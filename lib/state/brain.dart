import 'package:flutter/widgets.dart';

import '../logic/ai_map.dart';
import '../logic/answers.dart';
import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/ledger.dart';
import '../logic/parser.dart';
import '../logic/plan.dart';
import '../models/models.dart';
import '../services/ai.dart';
import '../services/data_store.dart';
import '../services/files.dart';
import '../services/launcher.dart';
import '../services/lock.dart';
import '../services/notifications.dart';
import '../services/phonebook.dart';
import '../services/voice.dart';

/// Everything the screens need from outside Flutter.
class Services {
  Services({
    required this.store,
    required this.lock,
    required this.voice,
    required this.notifier,
    required this.files,
    AiBrain? ai,
    Launcher? launcher,
    Phonebook? phonebook,
    DateTime Function()? clock,
  })  : ai = ai ?? FakeAi(),
        launcher = launcher ?? FakeLauncher(),
        phonebook = phonebook ?? FakePhonebook(),
        now = clock ?? DateTime.now;

  final DataStore store;
  final LockService lock;
  final Voice voice;
  final Notifier notifier;
  final FileBridge files;

  /// Claude, when the user has set an API key (see আরও).
  final AiBrain ai;

  /// Dialer, SMS and WhatsApp.
  final Launcher launcher;

  /// The phone's own contacts.
  final Phonebook phonebook;
  final DateTime Function() now;
}

/// The data in memory, saved (encrypted) after every change.
class Brain extends ChangeNotifier {
  Brain(this.services);

  final Services services;
  AppData data = AppData();
  bool loaded = false;
  String? loadError;

  /// True between the user unlocking and the app locking again.
  bool unlocked = false;

  /// When the user last proved it was them (PIN or fingerprint), for the
  /// vault's short grace period.
  DateTime? lastVerified;

  bool get speakOn => !services.voice.muted;

  Future<void> setSpeakOn(bool on) async {
    services.voice.muted = !on;
    if (!on) await services.voice.stopSpeaking();
    await services.lock.keys.write('speak_on', on ? 'true' : 'false');
    notifyListeners();
  }

  Future<void> setVoice(VoiceOption? v) async {
    await services.voice.useVoice(v);
    if (v == null) {
      await services.lock.keys.delete('tts_voice');
    } else {
      await services.lock.keys.write('tts_voice', v.name);
    }
    notifyListeners();
  }

  /// Reminders keep ringing until seen.
  bool get alarmInsistent => services.notifier.insistent;

  Future<void> setAlarmInsistent(bool on) async {
    services.notifier.insistent = on;
    await services.lock.keys.write('alarm_insistent', on ? 'true' : 'false');
    notifyListeners();
    await _reschedule();
  }

  /// The ringtone's name ('' = the phone's alarm tone).
  String alarmSoundTitle = '';

  /// A ringtone the user picked; null goes back to the alarm tone.
  Future<void> setAlarmSound(String? uri, String title) async {
    if (uri == null || uri == 'content://settings/system/alarm_alert') {
      services.notifier.soundUri = null;
      alarmSoundTitle = '';
      await services.lock.keys.delete('alarm_sound');
      await services.lock.keys.delete('alarm_sound_title');
    } else {
      services.notifier.soundUri = uri;
      alarmSoundTitle = title;
      await services.lock.keys.write('alarm_sound', uri);
      await services.lock.keys.write('alarm_sound_title', title);
    }
    notifyListeners();
    await _reschedule();
  }

  /// "করেছি": the phone's own battery page now says no restrictions.
  Future<void> confirmBattery() async {
    services.notifier.batteryConfirmed = true;
    await services.lock.keys.write('battery_done', 'true');
    notifyListeners();
  }

  bool get aiOn => services.ai.key.trim().isNotEmpty;

  Future<void> setAiKey(String key) async {
    services.ai.key = key.trim();
    if (key.trim().isEmpty) {
      await services.lock.keys.delete('claude_api_key');
    } else {
      await services.lock.keys.write('claude_api_key', key.trim());
    }
    notifyListeners();
  }

  AiContext aiContext() => AiContext(
        now: services.now(),
        people: knownPeople(data.ledger).take(60).toList(),
        categories: data.noteCategories,
        money: moneySummary(),
      );

  /// Money facts the AI may use to answer and advise (amounts and names only).
  String moneySummary() {
    final now = services.now();
    final lines = <String>[];
    final owed = balances(data.ledger).where((p) => p.balance != 0).take(40).toList();
    if (owed.isNotEmpty) {
      final t = totals(data.ledger);
      lines.add('Loans: others owe the user ${t.receivable} taka in total, the user owes ${t.payable} taka.');
      lines.add(owed.map((p) => '${p.name}: ${p.balance > 0 ? 'owes the user' : 'the user owes'} ${p.balance.abs()}').join('; '));
    }
    final m = monthSums(data.cash, now);
    if (m.income > 0 || m.expense > 0) {
      lines.add('This month: income ${m.income}, spending ${m.expense}, balance ${m.balance}.'
          '${m.topExpenses.isEmpty ? '' : ' Spending by category: ${m.topExpenses.take(10).map((e) => '${e.key} ${e.value}').join(', ')}.'}');
    }
    final prev = monthSums(data.cash, DateTime(now.year, now.month - 1));
    if (prev.income > 0 || prev.expense > 0) lines.add('Last month: income ${prev.income}, spending ${prev.expense}.');
    for (final p in data.projects.where((p) => !p.closed).take(10)) {
      final s = projectSums(data.cash, p.id);
      lines.add('Project ${p.name}: received ${s.income}, spent ${s.expense}, left ${s.balance}.');
    }
    return lines.join('\n');
  }

