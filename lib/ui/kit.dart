// The new look's building blocks (24 Oct 2026, docs/design/2026-10-24-new-ui):
// a hand-written note, the landscape hero card, icon squares, status pills,
// the week strip, avatar stacks, progress rings, small bar charts and the
// floating button. Colours come from [C], so the dark look and the user's
// accent follow.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import 'theme.dart';
import 'widgets.dart' show initialOf;

/// Where a [HandNote]'s little arrow points.
enum HandArrow { none, right, downLeft, downRight }

/// A small hand-written note ("ছোট ছোট পদক্ষেপ, বড় ফল ↗"): decoration only,
/// slightly turned, with an optional hand-drawn arrow or underline.
class HandNote extends StatelessWidget {
  const HandNote(this.text, {super.key, this.arrow = HandArrow.none, this.rotate = -6, this.size = 14, this.color, this.underline = false, this.smile = false});
  final String text;
  final HandArrow arrow;

  /// Degrees.
  final double rotate;
  final double size;
  final Color? color;
  final bool underline;
  final bool smile;

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.muted2;
    Widget t = Text(text, style: hand(size, color: c), textAlign: TextAlign.left);
    if (smile) t = Row(mainAxisSize: MainAxisSize.min, children: [t, const SizedBox(width: 6), CustomPaint(size: Size(size, size), painter: _Smile(c))]);
    if (underline) {
      t = Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [t, CustomPaint(size: Size(size * 6, 6), painter: _Underline(c))]);
    }
    final arrowW = switch (arrow) {
      HandArrow.none => null,
      HandArrow.right => CustomPaint(size: const Size(34, 18), painter: _Arrow(c, HandArrow.right)),
      HandArrow.downLeft => CustomPaint(size: const Size(26, 26), painter: _Arrow(c, HandArrow.downLeft)),
      HandArrow.downRight => CustomPaint(size: const Size(26, 26), painter: _Arrow(c, HandArrow.downRight)),
    };
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: rotate * math.pi / 180,
        child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Flexible(child: t),
          if (arrowW != null) ...[const SizedBox(width: 4), arrowW],
        ]),
      ),
    );
  }
}

Paint _stroke(Color c) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.5
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

class _Arrow extends CustomPainter {
  _Arrow(this.c, this.dir);
  final Color c;
  final HandArrow dir;

  @override
  void paint(Canvas canvas, Size s) {
    final p = _stroke(c);
    final path = Path();
    if (dir == HandArrow.right) {
      path.moveTo(2, s.height - 2);
      path.quadraticBezierTo(s.width * 0.45, s.height * 0.35, s.width - 3, 3);
      canvas.drawPath(path, p);
      canvas.drawLine(Offset(s.width - 3, 3), Offset(s.width - 11, 4), p);
      canvas.drawLine(Offset(s.width - 3, 3), Offset(s.width - 5, 11), p);
    } else {
      final left = dir == HandArrow.downLeft;
      final x0 = left ? s.width - 2 : 2.0, x1 = left ? 3.0 : s.width - 3;
      path.moveTo(x0, 2);
      path.quadraticBezierTo(left ? s.width * 0.9 : s.width * 0.1, s.height * 0.8, x1, s.height - 3);
      canvas.drawPath(path, p);
      canvas.drawLine(Offset(x1, s.height - 3), Offset(x1 + (left ? 8 : -8), s.height - 3), p);
      canvas.drawLine(Offset(x1, s.height - 3), Offset(x1 + (left ? 2 : -2), s.height - 11), p);
    }
  }

  @override
  bool shouldRepaint(_Arrow o) => o.c != c || o.dir != dir;
}

class _Underline extends CustomPainter {
  _Underline(this.c);
  final Color c;

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(1, s.height - 2)
      ..quadraticBezierTo(s.width * 0.5, 0, s.width - 1, s.height - 3);
    canvas.drawPath(path, _stroke(c));
  }

  @override
  bool shouldRepaint(_Underline o) => o.c != c;
}

