import 'dart:convert';

import 'package:riyal_hisab/services/api.dart';

/// The server (plugin) in memory, for tests: the same answers for the
/// routes the app uses. The real plugin is checked in server/test/e2e.php.
class FakeServer {
  final users = <Map<String, Object?>>[];
  final sessions = <String, int>{};
  final records = <String, Map<String, Object?>>{}; // kind:rid -> {kind, rid, rev, data}
  final photos = <String, String>{};
  final notes = <Map<String, Object?>>[];
  int rev = 0;
  final serials = <String, int>{};
  final errors = <Map<String, Object?>>[];
  bool offline = false;

  void addUser(String role, String name, String login, String password, {String agentRid = '', List<String>? perms}) {
    users.add({'id': users.length + 1, 'role': role, 'name': name, 'login': login, 'password': password, 'agent_rid': agentRid, 'status': 'active', 'perms': perms});
  }

  static const allPerms = ['send', 'deposit', 'edit', 'customers', 'loss', 'agent_pay', 'agents', 'expense', 'reports', 'users', 'settings'];

  Map<String, Object?> public(Map<String, Object?> u) => {
        'id': u['id'],
        'role': u['role'],
        'name': u['name'],
        'login': u['login'],
        'agent_rid': u['agent_rid'],
        'status': u['status'],
        'perms': u['role'] == 'owner' ? allPerms : (u['role'] == 'agent' ? <String>[] : (u['perms'] ?? allPerms)),
        'last_seen': null,
      };

  Api api() => _FakeApi(this);

  Map<String, Object?>? one(String kind, String rid) => records['$kind:$rid']?['data'] as Map<String, Object?>?;

  void put(String kind, String rid, Map<String, Object?> data) {
    final old = one(kind, rid);
    if (kind == 'txn' && old != null && old['status'] == 'sent' && data['status'] == 'pending') {
      for (final f in ['status', 'trxId', 'agentReply', 'replyTail', 'sentAt']) {
        data[f] = old[f];
      }
    }
    if (old != null && jsonEncode(old) == jsonEncode(data)) return;
    records['$kind:$rid'] = {'kind': kind, 'rid': rid, 'rev': ++rev, 'data': data};
    if (kind == 'txn') {
      final agent = '${data['agentId']}';
      if (old == null && data['status'] == 'pending') _noteAgent(agent, 'new', 'নতুন অনুরোধ #${data['no']}');
      if (old != null && old['status'] != 'cancelled' && data['status'] == 'cancelled') _noteAgent(agent, 'cancel', 'বাতিল #${data['no']}');
    }
    if (kind == 'payment' && old == null) _noteAgent('${data['agentId']}', 'paid', 'টাকা পেয়েছেন');
  }

  void _noteAgent(String agentRid, String kind, String title) {
    for (final u in users.where((u) => u['role'] == 'agent' && u['agent_rid'] == agentRid)) {
      notes.add({'user': u['id'], 'kind': kind, 'title': title, 'body': '', 'ref': '', 'at': DateTime.now().toUtc().toIso8601String(), 'read': false});
    }
  }
}

class _FakeApi implements Api {
  _FakeApi(this.s);
  final FakeServer s;

  @override
  String? token;

  @override
  bool get configured => true;

  Map<String, Object?>? get _me {
    final id = s.sessions[token];
    if (id == null) return null;
    final u = s.users.firstWhere((u) => u['id'] == id);
    return u['status'] == 'active' ? u : null;
  }

  Never _denied() => throw const ApiDenied();

  @override
  Future<Map<String, Object?>> get(String path, [Map<String, String> query = const {}]) async {
    if (s.offline) throw const ApiOffline();
    final u = _me ?? _denied();
    final admin = u['role'] != 'agent';
    switch (path) {
      case '/me':
        return {
          'user': s.public(u),
          'firebase': {'appId': '1:2:android:3', 'apiKey': 'k', 'senderId': '2', 'projectId': 'p'}
        };
      case '/pull':
        if (!admin) _denied();
        final since = int.parse(query['since'] ?? '0');
        final list = s.records.values.where((r) => (r['rev'] as int) > since).toList()..sort((a, b) => (a['rev'] as int).compareTo(b['rev'] as int));
        final page = list.take(500).toList();
        return {
          'records': [for (final r in page) jsonDecode(jsonEncode(r))],
          'rev': page.isEmpty ? since : page.last['rev'],
          'more': list.length > 500,
        };
      case '/photo':
        return {'data': s.photos[query['pid']] ?? (throw const ApiError(404, 'none'))};
      case '/users':
        return {
          'users': [for (final x in s.users) s.public(x)]
        };
      case '/notes':
        return {
          'notes': [for (final n in s.notes.reversed.where((n) => n['user'] == u['id'])) n]
        };
      case '/agent/feed':
        if (admin) _denied();
        final aid = u['agent_rid'];
        final txns = [
          for (final r in s.records.values.where((r) => r['kind'] == 'txn' && (r['data'] as Map)['agentId'] == aid))
            {
              for (final k in ['id', 'no', 'number', 'method', 'kind', 'operator', 'pack', 'taka', 'fee', 'status', 'trxId', 'agentReply', 'at', 'sentAt', 'fault', 'faultNote'])
                k: (r['data'] as Map)[k],
              'paid': (r['data'] as Map)['agentPaymentId'] != null,
              'commission': 0,
            }
        ];
        var owed = 0.0;
        for (final t in txns) {
          if (t['status'] != 'cancelled') owed += (t['taka'] as num) + ((t['fee'] as num?) ?? 0);
        }
        final pays = [
          for (final r in s.records.values.where((r) => r['kind'] == 'payment' && (r['data'] as Map)['agentId'] == aid))
            {...(r['data'] as Map), 'count': ((r['data'] as Map)['txnIds'] as List?)?.length ?? 0},
        ];
        for (final p in pays) {
          owed -= p['taka'] as num;
        }
        return {
          'agent': {'name': u['name'], 'commission': 0},
          'owed': owed,
          'txns': txns,
          'payments': pays,
          'unread': s.notes.where((n) => n['user'] == u['id'] && n['read'] != true).length,
        };
    }
    throw ApiError(404, 'rest_no_route $path');
  }

