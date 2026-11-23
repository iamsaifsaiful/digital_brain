// Owner, 23 Nov: ব্যবসায়ী মোড rebuilt — the first questions (old/new
// business; capital worked out, shown, confirmed, never typed), the home
// (no pictures; the main card opens the whole account, all time), টাকা জমা /
// খরচ, সব লেনদেন, রিপোর্ট, ক্যাশ বই, ঋণ, সাপ্লায়ার.
// SHOTS=1 flutter test test/ui/biz_1123_test.dart --update-goldens
// writes test/ui/shots/biz_1123/.
import 'dart:io';

import 'package:digital_brain/logic/biz_account.dart';
import 'package:digital_brain/logic/bn.dart' show taka;
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/biz/biz_account_page.dart';
import 'package:digital_brain/screens/biz/biz_home.dart';
import 'package:digital_brain/screens/biz/biz_money.dart';
import 'package:digital_brain/screens/biz/biz_sales.dart';
import 'package:digital_brain/screens/biz/biz_returns.dart';
import 'package:digital_brain/screens/biz/biz_customers.dart';
import 'package:digital_brain/screens/biz/biz_more.dart';
import 'package:digital_brain/screens/biz/biz_setup.dart';
import 'package:digital_brain/screens/biz/biz_stock.dart';
import 'package:digital_brain/logic/shop_logic.dart' show customerAccount, dealerAccount;
import 'package:digital_brain/screens/biz/biz_tx.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/state/brain.dart' show Brain, BrainShop;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> _shot(WidgetTester t, String name) async {
  if (!shots) return;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/biz_1123/$name.png'));
}

/// A shop with a few weeks behind it.
Future<void> _fill(Brain b) async {
  final now = b.services.now();
  final rice = Product(name: 'মিনিকেট চাল', unit: 'কেজি', buy: 68, sell: 75, stock: 4, low: 10, category: 'চাল-ডাল-আটা');
  final oil = Product(name: 'সয়াবিন তেল', unit: 'লিটার', buy: 165, sell: 180, stock: 40, category: 'তেল-মসলা');
  final egg = Product(name: 'ডিম', unit: 'হালি', buy: 44, sell: 52, stock: 30, low: 10, category: 'ডিম-দুধ');
  final soap = Product(name: 'লাক্স সাবান', unit: 'পিস', buy: 55, sell: 65, stock: 2, low: 5);
  await b.startBusiness(
    kind: 'old',
    cash: 38500,
    shopName: 'মায়ের দোয়া স্টোর',
    products: [rice, oil, egg, soap],
    customers: [('রহিম চাচা', '', 2400), ('সালমা আপা', '', 850)],
    dealers: [('করিম ট্রেডার্স', 6000)],
    loans: [('ব্র্যাক ব্যাংক', 15000, 2500)],
  );
  final p = {for (final x in b.shop.products) x.name: x};
  final salma = await b.customerFor('সালমা আপা');
  final rahim = await b.customerFor('রহিম চাচা');
  for (var d = 12; d >= 0; d--) {
    final at = DateTime(now.year, now.month, now.day - d, 11);
    await b.recordSale(Sale(at: at, lines: [SaleLine(productId: p['সয়াবিন তেল']!.id, name: 'সয়াবিন তেল', qty: 1 + d % 3, unit: 'লিটার', amount: 180 * (1 + d % 3), cost: 165 * (1 + d % 3))], pay: SalePay.cash));
  }
  await b.recordSale(Sale(at: now.subtract(const Duration(hours: 2)), lines: [SaleLine(productId: p['ডিম']!.id, name: 'ডিম', qty: 3, unit: 'হালি', amount: 156, cost: 132)], pay: SalePay.credit, customerId: salma.id));
  await b.recordSale(Sale(at: now.subtract(const Duration(hours: 1)), lines: [SaleLine(productId: p['মিনিকেট চাল']!.id, name: 'মিনিকেট চাল', qty: 2, unit: 'কেজি', amount: 150, cost: 136)], pay: SalePay.cash));
  await b.customerPaid(rahim.id, 1000);
  final d = await b.dealerFor('করিম ট্রেডার্স');
  await b.recordPurchase(d.id, [(p['সয়াবিন তেল']!, 10, 1650)], paid: 1000);
  await b.shopCost(300, 'বিদ্যুৎ বিল');
  await b.writeOff(p['ডিম']!.id, 1, why: 'ভেঙে গেছে');
}

