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
import 'home_sky.dart';
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
    final doneToday = [for (final t in d.tasks) if (t.done && t.doneAt != null && dayOnly(t.doneAt!) == today) t].length;
    final allTasks = left + doneToday;
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

    Widget stat(Key key, Widget lead, String value, String label, VoidCallback onTap) => Expanded(
          child: InkWell(
            key: key,
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(children: [
                SizedBox(height: 34, child: Center(child: lead)),
                const SizedBox(height: 6),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(17, weight: 700)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
              ]),
            ),
          ),
        );
    Widget badge(IconData icon, Color fg, Color bg) => Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, color: fg, size: 19),
        );

    const shade = [Shadow(color: Color(0x66000000), blurRadius: 8)];
    final white = Colors.white;
    final soft = Colors.white.withValues(alpha: 0.88);
    const horizon = 78.0;
    final daytime = now.isAfter(sun.sunrise) && now.isBefore(sun.sunset);
    final until = daytime
        ? trf('সূর্যাস্তের আর {0}', [_span(sun.sunset.difference(now))])
        : trf('সূর্যোদয়ের আর {0}', [_span((now.isBefore(sun.sunrise) ? sun.sunrise : sun.sunrise.add(const Duration(days: 1))).difference(now))]);

    return Column(children: [
      Expanded(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // The greeting, under today's sky: the sun where it is now.
            SizedBox(
              height: top + 318,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
                child: HomeSky(
                now: now,
                sunrise: sun.sunrise,
                sunset: sun.sunset,
                horizon: horizon,
                child: Stack(children: [
                  Positioned(
                    left: 20,
                    right: 16,
                    top: top + 14,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(first.isEmpty ? helloFor(now) : '${helloFor(now)},', style: body(15, color: soft).copyWith(shadows: shade)),
                            Text(first.isEmpty ? tr('আজ কী করে দেবো?') : first,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: display(30, weight: 700, color: white, height: 1.15).copyWith(shadows: shade)),
                          ]),
                        ),
                        Tooltip(
                          message: tr('প্রোফাইল'),
                          child: InkWell(customBorder: const CircleBorder(), onTap: () => goToTab(context, ShellTab.more), child: const UserPhoto(size: 46, onDark: true)),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => push(const CalendarScreen()),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${weekdayName(now)}, ${bnDigits(now.day)} ${monthName(now.month)}', style: display(17, weight: 700, color: white).copyWith(shadows: shade)),
                          Text('${bd.text}, ${trf('{0}কাল', [bd.season])}', style: body(13.5, color: soft).copyWith(shadows: shade)),
                          Text(hj.dayMonth, style: body(13.5, color: soft).copyWith(shadows: shade)),
                        ]),
                      ),
                    ]),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: horizon + 8,
                    child: Text(until, textAlign: TextAlign.center, style: body(12.5, weight: FontWeight.w600, color: white).copyWith(shadows: shade)),
                  ),
                  Positioned(
                    left: 18,
                    bottom: 42,
                    child: _SunLabel(icon: Icons.wb_twilight, text: trf('সূর্যোদয় {0}', [bnTime(sun.sunrise.hour, sun.sunrise.minute)])),
                  ),
                  Positioned(
                    right: 18,
                    bottom: 42,
                    child: _SunLabel(icon: Icons.nights_stay_outlined, text: trf('সূর্যাস্ত {0}', [bnTime(sun.sunset.hour, sun.sunset.minute)])),
                  ),
                ]),
                ),
              ),
            ),
            // What is waiting today, on a card that rises over the fields.
            Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: C.surface,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: C.dark ? 0.4 : 0.12), blurRadius: 24, offset: const Offset(0, 10))],
                  ),
                  child: Row(children: [
                    stat(
                        const Key('home-stat-tasks'),
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: Stack(alignment: Alignment.center, children: [
                            CircularProgressIndicator(
                              value: allTasks == 0 ? 1 : doneToday / allTasks,
                              strokeWidth: 3.5,
                              strokeCap: StrokeCap.round,
                              color: C.green,
                              backgroundColor: C.greenTint,
                            ),
                            Icon(left == 0 ? Icons.check_rounded : Icons.checklist_rounded, size: 16, color: C.green),
                          ]),
                        ),
                        left == 0 ? tr('সব শেষ') : trf('{0}টা বাকি', [bnDigits(left)]),
                        tr('আজকের কাজ'),
                        () => goToTab(context, ShellTab.diary)),
                    Container(width: 1, height: 44, color: C.line2),
                    stat(
                        const Key('home-stat-reminders'),
                        badge(Icons.notifications_none_rounded, C.orange, C.orangeTint),
                        remindersToday.isEmpty ? tr('নেই') : bnTime(remindersToday.first.hour, remindersToday.first.minute),
                        remindersToday.isEmpty ? tr('আজ রিমাইন্ডার') : (remindersToday.length == 1 ? tr('পরের রিমাইন্ডার') : trf('পরেরটা, মোট {0}টা', [bnDigits(remindersToday.length)])),
                        () => push(const AllTasksScreen())),
                    Container(width: 1, height: 44, color: C.line2),
                    stat(const Key('home-stat-spent'), badge(Icons.account_balance_wallet_outlined, C.teal, C.tealTint), taka(month.expense), tr('এ মাসে খরচ'),
                        () => goToTab(context, ShellTab.money)),
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

/// "২ ঘণ্টা ১০ মিনিট"
String _span(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return trf('{0} মিনিট', [bnDigits(m)]);
  if (m == 0) return trf('{0} ঘণ্টা', [bnDigits(h)]);
  return trf('{0} ঘণ্টা {1} মিনিট', [bnDigits(h), bnDigits(m)]);
}

class _SunLabel extends StatelessWidget {
  const _SunLabel({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: const Color(0xFFFDE68A)),
          const SizedBox(width: 4),
          Text(text, style: body(12.5, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.92))),
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
