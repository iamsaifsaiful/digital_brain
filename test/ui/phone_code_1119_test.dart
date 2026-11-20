// The profile's mobile number (owner, 19 Nov): a country code is a must
// (Bangladesh +880 first), and no more digits than that country's mobile
// numbers have. SHOTS=1 --update-goldens writes test/ui/shots/phone_1119/*.png.
import 'dart:io';

import 'package:digital_brain/logic/phone_codes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_shots_test.dart' show rig0;
import '../app_test.dart' show settle, vScroll;

final shots = Platform.environment['SHOTS'] == '1';

void main() {
  test('numbers keep to their country', () {
    final bd = homeCountry;
    expect(bd.code, '+880');
    expect(phoneDigits(bd, '01712345678999'), '1712345678');
    expect(phoneDigits(bd, '+880 1712-345678'), '1712345678');
    expect(phoneDigits(bd, '০১৭১২৩৪৫৬৭৮'), '1712345678');
    expect(validPhone(bd, '1712345678'), isTrue);
    expect(validPhone(bd, '1212345678'), isFalse);
    expect(validPhone(bd, '171234567'), isFalse);
    final sa = phoneCountries.firstWhere((c) => c.iso == 'SA');
    expect(phoneDigits(sa, '0512345678999'), '512345678');
    expect(splitPhone('01712345678').$2, '1712345678');
    expect(splitPhone('+966512345678').$1.iso, 'SA');
    expect(splitPhone('+60123456789').$1.iso, 'MY');
    expect(fullPhone(bd, '1712345678'), '+8801712345678');
  });

  testWidgets('profile: mobile number with its country code', (t) async {
    final rig = await rig0(t);
    t.view.physicalSize = const Size(1170, 2532);
    await t.tap(find.text('আরও').last);
    await settle(t);
    final list = find.descendant(of: find.byType(Scaffold).last, matching: vScroll()).first;
    await t.scrollUntilVisible(find.byKey(const Key('more-profile')), -300, scrollable: list);
    await t.tap(find.byKey(const Key('more-profile')));
    await settle(t);
    Future<void> shot(String name) async {
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/phone_1119/$name.png'));
    }

    await t.tap(find.byKey(const Key('profile-phone')));
    await settle(t);
    expect(find.text('+৮৮০'), findsOneWidget);
    await shot('1-empty');
    await t.enterText(find.byKey(const Key('profile-phone-field')), '017123456789');
    await settle(t);
    expect(find.text('১০/১০'), findsOneWidget);
    await shot('2-full');
    await t.tap(find.byKey(const Key('profile-phone-country')));
    await settle(t);
    await shot('3-countries');
    await t.enterText(find.byKey(const Key('phone-country-search')), 'সৌদি');
    await settle(t);
    await t.tap(find.byKey(const Key('phone-country-SA')));
    await settle(t);
    await t.enterText(find.byKey(const Key('profile-phone-field')), '51234');
    await t.tap(find.byKey(const Key('profile-phone-save')));
    await settle(t);
    expect(find.textContaining('৯ অঙ্কের হয়'), findsOneWidget);
    await shot('4-saudi-short');
    await t.tap(find.byKey(const Key('profile-phone-country')));
    await settle(t);
    await t.tap(find.byKey(const Key('phone-country-BD')));
    await settle(t);
    await t.enterText(find.byKey(const Key('profile-phone-field')), '01712345678');
    await t.tap(find.byKey(const Key('profile-phone-save')));
    await settle(t);
    expect(rig.brain.userPhone, '+8801712345678');
    expect(find.text('+৮৮০ ১৭১২-৩৪৫৬৭৮'), findsOneWidget);
    await shot('5-saved');
    await rig.brain.setEnglish(true);
    await settle(t);
    await t.tap(find.byKey(const Key('profile-phone')));
    await settle(t);
    await shot('6-english');
    await rig.brain.setEnglish(false);
    debugDisableShadows = true;
  });
}
