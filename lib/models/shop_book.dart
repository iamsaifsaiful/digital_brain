// ব্যবসায়ী মোড (owner, 6 Nov — the "দোকানি" handoff): a grocer's book kept on
// the phone with everything else. The cash a sale, a collection or a
// payment moves is written into আয়-ব্যয় too, so reports and backups see
// one set of money; the customers' বাকি and the dealers' দেনা stay here, in
// the shop's own book (owner, 6 Nov: not the personal ধার-দেনা).
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
  Sale({
    String? id,
    required this.at,
    required this.lines,
    this.discount = 0,
    this.discountPct = 0,
    this.pay = SalePay.cash,
    this.customerId = '',
    this.customer = '',
    this.amountOnly = 0,
    this.cashId,
    this.no = 0,
  }) : id = id ?? newId();

  final String id;
  final DateTime at;
  final List<SaleLine> lines;

  /// The discount in taka (worked out from [discountPct] when that was given).
  final int discount;

  /// The discount as typed in percent (0 = given in taka).
  final double discountPct;
  final SalePay pay;

  /// The customer (required for a sale on credit); [customer] is their name
  /// as it was, for the receipt.
  final String customerId;
  final String customer;

  /// "শুধু টাকা": a sale with no products picked, only an amount.
  final int amountOnly;

  /// The আয়-ব্যয় income it wrote (cash and QR).
  final String? cashId;

  /// The receipt number (#১, #২ …).
  final int no;

  int get subtotal => amountOnly > 0 ? amountOnly : lines.fold<int>(0, (s, l) => s + l.amount);
  int get total => amountOnly > 0 ? amountOnly : (subtotal - discount).clamp(0, 1 << 40);
  int get cost => lines.fold<int>(0, (s, l) => s + l.cost);

  Map<String, Object?> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'lines': [for (final l in lines) l.toJson()],
        if (discount > 0) 'discount': discount,
        if (discountPct > 0) 'discountPct': discountPct,
        'pay': pay.name,
        if (customerId.isNotEmpty) 'customerId': customerId,
        if (customer.isNotEmpty) 'customer': customer,
        if (amountOnly > 0) 'amountOnly': amountOnly,
        if (cashId != null) 'cashId': cashId,
        if (no > 0) 'no': no,
      };

  factory Sale.fromJson(Map<String, Object?> j) => Sale(
        id: j['id'] as String?,
        at: _d(j['at']) ?? DateTime(2000),
        lines: [for (final l in (j['lines'] as List? ?? const [])) if (l is Map) SaleLine.fromJson(l.cast<String, Object?>())],
        discount: _i(j['discount']),
        discountPct: _n(j['discountPct']),
        pay: SalePay.of(j['pay']),
        customerId: '${j['customerId'] ?? ''}',
        customer: '${j['customer'] ?? ''}',
        amountOnly: _i(j['amountOnly']),
        cashId: j['cashId'] as String?,
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

/// A customer's profile (owner, 6 Nov: "গ্রাহকদের প্রোফাইল দরকার"): who they
/// are, how to reach them, their credit limit and pay day, and the reminder
/// set to collect.
class Customer {
  Customer({
    String? id,
    required this.name,
    this.phone = '',
    this.whatsapp = '',
    this.address = '',
    this.note = '',
    this.limit = 0,
    this.opening = 0,
    this.dueDay,
    this.reminderId,
    this.lastSent,
    DateTime? added,
  })  : id = id ?? newId(),
        added = added ?? DateTime(2000);

  final String id;
  final String name;
  final String phone;

  /// The WhatsApp number when it is not [phone] (the তাগাদা goes there).
  final String whatsapp;
  final String address;
  final String note;

  /// The most they may owe (0 = no limit).
  final int limit;

  /// What they owed before the app (written in once).
  final int opening;

  /// The day they said they would pay.
  final DateTime? dueDay;

  /// The app reminder set to collect from them.
  final String? reminderId;
  final DateTime? lastSent;
  final DateTime added;

  String get whatsappNumber => whatsapp.isNotEmpty ? whatsapp : phone;

  Customer copyWith({String? name, String? phone, String? whatsapp, String? address, String? note, int? limit, int? opening, DateTime? dueDay, bool clearDue = false, String? reminderId, bool clearReminder = false, DateTime? lastSent}) => Customer(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        whatsapp: whatsapp ?? this.whatsapp,
        address: address ?? this.address,
        note: note ?? this.note,
        limit: limit ?? this.limit,
        opening: opening ?? this.opening,
        dueDay: clearDue ? null : dueDay ?? this.dueDay,
        reminderId: clearReminder ? null : reminderId ?? this.reminderId,
        lastSent: lastSent ?? this.lastSent,
        added: added,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        if (phone.isNotEmpty) 'phone': phone,
        if (whatsapp.isNotEmpty) 'whatsapp': whatsapp,
        if (address.isNotEmpty) 'address': address,
        if (note.isNotEmpty) 'note': note,
        if (limit > 0) 'limit': limit,
        if (opening != 0) 'opening': opening,
        if (dueDay != null) 'dueDay': dueDay!.toIso8601String(),
        if (reminderId != null) 'reminderId': reminderId,
        if (lastSent != null) 'lastSent': lastSent!.toIso8601String(),
        'added': added.toIso8601String(),
      };

  factory Customer.fromJson(Map<String, Object?> j) => Customer(
        id: j['id'] as String?,
        name: '${j['name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        whatsapp: '${j['whatsapp'] ?? ''}',
        address: '${j['address'] ?? ''}',
        note: '${j['note'] ?? ''}',
        limit: _i(j['limit']),
        opening: _i(j['opening']),
        dueDay: _d(j['dueDay']),
        reminderId: j['reminderId'] as String?,
        lastSent: _d(j['lastSent']),
        added: _d(j['added']),
      );
}

/// A dealer (ডিলার, মহাজন, সাপ্লায়ার) the shop buys from.
class Dealer {
  Dealer({String? id, required this.name, this.phone = '', this.whatsapp = '', this.address = '', this.note = '', this.opening = 0}) : id = id ?? newId();
  final String id;
  final String name;
  final String phone;
  final String whatsapp;
  final String address;
  final String note;

  /// What the shop owed them before the app.
  final int opening;

  String get whatsappNumber => whatsapp.isNotEmpty ? whatsapp : phone;

  Dealer copyWith({String? name, String? phone, String? whatsapp, String? address, String? note, int? opening}) =>
      Dealer(id: id, name: name ?? this.name, phone: phone ?? this.phone, whatsapp: whatsapp ?? this.whatsapp, address: address ?? this.address, note: note ?? this.note, opening: opening ?? this.opening);

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        if (phone.isNotEmpty) 'phone': phone,
        if (whatsapp.isNotEmpty) 'whatsapp': whatsapp,
        if (address.isNotEmpty) 'address': address,
        if (note.isNotEmpty) 'note': note,
        if (opening != 0) 'opening': opening,
      };
  factory Dealer.fromJson(Map<String, Object?> j) => Dealer(
        id: j['id'] as String?,
        name: '${j['name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        whatsapp: '${j['whatsapp'] ?? ''}',
        address: '${j['address'] ?? ''}',
        note: '${j['note'] ?? ''}',
        opening: _i(j['opening']),
      );
}

