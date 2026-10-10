import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'calls_screen.dart';
import 'new_item_screen.dart';
import 'notes_screen.dart';
import 'plan_screens.dart';
import 'vault_screen.dart';

/// "তথ্য": everything kept for later — people, notes, passwords, tasks —
/// as big tiles, plus the user's own categories.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final plan = planOf(d, now);
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final recent = ([...d.notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt))).take(3).toList();

    final tiles = <_Tile>[
      _Tile('যোগাযোগ', '${bnDigits(d.contacts.length)} জন', Icons.contact_phone_outlined, C.purple, C.purpleTint, () => push(const CallsScreen())),
      _Tile('নোট', '${bnDigits(d.notes.length)}টি', Icons.sticky_note_2_outlined, C.ochre, C.ochreTint, () => push(const NotesScreen())),
      _Tile('পাসওয়ার্ড', '${bnDigits(d.vault.length)}টি · তালাবদ্ধ', Icons.key_rounded, C.blue, C.blueTint, () => push(const VaultPage())),
      _Tile('রিমাইন্ডার', '${bnDigits(d.reminders.length)}টি', Icons.notifications_none_rounded, C.green, C.greenTint,
          () => push(const AllTasksScreen())),
      _Tile('সব কাজ', '${bnDigits(d.tasks.where((t) => !t.done).length)}টি বাকি', Icons.checklist_rounded, C.green, C.greenTint,
          () => push(const AllTasksScreen())),
      for (final c in d.noteCategories.where((c) => c != defaultNoteCategory))
        _Tile(c, 'নিজের বিভাগ · ${bnDigits(d.notes.where((n) => n.category == c).length)}', Icons.folder_outlined, C.orange, C.orangeTint,
            () => push(NotesScreen(category: c))),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const TabTitle('তথ্য'),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [
            for (final t in tiles) SizedBox(width: w, child: _TileView(tile: t)),
            SizedBox(
              width: w,
              height: 92,
              child: Material(
                color: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.inputBorder, width: 1.2)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => push(const NewItemScreen()),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.add_rounded, color: C.green),
                    Text('নতুন কিছু রাখুন', style: body(14, weight: FontWeight.w600, color: C.green)),
                  ]),
                ),
              ),
            ),
          ]);
        }),
        if (plan.overdue.isNotEmpty) ...[
          const SizedBox(height: 14),
          InfoBanner(
            text: '${bnDigits(plan.overdue.length)}টা কাজের দিন পার হয়ে গেছে — “সব কাজ” খুলে দেখুন।',
            icon: Icons.schedule_rounded,
            fg: C.orangeDark,
            iconColor: C.orange,
            bg: C.orangeTint,
          ),
        ],
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 18),
          const SectionTitle('সাম্প্রতিক নোট'),
          Panel(
            child: Rows(children: [
              for (final n in recent)
                ListRow(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: C.ochreTint, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.sticky_note_2_outlined, color: C.ochre, size: 20),
                  ),
                  title: n.title,
                  subtitle: n.body.replaceAll('\n', ' '),
                  onTap: () => push(NewItemScreen(note: n)),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        Text('খুঁজতে মাইকে জিজ্ঞেস করুন: “রহিমের নম্বর কত?”, “গাড়ির কাগজ কোথায় রেখেছি?”', style: body(13, color: C.muted)),
      ],
    );
  }
}

class _Tile {
  const _Tile(this.label, this.sub, this.icon, this.fg, this.bg, this.onTap);
  final String label;
  final String sub;
  final IconData icon;
  final Color fg;
  final Color bg;
  final VoidCallback onTap;
}

class _TileView extends StatelessWidget {
  const _TileView({required this.tile});
  final _Tile tile;

  @override
  Widget build(BuildContext context) => Material(
        color: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: tile.onTap,
          child: SizedBox(
            height: 92,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: tile.bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(tile.icon, color: tile.fg, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tile.label, style: body(15, weight: FontWeight.w600, height: 1.25), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(tile.sub, style: body(12, color: C.muted, height: 1.25), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}
