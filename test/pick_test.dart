import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/family_screen.dart';
import 'package:digital_brain/screens/money_screens.dart' show CashPage;
import 'package:digital_brain/screens/notes_screen.dart';
import 'package:digital_brain/screens/reminders_screen.dart';
import 'package:digital_brain/screens/tasks_screen.dart';
import 'package:digital_brain/screens/transactions_screen.dart';
import 'package:digital_brain/services/files.dart' show FakeFiles;
import 'package:digital_brain/ui/widgets.dart' show SwipeTabs, showAppSheet;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  Future<void> open(WidgetTester t, Widget page) async {
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => page));
    await settle(t);
  }

  Future<void> pick(WidgetTester t, Finder row, {bool first = false}) async {
    // Mid-screen, so the bar that appears at the bottom never covers it.
    await Scrollable.ensureVisible(t.element(row), alignment: 0.5);
    await settle(t);
    // Near its left edge: a floating add button may sit over its middle.
    final at = t.getTopLeft(row) + const Offset(24, 12);
    if (first) {
      await t.longPressAt(at);
    } else {
      await t.tapAt(at);
    }
    await settle(t);
  }

  testWidgets('কাজের তালিকা: hold one, tap another → both finished at once; the rest untouched', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final a = Task(title: 'ব্যাংকে যাওয়া'), c = Task(title: 'বিল দেওয়া'), d = Task(title: 'ডাক্তার');
    b.data.tasks.addAll([a, c, d]);
    await open(t, const TasksScreen());
    expect(find.byKey(const Key('pick-bar')), findsNothing);
    await pick(t, find.byKey(Key('task-${a.id}')), first: true);
    expect(find.byKey(const Key('pick-bar')), findsOneWidget);
    expect(find.text('১টা বাছাই'), findsOneWidget);
    await pick(t, find.byKey(Key('task-${c.id}')));
    expect(find.text('২টা বাছাই'), findsOneWidget);
    await t.tap(find.byKey(const Key('pick-শেষ')));
    await settle(t);
    expect(b.data.tasks.where((x) => x.done).map((x) => x.title).toSet(), {'ব্যাংকে যাওয়া', 'বিল দেওয়া'});
    expect(b.data.tasks.firstWhere((x) => x.id == d.id).done, isFalse);
    expect(find.byKey(const Key('pick-bar')), findsNothing, reason: 'done → selection ends');
  });

  testWidgets('কাজের তালিকা: "সব" picks every row; delete asks, then all go to মুছে ফেলা and come back with ফিরিয়ে আনুন', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final a = Task(title: 'এক'), c = Task(title: 'দুই');
    b.data.tasks.addAll([a, c]);
    await open(t, const TasksScreen());
    await pick(t, find.byKey(Key('task-${a.id}')), first: true);
    await t.tap(find.byKey(const Key('pick-all')));
    await settle(t);
    expect(find.text('২টা বাছাই'), findsOneWidget);
    await t.tap(find.byKey(const Key('pick-মুছুন')));
    await settle(t);
    await t.tap(find.text('মুছুন').last);
    await settle(t);
    expect(b.data.tasks, isEmpty);
    expect(b.data.trash.length, 2);
    await t.tap(find.text('ফিরিয়ে আনুন'));
    await settle(t);
    expect(b.data.tasks.map((x) => x.title).toSet(), {'এক', 'দুই'});
  });

  testWidgets('কাজের তালিকা: back while picking only ends the picking', (t) async {
    final rig = await start(t);
    final a = Task(title: 'এক');
    rig.brain.data.tasks.add(a);
    await open(t, const TasksScreen());
    await pick(t, find.byKey(Key('task-${a.id}')), first: true);
    await t.binding.handlePopRoute();
    await settle(t);
    expect(find.byType(TasksScreen), findsOneWidget);
    expect(find.byKey(const Key('pick-bar')), findsNothing);
  });

  testWidgets('আয়-ব্যয়: pick two, see their total, change their খাত together, share them', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final now = b.services.now();
    final x = CashEntry(kind: CashKind.expense, amount: 500, category: 'অন্যান্য', date: now);
    final y = CashEntry(kind: CashKind.expense, amount: 300, category: 'অন্যান্য', date: now);
    final z = CashEntry(kind: CashKind.income, amount: 1000, category: 'বেতন', date: now);
    b.data.cash.addAll([x, y, z]);
    await open(t, const CashPage());
    await t.ensureVisible(find.byKey(Key('cash-${x.id}')));
    await pick(t, find.byKey(Key('cash-${x.id}')), first: true);
    await t.ensureVisible(find.byKey(Key('cash-${y.id}')));
    await pick(t, find.byKey(Key('cash-${y.id}')));
    expect(find.text('২টা বাছাই'), findsOneWidget);
    expect(find.text('খরচ ৳৮০০'), findsOneWidget);
    await t.tap(find.byKey(const Key('pick-পাঠান')));
    await settle(t);
    expect((b.services.files as FakeFiles).sharedText, contains('মোট খরচ ৳৮০০'));
    await t.tap(find.byKey(const Key('pick-খাত বদলান')));
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'বাজার');
    await t.tap(find.text('ঠিক আছে'));
    await settle(t);
    expect(b.data.cash.where((e) => e.category == 'বাজার').length, 2);
    expect(b.data.cash.firstWhere((e) => e.id == z.id).category, 'বেতন');
    expect(b.data.cash.firstWhere((e) => e.id == x.id).amount, 500, reason: 'only the খাত changes');
  });

  testWidgets('সব লেনদেন: pick two and delete them; swipe-to-delete is off while picking', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final now = b.services.now();
    final e1 = LedgerEntry(person: 'রহিম', amount: 500, kind: LedgerKind.lent, date: now);
    final e2 = LedgerEntry(person: 'করিম', amount: 700, kind: LedgerKind.borrowed, date: now);
    final e3 = LedgerEntry(person: 'জামাল', amount: 900, kind: LedgerKind.lent, date: now);
    b.data.ledger.addAll([e1, e2, e3]);
    await open(t, const TransactionsScreen());
    await pick(t, find.text('রহিম'), first: true);
    await pick(t, find.text('করিম'));
    expect(find.text('২টা বাছাই'), findsOneWidget);
    await t.tap(find.byKey(const Key('pick-মুছুন')));
    await settle(t);
    await t.tap(find.text('মুছুন').last);
    await settle(t);
    expect(b.data.ledger.map((e) => e.person), ['জামাল']);
  });

  testWidgets('রিমাইন্ডার: pick several and switch them off together', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final now = b.services.now();
    final r1 = Reminder(title: 'বিদ্যুৎ বিল', date: now.add(const Duration(days: 3)));
    final r2 = Reminder(title: 'গ্যাস বিল', date: now.add(const Duration(days: 4)));
    b.data.reminders.addAll([r1, r2]);
    await open(t, const RemindersScreen());
    await pick(t, find.byKey(Key('rem-${r1.id}')), first: true);
    await pick(t, find.byKey(Key('rem-${r2.id}')));
    await t.tap(find.byKey(const Key('pick-বন্ধ করুন')));
    await settle(t);
    expect(b.data.reminders.every((r) => !r.enabled), isTrue);
    expect(b.data.reminders.length, 2, reason: 'switched off, kept');
  });

  testWidgets('নোট: pick two and move them to another section', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final n1 = Note(title: 'গাড়ির কাগজ', body: 'আলমারিতে');
    final n2 = Note(title: 'ওয়াইফাই', body: 'রাউটারের নিচে');
    b.data.notes.addAll([n1, n2]);
    await open(t, const NotesScreen());
    await pick(t, find.byKey(Key('note-${n1.id}')), first: true);
    await pick(t, find.byKey(Key('note-${n2.id}')));
    await t.tap(find.byKey(const Key('pick-বিভাগ বদলান')));
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'বাসা');
    await t.tap(find.text('ঠিক আছে'));
    await settle(t);
    expect(b.data.notes.every((n) => n.category == 'বাসা'), isTrue);
  });

  testWidgets('উত্তরাধিকারী: photos of notes and documents show as "ছবি দেখুন"; not yet uploaded → says so', (t) async {
    await start(t);
    final photo = DocFile(name: 'দলিল.jpg', mime: 'image/jpeg', size: 1000);
    final data = AppData(
      notes: [Note(title: 'জমির খবর', body: 'দলিল আলমারিতে', files: [photo])],
      docs: [Doc(title: 'জাতীয় পরিচয়পত্র', files: [DocFile(name: 'nid.jpg', mime: 'image/jpeg', size: 900)])],
    ).toJson()
      ..['parts'] = ['notes', 'docs']
      ..['files_key'] = '';
    await open(t, HeirViewScreen(title: 'আব্বা', data: Map<String, dynamic>.from(data)));
    expect(find.text('ছবি দেখুন'), findsNWidgets(2));
    await t.tap(find.byKey(Key('heir-file-${photo.id}')));
    await settle(t);
    expect(find.textContaining('এখনো আসেনি'), findsOneWidget);
  });


  testWidgets('SwipeTabs: a fling left goes to the next tab, right to the one before; ends stay put', (t) async {
    var tab = 'a';
    await t.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (ctx, set) => SwipeTabs<String>(
          items: const ['a', 'b', 'c'],
          value: tab,
          onChanged: (v) => set(() => tab = v),
          child: SizedBox.expand(child: Text(tab)),
        ),
      ),
    ));
    await t.fling(find.text('a'), const Offset(-300, 0), 1000);
    await t.pumpAndSettle();
    expect(tab, 'b');
    await t.fling(find.text('b'), const Offset(300, 0), 1000);
    await t.pumpAndSettle();
    expect(tab, 'a');
    await t.fling(find.text('a'), const Offset(300, 0), 1000);
    await t.pumpAndSettle();
    expect(tab, 'a');
  });

  testWidgets('showAppSheet keeps the sheet above the phone\'s navigation bar', (t) async {
    await t.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(400, 800), padding: EdgeInsets.only(bottom: 48), viewPadding: EdgeInsets.only(bottom: 48)),
        child: Builder(
          builder: (ctx) => Scaffold(body: Center(child: TextButton(onPressed: () => showAppSheet<void>(context: ctx, builder: (_) => const SizedBox(height: 60, child: Text('বোতাম'))), child: const Text('খুলুন')))),
        ),
      ),
    ));
    await t.tap(find.text('খুলুন'));
    await t.pumpAndSettle();
    final bottom = t.getBottomLeft(find.text('বোতাম')).dy;
    expect(bottom, lessThanOrEqualTo(800 - 48));
  });
}
