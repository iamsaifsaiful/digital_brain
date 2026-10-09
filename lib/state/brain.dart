import 'package:flutter/widgets.dart';

import '../logic/ai_map.dart';
import '../logic/ledger.dart';
import '../logic/parser.dart';
import '../models/models.dart';
import '../services/ai.dart';
import '../services/data_store.dart';
import '../services/files.dart';
import '../services/lock.dart';
import '../services/notifications.dart';
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
    DateTime Function()? clock,
  })  : ai = ai ?? FakeAi(),
        now = clock ?? DateTime.now;

  final DataStore store;
  final LockService lock;
  final Voice voice;
  final Notifier notifier;
  final FileBridge files;

  /// Claude, when the user has set an API key (see আরও).
  final AiBrain ai;
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
      );

  /// What the user meant. The rules always run (offline, instant); when AI
  /// is on, Claude's reading is used instead — except for anything secret,
  /// which never leaves the phone. Returns the command and, if AI failed, a
  /// message to show.
  Future<(Command, String?)> understand(String said) async {
    final rules = Parser(ledger: data.ledger).parse(said);
    if (!aiOn) return (rules, null);
    if (rules is VaultQuery || mentionsSecret(said)) return (rules, null);
    if (rules is SmallTalk && (rules.kind == Talk.time || rules.kind == Talk.date)) return (rules, null);
    try {
      final r = await services.ai.route(said, aiContext());
      if (r == null) return (rules, null);
      return (commandFromAi(said, r, data.ledger) ?? rules, null);
    } on AiError catch (e) {
      return (rules, '${e.message} নিজের নিয়মে বুঝে নিলাম।');
    }
  }

  Future<void> load() async {
    try {
      services.ai.key = await services.lock.keys.read('claude_api_key') ?? '';
    } catch (_) {}
    try {
      services.voice.muted = (await services.lock.keys.read('speak_on')) == 'false';
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

  Future<void> _reschedule() => services.notifier.schedule(plannedNotices(data.reminders, services.now()));

  // ── Generic upsert / remove ──

  void _upsert<T>(List<T> list, T item, String Function(T) id) {
    final i = list.indexWhere((e) => id(e) == id(item));
    if (i >= 0) {
      list[i] = item;
    } else {
      list.add(item);
    }
  }

  Future<void> saveEntry(LedgerEntry e) async {
    _upsert(data.ledger, e, (x) => x.id);
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
