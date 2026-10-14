/// Bangla date and season (Bangladesh's revised calendar), sunrise, sunset
/// and prayer times for a place in Bangladesh, and the government holidays.
/// Everything is worked out on the phone, without the internet.
library;

import 'dart:math';

import 'bn.dart';
import 'lang.dart';

const banglaMonths = ['বৈশাখ', 'জ্যৈষ্ঠ', 'আষাঢ়', 'শ্রাবণ', 'ভাদ্র', 'আশ্বিন', 'কার্তিক', 'অগ্রহায়ণ', 'পৌষ', 'মাঘ', 'ফাল্গুন', 'চৈত্র'];
const banglaSeasons = ['গ্রীষ্ম', 'বর্ষা', 'শরৎ', 'হেমন্ত', 'শীত', 'বসন্ত'];
const banglaMonthsEn = ['Boishakh', 'Joishtho', 'Asharh', 'Shrabon', 'Bhadro', 'Ashwin', 'Kartik', 'Ogrohayon', 'Poush', 'Magh', 'Falgun', 'Choitro'];
const banglaSeasonsEn = ['Summer', 'Monsoon', 'Autumn', 'Late autumn', 'Winter', 'Spring'];

class BanglaDate {
  const BanglaDate(this.year, this.month, this.day);
  final int year;

  /// 0 = বৈশাখ … 11 = চৈত্র.
  final int month;
  final int day;

  String get monthName => isEn ? banglaMonthsEn[month] : banglaMonths[month];

  /// "শরৎ" — two months to a season.
  String get season => isEn ? banglaSeasonsEn[month ~/ 2] : banglaSeasons[month ~/ 2];

  /// "২৮ আশ্বিন ১৪৩৩".
  String get text => '${bnDigits(day)} $monthName ${bnDigits(year)}';
  String get dayMonth => '${bnDigits(day)} $monthName';
}

bool _leap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

/// The revised Bangladesh calendar (2019): ১ বৈশাখ is 14 April; বৈশাখ to
/// আশ্বিন have 31 days, ফাল্গুন 29 (30 in a leap year), the rest 30. So
/// ২১ ফেব্রুয়ারি is always ৮ ফাল্গুন and ১৬ ডিসেম্বর ১ পৌষ.
BanglaDate banglaDate(DateTime g) {
  final d = DateTime.utc(g.year, g.month, g.day);
  final startYear = (d.month > 4 || (d.month == 4 && d.day >= 14)) ? g.year : g.year - 1;
  final start = DateTime.utc(startYear, 4, 14);
  var left = d.difference(start).inDays;
  final lengths = [31, 31, 31, 31, 31, 31, 30, 30, 30, 30, _leap(startYear + 1) ? 30 : 29, 30];
  var m = 0;
  while (m < 11 && left >= lengths[m]) {
    left -= lengths[m];
    m++;
  }
  return BanglaDate(startYear - 593, m, left + 1);
}

/// The first day of the next Bangla month after [g] (for "৪ দিন পর ১ কার্তিক").
DateTime nextBanglaMonthStart(DateTime g) {
  var d = DateTime(g.year, g.month, g.day);
  final m = banglaDate(d).month;
  for (var i = 0; i < 32; i++) {
    d = d.add(const Duration(days: 1));
    if (banglaDate(d).month != m) return d;
  }
  return d;
}

// ── Places, sun and prayer times ──

class Place {
  const Place(this.name, this.lat, this.lon);
  final String name;

  /// The name in the app's language.
  String get label => tr(name);
  final double lat;
  final double lon;
}

