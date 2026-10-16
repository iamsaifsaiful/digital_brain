import 'package:flutter/foundation.dart';

import '../logic/lang.dart';
import '../logic/ai_map.dart' show answeredByAi;
import '../logic/app_map.dart';
import '../logic/ask.dart' show infoTopic;
import '../logic/manage.dart';
import '../logic/meaning.dart';
import '../services/trace.dart';
import '../logic/me.dart';
import '../logic/answers.dart';
import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/categories.dart';
import '../logic/health.dart';
import '../logic/ledger.dart';
import '../logic/parser.dart';
import '../logic/phrases.dart';
import '../logic/plan.dart';
import '../logic/proactive.dart';
import '../logic/pro.dart' show freeVaultItems, freeLedgerPeople, freeReminders;
import '../logic/search.dart';
import '../logic/talk.dart';
import '../logic/when.dart';
import '../models/models.dart';
import '../services/ai.dart';
import '../ui/yes_no.dart' show pickSpokenOption;
import 'brain.dart';

/// What the chat is waiting to hear.
enum ChatWait { none, yesNo, name, amount, kind, callee, phone, message, contactName, topic, topicName, reminderTime, reminderTitle, project, collect, whichPerson, whichItem, clarify }

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

/// A button under the latest question; tapping it is the same as saying
/// [answer].
class ChatChoice {
  const ChatChoice(this.label, this.answer);
  final String label;
  final String answer;
}

enum LinkKind { person, editEntry, notes, reminders, tasks, contacts, cash, special, memory, doc, health, page }

/// "খাতা দেখুন" and similar, under an app message.
class ChatLink {
  const ChatLink(this.kind, this.label, {this.person, this.entry, this.docId, this.page, this.folder});
  final LinkKind kind;
  final String label;
  final String? person;

  /// For [LinkKind.page]: an [AppPlace] id, and a paper folder or note category in it.
  final String? page;
  final String? folder;

  /// For [LinkKind.doc]: the document to open (after fingerprint or PIN).
  final String? docId;
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

  /// "ফিরিয়ে নিন": the data as it was before this save, for a few seconds.
  String? undo;
  DateTime? undoAt;

  /// How long the undo button stays.
  static const undoFor = Duration(seconds: 10);

  bool undoable(DateTime now) => undo != null && undoAt != null && now.difference(undoAt!) < undoFor;
}

const _stopWords = ['থামো', 'থাম', 'থামেন', 'বন্ধ করো', 'বন্ধ কর', 'বন্ধ করেন', 'চুপ', 'চুপ করো', 'স্টপ', 'stop', 'ব্যাস', 'বাস', 'আর না', 'এখন না', 'শেষ'];

/// A conversation: the user says (or types) one thing after another and
/// the app answers each, asking short follow-ups when it needs a name, an
/// amount or a yes. Long messages are split into the separate facts in
/// them, shown as a list and saved together on one yes.
class ChatController extends ChangeNotifier {
  /// [restored]: an earlier conversation opened from the menu (shown, but
  /// not sent to the AI again).
  ChatController(this.brain, {List<ChatMessage> restored = const []}) {
    messages.addAll(restored);
  }

  final Brain brain;
  final messages = <ChatMessage>[];

  /// The user has said something in this conversation.
  bool get started => messages.any((m) => m.fromUser);

  /// The conversation as the AI may see it: the user's own sentences and
  /// tags in place of anything that came from saved data.
  final _history = <AiTurn>[];

  /// A page the user asked to open ("নোট খোলো"): the chat screen opens it
  /// after the reply and clears this.
  ChatLink? openNow;

  /// The conversation is spoken: the quick AI model answers, so there is no wait.
  bool voiceMode = false;

  ChatWait wait = ChatWait.none;
  List<ChatChoice> choices = const [];
  bool thinking = false;

  /// The user said goodbye or "থামো": stop listening until the mic is tapped.
  bool ended = false;

  Command? _current;

  /// "…মুছে দাও" / "…বদলে দাও": the thing meant, the change, and the
  /// choices when several match.
  Target? _target;
  Change _change = const Change();
  List<Target> _targets = const [];

  /// The last thing saved, with the data before it — so "না, রিমাইন্ডার
  /// দাও" right after can turn a note into a reminder.
  (Command, String, DateTime)? _lastSave;

  /// What existed before that save (so "শেষটা মুছে দাও" finds what it made).
  Set<String> _idsBeforeSave = const {};
  final _queue = <Command>[];
  bool _askingAll = false;
  bool _allYes = false;
  int _savedInBatch = 0;

  String _person = '';
  int _amount = 0;
  LedgerKind? _kind;

  /// The person's number for a ধার-দেনা entry, found in the book or in
  /// যোগাযোগ, and shown before saving.
  String _ledgerPhone = '';

  /// The day a money event happened when said ("গতকাল"); null = today.
  DateTime? _ledgerDate;
  bool _phoneChecked = false;

  /// Same-name people to choose from: (name, phone).
  List<(String, String)> _personChoices = const [];
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

  /// A reminder being completed: what, which day (if said), how often.
  String _pendingTitle = '';
  DateTime? _pendingDay;
  DateTime? _pendingAt;
  Repeat _pendingRepeat = Repeat.none;
  bool _pendingAlarm = false;
  int _pendingBefore = 0;
  List<int> _pendingDays = const [];

  /// The last request that did not lead to anything to save (an answer, or
  /// "didn't understand"), so a short follow-up like "আজ" or "সন্ধ্যায়"
  /// can complete it.
  String _lastSaid = '';
  DateTime? _lastSaidAt;

  /// What the conversation is about right now: the person last written or
  /// asked about (so "ও আরও দুইশ নিয়েছে" and "এখন মোট কত?" mean them), or
  /// the user's own income/spending. Kept for this session only.
  String _focusPerson = '';
  bool _focusCash = false;
  DateTime? _focusAt;

  /// The user chose the kind of a money entry from the choices: that is
  /// their consent — no second "লিখে রাখি?".
  bool _chosen = false;

  /// The command being saved right now, so a repeated "হ্যাঁ" (voice and a
  /// tap together, or a callback fired twice) can never save it twice.
  Command? _executing;
  Command? _executed;

  /// The answers offered by a clarifying question ("কোনটা জানতে চান?").
  List<(String, Command)> _clarifyOptions = const [];

  /// The last money list asked for, so "আর গত মাসে?" or "শুধু খরচ" follows it.
  MoneyListQuery? _focusMoney;

  void _focusOn({String person = '', bool cash = false}) {
    _focusPerson = person;
    _focusCash = cash;
    _focusAt = _now;
  }

  bool get _focusFresh => _focusAt != null && _now.difference(_focusAt!).inMinutes < 20;

  String get topicLabel => topic == null ? '' : (topic == Topic.custom ? customTopic : topic!.label);

  static List<ChatChoice> get _topicChoices => [
    ChatChoice(tr('লেনদেন'), 'লেনদেন'),
    ChatChoice(tr('রিমাইন্ডার'), 'রিমাইন্ডার'),
    ChatChoice(tr('কাজের তালিকা'), 'কাজের তালিকা'),
    ChatChoice(tr('ফোন ও মেসেজ'), 'ফোন ও মেসেজ'),
    ChatChoice(tr('নোট'), 'নোট'),
    ChatChoice(tr('অন্য কিছু'), 'অন্য কিছু'),
  ];

