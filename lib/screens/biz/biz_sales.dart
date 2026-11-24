import 'package:flutter/material.dart';

import '../../logic/biz_account.dart' show memoDue;
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
import 'biz_returns.dart' show ReturnsPage;
import 'biz_shop.dart' show showReceiptPdf;

/// বিক্রি (business mode tab; My Assistant's "দিনলিপি" in its place).
class BizSales extends StatefulWidget {
  const BizSales({super.key});
  @override
  State<BizSales> createState() => _BizSalesState();
}

class _BizSalesState extends State<BizSales> {
  // Owner, 23 Nov: "বিক্রি মেনুতে, আজ মাসিক, বার্ষিক তারিখ এভাবে ফিল্টার হবে".
  String _when = 'today';
  DateTime? _month; // first day of the month shown under মাসিক
  int? _year;
  DateTime? _day; // the day picked under তারিখ

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
    return BizRefresh(child: Stack(children: [
      TabPages<String>(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      items: [('today', tr('আজ')), ('month', tr('মাসিক')), ('year', tr('বার্ষিক')), ('date', tr('তারিখ'))],
      value: _when,
      onChanged: (v) {
        setState(() => _when = v);
        if (v == 'date' && _day == null) _pickDay(context, today);
      },
      top: (tabs) => [
        TabTitle(trm('বিক্রি'), sub: trf('আজ {0}টি বিক্রি · {1}', [bnDigits(todaySum.count), taka(todaySum.total)])),
        const BizFreeBanner(),
        const SizedBox(height: 12),
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
    ),
      Positioned(right: 16, bottom: 16, child: AddButton(key: const Key('biz-sell-fab'), label: tr('নতুন বিক্রি'), icon: Icons.add_shopping_cart_rounded, onPressed: () => pushPage(context, const SellPage()))),
    ]));
  }

  bool _picking = false;
  Future<void> _pickDay(BuildContext context, DateTime today) async {
    if (_picking) return; // the tab tap and the page settling both report the change
    _picking = true;
    final d = await showDatePicker(context: context, initialDate: _day ?? today, firstDate: DateTime(2000), lastDate: today);
    _picking = false;
    if (mounted) setState(() => _day = d ?? _day ?? today);
  }

