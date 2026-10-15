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
    this.quietOn = true,
    this.quietFrom = 22 * 60,
    this.quietTo = 7 * 60,
    this.dailyCap = 3,
    this.jumuah = true,
    this.health = true,
    this.festival = true,
    this.weekly = true,
    this.streak = true,
    this.comeback = true,
    this.prayers = const {},
    this.ramadan = false,
    this.place = 'ঢাকা',
    this.lastOpen,
    this.donorNext,
  });
  final bool morningOn;

  /// No nudges between these times (minutes after midnight); a nudge that
  /// falls inside waits for the morning. Reminders and alarms the user set
  /// are never held back.
  final bool quietOn;
  final int quietFrom;
  final int quietTo;

  /// At most this many nudges a day (summaries, prayer and Ramadan times
  /// the user turned on do not count).
  final int dailyCap;
  final bool jumuah;
  final bool health;
  final bool festival;
  final bool weekly;
  final bool streak;
  final bool comeback;

  /// Prayers to be told of: 'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'.
  final Set<String> prayers;
  final bool ramadan;

  /// The district for prayer times.
  final String place;

  /// When the app was last opened (for "অনেক দিন দেখা নেই").
  final DateTime? lastOpen;

  /// When the user can give blood again (a reminder that day).
  final DateTime? donorNext;

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
const nudgeHabit = 'nudge:habit:';
const nudgeWeek = 'nudge:week';
const nudgeHealth = 'nudge:health';
const nudgeFest = 'nudge:fest';
const nudgeBack = 'nudge:back';
const nudgeJumuah = 'nudge:jumuah';
const nudgePrayer = 'nudge:prayer';
const nudgeRamadan = 'nudge:ramadan';
const nudgeDonor = 'nudge:donor';

/// One sentence for each month: what to watch for in Bangladesh's seasons.
const healthTips = [
  'শীতের সকালে শিশু আর বয়স্কদের গরম কাপড় পরান; ঠান্ডা-কাশি বা শ্বাসকষ্ট বাড়লে দেরি না করে ডাক্তার দেখান।',
  'বসন্তে ধুলাবালি বাড়ে — বাইরে মাস্ক পরুন; অ্যালার্জি বা হাঁপানি থাকলে ওষুধ হাতের কাছে রাখুন।',
  'গরম শুরু হয়েছে — দিনে অন্তত ৮-১০ গ্লাস পানি খান, দুপুরের কড়া রোদ এড়িয়ে চলুন।',
  'তীব্র গরমে হিটস্ট্রোকের ঝুঁকি — বাইরে গেলে ছাতা আর পানি সাথে রাখুন, প্রয়োজনে খাবার স্যালাইন খান।',
  'কালবৈশাখীর মৌসুম — ঝড়ের সময় খোলা মাঠ ও গাছের নিচে থাকবেন না; বিদ্যুতের তার থেকে দূরে থাকুন।',
  'বর্ষা আসছে — ডেঙ্গু থেকে বাঁচতে বাড়ির আশপাশে জমে থাকা পানি ফেলে দিন, দিনেও মশারি ব্যবহার করুন।',
  'বর্ষায় পানিবাহিত রোগ বাড়ে — ফোটানো বা বিশুদ্ধ পানি খান, বাইরের খোলা খাবার এড়িয়ে চলুন।',
  'ডেঙ্গুর সময় — জ্বর হলে নিজে থেকে ব্যথার ওষুধ না খেয়ে প্যারাসিটামল খান আর পরীক্ষা করান।',
  'ভাদ্রের গরম আর আর্দ্রতা — হালকা সুতির কাপড় পরুন, ঘাম শুকিয়ে নিন, পানি বেশি খান।',
  'ডেঙ্গু এখনো আছে — ফুলের টব, এসির পানি আর ছাদে জমা পানি সপ্তাহে একবার পরিষ্কার করুন।',
  'শীত আসছে — বয়স্কদের ফ্লু-নিউমোনিয়ার টিকার খোঁজ নিন; গরম পানি দিয়ে গোসল করান।',
  'শীতে ত্বক শুকিয়ে যায় — পর্যাপ্ত পানি খান, ময়েশ্চারাইজার ব্যবহার করুন; সকালের রোদে কিছুক্ষণ থাকুন।',
];

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

/// The quiet notifications for the summaries and nudges, from [now] on,
/// after the rules that keep them welcome: nothing in the quiet hours (it
/// waits for the morning) and no more than [AssistantPrefs.dailyCap] nudges
/// a day, the most useful first.
List<PlannedNotice> assistantNotices(AppData d, DateTime now, AssistantPrefs p) {
  final all = [..._summaries(d, now, p), ..._nudges(d, now, p), ..._extras(d, now, p)];
  final kept = <PlannedNotice>[];
  final perDay = <String, int>{};
  // Most useful first, so the cap drops the least useful.
  all.sort((a, b) => _rank(a.reminderId).compareTo(_rank(b.reminderId)));
  for (var n in all) {
    final chosen = _chosenByUser(n.reminderId);
    if (!chosen && p.quietOn) n = _afterQuiet(n, p);
    if (!chosen) {
      final k = dayKey(n.at);
      final c = perDay[k] ?? 0;
      if (c >= p.dailyCap) continue;
      perDay[k] = c + 1;
    }
    kept.add(n);
  }
  kept.sort((a, b) => a.at.compareTo(b.at));
  return kept;
}

