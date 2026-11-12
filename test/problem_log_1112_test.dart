// Owner's logs of 12 Nov: fixed in general ways, never a rule per sentence.
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;

void main() {
  testWidgets('"ব্যয়" is spending, as "খরচ" is — not a লেনদেন with someone', (t) async {
    final rig = await start(t);
    final chat = ChatController(rig.brain);
    await chat.hear('আজ বাজারে ব্যয় ৩০০ টাকা');
    expect(chat.messages.last.text, isNot(contains('কার সাথে')));
    expect(chat.messages.last.text, contains('খরচ'));
    // "আয়-ব্যয়" is still the summary, not spending.
    final again = ChatController((await start(t)).brain);
    await again.hear('আয়-ব্যয়ের হিসাব দাও');
    expect(again.brain.data.cash, isEmpty);
    expect(again.messages.last.text, contains('আয়-খরচ'));
  });

  testWidgets('"একটা বাজে" is a clock time, not "কটা বাজে?" — the reminder is kept', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 11, 12, 8);
    final chat = ChatController(rig.brain);
    await chat.hear('রাত একটা বাজে মনে করিয়ে দিও ওষুধ খেতে');
    expect(chat.messages.last.text, isNot(startsWith('এখন ')));
    expect(rig.brain.data.reminders, isNotEmpty);
    await chat.hear('এখন কটা বাজে');
    expect(chat.messages.last.text, startsWith('এখন '));
  });
}
