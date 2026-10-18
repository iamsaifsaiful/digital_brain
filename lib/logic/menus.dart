// The menus beyond to-dos, reminders and the money book: what a sentence
// asks of accounts, savings and instalments, medicines, habits, what to keep
// in mind, alarms, the bin, the calendar, backup, settings, projects and
// the shop — read from the verb's time and intent and the user's own saved
// names (never from a keyword alone), into one typed shape ([MenuAction])
// that the chat's executor (state/menu_chat.dart) carries out and reports
// truthfully. What exists by voice is listed in app_map.dart ([voiceCaps]).
part of 'parser.dart';

/// One request about a menu, typed: [domain] and [op] (both from
/// [voiceCaps]) with what the sentence gave. Names are as said — the
/// executor resolves them to saved records by id (never trusted as ids).
class MenuAction extends Command {
  const MenuAction(super.transcript,
      {required this.domain, required this.op, this.target = '', this.target2 = '', this.amount = 0, this.amount2 = 0, this.day, this.until, this.time, this.text = '', this.part = ''});

  /// 'accounts', 'savings', 'installment', 'medicine', 'habit', 'memory',
  /// 'alarm', 'trash', 'calendar', 'backup', 'settings', 'project', 'shop',
  /// 'cash', 'health', 'emergency', 'vault', 'app', or a menu id for
  /// 'unsupported'.
  final String domain;
  final String op;

  /// A name as said: an account, goal, medicine, habit, project, shop,
  /// person, family member, or the words of a memory.
  final String target;

  /// The second name (a transfer's destination).
  final String target2;

  /// Taka (whole), a count (pills), or a reading.
  final int amount;

  /// A second amount: a transfer's fee, the paid part of a credit sale.
  final int amount2;

  /// The day it is about (a habit's day, a dose's day, a query's first day).
  final DateTime? day;

  /// The end of a query's span (exclusive).
  final DateTime? until;

  /// Minutes after midnight (a dose's time), when said.
  final int? time;

  /// Free text: what to keep, a category, a setting's value.
  final String text;

  /// "সকাল", "রাত" … when only a part of the day was said.
  final String part;
}

// ───────────── numbers said in words (health readings, phone digits) ─────────────

const _bnNumbers1to99 = <String, int>{
  'শূন্য': 0, 'জিরো': 0, 'এক': 1, 'দুই': 2, 'দু': 2, 'তিন': 3, 'চার': 4, 'পাঁচ': 5, 'পাচ': 5, 'ছয়': 6, 'ছ': 6, 'সাত': 7, 'আট': 8, 'নয়': 9,
  'দশ': 10, 'এগারো': 11, 'এগার': 11, 'বারো': 12, 'বার': 12, 'তেরো': 13, 'তের': 13, 'চৌদ্দ': 14, 'পনেরো': 15, 'পনের': 15, 'ষোলো': 16, 'ষোল': 16,
  'সতেরো': 17, 'সতের': 17, 'আঠারো': 18, 'আঠার': 18, 'উনিশ': 19, 'বিশ': 20, 'কুড়ি': 20, 'একুশ': 21, 'বাইশ': 22, 'তেইশ': 23, 'চব্বিশ': 24,
  'পঁচিশ': 25, 'ছাব্বিশ': 26, 'সাতাশ': 27, 'আঠাশ': 28, 'ঊনত্রিশ': 29, 'উনত্রিশ': 29, 'ত্রিশ': 30, 'তিরিশ': 30, 'একত্রিশ': 31, 'বত্রিশ': 32,
  'তেত্রিশ': 33, 'চৌত্রিশ': 34, 'পঁয়ত্রিশ': 35, 'ছত্রিশ': 36, 'সাঁইত্রিশ': 37, 'আটত্রিশ': 38, 'ঊনচল্লিশ': 39, 'উনচল্লিশ': 39, 'চল্লিশ': 40,
  'একচল্লিশ': 41, 'বিয়াল্লিশ': 42, 'তেতাল্লিশ': 43, 'চুয়াল্লিশ': 44, 'পঁয়তাল্লিশ': 45, 'ছেচল্লিশ': 46, 'সাতচল্লিশ': 47, 'আটচল্লিশ': 48,
  'ঊনপঞ্চাশ': 49, 'উনপঞ্চাশ': 49, 'পঞ্চাশ': 50, 'একান্ন': 51, 'বাহান্ন': 52, 'তিপ্পান্ন': 53, 'চুয়ান্ন': 54, 'পঞ্চান্ন': 55, 'ছাপ্পান্ন': 56,
  'সাতান্ন': 57, 'আটান্ন': 58, 'ঊনষাট': 59, 'উনষাট': 59, 'ষাট': 60, 'একষট্টি': 61, 'বাষট্টি': 62, 'তেষট্টি': 63, 'চৌষট্টি': 64, 'পঁয়ষট্টি': 65,
  'ছেষট্টি': 66, 'সাতষট্টি': 67, 'আটষট্টি': 68, 'ঊনসত্তর': 69, 'উনসত্তর': 69, 'সত্তর': 70, 'একাত্তর': 71, 'বাহাত্তর': 72, 'তিয়াত্তর': 73,
  'চুয়াত্তর': 74, 'পঁচাত্তর': 75, 'ছিয়াত্তর': 76, 'সাতাত্তর': 77, 'আটাত্তর': 78, 'ঊনআশি': 79, 'উনআশি': 79, 'আশি': 80, 'একাশি': 81,
  'বিরাশি': 82, 'তিরাশি': 83, 'চুরাশি': 84, 'পঁচাশি': 85, 'ছিয়াশি': 86, 'সাতাশি': 87, 'আটাশি': 88, 'ঊননব্বই': 89, 'উননব্বই': 89, 'নব্বই': 90,
  'একানব্বই': 91, 'বিরানব্বই': 92, 'তিরানব্বই': 93, 'চুরানব্বই': 94, 'পঁচানব্বই': 95, 'ছিয়ানব্বই': 96, 'সাতানব্বই': 97, 'আটানব্বই': 98, 'নিরানব্বই': 99,
};
final _bnNum = {for (final e in _bnNumbers1to99.entries) fold(e.key): e.value};

/// Numbers said in words written as digits, keeping everything else:
/// "একশ ত্রিশ বাই পঁচাশি" → "130 বাই 85", "ছয় দশমিক আট" → "6.8",
/// "পাঁচ ফুট ছয় ইঞ্চি" → "5 ফুট 6 ইঞ্চি". Not for money (see findAmount).
String spokenNumbers(String said) {
  final ws = fold(said).split(RegExp(r'\s+'));
  final out = <String>[];
  int? valueAt(int i, List<int> used) {
    if (i >= ws.length) return null;
    final w0 = ws[i].replaceAll(RegExp(r'[,।]$'), '');
    // "নয়" alone is "not" ("১৩০ নয় ১২০"); nine is "নয়টা", "নয় দশমিক…".
    if (w0 == fold('নয়') && !(i + 1 < ws.length && (ws[i + 1] == fold('দশমিক') || _bnNum.containsKey(ws[i + 1])))) return null;
    // "দশটা" → "দশ", but "পঁয়ষট্টি" is a number as it is.
    final w = _bnNum.containsKey(w0) ? w0 : w0.replaceAll(RegExp(fold(r'(?:টা|টি|টো)$')), '');
    var hundreds = 0;
    var at = i;
    final h = RegExp(fold(r'^(.+?)(?:শো|শ|শত)$')).firstMatch(w);
    if (h != null && _bnNum[h[1]] != null && _bnNum[h[1]]! < 10) {
      hundreds = _bnNum[h[1]]! * 100;
      at++;
    } else if (w == fold('একশ') || w == fold('একশো')) {
      hundreds = 100;
      at++;
    }
    if (hundreds > 0) {
      final next = at < ws.length ? _bnNum[ws[at].replaceAll(RegExp(r'[,।]$'), '')] : null;
      used.add(next == null ? at - i : at - i + 1);
      return hundreds + (next ?? 0);
    }
    final v = _bnNum[w];
    if (v == null) return null;
    used.add(1);
    return v;
  }

  for (var i = 0; i < ws.length;) {
    final used = <int>[];
    final v = valueAt(i, used);
    if (v == null) {
      out.add(ws[i]);
      i++;
      continue;
    }
    i += used.first;
    // "ছয় দশমিক আট": a decimal.
    if (i + 1 < ws.length && (ws[i] == fold('দশমিক') || ws[i] == fold('পয়েন্ট') || ws[i] == 'point')) {
      final used2 = <int>[];
      final d = valueAt(i + 1, used2);
      if (d != null) {
        out.add('$v.$d');
        i += 1 + used2.first;
        continue;
      }
    }
    out.add('$v');
  }
  return out.join(' ');
}

