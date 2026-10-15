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
                          ? tr('PIN শুধু এই ফোনে, এনক্রিপ্ট করে রাখা হয়। ভুলে গেলে তথ্য ফেরত আনা যাবে না — ব্যাকআপ রাখুন।')
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
