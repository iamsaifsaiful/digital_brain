import 'package:digital_brain/logic/proactive.dart';
import 'package:digital_brain/logic/repeat_text.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/new_item_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

Reminder w(List<int> days) => Reminder(title: 'x', date: DateTime(2026, 10, 31), repeat: Repeat.weekly, weekdays: days);

void main() {
  test('how often, said plainly (owner, 28 Oct)', () {
    expect(repeatText(w([DateTime.saturday])), 'প্রতি শনিবার');
    expect(repeatText(w([DateTime.saturday, DateTime.tuesday])), 'প্রতি শনি ও মঙ্গলবার');
    expect(repeatText(w([for (final d in weekOrder) if (d != DateTime.friday) d])), 'শুক্রবার বাদে প্রতিদিন');
    expect(repeatText(w([for (final d in weekOrder) if (d != DateTime.friday && d != DateTime.saturday) d])), 'শনি ও শুক্রবার বাদে প্রতিদিন');
    expect(repeatText(Reminder(title: 'x', date: DateTime(2026), repeat: Repeat.monthly)), 'প্রতি মাসে');
  });

  testWidgets('the form: every Saturday', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    Future<Reminder> make(String title, Future<void> Function() pick) async {
      Navigator.of(t.element(find.byTooltip('বলুন'))).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.reminder)));
      await settle(t);
      await t.enterText(find.byType(TextFormField).first, title);
      await t.scrollUntilVisible(find.textContaining('কতবার'), 200, scrollable: find.byType(Scrollable).last);
      await t.tap(find.textContaining('কতবার'));
      await settle(t);
      await pick();
      await t.tap(find.text('সেভ করুন').last);
      await settle(t);
      return b.data.reminders.firstWhere((r) => r.title == title);
    }

    Future<void> chip(String label) async {
      final f = find.text(label).last;
      await t.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).last);
      await t.tap(f);
      await settle(t);
    }

    final sat = await make('বাজার', () async {
      await chip('প্রতি সপ্তাহে');
      // The form's date's weekday comes ticked: Saturday on, every other day off.
      final satChip = find.byKey(const Key('rem-day-${DateTime.saturday}'));
      await t.scrollUntilVisible(satChip, 150, scrollable: find.byType(Scrollable).last);
      if (!t.widget<FilterChip>(satChip).selected) await t.tap(satChip);
      await settle(t);
      for (final d in weekOrder.where((d) => d != DateTime.saturday)) {
        final c = find.byKey(Key('rem-day-$d'));
        if (t.widget<FilterChip>(c).selected) await t.tap(c);
        await settle(t);
      }
    });
    expect(sat.repeat, Repeat.weekly);
    expect(sat.ringDays, {DateTime.saturday});
    expect(repeatText(sat), 'প্রতি শনিবার');

  });

  testWidgets('the form: every day but Friday — and it does not ring on Fridays', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    Future<Reminder> make(String title, Future<void> Function() pick) async {
      Navigator.of(t.element(find.byTooltip('বলুন'))).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.reminder)));
      await settle(t);
      await t.enterText(find.byType(TextFormField).first, title);
      await t.scrollUntilVisible(find.textContaining('কতবার'), 200, scrollable: find.byType(Scrollable).last);
      await t.tap(find.textContaining('কতবার'));
      await settle(t);
      await pick();
      await t.tap(find.text('সেভ করুন').last);
      await settle(t);
      return b.data.reminders.firstWhere((r) => r.title == title);
    }

    Future<void> chip(String label) async {
      final f = find.text(label).last;
      await t.scrollUntilVisible(f, 150, scrollable: find.byType(Scrollable).last);
      await t.tap(f);
      await settle(t);
    }

    final noFri = await make('হাঁটা', () async {
      await chip('প্রতিদিন');
      final fri = find.byKey(const Key('rem-day-${DateTime.friday}'));
      await t.scrollUntilVisible(fri, 150, scrollable: find.byType(Scrollable).last);
      await t.tap(fri);
      await settle(t);
    });
    expect(noFri.repeat, Repeat.weekly);
    expect(noFri.ringDays, {for (final d in weekOrder) if (d != DateTime.friday) d});
    expect(repeatText(noFri), 'শুক্রবার বাদে প্রতিদিন');
    expect(remindsOn(noFri, DateTime(2026, 10, 30)), isFalse, reason: '30 Oct 2026 is a Friday');
    expect(remindsOn(noFri, DateTime(2026, 10, 31)), isTrue);
  });

  test('a habit asks "করেছেন কি?" only when turned on, at its time, never on a day already ticked (owner, 28 Oct)', () {
    final now = DateTime(2026, 10, 28, 9);
    final off = Habit(id: 'h', name: 'হাঁটা');
    expect(assistantNotices(AppData(habits: [off]), now, const AssistantPrefs()).any((n) => n.reminderId.startsWith('nudge:habit:ask:')), isFalse, reason: 'off unless asked');
    final on = Habit(id: 'h', name: 'হাঁটা', askAt: 21 * 60, done: ['2026-10-29']);
    final n = assistantNotices(AppData(habits: [on]), now, const AssistantPrefs()).where((n) => n.reminderId.startsWith('nudge:habit:ask:')).toList();
    expect([for (final x in n) x.at], [DateTime(2026, 10, 28, 21), DateTime(2026, 10, 30, 21)], reason: '29 Oct is ticked already');
    expect(n.first.title, 'হাঁটা — আজ করেছেন?');
    expect(Habit.fromJson(on.toJson()).askAt, 21 * 60);
  });
}
