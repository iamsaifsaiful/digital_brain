import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/money_more.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/forms.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'money_screens.dart';
import 'shop_screens.dart';

export 'shop_screens.dart' show ShopScreen, ShopDetailScreen;
import '../ui/pdf_export.dart';

void _push(BuildContext context, Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

/// The row of money tools at the top of হিসাব.
class MoneyTools extends StatelessWidget {
  const MoneyTools({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    Widget tile(String label, IconData icon, Color fg, Color bg, Widget page) => Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Material(
            color: C.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _push(context, page),
              child: Container(
                width: 92,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                decoration: BoxDecoration(border: Border.all(color: C.line), borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(icon, color: fg, size: 22),
                  ),
                  const SizedBox(height: 6),
                  Text(label, textAlign: TextAlign.center, maxLines: 2, style: body(12.5, weight: FontWeight.w500, height: 1.25)),
                ]),
              ),
            ),
          ),
        );
    return SizedBox(
      height: 104,
      child: ListView(scrollDirection: Axis.horizontal, children: [
        if (brain.businessMode) tile(tr('দোকান'), Icons.storefront_outlined, C.orange, C.orangeTint, const ShopScreen()),
        tile(tr('অ্যাকাউন্ট'), Icons.account_balance_outlined, C.blue, C.blueTint, const AccountsScreen()),
        tile(tr('মাসের রিপোর্ট'), Icons.insert_chart_outlined_rounded, C.green, C.greenTint, const ReportScreen()),
        tile(tr('সঞ্চয় ও কিস্তি'), Icons.savings_outlined, C.purple, C.purpleTint, const SavingsScreen()),
        tile(tr('খরচ ভাগাভাগি'), Icons.call_split_rounded, C.teal, C.tealTint, const SplitScreen()),
        tile(tr('যাকাত'), Icons.volunteer_activism_outlined, C.ochre, C.ochreTint, const ZakatScreen()),
      ]),
    );
  }
}

/// A quick card at the top of হিসাব in business mode.
class ShopTodayCard extends StatelessWidget {
  const ShopTodayCard({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final d = brain.data;
    final s = salesOn(d, now);
    final due = d.shops.isEmpty ? customersOwing(d).fold(0, (a, p) => a + p.balance) : {for (final sh in d.shops) for (final p in shopCustomersOwing(d, sh)) p.key: p.balance}.values.fold(0, (a, b) => a + b);
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Figure(label: tr('আজকের বিক্রি'), amount: taka(s.total), color: C.green, size: 22, sub: trf('{0}টি বিক্রি', [bnDigits(s.count)]))),
          Expanded(child: Figure(label: tr('কাস্টমারের বাকি'), amount: taka(due), color: C.orange, size: 22)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: PrimaryButton(
              label: tr('বিক্রি'),
              icon: Icons.add_rounded,
              height: 44,
              onPressed: () async {
                final shop = await pickShop(context);
                if (shop == false || !context.mounted) return;
                _push(context, CashFormScreen(kind: CashKind.income, category: salesCategory, shopId: (shop as Shop?)?.id));
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PrimaryButton(
              label: tr('রসিদ'),
              icon: Icons.receipt_long_outlined,
              height: 44,
              color: C.fill,
              onPressed: () async {
                final shop = await pickShop(context);
                if (shop == false || !context.mounted) return;
                _push(context, ReceiptScreen(shop: shop as Shop?));
              },
            ),
          ),
        ]),
      ]),
    );
  }
}

