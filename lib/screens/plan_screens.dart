import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/when.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'alarm_screens.dart';
import 'new_item_screen.dart';

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
    if (due == null) return 'যেকোনো সময়';
    return withDay ? relativeDay(due, now) : 'যেকোনো সময়';
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
                Text(passed ? '$label · বেজেছে' : label, style: body(13, color: r != null && !passed ? C.green : C.muted)),
              ]),
            ),
          ),
          if (trailing != null) trailing!,
        ]),
      ),
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
        title: Text('কাজ', style: display(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: c, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'কী করতে হবে')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text(due == null ? 'যেকোনো দিন' : fullDate(due!), style: body(15))),
            TextButton(
              onPressed: () async {
                final now = brain.services.now();
                final p = await showDatePicker(context: ctx, initialDate: due ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 5));
                if (p != null) setD(() => due = p);
              },
              child: const Text('তারিখ'),
            ),
            if (due != null) IconButton(tooltip: 'তারিখ মুছুন', onPressed: () => setD(() => due = null), icon: const Icon(Icons.close_rounded)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: Text('মুছুন', style: body(15, color: C.red))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('সেভ')),
        ],
      ),
    ),
  );
  if (r == 'delete') {
    await brain.deleteTask(t.id);
    if (context.mounted) toast(context, 'কাজটা মুছে দিলাম');
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
      return _day == _Day.any ? 'কাজের তালিকায় থাকবে, কোনো দিন ঠিক করা নেই' : '${sayWhen(_dayDate(now), now, withTime: false)} কাজের তালিকায় থাকবে';
    }
    final at = _at(now);
    if (_repeat == Repeat.none && !at.isAfter(now)) return 'এই সময় পার হয়ে গেছে — অন্য সময় বেছে নিন';
    if (_repeat.isInterval) return '${sayWhen(at, now)} থেকে ${_repeat.label} বাজবে';
    if (_repeat != Repeat.none) return '${_repeat.label} ${bnTime(at.hour, at.minute)}-এ বাজবে, প্রথম বার ${sayWhen(at, now, withTime: false)}';
    return '${sayWhen(at, now)}-এ অ্যালার্মের মতো বাজবে';
  }

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    final now = brain.services.now();
    final title = _title.text.trim();
    if (title.isEmpty) {
      toast(context, 'কী করতে হবে, লিখুন');
      return;
    }
    if (!_remind) {
      await brain.saveTask(Task(title: title, due: _day == _Day.any ? null : _dayDate(now)));
      if (mounted) Navigator.of(context).pop(false);
      return;
    }
    final at = _at(now);
    if (_repeat == Repeat.none && !at.isAfter(now)) {
      toast(context, 'এই সময় পার হয়ে গেছে — অন্য সময় বেছে নিন');
      return;
    }
    await brain.saveReminder(Reminder(title: title, date: _dayDate(now), hour: _time.hour, minute: _time.minute, daysBefore: 0, repeat: _repeat));
    if (!mounted) return;
    toast(context, 'রাখা হলো · ${_summary(now)}');
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
            decoration: const InputDecoration(labelText: 'কী করতে হবে', hintText: 'যেমন: ক্লায়েন্টকে কোটেশন পাঠানো'),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.notifications_active_outlined, color: C.green),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('সময়মতো মনে করাবে', style: body(15, weight: FontWeight.w600)),
                  Text('বন্ধ রাখলে শুধু কাজের তালিকায় থাকবে', style: body(12, color: C.muted)),
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
          Text('কবে', style: body(13, weight: FontWeight.w600, color: C.muted2)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (!_remind) _chip('যেকোনো দিন', _day == _Day.any, () => setState(() => _day = _Day.any)),
            _chip('আজ', _day == _Day.today, () => setState(() => _day = _Day.today)),
            _chip('কাল', _day == _Day.tomorrow, () => setState(() => _day = _Day.tomorrow)),
            _chip(_day == _Day.pick && _picked != null ? shortDate(_picked!) : 'তারিখ বেছে নিন', _day == _Day.pick, () async {
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
            Text('কখন', style: body(13, weight: FontWeight.w600, color: C.muted2)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final p in _presets) _chip(bnTime(p.hour, p.minute), _time == p, () => setState(() => _time = p)),
              _chip(custom ? bnTime(_time.hour, _time.minute) : 'অন্য সময়', custom, () async {
                final t = await showTimePicker(context: context, initialTime: _time);
                if (t != null) setState(() => _time = t);
              }),
            ]),
            const SizedBox(height: 14),
            Text('বারবার', style: body(13, weight: FontWeight.w600, color: C.muted2)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final r in Repeat.values) _chip(r.label, _repeat == r, () => setState(() => _repeat = r)),
            ]),
          ],
          const SizedBox(height: 18),
          Text(_summary(now), textAlign: TextAlign.center, style: body(13, color: past ? C.orange : C.muted, weight: past ? FontWeight.w600 : FontWeight.w400)),
          const SizedBox(height: 8),
          PrimaryButton(label: 'রাখুন', onPressed: _save),
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

    Widget section(String title, List<PlanItem> items, {Color color = C.muted2, bool withDay = false}) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: const EdgeInsets.fromLTRB(2, 14, 2, 6), child: Text(title, style: body(14, weight: FontWeight.w600, color: color))),
            Panel(
              borderColor: color == C.orange ? const Color(0xFFF3D9C2) : C.line,
              child: Rows(children: [for (final i in items) PlanRow(item: i, withDay: withDay)]),
            ),
          ],
        );

    final List<Widget> body0 = switch (_tab) {
      _ListTab.open => [
          if (openCount == 0)
            const EmptyState(icon: Icons.check_circle_outline_rounded, title: 'কিছু বাকি নেই', text: 'নতুন কাজ বা রিমাইন্ডার নিচের বোতাম চেপে, বা মাইকে বলে রাখুন।'),
          if (plan.overdue.isNotEmpty) section('দেরি হয়ে গেছে', plan.overdue, color: C.orange, withDay: true),
          if (plan.today.isNotEmpty) section('আজ', plan.today),
          if (plan.ahead.isNotEmpty) section('সামনে', plan.ahead, withDay: true),
        ],
      _ListTab.repeating => [
          if (plan.repeating.isEmpty)
            const EmptyState(
                icon: Icons.repeat_rounded, title: 'বারবার বাজে এমন কিছু নেই', text: '“প্রতিদিন রাত ১০টায় ওষুধ” বা “প্রতি ৩০ মিনিটে পানি” — এমন রিমাইন্ডার এখানে থাকবে।')
          else
            Panel(child: Rows(children: [for (final r in plan.repeating) PlanRow(item: PlanItem.reminder(r, r.notifyAt(now)), withDay: true)])),
        ],
      _ListTab.done => [
          if (plan.finished.isEmpty)
            const EmptyState(icon: Icons.history_rounded, title: 'এখনো কিছু শেষ হয়নি', text: 'কাজে টিক দিলে বা রিমাইন্ডার বেজে গেলে এখানে আসবে।')
          else
            Panel(child: Rows(children: [for (final i in plan.finished.take(60)) PlanRow(item: i, withDay: true)])),
        ],
    };

    return Scaffold(
      floatingActionButton: AddButton(label: 'যোগ করুন', onPressed: () => showAddSheet(context)),
      body: SafeArea(
        child: Column(children: [
          const TopBar(title: 'কাজ ও রিমাইন্ডার'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: SegTabs<_ListTab>(
              items: [
                (_ListTab.open, 'বাকি · ${bnDigits(openCount)}'),
                (_ListTab.repeating, 'বারবার · ${bnDigits(plan.repeating.length)}'),
                (_ListTab.done, 'শেষ'),
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
