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
  _n('রাতে'): (21, 3), _n('রাতের'): (21, 3), 'am': (9, 0), 'pm': (16, 2),
};

final _hourWords = {for (final w in ['টা', 'টায়', 'টার', 'টাতে', 'টে', 'টাই', 'বাজে', 'ta', 'tay', 'baje']) _n(w)};
final _minuteWords = {for (final w in ['মিনিট', 'মিনিটে', 'মিনিটের', 'min', 'minute', 'minutes']) _n(w)};
final _hourUnitWords = {for (final w in ['ঘণ্টা', 'ঘন্টা', 'ঘণ্টার', 'ঘন্টার', 'ঘণ্টায়', 'hour', 'hours', 'ghonta']) _n(w)};
/// What may follow a clock time: "৬.২০-এ", "৬.২০ তে", "৬টা ২০ মিনিটে".
final _atWords = {for (final w in ['এ', 'য়', 'তে', 'টে', 'e', 'te']) _n(w), ..._minuteWords};
final _afterWords = {for (final w in ['পরে', 'পর', 'বাদে', 'পরেই', 'later', 'pore']) _n(w)};
final _weekdayStems = [for (final d in bnWeekdays) _n(d.replaceAll('বার', ''))];
final _months = [for (final m in bnMonths) _n(m)];

/// "দশটায়" → "10টায়": hours said as words, as speech engines often write them.
final _hourNames = <String, int>{
  for (final e in {
    'এক': 1, 'দুই': 2, 'দু': 2, 'তিন': 3, 'চার': 4, 'পাঁচ': 5, 'ছয়': 6, 'ছ': 6, 'সাত': 7, 'আট': 8, 'নয়': 9, 'দশ': 10, 'এগারো': 11,
    'এগার': 11, 'বারো': 12, 'বার': 12,
  }.entries)
    _n(e.key): e.value,
};
final _hourSuffix = RegExp('^(.+?)(${['টায়', 'টাতে', 'টার', 'টা', 'টে'].map(_n).join('|')})\$');

String _hourWord(String x) {
  final m = _hourSuffix.firstMatch(x);
  if (m == null) return x;
  final h = _hourNames[m[1]];
  return h == null ? x : '$h${m[2]}';
}

int? _num(String w) => int.tryParse(w) ?? findAmount(w);

/// The day/time in [said], or null when it has none. Past times today move
/// to tomorrow unless "আজ" was said.
const _enHours = ['one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve'];

/// Times said in English inside Bengali speech ("eight pm-এ", "8 am",
/// "seven thirty pm") as the Bengali the rest of the app reads
/// ("রাত ৮টায়", "সকাল ৮টায়", "সন্ধ্যা ৭.৩০").
String englishTimes(String s) {
  String part(int h, bool pm) => pm
      ? (h == 12 ? 'দুপুর' : (h <= 4 ? 'বিকাল' : (h <= 6 ? 'সন্ধ্যা' : 'রাত')))
      : (h == 12 ? 'রাত' : (h <= 3 ? 'রাত' : 'সকাল'));
  String out(int h, String mm, String p) {
    final pm = p.startsWith('p');
    final period = p.isEmpty ? '' : '${part(h, pm)} ';
    return mm.isEmpty ? '$period$hটায়' : '$period$h.$mm';
  }

  final words = RegExp(r'\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)(?:\s+(thirty|fifteen|forty[- ]five))?\s*(a\.?m\.?|p\.?m\.?|o.?clock)(?:\s*-?\s*(?:এ|তে)(?![ঀ-৿]))?', caseSensitive: false);
  final digits = RegExp(r'(?<![0-9০-৯.])([0-9]{1,2})(?:[.:]([0-9]{2}))?\s*(a\.?m\.?|p\.?m\.?)(?![a-z])(?:\s*-?\s*(?:এ|তে)(?![ঀ-৿]))?', caseSensitive: false);
  return s.replaceAllMapped(words, (m) {
    final h = _enHours.indexOf(m[1]!.toLowerCase()) + 1;
    final mm = switch (m[2]?.toLowerCase()) { 'thirty' => '30', 'fifteen' => '15', null => '', _ => '45' };
    final p = m[3]!.toLowerCase().replaceAll('.', '');
    return out(h, mm, p.startsWith('o') ? '' : p);
  }).replaceAllMapped(digits, (m) {
    final h = int.parse(m[1]!);
    if (h < 1 || h > 12) return m[0]!;
    return out(h, m[2] ?? '', m[3]!.toLowerCase().replaceAll('.', ''));
  });
}

