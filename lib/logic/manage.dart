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
      // With its day: two to-dos by one name on two days are told apart.
      for (final t in d.tasks) Target(ItemKind.task, t.id, '${tr('কাজ')}: ${t.title}${t.due != null && t.span == TaskSpan.day ? ' (${sayWhen(t.due!, now, withTime: false)})' : ''}${t.done ? tr(' (শেষ)') : ''}', t.title, t.createdAt),
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

const _deleteWords = ['ফেলে দাও', 'ফেলে দিন', 'ফেলে দেন', 'মুছে দাও', 'মুছে দিন', 'মুছে দেন', 'মুছে ফেলো', 'মুছে ফেল', 'মুছে ফেলুন', 'মুছো', 'মুছুন', 'মুছে', 'ডিলিট', 'delete', 'remove', 'বাতিল করো', 'বাতিল করে দাও', 'বাতিল করুন', 'কেটে দাও', 'সরিয়ে ফেলো', 'সরিয়ে নাও', 'বাদ দাও', 'বাদ দিন', 'বাদ দিয়ে দাও'];
const _editWords = ['বদলে দাও', 'বদলে দিন', 'বদলাও', 'বদলান', 'বদল করো', 'পরিবর্তন', 'এডিট', 'ইডিট', 'edit', 'ঠিক করে দাও', 'ঠিক করো', 'ঠিক করুন', 'সংশোধন', 'আপডেট', 'update', 'সরিয়ে দাও', 'পিছিয়ে দাও', 'এগিয়ে দাও'];
const _lastWords = ['শেষটা', 'শেষেরটা', 'শেষ টা', 'এইমাত্র', 'এই মাত্র', 'আগেরটা', 'আগের টা', 'মাত্র যেটা', 'last one', 'শেষ লেনদেন', 'শেষ খরচ', 'শেষ রিমাইন্ডার', 'শেষ নোট'];

bool _has(String t, List<String> ws) => ws.any((w) {
      final n = normalize(w);
      return n.isNotEmpty && t.contains(n);
    });

/// 'delete' or 'edit' when [text] (normalized) asks to remove or change something saved.
final _notWord = RegExp(' (${['না', 'নয়', 'নয়', 'নই'].map(normalize).join('|')}),? ');

/// "৫০০ না ৬০০", "আগের পাঁচশ নয়, সাতশ হবে": an amount (in digits or
/// words), "না/নয়", then the right one.
bool isCorrection(String text) {
  final parts = text.split(_notWord);
  return parts.length == 2 && findAmount(parts.first) != null && findAmount(parts.last) != null;
}

/// "রিমাইন্ডারটা বন্ধ করো", "মিটিংয়ের অ্যালার্ম অফ করে দাও".
const _stopWords = ['বন্ধ করো', 'বন্ধ কর', 'বন্ধ করে দাও', 'বন্ধ করে দিন', 'বন্ধ করুন', 'বন্ধ করেন', 'বন্ধ রাখো', 'অফ করো', 'অফ করে দাও', 'অফ করুন', 'off করো', 'থামাও', 'চুপ করাও'];

