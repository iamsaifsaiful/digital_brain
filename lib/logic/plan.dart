/// Long messages with several things in them, without the AI: split into
/// sentences and read each one; short summaries of what will be saved.
library;

import 'calendar_ask.dart';
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
    c is LedgerAdd || c is LedgerSet || c is NoteAdd || c is TaskAdd || c is ReminderAdd || c is ContactAdd || c is CashAdd || c is VaultAdd || c is MemoryAdd || c is SpecialAdd || c is HealthAdd || c is ProfileSet || c is TasksClear;

bool _complete(Command c) => switch (c) {
      LedgerAdd() => c.person.trim().isNotEmpty && c.amount > 0,
      ReminderAdd() => !c.needsTime,
      LedgerSet() || TaskAdd() || TasksClear() || ContactAdd() || NoteAdd() || VaultAdd() || MemoryAdd() || SpecialAdd() || HealthAdd() || ProfileSet() => true,
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
    {List<Task> tasks = const [], List<Contact> contacts = const [], List<FolderHint> folders = const [], DateTime? now, AppData? data}) {
  final out = _parseAll(said, ledger, tasks: tasks, contacts: contacts, folders: folders, now: now, data: data);
  // A menu clearly named in a request nothing understood (or only a loose
  // note would keep): said plainly what voice cannot do there, nothing saved.
  if (out.length == 1 && (out.first is NotUnderstood || out.first is SearchQuery || (out.first is NoteAdd && (out.first as NoteAdd).fromStatement))) {
    final u = menuUnsupported(said);
    if (u != null) return [u];
  }
  return out;
}

