import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../state/brain.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/pin.dart' show verifyUser;
import '../ui/widgets.dart' show TabTitle;
import 'calls_screen.dart';
import 'docs_screen.dart';
import 'home_shell.dart';
import 'new_item_screen.dart';
import 'health_hub.dart';
import 'notes_screen.dart';
import 'search_screen.dart';
import 'special_days_screen.dart';
import 'store_more_screens.dart';
import 'vault_screen.dart';
import '../logic/lang.dart';
import '../logic/pro.dart' show medicalOff;

/// সংরক্ষণ: notes, passwords, contacts and the user's own categories —
/// everything kept for later, locked on this phone.
class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final now = brain.services.now();
    final today = DateTime(now.year, now.month, now.day);

    // Owner, 19 Nov (design খ, "চার ঘর"): one colour, thin line icons, white
    // cards. The four used most in big squares, the rest as small buttons,
    // one line when a paper runs out, then what was kept lately.
    Widget box(Widget child, {double radius = 14}) => Container(
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(radius), border: Border.all(color: C.border)),
          clipBehavior: Clip.antiAlias,
          child: Material(color: Colors.transparent, child: child),
        );

    Widget tile(Key key, String label, int count, IconData icon, VoidCallback onTap) => Expanded(
          child: Pressable(
            child: box(
              InkWell(
                key: key,
                onTap: onTap,
                child: SizedBox(
                  height: 96,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Icon(icon, color: C.green, size: 24),
                        const Spacer(),
                        Text(bnDigits(count), style: body(13, color: C.muted)),
                      ]),
                      const Spacer(),
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600, height: 1.3)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );

    Widget small(Key key, String label, IconData icon, VoidCallback onTap) => Expanded(
          child: box(
            InkWell(
              key: key,
              onTap: onTap,
              child: SizedBox(
                height: 44,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: C.muted, size: 18),
                  const SizedBox(width: 7),
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13.5, weight: FontWeight.w500))),
                ]),
              ),
            ),
            radius: 12,
          ),
        );

    // The paper that runs out soonest, within a month.
    final dated = d.docs.where((x) => x.expiry != null).toList()..sort((a, b) => a.expiry!.compareTo(b.expiry!));
    final soon = dated.where((x) => !x.expiry!.isBefore(today) && x.expiry!.difference(now).inDays <= 30).firstOrNull;
    final gone = dated.where((x) => x.expiry!.isBefore(today)).firstOrNull;
    String? warning() {
      if (gone != null) return trf('{0}-এর মেয়াদ শেষ হয়ে গেছে', [gone.title]);
      if (soon != null) {
        final days = DateTime(soon.expiry!.year, soon.expiry!.month, soon.expiry!.day).difference(today).inDays;
        return days == 0 ? trf('{0} আজ শেষ', [soon.title]) : trf('{0} {1} দিন পর শেষ', [soon.title, bnDigits(days)]);
      }
      return null;
    }

    final warn = warning();

    // Lately kept: notes, papers and people, newest first. Passwords stay
    // inside their locked page.
    final recent = <(DateTime, String, String, IconData, VoidCallback)>[
      for (final n in d.notes) (n.updatedAt, n.title, tr(n.category), Icons.description_outlined, () => push(NewItemScreen(note: n))),
      for (final x in d.docs)
        (x.updatedAt, x.title, tr('ডকুমেন্টস'), Icons.folder_outlined, () async {
          final ok = await verifyUser(context, reason: trf('{0} — দেখতে যাচাই করুন', [x.title]));
          if (ok && context.mounted) push(DocScreen(id: x.id, unlocked: true));
        }),
      for (final c in d.contacts) (c.updatedAt, c.name, tr('যোগাযোগ'), Icons.person_outline_rounded, () => push(const CallsScreen())),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    final smalls = [
      small(const Key('store-special'), tr('বিশেষ দিন'), Icons.card_giftcard_outlined, () => push(const SpecialDaysScreen())),
      small(const Key('store-health'), tr('স্বাস্থ্য'), Icons.favorite_border_rounded, () => push(const HealthScreen())),
      if (!medicalOff) small(const Key('store-emergency'), tr('জরুরি কার্ড'), Icons.emergency_outlined, () => push(const EmergencyScreen())),
      small(const Key('store-tags'), tr('ট্যাগ'), Icons.sell_outlined, () => push(const TagsScreen())),
    ];
    Widget row(List<Widget> ws) => Row(children: [
          for (final (i, w) in ws.indexed) ...[if (i > 0) const SizedBox(width: 8), w],
        ]);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        TabTitle(tr('আমার ফাইল')),
        const SizedBox(height: 12),
        Material(
          color: C.surface2,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => push(const SearchScreen()),
            child: SizedBox(
              height: 46,
              child: Row(children: [
                const SizedBox(width: 13),
                Icon(Icons.search_rounded, color: C.muted, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(tr('খুঁজুন'), style: body(14.5, color: C.muted))),
                IconButton(tooltip: tr('বলে খুঁজুন'), onPressed: () => openVoice(context), icon: Icon(Icons.mic_none_rounded, color: C.muted, size: 21)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          tile(const Key('store-notes'), trm('নোট'), d.notes.length, Icons.description_outlined, () => push(const NotesScreen())),
          const SizedBox(width: 10),
          tile(const Key('store-vault'), trm('পাসওয়ার্ড'), d.vault.length, Icons.key_outlined, () => push(const VaultPage())),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          tile(const Key('store-docs'), tr('ডকুমেন্টস'), d.docs.length, Icons.folder_outlined, () => push(const DocsScreen())),
          const SizedBox(width: 10),
          tile(const Key('store-contacts'), tr('যোগাযোগ'), d.contacts.length, Icons.person_outline_rounded, () => push(const CallsScreen())),
        ]),
        const SizedBox(height: 10),
        if (smalls.length <= 3)
          row(smalls)
        else ...[
          row(smalls.sublist(0, 2)),
          const SizedBox(height: 8),
          row(smalls.sublist(2)),
        ],
        const SizedBox(height: 10),
        // The papers' end dates: a quiet row, or a warm one when one runs out.
        Material(
          color: warn != null ? C.warnBg : C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: warn != null ? C.warnBorder : C.border)),
          child: InkWell(
            key: const Key('store-expiry'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => push(const ExpiryScreen()),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 12, 11),
              child: Row(children: [
                Icon(warn != null ? Icons.error_outline_rounded : Icons.event_outlined, color: warn != null ? C.warn : C.muted, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(warn ?? tr('কাগজের মেয়াদ'), maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: body(13.5, weight: FontWeight.w500, color: warn != null ? C.orangeDark : C.ink)),
                ),
                if (warn != null)
                  Text(tr('দেখুন'), style: body(13.5, weight: FontWeight.w700, color: C.warn))
                else ...[
                  if (dated.isNotEmpty) Text(bnDigits(dated.length), style: body(13.5, color: C.muted)),
                  Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
                ],
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 0, 4),
          child: Row(children: [
            Expanded(child: Text(tr('সম্প্রতি'), style: body(13, weight: FontWeight.w600, color: C.muted))),
            TextButton.icon(
              onPressed: () => push(const NewItemScreen(category: ItemCategory.note)),
              icon: Icon(Icons.add_rounded, size: 18, color: C.green),
              label: Text(tr('নতুন'), style: body(13.5, weight: FontWeight.w600, color: C.green)),
            ),
          ]),
        ),
        box(
          recent.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(tr('এখনো কোনো নোট নেই। সহকারীকে বলুন — “মনে রাখো: গাড়ির কাগজ আলমারিতে”।'), style: body(14, color: C.muted, height: 1.5)),
                )
              : Column(children: [
                  for (final (i, r) in recent.take(4).indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 60, color: C.border),
                    InkWell(
                      onTap: r.$5,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Row(children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(10)),
                            child: Icon(r.$4, color: C.ink, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(r.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, weight: FontWeight.w500)),
                              Text(r.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Text(relativeDay(r.$1, now), style: body(12.5, color: C.muted)),
                        ]),
                      ),
                    ),
                  ],
                ]),
        ),
      ],
    );
  }
}
