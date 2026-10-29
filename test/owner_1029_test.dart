import 'dart:convert';

import 'package:digital_brain/logic/ask.dart' show todayMetal;
import 'package:digital_brain/logic/money_more.dart' show GoldPiece, MetalPrice, ZakatSaved;
import 'package:digital_brain/logic/strings_en.dart';
import 'package:digital_brain/logic/zakat.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/zakat_principles.dart';
import 'package:digital_brain/screens/zakat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  final now = DateTime(2026, 10, 29, 10);
  const silver = 3000;

  test('principles: as renowned scholars advise — no school named (owner, 29 Oct)', () {
    for (final (t, r, a) in zakatPrinciples) {
      for (final x in [t, r, a]) {
        expect(x, isNot(contains('হানাফি')));
        expect(x, isNot(contains('মাজহাব')));
        expect(enStrings[x] ?? '', isNot(contains('Hanafi')));
      }
    }
    expect(zakatPrinciples.where((p) => p.$2.contains('প্রখ্যাত আলেমদের পরামর্শ অনুসারে')).length, 3);
  });

  test('gold of several carats and an "other" kind: each its own line at its own price', () {
    const s = ZakatSaved(silverPrice: silver, golds: [
      GoldPiece(id: 'a', carat: '22k', vori: 2, price: 205000),
      GoldPiece(id: 'b', carat: '18k', vori: 1.5, price: 167700),
      GoldPiece(id: 'c', carat: 'other', vori: 1, price: 120000, label: 'সোনার কয়েন'),
    ]);
    final lines = zakatLines(AppData(), now, s).where((l) => l.group == ZakatGroup.metal).toList();
    expect([for (final l in lines) (l.key, l.label, l.amount)], [
      ('gold:a', 'সোনা — ২২ ক্যারেট', 410000),
      ('gold:b', 'সোনা — ১৮ ক্যারেট', 251550),
      ('gold:c', 'সোনার কয়েন', 120000),
    ]);
    final z = zakatCount(zakatLines(AppData(), now, s), s);
    expect(z.gold, 781550);
    // 4.5 ভরি of gold alone: under the gold nisab (7.5 ভরি by weight), whatever its value.
    expect((z.byGold, z.due), (true, false));
  });

  test('only gold: the nisab is 7.5 ভরি by weight across carats', () {
    const s = ZakatSaved(silverPrice: silver, golds: [
      GoldPiece(id: 'a', carat: '22k', vori: 4, price: 200000),
      GoldPiece(id: 'b', carat: '18k', vori: 4, price: 160000),
    ]);
    final z = zakatCount(zakatLines(AppData(), now, s), s);
    expect((z.byGold, z.due), (true, true), reason: '8 ভরি of gold');
    expect(z.nisab, (1440000 / 8 * 7.5).round());
    // One of them left out: 4 ভরি — under the nisab.
    final d = AppData()..zakat.excluded.add('gold:b');
    expect(zakatCount(zakatLines(d, now, s), s).due, isFalse);
  });

  test('gold written the old way is one 22-carat piece, still the "gold" line', () {
    const old = ZakatSaved(goldVori: 3, goldPrice: 200000, silverPrice: silver);
    expect([for (final g in old.pieces) (g.key, g.carat, g.vori, g.price)], [('gold', '22k', 3.0, 200000)]);
    final l = zakatLines(AppData(), now, old).firstWhere((l) => l.group == ZakatGroup.metal);
    expect((l.key, l.amount), ('gold', 600000));
  });

  test('today\'s price fills each piece at its carat; "other" keeps its own', () {
    final p = MetalPrice(date: now, gold: const {'22k': 205000, '18k': 167700}, silver: const {'22k': 3965});
    const s = ZakatSaved(golds: [GoldPiece(id: 'a', carat: '18k', vori: 1, price: 0), GoldPiece(id: 'c', carat: 'other', vori: 1, price: 90000)]);
    final w = s.withPrices(p);
    expect([for (final g in w.pieces) g.price], [167700, 90000]);
    expect((w.goldPrice, w.silverPrice), (205000, 3965));
  });

  testWidgets('the page: add 22 and 18 carat and an "other" gold, change one, delete one', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    todayMetal = MetalPrice(date: now, gold: const {'22k': 205000, '21k': 195700, '18k': 167700, 'traditional': 139400}, silver: const {'22k': 3965});
    Navigator.of(t.element(find.byTooltip('বলুন'))).push(MaterialPageRoute(builder: (_) => const ZakatScreen()));
    await settle(t);
    Future<void> show(Finder f) async {
      await t.scrollUntilVisible(f, 200, scrollable: find.descendant(of: find.byType(ZakatScreen), matching: find.byType(Scrollable)).first);
      await t.pump();
    }

    Future<void> add(String carat, String vori, {String? price, String? label}) async {
      await show(find.byKey(const Key('zakat-gold-add')));
      await t.tap(find.byKey(const Key('zakat-gold-add')));
      await settle(t);
      await t.tap(find.byKey(Key('zakat-gold-carat-$carat')));
      await settle(t);
      if (label != null) await t.enterText(find.byKey(const Key('zakat-gold-label')), label);
      await t.enterText(find.byKey(const Key('zakat-gold-vori')), vori);
      if (price != null) await t.enterText(find.byKey(const Key('zakat-gold-price')), price);
      await t.pump();
      await t.tap(find.byKey(const Key('zakat-gold-save')));
      await settle(t);
    }

    await add('22k', '2');
    await add('18k', '১.৫');
    // "অন্যান্য": no বাজুস price — saving waits for one.
    await show(find.byKey(const Key('zakat-gold-add')));
    await t.tap(find.byKey(const Key('zakat-gold-add')));
    await settle(t);
    await t.tap(find.byKey(const Key('zakat-gold-carat-other')));
    await settle(t);
    await t.enterText(find.byKey(const Key('zakat-gold-vori')), '1');
    await t.pump();
    expect(t.widget<FilledButton>(find.byKey(const Key('zakat-gold-save'))).onPressed, isNull);
    await t.tap(find.text('বাতিল'));
    await settle(t);
    await add('other', '1', price: '120000', label: 'সোনার কয়েন');

    var g = b.zakatSaved.pieces;
    expect([for (final x in g) (x.carat, x.vori, x.price, x.label)], [('22k', 2.0, 205000, ''), ('18k', 1.5, 167700, ''), ('other', 1.0, 120000, 'সোনার কয়েন')]);
    expect(find.text('সোনা — ১৮ ক্যারেট'), findsOneWidget);
    expect(find.text('সোনার কয়েন'), findsWidgets);
    // Kept as a list on the phone.
    expect((jsonDecode(b.prefs['zakat_gold_list']!) as List).length, 3);

    // Change the 18-carat one to 2 ভরি.
    await show(find.byKey(Key('zakat-gold-${g[1].key}')));
    await t.tap(find.byKey(Key('zakat-gold-${g[1].key}')));
    await settle(t);
    await t.enterText(find.byKey(const Key('zakat-gold-vori')), '2');
    await t.pump();
    await t.tap(find.byKey(const Key('zakat-gold-save')));
    await settle(t);
    expect(b.zakatSaved.pieces[1].vori, 2.0);
    expect(b.zakatSaved.pieces[1].key, g[1].key);

    // Delete the coin.
    g = b.zakatSaved.pieces;
    await show(find.byKey(Key('zakat-gold-del-${g[2].key}')));
    await t.tap(find.byKey(Key('zakat-gold-del-${g[2].key}')));
    await settle(t);
    expect(b.zakatSaved.pieces.length, 2);
    final z = zakatCount(zakatLines(b.data, b.services.now(), b.zakatSaved), b.zakatSaved);
    expect(z.gold, 2 * 205000 + 2 * 167700);
  });

  testWidgets('gold kept the old way shows as one piece and becomes a list when changed', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.setZakatValue('gold_vori', '3');
    await b.setZakatValue('gold_price', '200000');
    expect([for (final x in b.zakatSaved.pieces) (x.key, x.vori, x.price)], [('gold', 3.0, 200000)]);
    await b.useMetalPrice(MetalPrice(date: now, gold: const {'22k': 205000, '18k': 167700}, silver: const {'22k': 3965}));
    expect(b.zakatSaved.goldPrice, 205000);
    expect(b.zakatSaved.pieces.single.price, 205000, reason: 'the old piece is 22 carat unless chosen otherwise');
    expect(b.zakatSaved.pieces.single.key, 'gold', reason: 'a line left out before stays left out');
  });
}
