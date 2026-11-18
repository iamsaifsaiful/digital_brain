/// "দিনে কয়বার" and "কখন খাবেন" for a medicine (owner, 25 Oct; 18 Nov):
/// how many times a day is a choice that stays selected and sets the times;
/// the times are a short list, a tap changes one — no crosses.
library;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
export '../logic/meal.dart';
import 'forms.dart' show askTime, minutesText;
import 'theme.dart';

/// The usual times for 1–4 doses a day.
const medicinePresets = <int, List<int>>{
  1: [9 * 60],
  2: [9 * 60, 21 * 60],
  3: [8 * 60, 14 * 60, 22 * 60],
  4: [8 * 60, 13 * 60, 18 * 60, 22 * 60],
};

class MedicineTimesPicker extends StatelessWidget {
  const MedicineTimesPicker({super.key, required this.times, required this.onChanged});
  final List<int> times;
  final ValueChanged<List<int>> onChanged;

  /// Owner, 18 Nov: the times as a short list — one row per dose, a tap
  /// changes that time — instead of seventeen chips ("সময়গুলো হিবিজিবি").
  Future<void> _change(BuildContext context, int i) async {
    final m = await askTime(context, times[i]);
    if (m == null || m == times[i]) return;
    final next = [...times]..[i] = m;
    onChanged(next.toSet().toList()..sort());
  }

  @override
  Widget build(BuildContext context) {
    final perDay = times.length;
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
        Text(tr('বদলাতে সময়ে চাপুন'), style: body(12, color: C.muted)),
      ]),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.line)),
        child: Column(children: [
          for (final (i, m) in times.indexed) ...[
            if (i > 0) Divider(height: 1, color: C.line),
            _TimeRow(key: Key('med-time-$m'), minutes: m, onTap: () => _change(context, i)),
          ],
          if (times.isNotEmpty) Divider(height: 1, color: C.line),
          InkWell(
            key: const Key('med-time-other'),
            onTap: () async {
              final m = await askTime(context, 13 * 60);
              if (m != null && !times.contains(m)) onChanged([...times, m]..sort());
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(children: [
                Icon(Icons.add_rounded, size: 20, color: C.green),
                const SizedBox(width: 10),
                Text(tr('আরেকটা সময়'), style: body(14.5, weight: FontWeight.w600, color: C.green)),
              ]),
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// One dose time: the part of the day's icon, the time, and a pencil.
class _TimeRow extends StatelessWidget {
  const _TimeRow({super.key, required this.minutes, required this.onTap});
  final int minutes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final h = minutes ~/ 60;
    final icon = h < 12 ? Icons.wb_sunny_outlined : (h < 18 ? Icons.wb_twilight_outlined : Icons.nightlight_outlined);
    return Semantics(
      selected: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 19, color: C.green)),
            const SizedBox(width: 12),
            Expanded(child: Text(minutesText(minutes), style: body(16, weight: FontWeight.w700))),
            Icon(Icons.edit_outlined, size: 19, color: C.muted),
          ]),
        ),
      ),
    );
  }
}

/// Before, after or with food — or any time (owner, 29 Oct).
class MealPicker extends StatelessWidget {
  const MealPicker({super.key, required this.meal, required this.onChanged});
  final String meal;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (k, label) in [('before', tr('খাবারের আগে')), ('after', tr('খাবারের পরে')), ('with', tr('খাবারের সাথে')), ('', tr('যেকোনো সময়'))])
          _TimeChip(key: Key('med-meal-${k.isEmpty ? 'any' : k}'), label: label, selected: meal == k, onTap: () => onChanged(k)),
      ]);
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
