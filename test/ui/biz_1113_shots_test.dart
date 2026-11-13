// Owner, 13 Nov: "ব্যবসায়ী এর কয়েকটি ইউআই ফিক্স কর". SHOTS=1
// STAGE=before|after --update-goldens writes test/ui/shots/biz/.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/biz/biz_customers.dart';
import 'package:digital_brain/screens/biz/biz_sales.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';
final stage = Platform.environment['STAGE'] ?? 'after';

void main() {
  testWidgets('business pages', (t) async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
    final rig = await start(t);
    t.view.physicalSize = const Size(1170, 3000);
    final b = rig.brain;
    await b.setProForTest(true);
    await b.setPref('business_mode', true);
    final now = b.services.now();
    final egg = Product(name: 'ডিম', unit: 'হালি', buy: 44, sell: 52, stock: 30, low: 10);
    final rice = Product(name: 'মিনিকেট চাল', unit: 'কেজি', buy: 68, sell: 75, stock: 4, low: 10);
    final oil = Product(name: 'সয়াবিন তেল', unit: 'লিটার', buy: 165, sell: 180, stock: 22);
    final soap = Product(name: 'লাক্স সাবান', unit: 'পিস', buy: 55, sell: 65, stock: 0, low: 5);
    for (final p in [egg, rice, oil, soap]) {
      await b.saveProduct(p);
    }
    final salma = await b.customerFor('সালমা আপা');
    final rahim = await b.customerFor('রহিম চাচা');
    await b.recordSale(Sale(at: now.subtract(const Duration(days: 40)), lines: [SaleLine(productId: rice.id, name: 'মিনিকেট চাল', qty: 10, unit: 'কেজি', amount: 750, cost: 680)], pay: SalePay.credit, customerId: rahim.id));
    await b.recordSale(Sale(at: now.subtract(const Duration(hours: 3)), lines: [SaleLine(productId: egg.id, name: 'ডিম', qty: 2, unit: 'হালি', amount: 104, cost: 88)], pay: SalePay.cash));
    await b.recordSale(Sale(at: now.subtract(const Duration(hours: 1)), lines: [SaleLine(productId: oil.id, name: 'সয়াবিন তেল', qty: 2, unit: 'লিটার', amount: 360, cost: 330)], pay: SalePay.credit, customerId: salma.id));
    final d = await b.dealerFor('করিম ট্রেডার্স');
    await b.recordPurchase(d.id, [(oil, 10, 1650)], paid: 1000);
    await settle(t);
    Future<void> shot(String name) async {
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/biz/$stage/$name.png'));
    }

    final ctx = t.element(find.byType(HomeShell));
    for (final (i, tab) in [ShellTab.home, ShellTab.diary, ShellTab.people, ShellTab.money, ShellTab.store].indexed) {
      goToTab(ctx, tab);
      await settle(t);
      await shot('${i + 1}-${tab.name}');
    }
    final nav = Navigator.of(ctx);
    nav.push(MaterialPageRoute(builder: (_) => const SellPage()));
    await settle(t);
    await shot('6-sell');
    nav.pop();
    await settle(t);
    nav.push(MaterialPageRoute(builder: (_) => CustomerPage(id: rahim.id)));
    await settle(t);
    await shot('7-customer');
    debugDisableShadows = true;
  });
}
