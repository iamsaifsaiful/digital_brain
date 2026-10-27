import 'package:digital_brain/logic/cash.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/money_screens.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  group('অন্যান্য হিসাব → মূল হিসাব only with the user’s yes (owner, 27 Oct)', () {
    testWidgets('a new হিসাব stays out until asked; yes brings its entries in; no takes them out', (t) async {
      final rig = await start(t);
      final b = rig.brain;
      final now = b.services.now();
      final p = await b.projectNamed('দোকান');
      expect(p.inMain, isFalse);
      expect(p.mainAsked, isFalse);
      final e = CashEntry(kind: CashKind.expense, amount: 1500, category: 'মাল কেনা', date: now, projectId: p.id);
      await b.saveCash(e);
      expect(b.lastMainLine, isNull);
      expect(mainCopyOf(b.data, e.id), isNull, reason: 'not added before the user said yes');

      await b.setProjectMain(p.id, true);
      expect(b.data.projects.single.mainAsked, isTrue);
      expect(mainCopyOf(b.data, e.id)!.amount, 1500, reason: 'the entry already written comes in');
      final e2 = CashEntry(kind: CashKind.expense, amount: 300, category: 'ভাড়া', date: now, projectId: p.id);
      await b.saveCash(e2);
      expect(b.lastMainLine?.amount, 300);

      await b.setProjectMain(p.id, false);
      expect(mainCopyOf(b.data, e.id), isNull);
      expect(mainCopyOf(b.data, e2.id), isNull);
      expect(b.data.cash.where((c) => c.projectId == p.id).length, 2, reason: 'the হিসাব’s own entries stay');
    });

    testWidgets('by voice: asked after the first entry; a new request is not taken as the answer; "হ্যাঁ" lets it in', (t) async {
      final rig = await start(t);
      rig.brain.data.projects.add(Project(id: 'p9', name: 'বাড়ি মেরামত'));
      final chat = ChatController(rig.brain);
      Future<String> say(String s) async {
        final n = chat.messages.length;
        await chat.hear(s);
        return chat.messages.skip(n).where((m) => !m.fromUser).map((m) => m.text).join(' ');
      }

      var r = await say('বাড়ি মেরামত হিসাবে মিস্ত্রির বিল ২৯০০ টাকা খরচ');
      if (chat.wait == ChatWait.yesNo) r = await say('হ্যাঁ');
      expect(r, contains('মূল হিসাবেও যোগ হবে?'));
      final e = rig.brain.data.cash.firstWhere((c) => c.projectId == 'p9');
      expect(mainCopyOf(rig.brain.data, e.id), isNull, reason: 'not before the yes');
      // Asked again on the next entry; this time a question comes instead of an answer.
      r = await say('অন্যান্য হিসাবের সব দাও');
      expect(rig.brain.data.projects.single.mainAsked, isFalse);
      // The question comes again with the next entry; now the answer.
      await say('বাড়ি মেরামত হিসাবে রং ৫০০ টাকা খরচ');
      if (chat.wait == ChatWait.yesNo) await say('হ্যাঁ');
      // A second "হ্যাঁ" at once is the answer to the new question, not a repeat.
      r = await say('হ্যাঁ');
      expect(r, contains('মূল হিসাবেও যোগ হবে।'));
      expect(rig.brain.data.projects.single.mainAsked, isTrue);
      expect(mainCopyOf(rig.brain.data, e.id)?.amount, 2900);
    });

    test('only a plain answer counts', () {
      expect(ChatController.mainAnswer('হ্যাঁ'), isTrue);
      expect(ChatController.mainAnswer('জি, যোগ করো'), isTrue);
      expect(ChatController.mainAnswer('যোগ করুন'), isTrue);
      expect(ChatController.mainAnswer('না'), isFalse);
      expect(ChatController.mainAnswer('আলাদা রাখো'), isFalse);
      expect(ChatController.mainAnswer('যোগ করো না'), isFalse);
      expect(ChatController.mainAnswer('অন্যান্য হিসাবের সব দাও'), isNull);
      expect(ChatController.mainAnswer('মিস্ত্রির বিল ৫০০ টাকা'), isNull);
    });

    test('a হিসাব saved before this keeps going in, as it did, until asked', () {
      final old = Project.fromJson({'id': 'x', 'name': 'বাড়ির কাজ', 'createdAt': '2026-10-01T00:00:00.000'});
      expect(old.inMain, isTrue);
      expect(old.mainAsked, isFalse);
      final back = Project.fromJson(old.copyWith(inMain: false, mainAsked: true).toJson());
      expect(back.inMain, isFalse);
      expect(back.mainAsked, isTrue);
    });

    testWidgets('the new-হিসাব form cannot be saved without the answer', (t) async {
      await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => TextButton(onPressed: () => askNewProject(c), child: const Text('open')))));
      await t.tap(find.text('open'));
      await settle(t);
      await t.enterText(find.byType(TextField).first, 'দোকান');
      await t.pump();
      TextButton ok() => t.widget<TextButton>(find.byKey(const Key('project-ok')));
      expect(ok().onPressed, isNull, reason: 'no answer yet');
      await t.tap(find.byKey(const Key('main-no')));
      await t.pump();
      expect(ok().onPressed, isNotNull);
    });

    testWidgets('the question asked by itself cannot be closed without an answer', (t) async {
      bool? got;
      await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => TextButton(onPressed: () async => got = await askProjectMain(c, 'দোকান'), child: const Text('open')))));
      await t.tap(find.text('open'));
      await settle(t);
      expect(t.widget<TextButton>(find.byKey(const Key('main-ok'))).onPressed, isNull);
      await t.tapAt(const Offset(5, 5)); // outside the dialog
      await settle(t);
      expect(find.byKey(const Key('main-ok')), findsOneWidget);
      await t.tap(find.byKey(const Key('main-yes')));
      await t.pump();
      await t.tap(find.byKey(const Key('main-ok')));
      await settle(t);
      expect(got, isTrue);
    });
  });
}
