/// বকেয়া inside one of the অন্যান্য হিসাব (owner, 23 Oct: keep it simple):
/// who, what they took or why, how much, the pay day (a reminder). Giving
/// on credit is not আয় or ব্যয়; the money collected is আয়. Each line is a
/// loan entry tagged with the project, so it is on the person's page too.
library;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import 'to_main.dart';
import '../logic/cash.dart' show mainAddedText;
import '../logic/lang.dart';
import '../logic/ledger.dart';
import '../logic/pro.dart';
import '../models/models.dart';
import '../state/brain.dart';
import '../ui/pro_gate.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Category of the আয় a collected বকেয়া makes (and the ব্যয় of one paid).
const dueInCategory = 'বকেয়া আদায়';
const dueOutCategory = 'বকেয়া শোধ';

bool _isDue(LedgerEntry e) => e.kind == LedgerKind.lent || e.kind == LedgerKind.borrowed;

String dueKindLabel(LedgerKind k) => switch (k) {
      LedgerKind.lent => tr('বকেয়া পাবো'),
      LedgerKind.received => tr('বকেয়া আদায়'),
      LedgerKind.borrowed => tr('বকেয়া দেবো'),
      LedgerKind.repaid => tr('বকেয়া শোধ'),
    };

int _money(String s) => int.tryParse(asciiDigits(s).replaceAll(RegExp(r'[,\s৳]'), '')) ?? 0;

/// A new বকেয়া in [project]: who, what they took (or why), how much, and
/// when they will pay — that day brings a reminder. Not আয় or ব্যয়: only
/// the money, when it comes, is আয়.
Future<void> dueForm(BuildContext context, Project project, {String person = '', bool iOwe = false}) async {
  // অন্যান্য হিসাব is premium (owner, 24 Oct).
  if (!await needPro(context, ProFeature.projects) || !context.mounted) return;
  final brain = BrainScope.read(context);
  final name = TextEditingController(text: person);
  final what = TextEditingController();
  final money = TextEditingController();
  DateTime? due;
  var owe = iOwe;
  final known = [for (final p in projectDues(brain.data, project.id)) p.name];
  final ok = await showAppSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(trf('বকেয়া · {0}', [project.name]), style: display(19, weight: 700)),
            const SizedBox(height: 12),
            // Like ধার-দেনা: they owe me, or I owe them.
            SegTabs<bool>(
              items: [(false, tr('আমি পাবো')), (true, tr('আমি দেবো'))],
              value: owe,
              onChanged: (v) => setS(() => owe = v),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('due-person'),
              controller: name,
              autofocus: person.isEmpty,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: owe ? tr('কাকে দেবো (নাম)') : tr('কার কাছে (নাম)')),
            ),
            if (person.isEmpty && known.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final n in known.take(8)) ActionChip(label: Text(n), onPressed: () => setS(() => name.text = n)),
              ]),
            ],
            const SizedBox(height: 10),
            TextField(key: const Key('due-what'), controller: what, decoration: InputDecoration(labelText: owe ? tr('কী নিয়েছি বা কেন বকেয়া') : tr('কী নিয়েছে বা কেন বকেয়া'))),
            const SizedBox(height: 10),
            TextField(key: const Key('due-amount'), controller: money, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('টাকা'), prefixText: '৳ ')),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const Key('due-date'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), alignment: Alignment.centerLeft),
              onPressed: () async {
                final now = brain.services.now();
                final d = await showDatePicker(context: ctx, initialDate: due ?? now.add(const Duration(days: 7)), firstDate: dayOnly(now), lastDate: now.add(const Duration(days: 3650)));
                if (d != null) setS(() => due = d);
              },
              icon: const Icon(Icons.event_outlined),
              label: Text(due == null ? tr('পরিশোধের তারিখ (ঐচ্ছিক)') : trf('পরিশোধের তারিখ: {0}', [fullDate(due!)]), style: body(15)),
            ),
            if (due != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    brain.has(ProFeature.dueReminders) ? tr('আগের দিন আর সেদিন সকাল ১০টায় মনে করিয়ে দেবো।') : tr('তারিখ রাখা থাকবে; মনে করিয়ে দেওয়া প্রিমিয়ামে।'),
                    style: body(13, color: C.muted)),
              ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: tr('রাখুন'),
              icon: Icons.check_rounded,
              onPressed: () {
                if (name.text.trim().isEmpty) {
                  toast(ctx, tr('নাম লিখুন'));
                  return;
                }
                if (_money(money.text) <= 0) {
                  toast(ctx, tr('টাকার অঙ্ক দিন'));
                  return;
                }
                Navigator.pop(ctx, true);
              },
            ),
          ]),
        ),
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final who = name.text.trim();
  if (!await needPro(context, ProFeature.people, allowed: brain.canAddPerson(who)) || !context.mounted) return;
  final now = brain.services.now();
  final entry = LedgerEntry(person: who, kind: owe ? LedgerKind.borrowed : LedgerKind.lent, amount: _money(money.text), date: dayOnly(now), note: what.text.trim(), due: due, projectId: project.id);
  await brain.saveEntry(entry);
  if (!context.mounted) return;
  final left = _balanceOf(brain, project, who);
  toast(context, left >= 0 ? trf('রাখা হয়েছে। {0} এর কাছে বকেয়া {1}', [who, taka(left)]) : trf('রাখা হয়েছে। {0} কে দিতে হবে {1}', [who, taka(-left)]));
}

