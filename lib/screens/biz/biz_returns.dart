import 'package:flutter/material.dart';

import '../../logic/biz_account.dart';
import '../../logic/bn.dart';
import '../../logic/lang.dart';
import '../../logic/shop_logic.dart';
import '../../models/models.dart';
import '../../state/brain.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'biz_hisab.dart' show pickDealer;
import 'biz_parts.dart';

/// মাল ফেরত (owner, 23 Nov: "অনেক সময় মাল ফেরত যায়"): a customer brings
/// goods back from a memo, or the shop sends goods back to a supplier.
class ReturnsPage extends StatefulWidget {
  const ReturnsPage({super.key, this.supplier = false, this.saleId, this.dealerId});
  final bool supplier;
  final String? saleId;
  final String? dealerId;
  @override
  State<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends State<ReturnsPage> {
  late bool _supplier = widget.supplier;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            InnerTop(title: tr('মাল ফেরত')),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SegTabs<bool>(
                key: const Key('ret-kind'),
                items: [(false, tr('গ্রাহক ফেরত দিল')), (true, tr('সাপ্লায়ারকে ফেরত'))],
                value: _supplier,
                onChanged: (v) => setState(() => _supplier = v),
              ),
            ),
            Expanded(child: _supplier ? _SupplierReturn(dealerId: widget.dealerId) : _CustomerReturn(saleId: widget.saleId)),
          ]),
        ),
      );
}

Widget _label(String s, {String? note}) => Padding(
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: s, style: body(13, weight: FontWeight.w700)),
        if (note != null) TextSpan(text: ' $note', style: body(12, color: C.muted)),
      ])),
    );

Widget _box({required Widget child, Color? color, Color? border}) => Container(
      decoration: BoxDecoration(color: color ?? C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: border ?? C.border)),
      clipBehavior: Clip.antiAlias,
      child: child,
    );

Widget _sumBox(List<(String, String, Color?)> rows, (String, String) total) => _box(
      color: C.warnBg,
      border: C.warnBorder,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(children: [
          for (final (a, b, c) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [Expanded(child: Text(a, style: body(13.5))), Text(b, style: body(13.5, weight: FontWeight.w600, color: c))]),
            ),
          Divider(color: C.warnBorder, height: 14),
          Row(children: [
            Expanded(child: Text(total.$1, style: body(14, weight: FontWeight.w700, color: C.warn))),
            Text(total.$2, key: const Key('ret-after'), style: body(15, weight: FontWeight.w700, color: C.warn)),
          ]),
        ]),
      ),
    );

Widget _stepper(String key, double q, String unit, VoidCallback dec, VoidCallback inc) => Container(
      key: Key(key),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        InkWell(key: Key('$key-dec'), onTap: dec, child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.remove_rounded, size: 18, color: C.green))),
        ConstrainedBox(constraints: const BoxConstraints(minWidth: 40), child: Text('${bnDigits(qtyText(q))} ${tr(unit)}', textAlign: TextAlign.center, style: body(13, weight: FontWeight.w600))),
        InkWell(key: Key('$key-inc'), onTap: inc, child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.add_rounded, size: 18, color: C.green))),
      ]),
    );

// গ্রাহক ফেরত দিল ------------------------------------------------------------

class _CustomerReturn extends StatefulWidget {
  const _CustomerReturn({this.saleId});
  final String? saleId;
  @override
  State<_CustomerReturn> createState() => _CustomerReturnState();
}

