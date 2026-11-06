// 7 Nov: in notes and every other free-text box, a new line (and a new
// sentence) starts with a capital letter. Number, password and link boxes
// are left alone. A new box without it fails here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every free-text box capitalizes sentences', () {
    final missing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final s = f.readAsStringSync();
      for (final m in RegExp(r'\b(?:TextField|TextFormField)\(').allMatches(s)) {
        var d = 1, j = m.end;
        String? q;
        while (d > 0 && j < s.length) {
          final c = s[j];
          if (q != null) {
            if (c == r'\') {
              j++;
            } else if (c == q) {
              q = null;
            }
          } else if (c == "'" || c == '"') {
            q = c;
          } else if ('([{'.contains(c)) {
            d++;
          } else if (')]}'.contains(c)) {
            d--;
          }
          j++;
        }
        final args = s.substring(m.end, j - 1);
        if (args.contains('textCapitalization') || args.contains('obscureText') || args.contains('digitsOnly') || args.contains("'ইউজারনেম'")) continue;
        final kt = RegExp(r'keyboardType:\s*([^,\n]+)').firstMatch(args)?[1]?.trim();
        if (kt != null && !RegExp(r'^(?:const\s+)?TextInputType\.(?:text|multiline)\b').hasMatch(kt)) continue;
        missing.add('${f.path}:${'\n'.allMatches(s.substring(0, m.start)).length + 1}');
      }
    }
    expect(missing, isEmpty);
  });
}
