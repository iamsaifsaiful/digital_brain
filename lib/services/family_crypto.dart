// Sealing for the family (lib/screens/family_screen.dart): what one member
// sends another (a to-do, a reminder, a medicine reminder, a note, the key to
// their location) and the heirs' copy are locked on this phone with the
// other phone's public key, so our server only ever passes on bytes it
// cannot open.
//
//   sealed  = 0x01 | ephemeral X25519 public key (32) | AES-256-GCM(nonce 12 + text + tag 16)
//   key     = HKDF-SHA256(X25519(ephemeral, recipient), salt: epk | rpk, info: "ma-family-v1")
//
// A location report is locked with a shared 32-byte key instead (AES-256-GCM,
// nonce + text + tag) — the same bytes the Android side makes when the phone
// answers "এখন কোথায়?" by itself (LocationShare.kt).
import 'dart:convert';
import 'dart:io' show gzip;
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto.dart' show randomBytes, seal, open, WrongKey;

final _x = X25519();
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
final _aes = AesGcm.with256bits();
const _info = 'ma-family-v1';

/// This phone's key pair for the family, from its 32-byte secret seed.
class FamilyKeys {
  FamilyKeys._(this.seed, this._pair, this.publicKey);
  final Uint8List seed;
  final SimpleKeyPair _pair;
  final Uint8List publicKey;

  String get publicB64 => base64Encode(publicKey);

  static Future<FamilyKeys> fromSeed(List<int> seed) async {
    final pair = await _x.newKeyPairFromSeed(seed);
    final pub = await pair.extractPublicKey();
    return FamilyKeys._(Uint8List.fromList(seed), pair, Uint8List.fromList(pub.bytes));
  }

  static Future<FamilyKeys> generate() => fromSeed(randomBytes(32));
}

Future<SecretKey> _derive(SimpleKeyPair mine, List<int> theirPub, List<int> epk, List<int> rpk) async {
  final shared = await _x.sharedSecretKey(keyPair: mine, remotePublicKey: SimplePublicKey(theirPub, type: KeyPairType.x25519));
  return _hkdf.deriveKey(secretKey: shared, nonce: [...epk, ...rpk], info: utf8.encode(_info));
}

/// Locks [clear] for the holder of [recipientPublicB64].
Future<String> sealFor(List<int> clear, String recipientPublicB64) async {
  final rpk = base64Decode(recipientPublicB64);
  if (rpk.length != 32) throw ArgumentError('not an X25519 key');
  final eph = await _x.newKeyPair();
  final epk = (await eph.extractPublicKey()).bytes;
  final key = await _derive(eph, rpk, epk, rpk);
  final box = await _aes.encrypt(clear, secretKey: key);
  return base64Encode([1, ...epk, ...box.concatenation()]);
}

/// Opens what [sealFor] made for [mine]. Throws [WrongKey] when it was not for this phone.
Future<Uint8List> openSealed(String sealedB64, FamilyKeys mine) async {
  try {
    final b = base64Decode(sealedB64);
    if (b.length < 1 + 32 + 12 + 16 || b[0] != 1) throw const WrongKey();
    final epk = b.sublist(1, 33);
    final key = await _derive(mine._pair, epk, epk, mine.publicKey);
    final box = SecretBox.fromConcatenation(b.sublist(33), nonceLength: 12, macLength: 16);
    return Uint8List.fromList(await _aes.decrypt(box, secretKey: key));
  } on SecretBoxAuthenticationError {
    throw const WrongKey();
  } on FormatException {
    throw const WrongKey();
  }
}

Future<String> sealJsonFor(Map<String, Object?> j, String recipientPublicB64) => sealFor(utf8.encode(jsonEncode(j)), recipientPublicB64);

Future<Map<String, dynamic>> openJson(String sealedB64, FamilyKeys mine) async => (jsonDecode(utf8.decode(await openSealed(sealedB64, mine))) as Map).cast<String, dynamic>();

/// A location report with the shared location key (nonce + text + tag, base64).
Future<String> sealPlace(Map<String, Object?> place, List<int> key) async => base64Encode(await seal(utf8.encode(jsonEncode(place)), key));

Future<Map<String, dynamic>> openPlace(String sealedB64, List<int> key) async => (jsonDecode(utf8.decode(await open(base64Decode(sealedB64), key))) as Map).cast<String, dynamic>();

/// The heirs' copy: the chosen parts, gzipped and locked with a fresh content
/// key; that key locked for each heir. Returns (blob base64, family link id → wrapped key).
Future<(String, Map<String, String>)> sealPackage(Map<String, Object?> parts, Map<int, String> heirKeys) async {
  final content = randomBytes(32);
  final blob = await seal(gzip.encode(utf8.encode(jsonEncode(parts))), content);
  return (base64Encode(blob), {for (final e in heirKeys.entries) '${e.key}': await sealFor(content, e.value)});
}

Future<Map<String, dynamic>> openSealedPackage(String blobB64, String wrappedKey, FamilyKeys mine) async {
  final content = await openSealed(wrappedKey, mine);
  final clear = await open(base64Decode(blobB64), content);
  return (jsonDecode(utf8.decode(gzip.decode(clear))) as Map).cast<String, dynamic>();
}

/// The pair's safety code (owner's review, 27 Oct): the same 20 digits on both
/// phones when each has the other's real key. Different digits mean someone
/// in between (even our server) swapped a key — nothing sealed is then safe.
Future<String> safetyCode(String aB64, String bB64) async {
  final a = base64Decode(aB64), b = base64Decode(bB64);
  final first = _less(a, b) ? a : b, second = identical(first, a) ? b : a;
  final h = (await Sha256().hash([...utf8.encode('ma-safety-v1'), ...first, ...second])).bytes;
  final groups = [for (var i = 0; i < 5; i++) ((h[2 * i] << 8 | h[2 * i + 1]) % 10000).toString().padLeft(4, '0')];
  return groups.join(' ');
}

bool _less(List<int> a, List<int> b) {
  for (var i = 0; i < a.length && i < b.length; i++) {
    if (a[i] != b[i]) return a[i] < b[i];
  }
  return a.length < b.length;
}
