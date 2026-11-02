import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riyal_hisab/core/ledger.dart';
import 'package:riyal_hisab/main.dart';
import 'package:riyal_hisab/services/crypto.dart';
import 'package:riyal_hisab/services/device.dart';
import 'package:riyal_hisab/services/lock.dart';
import 'package:riyal_hisab/services/store.dart';
import 'package:riyal_hisab/state/hisab.dart';

Future<void> tapText(WidgetTester tester, String s) async {
  await tester.ensureVisible(find.text(s).first);
  await tester.tap(find.text(s).first);
  await tester.pumpAndSettle();
}

Future<void> pin(WidgetTester tester, String p) async {
  for (final ch in p.split('')) {
    await tester.tap(find.text(String.fromCharCode('০'.codeUnitAt(0) + int.parse(ch))).first);
    await tester.pump();
  }
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first run, a send to WhatsApp, TrxID from clipboard, deposit', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final keys = MemoryKeyVault();
    final dev = FakeDevice();
    final h = Hisab(Services(
      store: DataStore(keys: keys, blob: MemoryBlobStore(), photos: MemoryPhotoFiles()),
      lock: LockService(keys: keys, biometrics: FakeBiometrics(has: false), iterations: 1000),
      device: dev,
    ));
    await tester.pumpWidget(RiyalApp(hisab: h));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    expect(find.text('অ্যাপের পিন ঠিক করুন'), findsOneWidget);
    await pin(tester, '1234');
    await pin(tester, '1234');

    expect(find.text('শুরু করা যাক'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(2), '01811111111');
    await tapText(tester, 'শুরু করুন');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.text('সাইফুল'), findsOneWidget);

    await tapText(tester, 'নতুন পাঠানো');
    await tester.enterText(find.byType(TextField).first, 'করিম');
    await tester.pumpAndSettle();
    await tapText(tester, 'নতুন গ্রাহক: "করিম"');
    await tester.enterText(find.byType(TextField).at(1), '0551234567');
    await tapText(tester, 'সংরক্ষণ করে এগোন');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    expect(find.text('কত পাঠাবেন'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '500');
    await tester.enterText(fields.at(1), '32.5');
    await tester.pumpAndSettle();
    expect(find.text('16250'), findsOneWidget);
    await tester.enterText(fields.at(3), '01812345901');
    await tester.pumpAndSettle();
    await tapText(tester, 'পরের ধাপ');
    expect(find.text('মিলিয়ে দেখুন'), findsOneWidget);
    await tapText(tester, 'আংশিক');
    await tester.enterText(find.byType(TextField).last, '200');
    await tester.pumpAndSettle();
    await tapText(tester, 'সংরক্ষণ ও হোয়াটসঅ্যাপে পাঠান');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

    expect(dev.opened, hasLength(1));
    final msg = Uri.decodeComponent(dev.opened.single.toString());
    expect(msg, startsWith('https://wa.me/8801811111111?text='));
    expect(msg, contains('16,250'));
    expect(msg, isNot(contains('রিয়াল')));
    expect(h.d.txns.single.sarPaid, 200);
    expect(customerDue(h.d, h.d.customers.single.id), 300);

    // Back from WhatsApp with the reply copied.
    dev.clip = 'ok 901 BJ7K9X2Q1M';
    await tester.tap(find.byTooltip('পেছনে').last);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final st in [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused, AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
        tester.binding.handleAppLifecycleStateChanged(st);
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pumpAndSettle();
    // Auto-lock default is 30 s, so it is still open.
    expect(find.text('কপি করা TrxID পাওয়া গেছে'), findsOneWidget);
    await tapText(tester, 'এই লেনদেনে বসান');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(h.d.txns.single.trxId, 'BJ7K9X2Q1M');

    // Other tabs and screens open without errors.
    for (final tab in ['গ্রাহক', 'এজেন্ট', 'রিপোর্ট', 'হোম']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byTooltip('কাজের লগ'));
    await tester.pumpAndSettle();
    expect(find.textContaining('নতুন লেনদেন'), findsWidgets);
    await tester.tap(find.byTooltip('পেছনে').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('সেটিংস'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('পেছনে').last);
    await tester.pumpAndSettle();

    await tapText(tester, 'রিয়াল জমা');
    await tapText(tester, 'করিম');
    await tester.enterText(find.byType(TextField).first, '300');
    await tester.pumpAndSettle();
    expect(find.text('বাকি শেষ'), findsOneWidget);
    await tapText(tester, 'জমা সংরক্ষণ');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    await tapText(tester, 'না');
    expect(customerDue(h.d, h.d.customers.single.id), 0);

    // Pay the agent for the selected send.
    await tester.tap(find.text('এজেন্ট').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'সবগুলো');
    await tapText(tester, '১টার টাকা দিলাম · ৳ ১৬,২৫০');
    await tapText(tester, 'হ্যাঁ, দিয়েছি');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(agentOwed(h.d, h.d.agents.single.id), 0);

    // Customer page, send detail and edit open.
    await tester.tap(find.text('গ্রাহক').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'করিম');
    expect(find.text('হিসাবের খাতা'), findsOneWidget);
    await tester.tap(find.byTooltip('পেছনে').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('হোম').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'দিন শেষ');
    await tester.enterText(find.byType(TextField).first, '500');
    await tester.pumpAndSettle();
    expect(find.text('মিলেছে।'), findsOneWidget);
    await tapText(tester, 'হিসাব মিলিয়ে রাখুন');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    await tapText(tester, 'সব দেখুন');
    await tester.tap(find.textContaining('#১০০১').first);
    await tester.pumpAndSettle();
    expect(find.text('BJ7K9X2Q1M'), findsOneWidget);
    await tester.tap(find.byTooltip('সংশোধন'));
    await tester.pumpAndSettle();
    expect(find.text('লেনদেন সংশোধন #১০০১'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
