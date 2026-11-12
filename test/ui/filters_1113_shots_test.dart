// Owner, 13 Nov: দিনলিপি's day without the date card, a smaller month; the
// money filters behind ⋮. SHOTS=1 STAGE=before|after --update-goldens writes
// test/ui/shots/filters/<stage>/ (gitignored).
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/screens/money_screens.dart' show ProjectScreen;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'all_pages_shots_test.dart' show richer;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';
final stage = Platform.environment['STAGE'] ?? 'after';

Future<void> shot(WidgetTester t, String name) async {
  if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/filters/$stage/$name.png'));
}

Future<void> down(WidgetTester t, double by) async {
  final list = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).hitTestable();
  if (list.evaluate().isEmpty) return;
  final st = t.state<ScrollableState>(list.first);
  st.position.jumpTo((st.position.pixels + by).clamp(0, st.position.maxScrollExtent));
  await settle(t);
}

void main() {
  testWidgets('filters: diary and money', (t) async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
    final rig = await start(t);
    await rig.brain.setUserName('সাইফুল');
    final now = rig.brain.services.now();
    final d = richer(now);
    final p = d.projects.first.copyWith(mainAsked: true);
    d.projects[0] = p;
    d.cash.addAll([
      CashEntry(kind: CashKind.expense, amount: 45000, category: 'রড-সিমেন্ট', date: now.subtract(const Duration(days: 2)), projectId: p.id),
      CashEntry(kind: CashKind.expense, amount: 12000, category: 'মিস্ত্রি', date: now.subtract(const Duration(days: 1)), projectId: p.id),
      CashEntry(kind: CashKind.income, amount: 100000, category: 'জমা', date: now.subtract(const Duration(days: 5)), projectId: p.id),
      CashEntry(kind: CashKind.income, amount: 2000, category: 'অন্যান্য', date: now),
      CashEntry(kind: CashKind.expense, amount: 120, category: 'যাতায়াত', date: now),
    ]);
    rig.brain.data = d;
    await settle(t);
    final ctx = t.element(find.byType(Scaffold).first);
    goToTab(ctx, ShellTab.diary);
    await settle(t);
    await shot(t, '1-day');
    await t.tap(find.text('মাসিক').first);
    await settle(t);
    await shot(t, '2-month');
    goToTab(ctx, ShellTab.money);
    await settle(t);
    await shot(t, '3-money');
    await down(t, 500);
    await shot(t, '4-money-list');
    if (stage == 'after') {
      await t.tap(find.byKey(const ValueKey('cash-filter')));
      await settle(t);
      await shot(t, '4b-menu');
      await t.tap(find.byKey(const Key('cash-kind-expense')));
      await settle(t);
      await shot(t, '4c-filtered');
    }
    await down(t, -3000);
    await t.tap(find.text('ধার-দেনা').first, warnIfMissed: false);
    await settle(t);
    await down(t, 300);
    await shot(t, '5-loans');
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => ProjectScreen(id: p.id)));
    await settle(t);
    await down(t, 400);
    await shot(t, '6-project');
    debugDisableShadows = true;
  });
}
