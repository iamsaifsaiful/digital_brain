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
import '../logic/repeat_text.dart';

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

  /// Habits, medicines, special days and ready lists: one short chip each
  /// (owner, 3 Nov: the long list became chips).
  Widget _moreToKeep() {
    Widget chip(Key key, String label, IconData icon, String example, Widget page) => Tooltip(
          message: example,
          child: Material(
            key: key,
            color: C.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999), side: BorderSide(color: C.border)),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, size: 17, color: C.green),
                  const SizedBox(width: 6),
                  Text(label, style: body(13, weight: FontWeight.w600)),
                ]),
              ),
            ),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label(tr('আরও যা রাখা যায়')),
      Wrap(spacing: 8, runSpacing: 8, children: [
        chip(const Key('diary-habits'), tr('অভ্যাস'), Icons.local_fire_department_outlined, tr('যেমন: প্রতিদিন ৩০ মিনিট হাঁটা, ৫ ওয়াক্ত নামাজ'), const HabitsScreen()),
        if (!medicalOff) chip(const Key('diary-medicines'), tr('ওষুধ'), Icons.medication_outlined, tr('যেমন: নাপা — সকাল ৮টা আর রাত ৯টা, খাবারের পরে'), const MedicinesScreen()),
        chip(const Key('diary-special'), tr('বিশেষ দিন'), Icons.cake_outlined, tr('যেমন: আম্মার জন্মদিন ১২ মার্চ — প্রতি বছর আগের দিন মনে করাবে'), const SpecialDaysScreen()),
        chip(const Key('diary-templates'), tr('রেডিমেড তালিকা'), Icons.checklist_rtl_rounded, tr('যেমন: ঈদের কেনাকাটা, মাসের বাজার — এক চাপে পুরো তালিকা'), const TemplatesScreen()),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
        child: Text(tr('মুখেও বলা যায়: “রোজ সকালে হাঁটা অভ্যাসে রাখো”, “নাপা রাত ৯টায় মনে করিয়ে দিও”'), style: body(12.5, color: C.muted, height: 1.45)),
      ),
    ]);
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

  Widget _small(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 6),
        child: Text(text, style: body(12.5, weight: FontWeight.w600, color: color ?? C.muted)),
      );

  Widget _empty(String text) => Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text, style: body(14, color: C.muted, height: 1.5)),
      );

  /// "৭:০০" on the timeline's left ("7:00 PM" in English).
  String _clock(DateTime at) {
    if (isEn) return bnTime(at.hour, at.minute);
    final h12 = at.hour % 12 == 0 ? 12 : at.hour % 12;
    return '${bnDigits(h12)}:${bnDigits(at.minute.toString().padLeft(2, '0'))}';
  }

  /// সকাল, দুপুর, বিকেল, সন্ধ্যা, রাত: the timeline's groups.
  String _part(int hour) => tr(hour < 4 ? 'রাত' : hour < 6 ? 'ভোর' : hour < 12 ? 'সকাল' : hour < 15 ? 'দুপুর' : hour < 18 ? 'বিকেল' : hour < 20 ? 'সন্ধ্যা' : 'রাত');

  /// One timed row: the time on the left, the card on the right.
  Widget _timed(PlanItem i) {
    final r = i.reminder!;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(
        width: 58,
        child: Padding(
          padding: const EdgeInsets.only(left: 14),
          child: Text(r.repeat.isInterval ? '' : _clock(i.sort), style: body(12.5, weight: FontWeight.w600, color: C.green)),
        ),
      ),
      Expanded(child: PlanRow(item: i, sub: r.repeat == Repeat.none ? '' : (r.repeat.isInterval ? r.repeat.label : repeatText(r)))),
    ]);
  }

  /// "এখন ৬:৩৪": a red line across the timeline.
  Widget _nowLine(DateTime now) => Padding(
        key: const Key('diary-now'),
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          const SizedBox(width: 14),
          Text(trf('এখন {0}', [_clock(now)]), style: body(11.5, weight: FontWeight.w700, color: C.red)),
          const SizedBox(width: 6),
          Container(width: 7, height: 7, decoration: BoxDecoration(color: C.red, shape: BoxShape.circle)),
          Expanded(child: Container(height: 1.5, color: C.red)),
          const SizedBox(width: 14),
        ]),
      );

  List<Widget> _dayView(Brain brain, DateTime day, DateTime now) {
    final items = itemsOn(brain.data, day, now);
    final rem = items.where((i) => i.reminder != null).toList();
    final tasks = items.where((i) => i.task != null).toList();
    final hol = holidayOn(day);
    final isToday = dayOnly(day) == dayOnly(now);

    // The timeline, by part of the day; on today, the now-line where it falls.
    final groups = <(String, List<PlanItem>)>[];
    for (final i in rem) {
      final p = _part(i.sort.hour);
      if (groups.isEmpty || groups.last.$1 != p) groups.add((p, []));
      groups.last.$2.add(i);
    }
    final firstAhead = isToday ? rem.where((i) => i.sort.isAfter(now)).firstOrNull : null;
    final nowAtEnd = isToday && rem.isNotEmpty && firstAhead == null;
    final timeline = <Widget>[
      for (final (n, (part, list)) in groups.indexed) ...[
        _small(part),
        _box([
          for (final i in list) ...[
            if (identical(i, firstAhead)) _nowLine(now),
            _timed(i),
          ],
          if (nowAtEnd && n == groups.length - 1) _nowLine(now),
        ]),
      ],
    ];

    final diff = dayOnly(day).difference(dayOnly(now)).inDays;
    final rel = switch (diff) { 0 => '${tr('আজ')}, ', 1 => '${tr('কাল')}, ', -1 => '${tr('গতকাল')}, ', _ => '' };
    return [
      // As the week's page (owner, 13 Nov): ‹ the day, with its Bangla and
      // Hijri dates under it ›.
      _nav(
        tr('আগের দিন'),
        tr('পরের দিন'),
        () => setState(() => _picked = day.subtract(const Duration(days: 1))),
        () => setState(() => _picked = day.add(const Duration(days: 1))),
        Column(key: const Key('diary-summary'), children: [
          Text('$rel${weekdayName(day)}, ${bnDigits(day.day)} ${monthName(day.month)}', textAlign: TextAlign.center, style: body(15, weight: FontWeight.w700, color: holidayOn(day) != null || isWeekend(day) ? C.rose : C.ink)),
          Text('${banglaDate(day).dayMonth} · ${hijriDate(day).dayMonth}', textAlign: TextAlign.center, style: body(12, color: C.muted)),
        ]),
      ),
      const SizedBox(height: 4),
      if (hol != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(trf('ছুটি: {0}', [hol.label]), style: body(14, weight: FontWeight.w600, color: C.rose)),
        ),
      if (rem.isEmpty && tasks.isEmpty) ...[
        const SizedBox(height: 12),
        _box([_empty(tr('এই দিনে কিছু রাখা নেই। নিচের “কাজ যোগ করুন” চাপুন, বা সহকারীকে বলুন — যেমন “কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও”।'))]),
      ] else ...[
        ...timeline,
        if (tasks.isNotEmpty) ...[
          _small(trf('যেকোনো সময় · {0}টার {1}টা শেষ', [bnDigits(tasks.length), bnDigits(tasks.where((x) => x.task!.done).length)])),
          _box([for (final i in tasks) PlanRow(item: i)]),
        ],
      ],
      if (isToday && brain.data.habits.isNotEmpty) ...[
        _label(tr('আজকের অভ্যাস'), action: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HabitsScreen())), child: Text(tr('সব')))),
        HabitStrip(day: day),
      ],
      if (isToday && brain.data.medicines.isNotEmpty) ...[
        _label(tr('আজকের ওষুধ'), action: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MedicinesScreen())), child: Text(tr('সব')))),
        DoseStrip(day: day),
      ],
    ];
  }

  Widget _nav(String tipBack, String tipOn, VoidCallback back, VoidCallback on, Widget middle) => Row(children: [
        _navButton(tipBack, Icons.chevron_left_rounded, back),
        Expanded(child: middle),
        _navButton(tipOn, Icons.chevron_right_rounded, on),
      ]);

  Widget _navButton(String tip, IconData icon, VoidCallback onTap) => Tooltip(
        message: tip,
        child: Material(
          color: C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: C.border)),
          child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap, child: SizedBox(width: 40, height: 40, child: Icon(icon, color: C.ink))),
        ),
      );

  List<Widget> _weekView(Brain brain, DateTime day, DateTime now) {
    final start = _weekStart(day);
    final end = start.add(const Duration(days: 6));
    final days = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
    final all = [for (final d in days) ...itemsOn(brain.data, d, now)];
    final nTasks = all.where((i) => i.task != null).length;
    final nRem = all.where((i) => i.reminder != null).length;
    return [
      _nav(
        tr('আগের সপ্তাহ'),
        tr('পরের সপ্তাহ'),
        () => setState(() => _picked = day.subtract(const Duration(days: 7))),
        () => setState(() => _picked = day.add(const Duration(days: 7))),
        Column(children: [
          Text('${bnDigits(start.day)} ${monthShort(start.month)} – ${bnDigits(end.day)} ${monthShort(end.month)}', textAlign: TextAlign.center, style: body(15, weight: FontWeight.w700)),
          Text(trf('{0}টা কাজ · {1}টা রিমাইন্ডার', [bnDigits(nTasks), bnDigits(nRem)]), textAlign: TextAlign.center, style: body(12, color: C.muted)),
        ]),
      ),
      const SizedBox(height: 10),
      for (final d in days) Padding(padding: const EdgeInsets.only(bottom: 8), child: _weekCard(brain, d, now)),
    ];
  }

  /// One day of the week: its date on the left, two of its things, a tap opens the day.
  Widget _weekCard(Brain brain, DateTime d, DateTime now) {
    final items = itemsOn(brain.data, d, now);
    final hol = holidayOn(d);
    final today = dayOnly(d) == dayOnly(now);
    final red = hol != null || isWeekend(d);
    final dateColor = today ? C.green : (red ? C.rose : C.ink);
    // That day's own things before the daily ones (which are on every card).
    bool daily(PlanItem i) => i.reminder != null && (i.reminder!.repeat == Repeat.daily || i.reminder!.repeat.isInterval);
    final shown = [...items.where((i) => !daily(i)), ...items.where(daily)].take(2).toList();
    final more = items.length - shown.length;
    return Material(
      key: Key('week-${d.year}-${d.month}-${d.day}'),
      color: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: today ? C.green : C.border, width: today ? 2 : 1)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() {
          _picked = dayOnly(d);
          _view = DiaryView.day;
        }),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(children: [
            SizedBox(
              width: 58,
              child: Column(children: [
                if (today) Text(tr('আজ'), style: body(11, weight: FontWeight.w600, color: C.green, height: 1.2)),
                Text(bnDigits(d.day), style: body(20, weight: FontWeight.w700, color: dateColor, height: 1.2)),
                Text(weekdayName(d), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(11, color: red ? C.rose : C.muted, height: 1.2)),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: items.isEmpty
                  ? Text(hol?.label ?? tr('কিছু নেই'), style: body(13, color: hol != null ? C.rose : C.muted))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      for (final i in shown)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1.5),
                          child: Text.rich(
                            TextSpan(children: [
                              if (i.reminder != null && !i.reminder!.repeat.isInterval) TextSpan(text: '${bnTime(i.sort.hour, i.sort.minute)}  ', style: body(13, weight: FontWeight.w600, color: C.green)),
                              TextSpan(
                                text: i.title,
                                style: body(13.5, color: (i.task?.done ?? false) ? C.muted : C.ink).copyWith(decoration: (i.task?.done ?? false) ? TextDecoration.lineThrough : null, decorationColor: C.muted),
                              ),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (more > 0 || hol != null)
                        Text([if (more > 0) trf('আরও {0}টা', [bnDigits(more)]), if (hol != null) hol.label].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: hol != null ? C.rose : C.muted)),
                    ]),
            ),
            Icon(Icons.chevron_right_rounded, color: C.muted, size: 20),
          ]),
        ),
      ),
    );
  }

  /// A month's own things: one-day and monthly/yearly reminders and to-dos
  /// (the daily ones would put a dot on every day).
  List<PlanItem> _monthItems(Brain brain, DateTime d, DateTime now) =>
      itemsOn(brain.data, d, now).where((x) => x.reminder == null || x.reminder!.repeat == Repeat.none || x.reminder!.repeat == Repeat.monthly || x.reminder!.repeat == Repeat.yearly).toList();

  /// The month as a list (owner's pick, 13 Nov): the days that have
  /// something, each as the week page's day card.
  List<Widget> _monthView(Brain brain, DateTime day, DateTime now) => _monthAgenda(brain, day, now);

  Widget _monthNav(DateTime day) {
    final first = DateTime(day.year, day.month);
    final last = DateTime(day.year, day.month + 1, 0);
    return _nav(
      tr('আগের মাস'),
      tr('পরের মাস'),
      () => setState(() => _picked = DateTime(day.year, day.month - 1)),
      () => setState(() => _picked = DateTime(day.year, day.month + 1)),
      Column(children: [
        Text('${monthName(day.month)} ${bnDigits(day.year)}', textAlign: TextAlign.center, style: body(15, weight: FontWeight.w700)),
        Text('${banglaDate(first).monthName} – ${banglaDate(last).monthName} ${bnDigits(banglaDate(first).year)}', textAlign: TextAlign.center, style: body(12, color: C.muted)),
      ]),
    );
  }

  List<Widget> _monthAgenda(Brain brain, DateTime day, DateTime now) {
    final last = DateTime(day.year, day.month + 1, 0).day;
    final days = [
      for (var i = 1; i <= last; i++)
        if (_monthItems(brain, DateTime(day.year, day.month, i), now).isNotEmpty || holidayOn(DateTime(day.year, day.month, i)) != null) DateTime(day.year, day.month, i)
    ];
    return [
      _monthNav(day),
      const SizedBox(height: 10),
      if (days.isEmpty) _box([_empty(tr('এ মাসে কিছু রাখা নেই'))]),
      for (final d in days) Padding(padding: const EdgeInsets.only(bottom: 8), child: _weekCard(brain, d, now)),
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
