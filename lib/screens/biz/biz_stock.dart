import 'package:flutter/material.dart';

import '../../logic/bn.dart';
import '../../logic/lang.dart';
import '../../logic/shop_logic.dart';
import '../../models/models.dart';
import '../../state/brain.dart';
import '../../ui/forms.dart' show askText;
import '../../ui/kit.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'biz_parts.dart';

/// স্টক (business mode tab; My Assistant's "সংরক্ষণ" in its place).
class BizStock extends StatefulWidget {
  const BizStock({super.key});
  @override
  State<BizStock> createState() => _BizStockState();
}

class _BizStockState extends State<BizStock> {
  String _part = 'all';

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final now = brain.services.now();
    final low = lowStock(b);
    final exp = expiring(b, now);
    final worth = b.products.fold<int>(0, (s, p) => s + (p.buy * p.stock).round());
    final shown = switch (_part) {
      'low' => low,
      'expiry' => [for (final p in b.products) if (p.expiry != null) p]..sort((a, c) => a.expiry!.compareTo(c.expiry!)),
      _ => b.products,
    };
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
      TabTitle(tr('স্টক'),
          sub: trf('{0}টি পণ্য · কেনা দামে {1}', [bnDigits(b.products.length), taka(worth)]),
          trailing: IconButton(key: const Key('biz-stock-add'), tooltip: tr('নতুন পণ্য'), onPressed: () => pushPage(context, const ProductForm()), icon: const Icon(Icons.add_box_outlined))),
      if (exp.isNotEmpty) ...[
        const SizedBox(height: 12),
        AttentionCard(
          icon: Icons.schedule_rounded,
          title: trf('{0}-এর মেয়াদ {1}', [exp.first.name, dayOnly(exp.first.expiry!).isAfter(dayOnly(now)) ? trf('{0} শেষ', [shortDate(exp.first.expiry!)]) : tr('শেষ হয়ে গেছে')]),
          text: exp.length > 1 ? trf('আরও {0}টি পণ্যের মেয়াদ কাছে · কম দামে বিক্রি করতে পারেন', [bnDigits(exp.length - 1)]) : tr('আজ কম দামে বিক্রি করতে পারেন'),
          action: tr('দেখুন'),
          onAction: () => setState(() => _part = 'expiry'),
        ),
      ],
      const SizedBox(height: 12),
      SegTabs<String>(
        key: const Key('biz-stock-part'),
        items: [('all', tr('সব পণ্য')), ('low', low.isEmpty ? tr('কম স্টক') : trf('কম স্টক · {0}', [bnDigits(low.length)])), ('expiry', tr('মেয়াদ'))],
        value: _part,
        onChanged: (v) => setState(() => _part = v),
      ),
      if (b.products.isEmpty) ...[
        const SizedBox(height: 16),
        EmptyState(
          icon: Icons.inventory_2_outlined,
          title: tr('এখনো কোনো পণ্য নেই'),
          text: tr('পণ্যের নাম, কেনা-বেচার দাম আর কতটা আছে দিন — বিক্রি করলে স্টক নিজে থেকে কমবে, কম হলে অর্ডার তালিকায় উঠবে।'),
          action: tr('পণ্য যোগ করুন'),
          onAction: () => pushPage(context, const ProductForm()),
        ),
      ] else if (shown.isEmpty)
        Padding(padding: const EdgeInsets.only(top: 18), child: Text(_part == 'low' ? tr('কোনো পণ্য কম নেই।') : tr('মেয়াদ দেওয়া কোনো পণ্য নেই।'), style: body(14, color: C.muted)))
      else
        for (final (shelf, ps) in shelves(shown)) ...[
          SectionHeading(shelf, counter: trf('{0}টি', [bnDigits(ps.length)])),
          ListCard(
            rows: [for (final p in ps) _productRow(context, p, now)],
            foot: shelf == shelves(shown).last.$1
                ? CardFoot(left: tr('+ পণ্য যোগ'), onLeft: () => pushPage(context, ProductForm(category: shelf == 'অন্যান্য' ? '' : shelf)), right: tr('মাল কেনা'), onRight: () => pushPage(context, const PurchasePage()), leftKey: const Key('biz-add-product'), rightKey: const Key('biz-open-purchase'))
                : null,
          ),
        ],
    ]);
  }

  Widget _productRow(BuildContext context, Product p, DateTime now) {
    final exp = p.expiry;
    final soon = exp != null && !dayOnly(exp).isAfter(dayOnly(now).add(const Duration(days: 3)));
    return ListRow(
      key: Key('biz-product-${p.id}'),
      leading: LetterTile(p.name),
      title: p.name,
      subtitle: [
        trf('বিক্রি {0} / {1}', [taka(p.sell), p.unit]),
        if (exp != null) trf('মেয়াদ {0}', [shortDate(exp)]),
      ].join(' · '),
      subtitleColor: soon ? C.warn : null,
      trailing: p.isLow ? WarnChip('${bnDigits(qtyText(p.stock))} ${p.unit}') : Text('${bnDigits(qtyText(p.stock))} ${p.unit}', style: body(14, weight: FontWeight.w600)),
      onTap: () => pushPage(context, ProductForm(product: p)),
    );
  }
}

