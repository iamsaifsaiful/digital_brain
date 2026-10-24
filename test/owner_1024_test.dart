// Owner's changes of 24 Oct: "এখন কত টাকা আছে", the calendar swipe, the
// diary's extras at the bottom.
import 'package:digital_brain/logic/cash.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/logic/money_more.dart' show totalBalance;
import 'package:digital_brain/screens/calendar_screen.dart';
import 'package:digital_brain/screens/ledger_form_screen.dart';
import 'package:digital_brain/state/brain.dart' show BrainMore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start, openTyping, sendTyped;

void main() {
  test('money now: the amount said, then income adds and spending takes away; a project does not count', () {
    final now = DateTime(2026, 10, 24, 10);
    final d = AppData(cash: [CashEntry(kind: CashKind.expense, amount: 500, date: now)]);
    expect(cashOnHand(d), isNull);
    d.cashOffset = 10000 - ownNet(d);
    expect(cashOnHand(d), 10000);
    d.cash.add(CashEntry(kind: CashKind.income, amount: 2000, date: now));
    d.cash.add(CashEntry(kind: CashKind.expense, amount: 300, date: now));
    d.cash.add(CashEntry(kind: CashKind.expense, amount: 9999, date: now, projectId: 'p1'));
    expect(cashOnHand(d), 11700);
    final back = AppData.fromJson(d.toJson());
    expect(cashOnHand(back), 11700);
  });

  testWidgets('হিসাব: asked once at the top; typed and kept; later spending lowers it; it can be corrected', (t) async {
    final rig = await start(t);
    await t.tap(find.text('হিসাব').last);
    await settle(t);
    expect(find.byKey(const Key('cash-now-ask')), findsOneWidget);
    await t.enterText(find.byKey(const Key('cash-now-field')), '১২০০০');
    await t.tap(find.byKey(const Key('cash-now-save')));
    await settle(t);
    expect(find.byKey(const Key('cash-now')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('cash-now')), matching: find.textContaining('১২,০০০')), findsOneWidget);
    await rig.brain.saveCash(CashEntry(kind: CashKind.expense, amount: 450, category: 'বাজার', date: rig.brain.services.now()));
    await settle(t);
    expect(find.descendant(of: find.byKey(const Key('cash-now')), matching: find.textContaining('১১,৫৫০')), findsOneWidget);
    await t.tap(find.byKey(const Key('cash-now-change')));
    await settle(t);
    await t.enterText(find.byKey(const Key('cash-now-edit')), '11000');
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    expect(cashOnHand(rig.brain.data), 11000);
    await rig.brain.setCashOnHand(5000);
    expect(cashOnHand(rig.brain.data), 5000);
  });

  testWidgets('ক্যালেন্ডার: a swipe on the days turns the month; the date tabs change only by a tap', (t) async {
    await start(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
    await settle(t);
    expect(find.text('অক্টোবর ২০২৬'), findsOneWidget);
    final day = find.byKey(const Key('day-2026-10-15'));
    await t.ensureVisible(day);
    await settle(t);
    await t.fling(day, const Offset(-300, 0), 1500);
    await settle(t);
    expect(find.text('নভেম্বর ২০২৬'), findsOneWidget);
    await t.fling(find.byKey(const Key('day-2026-11-15')), const Offset(300, 0), 1500);
    await settle(t);
    expect(find.text('অক্টোবর ২০২৬'), findsOneWidget);
  });

  testWidgets('দিনলিপি: habits, medicines, special days and ready lists sit at the bottom, each with an example', (t) async {
    await start(t);
    await t.tap(find.text('দিনলিপি').last);
    await settle(t);
    final habits = find.byKey(const Key('diary-habits'));
    await t.scrollUntilVisible(habits, 300, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    expect(find.textContaining('যেমন: প্রতিদিন ৩০ মিনিট হাঁটা'), findsOneWidget);
    expect(find.byKey(const Key('diary-medicines')), findsOneWidget);
    expect(find.byKey(const Key('diary-templates')), findsOneWidget);
    await t.tap(habits);
    await settle(t);
    expect(find.text('অভ্যাস'), findsWidgets);
  });

  group('মূল হিসাবে যুক্ত', () {
    testWidgets('a loan put in the main আয়-ব্যয়: an expense ‘ধার দেওয়া’, follows its change, goes with it, and comes back on undo', (t) async {
      final rig = await start(t);
      final b = rig.brain;
      final now = b.services.now();
      await b.setCashOnHand(10000);
      final loan = LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 3000, date: now);
      await b.saveEntry(loan);
      expect(cashOnHand(b.data), 10000, reason: 'not in the main account until asked');
      final copy = await b.addToMain(loan.id);
      expect((copy!.kind, copy.category, copy.amount, copy.note), (CashKind.expense, 'ধার দেওয়া', 3000, 'রহিম'));
      expect(cashOnHand(b.data), 7000);
      expect(await b.addToMain(loan.id), isNull, reason: 'once only');
      await b.saveEntry(b.data.ledger.single.copyWith(amount: 3500));
      expect(mainCopyOf(b.data, loan.id)!.amount, 3500);
      await b.deleteEntry(loan.id);
      expect(mainCopyOf(b.data, loan.id), isNull);
      await b.undoLastDelete();
      expect(b.data.ledger, hasLength(1));
      expect(mainCopyOf(b.data, loan.id)!.amount, 3500);
      await b.removeFromMain(loan.id);
      expect(mainCopyOf(b.data, loan.id), isNull);
      expect(b.data.ledger, hasLength(1), reason: 'the loan stays');
    });

    testWidgets('another হিসাব: its entry goes in with the হিসাব name; a বকেয়া given can go, its payback goes as that হিসাবের আয়', (t) async {
      final rig = await start(t);
      final b = rig.brain;
      final now = b.services.now();
      final p = Project(name: 'বাড়ির কাজ');
      b.data.projects.add(p);
      final rod = CashEntry(kind: CashKind.expense, amount: 10000, category: 'রড', date: now, projectId: p.id);
      await b.saveCash(rod);
      final c = await b.addToMain(rod.id);
      expect((c!.category, c.note, c.projectId), ('রড', 'বাড়ির কাজ', null));
      final due = LedgerEntry(person: 'সেলিম', kind: LedgerKind.lent, amount: 7000, date: now, projectId: p.id);
      final back = LedgerEntry(person: 'সেলিম', kind: LedgerKind.received, amount: 2000, date: now, projectId: p.id);
      await b.saveEntry(due);
      await b.saveEntry(back);
      expect(canGoToMain(b.data, due.id), isTrue);
      expect((await b.addToMain(due.id))!.category, 'বকেয়া দেওয়া');
      expect(canGoToMain(b.data, back.id), isFalse, reason: 'the payback is the হিসাব\'s own income entry');
      await b.deleteCash(rod.id);
      expect(mainCopyOf(b.data, rod.id), isNull);
    });

    testWidgets('loan form: asked right after saving; yes puts it in and says so', (t) async {
      final rig = await start(t);
      Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const LedgerFormScreen(person: 'রহিম', kind: LedgerKind.lent, amount: 500)));
      await settle(t);
      await t.tap(find.text('সেভ করুন').last);
      await settle(t);
      expect(find.text('মূল হিসাবেও যোগ করবেন?'), findsOneWidget);
      await t.tap(find.text('হ্যাঁ, যোগ করুন'));
      for (var i = 0; i < 8; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('মূল হিসাবে যুক্ত হলো'), findsOneWidget);
      await settle(t);
      final loan = rig.brain.data.ledger.single;
      expect(mainCopyOf(rig.brain.data, loan.id)!.category, 'ধার দেওয়া');
    });

    testWidgets('chat: a loan said has “মূল হিসাবেও যোগ করুন”; tapped, it goes in and the chat says so', (t) async {
      final rig = await start(t);
      await openTyping(t);
      await t.enterText(find.byType(TextField).first, 'রহিমকে ৫০০ টাকা ধার দিলাম');
      await sendTyped(t);
      await settle(t);
      if (find.widgetWithText(ActionChip, 'হ্যাঁ').evaluate().isNotEmpty) {
        await t.tap(find.widgetWithText(ActionChip, 'হ্যাঁ'));
        await settle(t);
      }
      expect(rig.brain.data.ledger, hasLength(1));
      await t.tap(find.textContaining('মূল হিসাবেও যোগ করুন').last);
      await settle(t);
      expect(find.textContaining('মূল হিসাবে যুক্ত হলো'), findsOneWidget);
      expect(mainCopyOf(rig.brain.data, rig.brain.data.ledger.single.id), isNotNull);
    });
  });

  testWidgets('with accounts, “এখন আছে” is their total; a new entry goes into the cash account; a correction moves its opening', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final cash = MoneyAccount(name: 'নগদ', opening: 2000);
    final bkash = MoneyAccount(name: 'বিকাশ', kind: AccountKind.bkash, opening: 5000);
    await b.saveAccount(bkash);
    await b.saveAccount(cash);
    expect(cashOnHand(b.data), 7000);
    await b.saveCash(CashEntry(kind: CashKind.expense, amount: 500, category: 'বাজার', date: b.services.now()));
    expect(b.data.cash.single.accountId, cash.id);
    expect(cashOnHand(b.data), 6500);
    await b.setCashOnHand(10000);
    expect(cashOnHand(b.data), 10000);
    expect(totalBalance(b.data), 10000);
    expect(b.data.accounts.firstWhere((a) => a.id == cash.id).opening, 5500);
  });

  testWidgets('ধার-দেনা counts বকেয়া too and says how much of it is বকেয়া', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final p = Project(name: 'বাড়ির কাজ');
    b.data.projects.add(p);
    await b.saveEntry(LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 3000, date: b.services.now()));
    await b.saveEntry(LedgerEntry(person: 'সেলিম', kind: LedgerKind.lent, amount: 7000, date: b.services.now(), projectId: p.id));
    await t.tap(find.text('হিসাব').last);
    await settle(t);
    await t.tap(find.text('ধার-দেনা'));
    await settle(t);
    expect(find.byKey(const Key('loans-dues-note')), findsOneWidget);
    expect(find.textContaining('বকেয়া · বাড়ির কাজ'), findsOneWidget);
  });
}
