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

/// This app's version, sent with every call: an older one than the server
/// works with is told to update (keep equal to pubspec.yaml; a test checks).
const adminAppVersion = '1.15.0';

class ApiError implements Exception {
  const ApiError(this.message, {this.signedOut = false, this.code = '', this.url = ''});
  final String message;

  /// Where the new version is ('update').
  final String url;

  /// The server's reason ('otp_required', 'otp_wrong', 'otp_setup' …).
  final String code;

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

  static const _open = MethodChannel('my_assistant/open');
  static const _bkash = MethodChannel('my_assistant/bkash');

  /// A link in the phone's browser (the members PDF).
  static Future<bool> openUrl(String url) async {
    try {
      return await _open.invokeMethod<bool>('open', {'url': url}) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// বিকাশ মেলানো on this phone: {on, permission, last, queued}.
  static Future<Map<String, dynamic>> bkashStatus() async {
    try {
      return (await _bkash.invokeMapMethod<String, dynamic>('status')) ?? const {};
    } catch (_) {
      return const {};
    }
  }

  /// Asks Android for the SMS permission; true when given.
  static Future<bool> bkashPermission() async {
    try {
      return await _bkash.invokeMethod<bool>('permission') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> bkashSetup(String key, String base) async {
    try {
      await _bkash.invokeMethod('setup', {'key': key, 'base': base});
    } catch (_) {}
  }

  static Future<void> bkashOff() async {
    try {
      await _bkash.invokeMethod('off');
    } catch (_) {}
  }

  /// bKash payments received in the last [days] days (read on the phone; only the four fields).
  static Future<List<Map<String, dynamic>>> bkashScan(int days) async {
    try {
      final l = await _bkash.invokeListMethod<Map<Object?, Object?>>('scan', {'days': days}) ?? const [];
      return [for (final m in l) m.cast<String, dynamic>()];
    } catch (_) {
      return const [];
    }
  }

  static Future<Map<String, dynamic>> bkashFlush() async {
    try {
      return (await _bkash.invokeMapMethod<String, dynamic>('flush')) ?? const {};
    } catch (_) {
      return const {};
    }
  }
}

class Api {
  Api({http.Client? client, SessionStore? store, String? base}) : _http = client ?? http.Client(), _store = store ?? SecureSession(), base = base ?? apiBase;

  final http.Client _http;
  final SessionStore _store;
  final String base;
  String? _session;

  Future<bool> restore() async {
    _session = await _store.read();
    return _session != null && _session!.isNotEmpty;
  }

  /// Email and password of an admin account on the website, then the
  /// 6-digit code from the admin's authenticator app (two-step sign-in).
  Future<String> login(String email, String password, {String code = ''}) async {
    final r = await _call('POST', '/admin/login', {'email': email.trim(), 'password': password, if (code.isNotEmpty) 'code': code.replaceAll(' ', '')}, false);
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

  Future<List<Map<String, dynamic>>> payments(String status) async => ((await _send('GET', '/admin/payments?status=$status'))['payments'] as List).cast<Map<String, dynamic>>();

  Future<String> decide(int id, {required bool approve, String reason = '', bool tell = true}) async =>
      '${(await _send('POST', '/admin/payments/$id', {'decision': approve ? 'approve' : 'reject', 'reason': reason, 'tell': tell}))['message'] ?? ''}';

  Future<List<Map<String, dynamic>>> members({String q = '', int page = 1}) async => (await memberList(q: q, page: page)).$1;

  /// Members by search, status, join date ('today', 'week', 'month', 'YYYY-MM', 'YYYY-MM-DD')
  /// and Premium source: (rows, how many in all, the filter in words).
  Future<(List<Map<String, dynamic>>, int, String)> memberList({String q = '', String status = '', String joined = '', String src = '', int page = 1}) async {
    final r = await _send('GET', '/admin/members?${_query({'q': q, 'status': status, 'joined': joined, 'src': src, 'page': '$page'})}');
    return ((r['members'] as List).cast<Map<String, dynamic>>(), (r['count'] as num?)?.toInt() ?? 0, '${r['words'] ?? ''}');
  }

  /// New members per day (30) and month (12), Premium by source, and the figures.
  Future<Map<String, dynamic>> memberGrowth() => _send('GET', '/admin/members/growth');

  /// A 10-minute link to the members list as a PDF (opened in the phone's browser).
  Future<String> membersPdfLink({String q = '', String status = '', String joined = '', String src = ''}) async =>
      '${(await _send('POST', '/admin/members/print-link', {'q': q, 'status': status, 'joined': joined, 'src': src}))['url'] ?? ''}';

  static String _query(Map<String, String> m) => [for (final e in m.entries) if (e.value.isNotEmpty) '${e.key}=${Uri.encodeQueryComponent(e.value)}'].join('&');

  Future<Map<String, dynamic>> changeMember(int id, {int days = 0, bool stop = false, String? note}) async =>
      ((await _send('POST', '/admin/members/$id', {'days': days, 'stop': stop, if (note != null) 'note': note}))['member'] as Map).cast<String, dynamic>();

  Future<List<Map<String, dynamic>>> notices() async => ((await _send('GET', '/admin/notices'))['notices'] as List).cast<Map<String, dynamic>>();

  /// Members' feature wishes and problems ('open', 'done' or 'all').
  Future<List<Map<String, dynamic>>> feedback(String status) async => ((await _send('GET', '/admin/feedback?status=$status'))['feedback'] as List).cast<Map<String, dynamic>>();

  /// 'read', 'done', 'new' or 'delete'.
  Future<void> setFeedback(int id, String status) => _send('POST', '/admin/feedback/$id', {'status': status});

  /// One conversation: {feedback, messages}; opening it marks it read.
  Future<Map<String, dynamic>> feedbackThread(int id) => _send('GET', '/admin/feedback/$id');

  /// An answer (text and/or one photo or PDF, as base64); the member's phone is pushed.
  Future<void> replyFeedback(int id, String text, {String? fileName, Uint8List? bytes}) => _send('POST', '/admin/feedback/$id/reply', {
    'text': text,
    if (bytes != null) 'file': {'name': fileName ?? 'file', 'data': base64Encode(bytes)},
  });

  /// An attachment's bytes.
  Future<Uint8List> feedbackFile(int messageId) async => base64Decode('${(await _send('GET', '/admin/feedback/file/$messageId'))['data']}');

  Future<void> toggleNotice(int id) => _send('POST', '/admin/notices/$id/toggle');

  /// কোম্পানির হিসাব (site owner only): আয়, ব্যয়, বিনিয়োগকারী — the same as the site's হিসাব tab.
  /// [month] 'YYYY-MM'; [kind] '' / income / expense and [category] filter the month's lines.
  Future<Map<String, dynamic>> finance({String month = '', String kind = '', String category = ''}) =>
      _send('GET', '/admin/finance${month.isEmpty && kind.isEmpty && category.isEmpty ? '' : '?${_query({'month': month, 'kind': kind, 'category': category})}'}');

  /// সমস্যার লগ: errors the app ran into (cleaned on the phone and the server).
  Future<List<Map<String, dynamic>>> errors() async => [for (final e in ((await _send('GET', '/admin/errors'))['errors'] as List? ?? const [])) (e as Map).cast<String, dynamic>()];
  Future<void> clearErrors() => _send('POST', '/admin/errors/clear');
  /// সমস্যা খোঁজার লগ the members chose to send.
  Future<List<Map<String, dynamic>>> traces() async => [for (final e in ((await _send('GET', '/admin/traces'))['traces'] as List? ?? const [])) (e as Map).cast<String, dynamic>()];
  Future<String> trace(int id) async => '${(await _send('GET', '/admin/traces/$id'))['body'] ?? ''}';
  Future<void> clearTraces() => _send('POST', '/admin/traces/clear');
  /// Members who gave their blood group ([group] '' = all), with counts per group.
  Future<Map<String, dynamic>> bloodGroups(String group) async => await _send('GET', '/admin/blood${group.isEmpty ? '' : '?blood=${Uri.encodeQueryComponent(group)}'}');
  Future<void> addFinanceEntry({required String kind, required String category, required int amount, required String date, String note = ''}) =>
      _send('POST', '/admin/finance/entry', {'kind': kind, 'category': category, 'amount': amount, 'date': date, 'note': note});
  Future<void> addInvestor({required String name, String contact = '', int amount = 0, String share = '', required String date, String note = ''}) =>
      _send('POST', '/admin/finance/investor', {'name': name, 'contact': contact, 'amount': amount, 'share': share, 'date': date, 'note': note});
  Future<void> deleteFinance(String which, int id) => _send('POST', '/admin/finance/$which/$id');

  /// নোটিফিকেশনের লগ (as on the site): [q] a member's name or e-mail, [when] '', 'past' or 'next'.
  Future<List<Map<String, dynamic>>> noticeLog({String q = '', String when = ''}) async =>
      ((await _send('GET', '/admin/notice-log?q=${Uri.encodeQueryComponent(q)}&when=$when'))['rows'] as List).cast<Map<String, dynamic>>();

  /// What goes out, when, and how many a day (no list of who got what).
  Future<Map<String, dynamic>> noticeStats() => _send('GET', '/admin/notice-stats');

  /// The rules for the app's own notifications: each kind on/off, time, wording, who.
  Future<Map<String, dynamic>> noticeRules() => _send('GET', '/admin/notice-rules');
  Future<Map<String, dynamic>> saveNoticeRules(Map<String, dynamic> rules) => _send('POST', '/admin/notice-rules', rules);

  /// One day ('YYYY-MM-DD', '' = today): which notifications, what, when; how many each member gets.
  Future<Map<String, dynamic>> noticeDay(String day) => _send('GET', '/admin/notice-day${day.isEmpty ? '' : '?day=$day'}');

  // ── মতামত: one inbox per member ──

  /// Members with conversations ('open', 'done' or 'all').
  Future<List<Map<String, dynamic>>> inbox(String status) async => ((await _send('GET', '/admin/inbox?status=$status'))['members'] as List).cast<Map<String, dynamic>>();

  /// One member: every message of every conversation, and where a reply goes (reply_to).
  Future<Map<String, dynamic>> inboxOne(String key) => _send('GET', '/admin/inbox/${Uri.encodeComponent(key)}');

  /// 'done' (all finished) or 'open' (the newest opened again).
  Future<void> setInbox(String key, String status) => _send('POST', '/admin/inbox/${Uri.encodeComponent(key)}', {'status': status});

  // ── বিকাশ মেলানো ──

  Future<Map<String, dynamic>> bkash() => _send('GET', '/admin/bkash');
  Future<Map<String, dynamic>> setBkashAuto(bool on) => _send('POST', '/admin/bkash/settings', {'auto': on});

  /// A new key for this phone (the payment-SIM phone); the old one stops working.
  Future<String> bkashKey() async => '${(await _send('POST', '/admin/bkash/key'))['key'] ?? ''}';

  /// A bKash message read on this phone (pasted, or found in the inbox): only the four fields.
  Future<String> bkashManual(Map<String, dynamic> item) async => '${(await _send('POST', '/admin/bkash/manual', item))['status_label'] ?? ''}';

  Future<int> pushNow(String title, String body, String audience) async => ((await _send('POST', '/admin/push', {'title': title, 'body': body, 'audience': audience}))['sent'] as num?)?.toInt() ?? 0;

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

  /// Every sample under review (up to 500) as one text to copy, same as the site's button.
  Future<String> reviewText() async {
    final r = await _send('GET', '/admin/nlu/review?limit=500');
    return '${r['text'] ?? ''}';
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

  // ── উত্তরাধিকার (the same as the site's tab) ──

  /// Deaths reported by an heir the member chose: status review | all.
  Future<List<Map<String, dynamic>>> heirClaims({String status = 'all'}) async => ((await _send('GET', '/admin/family/claims?status=$status'))['claims'] as List).cast<Map<String, dynamic>>();

  /// approve (the member is told; the heir opens after 14 days unless cancelled) or reject.
  Future<void> decideClaim(int id, String action, String note) => _send('POST', '/admin/family/claims/$id', {'action': action, 'note': note});

  /// The certificate photo: (bytes, mime).
  Future<(Uint8List, String)> claimFile(int id) async {
    final r = await _send('GET', '/admin/family/claims/$id/file');
    return (base64Decode('${r['data']}'), '${r['mime']}');
  }

  /// A model added by hand as a draft (as on the site's "AI মডেল" page).
  Future<Map<String, dynamic>> addDraft(String version, String url, String sha256, int size) async =>
      ((await _send('POST', '/admin/nlu/models', {'action': 'draft', 'version': version, 'url': url, 'sha256': sha256, 'size': size}))['model'] as Map).cast<String, dynamic>();

  /// A new key for the retraining job (site owner only); the old one stops working.
  Future<String> newCiKey() async => '${(await _send('POST', '/admin/nlu/ci-key'))['ci_key']}';

  Future<Map<String, dynamic>> _send(String method, String path, [Map<String, Object?>? body]) => _call(method, path, body, true);

  Future<Map<String, dynamic>> _call(String method, String path, Map<String, Object?>? body, bool auth) async {
    final uri = Uri.parse('$base/wp-json/my-assistant/v1$path');
    final headers = {'content-type': 'application/json', 'x-ma-app-version': adminAppVersion, if (auth && _session != null) 'authorization': 'Bearer $_session'};
    http.Response r;
    try {
      r = await (method == 'GET' ? _http.get(uri, headers: headers) : _http.post(uri, headers: headers, body: jsonEncode(body ?? {}))).timeout(const Duration(seconds: 20));
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
    final reason = '${j['code'] ?? ''}';
    if (r.statusCode == 426 || reason == 'update') {
      final d = (j['data'] as Map?) ?? const {};
      throw ApiError('অ্যাডমিন অ্যাপের নতুন সংস্করণ (${d['min'] ?? ''}) বসান — এটা $adminAppVersion। নতুনটা ছাড়া লগইন বা কাজ হবে না।', code: 'update', url: '${d['url'] ?? ''}');
    }
    if (!auth && reason == 'otp_required') throw const ApiError('Authenticator অ্যাপের ৬ সংখ্যার কোড দিন', code: 'otp_required');
    if (!auth && reason == 'otp_wrong') throw const ApiError('কোড মেলেনি — অ্যাপে এখন যে কোড দেখাচ্ছে সেটা দিন', code: 'otp_wrong');
    if (!auth && (reason == 'otp_setup' || reason == 'otp_unreadable')) {
      final a = ((j['data'] as Map?)?['account'] as Map?) ?? const {};
      final who = a.isEmpty ? '' : '“${a['login']}” (${a['email']}) ';
      throw ApiError(
          reason == 'otp_setup'
              ? 'এই অ্যাকাউন্টে $whoদুই ধাপের লগইন চালু নেই। দুই ধাপ প্রতিটা WordPress অ্যাকাউন্টে আলাদা: getmyassistant.app/wp-admin-এ ঠিক এই অ্যাকাউন্ট দিয়ে ঢুকে My Assistant › নিরাপত্তা-তে চালু করুন, তারপর এখানে লগইন করুন।'
              : 'এই অ্যাকাউন্টের $whoদুই ধাপের চাবি সার্ভার পড়তে পারছে না। wp-admin › My Assistant › নিরাপত্তা-তে “পুরোনো চাবি মুছুন” চেপে আবার চালু করুন।',
          code: reason);
    }
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
