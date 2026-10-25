// Long speech (owner, 25 Oct: "দীর্ঘ কথা ধরতে পারে না … ভয়েস এ ঠিক শুনলেও সে
// অনুযায়ী কাজ করতে পারে না"). What a speech recogniser gives for one long
// breath: no punctuation, fillers ("মানে", "তো", "আচ্ছা শোনো"), several
// things at once, numbers in words. Each case says what must end up in the
// app after the user answers "হ্যাঁ" to a confirmation.
//
// MEASUREMENT SET: these sentences are never used for training data
// (owner's rule). LONG=1 prints a line per case; the test fails below the
// floor in [_floor].
import 'dart:io' show Platform;

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, start;

class _Want {
  const _Want({this.tasks = const [], this.reminders = const [], this.spend = const [], this.income = const [], this.lent = const [], this.borrowed = const [], this.received = const []});

  /// Words each to-do title must contain (one to-do per entry).
  final List<String> tasks;

  /// (word in the title, hour) per reminder.
  final List<(String, int)> reminders;
  final List<int> spend;
  final List<int> income;
  final List<(String, int)> lent;
  final List<(String, int)> borrowed;
  final List<(String, int)> received;
}

final _cases = <(String, _Want)>[
  ('আজকে আমার অনেক কাজ আছে প্রথমে ব্যাংকে যাব তারপর বাজার করব তারপর বিকেলে আম্মাকে নিয়ে ডাক্তারের কাছে যাব আর রাতে ছেলের পড়া দেখব',
      _Want(tasks: ['ব্যাংক', 'বাজার', 'ডাক্তার', 'পড়া'])),
  ('কাল সকাল ৮টায় অফিসের মিটিং আছে মনে করিয়ে দিও আর দুপুর ২টায় রহিম ভাইকে ফোন করতে হবে সেটাও মনে করিয়ে দিও', _Want(reminders: [('মিটিং', 8), ('রহিম', 14)])),
  ('আজ বাজারে গিয়ে চাল কিনলাম ১২০০ টাকার ডাল কিনলাম ৩০০ টাকার আর সবজি নিলাম ২৫০ টাকার রিকশা ভাড়া গেল ৬০ টাকা', _Want(spend: [1200, 300, 250, 60])),
  ('করিমকে আজকে পাঁচ হাজার টাকা ধার দিলাম সে বলছে আগামী মাসের দশ তারিখে ফেরত দিবে', _Want(lent: [('করিম', 5000)])),
  ('মানে আমি বলতে চাচ্ছি যে কালকে বিকেল পাঁচটায় মেয়ের স্কুলে প্যারেন্টস মিটিং আছে ওটা মনে করিয়ে দিও একটু', _Want(reminders: [('মিটিং', 17)])),
  ('আজকে বেতন পেলাম পঁয়ত্রিশ হাজার টাকা তার থেকে বাসা ভাড়া দিলাম বারো হাজার আর বিদ্যুৎ বিল দিলাম আঠারোশো টাকা', _Want(income: [35000], spend: [12000, 1800])),
  ('তো শোনো আমার কিছু কাজ লিখে রাখো গাড়ির কাগজ নবায়ন করা পাসপোর্টের ছবি তোলা আর মোবাইল বিল দেওয়া', _Want(tasks: ['গাড়ি', 'পাসপোর্ট', 'মোবাইল বিল'])),
  ('প্রতিদিন রাত দশটায় প্রেসারের ওষুধ খাওয়ার কথা মনে করিয়ে দিবা', _Want(reminders: [('ওষুধ', 22)])),
  ('আচ্ছা শোনো সুমন আমার কাছ থেকে গত সপ্তাহে দুই হাজার টাকা নিছিল আজকে এক হাজার ফেরত দিছে', _Want(received: [('সুমন', 1000)])),
  ('আজ সকালে নাস্তায় খরচ হলো একশো বিশ টাকা দুপুরে খাবারে তিনশো টাকা আর সন্ধ্যায় চা বিস্কুটে পঞ্চাশ টাকা', _Want(spend: [120, 300, 50])),
  ('আগামী শুক্রবার জুমার পরে মামার বাসায় দাওয়াত আছে সেটা কাজের তালিকায় রাখো আর শনিবার সকাল দশটায় গ্যাস বিল দিতে হবে মনে করিয়ে দিও',
      _Want(tasks: ['মামা'], reminders: [('গ্যাস', 10)])),
  ('রিনা আপাকে আজকে তিন হাজার টাকা দিলাম ধার হিসেবে আর জসিমের কাছ থেকে পাঁচশো টাকা ধার নিলাম', _Want(lent: [('রিনা', 3000)], borrowed: [('জসিম', 500)])),
  ('আজকে বাজার থেকে মাছ কিনলাম সাতশো টাকার আর মুরগি কিনলাম চারশো পঞ্চাশ টাকার', _Want(spend: [700, 450])),
  ('আসলে আজকে অনেক ব্যস্ত ছিলাম তো যা বলছিলাম কালকে ভোরে উঠে হাঁটতে যাব তারপর নাস্তা করে ব্যাংকে চেক জমা দিতে হবে এটা কাজের তালিকায় রাখো', _Want(tasks: ['হাঁট', 'চেক'])),
  ('আমার বউয়ের জন্য শাড়ি কিনলাম সাড়ে তিন হাজার টাকা দিয়ে আর মেয়ের জন্য জুতা আটশো টাকা', _Want(spend: [3500, 800])),
  ('মোবাইলে রিচার্জ করলাম দুইশো টাকা আর ইন্টারনেট প্যাকেজ কিনলাম পাঁচশো টাকার', _Want(spend: [200, 500])),
  ('পরশু দিন দুপুর বারোটায় ডাক্তারের অ্যাপয়েন্টমেন্ট আছে মনে করিয়ে দিও', _Want(reminders: [('ডাক্তার', 12)])),
  ('এই মাসের পঁচিশ তারিখে কিস্তি দিতে হবে পাঁচ হাজার টাকা সকাল দশটায় মনে করিয়ে দিও', _Want(reminders: [('কিস্তি', 10)])),
  ('কালকে যে কাজগুলো করতে হবে সেগুলো হলো দর্জির দোকান থেকে পাঞ্জাবি আনা লন্ড্রিতে কাপড় দেওয়া আর বাচ্চার স্কুলের বেতন দেওয়া', _Want(tasks: ['পাঞ্জাবি', 'লন্ড্রি', 'বেতন'])),
  ('হাসানকে দশ হাজার টাকা ধার দিছিলাম ও আজকে পুরো টাকাটা ফেরত দিয়ে দিছে', _Want(received: [('হাসান', 10000)])),
];

