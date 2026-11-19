// Owner, 19 Nov: "ইউজারের ইংরেজি ক্যালেন্ডার থাকবে, এবং সে চাইলে আরো একটি বা
// দুটি ক্যালেন্ডার যুক্ত করতে পারবে". The choice sheet, the calendar page and
// the Home date with the chosen calendars.
// SHOTS=1 flutter test test/ui/calendars_1119_test.dart --update-goldens
// writes test/ui/shots/calendars/.
import 'dart:io';

import 'package:digital_brain/screens/calendar_choice.dart';
import 'package:digital_brain/screens/calendar_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

/// The scripts of the other calendars (Arabic, Chinese …), from the machine's Noto fonts.
Future<void> _scripts() async {
  const dir = '/usr/share/fonts';
  final fonts = {
    'NotoNaskhArabic': '$dir/truetype/noto/NotoNaskhArabic-Regular.ttf',
    'NotoSansHebrew': '$dir/truetype/noto/NotoSansHebrew-Regular.ttf',
    'NotoSansCJK': '$dir/opentype/noto/NotoSansCJK-Regular.ttc',
    'NotoSansThai': '$dir/truetype/noto/NotoSansThai-Regular.ttf',
    'NotoSansDevanagari': '$dir/truetype/noto/NotoSansDevanagari-Regular.ttf',
    'NotoSansEthiopic': '$dir/truetype/noto/NotoSansEthiopic-Regular.ttf',
  };
  for (final e in fonts.entries) {
    final f = File(e.value);
    if (!f.existsSync()) continue;
    await (FontLoader(e.key)..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
  }
}

Future<void> _shot(WidgetTester t, String name) async {
  if (!shots) return;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/calendars/$name.png'));
}

/// Shadows back off before the test ends (the binding checks it).
void _done() => debugDisableShadows = true;

void main() {
  setUp(() async {
    if (shots) {
      await four.icons();
      await _scripts();
      debugDisableShadows = false;
    }
  });

  testWidgets('Bangla and Hijri stay by default; the calendar page and Home show them', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 19, 10, 5);
    await rig.brain.setUserName('সাইফুল');
    await settle(t);
    expect(rig.brain.calendars, ['bangla', 'hijri']);
    expect(find.textContaining('৪ অগ্রহায়ণ ১৪৩৩'), findsWidgets);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
    await settle(t);
    // On the ঋতুপঞ্জি page the chosen calendars stand under today's date (19 Nov).
    expect(find.text('৪ অগ্রহায়ণ ১৪৩৩ · হেমন্তকাল'), findsOneWidget);
    expect(find.byKey(const Key('cal-side-tabs')), findsOneWidget);
    await _shot(t, '1-page-bangla-hijri');
    _done();
  });

  testWidgets('the sheet: English always, at most two more, the first is the main one', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 19, 10, 5);
    await settle(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
    await settle(t);
    await t.tap(find.byKey(const Key('cal-choose')));
    await settle(t);
    expect(find.text('সবসময়'), findsOneWidget);
    expect(find.text('২/২ বাছাই'), findsOneWidget);
    // A third is refused until one is taken off.
    await t.tap(find.byKey(const Key('cal-choice-chinese')));
    await settle(t);
    expect(find.text('দুটির বেশি নয়। নতুনটি নিতে আগে একটি বাদ দিন।'), findsOneWidget);
    expect(rig.brain.calendars, ['bangla', 'hijri']);
    await t.tap(find.byKey(const Key('cal-choice-bangla')));
    await settle(t);
    await t.tap(find.byKey(const Key('cal-choice-chinese')));
    await settle(t);
    expect(rig.brain.calendars, ['hijri', 'chinese']);
    await _shot(t, '2-choose-sheet');
    await t.scrollUntilVisible(find.byKey(const Key('cal-choice-done')), 200, scrollable: find.descendant(of: find.byType(CalendarChoice), matching: find.byType(Scrollable)).first);
    await settle(t);
    await t.tap(find.byKey(const Key('cal-choice-done')));
    await settle(t);
    // Hijri first, then Chinese, under today's date; Chinese in the tabs too.
    expect(find.textContaining('১১ দশম মাস'), findsWidgets);
    expect(find.text('৪ অগ্রহায়ণ ১৪৩৩ · হেমন্তকাল'), findsNothing);
    await t.tap(find.text('চীনা চান্দ্র'));
    await settle(t);
    await _shot(t, '3-page-hijri-chinese');
    // Only English: no extra lines, no tabs.
    await rig.brain.setPref('calendars', 'none');
    await settle(t);
    expect(find.byKey(const Key('cal-side-tabs')), findsNothing);
    expect(find.text('বৃহস্পতিবার, ১৯ নভেম্বর ২০২৬'), findsOneWidget);
    _done();
  });

  testWidgets('Home: the chosen calendars beside the English date', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 19, 10, 5);
    await rig.brain.setUserName('সাইফুল');
    await rig.brain.setPref('calendars', 'bangla,chinese');
    await settle(t);
    expect(find.text('৪ অগ্রহায়ণ ১৪৩৩  •  ১১ দশম মাস, ঘোড়ার বছর'), findsOneWidget);
    await _shot(t, '4-home-bangla-chinese');
    await rig.brain.setPref('calendars', 'hebrew,persian');
    await settle(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
    await settle(t);
    await _shot(t, '5-page-hebrew-persian');
    await rig.brain.setPref('calendars', 'none');
    await settle(t);
    expect(find.byKey(const Key('home-extra-dates')), findsNothing);
    _done();
  });
}
