// সমস্যার লগ (owner, 27 Oct): "ইউজারের ফোন থেকে সরাসরি এখানে আসবে" —
// handled problems too, sent within seconds, kept on the phone until sent,
// and an Android crash sent on the next start.
import 'dart:convert';
import 'dart:io';

import 'package:digital_brain/services/ai.dart';
import 'package:digital_brain/services/error_log.dart';
import 'package:digital_brain/services/google_account.dart';
import 'package:digital_brain/services/notifications.dart' show idsToCancel, snoozeId;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('a handled problem goes by itself within seconds, as a code (never the member\'s words)', () async {
    final dir = await Directory.systemTemp.createTemp('elog');
    ErrorLog.pending.clear();
    ErrorLog.version = '2.55.12';
    ErrorLog.delay = const Duration(milliseconds: 50);
    await ErrorLog.open(dir);
    final sent = <Map<String, dynamic>>[];
    ErrorLog.connect(
        AccountServer(MockClient((r) async {
          sent.add(jsonDecode(r.body) as Map<String, dynamic>);
          return http.Response('{"ok":true}', 200);
        }), 'https://example.test'),
        () => 'session');
    const e = AiError('ইন্টারনেট ধীর, AI সময়মতো উত্তর দেয়নি।', 'timeout');
    ErrorLog.problem('AiError', e.code);
    ErrorLog.problem('AiError', e.code);
    ErrorLog.problem('Voice', 'error_network');
    // Kept in a file at once (a crash right now would not lose it).
    final saved = jsonDecode(File('${dir.path}/error_log_pending.json').readAsStringSync()) as List;
    expect(saved, hasLength(2));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(sent, hasLength(1));
    final items = (sent.single['items'] as List).cast<Map>();
    final ai = items.firstWhere((x) => x['kind'] == 'AiError');
    expect((ai['level'], ai['message'], ai['count'], ai['version']), ('problem', 'timeout', 2, '2.55.12'));
    expect(items.firstWhere((x) => x['kind'] == 'Voice')['message'], 'error_network');
    expect(jsonEncode(items), isNot(contains('ইন্টারনেট')));
    expect(ErrorLog.pending, isEmpty);
    expect(jsonDecode(File('${dir.path}/error_log_pending.json').readAsStringSync()), isEmpty);
    await dir.delete(recursive: true);
  });

  test('no internet: kept on the phone, and sent after the app opens again', () async {
    final dir = await Directory.systemTemp.createTemp('elog');
    ErrorLog.pending.clear();
    ErrorLog.delay = const Duration(milliseconds: 20);
    await ErrorLog.open(dir);
    ErrorLog.connect(AccountServer(MockClient((r) async => throw const SocketException('offline')), 'https://example.test'), () => '');
    ErrorLog.record(StateError('x'), null);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(ErrorLog.pending, hasLength(1));
    // The app is closed; next time it opens:
    ErrorLog.pending.clear();
    await ErrorLog.open(dir);
    expect(ErrorLog.pending.single['kind'], 'StateError');
    expect(ErrorLog.pending.single['level'], 'crash');
    ErrorLog.pending.clear();
    await dir.delete(recursive: true);
  });

  test('an Android crash left by MainActivity goes on the next start, cleaned', () async {
    final dir = await Directory.systemTemp.createTemp('elog');
    ErrorLog.pending.clear();
    File('${dir.path}/app_crash.json').writeAsStringSync(jsonEncode({
      'kind': 'Android:IllegalStateException',
      'message': 'Cannot open "রহিমের খাতা" for saif@gmail.com 01712345678',
      'stack': 'com.iamsaifsaiful.digital_brain.MainActivity.onCreate:120',
      'version': '2.55.12',
    }));
    await ErrorLog.open(dir);
    final e = ErrorLog.pending.single;
    expect((e['level'], e['kind'], e['version']), ('crash', 'Android:IllegalStateException', '2.55.12'));
    for (final secret in ['রহিম', 'saif@', '01712345678']) {
      expect('${e['message']}', isNot(contains(secret)));
    }
    expect(e['stack'], contains('MainActivity.onCreate:120'));
    expect(File('${dir.path}/app_crash.json').existsSync(), isFalse);
    ErrorLog.pending.clear();
    await dir.delete(recursive: true);
  });

  test('a ringing reminder is never cancelled when the app opens and sets the notices again (it went quiet in a second)', () {
    final daily = 1001, other = 1002, gone = 1003;
    final snooze = snoozeId('r-med');
    final pending = [(daily, 'r-med'), (other, 'r-bill'), (gone, 'r-old'), (snooze, 'r-med')];
    // The daily medicine reminder is on the screen, ringing.
    final cancel = idsToCancel(pending, live: {'r-med', 'r-bill'}, shown: {daily});
    expect(cancel, isNot(contains(daily)));
    expect(cancel, isNot(contains(snooze)));
    expect(cancel, containsAll([other, gone]));
    // Nothing on the screen: all but the snooze are cancelled and set again.
    expect(idsToCancel(pending, live: {'r-med', 'r-bill'}, shown: const {}), [daily, other, gone]);
  });
}
