// The to-do list, understood by what the person wants — not by fixed
// sentences. Every way of saying the same thing ends in the same command:
//
//   add       "বাজার করতে হবে", "কাল ব্যাংকে যাব", "বিলের কাজটা লিখে রাখো"
//   look      "কাল কী কী কাজ আছে?", "কী কী করা বাকি?", "শুক্রবার ফ্রি আছি?"
//   done      "বাজার করেছি", "ওটা হয়ে গেছে", "দ্বিতীয়টা শেষ"
//   not done  "ওষুধ আনিনি", "বিলডা দেওয়া অয় নাই"
//   change    "কাজটা কাল রাখো", "একদিন পিছিয়ে দাও", "এটা জরুরি"
//   remind    "ওটার রিমাইন্ডার সকাল দশটায় দিও", "আর মনে করিও না"
//   repeat    "প্রতি শুক্রবার বাজার করব", "দুই দিন পরপর গাছে পানি দেব"
//
// A sentence is read by its shape: what it points at (a to-do by its words,
// "ওটা", "দ্বিতীয়টা"), its time words (a day, a week, a month, a year, a
// repeat) and the form of its verb (করতে হবে / করব = to do, করেছি = done,
// করিনি = not done, a question = look). The chat resolves "ওটা" and
// "দ্বিতীয়টা" from what was said and shown just before.
part of 'parser.dart';

// ───────────────────────── Commands ─────────────────────────

/// Which to-do is meant: by its words, its place in the list just shown
/// ("দ্বিতীয়টা" = 2, "শেষেরটা" = -1), "ওটা"/"কাজটা" (the one just talked
/// about), or known ids (an answer to "কোনটা?").
class TaskRef {
  const TaskRef({this.terms = const [], this.index, this.it = false, this.ids = const [], this.said = ''});
  final List<String> terms;
  final int? index;
  final bool it;
  final List<String> ids;

  /// The words used for it, to say back when it is not found.
  final String said;

  bool get isEmpty => terms.isEmpty && index == null && !it && ids.isEmpty;
}

/// Which to-dos a question is about.
class TaskScope {
  const TaskScope({
    this.from,
    this.to,
    this.undated = false,
    this.overdue = false,
    this.withOverdue = false,
    this.future = false,
    this.doneOnly = false,
    this.about = const [],
    this.urgentFirst = false,
    this.count = false,
    this.free = false,
    this.suggest = false,
    this.soonest = false,
    this.label = '',
  });

  /// Days (inclusive) the to-do's date must touch.
  final DateTime? from, to;
  final bool undated, overdue, future;

  /// "মাসের শেষের আগে কী কী শেষ করতে হবে?": late ones count too.
  final bool withOverdue;

  /// "আজ কতগুলো কাজ শেষ করেছি?": ticked ones, by the day they were ticked.
  final bool doneOnly;

  /// "বিল সংক্রান্ত কাজগুলো", "অফিসের কাজগুলো".
  final List<String> about;
  final bool urgentFirst;

  /// "কয়টা", "কতগুলো", "মোট": a number first.
  final bool count;

  /// "শুক্রবার আমি ফ্রি আছি?": said from the list only.
  final bool free;

  /// "এখন কোনটা আগে করা ভালো?": a suggestion, said as one.
  final bool suggest;

  /// "কোনটার সময় আগে?": the nearest one.
  final bool soonest;

  /// How the span is said back ("আগামী সপ্তাহে", "শুক্রবার").
  final String label;
}

/// A change to a to-do already on the list.
class TaskEdit extends Command {
  const TaskEdit(
    super.transcript, {
    this.ref = const TaskRef(),
    this.title,
    this.due,
    this.span,
    this.clearDue = false,
    this.shiftDays = 0,
    this.urgent,
    this.note,
    this.remindAt,
    this.remindHour,
    this.remindMinute = 0,
    this.remindNeedsTime = false,
    this.remindAmPm = false,
    this.stopReminder = false,
    this.skipOnce = false,
    this.delete = false,
    this.keep = false,
    this.say,
    this.weekday,
    this.newTitle,
    this.dayOfMonth,
  });

  /// "৩১ তারিখে রাখো" about a to-do of a whole month: that day of its month.
  final int? dayOfMonth;

  final TaskRef ref;

  /// "ডাক্তারকে ফোন করার কাজটা কাল রাখো" when no such to-do is on the
  /// list: it is kept as a new one with these words.
  final String? newTitle;

  /// "বাজার করার বদলে মাসের বাজার করা লিখো".
  final String? title;

  /// "কাজটা কাল রাখো" / "শুক্রবারে সরাও".
  final DateTime? due;
  final TaskSpan? span;

  /// "বুধবার রাখো" said about a to-do of a week: that weekday inside its
  /// week (DateTime.monday … sunday), not this week's.
  final int? weekday;

  /// "তারিখ বাদ দাও, কাজটা থাক".
  final bool clearDue;

  /// "একদিন পিছিয়ে দাও" = 1, "দুই দিন এগিয়ে আনো" = -2.
  final int shiftDays;

  /// "এটা জরুরি" = true, "এত জরুরি না" = false.
  final bool? urgent;

  /// "এর সঙ্গে লিখো, কাগজপত্র নিতে হবে".
  final String? note;

  /// A reminder for it at this moment ("এক ঘণ্টা পরে মনে করিও").
  final DateTime? remindAt;

  /// Only an hour was said ("সকাল দশটায়"): on the to-do's own day.
  final int? remindHour;
  final int remindMinute;

  /// "বাজারের কাজটায় রিমাইন্ডার দাও": when is still to be asked.
  final bool remindNeedsTime;

  /// "আটটায়": morning or night is still to be asked.
  final bool remindAmPm;

  /// "আর মনে করিও না", "Reminder off করো, task থাকবে": the to-do stays.
  final bool stopReminder;

  /// "এই শুক্রবারটা বাদ দাও": one time of a repeating to-do.
  final bool skipOnce;

  /// "বাজারের কাজটা তালিকা থেকে বাদ দাও": asked once, then removed.
  final bool delete;

  /// "…মুছে দেব ভাবছিলাম, কিন্তু এখন রাখো": nothing changes.
  final bool keep;

  /// Only something to say ("কয়েক দিন বন্ধ রাখো" → "কত দিন?").
  final String? say;
}

/// "ভুল করে মুছে ফেলেছি, ফেরত আনো": the last removed to-do back.
class TaskRestore extends Command {
  const TaskRestore(super.transcript);
}

// ───────────────────────── Words ─────────────────────────

String _tf(String s) => fold(s);
RegExp _tre(String p) => RegExp(fold(p), caseSensitive: false);
bool _thas(String s, String p) => _tre(p).hasMatch(s);

/// A word for a to-do or the list.
const _taskNounP = r'(?:কাজ(?:টা|টি|টায়|টার|টাকে|টাও|গুলো|গুলি|গুলা|গুলোর|সমূহ|ের|ে)?|টাস্ক|task(?:s)?|টু-?ডু(?:তে|র)?|to-?do)';
const _listP = r'(?:(?:কাজের\s+)?(?:তালিকা|লিস্ট)(?:য়|তে|টা|টাতে|র|ে)?|টু-?ডু(?:তে|র|\s+লিস্ট(?:ে)?)?|to-?do(?:\s+list)?)';
const _wdP = r'(সোম|মঙ্গল|বুধ|বৃহস্পতি|বিষ্যুদ|শুক্র|শনি|রবি)(?:বার)?(?:ের|এর|ে|এ|টা|টায়)?';
const _monthsP = r'(জানুয়ারি|ফেব্রুয়ারি|মার্চ|এপ্রিল|মে|জুন|জুলাই|আগস্ট|সেপ্টেম্বর|অক্টোবর|নভেম্বর|ডিসেম্বর)';

int _wdIndex(String stem) => switch (stem) {
      'সোম' => DateTime.monday,
      'মঙ্গল' => DateTime.tuesday,
      'বুধ' => DateTime.wednesday,
      'বৃহস্পতি' || 'বিষ্যুদ' => DateTime.thursday,
      'শুক্র' => DateTime.friday,
      'শনি' => DateTime.saturday,
      _ => DateTime.sunday,
    };

/// "দুই", "২", "তিন" → 2, 2, 3.
int? _tdNum(String w) {
  final a = int.tryParse(asciiDigits(w));
  if (a != null) return a;
  const words = {'এক': 1, 'দুই': 2, 'দু': 2, 'তিন': 3, 'চার': 4, 'পাঁচ': 5, 'ছয়': 6, 'সাত': 7, 'আট': 8, 'নয়': 9, 'দশ': 10, 'পনেরো': 15, 'পনের': 15, 'বিশ': 20, 'ত্রিশ': 30};
  for (final e in words.entries) {
    if (_tf(e.key) == _tf(w)) return e.value;
  }
  return null;
}

/// The first day of the week (Saturday, as weeks are counted here).
DateTime _weekStart(DateTime d) => dayOnly(d).subtract(Duration(days: (d.weekday + 1) % 7));

// ───────────────────────── Verbs ─────────────────────────

/// Verb roots and the "doing it" form a to-do is written in.
final Map<String, String> _verbNoun = {
  for (final e in {
    'কর': 'করা', 'আন': 'আনা', 'এন': 'আনা', 'দে': 'দেওয়া', 'দি': 'দেওয়া', 'দিই': 'দেওয়া', 'যা': 'যাওয়া', 'যে': 'যাওয়া', 'যাই': 'যাওয়া', 'গি': 'যাওয়া', 'গে': 'যাওয়া',
    'নে': 'নেওয়া', 'নি': 'নেওয়া', 'নিই': 'নেওয়া', 'খা': 'খাওয়া', 'খে': 'খাওয়া', 'পা': 'পাওয়া', 'পে': 'পাওয়া', 'চা': 'চাওয়া', 'চাই': 'চাওয়া', 'ধু': 'ধোয়া', 'ধো': 'ধোয়া',
    'কিন': 'কেনা', 'কেন': 'কেনা', 'লিখ': 'লেখা', 'লেখ': 'লেখা', 'দেখ': 'দেখা', 'শিখ': 'শেখা', 'শেখ': 'শেখা', 'খুল': 'খোলা', 'খোল': 'খোলা',
    'তুল': 'তোলা', 'তোল': 'তোলা', 'উঠ': 'ওঠা', 'ওঠ': 'ওঠা', 'ঘুর': 'ঘোরা', 'ঘোর': 'ঘোরা', 'ফির': 'ফেরা', 'ফের': 'ফেরা', 'খুঁজ': 'খোঁজা', 'খোঁজ': 'খোঁজা',
    'মুছ': 'মোছা', 'মোছ': 'মোছা', 'শুন': 'শোনা', 'শোন': 'শোনা', 'বুঝ': 'বোঝা', 'বোঝ': 'বোঝা', 'ধর': 'ধরা', 'পড়': 'পড়া', 'বল': 'বলা', 'রাখ': 'রাখা',
    'হাঁট': 'হাঁটা', 'বস': 'বসা', 'আস': 'আসা', 'ফেল': 'ফেলা', 'কাট': 'কাটা', 'ছাড়': 'ছাড়া', 'ভর': 'ভরা', 'পর': 'পরা', 'নাম': 'নামা', 'ঝাড়': 'ঝাড়া',
    'সার': 'সারা', 'মার': 'মারা', 'ভাঙ': 'ভাঙা', 'জমা দে': 'জমা দেওয়া',
    // "-ানো" verbs: পাঠানো, গোছানো, জানানো …
    'পাঠা': 'পাঠানো', 'গুছা': 'গোছানো', 'গোছা': 'গোছানো', 'জানা': 'জানানো', 'চালা': 'চালানো', 'বানা': 'বানানো', 'সারা': 'সারানো', 'মিলা': 'মেলানো',
    'মেলা': 'মেলানো', 'ঘুমা': 'ঘুমানো', 'বদলা': 'বদলানো', 'সাজা': 'সাজানো', 'লাগা': 'লাগানো', 'দাঁড়া': 'দাঁড়ানো', 'পৌঁছা': 'পৌঁছানো', 'ছাপা': 'ছাপানো',
    'শুকা': 'শুকানো', 'ঝোলা': 'ঝোলানো', 'ভেজা': 'ভেজানো', 'খাওয়া': 'খাওয়ানো', 'বাড়া': 'বাড়ানো', 'কমা': 'কমানো', 'পাল্টা': 'পাল্টানো',
  }.entries)
    _tf(e.key): _tf(e.value),
};

