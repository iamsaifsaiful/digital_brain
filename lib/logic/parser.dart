/// Understands what the user said (or typed) in Bengali.
///
/// Version 1 works from sentence patterns, not AI: it recognises the usual
/// ways people say they gave, took, got back or paid back money, and the
/// usual ways of asking for a balance, a login, a date or a note. When the
/// meaning of a money sentence is not clear it never guesses: it returns the
/// choices so the app can ask.
library;

import '../models/models.dart';
import 'bn.dart';
import 'ledger.dart';

sealed class Command {
  const Command(this.transcript);
  final String transcript;
}

/// A money event to confirm. [kind] is null when the user must choose
/// between [options]; [suggested] is the likeliest one.
class LedgerAdd extends Command {
  const LedgerAdd(super.transcript,
      {required this.person, required this.amount, this.kind, this.options = const [], this.suggested, this.allowExpense = false});
  final String person;
  final int amount;
  final LedgerKind? kind;
  final List<LedgerKind> options;
  final LedgerKind? suggested;

  /// Offer "অন্য খরচ, হিসাবে রাখব না" as a choice too.
  final bool allowExpense;

  bool get needsChoice => kind == null;
}

/// "ইসমাইলের কাছে আমি ৫ হাজার টাকা পাই": the user states a balance.
/// [balance] > 0: they owe me; < 0: I owe them.
class LedgerSet extends Command {
  const LedgerSet(super.transcript, {required this.person, required this.balance});
  final String person;
  final int balance;
}

enum LedgerAsk { all, receivable, payable, person }

class LedgerQuery extends Command {
  const LedgerQuery(super.transcript, {required this.ask, this.person});
  final LedgerAsk ask;
  final String? person;
}

class VaultQuery extends Command {
  const VaultQuery(super.transcript, {required this.terms, this.wifiOnly = false});
  final List<String> terms;
  final bool wifiOnly;
}

class ReminderQuery extends Command {
  const ReminderQuery(super.transcript, {required this.terms});
  final List<String> terms;
}

/// Something to remember. [fromStatement]: the user just said a fact
/// ("ছাদের দরজার কোড ৪৫৬৭") that matched nothing else.
class NoteAdd extends Command {
  const NoteAdd(super.transcript, {required this.text, this.fromStatement = false});
  final String text;
  final bool fromStatement;
}

class SearchQuery extends Command {
  const SearchQuery(super.transcript, {required this.terms});
  final List<String> terms;
}

class NotUnderstood extends Command {
  const NotUnderstood(super.transcript);
}

// ───────────────────────── Text helpers ─────────────────────────

/// Writes য়, ড়, ঢ় one way (letter + nukta) and drops zero-width joiners,
/// since keyboards and speech engines spell them differently.
String fold(String s) => s
    .replaceAll('\u09DF', '\u09AF\u09BC')
    .replaceAll('\u09DC', '\u09A1\u09BC')
    .replaceAll('\u09DD', '\u09A2\u09BC')
    .replaceAll(RegExp('[\u200B-\u200D\uFEFF]'), '');

/// Lower-case, ASCII digits, no punctuation, single spaces.
String normalize(String s) {
  var t = fold(asciiDigits(s)).toLowerCase();
  t = t.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}${m[2]}');
  t = t.replaceAll(RegExp(r'[।?!,;:"“”‘’()\[\]]'), ' ');
  t = t.replaceAll('৳', ' ');
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

List<String> words(String normalized) => normalized.isEmpty ? const [] : normalized.split(' ');

const _vowelSigns = 'ািীুূৃেৈোৌ';

/// Removes a Bengali possessive ending: সজীবের → সজীব, রনির → রনি,
/// wi-fi-এর → wi-fi.
String stripPossessive(String w) {
  for (final suf in ['-এর', '-র', 'এর', 'ের']) {
    if (w.endsWith(suf) && w.length > suf.length + 1) return w.substring(0, w.length - suf.length);
  }
  if (w.endsWith('র') && w.length > 2 && _vowelSigns.contains(w[w.length - 2])) {
    return w.substring(0, w.length - 1);
  }
  return w;
}

/// Removes "কে" (to): সজীবকে → সজীব.
String stripTo(String w) {
  for (final suf in ['-কে', 'কে']) {
    if (w.endsWith(suf) && w.length > suf.length + 1) return w.substring(0, w.length - suf.length);
  }
  return w;
}