  bool get aiBest => services.ai.quality == AiQuality.best;

  Future<void> setAiBest(bool on) async {
    services.ai.quality = on ? AiQuality.best : AiQuality.fast;
    await services.lock.keys.write('ai_quality', on ? 'best' : 'fast');
    notifyListeners();
  }

  /// What the user meant. The rules always run (offline, instant); when AI
  /// is on, Claude's reading is used instead — except for anything secret,
  /// which never leaves the phone. Returns the command and, if AI failed, a
  /// message to show.
  Future<(Command, String?)> understand(String said) async {
    final (cmds, problem) = await understandAll(said);
    return (cmds.first, problem);
  }

  /// Like [understand], for a chat: a long message may hold several things
  /// (never empty). [history] is the conversation so far, already cleaned
  /// of anything private.
  Future<(List<Command>, String?)> understandAll(String said, {List<AiTurn> history = const []}) async {
    final rules = parseAll(said, data.ledger, tasks: data.tasks, contacts: data.contacts, now: services.now());
    if (!aiOn) return (rules, null);
    if (mentionsSecret(said) || rules.any((c) => c is VaultQuery)) return (rules, null);
    if (rules.length == 1 && rules.first is SmallTalk && {Talk.time, Talk.date}.contains((rules.first as SmallTalk).kind)) {
      return (rules, null);
    }
    try {
      final clean = stripAddress(said).$1;
      final r = await services.ai.route(clean.isEmpty ? said : clean, aiContext(), history: history);
      if (r == null) return (rules, null);
      final cmds = commandsFromAi(said, r, data.ledger);
      return (cmds.isEmpty ? rules : cmds, null);
    } on AiError catch (e) {
      return (rules, '${e.message} নিজের নিয়মে বুঝে নিলাম।');
    }
  }

  Future<void> load() async {
    try {
      services.ai.key = await services.lock.keys.read('claude_api_key') ?? '';
      services.ai.quality = (await services.lock.keys.read('ai_quality')) == 'fast' ? AiQuality.fast : AiQuality.best;
    } catch (_) {}
    try {
      services.voice.muted = (await services.lock.keys.read('speak_on')) == 'false';
      services.notifier.insistent = (await services.lock.keys.read('alarm_insistent')) != 'false';
      services.notifier.soundUri = await services.lock.keys.read('alarm_sound');
      alarmSoundTitle = await services.lock.keys.read('alarm_sound_title') ?? '';
      services.notifier.batteryConfirmed = (await services.lock.keys.read('battery_done')) == 'true';
      services.voice.preferredVoice = await services.lock.keys.read('tts_voice');
    } catch (_) {}
    try {
      data = await services.store.load();
      loadError = null;
    } catch (e) {
      loadError = '$e';
    }
    loaded = true;
    notifyListeners();
    await _reschedule();
  }

  void unlock() {
    unlocked = true;
    lastVerified = services.now();
    notifyListeners();
  }

  void lockNow() {
    unlocked = false;
    lastVerified = null;
    notifyListeners();
  }

  void markVerified() {
    lastVerified = services.now();
  }

  /// Verified within the last [seconds]?
  bool recentlyVerified([int seconds = 30]) {
    final t = lastVerified;
    return t != null && services.now().difference(t).inSeconds < seconds;
  }

  Future<void> _save() async {
    notifyListeners();
    await services.store.save(data);
  }

  /// Schedules the phone's notifications again (after a permission change).
  Future<void> refreshNotices() => _reschedule();

  Future<void> _scheduling = Future.value();

  /// One after another (never two at once), and never before the data is
  /// read: an empty list would cancel every reminder on the phone.
  Future<void> _reschedule() {
    if (!loaded || loadError != null) return Future.value();
    return _scheduling = _scheduling.then((_) => services.notifier.schedule(plannedNotices(data.reminders, services.now()))).catchError((_) {});
  }

  // ── Generic upsert / remove ──

  void _upsert<T>(List<T> list, T item, String Function(T) id) {
    final i = list.indexWhere((e) => id(e) == id(item));
    if (i >= 0) {
      list[i] = item;
    } else {
      list.add(item);
    }
  }

