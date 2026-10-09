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
import 'when.dart';

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
  const NoteAdd(super.transcript, {required this.text, this.fromStatement = false, this.category});
  final String text;
  final bool fromStatement;

  /// Category suggested by the AI (else the app guesses).
  final String? category;
}

/// The AI's own answer (conversation or general knowledge).
class AiReply extends Command {
  const AiReply(super.transcript, {required this.text});
  final String text;
}

/// "কাল ব্যাংকে যেতে হবে" → a to-do.
class TaskAdd extends Command {
  const TaskAdd(super.transcript, {required this.title, this.due});
  final String title;
  final DateTime? due;
}

/// "ব্যাংকের কাজটা হয়ে গেছে" → tick the matching to-do.
class TaskDone extends Command {
  const TaskDone(super.transcript, {required this.terms});
  final List<String> terms;
}

/// "আজ কী কী কাজ আছে?"
class TaskQuery extends Command {
  const TaskQuery(super.transcript);
}

/// "কাল সকাল ১০টায় মিটিংয়ের কথা মনে করিয়ে দিও".
class ReminderAdd extends Command {
  const ReminderAdd(super.transcript, {required this.title, required this.at, this.repeat = Repeat.none});
  final String title;
  final DateTime at;
  final Repeat repeat;
}

/// "রহিমের নম্বর ০১৭১২৩৪৫৬৭৮ রাখো".
class ContactAdd extends Command {
  const ContactAdd(super.transcript, {required this.name, required this.phone});
  final String name;
  final String phone;
}

/// "রহিমকে ফোন দাও", "রহিমকে মেসেজ দাও যে আমি আসছি".
class CallPerson extends Command {
  const CallPerson(super.transcript, {required this.person, this.via = Via.call, this.text = '', this.phone = ''});
  final String person;
  final Via via;
  final String text;
  final String phone;
}

/// "আজ আমার কী কী আছে?" — today's to-dos, reminders and dues.
class Briefing extends Command {
  const Briefing(super.transcript);
}

class SearchQuery extends Command {
  const SearchQuery(super.transcript, {required this.terms});
  final List<String> terms;
}

class NotUnderstood extends Command {
  const NotUnderstood(super.transcript);
}

enum Talk { greeting, salam, howAreYou, imFine, whoAreYou, whatCanYouDo, thanks, bye, time, date }

/// Conversation, not data: "তুমি কেমন আছো?", "ধন্যবাদ", "আজ কত তারিখ?".
class SmallTalk extends Command {
  const SmallTalk(super.transcript, {required this.kind});
  final Talk kind;
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
  t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return t;
  // Everyday and regional speech → the standard forms the rules know.
  final mapped = t.split(' ').map(_standardWord).toList();
  return _joinParticles(mapped).join(' ');
}

const _englishKe = {'smoke', 'spoke', 'brake', 'stroke', 'awake', 'mistake', 'snake', 'shake', 'strike', 'handshake', 'remake', 'intake', 'stake'};

/// Speech engines and typists often split "সজীব কে", "sajib ke",
/// "abc er": glue the particle back to the name ("সজীবকে", "abcএর").
/// "টিয়া" after a number is Noakhali speech for টাকা.
List<String> _joinParticles(List<String> ws) {
  const keep = {'তুমি', 'আপনি', 'তুই', 'সে', 'উনি', 'ও', 'কে', 'এ', 'এটা', 'ওটা', 'আমি', 'আমার', 'কী', 'কি'};
  final out = <String>[];
  for (var i = 0; i < ws.length; i++) {
    final w = ws[i];
    final prev = out.isEmpty ? null : out.last;
    final prevIsNumber = prev != null && (RegExp(r'^\d').hasMatch(prev) || const {'হাজার', 'লাখ', 'লক্ষ', 'শ', 'শো', 'শত'}.contains(prev));
    if (w == fold('টিয়া') && prevIsNumber) {
      out.add('টাকা');
      continue;
    }
    if (prev != null && !keep.contains(prev) && !RegExp(r'^\d').hasMatch(prev)) {
      if (w == 'কে' || w == 'ke') {
        out[out.length - 1] = '$prevকে';
        continue;
      }
      if (w == 'এর' || w == 'er' || w == 'r') {
        out[out.length - 1] = '$prevএর';
        continue;
      }
    }
    // Banglish name endings before কাছে/থেকে/সাথে: "rahimer kache" → "rahimএর কাছে".
    final next = i + 1 < ws.length ? ws[i + 1] : '';
    if (RegExp(r'^[a-z]{3,}er$').hasMatch(w) && (next == 'কাছে' || next == 'থেকে' || next == 'সাথে')) {
      out.add('${w.substring(0, w.length - 2)}এর');
      continue;
    }
    if (RegExp(r'^[a-z]{3,}ke$').hasMatch(w) && !_colloquial.containsKey(w) && !_englishKe.contains(w)) {
      out.add('${w.substring(0, w.length - 2)}কে');
      continue;
    }
    out.add(w);
  }
  return out;
}

String _standardWord(String w) {
  final m = _colloquial[w];
  if (m != null) return m;
  // Dhaka "-রে" for "-কে": "সজীবরে" → "সজীবকে". Only after a name-like
  // stem (3+ letters, not ending in a vowel sign), so "করে", "পরে",
  // "বাজারে" stay as they are.
  if (w.endsWith('রে') && w.length >= 5) {
    final base = w.substring(0, w.length - 2);
    final last = base[base.length - 1];
    if (!'ািীুূৃেৈোৌ্'.contains(last) && !RegExp(r'[a-z0-9]').hasMatch(last)) return '$baseকে';
  }
  return w;
}

