/// The account maths and the message texts, kept apart from the screens so
/// they can be tested.
library;

import 'format.dart';
import 'models.dart';
import 'templates.dart';
export 'templates.dart';

/// Riyal a customer owes now (negative = riyal paid in advance).
double customerDue(AppData d, String customerId) {
  var due = 0.0;
  for (final t in d.txns) {
    if (t.customerId == customerId) due += t.sarDueAtSend;
  }
  for (final p in d.deposits) {
    if (p.customerId == customerId) due -= p.sarAmount;
  }
  for (final l in d.losses) {
    if (l.customerId == customerId) due -= l.sarAmount;
  }
  for (final a in d.adjusts) {
    if (a.applied && a.customerId == customerId) due += a.sarDue;
  }
  return _round2(due);
}

/// Riyal written off as lost for one customer (or all when null).
double lossOf(AppData d, [String? customerId]) => _round2(d.losses.where((l) => customerId == null || l.customerId == customerId).fold<double>(0, (s, l) => s + l.sarAmount));

double _round2(double v) => (v * 100).roundToDouble() / 100;

double dueLimitOf(AppData d, Customer c) => c.dueLimit ?? d.settings.defaultDueLimit;

/// One send and how much of it is still owed, after later riyal payments
/// were put against the oldest sends first.
class Open {
  Open(this.txn, this.owedAtSend, this.left);
  final Txn txn;
  final double owedAtSend;
  final double left;
}

/// The customer's sends that were not fully paid at the time, oldest first,
/// with what is left of each after the later payments.
List<Open> openSends(AppData d, String customerId, {double extraPayment = 0}) {
  final sends = d.txns.where((t) => t.customerId == customerId && t.sarDueAtSend > 0).toList()..sort((a, b) => a.at.compareTo(b.at));
  var paid = extraPayment;
  for (final p in d.deposits) {
    if (p.customerId == customerId) paid += p.sarAmount;
  }
  for (final l in d.losses) {
    if (l.customerId == customerId) paid += l.sarAmount;
  }
  final out = <Open>[];
  for (final t in sends) {
    final owed = t.sarDueAtSend;
    final use = paid >= owed ? owed : (paid > 0 ? paid : 0.0);
    paid -= use;
    out.add(Open(t, owed, _round2(owed - use)));
  }
  return out;
}

/// Days since the oldest riyal still owed, or null when nothing is owed.
/// When the customer last sent money or paid riyal (null = never).
DateTime? lastActivity(AppData d, String customerId) {
  DateTime? last;
  for (final t in d.txns) {
    if (t.customerId == customerId && !t.cancelled && (last == null || t.at.isAfter(last))) last = t.at;
  }
  for (final p in d.deposits) {
    if (p.customerId == customerId && (last == null || p.at.isAfter(last))) last = p.at;
  }
  return last;
}

/// Customers with nothing for [days] days or more (counted from their last
/// send or payment, or from when their profile was made), longest first.
List<(Customer, int)> quietCustomers(AppData d, DateTime now, {int? days}) {
  final n = days ?? d.settings.inactiveDays;
  final out = <(Customer, int)>[];
  for (final c in d.liveCustomers) {
    final since = now.difference(lastActivity(d, c.id) ?? c.created).inDays;
    if (since >= n) out.add((c, since));
  }
  out.sort((a, b) => b.$2.compareTo(a.$2));
  return out;
}

/// A friendly message to a customer not heard from in a while.
String checkInMessage(AppData d, Customer c, int days) => fillTemplate(_tpl(d, 'cust_checkin'), {
      'নাম': c.name,
      'দিন': '$days',
      'স্বাক্ষর': _sign(d),
    });

int? oldestDueDays(AppData d, String customerId, DateTime now) {
  for (final o in openSends(d, customerId)) {
    if (o.left > 0) return now.difference(o.txn.at).inDays;
  }
  return null;
}

/// Commission on one send, in taka.
double commissionOf(Txn t, Agent? a) => a == null || t.cancelled ? 0 : (t.agentTaka * a.commissionPerThousand / 1000).roundToDouble();

