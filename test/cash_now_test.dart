// "এখন কত টাকা আছে" (owner, 24 Oct): said once, then moved by every
// income and spending; kept in the data (and its backup).
import 'package:digital_brain/logic/cash.dart';
import 'package:digital_brain/models/models.dart';
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
}