/// নতুন পণ্য / পণ্য বদলান.
class ProductForm extends StatefulWidget {
  const ProductForm({super.key, this.product, this.category = ''});
  final Product? product;
  final String category;
  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  late final Product? _p = widget.product;
  late final _name = TextEditingController(text: _p?.name ?? '');
  late final _buy = TextEditingController(text: _p == null || _p.buy == 0 ? '' : '${_p.buy}');
  late final _sell = TextEditingController(text: _p == null || _p.sell == 0 ? '' : '${_p.sell}');
  late final _stock = TextEditingController(text: _p == null ? '' : qtyText(_p.stock));
  late final _low = TextEditingController(text: _p == null || _p.low == 0 ? '' : qtyText(_p.low));
  late final _bulkFrom = TextEditingController(text: _p?.bulkFrom == null ? '' : qtyText(_p!.bulkFrom!));
  late final _bulkPrice = TextEditingController(text: _p?.bulkPrice == null ? '' : '${_p!.bulkPrice}');
  late final _barcode = TextEditingController(text: _p?.barcode ?? '');
  late final _supplier = TextEditingController(text: _p?.supplier ?? '');
  late final _shelf = TextEditingController(text: _p?.category ?? widget.category);
  late String _unit = _p?.unit ?? 'কেজি';
  late bool _loose = _p?.loose ?? true;
  late bool _bulk = _p?.bulkFrom != null;
  late bool _hasExpiry = _p?.expiry != null;
  late bool _hasBarcode = (_p?.barcode ?? '').isNotEmpty;
  late bool _hasSupplier = (_p?.supplier ?? '').isNotEmpty;
  late DateTime? _expiry = _p?.expiry;

  @override
  void dispose() {
    for (final c in [_name, _buy, _sell, _stock, _low, _bulkFrom, _bulkPrice, _barcode, _supplier, _shelf]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, tr('পণ্যের নাম লিখুন'));
      return;
    }
    final p = Product(
      id: _p?.id,
      name: name,
      unit: _unit,
      buy: (readNum(_buy.text) ?? 0).round(),
      sell: (readNum(_sell.text) ?? 0).round(),
      stock: readNum(_stock.text) ?? 0,
      low: readNum(_low.text) ?? 0,
      loose: _loose && (_unit == 'কেজি' || _unit == 'গ্রাম' || _unit == 'লিটার'),
      bulkFrom: _bulk ? readNum(_bulkFrom.text) : null,
      bulkPrice: _bulk ? readNum(_bulkPrice.text)?.round() : null,
      expiry: _hasExpiry ? _expiry : null,
      barcode: _hasBarcode ? _barcode.text.trim() : '',
      supplier: _hasSupplier ? _supplier.text.trim() : '',
      category: _shelf.text.trim(),
    );
    await brain.saveProduct(p);
    await brain.refreshOrders();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final weighable = _unit == 'কেজি' || _unit == 'গ্রাম' || _unit == 'লিটার';
    final suppliers = {for (final p in brain.shop.products) if (p.supplier.isNotEmpty) p.supplier, for (final o in owed(brain.data)) o.name}.toList();
    final shelvesUsed = {...shelfSuggestions, for (final p in brain.shop.products) if (p.category.isNotEmpty) p.category}.toList();