/// "শূন্য এক সাত এক এক …" (ten or more digits said one by one) → "০১৭১১…";
/// the leading zero kept. Other words stay.
String spokenDigits(String said) {
  final ws = fold(said).split(RegExp(r'\s+'));
  final out = <String>[];
  for (var i = 0; i < ws.length;) {
    var j = i;
    final digits = StringBuffer();
    while (j < ws.length) {
      final w = ws[j].replaceAll(RegExp(r'[,।]$'), '');
      final v = _bnNum[w];
      if (v == null || v > 9) break;
      digits.write(v);
      j++;
    }
    if (j - i >= 10) {
      out.add(bnDigits(digits.toString()));
      i = j;
    } else {
      out.add(ws[i]);
      i++;
    }
  }
  return out.join(' ');
}

// ───────────────────────── reading the sentence ─────────────────────────

String _mf(String said) => ' ${fold(englishTimes(said)).replaceAll(RegExp(r'[।!,;:"“”?]'), ' ').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim()} ';

/// The first of [names] said in [f] (folded, padded), longest first.
String? _named(String f, Iterable<String> names) {
  final sorted = names.where((n) => n.trim().isNotEmpty).toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final n in sorted) {
    final k = fold(n.trim().toLowerCase());
    if (f.contains(' $k') || f.contains(k)) return n;
  }
  return null;
}

/// A habit's or medicine's name in the sentence by its stem: "হাঁটা" ~
/// "হাঁটছি", "হাঁটিনি", "হাঁটার".
bool _stemSaid(String f, String name) {
  final ws = words(normalize(name)).where((w) => w.length >= 2).toList();
  if (ws.isEmpty) return false;
  final said = words(normalize(f));
  bool hit(String w) {
    var s = w;
    if (s.length >= 3 && RegExp(fold(r'[াোে]$')).hasMatch(s)) s = s.substring(0, s.length - 1);
    // "হাঁটা" → "হেঁটেছি": the vowel of the stem changes in the verb.
    final alt = s.replaceFirst('া', 'ে');
    return said.any((x) => x.startsWith(s) || x.startsWith(alt));
  }

  return ws.every(hit);
}

const _myRelations = [
  'শ্যালক', 'শালা', 'শ্যালিকা', 'শালী', 'ভাই', 'বোন', 'বন্ধু', 'বান্ধবী', 'বস', 'ম্যানেজার', 'স্ত্রী', 'বউ', 'বৌ', 'স্বামী', 'ছেলে', 'মেয়ে', 'মামা', 'মামি', 'চাচা', 'চাচি',
  'খালা', 'খালু', 'ফুপু', 'ফুফু', 'ফুপা', 'শ্বশুর', 'শাশুড়ি', 'দুলাভাই', 'ভাবি', 'ভাগ্নে', 'ভাগ্নি', 'ভাতিজা', 'ভাতিজি', 'নানা', 'নানি', 'দাদা', 'দাদি', 'প্রতিবেশী', 'সহকর্মী',
  'ক্লায়েন্ট', 'ড্রাইভার', 'ডাক্তার', 'শিক্ষক', 'স্যার',
];

/// Which account a word means: by the user's own names first, then by kind.
({String name, AccountKind? kind})? _accountIn(String part, AppData? d) {
  final f = ' ${fold(part.toLowerCase())} ';
  if (d != null) {
    final n = _named(f, [for (final a in d.accounts) a.name]);
    if (n != null) return (name: n, kind: null);
  }
  if (_thas(f, r'(?:বিকাশ|bkash)')) return (name: 'বিকাশ', kind: AccountKind.bkash);
  if (_thas(f, r'(?:রকেট|rocket)')) return (name: 'রকেট', kind: AccountKind.rocket);
  if (_thas(f, r'(?:ব্যাংক|ব্যাঙ্ক|bank)')) return (name: 'ব্যাংক', kind: AccountKind.bank);
  if (_thas(f, r'(?:হাতে|হাতের|ক্যাশ|cash|নগদ\s+টাকা|পকেট)')) return (name: 'নগদ', kind: AccountKind.cash);
  if (_thas(f, r'(?<=\s)নগদ(?:ে|এ|ের|এর)?(?=\s)')) {
    // "নগদ" is both cash in hand and the Nagad wallet: the user's own
    // Nagad account, if there is one; otherwise cash.
    final nagad = d?.accounts.any((a) => a.kind == AccountKind.nagad) ?? false;
    return (name: 'নগদ', kind: nagad ? AccountKind.nagad : AccountKind.cash);
  }
  return null;
}