/// Summaries at the user's own times, and prayer/Ramadan times they asked
/// for, are never held back or counted.
bool _chosenByUser(String tag) =>
    tag == morningTag || tag == nightTag || tag.startsWith(nudgePrayer) || tag.startsWith(nudgeRamadan) || tag.startsWith(nudgeDonor);

int _rank(String tag) {
  const order = [morningTag, nightTag, nudgePrayer, nudgeRamadan, nudgeDue, nudgeBill, nudgeMed, nudgeDoc, nudgeDonor, nudgeHabit, nudgeJumuah, nudgeWeek, nudgeFest, nudgeHealth, nudgeBack];
  for (var i = 0; i < order.length; i++) {
    if (tag.startsWith(order[i])) return i;
  }
  return order.length;
}

bool _inQuiet(DateTime t, AssistantPrefs p) {
  final m = t.hour * 60 + t.minute;
  return p.quietFrom <= p.quietTo ? (m >= p.quietFrom && m < p.quietTo) : (m >= p.quietFrom || m < p.quietTo);
}

PlannedNotice _afterQuiet(PlannedNotice n, AssistantPrefs p) {
  if (!_inQuiet(n.at, p)) return n;
  var day = dayOnly(n.at);
  final m = n.at.hour * 60 + n.at.minute;
  // Late evening: the next morning. After midnight: this morning.
  if (p.quietFrom > p.quietTo && m >= p.quietFrom) day = day.add(const Duration(days: 1));
  final at = _at(day, p.quietTo);
  return PlannedNotice(id: n.id, at: at, title: n.title, body: n.body, reminderId: n.reminderId, gentle: true);
}

List<PlannedNotice> _summaries(AppData d, DateTime now, AssistantPrefs p) {
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

  return out;
}

