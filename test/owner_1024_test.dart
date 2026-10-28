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
  test('money now (2.49.1 data): the offset kept then still gives the same amount', () {
    final at = DateTime(2026, 10, 24, 10);
    final d = AppData(cash: [CashEntry(kind: CashKind.expense, amount: 500, date: at.subtract(const Duration(hours: 1)))]);
    expect(cashOnHand(d), isNull);
    d.cashOffset = 10000 - ownNet(d);
    d.cashSetAt = at;
    expect(cashOnHand(d), 10000);
    d.cash.add(CashEntry(kind: CashKind.income, amount: 2000, date: at, addedAt: at.add(const Duration(minutes: 5))));
    d.cash.add(CashEntry(kind: CashKind.expense, amount: 9999, date: at, projectId: 'p1', addedAt: at.add(const Duration(minutes: 6))));
    expect(cashOnHand(d), 12000);
    final back = AppData.fromJson(d.toJson());
    expect(cashOnHand(back), 12000);
  });

  testWidgets('হিসাব: asked once at the top; typed and kept; later spending lowers it; set again, it starts from there', (t) async {
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
    rig.nowAt = rig.nowAt.add(const Duration(minutes: 1));
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

  group('মূল টাকা (owner, 24 Oct)', () {
    testWidgets('the owner’s example: salary in, spending out, lending out (shown as ব্যয়), borrowing in (as আয়), another হিসাবের খরচ out, a বকেয়া given does nothing, collected comes in', (t) async {
      final rig = await start(t);
      final b = rig.brain;
      final now = b.services.now();
      await b.setCashOnHand(5000);
      await b.saveCash(CashEntry(kind: CashKind.income, amount: 20000, category: 'বেতন', date: now));
      await b.saveCash(CashEntry(kind: CashKind.expense, amount: 3000, category: 'বাজার', date: now));
      await b.saveEntry(LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 2000, date: now));
      expect(b.lastMainLine!.category, 'ধার দেওয়া');
      await b.saveEntry(LedgerEntry(person: 'করিম', kind: LedgerKind.borrowed, amount: 1000, date: now));
      // The user said yes to "মূল হিসাবেও যোগ হবে?" (27 Oct: only then).
      final p = Project(name: 'বাড়ির কাজ', inMain: true, mainAsked: true);
      b.data.projects.add(p);
      await b.saveCash(CashEntry(kind: CashKind.expense, amount: 4000, category: 'রড', date: now, projectId: p.id));
      expect(b.lastMainLine!.note, 'বাড়ির কাজ');
      await b.saveEntry(LedgerEntry(person: 'সেলিম', kind: LedgerKind.lent, amount: 7000, date: now, projectId: p.id));
      expect(b.lastMainLine, isNull, reason: 'a বকেয়া is work done; no money moved');
      await b.saveCash(CashEntry(kind: CashKind.income, amount: 2000, category: 'বকেয়া আদায়', note: 'সেলিম', date: now, projectId: p.id));
      expect(b.lastMainLine!.category, 'বকেয়া থেকে আয়');
      expect(cashOnHand(b.data), 5000 + 20000 - 3000 - 2000 + 1000 - 4000 + 2000);
      expect(cashNowParts(b.data), [('আয়', 20000), ('খরচ', -3000), ('ধার নেওয়া', 1000), ('ধার দেওয়া', -2000), ('বকেয়া থেকে আয়', 2000), ('অন্যান্য হিসাবের খরচ', -4000)]);
      final m = monthSums(b.data.cash, now);
      expect(m.incomeByCategory['ধার নেওয়া'], 1000, reason: 'shown in আয়');
      expect(m.byCategory['ধার দেওয়া'], 2000, reason: 'shown in ব্যয়');
    });

    testWidgets('“এখন আছে” said again starts afresh: what came before is not counted', (t) async {
      final rig = await start(t);
      final b = rig.brain;
      await b.setCashOnHand(5000);
      await b.saveCash(CashEntry(kind: CashKind.income, amount: 20000, category: 'বেতন', date: b.services.now()));
      expect(cashOnHand(b.data), 25000);
      rig.nowAt = rig.nowAt.add(const Duration(minutes: 1));
      await b.setCashOnHand(10000);
      expect(cashOnHand(b.data), 10000);
      expect(cashNowParts(b.data), isEmpty);
      rig.nowAt = rig.nowAt.add(const Duration(minutes: 1));
      await b.saveCash(CashEntry(kind: CashKind.expense, amount: 500, category: 'বাজার', date: b.services.now()));
      expect(cashOnHand(b.data), 9500);
    });

    testWidgets('a loan taken out of the main money stays out (even when changed) until put back; deleted, its line goes and comes back with undo', (t) async {
      final rig = await start(t);
      final b = rig.brain;
      final now = b.services.now();
      await b.setCashOnHand(10000);
      final loan = LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 3000, date: now);
      await b.saveEntry(loan);
      expect(cashOnHand(b.data), 7000);
      await b.saveEntry(b.data.ledger.single.copyWith(amount: 3500));
      expect(cashOnHand(b.data), 6500, reason: 'its line follows');
      await b.removeFromMain(loan.id);
      expect(cashOnHand(b.data), 10000);
      await b.saveEntry(b.data.ledger.single.copyWith(amount: 4000));
      expect(mainCopyOf(b.data, loan.id), isNull, reason: 'stays out');
      expect((await b.addToMain(loan.id))!.amount, 4000);
      expect(cashOnHand(b.data), 6000);
      await b.deleteEntry(loan.id);
      expect(cashOnHand(b.data), 10000);
      await b.undoLastDelete();
      expect(cashOnHand(b.data), 6000);
    });

    testWidgets('loan form: the save message says it went into the main money', (t) async {
      final rig = await start(t);
      Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const LedgerFormScreen(person: 'রহিম', kind: LedgerKind.lent, amount: 500)));
      await settle(t);
      await t.tap(find.text('সেভ করুন').last);
      for (var i = 0; i < 6; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('মূল টাকায় যুক্ত হলো'), findsOneWidget);
      await settle(t);
      expect(mainCopyOf(rig.brain.data, rig.brain.data.ledger.single.id)!.category, 'ধার দেওয়া');
    });

    testWidgets('chat: a loan said is written in the main money too, and a quiet line says so', (t) async {
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
      expect(find.textContaining('মূল টাকায় যুক্ত হলো'), findsOneWidget);
    });

    testWidgets('“এখন আছে” opens how it came about', (t) async {
      final rig = await start(t);
      final b = rig.brain;
      await b.setCashOnHand(5000);
      await b.saveCash(CashEntry(kind: CashKind.income, amount: 2000, category: 'বেতন', date: b.services.now()));
      await t.tap(find.text('হিসাব').last);
      await settle(t);
      await t.tap(find.byKey(const Key('cash-now-open')));
      await settle(t);
      expect(find.byKey(const Key('cash-now-parts')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('cash-now-total')), matching: find.textContaining('৭,০০০')), findsOneWidget);
    });
  });

  testWidgets('accounts do not change “এখন আছে”; a new own entry still goes into the cash account', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final cash = MoneyAccount(name: 'নগদ', opening: 2000);
    await b.saveAccount(MoneyAccount(name: 'বিকাশ', kind: AccountKind.bkash, opening: 5000));
    await b.saveAccount(cash);
    await b.setCashOnHand(9000);
    await b.saveCash(CashEntry(kind: CashKind.expense, amount: 500, category: 'বাজার', date: b.services.now()));
    expect(b.data.cash.single.accountId, cash.id);
    expect(cashOnHand(b.data), 8500);
    expect(totalBalance(b.data), 6500);
  });
  testWidgets('ধার-দেনা has only ধার-দেনা: a হিসাব\'s বকেয়া stays inside that হিসাব (owner, 28 Oct; was counted here since 24 Oct)', (t) async {
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
    expect(find.byKey(const Key('loans-dues-note')), findsNothing);
    expect(find.text('রহিম'), findsOneWidget);
    expect(find.text('সেলিম'), findsNothing);
    expect(find.textContaining('৭,০০০'), findsNothing);
  });
}
