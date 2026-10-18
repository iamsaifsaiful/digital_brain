/// The one definition of "what is on a day" — used by the home's আজকের কাজ,
/// the কাজ ও রিমাইন্ডার page and the assistant's answers, so they never
/// disagree.
library;

import '../models/models.dart';
import 'bn.dart' show dayOnly;

/// One line in "আজ" / "কাজ ও রিমাইন্ডার": a task or a reminder's next ring.
class PlanItem {
  PlanItem.task(Task this.task, this.sort) : reminder = null;
  PlanItem.reminder(Reminder this.reminder, this.sort) : task = null;
  final Task? task;
  final Reminder? reminder;

  /// When it is (tasks without a time sort after timed ones of the day).
  final DateTime sort;
  String get title => task?.title ?? reminder!.title;
}

/// What is late, what is today and what is ahead.
class Plan {
  Plan(this.overdue, this.today, this.ahead, this.repeating, this.finished);
  final List<PlanItem> overdue;
  final List<PlanItem> today;
  final List<PlanItem> ahead;
  final List<Reminder> repeating;
  final List<PlanItem> finished;
}

Plan planOf(AppData d, DateTime now) {
  final today = dayOnly(now);
  final overdue = <PlanItem>[], todayL = <PlanItem>[], ahead = <PlanItem>[], finished = <PlanItem>[];
  for (final t in d.tasks) {
    if (t.done) {
      finished.add(PlanItem.task(t, t.doneAt ?? t.createdAt));
      continue;
    }
    final due = t.due == null ? null : dayOnly(t.due!);
    // A to-do of a whole week, month or year is late only after its span,
    // and is "today's" all through it — never pinned to its first day.
    // Late (its day or deadline passed) or a plan whose time is over: on
    // the "time passed" list, with its own date kept as it was.
    if (t.lateAt(now) || t.windowPassed(now)) {
      overdue.add(PlanItem.task(t, due ?? dayOnly(t.deadline!)));
    } else if (due == null || due == today || (t.span != TaskSpan.day && !due.isAfter(today))) {
      todayL.add(PlanItem.task(t, today.add(const Duration(hours: 23, minutes: 59))));
    } else {
      ahead.add(PlanItem.task(t, due.add(const Duration(hours: 23, minutes: 59))));
    }
  }
  for (final r in d.reminders) {
    if (!r.enabled) continue;
    final at = r.notifyAt(now);
    if (r.repeat == Repeat.none && !at.isAfter(now)) {
      // Rang already: today's stay on "আজ" (greyed), older ones are done.
      if (dayOnly(at) == today) {
        todayL.add(PlanItem.reminder(r, at));
      } else {
        finished.add(PlanItem.reminder(r, at));
      }
      continue;
    }
    if (dayOnly(at) == today) {
      todayL.add(PlanItem.reminder(r, at));
    } else if (!r.repeat.isInterval) {
      ahead.add(PlanItem.reminder(r, at));
    }
  }
  int by(PlanItem a, PlanItem b) => a.sort.compareTo(b.sort);
  overdue.sort(by);
  todayL.sort(by);
  ahead.sort(by);
  finished.sort((a, b) => b.sort.compareTo(a.sort));
  final repeating = d.reminders.where((r) => r.repeat != Repeat.none).toList()..sort((a, b) => a.notifyAt(now).compareTo(b.notifyAt(now)));
  return Plan(overdue, todayL, ahead, repeating, finished);
}


/// Everything on [day]: for today, what the home shows (late, due today,
/// without a date, and today's reminders); for another day, that day's
/// to-dos and reminders.
List<PlanItem> planItemsOn(AppData d, DateTime day, DateTime now) {
  final plan = planOf(d, now);
  final want = dayOnly(day);
  if (want == dayOnly(now)) return [...plan.overdue, ...plan.today];
  // A week/month/year plan is on every day of its span (said as the span,
  // never as that day); a one-day to-do and a reminder on their own day.
  return [for (final i in plan.ahead) if (i.task != null ? i.task!.onDay(want) : dayOnly(i.sort) == want) i];
}
