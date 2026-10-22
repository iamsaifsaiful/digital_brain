// The zakat count, line by line: every amount the app takes from the user's
// own records (accounts, savings, DPS, what people owe, what the user owes,
// loan instalments), what the user wrote (gold, silver, stock, other) and
// what they added by hand — each with where it came from and when it last
// changed, and each one the user may leave out.
import '../models/models.dart';
import 'bn.dart';
import 'lang.dart';
import 'ledger.dart';
import 'money_more.dart' show accountBalance, ZakatSaved, ZakatInput;

/// The groups, in the order shown.
enum ZakatGroup {
  cash,
  bank,
  savings,
  dps,
  receivable,
  metal,
  business,
  manual,
  payable,
  loan;

  String get title => switch (this) {
        cash => tr('হাতে নগদ ও মোবাইল ব্যাংকিং'),
        bank => tr('ব্যাংকে জমা'),
        savings => tr('সঞ্চয়ের লক্ষ্য'),
        dps => tr('DPS'),
        receivable => tr('পাওনা টাকা'),
        metal => tr('সোনা ও রুপা'),
        business => tr('ব্যবসা ও অন্যান্য'),
        manual => tr('নিজে যোগ করা'),
        payable => tr('দেনা (বাদ যাবে)'),
        loan => tr('লোনের কিস্তি — সামনের ১২ মাস (বাদ যাবে)'),
      };
}

/// One line of the count.
class ZakatLine {
  const ZakatLine({required this.key, required this.group, required this.label, required this.amount, required this.how, this.at, this.debt = false, this.included = true, this.manualId});

  /// Stable across changes (`account:<id>`, `person:<key>`, "gold"…): what
  /// [ZakatBook.excluded] keeps.
  final String key;
  final ZakatGroup group;
  final String label;
  final int amount;

  /// How the app got the amount, in words ("শুরু ৳২,০০০ + ১৪টা লেনদেন").
  final String how;

  /// When it last changed (the newest entry behind it).
  final DateTime? at;

  /// Taken off rather than added.
  final bool debt;
  final bool included;

  /// For a line added by hand: its [ZakatItem.id].
  final String? manualId;
}

String _tk(int n) => taka(n);

DateTime? _latest(Iterable<DateTime> ds) {
  DateTime? m;
  for (final d in ds) {
    if (m == null || d.isAfter(m)) m = d;
  }
  return m;
}

