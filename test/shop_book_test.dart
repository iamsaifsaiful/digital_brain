import 'package:digital_brain/logic/ledger.dart';
import 'package:digital_brain/logic/shop_logic.dart';
import 'package:digital_brain/models/models.dart';
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

  test('on credit: the buyer owes it in the ledger; paid back in cash goes into the box', () async {
    final r = await rig();
    final b = r.brain;
    await b.recordSale(Sale(at: r.nowAt, lines: const [], amountOnly: 780, pay: SalePay.credit, customer: 'রহিম মিয়া'));
    expect(owing(b.data).single.name, 'রহিম মিয়া');
    expect(owing(b.data).single.balance, 780);
    expect(b.data.cash, isEmpty, reason: 'nothing came in yet');
    await b.buyerPaid('রহিম মিয়া', 500);
    expect(owing(b.data).single.balance, 280);
    expect(cashBox(b.data, r.nowAt).collected, 500);
  });

  test('wholesale price and loose weights', () {
    final dal = Product(name: 'মসুর ডাল (খোলা)', sell: 110, loose: true, bulkFrom: 25, bulkPrice: 102);
    expect(dal.priceOf(1.25), 138);
    expect(dal.priceOf(25), 2550);
    expect(qtyText(1.25), '1.25');
    expect(qtyText(5), '5');
  });

  test('goods in: back on the shelf; owed to the supplier or paid', () async {
    final r = await rig();
    final b = r.brain;
    final oil = Product(name: 'সয়াবিন তেল ১ লি.', unit: 'বোতল', buy: 175, sell: 185, stock: 2, low: 5, supplier: 'করিম ট্রেডার্স');
    await b.saveProduct(oil);
    await b.refreshOrders();
    expect(b.shop.orders, hasLength(1));
    await b.goodsIn('করিম ট্রেডার্স', [(oil, 20, 3500)], paid: false);
    expect(b.shop.products.single.stock, 22);
    expect(b.shop.orders, isEmpty);
    expect(owed(b.data).single.name, 'করিম ট্রেডার্স');
    expect(owed(b.data).single.balance, -3500);
    await b.goodsIn('', [(oil, 5, 875)], paid: true);
    expect(b.data.cash.single.category, 'মাল কেনা');
  });

  test('the day closes: the box counted against what it should hold', () async {
    final r = await rig();
    final b = r.brain;
    await b.setOpening(1000);
    await b.recordSale(Sale(at: r.nowAt, lines: const [], amountOnly: 9850));
    await b.shopCost(580, 'দোকান খরচ');
    final box = cashBox(b.data, r.nowAt);
    expect(box.expected, 1000 + 9850 - 580);
    final c = await b.closeDay(10250);
    expect(c.diff, -20);
    // Tomorrow starts with the count.
    expect(cashBox(b.data, r.nowAt.add(const Duration(days: 1))).opening, 10250);
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

  test('the ledger balances see shop credit like any loan', () {
    final d = AppData(ledger: [LedgerEntry(person: 'সালমা', kind: LedgerKind.lent, amount: 1850, date: DateTime(2026, 11, 3))]);
    expect(balances(d.ledger).single.balance, 1850);
  });
}

