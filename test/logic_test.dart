import 'package:digital_brain/logic/ai_map.dart';
import 'package:digital_brain/logic/answers.dart';
import 'package:digital_brain/logic/ask.dart';
import 'package:digital_brain/logic/app_map.dart';
import 'package:digital_brain/logic/me.dart';
import 'package:digital_brain/logic/inbox.dart';
import 'package:digital_brain/logic/bn.dart';
import 'package:digital_brain/logic/calendar_bd.dart';
import 'package:digital_brain/logic/cash.dart';
import 'package:digital_brain/logic/categories.dart';
import 'package:digital_brain/logic/csv.dart';
import 'package:digital_brain/logic/dictation.dart';
import 'package:digital_brain/logic/ledger.dart';
import 'package:digital_brain/logic/match.dart';
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/logic/password.dart';
import 'package:digital_brain/logic/phrases.dart';
import 'package:digital_brain/logic/plan.dart';
import 'package:digital_brain/logic/when.dart';
import 'package:digital_brain/logic/health.dart';
import 'package:digital_brain/logic/lang.dart';
import 'package:digital_brain/logic/money_more.dart';
import 'package:digital_brain/logic/proactive.dart';
import 'package:digital_brain/logic/report.dart';
import 'package:digital_brain/logic/templates.dart';
import 'package:digital_brain/logic/search.dart';
import 'package:digital_brain/logic/suggest.dart';
import 'package:digital_brain/logic/talk.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/launcher.dart';
import 'package:digital_brain/services/notifications.dart';
import 'package:digital_brain/services/voice.dart';
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

    test('I gave: a loan only when said; a plain "দিলাম" asks (ধার first)', () {
      final c = Parser(ledger: const []).parse('আমি সজীবকে ৫০০ টাকা দিলাম।') as LedgerAdd;
      expect(c.person, 'সজীব');
      expect(c.amount, 500);
      expect(c.kind, isNull);
      expect(c.suggested, LedgerKind.lent);
      expect((Parser(ledger: const []).parse('আমি সজীবকে ৫০০ টাকা ধার দিলাম।') as LedgerAdd).kind, LedgerKind.lent);
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
      expect(d.suggested, LedgerKind.lent);
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
      expect(talkReply(Talk.date, DateTime(2026, 10, 9)), startsWith('আজ শুক্রবার, ৯ অক্টোবর ২০২৬।'));
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
      // A plain "দিলাম" is not assumed to be a loan: the app asks.
      expect(c.kind, isNull);
      expect(c.options, contains(LedgerKind.lent));
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
      expect(b.amount, 500);
      expect(normalize('একটা টিয়া পাখি'), contains('টিয়া'.replaceAll('য়', 'য়')));
    });

    test('Bengali written in English letters, and mixed', () {
      final a = Parser(ledger: const []).parse('Sajib ke 500 taka dhar dilam') as LedgerAdd;
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
      expect(contactMatches(d, 'মোবারক').map((c) => c.phone), unorderedEquals(['01711000001', '01811000003']));
    });

    test('"ফেসবুকের পাসওয়ার্ড ১২২৩৯৯৩৯" saves a login; asking for it does not', () {
      final a = Parser(ledger: const []).parse('ফেসবুকের পাসওয়ার্ড ১২২৩৯৯৩৯') as VaultAdd;
      expect(a.name, 'ফেসবুক');
      expect(a.password, '12239939');
      final w = Parser(ledger: const []).parse('অফিসের ওয়াইফাই পাসওয়ার্ড Shop@2024') as VaultAdd;
      expect(w.wifi, isTrue);
      expect(w.password, 'Shop@2024');
      expect(Parser(ledger: const []).parse('ফেসবুকের পাসওয়ার্ড কত?'), isA<VaultQuery>());
      expect(Parser(ledger: const []).parse('ফেসবুকের পাসওয়ার্ড দেখাও'), isA<VaultQuery>());
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

    test('clock times: ৬.২০, ৬:২০, ৬টা ২০ — the next one to come round', () {
      final eve = DateTime(2026, 10, 10, 18, 18);
      expect(parseWhen('৬.২০ এ রিমাইন্ডার দিও', eve)!.at, DateTime(2026, 10, 10, 18, 20));
      expect(parseWhen('৬:২০ এ রিমাইন্ডার দিও', eve)!.at, DateTime(2026, 10, 10, 18, 20));
      expect(parseWhen('6.20e', eve)!.at, DateTime(2026, 10, 10, 18, 20));
      expect(parseWhen('৬টা ২০ মিনিটে মিটিং', eve)!.at, DateTime(2026, 10, 10, 18, 20));
      expect(parseWhen('সকাল ৬.২০ এ', eve)!.at, DateTime(2026, 10, 11, 6, 20));
      expect(parseWhen('আজ ৭.৪৫ এ', eve)!.at, DateTime(2026, 10, 10, 19, 45));
      expect(parseWhen('৬.২০ টাকা', eve), isNull);
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

    test('a reminder with only a time, or with no time yet', () {
      final p = Parser(ledger: const [], now: DateTime(2026, 10, 10, 18, 18));
      final r = p.parse('৬.২০ এ রিমাইন্ডার দিও') as ReminderAdd;
      expect(r.at, DateTime(2026, 10, 10, 18, 20));
      expect(r.needsTitle, isTrue);
      final later = p.parse('ওষুধ খাওয়ার রিমাইন্ডার দিও') as ReminderAdd;
      expect(later.needsTime, isTrue);
      expect(fold(later.title), contains(fold('ওষুধ')));
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
      }, const []).where((x) => x is! AiReply).toList();
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

  test('"আজ কোন রিমাইন্ডার আছে?" lists today\'s reminders, or says there are none', () {
    final now = DateTime(2026, 10, 10, 18, 0);
    final d = AppData(reminders: [
      Reminder(title: 'বাজার', date: DateTime(2026, 10, 10), hour: 18, minute: 20),
      Reminder(title: 'মিটিং', date: DateTime(2026, 10, 11), hour: 10),
    ]);
    final q = Parser(ledger: const [], now: now).parse('আজ কোন রিমাইন্ডার আছে?');
    expect(q, isA<ReminderQuery>());
    final a = reminderAnswer(d, q as ReminderQuery, now);
    expect(a, contains('১টা রিমাইন্ডার'));
    expect(a, contains('বাজার'));
    expect(a, isNot(contains('মিটিং')));
    expect(reminderAnswer(AppData(), q, now), contains('আজ কোনো রিমাইন্ডার নেই'));
  });

  test('"দেব" is spoken as "দেবো", not as another word', () {
    expect(forSpeech('কাল সকালে মনে করিয়ে দেব — ঠিক আছে?'), 'কাল সকালে মনে করিয়ে দেবো — ঠিক আছে?');
    expect(forSpeech('আমি করব, রাখব।'), 'আমি করবো, রাখবো।');
    expect(forSpeech('দেবেন না, সব ঠিক'), 'দেবেন না, সব ঠিক');
    expect(forSpeech('• বাজার'), ' বাজার');
  });

  test('Bangla date (revised calendar), season and holidays', () {
    expect(banglaDate(DateTime(2026, 10, 13)).text, '২৮ আশ্বিন ১৪৩৩');
    expect(banglaDate(DateTime(2026, 10, 13)).season, 'শরৎ');
    expect(banglaDate(DateTime(2026, 10, 17)).text, '১ কার্তিক ১৪৩৩');
    expect(banglaDate(DateTime(2026, 12, 16)).text, '১ পৌষ ১৪৩৩');
    expect(banglaDate(DateTime(2027, 2, 21)).text, '৮ ফাল্গুন ১৪৩৩');
    expect(banglaDate(DateTime(2027, 4, 14)).text, '১ বৈশাখ ১৪৩৪');
    expect(banglaDate(DateTime(2026, 4, 13)).text, '৩০ চৈত্র ১৪৩২');
    final run = upcomingHolidays(DateTime(2026, 10, 13), count: 1).single;
    expect(run.start, DateTime(2026, 10, 20));
    expect(run.days, 5);
  });

  test('sunrise and sunset in Dhaka', () {
    final s = sunTimes(DateTime(2026, 10, 13), placeNamed('ঢাকা'));
    expect(s.sunrise.hour * 60 + s.sunrise.minute, inInclusiveRange(5 * 60 + 50, 5 * 60 + 59));
    expect(s.sunset.hour * 60 + s.sunset.minute, inInclusiveRange(17 * 60 + 30, 17 * 60 + 40));
    expect(s.fajr.isBefore(s.sunrise), isTrue);
    expect(s.asr.isAfter(s.dhuhr), isTrue);
  });

  group('voice examples (Bengali speech)', () {
    final now = DateTime(2026, 10, 13, 18, 0);
    final sajib = [
      LedgerEntry(person: 'সজীব', kind: LedgerKind.lent, amount: 500, date: DateTime(2026, 10, 13)),
      LedgerEntry(person: 'সজীব', kind: LedgerKind.received, amount: 300, date: DateTime(2026, 10, 13)),
    ];

    test('amounts said in words and in parts', () {
      expect(findAmount(normalize('পাঁচশ টাকা')), 500);
      expect(findAmount(normalize('তিনশ টাকা')), 300);
      expect(findAmount(normalize('দেড় হাজার টাকা')), 1500);
      expect(findAmount(normalize('দুই হাজার পাঁচশ টাকা')), 2500);
      expect(findAmount(normalize('সাড়ে তিন হাজার')), 3500);
      expect(findAmount(normalize('এক লাখ বিশ হাজার')), 120000);
      expect(findAmount(normalize('2 হাজার 500 টাকা')), 2500);
      expect(findAmount(normalize('৫০০ টাকা')), 500);
      expect(findAmount(normalize('এটা ধার নয়')), isNull);
    });

    test('“সজীবকে পাঁচশ টাকা ধার দিয়েছি” is a loan of 500', () {
      final c = Parser(ledger: const [], now: now).parse('সজীবকে পাঁচশ টাকা ধার দিয়েছি।') as LedgerAdd;
      expect(c.person, 'সজীব');
      expect(c.amount, 500);
      expect(c.kind, LedgerKind.lent);
    });

    test('“সজীব আমাকে তিনশ টাকা ফেরত দিয়েছে” is money received back', () {
      final c = Parser(ledger: [sajib.first], now: now).parse('সজীব আমাকে তিনশ টাকা ফেরত দিয়েছে।') as LedgerAdd;
      expect(c.person, 'সজীব');
      expect(c.amount, 300);
      expect(c.kind, LedgerKind.received);
    });

    test('“সজীবের কাছে কত টাকা পাই?” asks, saves nothing, and the answer is 200', () {
      final q = Parser(ledger: sajib, now: now).parse('সজীবের কাছে কত টাকা পাই?');
      expect(q, isA<LedgerQuery>());
      expect(isSave(q), isFalse);
      expect(answerText(AppData(ledger: sajib), q, now), contains('২০০'));
    });

    test('“আজ বাজারে দেড় হাজার টাকা খরচ করেছি” is own spending of 1500', () {
      final c = Parser(ledger: const [], now: now).parse('আজ বাজারে দেড় হাজার টাকা খরচ করেছি।') as CashAdd;
      expect(c.kind, CashKind.expense);
      expect(c.amount, 1500);
    });

    test('“সজীবকে টাকা দিয়েছি” has no amount and no assumed loan', () {
      final c = Parser(ledger: const [], now: now).parse('সজীবকে টাকা দিয়েছি।') as LedgerAdd;
      expect(c.amount, 0);
      expect(c.kind, isNull);
    });

    test('“কাল সকাল দশটায় মিটিং মনে করিয়ে দিও” is a reminder at 10:00 tomorrow, not money', () {
      final c = Parser(ledger: const [], now: now).parse('কাল সকাল দশটায় মিটিং মনে করিয়ে দিও।') as ReminderAdd;
      expect(c.at, DateTime(2026, 10, 14, 10, 0));
      expect(parseWhen('সাড়ে আটটায় ওষুধ', now)!.at, DateTime(2026, 10, 13, 20, 30));
    });

    test('“৩০ মিনিট আগে” / “১ ঘণ্টা আগে” adds an early notice; the main time is untouched', () {
      final p = Parser(ledger: const [], now: now);
      final a = p.parse('কাল সকাল ১০টায় মিটিং, ৩০ মিনিট আগে মনে করিয়ে দিও') as ReminderAdd;
      expect(a.at, DateTime(2026, 10, 14, 10, 0));
      expect(a.minutesBefore, 30);
      expect(a.title, 'মিটিং');
      final b = p.parse('বিকেল ৫টায় ডাক্তারের কাছে যাওয়া মনে করিয়ে দিও, এক ঘণ্টা আগে') as ReminderAdd;
      expect(b.minutesBefore, 60);
      expect(b.at.hour, 17);
      expect((p.parse('কাল সকাল ৯টায় ফ্লাইট মনে করিয়ে দিও আড়াই ঘণ্টা আগে') as ReminderAdd).minutesBefore, 150);
      // "৩০ মিনিট পরে" is still a time from now, not an early notice.
      final c = p.parse('৩০ মিনিট পরে চা খাওয়ার কথা মনে করিয়ে দিও') as ReminderAdd;
      expect(c.minutesBefore, 0);
      // The notices: the early one 30 minutes before, every day for a daily one.
      final r = Reminder(id: 'x', title: 'ওষুধ', date: DateTime(2026, 10, 13), hour: 21, repeat: Repeat.daily, minutesBefore: 30);
      final ns = plannedNotices([r], now);
      expect(ns.map((n) => n.at), containsAll([DateTime(2026, 10, 13, 21, 0), DateTime(2026, 10, 13, 20, 30)]));
      expect(ns.firstWhere((n) => n.early).repeat, NoticeRepeat.daily);
      expect(Reminder.fromJson(r.toJson()).minutesBefore, 30);
    });

    test('“আমার সংরক্ষিত ফোন নম্বর দেখাও” is a look, not a save', () {
      final c = Parser(ledger: const [], now: now).parse('আমার সংরক্ষিত ফোন নম্বর দেখাও।');
      expect(c, isA<ContactsQuery>());
      expect(isSave(c), isFalse);
      expect(Parser(ledger: const [], now: now).parse('রহিমের নম্বর দেখাও'), isNot(isA<ContactsQuery>()));
      final d = AppData(contacts: [Contact(name: 'রহিম', phone: '01712345678')]);
      expect(answerText(d, c, now), contains('১ জনের নম্বর'));
    });

    test('recogniser errors become plain Bengali advice', () {
      expect(voiceErrorMessage('error_permission'), contains('Microphone'));
      expect(voiceErrorMessage('error_network'), contains('ইন্টারনেট'));
      expect(voiceErrorMessage('error_language_not_supported'), contains('বাংলা'));
      expect(voiceErrorMessage('error_audio_error'), contains('মাইক্রোফোন'));
      expect(voiceErrorMessage('anything'), contains('আবার চেষ্টা'));
    });
  });

  group('alarms and documents', () {
    final now = DateTime(2026, 10, 13, 18, 0); // Tuesday

    test('a weekly alarm rings on its days; a switched-off one does not ring', () {
      final r = Reminder(title: 'অফিস', date: DateTime(2026, 10, 13), hour: 7, repeat: Repeat.weekly, alarm: true,
          weekdays: const [DateTime.saturday, DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday]);
      expect(r.notifyAt(now), DateTime(2026, 10, 14, 7, 0)); // Wednesday morning
      final fri = Reminder(title: 'জুমা', date: DateTime(2026, 10, 13), hour: 12, repeat: Repeat.weekly, weekdays: const [DateTime.friday]);
      expect(fri.notifyAt(now), DateTime(2026, 10, 16, 12, 0));
      final notices = plannedNotices([r, fri, r.copyWith(enabled: false)], now);
      expect(notices.where((n) => n.reminderId == r.id), hasLength(6));
      expect(notices.every((n) => n.repeat == NoticeRepeat.weekly), isTrue);
      expect(notices.every((n) => n.at.isAfter(now)), isTrue);
      final back = Reminder.fromJson(r.copyWith(enabled: false).toJson());
      expect(back.enabled, isFalse);
      expect(back.alarm, isTrue);
      expect(back.weekdays, hasLength(6));
    });

    test('"প্রতি শুক্রবার সকাল ৯টায় বাজারের অ্যালার্ম দাও" is a weekly alarm', () {
      final c = Parser(ledger: const [], now: now).parse('প্রতি শুক্রবার সকাল ৯টায় বাজারের অ্যালার্ম দাও') as ReminderAdd;
      expect(c.repeat, Repeat.weekly);
      expect(c.weekdays, [DateTime.friday]);
      expect(c.alarm, isTrue);
      expect(c.at, DateTime(2026, 10, 16, 9, 0));
    });

    test('documents survive saving', () {
      final d = AppData(docs: [
        Doc(title: 'পাসপোর্ট', folder: 'পাসপোর্ট', files: [DocFile(name: 'p1.jpg', mime: 'image/jpeg', size: 1200)], fields: const [DocField('নম্বর', 'A123')], expiry: DateTime(2030, 1, 5)),
      ]);
      final back = AppData.fromJson(d.toJson()).docs.single;
      expect(back.files.single.isImage, isTrue);
      expect(back.fields.single.value, 'A123');
      expect(back.expiry, DateTime(2030, 1, 5));
    });
  });

  group('v2.9: assistant, days, money', () {
    final now = DateTime(2026, 10, 13, 9, 30);
    Command say(String t, [List<LedgerEntry> l = const []]) => Parser(ledger: l, now: now).parse(t);

    test('special days: birthdays, anniversaries and death anniversaries are understood', () {
      final b = say('রহিমের জন্মদিন ১২ মার্চ') as SpecialAdd;
      expect(b.person, 'রহিম');
      expect(b.kind, SpecialKind.birthday);
      expect((b.month, b.day), (3, 12));
      final a = say('আমাদের বিবাহবার্ষিকী ৫ জানুয়ারি ২০১৫') as SpecialAdd;
      expect(a.kind, SpecialKind.anniversary);
      expect(a.year, 2015);
      final d = say('আব্বার মৃত্যুবার্ষিকী ৩ জুন') as SpecialAdd;
      expect(d.person, 'আব্বা');
      expect(d.kind, SpecialKind.deathday);
      final n = say('মনে রাখো সুমির জন্মদিন ২২/৮') as SpecialAdd;
      expect((n.person, n.month, n.day), ('সুমি', 8, 22));
      // A question is not a new special day.
      expect(say('রহিমের জন্মদিন কবে?'), isNot(isA<SpecialAdd>()));
    });

    test('a special day comes back every year and rings the day before', () {
      final s = SpecialDay(person: 'রহিম', month: 3, day: 12, year: 1990);
      expect(s.next(now), DateTime(2027, 3, 12));
      expect(s.yearsOn(s.next(now)), 37);
      expect(specialTitle(s, on: s.next(now)), 'রহিমের জন্মদিন (৩৭ বছর)');
      final leap = SpecialDay(person: 'ক', month: 2, day: 29);
      expect(leap.next(DateTime(2027, 1, 1)), DateTime(2027, 2, 28));
      final ours = SpecialDay(person: 'আমাদের', kind: SpecialKind.anniversary, month: 1, day: 5);
      expect(specialTitle(ours), 'আমাদের বিবাহবার্ষিকী');
      final back = SpecialDay.fromJson(s.toJson());
      expect((back.person, back.month, back.day, back.year), ('রহিম', 3, 12, 1990));
    });

    test('things about the user become memories, plain facts stay notes', () {
      expect(say('মনে রেখো রহিম আমার শ্যালক'), isA<MemoryAdd>());
      expect(say('মনে রাখো আমি শুক্রবার অফিস করি না'), isA<MemoryAdd>());
      expect(say('মনে রাখো গাড়ির কাগজ আলমারিতে'), isA<NoteAdd>());
      expect(say('মনে রাখো আমার গাড়ির নম্বর ঢাকা মেট্রো গ ১২'), isA<NoteAdd>());
    });

    test('"গত মাসে রহিমকে কত দিলাম?" sums only last month', () {
      final l = [
        e('রহিম', LedgerKind.lent, 2000, DateTime(2026, 9, 5)),
        e('রহিম', LedgerKind.lent, 500, DateTime(2026, 9, 20)),
        e('রহিম', LedgerKind.received, 300, DateTime(2026, 9, 25)),
        e('রহিম', LedgerKind.lent, 1000, DateTime(2026, 10, 2)),
      ];
      final q = say('গত মাসে রহিমকে কত দিলাম?', l);
      expect(q, isA<LedgerQuery>());
      final a = ledgerAnswer(AppData(ledger: l), q as LedgerQuery, now);
      expect(a, contains('২,৫০০'));
      expect(a, contains('৩০০'));
      expect(a, contains('৩ বার'));
    });

    test('morning summary and nudges are planned from the records', () {
      final d = AppData(
        reminders: [
          Reminder(title: 'মিটিং', date: DateTime(2026, 10, 14), hour: 11),
          Reminder(title: 'বিদ্যুৎ বিল', date: DateTime(2026, 10, 20), hour: 10),
        ],
        tasks: [Task(title: 'ব্যাংকে যাওয়া', due: DateTime(2026, 10, 13))],
        ledger: [e('করিম', LedgerKind.lent, 800, DateTime(2026, 9, 1))],
        docs: [Doc(title: 'পাসপোর্ট', expiry: DateTime(2027, 6, 1))],
        medicines: [Medicine(name: 'নাপা', times: [540, 1260], stock: 6)],
        specialDays: [SpecialDay(person: 'সুমি', month: 10, day: 14)],
      );
      final n = assistantNotices(d, now, const AssistantPrefs());
      final morning = n.where((x) => x.reminderId == morningTag).toList();
      expect(morning.first.at, DateTime(2026, 10, 14, 8, 0)); // today's 8:00 has passed
      expect(morning.first.body, contains('মিটিং'));
      expect(morning.first.body, contains('সুমি'));
      final night = n.firstWhere((x) => x.reminderId == nightTag);
      expect(night.at, DateTime(2026, 10, 13, 21, 0));
      expect(night.title, contains('১টা কাজ'));
      final due = n.firstWhere((x) => x.reminderId.startsWith(nudgeDue));
      expect(due.at, DateTime(2026, 10, 31, 10, 0)); // 60 days after the last entry
      expect(n.firstWhere((x) => x.reminderId.startsWith(nudgeBill)).at, DateTime(2026, 10, 18, 10, 0));
      expect(n.firstWhere((x) => x.reminderId.startsWith(nudgeDoc)).at, DateTime(2026, 12, 1, 10, 0)); // six months before
      expect(n.any((x) => x.reminderId.startsWith(nudgeMed)), isTrue); // 6 pills, 2 a day = 3 days
      expect(n.every((x) => x.gentle && x.at.isAfter(now)), isTrue);
      final off = assistantNotices(d, now, const AssistantPrefs(morningOn: false, nightOn: false, nudgesOn: false));
      expect(off.where((x) => [morningTag, nightTag, nudgeDue, nudgeBill, nudgeDoc, nudgeMed].any((t) => x.reminderId.startsWith(t))), isEmpty);
      // Every kind switched off: nothing at all.
      final none = assistantNotices(d, now,
          const AssistantPrefs(morningOn: false, nightOn: false, nudgesOn: false, jumuah: false, health: false, festival: false, weekly: false, streak: false, comeback: false, plan: false, smart: false));
      expect(none, isEmpty);
    });

    test('habits count days in a row; medicines count days left', () {
      final h = Habit(name: 'হাঁটা', done: ['2026-10-10', '2026-10-11', '2026-10-12']);
      expect(h.streak(now), 3);
      expect(h.copyWith(done: [...h.done, '2026-10-13']).streak(now), 4);
      expect(h.best(), 3);
      final m = Medicine(name: 'নাপা', times: [540, 1260], dose: 1, stock: 9);
      expect(m.daysLeft, 4);
    });

    test('accounts, transfers, the monthly report, splitting and zakat', () {
      final bkash = MoneyAccount(id: 'b', name: '', kind: AccountKind.bkash, opening: 5000);
      final cash = MoneyAccount(id: 'c', name: 'পকেট', kind: AccountKind.cash, opening: 1000);
      final d = AppData(
        accounts: [bkash, cash],
        cash: [
          CashEntry(kind: CashKind.expense, amount: 700, category: 'বাজার', date: DateTime(2026, 10, 2), accountId: 'c'),
          CashEntry(kind: CashKind.expense, amount: 300, category: 'যাতায়াত', date: DateTime(2026, 10, 3)),
          CashEntry(kind: CashKind.expense, amount: 400, category: 'বাজার', date: DateTime(2026, 9, 3)),
          CashEntry(kind: CashKind.income, amount: 20000, category: 'বেতন', date: DateTime(2026, 10, 1), accountId: 'b'),
        ],
        transfers: [Transfer(from: 'b', to: 'c', amount: 2000, fee: 37, date: DateTime(2026, 10, 4))],
      );
      expect(accountBalance(d, bkash), 5000 + 20000 - 2000 - 37);
      expect(accountBalance(d, cash), 1000 - 700 + 2000);
      final r = monthReport(d, DateTime(2026, 10));
      expect(r.expense, 1000);
      expect(r.byCategory.first.key, 'বাজার');
      expect(r.biggestRise!.key, 'বাজার');
      expect(reportInsights(r).first, contains('বাজার'));
      expect(splitAmounts(1000, 3), [334, 333, 333]);
      const z = ZakatInput(cash: 100000, bank: 50000, debts: 10000, nisab: 80000);
      expect(z.zakat, 3500);
      expect(const ZakatInput(cash: 50000, nisab: 80000).due, isFalse);
    });

    test('a receipt adds up and shows what is still due', () {
      final t = receiptText(shop: 'রহিম স্টোর', customer: 'করিম', lines: const [ReceiptLine('চাল', 5, 70), ReceiptLine('ডাল', 2, 120)], paid: 500, date: now, no: 7);
      expect(t, contains('মোট: ৳৫৯০'));
      expect(t, contains('বাকি: ৳৯০'));
      expect(t, contains('#৭'));
    });

    test('everything new survives saving', () {
      final d = AppData(
        specialDays: [SpecialDay(person: 'রহিম', month: 3, day: 12)],
        memories: [Memory(text: 'আমি চা খাই না')],
        habits: [Habit(name: 'হাঁটা', done: ['2026-10-12'])],
        medicines: [Medicine(name: 'নাপা', times: [540])],
        accounts: [MoneyAccount(name: 'বিকাশ', kind: AccountKind.bkash, opening: 10)],
        goals: [SavingsGoal(name: 'ঈদ', target: 20000, deposits: [GoalDeposit(500, now)])],
        installments: [Installment(name: 'DPS', amount: 1000, start: DateTime(2026, 1), paid: ['2026-01'])],
        tags: {'note:x': ['গাড়ি']},
        emergency: const EmergencyCard(blood: 'B+', contacts: ['মা|01711111111|মা']),
        tasks: [Task(title: 'সেমাই', list: 'ঈদের কেনাকাটা')],
      );
      final b = AppData.fromJson(d.toJson());
      expect(b.specialDays.single.person, 'রহিম');
      expect(b.memories.single.text, 'আমি চা খাই না');
      expect(b.habits.single.done, ['2026-10-12']);
      expect(b.medicines.single.times, [540]);
      expect(b.accounts.single.kind, AccountKind.bkash);
      expect(b.goals.single.saved, 500);
      expect(b.installments.single.left, 11);
      expect(b.tags['note:x'], ['গাড়ি']);
      expect(b.emergency.blood, 'B+');
      expect(b.tasks.single.list, 'ঈদের কেনাকাটা');
      // Old files without the new parts still open.
      expect(AppData.fromJson({'schema': 1}).specialDays, isEmpty);
    });

    test('every kind of user gets lists that exist', () {
      for (final p in personas) {
        for (final l in personaSetup(p.$1).lists) {
          expect(listTemplates.any((t) => t.name == l), isTrue, reason: l);
        }
      }
    });

    test('English: dates, numbers and words switch, Bangla stays the default', () {
      expect(isEn, isFalse);
      isEn = true;
      try {
        expect(bnDigits(1050), '1050');
        expect(fullDate(DateTime(2026, 10, 9)), '9 October 2026');
        expect(bnTime(18, 20), '6:20 PM');
        expect(tr('সেটিংস'), 'Settings');
        expect(trf('{0}টি লেনদেন', [3]), '3 transactions');
        expect(tr('এমন কোনো লেখা নেই যা অনুবাদ হয়নি'), 'এমন কোনো লেখা নেই যা অনুবাদ হয়নি');
      } finally {
        isEn = false;
      }
      expect(fullDate(DateTime(2026, 10, 9)), '৯ অক্টোবর ২০২৬');
    });
  });

  group('v2.10: Hijri date, early notices', () {
    test('Hijri date follows the Bangladesh calendar, with a correction', () {
      final h = hijriDate(DateTime(2026, 10, 13), adjust: 0);
      expect((h.year, h.month, h.day), (1448, 5, 1));
      expect(h.text, '১ জমাদিউল আউয়াল ১৪৪৮ হিজরি');
      expect(hijriDate(DateTime(2026, 8, 26), adjust: 0).dayMonth, '১২ রবিউল আউয়াল');
      expect(hijriDate(DateTime(2026, 6, 26), adjust: 0).dayMonth, '১০ মহররম');
      expect(hijriDate(DateTime(2026, 10, 13), adjust: -1).day, 29);
      expect(hijriDate(DateTime(2027, 2, 10), adjust: 0).isRamadan, isTrue);
      final c = Parser(ledger: const [], now: DateTime(2026, 10, 14, 9)).parse('আজ আরবি তারিখ কত?');
      expect(c, isA<SmallTalk>());
      expect(talkReply((c as SmallTalk).kind, DateTime(2026, 10, 14, 9)), allOf(contains('আরবি তারিখ'), contains('হিজরি'), contains('আশ্বিন')));
    });
  });

  group('v2.10: notification plan', () {
    final now = DateTime(2026, 10, 14, 9, 0); // Wednesday
    test('quiet hours move nudges to the morning; the daily cap keeps the most useful', () {
      final d = AppData(
        ledger: [for (final n in ['রহিম', 'করিম', 'সজীব', 'রনি']) LedgerEntry(person: n, kind: LedgerKind.lent, amount: 500, date: DateTime(2026, 9, 15))],
        habits: [Habit(name: 'হাঁটা', done: ['2026-10-12', '2026-10-13'])],
      );
      final p = AssistantPrefs(morningOn: false, nightOn: false, dailyCap: 3, plan: false, smart: false, lastOpen: DateTime(2026, 10, 14), prayers: const {'fajr'});
      final ns = assistantNotices(d, now, p);
      // Four people owe for 30 days on 15 Oct: only three nudges that day (the cap), and the habit note today.
      final dues = ns.where((n) => n.reminderId.startsWith(nudgeDue)).toList();
      expect(dues.length, 3);
      expect(dues.every((n) => n.at == DateTime(2026, 10, 15, 10)), isTrue);
      expect(ns.where((n) => n.reminderId.startsWith(nudgeHabit)).single.at, DateTime(2026, 10, 14, 20));
      // Fajr is in the quiet hours but was asked for, so it stays at its time.
      final fajr = ns.where((n) => n.reminderId.startsWith(nudgePrayer)).first;
      expect(fajr.at.hour, lessThan(6));
      // Friday's note and the comeback note (3 days after the last open) are planned.
      expect(ns.any((n) => n.reminderId == nudgeJumuah && n.at == DateTime(2026, 10, 16, 11)), isTrue);
      expect(ns.any((n) => n.reminderId == nudgeBack && n.at == DateTime(2026, 10, 17, 10, 30)), isTrue);
      // A nudge set inside the quiet hours waits for their end.
      final late = assistantNotices(AppData(habits: [Habit(name: 'পড়া', done: ['2026-10-12', '2026-10-13'])]), now,
          const AssistantPrefs(morningOn: false, nightOn: false, quietFrom: 19 * 60, quietTo: 7 * 60, jumuah: false, comeback: false, weekly: false, health: false, festival: false, plan: false, smart: false));
      expect(late.single.at, DateTime(2026, 10, 15, 7));
    });

    test('Ramadan times only in Ramadan, and only when asked for', () {
      final r = DateTime(2027, 2, 15, 9);
      expect(hijriDate(r).isRamadan, isTrue);
      final on = assistantNotices(AppData(), r, const AssistantPrefs(morningOn: false, nightOn: false, ramadan: true));
      expect(on.where((n) => n.reminderId.startsWith(nudgeRamadan)).length, greaterThanOrEqualTo(3));
      final off = assistantNotices(AppData(), r, const AssistantPrefs(morningOn: false, nightOn: false));
      expect(off.where((n) => n.reminderId.startsWith(nudgeRamadan)), isEmpty);
      expect(assistantNotices(AppData(), now, const AssistantPrefs(morningOn: false, nightOn: false, ramadan: true)).where((n) => n.reminderId.startsWith(nudgeRamadan)), isEmpty);
    });
  });

  group('v2.10: photos and papers found by asking', () {
    final now = DateTime(2026, 10, 14, 10);
    final d = AppData(docs: [
      Doc(id: 'p', title: 'রুমার পাসপোর্ট', folder: 'পাসপোর্ট', files: [DocFile(name: 'a.jpg', mime: 'image/jpeg', size: 10)]),
      Doc(id: 'w', title: 'ভাইয়ের বিয়ে', folder: 'পরিবারের ছবি', about: 'গায়ে হলুদ আর বিয়ের দিনের ছবি', people: 'ভাইয়া, ভাবি', place: 'ফেনী', taken: DateTime(2025, 12, 20),
          files: [for (var i = 0; i < 3; i++) DocFile(name: '$i.jpg', mime: 'image/jpeg', size: 10)]),
      Doc(id: 'h', title: 'গায়ে হলুদ', folder: 'পরিবারের ছবি', about: 'বিয়ের আগের দিন', files: [DocFile(name: 'h.jpg', mime: 'image/jpeg', size: 10)]),
    ]);
    test('asking for a passport photo finds it, and the answer names it', () {
      final c = Parser(ledger: const [], now: now).parse('আমার পাসপোর্টের ছবি দেখাও');
      expect(c, isA<SearchQuery>());
      expect(searchAll(d, (c as SearchQuery).terms).first, isA<DocHit>());
      expect(answerText(d, c, now), contains('রুমার পাসপোর্ট'));
    });
    test('the description, people, place and year are searched too', () {
      final c = Parser(ledger: const [], now: now).parse('বিয়ের ছবিগুলো দেখাও') as SearchQuery;
      final docs = [for (final h in searchAll(d, c.terms)) if (h is DocHit) h.doc.id];
      expect(docs, containsAll(['w', 'h']));
      expect(answerText(d, c, now), contains('২টা মিলেছে'));
      expect(searchAll(d, ['ফেনী']).whereType<DocHit>().single.doc.id, 'w');
      expect(searchAll(d, ['2025']).whereType<DocHit>().single.doc.id, 'w');
      expect(Doc.fromJson(d.docs[1].toJson()).people, 'ভাইয়া, ভাবি');
      expect(Note.fromJson(Note(title: 'x', files: [DocFile(name: 'n.pdf', mime: 'application/pdf', size: 1)]).toJson()).files.single.name, 'n.pdf');
    });
  });

  group('v2.10: plans for a day are to-dos', () {
    final now = DateTime(2026, 10, 14, 10);
    final p = Parser(ledger: const [], now: now);
    test('“আমি কাল বাজারে যাবো” is saved as tomorrow\'s to-do; with a clock time, a reminder', () {
      final a = p.parse('আমি কাল বাজারে যাবো') as TaskAdd;
      expect((a.title, a.due), ('বাজারে যাবো', DateTime(2026, 10, 15)));
      expect((p.parse('কাল ডাক্তারের অ্যাপয়েন্টমেন্ট আছে') as TaskAdd).due, DateTime(2026, 10, 15));
      final r = p.parse('কাল সকাল ১০টায় ব্যাংকে যাবো') as ReminderAdd;
      expect(r.at, DateTime(2026, 10, 15, 10));
      // Money promised for a day is not a payment made.
      final m = p.parse('কাল রহিমকে ৫০০ টাকা দেবো') as TaskAdd;
      expect(m.title, 'রহিমকে ৫০০ টাকা দেবো');
      expect(p.parse('রহিমকে ৫০০ টাকা দিলাম'), isA<LedgerAdd>());
      expect(p.parse('আজ কী কী আছে'), isA<Briefing>());
    });
  });

  group('v2.10: health', () {
    final now = DateTime(2026, 10, 14, 9);
    test('BMI by the Asian cut-offs, healthy weight range, BP and sugar levels', () {
      final b = bmiOf(70, 168);
      expect(b, closeTo(24.8, 0.1));
      expect(bmiLevel(b).$1, Level.watch); // 23–27.4 is "a little high" for South Asians
      expect(bmiLevel(22.0).$1, Level.ok);
      expect(healthyWeight(168), (53, 64));
      expect(bpLevel(118, 76).$1, Level.ok);
      expect(bpLevel(145, 92).$1, Level.high);
      expect(bpLevel(185, 100).$1, Level.urgent);
      expect(sugarLevel(5.2, fasting: true).$1, Level.ok);
      expect(sugarLevel(7.4, fasting: true).$1, isNot(Level.ok));
      expect(sugarLevel(toMmol(140), fasting: false).$1, Level.ok); // 140 mg/dL = 7.8 mmol/L boundary
      expect(sugarLevel(2.5, fasting: false).$1, Level.urgent);
    });
    test('said aloud: weight, pressure, sugar, water — and questions about them', () {
      final p = Parser(ledger: const [], now: now);
      final w = p.parse('আজ ওজন ৬৮ কেজি') as HealthAdd;
      expect((w.kind, w.a), (HealthKind.weight, 68.0));
      final bp = p.parse('প্রেশার ১৪০ বাই ৯০') as HealthAdd;
      expect((bp.kind, bp.a, bp.b), (HealthKind.bp, 140.0, 90.0));
      final s = p.parse('খালি পেটে সুগার ৭.২') as HealthAdd;
      expect((s.kind, s.a, s.tag), (HealthKind.sugar, 7.2, 'fasting'));
      expect((p.parse('২ গ্লাস পানি খেলাম') as HealthAdd).kind, HealthKind.water);
      expect(p.parse('আমার বিএমআই কত'), isA<HealthQuery>());
      final d = AppData(
        members: [FamilyMember(id: FamilyMember.meId, name: 'আমি', heightCm: 168)],
        health: [
          HealthLog(kind: HealthKind.weight, at: DateTime(2026, 9, 10), a: 72),
          HealthLog(kind: HealthKind.weight, at: DateTime(2026, 10, 13), a: 70),
        ],
      );
      expect(healthAnswer(d, 'bmi', now), allOf(contains('২৪.৮'), contains('৫৩–৬৪')));
      expect(healthAnswer(d, 'weight', now), contains('কমেছে'));
    });
    test('a child\'s vaccine card follows the EPI days', () {
      final baby = FamilyMember(name: 'আয়ান', birth: DateTime(2026, 9, 1));
      expect(needsVaccineCard(baby, now), isTrue);
      final penta1 = epiSchedule.firstWhere((v) => v.key == 'penta1');
      expect(doseDay(baby, penta1), DateTime(2026, 10, 13));
      expect(epiSchedule.where((v) => v.key.startsWith('mr')).length, 2);
    });
  });

  group('the app map: open any part by voice, and sensible answers', () {
    final now = DateTime(2026, 10, 14, 10);
    Command parse(String t, {List<FolderHint> folders = const []}) => Parser(ledger: const [], folders: folders, now: now).parse(t);
    test('"নোট খোলো", "সেটিংসে যাও", a folder — each opens its page', () {
      expect((parse('নোট খোলো') as OpenPlace).place, 'notes');
      expect((parse('সেটিংসে যাও') as OpenPlace).place, 'settings');
      expect((parse('আমার ওষুধের পাতা খুলে দাও') as OpenPlace).place, 'medicines');
      expect((parse('স্বাস্থ্যের পাতায় নিয়ে যাও') as OpenPlace).place, 'health');
      expect((parse('কাজের তালিকা খোলো') as OpenPlace).place, 'tasks');
      expect((parse('লেনদেন খোলো') as OpenPlace).place, 'ledger');
      expect((parse('আয় ব্যয় খোলো') as OpenPlace).place, 'money');
      expect((parse('open settings') as OpenPlace).place, 'settings');
      final f = parse('প্রেসক্রিপশন ফোল্ডার দেখাও') as OpenPlace;
      expect((f.place, f.folder), ('docs', 'প্রেসক্রিপশন'));
      final mine = parse('দোকানের মাল খোলো', folders: const [FolderHint('notes', 'দোকানের মাল')]) as OpenPlace;
      expect((mine.place, mine.folder), ('notes', 'দোকানের মাল'));
    });
    test('questions and requests are not mistaken for opening a page', () {
      expect(parse('রিমাইন্ডার দেখাও'), isNot(isA<OpenPlace>()));
      expect(parse('ফেসবুকের পাসওয়ার্ড খোলো'), isNot(isA<OpenPlace>()));
      expect(parse('রহিমের হিসাব খোলো'), isNot(isA<OpenPlace>()));
      expect(parse('আমার বিএমআই কত'), isA<HealthQuery>());
      expect(parse('আমি কাল বাজারে যাবো'), isA<TaskAdd>());
      expect(parse('রহিমকে ফোন দাও'), isA<CallPerson>());
    });
    test('every part has a page id, a name and what it does; the help list is complete', () {
      expect({for (final p in appPlaces) p.id}.length, appPlaces.length);
      for (final p in appPlaces) {
        expect(p.title.isNotEmpty && p.what.isNotEmpty && p.words.isNotEmpty, isTrue, reason: p.id);
      }
      expect(capabilitiesList(), allOf(contains('স্বাস্থ্য'), contains('ডকুমেন্টস'), contains('পাসওয়ার্ড')));
      expect(talkReply(Talk.whatCanYouDo, now), contains('খোলো'));
    });
    test('no zero amounts; income minus spending is the balance', () {
      final owed = AppData(ledger: [e('সজীব', LedgerKind.lent, 1000, now)]);
      final all = ledgerAnswer(owed, const LedgerQuery('হিসাব', ask: LedgerAsk.all), now);
      expect(all, contains('১,০০০'));
      expect(all, isNot(contains('০ টাকা দিতে')));
      expect(ledgerAnswer(AppData(), const LedgerQuery('হিসাব', ask: LedgerAsk.all), now), contains('কোনো পাওনা-দেনা নেই'));
      final d = AppData(cash: [
        CashEntry(kind: CashKind.income, amount: 30000, category: 'বেতন', date: DateTime(2026, 10, 1)),
        CashEntry(kind: CashKind.expense, amount: 1700, category: 'বাজার', date: DateTime(2026, 10, 5)),
      ]);
      final m = cashAnswer(d, const CashQuery('এই মাসে কত খরচ'), now);
      expect(m, contains('ব্যালেন্স'));
      expect(m, isNot(contains('সঞ্চয়')));
      final spentOnly = AppData(cash: [CashEntry(kind: CashKind.expense, amount: 500, category: 'বাজার', date: DateTime(2026, 10, 5))]);
      expect(cashAnswer(spentOnly, const CashQuery('খরচ'), now), allOf(contains('খরচ হয়েছে ৫০০'), isNot(contains('আয়'))));
    });
  });

  group('answers that fit the question', () {
    final now = DateTime(2026, 10, 14, 10);
    Command parse(String t) => Parser(ledger: const [], now: now).parse(t);
    String ask(AppData d, String t) => answerText(d, parse(t), now) ?? '';
    test('blood group: said, kept, asked — for the user and family', () {
      expect(bloodIn(normalize('আমার ব্লাড গ্রুপ বি পজিটিভ')), 'B+');
      expect(bloodIn(normalize('ও নেগেটিভ')), 'O−');
      expect(bloodIn(normalize('my blood group is AB+')), 'AB+');
      final set = parse('আমার ব্লাড গ্রুপ বি পজিটিভ') as ProfileSet;
      expect((set.field, set.value, set.who), ('blood', 'B+', ''));
      final mum = parse('আম্মার রক্তের গ্রুপ ও নেগেটিভ') as ProfileSet;
      expect((mum.value, mum.who), ('O−', 'আম্মা'));
      expect(ask(AppData(), 'আমার ব্লাড গ্রুপ কি'), allOf(contains('কোনো তথ্য নেই'), contains('যুক্ত করতে পারেন')));
      final d = AppData(emergency: const EmergencyCard(blood: 'B+'), members: [FamilyMember(name: 'রহিমা', relation: 'আম্মা', blood: 'O−')]);
      expect(ask(d, 'আমার ব্লাড গ্রুপ কি'), contains('বি পজিটিভ'));
      expect(ask(d, 'আম্মার রক্তের গ্রুপ কী'), contains('ও নেগেটিভ'));
    });
    test('height, age, photos: answered from what is kept', () {
      final h = parse('আমার উচ্চতা ৫ ফুট ৬ ইঞ্চি') as ProfileSet;
      expect(double.parse(h.value), closeTo(167.6, 0.1));
      expect(ask(AppData(), 'আমার উচ্চতা কত'), allOf(contains('উচ্চতার কোনো তথ্য নেই'), isNot(contains('লেখা নেই'))));
      final d = AppData(members: [FamilyMember(id: FamilyMember.meId, name: 'আমি', heightCm: 167.6, birth: DateTime(1990, 1, 1))]);
      expect(ask(d, 'আমার উচ্চতা কত'), contains('৫ ফুট'));
      expect(ask(d, 'আমার বয়স কত'), contains('৩৬'));
      expect(ask(AppData(), 'আমার কোন ছবি আছে'), contains('কোনো ছবি রাখা নেই'));
      final pics = AppData(docs: [Doc(title: 'ঈদের ছবি', folder: 'পরিবারের ছবি', files: [DocFile(name: 'a.jpg', mime: 'image/jpeg', size: 10)])]);
      expect(ask(pics, 'আমার কোন ছবি আছে'), contains('ঈদের ছবি'));
    });
    test('everyday questions: prayer, sehri, tomorrow, money, medicines, expiry', () {
      expect(ask(AppData(), 'নামাজের সময় কখন'), allOf(contains('ফজর'), contains('মাগরিব')));
      expect(ask(AppData(), 'আজ সেহরি কখন'), contains('সেহরির শেষ সময়'));
      final d = AppData(
        medicines: [Medicine(name: 'নাপা', times: [540])],
        accounts: [MoneyAccount(name: 'বিকাশ', kind: AccountKind.bkash, opening: 5000)],
        docs: [Doc(title: 'পাসপোর্ট', folder: 'পাসপোর্ট', files: const [], expiry: DateTime(2028, 3, 12))],
        reminders: [Reminder(title: 'ডাক্তার', date: DateTime(2026, 10, 15), hour: 17, minute: 0)],
      );
      expect(ask(d, 'কাল কি আছে'), contains('ডাক্তার'));
      expect(ask(d, 'বিকাশে কত টাকা আছে'), contains('৫,০০০'));
      expect(ask(d, 'আমার কী কী ওষুধ আছে'), contains('নাপা'));
      expect(ask(d, 'আমার পাসপোর্টের মেয়াদ কবে'), contains('২০২৮'));
      expect(ask(AppData(), 'রহিমের নম্বর কত'), contains('রহিমের নম্বরের কোনো তথ্য নেই'));
      expect(parse('প্রতিদিন রাত ১০টায় ওষুধ'), isA<ReminderAdd>());
      expect(parse('আমার কয়টা নোট আছে'), isNot(isA<NoteAdd>()));
    });
    test('the app\'s own voice is told apart from the user\'s words', () {
      expect(echoToken('৫০০,'), '500');
      expect(echoToken('শুনছি।'), 'শুনছি');
    });
  });

  group('messages from other apps', () {
    final now = DateTime(2026, 10, 14, 10);
    InboxMessage msg(String text, {String app = 'com.whatsapp', String name = 'WhatsApp', String from = 'রহিম', bool group = false}) =>
        InboxMessage(id: text.hashCode.toString(), app: app, appName: name, chat: from, from: from, text: text, at: now.subtract(const Duration(minutes: 5)), group: group);
    test('a meeting time becomes a reminder; a date a to-do', () {
      final m = insightOf(msg('কাল বিকেল ৩টায় অফিসে মিটিং, চলে আসবেন'), now)!;
      expect(m.kind, InboxKind.meeting);
      final r = m.command as ReminderAdd;
      expect((r.at.day, r.at.hour), (15, 15));
      expect(insightOf(msg('বৃহস্পতিবার রিপোর্ট জমা দিতে হবে'), now)!.kind, InboxKind.deadline);
    });
    test('money asked for, and bKash money in or out', () {
      final ask = insightOf(msg('ভাই ৫০০০ টাকা পাঠাও, খুব দরকার'), now)!;
      expect(ask.kind, InboxKind.moneyAsk);
      expect((ask.command as TaskAdd).title, contains('৫,০০০'));
      final inn = insightOf(msg('You have received Tk 1,500.00 from 01712345678. TrxID 9ABC', app: 'com.google.android.apps.messaging', name: 'SMS', from: 'bKash'), now)!;
      expect(inn.kind, InboxKind.moneyIn);
      expect((inn.command as CashAdd).amount, 1500);
    });
    test('a question waits for a reply; ads and plain chat are left alone', () {
      expect(insightOf(msg('আপনি কি আজ দোকানে আসবেন?'), now)!.kind, InboxKind.reply);
      expect(insightOf(msg('৫০% ছাড়! আজই রিচার্জ করুন', app: 'com.google.android.apps.messaging', name: 'SMS', from: 'GP'), now), isNull);
      expect(insightOf(msg('আলহামদুলিল্লাহ ভালো আছি'), now), isNull);
    });
    test('voice: "হোয়াটসঅ্যাপে কী এসেছে?" and "রহিম কী লিখেছে?"', () {
      final d = AppData(inbox: [msg('ভাই ৫০০০ টাকা পাঠাও'), msg('কেমন আছেন', from: 'করিম')]);
      final p = Parser(ledger: const [], now: now);
      final q = p.parse('হোয়াটসঅ্যাপে কী এসেছে?');
      expect(q, isA<ProfileQuery>());
      expect(answerText(d, q, now), allOf(contains('৫,০০০'), contains('কাজের কথা')));
      expect(answerText(d, p.parse('রহিম কী লিখেছে?'), now), contains('পাঠাও'));
      expect(p.parse('করিমকে মেসেজ দাও যে কী লাগবে'), isA<CallPerson>());
      expect(answerText(AppData(), q, now), contains('কোনো মেসেজের তথ্য নেই'));
    });
  });

  group('one conversation: a follow-up changes how the last message is kept', () {
    final now = DateTime(2026, 10, 14, 17, 15);
    test('an appointment with a time is a reminder', () {
      final r = Parser(ledger: const [], now: now).parse('আজ ইব্রাহিম ভাই আসার কথা সন্ধ্যা ৭ টায়') as ReminderAdd;
      expect((r.at.hour, r.title), (19, 'ইব্রাহিম ভাই আসার কথা'));
    });
    test('"রিমাইন্ডার লিখে রাখো", "এটা কাজের তালিকায় রাখো", "না, নোট করো" are instructions about the last message', () {
      expect(redirectOf('রিমাইন্ডার লিখে রাখো'), 'reminder');
      expect(redirectOf('এটা কাজের তালিকায় রাখো'), 'task');
      expect(redirectOf('না, নোট করো'), 'note');
      expect(redirectOf('অ্যালার্ম দাও'), 'alarm');
      expect(redirectOf('কাল ১০টায় মিটিং মনে করিয়ে দিও'), isNull);
      final c = convertTo('reminder', 'আজ ইব্রাহিম ভাই আসার কথা সন্ধ্যা ৭ টায়', const [], now) as ReminderAdd;
      expect(c.at.hour, 19);
      expect((convertTo('reminder', 'গ্যাস বিল দেওয়া', const [], now) as ReminderAdd).needsTime, isTrue);
      expect(convertTo('task', 'কাল গ্যাস বিল দেওয়া', const [], now), isA<TaskAdd>());
    });
  });

  group('PDF reports', () {
    final now = DateTime(2026, 10, 15, 19, 40);
    String text(Map<String, Object?> spec) => '$spec';
    AppData data() => AppData(
          vault: [VaultItem(name: 'ব্যাংক', username: 'saif', password: 'gopon123')],
          notes: [Note(title: 'বাসার ঠিকানা', body: 'মিরপুর ১০'), Note(title: 'ATM পিন', body: '4321')],
          ledger: [
            LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 500, date: DateTime(2026, 10, 1)),
            LedgerEntry(person: 'করিম', kind: LedgerKind.borrowed, amount: 200, date: DateTime(2026, 10, 2)),
          ],
          cash: [
            CashEntry(kind: CashKind.income, amount: 30000, category: 'বেতন', date: DateTime(2026, 10, 1)),
            CashEntry(kind: CashKind.expense, amount: 1200, category: 'বাজার', note: 'চাল', date: DateTime(2026, 10, 3)),
            CashEntry(kind: CashKind.expense, amount: 900, category: 'বাজার', date: DateTime(2026, 9, 20)),
          ],
          tasks: [Task(title: 'গ্যাস বিল দেওয়া')],
        );

    test('everything: each part has its heading, and secrets stay out', () {
      final spec = reportSpec(data(), ReportPart.values.toSet(), now, userName: 'সাইফ');
      final all = text(spec);
      expect(spec['title'], 'সাইফের সব তথ্য');
      for (final p in ReportPart.values) {
        expect(all, contains("{t: h1, text: ${p.label}}"));
      }
      expect(all, isNot(contains('gopon123')));
      expect(all, isNot(contains('4321')));
      expect(all, contains('মিরপুর ১০'));
      expect(all, contains('১টি নোট এই PDF-এ রাখা হয়নি'));
      expect(all, contains('গ্যাস বিল দেওয়া'));
    });

    test('one person, one month, one part', () {
      final d = data();
      final key = balances(d.ledger).firstWhere((p) => p.name == 'রহিম').key;
      final rahim = text(reportSpec(d, {ReportPart.ledger}, now, scope: ReportScope(personKey: key)));
      expect(rahim, contains('রহিম'));
      expect(rahim, isNot(contains('করিম')));
      expect(rahim, contains('পাবেন ৳৫০০'));

      final oct = reportSpec(d, {ReportPart.money}, now, scope: ReportScope(month: DateTime(2026, 10)));
      expect(oct['title'], 'আয়-ব্যয়');
      expect(text(oct), contains('চাল'));
      expect(text(oct), contains('৳২৮,৮০০'));
      expect(text(oct), isNot(contains('৯০০}')));

      expect(reportFileName({ReportPart.money}, now), 'my-assistant-income-expense-20261015.pdf');
      expect(reportFileName(ReportPart.values.toSet(), now), 'my-assistant-all-20261015.pdf');
    });

    test('an empty part says so instead of a blank page', () {
      expect(text(reportSpec(AppData(), {ReportPart.contacts}, now)), contains('এখনো কিছু রাখা হয়নি'));
    });
  });

  group('plans and things noticed', () {
    // Thursday 15 Oct 2026, 7 pm. Durga Puja is 20–22 Oct (Tue–Thu).
    final now = DateTime(2026, 10, 15, 19, 0);
    const only = AssistantPrefs(morningOn: false, nightOn: false, nudgesOn: false, jumuah: false, health: false, festival: false, weekly: false, streak: false, comeback: false, smart: false, dailyCap: 20);

    test('the evening before a day off, a new week, a new month, and tomorrow at night', () {
      final n = assistantNotices(AppData(), now, only);
      final fri = n.firstWhere((x) => x.reminderId == '${nudgePlan}eve' && x.at == DateTime(2026, 10, 15, 20, 30));
      expect(fri.title, 'কাল থেকে সাপ্তাহিক ছুটি');
      final puja = n.firstWhere((x) => x.reminderId == '${nudgePlan}eve' && x.at == DateTime(2026, 10, 19, 20, 30));
      expect(puja.title, contains('৫ দিনের ছুটি')); // Tue–Thu plus the weekend
      expect(puja.title, contains('দুর্গাপূজা'));
      expect(n.any((x) => x.reminderId == '${nudgePlan}week' && x.at == DateTime(2026, 10, 18, 9, 15)), isTrue);
      expect(n.any((x) => x.reminderId == '${nudgePlan}month' && x.at == DateTime(2026, 11, 1, 9, 30)), isTrue);
      // Thursday's evening question already covers tonight; Friday night asks about Saturday.
      expect(n.where((x) => x.reminderId == '${nudgePlan}night' && x.at.day == 15), isEmpty);
      expect(n.firstWhere((x) => x.reminderId == '${nudgePlan}night').title, 'কালকের জন্য কিছু মনে রাখার আছে?');
      expect(assistantNotices(AppData(), now, const AssistantPrefs(morningOn: false, nightOn: false, nudgesOn: false, plan: false, smart: false, jumuah: false, health: false, festival: false, weekly: false, streak: false, comeback: false)), isEmpty);
    });

    test('a busy tomorrow is told at night, with the first thing', () {
      final wed = DateTime(2026, 10, 14, 18);
      final d = AppData(reminders: [
        for (final (h, t) in [(9, 'ব্যাংকে যাওয়া'), (12, 'মিটিং'), (17, 'ডাক্তার')]) Reminder(title: t, date: DateTime(2026, 10, 15), hour: h),
      ]);
      final night = assistantNotices(d, wed, only).firstWhere((x) => x.reminderId == '${nudgePlan}night');
      expect(night.title, 'কাল ৩টা কাজ/রিমাইন্ডার আছে');
      expect(night.body, contains('ব্যাংকে যাওয়া'));
    });

    test('no spending today, a category up, a birthday the day after tomorrow, salary, Eid ahead', () {
      const smart = AssistantPrefs(morningOn: false, nightOn: false, nudgesOn: false, jumuah: false, health: false, festival: false, weekly: false, streak: false, comeback: false, plan: false, dailyCap: 20);
      final d = AppData(
        cash: [
          for (final day in [10, 12, 14]) CashEntry(kind: CashKind.expense, amount: 100, category: 'যাতায়াত', date: DateTime(2026, 10, day)),
          CashEntry(kind: CashKind.expense, amount: 2000, category: 'বাজার', date: DateTime(2026, 9, 10)),
          CashEntry(kind: CashKind.expense, amount: 1500, category: 'বাজার', date: DateTime(2026, 10, 15)),
          CashEntry(kind: CashKind.expense, amount: 1500, category: 'বাজার', date: DateTime(2026, 10, 15)),
          CashEntry(kind: CashKind.income, amount: 40000, category: 'বেতন', date: DateTime(2026, 10, 15)),
        ],
        specialDays: [SpecialDay(person: 'রিমা', month: 10, day: 18)],
      );
      final n = assistantNotices(d, now, smart);
      expect(n.where((x) => x.reminderId == nudgeNoCash), isEmpty); // written today
      final spend = n.firstWhere((x) => x.reminderId == nudgeSpend);
      expect(spend.title, 'এ মাসে বাজার-এ খরচ বেশি');
      expect(spend.at, DateTime(2026, 10, 15, 19, 30));
      expect(n.firstWhere((x) => x.reminderId == nudgeDay2).title, contains('পরশু রিমার জন্মদিন'));
      expect(n.firstWhere((x) => x.reminderId == nudgeSalary).at, DateTime(2026, 10, 16, 10));

      final quiet = assistantNotices(AppData(cash: [for (final day in [10, 12, 14]) CashEntry(kind: CashKind.expense, amount: 100, date: DateTime(2026, 10, day))]), now, smart);
      expect(quiet.firstWhere((x) => x.reminderId == nudgeNoCash).at, DateTime(2026, 10, 15, 21, 15));

      final beforeEid = assistantNotices(AppData(), DateTime(2026, 5, 1), smart);
      expect(beforeEid.firstWhere((x) => x.title.contains('ঈদুল আজহা')).at, DateTime(2026, 5, 18, 10));
    });
  });

  group('alarms by voice', () {
    final night = DateTime(2026, 10, 15, 23, 0);
    ReminderAdd alarm(String s) => parseAll(s, const [], now: night).single as ReminderAdd;

    test('every common way of asking sets an alarm at the right time', () {
      for (final (said, at) in [
        ('কাল সকাল ৬টায় এলার্ম দাও', DateTime(2026, 10, 16, 6)),
        ('৬টায় এলার্ম দাও', DateTime(2026, 10, 16, 6)), // at 11 pm, the next 6 o'clock
        ('এলার্ম সেট কর ৭টা ৩০', DateTime(2026, 10, 16, 7, 30)),
        ('সাড়ে ছয়টায় এলার্ম দাও', DateTime(2026, 10, 16, 6, 30)),
        ('এলার্ম দিয়ে দাও ৬টা', DateTime(2026, 10, 16, 6)),
        ('কাল ভোর ৪টা ৩০ এ এলার্ম দিয়ে রাখো', DateTime(2026, 10, 16, 4, 30)),
        ('আমাকে ৬টায় ঘুম থেকে ডেকে দিও', DateTime(2026, 10, 16, 6)),
        ('৩০ মিনিট পর এলার্ম দিও', DateTime(2026, 10, 15, 23, 30)),
        ('alarm set koro 6 tay', DateTime(2026, 10, 16, 6)),
        ('ওষুধ খাওয়ার এলার্ম রাত ১০টায়', DateTime(2026, 10, 16, 22)),
      ]) {
        final a = alarm(said);
        expect(a.alarm, isTrue, reason: said);
        expect(a.at, at, reason: said);
      }
      expect(alarm('সাড়ে ছয়টায় এলার্ম দাও').title, 'অ্যালার্ম');
      expect(alarm('এলার্ম বাজাবে ৬টায়').title, 'অ্যালার্ম');
      expect(alarm('ওষুধ খাওয়ার এলার্ম রাত ১০টায়').title, 'ওষুধ খাওয়ার');
      expect(alarm('প্রতিদিন সকাল ৬টায় এলার্ম').repeat, Repeat.daily);
      expect(alarm('একটা এলার্ম দাও').needsTime, isTrue);
      expect(alarm('কাল সকালে এলার্ম দাও').needsTime, isTrue);
    });

    test('showing or switching off alarms opens the alarm page', () {
      for (final s in ['এলার্ম গুলো দেখাও', 'কাল কয়টায় এলার্ম আছে?', 'এলার্ম বন্ধ করো']) {
        expect((parseAll(s, const [], now: night).single as OpenPlace).place, 'alarms', reason: s);
      }
    });
  });

  group('suggestions while typing', () {
    final now = DateTime(2026, 10, 15, 21, 0);
    final d = AppData(contacts: [Contact(name: 'রহিম', phone: '01711000000')], reminders: [Reminder(title: 'গ্যাস বিল', date: DateTime(2026, 10, 20))]);

    test('a word or two gives full sentences the app understands', () {
      for (final typed in ['বিদ্যুৎ বিল', 'রহি', 'নাপা', 'প্রেশার', 'চাল', 'ডাক্তার', 'রহিমের জন্মদিন', 'এলার্ম', 'বেতন', 'গ্যাস', 'পাসপোর্ট', 'ছাদ মেরামত', 'বিক্রি', 'ধার', 'দোকান']) {
        final ps = suggestPrompts(typed, d);
        expect(ps, isNotEmpty, reason: typed);
        for (final p in ps) {
          if (p.endsWith('যে ')) continue; // "রহিমকে মেসেজ দাও যে …" waits for the message
          final c = parseAll(p, d.ledger, contacts: d.contacts, now: now);
          expect(c.any((x) => x is NotUnderstood || x is SearchQuery), isFalse, reason: '$typed → $p');
        }
      }
      expect(suggestPrompts('বিদ্যুৎ বিল', d).first, 'প্রতি মাসের ১০ তারিখে বিদ্যুৎ বিল দেওয়ার কথা মনে করিয়ে দিও');
      expect(suggestPrompts('রহি', d).first, 'রহিমকে ৫০০ টাকা ধার দিলাম');
    });

    test('nothing for an empty box, a full request, a question or a secret', () {
      for (final typed in ['', 'রহিমকে ৫০০ টাকা দিলাম', 'বিল কত?', 'ব্যাংকের পিন', 'এক দুই তিন চার পাঁচ']) {
        expect(suggestPrompts(typed, d), isEmpty, reason: typed);
      }
    });
  });

  group('required examples: money meaning, negatives, corrections, dates', () {
    final now = DateTime(2026, 10, 15, 21, 0);
    final sajib = [LedgerEntry(person: 'সজীব', kind: LedgerKind.lent, amount: 500, date: DateTime(2026, 10, 14))];
    Command one(String s, [List<LedgerEntry> l = const []]) => parseAll(s, l, now: now).first;

    test('who gave whom', () {
      expect((one('সজীবকে পাঁচশ টাকা ধার দিলাম') as LedgerAdd).kind, LedgerKind.lent);
      expect((one('সজীবকে পাঁচশ টাকা ধার দিলাম') as LedgerAdd).amount, 500);
      expect((one('সজীবের কাছ থেকে পাঁচশ টাকা ধার নিলাম') as LedgerAdd).kind, LedgerKind.borrowed);
      final back = one('সজীব সেই ধার থেকে তিনশ টাকা ফেরত দিল', sajib) as LedgerAdd;
      expect((back.person, back.amount, back.kind), ('সজীব', 300, LedgerKind.received));
      expect((one('সজীব ধার থেকে দুইশ ফেরত দিয়েছে', sajib) as LedgerAdd).kind, LedgerKind.received);
      expect((one('আমি সজীবকে ধার থেকে ২০০ টাকা ফেরত দিলাম', sajib) as LedgerAdd).kind, LedgerKind.repaid);
      // "দিলাম" alone: never guessed, the app asks.
      expect((one('সজীবকে পাঁচশ টাকা দিলাম') as LedgerAdd).needsChoice, isTrue);
      expect(one('সজীবের কাছে কত পাই?', sajib), isA<LedgerQuery>());
      expect(one('সজীবের কাছে ৫০০ টাকা পাই', sajib), isA<LedgerSet>());
    });

    test('amounts in words and digits are the same', () {
      for (final (s, n) in [('রহিমকে পাঁচশ টাকা ধার দিলাম', 500), ('রহিমকে 500 taka ধার দিলাম', 500), ('রহিমকে ৫০০ টাকা ধার দিলাম', 500), ('রহিমকে দেড় হাজার টাকা ধার দিলাম', 1500), ('রহিমকে আড়াইশ টাকা ধার দিলাম', 250), ('রহিমকে সাড়ে তিন হাজার টাকা ধার দিলাম', 3500)]) {
        expect((one(s) as LedgerAdd).amount, n, reason: s);
      }
    });

    test('negatives are not transactions; "বাদ দাও" deletes nothing', () {
      for (final s in ['সজীবকে টাকা দিইনি', 'সজীবকে ৫০০ টাকা দেইনি', 'সজীব টাকা ফেরত দেয়নি']) {
        expect(one(s, sajib), isA<SmallTalk>(), reason: s);
      }
      expect((one('বাদ দাও') as SmallTalk).kind, Talk.cancelled);
      expect(isCancel('থাক'), isTrue);
      expect(isCancel('থাকার জায়গা'), isFalse);
      // "নেই" about a balance: what the book says is shown, nothing settled or removed.
      expect(one('সজীবের আর কোনো টাকা বাকি নেই', sajib), isA<LedgerQuery>());
    });

    test('a correction is an edit, not a new entry', () {
      expect((one('আগের পাঁচশ নয়, সাতশ হবে', sajib) as ManageItem).action, 'edit');
      expect((one('৫০০ না ৭০০ হবে', sajib) as ManageItem).action, 'edit');
    });

    test('days: a reminder asks the hour; money said with a past day keeps that day', () {
      final r = one('কাল রাত আটটায় ওষুধ খেতে মনে করাইও') as ReminderAdd;
      expect((r.at, r.title), (DateTime(2026, 10, 16, 20), 'ওষুধ খেতে'));
      final noHour = one('কাল মনে করিয়ে দিও') as ReminderAdd;
      expect(noHour.needsTime, isTrue);
      expect(noHour.day, DateTime(2026, 10, 16));
      expect((one('আধা ঘণ্টা পরে মনে করিয়ে দিও') as ReminderAdd).at, DateTime(2026, 10, 15, 21, 30));
      expect((one('সজীবকে গতকাল পাঁচশ টাকা ধার দিছি') as LedgerAdd).date, DateTime(2026, 10, 14));
      expect((one('কাল রহিমকে ৫০০ টাকা ধার দিলাম') as LedgerAdd).date, DateTime(2026, 10, 14));
      expect((one('রহিমকে ৫০০ টাকা ধার দিলাম') as LedgerAdd).date, isNull);
      expect((one('রহিমের কাছ থেকে ৫০০ টাকা ধার নিছি') as LedgerAdd).kind, LedgerKind.borrowed);
      // Mixed Bengali-English times.
      final mixed = one('কাল eight pm-এ medicine reminder দাও') as ReminderAdd;
      expect((mixed.at, mixed.title), (DateTime(2026, 10, 16, 20), 'medicine'));
      expect((one('seven thirty pm এ মনে করিয়ে দিও ওষুধ') as ReminderAdd).at, DateTime(2026, 10, 16, 19, 30));
      expect((one('কাল সকাল 8 am এ মিটিং মনে করিয়ে দিও') as ReminderAdd).at, DateTime(2026, 10, 16, 8));
    });
  });

  group('zakat worked out from the records', () {
    final now = DateTime(2026, 10, 16);
    test('accounts, savings, DPS, dues and loan instalments are counted; gold and silver come from what was entered', () {
      final d = AppData(
        accounts: [MoneyAccount(name: 'বিকাশ', kind: AccountKind.bkash, opening: 20000), MoneyAccount(name: 'ব্যাংক', kind: AccountKind.bank, opening: 300000)],
        goals: [SavingsGoal(name: 'হজ', target: 500000, deposits: [GoalDeposit(50000, DateTime(2026, 1, 1))])],
        installments: [
          Installment(name: 'DPS', kind: InstallmentKind.dps, amount: 5000, months: 60, start: DateTime(2025, 1, 1), paid: ['2025-01', '2025-02']),
          Installment(name: 'গাড়ির লোন', kind: InstallmentKind.loan, amount: 10000, months: 24, start: DateTime(2026, 1, 1)),
        ],
        ledger: [
          LedgerEntry(person: 'সজীব', kind: LedgerKind.lent, amount: 30000, date: DateTime(2026, 9, 1)),
          LedgerEntry(person: 'করিম', kind: LedgerKind.borrowed, amount: 20000, date: DateTime(2026, 9, 1)),
        ],
      );
      final r = zakatFromRecords(d, now);
      expect((r.cash, r.bank, r.receivable, r.debts), (20000, 300000 + 50000 + 10000, 30000, 20000 + 12 * 10000));
      final z = zakatAuto(d, now, const ZakatSaved(goldVori: 2, goldPrice: 150000, silverPrice: 2500));
      expect(z.gold, 300000);
      expect(z.nisab, 131250);
      expect(z.net, 20000 + 360000 + 300000 + 30000 - 140000);
      expect(z.zakat, (570000 * 0.025).round());
      askZakat = const ZakatSaved(goldVori: 2, goldPrice: 150000, silverPrice: 2500);
      expect(infoAnswer(d, 'আমার যাকাত কত?', now), contains('১৪,২৫০'));
      askZakat = const ZakatSaved();
      expect(infoAnswer(d, 'আমার যাকাত কত?', now), contains('রুপার দাম'));
    });

    test('no accounts: the income-expense balance is used and marked as an estimate', () {
      final d = AppData(cash: [CashEntry(kind: CashKind.income, amount: 50000, date: now), CashEntry(kind: CashKind.expense, amount: 20000, date: now)]);
      final r = zakatFromRecords(d, now);
      expect((r.cash, r.cashEstimated), (30000, true));
    });
  });

  group('long speech: the answer to "আর কিছু বলতে চান?"', () {
    test('control words, words to add, corrections', () {
      expect(continuationOf('না').$1, Continue.finish);
      expect(continuationOf('না, আর কিছু নেই').$1, Continue.finish);
      expect(continuationOf('এইটুকুই').$1, Continue.finish);
      expect(continuationOf('বলা শেষ').$1, Continue.finish);
      expect(continuationOf('এখন উত্তর দাও').$1, Continue.finish);
      for (final s in ['হ্যাঁ', 'জি', 'আরও আছে', 'আরও বলব', 'একটু অপেক্ষা করো', 'আছে']) {
        expect(continuationOf(s).$1, Continue.more, reason: s);
      }
      expect(continuationOf('হ্যাঁ, আর কাল বাজারে সাতশ টাকা খরচ হয়েছে'), (Continue.content, 'আর কাল বাজারে সাতশ টাকা খরচ হয়েছে'));
      expect(continuationOf('হ্যাঁ, সজীবের কথাটাও লিখো'), (Continue.content, 'সজীবের কথাটাও লিখো'));
      expect(continuationOf('না, পাঁচশ নয়, সাতশ হবে'), (Continue.content, 'পাঁচশ নয়, সাতশ হবে'));
      expect(continuationOf('সজীবকে আরও দুইশ টাকা দিয়েছি'), (Continue.content, 'সজীবকে আরও দুইশ টাকা দিয়েছি'));
      expect(continuationOf('পুরোটা বাদ দাও').$1, Continue.cancel);
      // A "না" inside the speech does not end it.
      expect(endsSpeech('সজীবকে টাকা দিইনি না'), isFalse);
      expect(endsSpeech('বলা শেষ'), isTrue);
      expect(assemble(['আজ সজীবকে পাঁচশ টাকা ধার দিয়েছি।', 'আর বাজারে সাতশ টাকা খরচ হয়েছে।', ' ']), 'আজ সজীবকে পাঁচশ টাকা ধার দিয়েছি। আর বাজারে সাতশ টাকা খরচ হয়েছে।');
    });
  });
}
