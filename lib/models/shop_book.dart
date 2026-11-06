// ব্যবসায়ী মোড (owner, 6 Nov — the "দোকানি" handoff): a grocer's book kept on
// the phone with everything else. Sales and purchases also write the
// money they move into আয়-ব্যয় and the credit into the ledger (পাবো /
// দেবো), so the rest of the app — reports, the assistant, backups — keeps
// seeing one set of money.
import 'models.dart' show newId;

DateTime? _d(Object? v) => v is String ? DateTime.tryParse(v) : null;
double _n(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
int _i(Object? v) => v is num ? v.round() : int.tryParse('$v') ?? 0;

/// The units a grocer sells in (the handoff's list, in its order).
const shopUnits = ['পিস', 'কেজি', 'গ্রাম', 'লিটার', 'হালি', 'ডজন', 'প্যাকেট', 'বোতল', 'বস্তা'];

/// A product on the shelf.
class Product {
  Product({
    String? id,
    required this.name,
    this.unit = 'কেজি',
    this.buy = 0,
    this.sell = 0,
    this.stock = 0,
    this.low = 0,
    this.loose = false,
    this.bulkFrom,
    this.bulkPrice,
    this.expiry,
    this.barcode = '',
    this.supplier = '',
    this.category = '',
  }) : id = id ?? newId();

  final String id;
  final String name;
  final String unit;

  /// Taka per [unit]: bought at, sold at.
  final int buy;
  final int sell;

  /// How much is on the shelf, in [unit] (a loose product in fractions: 1.25 কেজি).
  final double stock;

  /// At or below this, it shows as running out (0 = never).
  final double low;

  /// Sold loose by weight: any amount, the price worked out.
  final bool loose;

  /// Wholesale: from [bulkFrom] units on, [bulkPrice] a unit.
  final double? bulkFrom;
  final int? bulkPrice;
  final DateTime? expiry;
  final String barcode;

  /// Who it is bought from (the order list is split by this).
  final String supplier;

  /// The shelf it is on (চাল-ডাল, তেল-মসলা …); empty = "অন্যান্য".
  final String category;

  bool get isLow => low > 0 && stock <= low;

  /// The price of [qty] units (the wholesale price when that many are taken).
  int priceOf(double qty) {
    final unitPrice = bulkFrom != null && bulkPrice != null && qty >= bulkFrom! ? bulkPrice! : sell;
    return (unitPrice * qty).round();
  }

  Product copyWith({String? name, String? unit, int? buy, int? sell, double? stock, double? low, bool? loose, double? bulkFrom, int? bulkPrice, DateTime? expiry, bool clearExpiry = false, bool clearBulk = false, String? barcode, String? supplier, String? category}) => Product(
        id: id,
        name: name ?? this.name,
        unit: unit ?? this.unit,
        buy: buy ?? this.buy,
        sell: sell ?? this.sell,
        stock: stock ?? this.stock,
        low: low ?? this.low,
        loose: loose ?? this.loose,
        bulkFrom: clearBulk ? null : bulkFrom ?? this.bulkFrom,
        bulkPrice: clearBulk ? null : bulkPrice ?? this.bulkPrice,
        expiry: clearExpiry ? null : expiry ?? this.expiry,
        barcode: barcode ?? this.barcode,
        supplier: supplier ?? this.supplier,
        category: category ?? this.category,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'buy': buy,
        'sell': sell,
        'stock': stock,
        if (low > 0) 'low': low,
        if (loose) 'loose': true,
        if (bulkFrom != null) 'bulkFrom': bulkFrom,
        if (bulkPrice != null) 'bulkPrice': bulkPrice,
        if (expiry != null) 'expiry': expiry!.toIso8601String(),
        if (barcode.isNotEmpty) 'barcode': barcode,
        if (supplier.isNotEmpty) 'supplier': supplier,
        if (category.isNotEmpty) 'category': category,
      };

  factory Product.fromJson(Map<String, Object?> j) => Product(
        id: j['id'] as String?,
        name: '${j['name'] ?? ''}',
        unit: '${j['unit'] ?? 'কেজি'}',
        buy: _i(j['buy']),
        sell: _i(j['sell']),
        stock: _n(j['stock']),
        low: _n(j['low']),
        loose: j['loose'] == true,
        bulkFrom: j['bulkFrom'] == null ? null : _n(j['bulkFrom']),
        bulkPrice: j['bulkPrice'] == null ? null : _i(j['bulkPrice']),
        expiry: _d(j['expiry']),
        barcode: '${j['barcode'] ?? ''}',
        supplier: '${j['supplier'] ?? ''}',
        category: '${j['category'] ?? ''}',
      );
}

/// One line of a sale or a purchase.
class SaleLine {
  const SaleLine({this.productId, required this.name, required this.qty, required this.unit, required this.amount, this.cost = 0});

  final String? productId;
  final String name;
  final double qty;
  final String unit;

  /// What the line came to, in taka.
  final int amount;

  /// What it cost the shop (bought price × qty), for the rough profit.
  final int cost;

  Map<String, Object?> toJson() => {if (productId != null) 'p': productId, 'name': name, 'qty': qty, 'unit': unit, 'amount': amount, if (cost > 0) 'cost': cost};
  factory SaleLine.fromJson(Map<String, Object?> j) =>
      SaleLine(productId: j['p'] as String?, name: '${j['name'] ?? ''}', qty: _n(j['qty']), unit: '${j['unit'] ?? ''}', amount: _i(j['amount']), cost: _i(j['cost']));
}

/// How a sale was paid.
enum SalePay {
  cash('নগদ'),
  qr('QR / বিকাশ'),
  credit('বাকিতে');

  const SalePay(this.label);
  final String label;

  static SalePay of(Object? v) => SalePay.values.firstWhere((p) => p.name == v, orElse: () => SalePay.cash);
}

class Sale {
  Sale({String? id, required this.at, required this.lines, this.discount = 0, this.pay = SalePay.cash, this.customer = '', this.amountOnly = 0, this.cashId, this.ledgerId, this.no = 0})
      : id = id ?? newId();

  final String id;
  final DateTime at;
  final List<SaleLine> lines;
  final int discount;
  final SalePay pay;

  /// The buyer's name (required for a sale on credit).
  final String customer;

  /// "শুধু টাকা": a sale with no products picked, only an amount.
  final int amountOnly;

  /// The আয়-ব্যয় income it wrote (cash and QR) or the ledger entry (on credit).
  final String? cashId;
  final String? ledgerId;

  /// The receipt number (#১, #২ …).
  final int no;

  int get total => amountOnly > 0 ? amountOnly : (lines.fold<int>(0, (s, l) => s + l.amount) - discount).clamp(0, 1 << 40);
  int get cost => lines.fold<int>(0, (s, l) => s + l.cost);

  Map<String, Object?> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'lines': [for (final l in lines) l.toJson()],
        if (discount > 0) 'discount': discount,
        'pay': pay.name,
        if (customer.isNotEmpty) 'customer': customer,
        if (amountOnly > 0) 'amountOnly': amountOnly,
        if (cashId != null) 'cashId': cashId,
        if (ledgerId != null) 'ledgerId': ledgerId,
        if (no > 0) 'no': no,
      };

  factory Sale.fromJson(Map<String, Object?> j) => Sale(
        id: j['id'] as String?,
        at: _d(j['at']) ?? DateTime(2000),
        lines: [for (final l in (j['lines'] as List? ?? const [])) if (l is Map) SaleLine.fromJson(l.cast<String, Object?>())],
        discount: _i(j['discount']),
        pay: SalePay.of(j['pay']),
        customer: '${j['customer'] ?? ''}',
        amountOnly: _i(j['amountOnly']),
        cashId: j['cashId'] as String?,
        ledgerId: j['ledgerId'] as String?,
        no: _i(j['no']),
      );
}

