import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../state/brain.dart';
import '../ui/note_parts.dart';
import '../ui/theme.dart';
import 'calls_screen.dart';
import 'docs_screen.dart';
import 'home_shell.dart';
import 'library_screen.dart';
import 'new_item_screen.dart';
import 'health_hub.dart';
import 'notes_screen.dart';
import 'search_screen.dart';
import 'special_days_screen.dart';
import 'store_more_screens.dart';
import 'vault_screen.dart';
import '../logic/lang.dart';

/// সংরক্ষণ: notes, passwords, contacts and the user's own categories —
/// everything kept for later, locked on this phone.
class StoreScreen extends StatelessWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final recent = ([...d.notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt))).take(4).toList();

    Widget tile(String label, String sub, IconData icon, Color fg, Color bg, VoidCallback onTap) => Material(
          color: C.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: fg, size: 22)),
                const SizedBox(height: 10),
                Text(label, style: body(15, weight: FontWeight.w600)),
                Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
              ]),
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(tr('সংরক্ষণ'), style: display(24, weight: 700)),
        Text(tr('আপনার সব দরকারি জিনিস, এই ফোনে তালাবদ্ধ'), style: body(13.5, color: C.muted)),
        const SizedBox(height: 12),
        Material(
          color: C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: C.line)),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => push(const SearchScreen()),
            child: SizedBox(
              height: 46,
              child: Row(children: [
                const SizedBox(width: 16),
                Icon(Icons.search_rounded, color: C.muted, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(tr('নোট, নম্বর, পাসওয়ার্ড খুঁজুন…'), style: body(14.5, color: C.muted))),
                IconButton(tooltip: tr('বলে খুঁজুন'), onPressed: () => openVoice(context), icon: Icon(Icons.mic_none_rounded, color: C.green)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            tile(tr('নোট'), trf('{0}টি', [bnDigits(d.notes.length)]), Icons.sticky_note_2_outlined, C.ochre, C.ochreTint, () => push(const NotesScreen())),
            tile(tr('ডকুমেন্টস'), trf('{0}টি · তালাবদ্ধ', [bnDigits(d.docs.length)]), Icons.folder_copy_outlined, C.blue, C.blueTint, () => push(const DocsScreen())),
            tile(tr('পাসওয়ার্ড'), trf('{0}টি · তালাবদ্ধ', [bnDigits(d.vault.length)]), Icons.lock_outline_rounded, C.ink, C.soft, () => push(const VaultPage())),
            tile(tr('যোগাযোগ'), trf('{0} জন', [bnDigits(d.contacts.length)]), Icons.call_outlined, C.purple, C.purpleTint, () => push(const CallsScreen())),
            tile(tr('স্বাস্থ্য'), tr('BMI, প্রেশার, সুগার, টিকা'), Icons.favorite_border_rounded, C.rose, C.roseTint, () => push(const HealthScreen())),
          ],
        ),
        const SizedBox(height: 10),
        Row(children: [
          for (final (label, icon, fg, bg, page) in [
            (tr('জরুরি কার্ড'), Icons.emergency_outlined, C.rose, C.roseTint, const EmergencyScreen() as Widget),
            (tr('কাগজের মেয়াদ'), Icons.event_busy_outlined, C.orange, C.orangeTint, const ExpiryScreen() as Widget),
            (tr('ট্যাগ'), Icons.sell_outlined, C.green, C.greenTint, const TagsScreen() as Widget),
            (tr('বিশেষ দিন'), Icons.cake_outlined, C.purple, C.purpleTint, const SpecialDaysScreen() as Widget),
          ]) ...[
            Expanded(
              child: Material(
                color: C.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => push(page),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    child: Column(children: [
                      Container(width: 38, height: 38, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: fg, size: 20)),
                      const SizedBox(height: 6),
                      Text(label, textAlign: TextAlign.center, maxLines: 2, style: body(12, weight: FontWeight.w500, height: 1.2)),
                    ]),
                  ),
                ),
              ),
            ),
            if (label != tr('বিশেষ দিন')) const SizedBox(width: 8),
          ],
        ]),
        const SizedBox(height: 10),
        Material(
          color: C.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => push(const MenuPage(child: LibraryScreen())),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(children: [
                Icon(Icons.folder_open_outlined, color: C.muted2),
                const SizedBox(width: 12),
                Expanded(child: Text(trf('সব তথ্য ও নিজের বিভাগ · {0}টি', [bnDigits(d.noteCategories.length)]), style: body(15, weight: FontWeight.w500))),
                Icon(Icons.chevron_right_rounded, color: C.muted),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Row(children: [
            Expanded(child: Text(tr('সম্প্রতি রাখা নোট'), style: body(13, weight: FontWeight.w600, color: C.muted))),
            TextButton.icon(
              onPressed: () => push(const NewItemScreen(category: ItemCategory.note)),
              icon: Icon(Icons.add_rounded, size: 18, color: C.green),
              label: Text(tr('নতুন'), style: body(14, weight: FontWeight.w600, color: C.green)),
            ),
          ]),
        ),
        Container(
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: recent.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(tr('এখনো কোনো নোট নেই। সহকারীকে বলুন — “মনে রাখো: গাড়ির কাগজ আলমারিতে”।'), style: body(14, color: C.muted, height: 1.5)),
                )
              : Column(children: [
                  for (final (i, n) in recent.indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: C.line),
                    InkWell(
                      onTap: () => push(NewItemScreen(note: n)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                        child: Row(children: [
                          Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: C.ochreTint, borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.sticky_note_2_outlined, color: C.ochre, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600)),
                              Text('${n.category} · ${notePreview(n)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
                            ]),
                          ),
                          Icon(Icons.chevron_right_rounded, color: C.muted),
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
