// The intro before the PIN page (owner, 3 Nov): it plays, then the PIN page
// comes; a tap skips it. With SHOTS=1 --update-goldens its frames go to
// test/ui/shots/intro/*.png (made into a short moving picture to show).
import 'dart:io';

import 'package:digital_brain/app.dart';
import 'package:digital_brain/screens/lock_screen.dart';
import 'package:digital_brain/ui/intro_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show Rig, loadFonts, start;
import 'home_final_shots_test.dart' show icons;

final shots = Platform.environment['SHOTS'] == '1';

void main() {
  setUp(() => introOn = true);
  tearDown(() => introOn = false);

  Future<Rig> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await loadFonts();
    if (shots) await icons();
    final rig = Rig();
    await t.pumpWidget(DigitalBrainApp(brain: rig.brain));
    await rig.brain.load();
    return rig;
  }

  testWidgets('the intro plays on start, then the PIN page', (t) async {
    await open(t);
    expect(find.byKey(const Key('intro')), findsOneWidget);
    expect(find.byType(LockScreen), findsNothing);
    for (var ms = 0; ms <= 2800; ms += 60) {
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/intro/f${ms.toString().padLeft(4, '0')}.png'));
      await t.pump(const Duration(milliseconds: 60));
    }
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('intro')), findsNothing);
    expect(find.byType(LockScreen), findsOneWidget);
  });

  testWidgets('a tap skips the intro', (t) async {
    await open(t);
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(find.byKey(const Key('intro')));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byType(LockScreen), findsOneWidget);
  });

  testWidgets('it plays again when the app locks again', (t) async {
    introOn = false;
    final rig = await start(t);
    expect(find.byType(LockScreen), findsNothing);
    introOn = true;
    rig.brain.lockNow();
    await t.pump();
    expect(find.byKey(const Key('intro')), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
    await t.pump(const Duration(milliseconds: 500));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('intro')), findsNothing);
    expect(find.byType(LockScreen), findsOneWidget);
  });
}
