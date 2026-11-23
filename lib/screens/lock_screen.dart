import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../ui/secure.dart';

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

/// The sign-up and PIN pages' colours (owner, 19 Nov: design 6 of six, the
/// app mark on the Cox's Bazar sea, melting into the part below, in the
/// home's dark look).
class LockPal {
  const LockPal({
    required this.bg,
    required this.sheet,
    required this.line,
    required this.title,
    required this.text,
    required this.soft,
    required this.accent,
    required this.onAccent,
    required this.track,
    required this.error,
    required this.pad,
  });
  final Color bg, sheet, line, title, text, soft, accent, onAccent, track, error;

  /// The PIN pad: text, key, dot filled, dot empty.
  final (Color, Color, Color, Color) pad;

  /// The home screen's dark look (owner, 19 Nov: "হোম স্কিনে ডার্ক মোড
  /// যেভাবে আছে"): the night-blue ground, its cards, the light teal.
  static const night = LockPal(
    bg: Color(0xFF121A33),
    sheet: Color(0xFF1A2342),
    line: Color(0xFF2E3859),
    title: Color(0xFFEEF1F8),
    text: Color(0xFFC7CEE0),
    soft: Color(0xFFA3ADC6),
    accent: Color(0xFF79DCF6),
    onAccent: Color(0xFF0E2A36),
    track: Color(0xFF242E50),
    error: Color(0xFFFDBA74),
    pad: (Color(0xFFEEF1F8), Color(0xFF242E50), Color(0xFF79DCF6), Color(0xFF3A456A)),
  );
}

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

  /// The PIN pad chosen over the fingerprint (owner, 13 Nov: the member picks).
  bool _usePin = false;
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
    // No fingerprint prompt by itself (owner, 13 Nov: it felt forced): the
    // member picks the fingerprint or the PIN, then that one is shown.
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

  /// The Google sign-in button: white with a thin line, the same in every design.
  Widget _googleButton(LockPal p) => SizedBox(
        width: double.infinity,
        height: 56,
        child: FilledButton.icon(
          key: const Key('welcome-google'),
          style: FilledButton.styleFrom(
            backgroundColor: p.accent,
            foregroundColor: p.onAccent,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          onPressed: _signing ? null : _google,
          icon: _signing
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Text('G', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF4285F4))),
                ),
          label: Text(tr('Google দিয়ে লগইন'), style: body(16, weight: FontWeight.w700, color: p.onAccent)),
        ),
      );

  /// Sign-up (owner, 19 Nov: less to read): one line, the Google button and
  /// "not now". The language is chosen above it.
  Widget _googleStep(LockPal p) => Column(children: [
        Text(tr('শুরু করতে Google দিয়ে লগইন করুন'), textAlign: TextAlign.center, style: body(17, color: p.title, weight: FontWeight.w700)),
        const SizedBox(height: 6),
        // One line on why (owner, 19 Nov: only the text that is needed).
        Text(tr('ফোন বদলালেও সব তথ্য ফিরে পাবেন — Google Drive-এ তালাবদ্ধ ব্যাকআপ থাকে।'), key: const Key('welcome-why'), textAlign: TextAlign.center, style: body(14, color: p.soft, height: 1.5)),
        const SizedBox(height: 20),
        _googleButton(p),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(_message!, textAlign: TextAlign.center, style: body(14, color: p.error, weight: FontWeight.w600)),
        ],
        const SizedBox(height: 6),
        TextButton(
          key: const Key('welcome-later'),
          onPressed: _signing
              ? null
              : () => setState(() {
                    _mode = _Mode.create;
                    _message = null;
                    _padKey++;
                  }),
          child: Text(tr('এখন না, পরে করব'), style: body(15, color: p.soft, weight: FontWeight.w600)),
        ),
      ]);

  /// What is said about privacy, one tap away instead of on the page.
  void _privacy() => showAppSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('গোপনীয়তা'), style: display(20)),
              const SizedBox(height: 12),
              for (final line in [
                tr('ব্যাকআপ তালাবদ্ধ থাকে — Google একা বা আমরা একা খুলতে পারি না।'),
                tr('PIN শুধু এই ফোনে, এনক্রিপ্ট করে রাখা হয়। ভুলে গেলে আঙুলের ছাপ বা একই Google অ্যাকাউন্ট দিয়ে নতুন PIN দেওয়া যাবে।'),
                tr('মুখে বললে কথাকে লেখায় রূপান্তর করে ফোনের নিজের ভয়েস সেবা (সাধারণত Google)। সেজন্য আপনার কণ্ঠ ইন্টারনেটে Google-এর কাছে যেতে পারে — আমাদের সার্ভারে নয়। না চাইলে লিখে ব্যবহার করুন।'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.lock_outline_rounded, size: 18, color: C.green)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(line, style: body(14, color: C.muted, height: 1.5))),
                  ]),
                ),
            ]),
          ),
        ),
      );

  void _pickPin() => setState(() {
        _usePin = true;
        _message = null;
      });

  /// The fingerprint or the PIN, the member's pick (owner, 13 Nov): two
  /// full-width buttons, the fingerprint first.
  Widget _choose(LockPal p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(children: [
        SizedBox(
          width: double.infinity,
          height: 58,
          child: FilledButton.icon(
            key: const Key('lock-choose-finger'),
            style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.onAccent, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29))),
            onPressed: _biometric,
            icon: const Icon(Icons.fingerprint_rounded, size: 26),
            label: Text(tr('আঙুলের ছাপ দিয়ে খুলুন'), style: body(16, weight: FontWeight.w700, color: p.onAccent)),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 58,
          child: OutlinedButton.icon(
            key: const Key('lock-choose-pin'),
            style: OutlinedButton.styleFrom(foregroundColor: p.title, side: BorderSide(color: p.soft.withValues(alpha: 0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(29))),
            onPressed: _pickPin,
            icon: const Icon(Icons.dialpad_rounded, size: 22),
            label: Text(tr('PIN দিয়ে খুলুন'), style: body(16, weight: FontWeight.w600, color: p.title)),
          ),
        ),
      ]),
    );
  }

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
                    : tr(
                        'এই ফোনে আঙুলের ছাপ বা Google অ্যাকাউন্ট যুক্ত নেই, তাই PIN ছাড়া খোলা যাবে না — যাতে ফোন অন্যের হাতে গেলেও আপনার তথ্য নিরাপদ থাকে। Google Drive-এ ব্যাকআপ থাকলে: অ্যাপ মুছে আবার ইনস্টল করুন, একই Google অ্যাকাউন্টে লগইন করে সব ফিরিয়ে আনুন।'),
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
  Widget build(BuildContext context) => SecureView(child: _secretBuild(context));

  Widget _secretBuild(BuildContext context) {
    final brain = BrainScope.of(context);
    const p = LockPal.night;
    final unlock = _mode == _Mode.unlock;
    final title = switch (_mode) {
      _Mode.create => tr('একটি ৪ অঙ্কের PIN ঠিক করুন'),
      _Mode.confirm => tr('PIN টি আবার দিন'),
      // The two choices speak for themselves (owner, 13 Nov).
      _Mode.unlock when _bioAvailable && !_usePin && _lockedUntil == null => '',
      _ => tr('PIN দিন'),
    };
    final name = brain.userName.trim().split(RegExp(r'\s+')).first;
    final line = unlock ? (name.isEmpty ? bnEn('আবার স্বাগতম', 'Welcome back') : bnEn('আবার স্বাগতম, $name', 'Welcome back, $name')) : tr('আপনার ব্যক্তিগত সহকারী');
    final big = _mode == _Mode.google;

    // The app mark, the name and one line, on the dark top.
    Widget brand(Color nameC, Color lineC) => Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(big ? 24 : 18),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(big ? 24 : 18),
              child: Image.asset('assets/brand/app_mark.png', key: const Key('lock-app-mark'), width: big ? 88 : 64, height: big ? 88 : 64, filterQuality: FilterQuality.medium),
            ),
          ),
          SizedBox(height: big ? 16 : 12),
          Text('My Assistant', style: display(big ? 30 : 24, weight: 700, color: nameC)),
          const SizedBox(height: 4),
          Text(line, key: const Key('lock-greeting'), style: body(15, color: lineC), textAlign: TextAlign.center),
        ]);

    final pin = Column(children: [
      if (title.isNotEmpty) Text(title, style: body(18, color: p.title, weight: FontWeight.w700)),
      if (_mode == _Mode.create && _message == null) ...[
        const SizedBox(height: 6),
        Text(tr('অ্যাপ খুলতে এই PIN লাগবে। এটা শুধু এই ফোনেই থাকে।'), key: const Key('pin-why'), textAlign: TextAlign.center, style: body(14, color: p.soft, height: 1.5)),
      ],
      SizedBox(
        height: 36,
        child: Center(
          child: _lockedUntil != null
              ? LockCountdown(key: ValueKey(_lockedUntil), until: _lockedUntil!, style: body(14, color: p.error, weight: FontWeight.w600))
              : _message == null
                  ? null
                  : Text(_message!, style: body(14, color: p.error, weight: FontWeight.w600), textAlign: TextAlign.center),
        ),
      ),
      if (unlock && _bioAvailable && !_usePin && _lockedUntil == null)
        _choose(p)
      else
        PinPad(
          key: ValueKey(_padKey),
          colors: p.pad,
          onComplete: _entered,
          onBiometric: unlock && _bioAvailable ? _biometric : null,
        ),
      if (unlock)
        TextButton(
          key: const Key('forgot-pin'),
          onPressed: _forgot,
          child: Text(tr('PIN ভুলে গেছেন?'), style: body(14, weight: FontWeight.w700, color: p.accent)),
        ),
    ]);

    final content = _mode == _Mode.loading
        ? SizedBox(height: 300, child: Center(child: CircularProgressIndicator(color: p.accent)))
        : big
            ? _googleStep(p)
            : pin;

    // The foot: emergency info, the language (on the PIN pages), privacy, who made it.
    final foot = Column(children: [
      if (unlock && !brain.data.emergency.isEmpty) ...[
        OutlinedButton.icon(
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
          icon: const Icon(Icons.emergency_outlined, color: Color(0xFFDC2626)),
          label: Text(tr('জরুরি তথ্য'), style: body(15, weight: FontWeight.w600, color: const Color(0xFFDC2626))),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0x66DC2626)), shape: const StadiumBorder()),
        ),
        const SizedBox(height: 10),
      ],
      if (!big && _mode != _Mode.loading) LangSwitch(compact: true, pal: p),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (!unlock)
          InkWell(
            key: const Key('welcome-voice-note'),
            onTap: _privacy,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline_rounded, size: 14, color: p.soft),
                const SizedBox(width: 4),
                Text(tr('গোপনীয়তা'), style: body(12.5, color: p.soft, weight: FontWeight.w600)),
              ]),
            ),
          ),
        if (!unlock) Text('·', style: body(12.5, color: p.soft)),
        // The company behind the app (owner, 28 Oct).
        InkWell(
          key: const Key('lock-company'),
          onTap: () => BrainScope.read(context).services.launcher.openUrl(Uri.parse('https://owlgorithmlabs.com/')),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text('Owlgorithm Labs', style: body(12.5, color: p.soft)),
          ),
        ),
      ]),
    ]);

    final bottom = MediaQuery.paddingOf(context).bottom;
    Widget footPad(Widget f) => Padding(padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 12), child: f);

