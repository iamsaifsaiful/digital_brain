// আমার ফাইল › ব্যাংক একাউন্ট (owner, 20 Nov): add an account, see only the
// last four in the list, share it to other apps, open it with copy and
// share. With SHOTS=1 --update-goldens: test/ui/shots/accounts1120-*.png.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_test.dart' show settle, start;
import 'home_final_shots_test.dart' show icons, shots;

void main() {
  testWidgets('20 Nov ব্যাংক একাউন্ট: add, list, share, open', (t) async {
    final rig = await start(t);
    t.view.physicalSize = const Size(390 * 3, 860 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await settle(t);
    await t.tap(find.text('আমার ফাইল').last);
    await settle(t);
    await t.tap(find.byKey(const Key('store-accounts')));
    await settle(t);
    await t.tap(find.byKey(const Key('acct-add')));
    await settle(t);
    await t.enterText(find.byKey(const Key('acct-bank')), 'ব্র্যাক ব্যাংক');
    await t.enterText(find.byKey(const Key('acct-name')), 'Rahim Uddin');
    await t.enterText(find.byKey(const Key('acct-number')), '1501 2034 5678 9001');
    await t.tap(find.text('সঞ্চয়ী'));
    await t.tap(find.byKey(const Key('acct-save')));
    await settle(t);
    final a = rig.brain.data.bankAccounts.single;
    expect((a.bank, a.name, a.number, a.kind), ('ব্র্যাক ব্যাংক', 'Rahim Uddin', '1501203456789001', 'সঞ্চয়ী'));
    // The list shows only the last four.
    expect(find.textContaining('•••• ৯০০১'), findsOneWidget);
    expect(find.textContaining('1501203456789001'), findsNothing);

    rig.brain.markVerified();
    await t.tap(find.byKey(Key('acct-share-${a.id}')));
    await settle(t);
    expect(rig.files.sharedText, contains('1501203456789001'));
    expect(rig.files.sharedText, contains('Rahim Uddin'));

    await t.tap(find.byKey(Key('acct-${a.id}')));
    await settle(t);
    expect(find.text('1501203456789001'), findsOneWidget);
    rig.files.sharedText = null;
    await t.tap(find.byKey(const Key('acct-share')));
    await settle(t);
    expect(rig.files.sharedText, startsWith('ব্র্যাক ব্যাংক'));
  });

  for (final look in [Look.light, Look.dark]) {
    for (final en in [false, true]) {
      testWidgets('ব্যাংক একাউন্ট shots, ${look.name}, ${en ? 'en' : 'bn'}', (t) async {
        if (shots) await icons();
        final rig = await start(t);
        t.view.physicalSize = const Size(390 * 3, 760 * 3);
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        await rig.brain.setLook(look);
        if (en) await rig.brain.setEnglish(true);
        for (final a in [
          BankAccount(bank: 'ব্র্যাক ব্যাংক', name: 'Rahim Uddin', number: '1501203456789001', kind: 'সঞ্চয়ী', branch: 'গুলশান'),
          BankAccount(bank: 'ডাচ-বাংলা ব্যাংক', name: 'Rahim Uddin', number: '1171510012345', kind: 'বেতন'),
          BankAccount(bank: 'ইসলামী ব্যাংক', name: 'Rahim Traders', number: '20501770100045612', kind: 'চলতি'),
        ]) {
          await rig.brain.saveBankAccount(a);
        }
        await settle(t);
        await t.tap(find.text(en ? 'My Files' : 'আমার ফাইল').last);
        await settle(t);
        await t.tap(find.byKey(const Key('store-accounts')));
        await settle(t);
        final tag = '${look.name}-${en ? 'en' : 'bn'}';
        if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/accounts1120-list-$tag.png'));
        rig.brain.markVerified();
        await t.tap(find.byKey(Key('acct-${rig.brain.data.bankAccounts.first.id}')));
        await settle(t);
        if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/accounts1120-open-$tag.png'));
      });
    }
  }
}
