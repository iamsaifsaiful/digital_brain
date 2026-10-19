// 19 Oct 11:03 screenshots (2.36.0-b83), N01–N06 of the master brief,
// replayed word for word with the clock at 19 Oct 2026, 11:00.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, start;

void main() {
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

  Future<void> open(WidgetTester t) async {
    rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 19, 11);
    chat = ChatController(rig.brain);
  }

  const june = '২০২৯ সালের জুন মাসের কাজের তালিকা\n\n৫ জুন, মেঘনা ঘাট যাবো\n৬ জুন, ঢাকায় যাবো\n১০ জুন, দাওয়াত আছে\n১৫ জুন, নোয়াখালী যাবো';

  testWidgets('N01 "২০২৯ সালের জুন মাসের কাজের তালিকা": every one in June 2029', (t) async {
    await open(t);
    final r = await say(june);
    expect(data().tasks, hasLength(4));
    expect(data().tasks.every((x) => x.due!.year == 2029 && x.due!.month == 6), isTrue, reason: r);
    expect(r, contains('২০২৯'));
  });

  testWidgets('N02 by name like by number: "নোয়াখালী যাওয়া কাজের রিমাইন্ডার দাও" → "সকাল ১০ টায়" is 15 Jun 2029 10:00 on that to-do', (t) async {
    await open(t);
    await say(june);
    final a = await say('নোয়াখালী যাওয়া কাজের রিমাইন্ডার দাও');
    expect(a, isNot(contains('“নোয়াখালী যাওয়া কাজের”')));
    await say('সকাল ১০ টায়');
    final task = data().tasks.firstWhere((x) => x.title.contains('নোয়াখালী'));
    final r = data().reminders.single;
    expect(task.reminderId, r.id);
    expect((r.date, r.hour), (DateTime(2029, 6, 15), 10));
    expect(r.title, isNot(contains('কাজের')));
  });

  testWidgets('N03 "কাল না। ১৫ জুনে" right after a reminder: its day fixed, no new to-do', (t) async {
    await open(t);
    await say(june);
    // As on the phone: a standalone reminder that landed on tomorrow.
    await say('নোয়াখালী যাওয়ার রিমাইন্ডার দাও কাল সকাল ১০টায়');
    final before = data().tasks.length;
    final r = await say('কাল না। ১৫ জুনে');
    expect(data().tasks, hasLength(before), reason: r);
    final rem = data().reminders.last;
    expect(rem.date.month, 6);
    expect(rem.date.day, 15);
    expect(rem.hour, 10);
    // No year said: the year of the to-do of that name on that day.
    expect(rem.date.year, 2029);
    expect(r, isNot(contains('কোন কোন কাজ')));
  });

  testWidgets('N04 "৮নং বাদ দাও এবং ৭নং এ রিমাইন্ডার দাও": both parts, 7 is the original 7th', (t) async {
    await open(t);
    await say(june);
    for (final (i, x) in ['রবিনের বোনের বিয়েতে দাওয়াত', 'লাইব্রেরী থেকে বই কেনা', 'রেস্টুরেন্টে খেতে যাওয়া'].indexed) {
      data().tasks.add(Task(title: x, due: i == 0 ? DateTime(2026, 10, 24) : DateTime(2027, 1, 1)));
    }
    data().tasks.add(Task(id: 'extra', title: 'কাল নোয়াখালী যাওয়া', due: DateTime(2029, 6, 15)));
    await say('আমার সব কাজের তালিকা দাও');
    final a = await say('৮নং বাদ দাও এবং ৭নং এ রিমাইন্ডার দাও');
    if (chat.wait == ChatWait.bulk) await say('হ্যাঁ');
    final b = chat.wait == ChatWait.none ? '' : await say('দুপুর ২টায়');
    if (chat.wait == ChatWait.bulk) await say('হ্যাঁ');
    expect(data().tasks.any((x) => x.id == 'extra'), isFalse, reason: a);
    final noa = data().tasks.firstWhere((x) => x.title == 'নোয়াখালী যাওয়া');
    expect(noa.reminderId, isNotNull, reason: '$a / $b');
    final r = data().reminders.firstWhere((x) => x.id == noa.reminderId);
    expect((r.date, r.hour), (DateTime(2029, 6, 15), 14));
  });

  testWidgets('N05 "সব রিমাইন্ডার দাও" / "কি কি রিমাইন্ডার দাও" show them; nothing named "সব"', (t) async {
    await open(t);
    data().reminders.addAll([Reminder(title: 'মিটিং', date: DateTime(2026, 10, 20), hour: 9), Reminder(title: 'ওষুধ', date: DateTime(2026, 10, 21), hour: 21)]);
    final a = await say('সব রিমাইন্ডার দাও');
    expect(a, contains('মিটিং'));
    expect(chat.wait, ChatWait.none);
    final b = await say('কি কি রিমাইন্ডার দাও');
    expect(b, contains('ওষুধ'));
    expect(data().reminders, hasLength(2));
  });

  testWidgets('N06 a list cut at ten says so; "আজকের সব রিমাইন্ডার বাদ দাও" takes today\'s from all, not the ten shown', (t) async {
    await open(t);
    for (var i = 0; i < 15; i++) {
      data().reminders.add(Reminder(id: 'r$i', title: 'রিমাইন্ডার $i', date: DateTime(2026, 10, i < 5 ? 19 : 25), hour: 12 + (i % 5)));
    }
    final a = await say('রিমাইন্ডার গুলো দাও');
    expect(a, contains('১৫'));
    expect(a, contains('১০'));
    final b = await say('আজকের সব রিমাইন্ডার বাদ দাও');
    expect(b, contains('৫'));
    await say('হ্যাঁ');
    expect(data().reminders, hasLength(10));
    expect(data().reminders.every((x) => x.date == DateTime(2026, 10, 25)), isTrue);
  });
}
