import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/format.dart';
import '../state/hisab.dart';

/// Colours from the design (blue style).
class K {
  static const ground = Color(0xFFF4F4F4);
  static const card = Colors.white;
  static const ink = Color(0xFF1A1A1A);
  static const muted = Color(0xFF6B6B6B);
  static const line = Color(0xFFEEEEEE);
  static const border = Color(0xFFE0E0E0);
  static const chip = Color(0xFFE9E9EB);
  static const blue = Color(0xFF2F6BEA);
  static const blueTint = Color(0xFFE6EEFD);
  static const navy = Color(0xFF14284B);
  static const navySoft = Color(0xFFDCE7FB);
  static const red = Color(0xFFC5221F);
  static const redTint = Color(0xFFFDECEA);
  static const green = Color(0xFF16833A);
  static const greenTint = Color(0xFFE3F4E7);
  static const amber = Color(0xFFF0A020);
  static const amberTint = Color(0xFFFFF1DC);
  static const amberText = Color(0xFF9A5A00);
}

ThemeData appTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: K.blue, primary: K.blue, surface: K.card),
    scaffoldBackgroundColor: K.ground,
    fontFamily: 'NotoBengali',
    fontFamilyFallback: const ['Roboto', 'sans-serif'],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: K.ink, displayColor: K.ink),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: K.navy),
    dialogTheme: const DialogThemeData(backgroundColor: K.card, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: const BottomSheetThemeData(backgroundColor: K.ground, surfaceTintColor: Colors.transparent),
  );
}

const ts = TextStyle(fontFamily: 'NotoBengali', fontFamilyFallback: ['Roboto', 'sans-serif'], color: K.ink);

TextStyle t(double size, {FontWeight w = FontWeight.w400, Color c = K.ink, double? h}) => ts.copyWith(fontSize: size, fontWeight: w, color: c, height: h);

void snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text, style: t(14, c: Colors.white))));
}

/// Round white button with an icon (back, search, edit …).
class CircleBtn extends StatelessWidget {
  const CircleBtn({super.key, required this.icon, required this.onTap, required this.label, this.dot = false});
  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final bool dot;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: Tooltip(
          message: label,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: K.card, shape: BoxShape.circle, border: Border.all(color: const Color(0xFFE6E6E6))),
              child: Stack(alignment: Alignment.center, children: [
                Icon(icon, size: 21, color: K.ink),
                if (dot) const Positioned(top: 11, right: 12, child: CircleAvatar(radius: 4, backgroundColor: Color(0xFFD93025))),
              ]),
            ),
          ),
        ),
      );
}

/// A page with the round back button, a centred title and an optional
/// button on the right.
class Screen extends StatelessWidget {
  const Screen({super.key, required this.title, required this.body, this.trailing, this.bottom, this.back = true, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? trailing;
  final Widget? bottom;
  final bool back;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: K.ground,
        body: SafeArea(
          bottom: bottom == null,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Row(children: [
                if (back) CircleBtn(icon: Icons.chevron_left_rounded, label: 'পেছনে', onTap: () => Navigator.of(context).maybePop()) else const SizedBox(width: 48),
                Expanded(
                  child: Column(children: [
                    Text(title, textAlign: TextAlign.center, style: t(18, w: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (subtitle != null) Text(subtitle!, style: t(12.5, c: K.muted)),
                  ]),
                ),
                trailing ?? const SizedBox(width: 48),
              ]),
            ),
            Expanded(child: body),
          ]),
        ),
        bottomNavigationBar: bottom == null
            ? null
            : Container(
                decoration: const BoxDecoration(color: K.card, border: Border(top: BorderSide(color: K.line))),
                padding: EdgeInsets.fromLTRB(18, 12, 18, 12 + MediaQuery.of(context).padding.bottom),
                child: bottom,
              ),
      );
}

