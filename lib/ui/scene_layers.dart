import 'dart:math' as math;
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';

import '../logic/home_scene.dart';

/// Moving parts of the home picture (owner, 4 Nov). Release builds only,
/// so tests and screenshots see one still frame (a test can turn it on).
bool sceneLive = const bool.fromEnvironment('dart.vm.product');

/// The paintings are 1170 × 1056, shown "cover" with this alignment.
const sceneSize = Size(1170, 1056);
const sceneAlign = Alignment(0, 0.55);

/// Where a point of the painting lands in a box of [box] size.
class SceneMap {
  SceneMap(Size box) {
    scale = math.max(box.width / sceneSize.width, box.height / sceneSize.height);
    final w = sceneSize.width * scale, h = sceneSize.height * scale;
    dx = (box.width - w) * (sceneAlign.x + 1) / 2;
    dy = (box.height - h) * (sceneAlign.y + 1) / 2;
  }
  late final double scale, dx, dy;
  Offset at(double x, double y) => Offset(dx + x * scale, dy + y * scale);
  double len(double v) => v * scale;
}

/// Everything that lives on the painting: the boat, the moon, the weather,
/// birds, fireflies, glitter, smoke and the special days.
class SceneLayers extends StatefulWidget {
  const SceneLayers({
    super.key,
    required this.scene,
    required this.night,
    required this.phase,
    required this.moon,
    required this.weather,
    required this.special,
    required this.motion,
  });

  final String scene;

  /// 0 day … 1 night (from the light of the hour).
  final double night;
  final String phase;
  final ({double lit, bool waxing}) moon;

  /// 'storm', 'rain', 'fog', 'cloud' or '' (empty when the member turned it off).
  final String weather;

  /// See [specialDayOf]; null when none or turned off.
  final String? special;
  final bool motion;

  @override
  State<SceneLayers> createState() => _SceneLayersState();
}

