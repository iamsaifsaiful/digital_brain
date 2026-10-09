import 'package:flutter/material.dart';

import '../logic/answers.dart';
import '../logic/bn.dart';
import '../logic/when.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// কাজের তালিকা: to-dos said by voice or typed here.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _text = TextEditingController();
  bool _showDone = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final brain = BrainScope.read(context);
    final raw = _text.text.trim();
    if (raw.isEmpty) return;
    final when = parseWhen(raw, brain.services.now());
    var title = when != null && when.hasDay ? tidy(withoutWhen(raw)) : raw;
    if (title.isEmpty) title = raw;
    _text.clear();
    await brain.saveTask(Task(title: title, due: when != null && when.hasDay ? when.day : null));
  }

  Future<void> _edit(Task t) async {
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
              Expanded(child: Text(due == null ? 'তারিখ নেই' : fullDate(due!), style: body(15))),
              TextButton(
                onPressed: () async {
                  final now = brain.services.now();
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: due ?? now,
                    firstDate: DateTime(now.year - 1),
                    lastDate: DateTime(now.year + 5),
                  );
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
      if (mounted) toast(context, 'কাজটা মুছে দিলাম');
    } else if (r == 'save' && c.text.trim().isNotEmpty) {
      await brain.saveTask(t.copyWith(title: c.text.trim(), due: due, clearDue: due == null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final open = openTasksOf(brain.data, now);
    final done = brain.data.tasks.where((t) => t.done).toList()..sort((a, b) => (b.doneAt ?? b.createdAt).compareTo(a.doneAt ?? a.createdAt));

    Widget row(Task t) {
      final overdue = t.due != null && !t.done && dayOnly(t.due!).isBefore(dayOnly(now));
      return ListRow(
        leading: Checkbox(
          value: t.done,
          activeColor: C.green,
          onChanged: (v) => brain.setTaskDone(t, v ?? false),
        ),
        title: t.title,
        subtitle: t.due == null ? null : (overdue ? 'দেরি হয়ে গেছে · ${shortDate(t.due!)}' : sayWhen(t.due!, now, withTime: false)),
        subtitleColor: overdue ? C.orange : C.muted,
        onTap: () => _edit(t),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'কাজের তালিকা'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  if (open.isEmpty && done.isEmpty)
                    const EmptyState(
                      icon: Icons.checklist_rounded,
                      title: 'কোনো কাজ নেই',
                      text: 'বলুন “কাল ব্যাংকে যেতে হবে” বা “বাজারের লিস্টে ডিম রাখো”, অথবা নিচে লিখে যোগ করুন।',
                    )
                  else ...[
                    Text(open.isEmpty ? 'সব কাজ শেষ!' : '${bnDigits(open.length)}টা কাজ বাকি', style: body(14, color: C.muted)),
                    const SizedBox(height: 8),
                    if (open.isNotEmpty) Panel(child: Rows(children: [for (final t in open) row(t)])),
                    if (done.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => setState(() => _showDone = !_showDone),
                        icon: Icon(_showDone ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                        label: Text('শেষ হয়েছে (${bnDigits(done.length)})'),
                      ),
                      if (_showDone) Panel(child: Rows(children: [for (final t in done.take(50)) row(t)])),
                    ],
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(hintText: 'নতুন কাজ, যেমন: কাল ব্যাংকে যেতে হবে'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'যোগ করুন',
                  style: IconButton.styleFrom(backgroundColor: C.green, minimumSize: const Size(52, 52)),
                  onPressed: _add,
                  icon: const Icon(Icons.add_rounded, color: Colors.white),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
