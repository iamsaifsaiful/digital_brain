import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// What the AI understood: the fields of the `route` tool (see [_tool]).
typedef AiRoute = Map<String, Object?>;

/// What the app tells the AI besides the sentence. Never passwords, vault
/// items or note text: only names in the লেনদেন (money) book and category names.
class AiContext {
  const AiContext({required this.now, this.people = const [], this.categories = const []});
  final DateTime now;
  final List<String> people;
  final List<String> categories;
}

class AiError implements Exception {
  const AiError(this.message);

  /// Bengali, for the user.
  final String message;

  @override
  String toString() => message;
}

abstract class AiBrain {
  /// Understands [said]. Returns null when no key is set; throws [AiError]
  /// when the call fails.
  Future<AiRoute?> route(String said, AiContext ctx);

  /// The key in use (empty = AI off).
  String get key;
  set key(String value);
}

/// Claude Haiku over the Messages API.
class ClaudeAi implements AiBrain {
  ClaudeAi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String key = '';

  /// Newest first; the next one is tried if a model is not available.
  static const models = ['claude-haiku-5-5', 'claude-haiku-4-5'];
  int _model = 0;

  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  @override
  Future<AiRoute?> route(String said, AiContext ctx) async {
    if (key.trim().isEmpty) return null;
    while (true) {
      final res = await _post(said, ctx, models[_model]);
      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, Object?>;
        for (final block in (body['content'] as List? ?? const [])) {
          if (block is Map && block['type'] == 'tool_use' && block['input'] is Map) {
            return (block['input'] as Map).cast<String, Object?>();
          }
        }
        throw const AiError('AI-এর উত্তর বুঝতে পারিনি।');
      }
      final err = _errorText(res);
      if (res.statusCode == 404 && _model + 1 < models.length) {
        _model++;
        continue;
      }
      if (res.statusCode == 401) throw const AiError('API key ঠিক নেই। “আরও” থেকে key দেখে নিন।');
      if (res.statusCode == 429) throw const AiError('এই মুহূর্তে অনেক বেশি অনুরোধ হয়েছে। একটু পরে চেষ্টা করুন।');
      if (err.toLowerCase().contains('credit')) throw const AiError('API অ্যাকাউন্টে ক্রেডিট শেষ। platform.claude.com থেকে ক্রেডিট যোগ করুন।');
      debugPrint('AI error ${res.statusCode}: $err');
      throw AiError('AI সাড়া দেয়নি (${res.statusCode})।');
    }
  }

  Future<http.Response> _post(String said, AiContext ctx, String model) async {
    try {
      return await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'content-type': 'application/json',
              'x-api-key': key.trim(),
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': model,
              'max_tokens': 500,
              'system': systemPrompt(ctx),
              'tools': [_tool],
              'tool_choice': {'type': 'tool', 'name': 'route'},
              'messages': [
                {'role': 'user', 'content': said},
              ],
            }),
          )
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const AiError('ইন্টারনেট ধীর, AI সময়মতো উত্তর দেয়নি।');
    } catch (e) {
      throw const AiError('ইন্টারনেট সংযোগ পাওয়া যায়নি।');
    }
  }

  String _errorText(http.Response r) {
    try {
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
      return '${(j['error'] as Map?)?['message'] ?? r.body}';
    } catch (_) {
      return r.body;
    }
  }
}

