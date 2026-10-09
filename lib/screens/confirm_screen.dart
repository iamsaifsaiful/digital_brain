import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/ledger.dart';
import '../logic/parser.dart';
import '../logic/phrases.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yes_no.dart';
import 'person_screen.dart';
import 'voice_screen.dart';

/// "ঠিক বুঝেছি তো?" — shows what was understood from a money sentence and
/// saves only after the user agrees. When the meaning was unclear it first
/// asks which kind of transaction it was.
class ConfirmScreen extends StatefulWidget {
  const ConfirmScreen({super.key, required this.command});
  final LedgerAdd command;

  @override
  State<ConfirmScreen> createState() => _ConfirmScreenState();
}

class _ConfirmScreenState extends State<ConfirmScreen> {
  late LedgerKind? _kind = widget.command.kind;
  late String _person = widget.command.person;
  late int _amount = widget.command.amount;
  late DateTime _date;
  String? _picked; // in the clarify step: a kind name or 'expense'
  bool _saving = false;
  late final SpokenQuestion _q;
  final _nameCtl = TextEditingController();
  final _amountCtl = TextEditingController();

  /// Money was mentioned but not with whom / how much: ask that first.
  bool get _needName => _person.trim().isEmpty;
  bool get _needAmount => !_needName && _amount <= 0;

