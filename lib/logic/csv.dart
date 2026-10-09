import '../models/models.dart';
import 'ledger.dart';

String _cell(Object v) {
  final s = '$v';
  return RegExp(r'[",\n\r]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
}

String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The ledger as CSV (UTF-8 with BOM so Excel shows Bengali correctly).
/// Passwords are never part of any report.
String ledgerCsv(List<LedgerEntry> entries) {
  final b = StringBuffer('﻿');
  b.writeln(['তারিখ', 'নাম', 'ধরন', 'পরিমাণ (টাকা)', 'এরপর বাকি (+ পাবেন / − দেবেন)', 'নোট'].map(_cell).join(','));
  final names = <String>{for (final e in entries) personKey(e.person)};
  final rows = <(LedgerEntry, int)>[];
  for (final n in names) {
    final person = entries.firstWhere((e) => personKey(e.person) == n).person;
    rows.addAll(runningFor(entries, person));
  }
  rows.sort((a, b) {
    final c = a.$1.date.compareTo(b.$1.date);
    return c != 0 ? c : a.$1.createdAt.compareTo(b.$1.createdAt);
  });
  for (final (e, after) in rows) {
    b.writeln([_date(e.date), e.person, e.kind.label, e.amount, after, e.note].map(_cell).join(','));
  }
  b.writeln();
  b.writeln(['নাম', 'এখন বাকি (+ পাবেন / − দেবেন)'].map(_cell).join(','));
  for (final p in balances(entries)) {
    b.writeln([p.name, p.balance].map(_cell).join(','));
  }
  return b.toString();
}
