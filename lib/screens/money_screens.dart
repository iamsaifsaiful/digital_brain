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
import '../ui/kit.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../logic/lang.dart';
import '../ui/pdf_export.dart';
import '../ui/pick.dart';
import 'project_dues.dart';
import 'spend_health_screen.dart';

/// The dark balance card (24 Oct design): one big figure ("এই মাসের
/// ব্যালেন্স"), the figures under it, maybe a month switch on the right and
/// a soft line of how the balance went through the month.
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key, required this.title, required this.amount, required this.items, this.negative = false, this.trailing, this.spark});
  final String title;
  final int amount;

  /// Shows the big figure with a minus, in amber.
  final bool negative;

  /// (label, amount, colour) — amounts as taka. The colour is kept for
  /// the light text it maps to on the dark card.
  final List<(String, int, Color)> items;
  final Widget? trailing;

  /// The running balance, day by day (two points or more draws a line).
  final List<num>? spark;

  @override
  Widget build(BuildContext context) {
    const fg = Colors.white;
    final dim = Colors.white.withValues(alpha: 0.7);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: C.fill,
        borderRadius: BorderRadius.circular(22),
        border: C.dark ? Border.all(color: C.fillEdge) : null,
        boxShadow: C.shadow,
      ),
      child: Stack(children: [
        if (spark != null && spark!.length > 1)
          Positioned(right: 0, bottom: 0, width: 190, height: 96, child: CustomPaint(painter: _Spark(spark!))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: body(14, color: dim))),
              if (trailing != null) trailing!,
            ]),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('${negative ? '−' : ''}${taka(amount)}', style: display(36, weight: 700, color: negative ? const Color(0xFFF5C28B) : fg, height: 1.25)),
            ),
            const SizedBox(height: 10),
            Row(children: [
              for (final (i, it) in items.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(it.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: dim)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(it.$2 < 0 ? '—' : (it.$1 == tr('জমার হার') ? '${bnDigits(it.$2)}%' : taka(it.$2)), style: display(16, weight: 600, color: fg)),
                    ),
                  ]),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Spark extends CustomPainter {
  _Spark(this.v);
  final List<num> v;

  @override
  void paint(Canvas canvas, Size s) {
    final lo = v.fold<double>(double.infinity, (a, b) => a < b ? a : b.toDouble());
    final hi = v.fold<double>(-double.infinity, (a, b) => a > b ? a : b.toDouble());
    final span = hi - lo == 0 ? 1.0 : hi - lo;
    Offset at(int i) => Offset(s.width * i / (v.length - 1), s.height * 0.9 - (v[i] - lo) / span * s.height * 0.75);
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < v.length; i++) {
      final p0 = at(i - 1), p1 = at(i);
      final mx = (p0.dx + p1.dx) / 2;
      line.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
    }
    final area = Path.from(line)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF8FD3B4).withValues(alpha: 0.32), const Color(0xFF8FD3B4).withValues(alpha: 0.02)])
              .createShader(Offset.zero & s));
    canvas.drawPath(
        line,
        Paint()
          ..color = const Color(0xFFA9E2C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_Spark o) => o.v != v;
}

