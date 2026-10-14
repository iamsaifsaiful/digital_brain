import 'package:flutter/material.dart';

import 'logic/bn.dart';
import 'logic/proactive.dart';
import 'screens/docs_screen.dart';
import 'screens/health_screens.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'screens/person_screen.dart';
import 'screens/plan_screens.dart';
import 'screens/store_more_screens.dart';
import 'services/files.dart';
import 'services/platform.dart';
import 'ui/widgets.dart';
import 'screens/lock_screen.dart';
import 'screens/alarm_screens.dart';
import 'logic/lang.dart';
import 'state/brain.dart';
import 'ui/theme.dart';

/// Off in tests, so they start straight on Home.
bool showOnboarding = true;

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

  @override
  void dispose() {
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
    final dark = switch (brain.look) {
      Look.dark => true,
      Look.light => false,
      Look.system => platformDark,
    };
    final size = brain.easyMode ? (brain.letterSize < 1.15 ? 1.15 : brain.letterSize) : brain.letterSize;
    final stamp = '$dark|${brain.accentKey}|${brain.english}|$size';
    if (stamp == _lookStamp) return false;
    _lookStamp = stamp;
    C.dark = dark;
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
      // A ringing reminder's page stays open (it shows nothing private);
      // the pages under it close when it does.
      if (!_alarmOpen) _nav.currentState?.popUntil((r) => r.isFirst);
    }
    if (!_wasUnlocked && brain.unlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runPending();
        _maybeOnboard();
      });
    }
    _wasUnlocked = brain.unlocked;
  }

  bool _onboarded = false;

  /// The first time after the PIN: "আপনি কী করেন?".
  void _maybeOnboard() {
    if (_onboarded || brain.persona.isNotEmpty || !brain.unlocked || brain.loadError != null || !showOnboarding) return;
    _onboarded = true;
    _nav.currentState?.push(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _leftAt ??= brain.services.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null && brain.unlocked) _maybeLock(left);
      // Rings set while the app was away (or lost to a phone restart) are
      // put back every time the app comes to the front.
      brain.refreshNotices();
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
    // "আর বাজাবে না" pressed on the notification itself: stop it here and
    // now — no page to open, nothing more to press.
    if (t.action == 'stop') {
      await brain.whenLoaded();
      await brain.stopReminder(t.info.reminderId);
      final ctx = _nav.currentContext;
      if (ctx != null && ctx.mounted) toast(ctx, tr('আর বাজবে না'));
      return;
    }
    _alarmOpen = true;
    await nav.push(MaterialPageRoute(builder: (_) => AlarmScreen(info: t.info), fullscreenDialog: true));
    _alarmOpen = false;
    if (!brain.unlocked) nav.popUntil((r) => r.isFirst);
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
    if (!brain.unlocked) return const LockScreen();
    if (brain.loadError != null) return const _LoadError();
    return const HomeShell();
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
                  tr('এই ফোনের সুরক্ষিত চাবি দিয়ে তথ্যের ফাইল খোলা যাচ্ছে না। অ্যাপ নতুন করে ইনস্টল হলে বা ফোনের নিরাপত্তা বদলালে এমন হতে পারে। ব্যাকআপ থাকলে অ্যাপের ডেটা মুছে নতুন করে শুরু করে ব্যাকআপ ফিরিয়ে আনুন।'),
                  style: body(15, color: C.muted, height: 1.6),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}
