import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logic/bn.dart';
import '../models/models.dart';

class PlannedNotice {
  const PlannedNotice({required this.id, required this.at, required this.title, required this.body, required this.payload, this.every, this.daily = false});
  final int id;
  final DateTime at;

  /// Rings again and again ("প্রতি ৩০ মিনিটে"), first at [at].
  final Duration? every;

  /// Rings every day at [at]'s time.
  final bool daily;
  final String title;
  final String body;
  final String payload;
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

/// One notification per reminder, for its next occurrence. Past times are
/// skipped. The text never contains vault details.
List<PlannedNotice> plannedNotices(List<Reminder> reminders, DateTime now) {
  final out = <PlannedNotice>[];
  for (final r in reminders) {
    final at = r.notifyAt(now);
    if (!at.isAfter(now)) continue;
    final day = r.nextDate(now);
    final String when;
    if (r.repeat.isInterval || r.repeat == Repeat.daily) {
      when = r.repeat.label;
    } else {
      when = r.daysBefore == 0 ? 'আজ ${bnTime(r.hour, r.minute)}' : '${fullDate(day)} (${bnDigits(r.daysBefore)} দিন পর)';
    }
    out.add(PlannedNotice(
      id: stableId('rem:${r.id}'),
      at: r.repeat.isInterval ? r.anchor : at,
      title: r.title,
      body: r.note.trim().isEmpty ? 'সময়: $when' : 'সময়: $when · ${r.note.trim()}',
      payload: 'reminder:${r.id}',
      every: r.repeat.isInterval ? Duration(minutes: r.repeat.minutes) : null,
      daily: r.repeat == Repeat.daily,
    ));
  }
  return out;
}

abstract class Notifier {
  ValueNotifier<String?> get tapped;
  Future<void> init();
  Future<void> requestPermission();
  Future<void> schedule(List<PlannedNotice> notices);

  /// Keep ringing until the notification is seen (like an alarm).
  bool insistent = true;

  /// Can notifications ring on the exact minute? (Android 14 asks the user.)
  Future<bool> exactAllowed();
  Future<void> requestExact();
}

class NotificationService implements Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  final tapped = ValueNotifier<String?>(null);

  @override
  bool insistent = true;

  /// Rings like an alarm (the alarm tone on the alarm volume, with
  /// vibration), so it is heard with the phone in a pocket. A new channel:
  /// Android never changes a channel's sound after it is made.
  NotificationDetails _details() => NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_alarm',
          'রিমাইন্ডার (অ্যালার্ম)',
          channelDescription: 'সময়মতো মনে করানো — অ্যালার্মের মতো বাজে',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          sound: const UriAndroidNotificationSound('content://settings/system/alarm_alert'),
          audioAttributesUsage: AudioAttributesUsage.alarm,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 700, 400, 700, 400, 700]),
          category: AndroidNotificationCategory.alarm,
          ticker: 'রিমাইন্ডার',
          // FLAG_INSISTENT: the sound repeats until the notification is opened or swiped.
          additionalFlags: insistent ? Int32List.fromList([4]) : null,
        ),
      );

  @override
  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (r) => tapped.value = r.payload,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        tapped.value = launch!.notificationResponse?.payload;
      }
      _ready = true;
    } catch (e) {
      debugPrint('Notifications unavailable: $e');
    }
  }

  @override
  Future<void> requestPermission() async {
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (_) {}
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

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
  Future<void> schedule(List<PlannedNotice> notices) async {
    if (!_ready) return;
    try {
      final exact = await exactAllowed();
      final mode = exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
      final details = _details();
      await _plugin.cancelAllPendingNotifications();
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
              notificationDetails: details,
              title: n.title,
              body: n.body,
              androidScheduleMode: mode,
              payload: n.payload,
            ),
          );
          continue;
        }
        await _plugin.zonedSchedule(
          id: n.id,
          scheduledDate: tz.TZDateTime.from(n.at, tz.UTC),
          notificationDetails: details,
          androidScheduleMode: mode,
          title: n.title,
          body: n.body,
          payload: n.payload,
          matchDateTimeComponents: n.daily ? DateTimeComponents.time : null,
        );
      }
    } catch (e) {
      debugPrint('Could not schedule reminders: $e');
    }
  }
}

class FakeNotifier implements Notifier {
  List<PlannedNotice> scheduled = [];

  @override
  bool insistent = true;

  @override
  final tapped = ValueNotifier<String?>(null);

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> schedule(List<PlannedNotice> notices) async => scheduled = notices;

  @override
  Future<bool> exactAllowed() async => true;

  @override
  Future<void> requestExact() async {}
}
