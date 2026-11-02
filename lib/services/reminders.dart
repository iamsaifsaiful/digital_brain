import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Rings on the day a customer said they would pay. Tapping it opens that
/// customer, where the reminder message is one tap away.
abstract class Reminders {
  /// [onOpen] gets the customer id when a reminder is tapped.
  Future<void> init(void Function(String customerId) onOpen);
  Future<void> askPermission();
  Future<void> schedule(String customerId, DateTime at, String title, String body);
  Future<void> cancel(String customerId);
}

/// One notification id per customer, so a new date replaces the old one.
int reminderIdFor(String customerId) {
  final hex = customerId.replaceAll(RegExp('[^0-9a-f]'), '');
  return hex.isEmpty ? customerId.hashCode & 0x7fffffff : int.parse(hex.substring(0, hex.length < 7 ? hex.length : 7), radix: 16);
}

class PhoneReminders implements Reminders {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> init(void Function(String customerId) onOpen) async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_reminder')),
        onDidReceiveNotificationResponse: (r) {
          final id = r.payload;
          if (id != null && id.isNotEmpty) onOpen(id);
        },
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      final p = launch?.notificationResponse?.payload;
      if ((launch?.didNotificationLaunchApp ?? false) && p != null && p.isNotEmpty) {
        // Let the first screen build before opening the customer.
        scheduleMicrotask(() => onOpen(p));
      }
      _ready = true;
    } catch (e) {
      debugPrint('Reminders unavailable: $e');
    }
  }

  @override
  Future<void> askPermission() async {
    try {
      await _android?.requestNotificationsPermission();
    } catch (_) {}
  }

  @override
  Future<void> schedule(String customerId, DateTime at, String title, String body) async {
    try {
      final exact = await _android?.canScheduleExactNotifications() ?? false;
      await _plugin.zonedSchedule(
        id: reminderIdFor(customerId),
        scheduledDate: tz.TZDateTime.from(at, tz.UTC),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'due_promises',
            'বাকির তাগাদা',
            channelDescription: 'গ্রাহক যেদিন বাকি দেবেন বলেছেন, সেদিন মনে করানো',
            icon: 'ic_stat_reminder',
            color: Color(0xFF2F6BEA),
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.private,
            autoCancel: true,
          ),
        ),
        androidScheduleMode: exact ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
        payload: customerId,
      );
    } catch (e) {
      debugPrint('Could not schedule: $e');
    }
  }

  @override
  Future<void> cancel(String customerId) async {
    try {
      await _plugin.cancel(id: reminderIdFor(customerId));
    } catch (_) {}
  }
}

/// For tests.
class FakeReminders implements Reminders {
  final scheduled = <String, DateTime>{};
  void Function(String)? onOpen;

  @override
  Future<void> init(void Function(String customerId) open) async => onOpen = open;
  @override
  Future<void> askPermission() async {}
  @override
  Future<void> schedule(String customerId, DateTime at, String title, String body) async => scheduled[customerId] = at;
  @override
  Future<void> cancel(String customerId) async => scheduled.remove(customerId);
}