int _balanceOf(Brain brain, Project project, String who) =>
    projectDues(brain.data, project.id).where((p) => personKey(p.name) == personKey(who)).firstOrNull?.balance ?? 0;

/// [person] paid (some of) their বকেয়া — or, [iPay], the user paid theirs.
/// The বকেয়া goes down and the money is আয় (or ব্যয়) of [project]. Paid
/// in full, the pay-day reminders go.
Future<void> collectDue(BuildContext context, Project project, String person, int owed, {bool iPay = false}) async {
  // অন্যান্য হিসাব is premium (owner, 24 Oct).
  if (!await needPro(context, ProFeature.projects) || !context.mounted) return;
  final brain = BrainScope.read(context);
  final money = TextEditingController(text: owed > 0 ? '$owed' : '');
  final ok = await showAppSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(iPay ? trf('{0} কে বকেয়া দিলাম', [person]) : trf('{0} বকেয়া দিলেন', [person]), style: display(19, weight: 700)),
        const SizedBox(height: 4),
        Text(iPay ? trf('দেওয়ার ছিল {0}। যত দিলেন, লিখুন — ব্যয়ে যোগ হবে।', [taka(owed)]) : trf('বাকি ছিল {0}। যত পেলেন, লিখুন — আয়ে যোগ হবে।', [taka(owed)]),
            style: body(14, color: C.muted)),
        const SizedBox(height: 12),
        TextField(key: const Key('due-amount'), controller: money, autofocus: true, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: tr('টাকা'), prefixText: '৳ ')),
        const SizedBox(height: 14),
        PrimaryButton(
          label: tr('রাখুন'),
          icon: Icons.check_rounded,
          onPressed: () {
            if (_money(money.text) <= 0) {
              toast(ctx, tr('টাকার অঙ্ক দিন'));
              return;
            }
            Navigator.pop(ctx, true);
          },
        ),
      ]),
    ),
  );
  if (ok != true || !context.mounted) return;
  final n = _money(money.text);
  final now = brain.services.now();
  await brain.saveEntry(LedgerEntry(person: person, kind: iPay ? LedgerKind.repaid : LedgerKind.received, amount: n, date: dayOnly(now), note: tr(iPay ? dueOutCategory : dueInCategory), projectId: project.id));
  final paid = CashEntry(kind: iPay ? CashKind.expense : CashKind.income, amount: n, category: tr(iPay ? dueOutCategory : dueInCategory), note: person, date: now, projectId: project.id);
  await brain.saveCash(paid);
  final main = brain.lastMainLine;
  final left = _balanceOf(brain, project, person);
  if (iPay ? left >= 0 : left <= 0) {
    for (final e in [...brain.data.ledger]) {
      if (e.projectId == project.id && personKey(e.person) == personKey(person) && e.due != null) await brain.saveEntry(e.copyWith(clearDue: true), guessPhone: false);
    }
  }
  if (!context.mounted) return;
  if (iPay) {
    toast(context, (left < 0 ? trf('ব্যয়ে যোগ হলো। {0} কে আরও দিতে হবে {1}', [person, taka(-left)]) : trf('ব্যয়ে যোগ হলো। {0} এর বকেয়া শেষ', [person])) + (main == null ? '' : '\n${mainAddedText(main)}'));
  } else {
    toast(context, (left > 0 ? trf('আয়ে যোগ হলো। {0} এর কাছে আরও বকেয়া {1}', [person, taka(left)]) : trf('আয়ে যোগ হলো। {0} এর বকেয়া শেষ', [person])) + (main == null ? '' : '\n${mainAddedText(main)}'));
  }
}

/// The earliest pay day still ahead among [lines].
DateTime? _nextDue(Iterable<LedgerEntry> lines) {
  DateTime? best;
  for (final e in lines) {
    if ((e.kind == LedgerKind.lent || e.kind == LedgerKind.borrowed) && e.due != null && (best == null || e.due!.isBefore(best))) best = e.due;
  }
  return best;
}

