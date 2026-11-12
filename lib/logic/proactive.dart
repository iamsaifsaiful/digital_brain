/// The assistant speaking first: the morning and night summaries, and
/// gentle nudges — money owed for a month, a bill due the day after
/// tomorrow, a passport running out in six months, medicine running low.
///
/// Everything is worked out on the phone from the user's own records and
/// handed to the notifier as quiet notifications (not alarms).
library;

import 'dart:math' show min;

import '../models/models.dart';
import 'vault_age.dart';
import '../services/notifications.dart';
import 'bn.dart';
import 'calendar_bd.dart';
import 'health.dart' show bmiOf, latest;
import 'lang.dart';
import 'ledger.dart';
import 'phrases.dart';
import 'server_notices.dart';
import 'spend_health.dart';
import 'money_quotes.dart';

/// The morning summary rings at 9 unless the member picks a time (owner, 28 Oct; was 8).
const defaultMorningAt = 8 * 60;

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
    this.morningAt = defaultMorningAt,
    this.nightOn = true,
    this.nightAt = 21 * 60,
    this.nudgesOn = true,
    this.name = '',
    this.quietOn = true,
    this.quietFrom = 22 * 60,
    this.quietTo = 7 * 60,
    this.dailyCap = 3,
    this.jumuah = true,
    this.plan = true,
    this.smart = true,
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
    this.lastBackup,
    this.server = const [],
    this.news = true,
    this.docAlerts = true,
    this.dueAlerts = true,
    this.quote = true,
    this.homeFix = true,
    this.rules = NoticeRules.none,
    this.groups = const {'all'},
    this.trialEnds,
  });

  /// While on the free Premium trial: when it ends (a note the day before).
  final DateTime? trialEnds;

  /// What the admin set on the site or in the admin app (logic/server_notices.dart).
  final NoticeRules rules;

  /// Which groups this member is in (new/old, regular/occasional, free/pro), from this phone.
  final Set<String> groups;

  /// A thought about money each morning (see logic/money_quotes.dart).
  final bool quote;

  /// On days off: the things at home waiting to be fixed.
  final bool homeFix;

  /// Notifications from our website (see logic/server_notices.dart), and
  /// whether the user wants them (সেটিংস › নোটিফিকেশন).
  final List<ServerNotice> server;
  final bool news;

  /// Pro: paper expiry notes, and the "money owed for a month" nudges.
  final bool docAlerts;
  final bool dueAlerts;

  /// When the last backup was taken (null: never).
  final DateTime? lastBackup;
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

  /// Asking about plans: the evening before a day off, a new week, a new
  /// month, and at night for tomorrow (a tap opens the mic).
  final bool plan;

  /// Noticing from the user's own records: no spending written today, a
  /// category spent more than last month, a special day the day after
  /// tomorrow, salary in, Eid or Ramadan ten days away.
  final bool smart;
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

/// "What's the plan?" — tapped, the assistant opens listening.
const nudgePlan = 'nudge:plan:';
const nudgeNoCash = 'nudge:nocash';
const nudgeSpend = 'nudge:spend';
const nudgeDay2 = 'nudge:day2';
const nudgeSalary = 'nudge:salary';
const nudgeSoon = 'nudge:soon';
const nudgeBackup = 'nudge:backup';
const nudgeBmi = 'nudge:bmi:';

/// A shop buyer's weekly তাগাদা (ব্যবসায়ী মোড).
const nudgeTagada = 'nudge:tagada:';
const nudgeQuote = 'nudge:quote';
const nudgeFix = 'nudge:fix';
const nudgePass = 'nudge:pass';
const nudgeTrial = 'nudge:trial';

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
  if (parts.isEmpty) return tr('আজ কোনো কাজ রাখা নেই। দিনটা ভালো কাটুক।');
  return parts.join(' ');
}

DateTime _at(DateTime day, int minutes) => DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

/// The quiet notifications for the summaries and nudges, from [now] on,
/// after the rules that keep them welcome: nothing in the quiet hours (it
/// waits for the morning) and no more than [AssistantPrefs.dailyCap] nudges
/// a day, the most useful first.
List<PlannedNotice> assistantNotices(AppData d, DateTime now, AssistantPrefs p) {
  final all = [
    ..._summaries(d, now, p), ..._nudges(d, now, p), ..._extras(d, now, p), ..._plans(d, now, p), ..._noticed(d, now, p),
    if (p.news && p.nudgesOn) ...serverNotices(p.server, d, now, lastOpen: p.lastOpen),
  ];
  // The admin's rules: off, for some members only, another time or wording.
  final ruled = p.rules.kinds.isEmpty ? all : [for (final n in all) _ruled(n, p, now)].whereType<PlannedNotice>().toList();
  final cap = p.rules.cap == null ? p.dailyCap : min(p.dailyCap, p.rules.cap!);
  final kept = <PlannedNotice>[];
  final perDay = <String, int>{};
  // Most useful first, so the cap drops the least useful.
  ruled.sort((a, b) => _rank(a.reminderId).compareTo(_rank(b.reminderId)));
  for (var n in ruled) {
    final chosen = _chosenByUser(n.reminderId);
    if (!chosen && p.quietOn) n = _afterQuiet(n, p);
    if (!chosen) {
      final k = dayKey(n.at);
      final c = perDay[k] ?? 0;
      if (c >= cap) continue;
      perDay[k] = c + 1;
    }
    kept.add(n);
  }
  return _spaced(kept, p);
}

