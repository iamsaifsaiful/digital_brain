import 'package:flutter/material.dart';

import '../logic/pro.dart';
import '../ui/pro_gate.dart';

import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/ledger.dart' show projectDueTotals;
import '../logic/parser.dart' show normalize;
import '../logic/money_more.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/forms.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../logic/lang.dart';
import '../ui/pdf_export.dart';
import '../ui/pick.dart';
import 'project_dues.dart';
import 'to_main.dart';

/// White card: one big figure ("এই মাসের ব্যালেন্স") and two under it.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.title, required this.amount, required this.items, this.negative = false});
  final String title;
  final int amount;

  /// Shows the big figure with a minus, in amber.
  final bool negative;
  final List<(String, int, Color)> items;

  @override
  Widget build(BuildContext context) => Panel(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: body(14, color: C.muted)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('${negative ? '−' : ''}${taka(amount)}', style: display(34, weight: 700, color: negative ? C.orange : C.ink, height: 1.2)),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(children: [
            for (final (i, it) in items.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: Figure(label: it.$1, amount: taka(it.$2), color: it.$3, size: 18)),
            ],
          ]),
        ]),
      );
}

/// "এখন কত টাকা আছে": asked once at the top of আয়-ব্যয়; after that it
/// shows the money now, moved by every income and spending (owner, 24 Oct).
class CashNowCard extends StatefulWidget {
  const CashNowCard({super.key});

  @override
  State<CashNowCard> createState() => _CashNowCardState();
}

class _CashNowCardState extends State<CashNowCard> {
  final _amount = TextEditingController();

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save(Brain brain, String text) async {
    final v = readInt(text);
    if (v == null || v < 0) return;
    await brain.setCashOnHand(v);
    _amount.clear();
    if (mounted) FocusScope.of(context).unfocus();
  }

  Future<void> _change(Brain brain, int now) async {
    final v = await showDialog<String>(context: context, builder: (_) => _AmountDialog(initial: now));
    if (v != null) await _save(brain, v);
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = cashOnHand(brain.data);
    if (now != null) {
      return Panel(
        key: const Key('cash-now'),
        padding: EdgeInsets.zero,
        child: InkWell(
          key: const Key('cash-now-open'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CashNowScreen())),
          child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('এখন আছে'), style: body(13.5, color: C.muted)),
              Text('${now < 0 ? '−' : ''}${taka(now.abs())}', style: display(24, weight: 700, color: now < 0 ? C.orange : C.ink)),
            ]),
          ),
          TextButton(key: const Key('cash-now-change'), onPressed: () => _change(brain, now), child: Text(tr('নতুন করে দিন'))),
          Icon(Icons.chevron_right_rounded, color: C.muted),
        ]),
          ),
        ),
      );
    }
    return Panel(
      key: const Key('cash-now-ask'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('এখন আপনার কাছে কত টাকা আছে?'), style: body(15.5, weight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(tr('হাতে, ব্যাংকে, বিকাশে — সব মিলিয়ে লিখুন। এরপর আয়, খরচ, ধার আর অন্যান্য হিসাবের খরচ লিখলে নিজে বাড়বে-কমবে।'), style: body(13, color: C.muted, height: 1.45)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('cash-now-field'),
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(prefixText: '৳ ', hintText: tr('যেমন ১২,০০০'), isDense: true),
              onSubmitted: (v) => _save(brain, v),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(key: const Key('cash-now-save'), onPressed: () => _save(brain, _amount.text), child: Text(tr('রাখুন'))),
        ]),
      ]),
    );
  }
}

/// "এখন কত টাকা আছে?" — the box lives as long as the dialog.
class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.initial});
  final int initial;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final _c = TextEditingController(text: bnDigits('${widget.initial}'));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(tr('এখন কত টাকা আছে?'), style: display(19)),
        content: TextField(
          key: const Key('cash-now-edit'),
          controller: _c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(prefixText: '৳ ', helperText: tr('এখন থেকে নতুন করে হিসাব শুরু হবে'), helperMaxLines: 2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('বাতিল'))),
          TextButton(onPressed: () => Navigator.pop(context, _c.text), child: Text(tr('রাখুন'))),
        ],
      );
}

