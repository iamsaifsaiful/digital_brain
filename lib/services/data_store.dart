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

/// Where document pages (photos, PDFs) are kept, each already encrypted.
abstract class DocFiles {
  Future<Uint8List?> read(String id);
  Future<void> write(String id, Uint8List sealed);
  Future<void> delete(String id);
}

class FileDocFiles implements DocFiles {
  Future<File> _f(String id) async {
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/docs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/$id.bin');
  }

  @override
  Future<Uint8List?> read(String id) async {
    final f = await _f(id);
    return await f.exists() ? await f.readAsBytes() : null;
  }

  @override
  Future<void> write(String id, Uint8List sealed) async => (await _f(id)).writeAsBytes(sealed, flush: true);

  @override
  Future<void> delete(String id) async {
    final f = await _f(id);
    if (await f.exists()) await f.delete();
  }
}

class MemoryDocFiles implements DocFiles {
  final files = <String, Uint8List>{};
  @override
  Future<Uint8List?> read(String id) async => files[id];
  @override
  Future<void> write(String id, Uint8List sealed) async => files[id] = sealed;
  @override
  Future<void> delete(String id) async => files.remove(id);
}

/// Loads and saves everything, encrypted with a random 256-bit key that
/// only the phone's Keystore/Keychain holds.
class DataStore {
  DataStore({required this.keys, required this.blob, DocFiles? docFiles}) : docFiles = docFiles ?? MemoryDocFiles();

  final KeyVault keys;
  final BlobStore blob;
  final DocFiles docFiles;

  /// A document page, encrypted with the same key as the rest of the data.
  Future<void> saveDocFile(String id, List<int> bytes) async {
    final key = await _key();
    await docFiles.write(id, await seal(bytes, key));
  }

  Future<Uint8List?> loadDocFile(String id) async {
    final sealed = await docFiles.read(id);
    if (sealed == null) return null;
    return open(sealed, await _key());
  }

  Future<void> deleteDocFile(String id) => docFiles.delete(id);

  static const _keyName = 'data_key_v1';
  static final _magic = utf8.encode('DBRN1');

  Future<Uint8List> _key() async {
    final k = await keys.read(_keyName);
    if (k != null) return base64Decode(k);
    // Data is there but its key is gone (reinstall, phone security reset):
    // never make a new key over it — that would make the old data
    // unreadable for good. The app shows the problem and offers a backup.
    final existing = await blob.read();
    if (existing != null && existing.length > _magic.length) throw const DataKeyMissing();
    final fresh = randomBytes(32);
    await keys.write(_keyName, base64Encode(fresh));
    return fresh;
  }

  /// After the user chose to restore a backup over data this phone cannot
  /// open: the unreadable file is kept aside (never deleted) and a new key
  /// is made for the restored data.
  Future<void> startOverKeepingOld() async {
    final old = await blob.read();
    if (old != null && old.isNotEmpty) await docFiles.write('unreadable-data-${DateTime.now().millisecondsSinceEpoch}', old);
    await blob.write(Uint8List(0));
    await keys.write(_keyName, base64Encode(randomBytes(32)));
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

/// Backup files: "DBRNBK" + version digit + salt(16) + iterations(4, big
/// endian) + sealed JSON. The key comes from the backup password, so the file
/// can be restored on a new phone and is useless without that password.
/// Version 2 also carries every attached photo and file (documents, note and
/// contact attachments, the profile photo); version 1 files still restore.
class Backup {
  static final _prefix = utf8.encode('DBRNBK');
  static const version = 2;
  static const defaultIterations = 120000;

  static Future<Uint8List> export(AppData data, String password, {Map<String, Uint8List> files = const {}, int iterations = defaultIterations}) async {
    final salt = randomBytes(16);
    final key = await deriveKey(password, salt, iterations);
    final payload = {'v': version, 'data': data.toJson(), 'files': {for (final e in files.entries) e.key: base64Encode(e.value)}};
    final sealed = await seal(utf8.encode(jsonEncode(payload)), key);
    final it = ByteData(4)..setUint32(0, iterations);
    return Uint8List.fromList([..._prefix, ...utf8.encode('$version'), ...salt, ...it.buffer.asUint8List(), ...sealed]);
  }

  /// The data and attached files in a backup. Throws [NotABackup] (not a
  /// backup, or damaged), [UnsupportedBackup] (made by a newer app) or
  /// [WrongKey] (wrong password). Nothing is changed on the phone here.
  static Future<(AppData, Map<String, Uint8List>)> restore(Uint8List bytes, String password) async {
    final head = _prefix.length + 1;
    if (bytes.length < head + 20 || !sameBytes(bytes.sublist(0, _prefix.length), _prefix)) throw const NotABackup();
    final v = int.tryParse(String.fromCharCode(bytes[_prefix.length]));
    if (v == null) throw const NotABackup();
    if (v > version) throw const UnsupportedBackup();
    final salt = bytes.sublist(head, head + 16);
    final iterations = ByteData.sublistView(bytes, head + 16, head + 20).getUint32(0);
    if (iterations < 1000 || iterations > 5000000) throw const NotABackup();
    final key = await deriveKey(password, salt, iterations);
    final clear = await open(bytes.sublist(head + 20), key);
    try {
      final j = (jsonDecode(utf8.decode(clear)) as Map).cast<String, Object?>();
      if (v == 1) return (AppData.fromJson(j), <String, Uint8List>{});
      final files = <String, Uint8List>{
        for (final e in ((j['files'] as Map?) ?? const {}).entries) '${e.key}': base64Decode('${e.value}'),
      };
      return (AppData.fromJson((j['data'] as Map).cast<String, Object?>()), files);
    } on WrongKey {
      rethrow;
    } catch (_) {
      throw const NotABackup();
    }
  }
}

/// Every attached file id in [d] (documents, note and contact attachments).
Set<String> attachedFileIds(AppData d) => {
      for (final x in d.docs) for (final f in x.files) f.id,
      for (final n in d.notes) for (final f in n.files) f.id,
      for (final c in d.contacts) for (final f in c.files) f.id,
    };

class NotABackup implements Exception {
  const NotABackup();
}

/// A backup made by a newer version of the app.
class UnsupportedBackup implements Exception {
  const UnsupportedBackup();
}

/// The data file is there but this phone no longer has its key.
class DataKeyMissing implements Exception {
  const DataKeyMissing();
  @override
  String toString() => 'DataKeyMissing';
}
