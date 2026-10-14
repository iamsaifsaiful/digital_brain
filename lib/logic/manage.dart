/// "মিটিংয়ের রিমাইন্ডার মুছে দাও", "রহিমের ৫০০ টাকার লেনদেনটা ৬০০ করে দাও",
/// "বাজারের নোটটা ডিলিট করো", "শেষটা মুছে দাও": finding the saved thing the
/// user means, and what to change in it.
library;

import '../models/models.dart';
import 'bn.dart';
import 'lang.dart';
import 'phrases.dart' show describe;
import 'parser.dart';
import 'proactive.dart' show specialTitle;
import 'when.dart';

/// Kinds of saved things the assistant can change or remove by voice.
/// (Passwords are only changed on their own locked page.)
enum ItemKind {
  reminder('রিমাইন্ডার', ['রিমাইন্ডার', 'মনে করানো', 'অ্যালার্ম', 'এলার্ম', 'alarm', 'reminder']),
  task('কাজ', ['কাজের তালিকা', 'কাজ', 'টুডু', 'task']),
  note('নোট', ['নোট', 'note']),
  ledger('লেনদেন', ['লেনদেন', 'ধার', 'বাকি', 'পাওনা', 'দেনা', 'হিসাব']),
  cash('আয়-খরচ', ['খরচ', 'আয়', 'ইনকাম', 'বেতন']),
  contact('নম্বর', ['নম্বর', 'নাম্বার', 'কন্টাক্ট', 'যোগাযোগ']),
  special('বিশেষ দিন', ['জন্মদিন', 'বিবাহবার্ষিকী', 'মৃত্যুবার্ষিকী', 'বিশেষ দিন']),
  medicine('ওষুধ', ['ওষুধ', 'ঔষধ']),
  habit('অভ্যাস', ['অভ্যাস']),
  memory('মনে রাখা কথা', ['মনে রাখা কথা']),
  doc('কাগজ', ['কাগজ', 'ডকুমেন্ট', 'ছবি']);

  const ItemKind(this.bn, this.words);
  final String bn;
  final List<String> words;
}

/// One saved thing, as the user may name it.
class Target {
  const Target(this.kind, this.id, this.label, this.text, this.at, {this.amount});
  final ItemKind kind;
  final String id;

  /// Said back to the user: "রিমাইন্ডার: মিটিং — কাল সকাল ১০টা".
  final String label;

  /// Words to match against.
  final String text;
  final DateTime at;
  final int? amount;
}

/// Everything that can be changed or removed by voice.
List<Target> targetsIn(AppData d, DateTime now) => [
      for (final r in d.reminders)
        Target(ItemKind.reminder, r.id, '${r.alarm ? tr('অ্যালার্ম') : tr('রিমাইন্ডার')}: ${r.title} — ${sayWhen(DateTime(r.nextDate(now).year, r.nextDate(now).month, r.nextDate(now).day, r.hour, r.minute), now)}', r.title, DateTime(r.date.year, r.date.month, r.date.day, r.hour, r.minute)),
      for (final t in d.tasks) Target(ItemKind.task, t.id, '${tr('কাজ')}: ${t.title}${t.done ? tr(' (শেষ)') : ''}', t.title, t.createdAt),
      for (final n in d.notes) Target(ItemKind.note, n.id, '${tr('নোট')}: ${n.title.isEmpty ? n.body : n.title}', '${n.title} ${n.body} ${n.category}', n.updatedAt),
      for (final e in d.ledger)
        Target(ItemKind.ledger, e.id, '${tr('লেনদেন')}: ${describe(e.kind, e.person, e.amount)} (${shortDate(e.date)})', '${e.person} ${e.note}', e.date, amount: e.amount),
      for (final c in d.cash)
        Target(ItemKind.cash, c.id, '${c.kind.label}: ${c.category} — ${bnNumber(c.amount)} ${tr('টাকা')} (${shortDate(c.date)})', '${c.category} ${c.note}', c.date, amount: c.amount),
      for (final c in d.contacts) Target(ItemKind.contact, c.id, '${tr('নম্বর')}: ${c.name}', c.name, DateTime(2000)),
      for (final s in d.specialDays) Target(ItemKind.special, s.id, specialTitle(s), '${s.person} ${s.kind.bn}', DateTime(2000)),
      for (final m in d.medicines) Target(ItemKind.medicine, m.id, '${tr('ওষুধ')}: ${m.name}', m.name, DateTime(2000)),
      for (final h in d.habits) Target(ItemKind.habit, h.id, '${tr('অভ্যাস')}: ${h.name}', h.name, h.createdAt),
      for (final m in d.memories) Target(ItemKind.memory, m.id, m.text, m.text, m.createdAt),
      for (final x in d.docs) Target(ItemKind.doc, x.id, '${tr('কাগজ')}: ${x.title}', '${x.title} ${x.folder}', x.createdAt),
    ];

