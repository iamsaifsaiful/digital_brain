/// Turns what the AI understood into the same commands the rules produce,
/// so every screen (confirm, ask-name, answer) works the same either way.
library;

import '../models/models.dart';
import 'app_map.dart';
import 'cash.dart';
import 'ledger.dart';
import 'parser.dart';
import 'when.dart' show hourState;

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
List<Command> commandsFromAi(String said, Map<String, Object?> r, List<LedgerEntry> ledger, {DateTime? now}) {
  final at = now ?? DateTime.now();
  final reply = _str(r['reply']);
  final items = r['items'];
  if (items is! List) {
    final c = commandFromAi(said, r, ledger, now: at);
    return c == null ? const [] : [checked(c, said, at)];
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
    final c = commandFromAi(said, item, ledger, now: at);
    if (c != null) out.add(c);
  }
  // The AI's words are used only for talk. Anything it asks the app to do
  // or look up is done by the app, and what the app found or saved is what
  // is said — the AI never says its own count, date or "saved".
  if ((out.isEmpty || (chatted && out.every((c) => c is AiReply))) && reply.isNotEmpty) out.insert(0, AiReply(said, text: reply));
  // The same checks as the rules' commands (money tense, part-of-day times).
  return [for (final c in out) checked(c, said, at)];
}

/// Questions the AI may answer in its own words: none. Every question about
/// the user's things is answered from the app's own query result.
bool answeredByAi(Command c) => false;

TaskRef _ref(Map<String, Object?> r, String said) {
  final idx = _int(r['index']);
  if (idx != 0) return TaskRef(index: idx, said: said);
  final t = _terms(r['terms']);
  final it = _str(r['ref']) == 'it';
  if (t.isNotEmpty) return TaskRef(terms: t, it: it, said: said);
  return TaskRef(it: true, said: said);
}

/// The one way a span's date is kept, whatever day the AI wrote: the
/// first day of the app's week, the 1st of the month, 1 January.
DateTime? _spanStart(DateTime? d, TaskSpan span) => d == null
    ? null
    : switch (span) {
        TaskSpan.day => d,
        TaskSpan.week => weekStartOf(d),
        TaskSpan.month => DateTime(d.year, d.month),
        TaskSpan.year => DateTime(d.year),
      };

TaskSpan _span(Object? v) => TaskSpan.values.where((s) => s.name == _str(v)).firstOrNull ?? TaskSpan.day;

