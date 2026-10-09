import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/ledger.dart';
import '../logic/parser.dart';
import '../logic/phrases.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ledger_form_screen.dart';
import 'person_screen.dart';

enum _Filter {
  all('সব'),
  gave('দিলাম'),
  took('নিলাম'),
  back('ফেরত ও শোধ');

  const _Filter(this.label);
  final String label;

  bool keeps(LedgerKind k) => switch (this) {
        _Filter.all => true,
        _Filter.gave => k == LedgerKind.lent,
        _Filter.took => k == LedgerKind.borrowed,
        _Filter.back => k == LedgerKind.received || k == LedgerKind.repaid,
      };
}

/// Every transaction, by month, with search and filters.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  _Filter _filter = _Filter.all;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final q = normalize(_q);
    final list = newestFirst(brain.data.ledger).where((e) {
      if (!_filter.keeps(e.kind)) return false;
      if (q.isEmpty) return true;
      return normalize('${e.person} ${e.note} ${e.amount} ${e.kind.label}').contains(q);
    }).toList();

    // Group by month.
    final groups = <String, List<LedgerEntry>>{};
    for (final e in list) {
      groups.putIfAbsent('${e.date.year}-${e.date.month}', () => []).add(e);
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'সব লেনদেন'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'নাম বা পরিমাণ দিয়ে খুঁজুন'),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final f in _Filter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f.label, style: body(14, weight: f == _filter ? FontWeight.w600 : FontWeight.w400, color: f == _filter ? Colors.white : C.ink)),
                        selected: f == _filter,
                        showCheckmark: false,
                        selectedColor: C.ink,
                        backgroundColor: C.surface,
                        side: BorderSide(color: f == _filter ? C.ink : C.border),
                        shape: const StadiumBorder(),
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? ListView(children: const [
                      EmptyState(icon: Icons.receipt_long_outlined, title: 'কিছু পাওয়া যায়নি', text: 'অন্য নাম দিয়ে খুঁজুন বা ফিল্টার বদলান।'),
                    ])
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        for (final g in groups.values) ...[
                          _MonthHeader(entries: g),
                          Panel(
                            child: Rows(children: [for (final e in g) _EntryRow(entry: e, brain: brain)]),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text('বাঁ দিকে টানলে মুছে যায় · চাপলে সংশোধন', style: body(13, color: C.muted), textAlign: TextAlign.center),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.entries});
  final List<LedgerEntry> entries;

  @override
  Widget build(BuildContext context) {
    final gave = entries.where((e) => e.kind == LedgerKind.lent).fold<int>(0, (s, e) => s + e.amount);
    final took = entries.where((e) => e.kind == LedgerKind.borrowed).fold<int>(0, (s, e) => s + e.amount);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(monthTitle(entries.first.date), style: body(15, weight: FontWeight.w600))),
          Flexible(child: Text('দিয়েছেন ${taka(gave)} · নিয়েছেন ${taka(took)}', style: body(13, color: C.muted), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.brain});
  final LedgerEntry entry;
  final Brain brain;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final kindColor = switch (e.kind) {
      LedgerKind.received => C.green,
      LedgerKind.borrowed => C.orange,
      _ => C.muted,
    };
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: C.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.delete_outline_rounded, color: Colors.white),
          const SizedBox(width: 6),
          Text('মুছুন', style: body(14, color: Colors.white, weight: FontWeight.w600)),
        ]),
      ),
      onDismissed: (_) => deleteEntryWithUndo(context, brain, e),
      child: ListRow(
        leading: DateBlock(top: bnDigits(e.date.day), bottom: weekdayShort(e.date)),
        title: e.person,
        subtitle: e.note.isEmpty ? e.kind.label : '${e.kind.label} · ${e.note}',
        subtitleColor: kindColor,
        trailing: Text('${e.kind.outflow ? '−' : '+'}${taka(e.amount)}', style: display(17)),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text('${possessive(e.person)} হিসাব দেখুন'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PersonScreen(person: e.person)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('সংশোধন করুন'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => LedgerFormScreen(entry: e)));
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: C.red),
                title: Text('মুছে ফেলুন', style: body(16, color: C.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  deleteEntryWithUndo(context, brain, e);
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
