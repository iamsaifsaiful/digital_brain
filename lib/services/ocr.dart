import 'package:flutter/services.dart';

/// The printed text in a photo, read on the phone (nothing leaves it).
abstract class TextReader {
  /// The text of a photo or a PDF's first pages, or null when it could not
  /// be read (or on a phone without it).
  Future<String?> read(Uint8List image, {String mime = 'image/jpeg'});
}

class DeviceTextReader implements TextReader {
  static const _ch = MethodChannel('my_assistant/ocr');

  @override
  Future<String?> read(Uint8List image, {String mime = 'image/jpeg'}) async {
    try {
      return await _ch.invokeMethod<String>('read', {'bytes': image, 'mime': mime}).timeout(const Duration(seconds: 40));
    } catch (_) {
      return null;
    }
  }
}

/// Tests: the text a photo "has".
class FakeTextReader implements TextReader {
  FakeTextReader([this.text]);
  String? text;
  int reads = 0;

  @override
  Future<String?> read(Uint8List image, {String mime = 'image/jpeg'}) async {
    reads++;
    return text;
  }
}

/// Photos and PDFs the reader can read.
bool readable(String mime) => mime.startsWith('image/') || mime == 'application/pdf';
