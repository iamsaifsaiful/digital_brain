import 'package:flutter/material.dart';

import 'google_backup.dart';

import '../ui/pro_gate.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../logic/cash.dart';
import '../logic/proactive.dart' show tasksLeft, remindsOn;
import '../state/brain.dart';
import '../ui/theme.dart';
import 'alarm_list_screen.dart';
import 'calendar_screen.dart';
import 'docs_screen.dart';
import 'calls_screen.dart';
import 'home_screen.dart';
import 'health_hub.dart';
import 'home_shell.dart';
import 'inbox_screen.dart';
import 'settings_parts.dart';
import 'easy_home.dart';
import 'notes_screen.dart';
import 'plan_screens.dart';
import 'vault_screen.dart';
import 'requests_screen.dart';
import 'pro_screen.dart';
import '../logic/inbox.dart' show inboxTodo;
import '../logic/lang.dart';

String helloFor(DateTime now) {
  final h = now.hour;
  if (h >= 4 && h < 11) return tr('সুপ্রভাত');
  if (h >= 11 && h < 15) return tr('শুভ দুপুর');
  if (h >= 15 && h < 18) return tr('শুভ বিকেল');
  if (h >= 18 && h < 22) return tr('শুভ সন্ধ্যা');
  return tr('শুভ রাত');
}