/// Ending a search word might carry: টা, টি, তে, গুলো, এর, কে.
String stem(String w) {
  var s = w;
  for (final suf in ['গুলো', 'টার', 'টা', 'টি', 'তে']) {
    if (s.endsWith(suf) && s.length > suf.length + 1) {
      s = s.substring(0, s.length - suf.length);
      break;
    }
  }
  return stripTo(stripPossessive(s));
}

const _numberWordsRaw = {
  'এক': 1, 'দুই': 2, 'দু': 2, 'তিন': 3, 'চার': 4, 'পাঁচ': 5, 'ছয়': 6, 'সাত': 7, 'আট': 8, 'দশ': 10, 'বিশ': 20, 'ত্রিশ': 30, 'চল্লিশ': 40, 'পঞ্চাশ': 50, 'একশ': 100, 'একশো': 100, 'দেড়': 1.5, 'আড়াই': 2.5,
};

final Map<String, num> _numberWords = {for (final e in _numberWordsRaw.entries) fold(e.key): e.value};

/// The amount in a sentence, in whole taka. Understands "৫০০", "১,০০০",
/// "২ হাজার", "দেড় হাজার", "পাঁচশো", "৩ লাখ".
int? findAmount(String normalized) {
  final w = words(normalized);
  for (var i = 0; i < w.length; i++) {
    num? base;
    final digits = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(w[i]);
    if (digits != null) {
      base = num.parse(digits[1]!);
      // "500টাকা" or "500/-": the number is still the amount.
    } else {
      base = _numberWords[w[i]];
      if (base == null) {
        // পাঁচশো / পাঁচশ / দুইশো
        final m = RegExp(r'^(.+?)(শো|শ|শত)$').firstMatch(w[i]);
        if (m != null && _numberWords[m[1]] != null) base = _numberWords[m[1]]! * 100;
      }
    }
    if (base == null) continue;
    final next = i + 1 < w.length ? w[i + 1] : '';
    final mult = switch (next) {
      'হাজার' => 1000,
      'লাখ' || 'লক্ষ' => 100000,
      'শো' || 'শ' || 'শত' => 100,
      _ => 1,
    };
    final v = (base * mult).round();
    if (v > 0) return v;
  }
  return null;
}

bool _hasAny(String text, List<String> keys) => keys.any((k) => text.contains(fold(k)));

const _give1 = ['দিলাম', 'দিয়েছি', 'দিছি', 'দিয়েছিলাম', 'দিচ্ছি'];
const _take1 = ['নিলাম', 'নিয়েছি', 'নিছি', 'নিয়েছিলাম'];
const _got1 = ['পেলাম', 'পেয়েছি', 'পাইছি', 'পেয়েছিলাম'];
const _give3 = ['দিল', 'দিলো', 'দিয়েছে', 'দিয়েছেন', 'দিলেন', 'দিছে', 'দিয়েছিল'];
const _loanWords = ['ধার', 'কর্জ', 'লোন', 'loan'];
const _returnWords = ['ফেরত', 'শোধ', 'পরিশোধ'];
final List<String> _honorifics = [for (final h in _honorificsRaw) fold(h)];
const _honorificsRaw = ['ভাই', 'ভাইয়া', 'ভাইয়া', 'আপা', 'আপু', 'চাচা', 'মামা', 'খালা', 'কাকা', 'দাদা', 'স্যার', 'সাহেব', 'বোন'];
final Set<String> _notNames = {for (final w in _notNamesRaw) fold(w)};
const _notNamesRaw = {
  'আমি', 'আমাকে', 'আমার', 'আজ', 'আজকে', 'গতকাল', 'কাল', 'এইমাত্র', 'এখন', 'টাকা', 'তাকে', 'ওকে', 'উনাকে', 'তাঁকে',
  'আরো', 'আরও', 'মোট', 'আবার', 'কাছ', 'কাছে', 'থেকে', 'ধার', 'ফেরত', 'শোধ',
};

bool _looksLikeName(String w) => w.isNotEmpty && !_notNames.contains(w) && !RegExp(r'^\d').hasMatch(w) && findAmount(w) == null;

/// Matches [raw] to a known person (case-insensitive, also trying the
/// possessive/"to" endings), or returns it cleaned up.
String resolvePerson(String raw, List<String> known) {
  final cands = {raw, stripPossessive(raw), stripTo(raw), stripTo(stripPossessive(raw))};
  for (final c in cands) {
    for (final k in known) {
      if (personKey(k) == personKey(c)) return k;
    }
  }
  return raw;
}

