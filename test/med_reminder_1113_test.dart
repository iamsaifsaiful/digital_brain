// Owner, 13 Nov: the Play app keeps its medical pages off, but a medicine can
// still be reminded of: its name and times, each a daily reminder.
import 'package:digital_brain/logic/pro.dart' show medicalOffForTests;
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/new_item_screen.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  tearDown(() => medicalOffForTests = false);

  testWidgets('the reminder form: medicine, two times, a daily reminder each', (t) async {
    medicalOffForTests = true;
    final rig = await start(t);
    Navigator.of(t.element(find.byTooltip('বলুন'))).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.reminder)));
    await settle(t);
    await t.tap(find.byKey(const Key('rem-med')));
    await settle(t);
    await t.enterText(find.byType(TextFormField).first, 'নাপা');
    // 8:00 and 21:00 are on; 14:00 added.
    await t.tap(find.byKey(Key('rem-med-${14 * 60}')));
    await settle(t);
    final save = find.text('রাখুন').last;
    await t.ensureVisible(save);
    await settle(t);
    await t.tap(save);
    await settle(t);
    final rs = rig.brain.data.reminders;
    expect(rs.length, 3);
    expect(rs.every((r) => r.repeat == Repeat.daily && r.title == 'নাপা খাওয়ার সময়'), isTrue);
    expect({for (final r in rs) r.hour}, {8, 14, 21});
  });

  testWidgets('said aloud in the Play app: a daily reminder, not "not in this app"', (t) async {
    medicalOffForTests = true;
    final rig = await start(t);
    final chat = ChatController(rig.brain);
    await chat.hear('রোজ রাত ৯টায় নাপা খাওয়ার কথা মনে করিয়ে দিও');
    expect(chat.messages.last.text, isNot(contains('Google Play')));
    final r = rig.brain.data.reminders.single;
    expect((r.hour, r.repeat), (21, Repeat.daily));
  });
}
