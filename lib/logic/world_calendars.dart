/// The world's calendars beside the English (Gregorian) one (owner, 19 Nov:
/// "ইংরেজি ক্যালেন্ডার থাকবে, চাইলে আরো একটি বা দুটি যুক্ত করতে পারবে").
/// Everything is worked out on the phone, without the internet:
///  • Hebrew, Persian (Solar Hijri), Indian national (Saka), Ethiopian,
///    Julian, Thai and Japanese by their rules (arithmetic);
///  • Chinese lunisolar from a table of each year's months, 1900–2098, and
///    Korean from Korea's own (KASI) table, 1900–2049;
///  • Vikram Samvat as Nepal's official solar calendar, from its published
///    table of month lengths, 2000–2100 BS (1943–2044 AD).
/// Checked day by day against independent libraries in
/// test/world_calendars_1119_test.dart.
library;

import 'bn.dart';
import 'calendar_bd.dart';
import 'lang.dart';

/// A calendar the user may add: its key, its name and where it is used.
class CalKind {
  const CalKind(this.id, this.bn, this.en, this.whereBn, this.whereEn, this.shortBn, this.shortEn, {this.sameDays = false, this.rtl = false});
  final String id, bn, en, whereBn, whereEn, shortBn, shortEn;

  /// Its own script runs right to left (Arabic, Hebrew, Persian).
  final bool rtl;

  /// Its days are the English ones (only the year or the era differs), so a
  /// month grid has nothing new to show under each day.
  final bool sameDays;
  String get name => isEn ? en : bn;
  String get where => isEn ? whereEn : whereBn;

  /// "হিজরি", "চীনা": before a date.
  String get short => isEn ? shortEn : shortBn;
}

const calKinds = [
  CalKind('bangla', 'বাংলা (বঙ্গাব্দ)', 'Bangla (Bangabda)', 'বাংলাদেশ, পশ্চিমবঙ্গ', 'Bangladesh, West Bengal', 'বাংলা', 'Bangla'),
  CalKind('hijri', 'হিজরি (আরবি)', 'Hijri (Islamic)', 'মুসলিম বিশ্ব, চাঁদ দেখে', 'Muslim world, by the moon', 'হিজরি', 'Hijri', rtl: true),
  CalKind('chinese', 'চীনা চান্দ্র', 'Chinese lunar', 'চীন, চীনা নববর্ষ', 'China, Lunar New Year', 'চীনা', 'Chinese'),
  CalKind('hebrew', 'হিব্রু (ইহুদি)', 'Hebrew (Jewish)', 'ইসরায়েল', 'Israel', 'হিব্রু', 'Hebrew', rtl: true),
  CalKind('persian', 'ফারসি (সৌর হিজরি)', 'Persian (Solar Hijri)', 'ইরান, আফগানিস্তান', 'Iran, Afghanistan', 'ফারসি', 'Persian', rtl: true),
  CalKind('saka', 'শকাব্দ (ভারতীয় জাতীয়)', 'Saka (Indian national)', 'ভারত', 'India', 'শকাব্দ', 'Saka'),
  CalKind('vikram', 'বিক্রম সংবৎ', 'Vikram Samvat', 'নেপাল', 'Nepal', 'বিক্রম সংবৎ', 'Vikram Samvat'),
  CalKind('ethiopian', 'ইথিওপীয়', 'Ethiopian', 'ইথিওপিয়া, ১৩ মাসে বছর', 'Ethiopia, 13 months', 'ইথিওপীয়', 'Ethiopian'),
  CalKind('thai', 'থাই বৌদ্ধ', 'Thai Buddhist', 'থাইল্যান্ড', 'Thailand', 'থাই', 'Thai', sameDays: true),
  CalKind('japanese', 'জাপানি', 'Japanese', 'জাপান, সম্রাটের যুগ', "Japan, the emperor's era", 'জাপানি', 'Japanese', sameDays: true),
  CalKind('korean', 'কোরীয় চান্দ্র', 'Korean lunar', 'কোরিয়া', 'Korea', 'কোরীয়', 'Korean'),
  CalKind('julian', 'জুলিয়ান', 'Julian', 'অর্থোডক্স গির্জা', 'Orthodox church', 'জুলিয়ান', 'Julian'),
];

CalKind? calKind(String id) {
  for (final k in calKinds) {
    if (k.id == id) return k;
  }
  return null;
}

/// The extra calendars shown beside the English date, at most two. Before
/// this choice the app always showed Bangla and Hijri, so that stays the
/// default.
const defaultCalendars = ['bangla', 'hijri'];
const maxCalendars = 2;

