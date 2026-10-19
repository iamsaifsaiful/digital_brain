// The to-do list and its reminders, by voice and typing (19 Oct brief):
// the 60 regression scenarios, run on the real chat pipeline with a frozen
// clock (Monday 19 Oct 2026, 10:00, Asia/Dhaka wall time). Each states the
// starting data, the turns, the items it must touch, and what must be left
// alone. Typed input and a voice final take the same path (ChatController.hear),
// so these check the transcript → action half; the microphone itself is not
// measured here.
import 'dart:convert';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, start;

/// Nine to-dos in the order the list shows them (by day, then as added).
List<Task> nine() {
  final at = DateTime(2026, 10, 1);
  var i = 0;
  Task t(String id, String title, DateTime? due) => Task(id: id, title: title, due: due, createdAt: at.add(Duration(minutes: i++)));
  return [
    t('k1', 'ব্যাংকে যাওয়া', DateTime(2026, 10, 20)),
    t('k2', 'রবিনের বোনের বিয়েতে দাওয়াত', DateTime(2026, 10, 23)),
    t('k3', 'রবিনের বোনের বিয়েতে দাওয়াত', DateTime(2026, 10, 24)),
    t('k4', 'ঢাকায় যাওয়া', DateTime(2026, 10, 29)),
    t('k5', 'পার্টি', DateTime(2026, 10, 30)),
    t('k6', 'বাচ্চাকে স্কুলে নেওয়া', DateTime(2027, 1, 1)),
    t('k7', 'লাইব্রেরী থেকে বই কেনা', DateTime(2027, 1, 1)),
    t('k8', 'বাচ্চার জামা সেলাইতে দেওয়া', DateTime(2027, 1, 1)),
    t('k9', 'রেস্টুরেন্টে খেতে যাওয়া', DateTime(2027, 1, 1)),
  ];
}

