/// The two daily questions (owner, 22 Nov: "হোম পেইজে সকালে প্রশ্ন উঠবে,
/// কত ঘন্টা ঘুমালেন? সারাদিন থাকবে না … রাতে প্রশ্ন করবে, আজ কত গ্লাস
/// পানি খেলেন?"). Health that comes to the user instead of waiting in its
/// menu, without nagging:
///
/// * each question only in its own hours, once a day, never again that day
///   once answered or skipped ("আজ না");
/// * not asked when the answer is already known (Health Connect's sleep, or
///   a sleep written by hand or by voice);
/// * after three skips in a row the card offers to stop asking;
/// * each can be turned off (স্বাস্থ্য › প্রতিদিনের দুই প্রশ্ন).
///
/// These are the user's own wellness notes, not medical readings.
library;

import '../models/models.dart';
import 'bn.dart';
import 'health.dart';
import 'lang.dart';

enum DailyAsk { sleep, water }

/// The sleep question shows from 4 in the morning until noon.
const askSleepFrom = 4 * 60, askSleepTo = 12 * 60;

/// The water question shows from 7 in the evening until midnight.
const askWaterFrom = 19 * 60;

/// Three skips in a row: the card asks whether to stop.
const askOfferOffAfter = 3;

/// Glasses a day the water card counts toward.
const waterGoal = 8;

/// The quick answers on the sleep card and the morning notification.
const sleepChoices = [5, 6, 7, 8, 9];
const sleepNoticeChoices = [6, 7, 8];
const waterNoticeChoices = [4, 6, 8];

/// A notification button's id: "ask:sleep:7", "ask:water:6".
String askAction(DailyAsk k, int v) => 'ask:${k.name}:$v';

(DailyAsk, int)? parseAskAction(String? id) {
  final p = (id ?? '').split(':');
  if (p.length != 3 || p[0] != 'ask') return null;
  final k = DailyAsk.values.where((x) => x.name == p[1]).firstOrNull;
  final v = int.tryParse(p[2]);
  return k == null || v == null ? null : (k, v);
}

/// The sleep that ended this morning, if the app already has it.
HealthLog? sleepLastNight(AppData d, DateTime now) {
  final today = dayOnly(now);
  for (final h in readings(d, FamilyMember.meId, HealthKind.sleep).reversed) {
    if (dayOnly(h.at) == today) return h;
    if (h.at.isBefore(today)) break;
  }
  return null;
}

/// Which question the Home card shows now, if any.
/// [skipped] and [answered] hold "sleep:2026-11-22"-like keys for today.
DailyAsk? askNow(AppData d, DateTime now, {required bool sleepOn, required bool waterOn, required Set<String> done}) {
  final m = now.hour * 60 + now.minute;
  final day = dayKey(now);
  if (sleepOn && m >= askSleepFrom && m < askSleepTo && !done.contains('sleep:$day') && sleepLastNight(d, now) == null) return DailyAsk.sleep;
  if (waterOn && m >= askWaterFrom && !done.contains('water:$day')) return DailyAsk.water;
  return null;
}

/// The last [n] days' values (oldest first, today last), null for no entry.
List<double?> lastDays(AppData d, HealthKind kind, DateTime now, {int n = 7}) {
  final today = dayOnly(now);
  return [
    for (var i = n - 1; i >= 0; i--)
      () {
        final day = today.subtract(Duration(days: i));
        final logs = [for (final h in d.health) if (h.member == FamilyMember.meId && h.kind == kind && dayOnly(h.at) == day) h];
        if (logs.isEmpty) return null;
        // Sleep: the night's hours (the last one written that day); water: the day's glasses.
        return kind == HealthKind.sleep ? logs.last.a : logs.fold<double>(0, (a, h) => a + h.a);
      }(),
  ];
}

/// The average of the days with an entry (null with none).
double? averageOf(List<double?> v) {
  final have = v.whereType<double>().toList();
  return have.isEmpty ? null : have.reduce((a, b) => a + b) / have.length;
}

String oneDecimal(double v) => bnDigits(v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1));

/// A short, kind line under the week's numbers — never advice about illness.
String sleepWeekLine(List<double?> week) {
  final avg = averageOf(week);
  if (avg == null) return tr('সকালে এক ট্যাপে জানালেই সপ্তাহের হিসাব এখানে জমবে।');
  if (avg < 6) return trf('এ সপ্তাহে গড়ে {0} ঘণ্টা — একটু কম। আজ রাতে একটু আগে শুতে পারেন।', [oneDecimal(avg)]);
  if (avg > 9.5) return trf('এ সপ্তাহে গড়ে {0} ঘণ্টা।', [oneDecimal(avg)]);
  return trf('এ সপ্তাহে গড়ে {0} ঘণ্টা — ভালো চলছে।', [oneDecimal(avg)]);
}

String waterWeekLine(List<double?> week) {
  final avg = averageOf(week);
  if (avg == null) return tr('রাতে এক ট্যাপে জানালেই সপ্তাহের হিসাব এখানে জমবে।');
  final met = week.whereType<double>().where((x) => x >= waterGoal).length;
  return trf('এ সপ্তাহে গড়ে {0} গ্লাস · {1} দিন ৮ গ্লাস হয়েছে', [oneDecimal(avg), bnDigits(met)]);
}

/// The line added to the morning summary while the sleep question is on.
String get sleepAskLine => tr('রাতে কত ঘণ্টা ঘুমালেন? নিচের বোতামে এক ট্যাপে জানান।');
