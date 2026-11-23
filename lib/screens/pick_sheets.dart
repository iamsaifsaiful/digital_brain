/// Picking from ready lists (owner, 22 Nov): "অভ্যাসে ক্লিক করলে দৈনন্দিন
/// জীবনে ভালো অভ্যাসের তালিকা দেখাবে", special days the same way, and a
/// ready list shown before it is added, to take items out or put more in.
library;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/pick_lists.dart';
import '../logic/templates.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'onboarding_screen.dart' show templateIcon;
import 'special_days_screen.dart' show editSpecialDay;

// ───────────────────────── Habits ─────────────────────────

IconData _groupIcon(String key) => switch (key) {
      'body' => Icons.directions_walk_rounded,
      'mind' => Icons.menu_book_outlined,
      'faith' => Icons.mosque_outlined,
      _ => Icons.home_outlined,
    };

Color _groupColor(String key) => switch (key) {
      'body' => C.green,
      'mind' => C.blue,
      'faith' => C.teal,
      _ => C.ochre,
    };

/// The good habits to tick, a line for one's own, and one button to add them.
Future<void> showHabitPicker(BuildContext context) => showAppSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const _HabitPicker(),
    );

class _HabitPicker extends StatefulWidget {
  const _HabitPicker();
  @override
  State<_HabitPicker> createState() => _HabitPickerState();
}

class _HabitPickerState extends State<_HabitPicker> {
  final _picked = <String>{};
  final _own = TextEditingController();

  @override
  void dispose() {
    _own.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final brain = BrainScope.read(context);
    final own = _own.text.trim();
    final names = [..._picked.map(tr), if (own.isNotEmpty) own];
    if (names.isEmpty) return;
    for (final n in names) {
      await brain.saveHabit(Habit(name: n, createdAt: brain.services.now()));
    }
    if (!mounted) return;
    Navigator.pop(context);
    toast(context, names.length == 1 ? trf('“{0}” অভ্যাসে যোগ হলো', [names.first]) : trf('{0}টি অভ্যাস যোগ হলো', [bnDigits(names.length)]));
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final have = {for (final h in brain.data.habits) h.name.trim()};
    final religion = brain.text('religion');
    final groups = [
      for (final g in habitGroups)
        if (g.icon != 'faith' || religion.isEmpty || religion == 'islam')
          g
        else if (religion != 'none')
          (name: 'ধর্মচর্চা', icon: 'faith', items: otherFaithHabits),
    ];
    final n = _picked.length + (_own.text.trim().isEmpty ? 0 : 1);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('ভালো অভ্যাস বেছে নিন'), style: display(20, weight: 700)),
            const SizedBox(height: 2),
            Text(tr('যেগুলো রোজ করতে চান, চাপ দিন — প্রতিদিন টিক দেবেন, টানা কত দিন হলো দেখাবে।'), style: body(13, color: C.muted, height: 1.45)),
          ]),
        ),
        Flexible(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 8, 20, 8), children: [
            for (final g in groups) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Row(children: [
                  Icon(_groupIcon(g.icon), size: 18, color: _groupColor(g.icon)),
                  const SizedBox(width: 6),
                  Text(tr(g.name), style: body(14, weight: FontWeight.w700, color: C.muted2)),
                ]),
              ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final h in g.items)
                  _PickChip(
                    key: Key('habit-idea-$h'),
                    label: tr(h),
                    on: _picked.contains(h),
                    done: have.contains(tr(h)),
                    color: _groupColor(g.icon),
                    onTap: () => setState(() => _picked.contains(h) ? _picked.remove(h) : _picked.add(h)),
                  ),
              ]),
            ],
            const SizedBox(height: 16),
            TextField(
              key: const Key('habit-own'),
              controller: _own,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: tr('নিজের অভ্যাস (চাইলে)'), hintText: tr('যেমন: রোজ সকালে ইংরেজি শব্দ শেখা'), prefixIcon: const Icon(Icons.edit_outlined)),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
          child: PrimaryButton(
            key: const Key('habit-add-picked'),
            label: n == 0 ? tr('বেছে নিন') : trf('{0}টি অভ্যাস যোগ করুন', [bnDigits(n)]),
            icon: Icons.check_rounded,
            onPressed: n == 0 ? null : _add,
          ),
        ),
      ]),
    );
  }
}

