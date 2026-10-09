import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small secrets kept by the phone's own protected store (Android Keystore,
/// iOS Keychain): the data key, the PIN hash and lock settings.
abstract class KeyVault {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureKeyVault implements KeyVault {
  final FlutterSecureStorage _s = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  @override
  Future<String?> read(String key) => _s.read(key: key);

  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

/// For tests.
class MemoryKeyVault implements KeyVault {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

Uint8List randomBytes(int n) {
  final r = Random.secure();
  return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
}

final _aes = AesGcm.with256bits();

/// AES-256-GCM. Output is nonce + ciphertext + tag.
Future<Uint8List> seal(List<int> clear, List<int> key) async {
  final box = await _aes.encrypt(clear, secretKey: SecretKey(key));
  return Uint8List.fromList(box.concatenation());
}

/// Opens what [seal] made. Throws [WrongKey] if the key is wrong or the data
/// was changed.
Future<Uint8List> open(List<int> sealed, List<int> key) async {
  try {
    final box = SecretBox.fromConcatenation(sealed,
        nonceLength: _aes.nonceLength, macLength: _aes.macAlgorithm.macLength);
    return Uint8List.fromList(await _aes.decrypt(box, secretKey: SecretKey(key)));
  } on SecretBoxAuthenticationError {
    throw const WrongKey();
  } on ArgumentError {
    throw const WrongKey();
  } on RangeError {
    throw const WrongKey();
  }
}

class WrongKey implements Exception {
  const WrongKey();
}

/// PBKDF2-HMAC-SHA256 → 32 bytes.
Future<Uint8List> deriveKey(String secret, List<int> salt, int iterations) async {
  final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256);
  final k = await kdf.deriveKey(secretKey: SecretKey(utf8.encode(secret)), nonce: salt);
  return Uint8List.fromList(await k.extractBytes());
}

/// Same length, compared without leaking timing.
bool sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    d |= a[i] ^ b[i];
  }
  return d == 0;
}
