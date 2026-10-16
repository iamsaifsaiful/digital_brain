import 'package:flutter/material.dart';

import '../logic/pro.dart';
import '../ui/pro_gate.dart';

import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/money_more.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/forms.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../logic/lang.dart';
import '../ui/pdf_export.dart';

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

// ───────────────────────── আয়-ব্যয় (monthly) ─────────────────────────

/// One month of the user's own income and spending.
class CashView extends StatefulWidget {
  const CashView({super.key});

  @override
  State<CashView> createState() => _CashViewState();
}

class _CashViewState extends State<CashView> {
  DateTime? _month;

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final m = _month ?? DateTime(now.year, now.month);
    final isThisMonth = m.year == now.year && m.month == now.month;
    final sums = monthSums(brain.data.cash, m);
    final entries = brain.data.cash.where((e) => e.projectId == null && e.date.year == m.year && e.date.month == m.month).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final top = sums.topExpenses;
    final maxCat = top.isEmpty ? 1 : top.first.value;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        IconButton(
          tooltip: tr('আগের মাস'),
          onPressed: () => setState(() => _month = DateTime(m.year, m.month - 1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(child: Text('${monthName(m.month)} ${bnDigits(m.year)}', textAlign: TextAlign.center, style: display(18))),
        IconButton(
          tooltip: tr('পরের মাস'),
          onPressed: isThisMonth ? null : () => setState(() => _month = DateTime(m.year, m.month + 1)),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ]),
      const SizedBox(height: 6),
      SummaryCard(
        title: isThisMonth ? tr('এই মাসের ব্যালেন্স') : tr('মাসের ব্যালেন্স'),
        amount: sums.balance.abs(),
        negative: sums.balance < 0,
        items: [(tr('আয়'), sums.income, C.green), (tr('খরচ'), sums.expense, C.orange)],
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
                    child: LinearProgressIndicator(value: c.value / maxCat, minHeight: 7, color: C.orange, backgroundColor: C.orangeTint),
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
        Panel(child: Rows(children: [for (final e in entries) cashRow(context, e)])),
      ],
    ]);
  }
}

Widget cashRow(BuildContext context, CashEntry e) {
  final income = e.kind == CashKind.income;
  return ListRow(
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: income ? C.greenTint : C.orangeTint, borderRadius: BorderRadius.circular(12)),
      child: Icon(income ? Icons.south_west_rounded : Icons.north_east_rounded, color: income ? C.green : C.orange, size: 20),
    ),
    title: e.category,
    subtitle: [shortDate(e.date), if (e.note.trim().isNotEmpty) e.note.trim()].join(' · '),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('${income ? '+' : '−'}${taka(e.amount)}', style: display(16, color: income ? C.green : C.orange)),
      IconButton(
        tooltip: tr('বদলান বা মুছুন'),
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.more_vert_rounded, color: C.muted, size: 20),
        onPressed: () => cashActions(context, e),
      ),
    ]),
    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CashFormScreen(entry: e, kind: e.kind, projectId: e.projectId))),
  );
}

