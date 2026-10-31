// Screens for the website (website/img, owner 1 Nov: the site must show the
// app's current home). With SHOTS=1 --update-goldens they are written to
// test/ui/shots/site/*.png; website/shots.py makes the site's images from
// them. Without SHOTS the pages are only built.
import 'dart:io';

import 'package:digital_brain/services/notifications.dart' show AlarmHealth;
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start, openTyping, sendTyped, Rig;
import 'home_final_shots_test.dart' show icons, sample, shots;

Future<Rig> _ready(WidgetTester t, Look look) async {
  if (shots) {
    await icons();
    // The phone's own fallback font (arrows like "→" in the link chips); the
    // test has none, so an arrow showed as a box.
    final f = File('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf');
    if (f.existsSync()) {
      await (FontLoader('Roboto')..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
    }
    debugDisableShadows = false;
  }
  final rig = await start(t);
  // No first-run help on the pictures: the four steps are done, and the
  // "add your first …" card is closed below.
  await rig.services.lock.keys.write('tips_done', 'true');
  rig.nowAt = look == Look.light ? DateTime(2026, 10, 24, 10, 20) : DateTime(2026, 10, 24, 18, 34);
  await rig.brain.setLook(look);
  await rig.brain.setUserName('সাইফুল ইসলাম');
  rig.brain.gated = true;
  await rig.brain.setProForTest(true);
  // Every alarm setting right: no warning card on the home in a picture.
  rig.notifier.state = const AlarmHealth(notificationsOn: true, exactOn: true, batteryFree: true, fullScreenOn: true, brand: '', hasAutostart: false);
  rig.brain.data = sample(rig.nowAt);
  await rig.brain.setPref('home_tools_open', true);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await settle(t);
  // Pictures (the sky) are decoded for real before a shot.
  await t.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await settle(t);
  final close = find.descendant(of: find.byKey(const Key('add-nudge')), matching: find.byIcon(Icons.close_rounded));
  if (close.evaluate().isNotEmpty) {
    await t.tap(close.first);
    await settle(t);
  }
  return rig;
}

void main() {
  for (final look in [Look.light, Look.dark]) {
    testWidgets('site ${look.name}: home', (t) async {
      await _ready(t, look);
      expect(find.byKey(const Key('home-alarm-health')), findsNothing);
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/site/home_${look.name}.png'));
      debugDisableShadows = true;
    });

    testWidgets('site ${look.name}: money', (t) async {
      await _ready(t, look);
      await t.tap(find.text('হিসাব').last);
      await settle(t);
      await t.tap(find.text('মাসিক').first);
      await settle(t);
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/site/report_${look.name}.png'));
      debugDisableShadows = true;
    });

    testWidgets('site ${look.name}: chat', (t) async {
      await _ready(t, look);
      await openTyping(t);
      await t.enterText(find.byType(TextField).first, 'কাল সকাল ৯টায় ব্যাংকে যেতে হবে');
      await sendTyped(t);
      await settle(t);
      await t.enterText(find.byType(TextField).first, 'এই মাসে বাজারে কত খরচ হলো?');
      await sendTyped(t);
      await settle(t);
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/site/chat_${look.name}.png'));
      debugDisableShadows = true;
    });
  }
}
