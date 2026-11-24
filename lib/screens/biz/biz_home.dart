import 'package:flutter/material.dart';
import '../../logic/app_stats.dart';
import 'package:flutter/services.dart';

import '../../logic/biz_account.dart';
import '../../logic/bn.dart';
import '../../logic/lang.dart';
import '../../logic/shop_logic.dart';
import '../../models/models.dart';
import '../../state/brain.dart';
import '../../ui/kit.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import '../home_shell.dart';
import 'biz_account_page.dart';
import 'biz_customers.dart';
import 'biz_money.dart';
import 'biz_parts.dart';
import 'biz_sales.dart';
import 'biz_setup.dart';
import 'biz_shop.dart' show ShopProfilePage;
import 'biz_stock.dart';
import 'biz_tx.dart';

/// The home in ব্যবসায়ী মোড (owner, 23 Nov, the design picked that day):
/// no pictures — the business first. Today's cash on top (tap: the whole
/// account, since the start), what needs a look today, the four buttons
/// just below the middle of the screen where the thumb is, this month, the
/// whole position down to the capital, the chart, the latest entries, who
/// owes most and what is running out.
class BizHome extends StatefulWidget {
  const BizHome({super.key});
  @override
  State<BizHome> createState() => _BizHomeState();
}

class _BizHomeState extends State<BizHome> {
  static bool _asked = false;

  @override
  void initState() {
    super.initState();
    // The first questions, the first time (owner, 23 Nov).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _asked) return;
      if (BrainScope.read(context).shop.start == null) {
        _asked = true;
        pushPage(context, const BizSetupPage());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    AppStats.open('business');
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final b = brain.shop;
    return BizRefresh(child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: (C.dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(statusBarColor: Colors.transparent, systemNavigationBarColor: C.ground),
      child: ColoredBox(
        color: C.ground,
        child: SafeArea(
          bottom: false,
          child: ListView(physics: const AlwaysScrollableScrollPhysics(), key: const PageStorageKey('biz-home'), padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
            _Top(name: b.profile.name, now: now),
            const BizFreeBanner(),
            const SizedBox(height: 6),
            const _Today(),
            const _Attention(),
            const SizedBox(height: 18),
            const BizQuickButtons(),
            const _Month(),
            const _Position(),
            const _Chart(),
            const _Recent(),
            const _TopDues(),
            const _LowStock(),
          ]),
        ),
      ),
    ));
  }
}

/// A small heading with a link on the right.
class _Head extends StatelessWidget {
  const _Head(this.title, {this.count, this.link, this.onLink});
  final String title;
  final String? count;
  final String? link;
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Text(title, style: body(14.5, weight: FontWeight.w600)),
          if (count != null) ...[const SizedBox(width: 6), Text(count!, style: body(12, color: C.muted))],
          const Spacer(),
          if (link != null)
            InkWell(
              onTap: onLink,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('${link!} ›', style: body(13, weight: FontWeight.w600, color: C.green))),
            ),
        ]),
      );
}

