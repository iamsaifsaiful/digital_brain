import 'bn.dart' show bnMonths, fixMonthSpellings;
import 'parser.dart';

// How a sentence is meant, judged from its parts — who does what to whom,
// whether it is said in the negative, whether the speaker corrected
// themself — instead of from single keywords. Every function takes text
// already passed through [normalize] unless it says otherwise.

String _n(String s) => normalize(s);
bool _hasWord(List<String> w, Iterable<String> keys) => keys.map(_n).any(w.contains);
bool _hasPhrase(String text, Iterable<String> keys) => keys.any((k) => (' $text ').contains(' ${_n(k)} '));

// ───────────────────────── Negation ─────────────────────────

/// A request said in the negative: "মুছে দিও না", "রিমাইন্ডার বন্ধ কোরো
/// না", "ফোন দিয়ো না", "এটা রেখো না". Nothing is to be done. Only request
/// forms count — "আমি জানি না" or "টাকা দেয়নি" are statements.
bool negatedRequest(String text) {
  final w = words(text);
  if (w.length < 2) return _joinedNegative.contains(w.isEmpty ? '' : w.first);
  // The negative must belong to the request itself, at the end ("দেরি
  // কোরো না, কাল ১০টায় মনে করিয়ে দিও" is a request, not a refusal).
  final tail = w.length - 3;
  for (var i = 0; i + 1 < w.length; i++) {
    final next = w[i + 1];
    if (next != _n('না') && next != _n('নাহ') && next != 'na') continue;
    if (i + 1 >= tail && _requestVerbs.contains(w[i])) return true;
  }
  for (var i = w.length - 2; i < w.length; i++) {
    if (i >= 0 && _joinedNegative.contains(w[i])) return true;
  }
  return false;
}

/// Forms of "do it" said to the app (you-forms, now or later).
final Set<String> _requestVerbs = {
  for (final x in const [
    'করো', 'কোরো', 'কর', 'করিও', 'করিয়ো', 'করবে', 'করবা', 'করবেন', 'করবি', 'করেন', 'করুন',
    'দাও', 'দিও', 'দিয়ো', 'দিবে', 'দেবে', 'দিবা', 'দিবেন', 'দেবেন', 'দিস', 'দিবি', 'দিয়েন',
    'মুছো', 'মুছবে', 'মুছবা', 'মুছবেন', 'মুছিও', 'মুছিয়ো', 'ফেলো', 'ফেলবে', 'ফেলবা', 'ফেলিও', 'ফেলিয়ো',
    'রাখো', 'রেখো', 'রাখবে', 'রাখবা', 'রাখবেন', 'রাখিও',
    'পাঠাও', 'পাঠিও', 'পাঠিয়ো', 'পাঠাবে', 'পাঠাবা', 'পাঠাবেন',
    'খোলো', 'খুলো', 'খুলবে', 'খুলবা', 'বাজাও', 'বাজিও', 'বাজাবে', 'বাজাবা', 'জানিও', 'জানাবে', 'জানাবা',
    'লিখো', 'লেখো', 'লিখবে', 'লিখবা', 'ফোন', 'ডিলিট', 'বাতিল', 'বন্ধ',
  ])
    _n(x),
};
final Set<String> _joinedNegative = {
  for (final x in const ['কোরোনা', 'দিওনা', 'দিয়োনা', 'মুছোনা', 'রেখোনা', 'রাখোনা', 'ফেলোনা', 'পাঠিওনা', 'মুছিওনা', 'করিওনা']) _n(x),
};

/// "শেষ হয়নি", "এখনো করা হয়নি", "কিনিনি": something is still not done.
bool saysNotDone(String text) => _hasPhrase(text, _notDone) || words(text).any((x) => _notDoneWords.contains(x));

const _notDone = [
  'হয় নি', 'হয় নাই', 'হয়নি এখনো', 'হলো না', 'হল না', 'হয়নি', 'হয়নাই', 'করা হয়নি', 'করি নাই', 'করি নি', 'শেষ হয়নি', 'শেষ হয় নি',
  'শেষ হয় নাই', 'এখনো বাকি', 'এখনও বাকি', 'এখনো হয়নি', 'এখনও হয়নি', 'শেষ করিনি', 'শেষ করি নাই',
];
final Set<String> _notDoneWords = {for (final x in const ['হয়নি', 'হয়নাই', 'করিনি', 'কিনিনি', 'যাইনি', 'আনিনি', 'দিইনি', 'সারিনি']) _n(x)};

// ───────────────────────── "পাঁচশ, না সাতশ" ─────────────────────────

final Set<String> _changeMind = {for (final x in const ['না', 'নাহ', 'উহু', 'উঁহু', 'সরি', 'sorry', 'মানে', 'নাহ্']) _n(x)};
final Set<String> _scale = {for (final x in const ['হাজার', 'লাখ', 'লক্ষ', 'কোটি', 'শ', 'শো', 'শত', 'সাড়ে', 'দেড়', 'আড়াই']) _n(x)};
final Set<String> _money = {for (final x in const ['টাকা', 'টাকার', 'tk', 'taka']) _n(x)};

bool _timeWord(String x) => RegExp(fold(r'^\d{1,2}(?:[:.]\d{2})?(?:টা|টায়|টার|টাতে)?$')).hasMatch(x) || RegExp(fold(r'^(এক|দুই|দু|তিন|চার|পাঁচ|পাচ|ছয়|ছ|সাত|আট|নয়|দশ|এগারো|এগার|বারো|বার)(টা|টায়|টার|টাতে)$')).hasMatch(x);
bool _valueWord(String x) => findAmount(x) != null || _scale.contains(x) || _timeWord(x);

