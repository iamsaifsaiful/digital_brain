import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'crypto.dart';

/// Where the encrypted data file lives.
abstract class BlobStore {
  Future<Uint8List?> read();
  Future<void> write(Uint8List bytes);
}

class FileBlobStore implements BlobStore {
  File? _file;

  Future<File> _f() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return _file = File('${dir.path}/brain.enc');
  }

  @override
  Future<Uint8List?> read() async {
    final f = await _f();
    if (!await f.exists()) return null;
    return f.readAsBytes();
  }

  /// Writes a temp file first, then renames, so a crash never leaves half a file.
  @override
  Future<void> write(Uint8List bytes) async {
    final f = await _f();
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }
}

class MemoryBlobStore implements BlobStore {
  Uint8List? bytes;

  @override
  Future<Uint8List?> read() async => bytes;

  @override
  Future<void> write(Uint8List b) async => bytes = b;
}

/// Loads and saves everything, encrypted with a random 256-bit key that
/// only the phone's Keystore/Keychain holds.
class DataStore {
  DataStore({required this.keys, required this.blob});

  final KeyVault keys;
  final BlobStore blob;

  static const _keyName = 'data_key_v1';
  static final _magic = utf8.encode('DBRN1');

  Future<Uint8List> _key() async {
    final k = await keys.read(_keyName);
    if (k != null) return base64Decode(k);
    final fresh = randomBytes(32);
    await keys.write(_keyName, base64Encode(fresh));
    return fresh;
  }

  Future<AppData> load() async {
    final bytes = await blob.read();
    if (bytes == null || bytes.length <= _magic.length) return AppData();
    final key = await _key();
    final clear = await open(bytes.sublist(_magic.length), key);
    return AppData.fromJson((jsonDecode(utf8.decode(clear)) as Map).cast<String, Object?>());
  }

  Future<void> save(AppData data) async {
    final key = await _key();
    final sealed = await seal(utf8.encode(jsonEncode(data.toJson())), key);
    await blob.write(Uint8List.fromList([..._magic, ...sealed]));
  }
}

/// Backup files: "DBRNBK1" + salt(16) + iterations(4, big endian) + sealed JSON.
/// The key comes from the backup password, so the file can be restored on a
/// new phone and is useless without that password.
class Backup {
  static final _magic = utf8.encode('DBRNBK1');
  static const defaultIterations = 120000;

  static Future<Uint8List> export(AppData data, String password, {int iterations = defaultIterations}) async {
    final salt = randomBytes(16);
    final key = await deriveKey(password, salt, iterations);
    final sealed = await seal(utf8.encode(jsonEncode(data.toJson())), key);
    final it = ByteData(4)..setUint32(0, iterations);
    return Uint8List.fromList([..._magic, ...salt, ...it.buffer.asUint8List(), ...sealed]);
  }

  /// Throws [NotABackup] or [WrongKey] (wrong password).
  static Future<AppData> restore(Uint8List bytes, String password) async {
    final head = _magic.length;
    if (bytes.length < head + 20 || !sameBytes(bytes.sublist(0, head), _magic)) throw const NotABackup();
    final salt = bytes.sublist(head, head + 16);
    final iterations = ByteData.sublistView(bytes, head + 16, head + 20).getUint32(0);
    if (iterations < 1000 || iterations > 5000000) throw const NotABackup();
    final key = await deriveKey(password, salt, iterations);
    final clear = await open(bytes.sublist(head + 20), key);
    return AppData.fromJson((jsonDecode(utf8.decode(clear)) as Map).cast<String, Object?>());
  }
}

class NotABackup implements Exception {
  const NotABackup();
}
