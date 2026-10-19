// Which items of a list the user means, and what to do with them — "এইগুলো
// সব মুছে দাও", "দ্বিতীয় আর চতুর্থটা শেষ", "প্রথম দুটো কাল রাখো",
// "দ্বিতীয়টা ছাড়া সব", "ব্যাংকেরটা থাকবে, বাকিগুলো বাদ", "এর মধ্যে
// জরুরিগুলো". One typed [Selection] for every menu and for the AI; it is
// resolved against the list the app last showed (state/bulk_chat.dart),
// never against the whole database unless that was said ("সব দিনের সব কাজ").
part of 'parser.dart';

enum SelKind {
  /// Every item of the list just shown ("এইগুলো", "সবগুলো", "সব").
  all,

  /// Certain places in it ("দ্বিতীয় আর চতুর্থটা", "১ আর ৩ নম্বর").
  indexes,

  /// The first or last n ("প্রথম দুটো", "শেষের তিনটা").
  first,
  last,

  /// From place a to b, both included ("এক থেকে তিন নম্বর").
  range,

  /// Items named ("বাজার আর ওষুধের কাজটা").
  names,

  /// Those of the list that are urgent / late / without a date / open.
  filter,

  /// The rest: the list minus what was picked before ("বাকিগুলো").
  rest,

  /// Everything, said explicitly ("সব দিনের সব কাজ").
  global,
}

class Selection {
  const Selection(this.kind, {this.indexes = const [], this.n = 0, this.from = 0, this.to = 0, this.names = const [], this.filter = '', this.exceptIdx = const [], this.exceptNames = const []});
  final SelKind kind;

  /// 1-based places; -1 is the last.
  final List<int> indexes;
  final int n;
  final int from;
  final int to;

  /// Each name's words (searchTerms of what was said).
  final List<List<String>> names;

  /// 'urgent', 'overdue', 'undated', 'open', 'done'.
  final String filter;

  /// Left out: places, or names ("দ্বিতীয়টা ছাড়া", "ব্যাংকেরটা থাকবে").
  final List<int> exceptIdx;
  final List<List<String>> exceptNames;

  bool get hasExcept => exceptIdx.isNotEmpty || exceptNames.isNotEmpty;

  Selection without({List<int> idx = const [], List<List<String>> names = const []}) =>
      Selection(kind, indexes: indexes, n: n, from: from, to: to, names: this.names, filter: filter, exceptIdx: [...exceptIdx, ...idx], exceptNames: [...exceptNames, ...names]);

  @override
  String toString() => '${kind.name}${indexes.isEmpty ? '' : indexes}${n == 0 ? '' : ' n=$n'}${kind == SelKind.range ? ' $from-$to' : ''}${names.isEmpty ? '' : ' $names'}${filter.isEmpty ? '' : ' $filter'}'
      '${hasExcept ? ' except $exceptIdx $exceptNames' : ''}';
}

/// A request about several items of a list at once. [domain] is the kind of
/// list ('tasks', 'reminders', 'notes', 'medicines', 'habits', 'money'), or
/// '' when the sentence did not say (the list just shown is meant).
class BulkAction extends Command {
  const BulkAction(super.transcript, {required this.selection, required this.op, this.domain = '', this.due, this.time, this.ampmOpen = false, this.day, this.span = TaskSpan.day, this.yearSaid = true});
  final Selection selection;

  /// 'delete', 'done', 'reopen', 'move', 'remind', 'reminder_off', 'urgent',
  /// 'show', 'reverse', 'report', 'restore', 'not_done'.
  final String op;
  final String domain;

  /// 'move': the new day.
  final DateTime? due;

  /// 'remind': minutes after midnight.
  final int? time;
  final bool ampmOpen;

  /// 'done'/'not_done' for habits: which day.
  final DateTime? day;

  /// 'move': "এগুলো জুন মাসে করব" — a month (or year), not a day.
  final TaskSpan span;

  /// 'move' to a month: false when no year was said — each to-do keeps its
  /// own year ("২০৪১ সালের মে" → জুন ২০৪১).
  final bool yearSaid;
}

const _collectiveP = r'(?:এই\s+(?:দুটি|দুটো|দুটা|দুইটা|দুই|তিনটা|তিনটি|চারটা|চারটি|পাঁচটা)(?:\s+কাজ)?|(?:দুটি|দুটো|দুটা|দুইটা|তিনটা|তিনটি|চারটা|চারটি)\s+কাজ|কাজ\s+(?:দুটি|দুটো|দুটা|দুইটা|তিনটা|তিনটি|চারটা)|এতে|এগুলোতে|এগুলায়|এইগুলো|এইগুলা|এই\s+গুলো|এই\s+গুলা|এগুলো|এগুলা|এগুলি|ওগুলো|ওগুলা|ওইগুলো|ওইগুলা|ঐগুলো|সেগুলো|সেগুলা|এসব|ওসব|এই\s+সব|ওই\s+সব|সবগুলো|সবগুলা|সবগুলি|সবকটা|সবকটি|সবকয়টা|সবক’টা|সব|সমস্ত|উপরেরগুলো|তালিকার\s+সব|যেগুলো\s+দেখালে|যেগুলো\s+বললে|এই\s+কাজগুলো|ওই\s+কাজগুলো|কাজগুলো|কাজগুলা|এই\s+(?:নোট|রিমাইন্ডার|ওষুধ|অভ্যাস)গুলো|(?:নোট|রিমাইন্ডার|ওষুধ|অভ্যাস)গুলো|(?:নোট|রিমাইন্ডার|ওষুধ|অভ্যাস)গুলোর|(?:টাকা|পাওনা|দেনা|ধার|ঋণ)গুলো|(?:টাকা|পাওনা|দেনা|ধার|ঋণ)গুলা)';

