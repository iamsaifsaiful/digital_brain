import 'package:digital_brain/state/brain.dart';
import 'package:digital_brain/screens/blood_details.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  testWidgets('a blood group needs a number and the last donation — or "মনে নেই" (owner, 28 Oct)', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    late Future<bool> asked;
    asked = askBloodDetails(t.element(find.byTooltip('বলুন')), 'B+');
    await settle(t);
    await t.tap(find.byKey(const Key('blood-save')));
    await settle(t);
    expect(find.textContaining('মোবাইল নম্বর দিন'), findsOneWidget);
    await t.enterText(find.byKey(const Key('blood-phone')), '০১৭১২৩৪৫৬৭৮');
    await t.tap(find.byKey(const Key('blood-save')));
    await settle(t);
    expect(find.textContaining('মনে নেই'), findsWidgets);
    await t.tap(find.byKey(const Key('blood-last-unknown')));
    await t.pump();
    await t.tap(find.byKey(const Key('blood-save')));
    await settle(t);
    expect(await asked, isTrue);
    expect((b.text('blood_phone'), b.flag('blood_last_unknown')), ('01712345678', true));
    // Not signed in: waits to go to our server.
    await b.saveEmergency(b.data.emergency.copyWith(blood: 'B+'));
    await settle(t);
    expect(b.bloodDetailsMissing, isFalse);
    expect(b.text('blood_sync'), 'pending');
  });
}