void main() {
  late Rig rig;
  late ChatController chat;
  AppData data() => rig.brain.data;
  Set<String> ids() => {for (final x in data().tasks) x.id};
  Set<String> open() => {for (final x in data().tasks) if (!x.done) x.id};

  Future<void> begin(WidgetTester t, {bool tasks = true, void Function(Rig)? setup}) async {
    rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 19, 10);
    if (tasks) data().tasks.addAll(nine());
    setup?.call(rig);
    chat = ChatController(rig.brain);
  }

  Future<String> say(String s) async {
    final n = chat.messages.length;
    await chat.hear(s);
    final r = chat.messages.skip(n).where((m) => !m.fromUser).map((m) => [m.text, ...m.facts].join(' | ')).join(' ‖ ');
    // ignore: avoid_print
    print('» $s\n  ${r.replaceAll('\n', ' / ')}  [${chat.wait.name}]');
    return r;
  }

  /// Yes to the one question asked (voice "হ্যাঁ" and the button send the same).
  Future<void> yes() async {
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
  }

  Future<void> list() async => say('আমার কাজের তালিকা দাও');

  group('Selection', () {
    testWidgets('S01 "দ্বিতীয়টা বাদ দাও" removes the 2nd shown, only it', (t) async {
      await begin(t);
      await list();
      await say('দ্বিতীয়টা বাদ দাও');
      await yes();
      expect(ids(), {'k1', 'k3', 'k4', 'k5', 'k6', 'k7', 'k8', 'k9'});
    });

    testWidgets('S02 "৮নংটা বাদ দাও" / "8 no ta bad dao"', (t) async {
      await begin(t);
      await list();
      await say('৮নংটা বাদ দাও');
      await yes();
      expect(ids().contains('k8'), isFalse);
      expect(ids(), hasLength(8));
    });

    testWidgets('S03 "৩নং ৪নং রেখে বাকিগুলো বাদ" keeps exactly 3 and 4', (t) async {
      await begin(t);
      await list();
      final r = await say('৩নং ৪নং রেখে বাকিগুলো বাদ');
      expect(r, contains('৭'));
      await yes();
      expect(ids(), {'k3', 'k4'});
      final shown = await say('আমার কাজের তালিকা দাও');
      expect(shown, contains('২টা'));
    });

    testWidgets('S04 "৩ এবং ৪ বাদে সব মুছো" (and "3 ar 4 bade sob mucho")', (t) async {
      await begin(t);
      await list();
      await say('৩ এবং ৪ বাদে সব মুছো');
      await yes();
      expect(ids(), {'k3', 'k4'});
    });

    testWidgets('S05 "চার থেকে আট নম্বর মুছো": 4..8 inclusive', (t) async {
      await begin(t);
      await list();
      final r = await say('চার থেকে আট নম্বর মুছো');
      expect(r, contains('৫'));
      await yes();
      expect(ids(), {'k1', 'k2', 'k3', 'k9'});
    });

    testWidgets('S06 "প্রথম দুটো শেষ করেছি": ticked, not removed', (t) async {
      await begin(t);
      await list();
      await say('প্রথম দুটো শেষ করেছি');
      await yes();
      expect(ids(), hasLength(9));
      expect(open().containsAll(['k1', 'k2']), isFalse);
      expect(open(), hasLength(7));
    });

    testWidgets('S07 "শেষের তিনটি কাল করব": the last three move to tomorrow', (t) async {
      await begin(t);
      await list();
      await say('শেষের তিনটি কাল করব');
      await yes();
      for (final id in ['k7', 'k8', 'k9']) {
        expect(data().tasks.firstWhere((x) => x.id == id).due, DateTime(2026, 10, 20), reason: id);
      }
      expect(data().tasks.firstWhere((x) => x.id == 'k6').due, DateTime(2027, 1, 1));
    });

    testWidgets('S08 "উপরের দুটির রিমাইন্ডার দাও" → asks the time, then links two reminders', (t) async {
      await begin(t);
      await list();
      final r = await say('উপরের দুটির রিমাইন্ডার দাও');
      if (chat.wait != ChatWait.none) await say('সকাল ৯টায়');
      await yes();
      final linked = [for (final x in data().tasks) if (x.reminderId != null) x.id];
      expect(linked.toSet(), {'k1', 'k2'}, reason: r);
      expect(data().reminders.map((x) => x.title), isNot(contains(contains('দুটি'))));
    });

    testWidgets('S09 "বিয়ের কাজগুলো রেখে দাও, বাকিগুলো বাদ": both wedding ones stay', (t) async {
      await begin(t);
      await list();
      await say('বিয়ের কাজগুলো রেখে দাও, বাকিগুলো বাদ');
      await yes();
      expect(ids(), {'k2', 'k3'});
    });

    testWidgets('S10 an index past the list changes nothing', (t) async {
      await begin(t);
      await list();
      final r = await say('১২ নম্বরটা মুছে দাও');
      await yes();
      expect(ids(), hasLength(9), reason: r);
    });
  });

  group('Context', () {
    testWidgets('S11 task list → "সবগুলো মুছো": the 9 shown, asked once', (t) async {
      await begin(t, setup: (r) => r.brain.data.notes.add(Note(title: 'রাখো')));
      await list();
      final r = await say('সবগুলো মুছো');
      expect(r, contains('৯'));
      await yes();
      expect(ids(), isEmpty);
      expect(data().notes, hasLength(1));
    });

    testWidgets('S12 reminder list → "দ্বিতীয়টা বন্ধ কর": turned off, kept', (t) async {
      await begin(t, setup: (r) {
        for (final (i, x) in ['অ্যালার্ম', 'মিটিং', 'ওষুধ'].indexed) {
          r.brain.data.reminders.add(Reminder(id: 'r$i', title: x, date: DateTime(2026, 10, 19), hour: 11 + i));
        }
      });
      await say('আমার কোন রিমাইন্ডার আছে?');
      await say('দ্বিতীয়টা বন্ধ কর');
      await yes();
      expect(data().reminders, hasLength(3));
      expect(data().reminders.firstWhere((x) => x.id == 'r1').enabled, isFalse);
      expect(data().reminders.where((x) => x.enabled), hasLength(2));
    });

    testWidgets('S13 reminder list, then "আগের কাজের তালিকার দ্বিতীয়টা শেষ কর": the task list\'s 2nd', (t) async {
      await begin(t, setup: (r) {
        for (final (i, x) in ['অ্যালার্ম', 'মিটিং', 'ওষুধ'].indexed) {
          r.brain.data.reminders.add(Reminder(id: 'r$i', title: x, date: DateTime(2026, 10, 19), hour: 11 + i));
        }
      });
      await list();
      await say('আমার কোন রিমাইন্ডার আছে?');
      await say('আগের কাজের তালিকার দ্বিতীয়টা শেষ কর');
      await yes();
      expect(data().tasks.firstWhere((x) => x.id == 'k2').done, isTrue);
      expect(data().reminders.every((x) => x.enabled), isTrue);
    });

    testWidgets('S14 today\'s list → "এগুলো মুছো": only today\'s, the future ones stay', (t) async {
      await begin(t, setup: (r) {
        for (var i = 0; i < 4; i++) {
          r.brain.data.tasks.add(Task(id: 'd$i', title: 'আজকের কাজ $i', due: DateTime(2026, 10, 19)));
        }
      });
      await say('আজকের কাজ দেখাও');
      final r = await say('এগুলো মুছো');
      expect(r, contains('৪'));
      await yes();
      expect(ids(), {'k1', 'k2', 'k3', 'k4', 'k5', 'k6', 'k7', 'k8', 'k9'});
    });

    testWidgets('S15 a new clear request while a question waits is not taken as its answer', (t) async {
      await begin(t);
      await say('বাজার করার রিমাইন্ডার দাও');
      expect(chat.wait, isNot(ChatWait.none));
      await say('কাল রবিনকে কল করতে হবে');
      expect(data().tasks.any((x) => x.title.contains('রবিন') && x.due == DateTime(2026, 10, 20)), isTrue);
      expect(data().reminders.where((x) => x.title.contains('রবিন')), isEmpty);
    });
  });

  group('Compound', () {
    testWidgets('S16 "৪–৮ মুছো, ৯ নম্বরে সন্ধ্যা ৭টার রিমাইন্ডার দাও": 9 is the original 9th', (t) async {
      await begin(t);
      await list();
      await say('৪ থেকে ৮ নম্বর কাজ মুছে দাও, ৯ নম্বরে সন্ধ্যা ৭টার রিমাইন্ডার দাও।');
      await yes();
      if (chat.wait != ChatWait.none) await yes();
      expect(ids(), {'k1', 'k2', 'k3', 'k9'});
      final k9 = data().tasks.firstWhere((x) => x.id == 'k9');
      expect(k9.reminderId, isNotNull);
      final r = data().reminders.firstWhere((x) => x.id == k9.reminderId);
      expect((r.date, r.hour), (DateTime(2027, 1, 1), 19));
    });

    testWidgets('S17 "প্রথমটা শেষ, দ্বিতীয়টা কাল, তৃতীয়টা মুছো"', (t) async {
      await begin(t);
      await list();
      await say('প্রথমটা শেষ, দ্বিতীয়টা কাল, তৃতীয়টা মুছো');
      await yes();
      expect(data().tasks.firstWhere((x) => x.id == 'k1').done, isTrue);
      expect(data().tasks.firstWhere((x) => x.id == 'k2').due, DateTime(2026, 10, 20));
      expect(ids().contains('k3'), isFalse);
      expect(ids(), hasLength(8));
    });

    testWidgets('S18 "সব কাল করব, তবে ব্যাংকেরটা আজই থাকবে"', (t) async {
      await begin(t);
      await list();
      await say('সব কাল করব, তবে ব্যাংকেরটা আজই থাকবে');
      await yes();
      expect(data().tasks.firstWhere((x) => x.id == 'k1').due, DateTime(2026, 10, 19));
      expect(data().tasks.where((x) => x.id != 'k1').every((x) => x.due == DateTime(2026, 10, 20)), isTrue);
    });

    testWidgets('S19 a removal said "না" to leaves an unrelated reminder alone', (t) async {
      await begin(t, setup: (r) => r.brain.data.reminders.add(Reminder(id: 'rx', title: 'মিটিং', date: DateTime(2026, 10, 21), hour: 11)));
      await list();
      await say('৪ থেকে ৮ নম্বর মুছে দাও');
      await say('না');
      expect(ids(), hasLength(9));
      expect(data().reminders.single.enabled, isTrue);
    });

    testWidgets('S20 one part fails (no such item): the other is done and both are said truly', (t) async {
      await begin(t);
      await list();
      final r = await say('প্রথমটা শেষ, ১৫ নম্বরটা মুছো');
      await yes();
      expect(data().tasks.firstWhere((x) => x.id == 'k1').done, isTrue);
      expect(ids(), hasLength(9));
      expect(r, isNot(contains('সব করেছি')));
    });
  });

  group('Date', () {
    testWidgets('S21 a 1 Jan 2027 to-do → "রাত ৮টায় মনে করাও": on its own day', (t) async {
      await begin(t);
      await say('রেস্টুরেন্টে খেতে যাওয়ার রিমাইন্ডার দাও, রাত ৮টায়');
      await yes();
      final r = data().reminders.single;
      expect((r.date, r.hour), (DateTime(2027, 1, 1), 20));
      expect(data().tasks.firstWhere((x) => x.id == 'k9').reminderId, r.id);
    });

    testWidgets('S22 then "না, জানুয়ারির ১ তারিখে": the same reminder, year and time kept, no new category', (t) async {
      await begin(t, setup: (r) => r.brain.data.tasks.removeWhere((x) => x.id == 'k9'));
      data().tasks.add(Task(id: 'k9', title: 'রেস্টুরেন্টে খেতে যাওয়া', due: DateTime(2026, 10, 25)));
      await say('রেস্টুরেন্টে খেতে যাওয়ার রিমাইন্ডার দাও, রাত ৮টায়');
      await yes();
      final r = await say('না, জানুয়ারির ১ তারিখে');
      final rem = data().reminders.single;
      expect((rem.date, rem.hour), (DateTime(2027, 1, 1), 20));
      expect(r, isNot(contains('বিভাগ')));
    });

    testWidgets('S23 "২০৪১ সালের মে মাসের পাঁচটি কাজ" → five, May 2041, no day', (t) async {
      await begin(t, tasks: false);
      final r = await say('২০৪১ সালের মে মাসের কাজ: স্কুলে যাব, বাজার করব, চুল কাটব, ভাত খাব, ঘুমাব');
      expect(data().tasks, hasLength(5), reason: r);
      expect(data().tasks.every((x) => x.due == DateTime(2041, 5, 1) && x.span == TaskSpan.month), isTrue);
      expect(r, contains('মে'));
      expect(r, isNot(contains('২০৪১ সালের যেকোনো সময়')));
    });

    testWidgets('S24 "ওগুলো মে মাসে যুক্ত কর" after a year list moves them to May of that year', (t) async {
      await begin(t, tasks: false);
      await say('২০৪১ সালের কাজ: স্কুলে যাব, বাজার করব, চুল কাটব');
      final r = await say('ওগুলো মে মাসে যুক্ত কর');
      expect(data().tasks.every((x) => x.due == DateTime(2041, 5, 1) && x.span == TaskSpan.month), isTrue, reason: r);
      expect(data().notes, isEmpty);
      expect(data().projects, isEmpty);
    });

    testWidgets('S25 "ডিসেম্বরে যশোর যাব": the month, no made-up day', (t) async {
      await begin(t, tasks: false);
      final r = await say('ডিসেম্বরে যশোর যাব');
      final x = data().tasks.single;
      expect((x.due, x.span), (DateTime(2026, 12, 1), TaskSpan.month));
      expect(r, isNot(contains('১ ডিসেম্বর')));
    });

    testWidgets('S26 "রাতে মনে করিও" → "১১টায়" is 11 pm', (t) async {
      await begin(t);
      await say('পার্টির রিমাইন্ডার দাও রাতে');
      if (chat.wait != ChatWait.none) await say('১১টায়');
      await yes();
      final r = data().reminders.single;
      expect(r.hour, 23);
    });

    testWidgets('S27 "দুপুর ১২টায়" is not asked again', (t) async {
      await begin(t);
      final r = await say('পার্টির রিমাইন্ডার দাও দুপুর ১২টায়');
      expect(r, isNot(contains('রাত')));
      await yes();
      expect(data().reminders.single.hour, 12);
    });

    testWidgets('S28 "৩১ নভেম্বর" is not a date: asked, nothing saved', (t) async {
      await begin(t, tasks: false);
      final r = await say('৩১ নভেম্বর ঢাকায় যাব');
      expect(data().tasks.where((x) => x.due != null && x.due!.month == 12 && x.due!.day == 1), isEmpty, reason: r);
      expect(r, contains('নভেম্বর'));
      expect(data().tasks, isEmpty);
      await say('৩০ নভেম্বর');
      expect(data().tasks.single.due, DateTime(2026, 11, 30));
    });

    testWidgets('S29 a time already passed today is not quietly tomorrow', (t) async {
      await begin(t);
      final r = await say('আজ সকাল ৮টায় ব্যাংকে যাওয়ার রিমাইন্ডার দাও');
      await yes();
      expect(data().reminders.where((x) => x.date == DateTime(2026, 10, 20)), isEmpty, reason: r);
    });

    testWidgets('S30 "আগের দিন মনে করাও": the reminder moves, the to-do\'s day does not', (t) async {
      await begin(t);
      await say('পার্টির রিমাইন্ডার দাও সন্ধ্যা ৭টায়, আগের দিন');
      await yes();
      final r = data().reminders.single;
      expect(data().tasks.firstWhere((x) => x.id == 'k5').due, DateTime(2026, 10, 30));
      expect(r.date == DateTime(2026, 10, 29) || r.daysBefore == 1, isTrue, reason: '${r.date} ${r.daysBefore}');
    });
  });

  group('Batch extraction', () {
    testWidgets('S31 four to-dos for 1 Jan 2027, one shared date', (t) async {
      await begin(t, tasks: false);
      await say('২০২৭ সালের ১ জানুয়ারির কাজ— বাচ্চাকে স্কুলে নেব, লাইব্রেরি থেকে বই কিনব, জামা সেলাইতে দেব, রেস্টুরেন্টে খাব।');
      expect(data().tasks, hasLength(4));
      expect(data().tasks.every((x) => x.due == DateTime(2027, 1, 1)), isTrue);
    });

    testWidgets('S32 a spoken paragraph without commas: separate to-dos', (t) async {
      await begin(t, tasks: false);
      final r = await say('১০ জানুয়ারির কাজ ঘুম থেকে উঠে রবিনকে কল করব ফ্রেশ হয়ে নাস্তা করব গোসল করে মসজিদে যাব দুপুরে দাওয়াতে যাব বিকালে সোনাইমুড়ী যাব রাতে ঢাকায় যাব');
      expect(data().tasks.length, greaterThanOrEqualTo(5), reason: r);
      expect(data().reminders, isEmpty);
      expect(data().tasks.every((x) => x.due == DateTime(2027, 1, 10)), isTrue);
    });

    testWidgets('S33 "ব্যাংকে গিয়ে টাকা জমা দেব" stays one to-do', (t) async {
      await begin(t, tasks: false);
      await say('কাল ব্যাংকে গিয়ে টাকা জমা দেব');
      expect(data().tasks, hasLength(1));
      expect(data().cash, isEmpty);
    });

    testWidgets('S34 "মাছ, চাল, তেল কিনব": one shopping to-do with its items, not three', (t) async {
      await begin(t, tasks: false);
      await say('কাল মাছ, চাল, তেল কিনব');
      expect(data().tasks, hasLength(1));
      expect(data().tasks.single.title, allOf(contains('মাছ'), contains('চাল'), contains('তেল')));
    });

    testWidgets('S35 "এগুলো আলাদা কাজ" splits the one just kept', (t) async {
      await begin(t, tasks: false);
      await say('কাল মাছ, চাল, তেল কিনব');
      final r = await say('এগুলো তিনটা আলাদা কাজ হিসেবে রাখো');
      expect(data().tasks, hasLength(3), reason: r);
      expect(data().tasks.every((x) => x.due == DateTime(2026, 10, 20)), isTrue);
    });

    testWidgets('S36 the same name on two days stays two to-dos', (t) async {
      await begin(t, tasks: false);
      await say('রবিনের বোনের বিয়েতে ২৩ এবং ২৪ তারিখে দাওয়াত');
      expect(data().tasks, hasLength(2));
      expect(data().tasks.map((x) => x.due).toSet(), {DateTime(2026, 10, 23), DateTime(2026, 10, 24)});
      final r = await say('বিয়ের কাজটা বদলাও');
      expect(r, contains('২৩'));
      expect(r, contains('২৪'));
    });
  });

  group('Pending answers', () {
    testWidgets('S37 "কোন সময়?" → "হ্যাঁ" is not a time and not a reminder title', (t) async {
      await begin(t);
      await say('পার্টির রিমাইন্ডার দাও');
      final r = await say('হ্যাঁ');
      expect(data().reminders.where((x) => x.title.contains('হ্যাঁ') || x.title.contains('হ্যা')), isEmpty, reason: r);
      expect(data().reminders, isEmpty);
    });

    testWidgets('S38 "সকাল না সন্ধ্যা?" → "সন্ধ্যা": the time\'s half', (t) async {
      await begin(t);
      await say('পার্টির রিমাইন্ডার দাও ৭টায়');
      await say('সন্ধ্যা');
      await yes();
      expect(data().reminders.single.hour, 19);
      expect(data().notes, isEmpty);
    });

    testWidgets('S39 "না, কাল না শুক্রবার" corrects, not only cancels', (t) async {
      await begin(t, tasks: false);
      await say('কাল ব্যাংকে যাব');
      await say('না, কাল না শুক্রবার');
      expect(data().tasks.single.due, DateTime(2026, 10, 23));
    });

    testWidgets('S40 "একটা না, পাঁচটা" after one long to-do: the five', (t) async {
      await begin(t, tasks: false);
      await say('কাল স্কুলে যাব বাজার করব চুল কাটব ভাত খাব ঘুমাব');
      if (data().tasks.length == 1) {
        final r = await say('একটা না, পাঁচটা আলাদা কাজ');
        expect(data().tasks, hasLength(5), reason: r);
      } else {
        expect(data().tasks, hasLength(5));
      }
    });

    testWidgets('S41 a question that lapsed is not answered by a late "হ্যাঁ"', (t) async {
      await begin(t);
      await list();
      await say('৪ থেকে ৮ নম্বর মুছে দাও');
      rig.nowAt = rig.nowAt.add(const Duration(minutes: 45));
      await say('হ্যাঁ');
      expect(ids(), hasLength(9));
    });
  });

  group('Reminders', () {
    testWidgets('S42 "এই দুটি কাজের রিমাইন্ডার দাও" links the two shown', (t) async {
      await begin(t);
      await say('বিয়ের কাজগুলো দেখাও');
      await say('এই দুটি কাজের রিমাইন্ডার দাও, দুপুর ১২টায়');
      await yes();
      final linked = {for (final x in data().tasks) if (x.reminderId != null) x.id};
      expect(linked, {'k2', 'k3'});
      expect(data().reminders.map((x) => x.title), isNot(contains(contains('দুটি'))));
      expect(data().reminders.map((x) => (x.date, x.hour)).toSet(), {(DateTime(2026, 10, 23), 12), (DateTime(2026, 10, 24), 12)});
    });

    testWidgets('S43 the same reminder asked twice: one', (t) async {
      await begin(t);
      await say('পার্টির রিমাইন্ডার দাও সন্ধ্যা ৭টায়');
      await yes();
      await say('পার্টির রিমাইন্ডার দাও সন্ধ্যা ৭টায়');
      await yes();
      expect(data().reminders, hasLength(1));
    });

    testWidgets('S44 "প্রথম তিনটি রিমাইন্ডার বন্ধ কর": off, not removed', (t) async {
      await begin(t, setup: (r) {
        for (var i = 0; i < 4; i++) {
          r.brain.data.reminders.add(Reminder(id: 'r$i', title: 'রিমাইন্ডার $i', date: DateTime(2026, 10, 20), hour: 9 + i));
        }
      });
      await say('আমার কোন রিমাইন্ডার আছে?');
      await say('প্রথম তিনটি রিমাইন্ডার বন্ধ কর');
      await yes();
      expect(data().reminders, hasLength(4));
      expect([for (final x in data().reminders) x.enabled], [false, false, false, true]);
    });

    testWidgets('S45 "শুধু রিমাইন্ডার মুছো": the to-do stays', (t) async {
      await begin(t);
      await say('পার্টির রিমাইন্ডার দাও সন্ধ্যা ৭টায়');
      await yes();
      await say('পার্টির শুধু রিমাইন্ডার মুছো');
      await yes();
      expect(ids().contains('k5'), isTrue);
      expect(data().reminders.where((x) => x.enabled), isEmpty);
    });

    testWidgets('S46 "সব রিমাইন্ডার বন্ধ": no to-do ticked or removed', (t) async {
      await begin(t);
      await say('পার্টির রিমাইন্ডার দাও সন্ধ্যা ৭টায়');
      await yes();
      await say('ব্যাংকে যাওয়ার রিমাইন্ডার দাও সকাল ১১টায়');
      await yes();
      await say('সব রিমাইন্ডার বন্ধ কর');
      await yes();
      expect(ids(), hasLength(9));
      expect(open(), hasLength(9));
      expect(data().reminders.where((x) => x.enabled), isEmpty);
    });

    testWidgets('S47 "প্রতিদিন সকাল ৯টায় অ্যালার্ম দাও" is an alarm, said as one', (t) async {
      await begin(t, tasks: false);
      final r = await say('প্রতিদিন সকাল ৯টায় অ্যালার্ম দাও');
      await yes();
      final x = data().reminders.single;
      expect(x.alarm, isTrue, reason: r);
      expect(x.repeat, Repeat.daily);
    });
  });

  group('Reliability', () {
    testWidgets('S48 a double "হ্যাঁ" runs once', (t) async {
      await begin(t);
      await list();
      await say('প্রথমটা মুছে দাও');
      await say('হ্যাঁ');
      await say('হ্যাঁ');
      expect(ids(), hasLength(8));
    });

    testWidgets('S49 the same final twice in a row: one to-do', (t) async {
      await begin(t, tasks: false);
      await say('কাল রবিনকে কল করতে হবে');
      await say('কাল রবিনকে কল করতে হবে');
      expect(data().tasks, hasLength(1));
    });

    testWidgets('S52 after a restart, to-do days and reminder links are the same', (t) async {
      await begin(t);
      await say('রেস্টুরেন্টে খেতে যাওয়ার রিমাইন্ডার দাও, রাত ৮টায়');
      await yes();
      final before = [for (final x in data().tasks) (x.id, x.due, x.span, x.reminderId)];
      final rem = data().reminders.single;
      await rig.brain.load();
      final after = [for (final x in data().tasks) (x.id, x.due, x.span, x.reminderId)];
      expect(after, before);
      expect(data().reminders.single.id, rem.id);
    });

    testWidgets('S53 the phone refusing to schedule is said, not hidden', (t) async {
      await begin(t, setup: (r) => r.notifier.failSchedule = true);
      final r = await say('পার্টির রিমাইন্ডার দাও সন্ধ্যা ৭টায়');
      await yes();
      final all = chat.messages.where((m) => !m.fromUser).map((m) => m.text).join(' ');
      expect(all, isNot(contains('মনে করিয়ে দেব')), reason: r);
      expect(all, contains('সেট করা যায়নি'));
    });

    testWidgets('S54 undo after removing several brings the same ones back', (t) async {
      await begin(t);
      await list();
      await say('৪ থেকে ৮ নম্বর মুছে দাও');
      await yes();
      expect(ids(), hasLength(4));
      final m = chat.messages.lastWhere((x) => x.undo != null);
      await chat.undo(m);
      expect(ids(), {'k1', 'k2', 'k3', 'k4', 'k5', 'k6', 'k7', 'k8', 'k9'});
    });

    testWidgets('S55 questions write nothing', (t) async {
      await begin(t);
      final before = jsonEncode(rig.brain.data.toJson());
      for (final q in ['আজ কী কাজ?', 'কাল কী আছে?', 'এই সপ্তাহে কী বাকি?', 'মোট কয়টি বাকি?', 'তারিখ ছাড়া কাজ দেখাও', 'শুধু তালিকা দেখাও', 'সব শেষ হওয়া কাজ দেখাও']) {
        await say(q);
        if (chat.wait != ChatWait.none) await say('না');
      }
      expect(jsonEncode(rig.brain.data.toJson()), before);
    });
  });

  group('Domain boundary', () {
    testWidgets('S56 "কাল ৫০০ টাকার বাজার করব" is a to-do, not spending', (t) async {
      await begin(t, tasks: false);
      await say('কাল ৫০০ টাকার বাজার করব');
      expect(data().cash, isEmpty);
      expect(data().tasks, hasLength(1));
    });

    testWidgets('S56b "আজ ৫০০ টাকার বাজার করেছি, খরচে রাখো" is spending', (t) async {
      await begin(t, tasks: false);
      await say('আজ ৫০০ টাকার বাজার করেছি, খরচে রাখো');
      await yes();
      expect(data().cash.single.amount, 500);
      expect(data().tasks, isEmpty);
    });

    testWidgets('S57 "ইমরান টাকা দিয়েছে, শুধু নোটে রাখো" is a note', (t) async {
      await begin(t, tasks: false);
      await say('ইমরান ৫০০০ টাকা দিয়েছে, শুধু নোটে রাখো');
      await yes();
      expect(data().notes, hasLength(1));
      expect(data().cash, isEmpty);
      expect(data().ledger, isEmpty);
    });

    testWidgets('S58 "পার্টির তারিখ যুক্ত কর" edits the to-do', (t) async {
      await begin(t);
      final r = await say('পার্টির তারিখ ২ নভেম্বর যুক্ত কর');
      expect(data().tasks.firstWhere((x) => x.id == 'k5').due, DateTime(2026, 11, 2), reason: r);
      expect(data().projects, isEmpty);
      expect(data().notes, isEmpty);
    });

    testWidgets('S59 "তুমি ভুল বুঝেছো" after a wrong save: recovery, not a search', (t) async {
      await begin(t, tasks: false);
      await say('কাল ব্যাংকে যাব');
      final r = await say('তুমি ভুল বুঝেছো');
      expect(r, isNot(contains('কোনো তথ্য নেই')));
      expect(r, isNot(contains('নম্বর')));
    });

    testWidgets('S60 a removal that finds nothing is not answered with contacts or money', (t) async {
      await begin(t, setup: (r) => r.brain.data.contacts.add(Contact(name: 'রবিন', phone: '01711000000')));
      final r = await say('জাহাজের কাজটা মুছে দাও');
      expect(r, isNot(contains('০১৭')));
      expect(r, isNot(contains('টাকার লেনদেন')));
    });

    testWidgets('S—"এটা নোট করে রাখো" with an amount is a note', (t) async {
      await begin(t, tasks: false);
      await say('রহিমের দোকানে চালের দাম ৮০ টাকা কেজি, এটা নোট করে রাখো');
      await yes();
      expect(data().notes, hasLength(1));
      expect(data().cash, isEmpty);
    });

    testWidgets('S—"রবিনকে কাল কল করতে হবে" is a future to-do', (t) async {
      await begin(t, tasks: false);
      await say('রবিনকে কাল কল করতে হবে');
      expect(data().tasks.single.due, DateTime(2026, 10, 20));
    });

    testWidgets('S—"এই ফিচারটা কীভাবে চলে?" explains; nothing kept', (t) async {
      await begin(t, tasks: false);
      final before = jsonEncode(rig.brain.data.toJson());
      await say('কাজের তালিকা ফিচারটা কীভাবে চলে?');
      expect(jsonEncode(rig.brain.data.toJson()), before);
    });
  });
}
