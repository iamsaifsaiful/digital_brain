/// Understands what the user said (or typed) in Bengali.
///
/// Version 1 works from sentence patterns, not AI: it recognises the usual
/// ways people say they gave, took, got back or paid back money, and the
/// usual ways of asking for a balance, a login, a date or a note. When the
/// meaning of a money sentence is not clear it never guesses: it returns the
/// choices so the app can ask.
library;

import '../models/models.dart';
import 'app_map.dart';
import 'ask.dart';
import 'manage.dart';
import 'me.dart';
import 'bn.dart';
import 'ledger.dart';
import 'cash.dart';
import 'meaning.dart';
import 'answers.dart' show periodIn;
import 'when.dart';
import 'calendar_bd.dart' show hijriDate;
import 'phrases.dart' show toPerson;
import 'match.dart' show wordsMatch;

part 'todo.dart';
part 'aspect.dart';
part 'menus.dart';
part 'selection.dart';

sealed class Command {
  const Command(this.transcript);
  final String transcript;
}

/// A money event to confirm. [kind] is null when the user must choose
/// between [options]; [suggested] is the likeliest one.
class LedgerAdd extends Command {
  const LedgerAdd(super.transcript,
      {required this.person, required this.amount, this.kind, this.options = const [], this.suggested, this.allowExpense = false, this.date});
  final String person;

  /// The day it happened when said ("গতকাল", "কাল … দিছি", "১০ তারিখে"); null = today.
  final DateTime? date;
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

/// "ফেসবুকের পাসওয়ার্ড ১২২৩৯৯৩৯": keep a login in the vault. Never sent to
/// the AI and never read aloud.
class VaultAdd extends Command {
  const VaultAdd(super.transcript, {required this.name, required this.password, this.wifi = false});
  final String name;
  final String password;
  final bool wifi;
}

class ReminderQuery extends Command {
  const ReminderQuery(super.transcript, {required this.terms, this.alarmsOnly = false});
  final List<String> terms;

  /// "আমার কোন এলার্ম আছে?", "কখন আছে এলার্ম?": the alarms only.
  final bool alarmsOnly;
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
  const TaskAdd(super.transcript, {required this.title, this.due, this.span = TaskSpan.day, this.repeat, this.deadline = false, this.condition, this.urgent = false, this.monthEndAsked = false, this.by});
  final String title;

  /// "বৃহস্পতিবার করব, তবে শুক্রবারের মধ্যে জমা দিতে হবে": the last day,
  /// beside the day it is planned for.
  final DateTime? by;

  /// "প্রতি মাসের ৩১ তারিখে": what a shorter month does was already asked.
  final bool monthEndAsked;

  /// The day — or with a wider [span], the first day of that week, month or year.
  final DateTime? due;
  final TaskSpan span;
  final TaskRepeat? repeat;

  /// "শুক্রবারের মধ্যে": [due] is the last day for it.
  final bool deadline;

  /// "বেতন পেলে", "অফিস থেকে ফেরার পর": kept with it, never guessed into a date.
  final String? condition;
  final bool urgent;
}

/// "ব্যাংকের কাজটা হয়ে গেছে" → tick the matching to-do.
class TaskDone extends Command {
  const TaskDone(super.transcript, {required this.terms, this.done = true, this.ref, this.partial = false, this.all = false, this.allToday = false});
  final List<String> terms;

  /// False: "…এখনো শেষ হয়নি" — the to-do is still open.
  final bool done;

  /// Which one ("ওটা", "দ্বিতীয়টা", by its words); null = by [terms].
  final TaskRef? ref;

  /// "কাজটা অর্ধেক হয়েছে".
  final bool partial;

  /// "সব কাজ শেষ" — today's ([allToday]) or, when not said, asked.
  final bool all;
  final bool allToday;
}

/// "আমার সংরক্ষিত ফোন নম্বর দেখাও": the saved numbers — a look, not a save.
class ContactsQuery extends Command {
  const ContactsQuery(super.transcript);
}

/// "আজ কী কী কাজ আছে?"
class TaskQuery extends Command {
  const TaskQuery(super.transcript, {this.scope});

  /// What the question covers; null = the usual answer for its words.
  final TaskScope? scope;
}

/// "দশ মিনিট পরে আবার মনে করিও": the reminder that just rang (or was just
/// set) again after [minutes].
class ReminderSnooze extends Command {
  const ReminderSnooze(super.transcript, {required this.minutes});
  final int minutes;
}

/// "আজকের সব কাজ মুছে দাও", "কাজের তালিকার সবকটা ডিলিট করো": every open
/// to-do (of [day], when one is said) — confirmed once, then removed (kept
/// 30 days in মুছে ফেলা).
class TasksClear extends Command {
  const TasksClear(super.transcript, {this.day, this.doneOnly = false, this.ids = const []});
  final DateTime? day;

  /// Just these to-dos ("বাজারের কাজটা মুছে দাও" after it was found).
  final List<String> ids;

  /// "শেষ করা কাজগুলো সরাও": only the ticked ones.
  final bool doneOnly;
}

/// "কাল সকাল ১০টায় মিটিংয়ের কথা মনে করিয়ে দিও".
class ReminderAdd extends Command {
  const ReminderAdd(super.transcript,
      {required this.title, required this.at, this.repeat = Repeat.none, this.alarm = false, this.weekdays = const [], this.minutesBefore = 0, this.day, this.part, bool? ampmOpen})
      : _ampmOpen = ampmOpen;
  final String title;

  final bool? _ampmOpen;

  /// The hour of [at] is not settled yet: "চারটায়" was said with no ভোর/
  /// বিকেল — [at] is only one of two readings, so it is asked and never
  /// handed to the scheduler as it is. Set by whoever settled it (the
  /// clarification's answer passes false); otherwise read from the words.
  bool get ampmOpen => _ampmOpen ?? (!needsTime && !repeat.isInterval && hourOpen(transcript, at.hour));

  /// "কাল সকালে মনে করিও": only the part of the day was said — the hour is
  /// asked ("সকালে কয়টায়?"), and an answer like "আটটায়" stays in it.
  final String? part;

  /// A day said without a time ("কাল মনে করিয়ে দিও"): the chat asks the hour for it.
  final DateTime? day;

  /// "৩০ মিনিট আগে মনে করিয়ে দিও": an early notice this many minutes before (0 = none).
  final int minutesBefore;
  final DateTime at;
  final Repeat repeat;

  /// "অ্যালার্ম দাও": shown on the অ্যালার্ম page.
  final bool alarm;

  /// For a weekly one: the days (DateTime.monday … sunday).
  final List<int> weekdays;

  /// No time was said yet ("ওষুধের রিমাইন্ডার দিও"): the chat asks when.
  bool get needsTime => at.year <= 2000;

  /// Only a time was said ("৬.২০-এ রিমাইন্ডার দিও"): the chat asks what for.
  bool get needsTitle => title.trim().isEmpty || title == defaultReminderTitle;
}

/// [ReminderAdd.at] when the time is still to be asked.
final noTimeYet = DateTime(2000);

/// The title of a reminder when nothing but the time was said.
const defaultReminderTitle = 'মনে করানো';

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

/// Money in or out that nobody owes: "বাজারে ৫০০ টাকা খরচ হলো",
/// "বেতন পেলাম ৩০ হাজার", or a project's ("রহিম ভবন প্রজেক্টে ৫০ হাজার
/// টাকা এলো"; [project] is the name, "" when not said).
class CashAdd extends Command {
  const CashAdd(super.transcript, {required this.kind, required this.amount, this.category = 'অন্যান্য', this.project});
  final CashKind kind;
  final int amount;
  final String category;
  final String? project;
}

/// "এই মাসে কত খরচ হলো?", "রহিম ভবন প্রজেক্টে কত টাকা আছে?"
class CashQuery extends Command {
  const CashQuery(super.transcript, {this.project});
  final String? project;
}

/// "আজ আমার কী কী আছে?" — today's to-dos, reminders and dues.
class Briefing extends Command {
  const Briefing(super.transcript);
}

class SearchQuery extends Command {
  const SearchQuery(super.transcript, {required this.terms});
  final List<String> terms;
}

/// "রহিম আমার শ্যালক মনে রেখো", "মনে রাখো আমি শুক্রবার অফিস করি না":
/// something about the user for the assistant to keep in mind.
class MemoryAdd extends Command {
  const MemoryAdd(super.transcript, {required this.text});
  final String text;
}

/// "রহিমের জন্মদিন ১২ মার্চ", "আব্বার মৃত্যুবার্ষিকী ৩ জুন": a day every year.
class SpecialAdd extends Command {
  const SpecialAdd(super.transcript, {required this.person, required this.kind, required this.month, required this.day, this.year, this.hour, this.minute = 0});
  final String person;

  /// "সকাল ১১টায় তুবার জন্মদিনের রিমাইন্ডার দাও": the time said for the
  /// yearly ring (null = the usual 9 in the morning).
  final int? hour;
  final int minute;
  final SpecialKind kind;
  final int month;
  final int day;
  final int? year;
}

/// "আজ ওজন ৬৮ কেজি", "প্রেশার ১৪০ বাই ৯০", "খালি পেটে সুগার ৭.২",
/// "৩ গ্লাস পানি খেলাম", "৩০ মিনিট হাঁটলাম" — a health reading.
class HealthAdd extends Command {
  const HealthAdd(super.transcript, {required this.kind, required this.a, this.b, this.c, this.tag = '', this.member = 'me'});
  final HealthKind kind;
  final double a;
  final double? b;
  final double? c;
  final String tag;

  /// Whose (a family member's id, or 'me').
  final String member;
}

/// "আমার বিএমআই কত?", "প্রেশার কেমন?", "গত মাসে ওজন কত কমল?"
class HealthQuery extends Command {
  const HealthQuery(super.transcript, {required this.what, this.member = 'me'});

  /// 'bmi', or a [HealthKind] name.
  final String what;
  final String member;
}

/// "নোট খোলো", "সেটিংসে যাও", "প্রেসক্রিপশন ফোল্ডার দেখাও": open a part of the app.
class OpenPlace extends Command {
  const OpenPlace(super.transcript, {required this.place, this.folder});

  /// An [AppPlace] id ('docs' / 'notes' with a [folder]).
  final String place;
  final String? folder;
}

/// "মিটিংয়ের রিমাইন্ডার মুছে দাও", "রহিমের লেনদেনটা ৬০০ করে দাও": change or
/// remove something saved ([action] 'delete' or 'edit').
class ManageItem extends Command {
  const ManageItem(super.transcript, {required this.action});
  final String action;
}

/// "আমার ব্লাড গ্রুপ বি পজিটিভ", "আম্মার রক্তের গ্রুপ ও+": a fact to keep.
class ProfileSet extends Command {
  const ProfileSet(super.transcript, {required this.field, required this.value, this.who = ''});

  /// 'blood'.
  final String field;
  final String value;

  /// A family member's name or relation ('' = the user).
  final String who;
}

/// "আমার ব্লাড গ্রুপ কী?", "আমার কী কী ছবি আছে?" — answered from the phone.
class ProfileQuery extends Command {
  const ProfileQuery(super.transcript);
}

/// "এ মাসে কী কী লেনদেন হলো?", "গত সপ্তাহের বাজারের খরচগুলো দেখাও": the
/// money records of a time span — from the লেনদেন book and আয়-ব্যয় only,
/// filtered by date, খাত and person.
class MoneyListQuery extends Command {
  const MoneyListQuery(super.transcript, {required this.from, required this.to, required this.label, this.category, this.person});
  final DateTime from;
  final DateTime to;

  /// "এই মাসে", "গত সপ্তাহে".
  final String label;

  /// An আয়-ব্যয় খাত ("বাজার", "অন্যান্য"); null = all.
  final String? category;

  /// One person in the লেনদেন book; null = everyone.
  final String? person;
}

/// The request can mean more than one thing: ask which, with ready answers.
class Clarify extends Command {
  const Clarify(super.transcript, {required this.question, required this.options});
  final String question;
  final List<(String, Command)> options;
}

class NotUnderstood extends Command {
  const NotUnderstood(super.transcript);
}

enum Talk { greeting, salam, howAreYou, imFine, whoAreYou, whatCanYouDo, thanks, bye, time, date, nothingDone, cancelled, wontDo, listenOverMe, understand, sorry, calendar }

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
  // Banglish clock times: "8tay" → "8টায়", "10ta" → "10টা".
  t = t.replaceAllMapped(RegExp(r'(\d)(?:tay|tai|te)(?![a-z])'), (m) => '${m[1]}টায়').replaceAllMapped(RegExp(r'(\d)ta(?![a-z])'), (m) => '${m[1]}টা');
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
  'kal': 'কাল', 'kalke': 'কালকে', 'aj': 'আজ', 'aaj': 'আজ', 'ajke': 'আজকে', 'porshu': 'পরশু', 'sokal': 'সকাল', 'sokale': 'সকালে',
  'dupur': 'দুপুর', 'dupure': 'দুপুরে', 'bikal': 'বিকাল', 'bikele': 'বিকেলে', 'sondha': 'সন্ধ্যা', 'sondhay': 'সন্ধ্যায়', 'rat': 'রাত',
  'rate': 'রাতে', 'kotha': 'কথা', 'koriye': 'করিয়ে', 'dio': 'দিও', 'diyo': 'দিও', 'dao': 'দাও', 'dibe': 'দিবে', 'diba': 'দিবা',
  'koro': 'করো', 'kor': 'কর',
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
    if (w.endsWith(suf) && w.length > suf.length + 1) {
      final base = w.substring(0, w.length - suf.length);
      // "ভাইয়ের" → "ভাই", "মায়ের" → "মা": the য় only joins the ending.
      for (final y in ['\u09DF', '\u09AF\u09BC']) {
        if (base.endsWith(y) && base.length > y.length + 1) {
          final before = base[base.length - y.length - 1];
          if (_vowelSigns.contains(before) || 'অআইঈউঊএঐওঔ'.contains(before)) return base.substring(0, base.length - y.length);
        }
      }
      return base;
    }
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
  'এক': 1, 'দুই': 2, 'দু': 2, 'তিন': 3, 'চার': 4, 'পাঁচ': 5, 'ছয়': 6, 'সাত': 7, 'আট': 8, 'দশ': 10,
  'এগারো': 11, 'বারো': 12, 'তেরো': 13, 'চৌদ্দ': 14, 'পনেরো': 15, 'পনের': 15, 'ষোলো': 16, 'ষোল': 16, 'সতেরো': 17,
  'আঠারো': 18, 'উনিশ': 19, 'বিশ': 20, 'কুড়ি': 20, 'পঁচিশ': 25, 'ত্রিশ': 30, 'তিরিশ': 30, 'চল্লিশ': 40, 'পঞ্চাশ': 50, 'ষাট': 60,
  'সত্তর': 70, 'আশি': 80, 'নব্বই': 90, 'একশ': 100, 'একশো': 100, 'দেড়': 1.5, 'আড়াই': 2.5,
};

final Map<String, num> _numberWords = {for (final e in _numberWordsRaw.entries) fold(e.key): e.value};

