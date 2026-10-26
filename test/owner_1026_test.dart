// Owner, 26 Oct: "মোবাইল সাইলেন্ট থাকলেও এলার্ম বা রিমাইন্ডার সাউন্ড করে
// বাজবে।" Reminders ring on the alarm volume (not muted by silent mode); at
// zero they make no sound, so the app warns and turns it up; the alarm page
// rings itself when the phone muted the notification.
import 'package:digital_brain/app.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/crypto.dart';
import 'package:digital_brain/services/data_store.dart';
import 'package:digital_brain/screens/lock_screen.dart' show googleFirst;
import 'package:digital_brain/screens/alarm_screens.dart';
import 'package:digital_brain/services/notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, enterPin, loadFonts, settle, start;

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

  // Owner, 26 Oct: "মাঝে মাঝে রিমাইন্ডার বা এলার্ম বন্ধ করতে ক্লিক করলে সেখানে
  // বন্ধ হয় না। এপে লগইন স্কিন আসে, এরপর লগইন করলে বন্ধ হয়।" The lock's
  // fingerprint prompt came up over the alarm page; now it waits.
  testWidgets('opened by a ringing reminder with the app closed: the alarm page works before the PIN, no fingerprint prompt over it', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await loadFonts();
    googleFirst = false;
    final keys = MemoryKeyVault();
    final blob = MemoryBlobStore();
    final r1 = Rig(keys: keys, blob: blob);
    await t.pumpWidget(DigitalBrainApp(brain: r1.brain));
    await r1.brain.load();
    await settle(t);
    await enterPin(t, '1234');
    await enterPin(t, '1234');
    r1.biometrics.has = true;
    await r1.services.lock.setBiometricsOn(true);
    await r1.brain.saveReminder(Reminder(id: 'r1', title: 'ওষুধ খাওয়া', date: DateTime(2026, 10, 9), hour: 16));
    await t.pumpWidget(const SizedBox());

    // The app was closed; the reminder rings and opens it.
    final r2 = Rig(keys: keys, blob: blob);
    r2.biometrics.has = true;
    r2.notifier.tapped.value = const NoticeTap(NoticeInfo('r1', 'ওষুধ খাওয়া', '', false));
    await t.pumpWidget(DigitalBrainApp(brain: r2.brain));
    await r2.brain.load();
    await settle(t, 20);
    expect(find.text('হয়ে গেছে, বন্ধ করো'), findsOneWidget);
    expect(r2.biometrics.asked, 0, reason: 'no fingerprint prompt over the alarm page');
    await t.tap(find.text('হয়ে গেছে, বন্ধ করো'));
    await settle(t);
    expect(r2.notifier.stopped, contains('r1'));
    expect(r2.brain.alarmOpen, isFalse);
    expect(r2.brain.unlocked, isFalse, reason: 'behind it, the lock as before');
  });

  testWidgets('locked while away and a reminder opened: a fingerprint prompt already up is taken down', (t) async {
    final rig = await start(t);
    rig.biometrics.has = true;
    await rig.services.lock.setBiometricsOn(true);
    // The prompt is up and not yet answered.
    rig.biometrics.ok = false;
    rig.brain.lockNow();
    await settle(t);
    expect(rig.biometrics.asked, 1, reason: 'the lock asks as usual');
    rig.notifier.tapped.value = const NoticeTap(NoticeInfo('r9', 'আম্মাকে ফোন', '', false));
    await settle(t);
    expect(rig.biometrics.cancelled, 1);
    expect(find.text('হয়ে গেছে, বন্ধ করো'), findsOneWidget);
    await t.tap(find.text('হয়ে গেছে, বন্ধ করো'));
    await settle(t);
    expect(rig.notifier.stopped, contains('r9'));
    expect(find.byKey(const Key('lock-cover')), findsOneWidget);
  });
}
