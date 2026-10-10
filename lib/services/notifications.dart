import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logic/bn.dart';
import '../models/models.dart';

/// How a planned notice repeats on its own, without the app being opened.
enum NoticeRepeat { none, daily, monthly, yearly }

class PlannedNotice {
  const PlannedNotice({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.reminderId,
    this.every,
    this.repeat = NoticeRepeat.none,
    this.early = false,
  });
  final int id;
  final DateTime at;

  /// Rings again and again ("প্রতি ৩০ মিনিটে"), first at [at].
  final Duration? every;

  /// Rings every day / month / year at [at]'s time.
  final NoticeRepeat repeat;
  bool get daily => repeat == NoticeRepeat.daily;

  /// The advance notice ("২ দিন আগে"), not the reminder itself.
  final bool early;
  final String title;
  final String body;
  final String reminderId;

  String get payload => noticePayload(reminderId, title, body, every != null);
}

/// What a notification carries, so a snooze can ring again with the same
/// words even when the app is closed.
String noticePayload(String reminderId, String title, String body, bool repeating) =>
    jsonEncode({'r': reminderId, 't': title, 'b': body, 'x': repeating});

class NoticeInfo {
  const NoticeInfo(this.reminderId, this.title, this.body, this.repeating);
  final String reminderId;
  final String title;
  final String body;
  final bool repeating;

  static NoticeInfo? parse(String? p) {
    if (p == null || p.isEmpty) return null;
    if (p.startsWith('reminder:')) return NoticeInfo(p.substring(9), '', '', false);
    try {
      final j = jsonDecode(p) as Map<String, dynamic>;
      return NoticeInfo('${j['r'] ?? ''}', '${j['t'] ?? ''}', '${j['b'] ?? ''}', j['x'] == true);
    } catch (_) {
      return null;
    }
  }
}

/// A notification the user opened, or one of its buttons.
class NoticeTap {
  const NoticeTap(this.info, {this.action});
  final NoticeInfo info;

  /// null = the notification itself (or its full-screen alarm); 'stop' =
  /// "আর বাজাবে না" on a repeating reminder.
  final String? action;
}

/// Stable 31-bit id for a string, so a reminder keeps its notification id.
int stableId(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return 1 + (h % 900000000);
}

int snoozeId(String reminderId) => stableId('snooze:$reminderId');

/// The notifications for the reminders: each rings on its own day and time
/// (and, if asked, once more some days before). Past one-time reminders are
/// skipped. The text never contains vault details.
List<PlannedNotice> plannedNotices(List<Reminder> reminders, DateTime now) {
  final out = <PlannedNotice>[];
  for (final r in reminders) {
    final note = r.note.trim();
    String bodyFor(String when) => note.isEmpty ? when : '$when · $note';
    if (r.repeat.isInterval) {
      out.add(PlannedNotice(
        id: stableId('rem:${r.id}'),
        at: r.anchor,
        title: r.title,
        body: bodyFor(r.repeat.label),
        reminderId: r.id,
        every: Duration(minutes: r.repeat.minutes),
      ));
      continue;
    }
    final at = r.notifyAt(now);
    if (at.isAfter(now)) {
      out.add(PlannedNotice(
        id: stableId('rem:${r.id}'),
        at: at,
        title: r.title,
        body: bodyFor(r.repeat == Repeat.none ? 'এখন · ${bnTime(r.hour, r.minute)}' : '${r.repeat.label} · ${bnTime(r.hour, r.minute)}'),
        reminderId: r.id,
        repeat: switch (r.repeat) {
          Repeat.daily => NoticeRepeat.daily,
          Repeat.monthly => NoticeRepeat.monthly,
          Repeat.yearly => NoticeRepeat.yearly,
          _ => NoticeRepeat.none,
        },
      ));
    }
    final early = r.earlyAt(now);
    if (early != null) {
      out.add(PlannedNotice(
        id: stableId('rem:${r.id}:early'),
        at: early,
        title: 'আগাম মনে করানো: ${r.title}',
        body: bodyFor('${fullDate(at)}, ${bnTime(r.hour, r.minute)} (${bnDigits(r.daysBefore)} দিন পর)'),
        reminderId: r.id,
        early: true,
      ));
    }
  }
  return out;
}

