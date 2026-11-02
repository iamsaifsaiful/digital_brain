import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// The server answered "no such route": a wrong login, or the session is
/// gone (logged out, turned off, password changed). The server answers
/// like this on purpose so nobody can tell it is there.
class ApiDenied implements Exception {
  const ApiDenied();
}

/// No internet, or the server did not answer.
class ApiOffline implements Exception {
  const ApiOffline();
}

class ApiError implements Exception {
  const ApiError(this.status, this.code);
  final int status;
  final String code;
  @override
  String toString() => 'ApiError($status, $code)';
}

/// The app's server. Its address is built into the APK (hidden) and is
/// never shown in the app.
abstract class Api {
  String? token;
  bool get configured;
  Future<Map<String, Object?>> get(String path, [Map<String, String> query = const {}]);
  Future<Map<String, Object?>> post(String path, Map<String, Object?> body);
}

/// The server address, kept in the APK only as [_x] XOR [_k] in hex so it
/// does not show up as text in the file. Set at build time
/// (--dart-define=RH_X=…, see tool/hide_server.py).
const _x = String.fromEnvironment('RH_X');
const _k = 'rH#9v!Lq7@xP2^mZ';

String serverBase() {
  if (_x.isEmpty || _x.length.isOdd) return '';
  final out = StringBuffer();
  for (var i = 0; i < _x.length ~/ 2; i++) {
    out.writeCharCode(int.parse(_x.substring(i * 2, i * 2 + 2), radix: 16) ^ _k.codeUnitAt(i % _k.length));
  }
  return out.toString();
}

/// For tool/hide_server.py's test: the same encoding.
String hideServer(String url) => [for (var i = 0; i < url.length; i++) (url.codeUnitAt(i) ^ _k.codeUnitAt(i % _k.length)).toRadixString(16).padLeft(2, '0')].join();

class HttpApi implements Api {
  HttpApi({String? base}) : _base = (base ?? serverBase()).replaceAll(RegExp(r'/+$'), '');
  final String _base;
  final _client = http.Client();

  @override
  String? token;

  @override
  bool get configured => _base.startsWith('https://') || _base.startsWith('http://');

  Uri _uri(String path, Map<String, String> query) => Uri.parse('$_base/').replace(queryParameters: {'rest_route': '/rbh/v1$path', ...query});

  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      };

  Future<Map<String, Object?>> _go(Future<http.Response> Function() f) async {
    if (!configured) throw const ApiOffline();
    http.Response r;
    try {
      r = await f().timeout(const Duration(seconds: 25));
    } on SocketException {
      throw const ApiOffline();
    } on TimeoutException {
      throw const ApiOffline();
    } on http.ClientException {
      throw const ApiOffline();
    } on PlatformException {
      throw const ApiOffline();
    }
    Object? body;
    try {
      body = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      body = null;
    }
    final map = body is Map ? body.cast<String, Object?>() : <String, Object?>{};
    if (r.statusCode == 404 && (map['code'] == 'rest_no_route' || map.isEmpty)) throw const ApiDenied();
    if (r.statusCode >= 400) throw ApiError(r.statusCode, '${map['code'] ?? ''}');
    return map;
  }

  @override
  Future<Map<String, Object?>> get(String path, [Map<String, String> query = const {}]) => _go(() => _client.get(_uri(path, query), headers: _headers));

  @override
  Future<Map<String, Object?>> post(String path, Map<String, Object?> body) => _go(() => _client.post(_uri(path, const {}), headers: _headers, body: jsonEncode(body)));
}
