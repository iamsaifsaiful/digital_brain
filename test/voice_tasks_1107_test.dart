// 7 Nov: to-dos by voice — a to-do and its own reminder said as one, the
// time said once and plainly, a list's item moved by a follow-up, and
// changes asked in the ways people say them.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/voice.dart' show forSpeech;
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, start;

void main() {
  late Rig rig;
  late ChatController chat;
  Future<String> say(String s) async {
    final n = chat.messages.length;
    await chat.hear(s);
    return chat.messages.skip(n).where((m) => !m.fromUser).map((m) => m.text).join(' ‖ ');
  }

  Future<void> begin(WidgetTester t) async {
    rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 7, 8);
    chat = ChatController(rig.brain);
    await rig.brain.saveTask(Task(title: 'বাজার করা', due: DateTime(2026, 11, 7)));
  }

  Task task(String title) => rig.brain.data.tasks.firstWhere((x) => x.title == title);

  testWidgets('a to-do with its reminder is one item; the time in its name is not the reminder time', (t) async {
    await begin(t);
    await rig.brain.saveTask(Task(title: 'সকাল ১০ টায় পড়ানো', due: DateTime(2026, 11, 7)));
    expect(await say('সকাল ১০ টায় পড়ানো কাজটার রিমাইন্ডার সকাল সাড়ে ৯টায় দাও'), contains('৯:৩০'));
    final r = rig.brain.data.reminders.single;
    expect((r.hour, r.minute), (9, 30));
    expect(task('সকাল ১০ টায় পড়ানো').reminderId, r.id);
    final a = await say('আমার আজ কাজের তালিকা কি?');
    expect(a, startsWith('আজ ২টা'));
    expect(a, contains('সকাল ১০ টায় পড়ানো — রিমাইন্ডার সকাল ৯:৩০-এ'));
    expect(a, isNot(contains('(')));
  });

  testWidgets('"এই তালিকা থেকে পড়ানোটা কালকের তালিকায় যুক্ত কর" moves that one, with its reminder', (t) async {
    await begin(t);
    await rig.brain.saveTask(Task(title: 'পড়ানো', due: DateTime(2026, 11, 7)));
    await say('পড়ানো কাজটার রিমাইন্ডার সকাল সাড়ে ৯টায় দাও');
    await say('আজ কী কী কাজ আছে?');
    final a = await say('এই তালিকা থেকে পড়ানোটা কালকের তালিকা তে যুক্ত কর');
    expect(a, contains('পড়ানো'));
    expect(task('পড়ানো').due, DateTime(2026, 11, 8));
    expect(rig.brain.data.reminders.single.date, DateTime(2026, 11, 8));
    expect(task('বাজার করা').due, DateTime(2026, 11, 7));
    expect(rig.brain.data.tasks.length, 2);
  });

  testWidgets('a reminder named from the list is moved too', (t) async {
    await begin(t);
    await rig.brain.saveReminder(Reminder(title: 'ওষুধ খাওয়া', date: DateTime(2026, 11, 7), hour: 11, minute: 30));
    expect(await say('আজকের কাজের তালিকা দাও'), contains('সকাল ১১:৩০-এ ওষুধ খাওয়া'));
    await say('ওখান থেকে ওষুধেরটা পরশু সরাও');
    expect(rig.brain.data.reminders.single.date, DateTime(2026, 11, 9));
  });

  for (final (s, title) in [
    ('বাজার করা কাজটা বদলে মাছ কেনা কর', 'মাছ কেনা'),
    ('বাজার করার জায়গায় মাছ কেনা লেখো', 'মাছ কেনা'),
    ('বাজার করা এর বদলে লেখো মাছ কেনা', 'মাছ কেনা'),
  ]) {
    testWidgets('rename: $s', (t) async {
      await begin(t);
      final a = await say(s);
      expect(rig.brain.data.tasks.single.title, title);
      expect(a, '“বাজার করা”-এর নাম বদলে “মাছ কেনা” করেছি।');
    });
  }

  testWidgets('a note for a named to-do; a vague change asks what; "-টা … করব" moves it', (t) async {
    await begin(t);
    await rig.brain.saveTask(Task(title: 'বিদ্যুৎ বিল দেওয়া', due: DateTime(2026, 11, 7)));
    await say('বাজার করা কাজের সাথে লিখে রাখো সবজিও কিনতে হবে');
    expect(task('বাজার করা').note, contains('সবজি'));
    expect(await say('কাজের তালিকায় বাজার করা কাজটা পরিবর্তন করো'), contains('কী বদলাব'));
    await say('বাজার করাটা কাল সকালে করব');
    expect(task('বাজার করা').due, DateTime(2026, 11, 8));
    expect(rig.brain.data.tasks.length, 2);
  });

  test('spoken: no brackets, clock times said as words', () {
    expect(forSpeech('পড়ানো (সকাল ৯:৩০)।'), 'পড়ানো, সকাল ৯টা ৩০।');
    expect(forSpeech('সকাল ১০:০০-এ'), 'সকাল ১০টা-এ');
    expect(forSpeech('সকাল ৯:০৫'), 'সকাল ৯টা ৫');
  });
}
