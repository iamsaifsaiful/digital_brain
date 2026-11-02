import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';

/// What the app asks of the phone: WhatsApp, calls, sharing, files, the
/// camera and the clipboard. Nothing is sent without the user pressing
/// send in the other app.
abstract class Device {
  /// Opens WhatsApp on [phone]'s chat with [text] typed in.
  Future<bool> whatsapp(String phone, String text);
  Future<bool> call(String phone);
  Future<void> shareText(String text);
  Future<void> shareFile(Uint8List bytes, String name, String mime, {String text = ''});
  Future<Uint8List?> pickFile();

  /// Opens a web page in the browser.
  Future<void> openLink(String url);

  /// Saves into the phone's Downloads; returns where, or null.
  Future<String?> saveDownload(Uint8List bytes, String name, String mime);

  /// Opens the system print dialog for a PDF.
  Future<bool> printPdf(Uint8List bytes, String name);
  Future<Uint8List?> takePhoto();

  /// A photo from the gallery, or from the camera when [camera] is true
  /// (back camera, for receipts).
  Future<Uint8List?> pickImage({bool camera = false});
  Future<String?> clipboard();
}

Uri whatsappUri(String phone, String text) {
  final n = waNumber(phone);
  return Uri.parse('https://wa.me/$n${text.isEmpty ? '' : '?text=${Uri.encodeComponent(text)}'}');
}

class PhoneDevice implements Device {
  @override
  Future<bool> whatsapp(String phone, String text) async {
    try {
      return await launchUrl(whatsappUri(phone, text), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('whatsapp failed');
      return false;
    }
  }

  @override
  Future<bool> call(String phone) async {
    try {
      return await launchUrl(Uri.parse('tel:${en(phone).replaceAll(RegExp(r'[^0-9+]'), '')}'), mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> shareText(String text) async {
    await SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Future<void> shareFile(Uint8List bytes, String name, String mime, {String text = ''}) async {
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/$name');
    await f.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path, mimeType: mime, name: name)], text: text.isEmpty ? null : text));
  }

  @override
  Future<void> openLink(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  static const _pdf = MethodChannel('riyal/pdf');

  @override
  Future<String?> saveDownload(Uint8List bytes, String name, String mime) async {
    try {
      return await _pdf.invokeMethod<String>('save', {'bytes': bytes, 'name': name, 'mime': mime});
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> printPdf(Uint8List bytes, String name) async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/$name');
      await f.writeAsBytes(bytes, flush: true);
      return await _pdf.invokeMethod<bool>('print', {'path': f.path, 'name': name}) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Uint8List?> pickFile() async {
    final f = await openFile();
    return f?.readAsBytes();
  }

  @override
  Future<Uint8List?> takePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 720, maxHeight: 720, imageQuality: 70, preferredCameraDevice: CameraDevice.front);
    return x?.readAsBytes();
  }

  @override
  Future<Uint8List?> pickImage({bool camera = false}) async {
    final x = await ImagePicker().pickImage(source: camera ? ImageSource.camera : ImageSource.gallery, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
    return x?.readAsBytes();
  }

  @override
  Future<String?> clipboard() async {
    try {
      return (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    } catch (_) {
      return null;
    }
  }
}

/// For tests.
class FakeDevice implements Device {
  final opened = <Uri>[];
  final shared = <String>[];
  String? clip;
  Uint8List? photo;
  Uint8List? file;

  @override
  Future<bool> whatsapp(String phone, String text) async {
    opened.add(whatsappUri(phone, text));
    return true;
  }

  @override
  Future<bool> call(String phone) async => true;

  @override
  Future<void> shareText(String text) async => shared.add(text);

  @override
  Future<void> shareFile(Uint8List bytes, String name, String mime, {String text = ''}) async => shared.add(name);

  final links = <String>[];

  @override
  Future<void> openLink(String url) async => links.add(url);

  final saved = <String>[];
  final printed = <String>[];

  @override
  Future<String?> saveDownload(Uint8List bytes, String name, String mime) async {
    saved.add(name);
    return 'Download/$name';
  }

  @override
  Future<bool> printPdf(Uint8List bytes, String name) async {
    printed.add(name);
    return true;
  }

  @override
  Future<Uint8List?> pickFile() async => file;

  @override
  Future<Uint8List?> takePhoto() async => photo;

  @override
  Future<Uint8List?> pickImage({bool camera = false}) async => photo;

  @override
  Future<String?> clipboard() async => clip;
}
