// The 18 Oct (2.21.0-b28) review: one money policy for rules and AI, an
// unsettled hour that never reaches the scheduler, context that lapses, and
// week/month plans that are never turned into a made-up exact day.
//
// Written-input tests (test clock: Friday 9 Oct 2026, 15:53; weeks start on
// Saturday). No microphone, no live AI: the AI's side is a fixed answer in
// the tool schema's shape. "No write" is checked on the saved data itself.
import 'dart:convert';

import 'package:digital_brain/logic/ai_map.dart';
import 'package:digital_brain/logic/answers.dart';
import 'package:digital_brain/logic/day_plan.dart';
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/logic/when.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/ai.dart' show systemRules;
import 'package:digital_brain/state/brain.dart' show BrainMore;
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, start;
import 'todo_spec_test.dart' show seed;

final now = DateTime(2026, 10, 9, 15, 53);
Command one(String s) => Parser(ledger: const [], now: now).parse(s);

/// Nothing at all was written: no money, no to-do, no reminder.
void expectNoWrite(Rig rig) {
  final d = rig.brain.data;
  expect(d.ledger, isEmpty, reason: 'ledger');
  expect(d.cash, isEmpty, reason: 'cash');
  expect(d.reminders, isEmpty, reason: 'reminders');
  expect(rig.notifier.scheduled.where((n) => n.reminderId.isNotEmpty), isEmpty, reason: 'scheduler');
}

late ChatController chat;