/// The sentence with a change of mind applied: "রহিমকে পাঁচশ টাকা, না
/// সাতশ টাকা দিলাম" → "রহিমকে সাতশ টাকা দিলাম"; "দশটায়, না এগারোটায়" →
/// "এগারোটায়". Unchanged when there is no such correction.
String applySelfCorrection(String text) {
  var w = words(text);
  for (var guard = 0; guard < 4; guard++) {
    var changed = false;
    for (var i = 1; i + 1 < w.length; i++) {
      if (!_changeMind.contains(w[i])) continue;
      // The value said after: one or more value words.
      var j = i + 1;
      if (j < w.length && _changeMind.contains(w[j])) j++;
      if (j >= w.length || !_valueWord(w[j])) continue;
      // The value said before (its unit "টাকা" may follow it).
      var end = i;
      if (_money.contains(w[end - 1])) end--;
      var start = end;
      while (start > 0 && _valueWord(w[start - 1])) {
        start--;
      }
      if (start == end) continue;
      // Same kind of value on both sides: an amount and an amount, or a time and a time.
      final beforeTime = w.sublist(start, end).any(_timeWord);
      final afterTime = _timeWord(w[j]);
      if (beforeTime != afterTime) continue;
      final keepUnit = end < i && !_money.contains(w.length > j + 1 ? w[j + 1] : '');
      w = [...w.sublist(0, start), ...w.sublist(j, _endOfValue(w, j)), if (keepUnit) w[end], ...w.sublist(_endOfValue(w, j))];
      changed = true;
      break;
    }
    if (!changed) break;
  }
  return w.join(' ');
}

int _endOfValue(List<String> w, int from) {
  var k = from;
  while (k < w.length && _valueWord(w[k])) {
    k++;
  }
  return k;
}

// ───────────────────────── Questions about money owed ─────────────────────────

/// Whether a money question asks what others owe the user (true), what the
/// user owes (false), or is unclear (null). Judged by who receives in the
/// sentence: "আমি পাই / আমার পাওনা / কে আমাকে দেবে / কে নিয়েছে" are money
/// coming to the user; "কে আমার কাছে পাবে / আমাকে শোধ করতে হবে / আমার
/// দেনা / আমি কার কাছে ঋণী" are money the user must pay.
bool? owedToMe(String text) {
  final w = words(text);
  bool any(Iterable<String> ks) => _hasWord(w, ks);
  var mine = 0, theirs = 0;
  final me = any(['আমি', 'আমার', 'আমাকে', 'আমারে']);
  // "get": I get (পাই, পাবো) / someone else gets from me (পাবে, পায়).
  if (any(['পাই', 'পাব', 'পাবো', 'পামু'])) mine++;
  if (any(['পাবে', 'পায়', 'পান', 'পাবেন', 'পাবা'])) theirs++;
  // "give": someone will give / has not given (to me) / I must give.
  final theyGive = any(['দেবে', 'দিবে', 'দেবেন', 'দিবেন', 'দেয়নি', 'দেয়নাই', 'দেননি', 'দিচ্ছে না']) || _hasPhrase(text, ['দেয় নি', 'দেয় নাই', 'দেয়নি এখনো']);
  if (theyGive && !text.contains(_n('কাকে'))) mine++;
  final iGive = any(['দেব', 'দেবো', 'দিব', 'দিবো', 'দিমু']) ||
      _hasPhrase(text, ['দিতে হবে', 'শোধ করতে হবে', 'ফেরত দিতে হবে', 'শোধ দিতে হবে', 'দেওয়া লাগবে', 'দিতে লাগবে', 'দিতে বাকি', 'শোধ করা বাকি']);
  if (iGive) theirs++;
  // "take": others took (from me) / I took (from others).
  if (any(['নিয়েছে', 'নিল', 'নিলো', 'নিছে', 'নিয়েছেন', 'নিলেন', 'নিয়েছিল']) && !any(['আমি'])) mine++;
  if (any(['নিয়েছি', 'নিলাম', 'নিছি', 'নিয়েছিলাম'])) theirs++;
  // Nouns: পাওনা is mine unless "কে আমার কাছে পাওনা" (someone is owed by me).
  if (any(['পাওনা', 'পাওনাদার'])) {
    if (_hasPhrase(text, ['আমার কাছে']) && any(['কে', 'কারা', 'কার'])) {
      theirs++;
    } else {
      mine++;
    }
  }
  if (any(['দেনা', 'ঋণ', 'ঋণী', 'দেনাদার'])) theirs++;
  // "মানুষের কাছে আমার কত টাকা আছে / পড়ে আছে / আটকে আছে".
  if (_hasPhrase(text, ['কাছে আমার']) && any(['আছে', 'পড়ে', 'আটকে', 'রয়েছে', 'রয়ে'])) mine++;
  if (_hasPhrase(text, ['বাজারে আমার', 'বাইরে আমার'])) mine++;
  if (!me && mine == 0 && theirs == 0) return null;
  if (mine > 0 && theirs == 0) return true;
  if (theirs > 0 && mine == 0) return false;
  return null;
}

/// Who does the verbs of a sentence: the speaker ("দিলাম", "নিয়েছি",
/// "শোধ করেছি"), someone else ("দিল", "দিয়েছে", "শোধ করেছে"), both, or
/// neither. Judged word by word — "দিলাম" is never read as "দিল".
({bool me, bool other}) verbPerson(String text) {
  var me = false, other = false;
  for (final x in words(text)) {
    if (_firstPerson.contains(x) || RegExp(fold(r'(লাম|লুম|য়েছি|েছি|ছিলাম|য়েছিলাম)$')).hasMatch(x)) me = true;
    if (_thirdPerson.contains(x) || RegExp(fold(r'(য়েছে|েছে|য়েছেন|েছেন|লেন|ছিল)$')).hasMatch(x)) other = true;
  }
  return (me: me, other: other);
}

