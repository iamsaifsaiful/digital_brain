import 'package:flutter/material.dart';

import '../../logic/biz_account.dart';
import '../../logic/bn.dart';
import '../../logic/lang.dart';
import '../../logic/shop_logic.dart';
import '../../models/models.dart';
import '../../state/brain.dart';
import '../../ui/forms.dart' show askText;
import '../../ui/kit.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'biz_customers.dart' show pickCustomer;
import 'biz_hisab.dart' show addShopCost, payDealer, pickDealer, DealerPage, DealerForm;
import 'biz_parts.dart';
import 'biz_stock.dart' show StockInPage;

/// A sheet of choices: icon, title, line under it.
Future<String?> _choose(BuildContext context, String title, List<(String key, IconData, Color, Color, String title, String sub)> rows) => showAppSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 10), child: Text(title, style: display(19, weight: 600))),
          for (final (key, icon, fg, bg, t, sub) in rows)
            InkWell(
              key: Key('biz-pick-$key'),
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pop(ctx, key),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                child: Row(children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: fg, size: 21)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr(t), style: body(15, weight: FontWeight.w600)),
                      Text(tr(sub), style: body(12.5, color: C.muted)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.muted),
                ]),
              ),
            ),
        ]),
      ),
    );

Future<int?> _askAmount(BuildContext context, String title, {int initial = 0}) async {
  final v = await askText(context, title, initial: initial > 0 ? bnDigits(initial) : '', number: true);
  final n = v == null ? null : readNum(v);
  return n == null || n <= 0 ? null : n.round();
}

/// টাকা জমা: what came into the shop's cash.
Future<void> moneyIn(BuildContext context) async {
  final brain = BrainScope.read(context);
  final k = await _choose(context, tr('টাকা জমা'), [
    ('collect', Icons.person_outline_rounded, C.green, C.greenTint, 'বকেয়া আদায়', 'গ্রাহক বাকির টাকা দিলেন'),
    ('owner', Icons.savings_outlined, C.purple, C.purpleTint, 'মালিকের জমা', 'নিজের টাকা ব্যবসায় দিলেন'),
    ('loan', Icons.account_balance_outlined, C.blue, C.blueTint, 'ঋণ নিলাম', 'ব্যাংক বা কারো কাছ থেকে'),
    ('income', Icons.add_card_outlined, C.teal, C.tealTint, 'অন্য আয়', 'বিক্রি ছাড়া অন্য কোনো আয়'),
  ]);
  if (k == null || !context.mounted) return;
  switch (k) {
    case 'collect':
      final c = await pickCustomer(context);
      if (c == null || !context.mounted) return;
      final due = customerAccount(brain.shop, c).due;
      final n = await _askAmount(context, trf('{0} কত টাকা দিলেন?', [c.name]), initial: due);
      if (n == null) return;
      await brain.customerPaid(c.id, n);
      if (context.mounted) toast(context, trf('{0} আদায় হলো', [taka(n)]));
    case 'owner':
      final n = await _askAmount(context, tr('কত টাকা ব্যবসায় দিলেন?'));
      if (n == null) return;
      await brain.ownerMoney(n, inward: true);
      if (context.mounted) toast(context, trf('{0} মালিকের জমা — মূলধন বাড়ল', [taka(n)]));
    case 'loan':
      final l = await pickLoan(context);
      if (l == null || !context.mounted) return;
      final n = await _askAmount(context, trf('{0} থেকে কত টাকা নিলেন?', [l.name]));
      if (n == null) return;
      await brain.takeLoan(l.id, n);
      if (context.mounted) toast(context, trf('{0} ঋণ নেওয়া হলো', [taka(n)]));
    case 'income':
      final n = await _askAmount(context, tr('কত টাকা আয়?'));
      if (n == null || !context.mounted) return;
      final what = await askText(context, tr('কীসের আয়?'), hint: tr('যেমন: কমিশন, ভাড়া'));
      await brain.bizMoney(CashKind.income, n, (what == null || what.isEmpty) ? 'অন্য আয়' : what);
      if (context.mounted) toast(context, trf('{0} আয় রাখা হলো', [taka(n)]));
  }
}

