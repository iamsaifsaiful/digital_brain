import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/spend_health.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// খরচ বিশ্লেষণ: what share of income went where this week (or 30 days),
/// beside the 50/30/20 guide, with what to cut.
class SpendHealthScreen extends StatefulWidget {
  const SpendHealthScreen({super.key});
  @override
  State<SpendHealthScreen> createState() => _SpendHealthScreenState();
}

Color groupColor(SpendGroup g) => switch (g) {
      SpendGroup.need => C.blue,
      SpendGroup.want => C.orange,
      SpendGroup.give => C.purple,
      SpendGroup.other => C.muted,
    };

class _SpendHealthScreenState extends State<SpendHealthScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final h = spendHealth(brain.data, brain.services.now(), days: _days);
    final advice = spendAdvice(h);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('খরচ বিশ্লেষণ')),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: SegTabs<int>(items: [(7, tr('এই সপ্তাহ')), (30, tr('৩০ দিন'))], value: _days, onChanged: (v) => setState(() => _days = v)),
          ),
          Expanded(
            child: SwipeSwitch.tabs<int>(
              values: const [7, 30],
              value: _days,
              onChanged: (v) => setState(() => _days = v),
              child: ListView(key: ValueKey(_days), padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                _Split(h),
                const SizedBox(height: 14),
                if (advice.isNotEmpty)
                  Panel(
                    key: const Key('spend-advice'),
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(Icons.tips_and_updates_outlined, color: C.green, size: 20),
                        const SizedBox(width: 8),
                        Text(tr('কী করা যায়'), style: body(15, weight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 8),
                      for (final a in advice)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Padding(padding: const EdgeInsets.only(top: 8), child: Container(width: 5, height: 5, decoration: BoxDecoration(color: C.muted, shape: BoxShape.circle))),
                            const SizedBox(width: 8),
                            Expanded(child: Text(a, style: body(14, height: 1.45))),
                          ]),
                        ),
                    ]),
                  ),
                if (h.shares.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  SectionTitle(h.hasIncome ? tr('খাত অনুযায়ী — আয়ের কত ভাগ') : tr('খাত অনুযায়ী — খরচের কত ভাগ')),
                  Panel(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                    child: Column(children: [for (final s in h.shares) _Row(s, h)]),
                  ),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// The income in one bar — needs, wants, giving, unknown, kept — and the guide under it.
class _Split extends StatelessWidget {
  const _Split(this.h);
  final SpendHealth h;

  @override
  Widget build(BuildContext context) {
    final kept = h.hasIncome ? h.kept.clamp(0, h.income) : 0;
    final parts = <(String, int, Color)>[
      for (final g in SpendGroup.values)
        if (h.sum(g) > 0) (groupName(g), h.sum(g), groupColor(g)),
      if (kept > 0) (tr('বেঁচে আছে'), kept, C.green),
    ];
    final total = parts.fold(0, (a, p) => a + p.$2);
    Widget bar(List<(String, int, Color)> ps, int of, {double height = 16}) => ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: height,
            child: Row(children: [
              for (final p in ps)
                if (p.$2 > 0) Expanded(flex: (p.$2 * 1000 / (of <= 0 ? 1 : of)).round().clamp(1, 100000), child: Container(color: p.$3)),
            ]),
          ),
        );
    return Panel(
      key: const Key('spend-split'),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(h.days >= 30 ? tr('গত ৩০ দিন') : tr('গত ৭ দিন'), style: body(13, color: C.muted)),
        const SizedBox(height: 2),
        Text(
          h.hasIncome ? trf('আয় {0} · খরচ {1} ({2}%)', [taka(h.income), taka(h.spent), bnDigits(h.pct(h.spent))]) : trf('খরচ {0}', [taka(h.spent)]),
          style: display(19, weight: 700),
        ),
        if (h.hasIncome && h.days < 30) Text(tr('সাপ্তাহিক আয় = গত ৩০ দিনের আয়ের ৭ দিনের ভাগ'), style: body(12, color: C.muted)),
        const SizedBox(height: 14),
        Text(tr('আপনার'), style: body(12.5, color: C.muted)),
        const SizedBox(height: 4),
        if (total > 0) bar(parts, total) else Container(height: 16, decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(8))),
        const SizedBox(height: 10),
        Text(tr('যেমন হওয়া ভালো (৫০/৩০/২০)'), style: body(12.5, color: C.muted)),
        const SizedBox(height: 4),
        bar([(tr('প্রয়োজনীয়'), needCap, C.blue.withValues(alpha: 0.45)), (tr('শখের'), wantCap, C.orange.withValues(alpha: 0.45)), (tr('সঞ্চয়'), keepGoal, C.green.withValues(alpha: 0.45))], 100, height: 10),
        const SizedBox(height: 12),
        Wrap(spacing: 14, runSpacing: 6, children: [
          for (final p in parts)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Text('${p.$1} ${bnDigits(h.pct(p.$2))}%', style: body(13, weight: FontWeight.w500)),
            ]),
        ]),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.s, this.h);
  final SpendShare s;
  final SpendHealth h;

  @override
  Widget build(BuildContext context) {
    final p = h.pct(s.amount);
    final c = groupColor(s.group);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(spendLabel(s.category), style: body(14.5, weight: FontWeight.w500))),
          Text(taka(s.amount), style: body(13.5, color: C.muted)),
          const SizedBox(width: 10),
          SizedBox(width: 44, child: Text('${bnDigits(p)}%', textAlign: TextAlign.right, style: body(14.5, weight: FontWeight.w700, color: s.group == SpendGroup.want && p >= 10 ? C.orange : C.ink))),
        ]),
        const SizedBox(height: 5),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: (p / 100).clamp(0, 1).toDouble(), minHeight: 6, color: c, backgroundColor: C.soft),
            ),
          ),
          const SizedBox(width: 10),
          Text(groupName(s.group), style: body(11.5, color: c)),
        ]),
      ]),
    );
  }
}