List<Command> _parseAll(String said, List<LedgerEntry> ledger,
    {List<Task> tasks = const [], List<Contact> contacts = const [], List<FolderHint> folders = const [], DateTime? now, AppData? data}) {
  final p = Parser(ledger: ledger, tasks: tasks, contacts: contacts, folders: folders, now: now, data: data);
  // Typed on several lines: a to-do list under a heading ("কালকের কাজ:")
  // is one to-do per line; other lines are separate sentences.
  final perLine = lineTodos(said, p);
  if (perLine != null) return perLine;
  if (said.contains('\n')) said = said.split(RegExp(r'\s*\n+\s*')).where((x) => x.trim().isNotEmpty).map((x) => x.trim().replaceAll(RegExp(r'[।.!?]+$'), '')).join('। ');
  // "ইয়ার তুমি একটা কাজ করো তো …": the opening words are not part of it.
  final tidied = tidySpeech(said);
  if (tidied.isNotEmpty) said = tidied;
  // "এ মাসে কী কী ছুটি আছে?", "কাল কত তারিখ?": the calendar on the phone.
  if (calendarAsked(said)) return [SmallTalk(said, kind: calendarTodayOnly(said, p.now) ? Talk.date : Talk.calendar)];
  // The other menus first (menus.dart): "এই মাসের DPS দিয়েছি" is an
  // instalment, never a to-do ticked by a shared word.
  final menu = menuCommand(said, data, p.now);
  if (menu != null) return [menu];
  // "বাজারে ৫০০, রিকশায় ৫০ আর ওষুধে ৩০০, মোট ৮৫০": the parts, and the
  // total only as a check — never a fourth expense.
  final parts = spentInParts(said, p);
  if (parts != null) return parts;
  // "রিপোর্টটা নোটে রাখো, পাঠানোর কাজ কাল দাও": a note, and a to-do about
  // the same thing — two items; nothing is sent.
  final nt = RegExp(fold(r'^(.+?)\s+নোটে\s+(?:রাখো|রাখ|লিখে\s+রাখো|তুলে\s+রাখো)[,\s]+(\S+?)(?:র|ের|এর)\s+কাজ(?:টা|টি)?\s+(.+)$')).firstMatch(fold(said));
  if (nt != null) {
    final obj = nt[1]!.replaceAll(RegExp(fold(r'(?:টা|টি|গুলো)$')), '').trim();
    final w = parseWhen(nt[3]!, p.now);
    return [NoteAdd(said, text: obj), TaskAdd(said, title: '$obj ${nt[2]}', due: w != null && w.hasDay ? dayOnly(w.day) : null)];
  }
  // "৮ নভেম্বর ঢাকায় যাব, ২২ নভেম্বর সিঙ্গাপুর যাব আর ২৯ তারিখে ফিরব —
  // এগুলো কাজের তালিকায় যুক্ত করো": several dated to-dos in one breath.
  final dated = datedTodos(said, p);
  if (dated != null) return dated;
  // Money said in parts of different times: one command each.
  final money = moneyClauses(said, p);
  if (money != null) return money;
  // To-do requests, one per clause ("বাজার করেছি, ওষুধ আনিনি").
  final todo = todoCommands(englishTimes(said), tasks, p.now);
  if (todo != null && todo.isNotEmpty) return todo;
  // "… এটা আমাকে কাজের তালিকায় লিখে রাখো": one to-do, said whole.
  final first = p.parse(said);
  if (first is TaskAdd && RegExp(fold(r'(?:কাজের\s+(?:লিস্ট|তালিকা)|টু\s*ডু)')).hasMatch(fold(said))) return [first];
  // "তুমি এটা লেখ, …": the instruction is not part of what to save.
  final (rest, write) = stripAddress(said);
  if (rest.isNotEmpty && rest != said.trim()) {
    final cmds = _parseAll(rest, ledger, tasks: tasks, contacts: contacts, folders: folders, now: now, data: data);
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


/// A list typed on several lines under a to-do heading — "কাজের তালিকা:",
/// "কালকের কাজ", "টুডু" — one to-do per line ("-", "•", "১." in front
/// dropped). A date written on a line is that to-do's; otherwise the
/// heading's day, if it named one. Null when it is not such a list.
List<Command>? lineTodos(String said, Parser p) {
  final lines = [
    for (final x in said.split(RegExp(r'\r?\n')))
      if (x.trim().isNotEmpty) x.trim().replaceAll(RegExp(r'^(?:[-–—•*·▪]|[0-9০-৯]{1,2}\s*[.)।])\s*'), '').replaceAll(RegExp(r'[।.,;]+$'), '').trim()
  ].where((x) => x.isNotEmpty).toList();
  if (lines.length < 2) return null;
  final head = RegExp(fold(r'^(?:আমার\s+)?(.*?)\s*(?:কাজের\s+(?:তালিকা|লিস্ট)\S*|কাজগুলো|কাজ|টু\s*ডু\S*|to-?do\S*)(?:\s+(?:রাখো|লিখে\s+রাখো|যোগ\s+করো|যুক্ত\s+করো|লেখো|লিখো))?\s*[:：\-—–]?\s*$'), caseSensitive: false).firstMatch(fold(lines.first));
  if (head == null) return null;
  final pre = tidySpeech(head[1]!);
  final hw = pre.trim().isEmpty ? null : parseWhen(pre, p.now);
  if (pre.trim().isNotEmpty && (hw == null || !hw.hasDay)) return null;
  final out = <Command>[];
  for (final line in lines.skip(1)) {
    final c = p.parse('${tidySpeech(line)} — কাজের তালিকায় লিখে রাখো');
    final title = c is TaskAdd && c.title.trim().isNotEmpty ? c.title : tidy(line);
    if (title.trim().isEmpty) continue;
    out.add(TaskAdd(said, title: title, due: (c is TaskAdd ? c.due : null) ?? hw?.day));
  }
  return out.isEmpty ? null : out;
}

/// Several to-dos, each with its own date, said together with an order to
/// put them on the list. Split at every date ("৮ নভেম্বর", "২৯ তারিখে");
/// a date without a month takes the month said before it. Null when the
/// sentence is not such a list (one date or none, or no list order).
List<Command>? datedTodos(String said, Parser p) {
  final f = fold(said);
  final order = RegExp(fold(r'[\s,।]*(?:(?:এগুলো|এগুলা|এগুলি|এসব|এই\s+সব|এই\s+কাজগুলো|সবগুলো|সব)\s+)?(?:আমার\s+)?(?:কাজের\s+(?:তালিকা|লিস্ট)\S*|টু\s*ডু\S*)(?:\s+\S+){0,4}[\s,।!]*$')).firstMatch(f);
  // "কাজের তালিকায় (লেখো:) X, ৩১ অক্টোবর Y, ৪ নভেম্বর Z": the order first.
  final lead = RegExp(fold(r'^\s*(?:আমার\s+)?(?:কাজের\s+(?:তালিকা|লিস্ট)(?:য়|য়|তে|ে)|টু\s*ডু\s*(?:লিস্টে|তে))\s*(?:(?:লিখে\s+রাখো|লিখে\s+রাখ|লেখো|লিখো|রাখো|যোগ\s+করো|যুক্ত\s+করো|তুলে\s+রাখো)\s*)?[,:—–-]?\s*')).firstMatch(f);
  String body;
  if (order != null && RegExp(fold(r'(?:যুক্ত|যোগ|রাখ|রেখ|লিখ|লেখ|তুলে|অ্যাড|এড|add)')).hasMatch(order[0]!)) {
    body = f.substring(0, order.start);
  } else if (lead != null) {
    body = f.substring(lead.end);
  } else {
    return null;
  }
  final months = bnMonths.map(fold).join('|');
  final date = RegExp('(?:^|(?<=[\\s,।]))[০-৯0-9]{1,2}\\s+(?:(?:$months)|${fold('তারিখ')}\\S*)');
  final at = date.allMatches(body).toList();
  if (at.length < 2) return null;
  final out = <Command>[];
  // "লেখা, ৩১ অক্টোবর …": a to-do of its own before the first date, set
  // off by a comma — kept without a date.
  final before = body.substring(0, at.first.start);
  var first = 0;
  if (RegExp(r'[,،]\s*$').hasMatch(before)) {
    for (final x in before.split(RegExp(r'\s*[,،]\s*')).map((x) => x.trim()).where((x) => x.isNotEmpty)) {
      final c = p.parse('$x — কাজের তালিকায় লিখে রাখো');
      if (c is! TaskAdd || c.title.trim().isEmpty) return null;
      out.add(TaskAdd(said, title: c.title));
    }
    first = at.first.start;
  }
  String? month;
  for (var i = 0; i < at.length; i++) {
    final end = i + 1 < at.length ? at[i + 1].start : body.length;
    // Words said before the first date belong to the first to-do.
    var piece = body.substring(i == 0 ? first : at[i].start, end).trim();
    piece = piece.replaceAll(RegExp(r'^[,،\s]+|[,،\s]+$'), '');
    piece = piece.replaceAll(RegExp(fold(r'[\s,।]*(?:এবং|আর|তারপর|তারপরে|এরপর|এরপরে|ও)[\s,।]*$')), '').trim();
    final m = RegExp('($months)').firstMatch(at[i][0]!);
    if (m != null) {
      month = m[1];
    } else if (month != null) {
      piece = piece.replaceFirstMapped(RegExp('([০-৯0-9]{1,2})\\s+${fold('তারিখ')}\\S*'), (x) => '${x[1]} $month');
    }
    final c = p.parse('$piece — কাজের তালিকায় লিখে রাখো');
    if (c is! TaskAdd || c.title.trim().isEmpty || c.due == null) return null;
    out.add(c);
  }
  return out;
}

/// "বাজারে ৫০০, রিকশায় ৫০ আর ওষুধে ৩০০, মোট ৮৫০": one own expense per
/// part (each with its own amount and খাত); a spoken "মোট" is only a check
/// against their sum — if it does not match, the parts are still kept and
/// the chat shows them all before saving. Null when [said] is not a list
/// of own spending.
List<Command>? spentInParts(String said, Parser p) {
  final f = fold(said);
  final total = RegExp(fold(r'[,،]?\s*(?:মোট|সব\s+মিলিয়ে|টোটাল)\s+(.+?)\s*(?:টাকা)?\s*[।.]?\s*$')).firstMatch(f);
  final body = total == null ? f : f.substring(0, total.start);
  final pieces = body.split(RegExp(fold(r'\s*[,،;]\s*|\s+(?:আর|এবং|ও)\s+'))).map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
  if (pieces.length < 2) return null;
  // "আগের পাঁচশ নয়, সাতশ হবে": a correction, not a list.
  if (RegExp(fold(r'(?:^|\s)(?:না|নয়|নাহ|নয়)(?=\s|,|$)')).hasMatch(f) || RegExp(fold(r'(?:হবে|দেব|দেবো|করব|লাগবে)')).hasMatch(f)) return null;
  // Only a list of spending: said as spending ("খরচ", "মোট"), or short
  // "<where> <amount>" parts — never dated plans or people's names.
  final spendSaid = RegExp(fold(r'(?:খরচ|ব্যয়|মোট|টোটাল|গেল|গেছে)')).hasMatch(f);
  if (!spendSaid && pieces.any((x) => words(normalize(x)).length > 3)) return null;
  final w = parseWhen(said, p.now);
  if (w != null && w.hasDay && !RegExp(fold(r'(?:আজ|আজকে)')).hasMatch(f)) return null;
  final out = <CashAdd>[];
  for (final x in pieces) {
    final amount = findAmount(normalize(x));
    if (amount == null || amount <= 0) return null;
    // Each part names where it went ("বাজারে", "রিকশায়") — no person, no verb of owing.
    final c = p.parse('$x টাকা খরচ হয়েছে');
    if (c is! CashAdd || c.kind != CashKind.expense) return null;
    out.add(CashAdd(said, kind: CashKind.expense, amount: amount, category: c.category));
  }
  if (total != null) {
    final t = findAmount(normalize(total[1]!));
    if (t == null) return null;
  }
  return out;
}