void main() {
  setUp(() async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
  });

  testWidgets('first time: old business — cash, stock, dues; capital shown and confirmed', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.setProForTest(true);
    expect(b.shop.start, isNull);
    await b.setPref('business_mode', true);
    await settle(t);
    expect(find.byType(BizSetupPage), findsOneWidget, reason: 'asked the first time');
    await _shot(t, '01-setup-kind');
    await t.tap(find.byKey(const Key('setup-kind-old')));
    await settle(t);
    await t.tap(find.byKey(const Key('setup-next')));
    await settle(t);
    await t.enterText(find.byKey(const Key('setup-shop')), 'মায়ের দোয়া স্টোর');
    await t.enterText(find.byKey(const Key('setup-cash')), '12000');
    await settle(t);
    await _shot(t, '02-setup-cash');
    await t.tap(find.byKey(const Key('setup-next')));
    await settle(t);
    await t.enterText(find.byKey(const Key('setup-p-name')), 'মসুর ডাল');
    await t.enterText(find.byKey(const Key('setup-p-qty')), '20');
    await t.enterText(find.byKey(const Key('setup-p-buy')), '110');
    await t.enterText(find.byKey(const Key('setup-p-sell')), '125');
    await t.ensureVisible(find.byKey(const Key('setup-p-add')));
    await t.tap(find.byKey(const Key('setup-p-add')));
    await settle(t);
    await _shot(t, '03-setup-stock');
    await t.tap(find.byKey(const Key('setup-next')));
    await settle(t);
    await t.tap(find.byKey(const Key('setup-add-customer')));
    await settle(t);
    await t.enterText(find.byKey(const Key('setup-party-name')), 'রহিম চাচা');
    await t.enterText(find.byKey(const Key('setup-party-amount')), '1500');
    await t.tap(find.byKey(const Key('setup-party-save')));
    await settle(t);
    // 12000 + 20×110 + 1500 = 15700, worked out — not typed.
    expect(t.widget<Text>(find.byKey(const Key('setup-capital-amount'))).data, '৳১৫,৭০০');
    await t.ensureVisible(find.byKey(const Key('setup-confirm')));
    await settle(t);
    await _shot(t, '04-setup-capital');
    await t.tap(find.byKey(const Key('setup-confirm')));
    await settle(t);
    await t.tap(find.byKey(const Key('setup-done')));
    await settle(t);
    expect(find.byType(BizSetupPage), findsNothing);
    expect(b.shop.start?.sums.capital, 15700);
    expect(b.bizAcc.adds, isTrue);
    expect(find.byType(BizHome), findsOneWidget);
    debugDisableShadows = true;
  });

  testWidgets('home: main card opens the whole account; money in and out; every page renders', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 23, 18, 30);
    final b = rig.brain;
    await b.setProForTest(true);
    await _fill(b);
    expect(b.bizAcc.adds, isTrue);
    // The cash written in at the start is not today's income.
    final today = bizToday(b.shop, b.data.cash, rig.nowAt);
    expect(today.otherIncome, 0);
    expect(today.netProfit, lessThan(1000));
    await b.setPref('business_mode', true);
    await settle(t);
    expect(find.byType(BizSetupPage), findsNothing);
    expect(find.byType(BizHome), findsOneWidget);
    await _shot(t, '05-home');
    // The four buttons sit just below the middle of the screen.
    final y = t.getCenter(find.byKey(const Key('biz-quick-sell'))).dy;
    final h = t.view.physicalSize.height / t.view.devicePixelRatio;
    expect(y, greaterThan(h * .45));
    expect(y, lessThan(h * .72));

    if (shots) {
      t.view.physicalSize = const Size(1170, 6600);
      await settle(t);
      await _shot(t, '06-home-full');
      t.view.physicalSize = const Size(1170, 2532);
      await settle(t);
    }

    await t.tap(find.byKey(const Key('biz-home-today')));
    await settle(t);
    expect(find.byType(BizAccountPage), findsOneWidget);
    expect(find.byKey(const Key('biz-acc-ok')), findsOneWidget);
    final acc = b.bizAcc;
    expect(t.widget<Text>(find.byKey(const Key('biz-acc-capital'))).data, taka(acc.now.capital));
    await _shot(t, '07-account');
    if (shots) {
      t.view.physicalSize = const Size(1170, 7800);
      await settle(t);
      await _shot(t, '08-account-full');
      t.view.physicalSize = const Size(1170, 2532);
      await settle(t);
    }
    Navigator.of(t.element(find.byType(BizAccountPage))).pop();
    await settle(t);

    // টাকা জমা → মালিকের জমা.
    final cash0 = b.bizAcc.now.cash;
    await t.ensureVisible(find.byKey(const Key('biz-quick-in')));
    await t.tap(find.byKey(const Key('biz-quick-in')));
    await settle(t);
    await _shot(t, '09-money-in');
    await t.tap(find.byKey(const Key('biz-pick-owner')));
    await settle(t);
    await t.enterText(find.byType(TextField).last, '5000');
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    expect(b.bizAcc.now.cash, cash0 + 5000);
    expect(b.bizAcc.flows.ownerIn, 5000);

    // খরচ → the sheet.
    await t.tap(find.byKey(const Key('biz-quick-cost')));
    await settle(t);
    await _shot(t, '10-money-out');
    await t.tap(find.byKey(const Key('biz-pick-loan')));
    await settle(t);
    final brac = b.shop.loans.single;
    await t.tap(find.byKey(Key('biz-pick-loan-${brac.id}')));
    await settle(t);
    await t.tap(find.text('রাখুন').last); // the instalment offered
    await settle(t);
    await t.enterText(find.byType(TextField).last, '600');
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    expect(loanDue(b.shop, brac), 15000 - 2500);
    expect(b.bizAcc.flows.expenses, 300 + 600, reason: 'interest is a cost');
    expect(b.bizAcc.adds, isTrue);

    final nav = Navigator.of(t.element(find.byType(HomeShell)));
    for (final (name, w) in <(String, Widget)>[
      ('11-all-tx', const BizTxPage()),
      ('12-report', const BizReportPage()),
      ('13-cash-book', const BizCashBook()),
      ('14-loans', const LoanListPage()),
      ('15-loan', LoanPage(id: brac.id)),
      ('16-suppliers', const SupplierListPage()),
    ]) {
      nav.push(MaterialPageRoute(builder: (_) => w));
      await settle(t);
      expect(t.takeException(), isNull, reason: name);
      await _shot(t, name);
      nav.pop();
      await settle(t);
    }

    // Cancelling an entry from সব লেনদেন: the account still adds up.
    nav.push(MaterialPageRoute(builder: (_) => const BizTxPage()));
    await settle(t);
    final last = bizTransactions(b.shop, b.data.cash).first;
    await t.tap(find.byKey(Key('biz-tx-${last.id}')));
    await settle(t);
    await t.tap(find.byKey(const Key('biz-tx-undo')));
    await settle(t);
    await t.tap(find.text('বাতিল করুন').last);
    await settle(t);
    expect(bizTransactions(b.shop, b.data.cash).any((x) => x.id == last.id), isFalse);
    expect(b.bizAcc.adds, isTrue);
    debugDisableShadows = true;
  });

  testWidgets('stock: by section; স্টক যোগ a new product part paid; sell with + and −, discount %, part paid', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 23, 18, 30);
    final b = rig.brain;
    await b.setProForTest(true);
    await _fill(b);
    await b.setPref('business_mode', true);
    await settle(t);
    goToTab(t.element(find.byType(HomeShell)), ShellTab.store);
    await settle(t);
    expect(find.byType(BizStock), findsOneWidget);
    expect(t.widget<Text>(find.byKey(const Key('biz-stock-worth'))).data, taka(b.shop.products.fold<int>(0, (s, p) => s + p.value)));
    await _shot(t, '17-stock');

    // স্টক যোগ: a new product, 48 bottles at 820, sells at 850, 20,000 paid.
    await t.tap(find.byKey(const Key('biz-stock-in')));
    await settle(t);
    await t.enterText(find.byKey(const Key('stockin-q')), 'সয়াবিন তেল ৫ লি.');
    await settle(t);
    await _shot(t, '18-stock-in-search');
    await t.tap(find.byKey(const Key('stockin-new')));
    await settle(t);
    await t.enterText(find.byKey(const Key('stockin-qty')), '48');
    await t.enterText(find.byKey(const Key('stockin-buy')), '820');
    await t.enterText(find.byKey(const Key('stockin-sell')), '850');
    await t.enterText(find.byKey(const Key('stockin-weight')), '5');
    await settle(t);
    await t.tap(find.byKey(const Key('stockin-dealer')));
    await settle(t);
    await t.enterText(find.byKey(const Key('biz-dealer-name')), 'আকিজ ডিস্ট্রিবিউটর');
    await settle(t);
    await t.tap(find.byKey(const Key('biz-dealer-new')));
    await settle(t);
    expect(find.text('আকিজ ডিস্ট্রিবিউটর'), findsOneWidget);
    await t.drag(find.byType(Scrollable).last, const Offset(0, -600));
    await settle(t);
    await t.tap(find.text('আংশিক'));
    await settle(t);
    await t.enterText(find.byKey(const Key('stockin-paid')), '20000');
    await settle(t);
    expect(t.widget<Text>(find.byKey(const Key('stockin-total'))).data, '৳৩৯,৩৬০');
    await _shot(t, '19-stock-in-form');
    final cash0 = b.bizAcc.now.cash;
    await t.tap(find.byKey(const Key('stockin-save')));
    await settle(t);
    final oil5 = b.shop.products.firstWhere((p) => p.name == 'সয়াবিন তেল ৫ লি.');
    expect((oil5.stock, oil5.value, oil5.sell, oil5.weight), (48.0, 39360, 850, '5 কেজি'));
    final akij = b.shop.dealers.firstWhere((d) => d.name == 'আকিজ ডিস্ট্রিবিউটর');
    expect(dealerAccount(b.shop, akij).due, 19360);
    expect(b.bizAcc.now.cash, cash0 - 20000);
    expect(b.bizAcc.adds, isTrue);

    // Sell: + twice, − once, 5% off, part paid.
    final nav = Navigator.of(t.element(find.byType(HomeShell)));
    nav.push(MaterialPageRoute(builder: (_) => const SellPage()));
    await settle(t);
    await t.tap(find.byKey(const Key('biz-sell-customer')));
    await settle(t);
    final salma = b.shop.customers.firstWhere((c) => c.name == 'সালমা আপা');
    await t.tap(find.byKey(Key('biz-pick-${salma.id}')));
    await settle(t);
    await t.enterText(find.byKey(const Key('biz-sell-find')), 'সয়াবিন');
    await settle(t);
    await t.tap(find.byKey(Key('biz-plus-${oil5.id}')));
    await settle(t);
    await t.tap(find.byKey(Key('biz-inc-${oil5.id}')));
    await t.tap(find.byKey(Key('biz-inc-${oil5.id}')));
    await t.tap(find.byKey(Key('biz-dec-${oil5.id}')));
    await settle(t);
    await t.tap(find.text('%').last);
    await t.enterText(find.byKey(const Key('biz-sell-discount')), '5');
    await settle(t);
    expect(t.widget<Text>(find.byKey(const Key('biz-sell-total'))).data, '৳১,৬১৫');
    await t.drag(find.byType(Scrollable).last, const Offset(0, -600));
    await settle(t);
    await t.tap(find.text('আংশিক').last);
    await settle(t);
    await t.enterText(find.byKey(const Key('biz-sell-paid')), '1000');
    await settle(t);
    final before = customerAccount(b.shop, salma).due;
    expect(t.widget<Text>(find.byKey(const Key('biz-sell-due-after'))).data, 'মোট বকেয়া ${taka(before + 615)}');
    await _shot(t, '20-sell');
    await t.tap(find.byKey(const Key('biz-sell-done')));
    await settle(t);
    final sale = b.shop.sales.last;
    expect((sale.total, sale.paidNow, sale.due), (1615, 1000, 615));
    expect(customerAccount(b.shop, salma).due, before + 615);
    expect(b.shop.products.firstWhere((p) => p.id == oil5.id).stock, 46);
    expect(b.bizAcc.adds, isTrue);
    await _shot(t, '21-sell-memo');
    debugDisableShadows = true;
  });

  testWidgets('customers, the business আরও, goods back from a customer and to a supplier', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 23, 18, 30);
    final b = rig.brain;
    await b.setProForTest(true);
    await _fill(b);
    await b.setPref('business_mode', true);
    await settle(t);
    final ctx = t.element(find.byType(HomeShell));
    goToTab(ctx, ShellTab.people);
    await settle(t);
    expect(find.byType(BizCustomers), findsOneWidget);
    await _shot(t, '22-customers');
    goToTab(ctx, ShellTab.more);
    await settle(t);
    expect(find.byType(BizMore), findsOneWidget);
    expect(find.text('দিনলিপি'), findsNothing);
    expect(find.byKey(const Key('more-business')), findsOneWidget, reason: 'the way back is near the top');
    await _shot(t, '23-more');
    if (shots) {
      t.view.physicalSize = const Size(1170, 3600);
      await settle(t);
      await _shot(t, '24-more-full');
      t.view.physicalSize = const Size(1170, 2532);
      await settle(t);
    }

    // A customer brings back 1 of 3 eggs (good): off their due, back on the shelf.
    final nav = Navigator.of(ctx);
    final eggSale = b.shop.sales.firstWhere((x) => x.lines.isNotEmpty && x.lines.first.name == 'ডিম');
    final salma = b.shop.customers.firstWhere((c) => c.name == 'সালমা আপা');
    final due0 = customerAccount(b.shop, salma).due;
    final egg0 = b.shop.products.firstWhere((p) => p.name == 'ডিম').stock;
    nav.push(MaterialPageRoute(builder: (_) => ReturnsPage(saleId: eggSale.id)));
    await settle(t);
    await t.tap(find.byKey(const Key('ret-line-0')));
    await settle(t);
    expect(t.widget<Text>(find.byKey(const Key('ret-refund'))).data, '৳৫২');
    await _shot(t, '25-return-customer');
    await t.tap(find.byKey(const Key('ret-save')));
    await settle(t);
    expect(customerAccount(b.shop, salma).due, due0 - 52);
    expect(b.shop.products.firstWhere((p) => p.name == 'ডিম').stock, egg0 + 1);
    expect(b.bizAcc.adds, isTrue);

    // 3 litres of oil back to the supplier: off what is owed them.
    final karim = b.shop.dealers.firstWhere((d) => d.name == 'করিম ট্রেডার্স');
    final owe0 = dealerAccount(b.shop, karim).due;
    final oil = b.shop.products.firstWhere((p) => p.name == 'সয়াবিন তেল');
    nav.push(MaterialPageRoute(builder: (_) => ReturnsPage(supplier: true, dealerId: karim.id)));
    await settle(t);
    await t.tap(find.byKey(const Key('ret-add-product')));
    await settle(t);
    await t.tap(find.byKey(Key('ret-p-${oil.id}')));
    await settle(t);
    await t.tap(find.byKey(Key('ret-sq-${oil.id}-inc')));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(Key('ret-sq-${oil.id}-inc')));
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.byKey(const Key('ret-reason-মেয়াদ শেষ')));
    await settle(t);
    final worth = b.shop.products.firstWhere((p) => p.id == oil.id).costOf(3);
    await t.pump(const Duration(seconds: 5)); // the last toast gone
    await settle(t);
    await _shot(t, '26-return-supplier');
    await t.tap(find.byKey(const Key('ret-send')));
    await settle(t);
    expect(dealerAccount(b.shop, karim).due, owe0 - worth);
    expect(b.bizAcc.adds, isTrue);
    expect(b.bizAcc.flows.supplierReturnGain, 0, reason: 'at cost: the capital does not move');
    debugDisableShadows = true;
  });
}
