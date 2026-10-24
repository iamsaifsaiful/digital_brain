import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../state/brain.dart';
import '../ui/kit.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'home_page.dart' show holidayRange;
import 'diary_screen.dart' show itemsOn;
import 'plan_screens.dart' show showAddSheet, PlanRow;
import 'special_days_screen.dart';
import '../logic/lang.dart';

/// বাংলা তারিখ, ঋতু, সূর্যোদয়-সূর্যাস্ত, নামাজের সময় আর সরকারি ছুটি। The
/// month shows Bangla or Arabic (Hijri) dates under each day; tapping a day
/// shows what is on it and adds a to-do or reminder for it.
enum CalSide { bangla, arabic }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime? _month;
  DateTime? _picked;
  CalSide _side = CalSide.bangla;

  static final _red = C.rose;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final today = DateTime(now.year, now.month, now.day);
    final month = _month ?? DateTime(now.year, now.month);
    final picked = _picked ?? today;
    final bd = banglaDate(picked);
    final hj = hijriDate(picked, adjust: brain.number('hijri_adjust'));
    final place = placeNamed(brain.district);
    final sun = sunTimes(picked, place);
    final nextStart = nextBanglaMonthStart(today);
    final toNext = nextStart.difference(today).inDays;
    final nextBd = banglaDate(nextStart);
    final pickedHol = holidayOn(picked);
    String t(DateTime d) => bnTime(d.hour, d.minute);

    Widget sunTile(IconData icon, Color c, String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(icon, color: c, size: 22),
              const SizedBox(width: 8),
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: body(11.5, color: Colors.white70, height: 1.2)),
                  Text(value, style: body(15, weight: FontWeight.w600, color: Colors.white, height: 1.3)),
                ]),
              ),
            ]),
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: SwipeTabs<CalSide>(
          items: const [CalSide.bangla, CalSide.arabic],
          value: _side,
          onChanged: (v) => setState(() => _side = v),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              TopBar(title: tr('ক্যালেন্ডার'), sub: tr('ইংরেজি, বাংলা আর হিজরি এক সাথে'), note: HandNote(tr('প্রতিটা দিন গুরুত্বপূর্ণ'), size: 12.5, rotate: -5)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: C.fill, borderRadius: BorderRadius.circular(22), border: C.dark ? Border.all(color: C.fillEdge) : null),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(picked == today ? tr('আজ বাংলা তারিখ') : tr('বাংলা তারিখ'), style: body(13, color: Colors.white70)),
                        Text(bd.text, style: display(26, weight: 700, color: Colors.white, height: 1.3)),
                        Text('${weekdayName(picked)} · ${bnDigits(picked.day)} ${monthName(picked.month)} ${bnDigits(picked.year)}', style: body(13.5, color: Colors.white)),
                        const SizedBox(height: 2),
                        Text(trf('হিজরি · {0}', [hj.short]), style: body(13.5, weight: FontWeight.w600, color: Colors.white)),
                        Text(hj.arabic, textDirection: TextDirection.rtl, style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.5)),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        const Icon(Icons.eco_outlined, color: Colors.white, size: 20),
                        Text(trf('{0}কাল', [bd.season]), style: body(12.5, weight: FontWeight.w600, color: Colors.white)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    sunTile(Icons.wb_twilight, const Color(0xFFFDE68A), tr('সূর্যোদয়'), t(sun.sunrise)),
                    const SizedBox(width: 8),
                    sunTile(Icons.nights_stay_outlined, const Color(0xFFFDBA74), tr('সূর্যাস্ত'), t(sun.sunset)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                      trf('{0} অনুযায়ী · জেলা সেটিংসে বদলানো যায়{1}', [
                        place.label,
                        picked == today ? ' · ${bnDigits(toNext)} ${tr('দিন পর')} ${bnDigits(1)} ${nextBd.monthName}${nextBd.month % 2 == 0 ? ', ${trf('{0}কাল শুরু', [nextBd.season])}' : ''}' : ''
                      ]),
                      style: body(12.5, color: Colors.white, height: 1.45)),
                ]),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 10),
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                    child: Text(trf('নামাজের সময় ({0}, আনুমানিক)', [place.label]), style: body(12.5, color: C.muted)),
                  ),
                  Row(children: [
                    for (final (n, d) in [(tr('ফজর'), sun.fajr), (tr('জোহর'), sun.dhuhr), (tr('আসর'), sun.asr), (tr('মাগরিব'), sun.maghrib), (tr('এশা'), sun.isha)])
                      Expanded(
                        child: Column(children: [
                          Text(n, style: body(11.5, color: C.muted)),
                          Text(bnDigits('${d.hour > 12 ? d.hour - 12 : d.hour}:${d.minute.toString().padLeft(2, '0')}'), style: body(14, weight: FontWeight.w600)),
                        ]),
                      ),
                  ]),
                ]),
              ),
              if (hj.isRamadan) ...[
                const SizedBox(height: 10),
                Panel(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Row(children: [
                    Icon(Icons.nightlight_round, color: C.muted2),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(trf('রমজান · সেহরির শেষ সময় {0} · ইফতার {1} (আনুমানিক)', [bnTime(sun.fajr.hour, sun.fajr.minute), bnTime(sun.maghrib.hour, sun.maghrib.minute)]),
                          style: body(14, weight: FontWeight.w500)),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 10),
              // The Hijri date follows the moon seen in Bangladesh: a day either way can be set here.
              Panel(
                padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        brain.number('hijri_adjust') == 0
                            ? tr('হিজরি তারিখ চাঁদ দেখার ওপর এক দিন এদিক-ওদিক হতে পারে')
                            : trf('হিজরি তারিখ {0} দিন সরানো আছে', [bnDigits(brain.number('hijri_adjust') > 0 ? '+${brain.number('hijri_adjust')}' : '${brain.number('hijri_adjust')}')]),
                        style: body(12.5, color: C.muted)),
                  ),
                  IconButton(
                    tooltip: tr('হিজরি তারিখ এক দিন পিছিয়ে দিন'),
                    onPressed: brain.number('hijri_adjust') <= -2 ? null : () => brain.setPref('hijri_adjust', brain.number('hijri_adjust') - 1),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  IconButton(
                    tooltip: tr('হিজরি তারিখ এক দিন এগিয়ে দিন'),
                    onPressed: brain.number('hijri_adjust') >= 2 ? null : () => brain.setPref('hijri_adjust', brain.number('hijri_adjust') + 1),
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              SegTabs<CalSide>(
                items: [(CalSide.bangla, tr('বাংলা তারিখ')), (CalSide.arabic, tr('আরবি (হিজরি) তারিখ'))],
                value: _side,
                onChanged: (v) => setState(() => _side = v),
              ),
              const SizedBox(height: 8),
              _monthGrid(month, today, picked),
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
                child: Text(tr('সামনের সরকারি ছুটি'), style: body(13, weight: FontWeight.w600, color: C.muted)),
              ),
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
                            Text('${holidayRange(r)}${r.days > 1 ? ' · টানা ${bnDigits(r.days)} দিন' : ' · ${weekdayName(r.start)}'}', style: body(12.5, color: C.muted)),
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
            ],
          ),
        ),
      ),
    );
  }

  String _inDays(int n) => n <= 0 ? tr('আজ') : (n == 1 ? tr('কাল') : trf('{0} দিন পর', [bnDigits(n)]));

  Widget _monthGrid(DateTime month, DateTime today, DateTime picked) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = (DateTime(month.year, month.month).weekday + 1) % 7; // Saturday first
    final heads = [tr('শনি'), tr('রবি'), tr('সোম'), tr('মঙ্গল'), tr('বুধ'), tr('বৃহঃ'), tr('শুক্র')];
    final first = banglaDate(DateTime(month.year, month.month));
    final last = banglaDate(DateTime(month.year, month.month, days));
    final adjust = BrainScope.of(context).number('hijri_adjust');
    final hFirst = hijriDate(DateTime(month.year, month.month), adjust: adjust);
    final hLast = hijriDate(DateTime(month.year, month.month, days), adjust: adjust);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Row(children: [
          IconButton(tooltip: tr('আগের মাস'), onPressed: () => setState(() => _month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
            child: Column(children: [
              Text('${monthName(month.month)} ${bnDigits(month.year)}', style: body(15, weight: FontWeight.w600)),
              Text(_side == CalSide.bangla ? '${first.monthName} – ${last.monthName} ${bnDigits(last.year)}' : '${hFirst.monthName} – ${hLast.monthName} ${bnDigits(hLast.year)}',
                  style: body(12, color: C.muted)),
            ]),
          ),
          IconButton(tooltip: tr('পরের মাস'), onPressed: () => setState(() => _month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        Row(children: [
          for (final (i, h) in heads.indexed) Expanded(child: Text(h, textAlign: TextAlign.center, style: body(11.5, color: i == 0 || i == 6 ? _red : C.muted))),
        ]),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
          childAspectRatio: 0.9,
          children: [
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (var d = 1; d <= days; d++) _cell(DateTime(month.year, month.month, d), today, picked),
          ],
        ),
      ]),
    );
  }

  Widget _cell(DateTime d, DateTime today, DateTime picked) {
    final brain = BrainScope.of(context);
    final isToday = d == today;
    final busy = itemsOn(brain.data, d, brain.services.now()).isNotEmpty;
    final isPicked = d == picked && !isToday;
    final hol = holidayOn(d) != null;
    final weekend = isWeekend(d);
    final bg = isToday ? C.fill : (hol ? C.roseTint : Colors.transparent);
    final fg = isToday ? Colors.white : (hol || weekend ? _red : C.ink);
    return InkWell(
      key: Key('day-${d.year}-${d.month}-${d.day}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        setState(() => _picked = d);
        _dayDetails(d);
      },
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: isPicked ? Border.all(color: C.primary, width: 1.5) : null),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(bnDigits(d.day), style: body(14.5, weight: FontWeight.w600, color: fg, height: 1.2)),
          Text(_side == CalSide.bangla ? bnDigits(banglaDate(d).day) : bnDigits(hijriDate(d, adjust: brain.number('hijri_adjust')).day),
              style: body(10, color: isToday ? Colors.white70 : (_side == CalSide.arabic ? C.teal : C.muted), height: 1.2)),
          Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(shape: BoxShape.circle, color: busy ? (isToday ? Colors.white : C.orange) : Colors.transparent),
          ),
        ]),
      ),
    );
  }

  /// A day tapped: its dates, holiday, what is on it, and adding to it.
  Future<void> _dayDetails(DateTime d) async {
    final brain = BrainScope.read(context);
    final now = brain.services.now();
    final hol = holidayOn(d);
    final hj = hijriDate(d, adjust: brain.number('hijri_adjust'));
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
              Text('${banglaDate(d).text} · ${hj.dayMonth}', style: body(13.5, color: C.muted)),
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
                  icon: Icon(Icons.cake_outlined, color: C.muted2),
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
