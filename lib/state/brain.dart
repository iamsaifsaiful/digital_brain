import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';

import '../logic/vault_age.dart';
import '../logic/steps.dart' show StepBook, stepDay;
import '../logic/ai_safe.dart';
import '../logic/doc_dates.dart';
import 'doc_scan.dart' show mergeFields;
import '../services/health_connect.dart';
import '../logic/health_connect.dart';
import '../services/error_log.dart';
import '../services/weather.dart';
import '../services/compass.dart';
import '../logic/weather.dart';
import '../services/ocr.dart';
import '../services/trace.dart';

import '../logic/ai_map.dart';
import '../logic/app_map.dart';
import '../logic/ask.dart';
import '../logic/money_more.dart' show GoldPiece, ZakatSaved, MetalPrice;
import '../logic/manage.dart';
import '../logic/me.dart';
import '../logic/phrases.dart' show possessive;
import '../logic/answers.dart';
import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/health.dart';
import '../logic/ledger.dart';
import '../nlu/labels.dart';
import 'family_state.dart';
import '../nlu/reader.dart' show NluPiece;
import '../nlu/router.dart';
import '../nlu/samples.dart' show nluAppVersion, nluConsentVer, delexicalize;
import '../nlu/updater.dart';
import 'package:path_provider/path_provider.dart';
import '../logic/parser.dart';
import '../logic/plan.dart';
import '../logic/proactive.dart';
import '../logic/pro.dart';
import '../logic/notice_log.dart';
import '../logic/server_notices.dart';
import '../models/models.dart';
import '../services/ai.dart';
import '../services/community.dart';
import '../services/crypto.dart' show WrongKey;
import '../services/data_store.dart';
import '../services/files.dart';
import '../services/google_account.dart';
import '../services/push.dart';
import '../services/launcher.dart';
import '../services/lock.dart';
import '../services/notifications.dart';
import '../services/phonebook.dart';
import '../services/voice.dart';
import '../services/platform.dart';
import '../services/location_share.dart';
import '../logic/calendar_bd.dart';
import '../logic/holidays_abroad.dart' show builtInHolidays;
import '../logic/meal.dart';
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
    GoogleAccount? google,
    PushSource? push,
    DriveStore? drive,
    AccountServer? server,
    TextReader? ocr,
    WeatherSource? weather,
    CompassSource? compass,
    HealthConnectSource? health,
    DateTime Function()? clock,
  })  : ai = ai ?? FakeAi(),
        health = health ?? FakeHealthConnect(),
        ocr = ocr ?? FakeTextReader(),
        weather = weather ?? FakeWeather(),
        compass = compass ?? FakeCompass(),
        google = google ?? FakeGoogle(),
        push = push ?? FakePush(),
        drive = drive ?? FakeDrive(),
        server = server ?? AccountServer.off(),
        launcher = launcher ?? FakeLauncher(),
        phonebook = phonebook ?? FakePhonebook(),
        now = clock ?? DateTime.now;

  final DataStore store;
  final LockService lock;
  final Voice voice;
  final Notifier notifier;
  final FileBridge files;

  /// Reads the printed text in a photo, on the phone (a paper's expiry date).
  final TextReader ocr;

  /// Today's weather (temperature on the home page and in answers).
  final WeatherSource weather;

  /// The phone's heading, for the compass page.
  final CompassSource compass;

  /// Android's Health Connect, read only (steps, sleep, exercise for "আমি").
  final HealthConnectSource health;

  /// Claude, when the user has set an API key (see আরও).
  final AiBrain ai;

  /// Dialer, SMS and WhatsApp.
  final Launcher launcher;

  /// The phone's own contacts.
  final Phonebook phonebook;

  /// Messages from other apps' notifications.

  /// Google sign-in, the app's Drive folder, and our account server.
  final GoogleAccount google;
  final DriveStore drive;
  final AccountServer server;
  final PushSource push;
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

  /// Unlocked at least once since this brain started: later locks cover the
  /// open pages instead of closing them (app.dart, _LockCover).
  bool unlockedOnce = false;

  /// A ringing reminder's page is open (also over the PIN): the lock asks
  /// for no fingerprint meanwhile, so the page's buttons work at once (owner,
  /// 26 Oct: "বন্ধ করতে ক্লিক করলে … লগইন স্কিন আসে").
  bool alarmOpen = false;

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
  /// [own]: a file the member added (copied by the app) — the one added
  /// before is removed once it is no longer the tone.
  Future<void> setAlarmSound(String? uri, String title, {bool own = false}) async {
    final ownBefore = await services.lock.keys.read('alarm_sound_own');
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
    if (ownBefore != null && ownBefore != uri) {
      await services.notifier.removeOwnSound(ownBefore);
      await services.lock.keys.delete('alarm_sound_own');
    }
    if (own && uri != null) await services.lock.keys.write('alarm_sound_own', uri);
    notifyListeners();
    await _reschedule();
  }

  /// "করেছি": the phone's own battery page now says no restrictions.
  Future<void> confirmBattery() async {
    services.notifier.batteryConfirmed = true;
    await services.lock.keys.write('battery_done', 'true');
    notifyListeners();
  }

  /// The user's own API key works only in the downloaded APK. The Play app
  /// has no key field: its AI will come through our server, for Pro.
  bool get aiOn => (!gated && services.ai.key.trim().isNotEmpty) || aiByServer;

  /// AI through our server: signed in, the server's AI is on, and the
  /// server has this account as Pro or on trial (the server decides, not the phone).
  bool get aiByServer => services.ai.session.isNotEmpty && serverAi && (serverProUntil?.isAfter(services.now()) ?? false);

  bool serverAi = false;
  int aiLeft = 0;
  DateTime? serverProUntil;

  // ── Pro (sold only in the Play Store app; see logic/pro.dart) ──

  /// Premium features are locked until the member has Premium (every build
  /// given out; see logic/pro.dart).
  bool get gated => _gated;
  bool _gated = gatedEdition;
  set gated(bool v) {
    _gated = v;
    notifyListeners();
  }

  /// Pro lasts until this moment.
  DateTime? proUntil;

  /// 'play:pro_yearly' (Google Play), what our server says ('web', 'bkash',
  /// 'manual', 'trial'), or 'test' (an internal test build).
  String proKind = '';

  /// The first day the app was opened (no full-screen ad that day).
  DateTime? firstUse;

  /// Premium bought (Google Play or our server), not the trial.
  bool get paidPro => proUntil != null && services.now().isBefore(proUntil!);

  /// Seven days of Premium from the first open (owner, 28 Oct). After that,
  /// without buying, the Premium tools stop; everything kept stays (logic/pro.dart).
  static const trialDays = 7;
  DateTime? trialStart;
  DateTime? get trialEnds => trialStart?.add(const Duration(days: trialDays));
  bool get onTrial => gated && !paidPro && trialEnds != null && services.now().isBefore(trialEnds!);
  bool get trialOver => gated && !paidPro && trialEnds != null && !services.now().isBefore(trialEnds!);

  bool get pro => !gated || paidPro || onTrial;
  bool get showAds => gated && !pro;

  /// The preview draws sample ad spaces (real ads need AdMob).
  bool adSamples = previewEdition;
  bool has(ProFeature f) => pro || freeFeatures.contains(f);
  bool get canAddShop => true;
  bool get canAddProject => pro || data.projects.where((p) => !p.closed).length < freeProjects;

  /// The one অন্যান্য হিসাব the free app writes into (owner, 29 Oct): the
  /// first one opened that is still open. Others (from Premium or the trial)
  /// stay readable, editable and deletable; new entries in them need Premium.
  String? get freeProjectId {
    final open = data.projects.where((p) => !p.closed).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return open.isEmpty ? null : open.first.id;
  }

  /// Writing into the হিসাব [id].
  bool canUseProject(String id) => pro || id == freeProjectId;

  /// Writing into the হিসাব named [name], or opening it when there is none.
  bool canUseProjectNamed(String name) {
    final p = projectByName(data, name);
    return p == null ? canAddProject : canUseProject(p.id);
  }
  bool get canAddVault => pro || data.vault.length < freeVaultItems;
  bool get canAddDoc => pro || data.docs.length < freeDocs;

  /// Reminders that still ring (the app's own ones — bills, papers, habits —
  /// count too). Medicine and vaccine reminders never count (owner, 29 Oct:
  /// health is never held back for Premium).
  int get activeReminders {
    final health = {for (final m in data.medicines) ...m.reminderIds, for (final p in data.members) ...p.vaccineReminders};
    return data.reminders.where((r) => r.enabled && r.vaultId == null && !health.contains(r.id)).length;
  }
  bool get canAddReminder => pro || activeReminders < freeReminders;

  /// A new person in ধার-দেনা (someone already there is always fine).
  bool canAddPerson(String name) {
    if (has(ProFeature.people)) return true;
    final key = personKey(name);
    final people = {for (final e in data.ledger) personKey(e.person)};
    return people.contains(key) || people.length < freeLedgerPeople;
  }

  /// The first month of the reports a free user can open ([freeReportMonths] back).
  DateTime get firstFreeMonth {
    final n = services.now();
    return DateTime(n.year, n.month - (freeReportMonths - 1));
  }

  bool canSeeMonth(DateTime m) => has(ProFeature.history) || !DateTime(m.year, m.month).isBefore(firstFreeMonth);

  /// After Google Play confirms a purchase ('play:' + the plan; an internal
  /// test build's button uses it too). Only these stand without our server.
  Future<void> activatePro(ProPlan plan) => _setPro(services.now().add(Duration(days: plan.days)), 'play:${plan.id}');

  /// The preview's test switch.
  Future<void> setProForTest(bool on) => on ? _setPro(services.now().add(const Duration(days: 365)), 'test') : _setPro(null, '');

  /// One-off notifications planned by the app itself ("প্রিমিয়াম চালু হয়েছে").
  final _oneOff = <PlannedNotice>[];

  Future<void> _setPro(DateTime? until, String kind, {bool announce = true}) async {
    final wasPro = pro;
    proUntil = until;
    proKind = kind;
    final keys = services.lock.keys;
    try {
      if (until == null) {
        await keys.delete('pro_until');
      } else {
        await keys.write('pro_until', until.toIso8601String());
      }
      await keys.write('pro_kind', kind);
    } catch (_) {}
    if (!wasPro && pro) {
      await _addProReminders();
      // A notification that Pro is on (our server pushes one itself when
      // the phone can get pushes — then not twice).
      if (announce && gated) {
        _oneOff.add(PlannedNotice(
          id: stableId('pro-on'),
          at: services.now().add(const Duration(seconds: 5)),
          title: tr('প্রিমিয়াম চালু হয়েছে'),
          body: tr('রিমাইন্ডার, ব্যাকআপ, ফ্যামিলি — সব প্রিমিয়াম সুবিধা এখন চালু। ধন্যবাদ!'),
          reminderId: 'nudge:pro',
          gentle: true,
        ));
      }
    }
    notifyListeners();
    await _reschedule();
  }

  /// Pro just came on: the pay-back days and paper expiries already written
  /// get their reminders now.
  Future<void> _addProReminders() async {
    var changed = false;
    final today = dayOnly(services.now());
    for (var i = 0; i < data.ledger.length; i++) {
      final x = data.ledger[i];
      if (x.reminderId != null || x.due == null || x.due!.isBefore(today)) continue;
      if (x.kind != LedgerKind.lent && x.kind != LedgerKind.borrowed) continue;
      final r = _dueReminder(x);
      data.reminders.add(r);
      data.ledger[i] = x.copyWith(reminderId: r.id);
      changed = true;
    }
    for (var i = 0; i < data.docs.length; i++) {
      final d = data.docs[i];
      if (d.reminderId != null || d.expiry == null || d.expiry!.isBefore(today)) continue;
      final r = _expiryReminder(d);
      data.reminders.add(r);
      data.docs[i] = d.copyWith(reminderId: r.id);
      changed = true;
    }
    if (changed) await _save();
  }

  Reminder _dueReminder(LedgerEntry x) => Reminder(
      title: x.projectId != null
          ? (x.kind == LedgerKind.lent ? trf('{0} {1} বকেয়া দেওয়ার দিন', [x.person, taka(x.amount)]) : trf('{0}-কে {1} বকেয়া শোধের দিন', [x.person, taka(x.amount)]))
          : x.kind == LedgerKind.lent
              ? trf('{0} {1} ফেরত দেওয়ার দিন', [x.person, taka(x.amount)])
              : trf('{0}-কে {1} শোধের দিন', [x.person, taka(x.amount)]),
      date: dayOnly(x.due!),
      hour: 10,
      daysBefore: 1);

  /// The bell on ধার-দেনা (owner, 28 Oct, like the to-do list's): a reminder at
  /// [at] for money owed when no pay date was given — it becomes the pay date.
  /// The one set before for the same entry is replaced.
  Future<Reminder> remindLedger(LedgerEntry e, DateTime at) async {
    final old = e.reminderId;
    if (old != null) data.reminders.removeWhere((r) => r.id == old);
    final r = Reminder(
        title: e.projectId != null
            ? (e.kind == LedgerKind.lent ? trf('{0}-এর কাছে {1} বকেয়া — তাগাদা দিন', [e.person, taka(e.amount)]) : trf('{0}-কে {1} বকেয়া শোধ করার কথা', [e.person, taka(e.amount)]))
            : e.kind == LedgerKind.lent
                ? trf('{0}-এর কাছে {1} পাওনা — তাগাদা দিন', [e.person, taka(e.amount)])
                : trf('{0}-কে {1} শোধ করার কথা', [e.person, taka(e.amount)]),
        date: dayOnly(at),
        hour: at.hour,
        minute: at.minute);
    data.reminders.add(r);
    _upsert(data.ledger, e.copyWith(due: dayOnly(at), reminderId: r.id), (y) => y.id);
    await _save();
    await _reschedule();
    return r;
  }

  /// The reminder set on someone's money (the bell shows it), if any still to ring.
  Reminder? ledgerReminderOf(String accountKey) {
    final keys = accountKeys(data.ledger);
    return ledgerReminderIn([for (final e in data.ledger) if (keys[e.id] == accountKey) e]);
  }

  /// The same for any one person's entries (also a হিসাব's বকেয়া).
  Reminder? ledgerReminderIn(Iterable<LedgerEntry> lines) {
    final now = services.now();
    for (final e in lines.toList().reversed) {
      if (e.reminderId == null) continue;
      final r = data.reminders.where((x) => x.id == e.reminderId && x.enabled).firstOrNull;
      if (r != null && !r.nextDate(now).isBefore(dayOnly(now))) return r;
    }
    return null;
  }

  Reminder _expiryReminder(Doc d) => Reminder(title: '${d.title} — মেয়াদ শেষ', date: d.expiry!, hour: 10, daysBefore: 30);

  Future<void> _loadPro() async {
    final keys = services.lock.keys;
    try {
      proUntil = DateTime.tryParse(await keys.read('pro_until') ?? '');
      proKind = await keys.read('pro_kind') ?? '';
      // Premium turned on by the old preview's test switch or button (no
      // payment; there is no Play billing yet): gone in a build given out —
      // the member's data all stays.
      if (!proTestSwitch && (proKind == 'test' || proPlans.any((p) => p.id == proKind))) {
        proUntil = null;
        proKind = '';
        await keys.delete('pro_until');
        await keys.delete('pro_kind');
      }
      // The trial starts the first time this version (or a later one) opens —
      // members from before get their seven days too, once.
      trialStart = DateTime.tryParse(await keys.read('trial_start') ?? '');
      if (trialStart == null) {
        trialStart = services.now();
        await keys.write('trial_start', trialStart!.toIso8601String());
      }
      firstUse = DateTime.tryParse(await keys.read('first_use') ?? '');
      if (firstUse == null) {
        firstUse = services.now();
        await keys.write('first_use', firstUse!.toIso8601String());
      }
    } catch (_) {}
  }

  // ── Google account and Drive backup (see services/google_account.dart) ──

  /// Signed in on the welcome page: after the PIN, look for a Drive backup.
  bool offerRestore = false;

  String googleEmail = '';
  String googleName = '';
  bool get signedIn => googleEmail.isNotEmpty;

  /// Automatic backup to the app's hidden Google Drive folder is on.
  bool driveOn = false;
  DateTime? lastDrive;
  bool driveBusy = false;

  /// Something changed since the last Drive backup.
  bool _driveDirty = false;

  static const _drivePrefix = 'my-assistant-backup';

  Future<void> _loadAccount() async {
    final keys = services.lock.keys;
    try {
      googleEmail = await keys.read('g_email') ?? '';
      googleName = await keys.read('g_name') ?? '';
      driveOn = (await keys.read('drive_on')) == 'true';
      lastDrive = DateTime.tryParse(await keys.read('drive_last') ?? '');
      _driveDirty = (await keys.read('drive_dirty')) == 'true';
      services.ai.session = await keys.read('srv_session') ?? '';
      serverAi = (await keys.read('srv_ai')) == 'true';
      serverProUntil = DateTime.tryParse(await keys.read('srv_pro_until') ?? '');
      final ai = services.ai;
      if (ai is ClaudeAi) ai.proxy = services.server.aiUrl;
    } catch (_) {}
  }

  /// Google's account picker. Returns a message when it did not work.
  Future<String?> signInGoogle({String appVersion = ''}) async {
    try {
      final u = await services.google.signIn();
      if (u == null) return null;
      googleEmail = u.email;
      googleName = u.name;
      final keys = services.lock.keys;
      await keys.write('g_email', u.email);
      await keys.write('g_name', u.name);
      if (userName.isEmpty && u.name.trim().isNotEmpty) await setUserName(u.name.trim().split(' ').first);
      final info = await services.server.login(u, appVersion: appVersion, edition: edition);
      if (info != null) await _applyServer(info);
      if (info != null) {
        final until = info.proUntil;
        if (until != null && until.isAfter(services.now()) && (proUntil == null || until.isAfter(proUntil!))) {
          await _setPro(until, info.proKind, announce: await _noPush());
        }
      }
      notifyListeners();
      return null;
    } on UpdateRequired catch (e) {
      // Signed in to Google, but our site wants a newer app first (its data here stays open).
      updateUrl = e.url;
      notifyListeners();
      return trf('অ্যাপের নতুন সংস্করণ ({0}) এসেছে — আপডেট করে আবার লগইন করুন। ফোনে রাখা সব তথ্য আগের মতোই খোলা থাকবে।', [e.min]);
    } on GoogleError catch (e) {
      return e.message;
    } catch (e) {
      return 'Google লগইন হয়নি: $e';
    }
  }

  /// Where the newer app is, when our site asked for one at sign-in.
  String updateUrl = '';

  /// "PIN ভুলে গেছেন?" on a signed-in phone: the owner picks the same Google
  /// account and our server checks Google's token. Null when it is them.
  Future<String?> confirmGoogleOwner() async {
    if (!signedIn) return 'এই ফোনে Google অ্যাকাউন্ট যুক্ত নেই';
    try {
      final u = await services.google.signIn();
      if (u == null) return '';
      if (u.email.toLowerCase() != googleEmail.toLowerCase()) return 'এটা অন্য Google অ্যাকাউন্ট — অ্যাপে যুক্ত অ্যাকাউন্টটা ($googleEmail) বেছে নিন';
      final info = await services.server.login(u, appVersion: '', edition: edition);
      if (info == null) return 'সার্ভারে যাচাই করা যায়নি — ইন্টারনেট দেখে আবার চেষ্টা করুন';
      await _applyServer(info);
      return null;
    } on GoogleError catch (e) {
      return e.message;
    } catch (e) {
      return 'যাচাই করা যায়নি: $e';
    }
  }

  /// What the server said: the session for AI, whether its AI is on, and the plan.
  Future<void> _applyServer(AccountInfo info) async {
    final keys = services.lock.keys;
    final ai = services.ai;
    if (ai is ClaudeAi) ai.proxy = services.server.aiUrl;
    if (info.session.isNotEmpty) {
      ai.session = info.session;
      await keys.write('srv_session', info.session);
      await keys.delete('push_sent');
    }
    await _sendPushToken();
    serverAi = info.ai;
    aiLeft = info.aiLeft;
    feedbackUnread = info.feedbackUnread;
    // The Drive backup is locked with the account's key from our server (no password to remember).
    if (info.backupKey.isNotEmpty && await keys.read('drive_pw') != info.backupKey) {
      await keys.write('drive_pw', info.backupKey);
      await keys.write('drive_key_server', 'true');
    }
    serverProUntil = info.proUntil;
    await keys.write('srv_ai', serverAi ? 'true' : 'false');
    if (info.proUntil == null) {
      await keys.delete('srv_pro_until');
    } else {
      await keys.write('srv_pro_until', info.proUntil!.toIso8601String());
    }
    // Our server decides Premium (owner's review, 27 Oct): given on the
    // website, by bKash or by an admin shows up here — and taken back here
    // too. Only a Google Play purchase on this phone ('play…') stands on its own.
    final until = info.proUntil;
    final live = until != null && until.isAfter(services.now()) ? until : null;
    if (gated && !proKind.startsWith('play') && (live != proUntil || (live != null && proKind != info.proKind))) {
      await _setPro(live, live == null ? '' : info.proKind, announce: await _noPush());
    }
    notifyListeners();
  }

  /// This phone cannot get our pushes (no Firebase), so the app says it itself.
  Future<bool> _noPush() async {
    try {
      final t = await services.push.token();
      return t == null || t.isEmpty;
    } catch (_) {
      return true;
    }
  }

  /// The phone's push token to the server, when it is new for this session.
  Future<void> _sendPushToken() async {
    final session = services.ai.session;
    if (session.isEmpty) return;
    final token = await services.push.token();
    if (token == null || token.isEmpty) return;
    final keys = services.lock.keys;
    if (await keys.read('push_sent') == token) return;
    if (await services.server.device(session, token)) await keys.write('push_sent', token);
  }

  /// Asks the server for the plan now (on opening the app, at most every few hours).
  DateTime? _refreshedAt;

  /// Notifications written on our website (planned with the assistant's own).
  List<ServerNotice> serverNoticeList = const [];

  /// The admin's rules for the app's own notifications (on/off, time, wording, who).
  NoticeRules noticeRules = NoticeRules.none;

  Future<void> _loadServerNotices() async {
    try {
      final rules = await services.lock.keys.read('srv_note_rules');
      if (rules != null) noticeRules = NoticeRules.fromJson(jsonDecode(rules));
      final raw = await services.lock.keys.read('srv_notices');
      if (raw == null) return;
      serverNoticeList = [...(jsonDecode(raw) as List).map(ServerNotice.fromJson).whereType<ServerNotice>()];
    } catch (_) {}
  }

  Future<void> refreshAccount({bool force = false}) async {
    final now = services.now();
    if (!force && _refreshedAt != null && now.difference(_refreshedAt!) < const Duration(minutes: 15)) return;
    _refreshedAt = now;
    final session = services.ai.session;
    final list = await services.server.notices(session);
    if (list != null) {
      serverNoticeList = list;
      noticeRules = NoticeRules.fromJson(services.server.lastRules);
      try {
        await services.lock.keys.write('srv_notices', jsonEncode([for (final n in list) n.toJson()]));
        await services.lock.keys.write('srv_note_rules', jsonEncode(noticeRules.toJson()));
      } catch (_) {}
      await _reschedule();
    }
    if (session.isEmpty) return;
    try {
      final info = await services.server.me(session);
      if (info != null) await _applyServer(info);
    } on SessionExpired {
      services.ai.session = '';
      serverAi = false;
      await services.lock.keys.delete('srv_session');
      notifyListeners();
    }
  }

  /// Signs out: automatic Drive backup stops and its password is forgotten
  /// on this phone. Backups already in Drive stay there.
  Future<void> signOutGoogle() async {
    await services.google.signOut();
    googleEmail = '';
    googleName = '';
    driveOn = false;
    final keys = services.lock.keys;
    services.ai.session = '';
    serverAi = false;
    serverProUntil = null;
    for (final k in ['g_email', 'g_name', 'drive_on', 'drive_pw', 'drive_extra', 'drive_key_server', 'srv_session', 'srv_ai', 'srv_pro_until']) {
      await keys.delete(k);
    }
    notifyListeners();
  }

  /// Turns on Drive backup. It is locked with this Google account's key from
  /// our server, so there is no password to remember; the same account
  /// opens it on a new phone.
  Future<String?> startDriveBackup() async {
    if (!signedIn) return 'আগে Google দিয়ে লগইন করুন';
    final keys = services.lock.keys;
    if ((await keys.read('drive_key_server')) != 'true') {
      await refreshAccount(force: true);
      if ((await keys.read('drive_key_server')) != 'true') return 'সার্ভারের সাথে যোগাযোগ হয়নি — ইন্টারনেট দেখে আবার চেষ্টা করুন';
    }
    driveOn = true;
    await keys.write('drive_on', 'true');
    notifyListeners();
    return backupToDrive();
  }

  Future<void> stopDriveBackup() async {
    driveOn = false;
    await services.lock.keys.write('drive_on', 'false');
    notifyListeners();
  }

  /// One backup to Drive now. The new file is uploaded first; only then are
  /// the older ones deleted, so a failed upload never loses the last backup.
  Future<String?> backupToDrive() async {
    if (!signedIn) return 'আগে Google দিয়ে লগইন করুন';
    if (loadError != null) return 'তথ্য খোলা যায়নি, তাই ব্যাকআপ নেওয়া হয়নি';
    final keys = services.lock.keys;
    final pw = await keys.read('drive_pw');
    if (pw == null || pw.isEmpty || (await keys.read('drive_key_server')) != 'true') return 'সার্ভারের সাথে যোগাযোগ হয়নি — ইন্টারনেট দেখে আবার চেষ্টা করুন';
    if (driveBusy) return null;
    driveBusy = true;
    notifyListeners();
    try {
      final token = await services.google.driveToken();
      // The extra lock (the member's own password) on top of the account's key, when set.
      final extra = await keys.read('drive_extra');
      final hasExtra = extra != null && extra.isNotEmpty;
      final bytes = await Backup.export(data, hasExtra ? driveLock(pw, extra) : pw,
          files: await backupFiles(), iterations: hasExtra ? Backup.passwordIterations : Backup.defaultIterations);
      final now = services.now();
      final stamp = now.toIso8601String().replaceAll(':', '-').split('.').first;
      final id = await services.drive.upload(token, '$_drivePrefix-$stamp.dbk', bytes);
      for (final f in await services.drive.list(token)) {
        if (f.id != id && f.name.startsWith(_drivePrefix)) await services.drive.delete(token, f.id);
      }
      lastDrive = now;
      _driveDirty = false;
      await keys.write('drive_last', now.toIso8601String());
      await keys.write('drive_dirty', 'false');
      await setPref('last_backup', now.toIso8601String());
      return null;
    } on GoogleError catch (e) {
      return e.message;
    } catch (e) {
      return 'Drive-এ ব্যাকআপ হয়নি: $e';
    } finally {
      driveBusy = false;
      notifyListeners();
    }
  }

  /// When the app goes to the background: a quiet backup if something
  /// changed and the last one is at least 30 minutes old.
  Future<void> autoDriveBackup() async {
    if (!driveOn || !has(ProFeature.autoBackup) || !signedIn || !_driveDirty || driveBusy) return;
    final last = lastDrive;
    if (last != null && services.now().difference(last) < const Duration(minutes: 30)) return;
    await backupToDrive();
  }

  /// This account's backups in Drive, newest first.
  Future<List<DriveFile>> driveBackups() async {
    final token = await services.google.driveToken();
    return [for (final f in await services.drive.list(token)) if (f.name.startsWith(_drivePrefix)) f];
  }

  /// Opens a Drive backup (nothing is replaced yet): with the account's key;
  /// with [password] it is tried as the member's extra lock on that key, then
  /// as the whole password of a backup made before keys (WrongKey when none fits).
  Future<(AppData, Map<String, Uint8List>)> openDriveBackup(DriveFile f, {String? password}) async {
    final token = await services.google.driveToken();
    final bytes = await services.drive.download(token, f.id);
    final key = await services.lock.keys.read('drive_pw');
    if (password == null) {
      if (key == null || key.isEmpty) throw const WrongKey();
      final extra = await services.lock.keys.read('drive_extra');
      if (extra != null && extra.isNotEmpty) {
        try {
          return await Backup.restore(bytes, driveLock(key, extra));
        } on WrongKey {
          // Made before the extra lock was set: the key alone.
        }
      }
      return Backup.restore(bytes, key);
    }
    if (key != null && key.isNotEmpty) {
      try {
        final r = await Backup.restore(bytes, driveLock(key, password));
        // Opened with the extra lock: later backups keep it.
        await services.lock.keys.write('drive_extra', password);
        return r;
      } on WrongKey {
        // Not the extra lock: maybe an old backup's own password.
      }
    }
    return Backup.restore(bytes, password);
  }

  /// The Drive backup's key with the member's own extra password (owner's
  /// review, 27 Oct): someone who takes over the Google account cannot open
  /// the backup without it. Forgotten, it cannot be recovered.
  static String driveLock(String accountKey, String extra) => '$accountKey\u0000$extra';

  Future<bool> driveExtraOn() async => ((await services.lock.keys.read('drive_extra')) ?? '').isNotEmpty;

  /// Sets (or with null takes off) the extra lock, then backs up at once, so
  /// the copy in Drive has the new lock (the older one is deleted after).
  Future<String?> setDriveExtra(String? password) async {
    final keys = services.lock.keys;
    if (password == null || password.isEmpty) {
      await keys.delete('drive_extra');
    } else {
      await keys.write('drive_extra', password);
    }
    _driveDirty = true;
    notifyListeners();
    return driveOn ? backupToDrive() : null;
  }

  /// After restoring from Drive: keep backing up, now with the account's key.
  Future<void> continueDriveBackup() async {
    final keys = services.lock.keys;
    driveOn = true;
    await keys.write('drive_on', 'true');
    lastDrive = services.now();
    await keys.write('drive_last', lastDrive!.toIso8601String());
    notifyListeners();
  }

  /// Feedback conversations and blood requests through our server.
  late final community = Community(services.server, () => services.ai.session);

  /// ফ্যামিলি (lib/state/family_state.dart).
  late final family = FamilyState(this);

  /// Answers from our team not opened yet (from the server, on refresh).
  int feedbackUnread = 0;

  /// A feature wish or a problem to our server. Null when sent.
  Future<String?> sendFeedback(String kind, String text, String appVersion) async =>
      (await community.startFeedback(kind: kind, text: text, appVersion: appVersion)).$2;

  int _adShown = 0, _adDone = 0;
  String _adDay = '';

  /// A task was finished (a payment or reminder saved). True when the free
  /// app shows a full-screen ad now (see [fullAdDue]).
  Future<bool> taskFinished() async {
    if (!showAds) return false;
    final now = services.now();
    final today = '${now.year}-${now.month}-${now.day}';
    if (_adDay != today) {
      _adDay = today;
      _adShown = 0;
    }
    _adDone++;
    final first = firstUse == null || dayOnly(firstUse!) == dayOnly(now);
    if (!fullAdDue(shown: _adShown, done: _adDone, firstDay: first)) return false;
    _adShown++;
    _adDone = 0;
    return true;
  }

  Future<void> setAiKey(String key) async {
    services.ai.key = key.trim();
    if (key.trim().isEmpty) {
      await services.lock.keys.delete('claude_api_key');
    } else {
      await services.lock.keys.write('claude_api_key', key.trim());
    }
    notifyListeners();
  }

  AiContext aiContext({DateTime? now, String shown = ''}) => AiContext(
        now: now ?? services.now(),
        people: knownPeople(data.ledger).take(60).toList(),
        categories: aiShareData ? data.noteCategories : const [],
        money: moneySummary(),
        records: aiShareData ? recordsSummary() : '',
        shown: aiShareData ? shown : '',
      );

  // ── Where each answer came from (counts only, sent to our server) ──

  /// Today's counts by source: rules, local (the phone's model), gemini,
  /// haiku, sonnet, failed. Kept on the phone until sent; never any words.
  final Map<String, Map<String, int>> answerSources = {};

  void countSource(String source) {
    final d = services.now();
    final day = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final m = answerSources.putIfAbsent(day, () => {});
    m[source] = (m[source] ?? 0) + 1;
    _saveSources();
  }

  Future<void> _saveSources() async {
    try {
      await services.lock.keys.write('answer_sources', jsonEncode(answerSources));
    } catch (_) {}
  }

  Future<void> _loadSources() async {
    try {
      final raw = await services.lock.keys.read('answer_sources');
      if (raw == null || raw.isEmpty) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      for (final e in j.entries) {
        answerSources[e.key] = {for (final x in (e.value as Map<String, dynamic>).entries) x.key: (x.value as num).toInt()};
      }
    } catch (_) {}
  }

  /// Days before today go to the server once (signed in only); today's wait
  /// until tomorrow. Older than a week: dropped (the server refuses them).
  Future<void> sendAnswerSources() async {
    final session = services.ai.session;
    if (session.isEmpty || !services.server.configured) return;
    final d = services.now();
    final today = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final weekAgo = d.subtract(const Duration(days: 7));
    for (final day in answerSources.keys.toList()..sort()) {
      if (day.compareTo(today) >= 0) continue;
      final at = DateTime.tryParse(day);
      if (at == null || at.isBefore(weekAgo)) {
        answerSources.remove(day);
        continue;
      }
      final r = await services.server.send('POST', '/ai/sources', session, {'day': day, 'counts': answerSources[day]});
      if (r.status == 200 || r.status == 400) answerSources.remove(day);
    }
    await _saveSources();
  }

  /// The server's switch for the on-phone model: off | shadow | on (GET
  /// /nlu/config, once a day; shadow until the server says otherwise).
  String nluMode = 'shadow';

  /// The member agreed to send learning samples (off until they turn it on).
  bool nluSamplesOn = false;

  /// Samples waiting to be sent (at most 200 kept; the oldest go first).
  final List<Map<String, Object?>> nluSamples = [];
  DateTime? _lastSampleAt;
  String _lastSampleText = '';

  Future<void> setNluSamplesOn(bool on) async {
    nluSamplesOn = on;
    if (!on) nluSamples.clear();
    try {
      await services.lock.keys.write('nlu_samples_on', on ? 'true' : 'false');
      await services.lock.keys.write('nlu_samples', jsonEncode(nluSamples));
    } catch (_) {}
    notifyListeners();
  }

  /// One sample; [said] is the plain words (for "said again" only, never kept).
  void addNluSample(Map<String, Object?> sample, String said) {
    if (!nluSamplesOn) return;
    nluSamples.add(sample);
    while (nluSamples.length > 200) {
      nluSamples.removeAt(0);
    }
    _lastSampleAt = services.now();
    _lastSampleText = normalize(said);
    _saveNluSamples();
  }

  /// The member reacted to the reading just sampled: said no / complained
  /// within a minute, or said the same thing again within 30 seconds.
  void signalLastSample(String said, {required bool complained}) {
    final at = _lastSampleAt;
    if (!nluSamplesOn || at == null || nluSamples.isEmpty) return;
    final s = services.now().difference(at).inSeconds;
    String? sig;
    if (complained && s <= 60) sig = 'said_no';
    if (!complained && s <= 30 && normalize(said) == _lastSampleText) sig = 'repeated';
    if (sig == null) return;
    nluSamples.last['signal'] = sig;
    _lastSampleAt = null;
    _saveNluSamples();
  }

  Future<void> _saveNluSamples() async {
    try {
      await services.lock.keys.write('nlu_samples', jsonEncode(nluSamples));
    } catch (_) {}
  }

  /// Waiting samples go to the server (signed in and agreed only).
  Future<void> sendNluSamples() async {
    final session = services.ai.session;
    if (!nluSamplesOn || nluSamples.isEmpty || session.isEmpty || !services.server.configured) return;
    final batch = nluSamples.take(100).toList();
    final r = await services.server.send('POST', '/nlu/samples', session, {'consent_ver': nluConsentVer, 'samples': batch});
    if (r.status == 200 || r.status == 400 || r.status == 413) {
      nluSamples.removeRange(0, batch.length);
      await _saveNluSamples();
    }
  }

  /// A newer on-phone model for this member, if the server has one — downloaded
  /// on Wi-Fi only; the chat opens it at once ([onNluModelChanged]).
  Future<void> updateNluModelFromServer() async {
    final session = services.ai.session;
    if (session.isEmpty || !services.server.configured || nluMode == 'off') return;
    try {
      final r = await services.server.send('GET', '/nlu/model', session);
      final files = NluModelFiles(await getApplicationSupportDirectory());
      final what = await updateNluModel(files, r.status, r.data, mayDownload: await unmetered());
      Trace.log('nlu', 'model update', {'result': what});
      nluModelState = what.startsWith('updated:') ? 'ready' : (what == 'same' ? 'ready' : what);
      if (nluModelState == 'ready') nluModelVersion = files.current ?? '';
      notifyListeners();
      if (what.startsWith('updated:') || what == 'builtin') onNluModelChanged?.call();
    } catch (_) {}
  }

  /// For the More screen: 'ready' (with [nluModelVersion]), 'wait-wifi',
  /// 'builtin' (no model for this member yet), other failures, or '' (not asked yet).
  String nluModelState = '';
  String nluModelVersion = '';

  /// Wi-Fi (or another network that does not count data); tests replace it.
  Future<bool> Function() unmetered = AppPlatform.unmetered;

  /// Set by the chat: a new model is there (or gone) — open it again.
  void Function()? onNluModelChanged;

  /// Everything this member sent is deleted on the server (and nothing waits here).
  Future<String?> deleteMyNluSamples() async {
    nluSamples.clear();
    await _saveNluSamples();
    final session = services.ai.session;
    if (session.isEmpty || !services.server.configured) return null;
    final r = await services.server.send('DELETE', '/nlu/samples/mine', session);
    return r.ok ? null : r.error;
  }

  Future<void> loadNluConfig() async {
    try {
      nluSamplesOn = (await services.lock.keys.read('nlu_samples_on')) == 'true';
      final raw = await services.lock.keys.read('nlu_samples');
      if (nluSamplesOn && raw != null && raw.isNotEmpty) {
        nluSamples
          ..clear()
          ..addAll([for (final x in jsonDecode(raw) as List) (x as Map).cast<String, Object?>()]);
      }
      final saved = await services.lock.keys.read('nlu_mode');
      if (saved == 'off' || saved == 'shadow' || saved == 'on') nluMode = saved!;
      final session = services.ai.session;
      if (session.isEmpty || !services.server.configured) return;
      final r = await services.server.send('GET', '/nlu/config', session);
      final m = r.data['mode'];
      if (r.status == 200 && (m == 'off' || m == 'shadow' || m == 'on')) {
        nluMode = m as String;
        await services.lock.keys.write('nlu_mode', nluMode);
      }
    } catch (_) {}
  }

  /// The user lets the AI see their reminders, tasks and notes (never
  /// passwords, PINs or anything secret), so it can answer about them.
  bool aiShareData = true;

  /// What the assistant calls the user ("সাইফুল ভাই"); empty = no name.
  /// The main-money line the last loan or other হিসাব's entry made (to say
  /// "মূল টাকায় যুক্ত হলো"); null when none was made.
  CashEntry? lastMainLine;

  String userName = '';


  /// The place for sunrise, sunset and prayer times (see `bdPlaces`).
  String district = 'ঢাকা';

  Future<void> setUserName(String v) async {
    userName = v.trim();
    askUserName = userName;
    await services.lock.keys.write('user_name', userName);
    notifyListeners();
  }

  /// Chosen by hand ([auto] false) the place stays; otherwise it follows
  /// the phone (see [refreshPlace]).
  Future<void> setDistrict(String v, {bool auto = false}) async {
    final moved = v != district;
    district = v;
    askPlace = v;
    hijriAdjust = hijriShift;
    // A new place: its own weather now, never the last place's (owner, 25 Oct).
    if (moved) {
      _weather = null;
      _weatherKey = '';
      todayWeather = null;
    }
    await services.lock.keys.write('district', v);
    if (!auto && autoPlace) {
      autoPlace = false;
      await services.lock.keys.write('auto_place', 'false');
    }
    // Chosen by hand: kept while the phone stays near where it was chosen;
    // gone far (another district, another country), the place follows the
    // phone again (owner, 29 Oct: "নোয়াখালী থাকলে নোয়াখালী, ঢাকায় থাকলে ঢাকায়").
    if (!auto) await _put('place_hold', 'pending');
    notifyListeners();
    if (moved) {
      await refreshWeather();
      unawaited(refreshHolidaysAbroad().catchError((_) {}));
    }
  }

  /// The district follows where the phone is (sunrise, prayer times,
  /// weather). The location is read on the phone only — never sent.
  bool autoPlace = true;

  /// Roughly where the phone is, if the member allowed location; tests replace it.
  Future<(double, double)?> Function() whereAmI = () async {
    final st = await LocationShareChannel.status();
    if (st['fine'] != true || st['service'] != true) return null;
    return LocationShareChannel.here();
  };
  DateTime? _placeCheckedAt;

  /// Turns following the phone on or off.
  Future<void> setAutoPlace(bool on) async {
    autoPlace = on;
    await services.lock.keys.write('auto_place', on ? 'true' : 'false');
    if (on) await _put('place_hold', '');
    notifyListeners();
    if (on) {
      await askPlacePermission();
      await refreshPlace(force: true);
    }
  }

  /// Asks for location when following the phone has none yet (owner, 24
  /// Oct: "অটোমেটিক লোকেশন ট্রাক করতেছে না"). [once]: only the first time.
  Future<void> askPlacePermission({bool once = false}) async {
    if (once && await services.lock.keys.read('place_asked') == 'true') return;
    final st = await placeStatus();
    if (st.isEmpty || st['fine'] == true) return;
    await _put('place_asked', 'true');
    await LocationShareChannel.ask();
  }

  /// The country the phone's network is in (tests replace it).
  Future<String> Function() whereCountry = LocationShareChannel.country;

  /// The phone's location permission (tests replace it).
  Future<Map<String, bool>> Function() placeStatus = LocationShareChannel.status;

  /// Moves [district] to where the phone is now (at most every 10 minutes
  /// unless [force]). Returns the new place's name when it changed.
  Future<String?> refreshPlace({bool force = false}) async {
    String hold = '';
    if (!autoPlace) {
      hold = await services.lock.keys.read('place_hold') ?? '';
      if (hold.isEmpty) return null;
    }
    final now = services.now();
    final last = _placeCheckedAt;
    if (!force && last != null && now.difference(last).inMinutes < 10) return null;
    final at = await whereAmI();
    // No fix (location off, no permission yet): tried again next time.
    if (at == null) return null;
    _placeCheckedAt = now;
    if (!autoPlace) {
      // Chosen by hand: where the phone was then is remembered; more than
      // [placeHoldKm] away now, following the phone starts again.
      final f = hold.split(',');
      final hLat = f.length == 2 ? double.tryParse(f[0]) : null, hLon = f.length == 2 ? double.tryParse(f[1]) : null;
      if (hLat == null || hLon == null) {
        await _put('place_hold', '${at.$1.toStringAsFixed(4)},${at.$2.toStringAsFixed(4)}');
        return null;
      }
      if (kmBetween(at.$1, at.$2, hLat, hLon) <= placeHoldKm) return null;
      autoPlace = true;
      await services.lock.keys.write('auto_place', 'true');
      await _put('place_hold', '');
    }
    // Anywhere in the world (owner, 25 Oct): a district in Bangladesh, else
    // the place itself on the phone's own clock.
    var here = placeAt(at.$1, at.$2, tzMinutes: now.timeZoneOffset.inMinutes);
    // Abroad with no big city near: the country from the phone's network.
    if (here.abroad && here.cc.isEmpty) {
      final cc = await whereCountry();
      if (cc.isNotEmpty && cc != 'BD') here = Place(here.name, here.lat, here.lon, tz: here.tz, region: here.region, cc: cc);
    }
    final was = placeNamed(district);
    if (here.name == was.name && here.tz == was.tz && kmBetween(here.lat, here.lon, was.lat, was.lon) < 5) return null;
    await setDistrict(here.key, auto: true);
    return here.name;
  }

  /// How far the phone must go from where a place was chosen by hand before
  /// the place follows the phone again.
  static const placeHoldKm = 40.0;

  /// A place found by search, kept as a place: a district when it is in
  /// Bangladesh, else that town on its own clock (asked from the weather
  /// service; the phone's clock when offline).
  Future<Place> placeFromHit(PlaceHit h) async {
    final bd = nearestPlace(h.lat, h.lon);
    if (bd != null && (h.countryCode.isEmpty || h.countryCode == 'BD')) return bd.$1;
    final tz = await services.weather.offsetAt(h.lat, h.lon) ?? services.now().timeZoneOffset.inMinutes;
    return Place(h.name, h.lat, h.lon, tz: tz, region: regionAt(h.lat, h.lon), cc: h.countryCode.toUpperCase());
  }

  /// The public holidays of the country the member is in, abroad (owner,
  /// 29 Oct: "যে দেশে সে দেশের ছুটি"), from the next [count] ahead — kept on
  /// the phone by country and year; empty when not known (yet).
  List<AbroadHoliday> holidaysAbroad(DateTime now, {int count = 2}) {
    final cc = placeNamed(district).country;
    if (cc == 'BD' || cc.isEmpty) return const [];
    final today = DateTime(now.year, now.month, now.day);
    final all = <AbroadHoliday>[];
    final kept = _holidayBook();
    for (final y in [now.year, now.year + 1]) {
      final l = kept['${cc}_$y'];
      if (l is List) all.addAll(l.map(AbroadHoliday.fromJson).whereType<AbroadHoliday>());
    }
    all.sort((a, b) => a.date.compareTo(b.date));
    return all.where((h) => !h.date.isBefore(today)).take(count).toList();
  }

  /// Fetches this year's (and, late in the year, next year's) holidays of
  /// the country the member is in, when not kept yet.
  Future<void> refreshHolidaysAbroad() async {
    final cc = placeNamed(district).country;
    if (cc == 'BD' || cc.isEmpty) return;
    final now = services.now();
    for (final y in [now.year, if (now.month >= 10) now.year + 1]) {
      final k = '${cc}_$y';
      if (_holidayBook().containsKey(k)) continue;
      // The Gulf, Malaysia, Pakistan: worked out on the phone; the rest asked.
      final got = builtInHolidays(cc, y, adjust: hijriShift) ?? await services.weather.holidays(cc, y);
      if (got == null) continue;
      final book = _holidayBook()..[k] = [for (final h in got) h.toJson()];
      prefs['hol_abroad'] = jsonEncode(book);
      await _put('hol_abroad', prefs['hol_abroad']!);
      notifyListeners();
    }
  }

  /// Holidays kept by "CC_year".
  Map<String, Object?> _holidayBook() {
    try {
      final m = jsonDecode(text('hol_abroad', '{}'));
      return m is Map ? m.cast<String, Object?>() : <String, Object?>{};
    } catch (_) {
      return <String, Object?>{};
    }
  }

  /// Days the Hijri date is moved: the user's own choice, else +1 outside
  /// South Asia (the month there usually starts a day before Bangladesh).
  int get hijriShift => prefs.containsKey('hijri_adjust') ? number('hijri_adjust') : (placeNamed(district).region == 'sa' ? 0 : 1);

  /// The place's name in the app's language (a district or a city abroad).
  String get placeLabel => placeNamed(district).label;

  // ── Look and language (সেটিংস › চেহারা, ভাষা) ──

  /// Light, dark, or as the phone is.
  Look look = Look.sun;

  /// The accent colour's key (see `accents`).
  /// Default: কমলা (owner, 25 Oct); a colour the user chose stays.
  String accentKey = 'amber';

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
    final was = english;
    english = on;
    notifyListeners();
    await _put('lang', on ? 'en' : 'bn');
    // The medicine reminders' names are written in the app's language: made
    // again in the new one (owner, 29 Oct: English left Bangla behind).
    if (was != on && data.medicines.isNotEmpty) {
      final keep = isEn;
      isEn = on;
      try {
        for (final m in [...data.medicines]) {
          await saveMedicine(m);
        }
      } finally {
        isEn = keep;
      }
    }
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
      look = Look.values.firstWhere((l) => l.name == saved, orElse: () => Look.sun);
      accentKey = await keys.read('accent') ?? 'amber';
      english = (await keys.read('lang')) == 'en';
      letterSize = double.tryParse(await keys.read('letter_size') ?? '') ?? 1.0;
      easyMode = (await keys.read('easy_mode')) == 'true';
    } catch (_) {}
  }

  // ── The assistant speaking first, and modes (সেটিংস › সহকারী) ──

  bool morningOn = true;
  int morningAt = defaultMorningAt;
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

  AssistantPrefs get assistantPrefs => AssistantPrefs(
        morningOn: morningOn,
        morningAt: morningAt,
        nightOn: nightOn,
        nightAt: nightAt,
        nudgesOn: nudgesOn,
        name: userName,
        quietOn: flag('quiet_on', true),
        quietFrom: number('quiet_from', 22 * 60),
        quietTo: number('quiet_to', 7 * 60),
        dailyCap: number('daily_cap', 3),
        jumuah: flag('n_jumuah', true),
        plan: flag('n_plan', true),
        smart: flag('n_smart', true) && has(ProFeature.smartNudges),
        docAlerts: has(ProFeature.docAlerts),
        dueAlerts: has(ProFeature.dueReminders),
        health: flag('n_health', true),
        festival: flag('n_festival', true),
        weekly: flag('n_weekly', true),
        streak: flag('n_streak', true),
        comeback: flag('n_comeback', true),
        prayers: {for (final x in text('prayer_set').split(',')) if (x.trim().isNotEmpty) x.trim()},
        server: serverNoticeList,
        news: flag('n_news', true),
        ramadan: flag('n_ramadan'),
        place: district,
        lastOpen: DateTime.tryParse(text('last_open')),
        donorNext: donorNextDate,
        lastBackup: DateTime.tryParse(text('last_backup')),
        quote: flag('n_quote', true),
        homeFix: flag('n_fix', true),
        rules: noticeRules,
        trialEnds: onTrial ? trialEnds : null,
        groups: memberGroups(now: services.now(), firstUse: firstUse, openDays: openDays, pro: gated ? pro : true),
      );

  /// The days the app was opened lately (for the admin's "নিয়মিত / মাঝে মাঝে"; stays on the phone).
  List<DateTime> get openDays => [for (final x in text('open_days').split(',')) if (DateTime.tryParse(x) != null) DateTime.parse(x)];

  /// When the user may give blood again (3 months after the last time), if they are a donor.
  DateTime? get donorNextDate {
    final last = DateTime.tryParse(text('blood_last'));
    if (last == null || !flag('donor_on')) return null;
    return DateTime(last.year, last.month + 3, last.day);
  }

  /// The app was opened: the "অনেক দিন দেখা নেই" note moves three days on.
  Future<void> markOpened() async {
    final now = services.now();
    final last = DateTime.tryParse(text('last_open'));
    if (last != null && dayOnly(last) == dayOnly(now)) return;
    await setPref('last_open', now.toIso8601String());
    // The last 30 days it was opened (a date each, nothing more).
    final days = [...openDays.map(dayKey).where((d) => d != dayKey(now)), dayKey(now)];
    await setPref('open_days', days.skip(days.length > 30 ? days.length - 30 : 0).join(','));
  }

  // ── Health Connect, read only (owner, 27 Oct) ──

  /// Whether this phone has it; checked when the health page opens and on resume.
  HcStatus hcStatus = HcStatus.unsupported;

  /// All three read permissions given (steps, sleep, exercise).
  bool hcGranted = false;

  /// Today's steps from Health Connect (null: not read yet).
  int? hcStepsToday;
  DateTime? _hcRead;

  /// The user turned it on in the app, after the explanation page.
  bool get hcOn => flag('hc_on');

  Future<void> checkHealthConnect() async {
    hcStatus = await services.health.status();
    hcGranted = hcStatus == HcStatus.available && await services.health.granted();
    notifyListeners();
  }

  /// Asks Health Connect for the three read permissions (its own screen).
  Future<bool> turnOnHealthConnect() async {
    await checkHealthConnect();
    if (hcStatus != HcStatus.available) return false;
    final ok = await services.health.request();
    hcGranted = ok;
    if (ok) {
      await setPref('hc_on', true);
      await syncHealthConnect(force: true);
    }
    notifyListeners();
    return ok;
  }

  /// Stops reading; with [forget], the readings brought in from it go too
  /// (the hand-written ones stay).
  Future<void> turnOffHealthConnect({bool forget = false}) async {
    await setPref('hc_on', false);
    hcStepsToday = null;
    LiveSteps.today = null;
    if (forget) {
      data.health.removeWhere((h) => h.tag == hcTag);
      await setPref('hc_gone', '');
      await _save();
    }
    notifyListeners();
  }

  /// Reads today's steps and the last 30 days' sleep and exercise sessions
  /// into the app's own readings, without doubles (logic/health_connect.dart).
  /// Returns how many readings were new.
  Future<int> syncHealthConnect({bool force = false}) async {
    if (!hcOn) return 0;
    final now = services.now();
    if (!force && _hcRead != null && now.difference(_hcRead!) < const Duration(minutes: 2)) return 0;
    _hcRead = now;
    await checkHealthConnect();
    if (!hcGranted) return 0;
    final today = dayOnly(now);
    final steps = await services.health.steps(today, now);
    if (steps != null) {
      hcStepsToday = steps;
      LiveSteps.today = (day: today, steps: steps, at: now, hc: true);
    }
    final from = today.subtract(const Duration(days: 30));
    final gone = text('hc_gone').split(',').toSet();
    final incoming = [
      ...(await services.health.sleep(from, now)).map(sleepLog),
      ...(await services.health.exercise(from, now)).map(exerciseLog),
    ].whereType<HealthLog>().where((h) => !gone.contains(h.id)).toList();
    final before = {for (final h in data.health) if (h.tag == hcTag) h.id: jsonEncode(h.toJson())};
    final changed = incoming.any((h) => before[h.id] != jsonEncode(h.toJson()));
    var added = 0;
    if (changed) {
      final (list, n) = mergeHcLogs(data.health, incoming);
      added = n;
      data.health
        ..clear()
        ..addAll(list);
      await _save();
    }
    notifyListeners();
    return added;
  }

  /// A Health Connect reading the user deleted is not brought back.
  Future<void> _hcForget(String id) async {
    if (!id.startsWith('hc:')) return;
    final gone = [...text('hc_gone').split(',').where((x) => x.isNotEmpty && x != id), id];
    await setPref('hc_gone', gone.skip(gone.length > 300 ? gone.length - 300 : 0).join(','));
  }

  /// Today's steps for an answer: Health Connect's, else the phone's own counter.
  void noteStepsForAnswers() {
    final now = services.now();
    final hc = LiveSteps.today;
    if (hcOn && hc != null && hc.day == dayOnly(now)) return;
    final book = StepBook.fromJson(text('steps_book'));
    LiveSteps.today = book != null && book.day == stepDay(now) ? (day: dayOnly(now), steps: book.today, at: now, hc: false) : null;
  }

  /// The other settings (notification types, quiet hours, Hijri date
  /// correction, prayer reminders…), as saved text. Read with [flag] / [number].
  final Map<String, String> prefs = {};

  /// Saved settings read at start into [prefs].
  static const prefKeys = [
    'hijri_adjust', 'quiet_on', 'quiet_from', 'quiet_to', 'daily_cap', 'n_jumuah', 'n_plan', 'n_smart', 'n_health', 'n_festival', 'n_weekly', 'n_quote', 'n_fix',
    'n_streak', 'n_comeback', 'n_news', 'n_prayer', 'prayer_set', 'n_ramadan', 'blood_group', 'blood_last', 'blood_last_unknown', 'blood_phone', 'blood_sync', 'donor_on', 'last_open', 'open_days', 'last_backup', 'zakat_gold_vori', 'zakat_gold_price', 'zakat_silver_vori', 'zakat_silver_price', 'zakat_business', 'zakat_other', 'zakat_gold_carat', 'zakat_gold_list', 'order_home_tools', 'order_doc_folders', 'order_projects', 'hol_abroad', 'g_card_off', 'p_card_off', 'trace_on', 'trace_share', 'hc_on', 'hc_gone', 'steps_book',
  ];

  bool flag(String key, [bool or = false]) => prefs[key] == null ? or : prefs[key] == 'true';
  int number(String key, [int or = 0]) => int.tryParse(prefs[key] ?? '') ?? or;
  String text(String key, [String or = '']) => prefs[key] ?? or;

  /// The user's own blood group still lacks the number or the last donation
  /// day (or "মনে নেই") that must go with it (owner, 28 Oct).
  bool get bloodDetailsMissing {
    if (data.emergency.blood.isEmpty) return false;
    final phone = text('blood_phone');
    return phone.isEmpty || (text('blood_last').isEmpty && !flag('blood_last_unknown'));
  }

  /// Keeps the number and last donation that go with the group, then sends them.
  Future<String?> setBloodDetails({required String phone, DateTime? last, bool unknown = false}) async {
    await setPref('blood_phone', phone);
    if (last != null) {
      await setPref('blood_last', last.toIso8601String());
      await setPref('blood_last_unknown', false);
    } else {
      await setPref('blood_last_unknown', unknown);
    }
    return syncBloodGroup();
  }

  /// The group, number and last donation to our server (or taken away when
  /// the group is cleared). Kept pending when it cannot go now.
  Future<String?> syncBloodGroup() async {
    final blood = data.emergency.blood;
    if (blood.isNotEmpty && bloodDetailsMissing) return null;
    if (!signedIn) {
      await setPref('blood_sync', 'pending');
      return null;
    }
    final e = await community.setBloodGroup(
        blood: blood, phone: text('blood_phone'), lastDonated: DateTime.tryParse(text('blood_last')), lastUnknown: flag('blood_last_unknown'), district: district);
    await setPref('blood_sync', e == null ? 'done' : 'pending');
    return e;
  }

  /// সমস্যা খোঁজার লগ › সার্ভারে পাঠান: the member's choice to send the log
  /// to us (off unless turned on).
  bool get traceShare => flag('trace_share');

  /// Sends what is new in the log (private conversations left out). Null when
  /// it could not go; otherwise how many lines went and how many
  /// conversations were kept back.
  Future<({int sent, int left})?> sendTrace({bool all = false}) async {
    final t = Trace.forServer(all: all);
    if (t.lines.isEmpty) return (sent: 0, left: t.left);
    final ok = await services.server.sendTrace(t.lines.length > 400 ? t.lines.sublist(t.lines.length - 400) : t.lines, ErrorLog.version, services.ai.session);
    if (!ok) return null;
    if (t.upTo != null) Trace.sentUpTo = t.upTo;
    return (sent: t.lines.length > 400 ? 400 : t.lines.length, left: t.left);
  }

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
      default:
        prefs[key] = '$value';
        if (key == 'hijri_adjust') hijriAdjust = hijriShift;
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
      morningAt = int.tryParse(await keys.read('morning_at') ?? '') ?? defaultMorningAt;
      nightAt = int.tryParse(await keys.read('night_at') ?? '') ?? 21 * 60;
      persona = await keys.read('persona') ?? '';
      for (final k in prefKeys) {
        final v = await keys.read(k);
        if (v != null) prefs[k] = v;
      }
      // The diagnostic trace: on in development builds, or when the user turned it on.
      Trace.enabled = kDebugMode || prefs['trace_on'] == 'true';
      askZakat = zakatSaved;
      hijriAdjust = hijriShift;
      askPlace = district;
      askUserName = userName;
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
    // Health stays on the phone: anything about medicine, a doctor or an illness is left out (owner's rule).
    final meds = [for (final m in data.medicines) m.name];
    bool hx(String s) => mentionsHealth(s, extra: meds);
    var held = 0;
    final mem = data.memories.where((m) => !mentionsSecret(m.text) && !hx(m.text)).take(40).toList();
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
      final habits = data.habits.where((h) => !hx(h.name)).toList();
      if (habits.isNotEmpty) lines.add('Habits (streak days, done today?): ${habits.map((h) => '${h.name} ${h.streak(now)} ${h.doneOn(now) ? 'yes' : 'no'}').join('; ')}');
    }
    // Medicines are health data: they stay on the phone (questions about
    // them are answered by the app itself).
    if (data.medicines.isNotEmpty) lines.add('Medicines: kept on the phone only — for any medicine question add a menu/medicine item or reply "দেখছি।".');
    final rem = [...data.reminders.where((r) {
      final h = hx(r.title);
      if (h) held++;
      return !h;
    })]..sort((a, b) => a.nextDate(now).compareTo(b.nextDate(now)));
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
    final open = data.tasks.where((t) {
      if (t.done) return false;
      final h = hx(t.title);
      if (h) held++;
      return !h;
    }).toList();
    if (open.isNotEmpty) {
      lines.add('Open to-dos:');
      for (final t in open.take(60)) {
        // The span as kept: a week/month plan has no day of its own.
        final when = t.due == null
            ? ''
            : switch (t.span) {
                TaskSpan.day => ' (day: ${day(t.due!)})',
                TaskSpan.week => ' (some day in the week starting ${day(t.due!)}; no day set)',
                TaskSpan.month => ' (some time in ${t.due!.year}-${t.due!.month.toString().padLeft(2, '0')}; no day set)',
                TaskSpan.year => ' (some time in ${t.due!.year}; no day set)',
              };
        lines.add('- ${t.title}$when${t.deadline == null ? '' : ' (deadline: ${day(t.deadline!)})'}');
      }
    } else {
      lines.add('Open to-dos: none.');
    }
    final doneToday = data.tasks.where((t) => t.done && t.doneAt != null && dayOnly(t.doneAt!) == dayOnly(now) && !hx(t.title)).toList();
    if (doneToday.isNotEmpty) lines.add('Done today: ${doneToday.take(20).map((t) => t.title).join('; ')}');
    final notes = ([...data.notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
        .where((n) => !mentionsSecret('${n.title} ${n.body}') && !hx('${n.category} ${n.title} ${n.body}'))
        .take(40)
        .toList();
    if (notes.isNotEmpty) {
      lines.add('Notes (category: text):');
      for (final n in notes) {
        final text = (n.body.trim().isEmpty ? n.title : n.body).replaceAll('\n', ' ').trim();
        lines.add('- ${n.category}: ${text.length > 160 ? '${text.substring(0, 160)}…' : text}');
      }
    }
    final docs = data.docs.where((x) => !hx('${x.title} ${x.folder} ${x.about}')).toList();
    if (docs.isNotEmpty) {
      lines.add('Documents kept (photos/files, opened on the phone): '
          '${docs.take(40).map((x) => '${x.title} [${x.folder}]'
              '${x.about.isEmpty ? '' : ' — ${x.about}'}${x.people.isEmpty ? '' : ', people: ${x.people}'}${x.place.isEmpty ? '' : ', place: ${x.place}'}'
              '${x.taken == null ? '' : ', date ${day(x.taken!)}'}, ${x.files.length} files'
              '${x.expiry == null ? '' : ' expires ${day(x.expiry!)}'}').join('; ')}');
    }
    if (held > 0) lines.add('Health-related reminders/to-dos kept on the phone only: $held (not shown to you; for those reply "দেখছি।" or add a menu/medicine item).');
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

  /// What the user entered on the যাকাত page (gold, silver, stock…).
  ZakatSaved get zakatSaved => ZakatSaved(
        goldVori: double.tryParse(text('zakat_gold_vori')) ?? 0,
        goldPrice: number('zakat_gold_price'),
        silverVori: double.tryParse(text('zakat_silver_vori')) ?? 0,
        silverPrice: number('zakat_silver_price'),
        business: number('zakat_business'),
        other: number('zakat_other'),
        golds: _zakatGolds(),
      );

  /// The gold, kind by kind ('zakat_gold_list'); null while only the old
  /// single amount is kept — then that one, at its chosen carat.
  List<GoldPiece>? _zakatGolds() {
    final raw = text('zakat_gold_list');
    if (raw.isEmpty) {
      final v = double.tryParse(text('zakat_gold_vori')) ?? 0;
      return v > 0 ? [GoldPiece(carat: zakatCarat, vori: v, price: number('zakat_gold_price'))] : null;
    }
    try {
      final l = jsonDecode(raw);
      return [if (l is List) for (final j in l) ...[if (GoldPiece.fromJson(j) case final g?) g]];
    } catch (_) {
      return null;
    }
  }

  /// Keeps the member's gold, kind by kind.
  Future<void> setZakatGolds(List<GoldPiece> l) async {
    await setZakatValue('gold_list', jsonEncode([for (final g in l) g.toJson()]));
    notifyListeners();
  }

  Weather? _weather;

  /// The place ([Place.key]) [_weather] was fetched for.
  String _weatherKey = '';

  /// The weather last fetched for the user's place (kept 30 minutes) — only
  /// while that is still the place.
  Weather? get weatherNow => _weatherKey == district ? _weather : null;

  /// Fetches it when older than 30 minutes; the last one when offline.
  Future<Weather?> refreshWeather() async {
    final now = services.now();
    final place = placeNamed(district);
    final key = district;
    final w = weatherNow;
    if (w != null && now.difference(w.at).inMinutes < 30) return w;
    final got = await services.weather.now(place.lat, place.lon, place.name, now);
    // Moved again while asking: this answer is for a place no longer chosen.
    if (key != district) return weatherNow;
    if (got != null) {
      _weather = got;
      _weatherKey = key;
      todayWeather = got;
      notifyListeners();
    }
    return got ?? w;
  }

  MetalPrice? _metal;
  DateTime? _metalAt;

  /// Today's gold and silver price from the server (BAJUS), asked at most
  /// every few hours; the last one known when offline, or null.
  Future<MetalPrice?> metalPriceToday() async {
    final now = services.now();
    if (_metal != null && _metalAt != null && now.difference(_metalAt!).inHours < 6) return _metal;
    final p = await services.server.metalPrice();
    if (p != null) {
      _metal = p;
      _metalAt = now;
      todayMetal = p;
    }
    metalUnavailable = p == null && _metal == null;
    return p ?? _metal;
  }

  /// Today's prices into the যাকাত page — 22-carat gold and silver, and each
  /// kind of the member's gold at its own carat ('other' keeps the member's
  /// price). The user can still change them.
  Future<void> useMetalPrice(MetalPrice p) async {
    final golds = zakatSaved.golds;
    await setZakatValue('gold_price', '${p.gold22}');
    await setZakatValue('silver_price', '${p.silver22}');
    if (golds != null && golds.isNotEmpty) {
      await setZakatGolds([for (final g in golds) (p.gold[g.carat] ?? 0) > 0 ? g.copyWith(price: p.gold[g.carat]) : g]);
    }
  }

  /// The carat of the member's gold ('22k' unless chosen).
  String get zakatCarat => text('zakat_gold_carat', '22k');

  /// Today's বাজুস price of a carat (0: not known).
  int metalGold(String carat) => (todayMetal ?? _metal)?.gold[carat] ?? 0;

  /// An order the member arranged by hand (owner, 29 Oct): [what] is
  /// 'home_tools', 'doc_folders' or 'projects'; empty = the app's own order.
  List<String> orderOf(String what) {
    try {
      final l = jsonDecode(text('order_$what', '[]'));
      return [if (l is List) for (final x in l) '$x'];
    } catch (_) {
      return const [];
    }
  }

  Future<void> setOrder(String what, List<String> keys) async {
    final v = keys.isEmpty ? '' : jsonEncode(keys);
    prefs['order_$what'] = v;
    notifyListeners();
    await _put('order_$what', v);
  }

  /// Keeps one entered zakat value (no reschedule needed).
  Future<void> setZakatValue(String key, String value) async {
    prefs['zakat_$key'] = value;
    askZakat = zakatSaved;
    await _put('zakat_$key', value);
  }

  bool get bargeIn => services.voice.bargeIn;

  Future<void> setBargeIn(bool on) async {
    services.voice.bargeIn = on;
    await services.lock.keys.write('barge_in', on ? 'true' : 'false');
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
  ///
  /// [model] is the on-phone model's reading of the same words (started when
  /// the message came); used only in the server's "on" mode (lib/nlu/router.dart).
  Future<(List<Command>, String?)> understandAll(String said,
      {List<AiTurn> history = const [], bool fast = false, String shown = '', Future<List<NluPiece>?>? model, String nluState = 'idle', String nluKind = 'none'}) async {
    final (cmds, problem, source) = await _understandAll(said, history: history, fast: fast, shown: shown, model: model, nluState: nluState, nluKind: nluKind);
    countSource(source);
    return (cmds, problem);
  }

  /// Sonnet may be asked when Haiku could not make a message out: Pro
  /// through our server, or a key of the user's own.
  /// How long the AI is waited for when the rules already understood the
  /// message (it is waited for fully only when they did not).
  static const aiPatience = Duration(seconds: 4);

  bool get canEscalate => aiByServer || (!gated && services.ai.key.trim().isNotEmpty);

  Future<(List<Command>, String?, String)> _understandAll(String said,
      {List<AiTurn> history = const [], bool fast = false, String shown = '', Future<List<NluPiece>?>? model, String nluState = 'idle', String nluKind = 'none'}) async {
    // One "now" for the whole message: the rules, the AI's context and the
    // reading of its answer never disagree about today (e.g. at midnight).
    final now = services.now();
    List<Command> parse(String t) => parseAll(t, data.ledger, tasks: data.tasks, contacts: data.contacts, folders: folderHints, now: now, data: data);
    var rules = parse(said);
    // Spoken: the recogniser's other guesses for the same sentence.
    final voice = services.voice;
    final alts = voice.lastHeard.trim() == said.trim() ? voice.lastAlternatives : const <String>[];
    if (alts.isNotEmpty && _weak(rules)) {
      for (final a in alts) {
        final r = parse(a);
        if (!_weak(r)) {
          said = a;
          rules = r;
          break;
        }
      }
    }
    final ruleIntents = intentsOfCommands(rules);
    // "On" mode: the on-phone model's reading, if it is ready (it started when
    // the message came; it usually takes a few tens of milliseconds).
    List<NluPiece>? pieces;
    if (nluMode == 'on' && model != null) {
      try {
        pieces = await model.timeout(const Duration(milliseconds: 500), onTimeout: () => null);
      } catch (_) {}
    }
    final here = _staysHere(rules, said);
    // The rules only half understood ("এই মাসে কী কী দিন আছে", "মেয়ের
    // জন্মদিন কবে"), and the on-phone model is sure of a question or a
    // special day: its reading answers, on the phone — free, no network.
    if (!here && pieces != null && _weak(rules) && !_nluPrivate(said, rules, pieces)) {
      final phone = phoneModelCommands(said, pieces, data.ledger, now);
      if (phone != null) {
        Trace.log('nlu', 'phone model answered', {'rules': ruleIntents.join(','), 'model': pieces.map((p) => p.intent).join(',')});
        return (phone, null, 'nlu_phone');
      }
    }
    if (!aiOn) {
      // Without the AI: the cloud reading only where the model and the rules
      // disagree — two readings of three decide.
      if (here || pieces == null || nluAgrees(pieces, ruleIntents) || _nluPrivate(said, rules, pieces)) return (rules, null, 'rules');
      final got = await _cloudReading(said, pieces, nluState, nluKind);
      if (got == null) return (rules, null, 'nlu_cloud_fail');
      final (cloud, names) = got;
      if (nluVote(ruleIntents, pieces, cloud) == 'rules') return (rules, null, 'nlu_cloud_rules');
      final cmds = commandsFromReading(said, cloud, data.ledger, now, names: names);
      Trace.log('nlu', 'cloud reading', {'rules': ruleIntents.join(','), 'cloud': cloud.intents.join(','), 'used': cmds != null});
      return cmds == null ? (rules, null, 'nlu_cloud_rules') : (cmds, null, 'nlu_cloud');
    }
    if (here) return (rules, null, 'rules');
    // The rules and the model read the same action: the AI is not asked.
    if (nluMaySkipAi(pieces, ruleIntents)) return (rules, null, 'nlu_agree');
    try {
      final clean = stripAddress(said).$1;
      var text = clean.isEmpty ? said : clean;
      final others = [for (final a in alts) if (a.trim() != said.trim() && !mentionsSecret(a)) a];
      if (others.isNotEmpty) text = '$text\n[speech recogniser also heard: ${others.take(3).join(' | ')}]';
      final ctx = aiContext(now: now, shown: shown);
      // The rules already understood something: the AI gets a few seconds,
      // not twenty — a slow network should not keep the user waiting on
      // "ভাবছি…" for what the phone can do itself (owner, 26 Oct).
      final asking = services.ai.route(text, ctx, history: history, fast: fast);
      final AiRoute? r;
      if (_weak(rules)) {
        r = await asking;
      } else {
        var late = false;
        r = await asking.timeout(aiPatience, onTimeout: () {
          late = true;
          return null;
        });
        if (late) {
          asking.ignore();
          Trace.log('understood', 'the AI was slow — the phone\'s own reading', {'rules': ruleIntents.join(',')});
          ErrorLog.problem('AiSlow', 'no answer in ${aiPatience.inSeconds}s');
          return (rules, null, 'ai_slow');
        }
      }
      if (r == null) return (rules, null, 'rules');
      var cmds = commandsFromAi(said, r, data.ledger, now: now);
      var source = services.ai.lastModel.contains('sonnet') ? 'sonnet' : 'haiku';
      // Haiku could not make it out (nothing usable): Sonnet once, Pro only.
      if (_lost(cmds) && canEscalate) {
        try {
          final r2 = await services.ai.route(text, ctx, history: history, fast: fast, escalate: true);
          final c2 = r2 == null ? const <Command>[] : commandsFromAi(said, r2, data.ledger, now: now);
          if (!_lost(c2)) {
            cmds = c2;
            source = 'sonnet';
          }
        } on AiError catch (_) {}
      }
      // The rules plainly heard "remind me" but the AI read a question about
      // saved reminders: a request wins over a search.
      final ruleReminder = rules.whereType<ReminderAdd>().firstOrNull;
      if (ruleReminder != null && cmds.any((c) => c is ReminderQuery) && !cmds.any((c) => c is ReminderAdd)) {
        cmds = [for (final c in cmds) c is ReminderQuery ? ruleReminder : c];
      }
      return (cmds.isEmpty ? rules : cmds, null, source);
    } on AiError catch (e) {
      ErrorLog.problem('AiError', e.code.isEmpty ? 'unknown' : e.code);
      return (rules, '${e.message} নিজের নিয়মে বুঝে নিলাম।', 'failed');
    }
  }

  /// Readings the phone settles by itself — the AI and the cloud are never
  /// asked about these (to-dos, reminders, money answers, secrets, numbers…).
  bool _staysHere(List<Command> rules, String said) {
    // The to-do list and reminders are decided on the phone, by the same
    // rules typed or spoken: when they found what is wanted, the AI is not
    // asked (one reading, one action — never a second one from the AI).
    if (rules.any(_decidedHere)) return true;
    // Money is counted from the saved book, never put into words by the AI
    // (it could make up an amount); a question that needs a choice is asked.
    if (rules.length == 1 && (rules.first is MoneyListQuery || rules.first is Clarify || rules.first is LedgerQuery || rules.first is CashQuery)) return true;
    // "রবিনের কাছে ৫০০০ টাকা পাই": a balance said plainly — the rules read it
    // whole; asking the AI only cost seconds and came back as a loan whose
    // kind had to be asked again (owner's recording, 26 Oct).
    if (rules.length == 1 && rules.first is LedgerSet) return true;
    // "ইমরান ১০ হাজার দিয়েছে, শুধু নোট করে রাখো": the place the user named
    // wins on the phone — the AI never turns it into a money record.
    if (rules.length == 1 && rules.first is NoteAdd && !(rules.first as NoteAdd).fromStatement) return true;
    // "কোনো কাজ বাকি নেই" and other answers worked out here: amounts, what is
    // left, a category's entries — counted from the records, not by the AI.
    if (rules.length == 1 && rules.first is AiReply) return true;
    // "নোট খোলো": opening a page needs no AI; blood group, allergies and
    // what photos are kept stay on the phone.
    if (rules.length == 1 && (rules.first is OpenPlace || rules.first is ProfileQuery || rules.first is ProfileSet || rules.first is ManageItem)) return true;
    // An alarm is understood on the phone at once (no waiting for the AI).
    if (rules.length == 1 && rules.first is ReminderAdd && (rules.first as ReminderAdd).alarm) return true;
    if (mentionsSecret(said) || rules.any((c) => c is VaultQuery)) return true;
    // A phone number in the sentence: understood on the phone (numbers never go to the AI).
    if (findPhone(said) != null) return true;
    // Listing the saved numbers needs no AI (and numbers never go to it).
    if (rules.length == 1 && rules.first is ContactsQuery) return true;
    if (rules.length == 1 && rules.first is SmallTalk && {Talk.time, Talk.date}.contains((rules.first as SmallTalk).kind)) return true;
    return false;
  }

  /// Health and medicine stay on the phone (never sent for a cloud reading).
  static final _healthWords = RegExp(r'(ওষুধ|ঔষধ|ট্যাবলেট|ক্যাপসুল|ইনসুলিন|প্রেশার|প্রেসার|ডায়াবেটিস|ডায়াবেটিস|সুগার|রক্ত|ডাক্তার|হাসপাতাল|অসুখ|জ্বর|ওজন|পালস|bp\b|sugar|medicine|doctor)', caseSensitive: false);

  bool _nluPrivate(String said, List<Command> rules, List<NluPiece> pieces) =>
      _healthWords.hasMatch(said) ||
      rules.any((c) => c is HealthAdd || c is HealthQuery || c is VaultAdd || c is VaultQuery) ||
      pieces.any((p) => const {'health_add', 'menu_health', 'menu_medicine', 'vault_add', 'vault_query', 'contact_add'}.contains(p.intent));

  /// The server's cloud reading (POST /nlu/resolve), names taken out first.
  Future<(CloudReading, Map<String, String>)?> _cloudReading(String said, List<NluPiece> pieces, String state, String kind) async {
    final session = services.ai.session;
    if (session.isEmpty || !services.server.configured) return null;
    final names = <String, String>{};
    final text = delexicalize(said, [
      for (final e in data.ledger) e.person,
      for (final c in data.contacts) c.name,
      for (final p in pieces)
        if (p.slots['person'] != null) p.slots['person']!,
    ], found: names);
    if (text == null) return null;
    try {
      final r = await services.server.send('POST', '/nlu/resolve', session, {
        'text': text,
        'state': state,
        'kind': kind,
        'top': [for (final p in pieces) {'intent': p.intent, 'conf': double.parse(p.conf.toStringAsFixed(3))}],
        'local_conf': pieces.map((p) => p.conf).reduce((a, b) => a < b ? a : b),
        if (nluSamplesOn) 'consent_ver': nluConsentVer,
        'app_ver': nluAppVersion,
        'model_ver': 'bundled-1',
      }).timeout(const Duration(seconds: 8));
      if (r.status != 200) return null;
      return (CloudReading.fromJson(r.data), names);
    } catch (_) {
      return null;
    }
  }

  /// To-do and reminder commands the rules settle by themselves.
  static bool _decidedHere(Command c) =>
      c is TaskAdd || c is TaskEdit || c is TaskDone || c is TaskQuery || c is TaskRestore || c is TasksClear || c is ReminderAdd || c is ReminderSnooze || c is Clarify || c is MenuAction || c is BulkAction;

  /// The AI's reading gave nothing to act on.
  static bool _lost(List<Command> c) => c.isEmpty || c.every((x) => x is NotUnderstood);

  /// Rules that only half understood: nothing, a search, or a plain note.
  static bool _weak(List<Command> c) => c.length == 1 && (c.first is NotUnderstood || c.first is SearchQuery || c.first is NoteAdd);

  /// The user's own paper folders and note categories, for "… ফোল্ডার খোলো".
  List<FolderHint> get folderHints => [
        for (final f in {for (final d in data.docs) d.folder}) if (!docFolderWords.containsKey(f)) FolderHint('docs', f),
        for (final c in data.noteCategories) FolderHint('notes', c),
      ];

  Future<void> load() async {
    try {
      services.ai.key = await services.lock.keys.read('claude_api_key') ?? '';
      // Haiku for everyone; Sonnet only by escalation (an old "best" setting is not used).
      services.ai.quality = AiQuality.fast;
      aiShareData = (await services.lock.keys.read('ai_share_data')) != 'false';
      userName = await services.lock.keys.read('user_name') ?? '';
      askUserName = userName;
      district = await services.lock.keys.read('district') ?? 'ঢাকা';
      askPlace = district;
      autoPlace = (await services.lock.keys.read('auto_place')) != 'false';
    } catch (_) {}
    try {
      services.voice.muted = (await services.lock.keys.read('speak_on')) == 'false';
      services.voice.bargeIn = (await services.lock.keys.read('barge_in')) == 'true';
      services.notifier.insistent = (await services.lock.keys.read('alarm_insistent')) != 'false';
      services.notifier.soundUri = await services.lock.keys.read('alarm_sound');
      alarmSoundTitle = await services.lock.keys.read('alarm_sound_title') ?? '';
      services.notifier.batteryConfirmed = (await services.lock.keys.read('battery_done')) == 'true';
      services.voice.preferredVoice = await services.lock.keys.read('tts_voice');
    } catch (_) {}
    await loadLook();
    await _loadPrefs();
    await _loadSources();
    await _loadPro();
    await _loadAccount();
    // Yesterday's (and older) answer-source counts: sent once, quietly.
    unawaited(sendAnswerSources().catchError((_) {}));
    unawaited(loadNluConfig().then((_) => sendNluSamples()).then((_) => updateNluModelFromServer()).catchError((_) {}));
    // ফ্যামিলি: what family members sent, location sharing and the heirs' copy (signed in only).
    if (signedIn) unawaited(family.refresh().catchError((_) {}));
    unawaited((autoPlace ? askPlacePermission(once: true) : Future<void>.value()).then((_) => refreshPlace()).catchError((_) => null));
    await _loadServerNotices();
    await _loadNoticeLog();
    try {
      data = await services.store.load();
      loadError = null;
      try {
        photo = await services.store.loadDocFile(_photoId);
      } catch (_) {}
    } catch (e, st) {
      loadError = '$e';
      ErrorLog.problem('DataLoad', e.runtimeType.toString(), st: st);
    }
    loaded = true;
    notifyListeners();
    await carryOverTasks();
    if (loadError == null) await markOpened();
    if (loadError == null) await purgeTrash();
    refreshAccount();
    await _reschedule();
    if (loadError == null) await _showStanding();
  }

  void unlock() {
    unlocked = true;
    unlockedOnce = true;
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
    // The saved data could not be opened: never write over it (only a
    // restore the user chose may replace it).
    if (loadError != null) return;
    await services.store.save(data);
    if (driveOn && !_driveDirty) {
      _driveDirty = true;
      try {
        await services.lock.keys.write('drive_dirty', 'true');
      } catch (_) {}
    }
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
    _oneOff.removeWhere((n) => !n.at.isAfter(now.subtract(const Duration(minutes: 1))));
    final all = [...plannedNotices(data.reminders, now), ...assistantNotices(data, now, assistantPrefs), ..._oneOff];
    _updateWidget(now);
    _notePlan(all, now);
    return _scheduling = _scheduling.then((_) async {
      await services.notifier.schedule(all);
      scheduleFailed = false;
    }).catchError((Object _) {
      // The phone refused: said where a reminder is promised, never hidden.
      scheduleFailed = true;
    });
  }

  /// The last try to hand the reminders to the phone failed.
  bool scheduleFailed = false;

  // ── নোটিফিকেশন page: coming up and already shown ──

  /// The next seven days of notifications, soonest first.
  List<NoticeEvent> noticePlan = [];

  /// Those already shown (their time came), newest first, 30 days.
  List<NoticeEvent> noticeHistory = [];
  DateTime? _noticePlanAt;
  String _noticeSaved = '';
  String _planSent = '';
  DateTime? _planSentAt;

  Future<void> _loadNoticeLog() async {
    try {
      final raw = await services.lock.keys.read('notice_log');
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      noticePlan = [...(j['plan'] as List? ?? const []).map(NoticeEvent.fromJson).whereType<NoticeEvent>()];
      noticeHistory = [...(j['history'] as List? ?? const []).map(NoticeEvent.fromJson).whereType<NoticeEvent>()];
      _noticePlanAt = DateTime.tryParse('${j['at']}');
      _noticeSaved = raw;
    } catch (_) {}
  }

  void _notePlan(List<PlannedNotice> all, DateTime now) {
    noticeHistory = addPassed(noticeHistory, noticePlan, _noticePlanAt, now);
    noticePlan = expandPlan(all, now);
    _noticePlanAt = now;
    final raw = jsonEncode({
      'at': now.toIso8601String(),
      'plan': [for (final e in noticePlan.take(250)) e.toJson()],
      'history': [for (final e in noticeHistory) e.toJson()],
    });
    if (raw != _noticeSaved) {
      _noticeSaved = raw;
      unawaited(services.lock.keys.write('notice_log', raw).catchError((_) {}));
    }
    unawaited(_sendPlan(now).catchError((_) {}));
  }

  /// Tells our server what this member's phone will show (kind and time
  /// only): when it changed, or every six hours at most otherwise.
  Future<void> _sendPlan(DateTime now) async {
    final session = services.ai.session;
    if (session.isEmpty) return;
    final items = planForServer(noticePlan);
    final sig = jsonEncode(items.map((e) => '${e['kind']}@${e['at']}').toList());
    final fresh = _planSentAt != null && now.difference(_planSentAt!) < const Duration(hours: 6);
    if (sig == _planSent && fresh) return;
    _planSent = sig;
    _planSentAt = now;
    final r = await services.server.send('POST', '/notices/plan', session, {'items': items});
    if (!r.ok) _planSent = '';
  }

  /// Pushes our server sent this member (for the নোটিফিকেশন page).
  Future<List<PushRecord>> pushLog() async {
    final session = services.ai.session;
    if (session.isEmpty) return const [];
    final r = await services.server.send('GET', '/notices/log', session);
    if (!r.ok) return const [];
    return [...((r.data['pushes'] as List?) ?? const []).map(PushRecord.fromJson).whereType<PushRecord>()];
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
    // A pay-back day: a reminder (a day before, and on the day at 10:00).
    final old = data.ledger.where((y) => y.id == x.id).firstOrNull;
    final oldRem = old?.reminderId ?? x.reminderId;
    if (oldRem != null) data.reminders.removeWhere((r) => r.id == oldRem);
    x = x.copyWith(clearReminder: true);
    // The day is always kept; its reminder counts toward the 20 free ones
    // (owner, 24 Oct: money reminders too).
    if (x.due != null && (x.kind == LedgerKind.lent || x.kind == LedgerKind.borrowed) && has(ProFeature.dueReminders) && canAddReminder) {
      final r = _dueReminder(x);
      data.reminders.add(r);
      x = x.copyWith(reminderId: r.id);
    }
    _upsert(data.ledger, x, (y) => y.id);
    lastMainLine = await _intoMain(x.id);
    final pk = phoneKey(x.phone);
    if (pk.isNotEmpty && !data.contacts.any((c) => phoneKey(c.phone) == pk)) {
      data.contacts.add(Contact(name: x.person.trim(), phone: asciiDigits(x.phone.trim()), note: 'লেনদেন', updatedAt: services.now()));
    }
    await _save();
    if (oldRem != null || x.reminderId != null) await _reschedule();
  }

  // ── মুছে ফেলা: deleted things kept 30 days ──

  /// Keeps what is being deleted: [items] are (list key, JSON), the thing
  /// itself first. Its [files] stay on the phone until it is gone for good.
  void _trash(String title, List<(String, Map<String, Object?>)> items, {List<String> files = const []}) {
    if (items.isEmpty) return;
    data.trash.add(TrashItem(kind: items.first.$1, title: title, deletedAt: services.now(), items: items, files: files));
  }

  /// Brings a deleted thing back, with what went with it.
  Future<void> restoreTrash(TrashItem t) async {
    final j = data.toJson();
    for (final (k, item) in t.items) {
      final list = [...((j[k] as List?) ?? const [])]..removeWhere((x) => x is Map && x['id'] == item['id']);
      list.add(item);
      j[k] = list;
    }
    final keep = [for (final x in data.trash) if (x.id != t.id) x];
    final next = AppData.fromJson(j);
    next.trash
      ..clear()
      ..addAll(keep);
    data = next;
    await _save();
    notifyListeners();
    await _reschedule();
  }

  /// "ফিরিয়ে আনুন" right after deleting: the newest thing in মুছে ফেলা.
  Future<void> undoLastDelete() async {
    if (data.trash.isNotEmpty) await restoreTrash(data.trash.last);
  }

  /// "ফিরিয়ে আনুন" after deleting [n] picked rows at once.
  Future<void> undoLastDeletes(int n) async {
    for (var i = 0; i < n && data.trash.isNotEmpty; i++) {
      await restoreTrash(data.trash.last);
    }
  }

  /// Gone for good (with its files).
  Future<void> forgetTrash(TrashItem t) async {
    for (final f in t.files) {
      await services.store.deleteDocFile(f);
    }
    data.trash.removeWhere((x) => x.id == t.id);
    await _save();
    notifyListeners();
  }

  Future<void> emptyTrash() async {
    for (final t in [...data.trash]) {
      for (final f in t.files) {
        await services.store.deleteDocFile(f);
      }
    }
    data.trash.clear();
    await _save();
    notifyListeners();
  }

  /// Things deleted more than 30 days ago go for good.
  Future<void> purgeTrash() async {
    final cutoff = services.now().subtract(const Duration(days: TrashItem.keepDays));
    final old = [for (final t in data.trash) if (t.deletedAt.isBefore(cutoff)) t];
    if (old.isEmpty) return;
    for (final t in old) {
      for (final f in t.files) {
        await services.store.deleteDocFile(f);
      }
    }
    data.trash.removeWhere((t) => old.contains(t));
    await _save();
  }

  List<(String, Map<String, Object?>)> _remindersJson(Iterable<String?> ids) =>
      [for (final r in data.reminders) if (ids.contains(r.id)) ('reminders', r.toJson())];

  Future<void> deleteEntry(String id) async {
    final e = data.ledger.where((e) => e.id == id).firstOrNull;
    final copy = data.cash.where((c) => c.linkId == id && c.projectId == null).firstOrNull;
    if (e != null) _trash('${e.person} · ${e.kind.label} ${taka(e.amount)}', [('ledger', e.toJson()), ..._remindersJson([e.reminderId]), if (copy != null) ('cash', copy.toJson())]);
    final rem = e?.reminderId;
    data.ledger.removeWhere((e) => e.id == id);
    if (copy != null) data.cash.removeWhere((c) => c.id == copy.id);
    if (rem != null) data.reminders.removeWhere((r) => r.id == rem);
    await _save();
    if (rem != null) await _reschedule();
  }

  Future<void> saveVault(VaultItem v) async {
    // The date it was put in stays; a replaced password is kept, faded (logic/vault_age.dart).
    v = vaultToSave(data.vault.where((x) => x.id == v.id).firstOrNull, v, services.now());
    _upsert(data.vault, v, (x) => x.id);
    await _save();
  }

  Future<void> deleteVault(String id) async {
    for (final v in data.vault.where((e) => e.id == id)) {
      _trash(v.name, [('vault', v.toJson())]);
    }
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

  Future<void> saveContact(Contact c0) async {
    final c = c0.files.isEmpty ? c0 : Contact(id: c0.id, name: c0.name, phone: c0.phone, email: c0.email, note: c0.note, updatedAt: c0.updatedAt, address: c0.address, files: _withReadText(c0.files));
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
    // Its files stay until it is gone from মুছে ফেলা for good.
    for (final c in data.contacts.where((e) => e.id == id)) {
      _trash(c.name, [('contacts', c.toJson())], files: [for (final f in c.files) f.id]);
    }
    data.contacts.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> saveNote(Note n0) async {
    final n = n0.files.isEmpty ? n0 : Note(id: n0.id, title: n0.title, body: n0.body, category: n0.category, updatedAt: n0.updatedAt, files: _withReadText(n0.files));
    _upsert(data.notes, n, (x) => x.id);
    await _save();
  }

  Future<void> deleteNote(String id) async {
    for (final n in data.notes.where((e) => e.id == id)) {
      _trash(n.title.isEmpty ? n.body : n.title, [('notes', n.toJson())], files: [for (final f in n.files) f.id]);
    }
    data.notes.removeWhere((e) => e.id == id);
    await _save();
  }

  /// Keeps a photo or file encrypted on the phone (for a note, a contact or
  /// a document). Every photo or PDF is also read on the phone: [text] when
  /// already read, else in the background — its words kept with it.
  Future<DocFile> keepFile(PickedDoc f, {String? text}) async {
    final file = DocFile(name: f.name, mime: f.mime, size: f.bytes.length, text: text ?? '');
    await services.store.saveDocFile(file.id, f.bytes);
    if (text == null && readable(f.mime)) {
      _reading = _reading.then((_) async {
        final t = await services.ocr.read(f.bytes, mime: f.mime);
        if (t != null && t.trim().isNotEmpty) await _keepFileText(file.id, t.trim());
      });
    }
    return file;
  }

  /// Reads in the background one after another (and tests can wait for it).
  Future<void> _reading = Future.value();
  Future<void> get readingDone => _reading;

  /// What a kept file says, put with it wherever it is: a document also gets
  /// the facts found in it (new ones only — never over what the user wrote)
  /// and its expiry when it has none.
  /// Text read for files not yet in a saved note/contact/document (the
  /// form is still open): put in when it is saved.
  final _fileTexts = <String, String>{};

  List<DocFile> _withReadText(List<DocFile> fs) => [for (final f in fs) f.text.isEmpty && _fileTexts[f.id] != null ? f.withText(_fileTexts[f.id]!) : f];

  Future<void> _keepFileText(String fileId, String text) async {
    _fileTexts[fileId] = text;
    List<DocFile> withIt(List<DocFile> fs) => [for (final f in fs) f.id == fileId ? f.withText(text) : f];
    for (final d in [...data.docs]) {
      if (!d.files.any((f) => f.id == fileId)) continue;
      final files = withIt(d.files);
      final all = [for (final f in files) if (f.text.isNotEmpty) f.text].join('\n');
      var next = d.copyWith(files: files, text: all, fields: mergeFields(d.fields, docFieldsIn(all)));
      _upsert(data.docs, next, (x) => x.id);
      final exp = d.expiry == null ? docDateIn(all, services.now()) : null;
      if (exp != null) next = await setDocExpiry(next, exp.date);
    }
    for (final (i, n) in [...data.notes].indexed) {
      if (!n.files.any((f) => f.id == fileId)) continue;
      data.notes[i] = Note(id: n.id, title: n.title, body: n.body, category: n.category, updatedAt: n.updatedAt, files: withIt(n.files));
    }
    for (final (i, c) in [...data.contacts].indexed) {
      if (!c.files.any((f) => f.id == fileId)) continue;
      data.contacts[i] = Contact(id: c.id, name: c.name, phone: c.phone, email: c.email, note: c.note, updatedAt: c.updatedAt, address: c.address, files: withIt(c.files));
    }
    await _save();
    notifyListeners();
  }

  Future<void> dropFile(DocFile f) => services.store.deleteDocFile(f.id);

  /// Several photos or files at once: all in one document ([info] gives its
  /// name, folder and description), returned saved.
  Future<Doc> addDocGroup(List<PickedDoc> picked, Doc info, {List<String?> texts = const []}) async {
    final files = <DocFile>[...info.files];
    for (final (i, f) in picked.indexed) {
      files.add(await keepFile(f, text: i < texts.length ? texts[i] : null));
    }
    final d = info.copyWith(files: files);
    await saveDoc(d);
    return d;
  }

  // ── Documents ──

  Future<void> saveDoc(Doc d0) async {
    final d = d0.files.isEmpty ? d0 : d0.copyWith(files: _withReadText(d0.files));
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

  // ── ডকুমেন্টস › ব্যাংক কার্ড (owner, 28 Oct) ──

  /// A card photo, kept encrypted like a document's page — never read for
  /// text (the number would end up searchable).
  Future<DocFile> keepCardPhoto(PickedDoc f) => keepFile(f, text: '');

  Future<void> saveCard(BankCard c) async {
    final old = data.cards.where((x) => x.id == c.id).firstOrNull;
    // A photo replaced: the old one goes.
    for (final (was, now) in [(old?.front, c.front), (old?.back, c.back)]) {
      if (was != null && was.id != now?.id) await services.store.deleteDocFile(was.id);
    }
    _upsert(data.cards, c, (x) => x.id);
    await _save();
  }

  Future<void> deleteCard(String id) async {
    for (final c in data.cards.where((x) => x.id == id)) {
      _trash('${c.bank} ${c.kind.label}', [('cards', c.toJson())], files: [if (c.front != null) c.front!.id, if (c.back != null) c.back!.id]);
    }
    data.cards.removeWhere((x) => x.id == id);
    await _save();
  }

  Future<void> deleteDoc(Doc d) async {
    _trash(d.title, [('docs', d.toJson()), ..._remindersJson([d.reminderId])], files: [for (final f in d.files) f.id]);
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
    // The date is always kept; its reminder counts toward the 20 free ones.
    if (expiry != null && has(ProFeature.docAlerts) && canAddReminder) {
      final r = _expiryReminder(next);
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
    // Switched off while it rings (or with a snooze pending): quiet at once.
    if (!r.enabled) await services.notifier.stopRinging(r.id);
    if (r.enabled) await services.notifier.requestPermission();
    await _reschedule();
  }

  /// [trash]: kept in মুছে ফেলা (not when it simply rang for the last time).
  Future<void> deleteReminder(String id, {bool trash = true}) async {
    if (trash) {
      for (final r in data.reminders.where((e) => e.id == id)) {
        _trash(r.title, [('reminders', r.toJson())]);
      }
    }
    data.reminders.removeWhere((e) => e.id == id);
    await _save();
    await services.notifier.stopRinging(id);
    await _reschedule();
  }

  /// "মিটিংয়ের রিমাইন্ডার বন্ধ করো": switched off, kept (turn on again from its page).
  Future<void> switchOffReminder(String id) async {
    final r = reminderById(id);
    if (r != null) await saveReminder(r.copyWith(enabled: false));
  }

  /// "আর বাজাবে না": an alarm is switched off (kept on the alarm page);
  /// any other reminder is removed. Either way it never rings again.
  Future<void> stopReminder(String id) async {
    final r = reminderById(id);
    if (r == null) {
      await services.notifier.stopRinging(id);
      await _reschedule();
      return;
    }
    if (r.alarm) {
      await saveReminder(r.copyWith(enabled: false));
    } else {
      await deleteReminder(id, trash: false);
    }
  }

  /// Done once the data has been read (a notification may open the app first).
  Future<void> whenLoaded() async {
    while (!loaded) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
  }

  Future<void> saveTask(Task t) async {
    _upsert(data.tasks, t, (x) => x.id);
    await _save();
  }

  Future<void> deleteTask(String id) async {
    // Its ⏰ reminder goes with it.
    final t = data.tasks.where((e) => e.id == id).firstOrNull;
    final rid = t?.reminderId;
    if (t != null) _trash(t.title, [('tasks', t.toJson()), ..._remindersJson([rid])]);
    data.tasks.removeWhere((e) => e.id == id);
    await _save();
    if (rid != null && data.reminders.any((r) => r.id == rid)) await deleteReminder(rid, trash: false);
  }

  /// Ticks a to-do (or opens it again). A repeating one is never "done":
  /// this time is recorded and it moves on to the next time it is due.
  Future<void> setTaskDone(Task t, bool done) {
    final r = t.repeat;
    if (r != null && done) {
      final now = services.now();
      final due = t.due ?? r.nextOnOrAfter(now);
      return saveTask(t.copyWith(done: false, doneAt: now, due: r.after(due)));
    }
    // Done: its own one-time reminder still ahead is turned off (it would
    // only ring about something finished). Opened again: left off.
    final rid = t.reminderId;
    if (done && rid != null) {
      final rem = reminderById(rid);
      if (rem != null && rem.enabled && rem.repeat == Repeat.none && DateTime(rem.date.year, rem.date.month, rem.date.day, rem.hour, rem.minute).isAfter(services.now())) {
        return saveTask(t.copyWith(done: true, doneAt: services.now())).then((_) => switchOffReminder(rid));
      }
    }
    return saveTask(t.copyWith(done: done, doneAt: done ? services.now() : null));
  }

  /// "এই শুক্রবারটা বাদ দাও": one time of a repeating to-do is skipped.
  Future<void> skipTaskOnce(Task t) {
    final r = t.repeat;
    if (r == null || t.due == null) return Future.value();
    return saveTask(t.copyWith(due: r.after(t.due!)));
  }

  List<Task> openTasks() => openTasksOf(data, services.now());

  Future<void> saveCash(CashEntry e) async {
    // A new own entry with accounts kept goes into one (so "এখন আছে", their
    // total, follows it): the cash account, else the first.
    final isNew = !data.cash.any((x) => x.id == e.id);
    if (isNew) {
      final a = e.projectId == null && e.accountId == null ? defaultAccountId(data) : e.accountId;
      e = CashEntry(id: e.id, kind: e.kind, amount: e.amount, category: e.category, note: e.note, date: e.date, projectId: e.projectId, accountId: a, shopId: e.shopId, linkId: e.linkId, addedAt: e.addedAt ?? services.now());
    } else {
      final was = data.cash.firstWhere((x) => x.id == e.id);
      if (e.addedAt == null && was.addedAt != null) {
        e = CashEntry(id: e.id, kind: e.kind, amount: e.amount, category: e.category, note: e.note, date: e.date, projectId: e.projectId, accountId: e.accountId, shopId: e.shopId, linkId: e.linkId, addedAt: was.addedAt);
      }
    }
    _upsert(data.cash, e, (x) => x.id);
    lastMainLine = e.projectId != null ? await _intoMain(e.id) : null;
    await _save();
  }

  Future<void> deleteCash(String id) async {
    // Another হিসাব's entry takes its main-account copy with it (one undo).
    final copy = data.cash.where((e) => e.linkId == id && e.projectId == null && e.id != id).firstOrNull;
    for (final e in data.cash.where((e) => e.id == id)) {
      _trash('${e.category} · ${taka(e.amount)}', [('cash', e.toJson()), if (copy != null) ('cash', copy.toJson())]);
    }
    data.cash.removeWhere((e) => e.id == id || (copy != null && e.id == copy.id));
    await _save();
  }

  Future<void> saveShop(Shop s) async {
    _upsert(data.shops, s, (x) => x.id);
    await _save();
  }

  /// Removes a shop and its receipts. Its sales stay in আয়-ব্যয় (with the
  /// first remaining shop, if any).
  Future<void> deleteShop(String id) async {
    data.shops.removeWhere((x) => x.id == id);
    data.receipts.removeWhere((r) => r.shopId == id);
    for (var i = 0; i < data.cash.length; i++) {
      final e = data.cash[i];
      if (e.shopId == id) {
        data.cash[i] = CashEntry(id: e.id, kind: e.kind, amount: e.amount, category: e.category, note: e.note, date: e.date, projectId: e.projectId, accountId: e.accountId, linkId: e.linkId);
      }
    }
    for (var i = 0; i < data.ledger.length; i++) {
      final e = data.ledger[i];
      if (e.shopId == id) {
        data.ledger[i] = LedgerEntry(id: e.id, person: e.person, phone: e.phone, kind: e.kind, amount: e.amount, date: e.date, note: e.note, createdAt: e.createdAt, due: e.due, reminderId: e.reminderId);
      }
    }
    await _save();
  }

  Future<void> deleteReceipt(String id) async {
    data.receipts.removeWhere((r) => r.id == id);
    await _save();
  }

  Future<void> saveReceipt(Receipt r) async {
    _upsert(data.receipts, r, (x) => x.id);
    await _save();
  }

  Future<void> saveProject(Project p) async {
    _upsert(data.projects, p, (x) => x.id);
    await _save();
  }

  /// Removes a project and its entries.
  Future<void> deleteProject(String id) async {
    for (final p in data.projects.where((e) => e.id == id)) {
      _trash(p.name, [
        ('projects', p.toJson()),
        for (final c in data.cash) if (c.projectId == id) ('cash', c.toJson()),
        for (final l in data.ledger) if (l.projectId == id) ('ledger', l.toJson()),
      ]);
    }
    data.projects.removeWhere((e) => e.id == id);
    data.cash.removeWhere((e) => e.projectId == id);
    final dueRems = {for (final l in data.ledger) if (l.projectId == id && l.reminderId != null) l.reminderId};
    data.ledger.removeWhere((e) => e.projectId == id);
    data.reminders.removeWhere((r) => dueRems.contains(r.id));
    await _save();
    if (dueRems.isNotEmpty) await _reschedule();
  }

  /// Whether [id]'s entries go into the main আয়-ব্যয় — the user's answer.
  /// Its entries already written follow at once (in, or taken out).
  Future<void> setProjectMain(String id, bool inMain) async {
    final p = data.projects.where((x) => x.id == id).firstOrNull;
    if (p == null) return;
    _upsert(data.projects, p.copyWith(inMain: inMain, mainAsked: true), (x) => x.id);
    for (final c in [...data.cash.where((e) => e.projectId == id)]) {
      await _intoMain(c.id);
    }
    lastMainLine = null;
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
  /// Puts a backup in place of everything. The attached files are written
  /// first; if anything fails before the new data is saved, the data on the
  /// phone stays exactly as it was.
  Future<void> replaceAll(AppData restored, {Map<String, Uint8List> files = const {}}) async {
    if (loadError != null) await services.store.startOverKeepingOld();
    for (final e in files.entries) {
      await services.store.saveDocFile(e.key, e.value);
    }
    final before = data;
    data = restored;
    try {
      await services.store.save(data);
    } catch (_) {
      data = before;
      rethrow;
    }
    loadError = null;
    try {
      photo = await services.store.loadDocFile(_photoId);
    } catch (_) {}
    notifyListeners();
    await _reschedule();
  }

  /// Every attached photo and file, for the backup (ones that cannot be read are left out).
  Future<Map<String, Uint8List>> backupFiles() async {
    final out = <String, Uint8List>{};
    for (final id in {...attachedFileIds(data), _photoId}) {
      try {
        final b = await services.store.loadDocFile(id);
        if (b != null) out[id] = b;
      } catch (_) {}
    }
    return out;
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