/// Every line, included or not (the screen shows both).
List<ZakatLine> zakatLines(AppData d, DateTime now, ZakatSaved z) {
  final out = <ZakatLine>[];
  final off = d.zakat.excluded;
  void add(String key, ZakatGroup g, String label, int amount, String how, {DateTime? at, bool debt = false, String? manualId}) {
    if (amount <= 0) return;
    out.add(ZakatLine(key: key, group: g, label: label, amount: amount, how: how, at: at, debt: debt, included: !off.contains(key), manualId: manualId));
  }

  for (final a in d.accounts) {
    final bal = accountBalance(d, a);
    final entries = d.cash.where((e) => e.accountId == a.id).toList();
    final moves = d.transfers.where((t) => t.to == a.id || t.from == a.id).toList();
    final n = entries.length + moves.length;
    add('account:${a.id}', a.kind == AccountKind.bank ? ZakatGroup.bank : ZakatGroup.cash, a.name, bal,
        n > 0 ? trf('অ্যাকাউন্টের ব্যালেন্স: শুরু {0} + {1}টা লেনদেন', [_tk(a.opening), bnDigits(n)]) : trf('অ্যাকাউন্টের ব্যালেন্স: শুরু {0}', [_tk(a.opening)]), at: _latest([for (final e in entries) e.date, for (final t in moves) t.date]));
  }
  if (d.accounts.isEmpty) {
    final own = d.cash.where((e) => e.projectId == null).toList();
    final bal = own.fold<int>(0, (s, e) => s + (e.kind == CashKind.income ? e.amount : -e.amount));
    add('cash:estimate', ZakatGroup.cash, tr('আয়-ব্যয়ের ব্যালেন্স'), bal, trf('আয় থেকে খরচ বাদ ({0}টা হিসাব) — আনুমানিক; অ্যাকাউন্ট যোগ করলে ঠিক হিসাব', [bnDigits(own.length)]), at: _latest([for (final e in own) e.date]));
  }
  for (final g in d.goals) {
    add('goal:${g.id}', ZakatGroup.savings, g.name, g.saved, trf('{0}বার জমা', [bnDigits(g.deposits.length)]), at: _latest([for (final x in g.deposits) x.date]));
  }
  for (final i in d.installments.where((i) => i.kind == InstallmentKind.dps)) {
    final last = i.paid.isEmpty ? null : DateTime.tryParse('${(i.paid.toList()..sort()).last}-01');
    add('dps:${i.id}', ZakatGroup.dps, i.name, i.paidTotal, trf('{0}টা কিস্তি × {1}', [bnDigits(i.paidCount), _tk(i.amount)]), at: last);
  }
  for (final p in balances(d.ledger)) {
    if (p.balance > 0) {
      add('person:${p.key}', ZakatGroup.receivable, p.name, p.balance, trf('ধার দিয়েছেন {0}, ফেরত পেয়েছেন {1} ({2}টা হিসাব)', [_tk(p.lentTotal), _tk(p.receivedTotal), bnDigits(p.count)]), at: p.last);
    } else if (p.balance < 0) {
      add('owe:${p.key}', ZakatGroup.payable, p.name, -p.balance, trf('ধার নিয়েছেন {0}, শোধ করেছেন {1} ({2}টা হিসাব)', [_tk(p.borrowedTotal), _tk(p.repaidTotal), bnDigits(p.count)]), at: p.last, debt: true);
    }
  }
  for (final i in d.installments.where((i) => i.kind == InstallmentKind.loan)) {
    final n = i.left < 12 ? i.left : 12;
    add('loan:${i.id}', ZakatGroup.loan, i.name, n * i.amount, trf('{0}টা কিস্তি × {1}', [bnDigits(n), _tk(i.amount)]), debt: true);
  }
  String vori(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
  add('gold', ZakatGroup.metal, tr('সোনা'), (z.goldVori * z.goldPrice).round(), trf('{0} ভরি × {1} (আপনার লেখা)', [bnDigits(vori(z.goldVori)), _tk(z.goldPrice)]));
  add('silver', ZakatGroup.metal, tr('রুপা'), (z.silverVori * z.silverPrice).round(), trf('{0} ভরি × {1} (আপনার লেখা)', [bnDigits(vori(z.silverVori)), _tk(z.silverPrice)]));
  add('business', ZakatGroup.business, tr('ব্যবসার মাল'), z.business, tr('বিক্রয়মূল্যে (আপনার লেখা)'));
  add('other', ZakatGroup.business, tr('অন্যান্য (শেয়ার, বন্ড…)'), z.other, tr('আপনার লেখা'));
  for (final m in d.zakat.items) {
    add('manual:${m.id}', ZakatGroup.manual, m.label, m.amount, m.debt ? tr('নিজে যোগ করা দেনা') : tr('নিজে যোগ করা'), at: m.date, debt: m.debt, manualId: m.id);
  }
  return out;
}

/// The totals from the included lines (nisab: 52.5 ভরি of silver at the price written).
ZakatInput zakatCount(List<ZakatLine> lines, ZakatSaved z) {
  int sum(bool Function(ZakatLine) f) => lines.where((l) => l.included && f(l)).fold(0, (s, l) => s + l.amount);
  return ZakatInput(
    cash: sum((l) => l.group == ZakatGroup.cash),
    bank: sum((l) => l.group == ZakatGroup.bank || l.group == ZakatGroup.savings || l.group == ZakatGroup.dps),
    gold: sum((l) => l.key == 'gold'),
    silver: sum((l) => l.key == 'silver'),
    business: sum((l) => l.group == ZakatGroup.business),
    receivable: sum((l) => l.group == ZakatGroup.receivable),
    other: sum((l) => l.group == ZakatGroup.manual && !l.debt),
    debts: sum((l) => l.debt),
    nisab: (z.silverPrice * 52.5).round(),
  );
}

/// The next zakat day: a lunar year (354 days) after [start], moved on until it is today or later.
DateTime? zakatDueDay(DateTime? start, DateTime now) {
  if (start == null) return null;
  final today = DateTime(now.year, now.month, now.day);
  var d = DateTime(start.year, start.month, start.day).add(const Duration(days: 354));
  while (d.isBefore(today)) {
    d = d.add(const Duration(days: 354));
  }
  return d;
}
