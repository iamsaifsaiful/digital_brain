// Held out: 40 more phrasings written after the 500-case fixes and never
// used to tune them — a check that the fixes are general, not fitted. Same
// fixture and checks as intent500_test.dart.
//
// 500 ways people ask about their to-do list and reminders (19 Oct
// brief): what each one means (its intent) is checked by what the app then
// does to the data — not by the words of the reply. One fresh session and
// fixture per case; a question the app asks is answered the plain way
// ("হ্যাঁ", "সকাল ৯টায়") so the end state can be checked.
//
// Intents: list / listday (see; nothing written), add, done, delete, move,
// remtask (a reminder on a to-do), remind (a reminder of its own), remq
// (see reminders), remoff (stop or remove one), none (help, thanks, a
// complaint: nothing written, nothing left waiting).
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;

const cases = <(String, String, String)>[
  ('কাজের তালিকাটা একবার দেখাও তো', 'list', ''),
  ('আমার করণীয় কী কী?', 'list', ''),
  ('কোন কাজগুলো এখনো ঝুলে আছে', 'list', ''),
  ('লিস্টে কয়টা কাজ আছে', 'list', ''),
  ('আজকে কী কী করা লাগবে', 'listday', 'বাজার করা'),
  ('আজকের কাজকর্ম কী', 'listday', 'বাজার করা'),
  ('কাল সারাদিন কী কাজ আছে', 'listday', 'ব্যাংকে যাওয়া'),
  ('আগামীকাল কোন কাজ রাখা আছে?', 'listday', 'ব্যাংকে যাওয়া'),
  ('২৫ তারিখ কী করার আছে', 'listday', 'রিপোর্ট জমা দেওয়া'),
  ('রিপোর্ট জমা কবে দিতে হবে?', 'listday', 'রিপোর্ট জমা দেওয়া'),
  ('ডিম কিনতে হবে', 'add', 'ডিম'),
  ('কাল সকালে গ্যাস বিল দিতে হবে', 'add', 'বিল'),
  ('পরশু দর্জির দোকানে যাব', 'add', 'দর্জি'),
  ('টুডুতে রাখো: ছাদের ট্যাংক পরিষ্কার করা', 'add', 'ট্যাংক'),
  ('কাজের তালিকায় যোগ করো বই ফেরত দেওয়া', 'add', 'বই'),
  ('শুক্রবার নানুর বাসায় যাব লিখে রাখো', 'add', 'নানু'),
  ('ফ্রিজ সার্ভিসিং করাতে হবে কাজে রাখো', 'add', 'ফ্রিজ'),
  ('বাজার করা হয়ে গেছে', 'done', 'B'),
  ('ব্যাংকের কাজটা সেরে ফেলেছি', 'done', 'K'),
  ('রিপোর্টটা জমা দিয়ে দিয়েছি, টিক দাও', 'done', 'R'),
  ('বাজারের কাজটা তালিকা থেকে সরিয়ে দাও', 'delete', 'B'),
  ('নোয়াখালী যাওয়ার কাজটা ডিলিট করো', 'delete', 'N'),
  ('ব্যাংকের কাজটা পরশু দিন সরাও', 'move', 'K:2026-10-21'),
  ('বাজার করা কালকে করব, সরিয়ে দাও', 'move', 'B:2026-10-20'),
  ('রিপোর্ট জমার কাজে রিমাইন্ডার দাও', 'remtask', 'R'),
  ('বাজারের কাজটা মনে করিয়ে দিও', 'remtask', 'B'),
  ('আজ সন্ধ্যা ৭টায় মনে করিয়ে দিও গ্যাস বন্ধ করতে', 'remind', '2026-10-19'),
  ('পরশু সকাল ১০টায় দাঁতের ডাক্তারের রিমাইন্ডার দাও', 'remind', '2026-10-21'),
  ('প্রতি মাসের ১ তারিখে বাড়িভাড়ার কথা মনে করাবে', 'remind', 'monthly'),
  ('রোজ রাত ১১টায় পানি খাওয়ার কথা মনে করিয়ে দিও', 'remind', 'daily'),
  ('কোন কোন রিমাইন্ডার দেওয়া আছে?', 'remq', ''),
  ('আজ কী কী মনে করাবে বলো', 'remq', ''),
  ('আমার রিমাইন্ডারের লিস্ট দাও', 'remq', ''),
  ('ওষুধের রিমাইন্ডার আর দরকার নেই', 'remoff', 'W'),
  ('মিটিংয়ের এলার্ম বন্ধ করে দাও', 'remoff', 'M'),
  ('ওষুধের কথা আর মনে করাইও না ভাই', 'remoff', 'W'),
  ('তুমি কিভাবে মনে করাও?', 'none', ''),
  ('ঠিক আছে ধন্যবাদ', 'none', ''),
  ('এভাবে হবে না', 'none', ''),
  ('আগের মতো বুঝো না কেন', 'none', ''),
];

AppData fixture() => AppData(
      tasks: [
        Task(id: 'B', title: 'বাজার করা', due: DateTime(2026, 10, 19), createdAt: DateTime(2026, 10, 1)),
        Task(id: 'K', title: 'ব্যাংকে যাওয়া', due: DateTime(2026, 10, 20), createdAt: DateTime(2026, 10, 2)),
        Task(id: 'R', title: 'রিপোর্ট জমা দেওয়া', due: DateTime(2026, 10, 25), createdAt: DateTime(2026, 10, 3)),
        Task(id: 'N', title: 'নোয়াখালী যাওয়া', due: DateTime(2029, 6, 15), createdAt: DateTime(2026, 10, 4)),
      ],
      reminders: [
        Reminder(id: 'M', title: 'মিটিং', date: DateTime(2026, 10, 19), hour: 16),
        Reminder(id: 'W', title: 'ওষুধ খাওয়া', date: DateTime(2026, 10, 19), hour: 21, repeat: Repeat.daily),
      ],
    );