// ───────────────────────── Accounts ─────────────────────────

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  Future<void> _edit(BuildContext context, MoneyAccount? old) async {
    final brain = BrainScope.read(context);
    var kind = old?.kind ?? AccountKind.bkash;
    final name = TextEditingController(text: old?.name ?? '');
    final opening = TextEditingController(text: old == null ? '' : '${old.opening}');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(old == null ? tr('নতুন অ্যাকাউন্ট') : tr('অ্যাকাউন্ট বদলান'), style: display(20, weight: 700)),
            FieldLabel(tr('ধরন')),
            ChoiceChips<AccountKind>(items: [for (final k in AccountKind.values) (k, isEn ? k.en : k.bn)], value: kind, onChanged: (v) => set(() => kind = v)),
            FieldLabel(tr('নাম (ঐচ্ছিক)')),
            TextField(controller: name, decoration: InputDecoration(hintText: tr('যেমন: ডাচ-বাংলা সেভিংস, পকেটের টাকা'))),
            FieldLabel(tr('এখন কত আছে')),
            TextField(controller: opening, keyboardType: TextInputType.number, decoration: InputDecoration(prefixText: tr('৳ '))),
            const SizedBox(height: 16),
            PrimaryButton(label: tr('রাখুন'), onPressed: () => Navigator.pop(ctx, true)),
            if (old != null)
              TextButton(
                onPressed: () async {
                  await brain.deleteAccount(old.id);
                  if (ctx.mounted) Navigator.pop(ctx, false);
                },
                child: Text(tr('মুছে ফেলুন'), style: body(15, weight: FontWeight.w600, color: C.red)),
              ),
          ]),
        ),
      ),
    );
    if (ok == true) {
      final base = old ?? MoneyAccount(name: '');
      // The balance typed now: keep the history, change the opening to match.
      final typed = readInt(opening.text) ?? 0;
      final now = old == null ? 0 : accountBalance(brain.data, old) - old.opening;
      await brain.saveAccount(base.copyWith(name: name.text.trim(), kind: kind, opening: typed - now));
    }
    name.dispose();
    opening.dispose();
  }

  /// A new move between accounts, or [old] changed.
  Future<void> _transfer(BuildContext context, [Transfer? old]) async {
    final brain = BrainScope.read(context);
    final accs = brain.data.accounts;
    if (accs.length < 2) {
      toast(context, tr('টাকা সরাতে অন্তত দুটো অ্যাকাউন্ট লাগবে'));
      return;
    }
    var from = old?.from ?? accs[0].id, to = old?.to ?? accs[1].id;
    final amount = TextEditingController(text: old == null ? '' : '${old.amount}'), fee = TextEditingController(text: old == null || old.fee == 0 ? '' : '${old.fee}');
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('এক অ্যাকাউন্ট থেকে আরেকটায়'), style: display(20, weight: 700)),
            FieldLabel(tr('থেকে')),
            ChoiceChips<String>(items: [for (final a in accs) (a.id, accountLabel(a))], value: from, onChanged: (v) => set(() => from = v)),
            FieldLabel(tr('তে')),
            ChoiceChips<String>(items: [for (final a in accs) (a.id, accountLabel(a))], value: to, onChanged: (v) => set(() => to = v)),
            FieldLabel(tr('কত টাকা')),
            TextField(controller: amount, keyboardType: TextInputType.number, autofocus: true, decoration: InputDecoration(prefixText: tr('৳ '))),
            FieldLabel(tr('খরচ/চার্জ (যেমন ক্যাশ আউট, ঐচ্ছিক)')),
            TextField(controller: fee, keyboardType: TextInputType.number, decoration: InputDecoration(prefixText: tr('৳ '))),
            const SizedBox(height: 16),
            PrimaryButton(label: tr('রাখুন'), onPressed: () => Navigator.pop(ctx, true)),
          ]),
        ),
      ),
    );
    final a = readInt(amount.text) ?? 0;
    if (ok == true && a > 0 && from != to) {
      await brain.saveTransfer(Transfer(id: old?.id, from: from, to: to, amount: a, fee: readInt(fee.text) ?? 0, date: old?.date ?? brain.services.now(), note: old?.note ?? ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final total = totalBalance(d);
    IconData icon(AccountKind k) => switch (k) {
          AccountKind.cash => Icons.payments_outlined,
          AccountKind.bank => Icons.account_balance_outlined,
          AccountKind.other => Icons.wallet_outlined,
          _ => Icons.phone_android_rounded,
        };
    final moves = [...d.transfers]..sort((a, b) => b.date.compareTo(a.date));
    String nameOf(String id) => accountLabel(d.accounts.firstWhere((a) => a.id == id, orElse: () => MoneyAccount(id: id, name: '?')));
    return Scaffold(
      floatingActionButton: AddButton(label: tr('অ্যাকাউন্ট যোগ'), onPressed: () => _edit(context, null)),
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('অ্যাকাউন্ট'), trailing: [
            const PdfButton({ReportPart.accounts}),
            if (d.accounts.length >= 2) IconButton(tooltip: tr('টাকা সরান'), onPressed: () => _transfer(context), icon: const Icon(Icons.swap_horiz_rounded)),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
              if (d.accounts.isEmpty)
                EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: tr('নগদ, বিকাশ, ব্যাংক — আলাদা রাখুন'),
                  text: tr('প্রতিটার এখনকার টাকা দিয়ে যোগ করুন। এরপর আয়-ব্যয় লেখার সময় কোন অ্যাকাউন্ট, তা বেছে নিলে ব্যালেন্স নিজে থেকে মিলবে।'),
                  action: tr('প্রথম অ্যাকাউন্ট যোগ'),
                  onAction: () => _edit(context, null),
                )
              else ...[
                Panel(
                  padding: const EdgeInsets.all(16),
                  child: Figure(label: tr('সব মিলিয়ে হাতে আছে'), amount: '${total < 0 ? '−' : ''}${taka(total.abs())}', color: total < 0 ? C.orange : C.ink, size: 30),
                ),
                const SizedBox(height: 12),
                Panel(
                  child: Rows(children: [
                    for (final a in d.accounts)
                      ListRow(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: C.blueTint, borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon(a.kind), color: C.blue),
                        ),
                        title: accountLabel(a),
                        subtitle: a.name.trim().isEmpty ? null : (isEn ? a.kind.en : a.kind.bn),
                        trailing: Text(taka(accountBalance(d, a)), style: display(17, weight: 700, color: accountBalance(d, a) < 0 ? C.orange : C.ink)),
                        onTap: () => _edit(context, a),
                      ),
                  ]),
                ),
                if (moves.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionTitle(tr('টাকা সরানো')),
                  Panel(
                    child: Rows(children: [
                      for (final t in moves.take(20))
                        ListRow(
                          leading: Icon(Icons.swap_horiz_rounded, color: C.muted2),
                          title: '${nameOf(t.from)} → ${nameOf(t.to)}',
                          subtitle: '${shortDate(t.date)}${t.fee > 0 ? trf(' · চার্জ {0}', [taka(t.fee)]) : ''}',
                          trailing: Text(taka(t.amount), style: body(15, weight: FontWeight.w600)),
                          onTap: () async {
                            final pick = await editOrDelete(context);
                            if (!context.mounted) return;
                            if (pick == 'edit') await _transfer(context, t);
                            if (pick == 'delete' &&
                                await confirmDialog(context, title: tr('মুছবেন?'), text: tr('এই টাকা সরানোর হিসাবটা মুছে যাবে।'), yes: tr('মুছুন'), danger: true)) {
                              await brain.deleteTransfer(t.id);
                            }
                          },
                        ),
                    ]),
                  ),
                ],
                const SizedBox(height: 10),
                Text(tr('আয়-ব্যয় লেখার সময় অ্যাকাউন্ট বেছে নিলে এখানে মিলবে। “টাকা সরান” (⇄) দিয়ে বিকাশ থেকে নগদে তোলা বা ব্যাংকে জমা রাখুন।'),
                    style: body(13, color: C.muted, height: 1.5)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Monthly report ─────────────────────────

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime? _month;
  final _shot = GlobalKey();

  Future<void> _share(MonthReport r) async {
    final brain = BrainScope.read(context);
    try {
      final boundary = _shot.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 2.5);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      await brain.services.files.shareFile(data.buffer.asUint8List(), 'report-${r.month.year}-${r.month.month}.png', 'image/png',
          trf('{0} মাসের হিসাব — My Assistant', [monthTitle(r.month)]));
    } catch (_) {
      if (mounted) toast(context, tr('ছবি বানানো গেল না'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final m = _month ?? DateTime(now.year, now.month);
    final r = monthReport(brain.data, m);
    final insights = reportInsights(r);
    final colors = [C.green, C.blue, C.orange, C.purple, C.teal, C.rose, C.ochre, C.muted];
    final top = r.byCategory.take(7).toList();
    final rest = r.byCategory.skip(7).fold(0, (a, e) => a + e.value);
    final slices = [...top, if (rest > 0) MapEntry(tr('অন্যান্য'), rest)];

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('মাসের রিপোর্ট'), trailing: [
            PdfButton(const {ReportPart.money}, scope: ReportScope(month: m), title: trf('আয়-ব্যয় · {0}', [monthTitle(m)]), fileExtra: monthKey(m)),
            if (r.expense > 0) IconButton(tooltip: tr('ছবি হিসেবে পাঠান'), onPressed: () => _share(r), icon: const Icon(Icons.ios_share_rounded)),
          ]),
          Row(children: [
            IconButton(tooltip: tr('আগের মাস'), onPressed: () => setState(() => _month = DateTime(m.year, m.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
            Expanded(child: Text(monthTitle(m), textAlign: TextAlign.center, style: display(18))),
            IconButton(
              tooltip: tr('পরের মাস'),
              onPressed: m.year == now.year && m.month == now.month ? null : () => setState(() => _month = DateTime(m.year, m.month + 1)),
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              RepaintBoundary(
                key: _shot,
                child: Container(
                  color: C.ground,
                  padding: const EdgeInsets.all(4),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SummaryCard(
                      title: trf('{0} — ব্যালেন্স', [monthTitle(m)]),
                      amount: r.balance.abs(),
                      negative: r.balance < 0,
                      items: [(tr('আয়'), r.income, C.green), (tr('খরচ'), r.expense, C.orange)],
                    ),
                    const SizedBox(height: 12),
                    if (r.expense == 0)
                      EmptyState(icon: Icons.insert_chart_outlined_rounded, title: tr('এই মাসে কোনো খরচ লেখা নেই'), text: tr('খরচ লিখলে এখানে ছবিসহ হিসাব দেখাবে।'))
                    else ...[
                      Panel(
                        padding: const EdgeInsets.all(16),
                        child: Row(children: [
                          SizedBox(
                            width: 130,
                            height: 130,
                            child: CustomPaint(painter: _Donut([for (final e in slices) e.value.toDouble()], colors, C.surface)),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              for (final (i, e) in slices.indexed)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(children: [
                                    Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13))),
                                    Text('${bnDigits((e.value * 100 / r.expense).round())}%', style: body(13, weight: FontWeight.w600)),
                                  ]),
                                ),
                            ]),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      if (insights.isNotEmpty)
                        Panel(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Icon(Icons.lightbulb_outline_rounded, color: C.ochre, size: 20),
                              const SizedBox(width: 6),
                              Text(tr('খরচ কোথায় বেশি হলো'), style: body(15, weight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 6),
                            for (final t in insights) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $t', style: body(14, height: 1.5))),
                          ]),
                        ),
                      const SizedBox(height: 12),
                      SectionTitle(tr('খাত ধরে, গত মাসের সাথে')),
                      Panel(
                        padding: const EdgeInsets.all(14),
                        child: Column(children: [
                          for (final e in r.byCategory)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                Row(children: [
                                  Expanded(child: Text(e.key, style: body(14, weight: FontWeight.w500))),
                                  Text(taka(e.value), style: body(14, weight: FontWeight.w600)),
                                ]),
                                const SizedBox(height: 4),
                                Bar(value: e.value / r.byCategory.first.value, color: C.orange),
                                if ((r.lastByCategory[e.key] ?? 0) > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(trf('গত মাসে {0}', [taka(r.lastByCategory[e.key]!)]), style: body(12, color: C.muted)),
                                  ),
                              ]),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      SectionTitle(tr('দিন ধরে খরচ')),
                      Panel(
                        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
                        child: SizedBox(height: 120, child: CustomPaint(painter: _DayBars(r.byDay, DateTime(m.year, m.month + 1, 0).day, C.green, C.muted))),
                      ),
                    ],
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Donut extends CustomPainter {
  _Donut(this.values, this.colors, this.hole);
  final List<double> values;
  final List<Color> colors;
  final Color hole;
  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold(0.0, (a, b) => a + b);
    if (total <= 0) return;
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      canvas.drawArc(rect.deflate(12), start, sweep, false, Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _Donut old) => old.values != values;
}

class _DayBars extends CustomPainter {
  _DayBars(this.byDay, this.days, this.color, this.label);
  final Map<int, int> byDay;
  final int days;
  final Color color;
  final Color label;
  @override
  void paint(Canvas canvas, Size size) {
    final maxV = byDay.values.fold(0, math.max);
    if (maxV <= 0) return;
    final w = size.width / days;
    final h = size.height - 16;
    final p = Paint()..color = color;
    for (var d = 1; d <= days; d++) {
      final v = byDay[d] ?? 0;
      final bh = v / maxV * h;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH((d - 1) * w + w * 0.15, h - bh, w * 0.7, bh), const Radius.circular(2)), p);
      if (d == 1 || d % 5 == 0) {
        final tp = TextPainter(text: TextSpan(text: bnDigits(d), style: TextStyle(fontSize: 10, color: label)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset((d - 1) * w + w / 2 - tp.width / 2, h + 3));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DayBars old) => old.byDay != byDay;
}

// ───────────────────────── Savings and instalments ─────────────────────────

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});
  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  int _tab = 0;

  Future<void> _editGoal(SavingsGoal? old) async {
    final brain = BrainScope.read(context);
    final name = TextEditingController(text: old?.name ?? '');
    final target = TextEditingController(text: old == null ? '' : '${old.target}');
    DateTime? deadline = old?.deadline;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(old == null ? tr('নতুন সঞ্চয়ের লক্ষ্য') : tr('লক্ষ্য বদলান'), style: display(20, weight: 700)),
            FieldLabel(tr('কীসের জন্য')),
            TextField(controller: name, autofocus: old == null, decoration: InputDecoration(hintText: tr('যেমন: ঈদের খরচ, নতুন ফোন'))),
            FieldLabel(tr('কত টাকা জমাতে চান')),
            TextField(controller: target, keyboardType: TextInputType.number, decoration: InputDecoration(prefixText: tr('৳ '))),
            FieldLabel(tr('কবের মধ্যে (ঐচ্ছিক)')),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final d = await showDatePicker(context: ctx, initialDate: deadline ?? now.add(const Duration(days: 90)), firstDate: now, lastDate: DateTime(now.year + 20));
                if (d != null) set(() => deadline = d);
              },
              icon: const Icon(Icons.event_outlined),
              label: Text(deadline == null ? tr('তারিখ বেছে নিন') : fullDate(deadline!)),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: tr('রাখুন'), onPressed: () => Navigator.pop(ctx, true)),
            if (old != null)
              TextButton(
                onPressed: () async {
                  await brain.deleteGoal(old.id);
                  if (ctx.mounted) Navigator.pop(ctx, false);
                },
                child: Text(tr('মুছে ফেলুন'), style: body(15, weight: FontWeight.w600, color: C.red)),
              ),
          ]),
        ),
      ),
    );
    final t = readInt(target.text) ?? 0;
    if (ok == true && name.text.trim().isNotEmpty && t > 0) {
      final base = old ?? SavingsGoal(name: name.text.trim(), target: t, createdAt: brain.services.now());
      await brain.saveGoal(base.copyWith(name: name.text.trim(), target: t, deadline: deadline, clearDeadline: deadline == null));
    }
    name.dispose();
    target.dispose();
  }

  Future<void> _editInst(Installment? old) async {
    final brain = BrainScope.read(context);
    final name = TextEditingController(text: old?.name ?? '');
    final amount = TextEditingController(text: old == null ? '' : '${old.amount}');
    final months = TextEditingController(text: '${old?.months ?? 12}');
    var kind = old?.kind ?? InstallmentKind.dps;
    var day = old?.dayOfMonth ?? 5;
    var start = old?.start ?? DateTime(DateTime.now().year, DateTime.now().month);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(old == null ? tr('নতুন কিস্তি') : tr('কিস্তি বদলান'), style: display(20, weight: 700)),
              FieldLabel(tr('ধরন')),
              ChoiceChips<InstallmentKind>(items: [for (final k in InstallmentKind.values) (k, isEn ? k.en : k.bn)], value: kind, onChanged: (v) => set(() => kind = v)),
              FieldLabel(tr('নাম')),
              TextField(controller: name, decoration: InputDecoration(hintText: tr('যেমন: সোনালী ব্যাংক DPS, বাইকের লোন'))),
              FieldLabel(tr('প্রতি মাসে কত')),
              TextField(controller: amount, keyboardType: TextInputType.number, decoration: InputDecoration(prefixText: tr('৳ '))),
              FieldLabel(tr('মোট কয় মাস')),
              TextField(controller: months, keyboardType: TextInputType.number),
              FieldLabel(trf('মাসের কত তারিখে: {0}', [bnDigits(day)])),
              Slider(value: day.toDouble(), min: 1, max: 28, divisions: 27, label: bnDigits(day), onChanged: (v) => set(() => day = v.round())),
              FieldLabel(tr('প্রথম কিস্তির মাস')),
              OutlinedButton.icon(
                onPressed: () async {
                  final d = await showDatePicker(context: ctx, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) set(() => start = DateTime(d.year, d.month));
                },
                icon: const Icon(Icons.event_outlined),
                label: Text(monthTitle(start)),
              ),
              const SizedBox(height: 16),
              PrimaryButton(label: tr('রাখুন'), onPressed: () => Navigator.pop(ctx, true)),
              if (old != null)
                TextButton(
                  onPressed: () async {
                    await brain.deleteInstallment(old);
                    if (ctx.mounted) Navigator.pop(ctx, false);
                  },
                  child: Text(tr('মুছে ফেলুন'), style: body(15, weight: FontWeight.w600, color: C.red)),
                ),
            ]),
          ),
        ),
      ),
    );
    final a = readInt(amount.text) ?? 0;
    if (ok == true && name.text.trim().isNotEmpty && a > 0) {
      final base = old ?? Installment(name: name.text.trim(), amount: a, start: start);
      await brain.saveInstallment(base.copyWith(name: name.text.trim(), kind: kind, amount: a, months: (readInt(months.text) ?? 12).clamp(1, 600), dayOfMonth: day, start: start));
    }
    name.dispose();
    amount.dispose();
    months.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    return Scaffold(
      floatingActionButton: AddButton(label: _tab == 0 ? tr('লক্ষ্য যোগ') : tr('কিস্তি যোগ'), onPressed: () => _tab == 0 ? _editGoal(null) : _editInst(null)),
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('সঞ্চয় ও কিস্তি'), trailing: const [PdfButton({ReportPart.accounts})]),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: SegTabs<int>(items: [(0, tr('সঞ্চয়ের লক্ষ্য')), (1, tr('কিস্তি ও DPS'))], value: _tab, onChanged: (v) => setState(() => _tab = v)),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
              if (_tab == 0) ...[
                if (d.goals.isEmpty)
                  EmptyState(icon: Icons.savings_outlined, title: tr('কোনো লক্ষ্য নেই'), text: tr('ঈদ, ভ্রমণ, নতুন কিছু কেনা — লক্ষ্য ঠিক করে একটু একটু জমান। কত জমলো আর মাসে কত রাখতে হবে, দেখাবে।'))
                else
                  for (final g in d.goals) ...[
                    Panel(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Expanded(child: Text(g.name, style: body(16, weight: FontWeight.w600))),
                          IconButton(tooltip: tr('বদলান'), onPressed: () => _editGoal(g), icon: Icon(Icons.edit_outlined, color: C.muted, size: 20)),
                        ]),
                        Text(trf('{0} জমেছে, লক্ষ্য {1}', [taka(g.saved), taka(g.target)]), style: body(14, color: C.muted2)),
                        const SizedBox(height: 8),
                        Bar(value: g.progress, height: 10),
                        const SizedBox(height: 6),
                        if (g.deadline != null)
                          Text(
                            g.saved >= g.target
                                ? tr('লক্ষ্য পূরণ হয়েছে! 🎉')
                                : trf('{0}-এর মধ্যে · মাসে {1} করে রাখলে হবে', [shortDate(g.deadline!), taka(g.perMonth(now) ?? 0)]),
                            style: body(13, color: g.saved >= g.target ? C.green : C.muted),
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: FilledButton.icon(
                            onPressed: () async {
                              final v = readInt(await askText(context, tr('কত জমালেন?'), number: true));
                              if (v != null && v > 0) await brain.addDeposit(g, v);
                            },
                            style: FilledButton.styleFrom(backgroundColor: C.green, shape: const StadiumBorder()),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(tr('জমা')),
                          ),
                        ),
                        if (g.deposits.isNotEmpty)
                          TextButton(
                            onPressed: () => _deposits(context, g.id),
                            child: Text(trf('জমার হিসাব · {0}টা — বদলান বা মুছুন', [bnDigits(g.deposits.length)])),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],
              ] else ...[
                if (d.installments.isEmpty)
                  EmptyState(
                      icon: Icons.event_repeat_outlined,
                      title: tr('কোনো কিস্তি নেই'),
                      text: tr('DPS, লোনের কিস্তি, বীমার প্রিমিয়াম — প্রতি মাসে আগের দিন মনে করাবো, টিক দিলে কত বাকি দেখাবে।'))
                else
                  for (final i in d.installments) ...[
                    Panel(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(i.name, style: body(16, weight: FontWeight.w600)),
                              Text('${isEn ? i.kind.en : i.kind.bn} · ${taka(i.amount)} · ${trf('প্রতি মাসের {0} তারিখ', [bnDigits(i.dayOfMonth)])}', style: body(13, color: C.muted)),
                            ]),
                          ),
                          IconButton(tooltip: tr('বদলান'), onPressed: () => _editInst(i), icon: Icon(Icons.edit_outlined, color: C.muted, size: 20)),
                        ]),
                        const SizedBox(height: 8),
                        Bar(value: i.months == 0 ? 0 : i.paidCount / i.months, height: 10, color: C.purple),
                        const SizedBox(height: 6),
                        Text(trf('{0}/{1} কিস্তি দেওয়া ({2}) · বাকি {3}টি · শেষ {4}', [bnDigits(i.paidCount), bnDigits(i.months), taka(i.paidTotal), bnDigits(i.left), monthTitle(i.end)]),
                            style: body(13, color: C.muted2)),
                        const SizedBox(height: 8),
                        Row(children: [
                          FilledButton.icon(
                            onPressed: () => brain.toggleInstallmentPaid(i, now),
                            style: FilledButton.styleFrom(backgroundColor: i.paidFor(now) ? C.chip : C.purple, foregroundColor: i.paidFor(now) ? C.ink : Colors.white, shape: const StadiumBorder()),
                            icon: Icon(i.paidFor(now) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, size: 18),
                            label: Text(i.paidFor(now) ? trf('{0} দেওয়া হয়েছে', [monthName(now.month)]) : trf('{0}-এর কিস্তি দিলাম', [monthName(now.month)])),
                          ),
                        ]),
                      ]),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Split a bill ─────────────────────────

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});
  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  final _total = TextEditingController();
  final _names = <TextEditingController>[TextEditingController(text: ''), TextEditingController(), TextEditingController()];
  bool _iPaid = true;

  @override
  void dispose() {
    _total.dispose();
    for (final c in _names) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final total = readInt(_total.text) ?? 0;
    final people = _names.length + 1;
    final shares = splitAmounts(total, people);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('খরচ ভাগাভাগি')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              TextField(
                controller: _total,
                keyboardType: TextInputType.number,
                style: display(24),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: tr('মোট খরচ'), prefixText: tr('৳ ')),
              ),
              FieldLabel(trf('কয়জনে ভাগ (আপনিসহ {0} জন)', [bnDigits(people)])),
              for (final (i, c) in _names.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(child: TextField(controller: c, decoration: InputDecoration(hintText: trf('{0} নম্বর জনের নাম', [bnDigits(i + 2)])))),
                    IconButton(
                      tooltip: tr('সরান'),
                      onPressed: _names.length <= 1 ? null : () => setState(() => _names.removeAt(i).dispose()),
                      icon: Icon(Icons.remove_circle_outline_rounded, color: C.muted),
                    ),
                  ]),
                ),
              TextButton.icon(onPressed: () => setState(() => _names.add(TextEditingController())), icon: const Icon(Icons.person_add_alt_1_outlined), label: Text(tr('আরেকজন'))),
              const SizedBox(height: 8),
              if (total > 0)
                Panel(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(trf('প্রত্যেকে {0}', [taka(shares.first)]), style: display(24, weight: 700, color: C.green)),
                    if (shares.first != shares.last) Text(tr('(ভাগ সমান না হওয়ায় কারো কারো ১ টাকা বেশি)'), style: body(12.5, color: C.muted)),
                  ]),
                ),
              const SizedBox(height: 10),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _iPaid,
                onChanged: (v) => setState(() => _iPaid = v),
                title: Text(tr('পুরো টাকা আমি দিয়েছি'), style: body(15)),
                subtitle: Text(tr('তাহলে বাকিদের ভাগ “পাওনা” হিসেবে লেনদেনের খাতায় উঠবে'), style: body(12.5, color: C.muted)),
              ),
              const SizedBox(height: 10),
              PrimaryButton(
                label: _iPaid ? tr('খাতায় পাওনা হিসেবে রাখুন') : tr('আমার ভাগ খরচে লিখুন'),
                onPressed: total <= 0
                    ? null
                    : () async {
                        final now = brain.services.now();
                        if (_iPaid) {
                          var n = 0;
                          for (final (i, c) in _names.indexed) {
                            final name = c.text.trim();
                            if (name.isEmpty) continue;
                            await brain.saveEntry(LedgerEntry(person: name, kind: LedgerKind.lent, amount: shares[i + 1], date: dayOnly(now), note: tr('খরচ ভাগাভাগি')));
                            n++;
                          }
                          await brain.saveCash(CashEntry(kind: CashKind.expense, amount: shares.first, category: tr('ভাগের খরচ'), date: now));
                          if (context.mounted) toast(context, trf('{0} জনের পাওনা লেখা হলো, আপনার ভাগ খরচে', [bnDigits(n)]));
                        } else {
                          await brain.saveCash(CashEntry(kind: CashKind.expense, amount: shares.first, category: tr('ভাগের খরচ'), date: now));
                          if (context.mounted) toast(context, tr('আপনার ভাগ খরচে লেখা হলো'));
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Zakat ─────────────────────────

class ZakatScreen extends StatefulWidget {
  const ZakatScreen({super.key});
  @override
  State<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends State<ZakatScreen> {
  /// What the app cannot know: entered once, kept for next time.
  final _f = {for (final k in ['gold_vori', 'gold_price', 'silver_vori', 'silver_price', 'business', 'other']) k: TextEditingController()};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final z = BrainScope.read(context).zakatSaved;
      String n(num v) => v == 0 ? '' : (v is double && v != v.roundToDouble() ? '$v' : '${v.round()}');
      _f['gold_vori']!.text = n(z.goldVori);
      _f['gold_price']!.text = n(z.goldPrice);
      _f['silver_vori']!.text = n(z.silverVori);
      _f['silver_price']!.text = n(z.silverPrice);
      _f['business']!.text = n(z.business);
      _f['other']!.text = n(z.other);
      setState(() {});
    });
  }

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final r = zakatFromRecords(brain.data, now);
    final z = zakatAuto(brain.data, now, brain.zakatSaved);
    Widget field(String k, String label, {String? hint, bool vori = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: _f[k],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) async {
              await brain.setZakatValue(k, asciiDigits(v).replaceAll(',', '').trim());
              if (mounted) setState(() {});
            },
            decoration: InputDecoration(labelText: label, hintText: hint, prefixText: vori ? null : tr('৳ '), suffixText: vori ? tr('ভরি') : null),
          ),
        );
    Widget fromApp(String label, int value, {String? note}) => ListRow(
          leading: Icon(Icons.auto_awesome_outlined, color: C.green, size: 20),
          title: label,
          subtitle: note ?? tr('অ্যাপের হিসাব থেকে'),
          trailing: Text(taka(value), style: body(16, weight: FontWeight.w600)),
        );
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('যাকাত হিসাব')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Panel(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(trf('যাকাতযোগ্য সম্পদ: {0}', [taka(math.max(0, z.net))]), style: body(15)),
                  const SizedBox(height: 6),
                  Text(
                    z.nisab <= 0 ? tr('নিসাব জানতে নিচে আজকের রুপার দাম দিন') : (z.due ? trf('যাকাত: {0}', [taka(z.zakat)]) : tr('নিসাবের কম — যাকাত ফরজ নয়')),
                    style: display(z.nisab <= 0 ? 17 : 24, weight: 700, color: z.due ? C.green : C.muted2),
                  ),
                  if (z.nisab > 0) Text(trf('নিসাব (৫২.৫ ভরি রুপা): {0}', [taka(z.nisab)]), style: body(12.5, color: C.muted)),
                ]),
              ),
              const SizedBox(height: 14),
              SectionTitle(tr('অ্যাপ নিজে হিসাব করেছে')),
              Panel(
                child: Rows(children: [
                  fromApp(tr('হাতে নগদ ও মোবাইল ব্যাংকিং'), r.cash, note: r.cashEstimated ? tr('আয়-ব্যয়ের ব্যালেন্স থেকে আনুমানিক — অ্যাকাউন্ট যোগ করলে ঠিক হিসাব') : null),
                  fromApp(tr('ব্যাংকে জমা, সঞ্চয়, DPS'), r.bank),
                  fromApp(tr('পাওনা টাকা (ফেরত পাওয়ার আশা আছে)'), r.receivable),
                  fromApp(tr('বাদ যাবে: দেনা ও সামনের ১২ মাসের লোনের কিস্তি'), r.debts),
                ]),
              ),
              const SizedBox(height: 6),
              Text(tr('এগুলো অ্যাকাউন্ট, সঞ্চয়, কিস্তি আর ধার-দেনা থেকে নিজে আসে; সেখানে বদলালে এখানেও বদলায়।'), style: body(12.5, color: C.muted, height: 1.4)),
              const SizedBox(height: 16),
              SectionTitle(tr('একবার লিখে দিন — মনে রাখবো')),
              Row(children: [
                Expanded(child: field('gold_vori', tr('সোনা'), vori: true)),
                const SizedBox(width: 10),
                Expanded(child: field('gold_price', tr('১ ভরি সোনার দাম'))),
              ]),
              Row(children: [
                Expanded(child: field('silver_vori', tr('রুপা'), vori: true)),
                const SizedBox(width: 10),
                Expanded(child: field('silver_price', tr('১ ভরি রুপার দাম'), hint: tr('বাজারদর'))),
              ]),
              field('business', tr('ব্যবসার মাল (বিক্রয়মূল্যে)')),
              field('other', tr('অন্যান্য (শেয়ার, বন্ড…)')),
              InfoBanner(text: tr('এক চান্দ্র বছর ধরে নিসাব পরিমাণ সম্পদ থাকলে মোট সম্পদের ২.৫% যাকাত। এটা আনুমানিক হিসাব — নিশ্চিত হতে আলেমের পরামর্শ নিন। মুখেও জিজ্ঞেস করা যায়: “আমার যাকাত কত?”'), icon: Icons.info_outline_rounded),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── Shop ─────────────────────────

