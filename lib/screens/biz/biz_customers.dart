import 'package:flutter/material.dart';

import '../../logic/bn.dart';
import '../../logic/lang.dart';
import '../../logic/shop_logic.dart';
import '../../models/models.dart';
import '../../state/brain.dart';
import '../../ui/forms.dart' show askText, askTime;
import '../../ui/kit.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'biz_parts.dart';
import 'biz_sales.dart' show SellPage, showReceipt;
import 'biz_shop.dart' show TagadaPage;

/// গ্রাহক (business mode tab; owner, 6 Nov: "গ্রাহকদের প্রোফাইল দরকার। তাদের
/// নামে মেনু থাকবে। সেখানে গেলে বিস্তারিত থাকবে।").
class BizCustomers extends StatefulWidget {
  const BizCustomers({super.key});
  @override
  State<BizCustomers> createState() => _BizCustomersState();
}

class _BizCustomersState extends State<BizCustomers> {
  final _find = TextEditingController();
  String _part = 'all';

  @override
  void dispose() {
    _find.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final now = brain.services.now();
    final accounts = {for (final c in b.customers) c.id: customerAccount(b, c)};
    final owingN = accounts.values.where((a) => a.due > 0).length;
    final dueSum = accounts.values.fold<int>(0, (s, a) => s + (a.due > 0 ? a.due : 0));
    final longN = accounts.values.where((a) => a.daysOwed(now) > 30).length;
    // Owner, 7 Nov: the inner tabs slide with the finger.
    return TabPages<String>(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
      items: [('all', tr('সবাই')), ('due', owingN == 0 ? tr('বাকি আছে') : trf('বাকি আছে · {0}', [bnDigits(owingN)])), ('long', longN == 0 ? tr('৩০ দিন+') : trf('৩০ দিন+ · {0}', [bnDigits(longN)]))],
      value: _part,
      onChanged: (v) => setState(() => _part = v),
      top: (tabs) => [
        TabTitle(trm('গ্রাহক'),
            sub: trf('{0} জন · বাকি {1}', [bnDigits(b.customers.length), taka(dueSum)]),
            trailing: IconButton(key: const Key('biz-customer-add'), tooltip: tr('নতুন গ্রাহক'), onPressed: () => pushPage(context, const CustomerForm()), icon: const Icon(Icons.person_add_alt_outlined))),
        const BizFreeBanner(),
        const SizedBox(height: 12),
        Panel(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(children: [
            Expanded(child: Figure(label: trf('পাবো · {0} জনের কাছে', [bnDigits(owingN)]), amount: taka(dueSum), color: C.green, size: 20)),
            Expanded(child: Figure(label: tr('৩০ দিনের বেশি বাকি'), amount: trf('{0} জন', [bnDigits(longN)]), color: longN > 0 ? C.warn : C.ink, size: 20)),
          ]),
        ),
        const SizedBox(height: 12),
        TextField(textCapitalization: TextCapitalization.sentences, 
          key: const Key('biz-customer-find'),
          controller: _find,
          onChanged: (_) => setState(() {}),
          style: body(14.5),
          decoration: InputDecoration(hintText: tr('নাম বা মোবাইল দিয়ে খুঁজুন'), prefixIcon: const Icon(Icons.search_rounded), isDense: true),
        ),
        const SizedBox(height: 10),
        tabs,
      ],
      page: (part) => _page(context, b, part, accounts, now, owingN),
    );
  }

