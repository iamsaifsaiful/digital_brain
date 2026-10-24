// 19 Oct requests: compass (with qibla), where the income goes in percent,
// home repairs told on days off, and a thought about money each day.
import 'package:digital_brain/logic/calendar_bd.dart';
import 'package:digital_brain/logic/compass.dart';
import 'package:digital_brain/logic/money_quotes.dart';
import 'package:digital_brain/logic/proactive.dart';
import 'package:digital_brain/logic/spend_health.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/compass_screen.dart';
import 'package:digital_brain/services/compass.dart';
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
  final now = DateTime(2026, 10, 19, 10, 30); // a Monday

  Future<void> open(WidgetTester t) async {
    rig = await start(t);
    rig.nowAt = now;
    chat = ChatController(rig.brain);
  }

  CashEntry spend(String cat, int amount, int daysAgo) => CashEntry(kind: CashKind.expense, amount: amount, category: cat, date: now.subtract(Duration(days: daysAgo)));

  AppData week() => AppData()
    ..cash.addAll([
      CashEntry(kind: CashKind.income, amount: 30000, category: 'বেতন', date: now.subtract(const Duration(days: 10))),
      spend('খাবার', 2000, 1),
      spend('কেনাকাটা', 1500, 2),
      spend('বাজার', 1000, 3),
      spend('যাতায়াত', 300, 0),
      spend('খাবার', 400, 9), // the week before
    ]);

  test('qibla from Dhaka is west, a little north', () {
    final dhaka = placeNamed('ঢাকা');
    final q = qiblaFrom(dhaka.lat, dhaka.lon);
    expect(q, inInclusiveRange(275, 281));
    expect(directionName(q), 'পশ্চিম');
    expect(directionName(44), 'উত্তর-পূর্ব');
    expect(turnTo(350, 10), 20);
    expect(turnTo(10, 350), -20);
  });

  testWidgets('"কিবলা কোন দিকে?" is answered with the bearing, and opens the compass', (t) async {
    await open(t);
    final r = await say('কিবলা কোন দিকে?');
    expect(r, contains('পশ্চিম'));
    expect(r, contains('°'));
    expect(chat.messages.last.links.any((l) => l.page == 'compass'), isTrue);
  });

  testWidgets('the compass page follows the sensor and says when the phone faces the qibla', (t) async {
    await open(t);
    final nav = Navigator.of(t.element(find.byTooltip('বলুন')));
    nav.push(MaterialPageRoute(builder: (_) => const CompassScreen()));
    await settle(t);
    final fake = rig.brain.services.compass as FakeCompass;
    fake.point(const Heading(10));
    await settle(t);
    expect(find.text('১০°'), findsOneWidget);
    expect(find.text('উত্তর'), findsOneWidget);
    final dhaka = placeNamed(rig.brain.district);
    fake.point(Heading(qiblaFrom(dhaka.lat, dhaka.lon) + 1));
    await settle(t);
    expect(find.text('ফোনের মাথা এখন কিবলার দিকে'), findsOneWidget);
    fake.point(const Heading(200, accuracy: 0));
    await settle(t);
    expect(find.textContaining('ইংরেজি ৮-এর মতো'), findsOneWidget);
    expect(find.textContaining('ডানে আরও'), findsOneWidget);
    fake.point(null);
    await settle(t);
    expect(find.text('এই ফোনে কম্পাস সেন্সর নেই'), findsOneWidget);
  });

  test('a week\'s spending as shares of income, against 50/30/20', () {
    final h = spendHealth(week(), now);
    expect(h.income, 7000); // 30,000 a month → a week's part
    expect(h.spent, 4800);
    expect(h.wants, 3500);
    expect(h.pct(h.wants), 50);
    expect(h.lastWants, 400);
    final a = spendAdvice(h);
    expect(a.any((x) => x.contains('আয়ের ৫০%') && x.contains('৩০%')), isTrue, reason: a.join('\n'));
    expect(a.any((x) => x.contains('বাইরের খাবার-নাস্তা খাতে আয়ের ২৯%')), isTrue, reason: a.join('\n'));
    expect(a.any((x) => x.contains('বেঁচে আছে')), isTrue, reason: a.join('\n'));
    // No income written: shares of spending, and it says so.
    final none = spendHealth(AppData()..cash.addAll([spend('খাবার', 500, 1), spend('বাজার', 500, 1)]), now);
    expect(none.hasIncome, isFalse);
    expect(none.pct(500), 50);
    expect(spendAdvice(none).first, contains('আয় লেখা নেই'));
  });

  testWidgets('"আমার খরচ কেমন হচ্ছে?" and "অপ্রয়োজনীয় খরচ কোথায়?" answer in percent', (t) async {
    await open(t);
    rig.brain.data = week();
    final a = await say('আমার খরচ কেমন হচ্ছে?');
    expect(a, contains('আয়ের ৬৯%'));
    expect(a, contains('শখের'));
    final b = await say('অপ্রয়োজনীয় খরচ কোথায় বেশি হচ্ছে?');
    expect(b, contains('বাইরের খাবার-নাস্তা'));
    final c = await say('এই মাসে আয়ের কত ভাগ খরচ হলো?');
    expect(c, contains('গত ৩০ দিনে'));
  });

  testWidgets('home shows the week\'s share and the day\'s thought; the share opens the analysis', (t) async {
    await open(t);
    rig.brain.data = week();
    rig.brain.notifyListeners();
    await settle(t);
    await t.scrollUntilVisible(find.byKey(const Key('home-quote')), 300, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    expect(find.byKey(const Key('home-quote')), findsOneWidget);
    expect(find.text(quoteFor(now).text), findsOneWidget);
    final row = find.byKey(const Key('home-spend-health'));
    await t.scrollUntilVisible(row, -300, scrollable: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first);
    await t.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).at(1));
    expect(find.textContaining('শখের খাতে ৫০%'), findsOneWidget);
    await t.tap(row);
    await settle(t, 20);
    expect(find.byKey(const Key('spend-split')), findsOneWidget);
    expect(find.byKey(const Key('spend-advice')), findsOneWidget);
  });

  testWidgets('a thing at home to fix goes on its list and is told on the next day off', (t) async {
    await open(t);
    final r = await say('বাথরুমের কলটা নষ্ট হয়ে গেছে, ঠিক করাতে হবে');
    expect(r, contains('ছুটির দিন'));
    final task = data().tasks.single;
    expect(task.list, homeFixList);
    expect(task.title, 'বাথরুমের কলটা ঠিক করানো');
    await say('ফ্যানটা মেরামত করতে হবে');
    expect(homeFixes(data()), hasLength(2));
    final n = assistantNotices(data(), now, const AssistantPrefs()).where((x) => x.reminderId == nudgeFix).toList();
    expect(n, isNotEmpty);
    final first = n.first;
    expect(holidayOn(first.at) != null || isWeekend(first.at), isTrue);
    expect(first.at.hour, 10);
    expect(first.title, contains('২টা'));
    expect(first.body, contains('ফ্যান'));
    // Not a repair: a call to make.
    expect(isHomeFix('রহিমকে কল করতে হবে'), isFalse);
    expect(isHomeFix('বাজার করতে হবে'), isFalse);
  });

  test('a thought about money every morning, a different one each day', () {
    final n = assistantNotices(AppData(), now, const AssistantPrefs(nudgesOn: false)).where((x) => x.reminderId == nudgeQuote).toList();
    expect(n, hasLength(2)); // today's 9:15 has passed
    expect(n.first.at.hour, 9);
    expect(n[0].body == n[1].body, isFalse);
    final off = assistantNotices(AppData(), now, const AssistantPrefs(quote: false)).where((x) => x.reminderId == nudgeQuote);
    expect(off, isEmpty);
    expect(moneyQuotes.length, greaterThanOrEqualTo(30));
  });

  test('the weekly round-up says the share spent on wants', () {
    final n = assistantNotices(week(), now, const AssistantPrefs()).where((x) => x.reminderId == nudgeWeek).toList();
    expect(n.single.body, contains('শখের খরচ আয়ের'));
  });
}