final Set<String> _firstPerson = {for (final x in const ['দিছি', 'নিছি', 'পাইছি', 'করছি', 'করসি', 'দিসি', 'নিসি']) _n(x)};
final Set<String> _thirdPerson = {for (final x in const ['দিল', 'দিলো', 'নিল', 'নিলো', 'করল', 'করলো', 'দিছে', 'নিছে', 'করছে', 'দিসে', 'দিয়ে গেল', 'দিয়ে গেছে']) _n(x)};

/// A question about money between the user and others, of any wording.
bool asksAboutOwing(String text) {
  final w = words(text);
  final money = _hasWord(w, ['টাকা', 'পাওনা', 'দেনা', 'ঋণ', 'ঋণী', 'ধার', 'বাকি', 'হিসাব', 'লেনদেন', 'পাওনাদার', 'দেনাদার']);
  final ask = _hasWord(w, ['কত', 'কে', 'কারা', 'কার', 'কাকে', 'কোন', 'কতজন', 'কয়জন', 'কয়জনের']);
  return ask && (money || owedToMe(text) != null) && (owedToMe(text) != null || _hasWord(w, ['পাওনা', 'দেনা', 'ধার', 'বাকি', 'ঋণ']));
}

// ───────────────────────── Follow-ups ─────────────────────────

/// "এখন মোট কত?", "সব মিলিয়ে কত হলো?", "টোটাল কত?": a total, of whatever
/// was being talked about.
bool asksTotal(String text) {
  final w = words(text);
  if (w.length > 7) return false;
  final total = _hasWord(w, ['মোট', 'টোটাল', 'total', 'সবমিলিয়ে']) || _hasPhrase(text, ['সব মিলিয়ে', 'সব মিলে', 'এখন কত', 'কত দাঁড়াল', 'কত দাঁড়ালো', 'কত হলো', 'কত হল', 'কত হয়েছে']);
  return total && _hasWord(w, ['কত', 'কতো', 'কি', 'কী']);
}

/// Words for someone just talked about: ("ও", "সে", "উনি") as the doer,
/// ("ওকে", "তাকে", "উনাকে") as the one given to, ("ওর", "তার", "উনার") as
/// the owner. [first] true when "ও" may be read as a person (at the start).
enum PronounRole { doer, to, of }

PronounRole? pronounRole(String word, {required bool first}) {
  final w = _n(word);
  if (first && w == _n('ও')) return PronounRole.doer;
  if ({'সে', 'উনি', 'ওনি', 'তিনি', 'হে', 'হেতে'}.map(_n).contains(w)) return PronounRole.doer;
  if ({'ওকে', 'তাকে', 'উনাকে', 'ওনাকে', 'তাঁকে', 'ওরে', 'তারে', 'হেরে'}.map(_n).contains(w)) return PronounRole.to;
  if ({'ওর', 'তার', 'উনার', 'ওনার', 'তাঁর', 'ওনাদের'}.map(_n).contains(w)) return PronounRole.of;
  return null;
}

/// What a command is, in one line, for the diagnostic trace (never a
/// password or a vault secret).
String traceLine(Command c) => switch (c) {
      LedgerAdd(:final person, :final amount, :final kind) => 'লেনদেন যোগ: $person, $amount, ${kind?.name ?? 'ধরন জিজ্ঞেস'}',
      LedgerQuery(:final ask, :final person) => 'লেনদেনের প্রশ্ন: ${ask.name}${person == null ? '' : ', $person'}',
      MoneyListQuery(:final label, :final category, :final person) => 'লেনদেনের তালিকা: $label${category == null ? '' : ', খাত $category'}${person == null ? '' : ', $person'}',
      Clarify(:final question) => 'জিজ্ঞেস: $question',
      CashAdd(:final kind, :final amount, :final category) => 'আয়-খরচ যোগ: ${kind.name}, $amount, $category',
      CashQuery() => 'আয়-খরচের প্রশ্ন',
      ReminderAdd(:final title, :final at) => 'রিমাইন্ডার: $title, $at',
      TaskAdd(:final title) => 'কাজ: $title',
      TaskDone(:final done) => 'কাজ ${done ? 'শেষ' : 'বাকি'}',
      VaultAdd(:final name) => 'পাসওয়ার্ড রাখা: $name',
      VaultQuery() => 'পাসওয়ার্ড খোঁজা',
      SearchQuery(:final terms) => 'খোঁজা: ${terms.join(' ')}',
      SmallTalk(:final kind) => 'কথা: ${kind.name}',
      ManageItem(:final action) => 'বদল/মোছা: $action',
      _ => c.runtimeType.toString(),
    };

