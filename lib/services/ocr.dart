import 'package:flutter/services.dart';

/// The printed text in a photo, read on the phone (nothing leaves it).
abstract class TextReader {
  /// The text, or null when it could not be read (or on a phone without it).
  Future<String?> read(Uint8List image);
}

class DeviceTextReader implements TextReader {
  static const _ch = MethodChannel('my_assistant/ocr');

  @override
  Future<String?> read(Uint8List image) async {
    try {
      return await _ch.invokeMethod<String>('read', {'bytes': image}).timeout(const Duration(seconds: 20));
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
  Future<String?> read(Uint8List image) async {
    reads++;
    return text;
  }
}
