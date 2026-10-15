import 'dart:convert';
import 'dart:typed_data';

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
      await expectLater(DataStore(keys: MemoryKeyVault(), blob: blob).load(), throwsA(isA<DataKeyMissing>()));
      // …and never writes a new key over it.
      final other = DataStore(keys: MemoryKeyVault(), blob: blob);
      await expectLater(other.save(AppData()), throwsA(isA<DataKeyMissing>()));
      expect((await DataStore(keys: keys, blob: blob).load()).vault.single.password, 'super-secret-123');
    });

    test('backup restores with the right password only', () async {
      final data = AppData(notes: [Note(title: 'নোট', body: 'লেখা')]);
      final bytes = await Backup.export(data, 'my backup pass', iterations: 2000);
      final (back, _) = await Backup.restore(bytes, 'my backup pass');
      expect(back.notes.single.body, 'লেখা');
      await expectLater(Backup.restore(bytes, 'wrong'), throwsA(isA<WrongKey>()));
      await expectLater(Backup.restore(utf8.encode('hello world, not a backup file'), 'x'), throwsA(isA<NotABackup>()));
    });

    test('a backup carries the attached files; old (v1) backups still restore; newer or damaged ones are refused', () async {
      final data = AppData(docs: [Doc(title: 'NID', files: [DocFile(id: 'f1', name: 'nid.jpg', mime: 'image/jpeg', size: 3)])]);
      final bytes = await Backup.export(data, 'pass1234', files: {'f1': Uint8List.fromList([1, 2, 3])}, iterations: 2000);
      final (back, files) = await Backup.restore(bytes, 'pass1234');
      expect(back.docs.single.files.single.id, 'f1');
      expect(files['f1'], [1, 2, 3]);
      // A version-1 file (made by older app versions).
      final salt = randomBytes(16);
      final key = await deriveKey('old pass', salt, 2000);
      final sealed = await seal(utf8.encode(jsonEncode(AppData(notes: [Note(title: 'পুরনো')]).toJson())), key);
      final v1 = Uint8List.fromList([...utf8.encode('DBRNBK1'), ...salt, 0, 0, 7, 208, ...sealed]);
      final (old, oldFiles) = await Backup.restore(v1, 'old pass');
      expect(old.notes.single.title, 'পুরনো');
      expect(oldFiles, isEmpty);
      // Made by a newer app.
      final newer = Uint8List.fromList(bytes)..[6] = utf8.encode('9').first;
      await expectLater(Backup.restore(newer, 'pass1234'), throwsA(isA<UnsupportedBackup>()));
      // Cut short / damaged.
      await expectLater(Backup.restore(Uint8List.fromList(bytes.sublist(0, bytes.length - 40)), 'pass1234'), throwsA(anyOf(isA<WrongKey>(), isA<NotABackup>())));
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
    test('each upcoming reminder rings on its day (plus the early notice), none for the past', () {
      final now = DateTime(2026, 10, 9, 15);
      final list = plannedNotices([
        Reminder(title: 'ডোমেইন রিনিউ', date: DateTime(2026, 10, 14), daysBefore: 1, hour: 10),
        Reminder(title: 'পুরনো', date: DateTime(2026, 9, 1)),
      ], now);
      expect(list, hasLength(2));
      final main = list.firstWhere((n) => !n.early);
      expect(main.at, DateTime(2026, 10, 14, 10));
      expect(main.title, 'ডোমেইন রিনিউ');
      expect(list.firstWhere((n) => n.early).at, DateTime(2026, 10, 13, 10));
    });
  });
}
