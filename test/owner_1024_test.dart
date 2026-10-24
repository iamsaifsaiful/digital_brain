// Owner's changes of 24 Oct: "এখন কত টাকা আছে", the calendar swipe, the
// diary's extras at the bottom.
import 'package:digital_brain/logic/cash.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/calendar_screen.dart';
import 'package:digital_brain/state/brain.dart' show BrainMore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

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
}
