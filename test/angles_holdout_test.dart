// Angles held out: 35 scenarios written before the fixes and run only after them.
//
// The same intents from many angles (19 Oct, 20:33 screenshots): by name,
// by number in the list just shown, by date, by year or month, narrowed
// while a question waits, "হ্যাঁ দাও" to a suggested time, complaints in
// between. Each scenario is checked by the data it leaves — never by the
// words of the reply.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;

const scenarios = <(List<String>, String, String)>[
  (['যশোর যাওয়া কাজটার নাম শ্বশুর বাড়ি যাওয়া হবে'], 'rename', 'T3|শ্বশুর বাড়ি যাওয়া'),
  (['বাজার করা না লিখে মাসিক বাজার লেখো'], 'rename', 'T7|মাসিক বাজার'),
  (['নোয়াখালী যাওয়া কাজটা এডিট করে গ্রামের বাড়ি যাওয়া করো'], 'rename', 'T2|গ্রামের বাড়ি যাওয়া'),
  (['আমার কাজের তালিকা দাও', '২ নম্বর কাজের নাম ঠিক করো: রবিনের বোনের বিয়ে'], 'rename', 'T1|রবিনের বোনের বিয়ে'),
  (['আমার কাজের তালিকা দাও', 'পাঁচ নম্বরটার নাম স্বাধীনতা দিবস রাখো'], 'rename', 'T4|স্বাধীনতা দিবস'),
  (['আমার কাজের তালিকা দাও', 'ছয় নম্বর কাজটা মুছে ফেলো'], 'deltasks', 'T5'),
  (['আমার কাজের তালিকা দাও', 'দ্বিতীয় কাজটা শেষ করেছি'], 'done', 'T1'),
  (['আমার কাজের তালিকা দাও', '৪ নম্বর কাজটা ২৮ অক্টোবরে সরাও'], 'move', 'T3|2026-10-28'),
  (['তুবার জন্মদিনের রিমাইন্ডারটা রাত ৮টায় দাও'], 'remtime', 'R1|20'),
  (['৩১ অক্টোবরের রিমাইন্ডার সন্ধ্যা ৭টায় হবে'], 'remtime', 'R1|19'),
  (['জিলাপির রিমাইন্ডার দুপুর ২টায় সরিয়ে দাও'], 'remtime', 'R5|14'),
  (['ডাক্তারের রিমাইন্ডার ৫টার বদলে ৬টায় দাও'], 'remtime', 'R7|18'),
  (['মোস্তাফার জন্মদিনের রিমাইন্ডারের সময় বদলাবো', 'সকাল ৭টায়'], 'remtime', 'R2|7'),
  (['হিরার জন্মদিনের রিমাইন্ডার টাইমটা চেঞ্জ করো', 'রাত ১০টায়'], 'remtime', 'R3|22'),
  (['২০২৭ এর রিমাইন্ডারগুলো মুছে দাও'], 'delrems', 'R4,R5'),
  (['২০২৭ সালে যতগুলো রিমাইন্ডার আছে সেগুলো ডিলিট করো'], 'delrems', 'R4,R5'),
  (['নভেম্বর মাসের রিমাইন্ডার সব বাদ দিয়ে দাও'], 'delrems', 'R2,R3,R7'),
  (['আমার সব রিমাইন্ডার দাও', 'এর মধ্যে ২০২৭ সালেরগুলো মুছে দাও'], 'delrems', 'R4,R5'),
  (['আমার সব রিমাইন্ডার দাও', 'শুধু নভেম্বরেরগুলো বাদ দাও'], 'delrems', 'R2,R3,R7'),
  (['সব রিমাইন্ডার বাদ দাও', 'না, কেবল ২০২৭ সালের'], 'delrems', 'R4,R5'),
  (['সব রিমাইন্ডার বাদ দাও', 'শুধুমাত্র ২০৩১ এর টা'], 'delrems', 'R6'),
  (['২০২৯ সালের সব কাজ ডিলিট'], 'deltasks', 'T2,T3,T4,T5,T6'),
  (['এ মাসের কাজগুলো মুছে দাও'], 'deltasks', 'T1,T7'),
  (['সব কাজ মুছে দাও', 'শুধু ২০২৯ এর গুলো'], 'deltasks', 'T2,T3,T4,T5,T6'),
  (['যশোর যাওয়া কাজে রিমাইন্ডার দাও', 'হুম দাও'], 'remtask', 'T3|9'),
  (['নোয়াখালী যাওয়ার রিমাইন্ডার চাই', 'হ্যাঁ ঠিক আছে'], 'remtask', 'T2|9'),
  (['যশোর যাওয়ার তারিখ ২৮ অক্টোবর করে দাও'], 'move', 'T3|2026-10-28'),
  (['বাজার করা কাজটা ২৮ তারিখে করব'], 'move', 'T7|2026-10-28'),
  (['রবিনের বোনের বিয়ের দাওয়াত কাজটা বাদ'], 'deltasks', 'T1'),
  (['মসজিদে জিলাপি দেওয়ার রিমাইন্ডার আর দরকার নেই'], 'remoff', 'R5'),
  (['পাসপোর্টের রিমাইন্ডারটা ফেলে দাও'], 'delrems', 'R6'),
  (['এইটা ভুল দেখাইছো'], 'none', ''),
  (['আমি এটা চাইনি'], 'none', ''),
  (['তুমি বুঝতে পারোনি'], 'none', ''),
  (['আমার সব রিমাইন্ডার দাও', 'এগুলো ঠিক না'], 'none', ''),
];