  List<Widget> _page(BuildContext context, ShopBook b, String part, Map<String, Account> accounts, DateTime now, int owingN) {
    final q = _find.text.trim().toLowerCase();
    var shown = b.customers.where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || asciiDigits(c.phone).contains(asciiDigits(q))).toList();
    shown = switch (part) {
      'due' => shown.where((c) => accounts[c.id]!.due > 0).toList(),
      'long' => shown.where((c) => accounts[c.id]!.daysOwed(now) > 30).toList(),
      _ => shown,
    };
    shown.sort((a, c) {
      final x = accounts[c.id]!.due.compareTo(accounts[a.id]!.due);
      return x != 0 ? x : a.name.compareTo(c.name);
    });
    return [
      if (b.customers.isEmpty)
        EmptyState(
          icon: Icons.people_outline_rounded,
          title: tr('এখনো কোনো গ্রাহক নেই'),
          text: tr('নাম, মোবাইল আর হোয়াটসঅ্যাপ রাখুন — বাকিতে বিক্রি, তাগাদা আর রিমাইন্ডার সব তাঁর পাতায় থাকবে।'),
          action: tr('গ্রাহক যোগ করুন'),
          onAction: () => pushPage(context, const CustomerForm()),
        )
      else
        ListCard(
          empty: tr('মেলেনি।'),
          rows: [for (final c in shown) _row(context, c, accounts[c.id]!, now)],
          foot: CardFoot(
            left: tr('+ নতুন গ্রাহক'),
            leftKey: const Key('biz-customer-add-foot'),
            onLeft: () => pushPage(context, const CustomerForm()),
            right: owingN == 0 ? null : tr('সবাইকে তাগাদা'),
            onRight: () => _remindAll(context),
          ),
        ),
    ];
  }

  Widget _row(BuildContext context, Customer c, Account a, DateTime now) {
    final days = a.daysOwed(now);
    final sub = [
      if (c.phone.isNotEmpty) bnDigits(c.phone),
      if (a.due > 0 && days > 0) trf('{0} ধরে বাকি', [owedFor(days)]),
      if (a.due <= 0 && a.last != null) trf('শেষ কেনা {0}', [shortDate(a.last!)]),
    ].join(' · ');
    return ListRow(
      key: Key('biz-customer-${c.id}'),
      leading: Avatar(name: c.name, size: 40),
      title: c.name,
      subtitle: sub.isEmpty ? null : sub,
      subtitleColor: days > 30 ? C.warn : null,
      trailing: a.due > 0
          ? Text(taka(a.due), style: body(14.5, weight: FontWeight.w600, color: days > 30 ? C.warn : C.green))
          : Icon(Icons.chevron_right_rounded, color: C.muted),
      onTap: () => pushPage(context, CustomerPage(id: c.id)),
    );
  }

  Future<void> _remindAll(BuildContext context) async {
    final brain = BrainScope.read(context);
    final list = [
      for (final a in owing(brain.shop))
        if (customerById(brain.shop, a.id) case final c?) (c, a.due),
    ];
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ListView(shrinkWrap: true, padding: const EdgeInsets.symmetric(vertical: 12), children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 4), child: Text(tr('কাকে তাগাদা পাঠাবেন?'), style: display(18, weight: 600))),
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 8), child: Text(tr('হোয়াটসঅ্যাপ নম্বর থাকলে হোয়াটসঅ্যাপে, না থাকলে SMS-এ যাবে।'), style: body(12.5, color: C.muted))),
        for (final (c, due) in list)
          ListTile(
            leading: Avatar(name: c.name, size: 36),
            title: Text(c.name, style: body(15)),
            subtitle: Text(c.whatsappNumber.isEmpty ? trf('{0} · নম্বর নেই', [taka(due)]) : taka(due), style: body(12.5, color: C.muted)),
            trailing: Icon(c.whatsappNumber.isEmpty ? Icons.block_rounded : Icons.send_rounded, color: c.whatsappNumber.isEmpty ? C.muted : C.green),
            onTap: c.whatsappNumber.isEmpty ? null : () => sendTagada(ctx, c, due, via: c.whatsapp.isNotEmpty || c.phone.isNotEmpty ? Via.whatsapp : Via.sms),
          ),
      ]),
    );
  }
}

