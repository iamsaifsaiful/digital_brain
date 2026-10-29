import 'package:digital_brain/logic/ledger.dart' show accountKeys;
import 'package:digital_brain/logic/proactive.dart';
import 'package:digital_brain/state/brain.dart' show BrainScope;
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/crypto.dart' show MemoryKeyVault;
import 'package:digital_brain/screens/ledger_screen.dart' show LedgerAlarmButton;
import 'package:digital_brain/screens/money_screens.dart' show ProjectsView;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, settle, start;

void main() {
  group('seven days of Premium from the first open (owner, 28 Oct)', () {
    test('on for seven days, then off unless bought; what was kept stays', () async {
      final rig = Rig(keys: MemoryKeyVault());
      await rig.brain.load();
      final b = rig.brain..gated = true;
      expect(b.onTrial, isTrue);
      expect(b.pro, isTrue);
      expect(b.canAddProject, isTrue);
      b.data.projects.add(Project(name: 'দোকান', inMain: false, mainAsked: true));
      rig.nowAt = rig.nowAt.add(const Duration(days: 6, hours: 23));
      expect(b.pro, isTrue, reason: 'still the seventh day');
      rig.nowAt = rig.nowAt.add(const Duration(hours: 2));
      expect(b.onTrial, isFalse);
      expect(b.trialOver, isTrue);
      expect(b.pro, isFalse, reason: 'over, nothing bought');
      expect(b.canAddProject, isFalse, reason: 'a new হিসাব needs Premium again');
      expect(b.canUseProject(b.data.projects.single.id), isTrue, reason: 'one হিসাব is free (owner, 29 Oct)');
      expect(b.data.projects.single.name, 'দোকান', reason: 'what was made in the trial stays, to be seen');
      // Bought: Premium again, and no trial talk.
      b.proUntil = rig.nowAt.add(const Duration(days: 30));
      expect((b.pro, b.onTrial, b.trialOver), (true, false, false));
    });

    test('the start is kept: opening again does not start a new trial', () async {
      final rig = Rig(keys: MemoryKeyVault());
      await rig.brain.load();
      final first = rig.brain.trialStart;
      rig.nowAt = rig.nowAt.add(const Duration(days: 10));
      await rig.brain.load();
      expect(rig.brain.trialStart, first);
    });

    test('a note the day before it ends', () {
      final now = DateTime(2026, 10, 28, 9);
      final ends = DateTime(2026, 11, 4, 9);
      final n = assistantNotices(AppData(), now, AssistantPrefs(trialEnds: ends)).where((x) => x.reminderId == nudgeTrial).toList();
      expect(n.single.at, DateTime(2026, 11, 3, 10, 30));
      expect(n.single.title, contains('ট্রায়াল শেষ'));
      expect(assistantNotices(AppData(), now, const AssistantPrefs()).any((x) => x.reminderId == nudgeTrial), isFalse);
    });
  });

  testWidgets('ধার-দেনা: the bell beside someone with money owed sets a reminder on a day and time (owner, 28 Oct)', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final now = b.services.now();
    await b.saveEntry(LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 5000, date: now));
    final e = b.data.ledger.single;
    final key = accountKeys(b.data.ledger)[e.id]!;
    expect(e.due, isNull);
    await t.pumpWidget(BrainScope(brain: b, child: MaterialApp(home: Scaffold(body: Center(child: LedgerAlarmButton(accountKey: key, balance: 5000))))));
    await settle(t);
    expect(find.byIcon(Icons.alarm_add_outlined), findsOneWidget);
    // Tapped: a day, then a time.
    await t.tap(find.byKey(Key('ledger-alarm-$key')));
    await settle(t);
    await t.tap(find.text('OK'));
    await settle(t);
    await t.tap(find.text('OK'));
    await settle(t);
    final r = b.ledgerReminderOf(key)!;
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    expect((r.date, r.hour, r.minute), (tomorrow, 10, 0));
    expect(r.title, contains('রহিম'));
    expect(b.data.ledger.single.reminderId, r.id);
    expect(b.data.ledger.single.due, tomorrow, reason: 'it becomes the pay date');
    expect(find.byIcon(Icons.alarm_on_rounded), findsOneWidget, reason: 'green once set');
    // Set again: the old one is replaced, not doubled.
    await b.remindLedger(b.data.ledger.single, DateTime(now.year, now.month, now.day + 3, 18, 30));
    expect(b.data.reminders.where((x) => x.title.contains('রহিম')).length, 1);
    expect(b.ledgerReminderOf(key)!.hour, 18);
  });

  testWidgets('অন্যান্য হিসাব tab: no totals across them; each on its own cover with its overview; the বকেয়া has a reminder bell (owner, 28 Oct)', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final now = b.services.now();
    final shop = Project(id: 'shop', name: 'দোকান', inMain: false, mainAsked: true);
    b.data.projects.add(shop);
    await b.saveCash(CashEntry(kind: CashKind.income, amount: 9000, category: 'বিক্রি', date: now, projectId: 'shop'));
    await b.saveCash(CashEntry(kind: CashKind.expense, amount: 2500, category: 'মাল', date: now, projectId: 'shop'));
    await b.saveEntry(LedgerEntry(person: 'করিম', kind: LedgerKind.lent, amount: 700, date: now, projectId: 'shop'));
    await t.pumpWidget(BrainScope(brain: b, child: const MaterialApp(home: Scaffold(body: SingleChildScrollView(child: ProjectsView())))));
    await settle(t);
    expect(find.textContaining('চলমান হিসাবগুলোতে'), findsNothing, reason: 'no total across separate হিসাব');
    final cover = find.byKey(const Key('project-shop'));
    expect(find.descendant(of: cover, matching: find.text('দোকান')), findsOneWidget);
    expect(find.descendant(of: cover, matching: find.text('আলাদা')), findsOneWidget);
    expect(find.descendant(of: cover, matching: find.textContaining('৯,০০০')), findsOneWidget);
    expect(find.descendant(of: cover, matching: find.textContaining('৬,৫০০')), findsOneWidget, reason: 'what is left');
    expect(find.descendant(of: cover, matching: find.textContaining('৭০০')), findsOneWidget, reason: 'বকেয়া পাব');
    // The বকেয়া row's bell.
    final e = b.data.ledger.single;
    expect(find.byKey(Key('ledger-alarm-${e.id}')), findsOneWidget);
    await b.remindLedger(e, DateTime(now.year, now.month, now.day + 2, 17));
    expect(b.data.reminders.last.title, contains('বকেয়া'));
    await t.pump();
    expect(find.byIcon(Icons.alarm_on_rounded), findsOneWidget);
  });
}
