import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import 'home_page.dart' show holidayRange;

/// বাংলা তারিখ, ঋতু, সূর্যোদয়-সূর্যাস্ত, নামাজের সময় আর সরকারি ছুটি।
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime? _month;
  DateTime? _picked;

  static const _red = Color(0xFFBE123C);

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final today = DateTime(now.year, now.month, now.day);
    final month = _month ?? DateTime(now.year, now.month);
    final picked = _picked ?? today;
    final bd = banglaDate(picked);
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
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Row(children: [
              IconButton(tooltip: 'ফিরে যান', onPressed: () => Navigator.of(context).maybePop(), icon: const Icon(Icons.chevron_left_rounded, size: 30)),
              Expanded(child: Text('বাংলা তারিখ ও ছুটি', style: display(21, weight: 700))),
            ]),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(colors: [C.green, Color(0xFF0F766E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(picked == today ? 'আজ বাংলা তারিখ' : 'বাংলা তারিখ', style: body(13, color: Colors.white70)),
                      Text(bd.text, style: display(26, weight: 700, color: Colors.white, height: 1.3)),
                      Text('${weekdayName(picked)} · ${bnDigits(picked.day)} ${bnMonths[picked.month - 1]} ${bnDigits(picked.year)}',
                          style: body(13.5, color: Colors.white)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      const Icon(Icons.eco_outlined, color: Colors.white, size: 20),
                      Text('${bd.season}কাল', style: body(12.5, weight: FontWeight.w600, color: Colors.white)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  sunTile(Icons.wb_twilight, const Color(0xFFFDE68A), 'সূর্যোদয়', t(sun.sunrise)),
                  const SizedBox(width: 8),
                  sunTile(Icons.nights_stay_outlined, const Color(0xFFFDBA74), 'সূর্যাস্ত', t(sun.sunset)),
                ]),
                const SizedBox(height: 8),
                Text(
                    '${place.name} অনুযায়ী · জেলা “আমি” পাতায় বদলানো যায়${picked == today ? ' · ${bnDigits(toNext)} দিন পর ১ ${nextBd.monthName}${nextBd.month % 2 == 0 ? ', ${nextBd.season}কাল শুরু' : ''}' : ''}',
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
                  child: Text('নামাজের সময় (${place.name}, আনুমানিক)', style: body(12.5, color: C.muted)),
                ),
                Row(children: [
                  for (final (n, d) in [('ফজর', sun.fajr), ('জোহর', sun.dhuhr), ('আসর', sun.asr), ('মাগরিব', sun.maghrib), ('এশা', sun.isha)])
                    Expanded(
                      child: Column(children: [
                        Text(n, style: body(11.5, color: C.muted)),
                        Text(bnDigits('${d.hour > 12 ? d.hour - 12 : d.hour}:${d.minute.toString().padLeft(2, '0')}'),
                            style: body(14, weight: FontWeight.w600)),
                      ]),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 10),
            _monthGrid(month, today, picked),
            if (pickedHol != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('${bnDigits(picked.day)} ${bnMonths[picked.month - 1]}: ${pickedHol.name}${pickedHol.executive ? ' (নির্বাহী আদেশে)' : ''}',
                    style: body(14, weight: FontWeight.w600, color: _red)),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
              child: Text('সামনের সরকারি ছুটি', style: body(13, weight: FontWeight.w600, color: C.muted)),
            ),
            Container(
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                for (final (i, r) in upcomingHolidays(today, count: 6).indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14, color: C.line),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    child: Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.flag_outlined, color: _red, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(r.name, style: body(15, weight: FontWeight.w600)),
                          Text('${holidayRange(r)}${r.days > 1 ? ' · টানা ${bnDigits(r.days)} দিন' : ' · ${weekdayName(r.start)}'}',
                              style: body(12.5, color: C.muted)),
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
              child: Text('চাঁদ দেখার ওপর নির্ভর ছুটি এক-দুই দিন বদলাতে পারে।', style: body(12, color: C.muted)),
            ),
          ],
        ),
      ),
    );
  }

  String _inDays(int n) => n <= 0 ? 'আজ' : (n == 1 ? 'কাল' : '${bnDigits(n)} দিন পর');

  Widget _monthGrid(DateTime month, DateTime today, DateTime picked) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final lead = (DateTime(month.year, month.month).weekday + 1) % 7; // Saturday first
    const heads = ['শনি', 'রবি', 'সোম', 'মঙ্গল', 'বুধ', 'বৃহঃ', 'শুক্র'];
    final first = banglaDate(DateTime(month.year, month.month));
    final last = banglaDate(DateTime(month.year, month.month, days));
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
      decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Row(children: [
          IconButton(tooltip: 'আগের মাস', onPressed: () => setState(() => _month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
          Expanded(
            child: Column(children: [
              Text('${bnMonths[month.month - 1]} ${bnDigits(month.year)}', style: body(15, weight: FontWeight.w600)),
              Text('${first.monthName} – ${last.monthName} ${bnDigits(last.year)}', style: body(12, color: C.muted)),
            ]),
          ),
          IconButton(tooltip: 'পরের মাস', onPressed: () => setState(() => _month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
        ]),
        Row(children: [
          for (final (i, h) in heads.indexed)
            Expanded(child: Text(h, textAlign: TextAlign.center, style: body(11.5, color: i == 0 || i == 6 ? _red : C.muted))),
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
    final isToday = d == today;
    final isPicked = d == picked && !isToday;
    final hol = holidayOn(d) != null;
    final weekend = isWeekend(d);
    final bg = isToday ? C.green : (hol ? const Color(0xFFFFF1F2) : Colors.transparent);
    final fg = isToday ? Colors.white : (hol || weekend ? _red : C.ink);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(() => _picked = d),
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: isPicked ? Border.all(color: C.green, width: 1.5) : null),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(bnDigits(d.day), style: body(14.5, weight: FontWeight.w600, color: fg, height: 1.2)),
          Text(bnDigits(banglaDate(d).day), style: body(10, color: isToday ? Colors.white70 : C.muted, height: 1.2)),
        ]),
      ),
    );
  }
}
