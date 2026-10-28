import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/pro.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// My Assistant Pro: what it adds over the free app, the plans, and (in the
/// Play app) buying. In the downloaded APK everything is
/// already open, so it only explains.
class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

/// A short name and an icon for each Pro feature (the সংক্ষেপে tab).
/// The shop's features wait with ব্যবসায়ী মোড (owner, 23 Oct): not offered
/// until it is on.
bool _shown(BuildContext context, ProFeature f) =>
    !(f == ProFeature.shops || f == ProFeature.receipts) || BrainScope.of(context).businessMode;

const _short = <ProFeature, (String, IconData)>{
  ProFeature.ai: ('AI উত্তর', Icons.auto_awesome_outlined),
  ProFeature.noAds: ('বিজ্ঞাপন নেই', Icons.block_rounded),
  ProFeature.autoBackup: ('অটো ব্যাকআপ', Icons.cloud_sync_outlined),
  ProFeature.docAlerts: ('কাগজের মেয়াদের খবর', Icons.event_busy_outlined),
  ProFeature.dueReminders: ('ধার-দেনার রিমাইন্ডার', Icons.payments_outlined),
  ProFeature.history: ('পুরো ইতিহাস ও রিপোর্ট', Icons.insights_outlined),
  ProFeature.reminders: ('যত খুশি রিমাইন্ডার', Icons.notifications_active_outlined),
  ProFeature.people: ('যত খুশি মানুষ', Icons.groups_outlined),
  ProFeature.docs: ('যত খুশি ডকুমেন্ট', Icons.folder_copy_outlined),
  ProFeature.shops: ('একাধিক দোকান', Icons.storefront_outlined),
  ProFeature.receipts: ('রসিদ', Icons.receipt_long_outlined),
  ProFeature.pdf: ('PDF ডাউনলোড', Icons.picture_as_pdf_outlined),
  ProFeature.projects: ('অন্যান্য হিসাব', Icons.folder_special_outlined),
  ProFeature.vault: ('যত খুশি পাসওয়ার্ড', Icons.lock_outline_rounded),
  ProFeature.smartNudges: ('স্মার্ট খেয়াল', Icons.tips_and_updates_outlined),
  ProFeature.family: ('উত্তরাধিকার, পুরো অ্যাক্সেস, লোকেশন', Icons.family_restroom_rounded),
  ProFeature.will: ('ওছিয়তনামা', Icons.history_edu_outlined),
  ProFeature.familyHealth: ('পরিবারের স্বাস্থ্য', Icons.favorite_border_rounded),
};

class _ProScreenState extends State<ProScreen> {
  bool _details = false;

  /// "Get Premium": our website's Pro page, where any way of paying works.
  Future<void> _getPro(Brain brain) async {
    final ok = await brain.services.launcher.openUrl(Uri.parse(proWebPage));
    if (!ok && mounted) toast(context, tr('ব্রাউজার খোলা গেল না'));
  }