When? parseWhen(String said0, DateTime now) {
  // "১৪ ফেব্রুয়ারী": the month in any common spelling.
  final said = fixMonthSpellings(said0);
  // "৬:২০" → "৬.২০" (normalize drops the colon).
  final clockSaid = englishTimes(said).replaceAllMapped(RegExp(r'([0-9০-৯]{1,2})\s*:\s*([0-9০-৯]{2})'), (m) => '${m[1]}.${m[2]}');
  final w = [for (final x in words(normalize(clockSaid))) _hourWord(x)];
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
          // "১৫ জুন ২০২৯", "১৫ জুন, ২০২৯ সালে", "২০২৯ সালের ১৫ জুন": the
          // year said is the year — never the next 15 June.
          final y = _yearNear(w, i);
          if (y != null) {
            final e = DateTime(y, m + 1, d);
            if (e.month == m + 1) c = e;
          }
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
  var clock = false;
  for (var i = 0; i < w.length; i++) {
    final p = _periods[w[i]];
    if (p != null) period ??= p;
    // "৬.২০", "৬.২০-এ", "18.20": a clock time, never a count.
    final ck = RegExp(r'^(\d{1,2})\.(\d{2})-?(.*)$').firstMatch(w[i]);
    if (ck != null && hour == null) {
      final h = int.parse(ck[1]!), mi = int.parse(ck[2]!);
      final next = i + 1 < w.length ? w[i + 1] : '';
      final money = {_n('টাকা'), _n('টাকার'), _n('লাখ'), _n('হাজার'), _n('কেজি'), _n('কোটি')}.contains(next);
      if (h <= 23 && mi < 60 && !money && (ck[3]!.isEmpty || _hourWords.contains(ck[3]) || _atWords.contains(ck[3]))) {
        hour = h;
        minute = mi;
        clock = true;
        for (var j = i; j < w.length && j < i + 3; j++) {
          final p2 = _periods[w[j]];
          if (p2 != null) period ??= p2;
        }
        continue;
      }
    }
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
    // "৬টা ২০", "৬টা ২০ মিনিটে", "৬টা ২০-এ": minutes after the hour.
    int? after;
    if (mins == 0 && i + 1 < w.length) {
      final am = RegExp(r'^(\d{1,2})-?(.*)$').firstMatch(w[i + 1]);
      if (am != null && int.parse(am[1]!) < 60) {
        final rest = am[2]!;
        final follow = i + 2 < w.length ? w[i + 2] : '';
        if (_atWords.contains(rest) || (rest.isEmpty && (_atWords.contains(follow) || follow.isEmpty))) after = int.parse(am[1]!);
      }
    }
    // A bare "৩টা" is usually a count ("৩টা ডিম"); it is a time only with
    // সকাল/বিকেল… before it, "বাজে" after it, or minutes after it.
    if (suffix == _n('টা')) {
      final before = (i > 0 && _periods.containsKey(w[i - 1])) || (i > 1 && _periods.containsKey(w[i - 2]));
      final bajeNext = i + 1 < w.length && w[i + 1] == _n('বাজে');
      if (!before && !bajeNext && after == null) continue;
    }
    if (after != null) mins = after;
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
      // "৪টায় মিটিং" means 4 in the afternoon. A clock time ("৬.২০") is
      // the next time it comes round (see below).
      if (!clock && hour >= 1 && hour <= 6) hour += 12;
    } else if (kind == 1) {
      if (hour >= 1 && hour <= 5) hour += 12;
    } else if (kind == 2) {
      if (hour < 12) hour += 12;
    } else if (kind == 3) {
      if (hour >= 6 && hour < 12) hour += 12;
      if (hour == 12) {
        hour = 0;
        // "কাল রাত ১২টা": the night of that day — the next date at 00:00.
        if (day != null) day = day.add(const Duration(days: 1));
      }
    }
  } else if (period != null) {
    hour = period.$1;
    minute = 0;
  }

  if (day == null && hour == null) return null;
  final hasTime = hour != null;
  var d = day ?? today;
  var at = DateTime(d.year, d.month, d.day, hour ?? 9, minute ?? 0);
  // "৬.২০" said at 6 in the evening means 18:20 today, not 6:20 tomorrow.
  if (hasTime && period == null && hour >= 1 && hour <= 8 && !at.isAfter(now) && (day == null || explicitToday)) {
    final later = at.add(const Duration(hours: 12));
    if (later.isAfter(now) && later.day == at.day) at = later;
  }
  if (hasTime && !at.isAfter(now) && !explicitToday && day == null) {
    d = d.add(const Duration(days: 1));
    at = DateTime(d.year, d.month, d.day, hour, minute ?? 0);
  }
  return When(at, hasTime: hasTime, hasDay: day != null);
}

