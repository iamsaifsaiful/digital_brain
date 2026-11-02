import 'dart:async';
import 'dart:math' as math;

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
                    child: Center(child: icon != null ? Icon(icon, size: 26, color: K.navy) : Tx(label, style: t(24, w: FontWeight.w500))),
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

/// The opening animation: a riyal coin leaves the SAR side, travels along
/// the arc and lands as taka on the phone in Bangladesh, which then ticks.
/// It tells what the app does in two seconds.
class ExchangeAnim extends StatefulWidget {
  const ExchangeAnim({super.key, this.width = 270});
  final double width;

  @override
  State<ExchangeAnim> createState() => _ExchangeAnimState();
}

class _ExchangeAnimState extends State<ExchangeAnim> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static double _seg(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final hgt = w * 0.46;
    return Semantics(
      label: 'রিয়াল থেকে টাকা যাচ্ছে',
      child: SizedBox(
        width: w,
        height: hgt,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final inL = Curves.easeOutBack.transform(_seg(t, 0, 0.22));
            final inR = Curves.easeOutBack.transform(_seg(t, 0.1, 0.32));
            final fly = Curves.easeInOutCubic.transform(_seg(t, 0.3, 0.78));
            final done = Curves.elasticOut.transform(_seg(t, 0.78, 1));
            const r = 34.0;
            final a = Offset(r + 6, hgt - r - 6);
            final b = Offset(w - r - 6, hgt - r - 6);
            final ctrl = Offset(w / 2, -hgt * 0.25);
            Offset at(double u) => Offset(
                  math.pow(1 - u, 2) * a.dx + 2 * (1 - u) * u * ctrl.dx + u * u * b.dx,
                  math.pow(1 - u, 2) * a.dy + 2 * (1 - u) * u * ctrl.dy + u * u * b.dy,
                );
            final coin = at(fly);
            final showCoin = t > 0.3 && t < 0.8;
            Widget badge(Offset c, double scale, Color bg, String label, {Widget? extra}) => Positioned(
                  left: c.dx - r,
                  top: c.dy - r,
                  child: Transform.scale(
                    scale: scale,
                    child: Stack(clipBehavior: Clip.none, children: [
                      Container(
                        width: r * 2,
                        height: r * 2,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: bg, shape: BoxShape.circle, boxShadow: [BoxShadow(color: bg.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))]),
                        child: Tx(label, style: t2(label.length > 2 ? 17 : 26)),
                      ),
                      if (extra != null) extra,
                    ]),
                  ),
                );
            return Stack(clipBehavior: Clip.none, children: [
              Positioned.fill(child: CustomPaint(painter: _ArcPainter(a, ctrl, b, fly, t > 0.3))),
              badge(a, inL, K.navy, 'SAR'),
              badge(
                b,
                inR * (1 + 0.12 * math.sin(done * math.pi)),
                Color.lerp(K.blue, const Color(0xFF1E9E3A), _seg(t, 0.78, 0.86))!,
                '৳',
                extra: t > 0.8
                    ? Positioned(
                        right: -4,
                        top: -4,
                        child: Transform.scale(
                          scale: done,
                          child: const CircleAvatar(radius: 13, backgroundColor: Colors.white, child: Icon(Icons.check_circle_rounded, size: 26, color: Color(0xFF1E9E3A))),
                        ),
                      )
                    : null,
              ),
              if (showCoin)
                Positioned(
                  left: coin.dx - 13,
                  top: coin.dy - 13,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: K.amber, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                  ),
                ),
            ]);
          },
        ),
      ),
    );
  }

  TextStyle t2(double size) => t(size, w: FontWeight.w700, c: Colors.white);
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.a, this.c, this.b, this.f, this.on);
  final Offset a, c, b;
  final double f;
  final bool on;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(c.dx, c.dy, b.dx, b.dy);
    final dash = Paint()
      ..color = const Color(0xFFC9D5EE)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final done = Paint()
      ..color = K.blue
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      for (var d = 44.0; d < m.length - 44; d += 14) {
        final p = m.getTangentForOffset(d)!.position;
        final reached = on && d / m.length <= f;
        canvas.drawCircle(p, reached ? 2.6 : 2, reached ? done : dash);
      }
    }
  }

  @override
  bool shouldRepaint(_ArcPainter o) => o.f != f || o.on != on;
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
            const ExchangeAnim(),
            const SizedBox(height: 18),
            Tx('রিয়াল-বিকাশ হিসাব', style: t(21, w: FontWeight.w600)),
            const SizedBox(height: 6),
            Tx(
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
              const ExchangeAnim(width: 230),
              const SizedBox(height: 14),
              Tx(widget.title, style: t(20, w: FontWeight.w600)),
              const SizedBox(height: 6),
              Tx(
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
