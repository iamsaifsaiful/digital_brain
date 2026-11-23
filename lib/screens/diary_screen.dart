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
import '../logic/report.dart' show diarySpec, diaryFileName;
import '../logic/templates.dart' show listTemplates;
import '../ui/pdf_export.dart' show exportSpecPdf;

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
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              // Owner, 22 Nov: "দিনলিপি পিডিএফ আকারে ডাউনলোড করার অপশন থাকবে".
              IconButton(
                key: const Key('diary-pdf'),
                tooltip: tr('PDF ডাউনলোড'),
                onPressed: () => _pdf(brain, day),
                icon: Icon(Icons.picture_as_pdf_outlined, color: C.ink),
              ),
              IconButton(
                tooltip: tr('ক্যালেন্ডার'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
                icon: Icon(Icons.calendar_month_outlined, color: C.ink),
              ),
            ]),
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

  /// The day, its week or its month as a PDF; the page's tab comes chosen.
  Future<void> _pdf(Brain brain, DateTime day) async {
    final now = brain.services.now();
    final ws = _weekStart(day);
    final ranges = <(DiaryView, String, String, List<DateTime>)>[
      (DiaryView.day, tr('এই দিন'), '${weekdayName(day)}, ${bnDigits(day.day)} ${monthName(day.month)}', [dayOnly(day)]),
      (DiaryView.week, tr('এই সপ্তাহ'), '${bnDigits(ws.day)} ${monthShort(ws.month)} – ${bnDigits(ws.add(const Duration(days: 6)).day)} ${monthShort(ws.add(const Duration(days: 6)).month)}',
          [for (var i = 0; i < 7; i++) ws.add(Duration(days: i))]),
      (DiaryView.month, tr('এই মাস'), '${monthName(day.month)} ${bnDigits(day.year)}', [for (var i = 1; i <= DateTime(day.year, day.month + 1, 0).day; i++) DateTime(day.year, day.month, i)]),
    ];
    final pick = await showAppSheet<List<DateTime>>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('দিনলিপি PDF'), style: display(20, weight: 700)),
            const SizedBox(height: 2),
            Text(tr('কাজ, রিমাইন্ডার আর অভ্যাস — বাংলা ও হিজরি তারিখসহ।'), style: body(13, color: C.muted)),
            const SizedBox(height: 12),
            for (final (v, label, sub, days) in ranges)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  key: Key('diary-pdf-${v.name}'),
                  color: v == _view ? C.greenTint : C.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: v == _view ? C.green : C.border)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.pop(ctx, days),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Row(children: [
                        Icon(Icons.picture_as_pdf_outlined, color: C.green),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(label, style: body(15.5, weight: FontWeight.w600)),
                            Text(sub, style: body(12.5, color: C.muted)),
                          ]),
                        ),
                        Icon(Icons.download_rounded, color: C.muted),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
    if (pick == null || !mounted) return;
    final spec = diarySpec(brain.data, pick, now, itemsOn: (d) => itemsOn(brain.data, d, now), userName: brain.userName);
    await exportSpecPdf(context, spec, diaryFileName(pick.first, pick.last));
  }

  /// Habits, medicines, special days and ready lists as three (or four)
  /// cards with what is in each (owner, 22 Nov: "আরো সহজ ভাবে দেখাতে হবে,
  /// ইউআই সুন্দর হতে হবে").
  Widget _moreToKeep() {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final today = dayOnly(now);
    final habits = brain.data.habits;
    final ticked = habits.where((h) => h.doneOn(today)).length;
    final specials = [...brain.data.specialDays]..sort((a, b) => a.next(now).compareTo(b.next(now)));
    final nextSpecial = specials.firstOrNull;
    final ready = listTemplates.where((t) => brain.data.tasks.any((x) => x.list == tr(t.name) && !x.done)).length;

    Widget tile(Key key, String label, IconData icon, Color color, String line, Widget page) => Expanded(
          child: Material(
            key: key,
            color: Color.alphaBlend(color.withValues(alpha: 0.09), C.surface),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: color.withValues(alpha: 0.28))),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
                    child: Icon(icon, size: 21, color: color),
                  ),
                  const SizedBox(height: 10),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14.5, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  SizedBox(height: 34, child: Text(line, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(11.5, color: C.muted, height: 1.4))),
                ]),
              ),
            ),
          ),
        );
    String soon(SpecialDay s) {
      final left = dayOnly(s.next(now)).difference(today).inDays;
      final when = left == 0 ? tr('আজ') : (left == 1 ? tr('কাল') : trf('{0} দিন পর', [bnDigits(left)]));
      return '${specialTitle(s)} · $when';
    }

    final tiles = [
      tile(const Key('diary-habits'), tr('অভ্যাস'), Icons.local_fire_department_outlined, C.orange,
          habits.isEmpty ? tr('ভালো অভ্যাসের তালিকা থেকে বেছে নিন') : trf('আজ {0}/{1} টিক', [bnDigits(ticked), bnDigits(habits.length)]), const HabitsScreen()),
      if (!medicalOff)
        tile(const Key('diary-medicines'), tr('ওষুধ'), Icons.medication_outlined, C.teal, trf('{0}টি ওষুধ', [bnDigits(brain.data.medicines.length)]), const MedicinesScreen()),
      tile(const Key('diary-special'), tr('বিশেষ দিন'), Icons.cake_outlined, C.rose,
          nextSpecial == null ? tr('জন্মদিন, বার্ষিকী — তালিকা থেকে বেছে নিন') : soon(nextSpecial), const SpecialDaysScreen()),
      tile(const Key('diary-templates'), tr('রেডিমেড তালিকা'), Icons.checklist_rtl_rounded, C.blue,
          ready == 0 ? trf('{0}টি তালিকা — দেখে যোগ করুন', [bnDigits(listTemplates.length)]) : trf('{0}টি চালু আছে', [bnDigits(ready)]), const TemplatesScreen()),
    ];
    final rows = <List<Widget>>[for (var i = 0; i < tiles.length; i += tiles.length == 4 ? 2 : 3) tiles.sublist(i, (i + (tiles.length == 4 ? 2 : 3)).clamp(0, tiles.length))];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _label(tr('আরও যা রাখা যায়')),
      for (final (n, r) in rows.indexed) ...[
        if (n > 0) const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final (i, t) in r.indexed) ...[if (i > 0) const SizedBox(width: 8), t],
          ]),
        ),
      ],
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
          _small(trf('যেকোনো সময় · {0}টির {1}টি শেষ', [bnDigits(tasks.length), bnDigits(tasks.where((x) => x.task!.done).length)])),
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
          Text(trf('{0}টি কাজ · {1}টি রিমাইন্ডার', [bnDigits(nTasks), bnDigits(nRem)]), textAlign: TextAlign.center, style: body(12, color: C.muted)),
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
                        Text([if (more > 0) trf('আরও {0}টি', [bnDigits(more)]), if (hol != null) hol.label].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, color: hol != null ? C.rose : C.muted)),
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
