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
import 'biz_stock.dart' show PurchasePage;

/// হিসাব (business mode tab): আয়-ব্যয় and the dealers (owner, 6 Nov: "ধার
/// দেনা বাদ দিয়ে এখানে ব্যবসায়ী ডিলারদের থেকে মাল ক্রয় ও টাকা প্রদানের হিসাব").
class BizHisab extends StatefulWidget {
  const BizHisab({super.key, this.part = 'money'});
  final String part;
  @override
  State<BizHisab> createState() => BizHisabState();
}

class BizHisabState extends State<BizHisab> {
  late String _part = widget.part;

  void show(String part) => setState(() => _part = part == 'dealers' ? 'dealers' : 'money');

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final dealersDue = owedToDealers(brain.shop).fold<int>(0, (s, a) => s + a.due);
    // Owner, 7 Nov: the inner tabs slide with the finger.
    return TabPages<String>(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      items: [('money', tr('আয়-ব্যয়')), ('dealers', tr('ডিলার ও মাল কেনা'))],
      value: _part,
      onChanged: show,
      top: (tabs) => [
        TabTitle(tr('হিসাব'), sub: trf('{0} · ডিলারের দেনা {1}', [monthName(now.month), taka(dealersDue)])),
        const BizFreeBanner(),
        const SizedBox(height: 12),
        tabs,
      ],
      page: (part) => switch (part) {
        'dealers' => _dealers(context, brain, now),
        _ => _money(context, brain, now),
      },
    );
  }

  List<Widget> _dealers(BuildContext context, Brain brain, DateTime now) {
    final b = brain.shop;
    final accounts = [for (final d in b.dealers) dealerAccount(b, d)]..sort((x, y) => y.due != x.due ? y.due.compareTo(x.due) : x.name.compareTo(y.name));
    final due = accounts.fold<int>(0, (s, a) => s + (a.due > 0 ? a.due : 0));
    final monthStart = DateTime(now.year, now.month);
    final bought = b.purchases.where((p) => !p.at.isBefore(monthStart)).fold<int>(0, (s, p) => s + p.total);
    final paid = b.payouts.where((p) => !p.at.isBefore(monthStart)).fold<int>(0, (s, p) => s + p.amount) + b.purchases.where((p) => !p.at.isBefore(monthStart)).fold<int>(0, (s, p) => s + p.paid);
    return [
      const SizedBox(height: 12),
      Panel(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(children: [
          Expanded(child: Figure(label: tr('দেবো (ডিলার)'), amount: taka(due), color: due > 0 ? C.warn : C.ink, size: 20)),
          Expanded(child: Figure(label: tr('এ মাসে মাল কেনা'), amount: taka(bought), size: 20)),
          Expanded(child: Figure(label: tr('এ মাসে পরিশোধ'), amount: taka(paid), color: C.green, size: 20)),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: SmallButton(key: const Key('biz-buy-goods'), label: tr('মাল কিনলাম'), icon: Icons.local_shipping_outlined, primary: true, onTap: () => pushPage(context, const PurchasePage(part: 'in')))),
        const SizedBox(width: 8),
        Expanded(child: SmallButton(key: const Key('biz-pay-dealer'), label: tr('টাকা দিলাম'), icon: Icons.payments_outlined, onTap: () => _payWho(context))),
      ]),
      SectionHeading(tr('ডিলার'), counter: trf('{0} জন', [bnDigits(accounts.length)])),
      ListCard(
        empty: tr('কোনো ডিলার নেই। যাদের কাছ থেকে মাল কেনেন, তাঁদের যোগ করুন — কত মাল কিনলেন, কত দিলেন, কত বাকি, সব আলাদা থাকবে।'),
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
        foot: CardFoot(left: tr('+ নতুন ডিলার'), leftKey: const Key('biz-dealer-add'), onLeft: () => pushPage(context, const DealerForm()), right: tr('অর্ডার তালিকা'), onRight: () => pushPage(context, const PurchasePage())),
      ),
      ..._recentPurchases(context, brain),
    ];
  }

  List<Widget> _recentPurchases(BuildContext context, Brain brain) {
    final list = [...brain.shop.purchases]..sort((a, b) => b.at.compareTo(a.at));
    if (list.isEmpty) return const [];
    return [
      SectionHeading(tr('সাম্প্রতিক মাল কেনা')),
      ListCard(rows: [for (final p in list.take(6)) purchaseRow(context, p)]),
    ];
  }

  Future<void> _payWho(BuildContext context) async {
    final brain = BrainScope.read(context);
    final d = await pickDealer(context);
    if (d == null || !context.mounted) return;
    await payDealer(context, brain, d);
  }

  List<Widget> _money(BuildContext context, Brain brain, DateTime now) {
    final m = bizMonthSums(brain.data.cash, now);
    final week = salesByDay(brain.shop, now);
    final top = week.fold<int>(1, (s, x) => x.$2 > s ? x.$2 : s);
    final cash = todayCash(brain.data, now);
    return [
      const SizedBox(height: 12),
      Panel(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(children: [
          Expanded(child: Figure(label: tr('এ মাসে আয়'), amount: taka(m.income), color: C.green, size: 20)),
          Expanded(child: Figure(label: tr('এ মাসে খরচ'), amount: taka(m.expense), size: 20)),
          Expanded(child: Figure(label: tr('থাকল'), amount: '${m.balance < 0 ? '− ' : ''}${taka(m.balance.abs())}', color: m.balance < 0 ? C.warn : C.ink, size: 20)),
        ]),
      ),
      SectionHeading(tr('গত ৭ দিনের বিক্রি')),
      Panel(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        child: SizedBox(
          height: 120,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final (i, (day, amount)) in week.indexed)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: amount <= 0 ? 0.03 : (amount / top).clamp(0.03, 1.0),
                        child: Container(decoration: BoxDecoration(color: i == week.length - 1 ? C.green : C.greenTint, borderRadius: BorderRadius.circular(5))),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(dayName(day.weekday).characters.take(2).toString(), style: body(10.5, color: C.muted)),
                  ]),
                ),
              ),
          ]),
        ),
      ),
      SectionHeading(tr('আজকের নগদ')),
      Panel(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        child: Column(children: [
          for (final (label, v, sign) in [(tr('নগদ বিক্রি'), cash.sales, '+ '), (tr('বাকি আদায়'), cash.collected, '+ '), (tr('মাল কেনা, ডিলার ও খরচ'), cash.out, '− ')])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [Expanded(child: Text(label, style: body(14))), Text('$sign${taka(v)}', style: body(14.5, weight: FontWeight.w500))]),
            ),
          const Hairline(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Expanded(child: Text(tr('আজ হাতে এল'), style: body(14, weight: FontWeight.w600))),
              Text('${cash.net < 0 ? '− ' : ''}${taka(cash.net.abs())}', key: const Key('biz-cash-net'), style: body(15, weight: FontWeight.w700, color: cash.net < 0 ? C.warn : C.green)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(children: [
          CardFoot(
            left: tr('+ দোকানের খরচ'),
            leftKey: const Key('biz-cost-add'),
            onLeft: () => addShopCost(context),
            right: tr('ব্যবসার আয়-ব্যয়'),
            rightKey: const Key('biz-cash-all'),
            onRight: () => pushPage(context, const BizCashPage()),
          ),
        ]),
      ),
    ];
  }
}

