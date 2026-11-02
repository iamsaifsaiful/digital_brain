/// Everything the app keeps. Customers' accounts are in riyal (SAR), the
/// agents' accounts in taka. There is no stored exchange rate: every
/// transaction carries the rate typed for it.
library;

String _s(Object? v, [String d = '']) => v == null ? d : '$v';
double _d(Object? v, [double d = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? d;
int _i(Object? v, [int d = 0]) => v is num ? v.toInt() : int.tryParse('$v') ?? d;
DateTime _t(Object? v) => DateTime.tryParse('$v') ?? DateTime.fromMillisecondsSinceEpoch(0);
List<Map<String, Object?>> _l(Object? v) => [for (final e in (v as List?) ?? const []) (e as Map).cast<String, Object?>()];

/// How the money goes in Bangladesh.
enum Method { bkash, nagad, rocket, bank }

extension MethodText on Method {
  String get bnName => const {Method.bkash: 'বিকাশ', Method.nagad: 'নগদ', Method.rocket: 'রকেট', Method.bank: 'ব্যাংক'}[this]!;
}

Method methodOf(String s) => Method.values.firstWhere((m) => m.name == s, orElse: () => Method.bkash);

/// সেন্ড মানি, ক্যাশ আউট, মোবাইল রিচার্জ বা ইন্টারনেট (এমবি) প্যাক.
enum Kind { send, cashout, recharge, mb }

extension KindText on Kind {
  String get bnName => const {Kind.send: 'সেন্ড মানি', Kind.cashout: 'ক্যাশ আউট', Kind.recharge: 'মোবাইল রিচার্জ', Kind.mb: 'এমবি প্যাক'}[this]!;

  /// Recharge and MB go to a phone, not to a bKash/Nagad account.
  bool get isTopUp => this == Kind.recharge || this == Kind.mb;
}

/// Bangladeshi mobile operators, for recharge and MB.
const operators = ['গ্রামীণফোন', 'রবি', 'এয়ারটেল', 'বাংলালিংক', 'টেলিটক'];

/// The operator a number belongs to, from its prefix (013/017 GP …).
String operatorOf(String number) => switch (number.length >= 3 ? number.substring(0, 3) : '') {
      '013' || '017' => 'গ্রামীণফোন',
      '018' => 'রবি',
      '016' => 'এয়ারটেল',
      '014' || '019' => 'বাংলালিংক',
      '015' => 'টেলিটক',
      _ => '',
    };

/// Whose mistake it was when money went to a wrong number.
enum Fault { mine, agent, customer }

extension FaultText on Fault {
  String get bnName => const {Fault.mine: 'আমার ভুল', Fault.agent: 'এজেন্টের ভুল', Fault.customer: 'গ্রাহকের ভুল (ভুল নম্বর দিয়েছেন)'}[this]!;
  String get short => const {Fault.mine: 'আমার', Fault.agent: 'এজেন্টের', Fault.customer: 'গ্রাহকের'}[this]!;
}

/// How the customer paid the riyal for this transaction.
enum Pay { cash, due, partial }

extension PayText on Pay {
  String get bnName => const {Pay.cash: 'নগদ পেয়েছি', Pay.due: 'বকেয়া', Pay.partial: 'আংশিক'}[this]!;
}

enum TxnStatus { pending, sent, cancelled }

/// A saved number a customer sends to.
class Recipient {
  Recipient({required this.id, required this.label, required this.number, this.method = Method.bkash});
  final String id;
  String label;
  String number;
  Method method;

  Map<String, Object?> toJson() => {'id': id, 'label': label, 'number': number, 'method': method.name};
  factory Recipient.fromJson(Map<String, Object?> j) => Recipient(id: _s(j['id']), label: _s(j['label']), number: _s(j['number']), method: methodOf(_s(j['method'])));
}

class Customer {
  Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.created,
    this.area = '',
    this.photo,
    this.home = '',
    this.salaryDay = '',
    this.dueLimit,
    this.promiseAt,
    this.promiseNote = '',
    this.referrer = '',
    this.note = '',
    List<Recipient>? recipients,
  }) : recipients = recipients ?? [];

  final String id;
  String name;

  /// Saudi mobile (also WhatsApp), as typed.
  String phone;
  String area;

  /// Id of the encrypted photo file, if taken.
  String? photo;
  String home;
  String salaryDay;

  /// Riyal; null = the default limit from settings.
  double? dueLimit;

  /// When the customer said they would pay what they owe (rings then).
  DateTime? promiseAt;
  String promiseNote;
  String referrer;
  String note;
  List<Recipient> recipients;
  DateTime created;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'area': area,
        'photo': photo,
        'home': home,
        'salaryDay': salaryDay,
        'dueLimit': dueLimit,
        'promiseAt': promiseAt?.toIso8601String(),
        'promiseNote': promiseNote,
        'referrer': referrer,
        'note': note,
        'recipients': [for (final r in recipients) r.toJson()],
        'created': created.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, Object?> j) => Customer(
        id: _s(j['id']),
        name: _s(j['name']),
        phone: _s(j['phone']),
        area: _s(j['area']),
        photo: j['photo'] == null ? null : _s(j['photo']),
        home: _s(j['home']),
        salaryDay: _s(j['salaryDay']),
        dueLimit: j['dueLimit'] == null ? null : _d(j['dueLimit']),
        promiseAt: j['promiseAt'] == null ? null : _t(j['promiseAt']),
        promiseNote: _s(j['promiseNote']),
        referrer: _s(j['referrer']),
        note: _s(j['note']),
        recipients: [for (final r in _l(j['recipients'])) Recipient.fromJson(r)],
        created: _t(j['created']),
      );
}