/// Goods bought from a dealer: what came, what it came to, and how much was
/// paid there and then (the rest is owed to the dealer).
class Purchase {
  Purchase({String? id, required this.at, required this.dealerId, this.dealer = '', required this.lines, required this.total, this.paid = 0, this.cashId, this.note = ''}) : id = id ?? newId();
  final String id;
  final DateTime at;
  final String dealerId;
  final String dealer;
  final List<SaleLine> lines;
  final int total;
  final int paid;
  final String? cashId;
  final String note;

  int get owed => (total - paid).clamp(0, 1 << 40);

  Map<String, Object?> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'dealerId': dealerId,
        if (dealer.isNotEmpty) 'dealer': dealer,
        'lines': [for (final l in lines) l.toJson()],
        'total': total,
        if (paid > 0) 'paid': paid,
        if (cashId != null) 'cashId': cashId,
        if (note.isNotEmpty) 'note': note,
      };
  factory Purchase.fromJson(Map<String, Object?> j) => Purchase(
        id: j['id'] as String?,
        at: _d(j['at']) ?? DateTime(2000),
        dealerId: '${j['dealerId'] ?? ''}',
        dealer: '${j['dealer'] ?? ''}',
        lines: [for (final l in (j['lines'] as List? ?? const [])) if (l is Map) SaleLine.fromJson(l.cast<String, Object?>())],
        total: _i(j['total']),
        paid: _i(j['paid']),
        cashId: j['cashId'] as String?,
        note: '${j['note'] ?? ''}',
      );
}

/// Money between the shop and a customer (they paid their বাকি) or a dealer
/// (the shop paid them).
class ShopPayment {
  ShopPayment({String? id, required this.at, required this.party, required this.amount, this.cashId, this.note = ''}) : id = id ?? newId();
  final String id;
  final DateTime at;

  /// The customer's or the dealer's id.
  final String party;
  final int amount;
  final String? cashId;
  final String note;

  Map<String, Object?> toJson() => {'id': id, 'at': at.toIso8601String(), 'party': party, 'amount': amount, if (cashId != null) 'cashId': cashId, if (note.isNotEmpty) 'note': note};
  factory ShopPayment.fromJson(Map<String, Object?> j) =>
      ShopPayment(id: j['id'] as String?, at: _d(j['at']) ?? DateTime(2000), party: '${j['party'] ?? ''}', amount: _i(j['amount']), cashId: j['cashId'] as String?, note: '${j['note'] ?? ''}');
}

/// The default তাগাদা; the shopkeeper can write their own (the [] words
/// are filled in).
const defaultTagada = 'আসসালামু আলাইকুম [নাম], [দোকান]-এ আপনার বাকি [বাকি]। সুবিধামতো পরিশোধ করবেন। ধন্যবাদ।';

