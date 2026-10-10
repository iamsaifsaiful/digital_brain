/// The spoken answers to questions, shared by the chat and the answer
/// screen. Passwords are never part of an answer.
library;

import '../models/models.dart';
import 'bn.dart';
import 'cash.dart';
import 'ledger.dart';
import 'match.dart';
import 'parser.dart';
import 'phrases.dart';
import 'search.dart';
import 'talk.dart';
import 'when.dart';

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
        ? 'এই যে আপনার রাখা লগইনগুলো। কোনটা লাগবে ছুঁয়ে খুলুন — আঙুলের ছাপ বা PIN লাগবে।'
        : 'নাম দিয়ে ঠিক মেলাতে পারিনি। আপনার রাখা লগইনগুলো নিচে আছে, কোনটা লাগবে দেখে নিন।';
  }
  if (found.isEmpty) {
    return q.wifiOnly ? 'Wi-Fi-এর কোনো তথ্য এখনো রাখা হয়নি। চাইলে এখনই রেখে দিতে পারেন।' : 'এখনো কোনো পাসওয়ার্ড রাখা হয়নি। চাইলে এখনই রেখে দিতে পারেন।';
  }
  if (found.length == 1) {
    return '${possessive(found.first.name)} তথ্য পেয়েছি! তবে পাসওয়ার্ড গোপন জিনিস, তাই জোরে বলব না। আঙুলের ছাপ দিয়ে খুলুন, স্ক্রিনে দেখাব।';
  }
  return '${bnDigits(found.length)}টা মিলেছে। কোনটা লাগবে ছুঁয়ে খুলুন — আঙুলের ছাপ বা PIN লাগবে।';
}

/// "• সন্ধ্যা ৬টা ২০ — বাজার" lines for reminders.
String _reminderLines(Iterable<Reminder> rs, DateTime now, {bool withDay = false}) => [
      for (final r in rs)
        '• ${withDay ? '${sayWhen(r.nextDate(now), now, withTime: false)} ' : ''}${bnTime(r.hour, r.minute)} — ${r.title}',
    ].join('\n');

String reminderAnswer(AppData d, ReminderQuery q, DateTime now) {
  // "আজ কোন রিমাইন্ডার আছে?", "কালকের রিমাইন্ডার": every one on that day.
  final w = parseWhen(q.transcript, now);
  final sorted = [...d.reminders]
    ..sort((a, b) => DateTime(a.nextDate(now).year, a.nextDate(now).month, a.nextDate(now).day, a.hour, a.minute)
        .compareTo(DateTime(b.nextDate(now).year, b.nextDate(now).month, b.nextDate(now).day, b.hour, b.minute)));
  if (w != null && w.hasDay) {
    final onDay = sorted.where((r) => dayOnly(r.nextDate(now)) == w.day).toList();
    final dayText = sayWhen(w.day, now, withTime: false);
    if (onDay.isEmpty) return '$dayText কোনো রিমাইন্ডার নেই। রাখতে চাইলে বলুন — যেমন “সন্ধ্যা ৭টায় মিটিং মনে করিয়ে দিও”।';
    return '$dayText ${bnDigits(onDay.length)}টা রিমাইন্ডার আছে:\n${_reminderLines(onDay, now)}';
  }
  final found = searchReminders(d, q.terms);
  if (found.isEmpty) {
    final upcoming = sorted.where((r) => !r.nextDate(now).isBefore(dayOnly(now))).take(5).toList();
    if (upcoming.isEmpty) return 'এখনো কোনো রিমাইন্ডার রাখা নেই। রাখতে চাইলে বলুন — যেমন “কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও”।';
    return 'ঠিক এই নামে কিছু পেলাম না। সামনের রিমাইন্ডারগুলো:\n${_reminderLines(upcoming, now, withDay: true)}';
  }
  final r = found.first;
  final day = r.nextDate(now);
  final left = dayOnly(day).difference(dayOnly(now)).inDays;
  final when = left == 0 ? 'মানে আজকেই' : (left == 1 ? 'মানে কালকেই' : (left > 0 ? 'আর ${bnDigits(left)} দিন আছে' : '${bnDigits(-left)} দিন আগে চলে গেছে'));
  return '${r.title} ${weekdayName(day)}, ${bnDigits(day.day)} ${bnMonths[day.month - 1]}। $when।';
}

String searchAnswer(AppData d, SearchQuery q, DateTime now) {
  final hits = searchAll(d, q.terms);
  if (hits.isEmpty) return 'এ নিয়ে আমার কাছে কিছু লেখা নেই। চাইলে এখনই রেখে দিতে পারেন।';
  // Say the best match itself, not just "found N things".
  final best = hits.first;
  final tied = hits.where((h) => h.score == best.score).length;
  final lead = tied > 1 ? 'কয়েকটা মিলেছে। সবচেয়ে কাছেরটা হলো — ' : '';
  return '$lead${hitAnswer(d, best, now)}';
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
        '${reminder.title} ${weekdayName(reminder.nextDate(now))}, ${bnDigits(reminder.nextDate(now).day)} ${bnMonths[reminder.nextDate(now).month - 1]}'),
    PersonHit(:final person) => end(owesText(person, balanceWith(d.ledger, person))),
    VaultHit(:final item) => '${possessive(item.name)} তথ্য পেয়েছি! তবে এটা গোপন জিনিস, তাই জোরে বলব না। আঙুলের ছাপ দিয়ে খুলুন, স্ক্রিনে দেখাব।',
  };
}

