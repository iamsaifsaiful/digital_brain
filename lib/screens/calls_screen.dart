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
    final list = all.where((c) => q.isEmpty || normalize('${c.name} ${c.phone} ${asciiDigits(c.phone)} ${c.note}').contains(q)).toList();
    void addNew() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.contact)));

    final header = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: SecondaryButton(
          label: all.isEmpty ? 'ফোনবুক থেকে সব নম্বর আনুন' : 'ফোনবুক থেকে নতুন নম্বর আনুন',
          icon: Icons.download_rounded,
          fg: C.green,
          borderColor: C.green,
          onPressed: () => importFromPhone(context),
        ),
      ),
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
      if (all.isEmpty)
        EmptyState(
          icon: Icons.contact_phone_outlined,
          title: 'কোনো নম্বর রাখা নেই',
          text: 'উপরের বোতাম চেপে ফোনের সব নম্বর এক বারে আনুন, অথবা বলুন “রহিমের নম্বর ০১৭… রাখো”।',
          action: 'নিজে লিখে রাখুন',
          onAction: addNew,
        )
      else ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('${bnDigits(all.length)} জন · ধার-দেনার মানুষ আর যোগাযোগ একই — নম্বর একবার রাখলেই দুই জায়গায় পাবেন।',
              style: body(13, color: C.muted)),
        ),
        if (list.isEmpty && typed == null) Text('কিছু মেলেনি।', style: body(14, color: C.muted)),
      ],
    ];

    Widget row(int i) {
      final c = list[i];
      final first = i == 0, last = i == list.length - 1;
      return Container(
        decoration: BoxDecoration(
          color: C.surface,
          border: Border(
            left: const BorderSide(color: C.line),
            right: const BorderSide(color: C.line),
            top: first ? const BorderSide(color: C.line) : BorderSide.none,
            bottom: BorderSide(color: last ? C.line : C.line2),
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(first ? 16 : 0), bottom: Radius.circular(last ? 16 : 0)),
        ),
        child: ListRow(
          leading: Avatar(name: c.name, fg: C.purple, bg: C.purpleTint),
          title: c.name,
          subtitle: [if (c.note.trim().isNotEmpty) c.note.trim(), if (c.phone.isNotEmpty) showPhone(c.phone)].join(' · '),
          trailing: c.phone.isEmpty ? null : _actions(c.phone, c.name),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewItemScreen(contact: c))),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: 'যোগাযোগ', trailing: [
              IconButton(tooltip: 'নতুন নম্বর রাখুন', onPressed: addNew, icon: const Icon(Icons.person_add_alt_1_outlined)),
              IconButton(tooltip: 'মুখে বলুন', onPressed: () => openVoice(context), icon: const Icon(Icons.mic_none_rounded, color: C.green)),
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
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: header.length + list.length,
                itemBuilder: (_, i) => i < header.length ? header[i] : row(i - header.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "ফোনবুক থেকে আনুন": every number in the phone, without repeats.
Future<void> importFromPhone(BuildContext context) async {
  final brain = BrainScope.read(context);
  final r = await brain.importPhonebook();
  if (!context.mounted) return;
  if (r == null) {
    toast(context, 'ফোনবুক পড়ার অনুমতি দেওয়া হয়নি। আবার চাপলে অনুমতি চাইব।');
    return;
  }
  final (added, skipped) = r;
  toast(
    context,
    added == 0
        ? 'নতুন কোনো নম্বর পাওয়া যায়নি${skipped > 0 ? ' — ${bnDigits(skipped)}টি আগেই ছিল' : ''}'
        : '${bnDigits(added)} জনের নম্বর আনা হলো${skipped > 0 ? ' · ${bnDigits(skipped)}টি একই নম্বর বাদ দিলাম' : ''}',
  );
}

/// Choose someone from যোগাযোগ (with search), or bring the phone book first.
Future<Contact?> pickContact(BuildContext context) async {
  final brain = BrainScope.read(context);
  if (!brain.data.contacts.any((c) => c.phone.trim().isNotEmpty)) {
    final ok = await confirmDialog(context,
        title: 'ফোনবুক থেকে আনব?', text: 'যোগাযোগে এখনো কোনো নম্বর নেই। ফোনের সব নম্বর এক বারে নিয়ে আসি? একই নম্বর দুবার আসবে না।', yes: 'আনুন');
    if (!ok || !context.mounted) return null;
    await importFromPhone(context);
    if (!context.mounted || !brain.data.contacts.any((c) => c.phone.trim().isNotEmpty)) return null;
  }
  return showModalBottomSheet<Contact>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ContactPicker(),
  );
}

class _ContactPicker extends StatefulWidget {
  const _ContactPicker();

  @override
  State<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends State<_ContactPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final q = normalize(_q);
    final list = ([...brain.data.contacts.where((c) => c.phone.trim().isNotEmpty)]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())))
        .where((c) => q.isEmpty || normalize('${c.name} ${asciiDigits(c.phone)}').contains(q))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            autofocus: false,
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'নাম বা নম্বর খুঁজুন'),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.download_rounded, color: C.green),
          title: Text('ফোনবুক থেকে নতুন নম্বর আনুন', style: body(15, weight: FontWeight.w600, color: C.green)),
          onTap: () => importFromPhone(context),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) => ListTile(
              leading: Avatar(name: list[i].name, size: 36, fg: C.purple, bg: C.purpleTint),
              title: Text(list[i].name, style: body(15, weight: FontWeight.w600)),
              subtitle: Text(showPhone(list[i].phone), style: body(13, color: C.muted)),
              onTap: () => Navigator.pop(context, list[i]),
            ),
          ),
        ),
      ]),
    );
  }
}