/// How people in Bangladesh actually say it (Dhaka speech, and common
/// Chattogram, Sylhet, Barishal, Noakhali, Mymensingh forms) → standard
/// Bengali. Word for word, so names are left alone.
const _colloquialRaw = <String, String>{
  // money
  'টেকা': 'টাকা', 'ট্যাকা': 'টাকা', 'টাহা': 'টাকা', 'টেহা': 'টাকা', 'ট্যাহা': 'টাকা',
  // me / my / I
  'আমারে': 'আমাকে', 'মোরে': 'আমাকে', 'আঁরে': 'আমাকে', 'আমারেও': 'আমাকে', 'মুই': 'আমি', 'আঁই': 'আমি',
  'মোর': 'আমার', 'আঁর': 'আমার', 'আমাগো': 'আমাদের',
  // gave (I)
  'দিসি': 'দিয়েছি', 'দিছি': 'দিয়েছি', 'দিছিলাম': 'দিয়েছিলাম', 'দিসিলাম': 'দিয়েছিলাম', 'দিলুম': 'দিলাম', 'দিলাম্': 'দিলাম',
  'দিয়া': 'দিয়ে', 'দিইছি': 'দিয়েছি', 'দিসিলাম্': 'দিয়েছিলাম', 'দিলাম্ম': 'দিলাম', 'দিচি': 'দিয়েছি', 'দিছিম': 'দিয়েছি',
  // gave (they)
  'দিসে': 'দিয়েছে', 'দিছে': 'দিয়েছে', 'দিসেন': 'দিয়েছেন', 'দিছেন': 'দিয়েছেন', 'দিছিল': 'দিয়েছিল', 'দিসিল': 'দিয়েছিল',
  'দিছে্': 'দিয়েছে', 'দিল্': 'দিল', 'দিসো': 'দিয়েছে', 'দিছো': 'দিয়েছে',
  // took / brought (a loan)
  'নিসি': 'নিয়েছি', 'নিছি': 'নিয়েছি', 'নিলুম': 'নিলাম', 'নিছিলাম': 'নিয়েছিলাম', 'নিসিলাম': 'নিয়েছিলাম', 'নিচি': 'নিয়েছি',
  'আনছি': 'নিয়েছি', 'আনসি': 'নিয়েছি', 'আনলাম': 'নিলাম', 'আনছিলাম': 'নিয়েছিলাম', 'করছি': 'করেছি', 'করসি': 'করেছি',
  // got
  'পাইছি': 'পেয়েছি', 'পাইসি': 'পেয়েছি', 'পাইলাম': 'পেলাম', 'পেলুম': 'পেলাম', 'পাইছিলাম': 'পেয়েছিলাম',
  // will get / will give / owed
  'পামু': 'পাব', 'পাইমু': 'পাব', 'পাইবো': 'পাব', 'পাইব': 'পাব', 'পাইতাম': 'পাব', 'দিমু': 'দেব', 'দিবাম': 'দেব', 'দিম': 'দেব',
  'লাগবো': 'লাগবে', 'লাগব': 'লাগবে', 'হইবো': 'হবে', 'হইব': 'হবে', 'অইবো': 'হবে', 'দেওন': 'দিতে', 'দেয়া': 'দিতে',
  // loan / return
  'হাওলাত': 'ধার', 'হাওলাদ': 'ধার', 'হাওলাতি': 'ধার', 'উধার': 'ধার', 'করজ': 'কর্জ', 'ফিরত': 'ফেরত', 'ফেরৎ': 'ফেরত', 'ফেরতে': 'ফেরত',
  'ফিরাইয়া': 'ফেরত', 'ফিরায়া': 'ফেরত', 'ফিরাইয়্যা': 'ফেরত',
  // from / near
  'থেইকা': 'থেকে', 'থাইকা': 'থেকে', 'থিকা': 'থেকে', 'থেকা': 'থেকে', 'তুন': 'থেকে', 'থুন': 'থেকে', 'থন': 'থেকে', 'তে্থে': 'থেকে',
  'ধারে': 'কাছে', 'কাছত': 'কাছে', 'কাছো': 'কাছে', 'কাসে': 'কাছে',
  // questions and asking
  'কতো': 'কত', 'কত্ত': 'কত', 'কিতা': 'কী', 'কিডা': 'কী', 'কিয়া': 'কী', 'কেরে': 'কেন', 'কই': 'কোথায়', 'কোনহানে': 'কোথায়',
  'কুনখানে': 'কোথায়', 'কোনখানে': 'কোথায়', 'কোন্ডে': 'কোথায়', 'কডে': 'কোথায়', 'কেডা': 'কে', 'কেঠা': 'কে', 'হেতে': 'সে',
  'কও': 'বলো', 'কন': 'বলো', 'কওতো': 'বলো', 'কইয়া': 'বলে', 'দেহাও': 'দেখাও', 'দেহান': 'দেখান', 'দেখাওতো': 'দেখাও',
  'ক্যামন': 'কেমন', 'কেমুন': 'কেমন', 'কিরাম': 'কেমন', 'কিমুন': 'কেমন', 'কেমনে': 'কীভাবে', 'ক্যামনে': 'কীভাবে',
  'কারে': 'কাকে', 'তারে': 'তাকে', 'ওরে': 'ওকে', 'হেরে': 'তাকে', 'আছস': 'আছিস', 'আছো্': 'আছো', 'আসো': 'আছো', 'আসেন': 'আছেন', 'আছুইন': 'আছেন', 'আছোনি': 'আছো', 'নাই': 'নেই', 'নাইক্কা': 'নেই',
  // Noakhali, Chattogram, Sylhet, Rajshahi, Barishal
  'টেয়া': 'টাকা', 'টেঁয়া': 'টাকা', 'ট্যায়া': 'টাকা', 'টিঁয়া': 'টাকা', 'হাইছি': 'পেয়েছি', 'হাইসি': 'পেয়েছি', 'হাইমু': 'পাব',
  'দিয়্যি': 'দিয়েছি', 'দিইয়ি': 'দিয়েছি', 'দিলাইছি': 'দিয়েছি', 'দিলাইসি': 'দিয়েছি', 'দিনু': 'দিলাম', 'লিনু': 'নিলাম',
  'লিছি': 'নিয়েছি', 'লিসি': 'নিয়েছি', 'পানু': 'পেলাম', 'গইজ্জি': 'করেছি', 'গরিলাম': 'করলাম', 'তুঁই': 'তুমি', 'মোগো': 'আমাদের',
  'আঁরা': 'আমরা', 'হিতে': 'সে', 'ইতা': 'এটা', 'হেইডা': 'সেটা', 'এইডা': 'এটা', 'কিচ্ছু': 'কিছু', 'কুনু': 'কোনো',
  // Banglish (Bengali typed or spoken in English letters) and English words
  'taka': 'টাকা', 'tk': 'টাকা', 'tak': 'টাকা', 'takar': 'টাকার', 'dilam': 'দিলাম', 'disi': 'দিয়েছি', 'dichi': 'দিয়েছি',
  'diyechi': 'দিয়েছি', 'dise': 'দিয়েছে', 'diche': 'দিয়েছে', 'diyeche': 'দিয়েছে', 'dilo': 'দিল', 'nilam': 'নিলাম', 'nisi': 'নিয়েছি',
  'nichi': 'নিয়েছি', 'niyechi': 'নিয়েছি', 'pelam': 'পেলাম', 'paisi': 'পেয়েছি', 'paichi': 'পেয়েছি', 'peyechi': 'পেয়েছি',
  'pabo': 'পাব', 'pamu': 'পাব', 'pai': 'পাই', 'pay': 'শোধ', 'paid': 'শোধ', 'payment': 'শোধ', 'debo': 'দেব', 'dibo': 'দেব', 'dimu': 'দেব',
  'ferot': 'ফেরত', 'ferat': 'ফেরত', 'return': 'ফেরত', 'back': 'ফেরত', 'dhar': 'ধার', 'loan': 'ধার', 'lend': 'ধার', 'lent': 'ধার',
  'borrow': 'ধার', 'borrowed': 'ধার', 'shodh': 'শোধ', 'kache': 'কাছে', 'kase': 'কাছে', 'theke': 'থেকে', 'theika': 'থেকে',
  'ami': 'আমি', 'amake': 'আমাকে', 'amare': 'আমাকে', 'amar': 'আমার', 'koto': 'কত', 'kato': 'কত', 'kar': 'কার', 'kake': 'কাকে',
  'kare': 'কাকে', 'mone': 'মনে', 'rakho': 'রাখো', 'rakhen': 'রাখেন', 'rakh': 'রাখ', 'kemon': 'কেমন', 'kemun': 'কেমন', 'acho': 'আছো',
  'aso': 'আছো', 'achen': 'আছেন', 'asen': 'আছেন', 'tumi': 'তুমি', 'apni': 'আপনি', 'ki': 'কী', 'kii': 'কী', 'koi': 'কোথায়',
  'dekhao': 'দেখাও', 'bolo': 'বলো', 'na': 'না', 'ha': 'হ্যাঁ', 'haa': 'হ্যাঁ', 'hae': 'হ্যাঁ', 'hmm': 'হুম', 'dhonnobad': 'ধন্যবাদ',
  'remind': 'মনে করাও', 'reminder': 'রিমাইন্ডার', 'note': 'নোট', 'date': 'তারিখ', 'kobe': 'কবে', 'hisab': 'হিসাব', 'hishab': 'হিসাব',
  'pawna': 'পাওনা', 'paona': 'পাওনা', 'dena': 'দেনা', 'baki': 'বাকি',
  // misc
  'কইরা': 'করে', 'কইরে': 'করে', 'রাইখা': 'রেখে', 'রাখছি': 'রেখেছি', 'রাখসি': 'রেখেছি', 'হইছে': 'হয়েছে', 'হইসে': 'হয়েছে',
  'গেছে্': 'গেছে', 'ভালা': 'ভালো', 'ভাল': 'ভালো', 'বালা': 'ভালো',
};

