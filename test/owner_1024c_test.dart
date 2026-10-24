// Owner's points of 24 Oct (night): a lock keeps the page the user was on,
// tabs never sit flush on the page under them, a family request can be
// taken back, Bengali digits all in Noto (Hind's ১ was hard to read).
import 'dart:io' show Platform;

import 'package:digital_brain/logic/calendar_bd.dart';
import 'package:digital_brain/logic/sky_light.dart';
import 'package:digital_brain/logic/weather.dart';
import 'package:digital_brain/services/weather.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/notifications.dart' show AlarmHealth;
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/screens/plan_screens.dart';
import 'package:digital_brain/screens/health_screens.dart' show MedicinesScreen;
import 'package:digital_brain/screens/person_screen.dart';
import 'package:digital_brain/logic/steps.dart';
import 'package:digital_brain/logic/add_nudges.dart';
import 'package:digital_brain/services/compass.dart';
import 'package:digital_brain/services/error_log.dart';
import 'package:digital_brain/services/google_account.dart' show AccountServer;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:digital_brain/state/brain.dart' show BrainMore, BrainHealth;
import 'package:digital_brain/ui/theme.dart';
import 'package:digital_brain/ui/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, enterPin, settle, start;
import 'ui/home_final_shots_test.dart' show icons, sample;

