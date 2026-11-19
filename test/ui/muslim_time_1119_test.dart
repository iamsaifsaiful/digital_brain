// Owner, 19 Nov: "হোমে, নামাজে ওয়াক্ত, ক্যালেন্ডারে নামাজের সময় সূচি লাগবে
// না। এটা কম্পাস মেনুর ভেতরে নিয়ে যাও … সেহরি, ইফতারের সময় সূচিও". The
// page is now মুসলিম টাইম: নামাজ, সেহরি ও ইফতার, কিবলা.
// SHOTS=1 flutter test test/ui/muslim_time_1119_test.dart --update-goldens
// writes test/ui/shots/muslim_time/.
import 'dart:io';

import 'package:digital_brain/logic/calendar_bd.dart';
import 'package:digital_brain/logic/compass.dart';
import 'package:digital_brain/screens/calendar_screen.dart';
import 'package:digital_brain/screens/ibadah_screen.dart';
import 'package:digital_brain/services/compass.dart';
import 'package:digital_brain/ui/theme.dart' show Look;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> _shot(WidgetTester t, String name) async {
  if (!shots) return;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/muslim_time/$name.png'));
  // Shadows back off before the test ends (the binding checks it).
  debugDisableShadows = true;
}

void main() {
  setUp(() async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
  });

  Future<dynamic> openPage(WidgetTester t, {DateTime? at, IbadahTab tab = IbadahTab.prayer, bool dark = false}) async {
    final rig = await start(t);
    rig.nowAt = at ?? DateTime(2026, 11, 19, 15, 5);
    if (dark) await rig.brain.setLook(Look.dark);
    await rig.brain.setUserName('সাইফুল');
    await settle(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => IbadahScreen(tab: tab)));
    await settle(t);
    return rig;
  }

  testWidgets('Home and the calendar have no prayer times any more', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 19, 15, 5);
    await settle(t);
    expect(find.byKey(const Key('home-slot')), findsNothing);
    await _shot(t, '0-home');
    if (shots) debugDisableShadows = false;
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
    await settle(t);
    expect(find.textContaining('নামাজের সময়'), findsNothing);
    expect(find.text('মাগরিব'), findsNothing);
    debugDisableShadows = true;
  });

  testWidgets('নামাজ: the next prayer, the five times, the waqt now', (t) async {
    await openPage(t);
    expect(find.text('মুসলিম টাইম'), findsOneWidget);
    expect(find.byKey(const Key('ibadah-next')), findsOneWidget);
    expect(find.text('এখন'), findsOneWidget);
    await _shot(t, '1-prayer');
  });

  testWidgets('সেহরি ও ইফতার: today and the Ramadan timetable', (t) async {
    await openPage(t, tab: IbadahTab.fasting);
    expect(find.byKey(const Key('ibadah-ramadan-in')), findsOneWidget);
    expect(find.byKey(const Key('ibadah-timetable')), findsOneWidget);
    await _shot(t, '2-sehri-iftar');
  });

  testWidgets('in Ramadan: today is marked in the timetable', (t) async {
    // 1448 Ramadan starts about 8-9 Feb 2027.
    await openPage(t, at: DateTime(2027, 2, 20, 11), tab: IbadahTab.fasting);
    expect(hijriDate(DateTime(2027, 2, 20)).isRamadan, isTrue);
    await t.drag(find.byType(ListView).last, const Offset(0, -560));
    await settle(t);
    await _shot(t, '3-in-ramadan');
  });

  testWidgets('কিবলা: the compass inside the page', (t) async {
    final rig = await openPage(t, tab: IbadahTab.qibla);
    final dhaka = placeNamed(rig.brain.district);
    (rig.brain.services.compass as FakeCompass).point(Heading(qiblaFrom(dhaka.lat, dhaka.lon) - 18));
    await settle(t);
    expect(find.byKey(const Key('compass-qibla')), findsOneWidget);
    await _shot(t, '4-qibla');
  });

  testWidgets('pinned to Home by choice: the next prayer, sehri and iftar', (t) async {
    final rig = await openPage(t);
    await t.tap(find.byKey(const Key('ibadah-pin')));
    await settle(t);
    await t.tap(find.byKey(const Key('pin-home_waqt')));
    await settle(t);
    await t.tap(find.byKey(const Key('pin-home_iftar')));
    await settle(t);
    expect(rig.brain.flag('home_waqt'), isTrue);
    expect(rig.brain.flag('home_sehri'), isFalse);
    await _shot(t, '6-pin-sheet');
    if (shots) debugDisableShadows = false;
    await t.tap(find.byKey(const Key('pin-home_sehri')));
    await settle(t);
    Navigator.of(t.element(find.text('হোমে দেখান').first)).popUntil((r) => r.isFirst);
    await settle(t);
    expect(find.byKey(const Key('home-slot')), findsOneWidget);
    expect(find.textContaining('আসর'), findsWidgets);
    expect(find.textContaining('ইফতার'), findsWidgets);
    await _shot(t, '7-home-pinned');
  });

  testWidgets('dark look', (t) async {
    await openPage(t, dark: true);
    await _shot(t, '5-prayer-dark');
  });
}
