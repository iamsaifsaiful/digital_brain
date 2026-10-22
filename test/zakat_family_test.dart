import 'dart:convert';

import 'package:digital_brain/logic/money_more.dart' show ZakatSaved, zakatAuto;
import 'package:digital_brain/logic/zakat.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/family_screen.dart';
import 'package:digital_brain/screens/requests_screen.dart' show AskBloodScreen;
import 'package:digital_brain/screens/zakat_screen.dart';
import 'package:digital_brain/services/crypto.dart' show WrongKey, randomBytes;
import 'package:digital_brain/services/family_crypto.dart';
import 'package:digital_brain/services/google_account.dart';
import 'package:digital_brain/state/family_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'app_test.dart' show Rig, settle, start;

void main() {
  final now = DateTime(2026, 10, 22, 10);

  AppData sample() {
    final bkash = MoneyAccount(name: 'বিকাশ', kind: AccountKind.bkash, opening: 5000);
    final bank = MoneyAccount(name: 'ডাচ-বাংলা', kind: AccountKind.bank, opening: 200000);
    return AppData(
      accounts: [bkash, bank],
      cash: [CashEntry(kind: CashKind.expense, amount: 1000, category: 'বাজার', date: DateTime(2026, 10, 20), accountId: bkash.id)],
      ledger: [
        LedgerEntry(person: 'রহিম', amount: 30000, kind: LedgerKind.lent, date: DateTime(2026, 9, 1)),
        LedgerEntry(person: 'রহিম', amount: 10000, kind: LedgerKind.received, date: DateTime(2026, 10, 1)),
        LedgerEntry(person: 'করিম', amount: 15000, kind: LedgerKind.borrowed, date: DateTime(2026, 8, 5)),
      ],
      goals: [SavingsGoal(name: 'হজ', target: 500000, deposits: [GoalDeposit(40000, DateTime(2026, 7, 1))])],
      installments: [Installment(name: 'বাড়ির লোন', kind: InstallmentKind.loan, amount: 8000, months: 24, start: DateTime(2026, 1, 1))],
    );
  }

  const saved = ZakatSaved(goldVori: 2, goldPrice: 200000, silverPrice: 3000);

  test('zakat: every line from the records, with where it came from and when; excluded and hand-added lines count right', () {
    final d = sample();
    final lines = zakatLines(d, now, saved);
    ZakatLine line(String prefix) => lines.firstWhere((l) => l.key.startsWith(prefix));
    expect(line('account:').amount, 4000, reason: 'bKash: 5000 − 1000');
    expect(line('account:').group, ZakatGroup.cash);
    expect(line('account:').at, DateTime(2026, 10, 20));
    expect(lines.where((l) => l.group == ZakatGroup.bank).single.amount, 200000);
    expect(line('goal:').amount, 40000);
    expect(line('person:').amount, 20000);
    expect(line('person:').how, contains('৩০,০০০'));
    expect(line('owe:').debt, isTrue);
    expect(line('loan:').amount, 12 * 8000);
    expect(line('gold').amount, 400000);
    var z = zakatCount(lines, saved);
    expect(z.wealth, 4000 + 200000 + 40000 + 20000 + 400000);
    expect(z.debts, 15000 + 96000);
    expect(z.nisab, 157500);
    expect(z.zakat, ((z.wealth - z.debts) * 0.025).round());
    expect(zakatAuto(d, now, saved).zakat, z.zakat, reason: 'the voice answer uses the same count');

    // Gold left out, a land advance added by hand.
    d.zakat.excluded.add('gold');
    d.zakat.items.add(ZakatItem(label: 'জমির বায়না', amount: 100000, date: now));
    z = zakatCount(zakatLines(d, now, saved), saved);
    expect(z.wealth, 4000 + 200000 + 40000 + 20000 + 100000);
    expect(zakatLines(d, now, saved).firstWhere((l) => l.key == 'gold').included, isFalse, reason: 'still shown, unticked');
    // Kept with the data (backups too).
    final back = AppData.fromJson(jsonDecode(jsonEncode(d.toJson())) as Map<String, Object?>);
    expect(back.zakat.excluded, {'gold'});
    expect(back.zakat.items.single.label, 'জমির বায়না');
  });

  test('zakat day: a lunar year (354 days) after the start, moved on until today or later', () {
    expect(zakatDueDay(null, now), isNull);
    expect(zakatDueDay(DateTime(2026, 3, 1), now), DateTime(2027, 2, 18));
    expect(zakatDueDay(DateTime(2025, 1, 10), now), DateTime(2026, 12, 19));
  });

  testWidgets('যাকাত page: lines with their source; untick one and the total changes; add one by hand', (t) async {
    final rig = await start(t);
    final b = rig.brain;
    b.data = sample();
    await b.setZakatValue('silver_price', '3000');
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const ZakatScreen()));
    await settle(t);
    final before = t.widget<Text>(find.byKey(const Key('zakat-total'))).data;
    final countBefore = zakatCount(zakatLines(b.data, b.services.now(), b.zakatSaved), b.zakatSaved).net;
    expect(find.text('পাওনা টাকা'), findsOneWidget);
    final rahim = find.byKey(Key('zakat-line-person:${zakatLines(b.data, b.services.now(), b.zakatSaved).firstWhere((l) => l.key.startsWith('person:')).key.substring(7)}'));
    await t.scrollUntilVisible(rahim, 200, scrollable: find.byType(Scrollable).last);
    await settle(t);
    await t.tap(find.descendant(of: rahim, matching: find.byType(Checkbox)));
    await settle(t);
    expect(b.data.zakat.excluded.any((k) => k.startsWith('person:')), isTrue);
    expect(zakatCount(zakatLines(b.data, b.services.now(), b.zakatSaved), b.zakatSaved).net, countBefore - 20000);
    expect(before, contains('যাকাত'));
    await t.ensureVisible(find.byKey(const Key('zakat-add')));
    await t.tap(find.byKey(const Key('zakat-add')));
    await settle(t);
    await t.enterText(find.byKey(const Key('zakat-item-label')), 'প্রাইজবন্ড');
    await t.enterText(find.byKey(const Key('zakat-item-amount')), '৫০০০০');
    await t.tap(find.byKey(const Key('zakat-item-save')));
    await settle(t);
    expect(b.data.zakat.items.single.amount, 50000);
  });

  group('family sealing', () {
    test('only the intended phone opens what was sealed for it', () async {
      final mom = await FamilyKeys.generate(), son = await FamilyKeys.generate();
      final sealed = await sealJsonFor({'title': 'প্রেশারের ওষুধ', 'times': [480]}, son.publicB64);
      expect(utf8.decode(base64Decode(sealed), allowMalformed: true), isNot(contains('প্রেশার')));
      expect((await openJson(sealed, son))['title'], 'প্রেশারের ওষুধ');
      await expectLater(openJson(sealed, mom), throwsA(isA<WrongKey>()));
      // Same seed → same keys (the phone keeps only the seed).
      expect((await FamilyKeys.fromSeed(son.seed)).publicB64, son.publicB64);
    });

    test('the heirs\' copy: one blob, a key per heir', () async {
      final heir = await FamilyKeys.generate(), other = await FamilyKeys.generate();
      final (blob, keys) = await sealPackage({'notes': [{'title': 'জমির দলিল আলমারিতে'}]}, {7: heir.publicB64});
      expect(keys.keys, ['7']);
      final opened = await openSealedPackage(blob, keys['7']!, heir);
      expect((opened['notes'] as List).single['title'], 'জমির দলিল আলমারিতে');
      await expectLater(openSealedPackage(blob, keys['7']!, other), throwsA(isA<WrongKey>()));
    });

    test('a place sealed with the location key opens with it (the Android side makes the same bytes)', () async {
      final key = randomBytes(32);
      final s = await sealPlace({'lat': 23.81, 'lon': 90.41, 'acc': 12}, key);
      final raw = base64Decode(s);
      expect(raw.length, greaterThan(12 + 16), reason: 'nonce 12 + text + tag 16');
      expect((await openPlace(s, key))['lat'], 23.81);
    });
  });

  group('family on the phone', () {
    test('items from family: opened, added as this phone\'s own, then cleared from the server', () async {
      final calls = <http.Request>[];
      late Rig rig;
      final items = <Map<String, Object?>>[];
      final client = MockClient((r) async {
        calls.add(r);
        final p = r.url.path;
        Object body = {'ok': true};
        if (p.endsWith('/family') && r.method == 'GET') {
          final k = await rig.brain.family.keys();
          body = {'pro': true, 'my_key': k.publicB64, 'links': [], 'items': items.length, 'claims_on_me': []};
        } else if (p.endsWith('/family/items') && r.method == 'GET') {
          body = {'items': items};
        }
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      });
      rig = Rig(server: AccountServer(client, 'https://example.test'));
      rig.services.ai.session = 's' * 64;
      final me = await rig.brain.family.keys();
      items.addAll([
        {'id': 1, 'link': 5, 'kind': 'medicine', 'sealed': await sealJsonFor({'title': 'নাপা', 'times': [480, 1260], 'dose': 1, 'from': 'আম্মা'}, me.publicB64)},
        {'id': 2, 'link': 5, 'kind': 'task', 'sealed': await sealJsonFor({'title': 'বিদ্যুৎ বিল দেওয়া', 'date': '2026-10-25', 'from': 'আম্মা'}, me.publicB64)},
        {'id': 3, 'link': 5, 'kind': 'lockey', 'sealed': await sealJsonFor({'key': base64Encode(randomBytes(32))}, me.publicB64)},
        {'id': 4, 'link': 5, 'kind': 'task', 'sealed': await sealJsonFor({'title': 'অন্য ফোনের জন্য'}, (await FamilyKeys.generate()).publicB64)},
      ]);
      final n = await rig.brain.family.receive();
      expect(n, 2);
      expect(rig.brain.data.medicines.single.name, 'নাপা');
      expect(rig.brain.data.medicines.single.times, [480, 1260]);
      expect(rig.brain.data.tasks.single.title, 'বিদ্যুৎ বিল দেওয়া');
      expect(rig.brain.data.tasks.single.note, contains('আম্মা'));
      final ack = calls.lastWhere((r) => r.url.path.endsWith('/family/items/ack'));
      expect((jsonDecode(ack.body) as Map)['ids'], [1, 2, 3, 4], reason: 'all cleared, also what could not be opened');
      expect(await rig.services.lock.keys.read('fam_lockey_5'), isNotNull, reason: 'the location key is kept for asking where they are');
    });

    test('sending: sealed for their phone; the heirs\' copy keyed by family link, holding only the chosen parts', () async {
      final calls = <http.Request>[];
      final son = await FamilyKeys.generate();
      late Rig rig;
      final client = MockClient((r) async {
        calls.add(r);
        Object body = {'ok': true};
        if (r.url.path.endsWith('/family') && r.method == 'GET') {
          final k = await rig.brain.family.keys();
          body = {
            'pro': true,
            'my_key': k.publicB64,
            'links': [
              {'id': 9, 'status': 'active', 'name': 'রাফি', 'email': 'son@gmail.com', 'i_call': 'ছেলে', 'they_call': 'আম্মা', 'i_allow': [], 'they_allow': ['task'], 'they_are_my_heir': true, 'their_key': son.publicB64},
            ],
            'claims_on_me': [],
          };
        }
        if (r.url.path.endsWith('/family/items') && r.method == 'GET') body = {'items': []};
        return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
      });
      rig = Rig(server: AccountServer(client, 'https://example.test'));
      rig.services.ai.session = 's' * 64;
      rig.brain.data = AppData(notes: [Note(title: 'দলিল আলমারিতে')], vault: [VaultItem(name: 'ব্যাংক', password: 'গোপন১২৩')]);
      await rig.brain.family.refresh();
      final pkg = calls.lastWhere((r) => r.url.path.endsWith('/family/package'));
      final body = jsonDecode(pkg.body) as Map<String, dynamic>;
      expect((body['keys'] as Map).keys, ['9']);
      final opened = await openSealedPackage('${body['blob']}', '${(body['keys'] as Map)['9']}', son);
      expect((opened['notes'] as List).single['title'], 'দলিল আলমারিতে');
      expect(opened.containsKey('vault'), isFalse, reason: 'passwords only when the member ticks them');
      expect(pkg.body, isNot(contains('গোপন')));

      final l = rig.brain.family.links.single;
      expect(await rig.brain.family.send(l, 'task', {'title': 'ওষুধ আনতে হবে'}), isTrue);
      final sent = jsonDecode(calls.lastWhere((r) => r.url.path.endsWith('/family/items') && r.method == 'POST').body) as Map;
      expect(sent['kind'], 'task');
      expect((await openJson('${sent['sealed']}', son))['title'], 'ওষুধ আনতে হবে');
      expect((await openJson('${sent['sealed']}', son))['from'], 'আম্মা');
    });
  });

  testWidgets('ফ্যামিলি page: not signed in → asks to sign in; the permission list is there to choose from', (t) async {
    await start(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const FamilyScreen()));
    await settle(t);
    expect(find.textContaining('Google দিয়ে লগইন করুন'), findsOneWidget);
    expect(familyPerms, containsAll(['task', 'reminder', 'medicine', 'note', 'location']));
    expect(heirPartsDefault, isNot(contains('vault')));
    expect(heirPartsDefault, isNot(contains('health')));
  });

  testWidgets('রক্ত চাই: for whom, the problem and the hospital are needed; where it is and the date go too', (t) async {
    final calls = <http.Request>[];
    final rig = await start(t,
        server: AccountServer(
            MockClient((r) async {
              calls.add(r);
              return http.Response.bytes(utf8.encode(jsonEncode({'ok': true, 'id': 1, 'notified': 3})), 200);
            }),
            'https://example.test'));
    rig.services.ai.session = 's' * 64;
    t.view.physicalSize = const Size(1170, 7000); // the whole form at once
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const AskBloodScreen(phone: '01712345678')));
    await settle(t);
    await t.tap(find.byKey(const Key('ask-B+')));
    await settle(t);
    final send = find.byKey(const Key('ask-send'));
    await t.ensureVisible(send);
    await t.tap(send);
    await settle(t);
    expect(find.text('কার জন্যে, রোগীর সমস্যা আর হাসপাতালের নাম দিন'), findsOneWidget);
    expect(calls.where((r) => r.url.path.endsWith('/blood/requests')), isEmpty);
    await t.enterText(find.byKey(const Key('ask-patient')), 'আমার মা');
    await t.enterText(find.byKey(const Key('ask-problem')), 'অপারেশন');
    await t.enterText(find.byKey(const Key('ask-hospital')), 'রাজশাহী মেডিকেল');
    await t.enterText(find.byKey(const Key('ask-location')), 'লক্ষ্মীপুর, ওয়ার্ড ৫');
    await t.ensureVisible(send);
    await t.tap(send);
    await settle(t);
    final body = jsonDecode(calls.singleWhere((r) => r.url.path.endsWith('/blood/requests')).body) as Map;
    expect([body['patient'], body['problem'], body['hospital'], body['location'], body['blood'], body['phone']], ['আমার মা', 'অপারেশন', 'রাজশাহী মেডিকেল', 'লক্ষ্মীপুর, ওয়ার্ড ৫', 'B+', '01712345678']);
    expect(body['need_by'], isNotNull);
  });
}