  /// "‹ label ›": step back or forward through months, years or days.
  Widget _stepper(String key, String label, {required VoidCallback onBack, VoidCallback? onNext, VoidCallback? onLabel}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          IconButton(key: Key('$key-back'), tooltip: tr('আগের'), onPressed: onBack, icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
            child: InkWell(
              key: Key('$key-label'),
              borderRadius: BorderRadius.circular(12),
              onTap: onLabel,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (onLabel != null) ...[Icon(Icons.calendar_month_outlined, size: 18, color: C.green), const SizedBox(width: 6)],
                  Text(label, style: body(15.5, weight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
          IconButton(key: Key('$key-next'), tooltip: tr('পরের'), onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
        ]),
      );

  List<Widget> _best(List<Sale> list, String title) {
    final by = <String, (String, double, String, int)>{};
    for (final s in list) {
      for (final l in s.lines) {
        final k = l.productId ?? l.name;
        final was = by[k];
        by[k] = (l.name, (was?.$2 ?? 0) + l.qty, l.unit, (was?.$4 ?? 0) + l.amount);
      }
    }
    final best = by.values.toList()..sort((a, b) => b.$4.compareTo(a.$4));
    if (best.isEmpty) return const [];
    return [
      SectionHeading(title),
      ListCard(
        key: const Key('biz-best'),
        rows: [
          for (final (name, qty, unit, amount) in best.take(10))
            ListRow(leading: LetterTile(name), title: name, subtitle: '${bnDigits(qtyText(qty))} ${tr(unit)}', trailing: Text(taka(amount), style: body(14, weight: FontWeight.w600, color: C.green))),
        ],
      ),
    ];
  }

  List<Widget> _page(BuildContext context, Brain brain, String when, DateTime today) {
    final b = brain.shop;
    String part(DateTime t) => t.hour < 12 ? tr('সকাল') : (t.hour < 16 ? tr('দুপুর') : (t.hour < 18 ? tr('বিকাল') : (t.hour < 20 ? tr('সন্ধ্যা') : tr('রাত'))));
    String dayLabel(DateTime d) => sameDay(d, today) ? tr('আজ') : '${weekdayName(d)}, ${shortDate(d)}';
    final tail = [Padding(padding: const EdgeInsets.only(top: 10), child: Text(tr('রসিদ দেখতে, PDF বা হোয়াটসঅ্যাপে পাঠাতে বিক্রিতে চাপুন।'), textAlign: TextAlign.center, style: body(12, color: C.muted)))];

    List<Widget> grouped(String heading, List<Sale> list, String Function(Sale) key) {
      final sum = DaySum(list);
      final groups = <String, List<Sale>>{};
      for (final s in list) {
        groups.putIfAbsent(key(s), () => []).add(s);
      }
      return [
        SectionHeading(heading, counter: trf('{0}টি · {1}', [bnDigits(sum.count), taka(sum.total)])),
        if (list.isEmpty)
          ListCard(rows: const [], empty: tr('এই সময়ে কোনো বিক্রি নেই।'))
        else
          for (final MapEntry(key: g, value: ss) in groups.entries) ...[
            Padding(padding: const EdgeInsets.fromLTRB(4, 6, 4, 6), child: Text(g, style: body(12.5, weight: FontWeight.w600, color: C.muted))),
            ListCard(rows: [for (final s in ss) saleRow(context, s)]),
          ],
      ];
    }

    switch (when) {
      case 'month':
        final m = _month ?? DateTime(today.year, today.month);
        final next = DateTime(m.year, m.month + 1);
        final list = [for (final s in b.sales) if (!s.at.isBefore(m) && s.at.isBefore(next)) s]..sort((x, y) => y.at.compareTo(x.at));
        final label = '${monthName(m.month)} ${bnDigits(m.year)}';
        return [
          _stepper('biz-sales-month', label,
              onBack: () => setState(() => _month = DateTime(m.year, m.month - 1)),
              onNext: next.isAfter(today) ? null : () => setState(() => _month = next)),
          ...grouped(trf('{0}-এর বিক্রি', [label]), list, (s) => dayLabel(s.at)),
          ..._best(list, tr('এ মাসে বেশি বিক্রি')),
          if (list.isNotEmpty) ...tail,
        ];
      case 'year':
        final y = _year ?? today.year;
        final list = [for (final s in b.sales) if (s.at.year == y) s];
        final sum = DaySum(list);
        final months = <int, List<Sale>>{};
        for (final s in list) {
          months.putIfAbsent(s.at.month, () => []).add(s);
        }
        final keys = months.keys.toList()..sort((a, b) => b.compareTo(a));
        return [
          _stepper('biz-sales-year', bnDigits(y), onBack: () => setState(() => _year = y - 1), onNext: y >= today.year ? null : () => setState(() => _year = y + 1)),
          SectionHeading(trf('{0} সালের বিক্রি', [bnDigits(y)]), counter: trf('{0}টি · {1}', [bnDigits(sum.count), taka(sum.total)])),
          ListCard(
            key: const Key('biz-sales-months'),
            empty: tr('এই সময়ে কোনো বিক্রি নেই।'),
            rows: [
              for (final mo in keys)
                ListRow(
                  key: Key('biz-sales-m-$mo'),
                  leading: DateBlock(top: monthShort(mo), bottom: bnDigits(y)),
                  title: monthName(mo),
                  subtitle: [trf('{0}টি বিক্রি', [bnDigits(months[mo]!.length)]), if (DaySum(months[mo]!).by(SalePay.credit) > 0) trf('বাকিতে {0}', [taka(DaySum(months[mo]!).by(SalePay.credit))])].join(' · '),
                  trailing: Text(taka(DaySum(months[mo]!).total), style: body(14.5, weight: FontWeight.w600, color: C.green)),
                  onTap: () => setState(() {
                    _month = DateTime(y, mo);
                    _when = 'month';
                  }),
                ),
            ],
          ),
          ..._best(list, trf('{0} সালে বেশি বিক্রি', [bnDigits(y)])),
        ];
      case 'date':
        final d = _day ?? today;
        final list = salesOn(b, d);
        return [
          _stepper('biz-sales-day', dayLabel(d),
              onBack: () => setState(() => _day = d.subtract(const Duration(days: 1))),
              onNext: sameDay(d, today) ? null : () => setState(() => _day = d.add(const Duration(days: 1))),
              onLabel: () => _pickDay(context, today)),
          ...grouped(trf('{0}-এর বিক্রি', [shortDate(d)]), list, (s) => part(s.at)),
          if (list.isNotEmpty) ...tail,
        ];
      default:
        final list = salesOn(b, today);
        return [
          ...grouped(tr('আজকের বিক্রি'), list, (s) => part(s.at)),
          if (list.isEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr('এখনো কোনো বিক্রি নেই। নিচের “নতুন বিক্রি” চাপুন।'), textAlign: TextAlign.center, style: body(12.5, color: C.muted))),
          if (list.isNotEmpty) ...tail,
        ];
    }
  }
}

/// One sale as a row: who or what, when and how paid, the amount.
Widget saleRow(BuildContext context, Sale s) {
  final what = s.amountOnly > 0 ? tr('শুধু টাকা') : s.lines.map((l) => l.name).join(', ');
  final title = s.customer.isNotEmpty ? '${s.customer} · $what' : what;
  return ListRow(
    key: Key('biz-sale-${s.id}'),
    leading: DateBlock(top: bnTime(s.at.hour, s.at.minute).split(' ').firstWhere((w) => w.contains(RegExp(r'[0-9০-৯]')), orElse: () => ''), bottom: '#${bnDigits(s.no)}'),
    title: title,
    subtitle: [tr(s.pay.label), if (s.lines.isNotEmpty) trf('{0}টি পণ্য', [bnDigits(s.lines.length)])].join(' · '),
    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
      if (s.pay == SalePay.credit) ...[WarnChip(tr('বাকি')), const SizedBox(width: 6)],
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
        final d = memoDue(brain.shop, s);
        final base = receiptText(s, taka, bnDigits, profile: brain.shop.profile).split('\n');
        final from = [if (d.opening) tr('শুরুর বকেয়া'), if (d.memos.isNotEmpty) '${tr('মেমো')} ${d.memos.map((n) => '#${bnDigits(n)}').join(', ')}'].join(' + ');
        final text = [
          ...base.take(base.length - 1),
          if (s.customerId.isNotEmpty && (d.before > 0 || d.now > 0)) ...[
            '',
            from.isEmpty ? trf('আগের বকেয়া: {0}', [taka(d.before)]) : trf('আগের বকেয়া ({0}): {1}', [from, taka(d.before)]),
            trf('এই মেমোর বাকি: {0}', [taka(d.now)]),
            trf('মোট বকেয়া: {0}', [taka(d.after)]),
            '',
          ],
          base.last,
        ].join('\n');
        final c = s.customerId.isEmpty ? null : customerById(brain.shop, s.customerId);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(trf('মেমো #{0}', [bnDigits(s.no)]), style: display(19, weight: 600))),
              if (c != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    pushPage(context, CustomerPage(id: c.id));
                  },
                  child: Text(c.name, style: body(13.5, color: C.green, weight: FontWeight.w600)),
                ),
              IconButton(key: const Key('biz-receipt-close'), tooltip: tr('বন্ধ করুন'), icon: Icon(Icons.close_rounded, color: C.ink), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12)),
              child: Text(text, key: const Key('biz-receipt-text'), style: body(13.5, height: 1.6)),
            ),
            const SizedBox(height: 12),
            PrimaryButton(key: const Key('biz-receipt-pdf'), label: tr('PDF মেমো'), icon: Icons.picture_as_pdf_outlined, height: 46, onPressed: () => showReceiptPdf(ctx, s)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: SmallButton(label: tr('লেখা শেয়ার'), icon: Icons.share_outlined, onTap: () => brain.services.files.shareText(text))),
              const SizedBox(width: 8),
              Expanded(child: SmallButton(key: const Key('biz-receipt-wa'), label: tr('হোয়াটসঅ্যাপে'), icon: Icons.chat_outlined, onTap: () => brain.services.launcher.open(Via.whatsapp, c?.whatsappNumber ?? '', text: text))),
            ]),
            if (s.lines.isNotEmpty)
              TextButton(
                key: const Key('biz-sale-return'),
                onPressed: () {
                  Navigator.pop(ctx);
                  pushPage(context, ReturnsPage(saleId: s.id));
                },
                child: Text(tr('মাল ফেরত নিন'), style: body(14, color: C.green, weight: FontWeight.w600)),
              ),
            TextButton(
              key: const Key('biz-sale-delete'),
              onPressed: () async {
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

/// নতুন বিক্রি (owner, 23 Nov): one page — the customer (with what they
/// already owe and their last memo), the products by live search with + and
/// − for how many, the discount in ৳ or %, how it is paid (cash, bKash/QR,
/// part, on credit) and the memo.
class SellPage extends StatefulWidget {
  const SellPage({super.key, this.amountOnly = false, this.customerId = ''});
  final bool amountOnly;
  final String customerId;
  @override
  State<SellPage> createState() => _SellPageState();
}

enum _Pay { cash, qr, part, credit }

class _SellPageState extends State<SellPage> {
  final _find = TextEditingController();
  final _amount = TextEditingController();
  final _discount = TextEditingController();
  final _paid = TextEditingController();
  final _cart = <String, double>{}; // product id → quantity, in the order picked
  late String _customerId = widget.customerId;
  late _Pay _pay = widget.customerId.isEmpty ? _Pay.cash : _Pay.credit;
  bool _busy = false;

  /// The discount typed as taka or as percent (owner, 6 Nov: "ছাড়, টাকাতেও
  /// দিতে পারবে, পারসেন্ট এ। সেটা অটো লাইভ ক্যালকুলেট হবে।").
  bool _pct = false;

  @override
  void dispose() {
    for (final c in [_find, _amount, _discount, _paid]) {
      c.dispose();
    }
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

  int get _paidNow => switch (_pay) {
        _Pay.cash || _Pay.qr => _total,
        _Pay.credit => 0,
        _Pay.part => ((readNum(_paid.text) ?? 0).round()).clamp(0, _total),
      };

  Future<void> _pickCustomer() async {
    final c = await pickCustomer(context);
    if (c != null && mounted) setState(() => _customerId = c.id);
  }

  Future<void> _done() async {
    if (_busy) return;
    final brain = BrainScope.read(context);
    if (_total <= 0) return toast(context, widget.amountOnly ? tr('কত টাকার বিক্রি, লিখুন') : tr('কোনো পণ্য বাছা হয়নি'));
    final owes = _total - _paidNow;
    if (owes > 0 && _customerId.isEmpty) {
      toast(context, tr('বাকি থাকলে গ্রাহক বাছুন'));
      await _pickCustomer();
      if (_customerId.isEmpty || !mounted) return;
    }
    final c = customerById(brain.shop, _customerId);
    if (owes > 0 && c != null && c.limit > 0) {
      final after = customerAccount(brain.shop, c).due + owes;
      if (after > c.limit) {
        final ok = await confirmDialog(context, title: tr('বাকির সীমা পার হবে'), text: trf('{0}-এর সীমা {1}, এই বিক্রিতে বাকি হবে {2}। তবুও বাকিতে দেবেন?', [c.name, taka(c.limit), taka(after)]), yes: tr('হ্যাঁ, দিন'));
        if (!ok || !mounted) return;
      }
    }
    setState(() => _busy = true);
    final pct = _pct ? (readNum(_discount.text) ?? 0).clamp(0, 100).toDouble() : 0.0;
    final pay = switch (_pay) { _Pay.cash => SalePay.cash, _Pay.qr => SalePay.qr, _ => SalePay.credit };
    final s = await brain.recordSale(Sale(
      at: brain.services.now(),
      lines: widget.amountOnly ? const [] : _lines,
      discount: widget.amountOnly ? 0 : _off,
      discountPct: widget.amountOnly || _off == 0 ? 0 : pct,
      amountOnly: widget.amountOnly ? _total : 0,
      pay: pay,
      paid: pay == SalePay.credit ? _paidNow : 0,
      customerId: c?.id ?? '',
      customer: c?.name ?? '',
    ));
    if (!mounted) return;
    final nav = Navigator.of(context);
    nav.pop();
    toast(nav.context, trf('বিক্রি রাখা হয়েছে · মেমো #{0} · {1}', [bnDigits(s.no), taka(s.total)]));
    showReceipt(nav.context, s);
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final customer = _customerId.isEmpty ? null : customerById(b, _customerId);
    final before = customer == null ? 0 : customerAccount(b, customer).due;
    final lastMemo = customer == null ? null : (b.sales.where((x) => x.customerId == customer.id && x.no > 0).toList()..sort((a, x) => x.at.compareTo(a.at))).firstOrNull;
    final owes = _total - _paidNow;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          InnerTop(
            title: widget.amountOnly ? tr('শুধু টাকার বিক্রি') : tr('নতুন বিক্রি'),
            actions: [
              Padding(padding: const EdgeInsets.only(right: 4), child: Text(trf('মেমো #{0}', [bnDigits(brain.nextSaleNo)]), style: body(12.5, color: C.muted))),
              IconButton(tooltip: tr('মুখে বলে বিক্রি'), onPressed: () => openVoice(context), icon: const Icon(Icons.mic_none_rounded)),
            ],
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), children: [
              _label(tr('গ্রাহক')),
              _customerCard(customer, before, lastMemo),
              if (widget.amountOnly) ...[
                const SizedBox(height: 14),
                NumField(controller: _amount, label: tr('কত টাকার বিক্রি'), hint: '৳', fieldKey: const Key('biz-sell-amount-field'), onChanged: (_) => setState(() {})),
              ] else ...[
                const SizedBox(height: 14),
                _label(tr('পণ্য যোগ করুন')),
                ..._search(brain),
                if (_cart.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _label(trf('বাছাই করা {0}টি', [bnDigits(_cart.length)])),
                  _cartCard(),
                ],
                const SizedBox(height: 12),
                _sumCard(),
              ],
              const SizedBox(height: 14),
              _label(tr('টাকা')),
              SegTabs<_Pay>(
                key: const Key('biz-sell-pay'),
                items: [(_Pay.cash, tr('নগদ')), (_Pay.qr, tr('বিকাশ/QR')), (_Pay.part, tr('আংশিক')), (_Pay.credit, tr('বাকি'))],
                value: _pay,
                onChanged: (v) => setState(() => _pay = v),
              ),
              if (_pay == _Pay.part || (_pay == _Pay.credit && customer != null) || (before > 0 && owes == 0 && customer != null)) ...[
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (_pay == _Pay.part) ...[
                    Expanded(child: NumField(controller: _paid, fieldKey: const Key('biz-sell-paid'), label: tr('পেলাম ৳'), onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      decoration: BoxDecoration(color: C.warnBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: C.warnBorder)),
                      child: Text(trf('মোট বকেয়া {0}', [taka(before + owes)]), key: const Key('biz-sell-due-after'), style: body(14, weight: FontWeight.w700, color: C.warn)),
                    ),
                  ),
                ]),
              ],
            ]),
          ),
          PageFoot(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(_off > 0 ? trf('এই মেমো ({0} থেকে)', [taka(_subtotal)]) : tr('এই মেমো'), style: body(14, color: C.muted))),
                Text(taka(_total), key: const Key('biz-sell-total'), style: display(26, weight: 700)),
              ]),
              const SizedBox(height: 10),
              PrimaryButton(key: const Key('biz-sell-done'), label: tr('বিক্রি সেভ ও মেমো'), icon: Icons.check_rounded, onPressed: _busy ? null : _done),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _label(String s) => Padding(padding: const EdgeInsets.fromLTRB(2, 0, 2, 6), child: Text(s, style: body(12.5, color: C.muted, weight: FontWeight.w600)));

  Widget _customerCard(Customer? c, int before, Sale? lastMemo) => Material(
        color: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c == null && _pay != _Pay.cash && _pay != _Pay.qr ? C.warnBorder : C.border)),
        child: InkWell(
          key: const Key('biz-sell-customer'),
          borderRadius: BorderRadius.circular(14),
          onTap: _pickCustomer,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 14, 11),
            child: Row(children: [
              c == null ? CircleAvatar(radius: 19, backgroundColor: C.surface2, child: Icon(Icons.person_outline_rounded, color: C.muted)) : Avatar(name: c.name, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c?.name ?? tr('গ্রাহক বাছুন (ঐচ্ছিক)'), style: body(15, weight: FontWeight.w600, color: c == null ? C.muted : C.ink)),
                  if (c != null && before > 0)
                    Text([trf('আগের বকেয়া {0}', [taka(before)]), if (lastMemo != null) trf('শেষ মেমো #{0}', [bnDigits(lastMemo.no)])].join(' · '), style: body(12, color: C.warn))
                  else if (c == null && _pay != _Pay.cash && _pay != _Pay.qr)
                    Text(tr('বাকির জন্য দরকার'), style: body(12, color: C.warn)),
                ]),
              ),
              Text(c == null ? tr('বাছুন') : tr('বদলান'), style: body(13, weight: FontWeight.w600, color: C.green)),
            ]),
          ),
        ),
      );

  List<Widget> _search(Brain brain) {
    final b = brain.shop;
    final q = _find.text.trim().toLowerCase();
    final best = bestSellers(b, brain.services.now()).map((x) => x.$1).toList();
    int rank(Product p) {
      final i = best.indexOf(p.name);
      return i < 0 ? 999 : i;
    }

    final shown = [for (final p in b.products) if (q.isEmpty || p.name.toLowerCase().contains(q) || (p.barcode.isNotEmpty && p.barcode == asciiDigits(q))) p]..sort((a, x) {
        if (q.isNotEmpty) {
          final sa = a.name.toLowerCase().startsWith(q), sx = x.name.toLowerCase().startsWith(q);
          if (sa != sx) return sa ? -1 : 1;
        }
        final r = rank(a).compareTo(rank(x));
        return r != 0 ? r : a.name.compareTo(x.name);
      });
    return [
      TextField(textCapitalization: TextCapitalization.sentences, 
        key: const Key('biz-sell-find'),
        controller: _find,
        onChanged: (_) => setState(() {}),
        style: body(15),
        decoration: InputDecoration(hintText: tr('পণ্যের নাম বা বারকোড লিখুন'), prefixIcon: const Icon(Icons.search_rounded), isDense: true),
      ),
      const SizedBox(height: 8),
      if (b.products.isEmpty)
        Padding(padding: const EdgeInsets.all(8), child: Text(tr('স্টকে কোনো পণ্য নেই। “শুধু টাকা লিখে” বিক্রি রাখা যায়, বা স্টক যোগ করুন।'), style: body(13.5, color: C.muted)))
      else if (shown.isEmpty)
        Padding(padding: const EdgeInsets.all(8), child: Text(tr('মেলেনি।'), style: body(14, color: C.muted)))
      else
        Container(
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final (i, p) in shown.take(q.isEmpty ? 5 : 8).indexed) ...[
              if (i > 0) Divider(height: 1, color: C.border, indent: 14, endIndent: 14),
              InkWell(
                key: Key(p.loose ? 'biz-weigh-${p.id}' : 'biz-plus-${p.id}'),
                onTap: () => p.loose ? _weigh(p) : _add(p),
                onLongPress: () => _weigh(p),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: body(14.5, weight: FontWeight.w600)),
                        Text(
                          trf('{0} / {1} · আছে {2} {1}', [taka(p.sell), tr(p.unit), bnDigits(qtyText(p.stock))]),
                          style: body(12, color: p.stock <= 0 ? C.red : C.muted),
                        ),
                      ]),
                    ),
                    Icon(p.loose ? Icons.scale_outlined : Icons.add_rounded, color: C.green, size: 24),
                  ]),
                ),
              ),
            ],
          ]),
        ),
    ];
  }

  Widget _cartCard() => Container(
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
        child: Column(children: [
          for (final (i, l) in _lines.indexed) ...[
            if (i > 0) Divider(height: 1, color: C.border, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w600)),
                    Text(trf('{0} / {1}', [taka(_p(l.productId!)?.sell ?? 0), tr(l.unit)]), style: body(11.5, color: C.muted)),
                  ]),
                ),
                Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: C.border)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    InkWell(key: Key('biz-dec-${l.productId}'), onTap: () => _add(_p(l.productId!)!, -1), child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.remove_rounded, size: 18, color: C.green))),
                    InkWell(
                      key: Key('biz-qty-${l.productId}'),
                      onTap: () => _weigh(_p(l.productId!)!),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 44),
                        child: Text('${bnDigits(qtyText(l.qty))} ${tr(l.unit)}', textAlign: TextAlign.center, style: body(13, weight: FontWeight.w600)),
                      ),
                    ),
                    InkWell(key: Key('biz-inc-${l.productId}'), onTap: () => _add(_p(l.productId!)!), child: Padding(padding: const EdgeInsets.all(6), child: Icon(Icons.add_rounded, size: 18, color: C.green))),
                  ]),
                ),
                const SizedBox(width: 10),
                SizedBox(width: 64, child: Text(taka(l.amount), textAlign: TextAlign.right, style: body(14, weight: FontWeight.w700))),
              ]),
            ),
          ],
        ]),
      );

  Widget _sumCard() => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.border)),
        child: Column(children: [
          Row(children: [
            Expanded(child: Text(tr('মোট'), style: body(14, color: C.muted))),
            Text(taka(_subtotal), key: const Key('biz-sell-subtotal'), style: body(15, weight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Text(tr('ছাড়'), style: body(14, color: C.muted)),
            const SizedBox(width: 12),
            SizedBox(width: 96, child: SegTabs<bool>(key: const Key('biz-sell-discount-kind'), items: const [(false, '৳'), (true, '%')], value: _pct, onChanged: (v) => setState(() => _pct = v))),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                key: const Key('biz-sell-discount'),
                controller: _discount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                style: body(15),
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(width: 64, child: Text(_off > 0 ? '− ${taka(_off)}' : '', key: const Key('biz-sell-off'), textAlign: TextAlign.right, style: body(13.5, color: C.green, weight: FontWeight.w700))),
          ]),
        ]),
      );
}
