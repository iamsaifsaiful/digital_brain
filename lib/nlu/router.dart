// "On" mode (brief step F.7): the on-phone model no longer only watches — it
// decides when a paid or cloud reading is needed at all.
//
//   * The rules and the model agree on what is wanted (an action, not talk):
//     the rules' reading is used and the AI is NOT asked (on the gold set an
//     agreement was right 98.3% of the time — cheaper and as good).
//   * They disagree (on the gold set the rules were right only 43% of the
//     time then): a member without the AI asks the server's cloud reading
//     (POST /nlu/resolve — Gemini for free members, within the budgets), and
//     two readings out of three decide. A member with the AI is asked as today.
//
// The model never acts alone, and the rules keep the last word on to-dos,
// reminders, money answers, secrets and phone numbers (brain._staysHere).
import '../logic/ai_map.dart' show commandFromAi;
import '../logic/bn.dart' show asciiDigits;
import '../logic/parser.dart';
import '../models/models.dart';
import 'reader.dart';
import 'values.dart';

/// The model and the rules read the same requests (same intents, any order).
bool nluAgrees(List<NluPiece> pieces, List<String> rules) {
  if (pieces.isEmpty) return false;
  final mine = {for (final p in pieces) p.intent};
  return mine.length == rules.toSet().length && mine.containsAll(rules);
}

/// Talk, complaints and unclear messages: the AI's own words are worth asking
/// for there, so an agreement on these does not skip it.
const nluTalkIntents = {'smalltalk', 'complain_help', 'out_of_scope', 'none', 'reply', 'correct', 'inform', 'cancel', 'confirm_yes', 'confirm_no', 'select', 'dictate_start', 'dictate_end'};

/// The AI need not be asked: both read the same actions.
bool nluMaySkipAi(List<NluPiece>? pieces, List<String> rules) =>
    pieces != null && rules.isNotEmpty && nluAgrees(pieces, rules) && !rules.any(nluTalkIntents.contains);

/// The rules only half understood (nothing, a search, a plain note).
bool rulesWeak(List<String> rules) => rules.length == 1 && const {'none', 'note_query', 'note_add'}.contains(rules.first);

/// A cloud reading (POST /nlu/resolve): pieces of {intent, slots: [{name, words}]}.
class CloudReading {
  CloudReading(this.pieces, this.sure);

  factory CloudReading.fromJson(Map<String, dynamic> j) => CloudReading([
        for (final p in (j['pieces'] as List? ?? const []))
          if (p is Map && p['intent'] is String)
            (
              p['intent'] as String,
              {
                for (final s in (p['slots'] as List? ?? const []))
                  if (s is Map && s['name'] is String && s['words'] is String) s['name'] as String: s['words'] as String,
              }
            ),
      ], (j['sure'] as num?)?.toDouble() ?? 0);

  final List<(String, Map<String, String>)> pieces;
  final double sure;
  List<String> get intents => {for (final (i, _) in pieces) i}.toList();
}

/// Which reading wins: 'rules' or 'cloud'.
///  * the cloud says what the model said (and not the rules): two to one;
///  * the rules only half understood and the cloud is sure of something real.
/// Otherwise the rules, as today.
String nluVote(List<String> rules, List<NluPiece> model, CloudReading cloud) {
  final c = cloud.intents;
  if (c.isEmpty || c.every((i) => i == 'none' || i == 'out_of_scope')) return 'rules';
  final same = c.toSet().length == rules.toSet().length && c.toSet().containsAll(rules);
  if (same) return 'rules';
  if (nluAgrees(model, c) && cloud.sure >= 0.5) return 'cloud';
  if (rulesWeak(rules) && cloud.sure >= 0.7) return 'cloud';
  return 'rules';
}

