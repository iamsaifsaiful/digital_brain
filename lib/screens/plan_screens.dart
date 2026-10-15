import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/when.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/early_picker.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'alarm_screens.dart';
import 'new_item_screen.dart';
import '../logic/lang.dart';
import '../ui/pdf_export.dart';

/// One line in "আজ" / "কাজ ও রিমাইন্ডার": a task or a reminder's next ring.
class PlanItem {
  PlanItem.task(Task this.task, this.sort) : reminder = null;
  PlanItem.reminder(Reminder this.reminder, this.sort) : task = null;
  final Task? task;
  final Reminder? reminder;

  /// When it is (tasks without a time sort after timed ones of the day).
  final DateTime sort;
  String get title => task?.title ?? reminder!.title;
}

/// What is late, what is today and what is ahead.
class Plan {
  Plan(this.overdue, this.today, this.ahead, this.repeating, this.finished);
  final List<PlanItem> overdue;
  final List<PlanItem> today;
  final List<PlanItem> ahead;
  final List<Reminder> repeating;
  final List<PlanItem> finished;
}

Plan planOf(AppData d, DateTime now) {
  final today = dayOnly(now);
  final overdue = <PlanItem>[], todayL = <PlanItem>[], ahead = <PlanItem>[], finished = <PlanItem>[];
  for (final t in d.tasks) {
    if (t.done) {
      finished.add(PlanItem.task(t, t.doneAt ?? t.createdAt));
      continue;
    }
    final due = t.due == null ? null : dayOnly(t.due!);
    if (due != null && due.isBefore(today)) {
      overdue.add(PlanItem.task(t, due));
    } else if (due == null || due == today) {
      todayL.add(PlanItem.task(t, today.add(const Duration(hours: 23, minutes: 59))));
    } else {
      ahead.add(PlanItem.task(t, due.add(const Duration(hours: 23, minutes: 59))));
    }
  }
  for (final r in d.reminders) {
    if (!r.enabled) continue;
    final at = r.notifyAt(now);
    if (r.repeat == Repeat.none && !at.isAfter(now)) {
      // Rang already: today's stay on "আজ" (greyed), older ones are done.
      if (dayOnly(at) == today) {
        todayL.add(PlanItem.reminder(r, at));
      } else {
        finished.add(PlanItem.reminder(r, at));
      }
      continue;
    }
    if (dayOnly(at) == today) {
      todayL.add(PlanItem.reminder(r, at));
    } else if (!r.repeat.isInterval) {
      ahead.add(PlanItem.reminder(r, at));
    }
  }
  int by(PlanItem a, PlanItem b) => a.sort.compareTo(b.sort);
  overdue.sort(by);
  todayL.sort(by);
  ahead.sort(by);
  finished.sort((a, b) => b.sort.compareTo(a.sort));
  final repeating = d.reminders.where((r) => r.repeat != Repeat.none).toList()..sort((a, b) => a.notifyAt(now).compareTo(b.notifyAt(now)));
  return Plan(overdue, todayL, ahead, repeating, finished);
}

/// "সকাল ১০টা", "প্রতি ঘণ্টায়", "যেকোনো সময়" — the left label of a row.
String whenLabel(PlanItem i, DateTime now, {bool withDay = false}) {
  final r = i.reminder;
  if (r == null) {
    final due = i.task!.due;
    if (due == null) return tr('যেকোনো সময়');
    return withDay ? relativeDay(due, now) : tr('যেকোনো সময়');
  }
  if (r.repeat.isInterval) return r.repeat.label;
  final at = r.notifyAt(now);
  final t = bnTime(at.hour, at.minute);
  return withDay && dayOnly(at) != dayOnly(now) ? '${relativeDay(at, now)}, $t' : t;
}

/// A task (with a tick box) or a reminder (with a bell).
class PlanRow extends StatelessWidget {
  const PlanRow({super.key, required this.item, this.withDay = false, this.trailing});
  final PlanItem item;
  final bool withDay;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final r = item.reminder;
    final t = item.task;
    final passed = r != null && r.repeat == Repeat.none && !r.notifyAt(now).isAfter(now);
    final label = whenLabel(item, now, withDay: withDay);
    return InkWell(
      onTap: () => t != null ? editTask(context, t) : Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewItemScreen(reminder: r))),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
        child: Row(children: [
          if (t != null)
            Checkbox(value: t.done, activeColor: C.green, onChanged: (v) => brain.setTaskDone(t, v ?? false))
          else
            SizedBox(
              width: 48,
              height: 48,
              child: Icon(passed ? Icons.notifications_off_outlined : Icons.notifications_active_outlined, color: passed ? C.muted : C.green, size: 22),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.title,
                    style: body(16,
                        weight: FontWeight.w500,
                        color: (t?.done ?? false) || passed ? C.muted : C.ink),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                Text(passed ? trf('{0} · বেজেছে', [label]) : label, style: body(13, color: r != null && !passed ? C.green : C.muted)),
              ]),
            ),
          ),
          if (trailing != null) trailing! else if (t != null && !t.done) TaskAlarmButton(t),
        ]),
      ),
    );
  }
}

