// Global version, step 1 (owner, 2 Nov 2026: one app, country and language
// apart; English first, the countries where Bangladeshis live first): money
// in the member's currency, numbers grouped the way that currency does,
// the currency said by name read as an amount, and taka exactly as before.
import 'package:digital_brain/logic/bn.dart';
import 'package:digital_brain/logic/calendar_bd.dart';
import 'package:digital_brain/logic/lang.dart';
import 'package:digital_brain/logic/parser.dart' show normalize, findPhone;
import 'package:digital_brain/nlu/samples.dart' show delexicalize;
import 'package:digital_brain/logic/pro.dart';
import 'package:digital_brain/logic/region.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:digital_brain/screens/money_screens.dart' show ProjectScreen;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/material.dart';

import 'app_test.dart' show Rig, settle, start;

void main() {
  tearDown(() {
    setRegion(country: 'BD', currency: 'BDT');
    isEn = false;
    bangladeshPart = true;
    islamicPart = true;
    setRegion(second: '');
  });

  group('amounts', () {
    test('taka: unchanged, lakh grouping', () {
      expect(taka(1050000), '৳১০,৫০,০০০');
      expect(tr('পরিমাণ (৳)'), 'পরিমাণ (৳)');
      expect(trf('{0} কাছে পাবেন {1} টাকা', ['সজীবের', '২০০']), 'সজীবের কাছে পাবেন ২০০ টাকা');
    });

    test('dirham: its sign, thousands grouping, its name after an amount', () {
      setRegion(country: 'AE', currency: 'AED');
      expect(taka(1050000), 'AED ১,০৫০,০০০');
      expect(bnNumber(100000), '১০০,০০০');
      expect(tr('৳ '), 'AED ');
      expect(tr('পরিমাণ (৳)'), 'পরিমাণ (AED)');
      expect(trf('{0} কাছে পাবেন {1} টাকা', ['সজীবের', '২০০']), 'সজীবের কাছে পাবেন ২০০ দিরহাম');
      expect(trf('{0} জনের মোট {1} টাকার হিসাব', ['২', '৫০০']), '২ জনের মোট ৫০০ দিরহামের হিসাব');
      // Money in general, not an amount: stays.
      expect(tr('টাকা'), 'টাকা');
      isEn = true;
      expect(taka(1050000), 'AED 1,050,000');
      expect(trf('{0} কাছে পাবেন {1} টাকা', ['Sajib', '200']), 'Sajib owes you AED 200');
    });

    test('pound and ringgit read naturally in English', () {
      isEn = true;
      setRegion(country: 'GB', currency: 'GBP');
      expect(taka(2500), '£2,500');
      expect(trf('{0} কাছে পাবেন {1} টাকা', ['Sajib', '200']), 'Sajib owes you £200');
      setRegion(country: 'MY', currency: 'MYR');
      expect(taka(2500), 'RM 2,500');
    });

    test('a country with no table entry falls back to US dollars; Bangladesh to taka', () {
      expect(currencyOf('BD'), 'BDT');
      expect(currencyOf(''), 'BDT');
      expect(currencyOf('AE'), 'AED');
      expect(currencyOf('IT'), 'EUR');
      expect(currencyOf('XX'), 'USD');
    });

    test('the Premium note says ৳৮৩ only when the price is in taka', () {
      final yearly = proPlans.first;
      expect(yearly.noteFor('৳৯৯৯.০০'), contains('৳৮৩'));
      expect(yearly.noteFor(r'$19.99'), isNot(contains('৳')));
      setRegion(country: 'AE', currency: 'AED');
      expect(yearly.noteFor(null), isNot(contains('AED')), reason: 'the taka price is never relabelled');
    });
  });

  group('the currency said by name', () {
    test('only the member\'s own currency becomes an amount', () {
      expect(normalize('বাজারে ৫০ ডলার খরচ'), contains('ডলার'), reason: 'a taka member\'s dollars are not taka');
      setRegion(country: 'AE', currency: 'AED');
      expect(normalize('বাজারে ৫০০ দিরহাম খরচ'), contains('500 টাকা'));
      expect(normalize('aed 500 dilam'), contains('500 টাকা'));
      expect(normalize('৫ হাজার দিরহামের বাজার'), contains('হাজার টাকার'));
      expect(normalize('৫০০ দিরহাম ২০ তারিখে দেব'), allOf(contains('500 টাকা'), contains('20 তারিখে')));
      expect(normalize('৫০ ডলার খরচ'), contains('ডলার'), reason: 'not the member\'s currency');
      setRegion(country: 'US', currency: 'USD');
      expect(normalize(r'$20 dilam'), contains('20 টাকা'));
    });

    test('the chat writes it and answers in dirham', () async {
      final rig = Rig();
      await rig.brain.load();
      await rig.brain.setCurrency('AED');
      final chat = ChatController(rig.brain);
      final reply = await chat.hear('আজ বাজারে ৫০০ দিরহাম খরচ হয়েছে');
      expect(reply, contains('৫০০ দিরহাম'));
      await chat.hear('হ্যাঁ');
      final spent = rig.brain.data.cash.where((c) => c.kind == CashKind.expense).toList();
      expect(spent.map((c) => c.amount), [500], reason: reply);
      expect(reply, isNot(contains('৳')));
    });
  });

  group('the brain', () {
    test('a new member abroad gets the country\'s currency; a chosen one stays', () async {
      final rig = Rig();
      await rig.brain.load();
      final b = rig.brain;
      expect(appCurrency.code, 'BDT');
      await b.setDistrict(const Place('দুবাই', 25.2048, 55.2708, tz: 240, region: 'gulf', cc: 'AE').key);
      expect(appCountry, 'AE');
      expect(inBangladesh, isFalse);
      expect(appCurrency.code, 'AED', reason: 'nothing written yet: follows the country');
      await b.setCurrency('USD');
      await b.setDistrict('ঢাকা');
      expect(appCountry, 'BD');
      expect(appCurrency.code, 'USD', reason: 'the member\'s choice is kept');
    });

    test('money written in taka keeps taka when the phone goes abroad', () async {
      final rig = Rig();
      await rig.brain.load();
      final b = rig.brain;
      final chat = ChatController(rig.brain);
      await chat.hear('আজ বাজারে ৩০০ টাকা খরচ');
      await chat.hear('হ্যাঁ');
      expect(b.data.cash, isNotEmpty);
      await b.setDistrict(const Place('দুবাই', 25.2048, 55.2708, tz: 240, region: 'gulf', cc: 'AE').key);
      expect(appCountry, 'AE');
      expect(appCurrency.code, 'BDT');
      expect(b.currencyCode, 'BDT');
    });
  });

  group('phone numbers from any country', () {
    test('found with the country code, kept as +digits', () {
      expect(findPhone('রহিমের নম্বর ০১৭১২-৩৪৫৬৭৮'), '01712345678', reason: 'Bangladesh: as before');
      expect(findPhone('save karim +971 50 123 4567'), '+971501234567');
      expect(findPhone('নম্বর +৪৪ ৭৭০০ ৯০০১২৩'), '+447700900123');
      expect(findPhone('call 0060-12-345 6789'), '+60123456789');
      expect(findPhone('৫০০০০০ টাকা দিলাম'), isNull, reason: 'an amount is no number');
      expect(findPhone('+1 234'), isNull, reason: 'too short');
    });

    test('never in a learning sample', () {
      expect(delexicalize('করিমের নম্বর +971 50 123 4567 রাখো', ['করিম']), isNull);
      expect(delexicalize('call 0044 7700 900123', const []), isNull);
      expect(delexicalize('করিমকে ৫০০ টাকা দিলাম', ['করিম']), isNotNull);
    });
  });

  group('Bangladesh-only parts abroad', () {
    test('no BAJUS taka price under another currency', () async {
      final rig = Rig();
      await rig.brain.load();
      await rig.brain.setCurrency('AED');
      expect(await rig.brain.metalPriceToday(), isNull);
      final chat = ChatController(rig.brain);
      expect(await chat.hear('আজ সোনার দাম কত'), contains('নিজে লিখুন'));
    });

    testWidgets('home: no blood tool abroad; it is there in Bangladesh', (t) async {
      final rig = await start(t);
      await settle(t);
      expect(find.byKey(const Key('tool-blood'), skipOffstage: false), findsOneWidget);
      await rig.brain.setDistrict(const Place('দুবাই', 25.2048, 55.2708, tz: 240, region: 'gulf', cc: 'AE').key);
      await settle(t);
      expect(find.byKey(const Key('tool-blood'), skipOffstage: false), findsNothing);
    });
  });

  group('parts by language and country (owner, 2 Nov: "ভাষা + দেশ")', () {
    test('Bangladeshi part: Bangla, or in Bangladesh; Islamic part: Bangla or a Muslim-majority country', () {
      expect(bangladeshAuto(country: 'BD', english: true), isTrue);
      expect(bangladeshAuto(country: 'SA', english: false), isTrue, reason: 'a Bangla speaker abroad keeps bKash and the Bangla date');
      expect(bangladeshAuto(country: 'GB', english: true), isFalse);
      expect(islamicAuto(country: 'SA', english: true), isTrue);
      expect(islamicAuto(country: 'GB', english: true), isFalse);
      expect(islamicAuto(country: 'GB', english: false), isTrue);
      expect(partOn('off', true), isFalse);
      expect(partOn('on', false), isTrue);
      expect(partOn('', true), isTrue);
    });

    test('the brain: English in London has neither part; the member can turn one on; blood only in Bangladesh', () async {
      final rig = Rig();
      await rig.brain.load();
      final b = rig.brain;
      await b.setDistrict(const Place('লন্ডন', 51.5074, -0.1278, tz: 0, region: 'mwl', cc: 'GB').key);
      await b.setEnglish(true);
      expect(bangladeshPart, isFalse);
      expect(islamicPart, isFalse);
      expect(bloodHere, isFalse);
      await b.setPart('islam', true);
      expect(islamicPart, isTrue);
      await b.setEnglish(false);
      expect(bangladeshPart, isTrue, reason: 'Bangla brings the Bangladeshi part back');
      expect(bloodHere, isFalse, reason: 'blood requests are Bangladesh\'s');
    });

    testWidgets('home without the parts: no prayer pill, no zakat, no Bangla date', (t) async {
      final rig = await start(t);
      await settle(t);
      expect(find.byKey(const Key('home-slot')), findsOneWidget);
      expect(find.byKey(const Key('tool-zakat'), skipOffstage: false), findsOneWidget);
      await rig.brain.setPart('islam', false);
      await rig.brain.setPart('bd', false);
      await settle(t);
      expect(find.byKey(const Key('home-slot')), findsNothing);
      expect(find.byKey(const Key('tool-zakat'), skipOffstage: false), findsNothing);
    });
  });

  group('week, weekend and temperature by country', () {
    test('Bangladesh as always; the Gulf on Sunday; the US on Sunday with °F; Britain on Monday', () {
      expect(weekStart, DateTime.saturday);
      expect(weekendDays, {DateTime.friday, DateTime.saturday});
      expect(degrees(30), 30);
      setRegion(country: 'SA');
      expect(weekStart, DateTime.sunday);
      setRegion(country: 'US');
      expect(weekStart, DateTime.sunday);
      expect(weekendDays, {DateTime.saturday, DateTime.sunday});
      expect(degrees(30), 86);
      setRegion(country: 'GB');
      expect(weekStart, DateTime.monday);
      expect(weekStartOf(DateTime(2026, 11, 4)), DateTime(2026, 11, 2), reason: 'a Wednesday: its Monday');
    });
  });

  group('two currencies (owner, 2 Nov: "দুই মুদ্রা, দুই দেশের জীবন")', () {
    test('a member on riyal: "দেশের টাকা" goes to the taka হিসাব; riyal stays main; old data reads the same', () async {
      final rig = Rig();
      await rig.brain.load();
      final b = rig.brain;
      await b.setCurrency('SAR');
      await b.setSecondCurrency('BDT');
      final chat = ChatController(b);
      await chat.hear('আজ বাজারে ৫০ রিয়াল খরচ');
      await chat.hear('হ্যাঁ');
      final reply = await chat.hear('দেশের টাকা ১০ হাজার বাজারে খরচ হলো');
      await chat.hear('হ্যাঁ');
      final book = b.data.projects.where((p) => p.currency == 'BDT').single;
      expect(book.inMain, isFalse);
      final main = b.data.cash.where((e) => e.projectId == null).map((e) => e.amount).toList();
      final inBook = b.data.cash.where((e) => e.projectId == book.id).map((e) => e.amount).toList();
      expect(main, contains(50), reason: reply);
      expect(main, isNot(contains(10000)), reason: reply);
      expect(inBook, [10000], reason: reply);
      // Saved and read back: the currency stays with the হিসাব.
      expect(Project.fromJson(book.toJson()).currency, 'BDT');
      expect(Project.fromJson({'id': 'x', 'name': 'পুরনো'}).currency, isNull, reason: 'a হিসাব from before reads as before');
    });

    test('a member on taka: "৫০০ রিয়াল" goes to the riyal হিসাব, shown in riyal; never in zakat', () async {
      final rig = Rig();
      await rig.brain.load();
      final b = rig.brain;
      await b.setSecondCurrency('SAR');
      final chat = ChatController(b);
      await chat.hear('বেতন পেলাম ২০০০ রিয়াল');
      await chat.hear('হ্যাঁ');
      final book = b.data.projects.where((p) => p.currency == 'SAR').single;
      expect(b.data.cash.where((e) => e.projectId == book.id).map((e) => e.amount), [2000]);
      expect(b.data.cash.where((e) => e.projectId == null), isEmpty);
      expect(moneyIn(2000, 'SAR'), 'SAR ২,০০০');
      expect(moneyIn(2000, null), '৳২,০০০');
      expect(b.canAddProject, isTrue, reason: 'the currency\'s হিসাব does not use up the free one');
    });

    test('a loan said in the second currency is a বকেয়া of its হিসাব', () async {
      final rig = Rig();
      await rig.brain.load();
      final b = rig.brain;
      await b.setSecondCurrency('SAR');
      final chat = ChatController(b);
      final r1 = await chat.hear('করিমকে ৩০০ রিয়াল ধার দিলাম');
      final r2 = await chat.hear('হ্যাঁ');
      final book = b.data.projects.where((p) => p.currency == 'SAR').single;
      final loans = b.data.ledger.where((e) => e.person.contains('করিম')).toList();
      expect(loans.map((e) => e.projectId), [book.id], reason: '$r1 / $r2');
      expect(r2, allOf(contains('রিয়াল'), isNot(contains('টাকা'))));
    });

    test('words: only the second currency\'s own words route there', () {
      setRegion(currency: 'SAR', second: 'BDT');
      expect(mentionsSecond('দেশের টাকা ৫০০০'), isTrue);
      expect(mentionsSecond('৫০০ টাকা খরচ'), isFalse, reason: 'plain টাকা may mean the main money');
      setRegion(currency: 'BDT', second: 'SAR');
      expect(mentionsSecond('৫০০ রিয়াল'), isTrue);
      expect(mentionsSecond('two hours'), isFalse);
    });
  });

  testWidgets('the riyal হিসাব page shows riyal; going back, taka again', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.setSecondCurrency('SAR');
    final book = await b.currencyBook('SAR');
    await b.saveCash(CashEntry(kind: CashKind.income, amount: 2000, category: 'বেতন', date: DateTime(2026, 11, 2), projectId: book.id));
    await settle(t);
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute(builder: (_) => ProjectScreen(id: book.id)));
    await settle(t);
    expect(appCurrency.code, 'SAR');
    expect(find.textContaining('SAR'), findsWidgets);
    nav.pop();
    await settle(t);
    expect(appCurrency.code, 'BDT');
  });

  test('test app: picking a country makes the app as it is there, and back to Bangladesh', () async {
    final rig = Rig();
    await rig.brain.load();
    final b = rig.brain;
    await b.setPart('islam', false);
    await b.tryCountry('GB');
    expect(appCountry, 'GB');
    expect(appCurrency.code, 'GBP');
    expect(weekStart, DateTime.monday);
    expect(islamicPart, isTrue, reason: 'the choice is reset to automatic: the app is in Bangla');
    expect(bloodHere, isFalse);
    await b.tryCountry('BD');
    expect(appCurrency.code, 'BDT');
    expect(bloodHere, isTrue);
  });
}