    Widget extra(String key, bool on, String title, String sub, ValueChanged<bool> set, Widget field) => Column(children: [
          CheckboxListTile(
            key: Key('biz-extra-$key'),
            value: on,
            onChanged: (v) => setState(() => set(v ?? false)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: Text(title, style: body(14)),
            subtitle: Text(sub, style: body(11.5, color: C.muted)),
          ),
          if (on) Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 12), child: field),
        ]);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          InnerTop(
            title: _p == null ? tr('নতুন পণ্য') : tr('পণ্য বদলান'),
            actions: [
              if (_p != null)
                IconButton(
                  key: const Key('biz-product-delete'),
                  tooltip: tr('মুছুন'),
                  onPressed: () async {
                    final ok = await confirmDialog(context, title: trf('‘{0}’ মুছবেন?', [_p.name]), text: tr('বিক্রির পুরোনো হিসাব থেকে যাবে। মুছে ফেলা থেকে ৩০ দিন ফেরানো যায়।'), yes: tr('মুছুন'), danger: true);
                    if (!ok || !context.mounted) return;
                    await BrainScope.read(context).deleteProduct(_p.id);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: Icon(Icons.delete_outline_rounded, color: C.red),
                ),
            ],
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              Padding(padding: const EdgeInsets.fromLTRB(2, 6, 2, 6), child: Text(tr('পণ্যের নাম'), style: body(12.5, color: C.muted))),
              TextField(key: const Key('biz-product-name'), controller: _name, autofocus: _p == null, style: body(15), decoration: InputDecoration(hintText: tr('যেমন: মসুর ডাল'), isDense: true)),
              const SizedBox(height: 14),
              Text(tr('কীভাবে বিক্রি হয়'), style: body(12.5, color: C.muted)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final u in shopUnits)
                  ChoiceChip(key: Key('biz-unit-$u'), label: Text(tr(u)), selected: _unit == u, onSelected: (_) => setState(() => _unit = u)),
              ]),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 2.1,
                children: [
                  NumField(controller: _buy, label: tr('কেনা দাম'), hint: trf('৳ / {0}', [tr(_unit)]), fieldKey: const Key('biz-product-buy')),
                  NumField(controller: _sell, label: tr('বিক্রির দাম'), hint: trf('৳ / {0}', [tr(_unit)]), fieldKey: const Key('biz-product-sell')),
                  NumField(controller: _stock, label: tr('এখন স্টকে'), hint: trf('কত {0}', [tr(_unit)]), decimal: true, fieldKey: const Key('biz-product-stock')),
                  NumField(controller: _low, label: tr('কম হলে জানাবে'), hint: trf('কত {0}', [tr(_unit)]), decimal: true, fieldKey: const Key('biz-product-low')),
                ],
              ),
              const SizedBox(height: 6),
              Padding(padding: const EdgeInsets.fromLTRB(2, 6, 2, 6), child: Text(tr('তাক (বিভাগ)'), style: body(12.5, color: C.muted))),
              TextField(key: const Key('biz-product-shelf'), controller: _shelf, style: body(15), decoration: InputDecoration(hintText: tr('যেমন: চাল-ডাল'), isDense: true)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final s in shelvesUsed) ActionChip(label: Text(tr(s), style: body(12)), onPressed: () => setState(() => _shelf.text = s))]),
              SectionHeading(tr('বাড়তি তথ্য'), counter: tr('ইচ্ছামতো')),
              Panel(
                child: Column(children: [
                  if (weighable)
                    extra('loose', _loose, tr('খোলা পণ্য, ওজনে বিক্রি'), tr('যেকোনো ওজনে দাম নিজে হিসাব হবে'), (v) => _loose = v,
                        Text(trf('বিক্রির সময় ওজন লিখলেই দাম: {0} / {1}', [_sell.text.isEmpty ? '৳—' : taka((readNum(_sell.text) ?? 0).round()), tr(_unit)]), style: body(12.5, color: C.muted))),
                  extra('bulk', _bulk, tr('পাইকারি দর'), tr('বেশি নিলে কম দাম, যেমন বস্তায়'), (v) => _bulk = v,
                      Row(children: [
                        Expanded(child: NumField(controller: _bulkFrom, label: trf('কত {0} বা বেশি', [tr(_unit)]), decimal: true, fieldKey: const Key('biz-product-bulk-from'))),
                        const SizedBox(width: 12),
                        Expanded(child: NumField(controller: _bulkPrice, label: trf('তখন ৳ / {0}', [tr(_unit)]), fieldKey: const Key('biz-product-bulk-price'))),
                      ])),
                  extra('expiry', _hasExpiry, tr('মেয়াদ শেষের তারিখ'), tr('দুধ, বিস্কুট, প্যাকেটজাত খাবার'), (v) => _hasExpiry = v,
                      SecondaryButton(
                        key: const Key('biz-product-expiry'),
                        label: _expiry == null ? tr('তারিখ বাছুন') : '${bnDigits(_expiry!.day)} ${monthName(_expiry!.month)} ${bnDigits(_expiry!.year)}',
                        icon: Icons.event_outlined,
                        height: 44,
                        onPressed: () async {
                          final now = brain.services.now();
                          final d = await showDatePicker(context: context, initialDate: _expiry ?? now.add(const Duration(days: 7)), firstDate: now.subtract(const Duration(days: 30)), lastDate: DateTime(now.year + 5));
                          if (d != null) setState(() => _expiry = d);
                        },
                      )),
                  extra('barcode', _hasBarcode, tr('বারকোড'), tr('প্যাকেটের নিচের নম্বর — খুঁজলে এই নম্বরেও পাওয়া যাবে'), (v) => _hasBarcode = v,
                      TextField(key: const Key('biz-product-barcode'), controller: _barcode, keyboardType: TextInputType.number, style: body(15), decoration: InputDecoration(hintText: tr('বারকোডের নম্বর'), isDense: true))),
                  extra('supplier', _hasSupplier, tr('কার কাছ থেকে কেনা'), tr('অর্ডার তালিকায় সাপ্লায়ার ধরে ভাগ হবে'), (v) => _hasSupplier = v,
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        TextField(key: const Key('biz-product-supplier'), controller: _supplier, style: body(15), decoration: InputDecoration(hintText: tr('যেমন: করিম ট্রেডার্স'), isDense: true)),
                        if (suppliers.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(spacing: 6, runSpacing: 6, children: [for (final s in suppliers.take(6)) ActionChip(label: Text(s, style: body(12)), onPressed: () => setState(() => _supplier.text = s))]),
                        ],
                      ])),
                ]),
              ),
            ]),
          ),
          PageFoot(child: PrimaryButton(key: const Key('biz-product-save'), label: tr('পণ্য রাখুন'), icon: Icons.check_rounded, onPressed: _save)),
        ]),
      ),
    );
  }
}