/// The money left after each day of [m] so far (for the card's line).
List<int> runningBalance(List<CashEntry> cash, DateTime m, DateTime now) {
  final last = (m.year == now.year && m.month == now.month) ? now.day : DateTime(m.year, m.month + 1, 0).day;
  final perDay = List<int>.filled(last + 1, 0);
  for (final e in cash) {
    if (e.projectId != null || e.date.year != m.year || e.date.month != m.month || e.date.day > last) continue;
    perDay[e.date.day] += e.kind == CashKind.income ? e.amount : -e.amount;
  }
  final out = <int>[];
  var run = 0;
  for (var d = 1; d <= last; d++) {
    run += perDay[d];
    out.add(run);
  }
  return out;
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

    final rate = sums.income > 0 ? (sums.balance * 100 / sums.income).round().clamp(-999, 100) : -1;
    Widget arrow(IconData icon, String tip, VoidCallback? go) => SizedBox(
          width: 30,
          height: 30,
          child: IconButton(
            tooltip: tip,
            padding: EdgeInsets.zero,
            iconSize: 20,
            color: Colors.white,
            disabledColor: Colors.white24,
            onPressed: go,
            icon: Icon(icon),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SummaryCard(
        title: isThisMonth ? tr('এই মাসের ব্যালেন্স') : tr('মাসের ব্যালেন্স'),
        amount: sums.balance.abs(),
        negative: sums.balance < 0,
        spark: runningBalance(brain.data.cash, m, now),
        trailing: Container(
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            arrow(Icons.chevron_left_rounded, tr('আগের মাস'), () {
              _picks.clear();
              setState(() => _month = DateTime(m.year, m.month - 1));
            }),
            Text(isThisMonth || m.year == now.year ? monthName(m.month) : '${monthName(m.month)} ${bnDigits(m.year)}', style: body(13, weight: FontWeight.w600, color: Colors.white)),
            arrow(
                Icons.chevron_right_rounded,
                tr('পরের মাস'),
                isThisMonth
                    ? null
                    : () {
                        _picks.clear();
                        setState(() => _month = DateTime(m.year, m.month + 1));
                      }),
          ]),
        ),
        items: [(tr('আয়'), sums.income, C.green), (tr('খরচ'), sums.expense, C.orange), if (rate >= 0) (tr('জমার হার'), rate, C.green)],
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
            color: C.surface,
            textColor: C.ink,
            onPressed: () => _push(const CashFormScreen(kind: CashKind.expense)),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Text(tr('মুখেও বলা যায়: “বাজারে ৫০০ টাকা খরচ হলো”, “বেতন পেলাম ৩০ হাজার”'), style: body(13, color: C.muted)),
      const SizedBox(height: 16),
      if (top.isNotEmpty) ...[
        SectionTitle(tr('খাত অনুযায়ী খরচ'), action: tr('বিস্তারিত'), onAction: () => _push(const SpendHealthScreen())),
        Panel(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Builder(builder: (context) {
            final colors = splitColors();
            final shown = top.take(colors.length - 1).toList();
            final rest = top.skip(shown.length).fold<int>(0, (a, c) => a + c.value);
            final parts = [for (final (i, c) in shown.indexed) (c.key, c.value, colors[i]), if (rest > 0) (tr('অন্যান্য'), rest, colors.last)];
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              StackedBar(parts: [for (final p in parts) (p.$2.toDouble(), p.$3)], height: 12),
              const SizedBox(height: 10),
              Wrap(runSpacing: 2, children: [
                for (final p in parts)
                  FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 10, 4),
                      child: Row(children: [
                        Container(width: 9, height: 9, decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle, border: Border.all(color: C.line))),
                        const SizedBox(width: 7),
                        Expanded(child: Text(p.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13.5))),
                        Text(taka(p.$2), style: display(13.5, weight: 600)),
                      ]),
                    ),
                  ),
              ]),
            ]);
          }),
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
        : IconSquare(income ? Icons.south_west_rounded : Icons.north_east_rounded, size: 40, color: income ? C.green : C.muted2),
    title: e.category,
    subtitle: [shortDate(e.date), if (e.note.trim().isNotEmpty) e.note.trim()].join(' · '),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('${income ? '+' : '−'}${taka(e.amount)}', style: display(16, weight: 600, color: income ? C.green : C.ink)),
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
          await brain.saveCash(CashEntry(id: e.id, kind: e.kind, amount: e.amount, category: cat, note: e.note, date: e.date, projectId: e.projectId, accountId: e.accountId, shopId: e.shopId));
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
        items: [(tr('মোট এসেছে'), inTotal, C.green), (tr('মোট খরচ'), outTotal, C.orange)],
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
    // No খাত picked: guess it from the note ("রিকশা" → যাতায়াত), else অন্যান্য.
    final cat = _category.text.trim().isEmpty ? categoryFor(normalize(_note.text), _kind) : _category.text.trim();
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
                  for (final a in brain.data.accounts) ChoiceChip(label: Text(accountLabel(a), style: body(13)), selected: _accountId == a.id, onSelected: (_) => setState(() => _accountId = a.id)),
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