/// Why a reminder might not ring on this phone, and the fixes.
class AlarmHealth {
  const AlarmHealth({
    required this.notificationsOn,
    required this.exactOn,
    required this.batteryFree,
    required this.fullScreenOn,
    required this.brand,
    required this.hasAutostart,
  });
  final bool notificationsOn;
  final bool exactOn;

  /// Not stopped by battery saving.
  final bool batteryFree;

  /// Can light up a locked screen (Android 14 asks).
  final bool fullScreenOn;

  /// Phone maker, lower case ("xiaomi", "samsung"…).
  final String brand;

  /// The maker has its own "auto-start" switch that must be on.
  final bool hasAutostart;

  bool get allGood => notificationsOn && exactOn && batteryFree;

  static const unknown = AlarmHealth(notificationsOn: true, exactOn: true, batteryFree: true, fullScreenOn: true, brand: '', hasAutostart: false);
}

abstract class Notifier {
  ValueNotifier<NoticeTap?> get tapped;
  Future<void> init();
  Future<void> requestPermission();
  Future<void> schedule(List<PlannedNotice> notices);

  /// Keep ringing until the notification is seen (like an alarm).
  bool insistent = true;

  /// Can notifications ring on the exact minute? (Android 14 asks the user.)
  Future<bool> exactAllowed();
  Future<void> requestExact();

  Future<AlarmHealth> health();
  Future<void> fixBattery();
  Future<void> openAutostart();
  Future<void> requestFullScreen();
  Future<void> openNotificationSettings();

  /// Rings once, [after] from now (a snooze or the "test" button).
  Future<void> ringOnce(String reminderId, String title, String body, Duration after);

  /// Stops the sound of a reminder that is ringing now.
  Future<void> stopRinging(String reminderId);

  /// Lets the alarm page show over the lock screen (only while it is open).
  Future<void> showOverLock(bool on);
}

const _channelId = 'reminder_alarm';
const _platform = MethodChannel('my_assistant/alarm');

/// Rings like an alarm (the alarm tone on the alarm volume, with
/// vibration), so it is heard with the phone in a pocket. Android never
/// changes a channel's sound after it is made.
NotificationDetails _details({required bool insistent, required bool repeating}) => NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        'রিমাইন্ডার (অ্যালার্ম)',
        channelDescription: 'সময়মতো মনে করানো — অ্যালার্মের মতো বাজে',
        icon: 'ic_stat_reminder',
        color: const Color(0xFF0E7A5F),
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: const UriAndroidNotificationSound('content://settings/system/alarm_alert'),
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 700, 400, 700, 400, 700]),
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        ticker: 'রিমাইন্ডার',
        // Lights up a locked phone with the big alarm page.
        fullScreenIntent: true,
        autoCancel: true,
        // FLAG_INSISTENT: the sound repeats until the notification is opened or swiped.
        additionalFlags: insistent ? Int32List.fromList([4]) : null,
        actions: repeating
            ? const [
                AndroidNotificationAction('dismiss', 'ঠিক আছে'),
                AndroidNotificationAction('stop', 'আর বাজাবে না', showsUserInterface: true),
              ]
            : const [
                AndroidNotificationAction('snooze', '১০ মিনিট পরে'),
                AndroidNotificationAction('dismiss', 'হয়ে গেছে'),
              ],
      ),
    );