/// The তাগাদা for a customer, from the shop's own message.
String tagadaFor(Brain brain, Customer c, int due) {
  final p = brain.shop.profile;
  return fillTagada(tr(p.tagadaText), name: c.name, due: taka(due), shop: p.name, phone: bnDigits(p.phone));
}

/// Sends the তাগাদা: WhatsApp to their WhatsApp number (owner, 6 Nov), SMS to the mobile.
Future<void> sendTagada(BuildContext context, Customer c, int due, {required Via via}) async {
  final brain = BrainScope.read(context);
  final number = via == Via.whatsapp ? c.whatsappNumber : c.phone;
  if (number.isEmpty) return toast(context, via == Via.whatsapp ? tr('হোয়াটসঅ্যাপ নম্বর রাখা নেই — ✎ চেপে যোগ করুন') : tr('মোবাইল নম্বর রাখা নেই — ✎ চেপে যোগ করুন'));
  await brain.services.launcher.open(via, number, text: tagadaFor(brain, c, due));
  await brain.markTagadaSent(c.id);
}

/// Pick a customer for a sale (or write a new name). Null when closed.
Future<Customer?> pickCustomer(BuildContext context) async {
  final brain = BrainScope.read(context);
  final name = await showAppSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => const _PickCustomer(),
  );
  if (name == null || name.trim().isEmpty) return null;
  if (name.startsWith('id:')) return customerById(brain.shop, name.substring(3));
  if (!context.mounted || !await bizCan(context)) return null;
  return brain.customerFor(name.trim());
}

class _PickCustomer extends StatefulWidget {
  const _PickCustomer();
  @override
  State<_PickCustomer> createState() => _PickCustomerState();
}

