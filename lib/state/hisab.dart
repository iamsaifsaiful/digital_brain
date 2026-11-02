import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/format.dart';
import '../core/ledger.dart';
import '../core/models.dart';
import '../services/device.dart';
import '../services/lock.dart';
import '../services/reminders.dart';
import '../services/store.dart';

class Services {
  Services({required this.store, required this.lock, required this.device, Reminders? reminders, DateTime Function()? clock})
      : now = clock ?? DateTime.now,
        reminders = reminders ?? FakeReminders();
  final DataStore store;
  final LockService lock;
  final Device device;
  final Reminders reminders;
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

  DateTime get now => s.now();

  Future<void> load() async {
    try {
      d = await s.store.load();
      loadError = null;
    } catch (e) {
      loadError = e;
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    notifyListeners();
    await s.store.save(d);
  }

  String newId() => List.generate(12, (_) => _rand.nextInt(16).toRadixString(16)).join();

  void _log(String kind, String title, String detail, {String who = 'me', String ref = ''}) {
    d.log.add(LogEntry(at: now, kind: kind, title: title, detail: detail, who: who, ref: ref));
  }

  /// Something the user did that changes nothing (app opened, backup made).
  Future<void> note(String kind, String title, String detail, {String who = 'me'}) async {
    _log(kind, title, detail, who: who);
    await _save();
  }

  bool get needsSetup => d.agents.isEmpty || d.settings.ownerName.trim().isEmpty;

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
    return list.where((c) {
      if (c.name.toLowerCase().contains(t)) return true;
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
    await s.reminders.schedule(c.id, at, 'তাগাদা: ${c.name}', 'আজ ${due > 0 ? sar(due) : 'বাকি'} দেওয়ার কথা${c.promiseNote.isEmpty ? '' : ' · ${c.promiseNote}'}');
    _log('cust', 'বাকি ফেরতের তারিখ', '${c.name} · ${dateShort(at)}, ${timeText(at)}${c.promiseNote.isEmpty ? '' : ' · ${c.promiseNote}'}', ref: c.id);
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
        await s.reminders.schedule(c.id, at, 'তাগাদা: ${c.name}', 'আজ বাকি দেওয়ার কথা${c.promiseNote.isEmpty ? '' : ' · ${c.promiseNote}'}');
      }
    }
  }

  /// Riyal the customer owes that will not come back.
  Future<Loss> addLoss(Customer c, double amount, String note) async {
    final before = customerDue(d, c.id);
    final l = Loss(id: newId(), customerId: c.id, sarAmount: amount, at: now, note: note.trim());
    d.losses.add(l);
    _log('recv', 'লস ধরা হলো (আদায় হবে না)', '${c.name} · ${sar(amount)} · বাকি ${sar(before)} → ${sar(customerDue(d, c.id))}${l.note.isEmpty ? '' : ' · ${l.note}'}', ref: c.id);
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
    final b = await s.store.loadPhoto(id);
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
    final t = Txn.fromJson({...draft.toJson(), 'id': newId(), 'no': d.settings.nextNo, 'at': now.toIso8601String()});
    d.settings.nextNo++;
    d.txns.add(t);
    final c = customerById(d, t.customerId);
    if (c != null) rememberRecipient(c, t.recipientLabel, t.number, t.method);
    final dueAfter = customerDue(d, t.customerId);
    _log(
      'txn',
      'নতুন লেনদেন · #${bn('${t.no}')}',
      '${c?.name ?? ''} → ${t.recipientLabel.isEmpty ? bdShow(t.number) : t.recipientLabel} · ${serviceName(t)}${t.kind == Kind.mb && t.pack.isNotEmpty ? ' (${t.pack})' : ''} · '
          '${sar(t.sarAmount)} × ${rateText(t.rate)} = ${taka(t.taka)}${t.fee > 0 ? ' + খরচ ${taka(t.fee)}' : ''} · '
          '${t.pay.bnName}${t.pay == Pay.partial ? ' (${sar(t.sarPaid)})' : ''} · বাকি দাঁড়াল ${sar(dueAfter > 0 ? dueAfter : 0)}',
      ref: t.id,
    );
    await _save();
    return t;
  }

