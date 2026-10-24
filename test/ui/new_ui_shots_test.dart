// The four main pages build in light and dark, with a
// full sample. With SHOTS=1 --update-goldens it also writes screenshots to
// test/ui/shots/ (icons drawn with Flutter's own MaterialIcons font).
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;

final shots = Platform.environment['SHOTS'] == '1';

AppData sample(DateTime now) {
  final bkash = MoneyAccount(name: 'বিকাশ', kind: AccountKind.bkash, opening: 5000);
  final today = DateTime(now.year, now.month, now.day);
  return AppData(
    accounts: [bkash],
    cash: [
      CashEntry(kind: CashKind.expense, amount: 450, category: 'বাজার', date: now, accountId: bkash.id),
      CashEntry(kind: CashKind.expense, amount: 1200, category: 'যাতায়াত', date: now.subtract(const Duration(days: 1))),
      CashEntry(kind: CashKind.expense, amount: 2500, category: 'বিল', date: now.subtract(const Duration(days: 2))),
      CashEntry(kind: CashKind.income, amount: 35000, category: 'বেতন', date: now.subtract(const Duration(days: 3))),
    ],
    ledger: [LedgerEntry(person: 'রহিম', amount: 3000, kind: LedgerKind.lent, date: now.subtract(const Duration(days: 9)))],
    tasks: [
      Task(title: 'বিদ্যুৎ বিল দেওয়া', due: today.add(const Duration(hours: 11))),
      Task(title: 'ডাক্তারের সিরিয়াল', due: today.add(const Duration(hours: 17)), urgent: true),
      Task(title: 'বাজারের লিস্ট', due: today, done: true, doneAt: now.subtract(const Duration(hours: 1))),
      Task(title: 'ব্যাংকে যাওয়া', due: today, done: true, doneAt: now.subtract(const Duration(hours: 2))),
      Task(title: 'স্কুলের ফি', due: today.add(const Duration(days: 1, hours: 10))),
    ],
    reminders: [Reminder(title: 'আম্মাকে ফোন', date: now, hour: 20)],
    notes: [Note(title: 'গেটের কোড', body: '৪৪২১'), Note(title: 'গাড়ির কাগজ', body: 'আলমারির উপরের তাকে'), Note(title: 'ওয়াইফাই', body: 'রাউটারের নিচে লেখা')],
    docs: [Doc(title: 'পাসপোর্ট', expiry: now.add(const Duration(days: 12)))],
    medicines: [Medicine(name: 'নাপা', times: [480, 1260])],
    goals: [SavingsGoal(name: 'হজ', target: 500000, deposits: [GoalDeposit(180000, now)])],
    installments: [Installment(name: 'বাড়ির লোন', kind: InstallmentKind.loan, amount: 12000, months: 24, start: DateTime(now.year - 1, now.month), paid: [for (var i = 0; i < 10; i++) monthKey(DateTime(now.year - 1, now.month + i))])],
  );
}

Future<void> icons() async {
  final f = File('/opt/fl/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!f.existsSync()) return;
  final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await l.load();
}

void main() {
  for (final look in [Look.light, Look.dark]) {
    for (final (name, tab) in [('1-home', null), ('2-day', 'দিনলিপি'), ('3-money', 'হিসাব'), ('4-store', 'সংরক্ষণ')]) {
      testWidgets('new ui ${look.name}: $name', (t) async {
        if (shots) await icons();
        if (shots) debugDisableShadows = false;
        final rig = await start(t);
        await rig.brain.setLook(look);
        await rig.brain.setUserName('সাইফুল');
        rig.brain.data = sample(rig.brain.services.now());
        await settle(t);
        if (tab != null) {
          await t.tap(find.text(tab).last);
          await settle(t);
        }
        expect(C.dark, look == Look.dark);
        if (shots) {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name-${look.name}.png'));
          // The rest of the page, scrolled.
          final list = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).hitTestable().first;
          await t.drag(list, const Offset(0, -900));
          await settle(t);
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/$name-${look.name}-b.png'));
        }
        debugDisableShadows = true;
      });
    }
  }
}
