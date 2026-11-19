// আমার ফাইল of 19 Nov (owner picked design খ, "চার ঘর"): four big squares,
// small buttons for the rest, one end-date line, then what was kept lately.
// With SHOTS=1 --update-goldens the screens go to test/ui/shots/store1119-*.png.
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'home_final_shots_test.dart' show icons, sample, shots;

void main() {
  for (final look in [Look.light, Look.dark]) {
    for (final en in [false, true]) {
      for (final width in [390.0, 360.0]) {
        final name = '${look.name}-${en ? 'en' : 'bn'}-${width.round()}';
        testWidgets('19 Nov My Files, $name', (t) async {
          if (shots) await icons();
          final rig = await start(t);
          t.view.physicalSize = Size(width * 3, 860 * 3);
          t.view.devicePixelRatio = 3;
          addTearDown(t.view.reset);
          rig.nowAt = DateTime(2026, 10, 24, 18, 34);
          await rig.brain.setLook(look);
          if (en) await rig.brain.setEnglish(true);
          rig.brain.data = sample(rig.nowAt);
          await settle(t);
          await t.tap(find.text(en ? 'My Files' : 'আমার ফাইল').last);
          await settle(t);
          for (final k in ['store-notes', 'store-vault', 'store-docs', 'store-contacts', 'store-special', 'store-health', 'store-tags', 'store-expiry']) {
            expect(find.byKey(Key(k)), findsOneWidget, reason: k);
          }
          // The passport in the sample runs out in 12 days.
          expect(find.textContaining(en ? 'expires in 12 days' : '১২ দিন পর শেষ'), findsOneWidget);
          if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/store1119-$name.png'));
          await t.tap(find.byKey(const Key('store-expiry')));
          await settle(t);
          expect(find.textContaining('পাসপোর্ট'), findsWidgets);
        });
      }
    }
  }
}
