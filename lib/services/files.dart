import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' as sp;

/// Sharing a file out of the app, picking one in, and the clipboard.
abstract class FileBridge {
  /// Opens the share sheet with [bytes] saved as [fileName].
  Future<void> shareFile(Uint8List bytes, String fileName, String mime, String text);

  /// Asks where to keep the file (Download or any folder) and writes it
  /// there. True when saved, false when the user cancelled.
  Future<bool> saveFile(Uint8List bytes, String fileName);

  /// Lets the user pick a file; null when they cancel.
  Future<Uint8List?> pickFile();

  /// Copies [text]; secrets are wiped from the clipboard after [clearAfter].
  Future<void> copy(String text, {Duration? clearAfter});
}

class DeviceFiles implements FileBridge {
  Timer? _clear;
  static const _channel = MethodChannel('my_assistant/files');

  @override
  Future<bool> saveFile(Uint8List bytes, String fileName) async {
    final ok = await _channel.invokeMethod<bool>('saveFile', {'bytes': bytes, 'name': fileName});
    return ok ?? false;
  }

  @override
  Future<void> shareFile(Uint8List bytes, String fileName, String mime, String text) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$fileName');
    await f.writeAsBytes(bytes, flush: true);
    await sp.SharePlus.instance.share(sp.ShareParams(files: [sp.XFile(f.path, mimeType: mime)], text: text));
  }

  @override
  Future<Uint8List?> pickFile() async {
    try {
      final f = await fs.openFile();
      if (f == null) return null;
      return await f.readAsBytes();
    } catch (e) {
      debugPrint('pick failed: $e');
      return null;
    }
  }

  @override
  Future<void> copy(String text, {Duration? clearAfter}) async {
    await Clipboard.setData(ClipboardData(text: text));
    _clear?.cancel();
    if (clearAfter != null) {
      _clear = Timer(clearAfter, () async {
        try {
          final now = await Clipboard.getData(Clipboard.kTextPlain);
          if (now?.text == text) await Clipboard.setData(const ClipboardData(text: ''));
        } catch (_) {}
      });
    }
  }
}

class FakeFiles implements FileBridge {
  Uint8List? shared;
  Uint8List? toPick;
  String? copied;

  @override
  Future<void> shareFile(Uint8List bytes, String fileName, String mime, String text) async => shared = bytes;

  @override
  Future<Uint8List?> pickFile() async => toPick;

  Uint8List? saved;
  String? savedName;

  @override
  Future<bool> saveFile(Uint8List bytes, String fileName) async {
    saved = bytes;
    savedName = fileName;
    return true;
  }

  @override
  Future<void> copy(String text, {Duration? clearAfter}) async => copied = text;
}
