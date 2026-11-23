// Owner, 23 Nov: "সঞ্চয় ও কিস্তির জন্য আলাদা স্ক্রিন — সঞ্চয় কিসে করা
// হচ্ছে, মেয়াদ, পেমেন্টের ধরণ, আগে কত দিয়েছে, কত গুলো বাকি আছে,
// রিমাইন্ডার; কিস্তির ক্ষেত্রেও তাই।"
import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/money_more.dart' show accountLabel;
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/forms.dart';
import '../ui/pdf_export.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'money_hub.dart' show MoneyEye, hid, accountIcon;
import 'money_more_screens.dart' show editGoal, goalDeposits;

void _push(BuildContext context, Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

(IconData, Color, Color) kindLook(InstallmentKind k) => switch (k) {
      InstallmentKind.dps => (Icons.savings_outlined, C.teal, C.tealTint),
      InstallmentKind.fdr => (Icons.lock_clock_outlined, C.blue, C.blueTint),
      InstallmentKind.sanchay => (Icons.receipt_long_outlined, C.green, C.greenTint),
      InstallmentKind.samity => (Icons.groups_outlined, C.ochre, C.ochreTint),
      InstallmentKind.insurance => (Icons.health_and_safety_outlined, C.purple, C.purpleTint),
      InstallmentKind.savingOther => (Icons.account_balance_wallet_outlined, C.teal, C.tealTint),
      InstallmentKind.loan => (Icons.account_balance_outlined, C.rose, C.roseTint),
      InstallmentKind.ngo => (Icons.diversity_3_outlined, C.ochre, C.ochreTint),
      InstallmentKind.emi => (Icons.credit_card_rounded, C.purple, C.purpleTint),
      InstallmentKind.other => (Icons.event_repeat_outlined, C.rose, C.roseTint),
    };

String _cycleText(Installment i) => switch (i.cycle) {
      PayCycle.monthly => trf('মাসিক · প্রতি মাসের {0} তারিখ', [bnDigits(i.dayOfMonth)]),
      PayCycle.weekly => trf('সাপ্তাহিক · প্রতি {0}', [weekdayName(i.start)]),
      PayCycle.quarterly => trf('তিন মাসে একবার · {0} তারিখ', [bnDigits(i.dayOfMonth)]),
      PayCycle.yearly => trf('বাৎসরিক · প্রতি বছর {0}', [shortDate(i.dueAt(0))]),
      PayCycle.once => tr('এককালীন'),
    };

String _per(PayCycle c) => switch (c) {
      PayCycle.monthly => tr('/মাস'),
      PayCycle.weekly => tr('/সপ্তাহ'),
      PayCycle.quarterly => tr('/৩ মাস'),
      PayCycle.yearly => tr('/বছর'),
      PayCycle.once => '',
    };

/// "৫ বছর", "১ বছর ৬ মাস", "৪০ সপ্তাহ": the term in words.
String termText(PayCycle c, int n) {
  if (c == PayCycle.once) return tr('একবার');
  if (c == PayCycle.weekly) return trf('{0} সপ্তাহ', [bnDigits(n)]);
  final months = n * c.months;
  final y = months ~/ 12, m = months % 12;
  return [if (y > 0) trf('{0} বছর', [bnDigits(y)]), if (m > 0) trf('{0} মাস', [bnDigits(m)])].join(' ');
}

String _when(DateTime d, DateTime now) {
  final n = dayOnly(d).difference(dayOnly(now)).inDays;
  if (n == 0) return tr('আজ');
  if (n == 1) return tr('আগামীকাল');
  if (n < 0) return trf('{0} দিন পার', [bnDigits(-n)]);
  return trf('{0} দিন পর', [bnDigits(n)]);
}

// ───────────────────────── The list ─────────────────────────

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key, this.loans = false});

  /// Opens on কিস্তি.
  final bool loans;

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  late int _tab = widget.loans ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final saves = d.installments.where((i) => i.saving).toList();
    final loans = d.installments.where((i) => !i.saving).toList();
    int dueSort(Installment a, Installment b) => (a.nextDue ?? DateTime(9999)).compareTo(b.nextDue ?? DateTime(9999));
    saves.sort(dueSort);
    loans.sort(dueSort);
    final saved = saves.fold<int>(0, (a, i) => a + i.paidTotal) + d.goals.fold<int>(0, (a, g) => a + g.saved);
    final owed = loans.fold(0, (a, i) => a + i.left * i.amount);
    final thisMonth = [
      for (final i in d.installments)
        if (i.indexIn(now) != null && !i.paidAt(i.indexIn(now)!)) i
    ];
    final dueMonth = thisMonth.fold(0, (a, i) => a + i.amount);

    return Scaffold(
      floatingActionButton: AddButton(
        key: const Key('plan-add'),
        label: _tab == 0 ? tr('সঞ্চয় যোগ করুন') : tr('কিস্তি যোগ করুন'),
        onPressed: () => _push(context, PlanFormScreen(saving: _tab == 0)),
      ),
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('সঞ্চয় ও কিস্তি'), trailing: const [PdfButton({ReportPart.accounts})]),
          Expanded(
            child: TabPages<int>(
              items: [(0, trf('সঞ্চয় · {0}', [bnDigits(saves.length + d.goals.length)])), (1, trf('কিস্তি · {0}', [bnDigits(loans.length)]))],
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              top: (tabs) => [
                Panel(
                  key: const Key('plans-total'),
                  padding: const EdgeInsets.fromLTRB(16, 8, 6, 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [Expanded(child: Text(tr('সব মিলিয়ে'), style: body(13.5, weight: FontWeight.w600, color: C.muted2))), const MoneyEye()]),
                    IntrinsicHeight(
                      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Expanded(child: _Fig(label: tr('মোট জমা'), value: hid(context, taka(saved)), color: C.teal)),
                        VerticalDivider(width: 24, color: C.border),
                        Expanded(child: _Fig(label: tr('কিস্তি শোধ বাকি'), value: hid(context, taka(owed)), color: C.rose)),
                      ]),
                    ),
                    if (thisMonth.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(color: C.warnBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.warnBorder)),
                        child: Row(children: [
                          Icon(Icons.event_note_outlined, size: 16, color: C.warn),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(trf('{0}-এ আরও দিতে হবে {1} · {2}টি', [monthName(now.month), hid(context, taka(dueMonth)), bnDigits(thisMonth.length)]),
                                style: body(12.5, weight: FontWeight.w600, color: C.warn)),
                          ),
                        ]),
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 14),
                tabs,
                const SizedBox(height: 14),
              ],
              page: (tab) => tab == 0
                  ? [
                      if (saves.isEmpty && d.goals.isEmpty)
                        EmptyState(
                          icon: Icons.savings_outlined,
                          title: tr('কোনো সঞ্চয় রাখা নেই'),
                          text: tr('DPS, FDR, সঞ্চয়পত্র, সমিতি, বীমা — কোথায়, কত করে, কত মেয়াদে দিন। কত জমলো, কত বাকি দেখাবে, দেওয়ার আগের দিন মনে করাবে।'),
                        ),
                      for (final i in saves) Padding(padding: const EdgeInsets.only(bottom: 10), child: PlanCard(plan: i, now: now)),
                      const SizedBox(height: 6),
                      SectionTitle(tr('জমানোর লক্ষ্য'), action: tr('লক্ষ্য যোগ'), onAction: () => editGoal(context, null)),
                      if (d.goals.isEmpty)
                        Text(tr('ঈদ, ভ্রমণ, নতুন ফোন — লক্ষ্য ঠিক করে একটু একটু জমান।'), style: body(13, color: C.muted))
                      else
                        for (final g in d.goals) Padding(padding: const EdgeInsets.only(bottom: 10), child: _GoalCard(goal: g, now: now)),
                    ]
                  : [
                      if (loans.isEmpty)
                        EmptyState(
                          icon: Icons.event_repeat_outlined,
                          title: tr('কোনো কিস্তি রাখা নেই'),
                          text: tr('ব্যাংক লোন, এনজিও লোন, কার্ডের EMI — কোথায়, কত করে, কয়টা কিস্তি দিন। কতগুলো দিলেন, কত বাকি দেখাবে, দেওয়ার আগের দিন মনে করাবে।'),
                        ),
                      for (final i in loans) Padding(padding: const EdgeInsets.only(bottom: 10), child: PlanCard(plan: i, now: now)),
                    ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Fig extends StatelessWidget {
  const _Fig({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: body(12.5, color: C.muted)),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: display(22, weight: 700, color: color, height: 1.3))),
      ]);
}

