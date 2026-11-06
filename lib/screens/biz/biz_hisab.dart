import 'package:flutter/material.dart';

import '../../logic/bn.dart';
import '../../logic/cash.dart' show monthSums;
import '../../logic/lang.dart';
import '../../logic/ledger.dart';
import '../../logic/shop_logic.dart';
import '../../models/models.dart';
import '../../state/brain.dart';
import '../../ui/forms.dart' show askText;
import '../../ui/kit.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../home_shell.dart' show MenuPage;
import '../ledger_screen.dart' show MoneyScreen;
import 'biz_parts.dart';
import 'biz_sales.dart' show SellPage;

/// হিসাব (business mode tab): বাকি-দেনা, আয়-ব্যয়, দিন বন্ধ.
class BizHisab extends StatefulWidget {
  const BizHisab({super.key, this.part = 'baki'});
  final String part;
  @override
  State<BizHisab> createState() => BizHisabState();
}

class BizHisabState extends State<BizHisab> {
  late String _part = widget.part;

  void show(String part) => setState(() => _part = part);

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final box = cashBox(brain.data, now);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 96), children: [
      TabTitle(tr('হিসাব'), sub: trf('{0} · ক্যাশে {1}', [monthName(now.month), taka(box.expected)])),
      const SizedBox(height: 12),
      SegTabs<String>(
        key: const Key('biz-hisab-part'),
        items: [('money', tr('আয়-ব্যয়')), ('baki', tr('বাকি-দেনা')), ('close', tr('দিন বন্ধ'))],
        value: _part,
        onChanged: show,
      ),
      ...switch (_part) {
        'money' => _money(context, brain, now),
        'close' => [_DayClose(key: ValueKey(dayOnly(now)))],
        _ => _baki(context, brain, now),
      },
    ]);
  }

  List<Widget> _baki(BuildContext context, Brain brain, DateTime now) {
    final get = owing(brain.data), give = owed(brain.data);
    final getSum = get.fold<int>(0, (s, p) => s + p.balance), giveSum = give.fold<int>(0, (s, p) => s - p.balance);
    final today = dayOnly(now);
    bool dueToday(String name) {
      final b = buyerOf(brain.shop, name);
      return b.dueDay != null && !dayOnly(b.dueDay!).isAfter(today);
    }

    final dueN = get.where((p) => dueToday(p.name)).length;
    final nextGive = (brain.data.ledger.where((e) => e.kind == LedgerKind.borrowed && e.due != null && !dayOnly(e.due!).isBefore(today)).toList()..sort((a, b) => a.due!.compareTo(b.due!))).firstOrNull;
    String last(PersonBalance p) {
      final when = p.last ?? p.first;
      if (when == null) return '';
      final days = today.difference(dayOnly(when)).inDays;
      if (days <= 0) return tr('শেষ লেনদেন আজ');
      if (days < 30) return trf('শেষ লেনদেন {0} দিন আগে', [bnDigits(days)]);
      return tr('১ মাস কোনো লেনদেন নেই');
    }

    return [
      const SizedBox(height: 12),
      Panel(
        child: Column(children: [
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Icon(Icons.south_rounded, size: 13, color: C.muted), const SizedBox(width: 3), Flexible(child: Text(trf('পাবো · {0} জনের কাছে', [bnDigits(get.length)]), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted)))]),
                    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(taka(getSum), key: const Key('biz-get-sum'), style: display(22, weight: 600, color: C.green))),
                    if (dueN > 0) Text(trf('আজ {0} জনের দেওয়ার দিন', [bnDigits(dueN)]), style: body(11.5, color: C.warn)),
                  ]),
                ),
              ),
              Container(width: 1, color: C.border),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Icon(Icons.north_rounded, size: 13, color: C.muted), const SizedBox(width: 3), Flexible(child: Text(trf('দেবো · {0} জনকে', [bnDigits(give.length)]), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted)))]),
                    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(taka(giveSum), style: display(22, weight: 600, color: C.warn))),
                    if (nextGive != null) Text('${nextGive.person} · ${shortDate(nextGive.due!)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted)),
                  ]),
                ),
              ),
            ]),
          ),
        ]),
      ),
      SectionHeading(tr('যাদের কাছে পাবো'), counter: trf('{0} জন', [bnDigits(get.length)])),
      ListCard(
        empty: tr('কারো কাছে বাকি নেই। বাকিতে বিক্রি করলে, বা বললে “রহিমকে ৫০০ বাকি”, এখানে উঠবে।'),
        rows: [
          for (final p in get)
            ListRow(
              key: Key('biz-owes-${p.key}'),
              leading: Avatar(name: p.name, size: 38),
              title: p.name,
              subtitle: dueToday(p.name) ? tr('আজ দেওয়ার কথা') : last(p),
              subtitleColor: dueToday(p.name) || last(p) == tr('১ মাস কোনো লেনদেন নেই') ? C.warn : null,
              trailing: Text(taka(p.balance), style: body(14, weight: FontWeight.w600)),
              onTap: () => pushPage(context, BuyerPage(name: p.name)),
            ),
        ],
        foot: CardFoot(
          left: tr('+ যোগ করুন'),
          leftKey: const Key('biz-owes-add'),
          onLeft: () => pushPage(context, const SellPage(amountOnly: true)),
          right: get.isEmpty ? null : tr('সবাইকে তাগাদা'),
          onRight: () => _remindAll(context, brain, get),
        ),
      ),
      if (give.isNotEmpty) ...[
        SectionHeading(tr('যাদের দেবো'), counter: trf('{0} জন', [bnDigits(give.length)])),
        ListCard(rows: [
          for (final p in give)
            ListRow(
              leading: Avatar(name: p.name, size: 38),
              title: p.name,
              subtitle: last(p),
              trailing: Text(taka(-p.balance), style: body(14, weight: FontWeight.w600, color: C.warn)),
              onTap: () => pushPage(context, BuyerPage(name: p.name)),
            ),
        ]),
      ],
    ];
  }

  Future<void> _remindAll(BuildContext context, Brain brain, List<PersonBalance> ps) async {
    final withPhone = ps.where((p) => p.phone.isNotEmpty).toList();
    if (withPhone.isEmpty) return toast(context, tr('কারো মোবাইল নম্বর রাখা নেই — ক্রেতার পাতা থেকে একজন একজন করে পাঠান'));
    await showAppSheet<void>(
      context: context,
      builder: (ctx) => ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 12), children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(tr('কাকে পাঠাবেন?'), style: display(18, weight: 600))),
        for (final p in withPhone)
          ListTile(
            title: Text(p.name, style: body(15)),
            subtitle: Text(taka(p.balance), style: body(12.5, color: C.muted)),
            trailing: const Icon(Icons.send_rounded),
            onTap: () => brain.services.launcher.open(Via.sms, p.phone, text: tagadaText(p.name, p.balance)),
          ),
      ]),
    );
  }

  List<Widget> _money(BuildContext context, Brain brain, DateTime now) {
    final m = monthSums(brain.data.cash, now);
    final week = salesByDay(brain.shop, now);
    final top = week.fold<int>(1, (s, x) => x.$2 > s ? x.$2 : s);
    return [
      const SizedBox(height: 12),
      Panel(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(children: [
          Expanded(child: Figure(label: tr('এ মাসে আয়'), amount: taka(m.income), color: C.green, size: 20)),
          Expanded(child: Figure(label: tr('এ মাসে খরচ'), amount: taka(m.expense), size: 20)),
          Expanded(child: Figure(label: tr('থাকল'), amount: taka(m.balance), color: m.balance < 0 ? C.warn : C.ink, size: 20)),
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
      const SizedBox(height: 12),
      Panel(
        child: Column(children: [
          CardFoot(
            left: tr('+ দোকানের খরচ'),
            leftKey: const Key('biz-cost-add'),
            onLeft: () => addShopCost(context),
            right: tr('পুরো আয়-ব্যয়'),
            onRight: () => pushPage(context, const MenuPage(child: MoneyScreen())),
          ),
        ]),
      ),
    ];
  }
}

/// A shop cost: how much and what for.
Future<void> addShopCost(BuildContext context) async {
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

/// The তাগাদা message (with the payment line when a number is known).
String tagadaText(String name, int amount) => trf('{0} ভাই, আপনার বাকি {1}। সুবিধামতো দিয়ে দেবেন। ধন্যবাদ।', [name, taka(amount)]);

/// দিন বন্ধ: the cash box counted against what it should hold.
class _DayClose extends StatefulWidget {
  const _DayClose({super.key});
  @override
  State<_DayClose> createState() => _DayCloseState();
}

class _DayCloseState extends State<_DayClose> {
  final _counted = TextEditingController();

  @override
  void dispose() {
    _counted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final box = cashBox(brain.data, now);
    final counted = readNum(_counted.text)?.round();
    final diff = counted == null ? null : counted - box.expected;
    final closed = brain.shop.closes.where((c) => sameDay(c.day, now)).firstOrNull;
    Widget line(String label, int v, {String sign = '', bool strong = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(label, style: body(14, weight: strong ? FontWeight.w600 : FontWeight.w400))),
            Text('$sign${taka(v)}', style: body(14.5, weight: strong ? FontWeight.w700 : FontWeight.w500)),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading(tr('ক্যাশ মেলানো'), link: tr('সকালের টাকা'), onLink: () async {
        final v = await askText(context, tr('সকালে বাক্সে কত টাকা ছিল?'), initial: box.opening > 0 ? '${box.opening}' : '', number: true);
        final n = v == null ? null : readNum(v);
        if (n != null) await brain.setOpening(n.round());
      }),
      Panel(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
        child: Column(children: [
          line(tr('সকালে ছিল'), box.opening),
          line(tr('নগদ বিক্রি'), box.sales, sign: '+ '),
          line(tr('বাকি আদায়'), box.collected, sign: '+ '),
          line(tr('খরচ'), box.costs, sign: '− '),
          const Hairline(),
          line(tr('থাকার কথা'), box.expected, sign: '= ', strong: true),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(key: const Key('biz-close-counted'), controller: _counted, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), style: body(15), decoration: InputDecoration(labelText: tr('গুনে পেলাম'), prefixText: '৳ ', isDense: true))),
            const SizedBox(width: 10),
            if (diff != null) diff == 0 ? SoftChip(tr('মিলেছে')) : WarnChip(diff < 0 ? trf('{0} কম', [taka(-diff)]) : trf('{0} বেশি', [taka(diff)])),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      PrimaryButton(
        key: const Key('biz-close-day'),
        label: closed == null ? tr('দিন বন্ধ করুন') : tr('আবার গুনে রাখুন'),
        icon: Icons.lock_clock_outlined,
        onPressed: () async {
          if (counted == null) return toast(context, tr('বাক্সে গুনে কত পেলেন, লিখুন'));
          final c = await brain.closeDay(counted);
          if (!context.mounted) return;
          toast(context, c.diff == 0 ? tr('দিন বন্ধ — হিসাব মিলেছে') : trf('দিন বন্ধ — {0} {1}', [taka(c.diff.abs()), c.diff < 0 ? tr('কম') : tr('বেশি')]));
        },
      ),
      if (closed != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(trf('আজ বন্ধ করা হয়েছে · গুনে পেয়েছিলেন {0}', [taka(closed.counted)]), textAlign: TextAlign.center, style: body(12.5, color: C.muted))),
    ]);
  }
}

/// ক্রেতার হিসাব: what they owe, the limit and pay day, the তাগাদা, their entries.
class BuyerPage extends StatelessWidget {
  const BuyerPage({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final p = balances(brain.data.ledger).where((x) => x.name == name).firstOrNull;
    final owes = p?.balance ?? 0;
    final b = buyerOf(brain.shop, name);
    final entries = brain.data.ledger.where((e) => e.person == name).toList()..sort((a, c) => c.date.compareTo(a.date));
    final msg = tagadaText(name, owes);
    final dueToday = b.dueDay != null && !dayOnly(b.dueDay!).isAfter(dayOnly(now));
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          InnerTop(
            title: name,
            sub: p == null || p.phone.isEmpty ? tr('মোবাইল নম্বর রাখা নেই') : bnDigits(p.phone),
            actions: [
              if (p != null && p.phone.isNotEmpty) IconButton(tooltip: tr('ফোন করুন'), onPressed: () => brain.services.launcher.open(Via.call, p.phone), icon: const Icon(Icons.call_outlined)),
            ],
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (b.dueDay != null)
                    Text(dueToday ? tr('• দেওয়ার দিন · আজ') : trf('• দেওয়ার দিন · {0}', [shortDate(b.dueDay!)]), style: body(11.5, weight: FontWeight.w600, color: dueToday ? C.warn : C.green)),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(owes >= 0 ? tr('মোট পাওনা') : tr('আমি দেবো'), style: body(11.5, color: C.muted)),
                        Text(taka(owes.abs()), key: const Key('biz-buyer-owes'), style: display(27, weight: 600, color: owes < 0 ? C.warn : C.ink)),
                      ]),
                    ),
                    InkWell(
                      key: const Key('biz-buyer-limit'),
                      onTap: () async {
                        final v = await askText(context, tr('বাকির সীমা কত?'), initial: b.limit > 0 ? '${b.limit}' : '', number: true);
                        final n = v == null ? null : readNum(v);
                        if (n != null) await brain.saveBuyer(b.copyWith(limit: n.round()));
                      },
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(b.limit > 0 ? trf('বাকির সীমা {0}', [taka(b.limit)]) : tr('বাকির সীমা দিন'), style: body(12, color: C.green, weight: FontWeight.w600)),
                        if (b.limit > 0 && owes > 0) Text(trf('{0}% ব্যবহার হয়েছে', [bnDigits((owes * 100 / b.limit).round())]), style: body(11.5, color: owes > b.limit ? C.warn : C.muted)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: SmallButton(
                        key: const Key('biz-buyer-paid'),
                        label: tr('টাকা পেলাম'),
                        icon: Icons.check_rounded,
                        primary: true,
                        onTap: () async {
                          final v = await askText(context, tr('কত টাকা পেলেন?'), initial: owes > 0 ? '$owes' : '', number: true);
                          final n = v == null ? null : readNum(v);
                          if (n != null && n > 0) await brain.buyerPaid(name, n.round());
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: SmallButton(key: const Key('biz-buyer-credit'), label: tr('বাকিতে বিক্রি'), icon: Icons.add_rounded, onTap: () => pushPage(context, SellPage(customer: name)))),
                  ]),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    key: const Key('biz-buyer-due'),
                    onPressed: () async {
                      final d = await showDatePicker(context: context, initialDate: b.dueDay ?? now.add(const Duration(days: 7)), firstDate: dayOnly(now), lastDate: now.add(const Duration(days: 365)));
                      if (d != null) await brain.saveBuyer(b.copyWith(dueDay: d));
                    },
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(b.dueDay == null ? tr('দেওয়ার দিন ঠিক করুন') : tr('দেওয়ার দিন বদলান')),
                  ),
                ]),
              ),
              if (owes > 0) ...[
                SectionHeading(tr('তাগাদা'), counter: b.lastSent == null ? null : trf('শেষ পাঠানো {0}', [shortDate(b.lastSent!)])),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12)),
                      child: Text(msg, style: body(13.5, height: 1.55)),
                    ),
                    SwitchListTile(
                      key: const Key('biz-buyer-weekly'),
                      value: b.weekly,
                      onChanged: (v) => brain.saveBuyer(b.copyWith(weekly: v)),
                      title: Text(tr('প্রতি শুক্রবার মনে করাবে'), style: body(14)),
                      subtitle: Text(tr('সকাল ১০টায় নোটিফিকেশন — চাপলে মেসেজ পাঠানো যাবে'), style: body(11.5, color: C.muted)),
                    ),
                    CardFoot(
                      left: tr('SMS পাঠান'),
                      onLeft: () async {
                        await brain.services.launcher.open(Via.sms, p?.phone ?? '', text: msg);
                        await brain.saveBuyer(b.copyWith(lastSent: brain.services.now()));
                      },
                      right: tr('হোয়াটসঅ্যাপে'),
                      onRight: () async {
                        await brain.services.launcher.open(Via.whatsapp, p?.phone ?? '', text: msg);
                        await brain.saveBuyer(b.copyWith(lastSent: brain.services.now()));
                      },
                    ),
                  ]),
                ),
              ],
              SectionHeading(tr('লেনদেন'), counter: trf('{0}টি', [bnDigits(entries.length)])),
              ListCard(
                rows: [
                  for (final e in entries)
                    ListRow(
                      leading: DateBlock(top: bnDigits(e.date.day), bottom: monthShort(e.date.month)),
                      title: switch (e.kind) { LedgerKind.lent => tr('বাকিতে কেনা'), LedgerKind.received => tr('টাকা পেলাম'), LedgerKind.borrowed => tr('মাল নিলাম (দেনা)'), LedgerKind.repaid => tr('টাকা দিলাম') },
                      subtitle: e.note.isEmpty ? null : e.note,
                      trailing: Text('${e.kind.outflow ? '+ ' : '− '}${taka(e.amount)}', style: body(14, weight: FontWeight.w600, color: e.kind == LedgerKind.received ? C.green : C.ink)),
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
