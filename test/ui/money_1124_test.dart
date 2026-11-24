// Owner, 24 Nov: হিসাব's first card smaller, দৈনিক/মাসিক/বাৎসরিক right
// under it, সাবস্ক্রিপশন and সঞ্চয় in "আরও কাজে লাগে", the report last.
// SHOTS=1 flutter test test/ui/money_1124_test.dart --update-goldens
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/state/brain.dart' show BrainMore;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'money_hub_1122_test.dart' show seed;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> _shot(WidgetTester t, String name) async {
  if (!shots) return;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/money_1124/$name.png'));
}

void main() {
  setUp(() async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
  });
  tearDown(() => debugDisableShadows = true);

  for (final (name, withAccounts) in [('1-phone-accounts', true), ('2-phone-no-accounts', false)]) {
    testWidgets('the first screen: small card, then দৈনিক ($name)', (t) async {
      final rig = await start(t);
      rig.nowAt = DateTime(2026, 11, 22, 10, 5);
      final d = seed(rig.nowAt);
      rig.brain.data = withAccounts ? d : AppData(cash: [for (final e in d.cash) CashEntry(kind: e.kind, amount: e.amount, category: e.category, date: e.date)]);
      if (!withAccounts) await rig.brain.setCashOnHand(4000);
      await settle(t);
      t.view.physicalSize = const Size(1170, 2532);
      goToTab(t.element(find.byType(Scaffold).first), ShellTab.money);
      await settle(t);
      final card = t.getRect(find.byKey(const Key('hub-balance')));
      final day = t.getRect(find.byKey(const Key('cash-swipe')));
      expect(day.top - card.bottom, lessThan(120), reason: 'দৈনিক comes right under the card');
      expect(day.bottom, lessThan(844 - 140), reason: 'the day is on the first screen');
      await _shot(t, name);
      debugDisableShadows = true;
    });
  }
}