  /// The opening question. Returns what to say aloud.
  /// The opening: the full question on screen, but only a few words aloud
  /// so the microphone opens at once and the user can just start talking.
  String greet() {
    final q = tr('কী করতে চান — লেনদেন, রিমাইন্ডার, কাজের তালিকা, ফোন-মেসেজ, নাকি অন্য কিছু? বিষয়টা বলুন, অথবা সরাসরি বলে ফেলুন।');
    _ask(<String>[], q, ChatWait.topic, choices: _topicChoices);
    notifyListeners();
    return tr('জি, বলুন।');
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

  /// "আজকের কাজের তালিকা", "কালকের কাজের লিস্ট": the start of a list (not
  /// "…দেখাও" or a question). Sets the day the list is for.
  bool _startsList(String t) {
    if (isQuestionText(t)) return false;
    final n = normalize(t);
    if (const ['দেখাও', 'দেখান', 'দেখি', 'বলো', 'বলুন', 'শোনাও', 'দাও', 'দিন', 'দেন', 'দিবা', 'কী', 'কি', 'কত', 'বাকি'].any((w) => words(n).contains(normalize(w)))) return false;
    final tp = _topicWord(t);
    final dayless = tidy(cutWords(t, const ['আজকের', 'আজ', 'কালকের', 'কাল', 'আগামীকালের', 'সারাদিনের', 'পুরো দিনের', 'সারা দিনের', 'আমার', 'আমাদের', 'দিনের', 'এখন', 'নতুন']));
    if (tp != Topic.task || words(normalize(dayless)).length > 3 || _topicWord(dayless) != Topic.task) return false;
    if (!const ['তালিকা', 'লিস্ট', 'list', 'টু ডু', 'todo'].any((w) => n.contains(normalize(w)))) return false;
    final w = parseWhen(t, _now);
    _collectDue = w != null && w.hasDay ? w.day : (n.contains(normalize('কাল')) ? dayOnly(_now).add(const Duration(days: 1)) : dayOnly(_now));
    return true;
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
                ? tr('আজকের ')
                : due == dayOnly(_now).add(const Duration(days: 1))
                    ? tr('কালকের ')
                    : trf('{0}-এর ', [shortDate(due)]);
        say = 'ঠিক আছে, $dayWordকাজের তালিকা। একটা একটা করে বলুন, যতক্ষণ খুশি — শেষ হলে বলুন “শেষ”।';
      case Topic.call:
        say = 'ঠিক আছে। কাকে ফোন বা মেসেজ দেব বলুন — যেমন “রহিমকে ফোন দাও”।';
      case Topic.note:
        say = 'ঠিক আছে, নোট। কী মনে রাখব বলুন।';
      case Topic.custom:
        final exists = brain.data.noteCategories.any((c) => normalize(c) == normalize(name));
        say = exists ? trf('ঠিক আছে, ‘{0}’ বিভাগে আছি। এখন যা বলবেন, এখানে রাখব।', [name]) : trf('ঠিক আছে, ‘{0}’ নামে নতুন বিভাগ খুললাম। এখন যা বলবেন, এই বিভাগে রাখব।', [name]);
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
    // The list is done: what comes next is understood as usual again.
    if (topic == Topic.task) topic = null;
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
      _say(out, tr('কোনো কাজ পেলাম না। আবার বলবেন?'));
      return;
    }
    _queue
      ..clear()
      ..addAll(tasks);
    _askingAll = true;
    _ask(out, trf('{0}টা কাজ পেলাম। সবগুলো তালিকায় রাখি?', [bnDigits(tasks.length)]), ChatWait.yesNo,
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
    return ReminderAdd(said, title: title, at: w?.at ?? noTimeYet);
  }

  TaskAdd _taskFrom(String said) {
    final w = parseWhen(said, _now);
    var title = w != null && w.hasDay ? tidy(withoutWhen(said)) : said.trim();
    if (title.isEmpty) title = said.trim();
    return TaskAdd(said, title: title, due: w != null && w.hasDay ? w.day : null);
  }

  /// The chat asked something and waits for the answer.
  bool get waiting => wait != ChatWait.none;

  /// Said by voice and acted on at once, without collecting more speech:
  /// a question, opening a page, small talk, stop or cancel.
  /// A recogniser's final text is not the end of what the user wants to say
  /// (people pause mid-question), so everything else is collected until the
  /// user says it is all.
  bool quickRequest(String t) {
    if (_isStop(t) || isCancel(t)) return true;
    final c = parseAll(t, brain.data.ledger, tasks: brain.data.tasks, contacts: brain.data.contacts, now: _now);
    return c.length == 1 && c.first is SmallTalk && words(normalize(t)).length <= 4;
  }

  /// A whole request by itself ("রহিমকে ৫০০ টাকা ধার দিলাম", "কাল ১০টায়
  /// মিটিং মনে করিয়ে দিও"): when the user goes quiet after it, it is sent
  /// at once — no "আর কিছু বলতে চান?" before the one confirmation. A plain
  /// statement, a list or a sentence left open still waits for more.
  bool isCompleteRequest(String t) {
    final n = normalize(t);
    if (n.isEmpty) return false;
    if (RegExp(r'(?:^|\s)(?:আর|এবং|তারপর|তার পর|এরপর|এর পর|আরও|আরো|মানে|যেমন|কিন্তু|যে)$').hasMatch(n)) return false;
    if (const ['তালিকা', 'লিস্ট', 'list'].any((w) => n.contains(normalize(w)))) return false;
    final c = parseAll(t, brain.data.ledger, tasks: brain.data.tasks, contacts: brain.data.contacts, folders: brain.folderHints, now: _now);
    return c.isNotEmpty && c.every((x) => x is! NotUnderstood && x is! SearchQuery && !(x is NoteAdd && x.fromStatement));
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
  static List<ChatChoice> get _yesNoChoices => [ChatChoice(tr('না'), 'না'), ChatChoice(tr('হ্যাঁ'), 'হ্যাঁ')];

  /// One thing the user said, typed or tapped. Returns what to say aloud.
  Future<String> hear(String said) async {
    final t = said.trim();
    if (t.isEmpty) return '';
    ended = false;
    messages.add(ChatMessage.user(t));
    notifyListeners();
    final out = <String>[];
    // "শেষ" ends a list being collected; it is not "stop listening".
    if (_isStop(t) && !(collecting && _isFinish(t))) {
      if (wait != ChatWait.none) _dropPending();
      ended = true;
      _say(out, tr('ঠিক আছে, থামলাম। দরকার হলে মাইক চাপবেন।'));
      notifyListeners();
      return out.join(' ');
    }
    // "রিমাইন্ডার লিখে রাখো", "না, কাজের তালিকায় রাখো": about the previous
    // message, which is kept that way instead.
    final redirect = redirectOf(t);
    if (redirect != null && await _redirect(redirect, t, out)) {
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

    // "আজকের কাজের তালিকা": a list is coming, said over several breaths.
    if (_held.isEmpty && _startsList(t)) {
      _history.add(AiTurn.user(t));
      _setTopic(Topic.task, out);
      notifyListeners();
      return out.join(' ');
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
    // "মুছে দিও না", "বন্ধ কোরো না": nothing is done — decided here, before
    // the AI (if on) could read it as "মুছে দাও".
    if (!isQuestionText(whole) && negatedRequest(normalize(whole))) {
      _history.add(AiTurn.user(whole));
      final text = talkReply(Talk.wontDo, _now);
      _say(out, text);
      _history.add(AiTurn.app(text));
      _lastSaid = '';
      notifyListeners();
      return out.join(' ');
    }
    // "আর গত মাসে?" right after a money list: the same list, another span.
    final follow = _moneyFollowUp(whole);
    if (follow != null) {
      _history.add(AiTurn.user(whole));
      Trace.log('understood', 'follow-up', {'text': whole, 'means': traceLine(follow)});
      _answerMoney(follow, out);
      notifyListeners();
      return out.join(' ');
    }
    // "এখন মোট কত?" — the total of whatever was being talked about, read
    // from the saved data (never worked out from the chat).
    final total = _totalFromContext(whole);
    if (total != null) {
      _history.add(AiTurn.user(whole));
      final text = answerText(brain.data, total, _now) ?? '';
      _say(out, text, links: _linksFor(total));
      _history.add(AiTurn.app(text));
      notifyListeners();
      return out.join(' ');
    }
    return _understand(_withContext(_resolvePronouns(whole)), out, shown: whole);
  }

  MoneyListQuery? _moneyFollowUp(String t) {
    final q = _focusMoney;
    if (q == null || !_focusFresh) return null;
    final n = normalize(t);
    if (words(n).length > 5) return null;
    final p = periodIn(n, _now);
    if (p == null) return null;
    // Only a span said ("আর গত মাসে?", "গত সপ্তাহের?"), nothing else asked.
    final rest = words(n).where((x) => !const ['আর', 'আরও', 'তাহলে', 'গত', 'এই', 'এ', 'মাসে', 'মাসের', 'সপ্তাহে', 'সপ্তাহের', 'বছর', 'বছরের', 'আজ', 'আজকে', 'গতকাল', 'কী', 'কি', 'কত', 'দেখাও'].map(normalize).contains(x));
    if (rest.isNotEmpty) return null;
    return MoneyListQuery(t, from: p.$1, to: p.$2, label: p.$3, category: q.category, person: q.person);
  }

  /// "এখন মোট কত?": the person talked about, or this month's spending.
  /// Null when it is not such a question, or nothing is being talked about.
  Command? _totalFromContext(String t) {
    final n = normalize(t);
    if (!asksTotal(n) || !_focusFresh) return null;
    // A person or a subject named in the question itself wins.
    final named = knownPeople(brain.data.ledger).where((k) => n.contains(normalize(k)));
    if (named.isNotEmpty) return LedgerQuery(t, ask: LedgerAsk.person, person: named.first);
    if (_focusPerson.isNotEmpty) return LedgerQuery(t, ask: LedgerAsk.person, person: _focusPerson);
    if (_focusCash) return CashQuery(t);
    return null;
  }

  /// "ও", "সে", "ওকে", "ওর" → the person being talked about, when there is
  /// one and no one else is named. Otherwise the words stay as they are
  /// (and the app asks whom it means).
  String _resolvePronouns(String t) {
    if (!_focusFresh || _focusPerson.isEmpty) return t;
    final n = normalize(t);
    final others = knownPeople(brain.data.ledger).where((k) => normalize(k) != normalize(_focusPerson) && n.contains(normalize(k)));
    if (others.isNotEmpty) return t;
    final parts = t.trim().split(RegExp(r'\s+'));
    var changed = false;
    for (var i = 0; i < parts.length; i++) {
      final m = RegExp(r'^(.*?)([,।!?]*)$').firstMatch(parts[i])!;
      final role = pronounRole(m[1]!, first: i == 0 || (i == 1 && normalize(parts[0]) == normalize('আর')));
      if (role == null) continue;
      parts[i] = switch (role) {
            PronounRole.doer => _focusPerson,
            PronounRole.to => toPerson(_focusPerson),
            PronounRole.of => possessive(_focusPerson),
          } +
          m[2]!;
      changed = true;
    }
    return changed ? parts.join(' ') : t;
  }

  Future<bool> _redirect(String kind, String said, List<String> out) async {
    bool movable(Command c) => c is NoteAdd || c is TaskAdd || c is ReminderAdd || c is MemoryAdd;
    String textOf(Command c) => switch (c) { NoteAdd(:final text) => text, MemoryAdd(:final text) => text, _ => c.transcript };
    String kindOf(Command c) => switch (c) { ReminderAdd(:final alarm) => alarm ? 'alarm' : 'reminder', TaskAdd() => 'task', _ => 'note' };
    String? src;
    var moved = false;
    final cur = _current;
    final last = _lastSave;
    if (wait != ChatWait.none && cur != null && movable(cur)) {
      // Asked about the previous message ("নতুন বিভাগে রাখি?"): keep it the way said instead.
      src = textOf(cur);
      _dropPending();
    } else if (last != null && movable(last.$1) && _now.difference(last.$3).inMinutes < 5) {
      if (kindOf(last.$1) == kind) {
        _say(out, tr('জি, ওটা সেভাবেই রাখা আছে।'));
        return true;
      }
      await brain.restoreSnapshot(last.$2);
      src = textOf(last.$1);
      moved = true;
    } else {
      // The message before this one.
      final users = [for (final m in messages) if (m.fromUser) m.text];
      if (users.length >= 2) src = users[users.length - 2];
    }
    if (src == null || src.trim().isEmpty || redirectOf(src) != null) return false;
    _lastSave = null;
    _history.add(AiTurn.user(said));
    final cmd = convertTo(kind, src, brain.data.ledger, _now);
    if (moved) messages.add(ChatMessage.app(tr('আগেরটা সরিয়ে নিলাম।'), info: true));
    final ready = (cmd is ReminderAdd && !cmd.needsTime && !cmd.needsTitle) || cmd is TaskAdd;
    if (ready) {
      _current = cmd;
      await _saveCurrent(out);
    } else {
      await _start(cmd, out);
    }
    return true;
  }

  /// "…মুছে দাও", "…বদলে দাও", "৫০০ না ৬০০": find what is meant, then ask.
  Future<void> _manage(ManageItem c, List<String> out) async {
    final text = normalize(c.transcript);
    final last = _lastSave;
    // "শেষটা মুছে দাও" / "শেষটা বদলাও": what the last save made.
    var found = <Target>[];
    if (asksForLast(text) && last != null && _now.difference(last.$3).inMinutes < 30) {
      found = [for (final t in targetsIn(brain.data, _now)) if (!_idsBeforeSave.contains(t.id)) t].take(1).toList();
    }
    if (found.isEmpty) found = findTargets(brain.data, c.transcript, _now);
    final verb = c.action == 'delete' ? tr('মুছবো') : (c.action == 'stop' ? tr('বন্ধ করবো') : tr('বদলাবো'));
    if (c.action == 'stop') found = [for (final t in found) if (t.kind == ItemKind.reminder && (brain.data.reminders.where((r) => r.id == t.id).firstOrNull?.enabled ?? false)) t];
    if (found.isEmpty) {
      final kind = kindNamed(text);
      _say(out, trf('কোনটা {0}, খুঁজে পেলাম না। নাম, তারিখ বা টাকার অঙ্ক বলে আরেকবার বলুন — যেমন “রহিমের ৫০০ টাকার লেনদেনটা মুছে দাও”।', [verb]),
          links: [if (kind != null && _pageOf(kind) != null) ChatLink(LinkKind.page, trf('খুলুন: {0}', [tr(kind.bn)]), page: _pageOf(kind))]);
      return;
    }
    _current = c;
    if (found.length > 1) {
      _targets = found;
      _ask(out, trf('কয়েকটা মিলেছে — কোনটা {0}?', [verb]), ChatWait.whichItem,
          facts: [for (var i = 0; i < found.length; i++) '${bnDigits(i + 1)}. ${found[i].label}'],
          choices: [for (var i = 0; i < found.length; i++) ChatChoice(bnDigits(i + 1), '${i + 1}')]);
      return;
    }
    await _confirmManage(found.single, out);
  }

  Future<void> _confirmManage(Target t, List<String> out) async {
    final c = _current as ManageItem;
    _target = t;
    if (c.action == 'delete') {
      _ask(out, trf('“{0}” মুছে দেবো?', [t.label]), ChatWait.yesNo, choices: _yesNoChoices);
      return;
    }
    if (c.action == 'stop') {
      _ask(out, trf('“{0}” বন্ধ করে দেবো? মুছবে না, পরে আবার চালু করা যাবে।', [t.label]), ChatWait.yesNo, choices: _yesNoChoices);
      return;
    }
    _change = changeIn(t, c.transcript, _now);
    if (_change.isEmpty) {
      // No new time or amount said: open it to change by hand.
      final link = ChatLink(LinkKind.page, trf('বদলান: {0}', [t.label]), page: 'edit:${t.kind.name}', folder: t.id);
      _say(out, trf('“{0}” — বদলানোর পাতা খুলছি।', [t.label]), links: [link]);
      openNow = link;
      _current = null;
      wait = ChatWait.none;
      return;
    }
    final now = _change.amount != null
        ? trf('{0} টাকা', [bnNumber(_change.amount!)])
        : (_change.at != null && t.kind == ItemKind.reminder ? sayWhen(_change.at!, _now) : sayWhen(_change.day!, _now, withTime: false));
    _ask(out, trf('“{0}” বদলে {1} করে দেবো?', [t.label, now]), ChatWait.yesNo, choices: _yesNoChoices);
  }

  String? _pageOf(ItemKind k) => switch (k) {
        ItemKind.reminder => 'reminders',
        ItemKind.task => 'tasks',
        ItemKind.note => 'notes',
        ItemKind.ledger => 'ledger',
        ItemKind.cash => 'money',
        ItemKind.contact => 'contacts',
        ItemKind.special => 'special',
        ItemKind.medicine => 'medicines',
        ItemKind.habit => 'habits',
        ItemKind.memory => 'memory',
        ItemKind.doc => 'docs',
      };

  /// A short follow-up ("আজ", "সন্ধ্যায়", "৫০০", "রহিম") that means
  /// nothing alone but completes the previous request: the two together.
  String _withContext(String t) {
    final prev = _lastSaid;
    final at = _lastSaidAt;
    if (prev.isEmpty || at == null || _now.difference(at).inMinutes > 10) return t;
    if (words(normalize(t)).length > 4 || isQuestionText(t) || mentionsSecret(t)) return t;
    final d = brain.data;
    List<Command> rules(String s) => parseAll(s, d.ledger, tasks: d.tasks, contacts: d.contacts, folders: brain.folderHints, now: _now);
    bool acts(Command c) => (isSave(c) && c is! NoteAdd) || c is CallPerson;
    // Only a fragment that means nothing by itself is joined.
    if (!rules(t).every((c) => c is NotUnderstood || c is SearchQuery || c is NoteAdd)) return t;
    final both = '$prev $t';
    return rules(both).any(acts) ? both : t;
  }

  /// [t] is what is understood; [shown] is what the user actually said
  /// this time (kept for the AI's view of the conversation).
  Future<String> _understand(String t, List<String> out, {String? shown}) async {
    thinking = brain.aiOn;
    notifyListeners();
    final (understood, problem) = await brain.understandAll(t, history: List.of(_history), fast: voiceMode);
    final cmds = _applyTopic(understood, t);
    thinking = false;
    if (problem != null) messages.add(ChatMessage.app(problem, info: true));

    Trace.log('understood', 'intent', {'text': t, 'commands': cmds.map(traceLine).join(' + '), 'ai': brain.aiOn});
    final saves = cmds.where(isSave).toList();
    final others = cmds.where((c) => !isSave(c)).toList();
    final secret = mentionsSecret(t) || cmds.any((c) => c is VaultQuery);
    _history.add(AiTurn.user(secret ? tr('[গোপন কিছু জানতে চাইলেন — ফোনেই উত্তর দেওয়া হলো]') : (shown ?? t)));
    // Remember an unfinished request (nothing to save came of it) so the
    // next short message can complete it.
    final finished = saves.isNotEmpty || others.any((c) => c is CallPerson || c is TaskDone);
    _lastSaid = secret || finished ? '' : t;
    _lastSaidAt = _now;
    final tags = <String>[];

    // The AI answered a question about the user's things in its own words:
    // say that, with the app's links (e.g. "রহিমের খাতা দেখুন").
    final aiAnswer = brain.aiShareData && others.whereType<AiReply>().isNotEmpty && others.any(answeredByAi);
    final aiLinks = aiAnswer ? [for (final c in others.where(answeredByAi)) ..._linksFor(c)] : const <ChatLink>[];
    for (final c in others) {
      if (c is NotUnderstood && (saves.isNotEmpty || others.length > 1)) continue;
      if (aiAnswer && answeredByAi(c)) continue;
      if (aiAnswer && c is AiReply) {
        _say(out, c.text, links: aiLinks);
        tags.add(c.text);
        continue;
      }
      if (c is TaskDone) {
        _taskDone(c, out);
        tags.add('[কাজ শেষ হিসেবে দাগ দেওয়া হলো]');
        continue;
      }
      if (c is OpenPlace) {
        final p = placeById(c.place);
        final name = c.folder != null ? trf('‘{0}’ ফোল্ডার', [tr(c.folder!)]) : tr(p?.title ?? c.place);
        final link = ChatLink(LinkKind.page, trf('খুলুন: {0}', [name]), page: c.place, folder: c.folder);
        _say(out, trf('{0} খুলছি।', [name]), links: [link]);
        openNow = link;
        tags.add('[${p?.title ?? c.place} পাতা খুলে দিল]');
        continue;
      }
      if (c is ManageItem) {
        await _manage(c, out);
        tags.add('[সংরক্ষিত কিছু বদলানো বা মোছার কথা হচ্ছে]');
        continue;
      }
      if (c is Clarify) {
        _clarifyOptions = c.options;
        Trace.log('understood', 'needs a choice', {'question': c.question, 'options': c.options.map((o) => o.$1).join(' / ')});
        _ask(out, tr(c.question), ChatWait.clarify, choices: [for (final o in c.options) ChatChoice(tr(o.$1), o.$1)]);
        tags.add('[জিজ্ঞেস করল: ${c.question}]');
        continue;
      }
      if (c is MoneyListQuery) {
        _answerMoney(c, out);
        tags.add(answerText(brain.data, c, _now) ?? '');
        continue;
      }
      if (c is CallPerson) {
        _startCall(c, out);
        tags.add('[ফোন/মেসেজের ব্যবস্থা করছে]');
        continue;
      }
      final text = answerText(brain.data, c, _now) ?? '';
      _say(out, text, vault: _vaultFor(c), links: _linksFor(c));
      if (c is LedgerQuery && c.ask == LedgerAsk.person && c.person != null) _focusOn(person: c.person!);
      if (c is CashQuery) _focusOn(cash: true);
      // Money answers are kept in the AI's view of the conversation so a
      // follow-up ("তাহলে সব মিলিয়ে কত?") makes sense; saved notes, tasks
      // and logins are not.
      final shareable = c is AiReply || c is SmallTalk || c is NotUnderstood || c is LedgerQuery || c is CashQuery;
      tags.add(shareable ? text : tr('[অ্যাপ নিজের রাখা তথ্য থেকে উত্তর দিল]'));
      if (c is SmallTalk && c.kind == Talk.whatCanYouDo) _say(out, capabilitiesList(), speak: false, links: [ChatLink(LinkKind.page, tr('কী কী করা যায় — বিস্তারিত'), page: 'help')]);
      if (c is SmallTalk && c.kind == Talk.bye) ended = true;
    }
    if (saves.length == 1) {
      await _start(saves.single, out);
    } else if (saves.length > 1) {
      _queue
        ..clear()
        ..addAll(saves);
      _askingAll = true;
      _ask(out, trf('আপনার কথা থেকে {0}টা জিনিস পেলাম। সবগুলো রেখে দিই?', [bnDigits(saves.length)]), ChatWait.yesNo,
          choices: _yesNoChoices, facts: [for (final c in saves) summaryLine(c)]);
    }
    if (saves.isNotEmpty) tags.add('[রাখার আগে জিজ্ঞেস করছে: ${saves.map(summaryLine).join('; ')}]');
    _history.add(AiTurn.app(tags.isEmpty ? tr('[ঠিক আছে]') : tags.join(' ')));
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
    if (c is SearchQuery) return [for (final h in relevantHits(brain.data, c.terms).take(6)) if (h is VaultHit) h.item];
    return const [];
  }

  List<ChatLink> _linksFor(Command c) {
    final d = brain.data;
    if (c is LedgerQuery && c.ask == LedgerAsk.person) {
      final p = balanceOf(d.ledger, c.person!);
      if (p != null) return [ChatLink(LinkKind.person, trf('{0} খাতা দেখুন', [possessive(p.name)]), person: p.name)];
    }
    if (c is ReminderQuery && searchReminders(d, c.terms).isNotEmpty) return [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))];
    if (c is TaskQuery || c is Briefing) return [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))];
    if (c is CashQuery) return [ChatLink(LinkKind.cash, tr('আয়-ব্যয় দেখুন'))];
    if (c is ContactsQuery) return [ChatLink(LinkKind.contacts, tr('যোগাযোগ দেখুন'))];
    if (c is HealthQuery) return [ChatLink(LinkKind.health, tr('স্বাস্থ্য দেখুন'))];
    if (c is ProfileQuery) {
      final text = normalize(c.transcript);
      final kind = mentionsBlood(text) ? null : kindAsked(text);
      if (kind == 'photos') {
        return [
          for (final x in photoDocs(d).take(4)) ChatLink(LinkKind.doc, trf('দেখুন: {0}', [x.title]), docId: x.id),
          ChatLink(LinkKind.page, tr('ডকুমেন্টস খুলুন'), page: 'docs'),
          if (d.notes.any((n) => n.files.any((f) => f.isImage))) ChatLink(LinkKind.notes, tr('নোট দেখুন')),
        ];
      }
      if (kind == 'papers') return [ChatLink(LinkKind.page, tr('ডকুমেন্টস খুলুন'), page: 'docs')];
      if (!mentionsBlood(text)) {
        // Everyday questions: the page where it is kept.
        final page = switch (infoTopic(text) ?? profileField(text)) {
          'inbox' => 'inbox',
          'prayer' || 'sehri' || 'iftar' || 'sunrise' || 'sunset' => 'calendar',
          'money' => 'accounts',
          'savings' => 'savings',
          'medicines' => 'medicines',
          'habits' => 'habits',
          'notes' => 'notes',
          'special' => 'special',
          'day' => 'tasks',
          'expiry' => 'expiry',
          'height' || 'age' || 'birth' => 'health',
          'allergy' || 'illness' => 'emergency',
          'name' => 'settings',
          _ => null,
        };
        final p = page == null ? null : placeById(page);
        if (p != null) return [ChatLink(LinkKind.page, trf('খুলুন: {0}', [tr(p.title)]), page: p.id)];
      }
      return [
        whoseIn(text).isEmpty ? ChatLink(LinkKind.page, tr('জরুরি কার্ড দেখুন'), page: 'emergency') : ChatLink(LinkKind.health, tr('স্বাস্থ্য দেখুন')),
      ];
    }
    if (c is SearchQuery) {
      final docs = [
        for (final h in relevantHits(d, c.terms).whereType<DocHit>().take(4)) ChatLink(LinkKind.doc, trf('দেখুন: {0}', [h.doc.title]), docId: h.doc.id),
      ];
      if (docs.isNotEmpty) return docs;
    }
    // A part of the app was named ("ওষুধের কথা", "সঞ্চয়"): a way to it.
    if (c is SearchQuery || c is NotUnderstood) {
      final p = placeMentioned(normalize(c.transcript));
      if (p != null) return [ChatLink(LinkKind.page, trf('খুলুন: {0}', [tr(p.title)]), page: p.id)];
    }
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
    // A question the app asked only to choose an answer: nothing was waiting to be saved.
    if (wait == ChatWait.clarify) {
      _clarifyOptions = const [];
      _reset();
      return;
    }
    if (wait != ChatWait.none || _current != null || _queue.isNotEmpty) {
      messages.add(ChatMessage.app(tr('আগের প্রশ্নটা বাদ দিলাম, কিছু রাখা হয়নি।'), info: true));
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
    _personChoices = const [];
    _askingAll = false;
    _allYes = false;
    _savedInBatch = 0;
  }

  // ── Working through the things to save ──

  Future<void> _start(Command c, List<String> out) async {
    _current = c;
    _chosen = false;
    switch (c) {
      case LedgerAdd():
        _src = c;
        _person = c.person.trim();
        _amount = c.amount;
        _kind = c.kind;
        _ledgerDate = c.date;
        _ledgerPhone = '';
        _phoneChecked = false;
        await _nextLedgerStep(out);
      case LedgerSet():
        _setEntry = entryToReach(brain.data.ledger, c.person, c.balance, _now);
        if (_setEntry == null) {
          final cur = balanceWith(brain.data.ledger, c.person);
          _say(out, trf('খাতায় তো এটাই লেখা আছে — {0}। নতুন করে কিছু লাগবে না।', [owesText(c.person, cur)]), speak: !_allYes);
          await _done(out);
          return;
        }
        if (_allYes) return _saveCurrent(out);
        String owes(int bal) => bal == 0
            ? trf('{0} সাথে হিসাব মিটে গেছে', [possessive(c.person)])
            : (bal > 0 ? trf('{0} কাছে আপনার {1} টাকা পাওনা', [possessive(c.person), bnNumber(bal)]) : trf('{0} আপনার {1} টাকা দিতে হবে', [toPerson(c.person), bnNumber(-bal)]));
        final known = balanceOf(brain.data.ledger, c.person);
        _ask(
          out,
          known == null
              ? trf('{0} নামে তো কারও হিসাব নেই। লেনদেনের খাতায় নতুন করে খুলে লিখে রাখি যে {1}?', [c.person, owes(c.balance)])
              : trf('খাতায় এখন লেখা আছে, {0}। মিলিয়ে লিখে রাখি যে {1}?', [owes(known.balance), owes(c.balance)]),
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
          cat.isNew ? trf('“{0}” — এটা নতুন ধরনের তথ্য। ‘{1}’ নামে নতুন বিভাগ খুলে রেখে দিই?', [c.text, cat.name]) : trf('“{0}” — ‘{1}’ বিভাগে রেখে দিই?', [c.text, cat.name]),
          ChatWait.yesNo,
          choices: _yesNoChoices,
        );
      case TaskAdd():
        if (_allYes) return _saveCurrent(out);
        final due = c.due == null ? '' : ' (${sayWhen(c.due!, _now, withTime: false)})';
        _ask(out, trf('“{0}”{1} — কাজের তালিকায় তুলে রাখি?', [c.title, due]), ChatWait.yesNo, choices: _yesNoChoices);
      case ReminderAdd():
        _pendingTitle = c.title;
        _pendingRepeat = c.repeat;
        _pendingAlarm = c.alarm;
        _pendingDays = c.weekdays;
        _pendingBefore = c.minutesBefore;
        if (c.needsTime) {
          _pendingDay = c.day;
          final what = c.needsTitle ? '' : '“${c.title}” — ';
          if (c.day != null) {
            // "কাল মনে করিয়ে দিও": the day is known, only the hour is asked.
            _ask(out, trf('{0}{1} কয়টায় মনে করাব?', [what, sayWhen(c.day!, _now, withTime: false)]), ChatWait.reminderTime);
          } else {
            _ask(out, trf('{0}কখন মনে করাব? যেমন “আজ সন্ধ্যা ৭টায়”, “কাল সকাল ১০টায়” বা “এক ঘণ্টা পরে”।', [what]), ChatWait.reminderTime);
          }
          return;
        }
        if (!c.at.isAfter(_now)) {
          _pendingDay = null;
          _ask(out, trf('{0} তো পার হয়ে গেছে। কখন মনে করাব?', [sayWhen(c.at, _now)]), ChatWait.reminderTime);
          return;
        }
        if (c.needsTitle) {
          _pendingAt = c.at;
          _ask(out, trf('{0}-এ মনে করাব। কী বিষয়ে? বলুন, বা শুধু অ্যালার্ম চাইলে “শুধু অ্যালার্ম”।', [sayWhen(c.at, _now)]), ChatWait.reminderTitle,
              choices: [ChatChoice(tr('শুধু অ্যালার্ম'), 'শুধু অ্যালার্ম')]);
          return;
        }
        if (_allYes) return _saveCurrent(out);
        final again = c.repeat == Repeat.none ? '' : ', ${c.repeat.label}';
        final time = bnTime(c.at.hour, c.at.minute);
        final q = c.repeat.isInterval
            ? trf('{0} “{1}” মনে করিয়ে দেব, প্রথমবার {2}-এ — ঠিক আছে?', [c.repeat.label, c.title, time])
            : c.repeat == Repeat.daily
                ? trf('প্রতিদিন {0}-এ “{1}” মনে করিয়ে দেব — ঠিক আছে?', [time, c.title])
                : trf('{0}-এ “{1}” মনে করিয়ে দেব{2} — ঠিক আছে?', [sayWhen(c.at, _now), c.title, again]);
        _ask(out, q, ChatWait.yesNo, choices: _yesNoChoices);
      case CashAdd():
        if (c.amount <= 0) {
          _ask(out, tr('কত টাকা?'), ChatWait.amount);
          return;
        }
        if (c.project != null && c.project!.trim().isEmpty) {
          final open = brain.data.projects.where((p) => !p.closed).toList();
          if (open.length == 1) {
            return _start(CashAdd(c.transcript, kind: c.kind, amount: c.amount, category: c.category, project: open.first.name), out);
          }
          _ask(out, tr('কোন হিসাবে লিখব? নামটা বলুন।'), ChatWait.project, choices: [for (final p in open.take(5)) ChatChoice(p.name, p.name)]);
          return;
        }
        if (_allYes) return _saveCurrent(out);
        final inOut = c.kind == CashKind.income ? tr('আয়') : tr('খরচ');
        final String q;
        if (c.project != null) {
          final exists = projectByName(brain.data, c.project!) != null;
          q = trf('{0}‘{1}’ হিসাবে {2} টাকা {3} হিসেবে লিখি?', [exists ? '' : 'নতুন হিসাব খুলে ', c.project, bnNumber(c.amount), inOut]);
        } else {
          q = trf('{0} হিসেবে লিখি — {1}, {2} টাকা?', [inOut, c.category, bnNumber(c.amount)]);
        }
        _ask(out, q, ChatWait.yesNo, choices: _yesNoChoices);
      case VaultAdd():
        if (_allYes) return _saveCurrent(out);
        final old = _vaultNamed(c.name);
        _ask(
          out,
          old != null ? trf('‘{0}’-এর পাসওয়ার্ড আগে থেকেই রাখা আছে। নতুনটা দিয়ে বদলে দিই?', [old.name]) : trf('‘{0}’-এর পাসওয়ার্ড ভল্টে তালাবদ্ধ করে রাখি?', [c.name]),
          ChatWait.yesNo,
          choices: _yesNoChoices,
        );
      case ContactAdd():
        if (c.name.trim().isEmpty) {
          _ask(out, tr('নম্বরটা কার নামে রাখব?'), ChatWait.contactName);
          return;
        }
        if (_allYes) return _saveCurrent(out);
        final old = findContact(brain.data, c.name);
        _ask(
          out,
          old != null && old.phone.isNotEmpty && old.phone != c.phone
              ? trf('{0} আগের নম্বর {1}। নতুন নম্বর {2} দিয়ে বদলে দিই?', [possessive(old.name), bnDigits(old.phone), bnDigits(c.phone)])
              : trf('{0} নম্বর {1} — রেখে দিই?', [possessive(c.name), bnDigits(c.phone)]),
          ChatWait.yesNo,
          choices: _yesNoChoices,
        );
      case MemoryAdd():
        if (_allYes) return _saveCurrent(out);
        _ask(out, trf('“{0}” — এটা মনে রাখব, পরের উত্তরে কাজে লাগাব। ঠিক আছে?', [c.text]), ChatWait.yesNo, choices: _yesNoChoices);
      case HealthAdd():
      case ProfileSet():
        // Kept at once (it can be taken back with ফিরিয়ে নিন).
        return _saveCurrent(out);
      case SpecialAdd():
        if (_allYes) return _saveCurrent(out);
        final when = '${bnDigits(c.day)} ${monthName(c.month)}${c.year == null ? '' : ' ${bnDigits(c.year!)}'}';
        final what = specialTitle(SpecialDay(person: c.person, kind: c.kind, month: c.month, day: c.day));
        _ask(out, trf('{0}, {1} — প্রতি বছর আগের দিন আর সেদিন সকালে মনে করিয়ে দেবো?', [what, when]), ChatWait.yesNo, choices: _yesNoChoices);
      default:
        await _done(out);
    }
  }

  /// "নিজের খরচ": a money sentence with no one owing becomes spending.
  Future<void> _asOwnSpending(List<String> out) async {
    final src = _src!;
    final amount = _amount > 0 ? _amount : src.amount;
    await _start(CashAdd(src.transcript, kind: CashKind.expense, amount: amount, category: categoryFor(normalize(src.transcript), CashKind.expense)), out);
  }

  void _taskDone(TaskDone c, List<String> out) {
    if (!c.done) {
      // "…এখনো শেষ হয়নি": still to do. Ticked by mistake: open it again.
      final all = matchTasks(brain.data.tasks, c.terms);
      if (all.isEmpty) {
        _say(out, tr('এমন কোনো কাজ তালিকায় পেলাম না।'), links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
        return;
      }
      final t = all.first;
      if (t.done) {
        brain.setTaskDone(t, false);
        _say(out, trf('ঠিক আছে, “{0}” আবার বাকি কাজের তালিকায় রাখলাম।', [t.title]), links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
      } else {
        _say(out, trf('জি, “{0}” বাকি কাজের তালিকাতেই আছে — শেষ হলে বলবেন।', [t.title]), links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
      }
      return;
    }
    final open = brain.data.tasks.where((t) => !t.done);
    final found = matchTasks(open, c.terms);
    if (found.isEmpty) {
      _say(out, tr('এমন কোনো বাকি কাজ তালিকায় পেলাম না।'), links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
      return;
    }
    final t = found.first;
    brain.setTaskDone(t, true);
    final left = brain.data.tasks.where((x) => !x.done && x.id != t.id).length;
    _say(out, trf('বাহ! “{0}” শেষ হিসেবে দাগ দিলাম।{1}', [t.title, left > 0 ? ' আর ${bnDigits(left)}টা কাজ বাকি।' : ' সব কাজ শেষ!']),
        links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
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
        _ask(out, c.via == Via.call ? tr('কাকে ফোন দেব? নামটা বলুন।') : tr('কাকে পাঠাব? নামটা বলুন।'), ChatWait.callee, choices: [
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
          trf('“{0}” নামে {1} জন আছেন — {2}। কাকে {3}?', [_callee, bnDigits(many.length), nameList(names.take(4).toList(), unit: 'জন'), c.via == Via.call ? 'ফোন দেব' : 'পাঠাব']),
          ChatWait.callee,
          choices: [for (final x in _calleeChoices) ChatChoice('${x.name} · ${showPhone(x.phone)}', '${x.name} ${x.phone}')],
        );
        return;
      } else {
        _ask(out, trf('{0} নম্বর তো রাখা নেই। নম্বরটা বলবেন? রেখে দেব, পরের বার আর লাগবে না।', [possessive(_callee)]), ChatWait.phone);
        return;
      }
    }
    if (c.via != Via.call && _text.isEmpty) {
      _ask(out, tr('কী লিখব? বলুন।'), ChatWait.message);
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
    final i = _pickIndex(said, [for (final c in _calleeChoices) (c.name, c.phone)]);
    return i == null ? null : _calleeChoices[i];
  }

  int? _pickIndex(String said, List<(String, String)> list) {
    final digits = asciiDigits(said).replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 3) {
      final tail = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
      final hits = [for (var i = 0; i < list.length; i++) if (asciiDigits(list[i].$2).replaceAll(RegExp(r'[^0-9]'), '').endsWith(tail)) i];
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
      if (order[i].any((w) => n.contains(normalize(w)))) return i;
    }
    if (n == normalize('শেষ জন') || n == normalize('শেষেরটা')) return list.length - 1;
    final people = [for (final o in list) Contact(name: o.$1, phone: o.$2)];
    final narrowed = contactMatches(AppData(contacts: people), said);
    return narrowed.length == 1 ? people.indexOf(narrowed.single) : null;
  }

  VaultItem? _vaultNamed(String name) {
    final n = normalize(name);
    for (final v in brain.data.vault) {
      if (normalize(v.name) == n) return v;
    }
    return null;
  }

  Future<void> _savePhone(String name, String phone) async {
    final old = findContact(brain.data, name);
    await brain.saveContact(Contact(
      id: old?.id,
      name: old?.name ?? name,
      phone: phone,
      email: old?.email ?? '',
      note: old?.note ?? '',
      address: old?.address ?? '',
      files: old?.files ?? const [],
    ));
  }

  Future<void> _nextLedgerStep(List<String> out) async {
    final src = _src!;
    if (_person.isEmpty) {
      final known = knownPeople(brain.data.ledger).take(4);
      _ask(out, tr('টাকার হিসাব লেনদেনের খাতায় রাখি। কার সাথে লেনদেন হলো? নামটা বলেন।'), ChatWait.name, choices: [
        for (final k in known) ChatChoice(k, k),
        if (src.allowExpense) ChatChoice(tr('নিজের খরচ'), 'অন্য খরচ'),
      ]);
      return;
    }
    if (_amount <= 0) {
      _ask(out, trf('{0} নিয়ে কত টাকার কথা? অঙ্কটা বলেন।', [toPerson(_person)]), ChatWait.amount);
      return;
    }
    if (!_phoneChecked) {
      _phoneChecked = true;
      // Whose number? First the people already in the book with this name,
      // then যোগাযোগ. One fits: use it. Several: ask which.
      final inBook = peopleNamed(brain.data.ledger, _person).where((p) => p.phone.isNotEmpty).toList();
      final options = inBook.isNotEmpty
          ? [for (final p in inBook) (p.name, p.phone)]
          : [for (final c in contactMatches(brain.data, _person).where((c) => c.phone.isNotEmpty)) (c.name, c.phone)];
      if (options.length == 1) {
        _ledgerPhone = options.single.$2;
      } else if (options.length > 1) {
        _personChoices = options.take(6).toList();
        _ask(
          out,
          trf('“{0}” নামে {1} জন আছেন। কার সাথে লেনদেন?', [_person, bnDigits(options.length)]),
          ChatWait.whichPerson,
          choices: [
            for (final o in _personChoices) ChatChoice('${o.$1} · ${showPhone(o.$2)}', '${o.$1} ${o.$2}'),
            ChatChoice(tr('নতুন মানুষ'), 'নতুন মানুষ'),
          ],
        );
        return;
      }
    }
    if (_kind == null) {
      final opts = src.options.isEmpty ? LedgerKind.values : src.options;
      _ask(out, _clarifyQuestion(opts, src.allowExpense), ChatWait.kind, choices: [
        for (final k in opts) ChatChoice(k.label, k.label),
        if (src.allowExpense) ChatChoice(tr('অন্য খরচ'), 'অন্য খরচ'),
      ]);
      return;
    }
    if (_allYes || _chosen) return _saveCurrent(out);
    final on = _ledgerDate == null ? '' : '${sayWhen(_ledgerDate!, _now, withTime: false).replaceFirst(RegExp(r'^কাল'), 'গতকাল')}: ';
    // The recogniser also heard another amount: say so, and offer it.
    final alt = _altAmount(src.transcript);
    final unsure = alt == null ? '' : trf(' (“{0} টাকা”-ও শোনা গেছে — অঙ্কটা ঠিক আছে তো?)', [bnNumber(alt)]);
    _ask(out, '$on${confirmQuestion(_kind!, _person, _amount)}$unsure', ChatWait.yesNo,
        choices: [..._yesNoChoices, if (alt != null) ChatChoice(trf('{0} টাকা', [bnNumber(alt)]), 'না, $alt')],
        facts: [if (_ledgerPhone.isNotEmpty) '$_person · ${showPhone(_ledgerPhone)}'],
        links: [
      ChatLink(LinkKind.editEntry, tr('তারিখ বা অঙ্ক বদলান'),
          entry: LedgerAdd(src.transcript, person: _person, amount: _amount, kind: _kind)),
    ]);
  }

  String _clarifyQuestion(List<LedgerKind> o, bool allowExpense) {
    if (o.contains(LedgerKind.repaid) && allowExpense) {
      return tr('একটু বুঝিয়ে বলেন — এটা কি আগের দেনা শোধ করলেন, নাকি নতুন করে ধার দিলেন? নাকি অন্য কোনো খরচ?');
    }
    if (o.contains(LedgerKind.received) && o.contains(LedgerKind.borrowed)) {
      return tr('একটু বুঝিয়ে বলেন — উনি কি আগের টাকা ফেরত দিলেন, নাকি আপনি নতুন করে ধার নিলেন?');
    }
    return tr('একটু বুঝিয়ে বলেন — এটা কোন ধরনের লেনদেন?');
  }

  /// A long new sentence instead of an answer.
  bool _looksNew(String t) => words(normalize(t)).length >= 4;

  /// Handles [t] as the answer to the waiting question. False when it is
  /// not an answer but something new.
  Future<bool> _answer(String t, List<String> out) async {
    // "বাদ দাও", "থাক", "বাতিল": the question and what it was for are dropped.
    if (wait != ChatWait.none && isCancel(t)) {
      wait = ChatWait.none;
      choices = const [];
      _current = null;
      _queue.clear();
      _askingAll = false;
      _say(out, tr('ঠিক আছে, বাদ দিলাম। কিছুই রাখা হয়নি।'));
      return true;
    }
    switch (wait) {
      case ChatWait.none:
        return false;
      case ChatWait.clarify:
        final i = _pickOption(t);
        if (i == null) {
          if (_looksNew(t)) return false;
          _say(out, tr('কোনটা, ধরতে পারিনি — নিচ থেকে একটা বেছে নিন।'));
          return true;
        }
        final pick = _clarifyOptions[i].$2;
        wait = ChatWait.none;
        choices = const [];
        _clarifyOptions = const [];
        Trace.log('understood', 'choice made', {'picked': traceLine(pick)});
        if (pick is MoneyListQuery) {
          _answerMoney(pick, out);
        } else {
          final text = answerText(brain.data, pick, _now) ?? '';
          _say(out, text, links: _linksFor(pick));
          if (pick is CashQuery) _focusOn(cash: true);
        }
        return true;
      case ChatWait.whichItem:
        final n = asciiDigits(t).replaceAll(RegExp(r'[^0-9]'), '');
        var i = int.tryParse(n) == null ? null : int.parse(n) - 1;
        i ??= _pickIndex(t, [for (final x in _targets) (x.label, '')]);
        if (i == null || i < 0 || i >= _targets.length) {
          if (_looksNew(t)) return false;
          _say(out, tr('কোনটা — নম্বরটা বলুন, যেমন “১”।'));
          return true;
        }
        wait = ChatWait.none;
        choices = const [];
        await _confirmManage(_targets[i], out);
        return true;
      case ChatWait.whichPerson:
        if (normalize(t).contains(normalize('নতুন'))) {
          _ledgerPhone = '';
        } else {
          final i = _pickIndex(t, _personChoices);
          if (i == null) {
            if (_looksNew(t)) return false;
            _say(out, tr('কোন জন, বুঝতে পারিনি। নিচ থেকে বেছে নিন, বা নম্বরের শেষ কয়েকটা অঙ্ক বলুন।'));
            return true;
          }
          _ledgerPhone = _personChoices[i].$2;
        }
        _personChoices = const [];
        wait = ChatWait.none;
        choices = const [];
        await _nextLedgerStep(out);
        return true;
      case ChatWait.collect:
        if (_isFinish(t)) {
          if (_collected.isEmpty) {
            wait = ChatWait.none;
            _say(out, tr('ঠিক আছে, কিছু রাখা হলো না।'));
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
        // "না, সাতশ" / "পাঁচশ না, সাতশ": not a no — the amount corrected; ask again.
        final cur = _current;
        final fixed = _correctedAmount(t);
        if (fixed != null && !_askingAll && (cur is LedgerAdd || cur is CashAdd)) {
          wait = ChatWait.none;
          choices = const [];
          if (cur is LedgerAdd) {
            _amount = fixed;
            await _nextLedgerStep(out);
          } else if (cur is CashAdd) {
            await _start(CashAdd(cur.transcript, kind: cur.kind, amount: fixed, category: cur.category, project: cur.project), out);
          }
          return true;
        }
        // "না, এগারোটায় করো", "না, করিমকে", "না, কাল": the waiting action
        // corrected — not a no. It is shown again with the change.
        if (!_askingAll && await _editPending(t, out)) return true;
        final yn = yesNo(t);
        if (yn == null) {
          if (_looksNew(t)) return false;
          _say(out, tr('ঠিক ধরতে পারিনি। “হ্যাঁ” বা “না” বলেন।'));
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
            _say(out, tr('আচ্ছা, কিছুই রাখলাম না।'));
          }
          return true;
        }
        if (yn) {
          await _saveCurrent(out);
        } else {
          _say(out, tr('আচ্ছা, রাখলাম না।'));
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
        // "হ্যাঁ" / "না" is not a name.
        if (yesNo(t) != null && words(normalize(t)).length <= 2) {
          _say(out, tr('কার সাথে লেনদেন — নামটা বলুন।'));
          return true;
        }
        final n = spokenName(t, knownPeople(brain.data.ledger));
        if (n.isEmpty) {
          _say(out, tr('নামটা ধরতে পারিনি। আবার বলেন।'));
          return true;
        }
        _person = n;
        wait = ChatWait.none;
        await _nextLedgerStep(out);
        return true;
      case ChatWait.topic:
        final n = normalize(t);
        if (n == normalize('অন্য কিছু') || n == normalize('অন্যান্য') || n == normalize('অন্য')) {
          _ask(out, tr('কোন বিষয়ে? নামটা বলুন — নতুন বিভাগ খুলে দেব।'), ChatWait.topicName);
          return true;
        }
        final tp = _topicWord(t);
        // "আজকের কাজের তালিকা", "কালকের কাজ": a list is coming, not a question.
        if (_startsList(t)) {
          _setTopic(Topic.task, out);
          return true;
        }
        final count = words(n).length;
        final c = Parser(ledger: brain.data.ledger, tasks: brain.data.tasks, contacts: brain.data.contacts, folders: brain.folderHints, now: _now).parse(t);
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
          _say(out, tr('সময়টা ধরতে পারিনি। যেমন বলুন “সন্ধ্যা ৭টায়”, “৬.৩০-এ” বা “৩০ মিনিট পরে”।'));
          return true;
        }
        // "আজ" / "কাল" alone: keep the day and ask the hour.
        if (!w.hasTime) {
          _pendingDay = w.day;
          _say(out, trf('{0} কয়টায়?', [sayWhen(w.day, _now, withTime: false)]));
          return true;
        }
        var at = w.at;
        final day = _pendingDay;
        if (day != null && !w.hasDay) {
          at = DateTime(day.year, day.month, day.day, at.hour, at.minute);
          // "আজ" then "৬.২০": the evening one if the morning one has passed.
          if (!at.isAfter(_now) && at.hour < 12 && at.add(const Duration(hours: 12)).isAfter(_now)) at = at.add(const Duration(hours: 12));
        }
        _pendingDay = null;
        wait = ChatWait.none;
        await _start(ReminderAdd(t, title: _pendingTitle, at: at, repeat: _pendingRepeat, alarm: _pendingAlarm, weekdays: _pendingDays, minutesBefore: _pendingBefore), out);
        return true;
      case ChatWait.reminderTitle:
        final at = _pendingAt;
        if (at == null) return false;
        final n = normalize(t);
        final bare = n.contains(normalize('শুধু অ্যালার্ম')) || n == normalize('অ্যালার্ম') || n == normalize('কিছু না') || yesNo(t) == true;
        // A new full request instead of a subject.
        if (!bare && words(n).length > 8) return false;
        var title = bare ? tr('অ্যালার্ম') : tidy(cutWords(t, const ['মনে করিয়ে দিও', 'মনে করিয়ে দিবা', 'মনে করাবে', 'এর কথা', 'কথা', 'বিষয়ে', 'জন্য', 'জন্যে']));
        if (title.isEmpty) title = t.trim();
        _pendingAt = null;
        wait = ChatWait.none;
        choices = const [];
        await _start(ReminderAdd(t, title: title, at: at, repeat: _pendingRepeat, alarm: _pendingAlarm, weekdays: _pendingDays, minutesBefore: _pendingBefore), out);
        return true;
      case ChatWait.callee:
        if (_calleeChoices.isNotEmpty) {
          final picked = _pickCallee(t);
          if (picked == null) {
            if (_looksNew(t)) return false;
            _say(out, tr('কোন জন, বুঝতে পারিনি। নামটা পুরো বলুন, বা নিচ থেকে বেছে নিন।'));
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
          _say(out, tr('নামটা ধরতে পারিনি। আবার বলুন।'));
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
          _say(out, tr('নম্বরটা ধরতে পারিনি। আবার বলুন — ১১ সংখ্যার মোবাইল নম্বর।'));
          return true;
        }
        _phone = ph;
        wait = ChatWait.none;
        if (_callee.isNotEmpty) {
          await _savePhone(_callee, ph);
          messages.add(ChatMessage.app(trf('{0} নম্বর যোগাযোগে রেখে দিলাম।', [possessive(_callee)]), info: true));
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
          _say(out, tr('নামটা ধরতে পারিনি। আবার বলুন।'));
          return true;
        }
        wait = ChatWait.none;
        await _start(ContactAdd(c.transcript, name: n, phone: c.phone), out);
        return true;
      case ChatWait.amount:
        final a = findAmount(normalize(t));
        if (a == null || a <= 0) {
          if (_looksNew(t)) return false;
          _say(out, tr('টাকার অঙ্কটা ধরতে পারিনি। আবার বলেন।'));
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
          _say(out, tr('ঠিক ধরতে পারিনি। একটা বেছে নিন, বা বলেন — যেমন “শোধ” বা “নতুন ধার”।'));
          return true;
        }
        wait = ChatWait.none;
        choices = const [];
        if (choice == 'expense') {
          await _asOwnSpending(out);
          return true;
        }
        _kind = LedgerKind.values.byName(choice);
        // Picking the kind is the user's say-so: saved without asking again
        // (it can still be taken back with "ফিরিয়ে নিন").
        _chosen = pick != null;
        await _nextLedgerStep(out);
        return true;
    }
  }

  /// Which offered answer [t] means: its number, its order ("প্রথমটা"), or
  /// the words of one option and no other.
  int? _pickOption(String t) {
    final n = normalize(t);
    final idx = int.tryParse(asciiDigits(n).replaceAll(RegExp(r'[^0-9]'), ''));
    if (idx != null && idx >= 1 && idx <= _clarifyOptions.length && words(n).length <= 2) return idx - 1;
    final byOrder = _pickIndex(t, [for (final o in _clarifyOptions) (o.$1, '')]);
    if (byOrder != null) return byOrder;
    final said = words(n).map(stem).toSet();
    var best = -1, bestScore = 0, tie = false;
    for (var i = 0; i < _clarifyOptions.length; i++) {
      final ws = words(normalize(_clarifyOptions[i].$1)).map(stem).where((x) => x.length >= 2).toSet();
      final score = ws.intersection(said).length;
      if (score > bestScore) {
        best = i;
        bestScore = score;
        tie = false;
      } else if (score == bestScore && score > 0) {
        tie = true;
      }
    }
    return bestScore > 0 && !tie ? best : null;
  }

  /// The money records of a span of time, from the saved book only: what was
  /// found, a line for each, and a way to the page they are on.
  void _answerMoney(MoneyListQuery q, List<String> out) {
    final r = moneyRecords(brain.data, q);
    Trace.log('data', 'money records', {
      'from': q.from.toIso8601String().substring(0, 10),
      'to (not incl.)': q.to.toIso8601String().substring(0, 10),
      'category': q.category ?? '-',
      'person': q.person ?? '-',
      'sources': 'ledger, cash',
      'found': '${r.ledger.length} ledger + ${r.cash.length} cash',
      'records': [...r.ledger.map((e) => e.id), ...r.cash.map((e) => e.id)].take(12).join(','),
    });
    final text = moneyListAnswer(brain.data, q);
    _say(out, text, facts: moneyLines(brain.data, q), links: [
      if (r.cash.isNotEmpty || (r.ledger.isEmpty && q.person == null)) ChatLink(LinkKind.cash, tr('আয়-ব্যয় দেখুন')),
      if (r.ledger.isNotEmpty && q.person != null) ChatLink(LinkKind.person, trf('{0} খাতা দেখুন', [possessive(q.person!)]), person: q.person),
      if (r.ledger.isNotEmpty && q.person == null) ChatLink(LinkKind.page, tr('লেনদেন (ধার-দেনা) দেখুন'), page: 'ledger'),
    ]);
    _focusMoney = q;
    _focusAt = _now;
  }

  /// A correction to the action waiting for "হ্যাঁ": a new time or day for a
  /// reminder or to-do, a new person or kind for a money entry. True when it
  /// was one (the action is shown again, changed); false otherwise.
  Future<bool> _editPending(String t, List<String> out) async {
    final n = normalize(t);
    final ws = words(n);
    if (ws.isEmpty || ws.length > 8) return false;
    final lead = {'না', 'নাহ', 'উহু', 'না না', 'বরং', 'ওটা', 'না বরং'}.map(normalize).contains(ws.first) || ws.first == normalize('না,');
    final cur = _current;
    switch (cur) {
      case ReminderAdd():
        final w = parseWhen(t, _now);
        if (w == null || (!w.hasTime && !w.hasDay)) return false;
        if (!lead && !ws.any((x) => {'করো', 'করে', 'দাও', 'হবে', 'করুন', 'দিন'}.map(normalize).contains(x))) return false;
        final old = cur.at.year > 2000 ? cur.at : (cur.day ?? dayOnly(_now));
        var day = w.hasDay ? w.day : DateTime(old.year, old.month, old.day);
        var hour = w.hasTime ? w.at.hour : old.hour;
        final minute = w.hasTime ? w.at.minute : old.minute;
        // "দশটায়, না এগারোটায়" in the morning stays in the morning.
        if (w.hasTime && cur.at.year > 2000 && !RegExp(fold('সকাল|ভোর|দুপুর|বিকাল|বিকেল|সন্ধ্যা|রাত|am|pm')).hasMatch(n)) {
          final h12 = hour % 12;
          hour = cur.at.hour >= 12 ? h12 + 12 : h12;
        }
        if (!w.hasDay && cur.at.year <= 2000 && cur.day == null) day = dayOnly(_now);
        final at = DateTime(day.year, day.month, day.day, hour, minute);
        wait = ChatWait.none;
        choices = const [];
        await _start(ReminderAdd(cur.transcript, title: cur.title, at: at, repeat: cur.repeat, alarm: cur.alarm, weekdays: cur.weekdays, minutesBefore: cur.minutesBefore), out);
        return true;
      case TaskAdd():
        final w = parseWhen(t, _now);
        if (!lead || w == null || !w.hasDay) return false;
        wait = ChatWait.none;
        choices = const [];
        await _start(TaskAdd(cur.transcript, title: cur.title, due: w.day), out);
        return true;
      case LedgerAdd():
        if (!lead) return false;
        final rest = tidy(cutWords(t, const ['না', 'নাহ', 'উহু', 'বরং']));
        final kind = pickSpokenOption(rest, [for (final k in LedgerKind.values) k.name], allowExpense: false);
        final name = ws.length <= 4 ? spokenName(rest, knownPeople(brain.data.ledger)) : '';
        if (kind == null && (name.isEmpty || findAmount(normalize(rest)) != null)) return false;
        if (kind != null) _kind = LedgerKind.values.byName(kind);
        if (name.isNotEmpty && kind == null) {
          _person = name;
          _phoneChecked = false;
          _ledgerPhone = '';
        }
        wait = ChatWait.none;
        choices = const [];
        await _nextLedgerStep(out);
        return true;
      default:
        return false;
    }
  }

  /// Another amount in the recogniser's other guesses for [said] (only
  /// when it gave some; nothing is made up).
  int? _altAmount(String said) {
    final v = brain.services.voice;
    if (v.lastHeard.trim().isEmpty || v.lastHeard.trim() != said.trim()) return null;
    for (final a in v.lastAlternatives) {
      final n = findAmount(normalize(a));
      if (n != null && n > 0 && n != _amount) return n;
    }
    return null;
  }

  /// The new amount in a short correction ("না, ৭০০", "পাঁচশ না, সাতশ",
  /// "৭০০ হবে"); null when the answer is something else.
  int? _correctedAmount(String t) {
    final n = normalize(t);
    final ws = words(n);
    if (ws.isEmpty || ws.length > 7) return null;
    final parts = n.split(RegExp(' (${['না', 'নয়', 'নয়', 'নই'].map(normalize).join('|')}),? '));
    final tail = parts.last;
    final amount = findAmount(tail);
    if (amount == null || amount <= 0) return null;
    final startsNo = ws.first == normalize('না') || ws.first == normalize('না,');
    final hobe = ws.contains(normalize('হবে'));
    return (parts.length >= 2 || startsNo || hobe) ? amount : null;
  }

  Future<void> _saveCurrent(List<String> out) async {
    final c = _current;
    // Never the same action twice (a double "হ্যাঁ", a repeated callback).
    if (c != null && (identical(c, _executing) || identical(c, _executed))) return;
    _executing = c;
    try {
      await _saveOnce(c, out);
      _executed = c;
    } finally {
      _executing = null;
    }
  }

  Future<void> _saveOnce(Command? c, List<String> out) async {
    final quiet = _allYes;
    final snap = brain.snapshot();
    _batchSnap ??= snap;
    if (c != null && c is! ManageItem) {
      _lastSave = (c, snap, _now);
      _idsBeforeSave = {for (final t in targetsIn(brain.data, _now)) t.id};
    }
    switch (c) {
      case LedgerAdd() when !brain.canAddPerson(_person):
        _say(out, trf('ফ্রিতে {0} জনের ধার-দেনা রাখা যায়, সেটা পূর্ণ হয়ে গেছে। প্রো নিলে যত খুশি মানুষ রাখতে পারবেন — আগের হিসাব যেমন আছে থাকবে।', [bnDigits(freeLedgerPeople)]),
            links: [ChatLink(LinkKind.page, tr('প্রো দেখুন'), page: 'pro')]);
      case LedgerAdd():
        final kind = _kind!;
        final after = balanceAfter(brain.data.ledger, _person, kind, _amount);
        await brain.saveEntry(LedgerEntry(person: _person, phone: _ledgerPhone, kind: kind, amount: _amount, date: _ledgerDate ?? dayOnly(_now), note: ''),
            guessPhone: _ledgerPhone.isEmpty);
        _say(out, quiet ? trf('লিখলাম: {0}।', [describe(kind, _person, _amount)]) : savedSentence(kind, _person, _amount, after),
            links: [ChatLink(LinkKind.person, trf('{0} খাতা দেখুন', [possessive(_person)]), person: _person)], speak: !quiet);
        _history.add(AiTurn.app('[লিখে রাখা হলো: ${describe(kind, _person, _amount)}]'));
        _focusOn(person: _person);
      case LedgerSet():
        final e = _setEntry!;
        await brain.saveEntry(e);
        _say(out, quiet ? trf('লিখলাম: {0}।', [summaryLine(c)]) : trf('ঠিক আছে, লিখে রাখলাম। {0}', [balanceSentence(e.person, c.balance)]),
            links: [ChatLink(LinkKind.person, trf('{0} খাতা দেখুন', [possessive(e.person)]), person: e.person)], speak: !quiet);
        _history.add(AiTurn.app('[লিখে রাখা হলো: ${summaryLine(c)}]'));
      case NoteAdd():
        final cat = _cat?.name ?? defaultNoteCategory;
        await brain.saveNote(Note(title: noteTitleFrom(c.text), body: c.text, category: cat));
        _say(out, quiet ? trf('রাখলাম: {0} (‘{1}’)', [c.text, cat]) : trf('ঠিক আছে, ‘{0}’ বিভাগে রেখে দিলাম।', [cat]),
            links: [ChatLink(LinkKind.notes, tr('নোট দেখুন'))], speak: !quiet);
        _history.add(AiTurn.app('[নোট রাখা হলো, বিভাগ: $cat]'));
      case TaskAdd():
        await brain.saveTask(Task(title: c.title, due: c.due));
        _say(out, quiet ? trf('কাজ: {0}', [c.title]) : tr('ঠিক আছে, কাজের তালিকায় তুললাম।'),
            links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))], speak: !quiet);
        _history.add(AiTurn.app('[কাজের তালিকায় রাখা হলো: ${c.title}]'));
      case ReminderAdd() when !brain.canAddReminder:
        _say(out, trf('ফ্রিতে একসাথে {0}টা রিমাইন্ডার চালু রাখা যায়, সেটা পূর্ণ। পুরোনো কোনোটা বন্ধ বা মুছে দিন, অথবা প্রো নিলে যত খুশি রাখতে পারবেন।', [bnDigits(freeReminders)]),
            links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন')), ChatLink(LinkKind.page, tr('প্রো দেখুন'), page: 'pro')]);
      case ReminderAdd():
        await brain.saveReminder(Reminder(
          title: c.title,
          date: DateTime(c.at.year, c.at.month, c.at.day),
          hour: c.at.hour,
          minute: c.at.minute,
          daysBefore: 0,
          repeat: c.repeat,
          alarm: c.alarm,
          weekdays: c.weekdays,
          minutesBefore: c.minutesBefore,
        ));
        final early = c.minutesBefore > 0 ? trf(' {0} আগেও একবার জানিয়ে দেব।', [beforeLabel(c.minutesBefore)]) : '';
        // Saved, but the phone will not show it: say so instead of promising.
        if (!(await brain.services.notifier.health()).notificationsOn) {
          _say(out, trf('রিমাইন্ডারটা রাখা হয়েছে ({0}), কিন্তু এই ফোনে অ্যাপের নোটিফিকেশন বন্ধ — তাই এখন বাজবে না। ফোনের সেটিংস থেকে My Assistant-এর নোটিফিকেশন চালু করুন।', [sayWhen(c.at, _now)]),
              links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))]);
          _history.add(AiTurn.app('[রিমাইন্ডার রাখা হলো, কিন্তু নোটিফিকেশন বন্ধ: ${summaryLine(c)}]'));
          break;
        }
        _say(out, quiet ? trf('মনে করাব: {0}', [c.title]) : (c.repeat.isInterval || c.repeat == Repeat.daily ? trf('ঠিক আছে, {0} মনে করিয়ে দেব।', [c.repeat.label]) : trf('ঠিক আছে, {0}-এ মনে করিয়ে দেব।', [sayWhen(c.at, _now)])) + early,
            links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))], speak: !quiet);
        _history.add(AiTurn.app('[রিমাইন্ডার রাখা হলো: ${summaryLine(c)}]'));
        if (!_warnedExact && !await brain.services.notifier.exactAllowed()) {
          _warnedExact = true;
          messages.add(ChatMessage.app(tr('ঠিক মিনিটে বাজাতে সেটিংস → “ঠিক সময়ে রিমাইন্ডার” চালু করে নিন।'), info: true));
        }
      case CashAdd():
        Project? project;
        String proNote = '';
        if (c.project != null) {
          if (projectByName(brain.data, c.project!) == null && !brain.canAddProject) {
            // A second project is Pro: the entry still goes in, under the general account.
            proNote = trf(' নতুন হিসাব “{0}” খোলা প্রো সুবিধা (ফ্রিতে ১টা অন্যান্য হিসাব), তাই সাধারণ আয়-ব্যয়ে লিখলাম।', [c.project!]);
          } else {
            project = await brain.projectNamed(c.project!);
          }
        }
        await brain.saveCash(CashEntry(
          kind: c.kind,
          amount: c.amount,
          category: c.category,
          note: c.transcript.trim(),
          date: _now,
          projectId: project?.id,
          // "বড় দোকানে ৫০০০ টাকা বিক্রি": the shop named in the sentence.
          shopId: brain.data.shops.length < 2 ? null : brain.data.shops.where((x) => normalize(c.transcript).contains(normalize(x.name))).firstOrNull?.id,
        ));
        final String done;
        if (project != null) {
          final ps = projectSums(brain.data.cash, project.id);
          done = ps.income == 0
              ? trf('লিখলাম। ‘{0}’ হিসাবে এ পর্যন্ত খরচ {1} টাকা।', [project.name, bnNumber(ps.expense)])
              : (ps.balance >= 0
                  ? trf('লিখলাম। ‘{0}’ হিসাবে এখন হাতে আছে {1} টাকা।', [project.name, bnNumber(ps.balance)])
                  : trf('লিখলাম। ‘{0}’ হিসাবে আসার চেয়ে {1} টাকা বেশি খরচ হয়েছে।', [project.name, bnNumber(-ps.balance)]));
        } else {
          final m = monthSums(brain.data.cash, _now);
          done = c.kind == CashKind.expense ? trf('লিখলাম। এই মাসে মোট খরচ {0} টাকা।', [bnNumber(m.expense)]) : trf('লিখলাম। এই মাসে মোট আয় {0} টাকা।', [bnNumber(m.income)]);
        }
        _say(out, quiet ? trf('লিখলাম: {0}', [summaryLine(c)]) : done + proNote,
            links: [ChatLink(LinkKind.cash, tr('আয়-ব্যয় দেখুন')), if (proNote.isNotEmpty) ChatLink(LinkKind.page, tr('প্রো দেখুন'), page: 'pro')], speak: !quiet);
        _history.add(AiTurn.app('[লেখা হলো: ${summaryLine(c)}]'));
        _focusOn(cash: c.project == null);
      case VaultAdd():
        final old = _vaultNamed(c.name);
        if (old == null && !brain.canAddVault) {
          _say(out, trf('ফ্রিতে {0}টা পাসওয়ার্ড রাখা যায়, সেটা পূর্ণ হয়ে গেছে। প্রো নিলে যত খুশি রাখতে পারবেন — আগেরগুলো যেমন আছে থাকবে।', [bnDigits(freeVaultItems)]),
              links: [ChatLink(LinkKind.page, tr('প্রো দেখুন'), page: 'pro')]);
          break;
        }
        await brain.saveVault(VaultItem(
          id: old?.id,
          name: old?.name ?? c.name,
          kind: old?.kind ?? (c.wifi ? VaultKind.wifi : VaultKind.website),
          address: old?.address ?? '',
          username: old?.username ?? '',
          email: old?.email ?? '',
          password: c.password,
          note: old?.note ?? '',
          updatedAt: _now,
        ));
        // Never read the password back, not even to the AI.
        _say(out, quiet ? trf('ভল্টে: {0}', [c.name]) : tr('রেখে দিলাম, তালাবদ্ধ। দেখতে আঙুলের ছাপ বা PIN লাগবে।'), speak: !quiet);
        _history.add(AiTurn.app('[একটা লগইন ভল্টে রাখা হলো]'));
      case ContactAdd():
        await _savePhone(c.name, c.phone);
        _say(out, quiet ? trf('নম্বর: {0}', [c.name]) : trf('ঠিক আছে, {0} নম্বর রেখে দিলাম।', [possessive(c.name)]),
            links: [ChatLink(LinkKind.contacts, tr('যোগাযোগ দেখুন'))], speak: !quiet);
        _history.add(AiTurn.app('[নম্বর রাখা হলো: ${c.name}]'));
      case MemoryAdd():
        await brain.addMemory(c.text);
        _say(out, quiet ? trf('মনে রাখলাম: {0}', [c.text]) : tr('ঠিক আছে, মনে রাখলাম। সেটিংস › সহকারীর স্মৃতি থেকে দেখা বা মোছা যায়।'), speak: !quiet);
        _history.add(AiTurn.app('[মনে রাখা হলো: ${c.text}]'));
      case HealthAdd():
        final log = HealthLog(member: c.member, kind: c.kind, at: _now, a: c.a, b: c.b, c: c.c, tag: c.tag);
        await brain.addHealth(log);
        final level = levelOf(log);
        final who = brain.personById(c.member);
        var reply = trf('লিখে রাখলাম — {0}: {1}।', [isEn ? c.kind.en : c.kind.bn, readingText(log)]);
        if (level != null) reply += ' ${level.$2}।';
        if (c.kind == HealthKind.weight && who.heightCm != null) {
          final b = bmiOf(c.a, who.heightCm!);
          reply += trf(' BMI {0} — {1}।', [bnDigits(b.toStringAsFixed(1)), bmiLevel(b).$2]);
        }
        if (level != null && level.$1 == Level.urgent) reply += tr(' খুব দরকার হলে ৯৯৯-এ ফোন করুন।');
        _say(out, reply, links: [ChatLink(LinkKind.health, tr('স্বাস্থ্য দেখুন'))], speak: !quiet);
        _history.add(AiTurn.app('[স্বাস্থ্যের মাপ রাখা হলো: ${summaryLine(c)}]'));
      case ManageItem():
        final t = _target;
        if (t != null) {
          if (c.action == 'delete') {
            await brain.deleteTarget(t);
            _say(out, trf('মুছে দিলাম — {0}।', [t.label]), speak: !quiet);
          } else if (c.action == 'stop') {
            await brain.switchOffReminder(t.id);
            _say(out, trf('বন্ধ করে দিলাম — {0}। রিমাইন্ডারের পাতা থেকে আবার চালু করা যাবে।', [t.label]), speak: !quiet);
          } else {
            await brain.applyChange(t, _change);
            _say(out, tr('বদলে দিলাম।'), speak: !quiet);
          }
        }
        _target = null;
        _change = const Change();
      case ProfileSet() when c.field == 'height':
        final cm = double.parse(c.value);
        final whose = await brain.setHeight(c.who, cm);
        _say(out, trf('রেখে দিলাম — {0} উচ্চতা {1}। ওজন বললে BMI-ও বলে দিতে পারবো।', [whose, heightText(cm)]),
            links: [ChatLink(LinkKind.health, tr('স্বাস্থ্য দেখুন'))], speak: !quiet);
        _history.add(AiTurn.app(tr('[উচ্চতা রাখা হলো]')));
      case ProfileSet():
        final whose = await brain.setBlood(c.who, c.value);
        _say(out, trf('রেখে দিলাম — {0} রক্তের গ্রুপ {1}।', [whose, bloodSpoken(c.value)]),
            links: [c.who.isEmpty ? ChatLink(LinkKind.page, tr('জরুরি কার্ড দেখুন'), page: 'emergency') : ChatLink(LinkKind.health, tr('স্বাস্থ্য দেখুন'))], speak: !quiet);
        _history.add(AiTurn.app(tr('[রক্তের গ্রুপ রাখা হলো]')));
      case SpecialAdd():
        await brain.saveSpecialDay(SpecialDay(person: c.person, kind: c.kind, month: c.month, day: c.day, year: c.year));
        _say(out, quiet ? trf('বিশেষ দিন: {0}', [c.person]) : tr('রেখে দিলাম। প্রতি বছর আগের দিন আর সেদিন সকাল ৯টায় মনে করিয়ে দেবো।'),
            links: [ChatLink(LinkKind.special, tr('বিশেষ দিনগুলো দেখুন'))], speak: !quiet);
        _history.add(AiTurn.app('[বিশেষ দিন রাখা হলো: ${summaryLine(c)}]'));
      default:
        break;
    }
    if (quiet) {
      _savedInBatch++;
    } else {
      _offerUndo(snap);
      _batchSnap = null;
    }
    await _done(out);
  }

  /// The data before the first save of a "সব হ্যাঁ" batch.
  String? _batchSnap;

  /// Puts "ফিরিয়ে নিন" under the last message (and takes it off older ones).
  void _offerUndo(String snap) {
    for (final m in messages) {
      m.undo = null;
    }
    final last = messages.lastWhere((m) => !m.fromUser, orElse: () => ChatMessage.app(''));
    if (last.text.isEmpty) return;
    last.undo = snap;
    last.undoAt = DateTime.now();
  }

  /// "ফিরিয়ে নিন": everything goes back to before that save.
  Future<void> undo(ChatMessage m) async {
    final snap = m.undo;
    if (snap == null) return;
    m.undo = null;
    await brain.restoreSnapshot(snap);
    messages.add(ChatMessage.app(tr('ফিরিয়ে নিলাম — ওটা আর রাখা নেই।'), info: true));
    _history.add(const AiTurn.app('[The user undid the last save; it is no longer kept.]'));
    notifyListeners();
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
      if (_savedInBatch > 0) {
        _say(out, tr('সব রেখে দিলাম। আর কিছু?'));
        final snap = _batchSnap;
        if (snap != null) _offerUndo(snap);
      }
      _batchSnap = null;
      _allYes = false;
      _savedInBatch = 0;
    }
  }
}
