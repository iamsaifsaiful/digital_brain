/// What needs doing in a message from another app: a meeting or a time, a
/// date to remember, money asked for, money that came in or went out
/// (bKash, Nagad, bank SMS), a question waiting for an answer, a bill or a
/// deadline in an email. Works on the phone, from the words alone.
library;

import '../models/models.dart';
import 'bn.dart';
import 'cash.dart';
import 'lang.dart';
import 'parser.dart';
import 'when.dart';

enum InboxKind {
  meeting('সময় দেওয়া আছে', 'Time set'),
  deadline('তারিখ দেওয়া আছে', 'Date given'),
  moneyAsk('টাকা চেয়েছে', 'Money asked'),
  moneyIn('টাকা এসেছে', 'Money in'),
  moneyOut('টাকা গেছে', 'Money out'),
  bill('বিল / পেমেন্ট', 'Bill / payment'),
  reply('উত্তর চাইছে', 'Waiting for reply');

  const InboxKind(this.bn, this.en);
  final String bn;
  final String en;
  String get label => isEn ? en : bn;
}

class InboxInsight {
  const InboxInsight(this.kind, this.summary, {this.command});
  final InboxKind kind;

  /// One line: "রহিম: কাল বিকেল ৩টায় মিটিং".
  final String summary;

  /// What to keep, after the user agrees (a to-do, a reminder, an income/expense).
  final Command? command;
}

bool _has(String t, List<String> ws) => ws.any((w) {
      final n = normalize(w);
      return n.isNotEmpty && t.contains(n);
    });

const _moneyWords = ['টাকা', 'tk', 'taka', 'bdt', '৳'];
const _askWords = ['পাঠাও', 'পাঠান', 'পাঠাবেন', 'পাঠিয়ে দিও', 'পাঠিয়ে দিন', 'দাও', 'দিন', 'দেন', 'দিবেন', 'দেবেন', 'দিও', 'লাগবে', 'দরকার', 'ধার', 'send', 'pay', 'please', 'পরিশোধ', 'বকেয়া'];
const _inWords = ['received', 'cash in', 'cashin', 'credited', 'deposited', 'you have received', 'পেয়েছেন', 'জমা হয়েছে', 'জমা হলো', 'ক্যাশ ইন', 'refund'];
const _outWords = ['payment', 'cash out', 'cashout', 'send money', 'sent', 'debited', 'withdrawn', 'purchase', 'paid', 'পাঠানো হয়েছে', 'পরিশোধ করা হয়েছে', 'ক্যাশ আউট', 'কেনাকাটা'];
const _billWords = ['invoice', 'bill', 'due', 'payment due', 'overdue', 'বিল', 'বকেয়া', 'শেষ তারিখ', 'last date', 'deadline', 'interview', 'appointment', 'meeting', 'ইন্টারভিউ', 'সাক্ষাৎকার', 'মিটিং', 'অ্যাপয়েন্টমেন্ট'];
const _promoWords = ['offer', 'অফার', 'discount', 'ছাড়', 'cashback', 'ক্যাশব্যাক', 'bonus', 'বোনাস', 'recharge', 'রিচার্জ করুন', 'internet pack', 'ইন্টারনেট প্যাক', 'unsubscribe', 'sale', 'সেল', 'promo', 'win', 'জিতুন', 'subscribe'];
const _questionWords = ['কখন', 'কবে', 'কোথায়', 'পারবেন', 'পারবে', 'পারবা', 'আসবেন', 'আসবে', 'আসবা', 'কি না', 'কিনা', 'জানাবেন', 'জানাও', 'জানান', 'বলবেন', 'reply', 'confirm', 'let me know', 'can you', 'could you', 'will you', 'call me', 'ফোন দিও', 'ফোন দিয়েন', 'কল দিও', 'কল দিন'];

bool _isMoneyApp(InboxMessage m) =>
    m.app.contains('messaging') || m.app.contains('mms') || _has(normalize('${m.from} ${m.chat}'), ['bkash', 'বিকাশ', 'nagad', 'নগদ', 'rocket', 'রকেট', 'bank', 'ব্যাংক', 'upay', 'tap', 'cellfin', 'dbbl', 'brac', 'city', 'ebl']);

