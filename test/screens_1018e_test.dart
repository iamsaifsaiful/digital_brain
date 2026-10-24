// The fifth set of 18 Oct screenshots (2.26.1-b36), replayed word for word.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:digital_brain/state/chat_archive.dart';
import 'package:flutter/material.dart';
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
    rig.nowAt = DateTime(2026, 10, 18, 16, 40);
    data().projects.add(Project(id: 'p1', name: 'বাড়ি মেরামত'));
    data().cash.add(CashEntry(id: 'i1', kind: CashKind.income, amount: 2500, category: 'বেতন', date: DateTime(2026, 10, 5)));
    chat = ChatController(rig.brain);
  }

  testWidgets('১. the home box has a button to the earlier conversations (once touched)', (t) async {
    await open(t);
    // The approved design keeps the bar quiet: the button shows when the box is touched.
    expect(find.byKey(const Key('home-past-chats')), findsNothing);
    await t.tap(find.byType(TextField).first);
    await settle(t);
    expect(find.byKey(const Key('home-past-chats')), findsOneWidget);
    // Typing in the box: the button gives way (the box shows ✕ instead).
    await t.enterText(find.byType(TextField).first, 'আজ');
    await settle(t);
    expect(find.byKey(const Key('home-past-chats')), findsNothing);
    await t.enterText(find.byType(TextField).first, '');
    await settle(t);
    await t.tap(find.byKey(const Key('home-past-chats')));
    await settle(t);
    expect(find.text('আগের কথা'), findsWidgets, reason: 'the list of earlier conversations is open');
  });

  testWidgets('২–৪. a numbered list keeps each date, says them back, and questions about it are answered', (t) async {
    await open(t);
    final r = await say('কাজের তালিকায় যুক্ত কর,\n\n১. ১২ তারিখে ঢাকায় যাবো\n২. ১৭ তারিখে সিংগাপুর যাবো\n৩. ২৫ তারিখে ঢাকায় ব্যাক করব');
    expect(r, contains('১২ নভেম্বর'));
    expect(r, contains('২৫ নভেম্বর'), reason: 'a list goes forward: 25 after 17 Nov is 25 Nov');
    final before = data().tasks.length;
    final q = await say('তারিখ সহ যুক্ত করেছো?');
    expect(q, contains('তারিখসহ'));
    expect(q, contains('১৭ নভেম্বর'));
    await say('কাজ গুলো তারিখ সহ যুক্ত করা দরকার ছিল');
    expect(data().tasks.length, before, reason: 'a remark is not a new to-do');
    expect(data().tasks.any((x) => x.done), isFalse);
  });

  testWidgets('৫–৬. "ডিসেম্বরের ৬ তারিখে" is 6 December; a date correction moves the to-do, ticks nothing', (t) async {
    await open(t);
    final r = await say('ডিসেম্বরের ৬ তারিখে যশোর যাবো');
    expect(r, contains('৬ ডিসেম্বর'));
    final task = data().tasks.single;
    expect(task.due, DateTime(2026, 12, 6));
    expect(task.span, TaskSpan.day);
    // The same correction when it had been kept for the month.
    await rig.brain.saveTask(task.copyWith(due: DateTime(2026, 12, 1), span: TaskSpan.month));
    await say('যেকোন দিন কেন রাখবা, বলেছি ৬ তারিখ। কাজের রিমাইন্ডার চাই নাই। তবে, সে তারিখে লেখো');
    final now = data().tasks.single;
    expect(now.due, DateTime(2026, 12, 6));
    expect(now.span, TaskSpan.day);
    expect(now.done, isFalse);
    expect(now.reminderId, isNull);
  });

  testWidgets('৭–৮. this year\'s and this month\'s to-dos; undated ones are mentioned', (t) async {
    await open(t);
    data().tasks.addAll([
      Task(id: 'a', title: 'চিঠি লেখা', createdAt: DateTime(2026, 10, 1)),
      Task(id: 'b', title: 'যশোর যাওয়া', due: DateTime(2026, 12, 6), createdAt: DateTime(2026, 10, 1)),
    ]);
    final y = await say('পুরো বছরে কাজের তালিকায় কি আছে');
    expect(y, contains('যশোর যাওয়া'));
    expect(y, isNot(contains('“বছরে”')));
    final m = await say('এই মাসে আমার কি কি কাজ আছে?');
    expect(m, contains('চিঠি লেখা'));
  });

  testWidgets('৯–১০. "প্রথম রিমাইন্ডার বাদ দাও" and "বর্তমানে রিমাইন্ডার গুলো কি কি"', (t) async {
    await open(t);
    data().reminders.addAll([
      Reminder(id: 'r1', title: 'মাঠে খেলবো', date: DateTime(2026, 10, 19), hour: 17),
      Reminder(id: 'r2', title: 'তুবার জন্মদিন', date: DateTime(2026, 10, 31), hour: 9),
    ]);
    final l = await say('বর্তমানে রিমাইন্ডার গুলো কি কি');
    expect(l, isNot(contains('এই নামে')));
    expect(l, contains('মাঠে খেলবো'));
    final q = await say('প্রথম রিমাইন্ডার বাদ দাও');
    expect(q, contains('মাঠে খেলবো'));
    await say('হ্যাঁ');
    expect(data().reminders.map((r) => r.id), ['r2']);
  });

  testWidgets('১১. "আয়ের হিসাব দাও" is the income', (t) async {
    await open(t);
    data().ledger.add(LedgerEntry(person: 'ইমরান', kind: LedgerKind.borrowed, amount: 15000, date: DateTime(2026, 10, 18)));
    final r = await say('আয়ের হিসাব দাও');
    expect(r, contains('২,৫০০'));
    expect(r, isNot(contains('পাবেন')));
  });

  testWidgets('১২–১৪. অন্যান্য হিসাব: which one is always asked; a waiting or kept expense goes into it', (t) async {
    await open(t);
    final q = await say('অন্যান্য হিসেবে যুক্ত কর, মিস্ত্রীর বিল ২৭০০ টাকা');
    expect(q, contains('কোনটায়'), reason: 'asked even with one account');
    await say('বাড়ি মেরামত');
    await say('হ্যাঁ');
    expect(data().cash.where((e) => e.amount == 2700 && e.linkId == null).single.projectId, 'p1');
    // Waiting for a yes, the account is named instead.
    await say('মিস্ত্রীর বিল ৫০০ টাকা');
    await say('এটা অন্যান্য হিসাবের মাঝে রাখো');
    expect(chat.wait, ChatWait.project);
    await say('বাড়ি মেরামত');
    await say('হ্যাঁ');
    expect(data().cash.where((e) => e.amount == 500 && e.linkId == null).single.projectId, 'p1');
    // Kept in the general আয়-ব্যয়, then moved by name.
    await say('বাজারে ২০০ টাকা খরচ');
    await say('হ্যাঁ');
    expect(data().cash.where((e) => e.amount == 200).single.projectId, isNull);
    final m = await say('ব্যয়ে লিখতে বলি নাই, অন্যান্য হিসাবের বাড়ির মেরামত এ লিখ');
    expect(m, contains('বাড়ি মেরামত'));
    expect(data().cash.where((e) => e.amount == 200 && e.linkId == null).single.projectId, 'p1');
    expect(data().cash.where((e) => e.amount == 200 && e.linkId == null), hasLength(1), reason: 'moved, not written twice');
  });

  test('১৫. a chat is titled by its first real message, not "হ্যাঁ"', () {
    expect(chatTitle([ChatMessage.user('হ্যাঁ'), ChatMessage.app('?'), ChatMessage.user('এই মাসে আমার কি কি কাজ আছে?')]), 'এই মাসে আমার কি কি কাজ আছে?');
  });
}
