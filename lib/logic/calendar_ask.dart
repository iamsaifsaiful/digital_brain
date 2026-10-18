/// Questions the calendar answers on the phone: the government holidays
/// ("এ মাসে কী কী ছুটি আছে?", "পরের ছুটি কবে?", "ঈদ কবে?", "১৬ ডিসেম্বর
/// কিসের ছুটি?") and dates ("কাল কত তারিখ?", "২১ ফেব্রুয়ারি কী বার?",
/// "আজ বাংলা কত তারিখ?"). Nothing goes to the internet or the AI.
library;

import 'bn.dart';
import 'calendar_bd.dart';
import 'lang.dart';
import 'meaning.dart' show tidySpeech;
import 'parser.dart' show fold, normalize;
import 'when.dart';

bool _has(String f, String p) => RegExp(fold(p)).hasMatch(f);

// A question, not a statement ("শুক্রবার অফিসে যাব না, ছুটি আছে" tells).
const _ask = r'(?:কী|কি|কবে|কত|কয়|কোন|কোনো|কোনটা|কিসের|কীসের|নাকি|তালিকা|লিস্ট|দেখাও|বলো|বলুন|জানাও|\?)';

// Named days people ask about by name.
const _named = {
  'ঈদ': ['ঈদ'],
  'ঈদুল ফিতর': ['ঈদুল ফিতর', 'রোজার ঈদ', 'ছোট ঈদ'],
  'ঈদুল আজহা': ['ঈদুল আজহা', 'কোরবানির ঈদ', 'কুরবানির ঈদ', 'বড় ঈদ', 'কোরবানি'],
  'দুর্গাপূজা': ['পূজা', 'পুজা', 'দুর্গাপূজা', 'দুর্গা পূজা'],
  'বিজয় দিবস': ['বিজয় দিবস'],
  'স্বাধীনতা': ['স্বাধীনতা দিবস'],
  'শহীদ দিবস': ['শহীদ দিবস', 'একুশে ফেব্রুয়ারি', 'ভাষা দিবস', 'মাতৃভাষা দিবস'],
  'বাংলা নববর্ষ': ['পহেলা বৈশাখ', 'নববর্ষ'],
  'বড়দিন': ['বড়দিন', 'বড় দিন', 'ক্রিসমাস'],
  'শবে বরাত': ['শবে বরাত', 'শবেবরাত'],
  'শবে কদর': ['শবে কদর', 'শবেকদর'],
  'আশুরা': ['আশুরা'],
  'মিলাদুন্নবী': ['ঈদে মিলাদুন্নবী', 'মিলাদুন্নবী'],
  'জন্মাষ্টমী': ['জন্মাষ্টমী'],
  'মে দিবস': ['মে দিবস'],
  'বুদ্ধপূর্ণিমা': ['বুদ্ধপূর্ণিমা', 'বুদ্ধ পূর্ণিমা'],
  'জুলাই গণঅভ্যুত্থান': ['জুলাই গণঅভ্যুত্থান', 'গণঅভ্যুত্থান দিবস'],
};

String? _namedIn(String f) {
  for (final e in _named.entries) {
    if (e.value.any((x) => f.contains(fold(x)))) return e.key;
  }
  return null;
}

/// Is [said] (tidied) a question for the calendar?
bool calendarAsked(String said) {
  // (Tidied first: "নভেম্বরে" → "নভেম্বর" before the word rules see it.)
  final f = ' ${fold(normalize(tidySpeech(said)))} ';
  final asking = _has(f, _ask);
  if (!asking) return false;
  // Holidays: "ছুটি" asked about, or a holiday named with "কবে".
  if (_has(f, r'(?:ছুটি|হলিডে|holiday)') && !_has(f, r'(?:ছুটি\s+(?:নেব|নিব|নিলাম|নিয়েছি|চাই|দাও|লাগবে)|ছুটির\s+আবেদন|অফিসে\s+ছুটি)')) return true;
  if (_namedIn(f) != null && _has(f, r'(?:কবে|কত\s+তারিখ|কোন\s+দিন|কী\s+বার|কি\s+বার|কয়\s+তারিখ)')) return true;
  // Dates: "কত তারিখ", "তারিখ কত", "কী বার", "কোন বার", with a day.
  if (_has(f, r'(?:কত\s+তারিখ|তারিখ\s+কত|কয়\s+তারিখ|কী\s+বার|কি\s+বার|কোন\s+বার|বাংলা\s+(?:কত\s+)?তারিখ|আরবি\s+(?:কত\s+)?তারিখ|হিজরি\s+(?:কত\s+)?তারিখ)') &&
      !_has(f, r'(?:জন্মদিন|বিল|মিটিং|কিস্তি|রিমাইন্ডার|কাজ|মেয়াদ|পরীক্ষা)')) {
    return true;
  }
  return false;
}

