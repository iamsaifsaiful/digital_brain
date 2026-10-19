// 19 Oct, 20:33 screenshots: each conversation as it was had, now checked
// by what it leaves in the data.
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'angles_test.dart' show fixture, state;
import 'app_test.dart' show start;

void main() {
  late ChatController chat;
  late dynamic rig;
  Future<String> say(String x) async {
    final n0 = chat.messages.length;
    await chat.hear(x);
    return chat.messages.skip(n0).where((m) => !m.fromUser).map((m) => [m.text, ...m.facts].join(' ')).join(' ');
  }

  Future<void> open(WidgetTester t) async {
    rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 19, 20, 30);
    rig.brain.data = fixture();
    chat = ChatController(rig.brain);
  }

  testWidgets('S1 list → "শেষের তিনটি কাজ বাদ দাও" → হ্যাঁ → "৩নং কাজের নাম পরিবর্তন হবে, শ্রমিক দিবস": the third of what is left, renamed', (t) async {
    await open(t);
    await say('আমার কাজের তালিকা দাও');
    await say('শেষের তিনটি কাজ বাদ দাও');
    final done = await say('হ্যাঁ');
    expect(done, contains('১.'), reason: 'what is left is shown with its numbers');
    final r = await say('৩নং কাজের নাম পরিবর্তন হবে, শ্রমিক দিবস');
    final d = rig.brain.data;
    expect(d.tasks.map((x) => x.id).toSet(), {'T7', 'T1', 'T2', 'T3'});
    expect(d.tasks.firstWhere((x) => x.id == 'T2').title, 'শ্রমিক দিবস', reason: r);
    expect(r, contains('নোয়াখালী যাওয়া'), reason: 'the old name is said back');
    expect(chat.openNow, isNull, reason: 'no page opened');
  });

  testWidgets('S2 "যশোর যাওয়া কাজের নাম বদল হবে শ্বশুর বাড়ি যাওয়া": renamed — never a note', (t) async {
    await open(t);
    final r = await say('যশোর যাওয়া কাজের নাম বদল হবে শ্বশুর বাড়ি যাওয়া');
    expect(rig.brain.data.tasks.firstWhere((x) => x.id == 'T3').title, 'শ্বশুর বাড়ি যাওয়া', reason: r);
    expect(rig.brain.data.notes, isEmpty);
  });

  testWidgets('S3 something kept, then "না। কাজের নাম বদল কর": what was kept is taken back', (t) async {
    await open(t);
    final before = state(rig.brain.data);
    await say('যশোর যাওয়া শ্বশুর বাড়ি যাওয়া লিখে রাখো');
    final r = await say('না। কাজের নাম বদল কর');
    if (chat.wait != ChatWait.none) await say('না');
    final now = state(rig.brain.data);
    // Either the rename was done from the words before, or nothing is left kept.
    final renamed = rig.brain.data.tasks.any((x) => x.title == 'শ্বশুর বাড়ি যাওয়া') && rig.brain.data.tasks.length == 7;
    expect(renamed || now == before, isTrue, reason: r);
    expect(rig.brain.data.notes, isEmpty, reason: r);
    expect(r, isNot(contains('নতুন বিভাগ')), reason: r);
  });

  testWidgets('S4 "যশোর যাওয়া কাজের রিমাইন্ডার দাও" → "হ্যাঁ দাও": the time offered', (t) async {
    await open(t);
    await say('যশোর যাওয়া কাজের রিমাইন্ডার দাও');
    final r = await say('হ্যাঁ দাও');
    final x = rig.brain.data.tasks.firstWhere((x) => x.id == 'T3');
    expect(x.reminderId, isNotNull, reason: r);
    final rem = rig.brain.data.reminders.firstWhere((y) => y.id == x.reminderId);
    expect((rem.date, rem.hour), (DateTime(2029, 2, 15), 9));
  });

  testWidgets('S5 "৩১ অক্টোবরের রিমাইন্ডারের সময় পরিবর্তন করে সন্ধ্যা ৭টা কর": that day\'s one only', (t) async {
    await open(t);
    final r = await say('৩১ অক্টোবরের রিমাইন্ডারের সময় পরিবর্তন করে সন্ধ্যা ৭টা কর');
    expect(r, contains('তুবার জন্মদিন'));
    expect(r, isNot(contains('পাসপোর্ট')));
    await say('হ্যাঁ');
    expect(rig.brain.data.reminders.firstWhere((y) => y.id == 'R1').hour, 19);
    expect(rig.brain.data.reminders.firstWhere((y) => y.id == 'R6').hour, 10);
  });

  testWidgets('S6 "তুমি ভুল রিমাইন্ডার দেখাচ্ছো": heard as a complaint — no name search', (t) async {
    await open(t);
    final before = state(rig.brain.data);
    final r = await say('তুমি ভুল রিমাইন্ডার দেখাচ্ছো');
    expect(r, isNot(contains('এই নামে')));
    expect(state(rig.brain.data), before);
  });

  testWidgets('S7 "তুবার জন্মদিনের রিমাইন্ডারের সময় পরিবর্তন কর": the time asked here, no page', (t) async {
    await open(t);
    final r = await say('তুবার জন্মদিনের রিমাইন্ডারের সময় পরিবর্তন কর');
    expect(chat.openNow, isNull, reason: r);
    expect(chat.wait, ChatWait.changeTo, reason: r);
    await say('রাত ৯টায়');
    expect(rig.brain.data.reminders.firstWhere((y) => y.id == 'R1').hour, 21);
  });

  testWidgets('S8 "২০২৭ সালের রিমাইন্ডার গুলো বাদ দাও": the two of 2027, never all', (t) async {
    await open(t);
    final r = await say('২০২৭ সালের রিমাইন্ডার গুলো বাদ দাও');
    expect(r, contains('২টা'), reason: r);
    await say('হ্যাঁ');
    expect(rig.brain.data.reminders.map((y) => y.id).toSet(), {'R1', 'R2', 'R3', 'R6', 'R7'});
  });

  testWidgets('S9 "সব রিমাইন্ডার মুছে দাও" → "শুধু ২০২৭ সালের": narrowed and asked again', (t) async {
    await open(t);
    await say('সব রিমাইন্ডার মুছে দাও');
    final r = await say('শুধু ২০২৭ সালের');
    expect(r, contains('২টা'), reason: r);
    expect(rig.brain.data.reminders, hasLength(7), reason: 'nothing removed before the yes');
    await say('হ্যাঁ');
    expect(rig.brain.data.reminders.map((y) => y.id).toSet(), {'R1', 'R2', 'R3', 'R6', 'R7'});
  });

  testWidgets('S10 reminders shown → "শুধুমাত্র ২০২৭ সালের গুলো মুছে দাও"', (t) async {
    await open(t);
    await say('আমার সব রিমাইন্ডার দাও');
    final r = await say('শুধুমাত্র ২০২৭ সালের গুলো মুছে দাও');
    expect(r, contains('২টা'), reason: r);
    await say('হ্যাঁ');
    expect(rig.brain.data.reminders.map((y) => y.id).toSet(), {'R1', 'R2', 'R3', 'R6', 'R7'});
  });
}
