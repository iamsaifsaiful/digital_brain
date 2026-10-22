import 'package:flutter/material.dart';

import '../logic/answers.dart';
import '../logic/bn.dart';
import '../logic/when.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'onboarding_screen.dart';
import 'plan_screens.dart' show TaskAlarmButton;
import '../logic/lang.dart';
import '../ui/pdf_export.dart';
import '../ui/pick.dart';

/// কাজের তালিকা: to-dos said by voice or typed here.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _text = TextEditingController();
  final _picks = Picks();
  bool _showDone = false;

  @override
  void initState() {
    super.initState();
    _picks.addListener(() => setState(() {}));
  }

  /// The list shown ('' = the main to-do list, null = all).
  String? _list;

  @override
  void dispose() {
    _text.dispose();
    _picks.dispose();
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

  List<Task> _picked(Brain brain) => [
        for (final t in brain.data.tasks)
          if (_picks.has(t.id)) t
      ];

  List<PickAction> _actions(Brain brain) {
    final picked = _picked(brain);
    final anyOpen = picked.any((t) => !t.done);
    return [
      if (anyOpen)
        PickAction(Icons.check_rounded, tr('শেষ'), () async {
          for (final t in picked.where((t) => !t.done)) {
            await brain.setTaskDone(t, true);
          }
          _picks.clear();
        })
      else
        PickAction(Icons.undo_rounded, tr('আবার খুলুন'), () async {
          for (final t in picked) {
            await brain.setTaskDone(t, false);
          }
          _picks.clear();
        }),
      PickAction(Icons.event_rounded, tr('তারিখ'), () async {
        final now = brain.services.now();
        final d = await showDatePicker(context: context, initialDate: now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 5));
        if (d == null) return;
        for (final t in picked) {
          await brain.saveTask(t.copyWith(due: d));
        }
        _picks.clear();
      }),
      PickAction(Icons.drive_file_move_outline, tr('তালিকায় সরান'), () async {
        final name = await _askList(brain);
        if (name == null) return;
        for (final t in picked) {
          await brain.saveTask(t.copyWith(list: name));
        }
        _picks.clear();
      }),
      PickAction(Icons.share_outlined, tr('পাঠান'), () async {
        await brain.services.files.shareText(picked.map((t) => '${t.done ? '☑' : '☐'} ${t.title}').join('\n'));
      }),
      PickAction(Icons.delete_outline_rounded, tr('মুছুন'), danger: true, () async {
        final messenger = ScaffoldMessenger.of(context);
        if (!await confirmDialog(context, title: trf('{0}টা কাজ মুছবেন?', [bnDigits(picked.length)]), text: tr('৩০ দিন “মুছে ফেলা”-তে থাকবে।'), yes: tr('মুছুন'), danger: true)) return;
        for (final t in picked) {
          await brain.deleteTask(t.id);
        }
        _picks.clear();
        deletedSnack(messenger, picked.length, () => brain.undoLastDeletes(picked.length));
      }),
    ];
  }

  /// Which list to move picked to-dos to ('' = the main list).
  Future<String?> _askList(Brain brain) {
    final lists = {
      for (final t in brain.data.tasks)
        if (t.list.isNotEmpty) t.list
    }.toList()
      ..sort();
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('কোন তালিকায়?'), style: display(20)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            ActionChip(label: Text(tr('মূল তালিকা')), onPressed: () => Navigator.pop(ctx, '')),
            for (final l in lists) ActionChip(label: Text(l), onPressed: () => Navigator.pop(ctx, l)),
          ]),
          const SizedBox(height: 10),
          TextField(controller: c, decoration: InputDecoration(labelText: tr('নতুন তালিকার নাম'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? null : c.text.trim()), child: Text(tr('ঠিক আছে'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    final lists = {
      for (final t in brain.data.tasks)
        if (t.list.isNotEmpty) t.list
    }.toList()
      ..sort();
    if (_list != null && _list!.isNotEmpty && !lists.contains(_list)) _list = null;
    bool inList(Task t) => _list == null || t.list == _list;
    final open = openTasksOf(brain.data, now).where(inList).toList();
    final done = brain.data.tasks.where((t) => t.done && inList(t)).toList()..sort((a, b) => (b.doneAt ?? b.createdAt).compareTo(a.doneAt ?? a.createdAt));

    final shown = [...open, if (_showDone) ...done.take(50)];
    _picks.keepOnly(brain.data.tasks.map((t) => t.id));

    Widget row(Task t) {
      final overdue = t.lateAt(now) || t.windowPassed(now);
      final picking = _picks.on;
      return ListRow(
        key: Key('task-${t.id}'),
        picked: _picks.has(t.id),
        onLongPress: () => _picks.toggle(t.id),
        leading: picking
            ? PickMark(_picks.has(t.id))
            : Checkbox(
                value: t.done,
                activeColor: C.green,
                onChanged: (v) => brain.setTaskDone(t, v ?? false),
              ),
        title: t.title,
        subtitle: t.due == null && t.repeat == null && !t.urgent && t.note.isEmpty ? (_list == null && t.list.isNotEmpty ? t.list : null) : taskWhenText(t, now),
        subtitleColor: overdue ? C.orange : C.muted,
        trailing: t.done || picking ? null : TaskAlarmButton(t),
        onTap: picking ? () => _picks.toggle(t.id) : () => _edit(t),
      );
    }

    return PopScope(
      canPop: !_picks.on,
      onPopInvokedWithResult: (did, _) {
        if (!did) _picks.clear();
      },
      child: Scaffold(
        bottomNavigationBar: _picks.on ? PickBar(picks: _picks, all: shown.map((t) => t.id), actions: _actions(brain)) : null,
        body: SafeArea(
          child: Column(
            children: [
              TopBar(title: tr('কাজের তালিকা'), trailing: [
                const PdfButton({ReportPart.tasks}),
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
                      if (!_picks.on && open.length > 1) Text(tr('চেপে ধরে কয়েকটা বেছে একসাথে শেষ, সরানো বা মুছা যায়'), style: body(12, color: C.muted)),
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
              if (!_picks.on)
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
      ),
    );
  }
}
