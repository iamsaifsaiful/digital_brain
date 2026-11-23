import 'package:flutter/material.dart';

import '../../logic/biz_account.dart';
import '../../logic/bn.dart';
import '../../logic/lang.dart';
import '../../models/models.dart';
import '../../state/brain.dart';
import '../../ui/kit.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'biz_parts.dart';
import 'biz_money.dart' show moneyOut;
import 'biz_sales.dart' show showReceipt, SellPage;
import 'biz_stock_in.dart' show StockInPage;
import 'biz_shop.dart' show showReturnPdf;

/// The colour and the icon of a kind of entry.
(IconData, Color, Color) txLook(TxKind k) => switch (k) {
      TxKind.sale => (Icons.shopping_bag_outlined, C.green, C.greenTint),
      TxKind.collect => (Icons.download_rounded, C.green, C.greenTint),
      TxKind.purchase => (Icons.inventory_2_outlined, C.ochre, C.ochreTint),
      TxKind.payout => (Icons.local_shipping_outlined, C.warn, C.warnBg),
      TxKind.expense => (Icons.receipt_long_outlined, C.red, C.roseTint),
      TxKind.income => (Icons.add_card_outlined, C.green, C.greenTint),
      TxKind.owner => (Icons.person_outline_rounded, C.purple, C.purpleTint),
      TxKind.loan => (Icons.account_balance_outlined, C.blue, C.blueTint),
      TxKind.returnIn => (Icons.undo_rounded, C.orange, C.orangeTint),
      TxKind.returnOut => (Icons.redo_rounded, C.orange, C.orangeTint),
      TxKind.damage => (Icons.broken_image_outlined, C.red, C.roseTint),
      TxKind.adjust => (Icons.tune_rounded, C.muted, C.surface2),
    };

/// One entry: what, who, when; the money on the right (in green, out in
/// red, neither — a credit sale, goods — plain) and what is left owed.
class TxRow extends StatelessWidget {
  const TxRow(this.x, {super.key, this.showDate = true, this.foot});
  final BizTx x;
  final bool showDate;

  /// A small line under the money (the cash book: what was left in hand).
  final String? foot;

  @override
  Widget build(BuildContext context) {
    final (icon, fg, bg) = txLook(x.kind);
    final net = x.cashIn - x.cashOut;
    final when = showDate ? '${shortDate(x.at)} · ${bnTime(x.at.hour, x.at.minute)}' : bnTime(x.at.hour, x.at.minute);
    final String money;
    final Color moneyColor;
    if (net > 0) {
      money = '+ ${taka(net)}';
      moneyColor = C.green;
    } else if (net < 0) {
      money = '− ${taka(-net)}';
      moneyColor = C.red;
    } else {
      money = taka(x.amount);
      moneyColor = C.ink;
    }
    return InkWell(
      key: Key('biz-tx-${x.id}'),
      onTap: () => openTx(context, x),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)), child: Icon(icon, size: 19, color: fg)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(bnDigits(tr(x.title)), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text([if (x.party.isNotEmpty) x.party, when].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
            ]),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(money, style: body(14, weight: FontWeight.w600, color: moneyColor)),
            if (foot != null)
              Text(foot!, style: body(11, color: C.muted))
            else if (x.left > 0)
              Text(trf('বাকি {0}', [taka(x.left)]), style: body(11.5, color: C.warn)),
          ]),
        ]),
      ),
    );
  }
}

/// Tap on an entry: a sale opens its memo; the rest show what they were,
/// with a way to cancel the entry (the account takes the change).
Future<void> openTx(BuildContext context, BizTx x) async {
  final ref = x.ref;
  if (ref is Sale) return showReceipt(context, ref);
  final brain = BrainScope.read(context);
  final (icon, fg, bg) = txLook(x.kind);
  final undoable = ref is CashEntry || ref is ShopPayment || ref is Purchase || ref is OwnerMove || ref is LoanMove || ref is CustomerReturn || ref is SupplierReturn;
  await showAppSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)), child: Icon(icon, color: fg)),
            const SizedBox(width: 12),
            Expanded(child: Text(bnDigits(tr(x.title)), style: display(18, weight: 600))),
          ]),
          const SizedBox(height: 14),
          detailRows([
            (Icons.event_outlined, tr('কবে'), '${fullDate(x.at)} · ${bnTime(x.at.hour, x.at.minute)}'),
            if (x.party.isNotEmpty) (Icons.person_outline_rounded, tr('কার সাথে'), x.party),
            (Icons.payments_outlined, tr('পরিমাণ'), taka(x.amount)),
            if (x.cashIn > 0) (Icons.download_rounded, tr('ক্যাশে এলো'), taka(x.cashIn)),
            if (x.cashOut > 0) (Icons.upload_rounded, tr('ক্যাশ থেকে গেলো'), taka(x.cashOut)),
            if (x.left > 0) (Icons.hourglass_bottom_rounded, tr('বাকি থাকল'), taka(x.left)),
          ]),
          if (ref is CustomerReturn) ...[
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: SmallButton(key: const Key('biz-tx-return-pdf'), label: trf('ফেরত মেমো #{0}-ফ · PDF', [bnDigits(ref.saleNo)]), icon: Icons.picture_as_pdf_outlined, primary: true, onTap: () => showReturnPdf(ctx, ref))),
          ],
          if (undoable) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: SmallButton(
                key: const Key('biz-tx-undo'),
                label: tr('এই লেনদেন বাতিল করুন'),
                icon: Icons.delete_outline_rounded,
                onTap: () async {
                  final ok = await confirmDialog(ctx, title: tr('লেনদেনটি বাতিল করবেন?'), text: tr('ক্যাশ, স্টক, বাকি — যা বদলেছিল, আগের মতো হবে।'), yes: tr('বাতিল করুন'), danger: true);
                  if (!ok) return;
                  if (ref is CashEntry) {
                    await brain.deleteCash(ref.id);
                  } else if (ref is CustomerReturn || ref is SupplierReturn) {
                    await brain.undoReturn(x.id);
                  } else {
                    await brain.undoShopEntry(x.id);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ]),
      ),
    ),
  );
}