/// Taka owed to an agent now: everything they sent plus commission, less
/// what was paid. Negative = paid in advance.
double agentOwed(AppData d, String agentId) {
  final a = agentById(d, agentId);
  var owed = 0.0;
  for (final t in d.txns) {
    // Only what the agent has sent: a waiting request is not owed yet.
    if (t.agentId == agentId && t.status == TxnStatus.sent) owed += t.agentTaka + commissionOf(t, a);
  }
  for (final p in d.agentPayments) {
    if (p.agentId == agentId) owed -= p.taka;
  }
  for (final x in d.adjusts) {
    if (x.applied && x.agentId == agentId) owed += x.takaAgent;
  }
  return owed.roundToDouble();
}

/// Sends the agent has not been paid for yet, oldest first.
List<Txn> unpaidForAgent(AppData d, String agentId) => d.txns.where((t) => t.agentId == agentId && t.status == TxnStatus.sent && t.agentPaymentId == null).toList()..sort((a, b) => a.at.compareTo(b.at));

Agent? agentById(AppData d, String id) {
  for (final a in d.agents) {
    if (a.id == id) return a;
  }
  return null;
}

/// The customer's name for a send: the profile's, or the name typed for a
/// send without a profile.
String customerNameOf(AppData d, Txn t) {
  final c = customerById(d, t.customerId);
  if (c != null) return c.name;
  return t.walkIn.trim().isEmpty ? 'প্রোফাইল ছাড়া' : t.walkIn.trim();
}

/// A stand-in customer for a send without a profile (never saved).
Customer walkInCustomer(String name, String phone) => Customer(id: '', name: name.trim().isEmpty ? 'প্রোফাইল ছাড়া' : name.trim(), phone: phone, created: DateTime(2000));

Customer? customerById(AppData d, String id) {
  if (id.isEmpty) return null;
  for (final c in d.customers) {
    if (c.id == id) return c;
  }
  return null;
}

/// One movement of riyal in an admin's hand.
class CashLine {
  CashLine({required this.at, required this.title, required this.sub, this.inSar = 0, this.outSar = 0, required this.kind, this.ref = '', required this.by, required this.byName});
  final DateTime at;
  final String title;
  final String sub;
  final double inSar;
  final double outSar;

  /// txn, deposit, expense, payment, handover, close
  final String kind;
  final String ref;
  final int by;
  final String byName;
}

/// Is a record by [recBy] in the hand of [me]? Records from before the
/// server (no admin) belong to the main admin.
bool inHandOf(int recBy, int me, {bool owner = false}) => recBy == me || (owner && recBy == 0);

