/// The spoken answers to questions, shared by the chat and the answer
/// screen. Passwords are never part of an answer.
library;

import '../models/models.dart';
import 'app_map.dart';
import 'ask.dart';
import 'bn.dart';
import 'me.dart';
import 'calendar_ask.dart';
import 'cash.dart';
import 'health.dart';
import 'ledger.dart';
import 'match.dart';
import 'day_plan.dart';
import 'meaning.dart' show tidySpeech;
import 'parser.dart';
import 'phrases.dart';
import 'search.dart';
import 'talk.dart';
import 'when.dart';
import 'lang.dart';

/// Logins to show for a vault question: the matches, or (when nothing
/// matched by name) all of them so the user can pick.
List<VaultItem> vaultAnswerItems(AppData d, VaultQuery q) {
  final found = searchVault(d, q.terms, wifiOnly: q.wifiOnly);
  if (found.isNotEmpty) return found;
  return [...d.vault]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
}

String vaultAnswer(AppData d, VaultQuery q) {
  final found = searchVault(d, q.terms, wifiOnly: q.wifiOnly);
  if (found.isEmpty && d.vault.isNotEmpty) {
    return q.terms.isEmpty && !q.wifiOnly
        ? tr('এই যে আপনার রাখা লগইনগুলো। কোনটা লাগবে ছুঁয়ে খুলুন — আঙুলের ছাপ বা PIN লাগবে।')
        : tr('নাম দিয়ে ঠিক মেলাতে পারিনি। আপনার রাখা লগইনগুলো নিচে আছে, কোনটা লাগবে দেখে নিন।');
  }
  if (found.isEmpty) {
    return q.wifiOnly
        ? tr('Wi-Fi-এর কোনো তথ্য নেই। পাসওয়ার্ড ভল্টে তথ্যটি যুক্ত করতে পারেন — পরে জিজ্ঞেস করলে আঙুলের ছাপ নিয়ে দেখাবো।')
        : tr('কোনো পাসওয়ার্ডের তথ্য নেই। পাসওয়ার্ড ভল্টে তথ্যটি যুক্ত করতে পারেন — পরে জিজ্ঞেস করলে আঙুলের ছাপ নিয়ে দেখাবো।');
  }
  if (found.length == 1) {
    return trf('{0} তথ্য পেয়েছি! তবে পাসওয়ার্ড গোপন জিনিস, তাই জোরে বলব না। আঙুলের ছাপ দিয়ে খুলুন, স্ক্রিনে দেখাব।', [possessive(found.first.name)]);
  }
  return trf('{0}টা মিলেছে। কোনটা লাগবে ছুঁয়ে খুলুন — আঙুলের ছাপ বা PIN লাগবে।', [bnDigits(found.length)]);
}

/// "• সন্ধ্যা ৬টা ২০ — বাজার" lines for reminders.
String _reminderLines(Iterable<Reminder> rs, DateTime now, {bool withDay = false}) => [
      for (final r in rs)
        '• ${withDay ? '${sayWhen(r.nextDate(now), now, withTime: false)} ' : ''}${bnTime(r.hour, r.minute)} — ${r.title}',
    ].join('\n');

/// What a reminder question shows — one reading, used both for the answer
/// and for the list a following "এগুলো সব মুছে দাও" points at, so the two
/// can never disagree.
/// kind: 'day' (every one on a day), 'all' (no name said — "আর কোন
/// রিমাইন্ডার আছে?"), 'miss' (a name said, none matched: the upcoming ones
/// shown instead), 'one' (the best match told).
({String kind, List<Reminder> shown, List<Reminder> pool, int matching, DateTime? day}) reminderView(AppData d, ReminderQuery q, DateTime now) {
  final w = parseWhen(q.transcript, now);
  final sorted = [for (final r in d.reminders) if (!q.alarmsOnly || r.alarm) r]
    ..sort((a, b) => DateTime(a.nextDate(now).year, a.nextDate(now).month, a.nextDate(now).day, a.hour, a.minute)
        .compareTo(DateTime(b.nextDate(now).year, b.nextDate(now).month, b.nextDate(now).day, b.hour, b.minute)));
  if (w != null && w.hasDay) {
    final onDay = sorted.where((r) => dayOnly(r.nextDate(now)) == w.day).toList();
    return (kind: 'day', shown: onDay, pool: onDay, matching: onDay.length, day: w.day);
  }
  final upcoming = sorted.where((r) => !r.nextDate(now).isBefore(dayOnly(now))).toList();
  // Only words about reminders in general ("আর", "কোন", "সব", "বাকি"):
  // the list itself is asked for — not a reminder by that name.
  final named = [for (final t in q.terms) if (!_reminderGeneric.contains(t)) t];
  if (named.isEmpty) return (kind: 'all', shown: upcoming.take(_reminderPage).toList(), pool: upcoming, matching: upcoming.length, day: null);
  final found = [for (final r in searchReminders(d, named)) if (!q.alarmsOnly || r.alarm) r];
  if (found.isEmpty) return (kind: 'miss', shown: upcoming.take(_reminderPage).toList(), pool: upcoming, matching: upcoming.length, day: null);
  return (kind: 'one', shown: [found.first], pool: [found.first], matching: 1, day: null);
}

const _reminderPage = 10;
final Set<String> _reminderGeneric = searchTerms(normalize('অ্যালার্ম অ্যালার্মগুলো এলার্ম এলার্মগুলো alarm কখন কয়টায় কটায় বাজবে রিমাইন্ডার রিমাইন্ডারগুলো রিমাইন্ডারগুলা রিমাইন্ডারের রিমাইন্ডারগুলোর মনে করানো করিয়ে করাবে আর আরো আরও অন্য অন্যান্য বাকি বাকিগুলো সব সবগুলো সবগুলা সমস্ত আমার কোন কোনো কোনগুলো কী কি কয়টা কতগুলো কতটা আছে আছেন রাখা রাখছি রেখেছি দেওয়া দেয়া দেখাও দেখান বলো বলুন দাও দিন তালিকা লিস্ট সামনের সামনে পরের চলতি এখন এখনো তো সেট')).toSet();

String reminderAnswer(AppData d, ReminderQuery q, DateTime now) {
  // "আজ কোন রিমাইন্ডার আছে?", "কালকের রিমাইন্ডার": every one on that day.
  final v = reminderView(d, q, now);
  if (q.alarmsOnly) {
    if (v.shown.isEmpty) {
      return v.kind == 'day'
          ? trf('{0} কোনো অ্যালার্ম নেই।', [sayWhen(v.day!, now, withTime: false)])
          : tr('কোনো অ্যালার্ম রাখা নেই। রাখতে চাইলে বলুন — যেমন “কাল সকাল ৬টায় অ্যালার্ম দাও”।');
    }
    final lines = [
      for (final r in v.shown)
        '• ${r.repeat == Repeat.none ? sayWhen(r.nextDate(now), now, withTime: false) : (r.weekdays.isNotEmpty ? r.weekdays.map(dayName).join(', ') : tr(r.repeat.label))} ${bnTime(r.hour, r.minute)} — ${r.title}${r.enabled ? '' : tr(' (বন্ধ)')}'
    ].join('\n');
    return trf('{0}টা অ্যালার্ম আছে:\n{1}', [bnDigits(v.shown.length), lines]);
  }
  if (v.kind == 'day') {
    final dayText = sayWhen(v.day!, now, withTime: false);
    if (v.shown.isEmpty) return trf('{0} কোনো রিমাইন্ডার নেই। রাখতে চাইলে বলুন — যেমন “সন্ধ্যা ৭টায় মিটিং মনে করিয়ে দিও”।', [dayText]);
    return trf('{0} {1}টা রিমাইন্ডার আছে:\n{2}', [dayText, bnDigits(v.shown.length), _reminderLines(v.shown, now)]);
  }
  if (v.kind == 'all' || v.kind == 'miss') {
    if (v.shown.isEmpty) return tr('এখনো কোনো রিমাইন্ডার রাখা নেই। রাখতে চাইলে বলুন — যেমন “কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও”।');
    final lines = _reminderLines(v.shown, now, withDay: true);
    final head = v.kind == 'miss'
        ? tr('ঠিক এই নামে কিছু পেলাম না। সামনের রিমাইন্ডারগুলো:')
        : (v.matching > v.shown.length
            ? trf('সামনে {0}টা রিমাইন্ডার আছে — প্রথম {1}টা:', [bnDigits(v.matching), bnDigits(v.shown.length)])
            : trf('সামনে {0}টা রিমাইন্ডার আছে:', [bnDigits(v.matching)]));
    return '$head\n$lines';
  }
  final r = v.shown.first;
  final day = r.nextDate(now);
  final left = dayOnly(day).difference(dayOnly(now)).inDays;
  final when = left == 0 ? tr('মানে আজকেই') : (left == 1 ? tr('মানে কালকেই') : (left > 0 ? trf('আর {0} দিন আছে', [bnDigits(left)]) : trf('{0} দিন আগে চলে গেছে', [bnDigits(-left)])));
  return '${r.title} ${weekdayName(day)}, ${bnDigits(day.day)} ${monthName(day.month)}। $when।';
}