/// The polite reminder sent to a customer who owes.
String dueMessage(String name, int amount) =>
    trf('আসসালামু আলাইকুম {0} ভাই, আপনার কাছে আমার {1} বাকি আছে। সুবিধামতো দিয়ে দিলে উপকার হয়। ধন্যবাদ।', [name, taka(amount)]);

/// A receipt (memo): items, total, paid; sent by WhatsApp; the sale and any
/// due are recorded.
class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, this.shop});

  /// The shop it is given in (its name heads the receipt, and it is kept there).
  final Shop? shop;
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  final _shop = TextEditingController();
  final _customer = TextEditingController();
  final _phone = TextEditingController();
  final _paid = TextEditingController();
  final _rows = <(TextEditingController, TextEditingController, TextEditingController)>[];

  @override
  void initState() {
    super.initState();
    _addRow();
    if (widget.shop != null) {
      _shop.text = widget.shop!.name;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final v = await BrainScope.read(context).services.lock.keys.read('shop_name');
      if (v != null && mounted) setState(() => _shop.text = v);
    });
  }

  void _addRow() => _rows.add((TextEditingController(), TextEditingController(text: '1'), TextEditingController()));

  @override
  void dispose() {
    for (final c in [_shop, _customer, _phone, _paid]) {
      c.dispose();
    }
    for (final r in _rows) {
      r.$1.dispose();
      r.$2.dispose();
      r.$3.dispose();
    }
    super.dispose();
  }

  List<ReceiptLine> get _lines => [
        for (final r in _rows)
          if (r.$1.text.trim().isNotEmpty && (readInt(r.$3.text) ?? 0) > 0) ReceiptLine(r.$1.text.trim(), readInt(r.$2.text) ?? 1, readInt(r.$3.text) ?? 0),
      ];

  Future<void> _send() async {
    final brain = BrainScope.read(context);
    final lines = _lines;
    if (lines.isEmpty) {
      toast(context, tr('অন্তত একটা জিনিস আর দাম লিখুন'));
      return;
    }
    final total = lines.fold(0, (s, l) => s + l.total);
    final paid = _paid.text.trim().isEmpty ? total : (readInt(_paid.text) ?? 0).clamp(0, total);
    final now = brain.services.now();
    final keys = brain.services.lock.keys;
    final shop = widget.shop ?? brain.data.shops.firstOrNull;
    final int no;
    if (shop != null) {
      no = nextReceiptNo(brain.data, shop);
    } else {
      no = (int.tryParse(await keys.read('receipt_no') ?? '') ?? 0) + 1;
      await keys.write('receipt_no', '$no');
      if (_shop.text.trim().isNotEmpty) await keys.write('shop_name', _shop.text.trim());
    }
    final text = receiptText(shop: _shop.text, customer: _customer.text, lines: lines, paid: paid, date: now, no: no);
    // Record it: the paid part as a sale, the rest as the customer's due.
    if (paid > 0) {
      await brain.saveCash(CashEntry(kind: CashKind.income, amount: paid, category: salesCategory, note: lines.map((l) => l.item).join(', '), date: now, shopId: shop?.id));
    }
    if (total - paid > 0 && _customer.text.trim().isNotEmpty) {
      await brain.saveEntry(LedgerEntry(person: _customer.text.trim(), phone: _phone.text.trim(), kind: LedgerKind.lent, amount: total - paid, date: dayOnly(now), note: trf('রসিদ #{0}', [no]), shopId: shop?.id));
    }
    if (shop != null) {
      await brain.saveReceipt(Receipt(
        shopId: shop.id,
        no: no,
        customer: _customer.text.trim(),
        phone: _phone.text.trim(),
        items: [for (final l in lines) (l.item, l.qty, l.price)],
        paid: paid,
        date: now,
      ));
    }
    if (_phone.text.trim().isNotEmpty) {
      await brain.services.launcher.open(Via.whatsapp, _phone.text.trim(), text: text);
    } else {
      await brain.services.files.shareText(text);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final lines = _lines;
    final total = lines.fold(0, (s, l) => s + l.total);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('রসিদ / মেমো')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              if (widget.shop == null) ...[
                TextField(controller: _shop, decoration: InputDecoration(labelText: tr('দোকানের নাম'))),
                const SizedBox(height: 10),
              ],
              Row(children: [
                Expanded(child: TextField(controller: _customer, decoration: InputDecoration(labelText: tr('গ্রাহকের নাম')))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: tr('মোবাইল (ঐচ্ছিক)')))),
              ]),
              FieldLabel(tr('জিনিস')),
              for (final r in _rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Expanded(flex: 5, child: TextField(controller: r.$1, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: tr('জিনিসের নাম'), isDense: true))),
                    const SizedBox(width: 6),
                    Expanded(flex: 2, child: TextField(controller: r.$2, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: tr('সংখ্যা'), isDense: true))),
                    const SizedBox(width: 6),
                    Expanded(flex: 3, child: TextField(controller: r.$3, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: tr('দাম'), isDense: true))),
                  ]),
                ),
              TextButton.icon(onPressed: () => setState(_addRow), icon: const Icon(Icons.add_rounded), label: Text(tr('আরেকটা জিনিস'))),
              const SizedBox(height: 6),
              Text(trf('মোট: {0}', [taka(total)]), style: display(22, weight: 700)),
              const SizedBox(height: 10),
              TextField(
                controller: _paid,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: tr('কত দিলেন (খালি = পুরোটা)'), prefixText: tr('৳ ')),
              ),
              const SizedBox(height: 8),
              Text(tr('পাঠালে বিক্রি “বিক্রি” খাতে উঠবে; বাকি থাকলে গ্রাহকের নামে লেনদেনের খাতায় লেখা হবে।'), style: body(12.5, color: C.muted, height: 1.4)),
              const SizedBox(height: 16),
              PrimaryButton(label: tr('রসিদ পাঠান ও রাখুন'), icon: Icons.send_rounded, onPressed: _send),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A goal's deposits, each one changed or taken out.
