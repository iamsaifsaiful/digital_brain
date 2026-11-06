import 'package:flutter/material.dart';

import '../../logic/bn.dart';
import '../../logic/lang.dart';
import '../../logic/pro.dart' show ProFeature;
import '../../state/brain.dart';
import '../../ui/kit.dart';
import '../../ui/pro_gate.dart' show needPro;
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../pro_screen.dart';

/// Pieces the business pages share (owner, 6 Nov — the "দোকানি" handoff,
/// in My Assistant's own design language).

void pushPage(BuildContext context, Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

/// A name's first letters for the round avatar / product tile ("চা", "না").
String initials(String name) {
  final t = name.trim();
  if (t.isEmpty) return '?';
  final chars = t.characters.where((c) => c.trim().isNotEmpty).take(2).join();
  return chars;
}

/// A product's tile: its first two letters on the accent tint.
class LetterTile extends StatelessWidget {
  const LetterTile(this.name, {super.key, this.size = 40});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(12)),
        child: Text(initials(name), style: body(13, weight: FontWeight.w700, color: C.green)),
      );
}

/// "বাকি", "দেনা ৳১৫,০০০", "৮ কেজি": the warning chip.
class WarnChip extends StatelessWidget {
  const WarnChip(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => SoftChip(text, warn: true);
}

/// The full-width two-part button row under a card ("+ যোগ করুন | সব …").
class CardFoot extends StatelessWidget {
  const CardFoot({super.key, required this.left, required this.onLeft, this.right, this.onRight, this.leftKey, this.rightKey});
  final String left;
  final VoidCallback onLeft;
  final String? right;
  final VoidCallback? onRight;
  final Key? leftKey;
  final Key? rightKey;

  @override
  Widget build(BuildContext context) {
    Widget part(String t, VoidCallback? on, Key? k) => Expanded(
          child: InkWell(
            key: k,
            onTap: on,
            child: SizedBox(height: 44, child: Center(child: Text(t, style: body(13, weight: FontWeight.w600, color: C.green)))),
          ),
        );
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: C.border))),
      child: Row(children: [
        part(left, onLeft, leftKey),
        if (right != null) ...[Container(width: 1, height: 24, color: C.border), part(right!, onRight, rightKey)],
      ]),
    );
  }
}

/// A list card: rows with hairlines between, and an optional foot.
class ListCard extends StatelessWidget {
  const ListCard({super.key, required this.rows, this.foot, this.empty});
  final List<Widget> rows;
  final Widget? foot;
  final String? empty;

  @override
  Widget build(BuildContext context) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (rows.isEmpty && empty != null) Padding(padding: const EdgeInsets.all(14), child: Text(empty!, style: body(13.5, color: C.muted, height: 1.5))),
          for (final (i, r) in rows.indexed) ...[if (i > 0) const Hairline(indent: 14, endIndent: 14), r],
          if (foot != null) foot!,
        ]),
      );
}

/// The inner page's title: back, 21px title, a 12px line; icons on the right.
class InnerTop extends StatelessWidget {
  const InnerTop({super.key, required this.title, this.sub, this.actions = const []});
  final String title;
  final String? sub;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
        child: Row(children: [
          IconButton(tooltip: tr('ফিরে যান'), onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.chevron_left_rounded, size: 28)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(21, weight: 600, height: 1.3)),
              if (sub != null) Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
            ]),
          ),
          ...actions,
        ]),
      );
}

/// The fixed foot of an inner page (the main action).
class PageFoot extends StatelessWidget {
  const PageFoot({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.border))),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 18 + MediaQuery.of(context).viewPadding.bottom),
        child: child,
      );
}

/// A number field (taka or quantity, Bangla or English digits).
class NumField extends StatelessWidget {
  const NumField({super.key, required this.controller, required this.label, this.hint, this.decimal = false, this.onChanged, this.fieldKey});
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool decimal;
  final ValueChanged<String>? onChanged;
  final Key? fieldKey;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(2, 0, 2, 6), child: Text(label, style: body(12.5, color: C.muted))),
        TextField(
          key: fieldKey,
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          onChanged: onChanged,
          style: body(15),
          decoration: InputDecoration(hintText: hint, isDense: true),
        ),
      ]);
}

/// A number typed in either digits ("১.২৫", "1.25").
double? readNum(String s) => double.tryParse(asciiDigits(s.trim()).replaceAll(',', ''));

/// ব্যবসায়ী মোড is Premium (owner, 6 Nov): anyone can switch it on and look
/// around; adding or changing anything asks for Premium.
Future<bool> bizCan(BuildContext context) => needPro(context, ProFeature.business);

/// The free app's line on the business pages: what Premium adds.
class BizFreeBanner extends StatelessWidget {
  const BizFreeBanner({super.key});
  @override
  Widget build(BuildContext context) {
    if (BrainScope.of(context).has(ProFeature.business)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: C.greenTint,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: const Key('biz-free-banner'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => pushPage(context, const ProScreen()),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(children: [
              Icon(Icons.workspace_premium_outlined, size: 20, color: C.green),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('ব্যবসায়ী মোড প্রিমিয়াম সুবিধা — সব দেখে নিন; বিক্রি, গ্রাহক, পণ্য যোগ করতে প্রিমিয়াম লাগবে।'), style: body(12.5, height: 1.45, color: C.ink))),
              Icon(Icons.chevron_right_rounded, color: C.green),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A labelled text field (name, mobile, address …).
class LabeledField extends StatelessWidget {
  const LabeledField({super.key, required this.controller, required this.label, this.hint, this.keyboard, this.lines = 1, this.fieldKey, this.icon, this.onChanged});
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboard;
  final int lines;
  final Key? fieldKey;
  final IconData? icon;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.fromLTRB(2, 0, 2, 6), child: Text(label, style: body(12.5, color: C.muted))),
          TextField(
            key: fieldKey,
            controller: controller,
            keyboardType: keyboard,
            minLines: lines,
            maxLines: lines,
            onChanged: onChanged,
            style: body(15),
            decoration: InputDecoration(hintText: hint, isDense: true, prefixIcon: icon == null ? null : Icon(icon, size: 19)),
          ),
        ]),
      );
}

/// "১২ দিন" / "২ মাস" for how long something has been owed.
String owedFor(int days) => days < 60 ? trf('{0} দিন', [bnDigits(days)]) : trf('{0} মাস', [bnDigits(days ~/ 30)]);

/// Detail rows on a profile (মোবাইল, হোয়াটসঅ্যাপ, ঠিকানা …), empty ones left out.
Widget detailRows(List<(IconData, String, String)> rows) {
  final shown = [for (final r in rows) if (r.$3.trim().isNotEmpty) r];
  return ListCard(
    rows: [
      for (final (icon, label, value) in shown)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 19, color: C.muted),
            const SizedBox(width: 12),
            SizedBox(width: 92, child: Text(label, style: body(13, color: C.muted))),
            Expanded(child: Text(value, style: body(14))),
          ]),
        ),
    ],
    empty: tr('আর কোনো তথ্য রাখা নেই। ✎ চেপে মোবাইল, হোয়াটসঅ্যাপ, ঠিকানা যোগ করুন।'),
  );
}
