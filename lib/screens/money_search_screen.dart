/// হিসাবে খোঁজা: a person's name brings all of the user's money with them —
/// আয়-ব্যয় that names them, ধার-দেনা, বকেয়া — and one নীট figure.
library;

import 'package:flutter/material.dart';

import '../logic/bn.dart';
import '../logic/lang.dart';
import '../logic/person_money.dart';
import '../state/brain.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'person_screen.dart';

/// The totals and every line of [m], for the search page and the chat.
class PersonMoneyView extends StatelessWidget {
  const PersonMoneyView({super.key, required this.m});
  final PersonMoney m;

  @override
  Widget build(BuildContext context) {
    final d = BrainScope.of(context).data;
    String where(PersonLine l) {
      if (l.projectId != null) return d.projects.where((p) => p.id == l.projectId).firstOrNull?.name ?? tr('অন্যান্য হিসাব');
      return l.loan != null ? tr('ধার-দেনা') : tr('আয়-ব্যয়');
    }

    Widget fig(String label, int v, Color c) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: body(13, color: C.muted)),
            Text(taka(v), style: display(17, color: c)),
          ]),
        );

    final net = m.net;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Panel(
        key: const Key('person-net'),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(tr('নীট হিসাব'), style: body(14, weight: FontWeight.w600, color: C.muted)),
          Text('${net < 0 ? '−' : ''}${taka(net.abs())}', style: display(32, weight: 700, color: net < 0 ? C.orange : C.green, height: 1.2)),
          Text(net < 0 ? tr('সব মিলিয়ে তাঁর দিকে বেশি গেছে') : (net > 0 ? tr('সব মিলিয়ে আপনার দিকে বেশি') : tr('সব মিলিয়ে সমান')), style: body(13, color: C.muted)),
          const SizedBox(height: 12),
          Row(children: [
            fig(tr('আয়'), m.income, C.green),
            fig(tr('ব্যয়'), m.expense, C.orange),
            fig(m.owing > 0 ? tr('দেবো') : tr('পাবো / বকেয়া'), m.owing > 0 ? m.owing : m.owed, m.owing > 0 ? C.orange : C.green),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      SectionTitle(trf('সব হিসাব ({0})', [bnDigits(m.lines.length)])),
      Panel(
        child: Rows(children: [
          for (final l in m.lines)
            ListRow(
              leading: l.claim
                  ? Icon(Icons.receipt_long_outlined, color: l.mine ? C.green : C.orange)
                  : Icon(l.inflow ? Icons.south_west_rounded : Icons.north_east_rounded, color: l.inflow ? C.green : C.orange),
              title: tr(l.label),
              subtitle: [shortDate(l.date), where(l), if (l.note.trim().isNotEmpty) l.note.trim()].join(' · '),
              trailing: l.claim
                  ? Text(taka(l.amount), style: display(15, color: l.mine ? C.green : C.orange))
                  : Text('${l.inflow ? '+' : '−'}${taka(l.amount)}', style: display(15, color: l.inflow ? C.green : C.orange)),
              onTap: l.loan == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PersonScreen(person: l.loan!.person))),
            ),
        ]),
      ),
    ]);
  }
}

class MoneySearchScreen extends StatefulWidget {
  const MoneySearchScreen({super.key, this.query = ''});
  final String query;

  @override
  State<MoneySearchScreen> createState() => _MoneySearchScreenState();
}

class _MoneySearchScreenState extends State<MoneySearchScreen> {
  late final _q = TextEditingController(text: widget.query)..addListener(() => setState(() {}));

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brain = BrainScope.of(context);
    final q = _q.text.trim();
    final m = personMoney(brain.data, q);
    final names = personSuggestions(brain.data, q);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: tr('হিসাবে খুঁজুন')),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: TextField(
              key: const Key('money-search'),
              controller: _q,
              autofocus: widget.query.isEmpty,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: tr('ব্যক্তির নাম, যেমন: করিম')),
            ),
          ),
          if (names.length > 1)
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                for (final n in names)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(n),
                      onPressed: () => _q
                        ..text = n
                        ..selection = TextSelection.collapsed(offset: n.length),
                    ),
                  ),
              ]),
            ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
              if (q.isEmpty)
                EmptyState(icon: Icons.person_search_outlined, title: tr('কার হিসাব দেখবেন?'), text: tr('নাম লিখুন — তাঁর নামে সব আয়, ব্যয়, ধার-দেনা আর বকেয়া, সাথে নীট হিসাব।'))
              else if (m.isEmpty)
                EmptyState(icon: Icons.search_off_rounded, title: trf('‘{0}’ নামে কোনো হিসাব নেই', [q]), text: tr('আয়-ব্যয়ের বিবরণে নাম লিখলে সেটাও এখানে আসবে।'))
              else
                PersonMoneyView(m: m),
            ]),
          ),
        ]),
      ),
    );
  }
}
