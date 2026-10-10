/// Long messages with several things in them, without the AI: split into
/// sentences and read each one; short summaries of what will be saved.
library;

import '../models/models.dart';
import 'bn.dart';
import 'parser.dart';
import 'phrases.dart';

/// Saves something (needs a yes first)?
bool isSave(Command c) => c is LedgerAdd || c is LedgerSet || c is NoteAdd || c is TaskAdd || c is ReminderAdd || c is ContactAdd || c is CashAdd || c is VaultAdd;

bool _complete(Command c) => switch (c) {
      LedgerAdd() => c.person.trim().isNotEmpty && c.amount > 0,
      ReminderAdd() => !c.needsTime,
      LedgerSet() || TaskAdd() || ContactAdd() || NoteAdd() || VaultAdd() => true,
      CashAdd() => c.amount > 0,
      _ => false,
    };

final _sentenceEnd = RegExp(r'[।!?\n|]+|\.\s+');
final _joiners = RegExp(r'\s+(?:আর|এবং|তারপর|তার পর|তাছাড়া|আবার|and|then)\s+', caseSensitive: false);

/// Every request in [said]. One sentence gives one command (as before);
/// a message with several sentences gives one per sentence. Inside a
/// sentence, "… দিলাম আর … নিলাম" is split only when every part is a full
/// money event, so "রহিম আর করিমকে ৫০০ টাকা দিলাম" stays one.
List<Command> parseAll(String said, List<LedgerEntry> ledger,
    {List<Task> tasks = const [], List<Contact> contacts = const [], DateTime? now}) {
  final p = Parser(ledger: ledger, tasks: tasks, contacts: contacts, now: now);
  // "তুমি এটা লেখ, …": the instruction is not part of what to save.
  final (rest, write) = stripAddress(said);
  if (rest.isNotEmpty && rest != said.trim()) {
    final cmds = parseAll(rest, ledger, tasks: tasks, contacts: contacts, now: now);
    final plain = cmds.length == 1 && (cmds.first is NotUnderstood || cmds.first is SmallTalk || (cmds.first is NoteAdd && (cmds.first as NoteAdd).fromStatement));
    // "লিখে রাখো যে করিমের দোকান বন্ধ" is still a note.
    if (write && plain) return [p.parse('মনে রাখো: $rest')];
    return cmds;
  }
  final whole = p.parse(said);
  final sentences = said
      .split(_sentenceEnd)
      .map((x) => stripAddress(x).$1)
      .where((x) => x.isNotEmpty)
      .toList();
  final out = <Command>[];
  for (final s in sentences) {
    final parts = s.split(_joiners).map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
    if (parts.length > 1) {
      final cmds = [for (final x in parts) p.parse(x)];
      if (cmds.every(_complete)) {
        out.addAll(cmds);
        continue;
      }
    }
    final c = p.parse(s);
    if (c is! NotUnderstood) out.add(c);
  }
  if (out.length <= 1) return [whole];
  return out;
}

/// One line for the "these are the things I found" list.
String summaryLine(Command c) => switch (c) {
      LedgerAdd(:final kind?) when c.person.trim().isNotEmpty && c.amount > 0 => describe(kind, c.person, c.amount),
      LedgerAdd() => [
          if (c.person.trim().isNotEmpty) c.person.trim(),
          if (c.amount > 0) '${bnNumber(c.amount)} টাকা',
          'লেনদেন',
        ].join(' — '),
      LedgerSet() => c.balance >= 0
          ? '${possessive(c.person)} কাছে পাবেন ${bnNumber(c.balance)} টাকা'
          : '${toPerson(c.person)} দেবেন ${bnNumber(-c.balance)} টাকা',
      NoteAdd() => c.text,
      TaskAdd() => 'কাজ: ${c.title}${c.due == null ? '' : ' (${bnDigits(c.due!.day)} ${bnMonths[c.due!.month - 1]})'}',
      ReminderAdd() => c.needsTime
          ? 'মনে করানো: ${c.title} — সময় বলা বাকি'
          : 'মনে করানো: ${c.title} — ${bnDigits(c.at.day)} ${bnMonths[c.at.month - 1]}, ${bnTime(c.at.hour, c.at.minute)}',
      VaultAdd() => 'ভল্টে: ${c.name}-এর পাসওয়ার্ড (••••)',
      ContactAdd() => 'নম্বর: ${c.name.isEmpty ? '' : '${c.name} — '}${bnDigits(c.phone)}',
      CashAdd() => c.project != null
          ? '${c.project!.isEmpty ? 'প্রজেক্ট' : '‘${c.project}’ প্রজেক্ট'} — ${c.kind == CashKind.income ? 'এসেছে' : 'খরচ'} ${bnNumber(c.amount)} টাকা'
          : '${c.kind.label}: ${c.category} — ${bnNumber(c.amount)} টাকা',
      _ => c.transcript,
    };