/// A shop cost: how much and what for.
Future<void> addShopCost(BuildContext context) async {
  if (!await bizCan(context) || !context.mounted) return;
  final brain = BrainScope.read(context);
  final amount = await askText(context, tr('কত টাকা খরচ?'), number: true);
  final n = amount == null ? null : readNum(amount);
  if (n == null || n <= 0 || !context.mounted) return;
  const kinds = ['দোকান ভাড়া', 'বিদ্যুৎ বিল', 'কর্মচারীর বেতন', 'পরিবহন', 'অন্যান্য খরচ'];
  final kind = await showAppSheet<String>(
    context: context,
    builder: (ctx) => ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 12), children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(tr('কীসের খরচ?'), style: display(18, weight: 600))),
      for (final k in kinds) ListTile(title: Text(tr(k), style: body(15)), onTap: () => Navigator.pop(ctx, k)),
    ]),
  );
  if (kind == null) return;
  await brain.shopCost(n.round(), kind == 'অন্যান্য খরচ' ? 'দোকান খরচ' : kind);
  if (context.mounted) toast(context, trf('{0} রাখা হয়েছে', [taka(n.round())]));
}

/// Pay a dealer: how much (the whole দেনা offered).
Future<void> payDealer(BuildContext context, Brain brain, Dealer d) async {
  if (!await bizCan(context) || !context.mounted) return;
  final due = dealerAccount(brain.shop, d).due;
  final v = await askText(context, trf('{0}-কে কত টাকা দিলেন?', [d.name]), initial: due > 0 ? bnDigits(due) : '', number: true);
  final n = v == null ? null : readNum(v);
  if (n == null || n <= 0) return;
  await brain.dealerPaid(d.id, n.round());
  if (context.mounted) toast(context, trf('{0} দেওয়া হলো — আয়-ব্যয়ে “ডিলারকে পরিশোধ” লেখা হলো', [taka(n.round())]));
}

