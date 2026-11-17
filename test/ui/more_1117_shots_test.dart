// আরও (owner, 17 Nov): the features the bottom bar does not have come
// first, then the profile, business mode, your data, settings and help.
// SHOTS=1 --update-goldens writes test/ui/shots/more_1117/*.png.
import 'dart:io';

import 'package:digital_brain/screens/more_screen.dart' show MoreScreen;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_shots_test.dart' show rig0;
import '../app_test.dart' show settle, vScroll;

final shots = Platform.environment['SHOTS'] == '1';

void main() {
  testWidgets('আরও: সব সুবিধা first (without the bottom bar\'s), then the profile', (t) async {
    final rig = await rig0(t);
    rig.brain.supportWhatsapp = Platform.environment['WA'] ?? '01700000000';
    await t.tap(find.text('আরও').last);
    await settle(t);
    final grid = find.byKey(const Key('more-tools'));
    expect(grid, findsOneWidget);
    for (final k in ['reminders', 'docs', 'vault', 'zakat', 'family', 'pro']) {
      expect(find.descendant(of: grid, matching: find.byKey(Key('tool-$k'))), findsOneWidget, reason: k);
    }
    for (final k in ['tasks', 'money']) {
      expect(find.descendant(of: grid, matching: find.byKey(Key('tool-$k'))), findsNothing, reason: k);
    }
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/more_1117/1-top.png'));
    final list = find.descendant(of: find.byType(MoreScreen), matching: vScroll()).first;
    // Why Premium: one reason after another, a tap opens the details.
    final why = find.byKey(const Key('why-reminders'), skipOffstage: false);
    await t.scrollUntilVisible(why, 300, scrollable: list);
    await t.tap(why);
    await settle(t);
    expect(find.textContaining('চালু রিমাইন্ডারের কোনো সীমা নেই'), findsOneWidget);
    expect(find.textContaining('ফ্রিতে: সব মিলিয়ে একসাথে ২০টা'), findsOneWidget);
    await t.drag(list, const Offset(0, 200));
    await settle(t);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/more_1117/2-why.png'));
    await t.drag(list, const Offset(0, -900));
    await settle(t);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/more_1117/3-profile.png'));
    final wa = find.byKey(const Key('more-whatsapp'), skipOffstage: false);
    await t.scrollUntilVisible(wa, 300, scrollable: list);
    await t.drag(list, const Offset(0, -260));
    await settle(t);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/more_1117/4-help.png'));
    // Tapping a tool in আরও opens it.
    await t.drag(list, const Offset(0, 5000));
    await settle(t);
    await t.tap(find.descendant(of: grid, matching: find.byKey(const Key('tool-zakat'))));
    await settle(t);
    expect(find.text('যাকাত'), findsWidgets);
    debugDisableShadows = true;
  });
}