String ledgerAnswer(AppData d, LedgerQuery q) {
  final all = balances(d.ledger);
  switch (q.ask) {
    case LedgerAsk.person:
      final p = balanceOf(d.ledger, q.person!);
      if (p == null) return '${possessive(q.person!)} সাথে তো কোনো হিসাব লেখা নেই।';
      final hist = runningFor(d.ledger, p.name);
      final last = hist.isEmpty ? null : hist.last.$1;
      final lastText = last == null ? '' : ' শেষ লেনদেন ছিল ${bnDigits(last.date.day)} ${bnMonths[last.date.month - 1]}।';
      return '${owesText(p.name, p.balance)}।$lastText';
    case LedgerAsk.receivable:
      final owe = all.where((p) => p.balance > 0).toList();
      if (owe.isEmpty) return 'এখন কারও কাছে আপনার কিছু পাওনা নেই।';
      final sum = owe.fold<int>(0, (s, p) => s + p.balance);
      final who = nameList([for (final p in owe) '${possessive(p.name)} কাছে ${bnNumber(p.balance)}']);
      return 'সব মিলিয়ে আপনি ${bnNumber(sum)} টাকা পাবেন — $who।';
    case LedgerAsk.payable:
      final iOwe = all.where((p) => p.balance < 0).toList();
      if (iOwe.isEmpty) return 'কাউকে কিছু দিতে হবে না, সব শোধ!';
      final sum = iOwe.fold<int>(0, (s, p) => s - p.balance);
      final who = nameList([for (final p in iOwe) '${toPerson(p.name)} ${bnNumber(-p.balance)}']);
      return 'সব মিলিয়ে আপনাকে ${bnNumber(sum)} টাকা দিতে হবে — $who।';
    case LedgerAsk.all:
      final t = totals(d.ledger);
      return 'আপনি পাবেন মোট ${bnNumber(t.receivable)} টাকা, আর আপনাকে দিতে হবে ${bnNumber(t.payable)} টাকা।';
  }
}

/// "ক, খ, আর গ" (at most four, then "আরও N জন").
String nameList(List<String> parts, {String unit = 'জন'}) {
  final shown = parts.take(4).toList();
  final more = parts.length - shown.length;
  final head = shown.length > 1 ? '${shown.sublist(0, shown.length - 1).join(', ')}, আর ${shown.last}' : shown.join();
  return more > 0 ? '$head, এবং আরও ${bnDigits(more)} $unit' : head;
}

/// Open to-dos: overdue and today's first, then undated, then later ones.
List<Task> openTasksOf(AppData d, DateTime now) {
  final today = dayOnly(now);
  final open = d.tasks.where((t) => !t.done).toList();
  int rank(Task t) => t.due == null ? 1 : (t.due!.isAfter(today) ? 2 : 0);
  open.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    return (a.due ?? a.createdAt).compareTo(b.due ?? b.createdAt);
  });
  return open;
}

/// "ব্যাংকে যাওয়া (আজ)", "রিপোর্ট জমা (১২ অক্টোবর)".
String taskLabel(Task t, DateTime now) {
  if (t.due == null) return t.title;
  final diff = dayOnly(t.due!).difference(dayOnly(now)).inDays;
  final when = diff < 0 ? 'দেরি হয়ে গেছে' : sayWhen(t.due!, now, withTime: false);
  return '${t.title} ($when)';
}

String taskAnswer(AppData d, DateTime now) {
  final open = openTasksOf(d, now);
  if (open.isEmpty) return 'এখন কোনো কাজ বাকি নেই। নতুন কাজ বললে তালিকায় তুলে রাখব।';
  return '${bnDigits(open.length)}টা কাজ বাকি — ${nameList([for (final t in open) taskLabel(t, now)], unit: 'টা')}।';
}

