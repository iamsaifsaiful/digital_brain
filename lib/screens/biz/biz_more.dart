import 'package:flutter/material.dart';

import '../../logic/biz_account.dart';
import '../../logic/bn.dart';
import '../../logic/lang.dart';
import '../../state/brain.dart';
import '../../ui/kit.dart';
import '../../ui/theme.dart';
import '../../ui/widgets.dart';
import 'biz_account_page.dart';
import 'biz_money.dart';
import 'biz_parts.dart';
import 'biz_returns.dart';
import 'biz_shop.dart' show ShopProfilePage, TagadaPage;
import 'biz_stock.dart' show OrderListPage;
import 'biz_tx.dart';

/// আরও in ব্যবসায়ী মোড (owner, 23 Nov: "যে গুলো ব্যবসায়ী মোড এ থাকা দরকার,
/// সেগুলো থাকবে। অন্য গুলো থাকা অযৌক্তিক"; "আরও মেনু থেকেও ব্যক্তিগত মোডে
/// যাওয়া যাবে"): the shop, the way back to the personal app, the shop's
/// work, its settings, and Premium and help. [settings] and [others] are
/// the rows আরও already has (look, lock, backup; Premium, help).
class BizMore extends StatelessWidget {
  const BizMore({super.key, required this.settings, required this.others});
  final List<Widget> settings;
  final List<Widget> others;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final p = brain.shop.profile;
    final start = brain.shop.start;
    Widget tile(String key, IconData icon, Color fg, Color bg, String label, Widget page) => InkWell(
          key: Key('biz-more-$key'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => pushPage(context, page),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 46, height: 46, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: fg, size: 23)),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, maxLines: 2, style: body(12.5, weight: FontWeight.w500, height: 1.25)),
            ]),
          ),
        );
    Widget row(Key key, IconData icon, Color fg, Color bg, String title, String sub, VoidCallback onTap) => ListRow(
          key: key,
          leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: fg, size: 20)),
          title: title,
          subtitle: sub,
          trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
          onTap: onTap,
        );
    final tiles = [
      tile('suppliers', Icons.local_shipping_outlined, C.warn, C.warnBg, tr('সাপ্লায়ার'), const SupplierListPage()),
      tile('costs', Icons.receipt_long_outlined, C.red, C.roseTint, tr('খরচ'), const BizTxPage(kinds: {TxKind.expense})),
      tile('purchases', Icons.inventory_2_outlined, C.ochre, C.ochreTint, tr('ক্রয়ের তালিকা'), const BizTxPage(kinds: {TxKind.purchase})),
      tile('report', Icons.bar_chart_rounded, C.teal, C.tealTint, tr('রিপোর্ট'), const BizReportPage()),
      tile('cashbook', Icons.account_balance_wallet_outlined, C.green, C.greenTint, tr('ক্যাশ বই'), const BizCashBook()),
      tile('loans', Icons.account_balance_outlined, C.blue, C.blueTint, tr('ঋণ'), const LoanListPage()),
      tile('memos', Icons.description_outlined, C.purple, C.purpleTint, tr('সব মেমো'), const BizTxPage(kinds: {TxKind.sale})),
      tile('orders', Icons.sell_outlined, C.ochre, C.ochreTint, tr('অর্ডার তালিকা'), const OrderListPage()),
      tile('returns', Icons.assignment_return_outlined, C.orange, C.orangeTint, tr('মাল ফেরত'), const ReturnsPage()),
      tile('all', Icons.list_alt_rounded, C.muted2, C.surface2, tr('সব লেনদেন'), const BizTxPage()),
      tile('account', Icons.balance_rounded, C.purple, C.purpleTint, tr('পুরো হিসাব'), const BizAccountPage()),
      tile('tagada', Icons.campaign_outlined, C.green, C.greenTint, tr('তাগাদা'), const TagadaPage()),
    ];
    return ListView(
      key: const PageStorageKey('biz-more-list'),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        TabTitle(tr('আরও')),
        const SizedBox(height: 12),
        // The shop.
        AppCard(
          onTap: () => pushPage(context, const ShopProfilePage()),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(children: [
            Container(width: 48, height: 48, decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(14)), child: Icon(Icons.storefront_rounded, color: C.onAccent, size: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name.isEmpty ? tr('দোকানের নাম দিন') : p.name, key: const Key('biz-more-shop'), maxLines: 1, overflow: TextOverflow.ellipsis, style: display(18, weight: 700, color: p.name.isEmpty ? C.muted : C.ink)),
                Text([if (p.address.isNotEmpty) p.address, tr('মেমোতে যা ছাপা হয়')].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
              ]),
            ),
            Text(tr('এডিট'), style: body(13.5, weight: FontWeight.w600, color: C.green)),
          ]),
        ),
        const SizedBox(height: 10),
        // Back to the personal app (the same switch as before, so it works the same).
        Material(
          color: C.surface2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
          child: InkWell(
            key: const Key('more-business'),
            borderRadius: BorderRadius.circular(17),
            onTap: () => brain.setPref('business_mode', false),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(children: [
                Container(width: 38, height: 38, decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(11)), child: Icon(Icons.swap_horiz_rounded, color: C.muted2, size: 21)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('ব্যক্তিগত মোডে যান'), style: body(15, weight: FontWeight.w600)),
                    Text(tr('রিমাইন্ডার, নোট, পরিবার — ব্যবসার হিসাব যেমন আছে থাকবে'), style: body(12, color: C.muted)),
                  ]),
                ),
                Icon(Icons.chevron_right_rounded, color: C.muted),
              ]),
            ),
          ),
        ),
        SectionTitle(tr('ব্যবসার কাজ')),
        Panel(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.82,
            children: tiles,
          ),
        ),
        SectionTitle(tr('সেটিংস')),
        Panel(
          child: Rows(children: [
            row(const Key('biz-more-start'), Icons.edit_outlined, C.green, C.greenTint, tr('ব্যবসার শুরুর হিসাব'),
                start == null ? tr('শুরুর নগদ, স্টক, পাওনা-দেনা · মূলধন নিজে হিসাব হয়') : trf('{0} · শুরুর মূলধন {1}', [shortDate(start.at), taka(start.sums.capital)]), () => pushPage(context, const BizAccountPage())),
            row(const Key('biz-more-memo'), Icons.description_outlined, C.purple, C.purpleTint, tr('মেমো ও তাগাদা'), tr('মেমোর নিচের লেখা, লোগো, তাগাদার বার্তা'), () => pushPage(context, const ShopProfilePage())),
            ...settings,
          ]),
        ),
        SectionTitle(tr('অন্যান্য')),
        ...others,
      ],
    );
  }
}