class _PickCustomerState extends State<_PickCustomer> {
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
    final list = brain.shop.customers.where((c) => q.isEmpty || c.name.toLowerCase().contains(q.toLowerCase()) || asciiDigits(c.phone).contains(asciiDigits(q))).take(40).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final exact = brain.shop.customers.any((c) => c.name.trim() == q);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(tr('গ্রাহক'), style: display(18, weight: 600)),
        const SizedBox(height: 10),
        TextField(textCapitalization: TextCapitalization.sentences, 
          key: const Key('biz-customer-name'),
          controller: _c,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          style: body(15),
          decoration: InputDecoration(hintText: tr('নাম বা মোবাইল লিখুন'), prefixIcon: const Icon(Icons.search_rounded), isDense: true),
          onSubmitted: (t) => Navigator.pop(context, list.length == 1 ? 'id:${list.single.id}' : t.trim()),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView(shrinkWrap: true, children: [
            if (q.isNotEmpty && !exact)
              ListTile(
                key: const Key('biz-customer-new'),
                leading: Icon(Icons.person_add_alt_outlined, color: C.green),
                title: Text(trf('নতুন গ্রাহক: {0}', [q]), style: body(14.5, color: C.green, weight: FontWeight.w600)),
                onTap: () => Navigator.pop(context, q),
              ),
            for (final c in list)
              ListTile(
                key: Key('biz-pick-${c.id}'),
                leading: Avatar(name: c.name, size: 34),
                title: Text(c.name, style: body(14.5)),
                subtitle: () {
                  final due = customerAccount(brain.shop, c).due;
                  final t = [if (c.phone.isNotEmpty) bnDigits(c.phone), if (due > 0) trf('বাকি {0}', [taka(due)])].join(' · ');
                  return t.isEmpty ? null : Text(t, style: body(12, color: due > 0 ? C.warn : C.muted));
                }(),
                onTap: () => Navigator.pop(context, 'id:${c.id}'),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// A customer's page: what they owe, the reminder, the তাগাদা, their
/// details, and every purchase and payment.
class CustomerPage extends StatelessWidget {
  const CustomerPage({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final c = customerById(brain.shop, id);
    if (c == null) return const Scaffold(body: SizedBox.shrink());
    final now = brain.services.now();
    final a = customerAccount(brain.shop, c);
    final due = a.due;
    final days = a.daysOwed(now);
    final r = c.reminderId == null ? null : brain.reminderById(c.reminderId!);
    final sales = [for (final s in brain.shop.sales) if (s.customerId == c.id) s];
    final pays = [for (final p in brain.shop.collections) if (p.party == c.id) p];
    final bought = sales.fold<int>(0, (s, x) => s + x.total);
    final entries = <(DateTime, Widget)>[
      if (c.opening > 0)
        (
          c.added,
          ListRow(
            key: const Key('biz-cust-opening'),
            leading: DateBlock(top: bnDigits(c.added.day), bottom: monthShort(c.added.month)),
            title: tr('আগের বাকি'),
            subtitle: tr('অ্যাপের আগে থেকে'),
            trailing: Text('+ ${taka(c.opening)}', style: body(14, weight: FontWeight.w600, color: C.warn)),
          )
        ),
      for (final s in sales)
        (
          s.at,
          ListRow(
            key: Key('biz-cust-sale-${s.id}'),
            leading: DateBlock(top: bnDigits(s.at.day), bottom: monthShort(s.at.month)),
            title: s.amountOnly > 0 && s.lines.isEmpty ? (s.pay == SalePay.credit ? tr('বাকি') : tr('বিক্রি')) : s.lines.map((l) => l.name).join(', '),
            subtitle: [tr(s.pay.label), if (s.no > 0) trf('রসিদ #{0}', [bnDigits(s.no)])].join(' · '),
            trailing: Text(s.pay == SalePay.credit ? '+ ${taka(s.total)}' : taka(s.total), style: body(14, weight: FontWeight.w600, color: s.pay == SalePay.credit ? C.warn : C.ink)),
            onTap: () => showReceipt(context, s),
          )
        ),
      for (final p in pays)
        (
          p.at,
          ListRow(
            key: Key('biz-cust-pay-${p.id}'),
            leading: DateBlock(top: bnDigits(p.at.day), bottom: monthShort(p.at.month)),
            title: tr('টাকা পেলাম'),
            subtitle: p.note.isEmpty ? tr('বাকি আদায়') : p.note,
            trailing: Text('− ${taka(p.amount)}', style: body(14, weight: FontWeight.w600, color: C.green)),
            onLongPress: () => _undo(context, p.id),
          )
        ),
    ]..sort((x, y) => y.$1.compareTo(x.$1));

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          InnerTop(
            title: c.name,
            sub: [if (c.phone.isNotEmpty) bnDigits(c.phone), if (c.address.isNotEmpty) c.address].join(' · ').ifEmpty(tr('গ্রাহক')),
            actions: [
              if (c.phone.isNotEmpty) IconButton(tooltip: tr('ফোন করুন'), onPressed: () => brain.services.launcher.open(Via.call, c.phone), icon: const Icon(Icons.call_outlined)),
              IconButton(key: const Key('biz-customer-edit'), tooltip: tr('বদলান'), onPressed: () => pushPage(context, CustomerForm(customer: c)), icon: const Icon(Icons.edit_outlined)),
            ],
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              AppCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (due > 0 && days > 30)
                    Text(trf('• {0} ধরে বাকি', [owedFor(days)]), style: body(11.5, weight: FontWeight.w600, color: C.warn))
                  else if (c.dueDay != null && due > 0)
                    Text(trf('• দেওয়ার কথা {0}', [shortDate(c.dueDay!)]), style: body(11.5, weight: FontWeight.w600, color: C.green)),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(due >= 0 ? tr('মোট বাকি') : tr('অগ্রিম দেওয়া'), style: body(11.5, color: C.muted)),
                        Text(taka(due.abs()), key: const Key('biz-customer-due'), style: display(27, weight: 600, color: due > 0 ? (days > 30 ? C.warn : C.ink) : C.green)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(c.limit > 0 ? trf('বাকির সীমা {0}', [taka(c.limit)]) : tr('সীমা নেই'), style: body(12, color: C.muted)),
                      if (c.limit > 0 && due > 0) Text(trf('{0}% ব্যবহার হয়েছে', [bnDigits((due * 100 / c.limit).round())]), style: body(11.5, color: due > c.limit ? C.warn : C.muted)),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: SmallButton(
                        key: const Key('biz-customer-paid'),
                        label: tr('টাকা পেলাম'),
                        icon: Icons.check_rounded,
                        primary: true,
                        onTap: () async {
                          if (!await bizCan(context) || !context.mounted) return;
                          final v = await askText(context, tr('কত টাকা পেলেন?'), initial: due > 0 ? bnDigits(due) : '', number: true);
                          final n = v == null ? null : readNum(v);
                          if (n == null || n <= 0) return;
                          await brain.customerPaid(c.id, n.round());
                          if (context.mounted) toast(context, trf('{0} পাওয়া গেল — আয়-ব্যয়ে “বাকি আদায়” লেখা হলো', [taka(n.round())]));
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: SmallButton(key: const Key('biz-customer-credit'), label: tr('বাকিতে বিক্রি'), icon: Icons.add_shopping_cart_rounded, onTap: () => pushPage(context, SellPage(customerId: c.id)))),
                  ]),
                ]),
              ),
              SectionHeading(tr('বাকির রিমাইন্ডার')),
              _ReminderCard(c: c, r: r, due: due),
              if (due > 0) ...[
                SectionHeading(tr('তাগাদা'), counter: c.lastSent == null ? null : trf('শেষ পাঠানো {0}', [shortDate(c.lastSent!)]), link: tr('মেসেজ বদলান'), linkKey: const Key('biz-tagada-edit'), onLink: () => pushPage(context, const TagadaPage())),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12)),
                      child: Text(tagadaFor(brain, c, due), key: const Key('biz-tagada-text'), style: body(13.5, height: 1.55)),
                    ),
                    CardFoot(
                      left: tr('হোয়াটসঅ্যাপে'),
                      leftKey: const Key('biz-tagada-wa'),
                      onLeft: () => sendTagada(context, c, due, via: Via.whatsapp),
                      right: tr('SMS পাঠান'),
                      rightKey: const Key('biz-tagada-sms'),
                      onRight: () => sendTagada(context, c, due, via: Via.sms),
                    ),
                  ]),
                ),
              ],
              SectionHeading(tr('বিস্তারিত')),
              detailRows([
                (Icons.phone_outlined, tr('মোবাইল'), bnDigits(c.phone)),
                (Icons.chat_outlined, tr('হোয়াটসঅ্যাপ'), bnDigits(c.whatsapp.isNotEmpty ? c.whatsapp : (c.phone.isNotEmpty ? trf('{0} (মোবাইলই)', [c.phone]) : ''))),
                (Icons.place_outlined, tr('ঠিকানা'), c.address),
                (Icons.sticky_note_2_outlined, tr('নোট'), c.note),
                (Icons.shopping_bag_outlined, tr('মোট কেনা'), sales.isEmpty ? '' : trf('{0} · {1}টি রসিদ', [taka(bought), bnDigits(sales.length)])),
                (Icons.event_outlined, tr('গ্রাহক যেদিন থেকে'), c.added.year == 2000 ? '' : shortDate(c.added)),
              ]),
              SectionHeading(tr('কেনাকাটা ও লেনদেন'), counter: trf('{0}টি', [bnDigits(entries.length)])),
              ListCard(rows: [for (final e in entries) e.$2], empty: tr('এখনো কোনো কেনাকাটা নেই।')),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  key: const Key('biz-customer-old-due'),
                  onPressed: () async {
                    if (!await bizCan(context) || !context.mounted) return;
                    final v = await askText(context, tr('আগের কত টাকা বাকি আছে?'), number: true);
                    final n = v == null ? null : readNum(v);
                    if (n != null && n > 0) await brain.customerOwes(c.id, n.round());
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(tr('আগের বাকি লিখে রাখুন')),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _undo(BuildContext context, String entryId) async {
    final ok = await confirmDialog(context, title: tr('এই টাকা পাওয়াটা মুছবেন?'), text: tr('বাকি আবার আগের মতো হবে, আয়-ব্যয় থেকেও মুছে যাবে।'), yes: tr('মুছুন'), danger: true);
    if (ok && context.mounted) await BrainScope.read(context).undoShopEntry(entryId);
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// The reminder to collect: when it rings, or a button to set one.
class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.c, required this.r, required this.due});
  final Customer c;
  final Reminder? r;
  final int due;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final r = this.r;
    if (r == null) {
      return AppCard(
        key: const Key('biz-reminder-set'),
        onTap: () => setCollectReminder(context, c),
        child: Row(children: [
          const IconTile(Icons.alarm_add_outlined),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('বাকি আদায়ের রিমাইন্ডার দিন'), style: body(14.5, weight: FontWeight.w600)),
              Text(tr('যেদিন টাকা দেওয়ার কথা, সেদিন মনে করিয়ে দেবে — যেকোনো মোডে'), style: body(12, color: C.muted)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: C.muted),
        ]),
      );
    }
    return AppCard(
      key: const Key('biz-reminder-on'),
      child: Row(children: [
        const IconTile(Icons.alarm_on_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${shortDate(r.date)} · ${bnTime(r.hour, r.minute)}', style: body(14.5, weight: FontWeight.w600)),
            Text(r.repeat == Repeat.weekly ? tr('প্রতি সপ্তাহে, টাকা পাওয়া পর্যন্ত') : tr('একবার — পুরো টাকা পেলে নিজেই বন্ধ হবে'), style: body(12, color: C.muted)),
          ]),
        ),
        IconButton(tooltip: tr('বদলান'), onPressed: () => setCollectReminder(context, c), icon: const Icon(Icons.edit_outlined)),
        IconButton(
          key: const Key('biz-reminder-off'),
          tooltip: tr('বন্ধ করুন'),
          onPressed: () async {
            await brain.clearCollectReminder(c.id);
            if (context.mounted) toast(context, tr('রিমাইন্ডার বন্ধ করা হলো'));
          },
          icon: Icon(Icons.alarm_off_outlined, color: C.red),
        ),
      ]),
    );
  }
}

