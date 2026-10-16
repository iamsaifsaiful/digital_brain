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
