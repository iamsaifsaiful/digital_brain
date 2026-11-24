import 'package:flutter/material.dart';

import '../../logic/biz_account.dart';
import '../../logic/bn.dart';
import '../../logic/lang.dart';
import '../../logic/shop_logic.dart' show qtyText;
import '../../state/brain.dart';
import '../../ui/kit.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'biz_money.dart' show LoanListPage, SupplierListPage;
import 'biz_parts.dart';
import 'biz_setup.dart';
import 'biz_tx.dart';

String _signed(int n, {bool plus = true}) => n < 0 ? '− ${taka(-n)}' : '${plus ? '+ ' : ''}${taka(n)}';

/// A titled card of lines that end in a total.
class _Block extends StatelessWidget {
  const _Block({required this.title, this.sub, required this.lines, this.total, this.onTap, this.icon, this.fg, this.bg});
  final String title;
  final String? sub;
  final List<(String label, int amount, bool signed)> lines;
  final (String, int, Color?)? total;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? fg;
  final Color? bg;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (icon != null) ...[
                Container(width: 30, height: 30, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 17, color: fg)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: body(15, weight: FontWeight.w600)),
                  if (sub != null) Text(sub!, style: body(12, color: C.muted)),
                ]),
              ),
              if (onTap != null) Icon(Icons.chevron_right_rounded, color: C.muted),
            ]),
            const SizedBox(height: 6),
            for (final (label, amount, signed) in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(label, style: body(13.5, color: C.ink))),
                  Text(signed ? _signed(amount) : taka(amount), style: body(13.5, weight: FontWeight.w500, color: signed && amount < 0 ? C.red : C.ink)),
                ]),
              ),
            if (total != null) ...[
              const SizedBox(height: 4),
              const Hairline(),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Expanded(child: Text(total!.$1, style: body(14, weight: FontWeight.w700))),
                  Text(total!.$2 < 0 ? '− ${taka(-total!.$2)}' : taka(total!.$2), style: body(15, weight: FontWeight.w700, color: total!.$3 ?? C.ink)),
                ]),
              ),
            ],
          ]),
        ),
      );
}

/// Lines with nothing in them are left out (the start is always shown).
List<(String, int, bool)> _nz(List<(String, int, bool)> xs) => [for (final x in xs) if (x.$2 != 0) x];

