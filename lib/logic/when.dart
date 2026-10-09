/// "কাল সকাল ১০টায়", "৩০ মিনিট পরে", "শুক্রবার বিকেলে", "১৫ তারিখে" →
/// a day and time.
library;

import 'bn.dart';
import 'parser.dart';

class When {
  const When(this.at, {required this.hasTime, required this.hasDay});

  /// The moment (09:00 when only a day was said).
  final DateTime at;
  final bool hasTime;
  final bool hasDay;

  DateTime get day => DateTime(at.year, at.month, at.day);
}

String _n(String s) => normalize(s);

final _periods = <String, (int, int)>{
  // word → (default hour, kind) kind: 0 morning, 1 noon, 2 afternoon/evening/night, 3 late night
  _n('ভোর'): (6, 0), _n('ভোরে'): (6, 0), _n('সকাল'): (9, 0), _n('সকালে'): (9, 0), _n('সকালবেলা'): (9, 0),
  _n('দুপুর'): (13, 1), _n('দুপুরে'): (13, 1), _n('বিকাল'): (16, 2), _n('বিকালে'): (16, 2), _n('বিকেল'): (16, 2),
  _n('বিকেলে'): (16, 2), _n('সন্ধ্যা'): (19, 2), _n('সন্ধ্যায়'): (19, 2), _n('সন্ধ্যার'): (19, 2), _n('রাত'): (21, 3),
  _n('রাতে'): (21, 3), _n('রাতের'): (21, 3),
};

final _hourWords = {for (final w in ['টা', 'টায়', 'টার', 'টাতে', 'টে', 'টাই', 'বাজে', 'ta', 'tay', 'baje']) _n(w)};
final _minuteWords = {for (final w in ['মিনিট', 'মিনিটে', 'মিনিটের', 'min', 'minute', 'minutes']) _n(w)};
final _hourUnitWords = {for (final w in ['ঘণ্টা', 'ঘন্টা', 'ঘণ্টার', 'ঘন্টার', 'ঘণ্টায়', 'hour', 'hours', 'ghonta']) _n(w)};
final _afterWords = {for (final w in ['পরে', 'পর', 'বাদে', 'পরেই', 'later', 'pore']) _n(w)};
final _weekdayStems = [for (final d in bnWeekdays) _n(d.replaceAll('বার', ''))];
final _months = [for (final m in bnMonths) _n(m)];

int? _num(String w) => int.tryParse(w) ?? findAmount(w);

