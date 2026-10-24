// The approved home (docs/design/2026-10-24-home-final) and the three main
// tabs in its language, light and dark. With SHOTS=1 --update-goldens the
// screens are written to test/ui/shots/final-*.png to compare with the
// design's images. Without SHOTS they only check that the pages build and
// the computed bits (the turning slot, one attention card, the badge).
import 'dart:io';

import 'package:digital_brain/logic/calendar_bd.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/home_page.dart' show slotFacts;
import 'package:digital_brain/services/notifications.dart' show AlarmHealth;
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> icons() async {
  final f = File('/opt/fl/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (!f.existsSync()) return;
  final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
  await l.load();
}

AppData sample(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return AppData(
    cash: [
      CashEntry(kind: CashKind.income, amount: 35000, category: 'বেতন', date: today.subtract(const Duration(days: 20))),
      CashEntry(kind: CashKind.expense, amount: 8000, category: 'বাসা ভাড়া', date: today.subtract(const Duration(days: 18))),
      CashEntry(kind: CashKind.expense, amount: 2450, category: 'বাজার', date: today.subtract(const Duration(days: 2))),
      CashEntry(kind: CashKind.expense, amount: 2000, category: 'বিল', date: today.subtract(const Duration(days: 1))),
    ],
    ledger: [
      LedgerEntry(person: 'রহিম', amount: 12000, kind: LedgerKind.lent, date: today.subtract(const Duration(days: 40)), due: today),
      LedgerEntry(person: 'মামুন', amount: 7500, kind: LedgerKind.lent, date: today.subtract(const Duration(days: 30))),
      LedgerEntry(person: 'সজীব', amount: 5000, kind: LedgerKind.lent, date: today.subtract(const Duration(days: 10))),
      LedgerEntry(person: 'করিম', amount: 15000, kind: LedgerKind.borrowed, date: today.subtract(const Duration(days: 20)), due: DateTime(now.year, 11, 3)),
    ],
    contacts: [Contact(name: 'আম্মা', phone: '01711111111')],
    tasks: [
      Task(title: 'ব্যাংকে যাওয়া — ডিপিএস জমা', due: today.subtract(const Duration(days: 1))),
      Task(title: 'বিদ্যুৎ বিল দেওয়া', due: today, done: true, doneAt: now.subtract(const Duration(hours: 5))),
      Task(title: 'আব্বার ওষুধ', due: today, list: 'ফ্যামিলি'),
      Task(title: 'স্কুলের ফি', due: today.add(const Duration(days: 1))),
      Task(title: 'গাড়ি সার্ভিসিং', due: today.add(const Duration(days: 1))),
    ],
    reminders: [Reminder(title: 'আম্মাকে ফোন', date: today, hour: 19, repeat: Repeat.weekly)],
    notes: [Note(title: 'গেটের কোড', body: '৪৪২১'), Note(title: 'গাড়ির কাগজ', body: 'আলমারির উপরের তাকে')],
    docs: [Doc(title: 'পাসপোর্ট', expiry: now.add(const Duration(days: 12)))],
  );
}

void main() {
  test('the turning slot: the next prayer, then the sun; in Ramadan iftar until Maghrib, sehri after', () {
    final place = placeNamed('ঢাকা');
    final day = DateTime(2026, 10, 24);
    final t = sunTimes(day, place);
    final evening = DateTime(2026, 10, 24, 18, 34);
    final f = slotFacts(evening, t, const HijriDate(1448, 5, 12));
    expect(f.first.kind, 'prayer');
    expect(f.first.label, 'এশা');
    expect(f.last.kind, 'sun');
    // Ramadan: afternoon → iftar (Maghrib); after Maghrib → sehri ends (Fajr).
    final ram = const HijriDate(1448, 9, 14);
    final noon = slotFacts(DateTime(2026, 10, 24, 15), t, ram).first;
    expect((noon.kind, noon.ramadanDay), ('iftar', 14));
    final night = slotFacts(t.maghrib.add(const Duration(minutes: 1)), t, ram).first;
    expect(night.kind, 'sehri');
    // Owner, 24 Oct: sehri ends 5 minutes before Fajr.
    expect(t.sehriEnd, t.fajr.subtract(const Duration(minutes: 5)));
    // No countdowns or day length anywhere on the slot.
    for (final x in [...f, noon, night]) {
      expect('${x.label} ${x.time} ${x.second}', isNot(contains('পর')));
    }
  });

  for (final look in [Look.light, Look.dark]) {
    for (final (name, tab) in [('1-home', null), ('2-diary', 'দিনলিপি'), ('3-money', 'হিসাব'), ('4-store', 'সংরক্ষণ')]) {
      testWidgets('final ui ${look.name}: $name', (t) async {
        if (shots) await icons();
        if (shots) debugDisableShadows = false;
        final rig = await start(t);
        rig.nowAt = DateTime(2026, 10, 24, 18, 34);
        await rig.brain.setLook(look);
        await rig.brain.setUserName('সাইফুল ইসলাম');
        rig.brain.gated = true;
        await rig.brain.setProForTest(true);
        rig.notifier.state = const AlarmHealth(notificationsOn: true, exactOn: false, batteryFree: true, fullScreenOn: true, brand: '', hasAutostart: false);
        rig.brain.data = sample(rig.nowAt);
        await rig.brain.setPref('home_tools_open', true);
        // Back to the app: the phone's settings are read again.
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await settle(t);
        if (tab != null) {
          await t.tap(find.text(tab).last);
          await settle(t);
        } else {
          // One attention card only (the may-not-ring one beats the others).
          expect(find.byKey(const Key('home-alarm-health')), findsOneWidget);
          expect(find.byKey(const Key('home-google')), findsNothing);
          expect(find.byKey(const Key('home-premium-badge')), findsOneWidget);
          expect(find.text('আম্মাকে ফোন'), findsOneWidget);
          expect(find.text('ফোন করুন'), findsOneWidget);
        }
        expect(C.dark, look == Look.dark);
        if (shots) {
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/final-$name-${look.name}.png'));
          // The whole page on one tall phone.
          t.view.physicalSize = const Size(1170, 6000);
          await settle(t);
          await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/final-$name-${look.name}-full.png'));
        }
        debugDisableShadows = true;
      });
    }
  }

  testWidgets('a free user sees no প্রিমিয়াম badge', (t) async {
    final rig = await start(t);
    rig.brain.gated = true;
    await settle(t);
    expect(find.byKey(const Key('home-premium-badge')), findsNothing);
  });
}
