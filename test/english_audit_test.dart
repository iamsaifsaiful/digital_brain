// Global version (owner, 2 Nov: "ইংলিশ সিলেক্ট করব, তখন প্রতিটি শব্দ সে
// ভাষায় হবে"): every page in English, with a member's own data in English,
// shows no Bengali letters. A member's own words stay as written; what the
// app writes must be English. AUDIT=1 prints every Bengali line found.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/app_places.dart';
import 'package:digital_brain/screens/family_screen.dart';
import 'package:digital_brain/screens/zakat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

final _bn = RegExp('[ঀ-৿]');
final audit = Platform.environment['AUDIT'] == '1';

/// A member who uses the app in English: everything they wrote is English.
AppData englishSample(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final bank = MoneyAccount(name: 'Bank', kind: AccountKind.bank, opening: 5000);
  return AppData(
    accounts: [bank],
    cash: [
      CashEntry(kind: CashKind.expense, amount: 450, category: 'Groceries', date: now, accountId: bank.id),
      CashEntry(kind: CashKind.income, amount: 3500, category: 'Salary', date: now.subtract(const Duration(days: 3))),
    ],
    ledger: [LedgerEntry(person: 'John', amount: 300, kind: LedgerKind.lent, date: now.subtract(const Duration(days: 9)))],
    tasks: [
      Task(title: 'Pay the electricity bill', due: today.add(const Duration(hours: 11))),
      Task(title: 'Call the dentist', due: today, done: true, doneAt: now.subtract(const Duration(hours: 1))),
    ],
    reminders: [Reminder(title: 'Call Mum', date: now, hour: 20)],
    notes: [Note(title: 'Gate code', body: '4421')],
    docs: [Doc(title: 'Passport', expiry: now.add(const Duration(days: 12)))],
    contacts: [Contact(name: 'Mum', phone: '+447700900123')],
    goals: [SavingsGoal(name: 'Holiday', target: 2000, deposits: [GoalDeposit(500, now)])],
    projects: [Project(name: 'House repairs', budget: 5000)],
    habits: [Habit(name: 'Walk 30 minutes')],
    specialDays: [SpecialDay(person: 'Anna', month: now.month, day: now.day, year: 1993)],
  );
}

/// Every line on screen with a Bengali letter in it.
List<String> bengaliOnScreen(WidgetTester t) {
  final found = <String>{};
  for (final w in t.widgetList(find.byWidgetPredicate((w) => w is Text || w is RichText, skipOffstage: false))) {
    final s = w is Text ? (w.data ?? w.textSpan?.toPlainText() ?? '') : (w as RichText).text.toPlainText();
    if (_bn.hasMatch(s)) found.add(s.replaceAll('\n', ' '));
  }
  return found.toList()..sort();
}

/// What may stay: the language's own name in the language switch, and the
/// Bangladesh price of Premium when Google Play gives none (no Play in tests).
List<String> _left(List<String> found) => [for (final s in found) if (s != 'বাংলা' && !s.startsWith('৳')) s];

void main() {
  final pages = <String, Widget Function()>{
    for (final id in ['tasks', 'alarms', 'calendar', 'special', 'notes', 'docs', 'vault', 'contacts', 'report', 'spending', 'accounts', 'savings', 'split', 'shop', 'health', 'habits', 'expiry', 'tags', 'memory', 'templates', 'search', 'settings', 'notifications', 'sound', 'backup', 'help', 'pro', 'compass'])
      id: () => placePage(id)!,
    'zakat': () => const ZakatScreen(),
    'family': () => const FamilyScreen(),
  };
  final all = <String, List<String>>{};

  Future<void> english(WidgetTester t, {String cc = 'GB'}) async {
    final rig = await start(t);
    await rig.brain.tryCountry(cc);
    await rig.brain.setEnglish(true);
    rig.brain.data = englishSample(rig.brain.services.now());
    await rig.brain.setUserName('Saif');
    await settle(t);
  }

  for (final tab in ['home', 'Diary', 'Money', 'Records', 'More']) {
    testWidgets('english: tab $tab', (t) async {
      await english(t);
      if (tab != 'home') {
        await t.tap(find.text(tab).last);
        await settle(t);
      }
      all['tab $tab'] = bengaliOnScreen(t);
      expect(_left(all['tab $tab']!), isEmpty);
    });
  }
  for (final e in pages.entries) {
    testWidgets('english: ${e.key}', (t) async {
      await english(t);
      Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => e.value()));
      await settle(t);
      all[e.key] = bengaliOnScreen(t);
      expect(_left(all[e.key]!), isEmpty);
    });
  }
  tearDownAll(() {
    final total = all.values.fold<int>(0, (a, l) => a + l.length);
    if (audit) {
      for (final e in all.entries) {
        for (final s in e.value) {
          // ignore: avoid_print
          print('${e.key}\t$s');
        }
      }
    }
    // ignore: avoid_print
    print('Bengali lines in English: $total on ${all.length} pages');
  });
}
