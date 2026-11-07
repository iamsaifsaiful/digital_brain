part of 'brain.dart';

/// ব্যবসায়ী মোড (owner, 6 Nov): the shop's own actions. A sale writes its
/// cash into আয়-ব্যয় (cash or QR) or onto the customer's account (on
/// credit) and takes the products off the shelf; goods bought from a dealer
/// go back on it, paid in cash or owed to the dealer.
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

  String _cashIn(int amount, String category, String note, DateTime at) {
    final e = CashEntry(kind: CashKind.income, amount: amount, category: category, note: note, date: at, projectId: bizCash, addedAt: services.now());
    _upsert(data.cash, e, (x) => x.id);
    return e.id;
  }

  String _cashOut(int amount, String category, String note, DateTime at) {
    final e = CashEntry(kind: CashKind.expense, amount: amount, category: category, note: note, date: at, projectId: bizCash, addedAt: services.now());
    _upsert(data.cash, e, (x) => x.id);
    return e.id;
  }

  /// A sale: stock down; cash and QR into আয়-ব্যয়, credit onto the
  /// customer's account. Returns the sale as kept.
  Future<Sale> recordSale(Sale s) async {
    String? cashId;
    final what = s.amountOnly > 0 ? tr('বিক্রি') : s.lines.map((l) => l.name).take(4).join(', ');
    final c = s.customerId.isEmpty ? null : customerById(shop, s.customerId);
    if (s.total > 0 && s.pay != SalePay.credit) {
      cashId = _cashIn(s.total, 'বিক্রি', [if (s.pay == SalePay.qr) s.pay.label, if (c != null) c.name, what].join(' · '), s.at);
    }
    for (final l in s.lines) {
      final i = shop.products.indexWhere((p) => p.id == l.productId);
      if (i < 0) continue;
      final p = shop.products[i];
      shop.products[i] = p.copyWith(stock: (p.stock - l.qty) < 0 ? 0 : p.stock - l.qty);
    }
    final kept = Sale(
        id: s.id,
        at: s.at,
        lines: s.lines,
        discount: s.discount,
        discountPct: s.discountPct,
        pay: s.pay,
        customerId: s.customerId,
        customer: c?.name ?? s.customer.trim(),
        amountOnly: s.amountOnly,
        cashId: cashId,
        no: s.no > 0 ? s.no : nextSaleNo);
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
    for (final l in s.lines) {
      final i = shop.products.indexWhere((p) => p.id == l.productId);
      if (i >= 0) shop.products[i] = shop.products[i].copyWith(stock: shop.products[i].stock + l.qty);
    }
    shop.sales.removeWhere((x) => x.id == id);
    await _save();
  }

  // গ্রাহক ---------------------------------------------------------------

  /// A customer added or changed (a new one with the same name is the same customer).
  Future<Customer> saveCustomer(Customer c) async {
    final same = shop.customers.where((x) => x.id != c.id && x.name.trim() == c.name.trim()).firstOrNull;
    final kept = same == null ? (c.added.year == 2000 ? Customer.fromJson({...c.toJson(), 'added': services.now().toIso8601String()}) : c) : same;
    if (same == null) _upsert(shop.customers, kept, (x) => x.id);
    await _save();
    return kept;
  }

  /// The customer named [name], made if there is none.
  Future<Customer> customerFor(String name) async => customerNamed(shop, name) ?? await saveCustomer(Customer(name: name.trim()));

  Future<void> deleteCustomer(String id) async {
    final c = customerById(shop, id);
    if (c == null) return;
    if (c.reminderId != null) await deleteReminder(c.reminderId!, trash: false);
    _trash(c.name, [('customer', c.toJson())]);
    shop.customers.removeWhere((x) => x.id == id);
    await _save();
  }

  /// "টাকা পেলাম": a customer paid [amount] of their বাকি (into আয়-ব্যয়
  /// as বাকি আদায়). Paid off: the collection reminder goes.
  Future<void> customerPaid(String id, int amount, {String note = ''}) async {
    final c = customerById(shop, id);
    if (c == null || amount <= 0) return;
    final at = services.now();
    final cashId = _cashIn(amount, 'বাকি আদায়', c.name, at);
    shop.collections.add(ShopPayment(at: at, party: id, amount: amount, cashId: cashId, note: note));
    if (customerAccount(shop, c).due <= 0 && c.reminderId != null) {
      data.reminders.removeWhere((r) => r.id == c.reminderId);
      _upsert(shop.customers, c.copyWith(clearReminder: true, clearDue: true), (x) => x.id);
      await services.notifier.stopRinging(c.reminderId!);
    }
    await _save();
    await _reschedule();
  }

  /// "আগের বাকি": a due from before the app, written in by hand (not a sale,
  /// so today's sales stay as they were).
  Future<void> customerOwes(String id, int amount, {String note = ''}) async {
    final c = customerById(shop, id);
    if (c == null || amount <= 0) return;
    _upsert(shop.customers, c.copyWith(opening: c.opening + amount), (x) => x.id);
    await _save();
  }

  /// The reminder to collect from a customer (owner, 6 Nov: "বাকির
  /// রিমাইন্ডার সেট করার অপশন"): an ordinary app reminder, so it rings in
  /// either mode and counts like any other on the free app. False when the
  /// free app's reminders are full.
  Future<bool> setCollectReminder(String customerId, DateTime at, {Repeat repeat = Repeat.none}) async {
    final c = customerById(shop, customerId);
    if (c == null) return false;
    final old = c.reminderId == null ? null : reminderById(c.reminderId!);
    if (old == null && !canAddReminder) return false;
    final due = customerAccount(shop, c).due;
    final r = Reminder(
      id: old?.id,
      title: trf('{0}-এর কাছে বাকি আদায়', [c.name]),
      date: dayOnly(at),
      hour: at.hour,
      minute: at.minute,
      repeat: repeat,
      weekdays: repeat == Repeat.weekly ? [at.weekday] : const [],
      note: due > 0 ? trf('বাকি {0}', [taka(due)]) : '',
    );
    _upsert(shop.customers, c.copyWith(reminderId: r.id, dueDay: dayOnly(at)), (x) => x.id);
    await saveReminder(r);
    return true;
  }

  Future<void> clearCollectReminder(String customerId) async {
    final c = customerById(shop, customerId);
    if (c == null) return;
    if (c.reminderId != null) await deleteReminder(c.reminderId!, trash: false);
    _upsert(shop.customers, c.copyWith(clearReminder: true, clearDue: true), (x) => x.id);
    await _save();
  }

  Future<void> markTagadaSent(String customerId) async {
    final c = customerById(shop, customerId);
    if (c == null) return;
    _upsert(shop.customers, c.copyWith(lastSent: services.now()), (x) => x.id);
    await _save();
  }

  // ডিলার -------------------------------------------------------------------

  Future<Dealer> saveDealer(Dealer d) async {
    final same = shop.dealers.where((x) => x.id != d.id && x.name.trim() == d.name.trim()).firstOrNull;
    if (same != null) return same;
    _upsert(shop.dealers, d, (x) => x.id);
    await _save();
    return d;
  }

  Future<Dealer> dealerFor(String name) async => dealerNamed(shop, name) ?? await saveDealer(Dealer(name: name.trim()));

  Future<void> deleteDealer(String id) async {
    final d = dealerById(shop, id);
    if (d == null) return;
    _trash(d.name, [('dealer', d.toJson())]);
    shop.dealers.removeWhere((x) => x.id == id);
    await _save();
  }

  /// Goods bought from a dealer: back on the shelf; [paid] of [total] paid
  /// now (a cost in আয়-ব্যয়, খাত "মাল কেনা"), the rest owed to the dealer.
  Future<Purchase> recordPurchase(String dealerId, List<(Product, double qty, int amount)> lines, {required int paid, int? total, String note = ''}) async {
    final at = services.now();
    final d = dealerById(shop, dealerId);
    final sum = total ?? lines.fold<int>(0, (s, l) => s + l.$3);
    for (final (p, qty, _) in lines) {
      final i = shop.products.indexWhere((x) => x.id == p.id);
      if (i >= 0) shop.products[i] = shop.products[i].copyWith(stock: shop.products[i].stock + qty);
      shop.orders.removeWhere((o) => o.productId == p.id);
    }
    final what = lines.map((l) => l.$1.name).take(4).join(', ');
    final pay = paid.clamp(0, sum);
    final cashId = pay > 0 ? _cashOut(pay, 'মাল কেনা', [if (d != null) d.name, what].join(' · '), at) : null;
    final p = Purchase(
      at: at,
      dealerId: dealerId,
      dealer: d?.name ?? '',
      lines: [for (final (pr, qty, amount) in lines) SaleLine(productId: pr.id, name: pr.name, qty: qty, unit: pr.unit, amount: amount, cost: amount)],
      total: sum,
      paid: pay,
      cashId: cashId,
      note: note,
    );
    shop.purchases.add(p);
    await _save();
    return p;
  }

  /// The shop paid a dealer (into আয়-ব্যয় as ডিলারকে পরিশোধ).
  Future<void> dealerPaid(String id, int amount, {String note = ''}) async {
    final d = dealerById(shop, id);
    if (d == null || amount <= 0) return;
    final at = services.now();
    final cashId = _cashOut(amount, 'ডিলারকে পরিশোধ', d.name, at);
    shop.payouts.add(ShopPayment(at: at, party: id, amount: amount, cashId: cashId, note: note));
    await _save();
  }

  /// An entry undone (a purchase, a collection or a payout): its cash goes
  /// too, and a purchase's goods leave the shelf again.
  Future<void> undoShopEntry(String id) async {
    final p = shop.purchases.where((x) => x.id == id).firstOrNull;
    if (p != null) {
      for (final l in p.lines) {
        final i = shop.products.indexWhere((x) => x.id == l.productId);
        if (i >= 0) shop.products[i] = shop.products[i].copyWith(stock: (shop.products[i].stock - l.qty).clamp(0, double.infinity));
      }
      data.cash.removeWhere((e) => e.id == p.cashId);
      shop.purchases.removeWhere((x) => x.id == id);
    }
    for (final list in [shop.collections, shop.payouts]) {
      for (final x in list.where((x) => x.id == id).toList()) {
        data.cash.removeWhere((e) => e.id == x.cashId);
        list.remove(x);
      }
    }
    await _save();
  }

  Future<void> saveShopProfile(ShopProfile p) async {
    shop.profile = p;
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

  /// A shop cost (rent, electricity, a helper's pay): the business's own
  /// আয়-ব্যয়, never the personal one.
  Future<void> shopCost(int amount, String category, {String note = ''}) =>
      saveCash(CashEntry(kind: CashKind.expense, amount: amount, category: category, note: note, date: services.now(), projectId: bizCash));

  /// Money the business took in or paid out, said or typed in ব্যবসায়ী মোড.
  Future<void> bizMoney(CashKind kind, int amount, String category, {String note = '', DateTime? at}) =>
      saveCash(CashEntry(kind: kind, amount: amount, category: category, note: note, date: at ?? services.now(), projectId: bizCash));

  /// From before 7 Nov the shop's money was written into the personal
  /// আয়-ব্যয়: the entries a sale, a collection, a purchase or a payout made
  /// (and the shop's own costs) move to the business's — once, nothing lost.
  bool moveBizCash() {
    final linked = {
      for (final s in shop.sales) if (s.cashId != null) s.cashId!,
      for (final p in shop.purchases) if (p.cashId != null) p.cashId!,
      for (final x in [...shop.collections, ...shop.payouts]) if (x.cashId != null) x.cashId!,
    };
    const shopOnly = {'দোকান ভাড়া', 'কর্মচারীর বেতন', 'দোকান খরচ', 'মাল কেনা', 'ডিলারকে পরিশোধ'};
    final used = shop.products.isNotEmpty || shop.sales.isNotEmpty;
    var moved = false;
    for (var i = 0; i < data.cash.length; i++) {
      final e = data.cash[i];
      if (e.projectId != null || e.shopId != null || e.linkId != null) continue;
      if (!linked.contains(e.id) && !(used && e.kind == CashKind.expense && shopOnly.contains(e.category))) continue;
      data.cash[i] = CashEntry(id: e.id, kind: e.kind, amount: e.amount, category: e.category, note: e.note, date: e.date, projectId: bizCash, addedAt: e.addedAt);
      moved = true;
    }
    return moved;
  }
}