/// What the sentence asks of a menu beyond to-dos, reminders and the money
/// book; null when it is not such a sentence (the other rules read it).
Command? menuCommand(String said, AppData? d, DateTime now) {
  final f = _mf(said);
  final a = aspectOf(said);
  final asking = isQuestionText(said) || a == Aspect.question || _thas(f, r'(?<=\s)(?:কত|কতদিন|কতদিনের|কয়দিন|কয়দিনের|কবে|কখন|কী|কি)(?=\s)');
  final negated = a == Aspect.negated;
  final amount = findAmount(normalize(withoutWhen(said)));

  // "লিখে রাখো: সব হিসাব মুছে ফেলো": what follows is the note — a command
  // written in it is never carried out.
  final quoted = RegExp(fold(r'^\s*(?:লিখে\s+রাখো|লিখে\s+রাখ|নোট\s+করো|নোট\s+করে\s+রাখো|মনে\s+রাখো)\s*[:：]\s*(.+)$')).firstMatch(fold(said));
  if (quoted != null && !mentionsSecret(quoted[1]!)) return NoteAdd(said, text: quoted[1]!.trim());

  // A PIN, OTP or password to keep: never a plain note, never repeated.
  if (mentionsSecret(said) && RegExp(r'[0-9০-৯]{3,}').hasMatch(said) && _thas(f, r'(?:মনে\s+রাখ|লিখে\s+রাখ|রেখে\s+দাও|রাখো|সেভ|save|নোট)')) {
    return MenuAction(said, domain: 'vault', op: 'secret');
  }

  // "সজীবকে টাকা দিলে কত থাকবে?": a what-if — the book as it stands is
  // shown, nothing is written.
  if (asking && _thas(f, r'(?<=\s)(?:দিলে|নিলে|পেলে|দিই|দেই)(?=\s)') && _thas(f, r'(?:থাকবে|থাকে|হবে|পাব|পাবো)') && _thas(f, r'(?:টাকা|ধার|পাওনা|দেনা)')) {
    final p0 = d == null ? null : _named(f, knownPeople(d.ledger));
    return p0 == null ? LedgerQuery(said, ask: LedgerAsk.all) : LedgerQuery(said, ask: LedgerAsk.person, person: p0);
  }
  // Lists that "এগুলো" can then point at (bulk_chat.dart).
  // (Questions — "কী কী ওষুধ আছে?" — are answered by the question rules,
  // which keep the same list too.)
  // (Not isQuestionText: that counts "দেখাও" itself as asking.)
  final realQuestion = said.contains('?') || _thas(f, r'(?<=\s)(?:কী|কি|কোন|কোনো|কয়টা|কতগুলো|কতগুলা)(?=\s)');
  final showing = _thas(f, r'(?:দেখাও|দেখান|দাও|দিন|বলো|বলুন)\s*$') && !realQuestion;
  // "আমার কোন নোট আছে?", "কী কী নোট আছে?": the notes, listed (no
  // question rule answers this one; a search would pick one thing).
  if (realQuestion && _thas(f, r'(?<=\s)(?:নোট|নোটগুলো|নোটগুলা)(?:\s+কী\s+কী|\s+কি\s+কি)?\s+(?:আছে|রাখা\s+আছে|কয়টা|কতগুলো)(?=\s)') && !_thas(f, r'(?<=\s)\S+(?:ের|এর)\s+নোট')) {
    return MenuAction(said, domain: 'notes', op: 'list');
  }
  if (showing && _thas(f, r'(?:ওষুধের\s+তালিকা|ওষুধগুলো|ওষুধগুলা|সব\s+ওষুধ)')) return MenuAction(said, domain: 'medicine', op: 'list');
  if (showing && _thas(f, r'(?:অভ্যাসগুলো|অভ্যাসগুলা|অভ্যাসের\s+তালিকা|সব\s+অভ্যাস)')) return MenuAction(said, domain: 'habit', op: 'list');
  final noteList = _tre(r'(?<=\s)(\S+?)(?:ের|এর|র)?\s+(?:নোট|নোটগুলো|নোটগুলা)\s+(?:দেখাও|দাও|বলো|দেখান)').firstMatch(f);
  if (noteList != null) return MenuAction(said, domain: 'notes', op: 'list', text: _tf(noteList[1]!) == _tf('সব') ? '' : noteList[1]!);
  final readings = _tre(r'^\s*(\S+?)(?:ের|এর|র)\s+(?:শেষ\s+)?(\S+?)(?:টা|টি)?\s+(?:মাপ|রিডিং)\S*\s+(?:দেখাও|দাও|বলো)').firstMatch(f);
  if (readings != null) {
    final who = readings[1]!;
    final n0 = _countOf(readings[2]!) ?? 5;
    return MenuAction(said, domain: 'health', op: 'list', target: _tf(who) == _tf('আমা') ? '' : who, amount: n0);
  }
  // "আজ মাপিনি": nothing measured — nothing written.
  if (_thas(f, r'(?:মাপিনি|মাপা\s+হয়নি|মাপি\s+নাই|মাপা\s+হয়নাই)')) return MenuAction(said, domain: 'health', op: 'none');
  // "বেতন পাইনি", "টাকা আসেনি": it did not happen — nothing written.
  if (negated && _thas(f, r'(?:বেতন|টাকা|আয়|ইনকাম)') && !_thas(f, r'(?:কাজ|বিল)')) return SmallTalk(said, kind: Talk.nothingDone);

  // "করিমকে লিখো, কাল মাল পাঠাব": a message to draft for করিম (sent only
  // when the user sends it from the messaging app).
  final draft = _tre(r'^\s*(\S+?)(?:কে|রে)\s+(?:লিখো|লেখো|লিখে\s+দাও|লিখে\s+পাঠাও|মেসেজ\s+লেখো|মেসেজে\s+লেখো)\s+(?:যে\s+)?(.+)$').firstMatch(f);
  if (draft != null && !_thas(f, r'(?:নোট|তালিকা|লিস্ট|খাতা)')) return CallPerson(said, person: draft[1]!, via: Via.sms, text: draft[2]!.trim());

  // "সজীবের শেষ তিনটা লেনদেন দেখাও": that person's records.
  final hist = _tre(r'^\s*(\S+?)(?:ের|এর|র)\s+(?:শেষ\s+|আগের\s+|সব\s+)?(?:\S+\s+)?লেনদেন\S*\s+(?:দেখাও|দেখান|বলো|বলুন)').firstMatch(f);
  if (hist != null && d != null) {
    final who = resolvePerson(hist[1]!, knownPeople(d.ledger));
    if (knownPeople(d.ledger).contains(who)) return MoneyListQuery(said, from: DateTime(2000), to: dayOnly(now).add(const Duration(days: 1)), label: 'এ পর্যন্ত', person: who);
  }
  // "ওর আগের পাঁচশটা আসলে সাতশ": that record corrected — not a new one.
  final actually = _tre(r'(\S+)\s+(?:আসলে|আসলেই|ঠিক\s+হবে|হবে)\s+(\S+)\s*$').firstMatch(f);
  if (actually != null && findAmount(normalize(actually[1]!.replaceAll(RegExp(fold(r'(?:টা|টি)$')), ''))) != null && findAmount(normalize(actually[2]!)) != null) {
    final a1 = findAmount(normalize(actually[1]!.replaceAll(RegExp(fold(r'(?:টা|টি)$')), '')))!, a2 = findAmount(normalize(actually[2]!))!;
    return ManageItem('${f.substring(0, actually.start).trim()} লেনদেন $a1 না $a2'.trim(), action: 'edit');
  }
  // "রিকশার খরচটা যাতায়াতে রাখো": a saved expense moved to another খাত.
  final recat = _tre(r'^\s*(\S+?)(?:ের|এর|র)\s+খরচ(?:টা|টি)?\s+(\S+)\s+(?:খাতে\s+)?(?:রাখো|দাও|সরাও|নাও|করো)\s*$').firstMatch(f);
  if (recat != null) {
    // "যাতায়াতে" → the খাত "যাতায়াত": a known one it starts with, else the
    // word without its ending.
    final w = fold(recat[2]!);
    final known = [...knownCategoryWords, if (d != null) ...knownCategories(d, CashKind.expense)]..sort((a, b) => b.length.compareTo(a.length));
    final cat = known.where((k) => w.startsWith(fold(k))).firstOrNull ?? recat[2]!.replaceAll(RegExp(fold(r'(?:তে|ে|এ|য়)$')), '');
    return MenuAction(said, domain: 'cash', op: 'recategorize', target: recat[1]!, text: cat);
  }
  // "আগের নোটে আলমারি নয়, ড্রয়ার হবে": that note's word changed — not a new note.
  final noteFix = _tre(r'(?:আগের|শেষ|ওই)\s+নোট(?:ে|টায়|টাতে)?\s+(\S+)\s+(?:নয়|না|নয়)\s+(\S+)\s+(?:হবে|লেখো|করো)').firstMatch(f);
  if (noteFix != null) return MenuAction(said, domain: 'notes', op: 'replace_word', target: noteFix[1]!, text: noteFix[2]!);
  // "একই খরচ দুইবার হয়েছে, একটা বাদ দাও": find the pair, ask once.
  if (_thas(f, r'(?:একই|একি)\s+(?:খরচ|আয়)') && _thas(f, r'(?:দুইবার|দুবার|২\s*বার|ডাবল)')) return MenuAction(said, domain: 'cash', op: 'dupes');
  // "রুপার দাম কত ধরে আছে?": the saved price, never today's guessed.
  if (asking && _thas(f, r'(?:রুপা|রূপা|সোনা|স্বর্ণ)\S*\s+(?:দাম|মূল্য)')) return MenuAction(said, domain: 'zakat', op: 'price', text: _thas(f, r'(?:সোনা|স্বর্ণ)') ? 'gold' : 'silver');

  // ── Health readings said in words ("একশ ত্রিশ বাই পঁচাশি", "ছয় দশমিক আট").
  final health = _healthWords(said, f, d, now, negated);
  if (health != null) return health;

  // ── Phone numbers said digit by digit ("শূন্য এক সাত …").
  final digits = spokenDigits(said);
  if (digits != fold(said)) return Parser(ledger: d?.ledger ?? const [], contacts: d?.contacts ?? const [], now: now, data: d)._parse(digits);

  // "ফোন দিও না, শুধু রহিমের নম্বর দেখাও": the "only" part is the request.
  final only = RegExp(fold(r'^(.+?\s(?:দিও|দিয়ো|করো|করবে|দিবা)\s+না)[,\s]+(?:শুধু|খালি|কেবল)\s+(.+)$')).firstMatch(fold(said));
  if (only != null) return Parser(ledger: d?.ledger ?? const [], contacts: d?.contacts ?? const [], now: now, data: d)._parse(only[2]!);

  // ── Accounts ──
  final acct = _accounts(said, f, d, now, amount, asking, negated, a);
  if (acct != null) return acct;

  // ── Savings goals ──
  if (d != null) {
    final goal = _named(f, [for (final g in d.goals) g.name]);
    if (!asking && amount != null && _thas(f, r'(?:জন্য|লক্ষ্য)') && _thas(f, r'(?:জমাব|জমাবো|জমাতে\s+চাই|সঞ্চয়\s+করব|লক্ষ্য\s+রাখো|লক্ষ্য\s+ঠিক)')) {
      final m = _tre(r'(?<=\s)(\S+?)(?:ের|এর|র)?\s+জন্য').firstMatch(f);
      final name = m == null ? '' : m[1]!;
      if (name.isNotEmpty) return MenuAction(said, domain: 'savings', op: 'goal_add', target: name, amount: amount);
    }
    if (!asking && !negated && amount != null && a == Aspect.done && (goal != null || _thas(f, r'(?:লক্ষ্যে|সঞ্চয়ে|সঞ্চয়\s+হিসাবে)')) && _thas(f, r'(?:জমিয়েছি|জমালাম|জমা\s+দিয়েছি|জমা\s+করেছি|রেখেছি|রাখলাম|দিলাম|দিয়েছি)')) {
      return MenuAction(said, domain: 'savings', op: 'deposit', target: goal ?? '', amount: amount);
    }
    if (!asking && amount != null && a == Aspect.done && _thas(f, r'(?:সঞ্চয়|লক্ষ্য)\S*\s+থেকে') && _thas(f, r'(?:তুলেছি|তুললাম|নিলাম|নিয়েছি|উঠিয়েছি)')) {
      return MenuAction(said, domain: 'savings', op: 'withdraw', target: goal ?? '', amount: amount);
    }
    if (asking && _thas(f, r'(?:লক্ষ্য|লক্ষ্যে)') && _thas(f, r'(?:বাকি|লাগবে|পূরণ)')) return MenuAction(said, domain: 'savings', op: 'goal_left', target: goal ?? '');
  }

  // ── Instalments / DPS ──
  if (_thas(f, r'(?:ডিপিএস|dps|কিস্তি|প্রিমিয়াম)')) {
    final day = _thas(f, r'গত\s+মাস') ? DateTime(now.year, now.month - 1) : DateTime(now.year, now.month);
    if (_thas(f, r'(?:ভুল\s+করে)') && _thas(f, r'(?:দিয়েছি|পেইড|paid|টিক)')) return MenuAction(said, domain: 'installment', op: 'unpay', day: day);
    if (negated) {
      // "কিস্তি দিইনি, কাল দেব": not paid; the plan is a to-do.
      final w = parseWhen(said, now);
      if (w != null && w.hasDay && dayOnly(w.day).isAfter(dayOnly(now))) return TaskAdd(said, title: 'কিস্তি দেওয়া', due: dayOnly(w.day));
      return MenuAction(said, domain: 'installment', op: 'not_paid', day: day);
    }
    if (!asking && a == Aspect.done && _thas(f, r'(?:দিয়েছি|দিলাম|জমা\s+দিয়েছি|পরিশোধ|শোধ\s+করেছি|দিয়ে\s+দিয়েছি)')) return MenuAction(said, domain: 'installment', op: 'paid', day: day);
  }

  // ── Medicines ──
  final med = _medicines(said, f, d, now, amount, asking, negated);
  if (med != null) return med;

  // ── Habits ──
  final habit = _habits(said, f, d, now, asking, negated);
  if (habit != null) return habit;

  // ── What to keep in mind about the user ──
  if (_thas(f, r'(?:আর\s+মনে\s+রেখো\s+না|আর\s+মনে\s+রাখবে\s+না|ভুলে\s+যাও|মনে\s+রাখার\s+দরকার\s+নেই)')) {
    final rest = f.replaceAll(_tre(r'(?:এই|ওই)?\s*(?:কথাটা|কথাটি|তথ্যটা|ব্যাপারটা)?\s*(?:আর\s+মনে\s+রেখো\s+না|আর\s+মনে\s+রাখবে\s+না|ভুলে\s+যাও|মনে\s+রাখার\s+দরকার\s+নেই)'), ' ').trim();
    return MenuAction(said, domain: 'memory', op: 'forget', text: rest);
  }
  if (!asking && amount == null) {
    final rel = _tre(r'^\s*(\S+(?:\s+\S+)?)\s+আমার\s+(\S+)\s*$').firstMatch(f);
    if (rel != null && _myRelations.any((r) => fold(rel[2]!).startsWith(fold(r)))) return MemoryAdd(said, text: said.trim().replaceAll(RegExp(r'[।.!]+$'), ''));
    // "আমি শুক্রবার অফিস করি না", "আমি চা খাই না": a standing habit — and
    // "…, কিন্তু আজ খেয়েছি" only today's exception, not a change.
    final routine = _tre(r'^\s*আমি\s+(.+?)\s+(?:করি|খাই|যাই|পড়ি|থাকি|নিই|দেখি|পছন্দ\s+করি)(?:\s+না)?\s*(?:$|,|কিন্তু)').firstMatch(f);
    if (routine != null && !_thas(f.split(fold('কিন্তু')).first, r'(?<=\s)(?:আজ|কাল|গতকাল|এখন|তারিখ)(?=\s)')) {
      final general = said.split(RegExp(fold(r'[,،]?\s*কিন্তু\s+'))).first.trim().replaceAll(RegExp(r'[।.!]+$'), '');
      return MemoryAdd(said, text: general);
    }
  }

  // ── Alarms in bulk ──
  if (_thas(f, r'(?:সব|সবগুলো|সকল)\s+(?:অ্যালার্ম|এলার্ম|alarm)') && _thas(f, r'(?:বন্ধ|অফ|off)')) return MenuAction(said, domain: 'alarm', op: 'all_off');

  // ── The bin ──
  final restore = _tre(r'(?:মুছে\s+ফেলা|ডিলিট\s+করা|মোছা)\s+(\S+)').firstMatch(f);
  if (restore != null && _thas(f, r'(?:ফেরত|ফিরিয়ে|ফিরিয়ে\s+আনো|restore|রিস্টোর)')) return MenuAction(said, domain: 'trash', op: 'restore', target: restore[1]!);

  // ── Calendar and time ──
  if (asking && _thas(f, r'বাংলা\s+(?:কত\s+)?তারিখ|বাংলা\s+মাস|বঙ্গাব্দ')) return SmallTalk(said, kind: Talk.date);

  // ── Backup ──
  if (_thas(f, r'(?:ব্যাকআপ|backup)')) {
    if (asking && _thas(f, r'(?:কবে|কখন|শেষ)')) return MenuAction(said, domain: 'backup', op: 'when');
    // "গুগল ব্যাকআপ অন আছে?", "ব্যাকআপ চালু তো?": on or off, and the last one.
    if (_thas(f, r'(?:অন|চালু|বন্ধ|অফ|on|off|হচ্ছে|হয়\s+তো|ঠিক\s+আছে|কাজ\s+করছে)') && (asking || _thas(f, r'(?:আছে|তো|কিনা)'))) return MenuAction(said, domain: 'backup', op: 'status');
    if (!asking && _thas(f, r'(?:নাও|নিন|করো|করুন|দাও)')) return MenuAction(said, domain: 'backup', op: 'now');
  }

  // ── Settings said by voice ──
  final callMe = _tre(r'আমাকে\s+(\S+(?:\s+\S+)?)\s+(?:বলে|নামে)\s+(?:ডাকো|ডাকবে|ডাকবা|ডাকবেন|ডাকিও)').firstMatch(f);
  if (callMe != null) return MenuAction(said, domain: 'settings', op: 'call_me', text: callMe[1]!.trim());
  if (_thas(f, r'(?:ডার্ক\s+মোড|dark\s+mode|অন্ধকার\s+(?:থিম|মোড)|কালো\s+থিম)')) return MenuAction(said, domain: 'settings', op: 'look', text: 'dark');
  if (_thas(f, r'(?:লাইট\s+মোড|light\s+mode|সাদা\s+থিম)')) return MenuAction(said, domain: 'settings', op: 'look', text: 'light');
  if (_thas(f, r'(?:লেখা|অক্ষর|ফন্ট)\s+(?:একটু\s+)?(?:বড়|বড়)')) return MenuAction(said, domain: 'settings', op: 'letters', text: 'bigger');
  if (_thas(f, r'(?:লেখা|অক্ষর|ফন্ট)\s+(?:একটু\s+)?(?:ছোট)')) return MenuAction(said, domain: 'settings', op: 'letters', text: 'smaller');
  if (_thas(f, r'(?<=\s)(?:ai|এআই|এ\s+আই)(?=\s)') && _thas(f, r'(?:বন্ধ|অফ|off|চালু|অন)') && !asking) return MenuAction(said, domain: 'settings', op: 'ai', text: _thas(f, r'(?:বন্ধ|অফ|off)') ? 'off' : 'on');

  // "ফাউন্ডেশনের নাম মৃত্তিকা ফাউন্ডেশন", "রহিমের আসল নাম রহিম উদ্দিন":
  // a person in the ধার-দেনা book gets their full name.
  if (d != null && !asking && !negated && amount == null) {
    final rn = _tre(r'^\s*(\S+(?:\s+\S+)?)(?:ের|এর|র)\s+(?:আসল\s+|পুরো\s+|সঠিক\s+|ঠিক\s+)?নাম\s+(?:হলো\s+|হল\s+|হচ্ছে\s+|বদলে\s+)?(.+?)(?:\s+(?:লেখো|লিখো|লিখে\s+রাখো|করো|কর|দাও|রাখো|হবে))?\s*$').firstMatch(f);
    if (rn != null) {
      final who = _named(' ${rn[1]} ', knownPeople(d.ledger));
      final to = rn[2]!.trim();
      if (who != null && to.isNotEmpty && words(to).length <= 5 && personKey(to) != personKey(who)) {
        return MenuAction(said, domain: 'people', op: 'rename', target: who, text: _origWords(said, to));
      }
    }
  }

  // ── Projects and the shop ──
  final biz = _business(said, f, d, now, amount, asking, negated, a);
  if (biz != null) return biz;

  // ── Own money questions by span and খাত ──
  final money = _cashQuestion(said, f, d, now, asking);
  if (money != null) return money;

  // ── The app itself ──
  if (asking && _thas(f, r'(?:আমি\s+কী\s+কী\s+রেখেছি|কী\s+কী\s+রাখা\s+আছে|আমার\s+কী\s+কী\s+আছে\s+অ্যাপে)')) return MenuAction(said, domain: 'app', op: 'summary');
  if (_thas(f, r'(?:কেন|কি\s+কারণে)\s+(?:আমার\s+)?(?:কথা|কথাটা)?\s*(?:বুঝলে|বুঝলা|বুঝতে\s+পারলে|বোঝোনি|বুঝোনি)')) return MenuAction(said, domain: 'app', op: 'why');
  if (asking && _thas(f, r'(?:প্রো|pro)\S*\s') && _thas(f, r'(?:কী\s+পাব|কি\s+পাব|কী\s+আছে|কি\s+আছে|সুবিধা)')) return MenuAction(said, domain: 'app', op: 'pro');
  if (asking && _thas(f, r'রিমাইন্ডার\S*\s.*(?:কেন\s+(?:হয়নি|বাজেনি|আসেনি|বাজল\s+না))')) return MenuAction(said, domain: 'app', op: 'why_reminder');
  if (asking && _thas(f, r'(?:বয়স)') && d != null) {
    final who = _named(f, [for (final s in d.specialDays) s.person]);
    if (who != null) return MenuAction(said, domain: 'special', op: 'age', target: who);
  }
  if (asking && _thas(f, r'(?:আগামী|পরের|সামনের|এই)\s+মাস\S*\s.*জন্মদিন')) return MenuAction(said, domain: 'special', op: 'month', day: _thas(f, r'(?<=\s)এই\s+মাস') ? DateTime(now.year, now.month) : DateTime(now.year, now.month + 1));
  if (!asking && _thas(f, r'(?:অ্যালার্জি|এলার্জি|allergy)') && negated == false && _thas(f, r'(?<=\s)(?:নেই|নাই)(?=\s)')) return MenuAction(said, domain: 'emergency', op: 'allergy_none');

  // ── Diary: a day's view, not a place to write ──
  if (_thas(f, r'(?:ডায়েরি|ডায়রি|ডাইরি|দিনলিপি)') && _thas(f, r'(?:লিখো|লেখো|লিখে|লিখ|যোগ\s+করো|রাখো)')) return MenuAction(said, domain: 'diary', op: 'unsupported');

  // ── Documents: a folder or file named with "খোলো/দেখাও" ──
  if (_thas(f, r'(?:ফোল্ডার|ফাইল|ফাইলটা|কাগজটা|ছবিটা|কাগজপত্র)') && _thas(f, r'(?:খোলো|খুলো|দেখাও|দেখান|খুলুন)')) {
    for (final e in docFolderWords.entries) {
      if (e.value.any((w) => f.contains(fold(w.toLowerCase())))) return OpenPlace(said, place: 'docs', folder: e.key);
    }
  }
  if (_thas(f, r'(?:pdf|পিডিএফ|ছবিতে|ফাইলে)') && _thas(f, r'(?:কী\s+লেখা|কি\s+লেখা|পড়ে\s+শোনাও|পড়ে\s+দাও)')) return MenuAction(said, domain: 'docs', op: 'read_unsupported');

  return null;
}