class _Smile extends CustomPainter {
  _Smile(this.c);
  final Color c;

  @override
  void paint(Canvas canvas, Size s) {
    final p = _stroke(c);
    canvas.drawCircle(Offset(s.width * 0.3, s.height * 0.35), 0.8, p);
    canvas.drawCircle(Offset(s.width * 0.7, s.height * 0.35), 0.8, p);
    canvas.drawArc(Rect.fromLTWH(s.width * 0.15, s.height * 0.2, s.width * 0.7, s.height * 0.6), 0.3, math.pi - 0.6, false, p);
  }

  @override
  bool shouldRepaint(_Smile o) => o.c != c;
}

/// The misty hills and pines behind a hero card, darkened from the left so
/// white letters read (drawn, not a photo).
class LandscapePainter extends CustomPainter {
  const LandscapePainter({this.dim = 0});

  /// 0..1: how much darker (the dark look dims it ~15%).
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final sx = w / 346, sy = h / 128;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF8E9690), Color(0xFFC9CCC4)]).createShader(rect));
    Path hill(List<double> pts) {
      final p = Path()..moveTo(0, pts[1] * sy);
      for (var i = 2; i + 5 < pts.length; i += 6) {
        p.cubicTo(pts[i] * sx, pts[i + 1] * sy, pts[i + 2] * sx, pts[i + 3] * sy, pts[i + 4] * sx, pts[i + 5] * sy);
      }
      return p
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    }

    final mist = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
    canvas.drawPath(hill([0, 70, 50, 48, 90, 60, 140, 44, 190, 30, 240, 52, 290, 38, 320, 30, 340, 36, 346, 34]), mist..color = const Color(0xFF7C857F));
    canvas.drawPath(hill([0, 86, 60, 68, 110, 80, 170, 64, 220, 52, 270, 72, 346, 58, 346, 58, 346, 58]), Paint()..color = const Color(0xFF5F6A64)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6));
    canvas.drawPath(hill([0, 100, 70, 88, 140, 98, 210, 86, 260, 78, 300, 92, 346, 84, 346, 84, 346, 84]), Paint()..color = const Color(0xFF3E4842));
    final pine = Paint()..color = const Color(0xFF262E2A);
    for (final t in const [
      [230, 244, 70, 258],
      [252, 262, 82, 272],
      [268, 284, 60, 300],
      [296, 306, 86, 316],
      [310, 324, 66, 338],
      [332, 340, 92, 348],
      [200, 208, 96, 216],
    ]) {
      canvas.drawPath(
          Path()
            ..moveTo(t[0] * sx, h)
            ..lineTo(t[1] * sx, t[2] * sy)
            ..lineTo(t[3] * sx, h)
            ..close(),
          pine);
    }
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(colors: [Color(0xE0141917), Color(0x73141917), Color(0x26141917)], stops: [0, 0.55, 1]).createShader(rect));
    if (dim > 0) canvas.drawRect(rect, Paint()..color = Colors.black.withValues(alpha: dim));
  }

  @override
  bool shouldRepaint(LandscapePainter o) => o.dim != dim;
}

/// The dark rounded card at the top of a page: a landscape behind (or the
/// plain accent), a label, a big value, a line, an action on the right and
/// an optional progress bar.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, this.label, required this.child, this.action, this.onTap, this.progress, this.landscape = true, this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 18), this.radius = 22});
  final String? label;
  final Widget child;
  final String? action;
  final VoidCallback? onTap;

  /// 0..1, or null for no bar.
  final double? progress;
  final bool landscape;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: padding,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              if (label != null) Text(label!, style: body(13.5, weight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.85))),
              child,
            ]),
          ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(top: 22, left: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(action!, style: body(14, weight: FontWeight.w600, color: Colors.white)),
                const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 22),
              ]),
            ),
        ]),
        if (progress != null) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(value: progress!.clamp(0, 1).toDouble(), minHeight: 5, color: Colors.white, backgroundColor: Colors.white.withValues(alpha: 0.28)),
          ),
        ],
      ]),
    );
    return Material(
      color: C.fill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: C.fillEdge)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: landscape
            ? CustomPaint(painter: LandscapePainter(dim: C.dark ? 0.15 : 0), child: content)
            : content,
      ),
    );
  }
}

