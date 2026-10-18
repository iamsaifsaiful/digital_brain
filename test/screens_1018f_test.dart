// The sixth set of 18 Oct screenshots (2.27.0-b37), replayed word for word.
import 'package:digital_brain/state/brain.dart';
import 'package:digital_brain/logic/match.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, start;

void main() {
  late Rig rig;
  late ChatController chat;

  Future<String> say(String s) async {
    final n = chat.messages.length;
    await chat.hear(s);
    final r = chat.messages.skip(n).where((m) => !m.fromUser).map((m) => [m.text, ...m.facts].join(' ')).join(' ');
    // ignore: avoid_print
    print('» $s\n  ${r.replaceAll('\n', ' / ')}  [wait=${chat.wait}]');
    return r;
  }

  AppData data() => rig.brain.data;

  Future<void> open(WidgetTester t) async {
    rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 18, 17, 40);
    data().projects.addAll([Project(id: 'p1', name: 'শিক্ষার্থীদের বেতন'), Project(id: 'p2', name: 'বাড়ি মেরামত')]);
    chat = ChatController(rig.brain);
  }

  Future<void> fiveTasks() async {
    for (final (i, n) in ['বাজারে যাবো', 'সোনাইমুড়ী যাবো', 'রবিনের বোনের বিয়েতে দাওয়াত', 'রবিনের বোনের বিয়েতে দাওয়াত', 'ঢাকায় ব্যাক করা'].indexed) {
      data().tasks.add(Task(id: 't$i', title: n, due: DateTime(2026, 10, 23), createdAt: DateTime(2026, 10, 1)));
    }
    await say('আমার কাজের তালিকা দাও');
  }

  for (final s in [
    'রবিনের বোনের বিয়ের দাওয়াতের কাজ রেখে বাকি গুলো বাদ দাও',
    '৩ নং ৪নং বাদে বাকি গুলো বাদ দাও',
    'রবিনের বোনের বিয়ের দাওয়াত থাকবে শুধু',
  ]) {
    testWidgets('১–৩. "$s" keeps the দাওয়াত to-dos, removes the rest', (t) async {
      await open(t);
      await fiveTasks();
      final q = await say(s);
      expect(q, contains('৩টা কাজ মুছে দেব'));
      await say('হ্যাঁ');
      expect(data().tasks.map((x) => x.id), unorderedEquals(['t2', 't3']));
    });
  }

  testWidgets('৪–৫. "ফেব্রুয়ারীর ১৫ তারিখে" is February; a month correction moves the day kept', (t) async {
    await open(t);
    final r = await say('ফেব্রুয়ারীর ১৫ তারিখে আমার বিবাহ বার্ষিকী');
    expect(r, contains('১৫ ফেব্রুয়ারি'));
    await say('হ্যাঁ');
    final day = data().specialDays.single;
    expect([day.month, day.day], [2, 15]);
    // Kept wrong (as b37 did), then corrected in the user's words.
    await rig.brain.saveSpecialDay(day.copyWith(month: 11));
    await say('আমি বললাম ফেব্রুয়ারী, তুমি নভেম্বর কেন করছো?');
    expect(data().specialDays.single.month, 2);
    final rem = data().reminders.firstWhere((x) => x.id == data().specialDays.single.reminderId);
    expect(rem.date.month, 2, reason: 'the yearly reminder moves with it');
    await rig.brain.saveSpecialDay(data().specialDays.single.copyWith(month: 11));
    await say('এটা ১৫ ফেব্রুয়ারী হবে');
    expect(data().specialDays.single.month, 2);
    expect(data().notes, isEmpty);
  });

  testWidgets('৬, ১০. money taken along (said with a comma) is not spent; a question about the list keeps it', (t) async {
    await open(t);
    final r = await say('আজ সকালে ৯০০০ টাকা নিয়ে বাজারে গেলাম, ২৫০০ টাকার মাছ কিনলাম, ২০০০ টাকার মুদি মালামাল, ৩০০০ টাকার মাংস। ১৫০ টাকা ভাড়া দিছি');
    expect(r, contains('৪টা'));
    final q = await say('খরচ মাত্র ১৫০ টাকা?');
    expect(q, contains('৭,৬৫০'));
    expect(chat.wait, ChatWait.yesNo, reason: 'still waiting for the yes');
    await say('হ্যাঁ');
    expect([for (final e in data().cash) e.amount], unorderedEquals([2500, 2000, 3000, 150]));
  });

  testWidgets('৭. one verb for several people: none lost', (t) async {
    await open(t);
    final r = await say('আজ শফিক ভাইকে দিলাম ২৫০ টাকা, ইসমাঈলকে ৩৭১২ টাকা, রবিনকে ২০০ টাকা, শাকিলকে ৫০০ টাকা।');
    expect(r, contains('৪টা'));
    for (final n in ['শফিক ভাই', 'ইসমাঈল', 'রবিন', 'শাকিল']) {
      expect(r, contains(n));
    }
  });

  testWidgets('৮–৯. a money list under a heading; one item corrected before keeping', (t) async {
    await open(t);
    final r = await say('আজ সারাদিনের আয় ব্যয়ের হিসাব-\n\n১. নাহিয়ান ২০০০ টাকা দিয়েছে বেতন হিসেবে\n২. রেমিট্যান্স এসেছে ১৫০০০ টাকা\n৩. শফিক ভাইকে দিলাম ৭০০০ টাকা\n৪. ৪৫০ টাকা বাজার এনেছি\n৫. সাইফুল মিয়াকে দিলাম ১০০ টাকা');
    expect(r, isNot(contains('এই মাসে')), reason: 'the heading is not a question');
    expect(r, contains('৫টা'));
    expect(r, contains('আয়: বেতন (নাহিয়ান) — ২,০০০'));
    expect(r, contains('খরচ: বাজার — ৪৫০'), reason: 'বাজার এনেছি: the item is the খাত itself');
    expect(r, contains('সাইফুল মিয়া'));
    final e = await say('সব যথাযথ ভাবে হয় নাই। নাহিয়ানের বেতন অন্যান্য হিসাবের ভেতরে শিক্ষার্থীদের বেতনে যুক্ত কর');
    expect(e, contains('শিক্ষার্থীদের বেতন'));
    expect(data().cash, isEmpty, reason: 'nothing kept before the yes');
    expect(data().ledger, isEmpty);
  });

  testWidgets('১১. "কিসের বিল?" is the bill kept — not a contact', (t) async {
    await open(t);
    data().contacts.add(Contact(name: 'kechia wilson', phone: '9542051108'));
    data().cash.add(CashEntry(kind: CashKind.expense, amount: 2700, category: 'বিল', note: 'মিস্ত্রীর বিল ২৭০০ টাকা', projectId: 'p2', date: DateTime(2026, 10, 18)));
    final r = await say('কিসের বিল?');
    expect(r, isNot(contains('kechia')));
    expect(r, contains('মিস্ত্রীর বিল'));
  });

  test('a short sound-alike needs its vowels too', () {
    expect(wordsMatch('কিস', 'kechia'), isFalse);
    expect(wordsMatch('রিতু', 'ritu'), isTrue);
  });
}
