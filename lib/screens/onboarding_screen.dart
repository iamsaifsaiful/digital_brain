import 'package:flutter/material.dart';

import '../logic/lang.dart';
import '../logic/templates.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../logic/bn.dart';
import 'pick_sheets.dart' show TemplatePreviewScreen;

export '../logic/templates.dart' show personaLabel;

// The "আপনি কী করেন?" screen was removed (owner, 24 Oct: no profile).

/// তৈরি তালিকা: ready-made lists. A tap shows the list first, to take
/// things out or put more in before it is added (owner, 22 Nov).
class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('রেডিমেড তালিকা')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Text(tr('একটা বেছে নিন — যোগ করার আগে পুরো তালিকা দেখাবে, দরকারমতো বাদ দিন বা যোগ করুন।'), style: body(14, color: C.muted, height: 1.5)),
              const SizedBox(height: 14),
              for (final t in listTemplates) ...[
                _card(context, brain, t),
                const SizedBox(height: 10),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _card(BuildContext context, Brain brain, ListTemplate t) {
    final have = brain.data.tasks.any((x) => x.list == tr(t.name) && !x.done);
    void open() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TemplatePreviewScreen(template: t)));
    return Material(
      key: Key('tpl-${t.name}'),
      color: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: C.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            _IconBox(templateIcon(t.name)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(t.name), style: body(16.5, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(t.items.take(3).map(tr).join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
                const SizedBox(height: 4),
                Text(have ? tr('যোগ করা আছে · আবার দেখুন') : trf('{0}টি জিনিস · দেখে যোগ করুন', [bnDigits(t.items.length)]),
                    style: body(12.5, weight: FontWeight.w600, color: have ? C.muted : C.green)),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: C.muted),
          ]),
        ),
      ),
    );
  }
}


/// A plain icon in a soft square (instead of emoji: calm and the same on every phone).
class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: C.green, size: 24),
      );
}

IconData templateIcon(String name) => switch (name) {
      'ঈদের কেনাকাটা' => Icons.shopping_bag_outlined,
      'কুরবানির প্রস্তুতি' => Icons.pets_outlined,
      'বিয়ের আয়োজন' => Icons.favorite_border_rounded,
      'হজ/উমরাহর প্রস্তুতি' => Icons.mosque_outlined,
      'ভ্রমণের চেকলিস্ট' => Icons.luggage_outlined,
      'মাসিক বিল' => Icons.receipt_long_outlined,
      'মাসের বাজার' => Icons.shopping_cart_outlined,
      'দেশে ফেরার প্রস্তুতি' => Icons.flight_land_rounded,
      'বাচ্চার স্কুল' => Icons.backpack_outlined,
      _ => Icons.checklist_rounded,
    };