/// Only today's date asked ("আজ বাংলা কত তারিখ?"): the plain date answer.
bool calendarTodayOnly(String said, DateTime now) {
  final f = ' ${fold(normalize(tidySpeech(said)))} ';
  if (_has(f, r'(?:ছুটি|হলিডে|holiday)') || _namedIn(f) != null) return false;
  final w = parseWhen(tidySpeech(said), now);
  return w == null || !w.hasDay || (w.day.year == now.year && w.day.month == now.month && w.day.day == now.day);
}

String _line(Holiday h, DateTime today) {
  final note = [
    if (h.executive) tr('নির্বাহী আদেশে'),
    if (h.tentative) tr('চাঁদ দেখার ওপর নির্ভর'),
    if (h.date.isBefore(today)) tr('চলে গেছে'),
  ];
  return '• ${weekdayName(h.date)}, ${bnDigits(h.date.day)} ${monthName(h.date.month)} — ${h.label}${note.isEmpty ? '' : ' (${note.join(', ')})'}';
}

String _runText(HolidayRun r) => r.days == 1
    ? trf('{0}, {1} {2} — {3}', [weekdayName(r.start), bnDigits(r.start.day), monthName(r.start.month), r.label])
    : trf('{0} {1} থেকে {2} {3} — {4} ({5} দিন, সাপ্তাহিক ছুটিসহ)', [bnDigits(r.start.day), monthName(r.start.month), bnDigits(r.end.day), monthName(r.end.month), r.label, bnDigits(r.days)]);

/// The month the question is about: "এ মাসে", "আগামী মাসে", "নভেম্বরে",
/// "ডিসেম্বর মাসে"; null when none is named.
(int, int, String)? _monthAsked(String f, DateTime now) {
  if (_has(f, r'(?:এ|এই|চলতি)\s+মাস')) return (now.year, now.month, tr('এই মাসে'));
  if (_has(f, r'(?:আগামী|পরের|সামনের|next)\s+মাস')) {
    final d = DateTime(now.year, now.month + 1);
    return (d.year, d.month, tr('আগামী মাসে'));
  }
  if (_has(f, r'(?:গত|আগের)\s+মাস')) {
    final d = DateTime(now.year, now.month - 1);
    return (d.year, d.month, tr('গত মাসে'));
  }
  for (var m = 1; m <= 12; m++) {
    if (f.contains(' ${fold(bnMonths[m - 1])}')) {
      // The coming one: a month already gone this year is next year's.
      final y = m < now.month ? now.year + 1 : now.year;
      return (y, m, '${monthName(m)}${tr('-এ')}');
    }
  }
  return null;
}