class _CustomerReturnState extends State<_CustomerReturn> {
  Sale? _sale;
  final _qty = <int, double>{};
  bool _damaged = false;
  bool _cash = false;
  bool _busy = false;
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.saleId != null) _sale = BrainScope.read(context).shop.sales.where((s) => s.id == widget.saleId).firstOrNull;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  double _left(ShopBook b, int i) => _sale!.lines[i].qty - returnedQty(b, _sale!.id, _sale!.lines[i]);

  int get _refund {
    final s = _sale;
    if (s == null) return 0;
    final net = s.netLines;
    var r = 0;
    for (final MapEntry(key: i, value: q) in _qty.entries) {
      if (q > 0 && s.lines[i].qty > 0) r += (net[i] * q / s.lines[i].qty).round();
    }
    return r;
  }

  Future<void> _pickSale() async {
    final b = BrainScope.read(context).shop;
    final id = await showAppSheet<String>(context: context, isScrollControlled: true, builder: (_) => _PickSale(sales: b.sales));
    if (id == null || !mounted) return;
    setState(() {
      _sale = b.sales.where((s) => s.id == id).firstOrNull;
      _qty.clear();
      _cash = _sale?.customerId.isEmpty ?? false;
    });
  }

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    if (_sale == null || _busy) return;
    if (_qty.values.every((q) => q <= 0)) return toast(context, tr('কোন মাল ফেরত এলো, বেছে নিন'));
    setState(() => _busy = true);
    final r = await brain.recordCustomerReturn(_sale!.id, Map.of(_qty), damaged: _damaged, cash: _cash, note: _note.text.trim());
    if (!mounted) return;
    Navigator.of(context).pop(r);
    if (r != null) toast(context, trf('ফেরত নেওয়া হলো · মেমো #{0}-ফ · {1}', [bnDigits(r.saleNo), taka(r.refund)]));
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final s = _sale;
    final c = s == null || s.customerId.isEmpty ? null : customerById(b, s.customerId);
    final due = c == null ? 0 : customerAccount(b, c).due;
    final refund = _refund;
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), children: [
          _label(tr('কোন মেমোর মাল?')),
          _box(
            child: InkWell(
              key: const Key('ret-sale'),
              onTap: _pickSale,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                child: Row(children: [
                  s == null ? CircleAvatar(radius: 19, backgroundColor: C.surface2, child: Icon(Icons.receipt_long_outlined, color: C.muted)) : Avatar(name: s.customer.isEmpty ? '#' : s.customer, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: s == null
                        ? Text(tr('মেমো বেছে নিন'), style: body(15, color: C.muted))
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text([trf('মেমো #{0}', [bnDigits(s.no)]), if (s.customer.isNotEmpty) s.customer].join(' · '), style: body(15, weight: FontWeight.w700)),
                            Text([shortDate(s.at), taka(s.total), if (s.due > 0) trf('বাকি {0}', [taka(s.due)])].join(' · '), style: body(12, color: C.muted)),
                          ]),
                  ),
                  Text(s == null ? tr('বাছুন') : tr('বদলান'), style: body(13, weight: FontWeight.w600, color: C.green)),
                ]),
              ),
            ),
          ),
          if (s != null) ...[
            _label(tr('কোনগুলো ফেরত এলো')),
            _box(
              child: Column(children: [
                for (final (i, l) in s.lines.indexed) ...[
                  if (i > 0) Divider(height: 1, color: C.border, indent: 14, endIndent: 14),
                  () {
                    final left = _left(b, i);
                    final q = _qty[i] ?? 0;
                    final on = q > 0;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                      child: Row(children: [
                        Checkbox(
                          key: Key('ret-line-$i'),
                          value: on,
                          onChanged: left <= 0 ? null : (v) => setState(() => _qty[i] = v == true ? (left >= 1 ? 1 : left) : 0),
                        ),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.name, style: body(14.5, weight: FontWeight.w600, color: left <= 0 ? C.muted : C.ink)),
                            Text(
                              left < l.qty
                                  ? trf('নিয়েছিল {0} {1} · আগে ফেরত {2}', [bnDigits(qtyText(l.qty)), tr(l.unit), bnDigits(qtyText(l.qty - left))])
                                  : trf('নিয়েছিল {0} {1} · {2}', [bnDigits(qtyText(l.qty)), tr(l.unit), taka(l.amount)]),
                              style: body(12, color: C.muted),
                            ),
                          ]),
                        ),
                        if (on)
                          _stepper('ret-qty-$i', q, l.unit, () => setState(() => _qty[i] = (q - 1).clamp(0, left).toDouble()), () => setState(() => _qty[i] = (q + 1).clamp(0, left).toDouble())),
                      ]),
                    );
                  }(),
                ],
              ]),
            ),
            _label(tr('মালের অবস্থা')),
            SegTabs<bool>(
              key: const Key('ret-damaged'),
              items: [(false, tr('ভালো · স্টকে যাবে')), (true, tr('নষ্ট · ক্ষতিতে যাবে'))],
              value: _damaged,
              onChanged: (v) => setState(() => _damaged = v),
            ),
            const SizedBox(height: 12),
            _box(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(s.discount > 0 ? tr('ফেরতের দাম (ছাড় বাদে)') : tr('ফেরতের দাম'), style: body(13, color: C.muted))),
                    Text(taka(refund), key: const Key('ret-refund'), style: body(16, weight: FontWeight.w700)),
                  ]),
                  if (c != null) ...[
                    const SizedBox(height: 10),
                    Text(tr('টাকা কীভাবে?'), style: body(13, weight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    SegTabs<bool>(
                      key: const Key('ret-cash'),
                      items: [(false, tr('বকেয়া থেকে কাটা')), (true, tr('নগদ ফেরত'))],
                      value: _cash,
                      onChanged: (v) => setState(() => _cash = v),
                    ),
                    const SizedBox(height: 10),
                    _cash
                        ? _sumBox([(trf('{0}-এর বকেয়া', [c.name]), taka(due), null)], (tr('ক্যাশ থেকে দেবেন'), taka(refund)))
                        : _sumBox([
                            (trf('{0}-এর বকেয়া ছিল', [c.name]), taka(due), null),
                            (tr('ফেরত বাবদ কমলো'), '− ${taka(refund)}', C.green),
                          ], (tr('এখন বকেয়া'), due - refund < 0 ? '− ${taka(refund - due)}' : taka(due - refund))),
                  ] else ...[
                    const SizedBox(height: 6),
                    Text(trf('গ্রাহকের নাম নেই — ক্যাশ থেকে {0} ফেরত দেবেন', [taka(refund)]), style: body(12.5, color: C.muted)),
                  ],
                ]),
              ),
            ),
            _label(tr('কারণ'), note: tr('(ঐচ্ছিক)')),
            TextField(key: const Key('ret-note'), controller: _note, style: body(15), decoration: InputDecoration(isDense: true, hintText: tr('যেমন: বোতল ফাটা'))),
          ],
        ]),
      ),
      if (s != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
          child: PrimaryButton(key: const Key('ret-save'), label: trf('ফেরত নিন · মেমো #{0}-ফ', [bnDigits(s.no)]), icon: Icons.check_rounded, onPressed: _busy || refund <= 0 ? null : _save),
        ),
    ]);
  }
}