/// The shop's name and today; the switch to the personal app.
class _Top extends StatelessWidget {
  const _Top({required this.name, required this.now});
  final String name;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
      child: Row(children: [
        InkWell(
          onTap: () => pushPage(context, const ShopProfilePage()),
          borderRadius: BorderRadius.circular(12),
          child: Container(width: 42, height: 42, decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.storefront_rounded, color: C.onAccent)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name.isEmpty ? tr('আমার দোকান') : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(17.5, weight: 700, height: 1.25)),
            Text('${weekdayName(now)}, ${shortDate(now)}', style: body(12.5, color: C.muted)),
          ]),
        ),
        // Owner, 22 Nov: back to the personal app from the home itself.
        Material(
          color: C.surface,
          shape: StadiumBorder(side: BorderSide(color: C.border)),
          child: InkWell(
            key: const Key('biz-to-personal'),
            customBorder: const StadiumBorder(),
            onTap: () => brain.setPref('business_mode', false),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.swap_horiz_rounded, size: 17, color: C.muted2),
                const SizedBox(width: 5),
                Text(tr('ব্যক্তিগত'), style: body(13, weight: FontWeight.w600, color: C.muted2)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// The cash now and today's going; a tap opens the whole account (owner,
/// 23 Nov: "সে হিসাব সব সময়ের, নির্দিষ্ট দিনের না").
class _Today extends StatelessWidget {
  const _Today();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final cash = bizCashBalance(brain.data.cash);
    final t = bizToday(brain.shop, brain.data.cash, now);
    final inToday = t.salesPaid + t.collected + t.otherIncome + t.ownerIn + t.loanTaken + t.refundsGot;
    final outToday = t.purchasesPaid + t.dealersPaid + t.expenses + t.loanRepaid + t.ownerOut + t.refundsPaid;
    final acc = brain.bizAcc;
    Widget fig(String label, String v, Color color) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v, style: body(15, weight: FontWeight.w700, color: color))),
          ]),
        );
    return AppCard(
      key: const Key('biz-home-today'),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
      onTap: () => pushPage(context, const BizAccountPage()),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('ক্যাশ ব্যালেন্স · নগদ + বিকাশ'), style: body(12.5, color: C.muted)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(cash < 0 ? '− ${taka(-cash)}' : taka(cash), key: const Key('biz-home-cash'), style: display(31, weight: 700, height: 1.25, color: cash < 0 ? C.red : C.ink)),
              ),
            ]),
          ),
          Row(children: [
            if (!acc.adds) Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.error_outline_rounded, size: 18, color: C.red)),
            Text(tr('পুরো হিসাব'), style: body(13, weight: FontWeight.w600, color: C.green)),
            Icon(Icons.chevron_right_rounded, size: 19, color: C.green),
          ]),
        ]),
        const SizedBox(height: 10),
        const Hairline(),
        const SizedBox(height: 9),
        Row(children: [
          fig(tr('আজ বিক্রি'), taka(t.sales), C.ink),
          fig(tr('লাভ'), t.netProfit < 0 ? '− ${taka(-t.netProfit)}' : taka(t.netProfit), t.netProfit < 0 ? C.red : C.green),
          fig(tr('এলো'), '+${bnDigits(groupLakh(inToday))}', C.green),
          fig(tr('গেলো'), '−${bnDigits(groupLakh(outToday))}', outToday > 0 ? C.red : C.muted),
        ]),
      ]),
    );
  }
}

