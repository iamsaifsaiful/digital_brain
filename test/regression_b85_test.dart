// 2.37.1-b85 regression (19 Oct 14:39 screenshots): a list asked for became
// a to-do called "হ্যাঁ", and "কাজের তালিকা চাচ্ছি" started collecting, after
// which every question and complaint was taken as a to-do. Replayed word for
// word on one session (the state between turns is the point), clock
// 19 Oct 2026 11:00, with the stored data compared after every turn.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, start;

const t1 = 'রবিনের বোনের বিয়েতে দাওয়াত';

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

  // ───────── 02–23 (24–30: the same checks live in master100_test.dart) ─────────
  Future<void> readOnly(String s) async {
    final before = snapshot();
    final r = await say(s);
    expect(snapshot(), before, reason: '"$s" changed the store — $r');
    expect(chat.collecting, isFalse, reason: '"$s" started collecting');
    expect(r, contains(t1), reason: '"$s" did not show the list');
  }

  testWidgets('02 idle: "কাজের তালিকা দাও" reads', (t) async {
    await open(t, seven());
    await readOnly('কাজের তালিকা দাও');
  });

  testWidgets('03 idle: "কাজের তালিকা চাচ্ছি" reads, never starts dictation', (t) async {
    await open(t, seven());
    await readOnly('কাজের তালিকা চাচ্ছি');
  });

  testWidgets('04 idle: "তালিকাটা দেখতে চাই" reads', (t) async {
    await open(t, seven());
    await readOnly('তালিকাটা দেখতে চাই');
  });

  testWidgets('05 a removal agreed, then two queries: fresh list, no to-do from the "হ্যাঁ"', (t) async {
    await open(t, seven());
    await say('আমার কাজের তালিকা দাও');
    await say('৭নং বাদ দাও');
    await say('হ্যাঁ');
    expect(data().tasks, hasLength(6));
    await readOnly('কাজের তালিকা দাও');
    await readOnly('কাজের তালিকা দাও');
    expect(data().tasks.where((x) => x.title.contains('হ্যাঁ')), isEmpty);
  });

  testWidgets('06 a bare "হ্যাঁ" with nothing waiting writes nothing', (t) async {
    await open(t, seven());
    final before = snapshot();
    await say('হ্যাঁ');
    expect(snapshot(), before);
  });

  testWidgets('07 "হ্যাঁ নামে একটা কাজ রাখো" — a title said as a title is kept', (t) async {
    await open(t, seven());
    await say('হ্যাঁ নামে একটা কাজ রাখো');
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(data().tasks.where((x) => x.title == 'হ্যাঁ'), hasLength(1));
  });

  testWidgets('08 "কাজের তালিকায় বাজার করা যোগ করো" adds "বাজার করা"', (t) async {
    await open(t, seven());
    await say('কাজের তালিকায় বাজার করা যোগ করো');
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(data().tasks.where((x) => x.title == 'বাজার করা'), hasLength(1));
    expect(data().tasks, hasLength(8));
  });

  testWidgets('09 "কাজের তালিকায় কী আছে" reads', (t) async {
    await open(t, seven());
    await readOnly('কাজের তালিকায় কী আছে');
  });

  testWidgets('10 "নতুন কাজ একটা একটা করে লিখে নাও" starts dictation, and says how to stop', (t) async {
    await open(t, seven());
    final r = await say('নতুন কাজ একটা একটা করে লিখে নাও');
    expect(chat.collecting, isTrue);
    expect(r, contains('শেষ'));
    expect(r, contains('বাতিল'));
  });

  testWidgets('11 dictating "বাজার করব" then "শেষ" → kept once; then idle', (t) async {
    await open(t, seven());
    await say('নতুন কাজ একটা একটা করে লিখে নাও');
    await say('বাজার করব');
    await say('শেষ');
    await say('হ্যাঁ');
    await say('হ্যাঁ');
    expect(data().tasks, hasLength(8));
    expect(chat.collecting, isFalse);
    expect(chat.wait, ChatWait.none);
  });

  testWidgets('12 dictating, "কাজের তালিকা দাও" → the list; not a line of the draft', (t) async {
    await open(t, seven());
    await say('নতুন কাজ একটা একটা করে লিখে নাও');
    await say('বাজার করব');
    await readOnly('কাজের তালিকা দাও');
    await say('শেষ');
    expect(data().tasks, hasLength(7), reason: '"শেষ" after the pause keeps nothing by itself');
  });

  for (final s in const ['কি করতেছো?', 'তুমি ভুল বুঝেছো', 'কি?']) {
    testWidgets('13/14 dictating, "$s" → explained, dictation paused, not a line', (t) async {
      await open(t, seven());
      await say('নতুন কাজ একটা একটা করে লিখে নাও');
      await say('বাজার করব');
      final before = snapshot();
      await say(s);
      expect(snapshot(), before);
      expect(chat.collecting, isFalse);
      // The line said before is still there, unsaved — kept on asking.
      await say('ওগুলো রাখো');
      await say('হ্যাঁ');
      expect(data().tasks.where((x) => x.title.contains('বাজার')), hasLength(1));
      expect(data().tasks.where((x) => x.title.contains(s.replaceAll('?', ''))), isEmpty);
    });
  }

  testWidgets('15 dictating → "বাতিল" drops only the unsaved lines', (t) async {
    await open(t, seven());
    await say('নতুন কাজ একটা একটা করে লিখে নাও');
    await say('বাজার করব');
    await say('বাতিল');
    expect(data().tasks, hasLength(7));
    expect(chat.collecting, isFalse);
  });

  testWidgets('16 dictating → a question → "লেখা চালাও" → one more → "শেষ": both, once', (t) async {
    await open(t, seven());
    await say('নতুন কাজ একটা একটা করে লিখে নাও');
    await say('বাজার করব');
    await say('কাজের তালিকা দাও');
    await say('লেখা চালাও');
    expect(chat.collecting, isTrue);
    await say('ব্যাংকে যাব');
    await say('শেষ');
    await say('হ্যাঁ');
    expect(data().tasks, hasLength(9), reason: '${data().tasks.map((x) => x.title)}');
  });

  testWidgets('17 dictating, then the app restarts: nothing is captured by a ghost dictation', (t) async {
    await open(t, seven());
    await say('নতুন কাজ একটা একটা করে লিখে নাও');
    await say('বাজার করব');
    chat = ChatController(rig.brain);
    expect(chat.collecting, isFalse);
    await readOnly('কাজের তালিকা দাও');
  });

  testWidgets('18 a whole list in one breath is kept, and dictation is not left on', (t) async {
    await open(t, seven());
    await say('কাল স্কুলে যাব, বাজার করব, ব্যাংকে যাব');
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(data().tasks, hasLength(10));
    expect(chat.collecting, isFalse);
  });

  testWidgets('19 a removal waiting, then "কাজের তালিকা দাও": never a yes; a later "হ্যাঁ" removes nothing', (t) async {
    await open(t, seven());
    await say('আমার কাজের তালিকা দাও');
    await say('১নং ছাড়া বাকি সব গুলো বাদ দাও');
    expect(chat.wait, ChatWait.bulk);
    final r = await say('কাজের তালিকা দাও');
    expect(data().tasks, hasLength(7), reason: r);
    expect(r, contains('কিছু মোছা হয়নি'));
    await say('হ্যাঁ');
    expect(data().tasks, hasLength(7));
  });

  testWidgets('20 "হ্যাঁ" twice: one removal, no to-do', (t) async {
    await open(t, seven());
    await say('আমার কাজের তালিকা দাও');
    await say('৭নং বাদ দাও');
    await say('হ্যাঁ');
    await say('হ্যাঁ');
    expect(data().tasks.map((x) => x.id), ['T1', 'T2', 'T3', 'T4', 'T5', 'T6']);
  });

  testWidgets('22 the AI (late or wrong) proposing a to-do for "কাজের তালিকা দাও": nothing written', (t) async {
    await open(t, seven());
    rig.ai.key = 'k';
    rig.ai.answer = {'reply': 'জি', 'items': [{'action': 'task_add', 'text': 'হ্যাঁ'}]};
    await readOnly('কাজের তালিকা দাও');
  });

  testWidgets('23 "আজকের কাজ দাও" then "সব কাজের তালিকা দাও": the second is all of them, no filter carried over', (t) async {
    await open(t, [...seven(), Task(id: 'A', title: 'চুল কাটা', due: DateTime(2026, 10, 19))]);
    await say('আজকের কাজ দাও');
    final r = await say('সব কাজের তালিকা দাও');
    expect(r, contains('৮টা'));
  });

  // ───────── the same questions × the state they come in ─────────
  const phrases = ['তালিকা দাও', 'আমার কাজগুলো দেখাও', 'কাজের তালিকা চাই', 'কাজের তালিকা চাচ্ছি', 'কাজের তালিকা দেখতে চাই', 'কী কী বাকি?', 'amar kajer list dao'];
  final states = <String, Future<void> Function()>{
    'idle': () async {},
    'just removed': () async {
      await say('আমার কাজের তালিকা দাও');
      await say('৭নং বাদ দাও');
      await say('হ্যাঁ');
    },
    'removal waiting': () async {
      await say('আমার কাজের তালিকা দাও');
      await say('৭নং বাদ দাও');
    },
    'dictating': () async {
      await say('নতুন কাজ একটা একটা করে লিখে নাও');
      await say('বাজার করব');
    },
    'just cancelled': () async {
      await say('নতুন কাজ একটা একটা করে লিখে নাও');
      await say('বাতিল');
    },
    'a time asked': () async {
      await say('রেস্টুরেন্টে খেতে যাওয়ার রিমাইন্ডার দাও');
    },
  };
  for (final st in states.entries) {
    for (final ph in phrases) {
      testWidgets('P [${st.key}] "$ph" reads the list, writes nothing', (t) async {
        await open(t, seven());
        await st.value();
        await readOnly(ph);
        expect(data().tasks.where((x) => x.title.contains('হ্যাঁ') || x.title.contains('বাজার')), isEmpty);
      });
    }
  }
}