/// The shop on its receipts and messages: name, address, mobile, logo.
class ShopProfile {
  const ShopProfile({this.name = '', this.address = '', this.phone = '', this.logo = '', this.tagada = '', this.receiptNote = ''});
  final String name;
  final String address;
  final String phone;

  /// The logo, a small picture (base64), '' = none.
  final String logo;

  /// The shopkeeper's own তাগাদা ('' = [defaultTagada]).
  final String tagada;

  /// A line at the foot of the receipt ("আবার আসবেন").
  final String receiptNote;

  String get tagadaText => tagada.trim().isEmpty ? defaultTagada : tagada;

  ShopProfile copyWith({String? name, String? address, String? phone, String? logo, String? tagada, String? receiptNote}) => ShopProfile(
      name: name ?? this.name, address: address ?? this.address, phone: phone ?? this.phone, logo: logo ?? this.logo, tagada: tagada ?? this.tagada, receiptNote: receiptNote ?? this.receiptNote);

  bool get isEmpty => name.isEmpty && address.isEmpty && phone.isEmpty && logo.isEmpty && tagada.isEmpty && receiptNote.isEmpty;

  Map<String, Object?> toJson() => {
        if (name.isNotEmpty) 'name': name,
        if (address.isNotEmpty) 'address': address,
        if (phone.isNotEmpty) 'phone': phone,
        if (logo.isNotEmpty) 'logo': logo,
        if (tagada.isNotEmpty) 'tagada': tagada,
        if (receiptNote.isNotEmpty) 'receiptNote': receiptNote,
      };
  factory ShopProfile.fromJson(Map<String, Object?> j) => ShopProfile(
      name: '${j['name'] ?? ''}', address: '${j['address'] ?? ''}', phone: '${j['phone'] ?? ''}', logo: '${j['logo'] ?? ''}', tagada: '${j['tagada'] ?? ''}', receiptNote: '${j['receiptNote'] ?? ''}');
}

class ShopBook {
  ShopBook({
    List<Product>? products,
    List<Sale>? sales,
    List<OrderLine>? orders,
    List<Customer>? customers,
    List<Dealer>? dealers,
    List<Purchase>? purchases,
    List<ShopPayment>? collections,
    List<ShopPayment>? payouts,
    this.profile = const ShopProfile(),
  })  : products = products ?? [],
        sales = sales ?? [],
        orders = orders ?? [],
        customers = customers ?? [],
        dealers = dealers ?? [],
        purchases = purchases ?? [],
        collections = collections ?? [],
        payouts = payouts ?? [];

  final List<Product> products;
  final List<Sale> sales;
  final List<OrderLine> orders;
  final List<Customer> customers;
  final List<Dealer> dealers;
  final List<Purchase> purchases;

  /// Customers paying back their বাকি.
  final List<ShopPayment> collections;

  /// The shop paying its dealers.
  final List<ShopPayment> payouts;
  ShopProfile profile;

  bool get isEmpty => products.isEmpty && sales.isEmpty && orders.isEmpty && customers.isEmpty && dealers.isEmpty && purchases.isEmpty && collections.isEmpty && payouts.isEmpty && profile.isEmpty;

  Map<String, Object?> toJson() => {
        if (products.isNotEmpty) 'products': [for (final p in products) p.toJson()],
        if (sales.isNotEmpty) 'sales': [for (final s in sales) s.toJson()],
        if (orders.isNotEmpty) 'orders': [for (final o in orders) o.toJson()],
        if (customers.isNotEmpty) 'customers': [for (final c in customers) c.toJson()],
        if (dealers.isNotEmpty) 'dealers': [for (final d in dealers) d.toJson()],
        if (purchases.isNotEmpty) 'purchases': [for (final p in purchases) p.toJson()],
        if (collections.isNotEmpty) 'collections': [for (final p in collections) p.toJson()],
        if (payouts.isNotEmpty) 'payouts': [for (final p in payouts) p.toJson()],
        if (!profile.isEmpty) 'profile': profile.toJson(),
      };

  factory ShopBook.fromJson(Map<String, Object?> j) {
    List<T> list<T>(String k, T Function(Map<String, Object?>) f) => [for (final x in (j[k] as List? ?? const [])) if (x is Map) f(x.cast<String, Object?>())];
    final p = j['profile'];
    return ShopBook(
      products: list('products', Product.fromJson),
      sales: list('sales', Sale.fromJson),
      orders: list('orders', OrderLine.fromJson),
      customers: list('customers', Customer.fromJson),
      dealers: list('dealers', Dealer.fromJson),
      purchases: list('purchases', Purchase.fromJson),
      collections: list('collections', ShopPayment.fromJson),
      payouts: list('payouts', ShopPayment.fromJson),
      profile: p is Map ? ShopProfile.fromJson(p.cast<String, Object?>()) : const ShopProfile(),
    );
  }
}
