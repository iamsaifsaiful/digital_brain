// The old rules' reading of the gold set (tool/nlu/gold/*.jsonl), as a
// baseline for tool/nlu/eval.py. Two readings per row:
//  • parse: parseAll() on the sentence alone (no conversation) — the rules
//    the brief names;
//  • chat: the whole chat (ChatController) after the turns before it, read
//    from what it did: the data it changed, what it is now waiting on, the
//    list it showed, or the spec intents it logged.
// Runs only when asked (it writes a file):
//   NLU_BASELINE=1 flutter test --no-pub test/nlu_baseline_test.dart
// Output: tool/nlu/out/baseline_old.jsonl.
import 'dart:convert';
import 'dart:io';

import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/logic/plan.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/nlu/labels.dart';
import 'package:digital_brain/services/trace.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'angles_test.dart' as ang show fixture;
import 'app_test.dart' show start;
import 'intent500_test.dart' as i500 show fixture;
import 'master100_test.dart' as m100 show fixtureT, fixtureR, fixtureP, fixtureL;

AppData fixtureNamed(String name) => switch (name) {
      'intent500' => i500.fixture(),
      'angles' => ang.fixture(),
      'm100_T' => AppData(tasks: m100.fixtureT()),
      'm100_R' => AppData(reminders: m100.fixtureR()),
      'm100_TR' => AppData(tasks: m100.fixtureT(), reminders: m100.fixtureR()),
      'm100_P' => m100.fixtureP(),
      'm100_L' => m100.fixtureL(),
      _ => AppData(),
    };

/// What is kept, as comparable lines (ids, titles, days, flags — no notes' text).
Map<String, String> snap(AppData d) => {
      for (final x in d.tasks) 't:${x.id}': '${x.title}|${x.due}|${x.span}|${x.done}|${x.reminderId}',
      for (final r in d.reminders) 'r:${r.id}': '${r.date}|${r.hour}|${r.minute}|${r.enabled}|${r.title}',
      for (final n in d.notes) 'n:${n.id}': '',
      for (final c in d.cash) 'c:${c.id}': '${c.amount}|${c.category}',
      for (final l in d.ledger) 'l:${l.id}': '${l.amount}',
      for (final s in d.specialDays) 's:${s.id}': '${s.month}|${s.day}',
      for (final c in d.contacts) 'k:${c.id}': '',
      for (final m in d.memories) 'm:${m.id}': '',
      for (final p in d.projects) 'p:${p.id}': '',
      for (final h in d.health) 'h:${h.id}': '',
    };

/// Intents read from what changed in the data.
List<String> fromDiff(Map<String, String> a, Map<String, String> b) {
  final out = <String>{};
  final linked = {for (final e in b.entries) if (e.key.startsWith('t:')) e.value.split('|').last};
  for (final k in b.keys.where((k) => !a.containsKey(k))) {
    out.add(switch (k[0]) {
      't' => 'task_add',
      'r' => linked.contains(k.substring(2)) ? 'task_remind' : 'reminder_add',
      'n' => 'note_add',
      'c' => 'cash_add',
      'l' => 'ledger_add',
      's' => 'special_add',
      'k' => 'contact_add',
      'm' => 'memory_add',
      'p' => 'menu_project',
      'h' => 'health_add',
      _ => 'other',
    });
  }
  for (final k in a.keys.where((k) => !b.containsKey(k))) {
    out.add(switch (k[0]) { 't' => 'task_delete', 'r' => 'reminder_delete', _ => 'item_delete' });
  }
  for (final k in a.keys.where((k) => b.containsKey(k) && a[k] != b[k])) {
    final x = a[k]!.split('|'), y = b[k]!.split('|');
    switch (k[0]) {
      case 't':
        if (x[0] != y[0]) out.add('rename');
        if (x[3] != y[3]) out.add(y[3] == 'true' ? 'task_done' : 'task_reopen');
        if (x[1] != y[1] || x[2] != y[2]) out.add('task_edit');
        if (x[4] != y[4] && y[4] != 'null') out.add('task_remind');
      case 'r':
        if (x[3] != y[3]) out.add(y[3] == 'false' ? 'reminder_stop' : 'reminder_edit');
        if (x[0] != y[0] || x[1] != y[1] || x[2] != y[2]) out.add('reminder_edit');
        if (x[4] != y[4]) out.add('rename');
      case 's':
        out.add('correct');
      default:
        out.add('item_edit');
    }
  }
  return out.toList()..sort();
}

