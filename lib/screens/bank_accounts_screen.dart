import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/pin.dart';
import '../ui/secure.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// আমার ফাইল › ব্যাংক একাউন্ট (owner, 20 Nov): every bank account the user
/// has — bank, name, number, branch, routing — kept locked on this phone,
/// and sent to anyone (WhatsApp, Messenger, SMS, email…) in one tap. The
/// list shows only the last four digits; the whole number opens after the
/// fingerprint or PIN.
class BankAccountsScreen extends StatelessWidget {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) => SecureView(child: _secretBuild(context));

  Widget _secretBuild(BuildContext context) {
    final brain = BrainScope.of(context);
    final list = [...brain.data.bankAccounts]..sort((a, b) => a.bank.compareTo(b.bank));
    void add() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BankAccountForm()));
    return Scaffold(
      floatingActionButton: AddButton(key: const Key('acct-add'), label: tr('নতুন একাউন্ট'), onPressed: add),
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('ব্যাংক একাউন্ট'), trailing: [Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.lock_outline_rounded, color: C.green))]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
              if (list.isEmpty)
                EmptyState(
                  icon: Icons.account_balance_outlined,
                  title: tr('প্রথম একাউন্টটা রাখুন'),
                  text: tr('কেউ টাকা পাঠাতে চাইলে এক ট্যাপে পাঠিয়ে দিতে পারবেন।'),
                  action: tr('একাউন্ট যোগ করুন'),
                  onAction: add,
                )
              else
                for (final a in list) Padding(padding: const EdgeInsets.only(bottom: 10), child: _AccountTile(a)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The text sent when sharing an account.
String accountText(BankAccount a) => [
      a.bank,
      if (a.name.isNotEmpty) '${tr('একাউন্টের নাম')}: ${a.name}',
      if (a.number.isNotEmpty) '${tr('একাউন্ট নম্বর')}: ${a.number}',
      if (a.kind.isNotEmpty) '${tr('ধরন')}: ${tr(a.kind)}',
      if (a.branch.isNotEmpty) '${tr('শাখা')}: ${a.branch}',
      if (a.routing.isNotEmpty) '${tr('রাউটিং নম্বর')}: ${a.routing}',
      if (a.swift.isNotEmpty) 'SWIFT: ${a.swift}',
    ].join('\n');

/// Shares [a] after the fingerprint or PIN.
Future<void> shareAccount(BuildContext context, BankAccount a) async {
  final brain = BrainScope.read(context);
  if (!await verifyUser(context, reason: trf('{0} — শেয়ার করতে যাচাই করুন', [a.bank]))) return;
  await brain.services.files.shareText(accountText(a));
}

class _AccountTile extends StatelessWidget {
  const _AccountTile(this.a);
  final BankAccount a;

  @override
  Widget build(BuildContext context) => Material(
        color: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: C.border)),
        child: InkWell(
          key: Key('acct-${a.id}'),
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final ok = await verifyUser(context, reason: trf('{0} — দেখতে যাচাই করুন', [a.bank]));
            if (ok && context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => BankAccountScreen(id: a.id)));
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: C.greenTint, borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.account_balance_outlined, color: C.green, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.bank, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, weight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text([if (a.number.isNotEmpty) '•••• ${bnDigits(a.last4)}', if (a.name.isNotEmpty) a.name, if (a.kind.isNotEmpty) tr(a.kind)].join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12.5, color: C.muted)),
                ]),
              ),
              IconButton(
                key: Key('acct-share-${a.id}'),
                tooltip: tr('শেয়ার'),
                onPressed: () => shareAccount(context, a),
                icon: Icon(Icons.share_outlined, color: C.muted, size: 20),
              ),
            ]),
          ),
        ),
      );
}

