// How the assistant understands Bangla: each real feature asked in many
// different ways (standard, spoken, regional, Banglish), opposites and
// negatives, and corrections made mid-sentence. The rules are judged on the
// whole sentence — who does what to whom, and whether it is said in the
// negative — so the same word can mean different things.
import 'package:digital_brain/logic/meaning.dart';
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/logic/plan.dart';
import 'package:digital_brain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 10, 9, 15, 53);

// রহিম owes me 500; I owe করিম 1000.
final ledger = [
  LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 500, date: DateTime(2026, 10, 1)),
  LedgerEntry(person: 'করিম', kind: LedgerKind.borrowed, amount: 1000, date: DateTime(2026, 10, 2)),
];
final tasks = [Task(title: 'রিপোর্ট জমা দেওয়া'), Task(title: 'বিদ্যুৎ বিল দেওয়া'), Task(title: 'ডাক্তার দেখানো', done: true, doneAt: DateTime(2026, 10, 8))];
final contacts = [Contact(name: 'রহিম', phone: '01711000000'), Contact(name: 'সাবিনা', phone: '01811000000')];

Command one(String s) {
  final c = parseAll(s, ledger, tasks: tasks, contacts: contacts, now: now);
  expect(c, hasLength(1), reason: '$s → $c');
  return c.single;
}

/// Checks every sentence and reports all that fail together.
void each(List<String> said, void Function(String s, Command c) check) {
  expect(said.length, greaterThanOrEqualTo(10), reason: 'at least 10 ways to say it');
  final failed = <String>[];
  for (final s in said) {
    final cs = parseAll(s, ledger, tasks: tasks, contacts: contacts, now: now);
    try {
      expect(cs, hasLength(1));
      check(s, cs.single);
    } on TestFailure {
      failed.add('$s → ${cs.map(describeCommand).join(' + ')}');
    }
  }
  expect(failed, isEmpty, reason: failed.join('\n'));
}

String describeCommand(Command c) => switch (c) {
      LedgerAdd(:final person, :final amount, :final kind, :final suggested, :final options) => 'LedgerAdd($person, $amount, ${kind?.name ?? 'ask ${options.map((o) => o.name)} ~${suggested?.name}'})',
      LedgerQuery(:final ask, :final person) => 'LedgerQuery(${ask.name}${person == null ? '' : ', $person'})',
      CashAdd(:final kind, :final amount) => 'CashAdd(${kind.name}, $amount)',
      ReminderAdd(:final title, :final at, :final alarm) => 'ReminderAdd($title, $at${alarm ? ', alarm' : ''})',
      TaskAdd(:final title) => 'TaskAdd($title)',
      TaskDone(:final done) => 'TaskDone(done: $done)',
      SmallTalk(:final kind) => 'SmallTalk(${kind.name})',
      ManageItem(:final action) => 'ManageItem($action)',
      _ => c.runtimeType.toString(),
    };

