// The three ways of drawing the room ring (owner, 20 Nov), side by side.
// With SHOTS=1 --update-goldens: test/ui/shots/ring-<style>-<look>.png.
import 'package:digital_brain/screens/store_screen.dart' show roomStyle;
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'home_final_shots_test.dart' show icons, shots;
import 'store_1120_shots_test.dart' show withPages;

void main() {
  for (final style in [0, 1, 2]) {
    for (final look in [Look.light, Look.dark]) {
      testWidgets('ring style $style, ${look.name}', (t) async {
        if (shots) await icons();
        roomStyle = style;
        addTearDown(() => roomStyle = 2);
        final rig = await start(t);
        t.view.physicalSize = const Size(390 * 3, 860 * 3);
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        rig.nowAt = DateTime(2026, 10, 24, 18, 34);
        await rig.brain.setLook(look);
        await withPages(rig);
        await settle(t);
        await t.tap(find.text('আমার ফাইল').last);
        await settle(t);
        expect(find.byKey(const Key('store-room')), findsOneWidget);
        if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/ring-$style-${look.name}.png'));
      });
    }
  }
}