/// The "doing it" form of one verb word, or null when it is not a verb
/// form this knows: "করতে" / "করব" / "করমু" → "করা", "দিতে" / "দেব" →
/// "দেওয়া", "গুছাব" → "গোছানো", "যাইতে" → "যাওয়া".
String? _nounOfVerb(String w) {
  final x = _tf(w);
  for (final (suf, minRoot) in [('তে', 1), ('বো', 1), ('ব', 1), ('মু', 1), ('বেন', 1)]) {
    final s = _tf(suf);
    if (!x.endsWith(s) || x.length - s.length < minRoot) continue;
    final root = x.substring(0, x.length - s.length);
    final n = _verbNoun[root];
    if (n != null) return n;
    // Any other "-ানো" verb ("ঝুলাতে", "ঝুলাব"): only the standard endings,
    // so "আসসালামু" is not a verb.
    if (suf != 'মু' && suf != 'বেন' && root.length >= 3 && root.endsWith('া')) return '${root}নো';
  }
  return null;
}

/// A to-do's words from what was said: the verb in its "doing it" form,
/// the order and the time words gone. "বিদ্যুৎ বিল দেওয়ার কাজটা লিখে রাখো"
/// → "বিদ্যুৎ বিল দেওয়া"; "কাল ব্যাংকে যাইতে অইব" → "ব্যাংকে যাওয়া";
/// "আলমারি গুছাব" → "আলমারি গোছানো".
String todoTitle(String rest) {
  var s = ' ${_tf(rest)} '.replaceAll(_tre(_opener), ' ');
  // "…কাজের তালিকাতে লেখ যে X", "… যুক্ত করো যে X": the to-do is X.
  final after = _tre(r'(?<=\s)(?:লেখ|লেখো|লিখো|লিখে\s+রাখো|লিখে\s+রাখ|যুক্ত\s+করো|যোগ\s+করো|রাখো|রাখ|মনে\s+রাখো)\s+যে\s+(.+)$').firstMatch(s);
  if (after != null) s = ' ${after[1]} ';
  // "…কাজের তালিকাতে পুকুরে চুন দিতে হবে এটা লিখে রাখ": what comes after the list.
  final list = _tre(r'(?<=\s)(?:কাজের\s+)?(?:তালিকা|লিস্ট)(?:য়|তে|টা|টাতে|র|ে)?\s+(?:তে\s+)?(.+)$').firstMatch(s);
  if (list != null) {
    final tail = list[1]!.replaceAll(_tre(r'(?:^|\s)(?:এটা|এইটা|এরাম|এরকম|একটা|একটু|তো)(?=\s|$)'), ' ').replaceAll(_tre(r'(?:^|\s)(?:লেখ|লেখো|লিখো|লিখে\s+রাখো|লিখে\s+রাখ|লিখে\s+দাও|রাখো|রাখ|রেখো|তুলে\s+রাখ\S*|যুক্ত\s+করো|যোগ\s+করো|যুক্ত\s+কর|যোগ\s+কর|add)(?=\s|$)'), ' ').trim();
    if (tail.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).length >= 2) s = ' ${list[1]} ';
  }
  s = s.replaceAll(RegExp(r'[।!?;:"“”]'), ' ');
  s = s.replaceAll(RegExp(r'\s*[—–]\s*'), ' ');
  s = s.replaceAll(RegExp(r'\s*,\s*'), ' , ');
  // The order to keep it ("… লিখে রাখো", "একটা কাজ যোগ করো", "মনে রেখো").
  for (final p in [
    r'(?:আমার\s+|এটা\s+|এইটা\s+|একটা\s+|একটি\s+)?' + _listP + r'\s+(?:একটু\s+)?(?:লিখে\s+)?(?:রাখো|রাখ|রাখেন|রাখুন|রেখো|রেখে দাও|যোগ\s+কর\S*|যুক্ত\s+কর\S*|তুলে\s+রাখ\S*|তুলে\s+দাও|লিখো|লেখো|লিখে দাও|ঢুকাও|add\s+কর\S*)',
    r'(?:একটা|একটি)?\s*(?:নতুন\s+)?কাজ\s+(?:যোগ|যুক্ত|এড|অ্যাড)\s+(?:করো|কর|করে\s+দাও|করেন|করুন)',
    r'add\s+(?:a\s+)?task',
    r'(?:এটা|এইটা)?\s*(?:একটু\s+)?(?:লিখে\s+(?:রাখো|রাখ|রেখো|রাখেন|দাও|দিও)|লিখে\s+নাও|লিখো|লেখো|নোট\s+করো)(?:\s+তো)?',
    r'(?:এটা\s+)?(?:একটু\s+)?(?:মনে\s+(?:রেখো|রাখো|রাখবা|রাখবে|রাখিও)|ভুলে\s+যেও\s+না)',
    r'(?:\S+টা|\S+টি|তিনটা|দুইটা|দুটো|চারটা)\s+কাজ\s+(?:রাখো|রাখ|রেখো|লিখে রাখো)',
    r'(?:কাজ\s+হিসেবে|কাজ\s+হিসাবে)\s+(?:রাখো|রাখ|রেখো)',
    r'(?:রাখো|রাখ|রেখো|রেখে দাও|তুলে রাখো)\s*$',
  ]) {
    s = s.replaceAll(_tre(p), ' ');
  }
  // "আমার টু-ডুতে", "লিস্টে": where it goes, not what it is.
  s = s.replaceAll(_tre(r'(?<=\s)(?:আমার\s+)?' + _listP + r'(?=\s)'), ' ');
  // "দেওয়ার কাজটা", "হাঁটার কাজ" → "দেওয়া", "হাঁটা"; "বাজারের কাজটা" → "বাজার".
  s = s.replaceAllMapped(_tre(r'(?<=\s)(\S+)\s+' + _taskNounP + r'(?=\s|$)'), (m) {
    final w = m[1]!;
    if (w.endsWith(_tf('ের')) && w.length > 3) return ' ${w.substring(0, w.length - 2)} ';
    if (w.endsWith(_tf('এর')) && w.length > 3) return ' ${w.substring(0, w.length - 2)} ';
    if (w.endsWith(_tf('র')) && _verbNoun.containsValue(w.substring(0, w.length - 1))) return ' ${w.substring(0, w.length - 1)} ';
    if (w.endsWith(_tf('ার')) && w.length > 3) return ' ${w.substring(0, w.length - 1)} ';
    return ' $w ';
  });
  s = s.replaceAll(_tre(r'(?:^|\s)' + _taskNounP + r'(?=\s|$)'), ' ');
  // "বাকি আছে", "করতে হবে", "লাগবে", "দরকার".
  s = s.replaceAll(_tre(r'\s(?:এখনো\s+)?বাকি(?:\s+(?:আছে|রয়েছে|রইছে))?(?=\s|$)'), ' ');
  final words0 = s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  // Fillers that are never part of the to-do.
  final drop = {for (final w in ['আমাকে', 'আমার', 'আমি', 'আমরা', 'প্লিজ', 'please', 'একটু', 'তো', 'যে', 'এটা', 'এইটা', 'এরকম', 'এরাম', 'একটা', 'একটি', 'আজ', 'আজকে', 'হ্যাঁ', 'জি', 'ভাই', 'আর', 'এবং', 'ও', 'লেখ', 'লেখো', 'লিখো', 'তারপরে', 'তারপর', 'এরপরে', 'এরপর', 'আচ্ছা', 'বললাম', 'এখন', 'তে', 'এগুলো', 'সেটা']) _tf(w)};
  var ws = [for (final w in words0) if (!drop.contains(w)) w];
  // The verb at the end: "… করতে হবে" / "… করব" / "… করা লাগবে".
  while (ws.isNotEmpty && const ['হবে', 'হইবে', 'লাগবে', 'দরকার', 'হয়', 'হইব', 'চাই', 'রয়েছে', 'আছে', ','].map(_tf).contains(ws.last)) {
    ws.removeLast();
  }
  if (ws.isNotEmpty) {
    final n = _nounOfVerb(ws.last);
    if (n != null) ws[ws.length - 1] = n;
  }
  while (ws.isNotEmpty && ws.first == ',') {
    ws.removeAt(0);
  }
  return tidy(ws.join(' ').replaceAll(' , ', ', ')).replaceAll(RegExp(r'[,।.]+$'), '').trim();
}

// ───────────────────────── Time words ─────────────────────────

/// The when of a to-do: a day, or a whole week, month or year; a repeat;
/// or explicitly no date ("একদিন সময় করে").
class _TdWhen {
  DateTime? day;
  TaskSpan span = TaskSpan.day;
  TaskRepeat? repeat;
  bool undated = false;

  /// "শুক্রবার" said on a Friday: today, or a week from now?
  bool sameWeekday = false;

  /// "শুক্রবারের মধ্যে": by then.
  bool deadline = false;

  /// What was said, without the time words.
  String rest = '';
  bool get any => day != null || repeat != null || undated;
}

