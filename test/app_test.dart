import 'package:digital_brain/app.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/ai.dart';
import 'package:digital_brain/services/crypto.dart';
import 'package:digital_brain/services/data_store.dart';
import 'package:digital_brain/services/files.dart';
import 'package:digital_brain/services/lock.dart';
import 'package:digital_brain/services/notifications.dart';
import 'package:digital_brain/services/voice.dart';
import 'package:digital_brain/state/brain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real fonts, so text measures like on a phone.
Future<void> loadFonts() async {
  final noto = FontLoader('Noto');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    noto.addFont(rootBundle.load('assets/fonts/NotoSansBengali-$w.ttf'));
  }
  await noto.load();
}

class Rig {
  Rig({AppData? data}) {
    final keys = MemoryKeyVault();
    voice = FakeVoice();
    notifier = FakeNotifier();
    files = FakeFiles();
    biometrics = FakeBiometrics(has: false);
    ai = FakeAi();
    final store = DataStore(keys: keys, blob: MemoryBlobStore());
    services = Services(
      store: store,
      lock: LockService(keys: keys, biometrics: biometrics, iterations: 1000),
      voice: voice,
      notifier: notifier,
      files: files,
      ai: ai,
      clock: () => DateTime(2026, 10, 9, 15, 53),
    );
    brain = Brain(services);
    if (data != null) brain.data = data;
  }

  late final FakeVoice voice;
  late final FakeAi ai;
  late final FakeNotifier notifier;
  late final FakeFiles files;
  late final FakeBiometrics biometrics;
  late final Services services;
  late final Brain brain;
}

