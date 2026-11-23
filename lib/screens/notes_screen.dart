import 'will_screen.dart';
import '../logic/app_stats.dart';
import 'package:flutter/material.dart';

import '../ui/pro_gate.dart';

import '../logic/bn.dart';
import '../logic/parser.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/note_parts.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'new_item_screen.dart';
import '../logic/lang.dart';
import '../ui/pdf_export.dart';
import '../ui/pick.dart';
import '../ui/forms.dart' show askText;

/// Notes and everything else remembered, by category ("নোট", "যানবাহন"…).
/// Owner, 22 Nov: the first page shows the categories as tiles (পারিবারিক,
/// ব্যবসা, অনুষ্ঠান…); a tile opens that category's notes.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key, this.category});

  /// Category to open on; null shows all.
  final String? category;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _q = '';
  late String? _cat = widget.category;
  final _picks = Picks();

  @override
  void initState() {
    super.initState();
    _picks.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _picks.dispose();
    super.dispose();
  }

  List<PickAction> _actions(Brain brain) {
    final picked = [
      for (final n in brain.data.notes)
        if (_picks.has(n.id)) n
    ];
    return [
      PickAction(Icons.folder_outlined, tr('বিভাগ বদলান'), () async {
        final cats = brain.noteCats;
        final c = TextEditingController();
        final cat = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tr('কোন বিভাগে?'), style: display(20)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 6, runSpacing: 6, children: [for (final k in cats) ActionChip(label: Text(tr(k)), onPressed: () => Navigator.pop(ctx, k))]),
                const SizedBox(height: 10),
                TextField(textCapitalization: TextCapitalization.sentences, controller: c, decoration: InputDecoration(labelText: tr('নতুন বিভাগ'))),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
              TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? null : c.text.trim()), child: Text(tr('ঠিক আছে'))),
            ],
          ),
        );
        if (cat == null) return;
        for (final n in picked) {
          await brain.saveNote(Note(id: n.id, title: n.title, body: n.body, category: cat, updatedAt: n.updatedAt, files: n.files));
        }
        _picks.clear();
      }),
      PickAction(Icons.share_outlined, tr('পাঠান'), () async {
        await brain.services.files.shareText(picked.map((n) => [n.title, if (n.body.isNotEmpty && n.body != n.title) n.body].join('\n')).join('\n\n'));
      }),
      PickAction(Icons.delete_outline_rounded, tr('মুছুন'), danger: true, () async {
        final messenger = ScaffoldMessenger.of(context);
        if (!await confirmDialog(context, title: trf('{0}টি নোট মুছবেন?', [bnDigits(picked.length)]), text: tr('৩০ দিন “রিসাইকেল বিন”-এ থাকবে।'), yes: tr('মুছুন'), danger: true)) return;
        for (final n in picked) {
          await brain.deleteNote(n.id);
        }
        _picks.clear();
        deletedSnack(messenger, picked.length, () => brain.undoLastDeletes(picked.length));
      }),
    ];
  }

  /// A new note: inside a category it goes there; on the categories page the
  /// user picks one first (owner, 22 Nov: the form has no বিভাগ field now).
  Future<void> _new() async {
    final cat = _cat ?? await pickNoteCategory(context, title: tr('কোন বিভাগে লিখবেন?'));
    if (cat == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewItemScreen(category: ItemCategory.note, noteCategory: cat)));
  }

  Future<void> _newCat() async {
    final brain = BrainScope.read(context);
    final name = await askText(context, tr('নতুন বিভাগ'), hint: tr('যেমন: বাড়ি, অফিস, বিয়ে'));
    if (name == null || name.trim().isEmpty || !mounted) return;
    final c = await brain.addNoteCat(name);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotesScreen(category: c)));
  }

  Future<void> _catMenu(String c) async {
    final brain = BrainScope.read(context);
    final nav = Navigator.of(context);
    final what = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(key: const Key('cat-rename'), leading: const Icon(Icons.edit_outlined), title: Text(tr('নাম বদলান')), onTap: () => Navigator.pop(ctx, 'rename')),
          if (c != defaultNoteCategory)
            ListTile(key: const Key('cat-remove'), leading: Icon(Icons.delete_outline_rounded, color: C.red), title: Text(tr('বিভাগটি সরান'), style: TextStyle(color: C.red)), onTap: () => Navigator.pop(ctx, 'remove')),
        ]),
      ),
    );
    if (!mounted) return;
    if (what == 'rename') {
      final to = await askText(context, tr('বিভাগের নাম'), initial: tr(c));
      if (to == null || to.trim().isEmpty) return;
      await brain.renameNoteCat(c, to);
      if (_cat == c) setState(() => _cat = to.trim());
    } else if (what == 'remove') {
      final n = brain.data.notes.where((x) => x.category == c).length;
      if (!await confirmDialog(context,
          title: trf('“{0}” সরাবেন?', [tr(c)]), text: n == 0 ? tr('বিভাগটি খালি।') : trf('এর {0}টি নোট “নোট” বিভাগে চলে যাবে, মুছবে না।', [bnDigits(n)]), yes: tr('সরান'), danger: true)) {
        return;
      }
      await brain.removeNoteCat(c);
      if (_cat == c) nav.maybePop();
    }
  }

  Widget _noteCard(Note n, {required bool picking, required bool showCat}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Panel(
          child: InkWell(
            key: Key('note-${n.id}'),
            onTap: picking ? () => _picks.toggle(n.id) : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewItemScreen(note: n))),
            onLongPress: () => _picks.toggle(n.id),
            child: Container(
              color: _picks.has(n.id) ? C.greenTint : null,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    if (picking) ...[
                      Icon(_picks.has(n.id) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: _picks.has(n.id) ? C.green : C.muted, size: 22),
                      const SizedBox(width: 8)
                    ],
                    if (isChecklist(n.body)) ...[Icon(Icons.checklist_rounded, size: 18, color: C.muted), const SizedBox(width: 6)],
                    Expanded(child: Text(n.title, style: body(16, weight: FontWeight.w600))),
                  ]),
                  if ((n.body.isNotEmpty && n.body != n.title) || n.files.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(isChecklist(n.body) || n.files.isNotEmpty ? notePreview(n) : n.body,
                        style: body(14, color: C.muted2, height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 6),
                  Text(showCat ? '${tr(n.category)} · ${shortDate(n.updatedAt)}' : shortDate(n.updatedAt), style: body(12, color: C.muted)),
                ],
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    AppStats.open('notes');
    final brain = BrainScope.of(context);
    final cats = brain.noteCats;
    final q = normalize(_q);
    final all = ([...brain.data.notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt))).where((n) => n.id != willNoteId).toList();
    final list = all
        .where((n) => _cat == null || n.category == _cat)
        .where((n) => q.isEmpty || normalize('${n.title} ${n.body} ${n.category}').contains(q))
        .toList();
    _picks.keepOnly(brain.data.notes.map((n) => n.id));
    final picking = _picks.on;
    // The first page: the will, then the categories as tiles (owner, 22 Nov).
    final home = _cat == null && q.isEmpty;

    return PopScope(
      canPop: !picking,
      onPopInvokedWithResult: (did, _) {
        if (!did) _picks.clear();
      },
      child: Scaffold(
        bottomNavigationBar: picking ? PickBar(picks: _picks, all: list.map((n) => n.id), actions: _actions(brain)) : const AdBar(),
        // Owner, 22 Nov: a floating "নোট লিখুন" on every notes page.
        floatingActionButton: picking ? null : AddButton(key: const Key('note-fab'), label: tr('নোট লিখুন'), icon: Icons.edit_outlined, onPressed: _new),
        body: SafeArea(
          child: Column(
            children: [
              TopBar(title: _cat == null ? tr('নোট ও অন্যান্য') : tr(_cat!), trailing: [
                const PdfButton({ReportPart.notes}),
                if (_cat != null) RoundIconButton(key: const Key('cat-menu'), icon: Icons.more_vert_rounded, tooltip: tr('বিভাগ'), onPressed: () => _catMenu(_cat!)),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: TextField(
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: _cat == null ? tr('সব নোটে খুঁজুন') : trf('{0}-এ খুঁজুন', [tr(_cat!)])),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                  children: home
                      ? [
                          // ওছিয়তনামা: its own card, with the day it was last changed (owner, 24 Oct).
                          const WillCard(),
                          const SizedBox(height: 18),
                          Row(children: [
                            Expanded(child: Text(tr('বিভাগ'), style: body(15, weight: FontWeight.w700))),
                            Text(trf('{0}টি নোট', [bnDigits(all.length)]), style: body(12.5, color: C.muted)),
                          ]),
                          const SizedBox(height: 10),
                          NoteCatGrid(
                            cats: cats,
                            notes: all,
                            onOpen: (c) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NotesScreen(category: c))),
                            onMenu: _catMenu,
                            onAdd: _newCat,
                          ),
                          if (all.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Text(tr('সাম্প্রতিক'), style: body(15, weight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            for (final n in all.take(3)) _noteCard(n, picking: picking, showCat: true),
                          ],
                        ]
                      : [
                          if (list.isEmpty && q.isEmpty)
                            EmptyState(
                              icon: noteCatIcon(_cat!),
                              title: trf('{0}-এ এখনো নোট নেই', [tr(_cat!)]),
                              text: tr('নিচের “নোট লিখুন” চাপুন — লেখা বা টিক দেওয়ার তালিকা, ছবি-ফাইলও রাখা যায়।'),
                            )
                          else if (list.isEmpty)
                            Text(tr('কিছু মেলেনি।'), style: body(14, color: C.muted))
                          else
                            for (final n in list) _noteCard(n, picking: picking, showCat: _cat == null),
                        ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// An icon for a category, by its name; others get a folder.
IconData noteCatIcon(String c) => switch (c) {
      'পারিবারিক' || 'পরিবার' => Icons.family_restroom_rounded,
      'ব্যবসা' => Icons.storefront_outlined,
      'অনুষ্ঠান' || 'জন্মদিন ও অনুষ্ঠান' => Icons.celebration_outlined,
      'ব্যক্তিগত' => Icons.person_outline_rounded,
      'কেনাকাটা' => Icons.shopping_bag_outlined,
      'পড়াশোনা' => Icons.school_outlined,
      'স্বাস্থ্য' => Icons.favorite_border_rounded,
      'যানবাহন' => Icons.directions_car_outlined,
      'বিল' => Icons.receipt_long_outlined,
      'কাগজপত্র' => Icons.description_outlined,
      'ঠিকানা' => Icons.location_on_outlined,
      'কাজ' || 'অফিস' => Icons.work_outline_rounded,
      'ডিভাইস' => Icons.devices_other_outlined,
      'ব্যাংক ও টাকা' => Icons.account_balance_outlined,
      'জিনিস কোথায় রাখা' => Icons.inventory_2_outlined,
      'রান্না' || 'রেসিপি' => Icons.restaurant_outlined,
      'ভ্রমণ' => Icons.flight_takeoff_rounded,
      defaultNoteCategory => Icons.sticky_note_2_outlined,
      _ => Icons.folder_outlined,
    };

/// The tile colours, the same for a name every time.
(Color, Color) noteCatColors(String c) {
  final set = [
    (C.ochre, C.ochreTint),
    (C.blue, C.blueTint),
    (C.teal, C.tealTint),
    (C.purple, C.purpleTint),
    (C.rose, C.roseTint),
    (C.green, C.greenTint),
  ];
  final fixed = {'পারিবারিক': 4, 'ব্যবসা': 1, 'অনুষ্ঠান': 3, 'ব্যক্তিগত': 2, 'কেনাকাটা': 0, 'পড়াশোনা': 5, defaultNoteCategory: 0};
  return set[fixed[c] ?? c.runes.fold<int>(0, (a, r) => a + r) % set.length];
}

/// The categories as two-across tiles, with "নতুন বিভাগ" last.
class NoteCatGrid extends StatelessWidget {
  const NoteCatGrid({super.key, required this.cats, required this.notes, required this.onOpen, required this.onMenu, required this.onAdd});
  final List<String> cats;
  final List<Note> notes;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onMenu;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    Widget tile(String c) {
      final n = notes.where((x) => x.category == c).length;
      final (fg, bg) = noteCatColors(c);
      return Panel(
        child: InkWell(
          key: Key('cat-$c'),
          onTap: () => onOpen(c),
          onLongPress: () => onMenu(c),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(noteCatIcon(c), color: fg, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr(c), style: body(14.5, weight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(n == 0 ? tr('খালি') : trf('{0}টি নোট', [bnDigits(n)]), style: body(12, color: C.muted)),
                ]),
              ),
            ]),
          ),
        ),
      );
    }

    final add = Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: BorderSide(color: C.border, width: 1.2)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('cat-add'),
        onTap: onAdd,
        child: SizedBox(
          height: 66,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_rounded, color: C.green, size: 24),
            const SizedBox(width: 6),
            Text(tr('নতুন বিভাগ'), style: body(14, weight: FontWeight.w600, color: C.green)),
          ]),
        ),
      ),
    );
    final items = [for (final c in cats) tile(c), add];
    return Column(children: [
      for (var i = 0; i < items.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: items[i]),
            const SizedBox(width: 10),
            Expanded(child: i + 1 < items.length ? items[i + 1] : const SizedBox()),
          ]),
        ),
    ]);
  }
}

