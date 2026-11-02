import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' show sha1;
import 'package:flutter/foundation.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../services/api.dart';
import '../services/device.dart';
import '../services/errors.dart';
import '../services/lock.dart';
import '../services/push.dart';
import '../services/reminders.dart';
import '../services/store.dart';

class Services {
  Services({required this.store, required this.lock, required this.device, Reminders? reminders, Api? api, Push? push, DateTime Function()? clock})
      : now = clock ?? DateTime.now,
        reminders = reminders ?? FakeReminders(),
        api = api ?? HttpApi(),
        push = push ?? FakePush();
  final DataStore store;
  final LockService lock;
  final Device device;
  final Reminders reminders;
  final Api api;
  final Push push;
  final DateTime Function() now;
}

/// The agent's reply found on the clipboard ("10000-667" and/or a TrxID)
/// and the waiting sends it may belong to.
class ClipTrx {
  ClipTrx(this.reply, this.matches, this.text);
  final AgentReply reply;
  final List<Txn> matches;
  final String text;

  String get trxId => reply.trxIds.isEmpty ? '' : reply.trxIds.first;

  /// Short form for the screen: "10000-667 · BJ7K9X2Q1M".
  String get shown => [
        if (reply.no != null) '#${reply.no}',
        if (reply.amount != null && reply.tail.isNotEmpty) '${groupEn(reply.amount!)}-${reply.tail}' else if (reply.amount != null) groupEn(reply.amount!),
        if (trxId.isNotEmpty) trxId,
      ].join(' · ');
}

/// Who is signed in to the server on this phone.
class Session {
  Session({required this.token, required this.id, required this.role, required this.name, required this.login, this.agentRid = '', this.perms = const []});
  final String token;
  final int id;

  /// owner (main admin), admin or agent.
  final String role;
  final String name;
  final String login;
  final String agentRid;

  /// What this admin may do (the main admin: everything).
  final List<String> perms;

  bool can(String p) => isOwner || perms.contains(p);

  bool get isAgent => role == 'agent';
  bool get isOwner => role == 'owner';

  Map<String, Object?> toJson() => {'token': token, 'id': id, 'role': role, 'name': name, 'login': login, 'agent_rid': agentRid, 'perms': perms};
  factory Session.from(String token, Map<String, Object?> u) => Session(
        token: token,
        id: (u['id'] as num?)?.toInt() ?? 0,
        role: '${u['role'] ?? 'admin'}',
        name: '${u['name'] ?? ''}',
        login: '${u['login'] ?? ''}',
        agentRid: '${u['agent_rid'] ?? ''}',
        perms: [for (final p in (u['perms'] as List?) ?? const []) '$p'],
      );
}

/// The whole app's data and every change to it. Each change is saved at
/// once (encrypted) and written to the activity log.
class Hisab extends ChangeNotifier {
  Hisab(this.s);
  final Services s;

  AppData d = AppData();
  bool loaded = false;
  Object? loadError;

  final _photoCache = <String, Uint8List>{};
  final _rand = Random.secure();

  /// Signed in to the server (always, once past the login screen).
  Session? session;

  /// Sync state for the screen.
  bool syncing = false;
  DateTime? syncedAt;
  Object? syncError;

  DateTime get now => s.now();

