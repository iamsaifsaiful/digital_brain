import 'dart:convert';
import 'dart:math' as math;

import '../logic/csv.dart' show cashCsv;
import '../logic/standard.dart';
import '../nlu/labels.dart';
import '../nlu/model.dart' show TfliteRunner;
import '../nlu/reader.dart' show NluPiece;
import '../nlu/samples.dart';
import '../nlu/shadow.dart';
import 'package:flutter/foundation.dart';

import '../logic/lang.dart';
import '../logic/ai_map.dart' show answeredByAi;
import '../logic/app_map.dart';
import '../logic/ask.dart' show infoTopic;
import '../logic/calendar_ask.dart' show calendarAsked;
import '../logic/manage.dart';
import '../logic/meaning.dart';
import '../services/trace.dart';
import '../logic/me.dart';
import '../logic/answers.dart';
import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/dictation.dart' show splitDoneTail;
import '../logic/day_plan.dart' show planItemsOn;
import '../logic/categories.dart';
import '../logic/health.dart';
import '../logic/ledger.dart';
import '../logic/parser.dart';
import '../logic/phrases.dart';
import '../logic/plan.dart';
import '../logic/match.dart' show wordsMatch;
import '../logic/money_more.dart' show accountBalance, accountLabel, totalBalance, salesCategory;
import '../ui/theme.dart' show Look;
import '../logic/proactive.dart';
import '../logic/pro.dart' show freeVaultItems, freeLedgerPeople, freeReminders, medicalOff, medicalOffText;
import '../logic/search.dart';
import '../logic/talk.dart';
import '../logic/when.dart';
import '../models/models.dart';
import '../services/ai.dart';
import '../ui/yes_no.dart' show pickSpokenOption;
import 'brain.dart';

part 'todo_chat.dart';
part 'menu_chat.dart';
part 'bulk_chat.dart';