/// Which of the listed items ("১. ইসমাইল — ৫,০০০ টাকা", "২. বলতে চাই না")
/// a reply points at: by number ("২ নম্বরটা", "দ্বিতীয়টা", "শেষেরটা") or
/// by repeating its words ("বলতে চাই না এটা রাখার মত কিছু না" → item 2).
/// Empty when the reply names none, or names them all equally.
List<int> mentionedItems(String said, List<String> lines) {
  final t = _n(said);
  if (lines.isEmpty || t.isEmpty) return const [];
  final picked = <int>{};
  const ordinals = [
    ['প্রথম', 'এক নম্বর', '১ নম্বর', '1 নম্বর', 'এক নং', '১ নং'],
    ['দ্বিতীয়', 'দুই নম্বর', '২ নম্বর', '2 নম্বর', 'দুই নং', '২ নং'],
    ['তৃতীয়', 'তিন নম্বর', '৩ নম্বর', '3 নম্বর', 'তিন নং', '৩ নং'],
    ['চতুর্থ', 'চার নম্বর', '৪ নম্বর', '4 নম্বর', 'চার নং', '৪ নং'],
    ['পঞ্চম', 'পাঁচ নম্বর', '৫ নম্বর', '5 নম্বর', 'পাঁচ নং', '৫ নং'],
  ];
  for (var i = 0; i < lines.length && i < ordinals.length; i++) {
    if (ordinals[i].any((o) => t.contains(_n(o)))) picked.add(i);
  }
  if (RegExp(fold(r'শেষের(?:টা|টি)|শেষটা|সবশেষের|লাস্টের')).hasMatch(t)) picked.add(lines.length - 1);
  if (picked.isNotEmpty) return picked.toList()..sort();
  // By their words: the item whose own words the reply repeats most.
  const common = {'টাকা', 'লেনদেন', 'কাজ', 'নোট', 'রিমাইন্ডার', 'খরচ', 'আয়', 'আজ', 'আজকে', 'কাল', 'আর', 'এটা', 'ওটা', 'টা', 'না', 'হ্যাঁ'};
  // Compared by stem: "সজীবের" / "সজীবকে", "মিটিংটা" / "মিটিং".
  String stem(String w) {
    final m = RegExp(fold(r'^(.{2,}?)(?:কেও|কে|দের|এর|ের|রে|টার|টা|টি|র)$')).firstMatch(w);
    return m == null ? w : m.group(1)!;
  }
  final commonN = common.map(_n).toSet();
  final mine = words(t).map(stem).toSet();
  final scores = <int>[
    for (final l in lines)
      words(_n(l.replaceAll(RegExp(r'[—–:-]'), ' '))).where((w) => w.length > 1 && !RegExp(r'^\d').hasMatch(w) && !commonN.contains(w)).map(stem).toSet().where(mine.contains).length,
  ];
  final best = scores.fold(0, (a, b) => b > a ? b : a);
  final top = [for (var i = 0; i < scores.length; i++) if (scores[i] == best) i];
  // Two shared words, or one that only a single item has.
  if (best == 0 || (best == 1 && top.length > 1)) return const [];
  return top.length == lines.length ? const [] : top;
}

/// A reply about listed items that says "not this one": "না", "বাদ",
/// "রেখো না", "লাগবে না", "রাখার মত কিছু না".
bool dropsItem(String said) {
  final t = _n(said);
  return RegExp(fold(r'(?:^|\s)(?:না|নাহ|নয়|বাদ|বাতিল|মুছে|লাগবে না|দরকার নেই|দরকার নাই|রেখো না|রাখবে না|রাখবেন না|রাখার মত(?:ো)? কিছু না|ভুল)(?:\s|$)')).hasMatch(t) || t.endsWith(_n('রাখার মত কিছু')) || t.endsWith(_n('রাখার মতো কিছু'));
}

/// "শুধু ১ নম্বরটা রাখো": keep only the named ones.
bool keepsOnly(String said) => RegExp(fold(r'(?:^|\s)(?:শুধু|কেবল|শুধুমাত্র)(?:\s|$)')).hasMatch(_n(said));

/// "রেখো না", "লিখো না", "সেভ কোরো না": a plain refusal of what is waiting
/// to be saved — never a name or a correction ("না, রেখো" is not a person).
bool refusesSave(String said) => RegExp(fold(r'(?:^|\s)(?:রেখো|রেখ|রাখো|রাখবে|রাখবেন|রাখিস|লিখো|লিখ|লিখবে|লিখবেন|সেভ\s+(?:কোরো|করো|করবেন))\s+না(?:\s|$)')).hasMatch(_n(said));

