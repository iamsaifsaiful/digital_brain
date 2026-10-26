/// Google sign-in, Drive backup in the app's hidden Drive folder, and the
/// account record on our server.
///
/// Drive: only the `drive.appdata` scope — a hidden folder that belongs to
/// this app. The app cannot see the user's other Drive files, and the user
/// does not see this folder in Drive. Every backup there is the same
/// password-locked file as a manual backup; Google and we cannot read it.
///
/// Server: our WordPress plugin (tool/wordpress/my-assistant-accounts). It
/// gets the Google sign-in token (checked there with Google), and keeps the
/// name, email, when the trial started and Pro. Never any of the user's
/// records, notes, passwords or backups.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../logic/money_more.dart' show MetalPrice;
import '../logic/server_notices.dart';

/// The OAuth "Web client" ID from Google Cloud (passed at build time with
/// `--dart-define=GOOGLE_WEB_CLIENT_ID=…`). Empty until it is set up.
const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID', defaultValue: '611798531174-n31emvhp4bhvuh2he9rp9njirsi3ch47.apps.googleusercontent.com');

/// Our server: the WordPress site (override with `--dart-define=API_BASE=…`).
const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://getmyassistant.app');

class GoogleUser {
  const GoogleUser({required this.id, required this.email, required this.name, this.photo = '', this.idToken = ''});
  final String id;
  final String email;
  final String name;
  final String photo;

  /// Proof of sign-in for our server (never stored).
  final String idToken;
}

class GoogleError implements Exception {
  const GoogleError(this.message, {this.setup = false});
  final String message;

  /// Google Cloud is not set up for this app yet.
  final bool setup;
  @override
  String toString() => message;
}

abstract class GoogleAccount {
  /// Opens Google's account picker. Null when the user closes it.
  Future<GoogleUser?> signIn();

  /// An access token for the app's Drive folder (asks once for permission).
  Future<String> driveToken();
  Future<void> signOut();
}

class DeviceGoogle implements GoogleAccount {
  static const _ch = MethodChannel('my_assistant/google');

  @override
  Future<GoogleUser?> signIn() async {
    if (googleWebClientId.isEmpty) throw const GoogleError('Google লগইনের সেটআপ এখনো বাকি', setup: true);
    try {
      final r = await _ch.invokeMapMethod<String, Object?>('signIn', {'webClientId': googleWebClientId});
      if (r == null) return null;
      return GoogleUser(
        id: '${r['id'] ?? ''}',
        email: '${r['email'] ?? ''}',
        name: '${r['name'] ?? ''}',
        photo: '${r['photo'] ?? ''}',
        idToken: '${r['idToken'] ?? ''}',
      );
    } on PlatformException catch (e) {
      if (e.code == 'cancelled') return null;
      throw GoogleError(_message(e), setup: e.code == 'setup');
    }
  }

  @override
  Future<String> driveToken() async {
    try {
      final t = await _ch.invokeMethod<String>('driveToken');
      if (t == null || t.isEmpty) throw const GoogleError('Google Drive-এর অনুমতি পাওয়া যায়নি');
      return t;
    } on PlatformException catch (e) {
      throw GoogleError(_message(e), setup: e.code == 'setup');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _ch.invokeMethod<void>('signOut');
    } catch (_) {}
  }

  static String _message(PlatformException e) => switch (e.code) {
        'setup' => 'Google লগইনের সেটআপ এখনো বাকি',
        'network' => 'ইন্টারনেট সংযোগ নেই',
        'cancelled' => 'বাতিল করা হয়েছে',
        _ => 'Google-এ সমস্যা: ${e.message ?? e.code}',
      };
}

/// For tests.
class FakeGoogle implements GoogleAccount {
  GoogleUser? user = const GoogleUser(id: '1', email: 'test@gmail.com', name: 'Test');
  String token = 'token';
  int signIns = 0;

  @override
  Future<GoogleUser?> signIn() async {
    signIns++;
    return user;
  }

  @override
  Future<String> driveToken() async => token;

