import 'package:digital_brain/logic/home_figures.dart';
import 'package:digital_brain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('this week: done of all to-dos due in the week', () {
    final now = DateTime(2026, 10, 24, 15); // a Saturday
    final start = weekStartOf(now);
    final d = AppData(tasks: [
      Task(title: 'a', due: start, done: true, doneAt: now),
      Task(title: 'b', due: start.add(const Duration(days: 6, hours: 20))),
      Task(title: 'c', due: start.add(const Duration(days: 7))), // next week
      Task(title: 'd', due: start.subtract(const Duration(minutes: 1))), // last week
      Task(title: 'e'), // no day
    ]);
    expect(weekTaskProgress(d, now), (1, 2));
    expect(weekTaskProgress(AppData(), now), (0, 0));
  });

  test('done on a day', () {
    final now = DateTime(2026, 10, 24, 15);
    final d = AppData(tasks: [
      Task(title: 'a', done: true, doneAt: now),
      Task(title: 'b', done: true, doneAt: now.subtract(const Duration(days: 1))),
      Task(title: 'c'),
    ]);
    expect(doneOn(d, now), 1);
    expect(doneOn(d, now.subtract(const Duration(days: 1))), 1);
  });
}
