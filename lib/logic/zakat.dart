// The zakat count, line by line: every amount the app takes from the user's
// own records (accounts, savings, DPS, what people owe, what the user owes,
// loan instalments), what the user wrote (gold, silver, stock, other) and
// what they added by hand — each with where it came from and when it last
// changed, and each one the user may leave out.
import '../models/models.dart';
import 'bn.dart';
import 'cash.dart' show cashOnHand, cashStartOf, cashNowParts, cashSinceStart;
import 'lang.dart';
import 'ledger.dart';
import 'money_more.dart' show accountBalance, GoldPiece, ZakatSaved, ZakatInput;
import 'shop_logic.dart' show bizCashBalance, customerAccount, dealerAccount, isBizCash, qtyText;

/// নিসাব by weight: সাড়ে ৫২ তোলা (ভরি) রুপা ≈ ৬১২.৩৬ গ্রাম; সাড়ে ৭ তোলা সোনা ≈ ৮৭.৪৮ গ্রাম.
const nisabSilverVori = 52.5;
const nisabGoldVori = 7.5;

/// The carats বাজুস gives a price for.
const goldCarats = [('22k', '২২ ক্যারেট'), ('21k', '২১ ক্যারেট'), ('18k', '১৮ ক্যারেট'), ('traditional', 'সনাতন')];

