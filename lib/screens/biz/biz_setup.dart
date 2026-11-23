import 'package:flutter/material.dart';

import '../../logic/biz_account.dart';
import '../../logic/bn.dart';
import '../../logic/lang.dart';
import '../../logic/shop_logic.dart';
import '../../models/models.dart';
import '../../state/brain.dart';
import '../../ui/kit.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'biz_parts.dart';

/// ব্যবসার শুরুর হিসাব (owner, 23 Nov): asked the first time ব্যবসায়ী মোড
/// opens. Is the business new or already running? Running: the cash, the
/// goods on the shelf, who owes and whom the shop owes. New: what it starts
/// with. Any step can be left out. The capital is never typed (owner, 23
/// Nov: typed, it would show a false profit or loss) — it is worked out and
/// shown to be checked.
class BizSetupPage extends StatefulWidget {
  const BizSetupPage({super.key});
  @override
  State<BizSetupPage> createState() => _BizSetupPageState();
}

/// A product written in on the way (not kept until the end).
class _Item {
  _Item(this.name, this.qty, this.unit, this.buy, this.sell);
  final String name;
  final double qty;
  final String unit;
  final int buy;
  final int sell;
  int get worth => (qty * buy).round();
}

class _BizSetupPageState extends State<BizSetupPage> {
  String _kind = 'old';
  int _step = 0;
  bool _checked = false;
  bool _busy = false;

  final _shop = TextEditingController();
  final _cash = TextEditingController();
  final _bank = TextEditingController();
  final _loanAmt = TextEditingController();
  final _loanFrom = TextEditingController();
  String _type = '';

  // The shelf, the dues, the loans written in here.
  final _items = <_Item>[];
  final _customers = <(String, String, int)>[];
  final _dealers = <(String, int)>[];
  final _loans = <(String, int, int)>[];

  // The new-product line.
  final _pName = TextEditingController();
  final _pQty = TextEditingController();
  final _pBuy = TextEditingController();
  final _pSell = TextEditingController();
  String _pUnit = 'কেজি';

  @override
  void initState() {
    super.initState();
    final brain = BrainScope.read(context);
    _shop.text = brain.shop.profile.name;
    final cash = bizCashBalance(brain.data.cash);
    if (cash != 0) _cash.text = bnDigits(cash);
  }

  @override
  void dispose() {
    for (final c in [_shop, _cash, _bank, _loanAmt, _loanFrom, _pName, _pQty, _pBuy, _pSell]) {
      c.dispose();
    }
    super.dispose();
  }

  int _n(TextEditingController c) => (readNum(c.text) ?? 0).round();

  int get _steps => _kind == 'new' ? 2 : 4;

  /// The five sums as they will be: what the app has, with this page's.
  BizSums _sums(ShopBook b) {
    final cash = _n(_cash) + _n(_bank);
    if (_kind == 'new') {
      return BizSums(cash: cash, stock: b.products.fold(0, (s, p) => s + p.value), dues: owing(b).fold(0, (s, a) => s + a.due), payable: owedToDealers(b).fold(0, (s, a) => s + a.due), loans: _n(_loanAmt) + b.loans.fold(0, (s, l) => s + loanDue(b, l)));
    }
    return BizSums(
      cash: cash,
      stock: b.products.fold(0, (s, p) => s + p.value) + _items.fold(0, (s, i) => s + i.worth),
      dues: owing(b).fold(0, (s, a) => s + a.due) + _customers.fold(0, (s, c) => s + c.$3),
      payable: owedToDealers(b).fold(0, (s, a) => s + a.due) + _dealers.fold(0, (s, d) => s + d.$2),
      loans: b.loans.fold(0, (s, l) => s + loanDue(b, l)) + _loans.fold(0, (s, l) => s + l.$2),
    );
  }

