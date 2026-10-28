import 'dart:typed_data';

import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/cards_screen.dart';
import 'package:digital_brain/screens/docs_screen.dart' show DocsScreen;
import 'package:digital_brain/services/files.dart' show PickedDoc;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show enterPin, settle, start;

void main() {
  test('card numbers: grouped, the network from the first digits, the Luhn check', () {
    expect(groupedNumber('4111111111111111'), '4111 1111 1111 1111');
    expect(BankCard(bank: 'x', number: '4111111111111111').network, 'VISA');
    expect(BankCard(bank: 'x', number: '5500000000000004').network, 'Mastercard');
    expect(BankCard(bank: 'x', number: '6200000000000005').network, 'UnionPay');
    expect(luhnOk('4111111111111111'), isTrue);
    expect(luhnOk('4111111111111112'), isFalse);
    final c = BankCard(bank: 'ডাচ-বাংলা ব্যাংক', kind: CardKind.credit, number: '4111111111111111', expiry: '08/29', color: 2);
    final back = BankCard.fromJson(c.toJson());
    expect((back.bank, back.kind, back.number, back.expiry, back.color, back.last4), ('ডাচ-বাংলা ব্যাংক', CardKind.credit, '4111111111111111', '08/29', 2, '1111'));
  });

  testWidgets('ডকুমেন্টস › ব্যাংক কার্ড (owner, 28 Oct): first folder; several cards with bank and kind; the list shows the last four; the PIN opens the whole number', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    await b.saveCard(BankCard(bank: 'ব্র্যাক ব্যাংক', kind: CardKind.debit, number: '4111111111111111', expiry: '08/29'));
    rig.files.photo = PickedDoc(Uint8List.fromList(List.filled(40, 7)), 'card.jpg', 'image/jpeg');
    // Documents: ব্যাংক কার্ড is the first folder.
    Navigator.of(t.element(find.byTooltip('বলুন'))).push(MaterialPageRoute(builder: (_) => const DocsScreen()));
    await settle(t);
    final grid = find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith('DragGrid'));
    expect(t.widget<Material>(find.descendant(of: grid, matching: find.byType(Material)).first).key, const Key('doc-cards'), reason: 'the very first folder');
    await t.tap(find.byKey(const Key('doc-cards')));
    await settle(t);
    // The list: bank, kind, only the last four digits.
    expect(find.text('ব্র্যাক ব্যাংক'), findsOneWidget);
    expect(find.text('ডেবিট'), findsOneWidget);
    expect(find.text('•••• •••• •••• 1111'), findsOneWidget);
    expect(find.textContaining('4111 1111'), findsNothing);
    // A second card: a credit card from its photo only.
    await t.tap(find.byKey(const Key('card-add')));
    await settle(t);
    await t.enterText(find.byKey(const Key('card-bank')), 'সিটি ব্যাংক');
    await t.tap(find.byKey(const Key('card-kind-credit')));
    // Typing: the gaps come by themselves, no more digits than the card has.
    await t.enterText(find.byKey(const Key('card-number-field')), '5555444433332222999');
    await t.pump();
    expect(t.widget<TextField>(find.byKey(const Key('card-number-field'))).controller!.text, '5555 4444 3333 2222');
    expect(find.text('Mastercard (নম্বর থেকে)'), findsOneWidget, reason: 'the company read from the number');
    await t.enterText(find.byKey(const Key('card-number-field')), '378282246310005777');
    await t.pump();
    expect(t.widget<TextField>(find.byKey(const Key('card-number-field'))).controller!.text, '3782 822463 10005', reason: 'AMEX: 15 digits, 4-6-5');
    await t.scrollUntilVisible(find.byKey(const Key('card-expiry')), 100, scrollable: find.descendant(of: find.byType(CardFormScreen), matching: find.byType(Scrollable)).first);
    await t.enterText(find.byKey(const Key('card-expiry')), '08299');
    await t.pump();
    expect(t.widget<TextField>(find.byKey(const Key('card-expiry'))).controller!.text, '08/29');
    await t.enterText(find.byKey(const Key('card-expiry')), '');
    await t.enterText(find.byKey(const Key('card-number-field')), '');
    await t.scrollUntilVisible(find.byKey(const Key('card-company-VISA')), 100, scrollable: find.descendant(of: find.byType(CardFormScreen), matching: find.byType(Scrollable)).first);
    await t.tap(find.byKey(const Key('card-company-VISA')));
    await t.pump();
    await t.scrollUntilVisible(find.byKey(const Key('card-front-camera')), 200, scrollable: find.descendant(of: find.byType(CardFormScreen), matching: find.byType(Scrollable)).first);
    await settle(t);
    await t.tap(find.byKey(const Key('card-front-camera')));
    await settle(t);
    await t.tap(find.byKey(const Key('card-save')));
    await settle(t);
    expect(b.data.cards, hasLength(2));
    final city = b.data.cards.firstWhere((c) => c.bank == 'সিটি ব্যাংক');
    expect((city.kind, city.number, city.front != null, city.company), (CardKind.credit, '', true, 'VISA'));
    expect(city.front!.text, '', reason: 'a card photo is never read for text (the number would be searchable)');
    expect(find.text('শুধু ছবি রাখা'), findsOneWidget);
    // Opening one asks for the PIN (a while after the last check), then the whole number shows on asking.
    rig.nowAt = rig.nowAt.add(const Duration(hours: 1));
    await t.tap(find.byKey(Key('card-${b.data.cards.firstWhere((c) => c.bank == 'ব্র্যাক ব্যাংক').id}')));
    await settle(t);
    await enterPin(t, '1234');
    await settle(t);
    expect(find.text('•••• •••• •••• 1111'), findsOneWidget);
    await t.tap(find.byKey(const Key('card-show')));
    await t.pump();
    expect(find.text('4111 1111 1111 1111'), findsOneWidget);
    await t.tap(find.byKey(const Key('card-copy')));
    await t.pump();
    expect(rig.files.copied, '4111111111111111');
    await t.pump(const Duration(seconds: 31));
    expect(find.text('4111 1111 1111 1111'), findsNothing, reason: 'hidden again after 30 seconds');
  });
}