/// A button on a reminder was pressed while the app may be closed (runs
/// in its own little engine). "১০ মিনিট পরে" rings the same reminder again.
@pragma('vm:entry-point')
Future<void> onNoticeActionInBackground(NotificationResponse r) async {
  if (r.actionId != 'snooze') return;
  final info = NoticeInfo.parse(r.payload);
  if (info == null) return;
  try {
    tzdata.initializeTimeZones();
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_reminder')));
    await _ring(plugin, info.reminderId, info.title, info.body, const Duration(minutes: 10), insistent: true);
  } catch (e) {
    debugPrint('Snooze failed: $e');
  }
}

Future<void> _ring(FlutterLocalNotificationsPlugin plugin, String reminderId, String title, String body, Duration after,
    {required bool insistent}) async {
  final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  var exact = false;
  try {
    exact = await android?.canScheduleExactNotifications() ?? false;
  } catch (_) {}
  await plugin.zonedSchedule(
    id: snoozeId(reminderId),
    scheduledDate: tz.TZDateTime.from(clock.now().add(after), tz.UTC),
    notificationDetails: _details(insistent: insistent, repeating: false),
    androidScheduleMode: exact ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.inexactAllowWhileIdle,
    title: title,
    body: body.isEmpty ? 'আবার মনে করাচ্ছি' : body,
    payload: noticePayload(reminderId, title, body, false),
  );
}

