import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../logic/cash.dart';
import '../logic/lang.dart';
import '../logic/ledger.dart' show totals;
import '../logic/money_quotes.dart';
import '../logic/phrases.dart' show possessive;
import '../logic/spend_health.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/kit.dart';
import '../ui/pro_gate.dart';
import '../ui/theme.dart';
import 'alarm_list_screen.dart';
import 'calendar_screen.dart';
import 'calls_screen.dart';
import 'compass_screen.dart';
import 'docs_screen.dart';
import 'easy_home.dart';
import 'family_screen.dart';
import 'health_hub.dart';
import 'home_screen.dart';
import 'home_shell.dart';
import 'notes_screen.dart';
import 'notice_screen.dart';
import 'plan_screens.dart';
import 'pro_screen.dart';
import 'requests_screen.dart';
import 'settings_parts.dart';
import 'spend_health_screen.dart';
import 'vault_screen.dart';
import 'zakat_screen.dart';

String helloFor(DateTime now) {
  final h = now.hour;
  if (h >= 4 && h < 11) return tr('সুপ্রভাত');
  if (h >= 11 && h < 15) return tr('শুভ দুপুর');
  if (h >= 15 && h < 18) return tr('শুভ বিকেল');
  if (h >= 18 && h < 22) return tr('শুভ সন্ধ্যা');
  return tr('শুভ রাত');
}

/// হোম (the approved design of 24 Oct, docs/design/2026-10-24-home-final):
/// the greeting and today's three dates, weather and the next prayer, at
/// most one thing that needs a look, today's work, the money, the coming
/// holidays, every tool (folded), a line about money, and the privacy note.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    if (brain.easyMode) return const EasyHome();
    final now = brain.services.now();
    final quote = quoteFor(now);
    final top = MediaQuery.of(context).padding.top;

    return ColoredBox(
      color: C.ground,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, top + 6, 20, 24),
        children: [
          const _Header(),
          const _InfoRow(),
          const HomeAttention(),
          const TodaySections(),
          const _MoneyCard(),
          const _Holidays(),
          const SizedBox(height: 14),
          const _Tools(),
          const SizedBox(height: 12),
          AppCard(
            key: const Key('home-quote'),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.format_quote_rounded, size: 20, color: C.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(quote.text), style: body(13.5, height: 1.6)),
                  const SizedBox(height: 2),
                  Text(quote.source.isEmpty ? tr('আজকের অর্থ-কথা') : '${tr('আজকের অর্থ-কথা')} · ${tr(quote.source)}', style: body(11.5, color: C.muted)),
                ]),
              ),
            ]),
          ),
          // Free Play app only: a quiet ad card under the quote.
          const AdSlot(padding: EdgeInsets.only(top: 12)),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.lock_outline_rounded, size: 14, color: C.muted),
              const SizedBox(width: 5),
              Flexible(child: Text(tr('আপনার তথ্য এই ফোনেই থাকে, তালাবদ্ধ'), style: body(11.5, color: C.muted))),
            ]),
          ),
        ],
      ),
    );
  }
}

