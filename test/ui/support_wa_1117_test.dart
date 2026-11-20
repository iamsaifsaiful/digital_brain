// Support on WhatsApp (owner, 17 Nov): the number is set on the website and
// comes with the notices; no number, no button. SHOTS=1 --update-goldens
// writes test/ui/shots/support_wa_1117/*.png (WA=<number> shows a real one).
import 'dart:io';

import 'package:digital_brain/screens/more_screen.dart' show MoreScreen, SupportWhatsapp;
import 'package:digital_brain/services/launcher.dart' show FakeLauncher;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_shots_test.dart' show rig0;
import '../app_test.dart' show settle, vScroll;

final shots = Platform.environment['SHOTS'] == '1';
final number = Platform.environment['WA'] ?? '01700000000';

void main() {
  testWidgets('আরও: হোয়াটসঅ্যাপে কথা বলুন opens our number with a greeting', (t) async {
    final rig = await rig0(t);
    await t.tap(find.text('আরও').last);
    await settle(t);
    expect(find.byKey(const Key('more-whatsapp')), findsNothing);
    rig.brain.supportWhatsapp = number;
    rig.brain.setUserName('সাইফুল ইসলাম');
    await settle(t);
    final card = find.byKey(const Key('more-whatsapp'), skipOffstage: false);
    await t.scrollUntilVisible(card, 200, scrollable: find.descendant(of: find.byType(MoreScreen), matching: vScroll()).first);
    await t.ensureVisible(card);
    await settle(t);
    expect(find.text('হোয়াটসঅ্যাপে কথা বলুন'), findsOneWidget);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/support_wa_1117/more.png'));
    await t.tap(card);
    await settle(t);
    final u = (rig.brain.services.launcher as FakeLauncher).opened.last.toString();
    expect(u, startsWith('https://wa.me/88${number.substring(0, 11)}?text='));
    expect(Uri.decodeComponent(u), contains('My Assistant অ্যাপ নিয়ে জানতে চাই'));
    expect(SupportWhatsapp.shown('8801712345678'), '০১৭১২-৩৪৫৬৭৮');
    debugDisableShadows = true;
  });
}