/// "কাল (শনিবার) সকাল ১০টা" — how the app says a moment back.
String sayWhen(DateTime at, DateTime now, {bool withTime = true}) {
  // 00:00 belongs to the night before: "শনিবার দিবাগত রাত ১২টা".
  if (withTime && at.hour == 0 && at.minute == 0) {
    final eve = DateTime(at.year, at.month, at.day).subtract(const Duration(days: 1));
    return '${sayWhen(eve, now, withTime: false)} দিবাগত রাত ১২টা';
  }
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final diff = day.difference(today).inDays;
  final dayText = switch (diff) {
    0 => 'আজ',
    1 => 'কাল (${weekdayName(day)})',
    2 => 'পরশু (${weekdayName(day)})',
    // Another year, far off: the year too ("বুধবার, ১ মে ২০৪১").
    _ when day.year != today.year => '${weekdayName(day)}, ${bnDigits(day.day)} ${bnMonths[day.month - 1]} ${bnDigits(day.year)}',
    _ => '${weekdayName(day)}, ${bnDigits(day.day)} ${bnMonths[day.month - 1]}',
  };
  return withTime ? '$dayText ${bnTime(at.hour, at.minute)}' : dayText;
}

final _timeBits = RegExp(
    '(সাড়ে|সোয়া|পৌনে)?\\s*(?<![০-৯0-9])[০-৯0-9]{1,2}(\\s*[:.]\\s*[০-৯0-9]{2})?\\s*(টায়|টাতে|টার|টাই|টা|টে|বাজে)(?![ঀ-৿])'
        .replaceAll('ড়', 'ড়')
        .replaceAll('য়', 'য়'));

/// [said] without the when-words, for a title: "কাল সকাল ১০টায় মিটিংয়ের কথা
/// মনে করিয়ে দিও" → "মিটিংয়ের কথা মনে করিয়ে দিও" (the caller cuts the rest).
/// A year (four digits) said with the date at [i] ("১৫ জুন ২০২৯",
/// "২০২৯ সালের ১৫ জুন"): after the month, or before the day with "সাল".
int? _yearNear(List<String> w, int i) {
  int? year(String x) {
    final n = int.tryParse(x.replaceAll(RegExp(r'[,।]'), ''));
    return n != null && n >= 1900 && n <= 2300 && x.replaceAll(RegExp(r'[,।]'), '').length == 4 ? n : null;
  }
  if (i + 2 < w.length) {
    final y = year(w[i + 2]);
    if (y != null) return y;
  }
  if (i >= 2 && w[i - 1].startsWith(_n('সাল'))) return year(w[i - 2]);
  if (i >= 1) return year(w[i - 1]);
  return null;
}