/// The small ⏰ beside a task: set a reminder for it (or open the one set).
class TaskAlarmButton extends StatelessWidget {
  const TaskAlarmButton(this.task, {super.key});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final r = task.reminderId == null ? null : brain.data.reminders.where((x) => x.id == task.reminderId).firstOrNull;
    final now = brain.services.now();
    final due = task.due;
    final at = due == null ? null : DateTime(due.year, due.month, due.day, 9);
    return IconButton(
      tooltip: r == null ? tr('রিমাইন্ডার দিন') : trf('রিমাইন্ডার: {0}', [bnTime(r.hour, r.minute)]),
      visualDensity: VisualDensity.compact,
      icon: Icon(r == null ? Icons.alarm_add_outlined : Icons.alarm_on_rounded, size: 21, color: r == null ? C.muted : C.green),
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => r != null
            ? NewItemScreen(reminder: r)
            : NewItemScreen(category: ItemCategory.reminder, presetTitle: task.title, presetAt: at != null && at.isAfter(now) ? at : null, task: task),
      )),
    );
  }
}

/// Change or delete a task.
Future<void> editTask(BuildContext context, Task t) async {
  final brain = BrainScope.read(context);
  final c = TextEditingController(text: t.title);
  var due = t.due;
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => AlertDialog(
        title: Text(tr('কাজ'), style: display(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: c, minLines: 1, maxLines: 3, decoration: InputDecoration(labelText: tr('কী করতে হবে'))),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text(due == null ? tr('যেকোনো দিন') : fullDate(due!), style: body(15))),
            TextButton(
              onPressed: () async {
                final now = brain.services.now();
                final p = await showDatePicker(context: ctx, initialDate: due ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 5));
                if (p != null) setD(() => due = p);
              },
              child: Text(tr('তারিখ')),
            ),
            if (due != null) IconButton(tooltip: tr('তারিখ মুছুন'), onPressed: () => setD(() => due = null), icon: const Icon(Icons.close_rounded)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: Text(tr('মুছুন'), style: body(15, color: C.red))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
          TextButton(onPressed: () => Navigator.pop(ctx, 'save'), child: Text(tr('সেভ'))),
        ],
      ),
    ),
  );
  if (r == 'delete') {
    await brain.deleteTask(t.id);
    if (context.mounted) toast(context, tr('কাজটা মুছে দিলাম'));
  } else if (r == 'save' && c.text.trim().isNotEmpty) {
    await brain.saveTask(t.copyWith(title: c.text.trim(), due: due, clearDue: due == null));
  }
}

// ───────────────────────── Add (sheet) ─────────────────────────

/// "+ যোগ করুন": a task, or — with the switch on — a reminder that rings
/// like an alarm. Choices are buttons, so most people never type a time.
Future<void> showAddSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _AddSheet(),
  );
  if (saved == true && context.mounted) await checkAlarmsAfterSave(context);
}

enum _Day { today, tomorrow, pick, any }

class _AddSheet extends StatefulWidget {
  const _AddSheet();

