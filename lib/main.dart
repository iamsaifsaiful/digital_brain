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
        title: 'আমানত',
        debugShowCheckedModeBanner: false,
        theme: appTheme(),
        home: Gate(h: hisab),
      );
}

/// Loads the data, asks for the PIN, then shows the app. Locks again after
/// the chosen time in the background.
class Gate extends StatefulWidget {
  const Gate({super.key, required this.h});
  final Hisab h;

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> with WidgetsBindingObserver {
  bool? _hasPin;
  bool _unlocked = false;
  DateTime? _leftAt;

  /// A customer to open, from a tapped reminder, once the app is unlocked.
  String? _openCustomer;
  final _homeKey = GlobalKey<HomeShellState>();

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
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomerScreen(h: h, id: id)));
    });
  }

  void _unlock() {
    setState(() => _unlocked = true);
    _openPending();
    h.refreshSession();
    h.sync();
  }

  AgentState? _agent;

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
          if (mounted) {
            Navigator.of(context).popUntil((r) => r.isFirst);
            setState(() => _unlocked = false);
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

  @override
  Widget build(BuildContext context) {
    if (!h.loaded || _hasPin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (h.loadError != null) return _LoadError(h: h, onFixed: () => setState(() {}));
    if (_hasPin == false) {
      return PinSetup(
        lock: h.s.lock,
        onDone: () => setState(() {
          _hasPin = true;
          _unlocked = true;
        }),
      );
    }
    if (!_unlocked) return LockScreen(h: h, onOpen: _unlock);
    final ses = h.session;
    if (ses == null) {
      _agent = null;
      return LoginScreen(h: h);
    }
    if (ses.isAgent) {
      return AgentShell(st: _agent ??= AgentState(h));
    }
    if (h.needsSetup) return SetupScreen(h: h);
    return HomeShell(key: _homeKey, h: h);
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
