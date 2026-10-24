import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../logic/compass.dart';
import '../logic/lang.dart';
import '../services/compass.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// কম্পাস: north, south, east, west from the phone's sensor, and the qibla
/// from the user's district.
class CompassScreen extends StatefulWidget {
  const CompassScreen({super.key});
  @override
  State<CompassScreen> createState() => _CompassScreenState();
}

class _CompassScreenState extends State<CompassScreen> {
  StreamSubscription<Heading?>? _sub;
  Heading? _h;
  bool _none = false;

  /// The dial's turn, unwrapped (so 359° → 1° turns 2°, not back 358°).
  double _turn = 0;
  bool _facing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sub = BrainScope.read(context).services.compass.headings().listen((h) {
        if (!mounted) return;
        if (h == null) {
          setState(() => _none = true);
          return;
        }
        final last = _h;
        setState(() {
          _turn += last == null ? h.degrees - _turn : turnTo(last.degrees, h.degrees);
          _h = h;
          _none = false;
        });
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final place = placeNamed(brain.district);
    final qibla = qiblaFrom(place.lat, place.lon);
    final h = _h;
    final off = h == null ? null : turnTo(h.degrees, qibla);
    final facing = off != null && off.abs() <= 4;
    if (facing && !_facing) HapticFeedback.mediumImpact();
    _facing = facing;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('কম্পাস')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              if (_none)
                EmptyState(
                  icon: Icons.explore_off_outlined,
                  title: tr('এই ফোনে কম্পাস সেন্সর নেই'),
                  text: trf('তবু কিবলার দিক: উত্তর থেকে ঘড়ির কাঁটার দিকে {0} ({1})।', [degreesText(qibla), directionName(qibla)]),
                )
              else ...[
                Center(
                  child: Text(h == null ? '—' : degreesText(h.degrees), key: const Key('compass-degrees'), style: display(44, weight: 700)),
                ),
                Center(child: Text(h == null ? tr('সেন্সর চালু হচ্ছে…') : directionName(h.degrees), style: body(18, color: C.muted, weight: FontWeight.w500))),
                const SizedBox(height: 14),
                LayoutBuilder(builder: (context, c) {
                  final size = math.min(c.maxWidth, 320.0);
                  return Center(
                    child: SizedBox(
                      width: size,
                      height: size + 18,
                      child: Stack(alignment: Alignment.topCenter, children: [
                        Positioned(
                          top: 18,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: -_turn),
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            builder: (_, t, child) => Transform.rotate(angle: t * math.pi / 180, child: child),
                            child: CustomPaint(
                              size: Size.square(size),
                              painter: _Dial(qibla: qibla, ink: C.ink, muted: C.muted, line: C.line, face: C.surface, red: C.red, green: C.green, lit: facing),
                            ),
                          ),
                        ),
                        // The phone's top: where it points.
                        Icon(Icons.arrow_drop_down_rounded, size: 40, color: facing ? C.green : C.ink),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                Panel(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(color: facing ? C.green : C.greenTint, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.mosque_outlined, color: facing ? C.onAccent : C.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(trf('কিবলা {0} · {1}', [degreesText(qibla), directionName(qibla)]), style: body(16, weight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          off == null
                              ? trf('{0} থেকে, উত্তর থেকে ঘড়ির কাঁটার দিকে', [place.label])
                              : facing
                                  ? tr('ফোনের মাথা এখন কিবলার দিকে')
                                  : off > 0
                                      ? trf('ডানে আরও {0} ঘুরুন', [degreesText(off.abs())])
                                      : trf('বাঁয়ে আরও {0} ঘুরুন', [degreesText(off.abs())]),
                          key: const Key('compass-qibla'),
                          style: body(13.5, color: facing ? C.green : C.muted),
                        ),
                      ]),
                    ),
                  ]),
                ),
                if (h != null && h.shaky) ...[
                  const SizedBox(height: 10),
                  Panel(
                    color: C.orangeTint,
                    padding: const EdgeInsets.all(12),
                    child: Text(tr('দিক ঠিকমতো ধরতে পারছে না — ফোনটা বাতাসে ইংরেজি ৮-এর মতো কয়েকবার ঘোরান, আর চুম্বক বা লোহার জিনিস থেকে দূরে রাখুন।'),
                        style: body(13.5, color: C.orange, height: 1.4)),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  tr('ফোন হাতের তালুতে সমান করে ধরুন। কিবলার দিক আপনার জেলার হিসেবে — সেটিংসে জেলা ঠিক থাকলে দিকও ঠিক থাকবে। মসজিদের দিক মিলিয়ে নেওয়া ভালো।'),
                  style: body(13, color: C.muted, height: 1.45),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Dial extends CustomPainter {
  _Dial({required this.qibla, required this.ink, required this.muted, required this.line, required this.face, required this.red, required this.green, required this.lit});
  final double qibla;
  final Color ink, muted, line, face, red, green;
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = face);
    canvas.drawCircle(c, r - 1, Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    Offset at(double deg, double radius) {
      final a = (deg - 90) * math.pi / 180;
      return c + Offset(math.cos(a), math.sin(a)) * radius;
    }

    for (var d = 0; d < 360; d += 5) {
      final long = d % 30 == 0;
      canvas.drawLine(at(d.toDouble(), r - 6), at(d.toDouble(), r - (long ? 20 : 12)), Paint()
        ..color = long ? ink : muted.withValues(alpha: 0.6)
        ..strokeWidth = long ? 2 : 1);
    }
    void text(String s, double deg, double radius, TextStyle style) {
      final tp = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr)..layout();
      canvas.save();
      final p = at(deg, radius);
      canvas.translate(p.dx, p.dy);
      canvas.rotate(deg * math.pi / 180);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }

    final big = r * 0.15;
    text(tr('উ'), 0, r - 40, TextStyle(fontFamily: 'Hind', fontSize: big, fontWeight: FontWeight.w700, color: red));
    text(tr('পূ'), 90, r - 40, TextStyle(fontFamily: 'Hind', fontSize: big, fontWeight: FontWeight.w700, color: ink));
    text(tr('দ'), 180, r - 40, TextStyle(fontFamily: 'Hind', fontSize: big, fontWeight: FontWeight.w700, color: ink));
    text(tr('প'), 270, r - 40, TextStyle(fontFamily: 'Hind', fontSize: big, fontWeight: FontWeight.w700, color: ink));
    for (var d = 30; d < 360; d += 30) {
      if (d % 90 == 0) continue;
      text(bnDigits(d), d.toDouble(), r - 34, TextStyle(fontFamily: 'Hind', fontSize: r * 0.075, color: muted));
    }

    // The needle: red to the north.
    final n = Path()
      ..moveTo(at(0, r * 0.52).dx, at(0, r * 0.52).dy)
      ..lineTo(c.dx - r * 0.06, c.dy)
      ..lineTo(c.dx + r * 0.06, c.dy)
      ..close();
    canvas.drawPath(n, Paint()..color = red);
    final s = Path()
      ..moveTo(at(180, r * 0.52).dx, at(180, r * 0.52).dy)
      ..lineTo(c.dx - r * 0.06, c.dy)
      ..lineTo(c.dx + r * 0.06, c.dy)
      ..close();
    canvas.drawPath(s, Paint()..color = muted.withValues(alpha: 0.55));
    canvas.drawCircle(c, r * 0.05, Paint()..color = ink);

    // The qibla: a green line out to a dot at the rim.
    canvas.drawLine(c, at(qibla, r * 0.52), Paint()
      ..color = green.withValues(alpha: lit ? 1 : 0.7)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round);
    canvas.drawCircle(at(qibla, r * 0.58), r * 0.07, Paint()..color = green);
    final icon = Icons.mosque;
    final tp = TextPainter(
      text: TextSpan(text: String.fromCharCode(icon.codePoint), style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: r * 0.08, color: Colors.white)),
      textDirection: TextDirection.ltr,
    )..layout();
    final q = at(qibla, r * 0.58);
    tp.paint(canvas, q - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_Dial old) => old.qibla != qibla || old.lit != lit || old.ink != ink;
}