AppData fixture() => AppData(
      tasks: [
        Task(id: 'T1', title: 'রবিনের বোনের বিয়েতে দাওয়াত', due: DateTime(2026, 10, 24), createdAt: DateTime(2026, 10, 1)),
        Task(id: 'T2', title: 'নোয়াখালী যাওয়া', due: DateTime(2029, 1, 5), createdAt: DateTime(2026, 10, 2)),
        Task(id: 'T3', title: 'যশোর যাওয়া', due: DateTime(2029, 2, 15), createdAt: DateTime(2026, 10, 3)),
        Task(id: 'T4', title: 'স্বাধীনতা দিবসে যাওয়া', due: DateTime(2029, 3, 25), createdAt: DateTime(2026, 10, 4)),
        Task(id: 'T5', title: 'পহেলা বৈশাখের অনুষ্ঠানে যাওয়া', due: DateTime(2029, 4, 14), createdAt: DateTime(2026, 10, 5)),
        Task(id: 'T6', title: 'দিবস পালন করা', due: DateTime(2029, 5, 1), createdAt: DateTime(2026, 10, 6)),
        Task(id: 'T7', title: 'বাজার করা', due: DateTime(2026, 10, 20), createdAt: DateTime(2026, 10, 7)),
      ],
      reminders: [
        Reminder(id: 'R1', title: 'তুবার জন্মদিন', date: DateTime(2026, 10, 31), hour: 9, repeat: Repeat.yearly),
        Reminder(id: 'R2', title: 'মোস্তাফার জন্মদিন', date: DateTime(2026, 11, 4), hour: 9, repeat: Repeat.yearly),
        Reminder(id: 'R3', title: 'হিরার জন্মদিন', date: DateTime(2026, 11, 7), hour: 9, repeat: Repeat.yearly),
        Reminder(id: 'R4', title: 'আমার বিবাহবার্ষিকী', date: DateTime(2027, 2, 15), hour: 9),
        Reminder(id: 'R5', title: 'মসজিদে জিলাপি দেওয়া', date: DateTime(2027, 6, 11), hour: 11),
        Reminder(id: 'R6', title: 'সাইফুলের পাসপোর্ট মেয়াদ শেষ', date: DateTime(2031, 8, 25), hour: 10),
        Reminder(id: 'R7', title: 'ডাক্তার দেখানো', date: DateTime(2026, 11, 15), hour: 17),
      ],
    );

String state(AppData d) => [
      for (final x in d.tasks) '${x.id}|${x.title}|${x.due}|${x.done}|${x.reminderId}',
      for (final r in d.reminders) 'R:${r.id}|${r.title}|${r.date}|${r.hour}|${r.enabled}',
      'n${d.notes.length} c${d.cash.length} l${d.ledger.length} s${d.specialDays.length}',
    ].join('\n');

