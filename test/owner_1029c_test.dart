// Owner, 29 Oct: the home's সব সুবিধা and the document folders are arranged
// by hand — hold a tile, drag it, let go; the order is kept.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/docs_screen.dart';
import 'package:digital_brain/screens/money_screens.dart' show ProjectsView;
import 'package:digital_brain/ui/drag_grid.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

Future<void> drag(WidgetTester t, Finder from, Finder to) async {
  final g = await t.startGesture(t.getCenter(from));
  await t.pump(kLongPressTimeout + const Duration(milliseconds: 100));
  await g.moveBy(const Offset(4, 4));
  await t.pump();
  await g.moveTo(t.getCenter(to));
  await t.pump(const Duration(milliseconds: 200));
  await g.up();
  await t.pumpAndSettle();
}

void main() {
  test('a saved order first, new ones after in their own order', () {
    expect(inOrder(['a', 'b', 'c', 'd'], (x) => x, ['c', 'a']), ['c', 'a', 'b', 'd']);
    expect(inOrder(['a', 'b'], (x) => x, const []), ['a', 'b']);
    expect(inOrder(['a', 'b'], (x) => x, ['gone', 'b']), ['b', 'a']);
  });

  testWidgets('home: সব সুবিধা — drag যাকাত onto কাজের তালিকা; kept; reset', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await settle(t);
    final tools = find.byKey(const Key('home-tools'));
    await t.scrollUntilVisible(tools, 300, scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    expect(find.text('চেপে ধরে টেনে সাজান'), findsOneWidget);
    await drag(t, find.byKey(const Key('tool-zakat')), find.byKey(const Key('tool-tasks')));
    final order = b.orderOf('home_tools');
    expect(order.first, 'zakat');
    expect(order[1], 'tasks');
    expect(b.prefs['order_home_tools'], isNotNull);
    // Shown in that order: যাকাত is left of কাজের তালিকা now.
    expect(t.getTopLeft(find.byKey(const Key('tool-zakat'))).dx, lessThan(t.getTopLeft(find.byKey(const Key('tool-tasks'))).dx));
    // A tap still opens it.
    await t.ensureVisible(find.byKey(const Key('home-tools-reset')));
    await t.tap(find.byKey(const Key('home-tools-reset')));
    await t.pumpAndSettle();
    expect(b.orderOf('home_tools'), isEmpty);
  });

  testWidgets('documents: drag a folder before ব্যাংক কার্ড; kept; a tap still opens', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await settle(t);
    Navigator.of(t.element(find.byTooltip('বলুন').first)).push(MaterialPageRoute(builder: (_) => const DocsScreen()));
    await settle(t);
    final folders = allDocFolders(b.data);
    final last = folders.last;
    await t.ensureVisible(find.byKey(Key('doc-folder-$last')));
    await drag(t, find.byKey(Key('doc-folder-$last')), find.byKey(const Key('doc-cards')));
    expect(b.orderOf('doc_folders').first, last);
    expect(b.orderOf('doc_folders')[1], '__cards');
    await t.tap(find.byKey(const Key('doc-cards')));
    await settle(t);
    expect(find.byType(DocsScreen), findsNothing, reason: 'the cards page is open on top');
  });

  testWidgets('অন্যান্য হিসাব: drag the older হিসাব above the newer; kept', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    final old = Project(name: 'দোকান', createdAt: DateTime(2026, 9, 1), mainAsked: true);
    final young = Project(name: 'বিয়ে', createdAt: DateTime(2026, 10, 1), mainAsked: true);
    b.data.projects.addAll([old, young]);
    await settle(t);
    Navigator.of(t.element(find.byTooltip('বলুন').first)).push(MaterialPageRoute(builder: (_) => const Scaffold(body: SafeArea(child: ProjectsView()))));
    await settle(t);
    final a = find.byKey(Key('project-cover-${old.id}')), y = find.byKey(Key('project-cover-${young.id}'));
    expect(t.getTopLeft(y).dy, lessThan(t.getTopLeft(a).dy), reason: 'newest first at the start');
    await drag(t, a, y);
    expect(b.orderOf('projects'), [old.id, young.id]);
    expect(t.getTopLeft(a).dy, lessThan(t.getTopLeft(y).dy));
  });
}
