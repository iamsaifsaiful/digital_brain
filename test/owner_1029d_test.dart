// Owner, 29 Oct (a member's screen recording): the place follows the phone
// even after one was chosen by hand; a search for any place in the world;
// that country's holidays abroad; the qibla from where the phone is;
// the medicine form in the member's order with food and the four parts of
// the day; Banglish typed; a long today list folds; English everywhere.
import 'package:digital_brain/logic/calendar_bd.dart';
import 'package:digital_brain/logic/holidays_abroad.dart';
import 'package:digital_brain/logic/lang.dart';
import 'package:digital_brain/logic/phrases.dart' show describe;
import 'package:digital_brain/logic/standard.dart';
import 'package:digital_brain/logic/weather.dart' show weatherWords;
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/health_screens.dart' show editMedicine;
import 'package:digital_brain/screens/place_picker.dart';
import 'package:digital_brain/services/weather.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, settle, start;

void main() {
  group('Banglish typed', () {
    test('words and names written in Bangla; an English sentence stays', () {
      expect(standardSpeech('khalid amar kache 1 hajar taka pay'), 'খালিদ আমার কাছে 1 হাজার টাকা পায়');
      expect(standardSpeech('nusrat ke 300 taka ferot dilam'), 'নুসরাত কে 300 টাকা ফেরত দিলাম');
      expect(standardSpeech('Add a task for tomorrow'), 'Add a task for tomorrow');
      // A person already known by sound keeps the spelling kept.
      expect(standardSpeech('rahim ke 500 taka dilam', names: ['রহিম উদ্দিন']), 'রহিম কে 500 টাকা দিলাম');
      expect(soundKey('khalid'), soundKey('খালিদ'));
      expect(knownBySound('hasan', ['হাসান', 'করিম']), 'হাসান');
      expect(knownBySound('hasan', ['হাসান', 'হোসেন']), isNull, reason: 'two sound alike: none chosen');
    });

    test('the chat: owed by Banglish; paying back without "শোধ"; "সব টাকা" is all of it', () async {
      final rig = Rig();
      await rig.brain.load();
      final chat = ChatController(rig.brain);
      expect(await chat.hear('khalid amar kache 1 hajar taka pay'), contains('খালিদকে আপনার ১,০০০ টাকা দিতে হবে'));
      await chat.hear('হ্যাঁ');
      expect(await chat.hear('খালিদকে ৫০০ টাকা দিয়ে দিছি'), contains('শোধ করলেন, তাই তো'));
      await chat.hear('হ্যাঁ');
      expect(await chat.hear('খালিদকে সব টাকা দিয়ে দিছি'), contains('৫০০ টাকা শোধ করলেন'));
      expect(await chat.hear('হ্যাঁ'), contains('মিটে গেছে'));
      expect([for (final e in rig.brain.data.ledger) (e.kind, e.amount)], [(LedgerKind.borrowed, 1000), (LedgerKind.repaid, 500), (LedgerKind.repaid, 500)]);
    });
  });

  group('the place', () {
    test('chosen by hand, kept nearby; far away, the phone is followed again', () async {
      final rig = Rig();
      await rig.brain.load();
      final b = rig.brain..placeStatus = () async => {'fine': true, 'service': true};
      b.whereAmI = () async => (22.87, 91.10); // নোয়াখালী
      await b.setDistrict('ঢাকা');
      expect(b.autoPlace, isFalse);
      expect(await b.refreshPlace(force: true), isNull, reason: 'where the phone was when chosen is kept');
      expect(b.district, 'ঢাকা');
      expect(await b.refreshPlace(force: true), isNull, reason: 'still there');
      // Gone to Chattogram: following the phone again.
      b.whereAmI = () async => (22.35, 91.78);
      expect(await b.refreshPlace(force: true), 'চট্টগ্রাম');
      expect(b.autoPlace, isTrue);
    });

    testWidgets('search: the app\'s own places as typed, any other from the weather service', (t) async {
      final rig = await start(t);
      final b = rig.brain;
      final w = b.services.weather as FakeWeather;
      w.hits = const [PlaceHit('Bucharest', 44.4268, 26.1025, area: 'Bucharest', country: 'Romania', countryCode: 'RO')];
      w.offset = 120;
      expect(knownMatches('নোয়া').map((p) => p.name), contains('নোয়াখালী'));
      expect(knownMatches('dub').map((p) => p.name), contains('দুবাই'));
      PlacePick? got;
      final ctx = t.element(find.byTooltip('বলুন').first);
      final f = pickPlace(ctx).then((v) => got = v);
      await settle(t);
      expect(find.byKey(const Key('place-auto')), findsOneWidget);
      await t.enterText(find.byKey(const Key('place-search')), 'Buch');
      await t.pump(const Duration(milliseconds: 600));
      await settle(t);
      expect(find.text('Romania'), findsNothing);
      expect(find.text('Bucharest, Romania'), findsOneWidget);
      await t.tap(find.byKey(const Key('place-hit-0')));
      await settle(t);
      await f;
      final p = (got as PickedPlace).place;
      expect((p.name, p.tz, p.cc, p.abroad), ('Bucharest', 120, 'RO', true));
      expect(placeNamed(p.key).cc, 'RO', reason: 'the country is kept with the place');
    });
  });

  group('holidays abroad', () {
    test('Saudi Arabia: Eid from the Hijri calendar and the national days', () {
      final hs = builtInHolidays('SA', 2027)!;
      expect(hs.where((h) => h.name == 'Saudi National Day').single.date, DateTime(2027, 9, 23));
      expect(hs.where((h) => h.name == 'Eid al-Fitr').length, 3);
      expect(builtInHolidays('RO', 2027), isNull, reason: 'asked from the web');
    });

    testWidgets('home: the country\'s holidays, not Bangladesh\'s', (t) async {
      final rig = await start(t);
      final b = rig.brain;
      final w = b.services.weather as FakeWeather;
      w.days = {
        'RO': [AbroadHoliday(DateTime(2026, 11, 30), "Saint Andrew's Day", local: 'Sfântul Andrei'), AbroadHoliday(DateTime(2026, 12, 1), 'National Day', local: 'Ziua Națională')],
      };
      await b.setDistrict(const Place('Bucharest', 44.4268, 26.1025, tz: 120, region: 'mwl', cc: 'RO').key);
      await b.refreshHolidaysAbroad();
      await settle(t);
      expect(b.holidaysAbroad(b.services.now()).map((h) => h.name), ["Saint Andrew's Day", 'National Day']);
      await t.scrollUntilVisible(find.byKey(const Key('home-holidays-abroad')), 300, scrollable: find.byType(Scrollable).first);
      expect(find.text("Saint Andrew's Day"), findsOneWidget);
      expect(find.byKey(const Key('home-holidays')), findsNothing);
      // Kept: not asked again.
      final asked = w.holidayAsks;
      await b.refreshHolidaysAbroad();
      expect(w.holidayAsks, asked);
    });
  });

  testWidgets('medicine form: whose, name, food, times a day, then the times by part of day', (t) async {
    final rig = await start(t);
    editMedicine(t.element(find.byTooltip('বলুন').first), null);
    await settle(t);
    double y(String text) => t.getTopLeft(find.text(text).first).dy;
    expect(y('কার জন্য'), lessThan(y('ওষুধের নাম')));
    expect(y('ওষুধের নাম'), lessThan(y('খাবারের আগে না পরে')));
    expect(y('খাবারের আগে না পরে'), lessThan(y('দিনে কয়বার')));
    for (final part in ['সকাল', 'দুপুর', 'বিকাল', 'রাত', 'অন্য সময়']) {
      expect(find.text(part, skipOffstage: false), findsOneWidget, reason: part);
    }
    await t.enterText(find.byKey(const Key('med-name')), 'সেকলো');
    await t.tap(find.byKey(const Key('med-meal-before')));
    await t.pump();
    await t.ensureVisible(find.text('রাখুন'));
    await t.tap(find.text('রাখুন'));
    await settle(t);
    final m = rig.brain.data.medicines.single;
    expect(m.meal, 'before');
    expect(rig.brain.data.reminders.where((r) => m.reminderIds.contains(r.id)).every((r) => r.note.contains('খাবারের আগে')), isTrue);
  });

  testWidgets('home: a long today list folds to four, "আরও দেখুন" opens it', (t) async {
    final rig = await start(t);
    final now = rig.brain.services.now();
    for (var i = 0; i < 8; i++) {
      await rig.brain.saveTask(Task(title: 'কাজ $i', due: DateTime(now.year, now.month, now.day)));
    }
    await settle(t);
    final more = find.byKey(const Key('home-today-more'));
    await t.scrollUntilVisible(more, 200, scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(more);
    await settle(t);
    int rows() => find.byWidgetPredicate((w) => w is Text && RegExp(r'^কাজ \d$').hasMatch(w.data ?? ''), skipOffstage: false).evaluate().length;
    final folded = rows();
    expect(find.text('আরও ৩টা দেখুন', skipOffstage: false), findsOneWidget);
    await t.tap(more);
    await settle(t);
    expect(rows(), folded + 3);
    expect(find.text('কম দেখুন', skipOffstage: false), findsOneWidget);
  });

  test('English: the weather, a ledger sentence', () {
    isEn = true;
    try {
      expect(weatherWords(61), 'Rain');
      expect(weatherWords(2), 'Partly cloudy');
      expect(describe(LedgerKind.repaid, 'Khalid', 500), 'you paid Khalid back ৳500');
    } finally {
      isEn = false;
    }
  });
}
