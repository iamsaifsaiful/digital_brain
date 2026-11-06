// Owner, 6 Nov: "আমার এপের ভেতরে ব্যবসায়ী মুড চালু করা দরকার। যেখানে ব্যবসায়ীরা অন
// করলেই ব্যবসায়ী মোডে দেখাবে, অফ করলে এপের বর্তমান সাধারণ মুড চালু হবে।" and the
// second round: দিন বন্ধ out; dealers instead of ধার-দেনা; discount in ৳ or %;
// customer profiles; হোম → বিক্রি → গ্রাহক → হিসাব → স্টক; বাকির রিমাইন্ডার;
// 30-day dues on home; PDF receipt with the shop's details; WhatsApp তাগাদা;
// own তাগাদা; Premium (look around free, add nothing).
import 'package:digital_brain/logic/shop_logic.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/biz/biz_customers.dart';
import 'package:digital_brain/screens/biz/biz_hisab.dart';
import 'package:digital_brain/screens/biz/biz_home.dart';
import 'package:digital_brain/screens/biz/biz_sales.dart';
import 'package:digital_brain/screens/biz/biz_shop.dart';
import 'package:digital_brain/screens/biz/biz_stock.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/services/launcher.dart';
import 'package:digital_brain/state/brain.dart' show BrainShop;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  testWidgets('the switch: six tabs in the day\'s order; off brings the normal app back on the same tab', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.setProForTest(true);
    expect(find.byType(BizHome), findsNothing);
    await b.setPref('business_mode', true);
    await settle(t);
    expect(find.byType(BizHome), findsOneWidget);
    // হোম · বিক্রি · গ্রাহক · হিসাব · স্টক · আরও, left to right.
    final xs = [for (final l in ['হোম', 'বিক্রি', 'গ্রাহক', 'হিসাব', 'স্টক', 'আরও']) t.getCenter(find.text(l).last).dx];
    expect([...xs]..sort(), xs);
    await t.tap(find.text('গ্রাহক').last);
    await settle(t);
    expect(find.byType(BizCustomers), findsOneWidget);
    await t.tap(find.text('স্টক').last);
    await settle(t);
    expect(find.byType(BizStock), findsOneWidget);
    await t.tap(find.text('হিসাব').last);
    await settle(t);
    expect(find.text('দিন বন্ধ'), findsNothing, reason: 'owner, 6 Nov: দিন বন্ধ বাদ');
    expect(find.text('ডিলার ও মাল কেনা'), findsOneWidget);

    // Switched off from আরও: still on আরও, the normal tabs back.
    await t.tap(find.text('আরও').last);
    await settle(t);
    await t.tap(find.byKey(const Key('more-business')));
    await settle(t);
    expect(find.byType(BizHome), findsNothing);
    expect(find.byKey(const Key('more-business')), findsOneWidget);
    expect(find.text('দিনলিপি'), findsWidgets);
  });

  testWidgets('a sale: discount in percent works out live; on credit needs a customer and lands on their account', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.setProForTest(true);
    await b.setPref('business_mode', true);
    final sugar = Product(name: 'চিনি', buy: 120, sell: 130, stock: 10, low: 3);
    final rice = Product(name: 'চাল', buy: 60, sell: 70, stock: 25, loose: true);
    await b.saveProduct(sugar);
    await b.saveProduct(rice);
    await settle(t);
    final nav = Navigator.of(t.element(find.byType(HomeShell)));

    nav.push(MaterialPageRoute(builder: (_) => const SellPage()));
    await settle(t);
    await t.tap(find.byKey(Key('biz-plus-${sugar.id}')));
    await t.tap(find.byKey(Key('biz-plus-${sugar.id}')));
    await settle(t);
    await t.tap(find.byKey(Key('biz-weigh-${rice.id}')));
    await settle(t);
    await t.enterText(find.byType(TextField).last, '1.5');
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    // Step two (owner, 7 Nov): the checkout.
    expect(t.widget<Text>(find.byKey(const Key('biz-sell-subtotal'))).data, '৳৩৬৫');
    await t.tap(find.byKey(const Key('biz-sell-next')));
    await settle(t);
    String total() => t.widget<Text>(find.byKey(const Key('biz-sell-total'))).data!;
    expect(total(), '৳৩৬৫');
    // ১০% off: ৳৩৭ (365 × 10% rounded), the total follows as it is typed.
    await t.tap(find.text('%').last);
    await t.enterText(find.byKey(const Key('biz-sell-discount')), '১০');
    await settle(t);
    expect(t.widget<Text>(find.byKey(const Key('biz-sell-off'))).data, '− ৳৩৭');
    expect(total(), '৳৩২৮');
    // The same box in taka.
    await t.tap(find.text('৳').last);
    await settle(t);
    expect(total(), '৳৩৫৫');
    await t.tap(find.text('%').last);
    await settle(t);
    await t.tap(find.byKey(const Key('biz-sell-done')));
    await settle(t);
    final s = b.shop.sales.single;
    expect((s.subtotal, s.discount, s.discountPct, s.total), (365, 37, 10.0, 328));
    expect(b.shop.products.firstWhere((p) => p.id == sugar.id).stock, 8);
    expect(b.data.cash.single.amount, 328);

    // On credit with no customer: the picker opens; a new name is a new customer.
    await t.pump(const Duration(seconds: 5));
    await settle(t);
    nav.push(MaterialPageRoute(builder: (_) => const SellPage(amountOnly: true)));
    await settle(t);
    await t.enterText(find.byKey(const Key('biz-sell-amount-field')), '৫০০');
    await t.tap(find.text('বাকিতে').last);
    await settle(t);
    await t.tap(find.byKey(const Key('biz-sell-done')));
    await settle(t);
    await t.enterText(find.byKey(const Key('biz-customer-name')), 'রহিম মিয়া');
    await settle(t);
    await t.tap(find.byKey(const Key('biz-customer-new')));
    await settle(t);
    // Picked, the sale goes through at once.
    final c = b.shop.customers.single;
    expect(c.name, 'রহিম মিয়া');
    expect(customerAccount(b.shop, c).due, 500);
    expect(b.data.ledger, isEmpty);
  });

  testWidgets('customer profile: details, paid, reminder, WhatsApp তাগাদা in the shop\'s own words', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.setProForTest(true);
    await b.setPref('business_mode', true);
    await settle(t);
    final nav = Navigator.of(t.element(find.byType(HomeShell)));

    nav.push(MaterialPageRoute(builder: (_) => const CustomerForm()));
    await settle(t);
    await t.enterText(find.byKey(const Key('biz-cf-name')), 'সালমা বেগম');
    await t.enterText(find.byKey(const Key('biz-cf-phone')), '০১৭১১০০০০০০');
    await t.tap(find.byKey(const Key('biz-cf-same-wa')));
    await settle(t);
    await t.enterText(find.byKey(const Key('biz-cf-wa')), '01822000000');
    await t.enterText(find.byKey(const Key('biz-cf-address')), 'বাজার রোড');
    await t.enterText(find.byKey(const Key('biz-cf-opening')), '1200');
    await t.tap(find.byKey(const Key('biz-cf-save')));
    await settle(t);
    final c = b.shop.customers.single;
    expect((c.phone, c.whatsapp, c.address), ('01711000000', '01822000000', 'বাজার রোড'));
    expect(find.byType(CustomerPage), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('biz-customer-due'))).data, '৳১,২০০');
    expect(find.text('বাজার রোড'), findsWidgets);

    // The তাগাদা, written by the shop, goes to the WhatsApp number.
    await b.saveShopProfile(const ShopProfile(name: 'মা স্টোর', tagada: '[নাম], [দোকান]-এ বাকি [বাকি]।'));
    await settle(t);
    expect(t.widget<Text>(find.byKey(const Key('biz-tagada-text'))).data, 'সালমা বেগম, মা স্টোর-এ বাকি ৳১,২০০।');
    await t.ensureVisible(find.byKey(const Key('biz-tagada-wa')));
    await t.tap(find.byKey(const Key('biz-tagada-wa')));
    await settle(t);
    expect((rig.services.launcher as FakeLauncher).opened.last.toString(), contains('8801822000000'));

    // A reminder to collect, through the app's own reminders.
    await t.ensureVisible(find.byKey(const Key('biz-reminder-set')));
    await t.tap(find.byKey(const Key('biz-reminder-set')));
    await settle(t);
    await t.tap(find.byKey(const Key('biz-reminder-save')));
    await settle(t);
    expect(b.data.reminders.single.title, 'সালমা বেগম-এর কাছে বাকি আদায়');
    expect(find.byKey(const Key('biz-reminder-on')), findsOneWidget);

    // Paid in full: the due is gone, so is the reminder.
    await t.scrollUntilVisible(find.byKey(const Key('biz-customer-paid')), -200, scrollable: find.descendant(of: find.byType(CustomerPage), matching: find.byType(Scrollable)).first);
    await t.tap(find.byKey(const Key('biz-customer-paid')));
    await settle(t);
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    expect(customerAccount(b.shop, c).due, 0);
    expect(b.data.reminders, isEmpty);
  });

  testWidgets('dealers: buy part paid, pay the rest; home shows dues older than 30 days', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.setProForTest(true);
    await b.setPref('business_mode', true);
    final dal = Product(name: 'মসুর ডাল', buy: 110, sell: 125, stock: 3, low: 5, supplier: 'করিম ট্রেডার্স');
    await b.saveProduct(dal);
    final d = await b.dealerFor('করিম ট্রেডার্স');
    await settle(t);
    final nav = Navigator.of(t.element(find.byType(HomeShell)));

    nav.push(MaterialPageRoute(builder: (_) => PurchasePage(part: 'in', dealerId: d.id)));
    await settle(t);
    await t.tap(find.byKey(const Key('biz-in-from-order')));
    await settle(t);
    await t.enterText(find.byKey(const Key('biz-in-amount-0')), '1320');
    await t.tap(find.text('কিছু দিয়েছি'));
    await settle(t);
    await t.enterText(find.byKey(const Key('biz-in-paid-now')), '500');
    await settle(t);
    await t.tap(find.byKey(const Key('biz-in-save')));
    await settle(t);
    expect(dealerAccount(b.shop, d).due, 820);
    expect(b.shop.products.single.stock, 15);

    nav.push(MaterialPageRoute(builder: (_) => DealerPage(id: d.id)));
    await settle(t);
    expect(t.widget<Text>(find.byKey(const Key('biz-dealer-due'))).data, '৳৮২০');
    await t.tap(find.byKey(const Key('biz-dealer-pay')));
    await settle(t);
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    expect(dealerAccount(b.shop, d).due, 0);
    nav.popUntil((r) => r.isFirst);
    await settle(t);

    // A due from 40 days back shows on home.
    final c = await b.customerFor('পুরোনো গ্রাহক');
    await b.recordSale(Sale(at: rig.nowAt.subtract(const Duration(days: 40)), lines: const [], amountOnly: 700, pay: SalePay.credit, customerId: c.id));
    await settle(t);
    expect(find.byKey(const Key('biz-home-long')), findsOneWidget);
    expect(find.text('পুরোনো গ্রাহক'), findsWidgets);
  });

  testWidgets('free app: everything opens, nothing is added; the Premium sheet says why', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    b.gated = true;
    await b.setProForTest(false);
    await b.setPref('business_mode', true);
    final egg = Product(name: 'ডিম', unit: 'হালি', sell: 52, stock: 30);
    b.shop.products.add(egg);
    await settle(t);
    expect(find.byKey(const Key('biz-free-banner')), findsOneWidget);
    final nav = Navigator.of(t.element(find.byType(HomeShell)));
    nav.push(MaterialPageRoute(builder: (_) => const SellPage()));
    await settle(t);
    await t.tap(find.byKey(Key('biz-plus-${egg.id}')));
    await settle(t);
    await t.tap(find.byKey(const Key('biz-sell-next')));
    await settle(t);
    await t.tap(find.byKey(const Key('biz-sell-done')));
    await settle(t);
    expect(find.textContaining('প্রিমিয়াম সুবিধা'), findsOneWidget);
    expect(b.shop.sales, isEmpty);
  });

  testWidgets('every page renders with data, no overflow', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.setProForTest(true);
    await b.setPref('business_mode', true);
    final p = Product(name: 'ডিম', unit: 'পিস', buy: 11, sell: 13, stock: 2, low: 10);
    await b.saveProduct(p);
    final c = await b.customerFor('সালমা');
    await b.recordSale(Sale(at: b.services.now(), lines: [SaleLine(productId: p.id, name: 'ডিম', qty: 1, unit: 'পিস', amount: 13, cost: 11)], pay: SalePay.credit, customerId: c.id));
    final d = await b.dealerFor('করিম');
    await b.recordPurchase(d.id, [(p, 10, 110)], paid: 0);
    await settle(t);
    for (final tab in ['বিক্রি', 'গ্রাহক', 'হিসাব', 'স্টক', 'হোম']) {
      await t.tap(find.text(tab).last);
      await settle(t);
      expect(t.takeException(), isNull, reason: tab);
    }
    final nav = Navigator.of(t.element(find.byType(HomeShell)));
    for (final w in <Widget>[CustomerPage(id: c.id), DealerPage(id: d.id), const ShopProfilePage(), const TagadaPage(), const DealerForm(), CustomerForm(customer: c)]) {
      nav.push(MaterialPageRoute(builder: (_) => w));
      await settle(t);
      expect(t.takeException(), isNull, reason: '${w.runtimeType}');
      nav.pop();
      await settle(t);
    }
  });
}
