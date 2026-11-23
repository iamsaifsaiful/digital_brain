// Owner, 22 Nov: "হোম পেইজে সকালে প্রশ্ন উঠবে, কত ঘন্টা ঘুমালেন? সারাদিন
// থাকবে না … রাতে প্রশ্ন করবে, আজ কত গ্লাস পানি খেলেন? এরপর এপ এইসব
// ট্র্যাক করবে।" Also: the স্বাস্থ্য page's members slide with the finger.
// SHOTS=1 flutter test test/ui/daily_ask_1122_test.dart --update-goldens
// writes test/ui/shots/daily_ask/.
import 'dart:io';

import 'package:digital_brain/logic/bn.dart';
import 'package:digital_brain/logic/daily_ask.dart';
import 'package:digital_brain/logic/proactive.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/health_hub.dart';
import 'package:digital_brain/screens/home_page.dart';
import 'package:digital_brain/state/brain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> _shot(WidgetTester t, String name) async {
  if (!shots) return;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/daily_ask/$name.png'));
}

void main() {
  setUp(() async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
  });

  testWidgets('morning sleep, night water, the week on স্বাস্থ্য', (t) async {
    final rig = await start(t);
    final brain = rig.brain;
    await brain.setUserName('সাইফুল');
    // Six earlier days of answers.
    const sleeps = [6.0, 7.0, 5.0, 7.0, 8.0, 6.0];
    const glasses = [5.0, 8.0, 6.0, 4.0, 8.0, 7.0];
    for (var i = 0; i < 6; i++) {
      final day = DateTime(2026, 11, 16 + i);
      await brain.addHealth(HealthLog(kind: HealthKind.sleep, at: day.add(const Duration(hours: 7)), a: sleeps[i]));
      await brain.addHealth(HealthLog(kind: HealthKind.water, at: day.add(const Duration(hours: 21)), a: glasses[i]));
    }
    await brain.saveTask(Task(title: 'বিদ্যুৎ বিল জমা দিতে হবে', due: DateTime(2026, 11, 22)));

    // Morning: the sleep question.
    rig.nowAt = DateTime(2026, 11, 22, 7, 40);
    brain.notifyListeners();
    await settle(t);
    expect(find.text('রাতে কত ঘণ্টা ঘুমালেন?'), findsOneWidget);
    expect(find.text('আজ কত গ্লাস পানি খেলেন?'), findsNothing);
    await _shot(t, '1-home-morning');

    // The morning notification carries the line and three buttons.
    final morning = assistantNotices(brain.data, DateTime(2026, 11, 22, 6), brain.assistantPrefs).firstWhere((n) => n.reminderId == morningTag);
    expect(morning.body, contains(sleepAskLine));
    expect(morning.asks.map((a) => a.$1), [askAction(DailyAsk.sleep, 6), askAction(DailyAsk.sleep, 7), askAction(DailyAsk.sleep, 8)]);

    await t.tap(find.byKey(const Key('ask-sleep-7')));
    await settle(t);
    expect(find.text('ঘুম ৭ ঘণ্টা — লেখা হলো'), findsOneWidget);
    expect(sleepLastNight(brain.data, brain.services.now())?.a, 7);
    await _shot(t, '2-home-answered');

    // Noon: gone, and not back the same day.
    rig.nowAt = DateTime(2026, 11, 22, 12, 5);
    await t.tap(find.text('দেখুন'));
    await settle(t);
    Navigator.of(t.element(find.byType(HealthScreen))).pop();
    await settle(t);
    expect(find.byKey(const Key('home-daily-ask')), findsNothing);

    // Night: the water question, with the day's +1 taps already counted.
    rig.nowAt = DateTime(2026, 11, 22, 21, 10);
    for (var i = 0; i < 3; i++) {
      await brain.addHealth(HealthLog(kind: HealthKind.water, at: DateTime(2026, 11, 22, 10 + i * 2), a: 1));
    }
    await settle(t);
    // The water notice: on its own night summary, or alone.
    final night = assistantNotices(brain.data, DateTime(2026, 11, 22, 20), brain.assistantPrefs).where((n) => n.asks.isNotEmpty && dayOnly(n.at) == DateTime(2026, 11, 22)).toList();
    expect(night.single.asks.first.$1, askAction(DailyAsk.water, 4));
    expect(find.text('আজ কত গ্লাস পানি খেলেন?'), findsOneWidget);
    await t.tap(find.byKey(const Key('ask-water-6')));
    await settle(t);
    await _shot(t, '3-home-night');
    await t.tap(find.byKey(const Key('ask-water-save')));
    await settle(t);
    expect(find.text('আজ ৬ গ্লাস পানি — লেখা হলো'), findsOneWidget);
    expect(brain.data.health.where((h) => h.kind == HealthKind.water && dayOnly(h.at) == DateTime(2026, 11, 22)).fold<double>(0, (a, h) => a + h.a), 6);
    // Answered: no water notice for tonight any more.
    expect(assistantNotices(brain.data, DateTime(2026, 11, 22, 20), brain.assistantPrefs).where((n) => n.asks.isNotEmpty && dayOnly(n.at) == DateTime(2026, 11, 22)), isEmpty);

    // স্বাস্থ্য: the week.
    Navigator.of(t.element(find.byType(HomePage))).push(MaterialPageRoute(builder: (_) => const HealthScreen()));
    await settle(t);
    expect(find.byKey(const Key('health-week')), findsOneWidget);
    await _shot(t, '4-health-week');
    await t.drag(find.byKey(const Key('health-week')), const Offset(0, -420));
    await settle(t);
    await _shot(t, '5-health-switches');
    debugDisableShadows = true;
  });

  testWidgets('three skips in a row: offers to stop; off stays off', (t) async {
    final rig = await start(t);
    final brain = rig.brain;
    for (var i = 0; i < 3; i++) {
      rig.nowAt = DateTime(2026, 11, 19 + i, 8);
      brain.notifyListeners();
      await settle(t);
      await t.tap(find.byKey(const Key('ask-skip-sleep')));
      await settle(t);
      expect(find.byKey(const Key('home-daily-ask')), findsNothing);
    }
    rig.nowAt = DateTime(2026, 11, 22, 8);
    brain.notifyListeners();
    await settle(t);
    expect(find.text('কয়েক দিন উত্তর দেননি — প্রশ্নটা বন্ধ রাখব?'), findsOneWidget);
    await _shot(t, '6-offer-off');
    await t.tap(find.byKey(const Key('ask-off-sleep')));
    await settle(t);
    expect(brain.askOn(DailyAsk.sleep), isFalse);
    rig.nowAt = DateTime(2026, 11, 23, 8);
    brain.notifyListeners();
    await settle(t);
    expect(find.byKey(const Key('home-daily-ask')), findsNothing);
    expect(assistantNotices(brain.data, DateTime(2026, 11, 23, 6), brain.assistantPrefs).firstWhere((n) => n.reminderId == morningTag).asks, isEmpty);
    debugDisableShadows = true;
  });

  testWidgets('স্বাস্থ্য: a member page follows the finger', (t) async {
    final rig = await start(t);
    final brain = rig.brain;
    rig.nowAt = DateTime(2026, 11, 22, 15);
    await brain.saveMember(FamilyMember(name: 'রহিমা', relation: 'মা', heightCm: 152));
    await settle(t);
    Navigator.of(t.element(find.byType(HomePage))).push(MaterialPageRoute(builder: (_) => const HealthScreen()));
    await settle(t);
    final g = await t.startGesture(t.getCenter(find.byType(PageView)));
    await g.moveBy(const Offset(-40, 0));
    await t.pump();
    await g.moveBy(const Offset(-200, 0));
    await t.pump();
    // Half way: both pages show.
    expect(find.text('রহিমা'), findsWidgets);
    await _shot(t, '7-swipe-half');
    await g.up();
    await settle(t, 20);
    final chip = t.widget<ChoiceChip>(find.ancestor(of: find.text('রহিমা (মা)'), matching: find.byType(ChoiceChip)));
    expect(chip.selected, isTrue);
    debugDisableShadows = true;
  });
}
