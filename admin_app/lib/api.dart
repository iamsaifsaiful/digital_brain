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

  Future<bool> canFingerprint() async {
    try {
      return await _auth.isDeviceSupported() && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> fingerprint(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, biometricOnly: true, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }

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

  Future<void> toggleNotice(int id) => _send('POST', '/admin/notices/$id/toggle');

  Future<int> pushNow(String title, String body, String audience) async =>
      ((await _send('POST', '/admin/push', {'title': title, 'body': body, 'audience': audience}))['sent'] as num?)?.toInt() ?? 0;

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