  @override
  State<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<_AddSheet> {
  final _title = TextEditingController();
  bool _remind = true;
  _Day _day = _Day.today;
  DateTime? _picked;
  late TimeOfDay _time;
  Repeat _repeat = Repeat.none;
  int _earlyDays = 0;
  int _earlyMinutes = 0;

  static const _presets = [TimeOfDay(hour: 9, minute: 0), TimeOfDay(hour: 11, minute: 0), TimeOfDay(hour: 16, minute: 0), TimeOfDay(hour: 20, minute: 0)];

  @override
  void initState() {
    super.initState();
    final now = BrainScope.read(context).services.now();
    // The first preset still ahead today; otherwise tomorrow morning.
    final next = _presets.where((p) => p.hour > now.hour).toList();
    if (next.isEmpty) {
      _day = _Day.tomorrow;
      _time = _presets.first;
    } else {
      _time = next.first;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  DateTime _dayDate(DateTime now) => switch (_day) {
        _Day.today || _Day.any => dayOnly(now),
        _Day.tomorrow => dayOnly(now).add(const Duration(days: 1)),
        _Day.pick => dayOnly(_picked ?? now),
      };

  DateTime _at(DateTime now) {
    final d = _dayDate(now);
    return DateTime(d.year, d.month, d.day, _time.hour, _time.minute);
  }

  String _summary(DateTime now) {
    if (!_remind) {
      return _day == _Day.any ? tr('কাজের তালিকায় থাকবে, কোনো দিন ঠিক করা নেই') : trf('{0} কাজের তালিকায় থাকবে', [sayWhen(_dayDate(now), now, withTime: false)]);
    }
    final at = _at(now);
    if (_repeat == Repeat.none && !at.isAfter(now)) return tr('এই সময় পার হয়ে গেছে — অন্য সময় বেছে নিন');
    if (_repeat.isInterval) return trf('{0} থেকে {1} বাজবে', [sayWhen(at, now), _repeat.label]);
    if (_repeat != Repeat.none) return trf('{0} {1}-এ বাজবে, প্রথম বার {2}', [_repeat.label, bnTime(at.hour, at.minute), sayWhen(at, now, withTime: false)]);
    return trf('{0}-এ অ্যালার্মের মতো বাজবে', [sayWhen(at, now)]);
  }

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    final now = brain.services.now();
    final title = _title.text.trim();
    if (title.isEmpty) {
      toast(context, tr('কী করতে হবে, লিখুন'));
      return;
    }
    if (!_remind) {
      await brain.saveTask(Task(title: title, due: _day == _Day.any ? null : _dayDate(now)));
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    final at = _at(now);
    if (_repeat == Repeat.none && !at.isAfter(now)) {
      toast(context, tr('এই সময় পার হয়ে গেছে — অন্য সময় বেছে নিন'));
      return;
    }
    await brain.saveReminder(Reminder(
        title: title, date: _dayDate(now), hour: _time.hour, minute: _time.minute, daysBefore: _repeat.isInterval ? 0 : _earlyDays, minutesBefore: _repeat.isInterval ? 0 : _earlyMinutes, repeat: _repeat));
    if (!mounted) return;
    toast(context, trf('রাখা হলো · {0}', [_summary(now)]));
    Navigator.of(context).pop(true);
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => ChoiceChip(
        label: Text(label, style: body(14, color: on ? Colors.white : C.muted2)),
        selected: on,
        selectedColor: C.ink,
        backgroundColor: C.surface,
        side: BorderSide(color: on ? C.ink : C.line),
        onSelected: (_) => onTap(),
      );

  @override
  Widget build(BuildContext context) {
    final now = BrainScope.of(context).services.now();
    final custom = !_presets.contains(_time);
    final past = _remind && _repeat == Repeat.none && !_at(now).isAfter(now);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _title,
            autofocus: true,
            style: body(17),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: tr('কী করতে হবে'), hintText: tr('যেমন: ক্লায়েন্টকে কোটেশন পাঠানো')),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(color: C.soft, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(Icons.notifications_active_outlined, color: C.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('সময়মতো মনে করাবে'), style: body(15, weight: FontWeight.w600)),
                  Text(tr('বন্ধ রাখলে শুধু কাজের তালিকায় থাকবে'), style: body(12, color: C.muted)),
                ]),
              ),
              Switch(
                value: _remind,
                onChanged: (v) => setState(() {
                  _remind = v;
                  if (v && _day == _Day.any) _day = _Day.today;
                }),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Text(tr('কবে'), style: body(13, weight: FontWeight.w600, color: C.muted2)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (!_remind) _chip(tr('যেকোনো দিন'), _day == _Day.any, () => setState(() => _day = _Day.any)),
            _chip(tr('আজ'), _day == _Day.today, () => setState(() => _day = _Day.today)),
            _chip(tr('কাল'), _day == _Day.tomorrow, () => setState(() => _day = _Day.tomorrow)),
            _chip(_day == _Day.pick && _picked != null ? shortDate(_picked!) : tr('তারিখ বেছে নিন'), _day == _Day.pick, () async {
              final p = await showDatePicker(context: context, initialDate: _picked ?? now, firstDate: dayOnly(now), lastDate: DateTime(now.year + 10));
              if (p != null) {
                setState(() {
                  _picked = p;
                  _day = _Day.pick;
                });
              }
            }),
          ]),
          if (_remind) ...[
            const SizedBox(height: 14),
            Text(tr('কখন'), style: body(13, weight: FontWeight.w600, color: C.muted2)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in _presets) _chip(bnTime(p.hour, p.minute), _time == p, () => setState(() => _time = p)),
              _chip(custom ? bnTime(_time.hour, _time.minute) : tr('অন্য সময়'), custom, () async {
                final t = await showTimePicker(context: context, initialTime: _time);
                if (t != null) setState(() => _time = t);
              }),
            ]),
            const SizedBox(height: 14),
            Text(tr('বারবার'), style: body(13, weight: FontWeight.w600, color: C.muted2)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in Repeat.values) _chip(r.label, _repeat == r, () => setState(() => _repeat = r)),
            ]),
            if (!_repeat.isInterval) ...[
              const SizedBox(height: 6),
              // Folded by default so the sheet stays short; opens to the choices.
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 6),
                  title: Text(
                      _earlyDays == 0 && _earlyMinutes == 0
                          ? tr('আগাম মনে করানো: লাগবে না')
                          : trf('আগাম মনে করানো: {0} আগে', [beforeLabel(_earlyMinutes > 0 ? _earlyMinutes : _earlyDays * 1440)]),
                      style: body(13, weight: FontWeight.w600, color: C.muted2)),
                  children: [
                    EarlyPicker(
                days: _earlyDays,
                minutes: _earlyMinutes,
                showDays: _repeat == Repeat.none || _repeat == Repeat.monthly || _repeat == Repeat.yearly,
                onChanged: (d, m) => setState(() {
                  _earlyDays = d;
                  _earlyMinutes = m;
                }),
              ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 18),
          Text(_summary(now), textAlign: TextAlign.center, style: body(13, color: past ? C.orange : C.muted, weight: past ? FontWeight.w600 : FontWeight.w400)),
          const SizedBox(height: 8),
          PrimaryButton(label: tr('রাখুন'), onPressed: _save),
        ]),
      ),
    );
  }
}