/// Reads the time words of a to-do sentence. Weeks start on Saturday.
_TdWhen _tdWhen(String said, DateTime now) {
  final w = _TdWhen();
  final today = dayOnly(now);
  var s = ' ${_tf(said)} ';
  bool take(String p, void Function(Match m) f) {
    final m = _tre(p).firstMatch(s);
    if (m == null) return false;
    f(m);
    s = s.replaceRange(m.start, m.end, ' ');
    return true;
  }

  // No date, on purpose.
  take(r'(?<=\s)(?:(?:কোনো|কোন)\s+)?একদিন\s+(?:সময়\s+করে)?|(?<=\s)সময়\s+(?:করে|পেলে)|(?<=\s)সুযোগ\s+(?:হলে|পেলে)|(?<=\s)ফাঁকা\s+সময়ে', (_) => w.undated = true);

  // Repeats.
  take(r'(?<=\s)(?:প্রতি\s*দিন|প্রতিদিন|প্রত্যেক\s*দিন|রোজ|everyday|every\s+day|daily)(?:ই)?(?=\s)', (_) => w.repeat = const TaskRepeat.daily());
  take(r'(?<=\s)(\S+)\s+দিন\s+(?:পর\s*পর|পরপর|অন্তর)(?=\s)', (m) {
    final n = _tdNum(m[1]!) ?? 2;
    w.repeat = TaskRepeat.everyDays(n <= 1 ? 2 : n);
  });
  take(r'(?<=\s)(?:প্রতি|প্রত্যেক)\s+(\S+)\s+দিন(?:ে)?(?:\s+(?:পর|পরপর|পর\s+পর))?(?=\s)', (m) {
    final n = _tdNum(m[1]!);
    if (n != null) w.repeat = TaskRepeat.everyDays(n <= 1 ? 2 : n);
  });
  take(r'(?<=\s)(?:প্রতি|প্রত্যেক)\s*মাসে?র?\s+([০-৯0-9]{1,2})\s+তারিখ\S*|(?<=\s)মাসের\s+([০-৯0-9]{1,2})\s+তারিখ\S*\s+(?:প্রতি\s*মাসে|প্রতিমাসে)', (m) {
    final n = int.parse(asciiDigits(m[1] ?? m[2]!));
    if (n >= 1 && n <= 31) w.repeat = TaskRepeat.monthly(n);
  });
  // "প্রতি শুক্রবার", "প্রতি সপ্তাহে রবি আর বুধবার", "রবি, মঙ্গল আর বৃহস্পতিবার".
  final wdList = _tre(r'(?<=\s)(?:(?:প্রতি|প্রত্যেক)\s+(?:সপ্তাহে\s+)?)?' + _wdP + r'(?:\s*(?:,|আর|ও|এবং)\s*' + _wdP + r')*(?=\s)');
  for (final m in wdList.allMatches(s)) {
    final txt = m[0]!;
    final days = [for (final d in _tre(_wdP).allMatches(txt)) _wdIndex(d[1]!)];
    final every = _thas(txt, r'(?:প্রতি|প্রত্যেক)');
    if (every || days.toSet().length >= 2) {
      w.repeat = TaskRepeat.weekly(days.toSet().toList()..sort());
      s = s.replaceFirst(txt, ' ');
      break;
    }
  }
  if (w.repeat != null) {
    w.day = w.repeat!.nextOnOrAfter(today);
  }

  // A day in another month or later: "আগামী মাসের ৫ তারিখে".
  take(r'(?<=\s)(?:আগামী|পরের|সামনের)\s+মাসের\s+([০-৯0-9]{1,2})\s+তারিখ\S*', (m) {
    final n = int.parse(asciiDigits(m[1]!));
    w.day = DateTime(today.year, today.month + 1, n);
  });
  take(r'(?<=\s)(?:এই|এ)\s+মাসের\s+([০-৯0-9]{1,2})\s+তারিখ\S*', (m) {
    w.day = DateTime(today.year, today.month, int.parse(asciiDigits(m[1]!)));
  });
  // "তিন দিন পরে", "দুই সপ্তাহ পর", "এক মাস পরে".
  take(r'(?<=\s)(\S+)\s+(দিন|সপ্তাহ|মাস)\s+(?:পরে|পর|বাদে)(?=\s)', (m) {
    final n = _tdNum(m[1]!);
    if (n == null) return;
    w.day = switch (m[2]) {
      'দিন' => today.add(Duration(days: n)),
      'সপ্তাহ' => today.add(Duration(days: 7 * n)),
      _ => DateTime(today.year, today.month + n, today.day),
    };
  });
  // Weeks.
  if (w.day == null) {
    take(r'(?<=\s)(?:এই|এ)\s+সপ্তাহ(?:ে|ের|এর)?(?:\s+মধ্যে)?(?=\s)', (_) {
      w.day = _weekStart(today);
      w.span = TaskSpan.week;
    });
  }
  if (w.day == null) {
    take(r'(?<=\s)(?:আগামী|পরের|সামনের)\s+সপ্তাহ(?:ে|ের|এর)?(?:\s+(?:যেকোনো|যে\s+কোনো)\s+(?:একদিন|দিন))?(?=\s)|(?<=\s)next\s+week(?=\s)', (_) {
      w.day = _weekStart(today).add(const Duration(days: 7));
      w.span = TaskSpan.week;
    });
  }
  // Months.
  if (w.day == null) {
    take(r'(?<=\s)(?:আগামী|পরের|সামনের)\s+মাস(?:ে|ের|এর)?(?=\s)|(?<=\s)next\s+month(?=\s)', (_) {
      w.day = DateTime(today.year, today.month + 1, 1);
      w.span = TaskSpan.month;
    });
  }
  if (w.day == null) {
    take(r'(?<=\s)(?:এই|এ)\s+মাস(?:ে|ের|এর)?(?:\s+মধ্যে)?(?=\s)', (_) {
      w.day = DateTime(today.year, today.month, 1);
      w.span = TaskSpan.month;
    });
  }
  if (w.day == null) {
    // "ডিসেম্বরে" (no day number before it): that month.
    take(r'(?<=\s)(?<![০-৯0-9]\s)' + _monthsP + r'(?:\s+মাস(?:ে|ের)?)?(?:ের|এর|ে|তে)?(?:\s+মধ্যে)?(?=\s)', (m) {
      final mi = bnMonths.map(_tf).toList().indexOf(_tf(m[1]!)) + 1;
      if (mi <= 0) return;
      var y = today.year;
      if (mi < today.month) y++;
      w.day = DateTime(y, mi, 1);
      w.span = TaskSpan.month;
      if (mi == today.month) w.day = DateTime(y, mi, 1);
    });
  }
  // Years.
  if (w.day == null) {
    take(r'(?<=\s)(?:আগামী|পরের|সামনের)\s+বছর(?:ে|ের)?(?=\s)|(?<=\s)next\s+year(?=\s)', (_) {
      w.day = DateTime(today.year + 1, 1, 1);
      w.span = TaskSpan.year;
    });
  }
  if (w.day == null) {
    take(r'(?<=\s)(?:এই|এ)\s+বছর(?:ে|ের)?(?:\s+মধ্যে)?(?=\s)', (_) {
      w.day = DateTime(today.year, 1, 1);
      w.span = TaskSpan.year;
    });
  }
  // "আগামী শুক্রবার", "পরের রবিবার": the next one, never today.
  if (w.day == null) {
    take(r'(?<=\s)(?:আগামী|পরের|সামনের)\s+' + _wdP + r'(?=\s)', (m) {
      final wd = _wdIndex(m[1]!);
      var ahead = (wd - today.weekday) % 7;
      if (ahead == 0) ahead = 7;
      w.day = today.add(Duration(days: ahead));
    });
  }
  // "শুক্রবারের মধ্যে", "কালকের মধ্যে": by then.
  if (_thas(s, r'(?:ের|এর|র)\s+মধ্যে(?=\s)')) {
    w.deadline = true;
    s = s.replaceAllMapped(_tre(r'(\S+?)(?:ের|এর)\s+মধ্যে(?=\s)'), (m) => ' ${m[1]} ');
  }
  if (w.day == null && w.repeat == null) {
    final when = parseWhen(s, now);
    if (when != null && when.hasDay) {
      w.day = when.day;
      // A weekday said on that same weekday, without "আজ".
      final wm = _tre(r'(?<=\s)' + _wdP + r'(?=\s)').firstMatch(s);
      if (wm != null && _wdIndex(wm[1]!) == today.weekday && !_thas(s, r'(?<=\s)(?:আজ|আজকে|আজকেই)(?=\s)')) w.sameWeekday = true;
    }
  }
  w.rest = withoutWhen(withoutClockWords(s)).replaceAll(_tre(r'(?<=\s|^)(?:আগামী|পরের|সামনের|আগে)(?=\s|$)'), ' ').trim();
  return w;
}

// ───────────────────────── Pointing at a to-do ─────────────────────────

/// Words that never name a to-do: orders, time, question and list words.
final Set<String> _tdStop = {
  for (final w in [
    'রাখো', 'রাখ', 'রেখো', 'রাখেন', 'রাখুন', 'রেখে', 'সরাও', 'সরিয়ে', 'নাও', 'নিয়ে', 'দাও', 'দিও', 'দেও', 'দিন', 'করো', 'কর', 'করে', 'করেন', 'লিখো', 'লেখো', 'লিখে',
    'যোগ', 'যুক্ত', 'মুছে', 'মুছো', 'বাদ', 'ডিলিট', 'টিক', 'শেষ', 'হয়ে', 'গেছে', 'হয়েছে', 'হয়নি', 'হয়', 'হলো', 'সম্পন্ন', 'done', 'move', 'task', 'off', 'reminder', 'রিমাইন্ডার',
    'মনে', 'করিও', 'করাইও', 'করিয়ে', 'দিয়ো', 'জানাবে', 'জানিও', 'বদলে', 'পরিবর্তে', 'জায়গায়', 'জরুরি', 'গুরুত্বপূর্ণ', 'সাধারণ', 'এত', 'না', 'নয়', 'আর', 'এখনো', 'এখনও', 'এখন',
    'পিছিয়ে', 'এগিয়ে', 'আনো', 'তারিখ', 'তারিখটা', 'থাক', 'থাকুক', 'থাকবে', 'সঙ্গে', 'সাথে', 'তালিকা', 'তালিকায়', 'তালিকাতে', 'তালিকার', 'থেকে', 'লিস্ট', 'লিস্টে',
    'ওটা', 'ওটার', 'ওটাকে', 'ওইটা', 'এটা', 'এটার', 'এটাকে', 'এইটা', 'সেটা', 'সেটার', 'এই', 'ওই', 'সেই', 'কাজ', 'কাজটা', 'কাজটি', 'কাজটার', 'কাজটায়', 'কাজের', 'কাজগুলো',
    'প্রথম', 'দ্বিতীয়', 'তৃতীয়', 'চতুর্থ', 'পঞ্চম', 'শেষের', 'শেষেরটা', 'প্রথমটা', 'দ্বিতীয়টা', 'তৃতীয়টা', 'নম্বর', 'নাম্বার', 'নং', 'আজ', 'আজকে', 'কাল', 'কালকে', 'পরশু',
    'খুঁজে', 'খোঁজো', 'দেখাও', 'বলো', 'আছে', 'নেই', 'নাই', 'কি', 'কী', 'কোন', 'কোনো', 'আমার', 'আমি', 'আমাকে', 'তো', 'একটু', 'প্লিজ', 'ভুল', 'ভুলে', 'আবার', 'বাকি', 'পুরো', 'নিয়মিত', 'অর্ধেক', 'আংশিক', 'কিছুটা', 'বন্ধ', 'অফ', 'থাকবে', 'থাকুক', 'চালু', 'পরে', 'পর', 'আগে', 'মিনিট', 'ঘণ্টা', 'ঘন্টা',
  ])
    _tf(w),
  ..._stopWords,
};

