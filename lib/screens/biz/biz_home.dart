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
import 'biz_hisab.dart';
import 'biz_parts.dart';
import 'biz_sales.dart';
import 'biz_stock.dart';

/// The home in business mode (owner, 6 Nov — the "দোকানি" handoff): My
/// Assistant's home, part for part, with the shop's own in the middle —
/// what is running out, whose due is today, today's sales and the cash box.
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
              if (low.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
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
              const TodaySections(),
              const _ShopMoney(),
              const HomeHolidays(),
              const SizedBox(height: 14),
              const _ShopTools(),
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
  'দিনের হিসাব দিনেই মেলান — কাল আর মনে থাকে না।',
  'ছোট লাভে বেশি বিক্রি, বড় লাভে কম ক্রেতা।',
  'মেয়াদ শেষের আগে কম দামে বিক্রি — ফেলে দেওয়ার চেয়ে ভালো।',
  'হাসিমুখের ক্রেতা আবার ফিরে আসে।',
];

/// "এরপর · বাকি আদায়": the buyer whose pay day is today (else the one who
/// owes most), with call, paid and তাগাদা.
class _NextDue extends StatelessWidget {
  const _NextDue();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final get = owing(brain.data);
    if (get.isEmpty) return const SizedBox.shrink();
    final today = dayOnly(now);
    final due = get.where((p) {
      final b = buyerOf(brain.shop, p.name);
      return b.dueDay != null && !dayOnly(b.dueDay!).isAfter(today);
    }).firstOrNull;
    final p = due ?? get.first;
    final b = buyerOf(brain.shop, p.name);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading(tr('বাকি আদায়'), link: trf('{0} জন · সব', [bnDigits(get.length)]), onLink: () => goToTab(context, ShellTab.money)),
      AppCard(
        key: const Key('biz-home-next'),
        onTap: () => pushPage(context, BuyerPage(name: p.name)),
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
                Text(trf('{0}-এর বাকি', [p.name]), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(16, weight: FontWeight.w600)),
                if (p.last != null) Text(trf('শেষ লেনদেন {0}', [shortDate(p.last!)]), style: body(12, color: C.muted)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(taka(p.balance), style: display(22, weight: 600, color: C.green)),
              if (b.limit > 0) Text(trf('সীমা {0}', [taka(b.limit)]), style: body(11, color: C.muted)),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: SmallButton(label: tr('ফোন'), icon: Icons.call_outlined, primary: true, onTap: () => p.phone.isEmpty ? toast(context, tr('নম্বর রাখা নেই')) : brain.services.launcher.open(Via.call, p.phone))),
            const SizedBox(width: 8),
            Expanded(
              child: SmallButton(
                key: const Key('biz-home-paid'),
                label: tr('পেলাম'),
                icon: Icons.check_rounded,
                onTap: () => pushPage(context, BuyerPage(name: p.name)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: SmallButton(label: tr('তাগাদা'), icon: Icons.sms_outlined, onTap: () => brain.services.launcher.open(Via.sms, p.phone, text: tagadaText(p.name, p.balance)))),
          ]),
        ]),
      ),
    ]);
  }
}

/// দোকানের হিসাব: the cash box, today's sales, cost and rough profit, who
/// owes and whom to pay, and how today was paid.
class _ShopMoney extends StatelessWidget {
  const _ShopMoney();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final today = DaySum(salesOn(brain.shop, now));
    final box = cashBox(brain.data, now);
    final get = owing(brain.data), give = owed(brain.data);
    final (cash, qr, credit) = today.split;
    Widget stat(IconData icon, String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 14, color: C.muted), const SizedBox(width: 4), Text(label, style: body(11.5, color: C.muted))]),
          const SizedBox(height: 4),
          Text(value, style: body(14, weight: FontWeight.w600, color: color)),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading(tr('দোকানের হিসাব'), link: tr('আজ · খুলুন'), onLink: () => goToTab(context, ShellTab.money)),
      AppCard(
        key: const Key('biz-home-money'),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('ক্যাশ বাক্সে আছে'), style: body(11.5, color: C.muted)),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: RollingAmount(value: box.expected, format: taka, style: display(27, weight: 600, height: 1.45))),
              ]),
            ),
            const IconTile(Icons.account_balance_wallet_outlined),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 26, runSpacing: 10, children: [
            stat(Icons.south_rounded, tr('আজ বিক্রি'), taka(today.total), C.green),
            stat(Icons.north_rounded, tr('খরচ'), taka(box.costs), C.ink),
            stat(Icons.trending_up_rounded, tr('লাভ (আনুমানিক)'), taka(today.profit), C.ink),
          ]),
          const SizedBox(height: 12),
          const Hairline(),
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: InkWell(
                  onTap: () => goToTab(context, ShellTab.money),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(trf('পাবো · {0} জনের কাছে', [bnDigits(get.length)]), style: body(11.5, color: C.muted)),
                      Text(taka(get.fold(0, (s, p) => s + p.balance)), style: body(14.5, weight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ),
              Container(width: 1, color: C.border, margin: const EdgeInsets.symmetric(horizontal: 12)),
              Expanded(
                child: InkWell(
                  onTap: () => goToTab(context, ShellTab.money),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(trf('দেবো · {0} জনকে', [bnDigits(give.length)]), style: body(11.5, color: C.muted)),
                      Text(taka(give.fold(0, (s, p) => s - p.balance)), style: body(14.5, weight: FontWeight.w600, color: give.isEmpty ? C.ink : C.warn)),
                    ]),
                  ),
                ),
              ),
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
                  child: Text(today.total == 0 ? tr('আজ এখনো বিক্রি হয়নি') : trf('আজ নগদ {0}% · QR {1}% · বাকি {2}%', [bnDigits(cash), bnDigits(qr), bnDigits(credit)]),
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

/// সব সুবিধা · দোকানের.
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
      (tr('পণ্যের তালিকা'), Icons.inventory_2_outlined, () => goToTab(context, ShellTab.store)),
      (tr('নতুন পণ্য'), Icons.add_box_outlined, () => pushPage(context, const ProductForm())),
      (tr('মাল কেনা'), Icons.local_shipping_outlined, () => pushPage(context, const PurchasePage())),
      (tr('বাকি খাতা'), Icons.menu_book_outlined, () => hisab('baki')),
      (tr('খরচ'), Icons.receipt_outlined, () => addShopCost(context)),
      (tr('দিন বন্ধ'), Icons.lock_clock_outlined, () => hisab('close')),
      (tr('আয়-ব্যয়'), Icons.account_balance_wallet_outlined, () => hisab('money')),
      (tr('রসিদ'), Icons.receipt_long_outlined, () => goToTab(context, ShellTab.diary)),
      (tr('শুধু টাকা'), Icons.payments_outlined, () => pushPage(context, const SellPage(amountOnly: true))),
      (tr('বলে বিক্রি'), Icons.mic_none_rounded, () => openVoice(context)),
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
