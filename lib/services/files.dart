import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart' as sp;

/// Sharing a file out of the app, picking one in, and the clipboard.
abstract class FileBridge {
  /// Opens the share sheet with [bytes] saved as [fileName].
  Future<void> shareFile(Uint8List bytes, String fileName, String mime, String text);

  /// Opens the share sheet with plain text (a receipt, a message).
  Future<void> shareText(String text);

  /// Asks where to keep the file (Download or any folder) and writes it
  /// there. True when saved, false when the user cancelled.
  Future<bool> saveFile(Uint8List bytes, String fileName, {String? mime});

  /// Opens the file in another app on the phone (a PDF reader, Word…).
  /// False when no app can open it.
  Future<bool> openWith(Uint8List bytes, String fileName, String mime);

  /// A PDF opened for viewing: its id and number of pages (null: not readable).
  Future<(int, int)?> pdfOpen(Uint8List bytes);

  /// One page as a PNG, [width] pixels wide.
  Future<Uint8List?> pdfPage(int id, int index, int width);
  Future<void> pdfClose(int id);

  /// Lets the user pick a file; null when they cancel.
  Future<Uint8List?> pickFile();

  /// Copies [text]; secrets are wiped from the clipboard after [clearAfter].
  Future<void> copy(String text, {Duration? clearAfter});

  /// A photo from the camera or the gallery. With [shrink] the longest side
  /// is kept within [maxSide] pixels and saved at high JPEG quality, so a
  /// phone photo of a paper becomes a fraction of its size and stays sharp
  /// enough to read.
  Future<PickedDoc?> pickPhoto({required bool camera, bool shrink = true, int side = maxSide});

  /// Any file (PDF, Word…), kept exactly as it is.
  Future<PickedDoc?> pickDocument();

  /// Several photos from the gallery at once (shrunk like [pickPhoto]).
  Future<List<PickedDoc>> pickPhotos({bool shrink = true});

  /// Several files at once, kept as they are.
  Future<List<PickedDoc>> pickDocuments();
}

/// The longest side of a saved document photo: about 240 dpi for an A4
/// page — small print stays readable.
const maxSide = 2000;
const photoQuality = 88;

class PickedDoc {
  const PickedDoc(this.bytes, this.name, this.mime);
  final Uint8List bytes;
  final String name;
  final String mime;
}

