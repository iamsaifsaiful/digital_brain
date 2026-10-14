import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import 'theme.dart';

/// A one-line question in a dialog ("নাম", "টাকার পরিমাণ"…). Null when cancelled.
Future<String?> askText(BuildContext context, String title, {String initial = '', String? hint, bool number = false, int lines = 1}) async {
  final c = TextEditingController(text: initial);
  final v = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: body(18, weight: FontWeight.w600)),
      content: TextField(
        controller: c,
        autofocus: true,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 3,
        keyboardType: number ? TextInputType.number : (lines > 1 ? TextInputType.multiline : TextInputType.text),
        inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9০-৯]'))] : null,
        style: body(16),
        decoration: InputDecoration(hintText: hint),
        onSubmitted: lines == 1 ? (t) => Navigator.pop(ctx, t) : null,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(tr('রাখুন'), style: body(15, weight: FontWeight.w600, color: C.green))),
      ],
    ),
  );
  c.dispose();
  return v?.trim();
}

/// A number typed in Bengali or English digits.
int? readInt(String? s) => s == null ? null : int.tryParse(asciiDigits(s).replaceAll(RegExp(r'[^0-9]'), ''));

/// The phone's clock picker; minutes after midnight.
Future<int?> askTime(BuildContext context, int minutes) async {
  final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
  return t == null ? null : t.hour * 60 + t.minute;
}

/// "সকাল ৮টা" for minutes after midnight.
String minutesText(int m) => bnTime(m ~/ 60, m % 60);

/// A label above a field.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
        child: Text(text, style: body(14, weight: FontWeight.w600, color: C.muted2)),
      );
}

/// One choice out of a few, as chips.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({super.key, required this.items, required this.value, required this.onChanged});
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (v, label) in items)
          ChoiceChip(
            label: Text(label),
            selected: v == value,
            onSelected: (_) => onChanged(v),
            labelStyle: body(14, weight: v == value ? FontWeight.w600 : FontWeight.w400, color: v == value ? C.greenDark : C.muted2),
          ),
      ]);
}

/// A progress bar with rounded ends.
class Bar extends StatelessWidget {
  const Bar({super.key, required this.value, this.color, this.height = 8});
  final double value;
  final Color? color;
  final double height;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: height, backgroundColor: C.chip, color: color ?? C.green),
      );
}

/// "বদলান" or "মুছুন" for a saved entry ('edit', 'delete', or null).
Future<String?> editOrDelete(BuildContext context, {String? title}) => showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: display(17, weight: 700)),
            ),
          ListTile(leading: const Icon(Icons.edit_outlined), title: Text(tr('বদলান'), style: body(16)), onTap: () => Navigator.pop(ctx, 'edit')),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: C.red),
            title: Text(tr('মুছুন'), style: body(16, color: C.red)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
