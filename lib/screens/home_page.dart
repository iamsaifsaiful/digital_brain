import 'package:flutter/material.dart';

import 'google_backup.dart';

import '../ui/pro_gate.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../logic/cash.dart';
import '../logic/ledger.dart' show totals;
import '../state/brain.dart';
import '../ui/theme.dart';
import 'alarm_list_screen.dart';
import 'calendar_screen.dart';
import 'compass_screen.dart';
import 'spend_health_screen.dart';
import '../logic/spend_health.dart';
import '../logic/money_quotes.dart';
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
import 'zakat_screen.dart';
import 'family_screen.dart';
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

/// হোম, content first: a short greeting under today's sky, then what is
/// to be done today, this month's money, what is coming, and every part of
/// the app — on plain cards, colour only where it means something.
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
    final owe = totals(d.ledger);
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final top = MediaQuery.of(context).padding.top;
    final first = brain.userName.trim().isEmpty ? '' : brain.userName.trim().split(' ').first;
    final inboxTodos = inboxTodo(d, now);
    final week = spendHealth(d, now);
    final weekWarn = week.hasIncome && (week.pct(week.wants) > wantCap || week.spent > week.income);
    final quote = quoteFor(now);

    // Most used first: the day's work, then money, then the rest.
    final shortcuts = <(String, IconData, Color, Color, VoidCallback)>[
      (tr('কাজের তালিকা'), Icons.checklist_rounded, C.green, C.greenTint, () => goToTab(context, ShellTab.diary)),
      (tr('রিমাইন্ডার'), Icons.notifications_none_rounded, C.orange, C.orangeTint, () => push(const AllTasksScreen())),
      (tr('হিসাব'), Icons.account_balance_wallet_outlined, C.teal, C.tealTint, () => goToTab(context, ShellTab.money)),
      (tr('ডকুমেন্টস'), Icons.folder_copy_outlined, C.blue, C.blueTint, () => push(const DocsScreen())),
      (tr('নোট'), Icons.sticky_note_2_outlined, C.ochre, C.ochreTint, () => push(const NotesScreen())),
      (tr('যোগাযোগ'), Icons.call_outlined, C.purple, C.purpleTint, () => push(const CallsScreen())),
      (tr('স্বাস্থ্য'), Icons.favorite_border_rounded, C.rose, C.roseTint, () => push(const HealthScreen())),
      (tr('অ্যালার্ম'), Icons.alarm_rounded, C.orange, C.orangeTint, () => push(const AlarmsScreen())),
      (tr('পাসওয়ার্ড'), Icons.lock_outline_rounded, C.muted2, C.soft, () => push(const VaultPage())),
      (tr('ক্যালেন্ডার'), Icons.calendar_month_outlined, C.blue, C.blueTint, () => push(const CalendarScreen())),
      (tr('কম্পাস'), Icons.explore_outlined, C.green, C.greenTint, () => push(const CompassScreen())),
      (tr('যাকাত'), Icons.volunteer_activism_outlined, C.ochre, C.ochreTint, () => push(const ZakatScreen())),
      (tr('ফ্যামিলি'), Icons.family_restroom_rounded, C.purple, C.purpleTint, () => push(const FamilyScreen())),
      (tr('ব্লাড ডোনেশন'), Icons.bloodtype_outlined, C.rose, C.roseTint, () => push(const RequestsScreen())),
      (tr('প্রো ভার্সন'), Icons.workspace_premium_outlined, C.ochre, C.ochreTint, () => push(const ProScreen())),
    ];

    if (brain.easyMode) return const EasyHome();

    const shade = [Shadow(color: Color(0x66000000), blurRadius: 8)];
    final soft = Colors.white.withValues(alpha: 0.88);
    const horizon = 54.0;
    Widget figure(String label, String value, Color color) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: body(12.5, color: C.muted)),
            const SizedBox(height: 2),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(17, weight: 700, color: color)),
          ]),
        );

    return Column(children: [
      Expanded(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // A short greeting under today's sky.
            SizedBox(
              height: top + 236,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: HomeSky(
                  now: now,
                  sunrise: sun.sunrise,
                  sunset: sun.sunset,
                  horizon: horizon,
                  arcHeight: 58,
                  child: Stack(children: [
                    Positioned(
                      left: 20,
                      right: 16,
                      top: top + 12,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => push(const CalendarScreen()),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(first.isEmpty ? helloFor(now) : '${helloFor(now)}, $first', maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: display(24, weight: 700, color: Colors.white, height: 1.2).copyWith(shadows: shade)),
                              const SizedBox(height: 4),
                              Text('${weekdayName(now)}, ${bnDigits(now.day)} ${monthName(now.month)}', style: body(14.5, weight: FontWeight.w600, color: Colors.white).copyWith(shadows: shade)),
                              Text('${bd.text}, ${hj.dayMonth}', style: body(13, color: soft).copyWith(shadows: shade)),
                              // The weather now, under the date (tap: the full weather).
                              const Padding(padding: EdgeInsets.only(top: 6), child: _WeatherLabel()),
                            ]),
                          ),
                        ),
                        Tooltip(
                          message: tr('প্রোফাইল'),
                          child: InkWell(customBorder: const CircleBorder(), onTap: () => goToTab(context, ShellTab.more), child: const UserPhoto(size: 44, onDark: true)),
                        ),
                      ]),
                    ),
                    Positioned(left: 16, bottom: 14, child: _SunLabel(icon: Icons.wb_twilight, text: trf('সূর্যোদয় {0}', [bnTime(sun.sunrise.hour, sun.sunrise.minute)]))),
                    Positioned(right: 16, bottom: 14, child: _SunLabel(icon: Icons.nights_stay_outlined, text: trf('সূর্যাস্ত {0}', [bnTime(sun.sunset.hour, sun.sunset.minute)]))),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const GoogleStartCard(),
                if (d.reminders.isNotEmpty) const AlarmBanner(),
                const TodaySections(),
                HomeSection(
                  title: tr('এ মাসের হিসাব'),
                  action: tr('হিসাব খুলুন'),
                  onAction: () => goToTab(context, ShellTab.money),
                  child: HomeCard(
                    key: const Key('home-stat-spent'),
                    onTap: () => goToTab(context, ShellTab.money),
                    child: Column(children: [
                      Row(children: [
                        figure(tr('আয়'), taka(month.income), C.green),
                        figure(tr('খরচ'), taka(month.expense), C.red),
                        figure(tr('হাতে থাকল'), taka(month.balance), C.ink),
                      ]),
                      if (owe.receivable > 0 || owe.payable > 0) ...[
                        Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: C.line)),
                        Row(children: [
                          if (owe.receivable > 0) figure(trf('পাবো, {0} জনের কাছে', [bnDigits(owe.owingPeople)]), taka(owe.receivable), C.green),
                          if (owe.payable > 0) figure(trf('দেবো, {0} জনকে', [bnDigits(owe.owedPeople)]), taka(owe.payable), C.orange),
                          if (owe.receivable == 0 || owe.payable == 0) const Spacer(),
                        ]),
                      ],
                      if (week.spent > 0) ...[
                        Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Divider(height: 1, color: C.line)),
                        InkWell(
                          key: const Key('home-spend-health'),
                          onTap: () => push(const SpendHealthScreen()),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              Icon(Icons.pie_chart_outline_rounded, size: 20, color: weekWarn ? C.orange : C.green),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  week.hasIncome
                                      ? trf('এ সপ্তাহে আয়ের {0}% খরচ — শখের খাতে {1}%', [bnDigits(week.pct(week.spent)), bnDigits(week.pct(week.wants))])
                                      : trf('এ সপ্তাহে খরচ {0} — কোথায় যাচ্ছে দেখুন', [taka(week.spent)]),
                                  style: body(13.5, color: weekWarn ? C.orange : C.ink, weight: FontWeight.w500),
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: C.muted),
                            ]),
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
                HomeSection(
                  title: tr('আজকের অর্থ-কথা'),
                  child: HomeCard(
                    key: const Key('home-quote'),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.format_quote_rounded, color: C.ochre, size: 26),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(tr(quote.text), style: body(15, height: 1.5, weight: FontWeight.w500)),
                          if (quote.source.isNotEmpty) ...[const SizedBox(height: 4), Text('— ${tr(quote.source)}', style: body(12.5, color: C.muted))],
                        ]),
                      ),
                    ]),
                  ),
                ),
                if (inboxTodos.isNotEmpty || (next != null && daysTo <= 30))
                  HomeSection(
                    title: tr('সামনে'),
                    child: HomeCard(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        if (inboxTodos.isNotEmpty)
                          _UpcomingRow(
                            lead: Icon(Icons.mark_chat_unread_outlined, color: C.green, size: 22),
                            tint: C.greenTint,
                            title: trf('মেসেজ থেকে {0}টা কাজ', [bnDigits(inboxTodos.length)]),
                            text: inboxTodos.first.$2.summary,
                            onTap: () => push(const InboxScreen()),
                          ),
                        if (inboxTodos.isNotEmpty && next != null && daysTo <= 30) Divider(height: 1, indent: 72, color: C.line),
                        if (next != null && daysTo <= 30)
                          _UpcomingRow(
                            lead: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Text(bnDigits(next.start.day), style: display(17, weight: 700, color: C.rose, height: 1.05)),
                              Text(monthName(next.start.month), maxLines: 1, overflow: TextOverflow.clip, style: body(9.5, weight: FontWeight.w600, color: C.rose, height: 1.1)),
                            ]),
                            tint: C.roseTint,
                            title: daysTo == 0 ? trf('আজ ছুটি — {0}', [next.label]) : next.label,
                            text: '${holidayRange(next)}${next.days > 1 ? ', ${trf('টানা {0} দিন', [bnDigits(next.days)])}' : ''}',
                            tag: daysTo > 0 ? trf('{0} দিন পর', [bnDigits(daysTo)]) : null,
                            onTap: () => push(const CalendarScreen()),
                          ),
                      ]),
                    ),
                  ),
                HomeSection(
                  title: tr('সব কিছু এক জায়গায়'),
                  child: HomeCard(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                    child: GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 0.92,
                      children: [
                        for (final (label, icon, fg, bg, onTap) in shortcuts)
                          InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: onTap,
                            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                                child: Icon(icon, color: fg, size: 23),
                              ),
                              const SizedBox(height: 7),
                              Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(12.5, height: 1.2)),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
                const StartTips(),
              ]),
            ),
          ],
        ),
      ),
      const AdSlot(padding: EdgeInsets.fromLTRB(16, 4, 16, 6)),
    ]);
  }
}

