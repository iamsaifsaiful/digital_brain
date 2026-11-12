// Owner, 13 Nov: ধার-দেনা and অন্যান্য হিসাব as cards. SHOTS=1
// STAGE=before|after --update-goldens writes test/ui/shots/loancards/.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/screens/money_screens.dart' show ProjectScreen;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'all_pages_shots_test.dart' show richer;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';
final stage = Platform.environment['STAGE'] ?? 'after';

void main() {
  testWidgets('loan cards', (t) async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
    final rig = await start(t);
    t.view.physicalSize = const Size(1170, 3600);
    final now = rig.brain.services.now();
    final d = richer(now);
    d.ledger.addAll([
      LedgerEntry(person: 'করিম ভাই', kind: LedgerKind.borrowed, amount: 10000, date: now.subtract(const Duration(days: 20)), due: now.add(const Duration(days: 3))),
      LedgerEntry(person: 'করিম ভাই', kind: LedgerKind.repaid, amount: 4000, date: now.subtract(const Duration(days: 6))),
      LedgerEntry(person: 'সুমন', kind: LedgerKind.lent, amount: 2500, date: now.subtract(const Duration(days: 2))),
    ]);
    final p = d.projects.first.copyWith(mainAsked: true);
    d.projects[0] = p;
    d.cash.addAll([
      CashEntry(kind: CashKind.expense, amount: 45000, category: 'রড-সিমেন্ট', date: now.subtract(const Duration(days: 2)), projectId: p.id),
      CashEntry(kind: CashKind.expense, amount: 3000, category: 'বালু', date: now.subtract(const Duration(days: 2)), projectId: p.id),
      CashEntry(kind: CashKind.expense, amount: 12000, category: 'মিস্ত্রি', date: now.subtract(const Duration(days: 1)), projectId: p.id),
      CashEntry(kind: CashKind.income, amount: 100000, category: 'জমা', date: now.subtract(const Duration(days: 5)), projectId: p.id),
    ]);
    rig.brain.data = d;
    await settle(t);
    final ctx = t.element(find.byType(Scaffold).first);
    goToTab(ctx, ShellTab.money);
    await settle(t);
    await t.tap(find.text('ধার-দেনা').first);
    await settle(t);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/loancards/$stage/loans.png'));
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => ProjectScreen(id: p.id)));
    await settle(t);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/loancards/$stage/project.png'));
    debugDisableShadows = true;
  });
}
