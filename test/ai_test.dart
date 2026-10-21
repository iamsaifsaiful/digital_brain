import 'dart:convert';

import 'package:digital_brain/services/ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response res(int code, Object body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), code, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  final ctx = AiContext(now: DateTime(2026, 10, 9), people: const ['সজীব'], categories: const ['ছাদ']);

  test('sends the sentence with the forced route tool and reads the tool input', () async {
    late Map<String, dynamic> sent;
    late Map<String, String> headers;
    final ai = ClaudeAi(
      client: MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        headers = req.headers;
        return res(200, {
          'content': [
            {'type': 'tool_use', 'id': 't1', 'name': 'route', 'input': {'action': 'chat', 'reply': 'ভালো আছি'}},
          ],
        });
      }),
    )..key = 'sk-ant-test';
    final r = await ai.route('কেমন আছো', ctx);
    expect(r!['reply'], 'ভালো আছি');
    // Haiku by default (21 Oct 2026 brief).
    expect(sent['model'], ClaudeAi.fastModels.first);
    // Haiku takes the forced tool (Sonnet 5.5, when escalated, is asked with auto).
    expect(sent['tool_choice'], {'type': 'tool', 'name': 'route'});
    expect(sent.containsKey('output_config'), isFalse);
    expect((sent['messages'] as List).single['content'], 'কেমন আছো');
    // The fixed rules are cached; the user's context comes after them.
    final system = sent['system'] as List;
    expect(system.first['cache_control'], {'type': 'ephemeral'});
    expect(system.last['text'], contains('সজীব'));
    expect(headers['x-api-key'], 'sk-ant-test');
    expect(headers['anthropic-version'], '2023-06-01');
  });

  test('phone, card and ID numbers and e-mails never leave the phone', () async {
    late String body;
    final ai = ClaudeAi(
      client: MockClient((req) async {
        body = req.body;
        return res(200, {
          'content': [
            {'type': 'tool_use', 'id': 't', 'name': 'route', 'input': {'reply': 'ঠিক আছে', 'items': []}},
          ],
        });
      }),
    )..key = 'sk-ant-test';
    final c = AiContext(now: DateTime(2026, 10, 9), people: const ['রহিম'], categories: const [], records: 'রহিমের নম্বর ০১৭১১-২২৩৩৪৪ · NID 1990123456789 · কার্ড 4111 1111 1111 1111 · rahim@example.com · ৫০০০ টাকা');
    await ai.route('আমার নম্বর +8801711223344, বাকি ১,০০,০০০ টাকা', c, history: const [AiTurn.user('ইমেইল saif@mail.com')]);
    final decoded = jsonDecode(body).toString();
    for (final n in ['০১৭১১-২২৩৩৪৪', '1990123456789', '4111 1111 1111 1111', 'rahim@example.com', '+8801711223344', 'saif@mail.com']) {
      expect(decoded, isNot(contains(n)), reason: n);
    }
    // Ordinary amounts stay.
    expect(decoded, contains('৫০০০'));
    expect(decoded, contains('১,০০,০০০'));
  });

  test('no key: AI is off', () async {
    final ai = ClaudeAi(client: MockClient((_) async => throw StateError('should not call')));
    expect(await ai.route('x', ctx), isNull);
  });

  test('a missing model falls back to the next one', () async {
    final models = <String>[];
    final ai = ClaudeAi(
      client: MockClient((req) async {
        final m = (jsonDecode(req.body) as Map)['model'] as String;
        models.add(m);
        if (m == ClaudeAi.escalationModels.first) return res(404, {'error': {'message': 'model not found'}});
        return res(200, {
          'content': [
            {'type': 'tool_use', 'id': 't', 'name': 'route', 'input': {'action': 'search', 'terms': ['ছাদ']}},
          ],
        });
      }),
    )..key = 'k';
    final r = await ai.route('ছাদের কোড', ctx, escalate: true);
    expect(r!['action'], 'search');
    expect(models, ClaudeAi.escalationModels.take(2).toList());
  });

  test('errors become Bengali messages', () async {
    final bad = ClaudeAi(client: MockClient((_) async => res(401, {'error': {'message': 'invalid x-api-key'}})))..key = 'k';
    await expectLater(bad.route('x', ctx), throwsA(isA<AiError>().having((e) => e.message, 'message', contains('key'))));
    final broke = ClaudeAi(client: MockClient((_) async => res(400, {'error': {'message': 'Your credit balance is too low'}})))..key = 'k';
    await expectLater(broke.route('x', ctx), throwsA(isA<AiError>().having((e) => e.message, 'message', contains('ক্রেডিট'))));
  });

  test('the conversation so far is sent as alternating turns', () {
    final m = messagesFor('আর ওর নম্বর?', const [
      AiTurn.app('[শুরু]'), // dropped: must start with the user
      AiTurn.user('সজীবকে ৫০০ দিলাম'),
      AiTurn.app('[রাখার আগে জিজ্ঞেস করছে]'),
      AiTurn.user('হ্যাঁ'),
    ]);
    expect([for (final x in m) x['role']], ['user', 'assistant', 'user', 'assistant', 'user']);
    expect(m.first['content'], 'সজীবকে ৫০০ দিলাম');
    expect(m.last['content'], 'আর ওর নম্বর?');
  });

  test('history goes into the request', () async {
    late Map<String, dynamic> sent;
    final ai = ClaudeAi(
      client: MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, dynamic>;
        return res(200, {
          'content': [
            {'type': 'tool_use', 'id': 't', 'name': 'route', 'input': {'reply': 'জি', 'items': []}},
          ],
        });
      }),
    )..key = 'k';
    await ai.route('আরও কিছু?', ctx, history: const [AiTurn.user('হ্যালো'), AiTurn.app('জি বলুন')]);
    expect((sent['messages'] as List), hasLength(3));
    final tool = (sent['tools'] as List).single as Map;
    expect(((tool['input_schema'] as Map)['properties'] as Map).keys, containsAll(['reply', 'items']));
  });

  // Changed 21 Oct 2026 (brief, step A): Haiku is the default for every
  // message; Sonnet only by escalation (test/ai_cost_test.dart).
  test('Haiku is used by default and the money summary goes in the instructions', () {
    final ai = ClaudeAi();
    expect(ai.quality, AiQuality.fast);
    expect(ClaudeAi.fastModels.first, 'claude-haiku-5-5');
    expect(ClaudeAi.escalationModels.first, 'claude-sonnet-5-5');
    final p = systemPrompt(AiContext(now: DateTime(2026, 10, 9), money: 'রহিম: owes the user 4000'));
    expect(p, contains('রহিম: owes the user 4000'));
    expect(p, contains('ask ONE short question'));
  });

  test('a forced-tool refusal is retried with auto; a plain-text answer becomes the reply', () async {
    final sent = <Map<String, dynamic>>[];
    final ai = ClaudeAi(
      client: MockClient((req) async {
        final b = jsonDecode(req.body) as Map<String, dynamic>;
        sent.add(b);
        if ((b['tool_choice'] as Map)['type'] == 'tool') {
          return res(400, {'error': {'message': 'tool_choice: type "tool" and "any" are not supported for this model.'}});
        }
        return res(200, {
          'content': [
            {'type': 'thinking', 'thinking': '…'},
            {'type': 'text', 'text': 'জি, ভালো আছি।'},
          ],
        });
      }),
    )
      ..key = 'k'
      ..quality = AiQuality.fast;
    final r = await ai.route('কেমন আছো', ctx);
    expect(r!['reply'], 'জি, ভালো আছি।');
    expect(sent.first['tool_choice'], {'type': 'tool', 'name': 'route'});
    expect(sent.last['tool_choice'], {'type': 'auto'});
  });

  test('a spoken turn uses the quick model', () async {
    late Map<String, Object?> sent;
    final ai = ClaudeAi(
      client: MockClient((req) async {
        sent = jsonDecode(req.body) as Map<String, Object?>;
        return http.Response(jsonEncode({
          'content': [
            {'type': 'tool_use', 'name': 'route', 'input': {'reply': 'জি', 'items': []}},
          ],
        }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }),
    )..key = 'sk-ant-test';
    await ai.route('কেমন আছো', AiContext(now: DateTime(2026, 10, 14)), fast: true);
    expect(sent['model'], ClaudeAi.fastModels.first);
  });
}
