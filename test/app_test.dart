import 'package:digital_brain/app.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/ai.dart';
import 'package:digital_brain/services/crypto.dart';
import 'package:digital_brain/services/data_store.dart';
import 'package:digital_brain/services/files.dart';
import 'package:digital_brain/services/launcher.dart';
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
    expect(find.text('My Assistant'), findsOneWidget);
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

  Future<void> openChat(WidgetTester t) async {
    await t.tap(find.text('যেকোনো কিছু জিজ্ঞেস করুন'));
    await settle(t);
    expect(find.text('কথা বলুন'), findsOneWidget);
  }

  Finder chip(String label) => find.widgetWithText(ActionChip, label);

  testWidgets('chat: say a loan, yes by voice, then keep talking', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('আমি সজীবকে ৫০০ টাকা দিলাম');
    await settle(t);
    expect(rig.voice.spoken.last, 'আচ্ছা, সজীবকে ৫০০ টাকা ধার দিলেন, তাই তো? লিখে রাখি?');
    expect(find.text('আমি সজীবকে ৫০০ টাকা দিলাম'), findsOneWidget);

    // Answer by voice; the chat keeps listening.
    rig.voice.say('হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.ledger.single.amount, 500);
    expect(rig.brain.data.ledger.single.kind, LedgerKind.lent);
    expect(rig.voice.spoken.last, contains('এখন সজীবের কাছে আপনার ৫০০ টাকা পাওনা আছে।'));
    expect(find.text('সজীবের খাতা দেখুন →'), findsOneWidget);

    rig.voice.say('সজীবের কাছে আমার কত টাকা পাওনা?');
    await settle(t);
    expect(rig.voice.spoken.last, startsWith('সজীবের কাছে আপনার ৫০০ টাকা পাওনা আছে।'));

    rig.voice.say('তুমি কেমন আছো?');
    await settle(t);
    expect(rig.voice.spoken.last, contains('ভালো আছি'));
    expect(find.text('কথা বলুন'), findsOneWidget);
  });

  testWidgets('chat: unclear money asks the kind with buttons', (t) async {
    final rig = await start(t,
        data: AppData(ledger: [LedgerEntry(person: 'রহিম', kind: LedgerKind.borrowed, amount: 1000, date: DateTime(2026, 10, 5))]));
    await openChat(t);
    rig.voice.say('রহিমকে ৫০০ টাকা দিলাম');
    await settle(t);
    expect(chip('শোধ করলাম'), findsOneWidget);
    expect(rig.brain.data.ledger, hasLength(1));
    await t.tap(chip('শোধ করলাম'));
    await settle(t);
    expect(rig.voice.spoken.last, 'আচ্ছা, রহিমকে ৫০০ টাকা শোধ করলেন, তাই তো? লিখে রাখি?');
    await t.tap(chip('হ্যাঁ'));
    await settle(t);
    expect(rig.brain.data.ledger, hasLength(2));
    expect(rig.brain.data.ledger.last.kind, LedgerKind.repaid);
  });

  testWidgets('chat: a note, saved on the হ্যাঁ button', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('মনে রাখো: গাড়ির কাগজ আলমারিতে');
    await settle(t);
    await t.tap(chip('হ্যাঁ'));
    await settle(t);
    expect(rig.brain.data.notes.single.body, 'গাড়ির কাগজ আলমারিতে');
    expect(rig.brain.data.notes.single.category, 'যানবাহন');
  });

  testWidgets('chat: a fact that matches nothing goes to a new category, by spoken yes', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('ছাদের দরজার কোড ৪৫৬৭');
    await settle(t);
    expect(find.textContaining('নতুন বিভাগ খুলে রেখে দিই'), findsOneWidget);
    rig.voice.say('জি রাখো');
    await settle(t);
    expect(rig.brain.data.notes.single.category, 'ছাদ');
  });

  testWidgets('chat: "ইসমাইলের কাছে আমি ৫ হাজার টাকা পাই" asks, then adds on হ্যাঁ', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('ইসমাইলের কাছে আমি ৫ হাজার টাকা পাই');
    await settle(t);
    expect(rig.voice.spoken.last, contains('ইসমাইল নামে তো কারও হিসাব নেই'));
    expect(rig.brain.data.ledger, isEmpty);
    rig.voice.say('হ্যাঁ');
    await settle(t);
    final e = rig.brain.data.ledger.single;
    expect(e.person, 'ইসমাইল');
    expect(e.amount, 5000);
    expect(e.kind, LedgerKind.lent);
  });

  testWidgets('chat: a saved login is found by its Bengali spelling, never read out', (t) async {
    final rig = await start(t,
        data: AppData(vault: [VaultItem(name: 'ABC ওয়েবসাইট', username: 'saif_admin', password: 'Kp7#vR2!qz')]));
    await openChat(t);
    rig.voice.say('এবিসির পাসওয়ার্ড দেখাও');
    await settle(t);
    expect(find.text('ABC ওয়েবসাইট'), findsOneWidget);
    expect(rig.voice.spoken.last, contains('তথ্য পেয়েছি'));
    expect(rig.voice.spoken.join(' '), isNot(contains('Kp7')));
    expect(find.textContaining('Kp7'), findsNothing);
  });

  testWidgets('chat: asking for a remembered fact says the fact itself', (t) async {
    final rig = await start(t,
        data: AppData(notes: [Note(title: 'ছাদের দরজার কোড ৪৫৬৭', body: 'ছাদের দরজার কোড ৪৫৬৭', category: 'ছাদ')]));
    await openChat(t);
    rig.voice.say('ছাদের দরজার কোড কত?');
    await settle(t);
    expect(rig.voice.spoken.last, 'ছাদের দরজার কোড ৪৫৬৭।');
  });

  testWidgets('chat: money without a name asks whom, then the kind, then saves', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('বিদ্যুৎ বিল ১২০০ টাকা দিলাম');
    await settle(t);
    expect(rig.voice.spoken.last, contains('কার সাথে লেনদেন হলো'));
    expect(rig.brain.data.notes, isEmpty);
    rig.voice.say('করিম');
    await settle(t);
    rig.voice.say('হ্যাঁ'); // the likely kind: ধার দিলাম
    await settle(t);
    expect(rig.voice.spoken.last, contains('তাই তো? লিখে রাখি?'));
    rig.voice.say('হ্যাঁ');
    await settle(t);
    final e = rig.brain.data.ledger.single;
    expect(e.person, 'করিম');
    expect(e.amount, 1200);
    expect(e.kind, LedgerKind.lent);
  });

  testWidgets('chat: two money events in one breath are listed and saved on one yes', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('সজীবকে ৫০০ টাকা ধার দিলাম আর রহিমের কাছ থেকে ২০০ টাকা ধার নিলাম');
    await settle(t);
    expect(rig.voice.spoken.last, contains('২টা জিনিস পেলাম'));
    expect(find.text('সজীবকে ৫০০ টাকা ধার দিলেন'), findsOneWidget);
    rig.voice.say('হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.ledger, hasLength(2));
    expect(rig.voice.spoken.last, contains('সব রেখে দিলাম'));
  });

  testWidgets('chat: "থামো" stops listening', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('থামো');
    await settle(t);
    expect(rig.voice.spoken.last, contains('থামলাম'));
    expect(find.text('বলুন'), findsOneWidget);
  });

  testWidgets('with AI on, Claude\'s reply is spoken', (t) async {
    final rig = await start(t, ai: {'action': 'chat', 'reply': 'জি, আলহামদুলিল্লাহ ভালো আছি! আপনার কী খবর?'});
    await openChat(t);
    rig.voice.say('কিরে দোস্ত, কী অবস্থা তোর');
    await settle(t);
    expect(rig.ai.asked, ['কিরে দোস্ত, কী অবস্থা তোর']);
    expect(rig.voice.spoken.last, 'জি, আলহামদুলিল্লাহ ভালো আছি! আপনার কী খবর?');
  });

  testWidgets('with AI on, the conversation so far goes along with the next sentence', (t) async {
    final rig = await start(t, ai: {'reply': 'ভালো আছি।', 'items': []});
    await openChat(t);
    rig.voice.say('কেমন আছো');
    await settle(t);
    rig.voice.say('আজকে আবহাওয়া কেমন');
    await settle(t);
    expect(rig.ai.asked, hasLength(2));
    final h = rig.ai.histories.last;
    expect(h.first.fromUser, isTrue);
    expect(h.first.text, 'কেমন আছো');
    expect(h[1].text, 'ভালো আছি।');
  });

  testWidgets('with AI on, a long message becomes a list of facts saved on one yes', (t) async {
    final rig = await start(t, ai: {
      'reply': 'আচ্ছা, বুঝেছি।',
      'items': [
        {'action': 'ledger_add', 'person': 'জামাল', 'amount': 1500, 'kind': 'lent'},
        {'action': 'note_add', 'text': 'ছাদের দরজার কোড ৪৫৬৭', 'category': 'বাসা'},
      ],
    });
    await openChat(t);
    rig.voice.say('শোনো আজকে জামাইল্লারে দেড় হাজার টেয়া হাওলাত দিছি আর হ্যাঁ ছাদের দরজার কোডটা হইল চাইর পাঁচ ছয় সাত');
    await settle(t);
    expect(find.text('জামালকে ১,৫০০ টাকা ধার দিলেন'), findsOneWidget);
    expect(find.text('ছাদের দরজার কোড ৪৫৬৭'), findsOneWidget);
    rig.voice.say('হ');
    await settle(t);
    expect(rig.brain.data.ledger.single.person, 'জামাল');
    expect(rig.brain.data.ledger.single.amount, 1500);
    expect(rig.brain.data.notes.single.category, 'বাসা');
  });

  testWidgets('with AI on, a money sentence the AI understood is confirmed in the chat', (t) async {
    final rig = await start(t, ai: {'action': 'ledger_add', 'person': 'জামাল', 'amount': 1500, 'kind': 'lent'});
    await openChat(t);
    rig.voice.say('জামাইল্লারে দেড় হাজার টেয়া হাওলাত দিছি');
    await settle(t);
    expect(rig.voice.spoken.last, contains('তাই তো? লিখে রাখি?'));
    rig.voice.say('হ');
    await settle(t);
    expect(rig.brain.data.ledger.single.person, 'জামাল');
    expect(rig.brain.data.ledger.single.amount, 1500);
  });

  testWidgets('password questions never go to the AI', (t) async {
    final rig = await start(t, ai: {'action': 'chat', 'reply': 'x'});
    await openChat(t);
    rig.voice.say('ফেসবুকের পাসওয়ার্ড দেখাও');
    await settle(t);
    expect(rig.ai.asked, isEmpty);
    rig.voice.say('কেমন আছো');
    await settle(t);
    // The earlier secret question is not passed on either.
    expect(rig.ai.histories.single.first.text, isNot(contains('ফেসবুক')));
  });

  testWidgets('AI failure falls back to the rules', (t) async {
    final rig = await start(t, ai: {'action': 'chat', 'reply': 'x'});
    rig.ai.error = const AiError('ইন্টারনেট সংযোগ পাওয়া যায়নি।');
    await openChat(t);
    rig.voice.say('আমি সজীবকে ৫০০ টাকা দিলাম');
    await settle(t);
    expect(rig.voice.spoken.last, 'আচ্ছা, সজীবকে ৫০০ টাকা ধার দিলেন, তাই তো? লিখে রাখি?');
    expect(find.textContaining('নিজের নিয়মে বুঝে নিলাম'), findsOneWidget);
  });

  testWidgets('assistant: a to-do by voice, the day at a glance, then ticked off', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('আজকে ব্যাংকে যেতে হবে');
    await settle(t);
    expect(rig.voice.spoken.last, contains('তুলে রাখি?'));
    rig.voice.say('হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.tasks.single.due, DateTime(2026, 10, 9));
    rig.voice.say('আজ আমার কী কী আছে?');
    await settle(t);
    expect(rig.voice.spoken.last, contains('কাজ বাকি ১টা'));
    rig.voice.say('ব্যাংকের কাজ হয়ে গেছে');
    await settle(t);
    expect(rig.brain.data.tasks.single.done, isTrue);
    expect(rig.voice.spoken.last, contains('দাগ দিলাম'));
  });

  testWidgets('assistant: a timed reminder is scheduled', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('কাল সকাল ১০টায় মিটিংয়ের কথা মনে করিয়ে দিও');
    await settle(t);
    expect(rig.voice.spoken.last, contains('দেব — ঠিক আছে?'));
    rig.voice.say('হ্যাঁ');
    await settle(t);
    final r = rig.brain.data.reminders.single;
    expect(r.date, DateTime(2026, 10, 10));
    expect(r.hour, 10);
    expect(r.daysBefore, 0);
    expect(rig.notifier.scheduled.single.at, DateTime(2026, 10, 10, 10, 0));
  });

  testWidgets('assistant: "রহিমকে ফোন দাও" opens the dialer with the saved number', (t) async {
    final rig = await start(t, data: AppData(contacts: [Contact(name: 'রহিম', phone: '01712345678')]));
    await openChat(t);
    rig.voice.say('রহিমকে ফোন দাও');
    await settle(t);
    final l = rig.services.launcher as FakeLauncher;
    expect(l.opened.single.toString(), 'tel:01712345678');
    expect(rig.voice.spoken.last, contains('ফোন দিচ্ছি'));
  });

  testWidgets('assistant: a message to someone new asks the number, keeps it, then opens SMS', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('করিমকে মেসেজ দাও যে মাল পাঠিয়েছি');
    await settle(t);
    expect(rig.voice.spoken.last, contains('নম্বর তো রাখা নেই'));
    rig.voice.say('০১৮১২৩৪৫৬৭৮');
    await settle(t);
    expect(rig.brain.data.contacts.single.phone, '01812345678');
    final l = rig.services.launcher as FakeLauncher;
    expect(l.opened.single.scheme, 'sms');
    expect(Uri.decodeComponent(l.opened.single.toString()), contains('মাল'));
  });

  testWidgets('assistant: a phone number said is kept in যোগাযোগ', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('রহিমের নম্বর ০১৭১২৩৪৫৬৭৮ রাখো');
    await settle(t);
    rig.voice.say('হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.contacts.single.name, 'রহিম');
    expect(rig.brain.data.contacts.single.phone, '01712345678');
  });
}