  /// The preview only: Pro on without paying, to try both sides.
  Future<void> _tryPreview(Brain brain) async {
    await brain.activatePro(proPlans.first);
    if (mounted) toast(context, tr('প্রিমিয়াম চালু হলো (পরীক্ষা)'));
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final sell = brain.gated;
    final until = brain.proUntil;
    final status = !sell
        ? tr('এই অ্যাপে এখন সব সুবিধা খোলা — কিছুই তালাবদ্ধ নয়।')
        : brain.onTrial
            ? trf('৭ দিনের ফ্রি ট্রায়াল চলছে — {0} পর্যন্ত, আর {1} দিন। এর মধ্যে প্রিমিয়াম নিলে সব সুবিধা থাকবে।',
                [fullDate(brain.trialEnds!), bnDigits(brain.trialEnds!.difference(brain.services.now()).inHours ~/ 24 + 1)])
            : brain.pro
                ? switch (brain.proKind) {
                    'test' => tr('প্রিমিয়াম চালু (প্রিভিউ পরীক্ষা)'),
                    _ => until == null ? tr('প্রিমিয়াম চালু') : trf('প্রিমিয়াম চালু — {0} পর্যন্ত', [fullDate(until)]),
                  }
                : brain.trialOver
                    ? tr('৭ দিনের ফ্রি ট্রায়াল শেষ। এই কয়দিনে যা রেখেছেন সব আছে, দেখা যাবে; প্রিমিয়ামের সুবিধাগুলো আবার পেতে প্রিমিয়াম নিন।')
                    : null;

    Widget getPro() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (showProLink) PrimaryButton(key: const Key('get-pro'), label: brain.pro && sell ? tr('মেয়াদ বাড়ান') : 'Get Premium', icon: Icons.workspace_premium_rounded, onPressed: () => _getPro(brain)),
          if (proTestSwitch && !brain.pro) ...[
            const SizedBox(height: 6),
            TextButton(onPressed: () => _tryPreview(brain), child: Text(tr('প্রিভিউ: টাকা ছাড়া প্রিমিয়াম চালু করে দেখুন'))),
          ],
        ]);

    final brief = <Widget>[
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.3,
        children: [
          for (final f in proInfo.keys)
            if (_shown(context, f))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(_short[f]?.$2 ?? Icons.check_rounded, size: 19, color: C.green),
                const SizedBox(width: 8),
                Expanded(child: Text(tr(_short[f]?.$1 ?? proInfo[f]!.title), maxLines: 2, overflow: TextOverflow.ellipsis, style: body(13, weight: FontWeight.w600, height: 1.25))),
              ]),
            ),
          // The last cell (owner, 28 Oct): the details on our website.
          if (showProLink)
            Material(
              color: C.greenTint,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                key: const Key('pro-brief-website'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => _getPro(brain),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(children: [
                    Icon(Icons.open_in_new_rounded, size: 19, color: C.green),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tr('বিস্তারিত — ওয়েবসাইটে'), maxLines: 2, overflow: TextOverflow.ellipsis, style: body(13, weight: FontWeight.w700, color: C.greenDark, height: 1.25))),
                  ]),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 16),
      Row(children: [
        for (final (i, p) in proPlans.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: i == 0 ? C.greenSoft : C.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: i == 0 ? C.green : C.line, width: i == 0 ? 1.5 : 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p.price} / ${tr(p.title)}', style: display(18, weight: 700)),
                Text(tr(p.note), maxLines: 2, style: body(12, color: C.muted)),
              ]),
            ),
          ),
        ],
      ]),
      const SizedBox(height: 16),
      getPro(),
      const SizedBox(height: 10),
      Center(
        child: TextButton.icon(
          onPressed: () => setState(() => _details = true),
          icon: const Icon(Icons.list_alt_rounded),
          label: Text(tr('ফ্রি আর প্রিমিয়ামের পুরো তুলনা')),
        ),
      ),
    ];

    final details = <Widget>[
      if (showProLink) ...[
        Material(
          color: C.greenTint,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: const Key('pro-website'),
            borderRadius: BorderRadius.circular(16),
            onTap: () => _getPro(brain),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(children: [
                Icon(Icons.public_rounded, color: C.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('বিস্তারিত আর কেনা — আমাদের ওয়েবসাইটে'), style: body(15, weight: FontWeight.w700, color: C.greenDark)),
                    Text(proWebPage.replaceFirst('https://', ''), style: body(13, color: C.greenDark)),
                    Text(tr('বিকাশে টাকা দিয়ে প্রিমিয়াম নেওয়া যায়'), style: body(12, color: C.greenDark)),
                  ]),
                ),
                Icon(Icons.open_in_new_rounded, color: C.green),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
      for (final e in proInfo.entries)
        if (_shown(context, e.key))
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(10)),
              child: Icon(_short[e.key]?.$2 ?? Icons.check_rounded, size: 19, color: C.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(e.value.title), style: body(15, weight: FontWeight.w600)),
                Text(tr(e.value.what), style: body(13, color: C.muted, height: 1.45)),
                Text(e.value.free.isEmpty ? tr('ফ্রিতে: নেই') : trf('ফ্রিতে: {0}', [tr(e.value.free)]), style: body(12, color: C.muted2)),
              ]),
            ),
          ]),
        ),
      const SizedBox(height: 4),
      SectionTitle(tr('সবসময় ফ্রি')),
      Text(tr(freeList), key: const Key('pro-free-list'), style: body(14, color: C.muted2, height: 1.55)),
      if (sell) ...[
        const SizedBox(height: 18),
        SectionTitle(tr('ফ্রি ভার্সনে বিজ্ঞাপন কোথায় দেখাবে')),
        for (final (title, where) in adPlaces)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(title == 'কখনো না' ? Icons.block_rounded : Icons.campaign_outlined, size: 20, color: title == 'কখনো না' ? C.green : C.muted2),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(title), style: body(14, weight: FontWeight.w600)),
                  Text(tr(where), style: body(13, color: C.muted, height: 1.45)),
                ]),
              ),
            ]),
          ),
      ],
      const SizedBox(height: 12),
      getPro(),
    ];

    return Scaffold(
      backgroundColor: C.ground,
      body: SafeArea(
        child: Column(children: [
          const TopBar(title: '', close: true),
          Expanded(
            child: SwipeTabs<bool>(
              items: const [false, true],
              value: _details,
              onChanged: (v) => setState(() => _details = v),
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: C.border)),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(16)),
                      child: Icon(Icons.workspace_premium_rounded, color: C.green, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('My Assistant Premium', style: display(21, weight: 600)),
                        Text(status ?? tr('আরও বেশি কাজ, বিজ্ঞাপন ছাড়া'), style: body(13, color: C.muted)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                SegTabs<bool>(
                  items: [(false, tr('সংক্ষেপে')), (true, tr('বিস্তারিত'))],
                  value: _details,
                  onChanged: (v) => setState(() => _details = v),
                ),
                const SizedBox(height: 14),
                ...(_details ? details : brief),
                if (proTestSwitch) ...[
                  const SizedBox(height: 14),
                  Panel(
                    color: C.orangeTint,
                    borderColor: C.orange,
                    padding: const EdgeInsets.all(14),
                    child: Text(tr('এটা প্লে স্টোর ভার্সনের প্রিভিউ। সেটিংসের “পরীক্ষা: প্রিমিয়াম চালু” সুইচ দিয়ে ফ্রি আর প্রিমিয়াম দুটোই দেখতে পারবেন।'), style: body(13, color: C.orangeDark, height: 1.5)),
                  ),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
