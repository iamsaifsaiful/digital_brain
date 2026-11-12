import 'package:flutter/material.dart';

import '../ui/pro_gate.dart';

import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/ledger.dart';
import '../state/brain.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ledger_form_screen.dart';
import 'new_item_screen.dart';
import '../logic/pro.dart' show ProFeature;
import '../models/models.dart';
import 'money_screens.dart';
import 'money_more_screens.dart';
import 'money_search_screen.dart';
import 'person_screen.dart';
import 'transactions_screen.dart';
import '../logic/lang.dart';
import '../ui/pdf_export.dart';

/// Which part of হিসাব is open. Ordered as people use them: own monthly
/// money most often, then loans, then projects.
enum MoneyPart { cash, loans, projects }

/// The হিসাব tab: আয়-ব্যয়, ধার-দেনা and প্রজেক্ট, each with its own totals
/// so they never mix.
class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key, this.initial = MoneyPart.cash});
  final MoneyPart initial;

  @override
  State<MoneyScreen> createState() => MoneyScreenState();
}

class MoneyScreenState extends State<MoneyScreen> {
  late MoneyPart _part = widget.initial;

  /// ধার-দেনা's filter: everyone, those who owe me, those I owe, settled.
  String _who = 'all';

  void show(MoneyPart p) => setState(() => _part = p);

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    // One add button at the bottom, by the thumb, as on দিনলিপি (approved design, 3 Nov).
    final add = switch (_part) {
      MoneyPart.cash => AddButton(key: const Key('cash-add'), label: tr('লেনদেন যোগ করুন'), onPressed: () => push(const CashFormScreen(kind: CashKind.expense))),
      MoneyPart.loans => AddButton(key: const Key('loan-add'), label: tr('নতুন লেনদেন'), onPressed: () => push(const LedgerFormScreen())),
      MoneyPart.projects => null,
    };
    return Stack(children: [
      TabPages<MoneyPart>(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      items: [(MoneyPart.cash, tr('আয়-ব্যয়')), (MoneyPart.loans, tr('ধার-দেনা')), (MoneyPart.projects, tr('অন্যান্য হিসাব'))],
      value: _part,
      onChanged: show,
      top: (tabs) => [
        TabTitle(tr('হিসাব'),
            sub: tr('আয়-ব্যয় আর ধার-দেনা'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              PdfButton(switch (_part) {
                MoneyPart.cash => const {ReportPart.money},
                MoneyPart.loans => const {ReportPart.ledger},
                MoneyPart.projects => const {ReportPart.projects},
              }),
              if (_part == MoneyPart.loans) IconButton(tooltip: tr('সব লেনদেন খুঁজুন'), onPressed: () => push(const TransactionsScreen()), icon: const Icon(Icons.list_alt_rounded)),
              IconButton(
                  key: const Key('money-search-open'), tooltip: tr('হিসাবে খুঁজুন'), onPressed: () => push(const MoneySearchScreen()), icon: const Icon(Icons.person_search_outlined)),
              const MoneyToolsMenu(),
            ])),
        const SizedBox(height: 12),
        tabs,
        const SizedBox(height: 14),
      ],
      page: (part) => [
        ...switch (part) {
          MoneyPart.cash => [const CashView()],
          MoneyPart.loans => _loans(context, brain, push),
          MoneyPart.projects => [const ProjectsView()],
        },
        const AdSlot(padding: EdgeInsets.only(top: 16)),
      ],
      ),
      if (add != null) Positioned(right: 16, bottom: 16, child: add),
    ]);
  }

  List<Widget> _loans(BuildContext context, Brain brain, void Function(Widget) push) {
    // Only ধার-দেনা: a হিসাব's বকেয়া lives inside that হিসাব (owner, 28 Oct).
    final entries = brain.data.ledger.where((e) => e.projectId == null).toList();
    final now = brain.services.now();
    final loans = loanSummary(entries);
    final people = balances(entries)
      ..sort((a, b) {
        // Open accounts first (biggest first), settled ones last.
        final s = (a.balance == 0 ? 1 : 0).compareTo(b.balance == 0 ? 1 : 0);
        return s != 0 ? s : b.balance.abs().compareTo(a.balance.abs());
      });
    final keys = accountKeys(entries);
    final dupNames = <String>{};
    final seen = <String>{};
    for (final p in people) {
      if (!seen.add(personKey(p.name))) dupNames.add(personKey(p.name));
    }

    final today = dayOnly(now);
    // The earliest pay date still open for each person.
    final dueOf = <String, DateTime>{};
    for (final e in entries) {
      final k = keys[e.id];
      final d = e.due;
      if (k == null || d == null) continue;
      if (dueOf[k] == null || d.isBefore(dueOf[k]!)) dueOf[k] = d;
    }
    final open = people.where((p) => p.balance != 0).toList();
    final dueNow = [for (final p in open) if (dueOf[p.key] != null && !dayOnly(dueOf[p.key]!).isAfter(today)) p];
    final getN = people.where((p) => p.balance > 0).length;
    final giveN = people.where((p) => p.balance < 0).length;
    final doneN = people.where((p) => p.balance == 0).length;
    final shown = [
      for (final p in people)
        if (_who == 'all' || (_who == 'get' && p.balance > 0) || (_who == 'give' && p.balance < 0) || (_who == 'done' && p.balance == 0)) p
    ];
    final net = loans.receivable - loans.payable;
    final both = loans.receivable + loans.payable;

    Widget half(String label, int amount, Color color, String sub, {bool first = true}) => Expanded(
          child: Container(
            padding: EdgeInsets.only(left: first ? 0 : 14),
            decoration: first ? null : BoxDecoration(border: Border(left: BorderSide(color: C.border))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: body(12.5, color: C.muted)),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: RollingAmount(value: amount, format: taka, style: display(22, weight: 700, color: color, height: 1.3))),
              Text(sub, maxLines: 2, style: body(11.5, color: C.muted, height: 1.35)),
            ]),
          ),
        );
    String dueText(DateTime d) {
      final diff = dayOnly(d).difference(today).inDays;
      if (diff == 0) return tr('ফেরতের দিন আজ');
      if (diff < 0) return trf('ফেরতের দিন পার হয়েছে · {0}', [shortDate(d)]);
      return trf('ফেরত {0}', [shortDate(d)]);
    }

    return [
      Panel(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              half(tr('আমি পাব'), loans.receivable, C.blue, trf('দিয়েছি {0} · ফেরত {1}', [taka(loans.lent), taka(loans.received)])),
              half(tr('আমি দেব'), loans.payable, C.red, trf('নিয়েছি {0} · শোধ {1}', [taka(loans.borrowed), taka(loans.repaid)]), first: false),
            ]),
          ),
          if (both > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (loans.receivable > 0) Expanded(flex: loans.receivable, child: ColoredBox(color: C.blue)),
                  if (loans.payable > 0) Expanded(flex: loans.payable, child: ColoredBox(color: C.red)),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              net == 0 ? tr('সব মিলিয়ে সমান সমান') : trf(net > 0 ? 'সব মিলিয়ে আপনি পাবেন {0}' : 'সব মিলিয়ে আপনি দেবেন {0}', [taka(net.abs())]),
              key: const Key('loans-net'),
              style: body(12.5, color: C.muted),
            ),
          ],
        ]),
      ),
      // Whose pay date has come: first, with a call (approved design, 3 Nov).
      for (final p in dueNow.take(2)) ...[
        const SizedBox(height: 10),
        Container(
          key: Key('loan-due-${p.key}'),
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
          decoration: BoxDecoration(color: C.warnBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.warnBorder)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${p.name} · ${dueText(dueOf[p.key]!)}', style: body(13.5, weight: FontWeight.w600, color: C.warn)),
                Text(p.balance > 0 ? trf('{0} পাবেন', [taka(p.balance)]) : trf('{0} দেবেন', [taka(-p.balance)]), style: body(12, color: C.warn)),
              ]),
            ),
            if (p.phone.isNotEmpty)
              IconButton(
                tooltip: tr('ফোন করুন'),
                onPressed: () => brain.services.launcher.open(Via.call, p.phone),
                icon: Icon(Icons.call_outlined, color: C.warn),
              ),
            IconButton(
              tooltip: tr('খুলুন'),
              onPressed: () => push(PersonScreen(person: p.name, accountKey: p.key)),
              icon: Icon(Icons.chevron_right_rounded, color: C.warn),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 10),
      Text(tr('মুখেও বলা যায়: “রহিমকে ৫০০ টাকা ধার দিলাম”'), style: body(12.5, color: C.muted)),
      const SizedBox(height: 6),
      if (people.isEmpty)
        EmptyState(
          icon: Icons.payments_outlined,
          title: tr('কারো সাথে ধার-দেনা নেই'),
          text: tr('কাউকে টাকা দিলে বা কারো কাছ থেকে নিলে এখানে রাখুন — নাম আর মোবাইল নম্বর দিয়ে, যাতে একই নামের দুজন গুলিয়ে না যায়।'),
          action: tr('লিখে যোগ করুন'),
          onAction: () => push(const LedgerFormScreen()),
        )
      else ...[
        // Who to show sits behind ⋮ (owner, 13 Nov), so the list shows whole.
        FilterTitle<String>(
          trf('মানুষ · {0}', [bnDigits(shown.length)]),
          menuKey: const ValueKey('loans-filter'),
          items: [
            ('all', trf('সবাই · {0}', [bnDigits(people.length)]), const Key('loans-all')),
            ('get', trf('পাব · {0}', [bnDigits(getN)]), const Key('loans-get')),
            ('give', trf('দেব · {0}', [bnDigits(giveN)]), const Key('loans-give')),
            ('done', trf('শোধ · {0}', [bnDigits(doneN)]), const Key('loans-done')),
          ],
          value: _who,
          onChanged: (k) => setState(() => _who = k),
        ),
        if (shown.isEmpty)
          Panel(padding: const EdgeInsets.all(14), child: Text(tr('এই ভাগে কেউ নেই'), style: body(14, color: C.muted)))
        else
          Panel(
            child: Rows(children: [
              for (final p in shown)
                ListRow(
                  leading: Avatar(
                    name: p.name,
                    fg: p.balance > 0 ? C.blue : (p.balance < 0 ? C.red : C.muted),
                    bg: p.balance > 0 ? C.blueTint : (p.balance < 0 ? C.roseTint : C.surface2),
                  ),
                  title: p.name,
                  subtitle: [
                    if (p.balance != 0 && dueOf[p.key] != null) dueText(dueOf[p.key]!),
                    if (p.phone.isNotEmpty) showPhone(p.phone) else if (dupNames.contains(personKey(p.name))) tr('নম্বর নেই — যোগ করুন'),
                    if (p.last != null) daysLeftLabel(p.last!, now).replaceAll(' আগে', ''),
                  ].join(' · '),
                  subtitleColor: (p.balance != 0 && dueOf[p.key] != null && !dayOnly(dueOf[p.key]!).isAfter(today)) || (p.phone.isEmpty && dupNames.contains(personKey(p.name))) ? C.warn : C.muted,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(taka(p.balance.abs()), style: display(16, weight: 700, color: p.balance > 0 ? C.blue : (p.balance < 0 ? C.red : C.muted))),
                      Text(p.balance == 0 ? tr('শোধ') : (p.balance > 0 ? tr('পাব') : tr('দেব')), style: body(12, color: C.muted)),
                    ]),
                    if (p.balance != 0) LedgerAlarmButton(lines: [for (final e in entries) if (keys[e.id] == p.key) e], balance: p.balance) else const SizedBox(width: 48),
                  ]),
                  onTap: () => push(PersonScreen(person: p.name, accountKey: p.key)),
                ),
            ]),
          ),
      ],
    ];
  }
}