void main() {
  for (final (i, s) in scenarios.indexed) {
    final (turns, check, arg) = s;
    testWidgets('${(i + 1).toString().padLeft(3, '0')} [$check] ${turns.join(' → ')}', (t) async {
      final rig = await start(t);
      rig.nowAt = DateTime(2026, 10, 19, 20, 30);
      rig.brain.data = fixture();
      final chat = ChatController(rig.brain);
      final before = state(rig.brain.data);
      final replies = <String>[];
      for (final x in turns) {
        final n0 = chat.messages.length;
        await chat.hear(x);
        replies.add(chat.messages.skip(n0).where((m) => !m.fromUser).map((m) => [m.text, ...m.facts].join(' ')).join(' '));
      }
      // A plain yes to "…দেবো?" — the one confirmation a change may ask.
      for (var k = 0; k < 2 && check != 'none' && (chat.wait == ChatWait.yesNo || chat.wait == ChatWait.bulk); k++) {
        final n0 = chat.messages.length;
        await chat.hear('হ্যাঁ');
        replies.add(chat.messages.skip(n0).where((m) => !m.fromUser).map((m) => m.text).join(' '));
      }
      final d = rig.brain.data;
      final why = 'replies: ${replies.join(' ‖ ')}';
      Task? task(String id) => d.tasks.where((x) => x.id == id).firstOrNull;
      Reminder? rem(String id) => d.reminders.where((x) => x.id == id).firstOrNull;
      final parts = arg.split('|');
      switch (check) {
        case 'none':
          expect(state(d), before, reason: why);
          expect(replies.last, isNot(contains('এই নামে')), reason: why);
          expect(chat.wait == ChatWait.collect, isFalse, reason: why);
        case 'rename':
          expect(task(parts[0])?.title, parts[1], reason: why);
          expect(d.tasks, hasLength(7), reason: why);
          expect(d.notes, isEmpty, reason: why);
          expect(d.reminders, hasLength(7), reason: why);
        case 'deltasks':
          final gone = parts[0].split(',').toSet();
          expect({for (final x in d.tasks) x.id}, {for (final x in ['T1', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7']) if (!gone.contains(x)) x}, reason: why);
          expect(d.reminders, hasLength(7), reason: why);
        case 'done':
          expect(task(parts[0])?.done, isTrue, reason: why);
          expect(d.tasks.where((x) => x.done), hasLength(1), reason: why);
        case 'remtask':
          final x = task(parts[0])!;
          expect(x.reminderId, isNotNull, reason: why);
          final r = rem(x.reminderId!)!;
          expect((r.hour, DateTime(r.date.year, r.date.month, r.date.day)), (int.parse(parts[1]), x.due), reason: why);
          expect(d.tasks, hasLength(7), reason: why);
        case 'remtime':
          final r = rem(parts[0]);
          final was = fixture().reminders.firstWhere((y) => y.id == parts[0]);
          expect(r?.hour, int.parse(parts[1]), reason: why);
          expect((r!.date.month, r.date.day), (was.date.month, was.date.day), reason: 'the day stays — $why');
          expect(d.reminders, hasLength(7), reason: why);
          expect([for (final y in d.reminders) if (y.id != r.id) '${y.id}${y.hour}'], [for (final y in fixture().reminders) if (y.id != r.id) '${y.id}${y.hour}'], reason: 'only that one — $why');
        case 'delrems':
          final gone = parts[0].split(',').toSet();
          expect({for (final x in d.reminders) x.id}, {for (final x in ['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7']) if (!gone.contains(x)) x}, reason: why);
          expect(d.tasks, hasLength(7), reason: why);
        case 'remoff':
          final r = rem(parts[0]);
          expect(r == null || !r.enabled, isTrue, reason: why);
          expect(d.reminders.where((y) => y.id != parts[0] && !y.enabled), isEmpty, reason: why);
          expect(d.reminders.length >= 6, isTrue, reason: why);
        case 'move':
          expect(task(parts[0])?.due, DateTime.parse(parts[1]), reason: why);
          expect(d.tasks, hasLength(7), reason: why);
      }
    });
  }
}