  @override
  Future<void> signOut() async {}
}

class DriveFile {
  const DriveFile(this.id, this.name, this.time, this.size);
  final String id;
  final String name;
  final DateTime time;
  final int size;
}

/// The app's hidden Drive folder (appDataFolder), through the Drive REST API.
abstract class DriveStore {
  Future<List<DriveFile>> list(String token);
  Future<String> upload(String token, String name, Uint8List bytes);
  Future<Uint8List> download(String token, String id);
  Future<void> delete(String token, String id);
}

class HttpDrive implements DriveStore {
  HttpDrive([http.Client? client]) : _http = client ?? http.Client();
  final http.Client _http;
  static const _api = 'https://www.googleapis.com/drive/v3';
  static const _upload = 'https://www.googleapis.com/upload/drive/v3';

  Map<String, String> _auth(String t) => {'Authorization': 'Bearer $t'};

  void _ok(http.Response r, String what) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    if (r.statusCode == 403 && r.body.contains('storageQuotaExceeded')) throw const GoogleError('Google Drive-এ জায়গা নেই');
    if (r.statusCode == 401 || r.statusCode == 403) throw const GoogleError('Google Drive-এর অনুমতি শেষ হয়েছে — আবার লগইন করুন');
    throw GoogleError('Google Drive: $what হয়নি (${r.statusCode})');
  }

  @override
  Future<List<DriveFile>> list(String token) async {
    final uri = Uri.parse('$_api/files').replace(queryParameters: {
      'spaces': 'appDataFolder',
      'fields': 'files(id,name,createdTime,size)',
      'orderBy': 'createdTime desc',
      'pageSize': '50',
    });
    final r = await _http.get(uri, headers: _auth(token));
    _ok(r, 'তালিকা');
    final files = (jsonDecode(r.body) as Map<String, dynamic>)['files'] as List? ?? const [];
    return [
      for (final f in files.cast<Map<String, dynamic>>())
        DriveFile('${f['id']}', '${f['name']}', DateTime.tryParse('${f['createdTime']}') ?? DateTime(2000), int.tryParse('${f['size'] ?? 0}') ?? 0),
    ];
  }

  @override
  Future<String> upload(String token, String name, Uint8List bytes) async {
    // Resumable upload: works for large backups with photos too.
    final start = await _http.post(
      Uri.parse('$_upload/files?uploadType=resumable&fields=id'),
      headers: {..._auth(token), 'Content-Type': 'application/json; charset=UTF-8', 'X-Upload-Content-Type': 'application/octet-stream', 'X-Upload-Content-Length': '${bytes.length}'},
      body: jsonEncode({'name': name, 'parents': ['appDataFolder']}),
    );
    _ok(start, 'আপলোড শুরু');
    final at = start.headers['location'];
    if (at == null) throw const GoogleError('Google Drive: আপলোড শুরু হয়নি');
    final put = await _http.put(Uri.parse(at), headers: {'Content-Type': 'application/octet-stream'}, body: bytes);
    _ok(put, 'আপলোড');
    return '${(jsonDecode(put.body) as Map<String, dynamic>)['id']}';
  }

  @override
  Future<Uint8List> download(String token, String id) async {
    final r = await _http.get(Uri.parse('$_api/files/$id?alt=media'), headers: _auth(token));
    _ok(r, 'ডাউনলোড');
    return r.bodyBytes;
  }

  @override
  Future<void> delete(String token, String id) async {
    final r = await _http.delete(Uri.parse('$_api/files/$id'), headers: _auth(token));
    if (r.statusCode == 404) return;
    _ok(r, 'পুরোনো ব্যাকআপ মোছা');
  }
}

/// For tests: an in-memory Drive folder.
class FakeDrive implements DriveStore {
  final files = <String, (DriveFile, Uint8List)>{};
  int _n = 0;
  DateTime Function() now = DateTime.now;
  bool failUpload = false;