/// মাল কেনা: the order list (by supplier) and goods coming in.
class PurchasePage extends StatefulWidget {
  const PurchasePage({super.key});
  @override
  State<PurchasePage> createState() => _PurchasePageState();
}

class _PurchasePageState extends State<PurchasePage> {
  String _part = 'order';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BrainScope.read(context).refreshOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final bySup = <String, List<OrderLine>>{};
    for (final o in b.orders) {
      bySup.putIfAbsent(o.supplier.isEmpty ? tr('সাপ্লায়ার দেওয়া নেই') : o.supplier, () => []).add(o);
    }
    Product? productOf(OrderLine o) => b.products.where((p) => p.id == o.productId).firstOrNull;
    int estimate(List<OrderLine> lines) => lines.where((o) => o.picked).fold(0, (s, o) => s + ((productOf(o)?.buy ?? 0) * o.qty).round());
    String listText(String sup, List<OrderLine> lines) => [
          trf('অর্ডার — {0}', [sup]),
          for (final o in lines.where((o) => o.picked)) '• ${o.name} — ${bnDigits(qtyText(o.qty))} ${o.unit}',
        ].join('\n');

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          InnerTop(title: tr('মাল কেনা'), sub: tr('কম স্টকের পণ্য নিজে থেকেই তালিকায় আসে')),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: SegTabs<String>(key: const Key('biz-purchase-part'), items: [('order', tr('অর্ডার তালিকা')), ('in', tr('মাল এল'))], value: _part, onChanged: (v) => setState(() => _part = v)),
          ),
          Expanded(
            child: _part == 'in'
                ? const _GoodsIn()
                : ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
                    if (b.orders.isEmpty)
                      Padding(padding: const EdgeInsets.only(top: 12), child: Text(tr('তালিকা খালি। কোনো পণ্য কম হলে এখানে নিজে থেকে উঠবে, বা নিচ থেকে যোগ করুন।'), style: body(14, color: C.muted, height: 1.5))),
                    for (final MapEntry(key: sup, value: lines) in bySup.entries) ...[
                      Builder(builder: (_) {
                        final debt = owed(brain.data).where((p) => p.name == sup).firstOrNull;
                        return Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 6),
                          child: Row(children: [
                            Expanded(child: Text(sup, style: display(17, weight: 600))),
                            if (debt != null) WarnChip(trf('দেনা {0}', [taka(-debt.balance)])),
                          ]),
                        );
                      }),
                      ListCard(
                        rows: [
                          for (final o in lines)
                            Builder(builder: (_) {
                              final p = productOf(o);
                              return ListRow(
                                key: Key('biz-order-${o.id}'),
                                leading: Checkbox(value: o.picked, onChanged: (v) => brain.saveOrder(o.copyWith(picked: v ?? true))),
                                title: o.name,
                                subtitle: p == null ? null : trf('আছে {0} {1}', [bnDigits(qtyText(p.stock)), p.unit]),
                                subtitleColor: p != null && p.isLow ? C.warn : null,
                                trailing: SoftChip('${bnDigits(qtyText(o.qty))} ${tr(o.unit)}', onTap: () async {
                                  final v = await askText(context, trf('{0} — কত {1}?', [o.name, tr(o.unit)]), initial: qtyText(o.qty), number: true);
                                  final n = v == null ? null : readNum(v);
                                  if (n != null && n > 0) await brain.saveOrder(o.copyWith(qty: n));
                                }),
                                onLongPress: () => brain.removeOrder(o.id),
                              );
                            }),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                            child: Row(children: [
                              Expanded(child: Text(trf('{0}টি পণ্য · আনুমানিক', [bnDigits(lines.where((o) => o.picked).length)]), style: body(13, color: C.muted))),
                              Text(taka(estimate(lines)), style: display(18, weight: 600)),
                            ]),
                          ),
                        ],
                        foot: CardFoot(
                          left: tr('শেয়ার / প্রিন্ট'),
                          onLeft: () => brain.services.files.shareText(listText(sup, lines)),
                          right: tr('হোয়াটসঅ্যাপে অর্ডার'),
                          onRight: () => brain.services.launcher.open(Via.whatsapp, '', text: listText(sup, lines)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SecondaryButton(
                      key: const Key('biz-order-add'),
                      label: tr('+ আরও পণ্য যোগ করুন'),
                      onPressed: () async {
                        final pick = await _pickProduct(context, b.products.where((p) => !b.orders.any((o) => o.productId == p.id)).toList());
                        if (pick != null) await brain.saveOrder(OrderLine(productId: pick.id, name: pick.name, qty: suggestedOrder(pick), unit: pick.unit, supplier: pick.supplier));
                      },
                    ),
                  ]),
          ),
        ]),
      ),
    );
  }
}

