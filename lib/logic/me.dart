/// Facts about the user and their family the assistant can answer from
/// the phone (blood group, allergies, illnesses), and "আমার কী কী ছবি আছে?"
/// — what kind of things are kept, not one thing by name.
library;

import '../models/models.dart';
import 'ask.dart' show askUserName;
import 'bn.dart';
import 'health.dart' show heightText, feetToCm;
import 'lang.dart';
import 'parser.dart';

/// As written on the emergency card (with a real minus sign).
const bloodGroups = ['A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−'];

/// "B+" → "বি পজিটিভ" (read aloud the Bangla way).
String bloodSpoken(String g) {
  if (g.isEmpty) return g;
  final neg = g.endsWith('−') || g.endsWith('-');
  final letter = g.substring(0, g.length - 1);
  final bn = const {'A': 'এ', 'B': 'বি', 'AB': 'এবি', 'O': 'ও'}[letter] ?? letter;
  if (isEn) return '$letter ${neg ? 'negative' : 'positive'}';
  return '$bn ${neg ? 'নেগেটিভ' : 'পজিটিভ'}';
}

const _plus = ['পজিটিভ', 'পজেটিভ', 'পজিটিব', 'পজেটিব', 'পজিটিফ', 'পসিটিভ', 'পজিটিভে', 'প্লাস', 'positive', 'pos', 'plus', '+ve', '+'];
const _minus = ['নেগেটিভ', 'নেগেটিব', 'নেগেটিফ', 'নেগাটিভ', 'মাইনাস', 'negative', 'neg', 'minus', '-ve', '-', '−'];

/// A blood group said in [text] (normalized): "বি পজিটিভ", "B+", "ও নেগেটিভ", "এবি+".
String? bloodIn(String text) {
  final t = ' ${text.replaceAll('এ বি', 'এবি').replaceAll('a b ', 'ab ')} ';
  String esc(String s) => RegExp.escape(fold(s));
  final sign = '(${[..._plus, ..._minus].map(esc).join('|')})';
  final re = RegExp('(?<=[\\s])(এবি|বি|এ|ও|ab|a|b|o)\\s*$sign(?=[\\s।.,?!]|\$)');
  final m = re.firstMatch(t);
  if (m == null) return null;
  final letter = const {'এবি': 'AB', 'বি': 'B', 'এ': 'A', 'ও': 'O', 'ab': 'AB', 'a': 'A', 'b': 'B', 'o': 'O'}[m[1]]!;
  final neg = _minus.map(fold).contains(m[2]);
  return '$letter${neg ? '−' : '+'}';
}

const _bloodWords = ['ব্লাড গ্রুপ', 'ব্লাড গ্রুফ', 'ব্লাডগ্রুপ', 'রক্তের গ্রুপ', 'রক্তের গ্রুফ', 'রক্তের গ্রূপ', 'রক্তের গোষ্ঠী', 'blood group', 'blood type'];
const _allergyWords = ['এলার্জি', 'অ্যালার্জি', 'এলার্জী', 'allergy', 'allergies'];
const _illnessWords = ['কী রোগ', 'কি রোগ', 'কোন রোগ', 'রোগ আছে', 'অসুখ আছে', 'কী অসুখ', 'কি অসুখ'];

const _heightWords = ['উচ্চতা', 'উচ্চতা', 'হাইট', 'height', 'কত লম্বা'];
const _ageWords = ['বয়স', 'বয়স', 'age'];
const _birthWords = ['জন্মতারিখ', 'জন্ম তারিখ', 'জন্মদিন', 'date of birth', 'birthday'];

/// Which fact about the user is meant: 'height', 'age', 'birth', 'allergy', 'illness' (blood: [mentionsBlood]).
String? profileField(String text) {
  bool has(List<String> l) => l.any((w) => text.contains(normalize(w)));
  final mine = words(text).contains('আমার') || words(text).contains('my') || words(text).contains('আমি');
  if (has(_heightWords)) return 'height';
  if (text.contains(normalize('আমার নাম')) || text.contains('my name')) return 'name';
  if (mine && has(_ageWords)) return 'age';
  if (mine && has(_birthWords)) return 'birth';
  if (has(_allergyWords)) return 'allergy';
  if (has(_illnessWords)) return 'illness';
  return null;
}

/// "৫ ফুট ৬ ইঞ্চি", "৫'৬", "১৬৮ সেমি" → centimetres.
double? heightIn(String text) {
  final t = asciiDigits(text);
  final ft = RegExp(r"(\d)\s*(?:ফুট|ফিট|feet|foot|ft|')\s*(?:(\d{1,2}(?:\.\d)?)\s*(?:ইঞ্চি|ইঞ্চ|inch|inches|in|\x22)?)?").firstMatch(t);
  if (ft != null) {
    final f = int.parse(ft[1]!);
    final i = double.tryParse(ft[2] ?? '') ?? 0;
    if (f >= 2 && f <= 7 && i < 12) return feetToCm(f, i);
  }
  final cm = RegExp(r'(\d{2,3}(?:\.\d)?)\s*(?:সেমি|সেন্টিমিটার|cm)').firstMatch(t);
  if (cm != null) {
    final v = double.parse(cm[1]!);
    if (v >= 50 && v <= 230) return v;
  }
  return null;
}