/// How people start and end a request when they talk to someone, which is
/// not part of the request: "ইয়ার তুমি একটা কাজ করো তো …", "আমাকে বলো
/// যে …", "যেটা হলো …", "… একটু বলতো", "… আরকি". Also everyday forms of
/// day words ("আগামীকালকে" → "কাল") and "আরবি কত তারিখ" (the Hijri date).
/// The words in between are left exactly as said.
String tidySpeech(String said, {List<bool>? whole}) {
  var s = fold(said.trim());
  // "সব গুলো", "কত গুলো", "জন্মদিনের গুলো": the plural ending never stands
  // alone — speech-to-text splits it off. Joined back, so every rule reads
  // "সবগুলো" / "কতগুলো" the one way.
  s = s.replaceAllMapped(RegExp(fold(r'([^\s,।?!])\s+(গুলো|গুলা|গুলি|গুলোর|গুলার|গুলোকে|গুলোতে|গুলোও|গুলোই)(?=$|[\s,।?!])')), (m) => '${m[1]}${m[2]}');
  // "৯ টায়", "১১ টা": the clock ending written apart is joined ("৯টায়").
  s = s.replaceAllMapped(RegExp(fold(r'([০-৯0-9])\s+(টায়|টা|টার|টাতে|টে|টার\s+দিকে)(?=$|[\s,।?!])')), (m) => '${m[1]}${m[2]}');
  // Regional and mixed-language words, as standard Bengali (whole words).
  s = _everydayWords(s);
  // "সকল", "সমস্ত" are "সব" ("আমার কাজের সকল তালিকা দেখাও").
  s = s.replaceAllMapped(RegExp(fold(r'(^|[\s,।])(?:সকল|সমস্ত)(?=$|[\s,।?!])')), (m) => '${m[1]}${fold('সব')}');
  // "আয় ব্যয়ের", "আয়-খরচের", "ইনকাম খরচ": one word, read the one way.
  s = s.replaceAllMapped(RegExp(fold(r'(^|[\s,।])(?:আয়|ইনকাম)\s*[-–]?\s*(?:ব্যয়|খরচ|ব্যয়)(?:ের|এর|র)?(?=$|[\s,।?!])')), (m) => '${m[1]}${fold('আয়-ব্যয়')}');
  // Day words in their everyday forms.
  s = s.replaceAllMapped(RegExp(fold(r'(^|[\s,।])(?:আগামী\s*কাল(?:কে|কের|ের)?|আগামীকাল(?:কে|কের|ের)?|কালকের)(?=$|[\s,।?!])')), (m) => '${m[1]}কাল');
  s = s.replaceAllMapped(RegExp(fold(r'(^|[\s,।])পরশু\s*দিন(?:কে|ের)?(?=$|[\s,।?!])')), (m) => '${m[1]}পরশু');
  s = s.replaceAllMapped(RegExp(fold(r'(^|[\s,।])আজকের(?=$|[\s,।?!])')), (m) => '${m[1]}আজ');
  s = s.replaceAll(RegExp(fold(r'কাজে\s+(?=তালিকা|লিস্ট)')), fold('কাজের '));
  s = s.replaceAll(RegExp(fold(r'আরব[িী]\s+(?:মাসের\s+)?কত\s+তারিখ\S*')), fold('আরবি তারিখ'));
  // Dates as people say them: "৩১ শে অক্টোবর" → "৩১ অক্টোবর", "অক্টোবরের" →
  // "অক্টোবর", "জানুয়ারি মাসের প্রথম তারিখে" → "১ জানুয়ারি", "২৭ সালের" dropped.
  // One spelling of each month ("ফেব্রুয়ারী" = "ফেব্রুয়ারি", "আগষ্ট" =
  // "আগস্ট"), its ending kept: every date rule after this knows it.
  s = fixMonthSpellings(s);
  final months = bnMonths.map(fold).join('|');
  // "বাইশ তারিখে", "পঁচিশে ডিসেম্বর": a day of the month said as a word is
  // the same date as "২২ তারিখে" — written as a number so every date rule
  // after this (and the parser) reads it.
  s = s.replaceAllMapped(RegExp('(^|[\\s,।])(${_dayWords.keys.map(fold).join('|')})(?:${fold('শে')}|${fold('ে')}|${fold('এ')})?(?=\\s+(?:${fold('তারিখ')}|$months))'),
      (m) => '${m[1]}${_bnNum(_dayWords[_dayWordsFolded[m[2]]]!)}');
  s = s.replaceAllMapped(RegExp(fold(r'([০-৯0-9]{1,2})\s*(?:শে|ই|লা|রা|ঠা)(?=$|[\s,।])')), (m) => m[1]!);
  // (A month only as a word of its own: "মে" inside "রহিমের" is not May.)
  s = s.replaceAllMapped(RegExp('(?<=^|[\\s,।(])($months)(?:\\s*${fold('এর')}|${fold('ের')}|${fold('তে')}|${fold('ে')}|${fold('র')}|${fold('তেই')})(?=\$|[\\s,।])'), (m) => m[1]!);
  s = s.replaceAllMapped(RegExp('($months)\\s+${fold('মাসের')}\\s+(?:${fold('প্রথম')}|${fold('পহেলা')}|${fold('এক')})\\s+${fold('তারিখ')}\\S*'), (m) => '১ ${m[1]}');
  s = s.replaceAllMapped(RegExp('($months)\\s+(?:${fold('মাসের')}|${fold('মাসে')}|${fold('মাসেই')})\\s+([০-৯0-9]{1,2})\\s+${fold('তারিখ')}\\S*'), (m) => '${m[2]} ${m[1]}');
  // "ডিসেম্বরের ৬ তারিখে" (the "-এর" already gone): "৬ ডিসেম্বর", not the 6th of this month.
  s = s.replaceAllMapped(RegExp('(^|[\\s,।])($months)\\s+([০-৯0-9]{1,2})\\s+${fold('তারিখ')}\\S*'), (m) => '${m[1]}${m[3]} ${m[2]}');
  // "৩১ ডিসেম্বর ২০২৭ সালের", "২০২৭ সালের ৫ জানুয়ারি": one form, the year
  // kept right after the date ("৫ জানুয়ারি ২০২৭") — a year said is never
  // lost. A spoken year ("দুই হাজার সাতাশ") is still dropped.
  s = s.replaceAllMapped(RegExp('($months)\\s+([০-৯0-9]{4})\\s+${fold('সাল')}(?:${fold('ের')}|${fold('ে')}|)(?=\\s|\$)'), (m) => '${m[1]} ${m[2]}');
  s = s.replaceAllMapped(RegExp('($months)\\s+(?:[০-৯0-9]{2}|${fold('দুই')}\\s+${fold('হাজার')}\\s+\\S+)\\s+${fold('সাল')}(?:${fold('ের')}|${fold('ে')}|)\\s+'), (m) => '${m[1]} ');
  s = s.replaceAllMapped(RegExp('([০-৯0-9]{4})\\s+${fold('সাল')}(?:${fold('ের')}|${fold('ে')}|)\\s+([০-৯0-9]{1,2}\\s+(?:$months))(?=\\s|\$|[,।])'), (m) => '${m[2]} ${m[1]}');
  s = s.replaceAll(RegExp('(?:[০-৯0-9]{2}|${fold('দুই')}\\s+${fold('হাজার')}\\s+\\S+)\\s+${fold('সাল')}(?:${fold('ের')}|${fold('ে')}|)\\s+(?=[০-৯0-9]{1,2}\\s+(?:$months))'), '');
  // "৩১ অক্টোবরের জন্য", "আমার জন্য একটা রিমাইন্ডার": "for" carries nothing here.
  s = s.replaceAllMapped(RegExp('($months)\\s+${fold('জন্য')}\\S*'), (m) => m[1]!);
  s = s.replaceAll(RegExp(fold(r'(?:(?:তুমি|আপনি)\s+)?আমার\s+জন্য\S*\s+(?=(?:একটা|একটি|এক|রিমাইন্ডার|অ্যালার্ম|এলার্ম))')), '');
  // Hesitations ("ইয়া", "ইয়ে", "উম") and "in our contacts" carry nothing.
  s = s.replaceAll(RegExp(fold(r'(?:^|(?<=[\s,।]))(?:ইয়া|ইয়ে|উম|উমম|আঁ|অ্যা)(?=$|[\s,।])')), ' ');
  s = s.replaceAll(RegExp(fold(r'(?:আমাদের|আমার)\s+(?:যোগাযোগ|কন্টাক্ট|কনট্যাক্ট)(?:ের|এর|ে)?\s+(?:নাম্বারে|নম্বরে|লিস্টে|তালিকায়|থেকে|এ)?')), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  final lead = RegExp(fold(
    r'^(?:'
    r'(?:এই(?![\s,।]+(?:সপ্তাহ|মাস|বছর|শুক্র|শনি|রবি|সোম|মঙ্গল|বুধ|বৃহস্পতি|কাজ|তারিখ|দিন|বার|মাত্র|লিস্ট|তালিকা|রিমাইন্ডার))|ইয়া|ইয়ার|ইয়ার|আরে|ওই(?![\s,।]+(?:সপ্তাহ|মাস|বছর|কাজ|দিন|তারিখ))|ওই যে|শোনো|শোন|শুনো|শুনেন|শুনুন|হ্যালো|hello|ভাই|আচ্ছা|ঠিক আছে|তাহলে|মানে|বললাম|তারপরে|তারপর|এরপরে|এরপর|দেখো তো|দেখতো|দেখ তো)'
    r'|(?:তুমি\s+|আপনি\s+)?(?:এক|একটা|একটি)\s+কাজ\s+(?:করো|কর|করেন|করুন|করবা|করবে)(?:\s+তো)?'
    r'|(?:আমি\s+)?(?:তোমাকে|তোমারে|আপনাকে)\s+(?:বলতেছি|বলছি|বলতেছিলাম|বলছিলাম|বললাম)(?:\s+যে)?'
    r'|আমি\s+(?:বললাম|বলতেছি|বলছি)(?:\s+যে)?'
    r'|কাজ\s+(?:করো|কর)\s+(?:তো\s+)?যে'
    r'|(?:আমাকে\s+)?(?:একটু\s+)?(?:বলো|বল|বলেন|বলুন|জানাও)(?:\s+তো)?\s+যে'
    r'|যেটা\s+(?:হলো|হল|হইলো)'
    r')(?=$|[\s,।])[\s,।]*'));
  for (var i = 0; i < 6; i++) {
    final m = lead.firstMatch(s);
    if (m == null) break;
    if (m.end >= s.length) {
      // Only the opening words so far ("তুমি একটা কাজ করো"): the request is still to come.
      if (whole != null) whole[0] = true;
      break;
    }
    s = s.substring(m.end);
  }
  final tail = RegExp(fold(r'[\s,।]+(?:আরকি|আর কি|(?:একটু\s+)?(?:বলতো|বলো তো|বল তো|বলেন তো|বলবা|জানাও তো))[\s,।?!]*$'));
  final t = tail.firstMatch(s);
  if (t != null && t.start > 0) s = s.substring(0, t.start);
  return s.trim();
}

/// Said to the assistant about how it should behave, or about how it is
/// doing — not data to keep: "আমি কথা বললে তুমি থেমে শুনবা", "তুমি কি
/// আমার কথা বুঝতেছো?", "এটা বাজে হচ্ছে, প্রফেশনাল না".
enum AboutMe { listenWhenITalk, doYouUnderstand, complaint }

AboutMe? aboutTheAssistant(String said) {
  final t = _n(said);
  bool has(String p) => RegExp(fold(p)).hasMatch(t);
  final toYou = has(r'(?:^|\s)(?:তুমি|তোমার|তোমাকে|তুই|তোর|আপনি|আপনার)(?:\s|$)');
  if (toYou && has(r'(?:কথা\s+বন্ধ|চুপ\s+(?:হয়ে|হইয়া|কর|করে|থাক)|থেমে|থামবা|থামবে|থামো)') && has(r'(?:শুনবা|শুনবে|শুনবেন|শুনো|শোনো|শুনতে|মনোযোগ|কথা\s+বলি|কথা\s+বললে|বলবো|বলব|বললে)')) {
    return AboutMe.listenWhenITalk;
  }
  if (toYou && has(r'(?:বুঝতেছো|বুঝতেছ|বুঝতেছেন|বুঝছো|বুঝছ|বুঝতে\s+পারছ|বুঝতে\s+পারছো|বুঝতে\s+পারছেন|বুঝো|বুঝেন)') && !has(r'(?:না\s+বুঝে|বুঝো\s+না|বুঝ না|বুঝতেছো\s+না|বোঝো\s+না)')) {
    return AboutMe.doYouUnderstand;
  }
  if (has(r'(?:প্রফেশনাল|প্রোফেশনাল)\s+(?:কিছু\s+)?(?:না|নয়|হইতেছে না|হচ্ছে না|হতে পারে না)') || has(r'(?:একদম|খুবই|খুব|অনেক|কি|কী)\s+বাজে(?:\s|$)') || has(r'বাজে\s+(?:হইছে|হচ্ছে|হইতেছে|হয়েছে|লাগে|লাগতেছে|লাগছে|কাজ)') ||
      has(r'(?:কিছুই|কিছু)\s+(?:বুঝো|বোঝো|বুঝতেছো|বুঝতেছ|বোঝ)\s+না') || has(r'না\s+বুঝে') || has(r'বিরক্তিকর') || (toYou && has(r'কেন\s+(?:দিতেছ|দিতেছো|দিচ্ছ|দিচ্ছো|দিলা|দিলে|করতেছ|করছ|করলা)')) || has(r'(?:আজকের\s+)?কথা\s+বলি\s*(?:নাই|নি)') || has(r'(?:জিজ্ঞেস|জিজ্ঞাসা|প্রশ্ন)\s*(?:করি|করলাম)\s*(?:নাই|নি|না)') || has(r'(?:চাই|চাইলাম|বললাম)\s*(?:নাই|নি)\s') || has(r'(?:দাও|দিলা|করো|করলা)\s+নাই') || has(r'(?:সমন্বয়|মিলিয়ে)\s+(?:করার\s+)?(?:চেষ্টা\s+)?(?:করবা|করবে|করো|কর)') || has(r'লক্ষ্য\s+রাখবা\s+না') || has(r'(?:আমার\s+)?পুরো\s+কথা\s+(?:শোনো|শুনো|শুনবা|শোন)') || has(r'(?:নির্দেশনা|কথা)\s+(?:দিতেছি|দিচ্ছি|বলতেছি|বলছি)\s+(?:তুমি|আর)') ||
      // "নির্দেশনা কি দিই, আর উত্তর কি দাও"
      (has(r'(?:নির্দেশনা|প্রশ্ন|কথা)\s+(?:কি|কী)\s+(?:দিই|দেই|দিচ্ছি|দিলাম|বলি|বললাম|বলছি|করি|করলাম)') && has(r'উত্তর\s+(?:কি|কী)\s+(?:দাও|দেও|দিচ্ছ|দিচ্ছো|দিলা|দিলে|দেন|দিচ্ছেন)')) ||
      // "তুমি ভুল বুঝেছো", "এখনো ঠিক করোনি", "তারিখটা ভুল হয়েছে".
      has(r'ভুল\s+(?:বুঝেছ|বুঝেছো|বুঝেছেন|বুঝছ|বুঝছো|বুঝলে|বুঝলা|বুঝেছ|করেছ|করেছো|করেছেন|করলে|করলা|হয়েছে|হয়েছে|হইছে|হলো|হল)') ||
      has(r'ঠিক\s*(?:বোঝোনি|বুঝোনি|বুঝনি|বোঝনি|করোনি|করো\s+নাই|করনি|করো\s+নি)') ||
      // "আগে তো আরো উন্নত ভাবে কাজ করতে", "এটা হলো কিছু?", "এমন মডিফাই
      // করলা, এখন কথাই বুঝে না" (19 Oct, 14:39).
      has(r'আগে\s+(?:তো\s+)?(?:আরো|আরও|অনেক)?\s*(?:উন্নত|ভালো|ভাল|ঠিকঠাক|সুন্দর)\S*\s+(?:ভাবে\s+)?(?:কাজ|বুঝ)') ||
      has(r'^\s*(?:এটা|এইটা|এটি|এগুলো)\s+(?:হলো|হল|হইলো|হইল)\s+(?:কিছু|কোনো\s+কাজ)') ||
      has(r'(?:কথাই|কিছুই|কিছু)\s+(?:বুঝে|বোঝে|বুঝতেছ|বুঝো|বোঝো)\s+না') || has(r'(?:মডিফাই|আপডেট|পরিবর্তন)\s+(?:করলা|করলে|করছো|করেছ|করে)\s*,?\s*(?:এখন|আর)') ||
      // "কি বলো?", "এটা কী বললা?" — the whole message.
      has(r'^\s*(?:এটা\s+|এসব\s+)?(?:কি|কী)\s+(?:বলো|বলছ|বলছো|বলতেছ|বলতেছো|বললা|বললে|বলেন|বলছেন|বলতেছেন)\s*$')) {
    return AboutMe.complaint;
  }
  return null;
}

/// Only the opening words of a request so far: "তুমি একটা কাজ করো", "যেটা হলো".
bool onlyOpening(String said) {
  final flag = [false];
  tidySpeech(said, whole: flag);
  return flag[0];
}

/// "এটা তো বলি নাই", "এটা আমি বলিনি": what is waiting is not what was said.
bool notWhatISaid(String said) => RegExp(fold(r'(?:^|\s)(?:বলি\s*নাই|বলি\s*নেই|বলি\s*নি|বলিনি|বলিনাই|বলি নাই|এটা\s+বলি\s+নাই|বলছি\s+না|কইনাই|কই নাই)(?:\s|$)')).hasMatch(_n(said));

/// "হ্যাঁ, কিন্তু শুধু লিখবা ওয়াইফাই বিল দিতে হবে — এত কিছু প্রয়োজন নাই":
/// the waiting item is right, only its words are to be shorter. Returns the
/// new words, or null.
String? onlyWrite(String said) {
  final s = fold(said.trim());
  final m = RegExp(fold(r'(?:শুধু|কেবল|খালি)\s+(?:তুমি\s+)?(?:লিখবা|লিখবে|লিখবেন|লেখো|লিখো|লিখ|লেখ|লিখে\s+রাখো|লিখে\s+রাখ|রাখবা|রাখো)\s+(?:যে\s+)?(.+)$')).firstMatch(s);
  if (m == null) return null;
  var t = m[1]!;
  t = t.replaceAll(RegExp(fold(r'[\s,।]*(?:এত|এতো|এত্ত)\s+কিছু.*$')), '');
  t = t.replaceAll(RegExp(r'[\s,।!.]+$'), '').trim();
  return t.isEmpty ? null : t;
}


/// The days of a month as said in words (1–31).
const _dayWords = {
  'এক': 1, 'দুই': 2, 'তিন': 3, 'চার': 4, 'পাঁচ': 5, 'ছয়': 6, 'সাত': 7, 'আট': 8, 'নয়': 9, 'দশ': 10,
  'এগারো': 11, 'বারো': 12, 'তেরো': 13, 'চৌদ্দ': 14, 'পনেরো': 15, 'পনের': 15, 'ষোলো': 16, 'ষোল': 16, 'সতেরো': 17, 'আঠারো': 18,
  'উনিশ': 19, 'ঊনিশ': 19, 'বিশ': 20, 'কুড়ি': 20, 'একুশ': 21, 'বাইশ': 22, 'তেইশ': 23, 'চব্বিশ': 24, 'পঁচিশ': 25, 'ছাব্বিশ': 26,
  'সাতাশ': 27, 'আটাশ': 28, 'উনত্রিশ': 29, 'ঊনত্রিশ': 29, 'ত্রিশ': 30, 'তিরিশ': 30, 'একত্রিশ': 31,
};
final Map<String, String> _dayWordsFolded = {for (final k in _dayWords.keys) fold(k): k};
String _bnNum(int n) => n.toString().split('').map((c) => '০১২৩৪৫৬৭৮৯'[int.parse(c)]).join();


/// "কামডা" → "কাজটা", "যাইতে অইব" → "যেতে হবে", "করমু" → "করব",
/// "task-টা tomorrow move করো" → "কাজটা কাল সরাও": the same meaning in
/// the words the rest of the app reads. Only whole words change, so names
/// stay as they are.
String _everydayWords(String s) {
  var t = s;
  // English inside Bengali speech.
  for (final (p, r) in [
    (r'\badd\s+(?:a|one|new)?\s*task\b', 'একটা কাজ যোগ করো'),
    (r'\btasks?\s*-?\s*(টা|টি|গুলো)', r'কাজ$1'),
    (r'\btasks?\b', 'কাজ'),
    (r'\bto-?do\s+list\b', 'কাজের তালিকা'),
    (r'\btomorrow\b', 'কাল'),
    (r'\btoday\b', 'আজ'),
    (r'\bmove\s*(?:কর(?:ো|ে\s+দাও|ুন|েন)?)', 'সরাও'),
    (r'\bdone\s*(?:কর(?:ো|ে\s+দাও|ুন|েন)?)', 'টিক দাও'),
    (r'\bdelete\s*(?:কর(?:ো|ে\s+দাও|ুন|েন)?)', 'মুছে দাও'),
    (r'\badd\s*(?:কর(?:ো|ে\s+দাও|ুন|েন))', 'যোগ করো'),
    (r'\boff\s*(?:কর(?:ো|ে\s+দাও|ুন|েন)?)', 'বন্ধ করো'),
    (r'\breminder\b', 'রিমাইন্ডার'),
  ]) {
    t = t.replaceAllMapped(RegExp(p, caseSensitive: false), (m) => r.contains(r'$1') ? r.replaceAll(r'$1', m[1] ?? '') : r);
  }
  const map = {
    'কাম': 'কাজ', 'কামডা': 'কাজটা', 'কামটা': 'কাজটা', 'কামগুলা': 'কাজগুলো', 'কামগুলো': 'কাজগুলো', 'কামের': 'কাজের',
    'অইব': 'হবে', 'অইবো': 'হবে', 'হইব': 'হবে', 'হইবো': 'হবে', 'অইবে': 'হবে', 'লাগব': 'লাগবে', 'লাগবো': 'লাগবে', 'লাগবু': 'লাগবে',
    'যাইতে': 'যেতে', 'খাইতে': 'খেতে', 'দিতাম': 'দিতে', 'নিতাম': 'নিতে',
    'করমু': 'করব', 'আনমু': 'আনব', 'যামু': 'যাব', 'খামু': 'খাব', 'দিমু': 'দেব', 'নিমু': 'নেব', 'কিনমু': 'কিনব', 'পাঠামু': 'পাঠাব',
    'হইয়া': 'হয়ে', 'হইয়্যা': 'হয়ে', 'অইয়া': 'হয়ে', 'অয়': 'হয়', 'অইছে': 'হয়েছে', 'হইছে': 'হয়েছে', 'হইসে': 'হয়েছে',
    'এইডা': 'এটা', 'ওইডা': 'ওটা', 'হেইডা': 'সেটা', 'হেডা': 'সেটা',
  };
  final folded = {for (final e in map.entries) fold(e.key): fold(e.value)};
  t = t.replaceAllMapped(RegExp(r'[^\s,।?!.]+'), (m) {
    final w = m[0]!;
    final r = folded[w];
    if (r != null) return r;
    // "বিলডা", "আগেরডা", "কামডা": the Dhaka "-ডা" is "-টা" (not "ঠান্ডা", "সোডা").
    if (w.length >= 4 && w.endsWith(fold('ডা')) && !RegExp(fold(r'(?:ন্|ণ্)ডা$')).hasMatch(w) && !const {'সোডা', 'ফোডা', 'কাডা'}.contains(w)) {
      return '${w.substring(0, w.length - 2)}টা';
    }
    return w;
  });
  return t;
}


/// "আমি দেনা পাওনা বলি নাই, বলেছি, অন্যান্য হিসাব" → "অন্যান্য হিসাব": a
/// correction of what was heard; only the words meant are left.
String meantInstead(String said) {
  final m = RegExp(fold(r'^.+?\s+(?:বলি\s*নাই|বলিনি|বলি\s+নি|বলিনাই|বলছি\s+না|বুঝাইনি|বোঝাইনি)\s*[,।;]?\s*(?:আমি\s+)?(?:বলেছি|বলছি|বলেছিলাম|বলতে\s+চেয়েছি|মানে|বুঝিয়েছি)\s*[,।:;]?\s*(.+)$')).firstMatch(fold(said));
  // "ব্যয়ে লিখতে বলি নাই, অন্যান্য হিসাবের বাড়ির মেরামত এ লিখ".
  final m2 = m ?? RegExp(fold(r'^.+?\s+(?:লিখতে|রাখতে|করতে|দিতে)\s+(?:বলি\s*নাই|বলিনি|বলি\s+নি|বলিনাই)\s*[,।;]\s*(.+)$')).firstMatch(fold(said));
  if (m2 == null) return said;
  final rest = m2[1]!.trim();
  return rest.split(RegExp(r'\s+')).length >= 2 ? rest : said;
}


