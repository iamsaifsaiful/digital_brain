// Owner, 23 Nov: "লজিক গুলো ঠিক ভাবে কাজ করে কিনা, তার একটা লিস্ট দিও, মানে
// যেন, হিসাবে কোন গড়মিল না থাকে" — and "অনেক সময় মাল ফেরত যায়". The rules
// as promised in the thread, one test each, then a long random day of
// business after which every sum must still add up.
import 'dart:math';

import 'package:digital_brain/logic/biz_account.dart';
import 'package:digital_brain/logic/shop_logic.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/brain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig;

/// A shop as in the plan's pictures: ৳45,000 cash, rice and oil on the
/// shelf, Karim owing ৳9,200, Akij owed ৳24,000, a bank loan of ৳50,000.
Future<(Rig, Brain)> shopRig() async {
  final rig = Rig();
  final b = rig.brain;
  await b.load();
  await b.startBusiness(
    kind: 'old',
    cash: 45000,
    shopName: 'রহমান জেনারেল স্টোর',
    products: [
      Product(name: 'মিনিকেট চাল', unit: 'কেজি', buy: 62, sell: 70, stock: 120, low: 25),
      Product(name: 'সয়াবিন তেল ৫ লি.', unit: 'বোতল', buy: 820, sell: 850, stock: 24),
    ],
    customers: [('করিম মিয়া', '', 9200)],
    dealers: [('আকিজ', 24000)],
    loans: [('ব্র্যাক ব্যাংক', 50000, 5500)],
  );
  rig.nowAt = rig.nowAt.add(const Duration(minutes: 1));
  return (rig, b);
}

Product prod(Brain b, String name) => b.shop.products.firstWhere((p) => p.name == name);
Customer cust(Brain b, String name) => b.shop.customers.firstWhere((c) => c.name == name);
Dealer dealer(Brain b, String name) => b.shop.dealers.firstWhere((d) => d.name == name);

Future<Sale> sell(Brain b, List<(Product, double)> items, {SalePay pay = SalePay.cash, Customer? c, int paid = 0, int discount = 0, double pct = 0}) {
  final lines = [for (final (p, q) in items) SaleLine(productId: p.id, name: p.name, qty: q, unit: p.unit, amount: p.priceOf(q))];
  final sub = lines.fold<int>(0, (s, l) => s + l.amount);
  final off = pct > 0 ? (sub * pct / 100).round() : discount;
  return b.recordSale(Sale(at: b.services.now(), lines: lines, pay: pay, customerId: c?.id ?? '', discount: off, discountPct: pct, paid: paid));
}

void expectAdds(Brain b, [String why = '']) {
  final a = b.bizAcc;
  expect(a.gap.isZero, isTrue, reason: 'gap $why: ${a.gap}');
  expect(a.adds, isTrue, reason: 'capital $why: ${a.now.capital} vs ${a.start.capital} + ${a.flows.capitalChange}');
}