/// A rounded square with an icon (in rows and tiles).
class IconSquare extends StatelessWidget {
  const IconSquare(this.icon, {super.key, this.size = 38, this.color, this.bg, this.radius = 12});
  final IconData icon;
  final double size;
  final Color? color;
  final Color? bg;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg ?? C.soft, borderRadius: BorderRadius.circular(radius)),
        child: Icon(icon, size: size * 0.52, color: color ?? C.muted2),
      );
}

/// "• চলছে", "১০ দিন": a small pill, with an optional dot.
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.dot, this.fg, this.bg, this.size = 11.5});
  final String text;
  final Color? dot;
  final Color? fg;
  final Color? bg;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg ?? C.surface, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot != null) ...[Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 5)],
          Text(text, style: body(size, weight: FontWeight.w500, color: fg ?? C.ink, height: 1.3)),
        ]),
      );
}

/// Seven days from Saturday: the chosen one in a dark rounded square, a dot
/// under days that have something, Friday's number red.
class WeekStrip extends StatelessWidget {
  const WeekStrip({super.key, required this.start, required this.selected, required this.onPick, this.hasItems, this.today});
  final DateTime start;
  final DateTime selected;
  final ValueChanged<DateTime> onPick;
  final bool Function(DateTime day)? hasItems;
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    const names = ['শনি', 'রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র'];
    return Row(children: [
      for (var i = 0; i < 7; i++)
        () {
          final day = DateTime(start.year, start.month, start.day + i);
          final sel = day.year == selected.year && day.month == selected.month && day.day == selected.day;
          final friday = day.weekday == DateTime.friday;
          final dot = hasItems?.call(day) ?? false;
          final fg = sel ? Colors.white : (friday ? C.nowLine : C.ink);
          return Expanded(
            child: GestureDetector(
              key: Key('week-day-$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onPick(day),
              child: Center(
                child: Container(
                  width: 46,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: sel
                      ? BoxDecoration(color: C.fill, borderRadius: BorderRadius.circular(14), boxShadow: C.dark ? const [] : const [BoxShadow(color: Color(0x401F2A27), blurRadius: 14, offset: Offset(0, 6))])
                      : null,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(names[(day.weekday % 7 + 1) % 7], style: body(12, color: sel ? Colors.white.withValues(alpha: 0.75) : C.muted, height: 1.2)),
                    const SizedBox(height: 4),
                    Text(bnDigits(day.day), style: display(17, weight: 700, color: fg, height: 1.1)),
                    const SizedBox(height: 5),
                    Container(width: 5, height: 5, decoration: BoxDecoration(color: dot ? (sel ? Colors.white : C.muted) : Colors.transparent, shape: BoxShape.circle)),
                  ]),
                ),
              ),
            ),
          );
        }(),
    ]);
  }
}

/// Overlapping round initials.
class AvatarStack extends StatelessWidget {
  const AvatarStack(this.names, {super.key, this.size = 28, this.max = 4});
  final List<String> names;
  final double size;
  final int max;

  static const _tones = [Color(0xFFB9785A), Color(0xFF4F6B60), Color(0xFF7A6FA8), Color(0xFFB98A3E), Color(0xFF5C7A99)];

