/// Turns what the AI understood into the same commands the rules produce,
/// so every screen (confirm, ask-name, answer) works the same either way.
library;

import '../models/models.dart';
import 'ledger.dart';
import 'parser.dart';

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String _str(Object? v) => v is String ? v.trim() : '';
List<String> _terms(Object? v) {
  final out = <String>[];
  if (v is! List) return out;
  for (final t in v) {
    if (t is! String || t.trim().isEmpty) continue;
    final n = normalize(t);
    final st = searchTerms(n);
    for (final x in st.isEmpty ? [n] : st) {
      if (!out.contains(x)) out.add(x);
    }
  }
  return out;
}

/// Null when the AI's answer is not usable (the rules are used instead).
Command? commandFromAi(String said, Map<String, Object?> r, List<LedgerEntry> ledger) {
  final known = knownPeople(ledger);
  String person() {
    final p = _str(r['person']);
    return p.isEmpty ? '' : resolvePerson(p, known);
  }

  switch (_str(r['action'])) {
    case 'ledger_add':
      final p = person();
      final amount = _int(r['amount']).abs();
      final kind = LedgerKind.values.where((k) => k.name == _str(r['kind'])).firstOrNull;
      if (kind != null && p.isNotEmpty) return LedgerAdd(said, person: p, amount: amount, kind: kind);
      return LedgerAdd(said, person: p, amount: amount, options: LedgerKind.values, suggested: kind, allowExpense: true);
    case 'ledger_set':
      final p = person();
      final b = _int(r['balance']);
      if (p.isEmpty || b == 0) return LedgerAdd(said, person: p, amount: b.abs(), options: LedgerKind.values, allowExpense: true);
      return LedgerSet(said, person: p, balance: b);
    case 'ledger_query':
      final ask = LedgerAsk.values.where((a) => a.name == _str(r['ask'])).firstOrNull ?? LedgerAsk.all;
      final p = person();
      if (ask == LedgerAsk.person && p.isEmpty) return LedgerQuery(said, ask: LedgerAsk.all);
      return LedgerQuery(said, ask: ask, person: ask == LedgerAsk.person ? p : null);
    case 'vault_query':
      return VaultQuery(said, terms: _terms(r['terms']), wifiOnly: r['wifi'] == true);
    case 'reminder_query':
      return ReminderQuery(said, terms: _terms(r['terms']));
    case 'note_add':
      final text = _str(r['text']).isEmpty ? said.trim() : _str(r['text']);
      final cat = _str(r['category']);
      return NoteAdd(said, text: text, fromStatement: true, category: cat.isEmpty ? null : cat);
    case 'search':
      final t = _terms(r['terms']);
      return t.isEmpty ? null : SearchQuery(said, terms: t);
    case 'chat':
      final reply = _str(r['reply']);
      return reply.isEmpty ? null : AiReply(said, text: reply);
  }
  return null;
}
