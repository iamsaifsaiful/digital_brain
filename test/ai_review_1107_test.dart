// The owner's AI review of 7 Nov (18 real messages): what the app answered
// wrongly, fixed in general ways — never a rule per sentence.
import 'package:digital_brain/logic/categories.dart';
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/nlu/reader.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;

void main() {
  testWidgets('talk read by the rules as a search with nothing found: the sure model answers as talk', (t) async {
    final rig = await start(t);
    final b = rig.brain..nluMode = 'on';
    final (talk, _) = await b.understandAll('কিরে খবর কি', model: Future.value(const [NluPiece('smalltalk', 0.9, true, [], {})]));
    expect(talk.single, isA<SmallTalk>());
    final (help, _) = await b.understandAll('কি শুনছো প্রশ্ন করলে ভাত খাব এটা বলব', model: Future.value(const [NluPiece('complain_help', 0.9, true, [], {})]));
    expect((help.single as SmallTalk).kind, Talk.sorry);
    // Not sure: as before.
    final (unsure, _) = await b.understandAll('কিরে খবর কি', model: Future.value(const [NluPiece('smalltalk', 0.4, false, [], {})]));
    expect(unsure.single, isNot(isA<SmallTalk>()));
  });

  testWidgets('a search that finds something is never turned into talk', (t) async {
    final rig = await start(t);
    final b = rig.brain..nluMode = 'on';
    await b.saveNote(Note(title: 'বাবার ব্লাড গ্রুপ', body: 'বাবার ব্লাড গ্রুপ বি পজিটিভ'));
    final (c, _) = await b.understandAll('বাবার ব্লাড গ্রুপ', model: Future.value(const [NluPiece('smalltalk', 0.9, true, [], {})]));
    expect(c.single, isNot(isA<SmallTalk>()));
  });

  testWidgets('premium asked about: its state; all numbers asked for: the phone book', (t) async {
    final rig = await start(t);
    final chat = ChatController(rig.brain);
    await chat.hear('আমার প্রিমিয়াম কি চালু আছে');
    expect(chat.messages.last.text, isNot(contains('কোনো তথ্য নেই')));
    rig.brain.data.contacts.addAll([Contact(name: 'রহিম', phone: '01711000001'), Contact(name: 'করিম', phone: '01711000002')]);
    await chat.hear('নম্বর গুলো দেখাও তোমার কাছে আমার যত নম্বর আছে দেখাও');
    expect(chat.messages.last.text, contains('২টা নম্বর'));
  });

  testWidgets('a reminder asked for with "সেটা হল …" is a new reminder, not "no such to-do"', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 7, 12);
    final chat = ChatController(rig.brain);
    await chat.hear('আচ্ছা শোন একটা কাজ করো সেটা হল আগামীকালকে সকাল দশটায় আমার একটা মিটিং আছে একটু রিমাইন্ডার সেট করো');
    final r = rig.brain.data.reminders.single;
    expect((r.date, r.hour), (DateTime(2026, 11, 8), 10));
    expect(r.title, contains('মিটিং'));
    expect(r.title, isNot(contains('সেটা')));
  });

  test('"বিলিয়ন" is not a bill', () {
    expect(guessCategory(AppData(), 'আমার কাছে ১০ বিলিয়ন ডলার আছে').name, isNot('বিল'));
    expect(guessCategory(AppData(), 'বিদ্যুতের বিলের কাগজ').name, 'বিল');
  });
}