class _SceneLayersState extends State<SceneLayers> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(minutes: 10));

  bool get _moving => sceneLive && (widget.motion || widget.weather == 'rain' || widget.weather == 'storm') && !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(SceneLayers old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_moving && !_c.isAnimating) {
      _c.repeat();
    } else if (!_moving && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final map = SceneMap(box.biggest);
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 600; // seconds
          final drift = widget.motion ? (1 - math.cos(2 * math.pi * t / 120)) / 2 : 0.5;
          final bx = 460 + 320 * drift;
          final boatTop = widget.scene == 'cox' ? 800.0 : 765.0;
          return Stack(fit: StackFit.expand, children: [
            // The boat sails slowly up and down the river (a two-minute round).
            _boat(map, 'assets/sky/boat_day.png', bx, boatTop, 1 - widget.night),
            if (widget.night > 0.02) _boat(map, 'assets/sky/boat_night.png', bx, boatTop, widget.night),
            CustomPaint(painter: _ScenePainter(map, t, widget)),
          ]);
        },
      );
    });
  }

  Widget _boat(SceneMap map, String asset, double x, double top, double opacity) {
    final p = map.at(x, top);
    return Positioned(
      left: p.dx,
      top: p.dy,
      width: map.len(190),
      height: map.len(120),
      child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: Image.asset(asset, fit: BoxFit.fill, gaplessPlayback: true, excludeFromSemantics: true)),
    );
  }
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.m, this.t, this.w);
  final SceneMap m;
  final double t;
  final SceneLayers w;

  double _r(int i, int k) => ((math.sin(i * 127.1 + k * 311.7) * 43758.5453) % 1 + 1) % 1;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    if (w.night > 0.05) _moon(canvas);
    if (w.motion) {
      _glitter(canvas);
      if (const ['golden', 'sunset', 'evening'].contains(w.phase)) {
        _birds(canvas);
        _smoke(canvas);
      }
      if (w.night > 0.7 && !const ['sheet', 'hemonto', 'cox', 'dhaka'].contains(w.scene)) _fireflies(canvas);
    }
    switch (w.special) {
      case 'boishakh':
        _kites(canvas);
      case 'ekushey':
        _minar(canvas);
      case 'independence' || 'victory':
        _flag(canvas);
      case 'eid':
        _bunting(canvas);
    }
    switch (w.weather) {
      case 'rain':
        _rain(canvas, size, 90, 0.10);
      case 'storm':
        _rain(canvas, size, 170, 0.18);
        _lightning(canvas, size);
      case 'fog':
        _fog(canvas, size);
      case 'cloud':
        canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF55606E).withValues(alpha: 0.12 * (1 - w.night * 0.6)));
    }
    canvas.restore();
  }

  void _moon(Canvas c) {
    final o = m.at(915, 452);
    final r = m.len(27);
    final a = w.night.clamp(0.0, 1.0);
    c.drawCircle(o, r * 4, Paint()..shader = RadialGradient(colors: [const Color(0xFFDCE2FF).withValues(alpha: 0.22 * a * (0.3 + w.moon.lit)), Colors.transparent]).createShader(Rect.fromCircle(center: o, radius: r * 4)));
    // The dark part of the moon, faint.
    c.drawCircle(o, r, Paint()..color = const Color(0xFF2A3050).withValues(alpha: 0.35 * a));
    final lit = w.moon.lit;
    if (lit < 0.02) return;
    final path = Path();
    final rect = Rect.fromCircle(center: o, radius: r);
    // Half the disc on the lit side, then the terminator as half an ellipse.
    final right = w.moon.waxing;
    path.addArc(rect, right ? -math.pi / 2 : math.pi / 2, math.pi);
    final ex = r * (1 - 2 * lit).abs();
    final ell = Path()..addOval(Rect.fromCenter(center: o, width: ex * 2, height: r * 2));
    Path shape;
    if (lit > 0.5) {
      shape = Path.combine(PathOperation.union, path, ell);
    } else {
      shape = Path.combine(PathOperation.difference, path, ell);
    }
    c.drawPath(shape, Paint()..color = const Color(0xFFF4EFD2).withValues(alpha: a));
  }

  void _glitter(Canvas c) {
    final night = w.night > 0.5;
    for (var i = 0; i < 34; i++) {
      final x = night ? 820 + _r(i, 1) * 190 : _r(i, 1) * 1170;
      final y = 818 + _r(i, 2) * 64;
      final tw = math.pow(math.max(0, math.sin(t * (1.2 + _r(i, 3) * 1.6) + i * 2.1)), 10).toDouble();
      if (tw < 0.05) continue;
      final p = m.at(x, y);
      final paint = Paint()..color = Colors.white.withValues(alpha: tw * (night ? 0.55 : 0.75));
      c.drawLine(p.translate(-m.len(4), 0), p.translate(m.len(4), 0), paint..strokeWidth = math.max(1, m.len(1.6)));
    }
  }

  void _birds(Canvas c) {
    final cycle = (t % 45) / 45;
    final cx = 1300 - cycle * 1500, cy = 330 + math.sin(cycle * 6) * 20;
    final paint = Paint()
      ..color = const Color(0xFF1E1E28).withValues(alpha: 0.75)
      ..strokeWidth = math.max(1.2, m.len(2.2))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final row = (i + 1) ~/ 2, side = i.isOdd ? -1 : 1;
      final x = cx + row * 26, y = cy + side * row * 16;
      final flap = math.sin(t * 7 + i) * 6;
      final p = m.at(x, y);
      final s = m.scale;
      c.drawPath(
          Path()
            ..moveTo(p.dx - 10 * s, p.dy - (4 + flap) * s)
            ..quadraticBezierTo(p.dx - 4 * s, p.dy - 2 * s, p.dx, p.dy)
            ..quadraticBezierTo(p.dx + 4 * s, p.dy - 2 * s, p.dx + 10 * s, p.dy - (4 + flap) * s),
          paint);
    }
  }

  void _smoke(Canvas c) {
    for (final sx in const [190.0, 430.0]) {
      for (var k = 0; k < 6; k++) {
        final life = ((t / 9 + k / 6 + sx) % 1);
        final p = m.at(sx + life * 30, 785 - life * 140);
        c.drawCircle(p, m.len(8 + life * 26), Paint()..color = const Color(0xFFBFC3CC).withValues(alpha: 0.22 * (1 - life)));
      }
    }
  }

  void _fireflies(Canvas c) {
    for (var i = 0; i < 24; i++) {
      final x = _r(i, 4) * 1170 + math.sin(t * 0.3 + i) * 20;
      final y = 905 + _r(i, 5) * 140 + math.cos(t * 0.4 + i * 1.7) * 10;
      final on = math.max(0.0, math.sin(t * (0.8 + _r(i, 6)) + i * 3));
      if (on < 0.1) continue;
      final p = m.at(x, y);
      c.drawCircle(p, m.len(7), Paint()..color = const Color(0xFFE8F27A).withValues(alpha: 0.18 * on));
      c.drawCircle(p, math.max(1, m.len(2)), Paint()..color = const Color(0xFFF4FF9A).withValues(alpha: 0.9 * on));
    }
  }

  void _kites(Canvas c) {
    const kites = [(250.0, 230.0, Color(0xFFD62828)), (560.0, 150.0, Color(0xFFF2B705)), (780.0, 290.0, Color(0xFF0B7A3E))];
    for (var i = 0; i < kites.length; i++) {
      final (x, y, col) = kites[i];
      final sway = math.sin(t * 0.9 + i * 2) * 10;
      final p = m.at(x + sway, y + math.cos(t * 0.7 + i) * 6);
      final s = m.scale * 1.6;
      final body = Path()
        ..moveTo(p.dx, p.dy - 22 * s)
        ..lineTo(p.dx + 15 * s, p.dy)
        ..lineTo(p.dx, p.dy + 26 * s)
        ..lineTo(p.dx - 15 * s, p.dy)
        ..close();
      c.drawPath(body, Paint()..color = col);
      c.drawLine(p.translate(0, -22 * s), p.translate(0, 26 * s), Paint()..color = Colors.white.withValues(alpha: 0.6)..strokeWidth = s);
      final tail = Path()..moveTo(p.dx, p.dy + 26 * s);
      for (var k = 1; k <= 6; k++) {
        tail.lineTo(p.dx + math.sin(t * 3 + k + i) * 6 * s, p.dy + (26 + k * 9) * s);
      }
      c.drawPath(tail, Paint()..color = col.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 1.5 * s);
      // the string down to the bank
      c.drawLine(p.translate(0, 4 * s), m.at(140, 900), Paint()..color = Colors.white.withValues(alpha: 0.35)..strokeWidth = 0.8);
    }
  }

  void _minar(Canvas c) {
    // Shaheed Minar on the far bank at dawn: the bowed centre frame, two pairs either side, a red sun behind.
    final base = m.at(800, 805); // between the boat and the palms, clear of the season's tree
    final s = m.scale;
    c.drawCircle(base.translate(0, -120 * s), 46 * s, Paint()..color = const Color(0xFFC8102E).withValues(alpha: 0.9));
    final ink = Paint()
      ..color = (w.night > 0.5 ? const Color(0xFF0C0E18) : const Color(0xFF2A2A30))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s
      ..strokeCap = StrokeCap.square;
    // centre: four uprights, top bent forward
    for (final dx in const [-30.0, -10.0, 10.0, 30.0]) {
      c.drawLine(base.translate(dx * s, 0), base.translate(dx * s, -150 * s), ink);
    }
    c.drawLine(base.translate(-30 * s, -150 * s), base.translate(30 * s, -150 * s), ink);
    c.drawLine(base.translate(-30 * s, -150 * s), base.translate(-24 * s, -176 * s), ink);
    c.drawLine(base.translate(30 * s, -150 * s), base.translate(24 * s, -176 * s), ink);
    c.drawLine(base.translate(-24 * s, -176 * s), base.translate(24 * s, -176 * s), ink);
    for (final side in const [-1.0, 1.0]) {
      for (final (off, h) in const [(62.0, 112.0), (92.0, 84.0)]) {
        final x = side * off;
        c.drawLine(base.translate((x - 9) * s, 0), base.translate((x - 9) * s, -h * s), ink);
        c.drawLine(base.translate((x + 9) * s, 0), base.translate((x + 9) * s, -h * s), ink);
        c.drawLine(base.translate((x - 9) * s, -h * s), base.translate((x + 9) * s, -h * s), ink);
      }
    }
    c.drawRect(Rect.fromLTRB(base.dx - 110 * s, base.dy - 4 * s, base.dx + 110 * s, base.dy + 6 * s), Paint()..color = ink.color);
  }

  void _flag(Canvas c) {
    final foot = m.at(140, 905);
    final s = m.scale * 1.3;
    final top = foot.translate(0, -150 * s);
    c.drawLine(foot, top, Paint()..color = const Color(0xFF3A3A3A)..strokeWidth = 3 * s);
    const fw = 70.0, fh = 42.0;
    final cloth = Path()..moveTo(top.dx, top.dy);
    for (var k = 0; k <= 10; k++) {
      final x = fw * k / 10;
      cloth.lineTo(top.dx + x * s, top.dy + math.sin(t * 3 + k * 0.6) * 3 * s * k / 10);
    }
    for (var k = 10; k >= 0; k--) {
      final x = fw * k / 10;
      cloth.lineTo(top.dx + x * s, top.dy + (fh + math.sin(t * 3 + k * 0.6) * 3 * k / 10) * s);
    }
    cloth.close();
    c.drawPath(cloth, Paint()..color = const Color(0xFF006A4E));
    c.drawCircle(top.translate(fw * 0.45 * s, (fh / 2 + math.sin(t * 3 + 2.7) * 1.4) * s), fh * 0.3 * s, Paint()..color = const Color(0xFFF42A41));
  }

  void _bunting(Canvas c) {
    // Eid: a string of little flags across the top; warm lights on the far bank at night.
    const colors = [Color(0xFFE63946), Color(0xFFF4A261), Color(0xFF2A9D8F), Color(0xFFE9C46A), Color(0xFF8E44AD)];
    final line = Paint()..color = Colors.white.withValues(alpha: 0.7)..strokeWidth = 1;
    Offset on(double f) => m.at(f * 1170, 70 + math.sin(f * math.pi) * 70);
    final pts = [for (var k = 0; k <= 40; k++) on(k / 40)];
    c.drawPoints(PointMode.polygon, pts, line);
    for (var k = 0; k < 24; k++) {
      final a = on(k / 24 + 0.01), b = on((k + 0.7) / 24 + 0.01);
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 + m.len(26 + math.sin(t * 2 + k) * 2));
      c.drawPath(Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..lineTo(mid.dx, mid.dy)..close(), Paint()..color = colors[k % colors.length].withValues(alpha: 0.95));
    }
    if (w.night > 0.4) {
      for (var i = 0; i < 40; i++) {
        final p = m.at(30 + i * 28.0, 786 + math.sin(i * 1.3) * 5);
        final on2 = 0.55 + 0.45 * math.sin(t * 2 + i);
        c.drawCircle(p, m.len(6), Paint()..color = const Color(0xFFFFD27A).withValues(alpha: 0.25 * on2 * w.night));
        c.drawCircle(p, math.max(1, m.len(2)), Paint()..color = const Color(0xFFFFE6A8).withValues(alpha: on2 * w.night));
      }
    }
  }

  void _rain(Canvas c, Size size, int n, double dim) {
    c.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF3A4452).withValues(alpha: dim));
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.32)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < n; i++) {
      final speed = 520 + _r(i, 7) * 300;
      final x = _r(i, 8) * (size.width + 60) - 30;
      final y = ((_r(i, 9) * size.height + t * speed) % (size.height + 40)) - 20;
      final len = 12 + _r(i, 10) * 10;
      c.drawLine(Offset(x, y), Offset(x - len * 0.25, y + len), paint);
    }
  }

  void _lightning(Canvas c, Size size) {
    final cycle = (t / 8).floor();
    final f = (t / 8) % 1;
    if (f > 0.035) return;
    c.drawRect(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: 0.35 * (1 - f / 0.035)));
    final x = 200 + _r(cycle, 11) * 770;
    final path = Path()..moveTo(m.at(x, 120).dx, m.at(x, 120).dy);
    var px = x, py = 120.0;
    for (var k = 0; k < 7; k++) {
      px += (_r(cycle * 7 + k, 12) - 0.5) * 70;
      py += 85;
      final p = m.at(px, py);
      path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path, Paint()..color = Colors.white.withValues(alpha: 0.9)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  void _fog(Canvas c, Size size) {
    for (var i = 0; i < 3; i++) {
      final y = m.at(0, 740 + i * 70).dy;
      final shift = math.sin(t * 0.05 + i) * 40;
      c.drawRect(
        Rect.fromLTWH(-60 + shift, y - m.len(60), size.width + 120, m.len(120)),
        Paint()
          ..color = (w.night > 0.5 ? const Color(0xFF6A7290) : const Color(0xFFF2F3F5)).withValues(alpha: 0.30)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, m.len(40)),
      );
    }
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.t != t || old.w != w || old.m.scale != m.scale;
}
