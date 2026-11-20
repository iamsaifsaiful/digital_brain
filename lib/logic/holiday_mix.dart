// সামনের ছুটি with several lists at once (owner, 19 Nov: "আন্তর্জাতিক ছুটি
// এবং অভ্যন্তরীণ ছুটি … প্রবাসীদের জন্যে … অন্তত দুটি দেশের ছুটির তারিখ").
// The member keeps a few lists: the country of the profile location ('@'),
// any other country by its two letters, and the international days
// ('INTL'). Home shows them in one list by date; a chip hides or shows each.
library;

import 'calendar_bd.dart' show HolidayRun, upcomingHolidays;
import 'countries.dart' show countryOf, findCountries;
import 'holidays_abroad.dart' show AbroadHoliday;
import 'lang.dart' show isEn, tr;

/// The country the profile location is in.
const holAuto = '@';

/// The international days.
const holIntl = 'INTL';

/// What a new member sees: only the profile location's country (owner,
/// 20 Nov: "লোকেশন অনুযায়ী ডিফল্ট ছুটির তারিখ দেখাবে। পরে চাইলে ইউজার অন্য
/// দেশ যুক্ত করবে"); Bangladesh and the international days are a tick away.
const holDefault = [holAuto];

/// At most this many countries at once (owner, 20 Nov: "এক সাথে তিনটির
/// বেশি ছুটির দেশ সিলেক্ট করা যাবে না"); the international days not counted.
const holMaxCountries = 3;

/// [cc]'s name in the app's language (the code itself when not listed);
/// all the countries in the UN's list are in countries.dart.
String countryName(String cc, {bool short = false}) {
  if (short && cc == 'AE') return tr('আমিরাত');
  return countryOf(cc)?.label ?? cc;
}

/// Countries whose Bengali or English name (or capital) matches [q].
List<String> searchCountries(String q) => [for (final c in findCountries(q)) c.code];

