import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/money_more.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/pdf_export.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'money_more_screens.dart' show ReceiptScreen, dueMessage;
import 'money_screens.dart';
import 'person_screen.dart';

void _push(BuildContext context, Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

/// Which shop a sale or receipt is for: none needed with 0 or 1 shop; a
/// choice with more. Returns false when the choice was cancelled.
Future<Object?> pickShop(BuildContext context) async {
  final shops = BrainScope.read(context).data.shops;
  if (shops.length < 2) return shops.firstOrNull;
  final picked = await showModalBottomSheet<Shop>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 6), child: Text(tr('কোন দোকানের?'), style: display(18, weight: 700))),
        for (final s in shops)
          ListTile(
            leading: Icon(Icons.storefront_outlined, color: C.orange),
            title: Text(s.name, style: body(16)),
            subtitle: s.address.isEmpty ? null : Text(s.address, style: body(13, color: C.muted)),
            onTap: () => Navigator.pop(ctx, s),
          ),
      ]),
    ),
  );
  return picked ?? false;
}

/// দোকানের নাম, নম্বর, ঠিকানা — a new shop, or changing one.
Future<Shop?> shopForm(BuildContext context, {Shop? shop}) async {
  final name = TextEditingController(text: shop?.name ?? '');
  final phone = TextEditingController(text: shop?.phone ?? '');
  final address = TextEditingController(text: shop?.address ?? '');
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(shop == null ? tr('নতুন দোকান') : tr('দোকানের তথ্য বদলান'), style: display(19, weight: 700)),
        const SizedBox(height: 12),
        TextField(key: const Key('shop-name'), controller: name, autofocus: shop == null, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: tr('দোকানের নাম'))),
        const SizedBox(height: 10),
        TextField(key: const Key('shop-phone'), controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: tr('মোবাইল নম্বর'))),
        const SizedBox(height: 10),
        TextField(key: const Key('shop-address'), controller: address, decoration: InputDecoration(labelText: tr('ঠিকানা'))),
        const SizedBox(height: 16),
        PrimaryButton(
          label: tr('রাখুন'),
          icon: Icons.check_rounded,
          onPressed: () {
            if (name.text.trim().isEmpty) {
              toast(ctx, tr('দোকানের নাম লিখুন'));
              return;
            }
            Navigator.pop(ctx, true);
          },
        ),
      ]),
    ),
  );
  if (ok != true) return null;
  final s = shop == null
      ? Shop(name: name.text.trim(), phone: phone.text.trim(), address: address.text.trim())
      : shop.copyWith(name: name.text.trim(), phone: phone.text.trim(), address: address.text.trim());
  if (context.mounted) await BrainScope.read(context).saveShop(s);
  return s;
}