String state(AppData d) => [
      for (final x in d.tasks) '${x.id}|${x.title}|${x.due}|${x.span}|${x.done}|${x.reminderId}',
      for (final r in d.reminders) 'R:${r.id}|${r.title}|${r.date}|${r.hour}|${r.enabled}|${r.repeat}',
      'n${d.notes.length} c${d.cash.length} l${d.ledger.length} s${d.specialDays.length}',
    ].join('\n');

void main() {
  for (final (i, c) in cases.indexed) {
    final (said, intent, arg) = c;
    testWidgets('${(i + 1).toString().padLeft(3, '0')} [$intent] $said', (t) async {
      final rig = await start(t);
      rig.nowAt = DateTime(2026, 10, 19, 11);
      rig.brain.data = fixture();
      final chat = ChatController(rig.brain);
      final before = state(rig.brain.data);
      final n0 = chat.messages.length;
      await chat.hear(said);
      final first = chat.messages.skip(n0).where((m) => !m.fromUser).map((m) => [m.text, ...m.facts].join(' ')).join(' ');
      // Answer what the app asks, the plain way, at most three times.
      for (var k = 0; k < 3 && chat.wait != ChatWait.none; k++) {
        final w = chat.wait;
        if (intent == 'none' || intent == 'alarmq' || intent == 'list' || intent == 'listday' || intent == 'remq') break;
        if (w == ChatWait.reminderTime || w == ChatWait.taskTime || w == ChatWait.batchTime) {
          // Later today, so a to-do due today can still be reminded.
          await chat.hear('সন্ধ্যা ৭টায়');
        } else if (w == ChatWait.clarify || w == ChatWait.whichTask || w == ChatWait.whichItem) {
          await chat.hear('১');
        } else if (w == ChatWait.reminderTitle) {
          await chat.hear('ফাইল নেওয়া');
        } else if (w == ChatWait.yesNo || w == ChatWait.bulk) {
          await chat.hear('হ্যাঁ');
        } else {
          break;
        }
      }
      final d = rig.brain.data;
      final after = state(d);
      Task? task(String id) => d.tasks.where((x) => x.id == id).firstOrNull;
      final why = 'reply: $first';
      switch (intent) {
        case 'list' || 'listday' || 'remq':
          expect(after, before, reason: 'a question changed the data — $why');
          expect(chat.wait == ChatWait.collect, isFalse, reason: why);
          final want = intent == 'list' ? ['বাজার করা', 'ব্যাংকে যাওয়া'] : (intent == 'remq' ? ['মিটিং', 'ওষুধ'] : [arg]);
          expect(want.any(first.contains), isTrue, reason: 'the list/answer was not shown — $why');
        case 'none':
          expect(after, before, reason: why);
          expect(chat.wait == ChatWait.collect, isFalse, reason: why);
        case 'alarmq':
          // Reminders are what ring; either listed, or a plain answer — never a change.
          expect(after, before, reason: why);
          expect(first.trim(), isNotEmpty, reason: why);
        case 'add':
          final added = [for (final x in d.tasks) if (!const {'B', 'K', 'R', 'N'}.contains(x.id)) x];
          expect(added, isNotEmpty, reason: 'no to-do kept — $why');
          expect(added.any((x) => x.title.contains(arg)), isTrue, reason: '${added.map((x) => x.title)} — $why');
          expect(d.reminders.length, 2, reason: 'a to-do is not a reminder unless asked — $why');
          expect(d.notes, isEmpty, reason: why);
        case 'done':
          expect(task(arg)?.done, isTrue, reason: why);
          expect(d.tasks, hasLength(4), reason: why);
        case 'delete':
          expect(task(arg), isNull, reason: why);
          expect(d.tasks, hasLength(3), reason: 'only that one — $why');
        case 'move':
          final (id, day) = (arg.split(':')[0], DateTime.parse(arg.split(':')[1]));
          expect(task(id)?.due, day, reason: why);
          expect(d.tasks, hasLength(4), reason: why);
        case 'remtask':
          final x = task(arg)!;
          expect(x.reminderId, isNotNull, reason: why);
          final r = d.reminders.firstWhere((y) => y.id == x.reminderId);
          expect(r.date, DateTime(x.due!.year, x.due!.month, x.due!.day), reason: 'on the to-do\'s own day — $why');
          expect(d.tasks, hasLength(4), reason: 'no new to-do — $why');
        case 'remind':
          final fresh = [for (final r in d.reminders) if (r.id != 'M' && r.id != 'W') r];
          expect(fresh, hasLength(1), reason: '${fresh.map((r) => '${r.title} ${r.date}')} — $why');
          final r = fresh.single;
          if (arg == 'daily') {
            expect(r.repeat, Repeat.daily, reason: why);
          } else if (arg == 'monthly') {
            expect(r.repeat, Repeat.monthly, reason: why);
          } else {
            expect(r.date, DateTime.parse(arg), reason: why);
          }
          expect(d.tasks, hasLength(4), reason: 'a reminder is not a to-do — $why');
        case 'remoff':
          final r = d.reminders.where((y) => y.id == arg).firstOrNull;
          expect(r == null || !r.enabled, isTrue, reason: why);
          expect(d.tasks, hasLength(4), reason: why);
      }
    });
  }
}