/// "bangla,hijri" (the 'calendars' setting) → the known keys, at most two;
/// "none" = only the English date.
List<String> parseCalendars(String? pref) {
  if (pref == null || pref.trim().isEmpty) return defaultCalendars;
  if (pref.trim() == 'none') return const [];
  final out = <String>[];
  for (final p in pref.split(',')) {
    final id = p.trim();
    if (calKind(id) != null && !out.contains(id)) out.add(id);
  }
  return out.take(maxCalendars).toList();
}

String calendarsPref(List<String> ids) => ids.isEmpty ? 'none' : ids.take(maxCalendars).join(',');

/// One day in one calendar.
class CalDate {
  const CalDate({required this.year, required this.month, required this.day, required this.monthName, required this.yearLabel, this.native = '', this.leap = false, this.yearAfter = true});

  /// The year's number in that calendar (Chinese: the Gregorian year its new year falls in).
  final int year;

  /// 1-based month in the calendar's own order.
  final int month;
  final int day;
  final bool leap;

  /// The month's name in the app's language: "কিসলেভ", "দশম মাস".
  final String monthName;

  /// What follows the month: "৫৭৮৭", "ঘোড়ার বছর", "রেইওয়া ৮".
  final String yearLabel;

  /// The date in the calendar's own script, when it has one: "ח׳ בכסלו תשפ״ז".
  final String native;

  final bool yearAfter;

  /// "৮ কিসলেভ ৫৭৮৭".
  String get text => '${bnDigits(day)} $monthName${yearLabel.isEmpty ? '' : (yearAfter ? ' ' : ', ')}$yearLabel';

  /// "৮ কিসলেভ".
  String get dayMonth => '${bnDigits(day)} $monthName';
}

/// [d] in the calendar [id]; null for an unknown key or a day outside a
/// table (before 1900 or after 2098 for Chinese, 2049 for Korean, outside
/// 1943–2044 for Vikram Samvat).
CalDate? calDate(String id, DateTime d, {int hijriShift = 0}) {
  switch (id) {
    case 'bangla':
      final b = banglaDate(d);
      return CalDate(year: b.year, month: b.month + 1, day: b.day, monthName: b.monthName, yearLabel: bnDigits(b.year), native: isEn ? '${_bn(b.day)} ${banglaMonths[b.month]} ${_bn(b.year)}' : '');
    case 'hijri':
      final h = hijriDate(d, adjust: hijriShift);
      return CalDate(year: h.year, month: h.month, day: h.day, monthName: h.monthName, yearLabel: bnDigits(h.year), native: h.arabic);
    case 'chinese':
      return _chinese(d, korean: false);
    case 'korean':
      return _chinese(d, korean: true);
    case 'hebrew':
      return _hebrew(d);
    case 'persian':
      return _persian(d);
    case 'saka':
      return _saka(d);
    case 'vikram':
      return _vikram(d);
    case 'ethiopian':
      return _ethiopian(d);
    case 'julian':
      final j = julianYmd(_jdn(d));
      return CalDate(year: j.$1, month: j.$2, day: j.$3, monthName: monthName(j.$2), yearLabel: bnDigits(j.$1));
    case 'thai':
      final y = d.year + 543;
      return CalDate(year: y, month: d.month, day: d.day, monthName: monthName(d.month), yearLabel: isEn ? 'BE $y' : 'বৌদ্ধাব্দ ${bnDigits(y)}', native: '${d.day} ${_thaiMonths[d.month - 1]} $y');
    case 'japanese':
      return _japanese(d);
  }
  return null;
}

String _bn(int n) => n.toString().replaceAllMapped(RegExp('[0-9]'), (m) => '০১২৩৪৫৬৭৮৯'[int.parse(m[0]!)]);

// ── Day numbers ──

/// Julian day number of a Gregorian date.
int _jdn(DateTime g) {
  final a = (14 - g.month) ~/ 12;
  final y = g.year + 4800 - a;
  final m = g.month + 12 * a - 3;
  return g.day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 + y ~/ 400 - 32045;
}

int gregorianJdn(int y, int m, int d) => _jdn(DateTime.utc(y, m, d));

/// (year, month, day) in the Julian calendar of a day number.
(int, int, int) julianYmd(int jdn) {
  final c = jdn + 32082;
  final d = (4 * c + 3) ~/ 1461;
  final e = c - (1461 * d) ~/ 4;
  final m = (5 * e + 2) ~/ 153;
  return (d - 4800 + m ~/ 10, m + 3 - 12 * (m ~/ 10), e - (153 * m + 2) ~/ 5 + 1);
}

// ── Hebrew ──

