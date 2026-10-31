import 'dart:convert';

import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/logic/plan.dart' show parseAll;
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/nlu/labels.dart';
import 'package:digital_brain/nlu/reader.dart';
import 'package:digital_brain/nlu/router.dart';
import 'package:digital_brain/services/ai.dart';
import 'package:digital_brain/services/google_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'app_test.dart' show Rig;

NluPiece piece(String intent, {double conf = 0.95, bool sure = true, Map<String, String> slots = const {}}) => NluPiece(intent, conf, sure, const [], slots);

CloudReading cloud(List<(String, Map<String, String>)> p, [double sure = 0.9]) => CloudReading(p, sure);

void main() {
  final now = DateTime(2026, 10, 22, 10);

  test('agreement: same intents, any order; talk never skips the AI', () {
    expect(nluAgrees([piece('task_add'), piece('reminder_add')], ['reminder_add', 'task_add']), isTrue);
    expect(nluAgrees([piece('task_add')], ['task_add', 'reminder_add']), isFalse);
    expect(nluAgrees(const [], const []), isFalse);
    expect(nluMaySkipAi([piece('cash_add')], ['cash_add']), isTrue);
    expect(nluMaySkipAi([piece('smalltalk')], ['smalltalk']), isFalse, reason: 'the AI talks better');
    expect(nluMaySkipAi(null, ['cash_add']), isFalse, reason: 'no model reading');
    expect(nluMaySkipAi([piece('note_add')], ['cash_add']), isFalse);
  });

  test('two readings of three decide; otherwise the rules', () {
    final model = [piece('cash_add')];
    expect(nluVote(['note_add'], model, cloud([('cash_add', {})])), 'cloud', reason: 'cloud = model');
    expect(nluVote(['note_add'], model, cloud([('cash_add', {})], 0.3)), 'rules', reason: 'cloud unsure');
    expect(nluVote(['ledger_add'], model, cloud([('ledger_add', {})])), 'rules', reason: 'cloud = rules');
    expect(nluVote(['ledger_add'], model, cloud([('note_add', {})])), 'rules', reason: 'all three differ, the rules understood something');
    expect(nluVote(['none'], model, cloud([('task_query', {})], 0.8)), 'cloud', reason: 'the rules understood nothing');
    expect(nluVote(['none'], model, cloud([('none', {})])), 'rules');
  });

  test('a cloud reading becomes the app\'s own commands; names put back', () {
    final c = commandsFromReading(
      'রহিমকে ৫০০ টাকা দিলাম',
      cloud([('ledger_add', {'person': '<নাম১>', 'amount': '৫০০ টাকা'})]),
      [LedgerEntry(person: 'রহিম', amount: 100, kind: LedgerKind.lent, date: now)],
      now,
      names: {'<নাম১>': 'রহিম'},
    )!;
    final l = c.single as LedgerAdd;
    expect(l.person, 'রহিম');
    expect(l.amount, 500);
    expect(l.options, isNotEmpty, reason: 'who gave whom is asked, never guessed');

    final t = commandsFromReading('কাল বাজার করতে হবে', cloud([('task_add', {'title': 'বাজার করতে', 'date': 'কাল'})]), const [], now)!.single as TaskAdd;
    expect(t.title, 'বাজার করতে');
    expect(t.due, DateTime(2026, 10, 23));

    final e = commandsFromReading('রিকশা ভাড়া ৮০ টাকা খরচ', cloud([('cash_add', {'amount': '৮০ টাকা', 'cash_kind': 'খরচ'})]), const [], now)!.single as CashAdd;
    expect((e.kind, e.amount), (CashKind.expense, 80));
  });

  test('anything not made safely: null (the rules are used)', () {
    expect(commandsFromReading('x', cloud([('menu_zakat', {})]), const [], now), isNull, reason: 'not supported');
    expect(commandsFromReading('কাল', cloud([('task_add', {'title': 'কিছু', 'date': 'ঝড়বৃষ্টি'})]), const [], now), isNull, reason: 'a date span that is no date');
    expect(commandsFromReading('৫০০', cloud([('cash_add', {'amount': '৫০০'})]), const [], now), isNull, reason: 'income or expense unclear');
    expect(commandsFromReading('প্রতিদিন ৮টায় ওষুধ', cloud([('reminder_add', {'repeat': 'প্রতিদিন'})]), const [], now), isNull);
    expect(commandsFromReading('x', cloud([('task_add', {'title': 'ক'}), ('open_page', {})]), const [], now), isNull, reason: 'one piece unsafe → all');
  });

  group('the router in the app', () {
    // A sentence the rules only half understand (checked below).
    const said = 'তুবাকে পাঁচশো টাকা দিয়েছি গতকাল';

    Rig rigWith(List<http.Request> calls, Map<String, Object?> answer) {
      final rig = Rig(
          server: AccountServer(
              MockClient((r) async {
                calls.add(r);
                if (r.url.path.endsWith('/nlu/resolve')) return http.Response.bytes(utf8.encode(jsonEncode(answer)), 200);
                return http.Response('{}', 404);
              }),
              'https://example.test'));
      rig.brain.gated = true; // no AI of the user's own, not Pro
      rig.services.ai.session = 's' * 64;
      rig.brain.nluMode = 'on';
      rig.brain.data = AppData(ledger: [LedgerEntry(person: 'তুবা', amount: 100, kind: LedgerKind.lent, date: now)]);
      return rig;
    }

    test('free member, rules and model disagree: the cloud is asked, names taken out; the cloud sides with the rules', () async {
      final calls = <http.Request>[];
      final rig = rigWith(calls, {
        'pieces': [
          {'intent': 'ledger_add', 'slots': [{'name': 'person', 'words': '<নাম১>কে'}, {'name': 'amount', 'words': 'পাঁচশো টাকা'}]}
        ],
        'sure': 0.9,
      });
      final b = rig.brain..nluSamplesOn = false; // on by default (31 Oct); this member turned it off
      expect(intentsOfCommands(parseAll(said, b.data.ledger, now: DateTime.now())), ['ledger_add']);
      final (cmds, _) = await b.understandAll(said, model: Future.value([piece('cash_add')]), nluState: 'idle');
      final asked = calls.where((r) => r.url.path.endsWith('/nlu/resolve')).toList();
      expect(asked, hasLength(1));
      final body = jsonDecode(asked.single.body) as Map;
      expect(body['text'], 'তুবাকে পাঁচশো টাকা দিয়েছি গতকাল'.replaceAll('তুবা', '<নাম১>'), reason: 'names never leave');
      expect(body['top'], [{'intent': 'cash_add', 'conf': 0.95}]);
      expect(body.containsKey('consent_ver'), isFalse, reason: 'no consent, no sample');
      expect(cmds.single, isA<LedgerAdd>(), reason: 'cloud = rules: the rules\' reading');
      expect(b.answerSources.values.expand((m) => m.keys), contains('nlu_cloud_rules'));
    });

    test('free member: the cloud agrees with the model (two of three) → its reading is used', () async {
      const lost = 'ফ্লাস্কটা কোথায় রাখলাম মনে নেই';
      final calls = <http.Request>[];
      final rig = rigWith(calls, {
        'pieces': [
          {'intent': 'note_add', 'slots': [{'name': 'text', 'words': lost}]}
        ],
        'sure': 0.8,
      });
      final b = rig.brain;
      expect(intentsOfCommands(parseAll(lost, b.data.ledger, now: DateTime.now())), ['note_query']);
      final (cmds, _) = await b.understandAll(lost, model: Future.value([piece('note_add')]));
      expect(cmds.single, isA<NoteAdd>());
      expect((cmds.single as NoteAdd).text, lost);
      expect(b.answerSources.values.expand((m) => m.keys), contains('nlu_cloud'));
    });

    test('the cloud fails or is over its limit: the rules, nothing lost', () async {
      final rig = Rig(server: AccountServer(MockClient((r) async => http.Response('{"code":"limit"}', 429)), 'https://example.test'));
      rig.brain
        ..gated = true
        ..nluMode = 'on';
      rig.services.ai.session = 's' * 64;
      const lost = 'ফ্লাস্কটা কোথায় রাখলাম মনে নেই';
      final (cmds, _) = await rig.brain.understandAll(lost, model: Future.value([piece('note_add')]));
      expect(cmds.single, isA<SearchQuery>());
      expect(rig.brain.answerSources.values.expand((m) => m.keys), contains('nlu_cloud_fail'));
    });

    test('they agree: no cloud, no AI', () async {
      final calls = <http.Request>[];
      final rig = rigWith(calls, const {});
      final b = rig.brain;
      final rules = intentsOfCommands(parseAll(said, b.data.ledger, now: DateTime.now()));
      await b.understandAll(said, model: Future.value([for (final i in rules) piece(i)]));
      expect(calls.where((r) => r.url.path.endsWith('/nlu/resolve')), isEmpty);
    });

    test('a secret, a phone number or health words never go to the cloud', () async {
      final calls = <http.Request>[];
      final rig = rigWith(calls, const {'pieces': [], 'sure': 0});
      for (final s in ['আমার জিমেইলের পাসওয়ার্ড কী', 'রহিমের নম্বর ০১৭১১২২৩৩৪৪', 'প্রেশারের ওষুধ খেলাম দুপুরে']) {
        await rig.brain.understandAll(s, model: Future.value([piece('out_of_scope')]));
      }
      expect(calls.where((r) => r.url.path.endsWith('/nlu/resolve')), isEmpty);
    });

    test('the rules make a new reminder, the model is very sure it is a question: the question (owner, 31 Oct)', () async {
      const ask = 'আজকের রিমাইন্ডার দাও';
      final calls = <http.Request>[];
      final rig = rigWith(calls, const {});
      final b = rig.brain;
      final rules = parseAll(ask, b.data.ledger, now: DateTime.now());
      if (rules.single is! ReminderAdd) {
        markTestSkipped('the rules read this one right now');
        return;
      }
      var (cmds, _) = await b.understandAll(ask, model: Future.value([piece('reminder_query', conf: 0.94)]));
      expect(cmds.single, isA<ReminderQuery>());
      expect(b.answerSources.values.expand((m) => m.keys), contains('nlu_phone_query'));
      // Not sure enough, or not a question: the rules.
      (cmds, _) = await b.understandAll(ask, model: Future.value([piece('reminder_query', conf: 0.6)]));
      expect(cmds.single, isA<ReminderAdd>());
      (cmds, _) = await b.understandAll('কাল সকালে ব্যাংকে যাব', model: Future.value([piece('reminder_delete', conf: 0.99)]));
      expect(cmds.single, isNot(isA<ReminderQuery>()));
      expect(calls.where((r) => r.url.path.endsWith('/nlu/resolve')), isEmpty, reason: 'decided on the phone');
    });

    test('shadow mode: the model changes nothing', () async {
      final calls = <http.Request>[];
      final rig = rigWith(calls, const {});
      rig.brain.nluMode = 'shadow';
      await rig.brain.understandAll(said, model: Future.value([piece('menu_zakat')]));
      expect(calls, isEmpty);
    });

    test('with the AI: an agreed action is not sent to the AI (cost); talk still is', () async {
      final rig = Rig();
      final b = rig.brain;
      final ai = rig.services.ai as FakeAi;
      ai.key = 'k';
      b.nluMode = 'on';
      expect(b.aiOn, isTrue);
      const money = 'বাজারে ২০০ টাকা খরচ হলো';
      final rules = intentsOfCommands(parseAll(money, b.data.ledger, now: DateTime.now()));
      expect(rules, ['cash_add']);
      await b.understandAll(money, model: Future.value([piece('cash_add')]));
      expect(ai.asked, isEmpty, reason: 'rules and model agree on an action');
      await b.understandAll(money, model: Future.value([piece('note_add')]));
      expect(ai.asked, hasLength(1), reason: 'they disagree: asked as before');
      b.nluMode = 'shadow';
      await b.understandAll(money, model: Future.value([piece('cash_add')]));
      expect(ai.asked, hasLength(2), reason: 'shadow: as before');
    });
  });
}
