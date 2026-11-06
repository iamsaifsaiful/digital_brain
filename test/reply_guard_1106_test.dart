// Owner, 6 Nov: "Reply already submitted" closed the app. ReplyGuard.kt
// keeps the app open past it and writes it as a problem (not a crash).
import 'dart:convert';
import 'dart:io';

import 'package:digital_brain/services/error_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a double reply the app survived is logged as a problem; a real crash still as a crash', () async {
    final dir = await Directory.systemTemp.createTemp('reply');
    addTearDown(() => dir.delete(recursive: true));
    ErrorLog.pending.clear();
    await File('${dir.path}/app_crash.json').writeAsString(jsonEncode({'kind': 'Android:ReplyTwice', 'message': 'java.lang.IllegalStateException: Reply already submitted', 'stack': 'a.b.c:12', 'version': '1.0.6', 'level': 'problem'}));
    await ErrorLog.open(dir);
    expect(ErrorLog.pending.last['level'], 'problem');
    expect(ErrorLog.pending.last['kind'], 'Android:ReplyTwice');

    ErrorLog.pending.clear();
    await File('${dir.path}/app_crash.json').writeAsString(jsonEncode({'kind': 'Android:NullPointerException', 'message': 'x', 'stack': '', 'version': '1.0.6'}));
    await ErrorLog.open(dir);
    expect(ErrorLog.pending.last['level'], 'crash');
  });
}