/// খরচ: what went out of the shop's cash (or off the shelf).
Future<void> moneyOut(BuildContext context) async {
  final brain = BrainScope.read(context);
  final k = await _choose(context, tr('খরচ'), [
    ('cost', Icons.receipt_long_outlined, C.red, C.roseTint, 'দোকানের খরচ', 'ভাড়া, বিল, বেতন, পরিবহন…'),
    ('dealer', Icons.local_shipping_outlined, C.warn, C.warnBg, 'সাপ্লায়ারকে পরিশোধ', 'মাল কেনার বাকি দিলেন'),
    ('loan', Icons.account_balance_outlined, C.blue, C.blueTint, 'ঋণের কিস্তি', 'আসল ও সুদ আলাদা'),
    ('owner', Icons.person_outline_rounded, C.purple, C.purpleTint, 'মালিক নিলেন', 'ব্যবসা থেকে নিজের জন্য'),
    ('damage', Icons.broken_image_outlined, C.red, C.roseTint, 'নষ্ট মাল', 'মাল নষ্ট বা হারিয়েছে — ক্ষতি'),
  ]);
  if (k == null || !context.mounted) return;
  switch (k) {
    case 'cost':
      await addShopCost(context);
    case 'dealer':
      final d = await pickDealer(context);
      if (d == null || !context.mounted) return;
      await payDealer(context, brain, d);
    case 'loan':
      final l = await pickLoan(context, owedOnly: true);
      if (l == null || !context.mounted) return;
      await repayLoanSheet(context, l);
    case 'owner':
      final n = await _askAmount(context, tr('ব্যবসা থেকে কত টাকা নিলেন?'));
      if (n == null) return;
      await brain.ownerMoney(n, inward: false);
      if (context.mounted) toast(context, trf('{0} মালিক নিলেন — মূলধন কমল', [taka(n)]));
    case 'damage':
      await writeOffSheet(context);
  }
}

/// Spoilt or lost goods: which, how much; the cost is the loss.
Future<void> writeOffSheet(BuildContext context) async {
  final brain = BrainScope.read(context);
  final p = await pickProduct(context, tr('কোন মাল নষ্ট হলো?'));
  if (p == null || !context.mounted) return;
  final v = await askText(context, trf('{0} কতটুকু নষ্ট? (আছে {1} {2})', [p.name, bnDigits(qtyText(p.stock)), tr(p.unit)]));
  final q = v == null ? null : readNum(v);
  if (q == null || q <= 0 || !context.mounted) return;
  final why = await askText(context, tr('কেন? (না লিখলেও চলবে)'), hint: tr('যেমন: মেয়াদ শেষ, ভেঙে গেছে'));
  await brain.writeOff(p.id, q > p.stock ? p.stock : q, why: why ?? '');
  if (context.mounted) toast(context, trf('{0} বাদ দেওয়া হলো — ক্ষতিতে লেখা হলো', [p.name]));
}

/// Pick a product, with live search.
Future<Product?> pickProduct(BuildContext context, String title) => showAppSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickProduct(title: title),
    );

class _PickProduct extends StatefulWidget {
  const _PickProduct({required this.title});
  final String title;
  @override
  State<_PickProduct> createState() => _PickProductState();
}

