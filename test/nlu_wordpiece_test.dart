import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:digital_brain/nlu/wordpiece.dart';

void main() {
  final vocabFile = File('assets/nlu/vocab.txt');
  final vectors = File('tool/nlu/train/wordpiece_vectors.jsonl');
  test('word pieces match the Python tokenizer', () {
    final wp = WordPiece(vocabFile.readAsLinesSync());
    final bad = <String>[];
    for (final l in vectors.readAsLinesSync().where((l) => l.trim().isNotEmpty)) {
      final v = jsonDecode(l) as Map<String, dynamic>;
      final got = wp.ids(v['norm'] as String);
      if (jsonEncode(got) != jsonEncode(v['ids'])) bad.add('${v['norm']}: $got ≠ ${v['ids']}');
    }
    expect(bad, isEmpty, reason: bad.take(5).join('\n'));
  }, skip: vocabFile.existsSync() && vectors.existsSync() ? false : 'model files not in the app yet');
}
