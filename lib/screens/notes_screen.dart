import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/parser.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'new_item_screen.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final q = normalize(_q);
    final list = ([...brain.data.notes]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)))
        .where((n) => q.isEmpty || normalize('${n.title} ${n.body}').contains(q))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: 'নোট', trailing: [
              RoundIconButton(
                icon: Icons.add_rounded,
                tooltip: 'নতুন নোট',
                dark: true,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.note))),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'নোটে খুঁজুন'),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  if (brain.data.notes.isEmpty)
                    EmptyState(
                      icon: Icons.description_outlined,
                      title: 'কোনো নোট নেই',
                      text: 'বলুন “মনে রাখো: গাড়ির কাগজ আলমারির উপরের তাকে” — অ্যাপ নোট করে রাখবে।',
                      action: 'নোট লিখুন',
                      onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.note))),
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
                                if (n.body.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(n.body, style: body(14, color: C.muted2, height: 1.5), maxLines: 4, overflow: TextOverflow.ellipsis),
                                ],
                                const SizedBox(height: 6),
                                Text(shortDate(n.updatedAt), style: body(12, color: C.muted)),
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