/// "এ বিষয়ে তথ্য নেই" — and how to add it, the way the app works.
String noInfo(String what, String example) => trf('{0} কোনো তথ্য নেই। তথ্যটি যুক্ত করতে পারেন — বলুন, যেমন “{1}”। পরে যেকোনো সময় জিজ্ঞেস করলে উত্তর দেবো।', [what, example]);

bool mentionsBlood(String text) => _bloodWords.any((w) => text.contains(normalize(w)));

/// Whose (a name or relation said before "রক্তের গ্রুপ"), '' for the user.
String whoseIn(String text) {
  final w = words(text);
  for (var i = 0; i < w.length; i++) {
    final x = w[i];
    if (x == 'আমার' || x == 'আমাদের' || x == 'my') return '';
    final isMarker = x.startsWith(normalize('ব্লাড')) || x.startsWith(normalize('রক্তের')) || x.startsWith(normalize('এলার্জি')) || x.startsWith(normalize('অ্যালার্জি'));
    if (isMarker && i > 0) {
      final prev = w[i - 1];
      if (prev == 'আমার' || prev == 'আমাদের') return '';
      final name = stripPossessive(prev);
      if (name != prev && name.isNotEmpty) return name;
    }
  }
  return '';
}

/// The family member called [who] (by name or relation), or null.
FamilyMember? memberCalled(AppData d, String who) {
  final n = normalize(who);
  for (final m in d.members) {
    if (m.isMe) continue;
    if (normalize(m.name) == n || normalize(m.relation) == n) return m;
  }
  for (final m in d.members) {
    if (m.isMe) continue;
    if (normalize(m.name).contains(n) || (m.relation.isNotEmpty && n.contains(normalize(m.relation)))) return m;
  }
  return null;
}

/// "আমার ব্লাড গ্রুপ কী?", "আম্মার রক্তের গ্রুপ", "আমার কিসে এলার্জি?" —
/// null when the question is about something else.
String? profileAnswer(AppData d, String said) {
  final text = normalize(said);
  final who = whoseIn(text);
  if (mentionsBlood(text)) {
    if (who.isEmpty) {
      final g = d.emergency.blood;
      return g.isEmpty ? noInfo(tr('আপনার রক্তের গ্রুপের'), tr('আমার ব্লাড গ্রুপ বি পজিটিভ')) : trf('আপনার রক্তের গ্রুপ {0}।', [bloodSpoken(g)]);
    }
    final m = memberCalled(d, who);
    if (m == null || m.blood.isEmpty) {
      return noInfo(trf('{0} রক্তের গ্রুপের', [_poss(who)]), trf('{0} ব্লাড গ্রুপ ও পজিটিভ', [_poss(who)]));
    }
    return trf('{0} রক্তের গ্রুপ {1}।', [_poss(m.relation.isNotEmpty ? m.relation : m.name), bloodSpoken(m.blood)]);
  }
  final field = profileField(text);
  final me = d.members.where((m) => m.isMe).firstOrNull;
  final now = DateTime.now();
  switch (field) {
    case 'name':
      final n = askUserName.isNotEmpty ? askUserName : (d.emergency.name.trim().isNotEmpty ? d.emergency.name.trim() : (me != null && me.name != 'আমি' && me.name != 'Me' ? me.name : ''));
      return n.isEmpty
          ? tr('আপনার নামের কোনো তথ্য নেই। সেটিংসে প্রোফাইলে নামটি যুক্ত করতে পারেন — তারপর নাম ধরেই কথা বলবো।')
          : trf('আপনার নাম {0}।', [n]);
    case 'height':
      final cm = me?.heightCm;
      return cm == null ? noInfo(tr('আপনার উচ্চতার'), tr('আমার উচ্চতা ৫ ফুট ৬ ইঞ্চি')) : trf('আপনার উচ্চতা {0}।', [heightText(cm)]);
    case 'age':
      final age = me?.ageOn(now);
      return age == null
          ? tr('আপনার জন্মতারিখের কোনো তথ্য নেই। স্বাস্থ্য পাতায় “বদলান” চেপে জন্মতারিখ দিতে পারেন — তারপর জিজ্ঞেস করলেই বয়স বলে দেবো।')
          : trf('আপনার বয়স {0} বছর।', [bnDigits(age)]);
    case 'birth':
      final b = me?.birth;
      return b == null
          ? tr('আপনার জন্মতারিখের কোনো তথ্য নেই। স্বাস্থ্য পাতায় “বদলান” চেপে জন্মতারিখ দিতে পারেন — পরে যেকোনো সময় জিজ্ঞেস করলে উত্তর দেবো।')
          : trf('আপনার জন্মতারিখ {0}।', [fullDate(b)]);
    case 'allergy':
      final a = d.emergency.allergies.trim();
      return a.isEmpty
          ? tr('আপনার অ্যালার্জির কোনো তথ্য নেই। জরুরি কার্ডে তথ্যটি যুক্ত করতে পারেন — পরে যেকোনো সময় জিজ্ঞেস করলে উত্তর দেবো।')
          : trf('আপনার অ্যালার্জি: {0}।', [a]);
    case 'illness':
      final c = d.emergency.conditions.trim();
      return c.isEmpty
          ? tr('আপনার কোনো রোগের তথ্য নেই। জরুরি কার্ডে তথ্যটি যুক্ত করতে পারেন — পরে যেকোনো সময় জিজ্ঞেস করলে উত্তর দেবো।')
          : trf('জরুরি কার্ডে লেখা আছে: {0}।', [c]);
  }
  return null;
}

