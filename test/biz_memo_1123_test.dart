// Owner, 23 Nov: "প্রতিটি লেনদেনের সুন্দর PDF মেমো — আগের বকেয়া এবং তার মেমো
// নাম্বার, আপডেট মোট বকেয়া". The previous due is what was owed when the
// memo was made (later payments do not change an old memo), from which
// memos (payments clear the oldest first).
import 'package:digital_brain/logic/biz_account.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/brain.dart' show BrainShop;
import 'package:flutter_test/flutter_test.dart';

import 'biz_account_1123_test.dart' show shopRig, cust, prod;

void main() {
  test('previous due at the memo: the start due, then memos, oldest cleared first', () async {
    final (rig, b) = await shopRig();
    final karim = cust(b, 'করিম মিয়া'); // owed 9,200 at the start
    final rice = prod(b, 'মিনিকেট চাল');
    Future<Sale> sell(int kg, {int paid = 0}) async {
      rig.nowAt = rig.nowAt.add(const Duration(hours: 1));
      return b.recordSale(Sale(at: rig.nowAt, lines: [SaleLine(productId: rice.id, name: rice.name, qty: kg.toDouble(), unit: 'কেজি', amount: 70 * kg)], pay: SalePay.credit, paid: paid, customerId: karim.id));
    }

    final s1 = await sell(10); // 700 due
    var d = memoDue(b.shop, s1);
    expect((d.before, d.opening, d.now, d.after), (9200, true, 700, 9900));
    expect(d.memos, isEmpty);

    rig.nowAt = rig.nowAt.add(const Duration(hours: 1));
    await b.customerPaid(karim.id, 9500); // clears the start due and 300 of #s1
    final s2 = await sell(20, paid: 400); // 1,400, 400 paid → 1,000 due
    d = memoDue(b.shop, s2);
    expect((d.before, d.opening, d.now, d.after), (400, false, 1000, 1400));
    expect(d.memos, [s1.no]);

    // A later payment does not change what the old memo said.
    rig.nowAt = rig.nowAt.add(const Duration(hours: 1));
    await b.customerPaid(karim.id, 1400);
    expect(memoDue(b.shop, s2).before, 400);

    // A cash sale with no customer: no due part.
    final cash = await b.recordSale(Sale(at: rig.nowAt.add(const Duration(hours: 1)), lines: [SaleLine(productId: rice.id, name: rice.name, qty: 1, unit: 'কেজি', amount: 70)], pay: SalePay.cash));
    expect(memoDue(b.shop, cash).after, 0);
  });

  test('the memo PDF: shop, goods with rate, paid, and the due box with memo numbers', () async {
    final (rig, b) = await shopRig();
    final karim = cust(b, 'করিম মিয়া');
    final rice = prod(b, 'মিনিকেট চাল');
    rig.nowAt = rig.nowAt.add(const Duration(hours: 1));
    final s1 = await b.recordSale(Sale(at: rig.nowAt, lines: [SaleLine(productId: rice.id, name: rice.name, qty: 5, unit: 'কেজি', amount: 350)], pay: SalePay.credit, customerId: karim.id));
    rig.nowAt = rig.nowAt.add(const Duration(hours: 1));
    final s2 = await b.recordSale(Sale(at: rig.nowAt, lines: [SaleLine(productId: rice.id, name: rice.name, qty: 10, unit: 'কেজি', amount: 700)], discount: 35, discountPct: 5, pay: SalePay.credit, paid: 300, customerId: karim.id));
    final spec = memoSpec(s2, b.shop.profile, memoDue(b.shop, s2), taka: (n) => '৳$n', digits: (x) => x, customer: karim);
    expect(spec['title'], 'রহমান জেনারেল স্টোর');
    final blocks = spec['blocks']! as List;
    final goods = blocks.firstWhere((x) => (x as Map)['t'] == 'table' && (x['cols'] as List).length == 5) as Map;
    expect((goods['rows'] as List).first, ['1', 'মিনিকেট চাল', '10 কেজি', '70', '৳700']);
    final dues = blocks.lastWhere((x) => (x as Map)['t'] == 'table') as Map;
    final rows = dues['rows'] as List;
    expect((rows[0] as List)[0], 'আগের বকেয়া (শুরুর বকেয়া + মেমো #${s1.no})');
    expect((rows[0] as List)[1], '৳9550');
    expect((rows[1] as List)[1], '৳365');
    expect(((rows[2] as List)[1] as Map)['s'], '৳9915');
  });
}