/// "শুভ সন্ধ্যা, সাইফুল", today in three calendars, the bell and the photo.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final bd = banglaDate(now);
    final hj = hijriDate(now, adjust: brain.number('hijri_adjust'));
    final first = brain.userName.trim().isEmpty ? '' : brain.userName.trim().split(' ').first;
    final seen = DateTime.tryParse(brain.text('notices_seen'));
    final unread = brain.noticeHistory.any((e) => !e.at.isAfter(now) && (seen == null || e.at.isAfter(seen)));
    final premium = brain.gated && brain.pro;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => push(const CalendarScreen()),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(first.isEmpty ? helloFor(now) : '${helloFor(now)}, $first', maxLines: 1, overflow: TextOverflow.ellipsis, style: display(25, weight: 600, height: 1.3)),
            const SizedBox(height: 2),
            Text('${weekdayName(now)}, ${bnDigits(now.day)} ${monthName(now.month)}', style: body(13.5, color: C.muted)),
            const SizedBox(height: 4),
            Text('${bd.text}  •  ${hj.dayMonth} ${bnDigits(hj.year)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted)),
          ]),
        ),
      ),
      SizedBox(
        width: 44,
        height: 44,
        child: IconButton(
          key: const Key('home-notices'),
          tooltip: tr('নোটিফিকেশন'),
          onPressed: () async {
            await brain.setPref('notices_seen', now.toIso8601String());
            push(const NoticeScreen());
          },
          icon: Stack(clipBehavior: Clip.none, children: [
            Icon(Icons.notifications_none_rounded, size: 24, color: C.ink),
            if (unread)
              Positioned(
                right: 1,
                top: 1,
                child: Container(
                  key: const Key('home-unread'),
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(color: C.green, shape: BoxShape.circle, border: Border.all(color: C.ground, width: 1.5)),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(width: 4),
      Tooltip(
        message: tr('প্রোফাইল'),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => goToTab(context, ShellTab.more),
          child: SizedBox(
            width: 44,
            height: 48,
            child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
              const Padding(padding: EdgeInsets.only(top: 2), child: UserPhoto(size: 38)),
              if (premium)
                Positioned(
                  bottom: 0,
                  child: Container(
                    key: const Key('home-premium-badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(5), border: Border.all(color: C.ground, width: 2)),
                    child: Text(tr('প্রিমিয়াম'), style: body(8.5, weight: FontWeight.w700, color: C.onAccent, height: 1.3)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    ]);
  }
}

/// What the right side of the info row turns between: the next prayer, then
/// sunrise and sunset; in Ramadan, iftar (Fajr to Maghrib) or the end of
/// sehri (Maghrib to Fajr) instead of the prayer. Times are worked out on
/// the phone for the district.
class SlotFact {
  const SlotFact(this.kind, this.label, this.time, {this.second = '', this.ramadanDay});

  /// 'prayer', 'iftar', 'sehri' or 'sun'.
  final String kind;
  final String label;
  final String time;

  /// The sun slide's second line ("সূর্যাস্ত ৫:২৪").
  final String second;

  /// In Ramadan: its day ("রমজান ১৪").
  final int? ramadanDay;
}

List<SlotFact> slotFacts(DateTime now, SunTimes t, HijriDate hj) {
  String at(DateTime x) => bnTime(x.hour, x.minute).replaceAll(RegExp(r'^(?:ভোর|সকাল|দুপুর|বিকেল|সন্ধ্যা|রাত)\s*'), '');
  final out = <SlotFact>[];
  if (hj.month == 9) {
    final beforeIftar = !now.isBefore(t.fajr) && now.isBefore(t.maghrib);
    out.add(beforeIftar
        ? SlotFact('iftar', tr('ইফতার'), at(t.maghrib), ramadanDay: hj.day)
        : SlotFact('sehri', tr('সেহরি শেষ'), at(t.fajr), ramadanDay: hj.day));
  } else {
    final prayers = [(tr('ফজর'), t.fajr), (now.weekday == DateTime.friday ? tr('জুমা') : tr('জোহর'), t.dhuhr), (tr('আসর'), t.asr), (tr('মাগরিব'), t.maghrib), (tr('এশা'), t.isha)];
    // The next one; after Isha, still Isha until midnight, then tomorrow's Fajr.
    final next = prayers.where((p) => p.$2.isAfter(now)).firstOrNull ?? (now.hour >= 12 ? prayers.last : prayers.first);
    out.add(SlotFact('prayer', next.$1, at(next.$2)));
  }
  out.add(SlotFact('sun', tr('সূর্যোদয়'), at(t.sunrise), second: '${tr('সূর্যাস্ত')} ${at(t.sunset)}'));
  return out;
}

/// Weather on the left; the turning slot on the right; hairlines above and below.
class _InfoRow extends StatefulWidget {
  const _InfoRow();

  @override
  State<_InfoRow> createState() => _InfoRowState();
}

class _InfoRowState extends State<_InfoRow> {
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
    final now = brain.services.now();
    final place = placeNamed(brain.district);
    final sun = sunTimes(now, place);
    final hj = hijriDate(now, adjust: brain.number('hijri_adjust'));
    final w = brain.weatherNow;
    final night = now.isBefore(sun.sunrise) || now.isAfter(sun.sunset);
    final facts = slotFacts(now, sun, hj);

    Widget slide(SlotFact f) {
      final text = f.kind == 'sun'
          ? Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              Text('${f.label} ${f.time}', style: body(11.5, color: C.muted, height: 1.5)),
              Text(f.second, style: body(11.5, color: C.muted, height: 1.5)),
            ])
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (f.ramadanDay != null)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: C.warnBg, borderRadius: BorderRadius.circular(9), border: Border.all(color: C.warnBorder)),
                  child: Text(trf('রমজান {0}', [bnDigits(f.ramadanDay!)]), style: body(11, weight: FontWeight.w600, color: C.warn)),
                ),
              Text(f.label, style: body(13.5, weight: FontWeight.w600)),
              const SizedBox(width: 4),
              Text(f.time, style: body(13.5, weight: FontWeight.w600, color: C.green)),
            ]);
      return text;
    }

    IconData iconOf(SlotFact f) => switch (f.kind) {
          'prayer' => Icons.mosque_outlined,
          'iftar' || 'sehri' => Icons.nightlight_outlined,
          _ => Icons.wb_twilight_rounded,
        };

    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 4),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border.symmetric(horizontal: BorderSide(color: C.border))),
      child: Row(children: [
        Expanded(
          child: w == null
              ? Row(children: [
                  Icon(night ? Icons.nightlight_outlined : Icons.place_outlined, size: 20, color: C.muted),
                  const SizedBox(width: 7),
                  Flexible(child: Text(tr(brain.district), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13))),
                ])
              : Tooltip(
                  key: const Key('home-temp'),
                  message: w.said(),
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 5),
                  child: Row(children: [
                    Icon(night ? Icons.nightlight_outlined : (w.code >= 51 ? Icons.water_drop_outlined : (w.code >= 3 ? Icons.cloud_outlined : Icons.wb_sunny_outlined)),
                        size: 20, color: C.muted),
                    const SizedBox(width: 7),
                    Flexible(child: Text('${w.short} · ${w.sky} · ${tr(brain.district)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13))),
                  ]),
                ),
        ),
        RotatingSlot(
          key: const Key('home-slot'),
          slides: [for (final f in facts) slide(f)],
          trailing: [for (final f in facts) IconTile(iconOf(f), size: 40)],
          onTap: (_) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
        ),
      ]),
    );
  }
}

