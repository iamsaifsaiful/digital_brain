import 'package:flutter/material.dart';

import 'screens/home_shell.dart';
import 'screens/lock_screen.dart';
import 'screens/reminders_screen.dart';
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    brain.removeListener(_onBrain);
    brain.services.notifier.tapped.removeListener(_onNotificationTap);
    super.dispose();
  }

  /// When the app locks, close every open page so nothing shows behind the lock.
  void _onBrain() {
    if (_wasUnlocked && !brain.unlocked) {
      _nav.currentState?.popUntil((r) => r.isFirst);
    }
    if (!_wasUnlocked && brain.unlocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onNotificationTap());
    }
    _wasUnlocked = brain.unlocked;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _leftAt ??= brain.services.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null && brain.unlocked) _maybeLock(left);
    }
  }

  Future<void> _maybeLock(DateTime left) async {
    final secs = await brain.services.lock.autoLockSeconds();
    if (brain.services.now().difference(left).inSeconds >= secs) brain.lockNow();
  }

  void _onNotificationTap() {
    final p = brain.services.notifier.tapped.value;
    if (p == null || !brain.unlocked) return;
    brain.services.notifier.tapped.value = null;
    if (p.startsWith('reminder:')) {
      _nav.currentState?.push(MaterialPageRoute(builder: (_) => RemindersScreen(highlightId: p.substring(9))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BrainScope(
      brain: brain,
      child: MaterialApp(
        navigatorKey: _nav,
        title: 'Digital Brain',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
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
      return const Scaffold(backgroundColor: C.ink, body: Center(child: CircularProgressIndicator(color: C.mint)));
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
                const Icon(Icons.error_outline_rounded, size: 48, color: C.orange),
                const SizedBox(height: 12),
                Text('তথ্য খোলা যায়নি', style: display(22)),
                const SizedBox(height: 8),
                Text(
                  'এই ফোনের সুরক্ষিত চাবি দিয়ে তথ্যের ফাইল খোলা যাচ্ছে না। অ্যাপ নতুন করে ইনস্টল হলে বা ফোনের নিরাপত্তা বদলালে এমন হতে পারে। ব্যাকআপ থাকলে অ্যাপের ডেটা মুছে নতুন করে শুরু করে ব্যাকআপ ফিরিয়ে আনুন।',
                  style: body(15, color: C.muted, height: 1.6),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
}
