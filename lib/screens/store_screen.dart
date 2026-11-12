import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../state/brain.dart';
import '../ui/note_parts.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart' show TabTitle, ListRow;
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
    final recent = ([...d.notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt))).take(4).toList();

    // Owner, 3 Nov (approved design): the three used most as big cards on
    // their own colour, the rest in one list with what each is for.
    Widget big(Key key, String label, int count, String sub, IconData icon, Color fg, Color bg, VoidCallback onTap) => Expanded(
          child: Pressable(
          child: Material(
            key: key,
            color: bg,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: SizedBox(
                height: 128,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 10, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(12)),
                      child: Icon(icon, color: fg, size: 21),
                    ),
                    const Spacer(),
                    Text(bnDigits(count), style: display(22, weight: 700, color: fg, height: 1.1)),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w700, height: 1.3)),
                    Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11, color: C.muted, height: 1.3)),
                  ]),
                ),
              ),
            ),
          ),
          ),
        );
    Widget item(Key key, String label, String sub, IconData icon, Color fg, Color bg, VoidCallback onTap, {int? count, bool warn = false}) => ListRow(
          key: key,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: fg, size: 20),
          ),
          title: label,
          subtitle: sub,
          subtitleColor: warn ? C.warn : null,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (count != null) Text(bnDigits(count), style: body(14, weight: FontWeight.w700, color: warn ? C.warn : C.ink)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: C.muted),
          ]),
          onTap: onTap,
        );
    // The paper that runs out soonest, within a month.
    final now = brain.services.now();
    final dated = d.docs.where((x) => x.expiry != null).toList()..sort((a, b) => a.expiry!.compareTo(b.expiry!));
    final soon = dated.where((x) => !x.expiry!.isBefore(DateTime(now.year, now.month, now.day)) && x.expiry!.difference(now).inDays <= 30).firstOrNull;
    final gone = dated.where((x) => x.expiry!.isBefore(DateTime(now.year, now.month, now.day))).firstOrNull;
    String expirySub() {
      if (gone != null) return trf('{0}-এর মেয়াদ শেষ হয়ে গেছে', [gone.title]);
      if (soon != null) {
        final days = DateTime(soon.expiry!.year, soon.expiry!.month, soon.expiry!.day).difference(DateTime(now.year, now.month, now.day)).inDays;
        return days == 0 ? trf('{0} আজ শেষ', [soon.title]) : trf('{0} {1} দিন পর শেষ', [soon.title, bnDigits(days)]);
      }
      return tr('পাসপোর্ট, লাইসেন্স — শেষ হওয়ার আগে মনে করাবে');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        TabTitle(tr('আমার তথ্য'), sub: tr('আপনার সব দরকারি জিনিস, এই ফোনে তালাবদ্ধ')),
        const SizedBox(height: 14),
        Material(
          color: C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: C.border)),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () => push(const SearchScreen()),
            child: SizedBox(
              height: 48,
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
        const SizedBox(height: 12),
        Row(children: [
          big(const Key('store-notes'), trm('নোট'), d.notes.length, tr('সব লেখা'), Icons.sticky_note_2_outlined, C.ochre, C.ochreTint, () => push(const NotesScreen())),
          const SizedBox(width: 10),
          big(const Key('store-vault'), trm('পাসওয়ার্ড'), d.vault.length, tr('তালাবদ্ধ'), Icons.key_outlined, C.blue, C.blueTint, () => push(const VaultPage())),
          const SizedBox(width: 10),
          big(const Key('store-docs'), tr('ডকুমেন্টস'), d.docs.length, tr('তালাবদ্ধ'), Icons.folder_copy_outlined, C.teal, C.tealTint, () => push(const DocsScreen())),
        ]),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: C.border)),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: Column(children: [
              for (final (i, w) in [
                item(const Key('store-contacts'), tr('যোগাযোগ'), tr('নাম বললেই ফোন, মেসেজ'), Icons.call_outlined, C.purple, C.purpleTint, () => push(const CallsScreen()), count: d.contacts.length),
                item(const Key('store-special'), tr('বিশেষ দিন'), tr('জন্মদিন, বিবাহবার্ষিকী'), Icons.cake_outlined, C.rose, C.roseTint, () => push(const SpecialDaysScreen()), count: d.specialDays.length),
                item(const Key('store-expiry'), tr('কাগজের মেয়াদ'), expirySub(), Icons.event_busy_outlined, C.ochre, C.ochreTint, () => push(const ExpiryScreen()),
                    count: dated.length, warn: soon != null || gone != null),
                item(const Key('store-health'), tr('স্বাস্থ্য'), medicalOff ? tr('BMI, ওজন, পানি, হাঁটা, ঘুম') : tr('BMI, প্রেশার, সুগার, টিকা'), Icons.favorite_border_rounded, C.rose, C.roseTint,
                    () => push(const HealthScreen())),
                if (!medicalOff) item(const Key('store-emergency'), tr('জরুরি কার্ড'), tr('রক্তের গ্রুপ, জরুরি নম্বর'), Icons.emergency_outlined, C.red, C.roseTint, () => push(const EmergencyScreen())),
                item(const Key('store-tags'), tr('ট্যাগ'), tr('সব জিনিস নিজের মতো সাজান'), Icons.sell_outlined, C.teal, C.tealTint, () => push(const TagsScreen())),
              ].indexed) ...[
                if (i > 0) Divider(height: 1, indent: 64, endIndent: 14, color: C.border),
                w,
              ],
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
          child: Row(children: [
            Expanded(child: Text(tr('সম্প্রতি রাখা নোট'), style: display(17, weight: 600))),
            TextButton.icon(
              onPressed: () => push(const NewItemScreen(category: ItemCategory.note)),
              icon: Icon(Icons.add_rounded, size: 18, color: C.green),
              label: Text(tr('নতুন'), style: body(14, weight: FontWeight.w600, color: C.green)),
            ),
          ]),
        ),
        Container(
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: C.border)),
          clipBehavior: Clip.antiAlias,
          child: recent.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(tr('এখনো কোনো নোট নেই। সহকারীকে বলুন — “মনে রাখো: গাড়ির কাগজ আলমারিতে”।'), style: body(14, color: C.muted, height: 1.5)),
                )
              : Column(children: [
                  for (final (i, n) in recent.indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: C.border),
                    InkWell(
                      onTap: () => push(NewItemScreen(note: n)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                        child: Row(children: [
                          Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(12)),
                              child: Icon(Icons.description_outlined, color: C.green, size: 20)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w500)),
                              Text('${tr(n.category)} · ${notePreview(n)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted)),
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
