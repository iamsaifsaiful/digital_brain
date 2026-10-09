/// The spoken answers to questions, shared by the chat and the answer
/// screen. Passwords are never part of an answer.
library;

import '../models/models.dart';
import 'bn.dart';
import 'ledger.dart';
import 'parser.dart';
import 'phrases.dart';
import 'search.dart';
import 'talk.dart';

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

String reminderAnswer(AppData d, ReminderQuery q, DateTime now) {
  final found = searchReminders(d, q.terms);
  if (found.isEmpty) return 'এমন কোনো তারিখ তো লেখা নেই। নতুন করে মনে করিয়ে দেওয়ার ব্যবস্থা করব?';
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
String nameList(List<String> parts) {
  final shown = parts.take(4).toList();
  final more = parts.length - shown.length;
  final head = shown.length > 1 ? '${shown.sublist(0, shown.length - 1).join(', ')}, আর ${shown.last}' : shown.join();
  return more > 0 ? '$head, এবং আরও ${bnDigits(more)} জন' : head;
}

/// The answer to a question or a bit of conversation. Null for commands
/// that save something (those are confirmed instead).
String? answerText(AppData d, Command cmd, DateTime now) => switch (cmd) {
      LedgerQuery() => ledgerAnswer(d, cmd),
      VaultQuery() => vaultAnswer(d, cmd),
      ReminderQuery() => reminderAnswer(d, cmd, now),
      SearchQuery() => searchAnswer(d, cmd, now),
      SmallTalk() => talkReply(cmd.kind, now),
      AiReply() => cmd.text,
      NotUnderstood() => 'দুঃখিত, ঠিক বুঝতে পারিনি। একটু অন্যভাবে আরেকবার বলবেন?',
      LedgerAdd() || LedgerSet() || NoteAdd() => null,
    };