String searchAnswer(AppData d, SearchQuery q, DateTime now) {
  // "আমার এখানে কোন ছবি আছে কিনা?": the photos kept in ডকুমেন্টস, in general.
  const photoWords = ['ছবি', 'ছবিগুলো', 'ছবিগুলা', 'ফটো', 'photo', 'photos', 'ছবিটবি'];
  const general = ['এখানে', 'আমার', 'কোন', 'কোনো', 'কোনও', 'আছে', 'কিনা', 'কি', 'কী', 'দেখো', 'দেখতো', 'সব', 'কয়টা', 'কয়টা', 'কতগুলো', 'রাখা', 'অ্যাপে', 'এপে'];
  final rest = [for (final t in q.terms) if (!photoWords.map(normalize).contains(normalize(t)) && !general.map(normalize).contains(normalize(t))) t];
  final askedPhotos = q.terms.any((t) => photoWords.map(normalize).contains(normalize(t)));
  if (askedPhotos && rest.isEmpty) {
    final withPhotos = [for (final x in d.docs) if (x.files.any((f) => f.isImage)) x];
    if (withPhotos.isEmpty) return tr('এখনো কোনো ছবি রাখা নেই। ডকুমেন্টস পাতায় ছবি তুলে বা গ্যালারি থেকে রাখতে পারেন।');
    final count = withPhotos.fold<int>(0, (a, x) => a + x.files.where((f) => f.isImage).length);
    return trf('ডকুমেন্টসে {0}টা ছবি আছে — {1}। নিচে চাপ দিয়ে দেখুন।', [bnDigits(count), withPhotos.take(5).map((x) => '“${x.title}”').join(', ')]);
  }
  final hits = relevantHits(d, q.terms);
  if (hits.isEmpty) {
    // "তুবাকে জন্মদিনে কি দেওয়া যায়?": advice, not something kept — said
    // honestly, with what is kept about it.
    if (asksAdvice(q.transcript)) {
      final t = normalize(q.transcript);
      final day = d.specialDays.where((x) => x.person.trim().isNotEmpty && t.contains(normalize(x.person))).firstOrNull;
      var known = '';
      if (day != null) {
        var next = DateTime(now.year, day.month, day.day);
        if (next.isBefore(dayOnly(now))) next = DateTime(now.year + 1, day.month, day.day);
        final left = next.difference(dayOnly(now)).inDays;
        known = trf(' {0}-এর {1} {2}, {3} — আর {4} দিন।', [day.person, day.kind.bn, weekdayName(next), '${bnDigits(next.day)} ${monthName(next.month)}', bnDigits(left)]);
      }
      return trf('এটা পরামর্শের প্রশ্ন — আপনার রাখা তথ্যে এর উত্তর নেই, আর নিজে থেকে বানিয়ে বলব না। AI চালু থাকলে এমন প্রশ্নে আইডিয়া দিতে পারি।{0}', [known]);
    }
    // "নিহানের বেতন কোথায় যুক্ত করলে?": an আয়-ব্যয় record by what was said with it.
    final cash = cashFound(d, q.terms);
    if (cash.isNotEmpty) {
      final e = cash.first;
      final proj = e.projectId == null ? null : d.projects.where((p) => p.id == e.projectId).firstOrNull;
      final where = proj == null ? tr('সাধারণ আয়-ব্যয়ে') : trf('‘{0}’ হিসাবে', [proj.name]);
      return trf('{0}: {1} {2} টাকা, {3} লেখা আছে ({4}, খাত: {5})।{6}', [
        e.note.length > 60 ? '${e.note.substring(0, 58)}…' : e.note,
        e.kind == CashKind.income ? tr('আয়') : tr('খরচ'),
        bnNumber(e.amount),
        where,
        shortDate(e.date),
        e.category,
        cash.length > 1 ? trf(' আরও {0}টা মিলেছে।', [bnDigits(cash.length - 1)]) : '',
      ]);
    }
    final p = placeMentioned(normalize(q.transcript));
    if (p != null) return trf('এ বিষয়ে আলাদা কোনো তথ্য নেই। {0} পাতায় দেখতে নিচে চাপুন।', [tr(p.title)]);
    // "রহিমের নম্বর কত?" with no such number: say whose, and how to add it.
    final w = words(normalize(q.transcript));
    if (w.any((x) => x.startsWith(normalize('নম্বর')) || x.startsWith(normalize('নাম্বার')))) {
      final whose = w.firstWhere((x) => x != 'আমার' && stripPossessive(x) != x, orElse: () => '');
      if (whose.isNotEmpty) {
        return trf('{0} নম্বরের কোনো তথ্য নেই। বলুন “{0} নম্বর ০১৭… রাখো”, অথবা যোগাযোগ পাতা থেকে ফোনবুকের নম্বর আনুন — পরে নাম বললেই ফোন করে দেবো।', [whose]);
      }
    }
    return tr('এ বিষয়ে কোনো তথ্য নেই। তথ্যটি যুক্ত করতে পারেন — বলুন “মনে রাখো: …” — পরে যেকোনো সময় জিজ্ঞেস করলে উত্তর দেবো।');
  }
  // Say the best match itself, not just "found N things".
  final best = hits.first;
  // Several photos or papers: name them all, the buttons below open them.
  final docs = [for (final h in hits) if (h is DocHit) h.doc];
  if (best is DocHit && docs.length > 1) {
    return trf('{0}টা মিলেছে: {1}। নিচে চাপ দিয়ে দেখুন।', [bnDigits(docs.length), docs.take(5).map((x) => '“${x.title}”').join(', ')]);
  }
  final tied = hits.where((h) => h.score == best.score).length;
  final lead = tied > 1 ? tr('কয়েকটা মিলেছে। সবচেয়ে কাছেরটা হলো — ') : '';
  return '$lead${hitAnswer(d, best, now)}';
}

/// "কি দেওয়া যায়?", "কী করা উচিত?", "কোনটা ভালো হবে?": asking for advice.
bool asksAdvice(String said) {
  final t = ' ${normalize(said)} ';
  return [
    'কি দেওয়া যায়', 'কী দেওয়া যায়', 'কি দেয়া যায়', 'কী দেয়া যায়', 'কি দিতে পারি', 'কী দিতে পারি', 'কি গিফট', 'কী গিফট', 'কি উপহার', 'কী উপহার',
    'কি করা উচিত', 'কী করা উচিত', 'কি করলে ভালো', 'কী করলে ভালো', 'কোনটা ভালো হবে', 'পরামর্শ দাও', 'পরামর্শ দিন', 'আইডিয়া দাও', 'সাজেস্ট',
  ].any((p) => t.contains(normalize(p)));
}

/// আয়-ব্যয় records whose words (what was said, the খাত) match [terms],
/// newest first. Words about the asking itself do not count.
List<CashEntry> cashFound(AppData d, List<String> terms) {
  const asking = ['কোথায়', 'কোথায়', 'যুক্ত', 'যোগ', 'করলে', 'করেছ', 'করেছো', 'রাখলে', 'রেখেছ', 'রেখেছো', 'লিখলে', 'লিখেছ', 'লিখেছো', 'কোন', 'কোনো', 'হিসাবে', 'হিসাব', 'টাকা'];
  final own = [for (final t in terms) if (normalize(t).length >= 2 && !asking.map(normalize).contains(normalize(t))) t];
  if (own.isEmpty) return const [];
  final found = [for (final e in d.cash) if (score(own, [e.note, e.category]) * 2 >= own.length && score(own, [e.note]) > 0) e]..sort((a, b) => b.date.compareTo(a.date));
  return found;
}

