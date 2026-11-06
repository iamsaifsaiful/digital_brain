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
import '../home_shell.dart' show openVoice;
import 'biz_customers.dart' show pickCustomer, CustomerPage;
import 'biz_parts.dart';
import 'biz_shop.dart' show showReceiptPdf;

/// বিক্রি (business mode tab; My Assistant's "দিনলিপি" in its place).
class BizSales extends StatefulWidget {
  const BizSales({super.key});
  @override
  State<BizSales> createState() => _BizSalesState();
}

class _BizSalesState extends State<BizSales> {
  String _when = 'today';

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final today = dayOnly(brain.services.now());
    final todaySum = DaySum(salesOn(b, today));
    final (cash, qr, credit) = (todaySum.by(SalePay.cash), todaySum.by(SalePay.qr), todaySum.by(SalePay.credit));

    // Owner, 7 Nov: the inner tabs slide with the finger like everywhere
    // else, and the page reads in the order it is used: sell first, then
    // today's money, then the list.
    return TabPages<String>(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      items: [('today', tr('আজ')), ('yesterday', tr('গতকাল')), ('week', tr('এই সপ্তাহ')), ('best', tr('বেশি বিক্রি'))],
      value: _when,
      onChanged: (v) => setState(() => _when = v),
      top: (tabs) => [
        TabTitle(tr('বিক্রি'), sub: trf('আজ {0}টি বিক্রি · {1}', [bnDigits(todaySum.count), taka(todaySum.total)])),
        const BizFreeBanner(),
        const SizedBox(height: 12),
        // The one big action, by the thumb's reach.
        Material(
          color: C.green,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            key: const Key('biz-sell-start'),
            borderRadius: BorderRadius.circular(18),
            onTap: () => pushPage(context, const SellPage()),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: C.onAccent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.add_shopping_cart_rounded, color: C.onAccent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('নতুন বিক্রি'), style: body(18, weight: FontWeight.w700, color: C.onAccent)),
                    Text(tr('পণ্য বাছুন, পরিমাণ দিন, টাকা নিন'), style: body(12.5, color: C.onAccent.withValues(alpha: 0.85))),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: C.onAccent, size: 28),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: SmallButton(key: const Key('biz-sell-amount'), label: tr('শুধু টাকা লিখে'), icon: Icons.payments_outlined, onTap: () => pushPage(context, const SellPage(amountOnly: true)))),
          const SizedBox(width: 8),
          Expanded(child: SmallButton(key: const Key('biz-sell-voice'), label: tr('মুখে বলে'), icon: Icons.mic_none_rounded, onTap: () => openVoice(context))),
        ]),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(children: [
            Expanded(child: Figure(label: tr('আজ নগদ'), amount: taka(cash), color: C.green, size: 18)),
            Expanded(child: Figure(label: tr('QR / বিকাশ'), amount: taka(qr), size: 18)),
            Expanded(child: Figure(label: tr('বাকিতে'), amount: taka(credit), color: credit > 0 ? C.warn : C.ink, size: 18)),
          ]),
        ),
        const SizedBox(height: 14),
        tabs,
        const SizedBox(height: 4),
      ],
      page: (when) => _page(context, brain, when, today),
    );
  }

  List<Widget> _page(BuildContext context, Brain brain, String when, DateTime today) {
    final b = brain.shop;
    if (when == 'best') {
      return [
        SectionHeading(tr('গত ৩০ দিনে বেশি বিক্রি')),
        ListCard(
          key: const Key('biz-best'),
          empty: tr('পণ্য বেছে বিক্রি করলে এখানে দেখা যাবে।'),
          rows: [
            for (final (name, qty, unit, amount) in bestSellers(b, brain.services.now()).take(15))
              ListRow(leading: LetterTile(name), title: name, subtitle: '${bnDigits(qtyText(qty))} ${tr(unit)}', trailing: Text(taka(amount), style: body(14, weight: FontWeight.w600, color: C.green))),
          ],
        ),
      ];
    }
    final list = switch (when) {
      'yesterday' => salesOn(b, today.subtract(const Duration(days: 1))),
      'week' => salesSince(b, today.subtract(const Duration(days: 6))),
      _ => salesOn(b, today),
    };
    final sum = DaySum(list);
    String part(DateTime t) => t.hour < 12 ? tr('সকাল') : (t.hour < 16 ? tr('দুপুর') : (t.hour < 18 ? tr('বিকাল') : (t.hour < 20 ? tr('সন্ধ্যা') : tr('রাত'))));
    final groups = <String, List<Sale>>{};
    for (final s in list) {
      final k = when == 'week' ? (sameDay(s.at, today) ? tr('আজ') : '${weekdayName(s.at)}, ${shortDate(s.at)}') : part(s.at);
      groups.putIfAbsent(k, () => []).add(s);
    }
    return [
      SectionHeading(when == 'today' ? tr('আজকের বিক্রি') : (when == 'yesterday' ? tr('গতকালের বিক্রি') : tr('এই সপ্তাহের বিক্রি')), counter: trf('{0}টি · {1}', [bnDigits(sum.count), taka(sum.total)])),
      if (list.isEmpty)
        ListCard(rows: const [], empty: tr('এখনো কোনো বিক্রি নেই। ওপরের “নতুন বিক্রি” চাপুন।'))
      else
        for (final MapEntry(key: g, value: ss) in groups.entries) ...[
          Padding(padding: const EdgeInsets.fromLTRB(4, 6, 4, 6), child: Text(g, style: body(12.5, weight: FontWeight.w600, color: C.muted))),
          ListCard(rows: [for (final s in ss) saleRow(context, s)]),
        ],
      if (list.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Text(tr('রসিদ দেখতে, PDF বা হোয়াটসঅ্যাপে পাঠাতে বিক্রিতে চাপুন।'), textAlign: TextAlign.center, style: body(12, color: C.muted))),
    ];
  }
}

