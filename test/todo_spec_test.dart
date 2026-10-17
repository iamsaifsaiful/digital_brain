// The to-do list guide (17 Oct): every example sentence, said the way people
// say it, ends in the same intent — add, look, done, not done, change,
// remind, repeat, remove — and the app answers from its own list.
// The test clock is Friday 9 Oct 2026, 15:53; weeks start on Saturday.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;

List<Task> seed() => [
      Task(id: 't1', title: 'বাজার করা', due: DateTime(2026, 10, 9)),
      Task(id: 't2', title: 'ওষুধ আনা', due: DateTime(2026, 10, 9)),
      Task(id: 't3', title: 'বিদ্যুৎ বিল দেওয়া', due: DateTime(2026, 10, 9)),
      Task(id: 't4', title: 'ইন্টারনেট বিল দেওয়া'),
      Task(id: 't5', title: 'রিপোর্ট পাঠানো', due: DateTime(2026, 10, 12)),
      Task(id: 't6', title: 'স্যারকে ফোন করা', due: DateTime(2026, 10, 10)),
      Task(id: 't7', title: 'ডাক্তারকে ফোন করা', due: DateTime(2026, 10, 7)),
      Task(id: 't8', title: 'ব্যাংকে যাওয়া'),
    ];

void main() {
  late ChatController chat;
  Future<(ChatController, List<String>)> talk(WidgetTester t, List<String> turns, {bool seeded = true}) async {
    final rig = await start(t);
    if (seeded) rig.brain.data.tasks.addAll(seed());
    chat = ChatController(rig.brain);
    final out = <String>[];
    for (final s in turns) {
      final n = chat.messages.length;
      await chat.hear(s);
      out.add(chat.messages.skip(n).where((m) => !m.fromUser).map((m) => m.text).join(' '));
    }
    return (chat, out);
  }

  Task task(String title) => chat.brain.data.tasks.firstWhere((x) => x.title == title);
  Task added(String title) => chat.brain.data.tasks.lastWhere((x) => x.title == title);

  group('1. adding — kept at once, in the words of a to-do', () {
    for (final (said, title, due) in [
      ('একটা কাজ যোগ করো, পানির ফিল্টার কিনতে হবে।', 'পানির ফিল্টার কেনা', null),
      ('গ্যাসের বিল দিতে হবে, মনে রেখো।', 'গ্যাসের বিল দেওয়া', null),
      ('আমার টু-ডুতে স্যারকে ইমেইল পাঠানো রাখো।', 'স্যারকে ইমেইল পাঠানো', null),
      ('লিখে রাখো, দোকানের মাল আনতে হবে।', 'দোকানের মাল আনা', null),
      ('Add a task, send the proposal.', 'send the proposal', null),
      ('কাল client-কে quotation send করতে হবে।', 'client-কে quotation send করা', DateTime(2026, 10, 10)),
      ('কাল ফার্মেসিতে যাইতে অইব।', 'ফার্মেসিতে যাওয়া', DateTime(2026, 10, 10)),
      ('বাজারের কামডা লিস্টে রাখো।', 'বাজার', null),
      ('পরশু ওষুধ আনতে হবে।', 'ওষুধ আনা', DateTime(2026, 10, 11)),
      ('আগামী মাসের পাঁচ তারিখে ভাড়া দিতে হবে।', 'ভাড়া দেওয়া', DateTime(2026, 11, 5)),
      ('তিন দিন পরে ফিল্টার পরিষ্কার করব।', 'ফিল্টার পরিষ্কার করা', DateTime(2026, 10, 12)),
      ('দুই সপ্তাহ পর ওয়েবসাইটটা পরীক্ষা করব।', 'ওয়েবসাইটটা পরীক্ষা করা', DateTime(2026, 10, 23)),
    ]) {
      testWidgets(said, (t) async {
        final (c, r) = await talk(t, [said]);
        final x = added(title);
        expect(x.due, due, reason: said);
        expect(r.single, contains('“$title”'));
        expect(r.single, isNot(contains('রাখি?')), reason: 'no confirmation for a plain to-do');
        expect(c.wait, ChatWait.none);
      });
    }

    testWidgets('three in one: "বাজার, ওষুধ আর বিদ্যুৎ বিল—তিনটা কাজ রাখো"', (t) async {
      final (c, r) = await talk(t, ['বাজার, ওষুধ আর বিদ্যুৎ বিল—তিনটা কাজ রাখো।'], seeded: false);
      expect(c.brain.data.tasks.map((x) => x.title), ['বাজার', 'ওষুধ', 'বিদ্যুৎ বিল']);
      expect(r.single, contains('৩টা কাজ যোগ করেছি'));
    });

    testWidgets('no words: "কাজ লিখে রাখো" asks which', (t) async {
      final (c, r) = await talk(t, ['কাজ লিখে রাখো।', 'চশমা ঠিক করাতে হবে'], seeded: false);
      expect(r[0], contains('কোন কাজটি লিখে রাখব'));
      expect(c.brain.data.tasks.single.title, 'চশমা ঠিক করানো');
    });

    testWidgets('already on the list: said so, not kept twice', (t) async {
      final (c, r) = await talk(t, ['বিদ্যুৎ বিল দেওয়ার কাজটা লিখে রাখো।']);
      expect(r.single, contains('আগেই'));
      expect(c.brain.data.tasks.where((x) => x.title == 'বিদ্যুৎ বিল দেওয়া'), hasLength(1));
    });

    testWidgets('"লিখে রাখো যে করিমের দোকান বন্ধ" stays a note, not a to-do', (t) async {
      final (c, _) = await talk(t, ['লিখে রাখো যে করিমের দোকান বন্ধ'], seeded: false);
      expect(c.brain.data.tasks, isEmpty);
    });
  });

  group('3. the future — a day, a week, a month, a year, or no date', () {
    testWidgets('a week, a month and a year are kept as such, never a made-up day', (t) async {
      final (c, r) = await talk(t, ['আগামী সপ্তাহে রিপোর্ট জমা দেব।', 'ডিসেম্বরে পাসপোর্ট নবায়ন করতে হবে।', 'পরের বছর ব্যবসার লাইসেন্স নবায়ন করব।', 'একদিন সময় করে আলমারি গুছাব।'], seeded: false);
      final ts = c.brain.data.tasks;
      expect((ts[0].span, ts[0].due), (TaskSpan.week, DateTime(2026, 10, 10)));
      expect(r[0], contains('আগামী সপ্তাহে'));
      expect((ts[1].span, ts[1].due), (TaskSpan.month, DateTime(2026, 12, 1)));
      expect(r[1], contains('ডিসেম্বর মাসে'));
      expect((ts[2].span, ts[2].due!.year), (TaskSpan.year, 2027));
      expect((ts[3].title, ts[3].due), ('আলমারি গোছানো', null));
      expect(r[3], contains('তারিখ ছাড়া'));
    });

    testWidgets('"শুক্রবার …" on a Friday: today or next Friday is asked', (t) async {
      final (c, r) = await talk(t, ['শুক্রবার মাসের বাজার করব।', 'আগামী শুক্রবার'], seeded: false);
      expect(r[0], contains('নাকি আগামী শুক্রবার'));
      expect(c.brain.data.tasks.single.due, DateTime(2026, 10, 16));
    });

    testWidgets('planned day and last day: "বৃহস্পতিবার করব, তবে শুক্রবারের মধ্যে জমা দিতে হবে"', (t) async {
      final (c, r) = await talk(t, ['বৃহস্পতিবার করব, তবে শুক্রবারের মধ্যে জমা দিতে হবে।'], seeded: false);
      expect(c.brain.data.tasks.single.due, DateTime(2026, 10, 15));
      expect(r.single, contains('শেষ সময় শুক্রবার, ১৬ অক্টোবর'));
    });

    testWidgets('a condition the app cannot see is kept, never turned into a date', (t) async {
      final (c, r) = await talk(t, ['বেতন পেলে গ্যাসের বিল দেব।', 'রিপোর্ট শেষ হলে ক্লায়েন্টকে পাঠাব।'], seeded: false);
      expect(c.brain.data.tasks.map((x) => (x.title, x.due, x.note)), [('গ্যাসের বিল দেওয়া', null, 'বেতন পেলে'), ('ক্লায়েন্টকে পাঠানো', null, 'রিপোর্ট শেষ হলে')]);
      expect(r[0], contains('অ্যাপ নিজে জানতে পারে না'));
    });

    testWidgets('"ঈদের আগে": the calendar\'s Eid is offered, not assumed', (t) async {
      final (c, r) = await talk(t, ['ঈদের আগে কেনাকাটা করতে হবে।', 'হ্যাঁ'], seeded: false);
      expect(r[0], contains('ঈদুল ফিতর'));
      expect(r[0], contains('চাঁদ দেখার'));
      expect(c.brain.data.tasks.single.due, isNotNull);
    });
  });

  group('2 & 4. looking — from the list only', () {
    for (final (said, has, hasNot) in [
      ('আমার কাজগুলো দেখাও।', '৮টা কাজ বাকি', 'রাখি?'),
      ('কী কী করা বাকি?', '৮টা কাজ বাকি', 'নম্বর'),
      ('আজ আমার কী কী করার আছে?', 'আজ ৬টা', 'স্যারকে'),
      ('মোট কয়টা কাজ জমেছে?', '৮টা কাজ বাকি', '__'),
      ('সময় পার হয়ে গেছে এমন কাজগুলো বলো।', 'ডাক্তারকে ফোন করা', 'বাজার'),
      ('কাল কী কী কাজ আছে?', 'স্যারকে ফোন করা', 'রিপোর্ট'),
      ('পরশু কোনো কাজ রেখেছি?', 'কোনো কাজ বা রিমাইন্ডার রাখা নেই', '__'),
      ('আগামী সপ্তাহের কাজ দেখাও।', 'রিপোর্ট পাঠানো', 'বাজার করা'),
      ('পরের মাসে কী কী করতে হবে?', 'আগামী মাসে কোনো কাজ রাখা নেই', '__'),
      ('সামনের সাত দিনের কাজ বলো।', 'সামনের ৭ দিনে', '__'),
      ('যেগুলোর তারিখ দিইনি সেগুলো দেখাও।', 'ইন্টারনেট বিল দেওয়া', 'বাজার করা'),
      ('ওষুধ আনার কাজ রেখেছিলাম?', 'হ্যাঁ, “ওষুধ আনা” তালিকায় আছে', '__'),
      ('বিল সংক্রান্ত কাজগুলো দেখাও।', '“বিল” নিয়ে ২টা কাজ', 'বাজার'),
      ('এখন কোনটা আগে করা ভালো?', 'আমার পরামর্শ: “ডাক্তারকে ফোন করা”', '__'),
      ('অফিসের কাজগুলো বলো।', 'কোনো বাকি কাজ তালিকায় পেলাম না', '__'),
    ]) {
      testWidgets(said, (t) async {
        final (c, r) = await talk(t, [said]);
        expect(r.single, contains(has));
        expect(r.single, isNot(contains(hasNot)));
        expect(c.brain.data.tasks, hasLength(8), reason: 'a question changes nothing');
      });
    }

    testWidgets('"আজ কতগুলো কাজ শেষ করেছি?" counts what was ticked today', (t) async {
      final (_, r) = await talk(t, ['বাজার করেছি', 'আজ কতগুলো কাজ শেষ করেছি?']);
      expect(r[1], contains('১টা কাজ শেষ করেছেন'));
    });

    testWidgets('"আমার টু-ডু লিস্ট খোলো" opens the page', (t) async {
      final (c, r) = await talk(t, ['আমার টু-ডু লিস্ট খোলো।']);
      expect(r.single, contains('কাজের তালিকা খুলছি'));
      expect(c.openNow?.page, 'tasks');
    });
  });

  group('5. done, not done, open again', () {
    testWidgets('"বাজার করেছি, ওষুধ আনিনি" — one done, one still to do', (t) async {
      final (_, r) = await talk(t, ['বাজার করেছি, ওষুধ আনিনি।']);
      expect(task('বাজার করা').done, isTrue);
      expect(task('ওষুধ আনা').done, isFalse);
      expect(r.single, allOf(contains('“বাজার করা” কাজটি সম্পন্ন'), contains('“ওষুধ আনা” কাজটি বাকি')));
    });

    testWidgets('two bills: "বিল দিয়ে দিয়েছি" asks which; "ইন্টারনেটেরটা" answers', (t) async {
      final (_, r) = await talk(t, ['বিল দিয়ে দিয়েছি।', 'ইন্টারনেটেরটা।']);
      expect(r[0], contains('নাকি'));
      expect(task('ইন্টারনেট বিল দেওয়া').done, isTrue);
      expect(task('বিদ্যুৎ বিল দেওয়া').done, isFalse);
    });

    testWidgets('"ওষুধ এনেছি, কাজটা টিক দাও" ticks one, once', (t) async {
      final (_, r) = await talk(t, ['ওষুধ এনেছি, কাজটা টিক দাও।']);
      expect(task('ওষুধ আনা').done, isTrue);
      expect(r.single, isNot(contains('আগেই')));
    });

    testWidgets('dialect: "বিলডা দেওয়া অয় নাই" is "not done"; "কামডা হইয়া গেছে" after it is done', (t) async {
      final (_, r) = await talk(t, ['বিলডা দেওয়া অয় নাই।', 'বিদ্যুতেরটা', 'কামডা হইয়া গেছে।']);
      expect(r[0], contains('নাকি'));
      expect(r[1], contains('বাকি আছে'));
      expect(task('বিদ্যুৎ বিল দেওয়া').done, isTrue);
    });

    testWidgets('ticked by mistake: "ভুল করে শেষ করেছি, আবার বাকি রাখো"', (t) async {
      final (_, r) = await talk(t, ['বাজার করার কাজটা হয়ে গেছে।', 'ভুল করে শেষ করেছি, আবার বাকি রাখো।']);
      expect(task('বাজার করা').done, isFalse);
      expect(r[1], contains('আবার অসমাপ্ত'));
    });

    testWidgets('"আজকের সব কাজ শেষ" ticks today\'s; "সব কাজ শেষ" asks which ones', (t) async {
      final (c, r) = await talk(t, ['সব কাজ শেষ।', 'আজকের কাজগুলো']);
      expect(r[0], contains('আজকের কাজগুলো, নাকি তালিকার সব কাজ?'));
      expect(task('রিপোর্ট পাঠানো').done, isFalse);
      expect(task('বাজার করা').done, isTrue);
      expect(c.brain.data.tasks.where((x) => x.done).length, 6);
    });

    testWidgets('"কাজটা অর্ধেক হয়েছে" is said honestly, nothing ticked', (t) async {
      final (c, r) = await talk(t, ['আজকের কাজগুলো বলো।', 'দ্বিতীয়টা অর্ধেক হয়েছে']);
      expect(r[1], contains('আংশিক'));
      expect(c.brain.data.tasks.where((x) => x.done), isEmpty);
    });
  });

  group('6. changing one — the right one, said back', () {
    testWidgets('rename, move, shift, no date, urgent, note', (t) async {
      final (_, r) = await talk(t, [
        'বাজার করার বদলে মাসের বাজার করা লিখো।',
        'ডাক্তারকে ফোন করার কাজটা কাল রাখো।',
        'একদিন পিছিয়ে দাও।',
        'তারিখ বাদ দাও, কাজটা থাক।',
        'এটা জরুরি',
        'এর সঙ্গে লিখো, রিপোর্ট নিয়ে যেতে হবে।',
      ]);
      expect(r[0], contains('“মাসের বাজার করা”'));
      expect(task('মাসের বাজার করা').due, DateTime(2026, 10, 9));
      final d = task('ডাক্তারকে ফোন করা');
      expect(r[1], contains('কাল'));
      expect(r[2], contains('পরশু'));
      expect(d.due, isNull);
      expect(d.urgent, isTrue);
      expect(d.note, contains('রিপোর্ট নিয়ে যেতে হবে'));
    });

    testWidgets('"বিল দেওয়ার কাজটা জরুরি" asks which; the urgent one is said first', (t) async {
      final (_, r) = await talk(t, ['বিল দেওয়ার কাজটা জরুরি।', 'বিদ্যুতেরটা।', 'জরুরি কাজগুলো আগে দেখাও।']);
      expect(r[0], contains('নাকি'));
      expect(task('বিদ্যুৎ বিল দেওয়া').urgent, isTrue);
      expect(r[2], contains('— বিদ্যুৎ বিল দেওয়া'));
    });

    testWidgets('"আজকের কাজগুলো বলো" → "দ্বিতীয়টা হয়ে গেছে" → "শেষেরটা কাল দাও"', (t) async {
      final (_, r) = await talk(t, ['আজকের কাজগুলো বলো।', 'দ্বিতীয়টা হয়ে গেছে।', 'শেষেরটা কাল দাও।']);
      expect(r[1], contains('“বাজার করা” কাজটি সম্পন্ন'));
      expect(task('বাজার করা').done, isTrue);
      expect(task('ব্যাংকে যাওয়া').due, DateTime(2026, 10, 10));
    });

    testWidgets('a week to-do: "বুধবার রাখো" is that week\'s Wednesday', (t) async {
      final (c, r) = await talk(t, ['আগামী সপ্তাহে ওয়েবসাইট পরীক্ষা করব।', 'বুধবার রাখো।', 'সকালে মনে করিও।', '৯টায়'], seeded: false);
      final w = c.brain.data.tasks.single;
      expect((w.due, w.span), (DateTime(2026, 10, 14), TaskSpan.day));
      expect(r[2], contains('বুধবার, ১৪ অক্টোবর সকালে কয়টায়'));
      final rem = c.brain.data.reminders.single;
      expect((rem.date, rem.hour), (DateTime(2026, 10, 14), 9));
      expect(w.reminderId, rem.id);
    }, skip: false);

    testWidgets('"…মুছে দেব ভাবছিলাম, কিন্তু এখন রাখো": nothing removed', (t) async {
      final (c, r) = await talk(t, ['আমি ভাবছিলাম বাজারের কাজটা মুছে দেব, কিন্তু এখন রাখো।']);
      expect(r.single, contains('রেখেছি'));
      expect(c.brain.data.tasks, hasLength(8));
    });

    testWidgets('mixed: "Meeting-এর task-টা tomorrow move করো"', (t) async {
      final (c, _) = await talk(t, ['মিটিং প্রস্তুতি নিতে হবে', 'Meeting-এর task-টা tomorrow move করো'], seeded: false);
      expect(c.brain.data.tasks.single.due, DateTime(2026, 10, 10));
    });
  });

  group('7. reminders for a to-do', () {
    testWidgets('"ওটার রিমাইন্ডার সকাল দশটায় দিও" → "না, এগারোটায়": one reminder, changed', (t) async {
      final (c, r) = await talk(t, ['কাল স্যারকে ফোন করার কাজ রাখো।', 'ওটার রিমাইন্ডার সকাল দশটায় দিও।', 'না, এগারোটায়।']);
      expect(r[1], contains('কাল (শনিবার) সকাল ১০টা'));
      expect(r[2], contains('১১টা'));
      final rem = c.brain.data.reminders.single;
      expect((rem.date, rem.hour), (DateTime(2026, 10, 10), 11));
      expect(task('স্যারকে ফোন করা').reminderId, rem.id);
      expect(c.brain.data.tasks.where((x) => x.title == 'স্যারকে ফোন করা'), hasLength(1), reason: 'never a new to-do');
    });

    testWidgets('"কাল আটটায়": morning or night is asked', (t) async {
      final (c, r) = await talk(t, ['কাল আটটায় বিল দিতে মনে করিও।', 'রাত']);
      expect(r[0], 'সকাল ৮টা, নাকি রাত ৮টা?');
      expect((c.brain.data.reminders.single.hour, c.brain.data.reminders.single.title), (20, 'বিল দেওয়া'));
    });

    testWidgets('"বাজারের কাজটায় রিমাইন্ডার দাও" asks when; "আর মনে করিও না" stops it, the to-do stays', (t) async {
      final (c, r) = await talk(t, ['বাজারের কাজটায় রিমাইন্ডার দাও।', 'সন্ধ্যা ৭টায়', 'আর মনে করিও না।']);
      expect(r[0], contains('কখন মনে করিয়ে দেব'));
      expect(r[2], contains('রিমাইন্ডার বন্ধ করেছি'));
      expect(c.brain.data.reminders.single.enabled, isFalse);
      expect(task('বাজার করা').done, isFalse);
    });

    testWidgets('a place cannot be watched: said so, no promise', (t) async {
      final (c, r) = await talk(t, ['বাজারের কাছে গেলে মনে করিও।']);
      expect(r.single, contains('জায়গা ধরে মনে করানোর ব্যবস্থা এই অ্যাপে নেই'));
      expect(c.brain.data.reminders, isEmpty);
    });
  });

  group('8. repeating to-dos', () {
    testWidgets('daily, weekly, monthly, every few days, chosen weekdays', (t) async {
      final (c, _) = await talk(t, ['প্রতিদিন হাঁটার কাজ রাখো।', 'প্রতি শুক্রবার বাজার করব।', 'প্রতি মাসের দশ তারিখে ভাড়া দেব।', 'দুই দিন পরপর গাছে পানি দেব।', 'রবি, মঙ্গল আর বৃহস্পতিবার ব্যায়াম করব।'], seeded: false);
      final r = [for (final x in c.brain.data.tasks) x.repeat];
      expect(r, [
        const TaskRepeat.daily(),
        const TaskRepeat.weekly([DateTime.friday]),
        const TaskRepeat.monthly(10),
        const TaskRepeat.everyDays(2),
        const TaskRepeat.weekly([DateTime.tuesday, DateTime.thursday, DateTime.sunday]),
      ]);
    });

    testWidgets('done today → back next time; "এই শুক্রবারটা বাদ দাও" skips one', (t) async {
      final (c, r) = await talk(t, ['প্রতি শুক্রবার বাজার করব।', 'আজ বাজার করেছি', 'এই শুক্রবারটা বাদ দাও।'], seeded: false);
      expect(r[1], contains('আবার শুক্রবার, ১৬ অক্টোবর'));
      final x = c.brain.data.tasks.single;
      expect(x.done, isFalse, reason: 'a repeating to-do is never finished');
      expect(x.due, DateTime(2026, 10, 23));
    });

    testWidgets('"প্রতি মাসের একত্রিশ তারিখে": what a short month does is asked', (t) async {
      final (c, r) = await talk(t, ['প্রতি মাসের একত্রিশ তারিখে বাড়িভাড়া দিতে হবে', 'হ্যাঁ, মাসের শেষ দিনে'], seeded: false);
      expect(r[0], contains('যে মাসে ৩১ তারিখ নেই'));
      expect(c.brain.data.tasks.single.repeat, const TaskRepeat.monthly(31));
      expect(const TaskRepeat.monthly(31).nextOnOrAfter(DateTime(2026, 11, 2)), DateTime(2026, 11, 30));
      expect(const TaskRepeat.monthly(31, strict: true).nextOnOrAfter(DateTime(2026, 11, 2)), DateTime(2026, 12, 31));
    });
  });

  group('10. removing — asked once', () {
    testWidgets('one to-do: asked, removed, brought back', (t) async {
      final (c, r) = await talk(t, ['বাজারের কাজটা তালিকা থেকে বাদ দাও।', 'হ্যাঁ', 'ভুল করে মুছে ফেলেছি, ফেরত আনো।']);
      expect(r[0], contains('মুছে দেবো?'));
      expect(r[2], contains('ফেরত এনেছি'));
      expect(c.brain.data.tasks.where((x) => x.title == 'বাজার করা'), hasLength(1));
    });

    testWidgets('"শেষ করা কাজগুলো সরাও" asks once, removes only the ticked ones', (t) async {
      final (c, r) = await talk(t, ['বাজার করেছি', 'শেষ করা কাজগুলো সরাও।', 'হ্যাঁ']);
      expect(r[1], contains('শেষ করা ১টা কাজ'));
      expect(c.brain.data.tasks, hasLength(7));
    });
  });

  group('13. opposite meanings never swap', () {
    testWidgets('"আজ আর অফিসে যাব না" and "যেতে হবে না" add nothing', (t) async {
      final (c, _) = await talk(t, ['আজ আর অফিসে যাব না', 'কাল ব্যাংকে যেতে হবে না'], seeded: false);
      expect(c.brain.data.tasks, isEmpty);
    });

    testWidgets('"শেষ করতে হবে" is still to do, not done', (t) async {
      final (_, r) = await talk(t, ['রিপোর্ট শেষ করতে হবে']);
      expect(task('রিপোর্ট পাঠানো').done, isFalse);
      expect(r.single, isNot(contains('সম্পন্ন')));
    });

    testWidgets('"না, পাঁচটায় নয়, ছয়টায়" with nothing to correct: asked, never saved as a reminder', (t) async {
      final (c, r) = await talk(t, ['না, পাঁচটায় নয়, ছয়টায়'], seeded: false);
      expect(r.single, contains('কোনটার সময় বদলাব'));
      expect(c.brain.data.reminders, isEmpty);
    });

    testWidgets('right after it was kept, "এটা তো বলি নাই" takes it back', (t) async {
      final (c, r) = await talk(t, ['কাল ফার্মেসিতে যেতে হবে', 'এটা তো বলি নাই'], seeded: false);
      expect(r[1], 'আচ্ছা, রাখলাম না।');
      expect(c.brain.data.tasks, isEmpty);
    });
  });
}