class CardBox extends StatelessWidget {
  const CardBox({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.color = K.card, this.onTap, this.radius = 16, this.border});
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;
  final double radius;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: border == null ? BorderSide.none : BorderSide(color: border!, width: 1.5));
    return Material(
      color: color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? Padding(padding: padding, child: child) : InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

/// The big pill buttons: blue for the main job, navy for the second.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.onTap, this.color = K.blue, this.icon, this.height = 54, this.textColor = Colors.white});
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final IconData? icon;
  final double height;
  final Color textColor;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: color,
            foregroundColor: textColor,
            disabledBackgroundColor: const Color(0xFFBFC6D4),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(label, style: t(15.5, w: FontWeight.w500, c: onTap == null ? Colors.white : textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (icon != null) ...[const SizedBox(width: 8), Icon(icon, size: 18)],
          ]),
        ),
      );
}

/// Outlined light pill.
class SoftPill extends StatelessWidget {
  const SoftPill({super.key, required this.label, required this.onTap, this.icon, this.color = K.ink});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 46,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            backgroundColor: K.card,
            foregroundColor: color,
            side: const BorderSide(color: K.border),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 6)],
            Flexible(child: Text(label, style: t(14, c: color), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );
}

/// Grey pill holding choices; the chosen one is navy.
class Seg<T> extends StatelessWidget {
  const Seg({super.key, required this.items, required this.value, required this.onChanged});
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: K.chip, borderRadius: BorderRadius.circular(28)),
        child: Row(children: [
          for (final (v, label) in items)
            Expanded(
              child: Semantics(
                selected: v == value,
                button: true,
                child: GestureDetector(
                  onTap: () => onChanged(v),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: v == value ? K.navy : Colors.transparent, borderRadius: BorderRadius.circular(22)),
                    child: Text(label,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: t(13.5, w: v == value ? FontWeight.w600 : FontWeight.w400, c: v == value ? Colors.white : const Color(0xFF4A4A4A))),
                  ),
                ),
              ),
            ),
        ]),
      );
}

/// A small choice chip (white, navy when chosen).
class ChoiceChipX extends StatelessWidget {
  const ChoiceChipX({super.key, required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: on,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: IntrinsicWidth(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? K.navy : K.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: on ? K.navy : K.border),
              ),
              child: Text(label, style: t(13.5, w: on ? FontWeight.w600 : FontWeight.w400, c: on ? Colors.white : K.ink)),
            ),
          ),
        ),
      );
}

/// Progress ring with the percentage in the middle.
class Ring extends StatelessWidget {
  const Ring({super.key, required this.percent, this.size = 52, this.color});
  final double percent;
  final double size;
  final Color? color;

  Color get _c =>
      color ??
      (percent > 100
          ? const Color(0xFFD93025)
          : percent >= 70
              ? K.amber
              : percent <= 0
                  ? const Color(0xFF1E9E3A)
                  : K.blue);

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'সীমার ${bnNum(percent.round())} শতাংশ',
        child: SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _RingPainter(percent.clamp(0, 100) / 100, _c),
            child: Center(child: Text('${bnNum(percent.round())}%', style: t(size * 0.24, w: FontWeight.w700, c: percent <= 0 ? K.green : K.ink))),
          ),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.f, this.c);
  final double f;
  final Color c;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = const Color(0xFFE8E8E8);
    canvas.drawArc(r, 0, 2 * math.pi, false, bg);
    if (f > 0) {
      canvas.drawArc(
          r,
          -math.pi / 2,
          2 * math.pi * f,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..color = c);
    }
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.f != f || o.c != c;
}

/// Smooth blue line chart with a soft fill and the last (or largest) point
/// marked.
class LineChart extends StatelessWidget {
  const LineChart({super.key, required this.values, required this.labels, required this.caption, this.markLabel, this.height = 130});
  final List<double> values;
  final List<String> labels;
  final String caption;
  final String? markLabel;
  final double height;