/// What a waiting question is about.
String pendingIntent(Map<String, Object?> st) {
  final wait = st['wait'];
  final cur = st['current'] as String?;
  final bulkOp = st['bulkOp'] as String?;
  final dom = st['bulkDomain'] as String?;
  String byCurrent() => switch (cur) {
        'TasksClear' => 'task_delete',
        'ManageItem' => switch (st['currentAction']) {
            'delete' => st['targetKind'] == 'task' ? 'task_delete' : (st['targetKind'] == 'reminder' ? 'reminder_delete' : 'item_delete'),
            'stop' => 'reminder_stop',
            _ => st['targetKind'] == 'task' ? 'task_edit' : 'reminder_edit',
          },
        'LedgerAdd' => 'ledger_add',
        'LedgerSet' => 'ledger_set',
        'CashAdd' => 'cash_add',
        'NoteAdd' => 'note_add',
        'SpecialAdd' => 'special_add',
        'TaskAdd' => 'task_add',
        'ReminderAdd' => 'reminder_add',
        'ContactAdd' => 'contact_add',
        'MemoryAdd' => 'memory_add',
        _ => 'pending:$cur',
      };
  switch (wait) {
    case 'bulk' || 'yesNo':
      if (bulkOp != null) {
        return switch (bulkOp) {
          'delete' => dom == 'tasks' ? 'task_delete' : (dom == 'reminders' ? 'reminder_delete' : 'item_delete'),
          'reminder_off' => 'reminder_stop',
          'done' => 'task_done',
          _ => 'bulk_$bulkOp',
        };
      }
      return byCurrent();
    case 'taskTime' || 'batchTime':
      return 'task_remind';
    case 'reminderTime' || 'reminderTitle':
      return 'reminder_add';
    case 'changeTo':
      return st['targetKind'] == 'task' ? 'task_edit' : 'reminder_edit';
    case 'collect':
      return 'dictate_start';
    case 'whichItem':
      return byCurrent();
    case 'taskTitle' || 'taskDay' || 'taskDate':
      return 'task_add';
    case 'name' || 'amount' || 'kind' || 'whichPerson' || 'newAccount':
      return cur == 'CashAdd' ? 'cash_add' : 'ledger_add';
    case 'project':
      return 'cash_add';
    default:
      return 'wait:$wait';
  }
}

const _answerWaits = {'taskTime', 'batchTime', 'reminderTime', 'reminderTitle', 'changeTo', 'taskTitle', 'taskDay', 'taskDate', 'name', 'amount', 'phone', 'message', 'contactName', 'topicName', 'callee'};
const _pickWaits = {'whichItem', 'whichTask', 'whichPerson', 'clarify', 'kind', 'project', 'newAccount', 'topic'};

