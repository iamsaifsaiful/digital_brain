/// Small figures the new home shows (24 Oct design), from the data as it is.
library;

import '../models/models.dart';

/// This week's to-dos (the week as the app counts it, [weekStartOf]): how
/// many of those due in it are done, and how many there are.
(int done, int total) weekTaskProgress(AppData d, DateTime now) {
  final start = weekStartOf(now);
  final end = start.add(const Duration(days: 7));
  var done = 0, total = 0;
  for (final t in d.tasks) {
    final due = t.due;
    if (due == null || due.isBefore(start) || !due.isBefore(end)) continue;
    total++;
    if (t.done) done++;
  }
  return (done, total);
}

/// To-dos ticked on [day].
int doneOn(AppData d, DateTime day) =>
    d.tasks.where((t) => t.done && t.doneAt != null && t.doneAt!.year == day.year && t.doneAt!.month == day.month && t.doneAt!.day == day.day).length;
