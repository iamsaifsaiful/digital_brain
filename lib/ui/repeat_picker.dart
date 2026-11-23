/// কতবার বাজবে, one simple picker for every reminder form (owner, 22 Nov:
/// "আমি শুক্রবার শনিবার ছাড়া প্রতিদিন বিকালে পড়াই"): একবার · প্রতিদিন ·
/// মাসে · বছরে · ঘণ্টায়; under প্রতিদিন the week's seven days as circles —
/// a tap leaves a day out ("শুক্র ও শনিবার বাদে প্রতিদিন"), or keeps only
/// one ("প্রতি শনিবার").
library;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/repeat_text.dart';
import '../models/models.dart';
import 'theme.dart';
import 'widgets.dart';

enum RepeatKind { once, days, monthly, yearly, often }

RepeatKind repeatKindOf(Repeat r) => switch (r) {
      Repeat.none => RepeatKind.once,
      Repeat.daily || Repeat.weekly => RepeatKind.days,
      Repeat.monthly => RepeatKind.monthly,
      Repeat.yearly => RepeatKind.yearly,
      _ => RepeatKind.often,
    };

/// The repeat and its weekdays as kept: all seven days is plain daily.
(Repeat, List<int>) keptRepeat(Repeat r, Set<int> days) {
  if (r != Repeat.daily && r != Repeat.weekly) return (r, const []);
  if (days.isEmpty || days.length >= 7) return (Repeat.daily, const []);
  return (Repeat.weekly, [for (final d in weekOrder) if (days.contains(d)) d]);
}

/// "শুক্র ও শনিবার বাদে প্রতিদিন", "প্রতি শনিবার", "প্রতি মাসে"…
String repeatSaid(Repeat r, Set<int> days, DateTime date) {
  final (rep, wd) = keptRepeat(r, days);
  return repeatText(Reminder(title: '', date: date, repeat: rep, weekdays: wd));
}

class RepeatPicker extends StatelessWidget {
  const RepeatPicker({super.key, required this.repeat, required this.days, required this.onChanged});

  /// [Repeat.daily] or [Repeat.weekly] both show as প্রতিদিন with [days].
  final Repeat repeat;

  /// The days it rings, for প্রতিদিন (all seven = every day).
  final Set<int> days;
  final void Function(Repeat repeat, Set<int> days) onChanged;

  static final _all = {...weekOrder};
  static const _often = [Repeat.every5, Repeat.every10, Repeat.every30, Repeat.hourly];

  @override
  Widget build(BuildContext context) {
    final kind = repeatKindOf(repeat);
    final on = days.isEmpty ? _all : days;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegTabs<RepeatKind>(
        key: const Key('repeat-kind'),
        items: [
          (RepeatKind.once, tr('একবার')),
          (RepeatKind.days, tr('প্রতিদিন')),
          (RepeatKind.monthly, tr('মাসে')),
          (RepeatKind.yearly, tr('বছরে')),
          (RepeatKind.often, tr('ঘণ্টায়')),
        ],
        value: kind,
        onChanged: (k) => onChanged(
            switch (k) {
              RepeatKind.once => Repeat.none,
              RepeatKind.days => Repeat.daily,
              RepeatKind.monthly => Repeat.monthly,
              RepeatKind.yearly => Repeat.yearly,
              RepeatKind.often => Repeat.hourly,
            },
            k == RepeatKind.days ? _all : days),
      ),
      if (kind == RepeatKind.days) ...[
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          for (final d in weekOrder) _DayDot(day: d, on: on.contains(d), onTap: () {
            final next = {...on};
            next.contains(d) ? next.remove(d) : next.add(d);
            if (next.isEmpty) return; // never no day at all
            onChanged(next.length == 7 ? Repeat.daily : Repeat.weekly, next);
          }),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.event_repeat_rounded, size: 17, color: C.green),
          const SizedBox(width: 6),
          Expanded(
            child: Text(repeatSaid(repeat, on, DateTime(2026)),
                key: const Key('repeat-said'), style: body(13.5, weight: FontWeight.w600, color: C.greenDark)),
          ),
          if (on.length == 7)
            Text(tr('যে দিন বাদ, চাপুন'), style: body(12, color: C.muted))
          else
            GestureDetector(
              onTap: () => onChanged(Repeat.daily, _all),
              child: Text(tr('সব দিন'), style: body(12.5, weight: FontWeight.w600, color: C.green)),
            ),
        ]),
      ],
      if (kind == RepeatKind.often) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final r in [..._often, if (!_often.contains(repeat)) repeat])
            ChoiceChip(
              label: Text(tr(r.label), style: body(13.5, color: r == repeat ? C.onInk : C.ink)),
              selected: r == repeat,
              showCheckmark: false,
              selectedColor: C.ink,
              backgroundColor: C.surface,
              side: BorderSide(color: r == repeat ? C.ink : C.border),
              shape: const StadiumBorder(),
              onSelected: (_) => onChanged(r, days),
            ),
        ]),
      ],
    ]);
  }
}

/// One day of the week: filled when it rings, empty (and struck) when left out.
class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.on, required this.onTap});
  final int day;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = isEn ? dayShort(day).substring(0, 2) : (day == DateTime.thursday ? 'বৃহঃ' : dayName(day).replaceFirst(RegExp(r'বার$'), ''));
    return Semantics(
      button: true,
      selected: on,
      label: dayName(day),
      child: InkResponse(
        key: Key('rem-day-$day'),
        onTap: onTap,
        radius: 24,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on ? C.green : C.surface,
            border: Border.all(color: on ? C.green : C.line, width: 1.5),
          ),
          child: Text(name,
              maxLines: 1,
              style: body(12.5, weight: FontWeight.w700, color: on ? C.onAccent : C.muted).copyWith(decoration: on ? null : TextDecoration.lineThrough, decorationColor: C.muted)),
        ),
      ),
    );
  }
}