/// A menu clearly named in a request nothing else understood (or would only
/// have kept as a loose note): what it cannot do by voice is said, and its
/// page offered — nothing is saved. Null when no menu is named.
MenuAction? menuUnsupported(String said) {
  if (isQuestionText(said)) return null;
  final f = _mf(said);
  for (final (id, keys) in _menuStrongWords) {
    if (keys.any((k) => f.contains(fold(k)))) return MenuAction(said, domain: id, op: 'unsupported');
  }
  return null;
}

/// Words that clearly name a menu whose voice support is in [voiceCaps].
const _menuStrongWords = <(String, List<String>)>[
  ('accounts', ['অ্যাকাউন্ট', 'একাউন্ট', 'বিকাশ', 'রকেট']),
  ('savings', ['সঞ্চয়', 'ডিপিএস', 'dps', 'কিস্তি']),
  ('medicines', ['ওষুধ', 'ঔষধ']),
  ('habits', ['অভ্যাস']),
  ('shop', ['দোকান', 'রসিদ']),
  ('zakat', ['যাকাত', 'জাকাত']),
  ('emergency', ['অ্যালার্জি', 'এলার্জি', 'জরুরি কার্ড']),
  ('health', ['টিকা', 'ভ্যাকসিন', 'চেকআপ']),
  ('requests', ['রক্তের অনুরোধ', 'রক্ত লাগবে', 'রক্তদাতা']),
  ('settings', ['থিম', 'ভাষা বদল', 'ভাষা পাল্টাও']),
];

