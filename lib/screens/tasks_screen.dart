import 'package:flutter/material.dart';

import '../logic/answers.dart';
import '../logic/bn.dart';
import '../logic/when.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'onboarding_screen.dart';
import '../logic/lang.dart';

/// কাজের তালিকা: to-dos said by voice or typed here.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _text = TextEditingController();
  bool _showDone = false;

  /// The list shown ('' = the main to-do list, null = all).
  String? _list;

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
    await brain.saveTask(Task(title: title, due: when != null && when.hasDay ? when.day : null, list: _list ?? ''));
  }

  Future<void> _edit(Task t) async {
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
              Expanded(child: Text(due == null ? tr('তারিখ নেই') : fullDate(due!), style: body(15))),
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
      if (mounted) toast(context, tr('কাজটা মুছে দিলাম'));
    } else if (r == 'save' && c.text.trim().isNotEmpty) {
      await brain.saveTask(t.copyWith(title: c.text.trim(), due: due, clearDue: due == null));
    }
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final lists = {for (final t in brain.data.tasks) if (t.list.isNotEmpty) t.list}.toList()..sort();
    if (_list != null && _list!.isNotEmpty && !lists.contains(_list)) _list = null;
    bool inList(Task t) => _list == null || t.list == _list;
    final open = openTasksOf(brain.data, now).where(inList).toList();
    final done = brain.data.tasks.where((t) => t.done && inList(t)).toList()..sort((a, b) => (b.doneAt ?? b.createdAt).compareTo(a.doneAt ?? a.createdAt));

    Widget row(Task t) {
      final overdue = t.due != null && !t.done && dayOnly(t.due!).isBefore(dayOnly(now));
      return ListRow(
        leading: Checkbox(
          value: t.done,
          activeColor: C.green,
          onChanged: (v) => brain.setTaskDone(t, v ?? false),
        ),
        title: t.title,
        subtitle: t.due == null ? (_list == null && t.list.isNotEmpty ? t.list : null) : (overdue ? trf('দেরি হয়ে গেছে · {0}', [shortDate(t.due!)]) : sayWhen(t.due!, now, withTime: false)),
        subtitleColor: overdue ? C.orange : C.muted,
        onTap: () => _edit(t),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: tr('কাজের তালিকা'), trailing: [
              IconButton(
                tooltip: tr('তৈরি তালিকা'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TemplatesScreen())),
                icon: const Icon(Icons.playlist_add_rounded),
              ),
            ]),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  if (lists.isNotEmpty) ...[
                    SizedBox(
                      height: 40,
                      child: ListView(scrollDirection: Axis.horizontal, children: [
                        for (final (key, label) in [(null, tr('সব')), ('', tr('মূল তালিকা')), for (final l in lists) (l, l)])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(label),
                              selected: _list == key,
                              onSelected: (_) => setState(() => _list = key),
                            ),
                          ),
                      ]),
                    ),
                    if (_list != null && _list!.isNotEmpty)
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        // Send the list to someone (WhatsApp, SMS…) — e.g. the shopping list to the family.
                        TextButton.icon(
                          onPressed: () {
                            final name = _list!;
                            final items = brain.data.tasks.where((t) => t.list == name).toList();
                            final text = '$name\n${items.map((t) => '${t.done ? '☑' : '☐'} ${t.title}').join('\n')}';
                            brain.services.files.shareText(text);
                          },
                          icon: Icon(Icons.share_outlined, size: 18, color: C.green),
                          label: Text(tr('তালিকা পাঠান'), style: body(13, color: C.green)),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final name = _list!;
                            if (!await confirmDialog(context, title: tr('তালিকা মুছবেন?'), text: trf('‘{0}’-এর সব জিনিস মুছে যাবে।', [name]), yes: tr('মুছুন'), danger: true)) return;
                            for (final t in [...brain.data.tasks.where((t) => t.list == name)]) {
                              await brain.deleteTask(t.id);
                            }
                            setState(() => _list = null);
                          },
                          icon: Icon(Icons.delete_outline_rounded, size: 18, color: C.red),
                          label: Text(tr('তালিকা মুছুন'), style: body(13, color: C.red)),
                        ),
                      ]),
                    const SizedBox(height: 8),
                  ],
                  if (open.isEmpty && done.isEmpty)
                    EmptyState(
                      icon: Icons.checklist_rounded,
                      title: tr('কোনো কাজ নেই'),
                      text: tr('বলুন “কাল ব্যাংকে যেতে হবে” বা “বাজারের লিস্টে ডিম রাখো”, অথবা নিচে লিখে যোগ করুন।'),
                    )
                  else ...[
                    Text(open.isEmpty ? tr('সব কাজ শেষ!') : trf('{0}টা কাজ বাকি', [bnDigits(open.length)]), style: body(14, color: C.muted)),
                    const SizedBox(height: 8),
                    if (open.isNotEmpty) Panel(child: Rows(children: [for (final t in open) row(t)])),
                    if (done.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: () => setState(() => _showDone = !_showDone),
                        icon: Icon(_showDone ? Icons.expand_less_rounded : Icons.expand_more_rounded),
                        label: Text(trf('শেষ হয়েছে ({0})', [bnDigits(done.length)])),
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
                    decoration: InputDecoration(hintText: tr('নতুন কাজ, যেমন: কাল ব্যাংকে যেতে হবে')),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: tr('যোগ করুন'),
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
