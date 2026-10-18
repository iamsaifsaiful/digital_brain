// What kind of statement a sentence is — done, planned, owed, asked to be
// reminded, conditional, negated or a question — decided from the whole
// sentence (its verb forms and question words), before any money rule may
// write to the book. And the shared check every command passes through,
// whether it came from these rules or from the AI (see [checked]).
part of 'parser.dart';

enum Aspect {
  /// "দিলাম", "দিয়েছি", "দিয়েছিলাম", "ফেরত পেয়েছি": it happened.
  done,

  /// "দেব", "করব", "শুক্রবার দেব": the person means to.
  future,

  /// "দিতে হবে", "ফেরত দেওয়া বাকি": something to do.
  duty,

  /// "দিতে মনে করিও", "রিমাইন্ডার দাও".
  remind,

  /// "বেতন পেলে দেব", "টাকা দিলে…".
  conditional,

  /// "দিইনি", "দিলাম না", "পাইনি": it did not happen.
  negated,

  /// "কত পাই?", "কাকে কত দেব?".
  question,

  /// None of these could be told.
  unknown,
}

String _af(String said) => ' ${fold(said).replaceAll(RegExp(r'[।!,;:"“”]'), ' ').toLowerCase()} ';

/// The kind of statement [said] is. The order matters: a question or a
/// negative decides first, then a reminder, a condition, a duty, a plan;
/// a past verb last.
Aspect aspectOf(String said) {
  final f = _af(said);
  // "কে"/"কার" alone after a name is often the recogniser splitting
  // "সজীবকে" ("সজীব কে ৩০০ টাকা দিলাম"): a question word only at the start.
  if (said.contains('?') || _thas(f, r'(?<=\s)(?:কত|কী|কি|কাকে|কবে|কোথায়|কয়টা|কিনা|নাকি)(?=\s)') || _thas(f, r'^\s*(?:কে|কার|কারা)(?=\s)')) return Aspect.question;
  if (_thas(f, r'(?<=\s)\S+(?:িনি|ইনি)(?=\s)') ||
      _thas(f, r'(?<=\s)(?:দিই|দেই|দেয়|দিয়|নিই|নেই|নেয়|পাই|করি|দিলাম|নিলাম|পেলাম|করলাম|দেননি|দেয়নি)\s+(?:নাই|নি|না)(?=\s)')) {
    return Aspect.negated;
  }
  if (_thas(f, r'(?:মনে\s+(?:করিও|করাইও|করিয়ো|করিয়ে|করাবে|করাবা|করাও)|রিমাইন্ডার|reminder|জানিয়ে\s+দিও|জানাবে|জানিও)')) return Aspect.remind;
  if (_thas(f, r'(?<=\s)(?:দিলে|পেলে|হলে|করলে|নিলে|এলে|আসলে|দিলেই|পেলেই|হলেই|ফিরলে|থাকলে)(?=\s)')) return Aspect.conditional;
  if (_thas(f, r'(?<=\s)\S+তে\s+(?:হবে|লাগবে|হইবে|হইব)(?=\s)') || _thas(f, r'(?<=\s)(?:দেওয়া|নেওয়া|শোধ\s+করা|ফেরত\s+দেওয়া)\s+(?:লাগবে|বাকি|দরকার)(?=\s)')) return Aspect.duty;
  for (final w in words(normalize(f))) {
    if (RegExp(_tf(r'(?:বো|ব|মু)$')).hasMatch(w) && _nounOfVerb(w) != null) return Aspect.future;
  }
  if (_thas(f, r'(?<=\s)\S+(?:েছি|েছিলাম|েছিল|িলাম|লাম|লুম|ছি|সি)(?=\s)') || _thas(f, r'(?<=\s)(?:দিলাম|নিলাম|পেলাম|করলাম|দিল|দিলো|নিল|পেল)(?=\s)')) return Aspect.done;
  return Aspect.unknown;
}

/// Money talk: taka, a loan, paying back, owing.
bool _moneyTalk(String said) {
  final f = _af(said);
  final n = ' ${normalize(said)} ';
  return _thas(f, r'(?:টাকা|টাকার|৳|taka|ধার|কর্জ|ফেরত|শোধ|পাওনা|দেনা|হাওলাত)') || _thas(n, r'(?:টাকা|ধার|ফেরত|শোধ)') || _amountIn(f);
}

/// Money said as a plan, a duty, a reminder or a condition — never a
/// transaction. "সজীবকে শুক্রবার পাঁচশ টাকা ধার দেব" → a to-do for
/// Friday; "শুক্রবার সজীবকে টাকা ফেরত দিতে মনে করিও" → a reminder whose
/// time is asked; "সজীবকে টাকা ফেরত দিতে হবে" → a to-do. Null when [said]
/// is not such a sentence (the money rules read it as before).
Command? moneyNotNow(String said, DateTime now) {
  if (!_moneyTalk(said)) return null;
  final a = aspectOf(said);
  final f = _af(said);
  switch (a) {
    case Aspect.remind:
      final title = reminderWords(withoutWhen(withoutClockWords(said)));
      final when = parseWhen(said, now);
      final t = title.isEmpty ? defaultReminderTitle : title;
      if (when == null) return ReminderAdd(said, title: t, at: noTimeYet);
      if (!when.hasTime) return ReminderAdd(said, title: t, at: noTimeYet, day: when.day);
      return ReminderAdd(said, title: t, at: when.at);
    case Aspect.future:
    case Aspect.duty:
    case Aspect.conditional:
      // "রহিমকে আমার ১০০০ টাকা দিতে হবে": a debt stated (the book asks
      // once before writing it), not a plan.
      if (a == Aspect.duty && _thas(f, r'(?<=\s)আমার\s+(?:\S+\s+)?(?:[০-৯0-9]|\S+শ|\S+হাজার)') && !_thas(f, r'ফেরত')) return null;
      // "ইসমাইলের কাছে আমি ৫ হাজার টাকা পাব": what is owed to the user,
      // stated — the book's own rule (asked once before writing).
      final n = ' ${normalize(said)} ';
      if (_thas(n, r'(?<=\s)\S*কাছে(?=\s)') && _thas(n, r'(?<=\s)(?:পাব|পাবো|পামু|পাই)(?=\s)') && findAmount(normalize(withoutWhen(said))) != null) return null;
      // "রহিমের কাছ থেকে টাকা ফেরত পাব" with no amount: how much is asked,
      // nothing is written.
      if (_thas(f, r'(?<=\s)(?:পাব|পাবো|পামু)(?=\s)') && findAmount(normalize(withoutWhen(said))) == null) {
        return TaskEdit(said, say: 'কত টাকা পাবেন বললে লেনদেনের খাতায় লিখে রাখব — যেমন “রহিমের কাছে ৫০০ টাকা পাব”।');
      }
      return _tdAdd(said, f, const [], now);
    default:
      return null;
  }
}

/// The one check every command goes through before anything is done, from
/// the rules or from the AI:
/// - a money event that was not a past, done event is not written;
/// - a reminder with only a part of the day ("কাল সকালে") asks the hour;
/// - nothing the AI says is trusted as an id — to-dos are found by words
///   on the phone.
Command checked(Command c, String said, DateTime now) {
  switch (c) {
    case LedgerAdd() || LedgerSet() || CashAdd():
      final a = aspectOf(said);
      if (a == Aspect.negated) return SmallTalk(said, kind: Talk.nothingDone);
      // "সজীবকে টাকা দিলে কত থাকবে?": a question — what is kept is shown,
      // nothing is written.
      if (a == Aspect.question) {
        final person = switch (c) { LedgerAdd(:final person) => person, LedgerSet(:final person) => person, _ => '' };
        if (c is CashAdd) return CashQuery(said);
        return person.isEmpty ? LedgerQuery(said, ask: LedgerAsk.all) : LedgerQuery(said, ask: LedgerAsk.person, person: person);
      }
      if (a == Aspect.future || a == Aspect.duty || a == Aspect.remind || a == Aspect.conditional) {
        return moneyNotNow(said, now) ?? c;
      }
      return c;
    case ReminderAdd(:final alarm, :final repeat, :final part) when !alarm && part == null && !repeat.isInterval:
      final p = partOnly(c.transcript);
      if (p == null) return c;
      if (c.needsTime) {
        return ReminderAdd(c.transcript, title: c.title, at: c.at, repeat: c.repeat, alarm: c.alarm, weekdays: c.weekdays, minutesBefore: c.minutesBefore, day: c.day, part: p);
      }
      // A day word said: that day; else the day the reading landed on.
      return ReminderAdd(c.transcript,
          title: c.title, at: noTimeYet, repeat: c.repeat, alarm: c.alarm, weekdays: c.weekdays, minutesBefore: c.minutesBefore, day: dayOnly(c.at), part: p);
    default:
      return c;
  }
}

/// "আজ সজীবকে দুইশ ফেরত দিয়েছি, বাকি তিনশ শুক্রবার দেব, বৃহস্পতিবার মনে
/// করিও": money said in parts that happened at different times — each its
/// own command (a payment made, a to-do, a reminder), the person carried to
/// the parts that leave it out, the reminder about the to-do before it.
/// Never one payment of the whole. Null when [said] is not such a sentence.
List<Command>? moneyClauses(String said, Parser p) {
  if (!_moneyTalk(said)) return null;
  final parts = [
    for (final x in said.split(RegExp(fold(r'[।;]+|,\s*|\s+(?:এবং|আর|তারপর|তারপরে)\s+'))))
      if (x.trim().isNotEmpty) x.trim(),
  ];
  if (parts.length < 2) return null;
  // "পাঁচশ টাকা, না সাতশ টাকা দিলাম": a change of mind, one event.
  if (applySelfCorrection(normalize(said)) != normalize(said)) return null;
  final kinds = [for (final x in parts) aspectOf(x)];
  if (kinds.contains(Aspect.unknown) || kinds.toSet().length < 2) return null;
  var person = '';
  var last = '';
  final out = <Command>[];
  for (final part in parts) {
    var x = part;
    final money = _moneyTalk(x) || aspectOf(x) == Aspect.future || aspectOf(x) == Aspect.duty;
    if (person.isNotEmpty && money && !fold(x).contains(fold(person))) x = '${toPerson(person)} $x';
    var c = p.parse(x);
    if (c is LedgerAdd && c.person.isNotEmpty) {
      person = c.person;
      last = '${toPerson(person)} টাকা দেওয়া';
    } else if (c is TaskAdd) {
      last = c.title;
    } else if (c is ReminderAdd && (c.needsTitle || reminderWords(c.title).isEmpty) && last.isNotEmpty) {
      c = ReminderAdd(c.transcript, title: last, at: c.at, repeat: c.repeat, alarm: c.alarm, weekdays: c.weekdays, minutesBefore: c.minutesBefore, day: c.day, part: c.part);
    } else if (c is Clarify) {
      // A choice (e.g. which Friday) stays a choice; its to-do names the reminder.
      final first = c.options.isEmpty ? null : c.options.first.$2;
      if (first is TaskAdd) last = first.title;
    } else if (c is NotUnderstood || c is SearchQuery || c is NoteAdd || c is SmallTalk) {
      return null;
    }
    out.add(c);
  }
  return out;
}
