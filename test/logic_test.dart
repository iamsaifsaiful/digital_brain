import 'package:digital_brain/logic/bn.dart';
import 'package:digital_brain/logic/categories.dart';
import 'package:digital_brain/logic/csv.dart';
import 'package:digital_brain/logic/ledger.dart';
import 'package:digital_brain/logic/match.dart';
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/logic/password.dart';
import 'package:digital_brain/logic/phrases.dart';
import 'package:digital_brain/logic/search.dart';
import 'package:digital_brain/models/models.dart';
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
      expect(confirmQuestion(LedgerKind.lent, 'সজীব', 500), 'আপনি সজীবকে ৫০০ টাকা ধার দিয়েছেন। সেভ করব?');
      expect(savedSentence(LedgerKind.received, 'সজীব', 300, 200),
          'সজীব আপনাকে ৩০০ টাকা ফেরত দিয়েছেন। এখন সজীবের কাছে আপনার ২০০ টাকা পাওনা।');
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

    test('notify time is days before, at the set hour', () {
      final r = Reminder(title: 'ডোমেইন', date: DateTime(2026, 10, 14), daysBefore: 1, hour: 10);
      expect(r.notifyAt(DateTime(2026, 10, 9)), DateTime(2026, 10, 13, 10));
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
}
