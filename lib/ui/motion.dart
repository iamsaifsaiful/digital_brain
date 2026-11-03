import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// The small movements that make the app feel finished (owner, 3 Nov, after
/// a video on "why premium apps feel smooth"). Each one stays still when the
/// phone's animations are turned off.

bool _still(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// A button sinks a little under the finger (95%) and springs back when
/// let go. Wraps any button; the tap itself is the child's.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true, this.depth = 0.95});
  final Widget child;
  final bool enabled;
  final double depth;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController.unbounded(vsync: this, value: 1);

  void _down() {
    if (!widget.enabled || _still(context)) return;
    _c.animateTo(widget.depth, duration: const Duration(milliseconds: 90), curve: Curves.easeOut);
  }

  void _up() {
    if (_c.value == 1) return;
    // A soft spring: a touch past full size, then settled.
    _c.animateWith(SpringSimulation(const SpringDescription(mass: 1, stiffness: 520, damping: 20), _c.value, 1, 0));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _down(),
        onPointerUp: (_) => _up(),
        onPointerCancel: (_) => _up(),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => Transform.scale(scale: _c.value, child: child),
          child: widget.child,
        ),
      );
}

/// A money figure that rolls from the old amount to the new one instead of
/// jumping (600 ms, fast then slow). Shown as it is the first time.
class RollingAmount extends StatefulWidget {
  const RollingAmount({super.key, required this.value, required this.format, required this.style});
  final int value;
  final String Function(int value) format;
  final TextStyle style;

  @override
  State<RollingAmount> createState() => _RollingAmountState();
}

class _RollingAmountState extends State<RollingAmount> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600), value: 1);
  late int _from = widget.value;

  @override
  void didUpdateWidget(RollingAmount old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    // From wherever the roll is now.
    _from = _now(old.value);
    if (_still(context)) {
      _c.value = 1;
    } else {
      _c.forward(from: 0);
    }
  }

  int _now(int to) => (_from + (to - _from) * Curves.easeOutCubic.transform(_c.value)).round();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Text(widget.format(_c.value >= 1 ? widget.value : _now(widget.value)), style: widget.style),
      );
}

/// A tick that is drawn rather than switched on: the circle fills, then the
/// tick is drawn into it (about 470 ms), with a light tap on the phone.
class DrawnTick extends StatefulWidget {
  const DrawnTick({super.key, required this.done, required this.size, required this.color, required this.tickColor, required this.borderColor});
  final bool done;
  final double size;
  final Color color;
  final Color tickColor;
  final Color borderColor;

  @override
  State<DrawnTick> createState() => _DrawnTickState();
}

class _DrawnTickState extends State<DrawnTick> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 470), value: widget.done ? 1 : 0);

  @override
  void didUpdateWidget(DrawnTick old) {
    super.didUpdateWidget(old);
    if (old.done == widget.done) return;
    if (widget.done) {
      HapticFeedback.lightImpact();
      if (_still(context)) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    } else {
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: Size.square(widget.size),
          painter: _TickPainter(_c.value, widget.color, widget.tickColor, widget.borderColor),
        ),
      );
}

class _TickPainter extends CustomPainter {
  _TickPainter(this.t, this.color, this.tickColor, this.borderColor);
  final double t;
  final Color color;
  final Color tickColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    // The ring, then the fill growing from the middle (first 40%).
    final fill = Curves.easeOut.transform((t / 0.4).clamp(0.0, 1.0));
    canvas.drawCircle(c, r - 1, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Color.lerp(borderColor, color, fill)!);
    if (fill > 0) canvas.drawCircle(c, (r - 1) * fill, Paint()..color = color);
    // The tick drawn after (the rest).
    final draw = Curves.easeInOut.transform(((t - 0.35) / 0.65).clamp(0.0, 1.0));
    if (draw <= 0) return;
    final w = size.width;
    final path = Path()
      ..moveTo(w * 0.28, w * 0.52)
      ..lineTo(w * 0.44, w * 0.67)
      ..lineTo(w * 0.73, w * 0.36);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, w * 0.1)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = tickColor;
    for (final m in path.computeMetrics()) {
      canvas.drawPath(m.extractPath(0, m.length * draw), paint);
    }
  }

  @override
  bool shouldRepaint(_TickPainter old) => old.t != t || old.color != color || old.tickColor != tickColor || old.borderColor != borderColor;
}