/// How "এখন আছে" came to be: the amount said and when, every kind of line
/// since with its sum, and the lines themselves (owner, 24 Oct).
class CashNowScreen extends StatelessWidget {
  const CashNowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final start = cashStartOf(brain.data);
    final now = cashOnHand(brain.data);
    final lines = [...cashSinceStart(brain.data)]..sort((a, b) => (b.addedAt ?? b.date).compareTo(a.addedAt ?? a.date));
    Widget row(String label, int v, {bool bold = false, Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(children: [
            Expanded(child: Text(label, style: body(15, weight: bold ? FontWeight.w700 : FontWeight.w400))),
            Text('${v < 0 ? '−' : (bold ? '' : '+')}${taka(v.abs())}', style: display(15.5, weight: bold ? 700 : 600, color: bold ? C.ink : (v < 0 ? C.ink : C.green))),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('এখন আছে কীভাবে হলো')),
          Expanded(
            child: start == null || now == null
                ? Padding(padding: const EdgeInsets.all(20), child: Text(tr('এখনো “এখন আছে” দেওয়া হয়নি।'), style: body(15, color: C.muted)))
                : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                    Panel(
                      key: const Key('cash-now-parts'),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Column(children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(children: [
                            Expanded(child: Text(trf('শুরুতে ছিল ({0})', [fullDate(start.$2)]), style: body(15))),
                            Text(taka(start.$1), style: display(15.5, weight: 600)),
                          ]),
                        ),
                        for (final (label, v) in cashNowParts(brain.data)) row(tr(label), v),
                        const Divider(height: 18),
                        row(tr('এখন আছে'), now, bold: true, key: const Key('cash-now-total')),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Text(tr('ধার দিলে ব্যয়ে দেখায়, ধার নিলে আয়ে — খরচ বা আয় নয়, টাকা আসা-যাওয়া। অন্যান্য হিসাবের খরচ এখান থেকেই যায়; বকেয়া পেলে আয়ে আসে।'),
                        style: body(12.5, color: C.muted, height: 1.5)),
                    if (lines.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SectionTitle(trf('এর পরের লেনদেন · {0}টি', [bnDigits(lines.length)])),
                      Panel(child: Rows(children: [for (final e in lines) cashRow(context, e)])),
                    ],
                  ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── আয়-ব্যয় (monthly) ─────────────────────────

/// One month of the user's own income and spending.
class CashView extends StatefulWidget {
  const CashView({super.key});

  @override
  State<CashView> createState() => _CashViewState();
}

class _CashViewState extends State<CashView> {
  DateTime? _month;
  final _picks = Picks();
  PersistentBottomSheetController? _bar;
  List<String> _shown = const [];

  @override
  void initState() {
    super.initState();
    _picks.addListener(_onPicks);
  }

  @override
  void dispose() {
    _picks.removeListener(_onPicks);
    _bar?.close();
    _picks.dispose();
    super.dispose();
  }

  /// The pick bar lives in the page's Scaffold (this view sits inside other pages).
  void _onPicks() {
    if (!mounted) return;
    setState(() {});
    if (_picks.on && _bar == null) {
      final bar = Scaffold.of(context).showBottomSheet(
        (ctx) => ListenableBuilder(
          listenable: _picks,
          builder: (ctx, _) => cashPickBar(ctx, _picks, _shown),
        ),
        enableDrag: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
      );
      _bar = bar;
      bar.closed.then((_) {
        if (_bar == bar) _bar = null;
        if (mounted) _picks.clear();
      });
    } else if (!_picks.on && _bar != null) {
      final bar = _bar;
      _bar = null;
      bar?.close();
    }
  }

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final m = _month ?? DateTime(now.year, now.month);
    final isThisMonth = m.year == now.year && m.month == now.month;
    final sums = monthSums(brain.data.cash, m);
    final entries = brain.data.cash.where((e) => e.projectId == null && e.date.year == m.year && e.date.month == m.month).toList()..sort((a, b) => b.date.compareTo(a.date));
    _shown = [for (final e in entries) e.id];
    _picks.keepOnly(_shown);
    final top = sums.topExpenses;
    final maxCat = top.isEmpty ? 1 : top.first.value;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const CashNowCard(),
      const SizedBox(height: 12),
      Row(children: [
        IconButton(
          tooltip: tr('আগের মাস'),
          onPressed: () {
            _picks.clear();
            setState(() => _month = DateTime(m.year, m.month - 1));
          },
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(child: Text('${monthName(m.month)} ${bnDigits(m.year)}', textAlign: TextAlign.center, style: display(18))),
        IconButton(
          tooltip: tr('পরের মাস'),
          onPressed: isThisMonth
              ? null
              : () {
                  _picks.clear();
                  setState(() => _month = DateTime(m.year, m.month + 1));
                },
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ]),
      const SizedBox(height: 6),
      SummaryCard(
        title: isThisMonth ? tr('এই মাসের ব্যালেন্স') : tr('মাসের ব্যালেন্স'),
        amount: sums.balance.abs(),
        negative: sums.balance < 0,
        items: [(tr('আয়'), sums.income, C.green), (tr('খরচ'), sums.expense, C.ink)],
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: PrimaryButton(
            label: tr('আয়'),
            icon: Icons.add_rounded,
            height: 48,
            onPressed: () => _push(const CashFormScreen(kind: CashKind.income)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PrimaryButton(
            label: tr('খরচ'),
            icon: Icons.add_rounded,
            height: 48,
            color: C.fill,
            onPressed: () => _push(const CashFormScreen(kind: CashKind.expense)),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Text(tr('মুখেও বলা যায়: “বাজারে ৫০০ টাকা খরচ হলো”, “বেতন পেলাম ৩০ হাজার”'), style: body(13, color: C.muted)),
      const SizedBox(height: 16),
      if (top.isNotEmpty) ...[
        SectionTitle(tr('খাত অনুযায়ী খরচ')),
        Panel(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            for (final c in top)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(c.key, style: body(15, weight: FontWeight.w600))),
                    Text(taka(c.value), style: display(15)),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: c.value / maxCat, minHeight: 6, color: C.green, backgroundColor: C.surface2),
                  ),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 16),
      ],
      if (entries.isEmpty)
        EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: tr('এই মাসে কিছু লেখা নেই'),
          text: tr('বাজার, ভাড়া, বিল, বেতন — নিজের আয় আর খরচ এখানে রাখুন। মাস শেষে কত জমলো, এক নজরে দেখবেন।'),
        )
      else ...[
        SectionTitle(isThisMonth ? tr('এই মাসের হিসাব') : tr('মাসের হিসাব')),
        if (!_picks.on && entries.length > 1)
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(tr('চেপে ধরে কয়েকটা বেছে একসাথে মুছা বা খাত বদলানো যায়'), style: body(12, color: C.muted))),
        Panel(child: Rows(children: [for (final e in entries) cashRow(context, e, picks: _picks)])),
      ],
    ]);
  }
}

Widget cashRow(BuildContext context, CashEntry e, {Picks? picks}) {
  final income = e.kind == CashKind.income;
  final picking = picks != null && picks.on;
  return ListRow(
    key: Key('cash-${e.id}'),
    picked: picks?.has(e.id) ?? false,
    onLongPress: picks == null ? null : () => picks.toggle(e.id),
    leading: picking
        ? PickMark(picks.has(e.id))
        : Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: income ? C.greenTint : C.surface2, borderRadius: BorderRadius.circular(12)),
            child: Icon(income ? Icons.south_west_rounded : Icons.north_east_rounded, color: income ? C.green : C.muted2, size: 20),
          ),
    title: e.category,
    subtitle: [shortDate(e.date), if (e.note.trim().isNotEmpty) e.note.trim()].join(' · ') + (e.projectId == null ? '' : mainMark(BrainScope.of(context).data, e.id)),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('${income ? '+' : '−'}${taka(e.amount)}', style: body(14.5, weight: FontWeight.w600, color: income ? C.green : C.ink)),
      if (!picking)
        IconButton(
          tooltip: tr('বদলান বা মুছুন'),
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.more_vert_rounded, color: C.muted, size: 20),
          onPressed: () => cashActions(context, e),
        ),
    ]),
    onTap: picking ? () => picks.toggle(e.id) : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CashFormScreen(entry: e, kind: e.kind, projectId: e.projectId))),
  );
}