/// One found thing, as a spoken answer.
String hitAnswer(AppData d, Hit h, DateTime now) {
  String end(String t) => RegExp(r'[।?!.]$').hasMatch(t.trim()) ? t.trim() : '${t.trim()}।';
  return switch (h) {
    NoteHit(:final note) => end(note.body.trim().isEmpty ? note.title : note.body),
    ContactHit(:final contact) => contact.phone.isEmpty
        ? end('${contact.name}${contact.note.isEmpty ? '' : ' — ${contact.note}'}')
        : end('${possessive(contact.name)} নম্বর ${bnDigits(contact.phone)}'),
    ReminderHit(:final reminder) => end(
        '${reminder.title} ${weekdayName(reminder.nextDate(now))}, ${bnDigits(reminder.nextDate(now).day)} ${monthName(reminder.nextDate(now).month)}'),
    PersonHit(:final person) => end(owesText(person, balanceWith(d.ledger, person))),
    VaultHit(:final item) => '${possessive(item.name)} তথ্য পেয়েছি! তবে এটা গোপন জিনিস, তাই জোরে বলব না। আঙুলের ছাপ দিয়ে খুলুন, স্ক্রিনে দেখাব।',
    DocHit(:final doc) => trf('“{0}” পেয়েছি — {1}টা {2}, {3} ফোল্ডারে। নিচে চাপ দিয়ে দেখুন।',
        [doc.title, bnDigits(doc.files.length), doc.files.every((f) => f.isImage) ? tr('ছবি') : tr('পাতা'), tr(doc.folder)]),
  };
}

String ledgerAnswer(AppData d, LedgerQuery q, [DateTime? now]) {
  final all = balances(d.ledger);
  switch (q.ask) {
    case LedgerAsk.person:
      final p = balanceOf(d.ledger, q.person!);
      if (p == null) return trf('{0} সাথে কোনো লেনদেনের তথ্য নেই।', [possessive(q.person!)]);
      final period = periodIn(normalize(q.transcript), now ?? DateTime.now());
      if (period != null) {
        final (from, to, label) = period;
        final inPeriod = [for (final (e, _) in runningFor(d.ledger, p.name)) if (!e.date.isBefore(from) && e.date.isBefore(to)) e];
        if (inPeriod.isEmpty) return trf('{0} {1} সাথে কোনো লেনদেন হয়নি। {2}।', [label, possessive(p.name), owesText(p.name, p.balance)]);
        int sum(LedgerKind k) => inPeriod.where((e) => e.kind == k).fold(0, (a, e) => a + e.amount);
        final parts = [
          if (sum(LedgerKind.lent) > 0) '${toPerson(p.name)} দিয়েছেন ${bnNumber(sum(LedgerKind.lent))} টাকা',
          if (sum(LedgerKind.received) > 0) 'ফেরত পেয়েছেন ${bnNumber(sum(LedgerKind.received))} টাকা',
          if (sum(LedgerKind.borrowed) > 0) '${possessive(p.name)} কাছ থেকে নিয়েছেন ${bnNumber(sum(LedgerKind.borrowed))} টাকা',
          if (sum(LedgerKind.repaid) > 0) 'শোধ করেছেন ${bnNumber(sum(LedgerKind.repaid))} টাকা',
        ];
        return trf('{0} {1} ({2} বার)। এখন {3}।', [label, parts.join(', '), bnDigits(inPeriod.length), owesText(p.name, p.balance)]);
      }
      final hist = runningFor(d.ledger, p.name);
      final last = hist.isEmpty ? null : hist.last.$1;
      final lastText = last == null ? '' : trf(' শেষ লেনদেন ছিল {0} {1}।', [bnDigits(last.date.day), monthName(last.date.month)]);
      return '${owesText(p.name, p.balance)}।$lastText';
    case LedgerAsk.receivable:
      final owe = all.where((p) => p.balance > 0).toList();
      if (owe.isEmpty) return tr('এখন কারও কাছে আপনার কিছু পাওনা নেই।');
      final sum = owe.fold<int>(0, (s, p) => s + p.balance);
      // Money owed is said in full (up to 10 people), never "আরও ১ জন".
      final who = nameList([for (final p in owe) '${possessive(p.name)} কাছে ${bnNumber(p.balance)}'], max: 10);
      return trf('সব মিলিয়ে আপনি {0} টাকা পাবেন — {1}।', [bnNumber(sum), who]);
    case LedgerAsk.payable:
      final iOwe = all.where((p) => p.balance < 0).toList();
      if (iOwe.isEmpty) return tr('কাউকে কিছু দিতে হবে না, সব শোধ!');
      final sum = iOwe.fold<int>(0, (s, p) => s - p.balance);
      final who = nameList([for (final p in iOwe) '${toPerson(p.name)} ${bnNumber(-p.balance)}'], max: 10);
      return trf('সব মিলিয়ে আপনাকে {0} টাকা দিতে হবে — {1}।', [bnNumber(sum), who]);
    case LedgerAsk.all:
      final t = totals(d.ledger);
      if (t.receivable == 0 && t.payable == 0) return tr('এখন কারও সাথে কোনো পাওনা-দেনা নেই, সব মিটে গেছে।');
      if (t.payable == 0) return trf('আপনি মোট {0} টাকা পাবেন; আপনার কোনো দেনা নেই।', [bnNumber(t.receivable)]);
      if (t.receivable == 0) return trf('আপনাকে মোট {0} টাকা দিতে হবে; কারও কাছে পাওনা নেই।', [bnNumber(t.payable)]);
      final net = t.receivable - t.payable;
      return trf('আপনি পাবেন {0} টাকা, দিতে হবে {1} টাকা — {2}।', [
        bnNumber(t.receivable),
        bnNumber(t.payable),
        net == 0 ? tr('দুটো সমান') : (net > 0 ? trf('সব মিলিয়ে {0} টাকা আপনার পক্ষে', [bnNumber(net)]) : trf('সব মিলিয়ে {0} টাকা আপনার দেনা বেশি', [bnNumber(-net)])),
      ]);
  }
}

/// A span of time said in a question: "গত মাসে", "এই সপ্তাহে", "আজ"…
/// (start inclusive, end exclusive, the words to repeat).
(DateTime, DateTime, String)? periodIn(String text, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = weekStartOf(today);
  bool has(List<String> w) => w.any((x) => text.contains(fold(x)));
  if (has(['গত মাসে', 'গত মাসের', 'আগের মাসে', 'last month'])) return (DateTime(now.year, now.month - 1), DateTime(now.year, now.month), 'গত মাসে');
  if (has(['এই মাসে', 'এ মাসে', 'এই মাসের', 'this month'])) return (DateTime(now.year, now.month), DateTime(now.year, now.month + 1), 'এই মাসে');
  if (has(['গত সপ্তাহে', 'গত সপ্তাহের', 'last week'])) return (weekStart.subtract(const Duration(days: 7)), weekStart, 'গত সপ্তাহে');
  if (has(['এই সপ্তাহে', 'এ সপ্তাহে', 'this week'])) return (weekStart, weekStart.add(const Duration(days: 7)), 'এই সপ্তাহে');
  if (has(['গত বছর', 'last year'])) return (DateTime(now.year - 1), DateTime(now.year), 'গত বছর');
  if (has(['এই বছর', 'এ বছর', 'this year'])) return (DateTime(now.year), DateTime(now.year + 1), 'এই বছর');
  if (has(['গতকাল', 'yesterday'])) return (today.subtract(const Duration(days: 1)), today, 'গতকাল');
  if (has(['আজকে', 'today']) || text.split(' ').contains('আজ')) return (today, today.add(const Duration(days: 1)), 'আজ');
  return null;
}

/// Weekdays said back: a run of three or more as "রবিবার থেকে
/// বৃহস্পতিবার" (the week starting Saturday or Sunday as it falls), else
/// "রবিবার ও বুধবার".
String weekdaysSaid(List<int> days) {
  final set = days.toSet();
  if (set.length == 7) return tr('দিন');
  // Find a start such that the days are one unbroken run from it.
  for (final start in set) {
    var n = 0;
    var d = start;
    while (set.contains(d) && n < 7) {
      n++;
      d = d % 7 + 1;
    }
    final prev = start == 1 ? 7 : start - 1;
    if (n == set.length && !set.contains(prev) && n >= 3) {
      final last = (start - 1 + n - 1) % 7 + 1;
      return trf('{0} থেকে {1}', [dayName(start), dayName(last)]);
    }
  }
  final order = [...set]..sort((a, b) => ((a + 1) % 7).compareTo((b + 1) % 7));
  final names = [for (final x in order) dayName(x)];
  return names.length == 1 ? names.single : '${names.sublist(0, names.length - 1).join(', ')} ${tr('ও')} ${names.last}';
}