class NotificationService implements Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  final tapped = ValueNotifier<NoticeTap?>(null);

  @override
  bool insistent = true;

  void _onResponse(NotificationResponse r) {
    final info = NoticeInfo.parse(r.payload);
    if (info == null) return;
    if (r.actionId == 'snooze') {
      ringOnce(info.reminderId, info.title, info.body, const Duration(minutes: 10));
      return;
    }
    if (r.actionId == 'dismiss') return;
    tapped.value = NoticeTap(info, action: r.actionId);
  }

  @override
  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_reminder'),
        ),
        onDidReceiveNotificationResponse: _onResponse,
        onDidReceiveBackgroundNotificationResponse: onNoticeActionInBackground,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final resp = launch?.notificationResponse;
      if ((launch?.didNotificationLaunchApp ?? false) && resp != null) _onResponse(resp);
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> requestPermission() async {
    try {
      await _android?.requestNotificationsPermission();
    } catch (_) {}
  }

  @override
  Future<bool> exactAllowed() async {
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> requestExact() async {
    try {
      await _android?.requestExactAlarmsPermission();
    } catch (_) {}
  }

  @override
  Future<AlarmHealth> health() async {
    var notificationsOn = true;
    try {
      notificationsOn = await _android?.areNotificationsEnabled() ?? true;
      final channels = await _android?.getNotificationChannels() ?? const [];
      for (final c in channels) {
        if (c.id == _channelId && c.importance == Importance.none) notificationsOn = false;
      }
    } catch (_) {}
    Map<Object?, Object?> p = const {};
    try {
      p = await _platform.invokeMapMethod<Object?, Object?>('status') ?? const {};
    } catch (_) {}
    return AlarmHealth(
      notificationsOn: notificationsOn,
      exactOn: await exactAllowed(),
      batteryFree: p['batteryFree'] != false,
      fullScreenOn: p['fullScreen'] != false,
      brand: '${p['brand'] ?? ''}'.toLowerCase(),
      hasAutostart: p['hasAutostart'] == true,
    );
  }

  Future<void> _call(String method, [Object? args]) async {
    try {
      await _platform.invokeMethod(method, args);
    } catch (e) {
      debugPrint('$method failed: $e');
    }
  }

  @override
  Future<void> fixBattery() => _call('askBattery');

  @override
  Future<void> openAutostart() => _call('openAutostart');

  @override
  Future<void> requestFullScreen() async {
    try {
      await _android?.requestFullScreenIntentPermission();
    } catch (_) {}
  }

  @override
  Future<void> openNotificationSettings() => _call('openNotificationSettings');

  @override
  Future<void> showOverLock(bool on) => _call('showOverLock', on);

  @override
  Future<void> ringOnce(String reminderId, String title, String body, Duration after) async {
    if (!_ready) return;
    try {
      await _ring(_plugin, reminderId, title, body, after, insistent: insistent);
    } catch (e) {
      debugPrint('Could not ring: $e');
    }
  }

  @override
  Future<void> stopRinging(String reminderId) async {
    try {
      final active = await _android?.getActiveNotifications() ?? const [];
      for (final a in active) {
        if (NoticeInfo.parse(a.payload)?.reminderId != reminderId || a.id == null) continue;
        // Only takes the shown copy off the screen: cancelling through the
        // plugin would also stop a repeating reminder's next rings.
        await _call('dismissShown', {'id': a.id, 'tag': a.tag});
      }
    } catch (e) {
      debugPrint('Could not stop: $e');
    }
  }

  @override
  Future<void> schedule(List<PlannedNotice> notices) async {
    if (!_ready) return;
    try {
      final exact = await exactAllowed();
      // alarmClock: Android treats it as an alarm clock — never delayed by
      // battery saving or Doze, which is what made reminders arrive late or
      // not at all on some phones.
      final mode = exact ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.inexactAllowWhileIdle;
      final repeatMode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
      final live = {for (final n in notices) n.reminderId};
      for (final p in await _plugin.pendingNotificationRequests()) {
        final info = NoticeInfo.parse(p.payload);
        // A snooze still to ring stays, unless its reminder was deleted.
        if (info != null && p.id == snoozeId(info.reminderId) && (live.contains(info.reminderId) || info.reminderId == 'test')) continue;
        await _plugin.cancel(id: p.id);
      }
      try {
        await _android?.deleteNotificationChannel(channelId: 'reminders');
      } catch (_) {}
      for (final n in notices) {
        final every = n.every;
        if (every != null) {
          // The plugin counts the repeats from "now"; a fixed clock keeps
          // them on the reminder's own times however often we reschedule.
          await withClock(
            Clock.fixed(n.at),
            () => _plugin.periodicallyShowWithDuration(
              id: n.id,
              repeatDurationInterval: every,
              notificationDetails: _details(insistent: insistent, repeating: true),
              title: n.title,
              body: n.body,
              androidScheduleMode: repeatMode,
              payload: n.payload,
            ),
          );
          continue;
        }
        await _plugin.zonedSchedule(
          id: n.id,
          scheduledDate: tz.TZDateTime.from(n.at, tz.UTC),
          notificationDetails: _details(insistent: insistent && !n.early, repeating: false),
          androidScheduleMode: mode,
          title: n.title,
          body: n.body,
          payload: n.payload,
          matchDateTimeComponents: switch (n.repeat) {
            NoticeRepeat.none => null,
            NoticeRepeat.daily => DateTimeComponents.time,
            NoticeRepeat.monthly => DateTimeComponents.dayOfMonthAndTime,
            NoticeRepeat.yearly => DateTimeComponents.dateAndTime,
          },
        );
      }
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }
}

class FakeNotifier implements Notifier {
  List<PlannedNotice> scheduled = [];
  final rung = <String>[];
  AlarmHealth state = AlarmHealth.unknown;

  @override
  bool insistent = true;

  @override
  final tapped = ValueNotifier<NoticeTap?>(null);

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> schedule(List<PlannedNotice> notices) async => scheduled = notices;

  @override
  Future<bool> exactAllowed() async => state.exactOn;

  @override
  Future<void> requestExact() async {}

  @override
  Future<AlarmHealth> health() async => state;

  @override
  Future<void> fixBattery() async {}

  @override
  Future<void> openAutostart() async {}

  @override
  Future<void> requestFullScreen() async {}

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> ringOnce(String reminderId, String title, String body, Duration after) async => rung.add(title);

  @override
  Future<void> stopRinging(String reminderId) async {}

  @override
  Future<void> showOverLock(bool on) async {}
}