/// Every riyal that came into or went out of hand, oldest first. With
/// [me], only that admin's hand (handovers move riyal between hands, so
/// the shop's total never counts them twice).
List<CashLine> cashLines(AppData d, {int? me, bool owner = false}) {
  bool mine(int by) => me == null || inHandOf(by, me, owner: owner);
  String who(int by, String name) => name.isEmpty ? (by == 0 ? 'মূল হিসাব' : '') : name;
  final out = <CashLine>[];
  for (final t in d.txns) {
    // The admin's dealing is with the customer: the riyal is in hand as soon
    // as the send is made (the agent's account waits until it is sent).
    if (t.cancelled || t.sarPaid <= 0 || !mine(t.by)) continue;
    out.add(CashLine(at: t.at, title: '${customerNameOf(d, t)} · #${t.no}', sub: '${t.pay == Pay.partial ? 'আংশিক' : 'নগদে'} · ${serviceName(t)}', inSar: t.sarPaid, kind: 'txn', ref: t.id, by: t.by, byName: who(t.by, t.byName)));
  }
  for (final p in d.deposits) {
    if (!mine(p.by)) continue;
    out.add(CashLine(at: p.at, title: '${customerById(d, p.customerId)?.name ?? ''} · জমা', sub: p.way == 'cash' ? 'নগদ হাতে' : 'ব্যাংক/ট্রান্সফার', inSar: p.sarAmount, kind: 'deposit', ref: p.customerId, by: p.by, byName: who(p.by, p.byName)));
  }
  for (final e in d.expenses) {
    if (!mine(e.by)) continue;
    out.add(CashLine(at: e.at, title: e.category, sub: e.note, outSar: e.sarAmount, kind: 'expense', by: e.by, byName: who(e.by, e.byName)));
  }
  for (final p in d.agentPayments) {
    if (p.sarAmount <= 0 || !mine(p.by)) continue;
    out.add(CashLine(at: p.at, title: 'এজেন্টকে ${groupEn(p.taka.round())} টাকা', sub: '${agentById(d, p.agentId)?.name ?? ''} · ${payWayName(p.way)}', outSar: p.sarAmount, kind: 'payment', ref: p.id, by: p.by, byName: who(p.by, p.byName)));
  }
  for (final h in d.handovers) {
    if (me == null) continue; // a handover changes no total
    if (inHandOf(h.from, me, owner: owner)) out.add(CashLine(at: h.at, title: '${h.toName}-কে দিলাম', sub: 'হাতবদল${h.note.isEmpty ? '' : ' · ${h.note}'}', outSar: h.sarAmount, kind: 'handover', by: h.from, byName: h.fromName));
    if (inHandOf(h.to, me, owner: owner)) out.add(CashLine(at: h.at, title: '${h.fromName}-এর কাছ থেকে বুঝে নিলাম', sub: 'হাতবদল${h.note.isEmpty ? '' : ' · ${h.note}'}', inSar: h.sarAmount, kind: 'handover', by: h.to, byName: h.toName));
  }
  for (final a in d.adjusts) {
    if (!a.applied || a.sarCash.abs() < 0.005 || !mine(a.handOf)) continue;
    final t = d.txns.where((x) => x.id == a.txnId).firstOrNull;
    out.add(CashLine(
        at: a.appliedAt ?? a.at,
        title: 'অতিরিক্ত হিসাব${t == null ? '' : ' · #${t.no}'}',
        sub: a.note,
        inSar: a.sarCash > 0 ? a.sarCash : 0,
        outSar: a.sarCash < 0 ? -a.sarCash : 0,
        kind: 'adjust',
        ref: a.txnId,
        by: a.handOf,
        byName: who(a.handOf, a.handOfName)));
  }
  for (final c in d.closes) {
    if (c.difference.abs() < 0.005 || !mine(c.by)) continue;
    out.add(CashLine(
        at: c.at,
        title: 'দিন শেষে গুনে ${c.difference > 0 ? 'বেশি' : 'কম'}',
        sub: c.note,
        inSar: c.difference > 0 ? c.difference : 0,
        outSar: c.difference < 0 ? -c.difference : 0,
        kind: 'close',
        by: c.by,
        byName: who(c.by, c.byName)));
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// Riyal that should be in hand: the shop's, or one admin's.
double cashInHand(AppData d, {int? me, bool owner = false}) => _round2(cashLines(d, me: me, owner: owner).fold<double>(0, (s, l) => s + l.inSar - l.outSar));

/// The admins who appear in the account: id → name (0 = before the server).
Map<int, String> adminsIn(AppData d) {
  final out = <int, String>{};
  void add(int by, String name) {
    if (!out.containsKey(by) || (out[by]!.isEmpty && name.isNotEmpty)) out[by] = by == 0 ? 'মূল হিসাব' : name;
  }

  for (final t in d.txns) {
    add(t.by, t.byName);
  }
  for (final x in d.deposits) {
    add(x.by, x.byName);
  }
  for (final x in d.expenses) {
    add(x.by, x.byName);
  }
  for (final x in d.agentPayments) {
    add(x.by, x.byName);
  }
  for (final x in d.adjusts) {
    add(x.handOf, x.handOfName);
  }
  for (final h in d.handovers) {
    add(h.from, h.fromName);
    add(h.to, h.toName);
  }
  return out;
}

/// "গ্রাহকের বকেয়া +৫০ SAR · হাতে −২০ SAR · এজেন্টের পাওনা +৳ ৬৫০".
String adjustText(Adjust x) {
  String signed(double v, String Function(double) f) => '${v > 0 ? '+' : '−'}${f(v.abs())}';
  return [
    if (x.sarDue.abs() >= 0.005) 'গ্রাহকের বকেয়া ${signed(x.sarDue, sar)}',
    if (x.sarCash.abs() >= 0.005) 'হাতে ${signed(x.sarCash, sar)}',
    if (x.takaAgent.abs() >= 0.5) 'এজেন্টের পাওনা ${signed(x.takaAgent, taka)}',
  ].join(' · ');
}

/// "রেট ভুল হয়েছিল · এজেন্টের ভুল · note".
String adjustWhy(Adjust x) {
  var who = adjustWhos[x.who] ?? '';
  if (x.who == 'admin' && x.handByName.isNotEmpty) who = '$who (${x.handByName})';
  return [adjustWhats[x.what] ?? '', who, x.note].where((v) => v.isNotEmpty).join(' · ');
}

/// Riyal owed by all customers together (only those who owe).
double totalCustomerDue(AppData d) {
  var v = 0.0;
  for (final c in d.customers) {
    final due = customerDue(d, c.id);
    if (due > 0) v += due;
  }
  return _round2(v);
}

/// Earlier sends to the same number for the same taka within [minutes].
List<Txn> duplicates(AppData d, {required String number, required double taka, required DateTime now, int? minutes, String? exceptId}) {
  final m = minutes ?? d.settings.dupMinutes;
  return d.txns.where((t) => t.id != exceptId && !t.cancelled && t.number == number && (t.taka - taka).abs() < 0.5 && now.difference(t.at).inMinutes.abs() <= m).toList();
}

/// Riyal × rate, rounded to whole taka.
double takaFor(double sarAmount, double rate) => (sarAmount * rate).roundToDouble();

// ---------------------------------------------------------------------------
// TrxID from the agent's reply

final _token = RegExp(r'[A-Za-z0-9]{8,12}');

/// Things in [text] that look like a bKash/Nagad transaction id: 8–12
/// letters and digits with at least one of each, not a phone number.
List<String> trxIdsIn(String text) {
  final t = en(text);
  final out = <String>[];
  for (final m in _token.allMatches(t)) {
    final s = m[0]!;
    final before = m.start > 0 ? t[m.start - 1] : ' ';
    final after = m.end < t.length ? t[m.end] : ' ';
    if (RegExp('[A-Za-z0-9]').hasMatch(before) || RegExp('[A-Za-z0-9]').hasMatch(after)) continue;
    if (!RegExp('[A-Za-z]').hasMatch(s) || !RegExp('[0-9]').hasMatch(s)) continue;
    if (RegExp(r'^(TrxID|TxnID|TRXID)$', caseSensitive: false).hasMatch(s)) continue;
    final up = s.toUpperCase();
    if (!out.contains(up)) out.add(up);
  }
  return out;
}

/// What the agent's reply says: "10000-667" (taka, then 3 digits of the
/// number), maybe a TrxID, maybe taka with a TrxID.
class AgentReply {
  const AgentReply({this.no, this.amount, this.tail = '', this.trxIds = const []});

  /// The send's number the agent wrote first ("1042 10000-667").
  final int? no;
  final double? amount;
  final String tail;
  final List<String> trxIds;

  /// Worth offering: the "taka-digits" form, or a TrxID.
  bool get useful => (amount != null && tail.isNotEmpty) || trxIds.isNotEmpty;
}

final _amountTail = RegExp(r'(?<![0-9A-Za-z#])(\d{1,3}(?:,\d{2,3})+|\d{2,7})(?:\.\d+)?\s*[-–—/]\s*(\d{3})(?![0-9])');
final _amount = RegExp(r'(?<![0-9A-Za-z#.])(\d{1,3}(?:,\d{2,3})+|\d{3,7})(?:\.\d+)?(?![0-9A-Za-z])');

final _leadNo = RegExp(r'^\s*#?\s*(\d{3,9})(?![0-9,\-–—/])');

/// [nos] are the send numbers in use: a reply that starts with one of them
/// ("1042 10000-667" or "#1042 …") names its send.
AgentReply parseReply(String text, {Iterable<int> nos = const []}) {
  var t = en(text);
  int? no;
  final lead = _leadNo.firstMatch(t);
  if (lead != null) {
    final n = int.parse(lead[1]!);
    final rest = t.substring(lead.end);
    if (nos.contains(n) && RegExp('[0-9A-Za-z]').hasMatch(rest)) {
      no = n;
      t = rest;
    }
  }
  if (no == null) {
    for (final m in RegExp(r'#\s*(\d{3,9})').allMatches(t)) {
      final n = int.parse(m[1]!);
      if (nos.contains(n)) {
        no = n;
        t = t.replaceRange(m.start, m.end, ' ');
        break;
      }
    }
  }
  final ids = trxIdsIn(t);
  final m = _amountTail.firstMatch(t);
  if (m != null) return AgentReply(no: no, amount: double.parse(m[1]!.replaceAll(',', '')), tail: m[2]!, trxIds: ids);
  if (ids.isNotEmpty) {
    // Taka written next to the TrxID: a number of 3+ digits that is not a
    // phone number.
    for (final n in _amount.allMatches(t)) {
      final digits = n[1]!.replaceAll(',', '');
      if (digits.length >= 10) continue;
      return AgentReply(no: no, amount: double.parse(digits), trxIds: ids);
    }
  }
  return AgentReply(no: no, trxIds: ids);
}

/// Which waiting send a reply is about: by "#1042", by the taka (narrowed
/// by the 3 digits when several sends have the same taka), or by the last
/// digits of the number. Returns the candidates; nothing is ever put on a
/// send without the user tapping it.
List<Txn> matchReply(String text, List<Txn> waiting) {
  final t = en(text);
  final r = parseReply(t, nos: [for (final x in waiting) x.no]);
  // The send's number given: that one only.
  if (r.no != null) return waiting.where((x) => x.no == r.no).toList();
  final amount = r.amount;
  if (amount != null) {
    // The 3 digits are of the agent's own number it went from, so they do
    // not tell sends apart: several sends with the same taka → ask.
    final byAmount = waiting.where((x) => (x.agentTaka - amount).abs() < 0.5 || (x.taka - amount).abs() < 0.5).toList();
    if (byAmount.isNotEmpty) return byAmount;
    // Taka given but no send has it: do not guess.
    if (r.tail.isNotEmpty) return [];
  }
  final digits = RegExp(r'(?<![0-9A-Za-z])[0-9]{3,4}(?![0-9A-Za-z])').allMatches(t).map((m) => m[0]!).toList();
  if (digits.isNotEmpty) {
    final byTail = waiting.where((x) => digits.any((d) => x.number.endsWith(d))).toList();
    if (byTail.isNotEmpty) return byTail;
  }
  return waiting.length == 1 && amount == null ? [waiting.first] : [];
}

// ---------------------------------------------------------------------------
// Message texts

String _methodWord(Txn t) => t.method == Method.bank ? 'ব্যাংক' : t.method.bnName;

/// The admin's wording if set, else the default.
String _tpl(AppData? d, String key) {
  final own = d?.settings.templates[key];
  return own != null && own.trim().isNotEmpty ? own : templateOf(key).def;
}

/// What the agent writes back: first the send's number, then the taka and
/// the last 3 digits of the agent's own number it was sent from, e.g.
/// "26110001 10000-667".
String _replyAsk(AppData? d, Txn t) => fillTemplate(_tpl(d, 'agent_reply_rule'), {'নং': '${t.no}', 'টাকা': '${t.agentTaka.round()}'});

/// What the agent gets on WhatsApp. Taka only: riyal is never mentioned.
String agentMessage(Txn t, [AppData? d]) {
  final amount = groupEn(t.agentTaka.round());
  if (t.kind.isTopUp) {
    return fillTemplate(_tpl(d, 'agent_topup'), {
      'নং': '${t.no}',
      'ধরন': t.kind.bnName,
      'নম্বর': bdShowEn(t.number),
      'অপারেটর': t.operator,
      'প্যাক': t.kind == Kind.mb ? t.pack : '',
      'টাকা': amount,
      'উত্তরের_নিয়ম': _replyAsk(d, t),
    });
  }
  return fillTemplate(_tpl(d, 'agent_send'), {
    'নং': '${t.no}',
    'মাধ্যম': _methodWord(t),
    'নম্বর': bdShowEn(t.number),
    'টাকা': amount,
    'খরচ': t.fee > 0 ? ' (খরচসহ, মূল ${groupEn(t.taka.round())})' : '',
    'ধরন': t.kind.bnName,
    'উত্তরের_নিয়ম': _replyAsk(d, t),
  });
}

/// How a send is named in lists: "বিকাশ", "রিচার্জ · রবি", "এমবি · রবি".
String serviceName(Txn t) => switch (t.kind) {
      Kind.recharge => 'রিচার্জ${t.operator.isEmpty ? '' : ' · ${t.operator}'}',
      Kind.mb => 'এমবি${t.operator.isEmpty ? '' : ' · ${t.operator}'}',
      _ => t.method.bnName,
    };

/// What the agent's reply proved: TrxID, or "10000-667".
String proofText(Txn t) => t.trxId.isNotEmpty ? t.trxId : (t.agentReply.isNotEmpty ? t.agentReply : '');

/// The send again, when it was changed after the first message.
String agentChangeMessage(Txn t, [AppData? d]) =>
    fillTemplate(_tpl(d, 'agent_change'), {'নং': '${t.no}', 'বিস্তারিত': agentMessage(t, d).split('\n').skip(1).join('\n')});

String agentCancelMessage(Txn t, [AppData? d]) =>
    fillTemplate(_tpl(d, 'agent_cancel'), {'নং': '${t.no}', 'নম্বর': bdShowEn(t.number), 'টাকা': groupEn(t.agentTaka.round())});

/// The day's list for the agent: taka only.
String agentDayStatement(AppData d, Agent a, DateTime day) {
  final list = d.txns.where((t) => t.agentId == a.id && !t.cancelled && sameDay(t.at, day)).toList()..sort((x, y) => x.at.compareTo(y.at));
  final total = list.fold<double>(0, (s, t) => s + t.agentTaka);
  final lines = [
    for (final t in list)
      '#${t.no} · ${t.kind.isTopUp ? '${t.kind.bnName} · ' : ''}${bdShowEn(t.number)} · ${groupEn(t.agentTaka.round())}${t.status == TxnStatus.sent ? ' · ${proofText(t).isEmpty ? 'পাঠানো' : proofText(t)}' : ' · পাঠানোর অপেক্ষায়'}',
  ];
  return fillTemplate(_tpl(d, 'agent_day'), {
    'তারিখ': en(dateShort(day)),
    'তালিকা': lines.isEmpty ? 'আজ কোনো লেনদেন নেই।' : lines.join('\n'),
    'মোট': groupEn(total.round()),
    'সংখ্যা': '${list.length}',
    'পাওনা': groupEn(agentOwed(d, a.id).round()),
  });
}

String _sign(AppData d) => d.settings.ownerName.trim();
/// The due line's value; empty when nothing is owed, so the line is left
/// out of the message (no "বকেয়া নেই").
String _dueText(double due) => due > 0 ? '${groupEn(due, decimals: 2)} রিয়াল' : '';

/// Receipt for the customer once the taka arrived.
/// [pin]: last digits of the number the agent sent from (null = as the
/// agent reported, '' = leave the line out).
String customerReceipt(AppData d, Txn t, {String? pin}) {
  final c = customerById(d, t.customerId);
  return fillTemplate(_tpl(d, 'cust_receipt'), {
    'নাম': c?.name ?? t.walkIn.trim(),
    'খবর': t.kind.isTopUp ? 'আপনার ${t.kind.bnName} হয়ে গেছে।' : 'আপনার টাকা পৌঁছেছে।',
    'প্রাপক': '${t.recipientLabel.isEmpty ? '' : '${t.recipientLabel} · '}${bdShowEn(t.number)}',
    'মাধ্যম': t.kind.isTopUp ? serviceName(t) : _methodWord(t),
    'প্যাক': t.kind == Kind.mb ? t.pack : '',
    'টাকা': groupEn(t.taka.round()),
    'TrxID': t.trxId,
    'পিন': t.kind.isTopUp ? '' : (pin ?? t.replyTail),
    'রিয়াল': '${groupEn(t.sarAmount, decimals: 2)}${t.pay == Pay.cash ? ' (পরিশোধ)' : ''}',
    'বকেয়া': _dueText(customerDue(d, t.customerId)),
    'স্বাক্ষর': _sign(d),
  }).replaceAll('আসসালামু আলাইকুম ,', 'আসসালামু আলাইকুম,');
}

String depositReceipt(AppData d, Deposit p) {
  final c = customerById(d, p.customerId);
  return fillTemplate(_tpl(d, 'cust_deposit'), {
    'নাম': c?.name ?? '',
    'রিয়াল': groupEn(p.sarAmount, decimals: 2),
    'বকেয়া': _dueText(customerDue(d, p.customerId)),
    'স্বাক্ষর': _sign(d),
  }).replaceAll('আসসালামু আলাইকুম ,', 'আসসালামু আলাইকুম,');
}

String dueReminder(AppData d, Customer c) => fillTemplate(_tpl(d, 'cust_due'), {
      'নাম': c.name,
      'বকেয়া': groupEn(customerDue(d, c.id), decimals: 2),
      'স্বাক্ষর': _sign(d),
    });

/// A customer's statement, riyal only.
String customerStatement(AppData d, Customer c) {
  final rows = <(DateTime, String)>[
    for (final t in d.txns.where((t) => t.customerId == c.id && !t.cancelled))
      (
        t.at,
        '${en(dateShort(t.at))}: ${t.recipientLabel.isEmpty ? bdShowEn(t.number) : t.recipientLabel} — ${groupEn(t.sarAmount, decimals: 2)} রিয়াল'
            '${t.sarPaid > 0 ? ', দিয়েছেন ${groupEn(t.sarPaid, decimals: 2)}' : ', বকেয়া'}'
      ),
    for (final p in d.deposits.where((p) => p.customerId == c.id)) (p.at, '${en(dateShort(p.at))}: জমা ${groupEn(p.sarAmount, decimals: 2)} রিয়াল'),
    for (final l in d.losses.where((l) => l.customerId == c.id)) (l.at, '${en(dateShort(l.at))}: আদায় হবে না ধরা হলো ${groupEn(l.sarAmount, decimals: 2)} রিয়াল'),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  return fillTemplate(_tpl(d, 'cust_statement'), {
    'নাম': c.name,
    'তালিকা': rows.map((r) => r.$2).join('\n'),
    'বকেয়া': _dueText(customerDue(d, c.id)),
    'স্বাক্ষর': _sign(d),
  });
}

/// All sends as CSV (opens in Excel).
String txnsCsv(AppData d) {
  String q(String s) => '"${s.replaceAll('"', '""')}"';
  final b = StringBuffer('No,Date,Customer,Recipient,Number,Method,Kind,Operator,Pack,SAR,Rate,Taka,Fee,Paid SAR,Pay,Agent,Status,TrxID,Agent reply,Wrong number fault\n');
  final list = [...d.txns]..sort((a, b) => a.at.compareTo(b.at));
  for (final t in list) {
    b.writeln([
      t.no,
      t.at.toIso8601String().substring(0, 16).replaceFirst('T', ' '),
      q(customerNameOf(d, t)),
      q(t.recipientLabel),
      t.number,
      t.method.name,
      t.kind.name,
      q(t.operator),
      q(t.pack),
      t.sarAmount,
      t.rate,
      t.taka,
      t.fee,
      t.sarPaid,
      t.pay.name,
      q(agentById(d, t.agentId)?.name ?? ''),
      t.status.name,
      t.trxId,
      q(t.agentReply),
      t.fault?.name ?? '',
    ].join(','));
  }
  return b.toString();
}
