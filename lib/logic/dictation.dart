/// Long speech said in several breaths: what an answer to "আর কিছু বলতে
/// চান?" means, and when a spoken piece ends the speech.
library;

import 'parser.dart' show normalize, words;

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

/// A piece said while collecting that ends the speech by itself ("বলা শেষ",
/// "এইটুকুই", "পাঠাও") — a bare "না" inside the speech does not.
bool endsSpeech(String said) {
  final t = _n(said);
  const ends = ['বলা শেষ', 'আমার বলা শেষ', 'এইটুকুই', 'এটুকুই', 'এখন উত্তর দাও', 'পাঠাও', 'পাঠিয়ে দাও', 'শেষ'];
  return ends.map(_n).contains(t);
}

/// The whole speech from its pieces, in order (a piece said twice on
/// purpose stays twice).
String assemble(List<String> pieces) => pieces.map((p) => p.trim()).where((p) => p.isNotEmpty).join(' ');

/// Rough size check: very long speech is handled in parts by the caller.
int wordCount(String s) => words(_n(s)).length;
