import '../logic/person_money.dart';
import 'money_search_screen.dart';
import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/ledger.dart';
import '../logic/phrases.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ledger_form_screen.dart';
import 'to_main.dart';
import '../logic/lang.dart';
import '../ui/pdf_export.dart';
import '../ui/pick.dart';

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

  /// Several entries picked (long-press a row) to delete or share together (owner, 24 Oct night).
  final _picks = Picks();

  @override
  void initState() {
    super.initState();
    _picks.addListener(_redraw);
  }

  void _redraw() => setState(() {});

  @override
  void dispose() {
    _picks.removeListener(_redraw);
    _picks.dispose();
    super.dispose();
  }

  List<PickAction> _pickActions(Brain brain) {
    final picked = [
      for (final e in brain.data.ledger)
        if (_picks.has(e.id)) e
    ];
    return [
      PickAction(Icons.share_outlined, tr('পাঠান'), () async {
        await brain.services.files.shareText(picked.map((e) => '${shortDate(e.date)} · ${e.person} · ${e.kind.label} ${taka(e.amount)}${e.note.isEmpty ? '' : ' (${e.note})'}').join('\n'));
      }),
      PickAction(Icons.delete_outline_rounded, tr('মুছুন'), danger: true, () async {
        final messenger = ScaffoldMessenger.of(context);
        if (!await confirmDialog(context, title: trf('{0}টা লেনদেন মুছবেন?', [bnDigits(picked.length)]), text: tr('৩০ দিন “মুছে ফেলা”-তে থাকবে।'), yes: tr('মুছুন'), danger: true)) return;
        for (final e in picked) {
          await brain.deleteEntry(e.id);
        }
        _picks.clear();
        deletedSnack(messenger, picked.length, () => brain.undoLastDeletes(picked.length));
      }),
    ];
  }

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
        title: Text(tr('নাম ও নম্বর'), style: display(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: InputDecoration(labelText: tr('নাম'))),
          const SizedBox(height: 10),
          TextField(controller: phone, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: tr('মোবাইল নম্বর'))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('বাতিল'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('সেভ করুন'))),
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
    final r = await showAppSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: Text(tr('সংশোধন করুন')), onTap: () => Navigator.pop(ctx, 'edit')),
          if (mainMenuLine(brain.data, e.id) case final line?)
            ListTile(leading: Icon(line.$2), title: Text(line.$1), onTap: () => Navigator.pop(ctx, 'main')),
          ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: C.red),
            title: Text(tr('মুছে ফেলুন'), style: body(16, color: C.red)),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    if (r == 'edit') _push(LedgerFormScreen(entry: e));
    if (r == 'main') await toggleMain(context, e.id);
    if (r == 'delete') await deleteEntryWithUndo(context, brain, e);
  }

  Future<void> _open(Brain brain, Via via, String phone, {String text = ''}) async {
    final ok = await brain.services.launcher.open(via, phone, text: text);
    if (!ok && mounted) toast(context, via == Via.whatsapp ? tr('WhatsApp খোলা গেল না') : tr('খোলা গেল না'));
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
            Padding(padding: const EdgeInsets.all(20), child: Text(tr('এই নামে কোনো লেনদেন নেই।'), style: body(15, color: C.muted))),
          ]),
        ),
      );
    }
    _key ??= p.key;
    final rows = runningForKey(brain.data.ledger, p.key).reversed.toList();
    _picks.keepOnly(rows.map((r) => r.$1.id));
    final picked = [for (final (e, _) in rows) if (_picks.has(e.id)) e];
    final pickedOut = picked.where((e) => e.kind.outflow).fold<int>(0, (a, e) => a + e.amount);
    final pickedIn = picked.where((e) => !e.kind.outflow).fold<int>(0, (a, e) => a + e.amount);
    final bal = p.balance;
    final (fg, bg) = balanceColors(bal);
    final given = p.lentTotal + p.repaidTotal;
    final got = p.receivedTotal + p.borrowedTotal;
    final sameName = peopleNamed(brain.data.ledger, p.name).length > 1;
    final all = personMoney(brain.data, p.name);
    final reminderText = bal > 0
        ? trf('আসসালামু আলাইকুম {0}, আপনার কাছে আমার {1} বাকি আছে। সুবিধামতো দিয়ে দিলে উপকার হয়। ধন্যবাদ।', [p.name, taka(bal)])
        : '';

    return PopScope(
      canPop: !_picks.on,
      onPopInvokedWithResult: (did, _) {
        if (!did) _picks.clear();
      },
      child: Scaffold(
      bottomNavigationBar: _picks.on
          ? PickBar(
              picks: _picks,
              all: rows.map((r) => r.$1.id),
              note: [
                if (pickedOut > 0) trf('গেছে {0}', [taka(pickedOut)]),
                if (pickedIn > 0) trf('এসেছে {0}', [taka(pickedIn)])
              ].join(' · '),
              actions: _pickActions(brain),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: '', trailing: [
              PdfButton(const {ReportPart.ledger}, scope: ReportScope(personKey: p.key), title: isEn ? 'Dealings with ${p.name}' : '${possessive(p.name)} সাথে লেনদেন'),
              TextButton.icon(
                onPressed: () => _edit(brain, p),
                icon: Icon(Icons.edit_outlined, size: 18, color: C.green),
                label: Text(tr('নাম/নম্বর'), style: body(14, weight: FontWeight.w600, color: C.green)),
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
                            child: Text(sameName ? tr('একই নামে আরেকজন আছেন — নম্বর যোগ করুন') : tr('+ মোবাইল নম্বর যোগ করুন'),
                                style: body(14, weight: FontWeight.w600, color: sameName ? C.orange : C.green)),
                          ),
                      ]),
                    ),
                  ]),
                  if (p.phone.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      for (final (via, icon, label) in [
                        (Via.call, Icons.call_outlined, tr('ফোন')),
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
                      Text(trf('দিয়েছেন {0} · পেয়েছেন {1}', [taka(given), taka(got)]), style: body(14, color: C.muted)),
                    ]),
                  ),
                  // The rest of this person's money (আয়-ব্যয় naming them, বকেয়া) and the নীট.
                  if (all.income > 0 || all.expense > 0 || all.lines.any((l) => l.projectId != null)) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      key: const Key('person-all'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _push(MoneySearchScreen(query: p.name)),
                      child: Panel(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(children: [
                        Icon(Icons.account_balance_wallet_outlined, color: C.green),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(trf('সব হিসাব · নীট {0}{1}', [all.net < 0 ? '−' : '', taka(all.net.abs())]), style: body(15, weight: FontWeight.w600)),
                            Text(trf('আয় {0} · ব্যয় {1} · বকেয়া/পাওনা {2}', [taka(all.income), taka(all.expense), taka(all.owed)]), style: body(13, color: C.muted)),
                          ]),
                        ),
                        Icon(Icons.chevron_right_rounded, color: C.muted),
                      ]),
                    ),
                    ),
                  ],
                  // The agreed pay-back day, while money is still out.
                  if (bal != 0)
                    for (final (e, _) in rows)
                      if (e.due != null && !e.due!.isBefore(dayOnly(brain.services.now())) && ((bal > 0) == (e.kind == LedgerKind.lent)))
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: InfoBanner(
                            icon: Icons.event_available_outlined,
                            text: trf('{0} — {1} ({2})', [bal > 0 ? tr('ফেরত পাওয়ার কথা') : tr('শোধের কথা'), fullDate(e.due!), daysLeftLabel(e.due!, brain.services.now())]),
                          ),
                        ),
                  if (bal > 0 && p.phone.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Panel(
                      color: C.greenSoft,
                      borderColor: C.greenTint,
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(tr('তাগাদা পাঠান'), style: body(15, weight: FontWeight.w600)),
                        Text(trf('“{0} বাকি আছে” — লেখা তৈরি থাকবে, আপনি শুধু Send চাপবেন', [taka(bal)]), style: body(13, color: C.muted)),
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
                  SectionTitle(tr('ইতিহাস')),
                  if (rows.isEmpty)
                    Panel(padding: const EdgeInsets.all(16), child: Text(tr('এই নামে কোনো লেনদেন নেই।'), style: body(14, color: C.muted)))
                  else
                    Panel(
                      child: Rows(children: [
                        for (final (e, after) in rows)
                          InkWell(
                            key: Key('person-row-${e.id}'),
                            onTap: () => _picks.on ? _picks.toggle(e.id) : _rowMenu(brain, e),
                            onLongPress: () => _picks.toggle(e.id),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                              child: Row(children: [
                                if (_picks.on) ...[PickMark(_picks.has(e.id)), const SizedBox(width: 10)],
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(e.kind.label, style: body(15, weight: FontWeight.w600)),
                                    Text([shortDate(e.date), if (e.note.isNotEmpty) e.note].join(' · '), style: body(13, color: C.muted)),
                                  ]),
                                ),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text(taka(e.amount), style: display(16, weight: 700, color: e.kind.outflow ? C.ink : C.green)),
                                  Text(after == 0 ? tr('হিসাব শূন্য') : '${after > 0 ? 'পাওনা' : 'দেনা'} ${taka(after.abs())}', style: body(12, color: C.muted)),
                                ]),
                              ]),
                            ),
                          ),
                      ]),
                    ),
                  if (rows.length > 1 && !_picks.on)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 2),
                      child: Text(tr('কয়েকটা একসাথে মুছতে বা পাঠাতে একটায় চেপে ধরুন'), style: body(12, color: C.muted)),
                    ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: PrimaryButton(
                        label: bal < 0 ? tr('শোধ করলাম') : tr('টাকা পেলাম'),
                        height: 50,
                        onPressed: () => _push(LedgerFormScreen(person: p.name, phone: p.phone, kind: bal < 0 ? LedgerKind.repaid : LedgerKind.received)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: bal < 0 ? tr('আরও নিলাম') : tr('আরও দিলাম'),
                        height: 50,
                        color: C.fill,
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
      content: Text(trf('{0}: {1} {2} মুছে ফেলা হয়েছে', [e.person, e.kind.label, taka(e.amount)])),
      persist: false,
      duration: const Duration(seconds: 5),
      action: SnackBarAction(label: tr('ফিরিয়ে আনুন'), textColor: C.mint, onPressed: () => brain.undoLastDelete()),
    ));
}