Command? _accounts(String said, String f, AppData? d, DateTime now, int? amount, bool asking, bool negated, Aspect a) {
  final hasAcct = _thas(f, r'(?:বিকাশ|bkash|রকেট|ব্যাংক|ব্যাঙ্ক|হাতে|নগদ|ক্যাশ|অ্যাকাউন্ট|একাউন্ট)');
  if (!hasAcct) return null;
  if (asking) {
    if (_thas(f, r'(?:সব|সকল|মোট)\s+(?:অ্যাকাউন্ট|একাউন্ট|হিসাব)') || _thas(f, r'(?:অ্যাকাউন্ট|একাউন্ট)\S*\s+(?:মোট|সব)')) return MenuAction(said, domain: 'accounts', op: 'balance');
    // "বিকাশে কত টাকা আছে" is answered by the money question rules (ask.dart).
    final one = _accountIn(said, d);
    if (one != null && !_thas(f, r'(?<=\s)আছে(?=\s)') && _thas(f, r'(?:কত|ব্যালেন্স|টাকা\s+(?:বলো|দেখাও|বলুন|দেখান))')) return MenuAction(said, domain: 'accounts', op: 'balance', target: one.name);
    return null;
  }
  if (_thas(f, r'(?<=\s)\S+\s+(?:টাকা|ব্যালেন্স)\s+(?:কত\s+)?(?:বলো|দেখাও|বলুন|দেখান)\s*$')) {
    final one = _accountIn(said, d);
    if (one != null) return MenuAction(said, domain: 'accounts', op: 'balance', target: one.name);
  }
  if (amount == null || negated) return null;
  // "নগদ থেকে বিকাশে এক হাজার সরালাম": a move between own accounts.
  final from = _tre(r'(?<=\s)(\S+(?:\s+\S+)?)\s+থেকে(?=\s)').firstMatch(f);
  final fee = _tre(r'(?:চার্জ|ফি|খরচ\s+কেটেছে|কাটল|কেটেছে)').hasMatch(f);
  if (from != null && fee && a != Aspect.future && a != Aspect.duty) {
    final src = _accountIn(from[1]!, d);
    final rest0 = f.substring(from.end);
    // "ব্যাংক থেকে দুই হাজার তুলে পাঁচশ বাজারে খরচ করেছি" is handled below; a
    // fee alone is spending from that account.
    if (src != null && _accountIn(rest0, d) == null && !_thas(rest0, r'(?:তুলে|তুলেছি|সরালাম|পাঠালাম)')) return MenuAction(said, domain: 'accounts', op: 'fee', target: src.name, amount: amount);
  }
  // "ব্যাংক থেকে দুই হাজার তুলে পাঁচশ বাজারে খরচ করেছি": a withdrawal, then
  // spending from the cash — two records, never income.
  final ws = _tre(r'^\s*(\S+)\s+থেকে\s+(.+?)\s+(?:তুলে|উঠিয়ে|ক্যাশ\s+আউট\s+করে)\s+(.+?)\s+(\S+?)(?:ে|এ|য়|তে)?\s+খরচ\s+(?:করেছি|করলাম|হয়েছে)').firstMatch(f);
  if (ws != null && a == Aspect.done) {
    final src = _accountIn(ws[1]!, d);
    final out1 = findAmount(normalize(ws[2]!)), spent = findAmount(normalize(ws[3]!));
    if (src != null && out1 != null && spent != null) return MenuAction(said, domain: 'accounts', op: 'withdraw_spend', target: src.name, target2: 'নগদ', amount: out1, amount2: spent, text: ws[4]!);
  }
  if (from != null && a == Aspect.done) {
    final src = _accountIn(from[1]!, d);
    final restPart = f.substring(from.end);
    final dst = _accountIn(restPart, d);
    if (src != null && (dst != null || _thas(f, r'(?:তুলেছি|তুললাম|উঠিয়েছি|উঠালাম|ক্যাশ\s+আউট|cash\s+out)'))) {
      final to = dst?.name ?? 'নগদ';
      final amounts = [for (final m in _tre(r'(?<=\s)(\S+(?:\s+(?:হাজার|শ|শো|লাখ))?)(?=\s)').allMatches(restPart)) findAmount(normalize(m[1]!))].whereType<int>().toList();
      final feeAmount = fee && amounts.length >= 2 ? amounts.last : 0;
      return MenuAction(said, domain: 'accounts', op: 'transfer', target: src.name, target2: to, amount: amounts.isEmpty ? amount : amounts.first, amount2: feeAmount);
    }
    // "ব্যাংক থেকে পাঠাতে চার্জ বিশ টাকা গেছে": only the fee, as spending
    // from that account.
    if (src != null && fee) return MenuAction(said, domain: 'accounts', op: 'fee', target: src.name, amount: amount);
  }
  // "হাতে নগদ দুই হাজার আছে": a balance as it stands — never income.
  if (_thas(f, r'(?<=\s)(?:আছে|রয়েছে|আছেন)\s*$')) {
    final one = _accountIn(said, d);
    if (one != null) return MenuAction(said, domain: 'accounts', op: 'set_balance', target: one.name, amount: amount);
  }
  // "বিকাশে তিন হাজার রাখো": a balance, or money moved in? Asked.
  if (_thas(f, r'(?:রাখো|রাখ|রেখে\s+দাও)\s*$')) {
    final one = _accountIn(said, d);
    if (one != null) return MenuAction(said, domain: 'accounts', op: 'put_unclear', target: one.name, amount: amount);
  }
  return null;
}

