import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The part of the day, from where the sun is.
enum SkyTime { dawn, day, golden, dusk, night }

SkyTime skyTimeFor(DateTime now, DateTime sunrise, DateTime sunset) {
  if (now.isBefore(sunrise.subtract(const Duration(minutes: 70)))) return SkyTime.night;
  if (now.isBefore(sunrise.add(const Duration(minutes: 60)))) return SkyTime.dawn;
  if (now.isBefore(sunset.subtract(const Duration(minutes: 150)))) return SkyTime.day;
  if (now.isBefore(sunset)) return SkyTime.golden;
  if (now.isBefore(sunset.add(const Duration(minutes: 70)))) return SkyTime.dusk;
  return SkyTime.night;
}

/// Top, middle and bottom of the sky, and the land under it.
({List<Color> sky, Color land}) skyColors(SkyTime t) => switch (t) {
      SkyTime.dawn => (sky: const [Color(0xFF3B3B98), Color(0xFFC0569B), Color(0xFFFDB27A)], land: const Color(0xFF2B2140)),
      SkyTime.day => (sky: const [Color(0xFF0A5EA8), Color(0xFF1F8FD1), Color(0xFF6CC3E8)], land: const Color(0xFF0F4D2E)),
      SkyTime.golden => (sky: const [Color(0xFF1F5FA8), Color(0xFFE48A3A), Color(0xFFFFD27A)], land: const Color(0xFF2E3A1A)),
      SkyTime.dusk => (sky: const [Color(0xFF1E1B4B), Color(0xFF8E2A6B), Color(0xFFF28A4B)], land: const Color(0xFF1A1630)),
      SkyTime.night => (sky: const [Color(0xFF050B1F), Color(0xFF13204A), Color(0xFF2B3A78)], land: const Color(0xFF070D18)),
    };

/// The sky behind the home greeting: the sun on its path from sunrise to
/// sunset (the part of the day already gone drawn bright), or the moon and
/// stars at night, over a horizon with palm trees. The sun rises to where
/// it is now once, when the page opens.
class HomeSky extends StatefulWidget {
  const HomeSky({super.key, required this.now, required this.sunrise, required this.sunset, required this.horizon, required this.child});
  final DateTime now;
  final DateTime sunrise;
  final DateTime sunset;

  /// Height of the land at the bottom.
  final double horizon;
  final Widget child;

  @override
  State<HomeSky> createState() => _HomeSkyState();
}