const _hebMonthsBn = ['তিশরেই', 'হেশভান', 'কিসলেভ', 'তেভেত', 'শেভাত', 'আদার', '', 'নিসান', 'ইয়ার', 'সিভান', 'তাম্মুজ', 'আভ', 'এলুল'];
const _hebMonthsEn = ['Tishrei', 'Heshvan', 'Kislev', 'Tevet', 'Shevat', 'Adar', '', 'Nisan', 'Iyar', 'Sivan', 'Tammuz', 'Av', 'Elul'];
const _hebMonthsHe = ['תשרי', 'חשוון', 'כסלו', 'טבת', 'שבט', 'אדר', '', 'ניסן', 'אייר', 'סיוון', 'תמוז', 'אב', 'אלול'];

bool _hebLeap(int y) => (7 * y + 1) % 19 < 7;

/// Days from the epoch to the molad of Tishrei, with the first postponement.
int _hebElapsed(int y) {
  final months = (235 * y - 234) ~/ 19;
  final parts = 12084 + 13753 * months;
  final day = 29 * months + parts ~/ 25920;
  return (3 * (day + 1)) % 7 < 3 ? day + 1 : day;
}

int _hebDelay(int y) {
  final ny0 = _hebElapsed(y - 1), ny1 = _hebElapsed(y), ny2 = _hebElapsed(y + 1);
  if (ny2 - ny1 == 356) return 2;
  if (ny1 - ny0 == 382) return 1;
  return 0;
}

/// Julian day number of 1 Tishrei of [y].
int _hebNewYear(int y) => 347998 + _hebElapsed(y) + _hebDelay(y);

CalDate _hebrew(DateTime d) {
  final jdn = _jdn(d);
  var y = d.year + 3760;
  while (_hebNewYear(y + 1) <= jdn) {
    y++;
  }
  while (_hebNewYear(y) > jdn) {
    y--;
  }
  final len = _hebNewYear(y + 1) - _hebNewYear(y);
  final leap = _hebLeap(y);
  // Civil order from Tishrei; a leap year has Adar I and Adar II.
  final lengths = [30, len % 10 == 5 ? 30 : 29, len % 10 == 3 ? 29 : 30, 29, 30, if (leap) 30, 29, 30, 29, 30, 29, 30, 29];
  var left = jdn - _hebNewYear(y);
  var i = 0;
  while (left >= lengths[i]) {
    left -= lengths[i];
    i++;
  }
  List<String> names(List<String> all, String adar1, String adar2) =>
      leap ? [...all.sublist(0, 5), adar1, adar2, ...all.sublist(7)] : [...all.sublist(0, 6), ...all.sublist(7)];
  final bn = names(_hebMonthsBn, 'আদার ১', 'আদার ২'), en = names(_hebMonthsEn, 'Adar I', 'Adar II'), he = names(_hebMonthsHe, 'אדר א׳', 'אדר ב׳');
  final day = left + 1;
  return CalDate(year: y, month: i + 1, day: day, leap: leap && i == 5, monthName: (isEn ? en : bn)[i], yearLabel: bnDigits(y), native: '${_gematria(day)} ב${he[i]} ${_gematria(y % 1000)}');
}

/// Hebrew numerals: 15 → ט״ו, 787 → תשפ״ז, 8 → ח׳.
String _gematria(int n) {
  const hundreds = ['', 'ק', 'ר', 'ש', 'ת', 'תק', 'תר', 'תש', 'תת', 'תתק'];
  const tens = ['', 'י', 'כ', 'ל', 'מ', 'נ', 'ס', 'ע', 'פ', 'צ'];
  const ones = ['', 'א', 'ב', 'ג', 'ד', 'ה', 'ו', 'ז', 'ח', 'ט'];
  var s = hundreds[n ~/ 100];
  final r = n % 100;
  if (r == 15) {
    s += 'טו';
  } else if (r == 16) {
    s += 'טז';
  } else {
    s += tens[r ~/ 10] + ones[r % 10];
  }
  return s.length == 1 ? '$s׳' : '${s.substring(0, s.length - 1)}״${s.substring(s.length - 1)}';
}

// ── Persian (Solar Hijri), by Borkowski's breaks (as in jalaali-js) ──

const _perMonthsBn = ['ফারভারদিন', 'ওর্দিবেহেশত', 'খোরদাদ', 'তির', 'মোরদাদ', 'শাহরিভার', 'মেহর', 'আবান', 'আজার', 'দেই', 'বাহমান', 'এসফান্দ'];
const _perMonthsEn = ['Farvardin', 'Ordibehesht', 'Khordad', 'Tir', 'Mordad', 'Shahrivar', 'Mehr', 'Aban', 'Azar', 'Dey', 'Bahman', 'Esfand'];
const _perMonthsFa = ['فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور', 'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'];
const _breaks = [-61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, 1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178];

