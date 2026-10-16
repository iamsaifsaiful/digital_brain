// Questions about money are answered from the money records only (the
// লেনদেন book and আয়-ব্যয়), for the right span of time — never with a
// phone number or a note that happens to sound alike.
//
// Regression: "আচ্ছা এ মাসে কি আমার কোন লেনদেন আছে অন্যান্য লেনদেন" was
// answered "কয়েকটা মিলেছে। সবচেয়ে কাছেরটা হলো — Messi-এর নম্বর …".
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/trace.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, start;

Future<void> seed(Rig rig) async {
  final b = rig.brain;
  // The app's clock is 9 Oct 2026, 15:53 (local time).
  await b.saveContact(Contact(name: 'Messi', phone: '+17548241066'));
  await b.saveNote(Note(title: 'মেসির নম্বর', body: 'মেসির নম্বর +17548241066'));
  await b.saveCash(CashEntry(kind: CashKind.income, amount: 2500, category: 'বেতন', date: DateTime(2026, 10, 3)));
  await b.saveCash(CashEntry(kind: CashKind.expense, amount: 400, category: 'বাজার', date: DateTime(2026, 10, 5)));
  await b.saveCash(CashEntry(kind: CashKind.expense, amount: 150, category: 'অন্যান্য', date: DateTime(2026, 10, 1, 0, 30)));
  // Last month, a few minutes before this month began: never in "এ মাসে".
  await b.saveCash(CashEntry(kind: CashKind.expense, amount: 9999, category: 'অন্যান্য', date: DateTime(2026, 9, 30, 23, 50)));
  await b.saveEntry(LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 700, date: DateTime(2026, 10, 7)));
}

void main() {
  late ChatController chat;
  Future<String> say(String s) => chat.hear(s);
  String facts() => chat.messages.last.facts.join('\n');

  testWidgets('the screenshot question: asked which is meant, then only this month’s money records', (t) async {
    final rig = await start(t);
    await seed(rig);
    chat = ChatController(rig.brain);
    final q = await say('আচ্ছা এ মাসে কি আমার কোন লেনদেন আছে অন্যান্য লেনদেন');
    expect(q, 'অন্যান্য খাতের লেনদেন, নাকি এই মাসের সব লেনদেন দেখতে চান?');
    expect(q, isNot(contains('Messi')));
    expect(chat.wait, ChatWait.clarify);

    final all = await say('সব লেনদেন');
    expect(all, contains('৪টা লেনদেন'));
    expect(all, contains('আয় ২,৫০০ টাকা'));
    expect(all, contains('খরচ ৫৫০ টাকা'));
    expect('$all\n${facts()}', isNot(contains('Messi')));
    expect(facts(), isNot(contains('৯,৯৯৯')), reason: 'last month (30 Sep 23:50) is not this month');
    expect(facts(), contains('রহিম'));
    // The link goes to the same records.
    expect(chat.messages.last.links.map((l) => l.label), containsAll(['আয়-ব্যয় দেখুন', 'লেনদেন (ধার-দেনা) দেখুন']));
  });

  testWidgets('"অন্যান্য খাতের": only that খাত, this month — 1 Oct 00:30 is in, 30 Sep 23:50 is out', (t) async {
    final rig = await start(t);
    await seed(rig);
    chat = ChatController(rig.brain);
    await say('এ মাসে অন্যান্য লেনদেন কী কী?');
    final r = await say('অন্যান্য খাতের');
    expect(r, contains('১টা লেনদেন'));
    expect(r, contains('খরচ ১৫০ টাকা'));
    expect(facts(), isNot(contains('বাজার')));
    expect(facts(), isNot(contains('৯,৯৯৯')));
  });

  testWidgets('a follow-up keeps the question and changes the span; nothing found is said plainly', (t) async {
    final rig = await start(t);
    await seed(rig);
    chat = ChatController(rig.brain);
    await say('এ মাসের লেনদেনগুলো দেখাও');
    final last = await say('আর গত মাসে?');
    expect(last, contains('গত মাসে'));
    expect(last, contains('১টা লেনদেন'));
    expect(facts(), contains('৯,৯৯৯'));
    final none = await say('গত বছরের লেনদেন দেখাও');
    expect(none, 'গত বছর কোনো লেনদেন পাওয়া যায়নি।');
    expect(chat.messages.last.facts, isEmpty);
  });

  testWidgets('"আমার কত টাকা?" is not taken as this month’s income — the app asks which', (t) async {
    final rig = await start(t);
    await seed(rig);
    chat = ChatController(rig.brain);
    final r = await say('আমার কত টাকা');
    expect(r, 'কোনটা জানতে চান?');
    expect(chat.choices.map((c) => c.label), containsAll(['এ মাসের আয়-খরচ', 'মানুষের কাছে পাওনা']));
    expect(await say('মানুষের কাছে পাওনা'), contains('৭০০'));
  });

  testWidgets('the AI is never asked to put money into words', (t) async {
    final rig = await start(t);
    await seed(rig);
    chat = ChatController(rig.brain);
    rig.ai.key = 'test-key';
    rig.ai.answer = {'reply': 'এই মাসে আপনার ১০,০০০ টাকা আছে।', 'items': []};
    final before = rig.ai.asked.length;
    await say('এ মাসের লেনদেনগুলো দেখাও');
    await say('আমার কত টাকা আছে?');
    await say('কার কাছে কত পাই?');
    expect(rig.ai.asked.length, before);
    expect(chat.messages.where((m) => m.text.contains('১০,০০০')), isEmpty);
  });

  test('money questions never become a text search', () {
    for (final s in ['আচ্ছা এ মাসে কি আমার কোন লেনদেন আছে অন্যান্য লেনদেন', 'আমার কত টাকা', 'টাকার হিসাবটা কী?', 'এ মাসের খরচগুলো কী কী?']) {
      final c = Parser(ledger: const [], now: DateTime(2026, 10, 9)).parse(s);
      expect(c, isNot(isA<SearchQuery>()), reason: s);
    }
  });

  testWidgets('the trace shows what was understood, where it looked and what it found — numbers hidden', (t) async {
    final rig = await start(t);
    await seed(rig);
    Trace.enabled = true;
    Trace.clear();
    chat = ChatController(rig.brain);
    await say('আচ্ছা এ মাসে কি আমার কোন লেনদেন আছে অন্যান্য লেনদেন');
    await say('সব লেনদেন');
    final log = Trace.dump();
    expect(log, contains('জিজ্ঞেস: অন্যান্য খাতের লেনদেন'));
    expect(log, contains('লেনদেনের তালিকা: এই মাসে'));
    expect(log, contains('sources=“ledger, cash”'));
    expect(log, contains('found=“1 ledger + 3 cash”'));
    expect(log, isNot(contains('17548241066')));
  });
}