Future<void> _deposits(BuildContext context, String goalId) async {
  final brain = BrainScope.read(context);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => ListenableBuilder(
      listenable: brain,
      builder: (ctx, _) {
        final g = brain.data.goals.where((x) => x.id == goalId).firstOrNull;
        if (g == null) return const SizedBox(height: 40);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
              Text(trf('{0} — জমা', [g.name]), style: display(18, weight: 700)),
              const SizedBox(height: 8),
              for (var i = g.deposits.length - 1; i >= 0; i--)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(taka(g.deposits[i].amount), style: body(16, weight: FontWeight.w600)),
                  subtitle: Text(shortDate(g.deposits[i].date), style: body(13, color: C.muted)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: tr('বদলান'),
                      icon: Icon(Icons.edit_outlined, color: C.muted2),
                      onPressed: () async {
                        final v = readInt(await askText(ctx, tr('কত জমালেন?'), initial: '${g.deposits[i].amount}', number: true));
                        if (v == null || v <= 0) return;
                        final list = [...g.deposits]..[i] = GoalDeposit(v, g.deposits[i].date);
                        await brain.saveGoal(g.copyWith(deposits: list));
                      },
                    ),
                    IconButton(
                      tooltip: tr('মুছুন'),
                      icon: Icon(Icons.delete_outline_rounded, color: C.muted2),
                      onPressed: () async {
                        if (!await confirmDialog(ctx, title: tr('মুছবেন?'), text: trf('{0} জমা মুছে যাবে।', [taka(g.deposits[i].amount)]), yes: tr('মুছুন'), danger: true)) return;
                        final list = [...g.deposits]..removeAt(i);
                        await brain.saveGoal(g.copyWith(deposits: list));
                      },
                    ),
                  ]),
                ),
            ]),
          ),
        );
      },
    ),
  );
}