/// Names put back where the phone took them out ("<নাম১>" → "রহিম").
String restoreNames(String words, Map<String, String> names) {
  var out = words;
  names.forEach((tag, name) => out = out.replaceAll(tag, name));
  return out;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// The commands for a cloud reading, made by the app's own code from the
/// words the cloud marked (lib/nlu/values.dart turns them into dates and
/// amounts; ai_map.dart checks them as it checks the AI's). Null when any
/// piece cannot be made safely — then the rules' reading is used.
List<Command>? commandsFromReading(String said, CloudReading r, List<LedgerEntry> ledger, DateTime now, {Map<String, String> names = const {}}) {
  final out = <Command>[];
  for (final (intent, raw) in r.pieces) {
    final s = {for (final e in raw.entries) e.key: restoreNames(e.value, names)};
    final item = _routeItem(intent, s, said, now);
    if (item == null) return null;
    final c = commandFromAi(said, item, ledger, now: now);
    if (c == null) return null;
    out.add(checked(c, said, now));
  }
  return out.isEmpty ? null : out;
}

final _income = RegExp(r'(আয়|আয়|পেলাম|পাইলাম|পাইছি|পেয়েছি|পেয়েছি|বেতন|ইনকাম|বিক্রি|লাভ)');
final _expense = RegExp(r'(খরচ|কিনলাম|কিনেছি|দিলাম|দিয়েছি|দিয়েছি|ভাড়া|ভাড়া|বিল|কেনা)');

/// The AI-route shape (lib/logic/ai_map.dart) of one spec piece, or null.
Map<String, Object?>? _routeItem(String intent, Map<String, String> s, String said, DateTime now) {
  final m = <String, Object?>{};
  // Date and time: only from the marked words; a span that is not a date is refused.
  if (s['date'] != null || s['time'] != null) {
    final w = whenOf(s['date'], s['time'], now);
    if (w == null) return null;
    if (w.hasDay) m['date'] = '${w.at.year}-${_two(w.at.month)}-${_two(w.at.day)}';
    if (w.hasTime) m['time'] = '${_two(w.at.hour)}:${_two(w.at.minute)}';
    m['time_clear'] = !w.askAmPm;
  }
  final title = s['title'] ?? s['text'];
  List<String> terms() => [for (final x in [s['title'], s['terms'], s['text']]) if (x != null && x.trim().isNotEmpty) x];
  void ref() {
    final idx = s['list_ref'] == null ? null : int.tryParse(asciiDigits(s['list_ref']!).replaceAll(RegExp(r'\D'), ''));
    if (idx != null && idx > 0) m['index'] = idx;
    final t = terms();
    if (t.isNotEmpty) m['terms'] = t;
  }

  switch (intent) {
    case 'task_add':
      if (title == null) return null;
      return m..addAll({'action': 'task_add', 'text': title, 'urgent': s['urgent'] != null});
    case 'task_done' || 'task_reopen' || 'task_delete' || 'task_skip_once' || 'reminder_stop':
      ref();
      if (!m.containsKey('index') && !m.containsKey('terms')) return null;
      return m..['action'] = intent;
    case 'task_remind':
      ref();
      return m..['action'] = 'task_remind';
    case 'task_query':
      return {'action': 'task_query'};
    case 'reminder_add':
      // A repeat ("প্রতিদিন", "প্রতি ২ ঘণ্টা") is the rules' to read.
      if (s['repeat'] != null) return null;
      return m..addAll({'action': 'reminder_add', 'text': title ?? '', 'alarm': s['alarm'] != null});
    case 'reminder_snooze':
      final n = s['minutes'] == null ? null : findAmount(normalize(s['minutes']!));
      if (n == null || n <= 0) return null;
      return {'action': 'reminder_snooze', 'minutes': n};
    case 'reminder_query':
      return {'action': 'reminder_query', 'terms': terms()};
    case 'ledger_add':
      final p = s['person'], a = amountOf(s['amount']);
      if (p == null || a == null || a <= 0) return null;
      // Who gave whom is asked (a choice), never guessed from a cloud reading.
      return {'action': 'ledger_add', 'person': p, 'amount': a};
    case 'ledger_query':
      final p = s['person'];
      return {'action': 'ledger_query', 'ask': p == null ? 'all' : 'person', 'person': p ?? ''};
    case 'cash_add':
      final a = amountOf(s['amount']);
      if (a == null || a <= 0) return null;
      final k = normalize(s['cash_kind'] ?? said);
      final income = _income.hasMatch(k), expense = _expense.hasMatch(k);
      if (income == expense) return null;
      return {'action': 'cash_add', 'amount': a, 'kind': income ? 'income' : 'expense', 'category': s['category'] ?? '', if (s['account'] != null) 'project': s['account']};
    case 'cash_query':
      return {'action': 'cash_query', if (s['account'] != null) 'project': s['account']};
    case 'note_add':
      return {'action': 'note_add', 'text': s['text'] ?? s['title'] ?? '', 'category': s['category'] ?? ''};
    case 'note_query':
      final t = terms();
      return t.isEmpty ? null : {'action': 'search', 'terms': t};
    case 'call':
      final p = s['person'];
      if (p == null) return null;
      final v = normalize(s['via'] ?? '');
      final via = v.contains('হোয়াটস') || v.contains('whatsapp') ? 'whatsapp' : (v.contains('মেসেজ') || v.contains('এসএমএস') || v.contains('sms') ? 'sms' : 'call');
      return {'action': 'call', 'person': p, 'via': via, 'text': s['text'] ?? ''};
    case 'briefing':
      return {'action': 'briefing'};
  }
  return null;
}
