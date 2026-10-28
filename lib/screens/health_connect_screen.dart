import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/health.dart';
import '../logic/lang.dart';
import '../logic/steps.dart' show stepsKm;
import '../models/models.dart';
import '../services/health_connect.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// "আজ কত পা হাঁটলেন" on the health page, for "আমি" (owner, 27 Oct): from
/// Health Connect when it is on; a button to get Health Connect on Android
/// 9–13 without it; nothing on older phones.
class HealthConnectCard extends StatefulWidget {
  const HealthConnectCard({super.key});

  @override
  State<HealthConnectCard> createState() => _HealthConnectCardState();
}

class _HealthConnectCardState extends State<HealthConnectCard> with WidgetsBindingObserver {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from Health Connect or the Play Store: look again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final brain = BrainScope.read(context);
    await brain.checkHealthConnect();
    if (brain.hcOn && brain.hcGranted) await brain.syncHealthConnect();
    if (mounted) setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    if (!_checked || brain.hcStatus == HcStatus.unsupported) return const SizedBox.shrink();
    final now = brain.services.now();
    Widget card(Widget child) => Padding(padding: const EdgeInsets.only(top: 10), child: Panel(key: const Key('health-hc'), child: child));

    if (brain.hcStatus == HcStatus.notInstalled) {
      return card(ListRow(
        leading: Icon(Icons.favorite_border_rounded, color: C.green),
        title: tr('আজ কত পা হাঁটলেন'),
        subtitle: tr('হাঁটা, ঘুম আর ব্যায়ামের হিসাব নিজে থেকে আনতে Google-এর Health Connect লাগবে'),
        trailing: TextButton(key: const Key('hc-install'), onPressed: brain.services.health.install, child: Text(tr('Health Connect নামান'))),
      ));
    }
    if (!brain.hcOn || !brain.hcGranted) {
      return card(ListRow(
        leading: Icon(Icons.favorite_border_rounded, color: C.green),
        title: tr('আজ কত পা হাঁটলেন'),
        subtitle: brain.hcOn ? tr('Health Connect-এ অনুমতি বন্ধ আছে — আবার দিলে দেখাবে') : tr('Health Connect থেকে হাঁটা, ঘুম আর ব্যায়াম — শুধু পড়বে, ফোনেই থাকবে'),
        trailing: TextButton(
          key: const Key('hc-start'),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthConnectIntro())),
          child: Text(tr('চালু করুন')),
        ),
      ));
    }
    final steps = brain.hcStepsToday ?? 0;
    final sleep = latest(brain.data, FamilyMember.meId, HealthKind.sleep);
    final ex = totalOn(brain.data, FamilyMember.meId, HealthKind.exercise, now);
    return card(ListRow(
      leading: Icon(Icons.directions_walk_rounded, color: C.green),
      title: trf('আজ {0} পা হাঁটলেন', [bnDigits(steps)]),
      subtitle: [
        if (steps > 0) trf('প্রায় {0} কিমি', [bnDigits(double.parse(stepsKm(steps).toStringAsFixed(1)))]),
        if (sleep != null && now.difference(sleep.at) < const Duration(hours: 30)) trf('গত রাতে ঘুম {0}', [readingText(sleep)]),
        if (ex > 0) trf('আজ ব্যায়াম {0} মিনিট', [bnDigits(ex.round())]),
        tr('Health Connect থেকে'),
      ].join(' · '),
      trailing: IconButton(
        key: const Key('hc-refresh'),
        tooltip: tr('আবার পড়ুন'),
        icon: const Icon(Icons.refresh_rounded),
        onPressed: () => brain.syncHealthConnect(force: true),
      ),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HealthConnectIntro())),
    ));
  }
}

/// Before the permission question: what is read, why, and that it stays on
/// this phone. Also where it is turned off again.
class HealthConnectIntro extends StatelessWidget {
  const HealthConnectIntro({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final on = brain.hcOn && brain.hcGranted;
    Widget point(IconData icon, String title, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: C.green, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: body(15, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(text, style: body(14, color: C.muted, height: 1.5)),
              ]),
            ),
          ]),
        );
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('Health Connect')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), children: [
              Text(tr('ফোনের স্বাস্থ্য-তথ্য থেকে শুধু পড়বে'), style: display(22, weight: 700)),
              const SizedBox(height: 8),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(children: [
                  point(Icons.visibility_outlined, tr('কী পড়বে'), tr('হাঁটার স্টেপ, ঘুমের সময় (ঘুমের ধাপসহ) আর ব্যায়ামের সময় — শুধু “আমি”-র জন্য। কিছু লিখবে না, বদলাবে না।')),
                  point(Icons.lightbulb_outline_rounded, tr('কেন পড়বে'), tr('স্বাস্থ্য পাতায় “আজ কত পা হাঁটলেন”, গত রাতের ঘুম আর ব্যায়ামের মিনিট দেখাতে; আর জিজ্ঞেস করলে (“আজ কত হাঁটলাম?”, “গত রাতে কত ঘুমিয়েছি?”) আসল সংখ্যা দিয়ে উত্তর দিতে।')),
                  point(Icons.phonelink_lock_outlined, tr('কোথায় থাকবে'), tr('শুধু এই ফোনে, অ্যাপের এনক্রিপ্ট করা ফাইলে। আমাদের সার্ভারে বা কারও কাছে যায় না।')),
                  point(Icons.edit_note_rounded, tr('হাতে লেখা'), tr('হাতে বা মুখে লেখা মাপ আগের মতোই থাকবে। Health Connect থেকে আনা মাপের পাশে উৎস লেখা থাকে, একই মাপ দুবার আসে না।')),
                  point(Icons.toggle_off_outlined, tr('বন্ধ করা'), tr('যেকোনো সময় এখান থেকে বা Health Connect-এর অনুমতি থেকে বন্ধ করা যায়।')),
                ]),
              ),
              const SizedBox(height: 12),
              InfoBanner(text: tr('পরের পাতায় Health Connect নিজে অনুমতি চাইবে। তিনটাই (স্টেপ, ঘুম, ব্যায়াম) দিলে চালু হবে।')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: on
                ? Row(children: [
                    Expanded(
                      child: SecondaryButton(
                        key: const Key('hc-off'),
                        label: tr('বন্ধ করুন'),
                        height: 52,
                        onPressed: () async {
                          await brain.turnOffHealthConnect();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SecondaryButton(
                        key: const Key('hc-forget'),
                        label: tr('বন্ধ করে আনা মাপ মুছুন'),
                        fg: C.red,
                        height: 52,
                        onPressed: () async {
                          final ok = await confirmDialog(context,
                              title: tr('Health Connect থেকে আনা মাপ মুছবেন?'), text: tr('হাতে লেখা মাপ থাকবে। Health Connect-এ রাখা তথ্যে কিছু হবে না।'), yes: tr('মুছুন'), danger: true);
                          if (!ok) return;
                          await brain.turnOffHealthConnect(forget: true);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ])
                : PrimaryButton(
                    key: const Key('hc-allow'),
                    label: tr('অনুমতি দিন'),
                    icon: Icons.favorite_rounded,
                    height: 52,
                    onPressed: () async {
                      final ok = await brain.turnOnHealthConnect();
                      if (!context.mounted) return;
                      if (ok) {
                        toast(context, tr('Health Connect চালু হলো'));
                        Navigator.of(context).pop();
                      } else {
                        toast(context, brain.hcStatus == HcStatus.available ? tr('তিনটা অনুমতিই লাগবে — আবার চেষ্টা করুন') : tr('এই ফোনে Health Connect পাওয়া যায়নি'));
                      }
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
