// The 18 Oct screenshots (2.22.0-b29), replayed word for word.
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
    d.tasks.add(Task(id: 'n1', title: 'নিজাম মামা আসবেন', done: true));
    d.contacts.add(Contact(id: 'k1', name: 'সবুজ SIR', phone: '01700000000'));
    d.reminders.addAll([
      Reminder(id: 'r1', title: 'নিজাম মামা আসবেন', date: DateTime(2026, 10, 16), hour: 18),
      Reminder(id: 'r2', title: 'ঢাকায় যাবো', date: DateTime(2026, 10, 10), hour: 10),
      Reminder(id: 'r3', title: 'কাজ কর চারটায় পড়ানো আছে', date: DateTime(2026, 10, 30), hour: 16),
      Reminder(id: 'r4', title: 'বাসা ভাড়া', date: DateTime(2026, 11, 10), hour: 10),
    ]);
    chat = ChatController(rig.brain);
  }

  testWidgets('রাতে পার্টি → "১১ টায়" is রাত ১১টা', (t) async {
    await open(t);
    final q = await say('৩১ই ডিসেম্বরের রাতে পার্টি হবে, রিমাইন্ডার দাও');
    expect(q, contains('কয়টায়'));
    final r = await say('১১ টায়');
    expect(r, contains('রাত ১১টা'));
    final p = rig.brain.data.reminders.firstWhere((x) => x.title.contains('পার্টি'));
    expect(p.hour, 23);
  });

  testWidgets('"আমার সব রিমাইন্ডার বাদ দিয়ে দাও" → all of them, one question', (t) async {
    await open(t);
    final r = await say('আমার সব রিমাইন্ডার বাদ দিয়ে দাও');
    expect(r, contains('৪টা'));
    expect(rig.brain.data.reminders, hasLength(4));
    await say('হ্যাঁ');
    expect(rig.brain.data.reminders, isEmpty);
    expect(rig.brain.data.tasks, hasLength(1));
    expect(rig.brain.data.contacts, hasLength(1));
  });

  testWidgets('"আর কোন রিমাইন্ডার আছে?" lists, no name search', (t) async {
    await open(t);
    final r = await say('আর কোন রিমাইন্ডার আছে?');
    expect(r, isNot(contains('এই নামে')));
    expect(r, contains('বাসা ভাড়া'));
  });

  testWidgets('shown reminders → "সব গুলো বাদ দিয়ে দাও" → those reminders only', (t) async {
    await open(t);
    await say('আর কোন রিমাইন্ডার আছে?');
    final r = await say('সব গুলো বাদ দিয়ে দাও');
    expect(r, contains('রিমাইন্ডার মুছে দেব?'));
    expect(r, isNot(contains('সবুজ')));
    await say('হ্যাঁ');
    expect(rig.brain.data.reminders, isEmpty);
    expect(rig.brain.data.tasks, hasLength(1));
    expect(rig.brain.data.contacts, hasLength(1));
  });

  testWidgets('a pick question answered "সব" is not a photo question', (t) async {
    await open(t);
    await say('নিজাম মামা মুছে দাও');
    final r = await say('সব');
    expect(r, isNot(contains('ছবি')));
  });

  testWidgets('two reminders of one name → "দুটোই" → one confirmation, both', (t) async {
    await open(t);
    rig.brain.data.reminders.add(Reminder(id: 'r5', title: 'নিজাম মামা আসবেন', date: DateTime(2026, 10, 20), hour: 18));
    rig.brain.data.tasks.clear();
    await say('নিজাম মামার রিমাইন্ডার মুছে দাও');
    final q = await say('দুটোই');
    expect(q, contains('২টা রিমাইন্ডার মুছে দেব?'));
    await say('হ্যাঁ');
    expect([for (final r in rig.brain.data.reminders) r.id], unorderedEquals(['r2', 'r3', 'r4']));
  });

  testWidgets('12 upcoming, 10 shown → "সব গুলো বাদ দাও" asks shown or all', (t) async {
    await open(t);
    for (var i = 0; i < 8; i++) {
      rig.brain.data.reminders.add(Reminder(id: 'x$i', title: 'বিল $i', date: DateTime(2026, 11, 20 + i), hour: 9));
    }
    final l = await say('আর কোন রিমাইন্ডার আছে?');
    expect(l, contains('সামনে ১২টা রিমাইন্ডার আছে — প্রথম ১০টা'));
    final q = await say('সব গুলো বাদ দিয়ে দাও');
    expect(q, contains('দেখানো ১০টা, নাকি পাওয়া সব ১২টা?'));
    expect(rig.brain.data.reminders, hasLength(12));
  });

  testWidgets('"আমার সব রিমাইন্ডার বাদ দাও" says all', (t) async {
    await open(t);
    final q = await say('আমার সব রিমাইন্ডার বাদ দিয়ে দাও');
    expect(q, contains('আপনার সব ৪টা রিমাইন্ডার মুছে দেব?'));
    await say('না');
    expect(rig.brain.data.reminders, hasLength(4));
  });

  testWidgets('"সব গুলো বাদ দাও" with nothing shown: asks which list, nothing matched by name', (t) async {
    await open(t);
    final q = await say('সব গুলো বাদ দিয়ে দাও');
    expect(q, contains('কোন তালিকার'));
    expect(rig.brain.data.reminders, hasLength(4));
  });
}