/// (leap: 0 when leap, march: the March day of 1 Farvardin) for Persian year [jy].
(int, int) _jalCal(int jy) {
  final gy = jy + 621;
  var leapJ = -14;
  var jp = _breaks[0];
  var jump = 0;
  for (var i = 1; i < _breaks.length; i++) {
    final jm = _breaks[i];
    jump = jm - jp;
    if (jy < jm) break;
    leapJ += (jump ~/ 33) * 8 + (jump.remainder(33)) ~/ 4;
    jp = jm;
  }
  var n = jy - jp;
  leapJ += (n ~/ 33) * 8 + (n.remainder(33) + 3) ~/ 4;
  if (jump.remainder(33) == 4 && jump - n == 4) leapJ += 1;
  final leapG = gy ~/ 4 - ((gy ~/ 100 + 1) * 3) ~/ 4 - 150;
  final march = 20 + leapJ - leapG;
  if (jump - n < 6) n = n - jump + ((jump + 4) ~/ 33) * 33;
  var leap = ((n + 1).remainder(33) - 1).remainder(4);
  if (leap == -1) leap = 4;
  return (leap, march);
}

CalDate _persian(DateTime d) {
  final jdn = _jdn(d);
  var jy = d.year - 621;
  var k = jdn - gregorianJdn(d.year, 3, _jalCal(jy).$2);
  int jm, jd;
  if (k >= 0 && k <= 185) {
    jm = 1 + k ~/ 31;
    jd = k % 31 + 1;
  } else {
    if (k >= 0) {
      k -= 186;
    } else {
      jy -= 1;
      k += 179;
      if (_jalCal(jy).$1 == 0) k += 1;
    }
    jm = 7 + k ~/ 30;
    jd = k % 30 + 1;
  }
  return CalDate(year: jy, month: jm, day: jd, monthName: (isEn ? _perMonthsEn : _perMonthsBn)[jm - 1], yearLabel: bnDigits(jy), native: '${_faDigits(jd)} ${_perMonthsFa[jm - 1]} ${_faDigits(jy)}');
}

