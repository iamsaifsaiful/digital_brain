// সমস্যার লগ (owner, 24 Oct night): errors the app runs into are sent to
// our server so they can be found and fixed. Only what a developer needs:
// the kind of error, its first line cleaned of the member's words (no
// Bengali letters, quoted text, e-mails or long numbers), the places in the
// app's own code, and the app version. Never passwords, notes, health or
// anything typed — the same cleaning runs again on the server.
import 'google_account.dart' show AccountServer;

class ErrorLog {
  ErrorLog._();

  /// Waiting to be sent (at most 30; the same error counted, not repeated).
  static final pending = <Map<String, Object?>>[];

  static String clean(String s, {int max = 300, int digits = 3}) {
    var t = s;
    t = t.replaceAll(RegExp(r'"[^"]*"' "|'[^']*'"), '…');
    t = t.replaceAll(RegExp(r'[^\x09\x0A\x20-\x7E]+'), '•');
    t = t.replaceAll(RegExp(r'\S+@\S+'), '@');
    t = t.replaceAll(RegExp('\\d{$digits,}'), '#');
    t = t.trim();
    return t.length > max ? t.substring(0, max) : t;
  }

  /// The app's own code places (and Flutter's), up to 15, without addresses.
  static String places(StackTrace? st) {
    if (st == null) return '';
    final out = <String>[];
    for (final line in '$st'.split('\n')) {
      final m = RegExp(r'\((package:(?:digital_brain|flutter)/[^)]+)\)').firstMatch(line) ?? RegExp(r'(package:(?:digital_brain|flutter)/\S+)').firstMatch(line);
      if (m != null) out.add(m.group(1)!);
      if (out.length >= 15) break;
    }
    return clean(out.join('\n'), max: 2000, digits: 6);
  }

  static void record(Object error, StackTrace? st, {required String version}) {
    try {
      final kind = clean(error.runtimeType.toString(), max: 80);
      final message = clean('$error'.split('\n').first);
      final stack = places(st);
      final same = pending.where((e) => e['kind'] == kind && e['message'] == message && e['stack'] == stack).firstOrNull;
      if (same != null) {
        same['count'] = (same['count'] as int) + 1;
        return;
      }
      if (pending.length >= 30) return;
      pending.add({'kind': kind, 'message': message, 'stack': stack, 'version': version, 'count': 1});
    } catch (_) {}
  }

  /// Sends what is waiting (with the member's session if signed in, else without).
  static Future<void> flush(AccountServer server, String session) async {
    if (pending.isEmpty || !server.configured) return;
    final batch = [...pending];
    pending.clear();
    if (!await server.sendErrors(batch, session)) {
      // Kept for the next time (still at most 30).
      pending.insertAll(0, batch.take(30 - pending.length.clamp(0, 30)));
    }
  }
}