// Dark above with the mark, a light sheet rising from below.
    final bodyW = LayoutBuilder(builder: (context, box) {
      // Where the words start (as before), and the picture: owner, 23 Nov,
      // "লগইন পেইজে ছবিটা হোম পেইজের মত না" — the whole sea as on Home, its
      // lower part fading under the mark instead of a thin strip above it.
      final start = box.maxHeight * (big ? 0.30 : 0.16);
      final upper = math.min(box.maxWidth * 0.92, start + box.maxHeight * (big ? 0.14 : 0.11));
      return SingleChildScrollView(
        child: Stack(children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: upper,
            // The home's Cox's Bazar sea at night behind the mark (owner,
            // 19 Nov), a little darker at the top for the clock and bar.
            child: Stack(fit: StackFit.expand, children: [
              Image.asset('assets/sky/cox_night.webp', key: const Key('lock-scene'), fit: BoxFit.cover, alignment: const Alignment(0, 0.55), filterQuality: FilterQuality.medium),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // Melting into the sheet below (owner, 19 Nov: no edge
                    // between the picture and the part with the words).
                    colors: [p.bg.withValues(alpha: 0.30), p.sheet.withValues(alpha: 0), p.sheet.withValues(alpha: 0.55), p.sheet],
                    stops: [0, 0.3, ((start + 8) / upper).clamp(0.4, 0.95), 1],
                  ),
                ),
              ),
            ]),
          ),
          Column(children: [
            SizedBox(height: start),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - start),
              child: SizedBox(
                width: double.infinity,
                // The buttons a little lower than right under the top (owner,
                // 19 Nov: "অল্প একটু নিচে", not at the bottom).
                child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                    child: Column(children: [
                      // The mark starts right where the picture melts into
                      // the sheet (owner, 20 Nov: not in the middle of it).
                      brand(p.title, p.text),
                      SizedBox(height: big ? 28 : 14),
                      if (big) ...[LangSwitch(pal: p), const SizedBox(height: 40)],
                      if (unlock && _bioAvailable && !_usePin && _lockedUntil == null) const SizedBox(height: 40),
                      content,
                    ]),
                  ),
                  footPad(foot),
                ]),
              ),
            ),
          ]),
        ]),
      );
    });
    return Scaffold(backgroundColor: p.sheet, body: bodyW);
  }
}

