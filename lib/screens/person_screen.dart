import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/ledger.dart';
import '../logic/phrases.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ledger_form_screen.dart';

/// One person's account: who (name and mobile), the balance, a reminder
/// message to send, and every transaction.
class PersonScreen extends StatefulWidget {
  const PersonScreen({super.key, this.person = '', this.accountKey});
  final String person;

  /// The account (see accountKeys); when null, the most recent with [person]'s name.
  final String? accountKey;

  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  late String? _key = widget.accountKey;

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  PersonBalance? _account(Brain brain) {
    final k = _key;
    final p = k != null ? accountByKey(brain.data.ledger, k) : balanceOf(brain.data.ledger, widget.person);
    return p;
  }

  /// Changes the name and/or number on every entry of this account.
  Future<void> _edit(Brain brain, PersonBalance p) async {
    final name = TextEditingController(text: p.name);
    final phone = TextEditingController(text: p.phone);
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('নাম ও নম্বর', style: display(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'নাম')),
          const SizedBox(height: 10),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'মোবাইল নম্বর')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('সেভ করুন')),
        ],
      ),
    );
    if (r != true || name.text.trim().isEmpty) return;
    final newPhone = asciiDigits(phone.text.trim());
    for (final (e, _) in runningForKey(brain.data.ledger, p.key)) {
      await brain.saveEntry(e.copyWith(person: name.text.trim(), phone: newPhone), guessPhone: false);
    }
    if (!mounted) return;
    setState(() => _key = phoneKey(newPhone).isNotEmpty ? 'p:${phoneKey(newPhone)}' : 'n:${personKey(name.text.trim())}');
  }

  Future<void> _rowMenu(Brain brain, LedgerEntry e) async {
    final r = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('সংশোধন করুন'), onTap: () => Navigator.pop(ctx, 'edit')),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: C.red),
            title: Text('মুছে ফেলুন', style: body(16, color: C.red)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    if (r == 'edit') _push(LedgerFormScreen(entry: e));
    if (r == 'delete') await deleteEntryWithUndo(context, brain, e);
  }

  Future<void> _open(Brain brain, Via via, String phone, {String text = ''}) async {
    final ok = await brain.services.launcher.open(via, phone, text: text);
    if (!ok && mounted) toast(context, via == Via.whatsapp ? 'WhatsApp খোলা গেল না' : 'খোলা গেল না');
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final p = _account(brain);
    if (p == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(children: [
            const TopBar(title: ''),
            Padding(padding: const EdgeInsets.all(20), child: Text('এই নামে কোনো লেনদেন নেই।', style: body(15, color: C.muted))),
          ]),
        ),
      );
    }
    _key ??= p.key;
    final rows = runningForKey(brain.data.ledger, p.key).reversed.toList();
    final bal = p.balance;
    final (fg, bg) = balanceColors(bal);
    final given = p.lentTotal + p.repaidTotal;
    final got = p.receivedTotal + p.borrowedTotal;
    final sameName = peopleNamed(brain.data.ledger, p.name).length > 1;
    final reminderText = bal > 0
        ? 'আসসালামু আলাইকুম ${p.name} ভাই, আপনার কাছে আমার ${taka(bal)} বাকি আছে। সুবিধামতো দিয়ে দিলে উপকার হয়। ধন্যবাদ।'
        : '';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: '', trailing: [
              TextButton.icon(
                onPressed: () => _edit(brain, p),
                icon: const Icon(Icons.edit_outlined, size: 18, color: C.green),
                label: Text('নাম/নম্বর', style: body(14, weight: FontWeight.w600, color: C.green)),
              ),
            ]),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Row(children: [
                    Avatar(name: p.name, fg: fg, bg: bg, size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: display(26, weight: 700)),
                        if (p.phone.isNotEmpty)
                          Text(showPhone(p.phone), style: body(15, color: C.muted2))
                        else
                          InkWell(
                            onTap: () => _edit(brain, p),
                            child: Text(sameName ? 'একই নামে আরেকজন আছেন — নম্বর যোগ করুন' : '+ মোবাইল নম্বর যোগ করুন',
                                style: body(14, weight: FontWeight.w600, color: sameName ? C.orange : C.green)),
                          ),
                      ]),
                    ),
                  ]),
                  if (p.phone.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      for (final (via, icon, label) in const [
                        (Via.call, Icons.call_outlined, 'ফোন'),
                        (Via.sms, Icons.sms_outlined, 'SMS'),
                        (Via.whatsapp, Icons.chat_outlined, 'WhatsApp'),
                      ]) ...[
                        if (via != Via.call) const SizedBox(width: 8),
                        Expanded(child: SecondaryButton(label: label, icon: icon, height: 44, onPressed: () => _open(brain, via, p.phone))),
                      ],
                    ]),
                  ],
                  const SizedBox(height: 16),
                  Panel(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(balanceHeading(p.name, bal), style: body(14, weight: FontWeight.w600, color: bal < 0 ? C.orangeDark : C.greenDark)),
                      Text(taka(bal.abs()), style: display(36, weight: 700, color: bal == 0 ? C.muted2 : fg, height: 1.2)),
                      const SizedBox(height: 4),
                      Text('দিয়েছেন ${taka(given)} · পেয়েছেন ${taka(got)}', style: body(14, color: C.muted)),
                    ]),
                  ),
                  if (bal > 0 && p.phone.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Panel(
                      color: C.greenSoft,
                      borderColor: C.greenTint,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('তাগাদা পাঠান', style: body(15, weight: FontWeight.w600)),
                        Text('“${taka(bal)} বাকি আছে” — লেখা তৈরি থাকবে, আপনি শুধু Send চাপবেন', style: body(13, color: C.muted)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: SecondaryButton(label: 'SMS', icon: Icons.sms_outlined, height: 42, onPressed: () => _open(brain, Via.sms, p.phone, text: reminderText))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: SecondaryButton(
                                  label: 'WhatsApp', icon: Icons.chat_outlined, height: 42, onPressed: () => _open(brain, Via.whatsapp, p.phone, text: reminderText))),
                        ]),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 18),
                  const SectionTitle('ইতিহাস'),
                  if (rows.isEmpty)
                    Panel(padding: const EdgeInsets.all(16), child: Text('এই নামে কোনো লেনদেন নেই।', style: body(14, color: C.muted)))
                  else
                    Panel(
                      child: Rows(children: [
                        for (final (e, after) in rows)
                          InkWell(
                            onTap: () => _rowMenu(brain, e),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(e.kind.label, style: body(15, weight: FontWeight.w600)),
                                    Text([shortDate(e.date), if (e.note.isNotEmpty) e.note].join(' · '), style: body(13, color: C.muted)),
                                  ]),
                                ),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(taka(e.amount), style: display(16, weight: 700, color: e.kind.outflow ? C.ink : C.green)),
                                  Text(after == 0 ? 'হিসাব শূন্য' : '${after > 0 ? 'পাওনা' : 'দেনা'} ${taka(after.abs())}', style: body(12, color: C.muted)),
                                ]),
                              ]),
                            ),
                          ),
                      ]),
                    ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: PrimaryButton(
                        label: bal < 0 ? 'শোধ করলাম' : 'টাকা পেলাম',
                        height: 50,
                        onPressed: () => _push(LedgerFormScreen(person: p.name, phone: p.phone, kind: bal < 0 ? LedgerKind.repaid : LedgerKind.received)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: bal < 0 ? 'আরও নিলাম' : 'আরও দিলাম',
                        height: 50,
                        color: C.ink,
                        onPressed: () => _push(LedgerFormScreen(person: p.name, phone: p.phone, kind: bal < 0 ? LedgerKind.borrowed : LedgerKind.lent)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Deletes with an "undo" on the snackbar.
Future<void> deleteEntryWithUndo(BuildContext context, Brain brain, LedgerEntry e) async {
  await brain.deleteEntry(e.id);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('${e.person}: ${e.kind.label} ${taka(e.amount)} মুছে ফেলা হয়েছে'),
      action: SnackBarAction(label: 'ফিরিয়ে আনুন', textColor: C.mint, onPressed: () => brain.saveEntry(e)),
    ));
}
