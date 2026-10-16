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

/// First run: choose a PIN. Every other time: unlock with fingerprint or PIN.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

enum _Mode { loading, create, confirm, unlock }

class _LockScreenState extends State<LockScreen> {
  _Mode _mode = _Mode.loading;
  String _first = '';
  String? _message;
  DateTime? _lockedUntil;
  bool _bioAvailable = false;
  int _padKey = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final lock = BrainScope.read(context).services.lock;
    final has = await lock.hasPin();
    final bio = has && await lock.biometricsOn() && await lock.biometrics.available();
    if (!mounted) return;
    setState(() {
      _mode = has ? _Mode.unlock : _Mode.create;
      _bioAvailable = bio;
    });
    if (bio) _biometric();
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
    final lock = BrainScope.read(context).services.lock;
    final bio = await lock.biometricsOn() && await lock.biometrics.available();
    final rec = await lock.hasRecovery();
    if (!mounted) return;
    final how = await showModalBottomSheet<String>(
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
            if (rec) ...[
              SecondaryButton(key: const Key('forgot-password'), label: tr('ব্যাকআপ-পাসওয়ার্ড দিয়ে'), icon: Icons.password_rounded, onPressed: () => Navigator.pop(ctx, 'password')),
              const SizedBox(height: 10),
            ],
            Text(
                bio || rec
                    ? tr('এগুলোর কোনোটা না পারলে: অ্যাপ মুছে আবার ইনস্টল করুন, একই Google অ্যাকাউন্টে লগইন করে ব্যাকআপ-পাসওয়ার্ড দিয়ে Drive-এর ব্যাকআপ ফিরিয়ে আনুন।')
                    : tr('এই ফোনে আঙুলের ছাপ বা ব্যাকআপ-পাসওয়ার্ড চালু নেই, তাই PIN ছাড়া খোলা যাবে না — যাতে ফোন অন্যের হাতে গেলেও আপনার তথ্য নিরাপদ থাকে। Google Drive-এ ব্যাকআপ থাকলে: অ্যাপ মুছে আবার ইনস্টল করুন, একই Google অ্যাকাউন্টে লগইন করে ব্যাকআপ-পাসওয়ার্ড দিয়ে সব ফিরিয়ে আনুন।'),
                style: body(13, color: C.muted, height: 1.5)),
          ]),
        ),
      ),
    );
    if (how == null || !mounted) return;
    var ok = false;
    if (how == 'bio') {
      ok = await lock.biometrics.authenticate(tr('নতুন PIN দিতে আঙুলের ছাপ দিন'));
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
      case _Mode.loading:
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
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(22)),
                          child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 42),
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
                      _mode == _Mode.create || _mode == _Mode.confirm
                          ? tr('PIN শুধু এই ফোনে, এনক্রিপ্ট করে রাখা হয়। ভুলে গেলে আঙুলের ছাপ বা Google Drive ব্যাকআপের পাসওয়ার্ড দিয়ে নতুন PIN দেওয়া যাবে।')
                          : tr('কিছুক্ষণ ব্যবহার না করলে অ্যাপ নিজে থেকে লক হয়ে যায়'),
                      style: body(13, color: const Color(0xFFA9B5AF), height: 1.5),
                      textAlign: TextAlign.center,
                    ),
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
