import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/ledger.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'contacts_screen.dart';
import 'home_shell.dart';
import 'new_item_screen.dart';
import 'notes_screen.dart';
import 'reminders_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final t = totals(d.ledger);
    final upcoming = [...d.reminders]..sort((a, b) => a.nextDate(now).compareTo(b.nextDate(now)));
    final soon = upcoming.where((r) => !r.nextDate(now).isBefore(dayOnly(now))).take(3).toList();

    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Digital Brain', style: display(22, weight: 700)),
                  Text('${weekdayName(now)}, ${bnDigits(now.day)} ${bnMonths[now.month - 1]}', style: body(13, color: C.muted)),
                ],
              ),
            ),
            RoundIconButton(icon: Icons.lock_outline_rounded, tooltip: 'এখনই লক করুন', onPressed: brain.lockNow),
          ],
        ),
        const SizedBox(height: 16),
        Material(
          color: C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: C.inputBorder)),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => openVoice(context),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, color: C.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('যেকোনো কিছু জিজ্ঞেস করুন', style: body(16, weight: FontWeight.w500)),
                        Text('“আমার Wi-Fi-এর নাম কী?”', style: body(13, color: C.muted)),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
                    child: const Icon(Icons.mic_none_rounded, color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text('আপনার তথ্য', style: display(19)),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 16) / 3;
          final tiles = [
            _Tile('পাসওয়ার্ড', '${bnDigits(d.vault.length)}টি · লক করা', Icons.key_rounded, C.blue, C.blueTint,
                () => ShellTabs.goTo(context, ShellTab.vault)),
            _Tile('যোগাযোগ', '${bnDigits(d.contacts.length)} জন', Icons.person_outline_rounded, C.purple, C.purpleTint,
                () => push(const ContactsScreen())),
            _Tile('ধার-দেনা', '${bnDigits(balances(d.ledger).length)} জনের সাথে', Icons.swap_horiz_rounded, C.green, C.greenTint,
                () => ShellTabs.goTo(context, ShellTab.ledger)),
            _Tile('নোট', '${bnDigits(d.notes.where((n) => n.category == defaultNoteCategory).length)}টি', Icons.description_outlined, C.ochre,
                C.ochreTint, () => push(const NotesScreen(category: defaultNoteCategory))),
            _Tile('রিমাইন্ডার', '${bnDigits(soon.length)}টি সামনে', Icons.notifications_none_rounded, C.orange, C.orangeTint,
                () => push(const RemindersScreen())),
            // Categories the app made from things the user said.
            for (final c in d.noteCategories.where((c) => c != defaultNoteCategory))
              _Tile(c, '${bnDigits(d.notes.where((n) => n.category == c).length)}টি', Icons.folder_outlined, C.ochre, C.ochreTint,
                  () => push(NotesScreen(category: c))),
          ];
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tile in tiles) SizedBox(width: w, child: _CategoryTile(tile: tile)),
              SizedBox(
                width: w,
                height: 104,
                child: Material(
                  color: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF9AA39E), width: 1.5)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => push(const NewItemScreen()),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_rounded, color: C.green, size: 26),
                        Text('নতুন তথ্য', style: body(14, weight: FontWeight.w600, color: C.green)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 18),
        SectionTitle('সামনের তারিখ', action: 'সব দেখুন', onAction: () => push(const RemindersScreen())),
        if (soon.isEmpty)
          Panel(
            padding: const EdgeInsets.all(16),
            child: Text('কোনো তারিখ রাখা নেই। বলুন: “১৪ অক্টোবর ডোমেইন রিনিউ” বা নতুন তথ্য থেকে রিমাইন্ডার যোগ করুন।',
                style: body(14, color: C.muted, height: 1.5)),
          )
        else
          Panel(
            child: Rows(children: [
              for (final r in soon)
                ListRow(
                  leading: DateBlock(top: bnDigits(r.nextDate(now).day), bottom: bnMonthsShort[r.nextDate(now).month - 1]),
                  title: r.title,
                  subtitle: weekdayName(r.nextDate(now)),
                  trailing: Pill(daysLeftLabel(r.nextDate(now), now), fg: C.orangeDark, bg: C.orangeTint),
                  onTap: () => push(RemindersScreen(highlightId: r.id)),
                ),
            ]),
          ),
        const SizedBox(height: 16),
        Material(
          color: C.ink,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => ShellTabs.goTo(context, ShellTab.ledger),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ধার-দেনা', style: body(13, color: C.onDarkMuted)),
                        Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: 'পাবেন '),
                            TextSpan(text: taka(t.receivable), style: display(16, color: C.mint)),
                            const TextSpan(text: ' · দেবেন '),
                            TextSpan(text: taka(t.payable), style: display(16, color: C.peach)),
                          ]),
                          style: body(15, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
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

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.tile});
  final _Tile tile;

  @override
  Widget build(BuildContext context) => Material(
        color: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: tile.onTap,
          child: SizedBox(
            height: 104,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: tile.bg, borderRadius: BorderRadius.circular(11)),
                    child: Icon(tile.icon, color: tile.fg, size: 20),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tile.label, style: body(14, weight: FontWeight.w600, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(tile.sub, style: body(12, color: C.muted, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Reminders from today on, soonest first.
List<Reminder> upcomingReminders(AppData d, DateTime now) =>
    ([...d.reminders]..sort((a, b) => a.nextDate(now).compareTo(b.nextDate(now)))).where((r) => !r.nextDate(now).isBefore(dayOnly(now))).toList();