// ───────────────────────── All tasks & reminders ─────────────────────────

enum _ListTab { open, repeating, done }

class AllTasksScreen extends StatefulWidget {
  const AllTasksScreen({super.key, this.repeating = false});
  final bool repeating;

  @override
  State<AllTasksScreen> createState() => _AllTasksScreenState();
}

class _AllTasksScreenState extends State<AllTasksScreen> {
  late _ListTab _tab = widget.repeating ? _ListTab.repeating : _ListTab.open;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final plan = planOf(brain.data, now);
    final openCount = plan.overdue.length + plan.today.length + plan.ahead.length;

    Widget section(String title, List<PlanItem> items, {Color? color, bool withDay = false}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(2, 14, 2, 6), child: Text(title, style: body(14, weight: FontWeight.w600, color: color ?? C.muted2))),
            Panel(
              borderColor: color == C.orange ? C.orangeTint : C.line,
              child: Rows(children: [for (final i in items) PlanRow(item: i, withDay: withDay)]),
            ),
          ],
        );

    final List<Widget> body0 = switch (_tab) {
      _ListTab.open => [
          if (openCount == 0)
            EmptyState(icon: Icons.check_circle_outline_rounded, title: tr('কিছু বাকি নেই'), text: tr('নতুন কাজ বা রিমাইন্ডার নিচের বোতাম চেপে, বা মাইকে বলে রাখুন।')),
          if (plan.overdue.isNotEmpty) section(tr('দেরি হয়ে গেছে'), plan.overdue, color: C.orange, withDay: true),
          if (plan.today.isNotEmpty) section(tr('আজ'), plan.today),
          if (plan.ahead.isNotEmpty) section(tr('সামনে'), plan.ahead, withDay: true),
        ],
      _ListTab.repeating => [
          if (plan.repeating.isEmpty)
            EmptyState(
                icon: Icons.repeat_rounded, title: tr('বারবার বাজে এমন কিছু নেই'), text: tr('“প্রতিদিন রাত ১০টায় ওষুধ” বা “প্রতি ৩০ মিনিটে পানি” — এমন রিমাইন্ডার এখানে থাকবে।'))
          else
            Panel(child: Rows(children: [for (final r in plan.repeating) PlanRow(item: PlanItem.reminder(r, r.notifyAt(now)), withDay: true)])),
        ],
      _ListTab.done => [
          if (plan.finished.isEmpty)
            EmptyState(icon: Icons.history_rounded, title: tr('এখনো কিছু শেষ হয়নি'), text: tr('কাজে টিক দিলে বা রিমাইন্ডার বেজে গেলে এখানে আসবে।'))
          else ...[
            // Reminders whose time has gone by, apart from the finished to-dos.
            if (plan.finished.any((i) => i.reminder != null)) section(tr('সময় পার হওয়া রিমাইন্ডার'), [for (final i in plan.finished.where((i) => i.reminder != null).take(60)) i], withDay: true),
            if (plan.finished.any((i) => i.reminder == null)) section(tr('শেষ হওয়া কাজ'), [for (final i in plan.finished.where((i) => i.reminder == null).take(60)) i], withDay: true),
          ],
        ],
    };

    return Scaffold(
      floatingActionButton: AddButton(label: tr('যোগ করুন'), onPressed: () => showAddSheet(context)),
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('কাজ ও রিমাইন্ডার'), trailing: [
            const PdfButton({ReportPart.tasks, ReportPart.reminders}),
            IconButton(tooltip: tr('বিলের রিমাইন্ডার'), onPressed: () => showBillPresets(context), icon: const Icon(Icons.receipt_long_outlined)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: SegTabs<_ListTab>(
              items: [
                (_ListTab.open, trf('বাকি · {0}', [bnDigits(openCount)])),
                (_ListTab.repeating, trf('বারবার · {0}', [bnDigits(plan.repeating.length)])),
                (_ListTab.done, tr('শেষ ও পার হওয়া')),
              ],
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
          ),
          Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 96), children: body0)),
        ]),
      ),
    );
  }
}