const bdPlaces = [
  Place('ঢাকা', 23.8103, 90.4125),
  Place('চট্টগ্রাম', 22.3569, 91.7832),
  Place('খুলনা', 22.8456, 89.5403),
  Place('রাজশাহী', 24.3745, 88.6042),
  Place('সিলেট', 24.8949, 91.8687),
  Place('বরিশাল', 22.7010, 90.3535),
  Place('রংপুর', 25.7439, 89.2752),
  Place('ময়মনসিংহ', 24.7471, 90.4203),
  Place('কুমিল্লা', 23.4607, 91.1809),
  Place('গাজীপুর', 23.9999, 90.4203),
  Place('নারায়ণগঞ্জ', 23.6238, 90.5000),
  Place('বগুড়া', 24.8465, 89.3773),
  Place('কক্সবাজার', 21.4272, 92.0058),
  Place('যশোর', 23.1664, 89.2081),
  Place('নোয়াখালী', 22.8696, 91.0995),
  Place('ফেনী', 23.0159, 91.3976),
  Place('দিনাজপুর', 25.6217, 88.6354),
  Place('টাঙ্গাইল', 24.2513, 89.9167),
  Place('পাবনা', 24.0064, 89.2372),
  Place('কুষ্টিয়া', 23.9013, 89.1205),
  Place('ফরিদপুর', 23.6070, 89.8429),
  Place('ব্রাহ্মণবাড়িয়া', 23.9571, 91.1115),
  Place('চাঁদপুর', 23.2333, 90.6713),
  Place('সিরাজগঞ্জ', 24.4534, 89.7007),
];

Place placeNamed(String name) => bdPlaces.firstWhere((p) => p.name == name, orElse: () => bdPlaces.first);

class SunTimes {
  const SunTimes({required this.sunrise, required this.sunset, required this.fajr, required this.dhuhr, required this.asr, required this.maghrib, required this.isha});
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime fajr;
  final DateTime dhuhr;

  /// Hanafi (shadow twice the length), as used in Bangladesh.
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
}

double _rad(double d) => d * pi / 180;
double _deg(double r) => r * 180 / pi;

/// Sun and prayer times (Bangladesh time, UTC+6) for [day] at [p]:
/// Fajr and Isha at 18° (Karachi method), Asr Hanafi. Accurate to a
/// minute or two.
SunTimes sunTimes(DateTime day, Place p) {
  final jd = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2000, 1, 1, 12)).inHours / 24.0;
  final g = _rad((357.529 + 0.98560028 * jd) % 360);
  final q = (280.459 + 0.98564736 * jd) % 360;
  final l = _rad((q + 1.915 * sin(g) + 0.020 * sin(2 * g)) % 360);
  final e = _rad(23.439 - 0.00000036 * jd);
  final ra = (_deg(atan2(cos(e) * sin(l), cos(l))) / 15) % 24;
  final dec = asin(sin(e) * sin(l));
  var eqt = q / 15 - ra;
  if (eqt > 12) eqt -= 24;
  if (eqt < -12) eqt += 24;
  final noon = 12 + 6 - p.lon / 15 - eqt;
  final lat = _rad(p.lat);
  double t(double angle) {
    final c = (-sin(_rad(angle)) - sin(lat) * sin(dec)) / (cos(lat) * cos(dec));
    return _deg(acos(c.clamp(-1.0, 1.0))) / 15;
  }

  final asrAngle = -_deg(atan(1 / (2 + tan((lat - dec).abs()))));
  DateTime at(double h) {
    final mins = (h * 60).round();
    return DateTime(day.year, day.month, day.day).add(Duration(minutes: mins));
  }

  return SunTimes(
    sunrise: at(noon - t(0.833)),
    sunset: at(noon + t(0.833)),
    fajr: at(noon - t(18)),
    dhuhr: at(noon + 1 / 60),
    asr: at(noon + t(asrAngle)),
    maghrib: at(noon + t(0.833) + 2 / 60),
    isha: at(noon + t(18)),
  );
}

// ── Holidays ──

class Holiday {
  const Holiday(this.date, this.name, {this.executive = false, this.tentative = false});

  /// The name in the app's language.
  String get label => tr(name);
  final DateTime date;
  final String name;

  /// By executive order (নির্বাহী আদেশে).
  final bool executive;

  /// Depends on the moon, or next year's list is not out yet.
  final bool tentative;
}

