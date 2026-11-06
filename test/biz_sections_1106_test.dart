// Owner, 6 Nov: "স্টক পণ্যের ধরণের ভিত্তিতে বিভিন্ন সেকশনে ভাগ করা দরকার।"
import 'package:digital_brain/logic/shop_logic.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/biz/biz_stock.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/state/brain.dart' show BrainShop;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show settle, start;

void main() {
  test('a product finds its section from its name', () {
    expect(guessSection('মিনিকেট চাল'), 'চাল-ডাল-আটা');
    expect(guessSection('মসুর ডাল'), 'চাল-ডাল-আটা');
    expect(guessSection('সয়াবিন তেল ১ লি.'), 'তেল-মসলা');
    expect(guessSection('চিনি'), 'তেল-মসলা');
    expect(guessSection('ডিম'), 'ডিম-দুধ');
    expect(guessSection('দুধ ৫০০ মি.লি.'), 'ডিম-দুধ');
    expect(guessSection('লাক্স সাবান'), 'সাবান-প্রসাধনী');
    expect(guessSection('হুইল পাউডার'), 'ঘর-পরিষ্কার');
    expect(guessSection('পটেটো চিপস'), 'বিস্কুট-নাস্তা');
    expect(guessSection('মিনারেল পানি'), 'পানীয়');
    expect(guessSection('Rice 5kg'), 'চাল-ডাল-আটা');
    expect(guessSection('ঝাড়ু'), 'ঘর-পরিষ্কার');
    expect(guessSection('জাদুর বাক্স'), isNull);
    // "চা" is tea, but "চাদর" and "চানাচুর" are not.
    expect(guessSection('চানাচুর'), 'বিস্কুট-নাস্তা');
  });

  test('sections: a chosen one wins, the known ones in order, অন্যান্য last', () {
    final ps = [
      Product(name: 'জাদুর বাক্স'),
      Product(name: 'লাক্স সাবান'),
      Product(name: 'মসুর ডাল'),
      Product(name: 'ডিম', category: 'আমার তাক'),
      Product(name: 'সয়াবিন তেল'),
    ];
    expect(shelves(ps).map((x) => x.$1).toList(), ['চাল-ডাল-আটা', 'তেল-মসলা', 'সাবান-প্রসাধনী', 'আমার তাক', 'অন্যান্য']);
    // The first week's shelf names join the new sections; "অন্যান্য" picked by hand still lets the name decide.
    expect(sectionOf(Product(name: 'x', category: 'চাল-ডাল')), 'চাল-ডাল-আটা');
    expect(sectionOf(Product(name: 'ডিম', category: 'অন্যান্য')), 'ডিম-দুধ');
  });

  testWidgets('stock: section chips filter; the form picks the section from the name', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.setPref('business_mode', true);
    for (final n in ['মিনিকেট চাল', 'মসুর ডাল', 'সয়াবিন তেল', 'ডিম', 'লাক্স সাবান']) {
      await b.saveProduct(Product(name: n, stock: 10, sell: 50));
    }
    await settle(t);
    await t.tap(find.text('স্টক').last);
    await settle(t);
    for (final s in ['চাল-ডাল-আটা', 'তেল-মসলা', 'ডিম-দুধ', 'সাবান-প্রসাধনী']) {
      expect(find.byKey(Key('biz-section-$s')), findsOneWidget, reason: s);
    }
    await t.tap(find.byKey(const Key('biz-section-chip-চাল-ডাল-আটা')));
    await settle(t);
    expect(find.byKey(const Key('biz-section-চাল-ডাল-আটা')), findsOneWidget);
    expect(find.byKey(const Key('biz-section-ডিম-দুধ')), findsNothing);
    expect(find.text('মসুর ডাল'), findsOneWidget);
    expect(find.text('ডিম'), findsNothing);
    await t.tap(find.byKey(const Key('biz-section-chip-')));
    await settle(t);
    expect(find.byKey(const Key('biz-section-ডিম-দুধ')), findsOneWidget);

    Navigator.of(t.element(find.byType(HomeShell))).push(MaterialPageRoute(builder: (_) => const ProductForm()));
    await settle(t);
    await t.enterText(find.byKey(const Key('biz-product-name')), 'হুইল পাউডার');
    await settle(t);
    await t.scrollUntilVisible(find.byKey(const Key('biz-product-shelf')), 200, scrollable: find.byType(Scrollable).first);
    await settle(t);
    expect(find.text('ঘর-পরিষ্কার'), findsWidgets);
    expect(t.widget<TextField>(find.byKey(const Key('biz-product-shelf'))).controller!.text, 'ঘর-পরিষ্কার');
    // Picked by hand: the name no longer moves it.
    await t.ensureVisible(find.byKey(const Key('biz-shelf-সাবান-প্রসাধনী')));
    await t.tap(find.byKey(const Key('biz-shelf-সাবান-প্রসাধনী')));
    await settle(t);
    await t.scrollUntilVisible(find.byKey(const Key('biz-product-name')), -200, scrollable: find.byType(Scrollable).first);
    await t.enterText(find.byKey(const Key('biz-product-name')), 'হুইল সাবান');
    await t.ensureVisible(find.byKey(const Key('biz-product-save')));
    await t.tap(find.byKey(const Key('biz-product-save')));
    await settle(t);
    expect(b.shop.products.firstWhere((p) => p.name == 'হুইল সাবান').category, 'সাবান-প্রসাধনী');
  });
}
