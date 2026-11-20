// Owner, 19 Nov: the place picker is a sheet from below (design 1 of three):
// search, "where I am now", the places picked before, the districts by
// division. On আরও the profile card no longer shows how long Premium lasts;
// that is on the Premium page.
// SHOTS=1 --update-goldens writes test/ui/shots/profile_1119/*.png.
import 'dart:io';

import 'package:digital_brain/screens/place_picker.dart';
import 'package:digital_brain/state/brain.dart' show BrainMore;
import 'package:digital_brain/screens/pro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_shots_test.dart' show rig0;
import '../app_test.dart' show settle;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> shot(WidgetTester t, String name) async {
  if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/profile_1119/$name.png'));
}

void main() {
  test('64 districts, each in one division', () {
    final all = [for (final l in bdDivisions.values) ...l];
    expect(all.length, 64);
    expect(all.toSet().length, 64);
  });

  testWidgets('the place sheet: search, here, picked before, by division', (t) async {
    final rig = await rig0(t);
    await rig.brain.setDistrict('ঢাকা');
    await rig.brain.setPref('place_recent', 'চট্টগ্রাম\nসিলেট');
    final ctx = t.element(find.byTooltip('বলুন'));
    PlacePick? got;
    pickPlace(ctx).then((v) => got = v);
    await settle(t);
    expect(find.text('লোকেশন বাছুন'), findsOneWidget);
    expect(find.byKey(const Key('place-auto')), findsOneWidget);
    expect(find.byKey(const Key('place-recent-চট্টগ্রাম')), findsOneWidget);
    expect(find.text('ঢাকা বিভাগ'), findsOneWidget);
    expect(find.text('Gazipur'), findsOneWidget);
    await shot(t, '1-sheet');
    await t.enterText(find.byKey(const Key('place-search')), 'কু');
    await t.pump(const Duration(milliseconds: 100));
    await settle(t);
    expect(find.byKey(const Key('place-কুমিল্লা')), findsOneWidget);
    expect(find.text('চট্টগ্রাম বিভাগ'), findsWidgets);
    await shot(t, '2-typing');
    await t.tap(find.byKey(const Key('place-কুমিল্লা')));
    await settle(t);
    expect((got as PickedPlace).place.name, 'কুমিল্লা');
    expect(recentPlaces(rig.brain).first, 'কুমিল্লা');
    await t.pump(const Duration(seconds: 1));
    debugDisableShadows = true;
  });

  testWidgets('আরও: no plan date on the card; it is on the Premium page', (t) async {
    final rig = await rig0(t);
    rig.brain.gated = true;
    rig.brain.proUntil = DateTime(2027, 11, 6);
    rig.brain.proKind = 'paid';
    await rig.brain.saveEmergency(rig.brain.data.emergency.copyWith(blood: 'B+'));
    await t.tap(find.text('আরও').last);
    await settle(t);
    expect(find.textContaining('দিন বাকি'), findsNothing);
    expect(find.byKey(const Key('more-place')), findsOneWidget);
    // Name, place and blood group given (3 of 6 in the Play edition): next the photo.
    expect(find.byKey(const Key('more-fullness')), findsOneWidget);
    expect(find.text('ছবি দিন'), findsOneWidget);
    await shot(t, '3-more');
    await t.tap(find.byKey(const Key('plan-badge')));
    await settle(t);
    expect(find.byType(ProScreen), findsOneWidget);
    expect(find.textContaining('আর ৩৭৮ দিন বাকি'), findsOneWidget);
    await shot(t, '4-premium');
    debugDisableShadows = true;
  });
}
