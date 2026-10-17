/// Long speech said in several breaths: what an answer to "আর কিছু বলতে
/// চান?" means, and when a spoken piece ends the speech.
library;

import 'meaning.dart' show onlyOpening;
import 'parser.dart' show fold, normalize, words;

enum Continue {
  /// "না", "এইটুকুই", "বলা শেষ": the speech is complete — act on all of it.
  finish,

  /// "হ্যাঁ", "জি", "আরও আছে": keep listening, nothing to add yet.
  more,

  /// New words to add ("হ্যাঁ, আর বাজারে ৭০০ খরচ" → "আর বাজারে ৭০০ খরচ").
  content,

  /// "বাতিল করো", "পুরোটা বাদ দাও": drop the whole speech.
  cancel,
}

String _n(String s) => normalize(s.replaceAll(RegExp(r'[।?!,.;:]'), ' ')).trim();

const _finishPhrases = [
  'না', 'নাহ', 'না না', 'না আর কিছু নেই', 'আর কিছু নেই', 'আর কিছু না', 'না আর না', 'এইটুকুই', 'এটুকুই', 'এই টুকুই', 'এতটুকুই', 'বলা শেষ', 'শেষ', 'আমার বলা শেষ', 'শেষ হয়েছে',
  'বলতে চাই না', 'না বলতে চাই না', 'আর বলতে চাই না', 'আর নেই', 'না আর নেই', 'এই পর্যন্ত', 'এই পর্যন্তই', 'আর কিছু বলব না', 'আর কিছু বলার নেই', 'কিছু বলার নেই',
  'এখন উত্তর দাও', 'উত্তর দাও', 'পাঠাও', 'পাঠিয়ে দাও', 'ঠিক আছে পাঠাও', 'না এইটুকুই', 'no', 'thats all', "that's all", 'done',
];
const _morePhrases = ['হ্যাঁ', 'হ্যা', 'হুম', 'জি', 'জ্বি', 'জি হ্যাঁ', 'আরও আছে', 'আরো আছে', 'আছে', 'আরও বলব', 'আরো বলব', 'আরও বলবো', 'আরো বলবো', 'একটু অপেক্ষা করো', 'অপেক্ষা করো', 'একটু থামো', 'দাঁড়াও', 'yes'];
const _cancelPhrases = ['বাতিল', 'বাতিল করো', 'বাতিল করুন', 'পুরোটা বাদ দাও', 'সব বাদ দাও', 'সবটা বাদ দাও', 'বাদ দাও', 'থাক', 'cancel'];
const _yesLead = ['হ্যাঁ', 'হ্যা', 'জি', 'জ্বি', 'আরও আছে', 'আরো আছে', 'আছে'];

/// The answer to "আর কিছু বলতে চান?". Only a whole answer counts as
/// control: "না, পাঁচশ নয় সাতশ হবে" is a correction (content), not "no".
(Continue, String) continuationOf(String said) {
  final t = _n(said);
  if (t.isEmpty) return (Continue.more, '');
  if (_finishPhrases.map(_n).contains(t)) return (Continue.finish, '');
  // "না, আর বলতে চাই না" / "আর কিছু বলার নেই".
  final (before, done) = splitDoneTail(said);
  if (done && (before.isEmpty || _finishPhrases.map(_n).contains(_n(before)))) return (Continue.finish, '');
  if (_cancelPhrases.map(_n).contains(t)) return (Continue.cancel, '');
  if (_morePhrases.map(_n).contains(t)) return (Continue.more, '');
  // "হ্যাঁ, আর কাল বাজারে ৭০০ টাকা খরচ" → the words after "হ্যাঁ".
  final raw = said.trim();
  for (final y in [..._yesLead]..sort((a, b) => b.length.compareTo(a.length))) {
    final m = RegExp('^${RegExp.escape(y)}[\\s,।]+', caseSensitive: false).firstMatch(raw);
    if (m != null) {
      final rest = raw.substring(m.end).trim();
      return rest.isEmpty ? (Continue.more, '') : (Continue.content, rest);
    }
  }
  // "না, আর কিছু নেই" → finish; "না, পাঁচশ নয় সাতশ হবে" → a correction to add.
  final no = RegExp(r'^না[\s,।]+').firstMatch(raw);
  if (no != null) {
    final rest = raw.substring(no.end).trim();
    if (rest.isEmpty || _finishPhrases.map(_n).contains(_n(rest))) return (Continue.finish, '');
    return (Continue.content, rest);
  }
  return (Continue.content, raw);
}

/// "আর বলতে চাই না", "আর কিছু বলার নেই", "এই পর্যন্তই" at the END of a
/// piece: the person is telling the app they are done talking — that is
/// not something to save. Returns the words before it and whether such an
/// ending was found. A leading "না" is part of it only when followed by
/// "আর" ("…দিলাম, না আর বলতে চাই না"); "দিলাম না" alone is left alone.
(String, bool) splitDoneTail(String said) {
  final raw = fold(said.trim());
  final m = _doneTail.firstMatch(raw);
  if (m == null) return (raw, false);
  final rest = raw.substring(0, m.start).replaceAll(RegExp(r'[\s,।;:—-]+$'), '').trim();
  return (rest, true);
}

