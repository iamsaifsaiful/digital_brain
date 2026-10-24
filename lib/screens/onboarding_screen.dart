import 'package:flutter/material.dart';

import '../logic/lang.dart';
import '../logic/templates.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

export '../logic/templates.dart' show personaLabel;

// The "আপনি কী করেন?" screen was removed (owner, 24 Oct: no profile).

/// তৈরি তালিকা: ready-made lists to add in one tap.
class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('তৈরি তালিকা')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Text(tr('একটা বেছে নিলে তার সব জিনিস কাজের তালিকায় আলাদা নামে উঠে যাবে। টিক দিয়ে দিয়ে শেষ করুন, দরকারমতো বাদ দিন বা যোগ করুন।'),
                  style: body(14, color: C.muted, height: 1.5)),
              const SizedBox(height: 14),
              for (final t in listTemplates) ...[
                Panel(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      _IconBox(templateIcon(t.name)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(tr(t.name), style: body(17, weight: FontWeight.w600))),
                      _addButton(context, brain, t),
                    ]),
                    const SizedBox(height: 6),
                    Text(t.items.map(tr).join(' · '), style: body(13, color: C.muted, height: 1.5), maxLines: 3, overflow: TextOverflow.ellipsis),
                  ]),
                ),
                const SizedBox(height: 10),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _addButton(BuildContext context, Brain brain, ListTemplate t) {
    final have = brain.data.tasks.any((x) => x.list == tr(t.name) && !x.done);
    if (have) return Pill(tr('যোগ করা আছে'));
    return FilledButton(
      onPressed: () async {
        await brain.addList(tr(t.name), [for (final i in t.items) tr(i)]);
        if (context.mounted) toast(context, trf('‘{0}’ কাজের তালিকায় যোগ হলো', [tr(t.name)]));
      },
      style: FilledButton.styleFrom(backgroundColor: C.green, shape: const StadiumBorder()),
      child: Text(tr('যোগ করুন')),
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
