// The fourth set of 18 Oct screenshots (2.25.0-b34), replayed word for word.
import 'package:digital_brain/logic/match.dart';
import 'package:digital_brain/models/extras.dart';
import 'package:digital_brain/models/models.dart';
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
    rig.nowAt = DateTime(2026, 10, 18, 15, 18);
    final d = data();
    d.docs.addAll([
      Doc(id: 'd1', title: 'সাইফুলের পাসপোর্ট', folder: 'পাসপোর্ট', expiry: DateTime(2031, 8, 25)),
      Doc(id: 'd2', title: 'জাতীয় পরিচয়পত্র', folder: 'জাতীয় পরিচয়পত্র'),
    ]);
    d.contacts.addAll([
      Contact(id: 'c1', name: 'Robin Hayder', phone: '+8801647150034'),
      Contact(id: 'c2', name: 'Robin Hayder', phone: '+8801711150099'),
      Contact(id: 'c3', name: 'DMC RABBANI', phone: '01711111111'),
      Contact(id: 'c4', name: 'Mozammel Mam Robin', phone: '01722222222'),
      Contact(id: 'c5', name: 'Ritu Shoshur', phone: '+8801756006837'),
    ]);
    d.vault.add(VaultItem(id: 'v1', name: 'ফেসবুক', username: 'saif', password: 'x1'));
    d.health.add(HealthLog(kind: HealthKind.weight, at: DateTime(2026, 10, 18), a: 82));
    d.cash.addAll([
      CashEntry(id: 'i1', kind: CashKind.income, amount: 2500, category: 'বেতন', date: DateTime(2026, 10, 5)),
      CashEntry(id: 'e0', kind: CashKind.expense, amount: 100, category: 'বাজার', date: DateTime(2026, 9, 5)),
    ]);
    d.projects.add(Project(id: 'p1', name: 'শিক্ষার্থীদের বেতন'));
    d.specialDays.add(SpecialDay(person: 'তুবা', month: 10, day: 31));
    chat = ChatController(rig.brain);
  }

  testWidgets('১. dated lines (and the same in one sentence) are a to-do and birthdays — never notes', (t) async {
    await open(t);
    final r = await say('২৪ তারিখে দাওয়াত\n৩১ তারিখে মোস্তাফার জন্মদিন\n৭ তারিখে হিরার জন্মদিন');
    expect(r, isNot(contains('বিভাগ')));
    await say('হ্যাঁ');
    expect(data().notes, isEmpty);
    expect(data().tasks.map((x) => x.title), ['দাওয়াত']);
    expect(data().tasks.single.due, DateTime(2026, 10, 24));
    expect([for (final s in data().specialDays) '${s.person} ${s.month}/${s.day}'], containsAll(['মোস্তাফা 10/31', 'হিরা 11/7']));
    await say('২৫ তারিখে মিটিং, ৪ তারিখে রবিনের জন্মদিন');
    await say('হ্যাঁ');
    expect(data().tasks.map((x) => x.title), containsAll(['দাওয়াত', 'মিটিং']));
    expect(data().specialDays.any((s) => s.person == 'রবিন' && s.month == 11 && s.day == 4), isTrue);
  });

  testWidgets('২. "আজ কয়েকটি কাজ আছে" asks for them — no to-do called "কয়েকটি"', (t) async {
    await open(t);
    final r = await say('আজ কয়েকটি কাজ আছে');
    expect(r, contains('কোন কোন কাজ'));
    await say('আমার এই বছরে কিছু কাজ আছে');
    expect(data().tasks, isEmpty);
    expect(data().notes, isEmpty);
  });

  testWidgets('৩. "রিমাইন্ডার গুলো দাও" / "কি কি" list them', (t) async {
    await open(t);
    data().reminders.addAll([
      Reminder(id: 'r1', title: 'তুবার জন্মদিন', date: DateTime(2026, 10, 31), hour: 9),
      Reminder(id: 'r2', title: 'হিরার জন্মদিন', date: DateTime(2026, 11, 7), hour: 9),
    ]);
    for (final s in ['রিমাইন্ডার গুলো কি কি', 'রিমাইন্ডার গুলো দাও', 'আমার কি কি রিমাইন্ডার আছে']) {
      final r = await say(s);
      expect(r, contains('তুবার জন্মদিন'), reason: s);
      expect(r, isNot(contains('একসাথে')), reason: s);
    }
  });

  testWidgets('৪. "আজ সন্ধ্যায় কোন কাজ আছে?" is the evening only', (t) async {
    await open(t);
    final d = data();
    d.reminders.addAll([
      Reminder(id: 'rm', title: 'সকালের মিটিং', date: DateTime(2026, 10, 18), hour: 10),
      Reminder(id: 're', title: 'দোকানে যাওয়া', date: DateTime(2026, 10, 18), hour: 19),
    ]);
    d.tasks.add(Task(id: 't1', title: 'বাজার করা', due: DateTime(2026, 10, 18), createdAt: rig.nowAt));
    final r = await say('আমার আজ সন্ধ্যায় কোন কাজ আছে?');
    expect(r, contains('দোকানে যাওয়া'));
    expect(r, isNot(contains('সকালের মিটিং')));
    expect(r, contains('সময় ছাড়া'));
  });

  testWidgets('৫. "কিভাবে ডকুমেন্টস যুক্ত করব" is answered, not kept as a to-do', (t) async {
    await open(t);
    final r = await say('কিভাবে ডকুমেন্টস যুক্ত করব');
    expect(r, contains('ডকুমেন্টস'));
    expect(data().tasks, isEmpty);
  });

  testWidgets('৬. "মনে করানোর প্রয়োজন নেই। কাজের তালিকা রাখো শুধু" makes the reminder a to-do', (t) async {
    await open(t);
    await say('আমরা আগামীকাল বিকালে মাঠে খেলবো');
    final r = await say('৫টায়');
    expect(r, contains('৫টায়'));
    expect(r, isNot(contains('টা-এ')));
    expect(data().reminders, hasLength(1));
    await say('মনে করানোর প্রয়োজন নেই। কাজের তালিকা রাখো শুধু');
    expect(data().reminders, isEmpty, reason: 'no ring, as asked');
    final task = data().tasks.single;
    expect(task.title, 'মাঠে খেলবো');
    expect(task.due, DateTime(2026, 10, 19));
    expect(task.reminderId, isNull);
  });

  testWidgets('৭. "আগের কাজ গুলো নোট এ কেন রাখছো?" moves today\'s notes to the to-do list', (t) async {
    await open(t);
    data().notes.addAll([
      Note(id: 'n1', title: '২৪ তারিখে দাওয়াত', body: '২৪ তারিখে দাওয়াত', category: 'তারিখে', updatedAt: rig.nowAt.subtract(const Duration(minutes: 20))),
      Note(id: 'n2', title: 'পুরোনো', body: 'গাড়ির কাগজ আলমারিতে', updatedAt: DateTime(2026, 9, 1)),
    ]);
    final r = await say('আগের কাজ গুলো নোট এ কেন রাখছো? কাজের তালিকায় রাখা উচিত ছিল');
    expect(r, contains('সরিয়ে দিলাম'));
    expect(data().notes.map((n) => n.id), ['n2']);
    expect(data().tasks.single.title, 'দাওয়াত');
    expect(data().tasks.single.due, DateTime(2026, 10, 24));
  });

  testWidgets('৮. অন্যান্য হিসাব: shown, money added to one, found again, a new one opened', (t) async {
    await open(t);
    for (final s in ['অন্যান্য হিসাব দাও', 'আমি দেনা পাওনা বলি নাই, বলেছি, অন্যান্য হিসাব', 'আমার অন্যান্য হিসাবের একটা সারাংশ দাও']) {
      final r = await say(s);
      expect(r, contains('শিক্ষার্থীদের বেতন'), reason: s);
      expect(r, isNot(contains('পাওনা-দেনা')), reason: s);
    }
    await say('নিহান ২০০০ টাকা বেতন দিয়েছে, এটা অন্যান্য হিসাবের ভেতরে শিক্ষার্থীদের বেতনে যুক্ত কর');
    await say('হ্যাঁ');
    final e = data().cash.where((x) => x.amount == 2000 && x.linkId == null).single;
    expect(e.kind, CashKind.income);
    expect(e.projectId, 'p1');
    expect(data().ledger, isEmpty);
    expect(await say('নিহানের বেতন কোথায় যুক্ত করলে?'), contains('শিক্ষার্থীদের বেতন'));
    await say('মৃত্তিকা ফাউন্ডেশন নামে অন্যান্য হিসাবে একটা বিভাগ লেখ');
    expect(data().projects.map((p) => p.name), contains('মৃত্তিকা ফাউন্ডেশন'));
  });

  testWidgets('৯. a market trip: each thing bought is an expense; the money taken along is not', (t) async {
    await open(t);
    final r = await say('আজ বাজারে গিয়েছি ৫০০০ টাকা নিয়ে। ৬০০ টাকার মুরগি কিনলাম, ১০০০ টাকার গরুর মাংস, ৩৫০ টাকার সবজি, ২২০ টাকার মুদি মালামাল এবং ৮০ টাকা রিক্সা ভাড়া');
    expect(r, contains('৫টা'));
    await say('হ্যাঁ');
    final today = [for (final e in data().cash) if (e.date.day == 18) e];
    expect(today.map((e) => e.amount), unorderedEquals([600, 1000, 350, 220, 80]));
    expect(today.every((e) => e.kind == CashKind.expense), isTrue);
    expect(data().ledger, isEmpty);
    expect(today.firstWhere((e) => e.amount == 80).category, 'যাতায়াত');
  });

  testWidgets('১০. "আমার সকল আয় বাদ দাও": the income only, asked once; a new sentence meanwhile is heard', (t) async {
    await open(t);
    final q = await say('আমার সকল আয় বাদ দাও');
    expect(q, contains('মুছে দেব'));
    final r = await say('ফাউন্ডেশনের কাছে আমি ৬৪ হাজার টাকা পাবো');
    expect(r, isNot(contains('কিছু মুছিনি')));
    expect(r, contains('ফাউন্ডেশন'));
    expect(data().cash.where((e) => e.kind == CashKind.income), hasLength(1), reason: 'nothing removed without a yes');
    await say('না');
    await say('আমার সকল আয় বাদ দাও');
    await say('হ্যাঁ');
    expect(data().cash.where((e) => e.kind == CashKind.income), isEmpty);
    expect(data().cash.where((e) => e.kind == CashKind.expense), hasLength(1), reason: 'expenses stay');
  });

  testWidgets('১১. "এই মাসে কত খরচ হলো?" answers the spending first', (t) async {
    await open(t);
    expect(await say('এই মাসে কত খরচ হলো?'), startsWith('এই মাসে খরচের কোনো তথ্য নেই'));
  });

  testWidgets('১২. "ফাউন্ডেশনের নাম মৃত্তিকা ফাউন্ডেশন" renames that account; "না। …" hears the rest', (t) async {
    await open(t);
    await say('ফাউন্ডেশনের কাছে আমি ৬৪ হাজার টাকা পাবো');
    await say('হ্যাঁ');
    await say('ফাউন্ডেশনের নাম মৃত্তিকা ফাউন্ডেশন');
    expect(data().ledger.map((e) => e.person).toSet(), {'মৃত্তিকা ফাউন্ডেশন'});
    expect(data().notes, isEmpty);
    // A yes/no waiting, answered "না" with something else after it.
    await say('পানির ফিল্টারের নাম পিউরিট');
    expect(chat.wait, ChatWait.yesNo);
    final r = await say('না। আজ নামাজের সময় দাও');
    expect(r, contains('রাখলাম না'));
    expect(r, contains('ফজর'));
  });

  testWidgets('১৩. calling রবিন: the Robins, counted as named, told apart; no Rabbani', (t) async {
    await open(t);
    final r = await say('রবিনকে কল দাও');
    expect(r, isNot(contains('RABBANI')));
    expect(r, contains('৩ জন'));
    expect(r, contains('…০০৩৪'));
    expect(r, contains('Mozammel Mam Robin'));
  });

  testWidgets('১৪. health questions give the measures — never a password or a contact', (t) async {
    await open(t);
    for (final s in ['আমার স্বাস্থ্যের অবস্থা কি', 'আমার শরীরের অবস্থা কি']) {
      final r = await say(s);
      expect(r, contains('৮২ কেজি'), reason: s);
      expect(r, isNot(contains('ফেসবুক')), reason: s);
      expect(r, isNot(contains('Ritu')), reason: s);
    }
  });

  testWidgets('১৫. prayer times, Ramadan (also while a question waits)', (t) async {
    await open(t);
    final p = await say('আজ নামাজের সময় দাও');
    expect(p, contains('ফজর'));
    expect(p, isNot(contains('বিভাগ')));
    await say('পানির ফিল্টারের নাম পিউরিট');
    final r = await say('রোজা কবে?');
    expect(r, contains('রমজান'));
    expect(r, contains('২০২৭'));
    expect(r, isNot(contains('হ্যাঁ, নাকি না')));
  });

  testWidgets('১৬. what the app can do, and advice, are answered', (t) async {
    await open(t);
    for (final s in ['এই এপ দিয়ে কি কি করা যায়?', 'তুমি আমাকে কিভাবে হেল্প করতে পারো?']) {
      final r = await say(s);
      expect(r, contains('কাজের তালিকা'), reason: s);
      expect(r, isNot(contains('কোনো তথ্য নেই')), reason: s);
    }
    final a = await say('তুবাকে এইবার জন্মদিনে কি দেওয়া যায়?');
    expect(a, contains('পরামর্শ'));
    expect(a, contains('৩১ অক্টোবর'));
  });

  testWidgets('১৭. one message, one "no information" — not twice', (t) async {
    await open(t);
    final n = chat.messages.length;
    await say('অন্য এপে গেলে তোমার আমার কনভারসেশন চলে থাকে না? আমার অন্য চ্যাট অন করে এরপর তোমাকে খুজে বের করা লাগে');
    final replies = chat.messages.skip(n).where((m) => !m.fromUser).map((m) => m.text).toList();
    expect(replies.toSet().length, replies.length);
  });

  test('১৮. sound-alike matching: one word in two scripts, never two different words', () {
    expect(wordsMatch('ফেসবুক', 'facebook'), isTrue);
    expect(wordsMatch('রবিন', 'Robin'), isTrue);
    expect(wordsMatch('অবস্থা', 'ওয়েবসাইট'), isFalse);
    expect(wordsMatch('শরীর', 'Shoshur'), isFalse);
    expect(soundDistance('রবিন', 'Robin'), lessThan(soundDistance('রবিন', 'Rabbani')));
  });
}
