import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../logic/bn.dart';
import '../../logic/lang.dart';
import '../../logic/shop_logic.dart';
import '../../models/models.dart' show Via;
import '../../state/brain.dart';
import '../../ui/kit.dart';
import '../../ui/motion.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../home_page.dart' show HomeHero, HomeHolidays;
import '../home_screen.dart' show TodaySections;
import '../home_shell.dart';
import '../pro_screen.dart';
import 'biz_customers.dart';
import 'biz_hisab.dart';
import 'biz_parts.dart';
import 'biz_sales.dart';
import 'biz_shop.dart';
import 'biz_stock.dart';

/// The home in business mode (owner, 6 Nov — the "দোকানি" handoff): My
/// Assistant's home, part for part, with the shop at a glance on top (owner,
/// 6 Nov: "হোমে সব এক নজরে দেখবে") — today's sales and cash, who owes and
/// whom to pay, dues older than 30 days, what is running out, whose due is
/// today.
class BizHome extends StatelessWidget {
  const BizHome({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final b = brain.shop;
    final low = lowStock(b);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: C.ground, systemNavigationBarIconBrightness: C.dark ? Brightness.light : Brightness.dark),
      child: ColoredBox(
        color: C.ground,
        child: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
          const HomeHero(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const BizFreeBanner(),
              const _ShopMoney(),
              const _LongOwing(),
              if (low.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: AttentionCard(
                    key: const Key('biz-home-low'),
                    icon: Icons.inventory_2_outlined,
                    title: trf('{0}টা পণ্য প্রায় শেষ', [bnDigits(low.length)]),
                    text: low.take(3).map((p) => p.name).join(', '),
                    action: tr('অর্ডার দিন'),
                    onAction: () => pushPage(context, const PurchasePage()),
                  ),
                ),
              const _NextDue(),
              const SizedBox(height: 14),
              const _ShopTools(),
              const TodaySections(),
              const HomeHolidays(),
              const SizedBox(height: 12),
              AppCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.format_quote_rounded, size: 20, color: C.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr(_quotes[now.difference(DateTime(2026)).inDays % _quotes.length]), style: body(13.5, height: 1.6)),
                      const SizedBox(height: 2),
                      Text(tr('আজকের ব্যবসা-কথা'), style: body(11.5, color: C.muted)),
                    ]),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.lock_outline_rounded, size: 14, color: C.muted),
                  const SizedBox(width: 5),
                  Flexible(child: Text(tr('আপনার হিসাব এই ফোনেই থাকে, তালাবদ্ধ'), style: body(11.5, color: C.muted))),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

const _quotes = [
  'বাকি কম, হিসাব পরিষ্কার — দোকান টেকে বহুদিন।',
  'যে পণ্য বেশি চলে, সেটা কখনো শেষ হতে দেবেন না।',
  'দিনের হিসাব দিনেই লিখুন — কাল আর মনে থাকে না।',
  'ছোট লাভে বেশি বিক্রি, বড় লাভে কম ক্রেতা।',
  'মেয়াদ শেষের আগে কম দামে বিক্রি — ফেলে দেওয়ার চেয়ে ভালো।',
  'হাসিমুখের ক্রেতা আবার ফিরে আসে।',
];

/// Dues older than 30 days (owner, 6 Nov: "বাকি ৩০ দিনের বেশি হলে হোমে দেখাবে").
class _LongOwing extends StatelessWidget {
  const _LongOwing();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final list = longOwing(brain.shop, now);
    if (list.isEmpty) return const SizedBox.shrink();
    final sum = list.fold<int>(0, (s, a) => s + a.due);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading(tr('৩০ দিনের বেশি বাকি'), counter: trf('{0} জন · {1}', [bnDigits(list.length), taka(sum)]), link: list.length > 3 ? tr('সব') : null, onLink: () => goToTab(context, ShellTab.people)),
      Container(
        key: const Key('biz-home-long'),
        decoration: BoxDecoration(color: C.warnBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.warnBorder)),
        child: Column(children: [
          for (final (i, a) in list.take(3).indexed) ...[
            if (i > 0) Divider(height: 1, color: C.warnBorder, indent: 14, endIndent: 14),
            ListRow(
              leading: Avatar(name: a.name, size: 36, fg: C.warn, bg: C.surface),
              title: a.name,
              subtitle: trf('{0} ধরে বাকি · {1} থেকে', [owedFor(a.daysOwed(now)), shortDate(a.since!)]),
              subtitleColor: C.warn,
              trailing: Text(taka(a.due), style: body(14.5, weight: FontWeight.w600, color: C.warn)),
              onTap: () => pushPage(context, CustomerPage(id: a.id)),
            ),
          ],
        ]),
      ),
    ]);
  }
}

