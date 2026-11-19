// Owner, 19 Nov: "পরিবার বা উত্তরাধিকার থেকে ওষুধের রিমাইন্ডার দেওয়ার অপশন
// থাকা দরকার" — in the Play app too. From a family member's page (or from
// "কার জন্য" on the medicine reminder form) the reminder goes to their own
// phone; in the Play app it arrives as daily reminders, no medicine record.
// SHOTS=1 --update-goldens writes test/ui/shots/family_med_1119/*.png.
import 'dart:convert';
import 'dart:io';

import 'package:digital_brain/logic/pro.dart' show medicalOffForTests;
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/screens/family_screen.dart';
import 'package:digital_brain/screens/new_item_screen.dart';
import 'package:digital_brain/services/family_crypto.dart';
import 'package:digital_brain/services/google_account.dart';
import 'package:digital_brain/state/family_state.dart';
import 'package:digital_brain/ui/theme.dart' show Look;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../app_test.dart' show Rig, settle, start;
import 'home_final_shots_test.dart' show icons;

final shots = Platform.environment['SHOTS'] == '1';

Future<void> shot(WidgetTester t, String name) async {
  if (shots) await expectLater(find.byType(MaterialApp), matchesGoldenFile('shots/family_med_1119/$name.png'));
}

/// A phone linked with আম্মা, who lets this phone set her medicine reminders.
Future<(Rig, List<http.Request>, FamilyKeys)> linked(WidgetTester t, {List<String> allow = const ['task', 'reminder', 'medicine', 'note']}) async {
  if (shots) {
    await icons();
    debugDisableShadows = false;
  }
  final calls = <http.Request>[];
  final amma = await t.runAsync(FamilyKeys.generate);
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
          {'id': 9, 'status': 'active', 'name': 'রাশিদা', 'email': 'amma@gmail.com', 'i_call': 'আম্মা', 'they_call': 'বাবু', 'i_allow': [], 'they_allow': allow, 'i_am_their_heir': true, 'their_key': amma!.publicB64},
        ],
        'claims_on_me': [],
      };
    }
    if (r.url.path.endsWith('/family/items') && r.method == 'GET') body = {'items': []};
    return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
  });
  rig = await start(t, server: AccountServer(client, 'https://example.test'));
  rig.nowAt = DateTime(2026, 11, 19, 10, 15);
  await rig.brain.setLook(Look.light);
  rig.services.ai.session = 's' * 64;
  await t.runAsync(rig.brain.family.refresh);
  await settle(t);
  return (rig, calls, amma!);
}

Future<Map<String, dynamic>> lastSent(WidgetTester t, List<http.Request> calls, FamilyKeys to) async {
  final r = calls.lastWhere((r) => r.url.path.endsWith('/family/items') && r.method == 'POST');
  final body = jsonDecode(r.body) as Map;
  expect(body['kind'], 'medicine');
  return (await t.runAsync(() => openJson('${body['sealed']}', to)))!;
}