/// দোকান: all shops together on top, then each shop to open.
class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final shops = d.shops;
    Future<void> add() async {
      final s = await shopForm(context);
      if (s != null && context.mounted && shops.length > 1) _push(context, ShopDetailScreen(shopId: s.id));
    }

    if (shops.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Column(children: [
            TopBar(title: tr('দোকান')),
            Expanded(
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
                EmptyState(
                  icon: Icons.storefront_outlined,
                  title: tr('প্রথমে দোকানটা যোগ করুন'),
                  text: tr('দোকানের নাম, মোবাইল নম্বর আর ঠিকানা দিন। একাধিক দোকান বা ব্যবসা থাকলে প্রতিটা আলাদা যোগ করা যাবে — প্রত্যেকটার আলাদা বিক্রি, খরচ, বাকি আর রসিদ।'),
                ),
                const SizedBox(height: 16),
                PrimaryButton(label: tr('দোকান যোগ করুন'), icon: Icons.add_business_outlined, onPressed: add),
              ]),
            ),
          ]),
        ),
      );
    }

    final today = salesOn(d, now);
    var month = 0, costs = 0;
    for (final s in shops) {
      final m = shopMonth(d, s, now);
      month += m.sales;
      costs += m.costs;
    }
    final due = {for (final s in shops) for (final p in shopCustomersOwing(d, s)) p.key: p.balance}.values.fold(0, (a, b) => a + b);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('দোকান'), trailing: [
            const PdfButton({ReportPart.shops}),
            IconButton(tooltip: tr('দোকান যোগ করুন'), onPressed: add, icon: const Icon(Icons.add_business_outlined)),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
              if (shops.length > 1) Text(trf('{0}টি দোকান মিলিয়ে', [bnDigits(shops.length)]), style: body(13.5, color: C.muted)),
              const SizedBox(height: 6),
              Panel(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Row(children: [
                    Expanded(child: Figure(label: tr('আজকের বিক্রি'), amount: taka(today.total), color: C.green, size: 22, sub: trf('{0}টি বিক্রি', [bnDigits(today.count)]))),
                    Expanded(child: Figure(label: trf('{0}-এর বিক্রি', [monthName(now.month)]), amount: taka(month), color: C.green, size: 22)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: Figure(label: tr('এ মাসের দোকান খরচ'), amount: taka(costs), color: C.orange, size: 20)),
                    Expanded(child: Figure(label: tr('কাস্টমারের বাকি'), amount: taka(due), color: C.orange, size: 20)),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              SectionTitle(tr('আমার দোকান')),
              Panel(
                child: Rows(children: [
                  for (final s in shops)
                    ListRow(
                      leading: Avatar(name: s.name, fg: C.orange, bg: C.orangeTint),
                      title: s.name,
                      subtitle: [
                        trf('আজ {0}', [taka(salesOn(d, now, shop: s).total)]),
                        trf('এ মাসে {0}', [taka(shopMonth(d, s, now).sales)]),
                        if (s.address.isNotEmpty) s.address,
                      ].join(' · '),
                      trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
                      onTap: () => _push(context, ShopDetailScreen(shopId: s.id)),
                    ),
                ]),
              ),
              const SizedBox(height: 12),
              SecondaryButton(label: tr('আরেকটা দোকান যোগ করুন'), icon: Icons.add_business_outlined, onPressed: add),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One shop: its sales, costs, customers' dues and receipts.
class ShopDetailScreen extends StatelessWidget {
  const ShopDetailScreen({super.key, required this.shopId});
  final String shopId;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final shop = d.shops.where((s) => s.id == shopId).firstOrNull;
    if (shop == null) return Scaffold(body: SafeArea(child: Column(children: [TopBar(title: tr('দোকান'))])));
    final now = brain.services.now();
    final today = salesOn(d, now, shop: shop);
    final m = shopMonth(d, shop, now);
    final owing = shopCustomersOwing(d, shop);
    final week = [for (var i = 6; i >= 0; i--) now.subtract(Duration(days: i))];
    final sales = [for (final day in week) salesOn(d, day, shop: shop).total];
    final maxS = sales.fold(1, math.max);
    final receipts = d.receipts.where((r) => r.shopId == shop.id).toList()..sort((a, b) => b.date.compareTo(a.date));

    Future<void> menu(String v) async {
      if (v == 'edit') {
        await shopForm(context, shop: shop);
      } else if (v == 'delete') {
        final ok = await confirmDialog(context,
            title: trf('‘{0}’ মুছবেন?', [shop.name]), text: tr('দোকানের রসিদগুলো মুছে যাবে। বিক্রি ও খরচের হিসাব আয়-ব্যয়ে থেকে যাবে।'), yes: tr('মুছুন'), danger: true);
        if (!ok || !context.mounted) return;
        Navigator.of(context).pop();
        await brain.deleteShop(shop.id);
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: shop.name, trailing: [
            PdfButton(const {ReportPart.shops}, scope: ReportScope(shopId: shop.id), title: shop.name),
            PopupMenuButton<String>(
              tooltip: tr('আরও'),
              onSelected: menu,
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(tr('দোকানের তথ্য বদলান'))),
                PopupMenuItem(value: 'delete', child: Text(tr('দোকান মুছুন'), style: body(15, color: C.red))),
              ],
            ),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
              if (shop.phone.isNotEmpty || shop.address.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text([if (shop.phone.isNotEmpty) shop.phone, if (shop.address.isNotEmpty) shop.address].join(' · '), style: body(13.5, color: C.muted)),
                ),
              Panel(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Figure(label: tr('আজকের বিক্রি'), amount: taka(today.total), color: C.green, size: 22, sub: trf('{0}টি বিক্রি', [bnDigits(today.count)]))),
                    Expanded(child: Figure(label: trf('{0}-এর বিক্রি', [monthName(now.month)]), amount: taka(m.sales), color: C.green, size: 22)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: Figure(label: tr('এ মাসের খরচ'), amount: taka(m.costs), color: C.orange, size: 20)),
                    Expanded(child: Figure(label: tr('এ মাসে থাকল'), amount: '${m.sales - m.costs < 0 ? '−' : ''}${taka(m.sales - m.costs)}', color: m.sales - m.costs < 0 ? C.orange : C.green, size: 20)),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: PrimaryButton(
                        label: tr('বিক্রি'),
                        icon: Icons.add_rounded,
                        height: 44,
                        onPressed: () => _push(context, CashFormScreen(kind: CashKind.income, category: salesCategory, shopId: shop.id)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PrimaryButton(
                        label: tr('খরচ'),
                        icon: Icons.remove_rounded,
                        height: 44,
                        color: C.orange,
                        onPressed: () => _push(context, CashFormScreen(kind: CashKind.expense, shopId: shop.id)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: PrimaryButton(label: tr('রসিদ'), icon: Icons.receipt_long_outlined, height: 44, color: C.fill, onPressed: () => _push(context, ReceiptScreen(shop: shop)))),
                  ]),
                ]),
              ),
              const SizedBox(height: 14),
              SectionTitle(tr('গত ৭ দিনের বিক্রি')),
              Panel(
                padding: const EdgeInsets.all(14),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final (i, v) in sales.indexed)
                    Expanded(
                      child: Column(children: [
                        Text(v == 0 ? '' : bnNumber(v), style: body(10, color: C.muted), maxLines: 1, overflow: TextOverflow.clip),
                        const SizedBox(height: 2),
                        Container(height: 80.0 * v / maxS + 2, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: i == 6 ? C.green : C.greenTint, borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 4),
                        Text(weekdayShort(week[i]), style: body(11, color: C.muted)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 14),
              SectionTitle(trf('রসিদ · {0}টি', [bnDigits(receipts.length)])),
              if (receipts.isEmpty)
                Text(tr('এই দোকানে এখনো কোনো রসিদ দেওয়া হয়নি। “রসিদ” চাপলে তৈরি করা যাবে, এখানে জমা থাকবে।'), style: body(14, color: C.muted, height: 1.5))
              else
                Panel(
                  child: Rows(children: [
                    for (final r in receipts.take(50))
                      ListRow(
                        leading: Icon(Icons.receipt_long_outlined, color: C.muted2),
                        title: '#${bnDigits(r.no)} · ${r.customer.isEmpty ? tr('নগদ বিক্রি') : r.customer}',
                        subtitle: [fullDate(r.date), taka(r.total), if (r.due > 0) trf('বাকি {0}', [taka(r.due)])].join(' · '),
                        onTap: () => _showReceipt(context, r, shop),
                      ),
                  ]),
                ),
              const SizedBox(height: 14),
              SectionTitle(trf('কাস্টমারের বাকি · {0} জন', [bnDigits(owing.length)])),
              if (owing.isEmpty)
                Text(tr('কারো কাছে বাকি নেই। “করিম ৫০০ টাকার মাল বাকিতে নিল” বললেই খাতায় উঠবে।'), style: body(14, color: C.muted, height: 1.5))
              else
                Panel(
                  child: Rows(children: [
                    for (final p in owing)
                      ListRow(
                        leading: Avatar(name: p.name, fg: C.orange, bg: C.orangeTint),
                        title: p.name,
                        subtitle: [taka(p.balance), if (p.last != null) daysLeftLabel(p.last!, now)].join(' · '),
                        trailing: p.phone.isEmpty
                            ? Icon(Icons.chevron_right_rounded, color: C.muted)
                            : TextButton(
                                onPressed: () => brain.services.launcher.open(Via.whatsapp, p.phone, text: dueMessage(p.name, p.balance)),
                                child: Text(tr('তাগাদা'), style: body(14, weight: FontWeight.w600, color: C.green)),
                              ),
                        onTap: () => _push(context, PersonScreen(person: p.name, accountKey: p.key)),
                      ),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// A kept receipt, to read or send again.
Future<void> _showReceipt(BuildContext context, Receipt r, Shop shop) async {
  final brain = BrainScope.read(context);
  final text = receiptTextOf(r, shop);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(text.replaceAll('*', ''), style: body(15, height: 1.55)),
          const SizedBox(height: 14),
          PrimaryButton(
            label: r.phone.isEmpty ? tr('পাঠান') : tr('WhatsApp-এ পাঠান'),
            icon: Icons.send_rounded,
            onPressed: () {
              Navigator.pop(ctx);
              if (r.phone.isNotEmpty) {
                brain.services.launcher.open(Via.whatsapp, r.phone, text: text);
              } else {
                brain.services.files.shareText(text);
              }
            },
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await confirmDialog(context, title: tr('রসিদটা মুছবেন?'), text: tr('শুধু রসিদ মুছবে; বিক্রি আর বাকির হিসাব যেমন আছে থাকবে।'), yes: tr('মুছুন'), danger: true);
              if (ok) await brain.deleteReceipt(r.id);
            },
            child: Text(tr('রসিদ মুছুন'), style: body(14, color: C.red)),
          ),
        ]),
      ),
    ),
  );
}