/// Pick a memo: by its number or the buyer's name, newest first.
class _PickSale extends StatefulWidget {
  const _PickSale({required this.sales});
  final List<Sale> sales;
  @override
  State<_PickSale> createState() => _PickSaleState();
}

class _PickSaleState extends State<_PickSale> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final q = asciiDigits(_q.trim().toLowerCase()).replaceAll('#', '');
    final list = [
      for (final s in widget.sales)
        if (s.lines.isNotEmpty && (q.isEmpty || '${s.no}' == q || s.customer.toLowerCase().contains(q))) s
    ]..sort((a, x) => x.at.compareTo(a.at));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .7,
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 4, 20, 8), child: Align(alignment: Alignment.centerLeft, child: Text(tr('কোন মেমো?'), style: display(18, weight: 600)))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              key: const Key('ret-sale-q'),
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(hintText: tr('মেমো নম্বর বা গ্রাহকের নাম'), prefixIcon: const Icon(Icons.search_rounded), isDense: true),
            ),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(8, 8, 8, 16), children: [
              for (final s in list.take(60))
                ListTile(
                  key: Key('ret-sale-${s.id}'),
                  title: Text([trf('মেমো #{0}', [bnDigits(s.no)]), if (s.customer.isNotEmpty) s.customer].join(' · '), style: body(14.5, weight: FontWeight.w600)),
                  subtitle: Text('${shortDate(s.at)} · ${s.lines.map((l) => l.name).take(3).join(', ')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
                  trailing: Text(taka(s.total), style: body(14, weight: FontWeight.w600)),
                  onTap: () => Navigator.pop(context, s.id),
                ),
              if (list.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(tr('কোনো মেমো মেলেনি।'), textAlign: TextAlign.center, style: body(14, color: C.muted))),
            ]),
          ),
        ]),
      ),
    );
  }
}

