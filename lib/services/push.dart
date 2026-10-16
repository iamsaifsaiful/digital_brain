import 'package:flutter/services.dart';

/// This phone's Firebase push token (see PushService.kt), for our server.
abstract class PushSource {
  /// Null when push is off in this build or not available.
  Future<String?> token();
}

class DevicePush implements PushSource {
  static const _ch = MethodChannel('my_assistant/push');

  @override
  Future<String?> token() async {
    try {
      return await _ch.invokeMethod<String>('token');
    } catch (_) {
      return null;
    }
  }
}

class FakePush implements PushSource {
  String? value;

  @override
  Future<String?> token() async => value;
}
