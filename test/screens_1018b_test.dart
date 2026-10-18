// The second set of 18 Oct screenshots (2.23.0-b30), replayed.
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
    print('» $s\n  $r  [wait=${chat.wait}]');
    return r;
  }

  Future<void> open(WidgetTester t) async {
    rig = await start(t);
    final d = rig.brain.data;
    d.contacts.addAll([
      Contact(id: 'k1', name: 'Std Ahad B', phone: '01700000001'),
      Contact(id: 'k2', name: 'Wahid Kaka Paikpara', phone: '01700000002'),
      Contact(id: 'k3', name: 'STD AHAD F', phone: '01700000003'),
      Contact(id: 'k4', name: 'STD AHAD 9', phone: '01700000004'),
      Contact(id: 'k5', name: 'সবুজ SIR', phone: '01700000005'),
    ]);
    d.ledger.addAll([
      LedgerEntry(id: 'l1', person: 'শফিক ভাই', kind: LedgerKind.lent, amount: 10000, date: DateTime(2026, 10, 1)),
      LedgerEntry(id: 'l2', person: 'ইসমাইল', kind: LedgerKind.lent, amount: 2000, date: DateTime(2026, 10, 2)),
    ]);
    d.reminders.addAll([
      Reminder(id: 'r2', title: 'ঢাকায় যাবো', date: DateTime(2026, 10, 10), hour: 10),
      Reminder(id: 'r4', title: 'বাসা ভাড়া', date: DateTime(2026, 11, 10), hour: 10),
    ]);
    chat = ChatController(rig.brain);
  }

  testWidgets('১. a list into the to-do list: one each, with its own date', (t) async {
    await open(t);
    await say('কাজের তালিকায় লেখা, ৩১ই অক্টোবর তুবার জন্মদিন, ৪ই নভেম্বর মোস্তাফার জন্মদিন, ৭ই নভেম্বর হিরার জন্মদিন');
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    final ts = rig.brain.data.tasks;
    expect(ts.map((x) => x.title), containsAll(['লেখা', 'তুবার জন্মদিন', 'মোস্তাফার জন্মদিন', 'হিরার জন্মদিন']));
    expect(ts.firstWhere((x) => x.title == 'হিরার জন্মদিন').due, DateTime(2026, 11, 7));
  });

  testWidgets('২. birthday reminder at a said time keeps the time', (t) async {
    await open(t);
    await say('৩১ই অক্টোবর সকাল ১১ টায় তুবার জন্মদিনের রিমাইন্ডার দাও');
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    final r = rig.brain.data.reminders.firstWhere((x) => x.title.contains('তুবা'));
    expect(r.hour, 11);
  });

  testWidgets('৩. "কত গুলো রিমাইন্ডার আছে?" counts', (t) async {
    await open(t);
    final r = await say('আমার কত গুলো রিমাইন্ডার আছে?');
    expect(r, isNot(contains('এই নামে')));
    expect(r, contains('২টা'));
  });

  testWidgets('৪. "জন্মদিন ছাড়া সব রিমাইন্ডার মুছে দাও" keeps every birthday', (t) async {
    await open(t);
    await say('৩১ অক্টোবর তুবার জন্মদিন');
    await say('হ্যাঁ');
    await say('৪ই নভেম্বর মোস্তাফার জন্মদিন');
    await say('হ্যাঁ');
    await say('আমার কত গুলো রিমাইন্ডার আছে?');
    final q = await say('জন্মদিন ছাড়া সব রিমাইন্ডার মুছে দাও');
    expect(q, contains('২টা'));
    await say('হ্যাঁ');
    expect(rig.brain.data.reminders.where((x) => x.title.contains('জন্মদিন')), hasLength(2));
    expect(rig.brain.data.reminders, hasLength(2));
  });

  testWidgets('৪খ. "জন্মদিনের গুলো থাকবে, বাকি গুলো বাদ দাও"', (t) async {
    await open(t);
    await say('৩১ অক্টোবর তুবার জন্মদিন');
    await say('হ্যাঁ');
    await say('৪ই নভেম্বর মোস্তাফার জন্মদিন');
    await say('হ্যাঁ');
    await say('আমার কত গুলো রিমাইন্ডার আছে?');
    final q = await say('জন্মদিনের গুলো থাকবে, বাকি গুলো বাদ দাও');
    expect(q, contains('২টা'));
  });

  testWidgets('৫. "আমার আয় ব্যয়ের হিসাব দাও" is a money answer, never a to-do', (t) async {
    await open(t);
    await say('আজকের কাজের তালিকা দাও');
    for (final s in ['আমার আয় ব্যয়ের হিসাব দাও', 'আয় ব্যয়ের হিসাব চাইছি']) {
      final r = await say(s);
      expect(r, isNot(contains('কাজের তালিকায় রেখেছি')));
    }
    expect(rig.brain.data.tasks, isEmpty);
  });

  testWidgets('৬. পাওনা shown → "সব গুলো বাদ দাও" is about পাওনা, not an old list', (t) async {
    await open(t);
    await say('আজকের কাজের তালিকা দাও');
    await say('আমার পাওনা টাকা কত?');
    final r = await say('সব গুলো বাদ দাও');
    expect(r, isNot(contains('তালিকার এগুলো আর নেই')));
    expect(r, contains('কী করব?'));
    await say('পুরো হিসাব মুছে দাও');
    expect(rig.brain.data.ledger, isEmpty);
  });

  testWidgets('৬খ. "পাওনা টাকা গুলো বাদ দাও"', (t) async {
    await open(t);
    final r = await say('পাওনা টাকা গুলো বাদ দাও');
    expect(r, contains('২ জনের মোট ১২,০০০ টাকার হিসাব'));
  });

  testWidgets('৭. alarm questions answer, not open a page', (t) async {
    await open(t);
    rig.brain.data.reminders.add(Reminder(id: 'al', title: 'ঘুম থেকে ওঠা', date: DateTime(2026, 10, 10), hour: 6, alarm: true, repeat: Repeat.daily));
    for (final s in ['আমার কোন এলার্ম আছে?', 'কখন আছে এলার্ম?']) {
      final r = await say(s);
      expect(r, contains('ঘুম থেকে ওঠা'));
    }
  });

  testWidgets('৮. "প্রতি রবিবার থেকে বৃহস্পতিবার এলার্ম…"', (t) async {
    await open(t);
    await say('প্রতি রবিবার থেকে বৃহস্পতিবার এলার্ম দাও বিকাল ৪ টায়, পড়ানো আছে আমার');
    final r = rig.brain.data.reminders.firstWhere((x) => x.hour == 16);
    expect(r.alarm, isTrue);
    expect(r.weekdays.toSet(), {DateTime.sunday, DateTime.monday, DateTime.tuesday, DateTime.wednesday, DateTime.thursday});
    expect(r.title, isNot(contains('প্রতি')));
    expect(r.title, contains('পড়ানো'));
    expect(chat.messages.last.text, contains('রবিবার'));
  });

  testWidgets('৯. "কত গুলো যোগাযোগ নাম্বার আছে?" counts', (t) async {
    await open(t);
    final r = await say('আমার কত গুলো যোগাযোগ নাম্বার আছে?');
    expect(r, contains('৫'));
  });

  testWidgets('১০. "রবিন হায়দারকে কল দাও" does not offer Ahad; the correction re-searches', (t) async {
    await open(t);
    final r = await say('রবিন হায়দারকে কল দাও');
    expect(r, isNot(contains('Ahad')));
    expect(r, isNot(contains('AHAD')));
    expect(r, contains('রবিন হায়দার'));
    rig.brain.data.contacts.add(Contact(id: 'k9', name: 'Robin Haider', phone: '01700000009'));
    final r2 = await say('রবিন হায়দারকে কল দাও');
    expect(r2, contains('Robin Haider'));
  });

  testWidgets('১১. typed on several lines under a heading: one to-do per line', (t) async {
    await open(t);
    await say('কালকের কাজ:\n- বাজার করা\n- ওষুধ আনা\n৩১ অক্টোবর রিপোর্ট জমা');
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    final ts = rig.brain.data.tasks;
    expect(ts, hasLength(3));
    expect(ts.firstWhere((x) => x.title.contains('বাজার')).due, DateTime(2026, 10, 10));
    expect(ts.firstWhere((x) => x.title.contains('রিপোর্ট')).due, DateTime(2026, 10, 31));
  });

  testWidgets('১২. several lines without a heading: each its own sentence', (t) async {
    await open(t);
    await say('কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও\nআমার পাওনা টাকা কত?');
    expect(rig.brain.data.reminders.where((x) => x.title.contains('মিটিং')), hasLength(1));
  });

  testWidgets('১৩. পাওনা → "সব গুলো বাদ দাও" → "শোধ হয়ে গেছে" keeps the history', (t) async {
    await open(t);
    await say('আমার পাওনা টাকা কত?');
    await say('সব গুলো বাদ দাও');
    await say('শোধ হয়ে গেছে ধরে নাও (হিসাব থাকবে)');
    expect(rig.brain.data.ledger, hasLength(4));
    final r = await say('আমার পাওনা টাকা কত?');
    expect(r, contains('পাওনা নেই'));
  });

  testWidgets('১৪. a list shown, then another topic: a bare "এগুলো" is asked', (t) async {
    await open(t);
    await say('আর কোন রিমাইন্ডার আছে?');
    await say('কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও');
    final r = await say('এগুলো সব মুছে দাও');
    expect(r, contains('কোন তালিকা'));
    expect(rig.brain.data.reminders, hasLength(3));
  });
}
