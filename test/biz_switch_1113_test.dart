// Owner, 13 Nov: "ব্যবসায়ী মোড চালু করলে এখনো কিছুটা গ্লিজ মারে" — the আরও page
// is built again when the mode switches; it must open where it was.
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/state/brain.dart' show BrainShop;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  testWidgets('switching ব্যবসায়ী মোড from আরও and back', (t) async {
    final rig = await start(t);
    await rig.brain.startBusiness(kind: 'skip');
    goToTab(t.element(find.byType(Scaffold).first), ShellTab.more);
    await settle(t);
    final sw = find.byKey(const Key('more-business'));
    await t.scrollUntilVisible(sw, 200, scrollable: find.descendant(of: find.byKey(const PageStorageKey('more-list')), matching: find.byType(Scrollable)).first);
    await settle(t);
    await t.tap(sw);
    await t.pump(const Duration(milliseconds: 16));
    expect(t.takeException(), isNull);
    await settle(t);
    // Owner, 23 Nov: the business আরও is its own page, the way back near its top.
    final back = find.byKey(const Key('more-business'));
    expect(back, findsOneWidget);
    expect(t.getTopLeft(back).dy, lessThan(400));
    await t.tap(back);
    await settle(t);
    expect(find.byKey(const Key('more-business')), findsOneWidget);
  });
}