  @override
  Future<Map<String, Object?>> post(String path, Map<String, Object?> body) async {
    if (s.offline) throw const ApiOffline();
    if (path == '/login') {
      final u = s.users.where((u) => u['login'] == body['login'] && u['password'] == body['password'] && u['status'] == 'active').firstOrNull ?? _denied();
      final tok = List.filled(64, '${s.sessions.length % 10}').join();
      s.sessions[tok] = u['id'] as int;
      return {'ok': true, 'token': tok, 'user': s.public(u), 'firebase': null};
    }
    final u = _me ?? _denied();
    switch (path) {
      case '/logout':
        s.sessions.remove(token);
        return {'ok': true};
      case '/device':
        return {'ok': true};
      case '/push':
        for (final r in (body['records'] as List).cast<Map>()) {
          s.put('${r['kind']}', '${r['rid']}', jsonDecode(jsonEncode(r['data'])) as Map<String, Object?>);
        }
        return {'ok': true};
      case '/reserve':
        final ym = '${body['ym']}';
        return {
          'numbers': [for (var i = 0; i < ((body['count'] as num?)?.toInt() ?? 1); i++) int.parse(ym) * 10000 + (s.serials[ym] = (s.serials[ym] ?? 0) + 1)],
        };
      case '/errors':
        s.errors.addAll((body['errors'] as List).cast<Map<String, Object?>>());
        return {'ok': true};
      case '/photo':
        s.photos['${body['pid']}'] = '${body['data']}';
        return {'ok': true};
      case '/users':
        s.addUser('${body['role']}', '${body['name']}', '${body['login']}', '${body['password']}', agentRid: '${body['agent_rid'] ?? ''}', perms: (body['perms'] as List?)?.cast<String>());
        return {'ok': true, 'user': s.public(s.users.last)};
      case '/users/update':
        final x = s.users.firstWhere((x) => x['id'] == body['id']);
        if (body['status'] != null) x['status'] = body['status'];
        if (body['perms'] != null) x['perms'] = (body['perms'] as List).cast<String>();
        return {'ok': true};
      case '/notes/read':
        for (final n in s.notes.where((n) => n['user'] == u['id'])) {
          n['read'] = true;
        }
        return {'ok': true};
      case '/agent/sent':
        final t = s.one('txn', '${body['id']}');
        if (t == null || t['agentId'] != u['agent_rid']) _denied();
        final tail = '${body['tail'] ?? ''}';
        final next = {
          ...t,
          'status': 'sent',
          if (tail.isNotEmpty) 'agentReply': '${t['no']} ${((t['taka'] as num) + ((t['fee'] as num?) ?? 0)).round()}-$tail',
          if (tail.isNotEmpty) 'replyTail': tail,
          'trxId': '${body['trxId'] ?? ''}'.isEmpty ? t['trxId'] : body['trxId']
        };
        s.put('txn', '${t['id']}', next);
        final lid = 's${s.rev}';
        s.put('log', lid, {
          'id': lid,
          'at': DateTime.now().toIso8601String(),
          'kind': 'agent',
          'title': 'এজেন্ট পাঠিয়েছেন · #${t['no']}',
          'detail': 'উত্তর: ${next['agentReply']}',
          'who': u['name'],
          'ref': t['id']
        });
        return {'ok': true};
      case '/agent/problem':
        return {'ok': true};
      case '/password':
        if (u['password'] != body['old']) throw const ApiError(403, 'wrong');
        u['password'] = body['new'];
        return {'ok': true};
    }
    throw ApiError(404, 'rest_no_route $path');
  }
}
