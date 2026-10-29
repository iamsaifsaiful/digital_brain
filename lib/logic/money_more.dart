/// Accounts, the monthly report, zakat and splitting a bill.
library;

import 'zakat.dart' show zakatCount, zakatLines;
import '../models/models.dart';
import 'bn.dart';
import 'lang.dart';
import 'cash.dart' show categoryFor;
import 'ledger.dart';
import 'parser.dart' show normalize;

/// What [a] holds now: what it started with, money in and out through it,
/// and moves between the user's own accounts.
int accountBalance(AppData d, MoneyAccount a) {
  var b = a.opening;
  for (final e in d.cash) {
    // Another হিসাব's own entry is never the account's money: when that হিসাব
    // is in the main money, its main-money line (no project) counts instead.
    if (e.accountId != a.id || e.projectId != null) continue;
    b += e.kind == CashKind.income ? e.amount : -e.amount;
  }
  for (final t in d.transfers) {
    if (t.to == a.id) b += t.amount;
    if (t.from == a.id) b -= t.amount + t.fee;
  }
  return b;
}

int totalBalance(AppData d) => d.accounts.fold(0, (s, a) => s + accountBalance(d, a));

String accountLabel(MoneyAccount a) => a.name.trim().isEmpty ? (isEn ? a.kind.en : a.kind.bn) : a.name;

/// A month's spending by category, with last month beside it.
class MonthReport {
  MonthReport(this.month, this.income, this.expense, this.byCategory, this.lastByCategory, this.lastExpense, this.byDay);
  final DateTime month;
  final int income;
  final int expense;

  /// Category → spent, largest first.
  final List<MapEntry<String, int>> byCategory;
  final Map<String, int> lastByCategory;
  final int lastExpense;

  /// Day of month → spent.
  final Map<int, int> byDay;

  int get balance => income - expense;

  /// The category that grew the most against last month (and by how much).
  MapEntry<String, int>? get biggestRise {
    MapEntry<String, int>? best;
    for (final e in byCategory) {
      final rise = e.value - (lastByCategory[e.key] ?? 0);
      if (rise > 0 && (best == null || rise > best.value)) best = MapEntry(e.key, rise);
    }
    return best;
  }
}

/// The খাত a spending is counted under: its own, or — when it was left as
/// অন্যান্য — one guessed from its note ("রিকশা" → যাতায়াত).
String reportCategory(CashEntry e) {
  if (e.kind != CashKind.expense || (e.category != 'অন্যান্য' && e.category.trim().isNotEmpty) || e.note.trim().isEmpty) return e.category.trim().isEmpty ? 'অন্যান্য' : e.category;
  return categoryFor(normalize(e.note), CashKind.expense);
}

MonthReport monthReport(AppData d, DateTime month) {
  bool inMonth(DateTime x, DateTime m) => x.year == m.year && x.month == m.month;
  final last = DateTime(month.year, month.month - 1);
  var income = 0, expense = 0, lastExpense = 0;
  final cats = <String, int>{}, lastCats = <String, int>{}, days = <int, int>{};
  for (final e in d.cash) {
    if (e.projectId != null) continue;
    if (inMonth(e.date, month)) {
      if (e.kind == CashKind.income) {
        income += e.amount;
      } else {
        expense += e.amount;
        cats[reportCategory(e)] = (cats[reportCategory(e)] ?? 0) + e.amount;
        days[e.date.day] = (days[e.date.day] ?? 0) + e.amount;
      }
    } else if (inMonth(e.date, last) && e.kind == CashKind.expense) {
      lastExpense += e.amount;
      lastCats[reportCategory(e)] = (lastCats[reportCategory(e)] ?? 0) + e.amount;
    }
  }
  final sorted = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return MonthReport(month, income, expense, sorted, lastCats, lastExpense, days);
}