  /// Saves a ধার-দেনা entry. Said without a number ("রহিমকে ৫০০ দিলাম"), it
  /// goes to the রহিম used most recently. A new number is also kept in
  /// যোগাযোগ, so the person can be called from either place.
  Future<void> saveEntry(LedgerEntry e, {bool guessPhone = true}) async {
    var x = e;
    if (guessPhone && phoneKey(x.phone).isEmpty) {
      final p = balanceOf(data.ledger.where((o) => o.id != x.id), x.person);
      if (p != null && p.phone.isNotEmpty) x = x.copyWith(phone: p.phone);
    }
    _upsert(data.ledger, x, (y) => y.id);
    final pk = phoneKey(x.phone);
    if (pk.isNotEmpty && !data.contacts.any((c) => phoneKey(c.phone) == pk)) {
      data.contacts.add(Contact(name: x.person.trim(), phone: asciiDigits(x.phone.trim()), note: 'লেনদেন', updatedAt: services.now()));
    }
    await _save();
  }

  Future<void> deleteEntry(String id) async {
    data.ledger.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> saveVault(VaultItem v) async {
    _upsert(data.vault, v, (x) => x.id);
    await _save();
  }

  Future<void> deleteVault(String id) async {
    data.vault.removeWhere((e) => e.id == id);
    for (var i = 0; i < data.reminders.length; i++) {
      final r = data.reminders[i];
      if (r.vaultId == id) {
        data.reminders[i] = Reminder(
            id: r.id,
            title: r.title,
            date: r.date,
            hour: r.hour,
            minute: r.minute,
            daysBefore: r.daysBefore,
            repeat: r.repeat,
            note: r.note);
      }
    }
    await _save();
  }

  Future<void> saveContact(Contact c) async {
    _upsert(data.contacts, c, (x) => x.id);
    await _save();
  }

  /// Brings every number from the phone book, leaving out numbers already
  /// kept (and repeats inside the phone book). Returns (added, left out), or
  /// null when the user did not allow reading contacts.
  Future<(int, int)?> importPhonebook() async {
    final list = await services.phonebook.readAll();
    if (list == null) return null;
    final seen = <String>{for (final c in data.contacts) phoneKey(c.phone)}..remove('');
    var added = 0, skipped = 0;
    final now = services.now();
    for (final pc in list) {
      final number = asciiDigits(pc.phone).replaceAll(RegExp(r'[^0-9+]'), '');
      final k = phoneKey(number);
      if (k.length < 6) continue;
      if (!seen.add(k)) {
        skipped++;
        continue;
      }
      final name = pc.name.trim().isEmpty ? bnDigits(number) : pc.name.trim();
      data.contacts.add(Contact(name: name, phone: number, updatedAt: now));
      added++;
    }
    if (added > 0) await _save();
    return (added, skipped);
  }

  Future<void> deleteContact(String id) async {
    data.contacts.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> saveNote(Note n) async {
    _upsert(data.notes, n, (x) => x.id);
    await _save();
  }

  Future<void> deleteNote(String id) async {
    data.notes.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> saveReminder(Reminder r) async {
    _upsert(data.reminders, r, (x) => x.id);
    await _save();
    await services.notifier.requestPermission();
    await _reschedule();
  }

  Future<void> deleteReminder(String id) async {
    data.reminders.removeWhere((e) => e.id == id);
    await _save();
    await _reschedule();
  }

  Future<void> saveTask(Task t) async {
    _upsert(data.tasks, t, (x) => x.id);
    await _save();
  }

  Future<void> deleteTask(String id) async {
    data.tasks.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> setTaskDone(Task t, bool done) => saveTask(t.copyWith(done: done, doneAt: done ? services.now() : null));

  List<Task> openTasks() => openTasksOf(data, services.now());

  Future<void> saveCash(CashEntry e) async {
    _upsert(data.cash, e, (x) => x.id);
    await _save();
  }

  Future<void> deleteCash(String id) async {
    data.cash.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> saveProject(Project p) async {
    _upsert(data.projects, p, (x) => x.id);
    await _save();
  }

  /// Removes a project and its entries.
  Future<void> deleteProject(String id) async {
    data.projects.removeWhere((e) => e.id == id);
    data.cash.removeWhere((e) => e.projectId == id);
    await _save();
  }

  /// The project called [name], made if there is none yet.
  Future<Project> projectNamed(String name) async {
    final p = projectByName(data, name);
    if (p != null) return p;
    final created = Project(name: name.trim(), createdAt: services.now());
    await saveProject(created);
    return created;
  }

  /// Replaces everything with a restored backup.
  Future<void> replaceAll(AppData restored) async {
    data = restored;
    await _save();
    await _reschedule();
  }

  VaultItem? vaultById(String? id) {
    if (id == null) return null;
    for (final v in data.vault) {
      if (v.id == id) return v;
    }
    return null;
  }

  Reminder? reminderById(String id) {
    for (final r in data.reminders) {
      if (r.id == id) return r;
    }
    return null;
  }
}

/// Gives every screen the [Brain] and rebuilds them when it changes.
class BrainScope extends InheritedNotifier<Brain> {
  const BrainScope({super.key, required Brain brain, required super.child}) : super(notifier: brain);

  static Brain of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<BrainScope>()!.notifier!;

  /// Without listening (for callbacks).
  static Brain read(BuildContext context) => context.getInheritedWidgetOfExactType<BrainScope>()!.notifier!;
}
