import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/parser.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'new_item_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final q = normalize(_q);
    final list = ([...brain.data.contacts]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())))
        .where((c) => q.isEmpty || normalize('${c.name} ${c.phone} ${c.email} ${c.note}').contains(q))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: 'যোগাযোগ', trailing: [
              RoundIconButton(
                icon: Icons.add_rounded,
                tooltip: 'নতুন যোগাযোগ',
                dark: true,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.contact))),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'নাম, নম্বর বা নোট দিয়ে খুঁজুন'),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  if (brain.data.contacts.isEmpty)
                    EmptyState(
                      icon: Icons.person_outline_rounded,
                      title: 'কোনো যোগাযোগ নেই',
                      text: 'মিস্ত্রি, ডাক্তার, অফিসের লোক — যাদের নম্বর মাঝে মাঝে লাগে, এখানে নোটসহ রাখুন।',
                      action: 'যোগাযোগ যোগ করুন',
                      onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.contact))),
                    )
                  else if (list.isEmpty)
                    Text('কিছু মেলেনি।', style: body(14, color: C.muted))
                  else
                    Panel(
                      child: Rows(children: [
                        for (final c in list)
                          ListRow(
                            leading: Avatar(name: c.name, fg: C.purple, bg: C.purpleTint),
                            title: c.name,
                            subtitle: [if (c.phone.isNotEmpty) bnDigits(c.phone), if (c.note.isNotEmpty) c.note].join(' · '),
                            trailing: c.phone.isEmpty
                                ? null
                                : Row(mainAxisSize: MainAxisSize.min, children: [
                                    IconButton(
                                      tooltip: 'ফোন দিন',
                                      onPressed: () => brain.services.launcher.open(Via.call, c.phone),
                                      icon: const Icon(Icons.call_outlined, size: 20, color: C.green),
                                    ),
                                    IconButton(
                                      tooltip: 'নম্বর কপি করুন',
                                      onPressed: () async {
                                        await brain.services.files.copy(c.phone);
                                        if (context.mounted) toast(context, 'নম্বর কপি হয়েছে');
                                      },
                                      icon: const Icon(Icons.copy_rounded, size: 20, color: C.muted),
                                    ),
                                  ]),
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewItemScreen(contact: c))),
                          ),
                      ]),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
