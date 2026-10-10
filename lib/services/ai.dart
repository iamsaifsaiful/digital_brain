import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// What the AI understood: the fields of the `route` tool (see [_tool]).
typedef AiRoute = Map<String, Object?>;

/// What the app tells the AI besides the sentence. Never passwords, vault
/// items or note text: only names in the লেনদেন (money) book and category names.
class AiContext {
  const AiContext({required this.now, this.people = const [], this.categories = const [], this.money = ''});
  final DateTime now;
  final List<String> people;
  final List<String> categories;

  /// A short summary of the money book (who owes what, this month's income
  /// and spending, projects) so the AI can answer and advise in its own
  /// words. Never passwords, notes, tasks or phone numbers.
  final String money;
}

/// Which Claude model reads the user's words.
enum AiQuality {
  /// Sonnet: understands far better (dialects, long mixed sentences); costs more.
  best,

  /// Haiku: quicker and cheaper.
  fast,
}

/// One earlier turn of the conversation, as the AI may see it. App turns
/// that came from the user's saved data are replaced by a short tag, so
/// nothing stored on the phone is sent.
class AiTurn {
  const AiTurn.user(this.text) : fromUser = true;
  const AiTurn.app(this.text) : fromUser = false;
  final bool fromUser;
  final String text;
}

class AiError implements Exception {
  const AiError(this.message);

  /// Bengali, for the user.
  final String message;

  @override
  String toString() => message;
}

abstract class AiBrain {
  /// Understands [said] (with the last few turns of the conversation in
  /// [history]). Returns null when no key is set; throws [AiError] when the
  /// call fails.
  Future<AiRoute?> route(String said, AiContext ctx, {List<AiTurn> history = const []});

  /// The key in use (empty = AI off).
  String get key;
  set key(String value);

  AiQuality get quality;
  set quality(AiQuality value);
}

/// Claude over the Messages API.
class ClaudeAi implements AiBrain {
  ClaudeAi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  String key = '';

  AiQuality _quality = AiQuality.best;

  @override
  AiQuality get quality => _quality;

  @override
  set quality(AiQuality value) {
    _quality = value;
    _model = 0;
  }

  /// Best first; the next one is tried if a model is not available.
  static const models = ['claude-sonnet-5-5', 'claude-sonnet-4-5', 'claude-haiku-5-5', 'claude-haiku-4-5'];
  static const fastModels = ['claude-haiku-5-5', 'claude-haiku-4-5'];
  List<String> get _models => _quality == AiQuality.best ? models : fastModels;
  int _model = 0;

  /// Models that refuse a forced tool (Sonnet 5.5 and newer): ask with
  /// tool_choice "auto" and read a plain-text answer as the reply.
  final _autoChoice = <String>{'claude-sonnet-5-5'};

  /// Models that refused the thinking/effort settings: send without them.
  final _plain = <String>{};

  static const _endpoint = 'https://api.anthropic.com/v1/messages';