String _faDigits(int n) => '$n'.replaceAllMapped(RegExp('[0-9]'), (m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);

// ── Indian national (Saka) ──

const _sakaMonthsBn = ['চৈত্র', 'বৈশাখ', 'জ্যৈষ্ঠ', 'আষাঢ়', 'শ্রাবণ', 'ভাদ্র', 'আশ্বিন', 'কার্তিক', 'অগ্রহায়ণ', 'পৌষ', 'মাঘ', 'ফাল্গুন'];
const _sakaMonthsEn = ['Chaitra', 'Vaishakha', 'Jyaishtha', 'Ashadha', 'Shravana', 'Bhadra', 'Ashvin', 'Kartika', 'Agrahayana', 'Pausha', 'Magha', 'Phalguna'];
const _sakaMonthsHi = ['चैत्र', 'वैशाख', 'ज्येष्ठ', 'आषाढ़', 'श्रावण', 'भाद्रपद', 'आश्विन', 'कार्तिक', 'अग्रहायण', 'पौष', 'माघ', 'फाल्गुन'];

bool _gLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

/// 1 Chaitra is 22 March (21 March in a Gregorian leap year); Chaitra has
/// 30 days (31 in a leap year), the next five 31, the rest 30.
CalDate _saka(DateTime d) {
  final g = DateTime.utc(d.year, d.month, d.day);
  DateTime start(int gy) => DateTime.utc(gy, 3, _gLeap(gy) ? 21 : 22);
  var gy = g.year;
  if (g.isBefore(start(gy))) gy--;
  var left = g.difference(start(gy)).inDays;
  final lengths = [_gLeap(gy) ? 31 : 30, 31, 31, 31, 31, 31, 30, 30, 30, 30, 30, 30];
  var m = 0;
  while (left >= lengths[m]) {
    left -= lengths[m];
    m++;
  }
  final y = gy - 78;
  return CalDate(year: y, month: m + 1, day: left + 1, monthName: (isEn ? _sakaMonthsEn : _sakaMonthsBn)[m], yearLabel: bnDigits(y), native: '${_deva(left + 1)} ${_sakaMonthsHi[m]} ${_deva(y)}');
}

String _deva(int n) => '$n'.replaceAllMapped(RegExp('[0-9]'), (m) => '०१२३४५६७८९'[int.parse(m[0]!)]);

// ── Vikram Samvat (Nepal's Bikram Sambat) ──

const _vsMonthsBn = ['বৈশাখ', 'জেঠ', 'আষাঢ়', 'শ্রাবণ', 'ভাদ্র', 'আশ্বিন', 'কার্তিক', 'মংসির', 'পৌষ', 'মাঘ', 'ফাল্গুন', 'চৈত্র'];
const _vsMonthsEn = ['Baishakh', 'Jestha', 'Asar', 'Shrawan', 'Bhadra', 'Asoj', 'Kartik', 'Mangsir', 'Poush', 'Magh', 'Falgun', 'Chaitra'];
const _vsMonthsNe = ['बैशाख', 'जेठ', 'असार', 'साउन', 'भदौ', 'असोज', 'कात्तिक', 'मंसिर', 'पुस', 'माघ', 'फागुन', 'चैत'];

/// Month lengths of 2000 … 2100 BS: two bits a month (days − 29), Baishakh lowest.
const _vsYears = [
  0x8456ed, 0x511aba, 0x5116fa, 0x9056ee, 0x8456ed, 0x511aba, 0x5116fa, 0x9056ee,
  0x814aea, 0x511aba, 0x5116fa, 0x9056ee, 0x514aea, 0x511aba, 0x5116fa, 0x9056ee,
  0x514aea, 0x511aba, 0x5116ee, 0x8456ee, 0x511aea, 0x511aba, 0x5056ee, 0x8456ee,
  0x511aea, 0x511aba, 0x9056ee, 0x8456ed, 0x511aba, 0x5117ba, 0x9056ee, 0x8456ed,
  0x511aba, 0x5116fa, 0x9056ee, 0x814aed, 0x511aba, 0x5116fa, 0x9056ee, 0x514aea,
  0x511aba, 0x5116fa, 0x9056ee, 0x514aea, 0x511aba, 0x5116ee, 0x9056ee, 0x511aea,
  0x511aba, 0x5056ee, 0x8456ee, 0x511aea, 0x511aba, 0x5056ee, 0x8456ee, 0x511aba,
  0x5117ba, 0x9056ee, 0x8456ed, 0x511aba, 0x5116fa, 0x9056ee, 0x844aea, 0x511aba,
  0x5116fa, 0x9056ee, 0x814aea, 0x511aba, 0x5116fa, 0x9056ee, 0x514aea, 0x511aba,
  0x5116ee, 0x9056ee, 0x511aea, 0x511aba, 0x5056ee, 0x8456ee, 0x511aea, 0x511aba,
  0x5056ee, 0x8456ee, 0x511aba, 0x511aba, 0x5456ba, 0x5459ee, 0x5456ed, 0x551aba,
  0x5459f9, 0x5456ed, 0x5456ed, 0x545aba, 0x5456f9, 0x5456ed, 0x5456ba, 0x551aba,
  0x5116f9, 0x5456ee, 0x844aba, 0x541aba, 0x5119ee,
];

CalDate? _vikram(DateTime d) {
  // 1 Baishakh 2000 BS = 14 April 1943.
  var left = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(1943, 4, 14)).inDays;
  if (left < 0) return null;
  for (var i = 0; i < _vsYears.length; i++) {
    for (var m = 0; m < 12; m++) {
      final len = 29 + ((_vsYears[i] >> (2 * m)) & 3);
      if (left < len) {
        final y = 2000 + i;
        return CalDate(year: y, month: m + 1, day: left + 1, monthName: (isEn ? _vsMonthsEn : _vsMonthsBn)[m], yearLabel: bnDigits(y), native: '${_deva(left + 1)} ${_vsMonthsNe[m]} ${_deva(y)}');
      }
      left -= len;
    }
  }
  return null;
}

// ── Ethiopian ──

const _ethMonthsBn = ['মাসকারাম', 'তিকিমত', 'হিদার', 'তাহসাস', 'তির', 'ইয়াকাতিত', 'মাগাবিত', 'মিয়াজিয়া', 'গিনবত', 'সেনে', 'হামলে', 'নাহাসে', 'পাগুমে'];
const _ethMonthsEn = ['Meskerem', 'Tikimt', 'Hidar', 'Tahsas', 'Tir', 'Yekatit', 'Megabit', 'Miyazya', 'Ginbot', 'Sene', 'Hamle', 'Nehase', 'Pagume'];
const _ethMonthsAm = ['መስከረም', 'ጥቅምት', 'ኅዳር', 'ታኅሣሥ', 'ጥር', 'የካቲት', 'መጋቢት', 'ሚያዝያ', 'ግንቦት', 'ሰኔ', 'ሐምሌ', 'ነሐሴ', 'ጳጉሜን'];

/// Twelve months of 30 days and Pagume of 5 (6 before a Gregorian leap year).
CalDate _ethiopian(DateTime d) {
  final jdn = _jdn(d);
  final r = (jdn - 1723856) % 1461;
  final n = r % 365 + 365 * (r ~/ 1460);
  final y = 4 * ((jdn - 1723856) ~/ 1461) + r ~/ 365 - r ~/ 1460;
  final m = n ~/ 30;
  final day = n % 30 + 1;
  return CalDate(year: y, month: m + 1, day: day, monthName: (isEn ? _ethMonthsEn : _ethMonthsBn)[m], yearLabel: bnDigits(y), native: '${_ethMonthsAm[m]} $day $y');
}

