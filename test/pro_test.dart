import 'package:digital_brain/logic/ask.dart' show infoAnswer;
import 'package:digital_brain/logic/pro.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/crypto.dart';
import 'package:digital_brain/services/google_account.dart';
import 'package:digital_brain/services/lock.dart';
import 'package:digital_brain/screens/pro_screen.dart';
import 'dart:convert';

import 'package:digital_brain/services/ai.dart';
import 'package:digital_brain/services/push.dart';
import 'package:digital_brain/logic/server_notices.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, enterPin, settle, start, tell;

/// Our server, pretended: sign-in gives a session and the account's backup key.
AccountServer keyServer([String key = 'Kq3xY8vB2nLm9PzR4tW7sD1fG6hJ0aC5eU8iO2pQ9rS']) => AccountServer(
    MockClient((r) async {
      if (r.url.path.endsWith('/login') || r.url.path.endsWith('/me')) {
        return http.Response(jsonEncode({'ok': true, 'session': 'd' * 64, 'backup_key': key}), 200);
      }
      return http.Response('{}', 200);
    }),
    'https://example.test');

/// A Google user whose sign-in token our server accepts.
FakeGoogle tokenGoogle([String email = 'test@gmail.com']) => FakeGoogle()..user = GoogleUser(id: '1', email: email, name: 'Test', idToken: 'google-token');

Future<void> openChat(WidgetTester t) async {
  await t.tap(find.byTooltip('বলুন').first);
  await settle(t);
}

