/// "দিনে কয়বার" and "কখন খাবেন" for a medicine (owner, 25 Oct): how many
/// times a day is a choice that stays selected, and picking it changes the
/// times shown; each time is a chip that changes colour when chosen — no
/// crosses to remove.
library;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import 'forms.dart' show askTime, minutesText;
import 'theme.dart';

/// The usual times for 1–4 doses a day.
const medicinePresets = <int, List<int>>{
  1: [9 * 60],
  2: [9 * 60, 21 * 60],
  3: [8 * 60, 14 * 60, 22 * 60],
  4: [8 * 60, 13 * 60, 18 * 60, 22 * 60],
};

/// The times offered, by part of the day.
const _parts = <(String, List<int>)>[
  ('সকাল', [6 * 60, 7 * 60, 8 * 60, 9 * 60, 10 * 60]),
  ('দুপুর-বিকেল', [12 * 60, 13 * 60, 14 * 60, 16 * 60, 18 * 60]),
  ('রাত', [20 * 60, 21 * 60, 22 * 60, 23 * 60]),
];

class MedicineTimesPicker extends StatelessWidget {
  const MedicineTimesPicker({super.key, required this.times, required this.onChanged});
  final List<int> times;
  final ValueChanged<List<int>> onChanged;

  void _toggle(int m) {
    final next = [...times];
    next.contains(m) ? next.remove(m) : next.add(m);
    next.sort();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final perDay = times.length;
    final offered = {for (final (_, ts) in _parts) ...ts};
    final own = [for (final t in times) if (!offered.contains(t)) t]..sort();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(tr('দিনে কয়বার'), style: body(13.5, weight: FontWeight.w600, color: C.muted2)),
      const SizedBox(height: 8),
      Row(children: [
        for (final n in medicinePresets.keys) ...[
          Expanded(
            child: _Pill(
              key: Key('med-per-$n'),
              label: trf('{0} বার', [bnDigits(n)]),
              selected: perDay == n,
              onTap: () => onChanged([...medicinePresets[n]!]),
            ),
          ),
          if (n != medicinePresets.keys.last) const SizedBox(width: 8),
        ],
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: Text(tr('কখন খাবেন'), style: body(13.5, weight: FontWeight.w600, color: C.muted2))),
        Text(perDay == 0 ? tr('একটা সময় বেছে নিন') : trf('{0}টা সময় বাছা', [bnDigits(perDay)]), style: body(12.5, color: perDay == 0 ? C.red : C.muted)),
      ]),
      for (final (part, ts) in _parts) ...[
        const SizedBox(height: 10),
        Text(tr(part), style: body(12.5, color: C.muted)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in ts) _TimeChip(key: Key('med-time-$m'), label: minutesText(m), selected: times.contains(m), onTap: () => _toggle(m)),
        ]),
      ],
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final m in own) _TimeChip(key: Key('med-time-$m'), label: minutesText(m), selected: true, onTap: () => _toggle(m)),
        _TimeChip(
          key: const Key('med-time-other'),
          label: tr('অন্য সময়'),
          selected: false,
          icon: Icons.add_rounded,
          onTap: () async {
            final m = await askTime(context, 13 * 60);
            if (m != null && !times.contains(m)) onChanged([...times, m]..sort());
          },
        ),
      ]),
    ]);
  }
}

/// "কার জন্য": the user and each family member, one tap to choose.
class MedicinePersonPicker extends StatelessWidget {
  const MedicinePersonPicker({super.key, required this.people, required this.selected, required this.onChanged});
  final List<(String, String)> people;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (id, name) in people)
          _TimeChip(key: Key('med-who-$id'), label: name, selected: id == selected, icon: id == selected ? null : Icons.person_outline_rounded, onTap: () => onChanged(id)),
      ]);
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? C.green : C.surface2,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: selected ? C.green : C.line)),
              child: Text(label, style: body(15, weight: FontWeight.w600, color: selected ? C.onAccent : C.ink)),
            ),
          ),
        ),
      );
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({super.key, required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? C.green : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(999), border: Border.all(color: selected ? C.green : C.line)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 18, color: C.muted2), const SizedBox(width: 4)],
                Text(label, style: body(14.5, weight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? C.onAccent : C.ink)),
              ]),
            ),
          ),
        ),
      );
}
