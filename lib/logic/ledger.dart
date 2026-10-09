import '../models/models.dart';

/// Key used to treat "Sajib", " sajib " and "SAJIB" as the same person.
String personKey(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// One person's running account.
class PersonBalance {
  PersonBalance(this.name);

  /// The name as most recently written.
  String name;

  /// Positive: they owe me. Negative: I owe them.
  int balance = 0;
  int lentTotal = 0;
  int borrowedTotal = 0;
  int receivedTotal = 0;
  int repaidTotal = 0;
  DateTime? first;
  DateTime? last;
  int count = 0;

  bool get owesMe => balance > 0;
  bool get iOwe => balance < 0;
  bool get settled => balance == 0;
}

/// Entries sorted oldest first (by date, then when they were saved).
List<LedgerEntry> chronological(Iterable<LedgerEntry> entries) {
  final l = entries.toList()
    ..sort((a, b) {
      final c = a.date.compareTo(b.date);
      return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
    });
  return l;
}

/// Entries sorted newest first.
List<LedgerEntry> newestFirst(Iterable<LedgerEntry> entries) => chronological(entries).reversed.toList();

/// Every person with their current balance, biggest amounts first.
List<PersonBalance> balances(Iterable<LedgerEntry> entries) {
  final map = <String, PersonBalance>{};
  for (final e in chronological(entries)) {
    final p = map.putIfAbsent(personKey(e.person), () => PersonBalance(e.person.trim()));
    p.name = e.person.trim();
    p.balance += e.kind.signed(e.amount);
    switch (e.kind) {
      case LedgerKind.lent:
        p.lentTotal += e.amount;
      case LedgerKind.borrowed:
        p.borrowedTotal += e.amount;
      case LedgerKind.received:
        p.receivedTotal += e.amount;
      case LedgerKind.repaid:
        p.repaidTotal += e.amount;
    }
    p.first ??= e.date;
    p.last = e.date;
    p.count++;
  }
  final l = map.values.toList()..sort((a, b) => b.balance.abs().compareTo(a.balance.abs()));
  return l;
}

PersonBalance? balanceOf(Iterable<LedgerEntry> entries, String person) {
  final k = personKey(person);
  for (final p in balances(entries)) {
    if (personKey(p.name) == k) return p;
  }
  return null;
}

/// Current balance with one person (0 when unknown).
int balanceWith(Iterable<LedgerEntry> entries, String person) => balanceOf(entries, person)?.balance ?? 0;

/// What adding [kind]/[amount] would change the balance to.
int balanceAfter(Iterable<LedgerEntry> entries, String person, LedgerKind kind, int amount) =>
    balanceWith(entries, person) + kind.signed(amount);

class LedgerTotals {
  const LedgerTotals({required this.receivable, required this.payable, required this.owingPeople, required this.owedPeople});

  /// Sum others owe me.
  final int receivable;

  /// Sum I owe others.
  final int payable;

  /// How many people owe me.
  final int owingPeople;

  /// How many people I owe.
  final int owedPeople;

  int get net => receivable - payable;
}

LedgerTotals totals(Iterable<LedgerEntry> entries) {
  var r = 0, p = 0, rn = 0, pn = 0;
  for (final b in balances(entries)) {
    if (b.balance > 0) {
      r += b.balance;
      rn++;
    } else if (b.balance < 0) {
      p += -b.balance;
      pn++;
    }
  }
  return LedgerTotals(receivable: r, payable: p, owingPeople: rn, owedPeople: pn);
}

/// Entries with one person, oldest first, with the balance after each.
List<(LedgerEntry, int)> runningFor(Iterable<LedgerEntry> entries, String person) {
  final k = personKey(person);
  var bal = 0;
  final out = <(LedgerEntry, int)>[];
  for (final e in chronological(entries.where((e) => personKey(e.person) == k))) {
    bal += e.kind.signed(e.amount);
    out.add((e, bal));
  }
  return out;
}

/// Names known to the ledger, most recent first.
List<String> knownPeople(Iterable<LedgerEntry> entries) {
  final seen = <String>{};
  final out = <String>[];
  for (final e in newestFirst(entries)) {
    if (seen.add(personKey(e.person))) out.add(e.person.trim());
  }
  return out;
}

/// "সজীবের কাছে পাবেন ৳২০০" style wording for a balance.
String balanceWords(String person, int balance) {
  if (balance > 0) return 'পাবেন';
  if (balance < 0) return 'দেবেন';
  return 'হিসাব শূন্য';
}
