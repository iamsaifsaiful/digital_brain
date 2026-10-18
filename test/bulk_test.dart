// "আজকের কাজের তালিকা দাও" → "এইগুলো সব মুছে দাও": the list the app showed
// is what "এগুলো" means. Each scenario checks the target ids, what may and
// may not change, the scope, how many questions were asked and what really
// happened — not only the wording.
//
// Written input (test clock: Fri 9 Oct 2026, 15:53). No microphone, no live
// AI: the AI's side is a fixed answer in the tool schema's shape.
import 'package:digital_brain/logic/ai_map.dart';
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, start;

final today = DateTime(2026, 10, 9);
final tomorrow = DateTime(2026, 10, 10);

List<Task> seedTasks() => [
      Task(id: 'a1', title: 'বাজার করা', due: today),
      Task(id: 'a2', title: 'ওষুধ আনা', due: today),
      Task(id: 'a3', title: 'ব্যাংকে যাওয়া', due: today, urgent: true),
      Task(id: 'a4', title: 'বিদ্যুৎ বিল দেওয়া', due: today),
      Task(id: 'a5', title: 'রিপোর্ট পাঠানো', due: today),
      Task(id: 'b1', title: 'স্যারকে ফোন করা', due: tomorrow),
      Task(id: 'b2', title: 'গাড়ি সার্ভিস করানো', due: tomorrow),
      Task(id: 'c1', title: 'অফিসের মিটিং', due: DateTime(2026, 10, 12)),
      Task(id: 'c2', title: 'অফিসের হিসাব জমা', due: DateTime(2026, 10, 13), urgent: true),
    ];

const todayIds = ['a1', 'a2', 'a3', 'a4', 'a5'];

