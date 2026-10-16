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

enum _Stage { loading, signIn, locked, open }

/// Signed in → (fingerprint, if turned on) → the tabs; otherwise sign-in.
class Gate extends StatefulWidget {
  const Gate({super.key, required this.api, required this.device});
  final Api api;
  final Device device;

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> with WidgetsBindingObserver {
  _Stage _stage = _Stage.loading;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Away for more than a minute: the fingerprint again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _leftAt = DateTime.now();
    if (state == AppLifecycleState.resumed && _stage == _Stage.open && _leftAt != null && DateTime.now().difference(_leftAt!) > const Duration(minutes: 1)) {
      widget.api.fingerprintOn().then((on) {
        if (on && mounted) setState(() => _stage = _Stage.locked);
      });
    }
  }

  Future<void> _start() async {
    if (!await widget.api.restore()) {
      setState(() => _stage = _Stage.signIn);
      return;
    }
    if (await widget.api.fingerprintOn()) {
      setState(() => _stage = _Stage.locked);
      await _unlock();
    } else {
      _opened();
    }
  }

  Future<void> _unlock() async {
    if (await widget.device.fingerprint('My Assistant অ্যাডমিন খুলতে আঙুলের ছাপ দিন')) _opened();
  }

  void _opened() {
    setState(() => _stage = _Stage.open);
    _push();
  }

  Future<void> _push() async {
    final t = await widget.device.pushToken();
    if (t != null && t.isNotEmpty) {
      try {
        await widget.api.sendPushToken(t);
      } catch (_) {}
    }
  }

  Future<void> _signedIn() async {
    if (await widget.device.canFingerprint() && mounted) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.fingerprint_rounded, size: 40),
          title: const Text('আঙুলের ছাপে খুলবেন?'),
          content: const Text('পরের বার পাসওয়ার্ড লাগবে না — অ্যাপ খুলতে শুধু আঙুলের ছাপ। পরে নোটিফিকেশন পাতার ⋮ থেকে বদলানো যায়।'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('পরে')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('চালু করুন')),
          ],
        ),
      );
      if (yes == true && await widget.device.fingerprint('চালু করতে আঙুলের ছাপ দিন')) await widget.api.setFingerprint(true);
    }
    _opened();
  }

  Future<void> _out() async {
    await widget.api.logout();
    if (mounted) setState(() => _stage = _Stage.signIn);
  }

  Future<void> _toggleFingerprint() async {
    final on = await widget.api.fingerprintOn();
    if (!on && !await widget.device.canFingerprint()) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('এই ফোনে আঙুলের ছাপ চালু নেই')));
      return;
    }
    if (!await widget.device.fingerprint(on ? 'বন্ধ করতে আঙুলের ছাপ দিন' : 'চালু করতে আঙুলের ছাপ দিন')) return;
    await widget.api.setFingerprint(!on);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(on ? 'আঙুলের ছাপ বন্ধ' : 'আঙুলের ছাপে খোলা চালু')));
  }

  @override
  Widget build(BuildContext context) => switch (_stage) {
        _Stage.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
        _Stage.signIn => SignIn(api: widget.api, onIn: _signedIn),
        _Stage.locked => Locked(onUnlock: _unlock, onPassword: _out),
        _Stage.open => Home(api: widget.api, onSignedOut: _out, onFingerprint: _toggleFingerprint),
      };
}

/// The green page behind sign-in and the fingerprint lock.
class _Brand extends StatelessWidget {
  const _Brand({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Palette.of(context).brand,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - 52),
                child: IntrinsicHeight(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
              ),
            ),
          ),
        ),
      );
}

Widget _logo() => Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
      child: const Icon(Icons.admin_panel_settings_outlined, color: Colors.white, size: 34),
    );

class SignIn extends StatefulWidget {
  const SignIn({super.key, required this.api, required this.onIn});
  final Api api;
  final VoidCallback onIn;

  @override
  State<SignIn> createState() => _SignInState();
}