class _PickProductState extends State<_PickProduct> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final b = BrainScope.of(context).shop;
    final q = _q.trim().toLowerCase();
    final list = [for (final p in b.products) if (q.isEmpty || p.name.toLowerCase().contains(q)) p]..sort((a, x) => a.name.compareTo(x.name));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text(widget.title, style: display(18, weight: 600)))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(textCapitalization: TextCapitalization.sentences, 
              key: const Key('biz-pick-product-search'),
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(hintText: tr('পণ্যের নাম লিখুন'), prefixIcon: const Icon(Icons.search_rounded), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24))),
            ),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(8, 8, 8, 16), children: [
              for (final p in list)
                ListTile(
                  key: Key('biz-pick-product-${p.id}'),
                  title: Text(p.name, style: body(15, weight: FontWeight.w500)),
                  subtitle: Text(trf('আছে {0} {1}', [bnDigits(qtyText(p.stock)), tr(p.unit)]), style: body(12.5, color: C.muted)),
                  onTap: () => Navigator.pop(context, p),
                ),
              if (list.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(tr('কোনো পণ্য মেলেনি।'), textAlign: TextAlign.center, style: body(14, color: C.muted))),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ঋণ ------------------------------------------------------------------------

/// Pick a loan, or write a new lender's name.
Future<Loan?> pickLoan(BuildContext context, {bool owedOnly = false}) async {
  final brain = BrainScope.read(context);
  final b = brain.shop;
  final loans = [for (final l in b.loans) if (!owedOnly || loanDue(b, l) > 0) l];
  final v = await showAppSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(8, 4, 8, 16), children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: Text(tr('কোন ঋণ?'), style: display(18, weight: 600))),
        for (final l in loans)
          ListTile(
            key: Key('biz-pick-loan-${l.id}'),
            leading: Avatar(name: l.name, size: 38, fg: C.blue, bg: C.blueTint),
            title: Text(l.name, style: body(15, weight: FontWeight.w500)),
            trailing: Text(taka(loanDue(b, l)), style: body(14, weight: FontWeight.w600, color: C.blue)),
            onTap: () => Navigator.pop(ctx, 'id:${l.id}'),
          ),
        if (!owedOnly)
          ListTile(
            key: const Key('biz-pick-loan-new'),
            leading: CircleAvatar(backgroundColor: C.greenTint, child: Icon(Icons.add_rounded, color: C.green)),
            title: Text(tr('নতুন ঋণদাতা'), style: body(15, weight: FontWeight.w600, color: C.green)),
            onTap: () => Navigator.pop(ctx, 'new'),
          ),
        if (owedOnly && loans.isEmpty) Padding(padding: const EdgeInsets.all(20), child: Text(tr('কোনো ঋণ বাকি নেই।'), textAlign: TextAlign.center, style: body(14, color: C.muted))),
      ]),
    ),
  );
  if (v == null || !context.mounted) return null;
  if (v.startsWith('id:')) return b.loans.where((l) => l.id == v.substring(3)).firstOrNull;
  final name = await askText(context, tr('কার কাছ থেকে ঋণ? (ব্যাংক বা নাম)'));
  if (name == null || name.isEmpty) return null;
  return brain.saveLoan(Loan(name: name));
}

/// Pay an instalment: the principal and, apart, the interest (a cost).
Future<void> repayLoanSheet(BuildContext context, Loan l) async {
  final brain = BrainScope.read(context);
  final due = loanDue(brain.shop, l);
  final n = await _askAmount(context, trf('{0}: আসল কত দিলেন? (বাকি {1})', [l.name, taka(due)]), initial: l.installment > 0 && l.installment < due ? l.installment : due);
  if (n == null || !context.mounted) return;
  final iv = await askText(context, tr('সুদ কত দিলেন? (না থাকলে খালি রাখুন)'), number: true);
  final interest = ((iv == null ? null : readNum(iv)) ?? 0).round();
  await brain.repayLoan(l.id, n > due ? due : n, interest: interest < 0 ? 0 : interest);
  if (context.mounted) toast(context, interest > 0 ? trf('কিস্তি {0} + সুদ {1} দেওয়া হলো', [taka(n), taka(interest)]) : trf('কিস্তি {0} দেওয়া হলো', [taka(n)]));
}