/// Plain sentences about the month: where most went, what grew, how it compares.
List<String> reportInsights(MonthReport r) {
  final out = <String>[];
  if (r.expense == 0) return out;
  final top = r.byCategory.first;
  out.add(trf('সবচেয়ে বেশি খরচ হয়েছে {0}-এ — {1} (মোট খরচের {2}%)।', [top.key, taka(top.value), bnDigits((top.value * 100 / r.expense).round())]));
  final rise = r.biggestRise;
  if (rise != null && r.lastExpense > 0) {
    out.add(trf('গত মাসের চেয়ে {0}-এ {1} বেশি গেছে।', [rise.key, taka(rise.value)]));
  }
  if (r.lastExpense > 0) {
    final diff = r.expense - r.lastExpense;
    out.add(diff > 0
        ? trf('মোট খরচ গত মাসের চেয়ে {0} বেশি।', [taka(diff)])
        : (diff < 0 ? trf('মোট খরচ গত মাসের চেয়ে {0} কম — ভালো!', [taka(-diff)]) : tr('মোট খরচ গত মাসের সমান।')));
  }
  if (r.income > 0) {
    final saved = r.income - r.expense;
    out.add(saved >= 0
        ? trf('মাসের ব্যালেন্স {0} — আয়ের {1}%।', [taka(saved), bnDigits((saved * 100 / r.income).round())])
        : trf('আয়ের চেয়ে {0} বেশি খরচ হয়েছে।', [taka(-saved)]));
  }
  return out;
}

/// Zakat: 2.5% of zakatable wealth above the nisab (all in taka).
class ZakatInput {
  const ZakatInput({this.cash = 0, this.bank = 0, this.gold = 0, this.silver = 0, this.business = 0, this.receivable = 0, this.other = 0, this.debts = 0, this.nisab = 0, this.byGold = false});
  final int cash, bank, gold, silver, business, receivable, other, debts, nisab;

  /// Only gold and nothing else (Hanafi): the nisab is 7.5 ভরি of gold, not
  /// the silver one — [nisab] is then its value at the gold price.
  final bool byGold;
  int get wealth => cash + bank + gold + silver + business + receivable + other;
  int get net => wealth - debts;
  bool get due => nisab > 0 && net >= nisab;
  int get zakat => due ? (net * 0.025).round() : 0;
}

/// What the user entered on the যাকাত page last time (kept on the phone),
/// for the parts the app cannot know: gold, silver, stock, other.
/// Today's gold and silver price (taka per ভরি) as BAJUS set it, from our
/// server — never made up in the app.
class MetalPrice {
  const MetalPrice({required this.date, required this.gold, required this.silver, this.source = '', this.sourceUrl = ''});

  /// The day the rate took effect.
  final DateTime date;
  final Map<String, int> gold;
  final Map<String, int> silver;
  final String source;
  final String sourceUrl;

  int get gold22 => gold['22k'] ?? 0;
  int get silver22 => silver['22k'] ?? 0;

  static MetalPrice? fromJson(Map<String, dynamic> j) {
    final d = DateTime.tryParse('${j['date'] ?? ''}');
    Map<String, int> m(Object? x) => {if (x is Map) for (final e in x.entries) '${e.key}': (e.value as num?)?.round() ?? 0};
    final p = MetalPrice(date: d ?? DateTime(2000), gold: m(j['gold']), silver: m(j['silver']), source: '${j['source'] ?? ''}', sourceUrl: '${j['source_url'] ?? ''}');
    return d == null || p.gold22 <= 0 || p.silver22 <= 0 ? null : p;
  }

  Map<String, dynamic> toJson() => {'date': date.toIso8601String().substring(0, 10), 'gold': gold, 'silver': silver, 'source': source, 'source_url': sourceUrl};

  /// "সোনা ২২ ক্যারেট ভরি ২,০৫,০০০ টাকা …" — every carat given.
  String said() {
    String part(Map<String, int> m) => [
          for (final (k, label) in const [('22k', '২২ ক্যারেট'), ('21k', '২১ ক্যারেট'), ('18k', '১৮ ক্যারেট'), ('traditional', 'সনাতন')])
            if ((m[k] ?? 0) > 0) '${tr(label)} ${bnNumber(m[k]!)}',
        ].join(', ');
    return trf('সোনা (ভরি): {0}। রুপা (ভরি): {1}।', [part(gold), part(silver)]);
  }
}

/// One kind of the member's gold (owner, 29 Oct): gold of several carats, or
/// of a kind বাজুস gives no price for ('other', named by the member), each
/// with its own weight and price per ভরি.
class GoldPiece {
  const GoldPiece({this.id = '', required this.carat, required this.vori, required this.price, this.label = ''});

  /// Empty for the one piece kept from before (its line key stays "gold").
  final String id;

  /// '22k', '21k', '18k', 'traditional' or 'other'.
  final String carat;
  final double vori;

  /// Taka per ভরি.
  final int price;

  /// For 'other': what it is (সোনার কয়েন…), as the member wrote it.
  final String label;

  int get value => (vori * price).round();

  /// The zakat line's key.
  String get key => id.isEmpty ? 'gold' : 'gold:$id';