const _deleteWords = ['মুছে দাও', 'মুছে দিন', 'মুছে দেন', 'মুছে ফেলো', 'মুছে ফেল', 'মুছে ফেলুন', 'মুছো', 'মুছুন', 'মুছে', 'ডিলিট', 'delete', 'remove', 'বাতিল করো', 'বাতিল করে দাও', 'বাতিল করুন', 'কেটে দাও', 'সরিয়ে ফেলো', 'সরিয়ে নাও', 'বাদ দাও', 'বাদ দিন', 'বাদ দিয়ে দাও'];
const _editWords = ['বদলে দাও', 'বদলে দিন', 'বদলাও', 'বদলান', 'বদল করো', 'পরিবর্তন', 'এডিট', 'ইডিট', 'edit', 'ঠিক করে দাও', 'ঠিক করো', 'ঠিক করুন', 'সংশোধন', 'আপডেট', 'update', 'সরিয়ে দাও', 'পিছিয়ে দাও', 'এগিয়ে দাও'];
const _lastWords = ['শেষটা', 'শেষেরটা', 'শেষ টা', 'এইমাত্র', 'এই মাত্র', 'আগেরটা', 'আগের টা', 'মাত্র যেটা', 'last one', 'শেষ লেনদেন', 'শেষ খরচ', 'শেষ রিমাইন্ডার', 'শেষ নোট'];

bool _has(String t, List<String> ws) => ws.any((w) {
      final n = normalize(w);
      return n.isNotEmpty && t.contains(n);
    });

/// 'delete' or 'edit' when [text] (normalized) asks to remove or change something saved.
String? manageAction(String text) {
  if (_has(text, _deleteWords)) return 'delete';
  if (_has(text, _editWords)) return 'edit';
  // "৫০০ না ৬০০ হবে", "রহিমের টাকাটা ৫০০ না, ৬০০": a correction.
  if (RegExp(r'\d+ না,? \d+').hasMatch(text)) return 'edit';
  // "মিটিংয়ের রিমাইন্ডারটা ৮টায় করে দাও", "রহিমের লেনদেনটা ৬০০ করো": a saved
  // one ("…টা") given a new value.
  final named = RegExp('(${['রিমাইন্ডার', 'অ্যালার্ম', 'এলার্ম', 'লেনদেন', 'কাজ', 'নোট', 'খরচ', 'আয়', 'হিসাব'].map(normalize).join('|')})(টা|টি|টাকে|টার)( |\$)').hasMatch(text);
  if (named && _has(text, ['করে দাও', 'করে দিন', 'করে দেন', 'করো', 'করেন', 'হবে', 'দাও'])) return 'edit';
  return null;
}

/// The kind named ("রিমাইন্ডার", "নোট"…), if any.
ItemKind? kindNamed(String text) {
  for (final k in ItemKind.values) {
    if (_has(text, k.words)) return k;
  }
  return null;
}

bool asksForLast(String text) => _has(text, _lastWords);