final Map<String, String> _colloquial = {for (final e in _colloquialRaw.entries) fold(e.key): fold(e.value)};

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
const _loanWords = ['ধার', 'কর্জ', 'লোন', 'loan', 'ঋণ'];
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
  // A new name typed in English letters: "rahim" → "Rahim".
  if (RegExp(r'^[a-z]').hasMatch(raw)) {
    return raw.split(' ').map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1)).join(' ');
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
  Parser({required this.ledger, this.tasks = const [], this.contacts = const [], DateTime? now}) : now = now ?? DateTime.now();

  /// Current entries, to resolve names and judge which meaning is likely.
  final List<LedgerEntry> ledger;

  /// To-dos, so "ব্যাংকের কাজ হয়ে গেছে" can find the one meant.
  final List<Task> tasks;
  final List<Contact> contacts;
  final DateTime now;

  Command parse(String said) {
    var text = normalize(said);
    if (text.isEmpty) return NotUnderstood(said);

    // "আজ আমার কী কী আছে?", "কাজের তালিকা দেখাও" (before small talk:
    // "আজ কী কী করতে হবে" is not "what can you do").
    final day = _dayQuestion(said, text);
    if (day != null) return day;

    // Conversation first ("তুমি কেমন আছো?" is not a search).
    final talk = smallTalk(text);
    if (talk != null) return SmallTalk(said, kind: talk);
    // "হ্যালো, সজীবকে ৫০০ টাকা দিলাম": drop the greeting and go on.
    final rest = stripGreeting(text);
    if (rest != text) {
      if (rest.isEmpty) return SmallTalk(said, kind: Talk.greeting);
      text = rest;
      said = stripGreeting(said.trim(), keepCase: true);
    }
    final w = words(text);

    // "মনে রাখো: …" → a note.
    final noteMatch = RegExp(r'^(মনে রাখো|মনে রেখো|মনে রাখ|নোট রাখো|নোট করো|নোট কর|লিখে রাখো|লিখে রাখ)\s*(যে)?\s*(.*)$').firstMatch(text);
    if (noteMatch != null && (noteMatch[3] ?? '').trim().isNotEmpty) {
      // Keep the user's own spelling and digits.
      final original = said.trim().replaceFirst(RegExp(r'^\S+\s+\S+\s*[:ঃ,-]?\s*(যে\s+)?'), '');
      final noteText = original.isEmpty ? noteMatch[3]!.trim() : original;
      // Money always goes to লেনদেন, even when said as "মনে রাখো …".
      final inner = parse(noteText);
      if (inner is LedgerAdd || inner is LedgerSet || inner is TaskAdd || inner is ReminderAdd || inner is ContactAdd) return inner;
      return NoteAdd(said, text: noteText);
    }

    // Calls, messages, phone numbers, timed reminders, ticking off to-dos.
    final act = _assistant(said, text, w);
    if (act != null) return act;

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

    // Anything else about money (টাকা) also belongs in লেনদেন, never in a
    // note category. Missing person or amount: the app asks for them.
    final money = _hasAny(text, ['টাকা']) || said.contains('৳') || w.contains('tk');
    if (money && !asking) {
      if (amount == null) {
        final add = _ledgerEvent(said, text, w, 0, known);
        if (add != null) return add;
      }
      return _moneyEvent(said, text, w, amount ?? 0, known);
    }

    // "কাল ব্যাংকে যেতে হবে", "বাজারের লিস্টে ডিম রাখো" → a to-do.
    if (!asking) {
      final task = _taskAdd(said, text, w);
      if (task != null) return task;
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
    final iOweWords = _hasAny(text, ['দেনা', 'ঋণ', 'দিতে হবে', 'দেব', 'দেবো', 'দিব', 'দিবো', 'দিতে বাকি', 'দিতে লাগবে', 'দেওয়া লাগবে']);
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

  /// A money sentence the patterns could not place: find whatever person
  /// is named (maybe none) and let the user choose the kind.
  LedgerAdd _moneyEvent(String said, String text, List<String> w, int amount, List<String> known) {
    String? person;
    for (final k in known) {
      if (text.contains(normalize(k))) person = k;
    }
    for (var i = 0; i < w.length && person == null; i++) {
      String? raw;
      if (w[i].endsWith('কে') && w[i] != 'আমাকে' && w[i] != 'কাকে') raw = _nameEndingAt(w, i, stripTo);
      if (raw == null && i + 1 < w.length && (w[i + 1] == 'কাছে' || w[i + 1] == 'কাছ' || w[i + 1] == 'থেকে')) {
        raw = _nameEndingAt(w, i, stripPossessive);
      }
      if (raw != null && raw.length >= 2) person = resolvePerson(raw, known);
    }
    LedgerKind? likely;
    final loan = _hasAny(text, _loanWords), ret = _hasAny(text, _returnWords);
    if (_hasAny(text, _give1)) {
      likely = ret ? LedgerKind.repaid : LedgerKind.lent;
    } else if (_hasAny(text, [..._take1, ...(loan ? _got1 : const <String>[])])) {
      likely = LedgerKind.borrowed;
    } else if (_hasAny(text, [..._got1, ..._give3])) {
      likely = ret ? LedgerKind.received : null;
    }
    return LedgerAdd(said, person: person ?? '', amount: amount, options: LedgerKind.values, suggested: likely, allowExpense: true);
  }

  LedgerAdd? _ledgerEvent(String said, String text, List<String> w, int amount, List<String> known) {
    final loan = _hasAny(text, _loanWords);
    final ret = _hasAny(text, _returnWords);

    // Shops and suppliers: "করিম ৫০০ টাকার মাল বাকিতে নিল" (they owe me),
    // "করিম বাকির ৩০০ টাকা দিয়ে গেল" (paid me), "দোকান থেকে বাকিতে নিলাম"
    // (I owe), "করিমের বাকি দিলাম" (I paid what I owed).
    final onCreditWord = w.any((x) => x.startsWith(normalize('বাকিতে')));
    final dues = onCreditWord || w.any((x) => x == normalize('বাকি') || x == normalize('বাকির') || x == normalize('বাকিটা'));
    if (dues) {
      LedgerKind? kind;
      if (onCreditWord && _hasNorm(text, ['নিলাম', 'নিয়েছি', 'নিছি', 'কিনলাম', 'কিনেছি', 'আনলাম', 'এনেছি'])) {
        kind = LedgerKind.borrowed;
      } else if (onCreditWord || _hasNorm(text, ['নিল', 'নিলো', 'নিয়েছে', 'নিছে', 'নিয়ে গেল', 'নিয়ে গেছে', 'রাখল', 'রাখলো', 'রাখছে', 'রইল', 'রইলো'])) {
        kind = LedgerKind.lent;
      } else if (_hasNorm(text, ['দিলাম', 'দিয়েছি', 'দিছি', 'শোধ করলাম', 'পরিশোধ করলাম', 'শোধ করেছি', 'শোধ করে দিলাম'])) {
        kind = LedgerKind.repaid;
      } else if (_hasNorm(text, ['দিল', 'দিলো', 'দিয়েছে', 'দিয়ে গেল', 'দিয়ে গেছে', 'দিছে', 'শোধ', 'পরিশোধ'])) {
        kind = LedgerKind.received;
      }
      final person = kind == null ? '' : _anyName(w, known);
      if (kind != null && person.isNotEmpty) return LedgerAdd(said, person: person, amount: amount, kind: kind);
    }

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

  /// Whoever is named: a known person, "X-কে", "X-এর", or a name first.
  String _anyName(List<String> w, List<String> known) {
    for (final k in known) {
      if (w.join(' ').contains(normalize(k))) return k;
    }
    for (var i = 0; i < w.length; i++) {
      if (w[i].endsWith('কে') && w[i] != 'আমাকে' && w[i] != 'কাকে') {
        final raw = _nameEndingAt(w, i, stripTo);
        if (raw != null && raw.length >= 2) return resolvePerson(raw, known);
      }
    }
    if (w.isNotEmpty) {
      final first = stripPossessive(w.first);
      if (_looksLikeName(first) && first.length >= 2 && !RegExp(r'\d').hasMatch(first)) return resolvePerson(first, known);
    }
    return '';
  }

  // ── The assistant: to-dos, reminders, calls, phone numbers ──

  Command? _dayQuestion(String said, String text) {
    final asking = isQuestionText(said) || _hasNorm(text, ['দেখাও', 'দেখান', 'বলো', 'বলুন', 'শোনাও', 'শোনান']);
    if (_hasNorm(text, _briefingKeys)) return Briefing(said);
    if (_hasNorm(text, _taskListKeys) && (asking || !_hasNorm(text, _addVerbs))) return TaskQuery(said);
    return null;
  }

  Command? _assistant(String said, String text, List<String> w) {
    final asking = isQuestionText(said);
    final phone = findPhone(said);
    final via = _via(text);

    // "রহিমকে ফোন দাও", "রহিমকে মেসেজ দাও যে আমি আসছি", "০১৭… নম্বরে ফোন দাও".
    if (via != null) {
      return CallPerson(said, person: _personIn(w), via: via, text: via == Via.call ? '' : messageText(said), phone: phone ?? '');
    }

    // "রহিমের নম্বর ০১৭১২৩৪৫৬৭৮" → keep it in যোগাযোগ.
    if (phone != null && !asking && !text.contains(normalize('টাকা'))) {
      return ContactAdd(said, name: _contactName(w), phone: phone);
    }

    // "কাল সকাল ১০টায় মিটিংয়ের কথা মনে করিয়ে দিও", "৩০ মিনিট পরে চা খাওয়ার কথা বলো".
    if (!asking && _hasNorm(text, _remindKeys)) {
      final when = parseWhen(said, now);
      if (when != null) {
        final repeat = _hasNorm(text, ['প্রতি মাসে', 'প্রতিমাসে', 'মাসে মাসে', 'every month'])
            ? Repeat.monthly
            : _hasNorm(text, ['প্রতি বছর', 'প্রতিবছর', 'বছরে বছরে', 'every year'])
                ? Repeat.yearly
                : Repeat.none;
        var title = tidy(cutWords(withoutWhen(said), [..._remindKeys, ..._fillers, 'প্রতি মাসে', 'প্রতিমাসে', 'প্রতি বছর', 'প্রতিবছর']));
        if (title.isEmpty) title = 'মনে করানো';
        return ReminderAdd(said, title: title, at: when.at, repeat: repeat);
      }
    }

    // "ব্যাংকের কাজটা হয়ে গেছে" — only when it matches a to-do.
    final money = text.contains(normalize('টাকা')) || findAmount(text) != null;
    if (!money && _hasNorm(text, _doneKeys)) {
      final terms = searchTerms(normalize(cutWords(said, [..._doneKeys, 'কাজটা', 'কাজ টা', 'কাজটি', 'কাজ', 'টা'])));
      if (terms.isNotEmpty && matchTasks(tasks.where((t) => !t.done), terms).isNotEmpty) return TaskDone(said, terms: terms);
    }
    return null;
  }

  TaskAdd? _taskAdd(String said, String text, List<String> w) {
    final listed = _hasNorm(text, _taskListKeys) || _hasNorm(text, ['লিস্টে', 'তালিকায়']);
    final mustDo = RegExp(r'\S(তে|তেই) (হবে|লাগবে)( |$)').hasMatch(text) || RegExp(r'\S (করা|কেনা|যাওয়া|আনা|দেওয়া|নেওয়া) (লাগবে|দরকার)( |$)').hasMatch(text);
    if (!listed && !mustDo) return null;
    final bazar = _hasNorm(text, ['বাজারের লিস্টে', 'বাজারের তালিকায়', 'বাজারের লিস্ট', 'বাজারের তালিকা']);
    var title = tidy(cutWords(withoutWhen(said), [
      ..._taskListKeys, 'বাজারের লিস্টে', 'বাজারের তালিকায়', 'লিস্টে', 'তালিকায়', 'কাজের', ..._addVerbs, ..._fillers,
    ]));
    if (title.isEmpty) return null;
    if (bazar) title = 'বাজার: $title';
    final when = parseWhen(said, now);
    return TaskAdd(said, title: title, due: when != null && when.hasDay ? when.day : null);
  }

  Via? _via(String text) {
    final wa = _hasNorm(text, ['হোয়াটসঅ্যাপ', 'হোয়াটসঅ্যাপে', 'হোয়াটসঅ্যাপে', 'হোয়াটসএপ', 'হোয়াটসএপে', 'হোয়াটস্যাপ', 'ওয়াটসঅ্যাপ', 'whatsapp']);
    final sms = _phraseIn(text, _smsKeys);
    final call = _phraseIn(text, _callKeys);
    if (wa && (sms || call || _hasNorm(text, ['পাঠাও', 'দাও', 'করো', 'দেন', 'পাঠান']))) return Via.whatsapp;
    if (sms) return Via.sms;
    if (call) return Via.call;
    return null;
  }

  /// "রহিমকে", "রহিম ভাইকে", "রহিমের নম্বরে".
  String _personIn(List<String> w) {
    final known = {...knownPeople(ledger), for (final c in contacts) c.name}.toList();
    const pronouns = {'আমাকে', 'তাকে', 'ওকে', 'উনাকে', 'ওনাকে', 'তাঁকে', 'কাকে', 'সবাইকে'};
    for (var i = 0; i < w.length; i++) {
      if (w[i].endsWith('কে') && !pronouns.contains(w[i])) {
        final raw = _nameEndingAt(w, i, stripTo);
        if (raw != null && raw.length >= 2) return resolvePerson(raw, known);
      }
      if (i + 1 < w.length && {'নম্বরে', 'নাম্বারে', 'মোবাইলে', 'ফোনে'}.contains(w[i + 1])) {
        final raw = _nameEndingAt(w, i, stripPossessive);
        if (raw != null && raw.length >= 2) return resolvePerson(raw, known);
      }
    }
    return '';
  }

  String _contactName(List<String> w) {
    final known = {...knownPeople(ledger), for (final c in contacts) c.name}.toList();
    for (var i = 0; i + 1 < w.length; i++) {
      if ({'নম্বর', 'নাম্বার', 'ফোন', 'মোবাইল', 'নং', 'number'}.contains(w[i + 1])) {
        final raw = _nameEndingAt(w, i, stripPossessive);
        if (raw != null && raw.length >= 2) return resolvePerson(raw, known);
      }
    }
    if (w.isNotEmpty && _looksLikeName(w.first) && !RegExp(r'\d').hasMatch(w.first)) {
      final raw = stripPossessive(w.first);
      if (raw.length >= 2 && !{'নম্বর', 'নাম্বার', 'ফোন', 'মোবাইল', 'নতুন'}.contains(raw)) return resolvePerson(raw, known);
    }
    return '';
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

bool _hasNorm(String text, List<String> keys) => keys.any((k) {
      final n = normalize(k);
      return n.isNotEmpty && text.contains(n);
    });

/// A phrase as whole words ("ফোন কর" must not match "ফোন করতে হবে").
bool _phraseIn(String text, List<String> keys) {
  final padded = ' $text ';
  return keys.any((k) {
    final n = normalize(k);
    return n.isNotEmpty && padded.contains(' $n ');
  });
}

const _briefingKeys = [
  'আজ আমার কী কী আছে', 'আজকে আমার কী কী আছে', 'আজ আমার কি কি আছে', 'আজকে আমার কি কি আছে', 'আজ কী কী আছে', 'আজকে কী কী আছে',
  'আজ কি কি আছে', 'আজকে কি কি আছে', 'আজ আমার কী আছে', 'আজকে কী আছে', 'আজ কী আছে', 'আজকে কি আছে', 'আজ কি আছে',
  'আজকের প্ল্যান', 'আজকের পরিকল্পনা', 'আজকের সারাংশ', 'দিনের সারাংশ', 'সারাদিনের কাজ', 'আজকের শিডিউল', 'শিডিউল কী', 'শিডিউল কি',
  'briefing', 'ব্রিফিং', 'আজ কী করতে হবে', 'আজকে কী করতে হবে', 'আজ কি করতে হবে', 'আজকে কি করতে হবে', 'আজকের কাজ', 'আজকে কী কাজ',
  'আজ কী কাজ', 'আজকে কি কাজ', 'আজ কি কাজ', 'today schedule', 'my day', 'আজ কী কী করতে হবে', 'আজকে কী কী করতে হবে',
  'আজ কি কি করতে হবে', 'আজকে কি কি করতে হবে', 'আজ কী কী কাজ', 'আজকে কী কী কাজ', 'আজ কি কি কাজ', 'আজকে কি কি কাজ',
];
const _taskListKeys = [
  'কাজের তালিকা', 'কাজের লিস্ট', 'কী কী কাজ', 'কি কি কাজ', 'কোন কোন কাজ', 'বাকি কাজ', 'কাজ বাকি', 'টু ডু', 'টুডু', 'todo', 'to do',
  'বাজারের লিস্ট', 'বাজারের তালিকা', 'লিস্টে কী', 'লিস্টে কি', 'তালিকায় কী', 'তালিকায় কি',
];
const _addVerbs = [
  'রাখো', 'রাখ', 'রেখো', 'রাখেন', 'রাখুন', 'যোগ করো', 'যোগ কর', 'যোগ করেন', 'যোগ করুন', 'লেখো', 'লিখো', 'লিখে রাখো', 'লিখে রাখ',
  'লিখে রেখো', 'লিখে রাখেন', 'add', 'মনে রাখো', 'তুলে রাখো', 'ঢুকাও',
];
const _fillers = ['আমাকে', 'আমারে', 'প্লিজ', 'একটু', 'please', 'তো'];
const _remindKeys = [
  'মনে করিয়ে দিও', 'মনে করিয়ে দিবা', 'মনে করিয়ে দেবে', 'মনে করিয়ে দিবে', 'মনে করিয়ে দাও', 'মনে করিয়ে দিয়ো', 'মনে করিয়ে দিবেন',
  'মনে করিয়ে দিন', 'মনে করিয়ে দেবেন', 'মনে করিয়ে দিও তো', 'মনে করিয়ে', 'মনে করাবে', 'মনে করাবা', 'মনে করাইও', 'মনে করাইয়া দিও',
  'রিমাইন্ডার দাও', 'রিমাইন্ডার দিও', 'রিমাইন্ডার সেট করো', 'রিমাইন্ডার রাখো', 'রিমাইন্ডার', 'অ্যালার্ম দাও', 'অ্যালার্ম দিও',
  'অ্যালার্ম সেট করো', 'এলার্ম দাও', 'এলার্ম দিও', 'remind me', 'remind', 'alarm', 'জানিয়ে দিও', 'জানিয়ে দিবা', 'জানাবে', 'ডেকে দিও',
  'ডেকে দিবা', 'কথা বলো', 'কথা বলবা', 'কথা বলবে', 'কথা বলিও', 'বলে দিও', 'বলে দিবা',
];
const _doneKeys = [
  'হয়ে গেছে', 'হয়ে গিয়েছে', 'হয়েছে', 'করে ফেলেছি', 'করে ফেলছি', 'করেছি', 'করছি', 'সেরে ফেলেছি', 'সেরেছি', 'শেষ করেছি', 'শেষ হয়েছে',
  'শেষ হয়ে গেছে', 'কেনা হয়েছে', 'কেনা হয়ে গেছে', 'কিনে ফেলেছি', 'কিনেছি', 'কিনছি', 'done', 'সম্পন্ন', 'কমপ্লিট', 'complete', 'হয়ে গেলো',
  'দিয়ে দিয়েছি', 'দিয়ে দিছি', 'গেছিলাম', 'গিয়েছিলাম', 'গিয়েছি', 'আনা হয়েছে', 'এনেছি',
];
const _callKeys = [
  'ফোন দাও', 'ফোন দেও', 'ফোন দে', 'ফোন করো', 'ফোন কর', 'ফোন করেন', 'ফোন দেন', 'ফোন লাগাও', 'ফোন দিন', 'ফোন করুন', 'ফোন দিও',
  'কল দাও', 'কল দেও', 'কল করো', 'কল কর', 'কল দেন', 'কল করেন', 'কল দিন', 'কল করুন', 'কল লাগাও', 'কল দিও', 'call', 'call koro',
  'call dao', 'phone dao', 'phone koro', 'ফোন দাওতো', 'কল দাওতো',
];
const _smsKeys = [
  'মেসেজ দাও', 'মেসেজ পাঠাও', 'মেসেজ করো', 'মেসেজ দেন', 'মেসেজ দিন', 'মেসেজ কর', 'মেসেজ পাঠান', 'মেসেজ দিও', 'ম্যাসেজ দাও',
  'ম্যাসেজ পাঠাও', 'ম্যাসেজ করো', 'ম্যাসেজ দেন', 'এসএমএস দাও', 'এসএমএস পাঠাও', 'এসএমএস করো', 'sms', 'sms koro', 'sms dao',
  'টেক্সট করো', 'টেক্সট দাও', 'টেক্সট পাঠাও', 'বার্তা পাঠাও', 'message', 'message dao', 'message koro', 'লিখে পাঠাও',
];

/// A Bangladeshi mobile number in [said] ("০১৭১২-৩৪৫৬৭৮", "+8801712345678").
String? findPhone(String said) {
  final t = asciiDigits(fold(said));
  final m = RegExp(r'(?<!\d)(\+?88)?0?1[3-9]\d{2}[\s-]?\d{6}(?!\d)').firstMatch(t);
  if (m == null) return null;
  var p = m[0]!.replaceAll(RegExp(r'[\s-]'), '');
  if (p.startsWith('1')) p = '0$p';
  return p;
}

/// The words after "যে" or after "মেসেজ দাও": "রহিমকে মেসেজ দাও যে আমি আসছি" → "আমি আসছি".
String messageText(String said) {
  final f = fold(said.trim());
  final ye = RegExp('(^|\\s)${fold('যে')}\\s+').firstMatch(f);
  if (ye != null) return tidy(f.substring(ye.end));
  var cut = -1;
  for (final k in [..._smsKeys, 'হোয়াটসঅ্যাপে', 'হোয়াটসঅ্যাপে', 'whatsapp', 'পাঠাও', 'লেখো']) {
    final kk = fold(k).toLowerCase();
    final i = f.toLowerCase().indexOf(kk);
    if (i >= 0 && i + kk.length > cut) cut = i + kk.length;
  }
  if (cut < 0 || cut >= f.length) return '';
  return tidy(f.substring(cut));
}

/// To-dos whose title shares a word with [terms], best first.
List<Task> matchTasks(Iterable<Task> tasks, List<String> terms) {
  final scored = <(Task, int)>[];
  for (final t in tasks) {
    final title = normalize(t.title);
    final tw = words(title).map(stem).toSet();
    var n = 0;
    for (final x in terms) {
      if (x.length >= 2 && (tw.contains(x) || title.contains(x))) n++;
    }
    if (n > 0) scored.add((t, n));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final s in scored) s.$1];
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
  'হ', 'হো', 'হঁ', 'জে', 'জ্বে', 'জ্বী', 'আইচ্ছা', 'আচ্চা', 'ঠিকাছে', 'ঠিকআছে', 'রাইখা', 'রাখেন', 'দেন', 'করেন', 'অক্কে', 'ওক্কে',
  'হ্যাঁ', 'হ্যা', 'হাঁ', 'হা', 'জি', 'জ্বি', 'জী', 'হুম', 'হুঁ', 'ঠিক', 'আচ্ছা', 'অবশ্যই', 'নিশ্চয়ই', 'একদম', 'সঠিক',
  'করো', 'কর', 'করেন', 'করুন', 'রাখো', 'রাখ', 'রাখেন', 'রাখুন', 'সেভ', 'যোগ', 'দাও', 'দিন', 'চলবে', 'হবে', 'হ্যাঁ।',
  'ok', 'okay', 'ওকে', 'yes', 'yeah', 'yep', 'sure', 'save', 'right',
];
const _noRaw = ['না', 'নাহ', 'নো', 'no', 'nope', 'বাতিল', 'থাক', 'থাউক', 'থাকুক', 'ভুল', 'cancel', 'নয়', 'নাগো', 'নারে', 'নাহি'];

final Set<String> _yes = {for (final x in _yesRaw) fold(x)};
final Set<String> _no = {for (final x in _noRaw) fold(x)};

/// A spoken answer: true for হ্যাঁ and its kin ("জি", "ঠিক আছে", "রাখো",
/// "ok"…), false for না/বাতিল/থাক/"দরকার নেই", null when unclear.
bool? yesNo(String said) {
  final t = normalize(said);
  if (t.isEmpty) return null;
  final w = words(t);
  if (w.any(_no.contains) || _hasAny(t, ['দরকার নেই', 'লাগবে না', 'রেখো না', 'রাখো না', 'করো না', 'চাই না', 'বাদ দাও', 'বাদ দেন', 'বাদ দে', 'রাখার দরকার'])) return false;
  if (w.any(_yes.contains) || _hasAny(t, ['ঠিক আছে', 'সেভ করো', 'যোগ করো'])) return true;
  return null;
}

bool _hasPhrase(String text, List<String> ps) => ps.any((p) => text.contains(fold(p)));

/// Recognises conversation. [text] is normalized.
Talk? smallTalk(String text) {
  final w = words(text);
  if (_hasPhrase(text, ['কেমন আছ', 'কেমন আছেন', 'কেমন আছিস', 'কি অবস্থা', 'কী অবস্থা', 'কী খবর', 'কি খবর', 'how are you'])) {
    return Talk.howAreYou;
  }
  bool seq(String a, String b) {
    for (var i = 0; i + 1 < w.length; i++) {
      if (w[i] == fold(a) && w[i + 1] == fold(b)) return true;
    }
    return false;
  }

  if (seq('তুমি', 'কে') || seq('আপনি', 'কে') || seq('তুই', 'কে') || _hasPhrase(text, ['তোমার নাম কী', 'তোমার নাম কি', 'আপনার নাম কী', 'আপনার নাম কি', 'who are you', 'your name'])) {
    return Talk.whoAreYou;
  }
  if (_hasPhrase(text, [
    'কী করতে পার', 'কি করতে পার', 'কী কী পার', 'কি কি পার', 'কী কী করতে', 'কি কি করতে', 'কীভাবে ব্যবহার', 'কিভাবে ব্যবহার',
    'কী বলতে পারি', 'কি বলতে পারি', 'কী জিজ্ঞেস করতে', 'কি জিজ্ঞেস করতে', 'what can you do',
  ]) || (w.length <= 3 && _hasPhrase(text, ['সাহায্য', 'help']))) {
    return Talk.whatCanYouDo;
  }
  if (_hasPhrase(text, ['কয়টা বাজে', 'কটা বাজে', 'কয়টা বাজে', 'এখন সময় কত', 'সময় কত', 'what time'])) return Talk.time;
  if (_hasPhrase(text, ['আজ কত তারিখ', 'আজকে কত তারিখ', 'আজকের তারিখ', 'আজ কী বার', 'আজ কি বার', 'আজকে কী বার', 'আজকে কি বার', 'আজ কোন বার'])) {
    return Talk.date;
  }
  if (w.length <= 5 && _hasPhrase(text, ['ধন্যবাদ', 'থ্যাংক', 'থ্যাঙ্ক', 'thank', 'শুকরিয়া'])) return Talk.thanks;
  if (w.length <= 4 && _hasPhrase(text, ['বিদায়', 'আল্লাহ হাফেজ', 'খোদা হাফেজ', 'bye', 'পরে কথা হবে', 'শুভ রাত্রি'])) return Talk.bye;
  if (w.length <= 4 && _hasPhrase(text, ['ভালো আছি', 'ভাল আছি', 'আমি ভালো', 'ঠিক আছি', 'আলহামদুলিল্লাহ'])) return Talk.imFine;
  if (w.length <= 3 && _hasPhrase(text, ['সালাম', 'আসসালামু', 'আস্সালামু'])) return Talk.salam;
  if (w.length <= 3 && _hasPhrase(text, ['শুভ সকাল', 'শুভ সন্ধ্যা', 'শুভ দুপুর', 'শুভ বিকেল', 'গুড মর্নিং', 'good morning'])) return Talk.greeting;
  final greet = {for (final g in _greetings) fold(g)};
  if (w.isNotEmpty && w.every((x) => greet.contains(x) || x == 'ডিজিটাল' || x == 'ব্রেইন' || x == 'brain' || x == 'digital' || x == 'অ্যাসিস্ট্যান্ট' || x == 'এসিস্ট্যান্ট' || x == 'assistant' || x == 'সহকারী')) {
    return Talk.greeting;
  }
  return null;
}

/// Greeting words that can be dropped from the start of a sentence. Not
/// "শুভ" (a common name) — "শুভ সকাল" is recognised as a phrase instead.
const _greetings = [
  'হ্যালো', 'হেলো', 'হাই', 'hello', 'hi', 'hey', 'নমস্কার', 'আসসালামু', 'আলাইকুম', 'আসসালামুয়ালাইকুম', 'আস্সালামু', 'সালাম',
  'শোনো', 'শুনুন', 'শোন', 'এই',
];

/// Removes greeting words at the start: "হ্যালো সজীবকে…" → "সজীবকে…".
String stripGreeting(String text, {bool keepCase = false}) {
  final greet = {for (final g in _greetings) fold(g)};
  final parts = text.split(RegExp(r'\s+'));
  var i = 0;
  while (i < parts.length && greet.contains(normalize(parts[i]))) {
    i++;
  }
  if (i == 0) return text;
  return parts.sublist(i).join(' ').trim();
}

/// A name said in answer to "কার সাথে?": "রহিম", "রহিম ভাই", "ওনার নাম
/// করিম" → the name, matched to someone already in the ledger if possible.
String spokenName(String heard, List<String> known) {
  const filler = {'নাম', 'ওনার', 'উনার', 'তার', 'তাঁর', 'ওর', 'হলো', 'হল', 'হচ্ছে', 'হইলো', 'জি', 'জ্বি', 'আচ্ছা', 'মানে', 'তো', 'এর', 'সাথে', 'সঙ্গে', 'লেনদেন'};
  final fillers = {for (final f in filler) fold(f)};
  final ws = words(normalize(heard)).where((x) => !fillers.contains(x)).toList();
  if (ws.isEmpty) return '';
  final joined = ws.take(3).join(' ');
  for (final k in known) {
    if (normalize(k) == joined || ws.any((x) => normalize(k) == stripTo(stripPossessive(x)))) return k;
  }
  // Keep the user's own spelling for a new name.
  final original = heard.trim().replaceAll(RegExp(r'[।?!,.]'), '').split(RegExp(r'\s+'))
      .where((x) => !fillers.contains(fold(x.toLowerCase())))
      .take(3)
      .map((x) => stripTo(stripPossessive(x)))
      .join(' ');
  return original.trim();
}

/// Sentences about passwords, PINs, OTPs or card numbers never leave the
/// phone (they are not sent to the AI).
bool mentionsSecret(String said) {
  final t = normalize(said);
  if (_hasAny(t, _vaultWords)) return true;
  if (_hasAny(t, ['wi-fi', 'wifi', 'ওয়াইফাই', 'ওয়াই-ফাই', 'ওয়াই ফাই', 'ওটিপি', 'otp', 'সিভিভি', 'cvv', 'কার্ড নম্বর', 'কার্ডের নম্বর', 'card number'])) {
    return true;
  }
  final w = words(t);
  return w.contains('পিন') || w.contains('pin');
}