// ── Thai and Japanese ──

const _thaiMonths = ['มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม'];

/// (first day, Japanese, Bangla, English) of each era since the Gregorian calendar (1873).
final _eras = [
  (DateTime.utc(2019, 5, 1), '令和', 'রেইওয়া', 'Reiwa'),
  (DateTime.utc(1989, 1, 8), '平成', 'হেইসেই', 'Heisei'),
  (DateTime.utc(1926, 12, 25), '昭和', 'শোওয়া', 'Showa'),
  (DateTime.utc(1912, 7, 30), '大正', 'তাইশো', 'Taisho'),
  (DateTime.utc(1868, 1, 25), '明治', 'মেইজি', 'Meiji'),
];

CalDate? _japanese(DateTime d) {
  final g = DateTime.utc(d.year, d.month, d.day);
  for (final (start, ja, bn, en) in _eras) {
    if (!g.isBefore(start)) {
      final n = d.year - start.year + 1;
      return CalDate(
          year: n,
          month: d.month,
          day: d.day,
          monthName: monthName(d.month),
          yearLabel: isEn ? '$en $n' : '$bn ${bnDigits(n)}',
          yearAfter: false,
          native: '$ja${n == 1 ? '元' : '$n'}年${d.month}月${d.day}日');
    }
  }
  return null;
}

// ── Chinese and Korean lunisolar ──

/// 1900 … 2098: (days from 1 Jan 1900 to the new year << 17) | (leap month << 13)
/// | a bit for each month of 30 days (the leap month in its place), first month lowest.
const _cnYears = [
  0x3d16d2, 0x33c0752, 0x6000ea5, 0x8c6b64a, 0xbc4064b, 0xe880a9b,
  0x114e9556, 0x144e056a, 0x17120b59, 0x19d85752, 0x1cd80752, 0x1f9cdb25,
  0x229c0b25, 0x25600a4b, 0x2824b4ab, 0x2b2402ad, 0x2de8056b, 0x30ae4b69,
  0x33ae0da9, 0x3674fd92, 0x39740e92, 0x3c380d25, 0x3efcba4d, 0x41fc0a56,
  0x44c002b6, 0x478495b5, 0x4a8606d4, 0x4d4a0ea9, 0x50105e92, 0x53100e92,
  0x55d4cd26, 0x58d2052b, 0x5b960a57, 0x5e5cb2d6, 0x615c0b5a, 0x642206d4,
  0x66e66ec9, 0x69e60749, 0x6caaf693, 0x6faa0a93, 0x726e052b, 0x7532ca5b,
  0x78320aad, 0x7af8056a, 0x7dbc9b55, 0x80be0ba4, 0x83820b49, 0x86465a93,
  0x89460a95, 0x8c0af52d, 0x8f0a0536, 0x91ce0aad, 0x9494b5aa, 0x979405b2,
  0x9a580ba5, 0x9d1e7d4a, 0xa01e0d4a, 0xa2e30a95, 0xa5e00a97, 0xa8a60556,
  0xab6acab5, 0xae6a0ad5, 0xb13006d2, 0xb3f48ea5, 0xb6f40ea5, 0xb9ba064a,
  0xbc7c6c97, 0xbf7c0a9b, 0xc242f55a, 0xc542056a, 0xc8060b69, 0xcaccb752,
  0xcdcc0b52, 0xd0900b25, 0xd354964b, 0xd6540a4b, 0xd91914ab, 0xdc1802ad,
  0xdedc05ad, 0xe1a2cb69, 0xe4a20da9, 0xe7680d92, 0xea2c9d25, 0xed2c0d25,
  0xeff15a4d, 0xf2f00a56, 0xf5b402b6, 0xf878c5b5, 0xfb7806d5, 0xfe3e0ea9,
  0x10104be92, 0x104040e92, 0x106c80d26, 0x1098c6a56, 0x10c8a0a57, 0x10f5114d6,
  0x11250035a, 0x1151406d5, 0x117dab6c9, 0x11ada0749, 0x11d9e0693, 0x12062952b,
  0x12362052b, 0x126260a5b, 0x128ec555a, 0x12bec056a, 0x12eb0fb55, 0x131b20ba4,
  0x134760b49, 0x1373aba93, 0x13a3a0a95, 0x13cfe052d, 0x13fc28aad, 0x142c20ab5,
  0x1458935aa, 0x1488805d2, 0x14b4c0da5, 0x14e12dd4a, 0x151120d4a, 0x153d60c95,
  0x1569a952e, 0x1599a0556, 0x15c5e0ab5, 0x15f2455b2, 0x1622406d2, 0x164e8cea5,
  0x167e80725, 0x16aac064b, 0x16d70ac97, 0x170700cab, 0x17336055a, 0x175fa6ad6,
  0x178fa0b69, 0x17bc17752, 0x17ec00b52, 0x181840b25, 0x18448da4b, 0x187480a4b,
  0x18a0c04ab, 0x18cd0a55b, 0x18fd005ad, 0x192960b6a, 0x1955c5b52, 0x1985c0d92,
  0x19b20fd25, 0x19e200d25, 0x1a0e40a55, 0x1a3a8b4ad, 0x1a6a804b6, 0x1a96c05b5,
  0x1ac326daa, 0x1af320ec9, 0x1b1f91e92, 0x1b4f80e92, 0x1b7bc0d26, 0x1ba80ca56,
  0x1bd7e0a57, 0x1c0440556, 0x1c30886d5, 0x1c6080755, 0x1c8ce0749, 0x1cb926e93,
  0x1ce920693, 0x1d156f52b, 0x1d456052b, 0x1d71a0a5b, 0x1d9e0b55a, 0x1dce0056a,
  0x1dfa40b65, 0x1e26a974a, 0x1e56a0b4a, 0x1e82f1a95, 0x1eb2e0a95, 0x1edf2052d,
  0x1f0b6caad, 0x1f3b60ab5, 0x1f67c05aa, 0x1f9408ba5, 0x1fc400da5, 0x1ff060d4a,
  0x201ca7c95, 0x204ca0c96, 0x2078ef94e, 0x20a8e0556, 0x20d520ab5, 0x21018b5b2,
  0x2131806d2, 0x215dc0ea5, 0x218a28e4a, 0x21ba0068b, 0x21e650c97, 0x2216404ab,
  0x22428055b, 0x226eecad6, 0x229ee0b6a, 0x22cb40752, 0x22f789725, 0x232780b45,
  0x2353c0a8b,
];

