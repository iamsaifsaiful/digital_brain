import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../logic/ai_map.dart';
import '../logic/answers.dart';
import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/ledger.dart';
import '../logic/parser.dart';
import '../logic/plan.dart';
import '../logic/proactive.dart';
import '../models/models.dart';
import '../services/ai.dart';
import '../services/data_store.dart';
import '../services/files.dart';
import '../services/launcher.dart';
import '../services/lock.dart';
import '../services/notifications.dart';
import '../services/phonebook.dart';
import '../services/voice.dart';
import '../services/platform.dart';
import '../logic/calendar_bd.dart';
import '../ui/theme.dart' show Look;
import '../logic/lang.dart';

part 'brain_more.dart';

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
        records: aiShareData ? recordsSummary() : '',
      );

  /// The user lets the AI see their reminders, tasks and notes (never
  /// passwords, PINs or anything secret), so it can answer about them.
  bool aiShareData = true;

  /// What the assistant calls the user ("সাইফুল ভাই"); empty = no name.
  String userName = '';

  /// The place for sunrise, sunset and prayer times (see `bdPlaces`).
  String district = 'ঢাকা';

  Future<void> setUserName(String v) async {
    userName = v.trim();
    await services.lock.keys.write('user_name', userName);
    notifyListeners();
  }

  Future<void> setDistrict(String v) async {
    district = v;
    await services.lock.keys.write('district', v);
    notifyListeners();
  }

  // ── Look and language (সেটিংস › চেহারা, ভাষা) ──

  /// Light, dark, or as the phone is.
  Look look = Look.system;

  /// The accent colour's key (see `accents`).
  String accentKey = 'green';

  /// The app's words in English instead of Bangla.
  bool english = false;

  /// Letter size: 1.0 normal, 1.15 large, 1.3 very large.
  double letterSize = 1.0;

  /// Easy mode: four big buttons, big letters, answers spoken aloud.
  bool easyMode = false;

  /// The user's photo for the profile (kept encrypted on the phone).
  Uint8List? photo;

  Future<void> _put(String key, String value) async {
    try {
      await services.lock.keys.write(key, value);
    } catch (_) {}
  }

  Future<void> setLook(Look v) async {
    look = v;
    notifyListeners();
    await _put('look', v.name);
  }

  Future<void> setAccent(String key) async {
    accentKey = key;
    notifyListeners();
    await _put('accent', key);
  }

  Future<void> setEnglish(bool on) async {
    english = on;
    notifyListeners();
    await _put('lang', on ? 'en' : 'bn');
  }

  Future<void> setLetterSize(double v) async {
    letterSize = v;
    notifyListeners();
    await _put('letter_size', '$v');
  }

  Future<void> setEasyMode(bool on) async {
    easyMode = on;
    if (on && !speakOn) await setSpeakOn(true);
    notifyListeners();
    await _put('easy_mode', on ? 'true' : 'false');
  }

  Future<void> setPhoto(Uint8List? bytes) async {
    photo = bytes;
    notifyListeners();
    if (bytes == null) {
      await services.store.deleteDocFile(_photoId);
    } else {
      await services.store.saveDocFile(_photoId, bytes);
    }
  }

  static const _photoId = 'me-profile-photo';

  /// Read once at start, before the first screen, so it opens in the right look.
  Future<void> loadLook() async {
    try {
      final keys = services.lock.keys;
      final saved = await keys.read('look');
      look = Look.values.firstWhere((l) => l.name == saved, orElse: () => Look.system);
      accentKey = await keys.read('accent') ?? 'green';
      english = (await keys.read('lang')) == 'en';
      letterSize = double.tryParse(await keys.read('letter_size') ?? '') ?? 1.0;
      easyMode = (await keys.read('easy_mode')) == 'true';
    } catch (_) {}
  }

  // ── The assistant speaking first, and modes (সেটিংস › সহকারী) ──

  bool morningOn = true;
  int morningAt = 8 * 60;
  bool nightOn = true;
  int nightAt = 21 * 60;
  bool nudgesOn = true;

  /// Undone to-dos from past days move to today on their own.
  bool carryOver = true;

  /// "ব্যবসায়ী", "চাকরিজীবী", "ছাত্র/ছাত্রী", "গৃহিণী", "অন্য" ('' = not chosen yet).
  String persona = '';

  /// Shop tools in হিসাব: customer dues, today's sales, receipts.
  bool businessMode = false;

  /// A mic button in the notification panel.
  bool panelMic = false;

  /// One-tap questions above the chat box and on Home (the user's own list).
  List<String> quickQuestions = defaultQuestions;
  static const defaultQuestions = ['আজকের কাজের লিস্ট দাও', 'আমার মোট পাওনা কত?', 'আমি কাকে কত দেব?', 'এই মাসে কত খরচ হলো?', 'আজ আমার কী কী আছে?'];

  Future<void> setQuickQuestions(List<String> q) async {
    quickQuestions = q;
    notifyListeners();
    await _put('quick_questions', jsonEncode(q));
  }

  AssistantPrefs get assistantPrefs =>
      AssistantPrefs(morningOn: morningOn, morningAt: morningAt, nightOn: nightOn, nightAt: nightAt, nudgesOn: nudgesOn, name: userName);

  /// One switch or value from the assistant settings, saved and applied.
  Future<void> setPref(String key, Object value) async {
    switch (key) {
      case 'morning_on':
        morningOn = value as bool;
      case 'morning_at':
        morningAt = value as int;
      case 'night_on':
        nightOn = value as bool;
      case 'night_at':
        nightAt = value as int;
      case 'nudges_on':
        nudgesOn = value as bool;
      case 'carry_over':
        carryOver = value as bool;
      case 'persona':
        persona = value as String;
      case 'business_mode':
        businessMode = value as bool;
      case 'panel_mic':
        panelMic = value as bool;
        await _showStanding();
    }
    notifyListeners();
    await _put(key, '$value');
    await _reschedule();
  }

  Future<void> _loadPrefs() async {
    try {
      final keys = services.lock.keys;
      Future<bool> flag(String k, bool or) async {
        final v = await keys.read(k);
        return v == null ? or : v == 'true';
      }

      morningOn = await flag('morning_on', true);
      nightOn = await flag('night_on', true);
      nudgesOn = await flag('nudges_on', true);
      carryOver = await flag('carry_over', true);
      businessMode = await flag('business_mode', false);
      panelMic = await flag('panel_mic', false);
      morningAt = int.tryParse(await keys.read('morning_at') ?? '') ?? 8 * 60;
      nightAt = int.tryParse(await keys.read('night_at') ?? '') ?? 21 * 60;
      persona = await keys.read('persona') ?? '';
      final q = await keys.read('quick_questions');
      if (q != null) quickQuestions = [for (final x in jsonDecode(q) as List) '$x'];
    } catch (_) {}
  }

  Future<void> setAiShareData(bool on) async {
    aiShareData = on;
    await services.lock.keys.write('ai_share_data', on ? 'true' : 'false');
    notifyListeners();
  }

  /// Reminders, to-dos and notes as plain lines for the AI. Anything that
  /// looks like a password or code is left out; vault items never appear.
  String recordsSummary() {
    final now = services.now();
    String d2(int n) => n.toString().padLeft(2, '0');
    String day(DateTime d) => '${d.year}-${d2(d.month)}-${d2(d.day)}';
    final lines = <String>[];
    final mem = data.memories.where((m) => !mentionsSecret(m.text)).take(40).toList();
    if (mem.isNotEmpty) {
      lines.add('What the user asked you to keep in mind about them (use it in answers):');
      for (final m in mem) {
        lines.add('- ${m.text}');
      }
    }
    if (data.specialDays.isNotEmpty) {
      final sd = [...data.specialDays]..sort((a, b) => a.next(now).compareTo(b.next(now)));
      lines.add('Special days (next date): ${sd.take(30).map((x) => '${x.person} ${x.kind.name} ${day(x.next(now))}${x.year == null ? '' : ' (since ${x.year})'}').join('; ')}');
    }
    if (data.habits.isNotEmpty) {
      lines.add('Habits (streak days, done today?): ${data.habits.map((h) => '${h.name} ${h.streak(now)} ${h.doneOn(now) ? 'yes' : 'no'}').join('; ')}');
    }
    if (data.medicines.isNotEmpty) {
      lines.add('Medicines (times, days of stock left): ${data.medicines.map((m) => '${m.name} ${m.times.map((t) => '${d2(t ~/ 60)}:${d2(t % 60)}').join('/')} ${m.daysLeft ?? '-'}').join('; ')}');
    }
    final rem = [...data.reminders]..sort((a, b) => a.nextDate(now).compareTo(b.nextDate(now)));
    if (rem.isNotEmpty) {
      lines.add('Reminders (next date, time, repeat):');
      for (final r in rem.take(50)) {
        final next = r.nextDate(now);
        final passed = r.repeat == Repeat.none && DateTime(next.year, next.month, next.day, r.hour, r.minute).isBefore(now);
        lines.add('- ${r.title} — ${day(next)} ${d2(r.hour)}:${d2(r.minute)}'
            '${r.repeat == Repeat.none ? '' : ' (repeats: ${r.repeat.name})'}${passed ? ' (already rang)' : ''}');
      }
    } else {
      lines.add('Reminders: none saved.');
    }
    final open = data.tasks.where((t) => !t.done).toList();
    if (open.isNotEmpty) {
      lines.add('Open to-dos:');
      for (final t in open.take(60)) {
        lines.add('- ${t.title}${t.due == null ? '' : ' (day: ${day(t.due!)})'}');
      }
    } else {
      lines.add('Open to-dos: none.');
    }
    final doneToday = data.tasks.where((t) => t.done && t.doneAt != null && dayOnly(t.doneAt!) == dayOnly(now)).toList();
    if (doneToday.isNotEmpty) lines.add('Done today: ${doneToday.take(20).map((t) => t.title).join('; ')}');
    final notes = ([...data.notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
        .where((n) => !mentionsSecret('${n.title} ${n.body}'))
        .take(40)
        .toList();
    if (notes.isNotEmpty) {
      lines.add('Notes (category: text):');
      for (final n in notes) {
        final text = (n.body.trim().isEmpty ? n.title : n.body).replaceAll('\n', ' ').trim();
        lines.add('- ${n.category}: ${text.length > 160 ? '${text.substring(0, 160)}…' : text}');
      }
    }
    if (data.docs.isNotEmpty) {
      lines.add('Documents kept (photos/files, opened on the phone): '
          '${data.docs.take(40).map((x) => '${x.title} [${x.folder}]${x.expiry == null ? '' : ' expires ${day(x.expiry!)}'}').join('; ')}');
    }
    lines.add('Contacts saved: ${data.contacts.length} (numbers stay on the phone; the app looks them up).');
    lines.add('Passwords saved: ${data.vault.length} (never shown to you; the app opens them with fingerprint/PIN).');
    return lines.join('\n');
  }

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
    // Listing the saved numbers needs no AI (and numbers never go to it).
    if (rules.length == 1 && rules.first is ContactsQuery) return (rules, null);
    if (rules.length == 1 && rules.first is SmallTalk && {Talk.time, Talk.date}.contains((rules.first as SmallTalk).kind)) {
      return (rules, null);
    }
    try {
      final clean = stripAddress(said).$1;
      final r = await services.ai.route(clean.isEmpty ? said : clean, aiContext(), history: history);
      if (r == null) return (rules, null);
      var cmds = commandsFromAi(said, r, data.ledger);
      // The rules plainly heard "remind me" but the AI read a question about
      // saved reminders: a request wins over a search.
      final ruleReminder = rules.whereType<ReminderAdd>().firstOrNull;
      if (ruleReminder != null && cmds.any((c) => c is ReminderQuery) && !cmds.any((c) => c is ReminderAdd)) {
        cmds = [for (final c in cmds) c is ReminderQuery ? ruleReminder : c];
      }
      return (cmds.isEmpty ? rules : cmds, null);
    } on AiError catch (e) {
      return (rules, '${e.message} নিজের নিয়মে বুঝে নিলাম।');
    }
  }

  Future<void> load() async {
    try {
      services.ai.key = await services.lock.keys.read('claude_api_key') ?? '';
      services.ai.quality = (await services.lock.keys.read('ai_quality')) == 'fast' ? AiQuality.fast : AiQuality.best;
      aiShareData = (await services.lock.keys.read('ai_share_data')) != 'false';
      userName = await services.lock.keys.read('user_name') ?? '';
      district = await services.lock.keys.read('district') ?? 'ঢাকা';
    } catch (_) {}
    try {
      services.voice.muted = (await services.lock.keys.read('speak_on')) == 'false';
      services.notifier.insistent = (await services.lock.keys.read('alarm_insistent')) != 'false';
      services.notifier.soundUri = await services.lock.keys.read('alarm_sound');
      alarmSoundTitle = await services.lock.keys.read('alarm_sound_title') ?? '';
      services.notifier.batteryConfirmed = (await services.lock.keys.read('battery_done')) == 'true';
      services.voice.preferredVoice = await services.lock.keys.read('tts_voice');
    } catch (_) {}
    await loadLook();
    await _loadPrefs();
    try {
      data = await services.store.load();
      loadError = null;
      try {
        photo = await services.store.loadDocFile(_photoId);
      } catch (_) {}
    } catch (e) {
      loadError = '$e';
    }
    loaded = true;
    notifyListeners();
    await carryOverTasks();
    await _reschedule();
    if (loadError == null) await _showStanding();
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

  /// Schedules the phone's notifications again (after a permission change,
  /// and whenever the app comes back): yesterday's undone to-dos move to today first.
  Future<void> refreshNotices() async {
    await carryOverTasks();
    await _reschedule();
  }

  /// The notifications that stay: the emergency card and the panel mic.
  Future<void> _showStanding() async {
    final c = data.emergency;
    await services.notifier.showEmergency(c.onLockScreen && !c.isEmpty ? emergencyText(c) : null);
    await services.notifier.showPanelMic(panelMic, title: 'My Assistant', body: tr('চাপুন, তারপর বলুন — রাখুন, খুঁজুন, জিজ্ঞেস করুন'));
  }

  Future<void> _scheduling = Future.value();

  /// One after another (never two at once), and never before the data is
  /// read: an empty list would cancel every reminder on the phone.
  Future<void> _reschedule() {
    if (!loaded || loadError != null) return Future.value();
    final now = services.now();
    final all = [...plannedNotices(data.reminders, now), ...assistantNotices(data, now, assistantPrefs)];
    _updateWidget(now);
    return _scheduling = _scheduling.then((_) => services.notifier.schedule(all)).catchError((_) {});
  }

  /// The home-screen widget: today's dates and the next few things.
  void _updateWidget(DateTime now) {
    final today = dayOnly(now);
    final rem = [for (final r in data.reminders) if (remindsOn(r, today) && !r.repeat.isInterval) r]
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    final upcoming = rem.where((r) => DateTime(today.year, today.month, today.day, r.hour, r.minute).isAfter(now)).toList();
    final lines = [
      for (final r in upcoming.take(3)) '⏰ ${bnTime(r.hour, r.minute)} ${r.title}',
      for (final t in tasksLeft(data, today).take(3 - (upcoming.length > 3 ? 3 : upcoming.length))) '☐ ${t.title}',
    ];
    final bd = banglaDate(now);
    AppPlatform.updateWidget({
      'date': '${weekdayName(now)}, ${bnDigits(now.day)} ${monthName(now.month)}',
      'bangla': '${bd.text} · ${trf('{0}কাল', [bd.season])}',
      'lines': lines.isEmpty ? tr('আজ কিছু রাখা নেই — মাইক চাপুন, তারপর বলুন') : lines.join('\n'),
    });
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

  // ── Documents ──

  Future<void> saveDoc(Doc d) async {
    _upsert(data.docs, d, (x) => x.id);
    await _save();
  }

  /// Adds a page (photo or file) to [doc], or makes a new document.
  Future<Doc> addDocPage(Doc? doc, PickedDoc f, {String folder = 'অন্যান্য', String? title}) async {
    final file = DocFile(name: f.name, mime: f.mime, size: f.bytes.length);
    await services.store.saveDocFile(file.id, f.bytes);
    final base = doc ?? Doc(title: title ?? folder, folder: folder);
    final d = base.copyWith(files: [...base.files, file]);
    await saveDoc(d);
    return d;
  }

  Future<Doc> removeDocPage(Doc d, DocFile f) async {
    await services.store.deleteDocFile(f.id);
    final next = d.copyWith(files: [for (final x in d.files) if (x.id != f.id) x]);
    await saveDoc(next);
    return next;
  }

  Future<Uint8List?> docBytes(DocFile f) => services.store.loadDocFile(f.id);

  Future<void> deleteDoc(Doc d) async {
    for (final f in d.files) {
      await services.store.deleteDocFile(f.id);
    }
    data.docs.removeWhere((x) => x.id == d.id);
    if (d.reminderId != null) data.reminders.removeWhere((r) => r.id == d.reminderId);
    await _save();
    await _reschedule();
  }

  /// "মেয়াদ শেষের আগে মনে করাও": a reminder a month before [Doc.expiry]
  /// (and on the day), or none.
  Future<Doc> setDocExpiry(Doc d, DateTime? expiry) async {
    if (d.reminderId != null) data.reminders.removeWhere((r) => r.id == d.reminderId);
    var next = d.copyWith(expiry: expiry, clearExpiry: expiry == null, clearReminder: true);
    if (expiry != null) {
      final r = Reminder(title: '${d.title} — মেয়াদ শেষ', date: expiry, hour: 10, daysBefore: 30);
      data.reminders.add(r);
      next = next.copyWith(reminderId: r.id);
    }
    _upsert(data.docs, next, (x) => x.id);
    await _save();
    await _reschedule();
    return next;
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