  @override
  void initState() {
    super.initState();
    final brain = BrainScope.read(context);
    _date = dayOnly(brain.services.now());
    _q = SpokenQuestion(voice: brain.services.voice, onAnswer: _onAnswer);
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakQuestion());
  }

  @override
  void dispose() {
    _q.dispose();
    _nameCtl.dispose();
    _amountCtl.dispose();
    super.dispose();
  }

  void _speakQuestion() {
    if (_needName) {
      _q.ask('টাকার হিসাব লেনদেনের খাতায় রাখি। কার সাথে লেনদেন হলো? নামটা বলেন।');
    } else if (_needAmount) {
      _q.ask('কত টাকা?');
    } else {
      _q.ask(_kind != null ? confirmQuestion(_kind!, _person, _amount) : _clarifyQuestion());
    }
  }

  void _setName(String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    _q.stop();
    setState(() => _person = n);
    _speakQuestion();
  }

  void _setAmount(int? a) {
    if (a == null || a <= 0) {
      setState(() => _q.hint = 'টাকার অঙ্কটা ধরতে পারিনি। আবার বলেন, বা লিখে দিন।');
      return;
    }
    _q.stop();
    setState(() => _amount = a);
    _speakQuestion();
  }

  /// A spoken answer: হ্যাঁ saves; না keeps the screen for changes; in the
  /// clarify step a named choice ("শোধ", "নতুন ধার", "খরচ") or হ্যাঁ for the
  /// likely one.
  void _onAnswer(String heard) {
    if (_saving || !mounted) return;
    if (_needName) {
      if (widget.command.allowExpense && pickSpokenOption(heard, const [], allowExpense: true) == 'expense') {
        _picked = 'expense';
        _proceed();
        return;
      }
      final n = spokenName(heard, knownPeople(BrainScope.read(context).data.ledger));
      if (n.isEmpty) {
        setState(() => _q.hint = 'নামটা ধরতে পারিনি। আবার বলেন, বা লিখে দিন।');
      } else {
        _setName(n);
      }
      return;
    }
    if (_needAmount) {
      _setAmount(findAmount(normalize(heard)));
      return;
    }
    if (_kind == null) {
      final pick = pickSpokenOption(heard, [for (final o in widget.command.options) o.name], allowExpense: widget.command.allowExpense);
      final yn = yesNo(heard);
      final choice = pick ?? (yn == true ? widget.command.suggested?.name : null);
      if (choice == null) {
        setState(() => _q.hint = 'ঠিক ধরতে পারিনি। একটা বেছে নিন, বা বলেন — যেমন “শোধ” বা “নতুন ধার”।');
        return;
      }
      setState(() => _picked = choice);
      _proceed();
      return;
    }
    switch (yesNo(heard)) {
      case true:
        _save();
      case false:
        setState(() => _q.hint = 'আচ্ছা, লিখিনি। কিছু ভুল থাকলে “বদলান” চেপে ঠিক করে নিন।');
      case null:
        setState(() => _q.hint = 'ঠিক ধরতে পারিনি। “হ্যাঁ” বা “না” বলেন, অথবা বোতাম চাপুন।');
    }
  }

  void _proceed() {
    if (_picked == 'expense') {
      toast(context, 'ঠিক আছে, এটা লেনদেনের খাতায় রাখা হলো না।');
      Navigator.of(context).pop();
      return;
    }
    setState(() => _kind = LedgerKind.values.byName(_picked!));
    _speakQuestion();
  }

  String _clarifyQuestion() {
    final o = widget.command.options;
    if (o.contains(LedgerKind.repaid) && widget.command.allowExpense) {
      return 'একটু বুঝিয়ে বলেন — এটা কি আগের দেনা শোধ করলেন, নাকি নতুন করে ধার দিলেন? নাকি অন্য কোনো খরচ?';
    }
    if (o.contains(LedgerKind.received) && o.contains(LedgerKind.borrowed)) {
      return 'একটু বুঝিয়ে বলেন — উনি কি আগের টাকা ফেরত দিলেন, নাকি আপনি নতুন করে ধার নিলেন?';
    }
    return 'একটু বুঝিয়ে বলেন — এটা কোন ধরনের লেনদেন?';
  }

  Future<void> _save() async {
    if (_saving) return;
    _q.stop();
    final brain = BrainScope.read(context);
    final kind = _kind!;
    setState(() => _saving = true);
    final before = balanceWith(brain.data.ledger, _person);
    final after = before + kind.signed(_amount);
    await brain.saveEntry(LedgerEntry(person: _person.trim(), kind: kind, amount: _amount, date: _date, note: ''));
    await brain.services.voice.speak(savedSentence(kind, _person, _amount, after));
    if (!mounted) return;
    toast(context, 'লিখে রাখলাম। ${balanceSentence(_person, after)}');
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PersonScreen(person: _person.trim())));
  }

  Future<void> _editPerson() async {
    _q.stop();
    final c = TextEditingController(text: _person);
    final known = knownPeople(BrainScope.read(context).data.ledger);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('কার সাথে', style: display(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: c, autofocus: true, decoration: const InputDecoration(labelText: 'নাম')),
            if (known.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final k in known.take(6)) ActionChip(label: Text(k), onPressed: () => Navigator.pop(ctx, k)),
              ]),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('ঠিক আছে')),
        ],
      ),
    );
    if (r != null && r.isNotEmpty) setState(() => _person = r);
  }

  Future<void> _editAmount() async {
    _q.stop();
    final c = TextEditingController(text: '$_amount');
    final r = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('পরিমাণ', style: display(20)),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(prefixText: '৳ ', labelText: 'টাকা'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(asciiDigits(c.text).replaceAll(',', '').trim())),
            child: const Text('ঠিক আছে'),
          ),
        ],
      ),
    );
    if (r != null && r > 0) setState(() => _amount = r);
  }

  Future<void> _editDate() async {
    _q.stop();
    final now = BrainScope.read(context).services.now();
    final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: now.add(const Duration(days: 3650)));
    if (d != null) setState(() => _date = d);
  }

  Future<void> _editKind() async {
    _q.stop();
    final r = await showModalBottomSheet<LedgerKind>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final k in LedgerKind.values)
              ListTile(
                title: Text(k.label, style: body(16, weight: FontWeight.w600)),
                subtitle: Text(k.hint),
                trailing: k == _kind ? const Icon(Icons.check_rounded, color: C.green) : null,
                onTap: () => Navigator.pop(ctx, k),
              ),
          ],
        ),
      ),
    );
    if (r != null) setState(() => _kind = r);
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final now = brain.services.now();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: _needName || _needAmount || _kind == null ? 'একটু জানতে চাই' : 'ঠিক বুঝেছি তো?', close: true),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Bubble(label: 'আপনি বললেন', text: widget.command.transcript.trim()),
                  const SizedBox(height: 16),
                  if (_needName)
                    ..._askName(brain)
                  else if (_needAmount)
                    ..._askAmount()
                  else if (_kind == null)
                    ..._clarify(brain)
                  else
                    ..._details(brain, now),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                children: [
                  if (_needName)
                    PrimaryButton(label: 'এগিয়ে যান', onPressed: () => _setName(_nameCtl.text))
                  else if (_needAmount)
                    PrimaryButton(label: 'এগিয়ে যান', onPressed: () => _setAmount(int.tryParse(asciiDigits(_amountCtl.text).replaceAll(RegExp(r'[,\s৳]'), ''))))
                  else if (_kind == null)
                    PrimaryButton(
                      label: _picked == null ? 'একটি বেছে নিন' : 'এগিয়ে যান',
                      onPressed: _picked == null ? null : _proceed,
                    )
                  else
                    PrimaryButton(label: 'হ্যাঁ, সেভ করুন', icon: Icons.check_rounded, onPressed: _saving ? null : _save),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'আবার বলুন',
                          icon: Icons.mic_none_rounded,
                          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const VoiceScreen())),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: SecondaryButton(label: 'বাতিল', onPressed: () => Navigator.of(context).pop())),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ListeningStrip(
                    q: _q,
                    prompt: _needName
                        ? 'নামটা মুখে বলেও দিতে পারেন'
                        : _needAmount
                            ? 'অঙ্কটা মুখে বলেও দিতে পারেন'
                            : _kind == null
                                ? 'বলেও বেছে নিতে পারেন — যেমন “শোধ” বা “নতুন ধার”'
                                : 'মুখে “হ্যাঁ” বা “না” বললেও হবে',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _askName(Brain brain) {
    final known = knownPeople(brain.data.ledger).take(8).toList();
    return [
      Text('কার সাথে লেনদেন?', style: display(26)),
      const SizedBox(height: 6),
      Text(
        _amount > 0
            ? '${taka(_amount)}-এর কথা বললেন। টাকার সব হিসাব লেনদেনের খাতায় থাকে — কার সাথে, সেটা জানালে লিখে রাখব।'
            : 'টাকার সব হিসাব লেনদেনের খাতায় থাকে — কার সাথে, সেটা জানালে লিখে রাখব।',
        style: body(15, color: C.muted, height: 1.5),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _nameCtl,
        textInputAction: TextInputAction.done,
        onSubmitted: _setName,
        onTap: _q.stop,
        decoration: const InputDecoration(labelText: 'নাম'),
      ),
      if (known.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final k in known)
            ActionChip(label: Text(k, style: body(14)), backgroundColor: C.surface, side: const BorderSide(color: C.border), onPressed: () => _setName(k)),
        ]),
      ],
      if (widget.command.allowExpense) ...[
        const SizedBox(height: 12),
        TextButton(
          onPressed: () {
            _picked = 'expense';
            _proceed();
          },
          child: Text('কারও সাথে নয়, নিজের খরচ', style: body(14, weight: FontWeight.w600, color: C.muted2)),
        ),
      ],
    ];
  }

  List<Widget> _askAmount() => [
        Text('কত টাকা?', style: display(26)),
        const SizedBox(height: 14),
        TextField(
          controller: _amountCtl,
          keyboardType: TextInputType.number,
          onTap: _q.stop,
          style: display(22),
          decoration: const InputDecoration(labelText: 'পরিমাণ (৳)'),
        ),
      ];

  List<Widget> _clarify(Brain brain) {
    final bal = balanceWith(brain.data.ledger, _person);
    final choices = <(String, String, String, bool)>[];
    for (final k in widget.command.options) {
      final after = bal + k.signed(_amount);
      final sub = switch (k) {
        LedgerKind.repaid => '${toPerson(_person)} দেবেন ${taka(-bal)} → ${after < 0 ? taka(-after) : '৳০'}',
        LedgerKind.lent => '$_person পরে এটা ফেরত দেবেন',
        LedgerKind.received => '${possessive(_person)} কাছে পাওনা ${taka(bal)} → ${taka(after > 0 ? after : 0)}',
        LedgerKind.borrowed => 'আপনি পরে ${toPerson(_person)} ফেরত দেবেন',
      };
      final title = switch (k) {
        LedgerKind.repaid => 'আগের দেনা শোধ করলাম',
        LedgerKind.lent => 'নতুন করে ধার দিলাম',
        LedgerKind.received => 'আগের পাওনা ফেরত পেলাম',
        LedgerKind.borrowed => 'নতুন করে ধার নিলাম',
      };
      choices.add((k.name, title, sub, k == widget.command.suggested));
    }
    if (widget.command.allowExpense) choices.add(('expense', 'অন্য খরচ', 'লেনদেনের খাতায় যোগ হবে না', false));

    return [
      Text('এটা কোন ধরনের লেনদেন?', style: display(26)),
      const SizedBox(height: 6),
      Text(
        bal == 0
            ? 'ঠিক না জেনে কিছু লিখব না।'
            : 'ঠিক না জেনে কিছু লিখব না। খাতায় এখন ${owesText(_person, bal)}।',
        style: body(15, color: C.muted, height: 1.5),
      ),
      const SizedBox(height: 14),
      for (final c in choices) ...[
        _Choice(
          title: c.$2,
          sub: c.$3,
          likely: c.$4,
          selected: _picked == c.$1,
          onTap: () {
            _q.stop();
            setState(() => _picked = c.$1);
          },
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 4),
      SpokenLine(_clarifyQuestion()),
    ];
  }

  List<Widget> _details(Brain brain, DateTime now) {
    final kind = _kind!;
    final before = balanceWith(brain.data.ledger, _person);
    final after = before + kind.signed(_amount);
    final (kfg, kbg) = kind.signed(1) > 0 ? (C.greenDark, C.greenTint) : (C.orangeDark, C.orangeTint);
    final personLabel = switch (kind) {
      LedgerKind.lent || LedgerKind.repaid => 'কাকে',
      _ => 'কার কাছ থেকে',
    };

    Widget row(String label, Widget value, VoidCallback onEdit) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(label, style: body(15, color: C.muted))),
              value,
              TextButton(
                onPressed: onEdit,
                style: TextButton.styleFrom(minimumSize: const Size(56, 40)),
                child: Text('বদলান', style: body(14, weight: FontWeight.w600, color: C.green)),
              ),
            ],
          ),
        );

    return [
      Panel(
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('যা বুঝলাম', style: body(14, weight: FontWeight.w600, color: C.muted)),
            row('ধরন', Pill(kind.label, fg: kfg, bg: kbg), _editKind),
            const Divider(),
            row(personLabel, Text(_person, style: body(17, weight: FontWeight.w600)), _editPerson),
            const Divider(),
            row('পরিমাণ', Text(taka(_amount), style: display(22, weight: 700)), _editAmount),
            const Divider(),
            row('তারিখ', Text(dayOnly(_date) == dayOnly(now) ? 'আজ, ${shortDate(_date)}' : fullDate(_date), style: body(16, weight: FontWeight.w500)), _editDate),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: after < 0 ? C.orangeTint : C.greenTint, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${possessive(_person)} হিসাব', style: body(14, weight: FontWeight.w600, color: after < 0 ? C.orangeDark : C.greenDark)),
            const SizedBox(height: 8),
            Row(
              children: [
                Flexible(child: _BalanceLabel(title: 'আগে ${balanceWords(_person, before)}', amount: before, strike: true)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_forward_rounded, color: C.ink)),
                Flexible(child: _BalanceLabel(title: 'এখন ${balanceWords(_person, after)}', amount: after, strike: false)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SpokenLine(confirmQuestion(kind, _person, _amount)),
    ];
  }
}

class _BalanceLabel extends StatelessWidget {
  const _BalanceLabel({required this.title, required this.amount, required this.strike});
  final String title;
  final int amount;
  final bool strike;

  @override
  Widget build(BuildContext context) {
    final color = strike ? C.muted2 : balanceColor(amount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: body(13, color: strike ? C.muted2 : C.ink, weight: strike ? FontWeight.w400 : FontWeight.w600)),
        Text(
          taka(amount),
          style: display(strike ? 22 : 30, weight: strike ? 600 : 700, color: color).copyWith(decoration: strike ? TextDecoration.lineThrough : null),
        ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.title, required this.sub, required this.likely, required this.selected, required this.onTap});
  final String title;
  final String sub;
  final bool likely;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: selected ? C.greenSoft : C.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: selected ? C.green : C.border, width: selected ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: selected ? C.green : const Color(0xFF9AA39E)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(title, style: body(17, weight: FontWeight.w600)),
                            if (likely) const Pill('সম্ভবত'),
                          ],
                        ),
                        Text(sub, style: body(14, color: C.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