  /// Saves a changed copy of [old]; the log keeps before → after.
  Future<List<String>> editTxn(Txn old, Txn changed) async {
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
  Future<void> setTrxId(Txn t, String trxId, {String who = 'me', String from = 'হাতে লেখা'}) => markSent(t, trxId: trxId, who: who, from: from);

  /// The agent's reply arrived: "10000-667" and/or a TrxID.
  Future<void> markSent(Txn t, {String trxId = '', String reply = '', String tail = '', String who = 'me', String from = 'হাতে লেখা'}) async {
    final wasSent = t.status == TxnStatus.sent;
    final oldId = t.trxId;
    if (trxId.trim().isNotEmpty) t.trxId = trxId.trim().toUpperCase();
    if (reply.trim().isNotEmpty) t.agentReply = reply.trim();
    if (tail.isNotEmpty) t.replyTail = tail;
    t.status = TxnStatus.sent;
    t.sentAt ??= now;
    final parts = <String>[
      if (reply.trim().isNotEmpty) 'উত্তর: ${reply.trim()}',
      if (trxId.trim().isNotEmpty) 'TrxID ${oldId.isNotEmpty && oldId != t.trxId ? '$oldId → ' : ''}${t.trxId}',
      from,
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
    final p = Deposit(id: newId(), customerId: c.id, sarAmount: amount, at: at ?? now, way: way, note: note.trim());
    d.deposits.add(p);
    final after = customerDue(d, c.id);
    _log(
      'recv',
      'রিয়াল জমা',
      '${c.name} · ${sar(amount)} · ${way == 'cash' ? 'নগদ হাতে' : 'ব্যাংক/ট্রান্সফার'} · বাকি ${sar(before)} → ${sar(after)}${note.trim().isEmpty ? '' : ' · ${note.trim()}'}',
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

  Future<AgentPayment> payAgent(Agent a, List<Txn> txns, {String way = 'bank', String note = '', String ref = '', String fromAccount = '', Uint8List? receipt, DateTime? at, double? amount}) async {
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
    );
    for (final t in txns) {
      t.agentPaymentId = p.id;
    }
    d.agentPayments.add(p);
    _log('agent', 'এজেন্টকে পরিশোধ', '${a.name} · ${taka(p.taka)} · ${bn('${txns.length}')}টা লেনদেন · ${_payDetail(p)}', ref: a.id);
    await _save();
    return p;
  }

  Future<AgentPayment> advanceAgent(Agent a, double amount, {String way = 'bank', String note = '', String ref = '', String fromAccount = '', Uint8List? receipt, DateTime? at}) async {
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
    );
    d.agentPayments.add(p);
    _log('agent', 'এজেন্টকে টাকা দিলাম', '${a.name} · ${taka(amount)} · ${_payDetail(p)} · দেনা এখন ${taka(agentOwed(d, a.id))}', ref: a.id);
    await _save();
    return p;
  }

  // -------------------------------------------------------- expenses, day

  Future<void> addExpense(String category, double amount, String note) async {
    d.expenses.add(Expense(id: newId(), category: category, sarAmount: amount, at: now, note: note.trim()));
    _log('sys', 'খরচ / রিয়াল বের', '$category · ${sar(amount)}${note.trim().isEmpty ? '' : ' · ${note.trim()}'}');
    await _save();
  }

  Future<DayClose> closeDay(double counted, String note) async {
    final c = DayClose(id: newId(), at: now, expected: cashInHand(d), counted: counted, note: note.trim());
    d.closes.add(c);
    final diff = c.difference;
    _log('sys', 'দিন শেষের হিসাব', 'হিসাবে ${sar(c.expected)} · গুনে ${sar(counted)}${diff == 0 ? ' · মিলেছে' : ' · পার্থক্য ${sar(diff)}'}${c.note.isEmpty ? '' : ' · ${c.note}'}');
    await _save();
    return c;
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