/// The name right before position [i] (and an honorific with it).
String? _nameEndingAt(List<String> w, int i, String Function(String) strip) {
  if (i < 0 || i >= w.length) return null;
  final head = strip(w[i]);
  if (!_looksLikeName(head)) return null;
  if (_honorifics.contains(head) && i > 0 && _looksLikeName(w[i - 1])) return '${w[i - 1]} $head';
  return head;
}

// ───────────────────────── The parser ─────────────────────────

class Parser {
  Parser({required this.ledger});

  /// Current entries, to resolve names and judge which meaning is likely.
  final List<LedgerEntry> ledger;

  Command parse(String said) {
    final text = normalize(said);
    if (text.isEmpty) return NotUnderstood(said);
    final w = words(text);

    // "মনে রাখো: …" → a note.
    final noteMatch = RegExp(r'^(মনে রাখো|মনে রেখো|মনে রাখ|নোট রাখো|নোট করো|নোট কর|লিখে রাখো|লিখে রাখ)\s*(যে)?\s*(.*)$').firstMatch(text);
    if (noteMatch != null && (noteMatch[3] ?? '').trim().isNotEmpty) {
      // Keep the user's own spelling and digits.
      final original = said.trim().replaceFirst(RegExp(r'^\S+\s+\S+\s*[:ঃ,-]?\s*(যে\s+)?'), '');
      return NoteAdd(said, text: original.isEmpty ? noteMatch[3]!.trim() : original);
    }

    final amount = findAmount(text);
    final known = knownPeople(ledger);
    final asking = isQuestionText(said);

    // "ইসমাইলের কাছে আমি ৫ হাজার টাকা পাই" — a stated balance.
    if (amount != null && !asking) {
      final set = _statedBalance(said, text, w, amount, known);
      if (set != null) return set;
    }

    // A question about money.
    final isQuestion = _hasAny(text, ['কত', 'কাকে', 'কার কাছে', 'কে কে', 'হিসাব', 'কবে']) &&
        _hasAny(text, ['পাওনা', 'পাব', 'পাবো', 'পাবে', 'পাই', 'দেনা', 'দিতে হবে', 'দেব', 'দেবো', 'বাকি', 'ধার', 'হিসাব', 'লেনদেন']);
    if (isQuestion) return _ledgerQuestion(said, text, w, known);

    // Vault: logins, passwords, Wi-Fi.
    final wifi = _hasAny(text, ['wi-fi', 'wifi', 'ওয়াইফাই', 'ওয়াইফাই', 'ওয়াই-ফাই', 'ওয়াই ফাই']);
    if (wifi || _hasAny(text, _vaultWords)) {
      return VaultQuery(said, terms: wifi ? const [] : searchTerms(text), wifiOnly: wifi);
    }

    // Dates and reminders.
    if (_hasAny(text, ['মনে করিয়ে', 'মনে করিয়ে', 'মনে করাও', 'রিমাইন্ডার', 'তারিখ', 'কবে', 'মেয়াদ', 'মেয়াদ'])) {
      return ReminderQuery(said, terms: searchTerms(text));
    }

    // A money event.
    if (amount != null) {
      final add = _ledgerEvent(said, text, w, amount, known);
      if (add != null) return add;
    }

    final terms = searchTerms(text);
    if (terms.isEmpty) return NotUnderstood(said);
    // A plain fact, not a question: keep it (in a matching or new category).
    if (!asking && w.length >= 3) return NoteAdd(said, text: said.trim(), fromStatement: true);
    return SearchQuery(said, terms: terms);
  }

