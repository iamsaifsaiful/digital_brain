/// Everything the admin app knows comes from the server
/// (getmyassistant.app, the My Assistant Accounts plugin). The phone keeps
/// only the sign-in session; deleting the app loses nothing.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://getmyassistant.app');

class ApiError implements Exception {
  const ApiError(this.message, {this.signedOut = false});
  final String message;

  /// The session is gone or the email is no longer an admin.
  final bool signedOut;
  @override
  String toString() => message;
}

/// The session, kept in the phone's secure storage (the only thing kept).
abstract class SessionStore {
  Future<String?> read();
  Future<void> write(String? value);
  Future<bool> readFlag(String key);
  Future<void> writeFlag(String key, bool on);
}

class SecureSession implements SessionStore {
  static const _s = FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));
  @override
  Future<String?> read() async {
    try {
      return await _s.read(key: 'session');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String? value) async {
    try {
      if (value == null) {
        await _s.delete(key: 'session');
      } else {
        await _s.write(key: 'session', value: value);
      }
    } catch (_) {}
  }

  @override
  Future<bool> readFlag(String key) async {
    try {
      return await _s.read(key: key) == 'true';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> writeFlag(String key, bool on) async {
    try {
      await _s.write(key: key, value: on ? 'true' : 'false');
    } catch (_) {}
  }
}

class MemorySession implements SessionStore {
  String? value;
  final flags = <String, bool>{};
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String? v) async => value = v;
  @override
  Future<bool> readFlag(String key) async => flags[key] ?? false;
  @override
  Future<void> writeFlag(String key, bool on) async => flags[key] = on;
}

/// Fingerprint (after the first sign-in with email and password) and the
/// Firebase push token (Kotlin: PushService.kt).
class Device {
  static const _push = MethodChannel('my_assistant/push');
  final _auth = LocalAuthentication();

  /// The phone can check its owner: fingerprint (or face), or failing that
  /// the phone's own PIN/pattern.
  Future<bool> canFingerprint() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Asks for the fingerprint (the phone's own lock is offered too). Null
  /// when it is the owner; otherwise why not, in Bangla ('' = cancelled).
  Future<String?> verify(String reason) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final ok = await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
        return ok ? null : '';
      } on LocalAuthException catch (e) {
        // A prompt left over from before (e.g. asked while the app was still opening): clear it and ask again.
        if (e.code == LocalAuthExceptionCode.authInProgress && attempt == 0) {
          await _auth.stopAuthentication();
          await Future<void>.delayed(const Duration(milliseconds: 400));
          continue;
        }
        return authProblem(e.code);
      } catch (e) {
        return 'আঙুলের ছাপ চালু করা গেল না ($e)';
      }
    }
    return 'আঙুলের ছাপ চালু করা গেল না, আবার চাপুন';
  }

  Future<bool> fingerprint(String reason) async => await verify(reason) == null;

  Future<String?> pushToken() async {
    try {
      return await _push.invokeMethod<String>('token');
    } catch (_) {
      return null;
    }
  }
}

class Api {
  Api({http.Client? client, SessionStore? store, String? base})
      : _http = client ?? http.Client(),
        _store = store ?? SecureSession(),
        base = base ?? apiBase;

  final http.Client _http;
  final SessionStore _store;
  final String base;
  String? _session;

  Future<bool> restore() async {
    _session = await _store.read();
    return _session != null && _session!.isNotEmpty;
  }

  /// Email and password of an admin account on the website.
  Future<String> login(String email, String password) async {
    final r = await _call('POST', '/admin/login', {'email': email.trim(), 'password': password}, false);
    _session = '${r['session']}';
    await _store.write(_session);
    return '${r['name'] ?? ''}';
  }

  Future<void> logout() async {
    final s = _session;
    _session = null;
    await _store.write(null);
    await _store.writeFlag('fingerprint', false);
    if (s != null) {
      try {
        await _http.post(Uri.parse('$base/wp-json/my-assistant/v1/admin/logout'), headers: {'authorization': 'Bearer $s'}).timeout(const Duration(seconds: 8));
      } catch (_) {}
    }
  }