/// A purchase as a row: the dealer, what came, total and what was paid.
Widget purchaseRow(BuildContext context, Purchase p, {bool showDealer = true}) => ListRow(
      key: Key('biz-purchase-${p.id}'),
      leading: DateBlock(top: bnDigits(p.at.day), bottom: monthShort(p.at.month)),
      title: [if (showDealer && p.dealer.isNotEmpty) p.dealer, p.lines.isEmpty ? tr('মাল কেনা') : p.lines.map((l) => l.name).take(3).join(', ')].join(' · '),
      subtitle: p.owed > 0 ? (p.paid > 0 ? trf('দিলাম {0} · বাকি {1}', [taka(p.paid), taka(p.owed)]) : trf('পুরোটা বাকি · {0}', [taka(p.owed)])) : tr('পুরো টাকা দেওয়া'),
      subtitleColor: p.owed > 0 ? C.warn : null,
      trailing: Text(taka(p.total), style: body(14, weight: FontWeight.w600)),
      onLongPress: () async {
        final ok = await confirmDialog(context, title: tr('এই মাল কেনা মুছবেন?'), text: tr('পণ্যগুলো স্টক থেকে কমবে, টাকার হিসাবও মুছে যাবে।'), yes: tr('মুছুন'), danger: true);
        if (ok && context.mounted) await BrainScope.read(context).undoShopEntry(p.id);
      },
    );

/// Pick a dealer (or write a new name). Null when closed.
Future<Dealer?> pickDealer(BuildContext context) async {
  final brain = BrainScope.read(context);
  final v = await showAppSheet<String>(context: context, isScrollControlled: true, builder: (_) => const _PickDealer());
  if (v == null || v.trim().isEmpty) return null;
  if (v.startsWith('id:')) return dealerById(brain.shop, v.substring(3));
  if (!context.mounted || !await bizCan(context)) return null;
  return brain.dealerFor(v.trim());
}

class _PickDealer extends StatefulWidget {
  const _PickDealer();
  @override
  State<_PickDealer> createState() => _PickDealerState();
}

