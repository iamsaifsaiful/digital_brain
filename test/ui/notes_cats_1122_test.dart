// নোট ও অন্যান্য by category (owner, 22 Nov): the first page shows the will
// and the categories as tiles (পারিবারিক, ব্যবসা, অনুষ্ঠান…); a tile opens its
// notes; a floating "নোট লিখুন" writes into the open category; the form has
// no বিভাগ field; লেখা and the tick list change with a swipe; the will opens
// with a sample already written. With SHOTS=1 --update-goldens:
// test/ui/shots/notes1122-*.png.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/notes_screen.dart';
import 'package:digital_brain/screens/will_screen.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'home_final_shots_test.dart' show icons, shots;

Future<void> _open(WidgetTester t, Widget page) async {
  Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => page));
  await settle(t);
}

void _fill(AppData d) {
  final now = DateTime(2026, 11, 22, 10);
  d.notes.addAll([
    Note(title: 'আম্মার চশমার পাওয়ার', body: 'ডান −১.৫, বাম −১.২৫ · ইসলামিয়া আই হসপিটাল', category: 'পারিবারিক', updatedAt: now),
    Note(title: 'ছোট ভাইয়ের ভর্তির কাগজ', body: '[ ] জন্ম নিবন্ধন\n[x] ছবি ৪ কপি\n[ ] টিকা কার্ড', category: 'পারিবারিক', updatedAt: now.subtract(const Duration(days: 1))),
    Note(title: 'দোকানের ভাড়া চুক্তি', body: 'প্রতি মাসের ৫ তারিখে ১৮,০০০ টাকা। চুক্তি শেষ মার্চ ২০২৭।', category: 'ব্যবসা', updatedAt: now.subtract(const Duration(days: 2))),
    Note(title: 'সাপ্লায়ারের নম্বর রাখার খাতা', body: 'আলমারির দ্বিতীয় তাকে', category: 'ব্যবসা', updatedAt: now.subtract(const Duration(days: 4))),
    Note(title: 'রিয়ার বিয়ের দাওয়াত', body: '১২ ডিসেম্বর, সন্ধ্যা ৭টা · রাওয়া কনভেনশন', category: 'অনুষ্ঠান', updatedAt: now.subtract(const Duration(days: 3))),
    Note(title: 'মাসের বাজার', body: '[ ] চাল ২৫ কেজি\n[ ] ডাল\n[x] তেল', category: 'কেনাকাটা', updatedAt: now.subtract(const Duration(days: 5))),
  ]);
}

void main() {
  testWidgets('22 Nov নোট: categories, open one, write into it, swipe, will sample', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    _fill(b.data);
    await _open(t, const NotesScreen());
    // The starting categories are there even when empty.
    for (final c in starterNoteCats) {
      expect(find.byKey(Key('cat-$c')), findsOneWidget);
    }
    expect(find.byKey(const Key('will-open')), findsOneWidget);
    expect(find.byKey(const Key('note-fab')), findsOneWidget);

    // Open পারিবারিক: only its notes, and the button writes into it.
    await t.tap(find.byKey(const Key('cat-পারিবারিক')));
    await settle(t);
    expect(find.text('আম্মার চশমার পাওয়ার'), findsOneWidget);
    expect(find.text('দোকানের ভাড়া চুক্তি'), findsNothing);
    await t.tap(find.byKey(const Key('note-fab')).last);
    await settle(t);
    expect(find.text('নতুন নোট'), findsOneWidget);
    // No বিভাগ field: one small line names the category.
    expect(find.widgetWithText(TextFormField, 'বিভাগ'), findsNothing);
    expect(find.byKey(const Key('note-cat')), findsOneWidget);
    await t.enterText(find.widgetWithText(TextFormField, 'শিরোনাম'), 'ঈদের কেনাকাটা');
    // Swipe left: the tick list; swipe right: back to লেখা.
    await t.fling(find.byKey(const Key('note-swipe')), const Offset(-300, 0), 1200);
    await settle(t);
    expect(find.byKey(const ValueKey('checklist')), findsOneWidget);
    await t.fling(find.byKey(const Key('note-swipe')), const Offset(300, 0), 1200);
    await settle(t);
    expect(find.byKey(const ValueKey('note-text')), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('note-text')), 'আব্বার পাঞ্জাবি');
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    final n = b.data.notes.firstWhere((n) => n.title == 'ঈদের কেনাকাটা');
    expect(n.category, 'পারিবারিক');

    // A new category stays while empty, and can be renamed and removed.
    await b.addNoteCat('বাড়ি');
    expect(b.noteCats, contains('বাড়ি'));
    await b.renameNoteCat('ব্যবসা', 'দোকান');
    expect(b.data.notes.where((n) => n.category == 'দোকান'), hasLength(2));
    expect(b.noteCats, isNot(contains('ব্যবসা')));
    await b.removeNoteCat('দোকান');
    expect(b.data.notes.where((n) => n.category == defaultNoteCategory), hasLength(2));

    // The will opens with the sample already written, editable.
    await _open(t, const WillScreen());
    final text = t.widget<TextField>(find.byKey(const Key('will-text'))).controller!.text;
    expect(text, startsWith('বিসমিল্লাহির রাহমানির রাহীম'));
    expect(find.byKey(const Key('will-ready')), findsOneWidget);
  });

  testWidgets('22 Nov will: another religion gets a sample without the Islamic parts', (t) async {
    final rig = await start(t);
    await rig.brain.setPref('religion', 'hindu');
    await _open(t, const WillScreen());
    final text = t.widget<TextField>(find.byKey(const Key('will-text'))).controller!.text;
    expect(text, isNot(contains('বিসমিল্লাহ')));
    expect(text, contains('প্রচলিত উত্তরাধিকার আইন'));
  });

  for (final look in [Look.light, Look.dark]) {
    for (final en in [false, true]) {
      testWidgets('নোট shots, ${look.name}, ${en ? 'en' : 'bn'}', (t) async {
        if (shots) await icons();
        final rig = await start(t);
        t.view.physicalSize = const Size(390 * 3, 844 * 3);
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        await rig.brain.setLook(look);
        if (en) await rig.brain.setEnglish(true);
        _fill(rig.brain.data);
        await settle(t);
        final tag = '${look.name}-${en ? 'en' : 'bn'}';
        Future<void> shot(String name) async {
          if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/notes1122-$name-$tag.png'));
        }

        await _open(t, const NotesScreen());
        await shot('1-categories');
        await t.tap(find.byKey(const Key('cat-পারিবারিক')));
        await settle(t);
        await shot('2-family');
        await t.tap(find.byKey(const Key('note-fab')).last);
        await settle(t);
        await t.enterText(find.byType(TextFormField).first, en ? 'Eid shopping' : 'ঈদের কেনাকাটা');
        await settle(t);
        await shot('3-new-note');
        await t.fling(find.byKey(const Key('note-swipe')), const Offset(-300, 0), 1200);
        await settle(t);
        await shot('4-swiped-list');
        await t.tap(find.byTooltip(en ? 'Back' : 'ফিরে যান').first);
        await settle(t);
        await t.tap(find.byTooltip(en ? 'Back' : 'ফিরে যান').first);
        await settle(t);
        await t.tap(find.byKey(const Key('note-fab')).last);
        await settle(t);
        await shot('5-pick-category');
        Navigator.of(t.element(find.byKey(const Key('pick-cat-new')))).pop();
        await settle(t);
        await t.tap(find.byKey(const Key('will-open')));
        await settle(t);
        await shot('6-will');
      });
    }
  }
}