  @override
  Future<List<DriveFile>> list(String token) async => [for (final f in files.values) f.$1]..sort((a, b) => b.time.compareTo(a.time));

  @override
  Future<String> upload(String token, String name, Uint8List bytes) async {
    if (failUpload) throw const GoogleError('Google Drive: আপলোড হয়নি (500)');
    final id = 'f${++_n}';
    files[id] = (DriveFile(id, name, now().add(Duration(milliseconds: _n)), bytes.length), bytes);
    return id;
  }

  @override
  Future<Uint8List> download(String token, String id) async => files[id]!.$2;

  @override
  Future<void> delete(String token, String id) async => files.remove(id);
}

class SessionExpired implements Exception {
  const SessionExpired();
}

/// What our server says about the account.
class AccountInfo {
  const AccountInfo({this.proUntil, this.proKind = '', this.trialUsed = false, this.session = '', this.ai = false, this.aiLeft = 0, this.backupKey = '', this.feedbackUnread = 0});
  final DateTime? proUntil;
  final String proKind;
  final bool trialUsed;

  /// This phone's session with the server ('' when not given).
  final String session;

  /// The server's AI is on (key set and switched on).
  final bool ai;
  final int aiLeft;

  /// Locks this account's Drive backup (kept by our server, given only to
  /// the member's own signed-in phone; the backup itself stays in Drive).
  final String backupKey;

  /// Answers to the user's feedback not opened yet.
  final int feedbackUnread;

  static AccountInfo fromJson(Map<String, dynamic> j) => AccountInfo(
        proUntil: DateTime.tryParse('${j['pro_until'] ?? ''}'),
        proKind: '${j['pro_kind'] ?? ''}',
        trialUsed: j['trial_used'] == true,
        session: RegExp(r'^[a-f0-9]{64}$').hasMatch('${j['session'] ?? ''}') ? '${j['session']}' : '',
        ai: j['ai'] == true,
        aiLeft: (j['ai_left'] as num?)?.toInt() ?? 0,
        feedbackUnread: (j['feedback_unread'] as num?)?.toInt() ?? 0,
        backupKey: RegExp(r'^[A-Za-z0-9_-]{40,64}$').hasMatch('${j['backup_key'] ?? ''}') ? '${j['backup_key']}' : '',
      );
}

/// Our server (the WordPress plugin). Does nothing when [apiBase] is empty.
class AccountServer {
  AccountServer([http.Client? client, String? base])
      : _http = client ?? http.Client(),
        base = base ?? apiBase;

  /// No server (tests, and builds without one).
  AccountServer.off()
      : _http = http.Client(),
        base = '';

  final http.Client _http;
  final String base;

  bool get configured => base.isNotEmpty;