class _PickDealerState extends State<_PickDealer> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final q = _c.text.trim();
    final list = brain.shop.dealers.where((d) => q.isEmpty || d.name.toLowerCase().contains(q.toLowerCase())).toList()..sort((a, b) => a.name.compareTo(b.name));
    final exact = brain.shop.dealers.any((d) => d.name.trim() == q);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('কোন ডিলার?'), style: display(18, weight: 600)),
        const SizedBox(height: 10),
        TextField(textCapitalization: TextCapitalization.sentences, 
          key: const Key('biz-dealer-name'),
          controller: _c,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          style: body(15),
          decoration: InputDecoration(hintText: tr('ডিলারের নাম লিখুন'), prefixIcon: const Icon(Icons.search_rounded), isDense: true),
          onSubmitted: (t) => Navigator.pop(context, list.length == 1 ? 'id:${list.single.id}' : t.trim()),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView(shrinkWrap: true, children: [
            if (q.isNotEmpty && !exact)
              ListTile(
                key: const Key('biz-dealer-new'),
                leading: Icon(Icons.add_business_outlined, color: C.green),
                title: Text(trf('নতুন ডিলার: {0}', [q]), style: body(14.5, color: C.green, weight: FontWeight.w600)),
                onTap: () => Navigator.pop(context, q),
              ),
            for (final d in list)
              ListTile(
                key: Key('biz-pickd-${d.id}'),
                leading: Avatar(name: d.name, size: 34, fg: C.orange, bg: C.orangeTint),
                title: Text(d.name, style: body(14.5)),
                subtitle: () {
                  final due = dealerAccount(brain.shop, d).due;
                  return due > 0 ? Text(trf('দেনা {0}', [taka(due)]), style: body(12, color: C.warn)) : null;
                }(),
                onTap: () => Navigator.pop(context, 'id:${d.id}'),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// A dealer's page: what the shop owes them, pay or buy, their details, and
/// every purchase and payment.
class DealerPage extends StatelessWidget {
  const DealerPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = dealerById(brain.shop, id);
    if (d == null) return const Scaffold(body: SizedBox.shrink());
    final a = dealerAccount(brain.shop, d);
    final purchases = [for (final p in brain.shop.purchases) if (p.dealerId == d.id) p];
    final pays = [for (final p in brain.shop.payouts) if (p.party == d.id) p];
    final bought = purchases.fold<int>(0, (s, p) => s + p.total);
    final entries = <(DateTime, Widget)>[
      for (final p in purchases) (p.at, purchaseRow(context, p, showDealer: false)),
      for (final p in pays)
        (
          p.at,
          ListRow(
            key: Key('biz-payout-${p.id}'),
            leading: DateBlock(top: bnDigits(p.at.day), bottom: monthShort(p.at.month)),
            title: tr('টাকা দিলাম'),
            subtitle: p.note.isEmpty ? null : p.note,
            trailing: Text('− ${taka(p.amount)}', style: body(14, weight: FontWeight.w600, color: C.green)),
            onLongPress: () async {
              final ok = await confirmDialog(context, title: tr('এই টাকা দেওয়াটা মুছবেন?'), text: tr('দেনা আবার আগের মতো হবে, আয়-ব্যয় থেকেও মুছে যাবে।'), yes: tr('মুছুন'), danger: true);
              if (ok && context.mounted) await BrainScope.read(context).undoShopEntry(p.id);
            },
          )
        ),
    ]..sort((x, y) => y.$1.compareTo(x.$1));
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          InnerTop(
            title: d.name,
            sub: [if (d.phone.isNotEmpty) bnDigits(d.phone), tr('ডিলার')].join(' · '),
            actions: [
              if (d.phone.isNotEmpty) IconButton(tooltip: tr('ফোন করুন'), onPressed: () => brain.services.launcher.open(Via.call, d.phone), icon: const Icon(Icons.call_outlined)),
              IconButton(key: const Key('biz-dealer-edit'), tooltip: tr('বদলান'), onPressed: () => pushPage(context, DealerForm(dealer: d)), icon: const Icon(Icons.edit_outlined)),
            ],
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.due >= 0 ? tr('তাঁকে দেবো') : tr('অগ্রিম দেওয়া আছে'), style: body(11.5, color: C.muted)),
                  Text(taka(a.due.abs()), key: const Key('biz-dealer-due'), style: display(27, weight: 600, color: a.due > 0 ? C.warn : C.green)),
                  if (a.since != null && a.due > 0) Text(trf('{0} থেকে বাকি', [shortDate(a.since!)]), style: body(12, color: C.muted)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: SmallButton(key: const Key('biz-dealer-pay'), label: tr('টাকা দিলাম'), icon: Icons.payments_outlined, primary: true, onTap: () => payDealer(context, brain, d))),
                    const SizedBox(width: 8),
                    Expanded(child: SmallButton(key: const Key('biz-dealer-buy'), label: tr('মাল কিনলাম'), icon: Icons.local_shipping_outlined, onTap: () => pushPage(context, PurchasePage(part: 'in', dealerId: d.id)))),
                  ]),
                ]),
              ),
              SectionHeading(tr('বিস্তারিত')),
              detailRows([
                (Icons.phone_outlined, tr('মোবাইল'), bnDigits(d.phone)),
                (Icons.chat_outlined, tr('হোয়াটসঅ্যাপ'), bnDigits(d.whatsapp)),
                (Icons.place_outlined, tr('ঠিকানা'), d.address),
                (Icons.sticky_note_2_outlined, tr('নোট'), d.note),
                (Icons.local_shipping_outlined, tr('মোট মাল কেনা'), purchases.isEmpty ? '' : trf('{0} · {1} বার', [taka(bought), bnDigits(purchases.length)])),
              ]),
              SectionHeading(tr('মাল কেনা ও পরিশোধ'), counter: trf('{0}টি', [bnDigits(entries.length)])),
              ListCard(rows: [for (final e in entries) e.$2], empty: tr('এখনো কোনো লেনদেন নেই।')),
              if (entries.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(tr('কোনোটা ভুল হলে চেপে ধরে মুছুন।'), textAlign: TextAlign.center, style: body(12, color: C.muted))),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// নতুন ডিলার / ডিলারের তথ্য বদলান.
