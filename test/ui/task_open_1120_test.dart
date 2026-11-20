// Owner, 20 Nov: "হোমের আজকের কাজের লিস্টে যে কাজে ক্লিক করলে সেটা ওপেন হবে,
// ইউজার চাইলে ইডিট করতে পারবে". A tap opens the whole thing in a sheet;
// "এডিট করুন" opens the edit form.
// SHOTS=1 flutter test test/ui/task_open_1120_test.dart --update-goldens
// writes test/ui/shots/task_open/.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> _shot(WidgetTester t, String name) async {
  if (!shots) return;
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/task_open/$name.png'));
}

void _done() => debugDisableShadows = true;

void main() {
  setUp(() async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
  });

  testWidgets('a tap on a to-do opens it; edit changes it', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 20, 10, 5);
    await rig.brain.setUserName('সাইফুল');
    final today = DateTime(2026, 11, 20);
    await rig.brain.saveTask(Task(title: 'বিদ্যুৎ বিল জমা দিতে হবে', due: today));
    await rig.brain.saveTask(Task(title: 'ব্যাংকে চেক জমা দেওয়া', due: today, urgent: true, list: 'অফিস', note: 'চেকের পেছনে সই করে নিতে হবে, আর জাতীয় পরিচয়পত্রের ফটোকপি সাথে রাখতে হবে।'));
    await rig.brain.saveReminder(Reminder(title: 'আম্মাকে ফোন করা', date: today, hour: 17, minute: 30));
    await settle(t);
    await _shot(t, '1-home');

    await t.tap(find.text('ব্যাংকে চেক জমা দেওয়া'));
    await settle(t);
    expect(find.text('এডিট করুন'), findsOneWidget);
    expect(find.textContaining('জাতীয় পরিচয়পত্রের ফটোকপি'), findsWidgets);
    await _shot(t, '2-task-open');

    await t.tap(find.text('এডিট করুন'));
    await settle(t);
    expect(find.text('নোট (চাইলে)'), findsOneWidget);
    await t.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first, 'ব্যাংকে দুটো চেক জমা দেওয়া');
    await settle(t);
    await _shot(t, '3-edit');
    await t.tap(find.text('রাখুন'));
    await settle(t);
    expect(rig.brain.data.tasks.any((x) => x.title == 'ব্যাংকে দুটো চেক জমা দেওয়া' && x.note.contains('সই')), isTrue);

    await t.tap(find.text('আম্মাকে ফোন করা'));
    await settle(t);
    expect(find.text('এডিট করুন'), findsOneWidget);
    await _shot(t, '4-reminder-open');
    _done();
  });
}