/// "জুন মাসে", "জুনে", "ডিসেম্বরের": the month named (1–12) with no day of it.
int? _monthSaid(String f) {
  for (var i = 0; i < bnMonths.length; i++) {
    final m = RegExp('(?:^|\\s)${fold(bnMonths[i])}(?:ে|ের|এ|এর|\\s+মাসে|\\s+মাসের|\\s+মাস)?(?:গুলো|গুলা|গুলি|টা|টি)?(?=\\s|\$)').firstMatch(f);
    if (m == null) continue;
    // "১৫ জুনে": a day of it — a day, not the month.
    final before = f.substring(0, m.start).trim();
    if (RegExp(r'[0-9০-৯]{1,2}$').hasMatch(before)) return null;
    return i + 1;
  }
  return null;
}

const _ordWords = {'প্রথম': 1, 'দ্বিতীয়': 2, 'তৃতীয়': 3, 'চতুর্থ': 4, 'পঞ্চম': 5, 'ষষ্ঠ': 6, 'সপ্তম': 7, 'অষ্টম': 8, 'নবম': 9, 'দশম': 10};
const _countWords = {'দু': 2, 'এক': 1, 'একটা': 1, 'দুই': 2, 'দুটো': 2, 'দুটা': 2, 'দুইটা': 2, 'দুটি': 2, 'তিন': 3, 'তিনটা': 3, 'তিনটি': 3, 'চার': 4, 'চারটা': 4, 'চারটি': 4, 'পাঁচ': 5, 'পাঁচটা': 5, 'পাঁচটি': 5, 'ছয়': 6, 'ছয়টা': 6, 'সাত': 7, 'সাতটা': 7, 'আট': 8, 'নয়': 9, 'দশ': 10, 'এগারো': 11, 'বারো': 12, 'তেরো': 13, 'চৌদ্দ': 14, 'পনেরো': 15, 'ষোল': 16, 'সতেরো': 17, 'আঠারো': 18, 'উনিশ': 19, 'বিশ': 20};

int? _countOf(String w) {
  final a = int.tryParse(asciiDigits(w).replaceAll(RegExp(r'[^0-9]'), ''));
  if (a != null && a > 0) return a;
  for (final e in _countWords.entries) {
    if (_tf(e.key) == _tf(w)) return e.value;
  }
  final stem = w.replaceAll(_tre(r'(?:টার|টির|টোর|গুলোর|টাকে|টিকে|টা|টি|টো|গুলো|টাই|টোই)$'), '');
  for (final e in _countWords.entries) {
    if (_tf(e.key) == _tf(stem)) return e.value;
  }
  return null;
}

/// "২য়", "৩য়", "৪র্থ", "১ম", "6th": a place written with its ending.
int? _numberedOrd(String s) {
  final m = RegExp(r'^([0-9০-৯]{1,2})\s*(?:ম|য়|য়|র্থ|ষ্ঠ|তম|st|nd|rd|th)$').firstMatch(s);
  return m == null ? null : int.parse(asciiDigits(m[1]!));
}

int? _ordOf(String w) {
  final s = w.replaceAll(_tre(r'(?:টা|টি|টাকে|টার|টায়|টাও)$'), '');
  final numbered = _numberedOrd(s);
  if (numbered != null) return numbered;
  for (final e in _ordWords.entries) {
    if (_tf(e.key) == _tf(s)) return e.value;
  }
  if (_tf(s) == _tf('শেষের') || _tf(s) == _tf('শেষ') || _tf(s) == _tf('নিচের')) return -1;
  final n = _tre(r'^(\S+?)(?:নম্বর|নাম্বার|নং)$').firstMatch(s);
  if (n != null) return _countOf(n[1]!);
  return null;
}

/// Places said with "আর/ও/এবং": "দ্বিতীয় আর চতুর্থটা", "১ আর ৩ নম্বর".
List<int> _ordList(String f) {
  const one = r'(?:প্রথম|দ্বিতীয়|তৃতীয়|চতুর্থ|পঞ্চম|ষষ্ঠ|সপ্তম|অষ্টম|নবম|দশম|[০-৯0-9]+|এক|দুই|তিন|চার|পাঁচ|ছয়|সাত|আট|নয়|দশ)';
  final m = _tre(r'(?<=\s)(' + one + r'(?:টা|টি)?(?:\s*(?:,|আর|ও|এবং)\s*' + one + r'(?:টা|টি)?)+)(\s*(?:নম্বর|নাম্বার|নং))?(?:টা|টি|টাকে|গুলো)?(?=\s)').firstMatch(f);
  if (m == null) return const [];
  // Count words ("পাঁচ আর সাত") are places only with "নম্বর".
  if (m[2] == null && _thas(' ${m[1]} ', r'(?<=\s)(?:এক|দুই|তিন|চার|পাঁচ|ছয়|সাত|আট|নয়|দশ)(?=\s|টা|টি)')) return const [];
  final out = <int>[];
  for (final w in m[1]!.split(_tre(r'\s*(?:,|আর|ও|এবং)\s*'))) {
    final x = w.trim();
    if (x.isEmpty) continue;
    final o = _ordOf(x) ?? _countOf(x);
    if (o == null) return const [];
    out.add(o);
  }
  return out.length >= 2 ? out : const [];
}

/// The selection in [f] (folded, padded) — null when the sentence points at
/// no group (a single "দ্বিতীয়টা" stays with the one-item rules).
/// First word of an except name meaning "that one" ("ফোনেরটা থাকবে").
const exceptOne = '#one';

