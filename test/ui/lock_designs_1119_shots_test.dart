// Owner, 19 Nov: three designs of the sign-up and PIN pages to choose from.
// SHOTS=1 --update-goldens writes test/ui/shots/designs/ (gitignored).
import 'dart:io';

import 'package:digital_brain/app.dart';
import 'package:digital_brain/logic/lang.dart';
import 'package:digital_brain/screens/lock_screen.dart' show googleFirst, lockDesign;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show Rig, loadFonts, settle;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

void main() {
  for (final d in [1, 2, 3]) {
    testWidgets('lock design $d: sign-up, PIN, unlock', (t) async {
      t.view.physicalSize = const Size(1170, 2532);
      t.view.devicePixelRatio = 3.0;
      addTearDown(t.view.reset);
      await loadFonts();
      if (shots) {
        await four.icons();
        debugDisableShadows = false;
      }
      lockDesign = d;
      googleFirst = true;
      final rig = Rig();
      englishFirst = true;
      addTearDown(() {
        googleFirst = false;
        englishFirst = false;
        isEn = false;
        lockDesign = 2;
      });
      await t.pumpWidget(DigitalBrainApp(brain: rig.brain));
      await rig.brain.load();
      await settle(t);
      await t.runAsync(() => precacheImage(const AssetImage('assets/brand/app_mark.png'), t.element(find.byKey(const Key('lock-app-mark')))));
      await settle(t);
      Future<void> shot(String n) async {
        if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/designs/$d-$n.png'));
      }

      expect(find.byKey(const Key('lock-lang')), findsOneWidget);
      await shot('1-signup-en');
      await t.tap(find.byKey(const Key('lock-lang-bn')));
      await settle(t);
      await shot('2-signup-bn');
      await t.tap(find.byKey(const Key('welcome-later')));
      await settle(t);
      await shot('3-pin');
      for (final k in ['১', '২', '৩', '৪', '১', '২', '৩', '৪']) {
        await t.tap(find.text(k).last);
        await t.pump(const Duration(milliseconds: 30));
      }
      await settle(t);
      await rig.brain.setUserName('সাইফুল ইসলাম');
      rig.brain.lockNow();
      await settle(t);
      expect(find.text('আবার স্বাগতম, সাইফুল'), findsOneWidget);
      await shot('4-unlock');
      debugDisableShadows = true;
    });
  }
}
