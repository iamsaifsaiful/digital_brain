// সমস্যার লগ (owner, 24 Oct night; 27 Oct: "ইউজারের ফোন থেকে সরাসরি
// এখানে আসবে"): problems the app runs into go straight to our server so
// they can be found and fixed —
//   • crash:   an error nothing caught (Dart), or the Android side crashing
//              (written by MainActivity, sent on the next start);
//   • problem: something the app handled but the member felt — the AI did
//              not answer or was slow, the voice recogniser failed, the data
//              could not be opened, our server answered with an error.
// Only what a developer needs: the kind, its first line cleaned of the
// member's words (no Bengali letters, quoted text, e-mails or long numbers),
// the places in the app's own code, and the app version. Never passwords,
// notes, health or anything typed — the same cleaning runs again on the
// server. Kept in a small file until sent, so a crash or a phone without
// internet does not lose them; sent a few seconds after they happen.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'google_account.dart' show AccountServer;

class ErrorLog {
  ErrorLog._();

  /// Waiting to be sent (at most 30; the same error counted, not repeated).
  static final pending = <Map<String, Object?>>[];

  static String version = '';
  static File? _file;
  static AccountServer? _server;
  static String Function() _session = () => '';
  static Timer? _soon;
  static bool _sending = false;

  /// How long after a problem it goes (several in a row go together).
  static Duration delay = const Duration(seconds: 8);

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

  /// Where the waiting reports are kept, and where the Android side leaves
  /// a crash (the app's files folder); reads both.
  static Future<void> open(Directory dir) async {
    try {
      _file = File('${dir.path}/error_log_pending.json');
      if (await _file!.exists()) {
        final j = jsonDecode(await _file!.readAsString());
        if (j is List) {
          for (final e in j) {
            if (e is Map && pending.length < 30) pending.add(Map<String, Object?>.from(e));
          }
        }
      }
      final crash = File('${dir.path}/app_crash.json');
      if (await crash.exists()) {
        final j = jsonDecode(await crash.readAsString());
        await crash.delete();
        if (j is Map) {
          _add('crash', clean('${j['kind'] ?? 'NativeCrash'}', max: 80), clean('${j['message'] ?? ''}'), clean('${j['stack'] ?? ''}', max: 2000, digits: 6), '${j['version'] ?? version}');
        }
      }
    } catch (_) {}
  }

  /// Our server and the member's session: reports go a few seconds after they happen.
  static void connect(AccountServer server, String Function() session) {
    _server = server;
    _session = session;
    if (pending.isNotEmpty) _later();
  }

  /// An error nothing caught.
  static void record(Object error, StackTrace? st, {String? version}) {
    try {
      _add('crash', clean(error.runtimeType.toString(), max: 80), clean('$error'.split('\n').first), places(st), version ?? ErrorLog.version);
    } catch (_) {}
  }

  /// Something the app handled but the member felt ([kind] like 'AiError',
  /// [code] like 'timeout'). Codes are the app's own words, never the member's.
  static void problem(String kind, String code, {StackTrace? st}) {
    try {
      _add('problem', clean(kind, max: 80), clean(code), places(st ?? StackTrace.current), version);
    } catch (_) {}
  }

  static void _add(String level, String kind, String message, String stack, String ver) {
    final same = pending.where((e) => e['kind'] == kind && e['message'] == message && e['stack'] == stack && (e['level'] ?? 'crash') == level).firstOrNull;
    if (same != null) {
      same['count'] = (same['count'] as int? ?? 1) + 1;
    } else {
      if (pending.length >= 30) return;
      pending.add({'level': level, 'kind': kind, 'message': message, 'stack': stack, 'version': ver, 'count': 1});
    }
    _save();
    _later();
  }

  static void _later() {
    if (_server == null) return;
    _soon?.cancel();
    _soon = Timer(delay, () => flush(_server!, _session()));
  }

  static void _save() {
    final f = _file;
    if (f == null) return;
    try {
      f.writeAsStringSync(jsonEncode(pending), flush: true);
    } catch (_) {}
  }

  /// Sends what is waiting (with the member's session if signed in, else without).
  static Future<void> flush(AccountServer server, String session) async {
    if (pending.isEmpty || !server.configured || _sending) return;
    _sending = true;
    final batch = [...pending];
    pending.clear();
    try {
      if (!await server.sendErrors(batch, session)) {
        // Kept for the next time (still at most 30).
        pending.insertAll(0, batch.take((30 - pending.length).clamp(0, 30)));
      }
    } finally {
      _sending = false;
      _save();
    }
  }
}
