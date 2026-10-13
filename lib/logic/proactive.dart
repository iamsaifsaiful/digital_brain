/// The assistant speaking first: the morning and night summaries, and
/// gentle nudges — money owed for a month, a bill due the day after
/// tomorrow, a passport running out in six months, medicine running low.
///
/// Everything is worked out on the phone from the user's own records and
/// handed to the notifier as quiet notifications (not alarms).
library;

import '../models/models.dart';
import '../services/notifications.dart';
import 'bn.dart';
import 'calendar_bd.dart';
import 'lang.dart';
import 'ledger.dart';
import 'phrases.dart';

/// Does [r] ring on [day]?
bool remindsOn(Reminder r, DateTime day) {
  if (!r.enabled) return false;
  final start = dayOnly(r.date);
  final d = dayOnly(day);
  if (d.isBefore(start)) return false;
  return switch (r.repeat) {
    Repeat.none => d == start,
    Repeat.weekly => r.ringDays.contains(d.weekday),
    Repeat.monthly => d.day == start.day,
    Repeat.yearly => d.month == start.month && d.day == start.day,
    _ => true, // daily and the short repeats
  };
}

/// What the user chose in সেটিংস › সহকারী.
class AssistantPrefs {
  const AssistantPrefs({
    this.morningOn = true,
    this.morningAt = 8 * 60,
    this.nightOn = true,
    this.nightAt = 21 * 60,
    this.nudgesOn = true,
    this.name = '',
  });
  final bool morningOn;

  /// Minutes after midnight.
  final int morningAt;
  final bool nightOn;
  final int nightAt;
  final bool nudgesOn;
  final String name;
}

/// Notification ids the app opens in its own way when tapped.
const morningTag = 'brief:morning';
const nightTag = 'brief:night';
const nudgeDue = 'nudge:due:';
const nudgeDoc = 'nudge:doc:';
const nudgeBill = 'nudge:bill:';
const nudgeMed = 'nudge:med:';

/// To-dos with a day on or before [day] that are not done.
List<Task> tasksLeft(AppData d, DateTime day) {
  final dd = dayOnly(day);
  return [for (final t in d.tasks) if (!t.done && t.due != null && !dayOnly(t.due!).isAfter(dd)) t];
}

/// Special days falling on [day].
List<SpecialDay> specialOn(AppData d, DateTime day) {
  final dd = dayOnly(day);
  return [for (final s in d.specialDays) if (dayOnly(s.next(dd)) == dd) s];
}

String specialTitle(SpecialDay s, {DateTime? on}) {
  final years = on == null ? null : s.yearsOn(on);
  final kind = isEn ? s.kind.en : s.kind.bn;
  if (s.kind == SpecialKind.other) return s.person;
  const mine = {'আমার', 'আমাদের', 'my', 'our'};
  if (mine.contains(s.person.toLowerCase())) {
    final who = isEn ? (s.person == 'আমার' || s.person.toLowerCase() == 'my' ? 'My' : 'Our') : s.person;
    final y = years == null || years <= 0 ? '' : (isEn ? ' ($years years)' : ' (${bnDigits(years)} বছর)');
    return isEn ? '$who ${kind.toLowerCase()}$y' : '$who $kind$y';
  }
  if (isEn) return years == null || years <= 0 ? "${s.person}'s ${kind.toLowerCase()}" : "${s.person}'s ${kind.toLowerCase()} ($years years)";
  return years == null || years <= 0 ? '${possessive(s.person)} $kind' : '${possessive(s.person)} $kind (${bnDigits(years)} বছর)';
}

/// The morning summary for [day]: reminders with times, to-dos, a holiday,
/// special days. Empty parts are left out.
String morningText(AppData d, DateTime day) {
  final dd = dayOnly(day);
  final parts = <String>[];
  final hol = holidayOn(dd);
  if (hol != null) parts.add(trf('আজ ছুটি — {0}।', [hol.label]));
  for (final s in specialOn(d, dd)) {
    parts.add(trf('আজ {0}।', [specialTitle(s, on: dd)]));
  }
  final rem = [for (final r in d.reminders) if (remindsOn(r, dd) && !r.repeat.isInterval) r]..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
  final rem2 = rem.where((r) => !d.specialDays.any((s) => s.reminderId == r.id)).toList();
  if (rem2.isNotEmpty) {
    final first = rem2.take(3).map((r) => '${bnTime(r.hour, r.minute)} ${r.title}').join(', ');
    parts.add(rem2.length > 3 ? trf('{0}টা রিমাইন্ডার: {1}…', [bnDigits(rem2.length), first]) : trf('রিমাইন্ডার: {0}।', [first]));
  }
  final tasks = tasksLeft(d, dd);
  final anyDay = d.tasks.where((t) => !t.done && t.due == null).length;
  if (tasks.isNotEmpty) {
    parts.add(trf('{0}টা কাজ: {1}{2}', [bnDigits(tasks.length), tasks.take(3).map((t) => t.title).join(', '), tasks.length > 3 ? '…' : '।']));
  } else if (anyDay > 0) {
    parts.add(trf('তালিকায় {0}টা কাজ আছে।', [bnDigits(anyDay)]));
  }
  for (final m in d.medicines) {
    final left = m.daysLeft;
    if (left != null && left <= 3) parts.add(trf('{0} আর {1} দিনের আছে।', [m.name, bnDigits(left)]));
  }
  if (parts.isEmpty) return tr('আজ কোনো রিমাইন্ডার বা কাজ রাখা নেই। ভালো দিন কাটুক!');
  return parts.join(' ');
}

