// Owner, 19 Nov: tapping the weather on Home opens the weather page (design
// 1, "ছবির আকাশ"), with other places to add, switch and remove.
// SHOTS=1 --update-goldens writes test/ui/shots/weather/ (gitignored).
import 'dart:io';

import 'package:digital_brain/logic/home_scene.dart';
import 'package:digital_brain/logic/lang.dart';
import 'package:digital_brain/logic/weather.dart';
import 'package:digital_brain/screens/weather_screen.dart';
import 'package:digital_brain/services/weather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;
import 'ui/new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

Forecast cast(String place, double temp, int code, DateTime at) {
  final h0 = DateTime(at.year, at.month, at.day, at.hour);
  return Forecast(
    now: Weather(temp: temp, feels: temp + 1, min: temp - 8, max: temp + 2, humidity: 62, code: code, place: place, at: at),
    hours: [
      for (var i = 0; i < 24; i++)
        HourCast(h0.add(Duration(hours: i)), temp - i * 0.6 + (i > 14 ? (i - 14) * 0.9 : 0), [code, 2, 0, 0, 0, 1, 3, 3, 1, 0][i % 10], day: h0.hour + i >= 6 && h0.hour + i < 17 || h0.hour + i >= 30)
    ],
    days: [
      for (var i = 0; i < 7; i++)
        DayCast(DateTime(at.year, at.month, at.day + i), [code, 0, 0, 3, 61, 2, 0][i], temp - 8 + [0, 0, 1, 1, 2, 0, -1][i], temp + 2 + [0, 1, 1, -1, -2, -1, 0][i],
            rain: [10, 0, 0, 20, 70, 10, 0][i]),
    ],
    wind: 8,
    sunrise: DateTime(at.year, at.month, at.day, 6, 1),
    sunset: DateTime(at.year, at.month, at.day, 17, 12),
  );
}