/// The to-do words of [s]: "বাজার করার কাজটা কাল রাখো" → [বাজার, করা].
List<String> _tdTerms(String s) {
  final out = <String>[];
  var t = ' ${_tf(s)} '.replaceAll(_tre(r'(?<=\s)(?:\S+\s+)?(?:মিনিট|ঘণ্টা|ঘন্টা|দিন|সপ্তাহ|মাস)\S*\s+(?:পরে|পর|বাদে|আগে|পরপর)(?=\s)'), ' ');
  t = t.replaceAll(_tre(r'(?<=\s)(?:সাড়ে\s+|সোয়া\s+|পৌনে\s+)?(?:এক|দুই|দু|তিন|চার|পাঁচ|ছয়|সাত|আট|নয়|দশ|এগারো|এগার|বারো|[০-৯0-9]{1,2})(?:টা|টায়|টার|টাতে|টে)(?=\s)'), ' ');
  for (final raw in words(normalize(withoutWhen(t)))) {
    if (_tdStop.contains(raw) || RegExp(r'^\d+$').hasMatch(raw)) continue;
    // "করেছি", "আনিনি", "দিলাম", "দেব": the verb of the sentence, not a name.
    if (RegExp(_tf(r'(?:েছি|েছিলাম|িনি|ইনি|লাম|েছে)$')).hasMatch(raw)) continue;
    if (RegExp(_tf(r'(?:বো|ব|মু)$')).hasMatch(raw) && _nounOfVerb(raw) != null) continue;
    final asNoun = raw.endsWith(_tf('তে')) ? _nounOfVerb(raw) : null;
    var x = asNoun ?? stem(raw);
    // "করার", "দেওয়ার", "হাঁটার": the doing-word itself.
    if (x.endsWith(_tf('র')) && _verbNoun.containsValue(x.substring(0, x.length - 1))) x = x.substring(0, x.length - 1);
    if (x.length < 2 || _tdStop.contains(x)) continue;
    if (_tre(r'^' + _wdP + r'$').hasMatch(x)) continue;
    if (!out.contains(x)) out.add(x);
  }
  return out;
}

/// How well [terms] name [t] (0 = not at all).
int _tdScore(Task t, List<String> terms0) {
  String k(String x) => x.replaceAll('ৎ', 'ত');
  final terms = [for (final x in terms0) k(x)];
  final title = k(normalize('${t.title} ${t.note} ${t.list}'));
  final tw = {...words(title), ...words(title).map(stem)};
  var n = 0;
  for (final x in terms) {
    if (x.length < 2) continue;
    if (tw.contains(x) || title.contains(x) || tw.any((w) => w.length >= 3 && x.length >= 3 && (w.startsWith(x) || x.startsWith(w))) || tw.any((w) => w.length >= 3 && x.length >= 3 && w == x)) n++;
  }
  return n;
}

/// The to-dos [terms] point at, best first; only the best-scoring ones.
List<Task> tdMatch(Iterable<Task> tasks, List<String> terms, {bool open = true}) {
  final scored = <(Task, int)>[];
  for (final t in tasks) {
    if (open && t.done) continue;
    final s = _tdScore(t, terms);
    if (s > 0) scored.add((t, s));
  }
  if (scored.isEmpty) return const [];
  final best = scored.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
  return [for (final e in scored) if (e.$2 == best) e.$1];
}

/// "দ্বিতীয়টা" → 2, "শেষেরটা" → -1, "৩ নম্বর" → 3.
int? _tdOrdinal(String f) {
  final m = _tre(r'(?<=\s)(প্রথম|দ্বিতীয়|তৃতীয়|চতুর্থ|পঞ্চম|শেষের|উপরের)(?:টা|টি|টাকে|টার|টায়|\s+কাজ(?:টা|টি|টার)?)(?=\s)').firstMatch(f);
  if (m != null) {
    return switch (_tf(m[1]!)) {
      final x when x == _tf('প্রথম') || x == _tf('উপরের') => 1,
      final x when x == _tf('দ্বিতীয়') => 2,
      final x when x == _tf('তৃতীয়') => 3,
      final x when x == _tf('চতুর্থ') => 4,
      final x when x == _tf('পঞ্চম') => 5,
      _ => -1,
    };
  }
  final n = _tre(r'(?<=\s)(\S+)\s*(?:নম্বর|নাম্বার|নং)(?:\s*কাজ)?(?:টা|টি)?(?=\s)').firstMatch(f);
  if (n != null) return _tdNum(n[1]!);
  return null;
}

final _deictic = r'(?<=\s)(?:ওটা|ওটার|ওটাকে|ওইটা|ওইটার|এটা|এটার|এটাকে|এইটা|এইটার|সেটা|সেটার|সেইটা|এই\s+কাজটা|ওই\s+কাজটা|কাজটা|কাজটি|কাজটার|কাজটায়|কাজটাকে|আগেরটা|আগেরটার)(?=\s)';

/// What [f] points at.
TaskRef _tdRef(String f, String said) {
  final idx = _tdOrdinal(f);
  if (idx != null) return TaskRef(index: idx, said: said);
  final terms = _tdTerms(said);
  final it = _thas(f, _deictic);
  if (terms.isNotEmpty) return TaskRef(terms: terms, it: it, said: said);
  if (it) return TaskRef(it: true, said: said);
  return const TaskRef();
}

// ───────────────────────── Verb forms ─────────────────────────

/// "করেছি", "এনেছি", "দিয়ে দিয়েছি", "হয়ে গেছে", "শেষ", "টিক দাও", "done".
bool _saysDone(String f) =>
    _thas(f, r'(?<=\s)(?!রেখেছি|রেখেছিলাম|দেখেছি)\S+(?:েছি|েছিলাম)(?=\s)') ||
    _thas(f, r'(?<=\s)(?:করলাম|দিলাম|আনলাম|গেলাম|কিনলাম|সারলাম|পাঠালাম|খেলাম|ফেললাম)(?=\s)') ||
    _thas(f, r'(?<=\s)(?:হয়ে\s+গেছে|হয়েছে|হইছে|সারা\s+হয়েছে|শেষ\s+হয়েছে|শেষ\s+হলো|শেষ(?:\s+করেছি)?|সম্পন্ন(?:\s+(?:হয়েছে|করো|করেছি))?|টিক\s+(?:দাও|দিয়ে\s+দাও|দিন|দিও|মারো)|done(?:\s+(?:করো|করে\s+দাও|কর))?|শেষ\s+হিসেবে\s+\S+)(?=\s)');

/// "করিনি", "আনিনি", "দিইনি", "হয়নি", "হয় নেই", "করি নাই", "এখনো … না".
bool _saysNotDone(String f) =>
    _thas(f, r'(?<=\s)\S+(?:িনি|ইনি)(?=\s)') ||
    _thas(f, r'(?<=\s)(?:হয়নি|হয়\s+(?:নি|নেই|নাই)|হয়নাই|করি\s+(?:নি|নেই|নাই)|শেষ\s+হয়নি|হয়\s+নাই)(?=\s)') ||
    _thas(f, r'(?<=\s)এখনো\s+(?:\S+\s+){0,3}(?:না|নি)(?=\s)') ||
    _thas(f, r'(?<=\s)(?:আবার\s+)?বাকি\s+(?:রাখো|করো|করে\s+দাও)(?=\s)') ||
    _thas(f, r'(?<=\s)(?:আবার\s+)?(?:অসমাপ্ত|অসম্পূর্ণ)\s+(?:করো|রাখো)(?=\s)');

/// "করতে হবে", "আনতে হবে", "করা লাগবে", "যেতে হবে", or "করব", "দেব",
/// "গুছাব", "করমু": something the person is going to do.
bool _saysToDo(String f) {
  // "আজ আর অফিসে যাব না", "যেতে হবে না": nothing to do.
  if (_thas(f, r'(?<=\s)\S+(?:বো|ব|মু|তে\s+হবে|তে\s+লাগবে)\s+(?:না|নাই|নি)(?=\s)')) return false;
  if (_thas(f, r'(?<=\s)\S+তে\s+(?:হবে|হইবে|লাগবে|হয়)(?=\s)')) return true;
  if (_thas(f, r'(?<=\s)(?:করা|কেনা|আনা|দেওয়া|নেওয়া|যাওয়া|পাঠানো|জমা)\s+(?:লাগবে|দরকার|বাকি)(?=\s)')) return true;
  for (final w in words(normalize(f))) {
    if (RegExp(_tf(r'(?:বো|ব|মু)$')).hasMatch(w) && _nounOfVerb(w) != null) return true;
  }
  return false;
}

/// A to-do written down on purpose: "… লিখে রাখো", "কাজের তালিকায় রাখো",
/// "একটা কাজ যোগ করো", "… মনে রেখো", "… কাজ রাখো".
bool _ordersAdd(String f) =>
    _thas(f, r'(?<=\s)(?:লেখ|লেখো|লিখো|লিখে\s+রাখো|লিখে\s+রাখ|যোগ\s+করো|যুক্ত\s+করো)\s+যে(?=\s)') ||
    (_thas(f, r'(?<=\s)' + _listP + r'(?=\s)') && _thas(f, r'(?<=\s)(?:লেখ|লেখো|লিখো)(?=\s)')) ||
    (_thas(f, r'(?<=\s)' + _listP + r'(?=\s)') && _thas(f, r'(?<=\s)(?:রাখো|রাখ|রেখো|রাখেন|রাখুন|রেখে\s+দাও|লিখে\s+রাখো|যোগ\s+করো|যুক্ত\s+করো|তুলে\s+রাখো|ঢুকাও)\s*$')) ||
    _thas(f, _listP + r'\s+(?:(?:একটু\s+)?(?:লিখে\s+)?(?:রাখো|রাখ|রেখো|রাখেন|রাখুন|রেখে\s+দাও)|যোগ\s+কর|যুক্ত\s+কর|তুলে\s+রাখ|লিখো|লেখো|লিখে\s+দাও|ঢুকাও|add)') ||
    _thas(f, r'(?<=\s)(?:একটা|একটি|নতুন)?\s*কাজ\s+(?:যোগ|যুক্ত|এড|অ্যাড)\s+কর') ||
    _thas(f, r'(?<=\s)add\s+(?:a\s+)?task(?=\s|,)') ||
    _thas(f, r'(?<=\s)লিখে\s+(?:রাখো|রাখ|রেখো|রাখেন|দাও)(?=\s)') ||
    _thas(f, r'(?<=\s)(?:মনে\s+(?:রেখো|রাখো|রাখবা|রাখবে|রাখিও)|ভুলে\s+যেও\s+না)(?=\s)') ||
    _thas(f, r'(?<=\s)(?:\S+(?:ার|র)\s+)?কাজ\s+(?:রাখো|রাখ|রেখো|রাখেন|রাখুন)(?=\s)') ||
    _thas(f, r'(?<=\s)কাজ\s+হিসেবে\s+(?:রাখো|রাখ|রেখো)(?=\s)');

/// A question, or an order to show or tell.
bool _tdAsks(String said, String f) =>
    said.contains('?') ||
    _thas(f, _listP + r'\s+(?:টা\s+)?(?:দাও|দিন|দেন|দিবা)(?=\s|$)') ||
    _thas(f, r'(?<=\s)(?:কী|কি|কোন|কোনো|কয়টা|কয়টি|কতগুলো|কতগুলা|কত|কোনটা|কোনটার|কোনগুলো|কবে|কিনা|নাকি)(?=\s)') ||
    _thas(f, r'(?<=\s)(?:দেখাও|দেখান|দেখি|বলো|বলুন|বল|শোনাও|জানাও|খুঁজে\s+দাও|খোঁজো|খুঁজুন)(?=\s|$)');

// ───────────────────────── Looking at the list ─────────────────────────