  GoldPiece copyWith({double? vori, int? price}) => GoldPiece(id: id, carat: carat, vori: vori ?? this.vori, price: price ?? this.price, label: label);

  Map<String, dynamic> toJson() => {'id': id, 'k': carat, 'v': vori, 'p': price, if (label.isNotEmpty) 'l': label};

  static GoldPiece? fromJson(Object? j) {
    if (j is! Map) return null;
    final v = (j['v'] as num?)?.toDouble() ?? 0;
    return v <= 0 ? null : GoldPiece(id: '${j['id'] ?? ''}', carat: '${j['k'] ?? '22k'}', vori: v, price: (j['p'] as num?)?.round() ?? 0, label: '${j['l'] ?? ''}');
  }
}

class ZakatSaved {
  const ZakatSaved({this.goldVori = 0, this.goldPrice = 0, this.silverVori = 0, this.silverPrice = 0, this.business = 0, this.other = 0, this.golds});

  /// Gold written as one amount (before the kinds); [pieces] makes it one 22-carat piece.
  final double goldVori;

  /// Taka per ভরি of 22-carat gold — today's বাজুস price unless changed; the
  /// gold nisab when there is no gold written yet.
  final int goldPrice;
  final double silverVori;
  final int silverPrice;
  final int business;
  final int other;

  /// The member's gold, kind by kind (null: written the old way, [goldVori]).
  final List<GoldPiece>? golds;

  List<GoldPiece> get pieces => golds ?? (goldVori > 0 ? [GoldPiece(carat: '22k', vori: goldVori, price: goldPrice)] : const []);

  /// The same, with today's market price where none was entered.
  ZakatSaved withPrices(MetalPrice? p) => p == null
      ? this
      : ZakatSaved(
          goldVori: goldVori,
          goldPrice: goldPrice > 0 ? goldPrice : p.gold22,
          silverVori: silverVori,
          silverPrice: silverPrice > 0 ? silverPrice : p.silver22,
          business: business,
          other: other,
          golds: golds == null ? null : [for (final g in golds!) g.price > 0 ? g : g.copyWith(price: p.gold[g.carat] ?? 0)],
        );
}

/// The zakat parts the app works out from the user's own records:
/// - cash: hand/mobile accounts (or, with no accounts, the income-expense
///   balance — marked as an estimate);
/// - bank: bank accounts, savings goals and DPS paid in;
/// - receivable: what people owe the user;
/// - debts: what the user owes people, plus loan instalments of the next 12 months.
({int cash, bool cashEstimated, int bank, int receivable, int debts}) zakatFromRecords(AppData d, DateTime now) {
  var cash = d.accounts.where((a) => a.kind != AccountKind.bank).fold(0, (s, a) => s + accountBalance(d, a));
  var estimated = false;
  if (d.accounts.isEmpty) {
    final own = d.cash.where((e) => e.projectId == null);
    final bal = own.fold<int>(0, (s, e) => s + (e.kind == CashKind.income ? e.amount : -e.amount));
    if (bal > 0) {
      cash = bal;
      estimated = true;
    }
  }
  final bank = d.accounts.where((a) => a.kind == AccountKind.bank).fold(0, (s, a) => s + accountBalance(d, a)) +
      d.goals.fold<int>(0, (s, g) => s + g.saved) +
      d.installments.where((i) => i.kind == InstallmentKind.dps).fold<int>(0, (s, i) => s + i.paidTotal);
  final people = balances(d.ledger);
  final receivable = people.fold(0, (s, p) => s + (p.balance > 0 ? p.balance : 0));
  final loans = d.installments.where((i) => i.kind == InstallmentKind.loan).fold(0, (s, i) => s + (i.left < 12 ? i.left : 12) * i.amount);
  final debts = people.fold(0, (s, p) => s + (p.balance < 0 ? -p.balance : 0)) + loans;
  return (cash: cash < 0 ? 0 : cash, cashEstimated: estimated, bank: bank < 0 ? 0 : bank, receivable: receivable, debts: debts);
}

/// The whole zakat: the records plus what the user entered ([z]). The
/// nisab is 52.5 ভরি of silver at the price entered (none entered: unknown).
/// The count the যাকাত page shows and "আমার যাকাত কত?" answers: every line
/// from lib/logic/zakat.dart, without the ones the user left out.
ZakatInput zakatAuto(AppData d, DateTime now, ZakatSaved z) => zakatCount(zakatLines(d, now, z), z);

