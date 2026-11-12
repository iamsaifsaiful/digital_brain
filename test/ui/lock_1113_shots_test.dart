// Owner, 13 Nov: the lock offers fingerprint or PIN. SHOTS=1 --update-goldens
// writes test/ui/shots/lock/ (gitignored).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

void main() {
  testWidgets('lock: the choice, then the PIN pad', (t) async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
    final rig = await start(t);
    rig.biometrics.has = true;
    await rig.services.lock.setBiometricsOn(true);
    rig.brain.lockNow();
    await settle(t);
    expect(find.byKey(const Key('lock-choose-finger')), findsOneWidget);
    // The app mark is an asset: loaded before the shot.
    await t.runAsync(() => precacheImage(const AssetImage('assets/brand/app_mark.png'), t.element(find.byKey(const Key('lock-app-mark')))));
    await settle(t);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/lock/1-choice.png'));
    await t.tap(find.byKey(const Key('lock-choose-pin')));
    await settle(t);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/lock/2-pin.png'));
    debugDisableShadows = true;
  });
}
