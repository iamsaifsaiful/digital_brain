import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../state/brain.dart';
import '../ui/note_parts.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import 'calls_screen.dart';
import 'docs_screen.dart';
import 'home_shell.dart';
import 'library_screen.dart';
import 'new_item_screen.dart';
import 'health_hub.dart';
import 'inbox_screen.dart';
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
    final recent = ([...d.notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt))).take(6).toList();
    final now = brain.services.now();
    // The paper whose expiry is nearest, if it ends within a month (or ended lately).
    final soon = (d.docs.where((x) => x.expiry != null && dayOnly(x.expiry!).difference(dayOnly(now)).inDays.abs() <= 30).toList()
          ..sort((a, b) => a.expiry!.compareTo(b.expiry!)))
        .firstOrNull;

    // fg/bg kept in the calls; the new look is one calm colour, the vault dark.
    Widget tile(String label, String sub, IconData icon, Color fg, Color bg, VoidCallback onTap, {bool dark = false}) => Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: C.shadow),
          child: Material(
            color: dark ? C.fill : C.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: C.dark ? BorderSide(color: dark ? C.fillEdge : C.line) : BorderSide.none),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(children: [
                  IconSquare(icon, size: 42, bg: dark ? Colors.white.withValues(alpha: 0.12) : null, color: dark ? Colors.white : null),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600, color: dark ? Colors.white : C.ink)),
                      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: dark ? Colors.white.withValues(alpha: 0.7) : C.muted)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        );

    final tiles = [
      tile(tr('নোট'), trf('{0}টি', [bnDigits(d.notes.length)]), Icons.sticky_note_2_outlined, C.ochre, C.ochreTint, () => push(const NotesScreen())),
      tile(tr('ডকুমেন্টস'), trf('{0}টি · তালাবদ্ধ', [bnDigits(d.docs.length)]), Icons.folder_copy_outlined, C.blue, C.blueTint, () => push(const DocsScreen())),
      tile(tr('পাসওয়ার্ড'), trf('{0}টি · তালাবদ্ধ', [bnDigits(d.vault.length)]), Icons.key_rounded, C.ink, C.soft, () => push(const VaultPage()), dark: true),
      tile(tr('যোগাযোগ'), trf('{0} জন', [bnDigits(d.contacts.length)]), Icons.call_outlined, C.purple, C.purpleTint, () => push(const CallsScreen())),
      tile(tr('স্বাস্থ্য'), tr('BMI, প্রেশার, সুগার, টিকা'), Icons.favorite_border_rounded, C.rose, C.roseTint, () => push(const HealthScreen())),
      if (brain.inboxSupported) tile(tr('মেসেজ থেকে কাজ'), tr('WhatsApp, imo, Gmail, SMS'), Icons.mark_chat_unread_outlined, C.green, C.greenTint, () => push(const InboxScreen())),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(tr('সংরক্ষণ'), style: heading(28))),
          Padding(padding: const EdgeInsets.only(top: 4), child: HandNote(tr('সব এক জায়গায়'), size: 13, arrow: HandArrow.downLeft, rotate: 6)),
        ]),
        Row(children: [
          Icon(Icons.lock_outline_rounded, size: 14, color: C.muted),
          const SizedBox(width: 4),
          Flexible(child: Text(tr('আপনার সব দরকারি জিনিস, এই ফোনে তালাবদ্ধ'), style: body(13, color: C.muted))),
        ]),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), boxShadow: C.shadow),
          child: Material(
            color: C.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: C.dark ? BorderSide(color: C.line) : BorderSide.none),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => push(const SearchScreen()),
              child: SizedBox(
                height: 54,
                child: Row(children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search_rounded, color: C.muted, size: 22),
                  const SizedBox(width: 10),
                  Expanded(child: Text(tr('নোট, নম্বর, পাসওয়ার্ড খুঁজুন…'), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, color: C.muted))),
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: Material(
                      color: C.soft,
                      borderRadius: BorderRadius.circular(12),
                      child: IconButton(tooltip: tr('বলে খুঁজুন'), onPressed: () => openVoice(context), icon: Icon(Icons.mic_none_rounded, color: C.ink)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
        if (soon != null) ...[
          const SizedBox(height: 12),
          Material(
            color: C.warnTint,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              key: const Key('store-expiry-soon'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => push(const ExpiryScreen()),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: C.warn),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                          dayOnly(soon.expiry!).isBefore(dayOnly(now))
                              ? trf('{0} — মেয়াদ শেষ হয়ে গেছে', [soon.title])
                              : trf('{0} — মেয়াদের {1}', [soon.title, daysLeftLabel(soon.expiry!, now)]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(14.5, weight: FontWeight.w600)),
                      Text(fullDate(soon.expiry!), style: body(12.5, color: C.muted2)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.muted2),
                ]),
              ),
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
          child: Row(children: [
            Expanded(child: Text(tr('সব কিছু'), style: heading(18))),
            Text(trf('{0}টা ভাগ', [bnDigits(tiles.length)]), style: body(13, color: C.muted)),
          ]),
        ),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.3,
          children: tiles,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final (label, icon, page) in [
              (tr('জরুরি কার্ড'), Icons.emergency_outlined, const EmergencyScreen() as Widget),
              (tr('কাগজের মেয়াদ'), Icons.event_busy_outlined, const ExpiryScreen() as Widget),
              (tr('ট্যাগ'), Icons.sell_outlined, const TagsScreen() as Widget),
              (tr('বিশেষ দিন'), Icons.cake_outlined, const SpecialDaysScreen() as Widget),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: C.surface,
                  shape: StadiumBorder(side: BorderSide(color: C.line)),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => push(page),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, size: 18, color: C.muted2),
                        const SizedBox(width: 6),
                        Text(label, style: body(13.5, weight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        Material(
          color: C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: C.dark ? BorderSide(color: C.line) : BorderSide.none),
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
          padding: const EdgeInsets.fromLTRB(2, 18, 0, 6),
          child: Row(children: [
            Expanded(child: Text(tr('সম্প্রতি রাখা নোট'), style: heading(18))),
            TextButton(
              onPressed: () => push(const NewItemScreen(category: ItemCategory.note)),
              style: TextButton.styleFrom(foregroundColor: C.muted),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(tr('নতুন'), style: body(14, weight: FontWeight.w500, color: C.muted)),
                const SizedBox(width: 2),
                Icon(Icons.add_rounded, size: 18, color: C.muted),
              ]),
            ),
          ]),
        ),
        if (recent.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
            child: Text(tr('এখনো কোনো নোট নেই। সহকারীকে বলুন — “মনে রাখো: গাড়ির কাগজ আলমারিতে”।'), style: body(14, color: C.muted, height: 1.5)),
          )
        else
          SizedBox(
            height: 132,
            child: ListView(clipBehavior: Clip.none, scrollDirection: Axis.horizontal, children: [
              for (final n in recent)
                Padding(
                  padding: const EdgeInsets.only(right: 10, bottom: 4),
                  child: Container(
                    width: 168,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: C.shadow),
                    child: Material(
                      color: C.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: C.dark ? BorderSide(color: C.line) : BorderSide.none),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => push(NewItemScreen(note: n)),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Expanded(child: Text(notePreview(n), maxLines: 2, overflow: TextOverflow.ellipsis, style: body(13, color: C.muted2, height: 1.4))),
                            Text('${shortDate(n.updatedAt)} · ${n.category}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
      ],
    );
  }
}