/// "এরপর · বাকি আদায়": the customer whose pay day is today (else the one
/// who owes most), with call, paid and তাগাদা.
class _NextDue extends StatelessWidget {
  const _NextDue();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final b = brain.shop;
    final get = owing(b);
    if (get.isEmpty) return const SizedBox.shrink();
    final today = dayOnly(now);
    final due = get.where((a) {
      final c = customerById(b, a.id);
      return c?.dueDay != null && !dayOnly(c!.dueDay!).isAfter(today);
    }).firstOrNull;
    final a = due ?? get.first;
    final c = customerById(b, a.id)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading(tr('বাকি আদায়'), link: trf('{0} জন · সব', [bnDigits(get.length)]), onLink: () => goToTab(context, ShellTab.people)),
      AppCard(
        key: const Key('biz-home-next'),
        onTap: () => pushPage(context, CustomerPage(id: c.id)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 5, height: 5, decoration: BoxDecoration(color: due != null ? C.warn : C.green, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(due != null ? tr('এরপর · বাকি আদায়ের দিন আজ') : tr('এরপর · সবচেয়ে বেশি বাকি'), style: body(11.5, weight: FontWeight.w600, color: due != null ? C.warn : C.green)),
          ]),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trf('{0}-এর বাকি', [c.name]), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(16, weight: FontWeight.w600)),
                if (a.since != null) Text(trf('{0} থেকে বাকি', [shortDate(a.since!)]), style: body(12, color: C.muted)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(taka(a.due), style: display(22, weight: 600, color: C.green)),
              if (c.limit > 0) Text(trf('সীমা {0}', [taka(c.limit)]), style: body(11, color: C.muted)),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: SmallButton(label: tr('ফোন'), icon: Icons.call_outlined, primary: true, onTap: () => c.phone.isEmpty ? toast(context, tr('নম্বর রাখা নেই')) : brain.services.launcher.open(Via.call, c.phone))),
            const SizedBox(width: 8),
            Expanded(child: SmallButton(key: const Key('biz-home-paid'), label: tr('পেলাম'), icon: Icons.check_rounded, onTap: () => pushPage(context, CustomerPage(id: c.id)))),
            const SizedBox(width: 8),
            Expanded(child: SmallButton(label: tr('তাগাদা'), icon: Icons.chat_outlined, onTap: () => sendTagada(context, c, a.due, via: c.whatsappNumber.isNotEmpty ? Via.whatsapp : Via.sms))),
          ]),
        ]),
      ),
    ]);
  }
}

