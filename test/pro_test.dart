import 'package:digital_brain/logic/ask.dart';
import 'package:digital_brain/logic/pro.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/crypto.dart';
import 'package:digital_brain/services/google_account.dart';
import 'package:digital_brain/services/lock.dart';
import 'package:digital_brain/screens/pro_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, enterPin, settle, start, tell;

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

      await b.startTrial();
      expect(b.pro, isTrue);
      expect(b.onTrial, isTrue);
      expect(b.proUntil, DateTime(2026, 10, 9, 15, 53).add(const Duration(days: trialDays)));
      expect(b.showAds, isFalse);

      // The trial is once.
      await b.setProForTest(false);
      await b.startTrial();
      expect(b.pro, isFalse);
      expect(b.trialUsed, isTrue);

      await b.activatePro(proPlans.first);
      expect(b.pro, isTrue);
      expect(b.proKind, 'pro_yearly');
    });

    test('zakat answer and smart notices are Pro; back to normal outside the Play app', () async {
      final rig = Rig();
      final b = rig.brain;
      final now = DateTime(2026, 10, 9);
      b.gated = true;
      expect(infoAnswer(b.data, 'আমার যাকাত কত?', now), contains('প্রো'));
      expect(b.assistantPrefs.smart, isFalse);
      await b.startTrial();
      expect(infoAnswer(b.data, 'আমার যাকাত কত?', now), isNot(contains('প্রো')));
      expect(b.assistantPrefs.smart, isTrue);
      b.gated = false;
      expect(askZakatLocked, isFalse);
    });

    test('Pro survives a restart', () async {
      final rig = Rig();
      rig.brain.gated = true;
      await rig.brain.load();
      await rig.brain.startTrial();
      final again = Rig.sharing(rig, keys: rig.services.lock.keys as MemoryKeyVault);
      again.brain.gated = true;
      await again.brain.load();
      expect(again.brain.pro, isTrue);
      expect(again.brain.trialUsed, isTrue);
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
    test('signs in, backs up, keeps only the newest; a failed upload keeps the old one', () async {
      final rig = Rig();
      final b = rig.brain;
      await b.load();
      final drive = rig.services.drive as FakeDrive;
      expect(await b.backupToDrive(), isNotNull); // not signed in
      expect(await b.signInGoogle(), isNull);
      expect(b.googleEmail, 'test@gmail.com');

      b.data = AppData(notes: [Note(title: 'গাড়ির কাগজ', body: 'আলমারিতে')]);
      expect(await b.startDriveBackup('backup-pass-1'), isNull);
      expect(drive.files.length, 1);
      expect(b.driveOn, isTrue);
      expect(await rig.services.lock.hasRecovery(), isTrue);
      final first = drive.files.keys.single;

      expect(await b.backupToDrive(), isNull);
      expect(drive.files.length, 1);
      expect(drive.files.keys.single, isNot(first));

      final kept = drive.files.keys.single;
      drive.failUpload = true;
      expect(await b.backupToDrive(), contains('আপলোড'));
      expect(drive.files.keys.single, kept);

      // A new phone with the same account: the backup comes back with its password.
      final list = await b.driveBackups();
      final (restored, _) = await b.openDriveBackup(list.single, 'backup-pass-1');
      expect(restored.notes.single.title, 'গাড়ির কাগজ');
      expect(() => b.openDriveBackup(list.single, 'wrong-pass'), throwsA(anything));
    });

    test('backs up on leaving the app only when something changed', () async {
      final rig = Rig();
      final b = rig.brain;
      await b.load();
      final drive = rig.services.drive as FakeDrive;
      await b.signInGoogle();
      await b.startDriveBackup('backup-pass-1');
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

    test('sign-out stops automatic backup and forgets its password', () async {
      final rig = Rig();
      final b = rig.brain;
      await b.load();
      await b.signInGoogle();
      await b.startDriveBackup('backup-pass-1');
      await b.signOutGoogle();
      expect(b.signedIn, isFalse);
      expect(b.driveOn, isFalse);
      expect(await rig.services.lock.keys.read('drive_pw'), isNull);
    });
  });

  testWidgets('Play app: a second project by voice goes to the general account and offers Pro; vault limit', (t) async {
    final rig = await start(t);
    rig.brain.gated = true;
    rig.brain.data = AppData(
      projects: [Project(name: 'বাড়ি')],
      vault: [for (var i = 0; i < freeVaultItems; i++) VaultItem(name: 'site$i', password: 'x')],
    );
    await settle(t);
    await openChat(t);
    await tell(t, rig, 'রহিম ভবন প্রজেক্টে ৫০ হাজার টাকা এলো');
    if (find.widgetWithText(ActionChip, 'হ্যাঁ').evaluate().isNotEmpty) await tell(t, rig, 'হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.projects.length, 1);
    expect(rig.brain.data.cash.single.projectId, isNull);
    expect(find.textContaining('প্রো সুবিধা'), findsWidgets);

    await tell(t, rig, 'ফেসবুকের পাসওয়ার্ড ১২২৩৯৯৩৯');
    if (find.widgetWithText(ActionChip, 'হ্যাঁ').evaluate().isNotEmpty) await tell(t, rig, 'হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.vault.length, freeVaultItems);
    expect(find.textContaining('পূর্ণ হয়ে গেছে'), findsWidgets);

    await tell(t, rig, 'প্রো খোলো');
    await settle(t);
    expect(find.byType(ProScreen), findsOneWidget);
    final list = find.descendant(of: find.byType(ProScreen), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text('৭ দিন ফ্রি চালু করুন'), 300, scrollable: list);
    await t.tap(find.text('৭ দিন ফ্রি চালু করুন'));
    await settle(t);
    expect(rig.brain.onTrial, isTrue);
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
}