/// A choice that can be ticked; one already kept shows ✓ and cannot be.
class _PickChip extends StatelessWidget {
  const _PickChip({super.key, required this.label, required this.on, required this.onTap, this.done = false, required this.color});
  final String label;
  final bool on;
  final bool done;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lit = on || done;
    return Material(
      color: lit ? Color.alphaBlend(color.withValues(alpha: 0.13), C.surface) : C.surface,
      shape: StadiumBorder(side: BorderSide(color: lit ? color : C.border, width: on ? 1.6 : 1)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: done ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(done ? Icons.check_circle_rounded : (on ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded), size: 18, color: lit ? color : C.muted),
            const SizedBox(width: 6),
            Flexible(child: Text(done ? trf('{0} · আছে', [label]) : label, style: body(14, weight: on ? FontWeight.w600 : FontWeight.w400, color: done ? C.muted : C.ink))),
          ]),
        ),
      ),
    );
  }
}

// ───────────────────────── Special days ─────────────────────────

/// Whose day to keep: the family's (the date asked next), or a day of the year (kept at once).
Future<void> showSpecialPicker(BuildContext context) async {
  final idea = await showAppSheet<SpecialIdea?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const _SpecialPicker(),
  );
  if (idea == null || !context.mounted) return;
  await editSpecialDay(context, null, idea: idea);
}

class _SpecialPicker extends StatelessWidget {
  const _SpecialPicker();

  IconData _icon(SpecialKind k) => switch (k) {
        SpecialKind.birthday => Icons.cake_outlined,
        SpecialKind.anniversary => Icons.favorite_border_rounded,
        SpecialKind.deathday => Icons.local_florist_outlined,
        SpecialKind.other => Icons.star_border_rounded,
      };

  Color _color(SpecialKind k) => switch (k) {
        SpecialKind.birthday => C.rose,
        SpecialKind.anniversary => C.purple,
        SpecialKind.deathday => C.teal,
        SpecialKind.other => C.ochre,
      };

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    bool kept(YearDay d) => brain.data.specialDays.any((s) => s.month == d.month && s.day == d.day && (s.person == d.name || s.person == tr(d.name)));
    Widget card(Widget child) => Container(
          decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
          clipBehavior: Clip.antiAlias,
          child: child,
        );
    return ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
      Text(tr('কোন দিনটা রাখবেন?'), style: display(20, weight: 700)),
      const SizedBox(height: 2),
      Text(tr('বেছে নিন — তারপর শুধু তারিখ দিলেই হবে। প্রতি বছর আগের দিন আর সেদিন মনে করাব।'), style: body(13, color: C.muted, height: 1.45)),
      const SizedBox(height: 14),
      Text(tr('পরিবার ও কাছের মানুষ'), style: body(14, weight: FontWeight.w700, color: C.muted2)),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.9,
        children: [
          for (final i in familyDayIdeas)
            Material(
              key: Key('special-idea-${i.label}'),
              color: Color.alphaBlend(_color(i.kind).withValues(alpha: 0.10), C.surface),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _color(i.kind).withValues(alpha: 0.35))),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.pop(context, i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(children: [
                    Icon(_icon(i.kind), size: 20, color: _color(i.kind)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tr(i.label), maxLines: 2, overflow: TextOverflow.ellipsis, style: body(13.5, weight: FontWeight.w600, height: 1.25))),
                  ]),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('special-own'),
        onPressed: () => Navigator.pop(context, (kind: SpecialKind.other, person: '', label: '')),
        icon: const Icon(Icons.edit_outlined),
        label: Text(tr('অন্য কোনো দিন — নিজে লিখুন')),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), foregroundColor: C.ink),
      ),
      const SizedBox(height: 18),
      Text(tr('বছরের বিশেষ দিনগুলো'), style: body(14, weight: FontWeight.w700, color: C.muted2)),
      const SizedBox(height: 8),
      card(Column(children: [
        for (final (n, d) in yearDayIdeas.indexed) ...[
          if (n > 0) Divider(height: 1, indent: 14, endIndent: 14, color: C.border),
          ListTile(
            key: Key('year-day-${d.month}-${d.day}'),
            leading: Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(11)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(bnDigits(d.day), style: display(15, weight: 700, color: C.green, height: 1.05)),
                Text(monthShort(d.month), style: body(9.5, weight: FontWeight.w600, color: C.green, height: 1.1)),
              ]),
            ),
            title: Text(tr(d.name), style: body(14.5, weight: FontWeight.w600)),
            trailing: kept(d)
                ? Pill(tr('রাখা আছে'))
                : IconButton(
                    tooltip: tr('রাখুন'),
                    icon: Icon(Icons.add_circle_rounded, color: C.green, size: 28),
                    onPressed: () async {
                      await brain.saveSpecialDay(SpecialDay(person: tr(d.name), kind: SpecialKind.other, month: d.month, day: d.day, daysBefore: 0));
                      if (context.mounted) toast(context, trf('“{0}” রাখা হলো', [tr(d.name)]));
                    },
                  ),
          ),
        ],
      ])),
    ]);
  }
}