Future<void> settle(WidgetTester t, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

Future<void> enterPin(WidgetTester t, String pin) async {
  const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  for (final c in pin.split('')) {
    await t.tap(find.text(bn[int.parse(c)]).last);
    await t.pump(const Duration(milliseconds: 30));
  }
  await settle(t);
}

/// Starts the app, sets the PIN 1234 and lands on home.
Future<Rig> start(WidgetTester t, {AppData? data, AiRoute? ai}) async {
  t.view.physicalSize = const Size(1170, 2532);
  t.view.devicePixelRatio = 3.0;
  addTearDown(t.view.reset);
  await loadFonts();
  final rig = Rig();
  await t.pumpWidget(DigitalBrainApp(brain: rig.brain));
  await rig.brain.load();
  if (data != null) rig.brain.data = data;
  if (ai != null) {
    rig.ai.key = 'test-key';
    rig.ai.answer = ai;
  }
  await settle(t);
  expect(find.text('একটি ৪ অঙ্কের PIN ঠিক করুন'), findsOneWidget);
  await enterPin(t, '1234');
  expect(find.text('PIN টি আবার দিন'), findsOneWidget);
  await enterPin(t, '1234');
  expect(find.text('আপনার তথ্য'), findsOneWidget);
  return rig;
}

void main() {
  testWidgets('first run: choose a PIN, then home', (t) async {
    final rig = await start(t);
    expect(find.text('Digital Brain'), findsOneWidget);
    expect(await rig.services.lock.hasPin(), isTrue);

    // Lock and unlock again with a wrong, then the right PIN.
    rig.brain.lockNow();
    await settle(t);
    expect(find.text('PIN দিন'), findsOneWidget);
    await enterPin(t, '9999');
    expect(find.textContaining('PIN মেলেনি'), findsOneWidget);
    await enterPin(t, '1234');
    expect(find.text('আপনার তথ্য'), findsOneWidget);
  });

  testWidgets('say a loan, confirm, and see the person', (t) async {
    final rig = await start(t);
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    rig.voice.say('আমি সজীবকে ৫০০ টাকা দিলাম');
    await settle(t);
    expect(find.text('ঠিক বুঝেছি তো?'), findsOneWidget);
    expect(rig.voice.spoken.last, 'আচ্ছা, সজীবকে ৫০০ টাকা ধার দিলেন, তাই তো? লিখে রাখি?');

    // Answer by voice.
    rig.voice.say('হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.ledger.single.amount, 500);
    expect(rig.brain.data.ledger.single.kind, LedgerKind.lent);
    expect(rig.voice.spoken.last, contains('এখন সজীবের কাছে আপনার ৫০০ টাকা পাওনা আছে।'));
    expect(find.text('লেনদেনের ইতিহাস'), findsOneWidget);
  });

  testWidgets('unclear sentence asks first', (t) async {
    final rig = await start(t,
        data: AppData(ledger: [LedgerEntry(person: 'রহিম', kind: LedgerKind.borrowed, amount: 1000, date: DateTime(2026, 10, 5))]));
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    rig.voice.say('রহিমকে ৫০০ টাকা দিলাম');
    await settle(t);
    expect(find.text('এটা কোন ধরনের লেনদেন?'), findsOneWidget);
    expect(rig.brain.data.ledger, hasLength(1));

    await t.tap(find.text('আগের দেনা শোধ করলাম'));
    await settle(t);
    await t.tap(find.text('এগিয়ে যান'));
    await settle(t);
    expect(find.text('ঠিক বুঝেছি তো?'), findsOneWidget);
    await t.tap(find.text('হ্যাঁ, সেভ করুন'));
    await settle(t);
    expect(rig.brain.data.ledger, hasLength(2));
    expect(rig.brain.data.ledger.last.kind, LedgerKind.repaid);
  });

  testWidgets('a question is answered aloud', (t) async {
    final rig = await start(t,
        data: AppData(ledger: [LedgerEntry(person: 'সজীব', kind: LedgerKind.lent, amount: 200, date: DateTime(2026, 10, 8))]));
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    rig.voice.say('সজীবের কাছে আমার কত টাকা পাওনা?');
    await settle(t);
    expect(find.text('প্রশ্ন ও উত্তর'), findsOneWidget);
    expect(rig.voice.spoken.last, startsWith('সজীবের কাছে আপনার ২০০ টাকা পাওনা আছে।'));
  });

  testWidgets('save a password, open it, reveal it', (t) async {
    final rig = await start(t);
    await t.tap(find.text('ভল্ট').last);
    await settle(t);
    await t.tap(find.text('পাসওয়ার্ড যোগ করুন'));
    await settle(t);
    await t.enterText(find.widgetWithText(TextFormField, 'ওয়েবসাইট বা অ্যাপের নাম'), 'ABC ওয়েবসাইট');
    await t.enterText(find.widgetWithText(TextFormField, 'ইউজারনেম'), 'saif_admin');
    await t.enterText(find.widgetWithText(TextFormField, 'পাসওয়ার্ড'), 'Kp7#vR2!qz');
    await t.tap(find.text('সেভ করুন'));
    await settle(t);
    expect(rig.brain.data.vault.single.password, 'Kp7#vR2!qz');

    await t.tap(find.text('ABC ওয়েবসাইট'));
    await settle(t);
    expect(find.text('saif_admin'), findsOneWidget);
    expect(find.text('Kp7#vR2!qz'), findsNothing);
    await t.tap(find.byTooltip('পাসওয়ার্ড দেখুন'));
    await settle(t, 2);
    expect(find.text('Kp7#vR2!qz'), findsOneWidget);
    // Leave the page so its hide-timer is cancelled.
    await t.tap(find.byTooltip('ফিরে যান'));
    await settle(t);
  });

  testWidgets('a note by voice', (t) async {
    final rig = await start(t);
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    rig.voice.say('মনে রাখো: গাড়ির কাগজ আলমারিতে');
    await settle(t);
    await t.tap(find.text('হ্যাঁ, রাখুন'));
    await settle(t);
    expect(rig.brain.data.notes.single.body, 'গাড়ির কাগজ আলমারিতে');
    expect(rig.brain.data.notes.single.category, 'যানবাহন');
  });

  testWidgets('a fact that matches nothing goes to a new category, by spoken yes', (t) async {
    final rig = await start(t);
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    rig.voice.say('ছাদের দরজার কোড ৪৫৬৭');
    await settle(t);
    expect(find.textContaining('নতুন বিভাগ খুলে রেখে দিই'), findsOneWidget);
    rig.voice.say('জি রাখো');
    await settle(t);
    expect(rig.brain.data.notes.single.category, 'ছাদ');
  });

  testWidgets('"ইসমাইলের কাছে আমি ৫ হাজার টাকা পাই" asks, then adds on হ্যাঁ', (t) async {
    final rig = await start(t);
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    rig.voice.say('ইসমাইলের কাছে আমি ৫ হাজার টাকা পাই');
    await settle(t);
    expect(find.text('নতুন হিসাব যোগ করব?'), findsOneWidget);
    expect(rig.voice.spoken.last, contains('ইসমাইল নামে তো কারও হিসাব নেই'));
    expect(rig.brain.data.ledger, isEmpty);
    rig.voice.say('হ্যাঁ');
    await settle(t);
    final e = rig.brain.data.ledger.single;
    expect(e.person, 'ইসমাইল');
    expect(e.amount, 5000);
    expect(e.kind, LedgerKind.lent);
  });

  testWidgets('asking for a saved login by its Bengali spelling finds it', (t) async {
    final rig = await start(t,
        data: AppData(vault: [VaultItem(name: 'ABC ওয়েবসাইট', username: 'saif_admin', password: 'p')]));
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    rig.voice.say('এবিসির পাসওয়ার্ড দেখাও');
    await settle(t);
    expect(find.text('ABC ওয়েবসাইট'), findsOneWidget);
    expect(rig.voice.spoken.last, contains('তথ্য পেয়েছি'));
  });

  testWidgets('"তুমি কেমন আছো?" gets a friendly reply, not "no data"', (t) async {
    final rig = await start(t);
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    rig.voice.say('তুমি কেমন আছো?');
    await settle(t);
    expect(rig.voice.spoken.last, contains('ভালো আছি'));
    expect(find.textContaining('কিছু লেখা নেই'), findsNothing);
  });

  testWidgets('asking for a remembered fact says the fact itself', (t) async {
    final rig = await start(t,
        data: AppData(notes: [Note(title: 'ছাদের দরজার কোড ৪৫৬৭', body: 'ছাদের দরজার কোড ৪৫৬৭', category: 'ছাদ')]));
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    rig.voice.say('ছাদের দরজার কোড কত?');
    await settle(t);
    expect(rig.voice.spoken.last, 'ছাদের দরজার কোড ৪৫৬৭।');
  });

  testWidgets('money without a name: asks whom, then the kind, then saves to ধার-দেনা', (t) async {
    final rig = await start(t);
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    rig.voice.say('বিদ্যুৎ বিল ১২০০ টাকা দিলাম');
    await settle(t);
    expect(find.text('কার সাথে লেনদেন?'), findsOneWidget);
    expect(rig.brain.data.notes, isEmpty);
    rig.voice.say('করিম');
    await settle(t);
    rig.voice.say('হ্যাঁ'); // the likely kind: ধার দিলাম
    await settle(t);
    expect(find.text('ঠিক বুঝেছি তো?'), findsOneWidget);
    rig.voice.say('হ্যাঁ');
    await settle(t);
    final e = rig.brain.data.ledger.single;
    expect(e.person, 'করিম');
    expect(e.amount, 1200);
    expect(e.kind, LedgerKind.lent);
  });

  testWidgets('with AI on, Claude\'s reply is spoken', (t) async {
    final rig = await start(t, ai: {'action': 'chat', 'reply': 'জি, আলহামদুলিল্লাহ ভালো আছি! আপনার কী খবর?'});
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    rig.voice.say('কিরে দোস্ত, কী অবস্থা তোর');
    await settle(t);
    expect(rig.ai.asked, ['কিরে দোস্ত, কী অবস্থা তোর']);
    expect(rig.voice.spoken.last, 'জি, আলহামদুলিল্লাহ ভালো আছি! আপনার কী খবর?');
  });

  testWidgets('with AI on, a money sentence the AI understood goes to confirm', (t) async {
    final rig = await start(t, ai: {'action': 'ledger_add', 'person': 'জামাল', 'amount': 1500, 'kind': 'lent'});
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    rig.voice.say('জামাইল্লারে দেড় হাজার টেয়া হাওলাত দিছি');
    await settle(t);
    expect(find.text('ঠিক বুঝেছি তো?'), findsOneWidget);
    rig.voice.say('হ');
    await settle(t);
    expect(rig.brain.data.ledger.single.person, 'জামাল');
    expect(rig.brain.data.ledger.single.amount, 1500);
  });

  testWidgets('password questions never go to the AI', (t) async {
    final rig = await start(t, ai: {'action': 'chat', 'reply': 'x'});
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    rig.voice.say('ফেসবুকের পাসওয়ার্ড দেখাও');
    await settle(t);
    expect(rig.ai.asked, isEmpty);
  });

  testWidgets('AI failure falls back to the rules', (t) async {
    final rig = await start(t, ai: {'action': 'chat', 'reply': 'x'});
    rig.ai.error = const AiError('ইন্টারনেট সংযোগ পাওয়া যায়নি।');
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    rig.voice.say('আমি সজীবকে ৫০০ টাকা দিলাম');
    await settle(t);
    expect(find.text('ঠিক বুঝেছি তো?'), findsOneWidget);
  });
}
