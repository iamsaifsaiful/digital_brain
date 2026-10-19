// The 19 Oct morning screenshots (2.34.0-b81), replayed word for word.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/ui/widgets.dart';
import 'package:flutter/material.dart';

import 'app_test.dart' show Rig, start, settle, openTyping, sendTyped;

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
    rig.nowAt = DateTime(2026, 10, 19, 8, 10);
    chat = ChatController(rig.brain);
    rig.brain.data = AppData(
      ledger: [
        LedgerEntry(person: 'করিম', kind: LedgerKind.lent, amount: 33200, date: DateTime(2026, 10, 1)),
        LedgerEntry(person: 'রহিম', kind: LedgerKind.borrowed, amount: 4500, date: DateTime(2026, 10, 2)),
      ],
      contacts: [Contact(name: 'MSI REASON', phone: '+8801829550003')],
      projects: [Project(name: 'বাড়ি মেরামত')],
    );
  }

  testWidgets('"শিক্ষার্থীদের বেতনের হিসাব রাখো নাই?" → there is none; "…একটি হিসাব বিভাগ দরকার" → opens it', (t) async {
    await open(t);
    final a = await say('শিক্ষার্থীদের বেতনের হিসাব রাখো নাই?');
    expect(a, isNot(contains('পাবেন')));
    expect(a, contains('শিক্ষার্থীদের বেতন'));
    final b = await say('শিক্ষার্থীদের বেতনের জন্যে একটি হিসাব বিভাগ দরকার');
    expect(b, isNot(contains('পাবেন')));
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(data().projects.map((p) => p.name), contains('শিক্ষার্থীদের বেতন'));
  });

  testWidgets('"অন্যান্য হিসাবে তা খুলো" after asking for it opens it; "নির্দেশনা কি দিই, আর উত্তর কি দাও" is a complaint', (t) async {
    await open(t);
    await say('শিক্ষার্থীদের বেতনের হিসাব রাখো নাই?');
    final c = await say('নির্দেশনা কি দিই, আর উত্তর কি দাও');
    expect(c, isNot(contains('কোনো তথ্য নেই')));
    expect(c, contains('দুঃখিত'));
    final b = await say('অন্যান্য হিসাবে তা খুলো');
    expect(b, isNot(contains('পাবেন')));
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(data().projects.map((p) => p.name), contains('শিক্ষার্থীদের বেতন'));
  });

  testWidgets('money from abroad, the bazaar and a gift to the mosque are three entries', (t) async {
    await open(t);
    final a = await say('আজ বিদেশ থেকে রাজু ৫০০০ টাকা পাঠাইছে, ২০০০ টাকার বাজার করলাম, ১০০০ টাকা মসজিদে দান করলাম');
    expect(a, isNot(contains('বাজার, ৫,০০০')));
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    final cash = data().cash;
    expect(cash, hasLength(3), reason: a);
    expect(cash.where((e) => e.kind == CashKind.income).single.amount, 5000);
    expect(cash.firstWhere((e) => e.category == 'বাজার').amount, 2000);
    expect(cash.firstWhere((e) => e.category == 'দান-সদকা').amount, 1000);
    final d = await say('বাজার কি ৫০০০?');
    expect(d, contains('২,০০০'));
    expect(d, isNot(contains('MSI')));
  });

  testWidgets('"বাজার কি ৫০০০?" doubts the offer, never a phone number; "কি বলো?" is confusion', (t) async {
    await open(t);
    rig.brain.data.contacts.add(Contact(name: 'MSI REASON', phone: '+8801829550003'));
    final a = await say('বাজার কি ৫০০০?');
    expect(a, isNot(contains('MSI')));
    final b = await say('কি বলো?');
    expect(b, contains('দুঃখিত'));
  });

  testWidgets('"দ্বিতীয় টা বাদ দাও" after the reminder list; "৮নং টা বাদ দাও" after the task list', (t) async {
    await open(t);
    for (final (i, x) in ['অ্যালার্ম', 'হ্যা', 'বিশ্ব ভালোবাসা দিবস'].indexed) {
      rig.brain.data.reminders.add(Reminder(title: x, date: DateTime(2026, 10, 19), hour: 9 + i, minute: 0));
    }
    await say('আমার কোন রিমাইন্ডার আছে?');
    final a = await say('দ্বিতীয় টা বাদ দাও');
    expect(a, contains('হ্যা'));
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(data().reminders.map((r) => r.title), isNot(contains('হ্যা')));
    for (final x in ['রবিনের বোনের বিয়েতে দাওয়াত', 'ঢাকায় যাবো পার্টি পাবে', 'বাচ্চাকে স্কুলে নেওয়া', 'লাইব্রেরী থেকে বই কেনা', 'বাচ্চার জামা সেলাইতে যাওয়া', 'রেস্টুরেন্টে খেতে যাওয়া', 'ঘুমানো', 'পার্টি']) {
      rig.brain.data.tasks.add(Task(title: x, due: DateTime(2026, 10, 23)));
    }
    await say('আমার কাজের তালিকা দাও');
    final b = await say('৮নং টা বাদ দাও');
    expect(b, contains('পার্টি'));
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(data().tasks.map((t) => t.title), isNot(contains('পার্টি')));
  });

  testWidgets('"কাজের তালিকা থেকে পার্টি বাদ দাও": the one named exactly', (t) async {
    await open(t);
    for (final x in ['লাইব্রেরী থেকে বই কেনা', 'ঢাকায় যাবো পার্টি পাবে', 'পার্টি']) {
      rig.brain.data.tasks.add(Task(title: x));
    }
    final a = await say('কাজের তালিকা থেকে পার্টি বাদ দাও');
    expect(a, isNot(contains('লাইব্রেরী')));
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(data().tasks.map((t) => t.title), ['লাইব্রেরী থেকে বই কেনা', 'ঢাকায় যাবো পার্টি পাবে']);
  });

  testWidgets('"২০৪১ সালের মে মাসের কাজের তালিকা" keeps May; "মে মাসে যুক্ত কর" moves them; reminders for each at 11', (t) async {
    await open(t);
    final a = await say('২০৪১ সালের মে মাসের কাজের তালিকা\n\nঘুম থেকে উঠে স্কুলে যাবো\nবাজার করব\nচুল কাটবো\nভাত খাবো\nঘুমাবো');
    expect(a, contains('মে'));
    final ts = data().tasks;
    expect(ts, hasLength(5));
    expect(ts.every((t) => t.due != null && t.due!.year == 2041 && t.due!.month == 5 && t.span == TaskSpan.month), isTrue, reason: a);
    // As it was on the phone: the year only, then "মে মাসে যুক্ত কর".
    for (final x in ts.toList()) {
      await rig.brain.saveTask(x.copyWith(due: DateTime(2041), span: TaskSpan.year));
    }
    final b = await say('মে মাসে যুক্ত কর');
    expect(b, isNot(contains('বিভাগ')));
    expect(data().tasks.every((t) => t.due!.month == 5 && t.span == TaskSpan.month), isTrue, reason: b);
    final c = await say('২০৪১ সালের প্রতিটি কাজের রিমাইন্ডার দাও, সকাল ১১ টায়');
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(data().reminders, hasLength(5), reason: c);
    expect(data().reminders.every((r) => r.date.year == 2041 && r.hour == 11), isTrue);
  });

  testWidgets('typing in the chat keeps the newest message in view', (t) async {
    rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 19, 8, 10);
    await openTyping(t);
    for (var i = 1; i <= 12; i++) {
      await t.enterText(find.byType(TextField).last, 'নোট রাখো: পরীক্ষার লাইন $i');
      await sendTyped(t);
      await settle(t, 20);
    }
    final view = t.getRect(find.byType(Scaffold).last);
    // The last reply is on screen, above the typing box.
    final last = find.textContaining('পরীক্ষার লাইন 12');
    expect(last, findsWidgets);
    final r = t.getRect(last.last);
    expect(r.bottom <= view.bottom && r.top >= view.top, isTrue, reason: '$r in $view');
    // Tapping into the box again: still the newest in view.
    await t.tap(find.byType(TextField).last);
    // The keyboard opens: a third of the screen.
    t.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(t.view.resetViewInsets);
    await settle(t, 20);
    final shown = t.getRect(find.textContaining('পরীক্ষার লাইন 12').last);
    expect(shown.bottom <= view.bottom - 300, isTrue, reason: '$shown with the keyboard over the bottom 300');
  });

  testWidgets('inner tabs follow the finger: the page beside slides in and the tab\'s thumb moves with it', (t) async {
    rig = await start(t);
    final shell = t.state<HomeShellState>(find.byType(HomeShell));
    shell.go(ShellTab.diary);
    await settle(t, 20);
    Align thumb() => t.widget<Align>(find.descendant(of: find.byWidgetPredicate((w) => w is SegTabs), matching: find.byType(Align)).first);
    expect((thumb().alignment as Alignment).x, -1);
    final g = await t.startGesture(const Offset(300, 500));
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(-20, 0));
      await t.pump(const Duration(milliseconds: 16));
    }
    // Held a third of a page over: the thumb is on its way, not jumped.
    final x = (thumb().alignment as Alignment).x;
    expect(x, greaterThan(-1));
    expect(x, lessThan(0));
    await g.up();
    await settle(t, 30);
    expect((thumb().alignment as Alignment).x, anyOf(-1, 0));
    // A full swipe: the next tab, and its thumb there.
    await t.flingFrom(const Offset(300, 500), const Offset(-300, 0), 1500);
    await settle(t, 30);
    expect((thumb().alignment as Alignment).x, 0);
    expect(shell.tabNow, ShellTab.diary);
  });
}