Command? _medicines(String said, String f, AppData? d, DateTime now, int? amount, bool asking, bool negated) {
  final named = d == null ? null : [for (final m in d.medicines) if (_stemSaid(f, m.name)) m.name].firstOrNull;
  final medWord = _thas(f, r'(?:ওষুধ|ঔষধ|অষুধ|ট্যাবলেট|বড়ি|ক্যাপসুল|ডোজ)');
  if (named == null && !medWord) return null;
  final part = _thas(f, r'(?:সকাল|ভোর)') ? 'সকাল' : _thas(f, r'দুপুর') ? 'দুপুর' : _thas(f, r'(?:বিকেল|বিকাল)') ? 'বিকেল' : _thas(f, r'সন্ধ্যা') ? 'সন্ধ্যা' : _thas(f, r'রাত') ? 'রাত' : '';
  final day = _thas(f, r'(?:গতকাল|গত\s+কাল)') ? dayOnly(now.subtract(const Duration(days: 1))) : dayOnly(now);
  if (named != null && _thas(f, r'(?:রিমাইন্ডার|reminder|মনে\s+করানো)') && _thas(f, r'(?:বন্ধ|অফ|off)')) return MenuAction(said, domain: 'medicine', op: 'reminder_off', target: named);
  if (asking) {
    if (_thas(f, r'(?:কতদিনের|কয়দিনের|কত\s+দিন|কয়\s+দিন|কতগুলো|কয়টা)\s') || _thas(f, r'(?:স্টক|বাকি\s+আছে)')) return MenuAction(said, domain: 'medicine', op: 'stock_query', target: named ?? '');
    return null;
  }
  if (_thas(f, r'ভুল\s+করে') && _thas(f, r'(?:টিক|খেয়েছি)')) return MenuAction(said, domain: 'medicine', op: 'dose_undo', target: named ?? '', day: day, part: part);
  if (negated && _thas(f, r'(?:খাইনি|খাই\s+নি|খাওয়া\s+হয়নি|খাওয়া\s+হয়নি|খাইনাই)')) return MenuAction(said, domain: 'medicine', op: 'dose_not', target: named ?? '', day: day, part: part);
  final count = RegExp(r'(\d+)').firstMatch(normalize(spokenNumbers(said)));
  if (_thas(f, r'(?:এনেছি|আনলাম|কিনেছি|কিনলাম|এনে\s+রেখেছি)') && count != null && named != null) {
    return MenuAction(said, domain: 'medicine', op: 'stock_add', target: named, amount: int.parse(count[1]!));
  }
  if (_thas(f, r'(?:খেয়েছি|খেলাম|খাইছি|খাইসি|খাইলাম|খাইলাম|খাওয়া\s+হয়েছে|খাওয়া\s+হয়েছে|খাওয়া\s+শেষ|খেয়ে\s+নিয়েছি|খাওয়া\s+হইছে)')) return MenuAction(said, domain: 'medicine', op: 'dose', target: named ?? '', day: day, part: part);
  return null;
}

Command? _habits(String said, String f, AppData? d, DateTime now, bool asking, bool negated) {
  if (_thas(f, r'(?<=\s)অভ্যাস') && _thas(f, r'(?:রাখো|যোগ\s+করো|শুরু\s+করো|বানাও|চালু\s+করো|লিখে\s+রাখো)') && !asking) {
    var name = f.substring(0, f.indexOf(fold('অভ্যাস'))).trim();
    name = name.replaceAll(_tre(r'^(?:প্রতিদিন|রোজ|প্রত্যেকদিন|দৈনিক|একটা|একটি|নতুন)\s+'), '').replaceAll(_tre(r'(?:ার|ের|এর|র)$'), 'া').trim();
    if (name.isNotEmpty) return MenuAction(said, domain: 'habit', op: 'add', target: name);
  }
  if (d == null || d.habits.isEmpty) return null;
  final habit = [for (final h in d.habits) if (_stemSaid(f, h.name)) h.name].firstOrNull;
  if (habit == null) return null;
  final day = _thas(f, r'(?:গতকাল|গত\s+কাল)') ? dayOnly(now.subtract(const Duration(days: 1))) : (_thas(f, r'(?<=\s)পরশু(?=\s)') ? dayOnly(now.subtract(const Duration(days: 2))) : dayOnly(now));
  if (_thas(f, r'(?:রিমাইন্ডার|reminder|মনে\s+করানো)') && _thas(f, r'(?:বন্ধ|অফ|off)')) return MenuAction(said, domain: 'habit', op: 'reminder_off', target: habit);
  // "হাঁটার রিমাইন্ডার সন্ধ্যা ৬টায় দাও": a daily reminder for the habit.
  if (_thas(f, r'(?:রিমাইন্ডার|reminder|মনে\s+করিও|মনে\s+করিয়ে\s+দিও)') && saysClock(said)) {
    final w = parseWhen(said, now);
    if (w != null && w.hasTime) return MenuAction(said, domain: 'habit', op: 'reminder_set', target: habit, time: w.at.hour * 60 + w.at.minute, part: hourOpen(said, w.at.hour) ? '?' : '');
  }
  if (asking) {
    if (_thas(f, r'(?:টানা|পরপর|একটানা)') || _thas(f, r'(?:কয়দিন|কত\s+দিন|কতদিন)')) return MenuAction(said, domain: 'habit', op: 'streak', target: habit);
    return null;
  }
  // "গতকাল করেছি, টিক দিইনি": done that day (the "not ticked" is about the box).
  if (_thas(f, r'(?:করেছি|হয়েছে|হয়েছে|হেঁটেছি|পড়েছি|টিক\s+দাও|টিক\s+দিন|হয়ে\s+গেছে|সেরেছি|পড়লাম|হাঁটলাম|করলাম)')) {
    return MenuAction(said, domain: 'habit', op: 'tick', target: habit, day: day, text: _thas(f, r'(?:মনে\s+করিও|রিমাইন্ডার)') ? 'remind' : '');
  }
  if (negated || _thas(f, r'(?:হয়নি|হয়নি|করিনি|হাঁটিনি|পড়িনি)')) return MenuAction(said, domain: 'habit', op: 'not_done', target: habit, day: day);
  return null;
}