/// A bKash agent (or anyone in Bangladesh who sends the taka).
class Agent {
  Agent({required this.id, required this.name, required this.whatsapp, this.commissionPerThousand = 0, required this.created, this.channel = 'whatsapp', this.deleted = false});
  final String id;
  String name;

  /// The WhatsApp number every message goes to (one chat, always).
  String whatsapp;

  /// Taka per 1,000 taka sent.
  double commissionPerThousand;
  DateTime created;

  /// 'whatsapp' (the message opens in WhatsApp) or 'app' (the agent uses
  /// this app and is told by notification).
  String channel;
  bool get usesApp => channel == 'app';

  /// Deleted by the main admin: gone from every list and choice. Its old
  /// sends and payments keep its name.
  bool deleted;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'whatsapp': whatsapp,
        'commission': commissionPerThousand,
        'created': created.toIso8601String(),
        'channel': channel,
        if (deleted) 'deleted': true,
      };
  factory Agent.fromJson(Map<String, Object?> j) => Agent(
        channel: _s(j['channel'], 'whatsapp'),
        deleted: j['deleted'] == true,
        id: _s(j['id']),
        name: _s(j['name']),
        whatsapp: _s(j['whatsapp']),
        commissionPerThousand: _d(j['commission']),
        created: _t(j['created']),
      );
}

/// One send: riyal taken in Saudi, taka sent in Bangladesh.
class Txn {
  Txn({
    required this.id,
    required this.no,
    required this.customerId,
    required this.recipientLabel,
    required this.number,
    required this.method,
    required this.kind,
    required this.sarAmount,
    required this.rate,
    required this.taka,
    required this.fee,
    required this.agentId,
    required this.pay,
    required this.sarPaid,
    required this.at,
    this.status = TxnStatus.pending,
    this.trxId = '',
    this.sentAt,
    this.agentPaymentId,
    this.note = '',
    this.operator = '',
    this.pack = '',
    this.agentReply = '',
    this.replyTail = '',
    this.changeNotice = '',
    this.walkIn = '',
    this.walkInPhone = '',
    this.fault,
    this.faultNote = '',
    this.by = 0,
    this.byName = '',
    this.replyFrom = '',
  });

