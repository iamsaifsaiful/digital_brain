// আমার ফাইল of 20 Nov, after the owner's reference picture: a hello and
// search, a ring of the room the app takes, the kinds as soft tiles, the
// latest kept as cards with ⋮ to open or share. Every document can be
// shared to other apps — from this tab, the documents list and the
// document page. With SHOTS=1 --update-goldens the screens go to
// test/ui/shots/store1120-*.png.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show Rig, settle, start;
import 'home_final_shots_test.dart' show icons, sample, shots;

/// The sample, with the passport's two pages kept in the store.
Future<void> withPages(Rig rig) async {
  final d = sample(rig.nowAt);
  final pass = d.docs.single.copyWith(files: [
    DocFile(id: 'pp1', name: 'passport-1.jpg', mime: 'image/jpeg', size: 1240000),
    DocFile(id: 'pp2', name: 'passport-2.jpg', mime: 'image/jpeg', size: 1180000),
  ]);
  await rig.brain.services.store.saveDocFile('pp1', [1, 2, 3]);
  await rig.brain.services.store.saveDocFile('pp2', [4, 5, 6]);
  d.docs[0] = pass;
  rig.brain.data = d;
}

void main() {
  for (final look in [Look.light, Look.dark]) {
    for (final en in [false, true]) {
      for (final width in [390.0, 360.0]) {
        final name = '${look.name}-${en ? 'en' : 'bn'}-${width.round()}';
        testWidgets('20 Nov My Files, $name', (t) async {
          if (shots) await icons();
          final rig = await start(t);
          t.view.physicalSize = Size(width * 3, 1180 * 3);
          t.view.devicePixelRatio = 3;
          addTearDown(t.view.reset);
          rig.nowAt = DateTime(2026, 10, 24, 18, 34);
          await rig.brain.setLook(look);
          if (en) await rig.brain.setEnglish(true);
          await withPages(rig);
          await settle(t);
          await t.tap(find.text(en ? 'My Files' : 'আমার ফাইল').last);
          await settle(t);
          for (final k in ['store-search', 'store-room', 'store-notes', 'store-vault', 'store-docs', 'store-contacts', 'store-accounts', 'store-cards', 'store-expiry', 'store-tags', 'store-warn']) {
            expect(find.byKey(Key(k)), findsOneWidget, reason: k);
          }
          // Owner, 24 Nov: the ring's parts named, no bare percent.
          expect(find.text(en ? 'Room the app takes' : 'অ্যাপ যতটা জায়গা নিয়েছে'), findsOneWidget);
          expect(find.textContaining(en ? 'free on the phone' : 'ফোনে খালি আছে'), findsOneWidget);
          // The passport in the sample runs out in 12 days.
          expect(find.textContaining(en ? 'expires in 12 days' : '১২ দিন পর শেষ'), findsOneWidget);
          if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/store1120-$name.png'));
        });
      }
    }
  }

  testWidgets('20 Nov: a document shared from My Files, the list and its page', (t) async {
    final rig = await start(t);
    t.view.physicalSize = const Size(390 * 3, 1180 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await withPages(rig);
    await settle(t);
    await t.tap(find.text('আমার ফাইল').last);
    await settle(t);
    rig.brain.markVerified();

    // ⋮ on the latest card → শেয়ার: both pages go to the share sheet.
    final card = find.ancestor(of: find.text('পাসপোর্ট'), matching: find.byWidgetPredicate((w) => w.key is ValueKey<String> && (w.key as ValueKey<String>).value.startsWith('store-recent-')));
    await t.tap(find.descendant(of: card, matching: find.byIcon(Icons.more_vert_rounded)));
    await settle(t);
    await t.tap(find.text('শেয়ার').last);
    await settle(t);
    expect(rig.files.sharedFiles?.map((f) => f.name), ['passport-1.jpg', 'passport-2.jpg']);

    // The documents list: a share button on each row.
    rig.files.sharedFiles = null;
    await t.tap(find.byKey(const Key('store-docs')));
    await settle(t);
    final id = rig.brain.data.docs.single.id;
    await t.tap(find.byKey(Key('doc-share-$id')));
    await settle(t);
    expect(rig.files.sharedFiles, hasLength(2));

    // The document's own page.
    rig.files.sharedFiles = null;
    await t.tap(find.text('পাসপোর্ট').last);
    await settle(t);
    await t.tap(find.byKey(const Key('doc-share')));
    await settle(t);
    expect(rig.files.sharedFiles, hasLength(2));
  });
}
