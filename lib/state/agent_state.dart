import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/api.dart';
import '../services/errors.dart';
import 'hisab.dart';

/// One send as an agent sees it: taka only.
class AgentTxn {
  AgentTxn(Map<String, Object?> j)
      : id = '${j['id']}',
        no = (j['no'] as num?)?.toInt() ?? 0,
        number = '${j['number'] ?? ''}',
        method = '${j['method'] ?? 'bkash'}',
        kind = '${j['kind'] ?? 'send'}',
        operator = '${j['operator'] ?? ''}',
        pack = '${j['pack'] ?? ''}',
        taka = (j['taka'] as num?)?.toDouble() ?? 0,
        fee = (j['fee'] as num?)?.toDouble() ?? 0,
        commission = (j['commission'] as num?)?.toDouble() ?? 0,
        status = '${j['status'] ?? 'pending'}',
        trxId = '${j['trxId'] ?? ''}',
        reply = '${j['agentReply'] ?? ''}',
        at = DateTime.tryParse('${j['at']}') ?? DateTime(2000),
        sentAt = DateTime.tryParse('${j['sentAt']}'),
        paid = j['paid'] == true,
        fault = j['fault'] == null ? null : '${j['fault']}',
        faultNote = '${j['faultNote'] ?? ''}';
  final String id;
  final int no;
  final String number;
  final String method;
  final String kind;
  final String operator;
  final String pack;
  final double taka;
  final double fee;
  final double commission;
  final String status;
  final String trxId;
  final String reply;
  final DateTime at;
  final DateTime? sentAt;
  final bool paid;
  final String? fault;
  final String faultNote;

  double get total => taka + fee;
  bool get pending => status == 'pending';
  bool get cancelled => status == 'cancelled';
  bool get topUp => kind == 'recharge' || kind == 'mb';
}

class AgentPay {
  AgentPay(Map<String, Object?> j)
      : id = '${j['id']}',
        taka = (j['taka'] as num?)?.toDouble() ?? 0,
        at = DateTime.tryParse('${j['at']}') ?? DateTime(2000),
        way = '${j['way'] ?? ''}',
        ref = '${j['ref'] ?? ''}',
        fromAccount = '${j['fromAccount'] ?? ''}',
        note = '${j['note'] ?? ''}',
        receipt = j['receipt'] == null ? null : '${j['receipt']}',
        count = (j['count'] as num?)?.toInt() ?? 0;
  final String id;
  final double taka;
  final DateTime at;
  final String way;
  final String ref;
  final String fromAccount;
  final String note;
  final String? receipt;
  final int count;
}

class ServerNote {
  ServerNote(Map<String, Object?> j)
      : kind = '${j['kind'] ?? ''}',
        title = '${j['title'] ?? ''}',
        body = '${j['body'] ?? ''}',
        ref = '${j['ref'] ?? ''}',
        at = (DateTime.tryParse('${j['at']}') ?? DateTime(2000)).toLocal(),
        read = j['read'] == true;
  final String kind;
  final String title;
  final String body;
  final String ref;
  final DateTime at;
  final bool read;
}

/// The agent's side of the app: their sends, payments and notifications,
/// fetched from the server.
class AgentState extends ChangeNotifier {
  AgentState(this.h);
  final Hisab h;

  Api get api => h.s.api;

  String name = '';

  /// The main admin, named in the agent's screens.
  String owner = 'মূল এডমিন';
  double commission = 0;
  double owed = 0;
  List<AgentTxn> txns = [];
  List<AgentPay> payments = [];
  List<ServerNote> notes = [];
  int unread = 0;
  bool loading = false;
  Object? error;
  DateTime? at;
  final _photos = <String, Uint8List>{};

  List<AgentTxn> get waiting => txns.where((t) => t.pending).toList()..sort((a, b) => a.at.compareTo(b.at));

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    try {
      final f = await api.get('/agent/feed');
      final a = ((f['agent'] as Map?) ?? const {}).cast<String, Object?>();
      name = '${a['name'] ?? h.session?.name ?? ''}';
      commission = (a['commission'] as num?)?.toDouble() ?? 0;
      final o = '${f['owner'] ?? ''}'.trim();
      if (o.isNotEmpty) owner = o;
      owed = (f['owed'] as num?)?.toDouble() ?? 0;
      txns = [for (final t in ((f['txns'] as List?) ?? const []).cast<Map>()) AgentTxn(t.cast<String, Object?>())];
      payments = [for (final p in ((f['payments'] as List?) ?? const []).cast<Map>()) AgentPay(p.cast<String, Object?>())];
      unread = (f['unread'] as num?)?.toInt() ?? 0;
      error = null;
      at = DateTime.now();
      await ErrorLog.flush(api);
    } on ApiDenied {
      await h.logout();
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadNotes() async {
    try {
      final r = await api.get('/notes');
      notes = [for (final n in ((r['notes'] as List?) ?? const []).cast<Map>()) ServerNote(n.cast<String, Object?>())];
      notifyListeners();
      if (notes.any((n) => !n.read)) {
        await api.post('/notes/read', {});
        unread = 0;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// "পাঠিয়েছি": last 3 digits of the number it went from, and/or a TrxID.
  Future<void> sent(AgentTxn t, {String tail = '', String trxId = ''}) async {
    await api.post('/agent/sent', {'id': t.id, 'tail': tail, 'trxId': trxId});
    await refresh();
  }

  Future<void> problem(AgentTxn t, String note) async {
    await api.post('/agent/problem', {'id': t.id, 'note': note});
  }

  Future<void> changePassword(String old, String now) async {
    await api.post('/password', {'old': old, 'new': now});
  }

  Future<Uint8List?> receipt(String pid) async {
    final hit = _photos[pid];
    if (hit != null) return hit;
    try {
      final r = await api.get('/photo', {'pid': pid});
      return _photos[pid] = base64Decode('${r['data']}');
    } catch (_) {
      return null;
    }
  }
}
