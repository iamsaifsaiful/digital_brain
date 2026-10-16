/// Pro locks and ad spaces for the Play app (see logic/pro.dart). In the
/// downloaded APK nothing here shows: every check passes and no ad space is
/// drawn.
library;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/pro.dart';
import '../screens/pro_screen.dart';
import '../state/brain.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> openPro(BuildContext context) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProScreen()));

/// True when [feature] may be used now (or [allowed] is already true, e.g.
/// still under the free limit). Otherwise explains it is Pro, offers the
/// trial or the Pro page, and returns whether Pro is on afterwards.
Future<bool> needPro(BuildContext context, ProFeature feature, {bool allowed = false}) async {
  final brain = BrainScope.read(context);
  if (allowed || brain.has(feature)) return true;
  final info = proInfo[feature]!;
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.lock_outline_rounded, color: C.green),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(trf('{0} — প্রো সুবিধা', [tr(info.title)]), style: display(19))),
          ]),
          const SizedBox(height: 12),
          Text(tr(info.what), style: body(15, height: 1.5)),
          if (info.free.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(trf('ফ্রিতে: {0}', [tr(info.free)]), style: body(13, color: C.muted)),
          ],
          const SizedBox(height: 6),
          Text(tr('আপনার রাখা তথ্য যেমন আছে তেমনই থাকবে — দেখা, বদলানো, মোছা সবসময় যাবে।'), style: body(13, color: C.muted, height: 1.45)),
          const SizedBox(height: 16),
          if (!brain.trialUsed) ...[
            PrimaryButton(
              label: trf('{0} দিন ফ্রি চালু করুন', [bnDigits(trialDays)]),
              icon: Icons.auto_awesome_rounded,
              onPressed: () async {
                await brain.startTrial();
                if (ctx.mounted) Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 8),
          ],
          SecondaryButton(
            label: tr('প্রো দেখুন'),
            onPressed: () async {
              Navigator.pop(ctx);
              await openPro(context);
            },
          ),
        ]),
      ),
    ),
  );
  return brain.has(feature);
}

/// A small "PRO" mark beside a locked row or button.
class ProMark extends StatelessWidget {
  const ProMark({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline_rounded, size: 12, color: C.greenDark),
          const SizedBox(width: 3),
          Text('PRO', style: body(11, weight: FontWeight.w700, color: C.greenDark)),
        ]),
      );
}

/// Where a Google banner ad goes in the free Play app. The preview draws a
/// labelled sample; the real ad comes with AdMob.
class AdSlot extends StatelessWidget {
  const AdSlot({super.key, this.padding = const EdgeInsets.only(top: 12)});
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    if (!brain.showAds || !brain.adSamples) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: Container(
        key: const Key('ad-banner'),
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: C.soft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: C.inputBorder),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: C.ochreTint, borderRadius: BorderRadius.circular(4)),
            child: Text(tr('বিজ্ঞাপন'), style: body(11, weight: FontWeight.w700, color: C.ochre)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(tr('নমুনা: এখানে Google-এর ছোট ব্যানার বিজ্ঞাপন দেখাবে'), maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted2, height: 1.35)),
          ),
          TextButton(onPressed: () => openPro(context), child: Text(tr('সরান'), style: body(13, weight: FontWeight.w600, color: C.green))),
        ]),
      ),
    );
  }
}

/// A banner ad space at the bottom of a page (nothing when there is no ad).
class AdBar extends StatelessWidget {
  const AdBar({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    if (!brain.showAds || !brain.adSamples) return const SizedBox.shrink();
    return const SafeArea(top: false, child: AdSlot(padding: EdgeInsets.fromLTRB(12, 4, 12, 6)));
  }
}

/// Call after a task is finished (a payment or reminder saved): in the free
/// Play app a full-screen ad may follow (at most 2 a day, never on the first
/// day). The preview shows a labelled sample.
Future<void> afterTaskDone(BuildContext context) async {
  final brain = BrainScope.read(context);
  if (!await brain.taskFinished() || !brain.adSamples || !context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => Dialog.fullscreen(
      backgroundColor: C.ground,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(key: const Key('ad-full-close'), tooltip: tr('বন্ধ করুন'), onPressed: () => Navigator.pop(ctx), icon: Icon(Icons.close_rounded, color: C.ink)),
            ),
            const Spacer(),
            Icon(Icons.campaign_outlined, size: 56, color: C.ochre),
            const SizedBox(height: 16),
            Text(tr('পুরো পর্দার বিজ্ঞাপন (নমুনা)'), textAlign: TextAlign.center, style: display(22)),
            const SizedBox(height: 10),
            Text(tr('ফ্রি ভার্সনে কাজ শেষ হওয়ার পর মাঝে মাঝে এমন একটা Google বিজ্ঞাপন আসবে — দিনে সর্বোচ্চ ২টা, প্রথম দিন একটাও না। কয়েক সেকেন্ড পর বন্ধ করা যায়।'),
                textAlign: TextAlign.center, style: body(15, color: C.muted2, height: 1.55)),
            const Spacer(),
            PrimaryButton(
              label: tr('বিজ্ঞাপন ছাড়া — প্রো দেখুন'),
              onPressed: () async {
                Navigator.pop(ctx);
                await openPro(context);
              },
            ),
          ]),
        ),
      ),
    ),
  );
}