/// What can be done with several picked incomes/expenses at once.
Widget cashPickBar(BuildContext context, Picks picks, Iterable<String> shown) {
  final brain = BrainScope.read(context);
  final picked = [
    for (final e in brain.data.cash)
      if (picks.has(e.id)) e
  ];
  final income = picked.where((e) => e.kind == CashKind.income).fold<int>(0, (a, e) => a + e.amount);
  final expense = picked.where((e) => e.kind == CashKind.expense).fold<int>(0, (a, e) => a + e.amount);
  return PickBar(
    picks: picks,
    all: shown,
    note: [
      if (income > 0) trf('আয় {0}', [taka(income)]),
      if (expense > 0) trf('খরচ {0}', [taka(expense)])
    ].join(' · '),
    actions: [
      PickAction(Icons.label_outline_rounded, tr('খাত বদলান'), () async {
        final kind = picked.every((e) => e.kind == CashKind.income) ? CashKind.income : CashKind.expense;
        final cat = await askCategory(context, knownCategories(brain.data, kind));
        if (cat == null || cat.isEmpty) return;
        for (final e in picked) {
          await brain.saveCash(CashEntry(id: e.id, kind: e.kind, amount: e.amount, category: cat, note: e.note, date: e.date, projectId: e.projectId, accountId: e.accountId, shopId: e.shopId, linkId: e.linkId));
        }
        picks.clear();
      }),
      PickAction(Icons.share_outlined, tr('পাঠান'), () async {
        final lines = [
          for (final e in picked) '${shortDate(e.date)} · ${e.category}${e.note.trim().isEmpty ? '' : ' (${e.note.trim()})'} · ${e.kind == CashKind.income ? '+' : '−'}${taka(e.amount)}',
          if (income > 0) trf('মোট আয় {0}', [taka(income)]),
          if (expense > 0) trf('মোট খরচ {0}', [taka(expense)]),
        ];
        await brain.services.files.shareText(lines.join('\n'));
      }),
      PickAction(Icons.delete_outline_rounded, tr('মুছুন'), danger: true, () async {
        final messenger = ScaffoldMessenger.of(context);
        if (!await confirmDialog(context, title: trf('{0}টা হিসাব মুছবেন?', [bnDigits(picked.length)]), text: tr('৩০ দিন “মুছে ফেলা”-তে থাকবে।'), yes: tr('মুছুন'), danger: true)) return;
        for (final e in picked) {
          await brain.deleteCash(e.id);
        }
        picks.clear();
        deletedSnack(messenger, picked.length, () => brain.undoLastDeletes(picked.length));
      }),
    ],
  );
}

