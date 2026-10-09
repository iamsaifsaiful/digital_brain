import 'dart:convert';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/crypto.dart';
import 'package:digital_brain/services/data_store.dart';
import 'package:digital_brain/services/lock.dart';
import 'package:digital_brain/services/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Encryption', () {
    test('seal and open', () async {
      final key = randomBytes(32);
      final sealed = await seal(utf8.encode('গোপন কথা'), key);
      expect(utf8.decode(await open(sealed, key)), 'গোপন কথা');
      await expectLater(open(sealed, randomBytes(32)), throwsA(isA<WrongKey>()));
    });

    test('data file is encrypted and loads back', () async {
      final keys = MemoryKeyVault();
      final blob = MemoryBlobStore();
      final store = DataStore(keys: keys, blob: blob);
      expect((await store.load()).vault, isEmpty);

      await store.save(AppData(vault: [VaultItem(name: 'ABC', password: 'super-secret-123')]));
      final raw = latin1.decode(blob.bytes!);
      expect(raw.contains('super-secret-123'), isFalse);
      expect(raw.contains('ABC'), isFalse);

      final again = await DataStore(keys: keys, blob: blob).load();
      expect(again.vault.single.password, 'super-secret-123');

      // Another phone (another key) cannot read it.
      await expectLater(DataStore(keys: MemoryKeyVault(), blob: blob).load(), throwsA(isA<WrongKey>()));
    });

    test('backup restores with the right password only', () async {
      final data = AppData(notes: [Note(title: 'নোট', body: 'লেখা')]);
      final bytes = await Backup.export(data, 'my backup pass', iterations: 2000);
      final back = await Backup.restore(bytes, 'my backup pass');
      expect(back.notes.single.body, 'লেখা');
      await expectLater(Backup.restore(bytes, 'wrong'), throwsA(isA<WrongKey>()));
      await expectLater(Backup.restore(utf8.encode('hello world, not a backup file'), 'x'), throwsA(isA<NotABackup>()));
    });
  });

  group('PIN', () {
    test('right, wrong, then a wait after too many tries', () async {
      var now = DateTime(2026, 10, 9, 12);
      final lock = LockService(keys: MemoryKeyVault(), biometrics: FakeBiometrics(), iterations: 1000, clock: () => now);
      expect(await lock.hasPin(), isFalse);
      await lock.setPin('1234');
      expect(await lock.hasPin(), isTrue);
      expect(await lock.checkPin('1234'), isA<PinOk>());

      for (var i = 1; i < LockService.freeTries; i++) {
        final r = await lock.checkPin('0000');
        expect(r, isA<PinWrong>());
        expect((r as PinWrong).triesLeft, LockService.freeTries - i);
      }
      expect(await lock.checkPin('0000'), isA<PinLocked>());
      // Even the right PIN waits.
      expect(await lock.checkPin('1234'), isA<PinLocked>());
      now = now.add(const Duration(minutes: 1));
      expect(await lock.checkPin('1234'), isA<PinOk>());
    });

    test('settings', () async {
      final lock = LockService(keys: MemoryKeyVault(), biometrics: FakeBiometrics(), iterations: 1000);
      expect(await lock.autoLockSeconds(), 30);
      await lock.setAutoLockSeconds(300);
      expect(await lock.autoLockSeconds(), 300);
      await lock.setBiometricsOn(false);
      expect(await lock.tryBiometrics('x'), isFalse);
    });
  });

  group('Notifications', () {
    test('one per upcoming reminder, none for the past', () {
      final now = DateTime(2026, 10, 9, 15);
      final list = plannedNotices([
        Reminder(title: 'ডোমেইন রিনিউ', date: DateTime(2026, 10, 14), daysBefore: 1, hour: 10),
        Reminder(title: 'পুরনো', date: DateTime(2026, 9, 1)),
      ], now);
      expect(list, hasLength(1));
      expect(list.single.at, DateTime(2026, 10, 13, 10));
      expect(list.single.title, 'ডোমেইন রিনিউ');
    });
  });
}