/// Words of the request that name the thing (action, kind and filler words left out).
List<String> _nameTerms(String text, ItemKind? kind) {
  var t = ' $text ';
  for (final w in [..._deleteWords, ..._editWords, ..._lastWords, ...?kind?.words]..sort((a, b) => b.length.compareTo(a.length))) {
    t = t.replaceAll(' ${normalize(w)}', ' ');
  }
  final rest = withoutWhen(t);
  return searchTerms(normalize(rest)).where((x) => !RegExp(r'^\d+$').hasMatch(x) && x != normalize('টাকা') && x != normalize('টাকার')).toList();
}

/// The saved things the request may mean, best first.
List<Target> findTargets(AppData d, String said, DateTime now) {
  final text = normalize(said);
  final kind = kindNamed(text);
  final all = [for (final t in targetsIn(d, now)) if (kind == null || t.kind == kind) t];
  if (asksForLast(text)) {
    final sorted = [...all]..sort((a, b) => b.at.compareTo(a.at));
    return sorted.take(1).toList();
  }
  final terms = _nameTerms(text, kind);
  final numbers = [for (final m in RegExp(r'\d+').allMatches(asciiDigits(text))) int.parse(m[0]!)];
  final scored = <(Target, int)>[];
  for (final t in all) {
    final hay = normalize(t.text);
    final hayWords = {...words(hay), ...searchTerms(hay)};
    var score = 0;
    for (final term in terms) {
      // "মিটিংয়ের" (stem "মিটিংয়") matches "মিটিং"; "রহিম" matches "রহিমের".
      if (hay.contains(term) || hayWords.any((h) => h.length >= 3 && (term.startsWith(h) || h.startsWith(term)))) score += 2;
    }
    if (t.amount != null && numbers.contains(t.amount)) score += 3;
    if (score > 0) scored.add((t, score));
  }
  if (scored.isEmpty) return const [];
  scored.sort((a, b) {
    final s = b.$2.compareTo(a.$2);
    return s != 0 ? s : b.$1.at.compareTo(a.$1.at);
  });
  final top = scored.first.$2;
  return [for (final (t, s) in scored) if (s == top) t].take(6).toList();
}

/// A change said with the request: a new time/day (reminder, to-do) or a
/// new amount (loan, income/expense). Null: the user edits it on its page.
class Change {
  const Change({this.at, this.day, this.amount});
  final DateTime? at;
  final DateTime? day;
  final int? amount;
  bool get isEmpty => at == null && day == null && amount == null;
}

Change changeIn(Target t, String said, DateTime now) {
  final text = normalize(said);
  switch (t.kind) {
    case ItemKind.reminder:
      final w = parseWhen(said, now);
      if (w == null || !(w.hasTime || w.hasDay)) break;
      if (w.hasDay) return Change(at: w.at, day: dayOnly(w.at));
      // Only a new time ("৮টায় করে দাও"): the same day; morning or evening
      // as the reminder was, unless said ("রাত ৮টায়").
      var h = w.at.hour;
      final part = _has(text, ['সকাল', 'ভোর', 'দুপুর', 'বিকাল', 'বিকেল', 'সন্ধ্যা', 'রাত', 'am', 'pm']);
      if (!part) {
        final base = h % 12;
        h = (t.at.hour >= 12) ? base + 12 : base;
      }
      final at = DateTime(t.at.year, t.at.month, t.at.day, h, w.at.minute);
      return Change(at: at.isAfter(now) ? at : at.add(const Duration(days: 1)));
    case ItemKind.task:
      final w = parseWhen(said, now);
      if (w != null && w.hasDay) return Change(day: dayOnly(w.at));
    case ItemKind.ledger || ItemKind.cash:
      // "৫০০ না ৬০০": what comes after "না" is the right amount.
      final parts = text.split(RegExp(r' না,? '));
      final amount = findAmount(parts.length >= 2 ? parts.last : text);
      if (amount != null && amount > 0 && amount != t.amount) return Change(amount: amount);
    default:
      break;
  }
  return const Change();
}
