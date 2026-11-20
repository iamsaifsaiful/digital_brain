// Owner, 20 Nov: after a new install the intro (logo animation) is in
// English; it turns Bangla only once বাংলা is picked. main() reads the
// language (brain.loadLook) before the first frame for this.
// SHOTS=1 --update-goldens writes test/ui/shots/intro/ (gitignored).
import 'dart:io';

import 'package:digital_brain/app.dart';
import 'package:digital_brain/logic/lang.dart';
import 'package:digital_brain/ui/intro_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show Rig, loadFonts;

final shots = Platform.environment['SHOTS'] == '1';

void main() {
  Future<void> open(WidgetTester t, Rig rig) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await loadFonts();
    introOn = true;
    englishFirst = true;
    addTearDown(() {
      introOn = false;
      englishFirst = false;
      isEn = false;
    });
    await rig.brain.loadLook(); // as main() does, before runApp
    await t.pumpWidget(DigitalBrainApp(brain: rig.brain));
    await t.pump(const Duration(milliseconds: 2500));
  }

  testWidgets('new install: the intro speaks English', (t) async {
    final rig = Rig();
    await open(t, rig);
    expect(find.text('Reminder'), findsOneWidget);
    expect(find.text('Everything important, in one place, secure'), findsOneWidget);
    expect(find.text('রিমাইন্ডার'), findsNothing);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/intro/new-install-en.png'));
    await t.pump(const Duration(seconds: 2));
  });

  testWidgets('after বাংলা was picked: the intro is Bangla', (t) async {
    final rig = Rig();
    await rig.brain.services.lock.keys.write('lang', 'bn');
    await open(t, rig);
    expect(find.text('সব দরকারি জিনিস এক জায়গায়, তালাবদ্ধ'), findsOneWidget);
    expect(find.text('Reminder'), findsNothing);
    await t.pump(const Duration(seconds: 2));
  });
}
