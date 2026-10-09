import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/cash.dart';
import '../logic/ledger.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'answer_screen.dart';
import 'home_shell.dart';
import 'ledger_form_screen.dart';
import 'money_screens.dart';
import 'person_screen.dart';
import 'transactions_screen.dart';
import '../logic/parser.dart';

/// Which part of লেনদেন is open.
enum MoneyPart { loans, cash, projects }

/// The লেনদেন tab: ধার-দেনা (people), আয়-ব্যয় (monthly) and প্রজেক্ট,
/// each with its own totals so they never mix.
class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  MoneyPart _part = MoneyPart.loans;

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final entries = brain.data.ledger;
    final people = balances(entries);
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    final sub = switch (_part) {
      MoneyPart.loans => people.isEmpty ? 'এখনো কোনো হিসাব নেই' : '${bnDigits(people.length)} জনের সাথে হিসাব',
      MoneyPart.cash => 'নিজের মাসিক আয়, খরচ আর সঞ্চয়',
      MoneyPart.projects => '${bnDigits(brain.data.projects.where((p) => !p.closed).length)}টি চলমান প্রজেক্ট',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('লেনদেন', style: display(26, weight: 700)),
                  Text(sub, style: body(14, color: C.muted)),
                ],
              ),
            ),
            if (_part == MoneyPart.loans) ...[
              RoundIconButton(icon: Icons.search_rounded, tooltip: 'সব লেনদেন', onPressed: () => push(const TransactionsScreen())),
              const SizedBox(width: 8),
              RoundIconButton(icon: Icons.add_rounded, tooltip: 'লিখে যোগ করুন', dark: true, onPressed: () => push(const LedgerFormScreen())),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<MoneyPart>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: MoneyPart.loans, label: Text('ধার-দেনা', style: body(13))),
              ButtonSegment(value: MoneyPart.cash, label: Text('আয়-ব্যয়', style: body(13))),
              ButtonSegment(value: MoneyPart.projects, label: Text('প্রজেক্ট', style: body(13))),
            ],
            selected: {_part},
            onSelectionChanged: (v) => setState(() => _part = v.first),
          ),
        ),
        const SizedBox(height: 14),
        ...switch (_part) {
          MoneyPart.loans => _loans(context, brain, push),
          MoneyPart.cash => [const CashView()],
          MoneyPart.projects => [const ProjectsView()],
        },
      ],
    );
  }

  List<Widget> _loans(BuildContext context, Brain brain, void Function(Widget) push) {
    final entries = brain.data.ledger;
    final t = totals(entries);
    final people = balances(entries);
    final recent = newestFirst(entries).take(4).toList();
    final loans = loanSummary(entries);
    return [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: C.ink, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LoanLine(title: 'ধার দেওয়া', a: ('মোট দিয়েছেন', loans.lent), b: ('ফেরত পেয়েছেন', loans.received), c: ('পাওনা আছে', loans.receivable), color: C.mint),
              const Divider(color: Color(0xFF34443D), height: 24),
              _LoanLine(title: 'ঋণ নেওয়া', a: ('মোট নিয়েছেন', loans.borrowed), b: ('শোধ করেছেন', loans.repaid), c: ('দেওয়া বাকি', loans.payable), color: C.peach),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Tile(
                      label: 'পাওনার তালিকা',
                      dot: const Color(0xFF5FD3AE),
                      amount: taka(t.receivable),
                      amountColor: C.mint,
                      sub: '${bnDigits(t.owingPeople)} জনের কাছে',
                      onTap: () => push(AnswerScreen(command: const LedgerQuery('আমি কার কাছে কত টাকা পাব?', ask: LedgerAsk.receivable))),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Tile(
                      label: 'দেনার তালিকা',
                      dot: const Color(0xFFF6A06B),
                      amount: taka(t.payable),
                      amountColor: C.peach,
                      sub: '${bnDigits(t.owedPeople)} জনকে দিতে হবে',
                      onTap: () => push(AnswerScreen(command: const LedgerQuery('কাকে কত টাকা দিতে হবে?', ask: LedgerAsk.payable))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Material(
          color: C.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: C.line)),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => openVoice(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: C.green, shape: BoxShape.circle),
                    child: const Icon(Icons.mic_none_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('বলে যোগ করুন বা জিজ্ঞেস করুন', style: body(16, weight: FontWeight.w600)),
                        Text('যেমন: “সজীবকে ৫০০ টাকা দিলাম”', style: body(14, color: C.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (people.isEmpty)
          EmptyState(
            icon: Icons.swap_horiz_rounded,
            title: 'প্রথম হিসাবটি যোগ করুন',
            text: 'মাইক চেপে বলুন “রহিমের কাছ থেকে ১০০০ টাকা ধার নিয়েছি”, অথবা লিখে যোগ করুন।',
            action: 'লিখে যোগ করুন',
            onAction: () => push(const LedgerFormScreen()),
          )
        else ...[
          const SectionTitle('মানুষ'),
          Panel(
            child: Rows(children: [
              for (final p in people)
                ListRow(
                  leading: Avatar(name: p.name, fg: balanceColors(p.balance).$1, bg: balanceColors(p.balance).$2),
                  title: p.name,
                  subtitle: p.last == null ? null : 'শেষ লেনদেন ${shortDate(p.last!)}',
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(taka(p.balance), style: display(17, color: balanceColor(p.balance))),
                      Text(balanceWords(p.name, p.balance), style: body(12, color: balanceColor(p.balance), weight: FontWeight.w600)),
                    ],
                  ),
                  onTap: () => push(PersonScreen(person: p.name)),
                ),
            ]),
          ),
          const SizedBox(height: 18),
          SectionTitle('সাম্প্রতিক লেনদেন', action: 'সব দেখুন', onAction: () => push(const TransactionsScreen())),
          Panel(
            child: Rows(children: [
              for (final e in recent)
                ListRow(
                  leading: Avatar(name: e.person, fg: balanceColors(balanceWith(entries, e.person)).$1, bg: balanceColors(balanceWith(entries, e.person)).$2),
                  title: e.person,
                  subtitle: '${e.kind.label} · ${shortDate(e.date)}',
                  trailing: Text(taka(e.amount), style: display(17)),
                  onTap: () => push(PersonScreen(person: e.person)),
                ),
            ]),
          ),
        ],
    ];
  }
}

class _LoanLine extends StatelessWidget {
  const _LoanLine({required this.title, required this.a, required this.b, required this.c, required this.color});
  final String title;
  final (String, int) a, b, c;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget cell((String, int) x, {bool strong = false}) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(x.$1, style: body(12, color: C.onDarkMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(taka(x.$2), style: display(strong ? 20 : 16, weight: 700, color: strong ? color : Colors.white)),
            ),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: body(14, weight: FontWeight.w600, color: color)),
      const SizedBox(height: 6),
      Row(children: [cell(a), cell(b), cell(c, strong: true)]),
    ]);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.dot, required this.amount, required this.amountColor, required this.sub, required this.onTap});
  final String label;
  final Color dot;
  final String amount;
  final Color amountColor;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: C.dark2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(label, style: body(13, color: C.onDarkMuted)),
                ]),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(amount, style: display(24, color: amountColor))),
                Text(sub, style: body(12, color: C.onDarkMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      );
}