/// The day/time in [said], or null when it has none. Past times today move
/// to tomorrow unless "আজ" was said.
When? parseWhen(String said, DateTime now) {
  final w = words(normalize(said));
  if (w.isEmpty) return null;

  // "৩০ মিনিট পরে", "২ ঘণ্টা পর", "আধা ঘণ্টা পরে", "দেড় ঘণ্টা পরে".
  for (var i = 0; i + 1 < w.length; i++) {
    final after = i + 2 < w.length && _afterWords.contains(w[i + 2]);
    if (!after) continue;
    int? minutes;
    final n = _num(w[i]);
    if (_minuteWords.contains(w[i + 1]) && n != null) minutes = n;
    if (_hourUnitWords.contains(w[i + 1])) {
      if (w[i] == _n('আধা') || w[i] == _n('আধ')) {
        minutes = 30;
      } else if (w[i] == _n('দেড়')) {
        minutes = 90;
      } else if (w[i] == _n('আড়াই')) {
        minutes = 150;
      } else if (n != null) {
        minutes = n * 60;
      }
    }
    if (minutes != null && minutes > 0 && minutes < 60 * 24 * 30) {
      final at = now.add(Duration(minutes: minutes));
      return When(DateTime(at.year, at.month, at.day, at.hour, at.minute), hasTime: true, hasDay: true);
    }
  }

  final today = DateTime(now.year, now.month, now.day);
  DateTime? day;
  var explicitToday = false;
  for (var i = 0; i < w.length && day == null; i++) {
    final x = w[i];
    if (x == _n('আজ') || x == _n('আজকে') || x == _n('আজকেই') || x == 'today') {
      day = today;
      explicitToday = true;
    } else if (x == _n('কাল') || x == _n('কালকে') || x == _n('আগামীকাল') || x == _n('কালকেই') || x == 'tomorrow') {
      day = today.add(const Duration(days: 1));
    } else if (x == _n('পরশু') || x == _n('পরশুদিন')) {
      day = today.add(const Duration(days: 2));
    } else {
      for (var k = 0; k < 7; k++) {
        if (x.startsWith('${_weekdayStems[k]}${_n('বার')}')) {
          final ahead = (k + 1 - now.weekday) % 7;
          day = today.add(Duration(days: ahead));
          explicitToday = ahead == 0;
        }
      }
      // "১৫ তারিখে", "১৫ অক্টোবর"
      final d = int.tryParse(x);
      if (day == null && d != null && d >= 1 && d <= 31 && i + 1 < w.length) {
        final next = w[i + 1];
        final m = _months.indexWhere((mm) => next.startsWith(mm));
        if (m >= 0) {
          var c = DateTime(now.year, m + 1, d);
          if (c.isBefore(today)) c = DateTime(now.year + 1, m + 1, d);
          day = c;
        } else if (next.startsWith(_n('তারিখ')) || next == _n('তাং')) {
          var c = DateTime(now.year, now.month, d);
          if (c.isBefore(today)) c = DateTime(now.year, now.month + 1, d);
          day = c;
        }
      }
    }
  }

  // The time: "সকাল ১০টায়", "সাড়ে ৪টায়", "১০:৩০টায়", "রাত ৯টা", or just "বিকেলে".
  int? hour, minute;
  (int, int)? period;
  for (var i = 0; i < w.length; i++) {
    final p = _periods[w[i]];
    if (p != null) period ??= p;
    final m = RegExp(r'^(\d{1,2})(.*)$').firstMatch(w[i]);
    if (m == null || hour != null) continue;
    var suffix = m[2]!;
    var mins = 0;
    var h = int.parse(m[1]!);
    // "10 30টায়" (the colon was dropped)
    if (suffix.isEmpty && i + 1 < w.length) {
      final mm = RegExp(r'^(\d{2})(.*)$').firstMatch(w[i + 1]);
      if (mm != null && int.parse(mm[1]!) < 60 && (_hourWords.contains(mm[2]) || (mm[2]!.isEmpty && i + 2 < w.length && _hourWords.contains(w[i + 2])))) {
        mins = int.parse(mm[1]!);
        suffix = mm[2]!.isEmpty ? w[i + 2] : mm[2]!;
      } else {
        suffix = w[i + 1];
      }
    }
    if (!_hourWords.contains(suffix) || h > 23) continue;
    final prev = i > 0 ? w[i - 1] : '';
    // A bare "৩টা" is usually a count ("৩টা ডিম"); it is a time only with
    // সকাল/বিকেল… before it or "বাজে" after it.
    if (suffix == _n('টা')) {
      final before = (i > 0 && _periods.containsKey(w[i - 1])) || (i > 1 && _periods.containsKey(w[i - 2]));
      final bajeNext = i + 1 < w.length && w[i + 1] == _n('বাজে');
      if (!before && !bajeNext) continue;
    }
    if (prev == _n('সাড়ে')) {
      mins = 30;
    } else if (prev == _n('সোয়া')) {
      mins = 15;
    } else if (prev == _n('পৌনে')) {
      mins = 45;
      h = h - 1 < 0 ? 23 : h - 1;
    }
    hour = h;
    minute = mins;
    // the period may come after: "১০টায় সকালে" — look ahead too
    for (var j = i; j < w.length && j < i + 3; j++) {
      final p2 = _periods[w[j]];
      if (p2 != null) period ??= p2;
    }
  }

  if (hour != null) {
    final kind = period?.$2;
    if (kind == null) {
      // "৪টায় মিটিং" means 4 in the afternoon.
      if (hour >= 1 && hour <= 6) hour += 12;
    } else if (kind == 1) {
      if (hour >= 1 && hour <= 5) hour += 12;
    } else if (kind == 2) {
      if (hour < 12) hour += 12;
    } else if (kind == 3) {
      if (hour >= 6 && hour < 12) hour += 12;
      if (hour == 12) hour = 0;
    }
  } else if (period != null) {
    hour = period.$1;
    minute = 0;
  }

  if (day == null && hour == null) return null;
  final hasTime = hour != null;
  var d = day ?? today;
  var at = DateTime(d.year, d.month, d.day, hour ?? 9, minute ?? 0);
  if (hasTime && !at.isAfter(now) && !explicitToday && day == null) {
    d = d.add(const Duration(days: 1));
    at = DateTime(d.year, d.month, d.day, hour, minute ?? 0);
  }
  return When(at, hasTime: hasTime, hasDay: day != null);
}

