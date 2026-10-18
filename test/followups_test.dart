// Every one-tap suggestion is a sentence the app understands as meant —
// never kept as a to-do by mistake, never "বুঝিনি".
import 'package:digital_brain/logic/suggest.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, start;

void main() {
  late Rig rig;
  late ChatController chat;

  Future<String> say(String s) async {
    final n = chat.messages.length;
    await chat.hear(s);
    return chat.messages.skip(n).where((m) => !m.fromUser).map((m) => [m.text, ...m.facts].join(' ')).join(' ');
  }

  Future<void> open(WidgetTester t) async {
    rig = await start(t);
    final d = rig.brain.data;
    d.tasks.addAll([Task(id: 'a1', title: 'বাজার করা', due: DateTime(2026, 10, 9)), Task(id: 'a2', title: 'ওষুধ আনা', due: DateTime(2026, 10, 9))]);
    d.reminders.addAll([Reminder(id: 'r1', title: 'মিটিং', date: DateTime(2026, 10, 10), hour: 10), Reminder(id: 'r2', title: 'বাসা ভাড়া', date: DateTime(2026, 11, 10), hour: 10)]);
    d.ledger.add(LedgerEntry(id: 'l1', person: 'রহিম', kind: LedgerKind.lent, amount: 500, date: DateTime(2026, 10, 1)));
    chat = ChatController(rig.brain);
  }

  bool bad(String r, [String asked = '']) => (r.contains('কাজের তালিকায় রেখেছি') && !asked.contains('কাজের তালিকায়')) || r.contains('বুঝতে পারিনি') || r.contains('ধরতে পারিনি') || r.trim().isEmpty;

  for (final (setup, kind) in const [('আজকের কাজের তালিকা দাও', 'tasks'), ('আমার সব রিমাইন্ডার দেখাও', 'reminders'), ('আমার পাওনা টাকা কত?', 'ledger')]) {
    testWidgets('after "$setup" ($kind): each next step is understood', (t) async {
      await open(t);
      await say(setup);
      final steps = chat.followUps;
      expect(steps, isNotEmpty);
      for (final s in steps) {
        await open(t);
        await say(setup);
        final r = await say(s);
        expect(bad(r), isFalse, reason: '"$s" → $r');
        if (chat.wait != ChatWait.none) await say('থাক');
      }
    });
  }

  testWidgets('typed words: every prompt offered is understood', (t) async {
    await open(t);
    for (final typed in const ['আয়', 'খরচ', 'রিমাইন্ডার', 'এলার্ম', 'যোগাযোগ', 'কাজ', 'নোট', 'পাওনা', 'হিসাব']) {
      final ps = suggestPrompts(typed, rig.brain.data);
      expect(ps, isNotEmpty, reason: typed);
      for (final p in ps.where((x) => !x.trim().endsWith('যে'))) {
        chat = ChatController(rig.brain);
        final r = await say(p);
        expect(bad(r, p), isFalse, reason: '"$typed" → "$p" → $r');
        if (chat.wait != ChatWait.none) await say('থাক');
      }
    }
  });
}
