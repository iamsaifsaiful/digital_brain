// AI review, 20 Nov (plugin 1.0.12): the phone's model was right, the app
// was not — "…এটা তুমি এড করে দাও" moved an old to-do sharing a word, and
// "১৫০ টাকা লিখে রাখো" asked for a name first.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;

void main() {
  testWidgets('"কাল সকাল দশটায় করিম পড়ানো আছে এটা তুমি এড করে দাও": a new reminder, the old to-do left alone', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 15, 8);
    final old = Task(title: 'রাহিমকে পড়ানো', due: DateTime(2026, 11, 15));
    rig.brain.data.tasks.add(old);
    final chat = ChatController(rig.brain);
    await chat.hear('কাল সকাল দশটায় করিম পড়ানো আছে এটা তুমি এড করে দাও');
    expect(rig.brain.data.tasks.single.due, DateTime(2026, 11, 15), reason: 'not moved');
    final r = rig.brain.data.reminders.single;
    expect(r.title, contains('করিম পড়ানো'));
    expect(r.date, DateTime(2026, 11, 16));
    expect(r.notifyAt(rig.brain.services.now()), DateTime(2026, 11, 16, 10));
  });

  testWidgets('"১৫০ টাকা লিখে রাখো": spent, earned or with someone is asked; "আয়" keeps an income', (t) async {
    final rig = await start(t);
    final chat = ChatController(rig.brain);
    await chat.hear('১৫০ টাকা লিখে রাখো');
    expect(chat.messages.last.text, contains('খরচ, আয়, নাকি কারও সাথে লেনদেন'));
    await chat.hear('আয়');
    await chat.hear('হ্যাঁ');
    final c = rig.brain.data.cash.single;
    expect(c.kind, CashKind.income);
    expect(c.amount, 150);
    await chat.hear('৩০০ টাকা লিখে রাখো');
    await chat.hear('খরচ');
    await chat.hear('হ্যাঁ');
    expect(rig.brain.data.cash.where((e) => e.kind == CashKind.expense).single.amount, 300);
    // With a person or a direction it is still a loan, as before.
    await chat.hear('রহিমকে ৫০০ টাকা দিলাম লিখে রাখো');
    expect(chat.messages.last.text, isNot(contains('খরচ, আয়, নাকি')));
  });
}