void main() {
  testWidgets('weather page: opens from Home, adds, switches and removes places', (t) async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
    final rig = await start(t);
    final b = rig.brain;
    final now = b.services.now();
    final w = b.services.weather as FakeWeather;
    w.answer = cast('ঢাকা', 27, 2, now).now;
    w.casts = {'ঢাকা': cast('ঢাকা', 27, 2, now), 'চট্টগ্রাম': cast('চট্টগ্রাম', 28, 0, now), 'সিলেট': cast('সিলেট', 24, 3, now)};
    await b.refreshWeather();
    await settle(t);
    Future<void> shot(String n) async {
      if (!shots) return;
      final ctx = t.element(find.byType(WeatherScreen));
      await t.runAsync(() async {
        for (final night in [false, true]) {
          await precacheImage(AssetImage(sceneAsset(sceneFor(b.text('home_scene'), now), night: night)), ctx);
        }
      });
      await settle(t);
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('ui/shots/weather/$n.png'));
    }

    await t.tap(find.byKey(const Key('home-temp')));
    await settle(t);
    expect(find.byType(WeatherScreen), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('wx-temp'))).data, '২৭°');
    expect(find.byKey(const Key('wx-hours')), findsOneWidget);
    expect(find.text('এখন'), findsOneWidget);
    expect(find.text('৭ দিনের পূর্বাভাস'), findsOneWidget);

    // Add চট্টগ্রাম and সিলেট from the sheet (the district picker's search).
    for (final name in ['চট্টগ্রাম', 'সিলেট']) {
      await t.tap(find.byKey(const Key('wx-places')));
      await settle(t);
      await t.tap(find.byKey(const Key('wx-add')));
      await settle(t);
      expect(find.byKey(const Key('place-auto')), findsNothing, reason: 'no "follow the phone" when adding');
      await t.enterText(find.byKey(const Key('place-search')), name);
      await settle(t);
      await t.tap(find.byKey(Key('place-$name')));
      await settle(t);
      expect(find.byKey(Key('wx-place-$name')), findsOneWidget);
      if (name == 'সিলেট') await shot('2-places');
      // Back to the page.
      await t.tapAt(const Offset(200, 60));
      await settle(t);
    }
    expect(b.weatherPlaces, ['চট্টগ্রাম', 'সিলেট']);
    expect(find.byKey(const Key('wx-chip-চট্টগ্রাম')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('wx-chip-চট্টগ্রাম')), matching: find.text('চট্টগ্রাম ২৮°')), findsOneWidget);
    await shot('1-dhaka');
    final list = find.descendant(of: find.byType(WeatherScreen), matching: find.byType(ListView)).first;
    await t.drag(list, const Offset(0, -520));
    await settle(t);
    expect(find.byKey(const Key('wx-sun')), findsOneWidget);
    await shot('5-below');
    await t.drag(list, const Offset(0, 900));
    await settle(t, 30);

    await t.tap(find.byKey(const Key('wx-chip-চট্টগ্রাম')));
    await settle(t);
    expect(t.widget<Text>(find.byKey(const Key('wx-temp'))).data, '২৮°');
    await shot('3-chattogram');

    // Remove সিলেট.
    await t.tap(find.byKey(const Key('wx-places')));
    await settle(t);
    await t.tap(find.byKey(const Key('wx-remove-সিলেট')));
    await settle(t);
    expect(find.byKey(const Key('wx-place-সিলেট')), findsNothing);
    expect(b.weatherPlaces, ['চট্টগ্রাম']);
    await t.tapAt(const Offset(200, 60));
    await settle(t);

    // English.
    isEn = true;
    addTearDown(() => isEn = false);
    await t.tap(find.byKey(const Key('wx-chip-ঢাকা')));
    await settle(t);
    expect(find.text('Now'), findsOneWidget);
    await shot('4-english');
    isEn = false;
    debugDisableShadows = true;
  });

  testWidgets('weather page offline: says so, no crash', (t) async {
    final rig = await start(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const WeatherScreen()));
    await settle(t);
    expect(find.textContaining('আবহাওয়া আনা গেল না'), findsOneWidget);
    expect(rig.brain.forecastKept(rig.brain.district), isNull);
  });

  test('Open-Meteo forecast is read: hours from now, seven days, wind, sunset', () {
    final j = {
      'current': {'time': '2026-11-19T15:15', 'temperature_2m': 27.2, 'apparent_temperature': 28.1, 'relative_humidity_2m': 62, 'weather_code': 2, 'wind_speed_10m': 8.4},
      'hourly': {
        'time': [for (var h = 0; h < 48; h++) DateTime(2026, 11, 19 + h ~/ 24, h % 24).toIso8601String().substring(0, 16)],
        'temperature_2m': [for (var h = 0; h < 48; h++) 20.0 + h % 24 / 3],
        'weather_code': [for (var h = 0; h < 48; h++) 1],
        'is_day': [for (var h = 0; h < 48; h++) h % 24 >= 6 && h % 24 < 17 ? 1 : 0],
      },
      'daily': {
        'time': [for (var d = 0; d < 7; d++) '2026-11-${19 + d}'],
        'weather_code': [2, 0, 0, 3, 61, 2, 0],
        'temperature_2m_max': [29, 30, 30, 28, 27, 28, 29],
        'temperature_2m_min': [19, 19, 20, 20, 21, 19, 18],
        'precipitation_probability_max': [10, 0, 0, 20, 70, 10, 0],
        'sunrise': ['2026-11-19T06:15'],
        'sunset': ['2026-11-19T17:12'],
      },
    };
    final f = Forecast.fromOpenMeteo(j, 'ঢাকা', DateTime(2026, 11, 19, 15, 15))!;
    expect(f.now.temp, 27.2);
    expect(f.hours.first.at.hour, 15);
    expect(f.hours.length, 24);
    expect(f.hours[3].day, isFalse);
    expect(f.days.length, 7);
    expect(f.days[4].rain, 70);
    expect(f.rain, 10);
    expect(f.wind, 8.4);
    expect(f.sunset, DateTime(2026, 11, 19, 17, 12));
  });
}
