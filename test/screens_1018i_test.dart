// The ninth set of 18 Oct screenshots (2.32.0-b44), replayed word for word.
import 'package:digital_brain/logic/weather.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/weather.dart';
import 'package:digital_brain/state/chat.dart';
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
    rig.nowAt = DateTime(2026, 10, 18, 22, 30);
    chat = ChatController(rig.brain);
  }

  testWidgets('a reminder for a to-do by its name is on the to-do\'s day; "না, জানুয়ারির ১ তারিখে" moves it', (t) async {
    await open(t);
    await say('২০২৭ সালের জানুয়ারি মাসের ১ তারিখের কাজ গুলো, বাচ্চাকে স্কুলে নিতে হবে, লাইব্রেরী থেকে বই কিনবো, বাচ্চার জামা সেলাইতে যেতে হবে, রেস্টুরেন্টে খেতে যাবো');
    expect(data().tasks, hasLength(4));
    await say('রেস্টুরেন্টে খেতে যাওয়ার রিমাইন্ডার দাও, রাত ৮টায়');
    if (chat.wait == ChatWait.yesNo) await say('হ্যাঁ');
    final r = data().reminders.single;
    expect((r.date.year, r.date.month, r.date.day, r.hour), (2027, 1, 1, 20));
  });

  testWidgets('"না, জানুয়ারির ১ তারিখে" right after a reminder moves its day', (t) async {
    await open(t);
    await say('রেস্টুরেন্টে খেতে যাওয়ার রিমাইন্ডার দাও, রাত ৮টায়');
    if (chat.wait == ChatWait.yesNo) await say('হ্যাঁ');
    final m = await say('না, জানুয়ারির ১ তারিখে');
    expect(m, isNot(contains('বিভাগ')));
    final r = data().reminders.single;
    expect((r.date.month, r.date.day, r.hour), (1, 1, 20));
  });

  testWidgets('a daily alarm says its time; "হ্যা, সকাল ৯টায়" is that one, not a new reminder', (t) async {
    await open(t);
    final a = await say('প্রতিদিন সকাল ৯টায় এলার্ম দাও');
    expect(a, contains('৯টা'));
    final b = await say('হ্যা, সকাল ৯টায়');
    expect(data().reminders, hasLength(1), reason: b);
  });

  testWidgets('students paid, one verb for all, into their account; "আব্দুর রহমান" is one name', (t) async {
    await open(t);
    data().projects.add(Project(id: 'p1', name: 'শিক্ষার্থীদের বেতন'));
    final r = await say('আমার শিক্ষার্থীদের মাঝে, মাহি ২০০০ টাকা দিছে, আখি ৫০০ টাকা, ফয়সাল ১০০০ টাকা। আব্দুর রহমানের কাছে ৩০০০ টাকা বেতন বাবদ পাবো');
    expect(r, contains('৪টা'));
    for (final n in ['মাহি', 'আখি', 'ফয়সাল', 'আব্দুর রহমান']) {
      expect(r, contains(n));
    }
    expect(r, contains('শিক্ষার্থীদের বেতন'));
    await say('হ্যাঁ');
    expect(data().cash.where((e) => e.projectId == 'p1').map((e) => e.amount), unorderedEquals([2000, 500, 1000]));
  });

  testWidgets('"না" to a list, then "অন্যান্য হিসাবে … বিভাগ খুলে এগুলো রাখবে": the same list, into that account', (t) async {
    await open(t);
    await say('মাহি ২০০০ টাকা দিছে, আখি ৫০০ টাকা, ফয়সাল ১০০০ টাকা');
    await say('না');
    final r = await say('অন্যান্য হিসাবে শিক্ষার্থীদের বেতন সংক্রান্ত বিভাগ খুলে এগুলো রাখবে');
    expect(r, isNot(contains('পাবেন')));
    expect(r, contains('শিক্ষার্থীদের বেতন'));
    await say('হ্যাঁ');
    final own = data().cash.where((e) => e.linkId == null);
    expect(own, hasLength(3));
    expect(own.every((e) => e.projectId != null), isTrue);
  });

  testWidgets('temperature: on the home sky and asked in the chat', (t) async {
    await open(t);
    (rig.brain.services.weather as FakeWeather).answer =
        Weather(temp: 27.6, feels: 30.2, min: 23, max: 31, humidity: 78, code: 2, place: 'ঢাকা', at: DateTime(2026, 10, 18, 22, 30));
    await rig.brain.refreshWeather();
    await settle(t);
    expect(find.byKey(const Key('home-temp')), findsOneWidget);
    expect(find.textContaining('২৮°'), findsWidgets);
    final r = await say('আজ তাপমাত্রা কত?');
    expect(r, contains('২৮°'));
    expect(r, contains('আংশিক মেঘলা'));
  });
}
