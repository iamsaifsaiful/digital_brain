import 'package:digital_brain/logic/ai_map.dart';
import 'package:digital_brain/logic/answers.dart';
import 'package:digital_brain/logic/bn.dart';
import 'package:digital_brain/logic/cash.dart';
import 'package:digital_brain/logic/categories.dart';
import 'package:digital_brain/logic/csv.dart';
import 'package:digital_brain/logic/ledger.dart';
import 'package:digital_brain/logic/match.dart';
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/logic/password.dart';
import 'package:digital_brain/logic/phrases.dart';
import 'package:digital_brain/logic/plan.dart';
import 'package:digital_brain/logic/when.dart';
import 'package:digital_brain/logic/search.dart';
import 'package:digital_brain/logic/talk.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/launcher.dart';
import 'package:digital_brain/services/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

LedgerEntry e(String p, LedgerKind k, int a, DateTime d) => LedgerEntry(person: p, kind: k, amount: a, date: d);

void main() {
  group('Bengali numbers', () {
    test('digits and lakh grouping', () {
      expect(bnDigits(1050), '১০৫০');
      expect(groupLakh(100000), '1,00,000');
      expect(groupLakh(12345678), '1,23,45,678');
      expect(taka(1050), '৳১,০৫০');
      expect(taka(-200), '৳২০০');
      expect(asciiDigits('১,০০০'), '1,000');
    });

    test('amounts in sentences', () {
      expect(findAmount(normalize('সজীবকে ৫০০ টাকা দিলাম')), 500);
      expect(findAmount(normalize('১,০০০ টাকা')), 1000);
      expect(findAmount(normalize('২ হাজার টাকা')), 2000);
      expect(findAmount(normalize('দেড় হাজার টাকা')), 1500);
      expect(findAmount(normalize('পাঁচশো টাকা')), 500);
      expect(findAmount(normalize('৳750 দিলাম')), 750);
      expect(findAmount(normalize('কোনো টাকা নেই')), isNull);
    });
  });

  group('Ledger', () {
    final d = DateTime(2026, 10, 1);
    final entries = [
      e('সজীব', LedgerKind.lent, 1000, DateTime(2026, 9, 15)),
      e('সজীব', LedgerKind.received, 1000, DateTime(2026, 9, 25)),
      e('সজীব', LedgerKind.lent, 500, DateTime(2026, 10, 2)),
      e('সজীব', LedgerKind.received, 300, DateTime(2026, 10, 8)),
      e('রহিম', LedgerKind.borrowed, 1000, d),
      e('নাসরিন', LedgerKind.lent, 1500, d),
      e('মামুন', LedgerKind.borrowed, 450, d),
      e('তানভীর', LedgerKind.lent, 800, d),
    ];

    test('balances per person', () {
      expect(balanceWith(entries, 'সজীব'), 200);
      expect(balanceWith(entries, ' সজীব '), 200);
      expect(balanceWith(entries, 'রহিম'), -1000);
      expect(balanceWith(entries, 'কেউ না'), 0);
      final s = balanceOf(entries, 'সজীব')!;
      expect(s.lentTotal, 1500);
      expect(s.receivedTotal, 1300);
      expect(s.count, 4);
    });

    test('totals match the design numbers', () {
      final t = totals(entries);
      expect(t.receivable, 2500);
      expect(t.payable, 1450);
      expect(t.net, 1050);
      expect(t.owingPeople, 3);
      expect(t.owedPeople, 2);
    });

    test('running balance', () {
      final r = runningFor(entries, 'সজীব').map((x) => x.$2).toList();
      expect(r, [1000, 0, 500, 200]);
    });

    test('repaying reduces what I owe', () {
      expect(balanceAfter(entries, 'রহিম', LedgerKind.repaid, 500), -500);
    });

    test('same name, different numbers: two accounts', () {
      final l = [
        LedgerEntry(person: 'রহিম', phone: '01712345678', kind: LedgerKind.lent, amount: 4000, date: DateTime(2026, 10, 1)),
        LedgerEntry(person: 'রহিম', phone: '+8801819876543', kind: LedgerKind.borrowed, amount: 3000, date: DateTime(2026, 10, 2)),
      ];
      expect(balances(l), hasLength(2));
      expect(peopleNamed(l, 'রহিম'), hasLength(2));
      expect(balanceWith(l, 'রহিম', phone: '০১৭১২৩৪৫৬৭৮'), 4000);
      expect(balanceWith(l, 'রহিম', phone: '01819876543'), -3000);
      // Without a number: the most recent রহিম.
      expect(balanceWith(l, 'রহিম'), -3000);
      // An old name-only entry joins the only numbered রহিম.
      final one = [
        LedgerEntry(person: 'করিম', kind: LedgerKind.lent, amount: 100, date: DateTime(2026, 9, 1)),
        LedgerEntry(person: 'করিম', phone: '01711223344', kind: LedgerKind.lent, amount: 200, date: DateTime(2026, 10, 1)),
      ];
      expect(balances(one).single.balance, 300);
      expect(showPhone('01711223344'), '০১৭১১-২২৩৩৪৪');
    });

    test('csv has every entry and no password', () {
      final csv = ledgerCsv(entries);
      expect(csv.split('\n').where((l) => l.contains('সজীব')).length, greaterThanOrEqualTo(4));
      expect(csv.startsWith('﻿'), isTrue);
    });
  });

  group('Parser: money events', () {
    final rahim = [e('রহিম', LedgerKind.borrowed, 1000, DateTime(2026, 10, 5))];
    final sajib = [e('সজীব', LedgerKind.lent, 500, DateTime(2026, 10, 2))];

    test('I gave → loan', () {
      final c = Parser(ledger: const []).parse('আমি সজীবকে ৫০০ টাকা দিলাম।') as LedgerAdd;
      expect(c.person, 'সজীব');
      expect(c.amount, 500);
      expect(c.kind, LedgerKind.lent);
    });

    test('they paid me back', () {
      final c = Parser(ledger: sajib).parse('সজীব আমাকে ৩০০ টাকা ফেরত দিয়েছে') as LedgerAdd;
      expect(c.person, 'সজীব');
      expect(c.amount, 300);
      expect(c.kind, LedgerKind.received);
    });

    test('I borrowed', () {
      final c = Parser(ledger: const []).parse('রহিমের কাছ থেকে ১,০০০ টাকা ধার নিয়েছি') as LedgerAdd;
      expect(c.person, 'রহিম');
      expect(c.amount, 1000);
      expect(c.kind, LedgerKind.borrowed);
    });

    test('giving to someone I owe is unclear: ask', () {
      final c = Parser(ledger: rahim).parse('রহিমকে ৫০০ টাকা দিলাম') as LedgerAdd;
      expect(c.needsChoice, isTrue);
      expect(c.options, contains(LedgerKind.repaid));
      expect(c.options, contains(LedgerKind.lent));
      expect(c.suggested, LedgerKind.repaid);
      expect(c.allowExpense, isTrue);
    });

    test('they gave me money with no hint: ask', () {
      final c = Parser(ledger: sajib).parse('সজীব আমাকে ২০০ টাকা দিল') as LedgerAdd;
      expect(c.needsChoice, isTrue);
      expect(c.suggested, LedgerKind.received);
    });

    test('paying back', () {
      final c = Parser(ledger: rahim).parse('রহিমকে ৫০০ টাকা শোধ করে দিলাম') as LedgerAdd;
      expect(c.kind, LedgerKind.repaid);
    });

    test('honorific stays with the name', () {
      final c = Parser(ledger: const []).parse('সজীব ভাইকে ২ হাজার টাকা ধার দিলাম') as LedgerAdd;
      expect(c.person, 'সজীব ভাই');
      expect(c.amount, 2000);
    });
  });

  group('Parser: questions and other things', () {
    final ledger = [e('সজীব', LedgerKind.lent, 200, DateTime(2026, 10, 2))];

    test('balance with one person', () {
      final c = Parser(ledger: ledger).parse('সজীবের কাছে আমার কত টাকা পাওনা?') as LedgerQuery;
      expect(c.ask, LedgerAsk.person);
      expect(c.person, 'সজীব');
    });

    test('who owes me / whom I owe', () {
      expect((Parser(ledger: ledger).parse('আমি কার কাছে কত টাকা পাব?') as LedgerQuery).ask, LedgerAsk.receivable);
      expect((Parser(ledger: ledger).parse('কাকে কত টাকা দিতে হবে?') as LedgerQuery).ask, LedgerAsk.payable);
    });

    test('wifi and logins', () {
      final w = Parser(ledger: const []).parse('আমার Wi-Fi-এর নাম কী?') as VaultQuery;
      expect(w.wifiOnly, isTrue);
      final l = Parser(ledger: const []).parse('ABC ওয়েবসাইটের লগইন তথ্য দেখাও') as VaultQuery;
      expect(l.terms, ['abc']);
    });

    test('reminder question', () {
      final r = Parser(ledger: const []).parse('ডোমেইন রিনিউ করার তারিখটা মনে করিয়ে দাও') as ReminderQuery;
      expect(r.terms, containsAll(['ডোমেইন', 'রিনিউ']));
    });

    test('note', () {
      final n = Parser(ledger: const []).parse('মনে রাখো: গাড়ির কাগজ আলমারিতে') as NoteAdd;
      expect(n.text, 'গাড়ির কাগজ আলমারিতে');
    });

    test('anything else is a search', () {
      final s = Parser(ledger: const []).parse('ইলেকট্রিশিয়ান');
      expect(s, isA<SearchQuery>());
    });

    test('empty is not understood', () {
      expect(Parser(ledger: const []).parse('   '), isA<NotUnderstood>());
    });
  });

  group('Search', () {
    final data = AppData(
      vault: [
        VaultItem(name: 'ABC ওয়েবসাইট', kind: VaultKind.website, username: 'saif_admin', password: 'secret-abc'),
        VaultItem(name: 'বাসার Wi-Fi', kind: VaultKind.wifi, address: 'Home_Net_5G', password: 'x'),
      ],
      reminders: [Reminder(title: 'ডোমেইন রিনিউ', date: DateTime(2026, 10, 14))],
      contacts: [Contact(name: 'ইলেকট্রিশিয়ান করিম', phone: '01700000000')],
    );

    test('vault by name, never by password', () {
      expect(searchVault(data, ['abc']).single.name, 'ABC ওয়েবসাইট');
      expect(searchVault(data, ['secret']), isEmpty);
      expect(searchVault(data, const [], wifiOnly: true).single.kind, VaultKind.wifi);
    });

    test('reminders and everything', () {
      expect(searchReminders(data, ['ডোমেইন']).single.title, 'ডোমেইন রিনিউ');
      expect(searchAll(data, ['ইলেকট্রিশিয়ান']).first, isA<ContactHit>());
    });
  });

  group('Phrases', () {
    test('possessive and to-person endings', () {
      expect(possessive('সজীব'), 'সজীবের');
      expect(possessive('রনি'), 'রনির');
      expect(possessive('Rahim'), 'Rahim-এর');
      expect(toPerson('সজীব'), 'সজীবকে');
    });

    test('sentences from the idea', () {
      expect(confirmQuestion(LedgerKind.lent, 'সজীব', 500), 'আচ্ছা, সজীবকে ৫০০ টাকা ধার দিলেন, তাই তো? লিখে রাখি?');
      expect(savedSentence(LedgerKind.received, 'সজীব', 300, 200), 'ঠিক আছে, লিখে রাখলাম। এখন সজীবের কাছে আপনার ২০০ টাকা পাওনা আছে।');
      expect(balanceSentence('রহিম', -1000), 'এখন রহিমকে আপনার ১,০০০ টাকা দিতে হবে।');
    });
  });

  group('Reminders', () {
    test('yearly and monthly repeat to the next date', () {
      final now = DateTime(2026, 10, 9, 15);
      final y = Reminder(title: 'ডোমেইন', date: DateTime(2025, 10, 14), repeat: Repeat.yearly);
      expect(y.nextDate(now), DateTime(2026, 10, 14));
      final m = Reminder(title: 'বিল', date: DateTime(2026, 1, 31), repeat: Repeat.monthly);
      expect(m.nextDate(now), DateTime(2026, 10, 31));
      final once = Reminder(title: 'পুরনো', date: DateTime(2026, 9, 1));
      expect(once.nextDate(now), DateTime(2026, 9, 1));
    });

    test('a reminder rings on its own day; days-before only adds an early notice', () {
      final r = Reminder(title: 'ডোমেইন', date: DateTime(2026, 10, 14), daysBefore: 1, hour: 10);
      expect(r.notifyAt(DateTime(2026, 10, 9)), DateTime(2026, 10, 14, 10));
      expect(r.earlyAt(DateTime(2026, 10, 9)), DateTime(2026, 10, 13, 10));
      expect(r.earlyAt(DateTime(2026, 10, 13, 11)), isNull);
      // Today, later: it still rings today (the old form skipped these).
      final today = Reminder(title: 'মিটিং', date: DateTime(2026, 10, 9), hour: 16);
      expect(today.daysBefore, 0);
      expect(plannedNotices([today], DateTime(2026, 10, 9, 15)).single.at, DateTime(2026, 10, 9, 16));
    });

    test('a monthly reminder whose time passed today rings next month', () {
      final m = Reminder(title: 'ভাড়া', date: DateTime(2026, 9, 9), hour: 10, repeat: Repeat.monthly);
      expect(m.notifyAt(DateTime(2026, 10, 9, 15)), DateTime(2026, 11, 9, 10));
      final n = plannedNotices([m], DateTime(2026, 10, 9, 15)).single;
      expect(n.repeat, NoticeRepeat.monthly);
    });

    test('a notice carries its words, so a snooze rings with them', () {
      final i = NoticeInfo.parse(noticePayload('r1', 'ওষুধ', 'রাত ১০টা', false))!;
      expect(i.reminderId, 'r1');
      expect(i.title, 'ওষুধ');
      expect(NoticeInfo.parse('reminder:abc')!.reminderId, 'abc');
    });
  });

  group('Passwords', () {
    test('generated passwords are strong', () {
      for (var i = 0; i < 20; i++) {
        final p = generatePassword();
        expect(p.length, 16);
        expect(strengthOf(p), Strength.strong);
      }
      expect(strengthOf('1234'), Strength.weak);
    });
  });

  group('Data', () {
    test('json round trip', () {
      final d = AppData(
        ledger: [e('সজীব', LedgerKind.lent, 500, DateTime(2026, 10, 2))],
        vault: [VaultItem(name: 'ABC', password: 'p')],
        notes: [Note(title: 'নোট', body: 'লেখা')],
        reminders: [Reminder(title: 'ডোমেইন', date: DateTime(2026, 10, 14), repeat: Repeat.yearly)],
        contacts: [Contact(name: 'করিম')],
      );
      final back = AppData.fromJson(d.toJson());
      expect(back.ledger.single.amount, 500);
      expect(back.vault.single.password, 'p');
      expect(back.reminders.single.repeat, Repeat.yearly);
      expect(back.contacts.single.name, 'করিম');
      expect(back.notes.single.body, 'লেখা');
    });
  });

  group('Revision 1: stated balances, yes/no, statements', () {
    test('"ইসমাইলের কাছে আমি ৫ হাজার টাকা পাই" → he owes me 5000', () {
      final c = Parser(ledger: const []).parse('ইসমাইলের কাছে আমি ৫ হাজার টাকা পাই') as LedgerSet;
      expect(c.person, 'ইসমাইল');
      expect(c.balance, 5000);
    });

    test('I owe: two ways of saying it', () {
      final a = Parser(ledger: const []).parse('ইসমাইল আমার কাছে ২০০০ টাকা পায়') as LedgerSet;
      expect(a.person, 'ইসমাইল');
      expect(a.balance, -2000);
      final b = Parser(ledger: const []).parse('রহিমকে আমার ১০০০ টাকা দিতে হবে') as LedgerSet;
      expect(b.person, 'রহিম');
      expect(b.balance, -1000);
    });

    test('past events are still events, questions still questions', () {
      expect(Parser(ledger: const []).parse('আমি সজীবকে ৫০০ টাকা দিলাম'), isA<LedgerAdd>());
      expect(Parser(ledger: const []).parse('ইসমাইলের কাছে আমি কত টাকা পাই?'), isA<LedgerQuery>());
    });

    test('spoken yes / no', () {
      for (final y in ['হ্যাঁ', 'হ্যা', 'জি রাখো', 'ঠিক আছে', 'ok', 'আচ্ছা করো', 'হুম']) {
        expect(yesNo(y), isTrue, reason: y);
      }
      for (final n in ['না', 'না না', 'দরকার নেই', 'বাতিল', 'থাক']) {
        expect(yesNo(n), isFalse, reason: n);
      }
      expect(yesNo('আকাশ নীল'), isNull);
    });

    test('a plain fact becomes a note to file', () {
      final c = Parser(ledger: const []).parse('ছাদের দরজার কোড ৪৫৬৭') as NoteAdd;
      expect(c.fromStatement, isTrue);
      expect(isQuestionText('ছাদের দরজার কোড কত?'), isTrue);
      expect(isQuestionText('ছাদের দরজার কোড ৪৫৬৭'), isFalse);
    });

    test('categories: existing match, known topic, or new', () {
      final empty = AppData();
      final car = guessCategory(empty, 'আমার গাড়ির নম্বর ঢাকা মেট্রো গ ১২-৩৪৫৬');
      expect(car.name, 'যানবাহন');
      expect(car.isNew, isTrue);
      final roof = guessCategory(empty, 'ছাদের দরজার কোড ৪৫৬৭');
      expect(roof.name, 'ছাদ');
      expect(roof.isNew, isTrue);
      final withRoof = AppData(notes: [Note(title: 'ছাদের দরজার কোড', body: 'ছাদের দরজার কোড ৪৫৬৭', category: 'ছাদ')]);
      final again = guessCategory(withRoof, 'ছাদের চাবি নিচের ড্রয়ারে');
      expect(again.name, 'ছাদ');
      expect(again.isNew, isFalse);
      expect(withRoof.noteCategories, ['ছাদ']);
    });
  });

  group('Revision 1: finding logins however they are spoken', () {
    test('Bengali spelling matches the English name', () {
      expect(skeleton('ফেসবুক'), skeleton('facebook'));
      expect(wordsMatch('ফেসবুক', 'facebook'), isTrue);
      expect(wordsMatch('এবিসি', 'abc'), isTrue);
      expect(wordsMatch('জিমেইল', 'gmail'), isTrue);
      expect(wordsMatch('ইউটিউব', 'YouTube'), isTrue);
      expect(wordsMatch('ফেসবুক', 'gmail'), isFalse);
      expect(spelledLetters('এবিসি'), 'abc');
      expect(spelledLetters('আমি'), isNull);
    });

    test('vault questions find the saved login', () {
      final d = AppData(vault: [
        VaultItem(name: 'Facebook', kind: VaultKind.website, password: 'x'),
        VaultItem(name: 'ABC ওয়েবসাইট', kind: VaultKind.website, password: 'y'),
      ]);
      final q1 = Parser(ledger: const []).parse('ফেসবুকের পাসওয়ার্ড কী?') as VaultQuery;
      expect(searchVault(d, q1.terms).single.name, 'Facebook');
      final q2 = Parser(ledger: const []).parse('এবিসির পাসওয়ার্ড দেখাও') as VaultQuery;
      expect(searchVault(d, q2.terms).first.name, 'ABC ওয়েবসাইট');
      final q3 = Parser(ledger: const []).parse('আমার ফেসবুক পাসওয়াড টা বলো');
      expect(q3, isA<VaultQuery>());
    });
  });

  group('Revision 2: everyday Bangladeshi speech and conversation', () {
    test('colloquial and regional money sentences', () {
      final a = Parser(ledger: const []).parse('সজীব আমারে ৩০০ ট্যাকা ফেরত দিসে') as LedgerAdd;
      expect(a.person, 'সজীব');
      expect(a.amount, 300);
      expect(a.kind, LedgerKind.received);
      final b = Parser(ledger: const []).parse('রহিমের থেইকা ১০০০ টেকা হাওলাত আনছি') as LedgerAdd;
      expect(b.person, 'রহিম');
      expect(b.kind, LedgerKind.borrowed);
      final c = Parser(ledger: const []).parse('ইসমাইলের কাছে মুই ৫ হাজার টেকা পামু') as LedgerSet;
      expect(c.person, 'ইসমাইল');
      expect(c.balance, 5000);
      final d = Parser(ledger: const []).parse('সজীবরে ৫০০ টাকা দিছি') as LedgerAdd;
      expect(d.person, 'সজীব');
      expect(d.kind, LedgerKind.lent);
      expect(normalize('কাজ করে দিলাম'), 'কাজ করে দিলাম');
    });

    test('colloquial yes / no', () {
      expect(yesNo('হ'), isTrue);
      expect(yesNo('হ, রাইখা দাও'), isTrue);
      expect(yesNo('আইচ্ছা'), isTrue);
      expect(yesNo('থাউক'), isFalse);
      expect(yesNo('বাদ দেন'), isFalse);
    });

    test('conversation is not a search', () {
      Talk? k(String s) => (Parser(ledger: const []).parse(s) as SmallTalk).kind;
      expect(k('তুমি কেমন আছো?'), Talk.howAreYou);
      expect(k('কেমুন আছেন'), Talk.howAreYou);
      expect(k('আসসালামু আলাইকুম'), Talk.salam);
      expect(k('ধন্যবাদ'), Talk.thanks);
      expect(k('আজ কত তারিখ?'), Talk.date);
      expect(k('এখন কয়টা বাজে'), Talk.time);
      expect(k('তুমি কী কী করতে পারো?'), Talk.whatCanYouDo);
      expect(k('তুমি কে'), Talk.whoAreYou);
      expect(k('হ্যালো'), Talk.greeting);
      expect(talkReply(Talk.date, DateTime(2026, 10, 9)), 'আজ শুক্রবার, ৯ অক্টোবর।');
    });

    test('a greeting before a request is dropped, a name is not', () {
      final c = Parser(ledger: const []).parse('হ্যালো, সজীবকে ৫০০ টাকা দিলাম') as LedgerAdd;
      expect(c.person, 'সজীব');
      expect(c.transcript, 'সজীবকে ৫০০ টাকা দিলাম');
      final d = Parser(ledger: const []).parse('শুভ আমাকে ৩০০ টাকা ফেরত দিসে') as LedgerAdd;
      expect(d.person, 'শুভ');
    });

    test('phone numbers are read digit by digit', () {
      expect(speakableNumbers('করিমের নম্বর ০১৭১১২২৩৩৪৪।'), 'করিমের নম্বর ০ ১ ৭ ১ ১ ২ ২ ৩ ৩ ৪ ৪।');
      expect(speakableNumbers('কোড ৪৫৬৭'), 'কোড ৪৫৬৭');
    });
  });

  group('Revision 2: every money sentence goes to লেনদেন', () {
    test('money without a person still goes to the ledger, never a note', () {
      final a = Parser(ledger: const []).parse('১২০০ টাকা ধার দিলাম') as LedgerAdd;
      expect(a.person, '');
      expect(a.amount, 1200);
      expect(a.needsChoice, isTrue);
      expect(a.suggested, LedgerKind.lent);
      // Own spending stays in লেনদেন too, in আয়-ব্যয়.
      final bill = Parser(ledger: const []).parse('বিদ্যুৎ বিল ১২০০ টাকা দিলাম') as CashAdd;
      expect(bill.kind, CashKind.expense);
      expect(bill.category, 'বিল');
      expect((Parser(ledger: const []).parse('আজ বাজারে ৫০০ টাকা খরচ হলো') as CashAdd).category, 'বাজার');
      expect(Parser(ledger: const []).parse('রহিমকে কিছু টাকা ধার দিলাম'), isA<LedgerAdd>());
    });

    test('"মনে রাখো" with money is still a ledger entry', () {
      final c = Parser(ledger: const []).parse('মনে রাখো রহিমকে ৫০০ টাকা দিলাম') as LedgerAdd;
      expect(c.person, 'রহিম');
      expect(c.kind, LedgerKind.lent);
    });

    test('a spoken name', () {
      expect(spokenName('করিম', const []), 'করিম');
      expect(spokenName('ওনার নাম করিম', const []), 'করিম');
      expect(spokenName('রহিমের সাথে', const ['রহিম']), 'রহিম');
    });
  });

  group('Revision 2: regional words and Banglish', () {
    test('Noakhali টিয়া / টেয়া', () {
      final a = Parser(ledger: const []).parse('ইসমাইলের কাছে আমি ৫ হাজার টিয়া পামু') as LedgerSet;
      expect(a.balance, 5000);
      final b = Parser(ledger: const []).parse('রহিমরে ৫০০ টেয়া দিসি') as LedgerAdd;
      expect(b.person, 'রহিম');
      expect(b.kind, LedgerKind.lent);
      expect(normalize('একটা টিয়া পাখি'), contains('টিয়া'.replaceAll('য়', 'য়')));
    });

    test('Bengali written in English letters, and mixed', () {
      final a = Parser(ledger: const []).parse('Sajib ke 500 taka dilam') as LedgerAdd;
      expect(a.person, 'Sajib');
      expect(a.amount, 500);
      expect(a.kind, LedgerKind.lent);
      final b = Parser(ledger: const []).parse('rahimer kache ami 2000 taka pai') as LedgerSet;
      expect(b.person, 'Rahim');
      expect(b.balance, 2000);
      final c = Parser(ledger: const []).parse('ABC er password ki') as VaultQuery;
      expect(c.terms, ['abc']);
      expect((Parser(ledger: const []).parse('tumi kemon acho') as SmallTalk).kind, Talk.howAreYou);
      final d = Parser(ledger: const []).parse('সজীব কে ৩০০ টাকা loan দিলাম') as LedgerAdd;
      expect(d.person, 'সজীব');
      expect(d.kind, LedgerKind.lent);
      expect((Parser(ledger: const []).parse('তুমি কে?') as SmallTalk).kind, Talk.whoAreYou);
    });
  });

  group('AI answers mapped to app commands', () {
    final ledger = [e('ইসমাইল', LedgerKind.lent, 100, DateTime(2026, 10, 1))];
    test('each action', () {
      final a = commandFromAi('x', {'action': 'ledger_add', 'person': 'সজীব', 'amount': 500, 'kind': 'lent'}, ledger) as LedgerAdd;
      expect(a.kind, LedgerKind.lent);
      expect(a.person, 'সজীব');
      final b = commandFromAi('x', {'action': 'ledger_add', 'person': '', 'amount': 1200, 'kind': 'unclear'}, ledger) as LedgerAdd;
      expect(b.needsChoice, isTrue);
      expect(b.person, '');
      final c = commandFromAi('x', {'action': 'ledger_set', 'person': 'ইসমাইলের', 'balance': 5000}, ledger) as LedgerSet;
      expect(c.person, 'ইসমাইল');
      expect(c.balance, 5000);
      expect(commandFromAi('x', {'action': 'chat', 'reply': 'ভালো আছি'}, ledger), isA<AiReply>());
      final n = commandFromAi('x', {'action': 'note_add', 'text': 'ছাদের কোড ৪৫৬৭', 'category': 'বাসা'}, ledger) as NoteAdd;
      expect(n.category, 'বাসা');
      final v = commandFromAi('x', {'action': 'vault_query', 'terms': ['Facebook']}, ledger) as VaultQuery;
      expect(v.terms, ['facebook']);
      expect(commandFromAi('x', {'action': 'nonsense'}, ledger), isNull);
      expect(commandFromAi('x', {'action': 'chat'}, ledger), isNull);
    });

    test('secrets are detected so they stay on the phone', () {
      expect(mentionsSecret('ফেসবুক পাসওয়ার্ড abc123 রাখো'), isTrue);
      expect(mentionsSecret('আমার ATM পিন 1234'), isTrue);
      expect(mentionsSecret('বাসার wifi এর নাম কী'), isTrue);
      expect(mentionsSecret('সজীবকে ৫০০ টাকা দিলাম'), isFalse);
    });
  });

  group('chat: several things in one message', () {
    test('two money events joined by আর are split', () {
      final c = parseAll('সজীবকে ৫০০ টাকা ধার দিলাম আর রহিমের কাছ থেকে ২০০ টাকা ধার নিলাম', const []);
      expect(c, hasLength(2));
      expect((c[0] as LedgerAdd).person, 'সজীব');
      expect((c[1] as LedgerAdd).amount, 200);
    });

    test('"রহিম আর করিমকে" stays one sentence', () {
      final c = parseAll('রহিম আর করিমকে ৫০০ টাকা দিলাম', const []);
      expect(c, hasLength(1));
    });

    test('calling: respect words do not pick a person, scripts match, two of a name are both returned', () {
      final d = AppData(contacts: [
        Contact(name: 'Mobarak Bhai', phone: '01711000001'),
        Contact(name: 'Ibne Sina Mostafiz Bhai', phone: '01711000002'),
      ]);
      expect(findContact(d, 'মোবারক ভাই')!.phone, '01711000001');
      expect(findContact(d, 'মোবারক ভাইকে')!.phone, '01711000001');
      expect(findContact(d, 'মোস্তাফিজ ভাই')!.phone, '01711000002');
      expect(findContact(d, 'রহিম ভাই'), isNull);
      d.contacts.add(Contact(name: 'মোবারক হোসেন', phone: '01811000003'));
      expect(findContact(d, 'মোবারক ভাই'), isNull);
      expect(contactMatches(d, 'মোবারক').map((c) => c.phone), ['01711000001', '01811000003']);
    });

    test('"তুমি এটা লেখ" is not part of what to save', () {
      final c = parseAll('তুমি এটা লেখ, আমি রবিনকে ৫ হাজার টাকা দিছি', const []);
      expect(c.single, isA<LedgerAdd>());
      expect((c.single as LedgerAdd).person, 'রবিন');
      expect((c.single as LedgerAdd).amount, 5000);
      expect(stripAddress('শোনো, এটা লিখে রাখো যে করিমের দোকান বন্ধ').$1, 'করিমের দোকান বন্ধ');
      expect(stripAddress('রবিনকে ৫০০ টাকা দিলাম, এটা লিখে রাখো').$1, 'রবিনকে ৫০০ টাকা দিলাম');
      expect(stripAddress('লেখাপড়ার খরচ ৫০০ টাকা').$1, 'লেখাপড়ার খরচ ৫০০ টাকা');
      expect(stripAddress('এই মাসে কত খরচ হলো').$1, 'এই মাসে কত খরচ হলো');
      expect(parseAll('লিখে রাখো যে করিমের দোকান বন্ধ', const []).single, isA<NoteAdd>());
    });

    test('separate sentences each count', () {
      final c = parseAll('তুমি কেমন আছো? সজীবকে ৫০০ টাকা দিলাম।', const []);
      expect(c, hasLength(2));
      expect(c.first, isA<SmallTalk>());
      expect(c.last, isA<LedgerAdd>());
    });

    test('one sentence is parsed as before', () {
      expect(parseAll('মনে রাখো: গাড়ির কাগজ আলমারিতে', const []).single, isA<NoteAdd>());
    });

    test('the AI\'s list of items becomes commands', () {
      final c = commandsFromAi('x', {
        'reply': 'আচ্ছা',
        'items': [
          {'action': 'ledger_add', 'person': 'জামাল', 'amount': 1500, 'kind': 'lent'},
          {'action': 'note_add', 'text': 'ছাদের কোড ৪৫৬৭', 'category': 'বাসা'},
        ],
      }, const []);
      expect(c, hasLength(2));
      expect(summaryLine(c[0]), 'জামালকে ১,৫০০ টাকা ধার দিলেন');
      expect(summaryLine(c[1]), 'ছাদের কোড ৪৫৬৭');
    });

    test('no items: the AI reply is the answer', () {
      final c = commandsFromAi('x', {'reply': 'ভালো আছি', 'items': []}, const []);
      expect((c.single as AiReply).text, 'ভালো আছি');
      expect(commandsFromAi('x', {'reply': '', 'items': []}, const []), isEmpty);
    });

    test('a stated balance gives the entry that reaches it', () {
      final now = DateTime(2026, 10, 9);
      final l = [e('রহিম', LedgerKind.lent, 1000, now)];
      final x = entryToReach(l, 'রহিম', 3000, now)!;
      expect(x.kind, LedgerKind.lent);
      expect(x.amount, 2000);
      expect(entryToReach(l, 'রহিম', 1000, now), isNull);
      expect(entryToReach(const [], 'ইসমাইল', -500, now)!.kind, LedgerKind.borrowed);
    });
  });

  group('assistant: when', () {
    final now = DateTime(2026, 10, 9, 15, 53); // Friday
    test('day and time words', () {
      expect(parseWhen('কাল সকাল ১০টায় মিটিং', now)!.at, DateTime(2026, 10, 10, 10, 0));
      expect(parseWhen('৩০ মিনিট পরে চা', now)!.at, DateTime(2026, 10, 9, 16, 23));
      expect(parseWhen('আধা ঘণ্টা পরে', now)!.at, DateTime(2026, 10, 9, 16, 23));
      expect(parseWhen('বিকেল ৪টায় মিটিং', now)!.at, DateTime(2026, 10, 9, 16, 0));
      expect(parseWhen('৪টায় মিটিং', now)!.at, DateTime(2026, 10, 9, 16, 0));
      expect(parseWhen('রাত সাড়ে ৯টায়', now)!.at, DateTime(2026, 10, 9, 21, 30));
      expect(parseWhen('১০:৩০টায় ব্যাংক', now)!.at, DateTime(2026, 10, 10, 10, 30));
      final sat = parseWhen('শনিবার দোকানে যাব', now)!;
      expect(sat.day, DateTime(2026, 10, 10));
      expect(sat.hasTime, isFalse);
      expect(parseWhen('১৫ তারিখে ভাড়া', now)!.day, DateTime(2026, 10, 15));
      expect(parseWhen('৩ নভেম্বর', now)!.day, DateTime(2026, 11, 3));
    });

    test('a past time today moves to tomorrow; counts are not times', () {
      expect(parseWhen('সকাল ১০টায় ফোন', now)!.at, DateTime(2026, 10, 10, 10, 0));
      expect(parseWhen('৩টা ডিম কিনতে হবে', now), isNull);
      expect(parseWhen('এমনি কথা', now), isNull);
    });
  });

  group('assistant: commands', () {
    final now = DateTime(2026, 10, 9, 15, 53);
    Command parse(String s, {List<Task> tasks = const [], List<Contact> contacts = const []}) =>
        Parser(ledger: const [], tasks: tasks, contacts: contacts, now: now).parse(s);

    test('a timed reminder', () {
      final r = parse('কাল সকাল ১০টায় মিটিংয়ের কথা মনে করিয়ে দিও') as ReminderAdd;
      expect(r.at, DateTime(2026, 10, 10, 10, 0));
      expect(fold(r.title), fold('মিটিংয়ের কথা'));
      final soon = parse('৩০ মিনিট পরে চা খাওয়ার কথা মনে করিয়ে দিও') as ReminderAdd;
      expect(soon.at, DateTime(2026, 10, 9, 16, 23));
      final monthly = parse('প্রতি মাসের ৫ তারিখে দোকান ভাড়ার কথা মনে করিয়ে দিও') as ReminderAdd;
      expect(monthly.repeat, Repeat.monthly);
      // No time: still a question about a saved date.
      expect(parse('ডোমেইন রিনিউ করার তারিখটা মনে করিয়ে দাও'), isA<ReminderQuery>());
    });

    test('to-dos', () {
      final t = parse('কাল ব্যাংকে যেতে হবে') as TaskAdd;
      expect(fold(t.title), fold('ব্যাংকে যেতে হবে'));
      expect(t.due, DateTime(2026, 10, 10));
      expect((parse('বাজারের লিস্টে ডিম রাখো') as TaskAdd).title, 'বাজার: ডিম');
      expect(parse('কাজের তালিকা দেখাও'), isA<TaskQuery>());
      expect(parse('আজ আমার কী কী আছে?'), isA<Briefing>());
      expect(parse('আজকে কী কী করতে হবে?'), isA<Briefing>());
      expect(parse('তুমি কী কী করতে পারো?'), isA<SmallTalk>());
      final bank = Task(title: 'ব্যাংকে যেতে হবে');
      expect(parse('ব্যাংকের কাজ হয়ে গেছে', tasks: [bank]), isA<TaskDone>());
      expect(matchTasks([bank], (parse('ব্যাংকের কাজ হয়ে গেছে', tasks: [bank]) as TaskDone).terms).single, bank);
      // Money still goes to লেনদেন.
      expect(parse('রহিমকে আমার ৫০০ টাকা দিতে হবে'), isA<LedgerSet>());
    });

    test('calls, messages and numbers', () {
      final c = parse('রহিমকে ফোন দাও') as CallPerson;
      expect(c.person, 'রহিম');
      expect(c.via, Via.call);
      final m = parse('করিমকে মেসেজ দাও যে মাল পাঠিয়েছি') as CallPerson;
      expect(m.via, Via.sms);
      expect(fold(m.text), fold('মাল পাঠিয়েছি'));
      expect((parse('হোয়াটসঅ্যাপে করিমকে লিখে পাঠাও আমি আসছি') as CallPerson).via, Via.whatsapp);
      expect(parse('রহিমকে ফোন করতে হবে'), isA<TaskAdd>());
      final n = parse('রহিমের নম্বর ০১৭১২-৩৪৫৬৭৮ রাখো') as ContactAdd;
      expect(n.name, 'রহিম');
      expect(n.phone, '01712345678');
      expect(findPhone('+8801812345678'), '+8801812345678');
      expect(launchUri(Via.whatsapp, '01712345678', text: 'আসছি').toString(), startsWith('https://wa.me/8801712345678?text='));
      expect(launchUri(Via.call, '01712-345678').toString(), 'tel:01712345678');
    });

    test('shop credit (বাকি)', () {
      final c = parse('করিম ৫০০ টাকার মাল বাকিতে নিল') as LedgerAdd;
      expect(c.person, 'করিম');
      expect(c.amount, 500);
      expect(c.kind, LedgerKind.lent);
      expect((parse('করিম বাকির ৩০০ টাকা দিয়ে গেল') as LedgerAdd).kind, LedgerKind.received);
      expect((parse('দোকান থেকে ২০০০ টাকার মাল বাকিতে নিলাম') as LedgerAdd).kind, LedgerKind.borrowed);
    });

    test('the AI\'s assistant actions', () {
      final c = commandsFromAi('x', {
        'reply': 'আচ্ছা',
        'items': [
          {'action': 'reminder_add', 'text': 'মিটিং', 'date': '2026-10-10', 'time': '16:30'},
          {'action': 'call', 'person': 'রহিম', 'via': 'whatsapp', 'text': 'আসছি'},
          {'action': 'task_add', 'text': 'রিপোর্ট জমা', 'date': '2026-10-12'},
          {'action': 'contact_add', 'person': 'করিম', 'phone': '01812345678'},
          {'action': 'briefing'},
        ],
      }, const []);
      expect((c[0] as ReminderAdd).at, DateTime(2026, 10, 10, 16, 30));
      expect((c[1] as CallPerson).via, Via.whatsapp);
      expect((c[2] as TaskAdd).due, DateTime(2026, 10, 12));
      expect((c[3] as ContactAdd).phone, '01812345678');
      expect(c[4], isA<Briefing>());
    });

    test('tasks survive saving', () {
      final d = AppData(tasks: [Task(title: 'দুধ কেনা', due: DateTime(2026, 10, 9))]);
      final back = AppData.fromJson(d.toJson());
      expect(back.tasks.single.title, 'দুধ কেনা');
      expect(back.tasks.single.due, DateTime(2026, 10, 9));
    });
  });

  group('revision 3: money in parts, repeating reminders', () {
    final now = DateTime(2026, 10, 9, 15, 53);
    Command parse(String s) => Parser(ledger: const [], now: now).parse(s);

    test('own income and spending', () {
      final pay = parse('বেতন পেলাম ৩০ হাজার টাকা') as CashAdd;
      expect(pay.kind, CashKind.income);
      expect(pay.amount, 30000);
      expect(pay.category, 'বেতন');
      expect(parse('এই মাসে কত খরচ হলো?'), isA<CashQuery>());
      expect(parse('রহিমকে ৫০০ টাকা দিলাম'), isA<LedgerAdd>());
    });

    test('project money', () {
      final c = parse('রহিম ভবন প্রজেক্টে ৫০ হাজার টাকা এলো') as CashAdd;
      expect(c.project, 'রহিম ভবন');
      expect(c.kind, CashKind.income);
      expect(c.amount, 50000);
      final out = parse('রহিম ভবন প্রজেক্টে রড কিনলাম ২০ হাজার টাকা') as CashAdd;
      expect(out.kind, CashKind.expense);
      final q = parse('রহিম ভবন প্রজেক্টে কত টাকা আছে?') as CashQuery;
      expect(q.project, 'রহিম ভবন');
    });

    test('sums by month and project; loans split', () {
      final d = AppData(
        cash: [
          CashEntry(kind: CashKind.income, amount: 30000, category: 'বেতন', date: DateTime(2026, 10, 1)),
          CashEntry(kind: CashKind.expense, amount: 500, category: 'বাজার', date: DateTime(2026, 10, 5)),
          CashEntry(kind: CashKind.expense, amount: 1200, category: 'বিল', date: DateTime(2026, 10, 6)),
          CashEntry(kind: CashKind.expense, amount: 999, category: 'বাজার', date: DateTime(2026, 9, 6)),
          CashEntry(kind: CashKind.income, amount: 50000, date: DateTime(2026, 10, 2), projectId: 'p1'),
          CashEntry(kind: CashKind.expense, amount: 20000, date: DateTime(2026, 10, 3), projectId: 'p1'),
        ],
        projects: [Project(id: 'p1', name: 'রহিম ভবন')],
        ledger: [
          e('সজীব', LedgerKind.lent, 1000, now),
          e('সজীব', LedgerKind.received, 400, now),
          e('রহিম', LedgerKind.borrowed, 2000, now),
          e('রহিম', LedgerKind.repaid, 500, now),
        ],
      );
      final m = monthSums(d.cash, now);
      expect(m.income, 30000);
      expect(m.expense, 1700);
      expect(m.balance, 28300);
      expect(m.topExpenses.first.key, 'বিল');
      expect(projectSums(d.cash, 'p1').balance, 30000);
      expect(openProjectsBalance(d), 30000);
      final l = loanSummary(d.ledger);
      expect([l.lent, l.received, l.receivable], [1000, 400, 600]);
      expect([l.borrowed, l.repaid, l.payable], [2000, 500, 1500]);
      final back = AppData.fromJson(d.toJson());
      expect(back.cash, hasLength(6));
      expect(back.projects.single.name, 'রহিম ভবন');
    });

    test('every 5/10/30 minutes, hourly, daily', () {
      final r = parse('প্রতি ৩০ মিনিটে পানি খাওয়ার কথা মনে করিয়ে দিও') as ReminderAdd;
      expect(r.repeat, Repeat.every30);
      expect(r.at, DateTime(2026, 10, 9, 16, 23));
      expect(fold(r.title), fold('পানি খাওয়ার কথা'));
      expect((parse('১০ মিনিট পর পর চুলার কথা মনে করিয়ে দিও') as ReminderAdd).repeat, Repeat.every10);
      expect((parse('ঘণ্টায় ঘণ্টায় হাঁটার কথা মনে করিয়ে দিও') as ReminderAdd).repeat, Repeat.hourly);
      final daily = parse('প্রতিদিন রাত ১০টায় ওষুধ খাওয়ার কথা মনে করিয়ে দিও') as ReminderAdd;
      expect(daily.repeat, Repeat.daily);
      expect(daily.at, DateTime(2026, 10, 9, 22, 0));
      expect(Repeat.everyMinutes(15), Repeat.every10);
      expect(Repeat.everyMinutes(45), Repeat.hourly);
    });

    test('a short repeat rings on its own times', () {
      final r = Reminder(title: 'পানি', date: DateTime(2026, 10, 9), hour: 15, minute: 0, daysBefore: 0, repeat: Repeat.every30);
      expect(r.notifyAt(now), DateTime(2026, 10, 9, 16, 0));
      final n = plannedNotices([r], now).single;
      expect(n.every, const Duration(minutes: 30));
      expect(n.at, DateTime(2026, 10, 9, 15, 0));
      final d = Reminder(title: 'ওষুধ', date: DateTime(2026, 10, 1), hour: 22, minute: 0, daysBefore: 0, repeat: Repeat.daily);
      expect(d.notifyAt(now), DateTime(2026, 10, 9, 22, 0));
      expect(plannedNotices([d], now).single.daily, isTrue);
    });
  });
}