/// টাকার হিসাব: what is in hand, this month's in and out, পাবো / দেবো, and the week.
class _MoneyCard extends StatelessWidget {
  const _MoneyCard();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final d = brain.data;
    final now = brain.services.now();
    final today = dayOnly(now);
    final month = monthSums(d.cash, now);
    final hand = cashOnHand(d);
    final owe = totals(d.ledger);
    final week = spendHealth(d, now);
    final weekWarn = week.hasIncome && (week.pct(week.wants) > wantCap || week.spent > week.income);
    // A pay-back day today, and the next day I have to give back.
    final dueToday = d.ledger.where((e) => e.kind == LedgerKind.lent && e.due != null && dayOnly(e.due!) == today).map((e) => e.person).toSet();
    final nextGive = (d.ledger.where((e) => e.kind == LedgerKind.borrowed && e.due != null && !dayOnly(e.due!).isBefore(today)).toList()
          ..sort((a, b) => a.due!.compareTo(b.due!)))
        .firstOrNull;
    void money() => goToTab(context, ShellTab.money);

    Widget stat(IconData icon, String label, String value, Color color) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 14, color: C.muted), const SizedBox(width: 4), Text(label, style: body(11.5, color: C.muted))]),
          const SizedBox(height: 4),
          Text(value, style: body(14, weight: FontWeight.w600, color: color)),
        ]);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading(tr('টাকার হিসাব'), link: '${monthName(now.month)} · ${tr('খুলুন')}', onLink: money),
      AppCard(
        key: const Key('home-stat-spent'),
        onTap: money,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hand != null ? tr('এখন আছে') : tr('হাতে থাকল'), style: body(11.5, color: C.muted)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(taka(hand ?? month.balance), style: display(27, weight: 600, height: 1.45)),
                ),
              ]),
            ),
            const IconTile(Icons.account_balance_wallet_outlined),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            stat(Icons.south_rounded, tr('আয়'), taka(month.income), C.green),
            const SizedBox(width: 26),
            stat(Icons.north_rounded, tr('খরচ'), taka(month.expense), C.ink),
          ]),
          const SizedBox(height: 12),
          if (owe.receivable > 0 || owe.payable > 0) ...[
            const Hairline(),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(trf('পাবো · {0} জনের কাছে', [bnDigits(owe.owingPeople)]), style: body(11.5, color: C.muted)),
                      Text(taka(owe.receivable), style: body(15, weight: FontWeight.w600)),
                      if (dueToday.isNotEmpty)
                        Text(trf('আজ {0} ফেরতের দিন', [dueToday.map(possessive).join(', ')]), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11, color: C.warn)),
                    ]),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 1, color: C.border),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 0, 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(trf('দেবো · {0} জনকে', [bnDigits(owe.owedPeople)]), style: body(11.5, color: C.muted)),
                      Text(taka(owe.payable), style: body(15, weight: FontWeight.w600, color: owe.payable > 0 ? C.warn : C.ink)),
                      if (nextGive != null) Text('${nextGive.person} · ${bnDigits(nextGive.due!.day)} ${monthName(nextGive.due!.month)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11, color: C.muted)),
                    ]),
                  ),
                ),
              ]),
            ),
          ],
          if (week.spent > 0) ...[
            const Hairline(),
            InkWell(
              key: const Key('home-spend-health'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SpendHealthScreen())),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(children: [
                  Icon(Icons.pie_chart_outline_rounded, size: 17, color: weekWarn ? C.warn : C.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      week.hasIncome
                          ? trf('এ সপ্তাহে আয়ের {0}% খরচ — শখের খাতে {1}%', [bnDigits(week.pct(week.spent)), bnDigits(week.pct(week.wants))])
                          : trf('এ সপ্তাহে খরচ {0} — কোথায় যাচ্ছে দেখুন', [taka(week.spent)]),
                      style: body(12.5, color: weekWarn ? C.warn : C.ink),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: C.muted),
                ]),
              ),
            ),
          ] else
            const SizedBox(height: 2),
        ]),
      ),
    ]);
  }
}

