import 'package:flutter/services.dart';

/// Notifications from the server (Firebase Cloud Messaging). Firebase's
/// settings come from the server at sign-in, so nothing about it is built
/// into the APK. Returns this phone's token, or null when push is off.
abstract class Push {
  Future<String?> start(Map<String, Object?> options);

  /// Shows a notification now, with the app's chime: to check the sound.
  Future<bool> test(String title, String body);
}

class PhonePush implements Push {
  static const _ch = MethodChannel('riyal/push');

  @override
  Future<bool> test(String title, String body) async {
    try {
      return await _ch.invokeMethod<bool>('test', {'title': title, 'body': body}) ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> start(Map<String, Object?> options) async {
    try {
      return await _ch.invokeMethod<String>('start', {for (final e in options.entries) e.key: '${e.value}'});
    } catch (_) {
      return null;
    }
  }
}

class FakePush implements Push {
  Map<String, Object?>? started;
  final tests = <String>[];
  @override
  Future<bool> test(String title, String body) async {
    tests.add(title);
    return true;
  }

  @override
  Future<String?> start(Map<String, Object?> options) async {
    started = options;
    return 'fake-device-token-0123456789';
  }
}