/// Null when the AI's answer is not usable (the rules are used instead).
Command? commandFromAi(String said, Map<String, Object?> r, List<LedgerEntry> ledger, {DateTime? now}) {
  final at0 = now ?? DateTime.now();
  final known = knownPeople(ledger);
  // Morning or evening still open for [h]: from the user's own words where
  // the hour is found in them; otherwise the AI's own `time_clear`.
  bool open(int h) => hourState(said, h) ?? (r['time_clear'] == false && h >= 1 && h <= 12);
  var guessed = false;
  String person() {
    final p = _str(r['person']);
    if (p.isEmpty) return '';
    final got = resolvePerson(p, known);
    // A name the user did not say (the AI "corrected" it to someone known):
    // left empty, so the app asks — money never goes to a guessed person.
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(said)) {
      final first = words(normalize(got)).where((w) => w.runes.length >= 2).firstOrNull;
      final head = first == null ? '' : String.fromCharCodes(first.runes.take(first.runes.length.clamp(2, 3)));
      if (head.isNotEmpty && !words(normalize(said)).any((w) => w.startsWith(head))) {
        guessed = true;
        return '';
      }
    }
    return got;
  }

  switch (_str(r['action'])) {
    case 'ledger_add':
      final p = person();
      // The AI named someone the user did not: the rules read it instead.
      if (guessed) return null;
      final amount = _int(r['amount']).abs();
      final kind = LedgerKind.values.where((k) => k.name == _str(r['kind'])).firstOrNull;
      if (kind != null && p.isNotEmpty) return LedgerAdd(said, person: p, amount: amount, kind: kind);
      return LedgerAdd(said, person: p, amount: amount, options: LedgerKind.values, suggested: kind, allowExpense: true);
    case 'ledger_set':
      // "রহিমকে কাল ১০০০ টাকা দিতে হবে": a duty, not the balance — the
      // rules read it (a to-do); the stored balance is never overwritten.
      if (RegExp(fold(r'(?:দিতে\s+হবে|দেবো|দেব|দিবো|দিব|ফেরত\s+দিতে)')).hasMatch(fold(normalize(said))) && !RegExp(fold(r'(?:মোট|সব\s+মিলিয়ে|সবমিলিয়ে|এখন|বর্তমানে)')).hasMatch(fold(normalize(said)))) return null;
      final p = person();
      if (guessed) return null;
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
    case 'memory_add':
      final text = _str(r['text']);
      return text.isEmpty ? null : MemoryAdd(said, text: text);
    case 'special_add':
      final person = _str(r['person']);
      final day = _day(r['date']);
      if (person.isEmpty || day == null) return null;
      final now = at0;
      return SpecialAdd(said,
          person: person, kind: SpecialKind.parse(_str(r['kind'])), month: day.month, day: day.day, year: day.year < now.year ? day.year : null);
    case 'open':
      final page = _str(r['page']);
      if (placeById(page) == null) return null;
      final folder = _str(r['folder']);
      return OpenPlace(said, place: page, folder: folder.isEmpty ? null : folder);
    case 'search':
      final t = _terms(r['terms']);
      return t.isEmpty ? null : SearchQuery(said, terms: t);
    case 'chat':
      final reply = _str(r['reply']);
      return reply.isEmpty ? null : AiReply(said, text: reply);
    case 'task_add':
      final title = _str(r['text']);
      if (title.isEmpty) return null;
      final deadline = _day(r['deadline']);
      final span = _span(r['span']);
      return TaskAdd(said,
          title: title, due: _spanStart(_day(r['date']), span), span: span, urgent: r['urgent'] == true, by: deadline, condition: _str(r['condition']).isEmpty ? null : _str(r['condition']));
    case 'task_done':
      final ref = _ref(r, said);
      return TaskDone(said, terms: ref.terms, ref: ref);
    case 'task_reopen':
      final ref = _ref(r, said);
      return TaskDone(said, terms: ref.terms, ref: ref, done: false);
    case 'task_edit':
      final ref = _ref(r, said);
      final title = _str(r['text']);
      final shift = _int(r['shift_days']);
      return TaskEdit(said,
          ref: ref,
          title: title.isEmpty ? null : title,
          due: _spanStart(_day(r['date']), _span(r['span'])),
          span: r['date'] == null ? null : _span(r['span']),
          clearDue: r['clear_date'] == true,
          shiftDays: shift,
          urgent: r['urgent'] is bool ? r['urgent'] as bool : null,
          note: _str(r['note']).isEmpty ? null : _str(r['note']));
    case 'task_delete':
      return TaskEdit(said, ref: _ref(r, said), delete: true);
    case 'task_skip_once':
      return TaskEdit(said, ref: _ref(r, said), skipOnce: true);
    case 'task_remind':
      final ref = _ref(r, said);
      final day = _day(r['date']);
      final time = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(_str(r['time']));
      if (time == null) return TaskEdit(said, ref: ref, remindNeedsTime: true, due: day);
      final h = int.parse(time[1]!), m = int.parse(time[2]!);
      if (day != null) return TaskEdit(said, ref: ref, remindAt: DateTime(day.year, day.month, day.day, h, m), remindAmPm: open(h));
      return TaskEdit(said, ref: ref, remindHour: h, remindMinute: m, remindAmPm: open(h));
    case 'reminder_stop':
      return TaskEdit(said, ref: _ref(r, said), stopReminder: true);
    case 'reminder_snooze':
      final minutes = _int(r['minutes']);
      return minutes <= 0 ? null : ReminderSnooze(said, minutes: minutes);
    case 'task_query':
      // The rules' reading of the same question (its day, week or words),
      // so the AI path and the rules answer from the same list.
      final local = todoCommands(said, const [], at0)?.whereType<TaskQuery>().firstOrNull;
      return local ?? TaskQuery(said);
    case 'briefing':
      return Briefing(said);
    case 'reminder_add':
      final day = _day(r['date']);
      final time = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(_str(r['time']));
      final repeat = Repeat.values.where((x) => x.name == _str(r['repeat'])).firstOrNull ?? Repeat.none;
      final now = at0;
      final title = _str(r['text']).isEmpty ? defaultReminderTitle : _str(r['text']);
      final before = _int(r['before_minutes']).clamp(0, 60 * 24 * 60);
      if (time == null) {
        if (repeat.isInterval) {
          final first = now.add(Duration(minutes: repeat.minutes));
          return ReminderAdd(said, title: title, at: DateTime(first.year, first.month, first.day, first.hour, first.minute), repeat: repeat);
        }
        // No hour said: asked ("কাল কয়টায় মনে করাব?") — never a made-up 9:00.
        return ReminderAdd(said, title: title, at: noTimeYet, repeat: repeat, day: day, alarm: r['alarm'] == true);
      }
      final h = int.parse(time[1]!), m = int.parse(time[2]!);
      final d = day ?? DateTime(now.year, now.month, now.day);
      var at = DateTime(d.year, d.month, d.day, h, m);
      final ampm = open(h);
      // Only a clear time and no day, already gone today: the next time it
      // comes round (tomorrow, the same hour). Never moved by 12 hours — an
      // open hour is asked, and a day that was said is never changed here.
      if (day == null && !ampm && !at.isAfter(now)) at = at.add(const Duration(days: 1));
      return ReminderAdd(said,
          title: title, at: at, repeat: repeat, alarm: r['alarm'] == true, weekdays: repeat == Repeat.weekly ? [at.weekday] : const [], minutesBefore: before, ampmOpen: ampm);
    case 'bulk':
      // Several items of the list the app showed last. Only a selection of
      // places, a count, names or "all of it" — never ids; the app resolves
      // them on the list it showed and asks before removing.
      final op = _str(r['op']);
      const ops = {'delete', 'done', 'reopen', 'move', 'remind', 'reminder_off', 'urgent', 'not_done', 'restore', 'report'};
      if (!ops.contains(op)) return null;
      final sel = _selection(r['select']);
      if (sel == null) return null;
      final day = _day(r['date']);
      if (op == 'move' && day == null) return null;
      final tm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(_str(r['time']));
      final h = tm == null ? null : int.parse(tm[1]!);
      return BulkAction(said,
          selection: sel,
          op: op,
          domain: const {'tasks', 'reminders', 'notes', 'medicines', 'habits', 'money', 'health'}.contains(_str(r['list'])) ? _str(r['list']) : '',
          due: day,
          time: h == null ? null : h * 60 + int.parse(tm![2]!),
          ampmOpen: h != null && (hourState(said, h) ?? (r['time_clear'] == false && h >= 1 && h <= 12)),
          day: DateTime(at0.year, at0.month, at0.day));
    case 'menu':
      // Only what the registry lists; names are resolved by the app, never ids.
      final domain = _str(r['domain']), op = _str(r['op']);
      if (voiceCaps[domain]?.ops.containsKey(op) != true) return null;
      return MenuAction(said,
          domain: domain,
          op: op,
          target: _str(r['target']),
          target2: _str(r['target2']),
          amount: _int(r['amount']).abs(),
          amount2: _int(r['amount2']).abs(),
          day: _day(r['date']),
          until: _day(r['until']),
          time: RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(_str(r['time'])) == null ? null : int.parse(_str(r['time']).split(':')[0]) * 60 + int.parse(_str(r['time']).split(':')[1].substring(0, 2)),
          text: _str(r['text']),
          part: r['time_clear'] == false ? '?' : '');
    case 'contact_add':
      final phone = findPhone(_str(r['phone'])) ?? findPhone(said);
      if (phone == null) return null;
      return ContactAdd(said, name: _str(r['person']), phone: phone);
    case 'cash_add':
      final amount = _int(r['amount']).abs();
      if (amount <= 0) return null;
      final kind = _str(r['kind']) == 'income' ? CashKind.income : CashKind.expense;
      final cat = _str(r['category']);
      final project = r.containsKey('project') && r['project'] != null ? _str(r['project']) : null;
      return CashAdd(said, kind: kind, amount: amount, category: cat.isEmpty ? categoryFor(normalize(said), kind) : cat, project: project);
    case 'cash_query':
      final project = r.containsKey('project') && r['project'] != null ? _str(r['project']) : null;
      return CashQuery(said, project: project);
    case 'call':
      final via = Via.values.where((v) => v.name == _str(r['via'])).firstOrNull ?? Via.call;
      return CallPerson(said, person: person(), via: via, text: via == Via.call ? '' : _str(r['text']), phone: findPhone(_str(r['phone'])) ?? '');
  }
  return null;
}

