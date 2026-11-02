/// The account maths and the message texts, kept apart from the screens so
/// they can be tested.
library;

import 'format.dart';
import 'models.dart';

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
    if (t.agentId == agentId && !t.cancelled) owed += t.agentTaka + commissionOf(t, a);
  }
  for (final p in d.agentPayments) {
    if (p.agentId == agentId) owed -= p.taka;
  }
  return owed.roundToDouble();
}

/// Sends the agent has not been paid for yet, oldest first.
List<Txn> unpaidForAgent(AppData d, String agentId) => d.txns.where((t) => t.agentId == agentId && !t.cancelled && t.agentPaymentId == null).toList()..sort((a, b) => a.at.compareTo(b.at));

Agent? agentById(AppData d, String id) {
  for (final a in d.agents) {
    if (a.id == id) return a;
  }
  return null;
}

Customer? customerById(AppData d, String id) {
  for (final c in d.customers) {
    if (c.id == id) return c;
  }
  return null;
}

/// Riyal that should be in hand: paid at send + later payments − costs and
/// riyal handed over, corrected by every day-end count.
double cashInHand(AppData d) {
  var v = 0.0;
  for (final t in d.txns) {
    if (!t.cancelled) v += t.sarPaid;
  }
  for (final p in d.deposits) {
    v += p.sarAmount;
  }
  for (final e in d.expenses) {
    v -= e.sarAmount;
  }
  for (final c in d.closes) {
    v += c.difference;
  }
  return _round2(v);
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

final _leadNo = RegExp(r'^\s*#?\s*(\d{3,7})(?![0-9,\-–—/])');

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
    for (final m in RegExp(r'#\s*(\d{3,7})').allMatches(t)) {
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
    var byAmount = waiting.where((x) => (x.agentTaka - amount).abs() < 0.5 || (x.taka - amount).abs() < 0.5).toList();
    if (byAmount.length > 1 && r.tail.isNotEmpty) {
      final narrowed = byAmount.where((x) => x.number.endsWith(r.tail)).toList();
      if (narrowed.isNotEmpty) byAmount = narrowed;
    }
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

/// What the agent writes back: first the send's number, then
/// taka-last 3 digits, e.g. "1042 10000-667".
String _replyAsk(Txn t) => 'পাঠানোর পর এই মেসেজে রিপ্লাই দিন — আগে লেনদেন নং, তারপর টাকা-শেষের ৩ সংখ্যা।\n'
    'যেমন: ${t.no} ${t.agentTaka.round()}-XXX (TrxID থাকলে সেটাও)';

/// What the agent gets on WhatsApp. Taka only: riyal is never mentioned.
String agentMessage(Txn t) {
  final amount = groupEn(t.agentTaka.round());
  if (t.kind.isTopUp) {
    return 'নতুন ${t.kind.bnName} — #${t.no}\n'
        'নম্বর: ${bdShowEn(t.number)}\n'
        '${t.operator.isEmpty ? '' : 'অপারেটর: ${t.operator}\n'}'
        '${t.kind == Kind.mb && t.pack.isNotEmpty ? 'প্যাক: ${t.pack}\n' : ''}'
        'টাকা: $amount\n'
        '${_replyAsk(t)}';
  }
  final feeLine = t.fee > 0 ? ' (খরচসহ, মূল ${groupEn(t.taka.round())})' : '';
  return 'নতুন ${_methodWord(t)} — #${t.no}\n'
      'নম্বর: ${bdShowEn(t.number)}\n'
      'টাকা: $amount$feeLine\n'
      'ধরন: ${t.kind.bnName}\n'
      '${_replyAsk(t)}';
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
String agentChangeMessage(Txn t) => 'সংশোধন — #${t.no}\n${agentMessage(t).split('\n').skip(1).join('\n')}';

String agentCancelMessage(Txn t) => 'বাতিল — #${t.no}\nনম্বর: ${bdShowEn(t.number)}\nটাকা: ${groupEn(t.agentTaka.round())}\nএটা পাঠাবেন না।';

/// The day's list for the agent: taka only.
String agentDayStatement(AppData d, Agent a, DateTime day) {
  final list = d.txns.where((t) => t.agentId == a.id && !t.cancelled && sameDay(t.at, day)).toList()..sort((x, y) => x.at.compareTo(y.at));
  final total = list.fold<double>(0, (s, t) => s + t.agentTaka);
  final lines = [
    for (final t in list)
      '#${t.no} · ${t.kind.isTopUp ? '${t.kind.bnName} · ' : ''}${bdShowEn(t.number)} · ${groupEn(t.agentTaka.round())}${t.status == TxnStatus.sent ? ' · ${proofText(t).isEmpty ? 'পাঠানো' : proofText(t)}' : ' · উত্তর বাকি'}',
  ];
  return 'হিসাব — ${en(dateShort(day))}\n'
      '${lines.isEmpty ? 'আজ কোনো লেনদেন নেই।' : lines.join('\n')}\n'
      'আজ মোট: ${groupEn(total.round())} টাকা (${list.length}টা)\n'
      'আপনার মোট পাওনা: ${groupEn(agentOwed(d, a.id).round())} টাকা';
}

String _owner(AppData d) => d.settings.ownerName.trim().isEmpty ? '' : '\n— ${d.settings.ownerName.trim()}';

/// Receipt for the customer once the taka arrived.
String customerReceipt(AppData d, Txn t) {
  final c = customerById(d, t.customerId);
  final due = customerDue(d, t.customerId);
  return 'আসসালামু আলাইকুম${c == null ? '' : ' ${c.name}'},\n'
      '${t.kind.isTopUp ? 'আপনার ${t.kind.bnName} হয়ে গেছে।' : 'আপনার টাকা পৌঁছেছে।'}\n'
      'প্রাপক: ${t.recipientLabel.isEmpty ? '' : '${t.recipientLabel} · '}${bdShowEn(t.number)} (${t.kind.isTopUp ? serviceName(t) : _methodWord(t)})\n'
      '${t.kind == Kind.mb && t.pack.isNotEmpty ? 'প্যাক: ${t.pack}\n' : ''}'
      'টাকা: ${groupEn(t.taka.round())}\n'
      '${t.trxId.isEmpty ? '' : 'TrxID: ${t.trxId}\n'}'
      'রিয়াল: ${groupEn(t.sarAmount, decimals: 2)}${t.pay == Pay.cash ? ' (পরিশোধ)' : ''}\n'
      'আপনার মোট বাকি: ${due > 0 ? '${groupEn(due, decimals: 2)} রিয়াল' : 'নেই'}'
      '${_owner(d)}';
}

String depositReceipt(AppData d, Deposit p) {
  final c = customerById(d, p.customerId);
  final due = customerDue(d, p.customerId);
  return 'আসসালামু আলাইকুম${c == null ? '' : ' ${c.name}'},\n'
      '${groupEn(p.sarAmount, decimals: 2)} রিয়াল জমা পেয়েছি, ধন্যবাদ।\n'
      'এখন বাকি: ${due > 0 ? '${groupEn(due, decimals: 2)} রিয়াল' : 'নেই'}'
      '${_owner(d)}';
}

String dueReminder(AppData d, Customer c) {
  final due = customerDue(d, c.id);
  return 'আসসালামু আলাইকুম ${c.name},\n'
      'আপনার কাছে ${groupEn(due, decimals: 2)} রিয়াল বাকি আছে। সুবিধামতো দিয়ে দিলে উপকার হয়।\n'
      'ধন্যবাদ।${_owner(d)}';
}

/// A customer's statement, riyal only.
String customerStatement(AppData d, Customer c) {
  final rows = <(DateTime, String)>[
    for (final t in d.txns.where((t) => t.customerId == c.id && !t.cancelled))
      (
        t.at,
        '${en(dateShort(t.at))}: ${t.recipientLabel.isEmpty ? bdShowEn(t.number) : t.recipientLabel} — ${groupEn(t.sarAmount, decimals: 2)} রিয়াল'
            '${t.sarPaid > 0 ? ', দিয়েছেন ${groupEn(t.sarPaid, decimals: 2)}' : ', বাকি'}'
      ),
    for (final p in d.deposits.where((p) => p.customerId == c.id)) (p.at, '${en(dateShort(p.at))}: জমা ${groupEn(p.sarAmount, decimals: 2)} রিয়াল'),
    for (final l in d.losses.where((l) => l.customerId == c.id)) (l.at, '${en(dateShort(l.at))}: আদায় হবে না ধরা হলো ${groupEn(l.sarAmount, decimals: 2)} রিয়াল'),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
  final due = customerDue(d, c.id);
  return '${c.name} — হিসাব\n${rows.map((r) => r.$2).join('\n')}\n'
      'মোট বাকি: ${due > 0 ? '${groupEn(due, decimals: 2)} রিয়াল' : 'নেই'}${_owner(d)}';
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
      q(customerById(d, t.customerId)?.name ?? ''),
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
