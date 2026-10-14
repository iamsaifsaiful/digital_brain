/// Accounts, the monthly report, zakat and splitting a bill.
library;

import '../models/models.dart';
import 'bn.dart';
import 'lang.dart';
import 'ledger.dart';

/// What [a] holds now: what it started with, money in and out through it,
/// and moves between the user's own accounts.
int accountBalance(AppData d, MoneyAccount a) {
  var b = a.opening;
  for (final e in d.cash) {
    if (e.accountId != a.id) continue;
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
        cats[e.category] = (cats[e.category] ?? 0) + e.amount;
        days[e.date.day] = (days[e.date.day] ?? 0) + e.amount;
      }
    } else if (inMonth(e.date, last) && e.kind == CashKind.expense) {
      lastExpense += e.amount;
      lastCats[e.category] = (lastCats[e.category] ?? 0) + e.amount;
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
  const ZakatInput({this.cash = 0, this.bank = 0, this.gold = 0, this.silver = 0, this.business = 0, this.receivable = 0, this.other = 0, this.debts = 0, this.nisab = 0});
  final int cash, bank, gold, silver, business, receivable, other, debts, nisab;
  int get wealth => cash + bank + gold + silver + business + receivable + other;
  int get net => wealth - debts;
  bool get due => nisab > 0 && net >= nisab;
  int get zakat => due ? (net * 0.025).round() : 0;
}

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

({int count, int total}) salesOn(AppData d, DateTime day) {
  var n = 0, t = 0;
  for (final e in d.cash) {
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