/// English | বাংলা (owner, 19 Nov). Big on the sign-up page: two halves of
/// one pill, the chosen one filled. Small on the PIN pages: two words at the
/// foot. Each name is in its own language, so anyone finds theirs.
class LangSwitch extends StatelessWidget {
  const LangSwitch({super.key, this.compact = false, this.pal = LockPal.night});

  final bool compact;
  final LockPal pal;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final en = brain.english;
    final p = pal;
    if (compact) {
      Widget word(String label, bool on, bool toEn, Key key) => InkWell(
            key: key,
            borderRadius: BorderRadius.circular(14),
            onTap: on ? null : () => brain.setEnglish(toEn),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(label, style: body(14, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? p.accent : p.soft)),
            ),
          );
      return Row(key: const Key('lock-lang'), mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.translate_rounded, size: 16, color: p.soft),
        const SizedBox(width: 2),
        word('English', en, true, const Key('lock-lang-en')),
        Container(width: 1, height: 14, color: p.soft.withValues(alpha: 0.4)),
        word('বাংলা', !en, false, const Key('lock-lang-bn')),
      ]);
    }
    final fill = p.accent;
    final onFill = p.onAccent;
    final off = p.text;
    Widget half(String label, bool on, bool toEn, Key key) => Expanded(
          child: Semantics(
            button: true,
            selected: on,
            child: GestureDetector(
              key: key,
              behavior: HitTestBehavior.opaque,
              onTap: on ? null : () => brain.setEnglish(toEn),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: on ? fill : Colors.transparent, borderRadius: BorderRadius.circular(21)),
                child: Text(label, style: body(15, weight: on ? FontWeight.w700 : FontWeight.w500, color: on ? onFill : off)),
              ),
            ),
          ),
        );
    return ConstrainedBox(
      key: const Key('lock-lang'),
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: p.track,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(children: [
          half('English', en, true, const Key('lock-lang-en')),
          half('বাংলা', !en, false, const Key('lock-lang-bn')),
        ]),
      ),
    );
  }
}
