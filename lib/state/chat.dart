import 'package:flutter/foundation.dart';

import '../logic/answers.dart';
import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/categories.dart';
import '../logic/ledger.dart';
import '../logic/parser.dart';
import '../logic/phrases.dart';
import '../logic/plan.dart';
import '../logic/search.dart';
import '../logic/talk.dart';
import '../logic/when.dart';
import '../models/models.dart';
import '../services/ai.dart';
import '../ui/yes_no.dart' show pickSpokenOption;
import 'brain.dart';

/// What the chat is waiting to hear.
enum ChatWait { none, yesNo, name, amount, kind, callee, phone, message, contactName, topic, topicName, reminderTime, project, collect }

/// What the user said they want to talk about at the start.
enum Topic {
  ledger('লেনদেন'),
  reminder('রিমাইন্ডার'),
  task('কাজের তালিকা'),
  note('নোট'),
  call('ফোন ও মেসেজ'),
  custom('');

  const Topic(this.label);
  final String label;
}

/// A reminder whose time is still to be asked.
final _noTime = DateTime(2000);

/// A button under the latest question; tapping it is the same as saying
/// [answer].
class ChatChoice {
  const ChatChoice(this.label, this.answer);
  final String label;
  final String answer;
}

enum LinkKind { person, editEntry, notes, reminders, tasks, contacts, cash }

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

  // A call or message being set up.
  CallPerson? _call;
  String _callee = '';
  String _phone = '';
  String _text = '';

  /// Several people fit the name said: the user picks one before any call.
  List<Contact> _calleeChoices = const [];

  /// Set when the dialer/SMS/WhatsApp should open once the app has
  /// finished speaking; the screen calls [launchPending].
  (Via, String, String)? pendingLaunch;

  bool _warnedExact = false;

  /// The subject chosen at the start ("লেনদেন", "রিমাইন্ডার", or a new
  /// category of the user's own); null = anything.
  Topic? topic;
  String customTopic = '';

  /// A list said over several breaths ("আজকের কাজের তালিকা… সকালে স্কুলে
  /// যাবো… তারপর বাজার…"): kept quietly until the user says "শেষ" or
  /// stops talking, then read back once.
  final List<String> _collected = [];
  DateTime? _collectDue;
  bool get collecting => wait == ChatWait.collect;

  /// The start of a sentence that ended in "আর…" / "তারপর…": joined with
  /// what comes next instead of being answered half-way.
  String _held = '';
  String _pendingTitle = '';

  String get topicLabel => topic == null ? '' : (topic == Topic.custom ? customTopic : topic!.label);

  static const _topicChoices = [
    ChatChoice('লেনদেন', 'লেনদেন'),
    ChatChoice('রিমাইন্ডার', 'রিমাইন্ডার'),
    ChatChoice('কাজের তালিকা', 'কাজের তালিকা'),
    ChatChoice('ফোন ও মেসেজ', 'ফোন ও মেসেজ'),
    ChatChoice('নোট', 'নোট'),
    ChatChoice('অন্য কিছু', 'অন্য কিছু'),
  ];

  /// The opening question. Returns what to say aloud.
  /// The opening: the full question on screen, but only a few words aloud
  /// so the microphone opens at once and the user can just start talking.
  String greet() {
    const q = 'কী করতে চান — লেনদেন, রিমাইন্ডার, কাজের তালিকা, ফোন-মেসেজ, নাকি অন্য কিছু? বিষয়টা বলুন, অথবা সরাসরি বলে ফেলুন।';
    _ask(<String>[], q, ChatWait.topic, choices: _topicChoices);
    notifyListeners();
    return 'জি, বলুন।';
  }

  /// Ask for the subject again (the topic pill was tapped).
  String chooseTopic() {
    _reset();
    _collected.clear();
    _collectDue = null;
    _held = '';
    _queue.clear();
    topic = null;
    customTopic = '';
    return greet();
  }

  /// A known subject in a short answer, or null.
  Topic? _topicWord(String t) {
    final n = normalize(t);
    bool has(List<String> ks) => ks.any((k) => n.contains(normalize(k)));
    if (has(['লেনদেন', 'টাকা', 'হিসাব', 'বাকি', 'ধার', 'দেনা', 'পাওনা', 'ledger', 'taka'])) return Topic.ledger;
    if (has(['রিমাইন্ডার', 'মনে করানো', 'মনে করাবে', 'অ্যালার্ম', 'এলার্ম', 'alarm', 'reminder'])) return Topic.reminder;
    if (has(['কাজের তালিকা', 'কাজের লিস্ট', 'কাজ', 'টু ডু', 'todo', 'লিস্ট', 'তালিকা', 'task'])) return Topic.task;
    if (has(['ফোন', 'মেসেজ', 'ম্যাসেজ', 'কল', 'হোয়াটসঅ্যাপ', 'whatsapp', 'sms', 'এসএমএস'])) return Topic.call;
    if (has(['নোট', 'মনে রাখা', 'note'])) return Topic.note;
    return null;
  }

  /// "দোকানের মাল নিয়ে" → "দোকানের মাল".
  String _categoryName(String t) {
    final c = tidy(cutWords(t, const ['বিষয়ে', 'বিষয়', 'নিয়ে', 'সম্পর্কে', 'ব্যাপারে', 'বিভাগ', 'বিভাগে', 'ক্যাটাগরি', 'নতুন', 'একটা', 'খোলো', 'খুলুন', 'চাই']));
    return c.isEmpty ? t.trim() : c;
  }

  void _setTopic(Topic tp, List<String> out, {String name = ''}) {
    topic = tp;
    customTopic = name;
    wait = ChatWait.none;
    choices = const [];
    final String say;
    switch (tp) {
      case Topic.ledger:
        say = 'ঠিক আছে, লেনদেন। বলুন — যেমন “সজীবকে ৫০০ টাকা দিলাম” বা “করিম ৫০০ টাকার মাল বাকিতে নিল”।';
      case Topic.reminder:
        say = 'ঠিক আছে, রিমাইন্ডার। কী, আর কখন মনে করাব বলুন — যেমন “কাল সকাল ১০টায় মিটিং”।';
      case Topic.task:
        final due = _collectDue;
        final dayWord = due == null
            ? ''
            : due == dayOnly(_now)
                ? 'আজকের '
                : due == dayOnly(_now).add(const Duration(days: 1))
                    ? 'কালকের '
                    : '${shortDate(due)}-এর ';
        say = 'ঠিক আছে, $dayWordকাজের তালিকা। একটা একটা করে বলুন, যতক্ষণ খুশি — শেষ হলে বলুন “শেষ”।';
      case Topic.call:
        say = 'ঠিক আছে। কাকে ফোন বা মেসেজ দেব বলুন — যেমন “রহিমকে ফোন দাও”।';
      case Topic.note:
        say = 'ঠিক আছে, নোট। কী মনে রাখব বলুন।';
      case Topic.custom:
        final exists = brain.data.noteCategories.any((c) => normalize(c) == normalize(name));
        say = exists ? 'ঠিক আছে, ‘$name’ বিভাগে আছি। এখন যা বলবেন, এখানে রাখব।' : 'ঠিক আছে, ‘$name’ নামে নতুন বিভাগ খুললাম। এখন যা বলবেন, এই বিভাগে রাখব।';
    }
    _say(out, say);
    _history.add(AiTurn.app('[ব্যবহারকারী এখন ‘$topicLabel’ বিষয়ে বলবেন]'));
    if (tp == Topic.task) {
      _collected.clear();
      wait = ChatWait.collect;
    }
  }

  static final _finishWords = [
    for (final w in const [
      'শেষ', 'শেষ শেষ', 'ব্যস', 'বাস', 'এইটুকুই', 'এটুকুই', 'এইটুকু', 'আর নেই', 'আর না', 'আর কিছু না', 'আর কিছু নেই', 'হয়ে গেছে', 'হয়েছে',
      'এটাই', 'এগুলোই', 'এই কয়টা', 'এই কয়টাই', 'এই কটা', 'রাখো', 'রেখে দাও', 'সেভ করো', 'সেভ কর', 'ডান', 'done', 'finish', 'শেষ করো', 'বলা শেষ',
      'ঠিক আছে রাখো', 'এবার রাখো', 'লিস্ট শেষ', 'তালিকা শেষ',
    ])
      normalize(w),
  ];

  bool _isFinish(String t) {
    final n = normalize(t.replaceAll(RegExp(r'[।?!,.]'), ''));
    return _finishWords.contains(n) || (_finishWords.any((w) => n.endsWith(' $w')) && words(n).length <= 4);
  }

  /// One breath of a list: its separate items ("…যাবো, তারপর বাজার করব").
  static List<String> _items(String t) => t
      .split(RegExp(r'[,।;\n]+|\s+(?:আর|এবং|তারপর|তার পর|এরপর|এর পর|পরে|তারপরে)\s+'))
      .map((x) => tidy(x.trim()))
      .where((x) => words(normalize(x)).isNotEmpty)
      .toList();

  /// Something is waiting for more words (a list, or a half sentence).
  bool get hasPending => (collecting && _collected.isNotEmpty) || _held.isNotEmpty;

  /// The user went quiet: finish the list, or answer the half sentence.
  Future<String> flush() async {
    if (collecting && _collected.isNotEmpty) return finishCollecting();
    if (_held.isEmpty) return '';
    final h = _held;
    _held = '';
    final out = <String>[];
    return _understand(h, out);
  }

  /// "শেষ" (or the user went quiet): read the whole list back once.
  String finishCollecting() {
    final out = <String>[];
    _finishCollect(out);
    notifyListeners();
    return out.join(' ');
  }

  void _finishCollect(List<String> out) {
    wait = ChatWait.none;
    choices = const [];
    final tasks = <Command>[];
    for (final line in _collected) {
      for (final item in _items(line)) {
        final w = parseWhen(item, _now);
        var title = w != null && w.hasDay ? tidy(withoutWhen(item)) : item;
        if (title.isEmpty) title = item;
        tasks.add(TaskAdd(item, title: title, due: w != null && w.hasDay ? w.day : _collectDue));
      }
    }
    _collected.clear();
    if (tasks.isEmpty) {
      _say(out, 'কোনো কাজ পেলাম না। আবার বলবেন?');
      return;
    }
    _queue
      ..clear()
      ..addAll(tasks);
    _askingAll = true;
    _ask(out, '${bnDigits(tasks.length)}টা কাজ পেলাম। সবগুলো তালিকায় রাখি?', ChatWait.yesNo,
        choices: _yesNoChoices, facts: [for (final c in tasks) summaryLine(c)]);
    _history.add(AiTurn.app('[কাজের তালিকা নিল, রাখার আগে জিজ্ঞেস করছে]'));
  }

  /// Fits what was understood to the chosen subject: in রিমাইন্ডার a plain
  /// sentence is a reminder, in a new category it is a note there, and so on.
  List<Command> _applyTopic(List<Command> cmds, String said) {
    final tp = topic;
    if (tp == null) return cmds;
    final asking = isQuestionText(said);
    bool plain(Command c) => c is NotUnderstood || (c is SearchQuery && !asking) || (c is NoteAdd && c.category == null) || c is TaskAdd;
    return [
      for (final c in cmds)
        switch (tp) {
          Topic.custom when c is NoteAdd => NoteAdd(c.transcript, text: c.text, fromStatement: c.fromStatement, category: customTopic),
          Topic.custom when c is NotUnderstood || (c is SearchQuery && !asking) =>
            NoteAdd(said, text: said.trim(), fromStatement: true, category: customTopic),
          Topic.note when c is NotUnderstood || (c is SearchQuery && !asking) => NoteAdd(said, text: said.trim(), fromStatement: true),
          Topic.reminder when plain(c) => _reminderFrom(c is TaskAdd ? c.title : said),
          Topic.task when plain(c) && c is! TaskAdd => _taskFrom(said),
          Topic.ledger when plain(c) && c is! TaskAdd && findAmount(normalize(said)) != null =>
            LedgerAdd(said, person: '', amount: findAmount(normalize(said))!, options: LedgerKind.values, allowExpense: true),
          Topic.call when c is NotUnderstood || c is SearchQuery || c is NoteAdd => CallPerson(said,
              person: spokenName(said, [for (final x in brain.data.contacts) x.name]),
              via: normalize(said).contains(normalize('হোয়াটসঅ্যাপ'))
                  ? Via.whatsapp
                  : (normalize(said).contains(normalize('মেসেজ')) ? Via.sms : Via.call)),
          _ => c,
        },
    ];
  }

  ReminderAdd _reminderFrom(String said) {
    final w = parseWhen(said, _now);
    var title = tidy(withoutWhen(said));
    if (title.isEmpty) title = said.trim();
    return ReminderAdd(said, title: title, at: w?.at ?? _noTime);
  }

  TaskAdd _taskFrom(String said) {
    final w = parseWhen(said, _now);
    var title = w != null && w.hasDay ? tidy(withoutWhen(said)) : said.trim();
    if (title.isEmpty) title = said.trim();
    return TaskAdd(said, title: title, due: w != null && w.hasDay ? w.day : null);
  }

  /// Short listening (yes/no) is enough for the next answer.
  bool get expectsShortAnswer =>
      const {ChatWait.yesNo, ChatWait.amount, ChatWait.name, ChatWait.callee, ChatWait.phone, ChatWait.contactName}.contains(wait);

  /// Opens the dialer / SMS app / WhatsApp prepared by the last answer.
  Future<void> launchPending() async {
    final p = pendingLaunch;
    pendingLaunch = null;
    if (p == null) return;
    final ok = await brain.services.launcher.open(p.$1, p.$2, text: p.$3);
    if (!ok) addInfo('এই ফোনে এটা খোলার মতো অ্যাপ পাওয়া গেল না।');
  }

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

    // "…যাবো আর" / "প্রথমে…": the sentence is not finished — wait for the rest.
    final whole = _held.isEmpty ? t : '$_held $t';
    if (RegExp(r'(?:^|\s)(?:আর|এবং|তারপর|তার পর|এরপর|এর পর|আরও|আরো|আর হ্যাঁ|শোনো|মানে|যেমন)$').hasMatch(normalize(whole)) ||
        RegExp(r'(?:^|\s)(?:আর|এবং|তারপর|তার পর|এরপর|এর পর|আরও|আরো|আর হ্যাঁ|শোনো|মানে|যেমন)$').hasMatch(whole.trim().replaceAll(RegExp(r'[।?!,.]+$'), ''))) {
      _held = whole;
      notifyListeners();
      return '';
    }
    _held = '';
    if (whole != t) return _understand(whole, out);
    return _understand(t, out);
  }

  Future<String> _understand(String t, List<String> out) async {
    thinking = brain.aiOn;
    notifyListeners();
    final (understood, problem) = await brain.understandAll(t, history: List.of(_history));
    final cmds = _applyTopic(understood, t);
    thinking = false;
    if (problem != null) messages.add(ChatMessage.app(problem, info: true));

    final saves = cmds.where(isSave).toList();
    final others = cmds.where((c) => !isSave(c)).toList();
    final secret = mentionsSecret(t) || cmds.any((c) => c is VaultQuery);
    _history.add(AiTurn.user(secret ? '[গোপন কিছু জানতে চাইলেন — ফোনেই উত্তর দেওয়া হলো]' : t));
    final tags = <String>[];

    for (final c in others) {
      if (c is NotUnderstood && (saves.isNotEmpty || others.length > 1)) continue;
      if (c is TaskDone) {
        _taskDone(c, out);
        tags.add('[কাজ শেষ হিসেবে দাগ দেওয়া হলো]');
        continue;
      }
      if (c is CallPerson) {
        _startCall(c, out);
        tags.add('[ফোন/মেসেজের ব্যবস্থা করছে]');
        continue;
      }
      final text = answerText(brain.data, c, _now) ?? '';
      _say(out, text, vault: _vaultFor(c), links: _linksFor(c));
      // Money answers are kept in the AI's view of the conversation so a
      // follow-up ("তাহলে সব মিলিয়ে কত?") makes sense; saved notes, tasks
      // and logins are not.
      final shareable = c is AiReply || c is SmallTalk || c is NotUnderstood || c is LedgerQuery || c is CashQuery;
      tags.add(shareable ? text : '[অ্যাপ নিজের রাখা তথ্য থেকে উত্তর দিল]');
      if (c is SmallTalk && c.kind == Talk.whatCanYouDo) _say(out, _skills, speak: false);
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
    if (c is TaskQuery || c is Briefing) return const [ChatLink(LinkKind.tasks, 'কাজের তালিকা')];
    if (c is CashQuery) return const [ChatLink(LinkKind.cash, 'আয়-ব্যয় দেখুন')];
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
    _call = null;
    _calleeChoices = const [];
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
      case TaskAdd():
        if (_allYes) return _saveCurrent(out);
        final due = c.due == null ? '' : ' (${sayWhen(c.due!, _now, withTime: false)})';
        _ask(out, '“${c.title}”$due — কাজের তালিকায় তুলে রাখি?', ChatWait.yesNo, choices: _yesNoChoices);
      case ReminderAdd():
        if (c.at == _noTime) {
          _pendingTitle = c.title;
          _ask(out, '“${c.title}” — কখন মনে করাব? যেমন “কাল সকাল ১০টায়” বা “এক ঘণ্টা পরে”।', ChatWait.reminderTime);
          return;
        }
        if (!c.at.isAfter(_now)) {
          _say(out, 'ওই সময়টা তো পার হয়ে গেছে। কখন মনে করাব, আরেকবার বলবেন?');
          await _done(out);
          return;
        }
        if (_allYes) return _saveCurrent(out);
        final again = c.repeat == Repeat.none ? '' : ', ${c.repeat.label}';
        final time = bnTime(c.at.hour, c.at.minute);
        final q = c.repeat.isInterval
            ? '${c.repeat.label} “${c.title}” মনে করিয়ে দেব, প্রথমবার $time-এ — ঠিক আছে?'
            : c.repeat == Repeat.daily
                ? 'প্রতিদিন $time-এ “${c.title}” মনে করিয়ে দেব — ঠিক আছে?'
                : '${sayWhen(c.at, _now)}-এ “${c.title}” মনে করিয়ে দেব$again — ঠিক আছে?';
        _ask(out, q, ChatWait.yesNo, choices: _yesNoChoices);
      case CashAdd():
        if (c.amount <= 0) {
          _ask(out, 'কত টাকা?', ChatWait.amount);
          return;
        }
        if (c.project != null && c.project!.trim().isEmpty) {
          final open = brain.data.projects.where((p) => !p.closed).toList();
          if (open.length == 1) {
            return _start(CashAdd(c.transcript, kind: c.kind, amount: c.amount, category: c.category, project: open.first.name), out);
          }
          _ask(out, 'কোন প্রজেক্টে লিখব? নামটা বলুন।', ChatWait.project, choices: [for (final p in open.take(5)) ChatChoice(p.name, p.name)]);
          return;
        }
        if (_allYes) return _saveCurrent(out);
        final inOut = c.kind == CashKind.income ? 'আয়' : 'খরচ';
        final String q;
        if (c.project != null) {
          final exists = projectByName(brain.data, c.project!) != null;
          q = '${exists ? '' : 'নতুন প্রজেক্ট খুলে '}‘${c.project}’ প্রজেক্টে ${bnNumber(c.amount)} টাকা $inOut হিসেবে লিখি?';
        } else {
          q = '$inOut হিসেবে লিখি — ${c.category}, ${bnNumber(c.amount)} টাকা?';
        }
        _ask(out, q, ChatWait.yesNo, choices: _yesNoChoices);
      case ContactAdd():
        if (c.name.trim().isEmpty) {
          _ask(out, 'নম্বরটা কার নামে রাখব?', ChatWait.contactName);
          return;
        }
        if (_allYes) return _saveCurrent(out);
        final old = findContact(brain.data, c.name);
        _ask(
          out,
          old != null && old.phone.isNotEmpty && old.phone != c.phone
              ? '${possessive(old.name)} আগের নম্বর ${bnDigits(old.phone)}। নতুন নম্বর ${bnDigits(c.phone)} দিয়ে বদলে দিই?'
              : '${possessive(c.name)} নম্বর ${bnDigits(c.phone)} — রেখে দিই?',
          ChatWait.yesNo,
          choices: _yesNoChoices,
        );
      default:
        await _done(out);
    }
  }

  static const _skills = 'আমি যা যা পারি: কাজের তালিকা রাখা (“কাল ব্যাংকে যেতে হবে”), সময় ধরে মনে করানো (“বিকেল ৪টায় মিটিংয়ের কথা মনে করিয়ে দিও”), '
      'ফোন বা মেসেজ (“রহিমকে ফোন দাও”, “করিমকে মেসেজ দাও যে মাল পাঠিয়েছি”), নম্বর রাখা, কাস্টমারের বাকি আর ধার-দেনার হিসাব '
      '(“করিম ৫০০ টাকার মাল বাকিতে নিল”), নোট, পাসওয়ার্ড, আর “আজ আমার কী কী আছে?” বললে সারাদিনের সারাংশ।';

  /// "নিজের খরচ": a money sentence with no one owing becomes spending.
  Future<void> _asOwnSpending(List<String> out) async {
    final src = _src!;
    final amount = _amount > 0 ? _amount : src.amount;
    await _start(CashAdd(src.transcript, kind: CashKind.expense, amount: amount, category: categoryFor(normalize(src.transcript), CashKind.expense)), out);
  }

  void _taskDone(TaskDone c, List<String> out) {
    final open = brain.data.tasks.where((t) => !t.done);
    final found = matchTasks(open, c.terms);
    if (found.isEmpty) {
      _say(out, 'এমন কোনো বাকি কাজ তালিকায় পেলাম না।', links: const [ChatLink(LinkKind.tasks, 'কাজের তালিকা')]);
      return;
    }
    final t = found.first;
    brain.setTaskDone(t, true);
    final left = brain.data.tasks.where((x) => !x.done && x.id != t.id).length;
    _say(out, 'বাহ! “${t.title}” শেষ হিসেবে দাগ দিলাম।${left > 0 ? ' আর ${bnDigits(left)}টা কাজ বাকি।' : ' সব কাজ শেষ!'}',
        links: const [ChatLink(LinkKind.tasks, 'কাজের তালিকা')]);
  }

  void _startCall(CallPerson c, List<String> out) {
    _call = c;
    _callee = c.person.trim();
    _phone = c.phone;
    _text = c.text.trim();
    _nextCallStep(out);
  }

  void _nextCallStep(List<String> out) {
    final c = _call!;
    if (_phone.isEmpty) {
      if (_callee.isEmpty) {
        _ask(out, c.via == Via.call ? 'কাকে ফোন দেব? নামটা বলুন।' : 'কাকে পাঠাব? নামটা বলুন।', ChatWait.callee, choices: [
          for (final x in brain.data.contacts.where((x) => x.phone.isNotEmpty).take(4)) ChatChoice(x.name, x.name),
        ]);
        return;
      }
      final contact = findContact(brain.data, _callee);
      final many = contact != null ? const <Contact>[] : contactMatches(brain.data, _callee).where((x) => x.phone.isNotEmpty).toList();
      if (contact != null && contact.phone.isNotEmpty) {
        _callee = contact.name;
        _phone = contact.phone;
      } else if (many.length > 1) {
        // Never guess between people: ask which one.
        _calleeChoices = many.take(6).toList();
        final names = _calleeChoices.map((x) => x.name).toList();
        _ask(
          out,
          '“$_callee” নামে ${bnDigits(many.length)} জন আছেন — ${nameList(names.take(4).toList(), unit: 'জন')}। কাকে ${c.via == Via.call ? 'ফোন দেব' : 'পাঠাব'}?',
          ChatWait.callee,
          choices: [for (final x in _calleeChoices) ChatChoice('${x.name} · ${showPhone(x.phone)}', '${x.name} ${x.phone}')],
        );
        return;
      } else {
        _ask(out, '${possessive(_callee)} নম্বর তো রাখা নেই। নম্বরটা বলবেন? রেখে দেব, পরের বার আর লাগবে না।', ChatWait.phone);
        return;
      }
    }
    if (c.via != Via.call && _text.isEmpty) {
      _ask(out, 'কী লিখব? বলুন।', ChatWait.message);
      return;
    }
    final who = _callee.isEmpty ? bnDigits(_phone) : _callee;
    if (_callee.isNotEmpty) _say(out, '$_callee · ${showPhone(_phone)}', speak: false);
    final say = switch (c.via) {
      Via.call => '${toPerson(who)} ফোন দিচ্ছি। কল বোতাম চাপলেই কথা বলতে পারবেন।',
      Via.sms => '${toPerson(who)} মেসেজ লিখে দিলাম — “$_text”। পাঠাতে শুধু Send চাপুন।',
      Via.whatsapp => 'WhatsApp-এ ${toPerson(who)} লিখে দিলাম — “$_text”। Send চাপলেই যাবে।',
    };
    _say(out, say);
    pendingLaunch = (c.via, _phone, _text);
    ended = true;
    _call = null;
    _history.add(AiTurn.app('[${c.via == Via.call ? 'ফোন' : 'মেসেজ'} খোলা হলো: $who]'));
  }

  /// Which of [_calleeChoices] the answer means: a tapped choice or a number
  /// ("…৩৪৪"), "প্রথম জন / দ্বিতীয়টা", or a fuller name that fits only one.
  Contact? _pickCallee(String said) {
    final list = _calleeChoices;
    final digits = asciiDigits(said).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 3) {
      final hits = list.where((x) => asciiDigits(x.phone).replaceAll(RegExp(r'[^0-9]'), '').endsWith(digits.length > 10 ? digits.substring(digits.length - 10) : digits)).toList();
      if (hits.length == 1) return hits.single;
    }
    final n = normalize(said);
    const order = [
      ['প্রথম', '১ম', 'এক নম্বর', 'একনম্বর', 'first', '1st'],
      ['দ্বিতীয়', '২য়', 'দুই নম্বর', 'দুইনম্বর', 'second', '2nd'],
      ['তৃতীয়', '৩য়', 'তিন নম্বর', 'third', '3rd'],
      ['চতুর্থ', '৪র্থ', 'চার নম্বর', 'fourth'],
      ['পঞ্চম', '৫ম', 'পাঁচ নম্বর', 'fifth'],
      ['ষষ্ঠ', '৬ষ্ঠ', 'ছয় নম্বর', 'sixth'],
    ];
    for (var i = 0; i < order.length && i < list.length; i++) {
      if (order[i].any((w) => n.contains(normalize(w)))) return list[i];
    }
    if (n == normalize('শেষ জন') || n == normalize('শেষেরটা')) return list.last;
    final narrowed = contactMatches(AppData(contacts: list), said);
    return narrowed.length == 1 ? narrowed.single : null;
  }

  Future<void> _savePhone(String name, String phone) async {
    final old = findContact(brain.data, name);
    await brain.saveContact(Contact(
      id: old?.id,
      name: old?.name ?? name,
      phone: phone,
      email: old?.email ?? '',
      note: old?.note ?? '',
    ));
  }

  Future<void> _nextLedgerStep(List<String> out) async {
    final src = _src!;
    if (_person.isEmpty) {
      final known = knownPeople(brain.data.ledger).take(4);
      _ask(out, 'টাকার হিসাব লেনদেনের খাতায় রাখি। কার সাথে লেনদেন হলো? নামটা বলেন।', ChatWait.name, choices: [
        for (final k in known) ChatChoice(k, k),
        if (src.allowExpense) const ChatChoice('নিজের খরচ', 'অন্য খরচ'),
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
      case ChatWait.collect:
        if (_isFinish(t)) {
          if (_collected.isEmpty) {
            wait = ChatWait.none;
            _say(out, 'ঠিক আছে, কিছু রাখা হলো না।');
          } else {
            _finishCollect(out);
          }
          return true;
        }
        // A question or a money/call request in the middle: answer it normally.
        if (isQuestionText(t) && _collected.isEmpty) return false;
        _collected.add(t);
        messages.add(ChatMessage.app('${bnDigits(_collected.length)}. $t', info: true));
        return true;
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
          wait = ChatWait.none;
          choices = const [];
          await _asOwnSpending(out);
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
      case ChatWait.topic:
        final n = normalize(t);
        if (n == normalize('অন্য কিছু') || n == normalize('অন্যান্য') || n == normalize('অন্য')) {
          _ask(out, 'কোন বিষয়ে? নামটা বলুন — নতুন বিভাগ খুলে দেব।', ChatWait.topicName);
          return true;
        }
        final tp = _topicWord(t);
        // "আজকের কাজের তালিকা", "কালকের কাজ": a list is coming, not a question.
        final dayless = tidy(cutWords(t, const ['আজকের', 'আজ', 'কালকের', 'কাল', 'আগামীকালের', 'সারাদিনের', 'পুরো দিনের', 'সারা দিনের', 'আমার', 'আমাদের', 'দিনের', 'এখন']));
        if (tp == Topic.task && words(normalize(dayless)).length <= 3 && _topicWord(dayless) == Topic.task && !isQuestionText(t)) {
          final w = parseWhen(t, _now);
          _collectDue = w != null && w.hasDay ? w.day : (normalize(t).contains(normalize('কাল')) ? dayOnly(_now).add(const Duration(days: 1)) : dayOnly(_now));
          _setTopic(Topic.task, out);
          return true;
        }
        final count = words(n).length;
        final c = Parser(ledger: brain.data.ledger, tasks: brain.data.tasks, contacts: brain.data.contacts, now: _now).parse(t);
        final actionable = !(c is NotUnderstood || c is SearchQuery || c is NoteAdd);
        if (tp != null && (count <= 2 || (!actionable && count <= 3))) {
          _collectDue = null;
          _setTopic(tp, out);
          return true;
        }
        // A whole request instead of a subject: just do it.
        if (actionable || count > 3) {
          wait = ChatWait.none;
          choices = const [];
          return false;
        }
        // Words that match no subject: a new category of the user's own.
        _setTopic(Topic.custom, out, name: _categoryName(t));
        return true;
      case ChatWait.topicName:
        final tp = _topicWord(t);
        if (tp != null && words(normalize(t)).length <= 2) {
          _setTopic(tp, out);
        } else {
          _setTopic(Topic.custom, out, name: _categoryName(t));
        }
        return true;
      case ChatWait.reminderTime:
        final w = parseWhen(t, _now);
        if (w == null) {
          if (_looksNew(t)) return false;
          _say(out, 'সময়টা ধরতে পারিনি। যেমন বলুন “কাল সকাল ১০টায়” বা “৩০ মিনিট পরে”।');
          return true;
        }
        wait = ChatWait.none;
        await _start(ReminderAdd(t, title: _pendingTitle, at: w.at), out);
        return true;
      case ChatWait.callee:
        if (_calleeChoices.isNotEmpty) {
          final picked = _pickCallee(t);
          if (picked == null) {
            if (_looksNew(t)) return false;
            _say(out, 'কোন জন, বুঝতে পারিনি। নামটা পুরো বলুন, বা নিচ থেকে বেছে নিন।');
            return true;
          }
          _callee = picked.name;
          _phone = picked.phone;
          _calleeChoices = const [];
          wait = ChatWait.none;
          choices = const [];
          _nextCallStep(out);
          return true;
        }
        final n = spokenName(t, [for (final c in brain.data.contacts) c.name, ...knownPeople(brain.data.ledger)]);
        if (n.isEmpty) {
          if (_looksNew(t)) return false;
          _say(out, 'নামটা ধরতে পারিনি। আবার বলুন।');
          return true;
        }
        _callee = n;
        wait = ChatWait.none;
        choices = const [];
        _nextCallStep(out);
        return true;
      case ChatWait.phone:
        final ph = findPhone(t);
        if (ph == null) {
          if (_looksNew(t) && findAmount(normalize(t)) == null) return false;
          _say(out, 'নম্বরটা ধরতে পারিনি। আবার বলুন — ১১ সংখ্যার মোবাইল নম্বর।');
          return true;
        }
        _phone = ph;
        wait = ChatWait.none;
        if (_callee.isNotEmpty) {
          await _savePhone(_callee, ph);
          messages.add(ChatMessage.app('${possessive(_callee)} নম্বর যোগাযোগে রেখে দিলাম।', info: true));
        }
        _nextCallStep(out);
        return true;
      case ChatWait.message:
        _text = t;
        wait = ChatWait.none;
        _nextCallStep(out);
        return true;
      case ChatWait.contactName:
        final c = _current;
        final n = spokenName(t, [for (final x in brain.data.contacts) x.name, ...knownPeople(brain.data.ledger)]);
        if (n.isEmpty || c is! ContactAdd) {
          _say(out, 'নামটা ধরতে পারিনি। আবার বলুন।');
          return true;
        }
        wait = ChatWait.none;
        await _start(ContactAdd(c.transcript, name: n, phone: c.phone), out);
        return true;
      case ChatWait.amount:
        final a = findAmount(normalize(t));
        if (a == null || a <= 0) {
          if (_looksNew(t)) return false;
          _say(out, 'টাকার অঙ্কটা ধরতে পারিনি। আবার বলেন।');
          return true;
        }
        wait = ChatWait.none;
        final cur = _current;
        if (cur is CashAdd) {
          await _start(CashAdd(cur.transcript, kind: cur.kind, amount: a, category: cur.category, project: cur.project), out);
          return true;
        }
        _amount = a;
        await _nextLedgerStep(out);
        return true;
      case ChatWait.project:
        final cur = _current;
        wait = ChatWait.none;
        choices = const [];
        if (cur is! CashAdd) return false;
        var name = tidy(cutWords(t, const ['প্রজেক্ট', 'প্রজেক্টে', 'প্রজেক্টের', 'প্রকল্প', 'প্রকল্পে', 'নামে', 'নাম']));
        if (name.isEmpty) name = t.trim();
        final known = projectByName(brain.data, name);
        await _start(CashAdd(cur.transcript, kind: cur.kind, amount: cur.amount, category: cur.category, project: known?.name ?? name), out);
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
          await _asOwnSpending(out);
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
      case TaskAdd():
        await brain.saveTask(Task(title: c.title, due: c.due));
        _say(out, quiet ? 'কাজ: ${c.title}' : 'ঠিক আছে, কাজের তালিকায় তুললাম।',
            links: const [ChatLink(LinkKind.tasks, 'কাজের তালিকা')], speak: !quiet);
        _history.add(AiTurn.app('[কাজের তালিকায় রাখা হলো]'));
      case ReminderAdd():
        await brain.saveReminder(Reminder(
          title: c.title,
          date: DateTime(c.at.year, c.at.month, c.at.day),
          hour: c.at.hour,
          minute: c.at.minute,
          daysBefore: 0,
          repeat: c.repeat,
        ));
        _say(out, quiet ? 'মনে করাব: ${c.title}' : (c.repeat.isInterval || c.repeat == Repeat.daily ? 'ঠিক আছে, ${c.repeat.label} মনে করিয়ে দেব।' : 'ঠিক আছে, ${sayWhen(c.at, _now)}-এ মনে করিয়ে দেব।'),
            links: const [ChatLink(LinkKind.reminders, 'রিমাইন্ডার দেখুন')], speak: !quiet);
        _history.add(AiTurn.app('[রিমাইন্ডার রাখা হলো]'));
        if (!_warnedExact && !await brain.services.notifier.exactAllowed()) {
          _warnedExact = true;
          messages.add(ChatMessage.app('ঠিক মিনিটে বাজাতে “আরও” → “ঠিক সময়ে রিমাইন্ডার” চালু করে নিন।', info: true));
        }
      case CashAdd():
        Project? project;
        if (c.project != null) project = await brain.projectNamed(c.project!);
        await brain.saveCash(CashEntry(
          kind: c.kind,
          amount: c.amount,
          category: c.category,
          note: c.transcript.trim(),
          date: _now,
          projectId: project?.id,
        ));
        final String done;
        if (project != null) {
          done = 'লিখলাম। ‘${project.name}’ প্রজেক্টে এখন হাতে আছে ${bnNumber(projectSums(brain.data.cash, project.id).balance)} টাকা।';
        } else {
          final m = monthSums(brain.data.cash, _now);
          done = c.kind == CashKind.expense ? 'লিখলাম। এই মাসে মোট খরচ ${bnNumber(m.expense)} টাকা।' : 'লিখলাম। এই মাসে মোট আয় ${bnNumber(m.income)} টাকা।';
        }
        _say(out, quiet ? 'লিখলাম: ${summaryLine(c)}' : done, links: const [ChatLink(LinkKind.cash, 'আয়-ব্যয় দেখুন')], speak: !quiet);
        _history.add(AiTurn.app('[লেখা হলো: ${summaryLine(c)}]'));
      case ContactAdd():
        await _savePhone(c.name, c.phone);
        _say(out, quiet ? 'নম্বর: ${c.name}' : 'ঠিক আছে, ${possessive(c.name)} নম্বর রেখে দিলাম।',
            links: const [ChatLink(LinkKind.contacts, 'যোগাযোগ দেখুন')], speak: !quiet);
        _history.add(AiTurn.app('[নম্বর রাখা হলো: ${c.name}]'));
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