  final String id;

  /// Short number shown everywhere and in the agent's message (#1042).
  final int no;
  String customerId;
  String recipientLabel;

  /// 11-digit Bangladeshi number.
  String number;
  Method method;
  Kind kind;
  double sarAmount;
  double rate;

  /// Taka the recipient gets (riyal × rate, rounded).
  double taka;

  /// Cash-out charge in taka, sent on top (0 = none).
  double fee;
  String agentId;
  Pay pay;

  /// Riyal paid at the time of the send (the rest is the customer's due).
  double sarPaid;
  DateTime at;
  TxnStatus status;
  String trxId;
  DateTime? sentAt;

  /// Set when the agent has been paid for this one.
  String? agentPaymentId;
  String note;

  /// Recharge / MB: the operator, and the pack for MB ("৩০ জিবি ৩০ দিন").
  String operator;
  String pack;

  /// The agent's reply as copied ("10000-667"), and the 3 digits in it
  /// (of the agent's own number it was sent from).
  String agentReply;
  String replyTail;

  /// How the reply got here: 'auto' (filled from the copied reply),
  /// 'manual' (an admin typed it), 'agent' (the agent in their app).
  String replyFrom;

  /// Sent without a customer profile: the name (and Saudi number) typed
  /// for this send only. Such a send is always paid in cash.
  String walkIn;
  String walkInPhone;

  /// 'pending' after a change the agent must be told about (amount,
  /// number…), until the admin confirms the message went.
  String changeNotice;

  /// Set when the money went to a wrong number: whose mistake it was.
  Fault? fault;
  String faultNote;

  /// The admin who did it (server user id and name; 0 = before the server).
  int by;
  String byName;

  bool get cancelled => status == TxnStatus.cancelled;

  /// What the agent sends (taka + charge).
  double get agentTaka => taka + fee;

  /// Riyal still owed for this send at the moment it was made.
  double get sarDueAtSend => cancelled ? 0 : (sarAmount - sarPaid).clamp(0, double.infinity).toDouble();

  Txn copy() => Txn.fromJson(toJson());

  Map<String, Object?> toJson() => {
        'id': id,
        'no': no,
        'customerId': customerId,
        'recipientLabel': recipientLabel,
        'number': number,
        'method': method.name,
        'kind': kind.name,
        'sar': sarAmount,
        'rate': rate,
        'taka': taka,
        'fee': fee,
        'agentId': agentId,
        'pay': pay.name,
        'sarPaid': sarPaid,
        'at': at.toIso8601String(),
        'status': status.name,
        'trxId': trxId,
        'sentAt': sentAt?.toIso8601String(),
        'agentPaymentId': agentPaymentId,
        'note': note,
        'operator': operator,
        'pack': pack,
        'agentReply': agentReply,
        'replyTail': replyTail,
        'fault': fault?.name,
        'faultNote': faultNote,
        'by': by,
        'byName': byName,
        'replyFrom': replyFrom,
        'changeNotice': changeNotice,
        'walkIn': walkIn,
        'walkInPhone': walkInPhone,
      };

