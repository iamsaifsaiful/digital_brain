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
  b.writeln(['তারিখ', 'নাম', 'মোবাইল', 'ধরন', 'পরিমাণ (টাকা)', 'এরপর বাকি (+ পাবেন / − দেবেন)', 'নোট'].map(_cell).join(','));
  final rows = <(LedgerEntry, int)>[];
  for (final p in balances(entries)) {
    rows.addAll(runningForKey(entries, p.key));
  }
  rows.sort((a, b) {
    final c = a.$1.date.compareTo(b.$1.date);
    return c != 0 ? c : a.$1.createdAt.compareTo(b.$1.createdAt);
  });
  for (final (e, after) in rows) {
    b.writeln([_date(e.date), e.person, e.phone, e.kind.label, e.amount, after, e.note].map(_cell).join(','));
  }
  b.writeln();
  b.writeln(['নাম', 'মোবাইল', 'এখন বাকি (+ পাবেন / − দেবেন)'].map(_cell).join(','));
  for (final p in balances(entries)) {
    b.writeln([p.name, p.phone, p.balance].map(_cell).join(','));
  }
  return b.toString();
}

/// One account's (or the general) entries as CSV — only the kind asked
/// ([kind] null = both), each with its own row and a total row that is
/// the exact sum of them. Amounts are taka (the app keeps one currency);
/// nothing from the vault is ever part of it.
String cashCsv(List<CashEntry> entries, {CashKind? kind}) {
  final rows = [for (final e in entries) if (kind == null || e.kind == kind) e]..sort((a, b) => a.date.compareTo(b.date));
  final b = StringBuffer('\uFEFF');
  b.writeln(['তারিখ', 'ধরন', 'খাত', 'বিবরণ', 'পরিমাণ (টাকা)'].map(_cell).join(','));
  for (final e in rows) {
    b.writeln([_date(e.date), e.kind.label, e.category, e.note, e.amount].map(_cell).join(','));
  }
  final income = rows.where((e) => e.kind == CashKind.income).fold<int>(0, (s, e) => s + e.amount);
  final spent = rows.where((e) => e.kind == CashKind.expense).fold<int>(0, (s, e) => s + e.amount);
  b.writeln();
  if (kind != CashKind.expense) b.writeln(['', 'মোট আয়', '', '', income].map(_cell).join(','));
  if (kind != CashKind.income) b.writeln(['', 'মোট খরচ', '', '', spent].map(_cell).join(','));
  return b.toString();
}
