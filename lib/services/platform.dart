import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// What opened the app, other than the launcher icon: a share from another
/// app, the phone's assistant gesture, or the home-screen widget's mic.
class Launch {
  const Launch({this.action = '', this.text = '', this.files = const []});

  /// 'share', 'assist', 'voice' or ''.
  final String action;
  final String text;
  final List<SharedFile> files;
  bool get isEmpty => action.isEmpty && text.isEmpty && files.isEmpty;
}

class SharedFile {
  const SharedFile(this.name, this.mime, this.bytes);
  final String name;
  final String mime;
  final Uint8List bytes;
}

/// Android-only extras: the widget, the assistant setting, shares.
class AppPlatform {
  static const _ch = MethodChannel('my_assistant/launch');

  /// Called with each new launch while the app is running.
  static final launches = ValueNotifier<Launch?>(null);

  static bool _listening = false;

  static void listen() {
    if (_listening) return;
    _listening = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'launch') launches.value = _read(call.arguments);
      return null;
    });
  }

  static Launch _read(Object? a) {
    if (a is! Map) return const Launch();
    final files = <SharedFile>[];
    for (final f in (a['files'] as List? ?? const [])) {
      if (f is Map && f['bytes'] is Uint8List) {
        files.add(SharedFile('${f['name'] ?? 'file'}', '${f['mime'] ?? 'application/octet-stream'}', f['bytes'] as Uint8List));
      }
    }
    return Launch(action: '${a['action'] ?? ''}', text: '${a['text'] ?? ''}', files: files);
  }

  /// How the app was started (asked once at start).
  static Future<Launch> initial() async {
    try {
      return _read(await _ch.invokeMethod<Object?>('initial'));
    } catch (e) {
      return const Launch();
    }
  }

  /// The phone's "default digital assistant" page.
  static Future<void> openAssistSettings() async {
    try {
      await _ch.invokeMethod<void>('assistSettings');
    } catch (_) {}
  }

  /// Fresh numbers and lines for the home-screen widget.
  static Future<void> updateWidget(Map<String, String> v) async {
    try {
      await _ch.invokeMethod<void>('widget', v);
    } catch (_) {}
  }
}