/// The instructions sent with every sentence.
String systemPrompt(AiContext ctx) {
  final d = ctx.now;
  final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  return '''
You are the brain of "Digital Brain", a Bengali personal-memory app used in Bangladesh. The user speaks (speech-to-text, so expect mis-hearings) or types. Work out what they want and call the `route` tool once.

Understand every way people in Bangladesh talk: standard Bengali, Dhaka speech, regional dialects (Noakhali: টেয়া/টিয়া = টাকা; Chattogram: আঁই, গইজ্জি; Sylhet: কিতা, দিলাইছি; Barishal: মুই, মোরে; Rajshahi: দিনু, লিনু; Mymensingh…), Banglish in English letters ("Sajib ke 500 taka dilam"), and Bengali mixed with English words. Amounts may be in Bengali or English digits or words (দেড় হাজার, আড়াই শো, 2k).

Actions:
- ledger_add: a money event with a person. kind: lent (user gave a loan; they owe the user), borrowed (user took a loan), received (person paid the user back), repaid (user paid the person back), unclear (you cannot tell). Fill person and amount (0 if not said; person "" if not said).
- ledger_set: the user states a balance ("ইসমাইলের কাছে আমি ৫ হাজার টাকা পাই"). balance > 0: they owe the user; < 0: the user owes them.
- ledger_query: asks about balances. ask: person (fill person), receivable (who owes me), payable (whom I owe), all.
- vault_query: asks for a password/login/Wi-Fi. terms: the site/app name words. wifi true for Wi-Fi.
- reminder_query: asks when something is due. terms: key words.
- note_add: a fact to remember that is not about money ("ছাদের দরজার কোড ৪৫৬৭", "মনে রাখো …"). text: the fact as a clean Bengali sentence (keep numbers exactly). category: a short Bengali category; reuse one of the user's categories when it fits.
- search: asks for something the user saved earlier (a note, a contact's number, anything). terms: the key words.
- chat: conversation, greetings, how-are-you, thanks, or a general-knowledge question. reply: the answer.
Every sentence that mentions money (টাকা etc.) is ledger_add / ledger_set / ledger_query, never note_add.

Names: write the person's name in Bengali script as said, without endings (সজীবকে → সজীব, রহিমের → রহিম). If it matches one of the known people, use that exact spelling. Names in English letters stay in English with a capital letter.

reply (chat only): warm, natural Bangladeshi Bengali the way a polite friend talks, short (1–3 sentences), address the user as আপনি, no English unless the user used it. For general-knowledge questions answer briefly and correctly; if you are not sure, say so. Never ask for or repeat passwords or PINs. Today is $date.

Known people in the লেনদেন (money) book: ${ctx.people.isEmpty ? '(none)' : ctx.people.join(', ')}
User's note categories: ${ctx.categories.isEmpty ? '(none)' : ctx.categories.join(', ')}''';
}

const _tool = {
  'name': 'route',
  'description': 'What the user wants, with the details the app needs.',
  'input_schema': {
    'type': 'object',
    'properties': {
      'action': {
        'type': 'string',
        'enum': ['ledger_add', 'ledger_set', 'ledger_query', 'vault_query', 'reminder_query', 'note_add', 'search', 'chat'],
      },
      'person': {'type': 'string', 'description': 'Person name without case endings'},
      'amount': {'type': 'integer', 'description': 'Whole taka, 0 if not said'},
      'kind': {
        'type': 'string',
        'enum': ['lent', 'borrowed', 'received', 'repaid', 'unclear'],
      },
      'balance': {'type': 'integer', 'description': 'ledger_set: + they owe the user, - the user owes them'},
      'ask': {
        'type': 'string',
        'enum': ['person', 'receivable', 'payable', 'all'],
      },
      'terms': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'wifi': {'type': 'boolean'},
      'text': {'type': 'string', 'description': 'note_add: the fact'},
      'category': {'type': 'string', 'description': 'note_add: category'},
      'reply': {'type': 'string', 'description': 'chat: the spoken answer in Bengali'},
    },
    'required': ['action'],
  },
};

/// For tests and when AI is off.
class FakeAi implements AiBrain {
  FakeAi({this.answer, this.error});
  AiRoute? answer;
  AiError? error;
  final asked = <String>[];

  @override
  String key = '';

  @override
  Future<AiRoute?> route(String said, AiContext ctx) async {
    if (key.isEmpty) return null;
    asked.add(said);
    if (error != null) throw error!;
    return answer;
  }
}
