import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../logic/lang.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import 'calls_screen.dart';
import 'diary_screen.dart';
import 'home_page.dart';
import 'home_shell.dart';
import 'plan_screens.dart';
import 'settings_parts.dart';

/// সহজ মোড: big letters and four big buttons, for elders and anyone who
/// would rather just talk. Everything else is still one tap away below.
class EasyHome extends StatelessWidget {
  const EasyHome({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final today = itemsOn(brain.data, now, now).where((i) => i.task == null || !i.task!.done).toList();
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    Widget big(String label, IconData icon, Color fg, Color bg, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            label: label,
            excludeSemantics: true,
            child: Material(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon, size: 52, color: fg),
                    const SizedBox(height: 10),
                    Text(label, textAlign: TextAlign.center, style: display(20, weight: 700, color: fg)),
                  ]),
                ),
              ),
            ),
          ),
        );

    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 24), children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${helloFor(now)}${brain.userName.isEmpty ? '' : ', ${brain.userName}'}', style: display(24, weight: 700)),
              Text('${weekdayName(now)}, ${fullDate(now)}', style: body(18, color: C.muted2)),
              Text(banglaDate(now).text, style: body(17, color: C.muted)),
            ]),
          ),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => goToTab(context, ShellTab.more),
            child: const UserPhoto(size: 56),
          ),
        ]),
        const SizedBox(height: 18),
        Material(
          color: C.green,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => openVoice(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Column(children: [
                const Icon(Icons.mic_rounded, color: Colors.white, size: 64),
                const SizedBox(height: 8),
                Text(tr('চাপুন, তারপর বলুন'), style: display(24, weight: 700, color: Colors.white)),
                Text(tr('যেমন: “আজ আমার কী কী আছে?”'), style: body(16, color: Colors.white70)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          big(tr('আজকের কাজ'), Icons.event_note_rounded, C.orange, C.orangeTint, () => goToTab(context, ShellTab.diary)),
          const SizedBox(width: 12),
          big(tr('হিসাব'), Icons.account_balance_wallet_rounded, C.blue, C.blueTint, () => goToTab(context, ShellTab.money)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          big(tr('ফোন করুন'), Icons.call_rounded, C.purple, C.purpleTint, () => push(const CallsScreen())),
          const SizedBox(width: 12),
          big(tr('সব কাজ'), Icons.checklist_rounded, C.green, C.greenTint, () => push(const AllTasksScreen())),
        ]),
        const SizedBox(height: 18),
        Text(today.isEmpty ? tr('আজ কিছু রাখা নেই') : trf('আজ {0}টা জিনিস', [bnDigits(today.length)]), style: display(20, weight: 700)),
        const SizedBox(height: 8),
        for (final i in today.take(6))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                Icon(i.reminder != null ? Icons.alarm_rounded : Icons.check_box_outline_blank_rounded, size: 28, color: i.reminder != null ? C.orange : C.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    i.reminder != null ? '${bnTime(i.reminder!.hour, i.reminder!.minute)} — ${i.reminder!.title}' : i.task!.title,
                    style: body(19, weight: FontWeight.w500),
                  ),
                ),
                if (i.task != null)
                  IconButton(
                    tooltip: tr('হয়ে গেছে'),
                    iconSize: 32,
                    onPressed: () => brain.setTaskDone(i.task!, true),
                    icon: Icon(Icons.check_circle_outline_rounded, color: C.green),
                  ),
              ]),
            ),
          ),
        if (today.isEmpty) Text(tr('বলুন — “কাল সকাল ১০টায় ডাক্তারের কাছে যাওয়ার কথা মনে করিয়ে দিও”।'), style: body(17, color: C.muted, height: 1.5)),
      ]),
    );
  }
}
