import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../services/lock.dart';
import '../state/brain.dart';
import 'theme.dart';

const pinLength = 4;

/// Dots plus a number pad. Calls [onComplete] once [pinLength] digits are in.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onComplete, this.dark = true, this.onBiometric, this.enabled = true});
  final Future<void> Function(String pin, VoidCallback clear) onComplete;
  final bool dark;
  final VoidCallback? onBiometric;
  final bool enabled;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  bool _busy = false;

  void _clear() {
    if (mounted) setState(() => _pin = '');
  }

  Future<void> _press(String d) async {
    if (_busy || !widget.enabled || _pin.length >= pinLength) return;
    setState(() => _pin += d);
    if (_pin.length == pinLength) {
      _busy = true;
      try {
        await widget.onComplete(_pin, _clear);
      } finally {
        _busy = false;
      }
    }
  }

  void _back() {
    if (_pin.isEmpty || _busy) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.dark ? Colors.white : C.ink;
    final keyBg = widget.dark ? C.dark2 : C.line2;
    final dotOn = widget.dark ? C.mint : C.green;
    final dotOff = widget.dark ? const Color(0xFF5D6B65) : C.border;

    Widget key(String d) => Semantics(
          button: true,
          label: d,
          child: Material(
            color: keyBg,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _press(d),
              child: SizedBox(width: 68, height: 68, child: Center(child: Text(bnDigits(d), style: display(26, weight: 500, color: fg)))),
            ),
          ),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '${bnDigits(_pin.length)}টি অঙ্ক দেওয়া হয়েছে',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < pinLength; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _pin.length ? dotOn : Colors.transparent,
                    border: i < _pin.length ? null : Border.all(color: dotOff, width: 2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ]) ...[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final d in row) Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: key(d))]),
          const SizedBox(height: 14),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 68,
                height: 68,
                child: widget.onBiometric == null
                    ? null
                    : IconButton(
                        tooltip: 'আঙুলের ছাপে খুলুন',
                        onPressed: widget.onBiometric,
                        icon: Icon(Icons.fingerprint_rounded, size: 36, color: widget.dark ? C.mint : C.green),
                      ),
              ),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: key('0')),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 68,
                height: 68,
                child: IconButton(
                  tooltip: 'মুছুন',
                  onPressed: _back,
                  icon: Icon(Icons.backspace_outlined, size: 26, color: widget.dark ? C.onDarkMuted : C.muted),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String lockedMessage(DateTime until, DateTime now) {
  final secs = until.difference(now).inSeconds.clamp(1, 99999);
  if (secs < 60) return 'অনেকবার ভুল হয়েছে। ${bnDigits(secs)} সেকেন্ড পর আবার চেষ্টা করুন।';
  return 'অনেকবার ভুল হয়েছে। ${bnDigits((secs / 60).ceil())} মিনিট পর আবার চেষ্টা করুন।';
}

/// Makes sure the person holding the phone is the owner before showing a
/// secret: fingerprint first, PIN otherwise. A check within the last 30
/// seconds counts.
Future<bool> verifyUser(BuildContext context, {String reason = 'সুরক্ষিত তথ্য দেখতে যাচাই করুন'}) async {
  final brain = BrainScope.read(context);
  if (brain.recentlyVerified()) return true;
  if (await brain.services.lock.tryBiometrics(reason)) {
    brain.markVerified();
    return true;
  }
  if (!context.mounted) return false;
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (c) => _PinSheet(reason: reason),
  );
  if (ok == true) {
    brain.markVerified();
    return true;
  }
  return false;
}

class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.reason});
  final String reason;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.read(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('PIN দিন', style: display(20)),
            const SizedBox(height: 4),
            Text(widget.reason, style: body(14, color: C.muted), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            SizedBox(height: 22, child: _error == null ? null : Text(_error!, style: body(14, color: C.red, weight: FontWeight.w600), textAlign: TextAlign.center)),
            const SizedBox(height: 12),
            PinPad(
              dark: false,
              onComplete: (pin, clear) async {
                final r = await brain.services.lock.checkPin(pin);
                if (!context.mounted) return;
                switch (r) {
                  case PinOk():
                    Navigator.pop(context, true);
                  case PinWrong(:final triesLeft):
                    setState(() => _error = 'PIN মেলেনি। আর ${bnDigits(triesLeft)} বার চেষ্টা করা যাবে।');
                    clear();
                  case PinLocked(:final until):
                    setState(() => _error = lockedMessage(until, brain.services.now()));
                    clear();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