/// The amount in a sentence, in whole taka. Understands "৫০০", "১,০০০",
/// "২ হাজার", "দেড় হাজার", "পাঁচশো", "৩ লাখ", "সাড়ে তিন হাজার" and
/// amounts said in parts: "দুই হাজার পাঁচশ" = 2500, "এক লাখ বিশ হাজার".
int? findAmount(String normalized) {
  final w = words(normalized);

  // One part: a number and its multiplier ("দুই হাজার", "পাঁচশ", "৫০০").
  // Returns (value, multiplier, words used) or null.
  (num, int, int)? part(int i) {
    if (i >= w.length) return null;
    var at = i;
    var half = 0.0;
    if (w[at] == fold('সাড়ে') && at + 1 < w.length) {
      half = 0.5;
      at++;
    }
    num? base;
    var mult = 1;
    final digits = RegExp(r'^(\d+(?:\.\d+)?)').firstMatch(w[at]);
    if (digits != null) {
      base = num.parse(digits[1]!);
      // "500টাকা" or "500/-": the number is still the amount.
    } else {
      base = _numberWords[w[at]];
      if (base == null) {
        // পাঁচশো / পাঁচশ / দুইশো
        final m = RegExp(fold(r'^(.+?)(শো|শ|শত)(?:টা|টি|টাকা|টাকার|র|ের|এর)?$')).firstMatch(w[at]);
        if (m != null && _numberWords[m[1]] != null) {
          base = _numberWords[m[1]]!;
          mult = 100;
        }
      }
    }
    if (base == null) return null;
    final next = at + 1 < w.length ? w[at + 1] : '';
    // "এক হাজারের", "দুই লাখ টাকার": the multiplier with an ending.
    final m2 = RegExp(fold(r'^হাজার(?:ের|এর|ে|টাকার|টাকা)?$')).hasMatch(next)
        ? 1000
        : RegExp(fold(r'^(?:লাখ|লক্ষ)(?:ের|এর|ে|টাকার|টাকা)?$')).hasMatch(next)
            ? 100000
            : RegExp(fold(r'^কোটি(?:র|তে|টাকার|টাকা)?$')).hasMatch(next)
                ? 10000000
                : (next == 'শো' || next == 'শ' || next == 'শত')
                    ? 100
                    : 0;
    if (m2 > 0) mult = m2;
    return ((base + half) * mult, mult, at - i + 1 + (m2 > 0 ? 1 : 0));
  }

  for (var i = 0; i < w.length; i++) {
    final first = part(i);
    if (first == null) continue;
    var total = first.$1;
    var lastMult = first.$2;
    var j = i + first.$3;
    // Following smaller parts add up: "দুই হাজার" + "পাঁচশ".
    while (lastMult > 1) {
      final more = part(j);
      if (more == null || more.$2 >= lastMult) break;
      total += more.$1;
      lastMult = more.$2;
      j += more.$3;
    }
    final v = total.round();
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
const _returnWords = ['ফেরত', 'শোধ', 'পরিশোধ', 'ফিরিয়ে'];
final List<String> _honorifics = [for (final h in _honorificsRaw) fold(h)];
const _honorificsRaw = ['ভাই', 'ভাইয়া', 'ভাইয়া', 'আপা', 'আপু', 'চাচা', 'মামা', 'খালা', 'কাকা', 'দাদা', 'স্যার', 'সাহেব', 'বোন', 'মিয়া', 'মিঞা', 'মিয়াঁ', 'ভাবি', 'ভাবী', 'চাচী', 'চাচি', 'মামী', 'মামি', 'খালু', 'ফুফু', 'নানা', 'নানি', 'দাদি', 'হুজুর', 'মাস্টার', 'ভাইজান'];
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

// ───────────────────────── Special days and memory ─────────────────────────

const _monthWords = {
  'জানুয়ারি': 1, 'জানুয়ারী': 1, 'জানু': 1, 'january': 1, 'jan': 1,
  'ফেব্রুয়ারি': 2, 'ফেব্রুয়ারী': 2, 'ফেব্রু': 2, 'february': 2, 'feb': 2,
  'মার্চ': 3, 'march': 3, 'mar': 3,
  'এপ্রিল': 4, 'april': 4, 'apr': 4,
  'মে': 5, 'may': 5,
  'জুন': 6, 'june': 6, 'jun': 6,
  'জুলাই': 7, 'july': 7, 'jul': 7,
  'আগস্ট': 8, 'আগষ্ট': 8, 'august': 8, 'aug': 8,
  'সেপ্টেম্বর': 9, 'সেপ্টে': 9, 'september': 9, 'sep': 9, 'sept': 9,
  'অক্টোবর': 10, 'অক্টো': 10, 'october': 10, 'oct': 10,
  'নভেম্বর': 11, 'নভে': 11, 'november': 11, 'nov': 11,
  'ডিসেম্বর': 12, 'ডিসে': 12, 'december': 12, 'dec': 12,
};

final Map<String, int> _months = {for (final e in _monthWords.entries) fold(e.key): e.value};

const _specialKinds = {
  'জন্মদিন': SpecialKind.birthday, 'জন্ম দিন': SpecialKind.birthday, 'জন্মদিবস': SpecialKind.birthday, 'birthday': SpecialKind.birthday,
  'বিবাহবার্ষিকী': SpecialKind.anniversary, 'বিবাহ বার্ষিকী': SpecialKind.anniversary, 'বিয়ের দিন': SpecialKind.anniversary,
  'বিয়েবার্ষিকী': SpecialKind.anniversary, 'বিয়ে বার্ষিকী': SpecialKind.anniversary, 'anniversary': SpecialKind.anniversary,
  'মৃত্যুবার্ষিকী': SpecialKind.deathday, 'মৃত্যু বার্ষিকী': SpecialKind.deathday, 'মৃত্যুদিবস': SpecialKind.deathday, 'মৃত্যুদিন': SpecialKind.deathday,
  'মৃত্যু দিবস': SpecialKind.deathday, 'death anniversary': SpecialKind.deathday,
};

/// (day, month, year) written in [text] (already normalised): "১২ মার্চ",
/// "১২ই মার্চ ১৯৯০", "12/3", "১২-০৩-১৯৯০".
(int, int, int?)? dayMonthIn(String text) {
  final num = RegExp(r'(\d{1,2})[/.-](\d{1,2})(?:[/.-](\d{2,4}))?').firstMatch(text);
  if (num != null) {
    final d = int.parse(num[1]!), m = int.parse(num[2]!);
    var y = num[3] == null ? null : int.parse(num[3]!);
    if (y != null && y < 100) y += y > 30 ? 1900 : 2000;
    if (d >= 1 && d <= 31 && m >= 1 && m <= 12) return (d, m, y);
  }
  final w = text.split(' ');
  for (var i = 0; i < w.length; i++) {
    final m = _months[w[i]];
    if (m == null) continue;
    int? day;
    for (final j in [i - 1, i + 1]) {
      if (j < 0 || j >= w.length) continue;
      final dm = RegExp(r'^(\d{1,2})(?:ই|শে|লা|রা|ঠা|তারিখ|th|st|nd|rd)?$').firstMatch(w[j]);
      if (dm != null) {
        day = int.parse(dm[1]!);
        break;
      }
    }
    if (day == null || day < 1 || day > 31) continue;
    int? year;
    for (final x in w) {
      final ym = RegExp(r'^(19|20)\d\d(?:সালে?|সন)?$').firstMatch(x);
      if (ym != null) year = int.parse(x.substring(0, 4));
    }
    return (day, m, year);
  }
  return null;
}

/// "রহিমের জন্মদিন ১২ মার্চ" → a [SpecialAdd]; questions ("কবে?") are not.
SpecialAdd? specialDayIn(String said, String text, {DateTime? now}) {
  if (said.contains('?') || text.contains('কবে') || text.contains('when')) return null;
  SpecialKind? kind;
  var at = -1, len = 0;
  for (final e in _specialKinds.entries) {
    final k = fold(e.key);
    final i = text.indexOf(k);
    if (i >= 0 && (kind == null || k.length > len)) {
      kind = e.value;
      at = i;
      len = k.length;
    }
  }
  if (kind == null) return null;
  var date = dayMonthIn(text);
  // "৩১ তারিখে তুবার জন্মদিন": a day of the month only — the next such day.
  // (Not when a month is named in any spelling: that month, never a guess.)
  final monthSaid = text.split(' ').any((w) => _months.keys.any((m) => m.length > 2 && w.startsWith(m)));
  if (date == null && now != null && !monthSaid) {
    final dm = RegExp(r'(?:^|\s)(\d{1,2})(?:ই|শে|লা|রা|ঠা)?\s*' + fold('তারিখ')).firstMatch(text);
    final day = dm == null ? null : int.parse(dm[1]!);
    if (day != null && day >= 1 && day <= 31) {
      for (var i = 0; i < 13; i++) {
        final m = DateTime(now.year, now.month + i);
        final last = DateTime(m.year, m.month + 1, 0).day;
        if (day > last) continue;
        if (i == 0 && day < now.day) continue;
        date = (day, m.month, null);
        break;
      }
    }
  }
  if (date == null) return null;
  final before = text.substring(0, at).trim().split(' ').where((x) => x.isNotEmpty).toList();
  var person = '';
  if (before.isNotEmpty) {
    final last = before.last;
    person = last == 'আমার' || last == 'আমাদের' ? last : stripPossessive(last);
    if (before.length >= 2 && _honorifics.contains(person) && _looksLikeName(before[before.length - 2])) person = '${before[before.length - 2]} $person';
  }
  if (person.isEmpty || RegExp(r'^\d').hasMatch(person) || _months.containsKey(person)) person = kind == SpecialKind.anniversary ? 'আমাদের' : '';
  if (person.isEmpty) return null;
  // Keep the user's own spelling of the name.
  final orig = RegExp(RegExp.escape(person), caseSensitive: false).firstMatch(said);
  // A clock time said with a part of the day ("সকাল ১১টায়") is the ring
  // time; a bare hour is left to the usual morning ring.
  final w = parseWhen(said, DateTime(2000, 1, 1));
  final timed = w != null && w.hasTime && !hourOpen(said, w.at.hour);
  return SpecialAdd(said, person: orig?.group(0) ?? person, kind: kind, month: date.$2, day: date.$1, year: date.$3, hour: timed ? w.at.hour : null, minute: timed ? w.at.minute : 0);
}

const _relations = [
  'ভাই', 'বোন', 'শ্যালক', 'শালা', 'শালী', 'বাবা', 'আব্বা', 'মা', 'আম্মা', 'স্ত্রী', 'বউ', 'স্বামী', 'ছেলে', 'মেয়ে', 'বন্ধু', 'বস',
  'ম্যানেজার', 'চাচা', 'মামা', 'খালা', 'ফুপু', 'দুলাভাই', 'ভাবি', 'শ্বশুর', 'শাশুড়ি', 'নানা', 'নানি', 'দাদা', 'দাদি', 'ভাগ্নে', 'ভাতিজা',
  'কলিগ', 'সহকর্মী', 'ড্রাইভার', 'কাজের লোক', 'বাড়িওয়ালা', 'ডাক্তার', 'উকিল', 'পার্টনার', 'কাস্টমার',
];

/// Something about the user or their people, not a plain fact to look up:
/// "রহিম আমার শ্যালক", "আমি শুক্রবার অফিস করি না", "আমি চা খাই না".
bool isAboutMe(String text) {
  final t = fold(text.toLowerCase());
  if (RegExp(r'(^|\s)আমার\s+(' + _relations.map(fold).join('|') + r')(\s|$|।)').hasMatch(t) && !t.contains('নম্বর')) return true;
  if (RegExp(r'(^|\s)আমি\s').hasMatch(t) &&
      RegExp(r'(করি|করিনা|থাকি|খাই|পছন্দ|ভালোবাসি|পারি|যাই|উঠি|ঘুমাই|পড়ি|চাই)(\s|$|।|না)').hasMatch(t)) {
    return true;
  }
  return false;
}

// ───────────────────────── The parser ─────────────────────────

class Parser {
  Parser({required this.ledger, this.tasks = const [], this.contacts = const [], this.folders = const [], DateTime? now, this.data}) : now = now ?? DateTime.now();

  /// Everything saved (accounts, goals, medicines, habits, family…), so a
  /// menu request is read against the user's own names. Null in tests that
  /// pass only a ledger.
  final AppData? data;

  /// The user's paper folders and note categories, so "অফিসের ফোল্ডার খোলো" finds them.
  final List<FolderHint> folders;

  /// Current entries, to resolve names and judge which meaning is likely.
  final List<LedgerEntry> ledger;

  /// To-dos, so "ব্যাংকের কাজ হয়ে গেছে" can find the one meant.
  final List<Task> tasks;
  final List<Contact> contacts;
  final DateTime now;

  /// What [said] asks for, checked against the shared rules ([checked])
  /// that every way in — these rules or the AI — goes through.
  Command parse(String said) => checked(_parse(said), said, now);

  Command _parse(String said) {
    // "কাল eight pm-এ …": English times read as Bengali ones (also for titles).
    said = englishTimes(said);
    // "ইয়ার তুমি একটা কাজ করো তো …", "… একটু বলতো": how people open and
    // close a request, not part of it; "আগামীকালকে" is "কাল".
    final tidied = tidySpeech(said);
    if (tidied.isNotEmpty) said = tidied;
    var text = normalize(said);
    if (text.isEmpty) return NotUnderstood(said);

    // Said to the assistant about the assistant: never data to keep.
    switch (aboutTheAssistant(said)) {
      case AboutMe.listenWhenITalk:
        return SmallTalk(said, kind: Talk.listenOverMe);
      case AboutMe.doYouUnderstand:
        return SmallTalk(said, kind: Talk.understand);
      case AboutMe.complaint:
        return SmallTalk(said, kind: Talk.sorry);
      case null:
        break;
    }

    // The other menus (menus.dart): accounts, savings, medicines, habits,
    // what to keep in mind, settings… read against the user's own names.
    final menu = menuCommand(said, data, now);
    if (menu != null) return menu;

    // The to-do list, by what is wanted (todo.dart): asked, added, done,
    // moved, reminded — before any keyword rule can take a piece of it.
    final todo = todoCommands(said, tasks, now);
    if (todo != null && todo.isNotEmpty) return todo.first;

    // Money said as a plan, a duty, a reminder or a condition ("শুক্রবার
    // দেব", "ফেরত দিতে হবে", "দিতে মনে করিও", "বেতন পেলে দেব") is not a
    // transaction: it never reaches the money book (aspect.dart).
    final notYet = moneyNotNow(said, now);
    if (notYet != null) return notYet;

    // "… এটা একটা কাজের লিস্টে রাখ", "… কাজের তালিকায় লিখে রাখো": a to-do,
    // even when it has a date ("২০ তারিখে") or a time in it.
    final toList = _hasNorm(text, ['কাজের লিস্ট', 'কাজের লিস্টে', 'কাজের তালিকা', 'কাজের তালিকায়', 'কাজের তালিকাতে', 'কাজের তালিকা তে', 'কাজের লিস্টের', 'টুডু', 'টু ডু']);
    // "কাজের তালিকা: বোর্ডে এনআইডি যুক্ত করা লাগবে" — the list, then what to do.
    final mustDo = RegExp(r'\S(তে|তেই) (হবে|লাগবে)( |$)').hasMatch(text) || RegExp(r'\S (করা|কেনা|যাওয়া|আনা|দেওয়া|নেওয়া) (লাগবে|দরকার)( |$)').hasMatch(text);
    // A plain order to write ("… এটা লিখে রাখ") wins over a question word said with it.
    final orderToWrite = _hasNorm(text, ['লিখে রাখ', 'লিখে রাখো', 'লেখ যে', 'লিখো যে', 'তুলে রাখ', 'তুলে রাখো', 'তালিকায় রাখ', 'লিস্টে রাখ', 'লিস্টে রাখো']);
    // "৩০ অক্টোবর বিকেল চারটায় পড়ানো আছে, এটা একটু লিখে রাখো তো": a day or
    // time and an order to write it down — a reminder (with a time) or a to-do.
    final writeIt = RegExp(fold(r'[\s,।]*(?:এটা|এইটা|এটাকে)?\s*(?:একটু\s+)?(?:লিখে\s+(?:রাখো|রাখ|রাখেন|রেখো|দাও|দিও)|লেখো|লিখো|লিখে নাও)(?:\s+তো)?[\s,।!]*$')).firstMatch(fold(said));
    if (writeIt != null && !_hasNorm(text, ['কাজের তালিকা', 'কাজের লিস্ট', 'নোট', 'পাসওয়ার্ড', 'নম্বর', 'নাম্বার']) && findAmount(normalize(withoutWhen(said))) == null) {
      final when = parseWhen(said, now);
      if (when != null && (when.hasDay || when.hasTime)) {
        var body = fold(said).substring(0, writeIt.start);
        body = body.replaceAll(RegExp(fold(r'(?:^|\s)(?:এক|দুই|দু|তিন|চার|পাঁচ|পাচ|ছয়|সাত|আট|নয়|দশ|এগারো|বারো)টায়(?=\s|$)')), ' ');
        var title = tidy(cutWords(withoutWhen(body), ['আমার', 'আমাকে', 'যে', ..._fillers])).replaceAll(RegExp(r'[।.!,]+$'), '').trim();
        if (title.isNotEmpty) {
          if (when.hasTime && when.at.isAfter(now)) return ReminderAdd(said, title: title, at: when.at);
          return TaskAdd(said, title: title, due: when.day);
        }
      }
    }
    // "একটা কাজ যুক্ত করো যে আমাকে X" — the to-do is what follows "যে".
    final addTask = RegExp(fold(r'(?:একটা|একটি)?\s*কাজ\s+(?:যুক্ত|যোগ|এড|অ্যাড)\s+(?:করো|কর|করেন|করুন|করে\s+দাও)\s+(?:যে\s+)?(.+)$')).firstMatch(fold(said));
    if (addTask != null) {
      var title = tidy(cutWords(withoutWhen(addTask[1]!), ['আমাকে', 'আমার', ..._fillers])).replaceAll(RegExp(r'[।.!,]+$'), '').trim();
      final when = parseWhen(said, now);
      if (title.isNotEmpty) return _maybeMonthly(said, text, TaskAdd(said, title: title, due: when != null && when.hasDay ? when.day : null));
    }
    // "৩১ শে জানুয়ারিতে যে কাজটা আছে সেটা মুছে দাও": that day's to-dos.
    if (_hasNorm(text, ['কাজ', 'কাজটা', 'কাজগুলো', 'কাজের তালিকা']) && _hasNorm(text, ['মুছে', 'মুছো', 'বাদ দাও', 'বাদ দিয়ে', 'ডিলিট']) && !_hasNorm(text, ['নোট', 'রিমাইন্ডার', 'লেনদেন'])) {
      final w0 = parseWhen(said, now);
      if (w0 != null && w0.hasDay && RegExp(r'\d').hasMatch(normalize(said))) return TasksClear(said, day: dayOnly(w0.day));
    }
    final removing = _hasNorm(text, ['মুছে দাও', 'মুছে দিও', 'মুছে ফেলো', 'মুছো', 'বাদ দাও', 'বাদ দিয়ে দাও', 'ডিলিট', 'কেটে দাও']);
    if (!removing && (!isQuestionText(said) || orderToWrite) && toList && (_hasNorm(text, _addVerbs) || mustDo)) {
      final t = _taskAdd(said, text, words(text));
      if (t != null) return t;
    }

    // "রহিমকে পাঁচশ টাকা, না সাতশ টাকা দিলাম": the speaker changed their
    // mind mid-sentence — the later value counts.
    final fixed = applySelfCorrection(text);
    if (fixed != text) {
      final c = parse(fixed);
      if (c is LedgerAdd || c is LedgerSet || c is CashAdd || c is ReminderAdd || c is TaskAdd) return c;
    }

    // "মুছে দিও না", "রিমাইন্ডার বন্ধ কোরো না": a request in the negative —
    // nothing is done (never read as "মুছে দাও").
    if (!isQuestionText(said) && negatedRequest(text)) return SmallTalk(said, kind: Talk.wontDo);

    // "নোট খোলো", "সেটিংসে যাও", "প্রেসক্রিপশন ফোল্ডার দেখাও" (before the
    // to-do list question: "কাজের তালিকা খোলো" opens the page).
    final open = _open(said, text);
    if (open != null) return open;

    // "বাদ দাও" alone, with nothing waiting: nothing to cancel, nothing deleted.
    if (isCancel(said)) return SmallTalk(said, kind: Talk.cancelled);

    // "শেষ করা কাজগুলো সরাও": only the ticked ones, asked once.
    if (_hasNorm(text, ['শেষ করা কাজ', 'শেষ হওয়া কাজ', 'সম্পন্ন কাজ', 'করা হয়ে গেছে এমন কাজ', 'টিক দেওয়া কাজ']) && _hasNorm(text, ['সরাও', 'মুছে', 'মুছো', 'বাদ দাও', 'ডিলিট', 'ক্লিয়ার', 'সরিয়ে'])) {
      return TasksClear(said, doneOnly: true);
    }
    // "রিমাইন্ডারটা মুছে দাও", "রহিমের লেনদেন ৫০০ না ৬০০", "শেষটা ডিলিট করো".
    // "আজকের যতগুলো কাজ আছে সবগুলো বাদ দিয়ে দাও": all of them, not one.
    if (_hasNorm(text, ['সব', 'সবগুলো', 'সবগুলা', 'সবকটা', 'সবকটাকে', 'সবকয়টা', 'সবটা', 'যতগুলো', 'যতগুলা', 'সমস্ত']) &&
        _hasNorm(text, ['কাজ', 'কাজের তালিকা', 'কাজের লিস্ট', 'টুডু']) &&
        _hasNorm(text, ['মুছে', 'মুছো', 'বাদ দাও', 'বাদ দিয়ে', 'বাদ দিও', 'ডিলিট', 'কেটে দাও', 'ক্লিয়ার'])) {
      final w0 = parseWhen(said, now);
      return TasksClear(said, day: w0 != null && w0.hasDay ? dayOnly(w0.day) : null);
    }
    var manage = manageAction(text);
    // "অ্যালার্ম বন্ধ করো" with no name: the alarm/reminder page, to choose there.
    if (manage == 'stop' && !namesSomething(text)) manage = null;
    if (manage != null && (kindNamed(text) != null || asksForLast(text) || manage == 'delete' || RegExp(r'\d+ (না|নয়|নয়|নই),? \d+').hasMatch(text) || isCorrection(text))) {
      return ManageItem(said, action: manage);
    }

    // "এ মাসে কী কী লেনদেন হলো?", "আমার কত টাকা?": money records by
    // period, or a question that needs one more word from the user.
    final moneyAsk = _moneyQuestion(said, text);
    if (moneyAsk != null) return moneyAsk;

    // "নামাজের সময় কখন?", "কাল কী আছে?", "আমার ব্যালেন্স কত?", "কী কী ওষুধ চলছে?"
    // "আজ নামাজের সময় দাও", "সেহরির সময় বলো": asked as a request.
    final topic = infoTopic(text);
    if (topic != null && (isQuestionText(said) || (const {'prayer', 'sehri', 'iftar', 'sunrise', 'sunset', 'ramadan', 'zakat', 'savings', 'expiry', 'notes', 'special'}.contains(topic) && asksToShow(text)))) {
      return ProfileQuery(said);
    }

    // "আজ আমার কী কী আছে?", "কাজের তালিকা দেখাও" (before small talk:
    // "আজ কী কী করতে হবে" is not "what can you do").
    final day = _dayQuestion(said, text);
    if (day != null) return day;

    // "আমার সংরক্ষিত ফোন নম্বরগুলো দেখাও" — show what is kept, save nothing.
    if (_contactList(text)) return ContactsQuery(said);

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

    final opened = _open(said, text);
    if (opened != null) return opened;

    // "পিডিএফ দাও", "সব তথ্যের PDF বানাও": the PDF picker.
    if (_hasNorm(text, const ['পিডিএফ', 'pdf', 'পিডিএফে', 'পিডিএফ-এ']) && !isQuestionText(said)) return OpenPlace(said, place: 'pdf');

    // "কাল ভোর ৫টায় অ্যালার্ম দাও", "৬টায় ঘুম থেকে ডেকে দিও", "এলার্ম সেট করো ৭টা ৩০".
    final alarm = _alarm(said, text);
    if (alarm != null) return alarm;

    // "আমার ব্লাড গ্রুপ বি পজিটিভ" (keep) / "আমার ব্লাড গ্রুপ কী?" (answer);
    // "আমার কী কী ছবি আছে?" (what kind of things are kept).
    if (mentionsBlood(text)) {
      final g = bloodIn(text);
      if (g != null && !isQuestionText(said)) return ProfileSet(said, field: 'blood', value: g, who: whoseIn(text));
      return ProfileQuery(said);
    }
    if (kindAsked(text) != null && (isQuestionText(said) || _hasNorm(text, ['আছে']))) return ProfileQuery(said);
    // "আমার উচ্চতা কত?", "আমার বয়স কত?", "আমার উচ্চতা ৫ ফুট ৬ ইঞ্চি".
    final field = profileField(text);
    if (field != null) {
      if (field == 'height' && !isQuestionText(said)) {
        final cm = heightIn(text);
        if (cm != null) return ProfileSet(said, field: 'height', value: cm.toStringAsFixed(1), who: whoseIn(text));
      }
      if (isQuestionText(said)) return ProfileQuery(said);
    }

    // "প্রেশার ১৪০ বাই ৯০", "আজ ওজন ৬৮ কেজি", "আমার বিএমআই কত?"
    final health = _health(said, text, w);
    if (health != null) return health;

    // "রহিমের জন্মদিন ১২ মার্চ" → a special day.
    final special = specialDayIn(said, text, now: now);
    if (special != null) return special;

    // "মনে রাখো: …" → a note.
    final noteMatch = RegExp(r'^(মনে রাখো|মনে রেখো|মনে রাখ|নোট রাখো|নোট করো|নোট কর|লিখে রাখো|লিখে রাখ)\s*(যে)?\s*(.*)$').firstMatch(text);
    if (noteMatch != null && (noteMatch[3] ?? '').trim().isNotEmpty) {
      // Keep the user's own spelling and digits.
      final original = said.trim().replaceFirst(RegExp(r'^\S+\s+\S+\s*[:ঃ,-]?\s*(যে\s+)?'), '');
      final noteText = original.isEmpty ? noteMatch[3]!.trim() : original;
      // Money always goes to লেনদেন, even when said as "মনে রাখো …".
      final inner = parse(noteText);
      if (inner is LedgerAdd || inner is LedgerSet || inner is TaskAdd || inner is ReminderAdd || inner is ContactAdd || inner is SpecialAdd) return inner;
      if (isAboutMe(noteText)) return MemoryAdd(said, text: noteText);
      return NoteAdd(said, text: noteText);
    }

    // Calls, messages, phone numbers, timed reminders, ticking off to-dos.
    final act = _assistant(said, text, w);
    if (act != null) return act;

    final amount = findAmount(text);
    final known = knownPeople(ledger);
    final asking = isQuestionText(said);

    // "ফেসবুকের পাসওয়ার্ড ১২২৩৯৯৩৯": a login to keep (before any money rule
    // reads the digits as an amount).
    if (!asking && _hasAny(text, _vaultWords)) {
      final add = vaultAddFrom(said);
      if (add != null) return add;
    }

    // Projects and own income/spending.
    final cash = _cashSentence(said, text, w, amount, asking);
    if (cash != null) return cash;

    // "ইসমাইলের কাছে আমি ৫ হাজার টাকা পাই" — a stated balance.
    if (amount != null && !asking) {
      final set = _statedBalance(said, text, w, amount, known);
      if (set != null) return set;
    }

    // "আয়-ব্যয়ের হিসাব দাও / চাই / কত?": the span's income and spending —
    // never the people's balances (their "হিসাব" is a different book).
    if (text.contains(normalize('আয়-ব্যয়')) && !_hasNorm(text, const ['তালিকা', 'লিস্ট', 'লেনদেন', 'পাওনা', 'দেনা', 'ধার'])) return CashQuery(said);

    // A question about money.
    final isQuestion = (asking && asksAboutOwing(text)) || _hasAny(text, ['কত', 'কাকে', 'কার কাছে', 'কে কে', 'হিসাব', 'কবে']) &&
        (_hasAny(text, ['পাওনা', 'পাব', 'পাবো', 'পাবে', 'পাই', 'দেনা', 'দিতে হবে', 'দেব', 'দেবো', 'বাকি', 'ধার', 'হিসাব', 'লেনদেন']) ||
            // "গত মাসে রহিমকে কত দিলাম?" — what passed between us, in a span of time.
            (text.contains('কত') && _hasAny(text, [..._give1, ..._take1, ..._got1, 'ফেরত'])));
    if (isQuestion) return _ledgerQuestion(said, text, w, known);

    // Vault: logins, passwords, Wi-Fi.
    final wifi = _hasAny(text, ['wi-fi', 'wifi', 'ওয়াইফাই', 'ওয়াইফাই', 'ওয়াই-ফাই', 'ওয়াই ফাই']);
    if (wifi || _hasAny(text, _vaultWords)) {
      return VaultQuery(said, terms: wifi ? const [] : searchTerms(text), wifiOnly: wifi);
    }

    // Dates and reminders.
    // ("২৩ তারিখে দাওয়াত আছে" tells a date — not a question about one.)
    if (_hasAny(text, ['মনে করিয়ে', 'মনে করিয়ে', 'মনে করাও', 'রিমাইন্ডার', 'তারিখ', 'কবে', 'মেয়াদ', 'মেয়াদ']) &&
        (asking || _hasAny(text, ['রিমাইন্ডার', 'মনে করাও', 'কবে', 'মনে করিয়ে', 'মনে করিয়ে']))) {
      return ReminderQuery(said, terms: searchTerms(text));
    }

    // "কাল রহিমকে ৫০০ টাকা দেবো": money promised for a day is a to-do, not a payment made.
    if (!asking && amount != null) {
      final when = parseWhen(said, now);
      final promise = w.any((x) => const ['দেবো', 'দেব', 'দিবো', 'দিব', 'পাঠাবো', 'পাঠাব', 'শোধ করবো', 'শোধ করব', 'ফেরত দেবো'].map(normalize).contains(x));
      // "ইমরান আজ ১৫০০০ টাকা দিবে": someone else will pay — a plan to
      // remember, not money that moved (and never "who?" asked again).
      final theyWill = w.any((x) => const ['দিবে', 'দেবে', 'দিবেন', 'দেবেন', 'দিবা', 'পাঠাবে', 'পাঠাবেন', 'দিয়ে দিবে', 'ফেরত দিবে'].map(normalize).contains(x));
      if (theyWill) {
        final title = tidy(cutWords(said, ['আগামীকাল', 'আগামী কাল', 'কাল', 'আজকে', 'আজ', 'পরশু', ..._fillers]))
            .replaceAll(RegExp(r'[।.!]+$'), '')
            .trim();
        if (title.isNotEmpty) {
          return when != null && when.hasTime && when.at.isAfter(now) && !hourOpen(said, when.at.hour)
              ? ReminderAdd(said, title: title, at: when.at)
              : TaskAdd(said, title: title, due: when != null && when.hasDay ? when.day : null);
        }
      }
      if (when != null && when.hasDay && promise) {
        // Day words only: withoutWhen would read "৫০০ টা(কা)" as a clock time.
        final title = tidy(cutWords(said, ['আমি', 'আগামীকাল', 'আগামী কাল', 'কাল', 'আজকে', 'আজ', 'পরশু', 'সকালে', 'বিকেলে', 'রাতে', 'দুপুরে', 'সন্ধ্যায়', ..._fillers]))
            .replaceAll(RegExp(r'[।.!]+$'), '')
            .trim();
        if (title.isNotEmpty) return when.hasTime && when.at.isAfter(now) ? ReminderAdd(said, title: title, at: when.at) : TaskAdd(said, title: title, due: when.day);
      }
    }

    // "সজীবকে টাকা দিইনি", "সে ফেরত দেয়নি": nothing happened — never a transaction.
    if (!asking && _negatedMoney(text)) return SmallTalk(said, kind: Talk.nothingDone);

    // "সজীবের আর কোনো টাকা বাকি নেই": tell what the book says; settle only when asked.
    if (!asking && _hasNorm(text, const ['বাকি নেই', 'পাওনা নেই', 'দেনা নেই', 'কিছু বাকি নেই', 'আর কিছু পাই না', 'আর কিছু পাবো না'])) {
      for (final k in known) {
        if (text.contains(normalize(k))) return LedgerQuery(said, ask: LedgerAsk.person, person: k);
      }
    }

    // A money event.
    if (amount != null) {
      final add = _ledgerEvent(said, text, w, amount, known);
      if (add != null) return _dated(add, text);
    }

    // Anything else about money (টাকা) also belongs in লেনদেন, never in a
    // note category. Missing person or amount: the app asks for them.
    final money = _hasAny(text, ['টাকা']) || said.contains('৳') || w.contains('tk');
    if (money && !asking) {
      if (amount == null) {
        final add = _ledgerEvent(said, text, w, 0, known);
        if (add != null) return _dated(add, text);
      }
      // No one owes anything: own spending or income ("বিদ্যুৎ বিল ১২০০ টাকা দিলাম").
      final kind = cashKindOf(text);
      if (kind != null && amount != null && amount > 0 && !_hasAny(text, [..._loanWords, ..._returnWords])) {
        return CashAdd(said, kind: kind, amount: amount, category: categoryFor(text, kind));
      }
      return _moneyEvent(said, text, w, amount ?? 0, known);
    }

    // "কাল ব্যাংকে যেতে হবে", "বাজারের লিস্টে ডিম রাখো" → a to-do.
    if (!asking) {
      final task = _taskAdd(said, text, w);
      if (task != null) return task;
      // "আমি কাল বাজারে যাবো", "পরশু ডাক্তারের অ্যাপয়েন্টমেন্ট আছে": a plan
      // for a day is a to-do on that day (with a clock time, a reminder).
      final plan = _plan(said, text, w);
      if (plan != null) return plan;
    }

    // "প্রতিদিন রাত ১০টায় ওষুধ", "রাত ৯টায় ওষুধ খাওয়া": a clock time and a
    // thing, said short — a reminder, even without "মনে করিয়ে দিও".
    if (!asking && w.length <= 7 && !text.contains(normalize('মনে করিয়ে'))) {
      final when = parseWhen(said, now);
      if (when != null && when.hasTime) {
        final r = parse('$said মনে করিয়ে দিও');
        if (r is ReminderAdd && r.title.trim().isNotEmpty) return r;
      }
    }

    // A money question the rules could not place: never answered with a
    // text match (a phone number, a note) — ask which money is meant.
    if (asking && w.any((x) => const ['টাকা', 'টাকার', 'লেনদেন', 'খরচ', 'আয়', 'পাওনা', 'দেনা', 'হিসাব', 'ব্যালেন্স'].map(normalize).contains(x) || x.startsWith(normalize('লেনদেন')))) {
      return Clarify(said, question: 'টাকার কোন হিসাব জানতে চান?', options: [
        ('এ মাসের আয়-খরচ', CashQuery(said)),
        ('মানুষের কাছে পাওনা', LedgerQuery(said, ask: LedgerAsk.receivable)),
        ('আমার দেনা', LedgerQuery(said, ask: LedgerAsk.payable)),
        ('এ মাসের সব লেনদেন', MoneyListQuery(said, from: DateTime(now.year, now.month), to: DateTime(now.year, now.month + 1), label: 'এই মাসে')),
      ]);
    }
    final terms = searchTerms(text);
    if (terms.isEmpty) return NotUnderstood(said);
    // A plain fact, not a question: keep it (in a matching or new category).
    // Talk addressed to the assistant ("তুমি …", "তোমাকে …") is not a fact
    // about the user's life to file away.
    final toYou = w.any((x) => const ['তুমি', 'তোমার', 'তোমাকে', 'তুই', 'তোর', 'তোরে'].map(normalize).contains(x));
    if (!asking && w.length >= 3 && !toYou) return NoteAdd(said, text: said.trim(), fromStatement: true);
    return SearchQuery(said, terms: terms);
  }

  /// Money records for a span of time, or an unclear money question. Null
  /// when the sentence is something else.
  Command? _moneyQuestion(String said, String text) {
    final w = words(text);
    final asking = isQuestionText(said) || _hasNorm(text, const ['দেখাও', 'দেখান', 'তালিকা', 'লিস্ট', 'বলো', 'বলুন']);
    if (!asking) return null;
    final known = knownPeople(ledger);
    // "আমার কত টাকা?" / "আমার কত টাকা আছে?": balance, income or what others
    // owe? Ask instead of guessing.
    const plain = {'আমার', 'কত', 'টাকা', 'আছে', 'এখন', 'মোট', 'সব', 'আচ্ছা', 'তো', 'আমি', 'হাতে', 'বলো', 'বলুন'};
    if (w.contains(normalize('টাকা')) && w.contains(normalize('কত')) && w.every((x) => plain.map(normalize).contains(x)) && !w.contains(normalize('হাতে'))) {
      final now = this.now;
      return Clarify(said, question: 'কোনটা জানতে চান?', options: [
        ('এ মাসের আয়-খরচ', CashQuery(said)),
        ('মানুষের কাছে পাওনা', LedgerQuery(said, ask: LedgerAsk.receivable)),
        ('আমার দেনা', LedgerQuery(said, ask: LedgerAsk.payable)),
        ('এ মাসের সব লেনদেন', MoneyListQuery(said, from: DateTime(now.year, now.month), to: DateTime(now.year, now.month + 1), label: 'এই মাসে')),
      ]);
    }
    // "আয়-ব্যয়ের হিসাব দাও", "আয়-ব্যয় কত?": the summary of the span (this
    // month unless said); a list only when one is asked for.
    if (w.contains(normalize('আয়-ব্যয়')) && !_hasNorm(text, const ['তালিকা', 'লিস্ট', 'লেনদেন', 'গুলো']) && owedToMe(text) == null) return CashQuery(said);
    final records = w.any((x) => x.startsWith(normalize('লেনদেন')) || x == normalize('আয়-ব্যয়') || x == normalize('আয়ব্যয়') || x == 'transaction' || x == 'transactions') ||
        (w.any((x) => x == normalize('খরচগুলো') || x == normalize('আয়গুলো') || x == normalize('খরচের') && _hasNorm(text, const ['তালিকা', 'লিস্ট'])));
    if (!records) return null;
    // "আমার পাওনা লেনদেন কত?" is about who owes whom.
    if (owedToMe(text) != null) return null;
    String? person;
    for (final k in known) {
      if (text.contains(normalize(k))) person = k;
    }
    // "রহিমের সাথে লেনদেন কত?": one person's account (with its own periods).
    if (person != null) return null;
    final period = periodIn(text, now) ?? (DateTime(now.year, now.month), DateTime(now.year, now.month + 1), 'এই মাসে');
    String? category;
    for (final c in knownCategoryWords) {
      if (w.contains(normalize(c)) || w.contains(normalize('$cের')) || w.contains(normalize('$cএর'))) category = c;
    }
    final other = w.contains(normalize('অন্যান্য'));
    MoneyListQuery q({String? cat}) => MoneyListQuery(said, from: period.$1, to: period.$2, label: period.$3, category: cat, person: person);
    // "অন্যান্য লেনদেন": the খাত "অন্যান্য", or all the others? Ask.
    if (other && category == null) {
      return Clarify(said, question: 'অন্যান্য খাতের লেনদেন, নাকি ${period.$3.replaceFirst('এই মাসে', 'এই মাসের').replaceFirst('গত মাসে', 'গত মাসের')} সব লেনদেন দেখতে চান?', options: [
        ('অন্যান্য খাতের', q(cat: 'অন্যান্য')),
        ('সব লেনদেন', q()),
      ]);
    }
    return q(cat: category);
  }

  /// "দিইনি", "দেইনি", "দেই নাই", "পাইনি", "নেইনি", "দেয়নি": a money verb said in the negative.
  bool _negatedMoney(String text) {
    final ws = words(text);
    const neg = ['দিইনি', 'দেইনি', 'দিনি', 'দেইনাই', 'দেয়নি', 'দেয়নি', 'দেয়নাই', 'দেননি', 'দিলাম না', 'দিই নাই', 'দেই নাই', 'দেই নি', 'দেয় নাই', 'দেয় নি', 'দিল না', 'দিলো না',
      'নিইনি', 'নেইনি', 'নেই নাই', 'নিলাম না', 'নেয়নি', 'নেয়নি', 'পাইনি', 'পাই নাই', 'পাইনাই', 'পেলাম না', 'করিনি', 'শোধ করিনি', 'শোধ করেনি', 'ফেরত দেয়নি'];
    final money = ws.contains(normalize('টাকা')) || findAmount(text) != null || _hasAny(text, [..._loanWords, ..._returnWords]);
    return money && _hasNorm(text, neg);
  }

  /// The day a money event happened, when one is said: "আজ", "গতকাল",
  /// "কাল/পরশু" with a past verb (= yesterday / the day before), a weekday
  /// (the last one), or "১০ তারিখে" (this month, or last month if still ahead).
  LedgerAdd _dated(LedgerAdd a, String text) {
    final ws = words(text);
    final today = DateTime(now.year, now.month, now.day);
    DateTime? d;
    if (ws.contains(normalize('গতকাল')) || ws.contains(normalize('গতকালকে'))) {
      d = today.subtract(const Duration(days: 1));
    } else if (ws.contains(normalize('গত পরশু')) || text.contains(normalize('গত পরশু'))) {
      d = today.subtract(const Duration(days: 2));
    } else if (ws.contains(normalize('কাল')) || ws.contains(normalize('কালকে'))) {
      d = today.subtract(const Duration(days: 1)); // a payment already made: yesterday
    } else if (ws.contains(normalize('পরশু'))) {
      d = today.subtract(const Duration(days: 2));
    } else {
      for (var k = 0; k < 7 && d == null; k++) {
        final stem = normalize(bnWeekdays[k].replaceAll('বার', ''));
        if (ws.any((x) => x.startsWith('$stem${normalize('বার')}'))) {
          var back = (now.weekday - (k + 1)) % 7;
          if (back == 0) back = 7;
          d = today.subtract(Duration(days: back));
        }
      }
      final m = RegExp(r'(\d{1,2}) ' + normalize('তারিখ')).firstMatch(text);
      if (d == null && m != null) {
        final day = int.parse(m[1]!);
        if (day >= 1 && day <= 31) {
          var c = DateTime(now.year, now.month, day);
          if (c.isAfter(today)) c = DateTime(now.year, now.month - 1, day);
          d = c;
        }
      }
    }
    if (d == null || d == today) return a;
    return LedgerAdd(a.transcript, person: a.person, amount: a.amount, kind: a.kind, options: a.options, suggested: a.suggested, allowExpense: a.allowExpense, date: d);
  }

  OpenPlace? _open(String said, String text) {
    final o = openRequest(text, folders: [...folders, for (final e in docFolderWords.entries) FolderHint('docs', e.key, e.value)]);
    return o == null ? null : OpenPlace(said, place: o.$1, folder: o.$2?.name);
  }

  /// "X-এর কাছে আমি N টাকা পাই / আমার N টাকা পাওনা" → they owe me N.
  /// "X আমার কাছে N টাকা পায় / X-কে আমার N টাকা দিতে হবে / X-এর কাছে আমার
  /// N টাকা দেনা" → I owe them N.
  LedgerSet? _statedBalance(String said, String text, List<String> w, int amount, List<String> known) {
    // "…ঋণ নিয়েছি", "…ধার দিলাম": something happened — an entry, not a stated balance.
    if (verbPerson(text).me && !_hasAny(text, ['দিতে হবে', 'দিতে বাকি', 'দিতে লাগবে'])) return null;
    final iOweWords = _hasAny(text, ['দেনা', 'ঋণ', 'দিতে হবে', 'দেব', 'দেবো', 'দিব', 'দিবো', 'দিতে বাকি', 'দিতে লাগবে', 'দেওয়া লাগবে']);
    final owedWords = _hasAny(text, ['পাই', 'পাব', 'পাবো', 'পাওনা', 'পাবে', 'পাবেন', 'পায়', 'পান']);
    if (!iOweWords && !owedWords) return null;
    // "পাই", "পাবো", "দেবো" are said by the user about themself.
    final me = w.contains('আমি') || w.contains('আমার') || w.any((x) => const ['পাই', 'পাব', 'পাবো'].map(normalize).contains(x));
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
    // "X-এর কাছে ধার নিলাম" means the same as "X-এর কাছ থেকে".
    if (from < 0 && w.contains('কাছে') && (_hasAny(text, _take1) || (loan && _hasAny(text, _got1))) && !w.contains(normalize('আমাকে'))) {
      from = w.indexOf('কাছে') + 1;
    }
    if (from > 0 && _hasAny(text, [..._take1, ..._got1])) {
      var at = from - 1;
      if (at < w.length && (w[at] == 'কাছ' || w[at] == 'কাছে')) at--;
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

    final person = verbPerson(text);
    // "করিমের ধার ২০০ টাকা শোধ করলাম", "করিমের টাকা ফেরত দিয়ে দিলাম": I paid back.
    if (ret && person.me && !w.contains(normalize('আমাকে')) && !w.any((x) => x.endsWith('কে') && x != normalize('আমাকে'))) {
      final name = _anyName(w, known);
      if (name.isNotEmpty) return LedgerAdd(said, person: name, amount: amount, kind: LedgerKind.repaid);
    }

    // 3) "সজীবকে ৫০০ টাকা দিলাম" — I gave them.
    if (_hasAny(text, _give1) || _hasAny(text, ['দিলাম', 'দিয়েছি']) || (ret && person.me)) {
      for (var i = 0; i < w.length; i++) {
        final t = w[i];
        if (t == 'আমাকে' || !(t.endsWith('কে'))) continue;
        final raw = _nameEndingAt(w, i, stripTo);
        if (raw == null) continue;
        final person = resolvePerson(raw, known);
        // "সজীবকে ধার থেকে ২০০ টাকা ফেরত দিলাম": paying back wins over the word ধার.
        if (ret) return LedgerAdd(said, person: person, amount: amount, kind: LedgerKind.repaid);
        if (loan) return LedgerAdd(said, person: person, amount: amount, kind: LedgerKind.lent);
        final iOwe = balanceWith(ledger, person) < 0;
        if (iOwe) {
          return LedgerAdd(said,
              person: person,
              amount: amount,
              options: const [LedgerKind.repaid, LedgerKind.lent],
              suggested: LedgerKind.repaid,
              allowExpense: true);
        }
        // A plain "দিলাম" may be a loan, paying back, or a payment that is
        // not owed back: never guess, ask (ধার is offered first).
        return LedgerAdd(said,
            person: person, amount: amount, options: const [LedgerKind.lent, LedgerKind.repaid], suggested: LedgerKind.lent, allowExpense: true);
      }
    }

    // "সজীব সেই ধার থেকে ৩০০ টাকা ফেরত দিল", "করিম ৫০০ টাকা শোধ করেছে" —
    // they paid me back (said about them, not "আমি").
    if (ret && !w.contains(normalize('আমি')) && person.other && !person.me) {
      var person = '';
      for (final k in known) {
        if (text.contains(normalize(k))) {
          person = k;
          break;
        }
      }
      if (person.isEmpty && w.isNotEmpty && _looksLikeName(w.first)) person = resolvePerson(w.first, known);
      if (person.isNotEmpty) return LedgerAdd(said, person: person, amount: amount, kind: LedgerKind.received);
    }

    // "রহিম আরও ২০০ টাকা নিয়েছে", "করিম আমার কাছ থেকে ৫০০ টাকা ধার নিল" —
    // someone else took money from me: a loan to them (or, when I owe
    // them, maybe paying them back — then ask).
    final theyTook = _hasNorm(text, const ['নিয়েছে', 'নিল', 'নিলো', 'নিছে', 'নিয়েছেন', 'নিলেন', 'নিয়ে গেছে', 'নিয়ে গেল', 'নিয়ে গেলো']) &&
        !w.contains(normalize('আমি')) && !_hasAny(text, [..._take1, ..._give1]);
    if (theyTook) {
      var person = '';
      for (final k in known) {
        if (text.contains(normalize(k))) {
          person = k;
          break;
        }
      }
      if (person.isEmpty && w.isNotEmpty) {
        final first = stripPossessive(w.first);
        if (_looksLikeName(first) && first.length >= 2 && !_notNames.contains(first)) person = resolvePerson(first, known);
      }
      if (person.isNotEmpty) {
        if (ret) return LedgerAdd(said, person: person, amount: amount, kind: LedgerKind.repaid);
        if (loan || balanceWith(ledger, person) >= 0) return LedgerAdd(said, person: person, amount: amount, kind: LedgerKind.lent);
        return LedgerAdd(said, person: person, amount: amount, options: const [LedgerKind.repaid, LedgerKind.lent], suggested: LedgerKind.repaid, allowExpense: true);
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

  /// "রহিম ভবন প্রজেক্টে ৫০ হাজার টাকা এলো", "এই মাসে কত খরচ হলো?",
  /// "বাজারে ৫০০ টাকা খরচ হলো".
  Command? _cashSentence(String said, String text, List<String> w, int? amount, bool asking) {
    final projectAt = w.indexWhere((x) => _projectWords.any((p) => x.startsWith(p)));
    if (projectAt >= 0) {
      final name = _projectName(w, projectAt);
      if (asking) return CashQuery(said, project: name);
      if (amount != null && amount > 0) {
        final kind = cashKindOf(text) ?? CashKind.expense;
        return CashAdd(said, kind: kind, amount: amount, category: categoryFor(text, kind), project: name);
      }
      return null;
    }
    if (asking && _hasNorm(text, ['খরচ', 'আয়', 'ইনকাম', 'সঞ্চয়', 'সেভিংস', 'জমলো', 'জমেছে']) && !_hasNorm(text, ['পাওনা', 'দেনা', 'ধার', 'বাকি'])) {
      return CashQuery(said);
    }
    // Spending/income words with an amount and nobody named as owing:
    // "বাজারে ৫০০ টাকা খরচ হলো", "বেতন পেলাম ৩০ হাজার".
    if (!asking && amount != null && amount > 0 && _hasNorm(text, ['খরচ', 'কিনলাম', 'কিনেছি', 'বেতন', 'আয়', 'ইনকাম', 'বিক্রি', 'রিচার্জ', 'বিল', 'বাজার এনেছি', 'বাজার করেছি', 'বাজার করলাম', 'বাজার আনলাম', 'রেমিট্যান্স'])) {
      final known = knownPeople(ledger);
      final bill = _hasNorm(text, const ['বিল']) && !known.any((k) => text.contains(normalize(k)));
      final namedPerson = w.any((x) => x.endsWith('কে') && !{'আমাকে', 'কাকে'}.contains(x)) ||
          w.any((x) => x == 'কাছে' || x == 'কাছ' || x == 'থেকে') ||
          _hasAny(text, _loanWords) ||
          (!bill && _hasAny(text, _returnWords));
      if (!namedPerson) {
        final kind = cashKindOf(text) ?? CashKind.expense;
        return CashAdd(said, kind: kind, amount: amount, category: categoryFor(text, kind));
      }
    }
    return null;
  }

  /// The one or two words before "প্রজেক্টে": "রহিম ভবন প্রজেক্টে" → "রহিম ভবন".
  String _projectName(List<String> w, int at) {
    const skip = {'আজ', 'আজকে', 'আমার', 'আমাদের', 'এই', 'ওই', 'নতুন', 'সেই', 'কাল', 'গতকাল'};
    final parts = <String>[];
    for (var i = at - 1; i >= 0 && parts.length < 2; i--) {
      final x = w[i];
      if (skip.contains(x) || RegExp(r'^\d').hasMatch(x) || findAmount(x) != null) break;
      parts.insert(0, x);
    }
    if (parts.isEmpty && at + 1 < w.length) {
      final next = stripPossessive(w[at + 1]);
      if (_looksLikeName(next) && !RegExp(r'^\d').hasMatch(next)) parts.add(next);
    }
    return resolvePerson(parts.join(' '), const []);
  }

  // ── The assistant: to-dos, reminders, calls, phone numbers ──

  Command? _dayQuestion(String said, String text) {
    final asking = isQuestionText(said) || _hasNorm(text, ['দেখাও', 'দেখান', 'বলো', 'বলুন', 'শোনাও', 'শোনান']);
    if (_hasNorm(text, _briefingKeys)) return Briefing(said);
    if (_hasNorm(text, _taskListKeys) && (asking || !_hasNorm(text, _addVerbs))) return TaskQuery(said);
    final w = words(text);
    // A question about the day's plan, or about "my tasks", in any words.
    if (isQuestionText(said) && w.any((x) => const ['পরিকল্পনা', 'প্ল্যান', 'শিডিউল', 'রুটিন'].map(normalize).contains(x)) && w.any((x) => const ['আজ', 'আজকের', 'আজকে', 'দিনের'].map(normalize).contains(x))) {
      return Briefing(said);
    }
    if (isQuestionText(said) && w.any((x) => x == normalize('কাজগুলো') || x == normalize('কাজগুলি') || x == normalize('কাজসমূহ')) && !_hasNorm(text, _doneKeys) && findAmount(text) == null) {
      return TaskQuery(said);
    }
    return null;
  }

  /// "প্রতি শুক্রবার", "প্রতি সপ্তাহে রবি আর বুধবার": the weekdays of a
  /// weekly repeat (empty when it is not weekly).
  List<int> _weeklyDays(String text) {
    // "রবিবার থেকে বৃহস্পতিবার", "শনি থেকে বুধ পর্যন্ত": every day of the
    // range, in week order (wrapping past the week's end).
    final stems = [for (var k = 0; k < 7; k++) normalize(bnWeekdays[k].replaceAll('বার', ''))];
    final range = RegExp('(?:^|\\s)(${stems.join('|')})(?:${normalize('বার')})?(?:${normalize('ের')}|${normalize('এর')}|${normalize('দিন')})?\\s+${normalize('থেকে')}\\s+(?:${normalize('প্রতি')}\\s+)?(${stems.join('|')})(?:${normalize('বার')})?').firstMatch(text);
    if (range != null) {
      final a = stems.indexOf(range[1]!), b = stems.indexOf(range[2]!);
      final out = <int>[];
      for (var i = a;; i = (i + 1) % 7) {
        out.add(i + 1);
        if (i == b || out.length == 7) break;
      }
      return out;
    }
    final weekly = text.contains(normalize('প্রতি সপ্তাহে')) || text.contains(normalize('সপ্তাহে সপ্তাহে')) || text.contains(normalize('প্রত্যেক'));
    final days = <int>[];
    for (var k = 0; k < 7; k++) {
      final stem = normalize(bnWeekdays[k].replaceAll('বার', ''));
      final every = text.contains('${normalize('প্রতি')} $stem') || text.contains('${normalize('প্রত্যেক')} $stem');
      if ((weekly || every) && text.contains(stem)) days.add(k + 1);
    }
    return days;
  }

  bool _contactList(String text) {
    if (findPhone(text) != null) return false;
    final numbers = _hasNorm(text, ['নম্বর', 'নাম্বার', 'কন্টাক্ট', 'contact', 'যোগাযোগ', 'number']);
    final show = _hasNorm(text, ['দেখাও', 'দেখান', 'দেখি', 'কী কী', 'কি কি', 'তালিকা', 'লিস্ট', 'কয়টা', 'কতগুলো', 'কত জন', 'কতজন', 'show']);
    final all = _hasNorm(text, ['সব', 'সংরক্ষিত', 'রাখা', 'গুলো', 'গুলি', 'আমার', 'তালিকা', 'লিস্ট', 'সেভ']);
    if (!numbers || !show || !all) return false;
    // "রহিমের নম্বর দেখাও" asks for one person: that is a search.
    final w = words(text);
    const mine = {'আমার', 'আমাদের', 'সব', 'সবার'};
    return !w.any((x) => (x.endsWith('ের') || x.endsWith('এর') || x.endsWith('র')) && !mine.contains(x) && x != normalize('সংরক্ষিত') &&
        !x.startsWith(normalize('নম্বর')) && !x.startsWith(normalize('নাম্বার')) && !x.startsWith(normalize('যোগাযোগ')));
  }

  /// An alarm said in any common way. A bare hour with no সকাল/রাত is the
  /// next time that hour comes round (at 11 at night "৬টায়" is 6 in the
  /// morning); with a day ("কাল ৬টায়") it is the morning.
  Command? _alarm(String said, String text) {
    final alarmWord = _hasNorm(text, _alarmWords);
    final wake = _hasNorm(text, _wakeWords);
    if (!alarmWord && !wake) return null;
    // Asking about, showing, stopping or removing alarms is not setting one.
    // Removing one by name is handled with the other changes ("মিটিংয়ের অ্যালার্মটা মুছে দাও").
    if (_hasNorm(text, const ['মুছ', 'ডিলিট', 'delete', 'বাতিল'])) return null;
    // Switching alarms off or on, or opening the page: the অ্যালার্ম page.
    if (_hasNorm(text, const ['বন্ধ', 'খোলো', 'খুলুন', 'খুলে', 'অফ', 'off', 'চালু', 'পাতা', 'পেজ'])) {
      return alarmWord ? OpenPlace(said, place: 'alarms') : null;
    }
    // Asking about them ("আমার কোন এলার্ম আছে?", "কখন আছে এলার্ম?",
    // "অ্যালার্মগুলো দেখাও"): answered here, from the alarms kept.
    if (_hasNorm(text, const ['দেখাও', 'দেখান', 'তালিকা', 'লিস্ট', 'কয়টা', 'কয়টায়', 'কখন', 'কটায়', 'গুলো', 'গুলি', 'কতগুলো']) ||
        (isQuestionText(said) && !_hasNorm(text, const ['দিবা', 'দেবে', 'দিবেন', 'পারবে', 'পারবা']))) {
      return alarmWord ? ReminderQuery(said, terms: searchTerms(text), alarmsOnly: true) : null;
    }
    var (before, plain) = splitBefore(said);
    // For an alarm a bare "৬টা" is a time, not a count.
    plain = plain.replaceAllMapped(RegExp(r'([0-9০-৯]{1,2})\s*টা(?![য়য়র])'), (m) => '${m[1]}টায়');
    final when = parseWhen(plain, now);
    DateTime at = when?.at ?? noTimeYet;
    final relative = _hasNorm(text, const ['মিনিট পর', 'মিনিট পরে', 'ঘণ্টা পর', 'ঘণ্টা পরে', 'ঘন্টা পর', 'ঘন্টা পরে', 'মিনিটের মধ্যে']);
    final period = _hasNorm(text, const ['সকাল', 'ভোর', 'দুপুর', 'বিকাল', 'বিকেল', 'সন্ধ্যা', 'সন্ধা', 'রাত', 'am', 'pm', 'এএম', 'পিএম']);
    if (when != null && when.hasTime && !relative && !period) {
      final h12 = at.hour % 12;
      if (when.hasDay) {
        at = DateTime(at.year, at.month, at.day, h12 == 0 ? 12 : h12, at.minute);
      } else {
        final today = DateTime(now.year, now.month, now.day);
        at = [
          DateTime(today.year, today.month, today.day, h12, at.minute),
          DateTime(today.year, today.month, today.day, h12 + 12, at.minute),
          DateTime(today.year, today.month, today.day + 1, h12, at.minute),
        ].firstWhere((c) => c.isAfter(now));
      }
    } else if (when != null && (!when.hasTime || !RegExp(r'[0-9০-৯]').hasMatch(normalize(plain)) && !words(normalize(plain)).any(_numberWord.hasMatch))) {
      at = noTimeYet; // "কাল সকালে অ্যালার্ম দাও": the chat asks what time
    }
    final daily = _hasNorm(text, const ['প্রতিদিন', 'প্রতি দিন', 'রোজ', 'প্রত্যেকদিন', 'প্রত্যেক দিন', 'দৈনিক', 'daily', 'every day']);
    final weekDays = _weeklyDays(text);
    final repeat = daily ? Repeat.daily : (weekDays.isNotEmpty ? Repeat.weekly : Repeat.none);
    if (repeat == Repeat.weekly && at.year > 2000) {
      var d = DateTime(now.year, now.month, now.day, at.hour, at.minute);
      for (var i = 0; i < 8 && !(weekDays.contains(d.weekday) && d.isAfter(now)); i++) {
        d = d.add(const Duration(days: 1));
      }
      at = d;
    }
    // What it is for ("নামাজের অ্যালার্ম", "ওষুধ খাওয়ার এলার্ম"); otherwise just "অ্যালার্ম".
    final rest = [
      for (final x in words(normalize(withoutWhen(plain))))
        if (!_alarmJunk.contains(x) && !RegExp(r'^[0-9০-৯]').hasMatch(x) && !_numberWord.hasMatch(x) && !_alarmWords.any((a) => x.startsWith(normalize(a))) && !RegExp(r'^[a-z]{1,4}$').hasMatch(x)) x,
    ];
    var title = wake ? 'ঘুম থেকে ওঠা' : (rest.isEmpty ? 'অ্যালার্ম' : tidy(cutWords(withoutWhen(plain), [..._alarmWords, ..._alarmVerbs, ..._wakeWords, ..._fillers])));
    // "প্রতি রবিবার থেকে বৃহস্পতিবার …, পড়ানো আছে আমার" → "পড়ানো".
    title = tidy(title
        .replaceAll(RegExp(fold(r'(?:^|(?<=\s))(?:প্রতি|থেকে|পর্যন্ত|প্রত্যেক)(?=\s|$|[,।])')), ' ')
        .replaceAll(RegExp(fold(r'(?:\s+(?:আছে|আমার|আছে\s+আমার|আমার\s+আছে))+\s*[।.!]*\s*$')), '')
        .replaceAll(RegExp(r'^[\s,।]+|[\s,।]+$'), ''));
    final clean = title.trim().isEmpty || words(normalize(title)).every((x) => _alarmJunk.contains(x) || RegExp(r'^[0-9০-৯]').hasMatch(x) || _numberWord.hasMatch(x)) ? 'অ্যালার্ম' : title;
    return ReminderAdd(said, title: clean, at: at, repeat: repeat, alarm: true, weekdays: repeat == Repeat.weekly ? weekDays : const [], minutesBefore: before);
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
    final tellLater = _hasNorm(text, const ['কথা বলো', 'কথা বলবা', 'কথা বলবে', 'কথা বলিও', 'বলে দিও', 'বলে দিবা']) && (parseWhen(said, now)?.hasTime ?? false);
    if ((!asking || tellLater) && _hasNorm(text, _remindKeys)) {
      final (before, plain) = splitBefore(said);
      said = plain;
      final every = everyMinutes(text);
      final weekDays = _weeklyDays(text);
      final daily = _hasNorm(text, const ['প্রতিদিন', 'প্রতি দিন', 'রোজ', 'প্রত্যেকদিন', 'প্রত্যেক দিন', 'দৈনিক', 'daily', 'every day']);
      final when = parseWhen(said, now);
      Repeat repeat = Repeat.none;
      DateTime? at = when?.at;
      if (every != null) {
        repeat = Repeat.everyMinutes(every);
        // "প্রতি ৩০ মিনিটে" with no start time: first ring one interval from now.
        if (when == null || (!when.hasTime && !when.hasDay)) {
          final first = now.add(Duration(minutes: repeat.minutes));
          at = DateTime(first.year, first.month, first.day, first.hour, first.minute);
        }
      } else if (daily) {
        repeat = Repeat.daily;
        at ??= DateTime(now.year, now.month, now.day, 9);
        if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
      } else if (weekDays.isNotEmpty) {
        // "প্রতি শুক্রবার সকাল ৯টায়", "প্রতি সপ্তাহে রবি আর বুধবার"
        repeat = Repeat.weekly;
        if (at != null) {
          var d = DateTime(now.year, now.month, now.day, at.hour, at.minute);
          for (var i = 0; i < 8 && !(weekDays.contains(d.weekday) && d.isAfter(now)); i++) {
            d = d.add(const Duration(days: 1));
          }
          at = d;
        }
      } else if (_hasNorm(text, const ['প্রতি মাসে', 'প্রতিমাসে', 'মাসে মাসে', 'প্রতি মাসের', 'every month'])) {
        repeat = Repeat.monthly;
      } else if (_hasNorm(text, const ['প্রতি বছর', 'প্রতিবছর', 'বছরে বছরে', 'প্রতি বছরের', 'every year'])) {
        repeat = Repeat.yearly;
      }
      // "ডোমেইন রিনিউর তারিখটা মনে করিয়ে দাও" asks for a saved date.
      final askingDate = _hasNorm(text, const ['তারিখ', 'মেয়াদ', 'কবে']);
      if (at != null || (_hasNorm(text, _remindAskKeys) && !askingDate)) {
        var title = withoutWhen(said).replaceAll(_everyPattern, ' ');
        title = tidy(cutWords(title, [
          'reminder দাও', 'reminder দিও', 'reminder দিবা', 'রিমাইন্ডার দাও', 'রিমাইন্ডার দিও', 'রিমাইন্ডার দিবা', 'আগামী মাসের', 'আগামী মাসে',
          ..._remindKeys, ..._remindAskKeys, ..._fillers, 'প্রতি মাসে', 'প্রতিমাসে', 'প্রতি মাসের', 'প্রতি বছর', 'প্রতিবছর', 'প্রতি বছরের', 'প্রতিদিন', 'প্রতি দিন',
          'রোজ', 'প্রত্যেকদিন', 'দৈনিক', 'প্রতি ঘণ্টায়', 'প্রতি ঘন্টায়', 'ঘণ্টায় ঘণ্টায়', 'ঘন্টায় ঘন্টায়', 'পর পর', 'পরপর', 'অন্তর', 'প্রতি',
        ]));
        if (title.startsWith('পর ')) title = title.substring(3).trim();
        title = tidy(cutWords(title, [for (final d in bnWeekdays) ...[d, '$dে', '${d}ের'], 'সপ্তাহে', 'সপ্তাহে সপ্তাহে', 'প্রত্যেক', 'অ্যালার্ম', 'এলার্ম']));
        // A time said in words ("আটটায়", "সাড়ে ছয়টায়") is not part of the title.
        title = tidy([for (final x in title.split(RegExp(r'\s+'))) if (!_numberWord.hasMatch(normalize(x)) && !const ['সাড়ে', 'সোয়া', 'পৌনে'].contains(x)) x].join(' '));
        if (title.isEmpty) title = defaultReminderTitle;
        // "মিটিংয়ের রিমাইন্ডার দাও": the title is "মিটিং", not "মিটিংয়ের".
        final tw = title.split(' ');
        if (tw.length <= 2 && RegExp(r'(য়ের|ের|এর)$').hasMatch(fold(tw.last)) && _hasNorm(text, const ['রিমাইন্ডার', 'reminder', 'অ্যালার্ম', 'এলার্ম'])) {
          final last = fold(tw.last);
          tw[tw.length - 1] = last.endsWith(fold('য়ের')) ? last.substring(0, last.length - fold('য়ের').length) : stripPossessive(last);
          if (tw.last.trim().isNotEmpty) title = tw.join(' ');
        }
        // No time yet: the chat asks "কখন মনে করাব?".
        final alarmWord = _hasNorm(text, const ['অ্যালার্ম', 'এলার্ম', 'alarm']);
        // A day but no hour for a one-time reminder ("কাল মনে করিয়ে দিও"): ask the hour, keep the day.
        if (repeat == Repeat.none && when != null && when.hasDay && !when.hasTime) {
          return ReminderAdd(said, title: title, at: noTimeYet, alarm: alarmWord, minutesBefore: before, day: when.day);
        }
        return ReminderAdd(said, title: title, at: at ?? noTimeYet, repeat: repeat, alarm: alarmWord, weekdays: repeat == Repeat.weekly ? weekDays : const [], minutesBefore: before);
      }
    }

    // "ব্যাংকের কাজটা হয়ে গেছে" — only when it matches a to-do.
    final money = text.contains(normalize('টাকা')) || findAmount(text) != null;
    // "রিপোর্টের কাজটা এখনো শেষ হয়নি": the opposite — still to do.
    if (!money && !asking && saysNotDone(text)) {
      final terms = searchTerms(normalize(cutWords(said, [..._doneKeys, 'হয়নি', 'হয় নি', 'হয় নাই', 'হয়নাই', 'করিনি', 'এখনো', 'এখনও', 'বাকি', 'শেষ', 'কাজটা', 'কাজ টা', 'কাজটি', 'কাজ', 'টা'])));
      if (terms.isNotEmpty && matchTasks(tasks, terms).isNotEmpty) return TaskDone(said, terms: terms, done: false);
    }
    if (!money && _hasNorm(text, _doneKeys) && !saysNotDone(text)) {
      final terms = searchTerms(normalize(cutWords(said, [..._doneKeys, 'কাজটা', 'কাজ টা', 'কাজটি', 'কাজ', 'টা'])));
      if (terms.isNotEmpty && matchTasks(tasks.where((t) => !t.done), terms).isNotEmpty) return TaskDone(said, terms: terms);
    }
    return null;
  }

  static final _futureVerbs = {
    for (final x in ['যাব', 'করব', 'দিব', 'নিব', 'আনব', 'কিনব', 'দেখব', 'বলব', 'আসব', 'খাব', 'পাঠাব', 'ধরব', 'তুলব', 'রাখব', 'ফিরব', 'ছাড়ব', 'ঘুরব', 'বসব', 'শুরু করব']) normalize(x),
  };

  /// Numbers in the sentence, with decimals ("৭.২" → 7.2), in order.
  static List<double> _numbers(String said) => [
        for (final m in RegExp(r'\d+(?:\.\d+)?').allMatches(asciiDigits(said).replaceAll(RegExp(r'(?<=\d),(?=\d{3})'), ''))) double.parse(m[0]!),
      ];

  Command? _health(String said, String text, List<String> w) {
    bool has(List<String> keys) => _hasNorm(text, keys);
    final asking = isQuestionText(said) || has(['কত', 'কেমন', 'দেখাও', 'দেখান', 'কমল', 'কমেছে', 'বাড়ল', 'বেড়েছে']);
    final nums = _numbers(said);
    final weight = has(['ওজন', 'weight']) || (has(['কেজি', 'kg']) && !has(['টাকা', 'চাল', 'ডাল', 'মাংস', 'মাছ', 'আলু', 'পেঁয়াজ']));
    final bp = has(['প্রেশার', 'প্রেসার', 'রক্তচাপ', 'বিপি', 'bp', 'blood pressure']);
    final sugar = has(['সুগার', 'ডায়াবেটিস', 'ডায়বেটিস', 'গ্লুকোজ', 'sugar', 'glucose']);
    final bmi = has(['বিএমআই', 'bmi']);
    if (bmi) return HealthQuery(said, what: 'bmi');
    if (asking && nums.isEmpty) {
      if (weight) return HealthQuery(said, what: HealthKind.weight.name);
      if (bp) return HealthQuery(said, what: HealthKind.bp.name);
      if (sugar) return HealthQuery(said, what: HealthKind.sugar.name);
      // "আমার স্বাস্থ্যের অবস্থা কি", "শরীর কেমন": all the latest measures.
      if (has(['স্বাস্থ্য', 'সাস্থ্য', 'শরীর', 'শরির', 'হেলথ', 'health']) && !has(['টাকা', 'বিমা', 'বীমা', 'কার্ড'])) return HealthQuery(said, what: 'summary');
      return null;
    }
    if (has(['টাকা']) || nums.isEmpty) return null;
    if (bp && nums.length >= 2 && nums[0] >= 60 && nums[0] <= 260 && nums[1] >= 30 && nums[1] <= 160) {
      final pulse = nums.length >= 3 && has(['পালস', 'pulse', 'নাড়ি']) ? nums[2] : null;
      return HealthAdd(said, kind: HealthKind.bp, a: nums[0], b: nums[1], c: pulse);
    }
    if (sugar && nums.first > 0 && nums.first < 600) {
      final fasting = has(['খালি পেটে', 'খালিপেটে', 'ফাস্টিং', 'fasting', 'নাস্তার আগে', 'খাওয়ার আগে', 'খাবার আগে']);
      return HealthAdd(said, kind: HealthKind.sugar, a: double.parse(toMmolValue(nums.first).toStringAsFixed(1)), tag: fasting ? 'fasting' : 'after');
    }
    if (weight && nums.first >= 2 && nums.first <= 300) return HealthAdd(said, kind: HealthKind.weight, a: nums.first);
    if (has(['গ্লাস', 'glass']) && has(['পানি', 'water'])) return HealthAdd(said, kind: HealthKind.water, a: nums.first.clamp(1, 20).toDouble());
    if (has(['হাঁটলাম', 'হাঁটছি', 'হেঁটেছি', 'ব্যায়াম', 'হাঁটা', 'দৌড়', 'exercise', 'walk']) && has(['মিনিট', 'ঘণ্টা', 'ঘন্টা'])) {
      final minutes = has(['ঘণ্টা', 'ঘন্টা']) ? nums.first * 60 : nums.first;
      if (minutes > 0 && minutes <= 600) return HealthAdd(said, kind: HealthKind.exercise, a: minutes);
    }
    if (has(['ঘুমিয়েছি', 'ঘুমালাম', 'ঘুম হয়েছে', 'ঘুমিয়েছিলাম', 'slept']) && has(['ঘণ্টা', 'ঘন্টা', 'hour']) && nums.first > 0 && nums.first <= 16) {
      return HealthAdd(said, kind: HealthKind.sleep, a: nums.first);
    }
    return null;
  }

  Command? _plan(String said, String text, List<String> w) {
    if (text.contains(normalize('টাকা')) || findAmount(normalize(withoutWhen(said))) != null) return null;
    // "আজ সকাল ৮টায় মিটিং মনে করিও": a reminder request — never quietly a to-do.
    if (aspectOf(said) == Aspect.remind) return null;
    final when = parseWhen(said, now);
    if (when == null || !(when.hasDay || when.hasTime)) return null;
    // "আজ ইব্রাহিম ভাই আসার কথা সন্ধ্যা ৭টায়", "কাল ১০টায় মিটিং": an appointment.
    final event = _hasNorm(text, [
      'আসার কথা', 'যাওয়ার কথা', 'দেখা করার কথা', 'কথা আছে', 'কথা হয়েছে', 'মিটিং', 'দাওয়াত', 'অনুষ্ঠান', 'অ্যাপয়েন্টমেন্ট', 'এপয়েন্টমেন্ট', 'ক্লাস', 'পরীক্ষা',
      'ফ্লাইট', 'ট্রেন', 'ইন্টারভিউ', 'প্রোগ্রাম', 'সাক্ষাৎ', 'আসবেন', 'আসবে', 'আসছেন', 'আসছে', 'আসবা',
    ]);
    if (!when.hasDay && !event) return null;
    final future = event || w.any((x) => (x.endsWith(normalize('বো')) && x.length >= 3) || x.endsWith(normalize('বেন')) || (x.endsWith(normalize('বে')) && x.length >= 4) || _futureVerbs.contains(x)) ||
        (w.isNotEmpty && (w.last == normalize('আছে') || w.last == normalize('আছেন')));
    if (!future) return null;
    var title = tidy(cutWords(withoutWhen(said), ['আমি', 'আমার', 'আমরা', 'আমাদের', ..._fillers]));
    title = title.replaceAll(RegExp(r'[।.!]+$'), '').trim();
    if (title.isEmpty) return null;
    if (when.hasTime && when.at.isAfter(now)) return ReminderAdd(said, title: title, at: when.at);
    return TaskAdd(said, title: title, due: when.day);
  }

  Command? _taskAdd(String said, String text, List<String> w) {
    final listed = _hasNorm(text, _taskListKeys) || _hasNorm(text, ['লিস্টে', 'তালিকায়']);
    final mustDo = RegExp(r'\S(তে|তেই) (হবে|লাগবে)( |$)').hasMatch(text) || RegExp(r'\S (করা|কেনা|যাওয়া|আনা|দেওয়া|নেওয়া) (লাগবে|দরকার)( |$)').hasMatch(text);
    if (!listed && !mustDo) return null;
    final bazar = _hasNorm(text, ['বাজারের লিস্টে', 'বাজারের তালিকায়', 'বাজারের লিস্ট', 'বাজারের তালিকা']);
    // "… এটা একটা কাজের লিস্টে রাখ": the words that only point at the list.
    var body = said.replaceAll(RegExp(fold(r'[\s,।]*(?:এটা|এইটা|এটাকে|এইটাকে)(?:\s+(?:একটা|একটি|আমাকে|আমার))*(?=\s+(?:কাজের|লিস্টে|তালিকায়|তালিকা|লিস্ট))')), ' ');
    // "দশটায়", "পাঁচটায়": a clock time said in words.
    body = body.replaceAll(RegExp(fold(r'(?:^|\s)(?:এক|দুই|দু|তিন|চার|পাঁচ|পাচ|ছয়|সাত|আট|নয়|দশ|এগারো|বারো)টায়(?=\s|$)')), ' ');
    // "… কাজের তালিকাতে লেখ যে সকালবেলা বাজারে যাইতে হবে": the words after "যে".
    final after = RegExp(fold(r'(?:লেখ|লেখো|লিখো|লিখ|লিখবা|লিখে\s+রাখো|লিখে\s+রাখ|রাখো|রাখ|তুলে\s+রাখো|তুলে\s+রাখ)\s+যে\s+(.+)$')).firstMatch(fold(body));
    if (after != null) body = after[1]!;
    // "… কাজের তালিকা তে পুকুরে চুন দিতে হবে এটা লিখে রাখ": what follows the
    // list is the to-do (what came before it was talk).
    final listAt = RegExp(fold(r'কাজের\s+(?:তালিকা(?:য়|তে|\s+তে)?|লিস্ট(?:ে|ের)?)\s+(.+)$')).firstMatch(fold(body));
    if (after == null && listAt != null && RegExp(r'\S(তে|তেই) (হবে|লাগবে)( |$)|\S (করা|কেনা|যাওয়া|আনা|দেওয়া|নেওয়া) (লাগবে|দরকার)( |$)').hasMatch(normalize(listAt[1]!))) body = listAt[1]!;
    var title = tidy(cutWords(withoutWhen(body), [
      ..._taskListKeys, 'বাজারের লিস্টে', 'বাজারের তালিকায়', 'কাজের লিস্টে', 'কাজের তালিকাতে', 'কাজের তালিকা তে', 'কাজের তালিকায়', 'কাজের তালিকা', 'কাজের লিস্টের', 'কাজের লিস্ট', 'তালিকাতে', 'লিস্টে', 'তালিকায়', 'তালিকা', 'লিস্ট', 'কাজের', ..._addVerbs, ..._fillers, 'আমার', 'একটা', 'যা', 'জন্য',
    ]));
    title = title.replaceAll(RegExp(fold(r'\s+(?:এরকম|এরাম|এইরকম|এই রকম|এমন)(?:\s+(?:একটা|একটি))?(?=\s|$)')), ' ').replaceAll(RegExp(r'[।.!,]+$'), '').trim().replaceFirst(RegExp(fold(r'^যে\s+')), '').replaceFirst(RegExp(fold(r'\s+(?:এটা|এইটা|এটাকে)$')), '').trim();
    final when = parseWhen(said, now);
    final due = when != null && when.hasDay ? when.day : null;
    // "কালকের কাজের তালিকায় লেখ" and nothing yet: the chat asks what to write.
    if (title.isEmpty) return listed && _hasNorm(text, _addVerbs) ? TaskAdd(said, title: '', due: due) : null;
    if (bazar) title = 'বাজার: $title';
    return _maybeMonthly(said, text, TaskAdd(said, title: title, due: due));
  }

  /// "প্রতি মাসের ১ তারিখে … কাজ": a to-do that comes back every month is a
  /// monthly reminder (9 in the morning, the day said).
  Command _maybeMonthly(String said, String text, TaskAdd t) {
    if (t.due == null || !_hasNorm(text, const ['প্রতি মাসে', 'প্রতিমাসে', 'প্রতি মাসের', 'প্রতিমাসের', 'মাসে মাসে'])) return t;
    var at = DateTime(now.year, now.month, t.due!.day, 9);
    if (!at.isAfter(now)) at = DateTime(now.year, now.month + 1, t.due!.day, 9);
    final title = t.title.replaceAll(RegExp(fold(r'(?:^|\s)(?:প্রতি\s*মাসের|প্রতি\s*মাসে|প্রতিমাসের|প্রতিমাসে)(?=\s|$)')), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return ReminderAdd(said, title: title, at: at, repeat: Repeat.monthly);
  }

  Via? _via(String text) {
    final wa = _hasNorm(text, ['হোয়াটসঅ্যাপ', 'হোয়াটসঅ্যাপে', 'হোয়াটসঅ্যাপে', 'হোয়াটসএপ', 'হোয়াটসএপে', 'হোয়াটস্যাপ', 'ওয়াটসঅ্যাপ', 'whatsapp']);
    final sms = _phraseIn(text, _smsKeys);
    final call = _phraseIn(text, _callKeys);
    if (wa && (sms || call || _hasNorm(text, ['পাঠাও', 'দাও', 'করো', 'দেন', 'পাঠান', 'লেখো', 'লিখো', 'লিখে দাও', 'লিখে পাঠাও', 'জানাও', 'জানিয়ে দাও', 'বলো']))) return Via.whatsapp;
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
        var raw = _nameEndingAt(w, i, stripTo);
        // "রবিন হায়দারকে ফোন দাও": the whole name, not only its last word —
        // at the start of the sentence, plain words (no ending, no day or
        // time) before it are part of it.
        if (raw != null && !raw.contains(' ') && i <= 2) {
          var j = i - 1;
          final more = <String>[];
          while (j >= 0 && more.length < 2 && _looksLikeName(w[j]) && stripPossessive(w[j]) == w[j] && stripTo(w[j]) == w[j] && parseWhen(w[j], now) == null && !_honorifics.contains(w[j])) {
            more.insert(0, w[j]);
            j--;
          }
          if (j < 0 && more.isNotEmpty) raw = '${more.join(' ')} $raw';
        }
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
    // "রহিম আমাকে কত দেবে?": a known name said plainly.
    for (final k in known) {
      if (w.contains(normalize(k))) return LedgerQuery(said, ask: LedgerAsk.person, person: k);
    }
    // Who gets the money in the sentence decides the direction ("কে আমার
    // কাছে পাবে?" is what I owe; "কার কাছে পাই?" is what I am owed).
    final mine = owedToMe(text);
    if (mine == true) return LedgerQuery(said, ask: LedgerAsk.receivable);
    if (mine == false) return LedgerQuery(said, ask: LedgerAsk.payable);
    if (text.contains('কাকে')) return LedgerQuery(said, ask: LedgerAsk.payable);
    if (text.contains('কার কাছে')) return LedgerQuery(said, ask: LedgerAsk.receivable);
    return LedgerQuery(said, ask: LedgerAsk.all);
  }
}

final List<String> _projectWords = [for (final p in ['প্রজেক্ট', 'প্রকল্প', 'project', 'প্রোজেক্ট']) normalize(p)];

const _alarmWords = ['অ্যালার্ম', 'এলার্ম', 'এ্যালার্ম', 'অ্যালার্ম', 'এলার্ম', 'alarm', 'অ্যালাম', 'এলাম্ব'];
const _wakeWords = ['ঘুম থেকে ডেকে', 'ঘুম থেকে তুলে', 'ঘুম ভাঙিয়ে', 'ডেকে দিও', 'ডেকে দিবা', 'ডেকে দেবে', 'ডেকে দিবে', 'ডেকে দিয়ো', 'ডেকে তুলো', 'জাগিয়ে দিও', 'জাগিয়ে দিবা', 'জাগিয়ে দেবে', 'wake me'];
const _alarmVerbs = ['সেট করো', 'সেট কর', 'সেট করে দাও', 'সেট করুন', 'সেট দাও', 'দিয়ে রাখো', 'দিয়ে রাখ', 'দিয়ে দাও', 'দিয়ে দিও', 'দাও', 'দিও', 'দিন', 'দেন', 'লাগাও', 'লাগিয়ে দাও', 'বাজাবে', 'বাজিয়ো', 'বাজিও', 'বাজাও', 'রাখো', 'একটা', 'set', 'koro', 'kore', 'dao', 'den', 'tay', 'te'];
final _numberWord = RegExp('^(এক|দুই|দু|তিন|চার|পাঁচ|পাচ|ছয়|ছয়|ছ|সাত|আট|নয়|নয়|দশ|এগারো|এগার|বারো|বার)(টা|টায়|টায়|টার|টাতে|টাই)\$');
final _alarmJunk = {
  for (final x in const ['একটা', 'একটি', 'টা', 'সেট', 'কর', 'করো', 'করে', 'করুন', 'দাও', 'দিও', 'দিন', 'দেন', 'দিয়ে', 'রাখো', 'রাখ', 'লাগাও', 'লাগিয়ে', 'বাজাবে', 'বাজাও', 'বাজিও', 'আমাকে', 'আমার', 'জন্য', 'একটু', 'প্লিজ', 'please', 'সাড়ে', 'সোয়া', 'পৌনে', 'এ', 'য়', 'তে', 'টায়', 'টার', 'টাতে', 'বাজে', 'মিনিট', 'ঘণ্টা', 'পর', 'পরে', 'set', 'koro', 'tay', 'প্রতিদিন', 'রোজ', 'দৈনিক', 'প্রত্যেকদিন', 'প্রতি', 'দিন'])
    normalize(x),
};

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
  'তুলে রাখ', 'তুলে রাখেন', 'লিস্ট কর', 'লিস্ট করো', 'তালিকা কর', 'তালিকা করো', 'লিস্টে রাখ', 'লিস্টে রাখো', 'তালিকায় রাখ', 'তালিকায় রাখো',
  'লেখ', 'লেখো', 'লিখ', 'লিখবা', 'লিখবে', 'লিখে দাও', 'লিখে দিও', 'এড করো', 'এড কর', 'অ্যাড করো', 'অ্যাড কর',
  // "এগুলো কাজের তালিকায় যুক্ত করো": every form of "যুক্ত/যোগ করা".
  'যুক্ত কর', 'যুক্ত করে', 'যোগ করে', 'ঢুকিয়ে', 'সেভ কর', 'তুলে দাও', 'তুলে দিও',
];
const _fillers = ['আমাকে', 'আমারে', 'প্লিজ', 'একটু', 'please', 'তো'];
const _remindKeys = [
  'মনে করিয়ে দিও', 'মনে করিয়ে দিবা', 'মনে করিয়ে দেবে', 'মনে করিয়ে দিবে', 'মনে করিয়ে দাও', 'মনে করিয়ে দিয়ো', 'মনে করিয়ে দিবেন',
  'মনে করিয়ে দিন', 'মনে করিয়ে দেবেন', 'মনে করিয়ে দিও তো', 'মনে করিয়ে', 'মনে করাবে', 'মনে করাবা', 'মনে করাইও', 'মনে করিও', 'মনে করিয়ো', 'মনে করাইয়ো', 'মনে করাইয়া দিও',
  'রিমাইন্ডার সেট করে দাও', 'রিমাইন্ডার সেট করে দিও', 'রিমাইন্ডার সেট করে দেন', 'রিমাইন্ডার সেট করেন', 'রিমাইন্ডার সেট কর', 'এলার্ম সেট করে দাও', 'অ্যালার্ম সেট করে দাও', 'রিমাইন্ডার দাও', 'রিমাইন্ডার দিও', 'রিমাইন্ডার সেট করো', 'রিমাইন্ডার রাখো', 'রিমাইন্ডার', 'অ্যালার্ম দাও', 'অ্যালার্ম দিও',
  'অ্যালার্ম সেট করো', 'এলার্ম দাও', 'এলার্ম দিও', 'remind me', 'remind', 'alarm', 'জানিয়ে দিও', 'জানিয়ে দিবা', 'জানাবে', 'ডেকে দিও',
  'ডেকে দিবা', 'কথা বলো', 'কথা বলবা', 'কথা বলবে', 'কথা বলিও', 'বলে দিও', 'বলে দিবা',
];
/// Clearly asking for a reminder (even when the time is still missing).
const _remindAskKeys = [
  'মনে করিয়ে দিও', 'মনে করিয়ে দিবা', 'মনে করিয়ে দেবে', 'মনে করিয়ে দিবে', 'মনে করিয়ে দাও', 'মনে করিয়ে দিয়ো', 'মনে করিয়ে দিবেন',
  'মনে করিয়ে দিন', 'মনে করিয়ে দেবেন', 'মনে করাবে', 'মনে করাবা', 'মনে করাইও', 'মনে করাইয়া দিও', 'রিমাইন্ডার দাও', 'রিমাইন্ডার দিও',
  'রিমাইন্ডার সেট করে দাও', 'রিমাইন্ডার সেট করে দিও', 'রিমাইন্ডার সেট করে দেন', 'রিমাইন্ডার সেট করেন', 'রিমাইন্ডার সেট কর', 'এলার্ম সেট করে দাও', 'অ্যালার্ম সেট করে দাও', 'রিমাইন্ডার দিবা', 'রিমাইন্ডার দিবে', 'রিমাইন্ডার দেবে', 'রিমাইন্ডার দিন', 'রিমাইন্ডার সেট করো', 'রিমাইন্ডার সেট কর', 'রিমাইন্ডার রাখো',
  'অ্যালার্ম দাও', 'অ্যালার্ম দিও', 'অ্যালার্ম সেট করো', 'এলার্ম দাও', 'এলার্ম দিও', 'remind me', 'ডেকে দিও', 'ডেকে দিবা',
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

final _everyPattern = RegExp(fold('(প্রতি|প্রত্যেক)?\\s*(আধা|আধ|[০-৯0-9]+)\\s*(মিনিট|ঘণ্টা|ঘন্টা)\\S*(\\s*(পর পর|পরপর|অন্তর|পরে পরে))?'));

/// "প্রতি ৩০ মিনিটে", "১০ মিনিট পর পর", "ঘণ্টায় ঘণ্টায়", "প্রতি আধা ঘণ্টায়"
/// → minutes; null when the sentence has no such repeat. [text] is normalized.
int? everyMinutes(String text) {
  final t = ' $text ';
  int unit(String u) => u.startsWith(normalize('মিনিট')) || u.startsWith('min') ? 1 : 60;
  final a = RegExp('(?:প্রতি|প্রত্যেক|every)\\s*(\\d+|${normalize('আধা')}|${normalize('আধ')})\\s*(${normalize('মিনিট')}|${normalize('ঘণ্টা')}|${normalize('ঘন্টা')}|min|hour)')
      .firstMatch(t);
  final b = RegExp('(\\d+|${normalize('আধা')}|${normalize('আধ')})\\s*(${normalize('মিনিট')}|${normalize('ঘণ্টা')}|${normalize('ঘন্টা')})\\S*\\s*(?:পর পর|পরপর|অন্তর|পরে পরে)')
      .firstMatch(t);
  final m = a ?? b;
  if (m != null) {
    final n = m[1]!;
    final count = n == normalize('আধা') || n == normalize('আধ') ? 0 : int.tryParse(n) ?? 1;
    final u = unit(m[2]!);
    final minutes = count == 0 ? 30 : count * u;
    return minutes > 0 ? minutes : null;
  }
  if (_hasNorm(text, const ['প্রতি ঘণ্টায়', 'প্রতি ঘন্টায়', 'প্রতি ঘণ্টা', 'প্রতি ঘন্টা', 'ঘণ্টায় ঘণ্টায়', 'ঘন্টায় ঘন্টায়', 'every hour', 'hourly'])) return 60;
  return null;
}

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
  'সাইট', 'অ্যাপ', 'অ্যাপের', 'মেয়াদ', 'শেষ', 'হওয়ার', 'দিনটা', 'বর্তমানে', 'বর্তমান', 'এখনকার', 'চালু', 'সবগুলো', 'গুলো', 'কিসের', 'কিসে', 'কীসের', 'কোথায়', 'কেন', 'কেমন',
  // Words that never name a thing the user kept — by class, so a speech
  // fragment ("আগামীকাল", "কিন্তু আমি", "আজকে কোন কাজ আছে") never turns
  // into a search that fuzzy-matches a contact ("Khala", "Konate", "Kazi").
  // Days and times of day:
  'আজ', 'আজকে', 'আজকের', 'কাল', 'কালকে', 'কালকের', 'আগামীকাল', 'আগামীকালকে', 'আগামীকালের', 'গতকাল', 'গতকালকে', 'পরশু', 'পরশুদিন',
  'সকাল', 'সকালে', 'দুপুর', 'দুপুরে', 'বিকাল', 'বিকেল', 'বিকেলে', 'সন্ধ্যা', 'সন্ধ্যায়', 'রাত', 'রাতে', 'এখন', 'তখন', 'পরে', 'আগে', 'দিনে',
  // Joining words and openers:
  'কিন্তু', 'এবং', 'তারপর', 'তারপরে', 'এরপর', 'তবে', 'তাহলে', 'নাকি', 'অথবা', 'বা', 'যদি', 'মানে', 'আবার', 'তো', 'তাই', 'কারণ', 'আচ্ছা', 'ঠিক',
  'হ্যাঁ', 'হ্যা', 'জি', 'জ্বি', 'না', 'ভাই', 'আপা', 'ইয়ে', 'ইয়া', 'এইযে', 'শোনো', 'শুনো', 'যেটা', 'সেটা', 'এটা', 'ওটা', 'এগুলো', 'সেগুলো',
  // People said as pronouns:
  'তুমি', 'তোমার', 'তোমাকে', 'আপনি', 'আপনার', 'আপনাকে', 'আমরা', 'আমাদের', 'সে', 'তার', 'তাকে', 'ওর', 'ওকে', 'উনি', 'ওনার',
  // The to-do list itself (asked about through the list, not a search):
  'কাজ', 'কাজের', 'কাজগুলো', 'কাজগুলি', 'কাজগুলা', 'কাজটা', 'তালিকা', 'তালিকায়', 'লিস্ট', 'লিস্টে', 'বাকি', 'কোনো', 'কয়টা', 'কতগুলো', 'কোনগুলো',
  // Plain verbs of saying, doing and being:
  'করো', 'কর', 'করি', 'করিনি', 'করি নাই', 'বলি', 'বললাম', 'বলছি', 'বলতেছি', 'জিজ্ঞেস', 'চাই', 'যাও', 'যাব', 'দেখি', 'নেই', 'নাই', 'হলো', 'হল',
};

/// "আজকে কোন কাজ আছে", "কালকের যে কাজগুলো আছে", "কয়টা কাজ বাকি": a
/// question about the to-do list. A statement ("কাল আমার একটা কাজ আছে,
/// ব্যাংকে যেতে হবে") or an order to add/remove is not.
bool asksForTasks(String text) {
  final w = words(text);
  final nouns = {for (final x in const ['কাজ', 'কাজগুলো', 'কাজগুলি', 'কাজগুলা', 'কাজসমূহ', 'টাস্ক', 'task', 'tasks']) normalize(x)};
  final plural = {for (final x in const ['কাজগুলো', 'কাজগুলি', 'কাজগুলা', 'কাজসমূহ', 'tasks']) normalize(x)};
  final be = {for (final x in const ['আছে', 'বাকি', 'রয়েছে', 'রয়েছে', 'নেই', 'নাই', 'পড়ে']) normalize(x)};
  final ask = {for (final x in const ['কোন', 'কোনো', 'কী', 'কি', 'কয়টা', 'কয়টি', 'কয়টা', 'কতগুলো', 'কতগুলা', 'কত', 'কোনগুলো', 'কোনগুলা']) normalize(x)};
  final at = w.indexWhere(nouns.contains);
  if (at < 0) return false;
  // "তোমার কি কোনো কাজ নেই?" is said to the assistant, not about the list.
  if (w.any((x) => const ['তুমি', 'তোমার', 'তোমাকে', 'তোর', 'তুই'].map(normalize).contains(x))) return false;
  if (!w.skip(at + 1).any(be.contains)) return false;
  if (!w.any(ask.contains) && !w.any(plural.contains)) return false;
  if (_hasNorm(text, _addVerbs) || _hasNorm(text, const ['মুছে', 'মুছো', 'বাদ দাও', 'বাদ দিয়ে', 'বাদ দিও', 'ডিলিট', 'কেটে দাও', 'শেষ করেছি', 'হয়ে গেছে', 'করে ফেলেছি'])) return false;
  return findAmount(text) == null;
}

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

/// "…দাও", "…বলো", "…দেখাও" at the end, with nothing to keep or set: a
/// request to be told something ([text] normalized).
bool asksToShow(String text) {
  final w = words(text.trim());
  if (w.isEmpty || !_showVerbs.contains(w.last)) return false;
  return !_hasNorm(text, const ['মনে করি', 'রিমাইন্ডার', 'অ্যালার্ম', 'এলার্ম', 'রাখো', 'রাখুন', 'লিখে', 'লিখো', 'সেট', 'যোগ কর', 'যুক্ত কর', 'মুছ', 'বাদ']);
}

final _showVerbs = {for (final x in const ['দাও', 'দিন', 'দেন', 'দেখাও', 'দেখান', 'বলো', 'বলুন', 'বলেন', 'জানাও', 'জানান']) normalize(x)};

/// Does the sentence ask something (rather than state a fact)?
bool isQuestionText(String said) {
  if (said.contains('?') || said.contains('？')) return true;
  final w = words(normalize(said));
  const q = [
    'কী', 'কি', 'কত', 'কোথায়', 'কোথায়', 'কবে', 'কে', 'কার', 'কাকে', 'কোন', 'কোনটা', 'কেমন', 'কিভাবে', 'কীভাবে',
    'দেখাও', 'দেখান', 'দেখা', 'বলো', 'বলুন', 'বল', 'খুঁজে', 'খোঁজো', 'খুঁজো', 'বের', 'what', 'where', 'when', 'show', 'find',
    'কখন', 'কটায়', 'কয়টা', 'কয়টি', 'কতগুলো', 'কতটা', 'কেন', 'কিসে', 'কিসের', 'কোনগুলো', 'কারা', 'how', 'which',
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
/// "বাদ দাও", "থাক", "বাতিল করো", "cancel" — said alone.
bool isCancel(String said) {
  final t = normalize(said.replaceAll(RegExp(r'[।.!,]'), ' '));
  const all = ['বাদ দাও', 'বাদ দেন', 'বাদ দিন', 'বাদ', 'থাক', 'থাক দরকার নেই', 'থাকুক', 'বাতিল', 'বাতিল করো', 'বাতিল করুন', 'বাতিল কর', 'cancel', 'না থাক', 'দরকার নেই', 'এটা বাদ দাও', 'ওটা বাদ দাও'];
  return all.map(normalize).contains(t);
}

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
  // "এই এপ দিয়ে কি কি করা যায়?", "তুমি আমাকে কিভাবে হেল্প করতে পারো?"
  final aboutApp = _hasPhrase(text, ['এপ', 'অ্যাপ', 'অ্যাপস', 'এপস', 'app', 'তুমি', 'তোমাকে', 'তোমার', 'আপনি', 'আপনাকে', 'সহকারী', 'অ্যাসিস্ট্যান্ট', 'assistant']);
  final how = _hasPhrase(text, ['কি কি', 'কী কী', 'কিভাবে', 'কীভাবে', 'কি ভাবে', 'কী ভাবে', 'কেমনে', 'কোন কোন']);
  if (aboutApp && how && _hasPhrase(text, ['করা যায়', 'করা যায়', 'করতে পার', 'হেল্প', 'সাহায্য', 'কাজে লাগ', 'কাজ কর', 'help'])) return Talk.whatCanYouDo;
  if (_hasPhrase(text, ['কয়টা বাজে', 'কটা বাজে', 'কয়টা বাজে', 'এখন সময় কত', 'সময় কত', 'what time'])) return Talk.time;
  if (_hasPhrase(text, ['আজ কত তারিখ', 'আজকে কত তারিখ', 'আজকের তারিখ', 'আরবি তারিখ', 'আরবী তারিখ', 'হিজরি তারিখ', 'হিজরী তারিখ', 'চাঁদের তারিখ', 'বাংলা তারিখ', 'আরবি মাস', 'হিজরি সন', 'আজ কী বার', 'আজ কি বার', 'আজকে কী বার', 'আজকে কি বার', 'আজ কোন বার'])) {
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

// ───────────────────────── Words said to the assistant ─────────────────────────

const _writeVerbs = r'(?:লিখে\s*(?:রাখো|রাখ|রাখবা|রাখেন|রাখুন|রেখো|নাও|নেও|নিও|নেন|দাও|দেও)|লেখো|লেখ|লিখো|লিখ|লেখেন|লিখুন|লিখবা|নোট\s*(?:করো|কর|করেন|করুন|রাখো|নাও)|সেভ\s*(?:করো|কর|করেন|করুন)|টুকে\s*রাখো|টুকে\s*রাখ)';
const _callWords = r'(?:শোনো|শোন|শুনো|শুনেন|শুনুন|হ্যালো|দোস্ত)';
const _youWords = r'(?:তুমি|তুই|আপনি)';
const _thisWords = r'(?:এটা|এইটা|এটাও|এইটাও|এটাই|এগুলো|এগুলা|এইগুলা|এইগুলো|একটা কথা|একটা জিনিস|এই কথাটা|কথাটা|নিচেরটা)';

final _leadCall = RegExp('^\\s*(?:$_callWords[\\s,।!:;]+)+');
final _leadWrite = RegExp(
    '^\\s*(?:$_youWords\\s+)?(?:$_thisWords\\s+)?(?:একটু\\s+)?$_writeVerbs(?=[\\s,।!:;\\-–]|\$)\\s*(?:যে(?=[\\s,।]|\$))?[\\s,।!:;\\-–]*');
final _tailWrite = RegExp('[\\s,।]+(?:$_youWords\\s+)?(?:$_thisWords\\s+)?(?:একটু\\s+)?$_writeVerbs[\\s।!]*\$');

/// Takes off the words that only tell the assistant to listen or write —
/// "তুমি এটা লেখ, আমি রবিনকে ৫ হাজার দিছি" → "আমি রবিনকে ৫ হাজার দিছি" — so
/// they are never read back as part of what was said. The flag is true when
/// a "write it down" verb was removed.
(String, bool) stripAddress(String said) {
  var t = said.replaceAll('‌', '').replaceAll('‍', '');
  t = t.replaceFirst(_leadCall, '');
  var write = false;
  final m = _leadWrite.firstMatch(t);
  if (m != null) {
    t = t.substring(m.end);
    write = true;
  }
  final tail = _tailWrite.firstMatch(t);
  if (tail != null && tail.start > 0) {
    t = t.substring(0, tail.start);
    write = true;
  }
  return (t.trim(), write);
}

final _pwSentence = RegExp(
    r'^(.+?)\s*(?:এর|ের|র)?\s+(?:wi-?fi\s+|ওয়াইফাই\s+|ওয়াই-?ফাই\s+)?(?:পাসওয়ার্ড|পাসওয়ার্ড|পাসওয়াড|পাসোয়ার্ড|পাস ওয়ার্ড|password|pass|পিন|pin)\s*(?:হলো|হল|হচ্ছে|হইলো|টা|টা হলো|is|:|=|-|–)?\s*(\S+)\s*(?:রাখো|রাখ|লিখে রাখো|সেভ করো|সেভ কর|রেখে দাও)?[।.!]?\s*$',
    caseSensitive: false);

/// "ফেসবুকের পাসওয়ার্ড ১২২৩৯৯৩৯" / "অফিসের ওয়াইফাই পাসওয়ার্ড abcd1234" →
/// a login to keep; null for questions and anything else.
VaultAdd? vaultAddFrom(String said) {
  final m = _pwSentence.firstMatch(said.trim());
  if (m == null) return null;
  final value = m[2]!.trim();
  final v = fold(value.toLowerCase());
  const notValues = ['কত', 'কী', 'কি', 'কোনটা', 'কোথায়', 'দেখাও', 'বলো', 'বল', 'দাও', 'লাগবে', 'দরকার', 'ভুলে', 'মনে', 'নেই', 'খুলো', 'কেমন'];
  if (notValues.any((w) => v == fold(w)) || value.length < 3) return null;
  var name = m[1]!.trim().replaceAll(RegExp(r'^(?:আমার|আমাদের)\s+'), '');
  name = name.split(RegExp(r'\s+')).map((w) => stripPossessive(w)).join(' ').trim();
  if (name.isEmpty) return null;
  final wifi = RegExp(r'wi-?fi|ওয়াইফাই|ওয়াই-?ফাই', caseSensitive: false).hasMatch(said);
  // Spoken digits come in Bengali; a typed password keeps its letters as typed.
  return VaultAdd(said, name: name, password: asciiDigits(value), wifi: wifi);
}


/// mg/dL readings (above 35) as mmol/L.
double toMmolValue(double v) => v > 35 ? v / 18 : v;