  factory Txn.fromJson(Map<String, Object?> j) => Txn(
        id: _s(j['id']),
        no: _i(j['no']),
        customerId: _s(j['customerId']),
        recipientLabel: _s(j['recipientLabel']),
        number: _s(j['number']),
        method: methodOf(_s(j['method'])),
        kind: Kind.values.firstWhere((k) => k.name == j['kind'], orElse: () => Kind.send),
        sarAmount: _d(j['sar']),
        rate: _d(j['rate']),
        taka: _d(j['taka']),
        fee: _d(j['fee']),
        agentId: _s(j['agentId']),
        pay: Pay.values.firstWhere((p) => p.name == j['pay'], orElse: () => Pay.due),
        sarPaid: _d(j['sarPaid']),
        at: _t(j['at']),
        status: TxnStatus.values.firstWhere((s) => s.name == j['status'], orElse: () => TxnStatus.pending),
        trxId: _s(j['trxId']),
        sentAt: j['sentAt'] == null ? null : _t(j['sentAt']),
        agentPaymentId: j['agentPaymentId'] == null ? null : _s(j['agentPaymentId']),
        note: _s(j['note']),
        operator: _s(j['operator']),
        pack: _s(j['pack']),
        agentReply: _s(j['agentReply']),
        replyTail: _s(j['replyTail']),
        fault: j['fault'] == null ? null : Fault.values.firstWhere((f) => f.name == j['fault'], orElse: () => Fault.mine),
        faultNote: _s(j['faultNote']),
        by: _i(j['by']),
        byName: _s(j['byName']),
        replyFrom: _s(j['replyFrom']),
        changeNotice: _s(j['changeNotice']),
        walkIn: _s(j['walkIn']),
        walkInPhone: _s(j['walkInPhone']),
      );
}

/// Riyal a customer owed that will not come back (left without paying).
/// It takes the amount off their due but brings no riyal into hand.
class Loss {
  Loss({required this.id, required this.customerId, required this.sarAmount, required this.at, this.note = '', this.by = 0, this.byName = ''});
  final String id;
  final String customerId;
  double sarAmount;
  DateTime at;
  String note;
  /// The admin who did it (server user id and name; 0 = before the server).
  int by;
  String byName;

  Map<String, Object?> toJson() => {'id': id, 'customerId': customerId, 'sar': sarAmount, 'at': at.toIso8601String(), 'note': note, 'by': by, 'byName': byName};
  factory Loss.fromJson(Map<String, Object?> j) =>
      Loss(id: _s(j['id']), customerId: _s(j['customerId']), sarAmount: _d(j['sar']), at: _t(j['at']), note: _s(j['note']), by: _i(j['by']), byName: _s(j['byName']));
}

/// Riyal a customer paid later, against what they owe.
class Deposit {
  Deposit({required this.id, required this.customerId, required this.sarAmount, required this.at, this.way = 'cash', this.note = '', this.by = 0, this.byName = ''});
  final String id;
  final String customerId;
  double sarAmount;
  DateTime at;

  /// 'cash' or 'bank'.
  String way;
  String note;
  /// The admin who did it (server user id and name; 0 = before the server).
  int by;
  String byName;

  Map<String, Object?> toJson() => {'id': id, 'customerId': customerId, 'sar': sarAmount, 'at': at.toIso8601String(), 'way': way, 'note': note, 'by': by, 'byName': byName};
  factory Deposit.fromJson(Map<String, Object?> j) => Deposit(
        id: _s(j['id']),
        customerId: _s(j['customerId']),
        sarAmount: _d(j['sar']),
        at: _t(j['at']),
        way: _s(j['way'], 'cash'),
        note: _s(j['note']),
        by: _i(j['by']),
        byName: _s(j['byName']),
      );
}

/// Taka paid to an agent: for chosen transactions, or as an advance.
class AgentPayment {
  AgentPayment({
    required this.id,
    required this.agentId,
    required this.taka,
    required this.at,
    List<String>? txnIds,
    this.way = 'bank',
    this.note = '',
    this.ref = '',
    this.fromAccount = '',
    this.receipt,
    this.sarAmount = 0,
    this.by = 0,
    this.byName = '',
  }) : txnIds = txnIds ?? [];
  final String id;
  final String agentId;
  double taka;
  DateTime at;
  List<String> txnIds;

  /// How it was paid: one of [payWays].
  String way;
  String note;

  /// Bank/bKash transaction or reference number.
  String ref;

  /// Which account or number it was paid from.
  String fromAccount;

  /// Id of the encrypted photo of the bank receipt, if kept.
  String? receipt;

  /// Riyal that went out of hand for this taka (must be given).
  double sarAmount;
  /// The admin who did it (server user id and name; 0 = before the server).
  int by;
  String byName;

