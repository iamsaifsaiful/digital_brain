import 'package:flutter/material.dart';

import '../ui/pro_gate.dart';

import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/ledger.dart';
import '../state/brain.dart';
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

  void show(MoneyPart p) => setState(() => _part = p);

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return TabPages<MoneyPart>(
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
        if (brain.businessMode) ...[const ShopTodayCard(), const SizedBox(height: 12)],
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
    );
  }

  List<Widget> _loans(BuildContext context, Brain brain, void Function(Widget) push) {
    final entries = brain.data.ledger;
    final now = brain.services.now();
    final loans = loanSummary(entries);
    final people = balances(entries)
      ..sort((a, b) {
        // Open accounts first (biggest first), settled ones last.
        final s = (a.balance == 0 ? 1 : 0).compareTo(b.balance == 0 ? 1 : 0);
        return s != 0 ? s : b.balance.abs().compareTo(a.balance.abs());
      });
    // বকেয়া of other হিসাব are counted here too (owner, 24 Oct), and marked.
    final keys = accountKeys(entries);
    final dueOf = <String, Set<String>>{};
    for (final e in entries.where((e) => e.projectId != null)) {
      final name = brain.data.projects.where((x) => x.id == e.projectId).firstOrNull?.name;
      if (name != null) dueOf.putIfAbsent(keys[e.id]!, () => {}).add(name);
    }
    final dues = totals(entries.where((e) => e.projectId != null));
    final dupNames = <String>{};
    final seen = <String>{};
    for (final p in people) {
      if (!seen.add(personKey(p.name))) dupNames.add(personKey(p.name));
    }

    return [
      Row(children: [
        Expanded(
          child: Panel(
            padding: const EdgeInsets.all(14),
            child: Figure(
              label: tr('আমি পাব'),
              amount: taka(loans.receivable),
              color: C.green,
              size: 22,
              sub: trf('দিয়েছি {0} · ফেরত {1}', [taka(loans.lent), taka(loans.received)]),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Panel(
            padding: const EdgeInsets.all(14),
            child: Figure(
              label: tr('আমি দেব'),
              amount: taka(loans.payable),
              color: C.orange,
              size: 22,
              sub: trf('নিয়েছি {0} · শোধ {1}', [taka(loans.borrowed), taka(loans.repaid)]),
            ),
          ),
        ),
      ]),
      if (dues.receivable > 0 || dues.payable > 0)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
              trf('এর মধ্যে অন্যান্য হিসাবের বকেয়া: পাব {0} · দেব {1}', [taka(dues.receivable), taka(dues.payable)]),
              key: const Key('loans-dues-note'),
              style: body(12.5, color: C.muted)),
        ),
      const SizedBox(height: 12),
      PrimaryButton(label: tr('নতুন লেনদেন'), icon: Icons.add_rounded, color: C.fill, height: 48, onPressed: () => push(const LedgerFormScreen())),
      const SizedBox(height: 6),
      Text(tr('মুখেও বলা যায়: “রহিমকে ৫০০ টাকা ধার দিলাম”'), style: body(13, color: C.muted)),
      const SizedBox(height: 16),
      if (people.isEmpty)
        EmptyState(
          icon: Icons.payments_outlined,
          title: tr('কারো সাথে ধার-দেনা নেই'),
          text: tr('কাউকে টাকা দিলে বা কারো কাছ থেকে নিলে এখানে রাখুন — নাম আর মোবাইল নম্বর দিয়ে, যাতে একই নামের দুজন গুলিয়ে না যায়।'),
          action: tr('লিখে যোগ করুন'),
          onAction: () => push(const LedgerFormScreen()),
        )
      else ...[
        SectionTitle(trf('মানুষ · {0}', [bnDigits(people.length)])),
        Panel(
          child: Rows(children: [
            for (final p in people)
              ListRow(
                leading: Avatar(name: p.name, fg: balanceColors(p.balance).$1, bg: balanceColors(p.balance).$2),
                title: p.name,
                subtitle: [
                  if (dueOf[p.key] != null) trf('বকেয়া · {0}', [dueOf[p.key]!.join(', ')]),
                  if (p.phone.isNotEmpty) showPhone(p.phone) else if (dupNames.contains(personKey(p.name))) tr('নম্বর নেই — যোগ করুন'),
                  if (p.last != null) daysLeftLabel(p.last!, now).replaceAll(' আগে', ''),
                ].join(' · '),
                subtitleColor: p.phone.isEmpty && dupNames.contains(personKey(p.name)) ? C.orange : C.muted,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(taka(p.balance), style: display(16, weight: 700, color: balanceColor(p.balance))),
                    Text(p.balance == 0 ? tr('শোধ') : (p.balance > 0 ? tr('পাব') : tr('দেব')), style: body(12, color: C.muted)),
                  ]),
                  if (p.balance != 0) LedgerAlarmButton(accountKey: p.key, balance: p.balance),
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
  const LedgerAlarmButton({super.key, required this.accountKey, required this.balance});
  final String accountKey;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final r = brain.ledgerReminderOf(accountKey);
    return IconButton(
      key: Key('ledger-alarm-$accountKey'),
      tooltip: r == null ? tr('রিমাইন্ডার দিন') : trf('রিমাইন্ডার: {0}, {1}', [shortDate(r.date), bnTime(r.hour, r.minute)]),
      visualDensity: VisualDensity.compact,
      icon: Icon(r == null ? Icons.alarm_add_outlined : Icons.alarm_on_rounded, size: 21, color: r == null ? C.muted : C.green),
      onPressed: () async {
        if (r != null) {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewItemScreen(reminder: r)));
          return;
        }
        if (!await needPro(context, ProFeature.reminders, allowed: brain.canAddReminder) || !context.mounted) return;
        final keys = accountKeys(brain.data.ledger);
        final kind = balance > 0 ? LedgerKind.lent : LedgerKind.borrowed;
        final e = brain.data.ledger.reversed.where((x) => keys[x.id] == accountKey && x.kind == kind).firstOrNull ??
            brain.data.ledger.reversed.where((x) => keys[x.id] == accountKey).firstOrNull;
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
