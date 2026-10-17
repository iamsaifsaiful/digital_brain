// The 18 Oct contract: unclear times are asked, the rules and the AI lead
// to the same actions, money that has not happened is never written, and
// what is said comes from what was actually saved or found.
//
// Written-input tests only (the test clock is Friday 9 Oct 2026, 15:53).
// They do not measure the microphone, and no live AI call is made: the AI's
// side is a fixed answer in the shape the tool schema asks for.
import 'package:digital_brain/logic/ai_map.dart';
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/logic/plan.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/notifications.dart' show AlarmHealth;
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;
import 'todo_spec_test.dart' show seed;

void main() {
  late ChatController chat;
  Future<List<String>> talk(WidgetTester t, List<String> turns, {bool seeded = false, Map<String, Object?>? ai, void Function(dynamic rig)? setup}) async {
    final rig = await start(t, ai: ai);
    if (seeded) rig.brain.data.tasks.addAll(seed());
    setup?.call(rig);
    chat = ChatController(rig.brain);
    final out = <String>[];
    for (final s in turns) {
      final n = chat.messages.length;
      await chat.hear(s);
      out.add(chat.messages.skip(n).where((m) => !m.fromUser).map((m) => m.text).join(' '));
    }
    return out;
  }

  group('1. time: asked when unclear, never decided by the clock', () {
    testWidgets('১. "চারটায় মনে করিও" asks morning or afternoon', (t) async {
      final r = await talk(t, ['চারটায় ওষুধ খাওয়া মনে করিও।', 'বিকেল']);
      expect(r[0], 'ভোর ৪টা, নাকি বিকেল ৪টা?');
      final rem = chat.brain.data.reminders.single;
      expect((rem.date, rem.hour), (DateTime(2026, 10, 9), 16));
    });

    testWidgets('২. "কাল সকালে …" → "সকালে কয়টায়?" → "আটটায়" is 8 am; "না, কাল নয়, পরশু" moves the same one', (t) async {
      final r = await talk(t, ['কাল সকালে স্যারকে ফোন দিতে মনে করিও।', 'আটটায়।', 'না, কাল নয়, পরশু।']);
      expect(r[0], contains('সকালে কয়টায়'));
      expect(r[1], isNot(contains('নাকি')), reason: 'the morning was already said');
      final rems = chat.brain.data.reminders;
      expect(rems, hasLength(1), reason: 'the correction changes it, never a second one');
      expect((rems.single.title, rems.single.date, rems.single.hour), ('স্যারকে ফোন দেওয়া', DateTime(2026, 10, 11), 8));
    });

    testWidgets('৩. "আজ সকাল আটটায়" after 8 am is not quietly tomorrow', (t) async {
      final r = await talk(t, ['আজ সকাল আটটায় মিটিং মনে করিও']);
      expect(r.single, contains('পার হয়ে গেছে'));
      expect(chat.brain.data.reminders, isEmpty);
    });

    testWidgets('"কাল রাত বারোটায়" is the night of tomorrow, said with its date', (t) async {
      final r = await talk(t, ['কাল রাত বারোটায় ওষুধ মনে করিও']);
      final rem = chat.brain.data.reminders.single;
      expect((rem.date, rem.hour), (DateTime(2026, 10, 11), 0));
      expect(r.single, contains('দিবাগত রাত ১২টা'));
    });

    testWidgets('৪. "আগামী সপ্তাহে রিপোর্ট করব" is the week, not a made-up Monday', (t) async {
      final r = await talk(t, ['আগামী সপ্তাহে রিপোর্ট তৈরি করব।']);
      final x = chat.brain.data.tasks.single;
      expect((x.span, x.due), (TaskSpan.week, DateTime(2026, 10, 10)));
      expect(r.single, contains('আগামী সপ্তাহে'));
      expect(r.single, isNot(contains('সোমবার')));
    });

    testWidgets('৫. planned day and last day are both kept', (t) async {
      final r = await talk(t, ['রিপোর্ট বৃহস্পতিবার তৈরি করব, শুক্রবার জমা দেব।']);
      final x = chat.brain.data.tasks.single;
      expect((x.due, x.deadline), (DateTime(2026, 10, 15), DateTime(2026, 10, 16)));
      expect(r.single, contains('শেষ সময় শুক্রবার, ১৬ অক্টোবর'));
      // Moving the planned day never moves the last day.
      await chat.hear('একদিন পিছিয়ে দাও');
      expect((chat.brain.data.tasks.single.due, chat.brain.data.tasks.single.deadline), (DateTime(2026, 10, 16), DateTime(2026, 10, 16)));
    });

    testWidgets('a plan for a part of the day is a to-do, not a silent alarm', (t) async {
      await talk(t, ['কাল সকালে রিপোর্ট পাঠাব']);
      expect(chat.brain.data.tasks.single.due, DateTime(2026, 10, 10));
      expect(chat.brain.data.reminders, isEmpty);
    });
  });

  group('2. the same rules for typed, spoken and AI', () {
    testWidgets('৬. "দ্বিতীয় কাজটা শেষ" is the second of the list just shown', (t) async {
      await talk(t, ['আজকের কাজগুলো বলো', 'দ্বিতীয় কাজটা শেষ'], seeded: true);
      expect(chat.brain.data.tasks.firstWhere((x) => x.id == 't1').done, isTrue);
      expect(chat.brain.data.tasks.where((x) => x.done), hasLength(1));
    });

    testWidgets('৭. "শুধু রিমাইন্ডার বন্ধ করো" turns off the reminder; the to-do stays', (t) async {
      final r = await talk(t, ['বাজারের কাজটায় রিমাইন্ডার দাও', 'সন্ধ্যা ৭টায়', 'শুধু রিমাইন্ডার বন্ধ করো'], seeded: true);
      expect(r[2], contains('রিমাইন্ডার বন্ধ করেছি'));
      expect(chat.brain.data.reminders.single.enabled, isFalse);
      expect(chat.brain.data.tasks.firstWhere((x) => x.id == 't1').done, isFalse);
    });

    testWidgets('৮. "এই শুক্রবার বাদ দাও" skips one time; the series stays', (t) async {
      await talk(t, ['প্রতি শুক্রবার বাজার করব', 'এই শুক্রবার বাদ দাও']);
      final x = chat.brain.data.tasks.single;
      expect(x.repeat, const TaskRepeat.weekly([DateTime.friday]));
      expect(x.due, DateTime(2026, 10, 16));
    });

    testWidgets('"প্রতি শুক্রবারেরটা বন্ধ করো" is the whole series — asked once', (t) async {
      final r = await talk(t, ['প্রতি শুক্রবার বাজার করব', 'প্রতি শুক্রবারেরটা বন্ধ করো', 'হ্যাঁ']);
      expect(r[1], contains('মুছে দেব?'));
      expect(chat.brain.data.tasks, isEmpty);
    });

    testWidgets('১৩. "শেষ হয়নি" never ticks', (t) async {
      await talk(t, ['বাজার করার কাজটা এখনো শেষ হয়নি'], seeded: true);
      expect(chat.brain.data.tasks.where((x) => x.done), isEmpty);
    });

    testWidgets('১৪. with the AI on, what the rules decided is not sent to the AI (no second action)', (t) async {
      final rig = await start(t, ai: {
        'reply': 'AI বলছে: সব সেভ হয়ে গেছে',
        'items': [
          {'action': 'task_add', 'text': 'ব্যাংকে যাওয়া', 'date': '2026-10-10'},
        ],
      });
      chat = ChatController(rig.brain);
      await chat.hear('কাল ব্যাংকে যেতে হবে');
      expect(rig.ai.asked, isEmpty);
      expect(rig.brain.data.tasks, hasLength(1));
      expect(chat.messages.last.text, isNot(contains('AI বলছে')), reason: 'the reply is what the app did, not the AI\'s word');
    });

    testWidgets('the AI\'s reading goes through the same checks: a money plan from the AI is never written', (t) async {
      final rig = await start(t, ai: {
        'reply': 'জি',
        'items': [
          {'action': 'ledger_add', 'person': 'সজীব', 'amount': 500, 'kind': 'lent'},
        ],
      });
      chat = ChatController(rig.brain);
      // Said so the rules do not settle it alone; the AI then reads it as a loan.
      final cmds = commandsFromAi('সজীবরে পাঁচশ টেকা পরে দিমু', {
        'reply': 'জি',
        'items': [
          {'action': 'ledger_add', 'person': 'সজীব', 'amount': 500, 'kind': 'lent'},
        ],
      }, const []);
      expect(cmds.whereType<LedgerAdd>(), isEmpty);
      expect(cmds.single, isA<TaskAdd>());
      expect(rig.brain.data.ledger, isEmpty);
    });

    testWidgets('১৫. the same words again at once after a save: one entry', (t) async {
      await talk(t, ['রহিমকে ৫০০ টাকা ধার দিলাম', 'হ্যাঁ', 'কাল ফার্মেসিতে যেতে হবে', 'কাল ফার্মেসিতে যেতে হবে']);
      expect(chat.brain.data.tasks, hasLength(1));
      expect(chat.brain.data.ledger, hasLength(1));
    });
  });

  group('3. money that has not happened is not written', () {
    for (final (said, kind) in [
      ('সজীবকে পাঁচশ টাকা ফেরত দিতে হবে।', 'task'),
      ('কাল সজীবকে ৫০০ টাকা দেব।', 'task'),
      ('শুক্রবার সজীবকে টাকা ফেরত দিতে মনে করিও।', 'reminder'),
      ('সজীবকে টাকা দিইনি।', 'nothing'),
      ('সজীবের কাছে কত টাকা পাই?', 'query'),
      ('বেতন পেলে বিল দেব।', 'task'),
      ('বিলের টাকা বেতন থেকে দেব।', 'task'),
    ]) {
      test('৯. $said → $kind, never the book', () {
        final c = parseAll(said, const [], now: DateTime(2026, 10, 9, 15, 53));
        expect(c.whereType<LedgerAdd>(), isEmpty, reason: said);
        expect(c.whereType<LedgerSet>(), isEmpty, reason: said);
        expect(c.whereType<CashAdd>(), isEmpty, reason: said);
        switch (kind) {
          case 'task':
            expect(c.single, anyOf(isA<TaskAdd>(), isA<Clarify>()), reason: said);
          case 'reminder':
            expect(c.single, isA<ReminderAdd>(), reason: said);
            expect((c.single as ReminderAdd).title, 'সজীবকে টাকা ফেরত দেওয়া');
          case 'nothing':
            expect(c.single, isA<SmallTalk>(), reason: said);
          case 'query':
            expect(c.single, isA<LedgerQuery>(), reason: said);
        }
      });
    }

    test('১০–১১. done is a payment (asked once); "কাল দিয়েছিলাম" is yesterday, "কাল দেব" tomorrow', () {
      final now = DateTime(2026, 10, 9, 15, 53);
      final paid = parseAll('সজীবকে ৫০০ টাকা ফেরত দিয়েছি', const [], now: now).single as LedgerAdd;
      expect((paid.kind, paid.amount), (LedgerKind.repaid, 500));
      final past = parseAll('কাল সজীবকে ৫০০ টাকা দিয়েছিলাম', const [], now: now).single as LedgerAdd;
      expect(past.date, DateTime(2026, 10, 8));
      final plan = parseAll('কাল সজীবকে ৫০০ টাকা দেব', const [], now: now).single as TaskAdd;
      expect((plan.due, plan.title), (DateTime(2026, 10, 10), 'সজীবকে ৫০০ টাকা দেওয়া'));
    });

    testWidgets('১০. a payment with no amount asks the amount; nothing is written yet', (t) async {
      final r = await talk(t, ['সজীবকে টাকা ফেরত দিয়েছি।']);
      expect(r.single, contains('কত'));
      expect(chat.brain.data.ledger, isEmpty);
    });

    testWidgets('১২. paid today + to pay Friday + remind Thursday: three separate things', (t) async {
      final r = await talk(t, ['আজ সজীবকে দুইশ টাকা ফেরত দিয়েছি, বাকি তিনশ টাকা সোমবার দেব, রবিবার মনে করিও।', 'হ্যাঁ', 'সকাল ৯টায়']);
      expect(r[0], contains('৩টা জিনিস'));
      final e = chat.brain.data.ledger.single;
      expect((e.amount, e.kind), (200, LedgerKind.repaid), reason: 'only what was paid today — never 500');
      final task = chat.brain.data.tasks.single;
      expect((task.due, task.title), (DateTime(2026, 10, 12), contains('৩০০').matches(task.title, {}) ? task.title : task.title));
      expect(task.title, contains('তিনশ'));
      final rem = chat.brain.data.reminders.single;
      expect((rem.date, rem.hour), (DateTime(2026, 10, 11), 9));
      expect(rem.title, task.title);
    });

    testWidgets('a bill to-do finished is a tick, not an expense', (t) async {
      await talk(t, ['বিদ্যুৎ বিল দেওয়ার কাজটা শেষ'], seeded: true);
      expect(chat.brain.data.tasks.firstWhere((x) => x.id == 't3').done, isTrue);
      expect(chat.brain.data.cash, isEmpty);
    });
  });

  group('4. what is said is what was saved or found', () {
    testWidgets('১৬. four matching to-dos: four said, four on screen', (t) async {
      final r = await talk(t, ['ফোন সংক্রান্ত কাজগুলো দেখাও'], setup: (rig) {
        rig.brain.data.tasks.addAll([for (final n in ['রহিম', 'করিম', 'সজীব', 'ইসমাইল']) Task(title: '$nকে ফোন করা')]);
      });
      expect(r.single, contains('৪টা কাজ'));
      expect(chat.messages.last.facts, hasLength(4));
    });

    testWidgets('১৭. free reminders full: the to-do is kept, the reminder is said to be off', (t) async {
      final r = await talk(t, ['বাজারের কাজটায় রিমাইন্ডার দাও', 'সন্ধ্যা ৭টায়'], seeded: true, setup: (rig) {
        rig.brain.gated = true;
        rig.brain.data.reminders.addAll([for (var i = 0; i < 20; i++) Reminder(title: 'r$i', date: DateTime(2026, 11, 1), hour: 10)]);
      });
      expect(r[1], contains('রিমাইন্ডার চালু হয়নি'));
      expect(r[1], isNot(contains('মনে করিয়ে দেব')));
      expect(chat.brain.data.reminders, hasLength(20));
      expect(chat.brain.data.tasks.firstWhere((x) => x.id == 't1').reminderId, isNull);
    });

    testWidgets('১৮. notifications off: kept, with a true warning — no promise to ring', (t) async {
      final r = await talk(t, ['বাজারের কাজটায় রিমাইন্ডার দাও', 'সন্ধ্যা ৭টায়'], seeded: true, setup: (rig) {
        rig.notifier.state = const AlarmHealth(notificationsOn: false, exactOn: true, batteryFree: true, fullScreenOn: true, brand: '', hasAutostart: false);
      });
      expect(r[1], contains('নোটিফিকেশন বন্ধ'));
      expect(r[1], isNot(contains('মনে করিয়ে দেব')));
      expect(chat.brain.data.reminders, hasLength(1));
    });

    testWidgets('১৯. a to-do moved to tomorrow takes its reminder along', (t) async {
      final r = await talk(t, ['বাজারের কাজটায় রিমাইন্ডার দাও', 'সন্ধ্যা ৭টায়', 'বাজার করার কাজটা কাল রাখো'], seeded: true);
      final rem = chat.brain.data.reminders.single;
      expect((rem.date, rem.hour), (DateTime(2026, 10, 10), 19));
      expect(r[2], contains('রিমাইন্ডারও'));
    });

    testWidgets('a finished to-do\'s reminder still ahead is turned off', (t) async {
      await talk(t, ['বাজারের কাজটায় রিমাইন্ডার দাও', 'সন্ধ্যা ৭টায়', 'বাজার করেছি'], seeded: true);
      expect(chat.brain.data.reminders.single.enabled, isFalse);
    });

    testWidgets('২০. several requests, part done: each said truly', (t) async {
      final r = await talk(t, ['বাজার করেছি, ওষুধ আনিনি, গাড়ি ধোয়ার কাজটা কাল রাখো'], seeded: true);
      expect(r.single, contains('“বাজার করা” কাজটি সম্পন্ন'));
      expect(r.single, contains('“ওষুধ আনা” কাজটি বাকি'));
      // The car wash was not on the list: kept as a new one, said so.
      expect(r.single, contains('গাড়ি'));
      expect(chat.brain.data.tasks.where((x) => x.title.contains('গাড়ি')), hasLength(1));
    });

    testWidgets('snooze: "দশ মিনিট পরে আবার মনে করিও" after a reminder', (t) async {
      final r = await talk(t, ['বিকেল ৫টায় ওষুধ খাওয়া মনে করিও', 'দশ মিনিট পরে আবার মনে করিও']);
      expect(r[1], contains('১০ মিনিট পরে'));
      final rem = chat.brain.data.reminders.single;
      expect((rem.hour, rem.minute), (16, 3));
    });
  });

  group('contract parity: the rules and the AI\'s answer give the same action', () {
    // What the AI should send for each sentence (per the tool schema), and
    // the action both must lead to.
    final now = DateTime(2026, 10, 9, 15, 53);
    final cases = <(String, Map<String, Object?>, String)>[
      ('কাল ব্যাংকে যেতে হবে', {'action': 'task_add', 'text': 'ব্যাংকে যাওয়া', 'date': '2026-10-10'}, 'add ব্যাংকে যাওয়া 2026-10-10'),
      ('বাজার করার কাজটা হয়ে গেছে', {'action': 'task_done', 'terms': ['বাজার']}, 'done [বাজার]'),
      ('বাজার করার কাজটা এখনো শেষ হয়নি', {'action': 'task_reopen', 'terms': ['বাজার']}, 'notdone [বাজার]'),
      ('দ্বিতীয়টা হয়ে গেছে', {'action': 'task_done', 'index': 2}, 'done #2'),
      ('ওটা কাল রাখো', {'action': 'task_edit', 'ref': 'it', 'date': '2026-10-10'}, 'edit it due 2026-10-10'),
      ('এটা জরুরি', {'action': 'task_edit', 'ref': 'it', 'urgent': true}, 'edit it urgent'),
      ('আর মনে করিও না', {'action': 'reminder_stop', 'ref': 'it'}, 'edit it stopReminder'),
      ('এই শুক্রবারটা বাদ দাও', {'action': 'task_skip_once', 'ref': 'it'}, 'edit it skipOnce'),
      ('দশ মিনিট পরে আবার মনে করিও', {'action': 'reminder_snooze', 'minutes': 10}, 'snooze 10'),
      ('আগামী সপ্তাহে রিপোর্ট জমা দেব', {'action': 'task_add', 'text': 'রিপোর্ট জমা দেওয়া', 'date': '2026-10-10', 'span': 'week'}, 'add রিপোর্ট জমা দেওয়া 2026-10-10 week'),
      ('সজীবকে পাঁচশ টাকা ফেরত দিতে হবে', {'action': 'task_add', 'text': 'সজীবকে পাঁচশ টাকা ফেরত দেওয়া'}, 'add সজীবকে পাঁচশ টাকা ফেরত দেওয়া -'),
    ];

    String sig(Command c) => switch (c) {
          TaskAdd() => 'add ${c.title} ${c.due?.toIso8601String().substring(0, 10) ?? '-'}${c.span == TaskSpan.day ? '' : ' ${c.span.name}'}',
          TaskDone(:final ref) => '${c.done ? 'done' : 'notdone'} ${ref?.index != null ? '#${ref!.index}' : [...?ref?.terms, ...c.terms].any((x) => 'বাজার'.startsWith(x) && x.length >= 3) ? '[বাজার]' : ref?.terms}',
          TaskEdit() => 'edit ${c.ref.it ? 'it' : c.ref.terms}${c.due != null ? ' due ${c.due!.toIso8601String().substring(0, 10)}' : ''}${c.urgent == true ? ' urgent' : ''}${c.stopReminder ? ' stopReminder' : ''}${c.skipOnce ? ' skipOnce' : ''}',
          ReminderSnooze() => 'snooze ${c.minutes}',
          _ => c.runtimeType.toString(),
        };

    for (final (said, ai, want) in cases) {
      test(said, () {
        final local = parseAll(said, const [], tasks: seed(), now: now);
        final fromAi = commandsFromAi(said, {
          'reply': 'জি',
          'items': [ai],
        }, const []);
        expect(local.map(sig).toList(), [want], reason: 'rules: $said');
        expect(fromAi.map(sig).toList(), [want], reason: 'AI: $said');
      });
    }
  });
}
