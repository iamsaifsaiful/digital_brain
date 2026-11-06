// ব্যবসায়ী মোড: the numbers the shop pages show, worked out from the book.
import 'package:flutter/material.dart' show IconData, Icons;

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

/// The stock's sections by kind of product (owner, 6 Nov: "স্টক পণ্যের ধরণের
/// ভিত্তিতে বিভিন্ন সেকশনে ভাগ করা দরকার"), in the order a shop keeps them.
/// Each has an icon and the name words that put a product in it.
const shopSections = <(String, IconData, List<String>)>[
  ('চাল-ডাল-আটা', Icons.rice_bowl_outlined, ['চাল', 'ডাল', 'আটা', 'ময়দা', 'সুজি', 'চিড়া', 'মুড়ি', 'খই', 'বেসন', 'ছোলা', 'মটর', 'rice', 'dal', 'flour', 'atta']),
  ('তেল-মসলা', Icons.soup_kitchen_outlined, ['তেল', 'সয়াবিন', 'সরিষা', 'মসলা', 'লবণ', 'নুন', 'চিনি', 'গুড়', 'হলুদ', 'মরিচ', 'জিরা', 'ধনিয়া', 'এলাচ', 'দারুচিনি', 'লবঙ্গ', 'তেজপাতা', 'পাঁচফোড়ন', 'oil', 'salt', 'sugar', 'spice']),
  ('ডিম-দুধ', Icons.egg_outlined, ['ডিম', 'দুধ', 'দই', 'ঘি', 'মাখন', 'পনির', 'egg', 'milk', 'butter', 'ghee']),
  ('বিস্কুট-নাস্তা', Icons.cookie_outlined, ['বিস্কুট', 'চানাচুর', 'চিপস', 'কেক', 'চকলেট', 'রুটি', 'পাউরুটি', 'নুডলস', 'সেমাই', 'লজেন্স', 'চিপস', 'biscuit', 'chips', 'cake', 'chocolate', 'noodles', 'bread']),
  ('পানীয়', Icons.local_drink_outlined, ['পানি', 'কোক', 'স্প্রাইট', 'জুস', 'চা', 'কফি', 'হরলিক্স', 'ড্রিংক', 'সফট', 'water', 'juice', 'tea', 'coffee', 'drink', 'cola']),
  ('সবজি-ফল', Icons.eco_outlined, ['আলু', 'পেঁয়াজ', 'পিয়াজ', 'রসুন', 'আদা', 'টমেটো', 'বেগুন', 'শাক', 'লাউ', 'কলা', 'আম', 'আপেল', 'কমলা', 'লেবু', 'সবজি', 'ফল', 'potato', 'onion', 'garlic', 'ginger', 'banana', 'apple']),
  ('মাছ-মাংস', Icons.set_meal_outlined, ['মাছ', 'মাংস', 'মুরগি', 'গরু', 'খাসি', 'চিংড়ি', 'ইলিশ', 'fish', 'meat', 'chicken', 'beef']),
  ('সাবান-প্রসাধনী', Icons.soap_outlined, ['সাবান', 'শ্যাম্পু', 'পেস্ট', 'ব্রাশ', 'লোশন', 'ক্রিম', 'ট্যালকম', 'স্যানিটারি', 'প্যাড', 'রেজর', 'soap', 'shampoo', 'paste', 'brush', 'lotion', 'cream']),
  ('ঘর-পরিষ্কার', Icons.cleaning_services_outlined, ['ডিটারজেন্ট', 'হুইল', 'সার্ফ', 'ভিম', 'হারপিক', 'লাইজল', 'ফিনাইল', 'ঝাড়ু', 'টিস্যু', 'মশার', 'কয়েল', 'detergent', 'tissue', 'cleaner']),
  ('শিশুর জিনিস', Icons.child_care_outlined, ['ডায়াপার', 'বেবি', 'শিশু', 'ফিডার', 'সেরেলাক', 'ল্যাকটোজেন', 'diaper', 'baby']),
  ('ওষুধ', Icons.medication_outlined, ['ওষুধ', 'ট্যাবলেট', 'সিরাপ', 'ক্যাপসুল', 'নাপা', 'স্যালাইন', 'ব্যান্ডেজ', 'tablet', 'syrup', 'saline']),
  ('খাতা-কলম', Icons.edit_note_outlined, ['খাতা', 'কলম', 'পেন্সিল', 'রাবার', 'কাগজ', 'স্কেল', 'pen', 'pencil', 'paper', 'notebook']),
  ('মোবাইল-ইলেকট্রিক', Icons.electrical_services_outlined, ['ব্যাটারি', 'বাল্ব', 'চার্জার', 'কার্ড', 'সিম', 'তার', 'হেডফোন', 'battery', 'bulb', 'charger', 'sim']),
];

/// The catch-all section.
const otherSection = 'অন্যান্য';

/// The section a product's name points to, or null.
String? guessSection(String name) {
  final n = name.trim().toLowerCase();
  if (n.isEmpty) return null;
  final words = n.split(RegExp(r'[\s,./()\-]+')).where((w) => w.isNotEmpty).toList();
  for (final (section, _, keys) in shopSections) {
    for (final k in keys) {
      // A whole word, or a word that starts with it ("চালের", "ডিমের", "সাবানটা").
      if (k.contains(' ') ? n.contains(k) : words.any((w) => w == k || (k.length > 1 && w.startsWith(k) && w.length - k.length <= 3))) return section;
    }
  }
  return null;
}

/// The first week's shelf names, now a section's.
const _oldShelves = {'চাল-ডাল': 'চাল-ডাল-আটা', 'বিস্কুট-চানাচুর': 'বিস্কুট-নাস্তা', 'সাবান-শ্যাম্পু': 'সাবান-প্রসাধনী'};

/// The section a product sits in: the one chosen for it, else the one its
/// name points to, else অন্যান্য.
String sectionOf(Product p) {
  final c = p.category.trim();
  if (c.isNotEmpty && c != otherSection) return _oldShelves[c] ?? c;
  return guessSection(p.name) ?? otherSection;
}

IconData sectionIcon(String section) {
  for (final (s, icon, _) in shopSections) {
    if (s == section) return icon;
  }
  return section == otherSection ? Icons.category_outlined : Icons.inventory_2_outlined;
}

/// The sections with their products: the known ones in a shop's order, the
/// shop's own after them, অন্যান্য last.
List<(String, List<Product>)> shelves(Iterable<Product> ps) {
  final by = <String, List<Product>>{};
  for (final p in ps) {
    by.putIfAbsent(sectionOf(p), () => []).add(p);
  }
  final order = [for (final s in shopSections) s.$1];
  int rank(String k) => k == otherSection ? 1 << 20 : (order.contains(k) ? order.indexOf(k) : order.length);
  final keys = by.keys.toList()..sort((a, b) => rank(a) != rank(b) ? rank(a).compareTo(rank(b)) : a.compareTo(b));
  return [for (final k in keys) (k, by[k]!..sort((a, b) => a.name.compareTo(b.name)))];
}

/// Section names to offer in the product form.
List<String> get shelfSuggestions => [for (final s in shopSections) s.$1];

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
