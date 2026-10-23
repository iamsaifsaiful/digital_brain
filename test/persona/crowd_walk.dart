// The 2000-user crowd (tool/nlu/crowd/crowd.py): each sentence of a half
// through the app's rules (parseAll) and, with MODEL=1, the on-phone model
// too. → test/persona/out/crowd_<half>.jsonl, checked by tool/nlu/crowd/check.py.
//   flutter test --no-pub test/persona/crowd_walk.dart --dart-define=HALF=test
import 'dart:convert';
import 'dart:io';

import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/logic/plan.dart';
import 'package:digital_brain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'nlu_runner.dart';

Map<String, Object?> d(Command c) => switch (c) {
      LedgerAdd x => {'t': 'LedgerAdd', 'amount': x.amount, 'kind': x.kind?.name, 'person': x.person},
      CashAdd x => {'t': 'CashAdd', 'amount': x.amount, 'kind': x.kind.name, 'cat': x.category},
      ReminderAdd x => {'t': 'ReminderAdd', 'hour': x.needsTime ? null : x.at.hour, 'repeat': x.repeat.name, 'title': x.title},
      TaskAdd x => {'t': 'TaskAdd', 'title': x.title},
      MenuAction x => {'t': 'Menu', 'domain': x.domain, 'op': x.op},
      HealthAdd x => {'t': 'HealthAdd', 'kind': x.kind.name},
      _ => {'t': '${c.runtimeType}'},
    };

void main() {
  final now = DateTime(2026, 10, 9, 15, 53);
  const half = String.fromEnvironment('HALF', defaultValue: 'test');
  final withModel = Platform.environment['MODEL'] == '1';
  test('crowd', () async {
    final r = withModel ? realReader() : null;
    final out = StringBuffer();
    final data = AppData();
    for (final line in File('tool/nlu/out/crowd/$half.jsonl').readAsLinesSync().where((x) => x.trim().isNotEmpty)) {
      final g = jsonDecode(line) as Map<String, dynamic>;
      final text = g['text'] as String;
      final cs = parseAll(text, const [], now: now, data: data);
      final row = <String, Object?>{'id': g['id'], 'rules': [for (final c in cs) d(c)]};
      if (r != null) {
        final ps = await r.read(text, 'idle', 'none');
        row['model'] = [for (final p in ps) p.intent];
        row['model_conf'] = ps.isEmpty ? 0.0 : ps.map((p) => p.conf).reduce((a, b) => a < b ? a : b);
      }
      out.writeln(jsonEncode(row));
    }
    File('test/persona/out/crowd_$half.jsonl').writeAsStringSync(out.toString());
  });
}