Selection? selectionIn(String f) {
  // "দ্বিতীয়টা ছাড়া সব", "ব্যাংকেরটা থাকবে, বাকিগুলো বাদ", "সব মুছো, শুধু ব্যাংকেরটা থাকবে".
  final exceptIdx = <int>[];
  final exceptNames = <List<String>>[];
  var g = f;
  for (final re in [
    // "রবিনের বোনের বিয়ের দাওয়াতের কাজ রেখে বাকিগুলো বাদ দাও": a longer
    // name, from the start of the sentence (or a comma) up to "রেখে/ছাড়া".
    _tre(r'(?:^|,)\s*(?:শুধু|কেবল|খালি)?\s*(\S+(?:\s+\S+){0,6}?)\s+(?:রেখে|ছাড়া|বাদে|বাদ\s+দিয়ে)\s+(?=(?:সব|বাকি|অন্য))'),
    _tre(r'(?<=\s)(\S+(?:\s+\S+)?)\s+(?:ছাড়া|বাদে|বাদ\s+দিয়ে|রেখে)\s+(?=(?:সব|বাকি|অন্য))'),
    // "বিয়ের কাজগুলো রেখে দাও, বাকিগুলো বাদ": kept by a verb, the rest after a comma.
    _tre(r'(?:^|,)\s*(?:শুধু|কেবল|খালি)?\s*(\S+(?:\s+\S+){0,6}?)\s+(?:রেখে\s+(?:দাও|দিও|দিন|দেন)|রাখো|রাখ|রেখো|রাখবে)(?=\s*,\s*(?:বাকি|অন্য|সব))'),
    // "রবিনের বোনের বিয়ের দাওয়াত থাকবে শুধু", "শুধু ব্যাংকেরটা থাকবে".
    _tre(r'(?:^|,)\s*(?:শুধু|কেবল|খালি)?\s*(\S+(?:\s+\S+){0,6}?)\s+(?:থাকবে|থাকুক|রাখো\s+না|বাদ\s+থাকবে|থাক)(?=[\s,])'),
    _tre(r'(?<=\s)(?:শুধু|কেবল|খালি)?\s*(\S+(?:\s+\S+)?)\s+(?:থাকবে|থাকুক|রাখো\s+না|বাদ\s+থাকবে|থাক)(?=[\s,])'),
  ]) {
    final m = re.firstMatch(g);
    if (m == null) continue;
    final w = m[1]!.trim();
    final o = _ordOf(w);
    // "৩ নং ৪নং", "২ আর ৩ নম্বর": several places.
    final wd = asciiDigits(w);
    final nums = [for (final x in _tre(r'([0-9]+)\s*(?:নং|নম্বর|নাম্বার)?').allMatches(wd)) int.parse(x[1]!)];
    final onlyNums = nums.isNotEmpty && _tre(r'^(?:\s*[0-9]+\s*(?:নং|নম্বর|নাম্বার)?(?:টা|টি)?\s*(?:,|আর|ও|এবং)?)+\s*$').hasMatch(wd);
    // "তিন আর চার রেখে": places said as words.
    final wordPlaces = [for (final x in w.split(_tre(r'\s*(?:,|আর|ও|এবং)\s*'))) if (x.trim().isNotEmpty) _ordOf(x.trim().replaceAll(_tre(r'\s*(?:নম্বর|নাম্বার|নং)$'), '')) ?? _countOf(x.trim().replaceAll(_tre(r'\s*(?:নম্বর|নাম্বার|নং)$'), ''))];
    final allWords = wordPlaces.length >= 2 && !wordPlaces.contains(null);
    if (o != null) {
      exceptIdx.add(o);
    } else if (allWords) {
      exceptIdx.addAll(wordPlaces.whereType<int>());
    } else if (onlyNums) {
      exceptIdx.addAll(nums);
    } else {
      final terms = searchTerms(normalize(w.replaceAll(_tre(r'(?:ের|এর|র)?(?:টা|টি|গুলো)$'), '').replaceAll(_tre(r'(?:কাজ|নোট)$'), '')));
      // "ফোনেরটা থাকবে" means one; "জন্মদিনের গুলো থাকবে" / "জন্মদিন
      // ছাড়া" all by that name. The one-ness travels as a first mark.
      final one = _thas(' $w ', r'(?:টা|টি)\s');
      if (terms.isNotEmpty) exceptNames.add([if (one) exceptOne, ...terms]);
    }
    g = g.replaceRange(m.start, m.end, ' ');
    // One name said once is enough: the shorter forms after it would only
    // find a piece of the same words.
    if (exceptIdx.isNotEmpty || exceptNames.isNotEmpty) break;
  }
  final hasRest = _thas(g, r'(?<=\s)(?:বাকিগুলো|বাকিগুলা|বাকি\s+সব|বাকি\s+সবগুলো|অন্যগুলো|অন্য\s+সব|বাকিগুলোর)(?=\s)');
  Selection withExcept(Selection s) => Selection(s.kind, indexes: s.indexes, n: s.n, from: s.from, to: s.to, names: s.names, filter: s.filter, exceptIdx: exceptIdx, exceptNames: exceptNames);

  // "৪–৮ নম্বর", "৪-৮": a range written with a dash.
  final dash = _tre(r'(?<=\s)([0-9০-৯]{1,2})\s*[–—-]\s*([0-9০-৯]{1,2})(?:\s*(?:নম্বর|নাম্বার|নং))?(?:টা|টি|গুলো)?(?=\s)').firstMatch(g);
  if (dash != null && !_thas(g, r'(?:তারিখ|টায়|টাকা|মিনিট|ঘণ্টা)')) {
    final a = int.parse(asciiDigits(dash[1]!)), b = int.parse(asciiDigits(dash[2]!));
    if (a > 0 && b >= a) return withExcept(Selection(SelKind.range, from: a, to: b));
  }
  // "৩ নং ৪নং", "৩নং ৪নং ৭নং": places side by side, each with its নং.
  final side = _tre(r'(?<=\s)((?:[0-9০-৯]{1,2}\s*(?:নং|নম্বর|নাম্বার)(?:টা|টি)?\s+){1,}[0-9০-৯]{1,2}\s*(?:নং|নম্বর|নাম্বার)(?:টা|টি)?)(?=\s)').firstMatch(g);
  if (side != null) {
    final nums = [for (final x in RegExp(r'([0-9০-৯]{1,2})').allMatches(side[1]!)) int.parse(asciiDigits(x[1]!))];
    if (nums.length >= 2) return withExcept(Selection(SelKind.indexes, indexes: nums));
  }
  // "এক থেকে তিন নম্বর", "১ থেকে ৩".
  // "৪নং থেকে ৮নং": the number with its নং attached, too.
  final range = _tre(r'(?<=\s)(\S+?)(?:\s*(?:নম্বর|নাম্বার|নং))?\s+(?:থেকে|হতে)\s+(\S+?)(?:\s*(?:নম্বর|নাম্বার|নং))?(?:টা|টি|গুলো)?\s').firstMatch(g);
  if (range != null) {
    final a = _ordOf(range[1]!) ?? _countOf(range[1]!), b = _ordOf(range[2]!) ?? _countOf(range[2]!);
    if (a != null && b != null && a > 0 && b > 0 && !_thas(g, r'(?:তারিখ|টায়|টাকা|মিনিট|ঘণ্টা)')) return withExcept(Selection(SelKind.range, from: a, to: b));
  }
  // "প্রথম দুটো", "উপরের তিনটা", "শেষের তিনটা", "শেষ দুটো".
  final fl = _tre(r'(?<=\s)(প্রথম|উপরের|শেষের|শেষ|নিচের)\s+(\S+)(?=\s)').firstMatch(g);
  if (fl != null) {
    final c = _countOf(fl[2]!);
    if (c != null && c >= 2) {
      final first = _tf(fl[1]!) == _tf('প্রথম') || _tf(fl[1]!) == _tf('উপরের');
      return withExcept(Selection(first ? SelKind.first : SelKind.last, n: c));
    }
  }
  final many = _ordList(g);
  if (many.isNotEmpty) return withExcept(Selection(SelKind.indexes, indexes: many));
  // "এর মধ্যে জরুরিগুলো", "যেগুলোর সময় পার হয়েছে", "সময় দেওয়া নেই যেগুলো".
  if (_thas(g, r'(?:জরুরিগুলো|জরুরি\s+গুলো|জরুরি\s+কাজগুলো|যেগুলো\s+জরুরি)')) return withExcept(const Selection(SelKind.filter, filter: 'urgent'));
  if (_thas(g, r'(?:যেগুলোর\s+সময়\s+(?:পার|পেরিয়ে)|সময়\s+পেরিয়ে\s+যাওয়াগুলো|দেরি\s+হওয়াগুলো|পুরোনোগুলো)')) return withExcept(const Selection(SelKind.filter, filter: 'overdue'));
  if (_thas(g, r'(?:সময়|তারিখ|দিন)\s+(?:দেওয়া|দেয়া)\s+নেই\s+যেগুলো|যেগুলোর\s+(?:তারিখ|দিন)\s+নেই')) return withExcept(const Selection(SelKind.filter, filter: 'undated'));
  if (_thas(g, r'যেগুলো\s+(?:শেষ\s+)?(?:হয়নি|হয়নি|করিনি|বাকি)')) return withExcept(const Selection(SelKind.filter, filter: 'open'));
  // "সব দিনের সব কাজ", "পুরো তালিকার সব".
  if (_thas(g, r'(?:সব\s+দিনের|সব\s+তারিখের|পুরো\s+তালিকার|তালিকার\s+সব\s+কাজ|যত\s+কাজ\s+আছে|সব\s+কাজই)')) return withExcept(const Selection(SelKind.global));
  // "ব্যাংকেরটা থাকবে, বাকিগুলো বাদ": the list without what stays.
  if (hasRest && (exceptIdx.isNotEmpty || exceptNames.isNotEmpty)) return withExcept(const Selection(SelKind.all));
  if (hasRest) return withExcept(const Selection(SelKind.rest));
  if (_thas(g, r'(?<=\s)' + _collectiveP + r'(?:ই|ও|কে|র|ের)?(?=\s)')) return withExcept(const Selection(SelKind.all));
  // "বাজার আর ওষুধের কাজটা", "নোট দুটো" — names of several.
  final named = _tre(r'^\s*(.+?)\s+(?:কাজ|কাজটা|কাজগুলো|কাজ\s+দুটো|দুটো|দুটা|দুটোই)(?=\s)').firstMatch(g);
  if (named != null && _thas(named[1]!, r'\s(?:আর|ও|এবং|,)\s')) {
    final parts = named[1]!.split(_tre(r'\s*(?:আর|ও|এবং|,)\s*')).map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    final names = [for (final p in parts) searchTerms(normalize(p.replaceAll(_tre(r'(?:ের|এর|র)$'), '')))].where((t) => t.isNotEmpty).toList();
    if (names.length >= 2) return withExcept(Selection(SelKind.names, names: names));
  }
  if (exceptIdx.isNotEmpty || exceptNames.isNotEmpty) return withExcept(const Selection(SelKind.all));
  return null;
}