class DealerForm extends StatefulWidget {
  const DealerForm({super.key, this.dealer});
  final Dealer? dealer;
  @override
  State<DealerForm> createState() => _DealerFormState();
}

class _DealerFormState extends State<DealerForm> {
  late final Dealer? _d = widget.dealer;
  late final _name = TextEditingController(text: _d?.name ?? '');
  late final _phone = TextEditingController(text: _d == null ? '' : bnDigits(_d.phone));
  late final _wa = TextEditingController(text: _d == null ? '' : bnDigits(_d.whatsapp));
  late final _address = TextEditingController(text: _d?.address ?? '');
  late final _note = TextEditingController(text: _d?.note ?? '');
  late final _opening = TextEditingController(text: _d == null || _d.opening == 0 ? '' : bnDigits(_d.opening));

  @override
  void dispose() {
    for (final c in [_name, _phone, _wa, _address, _note, _opening]) {
      c.dispose();
    }
    super.dispose();
  }

  String _num(String s) => asciiDigits(s).replaceAll(RegExp(r'[^0-9+]'), '');

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            InnerTop(
              title: _d == null ? tr('নতুন ডিলার') : tr('ডিলারের তথ্য'),
              actions: [
                if (_d != null)
                  IconButton(
                    key: const Key('biz-dealer-delete'),
                    tooltip: tr('মুছুন'),
                    onPressed: () async {
                      final ok = await confirmDialog(context, title: trf('‘{0}’ মুছবেন?', [_d.name]), text: tr('মাল কেনার পুরোনো হিসাব থেকে যাবে। মুছে ফেলা থেকে ৩০ দিন ফেরানো যায়।'), yes: tr('মুছুন'), danger: true);
                      if (!ok || !context.mounted) return;
                      await BrainScope.read(context).deleteDealer(_d.id);
                      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    icon: Icon(Icons.delete_outline_rounded, color: C.red),
                  ),
              ],
            ),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
                LabeledField(controller: _name, label: tr('ডিলার বা প্রতিষ্ঠানের নাম'), hint: tr('যেমন: করিম ট্রেডার্স'), fieldKey: const Key('biz-df-name'), icon: Icons.storefront_outlined),
                LabeledField(controller: _phone, label: tr('মোবাইল নম্বর'), hint: '01XXXXXXXXX', keyboard: TextInputType.phone, fieldKey: const Key('biz-df-phone'), icon: Icons.phone_outlined),
                LabeledField(controller: _wa, label: tr('হোয়াটসঅ্যাপ নম্বর'), hint: tr('খালি থাকলে মোবাইল নম্বরেই'), keyboard: TextInputType.phone, fieldKey: const Key('biz-df-wa'), icon: Icons.chat_outlined),
                LabeledField(controller: _address, label: tr('ঠিকানা'), fieldKey: const Key('biz-df-address'), icon: Icons.place_outlined),
                NumField(controller: _opening, label: tr('আগের দেনা (অ্যাপের আগে যা বাকি ছিল)'), hint: '৳', fieldKey: const Key('biz-df-opening')),
                const SizedBox(height: 12),
                LabeledField(controller: _note, label: tr('নোট'), hint: tr('যেমন: প্রতি বৃহস্পতিবার মাল দেয়'), lines: 2, fieldKey: const Key('biz-df-note')),
              ]),
            ),
            PageFoot(
              child: PrimaryButton(
                key: const Key('biz-df-save'),
                label: tr('ডিলার রাখুন'),
                icon: Icons.check_rounded,
                onPressed: () async {
                  final name = _name.text.trim();
                  if (name.isEmpty) return toast(context, tr('ডিলারের নাম লিখুন'));
                  if (!await bizCan(context) || !context.mounted) return;
                  final base = _d ?? Dealer(name: name);
                  final kept = await BrainScope.read(context).saveDealer(base.copyWith(
                    name: name,
                    phone: _num(_phone.text),
                    whatsapp: _num(_wa.text),
                    address: _address.text.trim(),
                    note: _note.text.trim(),
                    opening: (readNum(_opening.text) ?? 0).round(),
                  ));
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  if (_d == null) pushPage(context, DealerPage(id: kept.id));
                },
              ),
            ),
          ]),
        ),
      );
}

