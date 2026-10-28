// Owner's changes of 24 Oct (second list): what is premium, zakat from
// এখন আছে, the BMI push, ওছিয়তনামা, known apps for passwords, a name or tag
// for every upload, the heir's one-tap backup.
import 'package:digital_brain/logic/app_map.dart' show capabilitiesList, placeById;
import 'package:digital_brain/logic/pro.dart';
import 'package:digital_brain/logic/proactive.dart';
import 'package:digital_brain/logic/services_list.dart';
import 'package:digital_brain/logic/zakat.dart';
import 'package:digital_brain/logic/money_more.dart' show ZakatSaved;
import 'package:digital_brain/models/models.dart';
import 'dart:typed_data';

import 'package:digital_brain/screens/docs_screen.dart';
import 'package:digital_brain/state/brain.dart' show BrainMore;
import 'package:digital_brain/screens/notes_screen.dart';
import 'package:digital_brain/services/files.dart' show PickedDoc;
import 'package:digital_brain/screens/will_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, settle, start;

void main() {
  test('premium is only the owner\'s list; the rest is free', () {
    final b = Rig().brain..gated = true;
    expect(b.pro, isFalse);
    for (final f in [ProFeature.history, ProFeature.people, ProFeature.dueReminders, ProFeature.docAlerts, ProFeature.shops, ProFeature.receipts, ProFeature.smartNudges]) {
      expect(b.has(f), isTrue, reason: '$f');
    }
    for (final f in [ProFeature.projects, ProFeature.will, ProFeature.familyHealth, ProFeature.family, ProFeature.autoBackup, ProFeature.pdf, ProFeature.ai]) {
      expect(b.has(f), isFalse, reason: '$f');
    }
    expect(b.canAddProject, isFalse);
    expect(b.canUseProjects, isFalse);
    expect(freeVaultItems, 20);
    expect(freeReminders, 20);
    expect(freeDocs, 30);
    b.data = AppData(vault: [for (var i = 0; i < 19; i++) VaultItem(name: 's$i', password: 'x')]);
    expect(b.canAddVault, isTrue);
    b.data.vault.add(VaultItem(name: 's19', password: 'x'));
    expect(b.canAddVault, isFalse);
    expect(b.canSeeMonth(DateTime(2020, 1)), isTrue);
    // The Premium page lists every premium item, and nothing free.
    expect(proInfo.keys.toSet(), {ProFeature.reminders, ProFeature.docs, ProFeature.projects, ProFeature.will, ProFeature.familyHealth, ProFeature.vault, ProFeature.family, ProFeature.autoBackup, ProFeature.pdf, ProFeature.ai, ProFeature.noAds});
    expect(proInfo.keys.where(freeFeatures.contains), isEmpty);
  });

  test('zakat counts from এখন আছে, with loans and বকেয়া, not the accounts again', () {
    final at = DateTime(2026, 10, 24, 9);
    final d = AppData(
      accounts: [MoneyAccount(id: 'a', name: 'ব্যাংক', kind: AccountKind.bank, opening: 99999)],
      ledger: [
        LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 3000, date: at),
        LedgerEntry(person: 'করিম', kind: LedgerKind.lent, amount: 2000, date: at, projectId: 'p'),
      ],
      projects: [Project(id: 'p', name: 'দোকান', inMain: true, mainAsked: true)], // let into the main money (a হিসাব kept apart stays out of zakat, owner 28 Oct)
    );
    d.cashStart = 50000;
    d.cashSetAt = at;
    d.cash.add(CashEntry(kind: CashKind.income, amount: 20000, category: 'বেতন', date: at, addedAt: at.add(const Duration(minutes: 1))));
    d.cash.add(CashEntry(kind: CashKind.expense, amount: 3000, category: 'ধার দেওয়া', date: at, addedAt: at.add(const Duration(minutes: 2)), linkId: 'x'));
    final lines = zakatLines(d, at.add(const Duration(hours: 1)), const ZakatSaved());
    final now = lines.firstWhere((l) => l.key == 'cash:now');
    expect(now.amount, 67000);
    expect(now.how, contains('ধার দেওয়া'));
    expect(lines.where((l) => l.key.startsWith('account:')), isEmpty);
    expect(lines.firstWhere((l) => l.label.startsWith('রহিম')).amount, 3000);
    expect(lines.firstWhere((l) => l.label.startsWith('করিম')).label, contains('বকেয়া'));
  });

  test('a BMI above normal brings a kind push twice a week, without the number', () {
    final now = DateTime(2026, 10, 24, 12); // Saturday
    final d = AppData(
      members: [FamilyMember(id: FamilyMember.meId, name: 'আমি', heightCm: 165), FamilyMember(id: 'm', name: 'রুমা', relation: 'আম্মা', heightCm: 150)],
      health: [
        HealthLog(kind: HealthKind.weight, at: now.subtract(const Duration(days: 2)), a: 80),
        HealthLog(member: 'm', kind: HealthKind.weight, at: now.subtract(const Duration(days: 2)), a: 45),
      ],
    );
    final n = assistantNotices(d, now, const AssistantPrefs(dailyCap: 9)).where((x) => x.reminderId.startsWith(nudgeBmi)).toList();
    expect(n, hasLength(2), reason: '${n.map((x) => '${x.at} ${x.title}')}');
    expect(n.every((x) => x.reminderId == '${nudgeBmi}me'), isTrue, reason: 'আম্মার BMI is normal');
    expect({for (final x in n) x.at.weekday}, {DateTime.monday, DateTime.thursday});
    expect(n.first.body, isNot(contains(RegExp(r'[0-9০-৯]{2}'))));
    final off = assistantNotices(d, now, const AssistantPrefs(dailyCap: 9, health: false));
    expect(off.where((x) => x.reminderId.startsWith(nudgeBmi)), isEmpty);
  });

  test('known apps for passwords: by name, Bangla name or address', () {
    expect(knownServiceOf('ফেসবুক')?.name, 'Facebook');
    expect(knownServiceOf('gmail.com')?.name, 'Gmail');
    expect(knownServiceOf('বিকাশ')?.kind, VaultKind.bank);
    expect(knownServiceOf('আমার অফিসের সার্ভার'), isNull);
  });

  testWidgets('নোট: ওছিয়তনামা written, with the day it was last changed', (t) async {
    final rig = await start(t);
    final ctx = t.element(find.byType(Scaffold).first);
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const NotesScreen()));
    await settle(t);
    expect(find.byKey(const Key('will-open')), findsOneWidget);
    expect(find.textContaining('এখনো লেখা হয়নি'), findsOneWidget);
    await t.tap(find.byKey(const Key('will-open')));
    await settle(t);
    await t.tap(find.byKey(const Key('will-sample')));
    await settle(t);
    await t.tap(find.byKey(const Key('will-save')));
    await settle(t);
    final w = willOf(rig.brain.data)!;
    expect(w.body, contains('ওছিয়ত'));
    expect(find.byKey(const Key('will-last')), findsOneWidget);
    expect(find.textContaining('শেষ ওছিয়ত:'), findsWidgets);
  });

  test('a document must have a folder that fits: no catch-all অন্যান্য', () {
    expect(docFolders, isNot(contains('অন্যান্য')));
  });

  test('কী কী করা যায়: the new parts are listed (will, money now, family, premium by bKash)', () {
    final all = capabilitiesList();
    expect(all, contains('ওছিয়তনামা'));
    expect(all, contains('এখন আছে'));
    expect(all, contains('উত্তরাধিকারী'));
    expect(all, contains('বিকাশে'));
    expect(all, isNot(contains('মেসেজ থেকে কাজ')));
    expect(placeById('will'), isNotNull);
  });

  testWidgets('ডকুমেন্টস: a folder named by the user, kept while empty, a photo goes in it', (t) async {
    final rig = await start(t);
    final ctx = t.element(find.byType(Scaffold).first);
    Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => const DocsScreen()));
    await settle(t);
    await t.ensureVisible(find.byKey(const Key('doc-folder-new')));
    await t.tap(find.byKey(const Key('doc-folder-new')));
    await settle(t);
    await t.enterText(find.byKey(const Key('doc-folder-name')), 'বাচ্চার স্কুল');
    await t.tap(find.byKey(const Key('doc-folder-save')));
    await settle(t);
    expect(rig.brain.data.ownDocFolders, ['বাচ্চার স্কুল']);
    expect(find.text('বাচ্চার স্কুল'), findsWidgets, reason: 'the folder opens');
    // Kept after a restart (in the saved data).
    expect(AppData.fromJson(rig.brain.data.toJson()).ownDocFolders, ['বাচ্চার স্কুল']);
    rig.files.photo = PickedDoc(Uint8List.fromList(List.generate(800, (i) => i % 251)), 'r.jpg', 'image/jpeg');
    await t.tap(find.text('গ্যালারি'));
    await settle(t);
    await t.enterText(find.widgetWithText(TextField, 'নাম'), 'রেজাল্ট কার্ড');
    await t.ensureVisible(find.text('রাখুন').last);
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    expect(rig.brain.data.docs.single.folder, 'বাচ্চার স্কুল');
    expect(await rig.brain.removeDocFolder('বাচ্চার স্কুল'), isFalse, reason: 'not while it holds a paper');
  });
}
