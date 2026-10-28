import 'package:digital_brain/logic/money_more.dart' show ZakatSaved;
import 'package:digital_brain/logic/zakat.dart';
import 'package:digital_brain/models/extras.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/zakat_principles.dart';
import 'package:digital_brain/screens/zakat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  final now = DateTime(2026, 10, 28, 10);
  const gold = 200000, silver = 3000;

  test('nisab (Hanafi): only gold → 7.5 ভরি of gold; gold with anything else → 52.5 ভরি of silver (owner, 28 Oct)', () {
    // 3 ভরি of gold and nothing else: no zakat, though its value passes the silver nisab.
    var z = zakatCount(zakatLines(AppData(), now, const ZakatSaved(goldVori: 3, goldPrice: gold, silverPrice: silver)), const ZakatSaved(goldVori: 3, goldPrice: gold, silverPrice: silver));
    expect((z.byGold, z.nisab, z.due), (true, 1500000, false));
    // 8 ভরি of gold alone: due.
    const eight = ZakatSaved(goldVori: 8, goldPrice: gold, silverPrice: silver);
    z = zakatCount(zakatLines(AppData(), now, eight), eight);
    expect((z.byGold, z.due, z.zakat), (true, true, 40000));
    // 3 ভরি of gold and a little cash: the silver nisab, so due.
    final cash = AppData(accounts: [MoneyAccount(id: 'h', name: 'হাতে', opening: 5000)]);
    const three = ZakatSaved(goldVori: 3, goldPrice: gold, silverPrice: silver);
    z = zakatCount(zakatLines(cash, now, three), three);
    expect((z.byGold, z.nisab, z.due, z.zakat), (false, 157500, true, 15125));
    // Debts come off before the nisab is checked.
    final owed = AppData(ledger: [LedgerEntry(person: 'রহিম', kind: LedgerKind.borrowed, amount: 1000000, date: now)]);
    z = zakatCount(zakatLines(owed, now, eight), eight);
    expect(z.due, isFalse, reason: '16 lakh of gold less 10 lakh of debt is under the gold nisab');
  });

  test('a হিসাব kept apart: shown, not counted until ticked — then its cash and বকেয়া count', () {
    final d = AppData(
      projects: [Project(id: 'p', name: 'নিজের দোকান', inMain: false, mainAsked: true)],
      cash: [CashEntry(kind: CashKind.income, amount: 300000, category: 'বিক্রি', date: now, projectId: 'p'), CashEntry(kind: CashKind.expense, amount: 50000, category: 'মাল', date: now, projectId: 'p')],
      ledger: [LedgerEntry(person: 'করিম', kind: LedgerKind.lent, amount: 20000, date: now, projectId: 'p')],
    );
    const s = ZakatSaved(silverPrice: silver);
    var line = zakatLines(d, now, s).firstWhere((l) => l.key == 'project:p');
    expect((line.amount, line.included, line.group), (270000, false, ZakatGroup.apart));
    expect(zakatCount(zakatLines(d, now, s), s).net, 0);
    d.zakat.excluded.add('+project:p');
    line = zakatLines(d, now, s).firstWhere((l) => l.key == 'project:p');
    expect(line.included, isTrue);
    expect(zakatCount(zakatLines(d, now, s), s).net, 270000);
  });

  testWidgets('the page: principles written out; where a line came from, month by month; carat picks the price', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    b.data.accounts.add(MoneyAccount(id: 'b', name: 'ব্যাংক', kind: AccountKind.bank, opening: 1000));
    b.data.cash.addAll([
      CashEntry(kind: CashKind.income, amount: 400, category: 'বেতন', date: DateTime(2026, 9, 3), accountId: 'b'),
      CashEntry(kind: CashKind.income, amount: 700, category: 'বেতন', date: DateTime(2026, 10, 3), accountId: 'b'),
      CashEntry(kind: CashKind.expense, amount: 200, category: 'বাজার', date: DateTime(2026, 10, 5), accountId: 'b'),
    ]);
    Navigator.of(t.element(find.byTooltip('বলুন'))).push(MaterialPageRoute(builder: (_) => const ZakatScreen()));
    await settle(t);
    await t.tap(find.byKey(const Key('zakat-line-account:b')));
    await settle(t);
    expect(find.byKey(const Key('zakat-month-2026-10')), findsOneWidget);
    expect(find.byKey(const Key('zakat-month-2026-9')), findsOneWidget);
    expect(find.text('+৳৫০০'), findsOneWidget, reason: 'October: 700 − 200');
    await t.tapAt(const Offset(10, 10));
    await settle(t);
    await t.tap(find.byKey(const Key('zakat-principles')));
    await settle(t);
    expect(find.text('নিসাব'), findsOneWidget);
    expect(find.byKey(const Key('zakat-rule-0')), findsOneWidget);
    expect(zakatPrinciples.length, greaterThanOrEqualTo(15));
  });
}