  Future<void> load() async {
    try {
      d = await s.store.load();
      loadError = null;
    } catch (e) {
      loadError = e;
    }
    try {
      final raw = await s.lock.keys.read('session_v1');
      if (raw != null) {
        final j = (jsonDecode(raw) as Map).cast<String, Object?>();
        session = Session.from('${j['token']}', j);
        s.api.token = session!.token;
      }
    } catch (_) {
      session = null;
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    await s.store.save(d);
    _syncSoon();
  }

  // ------------------------------------------------------------- server

  /// Signs in. An admin's phone then gets the shared account; when the
  /// server has none yet, what is on this phone becomes the account.
  /// Throws [ApiDenied] (wrong login), [ApiOffline].
  Future<Session> login(String login, String password, {String device = ''}) async {
    final r = await s.api.post('/login', {'login': login.trim(), 'password': password, 'device': device});
    final ses = Session.from('${r['token']}', ((r['user'] as Map?) ?? const {}).cast<String, Object?>());
    s.api.token = ses.token;
    session = ses;
    await s.lock.keys.write('session_v1', jsonEncode(ses.toJson()));
    await s.reminders.askPermission();
    await _startPush(r['firebase']);
    await ErrorLog.flush(s.api);
    if (!ses.isAgent) {
      await _adoptServer();
      await s.store.save(d);
      await sync();
      // Only for a brand-new shop: the server had no owner's name yet.
      if (d.settings.ownerName.trim().isEmpty && ses.isOwner) {
        d.settings.ownerName = ses.name;
        await _save();
      }
    }
    notifyListeners();
    return ses;
  }

  Future<void> _startPush(Object? firebase) async {
    if (firebase is! Map) return;
    final tok = await s.push.start(firebase.cast<String, Object?>());
    if (tok == null) return;
    try {
      await s.api.post('/device', {'token': tok});
    } catch (_) {}
  }

  /// After opening the app: Firebase may have been set on the server since.
  /// The signed-in admin's own name (for the main admin, also the name
  /// the account goes by and receipts are signed with).
  Future<void> renameMe(String name) async {
    final n = name.trim();
    if (n.isEmpty) return;
    if (session != null) {
      await s.api.post('/me/name', {'name': n});
      await refreshSession();
    }
    if (isOwner) {
      final old = d.settings.ownerName;
      d.settings.ownerName = n;
      await saveSettings('মূল এডমিনের নাম $old → $n');
    }
  }

  Future<void> changeMyPassword(String old, String now) => s.api.post('/password', {'old': old, 'new': now});

  Future<void> refreshSession() async {
    if (session == null) return;
    try {
      final r = await s.api.get('/me');
      final u = r['user'];
      if (u is Map) {
        session = Session.from(session!.token, u.cast<String, Object?>());
        await s.lock.keys.write('session_v1', jsonEncode(session!.toJson()));
        notifyListeners();
      }
      await _startPush(r['firebase']);
    } on ApiDenied {
      await _signedOut();
    } catch (_) {}
  }

  /// A phone that kept its own account before the server: if the server
  /// already has an account, this phone's is put aside (kept, encrypted)
  /// and the server's is taken; if the server is empty, this phone's is
  /// sent up.
  Future<void> _adoptServer() async {
    if (d.sync.rev > 0) return;
    final hasLocal = d.txns.isNotEmpty || d.customers.isNotEmpty;
    if (!hasLocal) return;
    final first = await s.api.get('/pull', {'since': '0'});
    if (((first['records'] as List?) ?? const []).isEmpty) return;
    await s.store.putAside(d);
    d = AppData();
    _log('sys', 'এই ফোনের আগের হিসাব আলাদা রাখা হলো', 'সার্ভারের হিসাব নেওয়া হলো');
  }

  /// Signs out on this phone. An admin's data stays on the server; this
  /// phone's copy is cleared.
  Future<void> logout() async {
    try {
      await s.api.post('/logout', {});
    } catch (_) {}
    await _signedOut();
  }

  Future<void> _signedOut() async {
    session = null;
    s.api.token = null;
    await s.lock.keys.delete('session_v1');
    d = AppData();
    _photoCache.clear();
    await s.store.save(d);
    notifyListeners();
  }

  Timer? _soon;
  void _syncSoon() {
    if (session == null || session!.isAgent) return;
    _soon?.cancel();
    _soon = Timer(const Duration(milliseconds: 700), () => sync());
  }

  static String _hash(Object? j) => sha1.convert(utf8.encode(jsonEncode(j))).toString();

  /// Every record that goes to the server: (kind, id, json).
  Iterable<(String, String, Map<String, Object?>)> _records() sync* {
    yield ('settings', 'main', d.settings.shared());
    for (final x in d.customers) {
      yield ('customer', x.id, x.toJson());
    }
    for (final x in d.agents) {
      yield ('agent', x.id, x.toJson());
    }
    for (final x in d.txns) {
      yield ('txn', x.id, x.toJson());
    }
    for (final x in d.deposits) {
      yield ('deposit', x.id, x.toJson());
    }
    for (final x in d.agentPayments) {
      yield ('payment', x.id, x.toJson());
    }
    for (final x in d.expenses) {
      yield ('expense', x.id, x.toJson());
    }
    for (final x in d.closes) {
      yield ('close', x.id, x.toJson());
    }
    for (final x in d.losses) {
      yield ('loss', x.id, x.toJson());
    }
    for (final x in d.handovers) {
      yield ('handover', x.id, x.toJson());
    }
    for (final x in d.adjusts) {
      yield ('adjust', x.id, x.toJson());
    }
    for (final x in d.log) {
      yield ('log', x.id, x.toJson());
    }
  }

  /// Puts a record from the server in place; returns its json as this
  /// phone now has it.
  Map<String, Object?>? _apply(String kind, String id, Map<String, Object?> j) {
    void put<T>(List<T> list, T x, String Function(T) idOf) {
      final i = list.indexWhere((e) => idOf(e) == id);
      if (i < 0) {
        list.add(x);
      } else {
        list[i] = x;
      }
    }

    switch (kind) {
      case 'settings':
        d.settings.applyShared(j);
        return d.settings.shared();
      case 'customer':
        final x = Customer.fromJson(j);
        put(d.customers, x, (e) => e.id);
        return x.toJson();
      case 'agent':
        final x = Agent.fromJson(j);
        put(d.agents, x, (e) => e.id);
        return x.toJson();
      case 'txn':
        final x = Txn.fromJson(j);
        put(d.txns, x, (e) => e.id);
        return x.toJson();
      case 'deposit':
        final x = Deposit.fromJson(j);
        put(d.deposits, x, (e) => e.id);
        return x.toJson();
      case 'payment':
        final x = AgentPayment.fromJson(j);
        put(d.agentPayments, x, (e) => e.id);
        return x.toJson();
      case 'expense':
        final x = Expense.fromJson(j);
        put(d.expenses, x, (e) => e.id);
        return x.toJson();
      case 'close':
        final x = DayClose.fromJson(j);
        put(d.closes, x, (e) => e.id);
        return x.toJson();
      case 'loss':
        final x = Loss.fromJson(j);
        put(d.losses, x, (e) => e.id);
        return x.toJson();
      case 'handover':
        final x = Handover.fromJson(j);
        put(d.handovers, x, (e) => e.id);
        return x.toJson();
      case 'adjust':
        final x = Adjust.fromJson(j);
        put(d.adjusts, x, (e) => e.id);
        return x.toJson();
      case 'log':
        final x = LogEntry.fromJson(j);
        put(d.log, x, (e) => e.id);
        return x.toJson();
    }
    return null;
  }

  Future<void>? _running;

  /// Sends what changed on this phone, then takes what changed elsewhere.
  Future<void> sync() {
    if (session == null || session!.isAgent) return Future.value();
    return _running ??= _sync().whenComplete(() => _running = null);
  }

  Future<void> _sync() async {
    syncing = true;
    notifyListeners();
    try {
      // Photos first, so other phones can show them.
      final pids = <String>{
        for (final c in d.customers)
          if (c.photo != null) c.photo!,
        for (final p in d.agentPayments)
          if (p.receipt != null) p.receipt!,
      }.difference(d.sync.photosUp);
      for (final pid in pids) {
        final b = await s.store.loadPhoto(pid);
        if (b == null) continue;
        await s.api.post('/photo', {'pid': pid, 'data': base64Encode(b)});
        d.sync.photosUp.add(pid);
      }
      final changedTxns = <Txn>[];
      Future<void> pull() async {
        var more = true;
        while (more) {
          final r = await s.api.get('/pull', {'since': '${d.sync.rev}'});
          for (final rec in ((r['records'] as List?) ?? const []).cast<Map>()) {
            final kind = '${rec['kind']}', id = '${rec['rid']}';
            final data = rec['data'];
            if (data is! Map) continue;
            final before = kind == 'txn' ? txnById(id)?.status : null;
            final applied = _apply(kind, id, data.cast<String, Object?>());
            if (applied != null) d.sync.hashes['$kind:$id'] = _hash(applied);
            if (kind == 'txn' && before == TxnStatus.pending && txnById(id)?.status == TxnStatus.sent) changedTxns.add(txnById(id)!);
          }
          d.sync.rev = (r['rev'] as num?)?.toInt() ?? d.sync.rev;
          more = r['more'] == true;
        }
      }

      // A phone new to the server takes the server's account first, so its
      // empty settings never overwrite the shop's.
      if (d.sync.rev == 0) await pull();
      final out = <Map<String, Object?>>[];
      final sentHashes = <String, String>{};
      for (final (kind, id, j) in _records()) {
        final h = _hash(j);
        if (d.sync.hashes['$kind:$id'] != h) {
          out.add({'kind': kind, 'rid': id, 'data': j});
          sentHashes['$kind:$id'] = h;
        }
      }
      for (var i = 0; i < out.length; i += 300) {
        await s.api.post('/push', {'records': out.sublist(i, min(i + 300, out.length))});
      }
      d.sync.hashes.addAll(sentHashes);
      await pull();
      d.log.sort((a, b) => a.at.compareTo(b.at));
      if (d.sync.numbersYm != yearMonth(now) || d.sync.numbers.length < 5) await _reserve();
      syncError = null;
      syncedAt = now;
      await s.store.save(d);
      await ErrorLog.flush(s.api);
    } on ApiDenied {
      await _signedOut();
    } on ApiOffline catch (e) {
      syncError = e;
    } catch (e, st) {
      syncError = e;
      ErrorLog.add(e, st, where: 'sync');
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  Future<void> _reserve() async {
    final ym = yearMonth(now);
    final r = await s.api.post('/reserve', {'count': 20, 'ym': ym});
    if (d.sync.numbersYm != ym) {
      // Last month's spare numbers are not used in a new month.
      d.sync.numbers.clear();
      d.sync.numbersYm = ym;
    }
    d.sync.numbers.addAll([for (final n in (r['numbers'] as List?) ?? const []) (n as num).toInt()]);
  }

  /// The next send number: from this phone's block (kept from the server,
  /// so it works for a while without internet).
  Future<int> _takeNumber() async {
    if (session == null) return _localNumber();
    if (d.sync.numbersYm != yearMonth(now)) {
      d.sync.numbers.clear();
      d.sync.numbersYm = yearMonth(now);
    }
    if (d.sync.numbers.isEmpty) {
      try {
        await _reserve();
      } catch (_) {
        throw const NoNumbers();
      }
    }
    if (d.sync.numbers.isEmpty) throw const NoNumbers();
    return d.sync.numbers.removeAt(0);
  }

  String newId() => List.generate(12, (_) => _rand.nextInt(16).toRadixString(16)).join();

  void _log(String kind, String title, String detail, {String who = 'me', String ref = ''}) {
    d.log.add(LogEntry(id: 'L${newId()}', at: now, kind: kind, title: title, detail: detail, who: who == 'me' && session != null ? session!.name : who, ref: ref));
  }

  /// Something the user did that changes nothing (app opened, backup made).
  Future<void> note(String kind, String title, String detail, {String who = 'me'}) async {
    _log(kind, title, detail, who: who);
    await _save();
  }

  /// The signed-in admin (0 and the owner's name without a server).
  int get meId => session?.id ?? 0;
  String get meName => session?.name ?? d.settings.ownerName;
  bool get isOwner => session == null || session!.isOwner;

  /// The main admin's name: what the whole account is called.
  String get ownerLabel => d.settings.ownerName.trim().isEmpty ? 'মূল এডমিন' : d.settings.ownerName.trim();

  /// Riyal that should be in my hand now.
  double get myCash => cashInHand(d, me: meId, owner: isOwner);

  /// What the signed-in admin may do. Without a server (tests): everything.
  bool can(String p) => session?.can(p) ?? true;

  bool get needsSetup => d.liveAgents.isEmpty || d.settings.ownerName.trim().isEmpty;

  /// The next send's number, for the preview before saving.
  int get nextNoPreview => session == null ? _localNumber() : (d.sync.numbers.isEmpty || d.sync.numbersYm != yearMonth(now) ? 0 : d.sync.numbers.first);

  /// Without a server: this month's next serial.
  int _localNumber() {
    final ym = yearMonth(now);
    var max = sendNumber(ym, 0);
    for (final t in d.txns) {
      if ('${t.no}'.startsWith(ym) && '${t.no}'.length == 8 && t.no > max) max = t.no;
    }
    return max + 1;
  }

  // ---------------------------------------------------------------- setup

  Future<void> setup({required String owner, required String agentName, required String agentWhatsapp, double commission = 0}) async {
    d.settings.ownerName = owner.trim();
    if (d.agents.isEmpty) {
      d.agents.add(Agent(id: newId(), name: agentName.trim(), whatsapp: agentWhatsapp.trim(), commissionPerThousand: commission, created: now));
    }
    _log('sys', 'অ্যাপ চালু হলো', 'মালিক: ${owner.trim()} · এজেন্ট: ${agentName.trim()}');
    await _save();
  }

  // ------------------------------------------------------------ customers

  List<Customer> searchCustomers(String q) {
    final t = en(q).trim().toLowerCase();
    final list = [...d.customers];
    list.sort((a, b) => lastActivity(b).compareTo(lastActivity(a)));
    if (t.isEmpty) return list;
    final digits = t.replaceAll(RegExp(r'[^0-9]'), '');
    final key = soundKey(t);
    return list.where((c) {
      if (c.name.toLowerCase().contains(t)) return true;
      // Typed in English, saved in Bangla (or the other way round).
      if (key.length >= 2 && soundKey(c.name).contains(key)) return true;
      if (digits.length >= 3) {
        if (en(c.phone).replaceAll(RegExp(r'[^0-9]'), '').contains(digits)) return true;
        if (c.recipients.any((r) => r.number.contains(digits))) return true;
      }
      return false;
    }).toList();
  }

  DateTime lastActivity(Customer c) {
    var t = c.created;
    for (final x in d.txns) {
      if (x.customerId == c.id && x.at.isAfter(t)) t = x.at;
    }
    for (final p in d.deposits) {
      if (p.customerId == c.id && p.at.isAfter(t)) t = p.at;
    }
    return t;
  }

  Future<Customer> addCustomer({required String name, required String phone, String area = '', Uint8List? photo}) async {
    final c = Customer(id: newId(), name: name.trim(), phone: phone.trim(), area: area.trim(), created: now);
    if (photo != null) {
      final pid = newId();
      await s.store.savePhoto(pid, photo);
      _photoCache[pid] = photo;
      c.photo = pid;
    }
    d.customers.add(c);
    _log('cust', 'নতুন গ্রাহক প্রোফাইল', '${c.name} · ${bn(c.phone)}${photo != null ? ' · ছবিসহ' : ''}', ref: c.id);
    await _save();
    return c;
  }

  /// Saves edits made to [c] (the screen changed its fields).
  Future<void> customerChanged(Customer c, String what) async {
    _log('cust', 'গ্রাহকের প্রোফাইল বদল', '${c.name} · $what', ref: c.id);
    await _save();
  }

  Future<void> setPhoto(Customer c, Uint8List bytes) async {
    final pid = newId();
    await s.store.savePhoto(pid, bytes);
    _photoCache[pid] = bytes;
    c.photo = pid;
    _log('cust', 'গ্রাহকের ছবি', c.name, ref: c.id);
    await _save();
  }

  /// The day the customer said they would pay; the phone rings then.
  Future<void> setPromise(Customer c, DateTime at, String note) async {
    c
      ..promiseAt = at
      ..promiseNote = note.trim();
    final due = customerDue(d, c.id);
    await s.reminders.schedule(c.id, at, 'তাগাদা: ${c.name}', 'আজ ${due > 0 ? sar(due) : 'বকেয়া'} দেওয়ার কথা${c.promiseNote.isEmpty ? '' : ' · ${c.promiseNote}'}');
    _log('cust', 'বকেয়া ফেরতের তারিখ', '${c.name} · ${dateShort(at)}, ${timeText(at)}${c.promiseNote.isEmpty ? '' : ' · ${c.promiseNote}'}', ref: c.id);
    await _save();
  }

  Future<void> clearPromise(Customer c, {String why = 'মুছে দেওয়া হলো'}) async {
    if (c.promiseAt == null) return;
    c.promiseAt = null;
    c.promiseNote = '';
    await s.reminders.cancel(c.id);
    _log('cust', 'তাগাদার রিমাইন্ডার বন্ধ', '${c.name} · $why', ref: c.id);
    await _save();
  }

  /// Customers whose promised day has come and who still owe.
  List<Customer> get promisesDue => [
        for (final c in d.customers)
          if (c.promiseAt != null && !c.promiseAt!.isAfter(now) && customerDue(d, c.id) > 0) c,
      ];

  /// Puts back the scheduled reminders (after a restore or a new install).
  Future<void> rescheduleAll() async {
    for (final c in d.customers) {
      final at = c.promiseAt;
      if (at != null && at.isAfter(now)) {
        await s.reminders.schedule(c.id, at, 'তাগাদা: ${c.name}', 'আজ বকেয়া দেওয়ার কথা${c.promiseNote.isEmpty ? '' : ' · ${c.promiseNote}'}');
      }
    }
  }

  /// Riyal the customer owes that will not come back.
  Future<Loss> addLoss(Customer c, double amount, String note) async {
    final before = customerDue(d, c.id);
    final l = Loss(id: newId(), customerId: c.id, sarAmount: amount, at: now, note: note.trim(), by: meId, byName: meName);
    d.losses.add(l);
    _log('recv', 'লস ধরা হলো (আদায় হবে না)', '${c.name} · ${sar(amount)} · বকেয়া ${sar(before)} → ${sar(customerDue(d, c.id))}${l.note.isEmpty ? '' : ' · ${l.note}'}', ref: c.id);
    if (customerDue(d, c.id) <= 0 && c.promiseAt != null) {
      c.promiseAt = null;
      await s.reminders.cancel(c.id);
    }
    await _save();
    return l;
  }

  Future<Uint8List?> photo(String id) async {
    final hit = _photoCache[id];
    if (hit != null) return hit;
    var b = await s.store.loadPhoto(id);
    if (b == null && session != null) {
      // Taken on another admin's phone: fetched once, then kept here.
      try {
        final r = await s.api.get('/photo', {'pid': id});
        b = base64Decode('${r['data']}');
        await s.store.savePhoto(id, b);
        d.sync.photosUp.add(id);
      } catch (_) {
        b = null;
      }
    }
    if (b != null) _photoCache[id] = b;
    return b;
  }

  /// Keeps the number among the customer's saved recipients.
  void rememberRecipient(Customer c, String label, String number, Method m) {
    for (final r in c.recipients) {
      if (r.number == number) {
        if (label.trim().isNotEmpty) r.label = label.trim();
        r.method = m;
        return;
      }
    }
    c.recipients.add(Recipient(id: newId(), label: label.trim(), number: number, method: m));
  }

  // --------------------------------------------------------------- agents

  Future<Agent> addAgent(String name, String whatsapp, double commission) async {
    final a = Agent(id: newId(), name: name.trim(), whatsapp: whatsapp.trim(), commissionPerThousand: commission, created: now);
    d.agents.add(a);
    _log('agent', 'নতুন এজেন্ট', '${a.name} · হোয়াটসঅ্যাপ ${bn(a.whatsapp)}', ref: a.id);
    await _save();
    return a;
  }

  Future<void> updateAgent(Agent a, {required String name, required String whatsapp, required double commission}) async {
    final changes = <String>[
      if (a.name != name.trim()) 'নাম ${a.name} → ${name.trim()}',
      if (a.whatsapp != whatsapp.trim()) 'নম্বর ${bn(a.whatsapp)} → ${bn(whatsapp.trim())}',
      if (a.commissionPerThousand != commission) 'কমিশন ${bnNum(a.commissionPerThousand, decimals: 2)} → ${bnNum(commission, decimals: 2)}/হাজার',
    ];
    a
      ..name = name.trim()
      ..whatsapp = whatsapp.trim()
      ..commissionPerThousand = commission;
    if (changes.isEmpty) return;
    _log('edit', 'এজেন্টের তথ্য বদল', changes.join(' · '), ref: a.id);
    await _save();
  }

  /// WhatsApp or the app: how this agent gets the requests.
  /// The main admin deletes an agent: gone from every list, its logins
  /// removed on the server, its old records keep its name.
  Future<void> deleteAgent(Agent a) async {
    if (!isOwner) throw StateError('main admin only');
    if (d.liveAgents.length <= 1) throw StateError('last agent');
    a.deleted = true;
    _log('agent', 'এজেন্ট ডিলিট', '${a.name} · ${bn(a.whatsapp)} · তখন পাওনা ${taka(agentOwed(d, a.id))}', who: meName, ref: a.id);
    await _save();
  }

  Future<void> setAgentChannel(Agent a, String channel) async {
    if (a.channel == channel) return;
    a.channel = channel;
    _log('agent', 'এজেন্টের যোগাযোগ বদল', '${a.name} · ${channel == 'app' ? 'এখন থেকে অ্যাপে (নোটিফিকেশন)' : 'এখন থেকে হোয়াটসঅ্যাপে'}', ref: a.id);
    await _save();
  }

  // ----------------------------------------------------------------- txns

  List<Txn> get waiting => d.txns.where((t) => t.status == TxnStatus.pending).toList()..sort((a, b) => a.at.compareTo(b.at));

  Txn? txnById(String id) {
    for (final t in d.txns) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// A new send. [t] comes from the entry screen without number or id.
  Future<Txn> addTxn(Txn draft) async {
    final no = await _takeNumber();
    final t = Txn.fromJson({...draft.toJson(), 'id': newId(), 'no': no, 'at': now.toIso8601String(), 'by': meId, 'byName': meName});
    d.txns.add(t);
    final c = customerById(d, t.customerId);
    if (c != null) rememberRecipient(c, t.recipientLabel, t.number, t.method);
    final dueAfter = customerDue(d, t.customerId);
    _log(
      'txn',
      'নতুন লেনদেন · #${bn('${t.no}')}',
      '${customerNameOf(d, t)} → ${t.recipientLabel.isEmpty ? bdShow(t.number) : t.recipientLabel} · ${serviceName(t)}${t.kind == Kind.mb && t.pack.isNotEmpty ? ' (${t.pack})' : ''} · '
          '${sar(t.sarAmount)} × ${rateText(t.rate)} = ${taka(t.taka)}${t.fee > 0 ? ' + খরচ ${taka(t.fee)}' : ''} · '
          '${t.pay.bnName}${t.pay == Pay.partial ? ' (${sar(t.sarPaid)})' : ''} · বকেয়া দাঁড়াল ${sar(dueAfter > 0 ? dueAfter : 0)}',
      ref: t.id,
    );
    await _save();
    return t;
  }

  /// Saves a changed copy of [old]; the log keeps before → after.
  Future<List<String>> editTxn(Txn old, Txn changed) async {
    // Once the agent has sent it, a send is never changed: mistakes go to
    // "অতিরিক্ত হিসাব" (addAdjust).
    if (old.status != TxnStatus.pending) throw StateError('already sent');
    final diffs = <String>[
      if (old.sarAmount != changed.sarAmount) 'রিয়াল ${sar(old.sarAmount)} → ${sar(changed.sarAmount)}',
      if (old.rate != changed.rate) 'রেট ${rateText(old.rate)} → ${rateText(changed.rate)}',
      if (old.taka != changed.taka) 'টাকা ${taka(old.taka)} → ${taka(changed.taka)}',
      if (old.fee != changed.fee) 'খরচ ${taka(old.fee)} → ${taka(changed.fee)}',
      if (old.number != changed.number) 'নম্বর ${bdShow(old.number)} → ${bdShow(changed.number)}',
      if (old.recipientLabel != changed.recipientLabel) 'প্রাপক ${old.recipientLabel} → ${changed.recipientLabel}',
      if (old.method != changed.method) 'মাধ্যম ${old.method.bnName} → ${changed.method.bnName}',
      if (old.kind != changed.kind) 'ধরন ${old.kind.bnName} → ${changed.kind.bnName}',
      if (old.pay != changed.pay || old.sarPaid != changed.sarPaid) 'পরিশোধ ${old.pay.bnName} ${sar(old.sarPaid)} → ${changed.pay.bnName} ${sar(changed.sarPaid)}',
      if (old.operator != changed.operator) 'অপারেটর ${old.operator} → ${changed.operator}',
      if (old.pack != changed.pack) 'প্যাক ${old.pack} → ${changed.pack}',
      if (old.agentId != changed.agentId) 'এজেন্ট ${agentById(d, old.agentId)?.name ?? ''} → ${agentById(d, changed.agentId)?.name ?? ''}',
    ];
    if (diffs.isEmpty) return diffs;
    final i = d.txns.indexWhere((t) => t.id == old.id);
    if (i < 0) return const [];
    // A change in what the agent sends: the WhatsApp agent must be told,
    // and the send shows it until the admin says the message went.
    final agentSide = old.number != changed.number ||
        old.taka != changed.taka ||
        old.fee != changed.fee ||
        old.method != changed.method ||
        old.kind != changed.kind ||
        old.agentId != changed.agentId ||
        old.operator != changed.operator ||
        old.pack != changed.pack;
    final ag = agentById(d, changed.agentId);
    if (agentSide && ag != null && !ag.usesApp) changed.changeNotice = 'pending';
    d.txns[i] = changed;
    final c = customerById(d, changed.customerId);
    if (c != null) rememberRecipient(c, changed.recipientLabel, changed.number, changed.method);
    _log('edit', 'লেনদেন সম্পাদনা · #${bn('${old.no}')}', diffs.join(' · '), ref: old.id);
    await _save();
    return diffs;
  }

  /// Only before the agent has sent it.
  Future<void> cancelTxn(Txn t, String reason) async {
    if (t.status == TxnStatus.sent) throw StateError('already sent');
    t.status = TxnStatus.cancelled;
    _log('edit', 'লেনদেন বাতিল · #${bn('${t.no}')}', '${taka(t.agentTaka)} · ${bdShow(t.number)}${reason.trim().isEmpty ? '' : ' · কারণ: ${reason.trim()}'}', ref: t.id);
    await _save();
  }

  /// The agent sent it: TrxID noted, status "পৌঁছেছে".
  Future<void> setTrxId(Txn t, String trxId, {String who = 'me', String from = 'manual'}) => markSent(t, trxId: trxId, who: who, from: from);

  /// The agent's reply arrived: "10000-667" and/or a TrxID.
  /// [from]: 'auto' (filled from the copied reply) or 'manual' (typed).
  Future<void> markSent(Txn t, {String trxId = '', String reply = '', String tail = '', String who = 'me', String from = 'manual'}) async {
    final wasSent = t.status == TxnStatus.sent;
    final oldId = t.trxId;
    if (trxId.trim().isNotEmpty) t.trxId = trxId.trim().toUpperCase();
    if (reply.trim().isNotEmpty) t.agentReply = reply.trim();
    if (tail.isNotEmpty) t.replyTail = tail;
    t.status = TxnStatus.sent;
    t.sentAt ??= now;
    t.replyFrom = from == 'auto' ? 'auto' : 'manual';
    final parts = <String>[
      if (reply.trim().isNotEmpty) 'উত্তর: ${reply.trim()}',
      if (trxId.trim().isNotEmpty) 'TrxID ${oldId.isNotEmpty && oldId != t.trxId ? '$oldId → ' : ''}${t.trxId}',
      from == 'auto' ? 'কপি করা উত্তর থেকে অটো বসানো (${session?.name ?? 'আপনি'} নিশ্চিত করলেন)' : 'এডমিন নিজে লিখে বসালেন (${session?.name ?? 'আপনি'})',
      if (!wasSent) 'লেনদেন "পৌঁছেছে"',
    ];
    _log('agent', wasSent ? 'এজেন্টের উত্তর বদল · #${bn('${t.no}')}' : 'এজেন্ট পাঠিয়েছেন · #${bn('${t.no}')}', parts.join(' · '), who: who, ref: t.id);
    await _save();
  }

  /// The money went to a wrong number: whose mistake it was.
  Future<void> markFault(Txn t, Fault? fault, String note) async {
    final old = t.fault;
    t.fault = fault;
    t.faultNote = fault == null ? '' : note.trim();
    _log(
      'edit',
      fault == null ? 'ভুল নম্বরের চিহ্ন তোলা · #${bn('${t.no}')}' : 'ভুল নম্বরে গেছে · #${bn('${t.no}')}',
      fault == null ? 'আগে: ${old?.bnName ?? ''}' : '${fault.bnName}${t.faultNote.isEmpty ? '' : ' · ${t.faultNote}'} · ${bdShow(t.number)} · ${taka(t.agentTaka)}',
      ref: t.id,
    );
    await _save();
  }

  Future<void> logMessage(Txn t, String what) async {
    _log('agent', '$what · #${bn('${t.no}')}', '${agentById(d, t.agentId)?.name ?? ''} · ${taka(t.agentTaka)} · ${t.method.bnName} ${bdShow(t.number)}', ref: t.id);
    await _save();
  }

  /// A TrxID on the clipboard that is not used yet, with the waiting sends
  /// it may belong to.
  Future<ClipTrx?> clipboardTrx() async {
    if (waiting.isEmpty) return null;
    final text = await s.device.clipboard();
    if (text == null || text.trim().isEmpty || text.length > 600) return null;
    final r = parseReply(text, nos: [for (final t in waiting) t.no]);
    if (!r.useful) return null;
    final usedIds = {for (final t in d.txns) t.trxId};
    final usedReplies = {for (final t in d.txns) t.agentReply};
    final freshIds = r.trxIds.where((i) => !usedIds.contains(i)).toList();
    if (freshIds.isEmpty && (r.tail.isEmpty || usedReplies.contains(text.trim()))) return null;
    return ClipTrx(AgentReply(no: r.no, amount: r.amount, tail: r.tail, trxIds: freshIds), matchReply(text, waiting), text.trim());
  }

  // ------------------------------------------------------------- deposits

  Future<Deposit> addDeposit(Customer c, double amount, {String way = 'cash', String note = '', DateTime? at}) async {
    final before = customerDue(d, c.id);
    final p = Deposit(id: newId(), customerId: c.id, sarAmount: amount, at: at ?? now, way: way, note: note.trim(), by: meId, byName: meName);
    d.deposits.add(p);
    final after = customerDue(d, c.id);
    _log(
      'recv',
      'রিয়াল জমা',
      '${c.name} · ${sar(amount)} · ${way == 'cash' ? 'নগদ হাতে' : 'ব্যাংক/ট্রান্সফার'} · বকেয়া ${sar(before)} → ${sar(after)}${note.trim().isEmpty ? '' : ' · ${note.trim()}'}',
      ref: c.id,
    );
    if (after <= 0 && c.promiseAt != null) {
      c.promiseAt = null;
      c.promiseNote = '';
      await s.reminders.cancel(c.id);
    }
    await _save();
    return p;
  }

  // -------------------------------------------------------- agent payments

  Future<String?> _receipt(Uint8List? bytes) async {
    if (bytes == null) return null;
    final id = newId();
    await s.store.savePhoto(id, bytes);
    _photoCache[id] = bytes;
    return id;
  }

  String _payDetail(AgentPayment p) => [
        payWayName(p.way),
        if (p.fromAccount.isNotEmpty) 'থেকে ${p.fromAccount}',
        if (p.ref.isNotEmpty) 'রেফ ${p.ref}',
        if (p.receipt != null) 'রসিদের ছবি আছে',
        if (p.note.isNotEmpty) p.note,
      ].join(' · ');

  /// [sarOut]: the riyal that went out of hand for this taka (required).
  /// A mistake on a sent send, written down apart ("অতিরিক্ত হিসাব"). It
  /// changes no account until [applyAdjust].
  Future<Adjust> addAdjust(Txn t, {double sarDue = 0, double sarCash = 0, double takaAgent = 0, required String note}) async {
    final x = Adjust(
      id: newId(),
      at: now,
      txnId: t.id,
      customerId: t.customerId,
      agentId: t.agentId,
      sarDue: sarDue,
      sarCash: sarCash,
      takaAgent: takaAgent,
      note: note.trim(),
      by: meId,
      byName: meName,
    );
    d.adjusts.add(x);
    _log('edit', 'অতিরিক্ত হিসাব · #${bn('${t.no}')}', '${adjustText(x)}${x.note.isEmpty ? '' : ' · ${x.note}'} · এখনো মূল হিসাবে নেই', who: meName, ref: t.id);
    await _save();
    return x;
  }

  /// Adds a correction to the main account: from now it counts in the
  /// customer's due, the cash in hand and the agent's account. Once added it
  /// stays.
  Future<void> applyAdjust(Adjust x) async {
    if (x.applied) return;
    x
      ..applied = true
      ..appliedAt = now
      ..appliedByName = meName;
    final t = txnById(x.txnId);
    _log('edit', 'অতিরিক্ত হিসাব মূল হিসাবে যোগ${t == null ? '' : ' · #${bn('${t.no}')}'}', adjustText(x), who: meName, ref: x.txnId);
    await _save();
  }

  /// The admin confirms the change message reached the agent.
  Future<void> changeNoticeSent(Txn t) async {
    if (t.changeNotice.isEmpty) return;
    t.changeNotice = '';
    _log('agent', 'সংশোধনের মেসেজ এজেন্টকে পাঠানো হয়েছে · #${bn('${t.no}')}', '${agentById(d, t.agentId)?.name ?? ''} · ${taka(t.agentTaka)}', who: meName, ref: t.id);
    await _save();
  }

  /// The riyal a payment to the agent cost, corrected. Only this can change
  /// on a payment: the taka the agent got stays as it was.
  Future<void> editPaymentSar(AgentPayment p, double sarAmount, {String why = ''}) async {
    final old = p.sarAmount;
    if ((old - sarAmount).abs() < 0.005) return;
    p.sarAmount = sarAmount;
    final a = agentById(d, p.agentId);
    _log('edit', 'এজেন্টকে পরিশোধের রিয়াল বদল', '${a?.name ?? ''} · ${taka(p.taka)} · ${dateShort(p.at)} · ${sar(old)} → ${sar(sarAmount)}${why.trim().isEmpty ? '' : ' · কারণ: ${why.trim()}'}',
        who: meName, ref: p.agentId);
    await _save();
  }

  Future<AgentPayment> payAgent(Agent a, List<Txn> txns,
      {required double sarOut, String way = 'bank', String note = '', String ref = '', String fromAccount = '', Uint8List? receipt, DateTime? at, double? amount}) async {
    final due = txns.fold<double>(0, (s, t) => s + t.agentTaka + commissionOf(t, a)).roundToDouble();
    final p = AgentPayment(
      id: newId(),
      agentId: a.id,
      taka: amount ?? due,
      at: at ?? now,
      txnIds: [for (final t in txns) t.id],
      way: way,
      note: note.trim(),
      ref: ref.trim(),
      fromAccount: fromAccount.trim(),
      receipt: await _receipt(receipt),
      sarAmount: sarOut,
      by: meId,
      byName: meName,
    );
    for (final t in txns) {
      t.agentPaymentId = p.id;
    }
    d.agentPayments.add(p);
    _log('agent', 'এজেন্টকে পরিশোধ', '${a.name} · ${taka(p.taka)} (${sar(p.sarAmount)}) · ${bn('${txns.length}')}টা লেনদেন · ${_payDetail(p)}', ref: a.id);
    await _save();
    return p;
  }

  Future<AgentPayment> advanceAgent(Agent a, double amount,
      {required double sarOut, String way = 'bank', String note = '', String ref = '', String fromAccount = '', Uint8List? receipt, DateTime? at}) async {
    final p = AgentPayment(
      id: newId(),
      agentId: a.id,
      taka: amount,
      at: at ?? now,
      way: way,
      note: note.trim(),
      ref: ref.trim(),
      fromAccount: fromAccount.trim(),
      receipt: await _receipt(receipt),
      sarAmount: sarOut,
      by: meId,
      byName: meName,
    );
    d.agentPayments.add(p);
    _log('agent', 'এজেন্টকে টাকা দিলাম', '${a.name} · ${taka(amount)} (${sar(p.sarAmount)}) · ${_payDetail(p)} · দেনা এখন ${taka(agentOwed(d, a.id))}', ref: a.id);
    await _save();
    return p;
  }

  // -------------------------------------------------------- expenses, day

  Future<void> addExpense(String category, double amount, String note) async {
    d.expenses.add(Expense(id: newId(), category: category, sarAmount: amount, at: now, note: note.trim(), by: meId, byName: meName));
    _log('sys', 'খরচ / রিয়াল বের', '$category · ${sar(amount)}${note.trim().isEmpty ? '' : ' · ${note.trim()}'}');
    await _save();
  }

  Future<DayClose> closeDay(double counted, String note) async {
    final c = DayClose(id: newId(), at: now, expected: myCash, counted: counted, note: note.trim(), by: meId, byName: meName);
    d.closes.add(c);
    final diff = c.difference;
    _log('sys', 'দিন শেষের হিসাব', 'হিসাবে ${sar(c.expected)} · গুনে ${sar(counted)}${diff == 0 ? ' · মিলেছে' : ' · পার্থক্য ${sar(diff)}'}${c.note.isEmpty ? '' : ' · ${c.note}'}');
    await _save();
    return c;
  }

  /// "কালেকশন বুঝে নিলাম": [sarAmount] riyal from another admin's hand into mine.
  Future<Handover> receiveFrom(int from, String fromName, double sarAmount, String note) async {
    final x = Handover(id: newId(), at: now, from: from, fromName: fromName, to: meId, toName: meName, sarAmount: sarAmount, note: note.trim());
    d.handovers.add(x);
    _log('recv', 'কালেকশন বুঝে নিলাম', '$fromName → $meName · ${sar(sarAmount)}${x.note.isEmpty ? '' : ' · ${x.note}'}');
    await _save();
    return x;
  }

  // ------------------------------------------------------------- settings

  Future<void> saveSettings(String what) async {
    _log('sys', 'সেটিংস বদল', what);
    await _save();
  }

  // --------------------------------------------------------------- backup

  Future<Uint8List> exportBackup(String password) async {
    final photos = <String, Uint8List>{};
    for (final id in [for (final c in d.customers) c.photo, for (final p in d.agentPayments) p.receipt]) {
      if (id == null) continue;
      final b = await photo(id);
      if (b != null) photos[id] = b;
    }
    final bytes = await Backup.export(d, password, photos: photos);
    d.settings.lastBackup = now;
    _log('sys', 'ব্যাকআপ তৈরি', '${bn('${d.customers.length}')} গ্রাহক · ${bn('${d.txns.length}')} লেনদেন');
    await _save();
    return bytes;
  }

  /// Replaces everything with the backup. The log of the restored data is
  /// kept and the restore itself is added to it.
  Future<void> restoreBackup(Uint8List bytes, String password) async {
    final (data, photos) = await Backup.restore(bytes, password);
    if (loadError is DataKeyMissing) await s.store.startOver();
    for (final e in photos.entries) {
      await s.store.savePhoto(e.key, e.value);
      _photoCache[e.key] = e.value;
    }
    d = data;
    loadError = null;
    _log('sys', 'ব্যাকআপ থেকে ফিরিয়ে আনা', '${bn('${d.customers.length}')} গ্রাহক · ${bn('${d.txns.length}')} লেনদেন');
    await _save();
    await rescheduleAll();
  }
}

/// No send number: no internet and this phone's block is used up.
class NoNumbers implements Exception {
  const NoNumbers();
}
