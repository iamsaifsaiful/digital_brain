/// The warranty or expiry date printed on a paper, read from the text the
/// phone recognised in its photo: "Valid till 12/05/2027", "EXP 08/2027",
/// "Warranty: 1 Year" with the invoice date… Only what is printed is used;
/// when nothing clear is there, nothing is guessed.
library;

import '../models/models.dart' show DocField;
import 'bn.dart' show asciiDigits, fullDate, bnDigits;
import 'lang.dart';

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

// ───────────────────────── The useful facts on a paper ─────────────────────────

/// One kind of fact printed on papers: how its label is written, and the
/// name the app gives it.
class _Label {
  const _Label(this.pattern, this.name, {this.date = false, this.value});
  final String pattern;
  final String name;
  final bool date;

  /// What the value must look like (a number, a blood group…), if anything.
  final String? value;
}

const _labels = [
  _Label(r"(?:father'?s?|fathers)\s*name|\bfather\b", 'পিতা'),
  _Label(r"(?:mother'?s?|mothers)\s*name|\bmother\b", 'মাতা'),
  _Label(r"(?:husband'?s?|spouse'?s?|wife'?s?)\s*name|\bhusband\b|\bspouse\b", 'স্বামী/স্ত্রী'),
  _Label(r'\bsurname\b', 'নামের শেষাংশ'),
  _Label(r'\bgiven\s*names?\b', 'নামের প্রথমাংশ'),
  _Label(r'^\s*(?:full\s*)?name\b(?!\s*of)', 'নাম'),
  _Label(r'\bdate\s*of\s*birth\b|\bbirth\s*date\b|\bd\.?o\.?b\b', 'জন্মতারিখ', date: true),
  _Label(r'\b(?:nid|national\s*id|id)\s*(?:no|number|#)\b\.?', 'NID নম্বর', value: r'\d[\d ]{8,20}\d'),
  _Label(r'\bpassport\s*(?:no|number|#)\b\.?', 'পাসপোর্ট নম্বর', value: r'[A-Z]{1,2}\s?\d{7,8}(?!\d)'),
  _Label(r'\bdate\s*of\s*issue\b|\bissue\s*date\b|\bissued\s*on\b|\bdate\s*of\s*issuance\b', 'ইস্যুর তারিখ', date: true),
  _Label(r'\b(?:driving\s*)?licen[cs]e\s*(?:no|number|#)\b\.?|\bd\.?l\.?\s*(?:no|number)\b\.?', 'লাইসেন্স নম্বর'),
  _Label(r'\bblood\s*group\b|\bblood\b', 'রক্তের গ্রুপ', value: r'(?:AB|A|B|O)\s?[+-]|(?:AB|A|B|O)\s?(?:positive|negative|pos|neg|\(\+\)|\(-\))'),
  _Label(r'\bimei\s*(?:no|number|1|2)?\b\.?', 'IMEI', value: r'\d{15}'),
  _Label(r'\b(?:serial|s/n|sl)\s*(?:no|number|#)?\b\.?', 'সিরিয়াল নম্বর'),
  _Label(r'\bmodel\s*(?:no|name|number)?\b\.?', 'মডেল'),
  _Label(r'\b(?:invoice|bill|memo|receipt|cash\s*memo)\s*(?:no|number|#)\b\.?', 'রসিদ / ইনভয়েস নম্বর'),
  _Label(r'\b(?:invoice|bill|purchase|sale|sold)\s*date\b|\bdate\s*of\s*(?:purchase|sale)\b', 'কেনার তারিখ', date: true),
  _Label(r'\btin\b\s*(?:no|number)?', 'TIN', value: r'\d{9,12}'),
  _Label(r'\b(?:a/c|account)\s*(?:no|number|#)\b\.?', 'অ্যাকাউন্ট নম্বর'),
  _Label(r'\bpolicy\s*(?:no|number|#)\b\.?', 'পলিসি নম্বর'),
  _Label(r'\b(?:reg(?:istration)?)\s*(?:no|number|#)\b\.?', 'রেজিস্ট্রেশন নম্বর'),
  _Label(r'\bchassis\s*(?:no|number)?\b\.?', 'চেসিস নম্বর'),
  _Label(r'\bengine\s*(?:no|number)?\b\.?', 'ইঞ্জিন নম্বর'),
  _Label(r'\b(?:mobile|phone|cell|contact)\s*(?:no|number)?\b\.?', 'ফোন', value: r'\+?\d[\d\- ]{9,15}\d'),
];