class _SignInState extends State<SignIn> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  Future<void> _go() async {
    if (_email.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'ইমেইল আর পাসওয়ার্ড দিন');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.login(_email.text, _pass.text);
      _pass.clear();
      widget.onIn();
    } on ApiError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _field(String label, IconData icon, {Widget? suffix}) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        labelStyle: text(15, color: const Color(0xFF6B7280)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    return _Brand(children: [
      const SizedBox(height: 12),
      _logo(),
      const SizedBox(height: 18),
      Text('My Assistant\nঅ্যাডমিন', style: text(32, weight: FontWeight.w700, color: Colors.white, height: 1.15)),
      const SizedBox(height: 10),
      Text('পেমেন্ট অনুমোদন, সদস্য আর নোটিফিকেশন — ফোন থেকেই। সব তথ্য সার্ভারে থাকে, ফোনে কিছু জমা থাকে না।', style: text(15, color: const Color(0xFFC9EBDD), height: 1.6)),
      const Spacer(),
      const SizedBox(height: 24),
      AutofillGroup(
        child: Column(children: [
          TextField(
            key: const Key('email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            style: text(16, color: const Color(0xFF111827)),
            decoration: _field('ইমেইল', Icons.alternate_email_rounded),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('password'),
            controller: _pass,
            obscureText: !_show,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _go(),
            style: text(16, color: const Color(0xFF111827)),
            decoration: _field('পাসওয়ার্ড', Icons.lock_outline_rounded,
                suffix: IconButton(tooltip: _show ? 'লুকান' : 'দেখান', onPressed: () => setState(() => _show = !_show), icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
          ),
        ]),
      ),
      if (_error != null)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(14)),
          child: Text(_error!, style: text(14, color: const Color(0xFFBE123C), height: 1.5)),
        ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton(
          key: const Key('sign-in'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF111827), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: _busy ? null : _go,
          child: _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('লগইন', style: text(17, weight: FontWeight.w700, color: Colors.white)),
        ),
      ),
      const SizedBox(height: 10),
      Text('অ্যাকাউন্ট দেন ওয়েবসাইটের মূল অ্যাডমিন (My Assistant › সেটিংস › অ্যাডমিন)।', style: text(13, color: c.tint, height: 1.5)),
    ]);
  }
}

class Locked extends StatelessWidget {
  const Locked({super.key, required this.onUnlock, required this.onPassword});
  final VoidCallback onUnlock;
  final VoidCallback onPassword;

  @override
  Widget build(BuildContext context) => _Brand(children: [
        const Spacer(),
        Center(child: _logo()),
        const SizedBox(height: 18),
        Center(child: Text('My Assistant অ্যাডমিন', style: text(22, weight: FontWeight.w700, color: Colors.white))),
        const Spacer(),
        Center(
          child: InkResponse(
            key: const Key('unlock'),
            onTap: onUnlock,
            radius: 56,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.14), border: Border.all(color: Colors.white.withValues(alpha: 0.4))),
              child: const Icon(Icons.fingerprint_rounded, color: Colors.white, size: 54),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(child: Text('আঙুলের ছাপ দিন', style: text(16, color: Colors.white))),
        const Spacer(),
        Center(child: TextButton(onPressed: onPassword, child: Text('পাসওয়ার্ড দিয়ে লগইন', style: text(15, weight: FontWeight.w600, color: Colors.white)))),
      ]);
}

class Home extends StatefulWidget {
  const Home({super.key, required this.api, required this.onSignedOut, required this.onFingerprint});
  final Api api;
  final VoidCallback onSignedOut;
  final VoidCallback onFingerprint;

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int _tab = 0;
  int _pending = 0;
  int _feedback = 0;
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
      DashboardPage(api: widget.api, guard: guard, refresh: _refresh, onPending: (n) => setState(() => _pending = n), onFeedback: (n) => setState(() => _feedback = n), onOpenPayments: () => setState(() => _tab = 1)),
      PaymentsPage(api: widget.api, guard: guard, refresh: _refresh),
      MembersPage(api: widget.api, guard: guard),
      FeedbackPage(api: widget.api, guard: guard, refresh: _refresh),
      NoticesPage(api: widget.api, guard: guard, onSignOut: widget.onSignedOut, onFingerprint: widget.onFingerprint),
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
          NavigationDestination(
            icon: Badge(isLabelVisible: _feedback > 0, label: Text(bn(_feedback)), child: const Icon(Icons.forum_outlined)),
            selectedIcon: Badge(isLabelVisible: _feedback > 0, label: Text(bn(_feedback)), child: const Icon(Icons.forum_rounded)),
            label: 'মতামত',
          ),
          const NavigationDestination(icon: Icon(Icons.campaign_outlined), selectedIcon: Icon(Icons.campaign_rounded), label: 'নোটিফিকেশন'),
        ],
      ),
    );
  }
}
