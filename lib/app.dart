import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'logic/bn.dart';
import 'logic/proactive.dart';
import 'logic/calendar_bd.dart' show placeNamed, sunTimes;
import 'logic/sky_light.dart';
import 'screens/vault_screen.dart' show VaultPage;
import 'screens/more_screen.dart' show BackupScreen;
import 'screens/google_backup.dart' show restoreFromDrive;
import 'screens/feedback_screen.dart' show FeedbackScreen;
import 'screens/requests_screen.dart' show RequestsScreen;
import 'screens/docs_screen.dart';
import 'screens/money_more_screens.dart';
import 'screens/calendar_screen.dart';
import 'screens/health_screens.dart';
import 'screens/home_shell.dart';
import 'screens/person_screen.dart';
import 'screens/plan_screens.dart';
import 'screens/store_more_screens.dart';
import 'services/error_log.dart';
import 'services/files.dart';
import 'services/platform.dart';
import 'ui/widgets.dart';
import 'screens/lock_screen.dart';
import 'screens/alarm_screens.dart';
import 'logic/lang.dart';
import 'state/brain.dart';
import 'ui/theme.dart';

class DigitalBrainApp extends StatefulWidget {
  const DigitalBrainApp({super.key, required this.brain});
  final Brain brain;

  @override
  State<DigitalBrainApp> createState() => _DigitalBrainAppState();
}

class _DigitalBrainAppState extends State<DigitalBrainApp> with WidgetsBindingObserver {
  final _nav = GlobalKey<NavigatorState>();
  DateTime? _leftAt;
  bool _wasUnlocked = false;


