// Turning the words a model marked (a span) into real values. The model only
// says WHICH words are the date, time or amount; the numbers always come from
// these rules, so a model can never invent a number.
import '../logic/bn.dart';
import '../logic/parser.dart' show findAmount, normalize;
import '../logic/when.dart';

/// What a date and/or time span means.
class SpanWhen {
  const SpanWhen(this.at, {required this.hasTime, required this.hasDay, required this.askAmPm});

  final DateTime at;
  final bool hasTime;
  final bool hasDay;

  /// Only an hour was said ("৭টায়") with no part of the day: ask সকাল না সন্ধ্যা.
  final bool askAmPm;
}

/// Date and time spans together ("কাল" + "সকাল ৯টায়"). A date without a year
/// is the next one to come; "রাত ১২টা" is 00:00 of the next day.
SpanWhen? whenOf(String? date, String? time, DateTime now) {
  final said = englishWhen([date, time].whereType<String>().where((s) => s.trim().isNotEmpty).join(' '));
  if (said.isEmpty) return null;
  final w = parseWhen(said, now);
  if (w == null) return null;
  return SpanWhen(w.at, hasTime: w.hasTime, hasDay: w.hasDay, askAmPm: w.hasTime && ampmUnclear(said));
}

/// Taka in an amount span: ১৫০০০/=, 2k, দেড় হাজার, আড়াইশো, ১ লাখ, 15,000.
int? amountOf(String? span) {
  if (span == null) return null;
  final s = span.replaceAllMapped(RegExp(r'([0-9০-৯])[,،]([0-9০-৯]{3})'), (m) => '${m[1]}${m[2]}');
  final k = RegExp(r'^\s*([0-9০-৯]+)\s*k\b', caseSensitive: false).firstMatch(s);
  if (k != null) return int.parse(asciiDigits(k[1]!)) * 1000;
  return findAmount(normalize(s));
}

/// A quantity span ("৩ কেজি", "আধা কেজি", "২ ডজন") → (number, unit).
(num, String)? quantityOf(String? span) {
  if (span == null) return null;
  final n = normalize(span);
  final half = RegExp(r'^(আধা|আধ|হাফ)\s+(\S+)$').firstMatch(n);
  if (half != null) return (0.5, half[2]!);
  final m = RegExp(r'^([0-9০-৯]+(?:\.[0-9০-৯]+)?)\s*(\S+)$').firstMatch(n);
  if (m != null) return (num.parse(asciiDigits(m[1]!)), m[2]!);
  final word = RegExp(r'^(\S+)\s+(\S+)$').firstMatch(n);
  if (word != null) {
    final v = findAmount(word[1]!);
    if (v != null) return (v, word[2]!);
  }
  return null;
}

/// English date and time words in Bangla (owner, 6 Nov: English messages):
/// the words the cloud reading marked go through the same date rules.
/// "next monday" → "আগামী সোমবার", "20 November" → "20 নভেম্বর",
/// "evening 7" → "সন্ধ্যা 7". Bangla passes through unchanged.
String englishWhen(String s) {
  if (!RegExp(r'[A-Za-z]').hasMatch(s)) return s;
  var t = ' ${s.toLowerCase()} ';
  const phrases = {
    'day after tomorrow': 'পরশু', 'the day after tomorrow': 'পরশু', 'tomorrow': 'কাল', 'tmrw': 'কাল', 'tonight': 'আজ রাত', 'today': 'আজ', 'yesterday': 'গতকাল',
    'next week': 'আগামী সপ্তাহে', 'this week': 'এই সপ্তাহে', 'next month': 'আগামী মাসে', 'this month': 'এই মাসে',
    'this morning': 'আজ সকাল', 'this evening': 'আজ সন্ধ্যা', 'in the morning': 'সকাল', 'in the evening': 'সন্ধ্যা', 'in the afternoon': 'বিকাল', 'at night': 'রাত',
    'morning': 'সকাল', 'afternoon': 'বিকাল', 'evening': 'সন্ধ্যা', 'night': 'রাত', 'noon': 'দুপুর', 'midday': 'দুপুর', 'midnight': 'রাত ১২টা',
    'next': 'আগামী', 'coming': 'আগামী',
  };
  const days = {'monday': 'সোমবার', 'tuesday': 'মঙ্গলবার', 'wednesday': 'বুধবার', 'thursday': 'বৃহস্পতিবার', 'friday': 'শুক্রবার', 'saturday': 'শনিবার', 'sunday': 'রবিবার',
    'mon': 'সোমবার', 'tue': 'মঙ্গলবার', 'wed': 'বুধবার', 'thu': 'বৃহস্পতিবার', 'fri': 'শুক্রবার', 'sat': 'শনিবার', 'sun': 'রবিবার'};
  const months = {'january': 'জানুয়ারি', 'february': 'ফেব্রুয়ারি', 'march': 'মার্চ', 'april': 'এপ্রিল', 'may': 'মে', 'june': 'জুন', 'july': 'জুলাই', 'august': 'আগস্ট',
    'september': 'সেপ্টেম্বর', 'october': 'অক্টোবর', 'november': 'নভেম্বর', 'december': 'ডিসেম্বর',
    'jan': 'জানুয়ারি', 'feb': 'ফেব্রুয়ারি', 'mar': 'মার্চ', 'apr': 'এপ্রিল', 'jun': 'জুন', 'jul': 'জুলাই', 'aug': 'আগস্ট', 'sep': 'সেপ্টেম্বর', 'sept': 'সেপ্টেম্বর', 'oct': 'অক্টোবর', 'nov': 'নভেম্বর', 'dec': 'ডিসেম্বর'};
  String swap(String text, Map<String, String> words) {
    final keys = words.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      text = text.replaceAll(RegExp('(?<![a-z])${RegExp.escape(k)}(?![a-z])'), words[k]!);
    }
    return text;
  }

  t = swap(t, phrases);
  t = swap(t, days);
  t = swap(t, months);
  // "on", "at", "the", "of", ordinal endings: not needed by the date rules.
  t = t.replaceAllMapped(RegExp(r'(\d+)(st|nd|rd|th)\b'), (m) => m[1]!);
  t = t.replaceAll(RegExp(r'(?<![a-z])(on|at|the|of|by|in)(?![a-z])'), ' ');
  // "o'clock" and a lone "pm"/"am" stay as the rules know them.
  t = t.replaceAll("o'clock", 'টা');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

