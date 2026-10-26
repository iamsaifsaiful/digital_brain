// Promo video screens (owner, 25 Oct): SHOTS=1 --update-goldens writes
// test/ui/shots/promo/*.png (gitignored). Light look, rich sample data.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/alarm_screens.dart';
import 'package:digital_brain/screens/app_places.dart';
import 'package:digital_brain/screens/health_screens.dart' show MedicinesScreen;
import 'package:digital_brain/services/notifications.dart';
import 'package:digital_brain/state/brain.dart' show BrainMore, BrainHealth;
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show Rig, settle, start;
import 'home_final_shots_test.dart' show icons, sample;

final shots = Platform.environment['SHOTS'] == '1';

void main() {
  Future<Rig> rig0(WidgetTester t) async {
    if (shots) {
      await icons();
      debugDisableShadows = false;
    }
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 24, 18, 34);
    await rig.brain.setLook(Look.light);
    await rig.brain.setUserName('সাইফুল ইসলাম');
    final d = sample(rig.nowAt);
    d.vault.addAll([
      VaultItem(name: 'Gmail', username: 'saiful@gmail.com', password: 'x'),
      VaultItem(name: 'বিকাশ', password: 'y'),
      VaultItem(name: 'Facebook', username: 'saiful', password: 'z'),
      VaultItem(name: 'ব্যাংক অ্যাপ', password: 'w'),
      VaultItem(name: 'অফিসের ল্যাপটপ', password: 'v'),
    ]);
    rig.brain.data = d;
    await settle(t);
    return rig;
  }

  Future<void> snap(WidgetTester t, String name) async {
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/promo/$name.png'));
    debugDisableShadows = true;
  }

  testWidgets('promo: ledger', (t) async {
    await rig0(t);
    await t.tap(find.text('হিসাব').last);
    await settle(t);
    await t.tap(find.text('ধার-দেনা').first);
    await settle(t);
    await snap(t, 'ledger');
  });

  testWidgets('promo: alarm', (t) async {
    await rig0(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const AlarmScreen(info: NoticeInfo('x', 'আম্মাকে ফোন', 'সন্ধ্যা ৭টা', true))));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(AlarmScreen), findsOneWidget);
    await snap(t, 'alarm');
  });

  testWidgets('promo: home', (t) async {
    await rig0(t);
    await snap(t, 'home');
  });

  testWidgets('promo: vault', (t) async {
    await rig0(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => placePage('vault')!));
    await settle(t);
    await snap(t, 'vault');
  });

  testWidgets('promo: medicines', (t) async {
    final rig = await rig0(t);
    await rig.brain.saveMember(FamilyMember(id: 'amma', name: 'আম্মা'));
    await rig.brain.saveMedicine(Medicine(name: 'অ্যামলোডিপিন', times: [8 * 60, 22 * 60], member: 'amma'));
    await rig.brain.saveMedicine(Medicine(name: 'মেটফরমিন', times: [8 * 60, 14 * 60, 22 * 60], member: 'amma'));
    await rig.brain.saveMedicine(Medicine(name: 'ক্যালসিয়াম', times: [14 * 60], member: 'amma'));
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const MedicinesScreen(member: 'amma')));
    await settle(t);
    await snap(t, 'medicines');
  });

  testWidgets('promo: money by day and filters', (t) async {
    await rig0(t);
    await t.tap(find.text('হিসাব').last);
    await settle(t);
    await t.tap(find.text('মাসিক'));
    await settle(t);
    t.view.physicalSize = const Size(1170, 5200);
    await settle(t);
    await snap(t, 'money-month');
    await t.tap(find.text('দৈনিক'));
    await settle(t);
    await snap(t, 'money-day');
  });

  testWidgets('promo: emergency card with the blood group', (t) async {
    final rig = await rig0(t);
    rig.brain.data.emergency = const EmergencyCard(
        name: 'সাইফুল ইসলাম', blood: 'B+', contacts: ['আম্মা — 01711234567', 'ভাই — 01819765432'], medicines: 'অ্যামলোডিপিন ৫ মি.গ্রা.', allergies: 'পেনিসিলিন', onLockScreen: true);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => placePage('emergency')!));
    await settle(t);
    await snap(t, 'emergency');
  });
}