/// "ক, খ, আর গ" (at most four, then "আরও N জন").
String nameList(List<String> parts, {String unit = 'জন', int max = 4}) {
  final shown = parts.take(max).toList();
  final more = parts.length - shown.length;
  final head = shown.length > 1 ? trf('{0}, আর {1}', [shown.sublist(0, shown.length - 1).join(', '), shown.last]) : shown.join();
  return more > 0 ? trf('{0}, এবং আরও {1} {2}', [head, bnDigits(more), unit]) : head;
}

/// Open to-dos: overdue and today's first, then undated, then later ones.
List<Task> openTasksOf(AppData d, DateTime now) {
  final open = d.tasks.where((t) => !t.done).toList();
  int rank(Task t) => t.due == null ? 1 : (t.dueBy(now) ? 0 : 2);
  open.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return (a.due ?? a.createdAt).compareTo(b.due ?? b.createdAt);
  });
  return open;
}

/// "ব্যাংকে যাওয়া (আজ)", "রিপোর্ট জমা (১২ অক্টোবর)".
String taskLabel(Task t, DateTime now) => taskLine(t, now);

String taskAnswer(AppData d, DateTime now, [String asked = '']) {
  final open = openTasksOf(d, now);
  // "আজকের কাজের তালিকা", "৩১ অক্টোবরের কাজ": only that day's.
  // "জানুয়ারি মাসের কাজের তালিকা": that month's.
  final said = fold(tidySpeech(asked));
  for (var m = 0; m < 12 && asked.isNotEmpty; m++) {
    final i = said.indexOf(fold(bnMonths[m]));
    if (i < 0 || RegExp(r'[০-৯0-9]\s*$').hasMatch(said.substring(0, i))) continue;
    final year = (m + 1 < now.month) ? now.year + 1 : now.year;
    // A week, month or year plan that covers the month counts too.
    final those = [for (final t in open) if (t.touches(DateTime(year, m + 1), DateTime(year, m + 2, 0))) t];
    if (those.isEmpty) return trf('{0} মাসে কোনো কাজ রাখা নেই।', [bnMonths[m]]);
    return trf('{0} মাসে {1}টা কাজ — {2}।', [bnMonths[m], bnDigits(those.length), nameList([for (final t in those) taskLine(t, now)], unit: 'টা')]);
  }
  final w = asked.isEmpty ? null : parseWhen(tidySpeech(asked), now);
  if (w != null && w.hasDay) {
    // The same list the home's আজকের কাজ and the কাজ page show for that day:
    // to-dos and reminders (one definition — they never disagree).
    final items = planItemsOn(d, w.day, now);
    final when = sayWhen(dayOnly(w.day), now, withTime: false);
    final part = dayPartAsked(asked);
    if (part != null) return dayPartAnswer(d, items, part, when);
    if (items.isEmpty) {
      final rest = open.length;
      return trf('{0} কোনো কাজ বা রিমাইন্ডার নেই।{1}', [when, rest > 0 ? trf(' অন্য দিনের বা তারিখ ছাড়া {0}টা কাজ আছে।', [bnDigits(rest)]) : '']);
    }
    String label(PlanItem i) => i.reminder != null ? '${i.title} (${bnTime(i.sort.hour, i.sort.minute)})' : i.title;
    return trf('{0} {1}টা — {2}।', [when, bnDigits(items.length), nameList([for (final i in items) label(i)], unit: 'টা')]);
  }
  if (open.isEmpty) return tr('এখন কোনো কাজ বাকি নেই। নতুন কাজ বললে তালিকায় তুলে রাখব।');
  return trf('{0}টা কাজ বাকি — {1}।', [bnDigits(open.length), nameList([for (final t in open) taskLabel(t, now)], unit: 'টা')]);
}

/// "সন্ধ্যায়", "সকালে", "রাতে" in a question about a day: (name, from hour, to hour).
(String, int, int)? dayPartAsked(String said) {
  final t = ' ${normalize(said)} ';
  const parts = [
    ('ভোরে', ['ভোর', 'ভোরে'], 4, 6),
    ('সকালে', ['সকাল', 'সকালে'], 5, 12),
    ('দুপুরে', ['দুপুর', 'দুপুরে'], 12, 15),
    ('বিকেলে', ['বিকাল', 'বিকালে', 'বিকেল', 'বিকেলে'], 15, 18),
    ('সন্ধ্যায়', ['সন্ধ্যা', 'সন্ধ্যায়', 'সন্ধা', 'সন্ধায়'], 17, 20),
    ('রাতে', ['রাত', 'রাতে'], 19, 24),
  ];
  for (final (name, ws, a, b) in parts) {
    if (ws.any((w) => t.contains(' ${normalize(w)} '))) return (name, a, b);
  }
  return null;
}

/// A day's items in one part of it: those with a time then, and the ones
/// with no time said, told apart.
String dayPartAnswer(AppData d, List<PlanItem> items, (String, int, int) part, String when) {
  int? hourOf(PlanItem i) {
    if (i.reminder != null) return i.sort.hour;
    final rid = i.task?.reminderId;
    final r = rid == null ? null : d.reminders.where((x) => x.id == rid).firstOrNull;
    return r?.hour;
  }
  String label(PlanItem i) {
    final h = hourOf(i);
    final r = i.reminder ?? (i.task?.reminderId == null ? null : d.reminders.where((x) => x.id == i.task!.reminderId).firstOrNull);
    return h == null || r == null ? i.title : '${i.title} (${bnTime(r.hour, r.minute)})';
  }
  final inPart = [for (final i in items) if (hourOf(i) case final h? when h >= part.$2 && h < part.$3) i];
  final untimed = [for (final i in items) if (hourOf(i) == null) i];
  final head = inPart.isEmpty
      ? trf('{0} {1} সময় ধরা কোনো কাজ বা রিমাইন্ডার নেই।', [when, part.$1])
      : trf('{0} {1} {2}টা — {3}।', [when, part.$1, bnDigits(inPart.length), nameList([for (final i in inPart) label(i)], unit: 'টা')]);
  final rest = untimed.isEmpty ? '' : trf(' সময় ছাড়া {0} আরও {1}টা কাজ আছে — {2}।', [when, bnDigits(untimed.length), nameList([for (final i in untimed) i.title], unit: 'টা')]);
  return '$head$rest';
}

/// The to-dos a question covers, in the order they are said and shown:
/// urgent first, then late, then by date, then those without a date.
List<Task> scopedTasks(AppData d, TaskScope s, DateTime now) {
  final today = dayOnly(now);
  bool touches(Task t, DateTime a, DateTime b) => t.touches(a, b);
  // Late (a day or deadline passed) or a plan whose time is over.
  bool over(Task t) => t.lateAt(now) || t.windowPassed(now);
  Iterable<Task> pool;
  if (s.doneOnly) {
    final a = s.from ?? today, b = s.to ?? today;
    pool = d.tasks.where((t) => t.doneAt != null && (t.done || t.repeat != null) && !dayOnly(t.doneAt!).isBefore(a) && !dayOnly(t.doneAt!).isAfter(b));
  } else {
    pool = d.tasks.where((t) => !t.done);
    if (s.undated) {
      pool = pool.where((t) => t.due == null);
    } else if (s.overdue) {
      pool = pool.where(over);
    } else if (s.future) {
      pool = pool.where((t) => t.due != null && (dayOnly(t.due!).isAfter(today) || (t.span != TaskSpan.day && !dayOnly(t.dueEnd!).isBefore(today))));
    } else if (s.from != null) {
      pool = pool.where((t) => touches(t, s.from!, s.to ?? s.from!) || (s.withOverdue && over(t)));
    }
  }
  if (s.about.isNotEmpty) pool = pool.where((t) => taskScore(t, s.about) > 0);
  final out = pool.toList();
  int rank(Task t) => t.due == null && t.deadline == null ? 2 : (over(t) ? 0 : 1);
  out.sort((a, b) {
    if (a.urgent != b.urgent) return a.urgent ? -1 : 1;
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return (a.due ?? a.createdAt).compareTo(b.due ?? b.createdAt);
  });
  return out;
}

