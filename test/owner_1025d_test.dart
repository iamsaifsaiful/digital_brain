// Owner's fifth video (25 Oct). On screen the words were right ("এখানে
// তোমাকে না এটা হবে তোমাকে তুবা", "সেখানে তুমি বলছো তোমাকে আমি বলছি টোবা
// কে"), but the recogniser's final text dropped words ("এখানে তোমাকে না এটা
// হবে", "তুবা তু") and the app acted on that: a to-do "এখানে তোমাকে না",
// Tuba's phone number. Then "তোমারে আমি বললাম আমার কাজের তালিকা দাও" was
// answered "is X on the list?".
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/speech_join.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;

String same(String s) => s;

void main() {
  test('a clipped final never loses the words shown', () {
    final j = SpeechJoin();
    var s = j.newSession();
    j.result(s, 'এখানে তোমাকে না এটা হবে তোমাকে তুবা', isFinal: false, clean: same);
    j.result(s, 'এখানে তোমাকে না এটা হবে', isFinal: true, clean: same);
    expect(j.text, 'এখানে তোমাকে না এটা হবে তোমাকে তুবা');
    j.reset();
    s = j.newSession();
    j.result(s, 'সেখানে তুমি বলছো তোমাকে আমি বলছি টোবা কে', isFinal: false, clean: same);
    j.result(s, 'তুবা কে', isFinal: true, clean: same);
    expect(j.text, 'সেখানে তুমি বলছো তোমাকে আমি বলছি তুবা কে');
    // A final that corrects a word of the same length stays the final.
    j.reset();
    s = j.newSession();
    j.result(s, 'কাল সকালে বাজারে যাব', isFinal: false, clean: same);
    j.result(s, 'কাল সকালে বাজারে যাবো', isFinal: true, clean: same);
    expect(j.text, 'কাল সকালে বাজারে যাবো');
    expect(fuller('রহিমকে পাঁচশো টাকা দিলাম', 'রহিমকে পাঁচশো টাকা'), 'রহিমকে পাঁচশো টাকা দিলাম');
  });

  Future<(ChatController, dynamic)> saved(WidgetTester t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 25, 10, 49);
    final chat = ChatController(rig.brain);
    await chat.hear('আচ্ছা আগামীকালকে সকাল আটটা ৪৫ মিনিটে তোমাকে মাদ্রাসায় নিতে হবে একটা রিমাইন্ডার রাখো');
    if (chat.wait == ChatWait.yesNo) await chat.hear('হ্যাঁ');
    return (chat, rig);
  }

  testWidgets('"এখানে তোমাকে না, এটা হবে তোমাকে তুবা": the word swapped', (t) async {
    final (chat, rig) = await saved(t);
    await chat.hear('এখানে তোমাকে না এটা হবে তোমাকে তুবা');
    final r = (rig.brain.data as AppData).reminders.single;
    expect(r.title, contains('তুবাকে'));
    expect((rig.brain.data as AppData).tasks, isEmpty);
  });

  testWidgets('the new word cut off: asked, then put in — never a to-do', (t) async {
    final (chat, rig) = await saved(t);
    await chat.hear('এখানে তোমাকে না এটা হবে');
    expect(chat.messages.last.text, contains('জায়গায় কী হবে'));
    await chat.hear('তুবা');
    expect((rig.brain.data as AppData).reminders.single.title, contains('তুবাকে'));
    expect((rig.brain.data as AppData).tasks, isEmpty);
  });

  testWidgets('"তুমি বলছো তোমাকে, আমি বলছি তুবা কে": the word swapped, no phone number', (t) async {
    final (chat, rig) = await saved(t);
    await chat.hear('সেখানে তুমি বলছো তোমাকে আমি বলছি তুবা কে');
    expect((rig.brain.data as AppData).reminders.single.title, contains('তুবাকে'));
    expect(chat.messages.last.text, isNot(contains('নম্বর')));
  });

  testWidgets('"তোমারে আমি বললাম আমার কাজের তালিকা দাও": the list itself', (t) async {
    final rig = await start(t, data: AppData(tasks: [Task(title: 'বাজার করা'), Task(title: 'ব্যাংকে যাওয়া')]));
    rig.nowAt = DateTime(2026, 10, 25, 10, 50);
    final chat = ChatController(rig.brain);
    await chat.hear('তোমারে আমি বললাম আমার কাজের তালিকা দাও');
    final reply = chat.messages.where((m) => !m.fromUser).map((m) => m.text).join(' ');
    expect(reply, allOf(contains('বাজার'), contains('ব্যাংক')));
  });
}
