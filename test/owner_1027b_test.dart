// সমস্যার লগ (owner, 27 Oct): "ইউজারের ফোন থেকে সরাসরি এখানে আসবে" —
// handled problems too, sent within seconds, kept on the phone until sent,
// and an Android crash sent on the next start.
import 'dart:convert';
import 'dart:io';

import 'package:digital_brain/services/ai.dart';
import 'package:digital_brain/services/error_log.dart';
import 'package:digital_brain/services/family_crypto.dart' show FamilyKeys, safetyCode;
import 'package:digital_brain/services/google_account.dart';

import 'package:digital_brain/services/notifications.dart' show idsToCancel, snoozeId;
import 'package:digital_brain/logic/ai_safe.dart';
import 'package:digital_brain/logic/proactive.dart';
import 'package:digital_brain/logic/server_notices.dart';
import 'package:digital_brain/models/extras.dart' show Medicine;
import 'package:digital_brain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig;
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

  test('health stays on the phone: medicine, doctor or illness items never reach the AI', () {
    expect(mentionsHealth('ডায়াবেটিসের ওষুধ খাওয়া'), isTrue);
    expect(mentionsHealth('ডাক্তারের সাথে দেখা'), isTrue);
    expect(mentionsHealth('Take BP tablet'), isTrue);
    expect(mentionsHealth('মেটফরমিন ৫০০', extra: ['মেটফরমিন']), isTrue);
    expect(mentionsHealth('বাজার করা'), isFalse);
    expect(mentionsHealth('বিদ্যুৎ বিল দেওয়া'), isFalse);
    final rig = Rig();
    final b = rig.brain;
    b.data.medicines.add(Medicine(name: 'Metformin'));
    b.data.reminders.addAll([
      Reminder(title: 'ডায়াবেটিসের ওষুধ', date: DateTime(2026, 10, 27), hour: 9),
      Reminder(title: 'Metformin 500', date: DateTime(2026, 10, 27), hour: 21),
      Reminder(title: 'বিদ্যুৎ বিল', date: DateTime(2026, 10, 28), hour: 10),
    ]);
    b.data.tasks.add(Task(title: 'ডাক্তারের অ্যাপয়েন্টমেন্ট নেওয়া'));
    b.data.notes.add(Note(title: 'প্রেশার', body: 'সকালে ১৪০/৯০'));
    final ctx = b.aiContext(now: DateTime(2026, 10, 27, 8)).records;
    expect(ctx, contains('বিদ্যুৎ বিল'));
    for (final secret in ['ডায়াবেটিস', 'Metformin', 'ডাক্তার', 'প্রেশার', '১৪০']) {
      expect(ctx, isNot(contains(secret)), reason: secret);
    }
    expect(ctx, contains('kept on the phone only: 3'));
  });

  test('family safety code: the same on both phones; a swapped key gives another', () async {
    final a = await FamilyKeys.generate(), b = await FamilyKeys.generate(), mallory = await FamilyKeys.generate();
    final onA = await safetyCode(a.publicB64, b.publicB64);
    final onB = await safetyCode(b.publicB64, a.publicB64);
    expect(onA, onB);
    expect(RegExp(r'^\d{4}( \d{4}){4}$').hasMatch(onA), isTrue, reason: onA);
    // Our server (or anyone in between) gave A a different key for B.
    expect(await safetyCode(a.publicB64, mallory.publicB64), isNot(onA));
  });

  test('the admin controls the app\'s own notifications: off, who, time, wording, how many', () {
    final now = DateTime(2026, 10, 27, 6); // Tuesday morning
    final d = AppData();
    String quoteTitle(List<dynamic> l) => l.firstWhere((n) => n.reminderId == nudgeQuote).title as String;
    final plain = assistantNotices(d, now, const AssistantPrefs(name: 'সাইফ'));
    final today = plain.where((n) => n.at.day == 27).toList();
    expect(today.any((n) => n.reminderId == morningTag), isTrue);
    expect(today.firstWhere((n) => n.reminderId == nudgeQuote).at.hour, 9);
    // Morning brief only for new members; the quote at 7:30 with the admin's wording.
    const rules = NoticeRules(kinds: {
      'brief:morning': NoticeRule(who: 'new'),
      'nudge:quote': NoticeRule(at: '07:30', title: '{name}, আজকের ভাবনা: {title}'),
    });
    final old = assistantNotices(d, now, const AssistantPrefs(name: 'সাইফ', rules: rules, groups: {'all', 'old', 'regular', 'free'}));
    expect(old.where((n) => n.at.day == 27).any((n) => n.reminderId == morningTag), isFalse, reason: 'not for older members');
    final q = old.firstWhere((n) => n.reminderId == nudgeQuote && n.at.day == 27);
    expect((q.at.hour, q.at.minute), (7, 30));
    expect(q.title, 'সাইফ, আজকের ভাবনা: আজকের অর্থ-কথা');
    final fresh = assistantNotices(d, now, const AssistantPrefs(rules: rules, groups: {'all', 'new', 'occasional', 'free'}));
    expect(fresh.where((n) => n.at.day == 27).any((n) => n.reminderId == morningTag), isTrue, reason: 'new members still get it');
    // Off for everyone.
    final off = assistantNotices(d, now, const AssistantPrefs(rules: NoticeRules(kinds: {'nudge:quote': NoticeRule(on: false)})));
    expect(off.any((n) => n.reminderId == nudgeQuote), isFalse);
    // The member's own morning time stays theirs.
    final own = assistantNotices(d, now, const AssistantPrefs(morningAt: 6 * 60 + 30, rules: NoticeRules(kinds: {'brief:morning': NoticeRule(at: '09:00')})));
    expect(own.firstWhere((n) => n.reminderId == morningTag && n.at.day == 27).at.hour, 6);
    expect(quoteTitle(plain), 'আজকের অর্থ-কথা');
  });

  test('member groups come from this phone\'s own use', () {
    final now = DateTime(2026, 10, 27, 10);
    final g1 = memberGroups(now: now, firstUse: DateTime(2026, 10, 24), openDays: [DateTime(2026, 10, 25), DateTime(2026, 10, 27)], pro: false);
    expect(g1, {'all', 'new', 'occasional', 'free'});
    final g2 = memberGroups(now: now, firstUse: DateTime(2026, 9, 1), openDays: [for (var i = 0; i < 6; i++) DateTime(2026, 10, 27 - i * 2)], pro: true);
    expect(g2, {'all', 'old', 'regular', 'pro'});
    final r = NoticeRules.fromJson({'kinds': {'nudge:prayer': {'on': false}}, 'cap': 1});
    expect(r.forTag('nudge:prayer:fajr')?.on, isFalse);
    expect(r.cap, 1);
    expect(NoticeRules.fromJson(NoticeRules.fromJson({'kinds': {'nudge:quote': {'at': '07:30'}}}).toJson()).forTag('nudge:quote')?.minutes, 450);
  });

  test('the site asks for a newer app at sign-in: the member is told, with where; the phone keeps working', () async {
    final rig = Rig(
        server: AccountServer(MockClient((r) async => http.Response(jsonEncode({'code': 'update', 'data': {'status': 426, 'min': '2.56.0', 'url': 'https://getmyassistant.app/app'}}), 426)), 'https://example.test'),
        google: FakeGoogle()..user = GoogleUser(id: '1', email: 'test@gmail.com', name: 'Test', idToken: 'google-token'));
    await rig.brain.load();
    final msg = await rig.brain.signInGoogle();
    expect(msg, contains('2.56.0'));
    expect(rig.brain.updateUrl, 'https://getmyassistant.app/app');
  });
}
