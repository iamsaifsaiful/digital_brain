import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/cash.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

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
          tooltip: 'আগের মাস',
          onPressed: () => setState(() => _month = DateTime(m.year, m.month - 1)),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(child: Text('${bnMonths[m.month - 1]} ${bnDigits(m.year)}', textAlign: TextAlign.center, style: display(18))),
        IconButton(
          tooltip: 'পরের মাস',
          onPressed: isThisMonth ? null : () => setState(() => _month = DateTime(m.year, m.month + 1)),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ]),
      const SizedBox(height: 6),
      SummaryCard(
        title: isThisMonth ? 'এই মাসের ব্যালেন্স' : 'মাসের ব্যালেন্স',
        amount: sums.balance.abs(),
        negative: sums.balance < 0,
        items: [('আয়', sums.income, C.green), ('খরচ', sums.expense, C.orange)],
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: PrimaryButton(
            label: 'আয়',
            icon: Icons.add_rounded,
            height: 48,
            onPressed: () => _push(const CashFormScreen(kind: CashKind.income)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: PrimaryButton(
            label: 'খরচ',
            icon: Icons.add_rounded,
            height: 48,
            color: C.ink,
            onPressed: () => _push(const CashFormScreen(kind: CashKind.expense)),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Text('মুখেও বলা যায়: “বাজারে ৫০০ টাকা খরচ হলো”, “বেতন পেলাম ৩০ হাজার”', style: body(13, color: C.muted)),
      const SizedBox(height: 16),
      if (top.isNotEmpty) ...[
        const SectionTitle('খাত অনুযায়ী খরচ'),
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
        const EmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'এই মাসে কিছু লেখা নেই',
          text: 'বাজার, ভাড়া, বিল, বেতন — নিজের আয় আর খরচ এখানে রাখুন। মাস শেষে কত জমলো, এক নজরে দেখবেন।',
        )
      else ...[
        SectionTitle(isThisMonth ? 'এই মাসের হিসাব' : 'মাসের হিসাব'),
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
    trailing: Text('${income ? '+' : '−'}${taka(e.amount)}', style: display(16, color: income ? C.green : C.orange)),
    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CashFormScreen(entry: e, kind: e.kind, projectId: e.projectId))),
  );
}

/// আয়-ব্যয় as its own page (opened from the chat).
class CashPage extends StatelessWidget {
  const CashPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            const TopBar(title: 'আয়-ব্যয়'),
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
      title: Text(initial.isEmpty ? 'নতুন প্রজেক্ট' : 'প্রজেক্টের নাম', style: display(20)),
      content: TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'নাম, যেমন: রহিম ভবন')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
        TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('ঠিক আছে')),
      ],
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
      final name = await askProjectName(context);
      if (name == null || name.isEmpty || !context.mounted) return;
      final p = await brain.projectNamed(name);
      if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProjectScreen(id: p.id)));
    }

    Widget row(Project p) {
      final s = projectSums(d.cash, p.id);
      return ListRow(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: C.blueTint, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.work_outline_rounded, color: C.blue, size: 20),
        ),
        title: p.name,
        subtitle: 'এসেছে ${taka(s.income)} · খরচ ${taka(s.expense)}',
        trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(taka(s.balance.abs()), style: display(16, color: s.balance >= 0 ? C.green : C.orange)),
          Text(s.balance >= 0 ? 'অবশিষ্ট' : 'বেশি খরচ', style: body(12, color: C.muted)),
        ]),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProjectScreen(id: p.id))),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SummaryCard(
        title: 'চলমান প্রজেক্টে হাতে আছে',
        amount: (inTotal - outTotal).abs(),
        negative: inTotal < outTotal,
        items: [('মোট এসেছে', inTotal, C.green), ('মোট খরচ', outTotal, C.orange)],
      ),
      const SizedBox(height: 12),
      PrimaryButton(label: 'নতুন প্রজেক্ট', icon: Icons.add_rounded, height: 48, color: C.ink, onPressed: create),
      const SizedBox(height: 8),
      Text('মুখেও বলা যায়: “রহিম ভবন প্রজেক্টে ৫০ হাজার টাকা এলো”, “রহিম ভবন প্রজেক্টে রড কিনলাম ২০ হাজার”',
          style: body(13, color: C.muted)),
      const SizedBox(height: 16),
      if (open.isEmpty && closed.isEmpty)
        const EmptyState(
          icon: Icons.work_outline_rounded,
          title: 'কোনো প্রজেক্ট নেই',
          text: 'বাড়ি বানানো, অফিসের কাজ, কোনো অর্ডার — প্রতিটার আলাদা আয়-ব্যয় রাখুন। কত এলো, কত গেল, কত থাকলো দেখবেন।',
        )
      else ...[
        if (open.isNotEmpty) ...[
          const SectionTitle('চলমান প্রজেক্ট'),
          Panel(child: Rows(children: [for (final p in open) row(p)])),
        ],
        if (closed.isNotEmpty) ...[
          const SizedBox(height: 16),
          const SectionTitle('শেষ হওয়া প্রজেক্ট'),
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
      return const Scaffold(body: SafeArea(child: Column(children: [TopBar(title: 'প্রজেক্ট')])));
    }
    final s = projectSums(brain.data.cash, p.id);
    final entries = brain.data.cash.where((e) => e.projectId == p.id).toList()..sort((a, b) => b.date.compareTo(a.date));
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    Future<void> menu(String v) async {
      switch (v) {
        case 'rename':
          final name = await askProjectName(context, initial: p.name);
          if (name != null && name.isNotEmpty) await brain.saveProject(p.copyWith(name: name));
        case 'close':
          await brain.saveProject(p.copyWith(closed: !p.closed));
        case 'delete':
          final ok = await confirmDialog(context,
              title: 'প্রজেক্ট মুছবেন?', text: '‘${p.name}’ আর এর সব আয়-ব্যয় মুছে যাবে।', yes: 'মুছুন', danger: true);
          if (!ok) return;
          await brain.deleteProject(p.id);
          if (context.mounted) Navigator.of(context).pop();
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: p.name, trailing: [
            PopupMenuButton<String>(
              tooltip: 'আরও',
              onSelected: menu,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('নাম বদলান')),
                PopupMenuItem(value: 'close', child: Text(p.closed ? 'আবার চালু করুন' : 'প্রজেক্ট শেষ')),
                const PopupMenuItem(value: 'delete', child: Text('মুছুন')),
              ],
            ),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              SummaryCard(
                title: s.balance >= 0 ? 'হাতে আছে' : 'বেশি খরচ হয়েছে',
                amount: s.balance.abs(),
                negative: s.balance < 0,
                items: [('মোট এসেছে', s.income, C.green), ('মোট খরচ', s.expense, C.orange)],
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: PrimaryButton(
                    label: 'টাকা এলো',
                    icon: Icons.add_rounded,
                    height: 48,
                    onPressed: () => push(CashFormScreen(kind: CashKind.income, projectId: p.id)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    label: 'খরচ',
                    icon: Icons.add_rounded,
                    height: 48,
                    color: C.ink,
                    onPressed: () => push(CashFormScreen(kind: CashKind.expense, projectId: p.id)),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              if (s.byCategory.isNotEmpty) ...[
                const SectionTitle('খাত অনুযায়ী খরচ'),
                Panel(
                  child: Rows(children: [
                    for (final c in s.topExpenses)
                      ListRow(leading: const Icon(Icons.label_outline_rounded, color: C.muted), title: c.key, trailing: Text(taka(c.value), style: display(15))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],
              if (entries.isEmpty)
                const EmptyState(icon: Icons.receipt_long_outlined, title: 'এখনো কিছু লেখা নেই', text: 'টাকা এলে বা খরচ হলে উপরের বোতাম চাপুন, অথবা মুখে বলুন।')
              else ...[
                const SectionTitle('সব হিসাব'),
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
  const CashFormScreen({super.key, this.entry, this.kind = CashKind.expense, this.projectId});
  final CashEntry? entry;
  final CashKind kind;
  final String? projectId;

  @override
  State<CashFormScreen> createState() => _CashFormScreenState();
}

class _CashFormScreenState extends State<CashFormScreen> {
  late CashKind _kind = widget.entry?.kind ?? widget.kind;
  late final _amount = TextEditingController(text: widget.entry == null ? '' : '${widget.entry!.amount}');
  late final _category = TextEditingController(text: widget.entry?.category ?? '');
  late final _note = TextEditingController(text: widget.entry?.note ?? '');
  late DateTime _date = widget.entry?.date ?? BrainScope.read(context).services.now();
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
      toast(context, 'টাকার অঙ্ক দিন');
      return;
    }
    final cat = _category.text.trim().isEmpty ? (_kind == CashKind.income ? 'অন্যান্য আয়' : 'অন্যান্য') : _category.text.trim();
    await brain.saveCash(CashEntry(
      id: widget.entry?.id,
      kind: _kind,
      amount: amount,
      category: cat,
      note: _note.text.trim(),
      date: _date,
      projectId: _projectId,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final brain = BrainScope.read(context);
    final ok = await confirmDialog(context, title: 'মুছবেন?', text: 'এই হিসাবটা মুছে যাবে।', yes: 'মুছুন', danger: true);
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
          TopBar(title: widget.entry == null ? (_kind == CashKind.income ? 'আয় যোগ' : 'খরচ যোগ') : 'হিসাব বদলান', trailing: [
            if (widget.entry != null) IconButton(tooltip: 'মুছুন', onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded, color: C.red)),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              SegTabs<CashKind>(
                items: [(CashKind.expense, 'খরচ'), (CashKind.income, _projectId == null ? 'আয়' : 'টাকা এলো')],
                value: _kind,
                onChanged: (v) => setState(() => _kind = v),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                autofocus: widget.entry == null,
                style: display(24),
                decoration: const InputDecoration(labelText: 'টাকা', prefixText: '৳ '),
              ),
              const SizedBox(height: 14),
              TextField(controller: _category, decoration: const InputDecoration(labelText: 'খাত (যেমন: বাজার, ভাড়া, বেতন)')),
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
              TextField(controller: _note, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'নোট (ইচ্ছামতো)')),
              const SizedBox(height: 14),
              ListRow(
                leading: const Icon(Icons.event_outlined, color: C.ink),
                title: fullDate(_date),
                subtitle: 'তারিখ',
                trailing: const Icon(Icons.edit_calendar_outlined, color: C.muted),
                onTap: () async {
                  final now = brain.services.now();
                  final p = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(now.year - 5), lastDate: now);
                  if (p != null) setState(() => _date = DateTime(p.year, p.month, p.day, _date.hour, _date.minute));
                },
              ),
              if (projects.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('কোথায় লিখব', style: body(14, color: C.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  ChoiceChip(label: Text('নিজের মাসিক হিসাব', style: body(13)), selected: _projectId == null, onSelected: (_) => setState(() => _projectId = null)),
                  for (final p in projects)
                    ChoiceChip(label: Text('প্রজেক্ট: ${p.name}', style: body(13)), selected: _projectId == p.id, onSelected: (_) => setState(() => _projectId = p.id)),
                ]),
              ],
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: PrimaryButton(label: 'রাখুন', icon: Icons.check_rounded, onPressed: _save),
          ),
        ]),
      ),
    );
  }
}
