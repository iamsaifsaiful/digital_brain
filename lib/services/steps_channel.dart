import 'package:flutter/services.dart';

/// The phone's step counter (Steps.kt). Every call is harmless where it is
/// not supported (no sensor, tests, iOS): it answers "no sensor".
class StepsChannel {
  static const _ch = MethodChannel('my_assistant/steps');

  /// (the phone has a step counter, the app may read it)
  static Future<(bool, bool)> status() async {
    try {
      final m = await _ch.invokeMapMethod<String, Object?>('status') ?? const {};
      return (m['sensor'] == true, m['allowed'] == true);
    } catch (_) {
      return (false, false);
    }
  }

  static Future<void> ask() async {
    try {
      await _ch.invokeMethod<void>('ask');
    } catch (_) {}
  }

  /// The running count since the phone was switched on, or null.
  static Future<double?> read() async {
    try {
      return await _ch.invokeMethod<double>('read');
    } catch (_) {
      return null;
    }
  }
}