/// Splitting [total] among [people]; the rounding taka goes to the first ones.
List<int> splitAmounts(int total, int people) {
  if (people <= 0) return const [];
  final base = total ~/ people;
  final extra = total - base * people;
  return [for (var i = 0; i < people; i++) base + (i < extra ? 1 : 0)];
}

/// Customers who owe the user (for the shop's dues list), largest first.
List<PersonBalance> customersOwing(AppData d) => balances(d.ledger).where((p) => p.balance > 0).toList()..sort((a, b) => b.balance.compareTo(a.balance));

/// A day's sales: income entries in the "বিক্রি" category.
const salesCategory = 'বিক্রি';

/// Does an entry with [shopId] belong to [shop]? Entries without a shop go
/// to the first shop (sales said by voice, older records).
bool ofShop(AppData d, String? shopId, Shop shop) => shopId == shop.id || (shopId == null && d.shops.isNotEmpty && d.shops.first.id == shop.id);

/// A day's sales — all shops, or one [shop].
({int count, int total}) salesOn(AppData d, DateTime day, {Shop? shop}) {
  var n = 0, t = 0;
  for (final e in d.cash) {
    if (shop != null && !ofShop(d, e.shopId, shop)) continue;
    if (e.kind == CashKind.income && e.category == salesCategory && dayOnly(e.date) == dayOnly(day) && e.projectId == null) {
      n++;
      t += e.amount;
    }
  }
  return (count: n, total: t);
}

/// One line of a receipt.
class ReceiptLine {
  const ReceiptLine(this.item, this.qty, this.price);
  final String item;
  final int qty;
  final int price;
  int get total => qty * price;
}

/// A plain-text receipt to send by WhatsApp or SMS.
String receiptText({required String shop, required String customer, required List<ReceiptLine> lines, required int paid, required DateTime date, int no = 0}) {
  final total = lines.fold(0, (s, l) => s + l.total);
  final b = StringBuffer();
  if (shop.trim().isNotEmpty) b.writeln('*${shop.trim()}*');
  b.writeln(trf('রসিদ{0} · {1}', [no > 0 ? ' #${bnDigits(no)}' : '', fullDate(date)]));
  if (customer.trim().isNotEmpty) b.writeln(trf('গ্রাহক: {0}', [customer.trim()]));
  b.writeln('— — — — — — — —');
  for (final l in lines) {
    b.writeln('${l.item} — ${bnDigits(l.qty)} × ${taka(l.price)} = ${taka(l.total)}');
  }
  b.writeln('— — — — — — — —');
  b.writeln(trf('মোট: {0}', [taka(total)]));
  b.writeln(trf('পরিশোধ: {0}', [taka(paid)]));
  if (total - paid > 0) b.writeln(trf('বাকি: {0}', [taka(total - paid)]));
  b.write(tr('ধন্যবাদ, আবার আসবেন।'));
  return b.toString();
}


/// A shop's money in [month]: sales, its costs, and what is left.
({int sales, int costs, int count}) shopMonth(AppData d, Shop shop, DateTime month) {
  var sales = 0, costs = 0, n = 0;
  for (final e in d.cash) {
    if (e.projectId != null || e.date.year != month.year || e.date.month != month.month) continue;
    if (e.kind == CashKind.income && e.category == salesCategory && ofShop(d, e.shopId, shop)) {
      sales += e.amount;
      n++;
    } else if (e.kind == CashKind.expense && e.shopId == shop.id) {
      costs += e.amount;
    }
  }
  return (sales: sales, costs: costs, count: n);
}

/// Customers who owe [shop] (the first shop also keeps dues written without a shop).
List<PersonBalance> shopCustomersOwing(AppData d, Shop shop) =>
    balances(d.ledger.where((e) => ofShop(d, e.shopId, shop))).where((p) => p.balance > 0).toList()..sort((a, b) => b.balance.compareTo(a.balance));

/// The next receipt number in [shop].
int nextReceiptNo(AppData d, Shop shop) => d.receipts.where((r) => r.shopId == shop.id).fold(0, (m, r) => r.no > m ? r.no : m) + 1;

/// A kept receipt as text (to send again).
String receiptTextOf(Receipt r, Shop shop) => receiptText(
      shop: shop.name,
      customer: r.customer,
      lines: [for (final x in r.items) ReceiptLine(x.$1, x.$2, x.$3)],
      paid: r.paid,
      date: r.date,
      no: r.no,
    );
