import 'package:flutter/foundation.dart';

import '../logic/answers.dart';
import '../logic/bn.dart';
import '../logic/categories.dart';
import '../logic/ledger.dart';
import '../logic/parser.dart';
import '../logic/phrases.dart';
import '../logic/plan.dart';
import '../logic/search.dart';
import '../logic/talk.dart';
import '../models/models.dart';
import '../services/ai.dart';
import '../ui/yes_no.dart' show pickSpokenOption;
import 'brain.dart';

/// What the chat is waiting to hear.
enum ChatWait { none, yesNo, name, amount, kind }

/// A button under the latest question; tapping it is the same as saying
/// [answer].
class ChatChoice {
  const ChatChoice(this.label, this.answer);
  final String label;
  final String answer;
}

enum LinkKind { person, editEntry, notes, reminders }

/// "খাতা দেখুন" and similar, under an app message.
class ChatLink {
  const ChatLink(this.kind, this.label, {this.person, this.entry});
  final LinkKind kind;
  final String label;
  final String? person;
  final LedgerAdd? entry;
}

class ChatMessage {
  ChatMessage.user(this.text)
      : fromUser = true,
        facts = const [],
        vault = const [],
        links = const [],
        info = false;

  ChatMessage.app(this.text, {this.facts = const [], this.vault = const [], this.links = const [], this.info = false}) : fromUser = false;

  final bool fromUser;
  final String text;

  /// The things found in a long message (shown as a list).
  final List<String> facts;

  /// Logins to open (with fingerprint or PIN); never their passwords.
  final List<VaultItem> vault;
  final List<ChatLink> links;

  /// A small note (AI trouble, a dropped question), not a reply.
  final bool info;
}

const _stopWords = ['থামো', 'থাম', 'থামেন', 'বন্ধ করো', 'বন্ধ কর', 'বন্ধ করেন', 'চুপ', 'চুপ করো', 'স্টপ', 'stop', 'ব্যাস', 'বাস', 'আর না', 'এখন না', 'শেষ'];

/// A conversation: the user says (or types) one thing after another and
/// the app answers each, asking short follow-ups when it needs a name, an
/// amount or a yes. Long messages are split into the separate facts in
/// them, shown as a list and saved together on one yes.
class ChatController extends ChangeNotifier {
  ChatController(this.brain);

  final Brain brain;
  final messages = <ChatMessage>[];

  /// The conversation as the AI may see it: the user's own sentences and
  /// tags in place of anything that came from saved data.
  final _history = <AiTurn>[];

  ChatWait wait = ChatWait.none;
  List<ChatChoice> choices = const [];
  bool thinking = false;

  /// The user said goodbye or "থামো": stop listening until the mic is tapped.
  bool ended = false;

  Command? _current;
  final _queue = <Command>[];
  bool _askingAll = false;
  bool _allYes = false;
  int _savedInBatch = 0;

  String _person = '';
  int _amount = 0;
  LedgerKind? _kind;
  LedgerAdd? _src;
  CategoryGuess? _cat;
  LedgerEntry? _setEntry;

  /// Short listening (yes/no) is enough for the next answer.
  bool get expectsShortAnswer => wait == ChatWait.yesNo || wait == ChatWait.amount || wait == ChatWait.name;

  DateTime get _now => brain.services.now();
  static const _yesNoChoices = [ChatChoice('না', 'না'), ChatChoice('হ্যাঁ', 'হ্যাঁ')];

