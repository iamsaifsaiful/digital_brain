part of 'brain.dart';

/// ব্যবসায়ী মোড (owner, 6 Nov): the shop's own actions. A sale writes its
/// cash into আয়-ব্যয় (cash or QR) or onto the customer's account (on
/// credit) and takes the products off the shelf; goods bought from a dealer
/// go back on it, paid in cash or owed to the dealer.
extension BrainShop on Brain {
  ShopBook get shop => data.shop;

  /// The whole business's account (ব্যবসার পুরো হিসাব).
  BizAccount get bizAcc => bizAccount(shop, data.cash);

  /// Something changed that is not a sale, a purchase or a payment (a
  /// product's amount corrected, an old due written in, something deleted
  /// or brought back): what it changed in the five sums is kept as a
  /// correction, so the whole account still adds up (owner, 23 Nov:
  /// "হিসাবে কোন গড়মিল না থাকে"). Only the change [edit] makes is kept.
  Future<T> _bizEdit<T>(String why, FutureOr<T> Function() edit) async {
    final before = bizAcc.gap;
    final r = await edit();
    final moved = bizAcc.gap - before;
    if (!moved.isZero) {
      shop.adjusts.add(ShopAdjust(at: services.now(), why: why, change: moved));
      await _save();
    }
    return r;
  }

  /// A product added or changed: a changed amount or worth is a correction.
  Future<void> saveProduct(Product p) => _bizEdit(trf('{0}: পণ্যের তথ্য বদল', [p.name]), () async {
        _upsert(shop.products, p, (x) => x.id);
        await _save();
      });

  Future<void> deleteProduct(String id) async {
    final p = shop.products.where((x) => x.id == id).firstOrNull;
    if (p == null) return;
    await _bizEdit(trf('{0} মুছে ফেলা', [p.name]), () async {
      _trash(p.name, [('product', p.toJson())]);
      shop.products.removeWhere((x) => x.id == id);
      shop.orders.removeWhere((o) => o.productId == id);
      await _save();
    });
  }

