// Owner's screenshot of 25 Oct (a voice conversation): "সাবিনা ২০০০ টাকা ফেরত
// দিয়েছে" → "no one owed — what happened?" → "সাবিনা না এটা রবিন হবে" (not
// Sabina, Robin) became a to-do named "সাবিনা না রবিন". The answer names the
// right person: the return is Robin's.
import 'package:digital_brain/logic/meaning.dart' show personCorrection;
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/logic/plan.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;

void main() {
  testWidgets('"X না, এটা Y হবে" to the money question: the return is Y\'s, no to-do', (t) async {
    final rig = await start(t,
        data: AppData(ledger: [LedgerEntry(person: 'রবিন', kind: LedgerKind.lent, amount: 5000, date: DateTime(2026, 10, 20))]));
    final chat = ChatController(rig.brain);
    await chat.hear('সাবিনা ২০০০ টাকা ফেরত দিয়েছে');
    expect(chat.wait, ChatWait.kind);
    await chat.hear('সাবিনা না এটা রবিন হবে');
    if (chat.wait == ChatWait.yesNo) await chat.hear('হ্যাঁ');
    expect(rig.brain.data.tasks, isEmpty, reason: 'never a to-do');
    final r = rig.brain.data.ledger.where((e) => e.kind == LedgerKind.received).toList();
    expect(r.map((e) => (e.person, e.amount)), [('রবিন', 2000)]);
  });

  test('a name corrected in a reply', () {
    expect(personCorrection('সাবিনা না এটা রবিন হবে', 'সাবিনা'), 'রবিন');
    expect(personCorrection('না, রবিন', 'সাবিনা'), 'রবিন');
    expect(personCorrection('রবিন হবে', 'সাবিনা'), 'রবিন');
    expect(personCorrection('সাবিনা না রবিনের কাছ থেকে', 'সাবিনা'), 'রবিন');
    expect(personCorrection('নতুন ধার', 'সাবিনা'), isNull);
    expect(personCorrection('শোধ করেছে', 'সাবিনা'), isNull);
    expect(personCorrection('না', 'সাবিনা'), isNull);
    expect(personCorrection('সাবিনা হবে', 'সাবিনা'), isNull, reason: 'the same person');
  });

  // A loan told as the past, then what came back: both kept when the book
  // has no loan yet; only what came back when it has.
  test('past loan, then a return, in one breath', () {
    final now = DateTime(2026, 10, 25, 9, 30);
    String read(String s, [List<LedgerEntry> l = const []]) =>
        parseAll(s, l, now: now).map((c) => c is LedgerAdd ? '${c.kind?.name}:${c.person}:${c.amount}' : '${c.runtimeType}').join(' ');
    expect(read('মিলন ভাই আমার থেকে আট হাজার টাকা নিয়েছিল কাল তিন হাজার শোধ দিল'), 'lent:মিলন ভাই:8000 received:মিলন ভাই:3000');
    expect(read('বাবুলকে ৬০০০ টাকা দিয়েছিলাম সে আজ সব ফেরত দিয়েছে'), 'lent:বাবুল:6000 received:বাবুল:6000');
    expect(read('আমি তানিয়ার কাছ থেকে ১৫০০ টাকা নিছিলাম আজ ফেরত দিছি'), 'borrowed:তানিয়া:1500 repaid:তানিয়া:1500');
    expect(read('বাবুলকে ৬০০০ টাকা দিয়েছিলাম সে আজ দুই হাজার ফেরত দিয়েছে', [LedgerEntry(person: 'বাবুল', kind: LedgerKind.lent, amount: 6000, date: DateTime(2026, 10, 1))]),
        'received:বাবুল:2000', reason: 'the loan is already in the book');
  });

  test('sentences, each its own request', () {
    final now = DateTime(2026, 10, 25, 9, 30);
    final a = parseAll('সোমবার দর্জির কাছে যাব। মঙ্গলবার চুল কাটাব', const [], now: now);
    expect(a.whereType<TaskAdd>().length, 2);
    final b = parseAll('বৃহস্পতিবার বোনের বাড়ি যাওয়া কাজের তালিকায় রাখো। রবিবার সকাল নয়টায় ইন্টারনেট বিল দিতে হবে মনে করিয়ে দিও', const [], now: now);
    expect(b.map((c) => c.runtimeType.toString()), ['TaskAdd', 'ReminderAdd']);
  });
}
