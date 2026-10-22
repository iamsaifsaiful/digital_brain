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

/// Notes and everything else remembered, by category ("নোট", "যানবাহন"…).
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
        final cats = brain.data.noteCategories;
        final c = TextEditingController();
        final cat = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(tr('কোন বিভাগে?'), style: display(20)),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Wrap(spacing: 6, runSpacing: 6, children: [for (final k in cats) ActionChip(label: Text(k), onPressed: () => Navigator.pop(ctx, k))]),
                const SizedBox(height: 10),
                TextField(controller: c, decoration: InputDecoration(labelText: tr('নতুন বিভাগ'))),
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
        if (!await confirmDialog(context, title: trf('{0}টা নোট মুছবেন?', [bnDigits(picked.length)]), text: tr('৩০ দিন “মুছে ফেলা”-তে থাকবে।'), yes: tr('মুছুন'), danger: true)) return;
        for (final n in picked) {
          await brain.deleteNote(n.id);
        }
        _picks.clear();
        deletedSnack(messenger, picked.length, () => brain.undoLastDeletes(picked.length));
      }),
    ];
  }

  void _new() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewItemScreen(category: ItemCategory.note, noteCategory: _cat ?? defaultNoteCategory)));

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final cats = brain.data.noteCategories;
    final q = normalize(_q);
    final list = ([...brain.data.notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
        .where((n) => _cat == null || n.category == _cat)
        .where((n) => q.isEmpty || normalize('${n.title} ${n.body} ${n.category}').contains(q))
        .toList();
    _picks.keepOnly(brain.data.notes.map((n) => n.id));
    final picking = _picks.on;

    Widget chip(String label, String? value) {
      final on = _cat == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label, style: body(14, weight: on ? FontWeight.w600 : FontWeight.w400, color: on ? C.onInk : C.ink)),
          selected: on,
          showCheckmark: false,
          selectedColor: C.ink,
          backgroundColor: C.surface,
          side: BorderSide(color: on ? C.ink : C.border),
          shape: const StadiumBorder(),
          onSelected: (_) => setState(() => _cat = value),
        ),
      );
    }

    return PopScope(
      canPop: !picking,
      onPopInvokedWithResult: (did, _) {
        if (!did) _picks.clear();
      },
      child: Scaffold(
        bottomNavigationBar: picking ? PickBar(picks: _picks, all: list.map((n) => n.id), actions: _actions(brain)) : const AdBar(),
        body: SafeArea(
          child: Column(
            children: [
              TopBar(title: _cat ?? tr('নোট ও অন্যান্য'), trailing: [
                const PdfButton({ReportPart.notes}),
                RoundIconButton(icon: Icons.add_rounded, tooltip: tr('নতুন নোট'), dark: true, onPressed: _new),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: tr('খুঁজুন')),
                ),
              ),
              if (cats.length > 1)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [chip(tr('সব'), null), for (final c in cats) chip(c, c)],
                  ),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    if (brain.data.notes.isEmpty)
                      EmptyState(
                        icon: Icons.description_outlined,
                        title: tr('কোনো নোট নেই'),
                        text: tr('বলুন “মনে রাখো: গাড়ির কাগজ আলমারির উপরের তাকে” — অ্যাপ ঠিক বিভাগে রেখে দেবে।'),
                        action: tr('নোট লিখুন'),
                        onAction: _new,
                      )
                    else if (list.isEmpty)
                      Text(tr('কিছু মেলেনি।'), style: body(14, color: C.muted))
                    else
                      for (final n in list) ...[
                        Panel(
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
                                    Expanded(child: Text(n.title, style: body(16, weight: FontWeight.w600))),
                                  ]),
                                  if ((n.body.isNotEmpty && n.body != n.title) || n.files.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(isChecklist(n.body) || n.files.isNotEmpty ? notePreview(n) : n.body,
                                        style: body(14, color: C.muted2, height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(_cat == null ? '${n.category} · ${shortDate(n.updatedAt)}' : shortDate(n.updatedAt), style: body(12, color: C.muted)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
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