/// What the chat is waiting to hear.
enum ChatWait { none, newAccount, bulk, batchTime, taskDate, yesNo, name, amount, kind, callee, phone, message, contactName, topic, topicName, reminderTime, reminderTitle, taskTitle, taskDay, project, collect, whichPerson, whichItem, clarify, whichTask, taskTime, changeTo }

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
    // A model downloaded while the app runs is used from the next message.
    brain.onNluModelChanged = () => nluShadow.reload();
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

  /// Notes kept in this conversation (id, words, when): "আগের কাজগুলো নোটে
  /// কেন রাখছো? কাজের তালিকায় রাখো" moves these.
  final _notesKept = <(String, String, DateTime)>[];

  /// What existed before that save (so "শেষটা মুছে দাও" finds what it made).
  Set<String> _idsBeforeSave = const {};
  final _queue = <Command>[];

  /// The day of a to-do whose words are being asked for, and the rest of it.
  DateTime? _pendingTaskDue;
  TaskAdd? _pendingTaskAdd;

  /// A to-do being turned into a monthly reminder: removed once that is saved.
  String? _replaceTaskId;

  /// A to-do said with a month but no day, and that month (1–12).
  TaskAdd? _pendingTask;
  int? _pendingMonth;

  /// The to-do being talked about ("ওটা", "কাজটা") and since when.
  String? _focusTaskId;
  DateTime? _focusTaskAt;

  /// The to-dos the last answer named, in order ("দ্বিতীয়টা").
  List<String> _shownTasks = const [];

  /// When [_shownTasks] was shown: "দ্বিতীয়টা" means that list only while
  /// it is fresh (30 minutes), never an older or re-sorted one.
  DateTime? _shownAt;

  /// The ids of the to-do list last said, in order (for tests).
  @visibleForTesting
  List<String> get debugShownTasks => _shownTasks;
  bool get _shownFresh => _shownAt != null && _now.difference(_shownAt!).inMinutes <= 30;

  /// The lists shown (newest last) — what "এগুলো" means; see bulk_chat.dart.
  final List<ResultSet> _sets = [];

  /// What the conversation is waiting on, for the NLU baseline harness and
  /// shadow comparisons (tool/nlu): kinds and names only, never words.
  @visibleForTesting
  Map<String, Object?> get debugState {
    final cur = _current;
    final todo = _todoWaiting;
    return {
      'wait': wait.name,
      'current': cur?.runtimeType.toString(),
      'currentAction': cur is ManageItem ? cur.action : null,
      'currentKind': cur is CashAdd ? cur.kind.name : null,
      'queue': _askingAll ? [for (final c in _queue) c.runtimeType.toString()] : const <String>[],
      'todo': todo?.runtimeType.toString(),
      'bulkOp': _pendingBulk?.action.op,
      'bulkDomain': _pendingBulk?.set.domain,
      'targetKind': _target?.kind.name,
      'sets': _sets.length,
      'lastSetDomain': _sets.isEmpty ? null : _sets.last.domain,
      'lastSetTurn': _sets.isEmpty ? null : _sets.last.turn,
      'turn': _turn,
    };
  }

  /// Counts the user's turns (how long ago a list was shown).
  int _turn = 0;

  /// The on-phone model reading next to the rules, acting on nothing (shadow mode).
  late final NluShadow nluShadow = NluShadow(nluLoaderForTests ?? TfliteRunner.load,
      count: brain.countSource, enabled: () => brain.nluMode != 'off', onCompare: _nluSample, force: nluLoaderForTests != null);

  /// A learning sample (consent only): every reading the model and the rules
  /// disagreed on, and one in ten they agreed on; names replaced, secrets,
  /// numbers and codes never (see lib/nlu/samples.dart).
  void _nluSample(String text, String state, List<NluPiece> pieces, List<String> old, bool same) {
    brain.signalLastSample(text, complained: old.contains('complain_help') || old.contains('correct'));
    brain.signalLastSample(text, complained: false);
    if (!brain.nluSamplesOn) return;
    if (same && _sampleRandom.nextDouble() > 0.1) return;
    final names = [
      for (final e in brain.data.ledger) e.person,
      for (final c in brain.data.contacts) c.name,
      for (final p in pieces)
        if (p.slots['person'] != null) p.slots['person']!,
    ];
    final words = delexicalize(text, names);
    if (words == null) return;
    brain.addNluSample(
      nluSample(textDelex: words, state: state, local: [for (final p in pieces) (p.intent, p.conf)], finalIntents: old, appVer: nluAppVersion, modelVer: brain.nluModelVersion.isEmpty ? 'bundled-1' : brain.nluModelVersion),
      text,
    );
  }

  final _sampleRandom = math.Random();

  /// What the app waits on, in the NLU spec's state names (docs/nlu-spec.md).
  String get _nluState => switch (wait) {
        ChatWait.none => 'idle',
        ChatWait.collect => 'dictating_list',
        ChatWait.bulk => (_pendingBulk?.action.op == 'delete' ? 'confirm_delete' : 'confirm_batch'),
        ChatWait.batchTime || ChatWait.reminderTime || ChatWait.taskTime => 'await_time',
        ChatWait.taskDate || ChatWait.taskDay || ChatWait.changeTo => 'await_new_value',
        ChatWait.yesNo => 'confirm_save',
        ChatWait.callee || ChatWait.whichPerson || ChatWait.name => 'await_person',
        ChatWait.kind => 'await_kind',
        ChatWait.whichItem || ChatWait.whichTask => 'pick_one',
        ChatWait.clarify => 'clarify',
        _ => 'idle',
      };

  String get _nluKind {
    final st = _nluState;
    if (!const {'confirm_delete', 'confirm_batch', 'pick_one', 'clarify'}.contains(st)) return 'none';
    final d = _pendingBulk?.set.domain ?? (_sets.isEmpty ? null : _sets.last.domain);
    return d.toString().contains('reminder') ? 'reminders' : 'tasks';
  }

  /// A change to several items waiting for its yes, and ones already done
  /// (a repeated yes never runs it twice).
  _BulkProposal? _pendingBulk;
  final Set<String> _doneOps = {};
  _BulkBatch? _lastBatch;

  /// The items picked last ("বাকিগুলো" = the list without them).
  List<String> _lastPicked = const [];

  /// The turn of the last thing said or answered that was not about a
  /// shown list (see [_setFor]).
  int _topicTurn = 0;

  /// This turn acted on the list shown (a group change, one of its items
  /// ticked or moved, the answer to its question): the topic stays.
  bool _onList = false;

  /// To-dos just kept together (ids, their one title or '', the turn).
  (List<String>, String, int)? _batchTasks;

  /// The part of the day said for them ("দুপুরে"), the hour asked.
  String? _batchPart;

  /// Sentences said after a list command in the same message, heard next.
  String? _bulkRest;
  String? _afterWait;

  /// What was just refused ("না"), in case it is asked for again another
  /// way: "অন্যান্য হিসাবে … বিভাগ খুলে এগুলো রাখবে".
  (List<Command>, DateTime)? _refused;

  /// A separate account asked for ("শিক্ষার্থীদের বেতনের হিসাব রাখো নাই?"),
  /// for "অন্যান্য হিসাবে তা খুলো" a moment later.
  (String, DateTime)? _accountWanted;

  /// The parts of one request still to do after the question one of them
  /// asked ("এই ৫টা মুছে দেব?"), resolved against the list as it was shown.
  (List<(BulkAction, List<String>)>, ResultSet)? _planRest;

  /// A sentence with a day its month does not have ("৩১ নভেম্বর ঢাকায়
  /// যাব"): kept until the right date is said.
  (String, DateTime)? _badDate;

  /// To-dos of a month or year to be reminded at a time, waiting for the
  /// day ("মে মাসের কত তারিখে?"): their ids, the time, their first day.
  (List<String>, int, DateTime)? _spanRemind;

  /// The to-do whose day is asked ("পার্টির তারিখ যুক্ত কর").
  String? _dateTaskId;

  /// The turn of the last save (its next steps are offered only right after it).
  int _savedTurn = -1;

  /// One-tap next steps for the conversation now (see bulk_chat.dart).
  List<String> get followUps => _followUps;

  /// The reading "দ্বিতীয়টা ভুল" pointed at, waiting for its right value.
  String? _healthFix;

  /// The list a bulk choice ("দেখানো ৫টা, নাকি পাওয়া সব ২০টা?") is about.
  ResultSet? _clarifySet;

  /// The lists shown, for tests.
  @visibleForTesting
  List<ResultSet> get debugSets => _sets;

  /// When the app's open question was asked: an answer hours later is not
  /// taken as its answer (see [hear]).
  DateTime? _waitAt;

  /// A to-do request waiting for "কোনটা?" or "কয়টায়?", and the choices.
  Command? _todoWaiting;

  /// The time offered with "কখন মনে করিয়ে দেব? যেমন …": a plain yes takes it.
  String? _offeredTime;

  /// A bare "হ্যাঁ" to that question was asked back once: the next yes takes it.
  bool _offerAsked = false;

  /// The saved item a clarify choice about changing it is about.
  Target? _clarifyTarget;
  List<Task> _todoChoices = const [];

  /// The reminder just set for a to-do ("না, এগারোটায়" changes it).
  String? _focusReminderId;
  DateTime? _focusReminderAt;

  /// Things done (saved or changed) — to tell a repeated callback from a new request.
  int _actions = 0;
  String _lastText = '';
  DateTime? _lastTextAt;
  int _actionsAtLast = 0;

  /// To-dos kept together in one breath, for one line at the end.
  final _batchTaskTitles = <String>[];

  List<Task> _clearable(TasksClear c) {
    final today = dayOnly(_now);
    if (c.ids.isNotEmpty) return [for (final t in brain.data.tasks) if (c.ids.contains(t.id)) t];
    if (c.doneOnly) return [for (final t in brain.data.tasks) if (t.done) t];
    return [
      for (final t in brain.data.tasks)
        // A day's to-dos to remove: those planned for that one day (and,
        // for today, late ones) — never a week or month plan that only
        // passes through it.
        if (!t.done && (c.day == null || (t.due != null && t.span == TaskSpan.day && (dayOnly(t.due!) == c.day || (c.day == today && dayOnly(t.due!).isBefore(today)))))) t,
    ];
  }

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

  /// "সকালে কয়টায়?": the part of the day already said, so "আটটায়" stays in it.
  String? _pendingPart;
  DateTime? _pendingAt;
  Repeat _pendingRepeat = Repeat.none;
  bool _pendingAlarm = false;
  int _pendingBefore = 0;
  List<int> _pendingDays = const [];

  /// The last request that did not lead to anything to save (an answer, or
  /// "didn't understand"), so a short follow-up like "আজ" or "সন্ধ্যায়"
  /// can complete it.
  String _lastSaid = '';

  /// "X না, এটা হবে …" with the new word lost: which word, and when asked.
  (String, DateTime)? _swapAsk;

  /// A removal answered "না" (maybe wrongly), for a moment after.
  (ManageItem, Target, DateTime)? _refusedManage;

  /// Venting in a row ("ধুর মিয়া" again and again): each answer shorter.
  int _vents = 0;
  DateTime? _ventAt;
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

  /// "ফেরত পেলাম" more than was owed was pointed out once for this entry.
  bool _overWarned = false;

  /// The kind said before "more than was owed" was asked ("ফেরত দিয়েছে").
  LedgerKind? _overKind;

  /// The command being saved right now, so a repeated "হ্যাঁ" (voice and a
  /// tap together, or a callback fired twice) can never save it twice.
  Command? _executing;
  Command? _executed;

  /// The answers offered by a clarifying question ("কোনটা জানতে চান?").
  List<(String, Command)> _clarifyOptions = const [];

  /// The last money list asked for, so "আর গত মাসে?" or "শুধু খরচ" follows it.
  MoneyListQuery? _focusMoney;

  /// The separate account (অন্যান্য হিসাব) just shown or written to.
  (String, DateTime)? _focusProject;

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
    // "কাজের তালিকা দাও/চাচ্ছি": the list asked to be seen — not dictation.
    if (taskListAsked(t) || RegExp(fold(r'(?:চাই|চাচ্ছি|চাইছি|দেখতে|দেখব|দেখবো)')).hasMatch(fold(normalize(t)))) return false;
    // "টু-ডু লিস্ট খোলো", "কাজের তালিকায় X রাখো": a request, not a list to dictate.
    final asked = parseAll(t, brain.data.ledger, tasks: brain.data.tasks, now: _now);
    if (asked.any((c) => c is OpenPlace || c is TaskEdit || c is TaskDone || (c is TaskAdd && c.title.isNotEmpty))) return false;
    final n = normalize(t);
    if (const ['দেখাও', 'দেখান', 'দেখি', 'বলো', 'বলুন', 'শোনাও', 'দাও', 'দিন', 'দেন', 'দিবা', 'কী', 'কি', 'কত', 'বাকি', 'আছে', 'যে', 'টা'].any((w) => words(n).contains(normalize(w)))) return false;
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
        say = 'ঠিক আছে, $dayWordকাজের তালিকা লিখছি। একটা একটা করে বলুন — শেষ হলে বলুন “শেষ”, বাদ দিতে “বাতিল”। প্রশ্ন করলে লেখা থামিয়ে উত্তর দেব।';
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

  /// Lines dictated before a pause (a question, a complaint): not saved,
  /// not lost — kept on "ওগুলো রাখো", dictation goes on with "লেখা চালাও",
  /// dropped with "বাতিল".
  List<String> _pausedDraft = const [];

  void _pauseCollect(List<String> out, {String why = ''}) {
    wait = ChatWait.none;
    choices = const [];
    if (topic == Topic.task) topic = null;
    if (_collected.isEmpty) {
      _say(out, '$why ${tr('তালিকা লেখা বন্ধ করলাম — কিছু রাখা হয়নি।')}'.trim(), speak: false);
      return;
    }
    _pausedDraft = List.of(_collected);
    _collected.clear();
    _say(out, '$why ${trf('তালিকা লেখা থামালাম। এখন পর্যন্ত {0}টা লেখা হয়েছে, এখনো রাখা হয়নি — রাখতে বলুন “ওগুলো রাখো”, আবার লিখতে “লেখা চালাও”, বাদ দিতে “বাতিল”।', [bnDigits(_pausedDraft.length)])}'.trim(),
        facts: [for (final (i, x) in _pausedDraft.indexed) '${bnDigits(i + 1)}. $x'], speak: false);
  }

  /// After a pause: keep, go on with, or drop the lines dictated.
  bool _pausedDraftAnswer(String t, List<String> out) {
    if (_pausedDraft.isEmpty || wait != ChatWait.none) return false;
    final f = fold(normalize(t)).replaceAll(RegExp(r'[।.!?]'), ' ').trim();
    if (RegExp(fold(r'^(?:ওগুলো|ঐগুলো|সেগুলো|লেখাগুলো|তালিকাটা|তালিকা)\s+(?:রাখো|রেখে\s+দাও|সেভ\s+করো)$|^(?:শেষ|রাখো)$')).hasMatch(f)) {
      _collected
        ..clear()
        ..addAll(_pausedDraft);
      _pausedDraft = const [];
      _finishCollect(out);
      return true;
    }
    if (RegExp(fold(r'^(?:লেখা\s+চালাও|আবার\s+লিখে\s+নাও|আবার\s+লেখো|আরও\s+লিখব|আরো\s+লিখব|চালিয়ে\s+যাও|লিখতে\s+থাকো)$')).hasMatch(f)) {
      _collected
        ..clear()
        ..addAll(_pausedDraft);
      _pausedDraft = const [];
      topic = Topic.task;
      wait = ChatWait.collect;
      _say(out, trf('ঠিক আছে, আগের {0}টার পর থেকে লিখছি — বলুন, শেষ হলে “শেষ”।', [bnDigits(_collected.length)]));
      return true;
    }
    if (isCancel(t)) {
      _say(out, trf('ঠিক আছে, লেখা {0}টা বাদ দিলাম — আগে রাখা কাজগুলো যেমন ছিল আছে।', [bnDigits(_pausedDraft.length)]));
      _pausedDraft = const [];
      return true;
    }
    return false;
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
    // Left open: "…আর", "…তারপর", "খরচ হচ্ছে কোন" (কোন what?).
    if (RegExp(fold(r'(?:^|\s)(?:আর|এবং|তারপর|তার পর|এরপর|এর পর|আরও|আরো|মানে|যেমন|কিন্তু|যে|কোন|কোনো|কোনটা|যদি|তাহলে|নাকি|অথবা|বা)$')).hasMatch(n)) return false;
    // "কাজের তালিকা দাও" is whole; "আজকের কাজের তালিকা" (a heading) waits.
    if (taskListAsked(t)) return true;
    if (const ['তালিকা', 'লিস্ট', 'list'].any((w) => n.contains(normalize(w)))) return false;
    final c = parseAll(t, brain.data.ledger, tasks: brain.data.tasks, contacts: brain.data.contacts, folders: brain.folderHints, now: _now, data: brain.data);
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
  Future<String> hear(String said, {bool echo = true}) async {
    final shown = said.trim();
    if (shown.isEmpty) return '';
    // "…, না আর বলতে চাই না": the closing words only say the person is done
    // talking — they are not something to save or answer.
    final (body, doneTail) = splitDoneTail(shown);
    // "দেনা পাওনা বলি নাই, বলেছি অন্যান্য হিসাব": only what was meant is heard.
    // "আইজকা কি কাম আছে", "kal doctor er kache jabo": in standard Bengali
    // first, so every rule below reads one language (the bubble keeps the words as said).
    // Banglish names: a person already in ধার-দেনা or contacts by sound (owner, 29 Oct).
    final names = {for (final e in brain.data.ledger) e.person, for (final c in brain.data.contacts) c.name};
    final t = shortOrdinal(standardSpeech(meantInstead(doneTail && body.isNotEmpty ? body : shown), names: names));
    if (doneTail) Trace.log('understood', 'closing words left out', {'kept': t});
    ended = false;
    _turn++;
    // The turn before, if it was not about the list shown (a new request,
    // a question, a reminder kept…), is a new topic: a bare "এগুলো" now no
    // longer points at a list shown before it. A list shown by that turn
    // itself still counts.
    if (!_onList) _topicTurn = _turn - 1;
    _onList = false;
    // The same words again within seconds, right after they were acted on:
    // a repeated callback or a retry — never a second entry.
    final wall = DateTime.now();
    if (shown == _lastText && _lastTextAt != null && wall.difference(_lastTextAt!).inSeconds < 8 && _actions > _actionsAtLast && wait == ChatWait.none && _askMainFor == null) {
      Trace.log('understood', 'the same words again at once — not done twice', const {});
      return '';
    }
    _actionsAtLast = _actions;
    _lastText = shown;
    _lastTextAt = wall;
    if (echo) messages.add(ChatMessage.user(shown));
    nluShadow.listen(_turn, shown, _nluState, _nluKind);
    // Only closing words ("না, আর বলতে চাই না") while a save waits for its
    // yes/no: that is "I have nothing more to say", not "don't save it".
    if (doneTail && body.isEmpty && wait == ChatWait.yesNo) {
      Trace.log('understood', 'closing words while a save waits — asked again', const {});
      final out = <String>[];
      _say(out, _askingAll ? tr('ঠিক আছে। তাহলে এগুলো রেখে দিই — হ্যাঁ, নাকি না?') : tr('ঠিক আছে। তাহলে এটা রেখে দিই — হ্যাঁ, নাকি না?'));
      choices = _yesNoChoices;
      notifyListeners();
      return out.join(' ');
    }
    notifyListeners();
    final out = <String>[];
    // "‘…’ হিসাবের আয়-ব্যয় মূল হিসাবেও যোগ হবে?": the answer (anything else
    // leaves it apart, and is heard as itself).
    final askMain = _askMainFor;
    _askMainFor = null;
    // Only a plain yes or no is the answer; a new request ("অন্যান্য হিসাবের সব দাও") is heard as itself.
    final mainYes = askMain == null ? null : mainAnswer(t);
    if (askMain != null && mainYes != null) {
      await brain.setProjectMain(askMain, mainYes);
      choices = const [];
      _say(out, mainYes ? tr('ঠিক আছে — এই হিসাবের আয়-ব্যয় মূল হিসাবেও যোগ হবে।') : tr('ঠিক আছে — এই হিসাব আলাদা থাকবে, মূল হিসাবে যোগ হবে না।'));
      notifyListeners();
      return out.join(' ');
    }
    // "শেষ" ends a list being collected; it is not "stop listening".
    if (_isStop(t) && !(collecting && _isFinish(t))) {
      if (wait != ChatWait.none) _dropPending();
      ended = true;
      _say(out, tr('ঠিক আছে, থামলাম। দরকার হলে মাইক চাপবেন।'));
      notifyListeners();
      return out.join(' ');
    }
    // "কাজের তালিকা দাও" while something waits for a yes (a removal, a
    // save): a new question, never a yes — the waiting one is set aside,
    // unchanged, and the list is shown. (Dictation pauses on its own.)
    // "আজকের কাজগুলো" while "আজকের কাজগুলো, নাকি সব?" waits: the answer.
    final bareChoice = wait == ChatWait.clarify && !t.contains('?') && !RegExp(fold(r'(?:^|\s)(?:দাও|দিন|দেন|দেখাও|দেখান|বলো|বলুন|শোনাও|কি|কী|কোন|কোনো|কয়টা|কত|আছে|চাই|চাচ্ছি)(?:\s|$)')).hasMatch(fold(normalize(t)));
    if (taskListAsked(t) && wait != ChatWait.none && wait != ChatWait.collect && !bareChoice) {
      final removal = wait == ChatWait.bulk;
      _dropPending();
      if (removal) messages.add(ChatMessage.app(tr('মোছার প্রশ্নটা বাদ দিলাম — কিছু মোছা হয়নি।'), info: true));
    }
    // "রিমাইন্ডার লিখে রাখো", "না, কাজের তালিকায় রাখো": about the previous
    // message, which is kept that way instead.
    final redirect = redirectOf(t);
    // "প্রতিমাসে যেন এই কাজটা রিপিট হয়": the to-do just saved comes back every month.
    final lastTask = _lastSave?.$1;
    if (wait == ChatWait.none && lastTask is TaskAdd && RegExp(fold(r'(?:প্রতি\s*মাসে|প্রতিমাসে|মাসে\s+মাসে)')).hasMatch(fold(t)) && RegExp(fold(r'(?:রিপিট|বারবার|আবার\s+আসে|ফিরে\s+আসে|প্রতিবার|হয়)')).hasMatch(fold(t))) {
      // The same to-do, now coming back on that day of every month.
      final task = brain.data.tasks.where((x) => x.title == lastTask.title && !x.done).lastOrNull;
      if (task != null) {
        final snap = brain.snapshot();
        final r = TaskRepeat.monthly(task.due?.day ?? _now.day);
        await brain.saveTask(task.copyWith(repeat: r, due: r.nextOnOrAfter(task.due ?? _now)));
        _focusTask(task);
        Trace.log('understood', 'the last to-do made monthly', const {});
        _say(out, trf('ঠিক আছে, “{0}” প্রতি মাসের {1} তারিখে ফিরে আসবে।', [task.title, bnDigits(r.monthDay)]), links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
        _offerUndo(snap);
        notifyListeners();
        return out.join(' ');
      }
    }
    if (wait == ChatWait.none && await _cashToProject(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    if (wait == ChatWait.none && await _specialFix(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    if (wait == ChatWait.none && _aboutJustKept(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    if (wait == ChatWait.none && await _notesToTasks(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    if (redirect != null && await _redirect(redirect, t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    // A question left unanswered for over 30 minutes has lapsed: the words
    // now are a new request, never a late "yes" or answer to it.
    if (wait != ChatWait.none && _waitAt != null && _now.difference(_waitAt!).inMinutes > 30) {
      Trace.log('understood', 'the open question had lapsed — dropped', const {});
      _dropPending();
    }
    if (wait != ChatWait.none) {
      // "না। ৬৪ হাজার টাকা যে ফাউন্ডেশনের কাছে পাবো তার নাম": the "no" answers
      // the question; what follows is a new thing to hear.
      final (answer, rest0) = _answerAndRest(t);
      if (await _answer(answer, out)) {
        // A sentence left from the message that asked this, now heard.
        final after = wait == ChatWait.none ? _afterWait : null;
        if (after != null) _afterWait = null;
        final rest = rest0 ?? after;
        if (rest != null) {
          notifyListeners();
          final more = await hear(rest, echo: false);
          return [...out, more].where((x) => x.isNotEmpty).join(' ');
        }
        notifyListeners();
        return out.join(' ');
      }
      _dropPending();
    }
    // "তুবার জন্মদিনের রিমাইন্ডার সন্ধ্যা ৭টায় করে দাও", "৩১ অক্টোবরের
    // রিমাইন্ডারের সময় বদলাও": a reminder already kept, changed — never a
    // second reminder made beside it.
    if (wait == ChatWait.none && await _reminderChange(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    // "এইগুলো সব মুছে দাও", "প্রথম দুটো কাল রাখো": several items of the
    // list just shown — before any rule that reads one item or the database.
    if (wait == ChatWait.none && await _bulk(t, out)) {
      final rest = _bulkRest;
      _bulkRest = null;
      if (rest != null && wait == ChatWait.none) {
        notifyListeners();
        final more = await hear(rest, echo: false);
        return [...out, more].where((x) => x.isNotEmpty).join(' ');
      }
      // Asked first ("এই ৫টা মুছে দেব?"): the rest is heard after the answer.
      if (rest != null) _afterWait = rest;
      notifyListeners();
      return out.join(' ');
    }
    _bulkRest = null;
    // "দুপুরে দাওয়াত" right after "২৩ ও ২৪ তারিখে দাওয়াত" was kept: a time
    // for those to-dos — not a new reminder for tomorrow.
    // "৩১ নভেম্বর ঢাকায় যাব" → asked → "৩০ নভেম্বর": the same sentence, that day.
    final badBefore = _badDate;
    if (wait == ChatWait.none && badBefore != null && _now.difference(badBefore.$2).inMinutes <= 10 && _beyondWhen(t) == 0 && (parseWhen(tidySpeech(t), _now)?.hasDay ?? false)) {
      _badDate = null;
      final fixed = badBefore.$1.replaceFirst(RegExp(fold(r'[০-৯0-9]{1,2}\s*(?:তারিখ\S*|ই|শে|লা|এ)?\s+(?:জানুয়ারি|ফেব্রুয়ারি|মার্চ|এপ্রিল|মে|জুন|জুলাই|আগস্ট|সেপ্টেম্বর|অক্টোবর|নভেম্বর|ডিসেম্বর)\S*')), tidySpeech(t).replaceAll(RegExp(r'[।.!?]+$'), ''));
      notifyListeners();
      final more = await hear(fold(fixed) == fold(badBefore.$1) ? '${tidySpeech(t)} ${badBefore.$1}' : fixed, echo: false);
      return [...out, more].where((x) => x.isNotEmpty).join(' ');
    }
    if (wait == ChatWait.none && invalidDayOfMonth(t, _now) != null) {
      _badDate = (fold(normalize(t)), _now);
      _say(out, invalidDayOfMonth(t, _now)!);
      notifyListeners();
      return out.join(' ');
    }
    if (await _voiceUndo(t, out)) {
      _dropPending();
      wait = ChatWait.none;
      notifyListeners();
      return out.join(' ');
    }
    // "বাড়ি মেরামতের হিসাব দেখাও" (or anything naming one account): "এই
    // কাজে …" right after is about it.
    final named = projectMeant(brain.data, t);
    if (named != null) _focusProject = (named.name, _now);
    if (wait == ChatWait.none && await _moveCashInto(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    if (wait == ChatWait.none && await _remindByDayOrHere(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    if (wait == ChatWait.none && _envelopeLeft(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    if (wait == ChatWait.none && _amountDoubt(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    if (wait == ChatWait.none && await _accountTalk(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    if (wait == ChatWait.none && await _eachTaskReminder(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    if (wait == ChatWait.none && await _batchWhenFor(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    if (wait == ChatWait.none && await _batchTimeFor(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    // "না" to money just offered, then "অন্যান্য হিসাবে শিক্ষার্থীদের বেতন
    // সংক্রান্ত বিভাগ খুলে এগুলো রাখবে": the same items, into that account.
    if (wait == ChatWait.none && _refusedAsDues(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    if (wait == ChatWait.none && await _refusedIntoProject(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    // "হ্যা, সকাল ৯টায়" right after a reminder was kept at that time: a
    // yes to it — never a second reminder.
    final last = _lastSave;
    if (wait == ChatWait.none && last != null && last.$1 is ReminderAdd && _now.difference(last.$3).inMinutes <= 5 && yesNo(t.split(RegExp(r'[,।]')).first) == true) {
      final r = last.$1 as ReminderAdd;
      final w = parseWhen(t, _now);
      final leftover = words(normalize(withoutWhen(withoutClockWords(t)))).where((x) => yesNo(x) != true);
      if (w != null && w.hasTime && w.at.hour == r.at.hour && w.at.minute == r.at.minute && leftover.isEmpty) {
        _say(out, r.repeat == Repeat.daily ? trf('হ্যাঁ, প্রতিদিন {0}-এ রাখা আছে।', [bnTime(r.at.hour, r.at.minute)]) : trf('হ্যাঁ, {0}-এ রাখা আছে।', [sayWhen(r.at, _now)]));
        notifyListeners();
        return out.join(' ');
      }
    }
    // "না, এগারোটায়" right after a to-do's reminder: that one, changed.
    if (await _todoCorrection(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    // "না। কাজের নাম বদল কর" right after something was kept: what was kept
    // was a rename asked for — taken back, and the rename done (or asked).
    if (await _renameInstead(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    // Right after a to-do or reminder was kept at once: "এটা তো বলি নাই"
    // takes it back; "X শব্দটা বাদ দিও" / "শুধু লিখবা Y" change its words.
    if (wait == ChatWait.none && await _afterSave(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    // "হ্যাঁ" right after something was kept at once: nothing more to do.
    final lastSave = _lastSave;
    if (wait == ChatWait.none && lastSave != null && _now.difference(lastSave.$3).inMinutes <= 2 && words(normalize(t)).isNotEmpty && words(normalize(t)).length <= 3 && words(normalize(t)).every((w) => yesNo(w) == true)) {
      _say(out, tr('ঠিক আছে।'));
      notifyListeners();
      return out.join(' ');
    }
    // "না, পাঁচটায় নয়, ছয়টায়" with nothing just said to correct: asked,
    // never saved as a reminder called "না, নয়".
    if (wait == ChatWait.none && _onlyCorrection(t)) {
      _say(out, tr('কোনটার সময় বদলাব? কাজ বা রিমাইন্ডারের নামসহ আরেকবার বলুন।'));
      notifyListeners();
      return out.join(' ');
    }

    if (_pausedDraftAnswer(t, out)) {
      notifyListeners();
      return out.join(' ');
    }
    // "কি?", "কি করতেছো?", "তোমাকে কি প্রশ্ন করি": what the app is doing,
    // and how to ask — nothing kept.
    if (wait == ChatWait.none && confusedOrHelp(t)) {
      _say(out, tr('এখন কিছু করছি না — আপনার কথার অপেক্ষায় আছি। কাজ দেখতে বলুন “আমার কাজের তালিকা দাও”; নতুন কাজ রাখতে “কাল ব্যাংকে যাব, তালিকায় রাখো”; টাকার হিসাব জানতে “এই মাসে কত খরচ হলো?”।'));
      notifyListeners();
      return out.join(' ');
    }
    // "একটা একটা করে কাজ লিখে নাও": dictation, asked for in so many words.
    if (wait == ChatWait.none && _held.isEmpty && collectAsked(t)) {
      _history.add(AiTurn.user(t));
      _collectDue = null;
      _setTopic(Topic.task, out);
      notifyListeners();
      return out.join(' ');
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
    final todoHere = todoCommands(tidySpeech(whole), brain.data.tasks, _now);
    // "এই কথাটা আর মনে রেখো না", "হাঁটা বন্ধ না, reminder বন্ধ": a request
    // the menus understand (a negative word inside it is part of it).
    final menuHere = menuCommand(tidySpeech(whole), brain.data, _now);
    // "তুমি কি আমার কথা শুনতেছো না, বলতেছি এটা রাইখো না" (owner's video,
    // 25 Oct): not listened to — say sorry and keep the request the app left
    // unfinished; with none, ask for it once more. Never sent to the AI as a
    // new question (that took seconds and answered something else).
    // "তোমাকে তো আমি বাদ দিতে বলছি, আবার মোছ নাই কেন" right after a "না" to
    // "মুছে দেবো?": the "না" was taken wrongly — removed now, with an undo.
    final refused = _refusedManage;
    if (refused != null && _now.difference(refused.$3).inMinutes <= 5 && insistsOnDelete(whole) && refused.$1.action == 'delete') {
      _refusedManage = null;
      _history.add(AiTurn.user(whole));
      final snap = brain.snapshot();
      await brain.deleteTarget(refused.$2);
      _actions++;
      _say(out, trf('দুঃখিত, ভুল বুঝেছিলাম। মুছে দিলাম — {0}।', [refused.$2.label]));
      _offerUndo(snap);
      notifyListeners();
      return out.join(' ');
    }
    final shortKeep = keepThat(whole) && words(normalize(whole)).length <= 5 && _lastSaid.isNotEmpty;
    // "ধুর মিয়া", "আরে বোকা …", "ভাবতে লাগাও আধা ঘণ্টা" (owner's video, 25
    // Oct: "ইউজারের কথার ইমোশন বুঝতে হবে"): venting is answered as venting.
    final mood = moodOf(whole) ?? (shortKeep ? Mood.unheard : null);
    if (mood != null) {
      _history.add(AiTurn.user(whole));
      final sorry = switch (mood) {
        Mood.annoyed => tr('দুঃখিত, আপনাকে বিরক্ত করে ফেলেছি।'),
        Mood.impatient => tr('দুঃখিত, দেরি করে ফেলেছি।'),
        Mood.unheard => tr('দুঃখিত, আগেরবার ঠিক ধরতে পারিনি।'),
      };
      // A request said along with it ("ধুর, কাল সকাল ১০টায় মনে করিয়ে দিও"):
      // that request, after the sorry.
      final rest = withoutVenting(whole);
      final restWhen = parseWhen(rest, _now);
      if (words(rest).length >= 3 && ((restWhen?.hasTime ?? false) || findAmount(rest) != null)) {
        Trace.log('understood', 'venting, with a request in it', const {});
        _say(out, sorry);
        return _understand(withoutVenting(whole, keepWords: true), out, shown: whole);
      }
      // "এটা রাইখো না" after a request left unfinished: that request, kept.
      final prev = _lastSaid;
      final fresh = prev.isNotEmpty && _lastSaidAt != null && _now.difference(_lastSaidAt!).inMinutes <= 10;
      if (fresh && keepThat(whole)) {
        final timed = parseWhen(prev, _now)?.hasTime ?? false;
        final redo = timed ? '$prev মনে করিয়ে দিও' : '$prev — কাজের তালিকায় লিখে রাখো';
        Trace.log('understood', 'not listened to — the unfinished request kept', const {});
        _say(out, sorry);
        return _understand(redo, out, shown: whole);
      }
      // Something was just kept: say what, so a wrong word can be named.
      final kept = _lastSave;
      String? keptLine;
      if (kept != null && _now.difference(kept.$3).inMinutes <= 5) {
        final r = brain.data.reminders.where((x) => x.id == _focusReminderId).firstOrNull;
        final k = brain.data.tasks.where((x) => x.id == _focusTaskId).firstOrNull;
        keptLine = r != null
            ? '“${r.title}” — ${r.repeat == Repeat.daily ? tr('প্রতিদিন') : sayWhen(DateTime(r.date.year, r.date.month, r.date.day), _now, withTime: false)} ${bnTime(r.hour, r.minute)}'
            : k != null
                ? '“${k.title}”'
                : summaryLine(kept.$1);
      }
      // Said again and again: not the same long answer each time.
      final again = _ventAt != null && _now.difference(_ventAt!).inMinutes <= 3;
      _vents = again ? _vents + 1 : 1;
      _ventAt = _now;
      final text = _vents >= 3
          ? tr('বুঝতে পারছি, আপনি বিরক্ত — আমি দুঃখিত। এক লাইনে বলুন কী চান, আমি সেটাই করব। চাইলে কিবোর্ডে লিখেও দিতে পারেন।')
          : _vents == 2
              ? '$sorry ${keptLine != null ? trf('এখন আছে {0}। কী বদলাব, শুধু সেটুকু বলুন।', [keptLine]) : tr('কী করব, ছোট করে বলুন।')}'
              : keptLine != null
                  ? '$sorry ${trf('এখন রাখা আছে — {0}। ভুল হলে বলুন “এটা রাখতে বলিনি”, বা কোন শব্দ বদলাব — যেমন “X না, Y”।', [keptLine])}'
                  : '$sorry ${tr('এবার মন দিয়ে শুনছি — কী করব, আরেকবার বলুন; সময় থাকলে সময়সহ।')}';
      _say(out, text);
      _history.add(AiTurn.app(text));
      _lastSaid = '';
      notifyListeners();
      return out.join(' ');
    }
    if (!isQuestionText(whole) && negatedRequest(normalize(whole)) && !(todoHere?.any((c) => c is TaskEdit && c.stopReminder) ?? false) && menuHere is! MenuAction) {
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

  /// "অন্যান্য হিসাবের বাড়ির মেরামত এ লিখ" right after an expense was kept
  /// in the general আয়-ব্যয়: that entry moves into the account (no second one).
  Future<bool> _cashToProject(String t, List<String> out) async {
    final last = _lastSave;
    if (last == null || last.$1 is! CashAdd || _now.difference(last.$3).inMinutes > 10) return false;
    final c = last.$1 as CashAdd;
    if (findAmount(normalize(t)) != null) return false;
    if (!RegExp(fold(r'(?:লেখ|লিখ|রাখ|সরাও|নাও|যোগ|যুক্ত|দাও|মাঝে|ভেতরে|মধ্যে)')).hasMatch(fold(t))) return false;
    final p = projectMeant(brain.data, t);
    if (p == null && !projectPageNamed(t)) return false;
    final e = brain.data.cash.where((x) => x.amount == c.amount && x.kind == c.kind && x.projectId == null && x.linkId == null && dayOnly(x.date) == dayOnly(_now)).lastOrNull;
    if (e == null) return false;
    if (p == null) {
      // Only "অন্যান্য হিসাবে": which account is asked first.
      _moveCashId = e.id;
      final open = brain.data.projects.where((x) => !x.closed).toList();
      _ask(out, trf('{0} টাকার “{1}” অন্যান্য হিসাবের কোনটায় সরাব? বেছে নিন, বা নতুন নাম বলুন।', [bnNumber(e.amount), e.category]), ChatWait.project,
          choices: [for (final x in open.take(5)) ChatChoice(x.name, x.name)]);
      return true;
    }
    return _moveCash(e, p, out);
  }

  /// The expense being moved by "অন্যান্য হিসাবে রাখো" while its account is asked.
  String? _moveCashId;

  /// A হিসাব just opened by voice, waiting for "মূল হিসাবেও যোগ হবে?" (owner, 27 Oct).
  String? _askMainFor;

  /// The answer to "মূল হিসাবেও যোগ হবে?": a plain yes or no, or "যোগ করো" /
  /// "আলাদা রাখো"; anything else is not an answer (null).
  static bool? mainAnswer(String said) {
    final f = said.trim().toLowerCase().replaceAll(RegExp(r'[,।!.?]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (f.isEmpty || f.split(' ').length > 5) return null;
    if (RegExp(r'^(?:না|নাহ|জি না|no)(?: |$)').hasMatch(f) || RegExp(r'^(?:আলাদা|যোগ কর(?:ো|বে|বেন|িও)? না|যোগ হবে না)').hasMatch(f)) return false;
    if (RegExp(r'^(?:হ্যাঁ|হ্যা|হাঁ|হা|জি|জ্বি|ঠিক আছে|আচ্ছা|yes|ok|okay)(?: |$)').hasMatch(f) || RegExp(r'^যোগ (?:করো|কর|করুন|করেন|হবে)$').hasMatch(f)) return true;
    return null;
  }

  /// Asks whether [p]'s entries join the main money; until the answer they do not.
  void _askProjectMain(Project p, List<String> out) {
    if (p.mainAsked) return;
    _askMainFor = p.id;
    _say(out, trf('‘{0}’ হিসাবের আয়-ব্যয় মূল হিসাবেও যোগ হবে? হ্যাঁ বললে যোগ হবে; না বললে বা উত্তর না দিলে আলাদা থাকবে।', [p.name]));
    choices = _yesNoChoices;
  }

  Future<bool> _moveCash(CashEntry e, Project p, List<String> out) async {
    if (!brain.canUseProject(p.id)) {
      _say(out, tr('ফ্রিতে ১টা অন্যান্য হিসাবে লেখা যায়; এর বেশি প্রিমিয়াম সুবিধা — খরচটা যেমন ছিল আছে।'), links: [ChatLink(LinkKind.page, tr('প্রিমিয়াম দেখুন'), page: 'pro')]);
      return true;
    }
    final snap = brain.snapshot();
    await brain.saveCash(CashEntry(id: e.id, kind: e.kind, amount: e.amount, category: e.category, note: e.note, date: e.date, projectId: p.id, accountId: e.accountId, shopId: e.shopId));
    _actions++;
    final ps = projectSums(brain.data.cash, p.id);
    final state = ps.income == 0
        ? trf('‘{0}’-এ এ পর্যন্ত খরচ {1} টাকা।', [p.name, bnNumber(ps.expense)])
        : ps.balance >= 0
            ? trf('‘{0}’-এ এখন হাতে আছে {1} টাকা।', [p.name, bnNumber(ps.balance)])
            : trf('‘{0}’-এ আসার চেয়ে {1} টাকা বেশি খরচ হয়েছে।', [p.name, bnNumber(-ps.balance)]);
    _say(out, trf('ঠিক আছে, {0} টাকার “{1}” এখন ‘{2}’ হিসাবে — সাধারণ আয়-ব্যয় থেকে সরিয়েছি। {3}', [bnNumber(e.amount), e.category, p.name, state]),
        links: [ChatLink(LinkKind.page, tr('অন্যান্য হিসাব'), page: 'projects')]);
    _offerUndo(snap);
    return true;
  }

  /// One item of the list waiting for "সবগুলো রেখে দিই?" named by a word of
  /// it and said again as income, spending or into a separate account: that
  /// item is replaced and the list is asked again. Nothing is kept yet.
  bool _editQueued(String t, List<String> out) {
    // "খরচ মাত্র ১৫০ টাকা?" asks about the list; it changes nothing.
    if (isQuestionText(t)) return false;
    // An item is named by its words, never by an amount.
    final said = [for (final w in words(normalize(t))) if (w.length >= 3 && !RegExp(r'^\d').hasMatch(w)) w];
    const common = {'অন্যান্য', 'হিসাবের', 'হিসাবে', 'হিসাব', 'ভেতরে', 'ভিতরে', 'যুক্ত', 'টাকা', 'যথাযথ', 'ভাবে', 'হয়নি', 'বেতন', 'বেতনে', 'আয়', 'খরচ', 'লিখ', 'লেখো', 'রাখো', 'করো'};
    int? at;
    for (var i = 0; i < _queue.length; i++) {
      final c = _queue[i];
      if (c is! CashAdd && c is! LedgerAdd) continue;
      final item = words(normalize(c.transcript));
      final hit = said.any((w) => !common.contains(w) && item.any((x) => x.length >= 3 && (w.startsWith(x) || x.startsWith(w)) && (w.length - x.length).abs() <= 3));
      if (!hit) continue;
      if (at != null) return false; // two items named: not clear which
      at = i;
    }
    if (at == null) return false;
    final c = _queue[at];
    final amount = c is CashAdd ? c.amount : (c as LedgerAdd).amount;
    final f = fold(normalize(t));
    final p = projectMeant(brain.data, t);
    final toProject = p != null || projectPageNamed(t);
    final income = RegExp(fold(r'(?:আয়|বেতন|এসেছে|পেয়েছি|পেলাম|দিয়েছে|ইনকাম)')).hasMatch(f);
    final spend = RegExp(fold(r'(?:খরচ|ব্যয়)')).hasMatch(f);
    if (!toProject && !income && !spend) return false;
    final kind = spend && !income ? CashKind.expense : (income ? CashKind.income : (c is CashAdd ? c.kind : CashKind.income));
    final category = RegExp(fold('বেতন')).hasMatch(f) ? 'বেতন' : (c is CashAdd ? c.category : (kind == CashKind.income ? 'অন্যান্য আয়' : 'অন্যান্য'));
    _queue[at] = CashAdd(c.transcript, kind: kind, amount: amount, category: category, project: toProject ? (p?.name ?? '') : null);
    _ask(out, tr('ঠিক আছে, ওটা বদলে দিলাম। এখন এভাবে রেখে দিই?'), ChatWait.yesNo, choices: _yesNoChoices, facts: [for (final x in _queue) summaryLine(x)]);
    return true;
  }

  /// The special day kept last in this conversation (id, when).
  (String, DateTime)? _lastSpecial;

  /// "আমি বললাম ফেব্রুয়ারী, তুমি নভেম্বর কেন করছো?", "এটা ১৫ ফেব্রুয়ারী
  /// হবে": the special day just kept (or the one named) gets that date —
  /// its yearly reminder moves with it. Nothing new is kept.
  Future<bool> _specialFix(String t, List<String> out) async {
    final n = normalize(tidySpeech(t));
    final f = ' ${fold(n)} ';
    // About that day, not a new thing: "এটা …", "আমি বললাম …", "… কেন", "ভুল".
    final pointing = RegExp(fold(r'(?:বললাম|বলেছি|বলছি|কেন|ভুল|ঠিক\s+কর|(?<=\s)(?:এটা|ওটা|সেটা|এইটা|এটার)(?=\s))')).hasMatch(f);
    final changing = RegExp(fold(r'(?<=\s)(?:হবে|করো|কর|লেখো|রাখো)(?=\s)')).hasMatch(f);
    if (!pointing && !changing) return false;
    final date = dayMonthIn(n);
    // Months as words of their own ("মে" inside "রহিমের" is not May).
    final ws = words(n);
    var monthOnly = date == null ? [for (var i = 0; i < bnMonths.length; i++) if (ws.contains(normalize(bnMonths[i]))) i + 1] : const <int>[];
    if (date == null && monthOnly.isEmpty) return false;
    // "তাইলে ১৫ নভেম্বর কেন বলো?", "মাত্র যে বললাম ১৫ ফেব্রুয়ারী?": the day
    // in a "why"/"I said" question is never the day to move to blindly.
    // Two of the same kind kept (an old wrong one and the right one): the
    // one on the day complained about is offered for removal — asked once.
    if (date != null) {
      final why = RegExp(fold(r'(?:^|\s)কেন(?:\s|$)')).hasMatch(f) && !changing;
      final hits = [for (final x in brain.data.specialDays) if (x.month == date.$2 && x.day == date.$1) x];
      if (hits.length == 1) {
        final h = hits.single;
        final twins = [for (final x in brain.data.specialDays) if (x.id != h.id && x.kind == h.kind && x.kind != SpecialKind.birthday) x];
        if (why && twins.isNotEmpty) {
          final keep = twins.first;
          _current = ManageItem(t, action: 'delete');
          await _confirmManage(Target(ItemKind.special, h.id, '${specialTitle(h)} — ${bnDigits(h.day)} ${monthName(h.month)}', h.person, DateTime(2000)), out);
          messages.insert(messages.length - 1, ChatMessage.app(trf('দুঃখিত — {0} দুটো রাখা আছে: {1} {2} (পুরোনো, ভুল) আর {3} {4}। পুরোনোটা মুছে দিলে শুধু {3} {4} থাকবে।', [h.kind.bn, bnDigits(h.day), monthName(h.month), bnDigits(keep.day), monthName(keep.month)])));
          return true;
        }
        if (!why && pointing && RegExp(fold(r'(?:বললাম|বলেছি|বলছি|মাত্র)')).hasMatch(f)) {
          final extra = twins.isEmpty ? '' : ' ${trf('তবে আগের একটা {0}ও আছে — {1} {2}। ভুল হলে বলুন “{1} {2}-এরটা মুছে দাও”।', [h.kind.bn, bnDigits(twins.first.day), monthName(twins.first.month)])}';
          _say(out, trf('{0} — {1} {2}, এভাবেই রাখা আছে।', [specialTitle(h), bnDigits(h.day), monthName(h.month)]) + extra);
          _lastSpecial = (h.id, _now);
          return true;
        }
      }
      if (why) {
        // Asked why that day was said: explained, nothing moved.
        if (hits.isEmpty) return false;
        _say(out, trf('{0} {1} {2}-এ রাখা আছে। বদলাতে বলুন, যেমন “{0} ১৫ ফেব্রুয়ারি হবে”।', [specialTitle(hits.first), bnDigits(hits.first.day), monthName(hits.first.month)]));
        return true;
      }
    }
    SpecialDay? target;
    final last = _lastSpecial;
    if (last != null && _now.difference(last.$2).inMinutes <= 60) target = brain.data.specialDays.where((x) => x.id == last.$1).firstOrNull;
    final named = [for (final x in brain.data.specialDays) if (n.contains(normalize(x.kind.bn)) || (x.person.length > 1 && n.contains(normalize(x.person)) && x.person != 'আমার')) x];
    if (named.length == 1) target = named.single;
    if (target == null || (!pointing && named.length != 1)) return false;
    // "আমি বললাম ফেব্রুয়ারী, তুমি নভেম্বর কেন করছো?": the month that is
    // not the one kept is the one meant.
    if (monthOnly.length > 1) {
      // The month right after "বললাম/বলেছি" is what was said; otherwise the one not kept.
      final said = RegExp(fold('(?:বললাম|বলেছি|বলছি|বলেছিলাম)')).firstMatch(n);
      int? pos(int m) {
        final i = n.indexOf(' ${normalize(bnMonths[m - 1])}', said?.end ?? 0);
        return i < 0 ? null : i;
      }
      final after = said == null ? <int>[] : ([for (final m in monthOnly) if (pos(m) != null) m]..sort((a, b) => pos(a)!.compareTo(pos(b)!)));
      monthOnly = after.isNotEmpty ? [after.first] : [for (final m in monthOnly) if (m != target.month) m];
    }
    if (date == null && monthOnly.length != 1) return false;
    final month = date?.$2 ?? monthOnly.single;
    final day = date?.$1 ?? target.day;
    if (month == target.month && day == target.day) {
      _say(out, trf('{0} — {1} {2}, এভাবেই রাখা আছে।', [specialTitle(target), bnDigits(day), monthName(month)]));
      return true;
    }
    if (DateTime(2024, month, day).month != month) return false;
    final snap = brain.snapshot();
    await brain.saveSpecialDay(target.copyWith(month: month, day: day));
    _lastSpecial = (target.id, _now);
    _actions++;
    _say(out, trf('দুঃখিত, ভুল হয়েছিল। {0} এখন {1} {2} — রিমাইন্ডারও সেদিনে সরিয়েছি।', [specialTitle(target), bnDigits(day), monthName(month)]), links: [ChatLink(LinkKind.special, tr('বিশেষ দিনগুলো দেখুন'))]);
    _offerUndo(snap);
    return true;
  }

  /// "তারিখ সহ যুক্ত করেছো?", "কাজ গুলো তারিখ সহ যুক্ত করা দরকার ছিল":
  /// about the to-dos just kept — they are shown as kept, with their days;
  /// never a new to-do, a search or a tick.
  bool _aboutJustKept(String t, List<String> out) {
    final f = ' ${fold(normalize(t))} ';
    if (!RegExp(fold(r'(?:তারিখ|সময়|দিন)')).hasMatch(f)) return false;
    if (!RegExp(fold(r'(?:করেছ|রেখেছ|দিয়েছ|দিছ|লিখেছ|রাখছ|দাও\s*নি|দেও\s*নি|দাও\s+নাই|দেও\s+নাই|দরকার\s+ছিল|উচিত\s+ছিল|দেওয়া\s+হয়নি|দেয়া\s+হয়নি|কই|কোথায়)')).hasMatch(f)) return false;
    if (findAmount(normalize(t)) != null || RegExp(r'\d').hasMatch(f)) return false;
    final kept = [for (final x in brain.data.tasks) if (!x.done && !_now.difference(x.createdAt).isNegative && _now.difference(x.createdAt).inMinutes <= 15) x];
    if (kept.isEmpty) return false;
    final dated = kept.where((x) => x.due != null).length;
    final head = dated == kept.length
        ? trf('জি, {0}টা কাজই তারিখসহ রেখেছি:', [bnDigits(kept.length)])
        : dated == 0
            ? trf('এই {0}টা কাজ তারিখ ছাড়া রাখা আছে। তারিখ বলুন — যেমন “প্রথমটা ১২ তারিখে” — বসিয়ে দেব।', [bnDigits(kept.length)])
            : trf('{0}টার তারিখ আছে, {1}টার নেই:', [bnDigits(dated), bnDigits(kept.length - dated)]);
    _say(out, head, facts: [for (final x in kept) taskLine(x, _now)], links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
    _rememberSet('tasks', '', [for (final x in kept) x.id], source: t);
    return true;
  }

  /// A plain yes or no that a sentence of its own follows ("না। …", "হ্যাঁ, আর …"):
  /// (the answer, the rest). The rest is null when there is none to hear.
  (String, String?) _answerAndRest(String t) {
    if (wait != ChatWait.yesNo) return (t, null);
    final m = RegExp(fold(r'^\s*(না|নাহ|জি\s+না|হ্যাঁ|হ্যা|জি|জ্বি)\s*[।.,!]+\s*(.+)$')).firstMatch(fold(t));
    if (m == null) return (t, null);
    final rest = m[2]!.trim();
    if (words(normalize(rest)).length < 3) return (t, null);
    // "না। অন্যান্য হিসাবের ভেতরে বাড়ির মেরামতে" while an expense waits: not
    // a refusal — the place it goes, answered as one.
    final cur = _current;
    if (cur is CashAdd && cur.project == null && !_askingAll && (projectMeant(brain.data, rest) != null || projectPageNamed(rest))) return (rest, null);
    return (m[1]!, rest);
  }

  /// "আগের কাজ গুলো নোট এ কেন রাখছো? কাজের তালিকায় রাখা উচিত ছিল": the
  /// notes this conversation kept become to-dos (one undo brings them back).
  Future<bool> _notesToTasks(String t, List<String> out) async {
    final f = ' ${fold(normalize(t))} ';
    if (!RegExp(fold(r'(?<=\s)নোট')).hasMatch(f) || !RegExp(fold(r'(?:কাজের\s+(?:তালিকা|লিস্ট)|কাজ\s+হিসেবে|কাজ\s+হিসাবে|টুডু)')).hasMatch(f)) return false;
    if (!RegExp(fold(r'(?:কেন|উচিত|ভুল|সরাও|সরিয়ে|নিয়ে\s+যাও|রাখো|রাখ|নাও|বদলাও)')).hasMatch(f)) return false;
    var recent = [for (final n in _notesKept) if (_now.difference(n.$3).inMinutes <= 60 && brain.data.notes.any((x) => x.id == n.$1)) n];
    // Kept in an earlier conversation today: the notes written in the last hours.
    if (recent.isEmpty) {
      recent = [for (final n in brain.data.notes) if (_now.difference(n.updatedAt).inHours < 6 && !_now.difference(n.updatedAt).isNegative) (n.id, n.body.isEmpty ? n.title : n.body, n.updatedAt)];
    }
    if (recent.isEmpty) {
      _say(out, tr('সম্প্রতি কোনো নোট রাখা হয়নি যেটা কাজের তালিকায় সরাব। কাজটা বলুন — সরাসরি কাজের তালিকায় রাখব।'));
      return true;
    }
    final snap = brain.snapshot();
    final titles = <String>[];
    for (final n in recent) {
      final cmd = convertTo('task', n.$2, brain.data.ledger, _now);
      if (cmd is! TaskAdd || cmd.title.trim().isEmpty) continue;
      await brain.deleteNote(n.$1);
      await brain.saveTask(Task(title: cmd.title, due: cmd.due, createdAt: _now, span: cmd.span));
      titles.add(cmd.due == null ? cmd.title : '${cmd.title} (${sayWhen(cmd.due!, _now, withTime: false)})');
      _notesKept.remove(n);
    }
    if (titles.isEmpty) return false;
    _actions++;
    _say(out, trf('ঠিক বলেছেন — ভুল জায়গায় রেখেছিলাম। {0}টা নোট কাজের তালিকায় সরিয়ে দিলাম।', [bnDigits(titles.length)]), facts: titles, links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
    _offerUndo(snap);
    return true;
  }

  Future<bool> _redirect(String kind, String said, List<String> out) async {
    bool movable(Command c) => c is NoteAdd || c is TaskAdd || c is ReminderAdd || c is MemoryAdd;
    String textOf(Command c) => switch (c) { NoteAdd(:final text) => text, MemoryAdd(:final text) => text, _ => c.transcript };
    String kindOf(Command c) => switch (c) { ReminderAdd(:final alarm) => alarm ? 'alarm' : 'reminder', TaskAdd() => 'task', _ => 'note' };
    String? src;
    Command? from;
    var moved = false;
    final cur = _current;
    final last = _lastSave;
    if (wait != ChatWait.none && cur != null && movable(cur)) {
      // Asked about the previous message ("নতুন বিভাগে রাখি?"): keep it the way said instead.
      src = textOf(cur);
      from = cur;
      _dropPending();
    } else if (last != null && movable(last.$1) && _now.difference(last.$3).inMinutes < 5) {
      if (kindOf(last.$1) == kind) {
        _say(out, tr('জি, ওটা সেভাবেই রাখা আছে।'));
        return true;
      }
      await brain.restoreSnapshot(last.$2);
      src = textOf(last.$1);
      from = last.$1;
      moved = true;
    } else {
      // The message before this one.
      final users = [for (final m in messages) if (m.fromUser) m.text];
      if (users.length >= 2) src = users[users.length - 2];
    }
    if (src == null || src.trim().isEmpty || redirectOf(src) != null) return false;
    _lastSave = null;
    _history.add(AiTurn.user(said));
    // A reminder made a to-do ("মনে করানোর প্রয়োজন নেই, কাজের তালিকায় রাখো"):
    // its own title and day — and no ring, which was the point.
    final cmd = kind == 'task' && from is ReminderAdd && from.title.trim().isNotEmpty
        ? TaskAdd(said, title: from.title, due: dayOnly(from.at))
        : convertTo(kind, src, brain.data.ledger, _now);
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
    final kind = kindNamed(text);
    if (found.isEmpty) {
      // The example fits what was asked about — a to-do, a reminder, money.
      final example = switch (kind) {
        ItemKind.task => tr('“বাজারের কাজটা মুছে দাও”'),
        ItemKind.reminder => tr('“মিটিংয়ের রিমাইন্ডারটা মুছে দাও”'),
        ItemKind.note => tr('“ওয়াইফাইয়ের নোটটা মুছে দাও”'),
        ItemKind.ledger || ItemKind.cash => tr('“রহিমের ৫০০ টাকার লেনদেনটা মুছে দাও”'),
        _ => tr('“বাজারের কাজটা মুছে দাও”'),
      };
      _say(out, trf('কোনটা {0}, খুঁজে পেলাম না। নাম বা তারিখ বলে আরেকবার বলুন — যেমন {1}।', [verb, example]),
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
    // "তুবার জন্মদিনের রিমাইন্ডারের সময় পরিবর্তন কর": the new time asked
    // here, in the chat — no page opened for one value.
    if (_change.isEmpty && (t.kind == ItemKind.reminder || t.kind == ItemKind.task) && RegExp(fold(r'(?:সময়|টাইম|time|কয়টায়|তারিখ|দিন)')).hasMatch(fold(normalize(c.transcript)))) {
      _ask(out, t.kind == ItemKind.reminder ? trf('“{0}” — নতুন সময় কত? যেমন “সন্ধ্যা ৭টায়”।', [t.label]) : trf('“{0}” — নতুন তারিখ কবে? যেমন “২৮ অক্টোবর”।', [t.label]), ChatWait.changeTo);
      return;
    }
    if (_change.isEmpty) {
      // No new time or amount said: open it to change by hand.
      final link = ChatLink(LinkKind.page, trf('বদলান: {0}', [t.label]), page: 'edit:${t.kind.name}', folder: t.id);
      _say(out, trf('“{0}” — বদলানোর পাতা খুলছি।', [t.label]), links: [link]);
      openNow = link;
      _current = null;
      wait = ChatWait.none;
      return;
    }
    // The same time it already has ("রিমাইন্ডার সেট করো প্রতিদিন ৮:৪৫" said
    // again): never "X বদলে X করে দেবো?" — it is already so.
    final same = t.kind == ItemKind.reminder && _change.at != null && _change.amount == null
        ? brain.data.reminders.where((r) => r.id == t.id && r.hour == _change.at!.hour && r.minute == _change.at!.minute).firstOrNull
        : null;
    if (same != null) {
      _say(out, trf('“{0}” {1}-এ আগে থেকেই রাখা আছে — কিছু বদলাতে হয়নি।', [same.title, bnTime(same.hour, same.minute)]), links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))]);
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
    List<Command> rules(String s) => parseAll(s, d.ledger, tasks: d.tasks, contacts: d.contacts, folders: brain.folderHints, now: _now, data: d);
    bool acts(Command c) => (isSave(c) && c is! NoteAdd) || c is CallPerson;
    // Only a fragment that means nothing by itself is joined.
    if (!rules(t).every((c) => c is NotUnderstood || c is SearchQuery || c is NoteAdd)) return t;
    final both = '$prev $t';
    return rules(both).any(acts) ? both : t;
  }

  /// [t] is what is understood; [shown] is what the user actually said
  /// this time (kept for the AI's view of the conversation).
  Future<String> _understand(String t, List<String> out, {String? shown}) async {
    // The AI, or ("on" mode) maybe the cloud reading, may take a moment.
    thinking = brain.aiOn || brain.nluMode == 'on';
    notifyListeners();
    final turn = _turn;
    // Typed or spoken: the same model and the same path; the list last
    // shown goes with it, so "৩নং" reaches the AI with what it points at.
    final reading = brain.nluMode == 'on' ? nluShadow.readingFor(turn, t) : null;
    final (understood, problem) = await brain.understandAll(t,
        history: List.of(_history), shown: _shownForAi(), model: reading?.$1, nluState: reading?.$2 ?? 'idle', nluKind: reading?.$3 ?? 'none');
    // A newer message came while this one was being understood (a date
    // corrected, a new request): this late answer is old — nothing is done
    // with it, so it can never undo the newer one.
    if (_turn != turn) {
      Trace.log('understood', 'a late answer for an older message — ignored', {'text': t});
      return out.join(' ');
    }
    final cmds = _applyTopic(understood, t);
    thinking = false;
    if (problem != null) messages.add(ChatMessage.app(problem, info: true));

    Trace.log('understood', 'intent', {'text': t, 'commands': cmds.map(traceLine).join(' + '), 'ai': brain.aiOn});
    // The same reading in the NLU spec's names (for comparisons; no words).
    Trace.log('understood', 'spec', {'intents': intentsOfCommands(cmds).join(',')});
    nluShadow.oldReading(turn, intentsOfCommands(cmds));
    // A choice that belongs to something to keep ("আজই শুক্রবার, নাকি
    // আগামী?") waits its turn with the saves, so one question is open at a time.
    final saves = [for (final c in cmds) if (isSave(c) || (c is Clarify && cmds.length > 1 && c.options.every((o) => isSave(o.$2)))) c];
    final others = cmds.where((c) => !saves.contains(c)).toList();
    final secret = mentionsSecret(t) || cmds.any((c) => c is VaultQuery);
    _history.add(AiTurn.user(secret ? tr('[গোপন কিছু জানতে চাইলেন — ফোনেই উত্তর দেওয়া হলো]') : (shown ?? t)));
    // Remember an unfinished request (nothing to save came of it) so the
    // next short message can complete it.
    final finished = saves.isNotEmpty || others.any((c) => c is CallPerson || c is TaskDone || c is TaskEdit || c is TaskRestore || c is TaskQuery || c is ReminderSnooze || c is MenuAction || c is BulkAction);
    _lastSaid = secret || finished ? '' : t;
    _lastSaidAt = _now;
    final tags = <String>[];

    // The AI answered a question about the user's things in its own words:
    // say that, with the app's links (e.g. "রহিমের খাতা দেখুন").
    final aiAnswer = brain.aiShareData && others.whereType<AiReply>().isNotEmpty && others.any(answeredByAi);
    final aiLinks = aiAnswer ? [for (final c in others.where(answeredByAi)) ..._linksFor(c)] : const <ChatLink>[];
    final answered = <String>{};
    for (final c in others) {
      if (c is NotUnderstood && (saves.isNotEmpty || others.length > 1)) continue;
      if (aiAnswer && answeredByAi(c)) continue;
      if (aiAnswer && c is AiReply) {
        _say(out, c.text, links: aiLinks);
        tags.add(c.text);
        continue;
      }
      if (c is TaskDone || c is TaskEdit || c is TaskRestore || c is ReminderSnooze) {
        _onList = true;
        await _todo(c, out);
        tags.add('[কাজের তালিকায় বদল]');
        continue;
      }
      if (c is BulkAction) {
        // From the AI: the same resolver and executor as the rules' own.
        if (!await _bulkWith([c], t, out)) _say(out, tr('কোন তালিকার কথা বলছেন? আগে তালিকাটা দেখতে বলুন — যেমন “আজকের কাজ দাও”।'));
        tags.add('[${c.op}: একসাথে কয়েকটা]');
        continue;
      }
      if (c is MenuAction) {
        await _menu(c, out);
        tags.add('[${c.domain}: ${c.op}]');
        continue;
      }
      if (c is TaskQuery) _rememberShown(c);
      if (c is ReminderQuery) _rememberReminders(c);
      if (c is LedgerQuery) _rememberLedger(c);
      if (c is ProfileQuery) _rememberTopic(c);
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
        _rememberMoney(c);
        _answerMoney(c, out);
        tags.add(answerText(brain.data, c, _now) ?? '');
        continue;
      }
      if (c is CallPerson) {
        _startCall(c, out);
        tags.add('[ফোন/মেসেজের ব্যবস্থা করছে]');
        continue;
      }
      // "আমার যাকাত কত" with no price entered: today's market price is fetched first.
      if (c is ProfileQuery && infoTopic(normalize(c.transcript)) == 'zakat' && brain.zakatSaved.silverPrice <= 0) await brain.metalPriceToday();
      if (c is ProfileQuery && infoTopic(normalize(c.transcript)) == 'weather') await brain.refreshWeather();
      // "আজ কত হাঁটলাম?", "গত রাতে কত ঘুমিয়েছি?": the latest from Health Connect first (on the phone).
      if (c is HealthQuery && const {'steps', 'sleep', 'exercise'}.contains(c.what)) {
        await brain.syncHealthConnect(force: true).catchError((_) => 0);
        brain.noteStepsForAnswers();
      }
      if (medicalOff && c is HealthQuery && (c.what == HealthKind.bp.name || c.what == HealthKind.sugar.name)) {
        _say(out, medicalOffText());
        continue;
      }
      final text = (c is ProfileQuery ? _donorAnswer(c.transcript) : null) ?? answerText(brain.data, c, _now) ?? '';
      // Two parts of one message with the same answer ("এ বিষয়ে কোনো তথ্য
      // নেই" twice): said once.
      if (text.isNotEmpty && !answered.add(text)) continue;
      // A to-do answer shows every to-do it counted, so the screen and the
      // spoken count are the same list.
      final facts = c is TaskQuery && _shownTasks.length > 1 ? [for (final id in _shownTasks.take(30)) ..._maybe(id).map((t) => taskLine(t, _now))] : const <String>[];
      _say(out, text, vault: _vaultFor(c), links: _linksFor(c), facts: facts);
      if (c is LedgerQuery && c.ask == LedgerAsk.person && c.person != null) _focusOn(person: c.person!);
      if (c is CashQuery) {
        _focusOn(cash: true);
        // "বাড়ি মেরামতের হিসাব দেখাও": "এই কাজে …" next is about that account.
        final pr = (c.project != null ? projectByName(brain.data, c.project!) : null) ?? projectMeant(brain.data, c.transcript);
        if (pr != null) _focusProject = (pr.name, _now);
      }
      // Money answers are kept in the AI's view of the conversation so a
      // follow-up ("তাহলে সব মিলিয়ে কত?") makes sense; saved notes, tasks
      // and logins are not.
      final shareable = c is AiReply || c is SmallTalk || c is NotUnderstood || c is LedgerQuery || c is CashQuery;
      tags.add(shareable ? text : tr('[অ্যাপ নিজের রাখা তথ্য থেকে উত্তর দিল]'));
      if (c is SmallTalk && c.kind == Talk.whatCanYouDo) _say(out, capabilitiesList(), speak: false, links: [ChatLink(LinkKind.page, tr('কী কী করা যায় — বিস্তারিত'), page: 'help')]);
      if (c is SmallTalk && c.kind == Talk.bye) ended = true;
      // "তুমি ভুল বুঝেছো" right after a save: what was kept, and the ways to fix it.
      final justKept = _lastSave;
      if (c is SmallTalk && c.kind == Talk.sorry && justKept != null && _now.difference(justKept.$3).inMinutes <= 10 && (_accountWanted == null)) {
        out.removeLast();
        messages.removeLast();
        _say(out, trf('দুঃখিত। শেষে রেখেছি: {0}। কোনটা ভুল — নাম, তারিখ, না পুরোটাই? বলুন কী হবে, অথবা “ফিরিয়ে নাও” বললে ওটা সরিয়ে দেব।', [summaryLine(justKept.$1)]));
      }
      // A complaint right after an account was asked for: that offer again.
      final want = _accountWanted;
      if (c is SmallTalk && c.kind == Talk.sorry && want != null && _now.difference(want.$2).inMinutes <= 15 && projectByName(brain.data, want.$1) == null) {
        _ask(out, trf('আপনি ‘{0}’ নামে আলাদা হিসাব চেয়েছিলেন — অন্যান্য হিসাবে খুলে দিই?', [want.$1]), ChatWait.newAccount, choices: [ChatChoice(tr('হ্যাঁ, খুলে দাও'), 'হ্যাঁ'), ChatChoice(tr('না'), 'না')]);
      }
      // "আমি কথা বললে তুমি থেমে শুনবা": the setting itself is turned on.
      if (c is SmallTalk && c.kind == Talk.listenOverMe && !brain.bargeIn) await brain.setBargeIn(true);
    }
    if (saves.length == 1) {
      await _start(saves.single, out);
    } else if (saves.length > 1 && saves.every((c) => c is TaskAdd && c.title.trim().isNotEmpty)) {
      // Several to-dos in one breath: all kept, said back in one line.
      _queue
        ..clear()
        ..addAll(saves.skip(1));
      _allYes = true;
      _batchTaskTitles.clear();
      await _start(saves.first, out);
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
          'prayer' || 'sehri' || 'iftar' || 'sunrise' || 'sunset' || 'ramadan' => 'calendar',
          'howto' => howToAsked(text)?.id,
          'ability' => 'docs',
          'money' => 'accounts',
          'savings' => 'savings',
          'qibla' => 'compass',
          'spending' => 'spending',
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
    _waitAt = _now;
    this.choices = choices;
  }

  void _dropPending() {
    _todoWaiting = null;
    _pendingBulk = null;
    _planRest = null;
    _healthFix = null;
    _todoChoices = const [];
    if (wait == ChatWait.whichTask || wait == ChatWait.taskTime) {
      wait = ChatWait.none;
      choices = const [];
      return;
    }
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
    _batchLinks.clear();
    _batchKind = null;
  }

  // ── Working through the things to save ──

  Future<void> _start(Command c, List<String> out) async {
    _current = c;
    _chosen = false;
    _overWarned = false;
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
        _setEntry = entryToReach(brain.data.ledger, c.person, c.balance, _now)?.copyWith(note: c.note.isEmpty ? null : c.note);
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
      case Clarify():
        _current = null;
        _clarifyOptions = c.options;
        _ask(out, tr(c.question), ChatWait.clarify, choices: [for (final o in c.options) ChatChoice(tr(o.$1), o.$1)]);
      case TasksClear():
        final gone = _clearable(c);
        if (gone.isEmpty) {
          _current = null;
          _say(out, c.doneOnly ? tr('শেষ করা কোনো কাজ তালিকায় নেই।') : c.day == null ? tr('কাজের তালিকায় মোছার মতো কোনো কাজ নেই।') : trf('{0} কোনো কাজ নেই — কিছু মুছিনি।', [sayWhen(c.day!, _now, withTime: false)]));
          return;
        }
        final today = dayOnly(_now);
        final whose = c.day == null
            ? tr('কাজের তালিকার')
            : c.day == today
                ? tr('আজকের')
                : c.day == today.add(const Duration(days: 1))
                    ? tr('কালকের')
                    : trf('{0}-এর', [shortDate(c.day!)]);
        if (c.ids.length == 1) {
          _ask(out, trf('“{0}” কাজটি মুছে দেব?', [gone.single.title]), ChatWait.yesNo, choices: _yesNoChoices);
          return;
        }
        if (c.doneOnly) {
          _ask(out, trf('শেষ করা {0}টা কাজ তালিকা থেকে মুছে দেব? ৩০ দিন “মুছে ফেলা”-তে থাকবে।', [bnDigits(gone.length)]), ChatWait.yesNo,
              choices: _yesNoChoices, facts: [for (final t in gone.take(8)) t.title]);
          return;
        }
        _ask(out, trf('{0} সব — {1}টা কাজ মুছে দেবো?', [whose, bnDigits(gone.length)]), ChatWait.yesNo,
            choices: _yesNoChoices, facts: [for (final t in gone.take(8)) t.title]);
      case TaskAdd():
        if (c.title.trim().isEmpty) {
          // "কাজ লিখে রাখো", "কালকের কাজের তালিকায় লেখ": what to write is asked.
          _pendingTaskDue = c.due;
          _pendingTaskAdd = c;
          final day = c.due == null ? '' : ' (${sayWhen(c.due!, _now, withTime: false)})';
          _ask(out, trf('কোন কাজটি লিখে রাখব?{0}', [day]), ChatWait.taskTitle);
          return;
        }
        // "প্রতি মাসের ৩১ তারিখে": what a shorter month does is asked once.
        final rep = c.repeat;
        if (rep != null && rep.kind == 'monthly' && rep.monthDay >= 29 && !c.monthEndAsked && !_allYes) {
          _current = null;
          TaskAdd as(TaskRepeat r) => TaskAdd(c.transcript, title: c.title, due: r.nextOnOrAfter(_now), repeat: r, monthEndAsked: true);
          _clarifyOptions = [
            (tr('হ্যাঁ, মাসের শেষ দিনে'), as(TaskRepeat.monthly(rep.monthDay))),
            (tr('না, সে মাসে বাদ যাবে'), as(TaskRepeat.monthly(rep.monthDay, strict: true))),
          ];
          _ask(out, trf('যে মাসে {0} তারিখ নেই, সে মাসের শেষ দিনে রাখব?', [bnDigits(rep.monthDay)]), ChatWait.clarify, choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1)]);
          return;
        }
        // Already on the list: said so, not kept twice.
        final same = _sameTask(c);
        if (same != null) {
          _focusTask(same);
          _say(out, trf('“{0}” আগেই কাজের তালিকায় আছে{1}।', [same.title, same.due == null ? '' : ' (${_whenOf(same)})']), links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))], speak: !_allYes);
          await _done(out);
          return;
        }
        // "বাজার করা কাল করব" while "বাজার করা" is kept for another day: that
        // one moved, or a second one — asked (never a "বাজার করা করা").
        final moved = c.due != null && !_allYes && c.repeat == null ? _sameTitleOtherDay(c) : null;
        // "বাজার করা কাজটা ২৮ তারিখে করব": that one ("কাজটা"), moved.
        if (moved != null && RegExp(fold(r'(?:কাজটা|কাজটি|কাজটাকে)')).hasMatch(fold(normalize(c.transcript)))) {
          _current = null;
          await _todo(TaskEdit(c.transcript, ref: TaskRef(ids: [moved.id]), due: c.due, span: c.span), out);
          return;
        }
        if (moved != null) {
          _current = null;
          final when = sayWhen(c.due!, _now, withTime: false);
          _clarifyOptions = [
            (trf('{0} সরাও', [when]), TaskEdit(c.transcript, ref: TaskRef(ids: [moved.id]), due: c.due, span: c.span)),
            (tr('আরেকটা রাখো'), TaskAdd(c.transcript, title: moved.title, due: c.due, span: c.span)),
          ];
          _ask(out, trf('“{0}” তো {1} রাখা আছে — {2} সরাব, নাকি {2} আরেকটা রাখব?', [moved.title, _whenOf(moved), when]), ChatWait.clarify,
              choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1)]);
          return;
        }
        // A to-do is kept at once (ফিরিয়ে নিন takes it back) — no "রাখি?".
        return _saveCurrent(out);
      case ReminderAdd():
        // "সকালে মনে করিও" right after a to-do: that to-do's reminder.
        final bare = c.needsTitle || reminderWords(c.title).isEmpty;
        final focus = _focusTaskFresh && _focusTaskId != null ? _taskById(_focusTaskId!) : null;
        if (bare && focus != null && !c.alarm && c.repeat == Repeat.none) {
          _current = null;
          // "সকালে মনে করিও": the hour is asked, on the to-do's own day.
          final edit = c.needsTime || !saysClock(c.transcript)
              ? TaskEdit(c.transcript, ref: TaskRef(ids: [focus.id]), remindNeedsTime: true, due: RegExp(fold(r'(?:(?:^|\s)(?:আজ|আজকে|কাল|কালকে|পরশু)(?=\s|$)|\Sবার|তারিখ)')).hasMatch(fold(c.transcript)) ? (c.needsTime ? c.day : dayOnly(c.at)) : null, say: _partWord(c.transcript).isEmpty ? null : '{0} কয়টায় মনে করিয়ে দেব?')
              : TaskEdit(c.transcript, ref: TaskRef(ids: [focus.id]), remindAt: c.at, remindAmPm: ampmUnclear(c.transcript));
          await _todo(edit, out);
          return;
        }
        // Words that only said how or for whom: "যে …", "জন্য", "প্রতিমাসের".
        final cleaned = _reminderTitle(c.title, c.repeat);
        if (cleaned != c.title) {
          return _start(ReminderAdd(c.transcript, title: cleaned, at: c.at, repeat: c.repeat, alarm: c.alarm, weekdays: c.weekdays, minutesBefore: c.minutesBefore, day: c.day, part: c.part), out);
        }
        // "রেস্টুরেন্টে খেতে যাওয়ার রিমাইন্ডার দাও, রাত ৮টায়": an open to-do
        // by that name, with a day — its reminder, on its own day.
        // "পার্টির রিমাইন্ডার দাও সন্ধ্যা ৭টায়, আগের দিন": the day before the
        // to-do's own day — the to-do's day stays.
        final before = RegExp(fold(r'(?:^|\s)(?:আগের\s+দিন|এক\s+দিন\s+আগে|একদিন\s+আগে|১\s*দিন\s+আগে|আগের\s+রাতে)(?:ই)?(?=\s|$)'));
        final dayBefore = before.hasMatch(fold(normalize(c.transcript)));
        final title0 = dayBefore ? fold(normalize(c.title)).replaceAll(before, ' ').replaceAll(RegExp(r'\s+'), ' ').trim() : c.title;
        // "ওই কাজের আগের দিন মনে করিয়ে দিও": the to-do just shown or kept.
        final pointsBack = RegExp(fold(r'^(?:(?:ওই|এই|সেই|ঐ|ওটার|এটার|সেটার)\s*)?(?:কাজ(?:ের|টার|টির|টা|টি)?)?$')).hasMatch(title0.trim()) && title0.trim().isNotEmpty;
        final focused = pointsBack && _focusTaskFresh && _focusTaskId != null ? _taskById(_focusTaskId!) : null;
        final named = c.alarm || c.repeat != Repeat.none || c.needsTitle ? null : (focused ?? _openTaskNamed(title0));
        if (named != null && named.due != null && named.span == TaskSpan.day && dayBefore && c.needsTime) {
          // The day before its own day; the hour is asked. The to-do stays on its day.
          _current = null;
          final d = dayOnly(named.due!).subtract(const Duration(days: 1));
          await _todo(TaskEdit(c.transcript, ref: TaskRef(ids: [named.id]), remindNeedsTime: true, due: d), out);
          return;
        }
        if (named != null && named.due != null && named.span == TaskSpan.day && dayBefore && !c.needsTime) {
          _current = null;
          final d = dayOnly(named.due!).subtract(const Duration(days: 1));
          await _todo(TaskEdit(c.transcript, ref: TaskRef(ids: [named.id]), remindAt: DateTime(d.year, d.month, d.day, c.at.hour, c.at.minute), remindAmPm: ampmUnclear(c.transcript)), out);
          return;
        }
        if (named != null && named.due != null && named.span == TaskSpan.day && !(parseWhen(tidySpeech(c.transcript), _now)?.hasDay ?? false)) {
          _current = null;
          final edit = c.needsTime
              ? TaskEdit(c.transcript, ref: TaskRef(ids: [named.id]), remindNeedsTime: true)
              : TaskEdit(c.transcript, ref: TaskRef(ids: [named.id]), remindHour: c.at.hour, remindMinute: c.at.minute, remindAmPm: ampmUnclear(c.transcript));
          await _todo(edit, out);
          return;
        }
        _pendingTitle = c.title;
        _pendingRepeat = c.repeat;
        _pendingAlarm = c.alarm;
        _pendingDays = c.weekdays;
        _pendingBefore = c.minutesBefore;
        if (c.needsTime) {
          _pendingDay = c.day;
          _pendingPart = c.part;
          final what = c.needsTitle ? '' : '“${c.title}” — ';
          if (c.day != null && c.part != null) {
            // "কাল সকালে মনে করিও": only the hour is asked, in that part of the day.
            _ask(out, trf('{0}{1} {2} কয়টায় মনে করাব?', [what, sayWhen(c.day!, _now, withTime: false), tr(c.part!)]), ChatWait.reminderTime);
          } else if (c.day != null) {
            // "কাল মনে করিয়ে দিও": the day is known, only the hour is asked.
            _ask(out, trf('{0}{1} কয়টায় মনে করাব?', [what, sayWhen(c.day!, _now, withTime: false)]), ChatWait.reminderTime);
          } else {
            _ask(out, trf('{0}কখন মনে করাব? যেমন “আজ সন্ধ্যা ৭টায়”, “কাল সকাল ১০টায়” বা “এক ঘণ্টা পরে”।', [what]), ChatWait.reminderTime);
          }
          return;
        }
        // "চারটায়", "৬.২০-এ": morning or evening is asked — never decided
        // by the time it is now. (Asked before "it has passed", so a passed
        // morning reading is never the reason to pick the evening.)
        // Never skipped — not in a batch "সব রাখো", not for an alarm: an
        // open hour is not handed to the scheduler.
        if (c.ampmOpen) {
          final daySaid = c.day != null || (parseWhen(c.transcript, _now)?.hasDay ?? false);
          final r = ampmReadings(c.at, _now, daySaid: daySaid);
          ReminderAdd at(DateTime x) => ReminderAdd('${c.transcript} ${bnTime(x.hour, x.minute)}',
              title: c.title, at: x, repeat: c.repeat, alarm: c.alarm, weekdays: c.repeat == Repeat.weekly ? [x.weekday] : c.weekdays, minutesBefore: c.minutesBefore, ampmOpen: false);
          _current = null;
          _clarifyOptions = [for (final x in r) (bnTime(x.hour, x.minute), at(x))];
          _ask(out, trf('{0}, নাকি {1}?', [bnTime(r[0].hour, r[0].minute), bnTime(r[1].hour, r[1].minute)]), ChatWait.clarify,
              choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1)]);
          return;
        }
        if (!c.at.isAfter(_now)) {
          // "আজ সকাল ৮টায়" said after 8: never quietly moved to tomorrow.
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
        // Complete: set at once and said back with its time (ফিরিয়ে নিন undoes it).
        return _saveCurrent(out);
      case CashAdd():
        if (c.amount <= 0) {
          _ask(out, tr('কত টাকা?'), ChatWait.amount);
          return;
        }
        // "এই কাজে আরও ১৫০০০ টাকা পেয়েছি" right after that account was shown:
        // into it, not the monthly income.
        final fp = _focusProject;
        if (c.project == null && fp != null && _now.difference(fp.$2).inMinutes <= 20 && projectByName(brain.data, fp.$1) != null &&
            RegExp(fold(r'(?:^|\s)(?:এই|এ|ওই|সেই|ঐ)\s+(?:কাজে|কাজের|হিসাবে|হিসেবে|হিসাবের|প্রজেক্টে|প্রকল্পে|খাতে)|(?:^|\s)(?:এখানে|এতে|এটাতে|ওখানে|সেখানে)(?:\s|$)'))
                .hasMatch(fold(normalize('${[for (final m in messages.reversed) if (m.fromUser) m.text].firstOrNull ?? ''} ${c.transcript}')))) {
          return _start(CashAdd(c.transcript, kind: c.kind, amount: c.amount, category: c.category, project: fp.$1), out);
        }
        if (c.project != null && c.project!.trim().isEmpty) {
          // Which account (folder) is always asked; a new name opens a new one.
          final open = brain.data.projects.where((p) => !p.closed).toList();
          _ask(out, open.isEmpty ? tr('কোন নামে অন্যান্য হিসাব খুলে লিখব? নামটা বলুন।') : tr('অন্যান্য হিসাবের কোনটায় লিখব? বেছে নিন, বা নতুন নাম বলুন।'), ChatWait.project,
              choices: [for (final p in open.take(5)) ChatChoice(p.name, p.name)]);
          return;
        }
        // A new separate account is Pro: never written to the general
        // income-expense on its own — asked, and nothing is kept without a yes.
        if (c.project != null && projectByName(brain.data, c.project!) == null && !brain.canAddProject) {
          _current = CashAdd(c.transcript, kind: c.kind, amount: c.amount, category: c.category);
          _ask(out, trf('নতুন হিসাব “{0}” খোলা প্রিমিয়াম সুবিধা (ফ্রিতে ১টা অন্যান্য হিসাব), তাই ওখানে লিখতে পারছি না। {1} টাকা সাধারণ আয়-ব্যয়ে লিখব, নাকি এখন রাখব না?', [c.project!, bnNumber(c.amount)]), ChatWait.yesNo,
              choices: [ChatChoice(tr('সাধারণ আয়-ব্যয়ে লিখুন'), 'হ্যাঁ'), ChatChoice(tr('রাখবেন না'), 'না')]);
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
        // Already kept on another date ("১৫ নভেম্বর" from an earlier mishearing): that one moves.
        final same = _sameSpecial(c);
        if (same != null && (same.month != c.month || same.day != c.day)) {
          _ask(out, trf('{0} আগে রাখা আছে {1} — {2} তারিখে বদলে দিই? রিমাইন্ডারও সাথে সরে যাবে।', [what, '${bnDigits(same.day)} ${monthName(same.month)}', when]), ChatWait.yesNo,
              choices: _yesNoChoices);
          return;
        }
        _ask(out, c.hour == null
            ? trf('{0}, {1} — প্রতি বছর আগের দিন আর সেদিন সকালে মনে করিয়ে দেবো?', [what, when])
            : trf('{0}, {1} — প্রতি বছর আগের দিন আর সেদিন {2}-এ মনে করিয়ে দেবো?', [what, when, bnTime(c.hour!, c.minute)]), ChatWait.yesNo, choices: _yesNoChoices);
      default:
        await _done(out);
    }
  }

  /// "বকেয়া", "পাওনা", "বাকি আছে" said as what the money is.
  bool _saysDue(String t) => RegExp(fold(r'(?:বকেয়া|বাকি\s+আছে|বাকি\s+হিসাব|পাওনা\s+হিসাব|পাওনা|এরা\s+দেয়নি|দেয়নি)')).hasMatch(fold(normalize(t)));

  /// Money items read as income, re-read as what each one owes ("এটা আয়
  /// না, বকেয়া"): the person from each item's own words; the amount added
  /// to what they owe already; the account named on the note.
  List<Command> _asDues(List<Command> items, String said) {
    final p = projectHinted(brain.data, said) ?? [for (final c in items) if (c is CashAdd && c.project != null) projectByName(brain.data, c.project!)].nonNulls.firstOrNull;
    final note = p == null ? tr('বকেয়া') : '${tr('বকেয়া')} — ${p.name}';
    return [
      for (final c in items)
        if (c is CashAdd)
          () {
            final name = cashItem(c.transcript).isNotEmpty ? cashItem(c.transcript) : c.transcript.split(RegExp(r'\s+[০-৯0-9]')).first.trim();
            final known = balanceOf(brain.data.ledger, name)?.balance ?? 0;
            return LedgerSet(c.transcript, person: name, balance: known + c.amount, note: note, due: true);
          }()
        else
          c,
    ];
  }

  /// "বকেয়া হিসেবে এই গুলো রাখো" right after money items were refused:
  /// those, as dues — never a new note category.
  bool _refusedAsDues(String t, List<String> out) {
    final f = ' ${fold(normalize(t))} ';
    if (!_saysDue(t) || !RegExp(fold(r'(?<=\s)(?:এগুলো|এগুলা|ওগুলো|সেগুলো|এইগুলো|এসব|এই\s+গুলো|এটা|ওটা)(?=\s)')).hasMatch(f)) return false;
    final r = _refused;
    final cash = r == null || _now.difference(r.$2).inMinutes > 15 ? const <CashAdd>[] : r.$1.whereType<CashAdd>().toList();
    if (cash.isEmpty) {
      _say(out, tr('কোনগুলো বকেয়া হিসেবে রাখব? নাম আর টাকাসহ বলুন — যেমন “ফয়সাল ১০০০ টাকা বকেয়া”।'));
      return true;
    }
    _refused = null;
    _queue
      ..clear()
      ..addAll(_asDues(cash, t));
    _askingAll = true;
    _ask(out, trf('ঠিক আছে, এগুলো বকেয়া (তাঁরা দেবেন) হিসেবে রাখব — আয় হিসেবে নয়। রেখে দিই?', []), ChatWait.yesNo, choices: _yesNoChoices, facts: [for (final x in _queue) summaryLine(x)]);
    return true;
  }

  Future<bool> _refusedIntoProject(String t, List<String> out) async {
    final r = _refused;
    if (r == null || _now.difference(r.$2).inMinutes > 15) return false;
    final f = ' ${fold(normalize(t))} ';
    if (!RegExp(fold(r'(?<=\s)(?:এগুলো|এগুলা|ওগুলো|সেগুলো|এটা|ওটা|সেটা|এইগুলো|এসব)(?:ও|কে)?(?=\s)')).hasMatch(f)) return false;
    if (!RegExp(fold(r'(?:রাখ|লিখ|লেখ|যুক্ত|যোগ|তোল)')).hasMatch(f)) return false;
    final cash = r.$1.whereType<CashAdd>().toList();
    if (cash.isEmpty) return false;
    final p = projectMeant(brain.data, t);
    var name = p?.name;
    if (name == null) {
      // "অন্যান্য হিসাবে <X> সংক্রান্ত/নামে বিভাগ খুলে": a new account named X.
      final m = RegExp(fold(r'(?:অন্যান্য|আলাদা)\s+হিস(?:া|ে)ব\S*\s+(.+?)\s+(?:সংক্রান্ত|নামে|নামের)?\s*(?:বিভাগ|হিসাব|প্রজেক্ট|ফোল্ডার)')).firstMatch(fold(normalize(t)));
      name = m == null ? null : m[1]!.trim();
    }
    if (name == null || name.isEmpty) return false;
    _refused = null;
    final again = [
      for (final c in r.$1)
        c is CashAdd ? CashAdd(c.transcript, kind: c.kind, amount: c.amount, category: c.category, project: name) : c,
    ];
    _queue
      ..clear()
      ..addAll(again);
    if (again.length == 1) {
      await _start(_queue.removeAt(0), out);
      return true;
    }
    _askingAll = true;
    _ask(out, trf('ঠিক আছে — ‘{0}’ হিসাবে। এভাবে রেখে দিই?', [name]), ChatWait.yesNo, choices: _yesNoChoices, facts: [for (final c in again) summaryLine(c)]);
    return true;
  }

  /// The one open to-do [title] names ("…যাওয়ার" is "…যাওয়া"), or null.
  Task? _openTaskNamed(String title) {
    // "নোয়াখালী যাওয়া কাজের", "নোয়াখালী যাওয়ার": the to-do's own name.
    // "ব্যাংকে যাওয়ার কথা", "ব্যাংকের কাজে": the words around the name too.
    String key(String x) => fold(normalize(x)).replaceAll(RegExp(fold(r'(?:\s+(?:কাজ|কাজের|কাজে|কাজটির|কাজটার|কাজটা|কাজটি|কথা|কথাটা|বিষয়টা|ব্যাপারটা))+$')), '').replaceAll(RegExp(fold(r'(?:য়ের|ের|এর|র)$')), '').trim();
    final k = key(title);
    if (k.length < 3) return null;
    final hits = [for (final t in brain.data.tasks) if (!t.done && key(t.title) == k) t];
    if (hits.length == 1) return hits.single;
    if (hits.isNotEmpty) return null;
    // "ব্যাংক এর কাজ" for "ব্যাংকে যাওয়া": its own (not generic) words, one to-do only.
    final near = tdMatch(brain.data.tasks, [for (final w in words(normalize(k))) stem(w)]);
    return near.length == 1 ? near.single : null;
  }

  /// A special day already kept for the same person and kind.
  SpecialDay? _sameSpecial(SpecialAdd c) {
    final title = normalize(specialTitle(SpecialDay(person: c.person, kind: c.kind, month: c.month, day: c.day)));
    return brain.data.specialDays
        .where((x) => x.kind == c.kind && (normalize(x.person) == normalize(c.person) || normalize(specialTitle(x)) == title || normalize(x.person) == title))
        .firstOrNull;
  }

  /// "নিজের খরচ": a money sentence with no one owing becomes spending.
  Future<void> _asOwnSpending(List<String> out) async {
    final src = _src!;
    final amount = _amount > 0 ? _amount : src.amount;
    await _start(CashAdd(src.transcript, kind: CashKind.expense, amount: amount, category: categoryFor(normalize(src.transcript), CashKind.expense)), out);
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
        // The same name twice is told apart by the end of the number; the
        // count said is the count named.
        final counts = <String, int>{};
        for (final x in many) {
          counts[normalize(x.name)] = (counts[normalize(x.name)] ?? 0) + 1;
        }
        // Everyone counted is in one list: the first few named, then "আরও N জন" once.
        final names = [
          for (final x in many)
            (counts[normalize(x.name)] ?? 0) > 1 ? '${x.name} (…${bnDigits(phoneKey(x.phone).length > 4 ? phoneKey(x.phone).substring(phoneKey(x.phone).length - 4) : phoneKey(x.phone))})' : x.name,
        ];
        _ask(
          out,
          trf('“{0}” নামে {1} জন আছেন — {2}{3}। কাকে {4}?', [
            _callee,
            bnDigits(many.length),
            nameList(names, unit: 'জন'),
            '',
            c.via == Via.call ? 'ফোন দেব' : 'পাঠাব',
          ]),
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
    final n = normalize(said.replaceAll('নাম্বার', 'নম্বর').replaceAll('নং', 'নম্বর'));
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
    // "খালিদকে সব টাকা দিয়ে দিছি", "পুরো টাকা ফেরত দিল" (owner, 29 Oct): the
    // whole of what is owed, either way — still asked as a yes/no.
    if (_amount <= 0 && RegExp(fold(r'(?:^|\s)(?:সব|সবটা|সমস্ত|পুরো|পুরা|পুরোটা|বাকি|বাকিটা|যত)\s*(?:টাকা|টাকাই|দেনা|পাওনা|ধার)?(?:\s|$)')).hasMatch(fold(normalize(src.transcript)))) {
      final bal = balanceWith(brain.data.ledger, _person, phone: _ledgerPhone);
      if (bal != 0) {
        _amount = bal.abs();
        final opts = src.options.isEmpty ? LedgerKind.values : src.options;
        if (_kind == null || _kind == LedgerKind.lent || _kind == LedgerKind.borrowed) {
          if (bal < 0 && opts.contains(LedgerKind.repaid)) _kind = LedgerKind.repaid;
          if (bal > 0 && opts.contains(LedgerKind.received)) _kind = LedgerKind.received;
        }
      }
    }
    if (_amount <= 0) {
      _ask(out, trf('{0} নিয়ে কত টাকার কথা? অঙ্কটা বলেন।', [toPerson(_person)]), ChatWait.amount);
      return;
    }
    if (!_phoneChecked) {
      _phoneChecked = true;
      // Whose number? First the people already in the book with this name,
      // then যোগাযোগ. One fits: use it. Several: ask which.
      // Two in the book called "শফিক" (with or without a number): which one
      // is asked — money never goes to the first match.
      var inBook = peopleNamed(brain.data.ledger, _person).toList();
      // "শফিক" said, the book has "শফিক আহমেদ" and "শফিক হাসান": both offered.
      if (inBook.isEmpty && !_person.trim().contains(' ')) {
        final byFirst = [for (final p in balances(brain.data.ledger)) if (p.name.trim().contains(' ') && personKey(p.name.trim().split(' ').first) == personKey(_person)) p];
        if (byFirst.length >= 2) inBook = byFirst;
      }
      final options = inBook.isNotEmpty
          ? [for (final p in inBook) (p.name, p.phone)]
          : [for (final c in contactMatches(brain.data, _person).where((c) => c.phone.isNotEmpty)) (c.name, c.phone)];
      // "ইমরান নাঈম ১৫০০০ টাকা…": the whole name said fits one of them.
      final said = normalize(src.transcript);
      final whole = options.where((o) => normalize(o.$1).contains(' ') && said.contains(normalize(o.$1))).toList();
      if (options.length == 1) {
        _ledgerPhone = options.single.$2;
      } else if (whole.length == 1) {
        _person = whole.single.$1;
        _ledgerPhone = whole.single.$2;
      } else if (options.length > 1) {
        _personChoices = options.take(6).toList();
        _ask(
          out,
          trf('“{0}” নামে {1} জন আছেন। কার সাথে লেনদেন?', [_person, bnDigits(options.length)]),
          ChatWait.whichPerson,
          choices: [
            for (final o in _personChoices) ChatChoice(o.$2.isEmpty ? o.$1 : '${o.$1} · ${showPhone(o.$2)}', o.$2.isEmpty ? o.$1 : '${o.$1} ${o.$2}'),
            ChatChoice(tr('নতুন মানুষ'), 'নতুন মানুষ'),
          ],
        );
        return;
      }
    }
    if (_kind == null && _allYes && _batchKind != null && (src.options.isEmpty || src.options.contains(_batchKind))) {
      // "তুবাকে ৫০০ দিলাম। ফারুককে ১০ হাজার।": one verb for all — answered once.
      _kind = _batchKind;
      _chosen = true;
    }
    // "খালিদকে ৫০০ দিলাম" while the member owes খালিদ: paying it back (owner,
    // 29 Oct) — still asked as a yes/no, never saved unasked. The same for
    // money from someone who owes the member.
    if (_kind == null && _person.isNotEmpty && _amount > 0) {
      final opts = src.options.isEmpty ? LedgerKind.values : src.options;
      final bal = balanceWith(brain.data.ledger, _person, phone: _ledgerPhone);
      if (opts.contains(LedgerKind.repaid) && bal < 0 && _amount <= -bal) _kind = LedgerKind.repaid;
      if (opts.contains(LedgerKind.received) && !opts.contains(LedgerKind.repaid) && bal > 0 && _amount <= bal) _kind = LedgerKind.received;
    }
    if (_kind == null) {
      final opts = src.options.isEmpty ? LedgerKind.values : src.options;
      _ask(out, _clarifyQuestion(opts, src.allowExpense), ChatWait.kind, choices: [
        for (final k in opts) ChatChoice(k.label, k.label),
        if (src.allowExpense) ChatChoice(tr('অন্য খরচ'), 'অন্য খরচ'),
      ]);
      return;
    }
    // "ফেরত পেলাম" / "শোধ করলাম" for more than was owed would turn the
    // account around (a debt nobody had) — said plainly and asked once.
    if (!_overWarned && !_allYes && (_kind == LedgerKind.received || _kind == LedgerKind.repaid)) {
      final bal = balanceWith(brain.data.ledger, _person, phone: _ledgerPhone);
      final owed = _kind == LedgerKind.received ? (bal > 0 ? bal : 0) : (bal < 0 ? -bal : 0);
      if (_amount > owed) {
        _overWarned = true;
        _overKind = _kind;
        final was = owed == 0
            ? (_kind == LedgerKind.repaid ? tr('আপনার কোনো দেনা ছিল না') : tr('আগে কোনো পাওনা ছিল না'))
            : (_kind == LedgerKind.repaid ? trf('দেনা ছিল {0} টাকা', [bnNumber(owed)]) : trf('পাওনা ছিল {0} টাকা', [bnNumber(owed)]));
        _kind = null;
        _ask(out, trf('{0} কাছে {1} — তাই {2} টাকা “ফেরত” লিখলে হিসাব উল্টে যাবে। আসলে কী হলো?', [possessive(_person), was, bnNumber(_amount)]), ChatWait.kind, choices: [
          ChatChoice(LedgerKind.borrowed.label, LedgerKind.borrowed.label),
          ChatChoice(LedgerKind.lent.label, LedgerKind.lent.label),
          ChatChoice(LedgerKind.received.label, LedgerKind.received.label),
        ]);
        return;
      }
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
    if (o.contains(LedgerKind.received) && o.contains(LedgerKind.borrowed) && !o.contains(LedgerKind.repaid)) {
      if (_person.isNotEmpty) return trf('একটু বুঝিয়ে বলেন — {0} কি আগের টাকা ফেরত দিলেন, নাকি আপনি নতুন করে ধার নিলেন?', [_person]);
      return tr('একটু বুঝিয়ে বলেন — উনি কি আগের টাকা ফেরত দিলেন, নাকি আপনি নতুন করে ধার নিলেন?');
    }
    return tr('একটু বুঝিয়ে বলেন — এটা কোন ধরনের লেনদেন?');
  }

  /// A long new sentence instead of an answer.
  /// Something new rather than an answer: a longer sentence, or a question
  /// of its own ("রোজা কবে?").
  /// How many words of [t] say something besides when (and the small words
  /// of an answer: "টায়", "মনে করিও", "ঠিক আছে").
  int _beyondWhen(String t) {
    const small = ['টায়', 'টা', 'টাতে', 'এ', 'তে', 'দাও', 'দিও', 'মনে', 'করিও', 'করিয়ে', 'করিয়ে', 'দিবে', 'দেবে', 'হবে', 'ঠিক', 'আছে', 'হ্যাঁ', 'হ্যা', 'না', 'জি', 'আচ্ছা', 'ওকে', 'বাজে', 'বাজিয়ো', 'বাজাও', 'সময়', 'সময়ে', 'ভাই', 'প্লিজ', 'রাখো', 'করো', 'দিন', 'মিনিট', 'ঘণ্টা', 'পরে', 'আগে', 'বরং', 'নয়', 'নয়'];
    final rest = words(normalize(withoutWhen(withoutClockWords(t))));
    final skip = {for (final w in small) normalize(w)};
    return rest.where((w) => !skip.contains(w) && !RegExp(r'^[0-9০-৯.:]+$').hasMatch(w)).length;
  }

  /// "আবার কবে রক্ত দিতে পারব?": three months after the last time kept.
  String? _donorAnswer(String said) {
    final f = fold(normalize(said));
    if (!RegExp(fold(r'কবে.*(?:রক্ত|ব্লাড)\s+(?:দিতে|দেওয়া|দেয়া)|(?:রক্ত|ব্লাড)\s+(?:দিতে|দেওয়া|দেয়া)\s+(?:পারব|পারবো|যাবে|পারি).*কবে|আবার\s+কবে\s+(?:রক্ত|ব্লাড)')).hasMatch(f)) return null;
    final last = DateTime.tryParse(brain.text('blood_last'));
    if (last == null) return tr('শেষ কবে রক্ত দিয়েছেন জানা নেই। বলুন, যেমন “শেষ রক্ত দিয়েছি ১০ আগস্ট” — তিন মাস পরের দিনটা বলে দেবো।');
    final next = DateTime(last.year, last.month + 3, last.day);
    final today = dayOnly(_now);
    return next.isAfter(today)
        ? trf('শেষ দিয়েছেন {0}। আবার দিতে পারবেন {1} থেকে ({2})।', [fullDate(last), fullDate(next), daysLeftLabel(next, _now)])
        : trf('শেষ দিয়েছেন {0} — তিন মাস পেরিয়েছে, এখন দিতে পারবেন।', [fullDate(last)]);
  }

  bool _otherMoneyEvent(String t, LedgerAdd src) {
    final n = normalize(t);
    final amount = findAmount(n);
    if (amount == null || words(n).length < 3) return false;
    if (amount != src.amount) return true;
    final c = parseAll(t, brain.data.ledger, tasks: brain.data.tasks, now: _now, data: brain.data);
    return c.length == 1 && c.single is LedgerAdd && (c.single as LedgerAdd).person.trim().isNotEmpty && personKey((c.single as LedgerAdd).person) != personKey(src.person);
  }

  bool _looksNew(String t) {
    final n = words(normalize(t)).length;
    return n >= 4 || (n >= 2 && isQuestionText(t) && yesNo(t) == null) || infoTopic(normalize(t)) != null || (n >= 2 && (_asksOwnData(t) || _opensPage(t)));
  }

  /// "রিমাইন্ডার খোলো", "জরুরি কার্ড খোলো": a page asked for — never the
  /// answer to a waiting question.
  bool _opensPage(String t) {
    final cmds = parseAll(t, brain.data.ledger, tasks: brain.data.tasks, now: _now, data: brain.data);
    return cmds.length == 1 && cmds.single is OpenPlace;
  }

  /// "আজকের খরচ দাও", "কাজের তালিকা দাও": a question about the app's own
  /// records — never a name or an answer to what was asked before.
  bool _asksOwnData(String t) {
    final cmds = parseAll(t, brain.data.ledger, tasks: brain.data.tasks, now: _now, data: brain.data);
    return cmds.length == 1 && (cmds.single is CashQuery || cmds.single is LedgerQuery || cmds.single is ReminderQuery || cmds.single is TaskQuery || cmds.single is Briefing || cmds.single is MoneyListQuery || cmds.single is HealthQuery || (cmds.single is MenuAction && (const {'list', 'show', 'read', 'today', 'total', 'report'}.contains((cmds.single as MenuAction).op) || ((cmds.single as MenuAction).domain == 'cash' && const {'spend', 'income', 'net'}.contains((cmds.single as MenuAction).op)))));
  }

  String _reminderTitle(String title, Repeat repeat) {
    // "বিল দিতে মনে করিও" → "বিল দেওয়া".
    final words0 = reminderWords(title);
    var t = (words0.isEmpty ? title : words0).trim();
    t = t.replaceFirst(RegExp(fold(r'^(?:যে|জন্য|জন্যে|আমার\s+জন্য)\s+')), '');
    if (repeat != Repeat.none) t = t.replaceAll(RegExp(fold(r'(?:^|\s)(?:প্রতিমাসের|প্রতি\s+মাসের|প্রতিমাসে|প্রতি\s+মাসে|প্রতিদিনের|প্রতি\s+সপ্তাহের)(?=\s|$)')), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t == 'জন্য' || t == 'জন্যে') return '';
    return t;
  }

  /// Handles [t] as the answer to the waiting question. False when it is
  /// not an answer but something new.
  Future<bool> _answer(String t, List<String> out) async {
    // "বাদ দাও", "থাক", "বাতিল": the question and what it was for are dropped.
    // …except when the question was "মুছে দেবো?": then "বাদ দাও" is the yes.
    final deleting = (wait == ChatWait.yesNo && _current is ManageItem && (_current as ManageItem).action == 'delete') || (wait == ChatWait.bulk && _pendingBulk?.action.op == 'delete');
    if (wait != ChatWait.none && isCancel(t) && !(deleting && deleteSaid(t))) {
      _pendingBulk = null;
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
      case ChatWait.bulk:
        return _bulkAnswer(t, out);
      case ChatWait.batchTime:
        return _batchTimeAnswer(t, out);
      case ChatWait.taskDate:
        // "মে মাসের কত তারিখে মনে করাব?" → "১০ তারিখে": that day of the to-dos' own month.
        final span = _spanRemind;
        if (span != null) {
          final d = RegExp(r'^\s*([0-9০-৯]{1,2})').firstMatch(asciiDigits(tidySpeech(t)));
          final w0 = parseWhen(tidySpeech(t), _now);
          final first = span.$3;
          DateTime? day;
          final monthSaid = RegExp(fold('(?:${bnMonths.join('|')})')).hasMatch(fold(t));
          if (d != null && !monthSaid) {
            final n = int.parse(d[1]!);
            final c = DateTime(first.year, first.month, n);
            if (c.month == first.month) day = c;
          } else if (w0 != null && w0.hasDay) {
            day = dayOnly(w0.day);
          }
          if (day == null) {
            if (_looksNew(t)) return false;
            _say(out, trf('কোন তারিখ? যেমন “১০ তারিখে” ({0})।', [monthName(first.month)]));
            return true;
          }
          wait = ChatWait.none;
          _spanRemind = null;
          await _remindTasksOn(span.$1, span.$2, day, out);
          return true;
        }
        final w = parseWhen(tidySpeech(t), _now);
        final task = _dateTaskId == null ? null : _taskById(_dateTaskId!);
        if (task == null) return false;
        if (w == null || !w.hasDay) {
          if (_looksNew(t)) return false;
          _say(out, tr('তারিখটা ধরতে পারিনি। যেমন বলুন “৩১ অক্টোবর” বা “শুক্রবার”।'));
          return true;
        }
        wait = ChatWait.none;
        _dateTaskId = null;
        await _setTaskDay(task, dayOnly(w.day), out);
        return true;
      case ChatWait.whichTask:
      case ChatWait.taskTime:
        return _todoAnswer(t, out);
      case ChatWait.clarify:
        final i = _pickOption(t);
        if (i == null) {
          // "ভোর ৪টা, নাকি বিকেল ৪টা?" — "না, চারটায় নয়, পাঁচটায়": the same
          // reminder, at the new hour (asked again only if that is open too).
          final first = _clarifyOptions.isEmpty ? null : _clarifyOptions.first.$2;
          if (first is ReminderAdd && _clarifyOptions.every((o) => o.$2 is ReminderAdd)) {
            final f = ' ${fold(t).replaceAll(RegExp(r'[।,!?]'), ' ')} ';
            final last = f.replaceFirst(RegExp(fold(r'^\s*(?:না|নাহ|উহু|না\s+না)\s')), ' ').split(RegExp(fold(r'\s(?:নয়|না)\s'))).last.trim();
            final w = parseWhen(last, _now);
            if (w != null && w.hasTime) {
              final daySaid = w.hasDay || (parseWhen(first.transcript, _now)?.hasDay ?? false);
              final d = w.hasDay ? w.day : dayOnly(first.at);
              wait = ChatWait.none;
              choices = const [];
              _clarifyOptions = const [];
              await _start(
                  ReminderAdd(last,
                      title: first.title,
                      at: DateTime(d.year, d.month, d.day, w.at.hour, w.at.minute),
                      repeat: first.repeat,
                      alarm: first.alarm,
                      weekdays: first.weekdays,
                      minutesBefore: first.minutesBefore,
                      day: daySaid ? d : null),
                  out);
              return true;
            }
          }
          if (_looksNew(t)) return false;
          _say(out, tr('কোনটা, ধরতে পারিনি — নিচ থেকে একটা বেছে নিন।'));
          return true;
        }
        final pick = _clarifyOptions[i].$2;
        wait = ChatWait.none;
        choices = const [];
        _clarifyOptions = const [];
        Trace.log('understood', 'choice made', {'picked': traceLine(pick)});
        if (isSave(pick)) {
          await _start(pick, out);
        } else if (pick is TaskDone || pick is TaskEdit || pick is TaskRestore || pick is ReminderSnooze) {
          await _todo(pick, out);
        } else if (pick is MenuAction) {
          await _menu(pick, out);
        } else if (pick is BulkAction) {
          _onList = true;
          final set = _clarifySet;
          _clarifySet = null;
          if (set != null) {
            final (ids, why) = _resolve(pick.selection, set);
            if (why != null) {
              _say(out, why);
            } else {
              // The scope is now said: never the same question again.
              final whole = ResultSet(domain: set.domain, label: set.label, ids: set.ids, matching: set.ids.length, shown: set.ids.length, source: set.source, at: set.at, turn: _turn);
              await _bulkStart(pick, whole, ids, out);
            }
          }
        } else if (pick is ManageItem) {
          final tg = _clarifyTarget;
          _clarifyTarget = null;
          _current = pick;
          if (tg != null) await _confirmManage(tg, out);
        } else if (pick is MoneyListQuery) {
          _answerMoney(pick, out);
        } else {
          final text = answerText(brain.data, pick, _now) ?? '';
          _say(out, text, links: _linksFor(pick));
          if (pick is CashQuery) _focusOn(cash: true);
        }
        return true;
      case ChatWait.changeTo:
        // "সন্ধ্যা ৭টায়" after "নতুন সময় কত?": that one changed now.
        final target = _target;
        final ch = target == null ? const Change() : changeIn(target, t, _now);
        if (target == null || ch.isEmpty) {
          if (_looksNew(t)) return false;
          _say(out, target?.kind == ItemKind.task ? tr('তারিখটা ধরতে পারিনি — যেমন বলুন “২৮ অক্টোবর”।') : tr('সময়টা ধরতে পারিনি — যেমন বলুন “সন্ধ্যা ৭টায়”।'));
          return true;
        }
        wait = ChatWait.none;
        choices = const [];
        _current = null;
        await brain.applyChange(target, ch);
        _say(out, trf('বদলে দিলাম — {0}: {1}।', [target.text, ch.at != null && target.kind == ItemKind.reminder ? sayWhen(ch.at!, _now) : sayWhen(ch.day ?? ch.at!, _now, withTime: false)]));
        _target = null;
        _change = const Change();
        return true;
      case ChatWait.whichItem:
        // "সব" / "দুটোই": every one listed. One kind → one confirmation
        // for the group; mixed kinds are not removed together.
        if (RegExp(fold(r'(?:^|\s)(?:সব|সবগুলো|সবগুলা|সবকটা|সবকটাকে|যতগুলো|দুটোই|দুইটাই|দুটাই|সবই|সব\s+গুলো|সবগুলোই|তিনটাই|সবকয়টা)(?:\s|$|[।?!,])')).hasMatch(fold(t))) {
          return _whichAll(out);
        }
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
          // The one chosen, by its full name ("শফিক হাসান", not "শফিক").
          _person = _personChoices[i].$1;
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
        // A question about what is kept ("কাজের তালিকা দাও"), a complaint or
        // "কি করতেছো?" in the middle: never an item. Dictation pauses (the
        // lines so far are kept aside, unsaved) and the message is answered.
        if (confusedOrHelp(t)) {
          _pauseCollect(out, why: tr('এখন আপনার বলা কাজগুলো একটা একটা করে লিখছিলাম।'));
          return true;
        }
        if (taskListAsked(t) || _asksOwnData(t) || aboutTheAssistant(t) == AboutMe.complaint || complainsWrong(t) || (isQuestionText(t) && _collected.isEmpty)) {
          _pauseCollect(out);
          return false;
        }
        _collected.add(t);
        messages.add(ChatMessage.app('${bnDigits(_collected.length)}. $t', info: true));
        return true;
      case ChatWait.yesNo:
        // "তুমি কি আমার কথা শুনতেছো না, এটা রাইখো না": "keep it, will you" —
        // a yes said in annoyance, never a no (owner's video, 25 Oct).
        if (notListening(t) && keepThat(t)) t = 'হ্যাঁ';
        // "মুছে দেবো?" → "বাদ দাও আবার কি চিন্তা করতেছো": the same removal
        // asked again is a yes (owner's video, 25 Oct), never a no.
        final asked = _current;
        if (asked is ManageItem && asked.action == 'delete' && deleteSaid(t)) t = 'হ্যাঁ';
        if (asked is ManageItem && _target != null && yesNo(t) == false) _refusedManage = (asked, _target!, _now);
        // "না, রেখো না": a plain no — checked first, so "রেখো" is never
        // taken as a corrected name or kind.
        final refused = refusesSave(t) || notWhatISaid(t);
        // "সব কাজ মুছে দেবো?" → "শুধু ২০২৯ সালের": the same removal, narrowed
        // to that stretch of time and asked again.
        final clearing = _current;
        final narrowTo = clearing is TasksClear && clearing.ids.isEmpty && !clearing.doneOnly ? periodSaid(tidySpeech(t), _now) : null;
        if (narrowTo != null) {
          _current = null;
          wait = ChatWait.none;
          choices = const [];
          await _periodRemove('tasks', 'delete', narrowTo, t, out);
          return true;
        }
        // "হ্যাঁ তুলে রাখ, তবে এরাম শব্দটা বাদ দিও": that word out, then as asked.
        final drop = RegExp(fold(r'(\S+)\s+(?:শব্দটা|শব্দটি|কথাটা|শব্দ)\s+(?:বাদ|কেটে|মুছে)')).firstMatch(fold(t));
        final curW = _current;
        if (!refused && !_askingAll && drop != null && (curW is TaskAdd || curW is ReminderAdd)) {
          final word = drop[1]!;
          String cut(String s) => fold(s).replaceAll(RegExp('(?:^|\\s)${RegExp.escape(word)}(?=\\s|\$)'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
          final next = curW is TaskAdd
              ? TaskAdd(curW.transcript, title: cut(curW.title), due: curW.due)
              : ReminderAdd((curW as ReminderAdd).transcript, title: cut(curW.title), at: curW.at, repeat: curW.repeat, alarm: curW.alarm, weekdays: curW.weekdays, minutesBefore: curW.minutesBefore, day: curW.day);
          wait = ChatWait.none;
          choices = const [];
          Trace.log('understood', 'a word taken out of the waiting item', const {});
          _current = next;
          if (yesNo(t.substring(0, t.length)) == true || RegExp(fold(r'(?:^|\s)(?:রাখ|রাখো|তুলে রাখ|হ্যাঁ)(?:\s|$)')).hasMatch(fold(t))) {
            await _saveCurrent(out);
          } else {
            await _start(next, out);
          }
          return true;
        }
        // "সব যথাযথ হয় নাই। নাহিয়ানের বেতন অন্যান্য হিসাবের … শিক্ষার্থীদের
        // বেতনে যুক্ত কর": one item of the list waiting, changed; asked again.
        // "এটা আয় না। এটা বকেয়া হিসাব": the same items, as what each one
        // owes — never a "no" that drops them all.
        if (_saysDue(t) && ((_askingAll && _queue.whereType<CashAdd>().isNotEmpty) || (!_askingAll && _current is CashAdd))) {
          final items = _askingAll ? List<Command>.of(_queue) : <Command>[_current!];
          _queue
            ..clear()
            ..addAll(_asDues(items, t));
          _current = null;
          _askingAll = true;
          _ask(out, tr('ঠিক আছে, আয় নয় — বকেয়া (তাঁরা দেবেন)। এভাবে রেখে দিই?'), ChatWait.yesNo, choices: _yesNoChoices, facts: [for (final x in _queue) summaryLine(x)]);
          return true;
        }
        if (_askingAll && _editQueued(t, out)) return true;
        // "এইগুলো ওই বেতনের হিসাবে রাখো" while money items wait: all of
        // them into that account — shown again, then kept on a yes.
        final into = _askingAll && _queue.whereType<CashAdd>().isNotEmpty && !refused ? projectHinted(brain.data, t) : null;
        if (into != null && _queue.whereType<CashAdd>().any((c) => c.project != into.name)) {
          for (var i = 0; i < _queue.length; i++) {
            final c = _queue[i];
            if (c is CashAdd) _queue[i] = CashAdd(c.transcript, kind: c.kind, amount: c.amount, category: c.category, project: into.name);
          }
          _ask(out, trf('ঠিক আছে, এগুলো ‘{0}’ হিসাবে রাখব। এভাবে রেখে দিই?', [into.name]), ChatWait.yesNo, choices: _yesNoChoices, facts: [for (final x in _queue) summaryLine(x)]);
          return true;
        }
        // "খরচ মাত্র ১৫০ টাকা?" about the list waiting: what the list holds, still waiting.
        if (_askingAll && isQuestionText(t) && RegExp(fold(r'(?:খরচ|আয়|টাকা|মোট)')).hasMatch(fold(t)) && yesNo(t) == null) {
          final spent = _queue.whereType<CashAdd>().where((c) => c.kind == CashKind.expense).fold<int>(0, (a, c) => a + c.amount);
          final got = _queue.whereType<CashAdd>().where((c) => c.kind == CashKind.income).fold<int>(0, (a, c) => a + c.amount);
          _say(out, trf('এই তালিকায় মোট খরচ {0} টাকা{1} — নিচে আলাদা করে দিলাম। রেখে দিই? কোনোটা ভুল হলে বলুন, বদলে দেব।', [bnNumber(spent), got > 0 ? trf(', আয় {0} টাকা', [bnNumber(got)]) : '']),
              facts: [for (final x in _queue) summaryLine(x)]);
          choices = _yesNoChoices;
          return true;
        }
        // "হ্যাঁ, কিন্তু শুধু লিখবা ওয়াইফাই বিল দিতে হবে": same item, fewer words.
        final shorter = refused || _askingAll ? null : onlyWrite(t);
        if (shorter != null && (_current is TaskAdd || _current is ReminderAdd)) {
          final cur0 = _current;
          wait = ChatWait.none;
          choices = const [];
          Trace.log('understood', 'only the words of the waiting item changed', const {});
          if (cur0 is TaskAdd) {
            await _start(TaskAdd(cur0.transcript, title: shorter, due: cur0.due), out);
          } else if (cur0 is ReminderAdd) {
            await _start(ReminderAdd(cur0.transcript, title: shorter, at: cur0.at, repeat: cur0.repeat, alarm: cur0.alarm, weekdays: cur0.weekdays, minutesBefore: cur0.minutesBefore, day: cur0.day), out);
          }
          return true;
        }
        // "না, সাতশ" / "পাঁচশ না, সাতশ": not a no — the amount corrected; ask again.
        final cur = _current;
        // "পেয়াজ ৩০০ টাকা, ৩ না": the old amount said "না" to — a fix, not a no.
        final swapped = _amountSwap(t) ?? (cur == null ? null : _restatedAmount(t, cur));
        final fixed = swapped ?? _correctedAmount(t);
        if ((!refused || swapped != null) && fixed != null && !_askingAll && (cur is LedgerAdd || cur is CashAdd)) {
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
        // "এখনো ঠিক করতে পারো নাই", "দাম ভুল" about one money item waiting:
        // never a yes and never a drop — the right amount is asked.
        if (!_askingAll && (cur is CashAdd || cur is LedgerAdd) && (complainsWrong(t) || aboutTheAssistant(t) == AboutMe.complaint)) {
          final item = cashItem(cur!.transcript);
          _ask(out, trf('{0}ঠিক অঙ্কটা বলুন, যেমন “{1} ৩০০ টাকা”। ঠিক হলে তারপর রাখব — এখনো কিছু রাখিনি।', [item.isEmpty ? '' : '$item — ', item.isEmpty ? tr('খরচ') : item]), ChatWait.yesNo,
              choices: _yesNoChoices, facts: [summaryLine(cur)]);
          return true;
        }
        // "না, এগারোটায় করো", "না, করিমকে", "না, কাল": the waiting action
        // corrected — not a no. It is shown again with the change.
        if (!refused && !_askingAll && await _editPending(t, out)) return true;
        // A whole new request instead of yes/no ("কাল সকাল ১০টায় একটা
        // অ্যালার্ম সেট করে দাও"): the waiting one is dropped, never saved
        // by a "দাও" in the new sentence — the new one is handled instead.
        if (!refused && _looksNew(t) && yesNo(t) != false) {
          final next = parseAll(t, brain.data.ledger, tasks: brain.data.tasks, contacts: brain.data.contacts, folders: brain.folderHints, now: _now, data: brain.data);
          final action = next.isNotEmpty && next.every((c) => c is ReminderAdd || c is TaskAdd || c is TasksClear || c is LedgerAdd || c is CashAdd || c is ContactAdd || c is HealthAdd || (c is NoteAdd && !c.fromStatement));
          // The same request said again ("হ্যাঁ … সবকটা মুছে দাও"): that is a yes.
          final cur2 = _current;
          final same = next.length == 1 && cur2 != null && next.single.runtimeType == cur2.runtimeType &&
              (cur2 is TasksClear ? (next.single as TasksClear).day == cur2.day : traceLine(next.single) == traceLine(cur2));
          if (same) {
            Trace.log('understood', 'the waiting request said again — taken as yes', const {});
            wait = ChatWait.none;
            choices = const [];
            await _saveCurrent(out);
            return true;
          }
          // "এই সপ্তাহে কত দিন তিলাওয়াত করেছি": a question of its own, not
          // about the item waiting — never a yes to it.
          final question = isQuestionText(t) && yesNo(t) == null && words(normalize(t)).length >= 4 &&
              !RegExp(fold(r'(?:^|\s)(?:এটা|ওটা|এটি|ওটি|এগুলো|সেটা|কোন\s+বিভাগ|কোথায়\s+রাখ)')).hasMatch(fold(normalize(t)));
          if (action || question) {
            Trace.log('understood', 'new request while a save waited — the waiting one dropped', {'new': next.map(traceLine).join(' | ')});
            _dropPending();
            return false;
          }
        }
        // "২ নম্বরটা রেখো না", "বলতে চাই না — ওটা রাখার মত কিছু না",
        // "শুধু প্রথমটা রাখো": about some of the listed items, not all.
        if (_askingAll && _queue.isNotEmpty) {
          final lines = [for (final c in _queue) summaryLine(c)];
          final named = mentionedItems(t, lines);
          final f = fold(normalize(t));
          // "পেয়াজ এবং চা পাতার দাম ভুল উঠেছে", "এখনো ঠিক করতে পারো নাই":
          // something is wrong in the list — never a yes, never a drop.
          final complaint = complainsWrong(f);
          final amount = findAmount(normalize(t));
          // "পেয়াজ ৩০০ টাকা": that item's amount, said again.
          if (named.length == 1 && amount != null && !dropsItem(t)) {
            final i = named.single;
            final c = _queue[i];
            if (c is CashAdd || c is LedgerAdd) {
              _queue[i] = c is CashAdd
                  ? CashAdd(c.transcript, kind: c.kind, amount: amount, category: c.category, project: c.project)
                  : LedgerAdd((c as LedgerAdd).transcript, person: c.person, amount: amount, kind: c.kind, options: c.options, suggested: c.suggested, allowExpense: c.allowExpense, date: c.date);
              _ask(out, tr('ঠিক আছে, অঙ্কটা বদলে দিলাম। এখন এভাবে রেখে দিই?'), ChatWait.yesNo, choices: _yesNoChoices, facts: [for (final x in _queue) summaryLine(x)]);
              return true;
            }
          }
          if (complaint) {
            // Every item the reply names by its own words ("পেয়াজ এবং চা পাতার").
            final said = words(normalize(t)).toSet();
            final items = [for (final c in _queue) cashItem(c.transcript)];
            final hit = [
              for (var i = 0; i < items.length; i++)
                if (items[i].isNotEmpty && words(normalize(items[i])).any((w) => w.runes.length > 1 && said.any((x) => x.startsWith(w)))) i,
            ];
            final which = hit.isEmpty ? '' : '${nameList([for (final i in hit) items[i]], unit: 'টা')} — ';
            final example = hit.isEmpty ? (items.firstWhere((x) => x.isNotEmpty, orElse: () => trf('{0} নম্বর', [bnDigits(1)]))) : items[hit.first];
            _ask(out, trf('{0}ঠিক অঙ্কটা বলুন, যেমন “{1} ৩০০ টাকা”। ঠিক হলে তারপর রাখব — এখনো কিছু রাখিনি।', [which, example]), ChatWait.yesNo,
                choices: _yesNoChoices, facts: lines);
            return true;
          }
        }
        if (_askingAll && _queue.length > 1) {
          final lines = [for (final c in _queue) summaryLine(c)];
          final named = mentionedItems(t, lines);
          if (named.isNotEmpty) {
            final keepOnly = keepsOnly(t) || !dropsItem(t);
            final keep = [for (var i = 0; i < _queue.length; i++) if (named.contains(i) == keepOnly) _queue[i]];
            Trace.log('understood', 'some of the list', {'named': named.map((i) => i + 1).join(','), 'keep': keep.length});
            _queue
              ..clear()
              ..addAll(keep);
            if (keep.isEmpty) {
              _askingAll = false;
              wait = ChatWait.none;
              choices = const [];
              _say(out, tr('আচ্ছা, কিছুই রাখলাম না।'));
              return true;
            }
            final dropped = lines.length - keep.length;
            _ask(
                out,
                keep.length == 1
                    ? trf('ঠিক আছে, {0}টা বাদ দিলাম। বাকিটা রেখে দিই?', [bnDigits(dropped)])
                    : trf('ঠিক আছে, {0}টা বাদ দিলাম। বাকি {1}টা রেখে দিই?', [bnDigits(dropped), bnDigits(keep.length)]),
                ChatWait.yesNo,
                choices: _yesNoChoices,
                facts: [for (final c in keep) summaryLine(c)]);
            return true;
          }
        }
        // A question about what waits ("কোন তারিখে তুলবা?"): answered, still waiting — never a yes.
        // "রোজা কবে?" names something else: a new question, not about this.
        final aboutOther = infoTopic(normalize(t)) != null || calendarAsked(t) || words(normalize(t)).length > 6;
        if (!refused && !aboutOther && isQuestionText(t) && yesNo(t) != false && (_current is TaskAdd || _current is ReminderAdd) && !_askingAll && RegExp(fold(r'(?:কোন\s+তারিখ|কবে|কখন|কয়টায়|কটায়|কোন\s+দিন|কোন\s+সময়)')).hasMatch(fold(t))) {
          final cur1 = _current;
          final info = cur1 is TaskAdd
              ? (cur1.due == null ? tr('তারিখ ছাড়া রাখব। তারিখ চাইলে বলুন, যেমন “২০ তারিখে”।') : trf('{0} তারিখে রাখব।', [sayWhen(cur1.due!, _now, withTime: false)]))
              : cur1 is ReminderAdd
                  ? trf('{0}-এ মনে করাব।', [sayWhen(cur1.at, _now)])
                  : '';
          _say(out, '$info ${tr('রেখে দিই — হ্যাঁ, নাকি না?')}'.trim());
          choices = _yesNoChoices;
          return true;
        }
        // "এটা অন্যান্য হিসাবের মাঝে রাখো" while an expense waits: that one,
        // into the separate account — never a plain yes.
        final cur2 = _current;
        if (cur2 is CashAdd && cur2.project == null && !_askingAll && (projectMeant(brain.data, t) != null || projectPageNamed(t))) {
          final p = projectMeant(brain.data, t);
          wait = ChatWait.none;
          choices = const [];
          await _start(CashAdd(cur2.transcript, kind: cur2.kind, amount: cur2.amount, category: cur2.category, project: p?.name ?? ''), out);
          return true;
        }
        final yn = refused ? false : yesNo(t);
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
            _refused = ([..._queue], _now);
            _queue.clear();
            _say(out, tr('আচ্ছা, কিছুই রাখলাম না।'));
          }
          return true;
        }
        if (yn) {
          await _saveCurrent(out);
        } else {
          final cur3 = _current;
          if (cur3 != null) _refused = ([cur3], _now);
          // A "মুছে দেবো?" answered no: nothing removed (not "nothing kept").
          _say(out, cur3 is ManageItem && cur3.action == 'delete' ? tr('ঠিক আছে, মুছিনি — যেমন ছিল তেমনই আছে।') : tr('আচ্ছা, রাখলাম না।'));
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
        // "রিমাইন্ডার খোলো", "আজ কত খরচ হলো?": not a name.
        if (_opensPage(t) || (isQuestionText(t) && words(normalize(t)).length >= 3 && _looksNew(t))) return false;
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
        // "সকালে কয়টায়?" → "আটটায়": the morning, not asked again.
        final part = _pendingPart;
        // Whatever the clock words look like ("১১ টায়", "১১টা", "এগারোটায়"),
        // a part of the day already said holds unless the answer names one.
        // Only an answer that is itself a clock time ("১১ টায়") takes the
        // part said before — "আমার পাসপোর্ট দাও" is not "দুপুর" anything.
        // "কাল রবিনকে কল করতে হবে" while a time is asked: a new request,
        // not "কাল" for the waiting reminder.
        if (_beyondWhen(t) >= 2) return false;
        final own = parseWhen(t, _now);
        final t2 = part != null && part != '?' && own != null && own.hasTime && !saysDayPart(t) ? '$part $t' : t;
        final w = parseWhen(t2, _now);
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
        }
        _pendingDay = null;
        _pendingPart = null;
        wait = ChatWait.none;
        // The day already said counts as said ("কাল" then "৮টায়").
        final daySaid = day != null ? '${sayWhen(day, _now, withTime: false)} ' : '';
        await _start(ReminderAdd('$daySaid$t2', title: _pendingTitle, at: at, repeat: _pendingRepeat, alarm: _pendingAlarm, weekdays: _pendingDays, minutesBefore: _pendingBefore), out);
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
      case ChatWait.taskDay:
        final dn = int.tryParse(asciiDigits(t).replaceAll(RegExp(r'[^0-9]'), ''));
        final pend = _pendingTask;
        if (pend == null || _pendingMonth == null) return false;
        if (dn == null || dn < 1 || dn > 31) {
          if (_looksNew(t)) return false;
          _say(out, tr('কত তারিখ — সংখ্যাটা বলুন, যেমন “৩১ তারিখে”।'));
          return true;
        }
        var day = DateTime(_now.year, _pendingMonth!, dn);
        if (day.isBefore(dayOnly(_now))) day = DateTime(_now.year + 1, _pendingMonth!, dn);
        _pendingTask = null;
        _pendingMonth = null;
        wait = ChatWait.none;
        choices = const [];
        await _start(TaskAdd(pend.transcript, title: pend.title, due: day), out);
        return true;
      case ChatWait.taskTitle:
        // The words to write, said next ("আমাকে পুকুরে চুন দিতে হবে").
        if (isQuestionText(t) && _looksNew(t)) return false;
        final said = tidySpeech(t);
        final w = parseWhen(said, _now);
        var title = todoTitle(withoutWhen(said));
        if (title.isEmpty) title = tidy(cutWords(withoutWhen(said), const ['আমাকে', 'আমার', 'লিখে রাখো', 'লিখো', 'লেখো', 'লেখ', 'যে', 'এটা', 'একটা']));
        title = title.replaceAll(RegExp(r'[।.!,]+$'), '').trim();
        if (title.isEmpty) {
          _say(out, tr('কী লিখব, শুনতে পাইনি। কাজটা বলুন — যেমন “বিদ্যুৎ বিল দিতে হবে”।'));
          return true;
        }
        final due = w != null && w.hasDay ? w.day : _pendingTaskDue;
        final was = _pendingTaskAdd;
        _pendingTaskDue = null;
        _pendingTaskAdd = null;
        wait = ChatWait.none;
        choices = const [];
        await _start(TaskAdd(t, title: title, due: due, span: was?.span ?? TaskSpan.day, repeat: was?.repeat, deadline: was?.deadline ?? false), out);
        return true;
      case ChatWait.callee:
        // "রবিন হায়দার বলেছি, আহাদ না" / "না, রবিন হায়দার": the name said
        // again, a correction of the search — searched afresh, not a new topic.
        final fix = RegExp(fold(r'^\s*(?:না[,\s]+)?(.+?)\s+(?:বলেছি|বলছি|বললাম|বলেছিলাম|বলছিলাম)\b')).firstMatch(fold(t)) ??
            RegExp(fold(r'^\s*(?:না|নাহ|উহু)[,\s]+(.+?)\s*(?:কে)?\s*$')).firstMatch(fold(t));
        if (fix != null && _call != null) {
          final name = fix[1]!.replaceAll(RegExp(fold(r'(?:কে|কেই)$')), '').trim();
          if (name.isNotEmpty && words(normalize(name)).length <= 3) {
            _callee = name;
            _calleeChoices = const [];
            wait = ChatWait.none;
            choices = const [];
            _nextCallStep(out);
            return true;
          }
        }
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
      case ChatWait.newAccount:
        // "নির্দেশনা কি দিই, আর উত্তর কি দাও": a complaint, not a yes.
        if (aboutTheAssistant(t) == AboutMe.complaint) {
          final name = _accountWanted?.$1 ?? '';
          _ask(out, trf('দুঃখিত, আগে ঠিক উত্তর দিইনি। আপনি ‘{0}’ নামে আলাদা হিসাব চেয়েছেন — অন্যান্য হিসাবে খুলে দিই?', [name]), ChatWait.newAccount,
              choices: [ChatChoice(tr('হ্যাঁ, খুলে দাও'), 'হ্যাঁ'), ChatChoice(tr('না'), 'না')]);
          return true;
        }
        final yn = yesNo(t);
        if (yn == null) {
          if (_looksNew(t)) return false;
          _say(out, tr('খুলে দেবো কিনা — হ্যাঁ বা না বলুন।'));
          return true;
        }
        wait = ChatWait.none;
        choices = const [];
        final name = _accountWanted?.$1;
        if (yn != true || name == null) {
          _say(out, tr('আচ্ছা, খুললাম না।'));
          return true;
        }
        await _openAccount(name, out);
        return true;
      case ChatWait.project:
        final cur = _current;
        wait = ChatWait.none;
        choices = const [];
        final moving = _moveCashId;
        _moveCashId = null;
        if (moving != null) {
          final e = brain.data.cash.where((x) => x.id == moving).firstOrNull;
          if (e == null) return false;
          var name = tidy(cutWords(t, const ['প্রজেক্ট', 'প্রজেক্টে', 'প্রজেক্টের', 'প্রকল্প', 'প্রকল্পে', 'নামে', 'নাম', 'হিসাবে', 'হিসাব']));
          if (name.isEmpty) name = t.trim();
          final known = projectByName(brain.data, name);
          final p = known != null ? (brain.canUseProject(known.id) ? known : null) : (brain.canAddProject ? await brain.projectNamed(name) : null);
          if (p == null) {
            _say(out, tr('ফ্রিতে ১টা অন্যান্য হিসাবে লেখা যায়; এর বেশি প্রিমিয়াম সুবিধা — খরচটা যেমন ছিল আছে।'));
            return true;
          }
          final moved = await _moveCash(e, p, out);
          _askProjectMain(brain.data.projects.firstWhere((x) => x.id == p.id, orElse: () => p), out);
          return moved;
        }
        if (cur is! CashAdd) return false;
        var name = tidy(cutWords(t, const ['প্রজেক্ট', 'প্রজেক্টে', 'প্রজেক্টের', 'প্রকল্প', 'প্রকল্পে', 'নামে', 'নাম']));
        if (name.isEmpty) name = t.trim();
        final known = projectByName(brain.data, name);
        await _start(CashAdd(cur.transcript, kind: cur.kind, amount: cur.amount, category: cur.category, project: known?.name ?? name), out);
        return true;
      case ChatWait.kind:
        final src = _src!;
        // "সাবিনা না এটা রবিন হবে": not this person — the same money with
        // the right one, read again from the start (owner's voice chat, 25 Oct).
        final other = personCorrection(t, _person);
        if (other != null) {
          wait = ChatWait.none;
          choices = const [];
          await _start(LedgerAdd(src.transcript.replaceAll(_person, other), person: other, amount: _amount, kind: _overKind ?? src.kind), out);
          return true;
        }
        // "রহিমা আপার কাছ থেকে ১০০০ টাকা ধার নিলাম" while "মাকে ৫০০০ …" waits:
        // a whole new money event (its own amount or person), never the
        // answer to the old question — the old one is left unsaved.
        if (_otherMoneyEvent(t, src)) return false;
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
        if (_allYes) _batchKind = _kind;
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
  /// "মাহির ২০০০ টাকাটা বেতনের হিসাবে সরাও", "ওটা বেতনের হিসাবে সরাও": an
  /// entry already kept in the general income-expense, moved into that
  /// account — the same entry (never a second one). Undo is offered.
  Future<bool> _moveCashInto(String t, List<String> out) async {
    final f = fold(normalize(t));
    if (!RegExp(fold(r'(?:সরাও|সরিয়ে\s+দাও|সরিয়ে\s+দাও|নিয়ে\s+যাও|ট্রান্সফার\s+করো|স্থানান্তর\s+করো)\s*[।.!]?$')).hasMatch(f)) return false;
    final p = projectHinted(brain.data, t);
    if (p == null) return false;
    if (!brain.canUseProject(p.id)) {
      _say(out, tr('ফ্রিতে ১টা অন্যান্য হিসাবে লেখা যায়; এর বেশি প্রিমিয়াম সুবিধা — খরচটা যেমন ছিল আছে।'), links: [ChatLink(LinkKind.page, tr('প্রিমিয়াম দেখুন'), page: 'pro')]);
      return true;
    }
    final amount = findAmount(normalize(t));
    final said = words(normalize(t)).where((w) => w.runes.length > 2).map((w) => w.replaceAll(RegExp(fold(r'(?:ের|এর|র)$')), '')).toSet();
    final recent = [
      for (final e in brain.data.cash)
        if (e.projectId == null && e.linkId == null && (amount == null || e.amount == amount) && !e.date.isBefore(dayOnly(_now).subtract(const Duration(days: 60)))) e
    ]..sort((a, b) => b.date.compareTo(a.date));
    // Named ("মাহির") or the only one with that amount; "ওটা" = the newest.
    final named = [for (final e in recent) if (words(normalize(e.note)).any((w) => said.any((x) => w.startsWith(x)))) e];
    final pick = named.length == 1 ? named.single : (recent.length == 1 ? recent.single : (amount == null && recent.isNotEmpty && RegExp(fold(r'(?:^|\s)(?:ওটা|এটা|ওইটা|সেটা)(?:\s|$)')).hasMatch(f) ? recent.first : null));
    if (pick == null) {
      _say(out, recent.isEmpty
          ? tr('সাধারণ আয়-ব্যয়ে এমন কোনো এন্ট্রি পেলাম না — কিছু সরাইনি।')
          : trf('এমন {0}টা এন্ট্রি আছে — কোনটা সরাব? নাম বা অঙ্কসহ বলুন। কিছু সরাইনি।', [bnDigits(recent.length)]),
          facts: [for (final e in recent.take(5)) '${e.kind == CashKind.income ? tr('আয়') : tr('খরচ')}: ${e.category} — ${bnNumber(e.amount)} টাকা (${sayWhen(e.date, _now, withTime: false)})']);
      return true;
    }
    final snap = brain.snapshot();
    await brain.saveCash(CashEntry(id: pick.id, kind: pick.kind, amount: pick.amount, category: pick.category, note: pick.note, date: pick.date, projectId: p.id, accountId: pick.accountId, shopId: pick.shopId));
    _say(out, trf('{0} টাকার এন্ট্রিটা ‘{1}’ হিসাবে সরিয়েছি — নতুন করে কিছু যোগ হয়নি।', [bnNumber(pick.amount), p.name]), links: [ChatLink(LinkKind.page, tr('অন্যান্য হিসাব'), page: 'projects')]);
    _offerUndo(snap);
    return true;
  }

  /// "১ মে এর কাজের রিমাইন্ডার দরকার": the to-dos kept on that day (of
  /// whatever year they are in — "১ মে ২০২৯"), their reminder; "এখানে
  /// রিমাইন্ডার যুক্ত কর" right after a to-do: that one's. The time is asked
  /// when not said; never a reminder called "কাজের দরকার".
  Future<bool> _remindByDayOrHere(String t, List<String> out) async {
    // "একটু / ভাই / আপু …": a polite word before the request.
    final f = ' ${fold(normalize(tidySpeech(t))).replaceAll(RegExp(r'[।,!?]'), ' ').replaceFirst(RegExp(fold(r'^\s*(?:(?:একটু|ভাই|আপু|প্লিজ|আচ্ছা|শোনো|জি)\s+)+')), '')} ';
    if (!RegExp(fold(r'(?:রিমাইন্ডার|মনে\s+করানো|এলার্ম|অ্যালার্ম)')).hasMatch(f)) return false;
    if (!RegExp(fold(r'(?:দরকার|লাগবে|দাও|দিও|দেন|দিন|চাই|যুক্ত\s+কর|যোগ\s+কর|লাগাও|সেট\s+কর|দিয়ে\s+দাও|রাখো)')).hasMatch(f)) return false;
    final w = parseWhen(tidySpeech(t), _now);
    final clock = w != null && w.hasTime && saysClock(tidySpeech(t));
    List<Task> targets = const [];
    // "এখানে / এটাতে / এই কাজে রিমাইন্ডার যুক্ত কর".
    final here = RegExp(fold(r'(?:^|\s)(?:এখানে|এটাতে|এতে|ওটাতে|ওখানে|এটার|ওটার|এটায়|এই\s+কাজে|ওই\s+কাজে|এই\s+কাজটায়|কাজটায়|কাজটাতে)\s+(?:একটা\s+)?রিমাইন্ডার')).hasMatch(f);
    if (here) {
      final focus = _focusTaskId != null && _focusTaskAt != null && _now.difference(_focusTaskAt!).inMinutes <= 15 ? _taskById(_focusTaskId!) : null;
      if (focus == null) return false;
      targets = [focus];
    } else {
      final dm = RegExp(fold(r'^\s*([০-৯0-9]{1,2})\s+(' + bnMonths.join('|') + r')(?:\s+([০-৯0-9]{4}))?\s*(?:এর|ের|তারিখের|-এর)?\s+(?:সব\s+)?(?:কাজ|কাজের|কাজটার|কাজটির|কাজগুলোর|কাজগুলার)\s')).firstMatch(f);
      if (dm == null) {
        // "ব্যাংক এর কাজের রিমাইন্ডার দরকার": a to-do named before "কাজের".
        // "নোয়াখালী যাওয়ার রিমাইন্ডার চাই": a to-do's name, "কাজের" or not.
        final nm = RegExp(fold(r'^\s*(.+?)\s*(?:এর|-এর)?\s+(?:(?:কাজ|কাজের|কাজটার|কাজটির|কাজটায়|কাজে)\s+)?(?:একটা\s+)?(?:রিমাইন্ডার|এলার্ম|অ্যালার্ম)')).firstMatch(f);
        // Without "কাজের", only a plain ask ("…রিমাইন্ডার চাই/দাও"): times
        // and "আগের দিন" have their own rules.
        final plain = nm != null && (RegExp(fold(r'(?:কাজ|কাজের|কাজটার|কাজটির|কাজটায়|কাজে)\s+(?:একটা\s+)?(?:রিমাইন্ডার|এলার্ম|অ্যালার্ম)')).hasMatch(f) ||
            RegExp(fold(r'^\S*\s*(?:একটা\s+)?(?:চাই|দাও|দিও|দেন|দিন|দরকার|লাগবে|সেট\s+করো|সেট\s+কর|যুক্ত\s+করো|যুক্ত\s+কর|দিয়ে\s+দাও)?\s*$')).hasMatch(f.substring(nm.end)));
        // A day or a time inside the name ("আজ সকাল ৮টায় ব্যাংকে…") is a
        // reminder of its own, not the to-do's.
        final named = nm == null || !plain || parseWhen(nm[1]!, _now) != null ? null : _openTaskNamed(nm[1]!);
        if (named == null) return false;
        targets = [named];
      }
    }
    if (targets.isEmpty) {
      final dm = RegExp(fold(r'^\s*([০-৯0-9]{1,2})\s+(' + bnMonths.join('|') + r')(?:\s+([০-৯0-9]{4}))?\s*(?:এর|ের|তারিখের|-এর)?\s+(?:সব\s+)?(?:কাজ|কাজের|কাজটার|কাজটির|কাজগুলোর|কাজগুলার)\s')).firstMatch(f)!;
      final day = int.parse(asciiDigits(dm[1]!));
      final month = bnMonths.map(fold).toList().indexOf(dm[2]!) + 1;
      final year = dm[3] == null ? null : int.parse(asciiDigits(dm[3]!));
      final open = [for (final x in brain.data.tasks) if (!x.done && x.due != null && x.span == TaskSpan.day && x.due!.month == month && x.due!.day == day && (year == null || x.due!.year == year) && !x.due!.isBefore(dayOnly(_now))) x];
      if (open.isEmpty) {
        _say(out, trf('{0} {1}-এ কোনো কাজ রাখা নেই — কিছু রাখিনি।', [bnDigits(day), monthName(month)]), links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
        return true;
      }
      // The nearest year that has to-dos on that day.
      final y = open.map((x) => x.due!.year).reduce((a, b) => a < b ? a : b);
      targets = [for (final x in open) if (x.due!.year == y) x];
    }
    // A week's or month's plan: the usual path asks which day.
    if (targets.length == 1 && targets.single.span != TaskSpan.day) return false;
    if (targets.length == 1) {
      final task = targets.single;
      _focusTask(task);
      if (clock) {
        final d = dayOnly(task.due ?? _now);
        await _todo(TaskEdit(t, ref: TaskRef(ids: [task.id]), remindAt: DateTime(d.year, d.month, d.day, w.at.hour, w.at.minute), remindAmPm: ampmUnclear(t)), out);
      } else {
        await _todo(TaskEdit(t, ref: TaskRef(ids: [task.id]), remindNeedsTime: true), out);
      }
      return true;
    }
    _batchTasks = ([for (final x in targets) x.id], '', _turn);
    _batchPart = null;
    _ask(out, trf('{0}টা কাজের রিমাইন্ডার — প্রতিটা নিজের দিনে, কয়টায় মনে করাব? যেমন “দুপুর ১২টায়”।', [bnDigits(targets.length)]), ChatWait.batchTime,
        facts: [for (final x in targets) taskLine(x, _now)]);
    return true;
  }

  /// The freshest list shown (to-dos or reminders), numbered as shown.
  String _shownForAi() {
    final set = _sets.where(_setFresh).lastOrNull;
    if (set == null) return '';
    final d = brain.data;
    final lines = <String>[];
    for (final (i, id) in set.ids.take(20).indexed) {
      final line = switch (set.domain) {
        'tasks' => d.tasks.where((x) => x.id == id).map((x) => taskLine(x, _now)).firstOrNull,
        'reminders' => d.reminders.where((x) => x.id == id).map((x) => '${x.title} — ${sayWhen(DateTime(x.date.year, x.date.month, x.date.day, x.hour, x.minute), _now)}').firstOrNull,
        _ => null,
      };
      if (line != null) lines.add('${i + 1}. $line');
    }
    if (lines.isEmpty) return '';
    return '${set.domain == 'tasks' ? 'to-dos' : 'reminders'} (${set.label}):\n${lines.join('\n')}';
  }

  Future<bool> _reminderChange(String t, List<String> out) async {
    final f = fold(normalize(t));
    if (!RegExp(fold(r'(?:রিমাইন্ডার|মনে\s+করানো|এলার্ম|অ্যালার্ম)')).hasMatch(f)) return false;
    // Removing, stopping or a to-do's own reminder have their own rules.
    if (RegExp(fold(r'(?:মুছ|ডিলিট|বাদ|বন্ধ|লাগবে\s+না|দরকার\s+নেই|দরকার\s+নাই|(?:^|\s)কাজ)')).hasMatch(f)) return false;
    final said = tidySpeech(t);
    final w = parseWhen(said, _now);
    final clock = w != null && w.hasTime && saysClock(said);
    final timeWord = RegExp(fold(r'(?:সময়|টাইম|time)')).hasMatch(f);
    final strong = timeWord || RegExp(fold(r'(?:সরাও|সরিয়ে|বদল|পরিবর্তন|চেঞ্জ|করে\s+দাও|(?:^|\s)করো|(?:^|\s)কর(?:\s|$)|হবে)')).hasMatch(f);
    final weak = RegExp(fold(r'(?:দিও|(?:^|\s)দাও|(?:^|\s)দেন|(?:^|\s)দিন)')).hasMatch(f);
    if (!(clock || timeWord) || !(strong || weak)) return false;
    final hits = remindersNamed(brain.data, t, _now);
    if (hits.isEmpty || hits.length > 6) return false;
    // "তুবার জন্মদিনের রিমাইন্ডার সন্ধ্যা ৭টায় দিও" with one already kept:
    // that one moved, or a second one — asked, never guessed.
    if (!strong && hits.length == 1) {
      final add = parseAll(t, brain.data.ledger, tasks: brain.data.tasks, contacts: brain.data.contacts, folders: brain.folderHints, now: _now, data: brain.data).whereType<ReminderAdd>().firstOrNull;
      if (add != null) {
        final x = hits.single;
        _clarifyTarget = x;
        _clarifyOptions = [
          (tr('ওটাই সরাও'), ManageItem(t, action: 'edit')),
          (tr('আরেকটা রাখো'), add),
        ];
        _ask(out, trf('“{0}” — এটার সময় বদলাব, নাকি আরেকটা রিমাইন্ডার রাখব?', [x.label]), ChatWait.clarify, choices: [for (final o in _clarifyOptions) ChatChoice(o.$1, o.$1)]);
        return true;
      }
    }
    _current = ManageItem(t, action: 'edit');
    if (hits.length > 1) {
      _targets = hits;
      _ask(out, trf('কয়েকটা মিলেছে — কোনটা {0}?', [tr('বদলাবো')]), ChatWait.whichItem,
          facts: [for (var i = 0; i < hits.length; i++) '${bnDigits(i + 1)}. ${hits[i].label}'],
          choices: [for (var i = 0; i < hits.length; i++) ChatChoice(bnDigits(i + 1), '${i + 1}')]);
      return true;
    }
    await _confirmManage(hits.single, out);
    return true;
  }

  Future<bool> _renameInstead(String t, List<String> out) async {
    final f = fold(normalize(t));
    if (!RegExp(fold(r'নাম\s*(?:টা\s+)?(?:বদল|বদলাও|বদলে|পরিবর্তন|চেঞ্জ|পাল্টাও|পাল্টে)')).hasMatch(f) || renameCommand(t) != null) return false;
    // Only "কাজের নাম বদল কর" — which and to what are in the words before.
    if (words(f).length > 6) return false;
    final last = _lastSave;
    var undone = false;
    if (last != null && _now.difference(last.$3).inMinutes <= 5 && _savedTurn >= _turn - 1) {
      await brain.restoreSnapshot(last.$2);
      _lastSave = null;
      undone = true;
    }
    if (wait != ChatWait.none) _dropPending();
    final prev = [for (final m in messages.reversed) if (m.fromUser) m.text].skip(1).firstOrNull ?? '';
    // "যশোর যাওয়া শ্বশুর বাড়ি যাওয়া লিখে রাখো": a to-do's name, then the new one.
    TaskEdit? again = renameCommand(prev);
    if (again == null && prev.isNotEmpty) {
      final p = fold(normalize(prev));
      for (final x in brain.data.tasks.where((x) => !x.done)) {
        final k = fold(normalize(x.title));
        final head = RegExp('^${RegExp.escape(k)}\\S{0,3}\\s+(?:${fold('কাজের|কাজটার|কাজটা|এর')}\\s+)?(?:${fold('নাম')}\\s+)?').firstMatch(p);
        if (head == null) continue;
        final rest = p.substring(head.end).replaceAll(RegExp(fold(r'\s*(?:লিখে\s+রাখো|রাখো|হবে|করো|লেখো|লিখো)\s*$')), '').trim();
        if (rest.isNotEmpty) again = TaskEdit(prev, ref: TaskRef(ids: [x.id]), title: rest);
        break;
      }
    }
    if (again != null) {
      if (undone) messages.add(ChatMessage.app(tr('আগেরটা ভুল করে রেখেছিলাম — সরিয়ে নিলাম।'), info: true));
      await _todo(again, out);
      return true;
    }
    _say(out, undone
        ? tr('আগেরটা সরিয়ে নিলাম। কোন কাজের নাম কী হবে? যেমন বলুন “যশোর যাওয়া কাজের নাম বদলে শ্বশুর বাড়ি যাওয়া রাখো”।')
        : tr('কোন কাজের নাম কী হবে? যেমন বলুন “যশোর যাওয়া কাজের নাম বদলে শ্বশুর বাড়ি যাওয়া রাখো”।'));
    return true;
  }

  /// An open to-do with the same name as [c] ("বাজার করা" for "বাজার করা
  /// করা" / "বাজারের কাজ") kept for another day.
  Task? _sameTitleOtherDay(TaskAdd c) {
    String key(String x) => fold(normalize(x)).replaceAll(RegExp(fold(r'(?:\s+(?:করা|কাজ|কাজটা))+$')), '').replaceAll(RegExp(fold(r'(?:ের|এর|র)$')), '').trim();
    final k = key(c.title);
    if (k.isEmpty) return null;
    final hits = [for (final t in brain.data.tasks) if (!t.done && t.repeat == null && t.due != null && dayOnly(t.due!) != dayOnly(c.due!) && key(t.title) == k) t];
    if (hits.length != 1) return null;
    // Only when that to-do itself is named ("বাজার করা কাল করব", "বাজারের
    // কাজ কাল"): "পরশু ওষুধ আনতে হবে" is a need of its own, kept at once.
    final said = fold(normalize(c.transcript));
    final title = fold(normalize(hits.single.title));
    final named = said.contains(title) || RegExp('${RegExp.escape(k)}\\S*\\s+${fold('কাজ')}').hasMatch(said);
    return named ? hits.single : null;
  }

  /// "হাতে কত রইল?" right after "৯০০০ টাকা নিয়ে বাজারে গেলাম; মাছ ২৫০০, …":
  /// what is left of the money taken along — worked out here, from the
  /// parts said, never the accounts' balance.
  bool _envelopeLeft(String t, List<String> out) {
    final f = fold(normalize(t));
    if (!RegExp(fold(r'(?:হাতে|পকেটে|সাথে)\s+(?:আর\s+)?(?:কত|কতো)\s*(?:টাকা\s+)?(?:রইল|রইলো|থাকল|থাকলো|আছে|বাকি|রয়েছে)|(?:কত|কতো)\s+(?:টাকা\s+)?(?:রইল|রইলো|থাকল|থাকলো|বাঁচল|বাঁচলো|ফেরত\s+(?:আনলাম|থাকল))')).hasMatch(f)) return false;
    final said = [for (final m in messages.reversed) if (m.fromUser) m.text].skip(1).take(6);
    for (final x in said) {
      final carried = carriedCash(x);
      if (carried == null) continue;
      final parts = spentInParts(x, Parser(ledger: brain.data.ledger, tasks: brain.data.tasks, now: _now)) ?? const [];
      final spent = parts.whereType<CashAdd>().fold<int>(0, (s, c) => s + c.amount);
      if (spent == 0) return false;
      final left = carried - spent;
      _say(out, left >= 0
          ? trf('{0} টাকা নিয়ে গিয়েছিলেন, খরচ {1} টাকা — হাতে থাকার কথা {2} টাকা।', [bnNumber(carried), bnNumber(spent), bnNumber(left)])
          : trf('{0} টাকা নিয়ে গিয়েছিলেন, কিন্তু খরচ বলেছেন {1} টাকা — {2} টাকা বেশি। কোনো অঙ্ক ভুল হলে বলুন।', [bnNumber(carried), bnNumber(spent), bnNumber(-left)]));
      return true;
    }
    return false;
  }

  /// "পেয়াজ ৩০০ টাকা" (or just "৩০০ টাকা") while that item waits with
  /// another amount: the amount said again, right.
  int? _restatedAmount(String t, Command cur) {
    if (cur is! CashAdd && cur is! LedgerAdd) return null;
    final a = findAmount(normalize(t));
    final old = cur is CashAdd ? cur.amount : (cur as LedgerAdd).amount;
    if (a == null || a <= 0 || a == old || yesNo(t) == false) return null;
    final rest = words(normalize(t)).where((w) => findAmount(w) == null && !RegExp(fold(r'^(?:টাকা|টাকার|টাকায়|হবে|হবে।|ঠিক|দাম|খরচ|আসলে|মানে)$')).hasMatch(w)).toList();
    if (rest.isEmpty) return a;
    final item = words(normalize(cur is CashAdd ? cashItem(cur.transcript) : (cur as LedgerAdd).person)).toSet();
    return rest.every((w) => item.any((x) => x.startsWith(w) || w.startsWith(x))) ? a : null;
  }

  /// "পেয়াজ ৩০০ টাকা, ৩ না", "৩০০ হবে, ৩ নয়": the new amount, with the
  /// old one said "না" to after it.
  int? _amountSwap(String t) {
    final n = normalize(t).replaceAll(RegExp(r'[।.!]+\s*$'), '').trim();
    final m = RegExp('^(.*\\S)[,\\s]+(\\S+(?:\\s+${normalize('টাকা')})?)\\s+(?:${['না', 'নয়', 'নয়', 'নই'].map(normalize).join('|')})\$').firstMatch(n);
    if (m == null || findAmount(m[2]!) == null) return null;
    final a = findAmount(m[1]!);
    return a == null || a <= 0 || a == findAmount(m[2]!) ? null : a;
  }

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
    _actions++;
    final quiet = _allYes;
    final snap = brain.snapshot();
    _batchSnap ??= snap;
    if (c != null && c is! ManageItem) {
      _lastSave = (c, snap, _now);
      _savedTurn = _turn;
      _idsBeforeSave = {for (final t in targetsIn(brain.data, _now)) t.id};
    }
    switch (c) {
      case HealthAdd() when medicalOff && medicalReading(c.kind):
        _say(out, medicalOffText());
      case LedgerAdd() when !brain.canAddPerson(_person):
        _say(out, trf('ফ্রিতে {0} জনের ধার-দেনা রাখা যায়, সেটা পূর্ণ হয়ে গেছে। প্রিমিয়াম নিলে যত খুশি মানুষ রাখতে পারবেন — আগের হিসাব যেমন আছে থাকবে।', [bnDigits(freeLedgerPeople)]),
            links: [ChatLink(LinkKind.page, tr('প্রিমিয়াম দেখুন'), page: 'pro')]);
      case LedgerAdd():
        final kind = _kind!;
        final after = balanceAfter(brain.data.ledger, _person, kind, _amount);
        final entry = LedgerEntry(person: _person, phone: _ledgerPhone, kind: kind, amount: _amount, date: _ledgerDate ?? dayOnly(_now), note: '');
        await brain.saveEntry(entry, guessPhone: _ledgerPhone.isEmpty);
        _say(out, quiet ? trf('লিখলাম: {0}।', [describe(kind, _person, _amount)]) : savedSentence(kind, _person, _amount, after),
            links: _linksFor1(quiet, [ChatLink(LinkKind.person, trf('{0} খাতা দেখুন', [possessive(_person)]), person: _person)]), speak: !quiet);
        // The loan went into the main money by itself (owner, 24 Oct): a quiet line says so.
        if (brain.lastMainLine case final main?) messages.add(ChatMessage.app(mainAddedText(main), info: true));
        _history.add(AiTurn.app('[লিখে রাখা হলো: ${describe(kind, _person, _amount)}]'));
        _focusOn(person: _person);
      case LedgerSet():
        final e = _setEntry!;
        await brain.saveEntry(e);
        // A বকেয়া is no money out of the pocket (owner, 24 Oct).
        if (c.due) await brain.removeFromMain(e.id);
        _say(out, quiet ? trf('লিখলাম: {0}।', [summaryLine(c)]) : trf('ঠিক আছে, লিখে রাখলাম। {0}', [balanceSentence(e.person, c.balance)]),
            links: _linksFor1(quiet, [ChatLink(LinkKind.person, trf('{0} খাতা দেখুন', [possessive(e.person)]), person: e.person)]), speak: !quiet);
        _history.add(AiTurn.app('[লিখে রাখা হলো: ${summaryLine(c)}]'));
      case NoteAdd():
        final cat = _cat?.name ?? defaultNoteCategory;
        final note = Note(title: noteTitleFrom(c.text), body: c.text, category: cat);
        await brain.saveNote(note);
        _notesKept.add((note.id, c.text, _now));
        _say(out, quiet ? trf('রাখলাম: {0} (‘{1}’)', [c.text, cat]) : trf('ঠিক আছে, ‘{0}’ বিভাগে রেখে দিলাম।', [cat]),
            links: [ChatLink(LinkKind.notes, tr('নোট দেখুন'))], speak: !quiet);
        _history.add(AiTurn.app('[নোট রাখা হলো, বিভাগ: $cat]'));
      case TasksClear():
        final gone = _clearable(c);
        for (final t in gone) {
          await brain.deleteTask(t.id);
        }
        _say(out, trf('মুছে দিলাম — {0}টা কাজ। ৩০ দিন “মুছে ফেলা” থেকে ফেরত আনা যাবে।', [bnDigits(gone.length)]),
            links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
        _history.add(AiTurn.app('[${gone.length}টা কাজ মুছে দেওয়া হলো]'));
      case TaskAdd():
        await _saveTaskAdd(c, out, quiet: quiet);
      case ReminderAdd() when !brain.canAddReminder:
        _say(out, trf('ফ্রিতে একসাথে {0}টা রিমাইন্ডার চালু রাখা যায়, সেটা পূর্ণ। পুরোনো কোনোটা বন্ধ বা মুছে দিন, অথবা প্রিমিয়াম নিলে যত খুশি রাখতে পারবেন।', [bnDigits(freeReminders)]),
            links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন')), ChatLink(LinkKind.page, tr('প্রিমিয়াম দেখুন'), page: 'pro')]);
      case ReminderAdd() when c.ampmOpen:
        // Last guard before the scheduler: an hour still open is never set.
        _say(out, trf('{0} — ভোর না বিকেল, তা ঠিক হয়নি, তাই রিমাইন্ডারটি রাখিনি। সময়টা আবার বলুন।', [c.title]));
      case ReminderAdd():
        final saved = Reminder(
          title: c.title,
          date: DateTime(c.at.year, c.at.month, c.at.day),
          hour: c.at.hour,
          minute: c.at.minute,
          daysBefore: 0,
          repeat: c.repeat,
          alarm: c.alarm,
          weekdays: c.weekdays,
          minutesBefore: c.minutesBefore,
        );
        await brain.saveReminder(saved);
        // "না, এগারোটায়" right after changes this one.
        _focusReminderId = saved.id;
        _focusReminderAt = _now;
        final early = c.minutesBefore > 0 ? trf(' {0} আগেও একবার জানিয়ে দেব।', [beforeLabel(c.minutesBefore)]) : '';
        // Saved, but the phone will not show it: say so instead of promising.
        if (brain.scheduleFailed) {
          _say(out, trf('রিমাইন্ডারটা রাখা হয়েছে ({0}), কিন্তু ফোনে সেট করা যায়নি — তাই এখনো বাজবে না। অ্যাপটা একবার বন্ধ করে খুলুন; তবু না হলে রিমাইন্ডার পাতা থেকে আবার চালু করুন।', [sayWhen(c.at, _now)]),
              links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))]);
          break;
        }
        if (!(await brain.services.notifier.health()).notificationsOn) {
          _say(out, trf('রিমাইন্ডারটা রাখা হয়েছে ({0}), কিন্তু এই ফোনে অ্যাপের নোটিফিকেশন বন্ধ — তাই এখন বাজবে না। ফোনের সেটিংস থেকে My Assistant-এর নোটিফিকেশন চালু করুন।', [sayWhen(c.at, _now)]),
              links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))]);
          _history.add(AiTurn.app('[রিমাইন্ডার রাখা হলো, কিন্তু নোটিফিকেশন বন্ধ: ${summaryLine(c)}]'));
          break;
        }
        final what = c.needsTitle ? '' : '“${c.title}” ';
        final again = c.repeat == Repeat.none || c.repeat.isInterval || c.repeat == Repeat.daily ? '' : ', ${c.repeat.label}';
        // "রবিবার থেকে বৃহস্পতিবার": the days said back, not "প্রতি সপ্তাহে".
        final days = c.repeat == Repeat.weekly && c.weekdays.length >= 2
            ? trf('ঠিক আছে, প্রতি {0} {1}-এ {2}{3}।', [weekdaysSaid(c.weekdays), bnTime(c.at.hour, c.at.minute), what, c.alarm ? tr('অ্যালার্ম বাজবে') : tr('মনে করিয়ে দেব')])
            : null;
        _say(out, quiet ? trf('মনে করাব: {0}', [c.title]) : days != null ? days + early : (c.repeat == Repeat.daily
                    // "প্রতিদিন সকাল ৯টায়": the time is said back, so it is seen as kept.
                    ? (c.alarm && (c.needsTitle || fold(normalize(c.title)) == fold(normalize('অ্যালার্ম')))
                        ? trf('ঠিক আছে, প্রতিদিন {0}-এ অ্যালার্ম বাজবে।', [bnTime(c.at.hour, c.at.minute)])
                        : trf('ঠিক আছে, প্রতিদিন {0}-এ {1}মনে করিয়ে দেব।', [bnTime(c.at.hour, c.at.minute), what]))
                    : c.repeat.isInterval ? trf('ঠিক আছে, {0} {1}মনে করিয়ে দেব।', [c.repeat.label, what]) : trf('ঠিক আছে, {0}-এ {1}মনে করিয়ে দেব{2}।', [sayWhen(c.at, _now), what, again])) + early,
            links: [ChatLink(LinkKind.reminders, tr('রিমাইন্ডার দেখুন'))], speak: !quiet);
        _history.add(AiTurn.app('[রিমাইন্ডার রাখা হলো: ${summaryLine(c)}]'));
        if (!_warnedExact && !await brain.services.notifier.exactAllowed()) {
          _warnedExact = true;
          messages.add(ChatMessage.app(tr('ঠিক মিনিটে বাজাতে সেটিংস → “ঠিক সময়ে রিমাইন্ডার” চালু করে নিন।'), info: true));
        }
        final rid = _replaceTaskId;
        _replaceTaskId = null;
        if (rid != null) await brain.deleteTask(rid);
      case CashAdd():
        Project? project;
        String proNote = '';
        if (c.project != null) {
          if (!brain.canUseProjectNamed(c.project!)) {
            // Past the free one: nothing is written anywhere else unasked.
            _say(out, trf('ফ্রিতে ১টা অন্যান্য হিসাব; “{0}”-এ লেখা প্রিমিয়াম সুবিধা, তাই কিছু লিখিনি। সাধারণ আয়-ব্যয়ে চাইলে বলুন।', [c.project!]), links: [ChatLink(LinkKind.page, tr('প্রিমিয়াম দেখুন'), page: 'pro')]);
            await _done(out);
            return;
          } else {
            project = await brain.projectNamed(c.project!);
          }
        }
        final cashId = newId();
        await brain.saveCash(CashEntry(
          id: cashId,
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
            links: _linksFor1(quiet, [ChatLink(LinkKind.cash, tr('আয়-ব্যয় দেখুন')), if (proNote.isNotEmpty) ChatLink(LinkKind.page, tr('প্রিমিয়াম দেখুন'), page: 'pro')]), speak: !quiet);
        if (project != null && brain.lastMainLine != null) messages.add(ChatMessage.app(mainAddedText(brain.lastMainLine!), info: true));
        if (project != null) _askProjectMain(brain.data.projects.firstWhere((x) => x.id == project!.id), out);
        _history.add(AiTurn.app('[লেখা হলো: ${summaryLine(c)}]'));
        _focusOn(cash: c.project == null);
      case VaultAdd():
        final old = _vaultNamed(c.name);
        if (old == null && !brain.canAddVault) {
          _say(out, trf('ফ্রিতে {0}টা পাসওয়ার্ড রাখা যায়, সেটা পূর্ণ হয়ে গেছে। প্রিমিয়াম নিলে যত খুশি রাখতে পারবেন — আগেরগুলো যেমন আছে থাকবে।', [bnDigits(freeVaultItems)]),
              links: [ChatLink(LinkKind.page, tr('প্রিমিয়াম দেখুন'), page: 'pro')]);
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
      case ProfileSet() when c.field == 'blood_last':
        final day = DateTime.parse(c.value);
        await brain.setPref('blood_last', day.toIso8601String());
        final next = DateTime(day.year, day.month + 3, day.day);
        _say(out, trf('রেখে দিলাম — শেষ রক্ত দিয়েছেন {0}। আবার দিতে পারবেন {1} থেকে।', [fullDate(day), fullDate(next)]),
            links: [ChatLink(LinkKind.page, tr('ব্লাড ডোনেশন'), page: 'requests')], speak: !quiet);
        _history.add(AiTurn.app(tr('[শেষ রক্তদানের দিন রাখা হলো]')));
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
        // The same person's day of the same kind is one day: kept again, it moves.
        final same = _sameSpecial(c);
        final saved = await brain.saveSpecialDay(
            same != null
                ? same.copyWith(month: c.month, day: c.day, year: c.year ?? same.year)
                : SpecialDay(person: c.person, kind: c.kind, month: c.month, day: c.day, year: c.year),
            hour: c.hour,
            minute: c.minute);
        _lastSpecial = (saved.id, _now);
        final moved = same != null ? trf('বদলে দিলাম — এখন {0} {1}। ', [bnDigits(c.day), monthName(c.month)]) : tr('রেখে দিলাম। ');
        _say(out, quiet ? trf('বিশেষ দিন: {0}', [c.person]) : moved + trf('প্রতি বছর আগের দিন আর সেদিন {0}-এ মনে করিয়ে দেবো।', [bnTime(c.hour ?? 9, c.minute)]),
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

  /// The pages a batch's saves point to, offered once at its end.
  final _batchLinks = <ChatLink>[];

  /// [links] for one save: shown with it, or in a batch kept for the end.
  List<ChatLink> _linksFor1(bool quiet, List<ChatLink> links) {
    if (!quiet) return links;
    for (final l in links) {
      if (!_batchLinks.any((x) => x.label == l.label)) _batchLinks.add(l);
    }
    return const [];
  }

  /// A batch kept: one kind of answer the user gave (ধার দিলাম) for the rest of it.
  LedgerKind? _batchKind;

  /// Puts "ফিরিয়ে নিন" under the last message (and takes it off older ones).
  void _offerUndo(String snap) {
    for (final m in messages) {
      m.undo = null;
    }
    final last = messages.lastWhere((m) => !m.fromUser && !m.info, orElse: () => ChatMessage.app(''));
    if (last.text.isEmpty) return;
    last.undo = snap;
    last.undoAt = DateTime.now();
    _undoAfter = brain.snapshot();
  }

  /// The data right after the save that can be taken back by voice — only
  /// while nothing else has changed since.
  String? _undoAfter;

  /// "ফিরিয়ে নাও": the last save taken back, as the button does — only
  /// when nothing changed after it (else that would be lost too).
  Future<bool> _voiceUndo(String t, List<String> out) async {
    final f = fold(normalize(t)).replaceAll(RegExp(r'[।!?,]'), ' ').trim();
    if (!RegExp(fold(r'^(?:ওটা\s+|এটা\s+|শেষেরটা\s+|শেষটা\s+|আগেরটা\s+)?(?:ফিরিয়ে\s+(?:নাও|নিন|নেও|নে)|আনডু(?:\s+করো)?|undo|আগের\s+অবস্থায়\s+ফিরিয়ে\s+দাও)$')).hasMatch(f)) return false;
    final m = messages.lastWhere((x) => x.undo != null, orElse: () => ChatMessage.app(''));
    if (m.undo == null || _undoAfter == null || brain.snapshot() != _undoAfter) {
      _say(out, tr('ফিরিয়ে নেওয়ার মতো শেষ কোনো পরিবর্তন পেলাম না — মুছে ফেলা জিনিস “মুছে ফেলা” পাতা থেকে ফেরত আনা যায়।'));
      return true;
    }
    final snap = m.undo!;
    m.undo = null;
    _undoAfter = null;
    await brain.restoreSnapshot(snap);
    _lastSave = null;
    _say(out, tr('ফিরিয়ে নিলাম — শেষ পরিবর্তনের আগের মতো আছে।'));
    return true;
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
      if (_savedInBatch > 0 && _batchTaskTitles.length == _savedInBatch) {
        // The same title on several days ("দাওয়াত" on 23 and 24): said once, with the days.
        final same = _batchTaskTitles.toSet().length == 1 && _batchTaskTitles.length > 1;
        final days = [for (final t in brain.data.tasks.reversed.take(_batchTaskTitles.length).toList().reversed) if (t.due != null) sayWhen(t.due!, _now, withTime: false)];
        _say(
            out,
            same && days.length == _batchTaskTitles.length
                ? trf('“{0}” — {1}, {2} দিনই কাজের তালিকায় রেখেছি।', [_batchTaskTitles.first, nameList(days, unit: 'দিন'), bnDigits(days.length)])
                : trf('{0}টা কাজ যোগ করেছি:', [bnDigits(_batchTaskTitles.length)]),
            // Each with its day, so what was kept is seen, not guessed.
            facts: same && days.length == _batchTaskTitles.length
                ? const []
                : [for (final t in brain.data.tasks.reversed.take(_batchTaskTitles.length).toList().reversed) taskLine(t, _now)],
            links: [ChatLink(LinkKind.tasks, tr('কাজের তালিকা'))]);
        final snap = _batchSnap;
        if (snap != null) _offerUndo(snap);
        // "দুপুরে দাওয়াত" next: these to-dos, a time for them (see _batchTimeFor).
        final ids = [for (final t in brain.data.tasks.reversed.take(_batchTaskTitles.length).toList().reversed) t.id];
        _rememberSet('tasks', '', ids, source: _batchTaskTitles.first);
        _batchTasks = (ids, same ? _batchTaskTitles.first : '', _turn);
      } else if (_savedInBatch > 0) {
        _say(out, tr('সব রেখে দিলাম। আর কিছু?'), links: [..._batchLinks]);
        final snap = _batchSnap;
        if (snap != null) _offerUndo(snap);
      }
      _batchSnap = null;
      _allYes = false;
      _savedInBatch = 0;
      _batchTaskTitles.clear();
      _batchLinks.clear();
      _batchKind = null;
    }
  }
}
