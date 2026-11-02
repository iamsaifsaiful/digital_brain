// The opening on every cold start (owner, 2 Nov), then the PIN page or home.
import 'package:digital_brain/ui/splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui/home_final_shots_test.dart' show icons, shots;

void main() {
  testWidgets('plays about 1.8 s, then says it is done', (t) async {
    await icons();
    var done = false;
    await t.runAsync(() async {
      await t.pumpWidget(MaterialApp(home: Splash(onDone: () => done = true)));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await t.pump();
    await t.pump(const Duration(milliseconds: 700));
    expect(done, isFalse);
    expect(find.text('My Assistant'), findsOneWidget);
    if (shots) await expectLater(find.byKey(const Key('splash')), matchesGoldenFile('ui/shots/splash-mid.png'));
    await t.pump(const Duration(milliseconds: 1300));
    // The callback was set up outside the test's clock (the mark's decoding): let it run.
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(done, isTrue);
    if (shots) await expectLater(find.byKey(const Key('splash')), matchesGoldenFile('ui/shots/splash-end.png'));
  });

  test('skipped under flutter test, so the app starts at once in every other test', () {
    expect(splashOn, isFalse);
  });
}
