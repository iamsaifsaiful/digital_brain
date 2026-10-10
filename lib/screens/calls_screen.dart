import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/ledger.dart' show showPhone;
import '../logic/parser.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'home_shell.dart';
import 'new_item_screen.dart';

/// ফোন ও মেসেজ: call, SMS or WhatsApp anyone saved, or a number typed in.
/// The phone's own app opens ready; the user presses call or send there.
class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  String _q = '';

  Future<void> _go(Via via, String phone, String name) async {
    final brain = BrainScope.read(context);
    var text = '';
    if (via != Via.call) {
      final c = TextEditingController();
      final r = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(via == Via.sms ? '$name-কে মেসেজ' : '$name-কে WhatsApp', style: display(19)),
          content: TextField(
            controller: c,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'কী লিখবেন? (খালি রাখলেও চলবে)'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
            TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('খুলুন')),
          ],
        ),
      );
      if (r == null) return;
      text = r;
    }
    final ok = await brain.services.launcher.open(via, phone, text: text);
    if (!ok && mounted) toast(context, 'এই ফোনে এটা খোলার মতো অ্যাপ পাওয়া গেল না');
  }

  Widget _actions(String phone, String name) => Row(mainAxisSize: MainAxisSize.min, children: [
        CircleAction(icon: Icons.call_rounded, tooltip: 'ফোন দিন', size: 38, onPressed: () => _go(Via.call, phone, name)),
        const SizedBox(width: 6),
        CircleAction(icon: Icons.sms_outlined, tooltip: 'মেসেজ (SMS)', size: 38, fg: C.blue, bg: C.blueTint, onPressed: () => _go(Via.sms, phone, name)),
        const SizedBox(width: 6),
        CircleAction(
            icon: Icons.chat_outlined,
            tooltip: 'WhatsApp',
            size: 38,
            fg: const Color(0xFF128C4A),
            bg: const Color(0xFFE3F6EA),
            onPressed: () => _go(Via.whatsapp, phone, name)),
      ]);

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final q = normalize(_q);
    final typed = findPhone(_q);
    final all = [...brain.data.contacts]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final withPhone = all.where((c) => q.isEmpty || normalize('${c.name} ${c.phone} ${c.note}').contains(q)).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: 'যোগাযোগ', trailing: [
              RoundIconButton(
                icon: Icons.person_add_alt_1_outlined,
                tooltip: 'নতুন নম্বর রাখুন',
                dark: true,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.contact))),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                onChanged: (v) => setState(() => _q = v),
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'নাম খুঁজুন, বা নম্বর লিখুন'),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Material(
                    color: C.greenSoft,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: C.greenTint)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => openVoice(context),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          const Icon(Icons.mic_none_rounded, color: C.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('মুখেও বলতে পারেন: “রহিমকে ফোন দাও”, “করিমকে মেসেজ দাও যে মাল পাঠিয়েছি”',
                                style: body(14, color: C.greenDark, height: 1.45)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (typed != null) ...[
                    Panel(
                      child: ListRow(
                        leading: const Icon(Icons.dialpad_rounded, color: C.ink),
                        title: bnDigits(typed),
                        subtitle: 'এই নম্বরে',
                        trailing: _actions(typed, bnDigits(typed)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (all.isNotEmpty) ...[
                    Text('ধার-দেনার মানুষ আর যোগাযোগ একই — নম্বর একবার রাখলেই দুই জায়গায় পাবেন।', style: body(13, color: C.muted)),
                    const SizedBox(height: 10),
                  ],
                  if (all.isEmpty)
                    EmptyState(
                      icon: Icons.contact_phone_outlined,
                      title: 'কোনো নম্বর রাখা নেই',
                      text: 'বলুন “রহিমের নম্বর ০১৭… রাখো”, অথবা উপরের বোতাম চেপে নম্বর রাখুন। উপরে নম্বর লিখেও সরাসরি ফোন দিতে পারেন।',
                      action: 'নম্বর রাখুন',
                      onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.contact))),
                    )
                  else if (withPhone.isEmpty && typed == null)
                    Text('কিছু মেলেনি।', style: body(14, color: C.muted))
                  else if (withPhone.isNotEmpty)
                    Panel(
                      child: Rows(children: [
                        for (final c in withPhone)
                          ListRow(
                            leading: Avatar(name: c.name, fg: C.purple, bg: C.purpleTint),
                            title: c.name,
                            subtitle: [if (c.note.trim().isNotEmpty) c.note.trim(), if (c.phone.isNotEmpty) showPhone(c.phone)].join(' · '),
                            trailing: c.phone.isEmpty ? null : _actions(c.phone, c.name),
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