String _poss(String name) => name.endsWith('র') || name.endsWith('া') || name.endsWith('ি') || name.endsWith('ু') || name.endsWith('ো') ? '$nameর' : '$nameের';

// ───────────────────────── "আমার কী কী ছবি আছে?" ─────────────────────────

const _photoWords = ['ছবি', 'ফটো', 'ফোটো', 'photo', 'photos', 'picture', 'pictures', 'পিকচার', 'ইমেজ'];
const _paperWords = ['কাগজপত্র', 'কাগজ', 'ডকুমেন্ট', 'ডকুমেন্টস', 'documents', 'document', 'দলিল', 'ফাইল', 'files'];
const _kindFillers = ['আমার', 'কী', 'কি', 'কোন', 'কোনো', 'কয়টা', 'কয়টা', 'কতগুলো', 'কত', 'আছে', 'রাখা', 'রেখেছি', 'সব', 'সবগুলো', 'দেখাও', 'দেখান', 'দেখি', 'বলো', 'বলুন', 'গুলো', 'গুলি', 'টা', 'show', 'my', 'what', 'all'];

/// 'photos' / 'papers' when [terms] ask what kind of things are kept and nothing more specific.
String? kindAsked(String text) {
  final w = words(text);
  bool isAny(String x, List<String> list) => list.any((k) {
        final n = normalize(k);
        return x == n || (x.startsWith(n) && const ['গুলো', 'গুলি', 'টা', 'টি', 'ের', 'এর', 'র', 's'].map(normalize).contains(x.substring(n.length)));
      });
  String? kind;
  for (final x in w) {
    if (isAny(x, _photoWords)) {
      kind = 'photos';
    } else if (isAny(x, _paperWords)) {
      kind ??= 'papers';
    } else if (!isAny(x, _kindFillers)) {
      return null; // "পাসপোর্টের ছবি": a search for that one
    }
  }
  return kind;
}

/// Papers (documents) that hold photos, newest first.
List<Doc> photoDocs(AppData d) => [for (final x in d.docs) if (x.files.any((f) => f.isImage)) x]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

/// The answer to "আমার কী কী ছবি আছে?" / "কী কী কাগজ আছে?".
String kindAnswer(AppData d, String kind) {
  if (kind == 'photos') {
    final docs = photoDocs(d);
    final inDocs = docs.fold<int>(0, (s, x) => s + x.files.where((f) => f.isImage).length);
    final notes = [for (final n in d.notes) if (n.files.any((f) => f.isImage)) n];
    final inNotes = notes.fold<int>(0, (s, n) => s + n.files.where((f) => f.isImage).length);
    if (inDocs == 0 && inNotes == 0) {
      return tr('এখনো কোনো ছবি রাখা নেই। ডকুমেন্টস পাতা থেকে একসাথে অনেক ছবি রাখতে পারেন, নাম আর বিবরণসহ।');
    }
    final parts = <String>[];
    if (inDocs > 0) {
      parts.add(trf('ডকুমেন্টসে {0}টা ছবি — {1}', [bnDigits(inDocs), docs.take(5).map((x) => '“${x.title}”').join(', ') + (docs.length > 5 ? trf(' আর আরও {0}টা', [bnDigits(docs.length - 5)]) : '')]));
    }
    if (inNotes > 0) parts.add(trf('নোটে {0}টা ছবি', [bnDigits(inNotes)]));
    return trf('{0}। নিচে চাপ দিয়ে দেখুন।', [parts.join('; ')]);
  }
  final docs = [...d.docs]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  if (docs.isEmpty) return tr('এখনো কোনো কাগজপত্র রাখা নেই। ডকুমেন্টস পাতা থেকে ছবি তুলে বা ফাইল দিয়ে রাখতে পারেন।');
  final folders = <String, int>{};
  for (final x in docs) {
    folders[x.folder] = (folders[x.folder] ?? 0) + 1;
  }
  return trf('{0}টা কাগজ রাখা আছে — {1}। নিচে চাপ দিয়ে দেখুন।',
      [bnDigits(docs.length), folders.entries.map((e) => '${tr(e.key)} ${bnDigits(e.value)}টা').join(', ')]);
}
