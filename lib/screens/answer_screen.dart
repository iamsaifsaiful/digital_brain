import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/ledger.dart';
import '../logic/parser.dart';
import '../logic/phrases.dart';
import '../logic/search.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/pin.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
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
  _Answer(this.text, {this.items = const [], this.secure = false, this.actions = const []});

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _answer = _build(BrainScope.of(context));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speak());
  }

  void _speak() => BrainScope.read(context).services.voice.speak(_answer.text);

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
        final found = searchVault(d, cmd.terms, wifiOnly: cmd.wifiOnly);
        if (found.isEmpty) {
          return _Answer(
            cmd.wifiOnly ? 'কোনো Wi-Fi-এর তথ্য রাখা নেই।' : 'এমন কোনো লগইন তথ্য পাইনি।',
            actions: [
              PrimaryButton(
                label: 'নতুন পাসওয়ার্ড যোগ করুন',
                icon: Icons.add_rounded,
                onPressed: () => _push(NewItemScreen(category: ItemCategory.password, presetTitle: cmd.terms.join(' '))),
              ),
            ],
          );
        }
        final first = found.first;
        final text = found.length == 1
            ? '${possessive(first.name)} তথ্য পেয়েছি। এটা সুরক্ষিত — আঙুলের ছাপ দিয়ে খুলুন, তারপর স্ক্রিনে দেখুন।'
            : '${bnDigits(found.length)}টি মিলেছে। যেটা দরকার সেটা খুলুন — খুলতে আঙুলের ছাপ বা PIN লাগবে।';
        return _Answer(text, secure: true, items: [
          for (final v in found)
            ListRow(
              leading: _VaultIcon(kind: v.kind),
              title: v.name,
              subtitle: v.kind.label,
              trailing: const Icon(Icons.lock_outline_rounded, color: C.muted),
              onTap: () => _openVault(v),
            ),
        ]);
      case ReminderQuery():
        final found = searchReminders(d, cmd.terms);
        if (found.isEmpty) {
          return _Answer('এমন কোনো তারিখ রাখা নেই। নতুন রিমাইন্ডার যোগ করবেন?', actions: [
            PrimaryButton(
              label: 'নতুন রিমাইন্ডার',
              icon: Icons.add_rounded,
              onPressed: () => _push(NewItemScreen(category: ItemCategory.reminder, presetTitle: cmd.terms.join(' '))),
            ),
          ]);
        }
        final r = found.first;
        final day = r.nextDate(now);
        final left = dayOnly(day).difference(dayOnly(now)).inDays;
        final when = left == 0 ? 'আজই' : (left > 0 ? 'আর ${bnDigits(left)} দিন বাকি' : '${bnDigits(-left)} দিন আগে পার হয়েছে');
        return _Answer('${r.title}: ${weekdayName(day)}, ${fullDate(day)}। $when।', items: [
          for (final x in found)
            ListRow(
              leading: DateBlock(top: bnDigits(x.nextDate(now).day), bottom: bnMonthsShort[x.nextDate(now).month - 1]),
              title: x.title,
              subtitle: '${weekdayName(x.nextDate(now))} · ${daysLeftLabel(x.nextDate(now), now)}',
              onTap: () => _push(RemindersScreen(highlightId: x.id)),
            ),
        ]);
      case NoteAdd():
        return _Answer('এটা নোট হিসেবে রাখব?', items: [
          Padding(padding: const EdgeInsets.all(16), child: Text(cmd.text, style: body(17, height: 1.5))),
        ]);
      case SearchQuery():
        final hits = searchAll(d, cmd.terms);
        if (hits.isEmpty) {
          return _Answer('এ নিয়ে কিছু রাখা নেই। নতুন তথ্য হিসেবে যোগ করতে পারেন।', actions: [
            PrimaryButton(label: 'নতুন তথ্য যোগ করুন', icon: Icons.add_rounded, onPressed: () => _push(const NewItemScreen())),
          ]);
        }
        return _Answer('${bnDigits(hits.length)}টি জিনিস পেয়েছি।', secure: hits.any((h) => h is VaultHit), items: [for (final h in hits.take(12)) _hitRow(h, now)]);
      case LedgerAdd():
      case NotUnderstood():
        return _Answer('ঠিক বুঝতে পারিনি।');
    }
  }

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
            subtitle: 'ধার-দেনা',
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

    switch (q.ask) {
      case LedgerAsk.person:
        final p = balanceOf(d.ledger, q.person!);
        if (p == null) return _Answer('${possessive(q.person!)} সাথে কোনো হিসাব নেই।');
        final hist = runningFor(d.ledger, p.name);
        final last = hist.isEmpty ? null : hist.last.$1;
        final lastText = last == null ? '' : ' শেষ লেনদেন ${shortDate(last.date)}: ${last.kind.label} ${taka(last.amount)}।';
        return _Answer('${balanceSentence(p.name, p.balance).replaceFirst('এখন ', '')}$lastText', items: [row(p, '${bnDigits(p.count)}টি লেনদেন')]);
      case LedgerAsk.receivable:
        final owe = all.where((p) => p.balance > 0).toList();
        if (owe.isEmpty) return _Answer('এখন কারো কাছে আপনার কোনো পাওনা নেই।');
        final sum = owe.fold<int>(0, (s, p) => s + p.balance);
        return _Answer('আপনি ${bnDigits(owe.length)} জনের কাছে মোট ${bnNumber(sum)} টাকা পাবেন।', items: [
          for (final p in owe) row(p, p.last == null ? '' : 'শেষ লেনদেন ${shortDate(p.last!)}'),
        ]);
      case LedgerAsk.payable:
        final iOwe = all.where((p) => p.balance < 0).toList();
        if (iOwe.isEmpty) return _Answer('এখন কাউকে আপনার কিছু দিতে হবে না।');
        final sum = iOwe.fold<int>(0, (s, p) => s - p.balance);
        return _Answer('আপনাকে ${bnDigits(iOwe.length)} জনকে মোট ${bnNumber(sum)} টাকা দিতে হবে।', items: [
          for (final p in iOwe) row(p, p.last == null ? '' : 'শেষ লেনদেন ${shortDate(p.last!)}'),
        ]);
      case LedgerAsk.all:
        final t = totals(d.ledger);
        return _Answer('আপনি মোট ${bnNumber(t.receivable)} টাকা পাবেন, আর ${bnNumber(t.payable)} টাকা দেবেন।', items: [
          for (final p in all.where((p) => p.balance != 0)) row(p, p.balance > 0 ? 'পাবেন' : 'দেবেন'),
        ]);
    }
  }

  Future<void> _saveNote(NoteAdd n) async {
    final brain = BrainScope.read(context);
    final words = n.text.split(RegExp(r'\s+'));
    final title = words.take(5).join(' ') + (words.length > 5 ? '…' : '');
    await brain.saveNote(Note(title: title, body: n.text));
    await brain.services.voice.speak('নোট রাখা হয়েছে।');
    if (!mounted) return;
    setState(() => _noteSaved = true);
    toast(context, 'নোট রাখা হয়েছে');
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
                  Bubble(label: isNote ? 'আপনি বললেন' : 'আপনি জিজ্ঞেস করলেন', text: cmd.transcript.trim()),
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
                  ? Row(children: [
                      Expanded(child: SecondaryButton(label: 'বাতিল', height: 56, onPressed: () => Navigator.of(context).pop())),
                      const SizedBox(width: 10),
                      Expanded(child: PrimaryButton(label: 'নোট রাখুন', icon: Icons.check_rounded, onPressed: () => _saveNote(cmd))),
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