/// The same for Korea, 1900 … 2049, from the Korea Astronomy and Space Science
/// Institute's tables: on Korea's clock a new moon sometimes falls a day
/// later than on China's, so a month may begin a day apart.
const _krYears = [
  0x3d16d2, 0x33c0752, 0x6000ea5, 0x8c6b64a, 0xbc4064b, 0xe880a9b,
  0x114e9556, 0x144e056a, 0x17120b59, 0x19d85752, 0x1cd80752, 0x1f9cdb25,
  0x229c0b25, 0x25600a4b, 0x2824b29b, 0x2b240aad, 0x2dea056a, 0x30ae4b69,
  0x33ae0ba9, 0x3674fb52, 0x39740d92, 0x3c380d25, 0x3efcba4d, 0x41fc0956,
  0x44c002b5, 0x478495ad, 0x4a8606d4, 0x4d4a0da9, 0x50105d92, 0x53100e92,
  0x55d4cd26, 0x58d20527, 0x5b960a57, 0x5e5cb2b6, 0x615c0ada, 0x642206d4,
  0x66e66ea9, 0x69e60749, 0x6caaf693, 0x6faa0a93, 0x726e052b, 0x7532ca5b,
  0x7832096d, 0x7af80b6a, 0x7dbe9b54, 0x80be0ba4, 0x83820b49, 0x86465a93,
  0x89460a95, 0x8c0af52b, 0x8f0a052d, 0x91ce0aad, 0x9494b56a, 0x97940db2,
  0x9a5a0da4, 0x9d1e7d49, 0xa01e0d4a, 0xa2e31a95, 0xa5e20a96, 0xa8a60556,
  0xab6acab5, 0xae6a0ad5, 0xb13006d2, 0xb3f48ea5, 0xb6f40ea5, 0xb9ba0e4a,
  0xbc7e6c96, 0xbf7c0a9b, 0xc242f556, 0xc542056a, 0xc8060b59, 0xcaccb752,
  0xcdcc0752, 0xd0900725, 0xd354964b, 0xd6540a4b, 0xd91912ab, 0xdc1802ad,
  0xdedc056b, 0xe1a2cb69, 0xe4a20da9, 0xe7680d92, 0xea2c9b25, 0xed2c0d25,
  0xeff15a4d, 0xf2f00a56, 0xf5b402b6, 0xf878d5ad, 0xfb7a06d4, 0xfe3e0da9,
  0x10104bd92, 0x104040e92, 0x106c80d26, 0x1098c6a56, 0x10c8a0a57, 0x10f5112b6,
  0x112500b5a, 0x1151606d4, 0x117daaec9, 0x11ada0749, 0x11d9e0693, 0x120629527,
  0x12362052b, 0x126260a5b, 0x128ec555a, 0x12bec036a, 0x12eb0fb55, 0x131b20ba4,
  0x134760b49, 0x1373aba93, 0x13a3a0a95, 0x13cfe052d, 0x13fc26a5d, 0x142c20aad,
  0x1458935aa, 0x1488805d2, 0x14b4c0da5, 0x14e12bd4a, 0x151120d4a, 0x153d60a95,
  0x1569a952d, 0x1599a0556, 0x15c5e0ab5, 0x15f2455aa, 0x1622406d2, 0x164e8cea5,
  0x167e80ea5, 0x16aae0e4a, 0x16d72ac96, 0x170700c9b, 0x17336055a, 0x175fa6ad5,
  0x178fa0b69, 0x17bc17752, 0x17ec00752, 0x181840b25, 0x18448d64b, 0x187480a4b,
  0x18a0c04ab, 0x18cd0a55b, 0x18fd0056d, 0x192960b69, 0x1955c5b52, 0x1985c0d92,
  0x19b20fd25, 0x19e200d25, 0x1a0e40a4d, 0x1a3a8b4ad, 0x1a6a802b6, 0x1a96c05b5,
];

