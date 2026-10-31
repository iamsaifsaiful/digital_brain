// A newer version on Google Play: the update page (owner, 31 Oct).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:digital_brain/screens/update_screen.dart';

import 'app_test.dart';

void main() {
  final calls = <String>[];
  Map<String, Object?> info = {};
  String startAnswer = 'cancelled';

  setUp(() {
    calls.clear();
    resetUpdateOffer();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(AppUpdate.channel, (c) async {
      calls.add(c.method);
      return c.method == 'check' ? info : startAnswer;
    });
  });

  testWidgets('a newer version: the page, update starts Play; "পরে" hides it for that version', (t) async {
    info = {'available': false};
    final rig = await start(t);
    info = {'available': true, 'inProgress': false, 'versionCode': 10007, 'staleDays': 0};
    calls.clear();
    resetUpdateOffer();
    offerUpdate(t.element(find.byType(Scaffold).first));
    await settle(t);
    expect(find.text('নতুন সংস্করণ এসেছে'), findsOneWidget);
    await t.tap(find.byKey(const Key('update-now')));
    await settle(t);
    expect(calls, ['check', 'start']);
    expect(find.text('আপডেট বাতিল হয়েছে। চাইলে আবার চাপুন।'), findsOneWidget);
    await t.tap(find.byKey(const Key('update-later')));
    await settle(t);
    expect(find.text('নতুন সংস্করণ এসেছে'), findsNothing);
    // Opened again the same day: not asked again for this version.
    resetUpdateOffer();
    await offerUpdate(t.element(find.byType(Scaffold).first));
    await settle(t);
    expect(find.text('নতুন সংস্করণ এসেছে'), findsNothing);
    // A still newer version is asked about.
    info = {'available': true, 'inProgress': false, 'versionCode': 10008, 'staleDays': 0};
    resetUpdateOffer();
    offerUpdate(t.element(find.byType(Scaffold).first));
    await settle(t);
    expect(find.text('নতুন সংস্করণ এসেছে'), findsOneWidget);
    expect(rig.brain, isNotNull);
  });

  testWidgets('no update (or not from Google Play): nothing shown', (t) async {
    info = {'available': false};
    await start(t);
    await settle(t);
    expect(calls, ['check']);
    expect(find.text('নতুন সংস্করণ এসেছে'), findsNothing);
  });
}