  /// One thing the user said, typed or tapped. Returns what to say aloud.
  Future<String> hear(String said) async {
    final t = said.trim();
    if (t.isEmpty) return '';
    ended = false;
    messages.add(ChatMessage.user(t));
    notifyListeners();
    final out = <String>[];
    if (_isStop(t)) {
      if (wait != ChatWait.none) _dropPending();
      ended = true;
      _say(out, 'ঠিক আছে, থামলাম। দরকার হলে মাইক চাপবেন।');
      notifyListeners();
      return out.join(' ');
    }
    if (wait != ChatWait.none) {
      if (await _answer(t, out)) {
        notifyListeners();
        return out.join(' ');
      }
      _dropPending();
    }

    thinking = brain.aiOn;
    notifyListeners();
    final (cmds, problem) = await brain.understandAll(t, history: List.of(_history));
    thinking = false;
    if (problem != null) messages.add(ChatMessage.app(problem, info: true));

    final saves = cmds.where(isSave).toList();
    final others = cmds.where((c) => !isSave(c)).toList();
    final secret = mentionsSecret(t) || cmds.any((c) => c is VaultQuery);
    _history.add(AiTurn.user(secret ? '[গোপন কিছু জানতে চাইলেন — ফোনেই উত্তর দেওয়া হলো]' : t));
    final tags = <String>[];

    for (final c in others) {
      if (c is NotUnderstood && (saves.isNotEmpty || others.length > 1)) continue;
      final text = answerText(brain.data, c, _now) ?? '';
      _say(out, text, vault: _vaultFor(c), links: _linksFor(c));
      tags.add(c is AiReply || c is SmallTalk || c is NotUnderstood ? text : '[অ্যাপ নিজের রাখা তথ্য থেকে উত্তর দিল]');
      if (c is SmallTalk && c.kind == Talk.bye) ended = true;
    }
    if (saves.length == 1) {
      await _start(saves.single, out);
    } else if (saves.length > 1) {
      _queue
        ..clear()
        ..addAll(saves);
      _askingAll = true;
      _ask(out, 'আপনার কথা থেকে ${bnDigits(saves.length)}টা জিনিস পেলাম। সবগুলো রেখে দিই?', ChatWait.yesNo,
          choices: _yesNoChoices, facts: [for (final c in saves) summaryLine(c)]);
    }
    if (saves.isNotEmpty) tags.add('[রাখার আগে জিজ্ঞেস করছে: ${saves.map(summaryLine).join('; ')}]');
    _history.add(AiTurn.app(tags.isEmpty ? '[ঠিক আছে]' : tags.join(' ')));
    notifyListeners();
    return out.join(' ');
  }

  /// A line from another screen (e.g. saved on the edit screen).
  void addInfo(String text) {
    messages.add(ChatMessage.app(text, info: true));
    notifyListeners();
  }

  /// The user went to fix something on its own screen: forget the question.
  void dropPending() {
    _dropPending();
    notifyListeners();
  }

  bool _isStop(String t) {
    final n = normalize(t.replaceAll(RegExp(r'[।?!,.]'), ''));
    return _stopWords.any((w) => normalize(w) == n);
  }

  List<VaultItem> _vaultFor(Command c) {
    if (c is VaultQuery) return vaultAnswerItems(brain.data, c);
    if (c is SearchQuery) return [for (final h in searchAll(brain.data, c.terms).take(6)) if (h is VaultHit) h.item];
    return const [];
  }

  List<ChatLink> _linksFor(Command c) {
    final d = brain.data;
    if (c is LedgerQuery && c.ask == LedgerAsk.person) {
      final p = balanceOf(d.ledger, c.person!);
      if (p != null) return [ChatLink(LinkKind.person, '${possessive(p.name)} খাতা দেখুন', person: p.name)];
    }
    if (c is ReminderQuery && searchReminders(d, c.terms).isNotEmpty) return const [ChatLink(LinkKind.reminders, 'রিমাইন্ডার দেখুন')];
    return const [];
  }

  void _say(List<String> out, String text,
      {List<String> facts = const [], List<VaultItem> vault = const [], List<ChatLink> links = const [], bool speak = true}) {
    if (text.isEmpty) return;
    messages.add(ChatMessage.app(text, facts: facts, vault: vault, links: links));
    if (speak) out.add(speakableNumbers(text));
  }

  void _ask(List<String> out, String question, ChatWait w,
      {List<ChatChoice> choices = const [], List<String> facts = const [], List<ChatLink> links = const []}) {
    _say(out, question, facts: facts, links: links);
    wait = w;
    this.choices = choices;
  }

  void _dropPending() {
    if (wait != ChatWait.none || _current != null || _queue.isNotEmpty) {
      messages.add(ChatMessage.app('আগের প্রশ্নটা বাদ দিলাম, কিছু রাখা হয়নি।', info: true));
    }
    _reset();
    _queue.clear();
  }

  void _reset() {
    wait = ChatWait.none;
    choices = const [];
    _current = null;
    _askingAll = false;
    _allYes = false;
    _savedInBatch = 0;
  }

  // ── Working through the things to save ──

