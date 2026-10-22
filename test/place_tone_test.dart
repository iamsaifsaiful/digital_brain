import 'dart:io';

import 'package:digital_brain/logic/calendar_bd.dart';
import 'package:digital_brain/logic/weather.dart';
import 'package:digital_brain/screens/sound_screen.dart';
import 'package:digital_brain/services/notifications.dart' show FakeNotifier;
import 'package:digital_brain/services/weather.dart';
import 'package:digital_brain/screens/settings_parts.dart' show UserPhoto;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  test('all 64 districts, no name twice; the nearest district town to a point', () {
    expect(bdPlaces.length, 64);
    expect(bdPlaces.map((p) => p.name).toSet().length, 64);
    for (final p in bdPlaces) {
      expect(p.lat, inInclusiveRange(20.5, 26.7), reason: p.name);
      expect(p.lon, inInclusiveRange(88.0, 92.7), reason: p.name);
    }
    expect(nearestPlace(23.78, 90.40)!.$1.name, 'ঢাকা', reason: 'Dhaka city');
    expect(nearestPlace(22.33, 91.83)!.$1.name, 'চট্টগ্রাম');
    expect(nearestPlace(24.44, 90.78)!.$1.name, 'কিশোরগঞ্জ', reason: 'a district only in the full list');
    expect(nearestPlace(26.34, 88.55)!.$1.name, 'পঞ্চগড়');
    expect(nearestPlace(51.5, -0.12), isNull, reason: 'London: outside Bangladesh, the place stays');
  });

  testWidgets('district follows the phone: moved to Sylhet → সিলেট; chosen by hand → stays', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    (double, double)? at = (24.90, 91.87);
    var asked = 0;
    b.whereAmI = () async {
      asked++;
      return at;
    };
    expect(b.autoPlace, isTrue, reason: 'on unless turned off');
    expect(await b.refreshPlace(force: true), 'সিলেট');
    expect(b.district, 'সিলেট');
    expect(b.autoPlace, isTrue, reason: 'moving by itself keeps following');
    at = (22.36, 91.78);
    expect(await b.refreshPlace(), isNull, reason: 'not again within 20 minutes');
    expect(asked, 1);
    expect(await b.refreshPlace(force: true), 'চট্টগ্রাম');
    // No permission / no fix: nothing changes.
    at = null;
    expect(await b.refreshPlace(force: true), isNull);
    expect(b.district, 'চট্টগ্রাম');
    // Picked by hand: the phone no longer moves it.
    await b.setDistrict('খুলনা');
    expect(b.autoPlace, isFalse);
    at = (24.90, 91.87);
    expect(await b.refreshPlace(force: true), isNull);
    expect(b.district, 'খুলনা');
    // Turned on again.
    await b.setAutoPlace(true);
    expect(b.district, 'সিলেট');
  });

  testWidgets('home: the weather sits under the date (not over it), with the place', (t) async {
    final rig = await start(t);
    (rig.brain.services.weather as FakeWeather).answer =
        Weather(temp: 27.6, feels: 30.2, min: 23, max: 31, humidity: 78, code: 2, place: 'ঢাকা', at: DateTime(2026, 10, 18, 22, 30));
    await rig.brain.refreshWeather();
    await settle(t);
    final temp = find.byKey(const Key('home-temp'));
    expect(temp, findsOneWidget);
    expect(find.descendant(of: temp, matching: find.textContaining('ঢাকা')), findsOneWidget);
    final date = find.textContaining(RegExp(r'^\S+বার, '));
    expect(date, findsOneWidget);
    final dateBox = t.getRect(date), tempBox = t.getRect(temp);
    expect(tempBox.top, greaterThanOrEqualTo(dateBox.bottom), reason: 'below the date lines');
    expect(tempBox.overlaps(t.getRect(find.byType(UserPhoto).first)), isFalse);
    if (Platform.environment['SHOTS'] == '1') await expectLater(find.byType(MaterialApp), matchesGoldenFile('dark/shots/home-weather.png'));
  });

  testWidgets('রিংটোন: add your own audio file → plays, kept on রাখুন; the earlier own file is removed', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final n = b.services.notifier as FakeNotifier;
    n.pickedFile = (uri: 'content://media/external/audio/media/91', title: 'আমার গান', error: '');
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const SoundScreen()));
    await settle(t);
    await t.ensureVisible(find.byKey(const Key('tone-file')));
    await t.tap(find.byKey(const Key('tone-file')));
    await settle(t);
    expect(find.text('আমার গান'), findsOneWidget);
    expect(n.played, contains('content://media/external/audio/media/91'));
    await t.tap(find.text('রাখুন'));
    await settle(t);
    expect(n.soundUri, 'content://media/external/audio/media/91');
    expect(b.alarmSoundTitle, 'আমার গান');
    expect(n.removedSounds, isEmpty);

    // Another file replaces it: the first copy is removed.
    await t.pump(const Duration(seconds: 5)); // the toast goes
    await settle(t);
    n.pickedFile = (uri: 'content://media/external/audio/media/92', title: 'আজান', error: '');
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const SoundScreen()));
    await settle(t);
    await t.ensureVisible(find.byKey(const Key('tone-file')));
    await t.tap(find.byKey(const Key('tone-file')));
    await settle(t);
    await t.tap(find.text('রাখুন'));
    await settle(t);
    expect(n.soundUri, 'content://media/external/audio/media/92');
    expect(n.removedSounds, ['content://media/external/audio/media/91']);
  });

  testWidgets('রিংটোন: a file too big says so; one added but not kept is removed on leaving', (t) async {
    final rig = await start(t);
    final n = rig.brain.services.notifier as FakeNotifier;
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const SoundScreen()));
    await settle(t);
    n.pickedFile = (uri: '', title: '', error: 'too_big');
    await t.ensureVisible(find.byKey(const Key('tone-file')));
    await t.tap(find.byKey(const Key('tone-file')));
    await settle(t);
    expect(find.textContaining('অনেক বড়'), findsOneWidget);
    n.pickedFile = (uri: 'content://media/external/audio/media/77', title: 'ট্রায়াল', error: '');
    await t.tap(find.byKey(const Key('tone-file')));
    await settle(t);
    await t.binding.handlePopRoute();
    await settle(t);
    expect(n.soundUri, isNull);
    expect(n.removedSounds, ['content://media/external/audio/media/77']);
  });
}
