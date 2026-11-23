import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/daily_ask.dart';
import '../logic/lang.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart' show toast;
import 'health_hub.dart';

/// The day's one small question on Home (owner, 22 Nov): in the morning
/// "রাতে কত ঘণ্টা ঘুমালেন?", at night "আজ কত গ্লাস পানি খেলেন?". One tap
/// answers; "আজ না" hides it until tomorrow; after three skips in a row it
/// offers to stop asking. Shows nothing outside its hours.
class DailyAskCard extends StatefulWidget {
  const DailyAskCard({super.key});

  @override
  State<DailyAskCard> createState() => _DailyAskCardState();
}

class _DailyAskCardState extends State<DailyAskCard> {
  /// Answered just now: a one-line thanks until the page is left.
  (DailyAsk, num)? _answered;
  DateTime? _answeredAt;
  int? _glasses;

  void _done(Brain brain, (DailyAsk, num) a) => setState(() {
        _answered = a;
        _answeredAt = brain.services.now();
      });

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final a = _answered;
    // The thanks stays a few minutes, then the card is gone for the day.
    if (a != null && _answeredAt != null && now.difference(_answeredAt!).inMinutes < 3) return _wrap(_thanks(context, a));
    final ask = askNow(brain.data, now, sleepOn: brain.askOn(DailyAsk.sleep), waterOn: brain.askOn(DailyAsk.water), done: brain.askDone);
    if (ask == null) return const SizedBox.shrink();
    return _wrap(ask == DailyAsk.sleep ? _sleep(brain, now) : _water(brain, now));
  }

  Widget _wrap(Widget child) => Padding(padding: const EdgeInsets.only(top: 16), child: AppCard(key: const Key('home-daily-ask'), child: child));

  Widget _head(IconData icon, Color color, Color tint, String title, String sub, DailyAsk k, Brain brain) {
    final offerOff = brain.askSkips(k) >= askOfferOffAfter;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          child: Icon(icon, size: 19, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: body(15, weight: FontWeight.w600, height: 1.3)),
            const SizedBox(height: 2),
            Text(offerOff ? tr('কয়েক দিন উত্তর দেননি — প্রশ্নটা বন্ধ রাখব?') : sub, style: body(12, color: C.muted, height: 1.35)),
          ]),
        ),
        TextButton(
          key: Key('ask-skip-${k.name}'),
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 30)),
          onPressed: () => brain.skipAsk(k),
          child: Text(tr('আজ না'), style: body(12.5, color: C.muted)),
        ),
      ]),
      if (offerOff)
        Padding(
          padding: const EdgeInsets.only(left: 46),
          child: TextButton(
            key: Key('ask-off-${k.name}'),
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
            onPressed: () async {
              await brain.setAskOn(k, false);
              if (mounted) toast(context, tr('বন্ধ হলো। স্বাস্থ্য পাতা থেকে আবার চালু করা যাবে।'));
            },
            child: Text(tr('আর জিজ্ঞেস করবেন না'), style: body(12.5, weight: FontWeight.w600, color: C.green)),
          ),
        ),
    ]);
  }

  Widget _sleep(Brain brain, DateTime now) {
    final avg = averageOf(lastDays(brain.data, HealthKind.sleep, now));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _head(Icons.bedtime_outlined, C.purple, C.purpleTint, tr('রাতে কত ঘণ্টা ঘুমালেন?'),
          avg == null ? tr('এক ট্যাপে জানান — অ্যাপ সপ্তাহের হিসাব রাখবে') : trf('এ সপ্তাহে গড়ে {0} ঘণ্টা', [oneDecimal(avg)]), DailyAsk.sleep, brain),
      const SizedBox(height: 12),
      Row(children: [
        for (final h in sleepChoices) ...[
          if (h != sleepChoices.first) const SizedBox(width: 6),
          Expanded(
            child: _Pill(
              key: Key('ask-sleep-$h'),
              label: h == sleepChoices.first ? '≤${bnDigits(h)}' : (h == sleepChoices.last ? '${bnDigits(h)}+' : bnDigits(h)),
              onTap: () async {
                await brain.answerSleep(h.toDouble());
                if (mounted) _done(brain, (DailyAsk.sleep, h));
              },
            ),
          ),
        ],
      ]),
      const SizedBox(height: 6),
      Text(tr('ঘণ্টা'), textAlign: TextAlign.center, style: body(11.5, color: C.muted)),
    ]);
  }

  Widget _water(Brain brain, DateTime now) {
    final week = lastDays(brain.data, HealthKind.water, now);
    final today = week.last;
    final avg = averageOf(week.sublist(0, 6));
    final n = _glasses ?? today?.round() ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _head(Icons.water_drop_outlined, C.blue, C.blueTint, tr('আজ কত গ্লাস পানি খেলেন?'),
          today != null && today > 0
              ? trf('দিনে {0} গ্লাস লেখা ছিল — মিলিয়ে নিন', [bnDigits(today.round())])
              : (avg == null ? tr('দিনে ৮ গ্লাসের লক্ষ্য · এক ট্যাপে জানান') : trf('এ সপ্তাহে গড়ে {0} গ্লাস', [oneDecimal(avg)])),
          DailyAsk.water, brain),
      const SizedBox(height: 12),
      // Eight glasses: a tap on one fills up to it.
      Row(children: [
        for (var i = 1; i <= waterGoal; i++)
          Expanded(
            child: InkWell(
              key: Key('ask-water-$i'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _glasses = n == i ? i - 1 : i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Icon(i <= n ? Icons.local_drink_rounded : Icons.local_drink_outlined, size: 26, color: i <= n ? C.blue : C.line),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        _Round(icon: Icons.remove_rounded, onTap: n == 0 ? null : () => setState(() => _glasses = n - 1)),
        Expanded(
          child: Text(trf('{0} গ্লাস', [bnDigits(n)]), textAlign: TextAlign.center, style: display(18, weight: 700, color: n >= waterGoal ? C.green : C.ink)),
        ),
        _Round(icon: Icons.add_rounded, onTap: n >= 20 ? null : () => setState(() => _glasses = n + 1)),
        const SizedBox(width: 12),
        FilledButton(
          key: const Key('ask-water-save'),
          style: FilledButton.styleFrom(backgroundColor: C.green, foregroundColor: C.onAccent, minimumSize: const Size(0, 40), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () async {
            await brain.answerWater(n);
            if (mounted) _done(brain, (DailyAsk.water, n));
          },
          child: Text(tr('রাখুন'), style: body(14, weight: FontWeight.w600, color: C.onAccent)),
        ),
      ]),
    ]);
  }

  Widget _thanks(BuildContext context, (DailyAsk, num) a) {
    final sleep = a.$1 == DailyAsk.sleep;
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final line = sleep ? sleepWeekLine(lastDays(brain.data, HealthKind.sleep, now)) : waterWeekLine(lastDays(brain.data, HealthKind.water, now));
    return Row(children: [
      Icon(Icons.check_circle_rounded, color: C.green, size: 22),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(sleep ? trf('ঘুম {0} ঘণ্টা — লেখা হলো', [bnDigits(a.$2)]) : trf('আজ {0} গ্লাস পানি — লেখা হলো', [bnDigits(a.$2)]), style: body(14, weight: FontWeight.w600)),
          Text(line, style: body(12, color: C.muted, height: 1.35)),
        ]),
      ),
      TextButton(
        onPressed: () {
          setState(() => _answered = null);
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthScreen()));
        },
        child: Text(tr('দেখুন'), style: body(13, weight: FontWeight.w600, color: C.green)),
      ),
    ]);
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: C.purpleTint,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(height: 42, child: Center(child: Text(label, style: display(17, weight: 700, color: C.purple)))),
        ),
      );
}

