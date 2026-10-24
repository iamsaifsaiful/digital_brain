import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import 'theme.dart';

/// "আগাম মনে করানো": none, 30 minutes, 1 or 2 hours, some days, or any
/// other time the user types. Exactly one is chosen: [minutes] for the
/// same-day ones, [days] for the day ones.
class EarlyPicker extends StatelessWidget {
  const EarlyPicker({super.key, required this.days, required this.minutes, required this.onChanged, this.showDays = true});
  final int days;
  final int minutes;
  final bool showDays;

  /// (days, minutes): one of them is 0.
  final void Function(int days, int minutes) onChanged;

  static const _minuteChoices = [30, 60, 120];
  static const _dayChoices = [1, 2, 3, 7, 30];

  Future<void> _custom(BuildContext context) async {
    final c = TextEditingController();
    var unit = 1; // 1 = minutes, 60 = hours, 1440 = days
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(tr('কতক্ষণ আগে মনে করাবো?'), style: body(18, weight: FontWeight.w600)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(
              controller: c,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: body(18),
              decoration: InputDecoration(hintText: tr('যেমন: ৪৫')),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: [
              for (final (u, label) in [(1, tr('মিনিট')), (60, tr('ঘণ্টা')), if (showDays) (1440, tr('দিন'))])
                ChoiceChip(
                  label: Text(label),
                  selected: unit == u,
                  onSelected: (_) => setD(() => unit = u),
                ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
            TextButton(
              onPressed: () {
                final n = int.tryParse(asciiDigits(c.text.trim()));
                if (n == null || n <= 0) return;
                Navigator.pop(ctx, n * unit);
              },
              child: Text(tr('রাখুন'), style: body(15, weight: FontWeight.w600, color: C.green)),
            ),
          ],
        ),
      ),
    );
    c.dispose();
    if (picked == null) return;
    if (picked % 1440 == 0) {
      onChanged(picked ~/ 1440, 0);
    } else {
      onChanged(0, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final none = days == 0 && minutes == 0;
    final custom = !none && !(minutes > 0 && _minuteChoices.contains(minutes)) && !(days > 0 && _dayChoices.contains(days));
    Widget chip(String label, bool on, VoidCallback tap) => ChoiceChip(
          label: Text(label, style: body(14, color: on ? C.onAccent : C.ink)),
          selected: on,
          showCheckmark: false,
          selectedColor: C.fill,
          backgroundColor: C.surface,
          side: BorderSide(color: on ? C.fill : C.border),
          shape: const StadiumBorder(),
          onSelected: (_) => tap(),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(tr('আগাম মনে করানো'), style: body(14, weight: FontWeight.w600, color: C.muted)),
      const SizedBox(height: 2),
      Text(tr('ঠিক সময়ে তো বাজবেই; চাইলে তার আগেও একবার'), style: body(12.5, color: C.muted)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        chip(tr('লাগবে না'), none, () => onChanged(0, 0)),
        for (final m in _minuteChoices) chip(trf('{0} আগে', [beforeLabel(m)]), minutes == m, () => onChanged(0, m)),
        if (showDays)
          for (final d in _dayChoices) chip(trf('{0} আগে', [beforeLabel(d * 1440)]), days == d && minutes == 0, () => onChanged(d, 0)),
        chip(custom ? trf('{0} আগে', [beforeLabel(minutes > 0 ? minutes : days * 1440)]) : tr('অন্য সময়…'), custom, () => _custom(context)),
      ]),
    ]);
  }
}

/// The units for "কতক্ষণ আগে": a number box beside a choice of these.
enum BeforeUnit {
  minute('মিনিট', 1, false),
  hour('ঘণ্টা', 60, false),
  day('দিন', 1, true),
  month('মাস', 30, true),
  year('বছর', 365, true);

  const BeforeUnit(this.label, this.size, this.days);
  final String label;

  /// Minutes (for minute, hour) or days (for day, month, year) in one.
  final int size;
  final bool days;
}

/// (days, minutes) to keep on the reminder for [n] [unit]s; one is 0.
(int, int) beforeIn(int n, BeforeUnit unit) => n <= 0 ? (0, 0) : (unit.days ? (n * unit.size, 0) : (0, n * unit.size));

/// The number and unit to show for a reminder's early notice.
(int, BeforeUnit) beforeOf(int days, int minutes) {
  if (minutes > 0) return minutes % 60 == 0 ? (minutes ~/ 60, BeforeUnit.hour) : (minutes, BeforeUnit.minute);
  if (days <= 0) return (0, BeforeUnit.minute);
  if (days % 365 == 0) return (days ~/ 365, BeforeUnit.year);
  if (days % 30 == 0) return (days ~/ 30, BeforeUnit.month);
  return (days, BeforeUnit.day);
}
