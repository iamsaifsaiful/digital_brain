import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/crypto.dart';
import 'services/api.dart';
import 'services/device.dart';
import 'services/errors.dart';
import 'services/lock.dart';
import 'services/push.dart';
import 'services/reminders.dart';
import 'services/store.dart';
import 'state/hisab.dart';
import 'core/format.dart';
import 'ui/customers.dart';
import 'state/agent_state.dart';
import 'ui/agent_app.dart';
import 'ui/home.dart';
import 'ui/login.dart';
import 'ui/kit.dart';
import 'ui/lock_screen.dart';
import 'ui/setup.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorLog.add(details.exception, details.stack, where: 'screen: ${details.library ?? ''}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorLog.add(error, stack);
    return true;
  };
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));
  final keys = SecureKeyVault();
  final s = Services(
    store: DataStore(keys: keys, blob: FileBlobStore(), photos: FilePhotoFiles()),
    lock: LockService(keys: keys, biometrics: DeviceBiometrics()),
    device: PhoneDevice(),
    reminders: PhoneReminders(),
    api: HttpApi(),
    push: PhonePush(),
  );
  runApp(RiyalApp(hisab: Hisab(s)));
}

class RiyalApp extends StatelessWidget {
  const RiyalApp({super.key, required this.hisab});
  final Hisab hisab;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'রেমিট খাতা',
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        navigatorKey: rootNav,
        // The lock sits above every screen instead of replacing them, so
        // after the PIN the user is back exactly where they were.
        builder: (context, child) => Gate(h: hisab, child: child ?? const SizedBox()),
        home: AppHome(h: hisab),
      );
}

final rootNav = GlobalKey<NavigatorState>();
final _homeKey = GlobalKey<HomeShellState>();
AgentState? _agent;

/// What is under the lock: login, the agent's app, first setup or the
/// admin's app.
class AppHome extends StatelessWidget {
  const AppHome({super.key, required this.h});
  final Hisab h;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: h,
      builder: (context, _) {
        if (!h.loaded || h.loadError != null) return const Scaffold();
        final ses = h.session;
        if (ses == null) {
          _agent = null;
          return SplashThen(h: h, child: LoginScreen(h: h));
        }
        if (ses.isAgent) return AgentShell(st: _agent ??= AgentState(h));
        if (h.needsSetup) return SetupScreen(h: h);
        return HomeShell(key: _homeKey, h: h);
      });
}

/// Loads the data and keeps the lock: the opening animation, then the PIN,
/// over whatever screen is open. Locks again after the chosen time away.
class Gate extends StatefulWidget {
  const Gate({super.key, required this.h, required this.child});
  final Hisab h;
  final Widget child;

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> with WidgetsBindingObserver {
  bool? _hasPin;

  /// The opening animation plays before every PIN screen.
  bool _splash = true;
  bool _unlocked = false;
  DateTime? _leftAt;

  /// A customer to open, from a tapped reminder, once the app is unlocked.
  String? _openCustomer;

  Hisab get h => widget.h;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    h.addListener(_changed);
    _start();
  }

  Future<void> _start() async {
    appEnglish = await h.s.lock.english();
    await h.load();
    await h.s.reminders.init((id) {
      _openCustomer = id;
      _openPending();
    });
    final has = await h.s.lock.hasPin();
    if (mounted) setState(() => _hasPin = has);
  }

