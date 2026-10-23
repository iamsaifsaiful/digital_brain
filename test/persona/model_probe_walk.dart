import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'nlu_runner.dart';

void main() {
  test('model probe', () async {
    final r = realReader();
    final out = StringBuffer();
    for (final s in File('test/persona/out/sentences.txt').readAsLinesSync().where((x) => x.trim().isNotEmpty)) {
      final ps = await r.read(s, 'idle', 'none');
      out.writeln('$s\n   ⇒ ${ps.map((p) => '${p.intent}${p.sure ? '' : '?'}(${p.conf.toStringAsFixed(2)}) ${p.slots}').join(' | ')}');
    }
    File('test/persona/out/model.txt').writeAsStringSync(out.toString());
  });
}
