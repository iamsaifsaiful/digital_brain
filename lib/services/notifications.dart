import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../logic/bn.dart';
import '../models/models.dart';

class PlannedNotice {
  const PlannedNotice({required this.id, required this.at, required this.title, required this.body, required this.payload});
  final int id;
  final DateTime at;
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
    final when = r.daysBefore == 0 ? 'আজ' : '${fullDate(day)} (${bnDigits(r.daysBefore)} দিন পর)';
    out.add(PlannedNotice(
      id: stableId('rem:${r.id}'),
      at: at,
      title: r.title,
      body: r.note.trim().isEmpty ? 'তারিখ: $when' : 'তারিখ: $when · ${r.note.trim()}',
      payload: 'reminder:${r.id}',
    ));
  }
  return out;
}

abstract class Notifier {
  ValueNotifier<String?> get tapped;
  Future<void> init();
  Future<void> requestPermission();
  Future<void> schedule(List<PlannedNotice> notices);
}

class NotificationService implements Notifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  @override
  final tapped = ValueNotifier<String?>(null);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'রিমাইন্ডার',
      channelDescription: 'বিল, মেয়াদ, অ্যাপয়েন্টমেন্ট ও অন্যান্য তারিখ',
      importance: Importance.high,
      priority: Priority.high,
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

  @override
  Future<void> schedule(List<PlannedNotice> notices) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAllPendingNotifications();
      for (final n in notices) {
        await _plugin.zonedSchedule(
          id: n.id,
          scheduledDate: tz.TZDateTime.from(n.at, tz.UTC),
          notificationDetails: _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: n.title,
          body: n.body,
          payload: n.payload,
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
  final tapped = ValueNotifier<String?>(null);

  @override
  Future<void> init() async {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> schedule(List<PlannedNotice> notices) async => scheduled = notices;
}