/// One sale as a row: who or what, when and how paid, the amount.
Widget saleRow(BuildContext context, Sale s) {
  final what = s.amountOnly > 0 ? tr('শুধু টাকা') : s.lines.map((l) => l.name).join(', ');
  final title = s.customer.isNotEmpty ? '${s.customer} · $what' : what;
  return ListRow(
    key: Key('biz-sale-${s.id}'),
    leading: DateBlock(top: bnTime(s.at.hour, s.at.minute).split(' ').last, bottom: '#${bnDigits(s.no)}'),
    title: title,
    subtitle: [s.pay.label, if (s.lines.isNotEmpty) trf('{0}টি পণ্য', [bnDigits(s.lines.length)])].join(' · '),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      if (s.pay == SalePay.credit) ...[const WarnChip('বাকি'), const SizedBox(width: 6)],
      Text(taka(s.total), style: body(14.5, weight: FontWeight.w600, color: C.green)),
    ]),
    onTap: () => showReceipt(context, s),
  );
}

/// The receipt sheet: the lines, a PDF with the shop's name and logo, send
/// it, or take the sale back.
Future<void> showReceipt(BuildContext context, Sale s) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final brain = BrainScope.read(ctx);
        final text = receiptText(s, taka, bnDigits, profile: brain.shop.profile);
        final c = s.customerId.isEmpty ? null : customerById(brain.shop, s.customerId);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(trf('রসিদ #{0}', [bnDigits(s.no)]), style: display(19, weight: 600))),
              if (c != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    pushPage(context, CustomerPage(id: c.id));
                  },
                  child: Text(c.name, style: body(13.5, color: C.green, weight: FontWeight.w600)),
                ),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12)),
              child: Text(text, key: const Key('biz-receipt-text'), style: body(13.5, height: 1.6)),
            ),
            const SizedBox(height: 12),
            PrimaryButton(key: const Key('biz-receipt-pdf'), label: tr('PDF রসিদ'), icon: Icons.picture_as_pdf_outlined, height: 46, onPressed: () => showReceiptPdf(ctx, s)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: SmallButton(label: tr('লেখা শেয়ার'), icon: Icons.share_outlined, onTap: () => brain.services.files.shareText(text))),
              const SizedBox(width: 8),
              Expanded(child: SmallButton(key: const Key('biz-receipt-wa'), label: tr('হোয়াটসঅ্যাপে'), icon: Icons.chat_outlined, onTap: () => brain.services.launcher.open(Via.whatsapp, c?.whatsappNumber ?? '', text: text))),
            ]),
            TextButton(
              key: const Key('biz-sale-delete'),
              onPressed: () async {
                if (!await bizCan(ctx) || !ctx.mounted) return;
                final ok = await confirmDialog(ctx, title: tr('বিক্রিটা বাতিল করবেন?'), text: tr('পণ্য স্টকে ফিরবে, টাকা বা বাকির হিসাবও মুছে যাবে।'), yes: tr('বাতিল করুন'), danger: true);
                if (!ok) return;
                await brain.deleteSale(s.id);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(tr('বিক্রি বাতিল'), style: body(14, color: C.red)),
            ),
          ]),
        );
      },
    );

