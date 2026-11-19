// সামনের ছুটি with several lists at once (owner, 19 Nov: "আন্তর্জাতিক ছুটি
// এবং অভ্যন্তরীণ ছুটি … প্রবাসীদের জন্যে … অন্তত দুটি দেশের ছুটির তারিখ").
// The member keeps a few lists: the country of the profile location ('@'),
// any other country by its two letters, and the international days
// ('INTL'). Home shows them in one list by date; a chip hides or shows each.
library;

import 'calendar_bd.dart' show HolidayRun, upcomingHolidays;
import 'holidays_abroad.dart' show AbroadHoliday;
import 'lang.dart' show isEn, tr;

/// The country the profile location is in.
const holAuto = '@';

/// The international days.
const holIntl = 'INTL';

/// What a new member sees: the profile's country, Bangladesh (the same
/// when at home) and the international days.
const holDefault = [holAuto, 'BD', holIntl];

/// Countries to pick from: two letters, the Bengali name, the English name;
/// [holPopular] are shown first (where many Bangladeshis live and work).
const holCountries = <(String, String, String)>[
  ('BD', 'বাংলাদেশ', 'Bangladesh'),
  ('SA', 'সৌদি আরব', 'Saudi Arabia'),
  ('AE', 'সংযুক্ত আরব আমিরাত', 'United Arab Emirates'),
  ('MY', 'মালয়েশিয়া', 'Malaysia'),
  ('QA', 'কাতার', 'Qatar'),
  ('KW', 'কুয়েত', 'Kuwait'),
  ('OM', 'ওমান', 'Oman'),
  ('BH', 'বাহরাইন', 'Bahrain'),
  ('GB', 'যুক্তরাজ্য', 'United Kingdom'),
  ('US', 'যুক্তরাষ্ট্র', 'United States'),
  ('IT', 'ইতালি', 'Italy'),
  ('SG', 'সিঙ্গাপুর', 'Singapore'),
  ('CA', 'কানাডা', 'Canada'),
  ('AU', 'অস্ট্রেলিয়া', 'Australia'),
  ('JP', 'জাপান', 'Japan'),
  ('KR', 'দক্ষিণ কোরিয়া', 'South Korea'),
  ('IN', 'ভারত', 'India'),
  ('PK', 'পাকিস্তান', 'Pakistan'),
  ('NP', 'নেপাল', 'Nepal'),
  ('LK', 'শ্রীলঙ্কা', 'Sri Lanka'),
  ('MV', 'মালদ্বীপ', 'Maldives'),
  ('CN', 'চীন', 'China'),
  ('HK', 'হংকং', 'Hong Kong'),
  ('TH', 'থাইল্যান্ড', 'Thailand'),
  ('ID', 'ইন্দোনেশিয়া', 'Indonesia'),
  ('BN', 'ব্রুনাই', 'Brunei'),
  ('JO', 'জর্ডান', 'Jordan'),
  ('LB', 'লেবানন', 'Lebanon'),
  ('EG', 'মিশর', 'Egypt'),
  ('TR', 'তুরস্ক', 'Türkiye'),
  ('LY', 'লিবিয়া', 'Libya'),
  ('MA', 'মরক্কো', 'Morocco'),
  ('ZA', 'দক্ষিণ আফ্রিকা', 'South Africa'),
  ('MU', 'মরিশাস', 'Mauritius'),
  ('FR', 'ফ্রান্স', 'France'),
  ('DE', 'জার্মানি', 'Germany'),
  ('ES', 'স্পেন', 'Spain'),
  ('PT', 'পর্তুগাল', 'Portugal'),
  ('GR', 'গ্রিস', 'Greece'),
  ('NL', 'নেদারল্যান্ডস', 'Netherlands'),
  ('BE', 'বেলজিয়াম', 'Belgium'),
  ('SE', 'সুইডেন', 'Sweden'),
  ('FI', 'ফিনল্যান্ড', 'Finland'),
  ('DK', 'ডেনমার্ক', 'Denmark'),
  ('NO', 'নরওয়ে', 'Norway'),
  ('IE', 'আয়ারল্যান্ড', 'Ireland'),
  ('CH', 'সুইজারল্যান্ড', 'Switzerland'),
  ('AT', 'অস্ট্রিয়া', 'Austria'),
  ('PL', 'পোল্যান্ড', 'Poland'),
  ('RO', 'রোমানিয়া', 'Romania'),
  ('CY', 'সাইপ্রাস', 'Cyprus'),
  ('MT', 'মাল্টা', 'Malta'),
  ('RU', 'রাশিয়া', 'Russia'),
  ('NZ', 'নিউজিল্যান্ড', 'New Zealand'),
  ('BR', 'ব্রাজিল', 'Brazil'),
  ('MX', 'মেক্সিকো', 'Mexico'),
];

const holPopular = ['SA', 'AE', 'MY', 'QA', 'KW', 'OM', 'GB', 'US', 'IT', 'SG'];

/// [cc]'s name in the app's language (the code itself when not listed).
String countryName(String cc, {bool short = false}) {
  if (short && cc == 'AE') return tr('আমিরাত');
  for (final (c, bn, _) in holCountries) {
    if (c == cc) return tr(bn);
  }
  return cc;
}

/// Countries whose Bengali or English name starts (a word) with [q].
List<String> searchCountries(String q) {
  final s = q.trim().toLowerCase();
  if (s.isEmpty) return [for (final c in holCountries) c.$1];
  bool hit(String name) => name.toLowerCase().startsWith(s) || name.toLowerCase().contains(' $s');
  return [for (final (c, bn, en) in holCountries) if (hit(bn) || hit(en) || c.toLowerCase() == s) c];
}

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
};

/// [name] (a holiday abroad) in Bengali when the app is in Bangla and it is known.
String abroadName(String name) => isEn ? name : (_abroadBn[name] ?? name);
