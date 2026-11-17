// আরও (owner, 17 Nov, second look): short but nothing left out — you, every
// feature the bottom bar lacks, Premium in one row, the shop switch,
// settings (with backup on its own), your data, help, the app itself.
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
  testWidgets('আরও: the whole page, in order', (t) async {
    final rig = await rig0(t);
    rig.brain.supportWhatsapp = Platform.environment['WA'] ?? '01700000000';
    // One tall phone shows the whole page in one picture.
    t.view.physicalSize = const Size(1170, 2532 * 2.5);
    await t.tap(find.text('আরও').last);
    await settle(t);
    final grid = find.byKey(const Key('more-tools'));
    for (final k in ['reminders', 'docs', 'vault', 'zakat', 'family', 'compass', 'blood']) {
      expect(find.descendant(of: grid, matching: find.byKey(Key('tool-$k'))), findsOneWidget, reason: k);
    }
    for (final k in ['tasks', 'money', 'pro']) {
      expect(find.descendant(of: grid, matching: find.byKey(Key('tool-$k'))), findsNothing, reason: k);
    }
    double y(String key) => t.getTopLeft(find.byKey(Key(key))).dy;
    final order = ['more-profile', 'more-backup-chip', 'more-why-pro', 'more-tools', 'more-set-look', 'more-set-backup', 'more-set-safety', 'more-pdf', 'more-whatsapp', 'more-feedback', 'more-set-model', 'more-version'];
    for (var i = 1; i < order.length; i++) {
      expect(y(order[i - 1]), lessThan(y(order[i])), reason: '${order[i - 1]} before ${order[i]}');
    }
    final list = find.descendant(of: find.byType(MoreScreen), matching: vScroll()).first;
    final pos = t.state<ScrollableState>(list).position;
    debugPrint('more page: viewport ${pos.viewportDimension.round()}, extra ${pos.maxScrollExtent.round()}');
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/more_1117/1-page.png'));
    t.view.physicalSize = const Size(1170, 2532);
    await settle(t);
    // Premium: one row; its page has every reason, a tap opens the details.
    await t.ensureVisible(find.byKey(const Key('more-why-pro')));
    await settle(t);
    await t.tap(find.byKey(const Key('more-why-pro')));
    await settle(t);
    await t.tap(find.byKey(const Key('why-reminders')));
    await settle(t);
    expect(find.textContaining('চালু রিমাইন্ডারের কোনো সীমা নেই'), findsOneWidget);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/more_1117/2-why.png'));
    await t.tap(find.byTooltip('ফিরে যান').first);
    await settle(t);
    // The profile: one row, its page has name, place and blood group.
    await t.scrollUntilVisible(find.byKey(const Key('more-profile')), -300, scrollable: list);
    await t.tap(find.byKey(const Key('more-profile')));
    await settle(t);
    expect(find.byKey(const Key('profile-blood')), findsOneWidget);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/more_1117/3-profile.png'));
    debugDisableShadows = true;
  });
}
