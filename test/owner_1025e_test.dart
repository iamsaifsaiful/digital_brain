// Owner, 25 Oct: "সব সুবিধার এখানে হিসাব এবং ওষুধ যুক্ত কর — হিসাব রিমাইন্ডারের
// পরে, ওষুধ ফ্যামিলির পরে".
import 'package:digital_brain/screens/health_screens.dart' show MedicinesScreen;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show openTools, settle, start;

void main() {
  testWidgets('সব সুবিধা: হিসাব right after রিমাইন্ডার, ওষুধ right after ফ্যামিলি; each opens its page', (t) async {
    await start(t);
    await openTools(t);
    final grid = find.byKey(const Key('home-tools'));
    final labels = [
      for (final e in t.widgetList<Text>(find.descendant(of: grid, matching: find.byType(Text)))) e.data ?? '',
    ];
    int at(String s) => labels.indexOf(s);
    expect(at('হিসাব'), at('রিমাইন্ডার') + 1, reason: labels.join(', '));
    expect(at('ওষুধ'), at('ফ্যামিলি') + 1, reason: labels.join(', '));

    Future<void> tap(String label) async {
      final f = find.descendant(of: grid, matching: find.text(label));
      await t.ensureVisible(f);
      await settle(t);
      await t.tap(f);
      await settle(t);
    }

    await tap('ওষুধ');
    expect(find.byType(MedicinesScreen), findsOneWidget);
    Navigator.of(t.element(find.byType(MedicinesScreen))).pop();
    await settle(t);
    await tap('হিসাব');
    expect(find.text('আয়-ব্যয় আর ধার-দেনা'), findsWidgets);
  });
}