/// The list kind a sentence names ("নোটগুলো", "ওষুধের", "অভ্যাস"), or ''.
String _bulkDomain(String f) {
  if (_thas(f, r'(?:রিমাইন্ডার|reminder)গুলো|সব\s+রিমাইন্ডার')) return 'reminders';
  if (_thas(f, r'(?:নোট|note)(?:গুলো|গুলা|দুটো|দুটা)?(?=\s)')) return 'notes';
  if (_thas(f, r'(?:ওষুধ|ঔষধ)')) return 'medicines';
  if (_thas(f, r'(?:অভ্যাস)')) return 'habits';
  // "পাওনাগুলো", "সব দেনা", "ধারগুলো": the people's balances.
  if (_thas(f, r'(?:পাওনা|দেনা|ধার|ঋণ)')) return 'ledger';
  if (_thas(f, r'(?:লেনদেন|খরচ|আয়)')) return 'money';
  if (_thas(f, r'(?:মাপ|প্রেশার|প্রেসার|সুগার|ওজন|রিডিং)')) return 'health';
  if (_thas(f, r'(?:কাজ|task|টাস্ক)')) return 'tasks';
  return '';
}

/// What to do with them. Commands only ("মুছো", "মুছে দাও"), never a
/// description ("ও এসব মুছে দেয়"). '' when there is no such verb.
/// "৩০ অক্টোবর এবং ৩১ ডিসেম্বরের রিমাইন্ডার বাদ দাও", "কালকের সব
/// কাজ মুছে দাও": the items of named days. Null unless days, a kind
/// (reminders, alarms or to-dos) and a change are all said.
({String domain, String op, List<DateTime> days, bool alarms})? datedBulk(String said, DateTime now) {
  final f = ' ${_tf(normalize(said))} ';
  final alarms = _thas(f, r'(?:অ্যালার্ম|এলার্ম|alarm)');
  // (To-dos of a day have their own rules: "আজকের সব কাজ মুছে দাও".)
  final domain = alarms || _thas(f, r'(?:রিমাইন্ডার|reminder|মনে\s+করানো)') ? 'reminders' : '';
  if (domain.isEmpty) return null;
  final op = _bulkOp(f);
  if (!const {'delete', 'reminder_off', 'done'}.contains(op)) return null;
  // Each part between "এবং/আর/ও/," read for its own day.
  final days = <DateTime>[];
  for (final part in f.split(_tre(r'\s+(?:এবং|আর|ও)\s+|,'))) {
    final w = parseWhen(part, now);
    if (w != null && w.hasDay) {
      final d = DateTime(w.day.year, w.day.month, w.day.day);
      if (!days.contains(d)) days.add(d);
    }
  }
  if (days.isEmpty) return null;
  return (domain: domain, op: op, days: days, alarms: alarms);
}