Command? _business(String said, String f, AppData? d, DateTime now, int? amount, bool asking, bool negated, Aspect a) {
  // Projects (অন্যান্য হিসাব).
  final create = _tre(r'^\s*(.+?)\s+নামে\s+(?:একটা\s+|নতুন\s+)?(?:প্রজেক্ট|প্রকল্প|হিসাব)\s+(?:খোলো|খুলুন|খুলে\s+দাও|বানাও|শুরু\s+করো)').firstMatch(f);
  if (create != null) return MenuAction(said, domain: 'project', op: 'create', target: create[1]!.trim());
  // The page itself named: "অন্যান্য হিসাব", "আলাদা হিসাব", "প্রজেক্ট".
  final placeWord = _thas(f, r'(?:অন্যান্য\s+হিস(?:া|ে)ব|আলাদা\s+হিস(?:া|ে)ব|প্রজেক্ট|প্রকল্প|project)');
  // "মৃত্তিকা ফাউন্ডেশন নামে অন্যান্য হিসাবে একটা বিভাগ লেখ": a new one,
  // whichever order the words come in.
  final named = _tre(r'^\s*(.+?)\s+নামে\s+(.+)$').firstMatch(f);
  if (named != null && placeWord && _thas(' ${named[2]} ', r'(?<=\s)(?:খোলো|খোল|খুলুন|খুলে\s+দাও|বানাও|বানিয়ে\s+দাও|শুরু\s+করো|লেখ|লেখো|লিখো|লিখে\s+রাখো|যোগ\s+করো|যুক্ত\s+করো|তৈরি\s+করো|রাখো|করো|কর)(?=\s|$)')) {
    final name = named[1]!.replaceAll(_tre(r'^\s*(?:(?:অন্যান্য|আলাদা)\s+হিসাব\S*|প্রজেক্ট\S*|প্রকল্প\S*)\s+'), '').trim();
    if (name.isNotEmpty && words(name).length <= 5) return MenuAction(said, domain: 'project', op: 'create', target: _origWords(said, name));
  }
  final proj = d == null ? null : _named(f, [for (final p in d.projects) if (!p.closed) p.name]);
  // "অন্যান্য হিসাব দাও", "অন্যান্য হিসাবের সারাংশ": all of them at a glance.
  final bare = words(f.trim()).length <= 3 && _thas(f, r'^\s*(?:আমার\s+)?(?:অন্যান্য|আলাদা)\s+হিসাব\S*\s*$');
  // (Not "রহিম ভবন প্রজেক্টে কত আছে?": a name before it is that account.)
  final unnamed = _thas(f, r'^\s*(?:আমার\s+|আমাদের\s+|সব\s+|সকল\s+)?(?:অন্যান্য\s+হিসাব|আলাদা\s+হিসাব|প্রজেক্ট|প্রকল্প|project)');
  if (placeWord && unnamed && proj == null && amount == null && !negated && (bare || asking || _thas(f, r'(?:দেখাও|দেখান|দাও|দিন|বলো|বলুন|সারাংশ|সামারি|summary)\s*$') || _thas(f, r'(?:সারাংশ|সামারি)'))) {
    return CashQuery(said, project: '');
  }
  // "নিহান ২০০০ টাকা বেতন দিয়েছে, এটা অন্যান্য হিসাবের ভেতরে শিক্ষার্থীদের
  // বেতনে যুক্ত কর": money into that account (who gave it is the note).
  var into = proj ?? (placeWord ? _tre(r'(?:অন্যান্য|আলাদা)\s+হিস(?:া|ে)ব\S*\s+(?:ভেতরে|ভিতরে|মধ্যে|মাঝে)?\s*(.+?)(?:এ|তে|য়|ে)?\s+(?:যুক্ত|যোগ|লেখ|লিখ|রাখ|জমা|অ্যাড)').firstMatch(f)?.group(1)?.trim() : null);
  // "অন্যান্য হিসেবে যুক্ত কর, মিস্ত্রীর বিল ২৭০০ টাকা": no name said — the
  // chat asks which account (folder) it goes in, even when there is one.
  // ("রহিম ভবন প্রজেক্টে ৫০ হাজার এলো" names its account: not this.)
  final nameBefore = _tre(r'(\S+)\s+(?:প্রজেক্ট|প্রকল্প|project)').allMatches(f).any((m) => !const ['আমার', 'এই', 'ওই', 'সেই', 'কোন', 'কোনো', 'একটা', 'নতুন'].contains(m[1]));
  if ((into == null || into.isEmpty || words(into).any((w) => const ['যুক্ত', 'যোগ', 'লেখ', 'লিখ', 'রাখ', 'কর', 'করো'].contains(w))) && placeWord && !nameBefore && amount != null && !negated && !asking) {
    final spentHere = !_thas(f, r'(?:এসেছে|এলো|পেয়েছি|পেলাম|দিয়েছে|জমা|আয়|চাঁদা|অনুদান)');
    final what = _thas(f, r'(?<=\s)বিল') ? 'বিল' : (spentHere ? 'অন্যান্য' : 'আয়');
    return CashAdd(said, kind: spentHere ? CashKind.expense : CashKind.income, amount: amount, category: what, project: '');
  }
  if (into != null && into.isNotEmpty && amount != null && !negated && !asking) {
    final spent = _thas(f, r'(?:খরচ|কিনলাম|কিনেছি|দিলাম|দিয়েছি|পরিশোধ\s+করেছি|বিল)');
    final got = _thas(f, r'(?:দিয়েছে|দিয়েছে|দিল|দিলো|এসেছে|এলো|পেয়েছি|পেলাম|জমা|বেতন|ফি|আয়|চাঁদা|অনুদান)');
    final adding = _thas(f, r'(?:যুক্ত\s+কর|যোগ\s+কর|লেখ|লিখে\s+রাখ|রাখো|অ্যাড|তোলো)');
    if ((spent || got) && (adding || proj != null)) {
      final category = _thas(f, r'(?<=\s)বেতন') ? 'বেতন' : (spent ? 'অন্যান্য' : 'আয়');
      return CashAdd(said, kind: spent && !got ? CashKind.expense : CashKind.income, amount: amount, category: category,
          project: proj ?? _origWords(said, into));
    }
  }
  if (_thas(f, r'(?:প্রজেক্ট|প্রকল্প)\S*\s.*(?:শেষ|বন্ধ\s+করো|আর্কাইভ)') && !asking) return MenuAction(said, domain: 'project', op: 'close', target: proj ?? '');
  if (_thas(f, r'(?<=\s)বাজেট(?=\s)') && amount != null && !asking) return MenuAction(said, domain: 'project', op: 'budget', target: proj ?? '', amount: amount);
  if (proj != null) {
    if (asking && _thas(f, r'(?:খরচ|আয়|এসেছে|হিসাব)')) return CashQuery(said, project: proj);
    if (!negated && amount != null && a == Aspect.done && _thas(f, r'(?:এসেছে|এলো|পেয়েছি|পেলাম|জমা\s+হয়েছে|পেয়েছে)')) {
      return CashAdd(said, kind: CashKind.income, amount: amount, category: 'আয়', project: proj);
    }
  }
  // The shop.
  final shopWord = _thas(f, r'(?:দোকান|দোকানে|দোকানের|শপ)');
  final shop = d == null ? null : _named(f, [for (final s in d.shops) s.name]);
  if (asking && _thas(f, r'(?<=\s)লাভ(?=\s)')) return MenuAction(said, domain: 'shop', op: 'profit');
  final calc = _tre(r'(?<=\s)(\S+)(?:টা|টি)?\s+(\S+)\s+(\S+)\s+টাকা\s+করে(?=\s)').firstMatch(_np(said));
  if (calc != null) {
    final q = int.tryParse(normalize(spokenNumbers(calc[1]!.replaceAll(RegExp(fold(r'(?:টা|টি)$')), ''))));
    final u = findAmount(normalize(calc[3]!));
    if (q != null && u != null) return MenuAction(said, domain: 'shop', op: 'calc', amount: q, amount2: u, text: calc[2]!);
  }
  if ((shopWord || shop != null) && asking == false && _thas(f, r'(?:আজকের|আজ)\s.*হিসাব')) return MenuAction(said, domain: 'shop', op: 'today', target: shop ?? '');
  if ((shopWord || shop != null) && _thas(f, r'হিসাব') && _thas(f, r'(?:আজকের|আজ)')) return MenuAction(said, domain: 'shop', op: 'today', target: shop ?? '');
  if (!negated && amount != null && a == Aspect.done && (shopWord || shop != null) && _thas(f, r'বিক্রি')) {
    return MenuAction(said, domain: 'shop', op: 'sale', target: shop ?? '', amount: amount);
  }
  // "করিম দুই হাজার টাকার মাল নিল, হাজার দিয়েছে": one sale — paid now,
  // the rest owed.
  final credit = _tre(r'^\s*(\S+)\s+(.+?)\s+টাকার\s+(?:মাল|জিনিস|পণ্য)\s+(?:নিল|নিলো|নিয়েছে|নিয়ে\s+গেল)[,\s]+(.+?)\s+(?:দিয়েছে|দিল|দিলো|দিয়ে\s+গেছে)').firstMatch(f);
  if (credit != null) {
    final total = findAmount(normalize(credit[2]!));
    final paidWords = credit[3]!.replaceAll(RegExp(fold(r'^(?:নগদ|ক্যাশ)\s+')), '').trim();
    final paid = findAmount(normalize(paidWords)) ?? findAmount(normalize('এক $paidWords'));
    if (total != null && paid != null && paid <= total) return MenuAction(said, domain: 'shop', op: 'credit_sale', target: credit[1]!.replaceAll(RegExp(fold(r'(?:কে|রে)$')), ''), amount: total, amount2: paid);
  }
  final credit2 = _tre(r'^\s*(\S+?)(?:ের|এর|র)\s+(.+?)(?:ের|এর|র)?\s+বিক্রি(?:তে|র)?\s+(.+?)\s+(?:পেয়েছি|পেলাম|দিয়েছে|দিল)\s+(.+?)\s+বাকি').firstMatch(f);
  if (credit2 != null) {
    final total = findAmount(normalize(credit2[2]!)), paid = findAmount(normalize(credit2[3]!)), due = findAmount(normalize(credit2[4]!));
    if (total != null && paid != null && (due == null || paid + due == total)) return MenuAction(said, domain: 'shop', op: 'credit_sale', target: credit2[1]!, amount: total, amount2: paid);
  }
  // "করিম আগের বাকি থেকে পাঁচশ দিয়েছে": collecting what was owed — the
  // book, never a second sale.
  final collect = _tre(r'^\s*(\S+)\s+(?:আগের\s+)?(?:বাকি|পাওনা)\s+(?:থেকে|থিকা)\s+(.+?)\s+(?:দিয়েছে|দিল|দিলো|দিয়ে\s+গেছে|শোধ\s+করেছে)').firstMatch(f);
  if (collect != null) {
    final x = findAmount(normalize(collect[2]!));
    if (x != null) return LedgerAdd(said, person: collect[1]!, amount: x, kind: LedgerKind.received);
  }
  return null;
}

String _np(String s) => ' ${normalize(s)} ';

/// [norm] (normalized words of [said]) as the user wrote them, so a name
/// keeps its own spelling and case.
String _origWords(String said, String norm) {
  final want = words(normalize(norm));
  final have = said.split(RegExp(r'\s+'));
  for (var i = 0; i + want.length <= have.length; i++) {
    final cut = have.sublist(i, i + want.length);
    if (words(normalize(cut.join(' '))).join(' ') == want.join(' ')) return cut.join(' ').replaceAll(RegExp(r'[,।:;!?]+$'), '');
  }
  return norm;
}