void main() {
  group('লেনদেন — who gave whom', () {
    test('I lent', () {
      each([
        'রহিমকে পাঁচশ টাকা ধার দিয়েছি',
        'আজ সজীবকে ২০০০ টাকা ধার দিলাম',
        'আমি রুবেলকে ৩ হাজার টাকা কর্জ দিলাম',
        'মামুনরে ৫০০ টেকা ধার দিছি',
        'sajib ke 500 taka dhar dilam',
        'গতকাল নাসিরকে এক হাজার টাকা লোন দিয়েছি',
        'রহিম আরও দুইশ টাকা নিয়েছে',
        'রহিম আমার কাছ থেকে ৩০০ টাকা ধার নিল',
        'সুমন ভাইকে দেড় হাজার টাকা হাওলাত দিলাম',
        'রাকিব আমার থেকে ৮০০ টাকা নিয়ে গেছে',
      ], (s, c) {
        expect(c, isA<LedgerAdd>(), reason: s);
        expect((c as LedgerAdd).kind, LedgerKind.lent, reason: s);
        expect(c.amount, greaterThan(0), reason: s);
      });
    });

    test('I borrowed — the opposite direction', () {
      each([
        'রহিমের কাছ থেকে ধার নিয়েছি ৫০০ টাকা',
        'আমি সজীবের কাছ থেকে ২০০০ টাকা ধার নিলাম',
        'রুবেল আমাকে ৩ হাজার টাকা ধার দিয়েছে',
        'মামুনের থেকে ৫০০ টেকা হাওলাত নিছি',
        'নাসির ভাই আমাকে এক হাজার টাকা লোন দিলেন',
        'রাকিবের কাছ থেকে ৮০০ টাকা কর্জ নিয়েছি',
        'সুমনের কাছে ১২০০ টাকা ধার নিলাম',
        'আজ জামাল আমাকে ৪০০ টাকা ধার দিল',
        'rubel amake 700 taka dhar diyeche',
        'আমি তানভীরের কাছ থেকে দুই হাজার টাকা ঋণ নিয়েছি',
      ], (s, c) {
        expect(c, isA<LedgerAdd>(), reason: s);
        expect((c as LedgerAdd).kind, LedgerKind.borrowed, reason: s);
      });
    });

    test('paid back and got back', () {
      each([
        'করিমকে ধারের ৫০০ টাকা ফেরত দিলাম',
        'করিমের টাকা শোধ করে দিলাম ১০০০',
        'আমি করিমকে ৩০০ টাকা শোধ করেছি',
        'রহিম আমাকে ৩০০ টাকা ফেরত দিয়েছে',
        'রহিম সেই ধার থেকে ২০০ টাকা ফেরত দিল',
        'রহিম ৫০০ টাকা শোধ করেছে',
        'রহিমের কাছ থেকে ৩০০ টাকা ফেরত পেলাম',
        'করিমের ধার ২০০ টাকা পরিশোধ করলাম',
        'রহিম ধারের টাকা ৪০০ ফিরিয়ে দিয়েছে',
        'রহিমের থেকে পাওনা ২০০ টাকা পেয়েছি',
      ], (s, c) {
        expect(c, isA<LedgerAdd>(), reason: s);
        final k = (c as LedgerAdd).kind ?? c.suggested;
        expect(k, anyOf(LedgerKind.repaid, LedgerKind.received), reason: s);
        // Paying back is mine to করিম; getting back is from রহিম.
        expect(k, c.person == 'করিম' ? LedgerKind.repaid : LedgerKind.received, reason: s);
      });
    });

    test('"টাকা দিলাম" alone is never guessed as a loan — the app asks', () {
      for (final s in ['সজীবকে ৫০০ টাকা দিলাম', 'মিস্ত্রিকে ২০০০ টাকা দিয়েছি', 'আজ রাকিবকে ৩০০ টাকা দিলাম']) {
        final c = one(s) as LedgerAdd;
        expect(c.kind, isNull, reason: s);
        expect(c.allowExpense, isTrue, reason: '$s: may be spending, a gift or paying back');
      }
    });

    test('nothing happened: said in the negative', () {
      for (final s in ['সজীবকে টাকা দিইনি', 'রহিম টাকা ফেরত দেয়নি', 'করিমের কাছ থেকে ধার নিইনি', 'আমি রুবেলকে কোনো টাকা দেই নাই']) {
        expect(one(s), isA<SmallTalk>(), reason: s);
      }
    });
  });

  group('পাওনা আর দেনা — asked in many ways', () {
    test('what others owe me', () {
      each([
        'আমার পাওনা কত?',
        'কার কাছে কত পাই?',
        'মানুষের কাছে আমার কত টাকা আছে?',
        'আমি কত টাকা পাবো?',
        'কে কে আমাকে টাকা দেবে?',
        'কারা আমার কাছ থেকে টাকা নিয়েছে?',
        'বাজারে আমার কত পাওনা পড়ে আছে?',
        'কে কত টাকা ফেরত দেয়নি?',
        'amar pawna koto?',
        'সবার কাছে মিলিয়ে কত টাকা পাওনা?',
      ], (s, c) {
        expect(c, isA<LedgerQuery>(), reason: s);
        expect((c as LedgerQuery).ask, LedgerAsk.receivable, reason: s);
      });
    });

    test('what I owe others — the opposite', () {
      each([
        'আমার দেনা কত?',
        'কে আমার কাছে টাকা পাবে?',
        'আমাকে কত টাকা শোধ করতে হবে?',
        'আমি কাকে কত দেব?',
        'কাকে কাকে টাকা দিতে হবে?',
        'আমার কাছে কে কত পাবে?',
        'আমি কার কাছে ঋণী?',
        'আমার মোট ঋণ কত?',
        'আমাকে কত টাকা ফেরত দিতে হবে?',
        'আমি কার কাছ থেকে টাকা ধার নিয়েছি?',
      ], (s, c) {
        expect(c, isA<LedgerQuery>(), reason: s);
        expect((c as LedgerQuery).ask, LedgerAsk.payable, reason: s);
      });
    });

    test('one person', () {
      each([
        'রহিমের কাছে কত পাই?',
        'রহিম আমাকে কত দেবে?',
        'রহিমের হিসাব কত?',
        'রহিমের সাথে লেনদেন কত?',
        'করিমকে কত দিতে হবে?',
        'করিমের কাছে আমার দেনা কত?',
        'রহিমের কাছে আমার কত বাকি?',
        'করিমের সাথে হিসাব কেমন?',
        'রহিমের কাছে কত টাকা পাওনা আছে?',
        'করিমকে আর কত শোধ করতে হবে?',
      ], (s, c) {
        expect(c, isA<LedgerQuery>(), reason: s);
        expect((c as LedgerQuery).ask, LedgerAsk.person, reason: s);
      });
    });
  });

  group('আয়-খরচ', () {
    test('spending', () {
      each([
        'বাজারে ৫০০ টাকা খরচ হলো',
        'আজ রিকশা ভাড়া ৮০ টাকা খরচ',
        'বিদ্যুৎ বিল ১২০০ টাকা দিলাম',
        'ওষুধ কিনলাম ৩৫০ টাকার',
        'মোবাইলে ১০০ টাকা রিচার্জ করলাম',
        'দুপুরের খাবারে ২৫০ টাকা খরচ হয়েছে',
        'জুতা কিনেছি ১৫০০ টাকা দিয়ে',
        'গ্যাস বিল ৯৭৫ টাকা পরিশোধ করলাম',
        'স্কুলের বেতন ২০০০ টাকা দিলাম',
        'আজ বাজার করলাম সাতশ টাকার',
      ], (s, c) {
        expect(c, isA<CashAdd>(), reason: s);
        expect((c as CashAdd).kind, CashKind.expense, reason: s);
      });
    });

    test('income — the opposite', () {
      each([
        'বেতন পেলাম ৩০ হাজার টাকা',
        'আজ দোকানে ৫০০০ টাকা বিক্রি হলো',
        'ভাড়া পেলাম ১২০০০ টাকা',
        'এই মাসের স্যালারি ৪৫০০০ টাকা এসেছে',
        'কমিশন পেয়েছি ২০০০ টাকা',
        'ব্যবসায় লাভ হলো ৮০০০ টাকা',
        'আজ ১৫০০ টাকা ইনকাম হয়েছে',
        'বেতন এলো পঞ্চাশ হাজার',
        'মাল বিক্রি করলাম ৩২০০ টাকার',
        'salary pelam 40000 taka',
      ], (s, c) {
        expect(c, isA<CashAdd>(), reason: s);
        expect((c as CashAdd).kind, CashKind.income, reason: s);
      });
    });

    test('asking about it', () {
      each([
        'এই মাসে কত খরচ হলো?',
        'এ মাসে মোট খরচ কত?',
        'আমার আয় কত হলো?',
        'এই মাসে কত টাকা আয় হয়েছে?',
        'খরচ কত হয়েছে এখন পর্যন্ত?',
        'এ মাসে কত সঞ্চয় হলো?',
        'আমার ইনকাম কত?',
        'মাসে কত খরচ করলাম?',
        'এখন পর্যন্ত কত আয় হলো?',
        'চলতি মাসে খরচ কত দাঁড়াল?',
      ], (s, c) {
        expect(c, anyOf(isA<CashQuery>(), isA<ProfileQuery>()), reason: s);
      });
    });
  });

  group('রিমাইন্ডার ও অ্যালার্ম', () {
    test('a reminder at a time', () {
      each([
        'কাল সকাল ১০টায় মিটিংয়ের কথা মনে করিয়ে দিও',
        'কাল সকাল দশটায় মিটিংয়ের রিমাইন্ডার দাও',
        'রাত ৯টায় ওষুধ খাওয়ার কথা মনে করাবে',
        '৩০ মিনিট পরে চা খাওয়ার কথা বলো',
        'পরশু বিকেল ৪টায় ব্যাংকে যাওয়ার কথা মনে করিয়ে দিও',
        'আজ সন্ধ্যা ৭টায় আম্মুকে ফোন করার রিমাইন্ডার দাও',
        'প্রতিদিন রাত ১০টায় ওষুধ খাওয়ার কথা মনে করাও',
        'শুক্রবার সকাল ৯টায় জুম্মার কথা মনে করিয়ে দিও',
        'এক ঘণ্টা পরে গ্যাস বন্ধ করার কথা মনে করাবা',
        'kal sokal 8tay office er kotha mone koriye dio',
      ], (s, c) {
        expect(c, isA<ReminderAdd>(), reason: s);
        expect((c as ReminderAdd).needsTime, isFalse, reason: s);
        expect(c.alarm, isFalse, reason: s);
      });
    });

    test('an alarm', () {
      each([
        'কাল ভোর ৫টায় অ্যালার্ম দাও',
        '৬টায় ঘুম থেকে ডেকে দিও',
        'এলার্ম সেট করো ৭টা ৩০',
        'সকাল সাড়ে ছয়টায় এলার্ম দিয়ে রাখো',
        'প্রতিদিন ভোর ৪টা ৩০ এ নামাজের অ্যালার্ম দাও',
        'কাল সকাল ৮টায় জাগিয়ে দিও',
        'রাত ১২টায় একটা এলার্ম লাগাও',
        'ভোর ৫টায় এলার্ম দিও',
        'কাল ৬টায় অ্যালার্ম দিয়ে দাও',
        'সকাল ৭টায় এলার্ম বাজাবে',
      ], (s, c) {
        expect(c, isA<ReminderAdd>(), reason: s);
        expect((c as ReminderAdd).alarm || c.title == 'ঘুম থেকে ওঠা', isTrue, reason: s);
      });
    });

    test('the title is the thing, not "মিটিংয়ের"', () {
      expect((one('কাল সকাল দশটায় মিটিংয়ের রিমাইন্ডার দাও') as ReminderAdd).title, 'মিটিং');
    });

    test('stop, and do not stop', () {
      final d = AppData(reminders: [Reminder(title: 'মিটিং', date: DateTime(2026, 10, 10), hour: 10)]);
      final stop = parseAll('মিটিংয়ের রিমাইন্ডার বন্ধ করো', d.ledger, now: now).single;
      expect(stop, isA<ManageItem>());
      expect((stop as ManageItem).action, 'stop');
      for (final s in ['রিমাইন্ডার বন্ধ কোরো না', 'মিটিংয়ের রিমাইন্ডার বন্ধ করবে না', 'অ্যালার্মটা বন্ধ কোরোনা']) {
        expect(parseAll(s, d.ledger, now: now).single, isA<SmallTalk>(), reason: s);
      }
    });
  });

  group('কাজের তালিকা', () {
    test('adding a to-do', () {
      each([
        'কাল ব্যাংকে যেতে হবে',
        'বাজারের লিস্টে ডিম রাখো',
        'কাজের তালিকায় রাখো গাড়ি সার্ভিসিং',
        'আমি কাল বাজারে যাবো',
        'পরশু ডাক্তারের অ্যাপয়েন্টমেন্ট আছে',
        'আজ বিকেলে কাপড় আনতে হবে',
        'শুক্রবার মায়ের ওষুধ কিনতে হবে',
        'কাজের লিস্টে যোগ করো পানির বিল দেওয়া',
        'কাল অফিসে রিপোর্ট পাঠানো লাগবে',
        'আগামীকাল চাচার বাসায় যাবো',
      ], (s, c) {
        // "শুক্রবার …" said on a Friday: today or next Friday is asked.
        expect(c, anyOf(isA<TaskAdd>(), isA<ReminderAdd>(), predicate((x) => x is Clarify && x.options.every((o) => o.$2 is TaskAdd))), reason: s);
      });
    });

    test('done, and not done — opposites', () {
      for (final s in ['রিপোর্ট জমা দেওয়ার কাজটা শেষ হয়েছে', 'বিদ্যুৎ বিল দেওয়া হয়ে গেছে', 'রিপোর্ট জমা দিয়ে দিয়েছি']) {
        final c = one(s);
        expect(c, isA<TaskDone>(), reason: s);
        expect((c as TaskDone).done, isTrue, reason: s);
      }
      for (final s in ['রিপোর্ট জমা দেওয়ার কাজটা এখনো শেষ হয়নি', 'বিদ্যুৎ বিল দেওয়া হয়নি', 'ডাক্তার দেখানো এখনো হয়নি']) {
        final c = one(s);
        expect(c, isA<TaskDone>(), reason: s);
        expect((c as TaskDone).done, isFalse, reason: s);
      }
    });

    test('asking what is to do', () {
      each([
        'আজ আমার কী কী কাজ আছে?',
        'কাজের তালিকা দেখাও',
        'আজকে কী করতে হবে?',
        'বাকি কাজগুলো বলো',
        'আজকের কাজের লিস্ট দাও',
        'আমার টু ডু লিস্ট দেখাও',
        'আজ কী কী আছে?',
        'কালকে কী কাজ আছে?',
        'আমার কাজগুলো কী কী?',
        'আজকের দিনের পরিকল্পনা কী?',
      ], (s, c) {
        expect(c, anyOf(isA<TaskQuery>(), isA<Briefing>(), isA<ProfileQuery>()), reason: s);
      });
    });
  });

  group('ফোন, মেসেজ আর নম্বর', () {
    test('call or message someone', () {
      each([
        'রহিমকে ফোন দাও',
        'সাবিনাকে কল করো',
        'রহিমকে মেসেজ দাও যে আমি আসছি',
        'সাবিনাকে হোয়াটসঅ্যাপে লেখো আজ দেরি হবে',
        'রহিম ভাইকে একটা ফোন দাও তো',
        'আম্মুকে ফোন লাগাও',
        '০১৭১২৩৪৫৬৭৮ নম্বরে ফোন দাও',
        'সাবিনাকে এসএমএস পাঠাও কাল মিটিং',
        'rahim ke phone dao',
        'রহিমকে whatsapp এ মেসেজ দাও ঠিক আছে',
      ], (s, c) {
        expect(c, isA<CallPerson>(), reason: s);
      });
    });

    test('keep a number', () {
      each([
        'রহিমের নম্বর ০১৭১২৩৪৫৬৭৮',
        'সাবিনার নতুন নাম্বার 01812345678',
        'ইলেকট্রিশিয়ানের নম্বর ০১৯১১২২৩৩৪৪',
        'ডাক্তার সাহেবের মোবাইল ০১৬১১২২৩৩৪৪',
        'রুবেলের ফোন নম্বর ০১৫১১২২৩৩৪৪',
        'বাড়িওয়ালার নম্বর রাখো ০১৭৯৯৮৮৭৭৬৬',
        'নাসিরের নং ০১৮৮৮৭৭৬৬৫৫',
        'মিস্ত্রির নম্বর ০১৩১১২২৩৩৪৪',
        'অফিসের নম্বর 01711223344',
        'জামালের নাম্বার হলো ০১৯৯৯৮৮৮৭৭৭',
      ], (s, c) {
        expect(c, isA<ContactAdd>(), reason: s);
      });
    });
  });

  group('changing and removing things', () {
    test('delete — and "do not delete"', () {
      for (final s in ['রহিমের ৫০০ টাকার লেনদেনটা মুছে দাও', 'শেষটা মুছে দাও', 'মিটিংয়ের রিমাইন্ডারটা ডিলিট করো', 'নোটটা মুছে ফেলো']) {
        final c = one(s);
        expect(c, isA<ManageItem>(), reason: s);
        expect((c as ManageItem).action, 'delete', reason: s);
      }
      for (final s in ['এটা মুছে দিও না', 'রহিমের লেনদেন মুছে দিও না', 'নোটটা ডিলিট কোরো না', 'শেষটা মুছবে না', 'ওটা মুছোনা']) {
        expect(one(s), isA<SmallTalk>(), reason: s);
        expect((one(s) as SmallTalk).kind, Talk.wontDo, reason: s);
      }
    });

    test('a negative earlier in the sentence does not cancel the request', () {
      final c = one('দেরি কোরো না, কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও');
      expect(c, isA<ReminderAdd>());
    });

    test('a change of mind mid-sentence: the later value counts', () {
      final a = one('রহিমকে পাঁচশ টাকা, না সাতশ টাকা ধার দিলাম') as LedgerAdd;
      expect((a.person, a.amount, a.kind), ('রহিম', 700, LedgerKind.lent));
      expect((one('সজীবকে ৫০০ না ৮০০ টাকা ধার দিয়েছি') as LedgerAdd).amount, 800);
      expect((one('বাজারে দুই হাজার, না না, আড়াই হাজার টাকা খরচ হলো') as CashAdd).amount, 2500);
      final r = one('কাল সকাল দশটায়, না এগারোটায় মিটিং মনে করিয়ে দিও') as ReminderAdd;
      expect(r.at.hour, 11);
      // Changing something already saved stays a change.
      expect(one('রহিমের লেনদেন ৫০০ না ৬০০'), isA<ManageItem>());
    });
  });

  group('the meaning helpers', () {
    test('owed to me, or owed by me', () {
      expect(owedToMe(normalize('কে আমার কাছে টাকা পাবে')), isFalse);
      expect(owedToMe(normalize('আমি কার কাছে টাকা পাবো')), isTrue);
      expect(owedToMe(normalize('রহিম আমাকে কত দেবে')), isTrue);
      expect(owedToMe(normalize('আমাকে কত দিতে হবে')), isFalse);
    });

    test('negatives belong to a request only at its end', () {
      expect(negatedRequest(normalize('মুছে দিও না')), isTrue);
      expect(negatedRequest(normalize('আমি জানি না')), isFalse);
      expect(negatedRequest(normalize('দেরি কোরো না কাল ১০টায় মনে করিয়ে দিও')), isFalse);
    });

    test('pronouns', () {
      expect(pronounRole('ও', first: true), PronounRole.doer);
      expect(pronounRole('ও', first: false), isNull, reason: '"আমি ও তুমি": "and"');
      expect(pronounRole('ওকে', first: false), PronounRole.to);
      expect(pronounRole('ওর', first: false), PronounRole.of);
    });

    test('totals', () {
      for (final s in ['এখন মোট কত?', 'সব মিলিয়ে কত হলো?', 'টোটাল কত?', 'মোট কত দাঁড়াল?']) {
        expect(asksTotal(normalize(s)), isTrue, reason: s);
      }
      expect(asksTotal(normalize('রহিমকে ৫০০ টাকা দিলাম')), isFalse);
    });
  });
}
