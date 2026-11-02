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

/// সেন্ড মানি বা ক্যাশ আউট.
enum Kind { send, cashout }

extension KindText on Kind {
  String get bnName => this == Kind.send ? 'সেন্ড মানি' : 'ক্যাশ আউট';
}

/// How the customer paid the riyal for this transaction.
enum Pay { cash, due, partial }

extension PayText on Pay {
  String get bnName => const {Pay.cash: 'নগদ পেয়েছি', Pay.due: 'বাকি', Pay.partial: 'আংশিক'}[this]!;
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
  factory Recipient.fromJson(Map<String, Object?> j) =>
      Recipient(id: _s(j['id']), label: _s(j['label']), number: _s(j['number']), method: methodOf(_s(j['method'])));
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
        referrer: _s(j['referrer']),
        note: _s(j['note']),
        recipients: [for (final r in _l(j['recipients'])) Recipient.fromJson(r)],
        created: _t(j['created']),
      );
}

/// A bKash agent (or anyone in Bangladesh who sends the taka).
class Agent {
  Agent({required this.id, required this.name, required this.whatsapp, this.commissionPerThousand = 0, required this.created});
  final String id;
  String name;

  /// The WhatsApp number every message goes to (one chat, always).
  String whatsapp;

  /// Taka per 1,000 taka sent.
  double commissionPerThousand;
  DateTime created;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'whatsapp': whatsapp,
        'commission': commissionPerThousand,
        'created': created.toIso8601String(),
      };
  factory Agent.fromJson(Map<String, Object?> j) => Agent(
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
      );
}

/// Riyal a customer paid later, against what they owe.
class Deposit {
  Deposit({required this.id, required this.customerId, required this.sarAmount, required this.at, this.way = 'cash', this.note = ''});
  final String id;
  final String customerId;
  double sarAmount;
  DateTime at;

  /// 'cash' or 'bank'.
  String way;
  String note;

  Map<String, Object?> toJson() =>
      {'id': id, 'customerId': customerId, 'sar': sarAmount, 'at': at.toIso8601String(), 'way': way, 'note': note};
  factory Deposit.fromJson(Map<String, Object?> j) => Deposit(
        id: _s(j['id']),
        customerId: _s(j['customerId']),
        sarAmount: _d(j['sar']),
        at: _t(j['at']),
        way: _s(j['way'], 'cash'),
        note: _s(j['note']),
      );
}

/// Taka paid to an agent: for chosen transactions, or as an advance.
class AgentPayment {
  AgentPayment({required this.id, required this.agentId, required this.taka, required this.at, List<String>? txnIds, this.way = 'bank', this.note = ''})
      : txnIds = txnIds ?? [];
  final String id;
  final String agentId;
  double taka;
  DateTime at;
  List<String> txnIds;
  String way;
  String note;

  Map<String, Object?> toJson() =>
      {'id': id, 'agentId': agentId, 'taka': taka, 'at': at.toIso8601String(), 'txnIds': txnIds, 'way': way, 'note': note};
  factory AgentPayment.fromJson(Map<String, Object?> j) => AgentPayment(
        id: _s(j['id']),
        agentId: _s(j['agentId']),
        taka: _d(j['taka']),
        at: _t(j['at']),
        txnIds: [for (final t in (j['txnIds'] as List?) ?? const []) '$t'],
        way: _s(j['way'], 'bank'),
        note: _s(j['note']),
      );
}

/// Riyal going out of hand: costs, or riyal sold/handed over.
class Expense {
  Expense({required this.id, required this.category, required this.sarAmount, required this.at, this.note = ''});
  final String id;
  String category;
  double sarAmount;
  DateTime at;
  String note;

  Map<String, Object?> toJson() => {'id': id, 'category': category, 'sar': sarAmount, 'at': at.toIso8601String(), 'note': note};
  factory Expense.fromJson(Map<String, Object?> j) =>
      Expense(id: _s(j['id']), category: _s(j['category']), sarAmount: _d(j['sar']), at: _t(j['at']), note: _s(j['note']));
}

/// End-of-day count of riyal in hand.
class DayClose {
  DayClose({required this.id, required this.at, required this.expected, required this.counted, this.note = ''});
  final String id;
  final DateTime at;
  final double expected;
  final double counted;
  final String note;

  double get difference => counted - expected;