/// নতুন বিক্রি: search or pick products, quantities (weights for loose
/// ones), the buyer, the payment, and the receipt.
class SellPage extends StatefulWidget {
  const SellPage({super.key, this.amountOnly = false, this.customerId = ''});
  final bool amountOnly;
  final String customerId;
  @override
  State<SellPage> createState() => _SellPageState();
}

class _SellPageState extends State<SellPage> {
  final _find = TextEditingController();
  final _amount = TextEditingController();
  final _discount = TextEditingController();
  final _cart = <String, double>{}; // product id → quantity
  String _shelf = '';
  late String _customerId = widget.customerId;
  late SalePay _pay = widget.customerId.isEmpty ? SalePay.cash : SalePay.credit;

  /// The discount typed as taka or as percent (owner, 6 Nov: "ছাড়, টাকাতেও
  /// দিতে পারবে, পারসেন্ট এ। সেটা অটো লাইভ ক্যালকুলেট হবে।").
  bool _pct = false;

  @override
  void dispose() {
    _find.dispose();
    _amount.dispose();
    _discount.dispose();
    super.dispose();
  }

  Product? _p(String id) => BrainScope.read(context).shop.products.where((p) => p.id == id).firstOrNull;

  void _add(Product p, [double by = 1]) => setState(() {
        final q = (_cart[p.id] ?? 0) + by;
        if (q <= 0) {
          _cart.remove(p.id);
        } else {
          _cart[p.id] = q;
        }
      });

  Future<void> _weigh(Product p) async {
    final v = await askText(context, trf('{0} — কত {1}?', [p.name, tr(p.unit)]), initial: _cart[p.id] == null ? '' : qtyText(_cart[p.id]!), hint: tr('যেমন ১.২৫০'));
    final n = v == null ? null : readNum(v);
    if (n == null) return;
    setState(() => n <= 0 ? _cart.remove(p.id) : _cart[p.id] = n);
  }

  List<SaleLine> get _lines => [
        for (final MapEntry(key: id, value: q) in _cart.entries)
          if (_p(id) case final p?) SaleLine(productId: p.id, name: p.name, qty: q, unit: p.unit, amount: p.priceOf(q), cost: (p.buy * q).round()),
      ];

  int get _subtotal => _lines.fold<int>(0, (s, l) => s + l.amount);

  /// The discount in taka, worked out live from what is typed.
  int get _off {
    final v = readNum(_discount.text) ?? 0;
    if (v <= 0) return 0;
    final off = _pct ? (_subtotal * v.clamp(0, 100) / 100).round() : v.round();
    return off.clamp(0, _subtotal);
  }

  int get _total => widget.amountOnly ? (readNum(_amount.text) ?? 0).round() : (_subtotal - _off).clamp(0, 1 << 40);

  Future<void> _pickCustomer() async {
    final c = await pickCustomer(context);
    if (c != null && mounted) setState(() => _customerId = c.id);
  }