  Future<void> _start(Command c, List<String> out) async {
    _current = c;
    switch (c) {
      case LedgerAdd():
        _src = c;
        _person = c.person.trim();
        _amount = c.amount;
        _kind = c.kind;
        await _nextLedgerStep(out);
      case LedgerSet():
        _setEntry = entryToReach(brain.data.ledger, c.person, c.balance, _now);
        if (_setEntry == null) {
          final cur = balanceWith(brain.data.ledger, c.person);
          _say(out, 'খাতায় তো এটাই লেখা আছে — ${owesText(c.person, cur)}। নতুন করে কিছু লাগবে না।', speak: !_allYes);
          await _done(out);
          return;
        }
        if (_allYes) return _saveCurrent(out);
        String owes(int bal) => bal >= 0 ? '${possessive(c.person)} কাছে আপনার ${bnNumber(bal)} টাকা পাওনা' : '${toPerson(c.person)} আপনার ${bnNumber(-bal)} টাকা দিতে হবে';
        final known = balanceOf(brain.data.ledger, c.person);
        _ask(
          out,
          known == null
              ? '${c.person} নামে তো কারও হিসাব নেই। লেনদেনের খাতায় নতুন করে খুলে লিখে রাখি যে ${owes(c.balance)}?'
              : 'খাতায় এখন লেখা আছে, ${owes(known.balance)}। মিলিয়ে লিখে রাখি যে ${owes(c.balance)}?',
          ChatWait.yesNo,
          choices: _yesNoChoices,
        );
      case NoteAdd():
        final ai = c.category;
        _cat = ai == null ? guessCategory(brain.data, c.text) : CategoryGuess(ai, isNew: !brain.data.noteCategories.contains(ai));
        if (_allYes) return _saveCurrent(out);
        final cat = _cat!;
        _ask(
          out,
          cat.isNew ? '“${c.text}” — এটা নতুন ধরনের তথ্য। ‘${cat.name}’ নামে নতুন বিভাগ খুলে রেখে দিই?' : '“${c.text}” — ‘${cat.name}’ বিভাগে রেখে দিই?',
          ChatWait.yesNo,
          choices: _yesNoChoices,
        );
      default:
        await _done(out);
    }
  }

  Future<void> _nextLedgerStep(List<String> out) async {
    final src = _src!;
    if (_person.isEmpty) {
      final known = knownPeople(brain.data.ledger).take(4);
      _ask(out, 'টাকার হিসাব লেনদেনের খাতায় রাখি। কার সাথে লেনদেন হলো? নামটা বলেন।', ChatWait.name, choices: [
        for (final k in known) ChatChoice(k, k),
        if (src.allowExpense) const ChatChoice('নিজের খরচ, রাখব না', 'অন্য খরচ'),
      ]);
      return;
    }
    if (_amount <= 0) {
      _ask(out, '${toPerson(_person)} নিয়ে কত টাকার কথা? অঙ্কটা বলেন।', ChatWait.amount);
      return;
    }
    if (_kind == null) {
      final opts = src.options.isEmpty ? LedgerKind.values : src.options;
      _ask(out, _clarifyQuestion(opts, src.allowExpense), ChatWait.kind, choices: [
        for (final k in opts) ChatChoice(k.label, k.label),
        if (src.allowExpense) const ChatChoice('অন্য খরচ', 'অন্য খরচ'),
      ]);
      return;
    }
    if (_allYes) return _saveCurrent(out);
    _ask(out, confirmQuestion(_kind!, _person, _amount), ChatWait.yesNo, choices: _yesNoChoices, links: [
      ChatLink(LinkKind.editEntry, 'তারিখ বা অঙ্ক বদলান',
          entry: LedgerAdd(src.transcript, person: _person, amount: _amount, kind: _kind)),
    ]);
  }

  String _clarifyQuestion(List<LedgerKind> o, bool allowExpense) {
    if (o.contains(LedgerKind.repaid) && allowExpense) {
      return 'একটু বুঝিয়ে বলেন — এটা কি আগের দেনা শোধ করলেন, নাকি নতুন করে ধার দিলেন? নাকি অন্য কোনো খরচ?';
    }
    if (o.contains(LedgerKind.received) && o.contains(LedgerKind.borrowed)) {
      return 'একটু বুঝিয়ে বলেন — উনি কি আগের টাকা ফেরত দিলেন, নাকি আপনি নতুন করে ধার নিলেন?';
    }
    return 'একটু বুঝিয়ে বলেন — এটা কোন ধরনের লেনদেন?';
  }

  /// A long new sentence instead of an answer.
  bool _looksNew(String t) => words(normalize(t)).length >= 4;

