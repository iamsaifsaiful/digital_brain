/// Bengali digits, money and dates (English ones when the app is in English).
library;

import 'lang.dart';

const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

/// "1050" → "১০৫০".
String bnDigits(Object value) {
  final s = value.toString();
  if (isEn) return s;
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final d = int.tryParse(c);
    b.write(d != null && c.codeUnitAt(0) < 128 ? _bnDigits[d] : c);
  }
  return b.toString();
}

/// "১,০৫০" → "1,050". Leaves other characters alone.
String asciiDigits(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = _bnDigits.indexOf(c);
    b.write(i >= 0 ? '$i' : c);
  }
  return b.toString();
}

/// Groups the way Bangladesh does: 1,00,000 (lakh), then 1,00,00,000.
String groupLakh(int n) {
  final neg = n < 0;
  var s = n.abs().toString();
  if (s.length > 3) {
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final parts = <String>[];
    while (rest.length > 2) {
      parts.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) parts.insert(0, rest);
    s = '${parts.join(',')},$last3';
  }
  return neg ? '-$s' : s;
}

/// 1050 → "৳১,০৫০".
String taka(int amount) => '৳${bnDigits(groupLakh(amount.abs()))}';

/// 1050 → "১,০৫০" (no sign).
String bnNumber(int n) => bnDigits(groupLakh(n));

const bnMonths = [
  'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
];

const bnMonthsShort = [
  'জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
  'জুলাই', 'আগস্ট', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে',
];

/// Monday = 1 … Sunday = 7, as DateTime.weekday.
const bnWeekdays = ['সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার', 'শনিবার', 'রবিবার'];
const bnWeekdaysShort = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র', 'শনি', 'রবি'];

const enMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const enMonthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const enWeekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const enWeekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Month 1–12 → "অক্টোবর" / "October".
String monthName(int month) => (isEn ? enMonths : bnMonths)[month - 1];
String monthShort(int month) => (isEn ? enMonthsShort : bnMonthsShort)[month - 1];

/// Weekday 1 (Monday) – 7 → "শুক্রবার" / "Friday".
String dayName(int weekday) => (isEn ? enWeekdays : bnWeekdays)[weekday - 1];
String dayShort(int weekday) => (isEn ? enWeekdaysShort : bnWeekdaysShort)[weekday - 1];

String weekdayName(DateTime d) => dayName(d.weekday);
String weekdayShort(DateTime d) => dayShort(d.weekday);

/// "৯ অক্টোবর ২০২৬".
String fullDate(DateTime d) => '${bnDigits(d.day)} ${monthName(d.month)} ${bnDigits(d.year)}';

/// "৯ অক্টো".
String shortDate(DateTime d) => '${bnDigits(d.day)} ${monthShort(d.month)}';

/// "অক্টোবর ২০২৬".
String monthTitle(DateTime d) => '${monthName(d.month)} ${bnDigits(d.year)}';

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "আজ", "গতকাল", "আগামীকাল" or "৯ অক্টো".
String relativeDay(DateTime d, DateTime now) {
  final diff = dayOnly(d).difference(dayOnly(now)).inDays;
  if (diff == 0) return bnEn('আজ', 'Today');
  if (diff == -1) return bnEn('গতকাল', 'Yesterday');
  if (diff == 1) return bnEn('আগামীকাল', 'Tomorrow');
  return shortDate(d);
}

/// "সকাল ১০টা", "বিকেল ৫:৩০".
String bnTime(int hour, int minute) {
  if (isEn) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${minute.toString().padLeft(2, '0')} ${hour < 12 ? 'AM' : 'PM'}';
  }
  final String part;
  if (hour < 4) {
    part = 'রাত';
  } else if (hour < 12) {
    part = 'সকাল';
  } else if (hour < 15) {
    part = 'দুপুর';
  } else if (hour < 18) {
    part = 'বিকেল';
  } else if (hour < 20) {
    part = 'সন্ধ্যা';
  } else {
    part = 'রাত';
  }
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final m = minute == 0 ? 'টা' : ':${bnDigits(minute.toString().padLeft(2, '0'))}';
  return '$part ${bnDigits(h12)}$m';
}

/// Days from today until [d] ("আজ" when 0).
String daysLeftLabel(DateTime d, DateTime now) {
  final diff = dayOnly(d).difference(dayOnly(now)).inDays;
  if (isEn) {
    if (diff < 0) return '${-diff} days ago';
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    return '$diff days left';
  }
  if (diff < 0) return '${bnDigits(-diff)} দিন আগে';
  if (diff == 0) return 'আজ';
  if (diff == 1) return 'কাল';
  return '${bnDigits(diff)} দিন বাকি';
}
