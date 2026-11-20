// Owner, 19 Nov: সামনের ছুটি with the international days and the
// country's own, one or both, in one list; abroad "অন্তত দুটি দেশের ছুটির
// তারিখ". SHOTS=1 --update-goldens writes test/ui/shots/holidays/.
import 'dart:io';

import 'package:digital_brain/logic/calendar_bd.dart';
import 'package:digital_brain/logic/holiday_mix.dart';
import 'package:digital_brain/logic/holidays_abroad.dart';
import 'package:digital_brain/logic/world_places.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

void main() {
  final day = DateTime(2026, 11, 19);

  test('one list by date; the same day in two lists is one row', () {
    final ae = builtInHolidays('AE', 2026)! + builtInHolidays('AE', 2027)!;
    final rows = mixHolidays(day, countries: ['AE', 'BD'], abroad: {'AE': ae}, intl: true, count: 5);
    expect(rows.map((r) => r.start), [DateTime(2026, 11, 20), DateTime(2026, 12, 2), DateTime(2026, 12, 3), DateTime(2026, 12, 10), DateTime(2026, 12, 16)].take(rows.length).toList()..length);
    final national = rows.firstWhere((r) => r.name == 'National Day');
    expect(national.days, 2, reason: 'next days of the same name joined');
    expect(national.from, ['AE']);
    expect(rows.firstWhere((r) => r.start == DateTime(2026, 12, 16)).from, ['BD']);
    final all = mixHolidays(day, countries: ['AE', 'BD'], abroad: {'AE': ae}, intl: true, count: 20);
    expect(all.where((r) => r.start == DateTime(2026, 12, 25)).single.from, ['BD', 'INTL'], reason: 'Christmas once');
    expect(all.where((r) => r.start == DateTime(2027, 1, 1)).single.from, ['AE', 'INTL']);
  });

  test('each list keeps its next day, however many international days come first', () {
    final ro = [AbroadHoliday(DateTime(2027, 1, 24), 'Union Day')];
    final rows = mixHolidays(day, countries: ['RO'], abroad: {'RO': ro}, intl: true, count: 3);
    expect(rows.map((r) => r.name), contains('Union Day'));
    expect(rows.length, 3);
  });

  test('only one list: only its days', () {
    final bd = mixHolidays(day, countries: ['BD'], abroad: const {}, count: 3);
    expect(bd.every((r) => r.from.single == 'BD'), isTrue);
    final intl = mixHolidays(day, countries: const [], abroad: const {}, intl: true, count: 3);
    expect(intl.map((r) => r.name), ['বিশ্ব শিশু দিবস', 'আন্তর্জাতিক প্রতিবন্ধী দিবস', 'মানবাধিকার দিবস']);
  });

  test('countries found in Bangla or English', () {
    expect(searchCountries('সৌদি'), ['SA']);
    expect(searchCountries('ital'), ['IT']);
    expect(searchCountries('arab'), containsAll(['SA', 'AE']));
  });

  testWidgets('home: Dubai with Bangladesh and the world; chips hide; the sheet adds a country', (t) async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 19, 17, 10);
    t.view.physicalSize = const Size(1170, 2532);
    final b = rig.brain;
    final dubai = worldPlaces.firstWhere((p) => p.name == 'দুবাই');
    await b.setDistrict(dubai.key);
    await b.refreshHolidaysAbroad();
    await settle(t);
    final card = find.byKey(const Key('home-holidays'));
    await t.scrollUntilVisible(card, 300, scrollable: find.byType(Scrollable).first);
    await settle(t);
    await Scrollable.ensureVisible(t.element(find.text(t.any(find.text('Upcoming holidays')) ? 'Upcoming holidays' : 'সামনের ছুটি').first), alignment: 0.06);
    await settle(t);
    expect(find.byKey(const Key('hol-chip-AE')), findsOneWidget);
    expect(find.byKey(const Key('hol-chip-BD')), findsOneWidget);
    expect(find.byKey(const Key('hol-chip-INTL')), findsOneWidget);
    expect(find.text('জাতীয় দিবস'), findsOneWidget);
    expect(find.text('মহান বিজয় দিবস'), findsOneWidget);
    expect(find.text('বিশ্ব শিশু দিবস'), findsOneWidget);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/holidays/1-dubai-all.png'));

    await t.tap(find.byKey(const Key('hol-chip-INTL')));
    await settle(t);
    expect(find.text('বিশ্ব শিশু দিবস'), findsNothing);
    expect(find.text('জাতীয় দিবস'), findsOneWidget);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/holidays/2-dubai-two.png'));
    await t.tap(find.byKey(const Key('hol-chip-INTL')));
    await settle(t);

    await t.tap(find.byKey(const Key('hol-lists')));
    await settle(t);
    expect(find.text('কোন কোন দেশের ছুটি দেখাবে'), findsOneWidget);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/holidays/3-sheet.png'));
    await t.ensureVisible(find.byKey(const Key('hol-add-SA')));
    await settle(t);
    await t.tap(find.byKey(const Key('hol-add-SA')));
    await settle(t);
    await t.tap(find.byKey(const Key('hol-done')));
    await settle(t);
    expect(b.holLists, ['@', 'BD', 'SA', 'INTL']);
    expect(b.holCountriesShown, ['AE', 'BD', 'SA']);
    expect(find.byKey(const Key('hol-chip-SA')), findsOneWidget);
    debugDisableShadows = true;
  });

  testWidgets('home in Bangladesh: Bangladesh and the world by default', (t) async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 19, 17, 10);
    final b = rig.brain;
    expect(placeNamed(b.district).country, 'BD');
    await b.setEnglish(false); // redraw on the new day
    await settle(t);
    final card = find.byKey(const Key('home-holidays'));
    await t.scrollUntilVisible(card, 300, scrollable: find.byType(Scrollable).first);
    await settle(t);
    await Scrollable.ensureVisible(t.element(find.text(t.any(find.text('Upcoming holidays')) ? 'Upcoming holidays' : 'সামনের ছুটি').first), alignment: 0.06);
    await settle(t);
    expect(b.holCountriesShown, ['BD']);
    expect(find.byKey(const Key('hol-chip-BD')), findsOneWidget);
    expect(find.text('মহান বিজয় দিবস'), findsOneWidget);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/holidays/4-bangladesh.png'));
    await b.setEnglish(true);
    await settle(t);
    expect(find.text('Upcoming holidays'), findsOneWidget);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/holidays/5-english.png'));
    await b.setEnglish(false);
    debugDisableShadows = true;
  });
}
