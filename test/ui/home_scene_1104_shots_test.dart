// The home picture of 4 Nov: seasons, regions, the moon, weather and the
// special days. With SHOTS=1 --update-goldens the screens go to
// test/ui/shots/scene1104-*.png.
import 'package:digital_brain/logic/home_scene.dart';
import 'package:digital_brain/logic/weather.dart';
import 'package:digital_brain/ui/scene_layers.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'home_final_shots_test.dart' show icons, sample, shots;

void main() {
  final cases = <(String, String, DateTime, int?)>[
    ('hemonto-day', 'auto', DateTime(2026, 11, 4, 10, 30), null),
    ('hemonto-night', 'auto', DateTime(2026, 11, 4, 21, 10), null),
    ('borsha-rain', 'borsha', DateTime(2026, 7, 20, 11, 0), 63),
    ('sheet-fog', 'sheet', DateTime(2027, 1, 10, 8, 30), 45),
    ('shorot-evening', 'shorot', DateTime(2026, 9, 20, 17, 50), null),
    ('ekushey', 'boshonto', DateTime(2027, 2, 21, 7, 30), null),
    ('victory', 'sheet', DateTime(2026, 12, 16, 11, 0), null),
    ('cox-day', 'cox', DateTime(2026, 11, 4, 12, 0), null),
    ('dhaka-night', 'dhaka', DateTime(2026, 11, 4, 22, 0), null),
    ('sylhet-day', 'sylhet', DateTime(2026, 11, 4, 9, 30), null),
  ];
  for (final (name, scene, at, code) in cases) {
    testWidgets('4 Nov home picture: $name', (t) async {
      if (shots) await icons();
      final rig = await start(t);
      t.view.physicalSize = const Size(390 * 3, 900 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      rig.nowAt = at;
      await rig.brain.setLook(Look.light);
      rig.brain.data = sample(rig.nowAt);
      await rig.brain.setPref('home_scene', scene);
      if (code != null) rig.brain.debugWeather(Weather(temp: 27, feels: 29, min: 24, max: 30, humidity: 90, code: code, place: rig.brain.district, at: at));
      // The paintings and the boat are read from the bundle off the test clock.
      await t.runAsync(() async {
        final ctx = t.element(find.byType(MaterialApp).first);
        for (final a in [sceneAsset(sceneFor(scene, at), night: false), sceneAsset(sceneFor(scene, at), night: true), 'assets/sky/boat_day.png', 'assets/sky/boat_night.png']) {
          await precacheImage(AssetImage(a), ctx);
        }
      });
      sceneLive = true;
      addTearDown(() => sceneLive = false);
      await t.pump();
      await t.pump(const Duration(seconds: 3));
      expect(find.byKey(const Key('home-scene')), findsOneWidget);
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/scene1104-$name.png'));
      sceneLive = false;
      await t.pumpWidget(const SizedBox());
      await settle(t);
    });
  }
}
