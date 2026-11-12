// Owner, 12 Nov: a user said the UI is pretty but the UX could be more
// logical and there is very little negative space. Before/after shots of the
// pages reworked first: হোম, হিসাব and কাজের তালিকা, screen by screen as a
// person scrolls. SHOTS=1 STAGE=before|after --update-goldens writes them to
// test/ui/shots/gap/<stage>/ (gitignored).
import 'dart:io';

import 'package:digital_brain/screens/app_places.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'all_pages_shots_test.dart' show richer;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';
final stage = Platform.environment['STAGE'] ?? 'after';

Future<void> screens(WidgetTester t, String name) async {
  for (var i = 1; i <= 4; i++) {
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/gap/$stage/$name-$i.png'));
    final list = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).hitTestable();
    if (list.evaluate().isEmpty) return;
    final st = t.state<ScrollableState>(list.first);
    if (st.position.pixels >= st.position.maxScrollExtent - 1) return;
    st.position.jumpTo((st.position.pixels + 600).clamp(0, st.position.maxScrollExtent));
    await settle(t);
  }
}

void main() {
  for (final (name, tab, page) in [('home', ShellTab.home, null), ('money', ShellTab.money, null), ('tasks', null, 'tasks'), ('more', ShellTab.more, null), ('health', null, 'health')]) {
    testWidgets('gap: $name', (t) async {
      if (shots) {
        await four.icons();
        debugDisableShadows = false;
      }
      final rig = await start(t);
      await rig.brain.setUserName('সাইফুল');
      rig.brain.data = richer(rig.brain.services.now());
      await settle(t);
      if (tab != null) goToTab(t.element(find.byType(Scaffold).first), tab);
      if (page != null) Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => placePage(page)!));
      await settle(t);
      await screens(t, name);
      debugDisableShadows = true;
    });
  }
}
