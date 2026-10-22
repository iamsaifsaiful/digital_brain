import 'package:flutter/services.dart';

/// ফ্যামিলি › লোকেশন on Android (LocationShare.kt): permissions, the sharing
/// settings the phone uses to answer "এখন কোথায়?" by itself, and sending
/// where it is now. Every call is harmless where it is not supported.
class LocationShareChannel {
  static const _ch = MethodChannel('my_assistant/location');

  /// {fine, background, service, sharing}
  static Future<Map<String, bool>> status() async {
    try {
      final m = await _ch.invokeMapMethod<String, Object?>('status') ?? const {};
      return {for (final e in m.entries) e.key: e.value == true};
    } catch (_) {
      return const {};
    }
  }

  static Future<void> ask() async {
    try {
      await _ch.invokeMethod<void>('ask');
    } catch (_) {}
  }

  static Future<void> askBackground() async {
    try {
      await _ch.invokeMethod<void>('askBackground');
    } catch (_) {}
  }

  static Future<void> configure({required bool on, String key = '', String session = '', String base = ''}) async {
    try {
      await _ch.invokeMethod<void>('configure', {'on': on, 'key': key, 'session': session, 'base': base});
    } catch (_) {}
  }

  static Future<bool> report() async {
    try {
      return await _ch.invokeMethod<bool>('report') ?? false;
    } catch (_) {
      return false;
    }
  }
}
