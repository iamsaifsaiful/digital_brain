// কোম্পানির পরিসংখ্যান (owner, 24 Nov): the app counts which parts were
// opened and how fast it opened, sends that with the account refresh (on by
// default), and nothing at all once "ব্যবহারের হিসাব পাঠান" is off.
import 'dart:convert';

import 'package:digital_brain/logic/app_stats.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/crypto.dart' show MemoryKeyVault;
import 'package:digital_brain/services/google_account.dart';
import 'package:digital_brain/state/brain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'app_test.dart';

void main() {
  setUp(() {
    AppStats.on = true;
    AppStats.clear();
    AppStats.now = () => DateTime(2026, 11, 24, 10);
  });

  test('parts opened: once a day each, only known names, nothing when off', () {
    AppStats.open('money');
    AppStats.open('money');
    AppStats.open('notes');
    AppStats.open('রহিমকে ৫০০ টাকা'); // never text
    AppStats.started(1450);
    AppStats.started(9000); // the first open of the day counts
    AppStats.now = () => DateTime(2026, 11, 25, 9);
    AppStats.open('health');
    expect(AppStats.days(), [
      {'d': '2026-11-24', 'o': ['money', 'notes'], 'st': 1450},
      {'d': '2026-11-25', 'o': ['health']},
    ]);
    // Saved and read back on the next start, added to what this start kept.
    final saved = AppStats.save();
    AppStats.clear();
    AppStats.started(1200);
    AppStats.restore(saved);
    expect(AppStats.days().last, {'d': '2026-11-25', 'o': ['health'], 'st': 1200});
    expect(AppStats.days().first['st'], 1450);
    // Sent: the days before today are done; today keeps growing.
    AppStats.sent();
    expect(AppStats.days().map((d) => d['d']), ['2026-11-25']);
    AppStats.on = false;
    AppStats.clear();
    AppStats.open('money');
    AppStats.started(800);
    expect(AppStats.isEmpty, isTrue);
  });

  test('sent with the account refresh; a new install says "first open" once; off sends nothing', () async {
    final calls = <http.Request>[];
    final client = MockClient((r) async {
      calls.add(r);
      if (r.url.path.endsWith('/login')) {
        return http.Response(jsonEncode({'ok': true, 'trial_used': true, 'pro_until': null, 'pro_kind': '', 'session': 'a' * 64, 'ai': false, 'ai_left': 0}), 200);
      }
      if (r.url.path.endsWith('/me')) {
        return http.Response(jsonEncode({'ok': true, 'trial_used': true, 'pro_until': null, 'pro_kind': '', 'ai': false, 'ai_left': 0}), 200);
      }
      if (r.url.path.endsWith('/stats') || r.url.path.endsWith('/stats/first-open')) return http.Response('{"ok":true}', 200);
      return http.Response('{}', 404);
    });
    final google = FakeGoogle()..user = const GoogleUser(id: '1', email: 'a@gmail.com', name: 'রহিম', idToken: 'token-from-google');
    final vault = MemoryKeyVault()..values['trial_start'] = '2000-01-01T00:00:00.000';
    final server = AccountServer(client, 'https://example.test');
    final rig = Rig(keys: vault, server: server, google: google);
    final b = rig.brain;
    b.whereCountry = () async => 'BD';
    await b.load();
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((r) => r.url.path.endsWith('/stats/first-open')).length, 1, reason: 'a new install tells once');
    expect(b.statsOn, isTrue, reason: 'on by default (owner)');
    expect(await b.signInGoogle(appVersion: '1.0.15'), isNull);
    await b.saveNote(Note(title: 'গোপন কথা', body: 'রহিমের ফোন ০১৭১১২২৩৩৪৪'));
    AppStats.now = () => rig.nowAt;
    AppStats.open('money');
    AppStats.open('notes');
    calls.clear();
    await b.refreshAccount(force: true);
    await Future<void>.delayed(Duration.zero);
    final sent = calls.where((r) => r.url.path.endsWith('/stats')).toList();
    expect(sent, hasLength(1));
    expect(sent.single.headers['authorization'], 'Bearer ${'a' * 64}');
    final body = jsonDecode(sent.single.body) as Map<String, dynamic>;
    expect(body['days'], isA<List>());
    expect((body['days'] as List).last['o'], ['money', 'notes']);
    expect(body['lang'], 'bn');
    expect(body['country'], 'BD');
    expect(body['biz'], isFalse);
    expect(body['items'], isTrue);
    expect(body.keys.toSet(), {'days', 'brand', 'android', 'lang', 'country', 'biz', 'items'});
    for (final word in ['রহিম', 'গোপন', '০১৭১১', 'a@gmail.com']) {
      expect(sent.single.body.contains(word), isFalse, reason: '$word never leaves the phone');
    }

    // The same phone started again: no second "first open".
    calls.clear();
    final again = Rig(keys: vault, blob: rig.blob, server: server, google: google);
    await again.brain.load();
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((r) => r.url.path.endsWith('/stats/first-open')), isEmpty);

    // Turned off: kept days go, nothing is counted or sent.
    await b.setStatsOn(false);
    expect(b.statsOn, isFalse);
    AppStats.open('money');
    expect(AppStats.isEmpty, isTrue);
    calls.clear();
    await b.refreshAccount(force: true);
    await Future<void>.delayed(Duration.zero);
    expect(calls.where((r) => r.url.path.contains('/stats')), isEmpty);
    await b.setStatsOn(true);
    expect(b.statsOn, isTrue);
  });
}