/// Set (or change) the reminder to collect from [c]: the day, the time,
/// once or every week.
Future<void> setCollectReminder(BuildContext context, Customer c) async {
  if (!await bizCan(context) || !context.mounted) return;
  final brain = BrainScope.read(context);
  final now = brain.services.now();
  final old = c.reminderId == null ? null : brain.reminderById(c.reminderId!);
  final picked = await showAppSheet<(DateTime, Repeat)>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _ReminderSheet(start: old == null ? DateTime(now.year, now.month, now.day + 7, 10) : DateTime(old.date.year, old.date.month, old.date.day, old.hour, old.minute), weekly: old?.repeat == Repeat.weekly),
  );
  if (picked == null || !context.mounted) return;
  final ok = await brain.setCollectReminder(c.id, picked.$1, repeat: picked.$2);
  if (!context.mounted) return;
  toast(context, ok ? trf('রিমাইন্ডার রাখা হলো — {0}, {1}', [shortDate(picked.$1), bnTime(picked.$1.hour, picked.$1.minute)]) : tr('ফ্রিতে একসাথে ২০টা রিমাইন্ডার রাখা যায়, সেটা পূর্ণ। পুরোনো কোনোটা বন্ধ করুন, বা প্রিমিয়াম নিন।'));
}

class _ReminderSheet extends StatefulWidget {
  const _ReminderSheet({required this.start, required this.weekly});
  final DateTime start;
  final bool weekly;
  @override
  State<_ReminderSheet> createState() => _ReminderSheetState();
}

