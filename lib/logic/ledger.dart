import '../models/models.dart';
import 'bn.dart';

/// Key used to treat "Sajib", " sajib " and "SAJIB" as the same person.
String personKey(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// The last 10 digits of a mobile number, so "+8801711…", "01711…" and
/// "০১৭১১…" are the same person.
String phoneKey(String phone) {
  final d = asciiDigits(phone).replaceAll(RegExp(r'[^0-9]'), '');
  return d.length > 10 ? d.substring(d.length - 10) : d;
}

/// "01711223344" → "০১৭১১-২২৩৩৪৪".
String showPhone(String phone) {
  final d = asciiDigits(phone).replaceAll(RegExp(r'[^0-9+]'), '');
  final s = d.length == 11 && d.startsWith('01') ? '${d.substring(0, 5)}-${d.substring(5)}' : d;
  return bnDigits(s);
}

/// Which account each entry belongs to. An account is a mobile number, or —
/// for entries written without one — the name. A name-only entry joins the
/// numbered account of the same name when there is exactly one.
Map<String, String> accountKeys(Iterable<LedgerEntry> entries) {
  final numbered = <String, Set<String>>{};
  for (final e in entries) {
    final pk = phoneKey(e.phone);
    if (pk.isNotEmpty) numbered.putIfAbsent(personKey(e.person), () => {}).add('p:$pk');
  }
  return {
    for (final e in entries)
      e.id: () {
        final pk = phoneKey(e.phone);
        if (pk.isNotEmpty) return 'p:$pk';
        final same = numbered[personKey(e.person)];
        return same != null && same.length == 1 ? same.first : 'n:${personKey(e.person)}';
      }(),
  };
}

/// One person's running account.
class PersonBalance {
  PersonBalance(this.name, this.key);

  /// The name as most recently written.
  String name;

  /// The account (see [accountKeys]).
  final String key;

  /// Their mobile number, if one was written.
  String phone = '';

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
  final keys = accountKeys(entries);
  final map = <String, PersonBalance>{};
  for (final e in chronological(entries)) {
    final k = keys[e.id]!;
    final p = map.putIfAbsent(k, () => PersonBalance(e.person.trim(), k));
    p.name = e.person.trim();
    if (e.phone.trim().isNotEmpty) p.phone = e.phone.trim();
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

/// Everyone written under [person]'s name (two "রহিম" with different
/// numbers are two accounts), most recently used first.
List<PersonBalance> peopleNamed(Iterable<LedgerEntry> entries, String person) {
  final k = personKey(person);
  return balances(entries).where((p) => personKey(p.name) == k).toList()
    ..sort((a, b) => (b.last ?? DateTime(0)).compareTo(a.last ?? DateTime(0)));
}

/// [person]'s account: the one with [phone] if given, otherwise the one
/// with that name used most recently.
PersonBalance? balanceOf(Iterable<LedgerEntry> entries, String person, {String phone = ''}) {
  final pk = phoneKey(phone);
  if (pk.isNotEmpty) {
    for (final p in balances(entries)) {
      if (p.key == 'p:$pk') return p;
    }
  }
  final named = peopleNamed(entries, person);
  return named.isEmpty ? null : named.first;
}

PersonBalance? accountByKey(Iterable<LedgerEntry> entries, String key) {
  for (final p in balances(entries)) {
    if (p.key == key) return p;
  }
  return null;
}

/// Current balance with one person (0 when unknown).
int balanceWith(Iterable<LedgerEntry> entries, String person, {String phone = ''}) => balanceOf(entries, person, phone: phone)?.balance ?? 0;

/// What adding [kind]/[amount] would change the balance to.
int balanceAfter(Iterable<LedgerEntry> entries, String person, LedgerKind kind, int amount, {String phone = ''}) =>
    balanceWith(entries, person, phone: phone) + kind.signed(amount);

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
List<(LedgerEntry, int)> runningFor(Iterable<LedgerEntry> entries, String person, {String phone = ''}) {
  final p = balanceOf(entries, person, phone: phone);
  return p == null ? const [] : runningForKey(entries, p.key);
}

/// One account's entries, oldest first, with the balance after each.
List<(LedgerEntry, int)> runningForKey(Iterable<LedgerEntry> entries, String key) {
  final keys = accountKeys(entries);
  var bal = 0;
  final out = <(LedgerEntry, int)>[];
  for (final e in chronological(entries.where((e) => keys[e.id] == key))) {
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

/// The entry that brings [person]'s balance to [target] ("ইসমাইলের কাছে আমি
/// ৫ হাজার টাকা পাই"). Null when the book already says that.
LedgerEntry? entryToReach(Iterable<LedgerEntry> entries, String person, int target, DateTime now) {
  final p = balanceOf(entries, person);
  final current = p?.balance ?? 0;
  final d = target - current;
  if (d == 0) return null;
  final LedgerKind kind;
  if (d > 0) {
    kind = current < 0 && d <= -current ? LedgerKind.repaid : LedgerKind.lent;
  } else {
    kind = current > 0 && -d <= current ? LedgerKind.received : LedgerKind.borrowed;
  }
  return LedgerEntry(
    person: p?.name ?? person.trim(),
    phone: p?.phone ?? '',
    kind: kind,
    amount: d.abs(),
    date: dayOnly(now),
    note: p == null ? 'শুরুর হিসাব' : 'হিসাব মিলানো: মোট ${taka(target)} ${target >= 0 ? 'পাবেন' : 'দেবেন'}',
  );
}
