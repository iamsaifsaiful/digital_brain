import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../services/weather.dart' show AbroadHoliday;
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'home_page.dart' show holidayRange;
import 'diary_screen.dart' show itemsOn;
import 'plan_screens.dart' show showAddSheet, PlanRow;
import 'special_days_screen.dart';
import '../logic/lang.dart';
import '../logic/world_calendars.dart';
import 'calendar_choice.dart';
import '../logic/weather.dart';
import 'weather_screen.dart' show DaySkyScreen, WeatherIcon;

/// বাংলা তারিখ, ঋতু, সূর্যোদয়-সূর্যাস্ত আর সরকারি ছুটি। The
/// month shows the dates of a chosen calendar (Bangla, Hijri, Chinese …:
/// owner, 19 Nov) under each day; tapping a day shows what is on it and
/// adds a to-do or reminder for it.

/// Fonts for the dates in their own scripts; the phone's own fonts when these are not there.
const nativeFonts = ['Hind', 'NotoNaskhArabic', 'NotoSansHebrew', 'NotoSansCJK', 'NotoSansThai', 'NotoSansDevanagari', 'NotoSansEthiopic'];

/// The calendar tab of the ঋতুপঞ্জি page ([DaySkyScreen]).
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) => const DaySkyScreen(calendar: true);
}

/// The month, the chosen calendar under each day, the coming days' weather in
/// them ([forecast]: the user's own place), and the holidays.
class CalendarPanel extends StatefulWidget {
  const CalendarPanel({super.key, this.forecast});
  final Forecast? forecast;

  @override
  State<CalendarPanel> createState() => _CalendarPanelState();
}

class _CalendarPanelState extends State<CalendarPanel> {
  DateTime? _month;
  DateTime? _picked;
  /// The calendar under each day in the month (one of those chosen).
  String? _side;

