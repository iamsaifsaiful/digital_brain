import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'home_final_shots_test.dart' show icons, shots;

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Owner, 4 Nov: the dark look's colour is the member's pick — dark ones only.
void main() {
  test('every dark set is dark, and its words stay readable', () {
    for (final d in darkSets) {
      expect(d.ground.computeLuminance() < 0.03, isTrue, reason: '${d.key} ground');
      expect(d.surface.computeLuminance() < 0.04, isTrue, reason: '${d.key} surface');
      expect(_contrast(const Color(0xFFEEF1F8), d.surface) >= 7, isTrue, reason: '${d.key} ink');
      expect(_contrast(d.muted, d.surface) >= 4.5, isTrue, reason: '${d.key} muted ${_contrast(d.muted, d.surface)}');
      expect(_contrast(d.muted2, d.ground) >= 4.5, isTrue, reason: '${d.key} muted2');
    }
    expect(darkSetFor('nope').key, 'night');
  });

  testWidgets('picking one: kept, and the dark look uses it', (t) async {
    final rig = await start(t);
    await rig.brain.setDarkSet('forest');
    expect(rig.brain.darkKey, 'forest');
    expect(await rig.brain.services.lock.keys.read('dark_set'), 'forest');
    final was = (C.mix, C.darkSet);
    C.mix = 1;
    C.darkSet = darkSetFor('forest');
    expect(C.ground, darkSetFor('forest').ground);
    expect(C.surface, darkSetFor('forest').surface);
    C.mix = was.$1;
    C.darkSet = was.$2;
  });

  for (final key in ['forest', 'black']) {
    testWidgets('4 Nov dark colour: $key', (t) async {
      if (shots) await icons();
      final rig = await start(t);
      t.view.physicalSize = const Size(360 * 3, 1500 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await rig.brain.setLook(Look.dark);
      await settle(t);
      await t.tap(find.byTooltip('প্রোফাইল'));
      await settle(t);
      await t.tap(find.byKey(const Key('more-set-look')));
      await settle(t);
      await t.tap(find.byKey(Key('dark-$key')));
      await settle(t);
      expect(rig.brain.darkKey, key);
      expect(C.ground, darkSetFor(key).ground);
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/dark1104-look-$key.png'));
    });
  }
}