Command? _cashQuestion(String said, String f, AppData? d, DateTime now, bool asking) {
  if (!asking && !_thas(f, r'(?:দেখাও|দেখান|বলো|বলুন|দাও|দিন)\s*$')) return null;
  // "বেতনের আয় ৫০০০ টাকা লিখে দাও" keeps money; it does not ask.
  if (!asking && (findAmount(normalize(withoutWhen(said))) != null || _thas(f, r'(?:লিখে|লেখো|রাখো|যোগ|যুক্ত)'))) return null;
  final spend = _thas(f, r'(?:খরচ|ব্যয়|ব্যয়)');
  final income = _thas(f, r'(?:আয়|আয়|ইনকাম|উপার্জন)');
  if (!spend && !income) return null;
  if (_thas(f, r'(?:লেনদেন|ধার|পাওনা|দেনা)')) return null;
  final today = dayOnly(now);
  DateTime? from, to;
  var label = '';
  if (_thas(f, r'(?<=\s)(?:আজ|আজকে|আজকের)(?=\s)')) {
    (from, to, label) = (today, today.add(const Duration(days: 1)), 'আজ');
  } else if (_thas(f, r'(?:গতকাল|গত\s+কাল)')) {
    (from, to, label) = (today.subtract(const Duration(days: 1)), today, 'গতকাল');
  } else if (_thas(f, r'এই\s+সপ্তাহ')) {
    (from, to, label) = (weekStartOf(today), weekStartOf(today).add(const Duration(days: 7)), 'এই সপ্তাহে');
  } else if (_thas(f, r'গত\s+সপ্তাহ')) {
    (from, to, label) = (weekStartOf(today).subtract(const Duration(days: 7)), weekStartOf(today), 'গত সপ্তাহে');
  } else if (_thas(f, r'গত\s+মাস')) {
    (from, to, label) = (DateTime(now.year, now.month - 1), DateTime(now.year, now.month), 'গত মাসে');
  } else if (_thas(f, r'(?:এই|এ)\s+মাস')) {
    (from, to, label) = (DateTime(now.year, now.month), DateTime(now.year, now.month + 1), 'এই মাসে');
  } else if (_thas(f, r'(?:এই|এ)\s+বছর')) {
    (from, to, label) = (DateTime(now.year), DateTime(now.year + 1), 'এই বছর');
  }
  final net = spend && income && _thas(f, r'(?:বাদে|বাদ\s+দিয়ে|থাকে|থাকল|বাকি)');
  // "আয়ের হিসাব দাও": income alone, this month (spending alone keeps its own summary).
  final incomeOnly = income && !spend && !asking;
  if (from == null && !net && !incomeOnly) return null;
  from ??= DateTime(now.year, now.month);
  to ??= DateTime(now.year, now.month + 1);
  if (label.isEmpty) label = 'এই মাসে';
  // "এই মাসে কত খরচ হলো?": the month's summary (with its biggest খাত) as before.
  final thisMonth = from == DateTime(now.year, now.month) && to == DateTime(now.year, now.month + 1);
  // A খাত said ("চিকিৎসার খরচ").
  String cat = '';
  if (d != null) {
    final cats = {for (final c in d.cash) c.category};
    cat = _named(f, cats.where((c) => c != 'অন্যান্য')) ?? '';
  }
  if (thisMonth && cat.isEmpty && !net && !incomeOnly) return null;
  return MenuAction(said, domain: 'cash', op: net ? 'net' : (income && !spend ? 'income' : 'spend'), day: from, until: to, text: cat, target: label);
}

Command? _healthWords(String said, String f, AppData? d, DateTime now, bool negated) {
  final bp = _thas(f, r'(?:প্রেশার|প্রেসার|রক্তচাপ|বিপি|(?<=\s)bp(?=\s))');
  final sugar = _thas(f, r'(?:সুগার|ডায়াবেটিস|ডায়বেটিস|গ্লুকোজ|sugar)');
  final weight = _thas(f, r'(?<=\s)(?:ওজন)(?=\s)');
  final height = _thas(f, r'(?:উচ্চতা|লম্বা|হাইট)');
  final afterMeal = _thas(f, r'(?:খাওয়ার|খাবার|নাস্তার)\s+(?:\S+\s+){0,2}(?:পরে|পর|আগে)');
  final measure = _thas(f, r'(?:মাপ|মাপটা|রিডিং)');
  if (!bp && !sugar && !weight && !height && !afterMeal && !measure) return null;
  if (_thas(f, r'(?:মাপিনি|মাপা\s+হয়নি|মাপা\s+হয়নি|মাপি\s+নাই)')) return MenuAction(said, domain: 'health', op: 'none');
  final member = _memberIn(f, d);
  if (member == '?') return MenuAction(said, domain: 'health', op: 'unknown_member', target: _possessive(f) ?? '');
  // "আগের মাপটা ভুল, ১৩০ নয় ১২০": the last reading, corrected.
  final fix = _tre(r'(?:আগের|শেষ)\s+মাপ\S*\s.*?(\S+)\s+(?:নয়|না|নয়)\s+(\S+)').firstMatch(fold(spokenNumbers(said)));
  if (fix != null) {
    final wrong = double.tryParse(asciiDigits(fix[1]!)), right = double.tryParse(asciiDigits(fix[2]!));
    if (wrong != null && right != null) return MenuAction(said, domain: 'health', op: 'fix_last', amount: (wrong * 10).round(), amount2: (right * 10).round(), target: member);
  }
  // "গত সাত দিনের সুগার দেখাও", "শেষ প্রেশার কত": a question — never a reading.
  if (_thas(f, r'(?:দেখাও|দেখান|কত|কেমন|বলো|বলুন|গড়|গ্রাফ)') || isQuestionText(said)) {
    if (height) return null;
    final what = bp ? HealthKind.bp.name : sugar ? HealthKind.sugar.name : weight ? HealthKind.weight.name : null;
    return what == null ? null : HealthQuery(said, what: what, member: member);
  }
  final words2 = spokenNumbers(said);
  // "উচ্চতা পাঁচ ফুট ছয় ইঞ্চি": feet and inches — 167.6 cm, never 5.6 feet.
  final ftIn = RegExp(fold(r'(\d+)\s*(?:ফুট|ফিট|feet|ft)\s*(?:(\d+)\s*(?:ইঞ্চি|ইঞ্চ|inch|in))?')).firstMatch(fold(asciiDigits(words2)));
  if (height && ftIn != null) {
    if (words2 == fold(said)) return null; // digits already: the profile rule reads it
    final c = Parser(ledger: d?.ledger ?? const [], now: now, data: d)._parse(words2);
    return c is ProfileSet ? c : null;
  }
  // The rest are the existing reading rules, on the words written as digits;
  // a family member's reading is theirs.
  if (words2 == fold(said) && !afterMeal && member == 'me') return null;
  if (negated) return null;
  final p = Parser(ledger: d?.ledger ?? const [], now: now, data: d);
  final c = p._health(words2, normalize(words2), words(normalize(words2)));
  if (c is HealthAdd) return HealthAdd(said, kind: c.kind, a: c.a, b: c.b, c: c.c, tag: c.tag, member: member);
  // "খাওয়ার দুই ঘণ্টা পরে আট দশমিক দুই" with no সুগার said: asked — not a
  // reminder in two hours, not a guess.
  final nums = RegExp(r'\d+\.\d+').allMatches(asciiDigits(words2)).map((m) => double.parse(m[0]!)).toList();
  if (afterMeal && !sugar && nums.isNotEmpty && nums.last > 1 && nums.last < 35) {
    final v = nums.last;
    return Clarify(said,
        question: '${bnDigits(v.toString())} — এটা কি সুগারের মাপ (খাওয়ার পরে, mmol/L)?',
        options: [('হ্যাঁ, সুগার', HealthAdd(said, kind: HealthKind.sugar, a: v, tag: 'after', member: member)), ('না', SmallTalk(said, kind: Talk.cancelled))]);
  }
  return null;
}

/// "আম্মার", "রাফির": whose reading — a family member's id, 'me', or '?'
/// when a name was said that is not one of the family.
String _memberIn(String f, AppData? d) {
  if (_thas(f, r'(?<=\s)(?:আমার|নিজের)(?=\s)')) return 'me';
  final who = _possessive(f);
  if (who == null) return 'me';
  final m = d == null ? null : memberCalled(d, who);
  return m?.id ?? '?';
}

/// "আম্মার প্রেশার": the owner's word without its ending ("আম্মা"), or null.
String? _possessive(String f) {
  final m = _tre(r'^\s*(?:আজ\s+|গতকাল\s+)?(\S+?)(?:ের|এর|র)\s+(?:প্রেশার|প্রেসার|রক্তচাপ|বিপি|bp|সুগার|ডায়াবেটিস|গ্লুকোজ|ওজন|উচ্চতা|হাইট)').firstMatch(f);
  if (m == null) return null;
  final w = m[1]!;
  if (const ['আমা', 'নিজে', 'আজকে', 'আজকে'].map(fold).contains(w)) return null;
  // "আম্মার" → "আম্মা" (the -র belongs to a name ending in a vowel).
  return w;
}
