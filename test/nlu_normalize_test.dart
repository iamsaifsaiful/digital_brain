import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:digital_brain/nlu/normalize.dart';

void main() {
  test('Dart clean-up and split match the Python ones the model learned on', () {
    final lines = File('tool/nlu/train/vectors.jsonl').readAsLinesSync().where((l) => l.trim().isNotEmpty);
    final bad = <String>[];
    var n = 0;
    for (final l in lines) {
      final v = jsonDecode(l) as Map<String, dynamic>;
      final text = v['text'] as String;
      n++;
      if (nluNormalize(text) != v['norm']) bad.add('norm: $text → ${nluNormalize(text)} ≠ ${v['norm']}');
      final parts = [for (final p in nluSplitLines(text)) [p.$1, p.$2]];
      if (jsonEncode(parts) != jsonEncode(v['parts'])) bad.add('split: $text → $parts ≠ ${v['parts']}');
    }
    expect(n, greaterThan(1000));
    expect(bad, isEmpty, reason: bad.take(10).join('\n'));
  });
}
