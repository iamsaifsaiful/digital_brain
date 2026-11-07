// 7 Nov: "ব্যবসায়ী মোডের আয় ব্যয় সাধারণ মোডের আয় ব্যয় আলাদা হবে". The
// business's money never shows in the personal আয়-ব্যয় (nor its sums),
// and older entries the shop wrote there move over once.
import 'package:digital_brain/logic/cash.dart';
import 'package:digital_brain/logic/shop_logic.dart';
import 'package:digital_brain/logic/zakat.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/brain.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;

void main() {
  testWidgets('sales, collections, purchases and shop costs stay out of the personal sums', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.setProForTest(true);
    final now = b.services.now();
    await b.saveCash(CashEntry(kind: CashKind.expense, amount: 300, category: 'বাজার', date: now));
    final p = Product(name: 'ডিম', unit: 'হালি', buy: 46, sell: 52, stock: 30);
    await b.saveProduct(p);
    await b.recordSale(Sale(at: now, lines: [SaleLine(productId: p.id, name: 'ডিম', qty: 2, unit: 'হালি', amount: 104, cost: 92)]));
    final c = await b.saveCustomer(Customer(name: 'রহিম'));
    await b.customerOwes(c.id, 500);
    await b.customerPaid(c.id, 200);
    final d = await b.saveDealer(Dealer(name: 'করিম ট্রেডার্স'));
    await b.recordPurchase(d.id, [(p, 10, 460)], paid: 460);
    await b.shopCost(120, 'দোকান খরচ');

    final mine = monthSums(b.data.cash, now);
    expect((mine.income, mine.expense), (0, 300));
    final biz = bizMonthSums(b.data.cash, now);
    expect((biz.income, biz.expense), (104 + 200, 460 + 120));
    expect(todayCash(b.data, now).out, 580);
    // যাকাত: the shop's cash, marked as from the business — none while it is below zero.
    expect(bizCashBalance(b.data.cash), 304 - 580);
    expect(zakatLines(b.data, now, b.zakatSaved).where((l) => l.key == 'shop:cash'), isEmpty);
    await b.recordSale(Sale(at: now, lines: const [], amountOnly: 1000));
    final z = zakatLines(b.data, now, b.zakatSaved).where((l) => l.key == 'shop:cash').single;
    expect(z.amount, 1304 - 580);
    expect(z.label, contains('ব্যবসা থেকে'));
  });

  testWidgets('money said in ব্যবসায়ী মোড goes to the business; in the usual mode, to the personal', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.setProForTest(true);
    final chat = ChatController(b);
    await chat.hear('দোকান ভাড়া ৫০০০ টাকা দিলাম');
    if (chat.wait != ChatWait.none) await chat.hear('হ্যাঁ');
    expect(monthSums(b.data.cash, b.services.now()).expense, 5000);
    b.businessMode = true;
    await chat.hear('বিদ্যুৎ বিল ৮০০ টাকা দিলাম');
    if (chat.wait != ChatWait.none) await chat.hear('হ্যাঁ');
    expect(chat.messages.last.text, contains('ব্যবসার হিসাবে'));
    expect(monthSums(b.data.cash, b.services.now()).expense, 5000);
    expect(bizMonthSums(b.data.cash, b.services.now()).expense, 800);
  });

  testWidgets('older shop entries in the personal আয়-ব্যয় move over once', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final now = b.services.now();
    final p = Product(name: 'চাল', buy: 60, sell: 70, stock: 5);
    b.data.shop.products.add(p);
    final sold = CashEntry(kind: CashKind.income, amount: 140, category: 'বিক্রি', date: now);
    final rent = CashEntry(kind: CashKind.expense, amount: 4000, category: 'দোকান ভাড়া', date: now);
    final food = CashEntry(kind: CashKind.expense, amount: 250, category: 'বাজার', date: now);
    b.data.cash.addAll([sold, rent, food]);
    b.data.shop.sales.add(Sale(at: now, lines: const [], amountOnly: 140, cashId: sold.id));
    expect(b.moveBizCash(), isTrue);
    expect(monthSums(b.data.cash, now).income, 0);
    expect(monthSums(b.data.cash, now).expense, 250);
    expect(bizMonthSums(b.data.cash, now).income, 140);
    expect(bizMonthSums(b.data.cash, now).expense, 4000);
    expect(b.moveBizCash(), isFalse);
  });
}