/// ঋণ: every lender, what is owed, the next instalment.
class LoanListPage extends StatelessWidget {
  const LoanListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final total = b.loans.fold<int>(0, (s, l) => s + loanDue(b, l));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          InnerTop(title: tr('ঋণ'), sub: trf('মোট বাকি {0}', [taka(total)])),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
              Row(children: [
                Expanded(child: SmallButton(key: const Key('biz-loan-take'), label: tr('ঋণ নিলাম'), icon: Icons.download_rounded, primary: true, onTap: () async {
                  final l = await pickLoan(context);
                  if (l == null || !context.mounted) return;
                  final n = await _askAmount(context, trf('{0} থেকে কত টাকা নিলেন?', [l.name]));
                  if (n != null) await brain.takeLoan(l.id, n);
                })),
                const SizedBox(width: 8),
                Expanded(child: SmallButton(key: const Key('biz-loan-pay'), label: tr('কিস্তি দিলাম'), icon: Icons.upload_rounded, onTap: () async {
                  final l = await pickLoan(context, owedOnly: true);
                  if (l != null && context.mounted) await repayLoanSheet(context, l);
                })),
              ]),
              const SizedBox(height: 12),
              ListCard(
                empty: tr('কোনো ঋণ নেই।'),
                rows: [
                  for (final l in b.loans)
                    ListRow(
                      key: Key('biz-loan-${l.id}'),
                      leading: Avatar(name: l.name, size: 40, fg: C.blue, bg: C.blueTint),
                      title: l.name,
                      subtitle: [
                        if (l.installment > 0) trf('কিস্তি {0}', [taka(l.installment)]),
                        if (l.nextDue != null) trf('পরের কিস্তি {0}', [shortDate(l.nextDue!)]),
                      ].join(' · '),
                      trailing: Text(taka(loanDue(b, l)), style: body(14.5, weight: FontWeight.w600, color: loanDue(b, l) > 0 ? C.blue : C.muted)),
                      onTap: () => pushPage(context, LoanPage(id: l.id)),
                    ),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One loan: owed now, what was taken and paid, the instalment.
class LoanPage extends StatelessWidget {
  const LoanPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final l = b.loans.where((x) => x.id == id).firstOrNull;
    if (l == null) return const Scaffold(body: SizedBox());
    final due = loanDue(b, l);
    final moves = [for (final m in b.loanMoves) if (m.loanId == id) m]..sort((a, x) => x.at.compareTo(a.at));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          InnerTop(title: l.name, sub: tr('ঋণ'), actions: [
            IconButton(
              key: const Key('biz-loan-edit'),
              tooltip: tr('বদলান'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final v = await askText(context, tr('মাসিক কিস্তি কত?'), initial: l.installment > 0 ? bnDigits(l.installment) : '', number: true);
                if (v == null) return;
                await brain.saveLoan(l.copyWith(installment: (readNum(v) ?? 0).round()));
              },
            ),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
              AppCard(
                child: Row(children: [
                  Expanded(child: Figure(label: tr('বাকি'), amount: taka(due), color: due > 0 ? C.blue : C.ink, size: 22)),
                  Expanded(child: Figure(label: tr('কিস্তি'), amount: l.installment > 0 ? taka(l.installment) : '—', size: 18)),
                  Expanded(child: Figure(label: tr('পরের কিস্তি'), amount: l.nextDue == null ? '—' : shortDate(l.nextDue!), size: 18)),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: SmallButton(label: tr('আরও নিলাম'), icon: Icons.download_rounded, onTap: () async {
                  final n = await _askAmount(context, trf('{0} থেকে কত টাকা নিলেন?', [l.name]));
                  if (n != null) await brain.takeLoan(l.id, n);
                })),
                const SizedBox(width: 8),
                Expanded(child: SmallButton(key: const Key('biz-loan-repay'), label: tr('কিস্তি দিলাম'), icon: Icons.upload_rounded, primary: true, onTap: due <= 0 ? null : () => repayLoanSheet(context, l))),
              ]),
              const SizedBox(height: 14),
              ListCard(
                empty: l.opening > 0 ? trf('শুরুতে বাকি ছিল {0}। এরপর কোনো লেনদেন হয়নি।', [taka(l.opening)]) : tr('এখনো কোনো লেনদেন নেই।'),
                rows: [
                  for (final m in moves)
                    ListRow(
                      leading: DateBlock(top: bnDigits(m.at.day), bottom: monthShort(m.at.month)),
                      title: m.take ? tr('ঋণ নেওয়া') : tr('কিস্তি (আসল)'),
                      subtitle: m.note.isEmpty ? null : m.note,
                      trailing: Text('${m.take ? '+ ' : '− '}${taka(m.amount)}', style: body(14, weight: FontWeight.w600, color: m.take ? C.blue : C.green)),
                    ),
                  if (moves.isNotEmpty && l.opening > 0)
                    ListRow(leading: const Icon(Icons.flag_outlined), title: tr('শুরুতে বাকি ছিল'), trailing: Text(taka(l.opening), style: body(14, weight: FontWeight.w600))),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// সাপ্লায়ার -----------------------------------------------------------------

/// সাপ্লায়ার: who we buy from, what we owe each, buy and pay.
class SupplierListPage extends StatelessWidget {
  const SupplierListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final accounts = [for (final d in b.dealers) dealerAccount(b, d)]..sort((x, y) => y.due != x.due ? y.due.compareTo(x.due) : x.name.compareTo(y.name));
    final due = accounts.fold<int>(0, (s, a) => s + (a.due > 0 ? a.due : 0));
    return Scaffold(
      floatingActionButton: AddButton(key: const Key('biz-dealer-fab'), label: tr('নতুন সাপ্লায়ার'), icon: Icons.person_add_alt_1_rounded, onPressed: () => pushPage(context, const DealerForm())),
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          InnerTop(title: tr('সাপ্লায়ার'), sub: trf('মোট পাবে {0}', [taka(due)]), actions: [
            IconButton(key: const Key('biz-dealer-add'), tooltip: tr('নতুন সাপ্লায়ার'), icon: const Icon(Icons.person_add_alt_outlined), onPressed: () => pushPage(context, const DealerForm())),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
              Row(children: [
                Expanded(child: SmallButton(key: const Key('biz-buy-goods'), label: tr('স্টক যোগ'), icon: Icons.inventory_2_outlined, primary: true, onTap: () => pushPage(context, const StockInPage()))),
                const SizedBox(width: 8),
                Expanded(child: SmallButton(key: const Key('biz-pay-dealer'), label: tr('টাকা দিলাম'), icon: Icons.payments_outlined, onTap: () async {
                  final d = await pickDealer(context);
                  if (d != null && context.mounted) await payDealer(context, brain, d);
                })),
              ]),
              const SizedBox(height: 12),
              ListCard(
                empty: tr('কোনো সাপ্লায়ার নেই। যাদের কাছ থেকে মাল কেনেন, তাঁদের যোগ করুন।'),
                rows: [
                  for (final a in accounts)
                    ListRow(
                      key: Key('biz-dealer-${a.id}'),
                      leading: Avatar(name: a.name, size: 40, fg: C.orange, bg: C.orangeTint),
                      title: a.name,
                      subtitle: a.last == null ? null : trf('শেষ লেনদেন {0}', [shortDate(a.last!)]),
                      trailing: a.due > 0 ? Text(taka(a.due), style: body(14.5, weight: FontWeight.w600, color: C.warn)) : Text(tr('পরিশোধিত'), style: body(12.5, color: C.muted)),
                      onTap: () => pushPage(context, DealerPage(id: a.id)),
                    ),
                ],
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