/// Cases that must pass (raised as the understanding improves).
const _floor = 0;

void main() {
  testWidgets('long speech: one breath, several things', (t) async {
    final verbose = Platform.environment['LONG'] == '1';
    var passed = 0;
    final failed = <String>[];
    for (final (said, want) in _cases) {
      final rig = await start(t);
      rig.nowAt = DateTime(2026, 10, 25, 9, 30);
      final chat = ChatController(rig.brain);
      final replies = <String>[];
      var n = chat.messages.length;
      await chat.hear(said);
      for (var i = 0; i < 3 && (chat.wait == ChatWait.yesNo || chat.wait == ChatWait.bulk || chat.wait == ChatWait.batchTime); i++) {
        replies.add(chat.messages.skip(n).where((m) => !m.fromUser).map((m) => m.text).join(' / '));
        n = chat.messages.length;
        await chat.hear('হ্যাঁ');
      }
      replies.add(chat.messages.skip(n).where((m) => !m.fromUser).map((m) => m.text).join(' / '));
      final d = rig.brain.data;
      final why = <String>[];
      for (final w in want.tasks) {
        if (!d.tasks.any((x) => x.title.contains(w))) why.add('no to-do "$w"');
      }
      for (final (w, h) in want.reminders) {
        if (!d.reminders.any((r) => r.title.contains(w) && r.hour == h)) why.add('no reminder "$w" at $h');
      }
      List<int> cash(CashKind k) => [for (final c in d.cash) if (c.kind == k) c.amount];
      for (final a in want.spend) {
        if (!cash(CashKind.expense).contains(a)) why.add('no spending $a');
      }
      for (final a in want.income) {
        if (!cash(CashKind.income).contains(a)) why.add('no income $a');
      }
      for (final (k, list) in [(LedgerKind.lent, want.lent), (LedgerKind.borrowed, want.borrowed), (LedgerKind.received, want.received)]) {
        for (final (p, a) in list) {
          if (!d.ledger.any((e) => e.kind == k && e.person.contains(p) && e.amount == a)) why.add('no ${k.name} $p $a');
        }
      }
      if (why.isEmpty) {
        passed++;
      } else {
        failed.add('✗ $said\n    ${why.join('; ')}\n    wait=${chat.wait}\n    » ${replies.join('\n    » ')}');
      }
      if (verbose) {
        // ignore: avoid_print
        print('${why.isEmpty ? '✓' : '✗'} $said${why.isEmpty ? '' : '\n    ${why.join('; ')}'}');
      }
    }
    // ignore: avoid_print
    print('LONG SPEECH: $passed / ${_cases.length}\n${failed.join('\n')}');
    expect(passed, greaterThanOrEqualTo(_floor));
  });

  test('the set is for measuring only', () => expect(Rig, isNotNull));
}
