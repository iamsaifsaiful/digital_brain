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

/// The look of the sign-up and PIN pages (owner, 19 Nov: three designs to
/// choose from): 1 light, 2 a green header, 3 dark; (then three more ideas)
/// 4 all green, 5 light with the app's parts shown, 6 dark with a white sheet.
int lockDesign = 2;

/// The PIN pages' colours for [lockDesign].
class LockPal {
  const LockPal({
    required this.bg,
    required this.title,
    required this.text,
    required this.soft,
    required this.accent,
    required this.onAccent,
    required this.track,
    required this.error,
    required this.padDark,
    this.pad,
    this.googleWhite = false,
  });
  final Color bg, title, text, soft, accent, onAccent, track, error;
  final bool padDark;

  /// The PIN pad's own colours (see PinPad.colors), on a coloured ground.
  final (Color, Color, Color, Color)? pad;

  /// The Google button white (on a dark or green ground) or in the accent.
  final bool googleWhite;

  static const brand = Color(0xFF0F6B4F);

  static const light = LockPal(
    bg: Color(0xFFF5F7F6),
    title: Color(0xFF14261F),
    text: Color(0xFF3E524B),
    soft: Color(0xFF7A8A84),
    accent: brand,
    onAccent: Colors.white,
    track: Color(0x0F0F2A20),
    error: Color(0xFFB45309),
    padDark: false,
  );

  static const dark = LockPal(
    bg: C.night,
    title: Colors.white,
    text: Color(0xFFC9D3CE),
    soft: Color(0xFF8E9B95),
    accent: C.mint,
    onAccent: C.night,
    track: Color(0x14FFFFFF),
    error: C.peach,
    padDark: true,
    googleWhite: true,
  );

  static const green = LockPal(
    bg: brand,
    title: Colors.white,
    text: Color(0xDDFFFFFF),
    soft: Color(0xB3FFFFFF),
    accent: Colors.white,
    onAccent: brand,
    track: Color(0x29FFFFFF),
    error: Color(0xFFFFD7A8),
    padDark: true,
    pad: (Colors.white, Color(0x24FFFFFF), Colors.white, Color(0x80FFFFFF)),
    googleWhite: true,
  );