void main() {
  test('১. মূলধন = ক্যাশ + মাল + বাজারে বকেয়া − ডিলারের দেনা − ঋণ, worked out at the start, never typed', () async {
    final (_, b) = await shopRig();
    final s = b.shop.start!;
    expect(s.kind, 'old');
    expect(s.sums.cash, 45000);
    expect(s.sums.stock, 120 * 62 + 24 * 820);
    expect(s.sums.dues, 9200);
    expect(s.sums.payable, 24000);
    expect(s.sums.loans, 50000);
    expect(s.capital, 45000 + 7440 + 19680 + 9200 - 24000 - 50000);
    expect(b.bizAcc.now.capital, s.capital);
    expectAdds(b);
  });

  test('২. ক্যাশ: শুরুর নগদ + যত এলো − যত গেলো = হোমের ক্যাশ', () async {
    final (_, b) = await shopRig();
    final rice = prod(b, 'মিনিকেট চাল');
    await sell(b, [(rice, 10)]); // +700
    await b.customerPaid(cust(b, 'করিম মিয়া').id, 2000); // +2000
    await b.shopCost(1850, 'বিদ্যুৎ বিল'); // −1850
    await b.ownerMoney(10000, inward: true); // +10000
    await b.ownerMoney(3000, inward: false); // −3000
    final a = b.bizAcc;
    expect(a.now.cash, 45000 + 700 + 2000 - 1850 + 10000 - 3000);
    expect(bizCashBalance(b.data.cash), a.now.cash);
    expect(a.flows.expenses, 1850);
    expectAdds(b);
  });

  test('৩. স্টক: শুরু + এলো − বিক্রি − নষ্ট = এখন; কখনো মাইনাসে যায় না', () async {
    final (_, b) = await shopRig();
    final rice = prod(b, 'মিনিকেট চাল');
    await b.recordPurchase(dealer(b, 'আকিজ').id, [(rice, 50, 3250)], paid: 3250); // 50 kg at 65
    expect(prod(b, 'মিনিকেট চাল').stock, 170);
    expect(prod(b, 'মিনিকেট চাল').value, 7440 + 3250);
    await sell(b, [(prod(b, 'মিনিকেট চাল'), 20)]);
    await b.writeOff(rice.id, 5);
    expect(prod(b, 'মিনিকেট চাল').stock, 145);
    // Selling more than the shelf holds: the missing part goes on first (a
    // correction), so the shelf ends at nothing, not below it.
    await sell(b, [(prod(b, 'মিনিকেট চাল'), 150)]);
    expect(prod(b, 'মিনিকেট চাল').stock, 0);
    expect(prod(b, 'মিনিকেট চাল').value, 0);
    expect(b.shop.adjusts.where((a) => a.why.contains('স্টক কম')).length, 1);
    expectAdds(b);
  });

  test('৪. বিক্রি: মোট − ছাড় = মেমো = পাওয়া + বাকি; % ছাড় পুরো টাকায়', () async {
    final (_, b) = await shopRig();
    final rice = prod(b, 'মিনিকেট চাল'), oil = prod(b, 'সয়াবিন তেল ৫ লি.');
    final karim = cust(b, 'করিম মিয়া');
    final s = await sell(b, [(rice, 5), (oil, 1)], pay: SalePay.credit, c: karim, paid: 1000, pct: 5); // 350 + 850 = 1200, 5% = 60
    expect(s.subtotal, 1200);
    expect(s.discount, 60);
    expect(s.total, 1140);
    expect(s.paidNow + s.due, s.total);
    expect(s.paidNow, 1000);
    expect(s.due, 140);
    expect(s.netLines.fold<int>(0, (a, x) => a + x), s.total, reason: 'the discount spread over the lines adds back to the memo');
    expectAdds(b);
  });

  test('৫–৬. গ্রাহকের বকেয়া: শুরু + বাকি − আদায় = এখন; সবার যোগফল = বাজারে বকেয়া', () async {
    final (_, b) = await shopRig();
    final karim = cust(b, 'করিম মিয়া');
    final rice = prod(b, 'মিনিকেট চাল');
    await sell(b, [(rice, 10)], pay: SalePay.credit, c: karim); // +700
    await b.customerPaid(karim.id, 2000);
    final jasim = await b.saveCustomer(Customer(name: 'জসিম স্টোর'));
    await sell(b, [(rice, 4)], pay: SalePay.credit, c: jasim, paid: 80); // +200
    expect(customerAccount(b.shop, cust(b, 'করিম মিয়া')).due, 9200 + 700 - 2000);
    expect(customerAccount(b.shop, cust(b, 'জসিম স্টোর')).due, 200);
    expect(b.bizAcc.now.dues, 7900 + 200);
    expectAdds(b);
  });

  test('৭. ডিলারের দেনা: শুরু + বাকিতে কেনা − শোধ = এখন', () async {
    final (_, b) = await shopRig();
    final akij = dealer(b, 'আকিজ');
    await b.recordPurchase(akij.id, [(prod(b, 'সয়াবিন তেল ৫ লি.'), 48, 39360)], paid: 20000);
    await b.dealerPaid(akij.id, 10000);
    expect(dealerAccount(b.shop, dealer(b, 'আকিজ')).due, 24000 + 19360 - 10000);
    expect(b.bizAcc.now.payable, 33360);
    expectAdds(b);
  });

  test('৮. ঋণ: নেওয়া − আসল শোধ = এখন; সুদ খরচে যায়', () async {
    final (_, b) = await shopRig();
    final bank = b.shop.loans.single;
    await b.repayLoan(bank.id, 5000, interest: 500);
    await b.takeLoan(bank.id, 20000);
    final a = b.bizAcc;
    expect(loanDue(b.shop, bank), 50000 - 5000 + 20000);
    expect(a.flows.expenses, 500, reason: 'interest is a cost');
    expect(a.flows.netProfit, -500);
    expect(a.now.cash, 45000 - 5500 + 20000);
    expectAdds(b);
  });

  test('৯. লাভ = বিক্রির দাম − সেই মালের কেনা দাম − খরচ; ঋণ শোধ বা মালিকের টাকা লাভ থেকে কাটে না', () async {
    final (_, b) = await shopRig();
    await sell(b, [(prod(b, 'মিনিকেট চাল'), 10)]); // 700 − 620
    await sell(b, [(prod(b, 'সয়াবিন তেল ৫ লি.'), 2)]); // 1700 − 1640
    await b.shopCost(50, 'দোকান খরচ');
    await b.repayLoan(b.shop.loans.single.id, 5000);
    await b.ownerMoney(2000, inward: false);
    final f = b.bizAcc.flows;
    expect(f.sales, 2400);
    expect(f.cost, 620 + 1640);
    expect(f.saleProfit, 140);
    expect(f.netProfit, 90);
    expectAdds(b);
  });

  test('১০. ক্ষতি: নষ্ট মাল আর কেনা দামের কমে বিক্রি — লাভের ঘরে নয়', () async {
    final (_, b) = await shopRig();
    final oil = prod(b, 'সয়াবিন তেল ৫ লি.');
    await b.writeOff(oil.id, 1, why: 'বোতল ফাটা'); // −820
    final s = await sell(b, [(prod(b, 'সয়াবিন তেল ৫ লি.'), 1)], discount: 100); // 750 for 820: −70
    expect(s.total, 750);
    final f = b.bizAcc.flows;
    expect(f.damaged, 820);
    expect(f.lossOnSales, 70);
    expect(f.loss, 890);
    expect(f.saleProfit, 0, reason: 'the loss is shown as ক্ষতি, not taken off profit twice');
    expectAdds(b);
  });

  test('১১. মুছলে বা বদলালে সব আগের মতো (বিক্রি, ক্রয়, আদায়, পণ্যের তথ্য)', () async {
    final (_, b) = await shopRig();
    final before = b.bizAcc.now;
    final s = await sell(b, [(prod(b, 'মিনিকেট চাল'), 10)], pay: SalePay.credit, c: cust(b, 'করিম মিয়া'), paid: 300);
    final p = await b.recordPurchase(dealer(b, 'আকিজ').id, [(prod(b, 'সয়াবিন তেল ৫ লি.'), 10, 8300)], paid: 3000);
    await b.customerPaid(cust(b, 'করিম মিয়া').id, 1000);
    final paidId = b.shop.collections.last.id;
    await b.deleteSale(s.id);
    await b.undoShopEntry(p.id);
    await b.undoShopEntry(paidId);
    final now = b.bizAcc.now;
    expect(now.cash, before.cash);
    expect(now.stock, before.stock);
    expect(now.dues, before.dues);
    expect(now.payable, before.payable);
    expect(b.shop.adjusts, isEmpty, reason: 'undoing entries made after the start needs no correction');
    // A product's amount corrected by hand, an old due written in, an entry
    // from before the start deleted: each is kept as a correction.
    final rice = prod(b, 'মিনিকেট চাল');
    await b.saveProduct(rice.copyWith(stock: 100));
    await b.customerOwes(cust(b, 'করিম মিয়া').id, 500);
    final first = b.data.cash.firstWhere((e) => isBizCash(e));
    await b.deleteCash(first.id);
    expect(b.shop.adjusts.length, 3);
    expectAdds(b);
    // The cash entry back from the bin: the account adds up again.
    await b.restoreTrash(b.data.trash.last);
    expectAdds(b);
  });

  test('১২. রিপোর্ট: দিনের যোগফল মিলে মাসের যোগফল; মাসের যোগফল মিলে পুরো হিসাব', () async {
    final (rig, b) = await shopRig();
    for (var d = 0; d < 5; d++) {
      await sell(b, [(prod(b, 'মিনিকেট চাল'), 2)]);
      await b.shopCost(100, 'দোকান খরচ');
      rig.nowAt = rig.nowAt.add(const Duration(days: 1));
    }
    final start = DateTime(2026, 10, 9);
    var sales = 0, profit = 0;
    for (var d = 0; d < 5; d++) {
      final f = bizFlowsBetween(b.shop, b.data.cash, start.add(Duration(days: d)), start.add(Duration(days: d)));
      sales += f.sales;
      profit += f.netProfit;
    }
    final month = bizMonth(b.shop, b.data.cash, start);
    expect(sales, month.sales);
    expect(profit, month.netProfit);
    expect(month.sales, b.bizAcc.flows.sales);
    expect(salesByDay(b.shop, rig.nowAt, days: 7).fold<int>(0, (s, x) => s + x.$2), month.sales, reason: 'the chart shows the same sales');
  });

  test('১৩. গ্রাহকের ফেরত: বকেয়া বা ক্যাশ ঠিক ততটা কমে; ভালো মাল স্টকে, নষ্ট মাল ক্ষতিতে', () async {
    final (_, b) = await shopRig();
    final karim = cust(b, 'করিম মিয়া');
    final s = await sell(b, [(prod(b, 'মিনিকেট চাল'), 5), (prod(b, 'সয়াবিন তেল ৫ লি.'), 1)], pay: SalePay.credit, c: karim, paid: 1000, pct: 5);
    final dueBefore = customerAccount(b.shop, cust(b, 'করিম মিয়া')).due;
    final stockBefore = prod(b, 'সয়াবিন তেল ৫ লি.').stock;
    final r = await b.recordCustomerReturn(s.id, {1: 1}); // the oil back, good
    expect(r!.refund, s.netLines[1], reason: '850 less its share of the 5% discount');
    expect(r.refund, inInclusiveRange(807, 808));
    expect(customerAccount(b.shop, cust(b, 'করিম মিয়া')).due, dueBefore - r.refund);
    expect(prod(b, 'সয়াবিন তেল ৫ লি.').stock, stockBefore + 1);
    // Rice back spoilt, the money paid in cash: no stock back, a loss.
    final cashBefore = b.bizAcc.now.cash;
    final r2 = await b.recordCustomerReturn(s.id, {0: 2}, damaged: true, cash: true);
    expect(b.bizAcc.now.cash, cashBefore - r2!.refund);
    expect(b.bizAcc.flows.damaged, r2.cost);
    // Nothing more back than was sold.
    expect(await b.recordCustomerReturn(s.id, {1: 1}), isNull);
    expectAdds(b);
    await b.undoReturn(r.id);
    expectAdds(b);
  });

  test('১৪. সাপ্লায়ারকে ফেরত: মাল যত কমলো, দেনা বা ক্যাশ ঠিক ততটা — মূলধন একই', () async {
    final (_, b) = await shopRig();
    final cap = b.bizAcc.now.capital;
    final oil = prod(b, 'সয়াবিন তেল ৫ লি.');
    await b.recordSupplierReturn(dealer(b, 'আকিজ').id, [(oil.id, 3)]);
    expect(prod(b, 'সয়াবিন তেল ৫ লি.').stock, 21);
    expect(dealerAccount(b.shop, dealer(b, 'আকিজ')).due, 24000 - 2460);
    expect(b.bizAcc.now.capital, cap);
    await b.recordSupplierReturn(dealer(b, 'আকিজ').id, [(oil.id, 1)], pay: ReturnPay.cash);
    expect(b.bizAcc.now.capital, cap);
    // A replacement: the dealer's debt to us now, the goods come as a new purchase.
    await b.recordSupplierReturn(dealer(b, 'আকিজ').id, [(oil.id, 2)], pay: ReturnPay.replace);
    await b.recordPurchase(dealer(b, 'আকিজ').id, [(prod(b, 'সয়াবিন তেল ৫ লি.'), 2, 1640)], paid: 0);
    expect(dealerAccount(b.shop, dealer(b, 'আকিজ')).due, 24000 - 2460 - 1640 + 1640);
    expect(b.bizAcc.now.capital, cap);
    expectAdds(b);
  });

  test('এলোমেলো ৪০০টি লেনদেনের পরেও হিসাব মেলে', () async {
    final (rig, b) = await shopRig();
    final r = Random(23);
    final jasim = await b.saveCustomer(Customer(name: 'জসিম স্টোর'));
    for (var i = 0; i < 400; i++) {
      rig.nowAt = rig.nowAt.add(Duration(minutes: 7 + r.nextInt(300)));
      final ps = b.shop.products;
      final p = ps[r.nextInt(ps.length)];
      final c = r.nextBool() ? cust(b, 'করিম মিয়া') : jasim;
      switch (r.nextInt(14)) {
        case 0 || 1 || 2:
          final pay = SalePay.values[r.nextInt(3)];
          await sell(b, [(p, 1 + r.nextInt(6).toDouble())], pay: pay, c: pay == SalePay.credit ? c : null, paid: pay == SalePay.credit ? r.nextInt(500) : 0, pct: r.nextInt(3) == 0 ? 5 : 0);
        case 3:
          await b.recordPurchase(dealer(b, 'আকিজ').id, [(p, 5 + r.nextInt(20).toDouble(), 300 + r.nextInt(20000))], paid: r.nextInt(10000));
        case 4:
          await b.customerPaid(c.id, 1 + r.nextInt(2000));
        case 5:
          await b.dealerPaid(dealer(b, 'আকিজ').id, 1 + r.nextInt(5000));
        case 6:
          await b.shopCost(10 + r.nextInt(900), 'দোকান খরচ');
        case 7:
          await b.writeOff(p.id, 1);
        case 8:
          if (b.shop.sales.isNotEmpty) {
            final s = b.shop.sales[r.nextInt(b.shop.sales.length)];
            if (s.lines.isNotEmpty) await b.recordCustomerReturn(s.id, {0: 1}, damaged: r.nextBool(), cash: r.nextBool());
          }
        case 9:
          await b.recordSupplierReturn(dealer(b, 'আকিজ').id, [(p.id, 1)], pay: ReturnPay.values[r.nextInt(3)], credit: r.nextBool() ? null : r.nextInt(900));
        case 10:
          if (b.shop.sales.isNotEmpty) await b.deleteSale(b.shop.sales[r.nextInt(b.shop.sales.length)].id);
        case 11:
          await b.saveProduct(p.copyWith(stock: r.nextInt(80).toDouble(), buy: 50 + r.nextInt(900)));
        case 12:
          r.nextBool() ? await b.repayLoan(b.shop.loans.single.id, 1 + r.nextInt(3000), interest: r.nextInt(300)) : await b.takeLoan(b.shop.loans.single.id, 1 + r.nextInt(9000));
        default:
          await b.ownerMoney(1 + r.nextInt(5000), inward: r.nextBool());
      }
      for (final x in b.shop.products) {
        expect(x.stock, greaterThanOrEqualTo(-1e-9), reason: 'step $i: ${x.name} below nothing');
      }
      expectAdds(b, 'after step $i');
    }
  });
}