/// "রিপোর্ট পাঠানো (সোমবার, ১২ অক্টোবর)", "আলমারি গোছানো", with জরুরি.
String taskLine(Task t, DateTime now) {
  final today = dayOnly(now);
  final when = taskWhen(t, now);
  final dl = t.deadline;
  final bits = [
    if (when != null) when,
    if (dl != null && (t.due == null || dayOnly(dl) != dayOnly(t.due!) || t.span != TaskSpan.day))
      dayOnly(dl).isBefore(today) ? trf('শেষ সময় ছিল {0} — পেরিয়ে গেছে', [shortDate(dl)]) : trf('শেষ সময় {0}', [sayWhen(dl, now, withTime: false)]),
    if (t.urgent) tr('জরুরি'),
  ];
  if (bits.isEmpty) return t.title;
  // Brackets are not nested: "কাল (সোমবার)" inside them reads "কাল, সোমবার".
  final flat = [for (final b in bits) b.replaceAllMapped(RegExp(r'\s*\(([^()]*)\)'), (m) => ', ${m[1]}')];
  return '${t.title} (${flat.join(', ')})';
}

/// When a to-do is for, as it was said: "আগামীকাল", "এই সপ্তাহের যেকোনো
/// দিন", "নভেম্বর মাসের যেকোনো সময়", "দেরি হয়ে গেছে — ছিল ১০ অক্টো";
/// null without a date.
String? taskWhen(Task t, DateTime now) {
  final today = dayOnly(now);
  String? when;
  if (t.due != null) {
    final d = dayOnly(t.due!);
    // The span as it was said — a week or a month is never given a day.
    final said = switch (t.span) {
      TaskSpan.week => d == _weekStartOf(today)
          ? tr('এই সপ্তাহের যেকোনো দিন')
          : (d == _weekStartOf(today).add(const Duration(days: 7)) ? tr('আগামী সপ্তাহের যেকোনো দিন') : trf('{0}-এর সপ্তাহে, দিন ঠিক নেই', [shortDate(d)])),
      TaskSpan.month => d.year == today.year ? trf('{0} মাসের যেকোনো সময়', [bnMonths[d.month - 1]]) : trf('{0} {1}-এর যেকোনো সময়', [bnMonths[d.month - 1], bnDigits(d.year)]),
      TaskSpan.year => trf('{0} সালের যেকোনো সময়', [bnDigits(d.year)]),
      TaskSpan.day => sayWhen(d, now, withTime: false),
    };
    if (t.lateAt(now) && t.deadline == null) {
      // Late: said with the day it was planned for (kept as it was).
      when = trf('দেরি হয়ে গেছে — ছিল {0}', [shortDate(d)]);
    } else if (t.windowPassed(now)) {
      // A plan for a week/month/year that is over: to look at again — not
      // "late" on a date that was never said.
      when = switch (t.span) {
        TaskSpan.week => trf('{0}-এর সপ্তাহের পরিকল্পনা — সময় পেরিয়েছে', [shortDate(d)]),
        TaskSpan.month => trf('{0} মাসের পরিকল্পনা — সময় পেরিয়েছে', [bnMonths[d.month - 1]]),
        _ => trf('{0} সালের পরিকল্পনা — সময় পেরিয়েছে', [bnDigits(d.year)]),
      };
    } else {
      when = said;
    }
  }
  return when;
}

/// "প্রতি শুক্রবার", "প্রতি মাসের ১০ তারিখে", "২ দিন পরপর".
String repeatLabel(TaskRepeat r) => switch (r.kind) {
      'daily' => tr('প্রতিদিন'),
      'weekly' => trf('প্রতি {0}', [nameList([for (final d in r.weekdays) dayName(d)], unit: 'দিন')]),
      'monthly' => trf('প্রতি মাসের {0} তারিখে', [bnDigits(r.monthDay)]),
      _ => trf('{0} দিন পরপর', [bnDigits(r.every)]),
    };

/// The line under a to-do on its page: when (a day, a week, a month…),
/// how often, জরুরি, and its note.
String? taskWhenText(Task t, DateTime now) {
  final parts = <String>[];
  if (t.repeat != null) parts.add(repeatLabel(t.repeat!));
  final m = RegExp(r'\((.*)\)$').firstMatch(taskLine(t, now));
  if (m != null) parts.add(m[1]!);
  if (t.note.isNotEmpty) parts.add(t.note);
  return parts.isEmpty ? null : parts.join(' · ');
}

DateTime _weekStartOf(DateTime d) => weekStartOf(d);

/// The answer to a to-do question, and the to-dos it named in order (so
/// "দ্বিতীয়টা হয়ে গেছে" right after knows which one). Only what is on the
/// list is said: an empty list is "no to-do kept", never "you are free".
(String, List<Task>) taskScopeAnswer(AppData d, TaskScope s, DateTime now, [String asked = '']) {
  final label = s.label;
  final tasks = scopedTasks(d, s, now);
  if (s.suggest) {
    final open = scopedTasks(d, const TaskScope(), now);
    if (open.isEmpty) return (tr('এখন কোনো কাজ বাকি নেই।'), const []);
    final today = dayOnly(now);
    final t = open.first;
    final why = t.lateAt(now) || t.windowPassed(now)
        ? tr('এর সময় পেরিয়ে গেছে')
        : t.urgent
            ? tr('এটা জরুরি হিসেবে রাখা')
            : (t.due != null && dayOnly(t.due!) == today ? tr('এটা আজকের মধ্যে করার কথা') : tr('তালিকায় এটার তারিখ সবার আগে'));
    return (trf('আমার পরামর্শ: “{0}” আগে করতে পারেন — {1}।', [t.title, why]), [t]);
  }
  if (s.soonest) {
    final dated = [for (final t in scopedTasks(d, const TaskScope(), now)) if (t.due != null) t]..sort((a, b) => a.due!.compareTo(b.due!));
    if (dated.isEmpty) return (tr('তারিখ দেওয়া কোনো বাকি কাজ নেই।'), const []);
    return (trf('সবার আগে “{0}” — {1}।', [dated.first.title, taskLine(dated.first, now).replaceFirst('${dated.first.title} ', '').replaceAll(RegExp(r'^\(|\)$'), '')]), [dated.first]);
  }
  if (s.doneOnly) {
    final when = label.isEmpty ? tr('আজ') : label;
    if (tasks.isEmpty) return (trf('{0} এখনো কোনো কাজ শেষ হিসেবে দাগ দেওয়া হয়নি।', [when]), const []);
    return (trf('{0} {1}টা কাজ শেষ করেছেন — {2}।', [when, bnDigits(tasks.length), nameList([for (final t in tasks) t.title], unit: 'টা')]), tasks);
  }
  // One day: the same list home and the কাজ page show for it (to-dos and reminders).
  if (s.from != null && s.from == s.to && s.about.isEmpty && !s.withOverdue) {
    final items = planItemsOn(d, s.from!, now);
    final shown = [for (final i in items) if (i.task != null) i.task!];
    final when = label.isEmpty ? sayWhen(s.from!, now, withTime: false) : label;
    final part = dayPartAsked(asked);
    if (part != null) return (dayPartAnswer(d, items, part, sayWhen(s.from!, now, withTime: false)), shown);
    if (items.isEmpty) {
      return (s.free ? trf('{0} এই অ্যাপের তালিকায় কোনো কাজ বা রিমাইন্ডার রাখা নেই।', [when]) : trf('{0} কোনো কাজ বা রিমাইন্ডার রাখা নেই।', [when]), const []);
    }
    String line(PlanItem i) => i.reminder != null ? '${i.title} (${bnTime(i.sort.hour, i.sort.minute)})' : taskLine(i.task!, now).replaceAll(' (${sayWhen(s.from!, now, withTime: false)})', '');
    final head = s.free ? trf('{0} তালিকায় {1}টা রাখা আছে', [when, bnDigits(items.length)]) : trf('{0} {1}টা', [when, bnDigits(items.length)]);
    return (trf('{0} — {1}।', [head, nameList([for (final i in items) line(i)], unit: 'টা')]), shown);
  }
  final what = s.about.isEmpty ? '' : trf('“{0}” নিয়ে ', [s.about.join(' ')]);
  if (tasks.isEmpty) {
    if (s.undated) return (tr('তারিখ ছাড়া কোনো কাজ রাখা নেই।'), const []);
    if (s.overdue) return (tr('সময় পেরিয়ে গেছে এমন কোনো কাজ নেই।'), const []);
    if (s.about.isNotEmpty) return (trf('{0}কোনো বাকি কাজ তালিকায় পেলাম না।', [what]), const []);
    if (label.isEmpty) return (tr('এখন কোনো অসমাপ্ত কাজ নেই। নতুন কাজ বললে তালিকায় তুলে রাখব।'), const []);
    // "এই মাসে কি কি কাজ আছে?" with only to-dos without a date: said, not hidden.
    final loose = [for (final t in openTasksOf(d, now)) if (t.due == null && t.deadline == null) t];
    final also = loose.isEmpty ? '' : trf(' তবে তারিখ ছাড়া {0}টা কাজ আছে — {1}।', [bnDigits(loose.length), nameList([for (final t in loose.take(8)) t.title], unit: 'টা')]);
    return ((s.free ? trf('{0} এই অ্যাপের তালিকায় কোনো কাজ রাখা নেই।', [label]) : trf('{0} কোনো কাজ রাখা নেই।', [label])) + also, loose);
  }
  // "ওষুধ আনার কাজ রেখেছিলাম?": yes, and how it stands.
  if (s.about.isNotEmpty && tasks.length == 1 && label.isEmpty) {
    final t = tasks.first;
    final when = taskLine(t, now).replaceFirst(t.title, '').trim().replaceAll(RegExp(r'^\(|\)$'), '');
    return (trf('হ্যাঁ, “{0}” তালিকায় আছে{1} — এখনো বাকি।', [t.title, when.isEmpty ? '' : ' ($when)']), tasks);
  }
  final lead = label.isEmpty ? '' : '$label ';
  final count = trf('{0}{1}{2}টা কাজ বাকি', [lead, what, bnDigits(tasks.length)]);
  if (s.count && tasks.length > 4) return (trf('{0}। প্রথমগুলো — {1}।', [count, nameList([for (final t in tasks.take(3)) taskLine(t, now)], unit: 'টা')]), tasks);
  return (trf('{0} — {1}।', [count, nameList([for (final t in tasks) taskLine(t, now)], unit: 'টা')]), tasks);
}

