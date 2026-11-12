// Owner, 13 Nov: হিসাব's week and month as day cards. SHOTS=1
// STAGE=before|after --update-goldens writes test/ui/shots/moneycards/.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'all_pages_shots_test.dart' show richer;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';
final stage = Platform.environment['STAGE'] ?? 'after';

void main() {
  testWidgets('money cards', (t) async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
    final rig = await start(t);
    // Tall, so the whole list shows.
    t.view.physicalSize = const Size(1170, 4200);
    final now = rig.brain.services.now();
    final d = richer(now);
    for (final (ago, kind, amt, cat) in [
      (0, CashKind.expense, 120, 'যাতায়াত'), (1, CashKind.expense, 650, 'বাজার'), (1, CashKind.expense, 200, 'মোবাইল রিচার্জ'), (1, CashKind.expense, 90, 'নাস্তা'),
      (2, CashKind.income, 5000, 'টিউশন'), (2, CashKind.expense, 1500, 'বিদ্যুৎ বিল'), (4, CashKind.expense, 300, 'ওষুধ'), (5, CashKind.expense, 2200, 'বাজার'),
    ]) {
      d.cash.add(CashEntry(kind: kind, amount: amt, category: cat, date: now.subtract(Duration(days: ago))));
    }
    rig.brain.data = d;
    await settle(t);
    goToTab(t.element(find.byType(Scaffold).first), ShellTab.money);
    await settle(t);
    await t.tap(find.text('সাপ্তাহিক').first);
    await settle(t);
    final list = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).hitTestable();
    t.state<ScrollableState>(list.first).position.jumpTo(0);
    await settle(t);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/moneycards/$stage/week.png'));
    t.state<ScrollableState>(list.first).position.jumpTo(0);
    await settle(t);
    await t.tap(find.text('মাসিক').last);
    await settle(t);
    t.state<ScrollableState>(list.first).position.jumpTo(0);
    await settle(t);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/moneycards/$stage/month.png'));
    debugDisableShadows = true;
  });
}
