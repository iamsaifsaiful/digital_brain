import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/lang.dart';
import 'theme.dart';

/// Plays on every start of the app, before the PIN page (owner, 3 Nov).
/// Release builds only, so tests open straight on the PIN page; a test
/// that wants it turns it on.
bool introOn = const bool.fromEnvironment('dart.vm.product');

/// What the app keeps — reminders, money, notes, passwords, papers,
/// people — comes in from around and goes into the mark, a lock closes on
/// it, then the name and "all in one place, locked". About 2.8 seconds; a tap skips it. With animations turned off on the phone it is
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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
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

  /// What the app keeps, each coming in to the mark (owner, 3 Nov: "সব এক
  /// জায়গায়, তালাবদ্ধ").
  static final _things = <(IconData?, String, Color)>[
    (Icons.notifications_none_rounded, 'রিমাইন্ডার', const Color(0xFFE5C487)),
    (null, 'হিসাব', const Color(0xFF9DB7D6)),
    (Icons.sticky_note_2_outlined, 'নোট', const Color(0xFFF2BB8E)),
    (Icons.key_outlined, 'পাসওয়ার্ড', const Color(0xFFBBA9E0)),
    (Icons.folder_copy_outlined, 'ডকুমেন্টস', const Color(0xFF8FD3C3)),
    (Icons.call_outlined, 'যোগাযোগ', const Color(0xFFE99AA0)),
  ];

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
            // 1. The things appear around, one after another.
            // 2. They fly into the middle as the mark grows there.
            // 3. A lock closes on the mark. 4. The name and the line.
            final gather = Curves.easeInCubic.transform(_part(t, 0.36, 0.6));
            final mark = Curves.easeOutBack.transform(_part(t, 0.5, 0.68));
            final lock = Curves.elasticOut.transform(_part(t, 0.64, 0.86));
            final ring = _part(t, 0.66, 0.92);
            final name = Curves.easeOutCubic.transform(_part(t, 0.74, 0.88));
            final line = Curves.easeOutCubic.transform(_part(t, 0.8, 0.95));
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                  width: 320,
                  height: 320,
                  child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                    CustomPaint(size: const Size(320, 320), painter: _Rings(ring)),
                    for (final (i, (icon, label, color)) in _things.indexed)
                      Builder(builder: (_) {
                        final show = Curves.easeOutBack.transform(_part(t, i * 0.04, 0.14 + i * 0.04));
                        final a = -math.pi / 2 + i * 2 * math.pi / _things.length;
                        final r = 118 * (1 - gather);
                        final fade = (show * (1 - _part(t, 0.52, 0.6))).clamp(0.0, 1.0);
                        return Transform.translate(
                          offset: Offset(math.cos(a) * r, math.sin(a) * r),
                          child: Opacity(
                            opacity: fade,
                            child: Transform.scale(
                              scale: show * (1 - 0.55 * gather),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withValues(alpha: 0.45))),
                                  child: icon == null ? Text('৳', style: display(24, weight: 700, color: color, height: 1)) : Icon(icon, color: color, size: 25),
                                ),
                                const SizedBox(height: 4),
                                Opacity(opacity: 1 - gather, child: Text(tr(label), style: body(11.5, color: const Color(0xFFC7CEE0)))),
                              ]),
                            ),
                          ),
                        );
                      }),
                    Opacity(
                      opacity: _part(t, 0.5, 0.58),
                      child: Transform.scale(
                        scale: 0.4 + 0.6 * mark,
                        child: Stack(clipBehavior: Clip.none, children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.asset('assets/brand/app_mark.png', width: 100, height: 100, filterQuality: FilterQuality.medium),
                          ),
                          // The lock that closes on everything kept.
                          Positioned(
                            right: -12,
                            bottom: -12,
                            child: Transform.scale(
                              scale: lock,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(color: const Color(0xFFF3B93C), shape: BoxShape.circle, border: Border.all(color: C.night, width: 3)),
                                child: const Icon(Icons.lock_rounded, color: Color(0xFF2A1C04), size: 20),
                              ),
                            ),
                          ),
                        ]),
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
                    child: Text(tr('সব দরকারি জিনিস এক জায়গায়, তালাবদ্ধ'), textAlign: TextAlign.center, style: body(14.5, color: const Color(0xFFA9B5AF))),
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

/// Two rings in the mark's yellow as the lock closes.
class _Rings extends CustomPainter {
  _Rings(this.t);
  final double t;

  static const _yellow = Color(0xFFF3B93C);

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final c = size.center(Offset.zero);
    for (var i = 0; i < 2; i++) {
      final p = ((t * 1.3) - i * 0.3).clamp(0.0, 1.0);
      if (p <= 0 || p >= 1) continue;
      final r = 60 + 70 * Curves.easeOut.transform(p);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5 * (1 - p) + 1
          ..color = _yellow.withValues(alpha: (1 - p) * 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(_Rings old) => old.t != t;
}