  @override
  Widget build(BuildContext context) => Semantics(
        label: caption,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: height,
            child: CustomPaint(painter: _LinePainter(values, markLabel)),
          ),
          const SizedBox(height: 6),
          Row(children: [
            for (final l in labels) Expanded(child: Text(l, textAlign: TextAlign.center, style: t(12, c: K.muted), maxLines: 1, overflow: TextOverflow.clip)),
          ]),
        ]),
      );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.v, this.mark);
  final List<double> v;
  final String? mark;

  @override
  void paint(Canvas canvas, Size size) {
    if (v.isEmpty) return;
    final maxV = v.reduce(math.max);
    final minV = v.reduce(math.min);
    final span = (maxV - minV).abs() < 1e-9 ? (maxV == 0 ? 1.0 : maxV.abs()) : maxV - minV;
    final step = v.length == 1 ? 0.0 : size.width / v.length;
    final pts = <Offset>[
      for (var i = 0; i < v.length; i++) Offset(step / 2 + i * step, 30 + (size.height - 40) * (1 - (v[i] - (maxV == minV ? 0 : minV)) / span)),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[math.max(0, i - 1)], p1 = pts[i], p2 = pts[i + 1], p3 = pts[math.min(pts.length - 1, i + 2)];
      path.cubicTo(p1.dx + (p2.dx - p0.dx) / 6, p1.dy + (p2.dy - p0.dy) / 6, p2.dx - (p3.dx - p1.dx) / 6, p2.dy - (p3.dy - p1.dy) / 6, p2.dx, p2.dy);
    }
    final area = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [K.blue.withValues(alpha: 0.26), K.blue.withValues(alpha: 0)]).createShader(Offset.zero & size));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = K.blue);
    var mi = v.length - 1;
    for (var i = 0; i < v.length; i++) {
      if (v[i] > v[mi]) mi = i;
    }
    final m = pts[mi];
    final dash = Paint()
      ..color = K.blue
      ..strokeWidth = 1;
    for (var y = m.dy; y < size.height; y += 6) {
      canvas.drawLine(Offset(m.dx, y), Offset(m.dx, math.min(y + 3, size.height)), dash);
    }
    canvas.drawCircle(m, 6, Paint()..color = Colors.white);
    canvas.drawCircle(m, 4.5, Paint()..color = K.blue);
    final label = mark;
    if (label != null && label.isNotEmpty) {
      final tp = TextPainter(text: TextSpan(text: label, style: t(12, w: FontWeight.w600)), textDirection: TextDirection.ltr)..layout();
      final w = tp.width + 18;
      var x = m.dx - w / 2;
      x = x.clamp(0, size.width - w);
      final r = RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, w, 24), const Radius.circular(12));
      canvas.drawRRect(r.shift(const Offset(0, 1)), Paint()..color = const Color(0x22000000));
      canvas.drawRRect(r, Paint()..color = Colors.white);
      tp.paint(canvas, Offset(x + 9, 12 - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_LinePainter o) => o.v != v || o.mark != mark;
}

/// Customer's photo, or the first letter on a soft colour.
class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.h, required this.name, this.photo, this.size = 46});
  final Hisab h;
  final String name;
  final String? photo;
  final double size;

  static const _bgs = [Color(0xFFF6E3C8), Color(0xFFDCE7FB), Color(0xFFE3F4E7), Color(0xFFFDE7EF), Color(0xFFFFEBDD), Color(0xFFEDE7FB)];
  static const _fgs = [Color(0xFF8A4B08), K.navy, K.green, Color(0xFFB0175A), Color(0xFFB5470B), Color(0xFF5B36B0)];

  @override
  Widget build(BuildContext context) {
    final i = name.isEmpty ? 0 : name.codeUnitAt(0) % _bgs.length;
    final letter = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _bgs[i], shape: BoxShape.circle),
      child: Text(name.isEmpty ? '?' : name.characters.first, style: t(size * 0.38, w: FontWeight.w700, c: _fgs[i])),
    );
    final id = photo;
    if (id == null) return letter;
    return FutureBuilder<Uint8List?>(
      future: h.photo(id),
      builder: (context, snap) {
        final b = snap.data;
        if (b == null) return letter;
        return ClipOval(child: Image.memory(b, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true));
      },
    );
  }
}

/// "Title ........ action" above a list.
class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 4),
        child: Row(children: [
          Expanded(child: Text(title, style: t(16.5, w: FontWeight.w600))),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: K.navy, minimumSize: const Size(44, 44)),
              child: Text(action!, style: t(14, c: K.navy)),
            ),
        ]),
      );
}