/// The business's own আয়-ব্যয় (owner, 7 Nov: kept apart from the personal
/// one): month by month, every entry the shop wrote.
class BizCashPage extends StatefulWidget {
  const BizCashPage({super.key});
  @override
  State<BizCashPage> createState() => _BizCashPageState();
}

class _BizCashPageState extends State<BizCashPage> {
  int _back = 0;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final month = DateTime(now.year, now.month - _back);
    final m = bizMonthSums(brain.data.cash, month);
    final rows = [for (final e in brain.data.cash) if (isBizCash(e) && e.date.year == month.year && e.date.month == month.month) e]..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          InnerTop(title: tr('ব্যবসার আয়-ব্যয়'), sub: tr('নিজের আয়-ব্যয় থেকে আলাদা')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              Row(children: [
                IconButton(key: const Key('biz-cash-prev'), onPressed: () => setState(() => _back++), icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(child: Text('${monthName(month.month)} ${bnDigits(month.year)}', textAlign: TextAlign.center, style: body(15, weight: FontWeight.w600))),
                IconButton(key: const Key('biz-cash-next'), onPressed: _back == 0 ? null : () => setState(() => _back--), icon: const Icon(Icons.chevron_right_rounded)),
              ]),
              Panel(
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                child: Row(children: [
                  Expanded(child: Figure(label: tr('আয়'), amount: taka(m.income), color: C.green, size: 19)),
                  Expanded(child: Figure(label: tr('খরচ'), amount: taka(m.expense), size: 19)),
                  Expanded(child: Figure(label: tr('থাকল'), amount: '${m.balance < 0 ? '− ' : ''}${taka(m.balance.abs())}', color: m.balance < 0 ? C.warn : C.ink, size: 19)),
                ]),
              ),
              const SizedBox(height: 12),
              if (rows.isEmpty)
                Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Text(tr('এই মাসে ব্যবসার কোনো আয়-ব্যয় নেই।'), textAlign: TextAlign.center, style: body(14, color: C.muted)))
              else
                ListCard(rows: [
                  for (final e in rows)
                    ListRow(
                      key: Key('biz-cash-${e.id}'),
                      leading: DateBlock(top: bnDigits(e.date.day), bottom: monthShort(e.date.month)),
                      title: tr(e.category),
                      subtitle: e.note.isEmpty ? null : e.note,
                      trailing: Text('${e.kind == CashKind.income ? '+ ' : '− '}${taka(e.amount)}', style: body(14, weight: FontWeight.w600, color: e.kind == CashKind.income ? C.green : C.ink)),
                    ),
                ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
