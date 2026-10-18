/// The warranty or expiry date printed on a paper, read from the text the
/// phone recognised in its photo: "Valid till 12/05/2027", "EXP 08/2027",
/// "Warranty: 1 Year" with the invoice date… Only what is printed is used;
/// when nothing clear is there, nothing is guessed.
library;

import 'bn.dart' show asciiDigits;

class DocDate {
  const DocDate(this.date, {required this.warranty, required this.fromPeriod});

  /// The last day it is valid (or the warranty runs).
  final DateTime date;

  /// The paper speaks of a warranty/guarantee (not a passport-like expiry).
  final bool warranty;

  /// Worked out from "১ বছর ওয়ারেন্টি" and the purchase date, not printed.
  final bool fromPeriod;
}

const _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'sept': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// A date found in the text, and where.
class _Found {
  _Found(this.date, this.start, this.end, {this.monthOnly = false});
  final DateTime date;
  final int start;
  final int end;
  final bool monthOnly;
}

int _year(String y) {
  final n = int.parse(y);
  return y.length == 2 ? 2000 + n : n;
}

DateTime? _make(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1950 || y > 2100) return null;
  final t = DateTime(y, m, d);
  return t.month == m ? t : null;
}

List<_Found> _dates(String t) {
  final out = <_Found>[];
  bool taken(int s, int e) => out.any((f) => s < f.end && e > f.start);
  void add(DateTime? d, Match m, {bool monthOnly = false}) {
    if (d != null && !taken(m.start, m.end)) out.add(_Found(d, m.start, m.end, monthOnly: monthOnly));
  }

  // 2027-05-12
  for (final m in RegExp(r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b').allMatches(t)) {
    add(_make(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)), m);
  }
  // 12/05/2027, 12-05-27 (day first, as written here; month first only when the day cannot be the month).
  for (final m in RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4}|\d{2})\b').allMatches(t)) {
    var a = int.parse(m[1]!), b = int.parse(m[2]!);
    if (b > 12 && a <= 12) (a, b) = (b, a);
    add(_make(_year(m[3]!), b, a), m);
  }
  // 12 May 2027, 12th may, 2027, 12-may-27
  for (final m in RegExp(r'\b(\d{1,2})(?:st|nd|rd|th)?[\s\-/.,]*(jan|feb|mar|apr|may|jun|jul|aug|sept|sep|oct|nov|dec)[a-z]*[\s\-/.,]*(\d{4}|\d{2})\b').allMatches(t)) {
    add(_make(_year(m[3]!), _months[m[2]!]!, int.parse(m[1]!)), m);
  }
  // May 12, 2027
  for (final m in RegExp(r'\b(jan|feb|mar|apr|may|jun|jul|aug|sept|sep|oct|nov|dec)[a-z]*[\s\-.]*(\d{1,2})(?:st|nd|rd|th)?[\s,]+(\d{4})\b').allMatches(t)) {
    add(_make(int.parse(m[3]!), _months[m[1]!]!, int.parse(m[2]!)), m);
  }
  // EXP 08/2027, May 2027: the end of that month.
  for (final m in RegExp(r'\b(\d{1,2})[/.-](\d{4})\b').allMatches(t)) {
    final mo = int.parse(m[1]!);
    if (mo >= 1 && mo <= 12) add(DateTime(int.parse(m[2]!), mo + 1, 0), m, monthOnly: true);
  }
  for (final m in RegExp(r'\b(jan|feb|mar|apr|may|jun|jul|aug|sept|sep|oct|nov|dec)[a-z]*[\s\-.,]*(\d{4})\b').allMatches(t)) {
    add(DateTime(int.parse(m[2]!), _months[m[1]!]! + 1, 0), m, monthOnly: true);
  }
  out.sort((a, b) => a.start.compareTo(b.start));
  return out;
}

