// Owner's recording, 26 Oct: "রবিনের কাছে ৫০০০ টাকা পাই" sat on "ভাবছি…"
// for about six seconds (premium: the AI was asked) and came back as a loan
// whose kind had to be asked again. A plain balance stays on the phone, and
// when the rules already understood a message the AI is waited for only a
// few seconds.
import 'dart:async';

import 'package:digital_brain/logic/ledger.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/brain.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, start;

late Rig rig;
late ChatController chat;
AppData data() => rig.brain.data;

Future<void> open(WidgetTester t, [AppData? d]) async {
  rig = await start(t);
  rig.nowAt = DateTime(2026, 10, 26, 18);
  if (d != null) rig.brain.data = d;
  chat = ChatController(rig.brain);
  rig.ai.key = 'test-key';
}

void main() {
  testWidgets('"রবিনের কাছে ৫০০০ টাকা পাই" (premium): kept on the phone, no AI, no extra question', (t) async {
    await open(t, AppData(contacts: [Contact(name: 'রবিন', phone: '01711000001')]));
    rig.ai.answer = {'reply': 'জি', 'items': const []};
    await chat.hear('রবিনের কাছে ৫০০০ টাকা পাই');
    if (chat.wait == ChatWait.yesNo) await chat.hear('হ্যাঁ');
    expect(rig.ai.asked, isEmpty, reason: 'a plain balance is not sent to the AI');
    expect(balanceWith(data().ledger, 'রবিন'), 5000);
  });

  testWidgets('a slow AI: the rules\' reading after a few seconds, not twenty', (t) async {
    await open(t, AppData(contacts: [Contact(name: 'রহিম', phone: '01711000002')]));
    final never = Completer<void>();
    rig.ai.gate = never.future;
    rig.ai.answer = {'reply': 'জি', 'items': const []};
    var done = false;
    unawaited(chat.hear('রহিমকে ৫০০ টাকা দিলাম').then((_) => done = true));
    await t.pump(const Duration(seconds: 1));
    expect(rig.ai.asked, hasLength(1));
    expect(done, isFalse, reason: 'the AI is given its few seconds');
    await t.pump(Brain.aiPatience);
    await t.pump();
    expect(done, isTrue, reason: 'not left on "ভাবছি…"');
    // The phone's own reading goes on: which kind of money it was.
    expect(chat.wait, isNot(ChatWait.none));
    expect(chat.thinking, isFalse);
  });

  testWidgets('rules that understood nothing still wait for the AI', (t) async {
    await open(t);
    final slow = Completer<void>();
    rig.ai.gate = slow.future;
    rig.ai.answer = {'reply': 'আকাশ নীল দেখায় আলোর বিক্ষেপণের জন্য।', 'items': const []};
    var done = false;
    unawaited(chat.hear('আকাশ নীল কেন হয় একটু বুঝিয়ে বলো').then((_) => done = true));
    await t.pump(const Duration(seconds: 8));
    expect(done, isFalse);
    slow.complete();
    await t.pump();
    await t.pump();
    expect(done, isTrue);
    expect(chat.messages.any((m) => !m.fromUser && m.text.contains('বিক্ষেপণ')), isTrue);
  });
}
