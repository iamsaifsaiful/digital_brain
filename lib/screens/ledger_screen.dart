import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/ledger.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'ledger_form_screen.dart';
import 'money_screens.dart';
import 'person_screen.dart';
import 'transactions_screen.dart';

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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        TabTitle('হিসাব',
            trailing: _part == MoneyPart.loans
                ? IconButton(tooltip: 'সব লেনদেন খুঁজুন', onPressed: () => push(const TransactionsScreen()), icon: const Icon(Icons.search_rounded))
                : null),
        const SizedBox(height: 12),
        SegTabs<MoneyPart>(
          items: const [(MoneyPart.cash, 'আয়-ব্যয়'), (MoneyPart.loans, 'ধার-দেনা'), (MoneyPart.projects, 'প্রজেক্ট')],
          value: _part,
          onChanged: show,
        ),
        const SizedBox(height: 14),
        ...switch (_part) {
          MoneyPart.cash => [const CashView()],
          MoneyPart.loans => _loans(context, brain, push),
          MoneyPart.projects => [const ProjectsView()],
        },
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
              label: 'আমি পাব',
              amount: taka(loans.receivable),
              color: C.green,
              size: 22,
              sub: 'দিয়েছি ${taka(loans.lent)} · ফেরত ${taka(loans.received)}',
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Panel(
            padding: const EdgeInsets.all(14),
            child: Figure(
              label: 'আমি দেব',
              amount: taka(loans.payable),
              color: C.orange,
              size: 22,
              sub: 'নিয়েছি ${taka(loans.borrowed)} · শোধ ${taka(loans.repaid)}',
            ),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      PrimaryButton(label: 'নতুন লেনদেন', icon: Icons.add_rounded, color: C.ink, height: 48, onPressed: () => push(const LedgerFormScreen())),
      const SizedBox(height: 6),
      Text('মুখেও বলা যায়: “রহিমকে ৫০০ টাকা ধার দিলাম”', style: body(13, color: C.muted)),
      const SizedBox(height: 16),
      if (people.isEmpty)
        EmptyState(
          icon: Icons.swap_horiz_rounded,
          title: 'কারো সাথে ধার-দেনা নেই',
          text: 'কাউকে টাকা দিলে বা কারো কাছ থেকে নিলে এখানে রাখুন — নাম আর মোবাইল নম্বর দিয়ে, যাতে একই নামের দুজন গুলিয়ে না যায়।',
          action: 'লিখে যোগ করুন',
          onAction: () => push(const LedgerFormScreen()),
        )
      else ...[
        SectionTitle('মানুষ · ${bnDigits(people.length)}'),
        Panel(
          child: Rows(children: [
            for (final p in people)
              ListRow(
                leading: Avatar(name: p.name, fg: balanceColors(p.balance).$1, bg: balanceColors(p.balance).$2),
                title: p.name,
                subtitle: [
                  if (p.phone.isNotEmpty) showPhone(p.phone) else if (dupNames.contains(personKey(p.name))) 'নম্বর নেই — যোগ করুন',
                  if (p.last != null) daysLeftLabel(p.last!, now).replaceAll(' আগে', ''),
                ].join(' · '),
                subtitleColor: p.phone.isEmpty && dupNames.contains(personKey(p.name)) ? C.orange : C.muted,
                trailing: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(taka(p.balance), style: display(16, weight: 700, color: balanceColor(p.balance))),
                  Text(p.balance == 0 ? 'শোধ' : (p.balance > 0 ? 'পাব' : 'দেব'), style: body(12, color: C.muted)),
                ]),
                onTap: () => push(PersonScreen(person: p.name, accountKey: p.key)),
              ),
          ]),
        ),
      ],
    ];
  }
}