String withoutWhen(String said) {
  var s = fold(said);
  // "দশটায়", "তিনটায়": hours said as words go like "১০টায়".
  // (Only a clock time: "-টায়"/"-টে", or "-টা" after সকাল/বিকেল/রাত — "তিনটা
  // ফাইল" keeps its count.)
  final parts = s.split(' ');
  final dayparts = {for (final d in const ['ভোর', 'সকাল', 'দুপুর', 'বিকাল', 'বিকেল', 'সন্ধ্যা', 'রাত']) _n(d)};
  for (var i = 0; i < parts.length; i++) {
    final x = _n(parts[i]);
    final m = _hourSuffix.firstMatch(x);
    if (m == null || !_hourNames.containsKey(m[1])) continue;
    final atTime = m[2] != _n('টা') && m[2] != _n('টার');
    if (atTime || (i > 0 && dayparts.contains(_n(parts[i - 1])))) parts[i] = _hourWord(x);
  }
  s = parts.join(' ');
  // "আগামী রবিবার": the "next" goes with the day.
  s = s.replaceAll(RegExp('${fold('আগামী')}\\s+(?=(?:${bnWeekdays.map(fold).join('|')}))'), '');
  // "১৫ জুন ২০২৯", "২০২৯ সালের": the year goes with the date.
  s = s.replaceAll(RegExp('(?<=${bnMonths.map(fold).join('|')})\\s*,?\\s*[০-৯0-9]{4}(?:\\s+${fold('সাল')}\\S*|\\s*-?\\s*(?:${fold('এ')}|${fold('তে')}|${fold('র')}|${fold('এর')})(?=[\\s,।.!?]|\$))?(?=[\\s,।.!?]|\$)'), ' ');
  s = s.replaceAll(RegExp('(?:^|(?<=[\\s,।]))[০-৯0-9]{4}\\s+${fold('সাল')}\\S*'), ' ');
  s = s.replaceAll(RegExp(fold('[০-৯0-9]{1,2}\\s*[:.]\\s*[০-৯0-9]{2}(\\s*-?\\s*(এ|য়|তে|টায়|টা|টে|মিনিটে)(?=[\\s,।.!?]|\$))?')), ' ');
  s = s.replaceAll(RegExp(fold('([০-৯0-9]{1,2}\\s*(টায়|টা|টে))\\s+[০-৯0-9]{1,2}\\s*-?\\s*(মিনিটে|মিনিট|এ|তে)?(?=[\\s,।.!?]|\$)')), ' ');
  s = s.replaceAll(_timeBits, ' ');
  s = cutWords(s, const ['am', 'pm', 'AM', 'PM']);
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

/// Only the clock time and its part of day: "ডাক্তার দেখানো বিকেল ৫টায়" →
/// "ডাক্তার দেখানো". Other words (and counts like "তিনটা ফাইল") stay.
String withoutClock(String s) {
  final dayparts = ['ভোর', 'ভোরে', 'সকাল', 'সকালে', 'দুপুর', 'দুপুরে', 'বিকাল', 'বিকালে', 'বিকেল', 'বিকেলে', 'সন্ধ্যা', 'সন্ধ্যায়', 'রাত', 'রাতে'].map(fold).join('|');
  final hours = _hourNames.keys.join('|');
  final clock = '(?:(?:সাড়ে|সোয়া|পৌনে)\\s*)?(?:[০-৯0-9]{1,2}(?:\\s*[:.]\\s*[০-৯0-9]{2})?|$hours)\\s*(?:টায়|টাতে|টার|টা|টে|বাজে)';
  final re = RegExp(fold('(?:(?:$dayparts)\\s+)?$clock(?=[\\s,।.!?]|\$)'));
  final hasClock = RegExp(fold('(?:$dayparts)\\s+$clock|[০-৯0-9]{1,2}\\s*(?:টায়|টাতে|টে)|(?:$hours)(?:টায়|টাতে|টে)')).hasMatch(fold(s));
  if (!hasClock) return s;
  return fold(s).replaceAll(re, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
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

/// "৩০ মিনিট আগে", "১ ঘণ্টা আগে", "আধা ঘণ্টা আগে", "দেড় ঘণ্টা আগে", "২ দিন আগে"
/// inside a reminder request: the early notice, in minutes, and the
/// sentence without it (so the time and the title are read from the rest).
(int, String) splitBefore(String said) {
  final re = RegExp(r'(?:(\S+)\s+)?(মিনিট|মি\.|ঘণ্টা|ঘন্টা|দিন|minutes?|mins?|hours?|days?)\s*(?:খানেক\s*)?(?:আগে|আগেই|আগেও|before|early)', caseSensitive: false);
  final m = re.firstMatch(said);
  if (m == null) return (0, said);
  final unit = m[2]!.toLowerCase();
  final perUnit = unit.startsWith('দিন') || unit.startsWith('day') ? 1440 : (unit.startsWith('ঘ') || unit.startsWith('hour') ? 60 : 1);
  final word = (m[1] ?? '').trim();
  const halves = {'আধা': 0.5, 'আধ': 0.5, 'দেড়': 1.5, 'আড়াই': 2.5, 'সাড়ে': 0.5, 'half': 0.5};
  double? count;
  if (word.isEmpty) {
    count = 1;
  } else if (halves.containsKey(word)) {
    count = halves[word];
  } else {
    final n = _num(normalize(word).replaceAll(RegExp(r'[^০-৯0-9ঀ-৿a-z]'), ''));
    count = n?.toDouble();
  }
  if (count == null || count <= 0) return (0, said);
  final minutes = (count * perUnit).round();
  if (minutes <= 0 || minutes > 60 * 24 * 60) return (0, said);
  final rest = said.replaceRange(m.start, m.end, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return (minutes, rest);
}

/// "কাল আটটায়": an hour from 7 to 11 with no সকাল/রাত and no clock
/// minutes — morning or night is the person's to say, not a guess.
/// "চারটায়", "৬.২০-এ": a clock hour (1–12) with no ভোর/সকাল/দুপুর/বিকেল/
/// সন্ধ্যা/রাত, no am/pm and not "N মিনিট পরে" — morning or evening is the
/// person's to say. The time of day now never decides it.
/// Does [said] name a part of the day (or am/pm, or a relative time)?
bool saysDayPart(String said) =>
    RegExp(fold(r'(?:ভোর|সকাল|দুপুর|বিকাল|বিকেল|সন্ধ্যা|সন্ধা|রাত|am|pm|a\.m|p\.m|মিনিট\s+পর|ঘণ্টা\s+পর|ঘন্টা\s+পর|মিনিটে|ঘণ্টায়)')).hasMatch(' ${normalize(englishTimes(said))} ');

bool ampmUnclear(String said) {
  // "১১ টায়" (a space before the ending) is "১১টায়".
  final clockSaid = englishTimes(said)
      .replaceAllMapped(RegExp(r'([0-9০-৯]{1,2})\s*:\s*([0-9০-৯]{2})'), (m) => '${m[1]}.${m[2]}')
      .replaceAllMapped(RegExp(r'([0-9০-৯])\s+(টায়|টায়|টাতে|টার|টা|টে)(?=\s|$|[,।?])'), (m) => '${m[1]}${m[2]}');
  final f = ' ${normalize(clockSaid)} ';
  if (saysDayPart(said)) return false;
  final w = [for (final x in words(f.trim())) _hourWord(x)];
  for (var i = 0; i < w.length; i++) {
    final m = RegExp(fold(r'^(\d{1,2})(?:\.(\d{2}))?-?(টায়|টাতে|টার|টা|টে|এ|তে)?$')).firstMatch(w[i]);
    if (m == null) continue;
    final h = int.parse(m[1]!);
    if (h < 1 || h > 12) continue;
    final hasClock = m[2] != null;
    final next = i + 1 < w.length ? w[i + 1] : '';
    // "৩টা ডিম" is a count; a time needs টায়/বাজে, a clock, or minutes.
    if (!hasClock && m[3] == null) continue;
    if (!hasClock && m[3] == fold('টা') && next != fold('বাজে') && !RegExp(r'^\d').hasMatch(next)) continue;
    if (!hasClock && (m[3] == fold('এ') || m[3] == fold('তে'))) continue;
    return true;
  }
  return false;
}

/// Was [hour] (0–23, as a reading put it) said only as a bare clock hour —
/// "চারটায়" with no ভোর/বিকেল, am/pm or 24-hour form next to it? Looked up
/// per mention, so in "ভোর ৪টায় ওষুধ, আর ৫টায় নামাজ" 4 is clear and 5 is
/// open. With one time in the sentence, a part of the day anywhere in it
/// counts ("কাল সকালে মিটিং, আটটায় মনে করিও"). False when the hour is not
/// found as said (a relative time, a reading worked out elsewhere).
bool hourOpen(String said, int hour) => hourState(said, hour) ?? false;

/// As [hourOpen], but null when [hour] is not found in [said] at all.
bool? hourState(String said, int hour) {
  final h12 = hour % 12 == 0 ? 12 : hour % 12;
  final clockSaid = englishTimes(said).replaceAllMapped(RegExp(r'([0-9০-৯]{1,2})\s*:\s*([0-9০-৯]{2})'), (m) => '${m[1]}.${m[2]}');
  final f = ' ${normalize(clockSaid)} ';
  if (RegExp(fold(r'(?:মিনিট\s+পর|ঘণ্টা\s+পর|ঘন্টা\s+পর|মিনিটে|ঘণ্টায়)')).hasMatch(f)) return null;
  final part = RegExp(fold(r'^(?:ভোর|ভোরে|সকাল|সকালে|দুপুর|দুপুরে|বিকাল|বিকেল|বিকেলে|বিকালে|সন্ধ্যা|সন্ধ্যায়|সন্ধা|রাত|রাতে|রাতের|am|pm|a\.m|p\.m)$'));
  final w = [for (final x in words(f.trim())) _hourWord(x)];
  var mentions = 0;
  var open = false;
  var clear = false;
  for (var i = 0; i < w.length; i++) {
    final m = RegExp(fold(r'^(\d{1,2})(?:\.(\d{2}))?-?(টায়|টাতে|টার|টা|টে|এ|তে)?$')).firstMatch(w[i]);
    if (m == null) continue;
    final h = int.parse(m[1]!);
    final hasClock = m[2] != null;
    final next = i + 1 < w.length ? w[i + 1] : '';
    if (!hasClock && m[3] == null && !part.hasMatch(next)) continue;
    if (!hasClock && m[3] == fold('টা') && next != fold('বাজে') && !RegExp(r'^\d').hasMatch(next) && !part.hasMatch(next)) continue;
    if (!hasClock && (m[3] == fold('এ') || m[3] == fold('তে'))) continue;
    mentions++;
    if (h != h12 && h != hour) continue;
    if (h > 12 || h == 0) {
      clear = true;
      continue;
    }
    final near = (i > 0 && part.hasMatch(w[i - 1])) || (i > 1 && part.hasMatch(w[i - 2])) || part.hasMatch(next);
    if (near) {
      clear = true;
    } else {
      open = true;
    }
  }
  if (clear) return false;
  if (!open) return null;
  // One time in the sentence and a part of the day said elsewhere in it.
  if (mentions == 1 && RegExp(fold(r'(?:ভোর|সকাল|দুপুর|বিকাল|বিকেল|সন্ধ্যা|সন্ধা|রাত|am|pm)')).hasMatch(f)) return false;
  return true;
}

/// The two readings of an unclear hour, each the next time it comes round
/// (unless [day] was said): ("ভোর ৪টা", 04:00) and ("বিকেল ৪টা", 16:00);
/// for 12: noon and midnight.
List<DateTime> ampmReadings(DateTime at, DateTime now, {bool daySaid = false}) {
  final h12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final d = DateTime(at.year, at.month, at.day);
  final am = DateTime(d.year, d.month, d.day, h12 == 12 ? 0 : h12, at.minute).add(Duration(days: h12 == 12 ? 1 : 0));
  final pm = DateTime(d.year, d.month, d.day, h12 == 12 ? 12 : h12 + 12, at.minute);
  DateTime ahead(DateTime x) => !daySaid && !x.isAfter(now) ? x.add(const Duration(days: 1)) : x;
  return [ahead(am), ahead(pm)];
}

/// Only a part of the day was said ("কাল সকালে", "রাতে"), no clock hour:
/// that part ("সকালে"), or null.
String? partOnly(String said) {
  final f = ' ${fold(said)} ';
  final m = RegExp(fold(r'(?<=\s)(ভোরে|ভোর|সকালে|সকাল|সকালবেলা|দুপুরে|দুপুর|বিকেলে|বিকালে|বিকেল|সন্ধ্যায়|সন্ধ্যা|রাতে|রাত)(?=\s)')).firstMatch(f);
  if (m == null) return null;
  final hasClock = RegExp(fold(r'(?:[০-৯0-9]{1,2}\s*(?:টা|টায়|টাতে|টার|টে|[:.]\s*[০-৯0-9]{2})|(?:এক|দুই|দু|তিন|চার|পাঁচ|ছয়|সাত|আট|নয়|দশ|এগারো|এগার|বারো)(?:টা|টায়|টাতে|টার|টে)|মিনিট|ঘণ্টা|ঘন্টা)')).hasMatch(f);
  if (hasClock) return null;
  final p = m[1]!;
  for (final (k, v) in [('ভোর', 'ভোরে'), ('সকাল', 'সকালে'), ('দুপুর', 'দুপুরে'), ('বিকেল', 'বিকেলে'), ('বিকাল', 'বিকেলে'), ('সন্ধ্যা', 'সন্ধ্যায়'), ('রাত', 'রাতে')]) {
    if (p.startsWith(fold(k))) return v;
  }
  return p;
}
