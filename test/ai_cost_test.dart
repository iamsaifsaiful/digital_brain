// Step A of the 21 Oct 2026 brief: Haiku for every message (typed and spoken
// alike), Sonnet only when Haiku could not make one out and only for Pro; the
// fixed instructions cached, the changing part last, six turns of history
// with the list last shown always sent; where each answer came from counted.
import 'dart:convert';

import 'package:digital_brain/logic/ai_safe.dart';
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/ai.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'app_test.dart' show start;

http.Response ok() => http.Response(
    jsonEncode({
      'content': [
        {'type': 'tool_use', 'name': 'route', 'input': {'reply': 'জি', 'items': []}},
      ],
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  final ctx = AiContext(now: DateTime(2026, 10, 21, 10), money: 'রহিম: owes the user 4000', shown: 'to-dos (আজ):\n1. বাজার করা');

  test('typed and spoken: the same model (Haiku); escalation asks Sonnet', () async {
    final models = <String>[];
    final ai = ClaudeAi(client: MockClient((req) async {
      models.add((jsonDecode(req.body) as Map)['model'] as String);
      return ok();
    }))
      ..key = 'k';
    await ai.route('কেমন আছো', ctx);
    await ai.route('কেমন আছো', ctx, fast: true);
    await ai.route('কেমন আছো', ctx, escalate: true);
    expect(models, ['claude-haiku-5-5', 'claude-haiku-5-5', 'claude-sonnet-5-5']);
    expect(ai.lastModel, 'claude-sonnet-5-5');
  });

  test('the fixed part (rules, app map, folders) is the cached block; time, money and the list shown come after', () async {
    late Map<String, dynamic> sent;
    final ai = ClaudeAi(client: MockClient((req) async {
      sent = jsonDecode(req.body) as Map<String, dynamic>;
      return ok();
    }))
      ..key = 'k';
    await ai.route('৩নং টা মুছে দাও', ctx);
    final system = sent['system'] as List;
    final fixed = system.first as Map, rest = system.last as Map;
    expect(fixed['cache_control'], {'type': 'ephemeral'});
    expect(fixed['text'], contains("The app's parts"));
    expect(fixed['text'], contains('Paper folders'));
    expect(fixed['text'], isNot(contains('2026-10-21')), reason: 'nothing that changes in the cached block');
    expect(rest.containsKey('cache_control'), isFalse);
    expect(rest['text'], contains('2026-10-21 10:00'));
    expect(rest['text'], contains('রহিম: owes the user 4000'));
    expect(rest['text'], contains('1. বাজার করা'));
    expect(rest['text'], isNot(contains("The app's parts")));
  });

  test('history: the last 6 turns only', () {
    final h = [for (var i = 0; i < 20; i++) i.isEven ? AiTurn.user('u$i') : AiTurn.app('a$i')];
    final m = messagesFor('এখন', h);
    final all = m.map((x) => x['content']).join(' ');
    expect(all, isNot(contains('u12')));
    expect(all, contains('u14'));
    expect(all, contains('a19'));
  });

  testWidgets('Haiku could not make it out: Sonnet once, for Pro — not for a free user', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 21, 10);
    rig.ai.key = 'k';
    // Haiku's reading gives nothing to act on.
    rig.ai.answer = {'reply': '', 'items': []};
    rig.ai.escalatedAnswer = {
      'reply': 'রাখলাম',
      'items': [
        {'action': 'note_add', 'text': 'ছাদের চাবি মায়ের কাছে', 'category': 'বাসা'},
      ],
    };
    final (cmds, _) = await rig.brain.understandAll('ছাদের চাবিটা মায়ের কাছে থাকে, মনে রেখো কিন্তু');
    expect(rig.ai.escalated, [false, true]);
    expect(cmds.whereType<NoteAdd>(), isNotEmpty);
    final today = rig.brain.answerSources.values.last;
    expect(today['sonnet'], 1);
  });

  testWidgets('a spoken turn goes the same way as a typed one (no forced quick model)', (t) async {
    final rig = await start(t);
    rig.ai.key = 'k';
    rig.ai.answer = {'reply': 'জি', 'items': []};
    final chat = ChatController(rig.brain)..voiceMode = true;
    await chat.hear('আমাকে একটা গল্প বলো তো');
    expect(rig.ai.fastAsked, isNotEmpty);
    expect(rig.ai.fastAsked.every((f) => f == false), isTrue);
  });

  testWidgets('the list last shown reaches the AI, numbered as shown', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 21, 10);
    rig.brain.data = AppData(tasks: [
      Task(id: 'a', title: 'বাজার করা', due: DateTime(2026, 10, 21)),
      Task(id: 'b', title: 'ব্যাংকে যাওয়া', due: DateTime(2026, 10, 22)),
    ]);
    rig.ai.key = 'k';
    rig.ai.answer = {'reply': 'জি', 'items': []};
    final chat = ChatController(rig.brain);
    await chat.hear('আমার কাজের তালিকা দাও');
    await chat.hear('তুমি কি গান গাইতে পারো');
    expect(rig.ai.contexts, isNotEmpty);
    final shown = rig.ai.contexts.last.shown;
    expect(shown, contains('1. বাজার করা'));
    expect(shown, contains('2. ব্যাংকে যাওয়া'));
  });

  test('dates the app writes reach the AI; phone numbers still do not', () {
    final s = redactForAi('Now is 2026-10-21 10:00. রহিম 01711223344, কার্ড 4111 1111 1111 1111, due 2026-10-25');
    expect(s, contains('2026-10-21 10:00'));
    expect(s, contains('2026-10-25'));
    expect(s, isNot(contains('01711223344')));
    expect(s, isNot(contains('4111 1111')));
  });

  testWidgets('every answer is counted by where it came from — rules too; no words kept', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 21, 10);
    final chat = ChatController(rig.brain);
    await chat.hear('কাল সকাল ৯টায় ব্যাংকে যাব');
    final day = rig.brain.answerSources['2026-10-21']!;
    expect(day['rules'], greaterThanOrEqualTo(1));
    final kept = jsonEncode(rig.brain.answerSources);
    expect(kept, isNot(contains('ব্যাংক')));
  });
}
