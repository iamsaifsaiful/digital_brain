// Owner, 29 Oct: the free app opens one অন্যান্য হিসাব and writes into it;
// a second one needs Premium.
import 'package:digital_brain/logic/pro.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/money_screens.dart' show ProjectScreen;
import 'package:digital_brain/state/brain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, settle, start, tell;

void main() {
  test('free: one হিসাব — the first one opened that is still open', () async {
    expect(freeProjects, 1);
    expect(proInfo[ProFeature.projects]!.free, '১টা অন্যান্য হিসাব');
  });

  testWidgets('free: by voice the first হিসাব opens and takes the money; a second is not opened', (t) async {
    final rig = await start(t);
    final b = rig.brain..gated = true;
    expect(b.pro, isFalse);
    await settle(t);
    await t.tap(find.byTooltip('বলুন').first);
    await settle(t);
    await tell(t, rig, 'দোকান প্রজেক্টে ৫০০ টাকা খরচ');
    await settle(t);
    expect(find.textContaining('নতুন হিসাব খুলে ‘দোকান’ হিসাবে'), findsOneWidget);
    await tell(t, rig, 'হ্যাঁ');
    await settle(t);
    expect(b.data.projects.map((p) => p.name), ['দোকান']);
    expect(b.data.cash.where((e) => e.projectId == b.data.projects.single.id).map((e) => e.amount), [500]);
    expect(b.canAddProject, isFalse);
    await tell(t, rig, 'না');
    await settle(t);
    await tell(t, rig, 'বাড়ি প্রজেক্টে ২০০ টাকা খরচ');
    await settle(t);
    expect(b.data.projects.length, 1, reason: 'a second হিসাব needs Premium');
    expect(find.textContaining('প্রিমিয়াম'), findsWidgets);
  });

  testWidgets('free after the trial: the oldest open হিসাব takes entries; another asks for Premium', (t) async {
    final rig = await start(t);
    final b = rig.brain..gated = true;
    final first = Project(name: 'দোকান', createdAt: DateTime(2026, 10, 1), mainAsked: true);
    final second = Project(name: 'বিয়ে', createdAt: DateTime(2026, 10, 3), mainAsked: true);
    b.data.projects.addAll([second, first]);
    expect(b.freeProjectId, first.id);
    expect((b.canUseProject(first.id), b.canUseProject(second.id)), (true, false));
    expect(b.canUseProjectNamed('দোকান'), isTrue);
    expect(b.canUseProjectNamed('নতুন'), isFalse, reason: 'two are open already');

    await settle(t);
    final nav = Navigator.of(t.element(find.byTooltip('বলুন').first));
    Future<void> income(Project p) async {
      nav.push(MaterialPageRoute(builder: (_) => ProjectScreen(id: p.id)));
      await settle(t);
      await t.tap(find.byKey(const Key('project-income')));
      await settle(t);
    }

    await income(first);
    expect(find.text('প্রিমিয়াম নিন'), findsNothing);
    expect(find.textContaining('যত খুশি অন্যান্য হিসাব'), findsNothing, reason: 'the form opens, no Premium sheet');
    nav.popUntil((r) => r.isFirst);
    await settle(t);
    await income(second);
    expect(find.textContaining('যত খুশি অন্যান্য হিসাব'), findsOneWidget, reason: 'the Premium sheet');
  });

  test('medicine reminders never count toward the free 20 (owner, 29 Oct)', () async {
    final rig = Rig();
    await rig.brain.load();
    final b = rig.brain..gated = true;
    for (var i = 0; i < 6; i++) {
      await b.saveMedicine(Medicine(name: 'ওষুধ $i', times: [8 * 60, 14 * 60, 22 * 60]));
    }
    expect(b.data.reminders.length, 18);
    expect(b.activeReminders, 0);
    for (var i = 0; i < freeReminders; i++) {
      b.data.reminders.add(Reminder(title: 'r$i', date: DateTime(2026, 11), hour: 9));
    }
    expect(b.canAddReminder, isFalse, reason: 'the other 20 still count');
    await b.saveMedicine(Medicine(name: 'আরেকটা', times: [9 * 60]));
    expect(b.data.medicines.length, 7, reason: 'a medicine is never held back');
  });
}