  Map<String, Object?> toJson() => {
        'id': id,
        'agentId': agentId,
        'taka': taka,
        'at': at.toIso8601String(),
        'txnIds': txnIds,
        'way': way,
        'note': note,
        'ref': ref,
        'fromAccount': fromAccount,
        'receipt': receipt,
        'sar': sarAmount,
        'by': by,
        'byName': byName,
      };
  factory AgentPayment.fromJson(Map<String, Object?> j) => AgentPayment(
        id: _s(j['id']),
        agentId: _s(j['agentId']),
        taka: _d(j['taka']),
        at: _t(j['at']),
        txnIds: [for (final t in (j['txnIds'] as List?) ?? const []) '$t'],
        way: _s(j['way'], 'bank'),
        note: _s(j['note']),
        ref: _s(j['ref']),
        fromAccount: _s(j['fromAccount']),
        receipt: j['receipt'] == null ? null : _s(j['receipt']),
        sarAmount: _d(j['sar']),
        by: _i(j['by']),
        byName: _s(j['byName']),
      );
}

/// Ways of paying an agent, with their Bangla names.
const payWays = {'bank': 'ব্যাংক', 'bkash': 'বিকাশ', 'nagad': 'নগদ (অ্যাপ)', 'cash': 'হাতে নগদ', 'hundi': 'অন্যের মাধ্যমে', 'other': 'অন্যভাবে'};

String payWayName(String w) => payWays[w] ?? w;

/// Riyal going out of hand: costs, or riyal sold/handed over.
class Expense {
  Expense({required this.id, required this.category, required this.sarAmount, required this.at, this.note = '', this.by = 0, this.byName = ''});
  final String id;
  String category;
  double sarAmount;
  DateTime at;
  String note;
  /// The admin who did it (server user id and name; 0 = before the server).
  int by;
  String byName;

  Map<String, Object?> toJson() => {'id': id, 'category': category, 'sar': sarAmount, 'at': at.toIso8601String(), 'note': note, 'by': by, 'byName': byName};
  factory Expense.fromJson(Map<String, Object?> j) =>
      Expense(id: _s(j['id']), category: _s(j['category']), sarAmount: _d(j['sar']), at: _t(j['at']), note: _s(j['note']), by: _i(j['by']), byName: _s(j['byName']));
}

/// End-of-day count of riyal in hand.
class DayClose {
  DayClose({required this.id, required this.at, required this.expected, required this.counted, this.note = '', this.by = 0, this.byName = ''});
  final String id;
  final DateTime at;
  final double expected;
  final double counted;
  final String note;

  /// Whose hand was counted.
  final int by;
  final String byName;

  double get difference => counted - expected;

  Map<String, Object?> toJson() => {'id': id, 'at': at.toIso8601String(), 'expected': expected, 'counted': counted, 'note': note, 'by': by, 'byName': byName};
  factory DayClose.fromJson(Map<String, Object?> j) =>
      DayClose(id: _s(j['id']), at: _t(j['at']), expected: _d(j['expected']), counted: _d(j['counted']), note: _s(j['note']), by: _i(j['by']), byName: _s(j['byName']));
}

/// Riyal handed from one admin to another ("কালেকশন বুঝে নেওয়া"). It moves
/// riyal between their hands; the shop's total does not change.
class Handover {
  Handover({required this.id, required this.at, required this.from, required this.fromName, required this.to, required this.toName, required this.sarAmount, this.note = ''});
  final String id;
  final DateTime at;
  final int from;
  final String fromName;
  final int to;
  final String toName;
  final double sarAmount;
  final String note;

  Map<String, Object?> toJson() => {'id': id, 'at': at.toIso8601String(), 'from': from, 'fromName': fromName, 'to': to, 'toName': toName, 'sar': sarAmount, 'note': note};
  factory Handover.fromJson(Map<String, Object?> j) => Handover(
        id: _s(j['id']),
        at: _t(j['at']),
        from: _i(j['from']),
        fromName: _s(j['fromName']),
        to: _i(j['to']),
        toName: _s(j['toName']),
        sarAmount: _d(j['sar']),
        note: _s(j['note']),
      );
}