/// A question about the to-do list, with what it covers. Null when [said]
/// is not one.
TaskQuery? _tdQuery(String said, String f, DateTime now) {
  final task = _thas(f, r'(?<=\s)' + _taskNounP + r'(?=\s)') || _thas(f, _listP);
  // "কী কী করা বাকি?", "আজ কী কী করার আছে?", "কী কী করতে হবে?", "কী কী করা লাগব?"
  final todoAsk = _thas(f, r'(?<=\s)(?:কী|কি)\s+(?:কী|কি\s+)?(?:\S+\s+)?(?:করা|করার|করতে|শেষ\s+করতে)\s+(?:বাকি|আছে|হবে|লাগবে|লাগব|দরকার)(?=\s)') ||
      _thas(f, r'(?<=\s)(?:কী|কি)\s+(?:কী|কি)\s+(?:বাকি|করব|করবো)(?=\s)');
  final free = _thas(f, r'(?<=\s)(?:ফ্রি|ফাঁকা|অবসর|free)\s+(?:আছি|থাকব|আছে|থাকবো)(?=\s)');
  final suggest = _thas(f, r'(?<=\s)(?:কোনটা|কোন\s+কাজ(?:টা)?|কী)\s+আগে\s+(?:করা\s+(?:ভালো|উচিত)|করব|করবো|করি)(?=\s)') || _thas(f, r'(?<=\s)এখন\s+(?:কী|কোনটা)\s+করব(?=\s)');
  final soonest = _thas(f, r'(?<=\s)কোনটার\s+(?:সময়|তারিখ)\s+(?:আগে|সবার\s+আগে)(?=\s)');
  final asks = _tdAsks(said, f);
  // "কালকের যে কাজগুলো আছে": the list, asked without a question word.
  final exists = _thas(f, r'(?<=\s)কাজ(?:গুলো|গুলি|গুলা|সমূহ)\s+(?:\S+\s+)?(?:আছে|বাকি|রয়েছে)(?=\s)') && !_ordersAdd(f);
  // "কোন তারিখে তুলবা ঢাকায় যেতে হবে": when a to-do is (or will be) kept.
  final whenKept = _thas(f, r'(?<=\s)(?:কোন\s+তারিখে|কবে|কখন|কোন\s+দিন)\s') && _thas(f, r'(?:তুলবা|তুলবে|তুলেছ|রাখবা|রাখবে|রাখলা|রেখেছ|রাখছ|লিখবা|লিখলা|লিখেছ)');
  // "যেগুলোর তারিখ দিইনি সেগুলো দেখাও", "সময় পার হয়ে গেছে এমন গুলো বলো".
  final listy = asks && _thas(f, r'(?:তারিখ\s+(?:দিইনি|দেইনি|দিই\s+নাই|নেই|নাই|ছাড়া|দেওয়া\s+নেই)|তারিখবিহীন|সময়\s+(?:পার|পেরিয়ে)|দেরি\s+হয়ে\s+গেছে)');
  if (!(todoAsk || free || suggest || soonest || listy || exists || whenKept || (task && asks))) return null;
  // An order to add, move or remove is not a question.
  if (task && !todoAsk && !free && !suggest && !soonest && !whenKept && (_ordersAdd(f) && !_thas(f, r'(?<=\s)(?:রেখেছি|রেখেছিলাম|রাখা|রাখছি)(?=\s)'))) return null;
  if (_thas(f, r'(?<=\s)(?:মুছে|মুছো|ডিলিট|সরাও|বাদ\s+দাও|পিছিয়ে|এগিয়ে)(?=\s)')) return null;
  if (_saysDone(f) && !_thas(f, r'(?<=\s)(?:কতগুলো|কয়টা|কয়টি|কী\s+কী|কি\s+কি|কত)(?=\s)') && !_thas(f, r'(?:পার|পেরিয়ে|দেরি)')) return null;

  final today = dayOnly(now);
  DateTime? from, to;
  var label = '';
  var undated = false, overdue = false, future = false, withOverdue = false, doneOnly = false;
  if (_thas(f, r'(?<=\s)(?:তারিখ\s+(?:দিইনি|দেইনি|দিই\s+নাই|নেই|নাই|ছাড়া|দেওয়া\s+নেই)|তারিখবিহীন|তারিখ\s+ছাড়া)')) {
    undated = true;
    label = 'তারিখ ছাড়া';
  } else if (_thas(f, r'(?:সময়\s+(?:পার|পেরিয়ে)|দেরি\s+হয়ে|পেরিয়ে\s+গেছে|মেয়াদ\s+পার|overdue|ডেট\s+পার)')) {
    overdue = true;
    label = 'সময় পেরোনো';
  } else if (_thas(f, r'(?<=\s)মাস(?:ের)?\s+(?:শেষের|শেষ\s+হওয়ার)\s+আগে(?=\s)')) {
    from = today;
    to = DateTime(today.year, today.month + 1, 0);
    withOverdue = true;
    label = 'মাস শেষের আগে';
  } else if (_thas(f, r'(?<=\s)(?:ভবিষ্যতের|সামনের\s+সব|আগামী\s+সব|পরের\s+সব)(?=\s)')) {
    future = true;
    label = 'সামনের';
  } else {
    final days = _tre(r'(?<=\s)(?:সামনের|আগামী|পরের)\s+(\S+)\s+দিন(?:ের|ে)?(?=\s)').firstMatch(f);
    final n = days == null ? null : _tdNum(days[1]!);
    if (n != null && n > 0) {
      from = today;
      to = today.add(Duration(days: n - 1));
      label = 'সামনের ${bnDigits(n)} দিনে';
    } else if (_thas(f, r'(?<=\s)(?:এই|এ)\s+সপ্তাহ')) {
      from = today;
      to = _weekStart(today).add(const Duration(days: 6));
      withOverdue = true;
      label = 'এই সপ্তাহে';
    } else if (_thas(f, r'(?<=\s)(?:আগামী|পরের|সামনের)\s+সপ্তাহ|next\s+week')) {
      from = _weekStart(today).add(const Duration(days: 7));
      to = from.add(const Duration(days: 6));
      label = 'আগামী সপ্তাহে';
    } else if (_thas(f, r'(?<=\s)(?:আগামী|পরের|সামনের)\s+মাস|next\s+month')) {
      from = DateTime(today.year, today.month + 1, 1);
      to = DateTime(today.year, today.month + 2, 0);
      label = 'আগামী মাসে';
    } else if (_tre(r'(?<=\s)(?<![০-৯0-9]\s)' + _monthsP + r'(?:\s+মাস(?:ে|ের)?)?(?:ের|এর|ে|তে)?(?=\s)').hasMatch(f) && !_thas(f, r'[০-৯0-9]{1,2}\s+' + _monthsP)) {
      final m = _tre(_monthsP).firstMatch(f)!;
      final mi = bnMonths.map(_tf).toList().indexOf(_tf(m[1]!)) + 1;
      final y = mi < today.month ? today.year + 1 : today.year;
      from = DateTime(y, mi, 1);
      to = DateTime(y, mi + 1, 0);
      label = '${bnMonths[mi - 1]} মাসে';
    } else if (_thas(f, r'(?<=\s)(?:এই|এ)\s+মাস')) {
      from = today;
      to = DateTime(today.year, today.month + 1, 0);
      withOverdue = true;
      label = 'এই মাসে';
    } else {
      final w = parseWhen(f, now);
      if (w != null && w.hasDay) {
        from = to = w.day;
        label = sayWhen(w.day, now, withTime: false);
      } else if (_thas(f, r'(?<=\s)(?:আজ|আজকে|আজকের)(?=\s)')) {
        from = to = today;
        label = 'আজ';
      }
    }
  }
  if (_thas(f, r'(?<=\s)(?:\S+\s+)?(?:শেষ|সম্পন্ন)\s+(?:করেছি|হয়েছে|হলো)(?=\s)') && _thas(f, r'(?<=\s)(?:কতগুলো|কয়টা|কয়টি|কী\s+কী|কি\s+কি|কত)(?=\s)')) {
    doneOnly = true;
    from ??= today;
    to ??= today;
    if (label.isEmpty) label = 'আজ';
  }
  final count = _thas(f, r'(?<=\s)(?:কয়টা|কয়টি|কতগুলো|কতগুলা|মোট|কত)(?=\s)');
  final urgent = _thas(f, r'(?<=\s)(?:জরুরি|গুরুত্বপূর্ণ|urgent)(?=\s)');
  // "বিল সংক্রান্ত কাজগুলো", "ওষুধ আনার কাজ রেখেছিলাম?", "অফিসের কাজগুলো".
  final about = [
    for (final t in _tdTerms(f.replaceAll(_tre(r'(?<=\s)(?:সংক্রান্ত|সম্পর্কিত|বিষয়ক|নিয়ে|রেখেছিলাম|রেখেছি|রাখা|জমেছে|জমা\s+হয়েছে|করার|করা|করতে|হবে|লাগবে|লাগব|দরকার|ফ্রি|ফাঁকা|আগে|ভালো|উচিত|সময়|পার|গেছে|পেরিয়ে|দেরি|মোট|সব|সবগুলো|সামনের|আগামী|পরের|ভবিষ্যতের|দিন|দিনের|সপ্তাহে|সপ্তাহের|মাসে|মাসের|শেষের|এমন|যেগুলোর|সেগুলো|দিইনি|ছাড়া|জরুরি|গুরুত্বপূর্ণ|কাজগুলো|শেষ|করেছি|খুলো|খোলো)(?=\s)'), ' ')))
      if (!_tre(r'^(?:কয়টা|কতগুলো|কিনা|কিছু|কোনটা|কোনটার|কোনগুলো|বাকি|ফ্রি|ফাঁকা|অবসর|লাগব|জমেছে|নাকি|আছি|থাকব|থাকবো|আর|এখন|আছে|নেই|তুলবা|তুলবে|রাখবা|রাখলা|লিখবা|লিখলা|কবে|কখন|তারিখে|জানুয়ারি|ফেব্রুয়ারি|মার্চ|এপ্রিল|মে|জুন|জুলাই|আগস্ট|সেপ্টেম্বর|অক্টোবর|নভেম্বর|ডিসেম্বর|মাস|\d+)$').hasMatch(t) && _tdNum(t) == null) t,
  ];
  return TaskQuery(said,
      scope: TaskScope(
        from: from,
        to: to,
        undated: undated,
        overdue: overdue,
        future: future,
        withOverdue: withOverdue,
        doneOnly: doneOnly,
        about: about,
        urgentFirst: urgent,
        count: count,
        free: free,
        suggest: suggest,
        soonest: soonest,
        label: label,
      ));
}

// ───────────────────────── One request ─────────────────────────

/// Money, a password or a call is never a to-do.
bool _tdNotMine(String said, String f) {
  if (mentionsSecret(said)) return true;
  if (_thas(f, r'(?<=\s)(?:টাকা|টাকার|টাকায়|৳|tk|taka|হাজার|লাখ)(?=\s)')) return true;
  var bare = f.replaceAll(_tre(r'(?<=\s)\S+\s+(?:দিন|সপ্তাহ|মাস|বছর)(?:\s+(?:পরে|পর|পরপর|পর\s+পর|বাদে|অন্তর))?(?=\s)'), ' ');
  bare = bare.replaceAll(_tre(r'(?<=\s)\S+\s*(?:নম্বর|নাম্বার|নং)(?=\s)'), ' ');
  bare = bare.replaceAll(_tre(r'(?<=\s)\S+(?:টা|টি)\s+কাজ'), ' ');
  bare = normalize(withoutWhen(bare));
  bare = bare.replaceAll(RegExp(r'(?<=^|\s)\d{1,2}(?=\s|$)'), ' ');
  return findAmount(normalize(bare)) != null && RegExp(r'\d').hasMatch(bare);
}