/// আজ নজর দিন: whose pay day is today, dues older than 30 days, what is
/// running out or about to expire, an instalment coming. Nothing: one calm
/// line, so the buttons below stay where the thumb knows them.
class _Attention extends StatelessWidget {
  const _Attention();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final now = brain.services.now();
    final today = dayOnly(now);
    final rows = <Widget>[];
    for (final a in owing(b)) {
      final c = customerById(b, a.id);
      if (c?.dueDay == null || dayOnly(c!.dueDay!).isAfter(today)) continue;
      rows.add(_AlertRow(
        icon: Icons.people_outline_rounded,
        color: C.warn,
        title: trf('{0}-এর আদায়ের দিন আজ', [c.name]),
        text: trf('বকেয়া {0}', [taka(a.due)]),
        action: tr('ফোন'),
        actionIcon: Icons.call_outlined,
        onAction: () => c.phone.isEmpty ? toast(context, tr('নম্বর রাখা নেই')) : brain.services.launcher.open(Via.call, c.phone),
        onTap: () => pushPage(context, CustomerPage(id: c.id)),
      ));
      if (rows.length >= 2) break;
    }
    final long = longOwing(b, now);
    if (long.isNotEmpty && rows.length < 2) {
      rows.add(_AlertRow(
        key: const Key('biz-home-long'),
        icon: Icons.schedule_rounded,
        color: C.warn,
        title: trf('{0} জনের বকেয়া ৩০ দিনের বেশি', [bnDigits(long.length)]),
        text: '${long.take(3).map((a) => a.name).join(', ')} · ${taka(long.fold(0, (s, a) => s + a.due))}',
        action: tr('দেখুন'),
        onAction: () => goToTab(context, ShellTab.people),
      ));
    }
    final low = lowStock(b);
    if (low.isNotEmpty) {
      rows.add(_AlertRow(
        key: const Key('biz-home-low'),
        icon: Icons.inventory_2_outlined,
        color: C.red,
        title: trf('{0}টি পণ্য প্রায় শেষ', [bnDigits(low.length)]),
        text: low.take(3).map((p) => p.name).join(', ') + (low.length > 3 ? '…' : ''),
        action: tr('অর্ডার'),
        onAction: () => pushPage(context, const OrderListPage()),
      ));
    }
    final exp = expiring(b, now);
    if (exp.isNotEmpty) {
      rows.add(_AlertRow(
        icon: Icons.event_busy_outlined,
        color: C.warn,
        title: trf('{0}টি পণ্যের মেয়াদ শেষের পথে', [bnDigits(exp.length)]),
        text: exp.take(3).map((p) => p.name).join(', '),
        action: tr('দেখুন'),
        onAction: () => goToTab(context, ShellTab.store),
      ));
    }
    for (final l in b.loans) {
      if (l.nextDue == null || loanDue(b, l) <= 0) continue;
      final days = dayOnly(l.nextDue!).difference(today).inDays;
      if (days > 3) continue;
      rows.add(_AlertRow(
        icon: Icons.account_balance_outlined,
        color: C.blue,
        title: days <= 0 ? trf('{0}-এর কিস্তি আজ', [l.name]) : trf('{0}-এর কিস্তি {1} দিন পর', [l.name, bnDigits(days)]),
        text: l.installment > 0 ? trf('কিস্তি {0}', [taka(l.installment)]) : trf('বাকি {0}', [taka(loanDue(b, l))]),
        action: tr('দিন'),
        onAction: () => pushPage(context, LoanPage(id: l.id)),
      ));
    }
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          key: const Key('biz-home-calm'),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Icon(Icons.check_circle_outline_rounded, size: 20, color: C.green),
            const SizedBox(width: 10),
            Expanded(child: Text(tr('আজ নজর দেওয়ার মতো কিছু নেই — বকেয়া, স্টক, কিস্তি সব ঠিক আছে'), style: body(13, color: C.muted2, height: 1.4))),
          ]),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Head(tr('আজ নজর দিন'), count: trf('{0}টি', [bnDigits(rows.length)])),
      Container(
        key: const Key('biz-home-attention'),
        decoration: BoxDecoration(color: C.warnBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.warnBorder)),
        child: Column(children: [
          for (final (i, r) in rows.take(3).indexed) ...[if (i > 0) Divider(height: 1, color: C.warnBorder), r],
        ]),
      ),
    ]);
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({super.key, required this.icon, required this.color, required this.title, required this.text, required this.action, required this.onAction, this.actionIcon, this.onTap});
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final String action;
  final IconData? actionIcon;
  final VoidCallback onAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap ?? onAction,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 19, color: color)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13.5, weight: FontWeight.w600)),
                Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
              ]),
            ),
            const SizedBox(width: 6),
            Material(
              color: C.surface,
              shape: StadiumBorder(side: BorderSide(color: C.border)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onAction,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (actionIcon != null) ...[Icon(actionIcon, size: 14, color: C.green), const SizedBox(width: 4)],
                    Text(action, style: body(12.5, weight: FontWeight.w600, color: C.green)),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );
}

/// The four buttons of the day (owner, 23 Nov: just below the middle of
/// the screen, for the thumb): sell, money in, stock in, a cost.
class BizQuickButtons extends StatelessWidget {
  const BizQuickButtons({super.key});

  @override
  Widget build(BuildContext context) {
    Widget btn(Key key, String label, IconData icon, Color fg, Color bg, VoidCallback onTap, {bool main = false}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Material(
              color: main ? C.green : C.surface,
              elevation: main ? 3 : 0,
              shadowColor: C.green.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: main ? BorderSide.none : BorderSide(color: C.border)),
              child: InkWell(
                key: key,
                borderRadius: BorderRadius.circular(18),
                onTap: onTap,
                child: SizedBox(
                  height: 88,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(color: main ? C.onAccent.withValues(alpha: 0.16) : bg, borderRadius: BorderRadius.circular(13)),
                      child: Icon(icon, color: main ? C.onAccent : fg, size: 23),
                    ),
                    const SizedBox(height: 7),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, weight: FontWeight.w600, color: main ? C.onAccent : C.ink)),
                  ]),
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: -4 + 4),
      child: Row(children: [
        btn(const Key('biz-quick-sell'), tr('নতুন বিক্রি'), Icons.add_shopping_cart_rounded, C.green, C.greenTint, () => pushPage(context, const SellPage()), main: true),
        btn(const Key('biz-quick-in'), tr('টাকা জমা'), Icons.download_rounded, C.green, C.greenTint, () => moneyIn(context)),
        btn(const Key('biz-quick-stock'), tr('স্টক যোগ'), Icons.inventory_2_outlined, C.ochre, C.ochreTint, () => pushPage(context, const StockInPage())),
        btn(const Key('biz-quick-cost'), tr('খরচ'), Icons.receipt_long_outlined, C.red, C.roseTint, () => moneyOut(context)),
      ]),
    );
  }
}