  Brain get brain => widget.brain;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    brain.addListener(_onBrain);
    brain.services.notifier.tapped.addListener(_onNotificationTap);
    AppPlatform.listen();
    AppPlatform.launches.addListener(_onLaunch);
    _dusk = Timer.periodic(const Duration(minutes: 1), (_) {
      if (brain.look == Look.sun && brain.loaded && _applyLook()) {
        setState(() {});
        _rebuildAll();
      }
    });
    // Opened by a reminder before this page existed.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _onNotificationTap();
      final first = await AppPlatform.initial();
      if (!first.isEmpty) {
        _pending = first;
        _runPending();
      }
    });
  }

  /// সময়ের সাথে: the colours move on with the light (checked every minute).
  Timer? _dusk;

  @override
  void didUpdateWidget(DigitalBrainApp old) {
    super.didUpdateWidget(old);
    if (old.brain != widget.brain) {
      old.brain.removeListener(_onBrain);
      old.brain.services.notifier.tapped.removeListener(_onNotificationTap);
      widget.brain.addListener(_onBrain);
      widget.brain.services.notifier.tapped.addListener(_onNotificationTap);
      _wasUnlocked = widget.brain.unlocked;
    }
  }

  @override
  void dispose() {
    _dusk?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    brain.removeListener(_onBrain);
    brain.services.notifier.tapped.removeListener(_onNotificationTap);
    AppPlatform.launches.removeListener(_onLaunch);
    super.dispose();
  }

  /// The look and language the screens were last built with.
  String _lookStamp = '';

  /// Sets the colours, letter size and language every screen reads, from
  /// the user's choice (and the phone's own dark mode for "ফোনের মতো").
  bool _applyLook() {
    final platformDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    final mix = switch (brain.look) {
      Look.dark => 1.0,
      Look.light => 0.0,
      Look.system => platformDark ? 1.0 : 0.0,
      Look.sun => duskMix(brain),
    };
    final size = brain.easyMode ? (brain.letterSize < 1.15 ? 1.15 : brain.letterSize) : brain.letterSize;
    final stamp = '${mix.toStringAsFixed(2)}|${brain.accentKey}|${brain.english}|$size';
    if (stamp == _lookStamp) return false;
    _lookStamp = stamp;
    C.mix = mix;
    C.dark = mix >= 0.5;
    C.accent = accentFor(brain.accentKey);
    isEn = brain.english;
    textScale = size;
    return true;
  }

  /// Every page on screen builds again with the new look (open pages stay open).
  void _rebuildAll() {
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    if (mounted) (context as Element).visitChildren(mark);
  }

  @override
  void didChangePlatformBrightness() {
    if (_applyLook()) {
      setState(() {});
      _rebuildAll();
    }
  }

  /// When the app locks, close every open page so nothing shows behind the lock.
  void _onBrain() {
    if (_applyLook()) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
    }
    if (_wasUnlocked && !brain.unlocked) {
      // Locked after being used: the open pages stay as they were (a note
      // half written, the tab, the chat) and the lock covers them; the
      // keyboard goes down so nothing is typed behind the lock.
      FocusManager.instance.primaryFocus?.unfocus();
    }
    // The cover is built here (MaterialApp.builder), above BrainScope.
    if (_wasUnlocked != brain.unlocked && mounted) setState(() {});
    if (!_wasUnlocked && brain.unlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _maybeRestore();
        _runPending();
      });
    }
    _wasUnlocked = brain.unlocked;
  }


  /// Signed in with Google on the welcome page of a new install: bring back
  /// that account's Drive backup (asked first, with its password).
  Future<void> _maybeRestore() async {
    if (!brain.offerRestore) return;
    brain.offerRestore = false;
    final ctx = _nav.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await restoreFromDrive(ctx, fresh: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _leftAt ??= brain.services.now();
      // সমস্যার লগ goes when the app steps away (and on coming back).
      ErrorLog.flush(brain.services.server, brain.services.ai.session);
      if (brain.loaded) brain.autoDriveBackup();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null && brain.unlocked) _maybeLock(left);
      // Rings set while the app was away (or lost to a phone restart) are
      // put back every time the app comes to the front.
      brain.refreshNotices();
      ErrorLog.flush(brain.services.server, brain.services.ai.session);
      if (brain.loaded && brain.loadError == null) {
        brain.markOpened();
        brain.refreshAccount();
        // Travelled to another district: prayer times and weather follow.
        brain.refreshPlace();
        // What family members sent while away (light: no copy upload here).
        if (brain.signedIn) brain.family.refresh(deep: false).then((_) => brain.family.receive()).catchError((_) => 0);
      }
    }
  }

  Future<void> _maybeLock(DateTime left) async {
    final secs = await brain.services.lock.autoLockSeconds();
    if (brain.services.now().difference(left).inSeconds >= secs) brain.lockNow();
  }

  bool _alarmOpen = false;

  /// Something to open once the app is unlocked: an assistant notification
  /// ("brief:…", "nudge:…"), the panel mic, or a share from another app.
  Object? _pending;

  static bool _isAssistantTag(String id) => id.startsWith('brief:') || id.startsWith('nudge:') || id.startsWith('quick:') || id == 'emergency';

  void _onLaunch() {
    final l = AppPlatform.launches.value;
    if (l == null || l.isEmpty) return;
    AppPlatform.launches.value = null;
    _pending = l;
    _runPending();
  }

  Future<void> _runPending() async {
    final p = _pending;
    final nav = _nav.currentState;
    final ctx = _nav.currentContext;
    if (p == null || nav == null || ctx == null || !brain.unlocked || brain.loadError != null) return;
    _pending = null;
    if (p is Launch) {
      if (p.action == 'assist' || p.action == 'voice') {
        openVoice(ctx);
      } else if (p.action == 'push:blood') {
        nav.popUntil((r) => r.isFirst);
        nav.push(MaterialPageRoute(builder: (_) => const RequestsScreen()));
      } else if (p.action == 'push:feedback') {
        nav.popUntil((r) => r.isFirst);
        nav.push(MaterialPageRoute(builder: (_) => const FeedbackScreen()));
      } else if (p.files.isNotEmpty) {
        nav.popUntil((r) => r.isFirst);
        for (final f in p.files) {
          if (!ctx.mounted) return;
          await addDocument(ctx, source: 2, shared: PickedDoc(f.bytes, f.name, f.mime));
        }
      } else if (p.text.trim().isNotEmpty) {
        openChatWith(ctx, p.text.trim());
      }
      return;
    }
    final id = '$p';
    void push(Widget w) {
      nav.popUntil((r) => r.isFirst);
      nav.push(MaterialPageRoute(builder: (_) => w));
    }

    if (id == 'quick:voice') {
      openVoice(ctx);
    } else if (id == 'emergency') {
      push(const EmergencyScreen());
    } else if (id == morningTag) {
      openChatWith(ctx, 'আজ আমার কী কী আছে?');
    } else if (id == nightTag) {
      nav.popUntil((r) => r.isFirst);
      final left = tasksLeft(brain.data, brain.services.now());
      if (left.isEmpty) return;
      final ok = await showDialog<bool>(
        context: ctx,
        builder: (c) => AlertDialog(
          title: Text(trf('আজ {0}টা কাজ বাকি রইল', [bnDigits(left.length)]), style: display(20)),
          content: Text('${left.take(6).map((t) => '• ${t.title}').join('\n')}\n\n${tr('সবগুলো কালকের তালিকায় সরিয়ে দেবো?')}', style: body(15, height: 1.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('না, থাক'))),
            TextButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('হ্যাঁ, কালকে সরাও'), style: body(15, weight: FontWeight.w600, color: C.green))),
          ],
        ),
      );
      if (ok == true) {
        final n = await brain.moveLeftToTomorrow();
        if (ctx.mounted) toast(ctx, trf('{0}টা কাজ কালকের তালিকায় গেল', [bnDigits(n)]));
      }
    } else if (id.startsWith(nudgeDue)) {
      push(PersonScreen(person: id.substring(nudgeDue.length)));
    } else if (id.startsWith(nudgeDoc)) {
      push(const ExpiryScreen());
    } else if (id.startsWith(nudgeMed)) {
      push(const MedicinesScreen());
    } else if (id.startsWith(nudgeBill)) {
      push(const AllTasksScreen());
    } else if (id.startsWith(nudgeHabit)) {
      push(const HabitsScreen());
    } else if (id.startsWith(nudgeWeek)) {
      push(const SpendHealthScreen());
    } else if (id.startsWith(nudgeJumuah) || id.startsWith(nudgePrayer) || id.startsWith(nudgeRamadan)) {
      push(const CalendarScreen());
    } else if (id.startsWith(nudgeDonor)) {
      push(const RequestsScreen());
    } else if (id.startsWith(nudgeBack)) {
      openAssistant(ctx);
    } else if (id.startsWith(nudgeBackup)) {
      push(const BackupScreen());
    } else if (id.startsWith(nudgeQuote)) {
      push(const SpendHealthScreen());
    } else if (id.startsWith(nudgePass)) {
      push(const VaultPage());
    } else if (id.startsWith(nudgeFix)) {
      push(const AllTasksScreen());
    } else if (id.startsWith(nudgeSpend)) {
      push(const ReportScreen());
    } else if (id.startsWith(nudgeSalary)) {
      push(const SavingsScreen());
    } else if (id.startsWith(nudgePlan) || id.startsWith(nudgeNoCash) || id.startsWith(nudgeDay2) || id.startsWith(nudgeSoon)) {
      openVoice(ctx);
    }
  }

  /// A reminder rang and was opened (or lit up the locked screen): the big
  /// alarm page, even before the PIN — it shows only the title and time.
  Future<void> _onNotificationTap() async {
    final t = brain.services.notifier.tapped.value;
    final nav = _nav.currentState;
    if (t == null || nav == null || _alarmOpen) return;
    if (_isAssistantTag(t.info.reminderId)) {
      brain.services.notifier.tapped.value = null;
      _pending = t.info.reminderId;
      _runPending();
      return;
    }
    brain.services.notifier.tapped.value = null;
    // A fingerprint prompt up for the lock would sit over the alarm page.
    brain.alarmOpen = true;
    unawaited(brain.services.lock.biometrics.cancel());
    // "আর বাজাবে না" pressed on the notification itself: stop it here and
    // now — no page to open, nothing more to press.
    if (t.action == 'stop') {
      await brain.whenLoaded();
      await brain.stopReminder(t.info.reminderId);
      final ctx = _nav.currentContext;
      if (ctx != null && ctx.mounted) toast(ctx, tr('আর বাজবে না'));
      brain.alarmOpen = false;
      return;
    }
    // Over the lock the page comes in at once (no slide), so the pages kept
    // under the lock never show during a transition.
    final covered = !brain.unlocked;
    setState(() => _alarmOpen = true);
    await nav.push(covered
        ? PageRouteBuilder<void>(
            pageBuilder: (_, __, ___) => AlarmScreen(info: t.info),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            fullscreenDialog: true)
        : MaterialPageRoute(builder: (_) => AlarmScreen(info: t.info), fullscreenDialog: true));
    brain.alarmOpen = false;
    if (mounted) setState(() => _alarmOpen = false);
    // Another one rang meanwhile.
    if (brain.services.notifier.tapped.value != null) _onNotificationTap();
  }

  @override
  Widget build(BuildContext context) {
    _applyLook();
    return BrainScope(
      brain: brain,
      child: MaterialApp(
        navigatorKey: _nav,
        title: 'My Assistant',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        themeAnimationDuration: Duration.zero,
        home: const _Gate(),
        // The phone's own bars follow the look: the bottom navigation bar
        // takes the screen's colour (it stayed light grey in the dark look).
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: C.dark ? Brightness.light : Brightness.dark,
            statusBarBrightness: C.dark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: C.ground,
            systemNavigationBarDividerColor: C.ground,
            systemNavigationBarIconBrightness: C.dark ? Brightness.light : Brightness.dark,
          ),
          child: _LockCover(
            covered: brain.unlockedOnce && brain.loaded && !brain.unlocked && !_alarmOpen,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    if (!brain.loaded) {
      return const Scaffold(backgroundColor: C.night, body: Center(child: CircularProgressIndicator(color: C.mint)));
    }
    // Only the first lock replaces the app; later ones cover it (_LockCover).
    if (!brain.unlocked && !brain.unlockedOnce) return const LockScreen();
    if (brain.loadError != null) return const _LoadError();
    return const HomeShell();
  }
}

/// The lock after the app has been used: the pages stay alive underneath,
/// hidden (not painted, no taps, no animations, not read out), and the PIN
/// page sits on top with its own navigator for its sheets and dialogs.
/// Unlocking takes the cover away and the user is back where they were.
class _LockCover extends StatelessWidget {
  const _LockCover({required this.covered, required this.child});
  final bool covered;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      TickerMode(
        enabled: !covered,
        child: ExcludeSemantics(
          excluding: covered,
          child: Offstage(offstage: covered, child: child),
        ),
      ),
      if (covered)
        ColoredBox(
          key: const Key('lock-cover'),
          color: C.night,
          child: HeroControllerScope.none(
            child: Navigator(onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const LockScreen())),
          ),
        ),
    ]);
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: C.orange),
                const SizedBox(height: 12),
                Text(tr('তথ্য খোলা যায়নি'), style: display(22)),
                const SizedBox(height: 8),
                Text(
                  tr('এই ফোনের সুরক্ষিত চাবি দিয়ে তথ্যের ফাইল খোলা যাচ্ছে না। অ্যাপ নতুন করে ইনস্টল হলে বা ফোনের নিরাপত্তা বদলালে এমন হতে পারে। পুরনো ফাইলটা মুছে ফেলা হয়নি। ব্যাকআপ থাকলে নিচ থেকে ফিরিয়ে আনুন — পুরনো ফাইলটা আলাদা করে রাখা থাকবে।'),
                  style: body(15, color: C.muted, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BackupScreen())),
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(tr('ব্যাকআপ থেকে ফিরিয়ে আনুন')),
                ),
              ],
            ),
          ),
        ),
      );
}


/// How dark the app is now in the সময়ের সাথে look: the light set by day,
/// the dark set by night, changing once when the home picture is half way
/// to night (about a quarter of an hour after sunset, and before sunrise).
/// The picture itself still changes slowly; the pages never rest in
/// between — a half-light, half-night page was a muddy grey-blue at the
/// start of the evening and the morning (owner, 26 Oct).
double duskMix(Brain brain) {
  final now = brain.services.now();
  final sun = sunTimes(now, placeNamed(brain.district));
  final n = skyLight(now, sun.sunrise, sun.sunset).night;
  return n >= 0.5 ? 1.0 : 0.0;
}