  @override
  Widget build(BuildContext context) {
    final shown = names.take(max).toList();
    return SizedBox(
      height: size,
      width: shown.isEmpty ? 0 : size + (shown.length - 1) * (size - 7),
      child: Stack(children: [
        for (final (i, n) in shown.indexed)
          Positioned(
            left: i * (size - 7),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: _tones[n.hashCode.abs() % _tones.length], shape: BoxShape.circle, border: Border.all(color: C.ground, width: 2)),
              child: Text(initialOf(n), style: body(size * 0.4, weight: FontWeight.w600, color: Colors.white, height: 1)),
            ),
          ),
      ]),
    );
  }
}

/// A ring that fills with a share (green from 70%), an icon inside.
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, required this.icon, this.size = 54});
  final double value;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(value: value.clamp(0, 1).toDouble(), strokeWidth: 5, color: value >= 0.7 ? C.green : C.primary, backgroundColor: C.line, strokeCap: StrokeCap.round),
          ),
          Icon(icon, size: size * 0.38, color: C.muted2),
        ]),
      );
}

/// Small bars (the last one, the current, in the accent).
class MiniBars extends StatelessWidget {
  const MiniBars({super.key, required this.values, this.height = 56, this.highlight, this.light = false});
  final List<num> values;
  final double height;

  /// Which bar is the current one (default: the last).
  final int? highlight;

  /// On a dark card.
  final bool light;

  @override
  Widget build(BuildContext context) {
    final top = values.isEmpty ? 1 : values.reduce(math.max).toDouble();
    final hi = highlight ?? values.length - 1;
    return SizedBox(
      height: height,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final (i, v) in values.indexed)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                height: top <= 0 ? 2 : math.max(2, height * v / top),
                decoration: BoxDecoration(
                  color: light ? (i == hi ? const Color(0xFFA6E3C9) : Colors.white.withValues(alpha: 0.25)) : (i == hi ? C.fill : C.line),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
      ]),
    );
  }
}

/// One bar split into parts (spending by খাত).
class StackedBar extends StatelessWidget {
  const StackedBar({super.key, required this.parts, this.height = 10});
  final List<(double, Color)> parts;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = parts.fold<double>(0, (a, p) => a + p.$1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: SizedBox(
        height: height,
        child: Row(children: [
          for (final (i, (v, c)) in parts.indexed)
            if (v > 0)
              Expanded(
                flex: math.max(1, (v / (total == 0 ? 1 : total) * 1000).round()),
                child: Container(margin: EdgeInsets.only(right: i == parts.length - 1 ? 0 : 2), color: c),
              ),
        ]),
      ),
    );
  }
}

/// The colours of the split bar, darkest first (the new look's greys and greens).
List<Color> splitColors() => C.dark
    ? const [Color(0xFFDDE5E0), Color(0xFF6E8A7E), Color(0xFF8E9893), Color(0xFF3D4A44), Color(0xFF2A332F)]
    : const [Color(0xFF1F2A27), Color(0xFF4F6B60), Color(0xFF9FB3A8), Color(0xFFC8D2CC), Color(0xFFE4E8E5)];

/// A day number with a short month under it, in a soft square.
class DayBlock extends StatelessWidget {
  const DayBlock({super.key, required this.day, required this.month, this.color});
  final String day;
  final String month;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(day, style: display(16, weight: 700, color: color ?? C.ink, height: 1.05)),
          Text(month, maxLines: 1, overflow: TextOverflow.clip, style: body(9.5, weight: FontWeight.w600, color: color ?? C.muted, height: 1.1)),
        ]),
      );
}

/// The round floating button (58): the mic, "+", a camera…
class Fab extends StatelessWidget {
  const Fab({super.key, required this.icon, required this.tooltip, required this.onPressed, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: C.dark ? const [] : const [BoxShadow(color: Color(0x591F2A27), blurRadius: 18, offset: Offset(0, 8))]),
          child: Material(
            color: color ?? C.fab,
            shape: const CircleBorder(),
            child: InkWell(customBorder: const CircleBorder(), onTap: onPressed, child: SizedBox(width: 58, height: 58, child: Icon(icon, color: Colors.white, size: 28))),
          ),
        ),
      );
}
