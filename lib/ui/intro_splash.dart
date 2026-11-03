import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/lang.dart';
import 'theme.dart';

/// Plays on every start of the app, before the PIN page (owner, 3 Nov).
/// Release builds only, so tests open straight on the PIN page; a test
/// that wants it turns it on.
bool introOn = const bool.fromEnvironment('dart.vm.product');

/// The app's mark grows in, voice rings spread out from it as if it is
/// listening, then the name and the line under it come up. About 1.8
/// seconds; a tap skips it. With animations turned off on the phone it is
/// a short still picture.
class IntroGate extends StatefulWidget {
  const IntroGate({super.key, required this.child});
  final Widget child;

  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  bool _done = !introOn;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        child: _done ? KeyedSubtree(key: const ValueKey('app'), child: widget.child) : IntroSplash(key: const ValueKey('intro-splash'), onDone: () => setState(() => _done = true)),
      );
}

class IntroSplash extends StatefulWidget {
  const IntroSplash({super.key, required this.onDone});
  final VoidCallback onDone;

  @override
  State<IntroSplash> createState() => _IntroSplashState();
}

class _IntroSplashState extends State<IntroSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  bool _ended = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    // Animations off on the phone: a still picture for a moment.
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
      Future.delayed(const Duration(milliseconds: 500), _end);
    } else {
      _c.forward().whenComplete(_end);
    }
  }

  void _end() {
    if (_ended || !mounted) return;
    _ended = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _part(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('intro'),
      behavior: HitTestBehavior.opaque,
      onTap: _end,
      child: Material(
        color: C.night,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final grow = Curves.easeOutBack.transform(_part(t, 0, 0.32));
            final markIn = Curves.easeOut.transform(_part(t, 0, 0.2));
            final name = Curves.easeOutCubic.transform(_part(t, 0.38, 0.62));
            final line = Curves.easeOutCubic.transform(_part(t, 0.5, 0.74));
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(alignment: Alignment.center, children: [
                    // Voice rings: spread out from the mark and fade, one after another.
                    CustomPaint(size: const Size(220, 220), painter: _Rings(_part(t, 0.18, 1))),
                    Opacity(
                      opacity: markIn,
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * grow,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset('assets/brand/app_mark.png', width: 96, height: 96, filterQuality: FilterQuality.medium),
                        ),
                      ),
                    ),
                  ]),
                ),
                Opacity(
                  opacity: name,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - name)),
                    child: Text('My Assistant', style: display(30, weight: 700, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 6),
                Opacity(
                  opacity: line,
                  child: Transform.translate(
                    offset: Offset(0, 10 * (1 - line)),
                    child: Text(tr('আপনার ব্যক্তিগত সহকারী'), style: body(14.5, color: const Color(0xFFA9B5AF))),
                  ),
                ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

/// Three rings in the mark's yellow, each widening and fading in turn.
class _Rings extends CustomPainter {
  _Rings(this.t);
  final double t;

  static const _yellow = Color(0xFFF3B93C);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final p = ((t * 1.6) - i * 0.3).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final r = 52 + 58 * Curves.easeOut.transform(p);
      final a = (1 - p) * 0.55;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - p) + 1
          ..color = _yellow.withValues(alpha: a),
      );
    }
    // A soft glow behind the mark while the rings run.
    final glow = math.sin(math.pi * t.clamp(0.0, 1.0)) * 0.12;
    canvas.drawCircle(c, 60, Paint()..color = _yellow.withValues(alpha: glow));
  }

  @override
  bool shouldRepaint(_Rings old) => old.t != t;
}
