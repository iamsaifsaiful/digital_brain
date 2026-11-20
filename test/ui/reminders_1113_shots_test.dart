// Owner, 13 Nov: "রিমাইন্ডার মেনুর ইউআই ফিক্স কর". SHOTS=1
// STAGE=before|after --update-goldens writes test/ui/shots/reminders/.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/new_item_screen.dart';
import 'package:digital_brain/screens/plan_screens.dart' show AllTasksScreen;
import 'package:digital_brain/screens/reminders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'all_pages_shots_test.dart' show richer;
import 'new_ui_shots_test.dart' as four show icons;

final shots = Platform.environment['SHOTS'] == '1';
final stage = Platform.environment['STAGE'] ?? 'after';

void main() {
  testWidgets('reminder pages', (t) async {
    if (shots) {
      await four.icons();
      debugDisableShadows = false;
    }
    final rig = await start(t);
    t.view.physicalSize = const Size(1170, 3600);
    final now = rig.brain.services.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = richer(now);
    d.reminders.addAll([
      Reminder(title: 'বিদ্যুৎ বিল', date: today.add(const Duration(days: 4)), hour: 10, repeat: Repeat.monthly, daysBefore: 1),
      Reminder(title: 'ডাক্তারের অ্যাপয়েন্টমেন্ট', date: today.add(const Duration(days: 1)), hour: 17, minute: 30, note: 'রিপোর্ট সাথে নেবেন'),
      Reminder(title: 'নাপা খাওয়ার সময়', date: today, hour: 21, repeat: Repeat.daily),
      Reminder(title: 'পাসপোর্টের মেয়াদ শেষ', date: today.add(const Duration(days: 60)), hour: 9),
      Reminder(title: 'গ্যাস বিল', date: today.subtract(const Duration(days: 3)), hour: 10, enabled: false),
      Reminder(title: 'পানি খাওয়া', date: today, hour: 9, repeat: Repeat.every2h),
      Reminder(title: 'হাঁটতে যাওয়া', date: today, hour: 6, minute: 30, repeat: Repeat.daily, enabled: false),
      Reminder(title: 'বাবার জন্মদিন', date: today.add(const Duration(days: 40)), hour: 9, repeat: Repeat.yearly),
      Reminder(title: 'জুম্মার নামাজ', date: today, hour: 13, repeat: Repeat.weekly, weekdays: const [DateTime.friday]),
    ]);
    rig.brain.data = d;
    await settle(t);
    final ctx = t.element(find.byType(Scaffold).first);
    Future<void> shot(String name) async {
      if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/reminders/$stage/$name.png'));
    }

    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const AllTasksScreen()));
    await settle(t);
    await shot('list-open');
    await t.tap(find.textContaining('বারবার').first);
    await settle(t);
    await shot('list-repeating');
    await t.tap(find.textContaining('শেষ ও পার').first);
    await settle(t);
    await shot('list-done');
    Navigator.of(ctx).pop();
    await settle(t);
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const RemindersScreen()));
    await settle(t);
    await shot('dates');
    Navigator.of(ctx).pop();
    await settle(t);
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.reminder)));
    await settle(t);
    await shot('form');
    debugDisableShadows = true;
  });
}
