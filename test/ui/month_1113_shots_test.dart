// Owner, 13 Nov: other ways to lay out দিনলিপি's month. SHOTS=1
// --update-goldens writes test/ui/shots/month/ (gitignored).
import 'dart:io';

import 'package:digital_brain/screens/diary_screen.dart' show diaryMonthStyle;
import 'package:digital_brain/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'all_pages_shots_test.dart' show richer;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

void main() {
  for (final style in [1, 2, 3]) {
    testWidgets('month: look $style', (t) async {
      diaryMonthStyle = style;
      if (shots) {
        await four.icons();
        debugDisableShadows = false;
      }
      final rig = await start(t);
      rig.brain.data = richer(rig.brain.services.now());
      await settle(t);
      goToTab(t.element(find.byType(Scaffold).first), ShellTab.diary);
      await settle(t);
      await t.tap(find.text('মাসিক').first);
      await settle(t);
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/month/$style.png'));
      diaryMonthStyle = 1;
      debugDisableShadows = true;
    });
  }
}
