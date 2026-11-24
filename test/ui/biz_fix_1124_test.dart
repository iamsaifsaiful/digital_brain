// Owner, 24 Nov (on the phone): a new business started with ৳0 still
// showed ৳12,250 capital (goods written in before); the start could not be
// changed; pull to refresh; the report swipes month ↔ year; ক্রয়ের তালিকা vs
// অর্ডার তালিকা; text hidden behind the phone's buttons.
// SHOTS=1 flutter test test/ui/biz_fix_1124_test.dart --update-goldens
import 'dart:io';

import 'package:digital_brain/logic/biz_account.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/biz/biz_account_page.dart';
import 'package:digital_brain/screens/biz/biz_setup.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/state/brain.dart' show BrainShop;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> _shot(WidgetTester t, String name) async {
  if (!shots) return;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/biz_1124/$name.png'));
}

void main() {
  setUp(() async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
  });

  testWidgets('new business with old goods: count them or start at zero; start changed later', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 24, 9, 30);
    final b = rig.brain;
    await b.setProForTest(true);
    // Goods written in before the business was set up.
    await b.saveProduct(Product(name: 'মিনিকেট চাল', unit: 'কেজি', buy: 70, sell: 75, stock: 175));
    expect(b.shop.products.single.value, 12250);
    final ctx = t.element(find.byType(HomeShell));
    final nav = Navigator.of(ctx);
    nav.push(MaterialPageRoute(builder: (_) => const BizSetupPage()));
    await settle(t);
    await t.tap(find.text('নতুন শুরু করছি'));
    await settle(t);
    await t.tap(find.byKey(const Key('setup-next')));
    await settle(t);
    await t.enterText(find.byKey(const Key('setup-cash')), '0');
    await settle(t);
    await t.dragUntilVisible(find.byKey(const Key('setup-old-stock')), find.byType(ListView).last, const Offset(0, -200));
    await settle(t);
    expect(find.text('আগে থেকে অ্যাপে ৳১২,২৫০-এর মাল লেখা আছে'), findsOneWidget);
    expect(find.text('৳১২,২৫০'), findsWidgets, reason: 'counted by default');
    await t.tap(find.byKey(const Key('setup-old-zero')));
    await settle(t);
    await t.dragUntilVisible(find.byKey(const Key('setup-confirm')), find.byType(ListView).last, const Offset(0, -200));
    await settle(t);
    expect(find.byKey(const Key('setup-capital-amount')), findsOneWidget);
    expect((t.widget(find.byKey(const Key('setup-capital-amount'))) as Text).data, '৳০');
    await _shot(t, '1-new-old-stock');
    await t.tap(find.byKey(const Key('setup-confirm')));
    await settle(t);
    await t.tap(find.byKey(const Key('setup-done')));
    await settle(t);
    expect(b.shop.start!.sums.capital, 0);
    expect(b.shop.products.single.stock, 0, reason: 'the old goods start at zero');
    expect(bizAccount(b.shop, b.data.cash).adds, isTrue);

    // Later: the start changed (cash put in from today).
    rig.nowAt = rig.nowAt.add(const Duration(hours: 2));
    nav.push(MaterialPageRoute(builder: (_) => const BizAccountPage()));
    await settle(t);
    await t.dragUntilVisible(find.byKey(const Key('biz-acc-redo')), find.byType(ListView).last, const Offset(0, -300));
    await settle(t);
    await _shot(t, '2-account-redo');
    await t.tap(find.byKey(const Key('biz-acc-redo')));
    await settle(t);
    expect(find.text('শুরুর হিসাব বদলান'), findsWidgets);
    await _shot(t, '3-redo-start');
    await t.tap(find.byKey(const Key('setup-next')));
    await settle(t);
    await t.enterText(find.byKey(const Key('setup-cash')), '20000');
    await settle(t);
    await t.ensureVisible(find.byKey(const Key('setup-confirm')));
    await settle(t);
    await t.tap(find.byKey(const Key('setup-confirm')));
    await settle(t);
    await t.tap(find.byKey(const Key('setup-done')));
    await settle(t);
    expect(b.shop.start!.sums.capital, 20000);
    expect(b.shop.start!.at, rig.nowAt);
    final acc = bizAccount(b.shop, b.data.cash);
    expect((acc.adds, acc.now.capital, acc.flows.adjustCount), (true, 20000, 0));

    // The report: month and year slide.
    nav.push(MaterialPageRoute(builder: (_) => const BizReportPage()));
    await settle(t);
    expect(find.byKey(const Key('biz-report-prev')), findsOneWidget);
    await t.fling(find.byType(PageView), const Offset(-400, 0), 1200);
    await settle(t);
    expect(find.byKey(const Key('biz-report-y-prev')), findsOneWidget, reason: 'swiped to the year');
    await _shot(t, '4-report-year');
    debugDisableShadows = true;
  });
}
