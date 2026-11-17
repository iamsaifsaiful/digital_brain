// উত্তরাধিকারীর কপি (owner, 17 Nov): a glance, each part on its own page,
// PDF, and a backup with no password plus how to open it.
// SHOTS=1 --update-goldens writes test/ui/shots/heir_1117/*.png.
import 'dart:io';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/family_screen.dart' show HeirViewScreen;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';

import 'tutorial_shots_test.dart' show rig0;
import '../app_test.dart' show settle;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> shot(WidgetTester t, String n) async {
  if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/heir_1117/$n.png'));
}

void main() {
  testWidgets('heir copy: glance, a part, backup help', (t) async {
    final rig = await rig0(t);
    rig.brain.googleEmail = 'rafi@gmail.com';
    await rig.brain.services.lock.keys.write('drive_pw', 'k' * 48);
    await rig.brain.services.lock.keys.write('drive_key_server', 'true');
    final names = ['করিম', 'রহিম', 'মামুন', 'সজীব', 'জামাল', 'নাসির', 'হাবিব', 'রফিক'];
    final data = AppData(
      contacts: [for (var i = 0; i < 1100; i++) Contact(name: '${names[i % 8]} ${i ~/ 8 + 1}', phone: '0171${i.toString().padLeft(7, '0')}')],
      ledger: [
        for (var i = 0; i < 46; i++) LedgerEntry(person: '${names[i % 8]} ${i ~/ 8 + 1}', amount: 500 * (i + 1), kind: i % 3 == 0 ? LedgerKind.borrowed : LedgerKind.lent, date: DateTime(2026, 9, 1 + i % 28)),
      ],
      cash: [for (var i = 0; i < 320; i++) CashEntry(kind: i % 5 == 0 ? CashKind.income : CashKind.expense, amount: 200 + i * 7, category: i % 5 == 0 ? 'বেতন' : 'বাজার', date: DateTime(2026, 10, 1 + i % 24))],
      notes: [Note(title: 'জমির দলিল', body: 'আলমারির ওপরের তাকে'), Note(title: 'ব্যাংকের লকার', body: 'চাবি আম্মার কাছে')],
      docs: [Doc(title: 'জাতীয় পরিচয়পত্র'), Doc(title: 'জমির দলিল'), Doc(title: 'পাসপোর্ট')],
    ).toJson()
      ..['parts'] = ['money', 'docs', 'notes', 'contacts', 'vault']
      ..['files_key'] = ''
      ..['at'] = '2026-11-10T10:00:00Z';
    await t.tap(find.text('আরও').last);
    await settle(t);
    Navigator.of(t.element(find.text('আরও').last)).push(MaterialPageRoute(builder: (_) => HeirViewScreen(title: 'আব্বার তথ্য', data: Map<String, dynamic>.from(data))));
    await settle(t);
    await shot(t, '1-glance');
    await t.tap(find.byKey(const Key('heir-part-ledger')));
    await settle(t);
    await shot(t, '2-ledger');
    await t.tap(find.byTooltip('ফিরে যান').first);
    await settle(t);
    await t.tap(find.byKey(const Key('heir-backup')));
    await settle(t);
    expect(find.byKey(const Key('heir-backup-help')), findsOneWidget);
    await shot(t, '3-backup-help');
    debugDisableShadows = true;
  });
}