/// A piece of gold's name: its carat, or what the member called an 'other' one.
String goldPieceName(GoldPiece g) {
  if (g.carat == 'other') return g.label.isEmpty ? tr('অন্যান্য সোনা') : g.label;
  for (final (k, label) in goldCarats) {
    if (k == g.carat) return trf('সোনা — {0}', [tr(label)]);
  }
  return tr('সোনা');
}

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
  apart,
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
        apart => tr('আলাদা রাখা হিসাব — টাকা আপনার নিজের হলে টিক দিন'),
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
    // A হিসাব kept apart is left out unless the member ticks it ("+project:…").
    final on = key.startsWith('project:') ? off.contains('+$key') : !off.contains(key);
    out.add(ZakatLine(key: key, group: g, label: label, amount: amount, how: how, at: at, debt: debt, included: on, manualId: manualId));
  }

  // "এখন আছে" said (owner, 24 Oct): zakat counts from it — the amount then,
  // with every আয়-ব্যয়, loan and বকেয়া since (accounts are not added again).
  final now$ = cashOnHand(d);
  if (now$ != null) {
    final start = cashStartOf(d)!;
    final parts = cashNowParts(d);
    final how = [
      trf('শুরুতে {0} ({1})', [_tk(start.$1), shortDate(start.$2)]),
      for (final (k, v) in parts) '${tr(k)} ${v < 0 ? '−' : '+'}${_tk(v.abs())}',
    ].join(' · ');
    add('cash:now', ZakatGroup.cash, tr('এখন আছে'), now$, how, at: _latest([start.$2, for (final e in cashSinceStart(d)) e.addedAt ?? e.date]));
  } else {
    for (final a in d.accounts) {
      final bal = accountBalance(d, a);
      final entries = d.cash.where((e) => e.accountId == a.id && e.projectId == null).toList();
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
  }
  for (final g in d.goals) {
    add('goal:${g.id}', ZakatGroup.savings, g.name, g.saved, trf('{0}বার জমা', [bnDigits(g.deposits.length)]), at: _latest([for (final x in g.deposits) x.date]));
  }
  for (final i in d.installments.where((i) => i.kind == InstallmentKind.dps)) {
    final last = i.paid.isEmpty ? null : DateTime.tryParse('${(i.paid.toList()..sort()).last}-01');
    add('dps:${i.id}', ZakatGroup.dps, i.name, i.paidTotal, trf('{0}টা কিস্তি × {1}', [bnDigits(i.paidCount), _tk(i.amount)]), at: last);
  }
  // A হিসাব kept apart from the main money (owner, 28 Oct): its বকেয়া is not the member's own wealth or debt.
  final apart = {for (final p in d.projects) if (!p.inMain) p.id};
  final ledger = [for (final e in d.ledger) if (e.projectId == null || !apart.contains(e.projectId)) e];
  final dueKeys = {for (final e in ledger.where((e) => e.projectId != null)) accountKeys(ledger)[e.id]};
  for (final p in balances(ledger)) {
    final due = dueKeys.contains(p.key) ? ' · ${tr('বকেয়া')}' : '';
    if (p.balance > 0) {
      add('person:${p.key}', ZakatGroup.receivable, '${p.name}$due', p.balance, trf('ধার দিয়েছেন {0}, ফেরত পেয়েছেন {1} ({2}টা হিসাব)', [_tk(p.lentTotal), _tk(p.receivedTotal), bnDigits(p.count)]), at: p.last);
    } else if (p.balance < 0) {
      add('owe:${p.key}', ZakatGroup.payable, '${p.name}$due', -p.balance, trf('ধার নিয়েছেন {0}, শোধ করেছেন {1} ({2}টা হিসাব)', [_tk(p.borrowedTotal), _tk(p.repaidTotal), bnDigits(p.count)]), at: p.last, debt: true);
    }
  }
  // A হিসাব kept apart from the main money (a committee's, a mosque's, or
  // someone else's money kept by the member) is not counted — but if the
  // money is the member's own, zakat is due on it too: shown, unticked.
  for (final p in d.projects.where((p) => !p.inMain)) {
    var hand = 0;
    final own = d.cash.where((e) => e.projectId == p.id).toList();
    for (final e in own) {
      hand += e.kind == CashKind.income ? e.amount : -e.amount;
    }
    var get = 0, give = 0;
    for (final b in balances([for (final e in d.ledger) if (e.projectId == p.id) e])) {
      if (b.balance > 0) get += b.balance;
      if (b.balance < 0) give -= b.balance;
    }
    final net = hand + get - give;
    final how = [
      trf('হাতে {0}', [_tk(hand)]),
      if (get > 0) trf('বকেয়া পাবেন {0}', [_tk(get)]),
      if (give > 0) trf('বকেয়া দেবেন {0}', [_tk(give)]),
    ].join(' · ');
    if (net > 0) {
      add('project:${p.id}', ZakatGroup.apart, p.name, net, how, at: _latest([for (final e in own) e.date]));
    } else if (net < 0) {
      add('project:${p.id}', ZakatGroup.apart, p.name, -net, how, at: _latest([for (final e in own) e.date]), debt: true);
    }
  }
  for (final i in d.installments.where((i) => i.kind == InstallmentKind.loan)) {
    final n = i.left < 12 ? i.left : 12;
    add('loan:${i.id}', ZakatGroup.loan, i.name, n * i.amount, trf('{0}টা কিস্তি × {1}', [bnDigits(n), _tk(i.amount)]), debt: true);
  }
  String vori(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
  // Each kind of gold on its own line, at its own price (owner, 29 Oct).
  for (final g in z.pieces) {
    add(g.key, ZakatGroup.metal, goldPieceName(g), g.value, trf('{0} ভরি × {1} (আপনার লেখা)', [bnDigits(vori(g.vori)), _tk(g.price)]));
  }
  add('silver', ZakatGroup.metal, tr('রুপা'), (z.silverVori * z.silverPrice).round(), trf('{0} ভরি × {1} (আপনার লেখা)', [bnDigits(vori(z.silverVori)), _tk(z.silverPrice)]));
  // ব্যবসায়ী মোড (owner, 6 Nov: "ব্যবসায়ী হিসাব এই প্রোফাইলেই থাকবে। যাকাতের
  // ক্ষেত্রে হিসাব নিবে শুধু, ব্যবসা থেকে এসেছে তা উল্লেখ থাকবে"): the shop's
  // stock at its selling price, what customers owe and what is owed to
  // dealers, each marked as from the business. (The shop's cash is in
  // আয়-ব্যয় already, so it is counted with the rest of the cash.)
  final shop = d.shop;
  final stocked = [for (final p in shop.products) if (p.stock > 0 && (p.sell > 0 || p.buy > 0)) p];
  if (stocked.isNotEmpty) {
    final value = stocked.fold<int>(0, (s, p) => s + (p.stock * (p.sell > 0 ? p.sell : p.buy)).round());
    final units = stocked.fold<double>(0, (s, p) => s + p.stock);
    add('shop:stock', ZakatGroup.business, '${tr('দোকানের স্টক')} · ${tr('ব্যবসা থেকে')}', value,
        trf('{0}টি পণ্য, মোট {1} একক — বিক্রয়মূল্যে; ব্যবসায়ী মোডের স্টক থেকে', [bnDigits(stocked.length), bnDigits(qtyText(units))]));
  }
  // The business's own cash (sales and collections in, costs out).
  final bizNet = bizCashBalance(d.cash);
  if (bizNet > 0) {
    add('shop:cash', ZakatGroup.cash, '${tr('ব্যবসার নগদ')} · ${tr('ব্যবসা থেকে')}', bizNet, tr('ব্যবসায়ী মোডের আয় থেকে খরচ বাদ — বিক্রি, বাকি আদায়, মাল কেনা আর দোকানের খরচ'),
        at: _latest([for (final e in d.cash.where(isBizCash)) e.date]));
  }
  final owing = [for (final c in shop.customers) customerAccount(shop, c)].where((a) => a.due > 0).toList();
  if (owing.isNotEmpty) {
    add('shop:customers', ZakatGroup.receivable, '${tr('গ্রাহকের বাকি')} · ${tr('ব্যবসা থেকে')}', owing.fold<int>(0, (s, a) => s + a.due),
        trf('{0} জন গ্রাহকের কাছে পাওনা — ব্যবসায়ী মোডের হিসাব থেকে; আদায় হবে না এমন বাকি থাকলে বাদ দিন', [bnDigits(owing.length)]),
        at: _latest([for (final a in owing) if (a.last != null) a.last!]));
  }
  final owed = [for (final x in shop.dealers) dealerAccount(shop, x)].where((a) => a.due > 0).toList();
  if (owed.isNotEmpty) {
    add('shop:dealers', ZakatGroup.payable, '${tr('ডিলারের দেনা')} · ${tr('ব্যবসা থেকে')}', owed.fold<int>(0, (s, a) => s + a.due),
        trf('{0} জন ডিলারকে দিতে হবে — ব্যবসায়ী মোডের হিসাব থেকে', [bnDigits(owed.length)]),
        at: _latest([for (final a in owed) if (a.last != null) a.last!]), debt: true);
  }
  add('business', ZakatGroup.business, stocked.isEmpty ? tr('ব্যবসার মাল') : tr('অন্য ব্যবসার মাল'), z.business, tr('বিক্রয়মূল্যে (আপনার লেখা)'));
  add('other', ZakatGroup.business, tr('অন্যান্য (শেয়ার, বন্ড…)'), z.other, tr('আপনার লেখা'));
  for (final m in d.zakat.items) {
    add('manual:${m.id}', ZakatGroup.manual, m.label, m.amount, m.debt ? tr('নিজে যোগ করা দেনা') : tr('নিজে যোগ করা'), at: m.date, debt: m.debt, manualId: m.id);
  }
  return out;
}

bool _isGold(ZakatLine l) => l.key == 'gold' || l.key.startsWith('gold:');

/// The totals from the included lines. Nisab, as renowned scholars advise:
/// 52.5 ভরি of silver at the price written — the lower one, for wealth of
/// more than one kind; when the member has only gold, 7.5 ভরি of gold — by
/// weight, whatever its carats (its value at the gold's own average price).
ZakatInput zakatCount(List<ZakatLine> lines, ZakatSaved z) {
  int sum(bool Function(ZakatLine) f) => lines.where((l) => l.included && f(l)).fold(0, (s, l) => s + l.amount);
  final gold = sum(_isGold);
  final others = sum((l) => !l.debt && !_isGold(l));
  final onlyGold = gold > 0 && others == 0;
  final on = {for (final l in lines) if (l.included && _isGold(l)) l.key};
  final goldVori = z.pieces.where((g) => on.contains(g.key)).fold<double>(0, (s, g) => s + g.vori);
  final goldNisab = goldVori > 0 ? (gold / goldVori * nisabGoldVori).round() : (z.goldPrice * nisabGoldVori).round();
  return ZakatInput(
    byGold: onlyGold,
    cash: sum((l) => l.group == ZakatGroup.cash),
    bank: sum((l) => l.group == ZakatGroup.bank || l.group == ZakatGroup.savings || l.group == ZakatGroup.dps),
    gold: gold,
    silver: sum((l) => l.key == 'silver'),
    business: sum((l) => l.group == ZakatGroup.business),
    receivable: sum((l) => l.group == ZakatGroup.receivable),
    other: sum((l) => (l.group == ZakatGroup.manual || l.group == ZakatGroup.apart) && !l.debt),
    debts: sum((l) => l.debt),
    nisab: onlyGold ? goldNisab : (z.silverPrice * nisabSilverVori).round(),
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