/// A খাত for picked entries: one of [known] or a new one.
Future<String?> askCategory(BuildContext context, List<String> known) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('কোন খাতে?'), style: display(20)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 6, runSpacing: 6, children: [for (final k in known.take(16)) ActionChip(label: Text(k), onPressed: () => Navigator.pop(ctx, k))]),
          const SizedBox(height: 10),
          TextField(controller: c, decoration: InputDecoration(labelText: tr('নতুন খাত'))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? null : c.text.trim()), child: Text(tr('ঠিক আছে'))),
      ],
    ),
  );
}

/// ⋮ on an income/expense: change it, or delete it (with a few seconds to take it back).
Future<void> cashActions(BuildContext context, CashEntry e) async {
  final brain = BrainScope.read(context);
  final line = mainMenuLine(brain.data, e.id);
  final pick = await editOrDelete(context, title: '${e.category} · ${taka(e.amount)}', extra: line == null ? null : (line.$1, line.$2, 'main'));
  if (!context.mounted) return;
  if (pick == 'main') return toggleMain(context, e.id);
  if (pick == 'edit') {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CashFormScreen(entry: e, kind: e.kind, projectId: e.projectId)));
  } else if (pick == 'delete') {
    final ok = await confirmDialog(context, title: tr('মুছবেন?'), text: trf('{0} — {1} মুছে যাবে।', [e.category, taka(e.amount)]), yes: tr('মুছুন'), danger: true);
    if (!ok) return;
    await brain.deleteCash(e.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(tr('মুছে দিলাম — ৩০ দিন “মুছে ফেলা”-তে থাকবে')),
          persist: false,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: tr('ফিরিয়ে আনুন'), onPressed: () => brain.undoLastDelete()),
        ));
    }
  }
}

/// আয়-ব্যয় as its own page (opened from the chat).
class CashPage extends StatelessWidget {
  const CashPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            TopBar(title: tr('আয়-ব্যয়'), trailing: const [
              PdfButton({ReportPart.money})
            ]),
            Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: const [CashView()])),
          ]),
        ),
      );
}

// ───────────────────────── Projects ─────────────────────────

Future<String?> askProjectName(BuildContext context, {String initial = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(initial.isEmpty ? tr('নতুন হিসাব') : tr('হিসাবের নাম'), style: display(20)),
      content: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: tr('নাম, যেমন: রহিম ভবন'))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(tr('ঠিক আছে'))),
      ],
    ),
  );
}

