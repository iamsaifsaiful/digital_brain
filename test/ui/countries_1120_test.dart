// Owner, 20 Nov: "ছুটির সেকশনে, বিশ্বের সব দেশ থাকতে হবে, জাতিসংঘের
// তালিকায় সকল দেশ। লোকেশনেও তাই। আবহাওয়ার জন্যেও তাই।" — and no
// "যেসব দেশে অনেক বাংলাদেশি থাকেন" in the holiday sheet.
// SHOTS=1 --update-goldens writes test/ui/shots/countries/*.png.
import 'dart:io';

import 'package:digital_brain/logic/calendar_bd.dart';
import 'package:digital_brain/logic/countries.dart';
import 'package:digital_brain/logic/holiday_mix.dart';
import 'package:digital_brain/logic/strings_en.dart';
import 'package:digital_brain/logic/world_places.dart';
import 'package:digital_brain/screens/place_picker.dart';
import 'package:digital_brain/services/weather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;
import 'tutorial_shots_test.dart' show rig0;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> shot(WidgetTester t, String name) async {
  if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/countries/$name.png'));
}

void main() {
  test('the UN list: 193 members and two observers, each once, named in both languages', () {
    expect(worldCountries.where((c) => c.un && !c.observer).length, 193);
    expect(worldCountries.where((c) => c.observer).map((c) => c.code), unorderedEquals(['PS', 'VA']));
    expect(worldCountries.map((c) => c.code).toSet().length, worldCountries.length);
    for (final c in worldCountries) {
      expect(continents.containsKey(c.continent), isTrue, reason: c.code);
      expect(enStrings.containsKey(c.bn), isTrue, reason: c.bn);
      expect(enStrings.containsKey(c.capitalBn), isTrue, reason: c.capitalBn);
      expect(c.lat.abs() <= 90 && c.lon.abs() <= 180, isTrue, reason: c.code);
    }
    for (final k in continents.values) {
      expect(enStrings.containsKey(k), isTrue, reason: k);
    }
  });

  test('found by Bengali, English or capital', () {
    expect(searchCountries('জাম্বিয়া'), ['ZM']);
    expect(searchCountries('tuval'), ['TV']);
    expect(searchCountries('ouagad'), ['BF']);
    expect(countryName('KI'), 'কিরিবাতি');
  });

  test('main days for a country with no list on the web', () {
    final af = mainHolidays('AF', 2027)!;
    expect(af.map((h) => h.name), containsAll(['Nowruz', 'Independence Day', 'Eid al-Fitr', 'Eid al-Adha']));
    final zm = mainHolidays('ZM', 2027)!;
    expect(zm.map((h) => h.name), containsAll(["New Year's Day", 'Good Friday', 'Independence Day', 'Christmas Day']));
    expect(zm.firstWhere((h) => h.name == 'Good Friday').date, DateTime(2027, 3, 26));
    expect(easterSunday(2026), DateTime(2026, 4, 5));
    expect(mainHolidays('XX', 2027), isNull);
  });

  test('a country opens to its capital and the cities the app knows', () {
    final it = placesIn(countryOf('IT')!);
    expect(it.first.name, 'রোম');
    expect(it.map((p) => p.name), contains('মিলান'));
    expect(it.where((p) => p.name == 'রোম').length, 1);
    final zm = capitalPlace(countryOf('ZM')!);
    expect(zm.country, 'ZM');
    expect(zm.abroad, isTrue);
    expect(placeNamed(zm.key).name, 'লুসাকা');
  });

  testWidgets('holidays: every country by continent, no "many Bangladeshis" row; a country with main days only', (t) async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 20, 10, 10);
    t.view.physicalSize = const Size(1170, 2532);
    final b = rig.brain;
    final dubai = worldPlaces.firstWhere((p) => p.name == 'দুবাই');
    await b.setDistrict(dubai.key);
    (b.services.weather as FakeWeather).days['ZM'] = []; // no list on the web
    await b.setHolLists(['@', 'BD', 'ZM', 'INTL']);
    await b.refreshHolidaysAbroad();
    expect(b.holMainOnly('ZM'), isTrue, reason: 'the fake web has no list: worked out on the phone');
    await settle(t);
    final card = find.byKey(const Key('home-holidays'));
    await t.scrollUntilVisible(card, 300, scrollable: find.byType(Scrollable).first);
    await settle(t);
    await t.tap(find.byKey(const Key('hol-lists')));
    await settle(t);
    expect(find.text('যেসব দেশে অনেক বাংলাদেশি থাকেন'), findsNothing);
    expect(find.text('জাতিসংঘের সব দেশ'), findsOneWidget);
    expect(find.text('প্রধান ছুটিগুলো · জাতীয় ও ধর্মীয় দিবস'), findsOneWidget);
    await shot(t, '1-holiday-sheet');
    await t.drag(find.byKey(const Key('hol-search')), const Offset(0, -900));
    await settle(t);
    await shot(t, '2-holiday-list');
    await t.enterText(find.byKey(const Key('hol-search')), 'ki');
    await settle(t);
    expect(find.byKey(const Key('hol-add-KI')), findsOneWidget);
    expect(find.byKey(const Key('hol-add-PK')), findsOneWidget, reason: 'Pakistan has "ki" inside');
    await t.tap(find.byKey(const Key('hol-add-KI')));
    await settle(t);
    await t.tap(find.byKey(const Key('hol-done')));
    await settle(t);
    expect(b.holLists, ['@', 'BD', 'ZM', 'KI', 'INTL']);
    debugDisableShadows = true;
  });

  testWidgets('location: all countries by continent; one opens to its capital, cities and a search in it', (t) async {
    final rig = await rig0(t);
    await rig.brain.setDistrict('ঢাকা');
    (rig.brain.services.weather as FakeWeather).hits = const [
      PlaceHit('Ndola', -12.97, 28.64, area: 'Copperbelt', country: 'Zambia', countryCode: 'ZM'),
      PlaceHit('Ndé', 5.1, 10.5, area: 'West', country: 'Cameroon', countryCode: 'CM'),
    ];
    final ctx = t.element(find.byTooltip('বলুন'));
    PlacePick? got;
    pickPlace(ctx).then((v) => got = v);
    await settle(t);
    await t.scrollUntilVisible(find.byKey(const Key('place-country-AF')), 400, scrollable: find.byType(Scrollable).last);
    await settle(t);
    await t.drag(find.byType(Scrollable).last, const Offset(0, 330));
    await settle(t);
    expect(find.text('এশিয়া'), findsOneWidget);
    await shot(t, '3-location-countries');
    await t.enterText(find.byKey(const Key('place-search')), 'জাম');
    await t.pump(const Duration(milliseconds: 600));
    await settle(t);
    expect(find.byKey(const Key('place-country-ZM')), findsOneWidget);
    await shot(t, '4-location-search');
    await t.tap(find.byKey(const Key('place-country-ZM')));
    await settle(t);
    expect(find.byKey(const Key('place-capital')), findsOneWidget);
    expect(find.text('লুসাকা'), findsOneWidget);
    await t.enterText(find.byKey(const Key('place-search')), 'nd');
    await t.pump(const Duration(milliseconds: 600));
    await settle(t);
    expect(find.text('Ndola'), findsOneWidget);
    expect(find.text('Ndé'), findsNothing, reason: 'only towns in that country');
    await t.enterText(find.byKey(const Key('place-search')), '');
    await t.pump(const Duration(milliseconds: 600));
    await settle(t);
    await shot(t, '5-location-zambia');
    await t.tap(find.byKey(const Key('place-capital')));
    await settle(t);
    final p = (got as PickedPlace).place;
    expect(p.name, 'লুসাকা');
    expect(p.country, 'ZM');
    await t.pump(const Duration(seconds: 1));
    debugDisableShadows = true;
  });
}
