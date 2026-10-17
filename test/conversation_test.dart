// Conversations over several turns: what "ও" and "এখন মোট কত?" refer to,
// changing a waiting action instead of cancelling it, one confirmation per
// action, and never doing the same thing twice.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;

void main() {
  late ChatController chat;
  final asked = <String>[];

  Future<String> say(String s) async {
    final r = await chat.hear(s);
    asked.add(r);
    return r;
  }

  testWidgets('"ও" is the person just talked about; "এখন মোট কত?" comes from the saved book', (t) async {
    final rig = await start(t);
    chat = ChatController(rig.brain);
    expect(await say('রহিমকে পাঁচশ টাকা ধার দিয়েছি।'), contains('লিখে রাখি'));
    await say('হ্যাঁ');
    final second = await say('ও আরও দুইশ টাকা নিয়েছে।');
    expect(second, contains('রহিমকে ২০০ টাকা ধার'));
    await say('হ্যাঁ');
    expect([for (final e in rig.brain.data.ledger) (e.person, e.kind, e.amount)], [('রহিম', LedgerKind.lent, 500), ('রহিম', LedgerKind.lent, 200)]);
    // The total is read from the book, not from the chat.
    expect(await say('এখন মোট কত?'), contains('৭০০'));
    // Something changed outside the chat (the book was edited): the answer follows the book.
    await rig.brain.saveEntry(LedgerEntry(person: 'রহিম', kind: LedgerKind.received, amount: 100, date: DateTime(2026, 10, 9)));
    expect(await say('সব মিলিয়ে কত হলো?'), contains('৬০০'));
  });

  testWidgets('a new person changes who "ও" is; with nobody talked about, the app asks', (t) async {
    final rig = await start(t);
    chat = ChatController(rig.brain);
    await say('রহিমকে ৫০০ টাকা ধার দিলাম');
    await say('হ্যাঁ');
    await say('করিমের কাছ থেকে ১০০০ টাকা ধার নিয়েছি');
    await say('হ্যাঁ');
    expect(await say('ওকে ৩০০ টাকা ফেরত দিলাম'), contains('করিম'));
    await say('হ্যাঁ');
    expect(rig.brain.data.ledger.last.person, 'করিম');
    expect(rig.brain.data.ledger.last.kind, LedgerKind.repaid);

    // A new conversation (the app was closed): nothing is remembered.
    chat = ChatController(rig.brain);
    final r = await say('ও আরও দুইশ টাকা নিয়েছে');
    expect(r, contains('কার সাথে'));
    // "হ্যাঁ" is not a name.
    expect(await say('হ্যাঁ'), contains('নামটা বলুন'));
    expect(chat.wait, ChatWait.name);
    expect(await say('এখন মোট কত?'), isNot(contains('রহিম')), reason: 'no person in this conversation yet');
  });

  testWidgets('"না, এগারোটায় করো" changes the waiting reminder; it is not a no', (t) async {
    final rig = await start(t);
    chat = ChatController(rig.brain);
    // Set at once (complete request); "না, এগারোটায়" right after changes
    // that same reminder — never a second one, never a "no".
    expect(await say('কাল সকাল দশটায় মিটিংয়ের রিমাইন্ডার দাও'), contains('১০টা'));
    final again = await say('না, এগারোটায় করো');
    expect(again, contains('১১টা'));
    expect(again, contains('মিটিং'));
    final r = rig.brain.data.reminders.single;
    expect((r.title, r.hour, r.date), ('মিটিং', 11, DateTime(2026, 10, 10)));
    // A different day the same way.
    await say('পরশু বিকেল ৪টায় ব্যাংকে যাওয়ার কথা মনে করিয়ে দিও');
    await say('না, কাল করো');
    expect(rig.brain.data.reminders, hasLength(2));
    expect(rig.brain.data.reminders.last.date, DateTime(2026, 10, 10));
    expect(rig.brain.data.reminders.last.hour, 16);
  });

  testWidgets('money: "না, করিমকে" changes the person; "না, ৭০০" the amount; plain "না" saves nothing', (t) async {
    final rig = await start(t);
    chat = ChatController(rig.brain);
    await say('রহিমকে ৫০০ টাকা ধার দিলাম');
    expect(await say('না, করিমকে'), contains('করিমকে ৫০০'));
    expect(await say('না, ৭০০'), contains('৭০০'));
    await say('হ্যাঁ');
    expect([for (final e in rig.brain.data.ledger) (e.person, e.amount)], [('করিম', 700)]);
    await say('সজীবকে ৩০০ টাকা ধার দিলাম');
    expect(await say('না'), contains('রাখলাম না'));
    expect(rig.brain.data.ledger, hasLength(1));
  });

  testWidgets('one confirmation per action, and never twice', (t) async {
    final rig = await start(t);
    chat = ChatController(rig.brain);
    // Clear: one question, then saved.
    await say('বাজারে ৫০০ টাকা খরচ হলো');
    expect(chat.wait, ChatWait.yesNo);
    await say('হ্যাঁ');
    expect(rig.brain.data.cash, hasLength(1));
    // The same "হ্যাঁ" twice at once (voice and a tap, or a repeated callback).
    await say('সজীবকে ৫০০ টাকা ধার দিলাম');
    await Future.wait([chat.hear('হ্যাঁ'), chat.hear('হ্যাঁ')]);
    expect(rig.brain.data.ledger, hasLength(1));
    // Unclear kind: the user picks it — that is the answer, no second "লিখে রাখি?".
    await say('রাকিবকে ৩০০ টাকা দিলাম');
    expect(chat.wait, ChatWait.kind);
    final r = await say('ধার দিলাম');
    expect(r, isNot(contains('লিখে রাখি')));
    expect(rig.brain.data.ledger.last.person, 'রাকিব');
    // A question needs no confirmation at all.
    await say('আমার পাওনা কত?');
    expect(chat.wait, ChatWait.none);
  });

  testWidgets('negatives: "মুছে দিও না" deletes nothing; "না, মুছো না" cancels a waiting delete', (t) async {
    final rig = await start(t);
    chat = ChatController(rig.brain);
    await say('রহিমকে ৫০০ টাকা ধার দিলাম');
    await say('হ্যাঁ');
    expect(await say('রহিমের লেনদেন মুছে দিও না'), contains('কিছু করছি না'));
    expect(rig.brain.data.ledger, hasLength(1));
    expect(await say('রহিমের ৫০০ টাকার লেনদেনটা মুছে দাও'), contains('মুছে দেবো'));
    await say('না, মুছো না');
    expect(rig.brain.data.ledger, hasLength(1));
  });

  testWidgets('a reminder stopped (not deleted), and "বন্ধ কোরো না" leaves it on', (t) async {
    final rig = await start(t);
    chat = ChatController(rig.brain);
    await say('কাল সকাল ১০টায় মিটিংয়ের কথা মনে করিয়ে দিও');
    await say('হ্যাঁ');
    expect(await say('মিটিংয়ের রিমাইন্ডার বন্ধ কোরো না'), contains('কিছু করছি না'));
    expect(rig.brain.data.reminders.single.enabled, isTrue);
    expect(await say('মিটিংয়ের রিমাইন্ডার বন্ধ করো'), contains('বন্ধ করে দেবো'));
    await say('হ্যাঁ');
    expect(rig.brain.data.reminders.single.enabled, isFalse);
  });

  testWidgets('done and not done: a to-do ticked by mistake opens again', (t) async {
    final rig = await start(t);
    chat = ChatController(rig.brain);
    await rig.brain.saveTask(Task(title: 'রিপোর্ট জমা দেওয়া'));
    await say('রিপোর্ট জমা দেওয়ার কাজটা শেষ হয়েছে');
    expect(rig.brain.data.tasks.single.done, isTrue);
    expect(await say('না না, রিপোর্ট জমা দেওয়া এখনো হয়নি'), contains('আবার অসমাপ্ত'));
    expect(rig.brain.data.tasks.single.done, isFalse);
  });

  testWidgets('a change of mind in one sentence: the later amount is saved', (t) async {
    final rig = await start(t);
    chat = ChatController(rig.brain);
    expect(await say('রহিমকে পাঁচশ টাকা, না সাতশ টাকা ধার দিলাম'), contains('৭০০'));
    await say('হ্যাঁ');
    expect(rig.brain.data.ledger.single.amount, 700);
  });

  testWidgets('with the AI on: a negative request never reaches it as "delete", and AI answers still need the one confirmation', (t) async {
    final rig = await start(t);
    chat = ChatController(rig.brain);
    await say('রহিমকে ৫০০ টাকা ধার দিলাম');
    await say('হ্যাঁ');
    rig.ai.key = 'test-key';
    // The AI would say "delete" — it is not even asked.
    rig.ai.answer = {'reply': '', 'items': [{'type': 'manage', 'action': 'delete'}]};
    final before = rig.ai.asked.length;
    expect(await say('রহিমের লেনদেন মুছে দিও না'), contains('কিছু করছি না'));
    expect(rig.ai.asked.length, before);
    expect(rig.brain.data.ledger, hasLength(1));
    // An AI understanding is only a proposal: nothing is written before "হ্যাঁ".
    rig.ai.answer = {'reply': '', 'items': [{'type': 'ledger_add', 'person': 'করিম', 'amount': 300, 'kind': 'lent'}]};
    await say('করিমরে তিনশ টাকা দিসি হাওলাত');
    expect(rig.brain.data.ledger, hasLength(1));
    expect(chat.wait, isNot(ChatWait.none));
  });
}