String _who(InboxMessage m) => m.group && m.from.isNotEmpty && m.from != m.chat ? '${m.from} (${m.chat})' : (m.from.isNotEmpty ? m.from : m.chat);

String _short(String t, [int n = 70]) {
  final one = t.replaceAll(RegExp(r'\s+'), ' ').trim();
  return one.length <= n ? one : '${one.substring(0, n).trimRight()}…';
}

/// What needs doing in [m], or null when it is only a message (or an ad).
InboxInsight? insightOf(InboxMessage m, DateTime now) {
  final text = normalize(m.text);
  if (text.isEmpty) return null;
  if (_has(text, _promoWords)) return null;
  final who = _who(m);
  final amount = findAmount(text);
  final money = amount != null && amount > 0 && (_has(text, _moneyWords) || m.text.contains('৳') || RegExp(r'\btk\.?\s*\d', caseSensitive: false).hasMatch(m.text));

  // bKash, Nagad, bank SMS: money in or out of the user's own account.
  if (money && _isMoneyApp(m)) {
    if (_has(text, _inWords)) {
      return InboxInsight(InboxKind.moneyIn, trf('{0}: {1} টাকা এসেছে', [m.from.isNotEmpty ? m.from : m.appName, bnNumber(amount)]),
          command: CashAdd(m.text, kind: CashKind.income, amount: amount, category: tr('অন্যান্য')));
    }
    if (_has(text, _outWords)) {
      return InboxInsight(InboxKind.moneyOut, trf('{0}: {1} টাকা গেছে', [m.from.isNotEmpty ? m.from : m.appName, bnNumber(amount)]),
          command: CashAdd(m.text, kind: CashKind.expense, amount: amount, category: categoryFor(text, CashKind.expense)));
    }
  }

  // A time or a day ahead: a meeting, an appointment, a deadline.
  // Only a real time or day counts ("শুভ সকাল" is a greeting, not 9 o'clock).
  final greeting = _has(text, ['শুভ সকাল', 'শুভ রাত্রি', 'শুভ রাত', 'শুভ দুপুর', 'শুভ সন্ধ্যা', 'good morning', 'good night', 'good evening', 'সুপ্রভাত']);
  final dayWord = _has(text, ['আজ', 'কাল', 'পরশু', 'আগামী', 'তারিখ', 'শনিবার', 'রবিবার', 'রোববার', 'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শুক্রবার',
      'today', 'tomorrow', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']);
  final clock = RegExp(r'[0-9০-৯]').hasMatch(m.text);
  final when = greeting || !(dayWord || clock) ? null : parseWhen(m.text, m.at);
  if (when != null && (when.hasTime || when.hasDay) && when.at.isAfter(now)) {
    final title = trf('{0}: {1}', [who, _short(m.text, 50)]);
    if (when.hasTime) {
      return InboxInsight(InboxKind.meeting, trf('{0} — {1}', [title, sayWhen(when.at, now)]), command: ReminderAdd(m.text, title: title, at: when.at, minutesBefore: 30));
    }
    return InboxInsight(InboxKind.deadline, trf('{0} — {1}', [title, sayWhen(when.at, now, withTime: false)]), command: TaskAdd(m.text, title: title, due: dayOnly(when.at)));
  }

  // Money asked for: a to-do to send it.
  if (money && _has(text, _askWords) && !_isMoneyApp(m)) {
    return InboxInsight(InboxKind.moneyAsk, trf('{0} {1} টাকা চেয়েছেন', [who, bnNumber(amount)]),
        command: TaskAdd(m.text, title: trf('{0}-কে {1} টাকা পাঠানো', [m.from.isNotEmpty ? m.from : m.chat, bnNumber(amount)])));
  }

  // An email or message about a bill, an interview, a deadline.
  if (_has(text, _billWords) && !_isMoneyApp(m)) {
    return InboxInsight(InboxKind.bill, trf('{0}: {1}', [who, _short(m.text)]), command: TaskAdd(m.text, title: trf('{0}: {1}', [who, _short(m.text, 50)])));
  }

  // A direct question to the user (not in a busy group, not from a mail list).
  final mail = m.app.contains('gm') || m.app.contains('mail') || m.app.contains('outlook');
  if (!m.group && !mail && (m.text.contains('?') || _has(text, _questionWords))) {
    return InboxInsight(InboxKind.reply, trf('{0} জানতে চাইছেন: {1}', [who, _short(m.text)]),
        command: TaskAdd(m.text, title: trf('{0}-কে উত্তর দেওয়া: {1}', [m.from.isNotEmpty ? m.from : m.chat, _short(m.text, 40)])));
  }
  return null;
}

/// New messages that need something done, newest first.
List<(InboxMessage, InboxInsight)> inboxTodo(AppData d, DateTime now) => [
      for (final m in d.inbox.reversed)
        if (m.isNew)
          if (insightOf(m, now) case final i?) (m, i),
    ];

/// "হোয়াটসঅ্যাপে কী এসেছে?", "রহিম কী লিখেছে?", "জরুরি কোনো মেসেজ আছে?"
String inboxAnswer(AppData d, String said, DateTime now) {
  final text = normalize(said);
  if (d.inbox.isEmpty) {
    return tr('অন্য অ্যাপের কোনো মেসেজের তথ্য নেই। “মেসেজ” পাতায় অনুমতি দিয়ে অ্যাপগুলো বেছে দিন — তারপর WhatsApp, imo, Gmail-এর নতুন মেসেজ থেকে কাজের কথা বের করে দেবো।');
  }
  // One app ("হোয়াটসঅ্যাপে", "জিমেইলে").
  const appWords = {
    'WhatsApp': ['হোয়াটসঅ্যাপ', 'হোয়াটসআপ', 'whatsapp', 'হোয়াটস'],
    'Telegram': ['টেলিগ্রাম', 'telegram'],
    'imo': ['ইমো', 'imo'],
    'Messenger': ['মেসেঞ্জার', 'messenger'],
    'Gmail': ['জিমেইল', 'gmail', 'ইমেইল', 'মেইল', 'email', 'mail'],
    'SMS': ['এসএমএস', 'sms'],
  };
  String? app;
  for (final e in appWords.entries) {
    if (_has(text, e.value)) app = e.key;
  }
  var msgs = [for (final m in d.inbox.reversed) if (app == null || m.appName.startsWith(app) || (app == 'Gmail' && (m.app.contains('mail') || m.app.contains('outlook')))) m];
  // From someone ("রহিম কী লিখেছে", "রহিমের মেসেজ").
  final people = {for (final m in d.inbox) if (m.from.isNotEmpty) m.from};
  String? person;
  for (final p in people) {
    final first = normalize(p).split(' ').first;
    if (first.length >= 2 && words(text).any((w) => w.startsWith(first))) person = p;
  }
  if (person != null) msgs = [for (final m in msgs) if (m.from == person) m];
  if (msgs.isEmpty) {
    return person != null ? trf('{0}-এর কোনো মেসেজের তথ্য নেই।', [person]) : trf('{0}-এর কোনো নতুন মেসেজের তথ্য নেই।', [app ?? tr('অন্য অ্যাপ')]);
  }
  if (person != null) {
    final last = msgs.take(3).toList();
    return trf('{0} লিখেছেন ({1}):\n{2}', [person, last.first.appName, last.map((m) => '• ${sayWhen(m.at, now)} — ${_short(m.text, 160)}').join('\n')]);
  }
  final todo = [for (final m in msgs) if (m.isNew) if (insightOf(m, now) case final i?) i];
  final fresh = msgs.where((m) => m.isNew && now.difference(m.at).inHours < 24).toList();
  final from = {for (final m in fresh) m.from.isNotEmpty ? m.from : m.chat}.take(4).toList();
  final head = fresh.isEmpty
      ? tr('গত ২৪ ঘণ্টায় নতুন মেসেজ নেই।')
      : trf('গত ২৪ ঘণ্টায় {0}টা মেসেজ — {1}।', [bnDigits(fresh.length), from.join(', ')]);
  if (todo.isEmpty) return '$head ${tr('কাজের কিছু চোখে পড়েনি।')}';
  return trf('{0} কাজের কথা {1}টা:\n{2}', [head, bnDigits(todo.length), todo.take(4).map((i) => '• ${i.summary}').join('\n')]);
}