/// A correction for a send the agent already sent ("অতিরিক্ত হিসাব"): a sent
/// send is never edited, so a mistake is written down here instead. It counts
/// nowhere until an admin adds it to the main account ([applied]).
class Adjust {
  Adjust({
    required this.id,
    required this.at,
    this.txnId = '',
    this.customerId = '',
    this.agentId = '',
    this.sarDue = 0,
    this.sarCash = 0,
    this.takaAgent = 0,
    this.note = '',
    this.applied = false,
    this.appliedAt,
    this.appliedByName = '',
    this.by = 0,
    this.byName = '',
  });
  final String id;
  final DateTime at;
  final String txnId;
  final String customerId;
  final String agentId;

  /// Riyal more (+) or less (−) the customer owes.
  final double sarDue;

  /// Riyal more (+) or less (−) in hand.
  final double sarCash;

  /// Taka more (+) or less (−) owed to the agent.
  final double takaAgent;
  final String note;
  bool applied;
  DateTime? appliedAt;
  String appliedByName;
  int by;
  String byName;

  Map<String, Object?> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'txnId': txnId,
        'customerId': customerId,
        'agentId': agentId,
        'sarDue': sarDue,
        'sarCash': sarCash,
        'takaAgent': takaAgent,
        'note': note,
        'applied': applied,
        'appliedAt': appliedAt?.toIso8601String(),
        'appliedByName': appliedByName,
        'by': by,
        'byName': byName,
      };
  factory Adjust.fromJson(Map<String, Object?> j) => Adjust(
        id: _s(j['id']),
        at: _t(j['at']),
        txnId: _s(j['txnId']),
        customerId: _s(j['customerId']),
        agentId: _s(j['agentId']),
        sarDue: _d(j['sarDue']),
        sarCash: _d(j['sarCash']),
        takaAgent: _d(j['takaAgent']),
        note: _s(j['note']),
        applied: j['applied'] == true,
        appliedAt: j['appliedAt'] == null ? null : _t(j['appliedAt']),
        appliedByName: _s(j['appliedByName']),
        by: _i(j['by']),
        byName: _s(j['byName']),
      );
}

/// One line of the activity log. The log is only ever added to.
class LogEntry {
  LogEntry({String? id, required this.at, required this.kind, required this.title, required this.detail, this.who = 'me', this.ref = ''})
      : id = id ?? 'L${at.microsecondsSinceEpoch.toRadixString(36)}${(title.hashCode ^ detail.hashCode).toUnsigned(32).toRadixString(36)}';
  final String id;
  final DateTime at;

  /// txn, recv, agent, edit, cust, sys
  final String kind;
  final String title;
  final String detail;

  /// 'me' (this phone, no server), 'app' (done by the app itself), or the
  /// name of the admin/agent who did it.
  final String who;

  /// Id of the thing it is about, if any.
  final String ref;

  Map<String, Object?> toJson() => {'id': id, 'at': at.toIso8601String(), 'kind': kind, 'title': title, 'detail': detail, 'who': who, 'ref': ref};
  factory LogEntry.fromJson(Map<String, Object?> j) => LogEntry(
        id: j['id'] == null || '${j['id']}'.isEmpty ? null : _s(j['id']),
        at: _t(j['at']),
        kind: _s(j['kind'], 'sys'),
        title: _s(j['title']),
        detail: _s(j['detail']),
        who: _s(j['who'], 'me'),
        ref: _s(j['ref']),
      );
}

class Settings {
  Settings({this.ownerName = '', this.defaultDueLimit = 1000, this.oldDueDays = 7, this.dupMinutes = 10, this.nextNo = 1001, this.lastBackup, Map<String, String>? templates}) : templates = templates ?? {};
  String ownerName;
  double defaultDueLimit;
  int oldDueDays;
  int dupMinutes;
  int nextNo;
  DateTime? lastBackup;