class _HomeSkyState extends State<HomeSky> with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rise.status == AnimationStatus.dismissed) {
      if (MediaQuery.of(context).disableAnimations) {
        _rise.value = 1;
      } else {
        _rise.forward();
      }
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = skyTimeFor(widget.now, widget.sunrise, widget.sunset);
    final night = time == SkyTime.night;
    double progress;
    if (night) {
      // The moon crosses from sunset to the next sunrise.
      final from = widget.now.isBefore(widget.sunrise) ? widget.sunset.subtract(const Duration(days: 1)) : widget.sunset;
      final to = widget.now.isBefore(widget.sunrise) ? widget.sunrise : widget.sunrise.add(const Duration(days: 1));
      progress = widget.now.difference(from).inMinutes / to.difference(from).inMinutes;
    } else {
      progress = widget.now.difference(widget.sunrise).inMinutes / widget.sunset.difference(widget.sunrise).inMinutes;
    }
    progress = progress.clamp(-0.06, 1.06);
    return AnimatedBuilder(
      animation: _rise,
      builder: (context, child) => CustomPaint(
        painter: _SkyPainter(time: time, progress: progress, rise: Curves.easeOutCubic.transform(_rise.value), horizon: widget.horizon),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.time, required this.progress, required this.rise, required this.horizon});
  final SkyTime time;
  final double progress;
  final double rise;
  final double horizon;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final colors = skyColors(time);
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors.sky, stops: const [0, 0.62, 1]).createShader(rect));

    final night = time == SkyTime.night;
    final ground = h - horizon;

    // Stars, the same every time.
    if (night || time == SkyTime.dusk || time == SkyTime.dawn) {
      final r = math.Random(7);
      final a = (night ? 1.0 : 0.45) * rise;
      final star = Paint();
      for (var i = 0; i < 46; i++) {
        final p = Offset(r.nextDouble() * w, r.nextDouble() * ground * 0.8);
        final s = 0.5 + r.nextDouble() * 1.2;
        star.color = Colors.white.withValues(alpha: (0.35 + r.nextDouble() * 0.6) * a);
        canvas.drawCircle(p, s, star);
      }
    }

    // The path across the sky.
    final cx = w / 2;
    final rx = w / 2 - 34;
    final ry = math.min(96.0, ground * 0.42);
    Offset at(double t) {
      final th = math.pi * (1 - t);
      return Offset(cx + rx * math.cos(th), ground - 6 - ry * math.sin(th));
    }

    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.38)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const steps = 64;
    for (var i = 0; i < steps; i += 2) {
      canvas.drawLine(at(i / steps), at((i + 1) / steps), dash);
    }
    final shown = (progress * rise).clamp(0.0, 1.0);
    if (shown > 0) {
      final done = Path()..moveTo(at(0).dx, at(0).dy);
      for (var i = 1; i <= 80; i++) {
        final p = at(shown * i / 80);
        done.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
          done,
          Paint()
            ..color = (night ? const Color(0xFFE2E8F0) : const Color(0xFFFFE8A3)).withValues(alpha: 0.9)
            ..strokeWidth = 2.6
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round);
    }

    final c = at(progress * rise);
    if (night) {
      canvas.drawCircle(c, 30, Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: 30)));
      final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: c, radius: 12)),
        Path()..addOval(Rect.fromCircle(center: c.translate(6, -4), radius: 11)),
      );
      canvas.drawPath(moon, Paint()..color = const Color(0xFFF8FAFC));
    } else {
      final core = time == SkyTime.golden || time == SkyTime.dusk ? const Color(0xFFFFB45C) : const Color(0xFFFFF4C2);
      canvas.drawCircle(c, 44, Paint()..shader = RadialGradient(colors: [core.withValues(alpha: 0.55), core.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: 44)));
      canvas.drawCircle(c, 15, Paint()..color = core);
      canvas.drawCircle(c, 15, Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c.translate(-4, -4), radius: 12)));
    }

    // Birds over the fields by day.
    if (time == SkyTime.day || time == SkyTime.dawn || time == SkyTime.golden) {
      final bird = Paint()
        ..color = colors.land.withValues(alpha: 0.55)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (final (x, y, s) in [(0.70, 0.30, 7.0), (0.76, 0.26, 5.0), (0.66, 0.36, 4.5)]) {
        final o = Offset(w * x, ground * y + 10 * (1 - rise));
        canvas.drawPath(
            Path()
              ..moveTo(o.dx - s, o.dy - s * 0.3)
              ..quadraticBezierTo(o.dx - s * 0.5, o.dy - s * 0.8, o.dx, o.dy)
              ..quadraticBezierTo(o.dx + s * 0.5, o.dy - s * 0.8, o.dx + s, o.dy - s * 0.3),
            bird);
      }
    }

    // The land: soft fields, a far tree line, palms.
    final far = Paint()..color = Color.lerp(colors.land, colors.sky.last, 0.45)!;
    canvas.drawPath(
        Path()
          ..moveTo(0, ground + 2)
          ..quadraticBezierTo(w * 0.2, ground - 10, w * 0.42, ground)
          ..quadraticBezierTo(w * 0.62, ground + 8, w * 0.8, ground - 6)
          ..quadraticBezierTo(w * 0.92, ground - 10, w, ground - 2)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close(),
        far);
    final land = Paint()..color = colors.land;
    canvas.drawPath(
        Path()
          ..moveTo(0, ground + 14)
          ..quadraticBezierTo(w * 0.3, ground + 2, w * 0.55, ground + 14)
          ..quadraticBezierTo(w * 0.8, ground + 24, w, ground + 10)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close(),
        land);
    for (final (x, tall, lean) in [(0.025, 60.0, 8.0), (0.085, 40.0, -5.0), (0.975, 66.0, -9.0)]) {
      _palm(canvas, Offset(w * x, ground + 16), tall, lean, colors.land);
    }
  }

  void _palm(Canvas canvas, Offset base, double tall, double lean, Color color) {
    final top = base.translate(lean, -tall);
    canvas.drawPath(
        Path()
          ..moveTo(base.dx, base.dy)
          ..quadraticBezierTo(base.dx + lean * 0.1, base.dy - tall * 0.6, top.dx, top.dy),
        Paint()
          ..color = color
          ..strokeWidth = 3.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
    final leaf = Paint()..color = color;
    for (final a in [-2.9, -2.3, -1.6, -0.9, -0.25, 0.35, -3.5]) {
      final len = tall * 0.42;
      final tip = top + Offset(math.cos(a) * len, math.sin(a) * len * 0.55 + len * 0.28);
      final mid = top + Offset(math.cos(a) * len * 0.5, math.sin(a) * len * 0.5 - 4);
      final n = Offset(-(tip.dy - top.dy), tip.dx - top.dx) / (tip - top).distance * 3.2;
      canvas.drawPath(
          Path()
            ..moveTo(top.dx, top.dy)
            ..quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, tip.dx, tip.dy)
            ..quadraticBezierTo(mid.dx - n.dx, mid.dy - n.dy, top.dx, top.dy)
            ..close(),
          leaf);
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.time != time || old.progress != progress || old.rise != rise || old.horizon != horizon;
}