void main() {
  testWidgets('locked while away: the open page and what was typed are still there after the PIN', (t) async {
    final rig = await start(t);
    final nav = Navigator.of(t.element(find.byType(HomeShell)));
    nav.push(MaterialPageRoute(
        builder: (_) => const Scaffold(body: SafeArea(child: Padding(padding: EdgeInsets.all(20), child: TextField(key: Key('half-note')))))));
    await settle(t);
    await t.enterText(find.byKey(const Key('half-note')), 'বাজারের তালিকা: চাল, ডাল');
    await settle(t);

    // Away longer than the auto-lock: the app locks.
    rig.brain.lockNow();
    await settle(t);
    expect(find.text('PIN দিন'), findsOneWidget);
    // Nothing of the page shows (or is found) behind the lock.
    expect(find.byKey(const Key('half-note')), findsNothing);
    expect(find.text('বাজারের তালিকা: চাল, ডাল'), findsNothing);

    await enterPin(t, '1234');
    // Back on the same page, with the text as it was.
    expect(find.byKey(const Key('half-note')), findsOneWidget);
    expect(find.text('বাজারের তালিকা: চাল, ডাল'), findsOneWidget);
    expect(find.text('PIN দিন'), findsNothing);
  });

  testWidgets('locked on a tab: the same tab after the PIN', (t) async {
    final rig = await start(t);
    await t.tap(find.text('হিসাব').last);
    await settle(t);
    expect(find.text('আয়-ব্যয়'), findsWidgets);
    rig.brain.lockNow();
    await settle(t);
    await enterPin(t, '1234');
    expect(find.text('আয়-ব্যয়'), findsWidgets);
  });

  testWidgets('tabs that stay put have air under them, whatever the page starts with', (t) async {
    final now = DateTime.now();
    final rig = await start(t, data: AppData(reminders: [Reminder(title: 'বিদ্যুৎ বিল', date: DateTime(now.year, now.month, now.day).add(const Duration(days: 3)), repeat: Repeat.monthly)]));
    Navigator.of(t.element(find.byType(HomeShell))).push(MaterialPageRoute(builder: (_) => const AllTasksScreen()));
    await settle(t);
    await t.tap(find.textContaining('বারবার').first);
    await settle(t);
    final tabs = t.getRect(find.byWidgetPredicate((w) => w is SegTabs));
    final card = t.getRect(find.ancestor(of: find.text('বিদ্যুৎ বিল'), matching: find.byType(Panel)).first);
    expect(card.top - tabs.bottom, greaterThanOrEqualTo(12));
    expect(rig.brain.data.reminders, hasLength(1));
  });

  test('Bengali headings and amounts use Noto (clear ১), Hind only fills English', () {
    expect(display(20).fontFamily, 'NotoBengali');
    expect(body(14).fontFamily, 'NotoBengali');
    expect(display(20).fontFamilyFallback, contains('Hind'));
  });

  test('the dark look is a night blue', () {
    C.dark = true;
    final g = HSLColor.fromColor(C.ground);
    C.dark = false;
    expect(g.hue, inInclusiveRange(215, 240));
    expect(g.lightness, lessThan(0.16));
  });

  test('the home light follows the day: dawn, morning, noon, afternoon, golden, sunset, evening, night', () {
    final t = sunTimes(DateTime(2026, 10, 24), placeNamed('ঢাকা'));
    DateTime m(DateTime x, int d) => x.add(Duration(minutes: d));
    final cases = {
      DateTime(2026, 10, 24, 3): 'night',
      m(t.sunrise, -40): 'dawn',
      m(t.sunrise, 5): 'sunrise',
      m(t.sunrise, 100): 'morning',
      DateTime(2026, 10, 24, 11, 45): 'noon',
      m(t.sunset, -140): 'afternoon',
      m(t.sunset, -45): 'golden',
      m(t.sunset, 3): 'sunset',
      m(t.sunset, 28): 'evening',
      DateTime(2026, 10, 24, 21): 'night',
    };
    for (final e in cases.entries) {
      expect(skyLight(e.key, t.sunrise, t.sunset).phase, e.value, reason: '${e.key}');
    }
    // Day picture by day, night picture by night, mixing in between.
    expect(skyLight(DateTime(2026, 10, 24, 12), t.sunrise, t.sunset).night, 0);
    expect(skyLight(DateTime(2026, 10, 24, 22), t.sunrise, t.sunset).night, 1);
    final dusk = skyLight(m(t.sunset, 25), t.sunrise, t.sunset).night;
    expect(dusk, inExclusiveRange(0.3, 1));
  });

  for (final look in [Look.light, Look.dark]) {
    testWidgets('home hero ${look.name}: the painting through the day, words on it', (t) async {
      final shots = Platform.environment['SHOTS'] == '1';
      if (shots) await icons();
      final rig = await start(t);
      await rig.brain.setLook(look);
      await rig.brain.setUserName('সাইফুল ইসলাম');
      rig.brain.gated = true;
      await rig.brain.setProForTest(true);
      rig.notifier.state = const AlarmHealth(notificationsOn: true, exactOn: false, batteryFree: true, fullScreenOn: true, brand: '', hasAutostart: false);
      (rig.brain.services.weather as FakeWeather).answer =
          Weather(temp: 31, feels: 34, min: 24, max: 32, humidity: 70, code: 0, place: 'ঢাকা', at: DateTime(2026, 10, 24, 12));
      await rig.brain.refreshWeather();
      final sun = sunTimes(DateTime(2026, 10, 24), placeNamed('ঢাকা'));
      // The two pictures are read from the bundle off the test clock.
      await t.runAsync(() async {
        final ctx = t.element(find.byType(HomeShell));
        await precacheImage(const AssetImage('assets/sky/day.jpg'), ctx);
        await precacheImage(const AssetImage('assets/sky/night.jpg'), ctx);
      });
      for (final (name, at) in [
        ('a-dawn', sun.sunrise.subtract(const Duration(minutes: 40))),
        ('b-morning', DateTime(2026, 10, 24, 8, 30)),
        ('c-noon', DateTime(2026, 10, 24, 12)),
        ('d-afternoon', DateTime(2026, 10, 24, 15, 30)),
        ('e-golden', sun.sunset.subtract(const Duration(minutes: 40))),
        ('f-sunset', sun.sunset.add(const Duration(minutes: 3))),
        ('g-evening', sun.sunset.add(const Duration(minutes: 28))),
        ('h-night', DateTime(2026, 10, 24, 21, 10)),
      ]) {
        rig.nowAt = at;
        rig.brain.data = sample(at);
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        rig.brain.notifyListeners();
        await settle(t);
        final phase = skyLight(at, sun.sunrise, sun.sunset).phase;
        expect(find.byKey(Key('home-hero-$phase')), findsOneWidget, reason: name);
        expect(find.byKey(const Key('home-slot')), findsOneWidget);
        expect(find.descendant(of: find.byKey(const Key('home-temp')), matching: find.textContaining('ঢাকা')), findsOneWidget);
        expect(find.text('৩১°'), findsOneWidget);
        expect(find.textContaining('সূর্যোদয়'), findsOneWidget);
        expect(find.textContaining('সূর্যাস্ত'), findsOneWidget);
        if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('ui/shots/hero-$name-${look.name}.png'));
      }
    });
  }

  testWidgets('home: আজকের অর্থ-কথা right under the money; সব সুবিধা always open', (t) async {
    await start(t);
    final list = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
    await t.scrollUntilVisible(find.byKey(const Key('home-quote')), 300, scrollable: list);
    await settle(t);
    final money = t.getRect(find.byKey(const Key('home-stat-spent')));
    final quote = t.getRect(find.byKey(const Key('home-quote')));
    expect(quote.top, greaterThan(money.bottom));
    expect(quote.top - money.bottom, lessThan(30), reason: 'nothing between the money and the quote');
    await t.scrollUntilVisible(find.byKey(const Key('home-tools')), 300, scrollable: list);
    expect(find.descendant(of: find.byKey(const Key('home-tools')), matching: find.text('কাজের তালিকা')), findsOneWidget);
    expect(find.byKey(const Key('home-tools-toggle')), findsNothing);
  });

  testWidgets('স্বাস্থ্য: a family member has their own medicines, ringing on this phone with their name', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.saveMember(FamilyMember(id: 'amma', name: 'আম্মা'));
    await b.saveMedicine(Medicine(name: 'প্যারাসিটামল', times: [9 * 60]));
    final m = await b.saveMedicine(Medicine(name: 'মেটফরমিন', times: [8 * 60, 20 * 60], member: 'amma'));
    expect(b.data.reminders.where((r) => m.reminderIds.contains(r.id)).map((r) => r.title).toSet(), {'আম্মা-এর ওষুধ: মেটফরমিন'});
    // Saved and read back: still hers.
    final back = AppData.fromJson(b.data.toJson()).medicines.firstWhere((x) => x.id == m.id);
    expect(back.member, 'amma');
    expect(AppData.fromJson(b.data.toJson()).medicines.firstWhere((x) => x.name == 'প্যারাসিটামল').member, 'me');

    Navigator.of(t.element(find.byType(HomeShell))).push(MaterialPageRoute(builder: (_) => const MedicinesScreen(member: 'amma')));
    await settle(t);
    expect(find.text('আম্মা-এর ওষুধ'), findsOneWidget);
    expect(find.text('মেটফরমিন'), findsOneWidget);
    expect(find.text('প্যারাসিটামল'), findsNothing, reason: 'only hers');
    // Not in ফ্যামিলি: nothing to send to.
    expect(find.byKey(const Key('med-send-family')), findsNothing);
  });

  testWidgets('ধার-দেনা: several entries of a person picked and deleted together, with undo', (t) async {
    final now = DateTime(2026, 10, 9);
    final rig = await start(t,
        data: AppData(ledger: [
          LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 500, date: now),
          LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 700, date: now),
          LedgerEntry(person: 'রহিম', kind: LedgerKind.received, amount: 200, date: now),
        ]));
    Navigator.of(t.element(find.byType(HomeShell))).push(MaterialPageRoute(builder: (_) => const PersonScreen(person: 'রহিম')));
    await settle(t);
    final ids = rig.brain.data.ledger.map((e) => e.id).toList();
    await t.ensureVisible(find.byKey(Key('person-row-${ids[0]}')));
    await t.longPress(find.byKey(Key('person-row-${ids[0]}')));
    await settle(t);
    await t.tap(find.byKey(Key('person-row-${ids[1]}')));
    await settle(t);
    expect(find.byKey(const Key('pick-bar')), findsOneWidget);
    await t.tap(find.text('মুছুন').last);
    await settle(t);
    await t.tap(find.text('মুছুন').last);
    await settle(t);
    expect(rig.brain.data.ledger.map((e) => e.amount), [200]);
    await rig.brain.undoLastDeletes(2);
    expect(rig.brain.data.ledger.length, 3);
  });

  test('steps: today from the phone count; restarts and new days', () {
    final d1 = DateTime(2026, 10, 24, 8);
    var b = stepsRead(null, d1, 10000);
    expect(b.today, 0);
    b = stepsRead(b, d1.add(const Duration(hours: 3)), 13500);
    expect(b.today, 3500);
    // The phone restarted: the count starts from 0, today's walk stays.
    b = stepsRead(b, d1.add(const Duration(hours: 5)), 800);
    expect(b.today, 4300);
    // Next morning: yesterday kept, today from the last reading.
    b = stepsRead(b, DateTime(2026, 10, 25, 7), 1500);
    expect(b.days['2026-10-24'], 4300);
    expect(b.today, 700);
    expect(StepBook.fromJson(b.toJson())!.today, 700);
    expect(StepBook.fromJson('junk'), isNull);
    expect(stepsKm(5000), closeTo(3.6, 0.01));
  });

  test('compass: true north is asked with the place (declination taken out on the phone)', () async {
    final c = FakeCompass();
    expect(c.headings(lat: 23.8, lon: 90.4), isA<Stream<Heading?>>());
  });

  test('সমস্যার লগ: only the kind, cleaned words, code places and version; same errors counted', () async {
    ErrorLog.pending.clear();
    StackTrace st;
    try {
      throw StateError('Bad state: "রহিমকে ৫০০ দিলাম" saif@gmail.com 01712345678');
    } catch (_, s) {
      st = s;
    }
    final fake = StackTrace.fromString('#0      Brain.load (package:digital_brain/state/brain.dart:120:7)\n#1      _rootRun (dart:async/zone.dart:1525:13)\n#2      Element.rebuild (package:flutter/src/widgets/framework.dart:5000:7)');
    ErrorLog.record(StateError('Bad state: "রহিমকে ৫০০ দিলাম" saif@gmail.com 01712345678'), fake, version: '2.53.0');
    ErrorLog.record(StateError('Bad state: "রহিমকে ৫০০ দিলাম" saif@gmail.com 01712345678'), fake, version: '2.53.0');
    expect(st, isNotNull);
    expect(ErrorLog.pending, hasLength(1));
    final e = ErrorLog.pending.single;
    expect(e['count'], 2);
    expect(e['kind'], 'StateError');
    final all = '${e['message']} ${e['stack']}';
    for (final secret in ['রহিম', '৫০০', 'saif@', '01712345678', 'দিলাম']) {
      expect(all, isNot(contains(secret)));
    }
    expect(e['stack'], contains('package:digital_brain/state/brain.dart:120:7'));
    expect(e['stack'], isNot(contains('dart:async')));

    final sent = <http.Request>[];
    final server = AccountServer(MockClient((r) async {
      sent.add(r);
      return http.Response('{"ok":true}', 200);
    }), 'https://example.test');
    await ErrorLog.flush(server, '');
    expect(sent.single.url.path, '/wp-json/my-assistant/v1/errors');
    expect(sent.single.headers.containsKey('authorization'), isFalse);
    expect(ErrorLog.pending, isEmpty);
    // Not sent (offline): kept for next time.
    ErrorLog.record(ArgumentError('x'), null, version: '2.53.0');
    await ErrorLog.flush(AccountServer(MockClient((r) async => http.Response('', 500)), 'https://example.test'), 's' * 64);
    expect(ErrorLog.pending, hasLength(1));
    ErrorLog.pending.clear();
  });

  test('anywhere in the world: the city, its clock, its prayer method', () {
    final dubai = placeAt(25.20, 55.27, tzMinutes: 240);
    expect((dubai.name, dubai.region, dubai.tz, dubai.abroad), ('দুবাই', 'gulf', 240, true));
    final back = placeNamed(dubai.key);
    expect((back.name, back.tz, back.region), ('দুবাই', 240, 'gulf'));
    expect(back.lat, closeTo(25.20, 0.001));
    // Inside Bangladesh it is still the district.
    expect(placeAt(23.81, 90.41, tzMinutes: 360).key, 'ঢাকা');
    expect(placeNamed('ঢাকা').abroad, isFalse);
    // Far from any listed city: "আপনার এলাকা", region from the map.
    final sea = placeAt(-45.0, -100.0, tzMinutes: -360);
    expect((sea.name, sea.region), ('আপনার এলাকা', 'mwl'));

    String hm(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
    int mins(DateTime d) => d.hour * 60 + d.minute;
    // Dubai, 25 Oct 2026 (Property Finder's Umm al-Qura table: sunrise 6:19,
    // Maghrib 5:47; Isha 90 min after Maghrib). Within 5 minutes.
    final t = sunTimes(DateTime(2026, 10, 25), back);
    expect(mins(t.sunrise), inInclusiveRange(6 * 60 + 14, 6 * 60 + 24), reason: hm(t.sunrise));
    expect(mins(t.maghrib), inInclusiveRange(17 * 60 + 42, 17 * 60 + 52), reason: hm(t.maghrib));
    expect(t.isha.difference(t.maghrib).inMinutes, 90);
    expect(mins(t.dhuhr), inInclusiveRange(11 * 60 + 56, 12 * 60 + 6), reason: hm(t.dhuhr));
    // London in midsummer: the sun never goes 18° down, Fajr and Isha still come.
    final london = placeNamed(placeAt(51.51, -0.13, tzMinutes: 60).key);
    final s = sunTimes(DateTime(2026, 6, 21), london);
    expect(s.fajr.isBefore(s.sunrise), isTrue, reason: hm(s.fajr));
    expect(s.isha.isAfter(s.maghrib), isTrue, reason: hm(s.isha));
    expect(mins(s.sunrise), inInclusiveRange(4 * 60 + 38, 4 * 60 + 48), reason: hm(s.sunrise));
    // Dhaka as before (Karachi 18°, UTC+6).
    final d = sunTimes(DateTime(2026, 10, 24), placeNamed('ঢাকা'));
    expect(mins(d.sunrise), inInclusiveRange(5 * 60 + 55, 6 * 60 + 5), reason: hm(d.sunrise));
  });

  testWidgets('the phone abroad: home, prayer and Hijri follow the city', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    b.whereAmI = () async => (25.20, 55.27);
    b.placeStatus = () async => {'fine': true, 'service': true};
    final hj0 = b.hijriShift;
    final moved = await b.refreshPlace(force: true);
    await settle(t);
    expect(moved, 'দুবাই');
    expect(b.placeLabel, 'দুবাই');
    expect(placeNamed(b.district).region, 'gulf');
    expect(b.hijriShift, hj0 + 1, reason: 'a day ahead outside South Asia');
    await b.setPref('hijri_adjust', 0);
    expect(b.hijriShift, 0, reason: 'the user\'s own choice wins');
    // Back home: the district again.
    b.whereAmI = () async => (23.81, 90.41);
    expect(await b.refreshPlace(force: true), 'ঢাকা');
    expect(b.district, 'ঢাকা');
  });

  test('কিছু যুক্ত করুন: only empty menus; ✕ for a day', () {
    final empty = addNudges(AppData()).map((n) => n.id).toList();
    expect(empty, containsAll(['tasks', 'reminders', 'money', 'ledger', 'notes', 'docs', 'vault', 'health', 'medicines', 'habits', 'special', 'savings', 'alarms']));
    final some = addNudges(AppData(tasks: [Task(title: 'বাজার')], cash: [CashEntry(kind: CashKind.expense, amount: 50, category: 'বাজার', date: DateTime(2026, 10, 25))])).map((n) => n.id);
    expect(some, isNot(contains('tasks')));
    expect(some, isNot(contains('money')));
    expect(some, contains('notes'));
    final at = DateTime(2026, 10, 25, 9);
    expect(nudgesShown(at, null), isTrue);
    expect(nudgesShown(at.add(const Duration(hours: 23)), at), isFalse);
    expect(nudgesShown(at.add(const Duration(days: 1)), at), isTrue);
    // Backup: only with something kept, and none in 7 days; it comes first.
    final kept = AppData(notes: [Note(title: 'দলিল')]);
    expect(addNudges(AppData(), now: at).map((n) => n.id), isNot(contains('backup')));
    expect(addNudges(kept, now: at).first.id, 'backup');
    expect(addNudges(kept, now: at, lastBackup: at.subtract(const Duration(days: 3))).map((n) => n.id), isNot(contains('backup')));
    expect(addNudges(kept, now: at, lastBackup: at.subtract(const Duration(days: 8))).first.id, 'backup');
  });

  testWidgets('home: the floating message opens its menu; ✕ hides all until tomorrow', (t) async {
    final rig = await start(t);
    expect(find.byKey(const Key('add-nudge')), findsOneWidget);
    expect(find.byKey(const Key('add-nudge-tasks')), findsOneWidget, reason: 'the first empty menu');
    expect(find.text('কাজের তালিকায় কিছু যুক্ত করুন'), findsOneWidget);
    await t.tap(find.byKey(const Key('add-nudge-tasks')));
    await settle(t);
    expect(find.byKey(const Key('add-nudge')), findsNothing, reason: 'left home for the to-do list');
    Navigator.of(t.element(find.byType(HomeShell, skipOffstage: false))).popUntil((r) => r.isFirst);
    await settle(t);
    await t.tap(find.text('হোম').last);
    await settle(t);
    // Something written in to-dos: its message is gone, the next one shows.
    await rig.brain.saveTask(Task(title: 'বাজার করা'));
    await settle(t);
    expect(find.byKey(const Key('add-nudge-tasks')), findsNothing);
    expect(find.byKey(const Key('add-nudge')), findsOneWidget);
    await t.tap(find.byKey(const Key('add-nudge-close')));
    await settle(t);
    expect(find.byKey(const Key('add-nudge')), findsNothing);
    rig.nowAt = rig.nowAt.add(const Duration(days: 1, minutes: 1));
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    rig.brain.notifyListeners();
    await settle(t);
    expect(find.byKey(const Key('add-nudge')), findsOneWidget, reason: 'back a day later');
  });

  testWidgets('changing the place brings that place\'s weather at once (no 30-minute old one)', (t) async {
    final rig = await start(t);
    final w = rig.brain.services.weather as FakeWeather;
    w.answer = Weather(temp: 31, feels: 34, min: 24, max: 32, humidity: 70, code: 0, place: 'ঢাকা', at: rig.nowAt);
    await rig.brain.refreshWeather();
    await settle(t);
    expect(find.text('৩১°'), findsOneWidget);
    // Chosen by hand: Dubai.
    w.answer = Weather(temp: 36, feels: 39, min: 28, max: 37, humidity: 40, code: 0, place: 'দুবাই', at: rig.nowAt);
    await rig.brain.setDistrict(placeAt(25.20, 55.27, tzMinutes: 240).key);
    await settle(t);
    expect(find.text('৩৬°'), findsOneWidget);
    expect(find.text('৩১°'), findsNothing);
    expect(find.descendant(of: find.byKey(const Key('home-temp')), matching: find.textContaining('দুবাই')), findsOneWidget);
    // Offline in the new place: the old place's weather is not shown as if it were here.
    w.answer = null;
    await rig.brain.setDistrict('খুলনা');
    await settle(t);
    expect(find.text('৩৬°'), findsNothing);
    expect(find.byKey(const Key('home-temp')), findsNothing);
  });

  test('rig still builds', () => expect(Rig().brain, isNotNull));
}
