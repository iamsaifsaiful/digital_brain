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

/// Everything the AI found in one message: one command per item, plus its
/// reply when there is nothing else to say. Empty when the answer is not
/// usable (the rules are used instead). Also reads the older one-item shape
/// ({action: …}).
List<Command> commandsFromAi(String said, Map<String, Object?> r, List<LedgerEntry> ledger) {
  final reply = _str(r['reply']);
  final items = r['items'];
  if (items is! List) {
    final c = commandFromAi(said, r, ledger);
    return c == null ? const [] : [c];
  }
  final out = <Command>[];
  var chatted = false;
  for (final it in items) {
    if (it is! Map) continue;
    final item = it.cast<String, Object?>();
    if (_str(item['action']) == 'chat') {
      chatted = true;
      continue;
    }
    final c = commandFromAi(said, item, ledger);
    if (c != null) out.add(c);
  }
  if ((out.isEmpty || chatted) && reply.isNotEmpty) out.insert(0, AiReply(said, text: reply));
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
    case 'task_add':
      final title = _str(r['text']);
      if (title.isEmpty) return null;
      return TaskAdd(said, title: title, due: _day(r['date']));
    case 'task_done':
      final t = _terms(r['terms']);
      return t.isEmpty ? null : TaskDone(said, terms: t);
    case 'task_query':
      return TaskQuery(said);
    case 'briefing':
      return Briefing(said);
    case 'reminder_add':
      final day = _day(r['date']);
      final time = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(_str(r['time']));
      if (day == null && time == null) return null;
      final now = DateTime.now();
      final d = day ?? DateTime(now.year, now.month, now.day);
      final at = DateTime(d.year, d.month, d.day, time == null ? 9 : int.parse(time[1]!), time == null ? 0 : int.parse(time[2]!));
      final title = _str(r['text']);
      return ReminderAdd(said,
          title: title.isEmpty ? 'মনে করানো' : title, at: at, repeat: Repeat.values.where((x) => x.name == _str(r['repeat'])).firstOrNull ?? Repeat.none);
    case 'contact_add':
      final phone = findPhone(_str(r['phone'])) ?? findPhone(said);
      if (phone == null) return null;
      return ContactAdd(said, name: _str(r['person']), phone: phone);
    case 'call':
      final via = Via.values.where((v) => v.name == _str(r['via'])).firstOrNull ?? Via.call;
      return CallPerson(said, person: person(), via: via, text: via == Via.call ? '' : _str(r['text']), phone: findPhone(_str(r['phone'])) ?? '');
  }
  return null;
}

DateTime? _day(Object? v) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(_str(v));
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}
