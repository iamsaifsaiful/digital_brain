// আরও of 3 Nov (owner approved the design): the settings as five rows,
// each opening its own page. With SHOTS=1 --update-goldens the screens go
// to test/ui/shots/more1103-*.png.
import 'package:digital_brain/services/notifications.dart' show AlarmHealth;
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'home_final_shots_test.dart' show icons, shots;

void main() {
  for (final look in [Look.light, Look.dark]) {
    testWidgets('3 Nov আরও, ${look.name}', (t) async {
      if (shots) await icons();
      final rig = await start(t);
      t.view.physicalSize = const Size(360 * 3, 1700 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await rig.brain.setLook(look);
      rig.notifier.state = const AlarmHealth(notificationsOn: true, exactOn: true, batteryFree: true, fullScreenOn: true, brand: '', hasAutostart: false);
      await settle(t);
      await t.tap(find.byTooltip('প্রোফাইল'));
      await settle(t);
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/more1103-main-${look.name}.png'));
      for (final k in ['look', 'remind', 'assistant', 'model', 'safety']) {
        await t.tap(find.byKey(Key('more-set-$k')));
        await settle(t);
        expect(find.byKey(Key('settings-$k')), findsOneWidget);
        if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/more1103-$k-${look.name}.png'));
        await t.tap(find.byTooltip('ফিরে যান').first);
        await settle(t);
      }
    });
  }
}
