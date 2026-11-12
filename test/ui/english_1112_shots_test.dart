// Owner, 12 Nov: "তাইলে সব ইংরেজি করে প্রতিটি পেইজের ছবি দেখাও". Every page,
// tab and Business mode page in English with an English sample, on a phone.
// Each test fails if Bangla shows anywhere on the page except in words the
// user typed (the sample's own Bangla-free names) or the app's language
// name "বাংলা". SHOTS=1 --update-goldens also writes the screenshots to
// test/ui/shots/en1112/ (gitignored).
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/app_places.dart';
import 'package:digital_brain/screens/biz/biz_customers.dart';
import 'package:digital_brain/screens/biz/biz_hisab.dart';
import 'package:digital_brain/screens/biz/biz_sales.dart';
import 'package:digital_brain/screens/biz/biz_shop.dart';
import 'package:digital_brain/screens/biz/biz_stock.dart';
import 'package:digital_brain/screens/cards_screen.dart';
import 'package:digital_brain/screens/family_screen.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/screens/pro_screen.dart';
import 'package:digital_brain/screens/requests_screen.dart';
import 'package:digital_brain/screens/zakat_principles.dart';
import 'package:digital_brain/screens/zakat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import 'package:digital_brain/logic/lang.dart' show tr;

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';
const size = Size(390, 1500);

final _bn = RegExp(r'[ঀ-৲৴-৿]'); // ৳ (U+09F3) is the money sign

/// An English user's own data.
AppData englishSample(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final bkash = MoneyAccount(name: 'bKash', kind: AccountKind.bkash, opening: 5000);
  final rice = Product(name: 'Miniket rice', unit: 'কেজি', buy: 68, sell: 75, stock: 40, low: 10, category: 'চাল-ডাল-আটা');
  final oil = Product(name: 'Soybean oil 1 L', unit: 'পিস', buy: 175, sell: 190, stock: 3, low: 5, category: 'তেল-মসলা');
  final karim = Customer(name: 'Karim', phone: '01819765432', limit: 5000);
  final dealer = Dealer(name: 'Rahman Traders', phone: '01711000111');
  return AppData(
    accounts: [bkash],
    cash: [
      CashEntry(kind: CashKind.expense, amount: 450, category: 'বাজার', note: 'Vegetables', date: now, accountId: bkash.id),
      CashEntry(kind: CashKind.expense, amount: 1200, category: 'যাতায়াত', date: now.subtract(const Duration(days: 1))),
      CashEntry(kind: CashKind.expense, amount: 2500, category: 'বিল', note: 'Electricity', date: now.subtract(const Duration(days: 2))),
      CashEntry(kind: CashKind.income, amount: 35000, category: 'বেতন', date: now.subtract(const Duration(days: 3))),
    ],
    ledger: [LedgerEntry(person: 'Rahim', amount: 3000, kind: LedgerKind.lent, date: now.subtract(const Duration(days: 9)))],
    tasks: [
      Task(title: 'Pay the electricity bill', due: today.add(const Duration(hours: 11))),
      Task(title: 'Doctor’s appointment', due: today.add(const Duration(hours: 17)), urgent: true),
      Task(title: 'Grocery list', due: today, done: true, doneAt: now.subtract(const Duration(hours: 1))),
      Task(title: 'School fees', due: today.add(const Duration(days: 1, hours: 10))),
    ],
    reminders: [Reminder(title: 'Call Mom', date: now, hour: 20)],
    notes: [Note(title: 'Gate code', body: '4421'), Note(title: 'Car papers', body: 'Top shelf of the wardrobe')],
    docs: [Doc(title: 'Passport', expiry: now.add(const Duration(days: 12)))],
    medicines: [Medicine(name: 'Napa', times: [480, 1260])],
    goals: [SavingsGoal(name: 'Hajj', target: 500000, deposits: [GoalDeposit(180000, now)])],
    installments: [Installment(name: 'Home loan', kind: InstallmentKind.loan, amount: 12000, months: 24, start: DateTime(now.year - 1, now.month), paid: [for (var i = 0; i < 10; i++) monthKey(DateTime(now.year - 1, now.month + i))])],
    contacts: [Contact(name: 'Mom', phone: '01711234567'), Contact(name: 'Karim', phone: '01819765432')],
    vault: [VaultItem(name: 'Gmail', username: 'saiful@gmail.com', password: 'x')],
    specialDays: [SpecialDay(person: 'Jamal', month: now.month, day: now.day, year: 1993)],
    habits: [Habit(name: '30-minute walk', done: [for (var i = 1; i < 6; i++) dayKey(today.subtract(Duration(days: i)))])],
    health: [
      HealthLog(kind: HealthKind.bp, at: now.subtract(const Duration(hours: 3)), a: 120, b: 80),
      HealthLog(kind: HealthKind.weight, at: now.subtract(const Duration(days: 1)), a: 72),
    ],
    projects: [Project(name: 'House build', budget: 500000)],
    shop: ShopBook(
      products: [rice, oil],
      customers: [karim],
      dealers: [dealer],
      sales: [
        Sale(at: now.subtract(const Duration(hours: 2)), lines: [SaleLine(productId: rice.id, name: rice.name, qty: 5, unit: 'কেজি', amount: 375, cost: 340)], no: 1),
        Sale(at: now.subtract(const Duration(hours: 1)), lines: [SaleLine(productId: oil.id, name: oil.name, qty: 2, unit: 'পিস', amount: 380, cost: 350)], pay: SalePay.credit, customerId: karim.id, customer: karim.name, no: 2),
      ],
      profile: const ShopProfile(name: 'Ma General Store', address: 'Station Road, Sylhet', phone: '01711000222'),
    ),
  );
}

