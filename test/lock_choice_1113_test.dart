// Owner, 13 Nov: the fingerprint is not asked for by itself. The lock shows
// a choice — fingerprint or PIN — and then the one picked.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start, enterPin;

void main() {
  testWidgets('with a fingerprint: a choice first, no prompt by itself; PIN shows the pad', (t) async {
    final rig = await start(t);
    rig.biometrics.has = true;
    await rig.services.lock.setBiometricsOn(true);
    rig.brain.lockNow();
    await settle(t);
    expect(rig.biometrics.asked, 0);
    expect(find.byKey(const Key('lock-choose-pin')), findsOneWidget);
    expect(find.textContaining('নিজে থেকে লক'), findsNothing);
    await t.tap(find.byKey(const Key('lock-choose-pin')));
    await settle(t);
    expect(find.text('PIN দিন'), findsOneWidget);
    expect(rig.biometrics.asked, 0);
    await enterPin(t, '1234');
    expect(rig.brain.unlocked, isTrue);
  });

  testWidgets('the fingerprint picked: asked once, and it opens', (t) async {
    final rig = await start(t);
    rig.biometrics.has = true;
    rig.biometrics.ok = true;
    await rig.services.lock.setBiometricsOn(true);
    rig.brain.lockNow();
    await settle(t);
    await t.tap(find.byKey(const Key('lock-choose-finger')));
    await settle(t);
    expect(rig.biometrics.asked, 1);
    expect(rig.brain.unlocked, isTrue);
  });

  testWidgets('no fingerprint on the phone: straight to the PIN', (t) async {
    final rig = await start(t);
    rig.brain.lockNow();
    await settle(t);
    expect(find.byKey(const Key('lock-choose-finger')), findsNothing);
    expect(find.text('PIN দিন'), findsOneWidget);
  });
}