/// সব লেনদেন: every entry, newest first, by day, with a filter and search.
class BizTxPage extends StatefulWidget {
  const BizTxPage({super.key, this.kinds});
  final Set<TxKind>? kinds;
  @override
  State<BizTxPage> createState() => _BizTxPageState();
}

class _BizTxPageState extends State<BizTxPage> {
  static final _filters = <(String, Set<TxKind>?)>[
    ('সব', null),
    ('বিক্রি', {TxKind.sale}),
    ('আদায়', {TxKind.collect, TxKind.income, TxKind.owner}),
    ('স্টক', {TxKind.purchase, TxKind.damage}),
    ('খরচ', {TxKind.expense, TxKind.payout}),
    ('ফেরত', {TxKind.returnIn, TxKind.returnOut}),
    ('ঋণ', {TxKind.loan}),
  ];
  late Set<TxKind>? _kinds = widget.kinds;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final all = bizTransactions(brain.shop, brain.data.cash);
    final q = _q.trim().toLowerCase();
    final list = [
      for (final x in all)
        if ((_kinds == null || _kinds!.contains(x.kind)) && (q.isEmpty || x.title.toLowerCase().contains(q) || x.party.toLowerCase().contains(q) || tr(x.title).toLowerCase().contains(q))) x
    ];
    final days = <DateTime, List<BizTx>>{};
    for (final x in list) {
      days.putIfAbsent(DateTime(x.at.year, x.at.month, x.at.day), () => []).add(x);
    }
    final k = widget.kinds;
    final fab = k != null && k.contains(TxKind.purchase)
        ? AddButton(key: const Key('biz-tx-fab'), label: tr('স্টক যোগ'), onPressed: () => pushPage(context, const StockInPage()))
        : k != null && k.contains(TxKind.expense)
            ? AddButton(key: const Key('biz-tx-fab'), label: tr('খরচ'), onPressed: () => moneyOut(context))
            : AddButton(key: const Key('biz-tx-fab'), label: tr('নতুন বিক্রি'), onPressed: () => pushPage(context, const SellPage()));
    return Scaffold(
      floatingActionButton: fab,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          InnerTop(title: tr('সব লেনদেন'), sub: trf('{0}টি', [bnDigits(list.length)])),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(textCapitalization: TextCapitalization.sentences, 
              key: const Key('biz-tx-search'),
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                hintText: tr('নাম, মেমো বা খাত খুঁজুন'),
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
              for (final (label, kinds) in _filters)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    key: Key('biz-tx-f-$label'),
                    label: Text(tr(label)),
                    selected: _sameSet(_kinds, kinds),
                    onSelected: (_) => setState(() => _kinds = kinds),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(tr('কোনো লেনদেন নেই।'), style: body(14, color: C.muted))))
                : ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
                    for (final MapEntry(key: day, value: xs) in days.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
                        child: Row(children: [
                          Text(relativeDay(day, brain.services.now()), style: body(13, weight: FontWeight.w600, color: C.muted)),
                          const Spacer(),
                          Text(_dayNet(xs), style: body(12.5, color: C.muted)),
                        ]),
                      ),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: Column(children: [
                          for (final (i, x) in xs.indexed) ...[if (i > 0) const Hairline(indent: 62, endIndent: 14), TxRow(x, showDate: false)],
                        ]),
                      ),
                    ],
                  ]),
          ),
        ]),
      ),
    );
  }

  static bool _sameSet(Set<TxKind>? a, Set<TxKind>? b) => a == null || b == null ? a == b : a.length == b.length && a.containsAll(b);

  String _dayNet(List<BizTx> xs) {
    final n = xs.fold<int>(0, (s, x) => s + x.cashIn - x.cashOut);
    return trf('ক্যাশ {0}', ['${n < 0 ? '− ' : '+ '}${taka(n.abs())}']);
  }
}