// ───────────────────────── Ready lists ─────────────────────────

/// A ready list before it is added: its name, every item ticked (untick to
/// leave out), a line to add more (owner, 22 Nov).
class TemplatePreviewScreen extends StatefulWidget {
  const TemplatePreviewScreen({super.key, required this.template});
  final ListTemplate template;

  @override
  State<TemplatePreviewScreen> createState() => _TemplatePreviewScreenState();
}

class _TemplatePreviewScreenState extends State<TemplatePreviewScreen> {
  late final _name = TextEditingController(text: tr(widget.template.name));
  late final List<(bool, String)> _items = [for (final i in widget.template.items) (true, tr(i))];
  final _more = TextEditingController();
  final _moreFocus = FocusNode();

  @override
  void dispose() {
    _name.dispose();
    _more.dispose();
    _moreFocus.dispose();
    super.dispose();
  }

  void _addMore() {
    final t = _more.text.trim();
    if (t.isEmpty) return;
    setState(() => _items.add((true, t)));
    _more.clear();
    _moreFocus.requestFocus();
  }

  Future<void> _save() async {
    final brain = BrainScope.read(context);
    final name = _name.text.trim().isEmpty ? tr(widget.template.name) : _name.text.trim();
    final keep = [for (final (on, t) in _items) if (on) t];
    if (keep.isEmpty) return;
    await brain.addList(name, keep);
    if (!mounted) return;
    toast(context, trf('‘{0}’ কাজের তালিকায় যোগ হলো — {1}টি কাজ', [name, bnDigits(keep.length)]));
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final n = _items.where((x) => x.$1).length;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('তালিকা দেখে নিন')),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), children: [
              TextField(
                key: const Key('tpl-name'),
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                style: body(18, weight: FontWeight.w700),
                decoration: InputDecoration(labelText: tr('তালিকার নাম'), prefixIcon: Icon(templateIcon(widget.template.name), color: C.green)),
              ),
              const SizedBox(height: 10),
              Text(tr('যা লাগবে না, টিক তুলে দিন বা পাশের কাটা চিহ্নে চাপুন। নিচে নিজের জিনিস যোগ করুন।'), style: body(13, color: C.muted, height: 1.45)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (final (i, (on, t)) in _items.indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 52, color: C.border),
                    InkWell(
                      key: Key('tpl-item-$i'),
                      onTap: () => setState(() => _items[i] = (!on, t)),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 2, 4, 2),
                        child: Row(children: [
                          Checkbox(value: on, onChanged: (v) => setState(() => _items[i] = (v ?? false, t))),
                          Expanded(
                            child: Text(t,
                                style: body(15, color: on ? C.ink : C.muted).copyWith(decoration: on ? null : TextDecoration.lineThrough, decorationColor: C.muted)),
                          ),
                          IconButton(
                            tooltip: tr('বাদ দিন'),
                            onPressed: () => setState(() => _items.removeAt(i)),
                            icon: Icon(Icons.close_rounded, size: 19, color: C.muted),
                          ),
                        ]),
                      ),
                    ),
                  ],
                  Divider(height: 1, color: C.border),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
                    child: Row(children: [
                      Icon(Icons.add_rounded, color: C.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const Key('tpl-more'),
                          controller: _more,
                          focusNode: _moreFocus,
                          textCapitalization: TextCapitalization.sentences,
                          onSubmitted: (_) => _addMore(),
                          decoration: InputDecoration(hintText: tr('আরও কিছু যোগ করুন'), border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none, filled: false),
                        ),
                      ),
                      TextButton(key: const Key('tpl-more-add'), onPressed: _addMore, child: Text(tr('যোগ'))),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: PrimaryButton(
              key: const Key('tpl-save'),
              label: n == 0 ? tr('অন্তত একটা রাখুন') : trf('{0}টি কাজ তালিকায় যোগ করুন', [bnDigits(n)]),
              icon: Icons.playlist_add_check_rounded,
              onPressed: n == 0 ? null : _save,
            ),
          ),
        ]),
      ),
    );
  }
}
