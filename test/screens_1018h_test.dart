// The eighth set of 18 Oct screenshots (2.30.0-b42), replayed word for word.
import 'dart:convert';

import 'package:digital_brain/logic/search.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/files.dart';
import 'package:digital_brain/services/ocr.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, start;

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
    rig.nowAt = DateTime(2026, 10, 18, 21, 10);
    chat = ChatController(rig.brain);
  }

  Future<void> twoTasks() async {
    data().tasks.addAll([
      Task(id: 'a', title: 'রবিনের বোনের বিয়েতে দাওয়াত', due: DateTime(2026, 10, 23), createdAt: DateTime(2026, 10, 1)),
      Task(id: 'b', title: 'রবিনের বোনের বিয়েতে দাওয়াত', due: DateTime(2026, 10, 24), createdAt: DateTime(2026, 10, 1)),
    ]);
    await say('আমার কাজের তালিকা দেখাও');
  }

  void remindersOnTaskDays() {
    final rs = data().reminders.where((r) => r.title.contains('দাওয়াত')).toList();
    expect(rs.map((r) => (r.date.day, r.hour)), unorderedEquals([(23, 12), (24, 12)]));
    expect(data().reminders.where((r) => r.title.contains('দুটি') || r.title.contains('এতে')), isEmpty);
  }

  testWidgets('১. "এই দুটি কাজের রিমাইন্ডার দাও" → each shown to-do, on its own day', (t) async {
    await open(t);
    await twoTasks();
    await say('এই দুটি কাজের রিমাইন্ডার দাও');
    await say('দুপুর ১২ টায়');
    if (chat.wait == ChatWait.yesNo) await say('হ্যাঁ');
    remindersOnTaskDays();
  });

  testWidgets('১. "হ্যা, এতে রিমাইন্ডার দাও ১২ টায়" after the list', (t) async {
    await open(t);
    await twoTasks();
    await say('হ্যা, এতে রিমাইন্ডার দাও ১২ টায়');
    await say('দুপুর ১২টা');
    if (chat.wait == ChatWait.yesNo) await say('হ্যাঁ');
    remindersOnTaskDays();
  });

  testWidgets('১. "কাজের তালিকার কাজ দুটির রিমাইন্ডার ১২ টায় দাও"', (t) async {
    await open(t);
    await twoTasks();
    await say('কাজের তালিকার কাজ দুটির রিমাইন্ডার দুপুর ১২ টায় দাও');
    if (chat.wait == ChatWait.yesNo) await say('হ্যাঁ');
    remindersOnTaskDays();
  });

  testWidgets('২. a list with parts of the day, then two dated sentences', (t) async {
    await open(t);
    final r = await say('কাজ গুলো তালিকায় যুক্ত কর-\n১. সকাল স্কুলে যাবো\n২. বাজার করব\n৩. ব্যাংকে যাবো\n৪. দুপুরে রেস্টুরেন্টে খাবো\n৫. বিকালে নূরের বাসায় যাবো\n৬. রাতে পার্টি হবে।\n\n\n২৯ তারিখে ঢাকায় যাবো। ৩১ তারিখে পার্টি পাবে।');
    expect(data().tasks, hasLength(8), reason: r);
    final dhaka = data().tasks.firstWhere((x) => x.title.contains('ঢাকা'));
    expect(dhaka.title, isNot(contains('পার্টি')));
    expect(dhaka.due, DateTime(2026, 10, 29));
    expect(data().tasks.where((x) => x.title.contains('পার্টি') && x.due == DateTime(2026, 10, 31)), hasLength(1));
    expect(data().tasks.firstWhere((x) => x.title.contains('স্কুল')).title, contains('সকাল'));
  });

  testWidgets('৩. "পার্টির তারিখ যুক্ত কর" asks the day, and "৩১ অক্টোবর" sets it', (t) async {
    await open(t);
    data().tasks.add(Task(id: 'p', title: 'পার্টি', createdAt: DateTime(2026, 10, 18)));
    final q = await say('পার্টির তারিখ যুক্ত কর');
    expect(q, isNot(contains('বিভাগ')));
    await say('৩১ অক্টোবর');
    expect(data().tasks.single.due, DateTime(2026, 10, 31));
    expect(data().notes, isEmpty);
  });

  testWidgets('৪–৫. "১৪ই ফেব্রুয়ারি বিশ্ব ভালোবাসা দিবস" is a yearly day; a time with a date keeps the date', (t) async {
    await open(t);
    final q = await say('১৪ই ফেব্রুয়ারি বিশ্ব ভালোবাসা দিবস');
    expect(q, isNot(contains('বিভাগ')));
    await say('হ্যাঁ');
    final r1 = [...data().reminders, for (final s in data().specialDays) s];
    expect(r1, isNotEmpty);
    // The reminder asked by name, its time given with the date.
    data().reminders.clear();
    data().specialDays.clear();
    await say('বিশ্ব ভালোবাসা দিবসে মনে করিয়ে দিও');
    await say('১৪ ফেব্রুয়ারী সকাল ১০ টায়');
    if (chat.wait == ChatWait.yesNo) await say('হ্যাঁ');
    final r = data().reminders.single;
    expect((r.date.month, r.date.day, r.hour), (2, 14, 10));
  });

  testWidgets('৬. who owes me: every name, and "আরও ১ জনের কাছে কত?"', (t) async {
    await open(t);
    for (final (i, n) in ['শফিক ভাই', 'ফারুক', 'সাগর কাকা', 'তুবা', 'রবিন'].indexed) {
      data().ledger.add(LedgerEntry(person: n, kind: LedgerKind.lent, amount: 1000 * (5 - i), date: DateTime(2026, 10, 1)));
    }
    final r = await say('আমার পাওনা টাকা কত?');
    expect(r, contains('রবিন'));
    final m = await say('আরও ১ জনের কাছে কত?');
    expect(m, isNot(contains('সেটিংস')));
  });

  testWidgets('৭. "কোনটি মেয়াস কবে শেষ?" is about the papers\' expiry', (t) async {
    await open(t);
    data().docs.add(Doc(title: 'সাইফুলের পাসপোর্ট', folder: 'পাসপোর্ট', expiry: DateTime(2027, 8, 25)));
    final r = await say('কোনটি মেয়াস কবে শেষ?');
    expect(r, contains('সাইফুলের পাসপোর্ট'));
    expect(r, isNot(contains('এই নামে কিছু পেলাম না')));
  });

  testWidgets('৮–৯. quantities are not prices; "দাম ভুল" asks, an amount fixes, a complaint is not a yes', (t) async {
    await open(t);
    final r = await say('আজ বাজারে পেয়াজ কিনলাম ৩ কেজি ৩০০ টাকায়, চা পাতা ৫০০ গ্রাম ২০০ টাকায় এবং হ্যান্ডওয়াশ দুটা ৫০ টাকায়');
    expect(r, contains('৩০০ টাকা'));
    expect(r, contains('২০০ টাকা'));
    expect(r, contains('পেয়াজ'));
    expect(r, isNot(contains('কেজি')));
    // Said wrong on purpose (as the b42 app did), then corrected.
    final w = await say('পেয়াজ এবং চা পাতার দাম ভুল উঠেছে');
    expect(w, isNot(contains('বাদ দিলাম')));
    final f = await say('পেয়াজ ৩০০ টাকা');
    expect(f, isNot(contains('বাদ দিলাম')));
    final c = await say('এখনো ঠিক করতে পারো নাই');
    expect(c, isNot(contains('লিখলাম')));
    expect(data().cash, isEmpty);
    await say('হ্যাঁ');
    expect([for (final e in data().cash) e.amount], unorderedEquals([300, 200, 50]));
  });

  testWidgets('১০. zakat with no price and no internet says so', (t) async {
    await open(t);
    final r = await say('আমার যাকাত কত');
    expect(r, contains('আনতে পারিনি'));
  });

  final png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

  testWidgets('every photo kept is read: a note\'s photo, kept with the note and searchable', (t) async {
    await open(t);
    (rig.brain.services.ocr as FakeTextReader).text = 'WIFI PASSWORD SHEET\nRouter TP-LINK Archer C6';
    // The form is open while the photo is read; saved after.
    final f = await rig.brain.keepFile(PickedDoc(png, 'router.jpg', 'image/jpeg'));
    await t.runAsync(() => rig.brain.readingDone);
    await rig.brain.saveNote(Note(title: 'রাউটার', files: [f]));
    expect(data().notes.single.files.single.text, contains('Archer'));
    final hits = searchAll(data(), ['archer']);
    expect(hits, isNotEmpty);
  });

  testWidgets('pages added to a kept paper are read: new facts kept, the user\'s own stay', (t) async {
    await open(t);
    final d = await rig.brain.addDocGroup([PickedDoc(png, 'a.jpg', 'image/jpeg')], Doc(title: 'পাসপোর্ট', folder: 'পাসপোর্ট', fields: const [DocField('নাম', 'সাইফুল')]), texts: const ['']);
    (rig.brain.services.ocr as FakeTextReader).text = 'Passport No.\nA01234567\nName\nMD SAIFUL ISLAM\nDate of Expiry 11 MAY 2031';
    await rig.brain.addDocGroup([PickedDoc(png, 'b.jpg', 'image/jpeg')], data().docs.single);
    await t.runAsync(() => rig.brain.readingDone);
    final now = data().docs.singleWhere((x) => x.id == d.id);
    final f = {for (final x in now.fields) x.label: x.value};
    expect(f['নাম'], 'সাইফুল', reason: 'what the user wrote stays');
    expect(f['পাসপোর্ট নম্বর'], 'A01234567');
    expect(now.expiry, DateTime(2031, 5, 11));
    expect(now.files.last.text, contains('A01234567'));
  });
}
