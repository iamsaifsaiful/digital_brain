import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riyal_hisab/core/ledger.dart';
import 'package:riyal_hisab/core/models.dart';
import 'package:riyal_hisab/main.dart';
import 'package:riyal_hisab/ui/agent.dart';
import 'package:riyal_hisab/ui/kit.dart';
import 'package:riyal_hisab/services/crypto.dart';
import 'package:riyal_hisab/services/device.dart';
import 'package:riyal_hisab/services/lock.dart';
import 'package:riyal_hisab/services/store.dart';
import 'package:riyal_hisab/state/hisab.dart';

import 'fake_server.dart';

Future<void> tapText(WidgetTester tester, String s) async {
  if (find.text(s).evaluate().isEmpty) {
    final list = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).hitTestable().first;
    try {
      await tester.scrollUntilVisible(find.text(s), 300, scrollable: list, maxScrolls: 15);
    } catch (_) {
      await tester.scrollUntilVisible(find.text(s), -300, scrollable: list, maxScrolls: 30);
    }
  }
  await tester.ensureVisible(find.text(s).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(s).first);
  await tester.pumpAndSettle();
}

Future<void> pin(WidgetTester tester, String p) async {
  for (final ch in p.split('')) {
    await tester.tap(find.text(String.fromCharCode('০'.codeUnitAt(0) + int.parse(ch))).last);
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
    final server = FakeServer()..addUser('owner', 'সাইফুল', 'saiful', 'owner-pass');
    final h = Hisab(Services(
      store: DataStore(keys: keys, blob: MemoryBlobStore(), photos: MemoryPhotoFiles()),
      lock: LockService(keys: keys, biometrics: FakeBiometrics(has: false), iterations: 1000),
      device: dev,
      api: server.api(),
      clock: () => DateTime(2026, 11, 2, 21, 40),
    ));
    await tester.pumpWidget(RiyalApp(hisab: h));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();

    expect(find.text('অ্যাপের পিন ঠিক করুন'), findsOneWidget);
    await pin(tester, '1234');
    await pin(tester, '1234');

    // Sign in to the server.
    expect(find.text('এডমিন বা এজেন্ট — নিজের লগইন দিয়ে ঢুকুন'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'saiful');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.text('লগইন').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.textContaining('লগইন হয়নি'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'owner-pass');
    await tester.tap(find.text('লগইন').last);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();

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
    await tester.enterText(fields.at(1), '32.5');
    // Taka first: riyal is worked out.
    await tester.enterText(fields.at(2), '13000');
    await tester.pumpAndSettle();
    expect(find.text('400'), findsOneWidget);
    // A wrong rate blanks the result; putting it right brings it back.
    await tester.enterText(fields.at(1), '');
    await tester.pumpAndSettle();
    expect(find.text('400'), findsNothing);
    await tester.enterText(fields.at(1), '32.5');
    await tester.pumpAndSettle();
    expect(find.text('400'), findsOneWidget);
    // Riyal typed: taka follows, live.
    await tester.enterText(fields.at(0), '500');
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
    dev.clip = '26110001 16250-667';
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
    expect(find.text('এজেন্টের উত্তর কপি করা আছে'), findsOneWidget);
    await tapText(tester, 'ঠিক আছে, এই লেনদেনে বসান');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(h.d.txns.single.status, TxnStatus.sent);
    expect(h.d.txns.single.agentReply, '26110001 16250-667');

    // Tabs swipe.
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('মোট বকেয়া ৩০০ SAR · ১ জন গ্রাহক'), findsOneWidget);
    for (final tab in ['এজেন্ট', 'রিপোর্ট', 'অন্যান্য']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    await tapText(tester, 'কাজের লগ');
    expect(find.textContaining('নতুন লেনদেন'), findsWidgets);
    await tester.tap(find.byTooltip('পেছনে').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('হোম').last);
    await tester.pumpAndSettle();
    // No settings icon on home any more: notifications in its place.
    expect(find.byTooltip('সেটিংস'), findsNothing);
    expect(find.byTooltip('নোটিফিকেশন'), findsOneWidget);

    await tapText(tester, 'রিয়াল জমা');
    await tapText(tester, 'করিম');
    await tester.enterText(find.byType(TextField).first, '300');
    await tester.pumpAndSettle();
    expect(find.text('বকেয়া নেই'), findsOneWidget);
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
    expect(find.text('এজেন্টকে টাকা দিলাম'), findsOneWidget);
    await tapText(tester, 'বিকাশ');
    await tester.enterText(find.descendant(of: find.ancestor(of: find.text('রেফারেন্স / ট্রানজেকশন নম্বর (ইচ্ছা হলে)'), matching: find.byType(Field)), matching: find.byType(TextField)), 'REF123');
    await tapText(tester, 'সংরক্ষণ');
    expect(h.d.agentPayments, isEmpty, reason: 'riyal must be given');
    await tester.scrollUntilVisible(find.text('এর জন্য কত রিয়াল গেল (বাধ্যতামূলক)'), -200,
        scrollable: find.descendant(of: find.byType(AgentPayScreen), matching: find.byType(Scrollable)).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.descendant(of: find.ancestor(of: find.text('এর জন্য কত রিয়াল গেল (বাধ্যতামূলক)'), matching: find.byType(Field)), matching: find.byType(TextField)), '500');
    await tester.pumpAndSettle();
    expect(find.textContaining('রেট দাঁড়াল ৩২.৫০'), findsOneWidget);
    await tapText(tester, 'সংরক্ষণ');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(agentOwed(h.d, h.d.agents.single.id), 0);
    expect(h.d.agentPayments.single.way, 'bkash');
    expect(h.d.agentPayments.single.ref, 'REF123');
    expect(h.d.agentPayments.single.sarAmount, 500);
    expect(h.d.agentPayments.single.byName, 'সাইফুল');
    expect(h.d.txns.single.byName, 'সাইফুল');

    // The cash card opens every riyal in and out of my hand.
    await tester.tap(find.text('হোম').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'আমার হাতে থাকা উচিত');
    expect(find.text('হাতের হিসাব'), findsOneWidget);
    // The handover sheet: cash from sends, dues collected, paid to the agent.
    expect(find.textContaining('লেনদেনে নগদ পেলাম'), findsOneWidget);
    expect(find.textContaining('আগের বকেয়া আদায়'), findsOneWidget);
    expect(find.textContaining('এজেন্টকে দিলাম'), findsOneWidget);
    expect(find.text('৫০০.০০ SAR').evaluate().isNotEmpty || find.text('৫০০ SAR').evaluate().isNotEmpty, isTrue);
    await tapText(tester, 'প্রতিটা আসা-যাওয়া দেখুন (৩টা)');
    expect(find.text('−৫০০ SAR'), findsOneWidget);
    expect(find.text('+২০০ SAR'), findsOneWidget);
    expect(find.text('+৩০০ SAR'), findsOneWidget);
    expect(h.myCash, 0);
    await tester.tap(find.byTooltip('পেছনে').last);
    await tester.pumpAndSettle();

    // Customer page, send detail and edit open.
    await tester.tap(find.text('গ্রাহক').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'করিম');
    expect(find.text('হিসাবের খাতা'), findsOneWidget);
    await tester.tap(find.byTooltip('পেছনে').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('অন্যান্য').last);
    await tester.pumpAndSettle();
    // The day-end count is gone from the menu.
    expect(find.text('দিন শেষের হিসাব'), findsNothing);
    await tapText(tester, 'সব লেনদেন');
    await tapText(tester, 'আজ');
    await tester.tap(find.textContaining('#২৬১১০০০১').first);
    await tester.pumpAndSettle();
    expect(find.text('২৬১১০০০১ ১৬২৫০-৬৬৭ · কপি থেকে অটো'), findsOneWidget);
    // Sent by the agent: no cancel, but a wrong number can be marked.
    expect(find.text('লেনদেন বাতিল'), findsNothing);
    await tapText(tester, 'ভুল নম্বরে গেছে?');
    await tapText(tester, 'এজেন্টের ভুল');
    await tapText(tester, 'চিহ্ন দিন');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(h.d.txns.single.fault, Fault.agent);
    await tester.fling(find.byType(Scrollable).hitTestable().first, const Offset(0, 3000), 3000);
    await tester.pumpAndSettle();
    expect(find.text('ভুল নম্বরে গেছে — এজেন্টের ভুল'), findsOneWidget);
    // A sent send is never edited: a mistake goes to অতিরিক্ত হিসাব.
    expect(find.byTooltip('সংশোধন'), findsNothing);
    final dueBefore = customerDue(h.d, h.d.customers.single.id);
    await tapText(tester, 'ভুল হয়েছে? অতিরিক্ত হিসাব লিখুন');
    await tester.enterText(find.byType(TextField).first, '50');
    await tester.enterText(find.byType(TextField).last, 'রিয়াল ৫০ কম লিখেছিলাম');
    await tester.pumpAndSettle();
    await tester.tap(find.text('আলাদা করে রাখুন'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(h.d.adjusts.single.sarDue, 50);
    expect(customerDue(h.d, h.d.customers.single.id), dueBefore, reason: 'apart until added');
    await tapText(tester, 'মূল হিসাবে যোগ করুন');
    await tapText(tester, 'যোগ করুন');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(customerDue(h.d, h.d.customers.single.id), dueBefore + 50);
    expect(find.text('মূল হিসাবে আছে'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Everything is on the server.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await h.sync();
    });
    expect(server.one('txn', h.d.txns.single.id)!['fault'], 'agent');
    expect(server.records.keys.where((k) => k.startsWith('log:')).length, h.d.log.length);
    expect(server.records.containsKey('payment:${h.d.agentPayments.single.id}'), isTrue);
    expect(server.one('adjust', h.d.adjusts.single.id)!['applied'], isTrue);
    expect(h.d.txns.single.no, 26110001);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
