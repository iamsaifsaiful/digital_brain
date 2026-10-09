import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/parser.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'new_item_screen.dart';

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

  void _new() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => NewItemScreen(category: ItemCategory.note, noteCategory: _cat ?? defaultNoteCategory)));

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final cats = brain.data.noteCategories;
    final q = normalize(_q);
    final list = ([...brain.data.notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
        .where((n) => _cat == null || n.category == _cat)
        .where((n) => q.isEmpty || normalize('${n.title} ${n.body} ${n.category}').contains(q))
        .toList();

    Widget chip(String label, String? value) {
      final on = _cat == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label, style: body(14, weight: on ? FontWeight.w600 : FontWeight.w400, color: on ? Colors.white : C.ink)),
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: _cat ?? 'নোট ও অন্যান্য', trailing: [
              RoundIconButton(icon: Icons.add_rounded, tooltip: 'নতুন নোট', dark: true, onPressed: _new),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'খুঁজুন'),
              ),
            ),
            if (cats.length > 1)
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [chip('সব', null), for (final c in cats) chip(c, c)],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  if (brain.data.notes.isEmpty)
                    EmptyState(
                      icon: Icons.description_outlined,
                      title: 'কোনো নোট নেই',
                      text: 'বলুন “মনে রাখো: গাড়ির কাগজ আলমারির উপরের তাকে” — অ্যাপ ঠিক বিভাগে রেখে দেবে।',
                      action: 'নোট লিখুন',
                      onAction: _new,
                    )
                  else if (list.isEmpty)
                    Text('কিছু মেলেনি।', style: body(14, color: C.muted))
                  else
                    for (final n in list) ...[
                      Panel(
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewItemScreen(note: n))),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.title, style: body(16, weight: FontWeight.w600)),
                                if (n.body.isNotEmpty && n.body != n.title) ...[
                                  const SizedBox(height: 4),
                                  Text(n.body, style: body(14, color: C.muted2, height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
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
    );
  }
}
