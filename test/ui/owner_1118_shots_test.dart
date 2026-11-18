// Owner, 18 Nov: আরও with the profile lower down (place and blood group as
// two clear tiles); the notification page opens on what already came; a new
// খাত in হিসাব is typed in a box on top, not a field further down.
// SHOTS=1 --update-goldens writes test/ui/shots/owner_1118/*.png.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/brain.dart' show BrainMore;
import 'package:digital_brain/screens/money_screens.dart' show CashFormScreen;
import 'package:digital_brain/screens/notice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_shots_test.dart' show rig0;
import '../app_test.dart' show settle;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> shot(WidgetTester t, String name) async {
  if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/owner_1118/$name.png'));
}

void main() {
  testWidgets('আরও: the profile below the features, place and blood group shown', (t) async {
    final rig = await rig0(t);
    rig.brain.gated = true;
    await rig.brain.saveEmergency(rig.brain.data.emergency.copyWith(blood: 'B+'));
    t.view.physicalSize = const Size(1170, 2532 * 2.6);
    await t.tap(find.text('আরও').last);
    await settle(t);
    double y(String k) => t.getTopLeft(find.byKey(Key(k))).dy;
    expect(y('more-tools'), lessThan(y('more-profile')));
    expect(find.descendant(of: find.byKey(const Key('more-blood')), matching: find.text('B+')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('more-place')), matching: find.text('লোকেশন')), findsOneWidget);
    expect(y('more-feedback'), lessThan(y('more-help')));
    expect(find.text('তথ্য এক্সপোর্ট ও রিসাইকেল বিন'), findsOneWidget);
    expect(find.text('ফ্রি'), findsOneWidget);
    await shot(t, '1-more-free');
    rig.brain.proUntil = DateTime(2027, 11, 6);
    rig.brain.proKind = 'paid';
    rig.brain.notifyListeners();
    await settle(t);
    expect(find.text('প্রিমিয়াম'), findsWidgets);
    expect(find.text('আর ৩৭৮ দিন বাকি'), findsOneWidget);
    await shot(t, '1-more');
    t.view.physicalSize = const Size(1170, 2532);
    await settle(t);
    debugDisableShadows = true;
  });

  testWidgets('notifications: what came first, what is coming next', (t) async {
    final rig = await rig0(t);
    await rig.brain.saveReminder(Reminder(title: 'ওষুধ খাওয়া', date: DateTime(2026, 10, 24), hour: 21, repeat: Repeat.daily));
    Navigator.of(t.element(find.byTooltip('বলুন'))).push(MaterialPageRoute(builder: (_) => const NoticeScreen()));
    await settle(t);
    final tabs = [find.text('আগে এসেছে'), find.textContaining('আসছে (')];
    expect(t.getTopLeft(tabs[0]).dx, lessThan(t.getTopLeft(tabs[1]).dx));
    await shot(t, '2-notice');
    debugDisableShadows = true;
  });

  testWidgets('হিসাব: a new খাত in a box on top', (t) async {
    final rig = await rig0(t);
    Navigator.of(t.element(find.byTooltip('বলুন'))).push(MaterialPageRoute(builder: (_) => const CashFormScreen()));
    await settle(t);
    await t.enterText(find.byKey(const Key('cash-amount')), '৫০০');
    await t.tap(find.byKey(const Key('cash-cat-new')));
    await settle(t);
    expect(find.byKey(const Key('cash-cat-dialog')), findsOneWidget);
    await t.enterText(find.byKey(const Key('cash-cat-field')), 'গাছের যত্ন');
    await settle(t);
    await shot(t, '3-cat-dialog');
    await t.tap(find.byKey(const Key('cash-cat-ok')));
    await settle(t);
    expect(find.byKey(const Key('cash-cat-dialog')), findsNothing);
    expect(find.byKey(const Key('cash-cat-own')), findsOneWidget);
    await shot(t, '4-cat-picked');
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    expect(rig.brain.data.cash.any((e) => e.category == 'গাছের যত্ন' && e.amount == 500), isTrue);
    debugDisableShadows = true;
  });
}
