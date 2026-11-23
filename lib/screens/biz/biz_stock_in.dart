import 'package:flutter/material.dart';

import '../../logic/bn.dart';
import '../../logic/lang.dart';
import '../../logic/shop_logic.dart';
import '../../models/models.dart';
import '../../state/brain.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'biz_hisab.dart' show pickDealer;
import 'biz_parts.dart';

/// স্টক যোগ (owner, 23 Nov): pick a product (live search) or write a new
/// one; how much came, the unit, buying and selling price, what one piece
/// holds, the section, the supplier, paid in full, part or not at all, and
/// a note. The goods go on the shelf at what they cost; what was not paid
/// goes on the supplier's account.
class StockInPage extends StatefulWidget {
  const StockInPage({super.key, this.productId, this.dealerId});
  final String? productId;
  final String? dealerId;
  @override
  State<StockInPage> createState() => _StockInPageState();
}

class _StockInPageState extends State<StockInPage> {
  Product? _p;
  String _newName = '';
  final _q = TextEditingController();
  final _qty = TextEditingController();
  final _buy = TextEditingController();
  final _sell = TextEditingController();
  final _weight = TextEditingController();
  final _paid = TextEditingController();
  final _note = TextEditingController();
  String _unit = 'পিস';
  String _wUnit = 'কেজি';
  String _section = '';
  Dealer? _dealer;
  String _pay = 'cash'; // cash | part | due
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final b = BrainScope.read(context).shop;
    if (widget.dealerId != null) _dealer = dealerById(b, widget.dealerId!);
    final p = widget.productId == null ? null : b.products.where((x) => x.id == widget.productId).firstOrNull;
    if (p != null) _use(p);
  }

  @override
  void dispose() {
    for (final c in [_q, _qty, _buy, _sell, _weight, _paid, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _use(Product p) {
    final b = BrainScope.read(context).shop;
    setState(() {
      _p = p;
      _newName = '';
      _unit = p.unit;
      _buy.text = p.buy > 0 ? bnDigits(p.buy) : '';
      _sell.text = p.sell > 0 ? bnDigits(p.sell) : '';
      final w = p.weight.trim().split(' ');
      _weight.text = w.isNotEmpty && readNum(w.first) != null ? w.first : '';
      if (w.length > 1 && shopUnits.contains(w[1])) _wUnit = w[1];
      _section = sectionOf(p);
      if (_dealer == null && p.supplier.isNotEmpty) _dealer = dealerNamed(b, p.supplier);
    });
  }

  void _startNew(String name) => setState(() {
        _p = null;
        _newName = name.trim();
        _section = guessSection(_newName) ?? '';
        _unit = 'পিস';
      });

  double get _n => readNum(_qty.text) ?? 0;
  int get _unitBuy => (readNum(_buy.text) ?? 0).round();
  int get _total => (_n * _unitBuy).round();
  int get _paidNow => switch (_pay) {
        'cash' => _total,
        'due' => 0,
        _ => ((readNum(_paid.text) ?? 0).round()).clamp(0, _total),
      };

  bool get _picked => _p != null || _newName.isNotEmpty;

  Future<void> _save() async {
    if (_busy) return;
    final brain = BrainScope.read(context);
    if (!_picked) return toast(context, tr('পণ্য বেছে নিন বা নতুন নাম লিখুন'));
    if (_n <= 0) return toast(context, tr('কত এলো লিখুন'));
    if (_paidNow < _total && _dealer == null) return toast(context, tr('বাকি থাকলে সাপ্লায়ার বেছে নিন — কার কাছে দেনা, তা জানা দরকার'));
    if (_p == null && !await bizNewProduct(context) || !mounted) return;
    setState(() => _busy = true);
    final weight = _weight.text.trim().isEmpty ? '' : '${_weight.text.trim()} $_wUnit';
    final sell = (readNum(_sell.text) ?? 0).round();
    final section = _section == otherSection ? '' : _section;
    var p = _p;
    if (p == null) {
      p = Product(name: _newName, unit: _unit, buy: _unitBuy, sell: sell, weight: weight, category: section, supplier: _dealer?.name ?? '', loose: _unit == 'কেজি' || _unit == 'গ্রাম' || _unit == 'লিটার');
      await brain.saveProduct(p);
    } else if (p.sell != sell || p.weight != weight || sectionOf(p) != _section || (p.stock == 0 && p.unit != _unit) || (_dealer != null && p.supplier != _dealer!.name)) {
      p = p.copyWith(sell: sell, weight: weight, category: section, unit: p.stock == 0 ? _unit : null, supplier: _dealer?.name);
      await brain.saveProduct(p);
    }
    await brain.recordPurchase(_dealer?.id ?? '', [(p, _n, _total)], paid: _paidNow, note: _note.text.trim());
    await brain.refreshOrders();
    if (!mounted) return;
    Navigator.of(context).pop(true);
    toast(context, trf('{0} {1} {2} স্টকে যোগ হলো', [p.name, bnDigits(qtyText(_n)), tr(_unit)]));
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final owe = _total - _paidNow;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          InnerTop(title: tr('স্টক যোগ'), sub: tr('মাল এলো — স্টকে উঠবে, হিসাবে লেখা হবে')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 20), children: [
              _label(tr('পণ্য')),
              if (_picked) _pickedCard() else ..._search(b),
              if (_picked) ...[
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: NumField(controller: _qty, fieldKey: const Key('stockin-qty'), label: tr('কত এলো'), decimal: true, onChanged: (_) => setState(() {}))),
                  const SizedBox(width: 10),
                  Expanded(child: _unitPick(enabled: _p == null || _p!.stock == 0)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: NumField(controller: _buy, fieldKey: const Key('stockin-buy'), label: trf('কেনা দাম / {0}', [tr(_unit)]), onChanged: (_) => setState(() {}))),
                  const SizedBox(width: 10),
                  Expanded(child: NumField(controller: _sell, fieldKey: const Key('stockin-sell'), label: trf('বিক্রি দাম / {0}', [tr(_unit)]))),
                ]),
                if (_unitBuy > 0 && (readNum(_sell.text) ?? 0) > 0 && (readNum(_sell.text) ?? 0) < _unitBuy)
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr('বিক্রি দাম কেনা দামের চেয়ে কম — বিক্রিতে ক্ষতি হবে'), style: body(12, color: C.red))),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(child: NumField(controller: _weight, fieldKey: const Key('stockin-weight'), label: tr('প্রতিটির ওজন (ঐচ্ছিক)'), decimal: true, hint: tr('যেমন ৫'))),
                  const SizedBox(width: 10),
                  Expanded(child: _drop(const Key('stockin-wunit'), _wUnit, const ['কেজি', 'গ্রাম', 'লিটার', 'মিলি'], (v) => setState(() => _wUnit = v))),
                ]),
                const SizedBox(height: 12),
                _label(tr('ক্যাটাগরি')),
                _drop(const Key('stockin-section'), _section.isEmpty ? otherSection : _section, {...shelfSuggestions, ...[for (final (s, _) in shelves(b.products)) s], otherSection, if (_section.isNotEmpty) _section}.toList(), (v) => setState(() => _section = v)),
                const SizedBox(height: 14),
                _label(tr('সাপ্লায়ার')),
                Material(
                  color: C.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: C.border)),
                  child: InkWell(
                    key: const Key('stockin-dealer'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      final d = await pickDealer(context);
                      if (d != null) setState(() => _dealer = d);
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                      child: Row(children: [
                        Icon(Icons.local_shipping_outlined, size: 20, color: C.muted),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_dealer?.name ?? tr('বেছে নিন বা নতুন যোগ করুন'), style: body(15, weight: _dealer == null ? FontWeight.w400 : FontWeight.w600, color: _dealer == null ? C.muted : C.ink))),
                        Text(_dealer == null ? tr('বাছুন') : tr('বদলান'), style: body(13, color: C.green, weight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                ),
                if (_dealer != null && dealerAccount(b, _dealer!).due > 0)
                  Padding(padding: const EdgeInsets.fromLTRB(4, 6, 4, 0), child: Text(trf('আগের দেনা {0}', [taka(dealerAccount(b, _dealer!).due)]), style: body(12, color: C.warn))),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
                  child: Row(children: [
                    Expanded(child: Text(tr('মোট দাম'), style: body(14, color: C.muted))),
                    Text(taka(_total), key: const Key('stockin-total'), style: display(22, weight: 700)),
                  ]),
                ),
                const SizedBox(height: 14),
                _label(tr('টাকা দেওয়া হয়েছে?')),
                SegmentedButton<String>(
                  key: const Key('stockin-pay'),
                  segments: [
                    ButtonSegment(value: 'cash', label: Text(tr('পুরো নগদ'))),
                    ButtonSegment(value: 'part', label: Text(tr('আংশিক'))),
                    ButtonSegment(value: 'due', label: Text(tr('পুরো বাকি'))),
                  ],
                  selected: {_pay},
                  showSelectedIcon: false,
                  onSelectionChanged: (v) => setState(() => _pay = v.first),
                ),
                if (_pay == 'part') ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: NumField(controller: _paid, fieldKey: const Key('stockin-paid'), label: tr('দিলাম ৳'), onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                          decoration: BoxDecoration(color: C.warnBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.warnBorder)),
                          child: Text(trf('বাকি {0}', [taka(owe)]), style: body(14.5, weight: FontWeight.w700, color: C.warn)),
                        ),
                      ),
                    ),
                  ]),
                ],
                const SizedBox(height: 12),
                LabeledField(controller: _note, fieldKey: const Key('stockin-note'), label: tr('নোট'), hint: tr('যেমন: চালান নং ৪৫২৬')),
              ],
            ]),
          ),
          if (_picked)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
              child: Column(children: [
                PrimaryButton(key: const Key('stockin-save'), label: tr('স্টকে যোগ করুন'), icon: Icons.check_rounded, onPressed: _busy ? null : _save),
                if (_total > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      [
                        if (_paidNow > 0) trf('ক্যাশ থেকে {0} কমবে', [taka(_paidNow)]),
                        if (owe > 0) trf('{0}-এর পাওনা {1} বাড়বে', [_dealer?.name ?? tr('সাপ্লায়ার'), taka(owe)]),
                      ].join(' · '),
                      textAlign: TextAlign.center,
                      style: body(12, color: C.muted),
                    ),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _label(String s) => Padding(padding: const EdgeInsets.fromLTRB(2, 0, 2, 6), child: Text(s, style: body(12.5, color: C.muted)));

  Widget _unitPick({required bool enabled}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(tr('একক')),
        enabled ? _drop(const Key('stockin-unit'), _unit, shopUnits, (v) => setState(() => _unit = v)) : Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12)),
          child: Text(tr(_unit), style: body(15)),
        ),
      ]);

  Widget _drop(Key key, String value, List<String> items, ValueChanged<String> on) => DropdownButtonFormField<String>(
        key: key,
        initialValue: items.contains(value) ? value : items.first,
        isExpanded: true,
        decoration: const InputDecoration(isDense: true),
        items: [for (final u in items) DropdownMenuItem(value: u, child: Text(tr(u), style: body(14.5), overflow: TextOverflow.ellipsis))],
        onChanged: (v) => v == null ? null : on(v),
      );

  Widget _pickedCard() {
    final p = _p;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p?.name ?? _newName, key: const Key('stockin-picked'), style: body(15.5, weight: FontWeight.w700)),
            Text(p == null ? tr('নতুন পণ্য') : trf('{0} · এখন {1} {2}', [tr(sectionOf(p)), bnDigits(qtyText(p.stock)), tr(p.unit)]), style: body(12.5, color: C.muted)),
          ]),
        ),
        TextButton(key: const Key('stockin-change'), onPressed: () => setState(() {
          _p = null;
          _newName = '';
        }), child: Text(tr('বদলান'), style: body(13.5, weight: FontWeight.w600, color: C.green))),
      ]),
    );
  }

  List<Widget> _search(ShopBook b) {
    final q = _q.text.trim().toLowerCase();
    final list = [for (final p in b.products) if (q.isEmpty || p.name.toLowerCase().contains(q)) p]..sort((a, x) {
        if (q.isNotEmpty) {
          final sa = a.name.toLowerCase().startsWith(q), sx = x.name.toLowerCase().startsWith(q);
          if (sa != sx) return sa ? -1 : 1;
        }
        if (a.isLow != x.isLow) return a.isLow ? -1 : 1;
        return a.name.compareTo(x.name);
      });
    final exact = b.products.any((p) => p.name.trim().toLowerCase() == q);
    return [
      TextField(textCapitalization: TextCapitalization.sentences, 
        key: const Key('stockin-q'),
        controller: _q,
        autofocus: widget.productId == null,
        onChanged: (_) => setState(() {}),
        onSubmitted: (v) {
          if (v.trim().isNotEmpty && list.isEmpty) _startNew(v);
        },
        style: body(15),
        decoration: InputDecoration(hintText: tr('পণ্যের নাম লিখুন'), prefixIcon: const Icon(Icons.search_rounded), isDense: true),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (final (i, p) in list.take(8).indexed) ...[
            if (i > 0) Divider(height: 1, color: C.border, indent: 14, endIndent: 14),
            InkWell(
              key: Key('stockin-p-${p.id}'),
              onTap: () => _use(p),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: body(14.5, weight: FontWeight.w600)),
                      Text(trf('{0} · এখন {1} {2}', [tr(sectionOf(p)), bnDigits(qtyText(p.stock)), tr(p.unit)]), style: body(12, color: p.isLow ? C.red : C.muted)),
                    ]),
                  ),
                  Icon(Icons.chevron_right_rounded, color: C.muted),
                ]),
              ),
            ),
          ],
          if (q.isNotEmpty && !exact) ...[
            if (list.isNotEmpty) Divider(height: 1, color: C.border),
            InkWell(
              key: const Key('stockin-new'),
              onTap: () => _startNew(_q.text),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(children: [
                  Icon(Icons.add_rounded, color: C.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(trf('নতুন পণ্য: “{0}”', [_q.text.trim()]), style: body(14.5, weight: FontWeight.w600, color: C.green))),
                ]),
              ),
            ),
          ],
          if (q.isEmpty && list.isEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text(tr('নাম লিখুন — নতুন পণ্য হিসেবে যোগ হবে।'), style: body(13.5, color: C.muted))),
        ]),
      ),
    ];
  }
}
