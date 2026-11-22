// Owner, 22 Nov: "যোগাযোগ মেনুর ইউআই সুন্দর করতে হবে". Three looks for
// the owner to pick from (CallsScreen.look 1 ফোনবুক, 2 কার্ড, 3 গ্রিড), and
// a tap on a person opens their card. With SHOTS=1 --update-goldens the
// screens go to test/ui/shots/contacts1122/.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/calls_screen.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'home_final_shots_test.dart' show icons, sample, shots;

// Made-up numbers only.
final people = [
  Contact(name: 'আম্মা', phone: '01700000001'),
  Contact(name: 'আব্বু', phone: '01700000002'),
  Contact(name: 'করিম মিস্ত্রি', phone: '01800000003', note: 'ইলেকট্রিশিয়ান'),
  Contact(name: 'ডা. নাসরিন', phone: '01900000004', note: 'শিশু ডাক্তার', address: 'ধানমন্ডি ২৭, ঢাকা'),
  Contact(name: 'তানভীর', phone: '01600000005', note: 'অফিস'),
  Contact(name: 'নাদিয়া আপু', phone: '01500000006'),
  Contact(name: 'রহিম ভাই', phone: '01300000007', note: 'বাড়িওয়ালা'),
  Contact(name: 'সজীব', phone: '01400000008', email: 'sajib@example.com'),
  Contact(name: 'Rafiq (Dubai)', phone: '+971500000009', note: 'Office'),
];

void main() {
  for (final look in [1, 2, 3]) {
    for (final mode in [Look.light, Look.dark]) {
      testWidgets('22 Nov contacts, look $look ${mode.name}', (t) async {
        if (shots) await icons();
        CallsScreen.look = look;
        final rig = await start(t);
        t.view.physicalSize = const Size(390 * 3, 844 * 3);
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        await rig.brain.setLook(mode);
        final d = sample(rig.nowAt);
        d.contacts
          ..clear()
          ..addAll(people);
        rig.brain.data = d;
        await settle(t);
        await t.tap(find.text('আমার ফাইল').last);
        await settle(t);
        await t.tap(find.byKey(const Key('store-contacts')));
        await settle(t);
        expect(find.text('করিম মিস্ত্রি'), findsOneWidget);
        if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/contacts1122/$look-${mode.name}.png'));
        if (look == 1 && mode == Look.light || look == 2 && mode == Look.dark) {
          await t.tap(find.text('ডা. নাসরিন'));
          await settle(t);
          expect(find.byKey(const Key('contact-card')), findsOneWidget);
          expect(find.text('এডিট করুন'), findsOneWidget);
          if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/contacts1122/card-${mode.name}.png'));
        }
      });
    }
  }
}
