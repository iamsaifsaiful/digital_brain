// আরও › the phone's understanding model and the messages sent (owner, 2 Nov).
import 'package:digital_brain/screens/nlu_model_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart';

void main() {
  testWidgets('the model page: why, how, what got better in this version, how to help', (t) async {
    final rig = await start(t);
    rig.brain
      ..nluModelState = 'ready'
      ..nluModelVersion = 'r20261030-14';
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute<void>(builder: (_) => const NluModelScreen()));
    await settle(t);
    expect(find.text('এই ফোনে চলছে · সংস্করণ r20261030-14'), findsOneWidget);
    expect(find.text('কেন নিজের মডেল'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('nlu-notes')), 300);
    expect(find.text('৭৬.১%'), findsOneWidget);
    expect(find.text('৯৩.৫%'), findsOneWidget);
    expect(find.text('১০০%'), findsWidgets);
  });

  testWidgets('messages sent: what, what never, why; delete removes them and stops sending', (t) async {
    final rig = await start(t);
    expect(rig.brain.nluSamplesOn, isTrue);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute<void>(builder: (_) => const NluSamplesScreen()));
    await settle(t);
    expect(find.text('কী কখনো নিই না'), findsOneWidget);
    expect(find.text('স্বাস্থ্য, ওষুধ, ভল্ট বা কন্টাক্টের কথা'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const Key('nlu-samples-delete')), 300);
    await t.tap(find.byKey(const Key('nlu-samples-delete')));
    await settle(t);
    await t.tap(find.text('মুছে দিন').last);
    await settle(t);
    expect(rig.brain.nluSamplesOn, isFalse);
    await t.scrollUntilVisible(find.text('এখন পাঠানো বন্ধ আছে।'), -300);
    expect(find.text('এখন পাঠানো বন্ধ আছে।'), findsOneWidget);
  });
}