  Future<void> _finish({bool skip = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final brain = BrainScope.read(context);
    if (skip) {
      await brain.startBusiness(kind: 'skip', shopName: _shop.text);
    } else {
      final loans = [..._loans];
      if (_kind == 'new' && _n(_loanAmt) > 0) loans.add((_loanFrom.text.trim().isEmpty ? tr('ঋণ') : _loanFrom.text.trim(), _n(_loanAmt), 0));
      await brain.startBusiness(
        kind: _kind,
        cash: _n(_cash) + _n(_bank),
        shopName: _shop.text,
        type: _type,
        products: [
          for (final i in _items) Product(name: i.name, unit: i.unit, buy: i.buy, sell: i.sell, stock: i.qty, loose: i.unit == 'কেজি' || i.unit == 'গ্রাম' || i.unit == 'লিটার', category: guessSection(i.name) ?? ''),
        ],
        customers: _customers,
        dealers: _dealers,
        loans: loans,
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  void _next() {
    if (_step < _steps - 1) {
      setState(() {
        _step++;
        _checked = false;
      });
    }
  }

  void _addItem() {
    final name = _pName.text.trim();
    final qty = readNum(_pQty.text) ?? 0;
    if (name.isEmpty || qty <= 0) {
      toast(context, tr('পণ্যের নাম আর পরিমাণ লিখুন'));
      return;
    }
    setState(() {
      _items.add(_Item(name, qty, _pUnit, _n(_pBuy), _n(_pSell)));
      for (final c in [_pName, _pQty, _pBuy, _pSell]) {
        c.clear();
      }
    });
  }

  Future<void> _addParty(String what) async {
    final name = TextEditingController(), phone = TextEditingController(), amount = TextEditingController(), inst = TextEditingController();
    final ok = await showAppSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(
              switch (what) {
                'customer' => tr('গ্রাহক ও বকেয়া'),
                'dealer' => tr('সাপ্লায়ার ও দেনা'),
                _ => tr('ঋণ'),
              },
              style: display(19)),
          const SizedBox(height: 14),
          LabeledField(controller: name, fieldKey: const Key('setup-party-name'), label: what == 'loan' ? tr('কার কাছে (ব্যাংক, এনজিও, ব্যক্তি)') : tr('নাম')),
          if (what == 'customer') LabeledField(controller: phone, label: tr('মোবাইল (ঐচ্ছিক)'), keyboard: TextInputType.phone),
          NumField(
              controller: amount,
              fieldKey: const Key('setup-party-amount'),
              label: switch (what) {
                'customer' => tr('কত বকেয়া পাবেন (৳)'),
                'dealer' => tr('কত দিতে হবে (৳)'),
                _ => tr('এখন কত বাকি আছে (৳)'),
              }),
          if (what == 'loan') ...[const SizedBox(height: 12), NumField(controller: inst, label: tr('মাসিক কিস্তি (৳, ঐচ্ছিক)'))],
          const SizedBox(height: 18),
          PrimaryButton(key: const Key('setup-party-save'), label: tr('যোগ করুন'), onPressed: () => Navigator.pop(ctx, true)),
        ]),
      ),
    );
    final n = name.text.trim(), a = _n(amount);
    if (ok == true && n.isNotEmpty && a > 0) {
      setState(() {
        switch (what) {
          case 'customer':
            _customers.add((n, phone.text.trim(), a));
          case 'dealer':
            _dealers.add((n, a));
          default:
            _loans.add((n, a, _n(inst)));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final last = _step == _steps - 1;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (did, _) {
        if (!did) setState(() => _step--);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
              child: Row(children: [
                IconButton(tooltip: tr('ফিরে যান'), onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.arrow_back_rounded)),
                Expanded(child: Text(_step == 0 ? tr('ব্যবসায়ী মোড') : (_kind == 'new' ? tr('নতুন ব্যবসা') : tr('শুরুর হিসাব')), style: display(20, weight: 700))),
                if (!last)
                TextButton(
                  key: const Key('setup-skip'),
                  onPressed: _busy ? null : () => _step == 0 ? _finish(skip: true) : _next(),
                  child: Text(_step == 0 ? tr('পরে করব') : tr('বাদ দিন'), style: body(14, weight: FontWeight.w600, color: C.green)),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(children: [
                for (var i = 0; i < _steps; i++) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(child: Container(height: 4, decoration: BoxDecoration(color: i <= _step ? C.green : C.line, borderRadius: BorderRadius.circular(2)))),
                ],
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Text(trf('ধাপ {0} / {1}', [bnDigits(_step + 1), bnDigits(_steps)]) + (_stepName.isEmpty ? '' : ' · ${tr(_stepName)}'), style: body(12.5, color: C.muted)),
            ),
            Expanded(
              child: ListView(
                key: ValueKey('setup-$_kind-$_step'),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: switch ((_kind, _step)) {
                  (_, 0) => _start(),
                  ('new', _) => _newBusiness(b),
                  (_, 1) => _cashStep(),
                  (_, 2) => _stockStep(b),
                  _ => _duesStep(b),
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 16 + MediaQuery.of(context).viewPadding.bottom),
              child: last
                  ? PrimaryButton(key: const Key('setup-done'), label: tr('নিশ্চিত করে শুরু করি'), icon: Icons.check_rounded, onPressed: _checked && !_busy ? () => _finish() : null)
                  : PrimaryButton(key: const Key('setup-next'), label: tr('পরের ধাপ'), onPressed: _next),
            ),
          ]),
        ),
      ),
    );
  }

  String get _stepName => switch ((_kind, _step)) {
        (_, 0) => '',
        ('new', _) => 'মূলধন',
        (_, 1) => 'দোকান ও টাকা',
        (_, 2) => 'স্টকে কী কী আছে',
        _ => 'পাওনা আর দেনা',
      };

  List<Widget> _start() {
    Widget choice(String kind, IconData icon, Color fg, Color bg, String title, String sub) {
      final on = _kind == kind;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: on ? C.greenTint : C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: on ? C.green : C.border, width: on ? 2 : 1)),
          child: InkWell(
            key: Key('setup-kind-$kind'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _kind = kind),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(color: on ? C.surface : bg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: fg)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: body(16.5, weight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(sub, style: body(13, color: C.muted, height: 1.5)),
                  ]),
                ),
                Icon(on ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: on ? C.green : C.inputBorder),
              ]),
            ),
          ),
        ),
      );
    }

    return [
      const SizedBox(height: 8),
      Text(tr('আপনার ব্যবসা কি নতুন, নাকি আগে থেকে চলছে?'), style: display(23, weight: 700, height: 1.35)),
      const SizedBox(height: 6),
      Text(tr('উত্তর অনুযায়ী শুরুর হিসাব সাজিয়ে দেব — যাতে প্রথম দিন থেকেই লাভ-ক্ষতি ঠিক দেখায়।'), style: body(14, color: C.muted, height: 1.55)),
      const SizedBox(height: 20),
      choice('old', Icons.storefront_outlined, C.green, C.greenTint, tr('আগে থেকে চলছে'), tr('দোকানে মাল আছে, ক্যাশে টাকা আছে, কারো কাছে বাকি পাই বা ডিলারকে দেব')),
      choice('new', Icons.eco_outlined, C.blue, C.blueTint, tr('নতুন শুরু করছি'), tr('শুধু কত টাকা নিয়ে শুরু করছেন, সেটা দিলেই চলবে')),
      const SizedBox(height: 6),
      _note(Icons.lock_outline_rounded, tr('সব তথ্য শুধু এই ফোনে থাকে। যেকোনো প্রশ্ন বাদ দিতে পারবেন।')),
    ];
  }

  Widget _note(IconData icon, String text) => Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: C.green),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: body(12.5, color: C.muted2, height: 1.5))),
        ]),
      );

  List<Widget> _cashStep() => [
        LabeledField(controller: _shop, fieldKey: const Key('setup-shop'), label: tr('দোকানের নাম'), hint: tr('যেমন: মায়ের দোয়া স্টোর')),
        NumField(controller: _cash, fieldKey: const Key('setup-cash'), label: tr('এখন ক্যাশে নগদ কত আছে? (৳)'), onChanged: (_) => setState(() {})),
        const SizedBox(height: 12),
        NumField(controller: _bank, fieldKey: const Key('setup-bank'), label: tr('বিকাশ / ব্যাংকে ব্যবসার টাকা (৳, ঐচ্ছিক)'), onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        _note(Icons.help_outline_rounded, tr('মূলধন আপনাকে লিখতে হবে না। নগদ, স্টক আর পাওনা-দেনা থেকে অ্যাপ নিজে হিসাব করবে, শেষ ধাপে মিলিয়ে নিশ্চিত করবেন।')),
      ];

  List<Widget> _stockStep(ShopBook b) {
    final had = b.products.fold<int>(0, (s, p) => s + p.value);
    final worth = had + _items.fold<int>(0, (s, i) => s + i.worth);
    final sell = b.products.fold<int>(0, (s, p) => s + (p.stock * p.sell).round()) + _items.fold<int>(0, (s, i) => s + (i.qty * i.sell).round());
    return [
      AppCard(
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('স্টকের মাল (কেনা দামে)'), style: body(12.5, color: C.muted)),
              Text(taka(worth), key: const Key('setup-stock-worth'), style: display(20, weight: 700)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(tr('বিক্রি করলে প্রায়'), style: body(12.5, color: C.muted)),
            Text(taka(sell), style: body(15, weight: FontWeight.w600, color: C.green)),
          ]),
        ]),
      ),
      if (b.products.isNotEmpty || _items.isNotEmpty) SectionHeading(tr('পণ্য'), counter: trf('{0}টি', [bnDigits(b.products.length + _items.length)])),
      if (b.products.isNotEmpty || _items.isNotEmpty)
        ListCard(rows: [
          for (final p in b.products) _itemRow(p.name, p.stock, p.unit, p.avgCost.round(), p.sell, p.value, null),
          for (final (k, i) in _items.indexed) _itemRow(i.name, i.qty, i.unit, i.buy, i.sell, i.worth, () => setState(() => _items.removeAt(k))),
        ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.green.withValues(alpha: 0.5))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Icon(Icons.add_rounded, color: C.green, size: 20), const SizedBox(width: 6), Text(tr('আরেকটা পণ্য'), style: body(14.5, weight: FontWeight.w600, color: C.green))]),
          const SizedBox(height: 8),
          TextField(textCapitalization: TextCapitalization.sentences, key: const Key('setup-p-name'), controller: _pName, style: body(15), decoration: InputDecoration(hintText: tr('পণ্যের নাম'), isDense: true, fillColor: C.surface, filled: true)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(flex: 5, child: TextField(key: const Key('setup-p-qty'), controller: _pQty, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: body(15), decoration: InputDecoration(hintText: tr('পরিমাণ'), isDense: true, fillColor: C.surface, filled: true))),
            const SizedBox(width: 6),
            Expanded(
              flex: 4,
              child: DropdownButtonFormField<String>(
                initialValue: _pUnit,
                isDense: true,
                decoration: InputDecoration(isDense: true, fillColor: C.surface, filled: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12)),
                items: [for (final u in shopUnits) DropdownMenuItem(value: u, child: Text(tr(u), style: body(14)))],
                onChanged: (v) => setState(() => _pUnit = v ?? _pUnit),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(key: const Key('setup-p-buy'), controller: _pBuy, keyboardType: TextInputType.number, style: body(15), decoration: InputDecoration(hintText: tr('কেনা দাম ৳'), isDense: true, fillColor: C.surface, filled: true))),
            const SizedBox(width: 6),
            Expanded(child: TextField(key: const Key('setup-p-sell'), controller: _pSell, keyboardType: TextInputType.number, style: body(15), decoration: InputDecoration(hintText: tr('বিক্রি দাম ৳'), isDense: true, fillColor: C.surface, filled: true))),
          ]),
          const SizedBox(height: 10),
          SecondaryButton(key: const Key('setup-p-add'), label: tr('তালিকায় যোগ করুন'), icon: Icons.add_rounded, onPressed: _addItem),
        ]),
      ),
      const SizedBox(height: 12),
      _note(Icons.inventory_2_outlined, tr('দাম লিখবেন প্রতি একক (কেজি, পিস, বোতল) হিসেবে। পরে স্টক পাতা থেকেও যোগ করা যাবে।')),
    ];
  }

  Widget _itemRow(String name, double qty, String unit, int buy, int sell, int worth, VoidCallback? remove) => ListRow(
        leading: LetterTile(name),
        title: name,
        subtitle: trf('{0} {1} · কেনা {2} · বিক্রি {3}', [bnDigits(qtyText(qty)), tr(unit), taka(buy), taka(sell)]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(taka(worth), style: body(14, weight: FontWeight.w600)),
          if (remove != null) IconButton(tooltip: tr('বাদ দিন'), onPressed: remove, icon: Icon(Icons.close_rounded, size: 18, color: C.muted)),
        ]),
      );

  List<Widget> _duesStep(ShopBook b) {
    final s = _sums(b);
    Widget group(String title, int total, List<Widget> rows, String add, String what, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHeading(title, counter: taka(total)),
          ListCard(
            rows: rows,
            foot: InkWell(
              key: Key('setup-add-$what'),
              onTap: () => _addParty(what),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(children: [Icon(Icons.add_rounded, color: C.green, size: 20), const SizedBox(width: 8), Text(add, style: body(14, weight: FontWeight.w600, color: C.green))]),
              ),
            ),
          ),
        ]);
    Widget row(String name, String sub, int amount, Color color, VoidCallback? remove) => ListRow(
          leading: Avatar(name: name, size: 36),
          title: name,
          subtitle: sub,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(taka(amount), style: body(14.5, weight: FontWeight.w600, color: color)),
            if (remove != null) IconButton(tooltip: tr('বাদ দিন'), onPressed: remove, icon: Icon(Icons.close_rounded, size: 18, color: C.muted)),
          ]),
        );
    return [
      group(
          tr('বাজারে বকেয়া · কার কাছে কত পাবেন'),
          s.dues,
          [
            for (final a in owing(b)) row(a.name, tr('আগে থেকে লেখা'), a.due, C.green, null),
            for (final (k, c) in _customers.indexed) row(c.$1, c.$2.isEmpty ? tr('নম্বর নেই') : bnDigits(c.$2), c.$3, C.green, () => setState(() => _customers.removeAt(k))),
          ],
          tr('গ্রাহক ও বকেয়া যোগ করুন'),
          'customer',
          C.green),
      group(
          tr('ডিলার / সাপ্লায়ার কত পাবে'),
          s.payable,
          [
            for (final a in owedToDealers(b)) row(a.name, tr('আগে থেকে লেখা'), a.due, C.warn, null),
            for (final (k, d) in _dealers.indexed) row(d.$1, '', d.$2, C.warn, () => setState(() => _dealers.removeAt(k))),
          ],
          tr('সাপ্লায়ার ও দেনা যোগ করুন'),
          'dealer',
          C.warn),
      group(
          tr('ব্যবসার ঋণ'),
          s.loans,
          [
            for (final l in b.loans) row(l.name, tr('আগে থেকে লেখা'), loanDue(b, l), C.blue, null),
            for (final (k, l) in _loans.indexed) row(l.$1, l.$3 > 0 ? trf('কিস্তি মাসে {0}', [taka(l.$3)]) : '', l.$2, C.blue, () => setState(() => _loans.removeAt(k))),
          ],
          tr('ঋণ যোগ করুন'),
          'loan',
          C.blue),
      const SizedBox(height: 16),
      _capitalCard(s),
    ];
  }

  List<Widget> _newBusiness(ShopBook b) {
    const types = ['মুদি', 'কাপড়', 'ওষুধ', 'মোবাইল-ইলেকট্রনিক্স', 'হার্ডওয়্যার', 'কসমেটিক্স', 'অন্য'];
    return [
      Text(tr('কত টাকা নিয়ে শুরু করছেন?'), style: display(22, weight: 700, height: 1.35)),
      const SizedBox(height: 4),
      Text(tr('ব্যবসার ক্যাশে যত টাকা রাখছেন — এখান থেকে লাভ-ক্ষতি মাপা হবে।'), style: body(14, color: C.muted, height: 1.5)),
      const SizedBox(height: 16),
      LabeledField(controller: _shop, fieldKey: const Key('setup-shop'), label: tr('দোকানের নাম'), hint: tr('যেমন: মায়ের দোয়া স্টোর')),
      NumField(controller: _cash, fieldKey: const Key('setup-cash'), label: tr('শুরুর টাকা (৳)'), onChanged: (_) => setState(() {})),
      const SizedBox(height: 12),
      Text(tr('এর মধ্যে ঋণ নিয়েছেন? (ঐচ্ছিক)'), style: body(12.5, color: C.muted)),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: TextField(key: const Key('setup-loan-amount'), controller: _loanAmt, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), style: body(15), decoration: InputDecoration(hintText: tr('৳ পরিমাণ'), isDense: true))),
        const SizedBox(width: 8),
        Expanded(child: TextField(textCapitalization: TextCapitalization.sentences, controller: _loanFrom, style: body(15), decoration: InputDecoration(hintText: tr('কার কাছে'), isDense: true))),
      ]),
      const SizedBox(height: 14),
      Text(tr('ব্যবসার ধরন (ঐচ্ছিক)'), style: body(12.5, color: C.muted)),
      const SizedBox(height: 6),
      Wrap(spacing: 7, runSpacing: 7, children: [
        for (final t in types) ChoiceChip(label: Text(tr(t)), selected: _type == t, onSelected: (on) => setState(() => _type = on ? t : '')),
      ]),
      const SizedBox(height: 16),
      _capitalCard(_sums(b)),
    ];
  }

  /// The capital as worked out, line by line, with the box to tick
  /// (owner, 23 Nov: "নিশ্চিত করার জন্যে ইউজারকে দেখাবে").
  Widget _capitalCard(BizSums s) {
    Widget line(String label, int v, {Color? color, bool minus = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(child: Text(label, style: body(12.5, color: C.muted))),
            Text('${minus ? '− ' : '+ '}${bnDigits(groupLakh(v))}', style: body(12.5, color: color ?? C.ink)),
          ]),
        );
    return Container(
      key: const Key('setup-capital'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.green, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('আপনার মূলধন দাঁড়াল'), style: body(12.5, color: C.muted)),
        Text(s.capital < 0 ? '− ${taka(-s.capital)}' : taka(s.capital), key: const Key('setup-capital-amount'), style: display(24, weight: 700, color: s.capital < 0 ? C.red : C.green)),
        const SizedBox(height: 8),
        line(tr('নগদ ও বিকাশ'), s.cash),
        if (s.stock != 0) line(tr('স্টকের মাল (কেনা দামে)'), s.stock),
        if (s.dues != 0) line(tr('বাজারে বকেয়া'), s.dues),
        if (s.payable != 0) line(tr('ডিলারের দেনা'), s.payable, color: C.warn, minus: true),
        if (s.loans != 0) line(tr('ঋণ'), s.loans, color: C.blue, minus: true),
        const SizedBox(height: 8),
        const Hairline(),
        InkWell(
          key: const Key('setup-confirm'),
          onTap: () => setState(() => _checked = !_checked),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Checkbox(value: _checked, onChanged: (v) => setState(() => _checked = v ?? false), visualDensity: VisualDensity.compact),
              Expanded(child: Text(tr('হিসাবটা মিলিয়ে দেখেছি, ঠিক আছে'), style: body(13.5, weight: FontWeight.w600))),
            ]),
          ),
        ),
        Text(tr('মূলধন হাতে বদলানো যায় না। কোনো অংক ভুল হলে আগের ধাপে গিয়ে সেটা ঠিক করুন।'), style: body(12, color: C.muted, height: 1.45)),
      ]),
    );
  }
}