/// হোম: a warm welcome — the day (Bangla, English and Hijri dates, sun
/// times), what is waiting today, every part of the app one tap away, then
/// today's list.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final today = dayOnly(now);
    final bd = banglaDate(now);
    final hj = hijriDate(now, adjust: brain.number('hijri_adjust'));
    final sun = sunTimes(now, placeNamed(brain.district));
    final runs = upcomingHolidays(now, count: 1);
    final next = runs.isEmpty ? null : runs.first;
    final daysTo = next == null ? 0 : DateTime(next.start.year, next.start.month, next.start.day).difference(today).inDays;
    final month = monthSums(d.cash, now);
    final left = tasksLeft(d, now).length;
    final remindersToday = [for (final r in d.reminders) if (r.enabled && remindsOn(r, today) && DateTime(today.year, today.month, today.day, r.hour, r.minute).isAfter(now)) r]
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final top = MediaQuery.of(context).padding.top;
    final first = brain.userName.trim().isEmpty ? '' : brain.userName.trim().split(' ').first;

    // Most used first: the day's work, then money, then the rest.
    final shortcuts = <(String, IconData, Color, Color, VoidCallback)>[
      (tr('কাজের তালিকা'), Icons.checklist_rounded, C.green, C.greenTint, () => goToTab(context, ShellTab.diary)),
      (tr('রিমাইন্ডার'), Icons.notifications_none_rounded, C.orange, C.orangeTint, () => push(const AllTasksScreen())),
      (tr('হিসাব'), Icons.account_balance_wallet_outlined, C.teal, C.tealTint, () => goToTab(context, ShellTab.money)),
      (tr('ক্যালেন্ডার'), Icons.calendar_month_outlined, C.blue, C.blueTint, () => push(const CalendarScreen())),
      (tr('নোট'), Icons.sticky_note_2_outlined, C.ochre, C.ochreTint, () => push(const NotesScreen())),
      (tr('ডকুমেন্টস'), Icons.folder_copy_outlined, C.blue, C.blueTint, () => push(const DocsScreen())),
      (tr('যোগাযোগ'), Icons.call_outlined, C.purple, C.purpleTint, () => push(const CallsScreen())),
      (tr('স্বাস্থ্য'), Icons.favorite_border_rounded, C.rose, C.roseTint, () => push(const HealthScreen())),
      (tr('অ্যালার্ম'), Icons.alarm_rounded, C.orange, C.orangeTint, () => push(const AlarmsScreen())),
      (tr('পাসওয়ার্ড'), Icons.lock_outline_rounded, C.ink, C.soft, () => push(const VaultPage())),
      (tr('অনুরোধ'), Icons.bloodtype_outlined, C.rose, C.roseTint, () => push(const RequestsScreen())),
      if (brain.inboxSupported) (tr('মেসেজ থেকে কাজ'), Icons.mark_chat_unread_outlined, C.green, C.greenTint, () => push(const InboxScreen())),
      (tr('প্রো ভার্সন'), Icons.workspace_premium_outlined, C.ochre, C.ochreTint, () => push(const ProScreen())),
    ];
    final inboxTodos = inboxTodo(d, now);

    if (brain.easyMode) return const EasyHome();

    Widget stat(Key key, IconData icon, Color color, String value, String label, VoidCallback onTap) => Expanded(
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Column(children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(17, weight: 700)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
              ]),
            ),
          ),
        );

    return Column(children: [
      Expanded(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // The greeting, on the accent colour with two soft circles.
            Container(
              padding: EdgeInsets.fromLTRB(20, top + 16, 20, 52),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [C.green, Color.lerp(C.green, C.teal, 0.55)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(right: -40, top: -50, child: _Bubble(size: 150)),
                Positioned(left: -60, bottom: -70, child: _Bubble(size: 120)),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(first.isEmpty ? helloFor(now) : '${helloFor(now)},', style: body(15, color: Colors.white.withValues(alpha: 0.85))),
                        Text(first.isEmpty ? tr('আজ কী করে দেবো?') : first,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: display(28, weight: 700, color: Colors.white, height: 1.2)),
                      ]),
                    ),
                    Tooltip(
                      message: tr('প্রোফাইল'),
                      child: InkWell(customBorder: const CircleBorder(), onTap: () => goToTab(context, ShellTab.more), child: const UserPhoto(size: 48, onDark: true)),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => push(const CalendarScreen()),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${weekdayName(now)}, ${bnDigits(now.day)} ${monthName(now.month)}', style: display(18, weight: 700, color: Colors.white)),
                      const SizedBox(height: 2),
                      Wrap(spacing: 6, children: [
                        Text(bd.text, style: body(13.5, color: Colors.white.withValues(alpha: 0.9))),
                        Text('·', style: body(13.5, color: Colors.white70)),
                        Text(trf('{0}কাল', [bd.season]), style: body(13.5, color: Colors.white.withValues(alpha: 0.9))),
                        Text('·', style: body(13.5, color: Colors.white70)),
                        Text(hj.dayMonth, style: body(13.5, color: Colors.white.withValues(alpha: 0.9))),
                      ]),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 6, children: [
                        _Chip(icon: Icons.wb_twilight, text: trf('সূর্যোদয় {0}', [bnTime(sun.sunrise.hour, sun.sunrise.minute)])),
                        _Chip(icon: Icons.nights_stay_outlined, text: trf('সূর্যাস্ত {0}', [bnTime(sun.sunset.hour, sun.sunset.minute)])),
                      ]),
                    ]),
                  ),
                ]),
              ]),
            ),
            // What is waiting today, on a card that rises over the greeting.
            Transform.translate(
              offset: const Offset(0, -34),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: C.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: C.dark ? 0.35 : 0.08), blurRadius: 18, offset: const Offset(0, 6))],
                  ),
                  child: Row(children: [
                    stat(const Key('home-stat-tasks'), Icons.checklist_rounded, C.green, left == 0 ? tr('সব শেষ') : trf('{0}টা', [bnDigits(left)]), tr('আজকের কাজ'),
                        () => goToTab(context, ShellTab.diary)),
                    Container(width: 1, height: 40, color: C.line2),
                    stat(
                        const Key('home-stat-reminders'),
                        Icons.notifications_none_rounded,
                        C.orange,
                        remindersToday.isEmpty ? tr('নেই') : bnTime(remindersToday.first.hour, remindersToday.first.minute),
                        remindersToday.isEmpty ? tr('আজ রিমাইন্ডার') : (remindersToday.length == 1 ? tr('পরের রিমাইন্ডার') : trf('পরেরটা · মোট {0}টা', [bnDigits(remindersToday.length)])),
                        () => push(const AllTasksScreen())),
                    Container(width: 1, height: 40, color: C.line2),
                    stat(const Key('home-stat-spent'), Icons.account_balance_wallet_outlined, C.teal, taka(month.expense), tr('এ মাসে খরচ'), () => goToTab(context, ShellTab.money)),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (inboxTodos.isNotEmpty) ...[
                    _Banner(
                      color: C.greenTint,
                      fg: C.greenDark,
                      icon: Icons.mark_chat_unread_outlined,
                      title: trf('মেসেজ থেকে {0}টা কাজ', [bnDigits(inboxTodos.length)]),
                      text: inboxTodos.first.$2.summary,
                      onTap: () => push(const InboxScreen()),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (next != null && daysTo <= 30) ...[
                    _Banner(
                      color: C.roseTint,
                      fg: C.roseDark,
                      icon: Icons.flag_outlined,
                      title: daysTo == 0 ? trf('আজ ছুটি — {0}', [next.label]) : trf('{0} — ছুটি আসছে', [next.label]),
                      text:
                          '${holidayRange(next)}${next.days > 1 ? ' · ${trf('টানা {0} দিন', [bnDigits(next.days)])}' : ''}${daysTo > 0 ? ' · ${trf('{0} দিন পর', [bnDigits(daysTo)])}' : ''}',
                      onTap: () => push(const CalendarScreen()),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
                    child: Text(tr('সব কিছু এক জায়গায়'), style: display(17, weight: 700)),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                    decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(20)),
                    child: GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 0.92,
                      children: [
                        for (final (label, icon, fg, bg, onTap) in shortcuts)
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: onTap,
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                                child: Icon(icon, color: fg, size: 25),
                              ),
                              const SizedBox(height: 7),
                              Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12.5, weight: FontWeight.w500, height: 1.2)),
                            ]),
                          ),
                      ],
                    ),
                  ),
                  const StartTips(),
                  const SizedBox(height: 14),
                  const GoogleStartCard(),
                  if (d.reminders.isNotEmpty) const AlarmBanner(),
                  const TodaySections(),
                ]),
              ),
            ),
          ],
        ),
      ),
      const AdSlot(padding: EdgeInsets.fromLTRB(16, 4, 16, 6)),
    ]);
  }
}

/// A soft white circle behind the greeting.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08))),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: const Color(0xFFFDE68A)),
          const SizedBox(width: 5),
          Text(text, style: body(12.5, weight: FontWeight.w500, color: Colors.white)),
        ]),
      );
}

/// A slim, tappable notice (a holiday coming, tasks from messages).
class _Banner extends StatelessWidget {
  const _Banner({required this.color, required this.fg, required this.icon, required this.title, required this.text, required this.onTap});
  final Color color;
  final Color fg;
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(children: [
              Icon(icon, color: fg),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: body(15, weight: FontWeight.w600, color: fg)),
                  Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, color: fg)),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: fg),
            ]),
          ),
        ),
      );
}

/// "২০–২৪ অক্টোবর", or "১৬ ডিসেম্বর".
String holidayRange(HolidayRun r) {
  if (r.days == 1) return '${bnDigits(r.start.day)} ${monthName(r.start.month)}';
  if (r.start.month == r.end.month) return '${bnDigits(r.start.day)}–${bnDigits(r.end.day)} ${monthName(r.start.month)}';
  return '${bnDigits(r.start.day)} ${monthName(r.start.month)} – ${bnDigits(r.end.day)} ${monthName(r.end.month)}';
}
