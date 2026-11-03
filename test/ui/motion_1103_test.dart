// The small movements of 3 Nov: a button sinks and springs back, a money
// figure rolls to its new amount, a tick is drawn. With SHOTS=1
// --update-goldens frames go to test/ui/shots/motion/*.png.
import 'dart:io';

import 'package:digital_brain/ui/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final shots = Platform.environment['SHOTS'] == '1';

void main() {
  testWidgets('a button sinks under the finger and springs back', (t) async {
    await t.pumpWidget(MaterialApp(home: Center(child: Pressable(child: SizedBox(key: const Key('b'), width: 100, height: 40, child: ElevatedButton(onPressed: () {}, child: const Text('ok')))))));
    double scale() => t.widget<Transform>(find.descendant(of: find.byType(Pressable), matching: find.byType(Transform)).first).transform.entry(0, 0);
    final g = await t.startGesture(t.getCenter(find.byKey(const Key('b'))));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
    expect(scale(), closeTo(0.95, 0.005));
    await g.up();
    await t.pumpAndSettle();
    expect(scale(), closeTo(1, 0.001));
  });

  testWidgets('a figure rolls to its new amount, and shows it at once the first time', (t) async {
    Widget at(int v) => MaterialApp(home: Center(child: RollingAmount(value: v, format: (x) => '$x', style: const TextStyle())));
    await t.pumpWidget(at(100));
    expect(find.text('100'), findsOneWidget);
    await t.pumpWidget(at(200));
    await t.pump(const Duration(milliseconds: 150));
    final mid = int.parse(t.widget<Text>(find.byType(Text)).data!);
    expect(mid, inExclusiveRange(100, 200));
    await t.pumpAndSettle();
    expect(find.text('200'), findsOneWidget);
  });

  testWidgets('a tick is drawn when done', (t) async {
    var done = false;
    late StateSetter set;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: StatefulBuilder(builder: (c, s) {
            set = s;
            return RepaintBoundary(child: SizedBox(width: 120, height: 120, child: Center(child: DrawnTick(done: done, size: 96, color: const Color(0xFFC2570C), tickColor: Colors.white, borderColor: const Color(0xFFD3DED9)))));
          }),
        ),
      ),
    ));
    set(() => done = true);
    for (var ms = 0; ms <= 480; ms += 40) {
      await t.pump(const Duration(milliseconds: 40));
      if (shots) await expectLater(find.byType(RepaintBoundary).last, matchesGoldenFile('shots/motion/tick${ms.toString().padLeft(3, '0')}.png'));
    }
    await t.pumpAndSettle();
  });
}