  Future<void> _done() async {
    final brain = BrainScope.read(context);
    if (_total <= 0) return toast(context, widget.amountOnly ? tr('কত টাকার বিক্রি, লিখুন') : tr('কোনো পণ্য বাছা হয়নি'));
    if (!await bizCan(context) || !mounted) return;
    if (_pay == SalePay.credit && _customerId.isEmpty) {
      toast(context, tr('বাকিতে বিক্রির জন্য গ্রাহক বাছুন'));
      await _pickCustomer();
      if (_customerId.isEmpty || !mounted) return;
    }
    final c = customerById(brain.shop, _customerId);
    if (_pay == SalePay.credit && c != null && c.limit > 0) {
      final after = customerAccount(brain.shop, c).due + _total;
      if (after > c.limit) {
        final ok = await confirmDialog(context, title: tr('বাকির সীমা পার হবে'), text: trf('{0}-এর সীমা {1}, এই বিক্রিতে বাকি হবে {2}। তবুও বাকিতে দেবেন?', [c.name, taka(c.limit), taka(after)]), yes: tr('হ্যাঁ, দিন'));
        if (!ok || !mounted) return;
      }
    }
    final pct = _pct ? (readNum(_discount.text) ?? 0).clamp(0, 100).toDouble() : 0.0;
    final s = await brain.recordSale(Sale(
      at: brain.services.now(),
      lines: widget.amountOnly ? const [] : _lines,
      discount: widget.amountOnly ? 0 : _off,
      discountPct: widget.amountOnly || _off == 0 ? 0 : pct,
      amountOnly: widget.amountOnly ? _total : 0,
      pay: _pay,
      customerId: c?.id ?? '',
      customer: c?.name ?? '',
    ));
    if (!mounted) return;
    Navigator.of(context).pop();
    toast(context, trf('বিক্রি রাখা হয়েছে · {0}', [taka(s.total)]));
  }

