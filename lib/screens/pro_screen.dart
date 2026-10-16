import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/pro.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// My Assistant Pro: what it adds over the free app, the plans, and (in the
/// Play app) buying or the free trial. In the downloaded APK everything is
/// already open, so it only explains.
class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  String _plan = proPlans.first.id;

  Future<void> _buy(Brain brain) async {
    final plan = proPlans.firstWhere((p) => p.id == _plan);
    if (!previewEdition) {
      // The store build connects Google Play Billing here.
      toast(context, tr('Google Play পেমেন্ট এখনো যুক্ত হয়নি'));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('প্রিভিউ: এখানে Google Play-এর পেমেন্ট আসবে'), style: display(19)),
        content: Text(
            trf('আসল অ্যাপে এখানে Google Play-এর নিজের পেমেন্ট পাতা খুলবে ({0} {1})। কার্ড দিয়ে পরিশোধ, যেকোনো সময় Play Store থেকে বাতিল। প্রিভিউতে কোনো টাকা কাটা হবে না — পরীক্ষার জন্য প্রো চালু করে দেখাই?',
                [plan.price, tr(plan.title)]),
            style: body(15, height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('বাতিল'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('প্রো চালু করে দেখাও'))),
        ],
      ),
    );
    if (ok == true) {
      await brain.activatePro(plan);
      if (mounted) toast(context, tr('প্রো চালু হলো (পরীক্ষা)'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final sell = brain.gated;
    Widget point(ProInfo p) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(color: C.greenTint, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, size: 16, color: C.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(tr(p.title), style: body(15, weight: FontWeight.w600))),
                  if (p.later) ...[const SizedBox(width: 6), Pill(tr('শীঘ্রই'), fg: C.orange, bg: C.orangeTint)],
                ]),
                Text(tr(p.what), style: body(13, color: C.muted, height: 1.45)),
                Text(p.free.isEmpty ? tr('ফ্রিতে: নেই') : trf('ফ্রিতে: {0}', [tr(p.free)]), style: body(12, color: C.muted2)),
              ]),
            ),
          ]),
        );
    final until = brain.proUntil;
    final status = !sell
        ? tr('এই অ্যাপে এখন সব সুবিধা খোলা — কিছুই তালাবদ্ধ নয়।')
        : brain.pro
            ? switch (brain.proKind) {
                'trial' => trf('ফ্রি ট্রায়াল চলছে — শেষ {0}', [shortDate(until!)]),
                'test' => tr('প্রো চালু (প্রিভিউ পরীক্ষা)'),
                _ => trf('প্রো চালু — নবায়ন {0}', [shortDate(until!)]),
              }
            : null;
    return Scaffold(
      backgroundColor: C.surface,
      body: SafeArea(
        child: Column(children: [
          const TopBar(title: '', close: true),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
              Text('My Assistant Pro', style: display(28, weight: 700)),
              Text(tr('মুখে বলুন, বাকিটা সহকারী সামলাবে'), style: body(15, color: C.muted2)),
              if (status != null) ...[
                const SizedBox(height: 12),
                InfoBanner(text: status, icon: Icons.verified_rounded),
              ],
              const SizedBox(height: 20),
              for (final p in proInfo.values) point(p),
              if (sell && !brain.pro) ...[
                const SizedBox(height: 6),
                for (final p in proPlans) ...[
                  _PlanCard(plan: p, selected: _plan == p.id, best: p == proPlans.first, onTap: () => setState(() => _plan = p.id)),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 4),
                if (!brain.trialUsed) ...[
                  PrimaryButton(
                    label: trf('{0} দিন ফ্রি চালু করুন', [bnDigits(trialDays)]),
                    icon: Icons.auto_awesome_rounded,
                    onPressed: () async {
                      await brain.startTrial();
                      if (context.mounted) toast(context, trf('{0} দিনের ফ্রি ট্রায়াল চালু হলো', [bnDigits(trialDays)]));
                    },
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(label: tr('এখনই কিনুন'), onPressed: () => _buy(brain)),
                ] else
                  PrimaryButton(label: tr('প্রো নিন'), icon: Icons.auto_awesome_rounded, onPressed: () => _buy(brain)),
                const SizedBox(height: 8),
                Text(tr('পেমেন্ট Google Play দিয়ে (কার্ড)। ট্রায়ালে টাকা কাটে না; ট্রায়াল শেষে নিজে থেকে কিছু কেনা হবে না। যেকোনো সময় Play Store থেকে বাতিল করা যায়।'),
                    textAlign: TextAlign.center, style: body(12, color: C.muted, height: 1.5)),
                TextButton(
                  onPressed: () => toast(context, previewEdition ? tr('প্রিভিউ: আসল অ্যাপে Google Play থেকে আগের কেনা প্রো ফিরিয়ে আনবে') : tr('কোনো কেনা প্রো পাওয়া যায়নি')),
                  child: Text(tr('আগে কেনা প্রো ফিরিয়ে আনুন')),
                ),
              ],
              const SizedBox(height: 18),
              SectionTitle(tr('সবসময় ফ্রি')),
              Text(tr('লেনদেন ও বাকির হিসাব, কাজের তালিকা, রিমাইন্ডার ও অ্যালার্ম, নোট, ডকুমেন্ট, ভয়েসে সব কাজ, ক্যালেন্ডার ও নামাজের সময়, স্বাস্থ্য ও ওষুধ, অভ্যাস, সঞ্চয়, ১টা দোকান, ১টা আলাদা হিসাব, ১০টা পাসওয়ার্ড, ফোনে ব্যাকআপ। আপনার রাখা কোনো তথ্য কখনো তালাবদ্ধ হবে না।'),
                  style: body(14, color: C.muted2, height: 1.55)),
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
              if (previewEdition) ...[
                const SizedBox(height: 10),
                Panel(
                  color: C.orangeTint,
                  borderColor: C.orange,
                  padding: const EdgeInsets.all(14),
                  child: Text(tr('এটা প্লে স্টোর ভার্সনের প্রিভিউ। কেনা বা ট্রায়ালে কোনো টাকা কাটে না। সেটিংসের “পরীক্ষা: প্রো চালু” সুইচ দিয়ে ফ্রি আর প্রো দুটোই দেখতে পারবেন।'),
                      style: body(13, color: C.orangeDark, height: 1.5)),
                ),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.selected, required this.best, required this.onTap});
  final ProPlan plan;
  final bool selected;
  final bool best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Panel(
        color: selected ? C.greenSoft : C.surface,
        borderColor: selected ? C.green : C.line,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? C.green : C.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text('${plan.price} / ${tr(plan.title)}', style: body(17, weight: FontWeight.w700)),
                    if (best) ...[const SizedBox(width: 8), Pill(tr('সবচেয়ে লাভ'))],
                  ]),
                  Text(tr(plan.note), style: body(13, color: C.muted)),
                ]),
              ),
            ]),
          ),
        ),
      );
}