String mimeFor(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.jpg') || n.endsWith('.jpeg')) return 'image/jpeg';
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.heic')) return 'image/heic';
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.doc')) return 'application/msword';
  if (n.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
  if (n.endsWith('.xls')) return 'application/vnd.ms-excel';
  if (n.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
  return 'application/octet-stream';
}

class DeviceFiles implements FileBridge {
  Timer? _clear;
  static const _channel = MethodChannel('my_assistant/files');

  @override
  Future<bool> saveFile(Uint8List bytes, String fileName, {String? mime}) async {
    final ok = await _channel.invokeMethod<bool>('saveFile', {'bytes': bytes, 'name': fileName, if (mime != null) 'mime': mime});
    return ok ?? false;
  }

  @override
  Future<bool> openWith(Uint8List bytes, String fileName, String mime) async {
    try {
      return await _channel.invokeMethod<bool>('openWith', {'bytes': bytes, 'name': fileName, 'mime': mime}) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<(int, int)?> pdfOpen(Uint8List bytes) async {
    try {
      final r = await _channel.invokeMethod<Map<Object?, Object?>>('pdfOpen', {'bytes': bytes});
      if (r == null) return null;
      return ((r['id'] as num).toInt(), (r['pages'] as num).toInt());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Uint8List?> pdfPage(int id, int index, int width) async {
    try {
      return await _channel.invokeMethod<Uint8List>('pdfPage', {'id': id, 'index': index, 'width': width});
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> pdfClose(int id) async {
    try {
      await _channel.invokeMethod<void>('pdfClose', {'id': id});
    } catch (_) {}
  }

  @override
  Future<void> shareFile(Uint8List bytes, String fileName, String mime, String text) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$fileName');
    await f.writeAsBytes(bytes, flush: true);
    await sp.SharePlus.instance.share(sp.ShareParams(files: [sp.XFile(f.path, mimeType: mime)], text: text));
  }

  @override
  Future<void> shareText(String text) async {
    await sp.SharePlus.instance.share(sp.ShareParams(text: text));
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
  Future<PickedDoc?> pickPhoto({required bool camera, bool shrink = true, int side = maxSide}) async {
    try {
      final x = await ImagePicker().pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        preferredCameraDevice: side < maxSide ? CameraDevice.front : CameraDevice.rear,
        maxWidth: shrink ? side.toDouble() : null,
        maxHeight: shrink ? side.toDouble() : null,
        imageQuality: shrink ? photoQuality : null,
        requestFullMetadata: false,
      );
      if (x == null) return null;
      final name = x.name.isEmpty ? 'photo.jpg' : x.name;
      return PickedDoc(await x.readAsBytes(), name, x.mimeType ?? mimeFor(name));
    } catch (e) {
      debugPrint('photo failed: $e');
      return null;
    }
  }

  @override
  Future<List<PickedDoc>> pickPhotos({bool shrink = true}) async {
    try {
      final xs = await ImagePicker().pickMultiImage(
        maxWidth: shrink ? maxSide.toDouble() : null,
        maxHeight: shrink ? maxSide.toDouble() : null,
        imageQuality: shrink ? photoQuality : null,
        requestFullMetadata: false,
      );
      return [
        for (final x in xs) PickedDoc(await x.readAsBytes(), x.name.isEmpty ? 'photo.jpg' : x.name, x.mimeType ?? mimeFor(x.name.isEmpty ? 'photo.jpg' : x.name)),
      ];
    } catch (e) {
      debugPrint('photos failed: $e');
      return const [];
    }
  }

  @override
  Future<List<PickedDoc>> pickDocuments() async {
    try {
      final fsx = await fs.openFiles();
      return [for (final f in fsx) PickedDoc(await f.readAsBytes(), f.name, f.mimeType ?? mimeFor(f.name))];
    } catch (e) {
      debugPrint('pick failed: $e');
      return const [];
    }
  }

  @override
  Future<PickedDoc?> pickDocument() async {
    try {
      final f = await fs.openFile();
      if (f == null) return null;
      return PickedDoc(await f.readAsBytes(), f.name, f.mimeType ?? mimeFor(f.name));
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

  String? sharedText;

  @override
  Future<void> shareText(String text) async => sharedText = text;

  @override
  Future<Uint8List?> pickFile() async => toPick;

  Uint8List? saved;
  String? savedName;

  @override
  Future<bool> saveFile(Uint8List bytes, String fileName, {String? mime}) async {
    saved = bytes;
    savedName = fileName;
    return true;
  }

  String? openedWith;
  int pdfPages = 2;

  @override
  Future<bool> openWith(Uint8List bytes, String fileName, String mime) async {
    openedWith = fileName;
    return true;
  }

  @override
  Future<(int, int)?> pdfOpen(Uint8List bytes) async => (1, pdfPages);

  @override
  Future<Uint8List?> pdfPage(int id, int index, int width) async => null;

  @override
  Future<void> pdfClose(int id) async {}

  @override
  Future<void> copy(String text, {Duration? clearAfter}) async => copied = text;

  PickedDoc? photo;
  PickedDoc? document;

  @override
  Future<PickedDoc?> pickPhoto({required bool camera, bool shrink = true, int side = maxSide}) async => photo;

  @override
  Future<PickedDoc?> pickDocument() async => document;

  /// What the gallery "returns" when several photos are picked.
  List<PickedDoc> photos = [];
  List<PickedDoc> documents = [];

  @override
  Future<List<PickedDoc>> pickPhotos({bool shrink = true}) async => photos.isNotEmpty ? photos : [if (photo != null) photo!];

  @override
  Future<List<PickedDoc>> pickDocuments() async => documents.isNotEmpty ? documents : [if (document != null) document!];
}