  Future<bool> fingerprintOn() => _store.readFlag('fingerprint');
  Future<void> setFingerprint(bool on) => _store.writeFlag('fingerprint', on);

  Future<void> sendPushToken(String token) => _send('POST', '/device', {'token': token});

  Future<Map<String, dynamic>> summary() => _send('GET', '/admin/summary');

  Future<List<Map<String, dynamic>>> payments(String status) async =>
      ((await _send('GET', '/admin/payments?status=$status'))['payments'] as List).cast<Map<String, dynamic>>();

  Future<String> decide(int id, {required bool approve, String reason = '', bool tell = true}) async =>
      '${(await _send('POST', '/admin/payments/$id', {'decision': approve ? 'approve' : 'reject', 'reason': reason, 'tell': tell}))['message'] ?? ''}';

  Future<List<Map<String, dynamic>>> members({String q = '', int page = 1}) async =>
      ((await _send('GET', '/admin/members?q=${Uri.encodeQueryComponent(q)}&page=$page'))['members'] as List).cast<Map<String, dynamic>>();

  Future<Map<String, dynamic>> changeMember(int id, {int days = 0, bool stop = false, String? note}) async =>
      ((await _send('POST', '/admin/members/$id', {'days': days, 'stop': stop, if (note != null) 'note': note}))['member'] as Map).cast<String, dynamic>();

  Future<List<Map<String, dynamic>>> notices() async => ((await _send('GET', '/admin/notices'))['notices'] as List).cast<Map<String, dynamic>>();

  /// Members' feature wishes and problems ('open', 'done' or 'all').
  Future<List<Map<String, dynamic>>> feedback(String status) async =>
      ((await _send('GET', '/admin/feedback?status=$status'))['feedback'] as List).cast<Map<String, dynamic>>();

  /// 'read', 'done', 'new' or 'delete'.
  Future<void> setFeedback(int id, String status) => _send('POST', '/admin/feedback/$id', {'status': status});

  /// One conversation: {feedback, messages}; opening it marks it read.
  Future<Map<String, dynamic>> feedbackThread(int id) => _send('GET', '/admin/feedback/$id');

  /// An answer (text and/or one photo or PDF, as base64); the member's phone is pushed.
  Future<void> replyFeedback(int id, String text, {String? fileName, Uint8List? bytes}) =>
      _send('POST', '/admin/feedback/$id/reply', {'text': text, if (bytes != null) 'file': {'name': fileName ?? 'file', 'data': base64Encode(bytes)}});

  /// An attachment's bytes.
  Future<Uint8List> feedbackFile(int messageId) async => base64Decode('${(await _send('GET', '/admin/feedback/file/$messageId'))['data']}');

  Future<void> toggleNotice(int id) => _send('POST', '/admin/notices/$id/toggle');

  Future<int> pushNow(String title, String body, String audience) async =>
      ((await _send('POST', '/admin/push', {'title': title, 'body': body, 'audience': audience}))['sent'] as num?)?.toInt() ?? 0;

  // ── AI ও বোঝা ──

  /// Cost by model, budgets, answer sources, and the NLU numbers.
  Future<Map<String, dynamic>> aiOverview() => _send('GET', '/admin/ai/overview');

  Future<Map<String, dynamic>> aiSettings() => _send('GET', '/admin/ai/settings');

  /// {nlu: {...}, ai_on, budgets: {free:{day,month}, pro:{...}}, budgets_auto}.
  Future<Map<String, dynamic>> saveAiSettings(Map<String, Object?> change) => _send('POST', '/admin/ai/settings', change);

  /// One real call to Gemini and Claude with a made-up sentence (site owner only).
  Future<Map<String, dynamic>> aiSelfTest() => _send('POST', '/admin/ai/selftest');

  /// Samples where the phone, the cloud and the member's final action differ; error signals first.
  Future<(List<Map<String, dynamic>>, List<String>)> review() async {
    final r = await _send('GET', '/admin/nlu/review?limit=50');
    return ((r['samples'] as List).cast<Map<String, dynamic>>(), (r['intents'] as List).cast<String>());
  }