final _expiryWord = RegExp(
    r'(?:\bexp(?:iry|ires|ired|iration)?\b\.?|\bvalid(?:ity)?\s*(?:till|until|upto|up\s*to|thru|through|to)?\b|\bwarranty\s*(?:till|until|upto|up\s*to|ends?|expires?|expiry|valid|period|to)\b|\bguarantee\s*(?:till|until|upto|up\s*to|ends?)\b|\bdate\s+of\s+expiry\b|\bbest\s+before\b|\buse\s+before\b|\bvalid\s+date\b|\bdue\s+date\b|মেয়াদ|মেয়াদ)');
final _purchaseWord = RegExp(r'(?:\bdate\b|invoice|bill|purchase|purchased|sale|sold|cash\s*memo|memo|receipt|date\s+of\s+(?:purchase|sale|issue)|issue|delivery|activation|ক্রয়|ক্রয়|তারিখ)');
final _period = RegExp(r'(\d{1,2})\s*\+?\s*(years?|yrs?|months?|mon|mths?|days?)\b');

/// The paper's last valid day, or null when the text does not say it clearly.
DocDate? docDateIn(String text, DateTime now) {
  final t = asciiDigits(text).toLowerCase().replaceAll('‘', "'").replaceAll('’', "'");
  final warranty = RegExp(r'(?:warrant|guarant|ওয়ারেন্টি|ওয়ারেন্টি|গ্যারান্টি)').hasMatch(t);
  final found = _dates(t);
  bool sensible(DateTime d) => d.isAfter(DateTime(now.year - 20)) && d.isBefore(DateTime(now.year + 40));

  // 1) A date printed right after an expiry word (same line, or the next one).
  final lines = t.split(RegExp(r'\r?\n'));
  var at = 0;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final w = _expiryWord.firstMatch(line);
    if (w != null) {
      final from = at + w.start;
      final nextEnd = at + line.length + (i + 1 < lines.length ? 1 + lines[i + 1].length : 0);
      final near = found.where((f) => f.start >= from && f.start <= nextEnd && sensible(f.date)).toList();
      if (near.isNotEmpty) {
        // "Valid from 01/01/2026 to 31/12/2027": the later one.
        final last = near.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
        return DocDate(last.date, warranty: warranty, fromPeriod: false);
      }
    }
    at += line.length + 1;
  }

  // 2) "Warranty: 1 Year" (or "2 years warranty") from the purchase date.
  if (warranty) {
    final p = RegExp(r'(?:warrant\w*|guarant\w*)[^\n\d]{0,20}(\d{1,2})\s*\+?\s*(years?|yrs?|months?|mon|mths?|days?)\b|(\d{1,2})\s*\+?\s*(years?|yrs?|months?|mon|mths?|days?)\s*(?:of\s+)?(?:warrant|guarant)').firstMatch(t);
    if (p != null) {
      final n = int.parse(p[1] ?? p[3]!);
      final unit = (p[2] ?? p[4]!);
      final dated = found.where((f) => !f.monthOnly && sensible(f.date) && !f.date.isAfter(now)).toList();
      // The purchase date: the one written by a purchase word, or the only one there is.
      _Found? base;
      for (final f in dated) {
        final before = t.substring((f.start - 30).clamp(0, t.length), f.start);
        if (_purchaseWord.hasMatch(before)) {
          base = f;
          break;
        }
      }
      if (base == null && dated.length == 1) base = dated.single;
      if (base != null && n > 0) {
        final b = base.date;
        final d = unit.startsWith('y')
            ? DateTime(b.year + n, b.month, b.day)
            : unit.startsWith('d')
                ? b.add(Duration(days: n))
                : DateTime(b.year, b.month + n, b.day);
        if (sensible(d)) return DocDate(d, warranty: true, fromPeriod: true);
      }
    }
  }
  return null;
}

/// "১ বছর" etc. in [text] — used only to say why a date was chosen.
bool hasPeriod(String text) => _period.hasMatch(asciiDigits(text).toLowerCase());
