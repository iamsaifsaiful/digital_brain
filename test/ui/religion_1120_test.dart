// Owner, 20 Nov: "ধর্ম" in the member's profile: optional, with
// "বলতে চাই না", kept only on the phone and not counted in "প্রোফাইল N%".
// SHOTS=1 --update-goldens writes test/ui/shots/religion_1120/*.png.
import 'dart:io';

import 'package:digital_brain/state/brain.dart' show BrainMore;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_shots_test.dart' show rig0;
import '../app_test.dart' show settle;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> shot(WidgetTester t, String name) async {
  if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/religion_1120/$name.png'));
}

void main() {
  testWidgets('profile: religion row, sheet, pick, clear; not in the %', (t) async {
    final rig = await rig0(t);
    await rig.brain.setDistrict('ঢাকা');
    await rig.brain.saveEmergency(rig.brain.data.emergency.copyWith(blood: 'B+'));
    await t.tap(find.text('আরও').last);
    await settle(t);
    final before = (t.widget(find.textContaining('প্রোফাইল ').first) as Text).data;
    await t.tap(find.byKey(const Key('more-profile')));
    await settle(t);
    expect(find.byKey(const Key('profile-religion')), findsOneWidget);
    expect(find.text('বাছুন (ঐচ্ছিক)'), findsOneWidget);
    await shot(t, '1-profile-empty');
    await t.tap(find.byKey(const Key('profile-religion')));
    await settle(t);
    expect(find.text('আপনার ধর্ম'), findsOneWidget);
    expect(find.byKey(const Key('religion-none')), findsOneWidget);
    await shot(t, '2-sheet');
    await t.tap(find.byKey(const Key('religion-islam')));
    await settle(t);
    expect(rig.brain.text('religion'), 'islam');
    expect(find.text('ইসলাম'), findsOneWidget);
    await shot(t, '3-profile-islam');
    await t.tap(find.byKey(const Key('profile-religion')));
    await settle(t);
    expect(find.byKey(const Key('religion-clear')), findsOneWidget);
    await t.tap(find.byKey(const Key('religion-none')));
    await settle(t);
    expect(find.text('বলতে চাই না'), findsOneWidget);
    await t.tap(find.byKey(const Key('profile-religion')));
    await settle(t);
    await t.tap(find.byKey(const Key('religion-clear')));
    await settle(t);
    expect(rig.brain.text('religion'), '');
    Navigator.of(t.element(find.byKey(const Key('profile-religion')))).pop();
    await settle(t);
    expect((t.widget(find.textContaining('প্রোফাইল ').first) as Text).data, before);
    // English.
    await rig.brain.setPref('religion', 'hindu');
    await rig.brain.setEnglish(true);
    await settle(t);
    await t.tap(find.byKey(const Key('more-profile')));
    await settle(t);
    expect(find.text('Religion'), findsOneWidget);
    expect(find.text('Hinduism'), findsOneWidget);
    await shot(t, '4-english');
    await t.tap(find.byKey(const Key('profile-religion')));
    await settle(t);
    expect(find.text('Prefer not to say'), findsOneWidget);
    await shot(t, '5-sheet-english');
    await t.pump(const Duration(seconds: 1));
    debugDisableShadows = true;
  });
}