  /// Handles [t] as the answer to the waiting question. False when it is
  /// not an answer but something new.
  Future<bool> _answer(String t, List<String> out) async {
    switch (wait) {
      case ChatWait.none:
        return false;
      case ChatWait.yesNo:
        final yn = yesNo(t);
        if (yn == null) {
          if (_looksNew(t)) return false;
          _say(out, 'ঠিক ধরতে পারিনি। “হ্যাঁ” বা “না” বলেন।');
          return true;
        }
        wait = ChatWait.none;
        choices = const [];
        if (_askingAll) {
          _askingAll = false;
          if (yn) {
            _allYes = true;
            _savedInBatch = 0;
            await _done(out);
          } else {
            _queue.clear();
            _say(out, 'আচ্ছা, কিছুই রাখলাম না।');
          }
          return true;
        }
        if (yn) {
          await _saveCurrent(out);
        } else {
          _say(out, 'আচ্ছা, রাখলাম না।');
          await _done(out);
        }
        return true;
      case ChatWait.name:
        if (_src!.allowExpense && pickSpokenOption(t, const [], allowExpense: true) == 'expense') {
          _say(out, 'ঠিক আছে, এটা লেনদেনের খাতায় রাখলাম না।');
          await _done(out);
          return true;
        }
        if (_looksNew(t) && findAmount(normalize(t)) != null) return false;
        final n = spokenName(t, knownPeople(brain.data.ledger));
        if (n.isEmpty) {
          _say(out, 'নামটা ধরতে পারিনি। আবার বলেন।');
          return true;
        }
        _person = n;
        wait = ChatWait.none;
        await _nextLedgerStep(out);
        return true;
      case ChatWait.amount:
        final a = findAmount(normalize(t));
        if (a == null || a <= 0) {
          if (_looksNew(t)) return false;
          _say(out, 'টাকার অঙ্কটা ধরতে পারিনি। আবার বলেন।');
          return true;
        }
        _amount = a;
        wait = ChatWait.none;
        await _nextLedgerStep(out);
        return true;
      case ChatWait.kind:
        final src = _src!;
        final opts = src.options.isEmpty ? LedgerKind.values : src.options;
        final pick = pickSpokenOption(t, [for (final o in opts) o.name], allowExpense: src.allowExpense);
        final choice = pick ?? (yesNo(t) == true ? src.suggested?.name : null);
        if (choice == null) {
          if (_looksNew(t)) return false;
          _say(out, 'ঠিক ধরতে পারিনি। একটা বেছে নিন, বা বলেন — যেমন “শোধ” বা “নতুন ধার”।');
          return true;
        }
        wait = ChatWait.none;
        choices = const [];
        if (choice == 'expense') {
          _say(out, 'ঠিক আছে, এটা লেনদেনের খাতায় রাখলাম না।');
          await _done(out);
          return true;
        }
        _kind = LedgerKind.values.byName(choice);
        await _nextLedgerStep(out);
        return true;
    }
  }

  Future<void> _saveCurrent(List<String> out) async {
    final c = _current;
    final quiet = _allYes;
    switch (c) {
      case LedgerAdd():
        final kind = _kind!;
        final after = balanceAfter(brain.data.ledger, _person, kind, _amount);
        await brain.saveEntry(LedgerEntry(person: _person, kind: kind, amount: _amount, date: dayOnly(_now), note: ''));
        _say(out, quiet ? 'লিখলাম: ${describe(kind, _person, _amount)}।' : savedSentence(kind, _person, _amount, after),
            links: [ChatLink(LinkKind.person, '${possessive(_person)} খাতা দেখুন', person: _person)], speak: !quiet);
        _history.add(AiTurn.app('[লিখে রাখা হলো: ${describe(kind, _person, _amount)}]'));
      case LedgerSet():
        final e = _setEntry!;
        await brain.saveEntry(e);
        _say(out, quiet ? 'লিখলাম: ${summaryLine(c)}।' : 'ঠিক আছে, লিখে রাখলাম। ${balanceSentence(e.person, c.balance)}',
            links: [ChatLink(LinkKind.person, '${possessive(e.person)} খাতা দেখুন', person: e.person)], speak: !quiet);
        _history.add(AiTurn.app('[লিখে রাখা হলো: ${summaryLine(c)}]'));
      case NoteAdd():
        final cat = _cat?.name ?? defaultNoteCategory;
        await brain.saveNote(Note(title: noteTitleFrom(c.text), body: c.text, category: cat));
        _say(out, quiet ? 'রাখলাম: ${c.text} (‘$cat’)' : 'ঠিক আছে, ‘$cat’ বিভাগে রেখে দিলাম।',
            links: const [ChatLink(LinkKind.notes, 'নোট দেখুন')], speak: !quiet);
        _history.add(AiTurn.app('[নোট রাখা হলো, বিভাগ: $cat]'));
      default:
        break;
    }
    if (quiet) _savedInBatch++;
    await _done(out);
  }

  /// The current thing is finished: go on with the next one, if any.
  Future<void> _done(List<String> out) async {
    _current = null;
    wait = ChatWait.none;
    choices = const [];
    if (_queue.isNotEmpty) {
      await _start(_queue.removeAt(0), out);
      return;
    }
    if (_allYes) {
      if (_savedInBatch > 0) _say(out, 'সব রেখে দিলাম। আর কিছু?');
      _allYes = false;
      _savedInBatch = 0;
    }
  }
}
