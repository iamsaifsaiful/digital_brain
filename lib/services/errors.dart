import 'package:flutter/foundation.dart';

import 'api.dart';

const appVersion = '1.2.0';

/// Problems in the app, sent to the server's "সমস্যার লগ" so they can be
/// looked into. Kept in memory until the phone is signed in and online.
class ErrorLog {
  static final pending = <Map<String, Object?>>[];

  static void add(Object error, StackTrace? stack, {String where = 'app'}) {
    if (pending.length >= 50) pending.removeAt(0);
    final msg = '$error';
    // The same problem many times in a row is sent once.
    if (pending.isNotEmpty && pending.last['message'] == msg) return;
    pending.add({
      'at': DateTime.now().toIso8601String(),
      'where': where,
      'message': msg.length > 600 ? msg.substring(0, 600) : msg,
      'stack': (stack?.toString() ?? '').split('\n').take(25).join('\n'),
      'version': appVersion,
      'platform': defaultTargetPlatform.name,
    });
  }

  static Future<void> flush(Api api) async {
    if (pending.isEmpty || api.token == null) return;
    final batch = List<Map<String, Object?>>.of(pending);
    try {
      await api.post('/errors', {'errors': batch});
      pending.removeRange(0, batch.length.clamp(0, pending.length));
    } catch (_) {
      // Tried again at the next sync.
    }
  }
}