  /// "X-এর কাছে আমি N টাকা পাই / আমার N টাকা পাওনা" → they owe me N.
  /// "X আমার কাছে N টাকা পায় / X-কে আমার N টাকা দিতে হবে / X-এর কাছে আমার
  /// N টাকা দেনা" → I owe them N.
  LedgerSet? _statedBalance(String said, String text, List<String> w, int amount, List<String> known) {
    final iOweWords = _hasAny(text, ['দেনা', 'ঋণ', 'দিতে হবে', 'দেব', 'দেবো', 'দিব', 'দিবো', 'দিতে বাকি']);
    final owedWords = _hasAny(text, ['পাই', 'পাব', 'পাবো', 'পাওনা', 'পাবে', 'পাবেন', 'পায়', 'পান']);
    if (!iOweWords && !owedWords) return null;
    final me = w.contains('আমি') || w.contains('আমার');
    if (!me) return null;

    // "X আমার কাছে N টাকা পায়/পাবে": X is owed by me.
    final amar = w.indexOf('আমার');
    if (amar > 0 && amar + 1 < w.length && w[amar + 1] == 'কাছে' && owedWords) {
      final raw = _nameEndingAt(w, amar - 1, (x) => x);
      if (raw != null) return LedgerSet(said, person: resolvePerson(raw, known), balance: -amount);
    }

    // "X-এর কাছে আমি/আমার …"
    for (var i = 0; i + 1 < w.length; i++) {
      if (w[i + 1] != 'কাছে' || w[i] == 'আমার') continue;
      final raw = _nameEndingAt(w, i, stripPossessive);
      if (raw == null) continue;
      final person = resolvePerson(raw, known);
      if (iOweWords && !_hasAny(text, ['পাই', 'পাব', 'পাবো'])) return LedgerSet(said, person: person, balance: -amount);
      if (owedWords) return LedgerSet(said, person: person, balance: amount);
    }

    // "X-কে আমার/আমি N টাকা দিতে হবে / দেব"
    if (iOweWords && !_hasAny(text, _give1)) {
      for (var i = 0; i < w.length; i++) {
        if (!w[i].endsWith('কে') || w[i] == 'আমাকে' || w[i] == 'কাকে') continue;
        final raw = _nameEndingAt(w, i, stripTo);
        if (raw != null) return LedgerSet(said, person: resolvePerson(raw, known), balance: -amount);
      }
    }
    return null;
  }

  LedgerAdd? _ledgerEvent(String said, String text, List<String> w, int amount, List<String> known) {
    final loan = _hasAny(text, _loanWords);
    final ret = _hasAny(text, _returnWords);

    // 1) "সজীব আমাকে ৩০০ টাকা ফেরত দিয়েছে" — they gave me.
    final ami = w.indexOf('আমাকে');
    if (ami > 0 && _hasAny(text, [..._give3, ..._give1])) {
      final raw = _nameEndingAt(w, ami - 1, (s) => s);
      if (raw != null) {
        final person = resolvePerson(raw, known);
        if (ret) return LedgerAdd(said, person: person, amount: amount, kind: LedgerKind.received);
        if (loan) return LedgerAdd(said, person: person, amount: amount, kind: LedgerKind.borrowed);
        final owesMe = balanceWith(ledger, person) > 0;
        return LedgerAdd(said,
            person: person,
            amount: amount,
            options: const [LedgerKind.received, LedgerKind.borrowed],
            suggested: owesMe ? LedgerKind.received : LedgerKind.borrowed);
      }
    }

    // 2) "রহিমের কাছ থেকে ১,০০০ টাকা ধার নিয়েছি" — I took / got from them.
    var from = -1;
    for (var i = 0; i < w.length; i++) {
      if (w[i] == 'থেকে' || w[i] == 'হতে') {
        from = i;
        break;
      }
    }
    if (from > 0 && _hasAny(text, [..._take1, ..._got1])) {
      var at = from - 1;
      if (w[at] == 'কাছ' || w[at] == 'কাছে') at--;
      final raw = _nameEndingAt(w, at, stripPossessive);
      if (raw != null) {
        final person = resolvePerson(raw, known);
        final got = _hasAny(text, _got1);
        if (loan) return LedgerAdd(said, person: person, amount: amount, kind: LedgerKind.borrowed);
        if (ret) return LedgerAdd(said, person: person, amount: amount, kind: LedgerKind.received);
        final owesMe = balanceWith(ledger, person) > 0;
        if (!owesMe) {
          // Taking money from someone who owes me nothing is a loan.
          return LedgerAdd(said, person: person, amount: amount, kind: LedgerKind.borrowed);
        }
        return LedgerAdd(said,
            person: person,
            amount: amount,
            options: const [LedgerKind.received, LedgerKind.borrowed],
            suggested: got ? LedgerKind.received : LedgerKind.borrowed);
      }
    }

    // 3) "সজীবকে ৫০০ টাকা দিলাম" — I gave them.
    if (_hasAny(text, _give1) || _hasAny(text, ['দিলাম', 'দিয়েছি'])) {
      for (var i = 0; i < w.length; i++) {
        final t = w[i];
        if (t == 'আমাকে' || !(t.endsWith('কে'))) continue;
        final raw = _nameEndingAt(w, i, stripTo);
        if (raw == null) continue;
        final person = resolvePerson(raw, known);
        if (loan) return LedgerAdd(said, person: person, amount: amount, kind: LedgerKind.lent);
        if (ret) return LedgerAdd(said, person: person, amount: amount, kind: LedgerKind.repaid);
        final iOwe = balanceWith(ledger, person) < 0;
        if (iOwe) {
          return LedgerAdd(said,
              person: person,
              amount: amount,
              options: const [LedgerKind.repaid, LedgerKind.lent],
              suggested: LedgerKind.repaid,
              allowExpense: true);
        }
        return LedgerAdd(said, person: person, amount: amount, kind: LedgerKind.lent);
      }
    }

    // 4) A name and an amount, but no clear direction: ask.
    if (_hasAny(text, [..._give1, ..._give3, ..._take1, ..._got1, ..._loanWords, ..._returnWords, 'টাকা'])) {
      for (final k in known) {
        if (text.contains(normalize(k))) {
          return LedgerAdd(said, person: k, amount: amount, options: LedgerKind.values, allowExpense: true);
        }
      }
      // Someone new: "X-কে …", "X-এর কাছে/থেকে …", or a name first. Only
      // when a money verb is there ("বিদ্যুৎ বিল ১২০০ টাকা" is not a loan).
      if (!_hasAny(text, [..._give1, ..._give3, ..._take1, ..._got1, ..._loanWords, ..._returnWords])) return null;
      String? raw;
      for (var i = 0; i < w.length && raw == null; i++) {
        if (w[i].endsWith('কে') && w[i] != 'আমাকে' && w[i] != 'কাকে') raw = _nameEndingAt(w, i, stripTo);
        if (raw == null && i + 1 < w.length && (w[i + 1] == 'কাছে' || w[i + 1] == 'কাছ' || w[i + 1] == 'থেকে')) {
          raw = _nameEndingAt(w, i, stripPossessive);
        }
      }
      if (raw == null && (loan || ret) && w.isNotEmpty && _looksLikeName(w.first)) raw = w.first;
      if (raw != null && raw.length >= 2) {
        return LedgerAdd(said, person: raw, amount: amount, options: LedgerKind.values, allowExpense: true);
      }
    }
    return null;
  }