/// ব্যবসার পুরো হিসাব — all of it, since the start (owner, 23 Nov: the main
/// card opens the whole account, "সব সময়ের, নির্দিষ্ট দিনের না"). Every
/// sum: where it began, what moved it, where it is now; and whether it all
/// adds up.
class BizAccountPage extends StatelessWidget {
  const BizAccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final acc = bizAccount(b, brain.data.cash);
    final s0 = acc.start.sums, f = acc.flows, now = acc.now;
    final started = b.start == null ? tr('শুরু থেকে') : trf('{0} থেকে আজ পর্যন্ত', [fullDate(acc.start.at)]);
    final capChange = now.capital - s0.capital;
    return Scaffold(
      body: BizRefresh(child: SafeArea(
        child: Column(children: [
          InnerTop(title: tr('ব্যবসার পুরো হিসাব'), sub: started),
          Expanded(
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 6, 20, 32), children: [
              // Does it add up?
              Container(
                key: Key(acc.adds ? 'biz-acc-ok' : 'biz-acc-gap'),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(color: acc.adds ? C.greenTint : C.warnBg, borderRadius: BorderRadius.circular(13)),
                child: Row(children: [
                  Icon(acc.adds ? Icons.verified_outlined : Icons.error_outline_rounded, color: acc.adds ? C.green : C.warn, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      acc.adds ? tr('সব হিসাব মিলেছে — শুরু + লেনদেন = এখন') : tr('কোথাও হিসাব মিলছে না — নিচে লাল দাগ দেওয়া জায়গা দেখুন'),
                      style: body(13, weight: FontWeight.w500, color: acc.adds ? C.greenDark : C.warn),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              // The capital: then and now.
              AppCard(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('মূলধন এখন'), style: body(13, color: C.muted)),
                  const SizedBox(height: 2),
                  Text(now.capital < 0 ? '− ${taka(-now.capital)}' : taka(now.capital), key: const Key('biz-acc-capital'), style: display(30, weight: 700)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(trf('শুরুতে {0}', [taka(s0.capital)]), style: body(13, color: C.muted)),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: capChange >= 0 ? C.greenTint : C.roseTint, borderRadius: BorderRadius.circular(8)),
                      child: Text(_signed(capChange), style: body(12.5, weight: FontWeight.w600, color: capChange >= 0 ? C.green : C.red)),
                    ),
                  ]),
                ]),
              ),
              _Block(
                title: tr('লাভ-ক্ষতি'),
                sub: trf('{0}টি বিক্রি', [bnDigits(f.saleCount)]),
                icon: Icons.trending_up_rounded,
                fg: C.green,
                bg: C.greenTint,
                lines: _nz([
                  (tr('বিক্রি'), f.sales, false),
                  (tr('ফেরত আসা মালের দাম'), -f.returnsRefund, true),
                  (tr('বিক্রি করা মালের কেনা দাম'), -(f.cost - f.returnsCost), true),
                  (tr('কেনা দামের নিচে বিক্রি (ক্ষতিতে ধরা)'), f.lossOnSales, true),
                  (tr('অন্য আয়'), f.otherIncome, true),
                  (tr('দোকানের খরচ'), -f.expenses, true),
                ]),
                total: (tr('নিট লাভ'), f.netProfit, f.netProfit >= 0 ? C.green : C.red),
              ),
              _Block(
                title: tr('ক্ষতি'),
                icon: Icons.trending_down_rounded,
                fg: C.red,
                bg: C.roseTint,
                lines: [
                  (tr('কেনা দামের নিচে বিক্রি'), f.lossOnSales, false),
                  (tr('নষ্ট বা হারানো মাল'), f.damaged, false),
                ],
                total: (tr('মোট ক্ষতি'), f.loss, f.loss > 0 ? C.red : null),
              ),
              _Block(
                title: tr('মূলধন কীভাবে বদলাল'),
                icon: Icons.account_balance_wallet_outlined,
                fg: C.purple,
                bg: C.purpleTint,
                lines: [
                  (tr('শুরুর মূলধন'), s0.capital, false),
                  ..._nz([
                    (tr('নিট লাভ'), f.netProfit, true),
                    (tr('ক্ষতি'), -f.loss, true),
                    (tr('মালিকের জমা'), f.ownerIn, true),
                    (tr('মালিক নিলেন'), -f.ownerOut, true),
                    (trf('সংশোধন ({0}টি)', [bnDigits(f.adjustCount)]), f.adjustCapital, true),
                  ]),
                ],
                total: (tr('এখন মূলধন'), s0.capital + f.capitalChange, null),
              ),
              _Block(
                title: tr('ক্যাশ'),
                icon: Icons.payments_outlined,
                fg: C.green,
                bg: C.greenTint,
                onTap: () => pushPage(context, const BizCashBook()),
                lines: [
                  (tr('শুরুতে ছিল'), s0.cash, false),
                  ..._nz([
                    (tr('নগদ বিক্রি'), f.salesPaid, true),
                    (tr('বকেয়া আদায়'), f.collected, true),
                    (tr('অন্য আয়'), f.otherIncome, true),
                    (tr('মালিকের জমা'), f.ownerIn, true),
                    (tr('ঋণ নেওয়া'), f.loanTaken, true),
                    (tr('সাপ্লায়ার ফেরত দিল'), f.refundsGot, true),
                    (tr('মাল কেনায় নগদ'), -f.purchasesPaid, true),
                    (tr('সাপ্লায়ারকে পরিশোধ'), -f.dealersPaid, true),
                    (tr('দোকানের খরচ'), -f.expenses, true),
                    (tr('ঋণ শোধ (আসল)'), -f.loanRepaid, true),
                    (tr('মালিক নিলেন'), -f.ownerOut, true),
                    (tr('গ্রাহককে ফেরত দিলাম'), -f.refundsPaid, true),
                    (tr('সংশোধন'), f.adjust.cash, true),
                  ]),
                ],
                total: (tr('এখন ক্যাশে'), now.cash, null),
              ),
              _Block(
                title: tr('স্টক (কেনা দামে)'),
                icon: Icons.inventory_2_outlined,
                fg: C.ochre,
                bg: C.ochreTint,
                lines: [
                  (tr('শুরুতে ছিল'), s0.stock, false),
                  ..._nz([
                    (tr('মাল কেনা'), f.purchases, true),
                    (tr('বিক্রি হলো'), -f.cost, true),
                    (tr('গ্রাহক ফেরত দিল (ভালো মাল)'), f.returnsBack, true),
                    (tr('সাপ্লায়ারকে ফেরত'), -f.supplierReturns, true),
                    (tr('নষ্ট হলো'), -f.damagedOnShelf, true),
                    (tr('সংশোধন'), f.adjust.stock, true),
                  ]),
                ],
                total: (tr('এখন স্টকে'), now.stock, null),
              ),
              _Block(
                title: tr('গ্রাহকের বাকি (পাব)'),
                icon: Icons.people_outline_rounded,
                fg: C.warn,
                bg: C.warnBg,
                lines: [
                  (tr('শুরুতে ছিল'), s0.dues, false),
                  ..._nz([
                    (tr('বাকিতে বিক্রি'), f.salesCredit, true),
                    (tr('আদায় হলো'), -f.collected, true),
                    (tr('মাল ফেরতে বাকি থেকে কাটা'), -f.returnsOffDue, true),
                    (tr('সংশোধন'), f.adjust.dues, true),
                  ]),
                ],
                total: (tr('এখন পাব'), now.dues, null),
              ),
              _Block(
                title: tr('সাপ্লায়ার পাবে (দেব)'),
                icon: Icons.local_shipping_outlined,
                fg: C.orange,
                bg: C.orangeTint,
                onTap: () => pushPage(context, const SupplierListPage()),
                lines: [
                  (tr('শুরুতে ছিল'), s0.payable, false),
                  ..._nz([
                    (tr('বাকিতে মাল কেনা'), f.purchasesOwed, true),
                    (tr('পরিশোধ করলাম'), -f.dealersPaid, true),
                    (tr('ফেরত দেওয়া মালে কাটা'), -f.supplierCredit, true),
                    (tr('সংশোধন'), f.adjust.payable, true),
                  ]),
                ],
                total: (tr('এখন দেব'), now.payable, null),
              ),
              _Block(
                title: tr('ঋণ'),
                icon: Icons.account_balance_outlined,
                fg: C.blue,
                bg: C.blueTint,
                onTap: () => pushPage(context, const LoanListPage()),
                lines: [
                  (tr('শুরুতে ছিল'), s0.loans, false),
                  ..._nz([
                    (tr('নতুন ঋণ নেওয়া'), f.loanTaken, true),
                    (tr('শোধ করলাম (আসল)'), -f.loanRepaid, true),
                    (tr('সংশোধন'), f.adjust.loans, true),
                  ]),
                ],
                total: (tr('এখন ঋণ'), now.loans, null),
              ),
              _Block(
                title: tr('মূলধন = যা আছে − যা দেনা'),
                icon: Icons.balance_rounded,
                fg: C.purple,
                bg: C.purpleTint,
                lines: [
                  (tr('ক্যাশ'), now.cash, true),
                  (tr('স্টক'), now.stock, true),
                  (tr('গ্রাহকের বাকি'), now.dues, true),
                  (tr('সাপ্লায়ার পাবে'), -now.payable, true),
                  (tr('ঋণ'), -now.loans, true),
                ],
                total: (tr('মূলধন'), now.capital, null),
              ),
              if (!acc.adds) ...[
                const SizedBox(height: 12),
                Text(
                  trf('অমিল: ক্যাশ {0}, স্টক {1}, পাব {2}, দেব {3}, ঋণ {4}', [_signed(acc.gap.cash), _signed(acc.gap.stock), _signed(acc.gap.dues), _signed(acc.gap.payable), _signed(acc.gap.loans)]),
                  style: body(12.5, color: C.red),
                ),
              ],
              if (f.adjustCount > 0) ...[
                const SizedBox(height: 14),
                Text(tr('সংশোধন মানে: পুরনো লেনদেন বদলানো বা মুছে ফেলা, পণ্যের দাম বা স্টক হাতে বদলানো। এগুলো আলাদা লেখা থাকে, যেন হিসাব সবসময় মেলে।'), style: body(12, color: C.muted)),
              ],
              const SizedBox(height: 16),
              SmallButton(
                key: const Key('biz-acc-redo'),
                label: tr('শুরুর হিসাব বদলান'),
                icon: Icons.restart_alt_rounded,
                onTap: () => pushPage(context, BizSetupPage(redo: b.start != null)),
              ),
              const SizedBox(height: 6),
              Text(tr('শুরুর নগদ, স্টক বা পাওনা-দেনা ভুল হলে এখান থেকে আজকের হিসাব দিয়ে নতুন করে শুরু করুন। মূলধন সেখান থেকে নিজে ঠিক হবে।'), style: body(12, color: C.muted, height: 1.45)),
            ]),
          ),
        ]),
      )),
    );
  }
}