String _bulkOp(String f0) {
  // "শেষের তিনটা", "শেষ দুটো" choose items; they are not "done".
  final f = f0.replaceAll(_tre(r'(?<=\s)(?:শেষের|শেষ)\s+(?=\S+(?:টা|টি|টো|টোই|গুলো)?(?:\s|$))(?=(?:এক|দুই|দু|তিন|চার|পাঁচ|ছয়|সাত|[০-৯0-9]))'), ' ').replaceAll(_tre(r'(?<=\s)শেষেরটা'), ' ');
  // "এগুলো কাজের তালিকায় যুক্ত করো": adding what was just said — not this.
  if (_thas(f, r'(?:যুক্ত\s+কর|যোগ\s+কর|অ্যাড\s+কর|(?<=\s)add(?=\s)|তালিকায়\s+(?:রাখো|লিখে|তোলো|তুলে)|লিস্টে\s+(?:রাখো|লিখে|তোলো)|লিখে\s+রাখো)')) return '';
  if (_thas(f, r'(?:উল্টো\s+(?:ক্রমে|করে)|উল্টা\s+করে)')) return 'reverse';
  if (_thas(f, r'(?:দেখাও|দেখান|বলো|বলুন)\s*$') && !_thas(f, r'(?:মুছ|ডিলিট|রিমাইন্ডার)')) return 'show';
  if (_thas(f, r'(?:ফেরত\s+(?:আনো|দাও|আনুন)|ফিরিয়ে\s+(?:আনো|দাও|আনুন)|restore)')) return 'restore';
  if (_thas(f, r'(?:রিমাইন্ডার|reminder|মনে\s+করানো)\S*\s+(?:\S+\s+)?(?:বন্ধ|অফ|off)')) return 'reminder_off';
  // "দ্বিতীয়টা বন্ধ কর" (a reminder list on screen): turned off, kept.
  if (_thas(f, r'(?<=\s)(?:বন্ধ|অফ|off)\s*(?:কর|করো|করে\s+দাও|করে\s+দিন|করুন|দাও|রাখো)?\s*$')) return 'reminder_off';
  if (_thas(f, r'(?<=\s)(?:মুইছা\s+(?:দাও|দেও|ফালাও)|মুইছে\s+(?:দাও|দেও)|মুছা\s+দাও|মুছে\s+(?:দাও|দিও|ফেলো|দেন|দিন|ফেলুন)|মুছো|মুছুন|মুছে\s+দাও|ডিলিট\s+(?:করো|করে\s+দাও|করুন)?|delete|কেটে\s+দাও|বাদ\s+(?:দাও|দিয়ে\s+দাও|দিও|দেন|দিন)|সরিয়ে\s+ফেলো|ক্লিয়ার\s+করো)(?=\s|$)')) return 'delete';
  if (_thas(f, r'(?<=\s)বাদ(?=\s*$)')) return 'delete';
  // "রিমাইন্ডারগুলো দাও", "সব রিমাইন্ডার কি কি": the list's own name, not
  // "set a reminder for these".
  final named = f.replaceAll(_tre(r'(?:রিমাইন্ডার|reminder)(?:গুলো|গুলা|গুলি|সমূহ)|(?<=\s)সব\s+(?:রিমাইন্ডার|reminder)(?:ের|এর)?|(?:রিমাইন্ডার|reminder)(?:ের|এর)\s+(?:তালিকা|লিস্ট)'), ' তালিকা ');
  if (_thas(named, r'(?:রিমাইন্ডার|reminder|মনে\s+করিও|মনে\s+করিয়ে\s+দিও|মনে\s+করাবে)')) return 'remind';
  // "এগুলো কাজের তালিকায় যুক্ত করো": adding what was just said — not this.
  if (_thas(f, r'(?:যুক্ত\s+কর|যোগ\s+কর|অ্যাড\s+কর|(?<=\s)add(?=\s)|তালিকায়\s+(?:রাখো|লিখে|তোলো|তুলে)|লিস্টে\s+(?:রাখো|লিখে|তোলো)|লিখে\s+রাখো)')) return '';
  if (_thas(f, r'(?:উল্টো\s+(?:ক্রমে|করে)|উল্টা\s+করে)')) return 'reverse';
  if (_thas(f, r'(?:পিডিএফ|pdf|রিপোর্ট)\s*(?:করো|দাও|বানাও|চাই)?')) return 'report';
  if (_thas(f, r'(?<=\s)জরুরি\s+(?:করো|করে\s+দাও|রাখো)')) return 'urgent';
  if (_thas(f, r'(?:আবার\s+)?বাকি\s+(?:রাখো|করো|করে\s+দাও)|অসমাপ্ত\s+(?:করো|রাখো)')) return 'reopen';
  if (_thas(f, r'(?<=\s)(?:হয়নি|হয়নি|করিনি|হয়\s+নাই|হাঁটিনি|পড়িনি)(?=\s)')) return 'not_done';
  if (_thas(f, r'(?<=\s)(?:শেষ(?:\s+করো|\s+করেছি|\s+হয়েছে)?|করেছি|হয়ে\s+গেছে|হয়েছে|হয়েছে|সেরেছি|টিক\s+দাও|সম্পন্ন|done)(?=\s)')) return 'done';
  // "প্রথম দুটো কাল রাখো", "শেষের তিনটি কাল করব", "সব কাল করব": another day.
  if (_thas(f, r'(?<=\s)(?:রাখো|রাখ|দাও|সরাও|সরিয়ে\s+দাও|পিছিয়ে\s+দাও|নাও|করো|করব|করবো|করবো|হবে|যাবে|থাকবে)(?=\s*$|\s*,)') && (_thas(f, r'(?:আজ|কাল|পরশু|তারিখ|বার(?:ে)?|সপ্তাহ)') || _monthSaid(f) != null)) return 'move';
  if (_thas(f, r'(?:দেখাও|দেখান|বলো|বলুন|দাও)\s*$')) return 'show';
  // "রিমাইন্ডারগুলো কি কি", "নোটগুলো কোনগুলো": asking to see them.
  if (_thas(f, r'(?:কি\s+কি|কী\s+কী|কোনগুলো|কোন\s+কোন)\s*$')) return 'show';
  return '';
}