  LedgerQuery _ledgerQuestion(String said, String text, List<String> w, List<String> known) {
    // "সজীবের কাছে আমার কত পাওনা?" / "রহিমকে কত দিতে হবে?"
    for (var i = 0; i < w.length; i++) {
      String? raw;
      if (i + 1 < w.length && (w[i + 1] == 'কাছে' || w[i + 1] == 'সাথে' || w[i + 1] == 'সঙ্গে')) {
        raw = _nameEndingAt(w, i, stripPossessive);
      } else if (w[i].endsWith('কে') && w[i] != 'আমাকে' && w[i] != 'কাকে') {
        raw = _nameEndingAt(w, i, stripTo);
      } else if (w[i].endsWith('ের') || w[i].endsWith('এর')) {
        raw = _nameEndingAt(w, i, stripPossessive);
      }
      if (raw == null || raw == 'কার' || raw == 'কা') continue;
      final person = resolvePerson(raw, known);
      if (known.any((k) => personKey(k) == personKey(person))) {
        return LedgerQuery(said, ask: LedgerAsk.person, person: person);
      }
    }
    if (text.contains('কাকে') || _hasAny(text, ['দিতে হবে', 'দেনা', 'দেব', 'দেবো'])) {
      return LedgerQuery(said, ask: LedgerAsk.payable);
    }
    if (text.contains('কার কাছে') || _hasAny(text, ['পাব', 'পাবো', 'পাওনা'])) {
      return LedgerQuery(said, ask: LedgerAsk.receivable);
    }
    return LedgerQuery(said, ask: LedgerAsk.all);
  }
}

final Set<String> _stopWords = {for (final w in _stopWordsRaw) fold(w)};

