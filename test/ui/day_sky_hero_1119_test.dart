// Owner, 19 Nov: "ক্লিন ডিজাইন" for the top of ঋতুপঞ্জি — the three designs
// side by side. SHOTS=1 --update-goldens writes test/ui/shots/day_sky_hero/.
import 'dart:io';

import 'package:digital_brain/logic/calendar_bd.dart' show placeNamed;
import 'package:digital_brain/logic/home_scene.dart';
import 'package:digital_brain/screens/weather_screen.dart';
import 'package:digital_brain/services/weather.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import '../weather_1119_test.dart' show cast;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

void main() {
  tearDown(() {
    debugDisableShadows = true;
    daySkyHero = 1;
  });
  for (final style in [1, 2, 3]) {
    for (final dark in [true, false]) {
      testWidgets('ঋতুপঞ্জি top, design $style (${dark ? 'dark' : 'light'})', (t) async {
        if (shots) {
          await four.icons();
          debugDisableShadows = false;
        }
        daySkyHero = style;
        final rig = await start(t);
        rig.nowAt = DateTime(2026, 11, 19, 16, 10);
        final b = rig.brain;
        if (dark) await b.setLook(Look.dark);
        final now = b.services.now();
        final w = b.services.weather as FakeWeather;
        w.answer = cast('ঢাকা', 27, 2, now).now;
        w.casts = {'ঢাকা': cast('ঢাকা', 27, 2, now), 'চট্টগ্রাম': cast('চট্টগ্রাম', 28, 0, now)};
        await b.addWeatherPlace(placeNamed('চট্টগ্রাম'));
        await b.refreshWeather();
        await settle(t);
        await t.tap(find.byKey(const Key('home-temp')));
        await settle(t);
        expect(find.byKey(const Key('wx-temp')), findsOneWidget);
        expect(find.byKey(const Key('ds-date')), findsOneWidget);
        if (shots) {
          final ctx = t.element(find.byType(DaySkyScreen));
          await t.runAsync(() async {
            for (final night in [false, true]) {
              await precacheImage(AssetImage(sceneAsset(sceneFor(b.text('home_scene'), now), night: night)), ctx);
            }
          });
          await settle(t);
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/day_sky_hero/design-$style-${dark ? 'dark' : 'light'}.png'));
        }
        debugDisableShadows = true;
      });
    }
  }
}