/// সামনের ছুটি: the holiday going on now or the next two (always on the home).
class _Holidays extends StatelessWidget {
  const _Holidays();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final today = dayOnly(now);
    final runs = upcomingHolidays(now, count: 2);
    if (runs.isEmpty) return const SizedBox.shrink();
    void cal() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeading(tr('সামনের ছুটি'), link: tr('ক্যালেন্ডার'), onLink: cal),
      AppCard(
        key: const Key('home-holidays'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(children: [
          for (final (i, h) in runs.indexed) ...[
            if (i > 0) const Hairline(),
            InkWell(
              onTap: cal,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Builder(builder: (context) {
                  final days = DateTime(h.start.year, h.start.month, h.start.day).difference(today).inDays;
                  return Row(children: [
                    _DateBox(day: h.start.day, month: monthShort(h.start.month)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(days <= 0 ? trf('আজ ছুটি — {0}', [h.label]) : h.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, weight: FontWeight.w500)),
                        Text(h.days > 1 ? '${weekdayName(h.start)} · ${holidayRange(h)}, ${trf('টানা {0} দিন', [bnDigits(h.days)])}' : weekdayName(h.start),
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Counter(days > 0 ? trf('{0} দিন পর', [bnDigits(days)]) : tr('চলছে')),
                  ]);
                }),
              ),
            ),
          ],
        ]),
      ),
    ]);
  }
}