/// The useful facts printed on a paper — name, NID or passport number,
/// dates of birth and issue, serial/IMEI, invoice number… — read from the
/// text its photo gave, each with the app's own name for it. Only what is
/// printed beside its label (or in a passport's machine-readable lines);
/// nothing guessed. The expiry date is not here: see [docDateIn].
List<DocField> docFieldsIn(String text) {
  final out = <DocField>[];
  void add(String label, String value) {
    final v = value.trim().replaceAll(RegExp(r'\s+'), ' ').replaceAll(RegExp(r'^[:\-–.#\s]+|[,;:\-–.\s]+$'), '');
    if (v.isEmpty || v.length > 60 || out.any((f) => f.label == label)) return;
    out.add(DocField(label, v));
  }

  final t = asciiDigits(text);
  _passportMrz(t, add);
  final lines = [for (final l in t.split(RegExp(r'\r?\n'))) l.trim()];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    for (final l in _labels) {
      final m = RegExp(l.pattern, caseSensitive: false).firstMatch(line);
      if (m == null) continue;
      // The value: after the label on its line, else the next line.
      var rest = line.substring(m.end).replaceFirst(RegExp(r'^\s*[:\-–.#/]*\s*'), '');
      if (rest.isEmpty && i + 1 < lines.length) rest = lines[i + 1];
      if (rest.isEmpty) continue;
      // Another label's words are not this one's value.
      if (_labels.any((o) => o != l && RegExp(o.pattern, caseSensitive: false).hasMatch(rest) && RegExp(o.pattern, caseSensitive: false).firstMatch(rest)!.start == 0)) continue;
      if (l.date) {
        final d = _dates(rest.toLowerCase()).where((f) => !f.monthOnly).firstOrNull;
        if (d != null) add(tr(l.name), fullDate(d.date));
      } else if (l.value != null) {
        final v = RegExp(l.value!, caseSensitive: false).firstMatch(rest);
        if (v != null) add(tr(l.name), v[0]!.toUpperCase().replaceAll(RegExp(r'(?<=\d) (?=\d)'), ''));
      } else {
        add(tr(l.name), rest);
      }
      break;
    }
  }
  // "1 Year Warranty": said as it is printed.
  final w = RegExp(r'(?:warrant\w*|guarant\w*)[^\n\d]{0,20}(\d{1,2})\s*\+?\s*(years?|yrs?|months?|mon|mths?|days?)\b|(\d{1,2})\s*\+?\s*(years?|yrs?|months?|mon|mths?|days?)\s*(?:of\s+)?(?:warrant|guarant)', caseSensitive: false).firstMatch(t);
  if (w != null) {
    final n = int.parse(w[1] ?? w[3]!);
    final u = (w[2] ?? w[4]!).toLowerCase();
    add(tr('ওয়ারেন্টি'), u.startsWith('y') ? trf('{0} বছর', [bnDigits(n)]) : u.startsWith('d') ? trf('{0} দিন', [bnDigits(n)]) : trf('{0} মাস', [bnDigits(n)]));
  }
  // A lone 15-digit number on a phone's box or receipt is its IMEI.
  if (!out.any((f) => f.label == 'IMEI')) {
    final imei = RegExp(r'(?<!\d)\d{15}(?!\d)').firstMatch(t);
    if (imei != null && RegExp(r'imei', caseSensitive: false).hasMatch(t)) add('IMEI', imei[0]!);
  }
  return out;
}

/// A passport's two machine-readable lines (P<BGD…): name, number, birth
/// date — read even when the printed labels were not.
void _passportMrz(String t, void Function(String, String) add) {
  final rows = [for (final l in t.split(RegExp(r'\r?\n'))) l.replaceAll(' ', '').toUpperCase().replaceAll('«', '<')];
  for (var i = 0; i + 1 < rows.length; i++) {
    final a = rows[i], b = rows[i + 1];
    final head = RegExp(r'^P[A-Z<]([A-Z<]{3})([A-Z<]+)$').firstMatch(a);
    if (head == null || b.length < 28) continue;
    final m = RegExp(r'^([A-Z0-9<]{9})\d([A-Z<]{3})(\d{6})\d([MF<])(\d{6})').firstMatch(b);
    if (m == null) continue;
    final names = head[2]!.split('<<');
    final surname = names.first.replaceAll('<', ' ').trim();
    final given = names.length > 1 ? names[1].replaceAll('<', ' ').trim() : '';
    if (given.isNotEmpty || surname.isNotEmpty) add(tr('নাম'), [given, surname].where((x) => x.isNotEmpty).join(' '));
    add(tr('পাসপোর্ট নম্বর'), m[1]!.replaceAll('<', ''));
    DateTime? ymd(String s, {required bool past}) {
      final y = int.parse(s.substring(0, 2)), mo = int.parse(s.substring(2, 4)), d = int.parse(s.substring(4, 6));
      final now = DateTime.now().year % 100;
      final year = past ? (y > now ? 1900 + y : 2000 + y) : 2000 + y;
      return _make(year, mo, d);
    }

    final dob = ymd(m[3]!, past: true);
    if (dob != null) add(tr('জন্মতারিখ'), fullDate(dob));
    return;
  }
}
