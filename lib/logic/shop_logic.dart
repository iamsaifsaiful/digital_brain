// ব্যবসায়ী মোড: the numbers the shop pages show, worked out from the book.
import '../models/models.dart';
import 'ledger.dart';
import 'bn.dart' show dayOnly;

/// A quantity as the shop says it: "৫", "১.২৫০", "১২.৫".
String qtyText(double q) {
  if (q == q.roundToDouble()) return q.round().toString();
  final s = q.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '');
  return s.endsWith('.') ? s.substring(0, s.length - 1) : s;
}

bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// The sales of one day, newest first.
List<Sale> salesOn(ShopBook b, DateTime day) => [for (final s in b.sales) if (sameDay(s.at, day)) s]..sort((a, b) => b.at.compareTo(a.at));

/// Sales from [from] (a day) up to now, newest first.
List<Sale> salesSince(ShopBook b, DateTime from) => [for (final s in b.sales) if (!s.at.isBefore(dayOnly(from))) s]..sort((a, b) => b.at.compareTo(a.at));

class DaySum {
  DaySum(this.sales);
  final List<Sale> sales;
  int get count => sales.length;
  int get total => sales.fold(0, (s, x) => s + x.total);
  int by(SalePay p) => sales.where((s) => s.pay == p).fold(0, (s, x) => s + x.total);

  /// Rough profit: what the products sold for less what they cost (a sale
  /// with no products, or products without a bought price, adds nothing).
  int get profit => sales.fold(0, (s, x) => s + (x.cost > 0 ? x.total - x.cost : 0));

  /// Cash, QR and credit as whole percents that add up to 100.
  (int cash, int qr, int credit) get split {
    if (total <= 0) return (0, 0, 0);
    final c = (by(SalePay.cash) * 100 / total).round(), q = (by(SalePay.qr) * 100 / total).round();
    return (c, q, (100 - c - q).clamp(0, 100));
  }
}

/// Running low, the lowest first.
List<Product> lowStock(ShopBook b) => [for (final p in b.products) if (p.isLow) p]..sort((a, b) => (a.stock / (a.low == 0 ? 1 : a.low)).compareTo(b.stock / (b.low == 0 ? 1 : b.low)));

/// Products whose date runs out within [days] (or already has).
List<Product> expiring(ShopBook b, DateTime now, {int days = 3}) =>
    [for (final p in b.products) if (p.expiry != null && p.stock > 0 && !dayOnly(p.expiry!).isAfter(dayOnly(now).add(Duration(days: days)))) p]..sort((a, b) => a.expiry!.compareTo(b.expiry!));

/// The shelves (categories) with their products, in a steady order.
List<(String, List<Product>)> shelves(Iterable<Product> ps) {
  final by = <String, List<Product>>{};
  for (final p in ps) {
    by.putIfAbsent(p.category.trim().isEmpty ? 'অন্যান্য' : p.category.trim(), () => []).add(p);
  }
  final keys = by.keys.toList()..sort((a, b) => a == 'অন্যান্য' ? 1 : (b == 'অন্যান্য' ? -1 : a.compareTo(b)));
  return [for (final k in keys) (k, by[k]!..sort((a, b) => a.name.compareTo(b.name)))];
}

/// Shelf names already used, for the product form's suggestions.
const shelfSuggestions = ['চাল-ডাল', 'তেল-মসলা', 'ডিম-দুধ', 'সাবান-শ্যাম্পু', 'বিস্কুট-চানাচুর', 'পানীয়'];

/// The buyers who owe the shop (পাবো), most first.
List<PersonBalance> owing(AppData d) => balances(d.ledger).where((p) => p.balance > 0).toList()..sort((a, b) => b.balance.compareTo(a.balance));

/// Those the shop owes (দেবো — suppliers, the মহাজন), most first.
List<PersonBalance> owed(AppData d) => balances(d.ledger).where((p) => p.balance < 0).toList()..sort((a, b) => a.balance.compareTo(b.balance));

Buyer buyerOf(ShopBook b, String name) => b.buyers.firstWhere((x) => x.name == name, orElse: () => Buyer(name: name));

/// Today's cash box: the morning's cash, cash sales, credit collected in
/// cash today, less the shop's cash costs today (goods paid for in cash too).
class CashBox {
  const CashBox({required this.opening, required this.sales, required this.collected, required this.costs});
  final int opening;
  final int sales;
  final int collected;
  final int costs;
  int get expected => opening + sales + collected - costs;
}

CashBox cashBox(AppData d, DateTime now) {
  final b = d.shop;
  final today = dayOnly(now);
  var opening = 0;
  if (b.opening != null && sameDay(b.opening!.day, today)) {
    opening = b.opening!.amount;
  } else {
    final past = [for (final c in b.closes) if (c.day.isBefore(today)) c]..sort((a, b) => b.day.compareTo(a.day));
    if (past.isNotEmpty) opening = past.first.counted;
  }
  final sales = salesOn(b, today).where((s) => s.pay == SalePay.cash).fold(0, (s, x) => s + x.total);
  final collected = d.ledger.where((e) => e.kind == LedgerKind.received && sameDay(e.date, today)).fold(0, (s, e) => s + e.amount);
  final costs = d.cash.where((e) => e.kind == CashKind.expense && sameDay(e.date, today)).fold(0, (s, e) => s + e.amount);
  return CashBox(opening: opening, sales: sales, collected: collected, costs: costs);
}

/// Sales a day for the last [days] days, oldest first (the week chart).
List<(DateTime, int)> salesByDay(ShopBook b, DateTime now, {int days = 7}) => [
      for (var i = days - 1; i >= 0; i--)
        () {
          final day = dayOnly(now).subtract(Duration(days: i));
          return (day, salesOn(b, day).fold(0, (s, x) => s + x.total));
        }(),
    ];

/// The best sellers over [days] days: (name, quantity, unit, taka), most taka first.
List<(String, double, String, int)> bestSellers(ShopBook b, DateTime now, {int days = 30}) {
  final from = dayOnly(now).subtract(Duration(days: days - 1));
  final by = <String, (String, double, String, int)>{};
  for (final s in b.sales.where((s) => !s.at.isBefore(from))) {
    for (final l in s.lines) {
      final k = l.productId ?? l.name;
      final was = by[k];
      by[k] = (l.name, (was?.$2 ?? 0) + l.qty, l.unit, (was?.$4 ?? 0) + l.amount);
    }
  }
  return by.values.toList()..sort((a, b) => b.$4.compareTo(a.$4));
}

/// A suggested order for a low product: back up to three times its low mark.
double suggestedOrder(Product p) {
  final want = (p.low * 3 - p.stock);
  return want <= 0 ? (p.low > 0 ? p.low : 1) : want.ceilToDouble();
}

/// The receipt as text (to send by SMS or WhatsApp).
String receiptText(Sale s, String Function(int) taka, String Function(String) digits) {
  final lines = <String>[
    'রসিদ #${digits('${s.no}')} · ${digits('${s.at.day}/${s.at.month}/${s.at.year}')}',
    if (s.customer.isNotEmpty) 'ক্রেতা: ${s.customer}',
    for (final l in s.lines) '${l.name} ${digits(qtyText(l.qty))} ${l.unit} — ${taka(l.amount)}',
    if (s.amountOnly > 0) 'মোট বিক্রি — ${taka(s.amountOnly)}',
    if (s.discount > 0) 'ছাড় — ${taka(s.discount)}',
    'মোট: ${taka(s.total)} (${s.pay.label})',
    'ধন্যবাদ!',
  ];
  return lines.join('\n');
}
