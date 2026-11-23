// Owner, 22 Nov: হিসাব made nicer, with more in it — আমার খাত, অ্যাকাউন্ট
// (a must on every লেনদেন, নগদ always), সাবস্ক্রিপশন, no সাপ্তাহিক, no খাত
// অনুযায়ী খরচ, one floating button on আলাদা হিসাব, the eye that hides
// amounts, a rounder search, and Home's সামনের খরচ and রিপোর্ট.
// SHOTS=1 flutter test test/ui/money_hub_1122_test.dart --update-goldens
// writes test/ui/shots/money_hub/.
import 'dart:io';

import 'package:digital_brain/logic/upcoming.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/screens/ledger_screen.dart';
import 'package:digital_brain/screens/money_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> _shot(WidgetTester t, String name) async {
  if (!shots) return;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/money_hub/$name.png'));
}

AppData seed(DateTime now) {
  final cash = MoneyAccount(name: '', kind: AccountKind.cash, opening: 4500);
  final bkash = MoneyAccount(name: '', kind: AccountKind.bkash, opening: 12300);
  final bank = MoneyAccount(name: 'ডাচ-বাংলা সেভিংস', kind: AccountKind.bank, opening: 85000);
  final card = MoneyAccount(name: 'সিটি ব্যাংক কার্ড', kind: AccountKind.card, opening: -6200);
  DateTime day(int d, [int m = 11]) => DateTime(2026, m, d, 12);
  return AppData(
    accounts: [cash, bkash, bank, card],
    cash: [
      CashEntry(kind: CashKind.income, amount: 45000, category: 'বেতন', date: day(1), accountId: bank.id),
      CashEntry(kind: CashKind.expense, amount: 15000, category: 'বাসা ভাড়া', date: day(2), accountId: bank.id),
      CashEntry(kind: CashKind.expense, amount: 2200, category: 'বাজার', date: day(8), accountId: cash.id),
      CashEntry(kind: CashKind.expense, amount: 1500, category: 'বিদ্যুৎ বিল', date: day(10), accountId: bkash.id),
      CashEntry(kind: CashKind.expense, amount: 1800, category: 'রেস্টুরেন্ট', date: day(14), accountId: card.id),
      CashEntry(kind: CashKind.expense, amount: 3100, category: 'বাজার', date: day(18), accountId: cash.id),
      CashEntry(kind: CashKind.expense, amount: 650, category: 'ওষুধ', date: day(20), accountId: cash.id),
      CashEntry(kind: CashKind.expense, amount: 200, category: 'মোবাইল রিচার্জ', date: day(21), accountId: bkash.id),
      CashEntry(kind: CashKind.expense, amount: 120, category: 'যাতায়াত', date: day(22), accountId: cash.id),
      CashEntry(kind: CashKind.income, amount: 5000, category: 'টিউশন', date: day(20), accountId: bkash.id),
      CashEntry(kind: CashKind.expense, amount: 15000, category: 'বাসা ভাড়া', date: day(2, 10)),
      CashEntry(kind: CashKind.expense, amount: 9800, category: 'বাজার', date: day(12, 10)),
      CashEntry(kind: CashKind.expense, amount: 3500, category: 'কেনাকাটা', date: day(19, 10)),
    ],
    subscriptions: [
      Subscription(name: 'ইন্টারনেট', amount: 1200, next: DateTime(2026, 11, 25), accountId: bkash.id),
      Subscription(name: 'নেটফ্লিক্স', amount: 650, next: DateTime(2026, 12, 3), accountId: card.id),
      Subscription(name: 'জিম', amount: 2000, next: DateTime(2026, 12, 1), accountId: cash.id),
      Subscription(name: 'ডোমেইন', amount: 1500, cycle: SubCycle.yearly, next: DateTime(2027, 1, 15), accountId: card.id),
    ],
    installments: [
      Installment(name: 'বাইকের লোন', kind: InstallmentKind.loan, amount: 5500, dayOfMonth: 28, months: 24, start: DateTime(2026, 7)),
      Installment(name: 'DPS', amount: 2000, dayOfMonth: 10, months: 60, start: DateTime(2026, 1), paid: ['2026-11']),
    ],
    goals: [SavingsGoal(name: 'ঈদের খরচ', target: 20000, deposits: [GoalDeposit(8000, day(5))])],
    ledger: [
      LedgerEntry(person: 'করিম ভাই', kind: LedgerKind.borrowed, amount: 10000, date: day(3), due: DateTime(2026, 11, 30)),
      LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 3000, date: day(6)),
    ],
    projects: [Project(name: 'বাড়ির কাজ', inMain: true, mainAsked: true)],
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

  test('সামনের খরচ: subscriptions, instalments and loans by date', () {
    final now = DateTime(2026, 11, 22, 10);
    final up = upcomingCosts(seed(now), now);
    expect([for (final u in up) u.title], ['ইন্টারনেট', 'বাইকের লোন', 'করিম ভাই', 'জিম', 'নেটফ্লিক্স', 'DPS']);
    expect(up.firstWhere((u) => u.kind == UpcomingKind.loan).amount, 10000);
  });

  testWidgets('হিসাব: আমার খাত, tabs, eye, accounts, subscriptions, form', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 22, 10, 5);
    rig.brain.data = seed(rig.nowAt);
    await settle(t);
    t.view.physicalSize = const Size(1170, 4300);
    goToTab(t.element(find.byType(Scaffold).first), ShellTab.money);
    await settle(t);
    expect(find.text('আমার খাত'), findsWidgets);
    expect(find.byKey(const Key('money-tools')), findsNothing);
    expect(find.byKey(const Key('khat-subs')), findsOneWidget);
    await _shot(t, '1-amar-khat');

    // The eye hides every amount.
    await t.tap(find.byKey(const Key('money-eye')).first);
    await settle(t);
    expect(find.text('৳ ••••'), findsWidgets);
    expect(rig.brain.flag('money_hidden'), isTrue);
    await _shot(t, '2-hidden');
    await t.tap(find.byKey(const Key('money-eye')).first);
    await settle(t);

    // আয়-ব্যয়: no সাপ্তাহিক, no খাত অনুযায়ী খরচ.
    await t.tap(find.text('আয়-ব্যয়').first);
    await settle(t);
    expect(find.text('সাপ্তাহিক'), findsNothing);
    expect(find.byKey(const Key('cash-cats')), findsNothing);
    await t.tap(find.text('মাসিক').last);
    await settle(t);
    await _shot(t, '3-cash-month');

    await t.tap(find.text('আলাদা হিসাব').first);
    await settle(t);
    expect(find.byKey(const Key('due-add-top')), findsNothing);
    expect(find.byKey(const Key('project-add')), findsOneWidget);
    await _shot(t, '4-projects');

    await t.tap(find.text('অ্যাকাউন্ট').first);
    await settle(t);
    expect(find.byKey(const Key('accounts-total')), findsOneWidget);
    expect(find.text('সিটি ব্যাংক কার্ড'), findsOneWidget);
    await _shot(t, '5-accounts');

    // The form: the account is a must, নগদ chosen first.
    t.view.physicalSize = const Size(1170, 2532);
    await settle(t);
    await t.tap(find.byKey(const Key('account-add')));
    await settle(t);
    Navigator.of(t.element(find.byType(BottomSheet).last)).pop();
    await settle(t);
    t.state<MoneyScreenState>(find.byType(MoneyScreen)).show(MoneyPart.hub);
    await settle(t);
    await t.tap(find.byKey(const Key('cash-add')));
    await settle(t);
    expect(find.byKey(const Key('cash-accounts')), findsOneWidget);
    final list = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).hitTestable();
    await t.drag(list.first, const Offset(0, -900));
    await settle(t);
    await _shot(t, '6-form-account');
    Navigator.of(t.element(find.byKey(const Key('cash-accounts')))).pop();
    await settle(t);

    // সাবস্ক্রিপশন: a card for each, "দেওয়া হলো" adds the spending.
    await t.tap(find.byKey(const Key('khat-subs')));
    await settle(t);
    await _shot(t, '7-subscriptions');
    final net = rig.brain.data.subscriptions.firstWhere((s) => s.name == 'ইন্টারনেট');
    final before = rig.brain.data.cash.length;
    await t.tap(find.byKey(Key('sub-pay-${net.id}')));
    await settle(t);
    expect(rig.brain.data.cash.length, before + 1);
    expect(rig.brain.data.subscriptions.firstWhere((s) => s.id == net.id).next, DateTime(2026, 12, 25));
    expect(find.byType(SubscriptionsScreen), findsOneWidget);
  });

  testWidgets('Home: সামনের খরচ and রিপোর্ট under the money', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 22, 10, 5);
    rig.brain.data = seed(rig.nowAt);
    await rig.brain.setUserName('সাইফুল');
    t.view.physicalSize = const Size(1170, 2532);
    await settle(t);
    expect(find.byKey(const Key('upcoming')), findsOneWidget);
    expect(find.byKey(const Key('home-report')), findsOneWidget);
    final list = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).hitTestable();
    await t.scrollUntilVisible(find.byKey(const Key('home-stat-spent')), 300, scrollable: list.first);
    await settle(t);
    await t.drag(list.first, const Offset(0, -260));
    await settle(t);
    await _shot(t, '8-home-upcoming');
    await t.drag(list.first, const Offset(0, -700));
    await settle(t);
    await _shot(t, '9-home-report');
    await t.tap(find.byKey(const Key('home-report-open')));
    await settle(t);
    expect(find.text('মাসের রিপোর্ট'), findsWidgets);
  });
}
