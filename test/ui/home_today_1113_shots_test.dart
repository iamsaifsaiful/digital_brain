// Owner, 13 Nov: "হোমের আজকের কাজ সেকশনের ইউআই ফিক্স করে আমাকে ছবি দেখাও".
// SHOTS=1 STAGE=before|after --update-goldens writes test/ui/shots/hometoday/.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/logic/pro.dart' show medicalOffForTests;
import 'package:digital_brain/screens/home_screen.dart' show TodaySections;
import 'package:digital_brain/screens/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'all_pages_shots_test.dart' show richer;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';
final stage = Platform.environment['STAGE'] ?? 'after';

void main() {
  testWidgets('home today', (t) async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
    final rig = await start(t);
    t.view.physicalSize = const Size(1170, 4200);
    final now = rig.brain.services.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = richer(now);
    d.tasks.addAll([
      Task(title: 'গ্যাস বিল দেওয়া', due: today.subtract(const Duration(days: 2))),
      Task(title: 'রফিক ভাইকে ফোন', due: today),
    ]);
    d.reminders.addAll([
      Reminder(title: 'ডাক্তারের অ্যাপয়েন্টমেন্ট', date: today, hour: now.hour + 1 > 23 ? 23 : now.hour + 1, minute: 30),
      Reminder(title: 'নাপা খাওয়ার সময়', date: today, hour: 21, repeat: Repeat.daily),
      Reminder(title: 'স্কুলের ফি', date: today.add(const Duration(days: 1)), hour: 10),
    ]);
    rig.brain.data = d;
    medicalOffForTests = true;
    await rig.brain.setUserName('সাইফুল');
    await settle(t);
    final ctx = t.element(find.byType(Scaffold).first);
    goToTab(ctx, ShellTab.money);
    await settle(t);
    goToTab(ctx, ShellTab.home);
    await settle(t);
    final f = find.byType(TodaySections);
    await t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
    await settle(t);
    if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/hometoday/$stage/home.png'));
    medicalOffForTests = false;
    debugDisableShadows = true;
  });
}