/// A line on the order list (মাল কেনা › অর্ডার তালিকা).
class OrderLine {
  OrderLine({String? id, required this.productId, required this.name, required this.qty, required this.unit, this.supplier = '', this.picked = true}) : id = id ?? newId();
  final String id;
  final String productId;
  final String name;
  final double qty;
  final String unit;
  final String supplier;

  /// Ticked to be ordered (untick to leave it out this time).
  final bool picked;

  OrderLine copyWith({double? qty, bool? picked, String? supplier}) =>
      OrderLine(id: id, productId: productId, name: name, qty: qty ?? this.qty, unit: unit, supplier: supplier ?? this.supplier, picked: picked ?? this.picked);

  Map<String, Object?> toJson() => {'id': id, 'p': productId, 'name': name, 'qty': qty, 'unit': unit, if (supplier.isNotEmpty) 'supplier': supplier, if (!picked) 'picked': false};
  factory OrderLine.fromJson(Map<String, Object?> j) => OrderLine(
      id: j['id'] as String?, productId: '${j['p'] ?? ''}', name: '${j['name'] ?? ''}', qty: _n(j['qty']), unit: '${j['unit'] ?? ''}', supplier: '${j['supplier'] ?? ''}', picked: j['picked'] != false);
}

/// The day closed: the cash box counted.
class DayClose {
  const DayClose({required this.day, required this.opening, required this.expected, required this.counted});
  final DateTime day;
  final int opening;
  final int expected;
  final int counted;

