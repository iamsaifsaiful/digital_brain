import 'package:digital_brain/logic/calendar_bd.dart';
import 'package:digital_brain/logic/home_scene.dart';
import 'package:digital_brain/screens/home_picture_screen.dart';
import 'package:digital_brain/state/brain.dart';
import 'package:digital_brain/ui/scene_layers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show start;

/// Owner, 4 Nov: the home picture by season, region, the real moon, the
/// weather and the special days; the member's choice in আরও.
void main() {
  test('the season follows the Bangla calendar; a choice wins over auto', () {
    expect(seasonOf(DateTime(2026, 4, 20)), 'grishma'); // বৈশাখ
    expect(seasonOf(DateTime(2026, 7, 20)), 'borsha'); // আষাঢ়-শ্রাবণ
    expect(seasonOf(DateTime(2026, 9, 20)), 'shorot');
    expect(seasonOf(DateTime(2026, 11, 4)), 'hemonto');
    expect(seasonOf(DateTime(2027, 1, 10)), 'sheet');
    expect(seasonOf(DateTime(2027, 3, 1)), 'boshonto');
    expect(sceneFor('auto', DateTime(2026, 11, 4)), 'hemonto');
    // Nothing chosen: Cox's Bazar (owner, 7 Nov).
    expect(sceneFor('', DateTime(2026, 11, 4)), 'cox');
    expect(sceneFor('cox', DateTime(2026, 11, 4)), 'cox');
    expect(sceneAsset('cox', night: true), 'assets/sky/cox_night.webp');
  });

  test('special days, the moon, the weather', () {
    const plain = HijriDate(1448, 5, 2);
    expect(specialDayOf(DateTime(2027, 4, 14), plain), 'boishakh');
    expect(specialDayOf(DateTime(2027, 2, 21), plain), 'ekushey');
    expect(specialDayOf(DateTime(2027, 3, 26), plain), 'independence');
    expect(specialDayOf(DateTime(2026, 12, 16), plain), 'victory');
    expect(specialDayOf(DateTime(2027, 3, 10), const HijriDate(1448, 10, 1)), 'eid');
    expect(specialDayOf(DateTime(2026, 11, 4), plain), isNull);
    expect(moonOf(const HijriDate(1448, 5, 1)).lit, lessThan(0.05));
    expect(moonOf(const HijriDate(1448, 5, 15)).lit, greaterThan(0.95));
    expect(moonOf(const HijriDate(1448, 5, 7)).waxing, isTrue);
    expect(moonOf(const HijriDate(1448, 5, 22)).waxing, isFalse);
    expect(weatherKind(63), 'rain');
    expect(weatherKind(95), 'storm');
    expect(weatherKind(45), 'fog');
    expect(weatherKind(0), '');
  });

  test('every scene has its two paintings', () {
    for (final s in [...seasonKeys, ...regionKeys, 'river']) {
      for (final n in [false, true]) {
        expect(sceneAsset(s, night: n), startsWith('assets/sky/$s'));
      }
    }
  });

  testWidgets('আরও › হোমের ছবি: pick a place, turn the movement off; the home follows', (t) async {
    final rig = await start(t);
    final brain = rig.brain;
    expect(find.byKey(const Key('home-scene')), findsOneWidget);
    await t.pumpWidget(MaterialApp(home: BrainScope(brain: brain, child: const HomePictureScreen())));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byKey(const Key('scene-cox')));
    await t.tap(find.byKey(const Key('scene-cox')));
    await t.pumpAndSettle();
    expect(brain.text('home_scene'), 'cox');
    await t.ensureVisible(find.byKey(const Key('scene-scene_motion')));
    await t.tap(find.byKey(const Key('scene-scene_motion')));
    await t.pumpAndSettle();
    expect(brain.text('scene_motion'), 'off');
    expect(sceneLive, isFalse); // tests see a still frame
  });
}
