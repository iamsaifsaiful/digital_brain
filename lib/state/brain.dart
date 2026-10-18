import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';

import '../services/ocr.dart';
import '../services/trace.dart';

import '../logic/ai_map.dart';
import '../logic/app_map.dart';
import '../logic/ask.dart';
import '../logic/money_more.dart' show ZakatSaved, MetalPrice;
import '../logic/manage.dart';
import '../logic/me.dart';
import '../logic/phrases.dart' show possessive;
import '../logic/answers.dart';
import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/health.dart';
import '../logic/ledger.dart';
import '../logic/parser.dart';
import '../logic/plan.dart';
import '../logic/proactive.dart';
import '../logic/pro.dart';
import '../logic/server_notices.dart';
import '../logic/when.dart' show sayWhen;
import '../models/models.dart';
import '../services/ai.dart';
import '../services/community.dart';
import '../services/crypto.dart' show WrongKey;
import '../services/data_store.dart';
import '../services/files.dart';
import '../services/inbox.dart';
import '../services/google_account.dart';
import '../services/push.dart';
import '../services/launcher.dart';
import '../services/lock.dart';
import '../services/notifications.dart';
import '../services/phonebook.dart';
import '../services/voice.dart';
import '../services/platform.dart';
import '../logic/calendar_bd.dart';
import '../ui/theme.dart' show Look;
import '../logic/inbox.dart' show secretMessage;
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
    InboxSource? inbox,
    GoogleAccount? google,
    PushSource? push,
    DriveStore? drive,
    AccountServer? server,
    TextReader? ocr,
    DateTime Function()? clock,
  })  : ai = ai ?? FakeAi(),
        ocr = ocr ?? FakeTextReader(),
        google = google ?? FakeGoogle(),
        push = push ?? FakePush(),
        drive = drive ?? FakeDrive(),
        server = server ?? AccountServer.off(),
        inbox = inbox ?? FakeInbox(),
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

  /// Claude, when the user has set an API key (see আরও).
  final AiBrain ai;

  /// Dialer, SMS and WhatsApp.
  final Launcher launcher;

  /// The phone's own contacts.
  final Phonebook phonebook;

  /// Messages from other apps' notifications.
  final InboxSource inbox;

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

  /// Features are locked only in the Play app; the downloaded APK has all.
  bool get gated => _gated;
  bool _gated = playEdition;
  set gated(bool v) {
    _gated = v;
    notifyListeners();
  }

  /// Pro lasts until this moment.
  DateTime? proUntil;

  /// A plan id ('pro_yearly', 'pro_monthly'), 'web' (bought on the website) or 'test' (preview).
  String proKind = '';

  /// The first day the app was opened (no full-screen ad that day).
  DateTime? firstUse;

  bool get pro => !gated || (proUntil != null && services.now().isBefore(proUntil!));
  bool get showAds => gated && !pro;

  /// The preview draws sample ad spaces (real ads need AdMob).
  bool adSamples = previewEdition;
  bool has(ProFeature f) => pro;
  bool get canAddShop => pro || data.shops.length < freeShops;
  bool get canAddProject => pro || data.projects.where((p) => !p.closed).length < freeProjects;
  bool get canAddVault => pro || data.vault.length < freeVaultItems;
  bool get canAddDoc => pro || data.docs.length < freeDocs;

  /// Reminders that still ring (the app's own ones — bills, papers, habits — count too).
  int get activeReminders => data.reminders.where((r) => r.enabled && r.vaultId == null).length;
  bool get canAddReminder => pro || activeReminders < freeReminders;

  /// A new person in ধার-দেনা (someone already there is always fine).
  bool canAddPerson(String name) {
    if (pro) return true;
    final key = personKey(name);
    final people = {for (final e in data.ledger) personKey(e.person)};
    return people.contains(key) || people.length < freeLedgerPeople;
  }

  /// The first month of the reports a free user can open ([freeReportMonths] back).
  DateTime get firstFreeMonth {
    final n = services.now();
    return DateTime(n.year, n.month - (freeReportMonths - 1));
  }

  bool canSeeMonth(DateTime m) => pro || !DateTime(m.year, m.month).isBefore(firstFreeMonth);

  /// After Google Play confirms a purchase (in the preview, the test button).
  Future<void> activatePro(ProPlan plan) => _setPro(services.now().add(Duration(days: plan.days)), plan.id);

  /// The preview's test switch.
  Future<void> setProForTest(bool on) => on ? _setPro(services.now().add(const Duration(days: 365)), 'test') : _setPro(null, '');

  Future<void> _setPro(DateTime? until, String kind) async {
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
    if (!wasPro && pro) await _addProReminders();
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
      title: x.kind == LedgerKind.lent ? trf('{0} {1} ফেরত দেওয়ার দিন', [x.person, taka(x.amount)]) : trf('{0}-কে {1} শোধের দিন', [x.person, taka(x.amount)]),
      date: dayOnly(x.due!),
      hour: 10,
      daysBefore: 1);

  Reminder _expiryReminder(Doc d) => Reminder(title: '${d.title} — মেয়াদ শেষ', date: d.expiry!, hour: 10, daysBefore: 30);

  Future<void> _loadPro() async {
    final keys = services.lock.keys;
    try {
      proUntil = DateTime.tryParse(await keys.read('pro_until') ?? '');
      proKind = await keys.read('pro_kind') ?? '';
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
          await _setPro(until, info.proKind);
        }
      }
      notifyListeners();
      return null;
    } on GoogleError catch (e) {
      return e.message;
    } catch (e) {
      return 'Google লগইন হয়নি: $e';
    }
  }

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
    // Pro given on the website (or bought on another phone) shows up here too.
    final until = info.proUntil;
    if (gated && until != null && until.isAfter(services.now()) && (proUntil == null || until.isAfter(proUntil!))) {
      await _setPro(until, info.proKind);
    }
    notifyListeners();
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

  Future<void> _loadServerNotices() async {
    try {
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
      try {
        await services.lock.keys.write('srv_notices', jsonEncode([for (final n in list) n.toJson()]));
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
    for (final k in ['g_email', 'g_name', 'drive_on', 'drive_pw', 'drive_key_server', 'srv_session', 'srv_ai', 'srv_pro_until']) {
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
      final bytes = await Backup.export(data, pw, files: await backupFiles());
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

  /// Opens a Drive backup (nothing is replaced yet): with the account's key,
  /// or [password] for a backup made before keys (WrongKey when neither fits).
  Future<(AppData, Map<String, Uint8List>)> openDriveBackup(DriveFile f, {String? password}) async {
    final token = await services.google.driveToken();
    final bytes = await services.drive.download(token, f.id);
    final key = password ?? await services.lock.keys.read('drive_pw');
    if (key == null || key.isEmpty) throw const WrongKey();
    return Backup.restore(bytes, key);
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

  AiContext aiContext({DateTime? now}) => AiContext(
        now: now ?? services.now(),
        people: knownPeople(data.ledger).take(60).toList(),
        categories: aiShareData ? data.noteCategories : const [],
        money: moneySummary(),
        records: aiShareData ? recordsSummary() : '',
      );

  /// The user lets the AI see their reminders, tasks and notes (never
  /// passwords, PINs or anything secret), so it can answer about them.
  bool aiShareData = true;

  /// What the assistant calls the user ("সাইফুল ভাই"); empty = no name.
  String userName = '';

  /// This build can read other apps' messages (see [InboxSource.supported]).
  bool inboxSupported = false;

  /// The place for sunrise, sunset and prayer times (see `bdPlaces`).
  String district = 'ঢাকা';

  Future<void> setUserName(String v) async {
    userName = v.trim();
    askUserName = userName;
    await services.lock.keys.write('user_name', userName);
    notifyListeners();
  }

  Future<void> setDistrict(String v) async {
    district = v;
    askPlace = v;
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
      );

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
  }

  /// The other settings (notification types, quiet hours, Hijri date
  /// correction, prayer reminders…), as saved text. Read with [flag] / [number].
  final Map<String, String> prefs = {};

  /// Saved settings read at start into [prefs].
  static const prefKeys = [
    'hijri_adjust', 'quiet_on', 'quiet_from', 'quiet_to', 'daily_cap', 'n_jumuah', 'n_plan', 'n_smart', 'n_health', 'n_festival', 'n_weekly',
    'n_streak', 'n_comeback', 'n_news', 'n_prayer', 'prayer_set', 'n_ramadan', 'blood_group', 'blood_last', 'donor_on', 'last_open', 'inbox_apps', 'inbox_on', 'last_backup', 'zakat_gold_vori', 'zakat_gold_price', 'zakat_silver_vori', 'zakat_silver_price', 'zakat_business', 'zakat_other', 'g_card_off', 'trace_on',
  ];

  bool flag(String key, [bool or = false]) => prefs[key] == null ? or : prefs[key] == 'true';
  int number(String key, [int or = 0]) => int.tryParse(prefs[key] ?? '') ?? or;
  String text(String key, [String or = '']) => prefs[key] ?? or;

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
        if (key == 'hijri_adjust') hijriAdjust = value as int;
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
      for (final k in prefKeys) {
        final v = await keys.read(k);
        if (v != null) prefs[k] = v;
      }
      // The diagnostic trace: on in development builds, or when the user turned it on.
      Trace.enabled = kDebugMode || prefs['trace_on'] == 'true';
      askZakat = zakatSaved;
      hijriAdjust = number('hijri_adjust');
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
    // Medicines are health data: they stay on the phone (questions about
    // them are answered by the app itself).
    if (data.medicines.isNotEmpty) lines.add('Medicines: kept on the phone only — for any medicine question add a menu/medicine item or reply "দেখছি।".');
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
          '${data.docs.take(40).map((x) => '${x.title} [${x.folder}]'
              '${x.about.isEmpty ? '' : ' — ${x.about}'}${x.people.isEmpty ? '' : ', people: ${x.people}'}${x.place.isEmpty ? '' : ', place: ${x.place}'}'
              '${x.taken == null ? '' : ', date ${day(x.taken!)}'}, ${x.files.length} files'
              '${x.expiry == null ? '' : ' expires ${day(x.expiry!)}'}').join('; ')}');
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

  /// What the user entered on the যাকাত page (gold, silver, stock…).
  ZakatSaved get zakatSaved => ZakatSaved(
        goldVori: double.tryParse(text('zakat_gold_vori')) ?? 0,
        goldPrice: number('zakat_gold_price'),
        silverVori: double.tryParse(text('zakat_silver_vori')) ?? 0,
        silverPrice: number('zakat_silver_price'),
        business: number('zakat_business'),
        other: number('zakat_other'),
      );

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
    return p ?? _metal;
  }

  /// Today's 22-carat prices into the যাকাত page (the user can still change them).
  Future<void> useMetalPrice(MetalPrice p) async {
    await setZakatValue('gold_price', '${p.gold22}');
    await setZakatValue('silver_price', '${p.silver22}');
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
  Future<(List<Command>, String?)> understandAll(String said, {List<AiTurn> history = const [], bool fast = false}) async {
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
    if (!aiOn) return (rules, null);
    // The to-do list and reminders are decided on the phone, by the same
    // rules typed or spoken: when they found what is wanted, the AI is not
    // asked (one reading, one action — never a second one from the AI).
    if (rules.any(_decidedHere)) return (rules, null);
    // Money is counted from the saved book, never put into words by the AI
    // (it could make up an amount); a question that needs a choice is asked.
    if (rules.length == 1 && (rules.first is MoneyListQuery || rules.first is Clarify || rules.first is LedgerQuery || rules.first is CashQuery)) return (rules, null);
    // "নোট খোলো": opening a page needs no AI; blood group, allergies and
    // what photos are kept stay on the phone.
    if (rules.length == 1 && (rules.first is OpenPlace || rules.first is ProfileQuery || rules.first is ProfileSet || rules.first is ManageItem)) return (rules, null);
    // An alarm is understood on the phone at once (no waiting for the AI).
    if (rules.length == 1 && rules.first is ReminderAdd && (rules.first as ReminderAdd).alarm) return (rules, null);
    if (mentionsSecret(said) || rules.any((c) => c is VaultQuery)) return (rules, null);
    // A phone number in the sentence: understood on the phone (numbers never go to the AI).
    if (findPhone(said) != null) return (rules, null);
    // Listing the saved numbers needs no AI (and numbers never go to it).
    if (rules.length == 1 && rules.first is ContactsQuery) return (rules, null);
    if (rules.length == 1 && rules.first is SmallTalk && {Talk.time, Talk.date}.contains((rules.first as SmallTalk).kind)) {
      return (rules, null);
    }
    try {
      final clean = stripAddress(said).$1;
      var text = clean.isEmpty ? said : clean;
      final others = [for (final a in alts) if (a.trim() != said.trim() && !mentionsSecret(a)) a];
      if (others.isNotEmpty) text = '$text\n[speech recogniser also heard: ${others.take(3).join(' | ')}]';
      final r = await services.ai.route(text, aiContext(now: now), history: history, fast: fast);
      if (r == null) return (rules, null);
      var cmds = commandsFromAi(said, r, data.ledger, now: now);
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

  /// To-do and reminder commands the rules settle by themselves.
  static bool _decidedHere(Command c) =>
      c is TaskAdd || c is TaskEdit || c is TaskDone || c is TaskQuery || c is TaskRestore || c is TasksClear || c is ReminderAdd || c is ReminderSnooze || c is Clarify || c is MenuAction || c is BulkAction;

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
      services.ai.quality = (await services.lock.keys.read('ai_quality')) == 'fast' ? AiQuality.fast : AiQuality.best;
      aiShareData = (await services.lock.keys.read('ai_share_data')) != 'false';
      userName = await services.lock.keys.read('user_name') ?? '';
      askUserName = userName;
      district = await services.lock.keys.read('district') ?? 'ঢাকা';
      askPlace = district;
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
    await _loadPro();
    await _loadAccount();
    await _loadServerNotices();
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
    if (loadError == null) await markOpened();
    if (loadError == null) await purgeTrash();
    refreshAccount();
    await _reschedule();
    if (loadError == null) await _showStanding();
    inboxSupported = await services.inbox.supported();
    if (inboxSupported) notifyListeners();
    if (loadError == null && inboxSupported) {
      await services.inbox.setApps([for (final n in inboxAppsOn) ...packagesOf(n)], on: inboxOn);
      await syncInbox();
    }
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
    // A pay-back day: a reminder (a day before, and on the day at 10:00).
    final old = data.ledger.where((y) => y.id == x.id).firstOrNull;
    final oldRem = old?.reminderId ?? x.reminderId;
    if (oldRem != null) data.reminders.removeWhere((r) => r.id == oldRem);
    x = x.copyWith(clearReminder: true);
    // The day itself is kept for everyone; the reminder is Pro.
    if (x.due != null && (x.kind == LedgerKind.lent || x.kind == LedgerKind.borrowed) && has(ProFeature.dueReminders)) {
      final r = _dueReminder(x);
      data.reminders.add(r);
      x = x.copyWith(reminderId: r.id);
    }
    _upsert(data.ledger, x, (y) => y.id);
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
    if (e != null) _trash('${e.person} · ${e.kind.label} ${taka(e.amount)}', [('ledger', e.toJson()), ..._remindersJson([e.reminderId])]);
    final rem = e?.reminderId;
    data.ledger.removeWhere((e) => e.id == id);
    if (rem != null) data.reminders.removeWhere((r) => r.id == rem);
    await _save();
    if (rem != null) await _reschedule();
  }

  Future<void> saveVault(VaultItem v) async {
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
    // Its files stay until it is gone from মুছে ফেলা for good.
    for (final c in data.contacts.where((e) => e.id == id)) {
      _trash(c.name, [('contacts', c.toJson())], files: [for (final f in c.files) f.id]);
    }
    data.contacts.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> saveNote(Note n) async {
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

  /// Keeps a photo or file encrypted on the phone (for a note or a document).
  Future<DocFile> keepFile(PickedDoc f) async {
    final file = DocFile(name: f.name, mime: f.mime, size: f.bytes.length);
    await services.store.saveDocFile(file.id, f.bytes);
    return file;
  }

  Future<void> dropFile(DocFile f) => services.store.deleteDocFile(f.id);

  /// Several photos or files at once: all in one document ([info] gives its
  /// name, folder and description), returned saved.
  Future<Doc> addDocGroup(List<PickedDoc> picked, Doc info) async {
    final files = <DocFile>[...info.files];
    for (final f in picked) {
      files.add(await keepFile(f));
    }
    final d = info.copyWith(files: files);
    await saveDoc(d);
    return d;
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
    // The date is kept for everyone; the reminder is Pro.
    if (expiry != null && has(ProFeature.docAlerts)) {
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
    _upsert(data.cash, e, (x) => x.id);
    await _save();
  }

  Future<void> deleteCash(String id) async {
    for (final e in data.cash.where((e) => e.id == id)) {
      _trash('${e.category} · ${taka(e.amount)}', [('cash', e.toJson())]);
    }
    data.cash.removeWhere((e) => e.id == id);
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
        data.cash[i] = CashEntry(id: e.id, kind: e.kind, amount: e.amount, category: e.category, note: e.note, date: e.date, projectId: e.projectId, accountId: e.accountId);
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
      _trash(p.name, [('projects', p.toJson()), for (final c in data.cash) if (c.projectId == id) ('cash', c.toJson())]);
    }
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
