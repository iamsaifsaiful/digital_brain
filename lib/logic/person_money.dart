/// Everything the user's money has to do with one person: আয়-ব্যয় whose
/// note names them, ধার-দেনা and বকেয়া with them — and one নীট figure.
library;

import '../models/models.dart';
import 'ledger.dart';
import 'parser.dart' show normalize;

/// One line of a person's money, from any part of হিসাব.
class PersonLine {
  const PersonLine({required this.date, required this.label, required this.amount, required this.inflow, this.note = '', this.projectId, this.cash, this.loan});
  final DateTime date;
  final String label;
  final int amount;

  /// Money (or a claim) coming to the user.
  final bool inflow;
  final String note;
  final String? projectId;
  final CashEntry? cash;
  final LedgerEntry? loan;

  /// A বকেয়া (goods on credit), not money that moved: no + or −.
  bool get claim => loan != null && loan!.projectId != null && (loan!.kind == LedgerKind.lent || loan!.kind == LedgerKind.borrowed);

  /// A claim the user holds (they owe the user).
  bool get mine => loan != null && loan!.kind == LedgerKind.lent;
}

class PersonMoney {
  PersonMoney(this.query);
  final String query;

  /// The ledger names found (one "করিম" may be "করিম মিয়া" and "করিম ভাই").
  final names = <String>{};
  final lines = <PersonLine>[];

  /// আয়-ব্যয় entries that name the person.
  int income = 0, expense = 0;

  /// ধার-দেনা and বকেয়া still open: positive = they owe the user.
  int balance = 0;

  /// Money that actually moved in personal loans (lent/repaid out, borrowed/received in).
  int _loanFlow = 0;

  bool get isEmpty => lines.isEmpty;
  int get owed => balance > 0 ? balance : 0;
  int get owing => balance < 0 ? -balance : 0;

  /// নীট: what came from them minus what went to them, counting what is
  /// still owed. A loan given and owed back is 0; goods sold on credit
  /// count once (as বকেয়া, then as income when paid).
  int get net => income - expense + _loanFlow + balance;
}

final _sep = RegExp(r'\s+');

/// Does [text] name [q] as a word ("করিমের দোকানে" yes, "রহিমা" for "রহিম" no)?
bool namesPerson(String text, String q) {
  final t = normalize(text);
  final n = normalize(q);
  if (n.isEmpty || t.isEmpty) return false;
  final i = RegExp('(^|[^\\p{L}\\p{M}])${RegExp.escape(n)}(এর|ের|র|কে|দের|-এর)?(?=\$|[^\\p{L}\\p{M}])', unicode: true);
  return i.hasMatch(t);
}

/// A ledger name matches when every word of [q] starts one of its words.
bool _nameMatches(String person, String q) {
  final p = normalize(person).split(_sep);
  final words = normalize(q).split(_sep).where((w) => w.isNotEmpty);
  return words.isNotEmpty && words.every((w) => p.any((x) => x == w || x.startsWith(w)));
}

String _loanLabel(LedgerEntry e) => e.projectId == null
    ? e.kind.label
    : switch (e.kind) {
        LedgerKind.lent => 'বকেয়া পাবো',
        LedgerKind.received => 'বকেয়া আদায়',
        LedgerKind.borrowed => 'বকেয়া দেবো',
        LedgerKind.repaid => 'বকেয়া শোধ',
      };

/// All of [q]'s money in [d], newest first.
PersonMoney personMoney(AppData d, String q) {
  final m = PersonMoney(q.trim());
  if (m.query.isEmpty) return m;
  final loans = [for (final e in d.ledger) if (_nameMatches(e.person, m.query)) e];
  for (final e in loans) {
    m.names.add(e.person.trim());
    m.lines.add(PersonLine(date: e.date, label: _loanLabel(e), amount: e.amount, inflow: e.kind == LedgerKind.received || e.kind == LedgerKind.borrowed, note: e.note, projectId: e.projectId, loan: e));
    // A project's বকেয়া moves goods, not cash: its money is in আয়-ব্যয়.
    if (e.projectId == null) m._loanFlow += e.kind.outflow ? -e.amount : e.amount;
  }
  for (final b in balances(loans)) {
    m.balance += b.balance;
  }
  final names = {m.query, ...m.names};
  for (final c in d.cash) {
    if (!names.any((n) => namesPerson(c.note, n) || namesPerson(c.category, n))) continue;
    final inc = c.kind == CashKind.income;
    if (inc) {
      m.income += c.amount;
    } else {
      m.expense += c.amount;
    }
    m.lines.add(PersonLine(date: c.date, label: c.category, amount: c.amount, inflow: inc, note: c.note, projectId: c.projectId, cash: c));
  }
  m.lines.sort((a, b) => b.date.compareTo(a.date));
  return m;
}

/// Names to offer while typing in the হিসাব search.
List<String> personSuggestions(AppData d, String q, {int max = 8}) {
  if (normalize(q).isEmpty) return const [];
  final seen = <String>{};
  final out = <String>[];
  for (final e in d.ledger.reversed) {
    final n = e.person.trim();
    if (_nameMatches(n, q) && seen.add(personKey(n))) out.add(n);
    if (out.length >= max) break;
  }
  return out;
}
