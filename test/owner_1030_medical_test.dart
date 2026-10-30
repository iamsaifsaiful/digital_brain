// Owner, 30 Oct: Google Play rejected the app — medical apps need an
// organization account. The Play app leaves out medicines, blood pressure,
// sugar, vaccines, check-ups, the doctor's summary and the emergency card
// (pro.dart medicalOff); fitness stays. The downloaded APK keeps everything.
import 'package:digital_brain/logic/app_map.dart';
import 'package:digital_brain/logic/pro.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/app_places.dart';
import 'package:digital_brain/state/family_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start, tell;

void main() {
  tearDown(() => medicalOffForTests = false);

  test('the APK keeps the medical pages', () {
    expect(medicalOff, isFalse);
    expect(appPlaces.map((p) => p.id), containsAll(['medicines', 'emergency']));
    expect(placePage('medicines'), isNotNull);
    expect(familyPerms, contains('medicine'));
  });

  test('the Play app: no medicine or emergency page, no medicine sending in Family', () {
    medicalOffForTests = true;
    expect(appPlaces.map((p) => p.id), isNot(contains('medicines')));
    expect(appPlaces.map((p) => p.id), isNot(contains('emergency')));
    expect(placePage('medicines'), isNull);
    expect(placePage('emergency'), isNull);
    expect(placePage('health'), isNotNull);
    expect(familyPerms, isNot(contains('medicine')));
    final health = appPlaces.firstWhere((p) => p.id == 'health');
    expect(health.what, isNot(contains('প্রেশার')));
    expect(appMapForAi(), isNot(contains('ওষুধ')));
    expect(freeList, isNot(contains('ওষুধ')));
    expect(freeList, isNot(contains('টিকা')));
    for (final i in proInfo.values) {
      expect('${i.what} ${i.free}', isNot(matches(RegExp('ওষুধ|প্রেশার|সুগার|টিকা'))));
    }
  });

  testWidgets('the Play app: blood pressure and sugar by voice are not kept; weight is', (t) async {
    medicalOffForTests = true;
    final rig = await start(t);
    final b = rig.brain;
    await settle(t);
    await t.tap(find.byTooltip('বলুন').first);
    await settle(t);
    await tell(t, rig, 'আমার প্রেশার ১২০ বাই ৮০');
    await settle(t);
    expect(b.data.health.where((h) => h.kind == HealthKind.bp), isEmpty);
    expect(find.textContaining('Google Play-র এই অ্যাপে নেই'), findsWidgets);
    await tell(t, rig, 'আজ ওজন ৬৫ কেজি');
    await settle(t);
    expect(b.data.health.where((h) => h.kind == HealthKind.weight).map((h) => h.a), [65]);
  });

  testWidgets('the Play app: the health page has no blood pressure, sugar, vaccines or medicines', (t) async {
    medicalOffForTests = true;
    final rig = await start(t);
    await settle(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => placePage('health')!));
    await settle(t);
    expect(find.text('ওজন'), findsWidgets);
    expect(find.text('প্রেশার'), findsNothing);
    expect(find.text('সুগার'), findsNothing);
    expect(find.byKey(const Key('health-medicines')), findsNothing);
    expect(find.text('ডাক্তারকে দেখানোর সারাংশ'), findsNothing);
    expect(find.byTooltip('ডাক্তারকে দেখান'), findsNothing);
    expect(rig.brain.data.medicines, isEmpty);
  });
}