  static final _red = C.rose;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final today = DateTime(now.year, now.month, now.day);
    final month = _month ?? DateTime(now.year, now.month);
    final picked = _picked ?? today;
    final chosen = brain.calendars;
    final hasBangla = chosen.contains('bangla');
    final place = placeNamed(brain.district);
    final nextStart = nextBanglaMonthStart(today);
    final toNext = nextStart.difference(today).inDays;
    final nextBd = banglaDate(nextStart);
    // Abroad: that country's holidays, not Bangladesh's (owner, 29 Oct).
    final abroad = place.abroad;
    final pickedHol = abroad ? null : holidayOn(picked);
    final away = abroad ? brain.holidaysAbroad(today, count: 6) : const <AbroadHoliday>[];

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                        hasBangla
                            ? trf('{0} দিন পর {1} {2}{3}', [bnDigits(toNext), bnDigits(1), nextBd.monthName, nextBd.month % 2 == 0 ? ' · ${trf('{0}কাল শুরু', [nextBd.season])}' : ''])
                            : trf('{0} অনুযায়ী', [place.label]),
                        maxLines: 2,
                        style: body(12, color: C.muted, height: 1.4)),
                  ),
                ),
                // Which calendars beside English (owner, 19 Nov).
                TextButton.icon(
                  key: const Key('cal-choose'),
                  onPressed: () => showCalendarChoice(context),
                  icon: Icon(Icons.tune_rounded, size: 19, color: C.green),
                  label: Text(tr('ক্যালেন্ডার বাছাই'), style: body(13, weight: FontWeight.w600, color: C.green)),
                ),
              ]),
              // Prayer, sehri and iftar times are on the মুসলিম টাইম page now (owner, 19 Nov).
              const SizedBox(height: 6),
              if (chosen.length > 1) ...[
                SegTabs<String>(
                  key: const Key('cal-side-tabs'),
                  items: [for (final id in chosen) (id, id == 'bangla' ? tr('বাংলা তারিখ') : (id == 'hijri' ? tr('আরবি (হিজরি) তারিখ') : calKind(id)!.name))],
                  value: _sideOf(chosen)!,
                  onChanged: (v) => setState(() => _side = v),
                ),
                const SizedBox(height: 8),
              ],
              _monthGrid(month, today, picked, _sideOf(chosen)),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: Text(tr('কোনো তারিখে চাপ দিলে সেদিনের কাজ দেখা যাবে, নতুন কাজ বা রিমাইন্ডারও রাখা যাবে।'), style: body(12, color: C.muted)),
              ),
              if (pickedHol != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${bnDigits(picked.day)} ${monthName(picked.month)}: ${pickedHol.label}${pickedHol.executive ? tr(' (নির্বাহী আদেশে)') : ''}',
                      style: body(14, weight: FontWeight.w600, color: _red)),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
                child: Text(abroad ? trf('সামনের ছুটি · {0}', [place.label]) : tr('সামনের সরকারি ছুটি'), style: body(13, weight: FontWeight.w600, color: C.muted)),
              ),
              if (abroad && away.isEmpty)
                Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(tr('এই দেশের ছুটির তালিকা এখনো আনা যায়নি — ইন্টারনেট চালু থাকলে নিজে আসবে।'), style: body(13, color: C.muted))),
              if (abroad && away.isNotEmpty)
                Container(
                  key: const Key('cal-holidays-abroad'),
                  decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
                  child: Column(children: [
                    for (final (i, h) in away.indexed) ...[
                      if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: C.line),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        child: Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: C.roseTint, borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.flag_outlined, color: _red, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(h.name, style: body(15, weight: FontWeight.w600)),
                              Text('${bnDigits(h.date.day)} ${monthName(h.date.month)} · ${weekdayName(h.date)}${h.local.isNotEmpty && h.local != h.name ? ' · ${h.local}' : ''}', style: body(12.5, color: C.muted)),
                            ]),
                          ),
                          Text(_inDays(h.date.difference(today).inDays), style: body(12.5, weight: FontWeight.w600, color: _red)),
                        ]),
                      ),
                    ],
                  ]),
                ),
              if (!abroad)
              Container(
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  for (final (i, r) in upcomingHolidays(today, count: 6).indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: C.line),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      child: Row(children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: C.roseTint, borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.flag_outlined, color: _red, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.label, style: body(15, weight: FontWeight.w600)),
                            Text('${holidayRange(r)}${r.days > 1 ? ' · ${trf('টানা {0} দিন', [bnDigits(r.days)])}' : ' · ${weekdayName(r.start)}'}', style: body(12.5, color: C.muted)),
                          ]),
                        ),
                        Text(_inDays(r.start.difference(today).inDays), style: body(12.5, weight: FontWeight.w600, color: _red)),
                      ]),
                    ),
                  ],
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                child: Text(tr('চাঁদ দেখার ওপর নির্ভর ছুটি এক-দুই দিন বদলাতে পারে।'), style: body(12, color: C.muted)),
              ),
              // (Below the holidays: a setting, seldom needed.) The Hijri date follows the moon seen in Bangladesh: a day either way can be set here.
              if (chosen.contains('hijri')) ...[
              const SizedBox(height: 10),
              Panel(
                padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        brain.hijriShift == 0
                            ? tr('হিজরি তারিখ চাঁদ দেখার ওপর এক দিন আগে-পরে হতে পারে')
                            : trf('হিজরি তারিখ {0} দিন সরানো আছে', [bnDigits(brain.hijriShift > 0 ? '+${brain.hijriShift}' : '${brain.hijriShift}')]),
                        style: body(12.5, color: C.muted)),
                  ),
                  IconButton(
                    tooltip: tr('হিজরি তারিখ এক দিন পিছিয়ে দিন'),
                    onPressed: brain.hijriShift <= -2 ? null : () => brain.setPref('hijri_adjust', brain.hijriShift - 1),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  IconButton(
                    tooltip: tr('হিজরি তারিখ এক দিন এগিয়ে দিন'),
                    onPressed: brain.hijriShift >= 2 ? null : () => brain.setPref('hijri_adjust', brain.hijriShift + 1),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ]),
              ),
              ],
            ]);
  }

  String _inDays(int n) => n <= 0 ? tr('আজ') : (n == 1 ? tr('কাল') : trf('{0} দিন পর', [bnDigits(n)]));

  /// Which way the last month turn went (1 = next, -1 = before).
  double _dir = 1;

  void _turn(DateTime month, int by) => setState(() {
        _dir = by.toDouble();
        _month = DateTime(month.year, month.month + by);
      });

  /// The chosen calendar shown under the days (the first, until another tab is picked).
  String? _sideOf(List<String> chosen) => chosen.contains(_side) ? _side : (chosen.isEmpty ? null : chosen.first);

  Widget _monthGrid(DateTime month, DateTime today, DateTime picked, String? side) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = (DateTime(month.year, month.month).weekday + 1) % 7; // Saturday first
    final heads = [tr('শনি'), tr('রবি'), tr('সোম'), tr('মঙ্গল'), tr('বুধ'), tr('বৃহঃ'), tr('শুক্র')];
    final adjust = BrainScope.of(context).hijriShift;
    final first = side == null ? null : calDate(side, DateTime(month.year, month.month), hijriShift: adjust);
    final last = side == null ? null : calDate(side, DateTime(month.year, month.month, days), hijriShift: adjust);
    // "অগ্রহায়ণ – পৌষ ১৪৩৩"; for Thai and Japanese only the year ("রেইওয়া ৮").
    final sub = first == null || last == null
        ? ''
        : calKind(side!)!.sameDays
            ? last.yearLabel
            : '${first.monthName == last.monthName ? '' : '${first.monthName} – '}${last.monthName} ${last.yearLabel}';
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Row(children: [
          IconButton(tooltip: tr('আগের মাস'), onPressed: () => _turn(month, -1), icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
            child: Column(children: [
              Text('${monthName(month.month)} ${bnDigits(month.year)}', style: body(15, weight: FontWeight.w600)),
              if (sub.isNotEmpty) Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: C.muted)),
            ]),
          ),
          IconButton(tooltip: tr('পরের মাস'), onPressed: () => _turn(month, 1), icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        Row(children: [
          for (final (i, h) in heads.indexed) Expanded(child: Text(h, textAlign: TextAlign.center, style: body(11.5, color: i == 0 || i == 6 ? _red : C.muted))),
        ]),
        const SizedBox(height: 4),
        // Swipe the days left or right to turn the month; the new month
        // slides in from the side it was pulled from.
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v.abs() < 200) return;
            _turn(month, v < 0 ? 1 : -1);
          },
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, if (current != null) current]),
              transitionBuilder: (child, anim) {
                final incoming = child.key == ValueKey('${month.year}-${month.month}');
                final from = Offset((incoming ? 1.0 : -1.0) * _dir, 0);
                return SlideTransition(
                  position: Tween<Offset>(begin: incoming ? from : -from, end: Offset.zero).animate(anim),
                  child: FadeTransition(opacity: anim, child: child),
                );
              },
              child: GridView.count(
                key: ValueKey('${month.year}-${month.month}'),
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
                childAspectRatio: 0.9,
                children: [
                  for (var i = 0; i < lead; i++) const SizedBox.shrink(),
                  for (var d = 1; d <= days; d++) _cell(DateTime(month.year, month.month, d), today, picked, side),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _cell(DateTime d, DateTime today, DateTime picked, String? side) {
    final brain = BrainScope.of(context);
    final isToday = d == today;
    final busy = itemsOn(brain.data, d, brain.services.now()).isNotEmpty;
    final isPicked = d == picked && !isToday;
    final place = placeNamed(brain.district);
    final hol = place.abroad ? brain.holidaysAbroad(d, count: 1).any((h) => h.date == d) : holidayOn(d) != null;
    final weekend = isWeekend(d);
    // The chosen calendar's day under the English one (nothing for Thai and Japanese: the same days).
    final c = side == null || calKind(side)!.sameDays ? null : calDate(side, d, hijriShift: brain.hijriShift);
    final under = c == null ? '' : bnDigits(c.day);
    // The weather of the coming days, small in the corner (owner, 19 Nov: the calendar and the weather together).
    final cast = _castOn(d);
    final bg = isToday ? C.green : (hol ? C.roseTint : Colors.transparent);
    final fg = isToday ? C.onAccent : (hol || weekend ? _red : C.ink);
    return InkWell(
      key: Key('day-${d.year}-${d.month}-${d.day}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() => _picked = d);
        _dayDetails(d);
      },
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: isPicked ? Border.all(color: C.green, width: 1.5) : null),
        child: Stack(children: [
          if (cast != null) Positioned(top: 2, right: 2, child: WeatherIcon(cast.code, size: 12)),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(bnDigits(d.day), style: body(14.5, weight: FontWeight.w600, color: fg, height: 1.2)),
          Text(under, style: body(10, color: isToday ? C.onAccent.withValues(alpha: 0.75) : (side == 'bangla' ? C.muted : C.teal), height: 1.2)),
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(shape: BoxShape.circle, color: busy ? (isToday ? C.onAccent : C.orange) : Colors.transparent),
          ),
          ])),
        ]),
      ),
    );
  }

  DayCast? _castOn(DateTime d) {
    for (final c in widget.forecast?.days ?? const <DayCast>[]) {
      if (c.date.year == d.year && c.date.month == d.month && c.date.day == d.day) return c;
    }
    return null;
  }

  /// A day tapped: its dates, holiday, what is on it, and adding to it.
  Future<void> _dayDetails(DateTime d) async {
    final brain = BrainScope.read(context);
    final now = brain.services.now();
    final hol = placeNamed(brain.district).abroad ? null : holidayOn(d);
    final extra = [for (final id in brain.calendars) calDate(id, d, hijriShift: brain.hijriShift)?.text].whereType<String>().toList();
    final past = d.isBefore(dayOnly(now));
    await showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final items = itemsOn(BrainScope.of(ctx).data, d, now);
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
              Text('${weekdayName(d)}, ${bnDigits(d.day)} ${monthName(d.month)} ${bnDigits(d.year)}', style: display(20, weight: 700)),
              if (extra.isNotEmpty) Text(extra.join(' · '), style: body(13.5, color: C.muted)),
              // The dates in their own scripts: আরবি, 中文, עברית …
              for (final id in brain.calendars)
                if ((calDate(id, d, hijriShift: brain.hijriShift)?.native ?? '').isNotEmpty)
                  Text(calDate(id, d, hijriShift: brain.hijriShift)!.native,
                      textDirection: calKind(id)!.rtl ? TextDirection.rtl : TextDirection.ltr, style: TextStyle(fontSize: 14, color: C.muted2, height: 1.5, fontFamilyFallback: nativeFonts)),
              if (_castOn(d) case final c?) ...[
                const SizedBox(height: 8),
                Row(key: const Key('cal-day-weather'), children: [
                  WeatherIcon(c.code, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${weatherWords(c.code)} · ${deg(c.min)} – ${deg(c.max)}${c.rain >= 30 ? ' · ${trf('বৃষ্টির সম্ভাবনা {0}%', [bnDigits(c.rain)])}' : ''}',
                        style: body(14, weight: FontWeight.w500)),
                  ),
                ]),
              ],
              if (hol != null) Text(trf('ছুটি: {0}', [hol.label]), style: body(14, weight: FontWeight.w600, color: _red)),
              const SizedBox(height: 14),
              if (items.isEmpty) Text(tr('এই দিনে কিছু রাখা নেই।'), style: body(14.5, color: C.muted)) else Panel(child: Rows(children: [for (final i in items) PlanRow(item: i)])),
              const SizedBox(height: 16),
              if (!past) ...[
                Text(tr('এই দিনের জন্য'), style: body(13, weight: FontWeight.w600, color: C.muted2)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: PrimaryButton(
                      key: const Key('cal-add-task'),
                      label: tr('কাজ'),
                      icon: Icons.checklist_rounded,
                      height: 48,
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await showAddSheet(context, day: d);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SecondaryButton(
                      key: const Key('cal-add-reminder'),
                      label: tr('রিমাইন্ডার'),
                      icon: Icons.notifications_active_outlined,
                      height: 48,
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await showAddSheet(context, remind: true, day: d);
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SpecialDaysScreen()));
                  },
                  icon: Icon(Icons.cake_outlined, color: C.green),
                  label: Text(tr('জন্মদিন বা বিশেষ দিন রাখুন')),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }
}
