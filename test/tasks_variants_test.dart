// The same meaning said other ways (19 Oct brief, §5 and §25): Bangla and
// English digits, words, "নং" attached or not, no punctuation, colloquial
// forms and a little Banglish. Each removes from the nine-item list shown
// (see tasks_audit_test.dart) and must leave exactly the expected items.
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show start;
import 'tasks_audit_test.dart' show nine;

void main() {
  const all = {'k1', 'k2', 'k3', 'k4', 'k5', 'k6', 'k7', 'k8', 'k9'};
  Set<String> minus(Set<String> x) => all.difference(x);

  final cases = <String, Set<String>>{
    // One place.
    '২য়টা বাদ দাও': minus({'k2'}),
    'দ্বিতীয় টা মুছে দাও': minus({'k2'}),
    '2 নম্বরটা মুছো': minus({'k2'}),
    'দুই নম্বর কাজটা বাদ দাও': minus({'k2'}),
    'শেষেরটা মুছে দাও': minus({'k9'}),
    'শেষটি বাদ দাও': minus({'k9'}),
    'প্রথমটি মুছো': minus({'k1'}),
    // Several places.
    '৩ নং ৪নং মুছে দাও': minus({'k3', 'k4'}),
    '3 আর 4 মুছে দাও': minus({'k3', 'k4'}),
    'তিন আর চার নম্বর মুছে দাও': minus({'k3', 'k4'}),
    '৩ এবং ৪ মুছে দাও': minus({'k3', 'k4'}),
    'প্রথম দুইটা মুছে দাও': minus({'k1', 'k2'}),
    'উপরের দুটি বাদ দাও': minus({'k1', 'k2'}),
    'শেষ তিনটি মুছে দাও': minus({'k7', 'k8', 'k9'}),
    // Ranges.
    'চার থেকে আট মুছে দাও': {'k1', 'k2', 'k3', 'k9'},
    '৪–৮ নম্বর মুছে দাও': {'k1', 'k2', 'k3', 'k9'},
    '4 থেকে 8 নম্বর বাদ দাও': {'k1', 'k2', 'k3', 'k9'},
    '৪নং থেকে ৮নং মুছে দাও': {'k1', 'k2', 'k3', 'k9'},
    // Keep these, the rest go.
    '৩নং ৪নং রেখে বাকিগুলো বাদ': {'k3', 'k4'},
    '৩ আর ৪ বাদে সব মুছো': {'k3', 'k4'},
    'তিন আর চার রেখে বাকি সব মুছে দাও': {'k3', 'k4'},
    // No punctuation, colloquial.
    'প্রথমটা আর দ্বিতীয়টা মুইছা দাও': minus({'k1', 'k2'}),
    'এগুলা সব মুছে দাও': <String>{},
    // A little Banglish.
    '4 theke 8 number muche dao': {'k1', 'k2', 'k3', 'k9'},
  };

  for (final e in cases.entries) {
    testWidgets('V: "${e.key}"', (t) async {
      final rig = await start(t);
      rig.nowAt = DateTime(2026, 10, 19, 10);
      rig.brain.data.tasks.addAll(nine());
      final chat = ChatController(rig.brain);
      await chat.hear('আমার কাজের তালিকা দাও');
      final n = chat.messages.length;
      await chat.hear(e.key);
      final r = chat.messages.skip(n).where((m) => !m.fromUser).map((m) => m.text).join(' ');
      if (chat.wait != ChatWait.none) await chat.hear('হ্যাঁ');
      expect({for (final x in rig.brain.data.tasks) x.id}, e.value, reason: r);
    });
  }

  // "দুই নম্বর কাজ" is a place; "দুইটা কাজ" is how many.
  testWidgets('V: "দুইটা কাজ যোগ করো" is not the 2nd item', (t) async {
    final rig = await start(t);
    rig.nowAt = DateTime(2026, 10, 19, 10);
    rig.brain.data.tasks.addAll(nine());
    final chat = ChatController(rig.brain);
    await chat.hear('আমার কাজের তালিকা দাও');
    await chat.hear('দুইটা কাজ মুছে দাও');
    if (chat.wait != ChatWait.none) await chat.hear('না');
    expect(rig.brain.data.tasks, hasLength(9));
  });
}
