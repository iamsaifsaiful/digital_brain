// English mode (owner, 28 Oct): every page and tab builds in English with a
// full sample, on a small phone, without anything running out of its box
// (an overflow fails the test).
import 'dart:io';

import 'package:digital_brain/screens/app_places.dart';
import 'package:digital_brain/screens/family_screen.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/screens/requests_screen.dart';
import 'package:digital_brain/screens/zakat_screen.dart';
import 'package:digital_brain/screens/zakat_principles.dart';
import 'package:digital_brain/screens/pro_screen.dart';
import 'package:digital_brain/screens/cards_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'all_pages_shots_test.dart' show richer;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

void main() {
  final pages = <String, Widget Function()>{
    for (final id in ['tasks', 'alarms', 'calendar', 'special', 'notes', 'docs', 'vault', 'contacts', 'report', 'spending', 'accounts', 'savings', 'split', 'shop', 'health', 'medicines', 'habits', 'emergency', 'expiry', 'tags', 'memory', 'templates', 'search', 'settings', 'notifications', 'sound', 'backup', 'help', 'pro', 'compass'])
      id: () => placePage(id)!,
    'zakat': () => const ZakatScreen(),
    'zakat-rules': () => const ZakatPrinciplesScreen(),
    'family': () => const FamilyScreen(),
    'blood': () => const RequestsScreen(),
    'premium': () => const ProScreen(),
    'cards': () => const CardsScreen(),
    'card-new': () => const CardFormScreen(),
  };
  for (final size in [const Size(360, 740), const Size(320, 640)]) {
    for (final e in pages.entries) {
      testWidgets('English ${size.width.toInt()}: ${e.key}', (t) async {
        t.view.physicalSize = size * 3;
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        if (shots) await four.icons();
        final rig = await start(t);
        await rig.brain.setEnglish(true);
        rig.brain.data = richer(rig.brain.services.now());
        await settle(t);
        Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => e.value()));
        await settle(t);
        if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/en/${e.key}-${size.width.toInt()}.png'));
        // Every scrolled part, down to its end.
        for (final s in find.byType(Scrollable).evaluate().toList()) {
          if (!s.mounted) continue;
          final st = (s as StatefulElement).state as ScrollableState;
          if (st.position.maxScrollExtent > 0) {
            st.position.jumpTo(st.position.maxScrollExtent);
            await t.pump();
          }
        }
      });
    }
    for (final tab in ShellTab.values) {
      testWidgets('English ${size.width.toInt()}: tab ${tab.name}', (t) async {
        t.view.physicalSize = size * 3;
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        if (shots) await four.icons();
        final rig = await start(t);
        await rig.brain.setEnglish(true);
        rig.brain.data = richer(rig.brain.services.now());
        await settle(t);
        goToTab(t.element(find.byType(Scaffold).first), tab);
        await settle(t);
        if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/en/tab-${tab.name}-${size.width.toInt()}.png'));
      });
    }
  }
}