  static LockPal get now => switch (lockDesign) { 3 => dark, 4 => green, _ => light };
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
            backgroundColor: p.googleWhite ? Colors.white : p.accent,
            foregroundColor: p.googleWhite ? const Color(0xFF1F2937) : Colors.white,
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
          label: Text(tr('Google দিয়ে লগইন'), style: body(16, weight: FontWeight.w700, color: p.googleWhite ? const Color(0xFF1F2937) : Colors.white)),
        ),
      );

  /// Sign-up (owner, 19 Nov: less to read): one line, the Google button and
  /// "not now". The language is chosen above it.
  Widget _googleStep(LockPal p) => Column(children: [
        Text(tr('শুরু করতে Google দিয়ে লগইন করুন'), textAlign: TextAlign.center, style: body(17, color: p.title, weight: FontWeight.w700)),
        const SizedBox(height: 18),
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
  Widget build(BuildContext context) => SecureView(child: _secretBuild(context));

  Widget _secretBuild(BuildContext context) {
    final brain = BrainScope.of(context);
    final p = LockPal.now;
    final header = lockDesign == 2 || lockDesign == 4;
    final unlock = _mode == _Mode.unlock;
    final title = switch (_mode) {
      _Mode.create => tr('একটি ৪ অঙ্কের PIN ঠিক করুন'),
      _Mode.confirm => tr('PIN টি আবার দিন'),
      // The two choices speak for themselves (owner, 13 Nov).
      _Mode.unlock when _bioAvailable && !_usePin && _lockedUntil == null => '',
      _ => tr('PIN দিন'),
    };
    final name = brain.userName.trim().split(RegExp(r'\s+')).first;
    final line = unlock
        ? (name.isEmpty ? bnEn('আবার স্বাগতম', 'Welcome back') : bnEn('আবার স্বাগতম, $name', 'Welcome back, $name'))
        : tr('আপনার ব্যক্তিগত সহকারী');
    final big = _mode == _Mode.google;

    // The app mark, the name and one line: on the green header in white.
    Widget brand(Color nameC, Color lineC) => Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: EdgeInsets.all(header ? 3 : 0),
            decoration: BoxDecoration(
              color: header ? Colors.white.withValues(alpha: 0.9) : null,
              borderRadius: BorderRadius.circular((big ? 24 : 18) + (header ? 3 : 0)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: header ? 0.18 : 0.10), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(big ? 24 : 18),
              child: Image.asset('assets/brand/app_mark.png',
                  key: const Key('lock-app-mark'), width: big ? 88 : 64, height: big ? 88 : 64, filterQuality: FilterQuality.medium),
            ),
          ),
          SizedBox(height: big ? 16 : 12),
          Text('My Assistant', style: display(big ? 30 : 24, weight: 700, color: nameC)),
          const SizedBox(height: 4),
          Text(line, key: const Key('lock-greeting'), style: body(15, color: lineC), textAlign: TextAlign.center),
        ]);

    final pin = Column(children: [
      if (title.isNotEmpty) Text(title, style: body(18, color: p.title, weight: FontWeight.w700)),
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
          dark: p.padDark,
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

    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    Widget footPad(Widget f) => Padding(padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 12), child: f);

    // Design 5: what the app holds, as four small tiles (owner, 19 Nov:
    // a picture says it without text).
    Widget tiles() {
      Widget tile(IconData i, String w, Color c) => Expanded(
            child: Container(
              height: 76,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(18)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(i, color: c, size: 26),
                const SizedBox(height: 6),
                Text(trm(w), style: body(12.5, color: p.text, weight: FontWeight.w600)),
              ]),
            ),
          );
      return Row(children: [
        tile(Icons.notifications_none_rounded, 'রিমাইন্ডার', const Color(0xFFD97706)),
        tile(Icons.account_balance_wallet_outlined, 'হিসাব', LockPal.brand),
        tile(Icons.sticky_note_2_outlined, 'নোট', const Color(0xFFDB2777)),
        tile(Icons.medication_outlined, 'ওষুধ', const Color(0xFF2563EB)),
      ]);
    }

    final Widget bodyW;
    switch (lockDesign) {
      case 2:
        // A green header with the mark, the white page under it.
        bodyW = _fill(Column(children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, top + (big ? 64 : 20), 24, big ? 34 : 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF138A64), LockPal.brand]),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
            ),
            child: Column(children: [
              brand(Colors.white, const Color(0xFFD5F1E6)),
              if (big) ...[const SizedBox(height: 22), const LangSwitch(pal: LockPal.light, onGreen: true)],
            ]),
          ),
          Padding(padding: EdgeInsets.fromLTRB(24, big ? 48 : 24, 24, 0), child: content),
        ]), footPad(foot));
      case 4:
        // All green: the whole page in the app's colour.
        bodyW = DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF16956C), LockPal.brand, Color(0xFF0B5640)]),
          ),
          child: _fill(
            Padding(
              padding: EdgeInsets.fromLTRB(24, top + (big ? 96 : 36), 24, 0),
              child: Column(children: [
                brand(Colors.white, const Color(0xFFD5F1E6)),
                if (big) ...[const SizedBox(height: 24), const LangSwitch(pal: LockPal.light, onGreen: true)],
                SizedBox(height: big ? 48 : 26),
                content,
              ]),
            ),
            footPad(foot),
          ),
        );
      case 5:
        // Light, set from the left: the mark and name small, a big greeting,
        // and on sign-up what the app holds.
        bodyW = _fill(
          Padding(
            padding: EdgeInsets.fromLTRB(24, top + 24, 24, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset('assets/brand/app_mark.png', key: const Key('lock-app-mark'), width: 40, height: 40, filterQuality: FilterQuality.medium),
                ),
                const SizedBox(width: 10),
                Text('My Assistant', style: display(19, weight: 700, color: p.title)),
                const Spacer(),
                if (big) LangSwitch(compact: true, pal: p, bare: true),
              ]),
              SizedBox(height: big ? 48 : 36),
              Text(
                big ? bnEn('আপনার দিনের সব কাজ,\nএক জায়গায়', 'Your whole day,\nin one place') : line,
                key: const Key('lock-greeting'),
                style: display(big ? 30 : 26, weight: 700, color: p.title, height: 1.25),
              ),
              if (big) ...[const SizedBox(height: 24), tiles(), const SizedBox(height: 36)] else const SizedBox(height: 28),
              Center(child: content),
            ]),
          ),
          footPad(foot),
        );
      case 6:
        // Dark above with the mark, a white sheet rising from below.
        bodyW = LayoutBuilder(builder: (context, box) {
          final upper = box.maxHeight * (big ? 0.40 : 0.27);
          return SingleChildScrollView(
            child: Column(children: [
              SizedBox(
                height: upper,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(center: const Alignment(0, -0.2), radius: 0.9, colors: [C.mint.withValues(alpha: 0.16), C.night.withValues(alpha: 0)]),
                  ),
                  child: Padding(padding: EdgeInsets.only(top: top), child: Center(child: brand(Colors.white, const Color(0xFFA9B5AF)))),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight - upper),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(color: Color(0xFFF5F7F6), borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                  child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, big ? 30 : 24, 24, 0),
                      child: Column(children: [
                        if (big) ...[LangSwitch(pal: p), const SizedBox(height: 30)],
                        content,
                      ]),
                    ),
                    footPad(foot),
                  ]),
                ),
              ),
            ]),
          );
        });
      default:
        bodyW = _fill(
          Padding(
            padding: EdgeInsets.fromLTRB(24, top + (big ? 96 : 36), 24, 0),
            child: Column(children: [
              brand(p.title, p.soft),
              if (big) ...[const SizedBox(height: 24), LangSwitch(pal: p)],
              SizedBox(height: big ? 40 : 26),
              content,
            ]),
          ),
          footPad(foot),
        );
    }

    return Scaffold(backgroundColor: lockDesign == 6 ? C.night : p.bg, body: bodyW);
  }

  /// The page at the top, the foot at the bottom, scrolling when the
  /// screen is short.
  Widget _fill(Widget page, Widget foot) => LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [page, foot]),
          ),
        ),
      );
}

/// English | বাংলা (owner, 19 Nov). Big on the sign-up page: two halves of
/// one pill, the chosen one filled. Small on the PIN pages: two words at the
/// foot. Each name is in its own language, so anyone finds theirs.
class LangSwitch extends StatelessWidget {
  const LangSwitch({super.key, this.compact = false, this.pal = LockPal.dark, this.onGreen = false, this.bare = false});

  /// The small one without its icon (design 5's top row).
  final bool bare;

  final bool compact;
  final LockPal pal;

  /// On the green header: white on translucent white.
  final bool onGreen;

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
        if (!bare) ...[Icon(Icons.translate_rounded, size: 16, color: p.soft), const SizedBox(width: 2)],
        word('English', en, true, const Key('lock-lang-en')),
        Container(width: 1, height: 14, color: p.soft.withValues(alpha: 0.4)),
        word('বাংলা', !en, false, const Key('lock-lang-bn')),
      ]);
    }
    final fill = onGreen ? Colors.white : p.accent;
    final onFill = onGreen ? LockPal.brand : p.onAccent;
    final off = onGreen ? Colors.white.withValues(alpha: 0.85) : p.text;
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
          color: onGreen ? Colors.white.withValues(alpha: 0.16) : p.track,
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