/// The AI's `select`: {kind: all|indexes|first|last|range|names|filter|rest|global,
/// indexes, n, from, to, names, filter, except_indexes, except_names}.
Selection? _selection(Object? v) {
  if (v is! Map) return null;
  final kind = SelKind.values.where((k) => k.name == _str(v['kind'])).firstOrNull;
  if (kind == null) return null;
  List<int> ints(Object? x) => x is List ? [for (final e in x) if (e is num && e.toInt() != 0) e.toInt()] : const [];
  List<List<String>> names(Object? x) => x is List ? [for (final e in x) if (e is String && e.trim().isNotEmpty) _terms([e])].where((t) => t.isNotEmpty).toList() : const [];
  final sel = Selection(kind,
      indexes: ints(v['indexes']),
      n: _int(v['n']),
      from: _int(v['from']),
      to: _int(v['to']),
      names: names(v['names']),
      filter: const {'urgent', 'overdue', 'undated', 'open', 'done'}.contains(_str(v['filter'])) ? _str(v['filter']) : '',
      exceptIdx: ints(v['except_indexes']),
      exceptNames: names(v['except_names']));
  final ok = switch (kind) {
    SelKind.indexes => sel.indexes.isNotEmpty,
    SelKind.first || SelKind.last => sel.n > 0,
    SelKind.range => sel.from > 0 && sel.to > 0,
    SelKind.names => sel.names.isNotEmpty,
    SelKind.filter => sel.filter.isNotEmpty,
    _ => true,
  };
  return ok ? sel : null;
}

DateTime? _day(Object? v) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(_str(v));
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}