  /// Admin-edited message texts, by template key (missing = the default).
  final Map<String, String> templates;

  /// What all admins share (kept on the server).
  Map<String, Object?> shared() => {'ownerName': ownerName, 'defaultDueLimit': defaultDueLimit, 'oldDueDays': oldDueDays, 'dupMinutes': dupMinutes, 'templates': templates};

  void applyShared(Map<String, Object?> j) {
    ownerName = _s(j['ownerName'], ownerName);
    defaultDueLimit = _d(j['defaultDueLimit'], defaultDueLimit);
    oldDueDays = _i(j['oldDueDays'], oldDueDays);
    dupMinutes = _i(j['dupMinutes'], dupMinutes);
    if (j['templates'] is Map) {
      templates
        ..clear()
        ..addAll(_tpl(j['templates']));
    }
  }

  Map<String, Object?> toJson() => {
        'ownerName': ownerName,
        'defaultDueLimit': defaultDueLimit,
        'oldDueDays': oldDueDays,
        'dupMinutes': dupMinutes,
        'nextNo': nextNo,
        'lastBackup': lastBackup?.toIso8601String(),
        'templates': templates,
      };
  factory Settings.fromJson(Map<String, Object?> j) => Settings(
        ownerName: _s(j['ownerName']),
        defaultDueLimit: _d(j['defaultDueLimit'], 1000),
        oldDueDays: _i(j['oldDueDays'], 7),
        dupMinutes: _i(j['dupMinutes'], 10),
        nextNo: _i(j['nextNo'], 1001),
        lastBackup: j['lastBackup'] == null ? null : _t(j['lastBackup']),
        templates: _tpl(j['templates']),
      );
}

Map<String, String> _tpl(Object? j) => j is Map ? {for (final e in j.entries) if (e.value is String) '${e.key}': e.value as String} : {};

class AppData {
  AppData({
    Settings? settings,
    List<Customer>? customers,
    List<Agent>? agents,
    List<Txn>? txns,
    List<Deposit>? deposits,
    List<AgentPayment>? agentPayments,
    List<Expense>? expenses,
    List<DayClose>? closes,
    List<Loss>? losses,
    List<Handover>? handovers,
    List<Adjust>? adjusts,
    List<LogEntry>? log,
  })  : settings = settings ?? Settings(),
        customers = customers ?? [],
        agents = agents ?? [],
        txns = txns ?? [],
        deposits = deposits ?? [],
        agentPayments = agentPayments ?? [],
        expenses = expenses ?? [],
        closes = closes ?? [],
        losses = losses ?? [],
        handovers = handovers ?? [],
        adjusts = adjusts ?? [],
        log = log ?? [];

  Settings settings;

  /// This phone's place in the server's changes, what it last sent or got
  /// of each record (hash), which photos are up, and its send numbers.
  SyncState sync = SyncState();
  List<Customer> customers;
  List<Agent> agents;

  /// The agents still in use (not deleted).
  List<Agent> get liveAgents => agents.where((a) => !a.deleted).toList();
  List<Txn> txns;
  List<Deposit> deposits;
  List<AgentPayment> agentPayments;
  List<Expense> expenses;
  List<DayClose> closes;
  List<Loss> losses;
  List<Handover> handovers;
  List<Adjust> adjusts;
  List<LogEntry> log;

  Map<String, Object?> toJson() => {
        'v': 1,
        'settings': settings.toJson(),
        'sync': sync.toJson(),
        'customers': [for (final x in customers) x.toJson()],
        'agents': [for (final x in agents) x.toJson()],
        'txns': [for (final x in txns) x.toJson()],
        'deposits': [for (final x in deposits) x.toJson()],
        'agentPayments': [for (final x in agentPayments) x.toJson()],
        'expenses': [for (final x in expenses) x.toJson()],
        'closes': [for (final x in closes) x.toJson()],
        'losses': [for (final x in losses) x.toJson()],
        'handovers': [for (final x in handovers) x.toJson()],
        'adjusts': [for (final x in adjusts) x.toJson()],
        'log': [for (final x in log) x.toJson()],
      };

