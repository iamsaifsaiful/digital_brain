// v2.15: Google sign-in before the PIN, the menu, the diary, bills, the
// calendar, contacts, feedback, the new free/Pro rules and the own colour.
import 'dart:convert';
import 'dart:typed_data';

import 'package:digital_brain/app.dart';
import 'package:digital_brain/logic/pro.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/brain.dart' show BrainScope;
import 'package:digital_brain/screens/money_more_screens.dart' show ReportScreen;
import 'package:digital_brain/logic/money_more.dart';
import 'package:digital_brain/screens/lock_screen.dart' show googleFirst;
import 'package:digital_brain/services/community.dart';
import 'package:digital_brain/services/google_account.dart';
import 'package:digital_brain/services/launcher.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'pro_test.dart' show keyServer, tokenGoogle;
import 'app_test.dart' show Rig, enterPin, loadFonts, openMenu, settle, start, vScroll;

/// A shortcut in the home menu (scrolled into view first).
/// The new home (24 Oct) has the shortcuts near the bottom: bring them into view.
Future<void> toGrid(WidgetTester t) async {
  if (find.byType(GridView).evaluate().isNotEmpty) return;
  final list = t.state<ScrollableState>(vScroll().first);
  list.position.jumpTo(list.position.maxScrollExtent);
  await t.pump();
}

