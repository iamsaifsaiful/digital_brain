/// Today's steps from the phone's step counter (owner, 24 Oct night).
///
/// The phone counts steps all day, even with the app closed, as one running
/// number since it was last switched on. The app keeps, on this phone only,
/// the day and the running number at its start ([StepBook.base]) and the
/// last number it read; today's steps are the difference.
///
/// Limits (said in the report): steps after the last reading of yesterday
/// count for today when the app was not opened again before midnight; after
/// a restart on another day, steps before the first reading are not seen.
library;

import 'dart:convert';

class StepBook {
  const StepBook({required this.day, required this.base, required this.last, this.days = const {}});

  /// 'YYYY-MM-DD' of [base].
  final String day;
  final double base;
  final double last;

  /// Earlier days' totals (last 14), 'YYYY-MM-DD' → steps.
  final Map<String, int> days;

  int get today => (last - base).round().clamp(0, 1 << 30);

  String toJson() => jsonEncode({'day': day, 'base': base, 'last': last, 'days': days});

  static StepBook? fromJson(String s) {
    if (s.isEmpty) return null;
    try {
      final j = jsonDecode(s) as Map<String, dynamic>;
      return StepBook(
        day: j['day'] as String,
        base: (j['base'] as num).toDouble(),
        last: (j['last'] as num).toDouble(),
        days: {for (final e in ((j['days'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt()},
      );
    } catch (_) {
      return null;
    }
  }
}

String stepDay(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The book after reading [counter] at [now].
StepBook stepsRead(StepBook? old, DateTime now, double counter) {
  final day = stepDay(now);
  if (old == null) return StepBook(day: day, base: counter, last: counter);
  final restarted = counter < old.last;
  if (old.day == day) {
    // Same day: after a restart the count starts at 0 again; keep what was walked.
    // (the new count starts at 0, so today = what was walked + the new count)
    final base = restarted ? -old.today.toDouble() : old.base;
    return StepBook(day: day, base: base, last: counter, days: old.days);
  }
  // A new day: yesterday's total is kept; today starts from the last reading.
  final days = {...old.days, old.day: old.today};
  final keep = (days.keys.toList()..sort()).reversed.take(14).toSet();
  days.removeWhere((k, _) => !keep.contains(k));
  return StepBook(day: day, base: restarted ? counter : old.last, last: counter, days: days);
}

/// "৩.৭" km for [steps] at an average stride (0.72 m).
double stepsKm(int steps) => steps * 0.72 / 1000;