  /// Today's gold and silver price (BAJUS), looked up and kept by the server. Null offline.
  Future<MetalPrice?> metalPrice() async {
    if (!configured) return null;
    try {
      final r = await _http.get(Uri.parse('$base/wp-json/my-assistant/v1/metal-price')).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      return MetalPrice.fromJson(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<AccountInfo?> login(GoogleUser u, {required String appVersion, required String edition}) async {
    if (!configured || u.idToken.isEmpty) return null;
    try {
      final r = await _http
          .post(Uri.parse('$base/wp-json/my-assistant/v1/login'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode({'id_token': u.idToken, 'app_version': appVersion, 'edition': edition}))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      return AccountInfo.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// The plan now (Pro given on the website shows up without signing in
  /// again). Null when offline; [SessionExpired] when the server forgot us.
  Future<AccountInfo?> me(String session) async {
    if (!configured || session.isEmpty) return null;
    try {
      final r = await _http.get(Uri.parse('$base/wp-json/my-assistant/v1/me'), headers: {'authorization': 'Bearer $session'}).timeout(const Duration(seconds: 15));
      if (r.statusCode == 401) throw const SessionExpired();
      if (r.statusCode != 200) return null;
      return AccountInfo.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
    } on SessionExpired {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  String get aiUrl => '$base/wp-json/my-assistant/v1/ai';

  /// Tells the server where to send push for this phone.
  Future<bool> device(String session, String token) async {
    if (!configured || session.isEmpty) return false;
    try {
      final r = await _http
          .post(Uri.parse('$base/wp-json/my-assistant/v1/device'), headers: {'Content-Type': 'application/json', 'authorization': 'Bearer $session'}, body: jsonEncode({'token': token}))
          .timeout(const Duration(seconds: 15));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Notifications written on the website for this phone (everyone's, plus
  /// its plan's when signed in). Null when offline.
  Future<List<ServerNotice>?> notices(String session) async {
    if (!configured) return null;
    try {
      final r = await _http
          // push=1: this app takes the server's pushes for notices without a condition.
          .get(Uri.parse('$base/wp-json/my-assistant/v1/notices?push=1'), headers: {if (session.isNotEmpty) 'authorization': 'Bearer $session'})
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final list = body['notices'] as List? ?? const [];
      final pushed = {for (final x in body['pushed'] as List? ?? const []) if (x is num) x.toInt()};
      return [
        ...list.take(30).map((j) => ServerNotice.fromJson(j is Map && pushed.contains((j['id'] as num?)?.toInt()) ? {...j, 'pushed': true} : j)).whereType<ServerNotice>()
      ];
    } catch (_) {
      return null;
    }
  }

  /// সমস্যার লগ: cleaned error reports (services/error_log.dart); works before sign-in too.
  Future<bool> sendErrors(List<Map<String, Object?>> items, String session) async {
    if (!configured) return false;
    try {
      final r = await _http
          .post(Uri.parse('$base/wp-json/my-assistant/v1/errors'),
              headers: {'Content-Type': 'application/json', if (session.isNotEmpty) 'authorization': 'Bearer $session'}, body: jsonEncode({'items': items}))
          .timeout(const Duration(seconds: 20));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// One call to our server with this phone's session: the answer, or a
  /// plain Bangla reason it did not work (see logic in services/community.dart).
  Future<ServerReply> send(String method, String path, String session, [Map<String, Object?>? body]) async {
    if (!configured) return const ServerReply(0, {}, 'সার্ভার যুক্ত নেই');
    if (session.isEmpty) return const ServerReply(401, {}, 'আগে Google দিয়ে লগইন করুন');
    try {
      final uri = Uri.parse('$base/wp-json/my-assistant/v1$path');
      final headers = {'Content-Type': 'application/json', 'authorization': 'Bearer $session'};
      final r = await (method == 'GET'
              ? _http.get(uri, headers: headers)
              : method == 'DELETE'
                  ? _http.delete(uri, headers: headers)
                  : _http.post(uri, headers: headers, body: jsonEncode(body ?? const {})))
          .timeout(const Duration(seconds: 40));
      Map<String, dynamic> data = const {};
      try {
        final j = jsonDecode(utf8.decode(r.bodyBytes));
        if (j is Map<String, dynamic>) data = j;
      } catch (_) {}
      if (r.statusCode == 200) return ServerReply(200, data, null);
      return ServerReply(r.statusCode, data, switch (r.statusCode) {
        401 => 'আবার Google দিয়ে লগইন করুন',
        404 => 'খুঁজে পাওয়া গেল না',
        409 => 'এটা আর খোলা নেই',
        413 => 'ফাইলটা অনেক বড় — ৫ MB পর্যন্ত দেওয়া যায়',
        415 => 'শুধু ছবি বা PDF দেওয়া যায়',
        429 => 'আজ অনেকবার হয়ে গেছে — পরে আবার চেষ্টা করুন',
        _ => 'হয়নি (${r.statusCode}) — আবার চেষ্টা করুন',
      });
    } catch (_) {
      return const ServerReply(0, {}, 'ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন');
    }
  }
}

/// What our server answered: [error] is null when it worked.
class ServerReply {
  const ServerReply(this.status, this.data, this.error);
  final int status;
  final Map<String, dynamic> data;
  final String? error;
  bool get ok => error == null;
}
