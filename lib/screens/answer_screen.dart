import 'package:flutter/material.dart';

import '../logic/answers.dart';
import '../logic/bn.dart';
import '../logic/categories.dart';
import '../logic/ledger.dart';
import '../logic/parser.dart';
import '../logic/search.dart';
import '../logic/talk.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../ui/yes_no.dart';
import 'new_item_screen.dart';
import 'person_screen.dart';
import 'reminders_screen.dart';
import 'vault_item_screen.dart';
import 'voice_screen.dart';

/// The answer to a question (or a note to keep), shown and spoken.
class AnswerScreen extends StatefulWidget {
  const AnswerScreen({super.key, required this.command});
  final Command command;

  @override
  State<AnswerScreen> createState() => _AnswerScreenState();
}

class _Answer {
  _Answer(this.text, {this.items = const [], this.secure = false, this.actions = const [], String? say}) : say = say ?? speakableNumbers(text);

  /// What is spoken (phone numbers read digit by digit).
  final String say;

  /// Shown and spoken.
  final String text;
  final List<Widget> items;

  /// Vault answers: the items stay closed until the user verifies.
  final bool secure;
  final List<Widget> actions;
}

class _AnswerScreenState extends State<AnswerScreen> {
  late _Answer _answer;
  bool _noteSaved = false;
  CategoryGuess? _category;
  late final SpokenQuestion _q;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brain = BrainScope.of(context);
    final cmd = widget.command;
    if (cmd is NoteAdd && _category == null) {
      final ai = cmd.category;
      _category = ai == null ? guessCategory(brain.data, cmd.text) : CategoryGuess(ai, isNew: !brain.data.noteCategories.contains(ai));
    }
    _answer = _build(brain);
  }

  @override
  void initState() {
    super.initState();
    _q = SpokenQuestion(voice: BrainScope.read(context).services.voice, onAnswer: _onAnswer);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.command is NoteAdd) {
        _q.ask(_answer.say);
      } else {
        _speak();
      }
    });
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _speak() => BrainScope.read(context).services.voice.speak(_answer.say);

  void _onAnswer(String heard) {
    final cmd = widget.command;
    if (cmd is! NoteAdd || _noteSaved) return;
    switch (yesNo(heard)) {
      case true:
        _saveNote(cmd);
      case false:
        _q.stop();
        toast(context, 'ঠিক আছে, রাখা হয়নি');
        Navigator.of(context).pop();
      case null:
        setState(() => _q.hint = 'বুঝিনি। “হ্যাঁ” বা “না” বলুন, অথবা বোতাম চাপুন।');
    }
  }

  Future<void> _changeCategory() async {
    _q.stop();
    final brain = BrainScope.read(context);
    final c = TextEditingController();
    final existing = brain.data.noteCategories;
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('কোন বিভাগে রাখব?', style: display(20)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in {...existing, defaultNoteCategory}) ActionChip(label: Text(e), onPressed: () => Navigator.pop(ctx, e)),
          ]),
          const SizedBox(height: 12),
          TextField(controller: c, decoration: const InputDecoration(labelText: 'অথবা নতুন বিভাগের নাম')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('বাতিল')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('ঠিক আছে')),
        ],
      ),
    );
    if (r == null || r.isEmpty || !mounted) return;
    setState(() {
      _category = CategoryGuess(r, isNew: !existing.contains(r));
      _answer = _build(brain);
    });
  }

  void _push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Future<void> _openVault(VaultItem v) async {
    final ok = await verifyUser(context, reason: '${v.name} — তথ্য দেখতে যাচাই করুন');
    if (ok && mounted) _push(VaultItemScreen(id: v.id));
  }

  _Answer _build(Brain brain) {
    final d = brain.data;
    final now = brain.services.now();
    final cmd = widget.command;
    switch (cmd) {
      case LedgerQuery():
        return _ledger(d, cmd);
      case VaultQuery():
        final text = vaultAnswer(d, cmd);
        if (d.vault.isEmpty) {
          return _Answer(text, actions: [
            PrimaryButton(
              label: 'নতুন পাসওয়ার্ড যোগ করুন',
              icon: Icons.add_rounded,
              onPressed: () => _push(NewItemScreen(category: ItemCategory.password, presetTitle: cmd.terms.join(' '))),
            ),
          ]);
        }
        return _Answer(text, secure: true, items: [for (final v in vaultAnswerItems(d, cmd)) _vaultRow(v)]);
      case ReminderQuery():
        final found = searchReminders(d, cmd.terms);
        final text = reminderAnswer(d, cmd, now);
        if (found.isEmpty) {
          return _Answer(text, actions: [
            PrimaryButton(
              label: 'নতুন রিমাইন্ডার',
              icon: Icons.add_rounded,
              onPressed: () => _push(NewItemScreen(category: ItemCategory.reminder, presetTitle: cmd.terms.join(' '))),
            ),
          ]);
        }
        return _Answer(text, items: [
          for (final x in found)
            ListRow(
              leading: DateBlock(top: bnDigits(x.nextDate(now).day), bottom: bnMonthsShort[x.nextDate(now).month - 1]),
              title: x.title,
              subtitle: '${weekdayName(x.nextDate(now))} · ${daysLeftLabel(x.nextDate(now), now)}',
              onTap: () => _push(RemindersScreen(highlightId: x.id)),
            ),
        ]);
      case NoteAdd():
        final cat = _category ?? const CategoryGuess(defaultNoteCategory, isNew: false);
        final question = _noteSaved
            ? 'ঠিক আছে, ‘${cat.name}’ বিভাগে রেখে দিলাম।'
            : cmd.fromStatement
                ? (cat.isNew
                    ? 'এটা আগের কোনো কিছুর সাথে মেলে না। ‘${cat.name}’ নামে নতুন বিভাগ খুলে রেখে দিই?'
                    : 'এটা ‘${cat.name}’ বিভাগে রেখে দিই?')
                : (cat.isNew ? '‘${cat.name}’ নামে নতুন বিভাগ খুলে লিখে রাখি?' : '‘${cat.name}’ বিভাগে লিখে রাখি?');
        return _Answer(question, items: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 8), child: Text(cmd.text, style: body(17, height: 1.5))),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Text('বিভাগ:', style: body(14, color: C.muted)),
                ActionChip(
                  avatar: const Icon(Icons.folder_outlined, size: 18, color: C.ochre),
                  label: Text(cat.name, style: body(14, weight: FontWeight.w600)),
                  backgroundColor: C.ochreTint,
                  side: BorderSide.none,
                  onPressed: _noteSaved ? null : _changeCategory,
                ),
                if (cat.isNew && !_noteSaved) const Pill('নতুন বিভাগ', fg: C.ochre, bg: C.ochreTint),
                if (!_noteSaved) TextButton(onPressed: _changeCategory, child: Text('বদলান', style: body(14, weight: FontWeight.w600, color: C.green))),
              ],
            ),
          ),
        ]);
      case SearchQuery():
        final hits = searchAll(d, cmd.terms);
        final text = searchAnswer(d, cmd, now);
        if (hits.isEmpty) {
          return _Answer(text, actions: [
            PrimaryButton(label: 'নতুন তথ্য যোগ করুন', icon: Icons.add_rounded, onPressed: () => _push(const NewItemScreen())),
          ]);
        }
        return _Answer(text, secure: hits.first is VaultHit, items: [for (final h in hits.take(12)) _hitRow(h, now)]);
      case SmallTalk():
        return _Answer(talkReply(cmd.kind, now), actions: [
          if (cmd.kind == Talk.whatCanYouDo || cmd.kind == Talk.greeting || cmd.kind == Talk.whoAreYou)
            PrimaryButton(
              label: 'বলে শুরু করুন',
              icon: Icons.mic_none_rounded,
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const VoiceScreen())),
            ),
        ]);
      case AiReply():
        return _Answer(cmd.text);
      case TaskQuery():
      case CashQuery():
      case Briefing():
        return _Answer(answerText(d, cmd, now) ?? '');
      case LedgerAdd():
      case LedgerSet():
      case TaskAdd():
      case TaskDone():
      case ReminderAdd():
      case ContactAdd():
      case CallPerson():
      case CashAdd():
      case VaultAdd():
      case NotUnderstood():
        return _Answer('দুঃখিত, ঠিক বুঝতে পারিনি। একটু অন্যভাবে আরেকবার বলবেন?');
    }
  }

  Widget _vaultRow(VaultItem v) => ListRow(
        leading: _VaultIcon(kind: v.kind),
        title: v.name,
        subtitle: v.kind.label,
        trailing: const Icon(Icons.lock_outline_rounded, color: C.muted),
        onTap: () => _openVault(v),
      );

  Widget _hitRow(Hit h, DateTime now) => switch (h) {
        VaultHit(:final item) => ListRow(
            leading: _VaultIcon(kind: item.kind),
            title: item.name,
            subtitle: 'পাসওয়ার্ড · ${item.kind.label}',
            trailing: const Icon(Icons.lock_outline_rounded, color: C.muted),
            onTap: () => _openVault(item),
          ),
        ContactHit(:final contact) => ListRow(
            leading: Avatar(name: contact.name, fg: C.purple, bg: C.purpleTint),
            title: contact.name,
            subtitle: contact.phone.isNotEmpty ? bnDigits(contact.phone) : 'যোগাযোগ',
            onTap: () => _push(NewItemScreen(contact: contact)),
          ),
        NoteHit(:final note) => ListRow(
            leading: const _SmallIcon(icon: Icons.description_outlined, fg: C.ochre, bg: C.ochreTint),
            title: note.title,
            subtitle: note.body.replaceAll('\n', ' '),
            onTap: () => _push(NewItemScreen(note: note)),
          ),
        ReminderHit(:final reminder) => ListRow(
            leading: DateBlock(top: bnDigits(reminder.nextDate(now).day), bottom: bnMonthsShort[reminder.nextDate(now).month - 1]),
            title: reminder.title,
            subtitle: daysLeftLabel(reminder.nextDate(now), now),
            onTap: () => _push(RemindersScreen(highlightId: reminder.id)),
          ),
        PersonHit(:final person) => ListRow(
            leading: Avatar(name: person),
            title: person,
            subtitle: 'লেনদেন',
            onTap: () => _push(PersonScreen(person: person)),
          ),
      };

  _Answer _ledger(AppData d, LedgerQuery q) {
    final all = balances(d.ledger);
    Widget row(PersonBalance p, String sub) {
      final (fg, bg) = balanceColors(p.balance);
      return ListRow(
        leading: Avatar(name: p.name, fg: fg, bg: bg),
        title: p.name,
        subtitle: sub,
        trailing: Text(taka(p.balance), style: display(18, color: balanceColor(p.balance))),
        onTap: () => _push(PersonScreen(person: p.name)),
      );
    }

    final text = ledgerAnswer(d, q);
    switch (q.ask) {
      case LedgerAsk.person:
        final p = balanceOf(d.ledger, q.person!);
        return _Answer(text, items: [if (p != null) row(p, '${bnDigits(p.count)}টি লেনদেন')]);
      case LedgerAsk.receivable:
        return _Answer(text, items: [
          for (final p in all.where((p) => p.balance > 0)) row(p, p.last == null ? '' : 'শেষ লেনদেন ${shortDate(p.last!)}'),
        ]);
      case LedgerAsk.payable:
        return _Answer(text, items: [
          for (final p in all.where((p) => p.balance < 0)) row(p, p.last == null ? '' : 'শেষ লেনদেন ${shortDate(p.last!)}'),
        ]);
      case LedgerAsk.all:
        return _Answer(text, items: [
          for (final p in all.where((p) => p.balance != 0)) row(p, p.balance > 0 ? 'পাবেন' : 'দেবেন'),
        ]);
    }
  }

  Future<void> _saveNote(NoteAdd n) async {
    if (_noteSaved) return;
    _q.stop();
    final brain = BrainScope.read(context);
    final cat = _category?.name ?? defaultNoteCategory;
    _noteSaved = true;
    await brain.saveNote(Note(title: noteTitleFrom(n.text), body: n.text, category: cat));
    brain.services.voice.speak('ঠিক আছে, ‘$cat’ বিভাগে রেখে দিলাম।');
    if (!mounted) return;
    setState(() => _answer = _build(brain));
    toast(context, '‘$cat’ বিভাগে রেখে দিলাম');
  }

  @override
  Widget build(BuildContext context) {
    final cmd = widget.command;
    final isNote = cmd is NoteAdd;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const TopBar(title: 'প্রশ্ন ও উত্তর', close: true),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Bubble(label: isNote || cmd is SmallTalk || cmd is AiReply ? 'আপনি বললেন' : 'আপনি জিজ্ঞেস করলেন', text: cmd.transcript.trim()),
                  const SizedBox(height: 16),
                  Panel(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Icon(Icons.volume_up_outlined, size: 18, color: C.green),
                          const SizedBox(width: 6),
                          Text('অ্যাপ বলছে', style: body(13, weight: FontWeight.w600, color: C.green)),
                        ]),
                        const SizedBox(height: 8),
                        Text(_answer.text, style: display(22, height: 1.35)),
                        if (_answer.secure) ...[
                          const SizedBox(height: 6),
                          Text('পাসওয়ার্ড কখনো জোরে পড়ে শোনানো হয় না।', style: body(13, color: C.muted)),
                        ],
                        const SizedBox(height: 8),
                        if (_answer.items.isNotEmpty) ...[
                          const Divider(),
                          Rows(children: _answer.items),
                        ],
                      ],
                    ),
                  ),
                  for (final a in _answer.actions) ...[const SizedBox(height: 12), a],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: isNote && !_noteSaved
                  ? Column(children: [
                      Row(children: [
                        Expanded(child: SecondaryButton(label: 'না', height: 56, onPressed: () => _onAnswer('না'))),
                        const SizedBox(width: 10),
                        Expanded(flex: 2, child: PrimaryButton(label: 'হ্যাঁ, রাখুন', icon: Icons.check_rounded, onPressed: () => _saveNote(cmd))),
                      ]),
                      const SizedBox(height: 10),
                      ListeningStrip(q: _q),
                    ])
                  : Row(children: [
                      Expanded(child: SecondaryButton(label: 'আবার শুনুন', icon: Icons.volume_up_outlined, height: 56, onPressed: _speak)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PrimaryButton(
                          label: 'আরেকটা প্রশ্ন',
                          icon: Icons.mic_none_rounded,
                          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const VoiceScreen())),
                        ),
                      ),
                    ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultIcon extends StatelessWidget {
  const _VaultIcon({required this.kind});
  final VaultKind kind;

  @override
  Widget build(BuildContext context) {
    final l = vaultLook(kind);
    return _SmallIcon(icon: l.icon, fg: l.fg, bg: l.bg);
  }
}

class _SmallIcon extends StatelessWidget {
  const _SmallIcon({required this.icon, required this.fg, required this.bg});
  final IconData icon;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: fg, size: 20),
      );
}
