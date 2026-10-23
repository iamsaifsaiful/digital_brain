import 'package:digital_brain/logic/pro.dart';
import 'package:digital_brain/screens/settings_parts.dart' show PlanBadge;
import 'package:digital_brain/state/brain.dart' show BrainScope;
import 'package:digital_brain/ui/theme.dart' show buildTheme;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  testWidgets('profile: ফ্রি, then প্রো with a notification that it came on', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    b.gated = true;
    await t.pumpWidget(BrainScope(brain: b, child: MaterialApp(theme: buildTheme(), home: const Scaffold(body: PlanBadge()))));
    await settle(t);
    expect(find.text('ফ্রি'), findsOneWidget);
    await b.activatePro(proPlans.first);
    await settle(t);
    expect(find.text('প্রো'), findsOneWidget);
    final on = b.noticePlan.where((e) => e.tag == 'nudge:pro').toList();
    expect(on, hasLength(1), reason: 'planned, and on the নোটিফিকেশন page too');
    expect(on.single.title, contains('প্রো চালু'));
  });
}