/// This month: profit and loss side by side, sales (of which on credit and
/// what came back of it) and costs.
class _Month extends StatelessWidget {
  const _Month();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final m = bizMonth(brain.shop, brain.data.cash, now);
    final last = bizFlowsBetween(brain.shop, brain.data.cash, DateTime(now.year, now.month - 1), DateTime(now.year, now.month, 0));
    final change = last.netProfit > 0 ? ((m.netProfit - last.netProfit) * 100 / last.netProfit).round() : null;
    Widget tile(String label, int v, Color fg, Color bg, String sub, Key key) => Expanded(
          child: Container(
            key: key,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: body(12, weight: FontWeight.w600, color: fg)),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(v < 0 ? '− ${taka(-v)}' : taka(v), style: display(18, weight: 700, color: fg))),
              Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted)),
            ]),
          ),
        );
    Widget line(String label, String v, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Row(children: [Expanded(child: Text(label, style: body(13, color: C.muted))), Text(v, style: body(13, weight: FontWeight.w600, color: color))]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Head(isEn ? monthName(now.month) : trf('{0} মাস', [monthName(now.month)]), link: tr('রিপোর্ট'), onLink: () => pushPage(context, const BizReportPage())),
      AppCard(
        key: const Key('biz-home-month'),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            tile(tr('লাভ'), m.netProfit, m.netProfit < 0 ? C.red : C.greenDark, m.netProfit < 0 ? C.roseTint : C.greenTint,
                change == null ? tr('খরচ বাদ দিয়ে') : trf('{0} {1}% গত মাসের চেয়ে', [change >= 0 ? '↑' : '↓', bnDigits(change.abs())]), const Key('biz-home-profit')),
            const SizedBox(width: 8),
            tile(tr('ক্ষতি'), m.loss, C.red, C.roseTint, tr('নষ্ট মাল, লোকসানে বিক্রি'), const Key('biz-home-loss')),
          ]),
          const SizedBox(height: 6),
          line(tr('বিক্রি'), taka(m.sales)),
          line(tr('এর মধ্যে বাকিতে'), m.collected > 0 ? trf('{0} (আদায় {1})', [taka(m.salesCredit), taka(m.collected)]) : taka(m.salesCredit)),
          line(tr('খরচ'), taka(m.expenses), color: m.expenses > 0 ? C.red : null),
        ]),
      ),
    ]);
  }
}

