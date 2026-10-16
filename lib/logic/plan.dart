/// Long messages with several things in them, without the AI: split into
/// sentences and read each one; short summaries of what will be saved.
library;

import '../models/models.dart';
import 'app_map.dart';
import 'bn.dart';
import 'health.dart';
import 'meaning.dart';
import 'parser.dart';
import 'phrases.dart';
import 'when.dart';
import 'lang.dart';

/// Saves something (needs a yes first)?
bool isSave(Command c) =>
    c is LedgerAdd || c is LedgerSet || c is NoteAdd || c is TaskAdd || c is ReminderAdd || c is ContactAdd || c is CashAdd || c is VaultAdd || c is MemoryAdd || c is SpecialAdd || c is HealthAdd || c is ProfileSet;

bool _complete(Command c) => switch (c) {
      LedgerAdd() => c.person.trim().isNotEmpty && c.amount > 0,
      ReminderAdd() => !c.needsTime,
      LedgerSet() || TaskAdd() || ContactAdd() || NoteAdd() || VaultAdd() || MemoryAdd() || SpecialAdd() || HealthAdd() || ProfileSet() => true,
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
    {List<Task> tasks = const [], List<Contact> contacts = const [], List<FolderHint> folders = const [], DateTime? now}) {
  final p = Parser(ledger: ledger, tasks: tasks, contacts: contacts, folders: folders, now: now);
  // "তুমি এটা লেখ, …": the instruction is not part of what to save.
  final (rest, write) = stripAddress(said);
  if (rest.isNotEmpty && rest != said.trim()) {
    final cmds = parseAll(rest, ledger, tasks: tasks, contacts: contacts, folders: folders, now: now);
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
/// "রিমাইন্ডার লিখে রাখো", "এটা কাজের তালিকায় রাখো", "নোট করে রাখো",
/// "অ্যালার্ম দাও": an instruction about the previous message, with nothing
/// of its own. 'reminder', 'alarm', 'task' or 'note' — null otherwise.
String? redirectOf(String said) {
  // "রিমাইন্ডার বন্ধ কোরো না": a request in the negative moves nothing.
  if (negatedRequest(normalize(said))) return null;
  var t = ' ${normalize(said)} ';
  String? kind;
  const kinds = [
    ('alarm', ['অ্যালার্ম', 'এলার্ম', 'alarm']),
    ('reminder', ['রিমাইন্ডার', 'রিমাইন্ড', 'reminder', 'মনে করিয়ে', 'মনে করাবে', 'মনে করাবা', 'মনে করাও', 'জানিয়ে দিও', 'জানিয়ে দিবে', 'জানাবে']),
    ('task', ['কাজের তালিকায়', 'কাজের তালিকা', 'কাজের লিস্টে', 'কাজে', 'কাজ হিসেবে', 'কাজ হিসাবে', 'টুডু', 'todo', 'to do']),
    ('note', ['নোটে', 'নোট']),
  ];
  for (final (k, ws) in kinds) {
    for (final w in [...ws]..sort((a, b) => b.length.compareTo(a.length))) {
      final n = ' ${normalize(w)}';
      if (t.contains(n)) {
        kind ??= k;
        t = t.replaceAll(n, ' ');
      }
    }
  }
  if (kind == null) return null;
  const fillers = [
    'এটা', 'এটাকে', 'এইটা', 'ওটা', 'ওটাকে', 'এটার', 'সেটা', 'এটাও', 'এই', 'ওই', 'হিসেবে', 'হিসাবে', 'হিসেবেই', 'লিখে', 'লেখো', 'লিখো', 'রাখো', 'রাখ', 'রাখুন', 'রাখেন', 'রেখো', 'রেখে', 'দাও', 'দিন', 'দিও', 'দেন', 'দাও না',
    'করো', 'কর', 'করে', 'করুন', 'করেন', 'সেট', 'set', 'না', 'বরং', 'একটা', 'একটি', 'ভাই', 'প্লিজ', 'please', 'আর', 'তাহলে', 'তো', 'জি', 'হ্যাঁ', 'হ্যা', 'ঠিক', 'আছে', 'আমাকে', 'আমায়', 'যেন', 'দিয়ো',
    'ওটার', 'সময়মতো', 'সময়মত', 'সময়', 'মতো', 'মত', 'দিবে', 'দেবে', 'দিবা', 'দিও', 'দেবো', 'রাখবে', 'রাখবা', 'চাই',
  ];
  final left = [for (final w in words(normalize(t))) if (!fillers.map(normalize).contains(w)) w];
  return left.isEmpty ? kind : null;
}

/// The previous message ([said]) kept the way asked: a reminder (the chat
/// asks the time if none was said), an alarm, a to-do or a note.
Command convertTo(String kind, String said, List<LedgerEntry> ledger, DateTime now) {
  final p = Parser(ledger: ledger, now: now);
  final when = parseWhen(said, now);
  final title = tidy(withoutWhen(said)).replaceAll(RegExp(r'[।.!?]+$'), '').trim();
  switch (kind) {
    case 'reminder' || 'alarm':
      final r = p.parse('$said মনে করিয়ে দিও');
      if (r is ReminderAdd) {
        return ReminderAdd(said, title: r.title, at: r.at, repeat: r.repeat, weekdays: r.weekdays, minutesBefore: r.minutesBefore, alarm: kind == 'alarm' || r.alarm);
      }
      final at = when != null && when.hasTime ? when.at : noTimeYet;
      return ReminderAdd(said, title: title.isEmpty ? said.trim() : title, at: at, alarm: kind == 'alarm');
    case 'task':
      return TaskAdd(said, title: title.isEmpty ? said.trim() : title, due: when != null && when.hasDay ? when.day : null);
    default:
      return NoteAdd(said, text: said.trim());
  }
}

String summaryLine(Command c) => switch (c) {
      LedgerAdd(:final kind?) when c.person.trim().isNotEmpty && c.amount > 0 => describe(kind, c.person, c.amount),
      LedgerAdd() => [
          if (c.person.trim().isNotEmpty) c.person.trim(),
          if (c.amount > 0) '${bnNumber(c.amount)} টাকা',
          'লেনদেন',
        ].join(' — '),
      LedgerSet() => c.balance >= 0
          ? trf('{0} কাছে পাবেন {1} টাকা', [possessive(c.person), bnNumber(c.balance)])
          : trf('{0} দেবেন {1} টাকা', [toPerson(c.person), bnNumber(-c.balance)]),
      NoteAdd() => c.text,
      MemoryAdd() => 'মনে রাখব: ${c.text}',
      SpecialAdd() => '${c.kind.mark} ${c.person} — ${c.kind.bn}: ${bnDigits(c.day)} ${monthName(c.month)}',
      TaskAdd() => 'কাজ: ${c.title}${c.due == null ? '' : ' (${bnDigits(c.due!.day)} ${monthName(c.due!.month)})'}',
      ReminderAdd() => c.needsTime
          ? trf('মনে করানো: {0} — সময় বলা বাকি', [c.title])
          : trf('মনে করানো: {0} — {1} {2}, {3}', [c.title, bnDigits(c.at.day), monthName(c.at.month), bnTime(c.at.hour, c.at.minute)]),
      VaultAdd() => 'ভল্টে: ${c.name}-এর পাসওয়ার্ড (••••)',
      ContactAdd() => 'নম্বর: ${c.name.isEmpty ? '' : '${c.name} — '}${bnDigits(c.phone)}',
      CashAdd() => c.project != null
          ? trf('{0} — {1} {2} টাকা', [c.project!.isEmpty ? 'অন্যান্য হিসাব' : '‘${c.project}’ হিসাব', c.kind == CashKind.income ? 'এসেছে' : 'খরচ', bnNumber(c.amount)])
          : trf('{0}: {1} — {2} টাকা', [c.kind.label, c.category, bnNumber(c.amount)]),
      HealthAdd() => '${isEn ? c.kind.en : c.kind.bn}: ${readingText(HealthLog(kind: c.kind, at: DateTime(2000), a: c.a, b: c.b, c: c.c, tag: c.tag))}',
      ProfileSet() => c.field == 'height'
          ? trf('উচ্চতা{0}: {1}', [c.who.isEmpty ? '' : ' (${c.who})', heightText(double.parse(c.value))])
          : trf('রক্তের গ্রুপ{0}: {1}', [c.who.isEmpty ? '' : ' (${c.who})', c.value]),
      _ => c.transcript,
    };
