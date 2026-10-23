import 'package:digital_brain/services/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

PlannedNotice _n(DateTime at, NoticeRepeat r) => PlannedNotice(id: 1, at: at, title: 't', body: '', reminderId: 'r', repeat: r);

void main() {
  final now = DateTime(2026, 10, 23, 13, 0);

  test('a one-time notice keeps its time, even in the past', () {
    final past = DateTime(2026, 10, 20, 9);
    expect(nextAhead(_n(past, NoticeRepeat.none), now), past);
  });

  test('a future notice is left alone', () {
    final soon = DateTime(2026, 10, 23, 18);
    expect(nextAhead(_n(soon, NoticeRepeat.daily), now), soon);
  });

  test('daily moves to the next time ahead', () {
    expect(nextAhead(_n(DateTime(2026, 9, 1, 9), NoticeRepeat.daily), now), DateTime(2026, 10, 24, 9));
    expect(nextAhead(_n(DateTime(2026, 9, 1, 15), NoticeRepeat.daily), now), DateTime(2026, 10, 23, 15));
  });

  test('weekly keeps the weekday', () {
    final at = nextAhead(_n(DateTime(2026, 10, 1, 9), NoticeRepeat.weekly), now); // a Thursday
    expect(at, DateTime(2026, 10, 29, 9));
    expect(at.weekday, DateTime.thursday);
  });

  test('monthly on the 31st does not drift', () {
    final at = nextAhead(_n(DateTime(2026, 1, 31, 8), NoticeRepeat.monthly), now);
    expect(at, DateTime(2026, 10, 31, 8));
    final feb = nextAhead(_n(DateTime(2026, 1, 31, 8), NoticeRepeat.monthly), DateTime(2026, 2, 1));
    expect(feb, DateTime(2026, 2, 28, 8));
  });

  test('yearly moves a year at a time', () {
    expect(nextAhead(_n(DateTime(2020, 3, 5, 7), NoticeRepeat.yearly), now), DateTime(2027, 3, 5, 7));
    expect(nextAhead(_n(DateTime(2024, 2, 29, 7), NoticeRepeat.yearly), now), DateTime(2027, 2, 28, 7));
  });
}
