// Owner, 6 Nov: "আমার এপের ভেতরে ব্যবসায়ী মুড চালু করা দরকার। যেখানে ব্যবসায়ীরা অন
// করলেই ব্যবসায়ী মোডে দেখাবে, অফ করলে এপের বর্তমান সাধারণ মুড চালু হবে।"
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/biz/biz_hisab.dart';
import 'package:digital_brain/screens/biz/biz_home.dart';
import 'package:digital_brain/screens/biz/biz_sales.dart';
import 'package:digital_brain/screens/biz/biz_stock.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/state/brain.dart' show BrainShop;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  testWidgets('business mode: the switch swaps the tabs, and off brings the normal app back', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    expect(find.byType(BizHome), findsNothing);
    await b.setPref('business_mode', true);
    await settle(t);
    expect(find.byType(BizHome), findsOneWidget);
    for (final l in ['বিক্রি', 'হিসাব', 'স্টক']) {
      expect(find.text(l), findsWidgets, reason: l);
    }
    await t.tap(find.text('স্টক').last);
    await settle(t);
    expect(find.byType(BizStock), findsOneWidget);
    expect(find.text('এখনো কোনো পণ্য নেই'), findsOneWidget);

    await b.setPref('business_mode', false);
    await settle(t);
    expect(find.byType(BizHome), findsNothing);
    expect(find.byType(BizStock), findsNothing);
  });

  testWidgets('sell from the cart: stock goes down, cash comes in; on credit it lands in the ledger', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.setPref('business_mode', true);
    final sugar = Product(name: 'চিনি', buy: 120, sell: 135, stock: 10, low: 3);
    final rice = Product(name: 'চাল', buy: 60, sell: 70, stock: 25, loose: true);
    await b.saveProduct(sugar);
    await b.saveProduct(rice);
    await settle(t);

    Navigator.of(t.element(find.byType(HomeShell))).push(MaterialPageRoute(builder: (_) => const SellPage()));
    await settle(t);
    await t.tap(find.byKey(Key('biz-plus-${sugar.id}')));
    await t.tap(find.byKey(Key('biz-plus-${sugar.id}')));
    await settle(t);
    await t.tap(find.byKey(Key('biz-weigh-${rice.id}')));
    await settle(t);
    await t.enterText(find.byType(TextField).last, '1.5');
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    expect(t.widget<Text>(find.byKey(const Key('biz-sell-total'))).data, contains('৩৭৫'));
    await t.tap(find.byKey(const Key('biz-sell-done')));
    await settle(t);
    expect(b.shop.sales, hasLength(1));
    expect(b.shop.products.firstWhere((p) => p.id == sugar.id).stock, 8);
    expect(b.shop.products.firstWhere((p) => p.id == rice.id).stock, 23.5);
    expect(b.data.cash.where((c) => c.category == 'বিক্রি').single.amount, 375);

    // On credit to রহিম: the ledger owes it. (Let the first toast go.)
    await t.pump(const Duration(seconds: 5));
    await settle(t);
    Navigator.of(t.element(find.byType(HomeShell))).push(MaterialPageRoute(builder: (_) => const SellPage(amountOnly: true, customer: 'রহিম')));
    await settle(t);
    await t.enterText(find.byKey(const Key('biz-sell-amount-field')), '৫০০');
    await settle(t);
    await t.tap(find.byKey(const Key('biz-sell-done')));
    await settle(t);
    expect(b.shop.sales, hasLength(2));
    expect(b.data.ledger.where((e) => e.person == 'রহিম').map((e) => e.amount), [500]);
  });

  testWidgets('product form saves; buyer page takes a payment; goods in adds stock; the day closes', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.setPref('business_mode', true);
    await settle(t);
    final nav = Navigator.of(t.element(find.byType(HomeShell)));

    nav.push(MaterialPageRoute(builder: (_) => const ProductForm()));
    await settle(t);
    await t.enterText(find.byKey(const Key('biz-product-name')), 'মসুর ডাল');
    await t.enterText(find.byKey(const Key('biz-product-buy')), '110');
    await t.enterText(find.byKey(const Key('biz-product-sell')), '125');
    await t.enterText(find.byKey(const Key('biz-product-stock')), '4');
    await t.enterText(find.byKey(const Key('biz-product-low')), '5');
    await t.ensureVisible(find.byKey(const Key('biz-product-save')));
    await t.tap(find.byKey(const Key('biz-product-save')));
    await settle(t);
    final dal = b.shop.products.single;
    expect((dal.name, dal.buy, dal.sell, dal.stock, dal.isLow), ('মসুর ডাল', 110, 125, 4.0, true));
    expect(b.shop.orders.map((o) => o.name), contains('মসুর ডাল'), reason: 'low stock joins the order list');

    await b.buyerOwes('করিম', 800);
    nav.push(MaterialPageRoute(builder: (_) => const BuyerPage(name: 'করিম')));
    await settle(t);
    expect(find.textContaining('৮০০'), findsWidgets);
    await t.tap(find.byKey(const Key('biz-buyer-paid')));
    await settle(t);
    await t.enterText(find.byType(TextField).last, '300');
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    final owes = b.data.ledger.where((e) => e.person == 'করিম').toList();
    expect(owes, hasLength(2));
    await t.tap(find.byTooltip('ফিরে যান'));
    await settle(t);

    await b.goodsIn('রহমান ট্রেডার্স', [(dal, 20, 2200)], paid: true);
    expect(b.shop.products.single.stock, 24);
    expect(b.data.cash.where((c) => c.category == 'মাল কেনা').single.amount, 2200);

    await b.setOpening(1000);
    final close = await b.closeDay(1000 - 2200 + 300);
    expect(close.diff, 0);
  });

  testWidgets('home, sales, hisab and stock render with data without overflow', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.setPref('business_mode', true);
    final p = Product(name: 'ডিম', unit: 'পিস', buy: 11, sell: 13, stock: 2, low: 10);
    await b.saveProduct(p);
    await b.recordSale(Sale(at: b.services.now(), lines: [SaleLine(productId: p.id, name: 'ডিম', qty: 1, unit: 'পিস', amount: 13, cost: 11)], pay: SalePay.cash));
    await b.buyerOwes('সালমা', 450);
    await settle(t);
    expect(find.byType(BizHome), findsOneWidget);
    for (final tab in ['বিক্রি', 'হিসাব', 'স্টক', 'হোম']) {
      await t.tap(find.text(tab).last);
      await settle(t);
      expect(t.takeException(), isNull, reason: tab);
    }
    await t.tap(find.text('হিসাব').last);
    await settle(t);
    expect(find.byType(BizHisab), findsOneWidget);
    expect(find.textContaining('সালমা'), findsWidgets);
  });
}
