import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../services/lock.dart';
import '../state/brain.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import '../logic/lang.dart';
import '../models/models.dart';
import '../ui/widgets.dart';
import 'store_more_screens.dart';
import 'more_screen.dart' show shownVersion;

/// Off in tests, so they start straight at the PIN.
bool googleFirst = true;

/// First run: sign in with Google, then choose a PIN. Every other time:
/// unlock with fingerprint or PIN.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

enum _Mode { loading, google, create, confirm, unlock }

class _LockScreenState extends State<LockScreen> {
  _Mode _mode = _Mode.loading;
  String _first = '';
  String? _message;
  DateTime? _lockedUntil;
  bool _bioAvailable = false;
  int _padKey = 0;
  bool _signing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final brain = BrainScope.read(context);
    final lock = brain.services.lock;
    final has = await lock.hasPin();
    final bio = has && await lock.biometricsOn() && await lock.biometrics.available();
    if (!mounted) return;
    setState(() {
      _mode = has ? _Mode.unlock : (googleFirst && !brain.signedIn ? _Mode.google : _Mode.create);
      _bioAvailable = bio;
    });
    // Not while a ringing reminder's page is open (or about to open).
    if (bio && !brain.alarmOpen && brain.services.notifier.tapped.value == null) _biometric();
  }

  /// First step on a new phone: Google sign-in (the account, Pro bought on
  /// the website, and the Drive backup come with it).
  Future<void> _google() async {
    final brain = BrainScope.read(context);
    setState(() {
      _signing = true;
      _message = null;
    });
    final e = await brain.signInGoogle(appVersion: shownVersion);
    if (!mounted) return;
    setState(() => _signing = false);
    if (e != null) {
      setState(() => _message = e);
      return;
    }
    if (!brain.signedIn) return;
    // Right after the PIN: bring back this account's backup, if it has one.
    brain.offerRestore = true;
    setState(() {
      _mode = _Mode.create;
      _padKey++;
    });
  }

  Widget _googleStep() => Column(children: [
        Text(tr('শুরু করতে Google দিয়ে লগইন করুন'), textAlign: TextAlign.center, style: body(18, color: Colors.white, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text(tr('আপনার তথ্য Google Drive-এ তালাবদ্ধ ব্যাকআপ রাখা যাবে, ফোন বদলালেও সব ফিরে আসবে। এরপর একটা PIN ঠিক করবেন।'),
            textAlign: TextAlign.center, style: body(14, color: const Color(0xFFC9D3CE), height: 1.55)),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            key: const Key('welcome-google'),
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFF1F2937), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: _signing ? null : _google,
            icon: _signing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF4285F4))),
            label: Text(tr('Google দিয়ে লগইন'), style: body(16, weight: FontWeight.w600, color: const Color(0xFF1F2937))),
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(_message!, textAlign: TextAlign.center, style: body(14, color: C.peach, weight: FontWeight.w600)),
        ],
        const SizedBox(height: 10),
        TextButton(
          key: const Key('welcome-later'),
          onPressed: _signing
              ? null
              : () => setState(() {
                    _mode = _Mode.create;
                    _message = null;
                    _padKey++;
                  }),
          child: Text(tr('এখন না, পরে করব'), style: body(14, color: const Color(0xFFA9B5AF))),
        ),
      ]);

  Future<void> _biometric() async {
    final brain = BrainScope.read(context);
    final ok = await brain.services.lock.tryBiometrics(tr('My Assistant খুলতে আঙুলের ছাপ দিন'));
    if (ok && mounted) brain.unlock();
  }

  /// "PIN ভুলে গেছেন?": the owner proves it is them with the fingerprint or
  /// the backup password, then sets a new PIN. Nothing else opens the app,
  /// so a phone in someone else's hands stays locked.
  Future<void> _forgot() async {
    final brain = BrainScope.read(context);
    final lock = brain.services.lock;
    final bio = await lock.biometricsOn() && await lock.biometrics.available();
    final rec = await lock.hasRecovery();
    final google = brain.signedIn;
    if (!mounted) return;
    final how = await showAppSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('PIN ভুলে গেছেন?'), style: display(20)),
            const SizedBox(height: 8),
            Text(tr('আপনিই মালিক — সেটা দেখিয়ে নতুন PIN ঠিক করুন। আপনার তথ্য যেমন আছে তেমনই থাকবে।'), style: body(14, color: C.muted, height: 1.5)),
            const SizedBox(height: 14),
            if (bio) ...[
              PrimaryButton(key: const Key('forgot-bio'), label: tr('আঙুলের ছাপ দিয়ে'), icon: Icons.fingerprint_rounded, onPressed: () => Navigator.pop(ctx, 'bio')),
              const SizedBox(height: 8),
            ],
            if (google) ...[
              SecondaryButton(key: const Key('forgot-google'), label: tr('একই Google অ্যাকাউন্ট দিয়ে'), icon: Icons.account_circle_outlined, onPressed: () => Navigator.pop(ctx, 'google')),
              const SizedBox(height: 8),
            ],
            if (rec) ...[
              SecondaryButton(key: const Key('forgot-password'), label: tr('পুরোনো ব্যাকআপ-পাসওয়ার্ড দিয়ে'), icon: Icons.password_rounded, onPressed: () => Navigator.pop(ctx, 'password')),
              const SizedBox(height: 10),
            ],
            Text(
                bio || rec || google
                    ? tr('আপনার তথ্য যেমন আছে তেমনই থাকবে।')
                    : tr('এই ফোনে আঙুলের ছাপ বা Google অ্যাকাউন্ট যুক্ত নেই, তাই PIN ছাড়া খোলা যাবে না — যাতে ফোন অন্যের হাতে গেলেও আপনার তথ্য নিরাপদ থাকে। Google Drive-এ ব্যাকআপ থাকলে: অ্যাপ মুছে আবার ইনস্টল করুন, একই Google অ্যাকাউন্টে লগইন করে সব ফিরিয়ে আনুন।'),
                style: body(13, color: C.muted, height: 1.5)),
          ]),
        ),
      ),
    );
    if (how == null || !mounted) return;
    var ok = false;
    if (how == 'bio') {
      ok = await lock.biometrics.authenticate(tr('নতুন PIN দিতে আঙুলের ছাপ দিন'));
    } else if (how == 'google') {
      final why = await brain.confirmGoogleOwner();
      if (!mounted) return;
      ok = why == null;
      if (why != null && why.isNotEmpty) setState(() => _message = why);
    } else {
      final pw = await _askRecovery();
      if (pw == null || !mounted) return;
      final r = await lock.checkRecovery(pw);
      if (!mounted) return;
      switch (r) {
        case PinOk():
          ok = true;
        case PinWrong(:final triesLeft):
          setState(() => _message = trf('পাসওয়ার্ড মেলেনি। আর {0} বার চেষ্টা করা যাবে।', [bnDigits(triesLeft)]));
        case PinLocked(:final until):
          setState(() => _lockedUntil = until);
      }
    }
    if (ok && mounted) {
      setState(() {
        _mode = _Mode.create;
        _first = '';
        _lockedUntil = null;
        _message = tr('ঠিক আছে — এবার নতুন PIN ঠিক করুন');
        _padKey++;
      });
    }
  }

  Future<String?> _askRecovery() async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('ব্যাকআপ-পাসওয়ার্ড'), style: display(19)),
        content: TextField(
          key: const Key('recovery-field'),
          controller: c,
          obscureText: true,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(labelText: tr('Google Drive ব্যাকআপের পাসওয়ার্ড')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
          TextButton(key: const Key('recovery-ok'), onPressed: () => Navigator.pop(ctx, c.text), child: Text(tr('যাচাই করুন'))),
        ],
      ),
    );
    // Not disposed here: the dialog's closing animation still uses it.
    return v == null || v.isEmpty ? null : v;
  }

  Future<void> _entered(String pin, VoidCallback clear) async {
    final brain = BrainScope.read(context);
    final lock = brain.services.lock;
    switch (_mode) {
      case _Mode.create:
        setState(() {
          _first = pin;
          _mode = _Mode.confirm;
          _message = null;
          _padKey++;
        });
      case _Mode.confirm:
        if (pin != _first) {
          setState(() {
            _mode = _Mode.create;
            _first = '';
            _message = tr('দুইবারের PIN মেলেনি। আবার শুরু করুন।');
            _padKey++;
          });
          return;
        }
        await lock.setPin(pin);
        final bio = await lock.biometrics.available();
        await lock.setBiometricsOn(bio);
        if (mounted) brain.unlock();
      case _Mode.unlock:
        final r = await lock.checkPin(pin);
        if (!mounted) return;
        switch (r) {
          case PinOk():
            brain.unlock();
          case PinWrong(:final triesLeft):
            setState(() {
              _lockedUntil = null;
              _message = trf('PIN মেলেনি। আর {0} বার চেষ্টা করা যাবে।', [bnDigits(triesLeft)]);
            });
            clear();
          case PinLocked(:final until):
            setState(() => _lockedUntil = until);
            clear();
        }
      case _Mode.loading || _Mode.google:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _Mode.create => tr('একটি ৪ অঙ্কের PIN ঠিক করুন'),
      _Mode.confirm => tr('PIN টি আবার দিন'),
      _ => tr('PIN দিন'),
    };
    return Scaffold(
      backgroundColor: C.night,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        // Our own app icon (owner, 28 Oct).
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.asset('assets/brand/app_mark.png', key: const Key('lock-app-mark'), width: 76, height: 76, filterQuality: FilterQuality.medium),
                        ),
                        const SizedBox(height: 12),
                        Text('My Assistant', style: display(30, weight: 700, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(tr('আপনার ব্যক্তিগত সহকারী'),
                            style: body(14, color: const Color(0xFFA9B5AF)), textAlign: TextAlign.center),
                      ],
                    ),
                    const SizedBox(height: 28),
                    if (_mode == _Mode.loading)
                      const SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: C.mint)))
                    else if (_mode == _Mode.google)
                      _googleStep()
                    else
                      Column(
                        children: [
                          Text(title, style: body(17, color: const Color(0xFFE4EAE7), weight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 44,
                            child: _lockedUntil != null
                                ? LockCountdown(key: ValueKey(_lockedUntil), until: _lockedUntil!, style: body(14, color: C.peach, weight: FontWeight.w600))
                                : _message == null
                                ? null
                                : Text(_message!, style: body(14, color: C.peach, weight: FontWeight.w600), textAlign: TextAlign.center),
                          ),
                          PinPad(
                            key: ValueKey(_padKey),
                            onComplete: _entered,
                            onBiometric: _mode == _Mode.unlock && _bioAvailable ? _biometric : null,
                          ),
                          if (_mode == _Mode.unlock)
                            TextButton(
                              key: const Key('forgot-pin'),
                              onPressed: _forgot,
                              child: Text(tr('PIN ভুলে গেছেন?'), style: body(14, weight: FontWeight.w600, color: C.mint)),
                            ),
                        ],
                      ),
                    if (_mode == _Mode.unlock && !BrainScope.of(context).data.emergency.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => Scaffold(
                              body: SafeArea(
                                child: Column(children: [
                                  TopBar(title: tr('জরুরি তথ্য')),
                                  Expanded(
                                    child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                                      EmergencyView(
                                        card: BrainScope.read(context).data.emergency,
                                        onCall: (p) => BrainScope.read(context).services.launcher.open(Via.call, p),
                                      ),
                                    ]),
                                  ),
                                ]),
                              ),
                            ),
                          )),
                          icon: const Icon(Icons.emergency_outlined, color: Color(0xFFFCA5A5)),
                          label: Text(tr('জরুরি তথ্য'), style: body(15, weight: FontWeight.w600, color: const Color(0xFFFCA5A5))),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0x66FCA5A5)), shape: const StadiumBorder()),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      _mode == _Mode.google
                          ? tr('ব্যাকআপ তালাবদ্ধ থাকে — Google একা বা আমরা একা খুলতে পারি না।')
                          : _mode == _Mode.create || _mode == _Mode.confirm
                          ? tr('PIN শুধু এই ফোনে, এনক্রিপ্ট করে রাখা হয়। ভুলে গেলে আঙুলের ছাপ বা একই Google অ্যাকাউন্ট দিয়ে নতুন PIN দেওয়া যাবে।')
                          : tr('কিছুক্ষণ ব্যবহার না করলে অ্যাপ নিজে থেকে লক হয়ে যায়'),
                      style: body(13, color: const Color(0xFFA9B5AF), height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    // The company behind the app (owner, 28 Oct).
                    Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: InkWell(
                        key: const Key('lock-company'),
                        onTap: () => BrainScope.read(context).services.launcher.openUrl(Uri.parse('https://owlgorithmlabs.com/')),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text('a product of Owlgorithm Labs', style: body(12, color: const Color(0xFF8E9B95)), textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                    // Said at the start, where a new member reads it (owner, 28 Oct; was under আরও › রিমাইন্ডার ও কণ্ঠ).
                    if (_mode == _Mode.google || _mode == _Mode.create || _mode == _Mode.confirm) ...[
                      const SizedBox(height: 10),
                      Text(
                        tr('মুখে বললে কথাকে লেখায় রূপান্তর করে ফোনের নিজের ভয়েস সেবা (সাধারণত Google)। সেজন্য আপনার কণ্ঠ ইন্টারনেটে Google-এর কাছে যেতে পারে — আমাদের সার্ভারে নয়। না চাইলে লিখে ব্যবহার করুন।'),
                        key: const Key('welcome-voice-note'),
                        style: body(12, color: const Color(0xFF8E9B95), height: 1.5),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
