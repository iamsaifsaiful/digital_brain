import 'package:flutter/material.dart';

import '../logic/app_map.dart';
import '../logic/lang.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'app_places.dart';
import 'home_shell.dart';

const _icons = <String, IconData>{
  'home': Icons.home_outlined,
  'tasks': Icons.checklist_rounded,
  'reminders': Icons.notifications_active_outlined,
  'alarms': Icons.alarm_rounded,
  'calendar': Icons.calendar_month_outlined,
  'special': Icons.cake_outlined,
  'notes': Icons.sticky_note_2_outlined,
  'docs': Icons.folder_copy_outlined,
  'vault': Icons.key_rounded,
  'contacts': Icons.call_outlined,
  'inbox': Icons.mark_chat_unread_outlined,
  'money': Icons.account_balance_wallet_outlined,
  'ledger': Icons.payments_outlined,
  'projects': Icons.work_outline_rounded,
  'report': Icons.insert_chart_outlined_rounded,
  'accounts': Icons.account_balance_outlined,
  'savings': Icons.savings_outlined,
  'zakat': Icons.volunteer_activism_outlined,
  'split': Icons.call_split_rounded,
  'shop': Icons.storefront_outlined,
  'health': Icons.favorite_border_rounded,
  'medicines': Icons.medication_outlined,
  'habits': Icons.local_fire_department_outlined,
  'diary': Icons.menu_book_outlined,
  'emergency': Icons.emergency_outlined,
  'expiry': Icons.event_busy_outlined,
  'tags': Icons.sell_outlined,
  'memory': Icons.psychology_outlined,
  'templates': Icons.checklist_rtl_rounded,
  'settings': Icons.settings_outlined,
  'notifications': Icons.notifications_outlined,
  'sound': Icons.music_note_outlined,
  'backup': Icons.cloud_download_outlined,
};

/// "অ্যাপ দিয়ে কী কী করা যায়": every part of the app, what it does, what to
/// say, and a tap to open it. Built from the same list the assistant uses,
/// so it is always up to date.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final places = [for (final p in appPlaces) if (_icons.containsKey(p.id)) p];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('কী কী করা যায়')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
              Panel(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.mic_none_rounded, color: C.green),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tr('মুখে বলুন বা লিখুন'), style: body(16, weight: FontWeight.w600))),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                      tr('নিচের বক্সে লিখুন বা মাইক চাপুন — স্বাভাবিকভাবে বলুন, একসাথে কয়েকটা কথাও। যেকোনো পাতা খুলতে নাম বলে “খোলো” বলুন, যেমন “নোট খোলো”, “স্বাস্থ্যের পাতায় যাও”, “প্রেসক্রিপশন ফোল্ডার খোলো”। বাঁকা হরফের কথাগুলো হুবহু বলে দেখুন।'),
                      style: body(14, color: C.muted2, height: 1.5)),
                ]),
              ),
              const SizedBox(height: 10),
              for (final p in places) ...[
                Panel(
                  padding: const EdgeInsets.all(14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(12)),
                        child: Icon(_icons[p.id], color: C.green, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(tr(p.title), style: body(16, weight: FontWeight.w600))),
                      TextButton(onPressed: () => openPlace(context, p.id), child: Text(tr('খুলুন'))),
                    ]),
                    const SizedBox(height: 8),
                    Text(tr(p.what), style: body(14, color: C.muted2, height: 1.5)),
                    for (final x in p.say)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('“${tr(x)}”', style: body(14, color: C.greenDark).copyWith(fontStyle: FontStyle.italic)),
                      ),
                  ]),
                ),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
              PrimaryButton(label: tr('মাইকে বলে দেখুন'), icon: Icons.mic_none_rounded, onPressed: () => openVoice(context)),
            ]),
          ),
        ]),
      ),
    );
  }
}