const _verbs = r'(?:বলতে\s+চাই\s+না|বলতে\s+চাচ্ছি\s+না|বলব\s+না|বলবো\s+না|বলার\s+(?:নেই|নাই))';
const _lead = r'(?:না|নাহ|নারে|না\s+রে|ব্যস|ব্যাস|বাস|আচ্ছা|ঠিক আছে)(?:\s+ভাই)?';

final _doneTail = RegExp(fold(
  r'(?:^|[\s,।;:—-])'
  '(?:'
  // "(না,) আর কিছু বলতে চাই না", "নার কিছু বলতে চাই না" (না আর, run together)
  '(?:$_lead[\\s,।]+)?(?:আর|নার)\\s+(?:কিছু\\s+)?$_verbs'
  // "নারে ভাই, কিছু বলতে চাই না" — only with the "না" in front
  '|$_lead[\\s,।]+(?:কিছু\\s+)?$_verbs'
  r'|(?:(?:না|নাহ)[\s,।]+)?আর\s+কিছু\s+(?:নেই|নাই)'
  r'|(?:আমার\s+)?বলা\s+শেষ(?:\s+হয়েছে|\s+হইছে)?|আমার\s+কথা\s+শেষ'
  r'|এই\s*পর্যন্ত(?:ই)?|এইটুকুই|এটুকুই|এই\s+টুকুই|এতটুকুই'
  r'|ব্যস|ব্যাস'
  ')'
  r'[\s,।!.]*$'),
);

/// A piece said while collecting that ends the speech by itself ("বলা শেষ",
/// "এইটুকুই", "পাঠাও") — a bare "না" inside the speech does not.
bool endsSpeech(String said) {
  final t = _n(said);
  const ends = ['বলা শেষ', 'আমার বলা শেষ', 'এইটুকুই', 'এটুকুই', 'এখন উত্তর দাও', 'পাঠাও', 'পাঠিয়ে দাও', 'শেষ'];
  if (ends.map(_n).contains(t)) return true;
  final (before, done) = splitDoneTail(said);
  return done && before.isEmpty;
}

/// The whole speech from its pieces, in order (a piece said twice on
/// purpose stays twice).
String assemble(List<String> pieces) => pieces.map((p) => p.trim()).where((p) => p.isNotEmpty).join(' ');

/// Rough size check: very long speech is handled in parts by the caller.
int wordCount(String s) => words(_n(s)).length;

/// Speech the person has surely not finished: it ends on a joining word
/// ("…আর", "…তারপর", "…কিন্তু") or a word that needs more ("খরচ হচ্ছে
/// কোন", "…যদি"). Anything else is acted on when the person goes quiet —
/// nobody is asked "আর কিছু বলতে চান?" after a whole sentence.
bool leftOpen(String said) {
  final w = words(_n(said));
  if (w.isEmpty) return true;
  const open = ['আর', 'এবং', 'কিন্তু', 'যে', 'তারপর', 'এরপর', 'মানে', 'আবার', 'বা', 'অথবা', 'নাকি', 'যদি', 'তাহলে', 'যেমন', 'কোন', 'কোনো', 'কোনটা', 'আরও', 'আরো', 'and', 'but', 'or'];
  final last = w.last;
  if (open.map(_n).contains(last)) return true;
  // "তুমি একটা কাজ করো", "যেটা হলো": only the opening so far.
  if (onlyOpening(said)) return true;
  // "… আগামীকালকে সকাল দশটায় আমাকে": who / when said, the what still to come.
  const pending = ['আমাকে', 'আমারে', 'তোমাকে', 'আমার', 'তোমার', 'আমাদের', 'ওকে', 'তাকে', 'ওনাকে', 'কাল', 'কালকে', 'আগামীকাল', 'আগামীকালকে', 'আজ', 'আজকে', 'পরশু', 'সকাল', 'সকালে', 'বিকেলে', 'রাতে', 'দুপুরে', 'সন্ধ্যায়', 'হলো', 'হল', 'কাজ'];
  if (pending.map(_n).contains(last)) return true;
  if (RegExp(fold(r'টায়$')).hasMatch(last) && w.length <= 6) return true;
  if (w.length >= 2 && ['তার পর', 'এর পর'].map(_n).contains('${w[w.length - 2]} $last')) return true;
  return false;
}

/// The speech is over (quiet, "শেষ করেছি", "আর বলতে চাই না"): a joining
/// word left at the very end ("…ধার দিয়েছি আর") no longer means more is
/// coming, so it is dropped before the speech is understood.
String withoutOpenEnd(String said) {
  var t = said.trim();
  for (var i = 0; i < 3 && t.isNotEmpty && leftOpen(t); i++) {
    final cut = t.replaceFirst(RegExp(r'[\s,।]*\S+[\s,।]*$'), '').trim();
    if (cut.isEmpty) break;
    t = cut;
  }
  return t;
}
