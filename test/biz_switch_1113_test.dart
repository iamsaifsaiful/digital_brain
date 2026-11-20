// Owner, 13 Nov: "ব্যবসায়ী মোড চালু করলে এখনো কিছুটা গ্লিজ মারে" — the আরও page
// is built again when the mode switches; it must open where it was.
import 'package:digital_brain/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  testWidgets('switching ব্যবসায়ী মোড keeps আরও where it was', (t) async {
    await start(t);
    goToTab(t.element(find.byType(Scaffold).first), ShellTab.more);
    await settle(t);
    final sw = find.byKey(const Key('more-business'));
    await t.scrollUntilVisible(sw, 200, scrollable: find.descendant(of: find.byKey(const PageStorageKey('more-list')), matching: find.byType(Scrollable)).first);
    await settle(t);
    final before = t.getTopLeft(sw).dy;
    await t.tap(sw);
    await t.pump(const Duration(milliseconds: 16));
    // The new page, mid-fade, already at the same place.
    final now = t.getTopLeft(find.byKey(const Key('more-business')).last).dy;
    expect((now - before).abs(), lessThan(2));
    await settle(t);
    expect((t.getTopLeft(find.byKey(const Key('more-business'))).dy - before).abs(), lessThan(2));
  });
}
