// Owner's video of 25 Oct ("দেখো, কেমন অসংলগ্ন"): "সকাল আটটা ৪৫ মিনিটে তোমাকে
// মাদ্রাসায় নিয়ে যেতে হয়" was answered "এ বিষয়ে কোনো তথ্য নেই"; said again
// it became a to-do with no time; "তুমি কি আমার কথা শুনতেছো না, বলতেছি এটা
// রাইখো না" went to the AI and the app sat "ভাবছি…".
import 'package:digital_brain/logic/meaning.dart' show Mood, keepThat, moodOf, notListening;
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;

void main() {
  testWidgets('a clock time and a daily duty: a reminder every day at that time', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 25, 9, 18);
    final chat = ChatController(rig.brain);
    await chat.hear('সকাল আটটা ৪৫ মিনিটে তোমাকে মাদ্রাসায় নিয়ে যেতে হয়');
    for (var i = 0; i < 2 && chat.wait == ChatWait.yesNo; i++) {
      await chat.hear('হ্যাঁ');
    }
    final r = rig.brain.data.reminders.where((x) => x.title.contains('মাদ্রাসা')).toList();
    expect(r.length, 1);
    expect((r.single.hour, r.single.minute, r.single.repeat), (8, 45, Repeat.daily));
    expect(rig.brain.data.notes, isEmpty);
  });

  testWidgets('"you are not listening, keep it": sorry, and the unfinished request is kept', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 25, 9, 18);
    final chat = ChatController(rig.brain);
    await chat.hear('তুমি কি আমার কথা শুনতেছো না বলতেছি এটা রাইখো না');
    final reply = chat.messages.where((m) => !m.fromUser).last.text;
    expect(reply, contains('দুঃখিত'));
    expect(rig.brain.data.tasks, isEmpty);
    expect(rig.brain.data.notes, isEmpty);
  });

  // The second video: "দিন সকাল ৮:৪৫ …" (প্রতি lost), then "তোমাকে না রে ভাই
  // তুবা কে" (who is taken), then "কি করতেছ এভাবে থাকলে …" (a complaint).
  testWidgets('a daily reminder, the person corrected, then sorry with what is kept', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 25, 9, 22);
    final chat = ChatController(rig.brain);
    for (final s in ['দিন সকাল ৮:৪৫ মিনিটে তোমাকে মাদ্রাসায় নিয়ে যেতে হয়', 'তোমাকে না রে ভাই তুবা কে']) {
      await chat.hear(s);
      if (chat.wait == ChatWait.yesNo) await chat.hear('হ্যাঁ');
    }
    final r = rig.brain.data.reminders.single;
    expect((r.title, r.hour, r.minute, r.repeat), ('তুবাকে মাদ্রাসায় নিয়ে যেতে হয়', 8, 45, Repeat.daily));
    await chat.hear('কি করতেছ এভাবে থাকলে ইউজার ভালোভাবে নেবে এটা');
    final reply = chat.messages.where((m) => !m.fromUser).last.text;
    expect(reply, allOf(contains('দুঃখিত'), contains('তুবাকে')));
    expect(rig.brain.data.tasks, isEmpty);
    expect(rig.brain.data.reminders.length, 1);
  });

  // The third video (and "ইউজারের কথার ইমোশন বুঝতে হবে"): venting is never
  // kept as a to-do, "আমি বলি তুবা কে, তুমি শুনতেছো তোমাকে" names the word,
  // and the same reminder said again is "already there", not a change.
  testWidgets('venting answered with a sorry, never kept; corrections by "I say X, you hear Y"', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 25, 9, 30);
    final chat = ChatController(rig.brain);
    final replies = <String>[];
    for (final s in [
      'প্রতিদিন সকাল ৮ টা ৪৫ মিনিটে তোমাকে নিয়ে মাদ্রাসা যেতে হয়',
      'না এখানে হবে তুবা কেন',
      'আমি বলি তুবা কে তুমি শুনতেছো তোমাকে এটা কি হইল',
      'আরে বোকা এরকম কোন কাজ তালিকা রাখে কেউ',
      'ধুর মিয়া তোমার লগে কোন মজাই নাই তুমি কোথায় বুঝো না মিয়া',
      'তুমি ভাবতে লাগাও আধা ঘন্টা মানে লাগাও তোমার আমি কেন ব্যবহার করব তুমি নিজে বলতো',
      'তুমি একটা রিমাইন্ডার সেট করো প্রতিদিন ৮ টা ৪৫ মিনিটে আমার মেয়ে তুবাকে নিয়ে আমার মাদ্রাসায় যেতে হবে',
    ]) {
      final n = chat.messages.length;
      await chat.hear(s);
      replies.add(chat.messages.skip(n).where((m) => !m.fromUser).map((m) => m.text).join(' '));
      if (chat.wait == ChatWait.yesNo) await chat.hear('হ্যাঁ');
    }
    expect(rig.brain.data.tasks, isEmpty, reason: 'no venting kept as a to-do');
    final r = rig.brain.data.reminders.single;
    expect((r.title, r.hour, r.minute, r.repeat), ('তুবাকে নিয়ে মাদ্রাসা যেতে হয়', 8, 45, Repeat.daily));
    for (final i in [3, 4, 5]) {
      expect(replies[i], contains('দুঃখিত'), reason: replies[i]);
    }
    expect(replies[5], isNot(equals(replies[3])), reason: 'not the same long answer each time');
    expect(replies[6], contains('আগে থেকেই'));
  });

  test('moods', () {
    expect(moodOf('ধুর মিয়া'), Mood.annoyed);
    expect(moodOf('আরে বোকা এরকম কোন কাজ তালিকা রাখে কেউ'), Mood.annoyed);
    expect(moodOf('তুমি ভাবতে লাগাও আধা ঘন্টা'), Mood.impatient);
    expect(moodOf('একটু উত্তর দাও'), Mood.impatient);
    expect(moodOf('তুমি কি আমার কথা শুনতেছো না'), Mood.unheard);
    for (final calm in ['কাল সকাল ১০টায় ব্যাংকে যাব', 'রহিমকে ৫০০ টাকা দিলাম', 'আম্মার ওষুধ রাত ৯টায়', 'বাজারের লিস্ট দাও', 'আমার মেয়ে খুব মজা করেছে']) {
      expect(moodOf(calm), isNull, reason: calm);
    }
  });

  test('the words', () {
    expect(notListening('তুমি কি আমার কথা শুনতেছোনা বলতেছি এটা রাইখো না'), isTrue);
    expect(notListening('তুমি কি আমার কথা শুনতেছো না'), isTrue);
    expect(notListening('বুঝো না?'), isTrue);
    expect(notListening('আমি গান শুনি না'), isFalse);
    expect(keepThat('এটা রাইখো না'), isTrue);
    expect(keepThat('রেখে দাও'), isTrue);
    expect(keepThat('বাজারের টাকা রাখা হয়নি'), isFalse);
  });
}