List<PlannedNotice> _nudges(AppData d, DateTime now, AssistantPrefs p) {
  final out = <PlannedNotice>[];
  final today = dayOnly(now);
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

/// The friendly extras: Friday, weekly round-up, a monthly
/// health tip, festival wishes, habit streaks, a "we missed you" after a
/// few quiet days, and — only if the user turned them on — prayer and
/// Ramadan times.
List<PlannedNotice> _extras(AppData d, DateTime now, AssistantPrefs p) {
  final out = <PlannedNotice>[];
  final today = dayOnly(now);
  void add(String tag, String key, DateTime at, String title, String body) {
    if (!at.isAfter(now)) return;
    out.add(PlannedNotice(id: stableId('$tag:$key'), at: at, title: title, body: body, reminderId: tag, gentle: true));
  }

  // Next occurrence of [weekday] (today counts when the time is still ahead).
  DateTime nextWeekday(int weekday, int minutes) {
    for (var i = 0; i < 8; i++) {
      final day = today.add(Duration(days: i));
      final at = _at(day, minutes);
      if (day.weekday == weekday && at.isAfter(now)) return at;
    }
    return _at(today.add(const Duration(days: 7)), minutes);
  }

  final place = placeNamed(p.place);

  if (p.jumuah) {
    final at = nextWeekday(DateTime.friday, 11 * 60);
    final dhuhr = sunTimes(at, place).dhuhr;
    add(nudgeJumuah, dayKey(at), at, tr('জুমা মোবারক!'), trf('আজ জুমার দিন। জোহর শুরু {0} — গোসল সেরে আগেভাগে মসজিদে যাওয়ার প্রস্তুতি নিন।', [bnTime(dhuhr.hour, dhuhr.minute)]));
  }

  if (p.weekly) {
    // Saturday morning: the past week in two lines.
    final at = nextWeekday(DateTime.saturday, 10 * 60);
    final from = dayOnly(at).subtract(const Duration(days: 7));
    final spent = d.cash.where((c) => c.kind == CashKind.expense && c.projectId == null && !c.date.isBefore(from) && c.date.isBefore(dayOnly(at))).fold<int>(0, (a, c) => a + c.amount);
    final done = d.tasks.where((t) => t.done && t.doneAt != null && !t.doneAt!.isBefore(from)).length;
    final open = d.tasks.where((t) => !t.done).length;
    final parts = <String>[
      if (spent > 0) trf('খরচ {0}', [taka(spent)]),
      if (done > 0) trf('{0}টা কাজ শেষ', [bnDigits(done)]),
      if (open > 0) trf('{0}টা বাকি', [bnDigits(open)]),
    ];
    if (parts.isNotEmpty) add(nudgeWeek, dayKey(at), at, tr('গত সপ্তাহের হিসাব'), '${parts.join(' · ')}। ${tr('নতুন সপ্তাহ ভালো কাটুক!')}');
  }

  if (p.health) {
    // Once a month: the first Saturday, mid-morning.
    for (var k = 0; k < 2; k++) {
      final month = DateTime(today.year, today.month + k);
      var day = month;
      while (day.weekday != DateTime.saturday) {
        day = day.add(const Duration(days: 1));
      }
      final at = _at(day, 10 * 60 + 30);
      if (!at.isAfter(now)) continue;
      add(nudgeHealth, monthKey(day), at, tr('এই মৌসুমের স্বাস্থ্য পরামর্শ'), tr(healthTips[day.month - 1]));
      break;
    }
  }

  if (p.festival) {
    for (var i = 0; i < 30; i++) {
      final day = today.add(Duration(days: i));
      final h = holidayOn(day);
      if (h == null || h.name.endsWith('ছুটি')) continue;
      final wish = _wishFor(h.name);
      if (wish == null) continue;
      add(nudgeFest, dayKey(day), _at(day, 8 * 60 + 30), wish, trf('আজ {0}। পরিবার নিয়ে আনন্দে কাটুক দিনটি।', [h.label]));
      break;
    }
  }

  if (p.streak) {
    for (final h in d.habits) {
      final s = h.streak(now);
      if (s < 2 || h.doneOn(today)) continue;
      add(nudgeHabit, '${h.id}:${dayKey(today)}', _at(today, 20 * 60), trf('টানা {0} দিন — {1}', [bnDigits(s), h.name]),
          tr('আজকেরটা হয়ে গেলে টিক দিয়ে দিন, ধারা যেন না ভাঙে।'));
    }
  }

  final last = p.lastOpen;
  if (p.comeback && last != null) {
    final at = _at(dayOnly(last).add(const Duration(days: 3)), 10 * 60 + 30);
    final open = d.tasks.where((t) => !t.done).length;
    add(nudgeBack, dayKey(at), at, tr('কেমন আছেন?'),
        open > 0 ? trf('তালিকায় {0}টা কাজ বাকি আছে। নতুন কিছু মনে রাখার থাকলে শুধু বলুন।', [bnDigits(open)]) : tr('নতুন কিছু মনে রাখার থাকলে শুধু বলুন — আমি রেখে দেবো।'));
  }

  // Asked for by the user: prayer times and Ramadan (sehri, iftar), for the next two days.
  for (var i = 0; i < 2; i++) {
    final day = today.add(Duration(days: i));
    final t = sunTimes(day, place);
    final names = {'fajr': (tr('ফজর'), t.fajr), 'dhuhr': (day.weekday == DateTime.friday ? tr('জুমা') : tr('জোহর'), t.dhuhr), 'asr': (tr('আসর'), t.asr), 'maghrib': (tr('মাগরিব'), t.maghrib), 'isha': (tr('এশা'), t.isha)};
    for (final k in p.prayers) {
      final v = names[k];
      if (v == null) continue;
      add('$nudgePrayer:$k', dayKey(day), v.$2, trf('{0}-এর সময় হয়েছে', [v.$1]), trf('{0} · {1}', [bnTime(v.$2.hour, v.$2.minute), place.label]));
    }
    if (p.ramadan && hijriDate(day).isRamadan) {
      final sehri = t.fajr.subtract(const Duration(minutes: 40));
      add('$nudgeRamadan:sehri', dayKey(day), sehri, tr('সেহরির সময়'), trf('সেহরির শেষ সময় {0} (আনুমানিক)।', [bnTime(t.fajr.hour, t.fajr.minute)]));
      final iftar = t.maghrib.subtract(const Duration(minutes: 10));
      add('$nudgeRamadan:iftar', dayKey(day), iftar, tr('ইফতারের সময় হয়ে আসছে'), trf('ইফতার {0}-এ (আনুমানিক)।', [bnTime(t.maghrib.hour, t.maghrib.minute)]));
    }
  }

  final donor = p.donorNext;
  if (donor != null) {
    add(nudgeDonor, dayKey(donor), _at(dayOnly(donor), 10 * 60), tr('আবার রক্ত দিতে পারবেন'), tr('শেষ রক্তদানের পর যথেষ্ট সময় পার হয়েছে। কারও দরকার হলে এখন সাহায্য করতে পারবেন।'));
  }
  return out;
}

String? _wishFor(String holiday) {
  if (holiday.contains('ঈদুল ফিতর')) return tr('ঈদ মোবারক!');
  if (holiday.contains('ঈদুল আজহা')) return tr('ঈদ মোবারক!');
  if (holiday.contains('নববর্ষ')) return tr('শুভ নববর্ষ!');
  if (holiday.contains('বিজয় দিবস')) return tr('বিজয় দিবসের শুভেচ্ছা');
  if (holiday.contains('স্বাধীনতা')) return tr('স্বাধীনতা দিবসের শুভেচ্ছা');
  if (holiday.contains('মাতৃভাষা')) return tr('আন্তর্জাতিক মাতৃভাষা দিবস');
  if (holiday.contains('দুর্গাপূজা (বিজয়া')) return tr('শুভ বিজয়া');
  if (holiday.contains('বড়দিন')) return tr('শুভ বড়দিন');
  if (holiday.contains('বুদ্ধ')) return tr('শুভ বুদ্ধপূর্ণিমা');
  return null;
}