/// The to-do commands in [said] (tidied already), or null when it is not
/// about the to-do list. Several requests in one breath ("বাজার করেছি,
/// ওষুধ আনিনি। আর ব্যাংকের কাজটা কাল রাখো") give one command each.
List<Command>? todoCommands(String said, List<Task> tasks, DateTime now) {
  final whole = said.trim();
  if (whole.isEmpty) return null;
  // Several clauses, each a to-do request of its own.
  final clauses = [
    for (final c in whole.split(_tre(r'[।!?\n]+|,\s*|;\s*|\s+(?:আর|এবং|তারপর|এরপর)\s+(?=\S)')))
      if (c.trim().isNotEmpty) c.trim(),
  ];
  // "বৃহস্পতিবার করব, তবে শুক্রবারের মধ্যে জমা দিতে হবে": one to-do.
  final oneThought = _thas(' ${_tf(whole)} ', r'\s(?:তবে|কিন্তু)\s.+মধ্যে');
  if (clauses.length >= 2 && !oneThought) {
    final cmds = [for (final c in clauses) _tdOne(c, tasks, now)];
    final real = cmds.whereType<Command>().where((c) => c is! TaskQuery || clauses.length == 1).toList();
    final kinds = cmds.where((c) => c != null).length;
    // Every clause understood, and at least one is a change (not just a list).
    if (kinds == clauses.length && real.length == clauses.length && real.any((c) => c is TaskDone || c is TaskEdit)) {
      // "ওষুধ এনেছি, কাজটা টিক দাও": the second clause is the same one.
      final out = <Command>[];
      for (final c in real) {
        final prev = out.isEmpty ? null : out.last;
        if (c is TaskDone && prev is TaskDone && c.done == prev.done && (c.ref?.it ?? false) && (c.ref?.terms.isEmpty ?? true)) continue;
        out.add(c);
      }
      return out;
    }
  }
  final one = _tdOne(whole, tasks, now);
  if (one == null) return null;
  // "বাজার, ওষুধ আর বিদ্যুৎ বিল—তিনটা কাজ রাখো": one to-do each.
  final list = _tre(r'^(.+?)\s*[—–-]?\s*(?:[^\s—–-]+টা|[^\s—–-]+টি|দুটো|দুইটা)\s+কাজ\s+(?:রাখো|রাখ|রেখো|লিখে\s+রাখো|যোগ\s+করো|তুলে\s+রাখো)\s*[।.!]*$').firstMatch(_tf(whole));
  if (one is TaskAdd && list != null) {
    final items = [for (final x in list[1]!.split(_tre(r'\s*,\s*|\s+(?:আর|ও|এবং)\s+'))) if (todoTitle(x).isNotEmpty) todoTitle(x)];
    if (items.length >= 2) return [for (final x in items) TaskAdd(whole, title: x, due: one.due, span: one.span)];
  }
  return [one];
}

/// "(এখন) একটা কাজ করো (তো)": how a request opens, anywhere in it.
final _opener = r'(?<=\s)(?:আচ্ছা\s+)?(?:এখন\s+)?(?:তুমি\s+)?(?:এক|একটা|একটি)\s+কাজ\s+(?:করো|কর|করেন|করুন|করবা)(?:\s+তো)?(?=\s)';