/// ⋮ on an income/expense: change it, or delete it (with a few seconds to take it back).
Future<void> cashActions(BuildContext context, CashEntry e) async {
  final brain = BrainScope.read(context);
  final pick = await editOrDelete(context, title: '${e.category} · ${taka(e.amount)}');
  if (!context.mounted) return;
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
          content: Text(tr('মুছে দিলাম')),
          action: SnackBarAction(label: tr('ফিরিয়ে আনুন'), onPressed: () => brain.saveCash(e)),
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
            TopBar(title: tr('আয়-ব্যয়'), trailing: const [PdfButton({ReportPart.money})]),
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
      title: Text(initial.isEmpty ? tr('নতুন আলাদা হিসাব') : tr('হিসাবের নাম'), style: display(20)),
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
        title: Text(tr('নতুন আলাদা হিসাব'), style: display(20)),
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

    Widget row(Project p) {
      final s = projectSums(d.cash, p.id);
      return ListRow(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: C.blueTint, borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.work_outline_rounded, color: C.blue, size: 20),
        ),
        title: p.name,
        subtitle: p.budget > 0 ? trf('বাজেট {0} · খরচ {1}', [taka(p.budget), taka(s.expense)]) : trf('এসেছে {0} · খরচ {1}', [taka(s.income), taka(s.expense)]),
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
        items: [(tr('মোট এসেছে'), inTotal, C.green), (tr('মোট খরচ'), outTotal, C.orange)],
      ),
      const SizedBox(height: 12),
      PrimaryButton(label: tr('নতুন আলাদা হিসাব'), icon: Icons.add_rounded, height: 48, color: C.fill, onPressed: create),
      const SizedBox(height: 8),
      Text(tr('মুখেও বলা যায়: “রহিম ভবন প্রজেক্টে ৫০ হাজার টাকা এলো”, “রহিম ভবন প্রজেক্টে রড কিনলাম ২০ হাজার”'),
          style: body(13, color: C.muted)),
      const SizedBox(height: 16),
      if (open.isEmpty && closed.isEmpty)
        EmptyState(
          icon: Icons.work_outline_rounded,
          title: tr('কোনো আলাদা হিসাব নেই'),
          text: tr('বাড়ি বানানো, অফিসের কাজ, কোনো অর্ডার — প্রতিটার আলাদা আয়-ব্যয় রাখুন। কত এলো, কত গেল, কত থাকলো দেখবেন।'),
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
      return Scaffold(body: SafeArea(child: Column(children: [TopBar(title: tr('আলাদা হিসাব'))])));
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
          final ok = await confirmDialog(context,
              title: tr('এই হিসাব মুছবেন?'), text: trf('‘{0}’ আর এর সব আয়-ব্যয় মুছে যাবে।', [p.name]), yes: tr('মুছুন'), danger: true);
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
                items: [(tr('মোট এসেছে'), s.income, C.green), (tr('মোট খরচ'), s.expense, C.orange)],
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
              Row(children: [
                Expanded(
                  child: PrimaryButton(
                    label: tr('টাকা এলো'),
                    icon: Icons.add_rounded,
                    height: 48,
                    onPressed: () => push(CashFormScreen(kind: CashKind.income, projectId: p.id)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    label: tr('খরচ'),
                    icon: Icons.add_rounded,
                    height: 48,
                    color: C.fill,
                    onPressed: () => push(CashFormScreen(kind: CashKind.expense, projectId: p.id)),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              if (s.byCategory.isNotEmpty) ...[
                SectionTitle(tr('খাত অনুযায়ী খরচ')),
                Panel(
                  child: Rows(children: [
                    for (final c in s.topExpenses)
                      ListRow(leading: Icon(Icons.label_outline_rounded, color: C.muted), title: c.key, trailing: Text(taka(c.value), style: display(15))),
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
  late String? _accountId = widget.entry?.accountId ?? BrainScope.read(context).data.accounts.firstOrNull?.id;
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
    final cat = _category.text.trim().isEmpty ? (_kind == CashKind.income ? tr('অন্যান্য আয়') : tr('অন্যান্য')) : _category.text.trim();
    await brain.saveCash(CashEntry(
      id: widget.entry?.id,
      kind: _kind,
      amount: amount,
      category: cat,
      note: _note.text.trim(),
      date: _date,
      projectId: _projectId,
      accountId: _accountId,
      shopId: widget.entry?.shopId ?? widget.shopId,
    ));
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
                  for (final a in brain.data.accounts)
                    ChoiceChip(label: Text(accountLabel(a), style: body(13)), selected: _accountId == a.id, onSelected: (_) => setState(() => _accountId = a.id)),
                  ChoiceChip(label: Text(tr('বলা নেই'), style: body(13)), selected: _accountId == null, onSelected: (_) => setState(() => _accountId = null)),
                ]),
              ],
              if (projects.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(tr('কোথায় লিখব'), style: body(14, color: C.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  ChoiceChip(label: Text(tr('নিজের মাসিক হিসাব'), style: body(13)), selected: _projectId == null, onSelected: (_) => setState(() => _projectId = null)),
                  for (final p in projects)
                    ChoiceChip(label: Text(trf('হিসাব: {0}', [p.name]), style: body(13)), selected: _projectId == p.id, onSelected: (_) => setState(() => _projectId = p.id)),
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