/// At least this long between two of the app's own notifications (owner,
/// 4 Nov: সুপ্রভাত first, then nothing for 30 minutes, and so on).
const noticeGap = Duration(minutes: 30);

/// Times the member chose (the summaries, prayers, Ramadan, a habit's own
/// time) stay put; every other notice moves past them and past each other,
/// at least [noticeGap] apart, the most useful first when two share a time.
/// One that finds no room that day (it would run into the quiet hours or the
/// next day) is left out — it is a nudge, not a reminder.
List<PlannedNotice> _spaced(List<PlannedNotice> list, AssistantPrefs p) {
  bool fixed(String t) => t == morningTag || t == nightTag || t.startsWith(nudgePrayer) || t.startsWith(nudgeRamadan) || t.startsWith('${nudgeHabit}ask:');
  final placed = <DateTime>[for (final n in list) if (fixed(n.reminderId)) n.at];
  final out = <PlannedNotice>[for (final n in list) if (fixed(n.reminderId)) n];
  final rest = [for (final n in list) if (!fixed(n.reminderId)) n]
    ..sort((a, b) {
      final c = a.at.compareTo(b.at);
      return c != 0 ? c : _rank(a.reminderId).compareTo(_rank(b.reminderId));
    });
  for (final n in rest) {
    var at = n.at;
    for (var i = 0; i < 64; i++) {
      final near = [for (final t in placed) if (t.difference(at).abs() < noticeGap) t];
      if (near.isEmpty) break;
      near.sort();
      at = near.last.add(noticeGap);
    }
    if (dayOnly(at) != dayOnly(n.at) || (p.quietOn && at != n.at && _inQuiet(at, p))) continue;
    placed.add(at);
    out.add(at == n.at
        ? n
        : PlannedNotice(id: n.id, at: at, title: n.title, body: n.body, reminderId: n.reminderId, gentle: n.gentle, repeat: n.repeat, every: n.every, early: n.early));
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// [n] after the admin's rule for its kind: null when it does not go (off,
/// or not for this member's groups, or its new time has passed).
PlannedNotice? _ruled(PlannedNotice n, AssistantPrefs p, DateTime now) {
  final r = p.rules.forTag(n.reminderId);
  if (r == null) return n;
  if (!r.on || !p.groups.contains(r.who)) return null;
  var at = n.at;
  // Moved to another weekday (owner, 28 Oct): the next such day on or after the app's own.
  if (r.wd >= 1 && r.wd <= 7 && at.weekday != r.wd) {
    at = at.add(Duration(days: (r.wd - at.weekday + 7) % 7));
    if (!at.isAfter(now)) return null;
  }
  final m = r.minutes;
  // A summary time the member set themself stays theirs.
  final ownTime = (n.reminderId == morningTag && p.morningAt != defaultMorningAt) || (n.reminderId == nightTag && p.nightAt != 21 * 60);
  if (m != null && !ownTime) {
    at = _at(dayOnly(at), m);
    if (!at.isAfter(now)) return null;
  }
  final name = p.name.trim();
  final title = r.title.trim().isEmpty ? n.title : fillNotice(r.title, title: n.title, body: n.body, name: name);
  final body = r.body.trim().isEmpty ? n.body : fillNotice(r.body, title: n.title, body: n.body, name: name);
  if (at == n.at && title == n.title && body == n.body) return n;
  return PlannedNotice(id: n.id, at: at, title: title.isEmpty ? n.title : title, body: body, reminderId: n.reminderId, gentle: n.gentle, repeat: n.repeat, every: n.every, early: n.early);
}

/// Summaries at the user's own times, and prayer/Ramadan times they asked
/// for, are never held back or counted.
bool _chosenByUser(String tag) =>
    tag.startsWith('${nudgeHabit}ask:') ||
    tag.startsWith(nudgeQuote) || tag.startsWith(nudgeFix) || tag == morningTag || tag == nightTag || tag.startsWith(nudgePrayer) || tag.startsWith(nudgeRamadan) || tag.startsWith(nudgeDonor);

int _rank(String tag) {
  // Our own notices first (owner, 27 Oct): a few a week, and the daily cap must not drop them.
  const order = ['nudge:srv:', 'nudge:plan:srv', morningTag, nightTag, nudgePrayer, nudgeRamadan, nudgeDue, nudgeTagada, nudgeBill, nudgeMed, nudgeDoc, nudgeBackup, nudgeDonor, nudgeDay2, '${nudgePlan}eve', nudgeSoon, nudgeSalary, nudgeSpend, nudgeNoCash, nudgePlan, nudgeHabit, nudgeBmi, nudgeJumuah, nudgeWeek, nudgeFest, nudgeHealth, nudgeBack];
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
  // Not before সুপ্রভাত (owner, 4 Nov): the day starts with the summary.
  final at = _at(day, p.morningOn && p.morningAt >= p.quietTo ? p.morningAt + noticeGap.inMinutes : p.quietTo);
  return PlannedNotice(id: n.id, at: at, title: n.title, body: n.body, reminderId: n.reminderId, gentle: true);
}

List<PlannedNotice> _summaries(AppData d, DateTime now, AssistantPrefs p) {
  final out = <PlannedNotice>[];
  final today = dayOnly(now);
  final hello = p.name.trim().isEmpty ? tr('সুপ্রভাত') : trf('সুপ্রভাত, {0}', [p.name.trim()]);

  if (p.morningOn) {
    for (var i = 0; i < 3; i++) {
      final day = today.add(Duration(days: i));
      final at = _at(day, p.morningAt);
      if (!at.isAfter(now)) continue;
      out.add(PlannedNotice(
        id: stableId('$morningTag:${dayKey(day)}'),
        at: at,
        title: hello,
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
        title: trf('আজকের {0}টা কাজ বাকি আছে', [bnDigits(left.length)]),
        body: trf('{0}। চাইলে কালকের তালিকায় সরিয়ে রাখি।', [left.take(3).map((t) => t.title).join(', ')]),
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
  for (final b in p.dueAlerts ? owed.take(10) : const <PersonBalance>[]) {
    final last = dayOnly(b.last!);
    for (var k = 1; k <= 6; k++) {
      final at = morningOf(last.add(Duration(days: 30 * k)));
      if (!at.isAfter(now)) continue;
      out.add(PlannedNotice(
        id: stableId('$nudgeDue${b.key}'),
        at: at,
        // No amount: it shows on the lock screen (owner, 13 Nov).
        title: trf('{0} মাস হলো, {1}-এর কাছে টাকা পাওনা', [bnDigits(k), b.name]),
        body: tr('চাইলে তাঁকে মনে করিয়ে দিতে একটা ভদ্র মেসেজ পাঠাতে পারেন।'),
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
      title: trf('পরশু {0} দেওয়ার শেষ দিন', [r.title]),
      body: trf('{0}, {1}। আজ-কালের মধ্যে দিয়ে দিলে নিশ্চিন্ত থাকবেন।', [weekdayName(due), shortDate(due)]),
      reminderId: '$nudgeBill${r.id}',
      gentle: true,
    ));
  }

  // Papers that run out: six months ahead (the reminder itself comes a month before).
  for (final x in d.docs) {
    final exp = x.expiry;
    if (exp == null || !p.docAlerts) continue;
    final at = morningOf(exp.subtract(const Duration(days: 182)));
    if (!at.isAfter(now)) continue;
    out.add(PlannedNotice(
      id: stableId('$nudgeDoc${x.id}'),
      at: at,
      title: trf('{0}-এর মেয়াদ আর ছয় মাস আছে', [x.title]),
      body: trf('{0}-এ শেষ হবে। সময় থাকতে কাগজপত্র গুছিয়ে রাখলে শেষ মুহূর্তে তাড়াহুড়া করতে হবে না।', [fullDate(exp)]),
      reminderId: '$nudgeDoc${x.id}',
      gentle: true,
    ));
  }

  // No backup for a month (or never, once there is something to lose): Friday late morning.
  final lastBackup = p.lastBackup;
  final worth = d.ledger.length + d.notes.length + d.vault.length + d.docs.length + d.cash.length >= 10;
  if (worth && (lastBackup == null || now.difference(lastBackup).inDays >= 30)) {
    var day = today;
    while (day.weekday != DateTime.friday) {
      day = day.add(const Duration(days: 1));
    }
    var at = _at(day, 11 * 60 + 30);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 7));
    out.add(PlannedNotice(
      id: stableId('$nudgeBackup:${dayKey(at)}'),
      at: at,
      title: lastBackup == null ? tr('আপনার তথ্যের ব্যাকআপ রেখে দিই?') : trf('শেষ ব্যাকআপ {0} দিন আগে', [bnDigits(now.difference(lastBackup).inDays)]),
      body: lastBackup == null ? tr('ফোন হারালে বা নষ্ট হলেও সব ফিরে পাবেন। এক মিনিটেই হয়ে যায়।') : tr('এরপর যা যা রেখেছেন, সেগুলোরও ব্যাকআপ রেখে দিই? এক মিনিট লাগবে।'),
      reminderId: nudgeBackup,
      gentle: true,
    ));
  }

  out.addAll(passwordNudges(d, now));

  // Medicine running low.
  for (final m in d.medicines) {
    final left = m.daysLeft;
    if (left == null || left > 5) continue;
    out.add(PlannedNotice(
      id: stableId('$nudgeMed${m.id}:$left'),
      at: nextMorning(),
      title: trf('{0} আর {1} দিনের আছে', [m.name, bnDigits(left)]),
      body: tr('ফুরিয়ে যাওয়ার আগেই কিনে রাখুন, যেন একদিনও বাদ না যায়।'),
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
    add(nudgeJumuah, dayKey(at), at, tr('জুমা মোবারক'), trf('আজ জুমার দিন, ওয়াক্ত শুরু {0}-এ। গোসল সেরে একটু আগে আগে মসজিদে যেতে পারলে ভালো।', [bnTime(dhuhr.hour, dhuhr.minute)]));
  }

  if (p.weekly) {
    // Saturday morning: the past week in two lines.
    final at = nextWeekday(DateTime.saturday, 10 * 60);
    final from = dayOnly(at).subtract(const Duration(days: 7));
    final spent = d.cash.where((c) => c.kind == CashKind.expense && c.projectId == null && !c.date.isBefore(from) && c.date.isBefore(dayOnly(at))).fold<int>(0, (a, c) => a + c.amount);
    final done = d.tasks.where((t) => t.done && t.doneAt != null && !t.doneAt!.isBefore(from)).length;
    final open = d.tasks.where((t) => !t.done).length;
    final health = spendHealth(d, dayOnly(at).subtract(const Duration(days: 1)));
    final parts = <String>[
      if (spent > 0) trf('খরচ {0}', [taka(spent)]),
      if (health.hasIncome && health.wants > 0) trf('শখের খরচ আয়ের {0}%', [bnDigits(health.pct(health.wants))]),
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

  // BMI above normal (owner, 24 Oct): a kind push twice a week, at 11:00 on
  // Monday and Thursday (was 7:30; owner, 4 Nov: the day starts with সুপ্রভাত) — one small step, never the number (it shows on the
  // lock screen).
  if (p.health) {
    for (final m in d.members) {
      final w = latest(d, m.id, HealthKind.weight);
      if (w == null || m.heightCm == null || m.heightCm! <= 0) continue;
      if (bmiOf(w.a, m.heightCm!) < 23) continue;
      for (final wd in const [DateTime.monday, DateTime.thursday]) {
        final at = nextWeekday(wd, 11 * 60);
        final n = at.difference(DateTime(2026)).inDays ~/ 3;
        final step = tr(bmiSteps[n % bmiSteps.length]);
        final who = m.isMe ? tr('আজ নিজের জন্য ছোট একটা ধাপ') : trf('{0}-এর জন্য ছোট একটা ধাপ', [m.relation.isNotEmpty ? m.relation : m.name]);
        add('$nudgeBmi${m.id}', dayKey(at), at, who, step);
      }
    }
  }

  if (p.festival) {
    for (var i = 0; i < 30; i++) {
      final day = today.add(Duration(days: i));
      final h = holidayOn(day);
      if (h == null || h.name.endsWith('ছুটি')) continue;
      final wish = _wishFor(h.name);
      if (wish == null) continue;
      add(nudgeFest, dayKey(day), _at(day, 8 * 60 + 30), wish, trf('আজ {0}। প্রিয়জনদের নিয়ে দিনটা আনন্দে কাটুক।', [h.label]));
      break;
    }
  }

  // "করেছেন কি?" for the habits the user asked it for (owner, 28 Oct): each
  // day at their time, the next three days, never on a day already ticked.
  for (final h in d.habits) {
    final m = h.askAt;
    if (m == null) continue;
    for (var i = 0; i < 3; i++) {
      final day = today.add(Duration(days: i));
      if (h.doneOn(day)) continue;
      add('${nudgeHabit}ask:${h.id}', dayKey(day), _at(day, m), trf('{0} — আজ হয়েছে?', [h.name]), tr('হয়ে থাকলে একটা টিক দিয়ে রাখুন।'));
    }
  }

  if (p.streak) {
    for (final h in d.habits) {
      final s = h.streak(now);
      // Asked "করেছেন কি?" at its own time already: no second note.
      if (s < 2 || h.doneOn(today) || h.askAt != null) continue;
      add(nudgeHabit, '${h.id}:${dayKey(today)}', _at(today, 20 * 60), trf('{1}: টানা {0} দিন, দারুণ!', [bnDigits(s), h.name]),
          tr('আজকেরটাও হয়ে গেলে টিক দিন, এভাবেই চলুক।'));
    }
  }

  final last = p.lastOpen;
  if (p.comeback && last != null) {
    final at = _at(dayOnly(last).add(const Duration(days: 3)), 10 * 60 + 30);
    final open = d.tasks.where((t) => !t.done).length;
    add(nudgeBack, dayKey(at), at, tr('অনেক দিন কথা হয়নি, কেমন আছেন?'),
        open > 0 ? trf('তালিকায় {0}টা কাজ বাকি আছে। নতুন কিছু মনে রাখার থাকলে বলবেন।', [bnDigits(open)]) : tr('নতুন কিছু মনে রাখার থাকলে শুধু বলবেন, আমি রেখে দেব।'));
  }

  // Asked for by the user: prayer times and Ramadan (sehri, iftar), for the next two days.
  for (var i = 0; i < 2; i++) {
    final day = today.add(Duration(days: i));
    final t = sunTimes(day, place);
    final names = {'fajr': (tr('ফজর'), t.fajr), 'dhuhr': (day.weekday == DateTime.friday ? tr('জুমা') : tr('জোহর'), t.dhuhr), 'asr': (tr('আসর'), t.asr), 'maghrib': (tr('মাগরিব'), t.maghrib), 'isha': (tr('এশা'), t.isha)};
    // "আসরের", not "আসর-এর" (owner, 13 Nov).
    final of = {'fajr': tr('ফজরের'), 'dhuhr': day.weekday == DateTime.friday ? tr('জুমার') : tr('জোহরের'), 'asr': tr('আসরের'), 'maghrib': tr('মাগরিবের'), 'isha': tr('এশার')};
    for (final k in p.prayers) {
      final v = names[k];
      if (v == null) continue;
      add('$nudgePrayer:$k', dayKey(day), v.$2, trf('{0} সময় হয়েছে', [of[k]!]), '${bnTime(v.$2.hour, v.$2.minute)}, ${place.label}');
    }
    if (p.ramadan && hijriDate(day).isRamadan) {
      final sehri = t.sehriEnd.subtract(const Duration(minutes: 40));
      add('$nudgeRamadan:sehri', dayKey(day), sehri, tr('সেহরির সময় হয়েছে'), trf('সেহরি শেষ হবে আনুমানিক {0}-এ।', [bnTime(t.sehriEnd.hour, t.sehriEnd.minute)]));
      final iftar = t.maghrib.subtract(const Duration(minutes: 10));
      add('$nudgeRamadan:iftar', dayKey(day), iftar, tr('ইফতারের সময় হয়ে আসছে'), trf('আনুমানিক {0}-এ ইফতার। আল্লাহ রোজা কবুল করুন।', [bnTime(t.maghrib.hour, t.maghrib.minute)]));
    }
  }

  if (p.quote) {
    // Every morning, the day's thought about money.
    for (var i = 0; i < 3; i++) {
      final day = today.add(Duration(days: i));
      final q = quoteFor(day);
      add(nudgeQuote, dayKey(day), _at(day, 9 * 60), tr('আজকের অর্থ-কথা'), quoteText(q));
    }
  }

  if (p.homeFix) {
    // A day off (Friday, Saturday, a holiday), mid-morning: the things at home to fix.
    final fixes = homeFixes(d);
    if (fixes.isNotEmpty) {
      for (var i = 0; i < 9; i++) {
        final day = today.add(Duration(days: i));
        if (holidayOn(day) == null && !isWeekend(day)) continue;
        final names = fixes.take(3).map((t) => t.title).join(', ');
        add(nudgeFix, dayKey(day), _at(day, 10 * 60), tr('ছুটির দিনে ঘরের কিছু কাজ সেরে নেবেন?'),
            trf('{0} — {1}টা ঠিক করা বাকি। একটা-দুটো সেরে ফেললেও স্বস্তি লাগবে।', [fixes.length > 3 ? '$names…' : names, bnDigits(fixes.length)]));
      }
    }
  }

  // The free Premium trial ends tomorrow (owner, 28 Oct): once, mid-morning the day before.
  final trial = p.trialEnds;
  if (trial != null) {
    add(nudgeTrial, dayKey(trial), _at(dayOnly(trial).subtract(const Duration(days: 1)), 10 * 60 + 30), tr('কাল প্রিমিয়ামের ট্রায়াল শেষ হচ্ছে'),
        tr('যা যা রেখেছেন, সবই আপনার থাকবে। সব সুবিধা চালু রাখতে চাইলে প্রিমিয়াম নিতে পারেন।'));
  }

  final donor = p.donorNext;
  if (donor != null) {
    add(nudgeDonor, dayKey(donor), _at(dayOnly(donor), 10 * 60), tr('আপনি আবার রক্ত দিতে পারবেন'), tr('শেষবারের পর যথেষ্ট সময় পার হয়েছে। কারও দরকারে আপনার এক ব্যাগ রক্ত একজনের জীবন বাঁচাতে পারে।'));
  }
  return out;
}

/// The day the password nudge first went out to everyone; a password already
/// six months old then is counted from this day (owner, 27 Oct).
final passNudgeStart = DateTime(2026, 10, 27);

/// A Friday or a government holiday, on or after [day].
DateTime nextFridayOrHoliday(DateTime day) {
  var x = dayOnly(day);
  while (x.weekday != DateTime.friday && holidayOn(x) == null) {
    x = x.add(const Duration(days: 1));
  }
  return x;
}

/// Passwords six months old (then twelve…): one gentle note on the first
/// Friday or holiday after, at 11:45 — the count only, never the names (the
/// lock screen shows it). Tapped, it opens the vault.
List<PlannedNotice> passwordNudges(AppData d, DateTime now) {
  final byDay = <DateTime, int>{};
  for (final v in d.vault) {
    if (v.password.isEmpty) continue;
    final next = nextDue(v, now);
    final last = next.subtract(passwordMaxAge);
    for (final due in [if (!last.isBefore(v.passwordSince.add(passwordMaxAge))) last, next]) {
      final from = due.isBefore(passNudgeStart) ? passNudgeStart : due;
      final day = nextFridayOrHoliday(from);
      if (_at(day, 12 * 60).isAfter(now)) byDay[day] = (byDay[day] ?? 0) + 1;
    }
  }
  final days = byDay.keys.toList()..sort();
  return [
    for (final day in days.take(2))
      PlannedNotice(
        id: stableId('$nudgePass:${dayKey(day)}'),
        at: _at(day, 12 * 60),
        title: byDay[day] == 1 ? tr('একটা পাসওয়ার্ড ছয় মাসের পুরোনো') : trf('{0}টা পাসওয়ার্ড ছয় মাসের পুরোনো', [bnDigits(byDay[day]!)]),
        body: tr('ছুটির দিনে একটু সময় করে বদলে নিলে অ্যাকাউন্ট নিরাপদ থাকে। কোনগুলো, ভল্টে দেখে নিন।'),
        reminderId: nudgePass,
        gentle: true,
      ),
  ];
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


/// A day off from [day] on: the run of Fridays, Saturdays and government
/// holidays together, and the name of its main holiday (null for a plain weekend).
(int, Holiday?) offRun(DateTime day) {
  bool off(DateTime x) => holidayOn(x) != null || isWeekend(x);
  var n = 0;
  final hs = <Holiday>[];
  for (var x = dayOnly(day); off(x) && n < 30; x = x.add(const Duration(days: 1))) {
    n++;
    final h = holidayOn(x);
    if (h != null) hs.add(h);
  }
  final main = hs.where((h) => !h.name.endsWith('ছুটি')).firstOrNull ?? hs.firstOrNull;
  return (n, main);
}

/// What is set for [day]: reminders that ring then and to-dos for that day.
List<(int, String)> _dayItems(AppData d, DateTime day) {
  final dd = dayOnly(day);
  return [
    for (final r in d.reminders)
      if (remindsOn(r, dd) && !r.repeat.isInterval && !d.specialDays.any((s) => s.reminderId == r.id)) (r.hour * 60 + r.minute, r.title),
    for (final t in d.tasks)
      if (!t.done && t.onDay(dd)) (24 * 60, t.title),
  ]..sort((a, b) => a.$1.compareTo(b.$1));
}

/// Asking about plans (tapped: the assistant listens and writes it down).
List<PlannedNotice> _plans(AppData d, DateTime now, AssistantPrefs p) {
  final out = <PlannedNotice>[];
  if (!p.plan) return out;
  final today = dayOnly(now);
  void add(String key, String day, DateTime at, String title, String body) {
    if (!at.isAfter(now)) return;
    out.add(PlannedNotice(id: stableId('$nudgePlan$key:$day'), at: at, title: title, body: body, reminderId: '$nudgePlan$key', gentle: true));
  }

  bool off(DateTime x) => holidayOn(x) != null || isWeekend(x);
  final eves = <DateTime>{};

  // The evening before a day off: Friday, or a holiday (with how many days).
  for (var i = 0; i < 9; i++) {
    final day = today.add(Duration(days: i));
    if (!off(day) || off(day.subtract(const Duration(days: 1)))) continue;
    final eve = day.subtract(const Duration(days: 1));
    eves.add(eve);
    final (n, h) = offRun(day);
    final String title;
    if (h != null) {
      title = n > 1 ? trf('কাল থেকে {0} দিনের ছুটি — {1}', [bnDigits(n), h.label]) : trf('কাল ছুটি — {0}', [h.label]);
    } else {
      title = day.weekday == DateTime.friday ? (n > 1 ? tr('কাল থেকে সাপ্তাহিক ছুটি') : tr('কাল শুক্রবার, ছুটির দিন')) : tr('কাল ছুটির দিন');
    }
    final body = n > 2
        ? tr('ছুটির দিনগুলো কীভাবে কাটাবেন? বলে রাখলে তালিকা আর রিমাইন্ডার গুছিয়ে দেব।')
        : tr('ছুটির দিনের কোনো পরিকল্পনা? বলে রাখলে লিখে রাখব, সময়মতো মনে করিয়ে দেব।');
    add('eve', dayKey(eve), _at(eve, 20 * 60 + 30), title, body);
  }

  // Sunday morning: a new week.
  for (var i = 0; i < 8; i++) {
    final day = today.add(Duration(days: i));
    if (day.weekday != DateTime.sunday || off(day) || day.day == 1) continue;
    final week = [for (var k = 0; k < 7; k++) ..._dayItems(d, day.add(Duration(days: k)))];
    add('week', dayKey(day), _at(day, 9 * 60 + 30), tr('নতুন সপ্তাহ শুরু হলো'),
        week.isEmpty
            ? tr('এ সপ্তাহে কী কী কাজ করতে চান? বলে রাখুন, তালিকা করে দেব।')
            : trf('এ সপ্তাহে {0}টা কাজ রাখা আছে। আর কিছু থাকলে বলুন।', [bnDigits(week.length)]));
    break;
  }

  // The 1st of the month: last month's spending, and this month's plan.
  final first = DateTime(today.year, today.month + 1, 1);
  for (final day in [DateTime(today.year, today.month, 1), first]) {
    final last = DateTime(day.year, day.month - 1);
    final spent = monthSumsOf(d, last);
    add('month', dayKey(day), _at(day, 9 * 60 + 30), trf('{0} মাস শুরু হলো', [monthName(day.month)]),
        spent > 0
            ? trf('গত মাসে খরচ হয়েছিল {0}। এ মাসের বাজেট আর বড় কাজগুলো বলে রাখলে মাসটা গোছানো থাকবে।', [taka(spent)])
            : tr('এ মাসের বিল, খরচ আর বড় কাজগুলো বলে রাখলে মাসটা গোছানো থাকবে।'));
  }

  // At night: tomorrow, unless the evening-before-a-day-off one comes, or
  // the night summary is already asking about today's leftovers.
  for (var i = 0; i < 2; i++) {
    final day = today.add(Duration(days: i));
    if (eves.contains(day)) continue;
    if (p.nightOn && tasksLeft(d, day).isNotEmpty) continue;
    final tomorrow = day.add(const Duration(days: 1));
    final items = _dayItems(d, tomorrow);
    final at = _at(day, (p.nightOn ? p.nightAt : 21 * 60) + 30);
    if (items.length >= 3) {
      final f = items.first;
      final firstText = f.$1 >= 24 * 60
          ? trf('প্রথমটা: {0}। আর কিছু থাকলে বলে রাখুন।', [f.$2])
          : trf('প্রথমটা {0}-এ: {1}। আর কিছু থাকলে বলে রাখুন।', [bnTime(f.$1 ~/ 60, f.$1 % 60), f.$2]);
      add('night', dayKey(day), at, trf('কাল {0}টা কাজ আছে', [bnDigits(items.length)]), firstText);
    } else if (items.isEmpty) {
      add('night', dayKey(day), at, tr('কালকের জন্য কিছু মনে রাখার আছে?'), tr('বলে রাখুন, সময়মতো মনে করিয়ে দেব।'));
    }
  }
  return out;
}

/// The list where things at home to fix are kept.
const homeFixList = 'ঘরের মেরামত';

/// "ফ্যান ঠিক করতে হবে", "বাথরুমের কল মেরামত", "মিস্ত্রি ডাকতে হবে".
bool isHomeFix(String text) {
  final t = text.toLowerCase();
  final fix = RegExp(r'ঠিক\s*কর|ঠিক\s*করা|সারা(?:তে|নো|ই)|মেরামত|রিপেয়ার|repair|fix|মিস্ত্রি|মিস্ত্রী|ইলেকট্রিশিয়ান|প্লাম্বার|নষ্ট|ভাঙা|ভেঙে|লিক|চুইয়ে|রং\s*কর|বদলা(?:তে|নো)|পাল্টা(?:তে|নো)');
  final thing = RegExp(r'ফ্যান|লাইট|বাল্ব|বাতি|সুইচ|সকেট|প্লাগ|পানির কল|কলের পানি|কলটা|কলের মুখ|ট্যাপ|পানির লাইন|পাইপ|বেসিন|কমোড|ফ্লাশ|বাথরুম|টয়লেট|রান্নাঘর|চুলা|গ্যাসের|দরজা|জানালা|জানলা|তালা|ছিটকিনি|ছাদ|দেয়াল|দেওয়াল|টাইলস|মেঝে|ফ্রিজ|টিভি|এসি|ওয়াশিং মেশিন|মোটর|পাম্প|ট্যাংক|ট্যাঙ্ক|খাট|চেয়ার|টেবিল|আলমারি|ওয়্যারিং|বিদ্যুতের তার|তারের|মিটার|আইপিএস|ইনভার্টার|গিজার|পর্দা|ঘর|বাসা|বাড়ি|ঘরের|বাসার|বাড়ির');
  return fix.hasMatch(t) && thing.hasMatch(t);
}

/// The open to-dos for fixing things at home: on the list, or plainly so.
List<Task> homeFixes(AppData d) => [
      for (final t in d.tasks)
        if (!t.done && (t.list == homeFixList || (t.due == null && isHomeFix(t.title)))) t
    ];

/// Personal spending in [month].
int monthSumsOf(AppData d, DateTime month) =>
    d.cash.where((e) => e.projectId == null && e.kind == CashKind.expense && e.date.year == month.year && e.date.month == month.month).fold(0, (a, e) => a + e.amount);

/// Things noticed in the user's own records.
List<PlannedNotice> _noticed(AppData d, DateTime now, AssistantPrefs p) {
  final out = <PlannedNotice>[];
  if (!p.smart) return out;
  final today = dayOnly(now);
  void add(String tag, String key, DateTime at, String title, String body) {
    if (!at.isAfter(now)) return;
    out.add(PlannedNotice(id: stableId('$tag:$key'), at: at, title: title, body: body, reminderId: tag, gentle: true));
  }

  // No spending written today (for someone who writes it down most days).
  final personal = [for (final e in d.cash) if (e.projectId == null) e];
  final recentDays = {for (final e in personal) if (!e.date.isBefore(today.subtract(const Duration(days: 14)))) dayKey(e.date)};
  if (recentDays.length >= 3 && !personal.any((e) => dayOnly(e.date) == today)) {
    add(nudgeNoCash, dayKey(today), _at(today, 20 * 60 + 30), tr('আজকের খরচগুলো লিখে রাখবেন?'), tr('এক কথায় বললেই হবে, যেমন “বাজারে ৫০০ টাকা”।'));
  }

  // A category this month already well past all of last month.
  final last = DateTime(today.year, today.month - 1);
  final lastBy = <String, int>{};
  for (final e in personal) {
    if (e.kind == CashKind.expense && e.date.year == last.year && e.date.month == last.month) lastBy[e.category] = (lastBy[e.category] ?? 0) + e.amount;
  }
  final thisMonth = [for (final e in personal) if (e.kind == CashKind.expense && e.date.year == today.year && e.date.month == today.month) e]..sort((a, b) => a.date.compareTo(b.date));
  final sum = <String, int>{};
  final told = <String>{};
  for (final e in thisMonth) {
    sum[e.category] = (sum[e.category] ?? 0) + e.amount;
    final before = lastBy[e.category] ?? 0;
    final now0 = sum[e.category]!;
    if (before <= 0 || told.contains(e.category) || now0 < before * 1.2 || now0 - before < 500) continue;
    told.add(e.category);
    add(nudgeSpend, '${monthKey(today)}:${e.category}', _at(dayOnly(e.date), 19 * 60 + 30), trf('এ মাসে {0}-এ খরচ একটু বেশি হচ্ছে', [tr(e.category)]),
        trf('এখন পর্যন্ত {0}, গত পুরো মাসে ছিল {1}। একবার দেখে নেবেন?', [taka(now0), taka(before)]));
  }

  // A birthday or anniversary the day after tomorrow (its own reminder comes a day before).
  for (final sd in d.specialDays) {
    if (sd.daysBefore >= 2) continue;
    final next = sd.next(today);
    final at = _at(next.subtract(const Duration(days: 2)), 19 * 60);
    add(nudgeDay2, '${sd.id}:${dayKey(next)}', at, trf('পরশু {0}', [specialTitle(sd, on: next)]),
        sd.kind == SpecialKind.deathday
            ? tr('দোয়া বা মিলাদের আয়োজন করতে চাইলে বলে রাখুন, মনে করিয়ে দেব।')
            : tr('উপহার বা শুভেচ্ছার কিছু ভাবছেন? বলে রাখলে মনে করিয়ে দেব।'));
  }

  // Salary in: put some aside.
  final salary = RegExp(r'বেতন|স্যালারি|salary', caseSensitive: false);
  for (final e in personal) {
    if (e.kind != CashKind.income || !(salary.hasMatch(e.category) || salary.hasMatch(e.note))) continue;
    if (today.difference(dayOnly(e.date)).inDays > 1) continue;
    final goal = d.goals.where((g) => g.deposits.fold<int>(0, (a, x) => a + x.amount) < g.target).firstOrNull;
    final body = goal == null
        ? tr('শুরুতেই অল্প কিছু সঞ্চয়ে সরিয়ে রাখলে মাসের শেষটা হালকা থাকে।')
        : trf('‘{0}’ পূরণে আর {1} বাকি। এ মাসে কিছু জমা রাখবেন?', [goal.name, taka(goal.target - goal.deposits.fold<int>(0, (a, x) => a + x.amount))]);
    var at = _at(dayOnly(e.date), 19 * 60);
    if (!at.isAfter(now)) at = _at(dayOnly(e.date).add(const Duration(days: 1)), 10 * 60);
    add(nudgeSalary, e.id, at, tr('বেতন এসেছে'), body);
    break;
  }

  // Eid and Ramadan, ten days ahead.
  for (final h in bdHolidays) {
    if (h.name != 'ঈদুল ফিতর' && h.name != 'ঈদুল আজহা') continue;
    final at = _at(dayOnly(h.date).subtract(const Duration(days: 10)), 10 * 60);
    add(nudgeSoon, dayKey(h.date), at, trf('আর ১০ দিন পর {0}', [h.label]),
        h.name == 'ঈদুল আজহা'
            ? tr('কোরবানি, কেনাকাটা আর বাড়ি যাওয়ার প্রস্তুতি — বলে রাখলে গুছিয়ে তালিকা করে দেব।')
            : tr('কেনাকাটা আর বাড়ি যাওয়ার প্রস্তুতি — বলে রাখলে গুছিয়ে তালিকা করে দেব।'));
  }
  for (var i = 1; i < 60; i++) {
    final day = today.add(Duration(days: i));
    if (!hijriDate(day).isRamadan || hijriDate(day.subtract(const Duration(days: 1))).isRamadan) continue;
    add(nudgeSoon, 'ramadan:${dayKey(day)}', _at(day.subtract(const Duration(days: 10)), 10 * 60), tr('আর ১০ দিন পর রমজান'),
        tr('রমজানের বাজার, যাকাতের হিসাব আর সেহরি-ইফতারের প্রস্তুতি এখন থেকেই একটু একটু গুছিয়ে নিতে পারেন।'));
    break;
  }
  return out;
}


/// Small, kind steps for a weight above normal (one per notice, in turn).
const bmiSteps = [
  'আজ ২০ মিনিট হাঁটুন — ছোট ছোট পা-ই বড় বদল আনে।',
  'পানি বেশি, চিনি কম — আজ একটা মিষ্টি পানীয় বাদ দিয়ে দেখুন।',
  'প্লেটের অর্ধেক সবজি রাখুন — পেট ভরবে, ভাত লাগবে কম।',
  'লিফট নয়, সিঁড়ি — প্রতিটা ধাপই কাজে লাগে।',
  'রাতের খাবার একটু আগে আর একটু কম — ঘুমও ভালো হবে।',
  'সপ্তাহে আধা কেজি কমানোই যথেষ্ট — ধীরে, কিন্তু নিয়মিত।',
  'ভাজাপোড়ার বদলে আজ ফল খান — শরীর ধন্যবাদ দেবে।',
  'নামাজের পর ১০ মিনিট হাঁটা — অভ্যাস হয়ে গেলে আর কষ্ট লাগবে না।',
];
