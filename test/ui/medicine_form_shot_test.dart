// The medicine form (25 Oct): SHOTS=1 --update-goldens writes
// test/ui/shots/all/medicine-form-<look>.png (gitignored).
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/health_screens.dart' show MedicinesScreen;
import 'package:digital_brain/state/brain.dart' show BrainHealth;
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

void main() {
  for (final look in [Look.light, Look.dark]) {
    testWidgets('medicine form ${look.name}', (t) async {
      if (shots) {
        await four.icons();
        debugDisableShadows = false;
      }
      final rig = await start(t);
      await rig.brain.setLook(look);
      await rig.brain.saveMember(FamilyMember(id: 'amma', name: 'আম্মা'));
      await rig.brain.saveMember(FamilyMember(id: 'abba', name: 'আব্বা'));
      Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const MedicinesScreen()));
      await settle(t);
      await t.tap(find.text('ওষুধ যোগ'));
      await settle(t);
      await t.tap(find.byKey(const Key('med-per-3')));
      await t.tap(find.byKey(const Key('med-who-amma')));
      await settle(t);
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/all/medicine-form-${look.name}.png'));
      debugDisableShadows = true;
    });
  }
}
