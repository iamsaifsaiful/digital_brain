// The home list and the দিনলিপি of 3 Nov (owner approved the design: the
// actions on the right, the time under the title; the day as a timeline,
// the week as cards, the month as a calendar). With SHOTS=1
// --update-goldens the screens go to test/ui/shots/d1103-*.png.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/notifications.dart' show AlarmHealth;
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'home_final_shots_test.dart' show icons, sample, shots;

void main() {
  for (final look in [Look.light, Look.dark]) {
    for (final width in [390.0, 360.0]) {
      testWidgets('3 Nov home and দিনলিপি, ${look.name}, $width', (t) async {
        if (shots) await icons();
        final rig = await start(t);
        t.view.physicalSize = Size(width * 3, 844 * 3);
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        rig.nowAt = DateTime(2026, 10, 24, 18, 34);
        await rig.brain.setLook(look);
        rig.notifier.state = const AlarmHealth(notificationsOn: true, exactOn: true, batteryFree: true, fullScreenOn: true, brand: '', hasAutostart: false);
        final d = sample(rig.nowAt);
        final today = DateTime(2026, 10, 24);
        d.reminders.addAll([
          Reminder(title: 'ফজরের পরে হাঁটা', date: today, hour: 6, minute: 30, repeat: Repeat.daily),
          Reminder(title: 'অফিসের মিটিং', date: today, hour: 10),
          Reminder(title: 'ওষুধ খাওয়া', date: today, hour: 21, repeat: Repeat.daily),
          Reminder(title: 'পাসপোর্ট অফিস', date: DateTime(2026, 10, 28), hour: 11),
        ]);
        rig.brain.data = d;
        await rig.brain.setUserName('সাইফুল');
        await settle(t);
        Future<void> shot(String name) async {
          if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/d1103-$name-${look.name}-${width.round()}.png'));
        }

        expect(find.byKey(const Key('home-next')), findsOneWidget);
        expect(find.byTooltip('ফোন করুন'), findsOneWidget);
        expect(find.byTooltip('পরে'), findsOneWidget);
        await t.scrollUntilVisible(find.text('সব কাজ ও রিমাইন্ডার'), 200, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
        await shot('home');

        await t.tap(find.text('দিনলিপি').last);
        await settle(t);
        expect(find.byKey(const Key('diary-summary')), findsOneWidget);
        expect(find.byKey(const Key('diary-now')), findsOneWidget);
        await shot('day');
        await t.scrollUntilVisible(find.byKey(const Key('diary-habits')), 300, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last);
        await shot('day-bottom');
        await t.scrollUntilVisible(find.text('সাপ্তাহিক'), -300, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last);

        await t.tap(find.text('সাপ্তাহিক'));
        await settle(t);
        expect(find.byKey(const Key('week-2026-10-24')), findsOneWidget);
        await shot('week');
        // A day card opens that day.
        await t.tap(find.byKey(const Key('week-2026-10-25')));
        await settle(t);
        expect(find.textContaining('কাল, রবিবার'), findsWidgets);

        await t.tap(find.text('মাসিক'));
        await settle(t);
        await t.tap(find.byKey(const Key('month-2026-10-28')));
        await settle(t);
        expect(find.text('পাসপোর্ট অফিস'), findsWidgets);
        await shot('month');
      });
    }
  }
}