/// One সঞ্চয় or কিস্তি on the list: where, how much each time, how far
/// along, the next payment and its reminder; "দিলাম" ticks the next one.
class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.now});
  final Installment plan;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final i = plan;
    final (icon, fg, bg) = kindLook(i.kind);
    final kindName = isEn ? i.kind.en : i.kind.bn;
    final next = i.nextDue;
    final late = next != null && dayOnly(next).isBefore(dayOnly(now));
    final soon = next != null && dayOnly(next).difference(dayOnly(now)).inDays <= 3;
    final share = i.months == 0 ? 0.0 : i.paidCount / i.months;
    return Panel(
      key: Key('plan-${i.id}'),
      borderColor: late ? C.warnBorder : null,
      child: InkWell(
        onTap: () => _push(context, PlanScreen(id: i.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: fg)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15.5, weight: FontWeight.w700)),
                  Text([if (i.place.trim().isNotEmpty) i.place.trim(), kindName].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: hid(context, taka(i.amount)), style: display(16.5, weight: 700)),
                  TextSpan(text: _per(i.cycle), style: body(11.5, color: C.muted)),
                ])),
              ),
            ]),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: share, minHeight: 7, color: fg, backgroundColor: C.surface2)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(children: [
                Expanded(
                  child: Text(trf(i.saving ? '{0}/{1} দেওয়া · জমা {2}' : '{0}/{1} দেওয়া · শোধ {2}', [bnDigits(i.paidCount), bnDigits(i.months), hid(context, taka(i.paidTotal))]),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted2)),
                ),
                Text(i.left == 0 ? tr('শেষ') : trf('বাকি {0}টি', [bnDigits(i.left)]), style: body(12, weight: FontWeight.w600, color: i.left == 0 ? C.green : C.muted2)),
              ]),
            ),
            const SizedBox(height: 6),
            Divider(height: 1, color: C.line, endIndent: 6),
            Row(children: [
              Icon(next == null ? Icons.verified_outlined : Icons.event_outlined, size: 15, color: late ? C.red : (soon ? C.warn : C.muted)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  next == null ? trf('সব দেওয়া হয়েছে · শেষ {0}', [shortDate(i.end)]) : trf('পরের {0} · {1}', [shortDate(next), _when(next, now)]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: body(12.5, weight: soon || late ? FontWeight.w600 : FontWeight.w400, color: late ? C.red : (soon ? C.warn : C.muted)),
                ),
              ),
              Tooltip(
                message: i.remind ? tr('রিমাইন্ডার চালু') : tr('রিমাইন্ডার বন্ধ'),
                child: Icon(i.remind ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, size: 18, color: i.remind ? C.green : C.muted),
              ),
              if (next != null)
                TextButton(
                  key: Key('plan-pay-${i.id}'),
                  onPressed: () async {
                    await brain.toggleInstallmentAt(i, i.nextIndex!);
                    if (context.mounted) toast(context, trf('{0}-এর কিস্তি দেওয়া হিসেবে রাখলাম', [shortDate(next)]));
                  },
                  child: Text(tr('দিলাম'), style: body(13.5, weight: FontWeight.w700, color: C.green)),
                )
              else
                const SizedBox(height: 44),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.now});
  final SavingsGoal goal;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final g = goal;
    final done = g.saved >= g.target;
    return Panel(
      child: InkWell(
        onTap: () => editGoal(context, g),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(13)), child: Icon(Icons.flag_outlined, color: C.green)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15.5, weight: FontWeight.w700)),
                  Text(
                    done
                        ? tr('লক্ষ্য পূরণ হয়েছে')
                        : g.deadline == null
                            ? trf('লক্ষ্য {0}', [hid(context, taka(g.target))])
                            : trf('{0}-এর মধ্যে · মাসে {1} করে', [shortDate(g.deadline!), hid(context, taka(g.perMonth(now) ?? 0))]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: body(12, color: done ? C.green : C.muted),
                  ),
                ]),
              ),
              Padding(padding: const EdgeInsets.only(right: 6), child: Text(hid(context, taka(g.saved)), style: display(16.5, weight: 700))),
            ]),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: g.progress, minHeight: 7, color: C.green, backgroundColor: C.surface2)),
            ),
            Row(children: [
              Expanded(child: Text(trf('{0}% জমেছে', [bnDigits((g.progress * 100).round())]), style: body(12, color: C.muted2))),
              if (g.deposits.isNotEmpty) TextButton(onPressed: () => goalDeposits(context, g.id), child: Text(tr('জমার হিসাব'), style: body(13, color: C.muted2))),
              TextButton(
                onPressed: () async {
                  final v = readInt(await askText(context, tr('কত জমালেন?'), number: true));
                  if (v != null && v > 0) await brain.addDeposit(g, v);
                },
                child: Text(tr('+ জমা'), style: body(13.5, weight: FontWeight.w700, color: C.green)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── One plan ─────────────────────────

/// One সঞ্চয় or কিস্তি in full: what and where, the term and how it is
/// paid, what is paid and what is left, the reminder, and every payment.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key, required this.id});
  final String id;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final i = brain.data.installments.where((x) => x.id == widget.id).firstOrNull;
    if (i == null) return Scaffold(body: SafeArea(child: Column(children: [TopBar(title: tr('সঞ্চয় ও কিস্তি'))])));
    final (icon, fg, bg) = kindLook(i.kind);
    final kindName = isEn ? i.kind.en : i.kind.bn;
    final acc = i.accountId == null ? null : brain.data.accounts.where((a) => a.id == i.accountId).firstOrNull;
    final share = i.months == 0 ? 0.0 : i.paidCount / i.months;
    // The payments around now: the last three and the next three; all on a tap.
    final nextAt = i.nextIndex ?? i.months;
    final shown = [for (var n = 0; n < i.months; n++) if (_all || (n >= nextAt - 3 && n <= nextAt + 2)) n];

    Widget fact(String label, String value, {Color? color}) => Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted)),
            const SizedBox(height: 2),
            Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w700, color: color ?? C.ink, height: 1.3)),
          ]),
        );
    final facts = <(String, String, Color?)>[
      (tr('কিসে'), [kindName, if (i.place.trim().isNotEmpty) i.place.trim()].join(' · '), null),
      (tr('পেমেন্টের ধরন'), _cycleText(i), null),
      (tr('প্রতি কিস্তি'), hid(context, taka(i.amount)), null),
      (tr('মেয়াদ'), '${trf('{0}টি কিস্তি', [bnDigits(i.months)])} · ${termText(i.cycle, i.months)}', null),
      (tr('শুরু'), fullDate(i.dueAt(0)), null),
      (tr('শেষ'), fullDate(i.end), null),
      (tr('দেওয়া হয়েছে'), '${trf('{0}টি', [bnDigits(i.paidCount)])} · ${hid(context, taka(i.paidTotal))}', C.green),
      (tr('বাকি'), '${trf('{0}টি', [bnDigits(i.left)])} · ${hid(context, taka(i.left * i.amount))}', i.left > 0 ? C.warn : C.green),
      if (i.lump > 0) (i.saving ? tr('মেয়াদ শেষে পাবেন') : tr('লোন নিয়েছিলেন'), hid(context, taka(i.lump)), null),
      if (acc != null) (tr('যে অ্যাকাউন্ট থেকে'), accountLabel(acc), null),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: i.name, trailing: [
            IconButton(key: const Key('plan-edit'), tooltip: tr('বদলান'), onPressed: () => _push(context, PlanFormScreen(saving: i.saving, old: i)), icon: const Icon(Icons.edit_outlined)),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 16),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Icon(icon, color: fg, size: 20),
                    const SizedBox(width: 6),
                    Expanded(child: Text(i.saving ? tr('জমা হয়েছে') : tr('শোধ হয়েছে'), style: body(13.5, weight: FontWeight.w600, color: C.muted2))),
                    const MoneyEye(),
                  ]),
                  Text(hid(context, taka(i.paidTotal)), style: display(30, weight: 700, height: 1.2)),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: share, minHeight: 9, color: fg, backgroundColor: C.surface)),
                  ),
                  const SizedBox(height: 6),
                  Text(trf('মোট {0}-এর {1}% · {2}/{3} কিস্তি', [hid(context, taka(i.total)), bnDigits((share * 100).round()), bnDigits(i.paidCount), bnDigits(i.months)]), style: body(12.5, color: C.muted2)),
                ]),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, c) {
                  final w = (c.maxWidth - 10) / 2;
                  return Wrap(spacing: 10, runSpacing: 10, children: [for (final (l, v, col) in facts) SizedBox(width: w, child: fact(l, v, color: col))]);
                },
              ),
              const SizedBox(height: 14),
              Panel(
                child: SwitchListTile(
                  key: const Key('plan-remind'),
                  value: i.remind,
                  onChanged: (v) => brain.saveInstallment(i.copyWith(remind: v)),
                  secondary: Icon(i.remind ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, color: i.remind ? C.green : C.muted),
                  title: Text(tr('রিমাইন্ডার'), style: body(15, weight: FontWeight.w600)),
                  subtitle: Text(
                    i.remind
                        ? (i.nextDue == null ? tr('সব দেওয়া হয়ে গেছে') : trf('কিস্তির আগের দিন সকাল ১০টায় · পরেরটা {0}', [shortDate(i.nextDue!)]))
                        : tr('বন্ধ — চালু করলে আগের দিন মনে করাব'),
                    style: body(12.5, color: C.muted),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SectionTitle(tr('কিস্তির হিসাব')),
              Panel(
                child: Column(children: [
                  for (final (k, n) in shown.indexed) ...[
                    if (k > 0) Divider(height: 1, color: C.line, indent: 14, endIndent: 14),
                    _PayRow(plan: i, n: n, now: now),
                  ],
                ]),
              ),
              if (!_all && shown.length < i.months)
                TextButton(onPressed: () => setState(() => _all = true), child: Text(trf('সব {0}টি কিস্তি দেখুন', [bnDigits(i.months)]))),
              const SizedBox(height: 6),
              Text(tr('কোনো কিস্তিতে চাপ দিলে দেওয়া বা বাকি হিসেবে বদলাবে।'), style: body(12, color: C.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  const _PayRow({required this.plan, required this.n, required this.now});
  final Installment plan;
  final int n;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final at = plan.dueAt(n);
    final paid = plan.paidAt(n);
    final past = dayOnly(at).isBefore(dayOnly(now));
    final (label, fg, bg) = paid ? (tr('দেওয়া'), C.green, C.greenTint) : (past ? (tr('বাকি পড়েছে'), C.red, C.roseTint) : (tr('সামনে'), C.muted2, C.surface2));
    return InkWell(
      key: Key('pay-$n'),
      onTap: () => brain.toggleInstallmentAt(plan, n),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(children: [
          SizedBox(width: 34, child: Text(bnDigits(n + 1), style: body(13, weight: FontWeight.w700, color: C.muted))),
          Expanded(child: Text(fullDate(at), style: body(14))),
          Text(hid(context, taka(plan.amount)), style: body(14, weight: FontWeight.w600)),
          const SizedBox(width: 10),
          Container(
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
            child: Text(label, textAlign: TextAlign.center, style: body(11.5, weight: FontWeight.w600, color: fg)),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── The form ─────────────────────────

/// A new সঞ্চয় or কিস্তি, or [old] changed.
class PlanFormScreen extends StatefulWidget {
  const PlanFormScreen({super.key, required this.saving, this.old});
  final bool saving;
  final Installment? old;

  @override
  State<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanFormScreenState extends State<PlanFormScreen> {
  late final _old = widget.old;
  late InstallmentKind _kind = _old?.kind ?? (widget.saving ? InstallmentKind.dps : InstallmentKind.loan);
  late final _place = TextEditingController(text: _old?.place ?? '');
  late final _name = TextEditingController(text: _old?.name ?? '');
  late final _amount = TextEditingController(text: _old == null ? '' : bnDigits('${_old.amount}'));
  late final _count = TextEditingController(text: bnDigits('${_old?.months ?? 60}'));
  late final _lump = TextEditingController(text: _old == null || _old.lump == 0 ? '' : bnDigits('${_old.lump}'));
  late PayCycle _cycle = _old?.cycle ?? PayCycle.monthly;
  late DateTime _first = _old?.dueAt(0) ?? () {
    final now = BrainScope.read(context).services.now();
    return DateTime(now.year, now.month, 10);
  }();
  late final _before = TextEditingController(text: _old == null ? '' : bnDigits('${_old.paidCount}'));
  late bool _remind = _old?.remind ?? true;
  late String? _accountId = _old?.accountId;

  bool get _saving => _kind.saving;

  @override
  void dispose() {
    for (final c in [_place, _name, _amount, _count, _lump, _before]) {
      c.dispose();
    }
    super.dispose();
  }

  /// How many payments fell before today (a plan started in the past).
  int _passed(DateTime now) {
    final n = readInt(_count.text) ?? 0;
    final probe = Installment(name: '', amount: 1, start: _first, dayOfMonth: _first.day.clamp(1, 28), months: n, cycle: _cycle);
    var c = 0;
    for (var i = 0; i < n; i++) {
      if (probe.dueAt(i).isBefore(dayOnly(now))) c++;
    }
    return c;
  }

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    final amount = readInt(_amount.text) ?? 0;
    if (amount <= 0) {
      toast(context, tr('প্রতি কিস্তিতে কত টাকা, লিখুন'));
      return;
    }
    final count = _cycle == PayCycle.once ? 1 : (readInt(_count.text) ?? 0).clamp(1, 1200);
    final kindName = isEn ? _kind.en : _kind.bn;
    final name = _name.text.trim().isNotEmpty ? _name.text.trim() : [if (_place.text.trim().isNotEmpty) _place.text.trim(), kindName].join(' ');
    var plan = (_old ?? Installment(name: name, amount: amount, start: _first)).copyWith(
      name: name,
      kind: _kind,
      amount: amount,
      months: count,
      start: _cycle == PayCycle.weekly ? dayOnly(_first) : DateTime(_first.year, _first.month),
      dayOfMonth: _first.day.clamp(1, 28),
      place: _place.text.trim(),
      cycle: _cycle,
      lump: readInt(_lump.text) ?? 0,
      remind: _remind,
      accountId: _accountId,
    );
    // "আগে কয়টি দেওয়া হয়েছে": the first that many are ticked.
    final before = (readInt(_before.text) ?? 0).clamp(0, count);
    if (_old == null || before != _old.paidCount || _cycle != _old.cycle || _first != _old.dueAt(0)) {
      plan = plan.copyWith(paid: [for (var n = 0; n < before; n++) plan.keyAt(n)]);
    }
    await brain.saveInstallment(plan);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final brain = BrainScope.read(context);
    final nav = Navigator.of(context);
    if (!await confirmDialog(context, title: tr('মুছবেন?'), text: tr('৩০ দিন “রিসাইকেল বিন”-এ থাকবে।'), yes: tr('মুছুন'), danger: true)) return;
    await brain.deleteInstallment(_old!);
    nav.popUntil((r) => r.isFirst || r.settings.name == null && !nav.canPop());
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final kinds = [for (final k in InstallmentKind.values) if (k.saving == widget.saving) k];
    final count = readInt(_count.text) ?? 0;
    final passed = _passed(now);
    final places = _saving
        ? [tr('সোনালী ব্যাংক'), tr('ডাচ-বাংলা ব্যাংক'), tr('ইসলামী ব্যাংক'), tr('ব্র্যাক ব্যাংক'), tr('পোস্ট অফিস'), tr('এলাকার সমিতি')]
        : [tr('সোনালী ব্যাংক'), tr('ব্র্যাক'), tr('আশা'), tr('গ্রামীণ ব্যাংক'), tr('সিটি ব্যাংক কার্ড')];
    InputDecoration taka0([String? hint]) => InputDecoration(prefixText: '৳ ', hintText: hint);

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: _old != null ? (widget.saving ? tr('সঞ্চয় বদলান') : tr('কিস্তি বদলান')) : (widget.saving ? tr('নতুন সঞ্চয়') : tr('নতুন কিস্তি')), trailing: [
            if (_old != null) IconButton(tooltip: tr('মুছুন'), onPressed: _delete, icon: Icon(Icons.delete_outline_rounded, color: C.red)),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              FieldLabel(widget.saving ? tr('কিসে সঞ্চয় করছেন') : tr('কিসের কিস্তি')),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final k in kinds)
                  ChoiceChip(
                    avatar: Icon(kindLook(k).$1, size: 16),
                    label: Text(isEn ? k.en : k.bn, style: body(13)),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ]),
              FieldLabel(widget.saving ? tr('কোথায় (ব্যাংক, সমিতি, প্রতিষ্ঠান)') : tr('কোথা থেকে নেওয়া (ব্যাংক, এনজিও)')),
              TextField(key: const Key('plan-place'), controller: _place, textCapitalization: TextCapitalization.words, decoration: InputDecoration(hintText: places.first)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final p in places) ActionChip(label: Text(p, style: body(12.5)), onPressed: () => setState(() => _place.text = p))]),
              FieldLabel(tr('নাম (ঐচ্ছিক)')),
              TextField(controller: _name, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(hintText: widget.saving ? tr('যেমন: মেয়ের পড়ালেখার DPS') : tr('যেমন: বাইকের লোন'))),
              FieldLabel(tr('পেমেন্টের ধরন')),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final c in PayCycle.values)
                  if (c != PayCycle.once || _kind == InstallmentKind.fdr || _kind == InstallmentKind.sanchay || widget.old?.cycle == PayCycle.once)
                    ChoiceChip(label: Text(isEn ? c.en : c.bn, style: body(13)), selected: _cycle == c, onSelected: (_) => setState(() => _cycle = c)),
              ]),
              FieldLabel(_cycle == PayCycle.once ? tr('কত টাকা রেখেছেন') : tr('প্রতি কিস্তিতে কত টাকা')),
              TextField(key: const Key('plan-amount'), controller: _amount, keyboardType: TextInputType.number, decoration: taka0()),
              if (_cycle != PayCycle.once) ...[
                FieldLabel(tr('মেয়াদ: মোট কয়টি কিস্তি')),
                TextField(key: const Key('plan-count'), controller: _count, keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
                if (count > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(trf('= {0} · মোট {1}', [termText(_cycle, count), taka(count * (readInt(_amount.text) ?? 0))]), style: body(12.5, color: C.muted)),
                  ),
              ],
              FieldLabel(_cycle == PayCycle.once ? tr('কবে রেখেছেন') : tr('প্রথম কিস্তির তারিখ')),
              OutlinedButton.icon(
                key: const Key('plan-first'),
                onPressed: () async {
                  final p = await showDatePicker(context: context, initialDate: _first, firstDate: DateTime(1990), lastDate: DateTime(now.year + 30));
                  if (p != null) setState(() => _first = p);
                },
                icon: const Icon(Icons.event_outlined),
                label: Text(fullDate(_first)),
              ),
              if (_cycle != PayCycle.once) ...[
                FieldLabel(tr('আগে কয়টি কিস্তি দেওয়া হয়ে গেছে')),
                TextField(key: const Key('plan-before'), controller: _before, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: bnDigits('$passed'))),
                if (passed > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => setState(() => _before.text = bnDigits('$passed')),
                      child: Text(trf('আজ পর্যন্ত {0}টির তারিখ গেছে — সবগুলো দেওয়া ধরুন', [bnDigits(passed)])),
                    ),
                  ),
              ],
              FieldLabel(_saving ? tr('মেয়াদ শেষে কত পাবেন (ঐচ্ছিক)') : tr('মোট কত টাকা লোন নিয়েছেন (ঐচ্ছিক)')),
              TextField(controller: _lump, keyboardType: TextInputType.number, decoration: taka0()),
              if (brain.data.accounts.isNotEmpty) ...[
                FieldLabel(tr('কোন অ্যাকাউন্ট থেকে দেন (ঐচ্ছিক)')),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final a in brain.data.accounts)
                    ChoiceChip(
                      avatar: Icon(accountIcon(a.kind), size: 16),
                      label: Text(accountLabel(a), style: body(13)),
                      selected: _accountId == a.id,
                      onSelected: (on) => setState(() => _accountId = on ? a.id : null),
                    ),
                ]),
              ],
              const SizedBox(height: 12),
              Panel(
                child: SwitchListTile(
                  value: _remind,
                  onChanged: (v) => setState(() => _remind = v),
                  secondary: Icon(_remind ? Icons.notifications_active_outlined : Icons.notifications_off_outlined, color: _remind ? C.green : C.muted),
                  title: Text(tr('রিমাইন্ডার'), style: body(15, weight: FontWeight.w600)),
                  subtitle: Text(tr('প্রতিটা কিস্তির আগের দিন সকাল ১০টায় মনে করাব'), style: body(12.5, color: C.muted)),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: PrimaryButton(key: const Key('plan-save'), label: tr('রাখুন'), icon: Icons.check_rounded, onPressed: _save),
          ),
        ]),
      ),
    );
  }
}
