import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../core/models.dart';
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
    return _file = File('${dir.path}/hisab.enc');
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

/// Customers' photos, each encrypted.
abstract class PhotoFiles {
  Future<Uint8List?> read(String id);
  Future<void> write(String id, Uint8List sealed);
  Future<List<String>> ids();
}

class FilePhotoFiles implements PhotoFiles {
  Future<Directory> _dir() async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<Uint8List?> read(String id) async {
    final f = File('${(await _dir()).path}/$id.bin');
    return await f.exists() ? await f.readAsBytes() : null;
  }

  @override
  Future<void> write(String id, Uint8List sealed) async => File('${(await _dir()).path}/$id.bin').writeAsBytes(sealed, flush: true);

  @override
  Future<List<String>> ids() async => [
        for (final f in (await _dir()).listSync())
          if (f.path.endsWith('.bin')) f.uri.pathSegments.last.replaceAll('.bin', ''),
      ];
}

class MemoryPhotoFiles implements PhotoFiles {
  final files = <String, Uint8List>{};
  @override
  Future<Uint8List?> read(String id) async => files[id];
  @override
  Future<void> write(String id, Uint8List sealed) async => files[id] = sealed;
  @override
  Future<List<String>> ids() async => files.keys.toList();
}

/// Loads and saves everything, encrypted with a random 256-bit key that
/// only the phone's Keystore holds.
class DataStore {
  DataStore({required this.keys, required this.blob, required this.photos});

  final KeyVault keys;
  final BlobStore blob;
  final PhotoFiles photos;

  static const _keyName = 'data_key_v1';
  static final _magic = utf8.encode('RHSB1');

  Future<Uint8List> _key() async {
    final k = await keys.read(_keyName);
    if (k != null) return base64Decode(k);
    // Data is there but its key is gone: never make a new key over it.
    final existing = await blob.read();
    if (existing != null && existing.length > _magic.length) throw const DataKeyMissing();
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

  Future<void> savePhoto(String id, List<int> bytes) async => photos.write(id, await seal(bytes, await _key()));

  Future<Uint8List?> loadPhoto(String id) async {
    final sealed = await photos.read(id);
    if (sealed == null) return null;
    try {
      return await open(sealed, await _key());
    } catch (_) {
      return null;
    }
  }

  /// After restoring a backup on a phone that lost its key: keep the old
  /// file aside and start a new key.
  Future<void> startOver() async {
    final old = await blob.read();
    if (old != null && old.isNotEmpty) await photos.write('unreadable-${DateTime.now().millisecondsSinceEpoch}', old);
    await blob.write(Uint8List(0));
    await keys.write(_keyName, base64Encode(randomBytes(32)));
  }
}

/// Backup file: "RHSBBK1" + salt(16) + iterations(4) + sealed JSON with the
/// data and every photo. Locked by its own password, so it can be restored
/// on a new phone and is useless without that password.
class Backup {
  static final _prefix = utf8.encode('RHSBBK1');
  static const defaultIterations = 120000;

  static Future<Uint8List> export(AppData data, String password, {Map<String, Uint8List> photos = const {}, int iterations = defaultIterations}) async {
    final salt = randomBytes(16);
    final key = await deriveKey(password, salt, iterations);
    final payload = {'data': data.toJson(), 'photos': {for (final e in photos.entries) e.key: base64Encode(e.value)}};
    final sealed = await seal(utf8.encode(jsonEncode(payload)), key);
    final it = ByteData(4)..setUint32(0, iterations);
    return Uint8List.fromList([..._prefix, ...salt, ...it.buffer.asUint8List(), ...sealed]);
  }

  /// Throws [NotABackup] or [WrongKey] (wrong password).
  static Future<(AppData, Map<String, Uint8List>)> restore(Uint8List bytes, String password) async {
    final head = _prefix.length;
    if (bytes.length < head + 40 || !sameBytes(bytes.sublist(0, head), _prefix)) throw const NotABackup();
    final salt = bytes.sublist(head, head + 16);
    final iterations = ByteData.sublistView(bytes, head + 16, head + 20).getUint32(0);
    if (iterations < 1000 || iterations > 5000000) throw const NotABackup();
    final key = await deriveKey(password, salt, iterations);
    final clear = await open(bytes.sublist(head + 20), key);
    try {
      final j = (jsonDecode(utf8.decode(clear)) as Map).cast<String, Object?>();
      final photos = <String, Uint8List>{
        for (final e in ((j['photos'] as Map?) ?? const {}).entries) '${e.key}': base64Decode('${e.value}'),
      };
      return (AppData.fromJson((j['data'] as Map).cast<String, Object?>()), photos);
    } catch (_) {
      throw const NotABackup();
    }
  }
}

class NotABackup implements Exception {
  const NotABackup();
}

class DataKeyMissing implements Exception {
  const DataKeyMissing();
}