/// One account, opened: every detail with a copy button, and share.
class BankAccountScreen extends StatelessWidget {
  const BankAccountScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) => SecureView(child: _secretBuild(context));

  Widget _secretBuild(BuildContext context) {
    final brain = BrainScope.of(context);
    final a = brain.data.bankAccounts.where((x) => x.id == id).firstOrNull;
    if (a == null) {
      return Scaffold(body: SafeArea(child: Column(children: [TopBar(title: tr('ব্যাংক একাউন্ট')), Expanded(child: Center(child: Text(tr('মুছে ফেলা হয়েছে'))))])));
    }
    final rows = [
      (tr('একাউন্টের নাম'), a.name),
      (tr('একাউন্ট নম্বর'), a.number),
      (tr('ধরন'), a.kind.isEmpty ? '' : tr(a.kind)),
      (tr('শাখা'), a.branch),
      (tr('রাউটিং নম্বর'), a.routing),
      ('SWIFT', a.swift),
      (tr('নোট'), a.note),
    ].where((r) => r.$2.isNotEmpty).toList();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: a.bank, trailing: [
            IconButton(
              tooltip: tr('বদলান'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BankAccountForm(account: a))),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: tr('মুছুন'),
              onPressed: () async {
                final ok = await confirmDialog(context, title: tr('একাউন্টটা মুছবেন?'), text: a.bank, yes: tr('মুছুন'), danger: true);
                if (!ok || !context.mounted) return;
                await brain.deleteBankAccount(a.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ]),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 16), children: [
              Container(
                decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: C.border)),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (final (i, r) in rows.indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 14, color: C.border),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(r.$1, style: body(12, color: C.muted)),
                            SelectableText(r.$2, style: body(15.5, weight: FontWeight.w500)),
                          ]),
                        ),
                        IconButton(
                          tooltip: tr('কপি'),
                          onPressed: () async {
                            await brain.services.files.copy(r.$2);
                            if (context.mounted) toast(context, tr('কপি হয়েছে'));
                          },
                          icon: Icon(Icons.copy_rounded, size: 19, color: C.muted),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: PrimaryButton(
              key: const Key('acct-share'),
              label: tr('শেয়ার করুন'),
              icon: Icons.share_outlined,
              height: 52,
              onPressed: () => brain.services.files.shareText(accountText(a)),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Adding or changing an account.
class BankAccountForm extends StatefulWidget {
  const BankAccountForm({super.key, this.account});
  final BankAccount? account;

  @override
  State<BankAccountForm> createState() => _BankAccountFormState();
}

class _BankAccountFormState extends State<BankAccountForm> {
  static const banks = ['ডাচ-বাংলা ব্যাংক', 'ব্র্যাক ব্যাংক', 'ইসলামী ব্যাংক', 'সোনালী ব্যাংক', 'সিটি ব্যাংক', 'ইস্টার্ন ব্যাংক', 'জনতা ব্যাংক', 'অগ্রণী ব্যাংক', 'প্রাইম ব্যাংক', 'ইউসিবি'];
  static const kinds = ['সঞ্চয়ী', 'চলতি', 'ছাত্র', 'বেতন', 'এফডিআর'];
  late final _bank = TextEditingController(text: widget.account?.bank ?? '');
  late final _name = TextEditingController(text: widget.account?.name ?? '');
  late final _number = TextEditingController(text: widget.account?.number ?? '');
  late final _branch = TextEditingController(text: widget.account?.branch ?? '');
  late final _routing = TextEditingController(text: widget.account?.routing ?? '');
  late final _swift = TextEditingController(text: widget.account?.swift ?? '');
  late final _note = TextEditingController(text: widget.account?.note ?? '');
  late String _kind = widget.account?.kind ?? '';

  @override
  void dispose() {
    for (final c in [_bank, _name, _number, _branch, _routing, _swift, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_bank.text.trim().isEmpty) {
      toast(context, tr('ব্যাংকের নাম লিখুন'));
      return;
    }
    await BrainScope.read(context).saveBankAccount(BankAccount(
      id: widget.account?.id,
      bank: _bank.text.trim(),
      name: _name.text.trim(),
      number: asciiDigits(_number.text).replaceAll(RegExp(r'\s'), ''),
      kind: _kind,
      branch: _branch.text.trim(),
      routing: asciiDigits(_routing.text).trim(),
      swift: _swift.text.trim().toUpperCase(),
      note: _note.text.trim(),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => SecureView(
        child: Scaffold(
          body: SafeArea(
            child: Column(children: [
              TopBar(title: widget.account == null ? tr('নতুন একাউন্ট') : tr('একাউন্ট বদলান')),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 16), children: [
                  TextField(key: const Key('acct-bank'), controller: _bank, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: tr('ব্যাংকের নাম'))),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    for (final b in banks) ActionChip(label: Text(tr(b), style: body(12.5)), onPressed: () => setState(() => _bank.text = tr(b))),
                  ]),
                  const SizedBox(height: 12),
                  TextField(key: const Key('acct-name'), controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: tr('একাউন্টের নাম'))),
                  const SizedBox(height: 12),
                  TextField(key: const Key('acct-number'), controller: _number, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('একাউন্ট নম্বর'))),
                  const SizedBox(height: 12),
                  Text(tr('ধরন'), style: body(13, color: C.muted)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final k in kinds) ChoiceChip(label: Text(tr(k)), selected: _kind == k, onSelected: (on) => setState(() => _kind = on ? k : '')),
                  ]),
                  const SizedBox(height: 12),
                  TextField(controller: _branch, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: tr('শাখা (ঐচ্ছিক)'))),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextField(controller: _routing, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('রাউটিং নম্বর (ঐচ্ছিক)')))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _swift, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'SWIFT'))),
                  ]),
                  const SizedBox(height: 12),
                  TextField(controller: _note, maxLines: 2, textCapitalization: TextCapitalization.sentences, decoration: InputDecoration(labelText: tr('নোট (ঐচ্ছিক)'))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: PrimaryButton(key: const Key('acct-save'), label: tr('রাখুন'), icon: Icons.lock_outline_rounded, height: 52, onPressed: _save),
              ),
            ]),
          ),
        ),
      );
}
