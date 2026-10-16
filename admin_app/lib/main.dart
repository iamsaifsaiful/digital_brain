import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AdminApp(api: Api(), device: Device()));
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key, required this.api, required this.device});
  final Api api;
  final Device device;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'My Assistant Admin',
        debugShowCheckedModeBanner: false,
        theme: adminTheme(Brightness.light),
        darkTheme: adminTheme(Brightness.dark),
        home: Gate(api: api, device: device),
      );
}

/// Signed in → the tabs; otherwise the sign-in page.
class Gate extends StatefulWidget {
  const Gate({super.key, required this.api, required this.device});
  final Api api;
  final Device device;

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool? _in;

  @override
  void initState() {
    super.initState();
    widget.api.restore().then((ok) {
      if (mounted) setState(() => _in = ok);
      if (ok) _push();
    });
  }

  Future<void> _push() async {
    final t = await widget.device.pushToken();
    if (t != null && t.isNotEmpty) {
      try {
        await widget.api.sendPushToken(t);
      } catch (_) {}
    }
  }

  Future<void> _out() async {
    await widget.api.logout();
    await widget.device.signOut();
    if (mounted) setState(() => _in = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_in == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_in == false) {
      return SignIn(
        api: widget.api,
        device: widget.device,
        onIn: () {
          setState(() => _in = true);
          _push();
        },
      );
    }
    return Home(api: widget.api, onSignedOut: _out);
  }
}

class SignIn extends StatefulWidget {
  const SignIn({super.key, required this.api, required this.device, required this.onIn});
  final Api api;
  final Device device;
  final VoidCallback onIn;

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  bool _busy = false;
  String? _error;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final g = await widget.device.signIn();
      if (g == null) return;
      await widget.api.login(g.idToken);
      widget.onIn();
    } on ApiError catch (e) {
      await widget.device.signOut();
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    return Scaffold(
      backgroundColor: c.brand,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Spacer(),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 18),
            Text('My Assistant\nঅ্যাডমিন', style: text(32, weight: FontWeight.w700, color: Colors.white, height: 1.15)),
            const SizedBox(height: 10),
            Text('পেমেন্ট অনুমোদন, সদস্য আর নোটিফিকেশন — ফোন থেকেই। সব তথ্য সার্ভারে থাকে, ফোনে কিছু জমা থাকে না।',
                style: text(15, color: const Color(0xFFC9EBDD), height: 1.6)),
            const Spacer(flex: 2),
            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(14)),
                child: Text(_error!, style: text(14, color: const Color(0xFFBE123C), height: 1.5)),
              ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: c.brandDark, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _busy ? null : _go,
                icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login_rounded),
                label: Text('Google দিয়ে লগইন', style: text(17, weight: FontWeight.w700, color: c.brandDark)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key, required this.api, required this.onSignedOut});
  final Api api;
  final VoidCallback onSignedOut;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int _tab = 0;
  int _pending = 0;
  final _refresh = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from a push or another app: everything comes fresh from the server.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh.value++;
  }

  Future<T?> guard<T>(Future<T> Function() job) async {
    try {
      return await job();
    } on ApiError catch (e) {
      if (e.signedOut) {
        widget.onSignedOut();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(api: widget.api, guard: guard, refresh: _refresh, onPending: (n) => setState(() => _pending = n), onOpenPayments: () => setState(() => _tab = 1)),
      PaymentsPage(api: widget.api, guard: guard, refresh: _refresh),
      MembersPage(api: widget.api, guard: guard),
      NoticesPage(api: widget.api, guard: guard, onSignOut: widget.onSignedOut),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _tab = i);
          _refresh.value++;
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'সারাংশ'),
          NavigationDestination(
            icon: Badge(isLabelVisible: _pending > 0, label: Text(bn(_pending)), child: const Icon(Icons.payments_outlined)),
            selectedIcon: Badge(isLabelVisible: _pending > 0, label: Text(bn(_pending)), child: const Icon(Icons.payments_rounded)),
            label: 'পেমেন্ট',
          ),
          const NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group_rounded), label: 'সদস্য'),
          const NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign_rounded), label: 'নোটিফিকেশন'),
        ],
      ),
    );
  }
}