  /// The right reading of a sample; pick = phone | cloud | other.
  Future<bool> label(int id, List<String> intents, String pick) async {
    await _send('POST', '/admin/nlu/review/$id', {'intents': intents, 'pick': pick});
    return true;
  }

  Future<List<Map<String, dynamic>>> models() async => ((await _send('GET', '/admin/nlu/models'))['models'] as List).cast<Map<String, dynamic>>();

  /// action: live (with pct) | pct | rollback.
  Future<Map<String, dynamic>> modelAction(String version, String action, {int? pct}) async =>
      ((await _send('POST', '/admin/nlu/models', {'version': version, 'action': action, if (pct != null) 'pct': pct}))['model'] as Map).cast<String, dynamic>();

  Future<Map<String, dynamic>> _send(String method, String path, [Map<String, Object?>? body]) => _call(method, path, body, true);

  Future<Map<String, dynamic>> _call(String method, String path, Map<String, Object?>? body, bool auth) async {
    final uri = Uri.parse('$base/wp-json/my-assistant/v1$path');
    final headers = {'content-type': 'application/json', if (auth && _session != null) 'authorization': 'Bearer $_session'};
    http.Response r;
    try {
      r = await (method == 'GET' ? _http.get(uri, headers: headers) : _http.post(uri, headers: headers, body: jsonEncode(body ?? {})))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const ApiError('ইন্টারনেট সংযোগ পাওয়া যায়নি');
    }
    Map<String, dynamic> j;
    try {
      j = (jsonDecode(utf8.decode(r.bodyBytes)) as Map).cast<String, dynamic>();
    } catch (_) {
      j = {};
    }
    if (r.statusCode == 429) throw const ApiError('অনেকবার ভুল হয়েছে — ১৫ মিনিট পরে আবার চেষ্টা করুন');
    if (r.statusCode == 403 && j['code'] == 'owner') throw const ApiError('এটা শুধু সাইটের মূল অ্যাডমিন করতে পারেন');
    if (r.statusCode == 401 || r.statusCode == 403) {
      if (auth) {
        await logout();
        throw const ApiError('আবার লগইন করুন', signedOut: true);
      }
      throw const ApiError('ইমেইল বা পাসওয়ার্ড মেলেনি, অথবা এই অ্যাকাউন্ট অ্যাডমিন নয়');
    }
    if (r.statusCode == 409) throw ApiError('${j['message'] ?? 'আগেই করা হয়েছে'}');
    if (r.statusCode != 200) throw ApiError('সার্ভারে সমস্যা (${r.statusCode})');
    return j;
  }
}

/// Why the fingerprint did not open the app, said plainly.
String authProblem(LocalAuthExceptionCode code) => switch (code) {
      LocalAuthExceptionCode.userCanceled || LocalAuthExceptionCode.systemCanceled => '',
      LocalAuthExceptionCode.noBiometricsEnrolled => 'ফোনে কোনো আঙুলের ছাপ রাখা নেই — ফোনের Settings › Security থেকে যোগ করুন, অথবা ফোনের লক দিয়ে খুলুন',
      LocalAuthExceptionCode.noCredentialsSet => 'ফোনে কোনো স্ক্রিন লক নেই — আগে ফোনের Settings থেকে PIN বা আঙুলের ছাপ চালু করুন',
      LocalAuthExceptionCode.noBiometricHardware => 'এই ফোনে আঙুলের ছাপের সেন্সর নেই',
      LocalAuthExceptionCode.temporaryLockout => 'অনেকবার ভুল হয়েছে — একটু পরে আবার চেষ্টা করুন, বা ফোনের লক দিয়ে খুলুন',
      LocalAuthExceptionCode.biometricLockout => 'আঙুলের ছাপ বন্ধ হয়ে গেছে — ফোন একবার লক করে PIN দিয়ে খুলুন, তারপর আবার চেষ্টা করুন',
      LocalAuthExceptionCode.timeout => 'সময় শেষ — আবার চাপুন',
      _ => 'আঙুলের ছাপ চালু করা গেল না (${code.name}) — আবার চাপুন',
    };