/// "এইগুলো সব মুছে দাও", "প্রথম দুটো কাল রাখো", "দ্বিতীয়টা থাকবে,
/// বাকিগুলো মুছো": a request about several items of a list. Null when the
/// sentence names no group, has no supported verb, is negative ("মুছো না")
/// or is not a request ("ও এসব মুছে দেয়").
List<BulkAction>? bulkCommands(String said, DateTime now) {
  var f = ' ${_tf(englishTimes(banglishList(said))).replaceAll(RegExp(r'[।!?;:"“”]'), ' ').replaceAll(RegExp(r'(?<![0-9০-৯])\s*[—–]\s*(?![0-9০-৯])'), ', ').toLowerCase()} ';
  if (aspectOf(said) == Aspect.negated && !_thas(f, r'(?:হয়নি|হয়নি|করিনি|হাঁটিনি|পড়িনি)')) return null;
  if (negatedRequest(normalize(said))) return null;
  // "প্রথম দুটো — না, শেষের দুটো", "সব কাল রাখো — না, পরশু": the later words win.
  final full = f;
  final fix = _tre(r'(?:,\s*(?:না|নাহ|উহু|নয়)\s*,?\s+|(?<=\s)(?:না|নয়)\s*,\s+)').allMatches(f).lastOrNull;
  String? dayFix;
  if (fix != null) {
    final after = ' ${f.substring(fix.end)} ';
    if (selectionIn(after) != null) {
      final op = _bulkOp(after);
      f = op.isEmpty ? '$after ${f.substring(0, fix.start).replaceAll(_tre(r'^.*?(?=\s(?:মুছ|কাল|পরশু|শেষ|রাখো|দাও|বাদ))'), ' ')} ' : after;
    } else if (parseWhen(after, now)?.hasDay ?? false) {
      dayFix = after;
      f = ' ${f.substring(0, fix.start)} ';
    }
  }
  // "প্রথমটা শেষ, দ্বিতীয়টা কাল, তৃতীয়টা মুছো", "৪–৮ মুছো, ৯ নম্বরে সন্ধ্যা
  // ৭টার রিমাইন্ডার দাও": each part its own places and its own action —
  // all resolved later against the same list, so a removal never shifts
  // the numbers of another part.
  final planned = _clausePlan(f, said, now);
  if (planned != null) return planned;
  // "প্রথমটা হয়েছে, বাকিগুলো হয়নি": two requests, the second about the rest.
  final clauses = f.split(_tre(r'\s*,\s*')).where((x) => x.trim().isNotEmpty).toList();
  if (clauses.length == 2 && _thas(clauses[1], r'(?:বাকিগুলো|বাকিগুলা|বাকি\s+সব)')) {
    final firstOrd = _ordOf(clauses[0].trim().split(RegExp(r'\s+')).first);
    final op1 = _bulkOp(' ${clauses[0]} ');
    final op2 = _bulkOp(' ${clauses[1]} ');
    if (firstOrd != null && op1.isNotEmpty && op2.isNotEmpty && op1 != op2 && !_thas(clauses[0], r'(?:থাকবে|থাকুক|ছাড়া)')) {
      final dom = _bulkDomain(f);
      return [
        BulkAction(said, selection: Selection(SelKind.indexes, indexes: [firstOrd]), op: op1, domain: dom, day: dayOnly(now)),
        BulkAction(said, selection: Selection(SelKind.all, exceptIdx: [firstOrd]), op: op2, domain: dom, day: dayOnly(now)),
      ];
    }
  }
  final fo = f.replaceAll(',', ' ');
  // "এগুলো আজ না, কাল রাখো": the verb is after the corrected day.
  var op = _bulkOp(fo);
  if (op.isEmpty && dayFix != null) op = _bulkOp(' $dayFix ');
  if (op.isEmpty && dayFix != null) op = _bulkOp(full.replaceAll(',', ' '));
  // "উল্টো ক্রমে দেখাও": the whole list, in the other order.
  var sel = selectionIn(f) ?? (op == 'reverse' ? const Selection(SelKind.all) : null);
  if (sel == null) return null;
  // "রবিনের বোনের বিয়ের দাওয়াত থাকবে শুধু": only that stays — the rest go.
  if (op.isEmpty && sel.hasExcept && _thas(f, r'(?<=\s)(?:শুধু|কেবল|খালি)(?=\s)') && _thas(f, r'(?<=\s)(?:থাকবে|থাকুক|থাক)(?=\s)')) {
    op = 'delete';
    sel = Selection(SelKind.all, exceptIdx: sel.exceptIdx, exceptNames: sel.exceptNames);
  }
  if (op.isEmpty) return null;
  final domain = _bulkDomain(fo);
  DateTime? due;
  int? time;
  var open = false;
  var span = TaskSpan.day;
  var yearSaid = true;
  if (op == 'move') {
    final w = parseWhen(dayFix ?? f, now);
    final month = _monthSaid(f);
    if ((w == null || !w.hasDay) && month != null) {
      // "এগুলো জুন মাসে করব": the month, any day in it.
      final y = RegExp(r'([0-9০-৯]{4})').firstMatch(f);
      yearSaid = y != null;
      final year = y != null ? int.parse(asciiDigits(y[1]!)) : (month < now.month ? now.year + 1 : now.year);
      due = DateTime(year, month);
      span = TaskSpan.month;
    } else {
      if (w == null || !w.hasDay) return null;
      due = dayOnly(w.day);
    }
  }
  if (op == 'remind') {
    final w = parseWhen(f, now);
    if (w != null && w.hasTime) {
      time = w.at.hour * 60 + w.at.minute;
      open = hourOpen(said, w.at.hour);
      if (w.hasDay) due = dayOnly(w.day);
    }
  }
  final day = _thas(f, r'(?:গতকাল|গত\s+কাল)') ? dayOnly(now.subtract(const Duration(days: 1))) : dayOnly(now);
  final main = BulkAction(said, selection: sel, op: op, domain: domain, due: due, time: time, ampmOpen: open, day: day, span: span, yearSaid: yearSaid);
  // "সব কাল করব, তবে ব্যাংকেরটা আজই থাকবে": the one left out has its own day.
  if (op == 'move' && sel.exceptNames.isNotEmpty) {
    final ex = _tre(r'(?<=\s)\S+?(?:টা|টি)\s+(আজই|আজকেই|আজকে|আজ|কালকেই|কালই|কাল|পরশু)(?=\s)\s*(?:\S+\s+)?(?:থাকবে|থাকুক|রাখো|হবে|করব|করবো)').firstMatch(f);
    if (ex != null) {
      final w = _tf(ex[1]!);
      final add = w.startsWith(_tf('পরশু')) ? 2 : (w.startsWith(_tf('কাল')) ? 1 : 0);
      final own = dayOnly(now).add(Duration(days: add));
      if (own != due) return [main, BulkAction(said, selection: Selection(SelKind.names, names: sel.exceptNames), op: 'move', domain: domain, due: own, day: day)];
    }
  }
  return [main];
}

/// One place said on its own ("প্রথমটা", "৯ নম্বরে", "৩নং"), or null.
int? _onePlace(String c) {
  final m = _tre(r'^\s*(\S+?)\s*(?:নম্বর|নাম্বার|নং)(?:ের|এর|এ|ে|টা|টি|টার|টায়|টাকে)?(?=\s|$)').firstMatch(c);
  if (m != null) return _countOf(m[1]!) ?? _ordOf(m[1]!);
  final first = c.trim().split(RegExp(r'\s+')).first;
  final o = _ordOf(first);
  if (o != null && first != _tf('শেষ')) return o;
  return null;
}

/// Several comma-separated parts, each with its own places and action
/// (see [bulkCommands]); null unless every part has both.
List<BulkAction>? _clausePlan(String f, String said, DateTime now) {
  final clauses = [for (final x in f.split(_tre(r'\s*,\s*|\s+(?:এবং|আর|তারপর)\s+(?=[০-৯0-9]{1,2}\s*(?:নং|নম্বর|নাম্বার)|\S+(?:টা|টি)(?:\s|$)|(?:প্রথম|দ্বিতীয়|তৃতীয়|চতুর্থ|পঞ্চম|শেষের)\S*\s)'))) if (x.trim().isNotEmpty) ' ${x.trim()} '];
  if (clauses.length < 2) return null;
  final out = <BulkAction>[];
  final dom = _bulkDomain(f);
  for (final c in clauses) {
    final sel = selectionIn(c) ?? (_onePlace(c) == null ? null : Selection(SelKind.indexes, indexes: [_onePlace(c)!]));
    if (sel == null || sel.kind == SelKind.all || sel.hasExcept) return null;
    var op = _bulkOp(c);
    final w = parseWhen(c, now);
    // "দ্বিতীয়টা কাল": only a day — moved there.
    if (op.isEmpty && w != null && w.hasDay && !w.hasTime) op = 'move';
    if (op.isEmpty || op == 'show') return null;
    DateTime? due;
    int? time;
    var open = false;
    if (op == 'move') {
      if (w == null || !w.hasDay) return null;
      due = dayOnly(w.day);
    }
    if (op == 'remind' && w != null && w.hasTime) {
      time = w.at.hour * 60 + w.at.minute;
      open = hourOpen(said, w.at.hour) && !_thas(c, r'(?:সকাল|দুপুর|বিকাল|বিকেল|সন্ধ্যা|রাত|ভোর)');
      if (w.hasDay) due = dayOnly(w.day);
    }
    out.add(BulkAction(said, selection: sel, op: op, domain: dom, due: due, time: time, ampmOpen: open, day: dayOnly(now)));
  }
  return out;
}

/// A little Banglish about a list ("4 theke 8 number muche dao", "3 ar 4
/// bade sob mucho") in Bangla words, so the same rules read it.
String banglishList(String said) {
  if (!RegExp(r'[a-zA-Z]').hasMatch(said)) return said;
  const words = {
    'theke': 'থেকে', 'number': 'নম্বর', 'no': 'নং', 'nong': 'নং', 'ar': 'আর', 'ebong': 'এবং', 'sob': 'সব', 'shob': 'সব', 'bade': 'বাদে', 'bad': 'বাদ',
    'dao': 'দাও', 'muche': 'মুছে', 'mucho': 'মুছো', 'muchhe': 'মুছে', 'delete': 'মুছে দাও', 'rekhe': 'রেখে', 'baki': 'বাকি', 'bakigulo': 'বাকিগুলো',
    'prothom': 'প্রথম', 'ditiyo': 'দ্বিতীয়', 'sesh': 'শেষ', 'sesher': 'শেষের', 'kaj': 'কাজ', 'ta': 'টা', 'egulo': 'এগুলো', 'kal': 'কাল', 'aj': 'আজ',
  };
  return said.split(RegExp(r'\s+')).map((w) => words[w.toLowerCase()] ?? w).join(' ').replaceAll('মুছে দাও দাও', 'মুছে দাও');
}

/// "দ্বিতীয়টা ভুল", "প্রথমটা হয়েছে", "শেষেরটা মুছো": one place in the list
/// just shown — used for lists other than to-dos (those have their own
/// one-item rules). Null when there is no single place and verb.
BulkAction? singleIndexCommand(String said, DateTime now) {
  final f = ' ${_tf(said).replaceAll(RegExp(r'[।!?,;:"“”]'), ' ').toLowerCase()} ';
  if (aspectOf(said) == Aspect.negated && !_thas(f, r'(?:হয়নি|হয়নি|করিনি|হাঁটিনি|পড়িনি)')) return null;
  final i = _tdOrdinal(f);
  if (i == null) return null;
  var op = _bulkOp(f);
  if (op.isEmpty && _thas(f, r'(?<=\s)(?:ভুল|ঠিক\s+না|ঠিক\s+নয়)(?=\s)')) op = 'wrong';
  if (op.isEmpty) return null;
  final day = _thas(f, r'(?:গতকাল|গত\s+কাল)') ? dayOnly(now.subtract(const Duration(days: 1))) : dayOnly(now);
  return BulkAction(said, selection: Selection(SelKind.indexes, indexes: [i]), op: op, domain: _bulkDomain(f), day: day);
}


/// "২০২৭ সালের", "নভেম্বরের", "ফেব্রুয়ারি ২০২৯ এর", "এ মাসের": a stretch
/// of time named with no day in it (a day is [datedBulk]'s). Null when none.
({DateTime from, DateTime to, String label})? periodSaid(String said, DateTime now) {
  final f = ' ${fold(normalize(said)).replaceAll(RegExp(r'[।,!?]'), ' ')} ';
  final year = RegExp(r'(?<=\s)(20\d\d)(?!\d)').firstMatch(f);
  final y = year == null ? null : int.parse(year[1]!);
  final month = _monthSaid(f.replaceAll(RegExp(r'(?<=\s)(20\d\d)(?!\d)'), ' '));
  // "১৫ জুন", "১১ জুন ২০২৭": a day, not a stretch.
  for (final m in bnMonths) {
    if (RegExp('(?:^|\\s)\\d{1,2}\\s*(?:${fold('তারিখ')}\\S*)?\\s+${fold(m)}').hasMatch(f)) return null;
  }
  if (RegExp(fold(r'(?<=\s)(?:এ|এই)\s+মাস')).hasMatch(f)) {
    return (from: DateTime(now.year, now.month, 1), to: DateTime(now.year, now.month + 1, 0), label: 'এ মাসের');
  }
  if (month != null) {
    final yy = y ?? (month < now.month ? now.year + 1 : now.year);
    return (from: DateTime(yy, month, 1), to: DateTime(yy, month + 1, 0), label: y == null ? '${bnMonths[month - 1]}ের' : '${bnMonths[month - 1]} ${bnDigits(yy)}-এর');
  }
  if (y != null) return (from: DateTime(y, 1, 1), to: DateTime(y, 12, 31), label: '${bnDigits(y)} সালের');
  return null;
}

/// What is to be done to several items ("মুছে দাও" → 'delete'), or ''.
String bulkOpOf(String said) => _bulkOp(' ${_tf(normalize(said))} ');
