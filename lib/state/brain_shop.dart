part of 'brain.dart';

/// ব্যবসায়ী মোড (owner, 6 Nov): the shop's own actions. A sale writes its
/// money into আয়-ব্যয় (cash or QR) or the ledger (on credit) and takes the
/// products off the shelf; goods that came in go back on it and the cost
/// or the debt to the supplier is written the same way.
extension BrainShop on Brain {
  ShopBook get shop => data.shop;

  Future<void> saveProduct(Product p) async {
    _upsert(shop.products, p, (x) => x.id);
    await _save();
  }

  Future<void> deleteProduct(String id) async {
    final p = shop.products.where((x) => x.id == id).firstOrNull;
    if (p == null) return;
    _trash(p.name, [('product', p.toJson())]);
    shop.products.removeWhere((x) => x.id == id);
    shop.orders.removeWhere((o) => o.productId == id);
    await _save();
  }

  /// The next receipt number.
  int get nextSaleNo => shop.sales.fold<int>(0, (m, s) => s.no > m ? s.no : m) + 1;

  /// A sale: stock down, money where it belongs. Returns the sale as kept.
  Future<Sale> recordSale(Sale s) async {
    final now = services.now();
    String? cashId, ledgerId;
    final what = s.amountOnly > 0 ? tr('বিক্রি') : s.lines.map((l) => l.name).take(4).join(', ');
    if (s.total > 0) {
      if (s.pay == SalePay.credit && s.customer.trim().isNotEmpty) {
        final e = LedgerEntry(person: s.customer.trim(), kind: LedgerKind.lent, amount: s.total, date: s.at, note: '${tr('বাকিতে কেনা')} · $what', createdAt: now);
        _upsert(data.ledger, e, (x) => x.id);
        ledgerId = e.id;
      } else {
        final e = CashEntry(kind: CashKind.income, amount: s.total, category: tr('বিক্রি'), note: s.pay == SalePay.qr ? '${s.pay.label} · $what' : what, date: s.at, accountId: defaultAccountId(data), addedAt: now);
        _upsert(data.cash, e, (x) => x.id);
        cashId = e.id;
      }
    }
    for (final l in s.lines) {
      final i = shop.products.indexWhere((p) => p.id == l.productId);
      if (i < 0) continue;
      final p = shop.products[i];
      shop.products[i] = p.copyWith(stock: (p.stock - l.qty) < 0 ? 0 : p.stock - l.qty);
    }
    final kept = Sale(id: s.id, at: s.at, lines: s.lines, discount: s.discount, pay: s.pay, customer: s.customer.trim(), amountOnly: s.amountOnly, cashId: cashId, ledgerId: ledgerId, no: s.no > 0 ? s.no : nextSaleNo);
    _upsert(shop.sales, kept, (x) => x.id);
    _refillOrders();
    await _save();
    return kept;
  }

  /// A sale taken back: its money and its products return.
  Future<void> deleteSale(String id) async {
    final s = shop.sales.where((x) => x.id == id).firstOrNull;
    if (s == null) return;
    data.cash.removeWhere((e) => e.id == s.cashId);
    data.ledger.removeWhere((e) => e.id == s.ledgerId);
    for (final l in s.lines) {
      final i = shop.products.indexWhere((p) => p.id == l.productId);
      if (i >= 0) shop.products[i] = shop.products[i].copyWith(stock: shop.products[i].stock + l.qty);
    }
    shop.sales.removeWhere((x) => x.id == id);
    await _save();
  }

  /// "টাকা পেলাম": a buyer paid back [amount] (in cash, so it is in the box).
  Future<void> buyerPaid(String name, int amount) async {
    if (amount <= 0) return;
    _upsert(data.ledger, LedgerEntry(person: name, kind: LedgerKind.received, amount: amount, date: services.now(), note: tr('দোকানের বাকি আদায়'), createdAt: services.now()), (x) => x.id);
    await _save();
  }

  /// "+ বাকি দিলাম" without a sale (an old due written in, or goods by hand).
  Future<void> buyerOwes(String name, int amount, {String note = ''}) async {
    if (amount <= 0) return;
    _upsert(data.ledger, LedgerEntry(person: name, kind: LedgerKind.lent, amount: amount, date: services.now(), note: note.isEmpty ? tr('বাকি') : note, createdAt: services.now()), (x) => x.id);
    await _save();
  }

  Future<void> saveBuyer(Buyer b) async {
    _upsert(shop.buyers, b, (x) => x.name);
    await _save();
    await _reschedule();
  }

  /// Goods came in from [supplier]: back on the shelf; paid now (a cost in
  /// আয়-ব্যয়, খাত "মাল কেনা") or owed (দেবো in the ledger).
  Future<void> goodsIn(String supplier, List<(Product, double qty, int amount)> lines, {required bool paid}) async {
    final now = services.now();
    var total = 0;
    for (final (p, qty, amount) in lines) {
      final i = shop.products.indexWhere((x) => x.id == p.id);
      if (i >= 0) shop.products[i] = shop.products[i].copyWith(stock: shop.products[i].stock + qty);
      total += amount;
      shop.orders.removeWhere((o) => o.productId == p.id);
    }
    final what = lines.map((l) => l.$1.name).take(4).join(', ');
    if (total > 0) {
      if (paid || supplier.trim().isEmpty) {
        _upsert(data.cash, CashEntry(kind: CashKind.expense, amount: total, category: tr('মাল কেনা'), note: [if (supplier.trim().isNotEmpty) supplier.trim(), what].join(' · '), date: now, accountId: defaultAccountId(data), addedAt: now), (x) => x.id);
      } else {
        _upsert(data.ledger, LedgerEntry(person: supplier.trim(), kind: LedgerKind.borrowed, amount: total, date: now, note: '${tr('মাল কেনা')} · $what', createdAt: now), (x) => x.id);
      }
    }
    await _save();
  }

  /// The order list: running-low products come in by themselves; the
  /// shopkeeper's ticks and amounts stay.
  void _refillOrders() {
    for (final p in shop.products) {
      if (!p.isLow || shop.orders.any((o) => o.productId == p.id)) continue;
      shop.orders.add(OrderLine(productId: p.id, name: p.name, qty: suggestedOrder(p), unit: p.unit, supplier: p.supplier));
    }
  }

  Future<void> refreshOrders() async {
    _refillOrders();
    await _save();
  }

  Future<void> saveOrder(OrderLine o) async {
    _upsert(shop.orders, o, (x) => x.id);
    await _save();
  }

  Future<void> removeOrder(String id) async {
    shop.orders.removeWhere((o) => o.id == id);
    await _save();
  }

  /// The cash in the box when the shop opened today.
  Future<void> setOpening(int amount) async {
    shop.opening = (day: dayOnly(services.now()), amount: amount);
    await _save();
  }

  /// "দিন বন্ধ করুন": the box counted and kept; tomorrow starts with it.
  Future<DayClose> closeDay(int counted) async {
    final now = services.now();
    final box = cashBox(data, now);
    final c = DayClose(day: dayOnly(now), opening: box.opening, expected: box.expected, counted: counted);
    shop.closes.removeWhere((x) => sameDay(x.day, now));
    shop.closes.add(c);
    await _save();
    return c;
  }

  /// A shop cost (rent, electricity, a helper's pay): into আয়-ব্যয়.
  Future<void> shopCost(int amount, String category, {String note = ''}) =>
      saveCash(CashEntry(kind: CashKind.expense, amount: amount, category: category, note: note, date: services.now()));
}