void main() {
  late Rig rig;
  late ChatController chat;
  var questions = 0;

  Future<String> say(String s) async {
    final n = chat.messages.length;
    await chat.hear(s);
    if (chat.wait != ChatWait.none) questions++;
    return chat.messages.skip(n).where((m) => !m.fromUser).map((m) => [m.text, ...m.facts].join(' ')).join(' ');
  }

  Future<void> open(WidgetTester t, {List<Task>? tasks}) async {
    rig = await start(t);
    rig.brain.data.tasks.addAll(tasks ?? seedTasks());
    chat = ChatController(rig.brain);
    questions = 0;
  }

  Set<String> ids() => {for (final x in rig.brain.data.tasks) x.id};
  Task task(String id) => rig.brain.data.tasks.firstWhere((x) => x.id == id);
  List<String> shown() => chat.debugSets.last.ids;

  group('the user\'s example and its family', () {
    testWidgets('১. আজকের তালিকা → "এইগুলো সব মুছে দাও" → one question → exactly those five', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      expect(shown(), unorderedEquals(todayIds));
      questions = 0;
      final r = await say('এইগুলো সব মুছে দাও');
      expect(r, contains('আজকের এই ৫টা কাজ মুছে দেব?'));
      expect(ids(), containsAll(todayIds), reason: 'nothing removed before the yes');
      final done = await say('হ্যাঁ');
      expect(done, contains('৫টা কাজ মুছে দিয়েছি'));
      expect(ids(), {'b1', 'b2', 'c1', 'c2'}, reason: 'other days untouched');
      expect(questions, 1, reason: 'one confirmation, no "কোন কাজ?"');
    });

    testWidgets('২. "এগুলা সব কাল রাখো": the five moved, no question', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      questions = 0;
      await say('এগুলা সব কাল রাখো');
      expect([for (final id in todayIds) task(id).due], everyElement(tomorrow));
      expect(task('c1').due, DateTime(2026, 10, 12));
      expect(questions, 0);
    });

    testWidgets('৩. কালকের তালিকা → "সব শেষ করেছি": only tomorrow\'s two', (t) async {
      await open(t);
      await say('কালকের কাজ দাও');
      await say('সব শেষ করেছি');
      expect({for (final x in rig.brain.data.tasks) if (x.done) x.id}, {'b1', 'b2'});
    });

    testWidgets('৪/১৩. অফিসের তালিকা → "শুধু জরুরিগুলো দেখাও" → "সব কাল রাখো": the narrowed one only', (t) async {
      await open(t);
      await say('অফিসের কাজগুলো দেখাও');
      expect(shown(), unorderedEquals(['c1', 'c2']));
      final r = await say('এর মধ্যে জরুরিগুলো দেখাও');
      expect(r, contains('অফিসের হিসাব জমা'));
      expect(shown(), ['c2']);
      await say('সব কাল রাখো');
      expect(task('c2').due, tomorrow);
      expect(task('c1').due, DateTime(2026, 10, 12));
    });

    testWidgets('৫. "দ্বিতীয় আর চতুর্থটা শেষ করো": those two places of the list shown', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      final list = shown();
      await say('দ্বিতীয় আর চতুর্থটা শেষ করো');
      expect({for (final x in rig.brain.data.tasks) if (x.done) x.id}, {list[1], list[3]});
    });

    testWidgets('৬. "প্রথম দুটো মুছো": the first two, after one yes', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      final list = shown();
      await say('প্রথম দুটো মুছো');
      await say('হ্যাঁ');
      expect(ids().intersection({list[0], list[1]}), isEmpty);
      expect(ids(), containsAll(list.skip(2)));
    });

    testWidgets('৭. "শেষের তিনটা কাল রাখো"', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      final list = shown();
      await say('শেষের তিনটা কাল রাখো');
      expect([for (final id in list.skip(2)) task(id).due], everyElement(tomorrow));
      expect([for (final id in list.take(2)) task(id).due], everyElement(today));
    });

    testWidgets('৮. "দ্বিতীয়টা ছাড়া সব শেষ"', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      final list = shown();
      await say('দ্বিতীয়টা ছাড়া সব শেষ');
      expect({for (final x in rig.brain.data.tasks) if (x.done) x.id}, {...list}..remove(list[1]));
    });

    testWidgets('৯/৩৯. "ব্যাংকেরটা থাকবে, বাকিগুলো বাদ" and "সব মুছো, শুধু ব্যাংকেরটা থাকবে": four, the bank stays', (t) async {
      for (final said in ['ব্যাংকেরটা থাকবে, বাকিগুলো বাদ', 'সব মুছো, শুধু ব্যাংকেরটা থাকবে']) {
        await open(t);
        await say('আজকের কাজের তালিকা দাও');
        final r = await say(said);
        expect(r, contains('৪টা'), reason: said);
        await say('হ্যাঁ');
        expect(ids(), {'a3', 'b1', 'b2', 'c1', 'c2'}, reason: said);
      }
    });

    testWidgets('১০. "সব মুছো না": nothing, no question', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      questions = 0;
      await say('এগুলো সব মুছো না');
      expect(ids(), hasLength(9));
      expect(questions, 0);
    });

    testWidgets('১১. "এগুলো আজ না, কাল রাখো": moved to tomorrow', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      await say('এগুলো সব আজ না, কাল রাখো');
      expect([for (final id in todayIds) task(id).due], everyElement(tomorrow));
    });

    testWidgets('১২. "প্রথম দুটো মুছো" → "না, শেষের দুটো": the proposal replaced — two removed, not four', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      final list = shown();
      await say('প্রথম দুটো মুছো');
      final r = await say('না, শেষের দুটো');
      expect(r, contains('২টা'));
      await say('হ্যাঁ');
      expect(ids(), containsAll(list.take(3)));
      expect(ids().intersection({list[3], list[4]}), isEmpty);
    });

    testWidgets('"সব কাল রাখো — না, পরশু": the later day wins', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      await say('সব কাল রাখো — না, পরশু');
      expect([for (final id in todayIds) task(id).due], everyElement(DateTime(2026, 10, 11)));
    });

    testWidgets('১৪. reversed order → "প্রথম দুটো শেষ": the first two as now shown', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      final list = shown();
      await say('এবার উল্টো ক্রমে দেখাও');
      expect(shown(), list.reversed.toList());
      await say('প্রথম দুটো শেষ');
      expect({for (final x in rig.brain.data.tasks) if (x.done) x.id}, {list[4], list[3]});
    });

    testWidgets('১৫/১৬. more matched than shown: which is asked — then only those', (t) async {
      final many = [for (var i = 0; i < 35; i++) Task(id: 'm$i', title: 'কাজ নম্বর $i', due: today)];
      await open(t, tasks: many);
      await say('আজকের কাজের তালিকা দাও');
      final r = await say('এগুলো সব মুছে দাও');
      expect(r, contains('দেখানো ৩০টা, নাকি পাওয়া সব ৩৫টা?'));
      expect(ids(), hasLength(35));
      final r2 = await say('দেখানো ৩০টা');
      expect(r2, contains('৩০টা কাজ মুছে দেব?'));
      await say('হ্যাঁ');
      expect(ids(), hasLength(5));
    });

    testWidgets('১৭. an item removed elsewhere: places still mean the list as shown', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      final list = shown();
      await rig.brain.deleteTask(list[0]);
      await say('দ্বিতীয় আর তৃতীয়টা শেষ');
      expect({for (final x in rig.brain.data.tasks) if (x.done) x.id}, {list[1], list[2]});
    });

    testWidgets('১৮/২২. the list changes while the question waits: nothing new is removed; the result says what happened', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      await say('এগুলো সব মুছে দাও');
      rig.brain.data.tasks.add(Task(id: 'new', title: 'নতুন কাজ', due: today));
      await rig.brain.deleteTask('a5');
      final r = await say('হ্যাঁ, দাও');
      expect(r, contains('৪টা কাজ মুছে দিয়েছি'));
      expect(r, contains('১টা আগেই তালিকা থেকে সরে গিয়েছিল'));
      expect(ids(), contains('new'));
    });

    testWidgets('১৯/২১. "হ্যাঁ, দাও" runs once; the same yes again changes nothing', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      await say('এগুলো সব মুছে দাও');
      await say('হ্যাঁ, দাও');
      final after = rig.brain.data.trash.length;
      await say('হ্যাঁ, দাও');
      expect(rig.brain.data.trash.length, after);
      expect(ids(), {'b1', 'b2', 'c1', 'c2'});
    });

    testWidgets('২০. "না, থাক": zero changes', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      await say('এগুলো সব মুছে দাও');
      await say('না, থাক');
      expect(ids(), hasLength(9));
    });

    testWidgets('২৩. a retry of the same move changes nothing more', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      await say('সব কাল রাখো');
      final r = await say('সবগুলো কাল রাখো');
      expect(r, contains('বদলানোর কিছু ছিল না'));
    });

    testWidgets('২৪. removed together → "ওগুলো ফেরত আনো": the same batch back', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      await say('এগুলো সব মুছে দাও');
      await say('হ্যাঁ');
      final r = await say('ওগুলো সব ফেরত আনো');
      expect(r, contains('৫টাই ফেরত এনেছি'));
      expect(ids(), containsAll(todayIds));
    });

    testWidgets('২৫. after one item was handled, "সবগুলো" is the list — not that one', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      await say('দ্বিতীয়টা জরুরি করো');
      await say('সবগুলো কাল রাখো');
      expect([for (final id in todayIds) task(id).due], everyElement(tomorrow));
    });

    testWidgets('২৬. a short unrelated question in between: "ওই কাজগুলো" still means the list', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      await say('এখন কয়টা বাজে?');
      await say('আচ্ছা, ওই কাজগুলো কাল রাখো');
      expect([for (final id in todayIds) task(id).due], everyElement(tomorrow));
    });

    testWidgets('২৭. a list shown long ago: asked again — nothing removed', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      rig.nowAt = rig.nowAt.add(const Duration(minutes: 45));
      final r = await say('এগুলো সব মুছে দাও');
      expect(r, contains('অনেক আগের'));
      expect(ids(), hasLength(9));
    });

    testWidgets('২৮/২৯. a newer medicine list: "এগুলোর reminder বন্ধ" is the medicines\' — they stay, the to-dos are untouched', (t) async {
      await open(t);
      final r1 = Reminder(title: 'নাপা', date: today, hour: 8, minute: 0, repeat: Repeat.daily);
      rig.brain.data.reminders.add(r1);
      rig.brain.data.medicines.add(Medicine(id: 'm1', name: 'নাপা', times: [480], reminderIds: [r1.id]));
      await say('আজকের কাজের তালিকা দাও');
      await say('ওষুধের তালিকা দাও');
      await say('এগুলোর রিমাইন্ডার বন্ধ করো');
      expect(rig.brain.data.reminders.single.enabled, isFalse);
      expect(rig.brain.data.medicines, hasLength(1));
      expect(ids(), hasLength(9));
    });

    testWidgets('৩১. a mother\'s readings → "দ্বিতীয়টা ভুল" → "১২০/৮০": that reading corrected, none added', (t) async {
      await open(t);
      rig.brain.data.members.add(FamilyMember(id: 'mom', name: 'আম্মা', relation: 'মা'));
      rig.brain.data.health.addAll([
        HealthLog(id: 'h1', member: 'mom', kind: HealthKind.bp, at: DateTime(2026, 10, 9, 8), a: 140, b: 90),
        HealthLog(id: 'h2', member: 'mom', kind: HealthKind.bp, at: DateTime(2026, 10, 8, 8), a: 150, b: 95),
        HealthLog(id: 'h3', member: 'mom', kind: HealthKind.bp, at: DateTime(2026, 10, 7, 8), a: 135, b: 85),
        HealthLog(id: 'h4', member: 'me', kind: HealthKind.bp, at: DateTime(2026, 10, 9, 9), a: 120, b: 80),
      ]);
      await say('আম্মার শেষ তিনটা মাপ দেখাও');
      expect(shown(), ['h1', 'h2', 'h3']);
      final r = await say('দ্বিতীয়টা ভুল');
      expect(r, contains('ঠিক মানটা কত'));
      await say('১২০/৮০');
      final h2 = rig.brain.data.health.firstWhere((x) => x.id == 'h2');
      expect((h2.a, h2.b, h2.member), (120.0, 80.0, 'mom'));
      expect(rig.brain.data.health, hasLength(4));
    });

    testWidgets('৩২. "সজীবের সব টাকা পেয়েছি" after a list: money rules, never a to-do bulk', (t) async {
      await open(t);
      rig.brain.data.ledger.add(LedgerEntry(person: 'সজীব', kind: LedgerKind.lent, amount: 500, date: DateTime(2026, 10, 1), note: ''));
      await say('আজকের কাজের তালিকা দাও');
      await say('সজীবের সব টাকা পেয়েছি');
      expect(rig.brain.data.tasks.where((x) => x.done), isEmpty);
      expect(ids(), hasLength(9));
    });

    testWidgets('৩৩. a repeating to-do in today\'s list: only this time skipped — the series stays', (t) async {
      await open(t, tasks: [...seedTasks(), Task(id: 'r1', title: 'জুমার নামাজ', due: today, repeat: const TaskRepeat.weekly([DateTime.friday]))]);
      await say('আজকের কাজের তালিকা দাও');
      await say('এগুলো সব মুছে দাও');
      final r = await say('হ্যাঁ');
      expect(r, contains('পুরো সিরিজ আছে'));
      expect(task('r1').due, DateTime(2026, 10, 16));
    });

    testWidgets('৩৪. moved with its reminder — no alarm left on the old day', (t) async {
      final r = Reminder(id: 'rem', title: 'বাজার করা', date: today, hour: 18, minute: 0);
      await open(t);
      rig.brain.data.reminders.add(r);
      rig.brain.data.tasks[0] = rig.brain.data.tasks[0].copyWith(reminderId: 'rem');
      await say('আজকের কাজের তালিকা দাও');
      await say('সব কাল রাখো');
      expect(rig.brain.data.reminders.single.date, tomorrow);
    });

    testWidgets('৩৫. an empty list: nothing to remove', (t) async {
      await open(t, tasks: [Task(id: 'x', title: 'অন্য দিনের কাজ', due: DateTime(2026, 10, 20))]);
      await say('আজকের কাজের তালিকা দাও');
      await say('এগুলো সব মুছে দাও');
      await say('হ্যাঁ');
      expect(ids(), {'x'});
    });

    testWidgets('৩৬. "পাঁচ আর সাত নম্বর" in a list of five: said plainly, nothing changed', (t) async {
      await open(t);
      await say('আজকের কাজের তালিকা দাও');
      final r = await say('পাঁচ আর সাত নম্বর শেষ');
      expect(r, contains('৭ নম্বর নেই'));
      expect(rig.brain.data.tasks.where((x) => x.done), isEmpty);
    });

    testWidgets('৩৭. ten in the database, two in the list: only the two', (t) async {
      await open(t);
      await say('অফিসের কাজগুলো দেখাও');
      await say('সব শেষ করেছি');
      expect({for (final x in rig.brain.data.tasks) if (x.done) x.id}, {'c1', 'c2'});
    });

    testWidgets('৩৮. "সব দিনের সব কাজ মুছে দাও": the whole list, said so — asked once with its count', (t) async {
      await open(t);
      final r = await say('সব দিনের সব কাজ মুছে দাও');
      expect(r, contains('৯টা'));
      await say('হ্যাঁ');
      expect(ids(), isEmpty);
    });

    testWidgets('৪০. a name that fits two in the list: asked, nothing removed', (t) async {
      await open(t, tasks: [
        Task(id: 'p1', title: 'স্যারকে ফোন করা', due: today),
        Task(id: 'p2', title: 'ডাক্তারকে ফোন করা', due: today),
        Task(id: 'p3', title: 'বাজার করা', due: today),
      ]);
      await say('আজকের কাজের তালিকা দাও');
      final r = await say('ফোনেরটা থাকবে, বাকিগুলো বাদ');
      expect(r, contains('২টা আছে'));
      expect(ids(), hasLength(3));
    });

    testWidgets('no list shown: "এগুলো সব মুছো" asks which list — never the database', (t) async {
      await open(t);
      final r = await say('এগুলো সব মুছে দাও');
      expect(r, contains('কোন তালিকার'));
      expect(ids(), hasLength(9));
    });

    testWidgets('habits: "প্রথমটা হয়েছে, বাকিগুলো হয়নি"', (t) async {
      await open(t);
      rig.brain.data.habits.addAll([Habit(id: 'w', name: 'হাঁটা', done: ['2026-10-09']), Habit(id: 'q', name: 'বই পড়া', done: ['2026-10-09'])]);
      await say('অভ্যাসগুলো দেখাও');
      await say('প্রথমটা হয়েছে, বাকিগুলো হয়নি');
      expect(rig.brain.data.habits.firstWhere((h) => h.id == 'w').doneOn(today), isTrue);
      expect(rig.brain.data.habits.firstWhere((h) => h.id == 'q').doneOn(today), isFalse);
      expect(rig.brain.data.habits, hasLength(2));
    });

    testWidgets('notes: "অফিসের নোট দেখাও" → "প্রথম দুটো মুছো" → yes', (t) async {
      await open(t);
      rig.brain.data.notes.addAll([
        Note(id: 'n1', title: 'অফিস ওয়াইফাই রুম', category: 'অফিস', updatedAt: DateTime(2026, 10, 9)),
        Note(id: 'n2', title: 'অফিসের চাবি', category: 'অফিস', updatedAt: DateTime(2026, 10, 8)),
        Note(id: 'n3', title: 'অফিস পার্কিং', category: 'অফিস', updatedAt: DateTime(2026, 10, 7)),
        Note(id: 'n4', title: 'বাসার চাবি', category: 'বাসা', updatedAt: DateTime(2026, 10, 9)),
      ]);
      await say('অফিসের নোট দেখাও');
      expect(shown(), ['n1', 'n2', 'n3']);
      await say('প্রথম দুটো মুছো');
      await say('হ্যাঁ');
      expect({for (final n in rig.brain.data.notes) n.id}, {'n3', 'n4'});
    });
  });

  group('words that are not a request on the list', () {
    test('a description and a negative are not bulk; a command is', () {
      final now = DateTime(2026, 10, 9, 15, 53);
      expect(bulkCommands('ও এসব মুছে দেয়', now), isNull);
      expect(bulkCommands('এগুলো সব মুছো না', now), isNull);
      expect(bulkCommands('এইগুলো সব মুছে দাও', now)?.single.op, 'delete');
      expect(bulkCommands('এই গুলো সব মুছে দাও', now)?.single.selection.kind, SelKind.all);
      for (final w in ['এগুলো', 'এগুলা', 'এইগুলা', 'ওগুলো', 'ওইগুলো', 'এসব', 'এই কাজগুলো', 'সবগুলো', 'সবকটা', 'সবকয়টা']) {
        expect(bulkCommands('$w শেষ করেছি', now)?.single.selection.kind, SelKind.all, reason: w);
      }
      expect(bulkCommands('এক থেকে তিন নম্বর মুছো', now)?.single.selection.kind, SelKind.range);
      expect(bulkCommands('বাজার আর ওষুধের কাজটা শেষ', now)?.single.selection.names, hasLength(2));
    });
  });

  group('one selection contract for the rules and the AI', () {
    test('the AI\'s bulk item is the same typed selection; unknown kinds/ops and ids are not taken', () {
      final now = DateTime(2026, 10, 9, 15, 53);
      final rules = bulkCommands('প্রথম দুটো কাল রাখো', now)!.single;
      final ai = commandsFromAi('প্রথম দুটো কাল রাখো', {
        'reply': '',
        'items': [
          {'action': 'bulk', 'op': 'move', 'date': '2026-10-10', 'select': {'kind': 'first', 'n': 2}},
        ],
      }, const [], now: now).single as BulkAction;
      expect((ai.op, ai.selection.kind, ai.selection.n, ai.due), (rules.op, rules.selection.kind, rules.selection.n, rules.due));
      final bad = commandsFromAi('x', {
        'reply': '',
        'items': [
          {'action': 'bulk', 'op': 'wipe_everything', 'select': {'kind': 'all'}},
          {'action': 'bulk', 'op': 'delete', 'select': {'kind': 'ids', 'ids': ['a1']}},
          {'action': 'bulk', 'op': 'delete', 'confirmed': true, 'select': {'kind': 'first'}},
        ],
      }, const [], now: now);
      expect(bad.whereType<BulkAction>(), isEmpty);
    });

    testWidgets('an AI bulk delete still asks once, on the list shown', (t) async {
      rig = await start(t, ai: {
        'reply': 'সব মুছে দিয়েছি',
        'items': [
          {'action': 'bulk', 'op': 'delete', 'select': {'kind': 'all'}, 'confirmed': true},
        ],
      });
      rig.brain.data.tasks.addAll(seedTasks());
      chat = ChatController(rig.brain);
      await say('আজকের কাজের তালিকা দাও');
      final r = await say('উমম ওই যে দেখালা সেগুলারে উড়ায় দাও');
      expect(r, contains('মুছে দেব?'));
      expect(r, isNot(contains('সব মুছে দিয়েছি')));
      expect(ids(), hasLength(9));
    });
  });
}
