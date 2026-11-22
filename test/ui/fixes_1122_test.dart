// Owner, 22 Nov: (1) মুসলিম টাইম's pictures and sections didn't belong
// together, and the qibla compass a little smaller; (2) "এখন কোথায়?" off
// the family / heir pages ("ঠিক ভাবে কাজ করে না"); (3) the medicine form's
// words a little big next to the other pages; (4) "চেহারা ও ভাষা" is now
// "থিম ও ভাষা", its insides redone (two designs to pick from).
// SHOTS=1 flutter test test/ui/fixes_1122_test.dart --update-goldens
// writes test/ui/shots/fixes_1122/.
import 'dart:io';

import 'package:digital_brain/logic/calendar_bd.dart';
import 'package:digital_brain/logic/compass.dart';
import 'package:digital_brain/logic/pro.dart' show medicalOffForTests;
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/compass_screen.dart' show QiblaView;
import 'package:digital_brain/screens/family_screen.dart';
import 'package:digital_brain/screens/ibadah_screen.dart';
import 'package:digital_brain/screens/look_settings.dart';
import 'package:digital_brain/screens/new_item_screen.dart';
import 'package:digital_brain/services/compass.dart';
import 'package:digital_brain/state/brain.dart' show BrainHealth;
import 'package:digital_brain/state/family_state.dart';
import 'package:digital_brain/ui/theme.dart' show Look;
import 'package:digital_brain/ui/widgets.dart' show TopBar;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'family_med_1119_test.dart' show linked;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> _shot(WidgetTester t, String name) async {
  if (!shots) return;
  debugDisableShadows = false;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/fixes_1122/$name.png'));
  debugDisableShadows = true;
}

void main() {
  setUp(() async {
    if (shots) await four.icons();
  });
  tearDown(() {
    medicalOffForTests = false;
    lookDesign = 1;
  });

  Future<dynamic> openMuslim(WidgetTester t, {IbadahTab tab = IbadahTab.prayer, bool dark = false}) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 19, 15, 5);
    if (dark) await rig.brain.setLook(Look.dark);
    await settle(t);
    final ctx = t.element(find.byType(Scaffold).first);
    if (shots) {
      await t.runAsync(() async {
        for (final p in mosquePictures.values) {
          await precacheImage(AssetImage(p.$1), ctx);
        }
      });
    }
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => IbadahScreen(tab: tab)));
    await settle(t);
    return rig;
  }

  testWidgets('মুসলিম টাইম: the picture fades into the page, no hard edge', (t) async {
    await openMuslim(t);
    expect(find.byKey(const Key('ibadah-hero')), findsOneWidget);
    expect(find.byType(ClipRRect).evaluate().where((e) => (e.widget as ClipRRect).borderRadius == const BorderRadius.vertical(bottom: Radius.circular(26))), isEmpty);
    await _shot(t, '1-prayer');
  });

  testWidgets('মুসলিম টাইম: sehri and iftar', (t) async {
    await openMuslim(t, tab: IbadahTab.fasting);
    await _shot(t, '2-sehri-iftar');
  });

  testWidgets('মুসলিম টাইম: the qibla compass is smaller', (t) async {
    final rig = await openMuslim(t, tab: IbadahTab.qibla);
    final dhaka = placeNamed(rig.brain.district);
    (rig.brain.services.compass as FakeCompass).point(Heading(qiblaFrom(dhaka.lat, dhaka.lon) - 18));
    await settle(t);
    final dial = t.getSize(find.descendant(of: find.byType(QiblaView), matching: find.byType(CustomPaint)).first);
    expect(dial.width, lessThanOrEqualTo(250));
    await _shot(t, '3-qibla');
  });

  testWidgets('মুসলিম টাইম: dark', (t) async {
    await openMuslim(t, dark: true);
    await _shot(t, '4-prayer-dark');
  });

  testWidgets('family: no "এখন কোথায়?" and no location to allow', (t) async {
    final (rig, _, _) = await linked(t, allow: const ['task', 'reminder', 'medicine', 'note', 'location']);
    expect(familyPerms, isNot(contains('location')));
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const FamilyMemberScreen(linkId: 9)));
    await settle(t);
    expect(find.byKey(const Key('family-locate')), findsNothing);
    expect(find.text('এখন কোথায়?'), findsNothing);
    expect(find.byKey(const Key('family-allow-location')), findsNothing);
    await _shot(t, '5-family-member');
    expect(rig.brain.family.links.single.theyAllow, contains('location'));
  });

  testWidgets('medicine form: the same letter sizes as the other forms', (t) async {
    medicalOffForTests = true;
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 19, 10, 15);
    await rig.brain.saveMember(FamilyMember(id: 'amma', name: 'আম্মা'));
    await settle(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.reminder, medicine: true)));
    await settle(t);
    await t.tap(find.byKey(const Key('med-who-amma')));
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
    await _shot(t, '6-medicine');
  });

  for (final design in [1, 2]) {
    for (final dark in [false, true]) {
      testWidgets('থিম ও ভাষা: design $design${dark ? ', dark' : ''}', (t) async {
        lookDesign = design;
        final rig = await start(t);
        await rig.brain.setLook(dark ? Look.dark : Look.sun);
        await settle(t);
        Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(
            builder: (_) => Scaffold(
                  body: SafeArea(
                    child: Column(children: [
                      TopBar(title: 'থিম ও ভাষা'),
                      Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: const [LookSettings()])),
                    ]),
                  ),
                )));
        await settle(t);
        expect(find.byKey(const Key('look-sample')), findsOneWidget);
        await _shot(t, '7-look-$design${dark ? '-dark' : ''}');
        if (design == 1 && !dark) {
          await t.drag(find.byType(ListView).last, const Offset(0, -700));
          await settle(t);
          await _shot(t, '7-look-1-below');
          await t.drag(find.byType(ListView).last, const Offset(0, 700));
          await settle(t);
        }
        if (design == 2 && !dark) {
          await t.tap(find.byKey(const Key('look-row-theme')));
          await settle(t);
          await _shot(t, '8-look-2-theme-sheet');
          await t.tap(find.byKey(const Key('look-pick-dark')));
          await settle(t);
          expect(rig.brain.look, Look.dark);
        }
        if (design == 1 && !dark) {
          await t.tap(find.byKey(const Key('look-lang-en')));
          await settle(t);
          expect(rig.brain.english, isTrue);
          expect(find.text('Theme'), findsWidgets);
          await _shot(t, '7-look-1-english');
        }
      });
    }
  }
}
