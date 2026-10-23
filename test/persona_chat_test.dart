// The second 20-person walk (23 Oct, with the phone model): what went wrong
// in the conversation itself, replayed by voice.
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, settle, start, tell;

void main() {
  Future<Rig> begin(WidgetTester t) async {
    final rig = await start(t);
    await t.tap(find.byTooltip('বলুন').first);
    await settle(t);
    return rig;
  }

  String said(Rig rig, int from) => rig.voice.spoken.skip(from).join(' ⏎ ');

  testWidgets('"অন্যান্য হিসাব খোলো" opens the page — never an account named অন্যান্য', (t) async {
    final rig = await begin(t);
    await tell(t, rig, 'অন্যান্য হিসাব খোলো');
    await settle(t);
    expect(rig.brain.data.projects, isEmpty);
  });

  testWidgets('a page asked for while a name or an amount waits is opened, not taken as the answer', (t) async {
    final rig = await begin(t);
    await tell(t, rig, 'আজ একশো টাকা দিলাম');
    final n0 = rig.voice.spoken.length;
    await tell(t, rig, 'রিমাইন্ডার খোলো');
    await settle(t);
    expect(said(rig, n0), isNot(contains('নাম')), reason: 'not asked for the name again');
    expect(rig.brain.data.ledger, isEmpty);
  });

  testWidgets('a question while a note waits for yes is answered, never a yes to the note', (t) async {
    final rig = await begin(t);
    await tell(t, rig, 'আজ তিলাওয়াত করেছি');
    final notes0 = rig.brain.data.notes.length;
    await tell(t, rig, 'এই সপ্তাহে কত দিন তিলাওয়াত করেছি');
    await settle(t);
    expect(rig.brain.data.notes.length, notes0, reason: 'the question did not save the waiting note');
  });
}