/// The international days of [year]: days the world keeps (the UN's and a
/// few everyone knows), by their Bengali names.
List<AbroadHoliday> internationalDays(int year) {
  DateTime nthSunday(int month, int n) {
    var d = DateTime(year, month, 1);
    while (d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    return d.add(Duration(days: 7 * (n - 1)));
  }

  final out = [
    AbroadHoliday(DateTime(year, 1, 1), 'ইংরেজি নববর্ষ'),
    AbroadHoliday(DateTime(year, 2, 21), 'আন্তর্জাতিক মাতৃভাষা দিবস'),
    AbroadHoliday(DateTime(year, 3, 8), 'আন্তর্জাতিক নারী দিবস'),
    AbroadHoliday(DateTime(year, 3, 22), 'বিশ্ব পানি দিবস'),
    AbroadHoliday(DateTime(year, 4, 7), 'বিশ্ব স্বাস্থ্য দিবস'),
    AbroadHoliday(DateTime(year, 4, 22), 'ধরিত্রী দিবস'),
    AbroadHoliday(DateTime(year, 5, 1), 'আন্তর্জাতিক শ্রমিক দিবস'),
    AbroadHoliday(nthSunday(5, 2), 'মা দিবস'),
    AbroadHoliday(DateTime(year, 5, 31), 'বিশ্ব তামাকমুক্ত দিবস'),
    AbroadHoliday(DateTime(year, 6, 5), 'বিশ্ব পরিবেশ দিবস'),
    AbroadHoliday(nthSunday(6, 3), 'বাবা দিবস'),
    AbroadHoliday(DateTime(year, 8, 12), 'আন্তর্জাতিক যুব দিবস'),
    AbroadHoliday(DateTime(year, 9, 8), 'আন্তর্জাতিক সাক্ষরতা দিবস'),
    AbroadHoliday(DateTime(year, 9, 21), 'আন্তর্জাতিক শান্তি দিবস'),
    AbroadHoliday(DateTime(year, 10, 1), 'আন্তর্জাতিক প্রবীণ দিবস'),
    AbroadHoliday(DateTime(year, 10, 5), 'বিশ্ব শিক্ষক দিবস'),
    AbroadHoliday(DateTime(year, 10, 10), 'বিশ্ব মানসিক স্বাস্থ্য দিবস'),
    AbroadHoliday(DateTime(year, 10, 16), 'বিশ্ব খাদ্য দিবস'),
    AbroadHoliday(DateTime(year, 10, 24), 'জাতিসংঘ দিবস'),
    AbroadHoliday(DateTime(year, 11, 14), 'বিশ্ব ডায়াবেটিস দিবস'),
    AbroadHoliday(DateTime(year, 11, 20), 'বিশ্ব শিশু দিবস'),
    AbroadHoliday(DateTime(year, 12, 3), 'আন্তর্জাতিক প্রতিবন্ধী দিবস'),
    AbroadHoliday(DateTime(year, 12, 10), 'মানবাধিকার দিবস'),
    AbroadHoliday(DateTime(year, 12, 25), 'বড়দিন'),
  ];
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// One row of the mixed list: a day (or a run of days) and whose it is.
class MixedHoliday {
  MixedHoliday(this.start, this.end, this.name, this.from, {this.local = ''});
  final DateTime start, end;

  /// The name as shown (already in the app's language for Bangladesh and
  /// the international days; abroad, the country's English name).
  final String name, local;

  /// The lists it is on: country codes and/or [holIntl].
  final List<String> from;
  int get days => end.difference(start).inDays + 1;

  /// A public holiday (some country's), not only an international day.
  bool get official => from.any((f) => f != holIntl);
}

/// The coming rows from [today]: Bangladesh's runs ([upcomingHolidays]),
/// each other country's days ([abroad], by code; next days of the same
/// name joined), and the international days when [intl] — one on the same
/// day as a holiday is said on that row. At most [count].
List<MixedHoliday> mixHolidays(DateTime today, {required List<String> countries, required Map<String, List<AbroadHoliday>> abroad, bool intl = false, int count = 4}) {
  final day0 = DateTime(today.year, today.month, today.day);
  final rows = <MixedHoliday>[];
  for (final cc in countries) {
    if (cc == 'BD') {
      for (final HolidayRun r in upcomingHolidays(day0, count: count)) {
        rows.add(MixedHoliday(r.start, r.end, r.label, ['BD']));
      }
      continue;
    }
    final list = [...?abroad[cc]]..sort((a, b) => a.date.compareTo(b.date));
    MixedHoliday? last;
    for (final h in list) {
      if (h.date.isBefore(day0)) continue;
      if (last != null && last.name == h.name && h.date.difference(last.end).inDays == 1) {
        rows[rows.length - 1] = last = MixedHoliday(last.start, h.date, last.name, last.from, local: last.local);
        continue;
      }
      if (rows.where((r) => r.from.contains(cc)).length >= count) break;
      rows.add(last = MixedHoliday(h.date, h.date, h.name, [cc], local: h.local));
    }
  }
  // The same day in two countries: one row (Christmas, New Year).
  rows.sort((a, b) => a.start.compareTo(b.start));
  final joined = <MixedHoliday>[];
  for (final r in rows) {
    final same = joined.where((j) => j.start == r.start && j.days == r.days).firstOrNull;
    if (same != null && _alike(same.name, r.name)) {
      same.from.addAll(r.from.where((f) => !same.from.contains(f)));
    } else {
      joined.add(MixedHoliday(r.start, r.end, r.name, [...r.from], local: r.local));
    }
  }
  if (intl) {
    for (final y in [day0.year, day0.year + 1]) {
      for (final d in internationalDays(y)) {
        if (d.date.isBefore(day0)) continue;
        final on = joined.where((j) => j.start == d.date).firstOrNull;
        if (on != null) {
          on.from.add(holIntl);
        } else {
          joined.add(MixedHoliday(d.date, d.date, tr(d.name), [holIntl]));
        }
      }
    }
  }
  joined.sort((a, b) => a.start.compareTo(b.start));
  // Each list's next day always shows (a country's holiday is not pushed
  // out by many international days); the rest by date.
  final pick = <MixedHoliday>{};
  for (final f in [...countries, if (intl) holIntl]) {
    final first = joined.where((j) => j.from.contains(f)).firstOrNull;
    if (first != null) pick.add(first);
  }
  for (final j in joined) {
    if (pick.length >= count) break;
    pick.add(j);
  }
  return pick.toList()..sort((a, b) => a.start.compareTo(b.start));
}

/// Two names for the same day: different countries may call it otherwise
/// (বড়দিন / Christmas Day), so only a run of the same length on the same
/// day is joined, and only when both are a well-known shared day.
bool _alike(String a, String b) {
  const shared = ['বড়দিন', 'Christmas', 'নববর্ষ', 'New Year', 'মে দিবস', 'Labour', 'Labor', 'Workers'];
  bool k(String s) => shared.any((w) => s.contains(w));
  return a == b || (k(a) && k(b) && _key(a) == _key(b));
}

String _key(String s) {
  if (s.contains('বড়দিন') || s.contains('Christmas')) return 'x';
  if (s.contains('নববর্ষ') || s.contains('New Year')) return 'n';
  return 'm';
}

/// Bengali names of holidays abroad that come in English (the lists worked
/// out on the phone, and the most common ones from the web).
const _abroadBn = {
  'National Day': 'জাতীয় দিবস',
  "New Year's Day": 'ইংরেজি নববর্ষ',
  'Eid al-Fitr': 'ঈদুল ফিতর',
  'Eid al-Adha': 'ঈদুল আজহা',
  'Arafat Day': 'আরাফাত দিবস',
  'Islamic New Year': 'হিজরি নববর্ষ',
  "Prophet's Birthday": 'ঈদে মিলাদুন্নবী',
  'Christmas Day': 'বড়দিন',
  'Labour Day': 'মে দিবস',
  'Saudi National Day': 'সৌদি জাতীয় দিবস',
  'Founding Day': 'প্রতিষ্ঠা দিবস',
  'Independence Day': 'স্বাধীনতা দিবস',
  "Isra and Mi'raj": 'শবে মেরাজ',
  'Ashura': 'আশুরা',
  'Qatar National Day': 'কাতার জাতীয় দিবস',
  'Liberation Day': 'মুক্তি দিবস',
  'Malaysia Day': 'মালয়েশিয়া দিবস',
  'National Day (Merdeka)': 'জাতীয় দিবস (মারদেকা)',
  'Pakistan Day': 'পাকিস্তান দিবস',
  'Good Friday': 'গুড ফ্রাইডে',
  'Easter Monday': 'ইস্টার মানডে',
  'Republic Day': 'প্রজাতন্ত্র দিবস',
  'Victory Day': 'বিজয় দিবস',
  'Revolution Day': 'বিপ্লব দিবস',
  'Nowruz': 'নওরোজ',
  'Constitution Day': 'সংবিধান দিবস',
  'Statehood Day': 'রাষ্ট্র দিবস',
  'Unity Day': 'ঐক্য দিবস',
  'Orthodox Christmas': 'অর্থোডক্স বড়দিন',
  'National Foundation Day': 'জাতীয় প্রতিষ্ঠা দিবস',
  'State Foundation Day': 'রাষ্ট্র প্রতিষ্ঠা দিবস',
  'Foundation Day': 'প্রতিষ্ঠা দিবস',
  'Gandhi Jayanti': 'গান্ধী জয়ন্তী',
  'Ethiopian New Year': 'ইথিওপীয় নববর্ষ',
  'Freedom Day': 'স্বাধীনতা দিবস',
  'Throne Day': 'সিংহাসন দিবস',
  'Evacuation Day': 'স্বাধীনতা দিবস (উচ্ছেদ দিবস)',
  'Australia Day': 'অস্ট্রেলিয়া দিবস',
  'Canada Day': 'কানাডা দিবস',
  "King's Day": 'রাজা দিবস',
  'Bastille Day': 'বাস্তিল দিবস',
  'German Unity Day': 'জার্মান ঐক্য দিবস',
  'Russia Day': 'রাশিয়া দিবস',
  'Portugal Day': 'পর্তুগাল দিবস',
  "St Patrick's Day": 'সেন্ট প্যাট্রিক দিবস',
  'May Revolution': 'মে বিপ্লব দিবস',
};

/// [name] (a holiday abroad) in Bengali when the app is in Bangla and it is known.
String abroadName(String name) => isEn ? name : (_abroadBn[name] ?? name);
