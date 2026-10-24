// The seventh set of 18 Oct screenshots (2.28.0-b38), replayed word for word.
import 'package:digital_brain/logic/answers.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/doc_upload.dart';
import 'package:digital_brain/screens/docs_screen.dart' show DocScreen;
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/screens/zakat_screen.dart' show ZakatScreen;
import 'package:digital_brain/services/files.dart';
import 'package:digital_brain/services/ocr.dart';
import 'package:digital_brain/state/chat.dart';
import 'dart:async';
import 'dart:convert';

import 'package:digital_brain/services/google_account.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, settle, start;

void main() {
  late Rig rig;
  late ChatController chat;

  Future<String> say(String s) async {
    final n = chat.messages.length;
    await chat.hear(s);
    final r = chat.messages.skip(n).where((m) => !m.fromUser).map((m) => [m.text, ...m.facts].join(' ')).join(' ');
    // ignore: avoid_print
    print('» $s\n  ${r.replaceAll('\n', ' / ')}  [wait=${chat.wait}]');
    return r;
  }

  AppData data() => rig.brain.data;

  Future<void> open(WidgetTester t) async {
    rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 18, 19, 0);
    data().projects.addAll([Project(id: 'p1', name: 'শিক্ষার্থীদের বেতন'), Project(id: 'p2', name: 'বাড়ি মেরামত')]);
    chat = ChatController(rig.brain);
  }

  testWidgets('swiping right to left moves to the next tab; inner tabs first, then the bottom ones', (t) async {
    await open(t);
    HomeShellState shell() => t.state<HomeShellState>(find.byType(HomeShell));
    Future<void> swipe(double dx) async {
      await t.flingFrom(const Offset(200, 400), Offset(dx, 0), 1500);
      await settle(t);
    }

    expect(shell().tabNow, ShellTab.home);
    await swipe(-300);
    expect(shell().tabNow, ShellTab.diary);
    // দিনলিপি: দৈনিক → সাপ্তাহিক → মাসিক, then on to হিসাব.
    await swipe(-300);
    await swipe(-300);
    expect(shell().tabNow, ShellTab.diary);
    await swipe(-300);
    expect(shell().tabNow, ShellTab.money);
    await swipe(300);
    expect(shell().tabNow, ShellTab.diary, reason: 'left to right goes back');
  });

  testWidgets('২. "কাল (সোমবার)" is not put inside a second pair of brackets', (t) async {
    await open(t);
    data().tasks.add(Task(id: 'a', title: 'সোনাইমুড়ী যাবো', due: DateTime(2026, 10, 19), createdAt: DateTime(2026, 10, 1)));
    final r = await say('আমার কাজের তালিকা দাও');
    expect(r, isNot(contains('((')));
    expect(r, isNot(contains('))')));
    expect(r, contains('সোনাইমুড়ী যাবো'));
  });

  testWidgets('৩. "দিলাম" said once for several people is asked once', (t) async {
    await open(t);
    data().contacts.addAll([
      Contact(id: 't1', name: 'Tuba', phone: '+8801962470568'),
      Contact(id: 't2', name: 'তুবা আপু', phone: '+8801962470000'),
    ]);
    await say('আজ সকালে তুবাকে ৫০০ টাকা দিলাম। ফারুককে ১০ হাজার টাকা। সাগর কাকাকে ১০ হাজার টাকা।');
    await say('হ্যাঁ');
    await say('Tuba +8801962470568');
    final k = await say('ধার দিলাম');
    expect(k, isNot(contains('বুঝিয়ে')), reason: 'the others were given the same way');
    expect(data().ledger.where((e) => e.kind == LedgerKind.lent), hasLength(3));
  });

  testWidgets('৪. "শিক্ষার্থীদের বেতনের হিসাব দাও" is that account', (t) async {
    await open(t);
    data().cash.add(CashEntry(kind: CashKind.income, amount: 2000, category: 'বেতন', projectId: 'p1', date: DateTime(2026, 10, 18)));
    data().ledger.add(LedgerEntry(person: 'রবিন', kind: LedgerKind.borrowed, amount: 2500, date: DateTime(2026, 10, 1)));
    for (final s in ['আমার শিক্ষার্থীদের বেতনের হিসাব দাও', 'শিক্ষার্থীদের বেতনের হিসাব অন্যান্য হিসাবে']) {
      final r = await say(s);
      expect(r, contains('শিক্ষার্থীদের বেতন'));
      expect(r, contains('২,০০০'));
      expect(r, isNot(contains('পাবেন')));
    }
  });

  testWidgets('৫. each expense keeps what it was for; kept together, one link', (t) async {
    await open(t);
    final r = await say('আজ সকালে চা গেলাম ২০ টাকার, রুটি ২০ টাকার। সিংগাড়া ৫০ টাকার।');
    for (final w in ['চা', 'রুটি', 'সিংগাড়া']) {
      expect(r, contains(w));
    }
    expect(r, isNot(contains('অন্যান্য')));
    final n = chat.messages.length;
    await say('হ্যাঁ');
    expect(chat.messages.skip(n).expand((m) => m.links).length, 1, reason: 'one "আয়-ব্যয় দেখুন", not one per line');
    final m = await say('মাছ কিনলাম ১২৫০ টাকার, তেল কিনলাম ৫০০ টাকার');
    expect(m, contains('মাছ'));
    expect(m, contains('তেল'));
  });

  testWidgets('৬. what the documents page can keep, and whether a photo can be read', (t) async {
    await open(t);
    final a = await say('ডকুমেন্টস এ ওয়ারেন্টি কার্ড রাখার সিস্টেম আছে?');
    expect(a, isNot(contains('কোনো তথ্য নেই')));
    expect(a, contains('ওয়ারেন্টি'));
    final b = await say('কোন কাগজের ছবি তুলে সেখান থেকে ওয়ারেন্টি এর তারিখ নিতে পারবা?');
    expect(b, isNot(contains('রিমাইন্ডারগুলো')));
    expect(b, contains('ওয়ারেন্টি'));
  });

  testWidgets('৭. saying an anniversary again moves the one kept, not a second one', (t) async {
    await open(t);
    data().specialDays.add(SpecialDay(id: 's1', person: 'আমার বিবাহবার্ষিকী', kind: SpecialKind.anniversary, month: 11, day: 15));
    final r = await say('১৫ই ফেব্রুয়ারী আমার বিবাহ বার্ষিকী');
    await say('হ্যাঁ');
    expect(data().specialDays, hasLength(1), reason: r);
    expect(data().specialDays.single.month, 2);
  });

  testWidgets('৮. a note whose text is its title is said once', (t) async {
    await open(t);
    data().notes.add(Note(id: 'n1', title: '৭ তারিখে হিরার জন্মদিন', body: '৭ তারিখে হিরার জন্মদিন'));
    final r = await say('আমার কি কি নোট আছে?');
    expect('হিরার'.allMatches(r), hasLength(1));
  });

  testWidgets('৯. "ইমরান ১০ হাজার টাকা দিয়েছে" with a loan open asks which', (t) async {
    await open(t);
    data().ledger.add(LedgerEntry(person: 'ইমরান', kind: LedgerKind.lent, amount: 15000, date: DateTime(2026, 10, 1)));
    final r = await say('ইমরান আজ ১০ হাজার টাকা দিয়েছে, এটা নোট করে রাখো');
    expect(r, isNot(contains('অন্যান্য আয়')));
    expect(r, contains('ইমরান'));
  });

  testWidgets('১০. today\'s gold and silver price from BAJUS (through our server), put into যাকাত on a yes', (t) async {
    var asked = 0;
    final server = AccountServer(
        MockClient((r) async {
          if (r.url.path != '/wp-json/my-assistant/v1/metal-price') return http.Response('{}', 404);
          asked++;
          return http.Response.bytes(
              utf8.encode(jsonEncode({
                'date': '2026-10-15',
                'unit': 'vori',
                'gold': {'22k': 205000, '21k': 195700, '18k': 167700, 'traditional': 139400},
                'silver': {'22k': 3965, '21k': 3780, '18k': 3240, 'traditional': 2433},
                'source': 'বাজুস (বাংলাদেশ জুয়েলার্স অ্যাসোসিয়েশন)',
                'source_url': 'https://www.bajus.org/gold-price',
              })),
              200);
        }),
        'https://example.test');
    rig = await start(t, server: server);
    rig.nowAt = DateTime(2026, 10, 18, 19, 0);
    chat = ChatController(rig.brain);
    final a = await say('তুমি ইন্টারনেট থেকে আজকের রুপা সোনার দাম লিখতে পারো না?');
    expect(a, contains('বাজুস'));
    expect(a, contains('২,০৫,০০০'));
    expect(a, contains('৩,৯৬৫'));
    await say('হ্যাঁ, বসাও');
    expect(rig.brain.zakatSaved.goldPrice, 205000);
    expect(rig.brain.zakatSaved.silverPrice, 3965);
    final z = await say('আমার যাকাত কত');
    expect(z, isNot(contains('রুপার দাম লাগবে')));
    expect(asked, 1, reason: 'asked once, kept for hours');
    // A remark to the assistant afterwards is not a new note category.
    final b = await say('বানিয়ে কেন বলবা? বিশ্বাস্ত মাধ্যম থেকে নিবা');
    expect(b, isNot(contains('বিভাগ')));
    expect(chat.wait, ChatWait.none);
  });

  testWidgets('১০. offline: no price made up, where to see it is said', (t) async {
    await open(t);
    final a = await say('আজকের সোনার দাম কত?');
    expect(a, contains('bajus.org'));
    expect(a, contains('বানিয়ে বলব না'));
  });

  testWidgets('১০. "আমার যাকাত কত" with no price entered uses today\'s and says so', (t) async {
    final server = AccountServer(
        MockClient((r) async => http.Response.bytes(
            utf8.encode(jsonEncode({'date': '2026-10-15', 'gold': {'22k': 205000, '21k': 195700, '18k': 167700, 'traditional': 139400}, 'silver': {'22k': 3965}, 'source': 'বাজুস'})), 200)),
        'https://example.test');
    rig = await start(t, server: server);
    rig.nowAt = DateTime(2026, 10, 18, 19, 0);
    chat = ChatController(rig.brain);
    rig.brain.data.cash.add(CashEntry(kind: CashKind.income, amount: 500000, category: 'বেতন', date: DateTime(2026, 10, 1)));
    final z = await say('আমার যাকাত কত');
    expect(z, contains('আজকের বাজুস দামে'));
    expect(z, contains('১২,৫০০'), reason: '2.5% of 5,00,000');
    expect(rig.brain.zakatSaved.silverPrice, 0, reason: 'what the user entered is not changed without asking');
  });

  testWidgets('১১. many people of one name: "আরও N জন" said once', (t) async {
    await open(t);
    data().contacts.addAll([for (var i = 0; i < 7; i++) Contact(id: 'i$i', name: 'ইমরান ${['নাঈম মেটাল', 'ভাই', 'Spsc', 'ARTISAN', 'হোসেন', 'আলী', 'খান'][i]}', phone: '0171000000$i')]);
    final r = await say('ইমরানকে একটা কল দাও');
    expect('আরও'.allMatches(r), hasLength(1), reason: r);
    expect(r, contains('আরও ৩ জন'));
  });

  testWidgets('১২. income and spending by category', (t) async {
    await open(t);
    data().cash.addAll([
      CashEntry(kind: CashKind.income, amount: 15000, category: 'রেমিট্যান্স', date: DateTime(2026, 10, 18)),
      CashEntry(kind: CashKind.income, amount: 2500, category: 'বেতন', date: DateTime(2026, 10, 5)),
      CashEntry(kind: CashKind.expense, amount: 2700, category: 'বিল', date: DateTime(2026, 10, 18)),
      CashEntry(kind: CashKind.expense, amount: 450, category: 'বাজার', date: DateTime(2026, 10, 18)),
    ]);
    data().contacts.add(Contact(id: 'm', name: 'Masud Kat', phone: '+8801671779505'));
    for (final s in ['আয়ের খাত গুলো কি কি', 'কিভাবে আয় হয়েছে?']) {
      final r = await say(s);
      expect(r, contains('রেমিট্যান্স'));
      expect(r, contains('বেতন'));
      expect(r, isNot(contains('বিল')));
    }
    for (final s in ['ব্যয়ের খাত গুলো কি কি', 'কিভাবে ব্যয় হয়েছে?']) {
      final r = await say(s);
      expect(r, contains('বিল'));
      expect(r, contains('বাজার'));
      expect(r, isNot(contains('Masud')));
      expect(r, isNot(contains('রেমিট্যান্স')));
    }
  });

  testWidgets('১৩. "বাড়ির মেরামতে" is the বাড়ি মেরামত account, also after "না।"', (t) async {
    await open(t);
    final q = await say('বাড়ির মেরামতে মিস্ত্রির বিল বাবদ ২৯০০ টাকা যুক্ত কর');
    expect(q, contains('বাড়ি মেরামত'));
    await say('হ্যাঁ');
    final own = data().cash.where((c) => c.linkId == null);
    expect(own.single.projectId, 'p2');
    expect(own.single.category, 'বিল');
    // Offered for the monthly আয়-ব্যয়, then "না। <the account>": moved there, not dropped.
    await say('মিস্ত্রির বিল ৫০০ টাকা');
    final m = await say('না। অন্যান্য হিসাবের ভেতরে বাড়ির মেরামতে');
    expect(m, isNot(contains('রাখলাম না')));
    if (chat.wait == ChatWait.yesNo) await say('হ্যাঁ');
    expect(data().cash.where((e) => e.amount == 500 && e.linkId == null).single.projectId, 'p2');
    final all = await say('অন্যান্য হিসাব ভেততের সব দাও');
    expect(all, contains('মিস্ত্রি'));
  });

  testWidgets('১৪. a password\'s name is the site, not the words around it', (t) async {
    await open(t);
    await say('ওয়েবসাইট লিংক: getmyassistant.app এবং পাসওয়ার্ড: Ab12cd34');
    final q = chat.messages.last.text;
    expect(q, contains('getmyassistant.app'));
    expect(q, isNot(contains('লিংক')));
    expect(q, isNot(contains('এবং')));
  });

  testWidgets('৬. a photo of a warranty card: its date is read and put in the box, to check', (t) async {
    await open(t);
    (rig.brain.services.ocr as FakeTextReader).text = 'WALTON PLAZA\nInvoice Date: 12/05/2026\nRefrigerator\nWarranty: 1 Year';
    final ctx = t.element(find.byType(HomeShell));
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
    DocInfo? got;
    unawaited(askDocInfo(ctx, [PickedDoc(png, 'card.jpg', 'image/jpeg')]).then((v) => got = v));
    await settle(t);
    expect(find.byKey(const Key('doc-read-note')), findsOneWidget);
    expect(find.textContaining('১২ মে ২০২৭'), findsWidgets);
    await t.enterText(find.widgetWithText(TextField, 'নাম'), 'ফ্রিজের ওয়ারেন্টি');
    await t.ensureVisible(find.text('রাখুন').last);
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    expect(got!.doc.expiry, DateTime(2027, 5, 12));
    expect(got!.doc.folder, 'ওয়ারেন্টি ও গ্যারান্টি');
  });

  testWidgets('৬. nothing readable: no date is made up', (t) async {
    await open(t);
    (rig.brain.services.ocr as FakeTextReader).text = 'Model X200';
    final ctx = t.element(find.byType(HomeShell));
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
    DocInfo? got;
    unawaited(askDocInfo(ctx, [PickedDoc(png, 'x.jpg', 'image/jpeg')]).then((v) => got = v));
    await settle(t);
    expect(find.textContaining('পরিষ্কার পাইনি'), findsOneWidget);
    // A name and a folder are a must (owner, 24 Oct).
    await t.enterText(find.widgetWithText(TextField, 'নাম'), 'X200');
    await t.ensureVisible(find.widgetWithText(ChoiceChip, 'ওয়ারেন্টি ও গ্যারান্টি'));
    await t.tap(find.widgetWithText(ChoiceChip, 'ওয়ারেন্টি ও গ্যারান্টি'));
    await settle(t);
    await t.ensureVisible(find.text('রাখুন').last);
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    expect(got!.doc.expiry, isNull);
  });

  testWidgets('every paper is read: its facts are offered as details, kept after a look', (t) async {
    await open(t);
    (rig.brain.services.ocr as FakeTextReader).text =
        'PASSPORT\nPassport No.\nA01234567\nDate of Issue 12 MAY 2021\nDate of Expiry 11 MAY 2031\nP<BGDISLAM<<MD<SAIFUL<<<<<<<<<<<<<<<<<<<<<<<\nA012345674BGD9001057M3105115<<<<<<<<<<<<<<02';
    final ctx = t.element(find.byType(HomeShell));
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
    DocInfo? got;
    unawaited(askDocInfo(ctx, [PickedDoc(png, 'p.jpg', 'image/jpeg')]).then((v) => got = v));
    await settle(t);
    expect(find.byKey(const Key('doc-field-পাসপোর্ট নম্বর')), findsOneWidget);
    // One left out after a look.
    await t.ensureVisible(find.byKey(const Key('doc-field-ইস্যুর তারিখ')));
    await t.tap(find.byKey(const Key('doc-field-ইস্যুর তারিখ')));
    await settle(t);
    await t.enterText(find.widgetWithText(TextField, 'নাম'), 'আমার পাসপোর্ট');
    await t.ensureVisible(find.text('রাখুন').last);
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    final f = {for (final x in got!.doc.fields) x.label: x.value};
    expect(f['পাসপোর্ট নম্বর'], 'A01234567');
    expect(f['নাম'], 'MD SAIFUL ISLAM');
    expect(f.containsKey('ইস্যুর তারিখ'), isFalse);
    expect(got!.doc.folder, 'পাসপোর্ট');
    expect(got!.doc.expiry, DateTime(2031, 5, 11));
    expect(got!.doc.text, contains('A01234567'));
  });

  testWidgets('a paper kept earlier: "ছবি থেকে তথ্য পড়ুন" reads it and adds what is checked', (t) async {
    await open(t);
    final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
    final d = await rig.brain.addDocGroup([PickedDoc(png, 'nid.jpg', 'image/jpeg')], Doc(title: 'আমার NID', folder: 'জাতীয় পরিচয়পত্র', fields: const [DocField('নাম', 'সাইফুল')]));
    (rig.brain.services.ocr as FakeTextReader).text = 'National ID Card\nName\nMD SAIFUL ISLAM\nDate of Birth 05 Jan 1990\nID NO: 1234 567 890';
    Navigator.of(t.element(find.byType(HomeShell))).push(MaterialPageRoute(builder: (_) => DocScreen(id: d.id, unlocked: true)));
    await settle(t);
    await t.ensureVisible(find.byKey(const Key('doc-read')));
    await t.tap(find.byKey(const Key('doc-read')));
    await settle(t);
    expect(find.byKey(const Key('read-field-NID নম্বর')), findsOneWidget);
    expect(find.byKey(const Key('read-field-নাম')), findsNothing, reason: 'the name the user wrote stays; not offered again');
    await t.ensureVisible(find.byKey(const Key('read-add')));
    await t.tap(find.byKey(const Key('read-add')));
    await settle(t);
    final now = rig.brain.data.docs.single;
    final f = {for (final x in now.fields) x.label: x.value};
    expect(f['নাম'], 'সাইফুল');
    expect(f['NID নম্বর'], '1234567890');
    expect(f['জন্মতারিখ'], '৫ জানুয়ারি ১৯৯০');
  });

  test('a paper kept before this version still loads; its read text is saved and searched', () {
    final old = Doc.fromJson({'id': 'd1', 'title': 'পাসপোর্ট', 'folder': 'পাসপোর্ট'});
    expect(old.text, '');
    final read = Doc.fromJson(old.copyWith(text: 'A01234567').toJson());
    expect(read.text, 'A01234567');
    expect(read.searchText, contains('A01234567'));
  });

  testWidgets('১০. the যাকাত page brings today\'s price on a tap', (t) async {
    final server = AccountServer(
        MockClient((r) async => r.url.path.endsWith('/metal-price')
            ? http.Response.bytes(utf8.encode(jsonEncode({'date': '2026-10-15', 'gold': {'22k': 205000, '21k': 195700, '18k': 167700, 'traditional': 139400}, 'silver': {'22k': 3965}, 'source': 'বাজুস'})), 200)
            : http.Response('{}', 404)),
        'https://example.test');
    rig = await start(t, server: server);
    await t.tap(find.text('হিসাব').last);
    await settle(t);
    Navigator.of(t.element(find.byType(HomeShell))).push(MaterialPageRoute(builder: (_) => const ZakatScreen()));
    await settle(t);
    await t.ensureVisible(find.byKey(const Key('zakat-today-price')));
    await t.tap(find.byKey(const Key('zakat-today-price')));
    await settle(t);
    expect(rig.brain.zakatSaved.goldPrice, 205000);
    expect(rig.brain.zakatSaved.silverPrice, 3965);
    expect(find.textContaining('বাজুস, ১৫ অক্টো থেকে কার্যকর'), findsOneWidget);
  });

  test('nameList says "আরও" once', () {
    expect('আরও'.allMatches(nameList(['ক', 'খ', 'গ', 'ঘ', 'ঙ'])), hasLength(1));
  });
}