/// "এই মাসে কত খরচ হলো?" / "রহিম ভবন প্রজেক্টে কত আছে?"
String cashAnswer(AppData d, CashQuery q, DateTime now) {
  final name = q.project;
  // "অন্যান্য হিসাব দাও": every separate account at a glance.
  if (name != null && name.isEmpty) {
    if (d.projects.isEmpty) return tr('এখনো অন্যান্য কোনো হিসাব খোলা হয়নি। বলুন, যেমন “মৃত্তিকা ফাউন্ডেশন নামে অন্যান্য হিসাব খোলো”।');
    final lines = [
      for (final p in d.projects)
        () {
          final x = projectSums(d.cash, p.id);
          final state = x.income == 0 && x.expense == 0
              ? tr('এখনো কিছু লেখা নেই')
              : x.income == 0
                  ? trf('খরচ {0} টাকা', [bnNumber(x.expense)])
                  : trf('এসেছে {0}, খরচ {1} — হাতে {2} টাকা', [bnNumber(x.income), bnNumber(x.expense), bnNumber(x.balance)]);
          return '• ${p.name}${p.closed ? tr(' (শেষ)') : ''} — $state';
        }(),
    ];
    // "অন্যান্য হিসাবের ভেতরের সব দাও": what is written in each, too.
    final inside = RegExp(fold(r'(?:সব|সকল|ভেত|ভিত|বিস্তারিত|লেনদেন|এন্ট্রি)')).hasMatch(fold(normalize(q.transcript)));
    if (inside) {
      return [
        trf('অন্যান্য হিসাব {0}টা:', [bnDigits(d.projects.length)]),
        for (final p in d.projects) ...[
          lines[d.projects.indexOf(p)],
          ...projectEntryLines(d, p.id),
        ],
      ].join('\n');
    }
    return [trf('অন্যান্য হিসাব {0}টা:', [bnDigits(d.projects.length)]), ...lines].join('\n');
  }
  if (name != null) {
    final p = projectByName(d, name);
    if (p == null) {
      return d.projects.isEmpty
          ? tr('এখনো অন্যান্য কোনো হিসাব খোলা হয়নি। বলুন, যেমন “রহিম ভবন প্রজেক্টে ৫০ হাজার টাকা এলো”।')
          : trf('{0} খুঁজে পাইনি। আছে: {1}।', [name.isEmpty ? 'কোন হিসাব' : '‘$name’ নামে হিসাব', nameList([for (final x in d.projects) x.name], unit: 'টা')]);
    }
    final s = projectSums(d.cash, p.id);
    if (s.income == 0 && s.expense == 0) return trf('‘{0}’ হিসাবে টাকা আসা বা খরচের কোনো তথ্য নেই।', [p.name]);
    final String head;
    if (s.income == 0) {
      head = trf('‘{0}’ হিসাবে এ পর্যন্ত খরচ {1} টাকা।', [p.name, bnNumber(s.expense)]);
    } else if (s.expense == 0) {
      head = trf('‘{0}’ হিসাবে এসেছে {1} টাকা, এখনো খরচ হয়নি।', [p.name, bnNumber(s.income)]);
    } else {
      head = trf('‘{0}’ হিসাবে এসেছে {1} টাকা, খরচ {2} টাকা — {3}।',
          [p.name, bnNumber(s.income), bnNumber(s.expense), s.balance >= 0 ? trf('হাতে আছে {0} টাকা', [bnNumber(s.balance)]) : trf('আসার চেয়ে {0} টাকা বেশি খরচ', [bnNumber(-s.balance)])]);
    }
    // "… হিসাব দাও": the entries too, not only the totals ("কত" asks only the sum).
    final total = RegExp(fold(r'(?:কত|কতো)')).hasMatch(fold(normalize(q.transcript)));
    return total ? head : [head, ...projectEntryLines(d, p.id)].join('\n');
  }
  // "আয়ের খাত গুলো কি কি", "কিভাবে ব্যয় হয়েছে?": this month by খাত.
  final byCat = categoryAsked(q.transcript);
  if (byCat != null) {
    final m = monthSums(d.cash, now);
    final rows = byCat == CashKind.income ? m.topIncome : m.topExpenses;
    final total = byCat == CashKind.income ? m.income : m.expense;
    if (rows.isEmpty) return byCat == CashKind.income ? tr('এই মাসে কোনো আয় লেখা নেই।') : tr('এই মাসে কোনো খরচ লেখা নেই।');
    return [
      trf(byCat == CashKind.income ? 'এই মাসে আয় {0} টাকা, {1}টা খাতে:' : 'এই মাসে খরচ {0} টাকা, {1}টা খাতে:', [bnNumber(total), bnDigits(rows.length)]),
      for (final r in rows) trf('• {0} — {1} টাকা', [r.key, bnNumber(r.value)]),
    ].join('\n');
  }
  final s = monthSums(d.cash, now);
  if (s.income == 0 && s.expense == 0) return tr('এই মাসের আয়-খরচের কোনো তথ্য নেই। বলুন, যেমন “বাজারে ৫০০ টাকা খরচ হলো” — পরে জিজ্ঞেস করলেই হিসাব দেবো।');
  final top = s.topExpenses;
  final most = top.isEmpty ? '' : trf(' সবচেয়ে বেশি খরচ {0} খাতে — {1} টাকা।', [top.first.key, bnNumber(top.first.value)]);
  if (s.income == 0) return trf('এই মাসে খরচ হয়েছে {0} টাকা।{1}', [bnNumber(s.expense), most]);
  // "এই মাসে কত খরচ হলো?" is about spending: that comes first.
  final t = normalize(q.transcript);
  final aboutSpend = RegExp(fold('(?:খরচ|ব্যয়)')).hasMatch(t) && !RegExp(fold('(?:আয়|ইনকাম)')).hasMatch(t);
  if (s.expense == 0) {
    return aboutSpend ? trf('এই মাসে খরচের কোনো তথ্য নেই (আয় লেখা আছে {0} টাকা)।', [bnNumber(s.income)]) : trf('এই মাসে আয় {0} টাকা; খরচের কোনো তথ্য নেই।', [bnNumber(s.income)]);
  }
  if (aboutSpend) {
    return trf('এই মাসে খরচ হয়েছে {0} টাকা।{1} (আয় {2} টাকা — {3}।)', [
      bnNumber(s.expense),
      most,
      bnNumber(s.income),
      s.balance >= 0 ? trf('ব্যালেন্স {0} টাকা', [bnNumber(s.balance)]) : trf('আয়ের চেয়ে {0} টাকা বেশি খরচ হয়েছে', [bnNumber(-s.balance)]),
    ]);
  }
  return trf('এই মাসে আয় {0} টাকা, খরচ {1} টাকা — {2}।{3}', [
    bnNumber(s.income),
    bnNumber(s.expense),
    s.balance >= 0 ? trf('ব্যালেন্স {0} টাকা', [bnNumber(s.balance)]) : trf('আয়ের চেয়ে {0} টাকা বেশি খরচ হয়েছে', [bnNumber(-s.balance)]),
    most,
  ]);
}