  Map<String, Object?> toJson() => {'id': id, 'at': at.toIso8601String(), 'expected': expected, 'counted': counted, 'note': note};
  factory DayClose.fromJson(Map<String, Object?> j) =>
      DayClose(id: _s(j['id']), at: _t(j['at']), expected: _d(j['expected']), counted: _d(j['counted']), note: _s(j['note']));
}

/// One line of the activity log. The log is only ever added to.
class LogEntry {
  LogEntry({required this.at, required this.kind, required this.title, required this.detail, this.who = 'me', this.ref = ''});
  final DateTime at;

  /// txn, recv, agent, edit, cust, sys
  final String kind;
  final String title;
  final String detail;

  /// 'me' (the owner on this phone) or 'app' (done by the app itself).
  final String who;

  /// Id of the thing it is about, if any.
  final String ref;

  Map<String, Object?> toJson() => {'at': at.toIso8601String(), 'kind': kind, 'title': title, 'detail': detail, 'who': who, 'ref': ref};
  factory LogEntry.fromJson(Map<String, Object?> j) => LogEntry(
        at: _t(j['at']),
        kind: _s(j['kind'], 'sys'),
        title: _s(j['title']),
        detail: _s(j['detail']),
        who: _s(j['who'], 'me'),
        ref: _s(j['ref']),
      );
}

class Settings {
  Settings({this.ownerName = '', this.defaultDueLimit = 1000, this.oldDueDays = 7, this.dupMinutes = 10, this.nextNo = 1001, this.lastBackup});
  String ownerName;
  double defaultDueLimit;
  int oldDueDays;
  int dupMinutes;
  int nextNo;
  DateTime? lastBackup;

  Map<String, Object?> toJson() => {
        'ownerName': ownerName,
        'defaultDueLimit': defaultDueLimit,
        'oldDueDays': oldDueDays,
        'dupMinutes': dupMinutes,
        'nextNo': nextNo,
        'lastBackup': lastBackup?.toIso8601String(),
      };
  factory Settings.fromJson(Map<String, Object?> j) => Settings(
        ownerName: _s(j['ownerName']),
        defaultDueLimit: _d(j['defaultDueLimit'], 1000),
        oldDueDays: _i(j['oldDueDays'], 7),
        dupMinutes: _i(j['dupMinutes'], 10),
        nextNo: _i(j['nextNo'], 1001),
        lastBackup: j['lastBackup'] == null ? null : _t(j['lastBackup']),
      );
}

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
    List<LogEntry>? log,
  })  : settings = settings ?? Settings(),
        customers = customers ?? [],
        agents = agents ?? [],
        txns = txns ?? [],
        deposits = deposits ?? [],
        agentPayments = agentPayments ?? [],
        expenses = expenses ?? [],
        closes = closes ?? [],
        log = log ?? [];

  Settings settings;
  List<Customer> customers;
  List<Agent> agents;
  List<Txn> txns;
  List<Deposit> deposits;
  List<AgentPayment> agentPayments;
  List<Expense> expenses;
  List<DayClose> closes;
  List<LogEntry> log;

  Map<String, Object?> toJson() => {
        'v': 1,
        'settings': settings.toJson(),
        'customers': [for (final x in customers) x.toJson()],
        'agents': [for (final x in agents) x.toJson()],
        'txns': [for (final x in txns) x.toJson()],
        'deposits': [for (final x in deposits) x.toJson()],
        'agentPayments': [for (final x in agentPayments) x.toJson()],
        'expenses': [for (final x in expenses) x.toJson()],
        'closes': [for (final x in closes) x.toJson()],
        'log': [for (final x in log) x.toJson()],
      };

  factory AppData.fromJson(Map<String, Object?> j) => AppData(
        settings: Settings.fromJson(((j['settings'] as Map?) ?? const {}).cast<String, Object?>()),
        customers: [for (final x in _l(j['customers'])) Customer.fromJson(x)],
        agents: [for (final x in _l(j['agents'])) Agent.fromJson(x)],
        txns: [for (final x in _l(j['txns'])) Txn.fromJson(x)],
        deposits: [for (final x in _l(j['deposits'])) Deposit.fromJson(x)],
        agentPayments: [for (final x in _l(j['agentPayments'])) AgentPayment.fromJson(x)],
        expenses: [for (final x in _l(j['expenses'])) Expense.fromJson(x)],
        closes: [for (final x in _l(j['closes'])) DayClose.fromJson(x)],
        log: [for (final x in _l(j['log'])) LogEntry.fromJson(x)],
      );
}
