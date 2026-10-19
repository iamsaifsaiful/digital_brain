/// Long messages with several things in them, without the AI: split into
/// sentences and read each one; short summaries of what will be saved.
library;

import 'calendar_ask.dart';
import 'cash.dart' show cashItem, projectMeant;
import 'answers.dart' show categoryAsked;
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
  // "আজ কয়েকটি কাজ আছে": a heading before the list — no to-do is called
  // "কয়েকটি"; the list itself is asked for.
  if (out.isNotEmpty && out.every((c) => (c is TaskAdd && onlyCount(c.title)) || (c is NoteAdd && onlyCount(c.text)))) {
    return [AiReply(said, text: tr('কোন কোন কাজ? একটা একটা করে বলুন, বা এক লাইনে একটা করে লিখুন — সব কাজের তালিকায় রেখে দেব।'))];
  }
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
  // "৩১ নভেম্বর ঢাকায় যাব": no such day — asked first, nothing kept.
  final bad = invalidDayOfMonth(said, p.now);
  if (bad != null) return [AiReply(said, text: bad)];
  // "ইমরান ৫০০০ টাকা দিয়েছে, শুধু নোটে রাখো", "… এটা নোট করে রাখো": the
  // place said wins — a note, even with money or a day in it.
  final note = RegExp(fold(r'^(.+?)[\s,।]+(?:(?:এটা|এটি|এগুলো|এইটা|ওটা)\s+)?(?:শুধু\s+|শুধুই\s+|কেবল\s+)?(?:নোটে|নোট\s+হিসেবে|নোট\s+আকারে|নোটস-?এ)\s+(?:রাখো|রাখ|রেখো|লিখে\s+রাখো|লিখো|লেখো|তুলে\s+রাখো|সেভ\s+করো)\s*[।.!]?$|^(.+?)[\s,।]+(?:(?:এটা|এটি|এগুলো|এইটা|ওটা)\s+)?(?:শুধু\s+)?নোট\s+(?:করে\s+রাখো|করে\s+রাখ|করো|কর|করে\s+নাও)\s*[।.!]?$')).firstMatch(fold(said.trim()));
  if (note != null) {
    final body = (note[1] ?? note[2] ?? '').trim();
    if (body.isNotEmpty) return [NoteAdd(said, text: said.trim().substring(0, body.length).replaceAll(RegExp(r'[\s,।]+$'), ''))];
  }
  // Typed on several lines: a to-do list under a heading ("কালকের কাজ:")
  // is one to-do per line; other lines are separate sentences.
  final perLine = lineTodos(said, p) ?? lineMoney(said, p) ?? breathTodos(said, p);
  if (perLine != null) return perLine;
  if (said.contains('\n')) said = said.split(RegExp(r'\s*\n+\s*')).where((x) => x.trim().isNotEmpty).map((x) => x.trim().replaceAll(RegExp(r'[।.!?]+$'), '')).join('। ');
  // "ইয়ার তুমি একটা কাজ করো তো …": the opening words are not part of it.
  final tidied = tidySpeech(said);
  if (tidied.isNotEmpty) said = tidied;
  // "এ মাসে কী কী ছুটি আছে?", "কাল কত তারিখ?": the calendar on the phone.
  if (calendarAsked(said)) return [SmallTalk(said, kind: calendarTodayOnly(said, p.now) ? Talk.date : Talk.calendar)];
  // "কিভাবে ডকুমেন্টস যুক্ত করব": how to — answered, never kept as a to-do.
  if (howToAsked(said) != null || abilityAsked(said) != null) return [ProfileQuery(said)];
  // "আরও ১ জনের কাছে কত?" after a list of who owes: the whole list again.
  if (RegExp(fold(r'আরও\s+\S+\s+জন')).hasMatch(fold(said)) && RegExp(fold(r'(?:কত|কে|কারা|কার|কাকে)')).hasMatch(fold(said))) {
    return [LedgerQuery(said, ask: RegExp(fold(r'(?:কাছে|পাবো|পাব|পাওনা)')).hasMatch(fold(said)) ? LedgerAsk.receivable : LedgerAsk.payable)];
  }
  // "আয়ের খাত গুলো কি কি", "কিভাবে ব্যয় হয়েছে?": this month by খাত.
  if (categoryAsked(said) != null) return [CashQuery(said)];
  // "আমার পাসপোর্ট দাও", "জাতীয় পরিচয় পত্র কোথায়": a paper kept in
  // ডকুমেন্টস, by its name (spaces in it or not) — shown, never a new note.
  final doc = data == null ? null : docAsked(said, data);
  if (doc != null) return [SearchQuery(said, terms: doc)];
  // "শিক্ষার্থীদের মাঝে, মাহি ২০০০ টাকা দিছে, আখি ৫০০ টাকা, …": several
  // people each gave; the other sentences read on their own.
  final gave = peopleGave(said, p);
  if (gave != null) return gave;
  // The other menus first (menus.dart): "এই মাসের DPS দিয়েছি" is an
  // instalment, never a to-do ticked by a shared word.
  final menu = menuCommand(said, data, p.now);
  if (menu != null) return [menu];
  // "বাজারে ৫০০, রিকশায় ৫০ আর ওষুধে ৩০০, মোট ৮৫০": the parts, and the
  // total only as a check — never a fourth expense.
  final parts = spentInParts(said, p);
  if (parts != null) return parts;
  // "রাজু ৫০০০ টাকা পাঠাইছে, ২০০০ টাকার বাজার করলাম, ১০০০ টাকা মসজিদে দান
  // করলাম": money in and out in one breath — one entry per part.
  final mixed = mixedCash(said, p);
  if (mixed != null) return mixed;
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
  // "রবিনের বোনের বিয়েতে ২৩ এবং ২৪ তারিখে দাওয়াত", "২৪ তারিখেও দাওয়াত
  // আছে": something on those days, told — one to-do for each day.
  final onDays = eventOnDays(said, p);
  if (onDays != null) return onDays;
  final dated = datedTodos(said, p) ?? datedClauses(said, p);
  if (dated != null) return dated;
  // Money said in parts of different times: one command each.
  final shared = sharedVerbMoney(said, p);
  if (shared != null) return shared;
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
  // "মনে করানোর প্রয়োজন নেই, কাজের তালিকায় রাখো শুধু": the "no ring"
  // part only says what it should not be.
  for (final no in const ['মনে করানোর', 'মনে করানো', 'মনে করাতে', 'রিমাইন্ডারের', 'রিমাইন্ডার', 'অ্যালার্মের', 'এলার্মের']) {
    for (final need in const ['প্রয়োজন নেই', 'প্রয়োজন নাই', 'দরকার নেই', 'দরকার নাই', 'লাগবে না', 'দিতে হবে না', 'দিও না', 'দিবা না']) {
      t = t.replaceAll(' ${normalize('$no $need')}', ' ');
    }
  }
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
    'ওটার', 'সময়মতো', 'সময়মত', 'সময়', 'মতো', 'মত', 'দিবে', 'দেবে', 'দিবা', 'দিও', 'দেবো', 'রাখবে', 'রাখবা', 'চাই', 'শুধু', 'শুধুই', 'কেবল', 'শুধুমাত্র',
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
          ? trf('{0} — {1} {2} টাকা', [
              c.project!.isEmpty ? 'অন্যান্য হিসাব' : '‘${c.project}’ হিসাব',
              c.kind == CashKind.income ? 'এসেছে' : 'খরচ',
              bnNumber(c.amount),
            ]) + (cashItem(c.transcript).isEmpty ? '' : ' (${cashItem(c.transcript)})')
          : trf('{0}: {1} — {2} টাকা', [c.kind.label, _withItem(c.category, cashItem(c.transcript)), bnNumber(c.amount)]),
      HealthAdd() => '${isEn ? c.kind.en : c.kind.bn}: ${readingText(HealthLog(kind: c.kind, at: DateTime(2000), a: c.a, b: c.b, c: c.c, tag: c.tag))}',
      ProfileSet() => c.field == 'height'
          ? trf('উচ্চতা{0}: {1}', [c.who.isEmpty ? '' : ' (${c.who})', heightText(double.parse(c.value))])
          : trf('রক্তের গ্রুপ{0}: {1}', [c.who.isEmpty ? '' : ' (${c.who})', c.value]),
      _ => c.transcript,
    };


