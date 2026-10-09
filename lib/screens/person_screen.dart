import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/ledger.dart';
import '../logic/phrases.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ledger_form_screen.dart';

/// One person's account: balance, totals and every transaction.
class PersonScreen extends StatefulWidget {
  const PersonScreen({super.key, required this.person});
  final String person;

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  late String _person = widget.person;

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Future<void> _rename(Brain brain) async {
    final c = TextEditingController(text: _person);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('নাম বদলান', style: display(20)),
        content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'নাম')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('সেভ করুন')),
        ],
      ),
    );
    if (r == null || r.isEmpty || r == _person) return;
    final k = personKey(_person);
    for (final e in [...brain.data.ledger]) {
      if (personKey(e.person) == k) await brain.saveEntry(e.copyWith(person: r));
    }
    setState(() => _person = r);
  }

  Future<void> _rowMenu(Brain brain, LedgerEntry e) async {
    final r = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('সংশোধন করুন'), onTap: () => Navigator.pop(ctx, 'edit')),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: C.red),
            title: Text('মুছে ফেলুন', style: body(16, color: C.red)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    if (r == 'edit') _push(LedgerFormScreen(entry: e));
    if (r == 'delete') await deleteEntryWithUndo(context, brain, e);
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final p = balanceOf(brain.data.ledger, _person);
    final rows = runningFor(brain.data.ledger, _person).reversed.toList();
    final bal = p?.balance ?? 0;
    final (fg, bg) = balanceColors(bal);
    final given = (p?.lentTotal ?? 0) + (p?.repaidTotal ?? 0);
    final got = (p?.receivedTotal ?? 0) + (p?.borrowedTotal ?? 0);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: '', trailing: [
              RoundIconButton(icon: Icons.edit_outlined, tooltip: 'নাম বদলান', onPressed: p == null ? null : () => _rename(brain)),
            ]),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Row(children: [
                    Avatar(name: _person, fg: fg, bg: bg, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_person, style: display(28, weight: 700)),
                        if (p != null && p.first != null)
                          Text('${shortDate(p.first!)} থেকে · ${bnDigits(p.count)}টি লেনদেন', style: body(14, color: C.muted)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(balanceHeading(_person, bal), style: body(14, weight: FontWeight.w600, color: bal < 0 ? C.orangeDark : C.greenDark)),
                      Text(taka(bal), style: display(40, weight: 700, color: bal == 0 ? C.muted2 : fg, height: 1.15)),
                      Text('মোট দিয়েছেন ${taka(given)} · পেয়েছেন ${taka(got)}', style: body(14, color: C.muted2)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: SecondaryButton(
                        label: bal < 0 ? 'শোধ করলাম' : 'আরও দিলাম',
                        icon: bal < 0 ? Icons.check_rounded : Icons.add_rounded,
                        onPressed: () => _push(LedgerFormScreen(person: _person, kind: bal < 0 ? LedgerKind.repaid : LedgerKind.lent)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SecondaryButton(
                        label: bal < 0 ? 'আরও নিলাম' : 'ফেরত পেলাম',
                        icon: bal < 0 ? Icons.add_rounded : Icons.check_rounded,
                        onPressed: () => _push(LedgerFormScreen(person: _person, kind: bal < 0 ? LedgerKind.borrowed : LedgerKind.received)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  const SectionTitle('লেনদেনের ইতিহাস'),
                  if (rows.isEmpty)
                    Panel(padding: const EdgeInsets.all(16), child: Text('এই নামে কোনো লেনদেন নেই।', style: body(14, color: C.muted)))
                  else
                    Panel(
                      child: Rows(children: [
                        for (final (e, after) in rows)
                          InkWell(
                            onTap: () => _rowMenu(brain, e),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                              child: Row(children: [
                                DateBlock(top: bnDigits(e.date.day), bottom: bnMonthsShort[e.date.month - 1]),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text('${e.kind.label} ${taka(e.amount)}', style: body(15, weight: FontWeight.w600)),
                                    Text(
                                      after == 0 ? 'হিসাব শূন্য' : 'বাকি ${taka(after)} ${after > 0 ? 'পাবেন' : 'দেবেন'}',
                                      style: body(13, weight: FontWeight.w600, color: balanceColor(after)),
                                    ),
                                    if (e.note.isNotEmpty) Text(e.note, style: body(13, color: C.muted)),
                                  ]),
                                ),
                                IconButton(
                                  tooltip: 'সংশোধন বা মুছুন',
                                  onPressed: () => _rowMenu(brain, e),
                                  icon: const Icon(Icons.more_vert_rounded, color: C.muted),
                                ),
                              ]),
                            ),
                          ),
                      ]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deletes with an "undo" on the snackbar.
Future<void> deleteEntryWithUndo(BuildContext context, Brain brain, LedgerEntry e) async {
  await brain.deleteEntry(e.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('${e.person}: ${e.kind.label} ${taka(e.amount)} মুছে ফেলা হয়েছে'),
      action: SnackBarAction(label: 'ফিরিয়ে আনুন', textColor: C.mint, onPressed: () => brain.saveEntry(e)),
    ));
}
