import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'new_item_screen.dart';
import 'vault_item_screen.dart';

/// Dates to remember, grouped: this month, later, past.
class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key, this.highlightId});
  final String? highlightId;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final today = dayOnly(now);
    final all = [...brain.data.reminders]..sort((a, b) => a.nextDate(now).compareTo(b.nextDate(now)));
    final highlighted = highlightId == null ? null : brain.reminderById(highlightId!);
    final rest = all.where((r) => r.id != highlighted?.id).toList();
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final thisMonth = rest.where((r) => !r.nextDate(now).isBefore(today) && r.nextDate(now).isBefore(monthEnd)).toList();
    final later = rest.where((r) => !r.nextDate(now).isBefore(monthEnd)).toList();
    final past = rest.where((r) => r.nextDate(now).isBefore(today)).toList();

    void edit(Reminder r) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewItemScreen(reminder: r)));

    Widget row(Reminder r) {
      final d = r.nextDate(now);
      return ListRow(
        leading: DateBlock(top: bnDigits(d.day), bottom: bnMonthsShort[d.month - 1]),
        title: r.title,
        subtitle: [
          weekdayShort(d),
          if (r.repeat != Repeat.none) r.repeat.label,
          if (d.year != now.year) bnDigits(d.year),
          if (r.note.isNotEmpty) r.note,
        ].join(' · '),
        trailing: Text(daysLeftLabel(d, now), style: body(13, color: C.muted)),
        onTap: () => edit(r),
      );
    }

    List<Widget> group(String title, List<Reminder> list) => list.isEmpty
        ? const []
        : [
            Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Text(title, style: body(15, weight: FontWeight.w600))),
            Panel(child: Rows(children: [for (final r in list) row(r)])),
          ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'তারিখ ও রিমাইন্ডার'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  if (highlighted != null) _Highlight(reminder: highlighted, onEdit: () => edit(highlighted)),
                  if (all.isEmpty)
                    const EmptyState(
                      icon: Icons.notifications_none_rounded,
                      title: 'কোনো তারিখ রাখা নেই',
                      text: 'বিল দেওয়ার দিন, মেয়াদ শেষ হওয়ার দিন বা অ্যাপয়েন্টমেন্ট রাখুন — সময়মতো মনে করিয়ে দেওয়া হবে।',
                    ),
                  ...group('এই মাসে', thisMonth),
                  ...group('পরে', later),
                  ...group('পার হয়ে গেছে', past),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: PrimaryButton(
                label: 'নতুন রিমাইন্ডার',
                icon: Icons.add_rounded,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.reminder))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({required this.reminder, required this.onEdit});
  final Reminder reminder;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final r = reminder;
    final d = r.nextDate(now);
    final at = r.notifyAt(now);
    final v = brain.vaultById(r.vaultId);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: C.orange, width: 2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.title, style: display(22)),
                  Text('${weekdayName(d)}, ${fullDate(d)}', style: body(15, color: C.muted2)),
                ]),
              ),
              Pill(daysLeftLabel(d, now), fg: C.orangeDark, bg: C.orangeTint),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.notifications_none_rounded, size: 18, color: C.muted2),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                at.isAfter(now) ? 'মনে করাবে: ${shortDate(at)}, ${bnTime(at.hour, at.minute)}' : 'মনে করানোর সময় পার হয়েছে',
                style: body(14, color: C.muted2),
              ),
            ),
          ]),
          if (v != null)
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 40)),
              onPressed: () async {
                final ok = await verifyUser(context, reason: '${v.name} — তথ্য দেখতে যাচাই করুন');
                if (ok && context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => VaultItemScreen(id: v.id)));
                }
              },
              icon: const Icon(Icons.lock_outline_rounded, size: 16, color: C.green),
              label: Text('সাথে যুক্ত: ${v.name}', style: body(14, weight: FontWeight.w600, color: C.green)),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onEdit, child: Text('বদলান', style: body(14, weight: FontWeight.w600, color: C.green))),
          ),
        ],
      ),
    );
  }
}
