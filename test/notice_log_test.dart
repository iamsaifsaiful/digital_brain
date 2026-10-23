import 'package:digital_brain/logic/notice_log.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/notice_screen.dart';
import 'package:digital_brain/services/notifications.dart';
import 'package:digital_brain/state/brain.dart' show BrainScope;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

PlannedNotice _p(String tag, DateTime at, {NoticeRepeat repeat = NoticeRepeat.none, bool gentle = false, bool early = false, Duration? every, String title = 'ওষুধ খান — নাপা'}) =>
    PlannedNotice(id: tag.hashCode, at: at, title: title, body: '', reminderId: tag, repeat: repeat, gentle: gentle, early: early, every: every);

void main() {
  final now = DateTime(2026, 10, 23, 13);

  test('the plan: a daily one for each of the 7 days, a one-time one once, an every-30-minutes one capped', () {
    final plan = expandPlan([
      _p('r1', DateTime(2026, 9, 1, 8), repeat: NoticeRepeat.daily),
      _p('r2', DateTime(2026, 10, 25, 10)),
      _p('r3', DateTime(2026, 10, 20, 10)), // gone by
      _p('w', DateTime(2026, 10, 23, 9), every: const Duration(minutes: 30)),
    ], now);
    expect(plan.where((e) => e.tag == 'r1').length, 7);
    expect(plan.where((e) => e.tag == 'r1').first.at, DateTime(2026, 10, 24, 8));
    expect(plan.where((e) => e.tag == 'r2').length, 1);
    expect(plan.where((e) => e.tag == 'r3'), isEmpty);
    final w = plan.where((e) => e.tag == 'w').toList();
    expect(w.length, 48);
    expect(w.first.at, DateTime(2026, 10, 23, 13, 30));
    expect([for (final e in plan) e.at], orderedEquals([...plan.map((e) => e.at)]..sort()));
  });

  test('what goes to the server: kind and time only — a reminder never carries its words', () {
    final plan = expandPlan([
      _p('r1', DateTime(2026, 10, 24, 8)),
      _p('r1', DateTime(2026, 10, 23, 20), early: true),
      _p('brief:morning:2026-10-24', DateTime(2026, 10, 24, 7), gentle: true, title: 'আজ ৩টা কাজ: রহিমকে ফোন'),
      _p('nudge:srv:5', DateTime(2026, 10, 24, 21), gentle: true, title: 'আজকের লিস্ট করেছেন?'),
      _p('nudge:Odd Tag!', DateTime(2026, 10, 24, 22), gentle: true),
    ], now);
    final sent = planForServer(plan);
    expect([for (final e in sent) e['kind']], ['reminder_early', 'brief:morning', 'reminder', 'server', 'assistant']);
    final text = '$sent';
    expect(text.contains('নাপা'), isFalse);
    expect(text.contains('রহিম'), isFalse);
    expect(sent.firstWhere((e) => e['kind'] == 'server')['title'], 'আজকের লিস্ট করেছেন?');
    expect(sent.first['at'], DateTime(2026, 10, 23, 20).toUtc().toIso8601String());
  });

  test('history: what came between two looks is kept once, newest first, 30 days', () {
    final plan = expandPlan([_p('r1', DateTime(2026, 9, 1, 14), repeat: NoticeRepeat.daily)], now);
    var h = addPassed([], plan, now, now.add(const Duration(days: 2, hours: 1)));
    expect([for (final e in h) e.at], [DateTime(2026, 10, 25, 14), DateTime(2026, 10, 24, 14), DateTime(2026, 10, 23, 14)]);
    h = addPassed(h, plan, now, now.add(const Duration(days: 2, hours: 1)));
    expect(h.length, 3, reason: 'not twice');
    h = addPassed(h, const [], null, now.add(const Duration(days: 40)));
    expect(h, isEmpty);
    final e = h.isEmpty ? plan.first : h.first;
    expect(NoticeEvent.fromJson(e.toJson())!.key, e.key);
  });

  testWidgets('নোটিফিকেশন page: what is coming, then what came', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.saveReminder(Reminder(id: 'r1', title: 'ওষুধ খাওয়া', date: DateTime(2026, 10, 9), hour: 16, repeat: Repeat.daily));
    expect(b.noticePlan.where((e) => e.tag == 'r1'), isNotEmpty);
    await t.pumpWidget(BrainScope(brain: b, child: const MaterialApp(home: NoticeScreen())));
    await settle(t);
    expect(find.text('ওষুধ খাওয়া'), findsWidgets);
    expect(find.textContaining('আসছে'), findsOneWidget);
    await t.tap(find.text('আগে এসেছে'));
    await settle(t);
    expect(find.text('এখনো কোনো নোটিফিকেশন আসেনি'), findsOneWidget);
  });
}