/// Something happening on one or more days of the month, told as a fact
/// ("২৩ এবং ২৪ তারিখে দাওয়াত", "২৪ তারিখেও দাওয়াত আছে"): a to-do for
/// each day. Null for questions, money, orders and reminders (their own rules).
List<Command>? eventOnDays(String said, Parser p) {
  if (isQuestionText(said)) return null;
  final f = ' ${fold(normalize(said))} ';
  if (RegExp(fold(r'(?:টাকা|রিমাইন্ডার|মনে\s+করি|মনে\s+করা|এলার্ম|অ্যালার্ম|মুছ|বাদ\s+দাও|সরাও|রাখো|দেখাও|জন্মদিন|বার্ষিকী)')).hasMatch(f)) return null;
  final months = bnMonths.map(fold).join('|');
  final num = '[০-৯0-9]{1,2}';
  final tarikh = fold('তারিখ');
  final join = '(?:\\s*,\\s*|\\s+(?:${fold('এবং')}|${fold('আর')}|${fold('ও')})\\s+)';
  // "২৩ এবং ২৪ তারিখে", "২৩ তারিখ এবং ২৪ তারিখ", "২৩ ও ২৪ অক্টোবর".
  final m = RegExp('(?<=\\s)($num)(?:\\s+$tarikh\\S*)?((?:$join$num(?:\\s+$tarikh\\S*)?)*)\\s*(?:$tarikh\\S*|($months))?(?=\\s|,)').allMatches(f).where((x) => x[0]!.contains(tarikh) || x[3] != null).firstOrNull;
  if (m == null) return null;
  final nums = [for (final x in RegExp(num).allMatches(m[0]!)) int.parse(asciiDigits(x[0]!))];
  if (nums.isEmpty || nums.any((n) => n < 1 || n > 31)) return null;
  final today = DateTime(p.now.year, p.now.month, p.now.day);
  final month = m[3] == null ? null : bnMonths.map(fold).toList().indexOf(m[3]!) + 1;
  DateTime dayOf(int n) {
    if (month != null) {
      final d = DateTime(today.year, month, n);
      return d.isBefore(today) ? DateTime(today.year + 1, month, n) : d;
    }
    final d = DateTime(today.year, today.month, n);
    return d.isBefore(today) ? DateTime(today.year, today.month + 1, n) : d;
  }
  // What it is: the rest, without the told-words ("আছে", "দুই দিনেই", "না").
  var rest = (f.substring(0, m.start) + f.substring(m.end))
      .replaceAll(RegExp(fold(r'(?:^|\s)(?:না|আছে|আছেই|হবে|দুই\s+দিনেই|দুই\s+দিন|দুদিনই|দুদিন|দিনেই|ই|ও)(?=\s|$|[,।])')), ' ')
      .replaceAll(RegExp(r'[,।.!]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (rest.isEmpty || RegExp(r'\S+').allMatches(rest).length > 8) return null;
  // Only an event, not something to do ("২৩ তারিখে ঢাকায় যাব" is a to-do
  // rule's own).
  if (RegExp(fold(r'(?:বো|ব|মু|তে\s+হবে)(?:\s|$)')).hasMatch(' $rest ')) return null;
  if (RegExp(fold(r'(?:কাজ|তালিকা|লিস্ট|লেখ|লিখ|যোগ|যুক্ত|(?:^|\s)(?:করতে|নিতে|যেতে|দিতে|আনতে|কিনতে|দেখতে|খেতে|পড়তে)(?:\s|$))')).hasMatch(' $rest ')) return null;
  final title = rest.replaceFirst(RegExp(r'^\S'), rest[0]);
  return [for (final n in nums.toSet()) TaskAdd(said, title: title, due: dayOf(n))];
}

/// The words of a kept paper's title when [said] only asks for that paper
/// ("আমার পাসপোর্ট দাও"); null otherwise.
List<String>? docAsked(String said, AppData d) {
  if (d.docs.isEmpty) return null;
  final f = ' ${fold(normalize(said))} ';
  final ask = RegExp(fold(r'\s(?:দাও|দিন|দেন|দেখাও|দেখান|কোথায়|কই|বের\s+করো|খুঁজে\s+দাও|খোলো|খুলে\s+দাও)\s')).firstMatch(f);
  if (ask == null) return null;
  var rest = f.substring(0, ask.start).replaceAll(RegExp(fold(r'(?:^|\s)(?:আমার|আমাদের|আমাকে|একটু|টা|টি|কপি|ছবি)(?=\s|$)')), ' ').trim();
  rest = rest.replaceAll(RegExp(fold(r'(?:টা|টি|খানা)$')), '');
  if (rest.isEmpty || f.substring(ask.end).trim().isNotEmpty) return null;
  final want = rest.replaceAll(RegExp(r'\s+'), '');
  if (want.length < 3) return null;
  for (final x in d.docs) {
    final key = fold(normalize('${x.title} ${x.folder}')).replaceAll(RegExp(r'\s+'), '');
    if (key.contains(want)) return searchTerms(normalize(x.title));
  }
  return null;
}

/// "রবিনকে কল করব ফ্রেশ হয়ে নাস্তা করব গোসল করে মসজিদে যাব": the pieces,
/// each ending at a first-person future verb ("করব", "যাবো", "কিনব").
/// Joined actions ("গিয়ে", "করে", "হয়ে") stay inside their piece.
List<String> splitByWillVerbs(String text) {
  const notVerbs = {'সব', 'তবে', 'অব', 'কব', 'রব', 'শব', 'নব'};
  final out = <String>[];
  var cur = <String>[];
  for (final w in text.trim().split(RegExp(r'\s+'))) {
    cur.add(w);
    final bare = w.replaceAll(RegExp(r'[,।.!?]+$'), '');
    if (bare.length >= 2 && RegExp(fold(r'(?:ব|বো|বো)$')).hasMatch(fold(bare)) && !notVerbs.contains(bare)) {
      out.add(cur.join(' '));
      cur = [];
    }
  }
  if (cur.isNotEmpty) {
    if (out.isEmpty) return [cur.join(' ')];
    out[out.length - 1] = '${out.last} ${cur.join(' ')}';
  }
  return out;
}

/// "কাল স্কুলে যাব বাজার করব চুল কাটব": three or more plans said in one
/// breath with no commas — one to-do each, the day said once for all.
/// Null unless every piece reads as a to-do.
List<Command>? breathTodos(String said, Parser p) {
  if (said.contains('\n') || RegExp(r'[,،;।]').hasMatch(said.trim().replaceAll(RegExp(r'[।.!?]+$'), ''))) return null;
  // "… এগুলো কাজের তালিকায় যুক্ত করো": where to keep them, not one more to-do.
  final tidied = tidySpeech(said).replaceFirst(RegExp(fold(r'\s+(?:এগুলো|এগুলা|এগুলি|সব)\s+(?:কাজের\s+)?(?:তালিকায়|লিস্টে)\s+\S+(?:\s+\S+)?\s*$')), '');
  final pieces = splitByWillVerbs(tidied);
  if (pieces.length < 3) return null;
  // Each with its own day ("৮ তারিখে …, ২২ তারিখে …"): the dated rules read those.
  if (pieces.where((x) => parseWhen(x, p.now)?.hasDay ?? false).length >= 2) return null;
  final w = parseWhen(tidied, p.now);
  final out = <Command>[];
  for (final x in pieces) {
    final c = p.parse('${withoutWhen(x).trim()} — কাজের তালিকায় লিখে রাখো');
    if (c is! TaskAdd || c.title.trim().isEmpty) return null;
    out.add(TaskAdd(said, title: c.title, due: c.due ?? (w != null && w.hasDay ? dayOnly(w.day) : null), span: c.span));
  }
  return out;
}

/// A list typed on several lines under a to-do heading — "কাজের তালিকা:",
/// "কালকের কাজ", "টুডু" — one to-do per line ("-", "•", "১." in front
/// dropped). A date written on a line is that to-do's; otherwise the
/// heading's day, if it named one. Null when it is not such a list.
List<Command>? lineTodos(String said0, Parser p) {
  // "১০ই জানুয়ারি কাজ গুলো, ঘুম থেকে উঠে রবিনকে কল করব, ফ্রেশ হয়ে নাস্তা
  // করব, …": the heading, then one to-do per comma — as if on lines.
  var said = said0;
  if (!said.contains('\n')) {
    final m = RegExp(fold(r'^(.{0,40}?(?:কাজের\s+(?:তালিকা|লিস্ট)|কাজ\s*(?:গুলো|গুলা|গুলি)?))\s*(?:হলো|হল)?\s*[,:：\-–—]\s*(.+)$')).firstMatch(fold(said.trim()));
    if (m != null) {
      final parts = [for (final x in m[2]!.split(RegExp(r'\s*[,،;।]\s*'))) if (x.trim().isNotEmpty) x.trim()];
      if (parts.length >= 2) said = [m[1]!, ...parts].join('\n');
    }
  }
  // Said in one breath with no commas ("১০ জানুয়ারির কাজ ঘুম থেকে উঠে
  // রবিনকে কল করব ফ্রেশ হয়ে নাস্তা করব …"): one to-do per "I will" verb.
  if (!said.contains('\n')) {
    final m = RegExp(fold(r'^(.{0,40}?(?:কাজের\s+(?:তালিকা|লিস্ট)|কাজ\s*(?:গুলো|গুলা|গুলি)?))\s+(.+)$')).firstMatch(fold(said.trim()));
    if (m != null) {
      final parts = splitByWillVerbs(m[2]!);
      if (parts.length >= 2) said = [m[1]!, ...parts].join('\n');
    }
  }
  final lines = [
    for (final x in said.split(RegExp(r'\r?\n')))
      if (x.trim().isNotEmpty) x.trim().replaceAll(RegExp(r'^(?:[-–—•*·▪]|[0-9০-৯]{1,2}\s*[.)।])\s*'), '').replaceAll(RegExp(r'[।.,;]+$'), '').trim()
  ].where((x) => x.isNotEmpty).toList();
  if (lines.length < 2) return null;
  // The heading: "কাজের তালিকা:", "কালকের কাজ", "আমার এই বছরে কিছু কাজ
  // আছে," — to-do words, maybe a when, nothing else to do in it.
  final h = fold(tidySpeech(lines.first)).replaceAll(RegExp(r'[,:：\-—–।]+\s*$'), '').trim();
  final isHead = RegExp(fold(r'(?:কাজের\s+(?:তালিকা|লিস্ট)\S*|(?:^|\s)কাজ(?:গুলো|গুলা)?(?:\s|$)|টু\s*ডু\S*|to-?do\S*)'), caseSensitive: false).hasMatch(h) &&
      RegExp(r'\S+').allMatches(h).length <= 9 &&
      !RegExp(fold(r'(?:মুছ|ডিলিট|বাদ\s+দাও|শেষ\s+হয়েছে|করেছি|হয়ে\s+গেছে|দেখাও|দাও\s*$|(?:^|\s)(?:কী|কি|কোন|কয়টা)(?:\s|$)|\?)')).hasMatch(h);
  if (!isHead) return null;
  final hw = parseWhen(h, p.now);
  final yearPlan = RegExp(fold(r'(?:(?:এই|এ)\s+বছর|[০-৯0-9]{4}\s+সাল)')).hasMatch(h);
  final yearOf = RegExp(fold(r'([০-৯0-9]{4})\s+সাল')).firstMatch(h);
  final out = <Command>[];
  DateTime? prev;
  final monthWord = RegExp(fold('(?:${bnMonths.join('|')})'));
  // "২৯ তারিখে ঢাকায় যাবো। ৩১ তারিখে পার্টি।" on one line: two to-dos.
  final items = [
    for (final l in lines.skip(1))
      for (final x in l.split(RegExp(r'\s*।\s*|\.\s+'))) if (x.trim().isNotEmpty) x.trim(),
  ];
  for (final line in items) {
    final c = p.parse('${tidySpeech(line)} — কাজের তালিকায় লিখে রাখো');
    var title = c is TaskAdd && c.title.trim().isNotEmpty ? c.title : tidy(line);
    // "সকাল স্কুলে যাবো": the part of the day stays with it ("সকালে স্কুলে যাওয়া").
    final part = RegExp(fold(r'^(সকাল|দুপুর|বিকাল|বিকেল|সন্ধ্যা|রাত|ভোর)(?:ে|য়|ের)?(?=\s)')).firstMatch(fold(line));
    if (part != null && !fold(title).startsWith(part[1]!)) {
      const said = {'সকাল': 'সকালে', 'দুপুর': 'দুপুরে', 'বিকাল': 'বিকালে', 'বিকেল': 'বিকেলে', 'সন্ধ্যা': 'সন্ধ্যায়', 'রাত': 'রাতে', 'ভোর': 'ভোরে'};
      title = '${said[part[1]!] ?? part[1]!} $title';
    }
    if (title.trim().isEmpty) continue;
    var own = c is TaskAdd ? c.due : null;
    // "১২ তারিখে ঢাকা, ১৭ তারিখে সিংগাপুর, ২৫ তারিখে ফেরা": a list goes
    // forward — a bare day before the one above is in the next month.
    if (own != null && prev != null && own.isBefore(prev) && !monthWord.hasMatch(fold(line))) {
      final next = DateTime(own.year, own.month + 1, own.day);
      if (next.day == own.day && !next.isBefore(prev)) own = next;
    }
    if (own != null) prev = own;
    if (own == null && yearPlan) {
      // "এই বছরে কিছু কাজ আছে": each a plan for the year.
      final y = yearOf == null ? p.now.year : int.parse(asciiDigits(yearOf[1]!));
      // "২০৪১ সালের মে মাসের কাজের তালিকা": each for that month.
      final mo = RegExp('(?:^|\\s)(${bnMonths.map(fold).join('|')})(?:\\s+${fold('মাস')}\\S*|${fold('ের')}|${fold('এর')}|${fold('ে')})?(?=\\s|\$)').firstMatch(h);
      final mi = mo == null ? 0 : bnMonths.map(fold).toList().indexOf(mo[1]!) + 1;
      out.add(mi > 0
          ? TaskAdd(said, title: title, due: DateTime(y, mi, 1), span: TaskSpan.month)
          : TaskAdd(said, title: title, due: DateTime(y, 1, 1), span: TaskSpan.year));
    } else {
      out.add(TaskAdd(said, title: title, due: own ?? (hw != null && hw.hasDay ? hw.day : null)));
    }
  }
  return out.isEmpty ? null : out;
}

/// Several to-dos, each with its own date, said together with an order to
/// put them on the list. Split at every date ("৮ নভেম্বর", "২৯ তারিখে");
/// a date without a month takes the month said before it. Null when the
/// sentence is not such a list (one date or none, or no list order).
/// "আজ সারাদিনের আয় ব্যয়ের হিসাব-" and one money line under it each: the
/// heading only names the list (it is not a question); every line is read
/// on its own.
List<Command>? lineMoney(String said, Parser p) {
  final lines = [
    for (final x in said.split(RegExp(r'\r?\n')))
      if (x.trim().isNotEmpty) x.trim().replaceAll(RegExp(r'^(?:[-–—•*·▪]|[0-9০-৯]{1,2}\s*[.)।])\s*'), '').replaceAll(RegExp(r'[।.,;]+$'), '').trim()
  ].where((x) => x.isNotEmpty).toList();
  if (lines.length < 3) return null;
  final h = fold(lines.first);
  final isHead = RegExp(fold(r'(?:হিসাব|হিসেব|আয়|ব্যয়|খরচ|লেনদেন)')).hasMatch(h) && findAmount(normalize(lines.first)) == null && !h.contains('?') && RegExp(r'\S+').allMatches(h).length <= 8;
  if (!isHead) return null;
  final items = lines.skip(1).toList();
  if (items.any((x) => findAmount(normalize(x)) == null)) return null;
  final out = <Command>[];
  for (final x in items) {
    final tidied = tidySpeech(x);
    final c = spentInParts(tidied, p)?.firstOrNull ?? p.parse(tidied);
    if (c is NotUnderstood || c is SearchQuery || c is NoteAdd) return null;
    out.add(c);
  }
  return out;
}

/// "শফিক ভাইকে দিলাম ২৫০ টাকা, ইসমাঈলকে ৩৭১২ টাকা, রবিনকে ২০০ টাকা": one
/// verb said once for several people — each part read with it, one record
/// each (none lost after the first).
List<Command>? sharedVerbMoney(String said, Parser p) {
  final parts = [
    for (final x in said.split(RegExp(fold(r'\s*[,،;]\s*|\s+(?:এবং|আর|ও)\s+'))))
      if (x.trim().isNotEmpty) x.trim().replaceAll(RegExp(r'[।.!]+$'), ''),
  ];
  if (parts.length < 2) return null;
  final verb = RegExp(fold(r'(?<=\s|^)(দিলাম|দিয়েছি|দিয়েছি|দিছি|দিয়েছিলাম|নিলাম|নিয়েছি|নিয়েছি|পেলাম|পেয়েছি|পেয়েছি|ফেরত\s+দিলাম|ফেরত\s+পেলাম)(?=\s|$)'));
  final first = verb.firstMatch(fold(parts.first));
  if (first == null || findAmount(normalize(parts.first)) == null) return null;
  final out = <Command>[];
  for (final (i, x) in parts.indexed) {
    final f = fold(x);
    if (findAmount(normalize(x)) == null) return null;
    // A later part names a person ("ইসমাঈলকে", "রবিনের কাছ থেকে") and no verb of its own.
    if (i > 0 && (verb.hasMatch(f) || !RegExp(fold(r'\S+(?:কে|কেও|রে|র\s+কাছ\s+থেকে|ের\s+কাছ\s+থেকে|এর\s+কাছ\s+থেকে)(?=\s)')).hasMatch(f))) return null;
    final c = p.parse(i == 0 ? x : '$x ${first[1]}');
    if (c is! LedgerAdd || c.person.trim().isEmpty) return null;
    out.add(c);
  }
  return out;
}

/// A title that only counts ("কয়েকটি", "কিছু কাজ আছে"): nothing to do is named.
bool onlyCount(String title) {
  const filler = ['কয়েকটি', 'কয়েকটা', 'কয়েক', 'কিছু', 'অনেক', 'অনেকগুলো', 'বেশ', 'কয়টা', 'কয়টি', 'কতগুলো', 'কাজ', 'কাজও', 'আছে', 'আমার', 'আজ', 'আজকে', 'কাল', 'কালকে', 'এই', 'সপ্তাহে', 'মাসে', 'বছরে', 'টা', 'টি', 'গুলো', 'দুইটা', 'তিনটা', 'চারটা', 'পাঁচটা'];
  final w = words(normalize(title));
  return w.isNotEmpty && w.every((x) => filler.map(normalize).contains(x) || RegExp(r'^\d+(?:টা|টি)?$').hasMatch(x));
}

/// "২৪ তারিখে দাওয়াত, ৩১ তারিখে তুবার জন্মদিন, ৪ তারিখে মোস্তাফার
/// জন্মদিন": several things, each starting with its own day — each read on
/// its own (a to-do, a birthday…), never joined into one title.
List<Command>? datedClauses(String said, Parser p) {
  final months = bnMonths.map(fold).join('|');
  final starts = RegExp('^\\s*[০-৯0-9]{1,2}(?:ই|শে|লা|রা|ঠা)?\\s+(?:(?:$months)|${fold('তারিখ')})\\S*\\s+\\S');
  final parts = [
    for (final x in fold(said).split(RegExp(fold(r'\s*[,،।;]\s*|\s+(?:এবং|আর|তারপর)\s+'))))
      if (x.trim().isNotEmpty) x.trim(),
  ];
  if (parts.length < 2 || !parts.every(starts.hasMatch)) return null;
  final out = <Command>[];
  for (final x in parts) {
    final c = p.parse(x);
    if (c is NotUnderstood || c is SearchQuery || c is NoteAdd) return null;
    out.add(c);
  }
  return out;
}

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
  var f = fold(said);
  // "বাজারে গিয়েছি ৫০০০ টাকা নিয়ে।": the money taken along is not spent —
  // only what was bought after it is.
  final carried = RegExp(fold(r'^[^।.!?,]*?(?:[০-৯0-9][০-৯0-9]*|হাজার|শ)\s*টাকা\s+(?:নিয়ে|সাথে\s+নিয়ে|হাতে\s+নিয়ে)(?:\s+(?:গিয়েছি|গিয়েছিলাম|গেলাম|গেছি|বের\s+হয়েছি|বের\s+হলাম))?[^।.!?,]*[।.!,]\s*')).firstMatch(f);
  if (carried != null) f = f.substring(carried.end);
  final total = RegExp(fold(r'[,،]?\s*(?:মোট|সব\s+মিলিয়ে|টোটাল)\s+(.+?)\s*(?:টাকা)?\s*[।.]?\s*$')).firstMatch(f);
  final body = total == null ? f : f.substring(0, total.start);
  final pieces = body.split(RegExp(fold(r'\s*[,،;।]\s*|\s+(?:আর|এবং|ও)\s+'))).map((x) => x.trim()).where((x) => x.isNotEmpty).toList();
  if (pieces.length < 2) return null;
  // "আগের পাঁচশ নয়, সাতশ হবে": a correction, not a list.
  if (RegExp(fold(r'(?:^|\s)(?:না|নয়|নাহ|নয়)(?=\s|,|$)')).hasMatch(f) || RegExp(fold(r'(?:হবে|দেব|দেবো|করব|লাগবে)')).hasMatch(f)) return null;
  // Only a list of spending: said as spending ("খরচ", "মোট"), or short
  // "<where> <amount>" parts — never dated plans or people's names.
  final spendSaid = RegExp(fold(r'(?:খরচ|ব্যয়|মোট|টোটাল|গেল|গেছে|কিনলাম|কিনেছি|কিনছি|কেনা|কিনে)')).hasMatch(f) || carried != null;
  if (!spendSaid && pieces.any((x) => words(normalize(x)).length > 3)) return null;
  final w = parseWhen(said, p.now);
  if (w != null && w.hasDay && !RegExp(fold(r'(?:আজ|আজকে)')).hasMatch(fold(said))) return null;
  final out = <CashAdd>[];
  for (final x in pieces) {
    final amount = findAmount(normalize(x));
    if (amount == null || amount <= 0) return null;
    // Each part names where it went ("বাজারে", "রিকশায়") — no person, no verb of owing.
    final c = p.parse('${x.replaceAll(RegExp(fold(r'\s+(?:কিনলাম|কিনেছি|কিনছি|কিনে\s+আনলাম|দিছি|দিলাম|দিয়েছি|দিয়েছি)$')), '')} টাকা খরচ হয়েছে');
    if (c is! CashAdd || c.kind != CashKind.expense) return null;
    // Each keeps its own words ("রুটি ২০ টাকার") — the note, and what the list shows.
    out.add(CashAdd(x, kind: CashKind.expense, amount: amount, category: c.category));
  }
  if (total != null) {
    final t = findAmount(normalize(total[1]!));
    if (t == null) return null;
  }
  return out;
}

/// Several money events in one message, each its own part with its own
/// amount and verb: each read on its own (income, spending, or a person's
/// লেনদেন). A shared "আজ"/"গতকাল" at the front goes with every part. Null
/// unless every part is money with exactly its own amount.
List<Command>? mixedCash(String said, Parser p) {
  final pieces = [for (final x in said.split(RegExp(r'\s*[,،;।]\s*'))) if (x.trim().isNotEmpty) x.trim()];
  if (pieces.length < 2) return null;
  final lead = RegExp(fold(r'^(আজ|আজকে|গতকাল|গত\s+কাল)\s')).firstMatch(fold(pieces.first));
  final out = <Command>[];
  for (final (i, x) in pieces.indexed) {
    final amount = findAmount(normalize(x));
    if (amount == null || amount <= 0) return null;
    final c = p.parse(i > 0 && lead != null && !RegExp(fold(r'^(?:আজ|আজকে|গতকাল|গত\s+কাল)\s')).hasMatch(fold(x)) ? '${lead[1]} $x' : x);
    if (c is CashAdd && c.amount == amount) {
      out.add(c);
    } else if (c is LedgerAdd && c.amount == amount && c.person.trim().isNotEmpty) {
      out.add(c);
    } else {
      return null;
    }
  }
  return out.whereType<CashAdd>().isEmpty ? null : out;
}

/// "খাবার (চা)": the খাত, and what it was, when that says more.
String _withItem(String category, String item) {
  // "নাহিয়ান বেতন" under বেতন: the খাত is not said twice.
  final cat = words(normalize(category)).toSet();
  final rest = [for (final w in item.split(' ')) if (!cat.contains(normalize(w))) w].join(' ');
  if (rest.isEmpty || normalize(category).contains(normalize(rest))) return category;
  return '$category ($rest)';
}

/// "আমার শিক্ষার্থীদের মাঝে, মাহি ২০০০ টাকা দিছে, আখি ৫০০ টাকা, ফয়সাল ১০০০
/// টাকা।": one "দিছে" for several people — each one's money in. Someone
/// already in the লেনদেন book is asked as before (paid back or lent); the
/// rest is income — into the separate account the words point to
/// ("শিক্ষার্থীদের" → "শিক্ষার্থীদের বেতন"). Null when it is not such a list.
List<Command>? peopleGave(String said, Parser p) {
  final sentences = [for (final x in said.split(RegExp(r'\s*[।!]\s*'))) if (x.trim().isNotEmpty) x.trim()];
  final give3 = RegExp(fold(r'(?:^|\s)(?:দিছে|দিয়েছে|দিয়েছে|দিল|দিলো|দিয়েছেন|দিয়েছেন|পাঠিয়েছে|পাঠিয়েছে|দিয়ে\s+গেছে)(?=[\s,।]|$)'));
  final out = <Command>[];
  var found = false;
  for (final s in sentences) {
    final parts = [for (final x in s.split(RegExp(r'\s*[,،;]\s*'))) if (x.trim().isNotEmpty) x.trim()];
    final f0 = fold(s);
    if (!found && give3.hasMatch(f0) && parts.length >= 2) {
      final context = <String>[];
      final items = <(String, String, int)>[];
      var ok = true;
      for (final x in parts) {
        final amount = findAmount(normalize(x));
        if (amount == null) {
          if (items.isEmpty) {
            context.add(x);
            continue;
          }
          ok = false;
          break;
        }
        // "<name> <amount> টাকা (দিছে)": one or two words of name first.
        final m = RegExp(fold(r'^(\S+(?:\s+\S+)?)\s+[০-৯0-9][০-৯0-9,]*\s*(?:হাজার\s+)?টাকা(?:\s+\S+)?$')).firstMatch(fold(x));
        if (m == null || RegExp(r'^[০-৯0-9]').hasMatch(m[1]!)) {
          ok = false;
          break;
        }
        items.add((x.substring(0, m[1]!.length).trim(), x, amount));
      }
      if (ok && items.length >= 2) {
        found = true;
        final ctx = fold(context.join(' '));
        final salary = RegExp(fold(r'(?:শিক্ষার্থী|ছাত্র|ছাত্রী|স্টুডেন্ট|টিউশন|বেতন)')).hasMatch(fold(s));
        String? project;
        final d = p.data;
        if (d != null) {
          for (final pr in d.projects.where((x) => !x.closed)) {
            final first = words(normalize(pr.name)).where((w) => w.length >= 4).firstOrNull;
            if (first != null && (ctx.contains(fold(first)) || projectMeant(d, s)?.id == pr.id)) {
              project = pr.name;
              break;
            }
          }
        }
        for (final (name, text, amount) in items) {
          final c = p.parse(give3.hasMatch(fold(text)) ? text : '$text দিয়েছে');
          if (c is LedgerAdd && p.ledger.any((e) => normalize(e.person) == normalize(name))) {
            out.add(c);
          } else {
            out.add(CashAdd('$name ${bnNumber(amount)} টাকা', kind: CashKind.income, amount: amount, category: salary ? 'বেতন' : 'অন্যান্য আয়', project: project));
          }
        }
        continue;
      }
    }
    final c = p.parse(s);
    if (c is NotUnderstood) continue;
    out.add(c);
  }
  return found ? out : null;
}