/// "২৮° · আংশিক মেঘলা" on the sky; fetched when the home opens (kept 30
/// minutes), nothing shown while offline.
class _WeatherLabel extends StatefulWidget {
  const _WeatherLabel();

  @override
  State<_WeatherLabel> createState() => _WeatherLabelState();
}

class _WeatherLabelState extends State<_WeatherLabel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BrainScope.read(context).refreshWeather();
    });
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final w = brain.weatherNow;
    if (w == null) return const SizedBox.shrink();
    return Tooltip(
      message: w.said(),
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 5),
      child: Container(
        key: const Key('home-temp'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: const Color(0x33000000), borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(w.code >= 51 ? Icons.water_drop_outlined : (w.code >= 3 ? Icons.cloud_outlined : Icons.wb_sunny_outlined), size: 15, color: const Color(0xFFFDE68A)),
          const SizedBox(width: 5),
          Flexible(child: Text('${w.short} · ${w.sky} · ${tr(brain.district)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, weight: FontWeight.w600, color: Colors.white))),
        ]),
      ),
    );
  }
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

/// One thing coming up: a small tinted square (a date or an icon), what it
/// is, and how far away.
class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.lead, required this.tint, required this.title, required this.text, this.tag, required this.onTap});
  final Widget lead;
  final Color tint;
  final String title;
  final String text;
  final String? tag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)), child: Center(child: lead)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600)),
                Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, color: C.muted)),
              ]),
            ),
            if (tag != null) Padding(padding: const EdgeInsets.only(left: 8), child: Text(tag!, style: body(12.5, weight: FontWeight.w600, color: C.muted)))
            else Icon(Icons.chevron_right_rounded, color: C.muted),
          ]),
        ),
      );
}

/// "২০–২৪ অক্টোবর", or "১৬ ডিসেম্বর".
String holidayRange(HolidayRun r) {
  if (r.days == 1) return '${bnDigits(r.start.day)} ${monthName(r.start.month)}';
  if (r.start.month == r.end.month) return '${bnDigits(r.start.day)}–${bnDigits(r.end.day)} ${monthName(r.start.month)}';
  return '${bnDigits(r.start.day)} ${monthName(r.start.month)} – ${bnDigits(r.end.day)} ${monthName(r.end.month)}';
}
