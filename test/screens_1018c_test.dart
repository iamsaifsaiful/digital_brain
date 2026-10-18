// The third set of 18 Oct screenshots (2.24.0-b33), replayed.
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

  Future<void> open(WidgetTester t) async {
    rig = await start(t);
    final d = rig.brain.data;
    d.reminders.addAll([
      Reminder(id: 'r1', title: 'ঢাকায় যাবো', date: DateTime(2026, 10, 10), hour: 10),
      Reminder(id: 'r3', title: 'কাজ কর চারটায় পড়ানো আছে', date: DateTime(2026, 10, 30), hour: 16),
      Reminder(id: 'r4', title: 'বাসা ভাড়া', date: DateTime(2026, 11, 10), hour: 10),
      Reminder(id: 'r5', title: 'পার্টি হবে', date: DateTime(2026, 12, 31), hour: 11),
      Reminder(id: 'r6', title: 'পার্টি হবে', date: DateTime(2026, 12, 31), hour: 21),
    ]);
    d.docs.addAll([
      Doc(id: 'd1', title: 'সাইফুলের পাসপোর্ট', folder: 'পাসপোর্ট', expiry: DateTime(2031, 8, 25)),
      Doc(id: 'd2', title: 'জাতীয় পরিচয়পত্র', folder: 'জাতীয় পরিচয়পত্র'),
    ]);
    d.notes.addAll([Note(id: 'n1', title: 'বাজারের লিস্ট', body: 'চাল, ডাল'), Note(id: 'n2', title: 'ওয়াইফাই রাউটার', body: 'ছাদের ঘরে')]);
    d.contacts.add(Contact(id: 'k1', name: 'Fuad Aunty', phone: '01625808958'));
    d.contacts.addAll([for (var i = 0; i < 3; i++) Contact(id: 'im$i', name: 'ইমরান ${['নাঈম', 'হোসেন', 'আলী'][i]}', phone: '0171000000$i')]);
    chat = ChatController(rig.brain);
  }

  testWidgets('১. reminders of two dates removed, asked once', (t) async {
    await open(t);
    final q = await say('৩০ ই অক্টোবর এবং ৩১ ডিসেম্বরের রিমাইন্ডার বাদ দাও');
    expect(q, contains('৩টা রিমাইন্ডার মুছে দেব?'));
    await say('হ্যাঁ');
    expect([for (final r in rig.brain.data.reminders) r.id], unorderedEquals(['r1', 'r4']));
  });

  testWidgets('২. "আজ বাজারে যাবো রাত ৯ টায়" keeps the time', (t) async {
    await open(t);
    await say('আজ বাজারে যাবো রাত ৯ টায়।');
    final rs = rig.brain.data.reminders.where((r) => r.title.contains('বাজার'));
    final ts = rig.brain.data.tasks.where((x) => x.title.contains('বাজার'));
    expect(rs.length + ts.length, greaterThan(0));
    if (rs.isNotEmpty) expect(rs.first.hour, 21);
    if (ts.isNotEmpty) {
      final id = ts.first.reminderId;
      expect(id, isNotNull, reason: 'the time said is a reminder on the to-do');
      expect(rig.brain.data.reminders.firstWhere((r) => r.id == id).hour, 21);
    }
  });

  testWidgets('৩. "২০৩১ সালে আমি কোটিপতি হবো" is a goal for 2031', (t) async {
    await open(t);
    final r = await say('২০৩১ সালে আমি কোটিপতি হবো');
    expect(r, isNot(contains('বিভাগ')));
    final task = rig.brain.data.tasks.single;
    expect(task.span, TaskSpan.year);
    expect(task.due?.year, 2031);
  });

  testWidgets('৪. "আমার কাজের সকল তালিকা দেখাও" is the whole list', (t) async {
    await open(t);
    rig.brain.data.tasks.add(Task(id: 't1', title: 'বাজার করা', due: DateTime(2026, 10, 9)));
    final r = await say('আমার কাজের সকল তালিকা দেখাও');
    expect(r, contains('বাজার করা'));
  });

  testWidgets('৫. দাওয়াত on two days; a non-time answer is not a time', (t) async {
    await open(t);
    final r = await say('রবিনের বোনের বিয়েতে ২৩ এবং ২৪ তারিখে দাওয়াত');
    expect(r, isNot(contains('কোনো রিমাইন্ডার নেই')));
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    final days = {
      for (final x in rig.brain.data.tasks) if (x.title.contains('দাওয়াত')) x.due?.day,
      for (final x in rig.brain.data.reminders) if (x.title.contains('দাওয়াত')) x.date.day,
    };
    expect(days, containsAll([23, 24]));
  });

  testWidgets('৫খ. "কয়টায়?" answered "আমার পাসপোর্ট দাও" sets no time', (t) async {
    await open(t);
    await say('দুপুরে দাওয়াত মনে করিয়ে দিও');
    expect(chat.wait, ChatWait.reminderTime);
    await say('আমার পাসপোর্ট দাও');
    expect(rig.brain.data.reminders.where((x) => x.title.contains('দাওয়াত')), isEmpty);
  });

  testWidgets('৬. "আমার পাসপোর্ট দাও", "আমার জাতীয় পরিচয় পত্র দাও" show the paper', (t) async {
    await open(t);
    expect(await say('আমার পাসপোর্ট দাও'), contains('সাইফুলের পাসপোর্ট'));
    final r = await say('আমার জাতীয় পরিচয় পত্র দাও');
    expect(r, isNot(contains('বিভাগ')));
    expect(r, contains('জাতীয় পরিচয়পত্র'));
  });

  testWidgets('৭. "ইমরান আজ ১৫০০০ টাকা দিবে" is a plan, not a payment', (t) async {
    await open(t);
    final r = await say('ইমরান আজ ১৫০০০ টাকা দিবে');
    expect(r, isNot(contains('নামটা বলেন')));
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(rig.brain.data.ledger, isEmpty);
  });

  testWidgets('৭খ. "ফেরত পেলাম" with nothing owed is asked, not turned into a debt', (t) async {
    await open(t);
    final r = await say('ইমরান নাঈম ১৫০০০ টাকা ফেরত দিল');
    expect(r, contains('পাওনা ছিল না'));
  });

  testWidgets('৮. a numbered list under "এই বছরে কিছু কাজ আছে"', (t) async {
    await open(t);
    await say('আমার এই বছরে কিছু কাজ আছে,\n\n১. ফাউন্ডেশনের টাকা উঠানো\n২. রাফির টাকা দেওয়া\n৩. এই এপকে বাজারে ছাড়া\n৪. আমাদের পুকুরে মাছ ছাড়া\n৫. আমাদের বাড়ি পরিষ্কার করা');
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    final ts = rig.brain.data.tasks;
    expect(ts, hasLength(5));
    expect(ts.map((x) => x.title), contains('রাফির টাকা দেওয়া'));
    expect(ts.every((x) => x.span == TaskSpan.year), isTrue);
    expect(rig.brain.data.ledger, isEmpty);
  });

  testWidgets('৯. "আমার কোন নোট আছে?" lists the notes', (t) async {
    await open(t);
    final r = await say('আমার কোন নোট আছে?');
    expect(r, allOf(contains('বাজারের লিস্ট'), contains('ওয়াইফাই রাউটার')));
    expect(r, isNot(contains('Fuad')));
  });

  testWidgets('১০. "গুগল ব্যাকআপ অন আছে?" answered', (t) async {
    await open(t);
    final r = await say('গুগল ব্যাকআপ অন আছে?');
    expect(r, isNot(contains('তথ্য নেই')));
    expect(r, contains('ব্যাকআপ'));
  });

  testWidgets('১১. "কোনটা মেয়াদ শেষের দিকে?"', (t) async {
    await open(t);
    final r = await say('কোনটা মেয়াদ শেষের দিকে?');
    expect(r, contains('সাইফুলের পাসপোর্ট'));
  });

  testWidgets('৫গ. "না। ২৩ তারিখ এবং ২৪ তারিখ, দুই দিনেই দাওয়াত আছে" and "২৪ তারিখেও দাওয়াত আছে"', (t) async {
    await open(t);
    await say('না। ২৩ তারিখ এবং ২৪ তারিখ, দুই দিনেই দাওয়াত আছে');
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect({for (final x in rig.brain.data.tasks) x.due?.day}, {23, 24});
    expect(rig.brain.data.tasks.first.title, 'দাওয়াত');
    await say('২৪ তারিখেও দাওয়াত আছে');
    expect(rig.brain.data.tasks.where((x) => x.due?.day == 24), isNotEmpty);
  });

  testWidgets('৫ঘ. questions about dates still answered', (t) async {
    await open(t);
    expect(await say('৩১ ডিসেম্বর কী আছে?'), contains('পার্টি'));
    expect(await say('পার্টি কবে?'), contains('৩১'));
  });

  testWidgets('৫ঙ. "দুপুরে দাওয়াত" after the days were told', (t) async {
    await open(t);
    await say('রবিনের বোনের বিয়েতে ২৩ এবং ২৪ তারিখে দাওয়াত');
    final r = await say('দুপুরে দাওয়াত');
    expect(r, contains('কয়টায়'));
    expect(r, contains('২৩'));
    await say('১টায়');
    final rs = rig.brain.data.reminders.where((x) => x.title.contains('দাওয়াত')).toList();
    expect({for (final x in rs) (x.date.day, x.hour)}, {(23, 13), (24, 13)});
  });
}
