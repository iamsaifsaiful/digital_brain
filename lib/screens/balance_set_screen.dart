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

/// "ইসমাইলের কাছে আমি ৫ হাজার টাকা পাই": a stated balance. For someone new
/// it asks to open their account with that amount; for someone known it asks
/// to bring the account to that total. Saves only on হ্যাঁ.
class BalanceSetScreen extends StatefulWidget {
  const BalanceSetScreen({super.key, required this.command});
  final LedgerSet command;

  @override
  State<BalanceSetScreen> createState() => _BalanceSetScreenState();
}

class _BalanceSetScreenState extends State<BalanceSetScreen> {
  late final SpokenQuestion _q;
  bool _saving = false;
  late final int _current;
  late final bool _isNew;

  String get _person => widget.command.person;
  int get _target => widget.command.balance;
  int get _diff => _target - _current;

  @override
  void initState() {
    super.initState();
    final brain = BrainScope.read(context);
    final p = balanceOf(brain.data.ledger, _person);
    _isNew = p == null;
    _current = p?.balance ?? 0;
    _q = SpokenQuestion(voice: brain.services.voice, onAnswer: _onAnswer);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_diff == 0) {
        brain.services.voice.speak('খাতায় তো এটাই লেখা আছে — ${owesText(_person, _current)}। নতুন করে কিছু লাগবে না।');
      } else {
        _q.ask(_question());
      }
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String _owes(int bal) => bal >= 0 ? '${possessive(_person)} কাছে আপনার ${bnNumber(bal)} টাকা পাওনা' : '${toPerson(_person)} আপনার ${bnNumber(-bal)} টাকা দিতে হবে';

  String _question() {
    if (_isNew) {
      return '$_person নামে তো কারও হিসাব নেই। নতুন করে খুলে লিখে রাখি যে ${_owes(_target)}?';
    }
    return 'খাতায় এখন লেখা আছে, ${_owes(_current)}। মিলিয়ে লিখে রাখি যে ${_owes(_target)}?';
  }

  /// The entry that brings the balance from [_current] to [_target].
  LedgerEntry _entry(DateTime now) {
    final d = _diff;
    final LedgerKind kind;
    if (d > 0) {
      kind = _current < 0 && d <= -_current ? LedgerKind.repaid : LedgerKind.lent;
    } else {
      kind = _current > 0 && -d <= _current ? LedgerKind.received : LedgerKind.borrowed;
    }
    return LedgerEntry(
      person: _person,
      kind: kind,
      amount: d.abs(),
      date: dayOnly(now),
      note: _isNew ? 'শুরুর হিসাব' : 'হিসাব মিলানো: মোট ${taka(_target)} ${_target >= 0 ? 'পাবেন' : 'দেবেন'}',
    );
  }

  void _onAnswer(String heard) {
    switch (yesNo(heard)) {
      case true:
        _save();
      case false:
        _q.stop();
        toast(context, 'আচ্ছা, কিছু লিখিনি');
        Navigator.of(context).pop();
      case null:
        setState(() => _q.hint = 'বুঝিনি। “হ্যাঁ” বা “না” বলুন, অথবা বোতাম চাপুন।');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    _q.stop();
    setState(() => _saving = true);
    final brain = BrainScope.read(context);
    await brain.saveEntry(_entry(brain.services.now()));
    brain.services.voice.speak('ঠিক আছে, লিখে রাখলাম। ${balanceSentence(_person, _target)}');
    if (!mounted) return;
    toast(context, 'লিখে রাখলাম। ${balanceSentence(_person, _target)}');
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => PersonScreen(person: _person)));
  }

  @override
  Widget build(BuildContext context) {
    final same = _diff == 0;
    final (fg, bg) = balanceColors(_target);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: same ? 'হিসাব মিলে আছে' : (_isNew ? 'নতুন হিসাব যোগ করব?' : 'হিসাব মিলিয়ে নেব?'), close: true),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Bubble(label: 'আপনি বললেন', text: widget.command.transcript.trim()),
                  const SizedBox(height: 16),
                  Panel(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Avatar(name: _person, fg: fg, bg: bg, size: 48),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_person, style: display(22)),
                              Text(_isNew ? 'লেনদেনে নতুন ব্যক্তি' : 'আগে থেকে হিসাব আছে', style: body(14, color: C.muted)),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
                          child: Row(children: [
                            if (!_isNew && !same) ...[
                              Flexible(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('এখন ${balanceWords(_person, _current)}', style: body(13, color: C.muted2)),
                                  Text(taka(_current), style: display(20, color: C.muted2).copyWith(decoration: TextDecoration.lineThrough)),
                                ]),
                              ),
                              const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.arrow_forward_rounded)),
                            ],
                            Flexible(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(balanceHeading(_person, _target), style: body(13, weight: FontWeight.w600, color: _target < 0 ? C.orangeDark : C.greenDark)),
                                Text(taka(_target), style: display(30, weight: 700, color: fg)),
                              ]),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SpokenLine(same ? 'হিসাব আগে থেকেই মিলে আছে, কিছু যোগ করতে হবে না।' : _question()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: same
                  ? PrimaryButton(label: 'ঠিক আছে', onPressed: () => Navigator.of(context).pop())
                  : Column(children: [
                      Row(children: [
                        Expanded(child: SecondaryButton(label: 'না', height: 56, onPressed: () => _onAnswer('না'))),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: PrimaryButton(label: 'হ্যাঁ, যোগ করুন', icon: Icons.check_rounded, onPressed: _saving ? null : _save)),
                      ]),
                      const SizedBox(height: 10),
                      ListeningStrip(q: _q),
                    ]),
            ),
          ],
        ),
      ),
    );
  }
}
