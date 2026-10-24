// The 20-person walk (23 Oct): what the rules got wrong, replayed. Each case
// failed before its fix; the fixes are in shared layers, not per sentence.
import 'package:digital_brain/logic/answers.dart' show answerText;
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/logic/plan.dart';
import 'package:digital_brain/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 9, 15, 53);
  List<Command> read(String s, {List<LedgerEntry> ledger = const [], List<Project> projects = const []}) =>
      parseAll(s, ledger, now: now, data: AppData(ledger: ledger, projects: projects));
  Command one(String s, {List<LedgerEntry> ledger = const [], List<Project> projects = const []}) {
    final c = read(s, ledger: ledger, projects: projects);
    expect(c, hasLength(1), reason: s);
    return c.single;
  }

  group('money that came is income, not a loan', () {
    for (final s in ['টিউশনি থেকে তিন হাজার টাকা পেলাম', 'ফাইভার থেকে বিশ হাজার টাকা পেলাম', 'অফিস থেকে বোনাস পেলাম পাঁচ হাজার টাকা']) {
      test(s, () {
        final c = one(s);
        expect(c, isA<CashAdd>(), reason: s);
        expect((c as CashAdd).kind, CashKind.income);
      });
    }
    test('from someone who owes me: paid back (as before)', () {
      final ledger = [LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 1000, date: DateTime(2026, 10, 1))];
      final c = one('রহিমের কাছ থেকে পাঁচশো টাকা পেলাম', ledger: ledger);
      expect(c, isA<LedgerAdd>());
    });
    test('a loan is still a loan', () {
      final c = one('রহিমা আপার কাছ থেকে এক হাজার টাকা ধার নিলাম') as LedgerAdd;
      expect((c.kind, c.amount), (LedgerKind.borrowed, 1000));
    });
  });

  group('own earning and spending without a person', () {
    final cases = {
      'আজ কামাই হইছে সাতশো টাকা': (CashKind.income, 700),
      'চা নাস্তায় পঞ্চাশ টাকা গেল': (CashKind.expense, 50),
      'আম্মু টিফিনের জন্য একশো টাকা দিলো': (CashKind.income, 100),
      'রিকশা ভাড়া চল্লিশ টাকা লাগলো': (CashKind.expense, 40),
    };
    cases.forEach((s, want) => test(s, () {
          final c = one(s);
          expect(c, isA<CashAdd>(), reason: s);
          expect(((c as CashAdd).kind, c.amount), want);
        }));
  });

  test('a count of days is not the amount; চোদ্দ is 14', () {
    final c = one('মালিকের কাছে দুই দিনের মজুরি চোদ্দশো টাকা পাবো');
    expect(c, isA<LedgerSet>());
    expect((c as LedgerSet).balance, 1400);
    expect(findAmount(normalize('চৌদ্দশো টাকা')), 1400);
  });

  group('অন্যান্য হিসাব', () {
    final projects = [Project(name: 'রহিম ভবন'), Project(name: 'বোরো ধান'), Project(name: 'দোকান')];
    test('money given to me in a project is in; paying the mason is out', () {
      expect((one('রহিম ভবন প্রজেক্টে মালিক পাঁচ লাখ টাকা দিলো', projects: projects) as CashAdd).kind, CashKind.income);
      final pay = one('রহিম ভবনে মিস্ত্রিকে বারো হাজার টাকা দিলাম', projects: projects) as CashAdd;
      expect((pay.kind, pay.project), (CashKind.expense, 'রহিম ভবন'));
    });
    test('an open project named with হিসাবে / -এ gets the entry; a sale is income', () {
      final sale = one('বোরো ধান হিসাবে ধান বিক্রি চল্লিশ হাজার টাকা', projects: projects) as CashAdd;
      expect((sale.kind, sale.amount, sale.project), (CashKind.income, 40000, 'বোরো ধান'));
      final fert = one('বোরো ধান হিসাবে সার কিনলাম আড়াই হাজার টাকা', projects: projects) as CashAdd;
      expect((fert.kind, fert.project), (CashKind.expense, 'বোরো ধান'));
      final shop = one('দোকানে আজ বিক্রি হলো বারো হাজার টাকা', projects: projects) as CashAdd;
      expect((shop.kind, shop.project), (CashKind.income, 'দোকান'));
    });
    test('without such a project, a sale stays the user\'s own income', () {
      final c = one('দোকানে আজ বিক্রি হলো বারো হাজার টাকা') as CashAdd;
      expect((c.kind, c.project), (CashKind.income, null));
    });
  });

  test('"থেকে" is never a name (a word ending in কে is not always "to")', () {
    final c = one('করিম দোকান থেকে পাঁচশো টাকার বাকি নিলো') as LedgerAdd;
    expect((c.person, c.amount, c.kind), ('করিম', 500, LedgerKind.lent));
  });

  test('a loan given with a pay-back time is a loan', () {
    final c = one('ভাইকে দোকানের জন্য পঞ্চাশ হাজার টাকা ধার দিলাম ফেরত দেবে ডিসেম্বরে');
    expect(c, isA<LedgerAdd>());
    expect(((c as LedgerAdd).person, c.amount, c.kind), ('ভাই', 50000, LedgerKind.lent));
  });

  test('two times for one thing: one reminder each, both every day, same words', () {
    final cs = read('প্রতিদিন সকাল আটটা আর রাত আটটায় ইনসুলিন নেওয়ার কথা মনে করাবে');
    expect(cs, hasLength(2));
    for (final c in cs) {
      expect(c, isA<ReminderAdd>());
      expect((c as ReminderAdd).repeat, Repeat.daily);
      expect(c.title, contains('ইনসুলিন'));
    }
    expect({for (final c in cs) (c as ReminderAdd).at.hour}, {8, 20});
  });

  group('a reminder\'s name keeps no time words', () {
    final cases = {'পরশু সকাল দশটায় ফিজিক্স পরীক্ষা': 'ফিজিক্স পরীক্ষা', 'আগামী রবিবার বিকেল তিনটায় ব্রাঞ্চ মিটিং': 'ব্রাঞ্চ মিটিং'};
    cases.forEach((s, title) => test(s, () {
          final c = one(s) as ReminderAdd;
          expect(c.title, title);
        }));
  });

  group('giving blood', () {
    test('the day given is kept (in the past), never a to-do', () {
      final c = one('শেষ রক্ত দিয়েছি দশ আগস্ট') as ProfileSet;
      expect((c.field, DateTime.parse(c.value)), ('blood_last', DateTime(2026, 8, 10)));
      expect(DateTime.parse((one('গত মাসের ৫ তারিখে রক্ত দিলাম') as ProfileSet).value), DateTime(2026, 9, 5));
    });
    test('"রক্ত লাগবে" opens the requests page; "কবে দিতে পারব" is a question', () {
      expect((one('রক্ত লাগবে') as OpenPlace).place, 'requests');
      expect(one('আবার কবে রক্ত দিতে পারব'), isA<ProfileQuery>());
    });
  });

  test('"মেয়ের জন্মদিন" is মেয়ে\'s (not the month মে)', () {
    expect(stripPossessive('মেয়ের'), 'মেয়ে');
    expect(stripPossessive('ভাইয়ের'), 'ভাই');
    expect(one('মেয়ের জন্মদিন বিশে ডিসেম্বর'), isA<SpecialAdd>());
  });

  test('a week or a month asked: what is on then', () {
    expect(one('এই সপ্তাহে কী কী আছে'), isA<TaskQuery>());
    expect(one('এই মাসে কী কী দিন আছে'), isA<TaskQuery>());
  });

  test('a PIN asked is a secret, never an account balance', () {
    expect(one('আমার ব্যাংকের পিন কত'), isNot(isA<MenuAction>()));
  });

  test('"নোট রাখো …" first: a note', () {
    final c = one('নোট রাখো ক্লায়েন্ট রফিক সাহেব লোনের কাগজ বৃহস্পতিবার দেবেন') as NoteAdd;
    expect(c.text, startsWith('ক্লায়েন্ট রফিক'));
  });

  test('the clock time is not in a to-do\'s name', () {
    final c = one('ডাক্তার দেখানো আছে ১৫ তারিখ বিকেল ৫টায়');
    expect(c is TaskAdd ? c.title : (c as ReminderAdd).title, 'ডাক্তার দেখানো');
  });

  // ── The second 20 (personas 21–40, with the phone model) ──

  group('numbers 21–99 said as words; নয় only before a multiplier', () {
    final cases = {'আঠাশ হাজার': 28000, 'পঁয়ত্রিশ হাজার টাকা': 35000, 'নয়শো টাকা': 900, 'নয় হাজার টাকা': 9000, 'সাতাশ টাকা': 27, 'নিরানব্বই টাকা': 99, 'বাহান্ন হাজার পাঁচশো': 52500};
    cases.forEach((s, n) => test(s, () => expect(findAmount(normalize(s)), n)));
    test('"নয়" alone is "not"', () => expect(findAmount(normalize('এটা আমার নয়')), isNull));
  });

  test('a question never marks a to-do done', () {
    final tasks = [Task(title: 'পাসপোর্টের মেয়াদ শেষ হবে মার্চ দুই হাজার সাতাশ')];
    final c = parseAll('পাসপোর্টের মেয়াদ কবে শেষ', const [], tasks: tasks, now: now, data: AppData(tasks: tasks));
    expect(c.whereType<TaskDone>(), isEmpty);
    // Said as done, it still is.
    expect(parseAll('পাসপোর্টের কাজ শেষ', const [], tasks: tasks, now: now, data: AppData(tasks: tasks)).single, isA<TaskDone>());
  });

  group('money in and out, said plainly', () {
    final cases = {
      'পেনশন পেলাম আঠাশ হাজার টাকা': (CashKind.income, 28000, 'পেনশন'),
      'আজ ধান কাটার মজুরি পেলাম ছয়শো টাকা': (CashKind.income, 600, 'কাজের আয়'),
      'বাইকের তেল তিনশো টাকা': (CashKind.expense, 300, 'যাতায়াত'),
      'রুবিনা আপা অগ্রিম তিনশো টাকা দিলেন': (CashKind.income, 300, null),
    };
    cases.forEach((s, want) => test(s, () {
          final c = one(s);
          expect(c, isA<CashAdd>(), reason: s);
          c as CashAdd;
          expect((c.kind, c.amount), (want.$1, want.$2));
          if (want.$3 != null) expect(c.category, want.$3);
        }));
    test('the mason is still paid out (মজুরি দিলাম)', () {
      expect((one('মিস্ত্রির মজুরি দিলাম পাঁচশো টাকা') as CashAdd).kind, CashKind.expense);
    });
  });

  test('rent not paid yet: nothing is written', () {
    expect(one('তিনতলার ভাড়া এখনো দেয়নি'), isA<SmallTalk>());
  });

  group('own money of a time, asked', () {
    for (final q in ['আজ কত থাকল', 'এই সপ্তাহে কত কামাই হলো', 'এই মাসে ভাড়া কত পেলাম']) {
      test(q, () => expect(one(q), isA<CashQuery>()));
    }
    test('someone named: still the লেনদেন book', () {
      final ledger = [LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 1000, date: DateTime(2026, 10, 1))];
      expect(one('রহিমের কাছে কত পাবো', ledger: ledger), isNot(isA<CashQuery>()));
    });
    test('the answer: that time, in or left, and one খাত', () {
      final d = AppData(cash: [
        CashEntry(kind: CashKind.income, amount: 8000, category: 'ভাড়া আয়', date: DateTime(2026, 10, 1)),
        CashEntry(kind: CashKind.income, amount: 700, category: 'কাজের আয়', date: DateTime(2026, 10, 9, 9)),
        CashEntry(kind: CashKind.expense, amount: 200, category: 'খাবার', date: DateTime(2026, 10, 9, 10)),
      ]);
      String say(String q) => answerText(d, one(q), now)!;
      expect(say('আজ কত থাকল'), allOf(contains('৭০০'), contains('৫০০')));
      expect(say('এই মাসে ভাড়া কত পেলাম'), allOf(contains('ভাড়া আয়'), contains('৮,০০০')));
      expect(say('এই সপ্তাহে কত কামাই হলো'), contains('আয় ৭০০'));
    });
  });

  group('a project asked about', () {
    final projects = [Project(name: 'শাড়ির ব্যবসা'), Project(name: 'মসজিদ ফান্ড')];
    for (final q in ['মসজিদ ফান্ডে কত আছে', 'শাড়ির ব্যবসায় কত লাভ হলো']) {
      test(q, () {
        final c = one(q, projects: projects);
        expect(c, isA<CashQuery>(), reason: '$c');
        expect((c as CashQuery).project, isNotNull);
      });
    }
    test('paying the cook in the hotel is spending', () {
      final c = one('হোটেলে বাবুর্চিকে সাপ্তাহিক বেতন তিন হাজার টাকা দিলাম', projects: [Project(name: 'হোটেল')]) as CashAdd;
      expect((c.kind, c.project), (CashKind.expense, 'হোটেল'));
    });
  });

  test('every two hours: a repeat of its own, the time words not in the name', () {
    final c = one('প্রতি দুই ঘণ্টা পর পানি খাওয়ার কথা মনে করাবে') as ReminderAdd;
    expect((c.repeat, c.title), (Repeat.every2h, 'পানি খাওয়ার কথা'));
    expect((one('তিন ঘণ্টা পর পর ওষুধ খাওয়ার কথা মনে করিয়ে দিও') as ReminderAdd).repeat, Repeat.every3h);
    expect(Repeat.parse('every2h'), Repeat.every2h);
  });

  test('"ছেলের ওজন": the member is ছেলে, not ছেল', () {
    final c = one('ছেলের ওজন পাঁচ কেজি') as MenuAction;
    expect(c.target, 'ছেলে');
  });

  test('"ছেলের টিকা কবে": the to-do about the vaccine, not the son\'s birthday', () {
    final d = AppData(
      tasks: [Task(title: 'ছেলের টিকা দেওয়া', due: DateTime(2026, 10, 20))],
      reminders: [Reminder(title: 'ছেলের জন্মদিন', date: DateTime(2027, 8, 10), hour: 9, minute: 0, repeat: Repeat.yearly)],
    );
    final c = parseAll('ছেলের টিকা কবে', const [], tasks: d.tasks, now: now, data: d).single;
    final say = answerText(d, c, now)!;
    expect(say, contains('টিকা'));
    expect(say, isNot(contains('জন্মদিন')));
  });

  test('rent from a tenant is ভাড়া আয়, and "ভাড়া কত পেলাম" finds it', () {
    final c = one('দোতলার ভাড়াটিয়া জসিম সাহেব এই মাসের ভাড়া বারো হাজার টাকা দিলেন') as CashAdd;
    expect((c.kind, c.category), (CashKind.income, 'ভাড়া আয়'));
    final d = AppData(cash: [CashEntry(kind: c.kind, amount: c.amount, category: c.category, date: now)]);
    expect(answerText(d, one('এই মাসে ভাড়া কত পেলাম'), now), contains('১২,০০০'));
  });

  test('"পাসপোর্টের মেয়াদ কবে শেষ": no paper kept, but the to-do about it is said', () {
    final d = AppData(tasks: [Task(title: 'পাসপোর্টের মেয়াদ শেষ হবে মার্চ দুই হাজার সাতাশ')]);
    final c = parseAll('পাসপোর্টের মেয়াদ কবে শেষ', const [], tasks: d.tasks, now: now, data: d).single;
    expect(answerText(d, c, now), contains('মার্চ দুই হাজার সাতাশ'));
  });

  test('"বুধবার কী কী ডেলিভারি": that day\'s to-dos', () {
    final d = AppData(tasks: [Task(title: 'রুবিনা আপার ব্লাউজ ডেলিভারি দেওয়া', due: DateTime(2026, 10, 14))]);
    final c = parseAll('বুধবার কী কী ডেলিভারি', const [], tasks: d.tasks, now: now, data: d).single;
    expect(c, isA<TaskQuery>());
    expect(answerText(d, c, now), contains('ব্লাউজ'));
  });

  // ── The 2000-user crowd (tool/nlu/crowd): asides, regions, plain money ──
  group('the crowd', () {
    test('asides around a request are not the request', () {
      expect(one('ও হ্যাঁ, রহিমকে ৫০০ টাকা ধার দিলাম ভুল করবা না'), isA<LedgerAdd>());
      expect(one('স্বাস্থ্য খুলো মনে করে ভাই'), isA<OpenPlace>());
      expect(one('আমার প্রেশার কেমন'), isNot(isA<HealthAdd>()), reason: '"কেমন" there is the question itself');
    });
    test('the regions\' verbs', () {
      expect(one('দয়া করে এখনই মিঠুকে কল গর'), isA<CallPerson>());
      expect(one('এ মাসের খরচের হিসাব দেও'), isA<CashQuery>());
      expect((one('পেনশন তোলার কথা পরশু সকাল দশটায় মনে করাইয়া দিবা') as ReminderAdd).at.hour, 10);
      expect(one('কাল সকাল ৮টায় ওষুধ খাওয়ার কথা মনে করে দিও'), isA<ReminderAdd>());
      expect((one('ডেইলি রাত ১০টায় প্রেশারের ওষুধ নেওয়ার রিমাইন্ডার দাও') as ReminderAdd).repeat, Repeat.daily);
    });
    test('a loan someone gave is borrowed', () {
      final c = one('আবির মামা ৩৫ হাজার টাকা কর্জ দিছে') as LedgerAdd;
      expect((c.person, c.kind), ('আবির', LedgerKind.borrowed));
    });
    test('money without the word টাকা; money that came in', () {
      expect((one('১২০০ দিয়ে টায়ার সারাই করালাম') as CashAdd).kind, CashKind.expense);
      expect((one('১২০০ দিয়ে টায়ার সারাই করালাম') as CashAdd).category, isNot('কৃষি'));
      expect((one('আজ আপওয়ার্কের পেমেন্ট বাবদ ৬৫৫০০ টাকা পেয়েছি') as CashAdd).kind, CashKind.income);
      expect((one('আজ ফাইভারের পেমেন্ট হলো ৯৬৫০০ টাকা') as CashAdd).kind, CashKind.income);
      expect((one('আজ খাবার ২৮০০০ লাগলো') as CashAdd).kind, CashKind.expense);
      expect((one('বিদ্যুৎ বিল এসেছে ১২০০ টাকা') as CashAdd).kind, CashKind.expense);
    });
    test('a yearly day in any order; a list stays a list', () {
      expect(one('১৮ সেপ্টেম্বর আমার বিয়ের দিন'), isA<SpecialAdd>());
      expect(one('এ মাসে মোট কত গেল'), isA<CashQuery>());
    });
  });
}