/// The ⏰ beside someone with money still owed (owner, 28 Oct — like the to-do
/// list's): a reminder on a day and time, when no pay date was given. Set, it
/// shows green; tapped again, it opens to change or remove.
class LedgerAlarmButton extends StatelessWidget {
  const LedgerAlarmButton({super.key, this.accountKey, this.lines, required this.balance});

  /// One person in ধার-দেনা (see accountKeys)…
  final String? accountKey;

  /// …or any one person's entries (a হিসাব's বকেয়া, owner 28 Oct).
  final List<LedgerEntry>? lines;
  final int balance;

  List<LedgerEntry> _lines(Brain brain) {
    if (lines != null) return lines!;
    final keys = accountKeys(brain.data.ledger);
    return [for (final e in brain.data.ledger) if (keys[e.id] == accountKey) e];
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final mine = _lines(brain);
    final r = brain.ledgerReminderIn(mine);
    final id = accountKey ?? (mine.isEmpty ? '' : mine.first.id);
    return IconButton(
      key: Key('ledger-alarm-$id'),
      tooltip: r == null ? tr('রিমাইন্ডার দিন') : trf('রিমাইন্ডার: {0}, {1}', [shortDate(r.date), bnTime(r.hour, r.minute)]),
      visualDensity: VisualDensity.compact,
      icon: Icon(r == null ? Icons.alarm_add_outlined : Icons.alarm_on_rounded, size: 21, color: r == null ? C.muted : C.green),
      onPressed: () async {
        if (r != null) {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewItemScreen(reminder: r)));
          return;
        }
        if (!await needPro(context, ProFeature.reminders, allowed: brain.canAddReminder) || !context.mounted) return;
        final kind = balance > 0 ? LedgerKind.lent : LedgerKind.borrowed;
        final e = mine.reversed.where((x) => x.kind == kind).firstOrNull ?? mine.reversed.firstOrNull;
        if (e == null) return;
        final now = brain.services.now();
        final day = await showDatePicker(
            context: context, helpText: tr('কবে মনে করাব?'), initialDate: now.add(const Duration(days: 1)), firstDate: dayOnly(now), lastDate: DateTime(now.year + 5));
        if (day == null || !context.mounted) return;
        final t = await showTimePicker(context: context, helpText: tr('কয়টায়?'), initialTime: const TimeOfDay(hour: 10, minute: 0));
        if (t == null || !context.mounted) return;
        var at = DateTime(day.year, day.month, day.day, t.hour, t.minute);
        if (!at.isAfter(now)) at = now.add(const Duration(minutes: 1));
        await brain.remindLedger(e, at);
        if (context.mounted) toast(context, trf('{0}, {1}-এ মনে করাব', [fullDate(at), bnTime(at.hour, at.minute)]));
      },
    );
  }
}