/// Every text on screen that still has Bangla in it.
List<String> bangla(WidgetTester t) {
  final out = <String>{};
  for (final w in t.allWidgets) {
    final s = switch (w) {
      Text(:final data, :final textSpan) => data ?? textSpan?.toPlainText() ?? '',
      RichText(:final text) => text.toPlainText(),
      EditableText(:final controller) => controller.text,
      _ => '',
    };
    if (_bn.hasMatch(s) && s.trim() != 'বাংলা') out.add(s.replaceAll('\n', ' ⏎ '));
  }
  return out.toList();
}

Future<void> shoot(WidgetTester t, String name) async {
  final left = {...bangla(t)};
  if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/en1112/$name.png'));
  // The rest of each scrolled part, down to its end, read too (and shot once).
  var more = false;
  for (final s in find.byType(Scrollable).evaluate().toList()) {
    if (!s.mounted) continue;
    final st = (s as StatefulElement).state as ScrollableState;
    if (st.position.axis == Axis.vertical && st.position.maxScrollExtent > 0) {
      st.position.jumpTo(st.position.maxScrollExtent);
      await t.pump();
      more = true;
    }
  }
  if (more) {
    await settle(t);
    left.addAll(bangla(t));
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/en1112/$name-b.png'));
  }
  debugDisableShadows = true;
  expect(left, isEmpty, reason: 'Bangla left on $name');
}

Future<dynamic> open(WidgetTester t, {bool business = false}) async {
  t.view.physicalSize = size * 2;
  t.view.devicePixelRatio = 2;
  addTearDown(t.view.reset);
  if (shots) {
    await four.icons();
    debugDisableShadows = false;
  }
  final rig = await start(t);
  await rig.brain.setEnglish(true);
  await rig.brain.setUserName('Saiful');
  await rig.brain.setProForTest(true);
  rig.brain.data = englishSample(rig.brain.services.now());
  if (business) await rig.brain.setPref('business_mode', true);
  await settle(t);
  return rig;
}

void main() {
  final pages = <String, Widget Function()>{
    for (final id in ['tasks', 'reminders', 'alarms', 'calendar', 'special', 'notes', 'will', 'docs', 'vault', 'contacts', 'report', 'spending', 'accounts', 'savings', 'split', 'shop', 'health', 'medicines', 'habits', 'emergency', 'expiry', 'tags', 'memory', 'templates', 'search', 'settings', 'notifications', 'sound', 'backup', 'trash', 'help', 'compass'])
      id: () => placePage(id)!,
    'zakat': () => const ZakatScreen(),
    'zakat-rules': () => const ZakatPrinciplesScreen(),
    'family': () => const FamilyScreen(),
    'blood': () => const RequestsScreen(),
    'premium': () => const ProScreen(),
    'cards': () => const CardsScreen(),
    'card-new': () => const CardFormScreen(),
  };
  for (final e in pages.entries) {
    testWidgets('English page: ${e.key}', (t) async {
      await open(t);
      Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => e.value()));
      await settle(t);
      await shoot(t, 'page-${e.key}');
    });
  }
  for (final tab in shellTabs(false)) {
    testWidgets('English tab: ${tab.name}', (t) async {
      await open(t);
      goToTab(t.element(find.byType(Scaffold).first), tab);
      await settle(t);
      await shoot(t, 'tab-${tab.index}-${tab.name}');
    });
  }
  for (final tab in shellTabs(true)) {
    testWidgets('English business tab: ${tab.name}', (t) async {
      await open(t, business: true);
      goToTab(t.element(find.byType(Scaffold).first), tab);
      await settle(t);
      await shoot(t, 'biz-tab-${tab.index}-${tab.name}');
    });
  }
  final biz = <String, Widget Function(AppData)>{
    'sell': (_) => const SellPage(),
    'sell-amount': (_) => const SellPage(amountOnly: true),
    'customer': (d) => CustomerPage(id: d.shop.customers.first.id),
    'dealer': (d) => DealerPage(id: d.shop.dealers.first.id),
    'biz-cash': (_) => const BizCashPage(),
    'shop-profile': (_) => const ShopProfilePage(),
    'payment-reminder': (_) => const TagadaPage(),
    'order': (_) => const PurchasePage(),
    'goods-in': (_) => const PurchasePage(part: 'in'),
  };
  for (final e in biz.entries) {
    testWidgets('English business page: ${e.key}', (t) async {
      final rig = await open(t, business: true);
      Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => e.value(rig.brain.data as AppData)));
      await settle(t);
      await shoot(t, 'biz-${e.key}');
    });
  }
  testWidgets('English chat', (t) async {
    await open(t);
    await t.tap(find.byKey(const ValueKey('box')));
    await t.tap(find.descendant(of: find.byKey(const ValueKey('box')), matching: find.byType(TextField)));
    await settle(t);
    await t.tap(find.text(tr('আগের কথা')));
    await settle(t);
    if (find.byTooltip(tr('লিখে বলুন')).evaluate().isNotEmpty) {
      await t.tap(find.byTooltip(tr('লিখে বলুন')));
      await settle(t);
    }
    for (final said in ['Spent 500 taka on groceries', 'Yes', 'Remind me about the meeting tomorrow at 10 am', 'How much did I spend this month?']) {
      await t.enterText(find.byType(TextField).first, said);
      await t.pump();
      final button = find.byTooltip(tr('পাঠান'));
      t.widget<InkWell>(find.descendant(of: button.first, matching: find.byType(InkWell)).first).onTap!();
      await t.pump();
      await settle(t);
    }
    await shoot(t, 'chat');
  });
}