// সাপ্লায়ারকে ফেরত ----------------------------------------------------------

class _SupplierReturn extends StatefulWidget {
  const _SupplierReturn({this.dealerId});
  final String? dealerId;
  @override
  State<_SupplierReturn> createState() => _SupplierReturnState();
}

class _SupplierReturnState extends State<_SupplierReturn> {
  Dealer? _dealer;
  final _items = <String, double>{}; // product id → qty
  String _reason = '';
  ReturnPay _pay = ReturnPay.payable;
  bool _busy = false;

  static const _reasons = ['নষ্ট/ফাটা', 'মেয়াদ শেষ', 'ভুল মাল', 'বেশি এসেছিল', 'অন্য'];

  @override
  void initState() {
    super.initState();
    if (widget.dealerId != null) _dealer = dealerById(BrainScope.read(context).shop, widget.dealerId!);
  }

  Product? _p(ShopBook b, String id) => b.products.where((p) => p.id == id).firstOrNull;

  Future<void> _addProduct() async {
    final b = BrainScope.read(context).shop;
    final ps = [for (final p in b.products) if (p.stock > 0 && !_items.containsKey(p.id)) p]
      ..sort((a, x) {
        final sa = _dealer != null && a.supplier == _dealer!.name, sx = _dealer != null && x.supplier == _dealer!.name;
        if (sa != sx) return sa ? -1 : 1;
        return a.name.compareTo(x.name);
      });
    final id = await showAppSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .6,
        child: ListView(padding: const EdgeInsets.fromLTRB(8, 4, 8, 16), children: [
          Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: Text(tr('কোন মাল ফেরত যাচ্ছে?'), style: display(18, weight: 600))),
          for (final p in ps)
            ListTile(
              key: Key('ret-p-${p.id}'),
              title: Text(p.name, style: body(14.5, weight: FontWeight.w600)),
              subtitle: Text(trf('কেনা {0} · স্টকে আছে {1} {2}', [taka(p.avgCost.round()), bnDigits(qtyText(p.stock)), tr(p.unit)]), style: body(12, color: C.muted)),
              onTap: () => Navigator.pop(ctx, p.id),
            ),
          if (ps.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(tr('স্টকে কোনো মাল নেই।'), textAlign: TextAlign.center, style: body(14, color: C.muted))),
        ]),
      ),
    );
    if (id != null) setState(() => _items[id] = 1);
  }

  int _worth(ShopBook b) => _items.entries.fold(0, (s, e) => s + (_p(b, e.key)?.costOf(e.value) ?? 0));

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    if (_dealer == null) return toast(context, tr('সাপ্লায়ার বেছে নিন'));
    if (_items.isEmpty || _busy) return toast(context, tr('কোন মাল ফেরত যাচ্ছে, যোগ করুন'));
    setState(() => _busy = true);
    final r = await brain.recordSupplierReturn(_dealer!.id, [for (final e in _items.entries) (e.key, e.value)], pay: _pay, reason: _reason);
    if (!mounted) return;
    Navigator.of(context).pop(r);
    if (r != null) toast(context, trf('{0}-কে ফেরত পাঠানো হলো · {1}', [r.dealer, taka(r.credit)]));
  }

  @override
  Widget build(BuildContext context) {
    final b = BrainScope.of(context).shop;
    final d = _dealer;
    final owe = d == null ? 0 : dealerAccount(b, d).due;
    final worth = _worth(b);
    final qtyAll = _items.values.fold<double>(0, (s, q) => s + q);
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), children: [
          _label(tr('সাপ্লায়ার')),
          _box(
            child: InkWell(
              key: const Key('ret-dealer'),
              onTap: () async {
                final x = await pickDealer(context);
                if (x != null) setState(() => _dealer = x);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                child: Row(children: [
                  d == null ? CircleAvatar(radius: 19, backgroundColor: C.surface2, child: Icon(Icons.local_shipping_outlined, color: C.muted)) : Avatar(name: d.name, size: 38, fg: C.orange, bg: C.orangeTint),
                  const SizedBox(width: 12),
                  Expanded(
                    child: d == null
                        ? Text(tr('সাপ্লায়ার বেছে নিন'), style: body(15, color: C.muted))
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d.name, style: body(15, weight: FontWeight.w700)),
                            Text(owe > 0 ? trf('আমরা দেব {0}', [taka(owe)]) : tr('কোনো দেনা নেই'), style: body(12, color: owe > 0 ? C.warn : C.muted)),
                          ]),
                  ),
                  Text(d == null ? tr('বাছুন') : tr('বদলান'), style: body(13, weight: FontWeight.w600, color: C.green)),
                ]),
              ),
            ),
          ),
          _label(tr('ফেরত যাচ্ছে')),
          _box(
            child: Column(children: [
              for (final MapEntry(key: id, value: q) in _items.entries)
                if (_p(b, id) case final p?) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(p.name, style: body(14.5, weight: FontWeight.w600)),
                          Text(trf('কেনা {0} · স্টকে আছে {1}', [taka(p.avgCost.round()), bnDigits(qtyText(p.stock))]), style: body(12, color: C.muted)),
                        ]),
                      ),
                      _stepper('ret-sq-$id', q, p.unit, () => setState(() => q <= 1 ? _items.remove(id) : _items[id] = q - 1), () => setState(() => _items[id] = (q + 1).clamp(0, p.stock).toDouble())),
                      const SizedBox(width: 8),
                      SizedBox(width: 64, child: Text(taka(p.costOf(q)), textAlign: TextAlign.right, style: body(14, weight: FontWeight.w700))),
                    ]),
                  ),
                  Divider(height: 1, color: C.border),
                ],
              InkWell(
                key: const Key('ret-add-product'),
                onTap: _addProduct,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(children: [
                    Icon(Icons.add_rounded, color: C.green),
                    const SizedBox(width: 10),
                    Text(_items.isEmpty ? tr('পণ্য যোগ করুন') : tr('আরেকটা পণ্য'), style: body(14.5, weight: FontWeight.w600, color: C.green)),
                  ]),
                ),
              ),
            ]),
          ),
          _label(tr('কারণ')),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final r in _reasons)
              ChoiceChip(
                key: Key('ret-reason-$r'),
                label: Text(tr(r)),
                selected: _reason == r,
                showCheckmark: false,
                onSelected: (_) => setState(() => _reason = _reason == r ? '' : r),
              ),
          ]),
          _label(tr('টাকা কীভাবে?')),
          SegTabs<ReturnPay>(
            key: const Key('ret-pay'),
            items: [(ReturnPay.payable, tr('দেনা থেকে কাটা')), (ReturnPay.cash, tr('নগদ ফেরত পেলাম')), (ReturnPay.replace, tr('বদলে মাল দেবে'))],
            value: _pay,
            onChanged: (v) => setState(() => _pay = v),
          ),
          if (d != null && worth > 0) ...[
            const SizedBox(height: 10),
            switch (_pay) {
              ReturnPay.cash => _sumBox([(tr('মালের কেনা দাম'), taka(worth), null)], (tr('ক্যাশে আসবে'), taka(worth))),
              _ => _sumBox([
                  (trf('{0}-কে দেনা ছিল', [d.name]), taka(owe), null),
                  (_pay == ReturnPay.replace ? tr('বদলে মাল পাওনা') : tr('ফেরত বাবদ কমলো'), '− ${taka(worth)}', C.green),
                ], (tr('এখন দেনা'), owe - worth < 0 ? '− ${taka(worth - owe)}' : taka(owe - worth))),
            },
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
              child: Text(trf('স্টক থেকে {0} কমবে · মূলধন বদলাবে না', [bnDigits(qtyText(qtyAll))]), style: body(12, color: C.muted)),
            ),
          ],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        child: PrimaryButton(key: const Key('ret-send'), label: tr('ফেরত পাঠান'), icon: Icons.check_rounded, onPressed: _busy || d == null || _items.isEmpty ? null : _save),
      ),
    ]);
  }
}