// ───────────────────────── Ready-made bill reminders ─────────────────────────

/// Monthly bills most homes in Bangladesh pay, with a usual day of the month.
const billPresets = [
  ('বিদ্যুৎ বিল', 10),
  ('বাসা ভাড়া', 5),
  ('গ্যাস বিল', 10),
  ('পানির বিল', 10),
  ('ইন্টারনেট বিল', 5),
  ('মোবাইল বিল', 1),
  ('কিস্তি', 15),
  ('গ্যাস সিলিন্ডার কেনা', 25),
  ('ডিশ/ক্যাবল বিল', 5),
  ('বাচ্চার স্কুলের বেতন', 10),
];

/// Ticks for the bills the user pays and the day each falls on: a monthly
/// reminder for each (with a note two days before, see the nudges).
Future<void> showBillPresets(BuildContext context) async {
  final brain = BrainScope.read(context);
  final have = {for (final r in brain.data.reminders) r.title};
  final chosen = <String, int>{};
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('মাসের বিলগুলো মনে করাবো'), style: display(19)),
          const SizedBox(height: 4),
          Text(tr('যেগুলো দেন টিক দিন, দিনটা ঠিক করে দিন। প্রতি মাসে সেদিন সকালে বাজবে, দুই দিন আগে একবার জানাবে।'), style: body(13, color: C.muted, height: 1.5)),
          const SizedBox(height: 8),
          for (final (name, day) in billPresets)
            Row(children: [
              Checkbox(
                value: chosen.containsKey(name) || have.contains(name),
                onChanged: have.contains(name) ? null : (v) => setS(() => v == true ? chosen[name] = day : chosen.remove(name)),
              ),
              Expanded(child: Text(tr(name) + (have.contains(name) ? tr(' (রাখা আছে)') : ''), style: body(15.5))),
              if (chosen.containsKey(name))
                DropdownButton<int>(
                  value: chosen[name],
                  items: [for (var d = 1; d <= 28; d++) DropdownMenuItem(value: d, child: Text(trf('{0} তারিখ', [bnDigits(d)])))],
                  onChanged: (v) => setS(() => chosen[name] = v ?? day),
                ),
            ]),
          const SizedBox(height: 10),
          PrimaryButton(label: tr('রাখুন'), icon: Icons.check_rounded, onPressed: chosen.isEmpty ? null : () => Navigator.pop(ctx, true)),
        ]),
      ),
    ),
  );
  if (saved != true) return;
  final now = brain.services.now();
  for (final e in chosen.entries) {
    var date = DateTime(now.year, now.month, e.value);
    if (DateTime(date.year, date.month, date.day, 10).isBefore(now)) date = DateTime(now.year, now.month + 1, e.value);
    await brain.saveReminder(Reminder(title: tr(e.key), date: date, hour: 10, repeat: Repeat.monthly));
  }
  if (context.mounted) toast(context, trf('{0}টা বিলের রিমাইন্ডার রাখা হলো', [bnDigits(chosen.length)]));
}
