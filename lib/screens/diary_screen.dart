import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'calendar_screen.dart';
import 'plan_screens.dart';

enum DiaryView { day, week, month }

/// Does [r] ring on [day]?
bool remindsOn(Reminder r, DateTime day) {
  final start = dayOnly(r.date);
  final d = dayOnly(day);
  if (d.isBefore(start)) return false;
  return switch (r.repeat) {
    Repeat.none => d == start,
    Repeat.monthly => d.day == start.day,
    Repeat.yearly => d.month == start.month && d.day == start.day,
    _ => true, // daily and the short repeats
  };
}

/// Everything on [day]: reminders by time, then that day's to-dos (and on
/// today, the to-dos with no day).
List<PlanItem> itemsOn(AppData d, DateTime day, DateTime now) {
  final dd = dayOnly(day);
  final today = dayOnly(now) == dd;
  final rem = [
    for (final r in d.reminders)
      if (remindsOn(r, dd)) PlanItem.reminder(r, DateTime(dd.year, dd.month, dd.day, r.hour, r.minute)),
  ]..sort((a, b) => a.sort.compareTo(b.sort));
  final tasks = [
    for (final t in d.tasks)
      if ((t.due != null && dayOnly(t.due!) == dd && (!t.done || (t.doneAt != null && dayOnly(t.doneAt!) == dd))) ||
          (today && t.due == null && !t.done))
        PlanItem.task(t, DateTime(dd.year, dd.month, dd.day, 23, 59)),
  ];
  return [...rem, ...tasks];
}

