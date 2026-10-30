import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/calendar_bd.dart';
import '../logic/proactive.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'calendar_screen.dart';
import 'health_screens.dart';
import 'onboarding_screen.dart';
import 'special_days_screen.dart';
import 'plan_screens.dart';
import '../logic/lang.dart';
import '../logic/pro.dart' show medicalOff;

enum DiaryView { day, week, month }

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
      if ((t.onDay(dd) && (!t.done || (t.doneAt != null && dayOnly(t.doneAt!) == dd))) || (today && t.due == null && !t.done)) PlanItem.task(t, DateTime(dd.year, dd.month, dd.day, 23, 59)),
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
  DateTime _weekStart(DateTime d) => weekStartOf(d);

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final day = _picked ?? dayOnly(now);
    // "যোগ করুন" sits at the bottom, by the thumb, as on the other pages.
    return Stack(children: [
      TabPages<DiaryView>(
        items: [(DiaryView.day, tr('দৈনিক')), (DiaryView.week, tr('সাপ্তাহিক')), (DiaryView.month, tr('মাসিক'))],
        value: _view,
        onChanged: (v) => setState(() => _view = v),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
        top: (tabs) => [
          TabTitle(
            tr('দিনলিপি'),
            sub: tr('দিনের কাজ, রিমাইন্ডার আর অভ্যাস'),
            trailing: IconButton(
              tooltip: tr('ক্যালেন্ডার'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
              icon: Icon(Icons.calendar_month_outlined, color: C.ink),
            ),
          ),
          const SizedBox(height: 14),
          tabs,
          const SizedBox(height: 12),
        ],
        // Habits, medicines, special days and ready lists sit at the bottom
        // with an example each, so a new user sees what they are for (owner, 24 Oct).
        page: (view) => [
          ...switch (view) {
            DiaryView.day => _dayView(brain, day, now),
            DiaryView.week => _weekView(brain, day, now),
            DiaryView.month => _monthView(brain, day, now),
          },
          _moreToKeep(),
        ],
      ),
      Positioned(
        right: 16,
        bottom: 16,
        child: AddButton(key: const Key('diary-add'), label: tr('কাজ যোগ করুন'), onPressed: () => showAddSheet(context, day: _picked)),
      ),
    ]);
  }

  /// "আরও যা রাখা যায়": each with an example of what to say or keep.
  Widget _moreToKeep() {
    Widget row(Key key, String label, IconData icon, String example, Widget page) => ListRow(
          key: key,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: C.green, size: 21),
          ),
          title: label,
          subtitle: example,
          trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label(tr('আরও যা রাখা যায়')),
      _box([
        row(const Key('diary-habits'), tr('অভ্যাস'), Icons.local_fire_department_outlined, tr('যেমন: প্রতিদিন ৩০ মিনিট হাঁটা, ৫ ওয়াক্ত নামাজ'), const HabitsScreen()),
        if (!medicalOff) row(const Key('diary-medicines'), tr('ওষুধ'), Icons.medication_outlined, tr('যেমন: নাপা — সকাল ৮টা আর রাত ৯টা, খাবারের পরে'), const MedicinesScreen()),
        row(const Key('diary-special'), tr('বিশেষ দিন'), Icons.cake_outlined, tr('যেমন: আম্মার জন্মদিন ১২ মার্চ — প্রতি বছর আগের দিন মনে করাবে'), const SpecialDaysScreen()),
        row(const Key('diary-templates'), tr('তৈরি তালিকা'), Icons.checklist_rtl_rounded, tr('যেমন: ঈদের কেনাকাটা, মাসের বাজার — এক চাপে পুরো তালিকা'), const TemplatesScreen()),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Text(tr('মুখেও বলা যায়: “রোজ সকালে হাঁটা অভ্যাসে রাখো”, “নাপা রাত ৯টায় মনে করিয়ে দিও”'), style: body(12.5, color: C.muted, height: 1.45)),
      ),
    ]);
  }

  /// A to-do that can be dragged onto a day in the strip above.
  Widget _draggable(PlanItem i) {
    final t = i.task;
    if (t == null || t.done) return PlanRow(item: i);
    return LongPressDraggable<Task>(
      data: t,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: C.green, borderRadius: BorderRadius.circular(11)),
          child: Text(t.title, style: body(14, weight: FontWeight.w600, color: C.onAccent)),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.4, child: PlanRow(item: i)),
      child: PlanRow(item: i),
    );
  }

  Widget _box(List<Widget> rows) => Container(
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: C.border)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          for (final (i, r) in rows.indexed) ...[
            if (i > 0) Divider(height: 1, indent: 14, endIndent: 14, color: C.border),
            r,
          ],
        ]),
      );

  Widget _label(String text, {Widget? action}) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
        child: Row(children: [
          Expanded(child: Text(text, style: display(16, weight: 600))),
          if (action != null) action,
        ]),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text, style: body(14, color: C.muted, height: 1.5)),
      );

  String _dayTitle(DateTime d, DateTime now) {
    final diff = dayOnly(d).difference(dayOnly(now)).inDays;
    final rel = switch (diff) { 0 => '${tr('আজ')} · ', 1 => '${tr('কাল')} · ', -1 => '${tr('গতকাল')} · ', _ => '' };
    return '$rel${weekdayName(d)}, ${bnDigits(d.day)} ${monthName(d.month)} · ${banglaDate(d).dayMonth}';
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
        decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(17), border: Border.all(color: C.border)),
        child: Row(children: [
          IconButton(
            tooltip: tr('আগের সপ্তাহ'),
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _picked = day.subtract(const Duration(days: 7))),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          for (var i = 0; i < 7; i++) Expanded(child: _dayCell(brain, start.add(Duration(days: i)), day, now)),
          IconButton(
            tooltip: tr('পরের সপ্তাহ'),
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _picked = day.add(const Duration(days: 7))),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
      ),
      if (hol != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(trf('ছুটি: {0}', [hol.label]), style: body(14, weight: FontWeight.w600, color: C.rose)),
        ),
      _label(_dayTitle(day, now)),
      if (rem.isEmpty && tasks.isEmpty)
        _box([_empty(tr('এই দিনে কিছু রাখা নেই। নিচের “কাজ যোগ করুন” চাপুন, বা সহকারীকে বলুন — যেমন “কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও”।'))])
      else ...[
        if (rem.isNotEmpty) _box([for (final i in rem) PlanRow(item: i)]),
        if (tasks.isNotEmpty) ...[
          _label(trf('কাজ · {0}টার {1}টা শেষ', [bnDigits(tasks.length), bnDigits(tasks.where((x) => x.task!.done).length)])),
          _box([for (final i in tasks) _draggable(i)]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Text(tr('কাজ চেপে ধরে উপরের কোনো দিনে টেনে আনলে সেই দিনে সরে যাবে।'), style: body(12, color: C.muted)),
          ),
        ],
      ],
      if (dayOnly(day) == dayOnly(now) && brain.data.habits.isNotEmpty) ...[
        _label(tr('আজকের অভ্যাস'), action: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HabitsScreen())), child: Text(tr('সব')))),
        HabitStrip(day: day),
      ],
      if (dayOnly(day) == dayOnly(now) && brain.data.medicines.isNotEmpty) ...[
        _label(tr('আজকের ওষুধ'), action: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MedicinesScreen())), child: Text(tr('সব')))),
        DoseStrip(day: day),
      ],
      _repeating(brain),
    ];
  }

  Widget _dayCell(Brain brain, DateTime d, DateTime selected, DateTime now) {
    final on = dayOnly(d) == dayOnly(selected);
    final today = dayOnly(d) == dayOnly(now);
    final red = holidayOn(d) != null || isWeekend(d);
    final has = itemsOn(brain.data, d, now).isNotEmpty;
    final fg = on ? C.onAccent : (red ? C.rose : C.ink);
    return DragTarget<Task>(
      onAcceptWithDetails: (det) async {
        await brain.moveTask(det.data, d);
        if (mounted) toast(context, trf('“{0}” সরলো {1}-এ', [det.data.title, shortDate(d)]));
      },
      builder: (context, cand, _) => _cell(d, on, today, has, fg, cand.isNotEmpty),
    );
  }

  Widget _cell(DateTime d, bool on, bool today, bool has, Color fg, bool hover) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _picked = dayOnly(d)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: on ? C.green : (hover ? C.greenTint : Colors.transparent),
          borderRadius: BorderRadius.circular(12),
          border: hover ? Border.all(color: C.green, width: 2) : (today && !on ? Border.all(color: C.green) : null),
        ),
        child: Column(children: [
          Text(weekdayShort(d), style: body(11, color: on ? C.onAccent.withValues(alpha: 0.8) : C.muted, height: 1.2)),
          Text(bnDigits(d.day), style: body(16, weight: FontWeight.w700, color: fg, height: 1.25)),
          Text(bnDigits(banglaDate(d).day), style: body(11, color: on ? C.onAccent.withValues(alpha: 0.8) : C.muted, height: 1.2)),
          const SizedBox(height: 2),
          Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: has ? (on ? C.onAccent : C.warn) : Colors.transparent)),
        ]),
      ),
    );
  }

  List<Widget> _weekView(Brain brain, DateTime day, DateTime now) {
    final start = _weekStart(day);
    final end = start.add(const Duration(days: 6));
    return [
      Row(children: [
        IconButton(tooltip: tr('আগের সপ্তাহ'), onPressed: () => setState(() => _picked = day.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Text('${bnDigits(start.day)} ${monthShort(start.month)} – ${bnDigits(end.day)} ${monthShort(end.month)}', textAlign: TextAlign.center, style: body(15, weight: FontWeight.w600)),
        ),
        IconButton(tooltip: tr('পরের সপ্তাহ'), onPressed: () => setState(() => _picked = day.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right_rounded)),
      ]),
      for (var i = 0; i < 7; i++) ..._dayBlock(brain, start.add(Duration(days: i)), now),
    ];
  }

  List<Widget> _dayBlock(Brain brain, DateTime d, DateTime now) {
    final items = itemsOn(brain.data, d, now);
    final hol = holidayOn(d);
    return [
      _label('${_dayTitle(d, now)}${hol != null ? ' · ${tr('ছুটি')}' : ''}'),
      items.isEmpty ? _box([_empty(hol?.label ?? tr('কিছু নেই'))]) : _box([for (final i in items) PlanRow(item: i)]),
    ];
  }

  List<Widget> _monthView(Brain brain, DateTime day, DateTime now) {
    final first = DateTime(day.year, day.month);
    final days = DateTime(day.year, day.month + 1, 0).day;
    final blocks = <Widget>[];
    for (var i = 0; i < days; i++) {
      final d = first.add(Duration(days: i));
      final items =
          itemsOn(brain.data, d, now).where((x) => x.reminder == null || x.reminder!.repeat == Repeat.none || x.reminder!.repeat == Repeat.monthly || x.reminder!.repeat == Repeat.yearly).toList();
      final hol = holidayOn(d);
      if (items.isEmpty && hol == null) continue;
      blocks
        ..add(_label('${_dayTitle(d, now)}${hol != null ? ' · ${hol.label}' : ''}'))
        ..add(items.isEmpty ? _box([_empty(tr('ছুটি'))]) : _box([for (final x in items) PlanRow(item: x)]));
    }
    return [
      Row(children: [
        IconButton(tooltip: tr('আগের মাস'), onPressed: () => setState(() => _picked = DateTime(day.year, day.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
        Expanded(
          child: Column(children: [
            Text('${monthName(day.month)} ${bnDigits(day.year)}', style: body(16, weight: FontWeight.w600)),
            Text('${banglaDate(first).monthName} – ${banglaDate(DateTime(day.year, day.month, days)).monthName} ${bnDigits(banglaDate(first).year)}', style: body(12, color: C.muted)),
          ]),
        ),
        IconButton(tooltip: tr('পরের মাস'), onPressed: () => setState(() => _picked = DateTime(day.year, day.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
      ]),
      if (blocks.isEmpty) _box([_empty(tr('এই মাসে কোনো দিন-তারিখ ধরা কাজ বা রিমাইন্ডার নেই।'))]) else ...blocks,
      _repeating(brain),
    ];
  }

  /// Daily, monthly and yearly reminders, together.
  Widget _repeating(Brain brain) {
    final now = brain.services.now();
    final reps = brain.data.reminders.where((r) => r.repeat != Repeat.none).toList()..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    if (reps.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label(tr('নিয়মিত')),
      _box([
        for (final r in reps) PlanRow(item: PlanItem.reminder(r, DateTime(now.year, now.month, now.day, r.hour, r.minute)), next: true),
      ]),
    ]);
  }
}
