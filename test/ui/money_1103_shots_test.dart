// The হিসাব tab of 3 Nov (owner approved the design): the summary card with
// the money in hand, the খাত strip and its page, days as cards, the add
// button; ধার-দেনা with its filter and due line; অন্যান্য হিসাব as plain
// cards. With SHOTS=1 --update-goldens the screens go to test/ui/shots/m1103-*.png.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/notifications.dart' show AlarmHealth;
import 'package:digital_brain/state/brain.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'home_final_shots_test.dart' show icons, sample, shots;

void main() {
  for (final look in [Look.light, Look.dark]) {
    for (final width in [390.0, 360.0]) {
      testWidgets('3 Nov হিসাব, ${look.name}, $width', (t) async {
        if (shots) await icons();
        final rig = await start(t);
        t.view.physicalSize = Size(width * 3, 1500 * 3);
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        rig.nowAt = DateTime(2026, 10, 24, 18, 34);
        await rig.brain.setLook(look);
        rig.notifier.state = const AlarmHealth(notificationsOn: true, exactOn: true, batteryFree: true, fullScreenOn: true, brand: '', hasAutostart: false);
        final d = sample(rig.nowAt);
        final today = DateTime(2026, 10, 24);
        d.cash.addAll([
          CashEntry(kind: CashKind.expense, amount: 350, category: 'যাতায়াত', date: today.add(const Duration(hours: 13)), note: 'রিকশা, বাস'),
          CashEntry(kind: CashKind.expense, amount: 1200, category: 'বাজার', date: today.add(const Duration(hours: 18)), note: 'মাছ, সবজি'),
          CashEntry(kind: CashKind.income, amount: 5000, category: 'কাজের আয়', date: today.subtract(const Duration(days: 4)), note: 'লোগোর কাজ'),
        ]);
        d.projects.add(Project(id: 'p1', name: 'বাড়ি মেরামত', inMain: true, mainAsked: true, budget: 50000));
        d.cash.addAll([
          CashEntry(kind: CashKind.income, amount: 50000, category: 'টাকা এলো', date: today.subtract(const Duration(days: 9)), projectId: 'p1'),
          CashEntry(kind: CashKind.expense, amount: 32400, category: 'মাল কেনা', date: today.subtract(const Duration(days: 1)), projectId: 'p1'),
        ]);
        rig.brain.data = d;
        await rig.brain.setCashOnHand(12350);
        await settle(t);
        Future<void> shot(String name) async {
          if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/m1103-$name-${look.name}-${width.round()}.png'));
        }

        await t.tap(find.text('হিসাব').last);
        await settle(t);
        expect(find.byKey(const Key('cash-now')), findsOneWidget);
        expect(find.byKey(const Key('cash-add')), findsOneWidget);
        await shot('day');
        await t.tap(find.text('মাসিক'));
        await settle(t);
        expect(find.byKey(const Key('cash-cats')), findsOneWidget);
        await shot('month');
        await t.tap(find.byKey(const Key('cash-cats')));
        await settle(t);
        await shot('cats');
        await t.tap(find.byKey(const Key('cats-বাজার')));
        await settle(t);
        expect(find.byKey(const Key('cash-cat-on')), findsOneWidget);
        await t.tap(find.byKey(const Key('cash-add')));
        await settle(t);
        await shot('add');
        await t.tap(find.byTooltip('ফিরে যান').first);
        await settle(t);
        await t.tap(find.text('ধার-দেনা'));
        await settle(t);
        expect(find.byKey(const Key('loans-net')), findsOneWidget);
        await shot('loans');
        await t.tap(find.text('অন্যান্য হিসাব'));
        await settle(t);
        expect(find.byKey(const Key('project-p1')), findsOneWidget);
        await shot('projects');
      });
    }
  }
}