void main() {
  late Rig rig;
  Future<List<String>> talk(WidgetTester t, List<String> turns, {bool seeded = false, Map<String, Object?>? ai}) async {
    rig = await start(t, ai: ai);
    if (seeded) rig.brain.data.tasks.addAll(seed());
    chat = ChatController(rig.brain);
    final out = <String>[];
    for (final s in turns) {
      out.add(await say(s));
    }
    return out;
  }

  group('1. money: from the verb\'s time and intent, the same for rules and AI', () {
    test('rules: done, plan, reminder, negative, what-if, a balance as it stands', () {
      expect(one('সজীবকে পাঁচশ টাকা ফেরত দিয়েছি'), isA<LedgerAdd>());
      expect(one('সজীবকে রবিবার পাঁচশ টাকা ফেরত দেব'), isA<TaskAdd>());
      final r = one('সজীবকে টাকা ফেরত দিতে মনে করিও');
      expect((r as ReminderAdd).needsTime, isTrue, reason: 'no time said: asked');
      expect(one('সজীবকে টাকা দিইনি'), isNot(isA<LedgerAdd>()));
      expect(one('সজীবকে টাকা দিলে কত থাকবে?'), isNot(anyOf(isA<LedgerAdd>(), isA<LedgerSet>(), isA<TaskAdd>())));
      final b = one('সজীবের কাছে পাঁচশ টাকা পাই');
      expect(b, isA<LedgerSet>(), reason: 'a balance stated — never a to-do');
      expect(aspectOf('কাল টাকা দিয়েছিলাম'), Aspect.done);
      expect(aspectOf('কাল টাকা দেব'), Aspect.future);
    });

    test('AI: a wrong money proposal is held by the same check', () {
      List<Command> ai(String said, Map<String, Object?> item) => commandsFromAi(said, {'reply': 'জি', 'items': [item]}, const [], now: now);
      final lent = {'action': 'ledger_add', 'person': 'সজীব', 'amount': 500, 'kind': 'lent'};
      expect(ai('সজীবকে রবিবার পাঁচশ টাকা ধার দেব', lent).single, isA<TaskAdd>());
      expect(ai('সজীবকে পাঁচশ টাকা দিইনি', lent).single, isA<SmallTalk>());
      // A what-if: what is kept is shown, nothing written.
      final q = ai('সজীবকে পাঁচশ টাকা দিলে কত থাকবে?', lent).single;
      expect(q, isA<LedgerQuery>());
      expect((q as LedgerQuery).ask, LedgerAsk.person);
      expect(ai('বেতন পেলে সজীবকে পাঁচশ টাকা দেব', lent).single, isA<TaskAdd>());
      // What did happen still goes to the book.
      expect(ai('সজীবকে পাঁচশ টাকা ধার দিয়েছি', lent).single, isA<LedgerAdd>());
    });

    test('the AI instructions hold one money policy — the old "never task_add" rule is gone', () {
      final s = systemRules();
      expect(s, isNot(contains('never note_add or task_add')));
      expect(s, contains('never from money words'));
      expect(s, contains('A balance as it stands now'));
      expect(s, isNot(contains('almost always completes')));
    });

    testWidgets('a future payment is a to-do; the book is untouched', (t) async {
      await talk(t, ['সজীবকে রবিবার পাঁচশ টাকা ফেরত দেব']);
      expect(rig.brain.data.tasks, hasLength(1));
      expect(rig.brain.data.ledger, isEmpty);
    });

    testWidgets('negative and what-if: nothing written', (t) async {
      await talk(t, ['সজীবকে টাকা দিইনি', 'সজীবকে পাঁচশ টাকা দিলে কত থাকবে?']);
      expect(rig.brain.data.tasks, isEmpty);
      expectNoWrite(rig);
    });

    testWidgets('a to-do about a bill ticked: no money entry made', (t) async {
      await talk(t, ['বিদ্যুৎ বিল দিতে হবে', 'বিল দেওয়ার কাজটা শেষ']);
      expect(rig.brain.data.tasks.single.done, isTrue);
      expect(rig.brain.data.cash, isEmpty);
    });
  });

  group('2. an unsettled hour is typed as open and never scheduled', () {
    test('per mention: "ভোর ৪টায় … আর ৫টায় …" — 4 is clear, 5 is open', () {
      const s = 'ভোর ৪টায় ওষুধ আর ৫টায় নামাজ মনে করিও';
      expect(hourOpen(s, 4), isFalse);
      expect(hourOpen(s, 5), isTrue);
      expect(hourOpen('বিকেল চারটায় মনে করিও', 16), isFalse);
      expect(hourOpen('চারটায় মনে করিও', 4), isTrue);
      expect(hourOpen('১৬:০০ টায় মনে করিও', 16), isFalse);
      expect(hourState('দুই ঘণ্টা পরে মনে করিও', 18), isNull);
    });

    test('the reminder command carries it: open vs settled are not the same value', () {
      final open = one('চারটায় ওষুধ খেতে মনে করিও') as ReminderAdd;
      final clear = one('ভোর চারটায় ওষুধ খেতে মনে করিও') as ReminderAdd;
      expect(open.ampmOpen, isTrue);
      expect(clear.ampmOpen, isFalse);
      expect(clear.at.hour, 4);
      expect((one('বিকেল চারটায় ওষুধ খেতে মনে করিও') as ReminderAdd).at.hour, 16);
    });

    test('AI: open from the words, or from time_clear when the words do not show the hour; a day without an hour is asked, never 9:00', () {
      List<Command> ai(String said, List<Map<String, Object?>> items) => commandsFromAi(said, {'reply': '', 'items': items}, const [], now: now);
      final two = ai('ভোর ৪টায় ওষুধ আর ৫টায় নামাজ মনে করিও', [
        {'action': 'reminder_add', 'text': 'ওষুধ', 'time': '04:00'},
        {'action': 'reminder_add', 'text': 'নামাজ', 'time': '05:00'},
      ]).cast<ReminderAdd>();
      expect([for (final r in two) r.ampmOpen], [false, true]);
      final hidden = ai('ওটা', [
        {'action': 'reminder_add', 'text': 'ওষুধ', 'time': '04:00', 'time_clear': false},
      ]).single as ReminderAdd;
      expect(hidden.ampmOpen, isTrue);
      final dayOnly = ai('কাল ওষুধের কথা মনে করিও', [
        {'action': 'reminder_add', 'text': 'ওষুধ', 'date': '2026-10-10'},
      ]).single as ReminderAdd;
      expect(dayOnly.needsTime, isTrue);
      expect(dayOnly.day, DateTime(2026, 10, 10));
      // A clear time already gone today, no day said: tomorrow — never +12 hours.
      final passed = ai('সকাল ৮টায় হাঁটতে মনে করিও', [
        {'action': 'reminder_add', 'text': 'হাঁটা', 'time': '08:00', 'time_clear': true},
      ]).single as ReminderAdd;
      expect(passed.at, DateTime(2026, 10, 10, 8));
    });

    testWidgets('bare hour: asked; nothing saved or scheduled until it is answered', (t) async {
      final r = await talk(t, ['চারটায় ওষুধ খাওয়া মনে করিও']);
      expect(r.single, 'ভোর ৪টা, নাকি বিকেল ৪টা?');
      expectNoWrite(rig);
    });

    testWidgets('"ভোর চারটায়" and "বিকেল চারটায়" are set at once, with no question', (t) async {
      final r = await talk(t, ['কাল ভোর চারটায় সেহরি মনে করিও', 'কাল বিকেল চারটায় মিটিং মনে করিও']);
      expect(r.join(' '), isNot(contains('নাকি')));
      expect([for (final x in rig.brain.data.reminders) x.hour], [4, 16]);
    });

    testWidgets('"না, চারটায় নয়, পাঁচটায়" while asked: the same pending reminder, asked again for 5', (t) async {
      final r = await talk(t, ['চারটায় ওষুধ খাওয়া মনে করিও', 'না, চারটায় নয়, পাঁচটায়', 'বিকেল']);
      expect(r[1], 'ভোর ৫টা, নাকি বিকেল ৫টা?');
      final rem = rig.brain.data.reminders.single;
      expect((rem.title, rem.hour), ('ওষুধ খাওয়া', 17));
    });

    testWidgets('"না, চারটায় নয়, পাঁচটায়" after "বিকেল চারটায়" was set: the same one, still in the afternoon', (t) async {
      await talk(t, ['কাল বিকেল চারটায় ওষুধ খাওয়া মনে করিও', 'না, চারটায় নয়, পাঁচটায়']);
      final rem = rig.brain.data.reminders.single;
      expect((rem.date, rem.hour), (DateTime(2026, 10, 10), 17));
    });

    testWidgets('several at once ("সব রাখো") never skips the morning/evening question', (t) async {
      await talk(t, ['এটা আর ওটা'],
          ai: {
            'reply': 'জি',
            'items': [
              {'action': 'note_add', 'text': 'গেটের কোড ৪৫৬৭'},
              {'action': 'reminder_add', 'text': 'ওষুধ', 'date': '2026-10-10', 'time': '04:00', 'time_clear': false},
            ],
          });
      for (var i = 0; i < 4 && chat.wait != ChatWait.none; i++) {
        if (chat.messages.last.text.contains('নাকি')) break;
        await say('হ্যাঁ');
      }
      expect(rig.brain.data.reminders, isEmpty, reason: 'still asked, not set at 04:00');
      expect(chat.messages.last.text, contains('ভোর ৪টা, নাকি বিকেল ৪টা?'));
    });

    testWidgets('a saved reminder\'s exact time loads back the same', (t) async {
      await talk(t, ['কাল ভোর চারটায় সেহরি মনে করিও']);
      final back = Reminder.fromJson(jsonDecode(jsonEncode(rig.brain.data.reminders.single.toJson())) as Map<String, Object?>);
      expect((back.hour, back.minute), (4, 0));
    });
  });

  group('3. follow-ups: only to what is still open', () {
    testWidgets('an unanswered question lapses: "কাল" two hours later is not its answer', (t) async {
      final r = await talk(t, ['ওষুধ খাওয়ার রিমাইন্ডার দিও']);
      expect(r.single, contains('কখন মনে করাব'));
      rig.nowAt = rig.nowAt.add(const Duration(hours: 2));
      await say('কাল সকাল নয়টায়');
      expect(rig.brain.data.reminders.where((x) => x.title.contains('ওষুধ')), isEmpty);
    });

    testWidgets('"হ্যাঁ" to a lapsed question writes nothing', (t) async {
      final r = await talk(t, ['বাজারে ৫০০ টাকা খরচ হলো']);
      expect(r.single, contains('লিখি'));
      rig.nowAt = rig.nowAt.add(const Duration(hours: 1));
      await say('হ্যাঁ');
      expect(rig.brain.data.cash, isEmpty);
    });

    testWidgets('"কাল রাখো" with nothing talked about: which one is asked', (t) async {
      final r = await talk(t, ['কাল রাখো'], seeded: true);
      expect(r.single, contains('কোন কাজটি'));
      expect(rig.brain.data.tasks.where((x) => x.due == DateTime(2026, 10, 10)), hasLength(seed().where((x) => x.due == DateTime(2026, 10, 10)).length));
    });

    testWidgets('"দ্বিতীয়টা" is the second of the list as shown, even after one was removed', (t) async {
      await talk(t, ['আজকের কাজগুলো বলো'], seeded: true);
      final shown = [...chat.debugShownTasks];
      expect(shown.length, greaterThan(2));
      rig.brain.data.tasks.removeWhere((x) => x.id == shown.first);
      await say('দ্বিতীয়টা শেষ');
      expect(rig.brain.data.tasks.firstWhere((x) => x.id == shown[1]).done, isTrue);
      expect(rig.brain.data.tasks.where((x) => x.done), hasLength(1));
    });

    testWidgets('"দ্বিতীয়টা" long after the list: asked, nothing ticked', (t) async {
      await talk(t, ['আজকের কাজগুলো বলো'], seeded: true);
      rig.nowAt = rig.nowAt.add(const Duration(minutes: 45));
      final r = await say('দ্বিতীয়টা শেষ');
      expect(r, contains('কোন কাজ'));
      expect(rig.brain.data.tasks.where((x) => x.done), isEmpty);
    });

    testWidgets('"মুছো না" stops a removal that was waiting', (t) async {
      await talk(t, ['বাজার করার কাজটা মুছে দাও'], seeded: true);
      final n = rig.brain.data.tasks.length;
      await say('মুছো না');
      expect(rig.brain.data.tasks, hasLength(n));
    });

    testWidgets('the same words twice at once (a repeated callback): one to-do', (t) async {
      await talk(t, ['কাল ব্যাংকে যেতে হবে', 'কাল ব্যাংকে যেতে হবে']);
      expect(rig.brain.data.tasks, hasLength(1));
    });
  });

  group('4. week/month plans keep their span everywhere', () {
    testWidgets('"আগামী সপ্তাহে ওয়েবসাইট পরীক্ষা করব": the week, no day, no alarm', (t) async {
      final r = await talk(t, ['আগামী সপ্তাহে ওয়েবসাইট পরীক্ষা করব']);
      final x = rig.brain.data.tasks.single;
      expect((x.span, x.due, x.deadline), (TaskSpan.week, DateTime(2026, 10, 10), null));
      expect(r.single, isNot(contains('শনিবার')));
      expect(taskLine(x, now), contains('আগামী সপ্তাহের যেকোনো দিন'));
      expect(rig.brain.data.reminders, isEmpty);
      // It is on every day of that week when asked — said as the week.
      expect(planItemsOn(rig.brain.data, DateTime(2026, 10, 14), now).map((i) => i.task?.id), contains(x.id));
      expect(planItemsOn(rig.brain.data, DateTime(2026, 10, 17), now).map((i) => i.task?.id), isNot(contains(x.id)));
    });

    testWidgets('"আগামী সপ্তাহের বুধবার করব" is that exact day', (t) async {
      await talk(t, ['আগামী সপ্তাহের বুধবার ওয়েবসাইট পরীক্ষা করব']);
      final x = rig.brain.data.tasks.single;
      expect((x.span, x.due), (TaskSpan.day, DateTime(2026, 10, 14)));
    });

    testWidgets('"ডিসেম্বরে পাসপোর্ট নবায়ন করব": the month; after it, to look at again — never "late" on 1 Dec', (t) async {
      await talk(t, ['ডিসেম্বরে পাসপোর্ট নবায়ন করব']);
      final x = rig.brain.data.tasks.single;
      expect((x.span, x.due), (TaskSpan.month, DateTime(2026, 12, 1)));
      expect(x.lateAt(DateTime(2026, 12, 2)), isFalse);
      expect(x.lateAt(DateTime(2027, 1, 2)), isFalse);
      expect(x.windowPassed(DateTime(2027, 1, 2)), isTrue);
      expect(taskLine(x, DateTime(2027, 1, 2)), allOf(contains('পরিকল্পনা'), isNot(contains('দেরি'))));
    });

    testWidgets('"৫ ডিসেম্বরের মধ্যে নবায়ন শেষ করতে হবে": a deadline; late only after it', (t) async {
      await talk(t, ['৫ ডিসেম্বরের মধ্যে পাসপোর্ট নবায়ন শেষ করতে হবে']);
      final x = rig.brain.data.tasks.single;
      expect(x.deadline ?? x.due, DateTime(2026, 12, 5));
      expect(x.lateAt(DateTime(2026, 12, 5)), isFalse);
      expect(x.lateAt(DateTime(2026, 12, 6)), isTrue);
    });

    testWidgets('a reminder for a coming week\'s plan asks which day — never its first day', (t) async {
      final r = await talk(t, ['আগামী সপ্তাহে ওয়েবসাইট পরীক্ষা করব', 'ওটার রিমাইন্ডার সকাল দশটায় দিও']);
      expect(r[1], contains('কোন দিন'));
      expect(rig.brain.data.reminders, isEmpty);
      await say('বুধবার সকাল দশটায়');
      final rem = rig.brain.data.reminders.single;
      expect((rem.date, rem.hour), (DateTime(2026, 10, 14), 10));
      expect(rig.brain.data.tasks.single.span, TaskSpan.week, reason: 'the plan keeps its span');
    });

    test('opening the app never rewrites a plan\'s date or span; a form saved unchanged keeps the span', () async {
      final rig = Rig();
      await rig.brain.load();
      rig.brain.data.tasks.addAll([
        Task(id: 'w', title: 'ওয়েবসাইট পরীক্ষা', due: DateTime(2026, 10, 3), span: TaskSpan.week),
        Task(id: 'd', title: 'ব্যাংক', due: DateTime(2026, 10, 5)),
      ]);
      await rig.brain.carryOverTasks();
      final w = rig.brain.data.tasks.firstWhere((x) => x.id == 'w');
      final d = rig.brain.data.tasks.firstWhere((x) => x.id == 'd');
      expect((w.due, w.span), (DateTime(2026, 10, 3), TaskSpan.week));
      expect(d.due, DateTime(2026, 10, 5), reason: 'late, shown on today\'s list — its own day kept');
      expect(w.copyWith(title: 'নতুন নাম', due: w.due).span, TaskSpan.week);
      expect(w.copyWith(due: DateTime(2026, 10, 7)).span, TaskSpan.day, reason: 'a new day picked is a day');
      expect(planOf(rig.brain.data, now).overdue.map((i) => i.task!.id), ['d']);
    });

    test('backup restore keeps span, deadline and repeat', () {
      final data = AppData()
        ..tasks.addAll([
          Task(title: 'ক', due: DateTime(2026, 12, 1), span: TaskSpan.month, deadline: DateTime(2026, 12, 5)),
          Task(title: 'খ', due: DateTime(2026, 10, 10), span: TaskSpan.week),
          Task(title: 'গ', due: DateTime(2026, 10, 16), repeat: const TaskRepeat.weekly([DateTime.friday])),
        ]);
      final back = AppData.fromJson(jsonDecode(jsonEncode(data.toJson())) as Map<String, Object?>);
      expect([for (final t in back.tasks) (t.span, t.deadline, t.repeat)], [for (final t in data.tasks) (t.span, t.deadline, t.repeat)]);
    });

    test('AI: a week plan\'s date is kept as the week\'s first day whatever day it wrote', () {
      final c = commandsFromAi('আগামী সপ্তাহে ওয়েবসাইট পরীক্ষা করব', {
        'reply': '',
        'items': [
          {'action': 'task_add', 'text': 'ওয়েবসাইট পরীক্ষা', 'date': '2026-10-12', 'span': 'week'},
        ],
      }, const [], now: now).single as TaskAdd;
      expect((c.due, c.span), (DateTime(2026, 10, 10), TaskSpan.week));
      expect(weekStartOf(DateTime(2026, 10, 16)), DateTime(2026, 10, 10));
    });
  });
}

Future<String> say(String s) async {
  final n = chat.messages.length;
  await chat.hear(s);
  return chat.messages.skip(n).where((m) => !m.fromUser).map((m) => m.text).join(' ');
}
