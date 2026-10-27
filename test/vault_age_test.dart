import 'package:flutter_test/flutter_test.dart';
import 'package:digital_brain/logic/proactive.dart';
import 'package:digital_brain/logic/vault_age.dart';
import 'package:digital_brain/models/models.dart';

void main() {
  final t0 = DateTime(2026, 1, 10, 9);

  test('a new login gets the day it was put in and the day its password was set', () {
    final v = vaultToSave(null, VaultItem(id: 'a', name: 'bKash', password: 'one'), t0);
    expect(v.createdAt, t0);
    expect(v.passwordAt, t0);
    expect(v.old, isEmpty);
  });

  test('changing the password keeps the old one, newest first, and keeps the first date', () {
    final a = vaultToSave(null, VaultItem(id: 'a', name: 'bKash', password: 'one'), t0);
    final t1 = t0.add(const Duration(days: 40));
    final b = vaultToSave(a, VaultItem(id: 'a', name: 'bKash', password: 'two'), t1);
    expect(b.createdAt, t0);
    expect(b.passwordAt, t1);
    expect(b.old.single.password, 'one');
    expect(b.old.single.from, t0);
    expect(b.old.single.until, t1);
    final t2 = t1.add(const Duration(days: 5));
    final c = vaultToSave(b, VaultItem(id: 'a', name: 'bKash', password: 'three'), t2);
    expect(c.old.map((o) => o.password), ['two', 'one']);
    expect(usedBefore(c, 'one'), isTrue);
    expect(usedBefore(c, 'three'), isFalse);
  });

  test('editing only the note keeps the password date and history', () {
    final a = vaultToSave(null, VaultItem(id: 'a', name: 'x', password: 'one'), t0);
    final b = vaultToSave(a, VaultItem(id: 'a', name: 'x', password: 'one', note: 'নতুন নোট'), t0.add(const Duration(days: 9)));
    expect(b.passwordAt, t0);
    expect(b.old, isEmpty);
  });

  test('going back to an old password does not list it twice', () {
    var v = vaultToSave(null, VaultItem(id: 'a', name: 'x', password: 'one'), t0);
    v = vaultToSave(v, VaultItem(id: 'a', name: 'x', password: 'two'), t0.add(const Duration(days: 1)));
    v = vaultToSave(v, VaultItem(id: 'a', name: 'x', password: 'one'), t0.add(const Duration(days: 2)));
    expect(v.old.map((o) => o.password), ['two']);
  });

  test('history survives saving and reading back; an older login has no dates', () {
    var v = vaultToSave(null, VaultItem(id: 'a', name: 'x', password: 'one'), t0);
    v = vaultToSave(v, VaultItem(id: 'a', name: 'x', password: 'two'), t0.add(const Duration(days: 3)));
    final back = VaultItem.fromJson(v.toJson());
    expect(back.createdAt, v.createdAt);
    expect(back.passwordAt, v.passwordAt);
    expect(back.old.single.password, 'one');
    final legacy = VaultItem.fromJson({'id': 'b', 'name': 'y', 'password': 'p', 'updatedAt': t0.toIso8601String()});
    expect(legacy.createdAt, isNull);
    expect(legacy.passwordSince, t0);
  });

  test('at most ten old passwords are kept', () {
    var v = vaultToSave(null, VaultItem(id: 'a', name: 'x', password: 'p0'), t0);
    for (var i = 1; i <= 14; i++) {
      v = vaultToSave(v, VaultItem(id: 'a', name: 'x', password: 'p$i'), t0.add(Duration(days: i)));
    }
    expect(v.old.length, oldPasswordsKept);
    expect(v.old.first.password, 'p13');
  });

  group('the six-month nudge', () {
    AppData data(List<VaultItem> v) => AppData(vault: v);

    test('goes on the first Friday (or holiday) after six months, with the count only', () {
      // Set Wednesday 4 Nov 2026; six months later is Wed 5 May 2027.
      final set = DateTime(2026, 11, 4, 10);
      final d = data([
        VaultItem(id: 'a', name: 'bKash', password: 'x', passwordAt: set),
        VaultItem(id: 'b', name: 'Gmail', password: 'y', passwordAt: set),
      ]);
      final n = passwordNudges(d, DateTime(2027, 5, 1));
      expect(n, isNotEmpty);
      final at = n.first.at;
      expect(!at.isBefore(set.add(passwordMaxAge)), isTrue);
      expect(nextFridayOrHoliday(set.add(passwordMaxAge)), DateTime(at.year, at.month, at.day));
      expect(n.first.title, contains('২'));
      expect(n.first.title.contains('bKash') || n.first.body.contains('bKash'), isFalse);
      expect(n.first.reminderId, nudgePass);
    });

    test('a fresh password gets nothing within six months', () {
      final now = DateTime(2027, 1, 1);
      final d = data([VaultItem(id: 'a', name: 'x', password: 'x', passwordAt: now.subtract(const Duration(days: 30)))]);
      expect(passwordNudges(d, now).every((n) => n.at.isAfter(now.add(const Duration(days: 140)))), isTrue);
    });

    test('a password already old when this came is told once, on the first Friday or holiday from 27 Oct 2026', () {
      final d = data([VaultItem(id: 'a', name: 'x', password: 'x', updatedAt: DateTime(2025, 1, 1))]);
      final n = passwordNudges(d, DateTime(2026, 10, 27, 8));
      expect(n.first.at.isAfter(DateTime(2026, 10, 27)), isTrue);
      final day = DateTime(n.first.at.year, n.first.at.month, n.first.at.day);
      expect(day, nextFridayOrHoliday(DateTime(2026, 10, 27)));
    });

    test('nextFridayOrHoliday lands on a Friday when there is no holiday before it', () {
      // Mon 9 Nov 2026 → Fri 13 Nov 2026 (no government holiday in between).
      expect(nextFridayOrHoliday(DateTime(2026, 11, 9)), DateTime(2026, 11, 13));
    });

    test('logins without a password are left out', () {
      final d = data([VaultItem(id: 'a', name: 'x', updatedAt: DateTime(2020))]);
      expect(passwordNudges(d, DateTime(2027)), isEmpty);
      expect(stalePasswords(d, DateTime(2027)), isEmpty);
    });
  });
}
