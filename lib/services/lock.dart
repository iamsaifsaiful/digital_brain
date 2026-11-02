import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'crypto.dart';

/// Fingerprint / face unlock.
abstract class Biometrics {
  Future<bool> available();
  Future<bool> authenticate(String reason);
}

class DeviceBiometrics implements Biometrics {
  final _auth = LocalAuthentication();

  @override
  Future<bool> available() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final list = await _auth.getAvailableBiometrics();
      return list.isNotEmpty;
    } catch (e) {
      debugPrint('Biometrics unavailable: $e');
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true, persistAcrossBackgrounding: true);
    } catch (e) {
      debugPrint('Biometric check failed: $e');
      return false;
    }
  }
}

/// For tests.
class FakeBiometrics implements Biometrics {
  FakeBiometrics({this.has = true, this.ok = true});
  bool has;
  bool ok;
  int asked = 0;

  @override
  Future<bool> available() async => has;

  @override
  Future<bool> authenticate(String reason) async {
    asked++;
    return ok;
  }
}

sealed class PinResult {
  const PinResult();
}

class PinOk extends PinResult {
  const PinOk();
}

class PinWrong extends PinResult {
  const PinWrong(this.triesLeft);

  /// Tries before a wait is imposed.
  final int triesLeft;
}

class PinLocked extends PinResult {
  const PinLocked(this.until);
  final DateTime until;
}

/// The app PIN (stored only as a salted PBKDF2 hash), biometric choice and
/// auto-lock time, all in the Keystore/Keychain.
class LockService {
  LockService({required this.keys, required this.biometrics, this.iterations = 30000, DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final KeyVault keys;
  final Biometrics biometrics;
  final int iterations;
  final DateTime Function() _now;

  static const freeTries = 5;

  Future<bool> hasPin() async => (await keys.read('pin_hash')) != null;

  Future<void> setPin(String pin) async {
    final salt = randomBytes(16);
    final hash = await deriveKey(pin, salt, iterations);
    await keys.write('pin_salt', base64Encode(salt));
    await keys.write('pin_iter', '$iterations');
    await keys.write('pin_hash', base64Encode(hash));
    await keys.delete('pin_failed');
    await keys.delete('pin_wait_until');
  }

  Future<PinResult> checkPin(String pin) async {
    final waitUntil = DateTime.tryParse(await keys.read('pin_wait_until') ?? '');
    if (waitUntil != null && waitUntil.isAfter(_now())) return PinLocked(waitUntil);

    final salt = base64Decode(await keys.read('pin_salt') ?? '');
    final iter = int.tryParse(await keys.read('pin_iter') ?? '') ?? iterations;
    final want = base64Decode(await keys.read('pin_hash') ?? '');
    final got = await deriveKey(pin, salt, iter);
    if (want.isNotEmpty && sameBytes(want, got)) {
      await keys.delete('pin_failed');
      await keys.delete('pin_wait_until');
      return const PinOk();
    }
    final failed = (int.tryParse(await keys.read('pin_failed') ?? '') ?? 0) + 1;
    await keys.write('pin_failed', '$failed');
    if (failed >= freeTries) {
      // 30 s, then 1, 2, 4… minutes, up to 30 minutes.
      final secs = min(30 * pow(2, failed - freeTries).toInt(), 1800);
      final until = _now().add(Duration(seconds: secs));
      await keys.write('pin_wait_until', until.toIso8601String());
      return PinLocked(until);
    }
    return PinWrong(freeTries - failed);
  }

  Future<bool> biometricsOn() async => (await keys.read('bio_on')) != 'false';

  Future<void> setBiometricsOn(bool on) => keys.write('bio_on', on ? 'true' : 'false');

  /// Seconds in the background before the app locks itself.
  Future<int> autoLockSeconds() async => int.tryParse(await keys.read('auto_lock') ?? '') ?? 30;

  Future<void> setAutoLockSeconds(int s) => keys.write('auto_lock', '$s');

  /// Tries the fingerprint when it is on and the phone has one.
  Future<bool> tryBiometrics(String reason) async {
    if (!await biometricsOn()) return false;
    if (!await biometrics.available()) return false;
    return biometrics.authenticate(reason);
  }
}
