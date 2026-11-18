// Owner, 25 Oct: "ওষুধের দিনে কয়টা, এটা সিলেক্ট থাকবে, সিলেক্ট করলে ইউআই পরিবর্তন
// হবে, কখন খাবেন, এখানে ক্রস চিহ্নিত না রেখে টাইমে কালার পরিবর্তন দরকার।" and
// "ওষুধ কার জন্যে সেখান থেকেই সিলেক্ট করা যাবে".
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/health_screens.dart' show MedicinesScreen;
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/state/brain.dart' show BrainMore, BrainHealth;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  testWidgets('medicine form: times-a-day stays selected, times change colour (no crosses), and whose is chosen in the form', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.saveMember(FamilyMember(id: 'amma', name: 'আম্মা'));
    Navigator.of(t.element(find.byType(HomeShell))).push(MaterialPageRoute(builder: (_) => const MedicinesScreen()));
    await settle(t);
    await t.tap(find.text('ওষুধ যোগ'));
    await settle(t);

    bool on(Key k) => t.widget<Semantics>(find.descendant(of: find.byKey(k), matching: find.byType(Semantics)).first).properties.selected ?? false;

    // Default: twice a day, 9 and 21 — the chosen times only, as a short list (owner, 18 Nov).
    expect(on(const Key('med-per-2')), isTrue);
    expect(on(const Key('med-per-3')), isFalse);
    expect(find.byKey(Key('med-time-${9 * 60}')), findsOneWidget);
    expect(find.byKey(Key('med-time-${8 * 60}')), findsNothing);
    expect(find.byType(InputChip), findsNothing, reason: 'no crosses');

    // 3 a day: the pill stays selected and the times change with it.
    await t.tap(find.byKey(const Key('med-per-3')));
    await settle(t);
    expect(on(const Key('med-per-3')), isTrue);
    expect(on(const Key('med-per-2')), isFalse);
    for (final m in [8 * 60, 14 * 60, 22 * 60]) {
      expect(find.byKey(Key('med-time-$m')), findsOneWidget, reason: '$m');
    }
    expect(find.byKey(Key('med-time-${9 * 60}')), findsNothing);

    // Whose: me by default, আম্মা picked right here.
    expect(on(const Key('med-who-me')), isTrue);
    await t.ensureVisible(find.byKey(const Key('med-who-amma')));
    await t.tap(find.byKey(const Key('med-who-amma')));
    await settle(t);
    expect(on(const Key('med-who-amma')), isTrue);
    expect(on(const Key('med-who-me')), isFalse);

    await t.enterText(find.byType(TextField).first, 'মেটফরমিন');
    await t.ensureVisible(find.text('রাখুন'));
    await t.tap(find.text('রাখুন'));
    await settle(t);
    final m = b.data.medicines.single;
    expect(m.member, 'amma');
    expect(m.times, [8 * 60, 14 * 60, 22 * 60]);
    expect(b.data.reminders.where((r) => m.reminderIds.contains(r.id)).map((r) => r.title).toSet(), {'আম্মা-এর ওষুধ: মেটফরমিন'});

    // Changed back to me when edited.
    await b.saveMedicine(m.copyWith(member: 'me'));
    expect(b.data.medicines.single.member, 'me');
    expect(b.data.medicines.single.name, 'মেটফরমিন');
  });
}