/// The government's holiday list. 2026 from the official list (Durga Puja
/// extended to 22 Oct); 2027 has only the fixed dates until the list is out.
final bdHolidays = <Holiday>[
  Holiday(DateTime(2026, 2, 4), 'শবে বরাত', executive: true, tentative: true),
  Holiday(DateTime(2026, 2, 21), 'শহীদ দিবস ও আন্তর্জাতিক মাতৃভাষা দিবস'),
  Holiday(DateTime(2026, 3, 17), 'শবে কদর', executive: true, tentative: true),
  Holiday(DateTime(2026, 3, 19), 'ঈদুল ফিতরের ছুটি', executive: true, tentative: true),
  Holiday(DateTime(2026, 3, 20), 'জুমাতুল বিদা ও ঈদুল ফিতরের ছুটি', tentative: true),
  Holiday(DateTime(2026, 3, 21), 'ঈদুল ফিতর', tentative: true),
  Holiday(DateTime(2026, 3, 22), 'ঈদুল ফিতরের ছুটি', executive: true, tentative: true),
  Holiday(DateTime(2026, 3, 23), 'ঈদুল ফিতরের ছুটি', executive: true, tentative: true),
  Holiday(DateTime(2026, 3, 26), 'স্বাধীনতা ও জাতীয় দিবস'),
  Holiday(DateTime(2026, 4, 14), 'বাংলা নববর্ষ', executive: true),
  Holiday(DateTime(2026, 5, 1), 'মে দিবস ও বুদ্ধপূর্ণিমা'),
  Holiday(DateTime(2026, 5, 26), 'ঈদুল আজহার ছুটি', executive: true, tentative: true),
  Holiday(DateTime(2026, 5, 27), 'ঈদুল আজহার ছুটি', executive: true, tentative: true),
  Holiday(DateTime(2026, 5, 28), 'ঈদুল আজহা', tentative: true),
  Holiday(DateTime(2026, 5, 29), 'ঈদুল আজহার ছুটি', executive: true, tentative: true),
  Holiday(DateTime(2026, 5, 30), 'ঈদুল আজহার ছুটি', executive: true, tentative: true),
  Holiday(DateTime(2026, 5, 31), 'ঈদুল আজহার ছুটি', executive: true, tentative: true),
  Holiday(DateTime(2026, 6, 26), 'আশুরা', executive: true, tentative: true),
  Holiday(DateTime(2026, 8, 5), 'জুলাই গণঅভ্যুত্থান দিবস'),
  Holiday(DateTime(2026, 8, 26), 'ঈদে মিলাদুন্নবী (সা.)', tentative: true),
  Holiday(DateTime(2026, 9, 4), 'জন্মাষ্টমী'),
  Holiday(DateTime(2026, 10, 20), 'দুর্গাপূজা (মহানবমী)', executive: true),
  Holiday(DateTime(2026, 10, 21), 'দুর্গাপূজা (বিজয়া দশমী)'),
  Holiday(DateTime(2026, 10, 22), 'দুর্গাপূজার ছুটি', executive: true),
  Holiday(DateTime(2026, 12, 16), 'মহান বিজয় দিবস'),
  Holiday(DateTime(2026, 12, 25), 'বড়দিন'),
  Holiday(DateTime(2027, 2, 21), 'শহীদ দিবস ও আন্তর্জাতিক মাতৃভাষা দিবস', tentative: true),
  Holiday(DateTime(2027, 3, 26), 'স্বাধীনতা ও জাতীয় দিবস', tentative: true),
  Holiday(DateTime(2027, 4, 14), 'বাংলা নববর্ষ', tentative: true),
  Holiday(DateTime(2027, 5, 1), 'মে দিবস', tentative: true),
  Holiday(DateTime(2027, 8, 5), 'জুলাই গণঅভ্যুত্থান দিবস', tentative: true),
  Holiday(DateTime(2027, 12, 16), 'মহান বিজয় দিবস', tentative: true),
  Holiday(DateTime(2027, 12, 25), 'বড়দিন', tentative: true),
];

Holiday? holidayOn(DateTime day) {
  for (final h in bdHolidays) {
    if (h.date.year == day.year && h.date.month == day.month && h.date.day == day.day) return h;
  }
  return null;
}

/// Friday and Saturday are the weekly holidays.
bool isWeekend(DateTime d) => d.weekday == DateTime.friday || d.weekday == DateTime.saturday;