/// The whole position: what the business has and is owed, what it owes,
/// and the capital that leaves (with how it changed since the start).
class _Position extends StatelessWidget {
  const _Position();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final b = brain.shop;
    final acc = brain.bizAcc;
    final s = acc.now;
    final grew = s.capital - acc.start.capital;
    Widget row(IconData icon, Color fg, Color bg, String label, String sub, int v, {Color? color, bool minus = false, VoidCallback? onTap}) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(children: [
              Container(width: 30, height: 30, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 17, color: fg)),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: label, style: body(14)),
                  if (sub.isNotEmpty) TextSpan(text: ' · $sub', style: body(12, color: C.muted)),
                ])),
              ),
              Text('${minus && v != 0 ? '− ' : ''}${taka(v)}', style: body(14, weight: FontWeight.w600, color: color)),
            ]),
          ),
        );
    Widget label(String t) => Padding(padding: const EdgeInsets.only(top: 8, bottom: 2), child: Text(t, style: body(11.5, weight: FontWeight.w600, color: C.muted)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Head(tr('ব্যবসার মোট অবস্থা'), link: tr('পুরো হিসাব'), onLink: () => pushPage(context, const BizAccountPage())),
      AppCard(
        key: const Key('biz-home-position'),
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          label(tr('যা আছে ও পাবো')),
          row(Icons.account_balance_wallet_outlined, C.green, C.greenTint, tr('ক্যাশ'), '', s.cash, onTap: () => pushPage(context, const BizCashBook())),
          row(Icons.inventory_2_outlined, C.ochre, C.ochreTint, tr('স্টকের মাল'), tr('কেনা দামে'), s.stock, onTap: () => goToTab(context, ShellTab.store)),
          row(Icons.people_outline_rounded, C.teal, C.tealTint, tr('বাজারে বকেয়া'), trf('{0} জন', [bnDigits(owing(b).length)]), s.dues, onTap: () => goToTab(context, ShellTab.people)),
          Padding(padding: const EdgeInsets.only(top: 6), child: Divider(height: 1, color: C.line)),
          label(tr('যা দিতে হবে')),
          row(Icons.local_shipping_outlined, C.warn, C.warnBg, tr('সাপ্লায়ার পাবে'), trf('{0} জন', [bnDigits(owedToDealers(b).length)]), s.payable, color: s.payable > 0 ? C.warn : null, minus: true, onTap: () => pushPage(context, const SupplierListPage())),
          row(Icons.account_balance_outlined, C.blue, C.blueTint, tr('ঋণ'), '', s.loans, color: s.loans > 0 ? C.blue : null, minus: true, onTap: () => pushPage(context, const LoanListPage())),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('মূলধন এখন'), style: body(12, color: C.muted)),
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(s.capital < 0 ? '− ${taka(-s.capital)}' : taka(s.capital), key: const Key('biz-home-capital'), style: display(19, weight: 700))),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(trf('শুরুতে {0}', [taka(acc.start.capital)]), style: body(12, color: C.muted)),
                Text('${grew >= 0 ? '+' : '−'} ${taka(grew.abs())}', style: body(13.5, weight: FontWeight.w600, color: grew >= 0 ? C.green : C.red)),
              ]),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

/// Sales and profit by day (7 or 30 days) or by month (12).
class _Chart extends StatefulWidget {
  const _Chart();
  @override
  State<_Chart> createState() => _ChartState();
}

class _ChartState extends State<_Chart> {
  int _span = 7;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final today = dayOnly(now);
    final bars = <(String, int, int)>[];
    if (_span == 12) {
      for (var i = 11; i >= 0; i--) {
        final m = DateTime(now.year, now.month - i);
        final f = bizFlowsBetween(brain.shop, brain.data.cash, m, DateTime(m.year, m.month + 1, 0));
        bars.add((monthShort(m.month), f.sales, f.saleProfit));
      }
    } else {
      for (var i = _span - 1; i >= 0; i--) {
        final d = today.subtract(Duration(days: i));
        final f = bizFlowsBetween(brain.shop, brain.data.cash, d, d);
        bars.add((_span == 7 ? (i == 0 ? tr('আজ') : weekdayShort(d)) : (i % 5 == 0 ? bnDigits(d.day) : ''), f.sales, f.saleProfit));
      }
    }
    final top = bars.fold<int>(1, (m, x) => x.$2 > m ? x.$2 : m);
    final sum = bars.fold<int>(0, (s, x) => s + x.$2), profit = bars.fold<int>(0, (s, x) => s + x.$3);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Head(tr('বিক্রি ও লাভ')),
      AppCard(
        key: const Key('biz-home-chart'),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [ButtonSegment(value: 7, label: Text(tr('৭ দিন'))), ButtonSegment(value: 30, label: Text(tr('৩০ দিন'))), ButtonSegment(value: 12, label: Text(tr('১২ মাস')))],
            selected: {_span},
            onSelectionChanged: (v) => setState(() => _span = v.first),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final (label, sale, prof) in bars)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: _span == 30 ? 1 : 4),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(
                        height: sale <= 0 ? 2 : 2 + 92 * sale / top,
                        alignment: Alignment.bottomCenter,
                        decoration: BoxDecoration(color: C.green.withValues(alpha: 0.28), borderRadius: const BorderRadius.vertical(top: Radius.circular(5))),
                        child: FractionallySizedBox(
                          heightFactor: sale <= 0 || prof <= 0 ? 0 : (prof / sale).clamp(0, 1).toDouble(),
                          widthFactor: 1,
                          child: Container(decoration: BoxDecoration(color: C.green, borderRadius: const BorderRadius.vertical(top: Radius.circular(5)))),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(height: 16, child: Text(label, maxLines: 1, overflow: TextOverflow.visible, softWrap: false, style: body(10.5, color: C.muted))),
                    ]),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: C.green.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 4),
            Text(trf('বিক্রি {0}', [taka(sum)]), style: body(12, color: C.muted)),
            const SizedBox(width: 14),
            Container(width: 10, height: 10, decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 4),
            Text(trf('লাভ {0}', [taka(profit)]), style: body(12, color: C.muted)),
          ]),
        ]),
      ),
    ]);
  }
}