class _Round extends StatelessWidget {
  const _Round({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: C.surface2,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 38, height: 38, child: Icon(icon, size: 20, color: onTap == null ? C.muted : C.ink)),
        ),
      );
}

/// Seven days as small bars, today last (স্বাস্থ্য page).
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.values, required this.max, required this.goal, required this.color, required this.now});
  final List<double?> values;
  final double max;
  final double goal;
  final Color color;
  final DateTime now;

  static const _bnDays = ['সোম', 'মঙ্গল', 'বুধ', 'বৃহ', 'শুক্র', 'শনি', 'রবি'];
  static const _enDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = dayOnly(now);
    return SizedBox(
      height: 92,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(values[i] == null ? '' : oneDecimal(values[i]!), style: body(10.5, color: C.muted)),
              const SizedBox(height: 2),
              Container(
                width: 18,
                height: values[i] == null ? 4 : (56 * (values[i]! / max).clamp(0.06, 1.0)),
                decoration: BoxDecoration(
                  color: values[i] == null ? C.line : (values[i]! >= goal ? color : color.withValues(alpha: 0.45)),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                () {
                  final d = today.subtract(Duration(days: values.length - 1 - i));
                  return isEn ? _enDays[d.weekday - 1] : _bnDays[d.weekday - 1];
                }(),
                style: body(10.5, color: i == values.length - 1 ? C.ink : C.muted, weight: i == values.length - 1 ? FontWeight.w600 : FontWeight.w400),
              ),
            ]),
          ),
      ]),
    );
  }
}
