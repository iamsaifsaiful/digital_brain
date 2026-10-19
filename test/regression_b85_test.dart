// 2.37.1-b85 regression (19 Oct 14:39 screenshots): a list asked for became
// a to-do called "হ্যাঁ", and "কাজের তালিকা চাচ্ছি" started collecting, after
// which every question and complaint was taken as a to-do. Replayed word for
// word on one session (the state between turns is the point), clock
// 19 Oct 2026 11:00, with the stored data compared after every turn.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, start;

late Rig rig;
late ChatController chat;
AppData data() => rig.brain.data;

Future<String> say(String s) async {
  final n = chat.messages.length;
  await chat.hear(s);
  final r = chat.messages.skip(n).where((m) => !m.fromUser).map((m) => [m.text, ...m.facts].join(' | ')).join(' ‖ ');
  // ignore: avoid_print
  print('» $s\n  ${r.replaceAll('\n', ' / ')}  [${chat.wait.name}${chat.collecting ? ' collecting' : ''}]');
  return r;
}

Future<void> open(WidgetTester t, [List<Task>? tasks]) async {
  rig = await start(t);
  rig.nowAt = DateTime(2026, 10, 19, 11);
  if (tasks != null) rig.brain.data = AppData(tasks: tasks);
  chat = ChatController(rig.brain);
}

/// The seven to-dos on the 14:39 screen, ids T1–T7.
List<Task> seven() => [
      Task(id: 'T1', title: 'রবিনের বোনের বিয়েতে দাওয়াত', due: DateTime(2026, 10, 24), createdAt: DateTime(2026, 10, 1, 8, 1)),
      Task(id: 'T2', title: 'লাইব্রেরী থেকে বই কেনা', due: DateTime(2027, 1, 1), createdAt: DateTime(2026, 10, 1, 8, 2)),
      Task(id: 'T3', title: 'রেস্টুরেন্টে খেতে যাওয়া', due: DateTime(2027, 1, 1), createdAt: DateTime(2026, 10, 1, 8, 3)),
      Task(id: 'T4', title: 'মেঘনা ঘাট যাওয়া', due: DateTime(2027, 6, 5), createdAt: DateTime(2026, 10, 1, 8, 4)),
      Task(id: 'T5', title: 'ঢাকায় যাওয়া', due: DateTime(2027, 6, 6), createdAt: DateTime(2026, 10, 1, 8, 5)),
      Task(id: 'T6', title: 'দাওয়াত', due: DateTime(2027, 6, 10), createdAt: DateTime(2026, 10, 1, 8, 6)),
      Task(id: 'T7', title: 'নোয়াখালী যাওয়া', due: DateTime(2027, 6, 15), createdAt: DateTime(2026, 10, 1, 8, 7)),
    ];

/// Everything stored that a query must never change.
String snapshot() => [
      for (final x in data().tasks) '${x.id}|${x.title}|${x.due}|${x.done}|${x.reminderId}',
      for (final r in data().reminders) 'R:${r.id}|${r.title}|${r.date}|${r.enabled}',
      'notes:${data().notes.length}', 'cash:${data().cash.length}', 'ledger:${data().ledger.length}',
    ].join('\n');

void main() {
  testWidgets('01 the 12 turns of the 14:39 screenshots: only the six agreed are removed; nothing else is ever written', (t) async {
    await open(t, seven());
    final a = await say('আমার কাজের তালিকা দাও');
    expect(a, contains('৭টা'));
    await say('১নং ছাড়া বাকি সব গুলো বাদ দাও');
    expect(chat.wait, ChatWait.bulk);
    await say('হ্যাঁ');
    expect(data().tasks.map((x) => x.id), ['T1']);
    final after = snapshot();
    // Every turn from here on reads or answers — the store stays as it is.
    for (final s in const [
      'কাজের তালিকা দাও',
      'কাজের তালিকা দাও',
      'তোমাকে কি প্রশ্ন করি',
      'কাজের তালিকা চাচ্ছি',
      'আমার কাজের তালিকা দাও',
      'কি?',
      'কি করতেছো?',
      'আগে তো আরো উন্নত ভাবে কাজ করতে',
      'এটা হলো কিছু?',
      'এমন মডিফাই করলা, এখন কথাই বুঝে না',
    ]) {
      final r = await say(s);
      expect(snapshot(), after, reason: '"$s" changed the store — reply: $r');
      expect(chat.collecting, isFalse, reason: '"$s" left collecting on');
      expect(r, isNot(contains('“হ্যাঁ”')), reason: s);
      if (s.contains('তালিকা')) expect(r, contains('রবিনের বোনের বিয়েতে দাওয়াত'), reason: '"$s" must show the list');
      if (s == 'তোমাকে কি প্রশ্ন করি') expect(r, isNot(contains('কোনো তথ্য নেই')), reason: 'help, not the generic no-data reply');
    }
    expect(data().tasks.single.id, 'T1');
    expect(data().tasks.where((x) => x.title.contains('হ্যাঁ')), isEmpty);
  });
}