void main() {
  tearDown(() => medicalOffForTests = false);

  test('the Play app lets family set medicine reminders too', () {
    medicalOffForTests = true;
    expect(familyPerms, contains('medicine'));
  });

  test('received in the Play app: daily reminders, from whom, before/after food, why — no medicine kept', () async {
    medicalOffForTests = true;
    late Rig rig;
    final items = <Map<String, Object?>>[];
    rig = Rig(
        server: AccountServer(
            MockClient((r) async => http.Response.bytes(
                utf8.encode(jsonEncode(r.url.path.endsWith('/family/items') && r.method == 'GET' ? {'items': items} : {'ok': true})), 200)),
            'https://example.test'));
    rig.services.ai.session = 's' * 64;
    final me = await rig.brain.family.keys();
    items.add({
      'id': 1,
      'link': 5,
      'kind': 'medicine',
      'sealed': await sealJsonFor({'title': 'নাপা', 'times': [540, 1260], 'dose': 2, 'meal': 'after', 'why': 'জ্বরের জন্য', 'from': 'বাবু'}, me.publicB64),
    });
    expect(await rig.brain.family.receive(), 1);
    expect(rig.brain.data.medicines, isEmpty);
    final rs = rig.brain.data.reminders;
    expect(rs.map((r) => (r.hour, r.minute)), [(9, 0), (21, 0)]);
    for (final r in rs) {
      expect(r.title, 'নাপা খাওয়ার সময়');
      expect(r.repeat, Repeat.daily);
      expect(r.note, allOf(contains('খাবারের পরে'), contains('২টা করে'), contains('কেন: জ্বরের জন্য'), contains('বাবু দিয়েছেন')));
    }
  });

  test('received in the downloaded APK: a medicine, with food and why', () async {
    late Rig rig;
    final items = <Map<String, Object?>>[];
    rig = Rig(
        server: AccountServer(
            MockClient((r) async => http.Response.bytes(
                utf8.encode(jsonEncode(r.url.path.endsWith('/family/items') && r.method == 'GET' ? {'items': items} : {'ok': true})), 200)),
            'https://example.test'));
    rig.services.ai.session = 's' * 64;
    final me = await rig.brain.family.keys();
    items.add({'id': 1, 'link': 5, 'kind': 'medicine', 'sealed': await sealJsonFor({'title': 'নাপা', 'times': [540], 'meal': 'before', 'why': 'ব্যথা', 'from': 'বাবু'}, me.publicB64)});
    expect(await rig.brain.family.receive(), 1);
    final m = rig.brain.data.medicines.single;
    expect(m.meal, 'before');
    expect(m.note, allOf(contains('বাবু দিয়েছেন'), contains('কেন: ব্যথা')));
  });

  testWidgets('Play app: আম্মা page → ওষুধের রিমাইন্ডার দিন → the medicine form → her phone; listed on her page; on mine too', (t) async {
    medicalOffForTests = true;
    final (rig, calls, amma) = await linked(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const FamilyMemberScreen(linkId: 9)));
    await settle(t);
    expect(find.byKey(const Key('family-do-medicine')), findsOneWidget);
    expect(find.text('আম্মার ফোনে প্রতিদিন সময়মতো বাজবে'), findsOneWidget);
    await shot(t, '1-member-page');
    await t.tap(find.byKey(const Key('family-do-medicine')));
    await settle(t);
    await t.enterText(find.byKey(const Key('family-med-name')), 'নাপ');
    await settle(t);
    expect(find.byKey(const Key('med-hit-Napa')), findsOneWidget);
    await shot(t, '2-form-search');
    await t.tap(find.byKey(const Key('med-hit-Napa')));
    await t.enterText(find.byKey(const Key('family-med-why')), 'ডাক্তার জ্বরের জন্য দিয়েছেন');
    await settle(t);
    await t.ensureVisible(find.byKey(const Key('med-meal-after')));
    await t.tap(find.byKey(const Key('med-meal-after')));
    await t.ensureVisible(find.byKey(const Key('family-med-mine')));
    await settle(t);
    await t.tap(find.byKey(const Key('family-med-mine')));
    await settle(t);
    await shot(t, '3-form-filled');
    await t.ensureVisible(find.byKey(const Key('family-med-send')));
    await settle(t);
    await t.runAsync(() async {
      await t.tap(find.byKey(const Key('family-med-send')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(t);
    final p = await lastSent(t, calls, amma);
    expect(p['title'], 'নাপা');
    expect(p['times'], [540, 1260]);
    expect(p['meal'], 'after');
    expect(p['why'], 'ডাক্তার জ্বরের জন্য দিয়েছেন');
    expect(p['from'], 'বাবু');
    // Also on this phone, marked whose.
    expect(rig.brain.data.reminders.map((r) => r.title).toSet(), {'নাপা খাওয়ার সময় (আম্মা)'});
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(t);
    expect(find.byKey(const Key('family-sent-meds')), findsOneWidget);
    expect(find.text('আম্মাকে দেওয়া ওষুধের রিমাইন্ডার'), findsOneWidget);
    await shot(t, '4-sent-list');
    debugDisableShadows = true;
  });

  testWidgets('without her permission the row says so', (t) async {
    medicalOffForTests = true;
    await linked(t, allow: const ['task', 'reminder']);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const FamilyMemberScreen(linkId: 9)));
    await settle(t);
    expect(find.byKey(const Key('family-do-medicine')), findsNothing);
    expect(find.text('ওষুধের রিমাইন্ডার দিন'), findsOneWidget);
    expect(find.text('তিনি অনুমতি দেননি'), findsNWidgets(2), reason: 'medicines and notes');
    debugDisableShadows = true;
  });

  testWidgets('new medicine reminder: আম্মা (with a phone mark) in "কার জন্য" sends it to her phone', (t) async {
    medicalOffForTests = true;
    final (rig, calls, amma) = await linked(t);
    Navigator.of(t.element(find.byType(Scaffold).first)).push(MaterialPageRoute(builder: (_) => const NewItemScreen(category: ItemCategory.reminder, medicine: true)));
    await settle(t);
    await t.tap(find.byKey(const Key('med-who-link:9')));
    await settle(t);
    expect(find.byKey(const Key('med-to-phone')), findsOneWidget);
    expect(find.text('আম্মার ফোনে পাঠান'), findsOneWidget);
    await t.enterText(find.byKey(const Key('med-name')), 'সেকলো ২০');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(t);
    await shot(t, '5-from-reminder');
    final before = rig.brain.data.reminders.length;
    await t.runAsync(() async {
      await t.tap(find.text('আম্মার ফোনে পাঠান'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(t);
    final p = await lastSent(t, calls, amma);
    expect(p['title'], 'সেকলো ২০');
    expect(rig.brain.data.reminders.length, before, reason: 'not on this phone unless asked');
    debugDisableShadows = true;
  });
}