/// "আজ আমার কী কী আছে?" — the day at a glance.
String briefingAnswer(AppData d, DateTime now) {
  final today = dayOnly(now);
  final parts = <String>['আজ ${weekdayName(now)}, ${bnDigits(now.day)} ${monthName(now.month)}।'];
  final dueNow = openTasksOf(d, now).where((t) => t.due == null || !t.due!.isAfter(today)).toList();
  if (dueNow.isNotEmpty) {
    parts.add(trf('কাজ বাকি {0}টা — {1}।', [bnDigits(dueNow.length), nameList([for (final t in dueNow) t.title], unit: 'টা')]));
  }
  final rems = [...d.reminders]..sort((a, b) => a.notifyAt(now).compareTo(b.notifyAt(now)));
  final todays = rems.where((r) => dayOnly(r.nextDate(now)) == today).toList();
  final tomorrows = rems.where((r) => dayOnly(r.nextDate(now)) == today.add(const Duration(days: 1))).toList();
  if (todays.isNotEmpty) {
    parts.add(trf('আজ মনে রাখার: {0}।', [nameList([for (final r in todays) r.daysBefore == 0 ? '${bnTime(r.hour, r.minute)} ${r.title}' : r.title], unit: 'টা')]));
  }
  if (tomorrows.isNotEmpty) parts.add(trf('কাল আছে: {0}।', [nameList([for (final r in tomorrows) r.title], unit: 'টা')]));
  final t = totals(d.ledger);
  if (t.receivable > 0) parts.add(trf('পাওনা আছে মোট {0} টাকা।', [bnNumber(t.receivable)]));
  if (t.payable > 0) parts.add(trf('আপনাকে দিতে হবে মোট {0} টাকা।', [bnNumber(t.payable)]));
  final month = monthSums(d.cash, now);
  if (month.expense > 0) parts.add(trf('এই মাসে খরচ হয়েছে {0} টাকা।', [bnNumber(month.expense)]));
  if (parts.length == 1) parts.add(tr('আজ তেমন কিছু রাখা নেই — কোনো কাজ বা মনে করানোর কথা নেই। কিছু থাকলে বলুন, লিখে রাখি।'));
  return parts.join(' ');
}

/// "আমার সংরক্ষিত ফোন নম্বর দেখাও": how many, and a few names (the
/// numbers themselves are on the যোগাযোগ page).
String contactsAnswer(AppData d) {
  final n = d.contacts.length;
  if (n == 0) return tr('এখনো কোনো নম্বর রাখা নেই। “যোগাযোগ” পাতা থেকে ফোনবুকের সব নম্বর এক চাপে আনতে পারেন।');
  final names = ([...d.contacts]..sort((a, b) => a.name.compareTo(b.name))).take(4).map((c) => c.name).toList();
  return trf('{0} জনের নম্বর রাখা আছে{1}। সব দেখতে নিচে চাপুন।', [bnDigits(n), n > names.length ? ' — যেমন ${nameList(names, unit: 'জন')}' : ' — ${nameList(names, unit: 'জন')}']);
}

/// The answer to a question or a bit of conversation. Null for commands
/// that save or do something (those are confirmed or done instead).
String? answerText(AppData d, Command cmd, DateTime now) => switch (cmd) {
      LedgerQuery() => ledgerAnswer(d, cmd, now),
      VaultQuery() => vaultAnswer(d, cmd),
      ReminderQuery() => reminderAnswer(d, cmd, now),
      SearchQuery() => searchAnswer(d, cmd, now),
      SmallTalk() => cmd.kind == Talk.calendar ? calendarAnswer(cmd.transcript, now) : talkReply(cmd.kind, now),
      AiReply() => cmd.text,
      TaskQuery(:final scope?, :final transcript) => taskScopeAnswer(d, scope, now, transcript).$1,
      TaskQuery(:final transcript) => taskAnswer(d, now, transcript),
      CashQuery() => cashAnswer(d, cmd, now),
      MoneyListQuery() => moneyListAnswer(d, cmd),
      Clarify() => cmd.question,
      Briefing() => briefingAnswer(d, now),
      ContactsQuery() => contactsAnswer(d),
      HealthQuery() => healthAnswer(d, cmd.what, now, member: cmd.member),
      NotUnderstood() => _notUnderstood(cmd),
      ProfileQuery() => profileAnswer(d, cmd.transcript) ?? infoAnswer(d, cmd.transcript, now) ?? kindAnswer(d, kindAsked(normalize(cmd.transcript)) ?? 'papers'),
      OpenPlace() || ProfileSet() || ManageItem() ||
      LedgerAdd() || LedgerSet() || NoteAdd() || TaskAdd() || TasksClear() || TaskDone() || TaskEdit() || TaskRestore() || ReminderSnooze() || MenuAction() || BulkAction() || ReminderAdd() || ContactAdd() || CallPerson() || CashAdd() || VaultAdd() || MemoryAdd() || SpecialAdd() || HealthAdd() => null,
    };

/// The money records of [q] (লেনদেন book and আয়-ব্যয়), newest first.
/// Only these two are looked in — a phone number or a note is never an
/// answer to a money question.
({List<LedgerEntry> ledger, List<CashEntry> cash}) moneyRecords(AppData d, MoneyListQuery q) {
  bool inSpan(DateTime x) => !x.isBefore(q.from) && x.isBefore(q.to);
  final ledger = q.category != null
      ? <LedgerEntry>[]
      : [for (final e in d.ledger) if (inSpan(e.date) && (q.person == null || personKey(e.person) == personKey(q.person!))) e];
  final cash = q.person != null
      ? <CashEntry>[]
      : [for (final e in d.cash) if (inSpan(e.date) && (q.category == null || e.category == q.category || (q.category == 'অন্যান্য' && e.category.trim().isEmpty))) e];
  ledger.sort((a, b) => b.date.compareTo(a.date));
  cash.sort((a, b) => b.date.compareTo(a.date));
  return (ledger: ledger, cash: cash);
}

String moneyListAnswer(AppData d, MoneyListQuery q) {
  final r = moneyRecords(d, q);
  final what = q.category != null ? trf('‘{0}’ খাতে', [q.category!]) : (q.person != null ? trf('{0} সাথে', [possessive(q.person!)]) : '');
  final n = r.ledger.length + r.cash.length;
  if (n == 0) return trf('{0} {1} কোনো লেনদেন পাওয়া যায়নি।', [q.label, what]).replaceAll('  ', ' ');
  final income = r.cash.where((e) => e.kind == CashKind.income).fold(0, (a, e) => a + e.amount);
  final spent = r.cash.where((e) => e.kind == CashKind.expense).fold(0, (a, e) => a + e.amount);
  final parts = [
    if (income > 0) trf('আয় {0} টাকা', [bnNumber(income)]),
    if (spent > 0) trf('খরচ {0} টাকা', [bnNumber(spent)]),
    if (r.ledger.isNotEmpty) trf('ধার-দেনার {0}টা লেনদেন', [bnDigits(r.ledger.length)]),
  ];
  return trf('{0} {1} {2}টা লেনদেন — {3}।', [q.label, what, bnDigits(n), parts.join(', ')]).replaceAll('  ', ' ');
}

/// One line per record, for the list under the answer.
List<String> moneyLines(AppData d, MoneyListQuery q, {int max = 8}) {
  final r = moneyRecords(d, q);
  final lines = <(DateTime, String)>[
    for (final e in r.cash) (e.date, '${shortDate(e.date)} · ${e.kind == CashKind.income ? tr('আয়') : tr('খরচ')} · ${e.category} · ${taka(e.amount)}'),
    for (final e in r.ledger) (e.date, '${shortDate(e.date)} · ${describe(e.kind, e.person, e.amount)}'),
  ]..sort((a, b) => b.$1.compareTo(a.$1));
  final shown = [for (final l in lines.take(max)) l.$2];
  if (lines.length > max) shown.add(trf('আরও {0}টা…', [bnDigits(lines.length - max)]));
  return shown;
}

String _notUnderstood(NotUnderstood c) {
  final p = placeMentioned(normalize(c.transcript));
  if (p != null) return trf('ঠিক বুঝিনি। {0} দেখতে চাইলে নিচে চাপুন, বা বলুন “{0} খোলো”।', [tr(p.title)]);
  return tr('ঠিক বুঝতে পারিনি। একটু অন্যভাবে বলবেন?');
}