  /// Two steps (owner, 7 Nov: the sell page was not easy to use): first the
  /// products — big cards, one tap adds one; then the checkout — the cart,
  /// the customer, the discount, how it is paid.
  bool _checkout = false;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    if (widget.amountOnly) return _scaffold(context, tr('শুধু টাকার বিক্রি'), _checkoutBody(context, brain), _payFoot(context, brain));
    if (_checkout) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _checkout = false);
        },
        child: _scaffold(context, tr('টাকা নিন'), _checkoutBody(context, brain), _payFoot(context, brain), back: () => setState(() => _checkout = false)),
      );
    }
    final q = _find.text.trim().toLowerCase();
    final best = bestSellers(b, brain.services.now()).map((x) => x.$1).toList();
    final shelfNames = shelves(b.products).map((x) => x.$1).toList();
    var shown = b.products.where((p) => q.isEmpty || p.name.toLowerCase().contains(q) || (p.barcode.isNotEmpty && p.barcode == asciiDigits(q))).toList();
    if (_shelf.isNotEmpty) shown = shown.where((p) => sectionOf(p) == _shelf).toList();
    int rank(Product p) {
      final i = best.indexOf(p.name);
      return i < 0 ? 999 : i;
    }

    if (q.isEmpty && _shelf.isEmpty) shown.sort((a, c) => rank(a).compareTo(rank(c)));
    final count = _cart.length;

    final page = ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
      TextField(
        key: const Key('biz-sell-find'),
        controller: _find,
        onChanged: (_) => setState(() {}),
        style: body(15),
        decoration: InputDecoration(hintText: tr('পণ্যের নাম বা বারকোড লিখুন'), prefixIcon: const Icon(Icons.search_rounded), isDense: true),
      ),
      if (shelfNames.length > 1) ...[
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final s in ['', ...shelfNames])
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  avatar: s.isEmpty ? null : Icon(sectionIcon(s), size: 16, color: _shelf == s ? C.green : C.muted),
                  showCheckmark: false,
                  label: Text(s.isEmpty ? tr('সব') : tr(s)),
                  selected: _shelf == s,
                  onSelected: (_) => setState(() => _shelf = s),
                ),
              ),
          ]),
        ),
      ],
      const SizedBox(height: 12),
      if (b.products.isEmpty)
        ListCard(rows: const [], empty: tr('স্টকে কোনো পণ্য নেই। “শুধু টাকা লিখে” বিক্রি রাখা যায়, বা স্টক থেকে পণ্য যোগ করুন।'))
      else if (shown.isEmpty)
        Padding(padding: const EdgeInsets.all(12), child: Text(tr('মেলেনি।'), style: body(14, color: C.muted)))
      else
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.55,
          children: [for (final p in shown.take(60)) _card(p)],
        ),
      const SizedBox(height: 8),
      Text(tr('চাপ দিলে একটা যোগ হয় · চেপে ধরলে পরিমাণ লিখুন'), textAlign: TextAlign.center, style: body(12, color: C.muted)),
    ]);

    final foot = PageFoot(
      child: Row(children: [
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(count == 0 ? tr('কিছু বাছা হয়নি') : trf('{0}টি পণ্য', [bnDigits(count)]), style: body(12.5, color: C.muted)),
            Text(taka(_subtotal), key: const Key('biz-sell-subtotal'), style: display(24, weight: 600)),
          ]),
        ),
        SizedBox(
          width: 170,
          child: PrimaryButton(
            key: const Key('biz-sell-next'),
            label: tr('এগিয়ে যান'),
            icon: Icons.arrow_forward_rounded,
            onPressed: () => count == 0 ? toast(context, tr('কোনো পণ্য বাছা হয়নি')) : setState(() => _checkout = true),
          ),
        ),
      ]),
    );
    return _scaffold(context, tr('নতুন বিক্রি'), page, foot);
  }

  Widget _scaffold(BuildContext context, String title, Widget body, Widget foot, {VoidCallback? back}) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            back == null
                ? InnerTop(title: title, actions: [IconButton(tooltip: tr('মুখে বলে বিক্রি'), onPressed: () => openVoice(context), icon: const Icon(Icons.mic_none_rounded))])
                : Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 8, 4),
                    child: Row(children: [
                      IconButton(key: const Key('biz-sell-back'), tooltip: tr('পণ্যে ফিরে যান'), onPressed: back, icon: const Icon(Icons.chevron_left_rounded, size: 28)),
                      Expanded(child: Text(title, style: display(21, weight: 600))),
                    ]),
                  ),
            Expanded(child: body),
            foot,
          ]),
        ),
      );

  /// A product card: tap adds one (loose goods ask the weight), hold to type the amount.
  Widget _card(Product p) {
    final inCart = _cart[p.id];
    final on = inCart != null;
    return Material(
      color: on ? C.greenTint : C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: on ? C.green : C.border, width: on ? 1.6 : 1)),
      child: InkWell(
        key: Key(p.loose ? 'biz-weigh-${p.id}' : 'biz-plus-${p.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => p.loose ? _weigh(p) : _add(p),
        onLongPress: () => _weigh(p),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              LetterTile(p.name, size: 32),
              const Spacer(),
              if (on) ...[
                InkWell(
                  key: Key('biz-minus-${p.id}'),
                  customBorder: const CircleBorder(),
                  onTap: () => p.loose ? setState(() => _cart.remove(p.id)) : _add(p, -1),
                  child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.remove_circle_outline_rounded, color: C.green, size: 22)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(10)),
                  child: Text('${bnDigits(qtyText(inCart))} ${tr(p.unit)}', style: body(12, weight: FontWeight.w700, color: C.onAccent)),
                ),
              ] else
                Icon(p.loose ? Icons.scale_outlined : Icons.add_circle_outline_rounded, color: C.muted, size: 22),
            ]),
            const Spacer(),
            Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, weight: FontWeight.w600)),
            Text(trf('{0} / {1}', [taka(p.sell), tr(p.unit)]) + (p.stock <= 0 ? ' · ${tr('স্টক নেই')}' : ''), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: p.stock <= 0 ? C.warn : C.muted)),
          ]),
        ),
      ),
    );
  }

  /// The checkout: the cart (or the amount), the customer, the discount.
  Widget _checkoutBody(BuildContext context, Brain brain) {
    final b = brain.shop;
    final customer = _customerId.isEmpty ? null : customerById(b, _customerId);
    final owe = customer == null ? 0 : customerAccount(b, customer).due;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), children: [
      if (widget.amountOnly)
        NumField(controller: _amount, label: tr('কত টাকার বিক্রি'), hint: '৳', fieldKey: const Key('biz-sell-amount-field'), onChanged: (_) => setState(() {}))
      else ...[
        SectionHeading(tr('কার্ট'), counter: trf('{0}টি পণ্য', [bnDigits(_cart.length)]), link: tr('+ আরও পণ্য'), onLink: () => setState(() => _checkout = false)),
        ListCard(rows: [
          for (final l in _lines)
            ListRow(
              leading: LetterTile(l.name, size: 36),
              title: l.name,
              subtitle: '${bnDigits(qtyText(l.qty))} ${tr(l.unit)}',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(taka(l.amount), style: body(14, weight: FontWeight.w600)),
                IconButton(tooltip: tr('বাদ দিন'), onPressed: () => setState(() => _cart.remove(l.productId)), icon: Icon(Icons.close_rounded, size: 18, color: C.muted)),
              ]),
              onTap: () {
                final p = _p(l.productId!);
                if (p != null) _weigh(p);
              },
            ),
        ]),
      ],
      SectionHeading(tr('গ্রাহক')),
      OutlinedButton(
        key: const Key('biz-sell-customer'),
        onPressed: _pickCustomer,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48), alignment: Alignment.centerLeft),
        child: Row(children: [
          const Icon(Icons.person_outline_rounded, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: customer == null ? (_pay == SalePay.credit ? tr('গ্রাহক বাছুন (বাকির জন্য দরকার)') : tr('গ্রাহক (ঐচ্ছিক)')) : customer.name, style: body(14, color: customer == null && _pay == SalePay.credit ? C.warn : C.ink)),
                if (owe > 0) TextSpan(text: ' · ${trf('আগের বাকি {0}', [taka(owe)])}', style: body(13, color: C.warn)),
              ]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(customer == null ? tr('বাছুন') : tr('বদলান'), style: body(13, weight: FontWeight.w600, color: C.green)),
        ]),
      ),
      if (!widget.amountOnly) ...[
        SectionHeading(tr('ছাড়')),
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('biz-sell-discount'),
              controller: _discount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              style: body(15),
              decoration: InputDecoration(isDense: true, hintText: _pct ? tr('কত শতাংশ') : tr('কত টাকা')),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 120, child: SegTabs<bool>(key: const Key('biz-sell-discount-kind'), items: const [(false, '৳'), (true, '%')], value: _pct, onChanged: (v) => setState(() => _pct = v))),
        ]),
        if (_off > 0) Padding(padding: const EdgeInsets.only(top: 6), child: Text('− ${taka(_off)}', key: const Key('biz-sell-off'), style: body(13.5, color: C.green, weight: FontWeight.w600))),
      ],
      SectionHeading(tr('টাকা কীভাবে')),
      SegTabs<SalePay>(key: const Key('biz-sell-pay'), items: [for (final p in SalePay.values) (p, tr(p.label))], value: _pay, onChanged: (v) => setState(() => _pay = v)),
    ]);
  }

  Widget _payFoot(BuildContext context, Brain brain) => PageFoot(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(_off > 0 ? trf('মোট ({0} থেকে)', [taka(_subtotal)]) : tr('মোট'), style: body(14, color: C.muted))),
            Text(taka(_total), key: const Key('biz-sell-total'), style: display(27, weight: 600)),
          ]),
          const SizedBox(height: 10),
          PrimaryButton(key: const Key('biz-sell-done'), label: tr('বিক্রি সম্পন্ন'), icon: Icons.check_rounded, onPressed: _done),
        ]),
      );
}