Command? _tdOne(String said0, List<Task> tasks, DateTime now) {
  final said = ' ${_tf(said0)} '.replaceAll(_tre(_opener), ' ').trim();
  final f = ' ${_tf(said).replaceAll(RegExp(r'[।!?,;:"“”]'), ' ').replaceAll(RegExp(r'\s*[—–]\s*'), ' ').toLowerCase()} ';
  if (_tdNotMine(said, f)) return null;
  final open = tasks.where((t) => !t.done).toList();
  // Alarms have their own page and rules.
  if (_thas(f, r'(?:অ্যালার্ম|এলার্ম|alarm|ঘুম\s+থেকে)')) return null;
  // Removing ("…সেটা মুছে দাও", "সবগুলো বাদ দিয়ে দাও") has its own careful
  // rules (asked once, the right one found) — never read as something to do.
  if (_thas(f, r'(?<=\s)(?:মুছে\s+(?:দাও|দিও|ফেলো|দেন|দিন)|মুছো|ডিলিট|delete|কেটে\s+দাও|বাদ\s+(?:দাও|দিয়ে\s+দাও|দিও|দেন))(?=\s)') &&
      !_thas(f, r'(?:ভাবছিলাম|ভেবেছিলাম|চেয়েছিলাম|চাচ্ছিলাম)') && !_thas(f, r'(?<=\s)(?:এই|এ|এবারের)\s+' + _wdP + r'\s*(?:টা|টি)?\s+বাদ') && !_thas(f, r'^\s*(?:আগেরটা|আজ)\s+বাদ') &&
      !_thas(f, r'(?<=\s)তারিখ(?:টা)?\s+(?:বাদ|মুছে|কেটে)')) {
    return null;
  }
  // "বাজারের লিস্টে ডিম রাখো": a list of its own ("বাজার: ডিম"), not the to-dos.
  final named = _tre(r'(?<=\s)(\S+?)(?:ের|এর|র)\s+(?:লিস্ট|তালিকা)').firstMatch(f);
  if (named != null && _tf(named[1]!) != _tf('কাজ') && _tf(named[1]!) != _tf('কাজে')) return null;

  // "ভুল করে মুছে ফেলেছি, ফেরত আনো".
  if (_thas(f, r'(?:মুছে\s+ফেলেছি|ডিলিট\s+করেছি|মুছে\s+গেছে|মুছে\s+দিয়েছি)') && _thas(f, r'(?:ফেরত|ফিরিয়ে|ফিরায়ে|ফিরাও|restore|undo)')) return TaskRestore(said);

  // "আমার টু-ডু লিস্ট খোলো": the page itself.
  if (_thas(f, r'(?:' + _listP + r'|' + _taskNounP + r')\s+(?:পাতা\s+|পেজ\s+)?(?:খোলো|খোল|খুলুন|খুলে\s+দাও|ওপেন\s+করো|open)(?=\s)')) {
    return OpenPlace(said, place: 'tasks');
  }

  final q = _tdQuery(said, f, now);
  if (q != null) return q;

  // Reminders that belong to a to-do.
  final remindWord = _thas(f, r'(?:রিমাইন্ডার|reminder|মনে\s+(?:করিও|করাইও|করিয়ো|করিয়ে\s+দিও|করিয়ে\s+দিবা|করাবে|করাবা|করিয়ে\s+দেবে)|জানাবে|জানিও|জানিয়ে\s+দিও)');
  final pointsAtTask = _thas(f, _deictic) || _thas(f, r'(?<=\s)\S+\s+কাজ(?:টা|টি|টার|টায়|টাকে)(?=\s)') || _tdOrdinal(f) != null;
  // "আর মনে করিও না": the reminder of the one being talked about.
  if (_thas(f, r'^\s*(?:আর\s+)?(?:মনে\s+(?:করিও|করাইও|করাবে|করিয়ো|করিয়ে\s+দিও)\s+না|(?:রিমাইন্ডার|reminder)(?:টা)?\s+(?:বন্ধ|অফ|off)\s+করো(?:\s+(?:কাজ|task)\s+(?:থাকবে|থাকুক|থাক))?)\s*$')) {
    return TaskEdit(said, ref: TaskRef(it: true, said: said), stopReminder: true);
  }
  if (remindWord && pointsAtTask) {
    final ref = _tdRef(f, said);
    if (_thas(f, r'(?:মনে\s+(?:করিও|করাইও|করাবে|করিয়ো|করিয়ে\s+দিও)\s+না|(?:রিমাইন্ডার|reminder)(?:টা)?\s+(?:বন্ধ|অফ|off))')) {
      return TaskEdit(said, ref: ref.isEmpty ? TaskRef(it: true, said: said) : ref, stopReminder: true);
    }
    // "কাজের সময়ের আধা ঘণ্টা আগে": a to-do has no time of its own.
    if (_thas(f, r'(?:সময়ের|সময়\s+থেকে)\s+(?:\S+\s+)?(?:\S+\s+)?(?:আগে|পরে)')) {
      return TaskEdit(said, ref: ref.isEmpty ? TaskRef(it: true, said: said) : ref, remindNeedsTime: true, say: 'কাজটার নিজের কোনো সময় রাখা নেই। কখন মনে করাব? যেমন “সকাল ৯টায়”।');
    }
    final w = parseWhen(f, now);
    final r = ref.isEmpty ? TaskRef(it: true, said: said) : ref;
    if (w == null || !w.hasTime) {
      final part = _thas(f, r'(?<=\s)(?:সকালে|সকাল|দুপুরে|বিকেলে|সন্ধ্যায়|রাতে)(?=\s)');
      return TaskEdit(said, ref: r, remindNeedsTime: true, say: part ? '{0} কয়টায় মনে করিয়ে দেব?' : null, due: w != null && w.hasDay ? w.day : null);
    }
    final relative = _thas(f, r'(?:মিনিট|ঘণ্টা|ঘন্টা)\s+(?:পরে|পর|বাদে)');
    if (relative || w.hasDay) return TaskEdit(said, ref: r, remindAt: w.at, remindAmPm: ampmUnclear(said));
    return TaskEdit(said, ref: r, remindHour: w.at.hour, remindMinute: w.at.minute, remindAmPm: ampmUnclear(said));
  }

  // Places and conditions the app cannot know about.
  if (_thas(f, r'(?<=\s)\S+\s+(?:কাছে|পাশে|কাছাকাছি)\s+(?:গেলে|পৌঁছালে|গেলেই)(?=\s)') && remindWord) {
    return TaskEdit(said, say: 'জায়গা ধরে মনে করানোর ব্যবস্থা এই অ্যাপে নেই। একটা সময় বললে সেই সময়ে মনে করিয়ে দেব।');
  }

  // Changes to a to-do on the list.
  final edit = _tdEdit(said, f, open, now);
  if (edit != null) return edit;

  // Done, not done.
  final partial = _thas(f, r'(?<=\s)(?:অর্ধেক|আংশিক|কিছুটা)\s+(?:হয়েছে|করেছি|হলো|শেষ)(?=\s)');
  if (partial) {
    final ref = _tdRef(f, said);
    return TaskDone(said, terms: ref.terms, ref: ref.isEmpty ? TaskRef(it: true, said: said) : ref, partial: true);
  }
  if (_thas(f, r'(?<=\s)সব\s+(?:কাজ\s+)?শেষ\s+(?:হয়নি|হয়\s+নাই|হয়\s+নি)(?=\s)')) {
    return TaskEdit(said, say: 'ঠিক আছে। কোন কাজগুলো বাকি আছে?');
  }
  final reopen = _thas(f, r'(?<=\s)(?:আবার\s+)?(?:বাকি|অসমাপ্ত|অসম্পূর্ণ)\s+(?:রাখো|করো|করে\s+দাও)(?=\s)');
  final notDone = reopen || _saysNotDone(f);
  // "রিপোর্ট শেষ করতে হবে", "রিপোর্ট শেষ হলে পাঠাব": still to do, not done.
  final done = !notDone && !_saysToDo(f) && _saysDone(f);
  if (reopen) {
    final ref = _tdRef(f, said);
    return TaskDone(said, terms: ref.terms, ref: ref.terms.isEmpty && ref.index == null ? TaskRef(it: true, said: said) : ref, done: false);
  }
  if (done || notDone) {
    // "আজকের সব কাজ শেষ": every to-do of the day, asked once.
    if (done && _thas(f, r'(?<=\s)(?:সব|সবগুলো|সবকটা|সবকয়টা)\s+(?:কাজ(?:ই)?\s+)?(?:শেষ|হয়ে\s+গেছে|করেছি|done)')) {
      final today = _thas(f, r'(?<=\s)(?:আজ|আজকে|আজকের)(?=\s)');
      return TaskDone(said, terms: const [], all: true, allToday: today);
    }
    final ref = _tdRef(f, said);
    if (ref.terms.isNotEmpty && ref.index == null) {
      // Words that name no to-do: not about the list ("রহিমকে দিয়েছি").
      final pool = notDone ? tasks : open;
      if (tdMatch(pool, ref.terms, open: !notDone).isEmpty) return null;
    }
    if (ref.isEmpty) {
      if (!_thas(f, r'(?:টিক|done|সম্পন্ন|কাজটা|ওটা|এটা)')) return null;
      return TaskDone(said, terms: const [], ref: TaskRef(it: true, said: said), done: done);
    }
    return TaskDone(said, terms: ref.terms, ref: ref, done: done);
  }

  // "কাল ব্যাংকে যেতে হবে না", "আজ আর অফিসে যাব না": not something to do.
  // About a to-do on the list, the person is asked what to do with it.
  if (_thas(f, r'(?<=\s)\S+(?:বো|ব|মু|তে\s+হবে|তে\s+লাগবে)\s+(?:না|নাই|নি)(?=\s)') && !_tdAsks(said, f)) {
    final ref = _tdRef(f, said);
    final hit = ref.terms.isEmpty ? const <Task>[] : tdMatch(open, ref.terms);
    if (hit.length == 1) {
      return TaskEdit(said, ref: TaskRef(ids: [hit.single.id], said: said), say: '“${hit.single.title}” কাজটা তালিকায় আছে — মুছে দেব, নাকি অন্য দিনে সরাব?');
    }
    return TaskEdit(said, say: 'ঠিক আছে, কিছু রাখিনি।');
  }
  // Something to do.
  return _tdAdd(said, f, tasks, now);
}

/// A change to a to-do already on the list, or null.
TaskEdit? _tdEdit(String said, String f, List<Task> open, DateTime now) {
  // "…মুছে দেব ভাবছিলাম, কিন্তু এখন রাখো": the last word decides — keep.
  final mind = _tre(r'^(.*?)(?:ভাবছিলাম|ভেবেছিলাম|চেয়েছিলাম|চাচ্ছিলাম|ইচ্ছা\s+ছিল)(.*?)\s(?:কিন্তু|তবে|বরং)\s+(.*)$').firstMatch(f.trim());
  if (mind != null) {
    final last = ' ${mind[3]!} ';
    if (_thas(last, r'(?<=\s)(?:রাখো|রাখ|রেখে\s+দাও|থাক|থাকুক|রেখো|মুছো\s+না|মুছবে\s+না)(?=\s)') && !_thas(last, r'(?:মুছে\s+দাও|ডিলিট\s+করো)')) {
      final ref = _tdRef(' ${mind[1]} ${mind[2]} ', '${mind[1]} ${mind[2]}');
      return TaskEdit(said, ref: ref.isEmpty ? TaskRef(it: true, said: said) : ref, keep: true);
    }
  }
  final ref = _tdRef(f, said);
  final named = ref.terms.isNotEmpty && tdMatch(open, ref.terms).isNotEmpty;
  final pointed = ref.it || ref.index != null || named;
  final defin = _thas(f, r'(?:কাজটা|কাজটি|কাজটার|কাজটায়|(?<!এক)(?:টা|টাকে|টার)\s)') || ref.it || ref.index != null;
  final aboutReminder = _thas(f, r'(?:রিমাইন্ডার|reminder|মনে\s+করি|মনে\s+করা|অ্যালার্ম|এলার্ম)');

  // "বাজার করার বদলে মাসের বাজার করা লিখো".
  final rename = _tre(r'^\s*(.+?)\s*(?:এর|ের)?\s+(?:বদলে|পরিবর্তে|জায়গায়)\s+(.+?)\s+(?:লিখো|লেখো|লিখে\s+দাও|লিখে\s+রাখো|করো|রাখো|দাও|করে\s+দাও)\s*$').firstMatch(f);
  if (rename != null && !_thas(rename[1]!, r'(?:টাকা|সময়)')) {
    final r = _tdRef(' ${rename[1]} ', rename[1]!);
    final title = todoTitle(rename[2]!);
    if (title.isNotEmpty && !r.isEmpty) return TaskEdit(said, ref: r, title: title);
  }
  // "এর সঙ্গে লিখো, কাগজপত্র নিতে হবে".
  final note = _tre(r'(?:^|\s)(?:এর|এটার|ওটার|এই\s+কাজের|কাজটার)?\s*(?:সঙ্গে|সাথে)\s+(?:লিখো|লেখো|লিখে\s+রাখো|যোগ\s+করো|লিখে\s+দাও)\s+(.+)$').firstMatch(f);
  if (note != null) return TaskEdit(said, ref: TaskRef(it: true, said: said), note: tidy(note[1]!));
  // "তারিখ বাদ দাও, কাজটা থাক".
  if (_thas(f, r'(?<=\s)তারিখ(?:টা)?\s+(?:বাদ|সরাও|সরিয়ে|মুছে|উঠিয়ে|তুলে)')) {
    return TaskEdit(said, ref: named ? ref : TaskRef(it: true, said: said), clearDue: true);
  }
  // "একদিন পিছিয়ে দাও", "দুই দিন এগিয়ে আনো".
  final shift = _tre(r'(?<=\s)(?:(\S+)\s+)?দিন\s+(পিছিয়ে|পিছাও|পেছাও|পিছিয়ে\s+দাও|এগিয়ে|আগাও)').firstMatch(f) ?? _tre(r'(?<=\s)(একদিন)\s+(পিছিয়ে|পিছাও|পেছাও|এগিয়ে|আগাও)').firstMatch(f);
  if (shift != null) {
    final n = shift[1] == null || _tf(shift[1]!) == _tf('একদিন') ? 1 : (_tdNum(shift[1]!) ?? 1);
    final back = _thas(shift[2]!, r'(?:এগিয়ে|আগাও)');
    return TaskEdit(said, ref: named || ref.index != null ? ref : TaskRef(it: true, said: said), shiftDays: back ? -n : n);
  }
  // "এত জরুরি না, সাধারণ রাখো" / "বিল দেওয়ার কাজটা জরুরি".
  if (_thas(f, r'(?<=\s)(?:(?:এত|অত)\s+)?জরুরি\s+(?:না|নয়|নেই)(?=\s)|(?<=\s)সাধারণ\s+(?:রাখো|করো|করে\s+দাও)(?=\s)')) {
    return TaskEdit(said, ref: named ? ref : TaskRef(it: true, said: said), urgent: false);
  }
  if (_thas(f, r'(?<=\s)(?:জরুরি|খুব\s+জরুরি|গুরুত্বপূর্ণ|urgent|important)(?:\s+(?:কাজ|করো|রাখো|করে\s+দাও))?(?=\s)') && (pointed || defin)) {
    return TaskEdit(said, ref: named || ref.index != null ? ref : TaskRef(it: true, said: said), urgent: true);
  }
  // "কয়েক দিন বন্ধ রাখো": how long, first.
  if (_thas(f, r'(?<=\s)কয়েক\s+দিন\s+(?:বন্ধ|স্থগিত)')) {
    return TaskEdit(said, ref: TaskRef(it: true, said: said), say: 'কত দিন বন্ধ রাখব? বললে কাজটা ততদিন পিছিয়ে দেব।');
  }
  // "মুছবে না, শুধু লুকিয়ে রাখো".
  if (_thas(f, r'(?:লুকিয়ে\s+রাখো|আর্কাইভ|archive)')) {
    return TaskEdit(said, say: 'লুকিয়ে রাখার ব্যবস্থা এখনো নেই। চাইলে কাজটা শেষ হিসেবে দাগ দিতে পারি — তালিকায় আলাদা থাকবে।');
  }
  // "পরে করমু, এখন না".
  if (_thas(f, r'(?<=\s)পরে\s+(?:করব|করবো|করমু)(?=\s)') && _thas(f, r'(?<=\s)এখন\s+না(?=\s)')) {
    return TaskEdit(said, ref: TaskRef(it: true, said: said), say: 'ঠিক আছে, এখন থাক। কবে করবেন বললে সেদিনে সরিয়ে রাখব।');
  }
  // "এই শুক্রবারটা বাদ দাও": one time of a repeating to-do.
  final skip = _tre(r'(?<=\s)(?:এই|এ|এবারের)\s+' + _wdP + r'\s*(?:টা|টি)?\s+বাদ').firstMatch(f);
  if (skip != null) {
    final wd = _wdIndex(skip[1]!);
    final rep = [for (final t in open) if (t.repeat != null && t.due != null && t.due!.weekday == wd) t];
    final r = named ? ref : (rep.length == 1 ? TaskRef(ids: [rep.first.id], said: said) : TaskRef(it: true, said: said));
    return TaskEdit(said, ref: r, skipOnce: true);
  }
  // "এটা আর করার দরকার নেই", "নিয়মিত বাজারের কাজটা পুরো বন্ধ করো".
  if (_thas(f, r'(?:আর\s+(?:করার|করতে\s+হবে\s+না)|দরকার\s+নেই|লাগবে\s+না)') && (ref.it || named) && !_thas(f, r'(?:মনে|রিমাইন্ডার)')) {
    return TaskEdit(said, ref: named ? ref : TaskRef(it: true, said: said), delete: true);
  }
  if (_thas(f, r'(?<=\s)(?:নিয়মিত|প্রতিদিনের|প্রতি\s+সপ্তাহের)\s+') && _thas(f, r'(?:পুরো\s+)?(?:বন্ধ\s+করো|বন্ধ\s+করে\s+দাও|মুছে\s+দাও|বাদ\s+দাও)') && named) {
    return TaskEdit(said, ref: ref, delete: true);
  }

  // A new day for it: "ডাক্তারকে ফোন করার কাজটা কাল রাখো", "কাজটা শুক্রবারে
  // সরাও", "আজ না, পরশু করব", "শেষেরটা কাল দাও", "বুধবার রাখো".
  // "আগেরটা বাদ, এটা রাখো": which ones is not clear without them named.
  if (_thas(f, r'^\s*আগেরটা\s+বাদ')) {
    return TaskEdit(said, say: 'কোনটা বাদ দেব আর কোনটা রাখব, নাম ধরে আরেকবার বলবেন?');
  }
  final notToday = _tre(r'^\s*আজ\s+(?:না|নয়|বাদ)\s+(.+)$').firstMatch(f);
  // "বুধবার রাখো", "কাল রাখো", "পরশু করো": only a when and the order.
  final onlyWhen = ref.isEmpty && !_thas(f, r'(?<=\s)' + _listP + r'(?=\s)') && _thas(f, r'^\s*(?:\S+\s+){1,3}(?:রাখো|রাখ|দাও|করো|সরাও|নাও|করব|করবো)\s*$') && _tdWhen(f, now).day != null && _tdTerms(f).isEmpty;
  final moveVerb = _thas(f, r'(?<=\s)(?:রাখো|রাখ|রেখো|সরাও|সরিয়ে\s+দাও|নাও|নিয়ে\s+যাও|দাও|করো|move\s+করো|move|শিফট\s+করো|নিয়ে\s+নাও|পাঠাও)(?=\s|$)');
  final explicitAdd = _thas(f, r'(?:লিখে\s+রাখ|যোগ\s+কর|যুক্ত\s+কর|নতুন\s+কাজ|add)') || _thas(f, _listP);
  final named0 = ref.terms.isNotEmpty && defin;
  if (!aboutReminder && (notToday != null || onlyWhen || (moveVerb && !explicitAdd && (ref.it || ref.index != null || named || named0)))) {
    final w = _tdWhen(notToday != null ? notToday[1]! : f, now);
    // "বুধবার রাখো" with a to-do of a whole week: that day of its week.
    final wdOnly = _tre(r'^\s*' + _wdP + r'\s+(?:রাখো|রাখ|দাও|করো|সরাও|করব|করবো)\s*$').firstMatch(f);
    final r = notToday != null || ref.isEmpty ? TaskRef(it: true, said: said) : ref;
    if (wdOnly != null) return TaskEdit(said, ref: r, weekday: _wdIndex(wdOnly[1]!), due: w.day);
    final dom = _tre(r'^\s*([০-৯0-9]{1,2})\s+তারিখ\S*\s+(?:রাখো|রাখ|দাও|করো|সরাও|করব|করবো)\s*$').firstMatch(f);
    if (dom != null) return TaskEdit(said, ref: r, due: w.day, dayOfMonth: int.parse(asciiDigits(dom[1]!)));
    if (w.day != null && w.repeat == null) {
      // "…কাজটা কাল রাখো" for a to-do not on the list: kept as a new one.
      final keepVerb = _thas(f, r'(?<=\s)(?:রাখো|রাখ|রেখো|দাও|করো)\s*$');
      final fresh = keepVerb && !named && ref.terms.isNotEmpty ? todoTitle(w.rest) : null;
      return TaskEdit(said, ref: r, due: w.day, span: w.span, newTitle: fresh != null && fresh.isNotEmpty ? fresh : null);
    }
  }
  return null;
}

/// Something to do, or null when [said] does not ask to keep one.
Command? _tdAdd(String said, String f, List<Task> tasks, DateTime now) {
  final ordered = _ordersAdd(f);
  final toDo = _saysToDo(f);
  // "ব্যাংকে যাওয়া বাকি আছে" (said, not asked).
  final pending = _thas(f, r'(?<=\s)\S+(?:া|ো|য়া)\s+(?:এখনো\s+)?বাকি\s+(?:আছে|রয়েছে)(?=\s)');
  final reminder = _thas(f, r'(?:মনে\s+করিয়ে|মনে\s+করিও|মনে\s+করাইও|মনে\s+করাবে|মনে\s+করাবা|রিমাইন্ডার|reminder|অ্যালার্ম|এলার্ম|alarm|জানিয়ে\s+দিও)');
  if (reminder) return null;
  // "আমি কাকে কত দেব?": a question, never a to-do to keep.
  if (_tdAsks(said, f) && !ordered) return null;
  // "লিখে রাখো যে করিমের দোকান বন্ধ" is a note: an order to write is a
  // to-do only with the list or a to-do word in it, or something to do.
  final strong = _thas(f, r'(?<=\s)' + _listP + r'(?=\s)') || _thas(f, r'(?<=\s)' + _taskNounP + r'(?=\s)') || _thas(f, r'add\s+(?:a\s+)?task');
  if (!((ordered && strong) || toDo || pending)) return null;
  if (_thas(f, r'(?<=\s)(?:তুমি|তোমার|তোমাকে|তুই|আপনি)(?=\s)') && !ordered) return null;
  // "বৃহস্পতিবার করব, তবে শুক্রবারের মধ্যে জমা দিতে হবে": the day it is
  // planned and the last day, both kept.
  final two = _tre(r'^\s*(.+?)\s+(?:তবে|কিন্তু)\s+(.+?(?:ের|এর|র)\s+মধ্যে.+)$').firstMatch(f);
  if (two != null) {
    final plan = _tdWhen(two[1]!, now);
    final by = _tdWhen(two[2]!, now);
    final title = todoTitle(by.rest);
    if (plan.day != null && by.day != null && title.isNotEmpty) {
      var last = by.day!;
      while (last.isBefore(plan.day!)) {
        last = last.add(const Duration(days: 7));
      }
      return TaskAdd(said, title: title, due: plan.day, by: last);
    }
  }
  // "ঈদের আগে": the next Eid from the calendar, offered — not assumed.
  if (_thas(f, r'(?<=\s)ঈদের\s+আগে(?:ই)?(?=\s)')) {
    final eid = _nextEid(now);
    final title = todoTitle(f.replaceAll(_tre(r'(?<=\s)ঈদের\s+আগে(?:ই)?(?=\s)'), ' '));
    if (eid != null && title.isNotEmpty) {
      final by = eid.$1.subtract(const Duration(days: 1));
      return Clarify(said, question: 'সামনের ${eid.$2} সম্ভাব্য ${bnDigits(eid.$1.day)} ${bnMonths[eid.$1.month - 1]} ${bnDigits(eid.$1.year)} (চাঁদ দেখার ওপর নির্ভর করে)। তার আগের দিন, ${bnDigits(by.day)} ${bnMonths[by.month - 1]}-এর মধ্যে করার কাজ হিসেবে রাখব?', options: [
        ('হ্যাঁ, ${bnDigits(by.day)} ${bnMonths[by.month - 1]}-এর মধ্যে', TaskAdd(said, title: title, due: by, deadline: true)),
        ('না, তারিখ ছাড়া রাখো', TaskAdd(said, title: title, condition: 'ঈদের আগে')),
      ]);
    }
  }
  // "কাল সকাল ১০টায় ব্যাংকে যাবো": with a clock time it is a reminder.
  final clock = parseWhen(f, now);
  if (clock != null && clock.hasTime && saysClock(f) && !(ordered && strong)) return null;
  final w = _tdWhen(said, now);
  // "বেতন পেলে", "রিপোর্ট শেষ হলে", "অফিস থেকে ফেরার পর": a condition the
  // app cannot see — kept with the to-do, never turned into a date.
  String? cond;
  final c = _tre(r'^\s*(.+?\s(?:পেলে|পেলেই|হলে|হলেই|গেলে|এলে|আসলে|ফিরলে|করলে|দিলে|পারলে|থাকলে|মিললে|পৌঁছালে|আসার\s+পর|ফেরার\s+পর|যাওয়ার\s+পর|করার\s+পর|পাওয়ার\s+পর|শেষ\s+হলে))\s+(.+)$').firstMatch(' ${_tf(w.rest)} ');
  var rest = w.rest;
  if (c != null && !_thas(c[1]!, r'(?:মনে|লিখে|রাখো)') && todoTitle(c[2]!).isNotEmpty) {
    cond = tidy(c[1]!);
    rest = c[2]!;
  }
  final title = todoTitle(rest);
  if (title.isEmpty) {
    if (ordered) return TaskAdd(said, title: '', due: w.day, span: w.span);
    return null;
  }
  // A to-do said on its weekday ("শুক্রবার মাসের বাজার করব" on a Friday).
  if (w.sameWeekday && w.day != null) {
    final next = w.day!.add(const Duration(days: 7));
    return Clarify(said, question: 'আজই ${weekdayName(w.day!)}, নাকি আগামী ${weekdayName(w.day!)}?', options: [
      ('আজ (${weekdayName(w.day!)})', TaskAdd(said, title: title, due: w.day, deadline: w.deadline, condition: cond)),
      ('আগামী ${weekdayName(next)}, ${bnDigits(next.day)} ${bnMonths[next.month - 1]}', TaskAdd(said, title: title, due: next, deadline: w.deadline, condition: cond)),
    ]);
  }
  return TaskAdd(said, title: title, due: w.undated ? null : w.day, span: w.span, repeat: w.repeat, deadline: w.deadline, condition: cond);
}

/// How well [terms] name [t] (for the chat and the answers).
int taskScore(Task t, List<String> terms) => _tdScore(t, terms);

/// The next Eid (ঈদুল ফিতর on 1 Shawwal, ঈদুল আজহা on 10 Dhul Hijjah) from
/// the Hijri calendar, and its name. The real day depends on the moon.
(DateTime, String)? _nextEid(DateTime now) {
  var d = dayOnly(now);
  for (var i = 0; i < 400; i++) {
    final h = hijriDate(d);
    if (h.month == 10 && h.day == 1) return (d, 'ঈদুল ফিতর');
    if (h.month == 12 && h.day == 10) return (d, 'ঈদুল আজহা');
    d = d.add(const Duration(days: 1));
  }
  return null;
}

/// A reminder's words without the asking: "বিল দিতে মনে করিও" → "বিল দেওয়া".
String reminderWords(String title) {
  var s = ' ${_tf(title)} ';
  s = s.replaceAll(_tre(r'(?<=\s)(?:আমাকে\s+)?(?:একটু\s+)?মনে\s+(?:করিও|করাইও|করিয়ো|করিয়ে\s+দিও|করিয়ে\s+দিবা|করিয়ে\s+দেবে|করিয়ে\s+দিবে|করাবে|করাবা|করাও|করিয়ে\s+দাও|করিয়ে\s+দিয়ো)(?=\s|$)'), ' ');
  s = s.replaceAll(_tre(r'(?<=\s)(?:জানিয়ে\s+দিও|জানাবে|জানিও)(?=\s|$)'), ' ');
  final t = s.trim();
  if (t.isEmpty) return '';
  final ws = t.split(RegExp(r'\s+'));
  // "স্কুলে যেতে হবে" → "স্কুলে যাওয়া", like a to-do.
  if (ws.length >= 2 && const ['হবে', 'লাগবে', 'হইবে'].map(_tf).contains(ws.last) && _nounOfVerb(ws[ws.length - 2]) != null) ws.removeLast();
  final n = _nounOfVerb(ws.last);
  if (n != null) ws[ws.length - 1] = n;
  return ws.join(' ');
}

/// [s] without clock times said in words or digits ("এগারোটায়", "সাড়ে
/// ৫টায়") — for telling whether anything but a time was said.
String withoutClockWords(String s) => ' ${_tf(s)} '
    .replaceAll(_tre(r'(?<=\s)(?:সাড়ে\s+|সোয়া\s+|পৌনে\s+)?(?:এক|দুই|দু|তিন|চার|পাঁচ|ছয়|সাত|আট|নয়|দশ|এগারো|এগার|বারো|[০-৯0-9]{1,2})(?:টা|টায়|টার|টাতে|টে)(?=\s)'), ' ')
    .trim();

/// A clock hour was said ("আটটায়", "৮.৩০"), not only "সকালে".
bool saysClock(String s) => withoutClockWords(s) != ' ${_tf(s)} '.trim() || RegExp(r'[০-৯0-9]{1,2}\s*[:.]\s*[০-৯0-9]{2}').hasMatch(s) || RegExp(fold(r'(?:মিনিট|ঘণ্টা|ঘন্টা)')).hasMatch(fold(s));