class _Recent extends StatelessWidget {
  const _Recent();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final list = bizTransactions(brain.shop, brain.data.cash).take(5).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Head(tr('সাম্প্রতিক লেনদেন'), link: tr('সব লেনদেন'), onLink: () => pushPage(context, const BizTxPage())),
      if (list.isEmpty)
        AppCard(child: Text(tr('এখনো কোনো লেনদেন নেই। “নতুন বিক্রি” বা “স্টক যোগ” দিয়ে শুরু করুন।'), style: body(13.5, color: C.muted, height: 1.5)))
      else
        Panel(
          key: const Key('biz-home-recent'),
          child: Column(children: [
            for (final (i, x) in list.indexed) ...[if (i > 0) const Hairline(indent: 14, endIndent: 14), TxRow(x)],
          ]),
        ),
    ]);
  }
}

class _TopDues extends StatelessWidget {
  const _TopDues();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final list = owing(brain.shop).take(3).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Head(tr('বকেয়া বেশি যাদের'), link: tr('সব'), onLink: () => goToTab(context, ShellTab.people)),
      Panel(
        key: const Key('biz-home-dues'),
        child: Column(children: [
          for (final (i, a) in list.indexed) ...[
            if (i > 0) const Hairline(indent: 14, endIndent: 14),
            ListRow(
              leading: Avatar(name: a.name, size: 36, fg: a.daysOwed(now) > 30 ? C.warn : null, bg: a.daysOwed(now) > 30 ? C.warnBg : null),
              title: a.name,
              subtitle: a.since == null ? null : (a.daysOwed(now) < 1 ? tr('আজ থেকে') : trf('{0} ধরে', [owedFor(a.daysOwed(now))])),
              subtitleColor: a.daysOwed(now) > 30 ? C.warn : null,
              trailing: Text(taka(a.due), style: body(14.5, weight: FontWeight.w600, color: C.green)),
              onTap: () => pushPage(context, CustomerPage(id: a.id)),
            ),
          ],
        ]),
      ),
    ]);
  }
}

class _LowStock extends StatelessWidget {
  const _LowStock();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final list = lowStock(brain.shop).take(3).toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Head(tr('কম আছে'), link: tr('কী কিনতে হবে'), onLink: () => pushPage(context, const OrderListPage())),
      Panel(
        child: Column(children: [
          for (final (i, p) in list.indexed) ...[
            if (i > 0) const Hairline(indent: 14, endIndent: 14),
            InkWell(
              onTap: () => pushPage(context, ProductForm(product: p)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.name, style: body(14.5, weight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(minHeight: 6, value: p.low <= 0 ? 0 : (p.stock / (p.low * 3)).clamp(0.02, 1).toDouble(), color: p.stock <= p.low / 2 ? C.red : C.warn, backgroundColor: C.surface2),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 14),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${bnDigits(qtyText(p.stock))} ${tr(p.unit)}', style: body(14, weight: FontWeight.w600, color: p.stock <= p.low / 2 ? C.red : C.warn)),
                    Text(trf('সীমা {0}', [bnDigits(qtyText(p.low))]), style: body(11.5, color: C.muted)),
                  ]),
                ]),
              ),
            ),
          ],
        ]),
      ),
    ]);
  }
}