class _DateBox extends StatelessWidget {
  const _DateBox({required this.day, required this.month});
  final int day;
  final String month;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 46,
        decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(12)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(bnDigits(day), style: body(17, weight: FontWeight.w700, height: 1.15)),
          Text(month, maxLines: 1, overflow: TextOverflow.clip, style: body(10.5, color: C.muted, height: 1.2)),
        ]),
      );
}

/// সব সুবিধা: every tool, folded by default (the choice is kept).
class _Tools extends StatelessWidget {
  const _Tools();

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final open = brain.flag('home_tools_open');
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final tools = <(String, IconData, VoidCallback)>[
      (tr('কাজের তালিকা'), Icons.checklist_rounded, () => goToTab(context, ShellTab.diary)),
      (tr('রিমাইন্ডার'), Icons.notifications_none_rounded, () => push(const AllTasksScreen())),
      (tr('ডকুমেন্টস'), Icons.folder_outlined, () => push(const DocsScreen())),
      (tr('নোট'), Icons.description_outlined, () => push(const NotesScreen())),
      (tr('যোগাযোগ'), Icons.person_outline_rounded, () => push(const CallsScreen())),
      (tr('স্বাস্থ্য'), Icons.monitor_heart_outlined, () => push(const HealthScreen())),
      (tr('অ্যালার্ম'), Icons.alarm_rounded, () => push(const AlarmsScreen())),
      (tr('পাসওয়ার্ড'), Icons.lock_outline_rounded, () => push(const VaultPage())),
      (tr('ক্যালেন্ডার'), Icons.calendar_month_outlined, () => push(const CalendarScreen())),
      (tr('কম্পাস'), Icons.explore_outlined, () => push(const CompassScreen())),
      (tr('যাকাত'), Icons.volunteer_activism_outlined, () => push(const ZakatScreen())),
      (tr('ফ্যামিলি'), Icons.family_restroom_rounded, () => push(const FamilyScreen())),
      (tr('ব্লাড ডোনেশন'), Icons.bloodtype_outlined, () => push(const RequestsScreen())),
      (tr('প্রিমিয়াম'), Icons.workspace_premium_outlined, () => push(const ProScreen())),
    ];
    return AppCard(
      key: const Key('home-tools'),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(children: [
        InkWell(
          key: const Key('home-tools-toggle'),
          onTap: () => brain.setPref('home_tools_open', !open),
          child: SizedBox(
            height: 50,
            child: Row(children: [
              Text(tr('সব সুবিধা'), style: body(14, weight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text(trf('{0}টা', [bnDigits(tools.length)]), style: body(12, color: C.muted)),
              const Spacer(),
              AnimatedRotation(turns: open ? 0.5 : 0, duration: const Duration(milliseconds: 200), child: Icon(Icons.expand_more_rounded, size: 20, color: C.muted)),
            ]),
          ),
        ),
        if (open)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LayoutBuilder(builder: (context, box) {
              final w = (box.maxWidth - 18) / 4;
              return Wrap(spacing: 6, runSpacing: 4, children: [
                for (final (label, icon, onTap) in tools) SizedBox(width: w, child: ToolTile(icon: icon, label: label, onTap: onTap)),
              ]);
            }),
          ),
      ]),
    );
  }
}

/// "২০–২৪ অক্টোবর", or "১৬ ডিসেম্বর".
String holidayRange(HolidayRun r) {
  if (r.days == 1) return '${bnDigits(r.start.day)} ${monthName(r.start.month)}';
  if (r.start.month == r.end.month) return '${bnDigits(r.start.day)}–${bnDigits(r.end.day)} ${monthName(r.start.month)}';
  return '${bnDigits(r.start.day)} ${monthName(r.start.month)} – ${bnDigits(r.end.day)} ${monthName(r.end.month)}';
}
