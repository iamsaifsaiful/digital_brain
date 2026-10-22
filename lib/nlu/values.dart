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
  final said = [date, time].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
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
