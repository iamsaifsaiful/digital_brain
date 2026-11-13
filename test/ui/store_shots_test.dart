// Google Play store screenshots (owner, 30 Oct): SHOTS=1 --update-goldens
// writes test/ui/shots/store/*.png (gitignored), light look, rich sample.
// The owner's order: reminders, money, documents, passwords, family, zakat,
// backup, encrypted.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/alarm_screens.dart';
import 'package:digital_brain/screens/app_places.dart';
import 'package:digital_brain/state/family_state.dart' show FamilyLink;
import 'package:digital_brain/state/brain.dart' show BrainMore;
import 'package:digital_brain/services/notifications.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show Rig, settle, start;
import 'all_pages_shots_test.dart' show richer;
import 'home_final_shots_test.dart' show icons;

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
    await rig.brain.setUserName('সাইফুল');
    final now = rig.nowAt;
    final d = richer(now);
    d.docs.addAll([
      Doc(title: 'জাতীয় পরিচয়পত্র', folder: 'জাতীয় পরিচয়পত্র'),
      Doc(title: 'জমির দলিল', folder: 'জমি ও বাড়ির কাগজ'),
      Doc(title: 'ড্রাইভিং লাইসেন্স', folder: 'গাড়ি ও লাইসেন্স', expiry: now.add(const Duration(days: 40))),
      Doc(title: 'এসএসসি সার্টিফিকেট', folder: 'সার্টিফিকেট'),
      Doc(title: 'বিদ্যুৎ বিল', folder: 'বিল ও রসিদ'),
    ]);
    d.vault.addAll([
      VaultItem(name: 'Facebook', username: 'saiful', password: 'z'),
      VaultItem(name: 'ব্যাংক অ্যাপ', password: 'w'),
      VaultItem(name: 'অফিসের ল্যাপটপ', password: 'v'),
    ]);
    // Store pictures (13 Nov): more ধার-দেনা and today's লেনদেন, no first-steps card.
    d.ledger.addAll([
      LedgerEntry(person: 'করিম ভাই', kind: LedgerKind.borrowed, amount: 10000, date: now.subtract(const Duration(days: 20)), due: now.add(const Duration(days: 3))),
      LedgerEntry(person: 'করিম ভাই', kind: LedgerKind.repaid, amount: 4000, date: now.subtract(const Duration(days: 6))),
      LedgerEntry(person: 'সুমন', kind: LedgerKind.lent, amount: 2500, date: now.subtract(const Duration(days: 2))),
      LedgerEntry(person: 'সুমন', kind: LedgerKind.received, amount: 1000, date: now.subtract(const Duration(days: 1))),
    ]);
    d.cash.addAll([
      CashEntry(kind: CashKind.expense, amount: 650, category: 'বাজার', date: now.subtract(const Duration(hours: 5))),
      CashEntry(kind: CashKind.expense, amount: 120, category: 'যাতায়াত', date: now.subtract(const Duration(hours: 2))),
      CashEntry(kind: CashKind.expense, amount: 1450, category: 'বিদ্যুৎ বিল', date: now.subtract(const Duration(days: 1))),
      CashEntry(kind: CashKind.income, amount: 4500, category: 'টিউশনি', date: now.subtract(const Duration(days: 1))),
    ]);
    rig.brain.data = d;
    await rig.brain.setCashOnHand(18500);
    await settle(t);
    return rig;
  }

  Future<void> snap(WidgetTester t, String name) async {
    // Pictures (the home sky) decode only outside the fake clock.
    await t.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await t.pump(const Duration(milliseconds: 300));
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/store/$name.png'));
    debugDisableShadows = true;
  }

  Future<void> page(WidgetTester t, String id) async {
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => placePage(id)!));
    await settle(t);
  }

  testWidgets('store: home', (t) async {
    await rig0(t);
    // The first-steps and backup cards closed, as on a phone in use.
    for (var i = 0; i < 3; i++) {
      final x = find.byIcon(Icons.close_rounded);
      if (x.evaluate().isEmpty) break;
      await t.tap(x.first, warnIfMissed: false);
      await settle(t);
    }
    await snap(t, '0-home');
  });

  testWidgets('store: reminders', (t) async {
    await rig0(t);
    await page(t, 'tasks');
    await snap(t, '1-reminders');
  });

  testWidgets('store: alarm', (t) async {
    await rig0(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const AlarmScreen(info: NoticeInfo('x', 'বিদ্যুৎ বিল দেওয়া', 'রাত ১০টা', true))));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    await snap(t, '1b-alarm');
  });

  testWidgets('store: money', (t) async {
    await rig0(t);
    await t.tap(find.text('হিসাব').last);
    await settle(t);
    await snap(t, '2-money');
    await t.tap(find.text('ধার-দেনা').first);
    await settle(t);
    await snap(t, '2b-loans');
  });

  // The Play app has no medicines (owner, 30 Oct: pro.dart medicalOff): the
  // family page with members instead.
  testWidgets('store: family', (t) async {
    final rig = await rig0(t);
    rig.brain
      ..googleEmail = 'saiful@gmail.com'
      ..googleName = 'সাইফুল ইসলাম';
    final fam = rig.brain.family;
    Map<String, dynamic> link(int id, String name, String email, String call, List<String> allow, {bool heir = false}) => {
          'id': id, 'status': 'active', 'incoming': false, 'name': name, 'email': email, 'i_call': call, 'they_call': '',
          'i_allow': allow, 'they_allow': allow, 'they_are_my_heir': heir,
        };
    final links = [
      FamilyLink.fromJson(link(1, 'রহিমা বেগম', 'amma@gmail.com', 'আম্মা', ['task', 'reminder', 'note', 'location'])),
      FamilyLink.fromJson(link(2, 'রুমানা আক্তার', 'rumana@gmail.com', 'স্ত্রী', ['task', 'reminder', 'note', 'location'], heir: true)),
      FamilyLink.fromJson(link(3, 'রাফি ইসলাম', 'rafi@gmail.com', 'ছেলে', ['task', 'reminder', 'note'])),
    ];
    await page(t, 'family');
    fam
      ..links = links
      ..loaded = true
      ..error = null;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    fam.notifyListeners();
    await settle(t);
    await snap(t, '5-family');
  });

  for (final (name, id) in [('3-docs', 'docs'), ('4-vault', 'vault'), ('6-zakat', 'zakat'), ('7-backup', 'backup')]) {
    testWidgets('store: $name', (t) async {
      final rig = await rig0(t);
      if (id == 'backup') {
        rig.brain
          ..googleEmail = 'saiful@gmail.com'
          ..googleName = 'সাইফুল ইসলাম'
          ..driveOn = true
          ..lastDrive = rig.nowAt.subtract(const Duration(hours: 2));
      }
      await page(t, id);
      await snap(t, name);
    });
  }
}
