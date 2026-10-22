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
import '../logic/lang.dart';
import '../ui/pdf_export.dart';
import '../ui/pick.dart';

enum _Filter {
  all('সব'),
  gave('দিলাম'),
  took('নিলাম'),
  back('ফেরত ও শোধ');

  const _Filter(this._label);
  final String _label;
  String get label => tr(_label);

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
      for (final e in brain.data.ledger)
        if (_picks.has(e.id)) e
    ];
    return [
      PickAction(Icons.share_outlined, tr('পাঠান'), () async {
        await brain.services.files.shareText(picked.map((e) => '${shortDate(e.date)} · ${e.person} · ${e.kind.label} ${taka(e.amount)}${e.note.isEmpty ? '' : ' (${e.note})'}').join('\n'));
      }),
      PickAction(Icons.delete_outline_rounded, tr('মুছুন'), danger: true, () async {
        final messenger = ScaffoldMessenger.of(context);
        if (!await confirmDialog(context, title: trf('{0}টা লেনদেন মুছবেন?', [bnDigits(picked.length)]), text: tr('৩০ দিন “মুছে ফেলা”-তে থাকবে।'), yes: tr('মুছুন'), danger: true)) return;
        for (final e in picked) {
          await brain.deleteEntry(e.id);
        }
        _picks.clear();
        deletedSnack(messenger, picked.length, () => brain.undoLastDeletes(picked.length));
      }),
    ];
  }

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

    _picks.keepOnly(brain.data.ledger.map((e) => e.id));
    final picked = [
      for (final e in list)
        if (_picks.has(e.id)) e
    ];
    final out = picked.where((e) => e.kind.outflow).fold<int>(0, (a, e) => a + e.amount);
    final inn = picked.where((e) => !e.kind.outflow).fold<int>(0, (a, e) => a + e.amount);
    return PopScope(
      canPop: !_picks.on,
      onPopInvokedWithResult: (did, _) {
        if (!did) _picks.clear();
      },
      child: Scaffold(
        bottomNavigationBar: _picks.on
            ? PickBar(
                picks: _picks,
                all: list.map((e) => e.id),
                note: [
                  if (out > 0) trf('গেছে {0}', [taka(out)]),
                  if (inn > 0) trf('এসেছে {0}', [taka(inn)])
                ].join(' · '),
                actions: _actions(brain),
              )
            : null,
        body: SafeArea(
          child: Column(
            children: [
              TopBar(title: tr('সব লেনদেন'), trailing: const [
                PdfButton({ReportPart.ledger})
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: tr('নাম বা পরিমাণ দিয়ে খুঁজুন')),
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
                          label: Text(f.label, style: body(14, weight: f == _filter ? FontWeight.w600 : FontWeight.w400, color: f == _filter ? C.onInk : C.ink)),
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
                    ? ListView(children: [
                        EmptyState(icon: Icons.receipt_long_outlined, title: tr('কিছু পাওয়া যায়নি'), text: tr('অন্য নাম দিয়ে খুঁজুন বা ফিল্টার বদলান।')),
                      ])
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          for (final g in groups.values) ...[
                            _MonthHeader(entries: g),
                            Panel(
                              child: Rows(children: [for (final e in g) _EntryRow(entry: e, brain: brain, picks: _picks)]),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Text(tr('বাঁ দিকে টানলে মুছে যায় · চাপলে সংশোধন · চেপে ধরলে কয়েকটা বাছাই'), style: body(13, color: C.muted), textAlign: TextAlign.center),
                        ],
                      ),
              ),
            ],
          ),
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
          Flexible(child: Text(trf('দিয়েছেন {0} · নিয়েছেন {1}', [taka(gave), taka(took)]), style: body(13, color: C.muted), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.brain, required this.picks});
  final LedgerEntry entry;
  final Brain brain;
  final Picks picks;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final kindColor = switch (e.kind) {
      LedgerKind.received => C.green,
      LedgerKind.borrowed => C.orange,
      _ => C.muted,
    };
    final picking = picks.on;
    return Dismissible(
      key: ValueKey(e.id),
      direction: picking ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        color: C.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.delete_outline_rounded, color: Colors.white),
          const SizedBox(width: 6),
          Text(tr('মুছুন'), style: body(14, color: Colors.white, weight: FontWeight.w600)),
        ]),
      ),
      onDismissed: (_) => deleteEntryWithUndo(context, brain, e),
      child: ListRow(
        picked: picks.has(e.id),
        onLongPress: () => picks.toggle(e.id),
        leading: picking ? PickMark(picks.has(e.id)) : DateBlock(top: bnDigits(e.date.day), bottom: weekdayShort(e.date)),
        title: e.person,
        subtitle: e.note.isEmpty ? e.kind.label : '${e.kind.label} · ${e.note}',
        subtitleColor: kindColor,
        trailing: Text('${e.kind.outflow ? '−' : '+'}${taka(e.amount)}', style: display(17)),
        onTap: picking
            ? () => picks.toggle(e.id)
            : () => showAppSheet<void>(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      ListTile(
                        leading: const Icon(Icons.person_outline_rounded),
                        title: Text(trf('{0} হিসাব দেখুন', [possessive(e.person)])),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => PersonScreen(person: e.person)));
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(tr('সংশোধন করুন')),
                        onTap: () {
                          Navigator.pop(ctx);
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => LedgerFormScreen(entry: e)));
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.delete_outline_rounded, color: C.red),
                        title: Text(tr('মুছে ফেলুন'), style: body(16, color: C.red)),
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