List<String> classify(String text, Map<String, Object?> st0, Map<String, Object?> st1, List<String> diff, List<String> traced) {
  final w0 = st0['wait'] as String, w1 = st1['wait'] as String;
  if (w0 != 'none' && w0 != 'collect') {
    if (diff.isNotEmpty) {
      if (yesNo(text) == true) return ['confirm_yes'];
      if (_answerWaits.contains(w0)) return ['inform'];
      if (_pickWaits.contains(w0)) return ['select'];
      return diff;
    }
    if (w1 == 'none') return [yesNo(text) == false ? 'confirm_no' : 'cancel'];
    if (w1 == w0 && st1['bulkOp'] == st0['bulkOp'] && st1['current'] == st0['current']) {
      return [w0 == 'bulk' ? 'select' : (w0 == 'yesNo' ? 'correct' : (_answerWaits.contains(w0) ? 'inform' : 'select'))];
    }
    return [pendingIntent(st1)];
  }
  if (w0 == 'collect') {
    if (diff.isNotEmpty) return ['dictate_end'];
    if (w1 == 'collect') return ['task_add'];
    if (w1 == 'yesNo') return ['dictate_end'];
    if (w1 == 'none' && yesNo(text) == null && traced.isEmpty) return ['cancel'];
  }
  if (diff.isNotEmpty) return diff;
  if (w1 != 'none') return [pendingIntent(st1)];
  final newSet = (st1['sets'] as int) > (st0['sets'] as int) || st1['lastSetTurn'] == st1['turn'];
  if (newSet) {
    return [
      switch (st1['lastSetDomain']) {
        'tasks' => 'task_query',
        'reminders' => 'reminder_query',
        'ledger' => 'ledger_query',
        'money' => 'cash_query',
        'notes' => 'menu_notes',
        'medicines' => 'menu_medicine',
        'habits' => 'menu_habit',
        'health' => 'menu_health',
        final d => 'query:$d',
      }
    ];
  }
  if (traced.isNotEmpty) return traced;
  return ['none'];
}

List<Map<String, dynamic>> loadGold() {
  final rows = <Map<String, dynamic>>[];
  for (final f in Directory('tool/nlu/gold').listSync().whereType<File>().where((f) => f.path.endsWith('.jsonl')).toList()..sort((a, b) => a.path.compareTo(b.path))) {
    for (final line in f.readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      rows.add(jsonDecode(line) as Map<String, dynamic>);
    }
  }
  return rows;
}

void main() {
  final on = Platform.environment['NLU_BASELINE'] == '1';
  // Shards (NLU_SHARD=2/6): one process holds only so many widget tests.
  final shard = (Platform.environment['NLU_SHARD'] ?? '1/1').split('/').map(int.parse).toList();
  final all = on ? loadGold() : const <Map<String, dynamic>>[];
  final rows = [for (final (i, r) in all.indexed) if (i % shard[1] == shard[0] - 1) r];
  final file = File('tool/nlu/out/baseline_old.${shard[0]}of${shard[1]}.jsonl');
  if (on) {
    Directory('tool/nlu/out').createSync(recursive: true);
    file.writeAsStringSync('');
  }
  for (final row in rows) {
    testWidgets('${row['id']}', (t) async {
      final rig = await start(t);
      rig.nowAt = DateTime.parse(row['now'] as String);
      rig.brain.data = fixtureNamed(row['fixture'] as String);
      final chat = ChatController(rig.brain);
      for (final b in (row['before'] as List).cast<String>()) {
        await chat.hear(b);
      }
      final text = row['text'] as String;
      final d0 = rig.brain.data;
      final parse = intentsOfCommands(parseAll(text, d0.ledger, tasks: d0.tasks, contacts: d0.contacts, now: rig.nowAt, data: d0));
      final st0 = chat.debugState;
      final s0 = snap(rig.brain.data);
      Trace.enabled = true;
      Trace.clear();
      await chat.hear(text);
      final st1 = chat.debugState;
      final diff = fromDiff(s0, snap(rig.brain.data));
      final traced = [
        for (final e in Trace.events)
          if (e.area == 'understood' && e.what == 'spec')
            for (final x in (e.data['intents'] ?? '').split(','))
              if (x.isNotEmpty) x
      ];
      file.writeAsStringSync('${jsonEncode({
        'id': row['id'],
        'parse': parse,
        'chat': classify(text, st0, st1, diff, traced),
        'diff': diff,
        'wait': st1['wait'],
      })}\n', mode: FileMode.append);
      Trace.clear();
    });
  }
  if (!on) {
    test('baseline (run with NLU_BASELINE=1)', () {}, skip: 'writes tool/nlu/out/baseline_old.jsonl only when asked');
  }
}
