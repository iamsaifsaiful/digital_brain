// Medicine form (owner, 17 Nov): for whom, the name with a live search and
// what it is usually for, when, before/after food, special advice.
// SHOTS=1 --update-goldens writes test/ui/shots/med_form_1117/*.png.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/brain.dart' show BrainHealth;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_shots_test.dart' show rig0;
import '../app_test.dart' show settle;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> shot(WidgetTester t, String name) async {
  if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/med_form_1117/$name.png'));
}

void main() {
  testWidgets('medicine form: order, live search, what it is for', (t) async {
    final rig = await rig0(t);
    await rig.brain.saveMember(FamilyMember(id: 'amma', name: 'আম্মা'));
    final tool = find.descendant(of: find.byKey(const Key('home-tools')), matching: find.text('ওষুধ'));
    await t.ensureVisible(tool);
    await settle(t);
    await t.tap(tool);
    await settle(t);
    await t.tap(find.text('ওষুধ যোগ'));
    await settle(t);
    await t.tap(find.byKey(const Key('med-who-amma')));
    await settle(t);
    await shot(t, '1-empty');
    await t.enterText(find.byKey(const Key('med-name')), 'নাপ');
    await settle(t);
    expect(find.byKey(const Key('med-hit-Napa')), findsOneWidget);
    expect(find.byKey(const Key('med-hit-Napa Extra')), findsOneWidget);
    await shot(t, '2-search');
    await t.tap(find.byKey(const Key('med-hit-Napa')));
    await settle(t);
    expect(find.byKey(const Key('med-use')), findsOneWidget);
    expect(find.textContaining('জ্বর আর ব্যথা কমাতে'), findsOneWidget);
    await shot(t, '3-picked');
    // English name or what is inside finds it too.
    await t.enterText(find.byKey(const Key('med-name')), 'amlo');
    await settle(t);
    expect(find.byKey(const Key('med-hit-Amdocal')), findsOneWidget);
    await t.enterText(find.byKey(const Key('med-name')), 'সেকলো');
    await settle(t);
    expect(find.textContaining('গ্যাস্ট্রিক'), findsOneWidget);
    await t.enterText(find.byKey(const Key('med-note')), 'ভরা পেটে, পানির সাথে');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
    await t.ensureVisible(find.byKey(const Key('med-more')));
    await settle(t);
    await shot(t, '4-rest');
    await t.tap(find.byKey(const Key('med-more')));
    await settle(t);
    await t.ensureVisible(find.text('রাখুন').last);
    await settle(t);
    await shot(t, '5-more');
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    final m = rig.brain.data.medicines.single;
    expect(m.name, 'সেকলো');
    expect(m.member, 'amma');
    expect(m.note, 'ভরা পেটে, পানির সাথে');
    debugDisableShadows = true;
  });
}
