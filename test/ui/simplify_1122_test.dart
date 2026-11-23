// Owner, 22 Nov: more of the sea on Home, simpler add forms, "শুক্র-শনি
// বাদে প্রতিদিন", habits/special days/ready lists picked from lists, and
// the diary as a PDF. SHOTS=1 flutter test test/ui/simplify_1122_test.dart
// --update-goldens writes test/ui/shots/s1122/.
import 'package:digital_brain/logic/home_scene.dart';
import 'package:digital_brain/logic/report.dart';
import 'package:digital_brain/logic/templates.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/brain.dart';
import 'package:digital_brain/screens/diary_screen.dart';
import 'package:digital_brain/screens/new_item_screen.dart';
import 'package:digital_brain/screens/lock_screen.dart' show lockScene;
import 'package:digital_brain/screens/onboarding_screen.dart';
import 'package:digital_brain/screens/plan_screens.dart';
import 'package:digital_brain/screens/special_days_screen.dart';
import 'package:digital_brain/screens/health_screens.dart';
import 'package:digital_brain/ui/scene_layers.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'home_final_shots_test.dart' show icons, sample, shots;

Future<void> _shot(WidgetTester t, String name) async {
  if (!shots) return;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/s1122/$name.png'));
}

void main() {
  for (final (name, at) in [('home-day', DateTime(2026, 11, 22, 11, 0)), ('home-night', DateTime(2026, 11, 22, 21, 0))]) {
    testWidgets('22 Nov home sea: $name', (t) async {
      if (shots) await icons();
      final rig = await start(t);
      t.view.physicalSize = const Size(390 * 3, 844 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      rig.nowAt = at;
      await rig.brain.setLook(Look.light);
      rig.brain.data = sample(rig.nowAt);
      await t.runAsync(() async {
        final ctx = t.element(find.byType(MaterialApp).first);
        for (final a in [sceneAsset('cox', night: false), sceneAsset('cox', night: true), 'assets/sky/boat_day.png', 'assets/sky/boat_night.png']) {
          await precacheImage(AssetImage(a), ctx);
        }
      });
      sceneLive = true;
      addTearDown(() => sceneLive = false);
      await t.pump();
      await t.pump(const Duration(seconds: 3));
      await _shot(t, name);
      sceneLive = false;
      await t.pumpWidget(const SizedBox());
      await settle(t);
    });
  }

  Future<void> push(WidgetTester t, Widget page) async {
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => page));
    await settle(t);
  }

  testWidgets('add sheet: every day but Friday and Saturday, in the afternoon', (t) async {
    if (shots) await icons();
    final rig = await start(t);
    showAddSheet(t.element(find.byType(Scaffold).first));
    await settle(t);
    await _shot(t, '1-add-task');
    await t.enterText(find.byType(TextField).last, 'ছাত্র পড়ানো');
    await t.tap(find.text('সময়মতো মনে করাবে'));
    await settle(t);
    await t.tap(find.text('প্রতিদিন'));
    await settle(t);
    await t.tap(find.byKey(Key('rem-day-${DateTime.friday}')));
    await settle(t);
    await t.tap(find.byKey(Key('rem-day-${DateTime.saturday}')));
    await settle(t);
    expect(find.text('শনি ও শুক্রবার বাদে প্রতিদিন'), findsOneWidget);
    await t.tap(find.text('বিকেল ৪টা'));
    await settle(t);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
    await _shot(t, '2-add-reminder-days');
    await t.ensureVisible(find.text('রাখুন'));
    await settle(t);
    await t.tap(find.text('রাখুন'));
    await settle(t);
    final r = rig.brain.data.reminders.single;
    expect(r.repeat, Repeat.weekly);
    expect(r.ringDays, {DateTime.saturday, DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday, DateTime.friday}.difference({DateTime.friday, DateTime.saturday}));
    expect(r.hour, 16);
  });

  testWidgets('the reminder form, simpler', (t) async {
    if (shots) await icons();
    await start(t);
    await push(t, const NewItemScreen(category: ItemCategory.reminder));
    await t.enterText(find.byType(TextFormField).first, 'ছাত্র পড়ানো');
    await t.tap(find.text('প্রতিদিন'));
    await settle(t);
    await t.tap(find.byKey(Key('rem-day-${DateTime.friday}')));
    await settle(t);
    await t.tap(find.byKey(Key('rem-day-${DateTime.saturday}')));
    await settle(t);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
    await _shot(t, '3-reminder-form');
    await t.tap(find.text('ওষুধ খাওয়া'));
    await settle(t);
    await _shot(t, '3b-reminder-form-medicine');
  });

  testWidgets('diary cards, habits, special days and ready lists picked from lists', (t) async {
    if (shots) await icons();
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 22, 10, 0);
    await rig.brain.saveSpecialDay(SpecialDay(person: 'আম্মা', month: 11, day: 25));
    await push(t, const Scaffold(body: SafeArea(child: DiaryScreen())));

    await t.tap(find.byKey(const Key('diary-pdf')));
    await settle(t);
    expect(find.byKey(const Key('diary-pdf-week')), findsOneWidget);
    await _shot(t, '9-diary-pdf');
    Navigator.of(t.element(find.byKey(const Key('diary-pdf-week')))).pop();
    await settle(t);
    await t.scrollUntilVisible(find.byKey(const Key('diary-templates')), 200, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).last);
    await settle(t);
    await _shot(t, '4-diary-cards');

    await push(t, const HabitsScreen());
    await t.tap(find.byKey(const Key('habit-add')));
    await settle(t);
    for (final h in ['সকালে ৩০ মিনিট হাঁটা', '২০ মিনিট বই পড়া', '৫ ওয়াক্ত নামাজ']) {
      await t.ensureVisible(find.byKey(Key('habit-idea-$h')));
      await t.tap(find.byKey(Key('habit-idea-$h')));
      await settle(t);
    }
    await t.drag(find.byType(ListView).last, const Offset(0, 600));
    await settle(t);
    await _shot(t, '5-habit-pick');
    await t.tap(find.byKey(const Key('habit-add-picked')));
    await settle(t);
    expect(rig.brain.data.habits.map((h) => h.name), containsAll(['সকালে ৩০ মিনিট হাঁটা', '২০ মিনিট বই পড়া', '৫ ওয়াক্ত নামাজ']));
    await _shot(t, '5b-habits');
    Navigator.of(t.element(find.byKey(const Key('habit-add')))).pop();
    await settle(t);

    await push(t, const SpecialDaysScreen());
    await t.tap(find.byKey(const Key('special-add')));
    await settle(t);
    await _shot(t, '6-special-pick');
    await t.tap(find.byKey(const Key('special-idea-আব্বার জন্মদিন')));
    await settle(t);
    expect(find.text('আব্বা'), findsOneWidget);
    await _shot(t, '6b-special-form');
    Navigator.of(t.element(find.text('আব্বা'))).pop();
    await settle(t);
    Navigator.of(t.element(find.byKey(const Key('special-add')))).pop();
    await settle(t);

    await push(t, const TemplatesScreen());
    await _shot(t, '7-templates');
    await t.tap(find.byKey(const Key('tpl-মাসের বাজার')));
    await settle(t);
    await t.tap(find.byKey(const Key('tpl-item-6')));
    await settle(t);
    await t.enterText(find.byKey(const Key('tpl-more')), 'বাচ্চার দুধ');
    await t.tap(find.byKey(const Key('tpl-more-add')));
    await settle(t);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
    await _shot(t, '8-template-preview');
    await t.tap(find.byKey(const Key('tpl-save')));
    await settle(t);
    final list = rig.brain.data.tasks.where((x) => x.list == 'মাসের বাজার').map((x) => x.title).toList();
    expect(list, contains('বাচ্চার দুধ'));
    expect(list, isNot(contains('ডিম')));
    expect(list.length, listTemplates.firstWhere((x) => x.name == 'মাসের বাজার').items.length);
  });

  test('the diary PDF: each day with its things and the habits', () {
    final now = DateTime(2026, 11, 22, 10);
    final d = AppData(
      tasks: [Task(title: 'বিদ্যুৎ বিল', due: DateTime(2026, 11, 22))],
      reminders: [Reminder(title: 'ছাত্র পড়ানো', date: DateTime(2026, 11, 1), hour: 16, repeat: Repeat.weekly, weekdays: const [7, 1, 2, 3, 4])],
      habits: [Habit(name: 'হাঁটা', done: ['2026-11-21', '2026-11-22'])],
    );
    final days = [for (var i = 0; i < 7; i++) DateTime(2026, 11, 21).add(Duration(days: i))];
    final spec = diarySpec(d, days, now, itemsOn: (x) => itemsOn(d, x, now));
    final all = '$spec';
    expect(spec['title'], 'দিনলিপি');
    expect(all, contains('বিদ্যুৎ বিল'));
    expect(all, contains('ছাত্র পড়ানো (শনি ও শুক্রবার বাদে প্রতিদিন)'));
    expect(all, contains('হাঁটা'));
    expect(diaryFileName(days.first, days.last), 'my-assistant-diary-20261121-20261127.pdf');
  });

  for (final (name, at) in [('day', DateTime(2026, 11, 23, 9, 0)), ('night', DateTime(2026, 11, 23, 21, 0))]) {
    testWidgets('23 Nov fingerprint unlock page, $name', (t) async {
      if (shots) await icons();
      final rig = await start(t);
      rig.nowAt = at;
      await rig.brain.setUserName('সাইফুল ইসলাম');
      rig.biometrics.has = true;
      await rig.services.lock.setBiometricsOn(true);
      rig.brain.lockNow();
      await settle(t);
      await t.runAsync(() async {
        final ctx = t.element(find.byKey(const Key('lock-app-mark')));
        await precacheImage(const AssetImage('assets/brand/app_mark.png'), ctx);
        await precacheImage(AssetImage(lockScene(at)), ctx);
      });
      await settle(t);
      expect(find.byKey(const Key('lock-choose-pin')), findsOneWidget);
      await _shot(t, 'login-4-fingerprint-$name');
    });
  }
}