/// আজ এক নজরে: today's sales, the cash that came in, rough profit, who owes
/// the shop and what the shop owes its dealers, and how today was paid.
class _ShopMoney extends StatelessWidget {
  const _ShopMoney();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final today = DaySum(salesOn(brain.shop, now));
    final cash = todayCash(brain.data, now);
    final get = owing(brain.shop), give = owedToDealers(brain.shop);
    final (cashPct, qr, credit) = today.split;
    Widget stat(IconData icon, String label, String value, Color color, {Key? key}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 14, color: C.muted), const SizedBox(width: 4), Text(label, style: body(11.5, color: C.muted))]),
          const SizedBox(height: 4),
          Text(value, key: key, style: body(14, weight: FontWeight.w600, color: color)),
        ]);
    Widget half(String label, int amount, Color color, VoidCallback onTap, Key key) => Expanded(
          child: InkWell(
            key: key,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: body(11.5, color: C.muted)),
                Text(taka(amount), style: body(14.5, weight: FontWeight.w600, color: color)),
              ]),
            ),
          ),
        );
    void dealers() {
      goToTab(context, ShellTab.money);
      WidgetsBinding.instance.addPostFrameCallback((_) => bizHisabKey.currentState?.show('dealers'));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading(tr('আজ এক নজরে'), link: tr('বিক্রি দেখুন'), onLink: () => goToTab(context, ShellTab.diary)),
      AppCard(
        key: const Key('biz-home-money'),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(trf('আজ বিক্রি · {0}টি', [bnDigits(today.count)]), style: body(11.5, color: C.muted)),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: RollingAmount(value: today.total, format: taka, style: display(27, weight: 600, height: 1.45))),
              ]),
            ),
            IconButton.filled(key: const Key('biz-home-sell'), tooltip: tr('নতুন বিক্রি'), onPressed: () => pushPage(context, const SellPage()), icon: Icon(Icons.add_shopping_cart_rounded, color: C.onAccent)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 26, runSpacing: 10, children: [
            stat(Icons.payments_outlined, tr('আজ হাতে এল'), '${cash.net < 0 ? '− ' : ''}${taka(cash.net.abs())}', cash.net < 0 ? C.warn : C.green, key: const Key('biz-home-cash')),
            stat(Icons.trending_up_rounded, tr('লাভ (আনুমানিক)'), taka(today.profit), C.ink),
            stat(Icons.north_rounded, tr('আজ বের হলো'), taka(cash.out), C.ink),
          ]),
          const SizedBox(height: 12),
          const Hairline(),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              half(trf('পাবো · {0} জন গ্রাহক', [bnDigits(get.length)]), get.fold(0, (s, a) => s + a.due), C.green, () => goToTab(context, ShellTab.people), const Key('biz-home-get')),
              Container(width: 1, color: C.border, margin: const EdgeInsets.symmetric(horizontal: 12)),
              half(trf('দেবো · {0} জন ডিলার', [bnDigits(give.length)]), give.fold(0, (s, a) => s + a.due), give.isEmpty ? C.ink : C.warn, dealers, const Key('biz-home-give')),
            ]),
          ),
          const Hairline(),
          InkWell(
            onTap: () => goToTab(context, ShellTab.diary),
            child: SizedBox(
              height: 44,
              child: Row(children: [
                Icon(Icons.pie_chart_outline_rounded, size: 17, color: C.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(today.total == 0 ? tr('আজ এখনো বিক্রি হয়নি') : trf('আজ নগদ {0}% · QR {1}% · বাকি {2}%', [bnDigits(cashPct), bnDigits(qr), bnDigits(credit)]),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted2)),
                ),
                Icon(Icons.chevron_right_rounded, color: C.muted),
              ]),
            ),
          ),
        ]),
      ),
    ]);
  }
}

/// সব সুবিধা · দোকানের, in the order the day goes: sell, customers, money, stock.
class _ShopTools extends StatelessWidget {
  const _ShopTools();

  @override
  Widget build(BuildContext context) {
    void hisab(String part) {
      goToTab(context, ShellTab.money);
      WidgetsBinding.instance.addPostFrameCallback((_) => bizHisabKey.currentState?.show(part));
    }

    final tools = <(String, IconData, VoidCallback)>[
      (tr('বিক্রি'), Icons.add_shopping_cart_rounded, () => pushPage(context, const SellPage())),
      (tr('শুধু টাকা'), Icons.payments_outlined, () => pushPage(context, const SellPage(amountOnly: true))),
      (tr('নতুন গ্রাহক'), Icons.person_add_alt_outlined, () => pushPage(context, const CustomerForm())),
      (tr('গ্রাহক'), Icons.people_outline_rounded, () => goToTab(context, ShellTab.people)),
      (tr('খরচ'), Icons.receipt_outlined, () => addShopCost(context)),
      (tr('আয়-ব্যয়'), Icons.account_balance_wallet_outlined, () => hisab('money')),
      (tr('মাল কেনা'), Icons.local_shipping_outlined, () => pushPage(context, const PurchasePage(part: 'in'))),
      (tr('ডিলার'), Icons.storefront_outlined, () => hisab('dealers')),
      (tr('নতুন পণ্য'), Icons.add_box_outlined, () => pushPage(context, const ProductForm())),
      (tr('স্টক'), Icons.inventory_2_outlined, () => goToTab(context, ShellTab.store)),
      (tr('দোকানের তথ্য'), Icons.badge_outlined, () => pushPage(context, const ShopProfilePage())),
      (tr('প্রিমিয়াম'), Icons.workspace_premium_outlined, () => pushPage(context, const ProScreen())),
    ];
    return AppCard(
      key: const Key('biz-home-tools'),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(children: [
        SizedBox(
          height: 50,
          child: Row(children: [
            Text(tr('সব সুবিধা'), style: body(14, weight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text(trf('{0}টা', [bnDigits(tools.length)]), style: body(12, color: C.muted)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.92,
            children: [for (final (label, icon, on) in tools) ToolTile(icon: icon, label: label, onTap: on)],
          ),
        ),
      ]),
    );
  }
}

/// The business হিসাব tab, so a home shortcut can open one of its parts.
final bizHisabKey = GlobalKey<BizHisabState>();