  int get diff => counted - expected;

  Map<String, Object?> toJson() => {'day': day.toIso8601String(), 'opening': opening, 'expected': expected, 'counted': counted};
  factory DayClose.fromJson(Map<String, Object?> j) =>
      DayClose(day: _d(j['day']) ?? DateTime(2000), opening: _i(j['opening']), expected: _i(j['expected']), counted: _i(j['counted']));
}

/// What the shop keeps about a buyer on credit, beyond the ledger: a limit,
/// the day they said they would pay, and the weekly reminder.
class Buyer {
  const Buyer({required this.name, this.limit = 0, this.dueDay, this.weekly = false, this.lastSent});
  final String name;
  final int limit;
  final DateTime? dueDay;

  /// "প্রতি শুক্রবার নিজে থেকে পাঠাবে": a reminder each Friday to send the তাগাদা.
  final bool weekly;
  final DateTime? lastSent;

  Buyer copyWith({int? limit, DateTime? dueDay, bool clearDue = false, bool? weekly, DateTime? lastSent}) =>
      Buyer(name: name, limit: limit ?? this.limit, dueDay: clearDue ? null : dueDay ?? this.dueDay, weekly: weekly ?? this.weekly, lastSent: lastSent ?? this.lastSent);

  Map<String, Object?> toJson() => {
        'name': name,
        if (limit > 0) 'limit': limit,
        if (dueDay != null) 'dueDay': dueDay!.toIso8601String(),
        if (weekly) 'weekly': true,
        if (lastSent != null) 'lastSent': lastSent!.toIso8601String(),
      };
  factory Buyer.fromJson(Map<String, Object?> j) =>
      Buyer(name: '${j['name'] ?? ''}', limit: _i(j['limit']), dueDay: _d(j['dueDay']), weekly: j['weekly'] == true, lastSent: _d(j['lastSent']));
}

class ShopBook {
  ShopBook({List<Product>? products, List<Sale>? sales, List<OrderLine>? orders, List<DayClose>? closes, List<Buyer>? buyers, this.opening})
      : products = products ?? [],
        sales = sales ?? [],
        orders = orders ?? [],
        closes = closes ?? [],
        buyers = buyers ?? [];

  final List<Product> products;
  final List<Sale> sales;
  final List<OrderLine> orders;
  final List<DayClose> closes;
  final List<Buyer> buyers;

  /// The cash in the box this morning (set when the day opens; else the
  /// last day's count carries over).
  ({DateTime day, int amount})? opening;

  bool get isEmpty => products.isEmpty && sales.isEmpty && orders.isEmpty && closes.isEmpty && buyers.isEmpty && opening == null;

  Map<String, Object?> toJson() => {
        if (products.isNotEmpty) 'products': [for (final p in products) p.toJson()],
        if (sales.isNotEmpty) 'sales': [for (final s in sales) s.toJson()],
        if (orders.isNotEmpty) 'orders': [for (final o in orders) o.toJson()],
        if (closes.isNotEmpty) 'closes': [for (final c in closes) c.toJson()],
        if (buyers.isNotEmpty) 'buyers': [for (final b in buyers) b.toJson()],
        if (opening != null) 'opening': {'day': opening!.day.toIso8601String(), 'amount': opening!.amount},
      };

  factory ShopBook.fromJson(Map<String, Object?> j) {
    List<T> list<T>(String k, T Function(Map<String, Object?>) f) => [for (final x in (j[k] as List? ?? const [])) if (x is Map) f(x.cast<String, Object?>())];
    final o = j['opening'];
    return ShopBook(
      products: list('products', Product.fromJson),
      sales: list('sales', Sale.fromJson),
      orders: list('orders', OrderLine.fromJson),
      closes: list('closes', DayClose.fromJson),
      buyers: list('buyers', Buyer.fromJson),
      opening: o is Map && _d(o['day']) != null ? (day: _d(o['day'])!, amount: _i(o['amount'])) : null,
    );
  }
}