DateTime _at(DateTime day, int minutes) => DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

/// The quiet notifications for the summaries and nudges, from [now] on.
List<PlannedNotice> assistantNotices(AppData d, DateTime now, AssistantPrefs p) {
  final out = <PlannedNotice>[];
  final today = dayOnly(now);
  final hello = p.name.trim().isEmpty ? tr('সুপ্রভাত!') : trf('সুপ্রভাত, {0}!', [p.name.trim()]);

  if (p.morningOn) {
    for (var i = 0; i < 3; i++) {
      final day = today.add(Duration(days: i));
      final at = _at(day, p.morningAt);
      if (!at.isAfter(now)) continue;
      out.add(PlannedNotice(
        id: stableId('$morningTag:${dayKey(day)}'),
        at: at,
        title: trf('{0} আজকের সূচি', [hello]),
        body: morningText(d, day),
        reminderId: morningTag,
        gentle: true,
      ));
    }
  }

  if (p.nightOn) {
    for (var i = 0; i < 2; i++) {
      final day = today.add(Duration(days: i));
      final at = _at(day, p.nightAt);
      if (!at.isAfter(now)) continue;
      final left = tasksLeft(d, day);
      if (left.isEmpty) continue;
      out.add(PlannedNotice(
        id: stableId('$nightTag:${dayKey(day)}'),
        at: at,
        title: trf('আজ {0}টা কাজ বাকি রইল', [bnDigits(left.length)]),
        body: trf('{0} — কালকে সরিয়ে দেবো? চাপুন।', [left.take(3).map((t) => t.title).join(', ')]),
        reminderId: nightTag,
        gentle: true,
      ));
    }
  }

  if (!p.nudgesOn) return out;
  DateTime morningOf(DateTime day) => _at(day, 10 * 60);
  DateTime nextMorning() => morningOf(now).isAfter(now) ? morningOf(now) : morningOf(today.add(const Duration(days: 1)));

  // Money owed for a month (then two, three…): once each time.
  final owed = balances(d.ledger).where((b) => b.balance > 0 && b.last != null).toList()..sort((a, b) => b.balance.compareTo(a.balance));
  for (final b in owed.take(10)) {
    final last = dayOnly(b.last!);
    for (var k = 1; k <= 6; k++) {
      final at = morningOf(last.add(Duration(days: 30 * k)));
      if (!at.isAfter(now)) continue;
      out.add(PlannedNotice(
        id: stableId('$nudgeDue${b.key}'),
        at: at,
        title: trf('{0}-এর কাছে {1} পাওনা', [b.name, taka(b.balance)]),
        body: trf('শেষ লেনদেন {0} দিন আগে। তাগাদার মেসেজ পাঠাবো? চাপুন।', [bnDigits(30 * k)]),
        reminderId: '$nudgeDue${b.name}',
        gentle: true,
      ));
      break;
    }
  }

  // A bill or rent due the day after tomorrow (when it has no advance notice of its own).
  final billWords = RegExp(r'বিল|ভাড়া|ফি\b|কিস্তি|রিচার্জ|ইএমআই|bill|rent|fee|emi', caseSensitive: false);
  for (final r in d.reminders) {
    if (!r.enabled || r.daysBefore > 0 || !billWords.hasMatch(r.title)) continue;
    if (r.repeat != Repeat.none && r.repeat != Repeat.monthly) continue;
    final due = r.nextDate(now);
    final at = morningOf(due.subtract(const Duration(days: 2)));
    if (!at.isAfter(now)) continue;
    out.add(PlannedNotice(
      id: stableId('$nudgeBill${r.id}'),
      at: at,
      title: trf('{0} — শেষ দিন পরশু', [r.title]),
      body: trf('{0}, {1}। আগেভাগে দিয়ে দিলে ঝামেলা থাকে না।', [weekdayName(due), shortDate(due)]),
      reminderId: '$nudgeBill${r.id}',
      gentle: true,
    ));
  }

  // Papers that run out: six months ahead (the reminder itself comes a month before).
  for (final x in d.docs) {
    final exp = x.expiry;
    if (exp == null) continue;
    final at = morningOf(exp.subtract(const Duration(days: 182)));
    if (!at.isAfter(now)) continue;
    out.add(PlannedNotice(
      id: stableId('$nudgeDoc${x.id}'),
      at: at,
      title: trf('{0}-এর মেয়াদ ৬ মাস পর শেষ', [x.title]),
      body: trf('মেয়াদ শেষ {0}। নবায়নের কাগজ গুছিয়ে রাখুন।', [fullDate(exp)]),
      reminderId: '$nudgeDoc${x.id}',
      gentle: true,
    ));
  }

  // Medicine running low.
  for (final m in d.medicines) {
    final left = m.daysLeft;
    if (left == null || left > 5) continue;
    out.add(PlannedNotice(
      id: stableId('$nudgeMed${m.id}:$left'),
      at: nextMorning(),
      title: trf('{0} আর {1} দিনের আছে', [m.name, bnDigits(left)]),
      body: tr('ফুরিয়ে যাওয়ার আগে কিনে রাখুন।'),
      reminderId: '$nudgeMed${m.id}',
      gentle: true,
    ));
  }
  return out;
}
