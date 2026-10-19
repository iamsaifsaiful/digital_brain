// 19 Oct 16:30 screenshots (2.37.2-b86), replayed word for word, clock
// 19 Oct 2026 16:30. Each checks the stored data, not only the reply.
import 'package:digital_brain/models/extras.dart';
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
  print('» ${s.replaceAll('\n', ' / ')}\n  ${r.replaceAll('\n', ' / ')}  [${chat.wait.name}]');
  return r;
}

Future<void> open(WidgetTester t, [AppData? d]) async {
  rig = await start(t);
  rig.nowAt = DateTime(2026, 10, 19, 16, 30);
  if (d != null) rig.brain.data = d;
  chat = ChatController(rig.brain);
}

void main() {
  testWidgets('M1 "আজকের বাজারের হিসাব রাখো-" with numbered lines → five expenses, no "কার সাথে লেনদেন?"', (t) async {
    await open(t);
    final r = await say('আজকের বাজারের হিসাব রাখো-\n\n১. মুদি মালামাল ৭৫০ টাকা\n২. আপেল ১ কেজি ৩০০ টাকা\n৩. পেয়ারা ২ কেজি ২০০ টাকা\n৪. মাছ ৩ কেজি ৭৫০ টাকা\n৫. মুরগি ৪ কেজি ১২০০ টাকা');
    expect(r, isNot(contains('লেনদেন')));
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(chat.wait, ChatWait.none, reason: 'no question per item');
    final spent = data().cash.where((c) => c.kind == CashKind.expense).toList();
    expect([for (final c in spent) c.amount], [750, 300, 200, 750, 1200]);
    expect(spent.every((c) => c.category == 'বাজার'), isTrue, reason: '${spent.map((c) => c.category)}');
    expect(data().ledger, isEmpty);
  });

  testWidgets('M2 "আমার শিক্ষার্থীদের বেতন বকেয়া" with names → dues (they owe), never income', (t) async {
    await open(t, AppData(projects: [Project(id: 'S', name: 'শিক্ষার্থীদের বেতন')]));
    final r = await say('আমার শিক্ষার্থীদের বেতন বকেয়া\n\n১. ফয়সাল - ১০০০ টাকা\n২. আজিম- ১০০০ টাকা\n৩. আবির - ১০০০ টাকা\n৪. নিহান - ২০০০ টাকা');
    expect(r, isNot(contains('আয়')));
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(data().cash, isEmpty, reason: 'a due is not money in');
    int owes(String p) => data().ledger.where((e) => e.person == p).fold(0, (s, e) => s + e.kind.signed(e.amount));
    expect((owes('ফয়সাল'), owes('আজিম'), owes('আবির'), owes('নিহান')), (1000, 1000, 1000, 2000));
    // Asked about that account: the dues are in its answer.
    final b = await say('শিক্ষার্থীদের বেতনের হিসাব দেখাও');
    expect(b, contains('বকেয়া'));
    expect(b, contains('৫,০০০'));
  });

  testWidgets('M3 the dues read as income, "এটা আয় না। এটা বকেয়া হিসাব" → the same items as dues, not dropped', (t) async {
    await open(t, AppData(projects: [Project(id: 'S', name: 'শিক্ষার্থীদের বেতন')]));
    await say('মাহি ২০০০ টাকা, আব্দুর রহমান ১০০০ টাকা দিছে');
    expect(chat.wait, ChatWait.yesNo);
    final r = await say('এটা আয় না। এটা বকেয়া হিসাব');
    expect(r, isNot(contains('রাখলাম না')));
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(data().cash, isEmpty);
    int owes(String p) => data().ledger.where((e) => e.person == p).fold(0, (s, e) => s + e.kind.signed(e.amount));
    expect((owes('মাহি'), owes('আব্দুর রহমান')), (2000, 1000));
  });

  testWidgets('M4 "বকেয়া হিসেবে এই গুলো রাখো" never opens a note category', (t) async {
    await open(t);
    final r = await say('বকেয়া হিসেবে এই গুলো রাখো');
    expect(r, isNot(contains('নতুন বিভাগ')));
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(data().notes, isEmpty);
  });

  testWidgets('M5 an anniversary on 15 Nov, "এটা ভুল। বিবাহবার্ষিকী ১৫ ফেব্রুয়ারী" → the same one moved; no search, no second one', (t) async {
    await open(t, AppData(
      specialDays: [SpecialDay(id: 'a', person: 'আমার', kind: SpecialKind.anniversary, month: 11, day: 15)],
      contacts: [Contact(name: 'Net Bill', phone: '+8801714203262')],
    ));
    await say('আমার বিবাহবার্ষিকীর রিমাইন্ডার কবে?');
    final r = await say('এটা ভুল। বিবাহবার্ষিকী ১৫ ফেব্রুয়ারী');
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(r, isNot(contains('Net Bill')));
    expect(data().specialDays, hasLength(1));
    expect((data().specialDays.single.id, data().specialDays.single.month, data().specialDays.single.day), ('a', 2, 15));
  });

  testWidgets('M6 two anniversaries (old 15 Nov, new 15 Feb): "তাইলে ১৫ নভেম্বর কেন বলো?" never moves the right one to November', (t) async {
    await open(t, AppData(specialDays: [
      SpecialDay(id: 'old', person: 'আমার', kind: SpecialKind.anniversary, month: 11, day: 15),
      SpecialDay(id: 'new', person: 'আমাদের', kind: SpecialKind.anniversary, month: 2, day: 15),
    ]));
    await say('আমার বিবাহবার্ষিকীর রিমাইন্ডার কবে?');
    await say('মাত্র যে বললাম ১৫ ফেব্রুয়ারী?');
    final r = await say('তাইলে ১৫ নভেম্বর কেন বলো?');
    final n = data().specialDays.firstWhere((x) => x.id == 'new');
    expect((n.month, n.day), (2, 15), reason: r);
    // The old wrong one is offered to be removed (asked, not done unasked).
    expect(r, contains('নভেম্বর'));
    if (chat.wait != ChatWait.none) await say('হ্যাঁ');
    expect(data().specialDays.map((x) => x.id), ['new']);
  });

  testWidgets('M7 "১ মে এর কাজের রিমাইন্ডার দরকার" → the to-do on 1 May 2029, not a new "কাজের দরকার" in 2027', (t) async {
    await open(t);
    await say('২০২৯ সালের কাজের তালিকা\n\n১. জানুয়ারি ৫ তারিখে নোয়াখালী যাওয়া\n২. ফেব্রুয়ারীর ১৫ তারিখে যশোর যাওয়া\n৩. মার্চ ২৫ তারিখে স্বাধীনতা দিবসে যাওয়া\n৪. এপ্রিলের ১৪ তারিখে পহেলা বৈশাখের অনুষ্ঠানে যাওয়া\n৫. মে মাসের ১ তারিখে মে দিবস পালন করা');
    final may = data().tasks.firstWhere((x) => x.due == DateTime(2029, 5, 1));
    expect(may.title, contains('মে দিবস'), reason: 'the title keeps "মে দিবস"');
    final r = await say('১ মে এর কাজের রিমাইন্ডার দরকার');
    expect(r, isNot(contains('কাজের দরকার')));
    if (chat.wait != ChatWait.none) await say('সকাল ৯টায়');
    final t1 = data().tasks.firstWhere((x) => x.id == may.id);
    expect(t1.reminderId, isNotNull);
    final rem = data().reminders.firstWhere((x) => x.id == t1.reminderId);
    expect((rem.date, rem.hour), (DateTime(2029, 5, 1), 9));
    expect(data().reminders, hasLength(1));
  });

  testWidgets('M8 a to-do just talked about, "এখানে রিমাইন্ডার যুক্ত কর" → its reminder (the time asked)', (t) async {
    await open(t, AppData(tasks: [Task(id: 'm', title: 'মে দিবস পালন করা', due: DateTime(2029, 5, 1))]));
    await say('মে দিবস পালন করা কাজটা দেখাও');
    final r = await say('এখানে রিমাইন্ডার যুক্ত কর');
    expect(r, isNot(contains('পেলাম না')));
    if (chat.wait != ChatWait.none) await say('সকাল ৯টায়');
    final rem = data().reminders.single;
    expect((rem.date, rem.hour), (DateTime(2029, 5, 1), 9));
    expect(data().tasks.single.reminderId, rem.id);
  });

  testWidgets('M9 "এই হিসাব গুলোর বিস্তারিত দাও আমাকে" after the totals → per person', (t) async {
    await open(t, AppData(ledger: [
      LedgerEntry(person: 'করিম', kind: LedgerKind.lent, amount: 33200, date: DateTime(2026, 10, 1)),
      LedgerEntry(person: 'রহিম', kind: LedgerKind.borrowed, amount: 4500, date: DateTime(2026, 10, 2)),
    ]));
    await say('আমার মোট পাওনা কত?');
    final r = await say('এই হিসাব গুলোর বিস্তারিত দাও আমাকে');
    expect(r, contains('করিম'));
    expect(r, contains('রহিম'));
  });
}