String calendarAnswer(String said0, DateTime now) {
  final said = tidySpeech(said0);
  final f = ' ${fold(normalize(said))} ';
  final today = DateTime(now.year, now.month, now.day);
  final w = parseWhen(said, now);
  final day = w != null && w.hasDay ? DateTime(w.day.year, w.day.month, w.day.day) : null;
  final holidayAsked = _has(f, r'(?:ছুটি|হলিডে|holiday)');

  // "ঈদ কবে?", "পূজার ছুটি কবে?"
  final named = _namedIn(f);
  if (named != null && (holidayAsked || _has(f, r'(?:কবে|তারিখ|বার)')) && day == null) {
    final key = fold(named == 'ঈদ' ? 'ঈদ' : named);
    final hits = [for (final h in bdHolidays) if (fold(h.name).contains(key) && !h.date.isBefore(today)) h];
    if (hits.isEmpty) return trf('সামনে “{0}”-এর তারিখ আমার ক্যালেন্ডারে এখনো নেই — নতুন বছরের সরকারি তালিকা এলে যোগ হবে।', [named]);
    final runs = upcomingHolidays(today, count: 30).where((r) => fold(r.name).contains(key) || hits.any((h) => !h.date.isBefore(r.start) && !h.date.isAfter(r.end))).toList();
    final h = hits.first;
    final left = h.date.difference(today).inDays;
    final when = left == 0 ? tr('আজই') : (left == 1 ? tr('কালই') : trf('আর {0} দিন পর', [bnDigits(left)]));
    final run = runs.isEmpty ? '' : trf(' ছুটি: {0}।', [_runText(runs.first)]);
    return trf('{0}: {1}, {2} {3} {4} — {5}।{6}{7}', [h.label, weekdayName(h.date), bnDigits(h.date.day), monthName(h.date.month), bnDigits(h.date.year), when, run, h.tentative ? tr(' (চাঁদ দেখার ওপর নির্ভর করে এক দিন আগে-পরে হতে পারে।)') : '']);
  }

  if (holidayAsked) {
    // "১৬ ডিসেম্বর কিসের ছুটি?", "কাল কি ছুটি?"
    if (day != null && !_has(f, r'(?:মাস|বছর)')) {
      final h = holidayOn(day);
      final when = '${weekdayName(day)}, ${bnDigits(day.day)} ${monthName(day.month)}';
      if (h != null) return trf('{0} — ছুটি: {1}{2}।', [when, h.label, h.executive ? tr(' (নির্বাহী আদেশে)') : '']);
      if (isWeekend(day)) return trf('{0} — সাপ্তাহিক ছুটি (শুক্র-শনিবার); সরকারি কোনো বিশেষ ছুটি নেই।', [when]);
      return trf('{0} — কোনো সরকারি ছুটি নেই।', [when]);
    }
    // "এ বছর কয়টা ছুটি?"
    if (_has(f, r'(?:এ|এই)\s+বছর')) {
      final list = [for (final h in bdHolidays) if (h.date.year == now.year) h];
      final left = list.where((h) => !h.date.isBefore(today)).length;
      return trf('{0} সালে সরকারি ছুটি {1} দিন (শুক্র-শনিবার বাদে); এর মধ্যে সামনে বাকি {2} দিন।', [bnDigits(now.year), bnDigits(list.length), bnDigits(left)]);
    }
    // "এ মাসে কী কী ছুটি আছে?", "নভেম্বরে ছুটি আছে?"
    final m = _monthAsked(f, now);
    if (m != null) {
      final (y, mo, label) = m;
      final list = [for (final h in bdHolidays) if (h.date.year == y && h.date.month == mo) h];
      var weekends = 0;
      for (var d = DateTime(y, mo, 1); d.month == mo; d = d.add(const Duration(days: 1))) {
        if (isWeekend(d)) weekends++;
      }
      if (list.isEmpty) {
        final known = bdHolidays.any((h) => h.date.year == y);
        return known
            ? trf('{0} কোনো সরকারি ছুটি নেই — শুধু শুক্র-শনিবারের সাপ্তাহিক ছুটি ({1} দিন)।', [label, bnDigits(weekends)])
            : trf('{0} সালের সরকারি ছুটির তালিকা এখনো আমার ক্যালেন্ডারে নেই।', [bnDigits(y)]);
      }
      return trf('{0} সরকারি ছুটি {1} দিন:\n{2}\nএছাড়া শুক্র-শনিবার সাপ্তাহিক ছুটি ({3} দিন)।', [label, bnDigits(list.length), list.map((h) => _line(h, today)).join('\n'), bnDigits(weekends)]);
    }
    // "পরের ছুটি কবে?", "সামনে কী কী ছুটি আছে?"
    final runs = upcomingHolidays(today, count: _has(f, r'(?:পরের|পরবর্তী|next)') && !_has(f, r'(?:কী\s+কী|কি\s+কি|গুলো|তালিকা)') ? 1 : 4);
    if (runs.isEmpty) return tr('সামনের সরকারি ছুটির তালিকা এখনো আমার ক্যালেন্ডারে নেই।');
    if (runs.length == 1) return trf('পরের সরকারি ছুটি: {0}।', [_runText(runs.single)]);
    return trf('সামনের সরকারি ছুটি:\n{0}', [runs.map((r) => '• ${_runText(r)}').join('\n')]);
  }

  // Dates: "কাল কত তারিখ?", "২১ ফেব্রুয়ারি কী বার?", "আজ বাংলা কত তারিখ?"
  final d = day ?? today;
  final left = d.difference(today).inDays;
  final which = left == 0 ? tr('আজ') : (left == 1 ? tr('কাল') : (left == -1 ? tr('গতকাল') : (left == 2 ? tr('পরশু') : '')));
  final h = holidayOn(d);
  final extra = h != null ? trf(' সেদিন ছুটি: {0}।', [h.label]) : '';
  return trf('{0}{1}, {2}। বাংলায় {3}; আরবি তারিখ {4}।{5}', [which.isEmpty ? '' : '$which ', weekdayName(d), fullDate(d), banglaDate(d).text, hijriDate(d).text, extra]);
}
