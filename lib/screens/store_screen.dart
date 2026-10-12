import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import 'calls_screen.dart';
import 'docs_screen.dart';
import 'home_shell.dart';
import 'library_screen.dart';
import 'new_item_screen.dart';
import 'notes_screen.dart';
import 'search_screen.dart';
import 'vault_screen.dart';

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
        Text('সংরক্ষণ', style: display(24, weight: 700)),
        Text('আপনার সব দরকারি জিনিস, এই ফোনে তালাবদ্ধ', style: body(13.5, color: C.muted)),
        const SizedBox(height: 12),
        Material(
          color: C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: C.line)),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => push(const SearchScreen()),
            child: SizedBox(
              height: 46,
              child: Row(children: [
                const SizedBox(width: 16),
                const Icon(Icons.search_rounded, color: C.muted, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('নোট, নম্বর, পাসওয়ার্ড খুঁজুন…', style: body(14.5, color: C.muted))),
                IconButton(tooltip: 'বলে খুঁজুন', onPressed: () => openVoice(context), icon: const Icon(Icons.mic_none_rounded, color: C.green)),
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
            tile('নোট', '${bnDigits(d.notes.length)}টি', Icons.sticky_note_2_outlined, C.ochre, C.ochreTint, () => push(const NotesScreen())),
            tile('ডকুমেন্টস', '${bnDigits(d.docs.length)}টি · তালাবদ্ধ', Icons.folder_copy_outlined, C.blue, C.blueTint, () => push(const DocsScreen())),
            tile('পাসওয়ার্ড', '${bnDigits(d.vault.length)}টি · তালাবদ্ধ', Icons.lock_outline_rounded, C.ink, const Color(0xFFF1F2F4), () => push(const VaultPage())),
            tile('যোগাযোগ', '${bnDigits(d.contacts.length)} জন', Icons.call_outlined, C.purple, C.purpleTint, () => push(const CallsScreen())),
          ],
        ),
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
                const Icon(Icons.folder_open_outlined, color: C.muted2),
                const SizedBox(width: 12),
                Expanded(child: Text('সব তথ্য ও নিজের বিভাগ · ${bnDigits(d.noteCategories.length)}টি', style: body(15, weight: FontWeight.w500))),
                const Icon(Icons.chevron_right_rounded, color: C.muted),
              ]),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Row(children: [
            Expanded(child: Text('সম্প্রতি রাখা নোট', style: body(13, weight: FontWeight.w600, color: C.muted))),
            TextButton.icon(
              onPressed: () => push(const NewItemScreen(category: ItemCategory.note)),
              icon: const Icon(Icons.add_rounded, size: 18, color: C.green),
              label: Text('নতুন', style: body(14, weight: FontWeight.w600, color: C.green)),
            ),
          ]),
        ),
        Container(
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: recent.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('এখনো কোনো নোট নেই। সহকারীকে বলুন — “মনে রাখো: গাড়ির কাগজ আলমারিতে”।', style: body(14, color: C.muted, height: 1.5)),
                )
              : Column(children: [
                  for (final (i, n) in recent.indexed) ...[
                    if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14, color: C.line),
                    InkWell(
                      onTap: () => push(NewItemScreen(note: n)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                        child: Row(children: [
                          Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: C.ochreTint, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.sticky_note_2_outlined, color: C.ochre, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600)),
                              Text('${n.category} · ${n.body.replaceAll('\n', ' ')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: C.muted),
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
