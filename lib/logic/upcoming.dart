/// সামনের খরচ (owner, 22 Nov): what the member has to pay in the coming
/// days — subscriptions, instalments and loans to give back on a date.
library;

import '../models/models.dart';
import 'bn.dart';
import 'ledger.dart';

enum UpcomingKind { subscription, installment, loan }

class Upcoming {
  const Upcoming({required this.kind, required this.title, required this.amount, required this.date, required this.id});
  final UpcomingKind kind;
  final String title;
  final int amount;
  final DateTime date;

  /// The subscription, instalment or ledger account it comes from.
  final String id;
}

/// Everything due from a week back (still unpaid) to [days] ahead, by date.
List<Upcoming> upcomingCosts(AppData d, DateTime now, {int days = 30}) {
  final today = dayOnly(now);
  final until = today.add(Duration(days: days));
  final from = today.subtract(const Duration(days: 7));
  bool inside(DateTime x) => !x.isBefore(from) && !x.isAfter(until);
  final out = <Upcoming>[];

  for (final s in d.subscriptions) {
    if (s.paused || s.amount <= 0) continue;
    // A late one shows on its own (passed) day; at most the next two.
    var at = dayOnly(s.next);
    for (var n = 0; n < 2 && !at.isAfter(until); n++) {
      out.add(Upcoming(kind: UpcomingKind.subscription, title: s.name, amount: s.amount, date: at, id: s.id));
      at = s.after(at);
    }
  }

  for (final i in d.installments) {
    if (i.left <= 0 || i.amount <= 0) continue;
    final first = DateTime(i.start.year, i.start.month);
    for (var m = -1; m <= 1; m++) {
      final month = DateTime(today.year, today.month + m);
      final at = DateTime(month.year, month.month, i.dayOfMonth);
      if (month.isBefore(first) || month.isAfter(i.end) || i.paidFor(month) || !inside(at)) continue;
      out.add(Upcoming(kind: UpcomingKind.installment, title: i.name, amount: i.amount, date: at, id: i.id));
    }
  }

  // Loans to give back: people I owe, on their earliest pay date.
  final own = d.ledger.where((e) => e.projectId == null).toList();
  final keys = accountKeys(own);
  final dueOf = <String, DateTime>{};
  for (final e in own) {
    final k = keys[e.id], due = e.due;
    if (k == null || due == null || e.kind != LedgerKind.borrowed) continue;
    if (dueOf[k] == null || due.isBefore(dueOf[k]!)) dueOf[k] = due;
  }
  for (final p in balances(own)) {
    final due = dueOf[p.key];
    if (p.balance >= 0 || due == null) continue;
    final at = dayOnly(due);
    if (at.isAfter(until)) continue;
    out.add(Upcoming(kind: UpcomingKind.loan, title: p.name, amount: -p.balance, date: at, id: p.key));
  }

  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
}
