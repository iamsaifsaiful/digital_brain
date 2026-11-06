import 'package:digital_brain/logic/shop_logic.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/brain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig;

/// ব্যবসায়ী মোড (owner, 6 Nov): the shop's book and the money it moves.
void main() {
  Future<Rig> rig() async {
    final r = Rig();
    await r.brain.load();
    r.nowAt = DateTime(2026, 11, 6, 18);
    return r;
  }

  test('a cash sale: stock down, income in আয়-ব্যয়, a receipt number', () async {
    final r = await rig();
    final b = r.brain;
    final rice = Product(name: 'মিনিকেট চাল', unit: 'কেজি', buy: 64, sell: 72, stock: 20, low: 10, category: 'চাল-ডাল', supplier: 'করিম ট্রেডার্স');
    await b.saveProduct(rice);
    final s = await b.recordSale(Sale(at: r.nowAt, lines: [SaleLine(productId: rice.id, name: rice.name, qty: 12, unit: 'কেজি', amount: rice.priceOf(12), cost: 64 * 12)]));
    expect(s.no, 1);
    expect(b.shop.products.single.stock, 8);
    expect(b.data.cash.single.amount, 864);
    expect(b.data.cash.single.kind, CashKind.income);
    final sum = DaySum(salesOn(b.shop, r.nowAt));
    expect(sum.total, 864);
    expect(sum.profit, 96);
    // 8 left with a low mark of 10: it goes onto the order list by itself.
    expect(b.shop.orders.single.productId, rice.id);
    expect(b.shop.orders.single.qty, 22);
    expect(b.shop.orders.single.supplier, 'করিম ট্রেডার্স');
  });

  test('on credit: the customer owes it on their own account (not the personal ledger); paid back goes into আয়-ব্যয়', () async {
    final r = await rig();
    final b = r.brain;
    final c = await b.customerFor('রহিম মিয়া');
    await b.recordSale(Sale(at: r.nowAt, lines: const [], amountOnly: 780, pay: SalePay.credit, customerId: c.id));
    expect(b.data.ledger, isEmpty, reason: 'owner, 6 Nov: not the ধার-দেনা');
    expect(b.data.cash, isEmpty);
    expect(customerAccount(b.shop, c).due, 780);
    expect(owing(b.shop).single.name, 'রহিম মিয়া');
    await b.customerPaid(c.id, 500);
    expect(customerAccount(b.shop, c).due, 280);
    expect(b.data.cash.single.category, 'বাকি আদায়');
    expect(todayCash(b.data, r.nowAt).collected, 500);
  });

  test('wholesale price and loose weights', () {
    final dal = Product(name: 'মসুর ডাল (খোলা)', sell: 110, loose: true, bulkFrom: 25, bulkPrice: 102);
    expect(dal.priceOf(1.25), 138);
    expect(dal.priceOf(25), 2550);
    expect(qtyText(1.25), '1.25');
    expect(qtyText(5), '5');
  });

  test('dues: the oldest unpaid day, and older than 30 days shows', () async {
    final r = await rig();
    final b = r.brain;
    final c = await b.customerFor('সালমা');
    await b.recordSale(Sale(at: DateTime(2026, 9, 20), lines: const [], amountOnly: 600, pay: SalePay.credit, customerId: c.id));
    await b.recordSale(Sale(at: DateTime(2026, 10, 25), lines: const [], amountOnly: 400, pay: SalePay.credit, customerId: c.id));
    expect(customerAccount(b.shop, c).since, DateTime(2026, 9, 20));
    expect(longOwing(b.shop, r.nowAt).single.name, 'সালমা');
    // 600 paid: the September sale is cleared, the October one is left.
    await b.customerPaid(c.id, 600);
    final a = customerAccount(b.shop, c);
    expect(a.due, 400);
    expect(a.since, DateTime(2026, 10, 25));
    expect(longOwing(b.shop, r.nowAt), isEmpty);
  });

  test('a dealer: goods bought part paid, the rest owed; paying clears it', () async {
    final r = await rig();
    final b = r.brain;
    final oil = Product(name: 'সয়াবিন তেল ১ লি.', unit: 'বোতল', buy: 175, sell: 185, stock: 2, low: 5, supplier: 'করিম ট্রেডার্স');
    await b.saveProduct(oil);
    await b.refreshOrders();
    expect(b.shop.orders, hasLength(1));
    final d = await b.dealerFor('করিম ট্রেডার্স');
    final p = await b.recordPurchase(d.id, [(oil, 20, 3500)], paid: 1000);
    expect(b.shop.products.single.stock, 22);
    expect(b.shop.orders, isEmpty);
    expect(p.owed, 2500);
    expect(dealerAccount(b.shop, d).due, 2500);
    expect(owedToDealers(b.shop).single.name, 'করিম ট্রেডার্স');
    expect(b.data.cash.single.category, 'মাল কেনা');
    expect(b.data.ledger, isEmpty);
    await b.dealerPaid(d.id, 2500);
    expect(dealerAccount(b.shop, d).due, 0);
    expect(todayCash(b.data, r.nowAt).out, 3500);
    // Undone: the goods leave the shelf, the cash entry goes.
    await b.undoShopEntry(p.id);
    expect(b.shop.products.single.stock, 2);
    expect(b.data.cash.where((e) => e.category == 'মাল কেনা'), isEmpty);
  });

  test('the collection reminder is an app reminder (free limit counts) and goes when paid off', () async {
    final r = await rig();
    final b = r.brain;
    final c = await b.customerFor('করিম');
    await b.customerOwes(c.id, 900);
    expect(await b.setCollectReminder(c.id, DateTime(2026, 11, 10, 10)), isTrue);
    final rem = b.data.reminders.single;
    expect(rem.title, 'করিম-এর কাছে বাকি আদায়');
    expect((rem.hour, rem.minute), (10, 0));
    expect(customerById(b.shop, c.id)!.reminderId, rem.id);
    await b.customerPaid(c.id, 900);
    expect(b.data.reminders, isEmpty);
    expect(customerById(b.shop, c.id)!.reminderId, isNull);
  });

  test('the তাগাদা fills its [] words; the receipt carries the shop', () {
    expect(fillTagada(defaultTagada, name: 'রহিম', due: '৳১,২৫০', shop: 'মা স্টোর'), 'আসসালামু আলাইকুম রহিম, মা স্টোর-এ আপনার বাকি ৳১,২৫০। সুবিধামতো পরিশোধ করবেন। ধন্যবাদ।');
    final s = Sale(at: DateTime(2026, 11, 6, 15, 5), lines: [const SaleLine(name: 'চিনি', qty: 2, unit: 'কেজি', amount: 260)], discount: 26, discountPct: 10, no: 7, customer: 'রহিম');
    const profile = ShopProfile(name: 'মা স্টোর', address: 'স্টেশন রোড', phone: '01711000000');
    final t = receiptText(s, (n) => '৳$n', (x) => x, profile: profile);
    expect(t, contains('মা স্টোর'));
    expect(t, contains('ছাড় (10%) — ৳26'));
    expect(t, contains('মোট: ৳234'));
    final spec = receiptSpec(s, profile, taka: (n) => '৳$n', digits: (x) => x, logo: [1, 2, 3]);
    expect(spec['title'], 'মা স্টোর');
    expect(spec['page'], [420, 595]);
    expect(spec['logo'], [1, 2, 3]);
  });

  test('a deleted sale gives its products and money back; the book survives a save', () async {
    final r = await rig();
    final b = r.brain;
    final egg = Product(name: 'ফার্মের ডিম', unit: 'হালি', sell: 50, stock: 10);
    await b.saveProduct(egg);
    final s = await b.recordSale(Sale(at: r.nowAt, lines: [SaleLine(productId: egg.id, name: egg.name, qty: 2, unit: 'হালি', amount: 100)]));
    await b.deleteSale(s.id);
    expect(b.shop.products.single.stock, 10);
    expect(b.data.cash, isEmpty);
    await b.saveProduct(egg.copyWith(expiry: DateTime(2026, 11, 7)));
    final back = AppData.fromJson(b.data.toJson());
    expect(back.shop.products.single.expiry, DateTime(2026, 11, 7));
    expect(expiring(back.shop, r.nowAt).single.name, egg.name);
    await b.deleteProduct(egg.id);
    expect(b.shop.products, isEmpty);
    await b.undoLastDelete();
    expect(b.shop.products.single.name, egg.name);
  });
}
