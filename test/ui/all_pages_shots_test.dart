// The 24 Oct design across every page: each page builds in light and dark
// with a full sample. SHOTS=1 --update-goldens also writes screenshots
// (test/ui/shots/all/, gitignored); LOOK=light|dark picks one look.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/app_places.dart';
import 'package:digital_brain/screens/family_screen.dart';
import 'package:digital_brain/screens/requests_screen.dart';
import 'package:digital_brain/screens/zakat_screen.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start, openTyping, sendTyped;
import 'package:digital_brain/screens/search_screen.dart';
import 'package:digital_brain/screens/lock_screen.dart';
import 'new_ui_shots_test.dart' as four show sample, icons;

final shots = Platform.environment['SHOTS'] == '1';
final only = Platform.environment['LOOK'];

AppData richer(DateTime now) {
  final d = four.sample(now);
  final today = DateTime(now.year, now.month, now.day);
  return d
    ..contacts.addAll([Contact(name: 'আম্মা', phone: '01711234567'), Contact(name: 'করিম ভাই', phone: '01819765432'), Contact(name: 'ডা. রফিক', phone: '01912456789')])
    ..vault.addAll([VaultItem(name: 'Gmail', username: 'saiful@gmail.com', password: 'x'), VaultItem(name: 'বিকাশ', password: 'y')])
    ..specialDays.addAll([SpecialDay(person: 'জামাল', month: now.month, day: now.day, year: 1993), SpecialDay(person: 'রাফি', month: now.month, day: (now.day % 27) + 1, kind: SpecialKind.birthday)])
    ..habits.add(Habit(name: '৩০ মিনিট হাঁটা', done: [for (var i = 1; i < 6; i++) dayKey(today.subtract(Duration(days: i)))]))
    ..health.addAll([
      HealthLog(kind: HealthKind.bp, at: now.subtract(const Duration(hours: 3)), a: 120, b: 80),
      HealthLog(kind: HealthKind.sugar, at: now.subtract(const Duration(hours: 5)), a: 6.8),
      HealthLog(kind: HealthKind.weight, at: now.subtract(const Duration(days: 1)), a: 72),
    ])
    ..projects.add(Project(name: 'বাড়ির কাজ', budget: 500000));
}

void main() {
  final pages = <String, Widget Function()>{
    for (final id in ['tasks', 'alarms', 'calendar', 'special', 'notes', 'docs', 'vault', 'contacts', 'inbox', 'report', 'spending', 'accounts', 'savings', 'split', 'shop', 'health', 'medicines', 'habits', 'emergency', 'expiry', 'tags', 'memory', 'templates', 'search', 'settings', 'notifications', 'sound', 'backup', 'help', 'pro', 'compass'])
      id: () => placePage(id)!,
    'zakat': () => const ZakatScreen(),
    'family': () => const FamilyScreen(),
    'blood': () => const RequestsScreen(),
  };
  for (final look in [Look.light, Look.dark]) {
    if (only != null && only != look.name) continue;
    for (final e in pages.entries) {
      testWidgets('page ${look.name}: ${e.key}', (t) async {
        if (shots) {
          await four.icons();
          debugDisableShadows = false;
        }
        final rig = await start(t);
        await rig.brain.setLook(look);
        await rig.brain.setUserName('সাইফুল');
        rig.brain.data = richer(rig.brain.services.now());
        await settle(t);
        Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => e.value()));
        await settle(t);
        expect(C.dark, look == Look.dark);
        if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/all/${e.key}-${look.name}.png'));
        debugDisableShadows = true;
      });
    }
    testWidgets('page ${look.name}: chat', (t) async {
      if (shots) {
        await four.icons();
        debugDisableShadows = false;
      }
      final rig = await start(t);
      await rig.brain.setLook(look);
      rig.brain.data = richer(rig.brain.services.now());
      await settle(t);
      await openTyping(t);
      await t.enterText(find.byType(TextField).first, 'কাল সকাল ৯টায় ব্যাংকে যেতে হবে');
      await sendTyped(t);
      await settle(t);
      await t.enterText(find.byType(TextField).first, 'এই মাসে বাজারে কত খরচ হলো?');
      await sendTyped(t);
      await settle(t);
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/all/chat-${look.name}.png'));
      debugDisableShadows = true;
    });
    testWidgets('page ${look.name}: more', (t) async {
      if (shots) {
        await four.icons();
        debugDisableShadows = false;
      }
      final rig = await start(t);
      await rig.brain.setLook(look);
      rig.brain.data = richer(rig.brain.services.now());
      await settle(t);
      await t.tap(find.text('আরও').last);
      await settle(t);
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/all/more-${look.name}.png'));
      debugDisableShadows = true;
    });
  }
}