  /// Spoilt or expired goods taken off the shelf: a loss (ক্ষতি) at what
  /// they cost.
  Future<void> writeOff(String productId, double qty, {String why = ''}) async {
    final i = shop.products.indexWhere((p) => p.id == productId);
    if (i < 0 || qty <= 0) return;
    final p = shop.products[i];
    final q = qty > p.stock ? p.stock : qty;
    final cost = p.costOf(q);
    shop.products[i] = p.copyWith(stock: p.stock - q, value: p.value - cost);
    shop.adjusts.add(ShopAdjust(at: services.now(), why: why.isEmpty ? trf('{0} নষ্ট', [p.name]) : why, change: BizSums(stock: -cost), damaged: true));
    _refillOrders();
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

  /// A sale: the goods leave the shelf at their cost; what was paid goes
  /// into the business's money, the rest onto the customer's account. More
  /// than the shelf holds is first put on it at the bought price (a
  /// correction, so the stock never goes below nothing). Returns the sale
  /// as kept.
  Future<Sale> recordSale(Sale s) async {
    String? cashId;
    final what = s.amountOnly > 0 ? tr('বিক্রি') : s.lines.map((l) => l.name).take(4).join(', ');
    final c = s.customerId.isEmpty ? null : customerById(shop, s.customerId);
    final now = services.now();
    final lines = <SaleLine>[];
    for (final l in s.lines) {
      final i = shop.products.indexWhere((p) => p.id == l.productId);
      if (i < 0) {
        lines.add(l);
        continue;
      }
      var p = shop.products[i];
      if (l.qty > p.stock + 1e-9) {
        final missing = l.qty - (p.stock < 0 ? 0 : p.stock);
        final worth = (missing * p.buy).round();
        p = p.copyWith(stock: (p.stock < 0 ? 0 : p.stock) + missing, value: p.value + worth);
        shop.adjusts.add(ShopAdjust(at: now, why: trf('{0}: বিক্রির সময় স্টক কম ছিল', [p.name]), change: BizSums(stock: worth)));
      }
      final cost = p.costOf(l.qty);
      shop.products[i] = p.copyWith(stock: p.stock - l.qty, value: p.value - cost);
      lines.add(SaleLine(productId: l.productId, name: l.name, qty: l.qty, unit: l.unit, amount: l.amount, cost: cost));
    }
    final draft = Sale(id: s.id, at: s.at, lines: lines, discount: s.discount, discountPct: s.discountPct, pay: s.pay, amountOnly: s.amountOnly, paid: s.paid);
    if (draft.paidNow > 0) {
      cashId = _cashIn(draft.paidNow, 'বিক্রি', [if (s.pay == SalePay.qr) s.pay.label, if (draft.partial) tr('আংশিক'), if (c != null) c.name, what].join(' · '), s.at);
    }
    final kept = Sale(
        id: s.id,
        at: s.at,
        lines: lines,
        discount: s.discount,
        discountPct: s.discountPct,
        pay: s.pay,
        customerId: s.customerId,
        customer: c?.name ?? s.customer.trim(),
        amountOnly: s.amountOnly,
        cashId: cashId,
        no: s.no > 0 ? s.no : nextSaleNo,
        paid: s.pay == SalePay.credit ? s.paid : 0,
        note: s.note);
    _upsert(shop.sales, kept, (x) => x.id);
    _refillOrders();
    await _save();
    return kept;
  }

  /// A sale taken back: its money and its goods (at what they cost) return.
  Future<void> deleteSale(String id) async {
    final s = shop.sales.where((x) => x.id == id).firstOrNull;
    if (s == null) return;
    await _bizEdit(trf('বিক্রি #{0} বাতিল', [bnDigits(s.no)]), () async {
      data.cash.removeWhere((e) => e.id == s.cashId);
      for (final l in s.lines) {
        final i = shop.products.indexWhere((p) => p.id == l.productId);
        if (i >= 0) shop.products[i] = shop.products[i].copyWith(stock: shop.products[i].stock + l.qty, value: shop.products[i].value + l.cost);
      }
      shop.sales.removeWhere((x) => x.id == id);
      await _save();
    });
  }

  /// Goods a customer brought back from sale [saleId] (owner, 23 Nov): each
  /// line's share of what the sale charged (after its discount) and cost.
  /// Good goods go back on the shelf; spoilt ones are a loss. The money
  /// comes off their due, or is paid back in [cash].
  Future<CustomerReturn?> recordCustomerReturn(String saleId, Map<int, double> qtyByLine, {bool damaged = false, bool cash = false, String note = ''}) async {
    final s = shop.sales.where((x) => x.id == saleId).firstOrNull;
    if (s == null) return null;
    final net = s.netLines;
    final lines = <SaleLine>[];
    for (final (i, l) in s.lines.indexed) {
      final want = qtyByLine[i] ?? 0;
      final left = l.qty - returnedQty(shop, s.id, l);
      final q = want > left ? left : want;
      if (q <= 0 || l.qty <= 0) continue;
      final part = q / l.qty;
      lines.add(SaleLine(productId: l.productId, name: l.name, qty: q, unit: l.unit, amount: (net[i] * part).round(), cost: (l.cost * part).round()));
    }
    if (lines.isEmpty) return null;
    final at = services.now();
    final refund = lines.fold<int>(0, (a, l) => a + l.amount);
    // Cash back when asked, or when the sale owes nothing to take it off.
    final c = customerById(shop, s.customerId);
    final payBack = cash || c == null;
    final cashId = payBack && refund > 0 ? _cashOut(refund, 'মাল ফেরত', [if (c != null) c.name, trf('মেমো #{0}', [bnDigits(s.no)])].join(' · '), at) : null;
    if (!damaged) {
      for (final l in lines) {
        final i = shop.products.indexWhere((p) => p.id == l.productId);
        if (i >= 0) shop.products[i] = shop.products[i].copyWith(stock: shop.products[i].stock + l.qty, value: shop.products[i].value + l.cost);
      }
    }
    final r = CustomerReturn(at: at, saleId: s.id, saleNo: s.no, customerId: c?.id ?? '', customer: s.customer, lines: lines, damaged: damaged, cash: payBack, cashId: cashId, note: note);
    shop.customerReturns.add(r);
    await _save();
    return r;
  }

  /// Goods sent back to dealer [dealerId]: off the shelf at what they cost;
  /// [credit] (default: that cost) off what the shop owes them, or got back
  /// in cash, or to be made good with goods.
  Future<SupplierReturn?> recordSupplierReturn(String dealerId, List<(String productId, double qty)> items, {int? credit, ReturnPay pay = ReturnPay.payable, String reason = ''}) async {
    final d = dealerById(shop, dealerId);
    if (d == null) return null;
    final lines = <SaleLine>[];
    for (final (pid, qty) in items) {
      final i = shop.products.indexWhere((p) => p.id == pid);
      if (i < 0 || qty <= 0) continue;
      final p = shop.products[i];
      final q = qty > p.stock ? p.stock : qty;
      if (q <= 0) continue;
      final cost = p.costOf(q);
      shop.products[i] = p.copyWith(stock: p.stock - q, value: p.value - cost);
      lines.add(SaleLine(productId: p.id, name: p.name, qty: q, unit: p.unit, amount: cost, cost: cost));
    }
    if (lines.isEmpty) return null;
    final at = services.now();
    final worth = lines.fold<int>(0, (a, l) => a + l.cost);
    final back = credit ?? worth;
    final cashId = pay == ReturnPay.cash && back > 0 ? _cashIn(back, 'মাল ফেরত', d.name, at) : null;
    final r = SupplierReturn(at: at, dealerId: d.id, dealer: d.name, lines: lines, credit: back, pay: pay, cashId: cashId, reason: reason);
    shop.supplierReturns.add(r);
    _refillOrders();
    await _save();
    return r;
  }

  /// A return undone: goods, money and dues as they were.
  Future<void> undoReturn(String id) async {
    final cr = shop.customerReturns.where((x) => x.id == id).firstOrNull;
    final sr = shop.supplierReturns.where((x) => x.id == id).firstOrNull;
    await _bizEdit(tr('মাল ফেরত বাতিল'), () async {
      if (cr != null) {
        if (!cr.damaged) {
          for (final l in cr.lines) {
            final i = shop.products.indexWhere((p) => p.id == l.productId);
            if (i >= 0) shop.products[i] = shop.products[i].copyWith(stock: shop.products[i].stock - l.qty, value: shop.products[i].value - l.cost);
          }
        }
        data.cash.removeWhere((e) => e.id == cr.cashId);
        shop.customerReturns.removeWhere((x) => x.id == id);
      }
      if (sr != null) {
        for (final l in sr.lines) {
          final i = shop.products.indexWhere((p) => p.id == l.productId);
          if (i >= 0) shop.products[i] = shop.products[i].copyWith(stock: shop.products[i].stock + l.qty, value: shop.products[i].value + l.cost);
        }
        data.cash.removeWhere((e) => e.id == sr.cashId);
        shop.supplierReturns.removeWhere((x) => x.id == id);
      }
      await _save();
    });
  }

  // গ্রাহক ---------------------------------------------------------------

  /// A customer added or changed (a new one with the same name is the same customer).
  Future<Customer> saveCustomer(Customer c) => _bizEdit(trf('{0}: গ্রাহকের তথ্য বদল', [c.name]), () => _saveCustomer(c));

  Future<Customer> _saveCustomer(Customer c) async {
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
    await _bizEdit(trf('{0} মুছে ফেলা', [c.name]), () async {
      if (c.reminderId != null) await deleteReminder(c.reminderId!, trash: false);
      _trash(c.name, [('customer', c.toJson())]);
      shop.customers.removeWhere((x) => x.id == id);
      await _save();
    });
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
    await _bizEdit(trf('{0}: আগের বকেয়া যোগ', [c.name]), () async {
      _upsert(shop.customers, c.copyWith(opening: c.opening + amount), (x) => x.id);
      await _save();
    });
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
    return _bizEdit(trf('{0}: সাপ্লায়ারের তথ্য বদল', [d.name]), () async {
      _upsert(shop.dealers, d, (x) => x.id);
      await _save();
      return d;
    });
  }

  Future<Dealer> dealerFor(String name) async => dealerNamed(shop, name) ?? await saveDealer(Dealer(name: name.trim()));

  Future<void> deleteDealer(String id) async {
    final d = dealerById(shop, id);
    if (d == null) return;
    await _bizEdit(trf('{0} মুছে ফেলা', [d.name]), () async {
      _trash(d.name, [('dealer', d.toJson())]);
      shop.dealers.removeWhere((x) => x.id == id);
      await _save();
    });
  }

  /// Goods bought from a dealer: back on the shelf; [paid] of [total] paid
  /// now (a cost in আয়-ব্যয়, খাত "মাল কেনা"), the rest owed to the dealer.
  Future<Purchase> recordPurchase(String dealerId, List<(Product, double qty, int amount)> lines, {required int paid, int? total, String note = ''}) async {
    final at = services.now();
    final d = dealerById(shop, dealerId);
    final sum = total ?? lines.fold<int>(0, (s, l) => s + l.$3);
    // The goods go on the shelf at what they cost (a whole-bill [total]
    // spread over the lines by amount).
    final lineSum = lines.fold<int>(0, (s, l) => s + l.$3);
    var left = sum;
    final costs = [
      for (final (i, l) in lines.indexed)
        if (i == lines.length - 1) left else () {
          final v = lineSum > 0 ? (l.$3 * sum / lineSum).round() : 0;
          left -= v;
          return v;
        }(),
    ];
    for (final (k, (p, qty, _)) in lines.indexed) {
      final i = shop.products.indexWhere((x) => x.id == p.id);
      if (i >= 0) {
        final was = shop.products[i];
        final unit = qty > 0 ? (costs[k] / qty).round() : was.buy;
        shop.products[i] = was.copyWith(stock: was.stock + qty, value: was.value + costs[k], buy: unit > 0 ? unit : was.buy);
      }
      shop.orders.removeWhere((o) => o.productId == p.id);
    }
    final what = lines.map((l) => l.$1.name).take(4).join(', ');
    final pay = paid.clamp(0, sum);
    final cashId = pay > 0 ? _cashOut(pay, 'মাল কেনা', [if (d != null) d.name, what].join(' · '), at) : null;
    final p = Purchase(
      at: at,
      dealerId: dealerId,
      dealer: d?.name ?? '',
      lines: [for (final (k, (pr, qty, amount)) in lines.indexed) SaleLine(productId: pr.id, name: pr.name, qty: qty, unit: pr.unit, amount: amount, cost: costs[k])],
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
  Future<void> undoShopEntry(String id) => _bizEdit(tr('লেনদেন বাতিল'), () => _undoShopEntry(id));

  Future<void> _undoShopEntry(String id) async {
    final p = shop.purchases.where((x) => x.id == id).firstOrNull;
    if (p != null) {
      for (final l in p.lines) {
        final i = shop.products.indexWhere((x) => x.id == l.productId);
        if (i >= 0) shop.products[i] = shop.products[i].copyWith(stock: shop.products[i].stock - l.qty, value: shop.products[i].value - l.cost);
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
    for (final m in shop.loanMoves.where((x) => x.id == id).toList()) {
      data.cash.removeWhere((e) => e.id == m.cashId);
      shop.loanMoves.remove(m);
    }
    for (final m in shop.ownerMoves.where((x) => x.id == id).toList()) {
      data.cash.removeWhere((e) => e.id == m.cashId);
      shop.ownerMoves.remove(m);
    }
    await _save();
  }

  // ঋণ ও মালিকের টাকা -----------------------------------------------------

  /// A loan written in or changed: what was owed on it is a correction
  /// (money taken now is [takeLoan]).
  Future<Loan> saveLoan(Loan l) => _bizEdit(trf('{0}: ঋণের তথ্য বদল', [l.name]), () async {
        _upsert(shop.loans, l, (x) => x.id);
        await _save();
        return l;
      });

  Future<void> deleteLoan(String id) async {
    final l = shop.loans.where((x) => x.id == id).firstOrNull;
    if (l == null) return;
    await _bizEdit(trf('{0} মুছে ফেলা', [l.name]), () async {
      for (final m in shop.loanMoves.where((m) => m.loanId == id).toList()) {
        data.cash.removeWhere((e) => e.id == m.cashId);
        shop.loanMoves.remove(m);
      }
      shop.loans.removeWhere((x) => x.id == id);
      await _save();
    });
  }

  /// Money borrowed into the business: cash in, owed more.
  Future<LoanMove?> takeLoan(String loanId, int amount, {String note = ''}) async {
    final l = shop.loans.where((x) => x.id == loanId).firstOrNull;
    if (l == null || amount <= 0) return null;
    final at = services.now();
    final m = LoanMove(at: at, loanId: l.id, amount: amount, take: true, cashId: _cashIn(amount, 'ঋণ নেওয়া', l.name, at), note: note);
    shop.loanMoves.add(m);
    await _save();
    return m;
  }

  /// An instalment: [principal] off the loan, [interest] a cost (ঋণের সুদ).
  Future<LoanMove?> repayLoan(String loanId, int principal, {int interest = 0, String note = ''}) async {
    final l = shop.loans.where((x) => x.id == loanId).firstOrNull;
    if (l == null || principal + interest <= 0) return null;
    final at = services.now();
    LoanMove? m;
    if (principal > 0) {
      m = LoanMove(at: at, loanId: l.id, amount: principal, cashId: _cashOut(principal, 'ঋণের কিস্তি', l.name, at), note: note);
      shop.loanMoves.add(m);
    }
    if (interest > 0) _cashOut(interest, 'ঋণের সুদ', l.name, at);
    await _save();
    return m;
  }

  /// The owner putting money in ([inward]) or taking it out of the business.
  Future<OwnerMove?> ownerMoney(int amount, {required bool inward, String note = ''}) async {
    if (amount <= 0) return null;
    final at = services.now();
    final cashId = inward ? _cashIn(amount, 'মালিকের জমা', note, at) : _cashOut(amount, 'মালিক নিলেন', note, at);
    final m = OwnerMove(at: at, amount: amount, inward: inward, cashId: cashId, note: note);
    shop.ownerMoves.add(m);
    await _save();
    return m;
  }

  // শুরুর হিসাব ------------------------------------------------------------

  /// The first questions answered (owner, 23 Nov): the cash now ([cash],
  /// null = as the app has it), the goods on the shelf, what customers owe,
  /// what dealers are owed, the loans. All written in at one moment, then
  /// the five sums are kept as where the business began; its capital is
  /// worked out, never typed.
  Future<BizStart> startBusiness({
    required String kind,
    int? cash,
    String shopName = '',
    String type = '',
    List<Product> products = const [],
    List<(String name, String phone, int due)> customers = const [],
    List<(String name, int owed)> dealers = const [],
    List<(String name, int owed, int installment)> loans = const [],
  }) async {
    final at = services.now();
    if (shopName.trim().isNotEmpty) shop.profile = shop.profile.copyWith(name: shopName.trim());
    if (cash != null) {
      final diff = cash - bizCashBalance(data.cash);
      if (diff != 0) {
        final e = CashEntry(kind: diff > 0 ? CashKind.income : CashKind.expense, amount: diff.abs(), category: 'শুরুর হিসাব', note: tr('ব্যবসার শুরুর নগদ'), date: at, projectId: bizCash, addedAt: at);
        data.cash.add(e);
      }
    }
    for (final p in products) {
      _upsert(shop.products, p, (x) => x.id);
    }
    for (final (name, phone, due) in customers) {
      if (name.trim().isEmpty) continue;
      final was = customerNamed(shop, name);
      final c = was ?? Customer(name: name.trim(), phone: phone.trim(), added: at);
      _upsert(shop.customers, c.copyWith(opening: (was?.opening ?? 0) + due), (x) => x.id);
    }
    for (final (name, owed) in dealers) {
      if (name.trim().isEmpty) continue;
      final was = dealerNamed(shop, name);
      final d = was ?? Dealer(name: name.trim());
      _upsert(shop.dealers, d.copyWith(opening: (was?.opening ?? 0) + owed), (x) => x.id);
    }
    for (final (name, owed, installment) in loans) {
      if (name.trim().isEmpty || owed <= 0) continue;
      shop.loans.add(Loan(name: name.trim(), opening: owed, installment: installment));
    }
    final s = BizStart(at: at, kind: kind, sums: bizSums(shop, data.cash), before: bizEntryIds(shop, data.cash), type: type);
    shop.start = s;
    _refillOrders();
    await _save();
    return s;
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