  void _openPending() {
    final id = _openCustomer;
    if (id == null || !_unlocked || h.needsSetup || !mounted) return;
    _openCustomer = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rootNav.currentState?.push(MaterialPageRoute(builder: (_) => CustomerScreen(h: h, id: id)));
    });
  }

  void _unlock() {
    setState(() => _unlocked = true);
    _openPending();
    h.refreshSession();
    h.sync();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    h.removeListener(_changed);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _leftAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftAt;
      _leftAt = null;
      if (left != null && _unlocked) {
        final secs = await h.s.lock.autoLockSeconds();
        if (secs >= 0 && DateTime.now().difference(left).inSeconds >= secs) {
          // Nothing is closed: the lock covers the open screen.
          if (mounted) {
            setState(() {
              _unlocked = false;
              _splash = true;
            });
          }
          return;
        }
      }
      // Back from WhatsApp: a TrxID copied there is offered at once.
      _homeKey.currentState?.checkClipboard();
      h.sync();
      _agent?.refresh();
    }
  }

  /// What covers the app now, or null when it is open.
  (String, Widget)? _cover() {
    if (_splash || !h.loaded || _hasPin == null) {
      return ('splash', SplashScreen(h: h, onDone: () => setState(() => _splash = false)));
    }
    if (h.loadError != null) return ('error', _LoadError(h: h, onFixed: () => setState(() {})));
    if (_hasPin == false) {
      return (
        'setpin',
        PinSetup(
          lock: h.s.lock,
          onDone: () => setState(() {
            _hasPin = true;
            _unlocked = true;
          }),
        )
      );
    }
    if (!_unlocked) return ('lock', LockScreen(h: h, onOpen: _unlock));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final cover = _cover();
    final ready = h.loaded && _hasPin == true;
    return Stack(children: [
      // The app is built only once it may be shown, and kept while locked.
      if (ready || _unlocked) Positioned.fill(child: widget.child),
      if (cover != null)
        Positioned.fill(
          child: HeroControllerScope.none(
            child: Navigator(
              key: ValueKey(cover.$1),
              onGenerateRoute: (_) => PageRouteBuilder<void>(pageBuilder: (_, a, b) => cover.$2, transitionDuration: Duration.zero),
            ),
          ),
        ),
    ]);
  }
}

/// The data file is there but cannot be read (the phone lost its key).
class _LoadError extends StatelessWidget {
  const _LoadError({required this.h, required this.onFixed});
  final Hisab h;
  final VoidCallback onFixed;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.lock_reset_rounded, size: 56, color: K.red),
              const SizedBox(height: 16),
              Tx('হিসাবের ফাইল খোলা যাচ্ছে না', textAlign: TextAlign.center, style: t(20, w: FontWeight.w600)),
              const SizedBox(height: 10),
              Tx('ফোনের নিরাপদ চাবি হারিয়ে গেছে। ব্যাকআপ ফাইল থাকলে সেটা দিয়ে সব ফিরিয়ে আনুন।', textAlign: TextAlign.center, style: t(14.5, c: K.muted, h: 1.5)),
              const SizedBox(height: 24),
              Pill(
                label: 'ব্যাকআপ থেকে ফিরিয়ে আনুন',
                onTap: () async {
                  final bytes = await h.s.device.pickFile();
                  if (bytes == null || !context.mounted) return;
                  final pass = await askText(context, 'ব্যাকআপের পাসওয়ার্ড', obscure: true);
                  if (pass == null || pass.isEmpty) return;
                  try {
                    await h.restoreBackup(bytes, pass);
                    onFixed();
                  } on WrongKey {
                    if (context.mounted) snack(context, 'পাসওয়ার্ড ভুল');
                  } catch (_) {
                    if (context.mounted) snack(context, 'এটা এই অ্যাপের ব্যাকআপ ফাইল না');
                  }
                },
              ),
              const SizedBox(height: 12),
              SoftPill(
                label: 'নতুন করে শুরু (পুরনো ফাইল আলাদা রেখে)',
                onTap: () async {
                  if (!await confirm(context, 'নতুন করে শুরু?', 'পুরনো ফাইল মুছবে না, আলাদা রাখা থাকবে। কিন্তু অ্যাপে আগের হিসাব দেখা যাবে না।', yes: 'শুরু করুন', danger: true)) return;
                  await h.s.store.startOver();
                  await h.load();
                  onFixed();
                },
              ),
            ]),
          ),
        ),
      );
}
