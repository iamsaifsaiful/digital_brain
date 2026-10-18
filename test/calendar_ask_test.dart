// 18 Oct: "এ মাসে কি কি ছুটি আছে" → "এ বিষয়ে কোনো তথ্য নেই", though the
// app has the holiday calendar. Answered from it now (test clock Fri 9 Oct 2026).
import 'package:digital_brain/logic/calendar_ask.dart';
import 'package:digital_brain/logic/parser.dart';
import 'package:digital_brain/logic/plan.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;

void main() {
  final now = DateTime(2026, 10, 9, 15, 53);
  Command one(String s) => parseAll(s, const [], now: now, data: AppData()).single;

  test('holiday and date questions go to the calendar; other things do not', () {
    for (final s in ['আজকের তারিখ কত?', 'আজ বাংলা কত তারিখ?']) {
      final c = one(s);
      expect(c is SmallTalk && c.kind == Talk.date, isTrue, reason: '$s → $c');
    }
    for (final s in ['এ মাসে কি কি ছুটি আছে', 'পরের ছুটি কবে?', '১৬ ডিসেম্বর কিসের ছুটি?', 'বিজয় দিবস কবে?', 'কাল কত তারিখ?', '২১ ফেব্রুয়ারি কী বার?', 'নভেম্বরে কোনো ছুটি আছে?', 'এ বছর কয়টা ছুটি?']) {
      final c = one(s);
      expect(c is SmallTalk && c.kind == Talk.calendar, isTrue, reason: '$s → $c');
    }
    for (final s in ['কাল ছুটি নেব', 'শুক্রবার অফিসে যাব না, ছুটি আছে', 'রহিমের জন্মদিন কবে?', 'বিদ্যুৎ বিলের তারিখ কত?', 'মিটিং কবে?']) {
      final c = one(s);
      expect(c is SmallTalk && c.kind == Talk.calendar, isFalse, reason: '$s → $c');
    }
  });

  test('the answers', () {
    String a(String s) => calendarAnswer(s, now);
    expect(a('এ মাসে কি কি ছুটি আছে'), allOf(contains('৩ দিন'), contains('দুর্গাপূজা'), contains('২০ অক্টোবর')));
    expect(a('পরের ছুটি কবে?'), allOf(contains('দুর্গাপূজা'), contains('২০ অক্টোবর থেকে ২৪ অক্টোবর')));
    expect(a('১৬ ডিসেম্বর কিসের ছুটি?'), contains('মহান বিজয় দিবস'));
    expect(a('কাল কি ছুটি?'), contains('সাপ্তাহিক ছুটি'));
    expect(a('বিজয় দিবস কবে?'), allOf(contains('১৬ ডিসেম্বর'), contains('আর ৬৮ দিন পর')));
    expect(a('নভেম্বরে কোনো ছুটি আছে?'), contains('কোনো সরকারি ছুটি নেই'));
    expect(a('কাল কত তারিখ?'), allOf(contains('কাল'), contains('১০ অক্টোবর ২০২৬'), contains('শনিবার')));
    expect(a('২১ ফেব্রুয়ারি কী বার?'), allOf(contains('রবিবার'), contains('২১ ফেব্রুয়ারি ২০২৭')));
  });

  testWidgets('in the chat: no "এ বিষয়ে কোনো তথ্য নেই"', (t) async {
    final rig = await start(t);
    final chat = ChatController(rig.brain);
    for (final s in ['এ মাসে কি কি ছুটি আছে', 'আজকের তারিখ কত?']) {
      final n = chat.messages.length;
      await chat.hear(s);
      final r = chat.messages.skip(n).where((m) => !m.fromUser).map((m) => m.text).join(' ');
      expect(r, isNot(contains('তথ্য নেই')), reason: s);
      expect(r, contains('অক্টোবর'), reason: s);
    }
  });
}
