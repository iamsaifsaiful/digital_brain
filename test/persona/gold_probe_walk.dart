// The real on-phone model over a gold file (default persona.jsonl) →
// test/persona/out/pred_<name>.jsonl in tool/nlu/eval.py's format.
//   flutter test --no-pub test/persona/gold_probe_walk.dart --dart-define=GOLD=persona
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'nlu_runner.dart';

void main() {
  test('gold probe', () async {
    const name = String.fromEnvironment('GOLD', defaultValue: 'persona');
    final r = realReader();
    final out = StringBuffer();
    for (final line in File('tool/nlu/gold/$name.jsonl').readAsLinesSync().where((x) => x.trim().isNotEmpty)) {
      final g = jsonDecode(line) as Map<String, dynamic>;
      final ps = await r.read(g['text'] as String, g['state'] as String? ?? 'idle', 'none');
      final slots = <String, String>{};
      for (final p in ps) {
        p.slots.forEach((k, v) => slots.putIfAbsent(k, () => '$v'));
      }
      out.writeln(jsonEncode({
        'id': g['id'],
        'bert': [for (final p in ps) p.intent],
        'bert_conf': ps.isEmpty ? 0.0 : ps.map((p) => p.conf).reduce((a, b) => a < b ? a : b),
        'bert_slots': slots,
      }));
    }
    Directory('test/persona/out').createSync(recursive: true);
    File('test/persona/out/pred_$name.jsonl').writeAsStringSync(out.toString());
  });
}
