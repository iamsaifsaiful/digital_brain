// The new medicine form in the Play app (owner, 18 Nov: "এটা তো চিকিৎসা না,
// ওষুধের রিমাইন্ডার"): for whom, the name with a live search, why in the
// user's own words, when, before/after food, special instructions; each time
// a daily reminder. The app never says what a medicine is for there.
// SHOTS=1 --update-goldens writes test/ui/shots/med_reminder_play_1118/*.png.
import 'dart:io';

import 'package:digital_brain/logic/pro.dart' show medicalOffForTests;
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/new_item_screen.dart';
import 'package:digital_brain/state/brain.dart' show BrainHealth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_shots_test.dart' show rig0;
import '../app_test.dart' show settle;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> reach(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(f, 200, scrollable: find.descendant(of: find.byType(Form), matching: find.byType(Scrollable)).first);
  await settle(t);
}

Future<void> shot(WidgetTester t, String name) async {
  if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/med_reminder_play_1118/$name.png'));
}

void main() {
  tearDown(() => medicalOffForTests = false);

  testWidgets('Play app: the new medicine form makes daily reminders', (t) async {
    medicalOffForTests = true;
    final rig = await rig0(t);
    await rig.brain.saveMember(FamilyMember(id: 'amma', name: 'আম্মা'));
    await settle(t);
    final medsBefore = rig.brain.data.medicines.length;
    Navigator.of(t.element(find.byTooltip('বলুন'))).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.reminder, medicine: true)));
    await settle(t);
    await t.tap(find.byKey(const Key('med-who-amma')));
    await settle(t);
    await shot(t, '1-empty');
    await t.enterText(find.byKey(const Key('med-name')), 'নাপ');
    await settle(t);
    expect(find.byKey(const Key('med-hit-Napa')), findsOneWidget);
    // Names and what is inside only — never what it is taken for.
    expect(find.textContaining('জ্বর আর ব্যথা কমাতে'), findsNothing);
    await shot(t, '2-search');
    await t.tap(find.byKey(const Key('med-hit-Napa')));
    await settle(t);
    expect(find.byKey(const Key('med-use')), findsNothing);
    await t.enterText(find.byKey(const Key('med-why')), 'জ্বরের জন্য ডাক্তার দিয়েছেন');
    await t.tap(find.byKey(const Key('med-per-3')));
    await settle(t);
    await reach(t, find.byKey(const Key('med-meal-after')));
    await t.tap(find.byKey(const Key('med-meal-after')));
    await reach(t, find.byKey(const Key('med-note')));
    await t.enterText(find.byKey(const Key('med-note')), 'পানির সাথে');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
    await reach(t, find.byKey(const Key('med-more')));
    await settle(t);
    await shot(t, '3-rest');
    await t.tap(find.byKey(const Key('med-more')));
    await settle(t);
    await reach(t, find.descendant(of: find.byKey(const Key('med-more')), matching: find.byIcon(Icons.add_circle_outline_rounded)));
    await t.drag(find.descendant(of: find.byType(Form), matching: find.byType(Scrollable)).first, const Offset(0, -300));
    await settle(t);
    await t.tap(find.descendant(of: find.byKey(const Key('med-more')), matching: find.byIcon(Icons.add_circle_outline_rounded)));
    await settle(t);
    await reach(t, find.textContaining('প্রতিবার কয়টা: ২'));
    await settle(t);
    await shot(t, '4-more');
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    final rs = rig.brain.data.reminders.where((r) => r.title.startsWith('নাপা খাওয়ার')).toList();
    expect(rs.length, 3);
    expect(rs.every((r) => r.repeat == Repeat.daily && r.title == 'নাপা খাওয়ার সময় (আম্মা)'), isTrue);
    expect({for (final r in rs) r.hour}, {8, 14, 22});
    expect(rs.first.note, 'খাবারের পরে · ২টি করে · পানির সাথে · কেন: জ্বরের জন্য ডাক্তার দিয়েছেন');
    expect(rig.brain.data.medicines.length, medsBefore);
    debugDisableShadows = true;
  });
}