String? manageAction(String text) {
  if (_has(text, _stopWords) && kindNamed(text) == ItemKind.reminder) return 'stop';
  if (_has(text, _deleteWords)) return 'delete';
  // "রবিনের দাওয়াতের কাজটা বাদ": "বাদ" last.
  if (RegExp('(?:^| )${normalize('বাদ')}\$').hasMatch(text)) return 'delete';
  if (_has(text, _editWords)) return 'edit';
  // "৫০০ না ৬০০ হবে", "রহিমের টাকাটা ৫০০ না, ৬০০": a correction.
  if (RegExp(r'\d+ (না|নয়|নয়|নই),? \d+').hasMatch(text)) return 'edit';
  if (isCorrection(text)) return 'edit';
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

/// The request names a particular thing ("মিটিংয়ের রিমাইন্ডার"), not just a kind.
bool namesSomething(String text) => _nameTerms(text, kindNamed(text)).isNotEmpty;

/// Words of the request that name the thing (action, kind and filler words left out).
List<String> _nameTerms(String text, ItemKind? kind) {
  var t = ' $text ';
  for (final w in [..._deleteWords, ..._editWords, ..._stopWords, ..._lastWords, ...?kind?.words]..sort((a, b) => b.length.compareTo(a.length))) {
    t = t.replaceAll(' ${normalize(w)}', ' ');
  }
  final rest = withoutWhen(t);
  // "কাজের তালিকা থেকে পার্টি বাদ দাও": where it is kept is not its name.
  const where = ['থেকে', 'তালিকা', 'তালিকার', 'তালিকায়', 'লিস্ট', 'লিস্টের', 'লিস্টে', 'ভেতর', 'ভেতরে', 'মধ্যে'];
  final skip = {normalize('টাকা'), normalize('টাকার'), for (final w in where) normalize(w), for (final w in where) ...searchTerms(normalize(w))};
  return searchTerms(normalize(rest)).where((x) => !RegExp(r'^\d+$').hasMatch(x) && !skip.contains(x)).toList();
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
  // "৩১ অক্টোবরের রিমাইন্ডার", "১১ জুন ২০২৭ এর": the day it is on picks
  // it — the numbers are never read as part of a name or a year ("২০৩১").
  final dated = _datesIn(text);
  if (dated.isNotEmpty) {
    final hit = [
      for (final t in all)
        if (t.kind == ItemKind.reminder || t.kind == ItemKind.task)
          if (dated.any((x) => _onDay(d, t, x, now))) t
    ];
    if (hit.isNotEmpty) return hit.take(6).toList();
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
    // Named exactly ("পার্টি" and a to-do called just that): that one.
    if (score > 0 && terms.isNotEmpty && searchTerms(hay).join(' ') == terms.join(' ')) score += 5;
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
      // "৫টার বদলে ৬টায়": the time after "বদলে" is the new one.
      final instead = RegExp('(?:${['বদলে', 'পরিবর্তে', 'জায়গায়', 'না'].map(normalize).join('|')})\\s+(.*)\$').firstMatch(text);
      final w = (instead != null && parseWhen(instead[1]!, now) != null && RegExp('\\d').hasMatch(text.substring(0, instead.start)) ? parseWhen(instead[1]!, now) : null) ?? parseWhen(said, now);
      if (w == null || !(w.hasTime || w.hasDay)) break;
      // "১১ জুন ২০২৭ এর রিমাইন্ডারের সময় বদলাও": its own day names it — no
      // new time said, so nothing to change yet.
      final ownDay = w.hasDay && w.at.month == t.at.month && w.at.day == t.at.day;
      if (ownDay && !w.hasTime) break;
      if (w.hasDay && !ownDay) return Change(at: w.at, day: dayOnly(w.at));
      if (ownDay) return Change(at: DateTime(t.at.year, t.at.month, t.at.day, w.at.hour, w.at.minute), day: DateTime(t.at.year, t.at.month, t.at.day));
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
      final parts = text.split(_notWord);
      final amount = findAmount(parts.length >= 2 ? parts.last : text);
      if (amount != null && amount > 0 && amount != t.amount) return Change(amount: amount);
    default:
      break;
  }
  return const Change();
}

/// Days said as "৩১ অক্টোবর" / "১১ জুন ২০২৭" in [text] (normalized):
/// (month, day, year or null).
List<(int, int, int?)> _datesIn(String text) {
  final months = [for (final m in bnMonths) normalize(m)];
  final re = RegExp('(?:^|\\s)(\\d{1,2})\\s*(?:${normalize('তারিখ')}\\S*|${normalize('ই')}|${normalize('শে')}|${normalize('লা')})?\\s+(${months.join('|')})\\S*(?:\\s+(\\d{4}))?');
  return [
    for (final m in re.allMatches(text))
      if (int.parse(m[1]!) >= 1 && int.parse(m[1]!) <= 31) (months.indexOf(m[2]!) + 1, int.parse(m[1]!), m[3] == null ? null : int.parse(m[3]!)),
  ];
}

/// [t] falls on [x] (a reminder's own day — or, repeating yearly, that day
/// of any year; a to-do's due day).
bool _onDay(AppData d, Target t, (int, int, int?) x, DateTime now) {
  final (month, day, year) = x;
  DateTime? on;
  var yearly = false;
  if (t.kind == ItemKind.reminder) {
    final r = d.reminders.where((r) => r.id == t.id).firstOrNull;
    on = r?.date;
    yearly = r?.repeat == Repeat.yearly;
  } else {
    on = d.tasks.where((k) => k.id == t.id).firstOrNull?.due;
  }
  if (on == null) return false;
  return on.month == month && on.day == day && (year == null || yearly || on.year == year);
}

/// Saved reminders [said] names — by the day it is on ("৩১ অক্টোবরের") or
/// by the words of its title ("তুবার জন্মদিনের", "জিলাপির"): the best
/// match only (several when tied).
List<Target> remindersNamed(AppData d, String said, DateTime now) {
  final text = normalize(said);
  final all = [for (final t in targetsIn(d, now)) if (t.kind == ItemKind.reminder) t];
  final dated = _datesIn(text);
  if (dated.isNotEmpty) return [for (final t in all) if (dated.any((x) => _onDay(d, t, x, now))) t];
  const generic = {'দেওয়া', 'নেওয়া', 'যাওয়া', 'করা', 'শেষ', 'আমার', 'আমাদের', 'রিমাইন্ডার', 'সময়', 'দিন', 'আজ', 'কাল'};
  final saidWords = [for (final w in words(text)) if (w.runes.length >= 2) w];
  var best = 0;
  final scored = <(Target, int)>[];
  for (final t in all) {
    final own = [for (final w in words(normalize(t.text))) if (w.runes.length >= 2 && !generic.map(normalize).contains(w)) w];
    var score = 0;
    for (final o in own) {
      if (saidWords.any((w) => w == o || (o.runes.length >= 3 && w.startsWith(o)) || (w.runes.length >= 3 && o.startsWith(w)))) score++;
    }
    if (score > 0) scored.add((t, score));
    if (score > best) best = score;
  }
  return [for (final (t, s) in scored) if (s == best) t];
}