void main() {
  test('full-screen ads: never on the first day, at most 2 a day, 3 finished tasks apart', () {
    expect(fullAdDue(shown: 0, done: 3, firstDay: true), isFalse);
    expect(fullAdDue(shown: 0, done: 2, firstDay: false), isFalse);
    expect(fullAdDue(shown: 0, done: 3, firstDay: false), isTrue);
    expect(fullAdDue(shown: 2, done: 9, firstDay: false), isFalse);
  });

  group('Pro (Play app only)', () {
    test('the downloaded APK has everything; the Play app locks only adding more', () async {
      final rig = Rig();
      final b = rig.brain;
      expect(b.gated, isFalse);
      expect(b.pro, isTrue);
      expect(b.showAds, isFalse);

      b.gated = true;
      expect(b.pro, isFalse);
      expect(b.showAds, isTrue);
      b.data = AppData(
        shops: [Shop(name: 'বড় দোকান')],
        projects: [Project(name: 'বাড়ি')],
        vault: [for (var i = 0; i < freeVaultItems; i++) VaultItem(name: 'site$i', password: 'x')],
      );
      expect(b.canAddShop, isFalse);
      expect(b.canAddProject, isFalse);
      expect(b.canAddVault, isFalse);
      // A closed project does not count.
      b.data = AppData(projects: [Project(name: 'বাড়ি', closed: true)]);
      expect(b.canAddProject, isTrue);

      // New limits: 20 people in ধার-দেনা, 20 ringing reminders, 30 documents.
      b.data = AppData(
        ledger: [for (var i = 0; i < freeLedgerPeople; i++) LedgerEntry(person: 'মানুষ$i', kind: LedgerKind.lent, amount: 10, date: DateTime(2026, 10))],
        reminders: [for (var i = 0; i < freeReminders; i++) Reminder(title: 'r$i', date: DateTime(2026, 11), hour: 9)],
        docs: [for (var i = 0; i < freeDocs; i++) Doc(title: 'd$i')],
      );
      expect(b.canAddPerson('মানুষ3'), isTrue, reason: 'someone already there');
      expect(b.canAddPerson('নতুন কেউ'), isFalse);
      expect(b.canAddReminder, isFalse);
      expect(b.canAddDoc, isFalse);
      // Reports: this month and the two before.
      expect(b.canSeeMonth(DateTime(2026, 8)), isTrue);
      expect(b.canSeeMonth(DateTime(2026, 7)), isFalse);
      expect(b.has(ProFeature.autoBackup), isFalse);

      await b.activatePro(proPlans.first);
      expect(b.pro, isTrue);
      expect(b.proKind, 'pro_yearly');
    });

    test('zakat is free; smart notices, paper expiry and pay-back reminders are Pro', () async {
      final rig = Rig();
      final b = rig.brain;
      final now = DateTime(2026, 10, 9);
      b.gated = true;
      expect(infoAnswer(b.data, 'আমার যাকাত কত?', now), isNot(contains('প্রো')));
      expect(b.assistantPrefs.smart, isFalse);
      expect(b.assistantPrefs.docAlerts, isFalse);
      expect(b.assistantPrefs.dueAlerts, isFalse);
      // Free: the date is kept, no reminder.
      await b.saveEntry(LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 500, date: DateTime(2026, 10, 9), due: DateTime(2026, 11, 1)));
      final doc = Doc(title: 'পাসপোর্ট');
      await b.saveDoc(doc);
      await b.setDocExpiry(doc, DateTime(2027, 5, 1));
      expect(b.data.reminders, isEmpty);
      expect(b.data.ledger.single.due, DateTime(2026, 11, 1));
      // Pro comes on: both reminders are made from what was written.
      await b.activatePro(proPlans.last);
      expect(b.data.reminders.length, 2);
      expect(b.data.ledger.single.reminderId, isNotNull);
      expect(b.data.docs.single.reminderId, isNotNull);
      expect(b.assistantPrefs.smart, isTrue);
      expect(b.assistantPrefs.docAlerts, isTrue);
    });

    test('Pro survives a restart', () async {
      final rig = Rig();
      rig.brain.gated = true;
      await rig.brain.load();
      await rig.brain.activatePro(proPlans.first);
      final again = Rig.sharing(rig, keys: rig.services.lock.keys as MemoryKeyVault);
      again.brain.gated = true;
      await again.brain.load();
      expect(again.brain.pro, isTrue);
      expect(again.brain.proKind, 'pro_yearly');
    });
  });

  group('forgot PIN', () {
    test('the backup password sets a new PIN; wrong tries count with wrong PINs', () async {
      final rig = Rig();
      final lock = rig.services.lock;
      await lock.setPin('1234');
      expect(await lock.hasRecovery(), isFalse);
      await lock.setRecovery('long-secret-1');
      expect(await lock.hasRecovery(), isTrue);
      expect(await lock.checkRecovery('long-secret-1'), isA<PinOk>());
      for (var i = 0; i < LockService.freeTries - 1; i++) {
        expect(await lock.checkRecovery('wrong'), isA<PinWrong>());
      }
      // The fifth wrong try (PIN or password) starts the wait for both.
      expect(await lock.checkPin('0000'), isA<PinLocked>());
      expect(await lock.checkRecovery('long-secret-1'), isA<PinLocked>());
    });
  });

  group('Google Drive backup', () {
    test('signs in, backs up with the account key (no password), keeps only the newest; a failed upload keeps the old one', () async {
      final rig = Rig(server: keyServer(), google: tokenGoogle());
      final b = rig.brain;
      await b.load();
      final drive = rig.services.drive as FakeDrive;
      expect(await b.backupToDrive(), isNotNull); // not signed in
      expect(await b.signInGoogle(), isNull);
      expect(b.googleEmail, 'test@gmail.com');

      b.data = AppData(notes: [Note(title: 'গাড়ির কাগজ', body: 'আলমারিতে')]);
      expect(await b.startDriveBackup(), isNull);
      expect(drive.files.length, 1);
      expect(b.driveOn, isTrue);
      final first = drive.files.keys.single;

      expect(await b.backupToDrive(), isNull);
      expect(drive.files.length, 1);
      expect(drive.files.keys.single, isNot(first));

      final kept = drive.files.keys.single;
      drive.failUpload = true;
      expect(await b.backupToDrive(), contains('আপলোড'));
      expect(drive.files.keys.single, kept);

      // A new phone with the same account: the server gives the same key, and the backup opens.
      final other = Rig(server: keyServer(), google: tokenGoogle());
      await other.brain.load();
      await other.brain.signInGoogle();
      other.services.drive as FakeDrive;
      final list = await b.driveBackups();
      final bytes = drive.files[list.single.id]!.$2;
      (other.services.drive as FakeDrive).files[list.single.id] = (list.single, bytes);
      final (restored, _) = await other.brain.openDriveBackup(list.single);
      expect(restored.notes.single.title, 'গাড়ির কাগজ');
      // Another account's key does not open it.
      final stranger = Rig(server: keyServer('Zz9xY8vB2nLm9PzR4tW7sD1fG6hJ0aC5eU8iO2pQ9rS'), google: tokenGoogle('x@gmail.com'));
      await stranger.brain.load();
      await stranger.brain.signInGoogle();
      (stranger.services.drive as FakeDrive).files[list.single.id] = (list.single, bytes);
      await expectLater(stranger.brain.openDriveBackup(list.single), throwsA(anything));
    });

    test('backs up on leaving the app only when something changed', () async {
      final rig = Rig(server: keyServer(), google: tokenGoogle());
      final b = rig.brain;
      await b.load();
      final drive = rig.services.drive as FakeDrive;
      await b.signInGoogle();
      await b.startDriveBackup();
      final id = drive.files.keys.single;
      await b.autoDriveBackup();
      expect(drive.files.keys.single, id, reason: 'nothing changed');
      await b.saveNote(Note(title: 'নতুন', body: 'কিছু'));
      // Less than 30 minutes since the last one: waits.
      await b.autoDriveBackup();
      expect(drive.files.keys.single, id);
      b.lastDrive = DateTime(2026, 10, 9, 14);
      await b.autoDriveBackup();
      expect(drive.files.keys.single, isNot(id));
    });

    test('without the server there is no key, so no Drive backup', () async {
      final rig = Rig(google: tokenGoogle());
      await rig.brain.load();
      await rig.brain.signInGoogle();
      expect(await rig.brain.startDriveBackup(), contains('সার্ভারের'));
      expect((rig.services.drive as FakeDrive).files, isEmpty);
    });

    test('sign-out stops automatic backup and forgets its key', () async {
      final rig = Rig(server: keyServer(), google: tokenGoogle());
      final b = rig.brain;
      await b.load();
      await b.signInGoogle();
      await b.startDriveBackup();
      await b.signOutGoogle();
      expect(b.signedIn, isFalse);
      expect(b.driveOn, isFalse);
      expect(await rig.services.lock.keys.read('drive_pw'), isNull);
    });
  });

  testWidgets('Play app: a second project by voice is asked (general account only on a yes) and offers Pro; vault limit', (t) async {
    final rig = await start(t);
    rig.brain.gated = true;
    rig.brain.data = AppData(
      projects: [Project(name: 'বাড়ি')],
      vault: [for (var i = 0; i < freeVaultItems; i++) VaultItem(name: 'site$i', password: 'x')],
    );
    await settle(t);
    await openChat(t);
    await tell(t, rig, 'রহিম ভবন প্রজেক্টে ৫০ হাজার টাকা এলো');
    await settle(t);
    // Nothing is written anywhere until the user chooses the general account.
    expect(rig.brain.data.cash, isEmpty);
    expect(find.widgetWithText(ActionChip, 'সাধারণ আয়-ব্যয়ে লিখুন'), findsOneWidget);
    expect(find.textContaining('প্রো সুবিধা'), findsWidgets);
    await tell(t, rig, 'হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.projects.length, 1);
    expect(rig.brain.data.cash.single.projectId, isNull);

    await tell(t, rig, 'ফেসবুকের পাসওয়ার্ড ১২২৩৯৯৩৯');
    if (find.widgetWithText(ActionChip, 'হ্যাঁ').evaluate().isNotEmpty) await tell(t, rig, 'হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.vault.length, freeVaultItems);
    expect(find.textContaining('পূর্ণ হয়ে গেছে'), findsWidgets);

    await tell(t, rig, 'প্রো খোলো');
    await settle(t);
    expect(find.byType(ProScreen), findsOneWidget);
    expect(find.textContaining('ফ্রি চালু করুন'), findsNothing, reason: 'no trial');
    expect(find.byKey(const Key('get-pro')), findsOneWidget);
    await t.tap(find.text('বিস্তারিত').first);
    await settle(t);
    expect(find.byKey(const Key('pro-website')), findsOneWidget);
    final list = find.descendant(of: find.byType(ProScreen), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text('ফ্রি ভার্সনে বিজ্ঞাপন কোথায় দেখাবে'), 300, scrollable: list);
    expect(find.textContaining('দিনে সর্বোচ্চ ২টা'), findsOneWidget);
  });

  testWidgets('forgot PIN: the backup password lets the owner set a new PIN', (t) async {
    final rig = await start(t);
    final lock = rig.services.lock;
    rig.brain.lockNow();
    await settle(t);
    // Without fingerprint or backup password: explained, nothing opens.
    await t.tap(find.byKey(const Key('forgot-pin')));
    await settle(t);
    expect(find.byKey(const Key('forgot-password')), findsNothing);
    expect(find.textContaining('PIN ছাড়া খোলা যাবে না'), findsOneWidget);
    await t.tapAt(const Offset(20, 20));
    await settle(t);

    await lock.setRecovery('long-secret-1');
    await t.tap(find.byKey(const Key('forgot-pin')));
    await settle(t);
    await t.tap(find.byKey(const Key('forgot-password')));
    await settle(t);
    await t.enterText(find.byKey(const Key('recovery-field')), 'wrong-one');
    await t.tap(find.byKey(const Key('recovery-ok')));
    await settle(t);
    expect(find.textContaining('পাসওয়ার্ড মেলেনি'), findsOneWidget);
    expect(rig.brain.unlocked, isFalse);

    await t.tap(find.byKey(const Key('forgot-pin')));
    await settle(t);
    await t.tap(find.byKey(const Key('forgot-password')));
    await settle(t);
    await t.enterText(find.byKey(const Key('recovery-field')), 'long-secret-1');
    await t.tap(find.byKey(const Key('recovery-ok')));
    await settle(t);
    expect(find.text('ঠিক আছে — এবার নতুন PIN ঠিক করুন'), findsOneWidget);
    await enterPin(t, '5678');
    await enterPin(t, '5678');
    expect(rig.brain.unlocked, isTrue);
    expect(await lock.checkPin('5678'), isA<PinOk>());
  });

  testWidgets('free Play app: sample ad spaces on home; PDF asks for Pro', (t) async {
    final rig = await start(t);
    rig.brain.gated = true;
    rig.brain.adSamples = true;
    await settle(t);
    expect(find.byKey(const Key('ad-banner')), findsOneWidget);
    await rig.brain.setProForTest(true);
    await settle(t);
    expect(find.byKey(const Key('ad-banner')), findsNothing);
    await rig.brain.setProForTest(false);
    await settle(t);
    await openChat(t);
    await tell(t, rig, 'পিডিএফ দাও');
    await settle(t);
    expect(find.textContaining('PDF রিপোর্ট — প্রো সুবিধা'), findsOneWidget);
  });

  group('AI through our server (the key never in the app)', () {
    test('sign-in gives a session; AI is on only while the server has the account as Pro', () async {
      final calls = <http.Request>[];
      final client = MockClient((r) async {
        calls.add(r);
        if (r.url.path.endsWith('/login')) {
          return http.Response(jsonEncode({'ok': true, 'trial_used': true, 'pro_until': '2026-11-01T00:00:00Z', 'pro_kind': 'manual', 'session': 'a' * 64, 'ai': true, 'ai_left': 50}), 200);
        }
        if (r.url.path.endsWith('/device')) return http.Response('{"ok":true}', 200);
        if (r.url.path.endsWith('/me')) {
          return http.Response(jsonEncode({'ok': true, 'trial_used': true, 'pro_until': null, 'pro_kind': '', 'ai': true, 'ai_left': 0}), 200);
        }
        return http.Response('{}', 404);
      });
      final google = FakeGoogle()..user = const GoogleUser(id: '1', email: 'a@gmail.com', name: 'A', idToken: 'token-from-google');
      final rig = Rig(server: AccountServer(client), google: google);
      final b = rig.brain;
      b.gated = true;
      await b.load();
      expect(b.aiOn, isFalse);
      (rig.services.push as FakePush).value = 'fcm-token-of-this-phone-123';
      expect(await b.signInGoogle(appVersion: '2.14.0'), isNull);
      final device = calls.where((r) => r.url.path.endsWith('/device')).toList();
      expect(device.length, 1, reason: 'push token sent once');
      expect(jsonDecode(device.single.body)['token'], 'fcm-token-of-this-phone-123');
      expect(device.single.headers['authorization'], 'Bearer ${'a' * 64}');
      expect(jsonDecode(calls.firstWhere((r) => r.url.path.endsWith('/login')).body)['id_token'], 'token-from-google');
      expect(rig.services.ai.session, 'a' * 64);
      expect(b.aiByServer, isTrue);
      expect(b.aiOn, isTrue);
      // Pro given on the website shows up on the phone.
      expect(b.pro, isTrue);
      expect(await rig.services.lock.keys.read('srv_session'), 'a' * 64);

      // The server ends Pro: AI goes off at the next refresh.
      await b.refreshAccount(force: true);
      expect(calls.lastWhere((r) => r.url.path.endsWith('/me')).headers['authorization'], 'Bearer ${'a' * 64}');
      expect(b.aiByServer, isFalse);

      await b.signOutGoogle();
      expect(rig.services.ai.session, isEmpty);
      expect(await rig.services.lock.keys.read('srv_session'), isNull);
    });

    test('requests go to the server with the session, never with an API key', () async {
      late http.Request sent;
      final ai = ClaudeAi(client: MockClient((r) async {
        sent = r;
        return http.Response.bytes(utf8.encode(jsonEncode({'content': [{'type': 'tool_use', 'name': 'route', 'input': {'reply': 'ঠিক আছে', 'items': []}}]})), 200);
      }));
      expect(await ai.route('হ্যালো', AiContext(now: DateTime(2026, 10, 9))), isNull, reason: 'no key, no session');
      ai.session = 'b' * 64;
      ai.proxy = 'https://getmyassistant.app/wp-json/my-assistant/v1/ai';
      final r = await ai.route('হ্যালো', AiContext(now: DateTime(2026, 10, 9)));
      expect(r!['reply'], 'ঠিক আছে');
      expect(sent.url.toString(), 'https://getmyassistant.app/wp-json/my-assistant/v1/ai');
      expect(sent.headers['authorization'], 'Bearer ${'b' * 64}');
      expect(sent.headers.containsKey('x-api-key'), isFalse);

      final limited = ClaudeAi(client: MockClient((r) async => http.Response('{"code":"limit"}', 429)))
        ..session = 'b' * 64
        ..proxy = 'https://getmyassistant.app/wp-json/my-assistant/v1/ai';
      await expectLater(limited.route('হ্যালো', AiContext(now: DateTime(2026, 10, 9))), throwsA(isA<AiError>().having((e) => e.message, 'message', contains('আজকের AI প্রশ্ন শেষ'))));
    });
  });

  group('notifications from the website', () {
    final now = DateTime(2026, 10, 16, 10); // a Friday
    const daily = ServerNotice(id: 1, title: 'আজকের কাজের লিস্ট করেছেন?', kind: 'daily', time: '21:00', cond: 'no_tasks', mic: true);
    test('daily, only on days without a to-do list; a tap opens the mic', () {
      var out = serverNotices([daily], AppData(), now);
      expect(out.length, 3);
      expect(out.first.at, DateTime(2026, 10, 16, 21));
      expect(out.first.reminderId, startsWith('nudge:plan:'));
      final withTask = AppData(tasks: [Task(title: 'ব্যাংকে যাওয়া', due: DateTime(2026, 10, 16))]);
      out = serverNotices([daily], withTask, now);
      expect(out.map((n) => n.at.day), [17, 18]);
    });
    test('weekly, once, date range, unknown condition', () {
      const weekly = ServerNotice(id: 2, title: 'শুক্রবারের পরিকল্পনা', kind: 'weekly', weekday: 6, time: '20:30');
      expect(serverNotices([weekly], AppData(), now).single.at, DateTime(2026, 10, 17, 20, 30));
      final once = ServerNotice(id: 3, title: 'নতুন সুবিধা', kind: 'once', time: '09:00', date: DateTime(2026, 10, 16));
      expect(serverNotices([once], AppData(), now), isEmpty, reason: '9am already passed');
      final ended = ServerNotice(id: 4, title: 'x', until: DateTime(2026, 10, 16));
      expect(serverNotices([ended], AppData(), now).length, 1);
      const future = ServerNotice(id: 5, title: 'x', cond: 'something_new');
      expect(serverNotices([future], AppData(), now), isEmpty);
    });
    test('come down from the server, kept for offline, follow the switch', () async {
      final client = MockClient((r) async {
        if (r.url.path.endsWith('/notices')) {
          return http.Response.bytes(utf8.encode(jsonEncode({'notices': [daily.toJson()]})), 200);
        }
        return http.Response('{}', 404);
      });
      final rig = Rig(server: AccountServer(client, 'https://getmyassistant.app'));
      final b = rig.brain;
      await b.load();
      await settleAsync();
      expect(b.serverNoticeList.single.title, 'আজকের কাজের লিস্ট করেছেন?');
      expect(await rig.services.lock.keys.read('srv_notices'), contains('কাজের লিস্ট'));
      expect(b.assistantPrefs.server, isNotEmpty);
      await b.setPref('n_news', false);
      expect(b.assistantPrefs.news, isFalse);
    });
  });
}

Future<void> settleAsync() => Future<void>.delayed(const Duration(milliseconds: 50));
