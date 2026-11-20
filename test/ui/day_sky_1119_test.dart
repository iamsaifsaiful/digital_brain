// Owner, 19 Nov: "ক্যালেন্ডার আবহাওয়া এক সাথে রাখো, এবং এটার সুন্দর একটা নাম
// দাও" and "আবহাওয়া সেলসিয়াস ও ফারেনহাইট স্কেলে দেখাবে". The ঋতুপঞ্জি page:
// today's date and the weather on the picture, then আবহাওয়া | ক্যালেন্ডার.
// SHOTS=1 flutter test test/ui/day_sky_1119_test.dart --update-goldens
// writes test/ui/shots/day_sky/ (gitignored).
import 'dart:io';

import 'package:digital_brain/logic/calendar_bd.dart' show placeNamed;
import 'package:digital_brain/logic/home_scene.dart';
import 'package:digital_brain/logic/lang.dart';
import 'package:digital_brain/logic/weather.dart';
import 'package:digital_brain/screens/weather_screen.dart';
import 'package:digital_brain/services/weather.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import '../weather_1119_test.dart' show cast;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> _scripts() async {
  const dir = '/usr/share/fonts';
  final fonts = {
    'NotoNaskhArabic': '$dir/truetype/noto/NotoNaskhArabic-Regular.ttf',
    'NotoSansCJK': '$dir/opentype/noto/NotoSansCJK-Regular.ttc',
  };
  for (final e in fonts.entries) {
    final f = File(e.value);
    if (!f.existsSync()) continue;
    await (FontLoader(e.key)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
  }
}

void main() {
  setUp(() async {
    if (shots) {
      await four.icons();
      await _scripts();
      debugDisableShadows = false;
    }
  });
  tearDown(() {
    debugDisableShadows = true;
    tempF = false;
    isEn = false;
  });

  for (final dark in [true, false]) {
    testWidgets('ঋতুপঞ্জি: date and weather on top, two tabs, °C/°F (${dark ? 'dark' : 'light'})', (t) async {
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
      final tag = dark ? 'dark' : 'light';
      Future<void> shot(String n) async {
        if (!shots) return;
        final ctx = t.element(find.byType(DaySkyScreen));
        await t.runAsync(() async {
          for (final night in [false, true]) {
            await precacheImage(AssetImage(sceneAsset(sceneFor(b.text('home_scene'), now), night: night)), ctx);
          }
        });
        await settle(t);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/day_sky/$n-$tag.png'));
      }

      // The weather on Home opens the weather tab.
      await t.tap(find.byKey(const Key('home-temp')));
      await settle(t);
      expect(find.byType(DaySkyScreen), findsOneWidget);
      expect(t.widget<Text>(find.byKey(const Key('ds-title'))).data, 'ঋতুপঞ্জি');
      expect(t.widget<Text>(find.byKey(const Key('wx-temp'))).data, '২৭°');
      expect(t.widget<Text>(find.byKey(const Key('wx-other'))).data, '৮১°F');
      expect(find.byKey(const Key('wx-hours')), findsOneWidget);
      await shot('1-weather');

      // The calendar tab: the month with the coming days' weather in it.
      await t.tap(find.descendant(of: find.byKey(const Key('ds-tabs')), matching: find.text('ক্যালেন্ডার')));
      await settle(t);
      expect(find.byKey(const Key('cal-choose')), findsOneWidget);
      expect(find.byKey(const Key('day-2026-11-23')), findsOneWidget);
      await shot('2-calendar');
      final list = find.descendant(of: find.byType(DaySkyScreen), matching: find.byType(ListView)).first;
      await t.drag(list, const Offset(0, -420));
      await settle(t);
      await shot('3-calendar-below');

      // A coming day: its weather in the day's sheet.
      await t.tap(find.byKey(const Key('day-2026-11-23')));
      await settle(t);
      expect(find.byKey(const Key('cal-day-weather')), findsOneWidget);
      await shot('4-day-sheet');
      await t.tapAt(const Offset(200, 60));
      await settle(t);
      await t.drag(list, const Offset(0, 900));
      await settle(t, 30);

      // °F: kept, and the other scale beside it turns to °C.
      await t.tap(find.descendant(of: find.byKey(const Key('ds-tabs')), matching: find.text('আবহাওয়া')));
      await settle(t);
      await t.tap(find.byKey(const Key('wx-unit-f')));
      await settle(t);
      expect(b.text('temp_unit'), 'f');
      expect(t.widget<Text>(find.byKey(const Key('wx-temp'))).data, '৮১°');
      expect(t.widget<Text>(find.byKey(const Key('wx-other'))).data, '২৭°C');
      await shot('5-fahrenheit');

      if (dark) {
        isEn = true;
        await t.tap(find.byKey(const Key('wx-unit-c')));
        await settle(t);
        expect(find.text('Almanac'), findsOneWidget);
        await shot('6-english');
      }
      debugDisableShadows = true;
    });
  }

  // Owner, 20 Nov: "ঋতুপঞ্জির আবহাওয়া ও ক্যালেন্ডার ট্যাব গুলো সোয়াইপ হয় না। সোয়াইপ দরকার".
  testWidgets('ঋতুপঞ্জি: a sideways swipe turns between the two tabs', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 19, 16, 10);
    final b = rig.brain;
    final now = b.services.now();
    final w = b.services.weather as FakeWeather;
    w.answer = cast('ঢাকা', 27, 2, now).now;
    w.casts = {'ঢাকা': cast('ঢাকা', 27, 2, now)};
    await b.refreshWeather();
    await settle(t);
    await t.tap(find.byKey(const Key('home-temp')));
    await settle(t);
    expect(find.byKey(const Key('wx-hours')), findsOneWidget);
    // To the left: the calendar.
    await t.fling(find.byKey(const Key('wx-tip')), const Offset(-300, 0), 1500);
    await settle(t);
    expect(find.byKey(const Key('cal-choose')), findsOneWidget);
    expect(find.byKey(const Key('wx-hours')), findsNothing);
    // A swipe on the month still turns the month, not the tab.
    await t.fling(find.byKey(const Key('day-2026-11-12')), const Offset(-300, 0), 1500);
    await settle(t);
    expect(find.byKey(const Key('cal-choose')), findsOneWidget);
    expect(find.byKey(const Key('day-2026-12-12')), findsOneWidget);
    // To the right: the weather again.
    await t.fling(find.byKey(const Key('cal-choose')), const Offset(300, 0), 1500);
    await settle(t);
    expect(find.byKey(const Key('wx-hours')), findsOneWidget);
    expect(find.byKey(const Key('cal-choose')), findsNothing);
  });
}
