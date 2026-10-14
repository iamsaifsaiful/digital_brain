import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../logic/cash.dart';
import '../logic/ledger.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import 'alarm_list_screen.dart';
import 'calendar_screen.dart';
import 'docs_screen.dart';
import 'calls_screen.dart';
import 'home_screen.dart';
import 'health_hub.dart';
import 'home_shell.dart';
import 'ledger_screen.dart';
import 'more_screen.dart';
import 'settings_parts.dart';
import 'easy_home.dart';
import 'notes_screen.dart';
import 'plan_screens.dart';
import 'search_screen.dart';
import 'vault_screen.dart';
import '../logic/lang.dart';

String helloFor(DateTime now) {
  final h = now.hour;
  if (h >= 4 && h < 11) return tr('সুপ্রভাত');
  if (h >= 11 && h < 15) return tr('শুভ দুপুর');
  if (h >= 15 && h < 18) return tr('শুভ বিকেল');
  if (h >= 18 && h < 22) return tr('শুভ সন্ধ্যা');
  return tr('শুভ রাত');
}

/// হোম: today at a glance — both dates, sun times, the coming holiday,
/// what is due, money, and shortcuts to everything.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final bd = banglaDate(now);
    final hj = hijriDate(now, adjust: brain.number('hijri_adjust'));
    final sun = sunTimes(now, placeNamed(brain.district));
    final runs = upcomingHolidays(now, count: 1);
    final next = runs.isEmpty ? null : runs.first;
    final daysTo = next == null ? 0 : DateTime(next.start.year, next.start.month, next.start.day).difference(DateTime(now.year, now.month, now.day)).inDays;
    final t = totals(d.ledger);
    final month = monthSums(d.cash, now);
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final top = MediaQuery.of(context).padding.top;

    Widget dateChip(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: body(12, color: Colors.white70, height: 1.3)),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600, color: Colors.white, height: 1.35)),
            ]),
          ),
        );

    final shortcuts = <(String, IconData, Color, Color, VoidCallback)>[
      (tr('অ্যালার্ম'), Icons.alarm_rounded, C.orange, C.orangeTint, () => push(const AlarmsScreen())),
      (tr('রিমাইন্ডার'), Icons.notifications_none_rounded, C.orange, C.orangeTint, () => push(const AllTasksScreen())),
      (tr('কাজের তালিকা'), Icons.checklist_rounded, C.green, C.greenTint, () => goToTab(context, ShellTab.diary)),
      (tr('আয়-ব্যয়'), Icons.account_balance_wallet_outlined, C.green, C.greenTint, () => goToTab(context, ShellTab.money, money: MoneyPart.cash)),
      (tr('লেনদেন'), Icons.payments_outlined, C.teal, C.tealTint, () => goToTab(context, ShellTab.money, money: MoneyPart.loans)),
      (tr('নোট'), Icons.sticky_note_2_outlined, C.ochre, C.ochreTint, () => push(const NotesScreen())),
      (tr('ডকুমেন্টস'), Icons.folder_copy_outlined, C.blue, C.blueTint, () => push(const DocsScreen())),
      (tr('পাসওয়ার্ড'), Icons.lock_outline_rounded, C.ink, C.soft, () => push(const VaultPage())),
      (tr('যোগাযোগ'), Icons.call_outlined, C.purple, C.purpleTint, () => push(const CallsScreen())),
      (tr('বাংলা তারিখ'), Icons.eco_outlined, C.teal, C.tealTint, () => push(const CalendarScreen())),
      (tr('স্বাস্থ্য'), Icons.favorite_border_rounded, C.rose, C.roseTint, () => push(const HealthScreen())),
      (tr('খুঁজুন'), Icons.search_rounded, C.ink, C.soft, () => push(const SearchScreen())),
    ];

    if (brain.easyMode) return const EasyHome();

    return Column(children: [
      Expanded(
        child: ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(20, top + 14, 20, 18),
          decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${helloFor(now)}${brain.userName.isEmpty ? '' : ','}', style: body(14, color: Colors.white70)),
                  Text(brain.userName.isEmpty ? tr('আজ কী করে দেবো?') : brain.userName,
                      style: display(24, weight: 700, color: Colors.white, height: 1.25), maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
              IconButton(
                tooltip: tr('সেটিংস'),
                onPressed: () => push(const MenuPage(child: MoreScreen())),
                icon: const Icon(Icons.settings_outlined, color: Colors.white),
              ),
              const SizedBox(width: 2),
              Tooltip(
                message: tr('প্রোফাইল'),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => push(const MenuPage(child: MoreScreen())),
                  child: const UserPhoto(size: 44, onDark: true),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            InkWell(
              onTap: () => push(const CalendarScreen()),
              child: Row(children: [
                dateChip(tr('আজ'), '${weekdayName(now)}, ${bnDigits(now.day)} ${monthName(now.month)}'),
                const SizedBox(width: 10),
                dateChip(trf('বাংলা · {0}কাল', [bd.season]), bd.text),
              ]),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => push(const CalendarScreen()),
              child: Row(children: [
                const Icon(Icons.nightlight_round, size: 16, color: Color(0xFFFDE68A)),
                const SizedBox(width: 6),
                Flexible(child: Text(trf('হিজরি · {0}', [hj.short]), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13.5, weight: FontWeight.w500, color: Colors.white))),
              ]),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => push(const CalendarScreen()),
              child: Wrap(spacing: 14, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wb_twilight, size: 17, color: Color(0xFFFDE68A)),
                  const SizedBox(width: 5),
                  Text(trf('সূর্যোদয় {0}', [bnTime(sun.sunrise.hour, sun.sunrise.minute)]), style: body(13, color: Colors.white)),
                ]),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.nights_stay_outlined, size: 17, color: Color(0xFFFDBA74)),
                  const SizedBox(width: 5),
                  Text(trf('সূর্যাস্ত {0}', [bnTime(sun.sunset.hour, sun.sunset.minute)]), style: body(13, color: Colors.white)),
                ]),
                Text('· ${tr(brain.district)}', style: body(13, color: Colors.white70)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (next != null && daysTo <= 30)
              Material(
                color: C.roseTint,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => push(const CalendarScreen()),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                    child: Row(children: [
                      Icon(Icons.flag_outlined, color: C.rose),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(daysTo == 0 ? trf('আজ ছুটি — {0}', [next.label]) : trf('{0} — ছুটি আসছে', [next.label]),
                              style: body(15, weight: FontWeight.w600, color: C.roseDark)),
                          Text(
                              '${holidayRange(next)}${next.days > 1 ? ' · ${trf('টানা {0} দিন', [bnDigits(next.days)])}' : ''}${daysTo > 0 ? ' · ${trf('{0} দিন পর', [bnDigits(daysTo)])}' : ''}',
                              style: body(13, color: C.roseDark)),
                        ]),
                      ),
                      Icon(Icons.chevron_right_rounded, color: C.roseDark),
                    ]),
                  ),
                ),
              ),
            const StartTips(),
            if (d.reminders.isNotEmpty) const AlarmBanner(),
            const TodaySections(),
            const SizedBox(height: 6),
            Material(
              color: C.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => goToTab(context, ShellTab.money),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(children: [
                    _Figure(tr('পাওনা'), taka(t.receivable), C.green),
                    _Figure(tr('দেনা'), taka(t.payable), C.orange),
                    _Figure(tr('এ মাসে খরচ'), taka(month.expense), C.ink),
                    Icon(Icons.chevron_right_rounded, color: C.muted),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
              child: Text(tr('সব কিছু এক জায়গায়'), style: body(13, weight: FontWeight.w600, color: C.muted)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.95,
                children: [
                  for (final (label, icon, fg, bg, onTap) in shortcuts)
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onTap,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(13)),
                          child: Icon(icon, color: fg, size: 22),
                        ),
                        const SizedBox(height: 6),
                        Text(label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, height: 1.2)),
                      ]),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ],
        ),
      ),
    ]);
  }
}

class _Figure extends StatelessWidget {
  const _Figure(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: body(12, color: C.muted)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(16, weight: FontWeight.w600, color: color)),
        ]),
      );
}

/// "২০–২৪ অক্টোবর", or "১৬ ডিসেম্বর".
String holidayRange(HolidayRun r) {
  if (r.days == 1) return '${bnDigits(r.start.day)} ${monthName(r.start.month)}';
  if (r.start.month == r.end.month) return '${bnDigits(r.start.day)}–${bnDigits(r.end.day)} ${monthName(r.start.month)}';
  return '${bnDigits(r.start.day)} ${monthName(r.start.month)} – ${bnDigits(r.end.day)} ${monthName(r.end.month)}';
}
