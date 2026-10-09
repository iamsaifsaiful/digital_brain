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
    expect(sent['model'], ClaudeAi.models.first);
    expect(sent['tool_choice'], {'type': 'tool', 'name': 'route'});
    expect((sent['messages'] as List).single['content'], 'কেমন আছো');
    expect(sent['system'], contains('সজীব'));
    expect(headers['x-api-key'], 'sk-ant-test');
    expect(headers['anthropic-version'], '2023-06-01');
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
        if (m == ClaudeAi.models.first) return res(404, {'error': {'message': 'model not found'}});
        return res(200, {
          'content': [
            {'type': 'tool_use', 'id': 't', 'name': 'route', 'input': {'action': 'search', 'terms': ['ছাদ']}},
          ],
        });
      }),
    )..key = 'k';
    final r = await ai.route('ছাদের কোড', ctx);
    expect(r!['action'], 'search');
    expect(models, ClaudeAi.models);
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
}
