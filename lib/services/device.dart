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
  Future<Uint8List?> takePhoto();
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

  @override
  Future<Uint8List?> pickFile() async => file;

  @override
  Future<Uint8List?> takePhoto() async => photo;

  @override
  Future<String?> clipboard() async => clip;
}