/// রিপোর্ট: a month (or a year) — sales, profit, loss, costs, cash; the
/// best-selling goods.
class BizReportPage extends StatefulWidget {
  const BizReportPage({super.key});
  @override
  State<BizReportPage> createState() => _BizReportPageState();
}

class _BizReportPageState extends State<BizReportPage> {
  int _backM = 0, _backY = 0;
  bool _year = false;

  List<Widget> _page(BuildContext context, Brain brain, bool year) {
    final back = year ? _backY : _backM;
    final b = brain.shop;
    final now = brain.services.now();
    final DateTime from, to;
    final String label;
    if (year) {
      from = DateTime(now.year - back);
      to = DateTime(now.year - back, 12, 31);
      label = bnDigits(now.year - back);
    } else {
      from = DateTime(now.year, now.month - back);
      to = DateTime(from.year, from.month + 1, 0);
      label = monthTitle(from);
    }
    final f = bizFlowsBetween(b, brain.data.cash, from, to);
    final z = to.add(const Duration(days: 1));
    final top = <String, (String, double, int)>{};
    for (final s in b.sales) {
      if (s.at.isBefore(from) || !s.at.isBefore(z)) continue;
      final net = s.netLines;
      for (final (i, l) in s.lines.indexed) {
        final o = top[l.productId ?? l.name] ?? (l.name, 0.0, 0);
        top[l.productId ?? l.name] = (l.name, o.$2 + l.qty, o.$3 + (i < net.length ? net[i] : l.amount));
      }
    }
    final best = top.values.toList()..sort((a, x) => x.$3.compareTo(a.$3));
    return [
              Row(children: [
                IconButton(key: Key(year ? 'biz-report-y-prev' : 'biz-report-prev'), onPressed: () => setState(() => year ? _backY++ : _backM++), icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(child: Text(label, textAlign: TextAlign.center, style: body(15, weight: FontWeight.w600))),
                IconButton(key: Key(year ? 'biz-report-y-next' : 'biz-report-next'), onPressed: back == 0 ? null : () => setState(() => year ? _backY-- : _backM--), icon: const Icon(Icons.chevron_right_rounded)),
              ]),
              AppCard(
                child: Row(children: [
                  Expanded(child: Figure(label: tr('বিক্রি'), amount: taka(f.sales - f.returnsRefund), size: 19)),
                  Expanded(child: Figure(label: tr('নিট লাভ'), amount: _signed(f.netProfit, plus: false), color: f.netProfit >= 0 ? C.green : C.red, size: 19)),
                  Expanded(child: Figure(label: tr('ক্ষতি'), amount: taka(f.loss), color: f.loss > 0 ? C.red : C.ink, size: 19)),
                ]),
              ),
              _Block(
                title: tr('লাভ-ক্ষতি'),
                sub: trf('{0}টি বিক্রি', [bnDigits(f.saleCount)]),
                lines: _nz([
                  (tr('বিক্রি'), f.sales, false),
                  (tr('এর মধ্যে বাকিতে'), f.salesCredit, false),
                  (tr('ফেরত আসা মালের দাম'), -f.returnsRefund, true),
                  (tr('বিক্রি করা মালের কেনা দাম'), -(f.cost - f.returnsCost), true),
                  (tr('কেনা দামের নিচে বিক্রি (ক্ষতিতে ধরা)'), f.lossOnSales, true),
                  (tr('অন্য আয়'), f.otherIncome, true),
                  (tr('দোকানের খরচ'), -f.expenses, true),
                ]),
                total: (tr('নিট লাভ'), f.netProfit, f.netProfit >= 0 ? C.green : C.red),
              ),
              _Block(
                title: tr('ক্যাশে এলো-গেলো'),
                lines: _nz([
                  (tr('নগদ বিক্রি'), f.salesPaid, true),
                  (tr('বকেয়া আদায়'), f.collected, true),
                  (tr('অন্য আয়'), f.otherIncome, true),
                  (tr('মালিকের জমা'), f.ownerIn, true),
                  (tr('ঋণ নেওয়া'), f.loanTaken, true),
                  (tr('মাল কেনায় নগদ'), -f.purchasesPaid, true),
                  (tr('সাপ্লায়ারকে পরিশোধ'), -f.dealersPaid, true),
                  (tr('দোকানের খরচ'), -f.expenses, true),
                  (tr('ঋণ শোধ (আসল)'), -f.loanRepaid, true),
                  (tr('মালিক নিলেন'), -f.ownerOut, true),
                  (tr('গ্রাহককে ফেরত দিলাম'), -f.refundsPaid, true),
                ]),
                total: (tr('ক্যাশ বাড়ল/কমল'), f.change.cash - f.adjust.cash, null),
              ),
              _Block(
                title: tr('মাল'),
                lines: _nz([
                  (tr('মাল কেনা'), f.purchases, false),
                  (tr('এর মধ্যে বাকিতে'), f.purchasesOwed, false),
                  (tr('সাপ্লায়ারকে ফেরত'), f.supplierReturns, false),
                  (tr('নষ্ট হলো'), f.damaged, false),
                ]),
              ),
              if (best.isNotEmpty) ...[
                Padding(padding: const EdgeInsets.fromLTRB(2, 18, 2, 8), child: Text(tr('বেশি বিক্রি হওয়া পণ্য'), style: body(14.5, weight: FontWeight.w600))),
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final (i, (name, qty, amount)) in best.take(8).indexed) ...[
                      if (i > 0) const Hairline(indent: 14, endIndent: 14),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Row(children: [
                          SizedBox(width: 22, child: Text(bnDigits(i + 1), style: body(13, color: C.muted))),
                          Expanded(child: Text(name, style: body(14, weight: FontWeight.w500))),
                          Text(bnDigits(qtyText(qty)), style: body(12, color: C.muted)),
                          const SizedBox(width: 10),
                          Text(taka(amount), style: body(14, weight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ]),
                ),
              ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    // Owner, 24 Nov: "রিপোর্ট এ মাস বছরে সোয়াইপ হবে".
    return Scaffold(
      body: BizRefresh(child: SafeArea(
        child: Column(children: [
          InnerTop(title: tr('রিপোর্ট'), sub: tr('বিক্রি, লাভ, খরচ')),
          Expanded(
            child: TabPages<bool>(
              items: [(false, tr('মাস')), (true, tr('বছর'))],
              value: _year,
              onChanged: (v) => setState(() => _year = v),
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 32),
              page: (y) => _page(context, brain, y),
            ),
          ),
        ]),
      )),
    );
  }
}

/// ক্যাশ বই: every taka in and out of the shop's cash, newest first, with
/// what was in hand after it.
class BizCashBook extends StatelessWidget {
  const BizCashBook({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final all = [for (final x in bizTransactions(b, brain.data.cash)) if (x.cashIn != 0 || x.cashOut != 0) x];
    var bal = bizSums(b, brain.data.cash).cash;
    final after = <String, int>{};
    for (final x in all) {
      after[x.id] = bal;
      bal -= x.cashIn - x.cashOut;
    }
    final now = brain.services.now();
    final today = bizToday(b, brain.data.cash, now);
    return Scaffold(
      body: BizRefresh(child: SafeArea(
        child: Column(children: [
          InnerTop(title: tr('ক্যাশ বই'), sub: trf('এখন ক্যাশে {0}', [taka(bizSums(b, brain.data.cash).cash)])),
          Expanded(
            child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 6, 20, 32), children: [
              AppCard(
                child: Row(children: [
                  Expanded(child: Figure(label: tr('আজ এলো'), amount: taka(_inOf(today)), color: C.green, size: 19)),
                  Expanded(child: Figure(label: tr('আজ গেলো'), amount: taka(_outOf(today)), color: C.red, size: 19)),
                  Expanded(child: Figure(label: tr('এখন ক্যাশে'), amount: taka(bizSums(b, brain.data.cash).cash), size: 19)),
                ]),
              ),
              const SizedBox(height: 12),
              if (all.isEmpty)
                Padding(padding: const EdgeInsets.all(24), child: Text(tr('এখনো ক্যাশের কোনো লেনদেন নেই।'), textAlign: TextAlign.center, style: body(14, color: C.muted)))
              else
                AppCard(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final (i, x) in all.take(300).indexed) ...[
                      if (i > 0) const Hairline(indent: 62, endIndent: 14),
                      TxRow(x, foot: trf('থাকল {0}', [taka(after[x.id]!)])),
                    ],
                  ]),
                ),
            ]),
          ),
        ]),
      )),
    );
  }

  static int _inOf(BizFlows f) => f.salesPaid + f.collected + f.otherIncome + f.ownerIn + f.loanTaken + f.refundsGot;
  static int _outOf(BizFlows f) => f.purchasesPaid + f.dealersPaid + f.expenses + f.loanRepaid + f.ownerOut + f.refundsPaid;
}