/// দিনলিপি: the day, the week or the month — reminders and to-dos, with
/// the Bangla date beside every day.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  DiaryView _view = DiaryView.day;
  DateTime? _picked;

  /// Saturday of the week holding [d] (the Bangladesh week starts then).
  DateTime _weekStart(DateTime d) => dayOnly(d).subtract(Duration(days: (d.weekday + 1) % 7));

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final day = _picked ?? dayOnly(now);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(children: [
          Expanded(child: Text('দিনলিপি', style: display(24, weight: 700))),
          IconButton(
            tooltip: 'বাংলা তারিখ ও ছুটি',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
            icon: const Icon(Icons.calendar_month_outlined, color: C.ink),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: C.ink, shape: const StadiumBorder()),
            onPressed: () => showAddSheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('যোগ', style: body(14, weight: FontWeight.w600, color: Colors.white)),
          ),
        ]),
        const SizedBox(height: 10),
        SegTabs<DiaryView>(
          items: const [(DiaryView.day, 'দৈনিক'), (DiaryView.week, 'সাপ্তাহিক'), (DiaryView.month, 'মাসিক')],
          value: _view,
          onChanged: (v) => setState(() => _view = v),
        ),
        const SizedBox(height: 12),
        ...switch (_view) {
          DiaryView.day => _dayView(brain, day, now),
          DiaryView.week => _weekView(brain, day, now),
          DiaryView.month => _monthView(brain, day, now),
        },
      ],
    );
  }

  Widget _box(List<Widget> rows) => Container(
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14, color: C.line),
            r,
          ],
        ]),
      );

  Widget _label(String text, {Widget? action}) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 0, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: body(13, weight: FontWeight.w600, color: C.muted))),
          if (action != null) action,
        ]),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text, style: body(14, color: C.muted, height: 1.5)),
      );

  String _dayTitle(DateTime d, DateTime now) {
    final diff = dayOnly(d).difference(dayOnly(now)).inDays;
    final rel = switch (diff) { 0 => 'আজ · ', 1 => 'কাল · ', -1 => 'গতকাল · ', _ => '' };
    return '$rel${weekdayName(d)}, ${bnDigits(d.day)} ${bnMonths[d.month - 1]} · ${banglaDate(d).dayMonth}';
  }

  List<Widget> _dayView(Brain brain, DateTime day, DateTime now) {
    final start = _weekStart(day);
    final items = itemsOn(brain.data, day, now);
    final rem = items.where((i) => i.reminder != null).toList();
    final tasks = items.where((i) => i.task != null).toList();
    final hol = holidayOn(day);
    return [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          IconButton(
            tooltip: 'আগের সপ্তাহ',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _picked = day.subtract(const Duration(days: 7))),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          for (var i = 0; i < 7; i++) Expanded(child: _dayCell(brain, start.add(Duration(days: i)), day, now)),
          IconButton(
            tooltip: 'পরের সপ্তাহ',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _picked = day.add(const Duration(days: 7))),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
      ),
      if (hol != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('ছুটি: ${hol.name}', style: body(14, weight: FontWeight.w600, color: const Color(0xFFBE123C))),
        ),
      _label(_dayTitle(day, now)),
      if (rem.isEmpty && tasks.isEmpty)
        _box([_empty('এই দিনে কিছু রাখা নেই। “যোগ” চাপুন, বা সহকারীকে বলুন — যেমন “কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও”।')])
      else ...[
        if (rem.isNotEmpty) _box([for (final i in rem) PlanRow(item: i)]),
        if (tasks.isNotEmpty) ...[
          _label('কাজ · ${bnDigits(tasks.length)}টার ${bnDigits(tasks.where((x) => x.task!.done).length)}টা শেষ'),
          _box([for (final i in tasks) PlanRow(item: i)]),
        ],
      ],
      _repeating(brain),
    ];
  }

  Widget _dayCell(Brain brain, DateTime d, DateTime selected, DateTime now) {
    final on = dayOnly(d) == dayOnly(selected);
    final today = dayOnly(d) == dayOnly(now);
    final red = holidayOn(d) != null || isWeekend(d);
    final has = itemsOn(brain.data, d, now).isNotEmpty;
    final fg = on ? Colors.white : (red ? const Color(0xFFBE123C) : C.ink);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _picked = dayOnly(d)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: on ? C.green : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: today && !on ? Border.all(color: C.green) : null,
        ),
        child: Column(children: [
          Text(weekdayShort(d), style: body(10.5, color: on ? Colors.white70 : C.muted, height: 1.2)),
          Text(bnDigits(d.day), style: body(16, weight: FontWeight.w700, color: fg, height: 1.25)),
          Text(bnDigits(banglaDate(d).day), style: body(10, color: on ? Colors.white70 : C.muted, height: 1.2)),
          const SizedBox(height: 2),
          Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: has ? (on ? Colors.white : C.orange) : Colors.transparent)),
        ]),
      ),
    );
  }

  List<Widget> _weekView(Brain brain, DateTime day, DateTime now) {
    final start = _weekStart(day);
    final end = start.add(const Duration(days: 6));
    return [
      Row(children: [
        IconButton(tooltip: 'আগের সপ্তাহ', onPressed: () => setState(() => _picked = day.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Text('${bnDigits(start.day)} ${bnMonthsShort[start.month - 1]} – ${bnDigits(end.day)} ${bnMonthsShort[end.month - 1]}',
              textAlign: TextAlign.center, style: body(15, weight: FontWeight.w600)),
        ),
        IconButton(tooltip: 'পরের সপ্তাহ', onPressed: () => setState(() => _picked = day.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right_rounded)),
      ]),
      for (var i = 0; i < 7; i++) ..._dayBlock(brain, start.add(Duration(days: i)), now),
    ];
  }

  List<Widget> _dayBlock(Brain brain, DateTime d, DateTime now) {
    final items = itemsOn(brain.data, d, now);
    final hol = holidayOn(d);
    return [
      _label('${_dayTitle(d, now)}${hol != null ? ' · ছুটি' : ''}'),
      items.isEmpty ? _box([_empty(hol?.name ?? 'কিছু নেই')]) : _box([for (final i in items) PlanRow(item: i)]),
    ];
  }

  List<Widget> _monthView(Brain brain, DateTime day, DateTime now) {
    final first = DateTime(day.year, day.month);
    final days = DateTime(day.year, day.month + 1, 0).day;
    final blocks = <Widget>[];
    for (var i = 0; i < days; i++) {
      final d = first.add(Duration(days: i));
      final items = itemsOn(brain.data, d, now).where((x) => x.reminder == null || x.reminder!.repeat == Repeat.none || x.reminder!.repeat == Repeat.monthly || x.reminder!.repeat == Repeat.yearly).toList();
      final hol = holidayOn(d);
      if (items.isEmpty && hol == null) continue;
      blocks
        ..add(_label('${_dayTitle(d, now)}${hol != null ? ' · ${hol.name}' : ''}'))
        ..add(items.isEmpty ? _box([_empty('ছুটি')]) : _box([for (final x in items) PlanRow(item: x)]));
    }
    return [
      Row(children: [
        IconButton(tooltip: 'আগের মাস', onPressed: () => setState(() => _picked = DateTime(day.year, day.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Column(children: [
            Text('${bnMonths[day.month - 1]} ${bnDigits(day.year)}', style: body(16, weight: FontWeight.w600)),
            Text('${banglaDate(first).monthName} – ${banglaDate(DateTime(day.year, day.month, days)).monthName} ${bnDigits(banglaDate(first).year)}',
                style: body(12, color: C.muted)),
          ]),
        ),
        IconButton(tooltip: 'পরের মাস', onPressed: () => setState(() => _picked = DateTime(day.year, day.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
      ]),
      if (blocks.isEmpty) _box([_empty('এই মাসে কোনো দিন-তারিখ ধরা কাজ বা রিমাইন্ডার নেই।')]) else ...blocks,
      _repeating(brain),
    ];
  }

  /// Daily, monthly and yearly reminders, together.
  Widget _repeating(Brain brain) {
    final now = brain.services.now();
    final reps = brain.data.reminders.where((r) => r.repeat != Repeat.none).toList()
      ..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    if (reps.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label('নিয়মিত'),
      _box([
        for (final r in reps) PlanRow(item: PlanItem.reminder(r, DateTime(now.year, now.month, now.day, r.hour, r.minute))),
      ]),
    ]);
  }
}
