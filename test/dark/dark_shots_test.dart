// Dark-mode screenshots of the main pages (run with SHOTS=1 --update-goldens;
// images in test/dark/shots/). Without SHOTS it only checks they build.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/app_places.dart';
import 'package:digital_brain/screens/family_screen.dart';
import 'package:digital_brain/screens/requests_screen.dart';
import 'package:digital_brain/screens/zakat_screen.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;

final shots = Platform.environment['SHOTS'] == '1';

AppData sample(DateTime now) {
  final bkash = MoneyAccount(name: 'বিকাশ', kind: AccountKind.bkash, opening: 5000);
  return AppData(
    accounts: [bkash],
    cash: [
      CashEntry(kind: CashKind.expense, amount: 450, category: 'বাজার', date: now, accountId: bkash.id),
      CashEntry(kind: CashKind.income, amount: 35000, category: 'বেতন', date: now.subtract(const Duration(days: 3))),
    ],
    ledger: [LedgerEntry(person: 'রহিম', amount: 3000, kind: LedgerKind.lent, date: now.subtract(const Duration(days: 9)))],
    tasks: [Task(title: 'বিদ্যুৎ বিল দেওয়া', due: now), Task(title: 'ডাক্তারের সিরিয়াল', urgent: true)],
    reminders: [Reminder(title: 'আম্মাকে ফোন', date: now, hour: 20)],
    notes: [Note(title: 'গেটের কোড', body: '৪৪২১')],
    medicines: [Medicine(name: 'নাপা', times: [480, 1260])],
    goals: [SavingsGoal(name: 'হজ', target: 500000, deposits: [GoalDeposit(40000, now)])],
  );
}

void main() {
  final pages = <String, Widget Function()>{
    for (final id in ['tasks', 'alarms', 'calendar', 'special', 'notes', 'docs', 'contacts', 'report', 'spending', 'accounts', 'savings', 'split', 'shop', 'health', 'medicines', 'habits', 'emergency', 'expiry', 'memory', 'templates', 'search', 'notifications', 'sound', 'backup', 'help', 'pro'])
      id: () => placePage(id)!,
    'zakat': () => const ZakatScreen(),
    'family': () => const FamilyScreen(),
    'blood': () => const RequestsScreen(),
    'blood-ask': () => const AskBloodScreen(),
  };
  for (final e in pages.entries) {
    testWidgets('dark: ${e.key}', (t) async {
      final rig = await start(t);
      await rig.brain.setLook(Look.dark);
      rig.brain.data = sample(rig.brain.services.now());
      await settle(t);
      Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => e.value()));
      await settle(t);
      expect(C.dark, isTrue);
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/${e.key}.png'));
    });
  }
  for (final tab in ['হিসাব', 'আরও']) {
    testWidgets('dark tab: $tab', (t) async {
      final rig = await start(t);
      await rig.brain.setLook(Look.dark);
      rig.brain.data = sample(rig.brain.services.now());
      await settle(t);
      await t.tap(find.text(tab).last);
      await settle(t);
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/tab-$tab.png'));
    });
  }
  testWidgets('dark: home', (t) async {
    final rig = await start(t);
    await rig.brain.setLook(Look.dark);
    rig.brain.data = sample(rig.brain.services.now());
    await settle(t);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/home.png'));
  });
}