class _ReminderSheetState extends State<_ReminderSheet> {
  late DateTime _at = widget.start;
  late bool _weekly = widget.weekly;

  @override
  Widget build(BuildContext context) {
    final now = BrainScope.of(context).services.now();
    final quick = [(tr('কাল'), 1), (tr('৩ দিন পর'), 3), (tr('১ সপ্তাহ পর'), 7), (tr('মাস শেষে'), DateTime(now.year, now.month + 1, 0).difference(DateTime(now.year, now.month, now.day)).inDays)];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('বাকি আদায়ের রিমাইন্ডার'), style: display(18, weight: 600)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (label, d) in quick)
              ChoiceChip(
                label: Text(label),
                selected: DateUtils.isSameDay(_at, DateTime(now.year, now.month, now.day + d)),
                onSelected: (_) => setState(() => _at = DateTime(now.year, now.month, now.day + d, _at.hour, _at.minute)),
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('biz-reminder-day'),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: _at.isBefore(now) ? now : _at, firstDate: DateTime(now.year, now.month, now.day), lastDate: now.add(const Duration(days: 730)));
                  if (d != null) setState(() => _at = DateTime(d.year, d.month, d.day, _at.hour, _at.minute));
                },
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(shortDate(_at)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('biz-reminder-time'),
                onPressed: () async {
                  final m = await askTime(context, _at.hour * 60 + _at.minute);
                  if (m != null) setState(() => _at = DateTime(_at.year, _at.month, _at.day, m ~/ 60, m % 60));
                },
                icon: const Icon(Icons.schedule_rounded, size: 18),
                label: Text(bnTime(_at.hour, _at.minute)),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          SwitchListTile(
            key: const Key('biz-reminder-weekly'),
            contentPadding: EdgeInsets.zero,
            value: _weekly,
            onChanged: (v) => setState(() => _weekly = v),
            title: Text(tr('প্রতি সপ্তাহে আবার মনে করাবে'), style: body(14)),
            subtitle: Text(tr('পুরো টাকা পাওয়া পর্যন্ত'), style: body(12, color: C.muted)),
          ),
          const SizedBox(height: 6),
          PrimaryButton(key: const Key('biz-reminder-save'), label: tr('রিমাইন্ডার রাখুন'), icon: Icons.alarm_on_outlined, onPressed: () => Navigator.pop(context, (_at, _weekly ? Repeat.weekly : Repeat.none))),
        ]),
      ),
    );
  }
}