/// Rounded white text field with a small label above.
class Field extends StatelessWidget {
  const Field({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.number = false,
    this.phone = false,
    this.onChanged,
    this.big = false,
    this.suffix,
    this.prefix,
    this.autofocus = false,
    this.maxLines = 1,
    this.obscure = false,
    this.error,
    this.readOnly = false,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool number;
  final bool phone;
  final ValueChanged<String>? onChanged;
  final bool big;
  final String? suffix;
  final String? prefix;
  final bool autofocus;
  final int maxLines;
  final bool obscure;
  final String? error;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 6, bottom: 4), child: Text(label, style: t(13, c: K.muted))),
        TextField(
          controller: controller,
          readOnly: readOnly,
          autofocus: autofocus,
          obscureText: obscure,
          maxLines: maxLines,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : phone
                  ? TextInputType.phone
                  : TextInputType.text,
          inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯.,]'))] : null,
          onChanged: onChanged,
          style: t(big ? 26 : 16, w: big ? FontWeight.w700 : FontWeight.w400),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: t(big ? 22 : 15, c: const Color(0xFFA0A0A0)),
            errorText: error,
            prefixText: prefix,
            prefixStyle: t(big ? 22 : 16, w: FontWeight.w700),
            suffixText: suffix,
            suffixStyle: t(14, w: FontWeight.w600),
            filled: true,
            fillColor: readOnly ? const Color(0xFFEDEDED) : K.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(maxLines > 1 ? 16 : 26), borderSide: const BorderSide(color: K.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(maxLines > 1 ? 16 : 26), borderSide: const BorderSide(color: K.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(maxLines > 1 ? 16 : 26), borderSide: const BorderSide(color: K.blue, width: 2)),
          ),
        ),
      ]);
}

/// A row with a coloured round letter/icon, two lines and a value on the right.
class Row2 extends StatelessWidget {
  const Row2(
      {super.key,
      required this.lead,
      required this.title,
      this.sub,
      this.value,
      this.valueSub,
      this.valueColor = K.ink,
      this.subColor = K.muted,
      this.valueSubColor = K.muted,
      this.onTap,
      this.last = false});
  final Widget lead;
  final String title;
  final String? sub;
  final String? value;
  final String? valueSub;
  final Color valueColor;
  final Color subColor;
  final Color valueSubColor;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: K.line))),
          child: Row(children: [
            lead,
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t(15, w: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (sub != null) Text(sub!, style: t(12.5, c: subColor), maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(value!, style: t(15, w: FontWeight.w600, c: valueColor)),
                if (valueSub != null) Text(valueSub!, style: t(12, c: valueSubColor)),
              ]),
            ],
          ]),
        ),
      );
}

/// Round coloured letter used in lists.
Widget dotLetter(String s, Color bg, Color fg, {double size = 42}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(s, style: t(size * 0.31, w: FontWeight.w700, c: fg)),
    );

Widget dotIcon(IconData i, Color bg, Color fg, {double size = 42}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(i, size: size * 0.48, color: fg),
    );

/// A plain notice box.
class Note extends StatelessWidget {
  const Note(this.text, {super.key, this.color = K.blueTint, this.textColor = K.navy, this.icon});
  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icon != null) ...[Icon(icon, size: 19, color: textColor), const SizedBox(width: 10)],
          Expanded(child: Text(text, style: t(13, c: textColor, h: 1.5))),
        ]),
      );
}

Future<bool> confirm(BuildContext context, String title, String body, {String yes = 'হ্যাঁ', String no = 'না', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: t(18, w: FontWeight.w600)),
      content: Text(body, style: t(14.5, h: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(no, style: t(14.5, c: K.muted))),
        TextButton(onPressed: () => Navigator.pop(c, true), child: Text(yes, style: t(14.5, w: FontWeight.w600, c: danger ? K.red : K.blue))),
      ],
    ),
  );
  return r ?? false;
}

/// Asks for one line of text.
Future<String?> askText(BuildContext context, String title, {String hint = '', String initial = '', bool obscure = false, bool number = false, String ok = 'ঠিক আছে'}) async {
  final c = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: t(17, w: FontWeight.w600)),
      content: TextField(
        controller: c,
        autofocus: true,
        obscureText: obscure,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: t(16),
        decoration: InputDecoration(hintText: hint, hintStyle: t(15, c: K.muted)),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('বাতিল', style: t(14.5, c: K.muted))),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(ok, style: t(14.5, w: FontWeight.w600, c: K.blue))),
      ],
    ),
  );
  return r;
}
