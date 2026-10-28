import '../logic/repeat_text.dart';
import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'new_item_screen.dart';
import 'vault_item_screen.dart';
import '../logic/lang.dart';
import '../ui/pdf_export.dart';
import '../ui/pick.dart';

/// Dates to remember, grouped: this month, later, past.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, this.highlightId});
  final String? highlightId;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _picks = Picks();

  @override
  void initState() {
    super.initState();
    _picks.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _picks.dispose();
    super.dispose();
  }

  List<PickAction> _actions(Brain brain) {
    final picked = [
      for (final r in brain.data.reminders)
        if (_picks.has(r.id)) r
    ];
    final anyOn = picked.any((r) => r.enabled);
    return [
      PickAction(anyOn ? Icons.notifications_off_outlined : Icons.notifications_active_outlined, anyOn ? tr('বন্ধ করুন') : tr('চালু করুন'), () async {
        for (final r in picked) {
          await brain.saveReminder(r.copyWith(enabled: !anyOn));
        }
        _picks.clear();
      }),
      PickAction(Icons.delete_outline_rounded, tr('মুছুন'), danger: true, () async {
        final messenger = ScaffoldMessenger.of(context);
        if (!await confirmDialog(context, title: trf('{0}টা রিমাইন্ডার মুছবেন?', [bnDigits(picked.length)]), text: tr('৩০ দিন “মুছে ফেলা”-তে থাকবে।'), yes: tr('মুছুন'), danger: true)) return;
        for (final r in picked) {
          await brain.deleteReminder(r.id);
        }
        _picks.clear();
        deletedSnack(messenger, picked.length, () => brain.undoLastDeletes(picked.length));
      }),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final highlightId = widget.highlightId;
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final today = dayOnly(now);
    final all = [...brain.data.reminders]..sort((a, b) => a.nextDate(now).compareTo(b.nextDate(now)));
    final highlighted = highlightId == null ? null : brain.reminderById(highlightId);
    final rest = all.where((r) => r.id != highlighted?.id).toList();
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final thisMonth = rest.where((r) => !r.nextDate(now).isBefore(today) && r.nextDate(now).isBefore(monthEnd)).toList();
    final later = rest.where((r) => !r.nextDate(now).isBefore(monthEnd)).toList();
    final past = rest.where((r) => r.nextDate(now).isBefore(today)).toList();

    void edit(Reminder r) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewItemScreen(reminder: r)));

    _picks.keepOnly(all.map((r) => r.id));
    final picking = _picks.on;

    Widget row(Reminder r) {
      final d = r.nextDate(now);
      return ListRow(
        key: Key('rem-${r.id}'),
        picked: _picks.has(r.id),
        onLongPress: () => _picks.toggle(r.id),
        leading: picking ? PickMark(_picks.has(r.id)) : DateBlock(top: bnDigits(d.day), bottom: monthShort(d.month)),
        title: r.title,
        subtitle: [
          weekdayShort(d),
          if (r.repeat != Repeat.none) repeatText(r),
          if (d.year != now.year) bnDigits(d.year),
          if (!r.enabled) tr('বন্ধ'),
          if (r.note.isNotEmpty) r.note,
        ].join(' · '),
        trailing: Text(daysLeftLabel(d, now), style: body(13, color: C.muted)),
        onTap: picking ? () => _picks.toggle(r.id) : () => edit(r),
      );
    }

    List<Widget> group(String title, List<Reminder> list) => list.isEmpty
        ? const []
        : [
            Padding(padding: const EdgeInsets.only(top: 16, bottom: 8), child: Text(title, style: body(15, weight: FontWeight.w600))),
            Panel(child: Rows(children: [for (final r in list) row(r)])),
          ];

    return PopScope(
      canPop: !picking,
      onPopInvokedWithResult: (did, _) {
        if (!did) _picks.clear();
      },
      child: Scaffold(
        bottomNavigationBar: picking ? PickBar(picks: _picks, all: all.map((r) => r.id), actions: _actions(brain)) : null,
        body: SafeArea(
          child: Column(
            children: [
              TopBar(title: tr('তারিখ ও রিমাইন্ডার'), trailing: const [
                PdfButton({ReportPart.reminders})
              ]),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  children: [
                    if (highlighted != null) _Highlight(reminder: highlighted, onEdit: () => edit(highlighted)),
                    if (all.isEmpty)
                      EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: tr('কোনো তারিখ রাখা নেই'),
                        text: tr('বিল দেওয়ার দিন, মেয়াদ শেষ হওয়ার দিন বা অ্যাপয়েন্টমেন্ট রাখুন — সময়মতো মনে করিয়ে দেওয়া হবে।'),
                      ),
                    ...group(tr('এই মাসে'), thisMonth),
                    ...group(tr('পরে'), later),
                    ...group(tr('পার হয়ে গেছে'), past),
                  ],
                ),
              ),
              if (!picking)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: PrimaryButton(
                    label: tr('নতুন রিমাইন্ডার'),
                    icon: Icons.add_rounded,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.reminder))),
                  ),
                ),
            ],
          ),
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
            Icon(Icons.notifications_none_rounded, size: 18, color: C.muted2),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                at.isAfter(now) ? trf('মনে করাবে: {0}, {1}', [shortDate(at), bnTime(at.hour, at.minute)]) : tr('মনে করানোর সময় পার হয়েছে'),
                style: body(14, color: C.muted2),
              ),
            ),
          ]),
          if (v != null)
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 40)),
              onPressed: () async {
                final ok = await verifyUser(context, reason: trf('{0} — তথ্য দেখতে যাচাই করুন', [v.name]));
                if (ok && context.mounted) {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => VaultItemScreen(id: v.id)));
                }
              },
              icon: Icon(Icons.lock_outline_rounded, size: 16, color: C.green),
              label: Text(trf('সাথে যুক্ত: {0}', [v.name]), style: body(14, weight: FontWeight.w600, color: C.green)),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onEdit, child: Text(tr('বদলান'), style: body(14, weight: FontWeight.w600, color: C.green))),
          ),
        ],
      ),
    );
  }
}