/// নতুন গ্রাহক / গ্রাহকের তথ্য বদলান.
class CustomerForm extends StatefulWidget {
  const CustomerForm({super.key, this.customer});
  final Customer? customer;
  @override
  State<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerForm> {
  late final Customer? _c = widget.customer;
  late final _name = TextEditingController(text: _c?.name ?? '');
  late final _phone = TextEditingController(text: _c == null ? '' : bnDigits(_c.phone));
  late final _wa = TextEditingController(text: _c == null ? '' : bnDigits(_c.whatsapp));
  late final _address = TextEditingController(text: _c?.address ?? '');
  late final _note = TextEditingController(text: _c?.note ?? '');
  late final _limit = TextEditingController(text: _c == null || _c.limit == 0 ? '' : bnDigits(_c.limit));
  final _opening = TextEditingController();
  late bool _sameWa = _c == null || _c.whatsapp.isEmpty;

  @override
  void dispose() {
    for (final c in [_name, _phone, _wa, _address, _note, _limit, _opening]) {
      c.dispose();
    }
    super.dispose();
  }

  String _num(String s) => asciiDigits(s).replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    final name = _name.text.trim();
    if (name.isEmpty) return toast(context, tr('গ্রাহকের নাম লিখুন'));
    if (!await bizCan(context) || !mounted) return;
    final base = _c ?? Customer(name: name);
    final kept = await brain.saveCustomer(base.copyWith(
      name: name,
      phone: _num(_phone.text),
      whatsapp: _sameWa ? '' : _num(_wa.text),
      address: _address.text.trim(),
      note: _note.text.trim(),
      limit: (readNum(_limit.text) ?? 0).round(),
    ));
    final opening = (readNum(_opening.text) ?? 0).round();
    if (_c == null && opening > 0) await brain.customerOwes(kept.id, opening, note: tr('আগের বাকি'));
    if (!mounted) return;
    Navigator.of(context).pop();
    if (_c == null) pushPage(context, CustomerPage(id: kept.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          InnerTop(
            title: _c == null ? tr('নতুন গ্রাহক') : tr('গ্রাহকের তথ্য'),
            actions: [
              if (_c != null)
                IconButton(
                  key: const Key('biz-customer-delete'),
                  tooltip: tr('মুছুন'),
                  onPressed: () async {
                    final ok = await confirmDialog(context, title: trf('‘{0}’ মুছবেন?', [_c.name]), text: tr('তাঁর বিক্রির রসিদ থেকে যাবে। মুছে ফেলা থেকে ৩০ দিন ফেরানো যায়।'), yes: tr('মুছুন'), danger: true);
                    if (!ok || !context.mounted) return;
                    await BrainScope.read(context).deleteCustomer(_c.id);
                    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                  icon: Icon(Icons.delete_outline_rounded, color: C.red),
                ),
            ],
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              LabeledField(controller: _name, label: tr('নাম'), hint: tr('যেমন: রহিম মিয়া'), fieldKey: const Key('biz-cf-name'), icon: Icons.person_outline_rounded),
              LabeledField(controller: _phone, label: tr('মোবাইল নম্বর'), hint: '01XXXXXXXXX', keyboard: TextInputType.phone, fieldKey: const Key('biz-cf-phone'), icon: Icons.phone_outlined),
              CheckboxListTile(
                key: const Key('biz-cf-same-wa'),
                value: _sameWa,
                onChanged: (v) => setState(() => _sameWa = v ?? true),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: Text(tr('এই নম্বরেই হোয়াটসঅ্যাপ'), style: body(14)),
                subtitle: Text(tr('তাগাদা আর রসিদ হোয়াটসঅ্যাপে এই নম্বরে যাবে'), style: body(11.5, color: C.muted)),
              ),
              if (!_sameWa) LabeledField(controller: _wa, label: tr('হোয়াটসঅ্যাপ নম্বর'), hint: '01XXXXXXXXX', keyboard: TextInputType.phone, fieldKey: const Key('biz-cf-wa'), icon: Icons.chat_outlined),
              LabeledField(controller: _address, label: tr('ঠিকানা'), hint: tr('যেমন: বাজার রোড, বাড়ি ১২'), fieldKey: const Key('biz-cf-address'), icon: Icons.place_outlined),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                childAspectRatio: 2.1,
                children: [
                  NumField(controller: _limit, label: tr('বাকির সীমা'), hint: tr('৳ (ইচ্ছামতো)'), fieldKey: const Key('biz-cf-limit')),
                  if (_c == null) NumField(controller: _opening, label: tr('আগের বাকি'), hint: '৳', fieldKey: const Key('biz-cf-opening')),
                ],
              ),
              LabeledField(controller: _note, label: tr('নোট'), hint: tr('যেমন: মাসের ৫ তারিখে বেতন পান'), lines: 2, fieldKey: const Key('biz-cf-note')),
            ]),
          ),
          PageFoot(child: PrimaryButton(key: const Key('biz-cf-save'), label: tr('গ্রাহক রাখুন'), icon: Icons.check_rounded, onPressed: _save)),
        ]),
      ),
    );
  }
}
