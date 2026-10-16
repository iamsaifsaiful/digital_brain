// v2.15: Google sign-in before the PIN, the menu, the diary, bills, the
// calendar, contacts, feedback, the new free/Pro rules and the own colour.
import 'dart:convert';

import 'package:digital_brain/app.dart';
import 'package:digital_brain/logic/pro.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/lock_screen.dart' show googleFirst;
import 'package:digital_brain/services/google_account.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'app_test.dart' show Rig, enterPin, loadFonts, openMenu, settle, start;

/// A shortcut in the home menu (scrolled into view first).
Future<void> tapMenu(WidgetTester t, String label) async {
  final f = find.descendant(of: find.byType(GridView), matching: find.text(label));
  await t.ensureVisible(f);
  await settle(t);
  await t.tap(f);
  await settle(t);
}

void main() {
  testWidgets('a new install: Google sign-in first, then the PIN', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await loadFonts();
    showOnboarding = false;
    googleFirst = true;
    addTearDown(() => googleFirst = false);
    final google = FakeGoogle()..user = const GoogleUser(id: '1', email: 'saif@gmail.com', name: 'Saif Saiful', idToken: 'tok');
    final rig = Rig(google: google);
    await t.pumpWidget(DigitalBrainApp(brain: rig.brain));
    await rig.brain.load();
    await settle(t);
    expect(find.text('শুরু করতে Google দিয়ে লগইন করুন'), findsOneWidget);
    expect(find.text('একটি ৪ অঙ্কের PIN ঠিক করুন'), findsNothing);
    await t.tap(find.byKey(const Key('welcome-google')));
    await settle(t);
    expect(rig.brain.googleEmail, 'saif@gmail.com');
    expect(rig.brain.userName, 'Saif');
    expect(find.text('একটি ৪ অঙ্কের PIN ঠিক করুন'), findsOneWidget);
    await enterPin(t, '1234');
    await enterPin(t, '1234');
    expect(rig.brain.unlocked, isTrue);
  });

  testWidgets('the welcome page can be skipped', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await loadFonts();
    showOnboarding = false;
    googleFirst = true;
    addTearDown(() => googleFirst = false);
    final rig = Rig();
    await t.pumpWidget(DigitalBrainApp(brain: rig.brain));
    await rig.brain.load();
    await settle(t);
    await t.tap(find.byKey(const Key('welcome-later')));
    await settle(t);
    expect(find.text('একটি ৪ অঙ্কের PIN ঠিক করুন'), findsOneWidget);
  });

  testWidgets('home menu: one হিসাব (no separate আয়-ব্যয়), settings inside the menu, most used first', (t) async {
    await start(t);
    final grid = find.byType(GridView);
    expect(find.descendant(of: grid, matching: find.text('আয়-ব্যয়')), findsNothing);
    expect(find.descendant(of: grid, matching: find.text('লেনদেন')), findsNothing);
    expect(find.descendant(of: grid, matching: find.text('হিসাব')), findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('সেটিংস')), findsOneWidget);
    expect(find.byTooltip('সেটিংস'), findsNothing, reason: 'no settings icon at the top');
    final first = t.getTopLeft(find.descendant(of: grid, matching: find.text('কাজের তালিকা')));
    final alarm = t.getTopLeft(find.descendant(of: grid, matching: find.text('অ্যালার্ম')));
    expect(first.dy < alarm.dy || first.dx < alarm.dx, isTrue);
    await tapMenu(t, 'হিসাব');
    expect(find.text('অন্যান্য হিসাব'), findsOneWidget);
    expect(find.text('আলাদা হিসাব'), findsNothing);
  });

  testWidgets('দিনলিপি: the add button is at the bottom and makes a to-do, not a reminder', (t) async {
    final rig = await start(t);
    await t.tap(find.text('দিনলিপি').last);
    await settle(t);
    final add = find.byKey(const Key('diary-add'));
    expect(add, findsOneWidget);
    expect(t.getCenter(add).dy, greaterThan(t.view.physicalSize.height / t.view.devicePixelRatio / 2));
    await t.tap(add);
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'বাজার করা');
    await t.ensureVisible(find.text('রাখুন'));
    await settle(t);
    await t.tap(find.text('রাখুন'));
    await settle(t);
    expect(rig.brain.data.tasks.single.title, 'বাজার করা');
    expect(rig.brain.data.reminders, isEmpty);
  });

  testWidgets('reminders page lists the monthly bills; one tap and a day sets one', (t) async {
    final rig = await start(t);
    await tapMenu(t, 'রিমাইন্ডার');
    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.byKey(const Key('bill-বিদ্যুৎ বিল')), 200, scrollable: list);
    expect(find.text('এ মাসের বিল মনে করানো'), findsOneWidget);
    await t.tap(find.byKey(const Key('bill-বিদ্যুৎ বিল')));
    await settle(t);
    await t.tap(find.widgetWithText(ChoiceChip, '১২'));
    await settle(t);
    final r = rig.brain.data.reminders.single;
    expect(r.title, 'বিদ্যুৎ বিল');
    expect(r.repeat, Repeat.monthly);
    expect(r.date, DateTime(2026, 10, 12));
    expect(find.textContaining('প্রতি মাসের ১২ তারিখ'), findsWidgets);
  });

  testWidgets('calendar: Arabic (Hijri) dates on a tab; a tapped day shows its plans and adds to it', (t) async {
    final rig = await start(t, data: AppData(reminders: [Reminder(title: 'ডাক্তার', date: DateTime(2026, 10, 20), hour: 11)]));
    await tapMenu(t, 'ক্যালেন্ডার');
    final list0 = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.text('আরবি (হিজরি) তারিখ'), 200, scrollable: list0);
    await t.tap(find.text('আরবি (হিজরি) তারিখ'));
    await settle(t);
    final list = find.byType(Scrollable).first;
    final day = find.byKey(const Key('day-2026-10-20'));
    await t.scrollUntilVisible(day, 200, scrollable: list);
    await t.tap(day);
    await settle(t);
    expect(find.text('ডাক্তার'), findsOneWidget);
    await t.tap(find.byKey(const Key('cal-add-task')));
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'রিপোর্ট আনা');
    await t.ensureVisible(find.text('রাখুন'));
    await settle(t);
    await t.tap(find.text('রাখুন'));
    await settle(t);
    final task = rig.brain.data.tasks.single;
    expect(task.title, 'রিপোর্ট আনা');
    expect(task.due, DateTime(2026, 10, 20));
  });

  testWidgets('settings: profile rows are separate; blood donation is here; no AI row under অন্যান্য', (t) async {
    final rig = await start(t);
    rig.brain.gated = true;
    await openMenu(t, 'সেটিংস');
    for (final k in ['profile-name', 'profile-place', 'profile-blood']) {
      expect(t.getSize(find.byKey(Key(k))).height, greaterThanOrEqualTo(56));
    }
    await t.tap(find.byKey(const Key('profile-blood')));
    await settle(t);
    await t.tap(find.widgetWithText(ChoiceChip, 'B+'));
    await settle(t);
    expect(rig.brain.data.emergency.blood, 'B+');
    final list = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.text('আমি রক্ত দিতে আগ্রহী'), 200, scrollable: list);
    await t.scrollUntilVisible(find.text('মতামত বা সমস্যা জানান'), 200, scrollable: list);
    expect(find.text('AI সহকারী'), findsNothing);
  });

  testWidgets('feedback goes to the server with the session', (t) async {
    late http.Request sent;
    final client = MockClient((r) async {
      if (r.url.path.endsWith('/login')) return http.Response(jsonEncode({'ok': true, 'session': 'b' * 64}), 200);
      if (r.url.path.endsWith('/feedback')) {
        sent = r;
        return http.Response('{"ok":true}', 200);
      }
      return http.Response('{}', 404);
    });
    final google = FakeGoogle()..user = const GoogleUser(id: '1', email: 'a@gmail.com', name: 'A', idToken: 'tok');
    final rig = Rig(server: AccountServer(client, 'https://example.test'), google: google);
    await rig.brain.load();
    expect(await rig.brain.signInGoogle(), isNull);
    expect(await rig.brain.sendFeedback('idea', 'ক্যালেন্ডারে চাঁদের ছবি চাই', '2.15.0'), isNull);
    expect(sent.headers['authorization'], 'Bearer ${'b' * 64}');
    expect(jsonDecode(sent.body), {'kind': 'idea', 'text': 'ক্যালেন্ডারে চাঁদের ছবি চাই', 'app_version': '2.15.0'});
  });

  test('free: Drive backup by hand only; Pro backs up by itself', () async {
    final google = FakeGoogle()..user = const GoogleUser(id: '1', email: 'a@gmail.com', name: 'A');
    final rig = Rig(google: google);
    final b = rig.brain;
    await b.load();
    b.gated = true;
    await b.signInGoogle();
    expect(await b.startDriveBackup('long-secret-1'), isNull);
    final drive = rig.services.drive as FakeDrive;
    expect(drive.files.length, 1);
    await b.saveNote(Note(title: 'নতুন', body: 'x', category: 'অন্যান্য'));
    await rig.services.lock.keys.write('drive_last', DateTime(2026, 10, 1).toIso8601String());
    await b.load();
    final before = drive.files.keys.toSet();
    await b.autoDriveBackup();
    expect(drive.files.keys.toSet(), before, reason: 'free: no automatic backup');
    await b.activatePro(proPlans.last);
    await b.autoDriveBackup();
    expect(drive.files.keys.toSet(), isNot(before));
  });

  test('own colour: any colour becomes an accent dark enough for white letters', () {
    final a = accentFor(colorKey(const Color(0xFFFFEB3B)));
    expect(a.key, startsWith('#'));
    expect(HSLColor.fromColor(a.main).lightness, lessThanOrEqualTo(0.451));
    expect(accentFor('#zzzzzz').key, 'green');
  });
}