/// "এই মাসে কত খরচ হলো?" / "রহিম ভবন প্রজেক্টে কত আছে?"
String cashAnswer(AppData d, CashQuery q, DateTime now) {
  final name = q.project;
  if (name != null) {
    final p = projectByName(d, name);
    if (p == null) {
      return d.projects.isEmpty
          ? 'এখনো কোনো প্রজেক্ট খোলা হয়নি। বলুন, যেমন “রহিম ভবন প্রজেক্টে ৫০ হাজার টাকা এলো”।'
          : '${name.isEmpty ? 'কোন প্রজেক্ট' : '‘$name’ নামে প্রজেক্ট'} খুঁজে পাইনি। আছে: ${nameList([for (final x in d.projects) x.name], unit: 'টা')}।';
    }
    final s = projectSums(d.cash, p.id);
    return '‘${p.name}’ প্রজেক্টে এসেছে ${bnNumber(s.income)} টাকা, খরচ হয়েছে ${bnNumber(s.expense)} টাকা, হাতে আছে ${bnNumber(s.balance)} টাকা।';
  }
  final s = monthSums(d.cash, now);
  if (s.income == 0 && s.expense == 0) return 'এই মাসে এখনো কোনো আয় বা খরচ লেখা হয়নি। বলুন, যেমন “বাজারে ৫০০ টাকা খরচ হলো”।';
  final top = s.topExpenses;
  final most = top.isEmpty ? '' : ' সবচেয়ে বেশি খরচ ${top.first.key} খাতে — ${bnNumber(top.first.value)} টাকা।';
  return 'এই মাসে আয় ${bnNumber(s.income)} টাকা, খরচ ${bnNumber(s.expense)} টাকা, '
      '${s.balance >= 0 ? 'সঞ্চয় ${bnNumber(s.balance)} টাকা' : 'আয়ের চেয়ে ${bnNumber(-s.balance)} টাকা বেশি খরচ'}।$most';
}

/// "আজ আমার কী কী আছে?" — the day at a glance.
String briefingAnswer(AppData d, DateTime now) {
  final today = dayOnly(now);
  final parts = <String>['আজ ${weekdayName(now)}, ${bnDigits(now.day)} ${bnMonths[now.month - 1]}।'];
  final dueNow = openTasksOf(d, now).where((t) => t.due == null || !t.due!.isAfter(today)).toList();
  if (dueNow.isNotEmpty) {
    parts.add('কাজ বাকি ${bnDigits(dueNow.length)}টা — ${nameList([for (final t in dueNow) t.title], unit: 'টা')}।');
  }
  final rems = [...d.reminders]..sort((a, b) => a.notifyAt(now).compareTo(b.notifyAt(now)));
  final todays = rems.where((r) => dayOnly(r.nextDate(now)) == today).toList();
  final tomorrows = rems.where((r) => dayOnly(r.nextDate(now)) == today.add(const Duration(days: 1))).toList();
  if (todays.isNotEmpty) {
    parts.add('আজ মনে রাখার: ${nameList([for (final r in todays) r.daysBefore == 0 ? '${bnTime(r.hour, r.minute)} ${r.title}' : r.title], unit: 'টা')}।');
  }
  if (tomorrows.isNotEmpty) parts.add('কাল আছে: ${nameList([for (final r in tomorrows) r.title], unit: 'টা')}।');
  final t = totals(d.ledger);
  if (t.receivable > 0) parts.add('পাওনা আছে মোট ${bnNumber(t.receivable)} টাকা।');
  if (t.payable > 0) parts.add('আপনাকে দিতে হবে মোট ${bnNumber(t.payable)} টাকা।');
  final month = monthSums(d.cash, now);
  if (month.expense > 0) parts.add('এই মাসে খরচ হয়েছে ${bnNumber(month.expense)} টাকা।');
  if (parts.length == 1) parts.add('আজ তেমন কিছু রাখা নেই — কোনো কাজ বা মনে করানোর কথা নেই। কিছু থাকলে বলুন, লিখে রাখি।');
  return parts.join(' ');
}

/// The answer to a question or a bit of conversation. Null for commands
/// that save or do something (those are confirmed or done instead).
String? answerText(AppData d, Command cmd, DateTime now) => switch (cmd) {
      LedgerQuery() => ledgerAnswer(d, cmd),
      VaultQuery() => vaultAnswer(d, cmd),
      ReminderQuery() => reminderAnswer(d, cmd, now),
      SearchQuery() => searchAnswer(d, cmd, now),
      SmallTalk() => talkReply(cmd.kind, now),
      AiReply() => cmd.text,
      TaskQuery() => taskAnswer(d, now),
      CashQuery() => cashAnswer(d, cmd, now),
      Briefing() => briefingAnswer(d, now),
      NotUnderstood() => 'দুঃখিত, ঠিক বুঝতে পারিনি। একটু অন্যভাবে আরেকবার বলবেন?',
      LedgerAdd() || LedgerSet() || NoteAdd() || TaskAdd() || TaskDone() || ReminderAdd() || ContactAdd() || CallPerson() || CashAdd() || VaultAdd() => null,
    };

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
  final scored = <(Contact, int)>[];
  for (final c in d.contacts) {
    final cw = nameCore(c.name);
    if (cw.isEmpty) continue;
    final used = <int>{};
    var exact = 0;
    var ok = true;
    for (final w in q) {
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
          if (!used.contains(i) && _sameWord(w, cw[i])) {
            hit = i;
            break;
          }
        }
      }
      if (hit < 0) {
        ok = false;
        break;
      }
      used.add(hit);
    }
    if (!ok) continue;
    // Closer: more words spelled the same, fewer extra words in the name.
    scored.add((c, exact * 10 - (cw.length - q.length)));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  // The same number saved twice is one person.
  final seen = <String>{};
  return [
    for (final (c, _) in scored)
      if (seen.add(phoneKey(c.phone).isEmpty ? c.id : phoneKey(c.phone))) c,
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
