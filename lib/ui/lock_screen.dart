import 'dart:async';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../services/lock.dart';
import '../state/hisab.dart';
import 'kit.dart';

/// Number pad with dots, used for opening and for setting the PIN.
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.length, required this.onDigit, required this.onBack, this.onBio, this.max = 4});
  final int length;
  final int max;
  final ValueChanged<String> onDigit;
  final VoidCallback onBack;
  final VoidCallback? onBio;

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onTap, IconData? icon, String? semantic}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Semantics(
              button: true,
              label: semantic ?? label,
              child: Material(
                color: icon != null ? Colors.transparent : K.card,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: onTap,
                  child: SizedBox(
                    height: 60,
                    child: Center(child: icon != null ? Icon(icon, size: 26, color: K.navy) : Text(label, style: t(24, w: FontWeight.w500))),
                  ),
                ),
              ),
            ),
          ),
        );
    Widget row(List<String> ds) => Row(children: [for (final d in ds) key(bn(d), onTap: () => onDigit(d))]);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < max; i++)
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(shape: BoxShape.circle, color: i < length ? K.blue : Colors.transparent, border: Border.all(color: i < length ? K.blue : const Color(0xFFBDBDBD), width: 2)),
          ),
      ]),
      const SizedBox(height: 28),
      row(['1', '2', '3']),
      row(['4', '5', '6']),
      row(['7', '8', '9']),
      Row(children: [
        onBio != null ? key('', icon: Icons.fingerprint_rounded, onTap: onBio, semantic: 'আঙুলের ছাপ') : const Expanded(child: SizedBox()),
        key(bn('0'), onTap: () => onDigit('0')),
        key('', icon: Icons.backspace_outlined, onTap: onBack, semantic: 'মুছুন'),
      ]),
    ]);
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.h, required this.onOpen});
  final Hisab h;
  final VoidCallback onOpen;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  String _msg = '';
  bool _busy = false;
  bool _bio = false;
  DateTime? _until;
  Timer? _tick;

  LockService get lock => widget.h.s.lock;

  @override
  void initState() {
    super.initState();
    _initBio();
  }

  Future<void> _initBio() async {
    final on = await lock.biometricsOn() && await lock.biometrics.available();
    if (!mounted) return;
    setState(() => _bio = on);
    if (on) _tryBio();
  }

  Future<void> _tryBio() async {
    final ok = await lock.tryBiometrics('হিসাব খুলতে আঙুল দিন');
    if (ok && mounted) widget.onOpen();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _digit(String d) async {
    if (_busy || _until != null || _pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length < 4) return;
    setState(() => _busy = true);
    final r = await lock.checkPin(_pin);
    if (!mounted) return;
    switch (r) {
      case PinOk():
        widget.onOpen();
      case PinWrong(:final triesLeft):
        setState(() {
          _pin = '';
          _busy = false;
          _msg = 'পিন ভুল। আর ${bn('$triesLeft')} বার চেষ্টা করা যাবে।';
        });
      case PinLocked(:final until):
        setState(() {
          _pin = '';
          _busy = false;
          _until = until;
        });
        _tick?.cancel();
        _tick = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted) return;
          if (DateTime.now().isAfter(_until!)) {
            _tick?.cancel();
            setState(() {
              _until = null;
              _msg = '';
            });
          } else {
            setState(() {});
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wait = _until == null ? 0 : _until!.difference(DateTime.now()).inSeconds + 1;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(children: [
            const Spacer(),
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: K.blue, shape: BoxShape.circle),
              child: const Icon(Icons.lock_rounded, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 16),
            Text('রিয়াল-বিকাশ হিসাব', style: t(21, w: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              _until != null ? '${bn('$wait')} সেকেন্ড পর আবার চেষ্টা করুন' : (_msg.isEmpty ? 'পিন দিন' : _msg),
              style: t(14.5, c: _msg.isEmpty && _until == null ? K.muted : K.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            PinPad(
              length: _pin.length,
              onDigit: _digit,
              onBack: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1)),
              onBio: _bio ? _tryBio : null,
            ),
            const Spacer(),
          ]),
        ),
      ),
    );
  }
}

/// First run: choose a 4-digit PIN, twice.
class PinSetup extends StatefulWidget {
  const PinSetup({super.key, required this.lock, required this.onDone, this.title = 'অ্যাপের পিন ঠিক করুন'});
  final LockService lock;
  final VoidCallback onDone;
  final String title;

  @override
  State<PinSetup> createState() => _PinSetupState();
}

class _PinSetupState extends State<PinSetup> {
  String _first = '';
  String _pin = '';
  String _msg = '';
  bool _busy = false;

  Future<void> _digit(String d) async {
    if (_busy || _pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length < 4) return;
    if (_first.isEmpty) {
      setState(() {
        _first = _pin;
        _pin = '';
        _msg = '';
      });
      return;
    }
    if (_pin != _first) {
      setState(() {
        _first = '';
        _pin = '';
        _msg = 'দুইবার একই হয়নি, আবার দিন';
      });
      return;
    }
    setState(() => _busy = true);
    await widget.lock.setPin(_pin);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(children: [
              const Spacer(),
              const Icon(Icons.shield_outlined, size: 52, color: K.blue),
              const SizedBox(height: 14),
              Text(widget.title, style: t(20, w: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(
                _msg.isNotEmpty ? _msg : (_first.isEmpty ? '৪ সংখ্যার পিন দিন। অ্যাপ খুলতে এটা লাগবে।' : 'আরেকবার একই পিন দিন'),
                textAlign: TextAlign.center,
                style: t(14.5, c: _msg.isNotEmpty ? K.red : K.muted, h: 1.5),
              ),
              const SizedBox(height: 30),
              PinPad(length: _pin.length, onDigit: _digit, onBack: () => setState(() => _pin = _pin.isEmpty ? '' : _pin.substring(0, _pin.length - 1))),
              const Spacer(),
            ]),
          ),
        ),
      );
}
