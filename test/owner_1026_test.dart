// Owner, 26 Oct: "মোবাইল সাইলেন্ট থাকলেও এলার্ম বা রিমাইন্ডার সাউন্ড করে
// বাজবে।" Reminders ring on the alarm volume (not muted by silent mode); at
// zero they make no sound, so the app warns and turns it up; the alarm page
// rings itself when the phone muted the notification.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/alarm_screens.dart';
import 'package:digital_brain/services/notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  const mutedAlarm = AlarmHealth(notificationsOn: true, exactOn: true, batteryFree: true, fullScreenOn: true, brand: '', hasAutostart: false, alarmVolumeOn: false);

  test('alarm volume at zero: reminders may not ring', () {
    expect(mutedAlarm.allGood, isFalse);
    expect(AlarmHealth.unknown.allGood, isTrue);
  });

  testWidgets('home warns, the check page turns the alarm volume up', (t) async {
    final rig = await start(t);
    rig.notifier.state = mutedAlarm;
    rig.brain.data.reminders.add(Reminder(title: 'আম্মাকে ফোন', date: DateTime(2026, 10, 26), hour: 19));
    // Back to the app: the phone's settings are read again.
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(t);
    expect(find.byKey(const Key('home-alarm-health')), findsOneWidget);

    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const ReminderCheckScreen()));
    await settle(t);
    expect(find.text('শূন্যে আছে — রিমাইন্ডার কোনো শব্দ করবে না'), findsOneWidget);
    await t.tap(find.text('বাড়ান'));
    await settle(t);
    expect(rig.notifier.volumeRaised, 1);
    expect(find.text('চালু আছে — ফোন সাইলেন্ট থাকলেও রিমাইন্ডার বাজবে'), findsOneWidget);
  });

  testWidgets('the alarm page asks to ring itself, and stops when closed', (t) async {
    final rig = await start(t);
    Navigator.of(t.element(find.byType(Scaffold).first))
        .push(MaterialPageRoute(builder: (_) => const AlarmScreen(info: NoticeInfo('r1', 'আম্মাকে ফোন', '', false))));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(rig.notifier.pageRings, ['r1']);
    await t.tap(find.text('হয়ে গেছে, বন্ধ করো'));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(rig.notifier.stopped, contains('r1'));
  });
}
