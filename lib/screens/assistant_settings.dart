import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../models/models.dart';
import '../services/platform.dart';
import '../state/brain.dart';
import '../ui/forms.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'notification_settings.dart';
import 'onboarding_screen.dart';
import '../ui/pdf_export.dart';

/// সেটিংস › সহকারী: summaries, nudges, memory, quick ways to open it.
class AssistantSection extends StatelessWidget {
  const AssistantSection({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    Widget sw(IconData icon, String title, String sub, bool v, ValueChanged<bool> on, {Widget? extra}) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(children: [
            Icon(icon, color: C.muted2, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: body(15)),
                Text(sub, style: body(12, color: C.muted)),
                if (extra != null) extra,
              ]),
            ),
            Switch(value: v, onChanged: on),
          ]),
        );

    Widget link(IconData icon, String title, String sub, VoidCallback onTap) => ListRow(
          leading: Icon(icon, color: C.muted2, size: 22),
          title: title,
          subtitle: sub,
          trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
          onTap: onTap,
        );

    return Panel(
      child: Rows(children: [
        link(Icons.notifications_active_outlined, tr('নোটিফিকেশন'), tr('সারাংশ, নিজে থেকে মনে করানো, জুমা, নামাজ — আর চুপ থাকার সময়'),
            () => push(const NotificationSettingsScreen())),
        sw(Icons.redo_rounded, tr('বাকি কাজ পরের দিনে'), tr('আগের দিনের না-হওয়া কাজ নিজে থেকে আজকের তালিকায় আসবে'), brain.carryOver, (v) => brain.setPref('carry_over', v)),
        link(Icons.psychology_alt_outlined, tr('সহকারীর স্মৃতি'),
            brain.data.memories.isEmpty ? tr('আপনার সম্পর্কে যা মনে রাখবে') : trf('{0}টি কথা মনে রাখা আছে', [bnDigits(brain.data.memories.length)]), () => push(const MemoryScreen())),
        link(Icons.badge_outlined, tr('আপনার পরিচয়'), brain.persona.isEmpty ? tr('বেছে নিলে তালিকা ও হিসাব সেভাবে সাজানো থাকবে') : personaLabel(brain.persona),
            () => push(const OnboardingScreen(fromSettings: true))),
        // ব্যবসায়ী মোড comes later (owner, 23 Oct); for now businesses keep
        // বকেয়া inside অন্যান্য হিসাব. Kept only for those who already turned it on.
        if (brain.businessMode)
          sw(Icons.storefront_outlined, tr('ব্যবসায়ী মোড'), tr('হিসাবে দিনের বিক্রি, কাস্টমারের বাকি, রসিদ'), brain.businessMode, (v) => brain.setPref('business_mode', v)),
        sw(Icons.mic_none_rounded, tr('নোটিফিকেশনে মাইক'), tr('উপর থেকে টেনে নামিয়ে এক চাপে বলুন'), brain.panelMic, (v) => brain.setPref('panel_mic', v)),
        link(Icons.touch_app_outlined, tr('ফোনের সহকারী বানান'), tr('হোম বোতাম চেপে ধরলেই My Assistant খুলবে'), () async {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(tr('ফোনের সহকারী বানান'), style: display(20)),
              content: Text(
                tr('পরের পাতায় “Default digital assistant app” বা “ডিজিটাল সহকারী অ্যাপ”-এ My Assistant বেছে নিন। তারপর হোম বোতাম চেপে ধরলে (বা কোণ থেকে টানলে) সরাসরি শোনা শুরু হবে।'),
                style: body(15, height: 1.5),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    AppPlatform.openAssistSettings();
                  },
                  child: Text(tr('পাতাটা খুলুন'), style: body(15, weight: FontWeight.w600, color: C.green)),
                ),
              ],
            ),
          );
        }),
      ]),
    );
  }
}

/// সহকারীর স্মৃতি: what the assistant keeps in mind about the user.
class MemoryScreen extends StatelessWidget {
  const MemoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final list = [...brain.data.memories]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    Future<void> add() async {
      final t = await askText(context, tr('কী মনে রাখবে?'), hint: tr('যেমন: আমি শুক্রবার অফিস করি না'), lines: 2);
      if (t != null && t.isNotEmpty) await brain.addMemory(t);
    }

    return Scaffold(
      floatingActionButton: AddButton(label: tr('যোগ করুন'), onPressed: add),
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('সহকারীর স্মৃতি'), trailing: const [PdfButton({ReportPart.memories})]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 100), children: [
              InfoBanner(
                text: tr('এখানে লেখা কথাগুলো সহকারী উত্তর দেওয়ার সময় মনে রাখে। মুখেও বলা যায়: “মনে রেখো, রহিম আমার শ্যালক”। AI চালু থাকলে এগুলো উত্তর তৈরিতে পাঠানো হয়; পাসওয়ার্ড বা গোপন কিছু এখানে লিখবেন না।'),
                icon: Icons.psychology_alt_outlined,
              ),
              const SizedBox(height: 14),
              if (list.isEmpty)
                EmptyState(icon: Icons.psychology_alt_outlined, title: tr('এখনো কিছু নেই'), text: tr('আপনার অভ্যাস, পছন্দ বা কাছের মানুষদের কথা লিখে রাখুন।'))
              else
                Panel(
                  child: Rows(children: [
                    for (final m in list)
                      ListRow(
                        leading: Icon(Icons.bookmark_outline_rounded, color: C.green),
                        title: m.text,
                        subtitle: shortDate(m.createdAt),
                        trailing: IconButton(
                          tooltip: tr('মুছুন'),
                          icon: Icon(Icons.delete_outline_rounded, color: C.muted),
                          onPressed: () => brain.deleteMemory(m.id),
                        ),
                        onTap: () async {
                          final t = await askText(context, tr('বদলান'), initial: m.text, lines: 2);
                          if (t != null && t.isNotEmpty) await brain.editMemory(m, t);
                        },
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

/// The memories as lines for the AI (anything secret-looking left out).
String memoryLines(AppData d) => d.memories.map((m) => '- ${m.text}').join('\n');