/// "কাল (শনিবার) সকাল ১০টা" — how the app says a moment back.
String sayWhen(DateTime at, DateTime now, {bool withTime = true}) {
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = day.difference(today).inDays;
  final dayText = switch (diff) {
    0 => 'আজ',
    1 => 'কাল (${weekdayName(day)})',
    2 => 'পরশু (${weekdayName(day)})',
    _ => '${weekdayName(day)}, ${bnDigits(day.day)} ${bnMonths[day.month - 1]}',
  };
  return withTime ? '$dayText ${bnTime(at.hour, at.minute)}' : dayText;
}

final _timeBits = RegExp(
    '(সাড়ে|সোয়া|পৌনে)?\\s*[০-৯0-9]{1,2}(\\s*[:.]\\s*[০-৯0-9]{2})?\\s*(টা|টায়|টার|টাতে|টে|টাই|বাজে)'
        .replaceAll('ড়', 'ড়')
        .replaceAll('য়', 'য়'));

/// [said] without the when-words, for a title: "কাল সকাল ১০টায় মিটিংয়ের কথা
/// মনে করিয়ে দিও" → "মিটিংয়ের কথা মনে করিয়ে দিও" (the caller cuts the rest).
String withoutWhen(String said) {
  var s = fold(said);
  s = s.replaceAll(_timeBits, ' ');
  s = s.replaceAll(RegExp('[০-৯0-9]+\\s*(মিনিট|ঘণ্টা|ঘন্টা)\\S*\\s*(পরে|পর|বাদে)'), ' ');
  s = s.replaceAll(RegExp(fold('(আধা|আধ|দেড়|আড়াই)\\s*(ঘণ্টা|ঘন্টা)\\S*\\s*(পরে|পর|বাদে)')), ' ');
  s = s.replaceAll(RegExp('[০-৯0-9]{1,2}\\s*(${fold('তারিখ')}\\S*|${bnMonths.map(fold).join('|')})'), ' ');
  s = cutWords(s, [
    'আজ', 'আজকে', 'আজকেই', 'কাল', 'কালকে', 'আগামীকাল', 'কালকেই', 'পরশু', 'পরশুদিন',
    'ভোর', 'ভোরে', 'সকাল', 'সকালে', 'দুপুর', 'দুপুরে', 'বিকাল', 'বিকালে', 'বিকেল', 'বিকেলে', 'সন্ধ্যা', 'সন্ধ্যায়',
    'রাত', 'রাতে', 'today', 'tomorrow',
    for (final d in bnWeekdays) ...[d, '$dে', '$dের'],
  ]);
  return s;
}

/// Removes whole words or phrases (Bengali has no \b, so spaces and
/// punctuation mark the edges).
String cutWords(String s, List<String> phrases) {
  var out = ' ${fold(s)} ';
  final sorted = [for (final p in phrases) fold(p)]..sort((a, b) => b.length.compareTo(a.length));
  for (final p in sorted) {
    out = out.replaceAll(RegExp('(?<=[\\s,।.!?:;])${RegExp.escape(p)}(?=[\\s,।.!?:;])', caseSensitive: false), ' ');
  }
  return out.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Tidy a title: no stray punctuation, no leading "যে".
String tidy(String s) {
  var t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  t = t.replaceAll(RegExp(r'^[,।:;\-–—\s]+|[,।:;\-–—\s]+$'), '').trim();
  t = cutWords(t, const ['যে']).trim();
  if (t.startsWith(fold('যে '))) t = t.substring(3).trim();
  return t;
}
