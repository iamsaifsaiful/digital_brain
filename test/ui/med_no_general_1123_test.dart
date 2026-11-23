// Owner, 23 Nov: "ওষুধের রিমাইন্ডার মেনুর ভেতরে সাধারণ রিমাইন্ডার ট্যাব থাকা
// অযৌক্তিক". Opened as the medicine reminder, the form has no সাধারণ tab.
// SHOTS=1 --update-goldens writes test/ui/shots/med_no_general_1123/*.png.
import 'dart:io';

import 'package:digital_brain/logic/pro.dart' show medicalOffForTests;
import 'package:digital_brain/screens/new_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_shots_test.dart' show rig0;
import '../app_test.dart' show settle;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> shot(WidgetTester t, String name) async {
  if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/med_no_general_1123/$name.png'));
}

void main() {
  tearDown(() => medicalOffForTests = false);

  testWidgets('medicine reminder: no সাধারণ tab; the general one still has its own', (t) async {
    medicalOffForTests = true;
    await rig0(t);
    final nav = Navigator.of(t.element(find.byTooltip('বলুন')));
    nav.push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.reminder, medicine: true)));
    await settle(t);
    expect(find.byKey(const Key('rem-med')), findsNothing);
    expect(find.text('সাধারণ রিমাইন্ডার'), findsNothing);
    expect(find.text('ওষুধের রিমাইন্ডার'), findsWidgets);
    expect(find.byKey(const Key('med-name')), findsOneWidget);
    await shot(t, '1-medicine');
    nav.pop();
    await settle(t);
    nav.push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.reminder)));
    await settle(t);
    expect(find.byKey(const Key('rem-med')), findsOneWidget);
    await shot(t, '2-general');
    debugDisableShadows = true;
  });
}
