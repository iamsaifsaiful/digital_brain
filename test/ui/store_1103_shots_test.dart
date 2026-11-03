// সংরক্ষণ of 3 Nov (owner approved the design): the three used most as big
// cards, the rest in one list. With SHOTS=1 --update-goldens the screens go
// to test/ui/shots/store1103-*.png.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'home_final_shots_test.dart' show icons, sample, shots;

void main() {
  for (final look in [Look.light, Look.dark]) {
    for (final width in [390.0, 360.0]) {
      testWidgets('3 Nov সংরক্ষণ, ${look.name}, $width', (t) async {
        if (shots) await icons();
        final rig = await start(t);
        t.view.physicalSize = Size(width * 3, 1100 * 3);
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        rig.nowAt = DateTime(2026, 10, 24, 18, 34);
        await rig.brain.setLook(look);
        rig.brain.data = sample(rig.nowAt);
        await settle(t);
        await t.tap(find.text('সংরক্ষণ').last);
        await settle(t);
        expect(find.byKey(const Key('store-notes')), findsOneWidget);
        // The passport in the sample runs out in 12 days.
        expect(find.textContaining('১২ দিন পর শেষ'), findsOneWidget);
        if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/store1103-${look.name}-${width.round()}.png'));
        await t.tap(find.byKey(const Key('store-expiry')));
        await settle(t);
        expect(find.textContaining('পাসপোর্ট'), findsWidgets);
        expect(rig.brain.data.docs.single, isA<Doc>());
      });
    }
  }
}