Future<Product?> _pickProduct(BuildContext context, List<Product> ps) => showAppSheet<Product>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: ps.isEmpty
            ? Padding(padding: const EdgeInsets.all(24), child: Text(tr('যোগ করার মতো আর কোনো পণ্য নেই।'), style: body(14, color: C.muted)))
            : ListView(shrinkWrap: true, children: [
                for (final p in ps) ListTile(leading: LetterTile(p.name, size: 36), title: Text(p.name, style: body(15)), subtitle: Text('${bnDigits(qtyText(p.stock))} ${p.unit}', style: body(12, color: C.muted)), onTap: () => Navigator.pop(ctx, p)),
              ]),
      ),
    );

/// মাল এল: what came in, how much it cost, paid now or owed.
class _GoodsIn extends StatefulWidget {
  const _GoodsIn();
  @override
  State<_GoodsIn> createState() => _GoodsInState();
}

class _GoodsInState extends State<_GoodsIn> {
  final _supplier = TextEditingController();
  final _lines = <(Product, TextEditingController qty, TextEditingController amount)>[];
  bool _paid = true;

  @override
  void dispose() {
    _supplier.dispose();
    for (final l in _lines) {
      l.$2.dispose();
      l.$3.dispose();
    }
    super.dispose();
  }

  void _add(Product p, {double? qty}) {
    final q = qty ?? suggestedOrder(p);
    setState(() => _lines.add((p, TextEditingController(text: qtyText(q)), TextEditingController(text: p.buy > 0 ? '${(p.buy * q).round()}' : ''))));
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final total = _lines.fold<int>(0, (s, l) => s + (readNum(l.$3.text) ?? 0).round());
    return Column(children: [
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), children: [
          if (_lines.isEmpty && b.orders.any((o) => o.picked))
            SecondaryButton(
              key: const Key('biz-in-from-order'),
              label: tr('অর্ডার তালিকা থেকে নিন'),
              icon: Icons.playlist_add_check_rounded,
              onPressed: () {
                for (final o in b.orders.where((o) => o.picked)) {
                  final p = b.products.where((p) => p.id == o.productId).firstOrNull;
                  if (p != null) _add(p, qty: o.qty);
                }
                final sup = b.orders.firstWhere((o) => o.picked).supplier;
                if (_supplier.text.isEmpty) _supplier.text = sup;
              },
            ),
          Padding(padding: const EdgeInsets.fromLTRB(2, 12, 2, 6), child: Text(tr('কার কাছ থেকে'), style: body(12.5, color: C.muted))),
          TextField(key: const Key('biz-in-supplier'), controller: _supplier, style: body(15), decoration: InputDecoration(hintText: tr('যেমন: করিম ট্রেডার্স'), isDense: true)),
          const SizedBox(height: 12),
          ListCard(
            empty: tr('কোন কোন পণ্য এল, যোগ করুন।'),
            rows: [
              for (final (i, (p, q, a)) in _lines.indexed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(14))),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: TextField(key: Key('biz-in-qty-$i'), controller: q, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: body(14), decoration: InputDecoration(isDense: true, suffixText: tr(p.unit)), onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 8),
                    Expanded(flex: 2, child: TextField(key: Key('biz-in-amount-$i'), controller: a, keyboardType: TextInputType.number, style: body(14), decoration: const InputDecoration(isDense: true, prefixText: '৳'), onChanged: (_) => setState(() {}))),
                    IconButton(tooltip: tr('বাদ দিন'), onPressed: () => setState(() => _lines.removeAt(i)), icon: Icon(Icons.close_rounded, color: C.muted, size: 20)),
                  ]),
                ),
            ],
            foot: CardFoot(
              left: tr('+ পণ্য'),
              leftKey: const Key('biz-in-add'),
              onLeft: () async {
                final p = await _pickProduct(context, b.products.where((p) => !_lines.any((l) => l.$1.id == p.id)).toList());
                if (p != null) _add(p);
              },
            ),
          ),
          const SizedBox(height: 14),
          SegTabs<bool>(key: const Key('biz-in-paid'), items: [(true, tr('টাকা দিয়েছি')), (false, tr('বাকিতে (দেনা)'))], value: _paid, onChanged: (v) => setState(() => _paid = v)),
        ]),
      ),
      PageFoot(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Expanded(child: Text(tr('মোট'), style: body(14, color: C.muted))), Text(taka(total), style: display(24, weight: 600))]),
          const SizedBox(height: 10),
          PrimaryButton(
            key: const Key('biz-in-save'),
            label: tr('মাল তুলুন'),
            icon: Icons.move_to_inbox_outlined,
            onPressed: () async {
              if (_lines.isEmpty) return toast(context, tr('কোন পণ্য এল, যোগ করুন'));
              if (!_paid && _supplier.text.trim().isEmpty) return toast(context, tr('বাকিতে হলে কার কাছ থেকে, লিখুন'));
              await brain.goodsIn(_supplier.text, [for (final (p, q, a) in _lines) (p, readNum(q.text) ?? 0, (readNum(a.text) ?? 0).round())], paid: _paid);
              if (!context.mounted) return;
              toast(context, tr('স্টকে তোলা হয়েছে'));
              Navigator.of(context).pop();
            },
          ),
        ]),
      ),
    ]);
  }
}
