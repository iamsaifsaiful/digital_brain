import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/lang.dart';
import '../models/models.dart';
import '../ui/cat_style.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// খাত অনুযায়ী (approved design, 3 Nov): a ring of the খাত, each with its
/// share and the change from the period before. A tap on one returns it, to
/// show only that খাত's entries.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.title, required this.entries, required this.before, this.income = false});

  /// The period, as the summary card says it ("অক্টোবর ২০২৬").
  final String title;
  final List<CashEntry> entries;

  /// The period before, for the change.
  final List<CashEntry> before;
  final bool income;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late bool _income = widget.income;

  @override
  Widget build(BuildContext context) {
    final now = sumsOf(widget.entries);
    final was = sumsOf(widget.before);
    final parts = _income ? now.topIncome : now.topExpenses;
    final old = {for (final e in (_income ? was.topIncome : was.topExpenses)) e.key: e.value};
    final total = parts.fold<int>(0, (a, e) => a + e.value);
    final most = parts.isEmpty ? null : parts.first;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: '${tr('খাত অনুযায়ী')} · ${widget.title}'),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              SegTabs<bool>(
                key: const Key('cats-kind'),
                items: [(false, tr('খরচ')), (true, tr('আয়'))],
                value: _income,
                onChanged: (v) => setState(() => _income = v),
              ),
              const SizedBox(height: 12),
              if (parts.isEmpty)
                EmptyState(icon: Icons.pie_chart_outline_rounded, title: _income ? tr('এই সময়ে কোনো আয় নেই') : tr('এই সময়ে কোনো খরচ নেই'), text: '')
              else ...[
                Panel(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    SizedBox(
                      width: 148,
                      height: 148,
                      child: Stack(alignment: Alignment.center, children: [
                        CustomPaint(size: const Size(148, 148), painter: _Ring([for (final e in parts) (e.value, catStyle(e.key).color)], C.surface2)),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_income ? tr('মোট আয়') : tr('মোট খরচ'), style: body(11.5, color: C.muted)),
                          FittedBox(child: Text(taka(total), style: display(17, weight: 700))),
                        ]),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    if (most != null)
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr('সবচেয়ে বেশি'), style: body(12.5, color: C.muted)),
                          Text('${tr(most.key)} · ${bnDigits((most.value * 100 / total).round())}%', style: body(14.5, weight: FontWeight.w700)),
                        ]),
                      ),
                  ]),
                ),
                const SizedBox(height: 12),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                      child: Row(children: [
                        Expanded(child: Text(tr('খাতে চাপলে সেই খাতের লেনদেন'), style: body(11.5, color: C.muted))),
                        Text(tr('আগের তুলনায়'), style: body(11.5, color: C.muted)),
                      ]),
                    ),
                    for (final e in parts)
                      InkWell(
                        key: Key('cats-${e.key}'),
                        onTap: () => Navigator.of(context).pop(e.key),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
                          child: Row(children: [
                            CatIcon(e.key, size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                Row(children: [
                                  Expanded(child: Text(tr(e.key), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w600))),
                                  Text(taka(e.value), style: body(14, weight: FontWeight.w700)),
                                ]),
                                const SizedBox(height: 5),
                                Row(children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(value: e.value / parts.first.value, minHeight: 5, color: catStyle(e.key).color, backgroundColor: C.surface2),
                                    ),
                                  ),
                                  SizedBox(width: 38, child: Text('${bnDigits((e.value * 100 / total).round())}%', textAlign: TextAlign.right, style: body(11.5, color: C.muted))),
                                  SizedBox(width: 44, child: _Change(now: e.value, was: old[e.key], income: _income)),
                                ]),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

/// "↓১২%": less spent (or more earned) than before reads blue, more spent red.
class _Change extends StatelessWidget {
  const _Change({required this.now, required this.was, required this.income});
  final int now;
  final int? was;
  final bool income;

  @override
  Widget build(BuildContext context) {
    final w = was;
    if (w == null || w == 0) return Text('—', textAlign: TextAlign.right, style: body(11.5, color: C.muted));
    final pct = ((now - w) * 100 / w).round();
    if (pct == 0) return Text('—', textAlign: TextAlign.right, style: body(11.5, color: C.muted));
    final good = income ? pct > 0 : pct < 0;
    return Text('${pct > 0 ? '↑' : '↓'}${bnDigits(pct.abs())}%', textAlign: TextAlign.right, style: body(11.5, weight: FontWeight.w600, color: good ? C.blue : C.red));
  }
}

class _Ring extends CustomPainter {
  _Ring(this.parts, this.track);
  final List<(int, Color)> parts;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final total = parts.fold<int>(0, (a, p) => a + p.$1);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    if (total == 0) {
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint..color = track);
      return;
    }
    const gap = 0.03;
    var start = -math.pi / 2;
    for (final (v, c) in parts) {
      final sweep = 2 * math.pi * v / total;
      canvas.drawArc(rect, start, math.max(0.001, sweep - (parts.length > 1 ? gap : 0)), false, paint..color = c);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_Ring old) => old.parts != parts || old.track != track;
}