Future<void> tapMenu(WidgetTester t, String label) async {
  await toGrid(t);
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

  testWidgets('home menu: one হিসাব (no separate আয়-ব্যয়), no settings (it is in আরও), most used first', (t) async {
    await start(t);
    await toGrid(t);
    final grid = find.byType(GridView);
    expect(find.descendant(of: grid, matching: find.text('আয়-ব্যয়')), findsNothing);
    expect(find.descendant(of: grid, matching: find.text('লেনদেন')), findsNothing);
    expect(find.descendant(of: grid, matching: find.text('হিসাব')), findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('সেটিংস')), findsNothing, reason: 'settings live in আরও');
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

  testWidgets('settings: profile rows are separate; blood donation is its own page; no AI row under অন্যান্য', (t) async {
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
    expect(find.byKey(const Key('more-feedback')), findsOneWidget);
    final list = vScroll().first;
    // Blood donation has its own page now (no donor switch here).
    await t.scrollUntilVisible(find.text('তথ্য নিরাপদ রাখা'), 200, scrollable: list);
    expect(find.text('আমি রক্ত দিতে আগ্রহী'), findsNothing);
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
    final rig = Rig(google: tokenGoogle(), server: keyServer());
    final b = rig.brain;
    await b.load();
    b.gated = true;
    await b.signInGoogle();
    expect(await b.startDriveBackup(), isNull);
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

  testWidgets('forgot PIN: the same Google account sets a new PIN; another account does not', (t) async {
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await loadFonts();
    showOnboarding = false;
    googleFirst = false;
    final google = tokenGoogle('owner@gmail.com');
    final rig = Rig(google: google, server: keyServer());
    await t.pumpWidget(DigitalBrainApp(brain: rig.brain));
    await rig.brain.load();
    await settle(t);
    await enterPin(t, '1234');
    await enterPin(t, '1234');
    await rig.brain.signInGoogle();
    rig.brain.lockNow();
    await settle(t);
    // Someone picks a different account: refused.
    google.user = const GoogleUser(id: '2', email: 'thief@gmail.com', name: 'X', idToken: 'other-token');
    await t.tap(find.byKey(const Key('forgot-pin')));
    await settle(t);
    await t.tap(find.byKey(const Key('forgot-google')));
    await settle(t);
    expect(find.textContaining('অন্য Google অ্যাকাউন্ট'), findsOneWidget);
    expect(find.text('ঠিক আছে — এবার নতুন PIN ঠিক করুন'), findsNothing);
    // The owner's account: a new PIN.
    google.user = const GoogleUser(id: '1', email: 'owner@gmail.com', name: 'O', idToken: 'google-token');
    await t.tap(find.byKey(const Key('forgot-pin')));
    await settle(t);
    await t.tap(find.byKey(const Key('forgot-google')));
    await settle(t);
    expect(find.text('ঠিক আছে — এবার নতুন PIN ঠিক করুন'), findsOneWidget);
    await enterPin(t, '5678');
    await enterPin(t, '5678');
    expect(rig.brain.unlocked, isTrue);
  });

  testWidgets('feedback: a conversation with our team, a reply and an attachment', (t) async {
    final calls = <http.Request>[];
    final msgs = <Map<String, Object?>>[
      {'id': 1, 'from': 'member', 'admin': '', 'text': 'রিমাইন্ডার বাজেনি', 'created': '2026-10-09T08:00:00Z', 'file': null},
      {'id': 2, 'from': 'admin', 'admin': 'Saif', 'text': 'ব্যাটারি সেটিং দেখুন', 'created': '2026-10-09T09:00:00Z', 'file': {'name': 'how.png', 'mime': 'image/png', 'size': 70}},
    ];
    final client = MockClient((r) async {
      calls.add(r);
      final p = r.url.path.replaceFirst('/wp-json/my-assistant/v1', '');
      Object body = {};
      if (p == '/login') body = {'ok': true, 'session': 'e' * 64, 'backup_key': 'Kq3xY8vB2nLm9PzR4tW7sD1fG6hJ0aC5eU8iO2pQ9rS', 'feedback_unread': 1};
      if (p == '/feedback' && r.method == 'GET') {
        body = {'feedback': [{'id': 5, 'kind': 'problem', 'kind_label': 'সমস্যা', 'text': 'রিমাইন্ডার বাজেনি', 'updated': '2026-10-09T09:00:00Z', 'status': 'read', 'unread': true, 'last': {'from': 'admin', 'text': 'ব্যাটারি সেটিং দেখুন'}, 'count': 2}]};
      }
      if (p == '/feedback/5') body = {'feedback': {'id': 5, 'kind': 'problem', 'kind_label': 'সমস্যা', 'text': 'রিমাইন্ডার বাজেনি', 'status': 'read', 'unread': false}, 'messages': msgs};
      if (p == '/feedback/5/reply') {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        msgs.add({'id': 3, 'from': 'member', 'admin': '', 'text': j['text'], 'created': '2026-10-09T10:00:00Z', 'file': j['file'] == null ? null : {'name': j['file']['name'], 'mime': 'image/jpeg', 'size': 3}});
        body = {'ok': true, 'id': 3};
      }
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });
    await start(t);
    final server = AccountServer(client, 'https://example.test');
    final c = Community(server, () => 'e' * 64);
    final (threads, e) = await c.threads();
    expect(e, isNull);
    expect(threads.single.unread, isTrue);
    expect(threads.single.lastFromUs, isTrue);
    final (thread, list, e2) = await c.thread(5);
    expect(e2, isNull);
    expect(thread!.kindLabel, 'সমস্যা');
    expect(list[1].fromUs, isTrue);
    expect(list[1].file!.image, isTrue);
    expect(await c.reply(5, 'ঠিক হয়েছে', file: OutgoingFile(Uint8List.fromList([1, 2, 3]), 'photo.jpg')), isNull);
    final sent = jsonDecode(calls.last.body) as Map<String, dynamic>;
    expect(sent['text'], 'ঠিক হয়েছে');
    expect(sent['file']['name'], 'photo.jpg');
    expect(sent['file']['data'], base64Encode([1, 2, 3]));
    expect(calls.last.headers['authorization'], 'Bearer ${'e' * 64}');
  });

  test('blood requests: donor profile, ask, accept, close — through the server', () async {
    final calls = <http.Request>[];
    final client = MockClient((r) async {
      calls.add(r);
      final p = r.url.path.replaceFirst('/wp-json/my-assistant/v1', '');
      Object body = {};
      if (p == '/blood/donor') body = {'donor': {'on': true, 'blood': 'O-', 'district': 'ঢাকা', 'last_donated': null, 'phone': '01812345678'}};
      if (p == '/blood/requests' && r.method == 'POST') body = {'ok': true, 'id': 9, 'notified': 4};
      if (p == '/blood/requests' && r.method == 'GET') {
        body = {'requests': [{'id': 9, 'mine': true, 'by': 'রহিম', 'blood': 'B+', 'bags': 2, 'district': 'ঢাকা', 'hospital': 'ঢাকা মেডিকেল', 'need_by': '2026-10-10T04:00:00Z', 'phone': '01712345678', 'status': 'open', 'accepted': 1, 'donors': [{'name': 'করিম', 'phone': '01812345678', 'note': 'বিকেলে'}]}]};
      }
      if (p.endsWith('/accept')) body = {'ok': true, 'request': {'id': 9, 'mine': false, 'blood': 'B+', 'bags': 2, 'district': 'ঢাকা', 'need_by': '2026-10-10T04:00:00Z', 'phone': '01712345678', 'status': 'open', 'i_accepted': true}};
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });
    final c = Community(AccountServer(client, 'https://example.test'), () => 'e' * 64);
    final (d, e) = await c.setDonor(on: true, blood: 'O−', district: 'ঢাকা', phone: '01812345678', lastDonated: DateTime(2026, 6, 1));
    expect(e, isNull);
    expect(d.on, isTrue);
    final sentDonor = jsonDecode(calls.last.body) as Map<String, dynamic>;
    expect(sentDonor['blood'], 'O-', reason: 'the server keeps ASCII groups');
    expect(sentDonor['last_donated'], '2026-06-01');
    final (told, e2) = await c.ask(blood: 'B+', bags: 2, district: 'ঢাকা', hospital: 'ঢাকা মেডিকেল', needBy: DateTime(2026, 10, 10, 10), phone: '01712345678');
    expect(e2, isNull);
    expect(told, 4);
    final (mine, _) = await c.requests(scope: 'mine');
    expect(mine.single.donors.single.phone, '01812345678');
    expect(mine.single.blood, 'B+');
    final (acc, e3) = await c.act(9, 'accept', phone: '01812345678');
    expect(e3, isNull);
    expect(acc!.iAccepted, isTrue);
  });

  testWidgets('আরও tab: blood donation, Pro, feedback, যাকাত and ফ্যামিলি; the same in the home menu', (t) async {
    await start(t);
    await toGrid(t);
    final grid = find.byType(GridView);
    expect(find.descendant(of: grid, matching: find.text('ব্লাড ডোনেশন')), findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('যাকাত')), findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('ফ্যামিলি')), findsOneWidget);
    expect(find.descendant(of: grid, matching: find.text('অনুরোধ')), findsNothing, reason: 'not called অনুরোধ any more');
    expect(find.descendant(of: grid, matching: find.text('প্রিমিয়াম ভার্সন')), findsOneWidget);
    await t.tap(find.text('আরও').last);
    await settle(t);
    expect(find.byKey(const Key('more-requests')), findsOneWidget);
    expect(find.byKey(const Key('more-pro')), findsOneWidget);
    expect(find.byKey(const Key('more-feedback')), findsOneWidget);
    expect(find.byKey(const Key('more-zakat')), findsOneWidget);
    expect(find.byKey(const Key('more-family')), findsOneWidget);
    expect(find.text('রক্তের অনুরোধ'), findsNothing, reason: 'no separate request row in আরও');
    await t.tap(find.byKey(const Key('more-requests')));
    await settle(t);
    expect(find.text('ব্লাড ডোনেশন'), findsOneWidget);
    expect(find.textContaining('Google দিয়ে লগইন করুন'), findsWidgets, reason: 'not signed in yet');
  });

  test('own colour: any colour becomes an accent dark enough for white letters', () {
    final a = accentFor(colorKey(const Color(0xFFFFEB3B)));
    expect(a.key, startsWith('#'));
    expect(HSLColor.fromColor(a.main).lightness, lessThanOrEqualTo(0.451));
    expect(accentFor('#zzzzzz').key, 'forest'); // the default look (24 Oct)
  });

  testWidgets('মুছে ফেলা: a deleted note waits 30 days in আরও and comes back', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.saveNote(Note(title: 'গেটের কোড', body: '৪৪২১'));
    final id = b.data.notes.single.id;
    await b.deleteNote(id);
    expect(b.data.notes, isEmpty);
    expect(b.data.trash.single.kind, 'notes');
    // Saved and loaded again, it is still there.
    expect(AppData.fromJson(jsonDecode(jsonEncode(b.data.toJson()))).trash.single.title, 'গেটের কোড');

    await t.tap(find.text('আরও').last);
    await settle(t);
    final row = find.text('মুছে ফেলা');
    await t.ensureVisible(row);
    await settle(t);
    await t.tap(row);
    await settle(t);
    expect(find.text('গেটের কোড'), findsOneWidget);
    expect(find.textContaining('আর ৩০ দিন থাকবে'), findsOneWidget);
    await t.tap(find.byKey(Key('restore-${b.data.trash.single.id}')));
    await settle(t);
    expect(b.data.notes.single.id, id);
    expect(b.data.trash, isEmpty);
  });

  testWidgets('মুছে ফেলা: undo brings back the newest; a reminder comes back with its task; old ones go', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final now = b.services.now();
    await b.saveCash(CashEntry(kind: CashKind.expense, amount: 120, category: 'বাজার', date: now));
    await b.deleteCash(b.data.cash.single.id);
    expect(b.data.cash, isEmpty);
    await b.undoLastDelete();
    expect(b.data.cash.single.amount, 120);

    b.data.trash.add(TrashItem(kind: 'notes', title: 'পুরনো', deletedAt: now.subtract(const Duration(days: 31)), items: [('notes', Note(title: 'পুরনো').toJson())]));
    b.data.trash.add(TrashItem(kind: 'notes', title: 'নতুন', deletedAt: now.subtract(const Duration(days: 3)), items: [('notes', Note(title: 'নতুন').toJson())]));
    await b.purgeTrash();
    expect([for (final x in b.data.trash) x.title], ['নতুন']);
  });

  testWidgets('the delete notice goes away by itself', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.saveCash(CashEntry(kind: CashKind.expense, amount: 50, category: 'বাজার', date: b.services.now()));
    await settle(t);
    await openMenu(t, 'হিসাব');
    final more = find.byTooltip('বদলান বা মুছুন').first;
    await t.ensureVisible(more);
    await settle(t);
    await t.tap(more);
    await settle(t);
    await t.tap(find.text('মুছুন').last);
    await settle(t);
    await t.tap(find.text('মুছুন').last);
    await settle(t);
    expect(b.data.cash, isEmpty);
    final bar = find.byType(SnackBar);
    expect(bar, findsOneWidget);
    expect(t.widget<SnackBar>(bar).persist, isFalse);
    await t.pump(const Duration(seconds: 6));
    await settle(t);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('প্রো ভার্সন: features in brief, the website and Get Pro', (t) async {
    final rig = await start(t);
    await tapMenu(t, 'প্রিমিয়াম ভার্সন');
    expect(find.text('সংক্ষেপে'), findsOneWidget);
    final get = find.byKey(const Key('get-pro'));
    await t.scrollUntilVisible(get, 300, scrollable: vScroll().last);
    await settle(t);
    expect(find.text('Get Premium'), findsWidgets);
    await t.tap(get);
    await settle(t);
    final l = rig.services.launcher as FakeLauncher;
    expect(l.opened.last.toString(), proWebPage);
    await t.fling(find.text('Get Premium').first, const Offset(0, 3000), 3000);
    await settle(t);
    await t.tap(find.text('বিস্তারিত').first);
    await settle(t);
    await t.tap(find.byKey(const Key('pro-website')));
    await settle(t);
    expect(l.opened.last.toString(), proWebPage);
  });

  testWidgets('home: a greeting, today in numbers, the menu', (t) async {
    final rig = await start(t);
    await rig.brain.setUserName('সাইফ');
    await rig.brain.saveCash(CashEntry(kind: CashKind.expense, amount: 250, category: 'বাজার', date: rig.brain.services.now()));
    await settle(t);
    // The new home (24 Oct): the greeting on one line, the name big under it.
    expect(find.text('সাইফ'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^(সুপ্রভাত|শুভ \S+),$')), findsOneWidget);
    await t.scrollUntilVisible(find.text('এ মাসের হিসাব'), 300, scrollable: vScroll().first);
    expect(find.text('আজকের কাজ'), findsOneWidget);
    expect(find.text('এ মাসের হিসাব'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('home-stat-spent')), matching: find.textContaining('২৫০')), findsWidgets);
    await t.tap(find.byKey(const Key('home-stat-spent')));
    await settle(t);
    expect(find.text('অন্যান্য হিসাব'), findsOneWidget);
  });

  testWidgets('report: spending without a খাত is split by its note, and can be given one', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final now = b.services.now();
    expect(reportCategory(CashEntry(kind: CashKind.expense, amount: 60, category: 'অন্যান্য', note: 'রিকশা ভাড়া', date: now)), 'যাতায়াত');
    await b.saveCash(CashEntry(kind: CashKind.expense, amount: 9000, category: 'অন্যান্য', date: now));
    await b.saveCash(CashEntry(kind: CashKind.expense, amount: 500, category: 'অন্যান্য', note: 'ওষুধ', date: now));
    expect(monthReport(b.data, now).byCategory.map((e) => e.key), containsAll(['অন্যান্য', 'চিকিৎসা']));
    await t.pumpWidget(BrainScope(brain: b, child: const MaterialApp(home: ReportScreen())));
    await settle(t);
    final fix = find.byKey(const Key('fix-categories'));
    await t.ensureVisible(fix);
    await settle(t);
    await t.tap(fix);
    await settle(t);
    final big = b.data.cash.firstWhere((e) => e.amount == 9000);
    await t.tap(find.byKey(Key('unsorted-${big.id}')));
    await settle(t);
    await t.tap(find.widgetWithText(ActionChip, 'বাসা ভাড়া'));
    await settle(t);
    expect(b.data.cash.firstWhere((e) => e.id == big.id).category, 'বাসা ভাড়া');
    expect(find.text('সব খরচের খাত দেওয়া আছে'), findsOneWidget);
  });
}