/// A new project or event: a name (or a ready one — ঈদ, বিয়ে…) and, if
/// wanted, a budget. Returns (name, budget).
Future<(String, int)?> askNewProject(BuildContext context) {
  final name = TextEditingController();
  final budget = TextEditingController();
  return showDialog<(String, int)>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(tr('নতুন হিসাব'), style: display(20)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in [tr('ঈদের খরচ'), tr('বিয়ের আয়োজন'), tr('জন্মদিনের আয়োজন'), tr('কুরবানি'), tr('বাড়ি মেরামত'), tr('ভ্রমণ')])
                ActionChip(label: Text(t), onPressed: () => setD(() => name.text = t)),
            ]),
            const SizedBox(height: 10),
            TextField(controller: name, decoration: InputDecoration(labelText: tr('নাম, যেমন: রহিম ভবন'))),
            const SizedBox(height: 10),
            TextField(controller: budget, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('বাজেট (ঐচ্ছিক)'), prefixText: '৳ ')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, (name.text.trim(), int.tryParse(asciiDigits(budget.text).replaceAll(RegExp(r'[,\s]'), '')) ?? 0)),
            child: Text(tr('ঠিক আছে')),
          ),
        ],
      ),
    ),
  );
}

class ProjectsView extends StatelessWidget {
  const ProjectsView({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final open = d.projects.where((p) => !p.closed).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final closed = d.projects.where((p) => p.closed).toList();
    var inTotal = 0, outTotal = 0;
    for (final p in open) {
      final s = projectSums(d.cash, p.id);
      inTotal += s.income;
      outTotal += s.expense;
    }

    Future<void> create() async {
      if (!await needPro(context, ProFeature.projects, allowed: brain.canAddProject) || !context.mounted) return;
      final r = await askNewProject(context);
      if (r == null || r.$1.isEmpty || !context.mounted) return;
      var p = await brain.projectNamed(r.$1);
      if (r.$2 > 0) {
        p = p.copyWith(budget: r.$2);
        await brain.saveProject(p);
      }
      if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProjectScreen(id: p.id)));
    }

    // বকেয়া right from this tab: one হিসাব → straight in; several → which
    // one; none → name one first (দোকান, ব্যবসা…).
    Future<void> addDue() async {
      if (!await needPro(context, ProFeature.projects) || !context.mounted) return;
      Project? target;
      if (open.length == 1) {
        target = open.first;
      } else if (open.isEmpty) {
        if (!await needPro(context, ProFeature.projects, allowed: brain.canAddProject) || !context.mounted) return;
        final name = await askProjectName(context, initial: tr('দোকান'));
        if (name == null || name.trim().isEmpty || !context.mounted) return;
        target = await brain.projectNamed(name.trim());
      } else {
        target = await showAppSheet<Project>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
              Text(tr('কোন হিসাবে বকেয়া?'), style: display(19, weight: 700)),
              const SizedBox(height: 12),
              Panel(
                child: Rows(children: [
                  for (final p in open)
                    ListRow(
                      leading: Icon(Icons.work_outline_rounded, color: C.blue),
                      title: p.name,
                      onTap: () => Navigator.pop(ctx, p),
                    ),
                ]),
              ),
            ]),
          ),
        );
      }
      if (target == null || !context.mounted) return;
      await dueForm(context, target);
    }

    Widget row(Project p) {
      final s = projectSums(d.cash, p.id);
      final (owed, _) = projectDueTotals(d, p.id);
      final sub = p.budget > 0 ? trf('বাজেট {0} · খরচ {1}', [taka(p.budget), taka(s.expense)]) : trf('এসেছে {0} · খরচ {1}', [taka(s.income), taka(s.expense)]);
      return ListRow(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: C.blueTint, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.work_outline_rounded, color: C.blue, size: 20),
        ),
        title: p.name,
        subtitle: owed > 0 ? '$sub · ${trf('বকেয়া {0}', [taka(owed)])}' : sub,
        trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(taka(s.balance.abs()), style: display(16, color: s.balance >= 0 ? C.green : C.orange)),
          Text(s.balance >= 0 ? tr('অবশিষ্ট') : tr('বেশি খরচ'), style: body(12, color: C.muted)),
        ]),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProjectScreen(id: p.id))),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SummaryCard(
        title: tr('চলমান হিসাবগুলোতে হাতে আছে'),
        amount: (inTotal - outTotal).abs(),
        negative: inTotal < outTotal,
        items: [(tr('মোট এসেছে'), inTotal, C.green), (tr('মোট খরচ'), outTotal, C.ink)],
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: PrimaryButton(label: tr('নতুন হিসাব'), icon: Icons.add_rounded, height: 48, color: C.fill, onPressed: create)),
        const SizedBox(width: 8),
        Expanded(child: PrimaryButton(key: const Key('due-add-top'), label: tr('বকেয়া যোগ'), icon: Icons.receipt_long_outlined, height: 48, onPressed: addDue)),
      ]),
      const SizedBox(height: 8),
      Text(tr('মুখেও বলা যায়: “রহিম ভবন প্রজেক্টে ৫০ হাজার টাকা এলো”, “রহিম ভবন প্রজেক্টে রড কিনলাম ২০ হাজার”'), style: body(13, color: C.muted)),
      const SizedBox(height: 16),
      AllDuesSection(projects: [...open, ...closed]),
      if (open.isNotEmpty || closed.isNotEmpty) const SizedBox(height: 16),
      if (open.isEmpty && closed.isEmpty)
        EmptyState(
          icon: Icons.work_outline_rounded,
          title: tr('অন্যান্য কোনো হিসাব নেই'),
          text: tr('বাড়ি বানানো, দোকান, অফিসের কাজ, কোনো অর্ডার — প্রতিটার আলাদা আয়-ব্যয় আর বকেয়া রাখুন। কত এলো, কত গেল, কে কত বাকি দেখবেন।'),
        )
      else ...[
        if (open.isNotEmpty) ...[
          SectionTitle(tr('চলমান হিসাব')),
          Panel(child: Rows(children: [for (final p in open) row(p)])),
        ],
        if (closed.isNotEmpty) ...[
          const SizedBox(height: 16),
          SectionTitle(tr('শেষ হওয়া হিসাব')),
          Panel(child: Rows(children: [for (final p in closed) row(p)])),
        ],
      ],
    ]);
  }
}