const _stopWordsRaw = {
  'আমার', 'আমি', 'আমাকে', 'এর', 'কী', 'কি', 'কোন', 'কোনটা', 'দেখাও', 'দেখান', 'দেখা', 'বলো', 'বলুন', 'বল',
  'তথ্য', 'নাম', 'করার', 'করা', 'করে', 'তারিখ', 'মনে', 'করিয়ে', 'করাও', 'দাও', 'দিন', 'দেবে', 'দিও', 'কবে',
  'কত', 'লগইন', 'login', 'পাসওয়ার্ড', 'password', 'ইউজারনেম', 'username', 'রিমাইন্ডার', 'খুঁজে', 'খুঁজো',
  'খোঁজো', 'খুঁজুন', 'বের', 'আছে', 'ছিল', 'টা', 'টি', 'একটু', 'প্লিজ', 'please', 'show', 'the', 'my', 'of',
  'what', 'is', 'হবে', 'হয়', 'জন্য', 'আর', 'ও', 'যে', 'সেই', 'এই', 'ওই', 'নম্বর', 'নাম্বার', 'ওয়েবসাইট',
  'সাইট', 'অ্যাপ', 'অ্যাপের', 'মেয়াদ', 'শেষ', 'হওয়ার', 'দিনটা',
};

/// The words worth searching for in a sentence.
List<String> searchTerms(String normalized) {
  final out = <String>[];
  for (final raw in words(normalized)) {
    if (_stopWords.contains(raw)) continue;
    final s = stem(raw);
    if (s.length < 2 || _stopWords.contains(s)) continue;
    if (!out.contains(s)) out.add(s);
  }
  return out;
}

const _vaultWordsRaw = [
  'পাসওয়ার্ড', 'পাসওয়াড', 'পাসোয়ার্ড', 'পাসওর্ড', 'পাস ওয়ার্ড', 'password', 'pass', 'লগইন', 'লগ ইন', 'লগিন', 'login',
  'ইউজারনেম', 'ইউজার নেম', 'username', 'পিন নম্বর', 'পিন কোড', 'আইডি পাস', 'সাইন ইন',
];
final List<String> _vaultWords = [for (final v in _vaultWordsRaw) fold(v)];

/// Does the sentence ask something (rather than state a fact)?
bool isQuestionText(String said) {
  if (said.contains('?') || said.contains('？')) return true;
  final w = words(normalize(said));
  const q = [
    'কী', 'কি', 'কত', 'কোথায়', 'কোথায়', 'কবে', 'কে', 'কার', 'কাকে', 'কোন', 'কোনটা', 'কেমন', 'কিভাবে', 'কীভাবে',
    'দেখাও', 'দেখান', 'দেখা', 'বলো', 'বলুন', 'বল', 'খুঁজে', 'খোঁজো', 'খুঁজো', 'বের', 'what', 'where', 'when', 'show', 'find',
  ];
  final qs = {for (final x in q) fold(x)};
  return w.any(qs.contains);
}

const _yesRaw = [
  'হ্যাঁ', 'হ্যা', 'হাঁ', 'হা', 'জি', 'জ্বি', 'জী', 'হুম', 'হুঁ', 'ঠিক', 'আচ্ছা', 'অবশ্যই', 'নিশ্চয়ই', 'একদম', 'সঠিক',
  'করো', 'কর', 'করেন', 'করুন', 'রাখো', 'রাখ', 'রাখেন', 'রাখুন', 'সেভ', 'যোগ', 'দাও', 'দিন', 'চলবে', 'হবে', 'হ্যাঁ।',
  'ok', 'okay', 'ওকে', 'yes', 'yeah', 'yep', 'sure', 'save', 'right',
];
const _noRaw = ['না', 'নাহ', 'নো', 'no', 'nope', 'বাতিল', 'থাক', 'ভুল', 'cancel', 'নয়'];

final Set<String> _yes = {for (final x in _yesRaw) fold(x)};
final Set<String> _no = {for (final x in _noRaw) fold(x)};

/// A spoken answer: true for হ্যাঁ and its kin ("জি", "ঠিক আছে", "রাখো",
/// "ok"…), false for না/বাতিল/থাক/"দরকার নেই", null when unclear.
bool? yesNo(String said) {
  final t = normalize(said);
  if (t.isEmpty) return null;
  final w = words(t);
  if (w.any(_no.contains) || _hasAny(t, ['দরকার নেই', 'লাগবে না', 'রেখো না', 'রাখো না', 'করো না', 'চাই না'])) return false;
  if (w.any(_yes.contains) || _hasAny(t, ['ঠিক আছে', 'সেভ করো', 'যোগ করো'])) return true;
  return null;
}
