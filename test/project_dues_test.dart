import 'package:digital_brain/logic/answers.dart' show ledgerAnswer;
import 'package:digital_brain/logic/ledger.dart';
import 'package:digital_brain/logic/parser.dart' show LedgerQuery, LedgerAsk;
import 'package:digital_brain/logic/person_money.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/money_screens.dart' show ProjectScreen, ProjectsView;
import 'package:digital_brain/screens/money_search_screen.dart';
import 'package:digital_brain/screens/project_dues.dart';
import 'package:digital_brain/state/brain.dart' show BrainScope;
import 'package:digital_brain/ui/theme.dart' show buildTheme;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  testWidgets('বকেয়া: who, what, how much; giving is not আয়, the money collected is', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final p = await b.projectNamed('রহিম স্টোর');
    await t.pumpWidget(BrainScope(brain: b, child: MaterialApp(theme: buildTheme(), home: ProjectScreen(id: p.id))));
    await settle(t);
    final add = find.byKey(const Key('due-add'));
    await t.ensureVisible(add);
    await settle(t);
    await t.tap(add);
    await settle(t);
    await t.enterText(find.byKey(const Key('due-person')), 'করিম');
    await t.enterText(find.byKey(const Key('due-what')), 'চাল-ডাল');
    await t.enterText(find.byKey(const Key('due-amount')), '১২০০');
    await t.tap(find.text('রাখুন'));
    await settle(t);
    expect(projectDueTotals(b.data, p.id).$1, 1200);
    expect(b.data.cash.where((e) => e.projectId == p.id), isEmpty, reason: 'giving on credit is not আয় or ব্যয়');
    expect(b.data.ledger.single.note, 'চাল-ডাল');
    expect(find.text('আমি পাবো'), findsOneWidget);

    final row = find.text('করিম');
    await t.ensureVisible(row.first);
    await settle(t);
    await t.tap(row.first);
    await settle(t);
    expect(find.text('চাল-ডাল'), findsOneWidget);
    await t.tap(find.text('আদায় হলো'));
    await settle(t);
    await t.enterText(find.byKey(const Key('due-amount')), '৫০০');
    await t.tap(find.text('রাখুন'));
    await settle(t);
    expect(projectDueTotals(b.data, p.id).$1, 700);
    final cash = b.data.cash.where((e) => e.projectId == p.id).single;
    expect((cash.kind, cash.amount, cash.category), (CashKind.income, 500, dueInCategory), reason: 'the money collected is আয়');

    // Deleting the project takes its বকেয়া along (to মুছে ফেলা, restorable).
    await b.deleteProject(p.id);
    expect(b.data.ledger.where((e) => e.projectId == p.id), isEmpty);
  });

  testWidgets('like ধার-দেনা: I owe a supplier; paying it is ব্যয়', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final p = await b.projectNamed('রহিম স্টোর');
    await t.pumpWidget(BrainScope(brain: b, child: MaterialApp(theme: buildTheme(), home: ProjectScreen(id: p.id))));
    await settle(t);
    final add = find.byKey(const Key('due-add'));
    await t.ensureVisible(add);
    await settle(t);
    await t.tap(add);
    await settle(t);
    await t.tap(find.text('আমি দেবো').last);
    await settle(t);
    await t.enterText(find.byKey(const Key('due-person')), 'সেলিম পাইকার');
    await t.enterText(find.byKey(const Key('due-what')), '১০ বস্তা চাল');
    await t.enterText(find.byKey(const Key('due-amount')), '3000');
    await t.tap(find.text('রাখুন'));
    await settle(t);
    expect(projectDueTotals(b.data, p.id), (0, 3000));
    expect(b.data.cash, isEmpty);
    final row = find.text('সেলিম পাইকার');
    await t.ensureVisible(row.first);
    await settle(t);
    await t.tap(row.first);
    await settle(t);
    await t.tap(find.text('শোধ করলাম'));
    await settle(t);
    await t.enterText(find.byKey(const Key('due-amount')), '1000');
    await t.tap(find.text('রাখুন'));
    await settle(t);
    expect(projectDueTotals(b.data, p.id), (0, 2000));
    final cash = b.data.cash.single;
    expect((cash.kind, cash.amount, cash.category), (CashKind.expense, 1000, dueOutCategory));
  });

  testWidgets('a pay day brings a reminder; paid in full, it goes', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final p = await b.projectNamed('রহিম স্টোর');
    final day = b.services.now().add(const Duration(days: 5));
    await b.saveEntry(LedgerEntry(person: 'জসিম', kind: LedgerKind.lent, amount: 650, date: b.services.now(), note: 'সিমেন্ট', due: day, projectId: p.id));
    final rem = b.data.reminders.where((r) => r.title.contains('জসিম')).toList();
    expect(rem, hasLength(1));
    expect(rem.single.title, contains('বকেয়া দেওয়ার দিন'));
    await t.pumpWidget(BrainScope(brain: b, child: MaterialApp(theme: buildTheme(), home: ProjectScreen(id: p.id))));
    await settle(t);
    final row = find.text('জসিম');
    await t.ensureVisible(row.first);
    await settle(t);
    await t.tap(row.first);
    await settle(t);
    await t.tap(find.text('আদায় হলো'));
    await settle(t);
    await t.tap(find.text('রাখুন'));
    await settle(t);
    expect(projectDueTotals(b.data, p.id).$1, 0);
    expect(b.data.reminders.where((r) => r.title.contains('জসিম')), isEmpty);
  });

  testWidgets('a name in হিসাব search: all আয়, ব্যয়, ধার-দেনা, বকেয়া and the নীট', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final now = b.services.now();
    final p = await b.projectNamed('রহিম স্টোর');
    await b.saveEntry(LedgerEntry(person: 'করিম মিয়া', kind: LedgerKind.lent, amount: 1200, date: now, note: 'চাল', projectId: p.id));
    await b.saveEntry(LedgerEntry(person: 'করিম মিয়া', kind: LedgerKind.received, amount: 500, date: now, projectId: p.id));
    await b.saveCash(CashEntry(kind: CashKind.income, amount: 500, category: 'বকেয়া আদায়', note: 'করিম মিয়া', date: now, projectId: p.id));
    await b.saveCash(CashEntry(kind: CashKind.expense, amount: 300, category: 'যাতায়াত', note: 'করিমের রিকশা ভাড়া', date: now));
    await b.saveEntry(LedgerEntry(person: 'করিম মিয়া', kind: LedgerKind.lent, amount: 2000, date: now)); // a personal loan
    await b.saveCash(CashEntry(kind: CashKind.expense, amount: 999, category: 'বাজার', note: 'রহিমা খালার জন্য', date: now));

    final m = personMoney(b.data, 'করিম');
    expect(m.income, 500);
    expect(m.expense, 300, reason: '"করিমের" counts, another name does not');
    expect(m.balance, 700 + 2000);
    // 500 in − 300 out − 2000 lent + 2700 still owed = 900: the loan nets to 0, the credit sale counts once.
    expect(m.net, 900);
    expect(m.lines, hasLength(5));
    expect(namesPerson('রহিমা খালার জন্য', 'রহিম'), isFalse);

    final say = ledgerAnswer(b.data, LedgerQuery('করিম মিয়ার হিসাব', ask: LedgerAsk.person, person: 'করিম মিয়া'), now);
    expect(say, contains('নীট'));

    await t.pumpWidget(BrainScope(brain: b, child: MaterialApp(theme: buildTheme(), home: const MoneySearchScreen())));
    await settle(t);
    await t.enterText(find.byKey(const Key('money-search')), 'করিম');
    await settle(t);
    expect(find.byKey(const Key('person-net')), findsOneWidget);
    expect(find.text('৳৯০০'), findsOneWidget);
    expect(find.text('করিমের রিকশা ভাড়া'), findsNothing); // shown inside the subtitle
    expect(find.textContaining('করিমের রিকশা ভাড়া'), findsOneWidget);
  });

  testWidgets('বকেয়া from the অন্যান্য হিসাব tab itself, and all of them listed there', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await t.pumpWidget(BrainScope(brain: b, child: MaterialApp(theme: buildTheme(), home: Scaffold(body: ListView(children: const [ProjectsView()])))));
    await settle(t);
    await t.tap(find.byKey(const Key('due-add-top')));
    await settle(t);
    await t.tap(find.text('ঠিক আছে')); // the name, দোকান, is filled in
    await settle(t);
    await t.enterText(find.byKey(const Key('due-person')), 'করিম');
    await t.enterText(find.byKey(const Key('due-amount')), '৪০০');
    await t.tap(find.text('রাখুন'));
    await settle(t);
    final shop = b.data.projects.single;
    expect(shop.name, 'দোকান');
    expect(projectDueTotals(b.data, shop.id).$1, 400);
    expect(find.text('করিম'), findsOneWidget, reason: 'listed on the tab, no need to open the হিসাব');
    expect(find.textContaining('দোকান'), findsWidgets);
  });

  test('a project loan survives a save and load', () {
    final e = LedgerEntry(person: 'ক', kind: LedgerKind.lent, amount: 10, date: DateTime(2026), projectId: 'p1');
    expect(LedgerEntry.fromJson(e.toJson()).projectId, 'p1');
    expect(LedgerEntry.fromJson(e.toJson()).copyWith(amount: 5).projectId, 'p1');
  });
}
