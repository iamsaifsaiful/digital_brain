// Owner, 19 Nov: the PIN page has an English | বাংলা switch, and a new phone
// starts in English. SHOTS=1 --update-goldens writes test/ui/shots/lang/
// (gitignored).
import 'dart:io';

import 'package:digital_brain/app.dart';
import 'package:digital_brain/logic/lang.dart';
import 'package:digital_brain/screens/lock_screen.dart' show googleFirst, lockScene;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show Rig, loadFonts, settle;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

void main() {
  testWidgets('a new phone opens in English; বাংলা switches the page', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await loadFonts();
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
    googleFirst = true;
    final rig = Rig();
    englishFirst = true;
    addTearDown(() {
      googleFirst = false;
      englishFirst = false;
      isEn = false;
    });
    await t.pumpWidget(DigitalBrainApp(brain: rig.brain));
    await rig.brain.load();
    await settle(t);
    await t.runAsync(() async {
      final ctx = t.element(find.byKey(const Key('lock-app-mark')));
      await precacheImage(const AssetImage('assets/brand/app_mark.png'), ctx);
      await precacheImage(AssetImage(lockScene(rig.brain.services.now())), ctx);
    });
    await settle(t);

    expect(rig.brain.english, isTrue);
    expect(find.byKey(const Key('lock-lang')), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/lang/1-english.png'));

    await t.tap(find.byKey(const Key('lock-lang-bn')));
    await settle(t);
    expect(rig.brain.english, isFalse);
    expect(find.text('Google দিয়ে লগইন'), findsOneWidget);
    expect(await rig.services.lock.keys.read('lang'), 'bn');
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/lang/2-bangla.png'));

    // The PIN pages have a small switch at the foot.
    await t.tap(find.byKey(const Key('welcome-later')));
    await settle(t);
    expect(find.byKey(const Key('lock-lang')), findsOneWidget);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/lang/3-pin-bangla.png'));
    await t.tap(find.byKey(const Key('lock-lang-en')));
    await settle(t);
    expect(rig.brain.english, isTrue);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/lang/4-pin-english.png'));
    for (final d in ['1', '2', '3', '4']) {
      await t.tap(find.text(d).last);
      await t.pump(const Duration(milliseconds: 30));
    }
    await settle(t);
    await t.tap(find.text('1').last);
    for (final d in ['2', '3', '4']) {
      await t.tap(find.text(d).last);
      await t.pump(const Duration(milliseconds: 30));
    }
    await settle(t);
    // Locked again: the daily unlock page has it too, and greets by name.
    await rig.brain.setUserName('Saiful Islam');
    rig.brain.lockNow();
    await settle(t);
    expect(find.byKey(const Key('lock-lang')), findsOneWidget);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/lang/5-unlock.png'));
    expect(find.text('Welcome back, Saiful'), findsOneWidget);
    await t.tap(find.byKey(const Key('lock-lang-bn')));
    await settle(t);
    expect(find.text('আবার স্বাগতম, Saiful'), findsOneWidget);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/lang/6-unlock-bangla.png'));
    debugDisableShadows = true;
  });
}