/// A run of holidays together, e.g. দুর্গাপূজা 20–24 Oct with the weekend.
class HolidayRun {
  const HolidayRun(this.start, this.end, this.name);

  /// The name in the app's language.
  String get label => tr(name);
  final DateTime start;
  final DateTime end;
  final String name;
  int get days => end.difference(start).inDays + 1;
}

/// The coming holidays from [today] on, joined with weekends next to them.
List<HolidayRun> upcomingHolidays(DateTime today, {int count = 6}) {
  final day0 = DateTime(today.year, today.month, today.day);
  final out = <HolidayRun>[];
  final used = <DateTime>{};
  for (final h in bdHolidays) {
    if (h.date.isBefore(day0) || used.contains(h.date)) continue;
    var start = h.date;
    var end = h.date;
    bool off(DateTime d) => holidayOn(d) != null || isWeekend(d);
    while (off(start.subtract(const Duration(days: 1))) && !start.subtract(const Duration(days: 1)).isBefore(day0)) {
      start = start.subtract(const Duration(days: 1));
    }
    while (off(end.add(const Duration(days: 1)))) {
      end = end.add(const Duration(days: 1));
    }
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      used.add(DateTime(d.year, d.month, d.day));
    }
    // Name the run after its main day (not "…ছুটি").
    final main = [for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) holidayOn(d)].whereType<Holiday>().toList();
    final named = main.firstWhere((x) => !x.name.endsWith('ছুটি'), orElse: () => main.first);
    out.add(HolidayRun(start, end, named.name));
    if (out.length >= count) break;
  }
  return out;
}

// ───────────────────────── Hijri (Arabic) date ─────────────────────────

const hijriMonths = ['মহররম', 'সফর', 'রবিউল আউয়াল', 'রবিউস সানি', 'জমাদিউল আউয়াল', 'জমাদিউস সানি', 'রজব', 'শাবান', 'রমজান', 'শাওয়াল', 'জিলকদ', 'জিলহজ'];
const hijriMonthsEn = ['Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani', 'Jumada al-Awwal', 'Jumada al-Thani', 'Rajab', "Sha'ban", 'Ramadan', 'Shawwal', "Dhu al-Qa'dah", 'Dhu al-Hijjah'];

/// The user's correction for the moon seen here (সেটিংস / ক্যালেন্ডার), in days.
int hijriAdjust = 0;

class HijriDate {
  const HijriDate(this.year, this.month, this.day);
  final int year;

  /// 1 (Muharram) … 12 (Dhu al-Hijjah).
  final int month;
  final int day;

  String get monthName => isEn ? hijriMonthsEn[month - 1] : hijriMonths[month - 1];

  /// "২ জমাদিউল আউয়াল ১৪৪৮ হিজরি".
  String get text => isEn ? '$day $monthName $year AH' : '${bnDigits(day)} $monthName ${bnDigits(year)} হিজরি';
  String get dayMonth => '${bnDigits(day)} $monthName';
  bool get isRamadan => month == 9;
}

/// The Hijri date of [d], by the arithmetic (tabular) calendar, moved by
/// [adjust] days for the local moon sighting (সেটিংস: −২ … +২). In
/// Bangladesh the months begin with the moon seen here, so a day either
/// way is normal.
HijriDate hijriDate(DateTime d, {int? adjust}) {
  final g = DateTime.utc(d.year, d.month, d.day).add(Duration(days: adjust ?? hijriAdjust));
  // Julian day number of the date.
  final a = (14 - g.month) ~/ 12;
  final y = g.year + 4800 - a;
  final m = g.month + 12 * a - 3;
  final jd = g.day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
  var l = jd - 1948440 + 10632;
  final n = (l - 1) ~/ 10631;
  l = l - 10631 * n + 354;
  final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) + (l ~/ 5670) * ((43 * l) ~/ 15238);
  l = l - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) - (j ~/ 16) * ((15238 * j) ~/ 43) + 29;
  final month = (24 * l) ~/ 709;
  final day = l - (709 * month) ~/ 24;
  final year = 30 * n + j - 30;
  return HijriDate(year, month, day);
}