/// The saved contact for a spoken name ("রহিম", "রহিম ভাই", "Rahim").
/// Respect words around a name ("ভাই", "আপা", "Bhai", "Sir"…). They are
/// left out when matching, so "মোবারক ভাই" does not match every "… Bhai".
final _respect = {
  for (final w in const [
    'ভাই', 'ভাইয়া', 'ভাইয়া', 'ভাইজান', 'ভাইসাব', 'ভাবি', 'ভাবী', 'আপা', 'আপু', 'বোন', 'স্যার', 'সাহেব', 'সাব', 'দাদা', 'দিদি',
    'জনাব', 'মিস্টার', 'ডাক্তার', 'ডা', 'ডাঃ', 'মোঃ', 'মো', 'মোহাম্মদ', 'মুহাম্মদ', 'মোহাম্মাদ', 'হাজী', 'আলহাজ্ব',
    'bhai', 'vai', 'bhaiya', 'vaiya', 'bhaia', 'bro', 'apa', 'apu', 'sir', 'saheb', 'sahab', 'shaheb', 'dada', 'didi', 'mr', 'mrs', 'ms',
    'dr', 'md', 'mohammad', 'muhammad', 'mohammed', 'mohd', 'haji', 'alhaj',
  ])
    fold(w.toLowerCase()),
};

/// [_nameWords] without the possessive taken off — "হায়দার" stays
/// "হায়দার" (its "র" is part of the name, not "-এর").
List<String> _nameWordsFull(String name) => [
      for (final w in name.toLowerCase().replaceAll(RegExp(r'[।?!,.;:()\-_/]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) => fold(w)))
        RegExp(r'[ঀ-৿]').hasMatch(w) ? stripTo(w) : w
    ];

List<String> _nameWords(String name) {
  final ws = name
      .toLowerCase()
      .replaceAll(RegExp(r'[।?!,.;:()\-_/]'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => fold(w))
      .toList();
  return [for (final w in ws) RegExp(r'[ঀ-৿]').hasMatch(w) ? stripTo(stripPossessive(w)) : w];
}

/// The words of a name that tell people apart (respect words left out,
/// unless there is nothing else: "মামা").
List<String> nameCore(String name) {
  final ws = _nameWords(name);
  final core = ws.where((w) => !_respect.contains(w)).toList();
  return core.isEmpty ? ws : core;
}

bool _sameWord(String a, String b) {
  if (a == b) return true;
  final sa = skeleton(a), sb = skeleton(b);
  if (sa.length >= 2 && sa == sb) return true;
  return sa.length >= 4 && sb.length >= 4 && wordsMatch(a, b) && (sa.length - sb.length).abs() <= 1;
}

/// Everyone in যোগাযোগ whose name has every word of [name] (in Bengali or
/// English letters: "মোবারক" = "Mobarak"), closest first. Two or more means
/// the app must ask which one — it never guesses between people.
List<Contact> contactMatches(AppData d, String name) {
  final q = nameCore(name);
  if (q.isEmpty) return const [];
  // The same words before a possessive was taken off, for the loose
  // (sound-alike) match: "হায়দার" must not become "হায়দা" ≈ "Ahad".
  final fullAll = _nameWordsFull(name);
  final full = fullAll.length == _nameWords(name).length ? [for (var i = 0; i < fullAll.length; i++) if (!_respect.contains(_nameWords(name)[i])) fullAll[i]] : q;
  final scored = <(Contact, int)>[];
  // How far each one sounds from what was said ("Robin" 0, "Rabbani" 3 for
  // "রবিন"): a sound-alike is offered only when nothing closer is there.
  final far = <String, int>{};
  for (final c in d.contacts) {
    final cw = nameCore(c.name);
    if (cw.isEmpty) continue;
    final used = <int>{};
    var exact = 0;
    var dist = 0;
    var ok = true;
    for (var qi = 0; qi < q.length; qi++) {
      final w = q[qi];
      final wf = qi < full.length ? full[qi] : w;
      var hit = -1;
      for (var i = 0; i < cw.length; i++) {
        if (used.contains(i)) continue;
        if (cw[i] == w) {
          hit = i;
          exact++;
          break;
        }
      }
      if (hit < 0) {
        for (var i = 0; i < cw.length; i++) {
          // Sound-alike only on the word as said; the shortened form only
          // against a name written in Bengali letters.
          final bn = RegExp(r'[ঀ-৿]').hasMatch(cw[i]);
          if (!used.contains(i) && (_sameWord(wf, cw[i]) || (bn && _sameWord(w, cw[i])) || (wf != w && w.length > 2 && _sameWord(w, cw[i]) && skeleton(w).length >= 3))) {
            hit = i;
            break;
          }
        }
      }
      if (hit < 0) {
        ok = false;
        break;
      }
      if (cw[hit] != w) dist += soundDistance(wf, cw[hit]);
      used.add(hit);
    }
    if (!ok) continue;
    far[c.id] = dist;
    // Closer: more words spelled the same, fewer extra words in the name.
    scored.add((c, exact * 10 - (cw.length - q.length)));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  final closest = far.values.fold<int?>(null, (m, x) => m == null || x < m ? x : m) ?? 0;
  // The same number saved twice is one person.
  final seen = <String>{};
  return [
    for (final (c, _) in scored)
      if ((far[c.id] ?? 0) <= closest + 1 && seen.add(phoneKey(c.phone).isEmpty ? c.id : phoneKey(c.phone))) c,
  ];
}

/// The one contact [name] means, or null when there is none or more than
/// one (then ask).
Contact? findContact(AppData d, String name) {
  final n = normalize(name);
  if (n.isEmpty) return null;
  final exact = d.contacts.where((c) => normalize(c.name) == n).toList();
  if (exact.length == 1) return exact.single;
  final m = contactMatches(d, name);
  return m.length == 1 ? m.single : null;
}

/// Income or spending asked by খাত: "আয়ের খাত গুলো কি কি", "কিভাবে আয়
/// হয়েছে?", "কোন কোন খাতে খরচ হলো". Null when not.
CashKind? categoryAsked(String said) {
  final f = ' ${fold(normalize(said))} ';
  if (findAmount(normalize(said)) != null) return null;
  if (!RegExp(fold(r'(?:কি|কী|কোন|কোনো|কিভাবে|কীভাবে|কি\s+ভাবে|কোথা|কিসে|দাও|দিন|দেখাও|দেখান|বলো|বলুন|লিস্ট|তালিকা)')).hasMatch(f) && !said.contains('?')) return null;
  final how = RegExp(fold(r'(?:খাত|কিভাবে|কীভাবে|কি\s+ভাবে|কী\s+ভাবে|কোথা\s+থেকে|কোথায়\s+কোথায়|কিসে\s+কিসে|কোন\s+কোন\s+খাতে)')).hasMatch(f);
  if (!how) return null;
  final spend = RegExp(fold(r'(?:খরচ|ব্যয়)')).hasMatch(f);
  final earn = RegExp(fold(r'(?:আয়|ইনকাম|আসছে|এসেছে)')).hasMatch(f);
  if (spend == earn) return null;
  return spend ? CashKind.expense : CashKind.income;
}

/// The entries of one অন্যান্য হিসাব, latest first (at most [max]).
List<String> projectEntryLines(AppData d, String projectId, {int max = 8}) {
  final es = [for (final e in d.cash) if (e.projectId == projectId) e]..sort((a, b) => b.date.compareTo(a.date));
  return [
    for (final e in es.take(max))
      () {
        final what = cashItem(e.note);
        final label = what.isEmpty || normalize(what) == normalize(e.category) ? e.category : '${e.category} ($what)';
        return trf('   – {0}: {1} — {2} টাকা', [e.kind == CashKind.income ? tr('এসেছে') : tr('খরচ'), label, bnNumber(e.amount)]);
      }(),
    if (es.length > max) trf('   – আরও {0}টা', [bnDigits(es.length - max)]),
  ];
}

/// One note in a list: "title — text", but the text alone when the title is
/// only its beginning ("৭ তারিখে হিরার জন্মদিন" twice reads once).
String noteLine(Note n) {
  final title = n.title.trim().replaceAll(RegExp(r'(?:…|\.\.\.)$'), '').trim();
  final body = n.body.trim();
  if (title.isEmpty) return body;
  if (body.isEmpty) return n.title.trim();
  if (normalize(body).startsWith(normalize(title))) return body;
  return '${n.title.trim()} — $body';
}
