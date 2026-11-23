// Owner, 23 Nov: "বিক্রি মেনুতে, আজ মাসিক, বার্ষিক তারিখ এভাবে ফিল্টার হবে";
// floating add buttons (বিক্রয় and other lists); a ✕ on the memo sheet.
// SHOTS=1 flutter test test/ui/biz_sales_filter_1123_test.dart --update-goldens
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/screens/reminders_screen.dart';
import 'package:digital_brain/screens/vault_screen.dart';
import 'package:digital_brain/screens/bank_accounts_screen.dart';
import 'package:digital_brain/state/brain.dart' show BrainShop;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> _shot(WidgetTester t, String name) async {
  if (!shots) return;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/biz_1123b/$name.png'));
}

void main() {
  setUp(() async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
  });

  testWidgets('sales: আজ, মাসিক, বার্ষিক, তারিখ; floating buttons; ✕ on the memo', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 23, 18, 30);
    final b = rig.brain;
    await b.setProForTest(true);
    await b.startBusiness(kind: 'skip');
    final rice = Product(name: 'মিনিকেট চাল', unit: 'কেজি', buy: 68, sell: 75, stock: 400);
    await b.saveProduct(rice);
    final p = b.shop.products.single;
    Future<void> sell(DateTime at, int kg) => b.recordSale(Sale(at: at, lines: [SaleLine(productId: p.id, name: p.name, qty: kg.toDouble(), unit: 'কেজি', amount: 75 * kg, cost: 68 * kg)], pay: SalePay.cash));
    await sell(DateTime(2026, 11, 23, 10), 2); // today
    await sell(DateTime(2026, 11, 20, 12), 3); // this month
    await sell(DateTime(2026, 10, 5, 12), 4); // October
    await sell(DateTime(2025, 6, 1, 12), 5); // last year
    await b.setPref('business_mode', true);
    await settle(t);
    final ctx = t.element(find.byType(HomeShell));
    goToTab(ctx, ShellTab.diary);
    await settle(t);
    expect(find.byKey(const Key('biz-sell-fab')), findsOneWidget);
    expect(find.text('৳১৫০'), findsWidgets);
    await _shot(t, '1-today');

    await t.tap(find.text('মাসিক'));
    await settle(t);
    expect(find.textContaining('নভেম্বর ২০২৬'), findsWidgets);
    expect(find.text('২টি · ৳৩৭৫'), findsOneWidget);
    await _shot(t, '2-month');
    await t.tap(find.byKey(const Key('biz-sales-month-back')));
    await settle(t);
    expect(find.text('১টি · ৳৩০০'), findsOneWidget, reason: 'October');

    await t.tap(find.text('বার্ষিক'));
    await settle(t);
    expect(find.text('৩টি · ৳৬৭৫'), findsOneWidget);
    await _shot(t, '3-year');
    await t.tap(find.byKey(const Key('biz-sales-year-back')));
    await settle(t);
    expect(find.text('১টি · ৳৩৭৫'), findsOneWidget, reason: '2025');
    await t.tap(find.byKey(const Key('biz-sales-m-6')));
    await settle(t);
    expect(find.textContaining('জুন ২০২৫'), findsWidgets, reason: 'a month row opens that month');

    await t.tap(find.text('তারিখ'));
    await settle(t);
    expect(find.byType(DatePickerDialog), findsOneWidget);
    Navigator.of(t.element(find.byType(DatePickerDialog))).pop(); // keep today
    await settle(t);
    await t.tap(find.byKey(const Key('biz-sales-day-back')));
    await t.pump();
    await t.tap(find.byKey(const Key('biz-sales-day-back')));
    await t.pump();
    await t.tap(find.byKey(const Key('biz-sales-day-back')));
    await settle(t);
    expect(find.text('১টি · ৳২২৫'), findsOneWidget, reason: '20 Nov');
    await _shot(t, '4-date');

    // The memo sheet closes with ✕.
    await t.tap(find.byKey(Key('biz-sale-${b.shop.sales.firstWhere((s) => s.at.day == 20).id}')));
    await settle(t);
    expect(find.byKey(const Key('biz-receipt-close')), findsOneWidget);
    await _shot(t, '5-memo-close');
    await t.tap(find.byKey(const Key('biz-receipt-close')));
    await settle(t);
    expect(find.byKey(const Key('biz-receipt-close')), findsNothing);

    goToTab(ctx, ShellTab.store);
    await settle(t);
    await _shot(t, '6-stock');

    // Personal pages with a floating add button.
    final nav = Navigator.of(ctx);
    nav.push(MaterialPageRoute(builder: (_) => const RemindersScreen()));
    await settle(t);
    expect(find.byKey(const Key('reminder-fab')), findsOneWidget);
    await _shot(t, '7-reminders');
    nav.pop();
    await settle(t);
    b.markVerified();
    nav.push(MaterialPageRoute(builder: (_) => const VaultPage()));
    await settle(t);
    expect(find.byKey(const Key('vault-fab')), findsOneWidget);
    await _shot(t, '8-passwords');
    nav.pop();
    await settle(t);
    nav.push(MaterialPageRoute(builder: (_) => const BankAccountsScreen()));
    await settle(t);
    expect(find.byKey(const Key('acct-add')), findsOneWidget);
    await _shot(t, '9-bank');
    debugDisableShadows = true;
  });
}
