// Owner, 23 Nov: সঞ্চয় ও কিস্তি gets its own page — what it is kept in,
// the term, how it is paid, how many given, how many left, a reminder —
// and the account on a লেনদেন is asked for, not forced.
// SHOTS=1 flutter test test/ui/savings_1123_test.dart --update-goldens
// writes test/ui/shots/savings/.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/screens/ledger_screen.dart';
import 'package:digital_brain/screens/savings_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> _shot(WidgetTester t, String name) async {
  if (!shots) return;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/savings/$name.png'));
}

Installment _given(Installment i, int n) => i.copyWith(paid: [for (var k = 0; k < n; k++) i.keyAt(k)]);

AppData seed() {
  final cash = MoneyAccount(name: '', kind: AccountKind.cash, opening: 12500);
  final bkash = MoneyAccount(name: '', kind: AccountKind.bkash, opening: 12300);
  final bank = MoneyAccount(name: 'ডাচ-বাংলা সেভিংস', kind: AccountKind.bank, opening: 85000);
  final card = MoneyAccount(name: 'সিটি ব্যাংক কার্ড', kind: AccountKind.card, opening: -6200);
  return AppData(
    accounts: [cash, bkash, bank, card],
    installments: [
      _given(Installment(name: 'DPS', kind: InstallmentKind.dps, place: 'ডাচ-বাংলা ব্যাংক', amount: 2000, dayOfMonth: 10, months: 60, start: DateTime(2025, 1), accountId: bank.id), 22),
      _given(Installment(name: 'FDR', kind: InstallmentKind.fdr, place: 'ইসলামী ব্যাংক', amount: 100000, dayOfMonth: 15, months: 1, cycle: PayCycle.once, lump: 112000, start: DateTime(2026, 3), accountId: bank.id), 1),
      _given(Installment(name: 'মহল্লার সমিতি', kind: InstallmentKind.samity, place: 'আশার আলো সমিতি', amount: 500, months: 52, cycle: PayCycle.weekly, start: DateTime(2026, 6, 5), accountId: cash.id), 25),
      _given(Installment(name: 'বাইকের লোন', kind: InstallmentKind.loan, place: 'ব্র্যাক ব্যাংক', amount: 5500, dayOfMonth: 28, months: 24, lump: 120000, start: DateTime(2026, 7), accountId: bkash.id), 4),
      _given(Installment(name: 'দোকানের লোন', kind: InstallmentKind.ngo, place: 'ব্র্যাক', amount: 1200, months: 46, cycle: PayCycle.weekly, lump: 50000, start: DateTime(2026, 8, 3), accountId: cash.id), 16),
      _given(Installment(name: 'ফ্রিজ', kind: InstallmentKind.emi, place: 'সিটি ব্যাংক কার্ড', amount: 3500, dayOfMonth: 5, months: 6, start: DateTime(2026, 9), accountId: card.id), 3),
    ],
    goals: [SavingsGoal(name: 'ঈদের খরচ', target: 20000, deposits: [GoalDeposit(8000, DateTime(2026, 11, 5))])],
  );
}

void main() {
  setUp(() async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
  });
  tearDown(() => debugDisableShadows = true);

  test('a plan counts what is given and what is left', () {
    final dps = seed().installments.first;
    expect(dps.paidCount, 22);
    expect(dps.left, 38);
    expect(dps.paidTotal, 44000);
    final weekly = seed().installments[2];
    expect(weekly.dueAt(1).difference(weekly.dueAt(0)).inDays, 7);
  });

  testWidgets('সঞ্চয় ও কিস্তি: list, a plan, the form', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 23, 10, 5);
    rig.brain.data = seed();
    await settle(t);
    t.view.physicalSize = const Size(1170, 3400);
    goToTab(t.element(find.byType(Scaffold).first), ShellTab.money);
    await settle(t);
    final hub = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).hitTestable();
    await t.scrollUntilVisible(find.byKey(const Key('khat-savings')), 300, scrollable: hub.first);
    await Scrollable.ensureVisible(t.element(find.byKey(const Key('khat-savings'))), alignment: 0.4);
    await settle(t);
    await t.tap(find.byKey(const Key('khat-savings')));
    await settle(t);
    expect(find.byType(SavingsScreen), findsOneWidget);
    expect(find.byKey(const Key('plans-total')), findsOneWidget);
    await _shot(t, '1-savings');

    await t.tap(find.textContaining('কিস্তি ·').first);
    await settle(t);
    await _shot(t, '2-loans');
    await t.tap(find.textContaining('সঞ্চয় ·').first);
    await settle(t);

    // One plan: every fact, the reminder, each payment.
    t.view.physicalSize = const Size(1170, 3300);
    final dps = rig.brain.data.installments.firstWhere((i) => i.name == 'DPS');
    await t.tap(find.byKey(Key('plan-${dps.id}')));
    await settle(t);
    expect(find.byType(PlanScreen), findsOneWidget);
    expect(find.byKey(const Key('plan-remind')), findsOneWidget);
    await _shot(t, '3-plan');
    await t.ensureVisible(find.byKey(const Key('pay-22')));
    await settle(t);
    await t.tap(find.byKey(const Key('pay-22')));
    await settle(t);
    expect(rig.brain.data.installments.firstWhere((i) => i.id == dps.id).paidCount, 23);
    Navigator.of(t.element(find.byType(PlanScreen))).pop();
    await settle(t);

    // A new one.
    t.view.physicalSize = const Size(1170, 3600);
    await t.tap(find.byKey(const Key('plan-add')));
    await settle(t);
    expect(find.byType(PlanFormScreen), findsOneWidget);
    await t.enterText(find.byKey(const Key('plan-place')), 'সোনালী ব্যাংক');
    await t.enterText(find.byKey(const Key('plan-amount')), '3000');
    await t.enterText(find.byKey(const Key('plan-count')), '36');
    await settle(t);
    await _shot(t, '4-form');
    await t.tap(find.byKey(const Key('plan-save')));
    await settle(t);
    expect(rig.brain.data.installments.length, 7);
    debugDisableShadows = true;
  });

  testWidgets('লেনদেন: the account is asked for, not forced', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 23, 10, 5);
    rig.brain.data = seed();
    await settle(t);
    t.view.physicalSize = const Size(1170, 2532);
    goToTab(t.element(find.byType(Scaffold).first), ShellTab.money);
    await settle(t);
    t.state<MoneyScreenState>(find.byType(MoneyScreen)).show(MoneyPart.cash);
    await settle(t);
    await t.tap(find.byKey(const Key('cash-add')));
    await settle(t);
    expect(find.byKey(const Key('cash-accounts')), findsOneWidget);
    await t.enterText(find.byType(TextField).first, '450');
    await settle(t);
    final list = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).hitTestable();
    await t.drag(list.first, const Offset(0, -700));
    await settle(t);
    await _shot(t, '5-cash-account');
    debugDisableShadows = true;
  });
}