List<LedgerEntry> _linesOf(AppData d, Project project, PersonBalance p) {
  final mine = d.ledger.where((x) => x.projectId == project.id);
  final keys = accountKeys(mine);
  return [for (final e in mine) if (keys[e.id] == p.key) e]..sort((a, b) => b.date.compareTo(a.date));
}

/// One person's বকেয়া lines in [project], with buttons to add more.
Future<void> dueDetails(BuildContext context, Project project, PersonBalance p) async {
  final brain = BrainScope.read(context);
  final lines = _linesOf(brain.data, project, p);
  final action = await showAppSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), children: [
          Text(p.name, style: display(19, weight: 700)),
          const SizedBox(height: 4),
          Text(p.balance > 0 ? trf('বকেয়া পাবো {0}', [taka(p.balance)]) : (p.balance < 0 ? trf('বকেয়া দেবো {0}', [taka(-p.balance)]) : tr('বকেয়া নেই')),
              style: body(16, weight: FontWeight.w600, color: p.balance > 0 ? C.green : (p.balance < 0 ? C.orange : C.muted))),
          const SizedBox(height: 12),
          Row(children: [
            if (p.balance > 0) ...[
              Expanded(child: PrimaryButton(label: tr('আদায় হলো'), icon: Icons.south_west_rounded, height: 46, onPressed: () => Navigator.pop(ctx, 'in'))),
              const SizedBox(width: 8),
            ],
            if (p.balance < 0) ...[
              Expanded(child: PrimaryButton(label: tr('শোধ করলাম'), icon: Icons.north_east_rounded, height: 46, onPressed: () => Navigator.pop(ctx, 'out'))),
              const SizedBox(width: 8),
            ],
            Expanded(child: PrimaryButton(label: tr('আরও'), icon: Icons.add_rounded, height: 46, color: C.fill, onPressed: () => Navigator.pop(ctx, 'more'))),
          ]),
          const SizedBox(height: 14),
          Panel(
            child: Rows(children: [
              for (final e in lines)
                ListRow(
                  leading: Icon(_isDue(e) ? Icons.receipt_long_outlined : Icons.check_circle_outline_rounded, color: e.kind.signed(1) > 0 ? C.green : C.orange),
                  title: _isDue(e) && e.note.trim().isNotEmpty ? e.note.trim() : dueKindLabel(e.kind),
                  subtitle: [
                    if (_isDue(e)) dueKindLabel(e.kind),
                    shortDate(e.date),
                    if (_isDue(e) && e.due != null) trf('পরিশোধ {0}', [shortDate(e.due!)]),
                  ].join(' · ') + mainMark(brain.data, e.id),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(taka(e.amount), style: display(15, color: e.kind.signed(1) > 0 ? C.green : C.orange)),
                    if (mainMenuLine(brain.data, e.id) case final line?)
                      IconButton(
                        key: Key('due-main-${e.id}'),
                        tooltip: line.$1,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(line.$2, color: C.muted, size: 20),
                        onPressed: () => Navigator.pop(ctx, 'main:${e.id}'),
                      ),
                    IconButton(
                      tooltip: tr('মুছুন'),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.delete_outline_rounded, color: C.muted, size: 20),
                      onPressed: () => Navigator.pop(ctx, 'del:${e.id}'),
                    ),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  if (action == 'in') return collectDue(context, project, p.name, p.balance);
  if (action == 'out') return collectDue(context, project, p.name, -p.balance, iPay: true);
  if (action == 'more') return dueForm(context, project, person: p.name, iOwe: p.balance < 0);
  if (action.startsWith('del:')) {
    final ok = await confirmDialog(context, title: tr('মুছবেন?'), text: tr('এই বকেয়ার লাইনটা মুছে যাবে।'), yes: tr('মুছুন'), danger: true);
    if (ok && context.mounted) await brain.deleteEntry(action.substring(4));
  }
  if (action.startsWith('main:')) await toggleMain(context, action.substring(5));
}

/// The বকেয়া part of a project page.
class ProjectDuesSection extends StatelessWidget {
  const ProjectDuesSection({super.key, required this.project});
  final Project project;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final dues = projectDues(brain.data, project.id);
    final (owed, owing) = projectDueTotals(brain.data, project.id);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: SectionTitle(tr('বকেয়া'))),
        TextButton.icon(
          key: const Key('due-add'),
          onPressed: () => dueForm(context, project),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(tr('বকেয়া যোগ')),
        ),
      ]),
      if (dues.isEmpty)
        Panel(
          padding: const EdgeInsets.all(14),
          child: Text(tr('ধার-দেনার মতোই: কেউ বাকিতে নিলে বা আপনি বাকিতে নিলে লিখুন — কে, কী, কত টাকা, কবে শোধ। সেদিন মনে করিয়ে দেবো।'), style: body(14, color: C.muted)),
        )
      else ...[
        Panel(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('আমি পাবো'), style: body(13, color: C.muted)),
                Text(taka(owed), style: display(19, color: C.green)),
              ]),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(tr('আমি দেবো'), style: body(13, color: C.muted)),
                Text(taka(owing), style: display(19, color: C.orange)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Panel(
          child: Rows(children: [
            for (final p in dues)
              () {
                final next = p.balance != 0 ? _nextDue(_linesOf(brain.data, project, p)) : null;
                final late = next != null && dayOnly(next).isBefore(dayOnly(brain.services.now()));
                return ListRow(
                  key: Key('due-${p.key}'),
                  leading: CircleAvatar(
                    backgroundColor: p.balance > 0 ? C.greenTint : (p.balance < 0 ? C.orangeTint : C.chip),
                    child: Text(p.name.isEmpty ? '?' : p.name.characters.first,
                        style: body(15, weight: FontWeight.w700, color: p.balance > 0 ? C.green : (p.balance < 0 ? C.orange : C.muted))),
                  ),
                  title: p.name,
                  subtitle: next != null
                      ? (late ? trf('পরিশোধের দিন পেরিয়েছে ({0})', [shortDate(next)]) : trf('পরিশোধ {0}', [shortDate(next)]))
                      : (p.last == null ? null : trf('শেষ লেনদেন {0}', [shortDate(p.last!)])),
                  trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                    Text(taka(p.balance.abs()), style: display(16, color: p.balance > 0 ? (late ? C.red : C.green) : (p.balance < 0 ? C.orange : C.muted))),
                    Text(p.balance > 0 ? tr('পাবো') : (p.balance < 0 ? tr('দেবো') : tr('শোধ')), style: body(12, color: C.muted)),
                  ]),
                  onTap: () => dueDetails(context, project, p),
                );
              }(),
          ]),
        ),
      ],
    ]);
  }
}