  @override
  Future<AiRoute?> route(String said, AiContext ctx, {List<AiTurn> history = const []}) async {
    if (key.trim().isEmpty) return null;
    while (true) {
      final model = _models[_model];
      final res = await _post(said, ctx, model, history);
      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, Object?>;
        final text = StringBuffer();
        for (final block in (body['content'] as List? ?? const [])) {
          if (block is Map && block['type'] == 'tool_use' && block['input'] is Map) {
            return (block['input'] as Map).cast<String, Object?>();
          }
          if (block is Map && block['type'] == 'text' && block['text'] is String) text.write(block['text']);
        }
        // Answered in words instead of the tool: a plain reply.
        if (text.toString().trim().isNotEmpty) return {'reply': text.toString().trim(), 'items': const []};
        throw const AiError('AI-এর উত্তর বুঝতে পারিনি।');
      }
      final err = _errorText(res);
      final low = err.toLowerCase();
      if (res.statusCode == 400 && low.contains('tool_choice') && _autoChoice.add(model)) continue;
      if (res.statusCode == 400 && (low.contains('thinking') || low.contains('effort') || low.contains('output_config')) && _plain.add(model)) {
        continue;
      }
      if ((res.statusCode == 404 || (res.statusCode == 400 && low.contains('model'))) && _model + 1 < _models.length) {
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

  Future<http.Response> _post(String said, AiContext ctx, String model, List<AiTurn> history) async {
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
              'max_tokens': 4000,
              'system': _autoChoice.contains(model)
                  ? '${systemPrompt(ctx)}\n\nAlways answer by calling the `route` tool exactly once; never answer in plain text.'
                  : systemPrompt(ctx),
              'tools': [_tool],
              'tool_choice': _autoChoice.contains(model) ? {'type': 'auto'} : {'type': 'tool', 'name': 'route'},
              // Think a little before answering (to catch what the user really
              // means), without the long thinking of hard tasks.
              if (_autoChoice.contains(model) && !_plain.contains(model)) 'output_config': {'effort': 'medium'},
              'messages': messagesFor(said, history),
            }),
          )
          .timeout(Duration(seconds: _quality == AiQuality.best ? 45 : 20));
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

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

/// The conversation so far plus [said], as alternating user/assistant
/// messages (the API needs them to alternate and start with the user).
List<Map<String, String>> messagesFor(String said, List<AiTurn> history) {
  final out = <Map<String, String>>[];
  for (final t in history.length > 12 ? history.sublist(history.length - 12) : history) {
    final role = t.fromUser ? 'user' : 'assistant';
    if (out.isEmpty && role == 'assistant') continue;
    if (out.isNotEmpty && out.last['role'] == role) {
      out.last['content'] = '${out.last['content']}\n${t.text}';
    } else {
      out.add({'role': role, 'content': t.text});
    }
  }
  if (out.isNotEmpty && out.last['role'] == 'user') out.add({'role': 'assistant', 'content': '[ঠিক আছে]'});
  out.add({'role': 'user', 'content': said});
  return out;
}

/// The instructions sent with every sentence.
String systemPrompt(AiContext ctx) {
  final d = ctx.now;
  final date = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  return '''
You are "My Assistant", a Bengali personal assistant app used in Bangladesh by busy people of every kind: shopkeepers and traders, business owners, office workers, doctors, teachers, drivers, farmers, freelancers, students and homemakers. Treat the user the way a capable human assistant would: take notes, keep their to-do list, set reminders, keep track of money owed (customers' বাকি, suppliers, loans, staff advances), keep phone numbers, call or message people for them, and answer questions. The user talks to it like a chat, turn after turn (speech-to-text, so expect mis-hearings and no punctuation) or types. Earlier turns are given for context: use them to understand short follow-ups ("ওকে আরও ২০০ দিলাম" = the same person as before; "আর ওর নম্বর?" etc.). Messages in [brackets] are the app's own notes, not the user's words. Work out what the latest message wants and call the `route` tool once.

Understand every way people in Bangladesh talk: standard Bengali, Dhaka speech, regional dialects (Noakhali: টেয়া/টিয়া = টাকা; Chattogram: আঁই, গইজ্জি; Sylhet: কিতা, দিলাইছি; Barishal: মুই, মোরে; Rajshahi: দিনু, লিনু; Mymensingh…), Banglish in English letters ("Sajib ke 500 taka dilam"), and Bengali mixed with English words. Amounts may be in Bengali or English digits or words (দেড় হাজার, আড়াই শো, 2k).

The user often says many things in one long breath. Pull out every separate fact or request as its own item in `items`, in the order said. Summarise: keep only the real information (names, amounts, numbers, dates, places, codes exactly as said) and drop filler, repetition and corrections ("না না, ৫০০ না ৬০০" → 600). Do not invent anything that was not said. Ordinary talk with nothing to keep gives no items, just a reply.

Item actions:
- ledger_add: a money event with a person. kind: lent (user gave a loan; they owe the user), borrowed (user took a loan), received (person paid the user back), repaid (user paid the person back), unclear (you cannot tell). Fill person and amount (0 if not said; person "" if not said).
- ledger_set: the user states a balance ("ইসমাইলের কাছে আমি ৫ হাজার টাকা পাই"). balance > 0: they owe the user; < 0: the user owes them.
- ledger_query: asks about balances. ask: person (fill person), receivable (who owes me), payable (whom I owe), all.
- vault_query: asks for a password/login/Wi-Fi. terms: the site/app name words. wifi true for Wi-Fi.
- reminder_query: asks when something is due. terms: key words.
- note_add: a fact to remember that is not about money ("ছাদের দরজার কোড ৪৫৬৭", "মনে রাখো …"). text: the fact as one short, clean Bengali sentence (keep numbers exactly). category: a short Bengali category; reuse one of the user's categories when it fits.
- search: asks for something the user saved earlier (a note, a contact's number, anything). terms: the key words.
- task_add: something the user has to do ("কাল ব্যাংকে যেতে হবে", "সাপ্লায়ারকে অর্ডার দিতে হবে", "বাজারের লিস্টে ডিম রাখো"). text: the task, short (for a shopping list start with "বাজার: "). date: YYYY-MM-DD if a day was said.
- task_done: the user finished a to-do ("ব্যাংকের কাজ হয়ে গেছে"). terms: key words of the task.
- task_query: asks for the to-do list.
- reminder_add: remind at a time ("কাল সকাল ১০টায় মিটিংয়ের কথা মনে করিয়ে দিও", "৩০ মিনিট পরে চা খাওয়ার কথা বলো", "প্রতি মাসের ৫ তারিখে দোকান ভাড়া"). text: what to remind, short. date: YYYY-MM-DD. time: HH:MM 24-hour (Bangladesh time; "৪টায়" with no সকাল means 16:00). repeat: none, every5/every10/every30/hourly ("প্রতি ৫/১০/৩০ মিনিটে", "ঘণ্টায় ঘণ্টায়" — then date/time is the first ring, default now plus the interval), daily, monthly or yearly. Work out relative times from the current time below.
- contact_add: a phone number to keep. person, phone (as said, digits).
- call: call or message someone ("রহিমকে ফোন দাও", "করিমকে মেসেজ দাও যে মাল পাঠিয়েছি", "হোয়াটসঅ্যাপে লিখে দাও…"). person, via (call, sms, whatsapp), text: the message to send, written cleanly in the user's words, phone if a number was said.
- briefing: "আজ আমার কী কী আছে?", "আজকের প্ল্যান" — today's overview.
- cash_add: the user's own income or spending that nobody owes back ("বাজারে ৫০০ টাকা খরচ হলো", "বিদ্যুৎ বিল ১২০০ দিলাম", "বেতন পেলাম ৩০ হাজার"), or money in/out of a project ("রহিম ভবন প্রজেক্টে ৫০ হাজার টাকা এলো", "প্রজেক্টে মিস্ত্রির মজুরি ৫০০০"). kind: income or expense. amount. category: a short Bengali খাত (বাজার, খাবার, যাতায়াত, বাসা ভাড়া, বিল, মোবাইল, চিকিৎসা, শিক্ষা, কেনাকাটা, মজুরি, বেতন, বিক্রি…). project: the project name, only for project money.
- cash_query: asks about own income/spending/savings ("এই মাসে কত খরচ হলো?") or a project's money (project: the name).
- chat: conversation, greetings, how-are-you, thanks, or a general-knowledge or work question (put the answer in reply). For business questions (pricing, profit margin, VAT basics, how to write a message to a customer…) give short, practical help.
Money owed between the user and a person (loans, credit) is ledger_*; the user's own spending/income or project money is cash_add. Every sentence that mentions money owed between the user and a person (customer's বাকি, loans, advances, payments) is ledger_add / ledger_set / ledger_query, never note_add or task_add. A customer taking goods on credit ("করিম ৫০০ টাকার মাল বাকিতে নিল") is lent; a customer paying their বাকি is received; buying from a supplier on credit is borrowed; paying the supplier is repaid.

Names: write the person's name in Bengali script as said, without endings (সজীবকে → সজীব, রহিমের → রহিম). If it matches one of the known people, use that exact spelling. Names in English letters stay in English with a capital letter.

reply: always fill it. It is read aloud, so write it as natural spoken Bangladeshi Bengali the way a smart, polite human assistant talks: আপনি, plain words, no lists, no markdown, no emoji, no English unless the user used it. Make it tidy: one clear point per sentence, the answer first, no repeating the question, no filler like "অবশ্যই!" at the start.
- When there are items to save, only acknowledge in a few words ("আচ্ছা, বুঝেছি।") — the app reads back the details and asks before saving, so do not repeat them.
- Questions and advice (chat): answer properly and helpfully in 2–4 short sentences; give the actual answer, a number, or concrete steps. For money questions or advice ("খরচ কোথায় কমাব?", "কে সবচেয়ে বেশি বাকি রেখেছে?", "সব মিলিয়ে কত পাব?") use the money summary below, do the arithmetic, and never invent figures that are not there.
- If the message is unclear or a needed detail is missing and you cannot guess it sensibly from the earlier turns, use chat and ask ONE short question instead of guessing.
- Speech-to-text mishears words: work out what the user most likely meant from context (a name close to a known person is that person; "পাচশো" = 500).
- If you are not sure of a general-knowledge fact, say so briefly. Never ask for or repeat passwords or PINs.
Now is $date $time (Asia/Dhaka), ${_weekdays[d.weekday - 1]}.

Known people in the লেনদেন (money) book: ${ctx.people.isEmpty ? '(none)' : ctx.people.join(', ')}
User's note categories: ${ctx.categories.isEmpty ? '(none)' : ctx.categories.join(', ')}
Money summary (from the app, accurate):
${ctx.money.isEmpty ? '(nothing yet)' : ctx.money}''';
}

const _item = {
  'type': 'object',
  'properties': {
    'action': {
      'type': 'string',
      'enum': [
        'ledger_add', 'ledger_set', 'ledger_query', 'vault_query', 'reminder_query', 'note_add', 'search', 'chat', //
        'task_add', 'task_done', 'task_query', 'reminder_add', 'contact_add', 'call', 'briefing', 'cash_add', 'cash_query',
      ],
    },
    'person': {'type': 'string', 'description': 'Person name without case endings'},
    'amount': {'type': 'integer', 'description': 'Whole taka, 0 if not said'},
    'kind': {
      'type': 'string',
      'enum': ['lent', 'borrowed', 'received', 'repaid', 'unclear', 'income', 'expense'],
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
    'text': {'type': 'string', 'description': 'note_add: the fact; task_add/reminder_add: what; call: the message'},
    'date': {'type': 'string', 'description': 'YYYY-MM-DD'},
    'time': {'type': 'string', 'description': 'HH:MM, 24-hour'},
    'repeat': {
      'type': 'string',
      'enum': ['none', 'every5', 'every10', 'every30', 'hourly', 'daily', 'monthly', 'yearly'],
    },
    'via': {
      'type': 'string',
      'enum': ['call', 'sms', 'whatsapp'],
    },
    'phone': {'type': 'string'},
    'project': {'type': 'string', 'description': 'cash_add/cash_query: project name ("" if a project was meant but not named)'},
    'category': {'type': 'string', 'description': 'note_add: category'},
  },
  'required': ['action'],
};

const _tool = {
  'name': 'route',
  'description': 'What the user wants: a short spoken reply and every separate fact or request found in the message.',
  'input_schema': {
    'type': 'object',
    'properties': {
      'reply': {'type': 'string', 'description': 'What the app says back, in Bengali'},
      'items': {'type': 'array', 'items': _item},
    },
    'required': ['reply', 'items'],
  },
};

/// For tests and when AI is off.
class FakeAi implements AiBrain {
  FakeAi({this.answer, this.error});

  @override
  AiQuality quality = AiQuality.best;

  AiRoute? answer;
  AiError? error;
  final asked = <String>[];
  final histories = <List<AiTurn>>[];

  @override
  String key = '';

  @override
  Future<AiRoute?> route(String said, AiContext ctx, {List<AiTurn> history = const []}) async {
    if (key.isEmpty) return null;
    asked.add(said);
    histories.add(history);
    if (error != null) throw error!;
    return answer;
  }
}