  factory AppData.fromJson(Map<String, Object?> j) {
    final p = _AppDataParts(j);
    return AppData(
      settings: p.settings,
      customers: p.customers,
      agents: p.agents,
      txns: p.txns,
      deposits: p.deposits,
      agentPayments: p.agentPayments,
      expenses: p.expenses,
      closes: p.closes,
      losses: p.losses,
      handovers: p.handovers,
      adjusts: p.adjusts,
      log: p.log,
    )..sync = SyncState.fromJson(((j['sync'] as Map?) ?? const {}).cast<String, Object?>());
  }
}

class _AppDataParts {
  _AppDataParts(Map<String, Object?> j)
      : settings = Settings.fromJson(((j['settings'] as Map?) ?? const {}).cast<String, Object?>()),
        customers = [for (final x in _l(j['customers'])) Customer.fromJson(x)],
        agents = [for (final x in _l(j['agents'])) Agent.fromJson(x)],
        txns = [for (final x in _l(j['txns'])) Txn.fromJson(x)],
        deposits = [for (final x in _l(j['deposits'])) Deposit.fromJson(x)],
        agentPayments = [for (final x in _l(j['agentPayments'])) AgentPayment.fromJson(x)],
        expenses = [for (final x in _l(j['expenses'])) Expense.fromJson(x)],
        closes = [for (final x in _l(j['closes'])) DayClose.fromJson(x)],
        losses = [for (final x in _l(j['losses'])) Loss.fromJson(x)],
        handovers = [for (final x in _l(j['handovers'])) Handover.fromJson(x)],
        adjusts = [for (final x in _l(j['adjusts'])) Adjust.fromJson(x)],
        log = [for (final x in _l(j['log'])) LogEntry.fromJson(x)];
  final Settings settings;
  final List<Customer> customers;
  final List<Agent> agents;
  final List<Txn> txns;
  final List<Deposit> deposits;
  final List<AgentPayment> agentPayments;
  final List<Expense> expenses;
  final List<DayClose> closes;
  final List<Loss> losses;
  final List<Handover> handovers;
  final List<Adjust> adjusts;
  final List<LogEntry> log;
}

/// See [AppData.sync].
class SyncState {
  SyncState({this.rev = 0, Map<String, String>? hashes, Set<String>? photosUp, List<int>? numbers, this.numbersYm = ''})
      : hashes = hashes ?? {},
        photosUp = photosUp ?? {},
        numbers = numbers ?? [];
  int rev;
  Map<String, String> hashes;
  Set<String> photosUp;
  List<int> numbers;

  /// The month ("2611") the kept numbers belong to.
  String numbersYm;

  Map<String, Object?> toJson() => {'rev': rev, 'hashes': hashes, 'photosUp': photosUp.toList(), 'numbers': numbers, 'numbersYm': numbersYm};
  factory SyncState.fromJson(Map<String, Object?> j) => SyncState(
        rev: _i(j['rev']),
        hashes: {for (final e in ((j['hashes'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
        photosUp: {for (final x in (j['photosUp'] as List?) ?? const []) '$x'},
        numbers: [for (final x in (j['numbers'] as List?) ?? const []) _i(x)],
        numbersYm: _s(j['numbersYm']),
      );
}

/// "2611" for November 2026: the first part of a send's number.
String yearMonth(DateTime t) => '${(t.year % 100).toString().padLeft(2, '0')}${t.month.toString().padLeft(2, '0')}';

/// Send numbers are year, month and the month's serial: 26110001 is the
/// first send of November 2026.
int sendNumber(String ym, int serial) => int.parse(ym) * 10000 + serial;