/// Asks which category a note goes in (a sheet of the categories).
Future<String?> pickNoteCategory(BuildContext context, {required String title, String? current}) {
  final brain = BrainScope.read(context);
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: display(19)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in brain.noteCats)
              ActionChip(
                key: Key('pick-cat-$c'),
                avatar: Icon(noteCatIcon(c), size: 18, color: noteCatColors(c).$1),
                label: Text(tr(c), style: body(14, weight: c == current ? FontWeight.w700 : FontWeight.w400)),
                backgroundColor: c == current ? noteCatColors(c).$2 : C.surface,
                side: BorderSide(color: C.border),
                onPressed: () => Navigator.pop(ctx, c),
              ),
            ActionChip(
              key: const Key('pick-cat-new'),
              avatar: Icon(Icons.add_rounded, size: 18, color: C.green),
              label: Text(tr('নতুন বিভাগ'), style: body(14, color: C.green, weight: FontWeight.w600)),
              backgroundColor: C.surface,
              side: BorderSide(color: C.border),
              onPressed: () async {
                final name = await askText(ctx, tr('নতুন বিভাগ'), hint: tr('যেমন: বাড়ি, অফিস, বিয়ে'));
                if (name == null || name.trim().isEmpty || !ctx.mounted) return;
                final c = await brain.addNoteCat(name);
                if (ctx.mounted) Navigator.pop(ctx, c);
              },
            ),
          ]),
        ]),
      ),
    ),
  );
}