/// Every open বকেয়া across the অন্যান্য হিসাব, on that tab itself — so
/// nobody has to open a হিসাব and scroll to find them. Late ones first.
class AllDuesSection extends StatelessWidget {
  const AllDuesSection({super.key, required this.projects});
  final List<Project> projects;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final today = dayOnly(brain.services.now());
    final rows = <(Project, PersonBalance, DateTime?)>[];
    var owed = 0, owing = 0;
    for (final pr in projects) {
      for (final p in projectDues(brain.data, pr.id)) {
        if (p.balance == 0) continue;
        if (p.balance > 0) owed += p.balance;
        if (p.balance < 0) owing -= p.balance;
        rows.add((pr, p, _nextDue(_linesOf(brain.data, pr, p))));
      }
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    rows.sort((a, b) {
      final x = a.$3, y = b.$3;
      if (x == null && y == null) return b.$2.balance.abs().compareTo(a.$2.balance.abs());
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle(tr('বকেয়া')),
      Panel(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('আমি পাবো'), style: body(13, color: C.muted)),
              Text(taka(owed), style: display(19, color: C.green)),
            ]),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(tr('আমি দেবো'), style: body(13, color: C.muted)),
              Text(taka(owing), style: display(19, color: C.orange)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Panel(
        child: Rows(children: [
          for (final (pr, p, next) in rows)
            () {
              final late = next != null && dayOnly(next).isBefore(today);
              final when = next == null ? null : (late ? trf('দিন পেরিয়েছে {0}', [shortDate(next)]) : trf('পরিশোধ {0}', [shortDate(next)]));
              return ListRow(
                key: Key('alldue-${pr.id}-${p.key}'),
                leading: CircleAvatar(
                  backgroundColor: p.balance > 0 ? C.greenTint : C.orangeTint,
                  child: Text(p.name.isEmpty ? '?' : p.name.characters.first, style: body(15, weight: FontWeight.w700, color: p.balance > 0 ? C.green : C.orange)),
                ),
                title: p.name,
                subtitle: [pr.name, if (when != null) when].join(' · '),
                trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                  Text(taka(p.balance.abs()), style: display(16, color: late ? C.red : (p.balance > 0 ? C.green : C.orange))),
                  Text(p.balance > 0 ? tr('পাবো') : tr('দেবো'), style: body(12, color: C.muted)),
                ]),
                onTap: () => dueDetails(context, pr, p),
              );
            }(),
        ]),
      ),
    ]);
  }
}