class ProjectScreen extends StatelessWidget {
  const ProjectScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final p = brain.data.projects.where((x) => x.id == id).firstOrNull;
    if (p == null) {
      return Scaffold(body: SafeArea(child: Column(children: [TopBar(title: tr('অন্যান্য হিসাব'))])));
    }
    final s = projectSums(brain.data.cash, p.id);
    final entries = brain.data.cash.where((e) => e.projectId == p.id).toList()..sort((a, b) => b.date.compareTo(a.date));
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    Future<void> menu(String v) async {
      switch (v) {
        case 'rename':
          final name = await askProjectName(context, initial: p.name);
          if (name != null && name.isNotEmpty) await brain.saveProject(p.copyWith(name: name));
        case 'budget':
          final c = TextEditingController(text: p.budget > 0 ? '${p.budget}' : '');
          final v = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(tr('বাজেট'), style: display(20)),
              content: TextField(controller: c, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(prefixText: '৳ ')),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
                TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(tr('ঠিক আছে'))),
              ],
            ),
          );
          if (v != null) await brain.saveProject(p.copyWith(budget: int.tryParse(asciiDigits(v).replaceAll(RegExp(r'[,\s]'), '')) ?? 0));
        case 'close':
          await brain.saveProject(p.copyWith(closed: !p.closed));
        case 'delete':
          final ok = await confirmDialog(context, title: tr('এই হিসাব মুছবেন?'), text: trf('‘{0}’ আর এর সব আয়-ব্যয় ও বকেয়া মুছে যাবে।', [p.name]), yes: tr('মুছুন'), danger: true);
          if (!ok) return;
          await brain.deleteProject(p.id);
          if (context.mounted) Navigator.of(context).pop();
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: p.name, trailing: [
            PdfButton(const {ReportPart.projects}, scope: ReportScope(projectId: p.id), title: p.name),
            PopupMenuButton<String>(
              tooltip: tr('আরও'),
              onSelected: menu,
              itemBuilder: (_) => [
                PopupMenuItem(value: 'rename', child: Text(tr('নাম বদলান'))),
                PopupMenuItem(value: 'budget', child: Text(p.budget > 0 ? tr('বাজেট বদলান') : tr('বাজেট ঠিক করুন'))),
                PopupMenuItem(value: 'close', child: Text(p.closed ? tr('আবার চালু করুন') : tr('হিসাব শেষ'))),
                PopupMenuItem(value: 'delete', child: Text(tr('মুছুন'))),
              ],
            ),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              SummaryCard(
                title: s.balance >= 0 ? tr('হাতে আছে') : tr('বেশি খরচ হয়েছে'),
                amount: s.balance.abs(),
                negative: s.balance < 0,
                items: [(tr('মোট এসেছে'), s.income, C.green), (tr('মোট খরচ'), s.expense, C.ink)],
              ),
              if (p.budget > 0) ...[
                const SizedBox(height: 10),
                Panel(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                        s.expense <= p.budget
                            ? trf('বাজেট {0} · বাকি {1}', [taka(p.budget), taka(p.budget - s.expense)])
                            : trf('বাজেট {0} · {1} বেশি খরচ', [taka(p.budget), taka(s.expense - p.budget)]),
                        style: body(15, weight: FontWeight.w600, color: s.expense <= p.budget ? C.ink : C.orange)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (s.expense / p.budget).clamp(0, 1).toDouble(),
                        minHeight: 10,
                        color: s.expense <= p.budget ? C.green : C.orange,
                        backgroundColor: C.chip,
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              // Another হিসাব has spending (from the main money) and বকেয়া; money
              // coming in is the main আয় (owner, 24 Oct).
              PrimaryButton(
                label: tr('খরচ'),
                icon: Icons.add_rounded,
                height: 48,
                color: C.fill,
                onPressed: () async {
                  if (await needPro(context, ProFeature.projects) && context.mounted) push(CashFormScreen(kind: CashKind.expense, projectId: p.id));
                },
              ),
              const SizedBox(height: 6),
              Text(tr('খরচ মূল টাকা থেকে যায়। এই কাজে টাকা পেলে আয়-ব্যয়ে আয় হিসেবে লিখুন; বকেয়া পেলে নিচে বকেয়া থেকে আদায় দিন।'), style: body(12.5, color: C.muted, height: 1.45)),
              const SizedBox(height: 16),
              ProjectDuesSection(project: p),
              const SizedBox(height: 16),
              if (s.byCategory.isNotEmpty) ...[
                SectionTitle(tr('খাত অনুযায়ী খরচ')),
                Panel(
                  child: Rows(children: [
                    for (final c in s.topExpenses) ListRow(leading: Icon(Icons.label_outline_rounded, color: C.muted), title: c.key, trailing: Text(taka(c.value), style: display(15))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              if (entries.isEmpty)
                EmptyState(icon: Icons.receipt_long_outlined, title: tr('এখনো কিছু লেখা নেই'), text: tr('টাকা এলে বা খরচ হলে উপরের বোতাম চাপুন, অথবা মুখে বলুন।'))
              else ...[
                SectionTitle(tr('সব হিসাব')),
                Panel(child: Rows(children: [for (final e in entries) cashRow(context, e)])),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Add / edit an entry ─────────────────────────

class CashFormScreen extends StatefulWidget {
  const CashFormScreen({super.key, this.entry, this.kind = CashKind.expense, this.projectId, this.category, this.amount, this.note, this.date, this.shopId});
  final CashEntry? entry;

  /// A sale or cost of this shop.
  final String? shopId;
  final CashKind kind;
  final String? projectId;

  /// A category to start with ("বিক্রি" from the shop page).
  final String? category;

  /// Filled in from a message (bKash SMS…).
  final int? amount;
  final String? note;
  final DateTime? date;

  @override
  State<CashFormScreen> createState() => _CashFormScreenState();
}

class _CashFormScreenState extends State<CashFormScreen> {
  late CashKind _kind = widget.entry?.kind ?? widget.kind;
  late final _amount = TextEditingController(text: widget.entry == null ? (widget.amount == null ? '' : '${widget.amount}') : '${widget.entry!.amount}');
  late final _category = TextEditingController(text: widget.entry?.category ?? widget.category ?? '');
  late String? _accountId = widget.entry != null ? widget.entry!.accountId : defaultAccountId(BrainScope.read(context).data);
  late final _note = TextEditingController(text: widget.entry?.note ?? widget.note ?? '');
  late DateTime _date = widget.entry?.date ?? widget.date ?? BrainScope.read(context).services.now();
  late String? _projectId = widget.entry?.projectId ?? widget.projectId;

  @override
  void dispose() {
    _amount.dispose();
    _category.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    final amount = int.tryParse(asciiDigits(_amount.text).replaceAll(',', '').trim()) ?? 0;
    if (amount <= 0) {
      toast(context, tr('টাকার অঙ্ক দিন'));
      return;
    }
    // No খাত picked: guess it from the note ("রিকশা" → যাতায়াত), else অন্যান্য.
    final cat = _category.text.trim().isEmpty ? categoryFor(normalize(_note.text), _kind) : _category.text.trim();
    final saved = CashEntry(
      id: widget.entry?.id,
      kind: _kind,
      amount: amount,
      category: cat,
      note: _note.text.trim(),
      date: _date,
      projectId: _projectId,
      accountId: _accountId,
      shopId: widget.entry?.shopId ?? widget.shopId,
      linkId: widget.entry?.linkId,
    );
    await brain.saveCash(saved);
    // Owner (24 Oct): another হিসাব's new entry — in the main আয়-ব্যয় too?
    // Another হিসাব's spending goes into the main money by itself: say so.
    if (widget.entry == null && _projectId != null && mounted) sayMainLine(context);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final brain = BrainScope.read(context);
    final ok = await confirmDialog(context, title: tr('মুছবেন?'), text: tr('এই হিসাবটা মুছে যাবে।'), yes: tr('মুছুন'), danger: true);
    if (!ok) return;
    await brain.deleteCash(widget.entry!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final cats = knownCategories(brain.data, _kind);
    final projects = brain.data.projects.where((p) => !p.closed || p.id == _projectId).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: widget.entry == null ? (_kind == CashKind.income ? tr('আয় যোগ') : tr('খরচ যোগ')) : tr('হিসাব বদলান'), trailing: [
            if (widget.entry != null) IconButton(tooltip: tr('মুছুন'), onPressed: _delete, icon: Icon(Icons.delete_outline_rounded, color: C.red)),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              SegTabs<CashKind>(
                items: [(CashKind.expense, tr('খরচ')), (CashKind.income, _projectId == null ? tr('আয়') : tr('টাকা এলো'))],
                value: _kind,
                onChanged: (v) => setState(() => _kind = v),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                autofocus: widget.entry == null,
                style: display(24),
                decoration: InputDecoration(labelText: tr('টাকা'), prefixText: tr('৳ ')),
              ),
              const SizedBox(height: 14),
              TextField(controller: _category, decoration: InputDecoration(labelText: tr('খাত (যেমন: বাজার, ভাড়া, বেতন)'))),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in cats.take(14))
                  ChoiceChip(
                    label: Text(c, style: body(13)),
                    selected: _category.text.trim() == c,
                    onSelected: (_) => setState(() => _category.text = c),
                  ),
              ]),
              const SizedBox(height: 14),
              TextField(controller: _note, minLines: 1, maxLines: 3, decoration: InputDecoration(labelText: tr('নোট (ইচ্ছামতো)'))),
              const SizedBox(height: 14),
              ListRow(
                leading: Icon(Icons.event_outlined, color: C.ink),
                title: fullDate(_date),
                subtitle: tr('তারিখ'),
                trailing: Icon(Icons.edit_calendar_outlined, color: C.muted),
                onTap: () async {
                  final now = brain.services.now();
                  final p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(now.year - 5), lastDate: now);
                  if (p != null) setState(() => _date = DateTime(p.year, p.month, p.day, _date.hour, _date.minute));
                },
              ),
              if (brain.data.accounts.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(_kind == CashKind.income ? tr('কোথায় এলো') : tr('কোথা থেকে গেল'), style: body(14, color: C.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final a in brain.data.accounts) ChoiceChip(label: Text(accountLabel(a), style: body(13)), selected: _accountId == a.id, onSelected: (_) => setState(() => _accountId = a.id)),
                  // "বলা নেই" only for an old entry that has none (owner, 24 Oct: every entry in an account).
                  if (widget.entry != null && widget.entry!.accountId == null)
                    ChoiceChip(label: Text(tr('বলা নেই'), style: body(13)), selected: _accountId == null, onSelected: (_) => setState(() => _accountId = null)),
                ]),
              ],
              if (projects.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(tr('কোথায় লিখব'), style: body(14, color: C.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  ChoiceChip(label: Text(tr('নিজের মাসিক হিসাব'), style: body(13)), selected: _projectId == null, onSelected: (_) => setState(() => _projectId = null)),
                  for (final p in projects) ChoiceChip(label: Text(trf('হিসাব: {0}', [p.name]), style: body(13)), selected: _projectId == p.id, onSelected: (_) => setState(() => _projectId = p.id)),
                ]),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: PrimaryButton(label: tr('রাখুন'), icon: Icons.check_rounded, onPressed: _save),
          ),
        ]),
      ),
    );
  }
}
