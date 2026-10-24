import 'package:flutter/material.dart';

import '../logic/pro.dart';

import '../ui/pro_gate.dart';

import '../logic/bn.dart';
import '../logic/ledger.dart';
import '../logic/phrases.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'calls_screen.dart';
import 'home_shell.dart';
import '../logic/cash.dart' show mainAddedText;
import '../logic/lang.dart';

String _tail(String s) => s.length <= 3 ? s : s.substring(s.length - 3);

/// Add (or correct) a money transaction by typing.
class LedgerFormScreen extends StatefulWidget {
  const LedgerFormScreen({super.key, this.entry, this.person, this.phone, this.kind, this.amount, this.note});
  final LedgerEntry? entry;
  final String? person;
  final String? phone;
  final LedgerKind? kind;

  /// Filled in from a message.
  final int? amount;
  final String? note;

  @override
  State<LedgerFormScreen> createState() => _LedgerFormScreenState();
}

class _LedgerFormScreenState extends State<LedgerFormScreen> {
  late LedgerKind _kind = widget.entry?.kind ?? widget.kind ?? LedgerKind.lent;
  late final _person = TextEditingController(text: widget.entry?.person ?? widget.person ?? '');
  late final _phone = TextEditingController(text: widget.entry?.phone ?? widget.phone ?? '');
  late final _amount = TextEditingController(text: widget.entry == null ? (widget.amount == null ? '' : '${widget.amount}') : '${widget.entry!.amount}');
  late final _note = TextEditingController(text: widget.entry?.note ?? widget.note ?? '');
  late DateTime _date;
  DateTime? _due;
  final _form = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _date = widget.entry?.date ?? dayOnly(BrainScope.read(context).services.now());
    _due = widget.entry?.due;
    _person.addListener(() => setState(() {}));
    _phone.addListener(() => setState(() {}));
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _person.dispose();
    _phone.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _amountValue => int.tryParse(asciiDigits(_amount.text).replaceAll(RegExp(r'[,\s৳]'), ''));

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final brain = BrainScope.read(context);
    final person = _person.text.trim();
    final amount = _amountValue!;
    final phone = asciiDigits(_phone.text.trim());
    final others = brain.data.ledger.where((e) => e.id != widget.entry?.id);
    if (widget.entry == null && !await needPro(context, ProFeature.people, allowed: brain.canAddPerson(person))) return;
    if (!mounted) return;
    final after = balanceWith(others, person, phone: phone) + _kind.signed(amount);
    final e = widget.entry == null
        ? LedgerEntry(person: person, phone: phone, kind: _kind, amount: amount, date: _date, note: _note.text.trim(), due: _hasDue ? _due : null)
        : widget.entry!.copyWith(person: person, phone: phone, kind: _kind, amount: amount, date: _date, note: _note.text.trim(), due: _hasDue ? _due : null, clearDue: !_hasDue || _due == null);
    await brain.saveEntry(e, guessPhone: false);
    if (!mounted) return;
    // A loan goes into the main money by itself (owner, 24 Oct): say so too.
    final main = brain.lastMainLine;
    toast(context, trf('সেভ হয়েছে। {0}', [balanceSentence(person, after)]) + (main == null ? '' : '\n${mainAddedText(main)}'));
    final nav = Navigator.of(context);
    nav.pop();
    if (nav.mounted) await afterTaskDone(nav.context);
  }

  /// Only a loan (given or taken) has a pay-back day.
  bool get _hasDue => _kind == LedgerKind.lent || _kind == LedgerKind.borrowed;

  /// From যোগাযোগ (bringing the phone book first if it is empty).
  Future<void> _pick() async {
    final c = await pickContact(context);
    if (c == null || !mounted) return;
    setState(() {
      _person.text = c.name;
      _phone.text = c.phone;
    });
  }

  Future<void> _pickDate() async {
    final now = BrainScope.read(context).services.now();
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: now.add(const Duration(days: 3650)));
    if (d != null) setState(() => _date = d);
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final known = balances(brain.data.ledger)..sort((a, b) => (b.last ?? DateTime(0)).compareTo(a.last ?? DateTime(0)));
    final person = _person.text.trim();
    final phone = asciiDigits(_phone.text.trim());
    final amount = _amountValue;
    final others = brain.data.ledger.where((e) => e.id != widget.entry?.id).toList();
    final before = person.isEmpty ? 0 : balanceWith(others, person, phone: phone);
    // Two "রহিম"? Show both with their numbers to pick from.
    final namesake = person.isEmpty ? <PersonBalance>[] : peopleNamed(others, person);
    final ambiguous = namesake.length > 1 || (namesake.length == 1 && namesake.first.phone.isNotEmpty && phoneKey(phone) != phoneKey(namesake.first.phone));
    final after = amount == null ? before : before + _kind.signed(amount);

    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: Column(
            children: [
              TopBar(
                title: widget.entry == null ? tr('লেনদেন যোগ') : tr('লেনদেন সংশোধন'),
                trailing: [
                  if (widget.entry == null)
                    TextButton.icon(
                      onPressed: () => openVoice(context),
                      style: TextButton.styleFrom(backgroundColor: C.greenTint, foregroundColor: C.greenDark, minimumSize: const Size(44, 40)),
                      icon: const Icon(Icons.mic_none_rounded, size: 18),
                      label: Text(tr('বলে যোগ'), style: body(14, weight: FontWeight.w600, color: C.greenDark)),
                    ),
                ],
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    Text(tr('লেনদেনের ধরন'), style: body(14, weight: FontWeight.w600, color: C.muted)),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 2.5,
                      children: [
                        for (final k in LedgerKind.values)
                          Semantics(
                            selected: k == _kind,
                            child: Material(
                              color: k == _kind ? C.greenSoft : C.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(color: k == _kind ? C.green : C.border, width: k == _kind ? 2 : 1),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => setState(() => _kind = k),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(k.label, style: body(16, weight: FontWeight.w600, height: 1.2)),
                                      Text(k.hint, style: body(12, color: C.muted, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _person,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: _kind == LedgerKind.lent || _kind == LedgerKind.repaid ? tr('কাকে') : tr('কার কাছ থেকে'),
                        suffixIcon: IconButton(tooltip: tr('যোগাযোগ থেকে বেছে নিন'), icon: const Icon(Icons.person_search_outlined), onPressed: _pick),
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty ? tr('নাম লিখুন') : null,
                    ),
                    if (known.isNotEmpty && person.isEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        for (final k in known.take(6))
                          ActionChip(
                            label: Text(k.phone.isEmpty ? k.name : '${k.name} · …${_tail(showPhone(k.phone))}', style: body(14)),
                            backgroundColor: C.surface,
                            side: BorderSide(color: C.border),
                            onPressed: () {
                              _person.text = k.name;
                              _phone.text = k.phone;
                            },
                          ),
                      ]),
                    ],
                    if (ambiguous && phoneKey(phone).isEmpty) ...[
                      const SizedBox(height: 10),
                      Text(trf('“{0}” নামে {1} জন আছেন — নম্বর দেখে বেছে নিন', [person, bnDigits(namesake.length)]),
                          style: body(13, weight: FontWeight.w600, color: C.orangeDark)),
                      const SizedBox(height: 6),
                      Panel(
                        child: Rows(children: [
                          for (final n in namesake)
                            ListRow(
                              leading: Avatar(name: n.name, size: 36, fg: balanceColors(n.balance).$1, bg: balanceColors(n.balance).$2),
                              title: n.name,
                              subtitle: [
                                n.phone.isEmpty ? tr('নম্বর নেই') : showPhone(n.phone),
                                if (n.balance != 0) '${n.balance > 0 ? 'পাব' : 'দেব'} ${taka(n.balance.abs())}',
                              ].join(' · '),
                              onTap: () => setState(() => _phone.text = n.phone.isEmpty ? '' : n.phone),
                            ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: tr('মোবাইল নম্বর'),
                        hintText: tr('একই নামের মানুষ আলাদা রাখতে'),
                        suffixIcon: IconButton(
                          tooltip: tr('যোগাযোগ বা ফোনবুক থেকে নিন'),
                          icon: const Icon(Icons.contacts_outlined),
                          onPressed: _pick,
                        ),
                      ),
                      validator: (v) {
                        final d = phoneKey(v ?? '');
                        return d.isNotEmpty && d.length < 10 ? tr('নম্বরটা পুরো লিখুন') : null;
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _amount,
                            keyboardType: TextInputType.number,
                            style: display(22),
                            decoration: InputDecoration(labelText: tr('পরিমাণ (৳)')),
                            validator: (_) => (_amountValue ?? 0) <= 0 ? tr('টাকার পরিমাণ লিখুন') : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: InputDecoration(labelText: tr('তারিখ')),
                              child: Text(fullDate(_date), style: body(16), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_hasDue) ...[
                      const SizedBox(height: 14),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final now = BrainScope.read(context).services.now();
                          final d = await showDatePicker(
                              context: context, initialDate: _due ?? now.add(const Duration(days: 30)), firstDate: dayOnly(now), lastDate: now.add(const Duration(days: 3650)));
                          if (d != null) setState(() => _due = d);
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: _kind == LedgerKind.lent ? tr('ফেরত পাওয়ার তারিখ (ঐচ্ছিক)') : tr('শোধের তারিখ (ঐচ্ছিক)'),
                            helperText: BrainScope.of(context).has(ProFeature.dueReminders)
                                ? tr('দিলে আগের দিন আর সেদিন সকালে মনে করাবো')
                                : tr('তারিখ লেখা থাকবে। সেদিন মনে করানো প্রিমিয়াম সুবিধা।'),
                            prefixIcon: const Icon(Icons.event_available_outlined, size: 20),
                            suffixIcon: _due == null ? null : IconButton(tooltip: tr('তারিখ মুছুন'), onPressed: () => setState(() => _due = null), icon: const Icon(Icons.close_rounded)),
                          ),
                          child: Text(_due == null ? tr('তারিখ বেছে নিন') : fullDate(_due!), style: body(16, color: _due == null ? C.muted : C.ink)),
                        ),
                      ),
                      if (_due != null && !BrainScope.of(context).has(ProFeature.dueReminders))
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => needPro(context, ProFeature.dueReminders),
                            icon: const ProMark(),
                            label: Text(tr('সেদিন মনে করাক')),
                          ),
                        ),
                    ],
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _note,
                      decoration: InputDecoration(labelText: tr('নোট (ঐচ্ছিক)'), hintText: tr('কেন বা কীভাবে — যেমন “বিকাশে”')),
                    ),
                    const SizedBox(height: 14),
                    if (person.isNotEmpty && amount != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: after < 0 ? C.orangeTint : C.greenTint, borderRadius: BorderRadius.circular(14)),
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(text: trf('সেভ করলে {0}: ', [balanceHeading(person, after).replaceAll('আপনি ', '')])),
                            TextSpan(text: '${taka(before)} → ', style: display(17)),
                            TextSpan(text: taka(after), style: display(17, weight: 700, color: balanceColor(after))),
                          ]),
                          style: body(14, color: C.muted2),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: PrimaryButton(label: tr('সেভ করুন'), icon: Icons.check_rounded, onPressed: _save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