const _cnOrdBn = ['প্রথম', 'দ্বিতীয়', 'তৃতীয়', 'চতুর্থ', 'পঞ্চম', 'ষষ্ঠ', 'সপ্তম', 'অষ্টম', 'নবম', 'দশম', 'একাদশ', 'দ্বাদশ'];
const _cnMonthsZh = ['正月', '二月', '三月', '四月', '五月', '六月', '七月', '八月', '九月', '十月', '冬月', '腊月'];
const _stems = '甲乙丙丁戊己庚辛壬癸';
const _branches = '子丑寅卯辰巳午未申酉戌亥';
const _animalsBn = ['ইঁদুর', 'ষাঁড়', 'বাঘ', 'খরগোশ', 'ড্রাগন', 'সাপ', 'ঘোড়া', 'ছাগল', 'বানর', 'মোরগ', 'কুকুর', 'শূকর'];
const _animalsEn = ['Rat', 'Ox', 'Tiger', 'Rabbit', 'Dragon', 'Snake', 'Horse', 'Goat', 'Monkey', 'Rooster', 'Dog', 'Pig'];

/// (lunar year, month 1–12, day, leap) of [d]; null outside 1900–2098
/// (Korea: 1900–2049).
(int, int, int, bool)? chineseLunar(DateTime d, {bool korean = false}) {
  final table = korean ? _krYears : _cnYears;
  final off = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(1900, 1, 1)).inDays;
  if (off < (table.first >> 17)) return null;
  var i = table.length - 1;
  while (i >= 0 && (table[i] >> 17) > off) {
    i--;
  }
  final info = table[i];
  final leapMonth = (info >> 13) & 15;
  final count = leapMonth == 0 ? 12 : 13;
  var left = off - (info >> 17);
  for (var k = 0; k < count; k++) {
    final len = (info >> k) & 1 == 1 ? 30 : 29;
    if (left < len) {
      // Months before the leap one keep their number; the leap month repeats it.
      final isLeap = leapMonth != 0 && k == leapMonth;
      final month = leapMonth != 0 && k >= leapMonth ? k : k + 1;
      return (1900 + i, month, left + 1, isLeap);
    }
    left -= len;
  }
  return null; // past the end of the table's last month
}

String _cnDay(int d) {
  const n = '一二三四五六七八九十';
  if (d <= 10) return '初${n[d - 1]}';
  if (d < 20) return '十${n[d - 11]}';
  if (d == 20) return '二十';
  if (d < 30) return '廿${n[d - 21]}';
  return '三十';
}

CalDate? _chinese(DateTime d, {required bool korean}) {
  final c = chineseLunar(d, korean: korean);
  if (c == null) return null;
  final (y, m, day, leap) = c;
  final ord = isEn ? 'Month $m' : '${_cnOrdBn[m - 1]} মাস';
  final monthName = leap ? (isEn ? 'Leap $ord' : 'অধি-$ord') : ord;
  if (korean) {
    final dangi = y + 2333;
    return CalDate(year: dangi, month: m, day: day, leap: leap, monthName: monthName, yearLabel: isEn ? 'Dangi $dangi' : 'দাঙ্গি ${bnDigits(dangi)}', yearAfter: false, native: '음력 ${leap ? '윤' : ''}$m월 $day일');
  }
  final s = (y - 4) % 10, b = (y - 4) % 12;
  return CalDate(
      year: y,
      month: m,
      day: day,
      leap: leap,
      monthName: monthName,
      yearLabel: isEn ? 'Year of the ${_animalsEn[b]}' : '${_animalsBn[b]}র বছর',
      yearAfter: false,
      native: '${_stems[s]}${_branches[b]}年 ${leap ? '闰' : ''}${_cnMonthsZh[m - 1]}${_cnDay(day)}');
}
