import 'dart:async';
import 'dart:typed_data';

import 'package:digital_brain/app.dart';
import 'package:digital_brain/logic/ai_safe.dart';
import 'package:digital_brain/logic/ledger.dart';
import 'package:digital_brain/logic/money_more.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/services/ai.dart';
import 'package:digital_brain/services/crypto.dart';
import 'package:digital_brain/services/data_store.dart';
import 'package:digital_brain/services/files.dart';
import 'package:digital_brain/services/launcher.dart';
import 'package:digital_brain/services/inbox.dart';
import 'package:digital_brain/services/lock.dart';
import 'package:digital_brain/services/notifications.dart';
import 'package:digital_brain/services/phonebook.dart';
import 'package:digital_brain/services/voice.dart';
import 'package:digital_brain/state/brain.dart';
import 'package:digital_brain/ui/theme.dart';
import 'package:digital_brain/screens/assistant_settings.dart';
import 'package:digital_brain/screens/app_places.dart';
import 'package:digital_brain/screens/chat_home.dart';
import 'package:digital_brain/screens/inbox_screen.dart';
import 'package:digital_brain/screens/calendar_screen.dart';
import 'package:digital_brain/screens/tasks_screen.dart';
import 'package:digital_brain/ui/file_view.dart';
import 'package:digital_brain/ui/pdf_export.dart';
import 'package:digital_brain/screens/notes_screen.dart';
import 'package:digital_brain/screens/health_screens.dart';
import 'package:digital_brain/screens/home_shell.dart';
import 'package:digital_brain/screens/money_more_screens.dart';
import 'package:digital_brain/screens/more_screen.dart';
import 'package:digital_brain/screens/onboarding_screen.dart';
import 'package:digital_brain/screens/search_screen.dart';
import 'package:digital_brain/screens/special_days_screen.dart';
import 'package:digital_brain/screens/store_more_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real fonts, so text measures like on a phone.
Future<void> loadFonts() async {
  final hind = FontLoader('Hind');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    hind.addFont(rootBundle.load('assets/fonts/HindSiliguri-$w.ttf'));
  }
  await hind.load();
  final noto = FontLoader('NotoBengali');
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
    phonebook = FakePhonebook();
    inbox = FakeInbox();
    final store = DataStore(keys: keys, blob: MemoryBlobStore());
    services = Services(
      store: store,
      lock: LockService(keys: keys, biometrics: biometrics, iterations: 1000),
      voice: voice,
      notifier: notifier,
      files: files,
      ai: ai,
      phonebook: phonebook,
      inbox: inbox,
      clock: () => DateTime(2026, 10, 9, 15, 53),
    );
    brain = Brain(services);
    if (data != null) brain.data = data;
  }

  late final FakeVoice voice;
  late final FakeAi ai;
  late final FakePhonebook phonebook;
  late final FakeInbox inbox;
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
  showOnboarding = false;
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
  expect(find.byTooltip('বলুন'), findsOneWidget);
  return rig;
}

/// Goes to a page the way a user would: হিসাব from the bottom menu, আমি
/// from the home's profile button, the rest from সংরক্ষণ.
Future<void> openMenu(WidgetTester t, String item) async {
  if (item == 'হিসাব') {
    await t.tap(find.text('হিসাব').last);
  } else if (item == 'আমি' || item == 'সেটিংস') {
    await t.tap(find.byTooltip('সেটিংস'));
  } else {
    await t.tap(find.text('সংরক্ষণ').last);
    await settle(t);
    await t.tap(find.text(item).last);
  }
  await settle(t);
}

/// The assistant, ready to type.
Future<void> openTyping(WidgetTester t) async {
  if (find.text('আগের কথা').evaluate().isEmpty) {
    await t.tap(find.text('হোম').last);
    await settle(t);
  }
  await t.tap(find.text('আগের কথা'));
  await settle(t);
  if (find.byTooltip('লিখে বলুন').evaluate().isNotEmpty) {
    await t.tap(find.byTooltip('লিখে বলুন'));
    await settle(t);
  }
}

void main() {
  testWidgets('first run: choose a PIN, then home', (t) async {
    final rig = await start(t);
    expect(find.text('সব কিছু এক জায়গায়'), findsOneWidget);
    expect(await rig.services.lock.hasPin(), isTrue);

    // Lock and unlock again with a wrong, then the right PIN.
    rig.brain.lockNow();
    await settle(t);
    expect(find.text('PIN দিন'), findsOneWidget);
    await enterPin(t, '9999');
    expect(find.textContaining('PIN মেলেনি'), findsOneWidget);
    await enterPin(t, '1234');
    expect(find.byTooltip('বলুন'), findsOneWidget);
  });

  testWidgets('save a password, open it, reveal it', (t) async {
    final rig = await start(t);
    await openMenu(t, 'পাসওয়ার্ড');
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

  /// The mic on the home: the voice view opens and listens.
  Future<void> openChat(WidgetTester t) async {
    await t.tap(find.byTooltip('বলুন').first);
    await settle(t);
    expect(find.text('শুনছি…'), findsOneWidget);
  }

  Finder chip(String label) => find.widgetWithText(ActionChip, label);

  testWidgets('voice: "নোট খোলো" opens the notes page; "লেনদেন খোলো" the money tab', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('নোট খোলো');
    await settle(t);
    expect(find.byType(NotesScreen), findsOneWidget);
    Navigator.of(t.element(find.byType(NotesScreen))).pop();
    await settle(t);
    rig.voice.say('তুমি কী কী পারো');
    await settle(t);
    expect(find.textContaining('• স্বাস্থ্য'), findsOneWidget);
    rig.voice.say('লেনদেন খোলো');
    await settle(t);
    expect(find.byType(ChatHome), findsNothing);
  });

  testWidgets('inbox: access turned off shows the setup again; codes and passwords are never kept; a build without the reader says so', (t) async {
    final rig = await start(t);
    rig.inbox.access = true;
    rig.inbox.waiting.addAll([
      InboxMessage(id: 'a', app: 'com.google.android.apps.messaging', appName: 'SMS', chat: 'bKash', from: 'bKash', text: 'Your OTP is 482913. Do not share.', at: DateTime(2026, 10, 9, 9)),
      InboxMessage(id: 'b', app: 'com.whatsapp', appName: 'WhatsApp', chat: 'রহিম', from: 'রহিম', text: 'ওয়াইফাই পাসওয়ার্ড টা দাও', at: DateTime(2026, 10, 9, 9, 1)),
      InboxMessage(id: 'c', app: 'com.whatsapp', appName: 'WhatsApp', chat: 'রহিম', from: 'রহিম', text: 'কাল বিকেলে দেখা হবে', at: DateTime(2026, 10, 9, 9, 2)),
      InboxMessage(id: 'c', app: 'com.whatsapp', appName: 'WhatsApp', chat: 'রহিম', from: 'রহিম', text: 'কাল বিকেলে দেখা হবে', at: DateTime(2026, 10, 9, 9, 2)), // the same one twice
    ]);
    unawaited(openPlace(t.element(find.byType(HomeShell)), 'inbox'));
    await settle(t);
    expect([for (final m in rig.brain.data.inbox) m.id], ['c']);
    Navigator.of(t.element(find.byType(InboxScreen))).pop();
    await settle(t);
    // Access taken away in the phone's settings: the page asks again.
    rig.inbox.access = false;
    unawaited(openPlace(t.element(find.byType(HomeShell)), 'inbox'));
    await settle(t);
    expect(find.text('অনুমতি দিন'), findsOneWidget);
    Navigator.of(t.element(find.byType(InboxScreen))).pop();
    await settle(t);
    // This APK leaves the reader out (Play Protect): the page says so.
    rig.inbox.isSupported = false;
    await rig.brain.load();
    unawaited(openPlace(t.element(find.byType(HomeShell)), 'inbox'));
    await settle(t);
    expect(find.textContaining('এই সংস্করণে নেই'), findsOneWidget);
    expect(find.text('অনুমতি দিন'), findsNothing);
    Navigator.of(t.element(find.byType(InboxScreen))).pop();
    await settle(t);
  });

  testWidgets('বার্তা থেকে কাজ: permission first, then the work found in messages', (t) async {
    final rig = await start(t);
    unawaited(openPlace(t.element(find.byType(HomeShell)), 'inbox'));
    await settle(t);
    expect(find.byType(InboxScreen), findsOneWidget);
    expect(find.text('অনুমতি দিন'), findsOneWidget);
    expect(find.textContaining('কোনো সার্ভার বা AI-তে যায় না'), findsWidgets);
    rig.inbox.waiting.addAll([
      InboxMessage(id: '1', app: 'com.whatsapp', appName: 'WhatsApp', chat: 'রহিম', from: 'রহিম', text: 'ভাই ৫০০০ টাকা পাঠাও, খুব দরকার', at: DateTime(2026, 10, 9, 15, 40), key: 'k1'),
      InboxMessage(id: '2', app: 'com.whatsapp', appName: 'WhatsApp', chat: 'করিম', from: 'করিম', text: 'ঠিক আছে', at: DateTime(2026, 10, 9, 15, 41)),
    ]);
    await t.ensureVisible(find.text('অনুমতি দিন'));
    await t.tap(find.text('অনুমতি দিন'));
    await settle(t);
    expect(rig.brain.data.inbox, hasLength(2));
    expect(find.textContaining('টাকা চেয়েছেন'), findsOneWidget);
    await t.tap(find.text('কাজে রাখুন').first);
    await settle(t);
    expect(rig.brain.data.tasks.single.title, contains('৫,০০০'));
    expect(find.textContaining('টাকা চেয়েছেন'), findsNothing);
    // Reply to a message from the list.
    await t.tap(find.text('রহিম').first);
    await settle(t);
    await t.tap(find.text('উত্তর দিন').last);
    await settle(t);
    await t.tap(find.text('একটু পরে জানাচ্ছি।'));
    await t.tap(find.text('পাঠান'));
    await settle(t);
    expect(rig.inbox.sent.single, ('1', 'একটু পরে জানাচ্ছি।'));
    Navigator.of(t.element(find.byType(InboxScreen))).pop();
    await settle(t);
  });

  testWidgets('AI privacy: off sends nothing; on, secrets, numbers and the vault never go', (t) async {
    final data = AppData(
      vault: [VaultItem(name: 'ব্যাংক', username: 'saif', password: 'Gopon#123')],
      notes: [
        Note(title: 'বাসা', body: 'বাসা মিরপুর ১০, রোড ৩'),
        Note(title: 'ATM পিন', body: '4321'),
        Note(title: 'রহিম', body: 'রহিমের নম্বর 01711223344, ইমেইল rahim@example.com'),
      ],
      docs: [Doc(title: 'NID 1990123456789', folder: 'পরিচয়পত্র')],
      memories: [Memory(text: 'আমার ব্যাংকের পিন 9999')],
    );
    // AI off (no key): nothing is asked.
    final rig = await start(t, data: data);
    await openTyping(t);
    Future<void> type(String s) async {
      await t.enterText(find.byType(TextField).first, s);
      await t.testTextInput.receiveAction(TextInputAction.send);
      await settle(t);
    }

    await type('বাসার ঠিকানা কী?');
    expect(rig.ai.asked, isEmpty);
    // AI on.
    rig.ai.key = 'test-key';
    rig.ai.answer = {'reply': 'মিরপুর ১০, রোড ৩।', 'items': []};
    await type('বাসার ঠিকানা কী?');
    expect(rig.ai.asked, isNotEmpty);
    final records = rig.ai.contexts.last.records;
    expect(records, contains('মিরপুর'));
    for (final secret in ['Gopon#123', '4321', '9999', 'saif']) {
      expect(records, isNot(contains(secret)), reason: secret);
    }
    // What leaves the phone is also scrubbed of numbers and e-mails.
    final wire = redactForAi(systemContext(rig.ai.contexts.last));
    for (final n in ['01711223344', '1990123456789', 'rahim@example.com']) {
      expect(wire, isNot(contains(n)), reason: n);
    }
    // A sentence with a phone number is understood on the phone.
    final asked = rig.ai.asked.length;
    await type('করিমের নম্বর 01811223344');
    expect(rig.ai.asked.length, asked);
    // "Let the AI see my things" off: no records, no note folders.
    await rig.brain.setAiShareData(false);
    final before = rig.ai.asked.length;
    await type('আজ রাতে কী রান্না করা যায় বলো তো');
    expect(rig.ai.asked.length, before + 1);
    expect(rig.ai.contexts.last.records, isEmpty);
    expect(rig.ai.contexts.last.categories, isEmpty);
  });

  testWidgets('typing a word or two shows sentences to pick; a tap puts one in the box', (t) async {
    final rig = await start(t);
    await openTyping(t);
    await t.enterText(find.byType(TextField).first, 'বিদ্যুৎ বিল');
    await settle(t);
    const s = 'প্রতি মাসের ১০ তারিখে বিদ্যুৎ বিল দেওয়ার কথা মনে করিয়ে দিও';
    expect(find.byKey(const ValueKey('suggest:$s')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('suggest:$s')));
    await settle(t);
    expect(t.widget<TextField>(find.byType(TextField).first).controller!.text, s);
    await t.testTextInput.receiveAction(TextInputAction.send);
    await settle(t);
    if (rig.brain.data.reminders.isEmpty) {
      await t.enterText(find.byType(TextField).first, 'হ্যাঁ');
      await t.testTextInput.receiveAction(TextInputAction.send);
      await settle(t);
    }
    expect(rig.brain.data.reminders.single.repeat, Repeat.monthly);
  });

  testWidgets('"আজ ইব্রাহিম ভাই আসার কথা সন্ধ্যা ৭টায়" is a reminder; "রিমাইন্ডার লিখে রাখো" keeps it', (t) async {
    final rig = await start(t);
    await openTyping(t);
    Future<void> type(String s) async {
      await t.enterText(find.byType(TextField).first, s);
      await t.testTextInput.receiveAction(TextInputAction.send);
      await settle(t);
    }

    await type('আজ ইব্রাহিম ভাই আসার কথা সন্ধ্যা ৭ টায়');
    expect(find.textContaining('নতুন'), findsNothing);
    await type('রিমাইন্ডার লিখে রাখো');
    final r = rig.brain.data.reminders.single;
    expect((r.hour, r.minute, r.date.day), (19, 0, 9));
    expect(r.title, contains('ইব্রাহিম'));
    expect(rig.brain.data.notes, isEmpty);

    // A note saved, then "না, রিমাইন্ডার দাও": the note goes, a reminder comes.
    await type('মনে রাখো: কাল সকাল ১০টায় ব্যাংকে চেক জমা');
    if (find.widgetWithText(ActionChip, 'হ্যাঁ').evaluate().isNotEmpty) {
      await t.tap(find.widgetWithText(ActionChip, 'হ্যাঁ').last);
      await settle(t);
    }
    await type('না, রিমাইন্ডার দাও');
    expect(rig.brain.data.notes.where((n) => n.body.contains('ব্যাংকে')), isEmpty);
    expect(rig.brain.data.reminders.where((x) => x.title.contains('ব্যাংক') && x.hour == 10), hasLength(1));
  });

  testWidgets('change or remove saved things by typing or voice', (t) async {
    final rig = await start(t);
    await openTyping(t);
    Future<void> type(String s) async {
      await t.enterText(find.byType(TextField).first, s);
      await t.testTextInput.receiveAction(TextInputAction.send);
      await settle(t);
    }

    Future<void> yes() async {
      await t.tap(find.widgetWithText(ActionChip, 'হ্যাঁ').last);
      await settle(t);
    }

    await type('কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও');
    await yes();
    expect(rig.brain.data.reminders.single.hour, 10);
    await type('মিটিংয়ের রিমাইন্ডারটা ৮টায় করে দাও');
    expect(find.textContaining('বদলে'), findsWidgets);
    await yes();
    expect(rig.brain.data.reminders.single.hour, 8);
    await type('রবিনকে ৫০০০ টাকা ধার দিলাম');
    await yes();
    expect(rig.brain.data.ledger.single.amount, 5000);
    await type('রবিনের লেনদেনটা ৫০০০ না ৬০০০ হবে');
    await yes();
    expect(rig.brain.data.ledger.single.amount, 6000);
    await type('মিটিংয়ের রিমাইন্ডার মুছে দাও');
    expect(find.textContaining('মুছে দেবো?'), findsOneWidget);
    await yes();
    expect(rig.brain.data.reminders, isEmpty);
    await type('শেষটা মুছে দাও');
    expect(find.textContaining('রবিন'), findsWidgets);
    await yes();
    expect(rig.brain.data.ledger, isEmpty);
    expect(rig.brain.data.reminders, isEmpty, reason: 'the earlier delete stays');
  });

  testWidgets('a kept PDF opens page by page, and can be downloaded or opened in another app', (t) async {
    final rig = await start(t);
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(nav.push(MaterialPageRoute(builder: (_) => PdfViewScreen(bytes: Uint8List.fromList([37, 80, 68, 70]), name: 'রিপোর্ট.pdf', title: 'রিপোর্ট'))));
    await settle(t);
    expect(find.text('পাতা ১ / ২'), findsOneWidget);
    await t.tap(find.byTooltip('ডাউনলোড করুন'));
    await settle(t);
    expect(rig.files.savedName, 'রিপোর্ট.pdf');
    await t.tap(find.byTooltip('অন্য অ্যাপে খুলুন'));
    await settle(t);
    expect(rig.files.openedWith, 'রিপোর্ট.pdf');
    nav.pop();
    await settle(t);
  });

  testWidgets('after 4 wrong PINs the wait counts down every second', (t) async {
    final rig = await start(t);
    rig.brain.lockNow();
    await settle(t);
    for (var i = 0; i < 5; i++) {
      await enterPin(t, '0000');
    }
    expect(find.textContaining('৩০ সেকেন্ড পর').evaluate().isNotEmpty || find.textContaining('২৯ সেকেন্ড পর').evaluate().isNotEmpty, isTrue);
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2100)));
    await t.pump(const Duration(seconds: 1));
    expect(find.textContaining('২৭ সেকেন্ড পর').evaluate().isNotEmpty || find.textContaining('২৮ সেকেন্ড পর').evaluate().isNotEmpty, isTrue);
  });

  testWidgets('every income/expense has ⋮ to change or delete it', (t) async {
    final rig = await start(t, data: AppData(cash: [CashEntry(kind: CashKind.expense, amount: 500, category: 'বাজার', date: DateTime(2026, 10, 9))]));
    unawaited(openPlace(t.element(find.byType(HomeShell)), 'money'));
    await settle(t);
    final more = find.byTooltip('বদলান বা মুছুন');
    expect(more, findsOneWidget);
    await t.ensureVisible(more);
    await t.drag(find.ancestor(of: more, matching: find.byType(Scrollable)).first, const Offset(0, -300));
    await settle(t);
    await t.tap(more);
    await settle(t);
    await t.tap(find.text('মুছুন').last);
    await settle(t);
    await t.tap(find.text('মুছুন').last);
    await settle(t);
    expect(rig.brain.data.cash, isEmpty);
    await t.tap(find.text('ফিরিয়ে আনুন'));
    await settle(t);
    expect(rig.brain.data.cash.single.amount, 500);
  });

  testWidgets('settings: everything as one PDF, shown with download', (t) async {
    final rig = await start(t, data: AppData(tasks: [Task(title: 'ছাদ মেরামত')]));
    unawaited(exportEverything(t.element(find.byType(HomeShell))));
    await settle(t);
    expect(find.text('সবকিছু PDF আকারে'), findsWidgets);
    await t.tap(find.text('PDF তৈরি করুন'));
    await settle(t);
    expect('${rig.files.lastPdf}', contains('ছাদ মেরামত'));
    expect(find.byType(PdfViewScreen), findsOneWidget);
    await t.tap(find.byTooltip('ডাউনলোড করুন'));
    await settle(t);
    expect(rig.files.savedName, startsWith('my-assistant-all-'));
    Navigator.of(t.element(find.byType(PdfViewScreen))).pop();
    await settle(t);
  });

  testWidgets('a page\'s PDF button makes that page\'s report', (t) async {
    final rig = await start(t, data: AppData(contacts: [Contact(name: 'জামাল', phone: '01711000000')]));
    unawaited(openPlace(t.element(find.byType(HomeShell)), 'contacts'));
    await settle(t);
    await t.tap(find.byTooltip('PDF ডাউনলোড').first);
    await settle(t);
    final spec = '${rig.files.lastPdf}';
    expect(spec, contains('জামাল'));
    expect(spec, isNot(contains('কাজের তালিকা')));
    Navigator.of(t.element(find.byType(PdfViewScreen))).pop();
    await settle(t);
  });

  testWidgets('chat: say a loan, yes by voice, then keep talking', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('আমি সজীবকে ৫০০ টাকা ধার দিলাম');
    await settle(t);
    expect(rig.voice.spoken.last, 'আচ্ছা, সজীবকে ৫০০ টাকা ধার দিলেন, তাই তো? লিখে রাখি?');

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
    expect(find.text('শুনছি…'), findsOneWidget);

    // Closing the voice view shows the whole conversation.
    await t.tap(find.byTooltip('বন্ধ করুন'));
    await settle(t);
    // (also the page title)
    expect(find.text('আমি সজীবকে ৫০০ টাকা ধার দিলাম'), findsNWidgets(2));
    expect(find.text('সজীবের খাতা দেখুন →'), findsWidgets);
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
    rig.voice.say('১২০০ টাকা ধার দিলাম');
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
    expect(find.textContaining('সজীবকে ৫০০ টাকা ধার দিলেন'), findsOneWidget);
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
    // Back to the conversation, the mic waiting to be tapped.
    expect(find.byTooltip('কথা বলুন'), findsOneWidget);
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
    expect(find.textContaining('জামালকে ১,৫০০ টাকা ধার দিলেন'), findsOneWidget);
    expect(find.textContaining('ছাদের দরজার কোড ৪৫৬৭'), findsOneWidget);
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
    rig.voice.say('আমি সজীবকে ৫০০ টাকা ধার দিলাম');
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

  testWidgets('shops: the first visit asks for the shop; several shops, each with its own sales', (t) async {
    final rig = await start(t);
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(nav.push(MaterialPageRoute(builder: (_) => const ShopScreen())));
    await settle(t);
    expect(find.text('প্রথমে দোকানটা যোগ করুন'), findsOneWidget);
    await t.tap(find.text('দোকান যোগ করুন'));
    await settle(t);
    await t.enterText(find.byKey(const Key('shop-name')), 'সাইফ স্টোর');
    await t.enterText(find.byKey(const Key('shop-phone')), '01711000000');
    await t.enterText(find.byKey(const Key('shop-address')), 'মিরপুর ১০');
    await t.tap(find.text('রাখুন'));
    await settle(t);
    expect(rig.brain.data.shops.single.address, 'মিরপুর ১০');
    final first = rig.brain.data.shops.single;
    final second = Shop(name: 'সাইফ ফার্মেসি');
    await rig.brain.saveShop(second);
    final now = rig.brain.services.now();
    await rig.brain.saveCash(CashEntry(kind: CashKind.income, amount: 700, category: 'বিক্রি', date: now)); // said by voice: the first shop
    await rig.brain.saveCash(CashEntry(kind: CashKind.income, amount: 300, category: 'বিক্রি', date: now, shopId: second.id));
    await settle(t);
    expect(find.text('আমার দোকান'), findsOneWidget);
    expect(find.text('৳১,০০০'), findsWidgets); // both shops today
    await t.tap(find.text('সাইফ ফার্মেসি'));
    await settle(t);
    expect(find.byType(ShopDetailScreen), findsOneWidget);
    expect(find.text('৳৩০০'), findsWidgets);
    expect(salesOn(rig.brain.data, now, shop: first).total, 700);
    nav.popUntil((r) => r.isFirst);
    await settle(t);
  });

  testWidgets('tasks: the ⏰ beside a task sets its reminder, with how long before in a number and a unit', (t) async {
    final rig = await start(t, data: AppData(tasks: [Task(title: 'গ্যাস বিল দেওয়া')]));
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    unawaited(nav.push(MaterialPageRoute(builder: (_) => const TasksScreen())));
    await settle(t);
    await t.tap(find.byTooltip('রিমাইন্ডার দিন'));
    await settle(t);
    expect(find.text('কতক্ষণ আগে মনে করাবে?'), findsOneWidget);
    await t.enterText(find.byKey(const Key('before-number')), '২');
    await t.tap(find.byKey(const Key('before-unit')));
    await settle(t);
    await t.tap(find.text('ঘণ্টা আগে').last);
    await settle(t);
    await t.tap(find.text('সেভ করুন'));
    await settle(t);
    final r = rig.brain.data.reminders.single;
    expect(r.title, 'গ্যাস বিল দেওয়া');
    expect(r.minutesBefore, 120);
    expect(rig.brain.data.tasks.single.reminderId, r.id);
    expect(find.byTooltip('রিমাইন্ডার দিন'), findsNothing); // now the ⏰ shows it is set
    nav.popUntil((r) => r.isFirst);
    await settle(t);
  });

  testWidgets('voice: lend, partly paid back, a correction, a repeated final result, "বাদ দাও", a day then the hour', (t) async {
    final rig = await start(t);
    await openChat(t);
    int bal() => balanceWith(rig.brain.data.ledger, 'সজীব');
    Future<void> say(String s) async {
      rig.voice.say(s);
      await settle(t);
    }

    await say('সজীবকে পাঁচশ টাকা ধার দিলাম');
    // "না, সাতশ" to the question: the amount is corrected and asked again — nothing saved yet.
    await say('না, সাতশ');
    expect(rig.brain.data.ledger, isEmpty);
    expect(rig.voice.spoken.last, contains('৭০০'));
    await say('হ্যাঁ');
    expect(bal(), 700);
    // The recogniser reports the same final sentence twice: one entry.
    rig.voice.say('সজীব সেই ধার থেকে তিনশ টাকা ফেরত দিল');
    rig.voice.say('সজীব সেই ধার থেকে তিনশ টাকা ফেরত দিল');
    await settle(t);
    if (rig.brain.data.ledger.length == 1) await say('হ্যাঁ');
    expect(rig.brain.data.ledger, hasLength(2));
    expect(bal(), 400);
    // A new loan, then "বাদ দাও": nothing kept.
    await say('সজীবকে দুইশ টাকা ধার দিলাম');
    await say('বাদ দাও');
    expect(rig.brain.data.ledger, hasLength(2));
    expect(rig.voice.spoken.last, contains('বাদ দিলাম'));
    // "দিইনি": nothing written.
    await say('সজীবকে টাকা দিইনি');
    expect(rig.brain.data.ledger, hasLength(2));
    // A day without an hour: the hour is asked, the day kept.
    await say('কাল ডাক্তার দেখাতে মনে করিয়ে দিও');
    expect(rig.voice.spoken.last, contains('কয়টায়'));
    await say('বিকাল পাঁচটায়');
    if (rig.brain.data.reminders.isEmpty) await say('হ্যাঁ');
    final r = rig.brain.data.reminders.single;
    expect((r.date, r.hour), (DateTime(2026, 10, 10), 17));
  });

  testWidgets('voice: an alarm said aloud is set as an alarm', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('কাল সকাল ৬টায় এলার্ম দাও');
    await settle(t);
    if (rig.brain.data.reminders.isEmpty) {
      rig.voice.say('হ্যাঁ');
      await settle(t);
    }
    final r = rig.brain.data.reminders.single;
    expect(r.alarm, isTrue);
    expect(r.hour, 6);
    expect(r.date, DateTime(2026, 10, 10));
  });

  testWidgets('voice: when the first guess makes no sense, the recogniser\'s next guess is used', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('সব জীবকে পাঁচ দশ', alternatives: ['সজীবকে ৫০০ টাকা ধার দিলাম']);
    await settle(t);
    expect(rig.voice.spoken.last, contains('সজীবকে ৫০০ টাকা ধার দিলেন'));
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

  testWidgets('যোগাযোগ: from তথ্য, each person has call, SMS and WhatsApp', (t) async {
    final rig = await start(t, data: AppData(contacts: [Contact(name: 'রহিম', phone: '01712345678')]));
    await openMenu(t, 'যোগাযোগ');
    await t.tap(find.byTooltip('ফোন দিন'));
    await settle(t);
    final l = rig.services.launcher as FakeLauncher;
    expect(l.opened.single.toString(), 'tel:01712345678');
    await t.tap(find.byTooltip('WhatsApp'));
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'আসছি');
    await t.tap(find.text('খুলুন'));
    await settle(t);
    expect(l.opened.last.toString(), startsWith('https://wa.me/8801712345678'));
  });

  testWidgets('chat keeps listening through silence, then rests the mic', (t) async {
    final rig = await start(t);
    await openChat(t);
    for (var i = 0; i < 4; i++) {
      rig.voice.say('');
      await settle(t);
    }
    expect(find.textContaining('মাইক বন্ধ রাখলাম'), findsOneWidget);
    await t.tap(find.text('বলুন'));
    await settle(t);
    rig.voice.say('তুমি কেমন আছো?');
    await settle(t);
    expect(rig.voice.spoken.last, contains('ভালো আছি'));
  });

  testWidgets('"৫.৩০ এ রিমাইন্ডার দিও": today at 17:30, asks what for, then saves', (t) async {
    final rig = await start(t);
    await openChat(t);
    expect(rig.voice.spoken.last, 'আমি শুনছি', reason: 'said while the mic is already open');
    rig.voice.say('৫.৩০ এ রিমাইন্ডার দিও');
    await settle(t);
    expect(rig.voice.spoken.last, contains('কী বিষয়ে'));
    rig.voice.say('ওষুধ খাওয়া');
    await settle(t);
    expect(rig.voice.spoken.last, contains('দেব — ঠিক আছে?'));
    rig.voice.say('হ্যাঁ');
    await settle(t);
    final r = rig.brain.data.reminders.single;
    expect(r.date, DateTime(2026, 10, 9));
    expect(r.hour, 17);
    expect(r.minute, 30);
    expect(r.title, contains('ওষুধ'));
  });

  testWidgets('a reminder with no time asks when; "আজ" then "৬.২০" is this evening', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('বাজারের রিমাইন্ডার দিও');
    await settle(t);
    expect(rig.voice.spoken.last, contains('কখন মনে করাব'));
    rig.voice.say('আজ');
    await settle(t);
    expect(rig.voice.spoken.last, contains('কয়টায়'));
    rig.voice.say('৬.২০');
    await settle(t);
    expect(rig.voice.spoken.last, contains('দেব — ঠিক আছে?'));
    rig.voice.say('হ্যাঁ');
    await settle(t);
    final r = rig.brain.data.reminders.single;
    expect(r.hour, 18);
    expect(r.minute, 20);
  });

  testWidgets('own spending goes to আয়-ব্যয় with its খাত', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('বাজারে ৫০০ টাকা খরচ হলো');
    await settle(t);
    expect(rig.voice.spoken.last, contains('খরচ হিসেবে লিখি'));
    rig.voice.say('হ্যাঁ');
    await settle(t);
    final c = rig.brain.data.cash.single;
    expect(c.category, 'বাজার');
    expect(c.amount, 500);
    expect(rig.voice.spoken.last, contains('এই মাসে মোট খরচ'));
    expect(rig.brain.data.ledger, isEmpty);
  });

  testWidgets('project money: a new project, money in, money out, what is left', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('রহিম ভবন প্রজেক্টে ৫০ হাজার টাকা এলো');
    await settle(t);
    expect(rig.voice.spoken.last, contains('নতুন আলাদা হিসাব খুলে'));
    rig.voice.say('হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.projects.single.name, 'রহিম ভবন');
    rig.voice.say('রহিম ভবন প্রজেক্টে রড কিনলাম ২০ হাজার টাকা');
    await settle(t);
    rig.voice.say('হ্যাঁ');
    await settle(t);
    expect(rig.voice.spoken.last, contains('৩০,০০০'));
    expect(rig.brain.data.cash.every((e) => e.projectId == rig.brain.data.projects.single.id), isTrue);
  });

  testWidgets('a reminder every 30 minutes is scheduled as a repeat', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('প্রতি ৩০ মিনিটে পানি খাওয়ার কথা মনে করিয়ে দিও');
    await settle(t);
    expect(rig.voice.spoken.last, contains('প্রথমবার'));
    rig.voice.say('হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.reminders.single.repeat, Repeat.every30);
    expect(rig.notifier.scheduled.single.every, const Duration(minutes: 30));
  });

  testWidgets('হিসাব tab opens on আয়-ব্যয়, then ধার-দেনা and প্রজেক্ট', (t) async {
    await start(t, data: AppData(cash: [CashEntry(kind: CashKind.expense, amount: 500, category: 'বাজার', date: DateTime(2026, 10, 5))]));
    await openMenu(t, 'হিসাব');
    expect(find.text('এই মাসের ব্যালেন্স'), findsOneWidget);
    expect(find.text('বাজার'), findsWidgets);
    await t.tap(find.text('ধার-দেনা'));
    await settle(t);
    expect(find.text('আমি পাব'), findsOneWidget);
    expect(find.text('আমি দেব'), findsOneWidget);
  });

  testWidgets('two people with the same name stay apart by their numbers', (t) async {
    final rig = await start(t,
        data: AppData(ledger: [
          LedgerEntry(person: 'রহিম', phone: '01712345678', kind: LedgerKind.lent, amount: 4000, date: DateTime(2026, 10, 1)),
          LedgerEntry(person: 'রহিম', phone: '01819876543', kind: LedgerKind.borrowed, amount: 4000, date: DateTime(2026, 10, 2)),
        ]));
    await openMenu(t, 'হিসাব');
    await t.tap(find.text('ধার-দেনা'));
    await settle(t);
    expect(find.text('রহিম'), findsNWidgets(2));
    expect(find.textContaining('০১৭১২-৩৪৫৬৭৮'), findsOneWidget);
    expect(find.textContaining('০১৮১৯-৮৭৬৫৪৩'), findsOneWidget);
    // A number given once is in যোগাযোগ too.
    await rig.brain.saveEntry(LedgerEntry(person: 'করিম', phone: '01711223344', kind: LedgerKind.lent, amount: 100, date: DateTime(2026, 10, 9)));
    expect(rig.brain.data.contacts.single.phone, '01711223344');
    // Said by voice without a number: the রহিম used most recently.
    await rig.brain.saveEntry(LedgerEntry(person: 'রহিম', kind: LedgerKind.repaid, amount: 1000, date: DateTime(2026, 10, 9)));
    expect(rig.brain.data.ledger.last.phone, '01819876543');
  });

  testWidgets('+ যোগ করুন on the home makes a reminder that rings at the chosen time', (t) async {
    final rig = await start(t);
    // Today's list is on the home itself.
    await t.scrollUntilVisible(find.text('যোগ করুন'), 200, scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(find.text('যোগ করুন'));
    await settle(t);
    await t.tap(find.text('যোগ করুন'));
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'ক্লায়েন্ট মিটিং');
    await t.ensureVisible(find.text('রাখুন'));
    await settle(t);
    await t.tap(find.text('রাখুন'));
    await settle(t);
    final r = rig.brain.data.reminders.single;
    expect(r.hour, 16);
    expect(r.date, DateTime(2026, 10, 9));
    expect(rig.notifier.scheduled.single.at, DateTime(2026, 10, 9, 16, 0));
  });

  testWidgets('a ringing reminder opens the alarm page; snooze rings again', (t) async {
    final rig = await start(t, data: AppData(reminders: [Reminder(id: 'r1', title: 'ওষুধ খাওয়া', date: DateTime(2026, 10, 9), hour: 16)]));
    rig.notifier.tapped.value = const NoticeTap(NoticeInfo('r1', 'ওষুধ খাওয়া', '', false));
    await settle(t);
    expect(find.text('হয়ে গেছে, বন্ধ করো'), findsOneWidget);
    await t.tap(find.text('১০ মিনিট'));
    await settle(t);
    expect(rig.notifier.rung, ['ওষুধ খাওয়া']);
    expect(find.text('হয়ে গেছে, বন্ধ করো'), findsNothing);
  });

  testWidgets('"আর বাজাবে না" on the notification stops a repeating reminder for good; an alarm switched off goes quiet', (t) async {
    final rig = await start(t,
        data: AppData(reminders: [
          Reminder(id: 'w', title: 'পানি খাওয়া', date: DateTime(2026, 10, 9), hour: 16, repeat: Repeat.every30),
          Reminder(id: 'a', title: 'ঘুম থেকে ওঠা', date: DateTime(2026, 10, 10), hour: 6, repeat: Repeat.daily, alarm: true),
        ]));
    await rig.brain.refreshNotices();
    expect(rig.notifier.scheduled.map((n) => n.reminderId), containsAll(['w', 'a']));
    // The button on the notification: no alarm page, it simply stops.
    rig.notifier.tapped.value = const NoticeTap(NoticeInfo('w', 'পানি খাওয়া', '', true), action: 'stop');
    await settle(t);
    expect(find.text('আর বাজাবে না'), findsNothing);
    expect(rig.brain.reminderById('w'), isNull);
    expect(rig.notifier.stopped, contains('w'));
    expect(rig.notifier.scheduled.map((n) => n.reminderId), isNot(contains('w')));
    // An alarm switched off: kept, silenced, not scheduled.
    await rig.brain.saveReminder(rig.brain.reminderById('a')!.copyWith(enabled: false));
    expect(rig.notifier.stopped, contains('a'));
    expect(rig.notifier.scheduled.map((n) => n.reminderId), isNot(contains('a')));
    expect(rig.brain.reminderById('a')!.enabled, isFalse);
  });

  testWidgets('ফোনবুক থেকে আনুন brings every number once, skipping repeats', (t) async {
    final rig = await start(t, data: AppData(contacts: [Contact(name: 'রহিম', phone: '01712345678')]));
    rig.phonebook.contacts = const [
      PhoneContact('Rahim Office', '+880 1712-345678'),
      PhoneContact('করিম', '০১৮১১-২২৩৩৪৪'),
      PhoneContact('করিম ভাই', '01811223344'),
      PhoneContact('Service', '121'),
    ];
    await openMenu(t, 'যোগাযোগ');
    await t.tap(find.text('ফোনবুক থেকে নতুন নম্বর আনুন'));
    await settle(t);
    expect(rig.brain.data.contacts.map((c) => c.phone), ['01712345678', '01811223344']);
    expect(find.textContaining('১ জনের নম্বর আনা হলো'), findsOneWidget);
    // Asked again: nothing new.
    expect(await rig.brain.importPhonebook(), (0, 3));
  });

  testWidgets('a chosen ringtone is used for every reminder', (t) async {
    final rig = await start(t, data: AppData(reminders: [Reminder(title: 'ওষুধ', date: DateTime(2026, 10, 9), hour: 16)]));
    await rig.brain.setAlarmSound('content://media/internal/audio/media/7', 'Morning');
    expect(rig.notifier.soundUri, 'content://media/internal/audio/media/7');
    expect(rig.brain.alarmSoundTitle, 'Morning');
    await rig.brain.setAlarmSound('content://settings/system/alarm_alert', '');
    expect(rig.notifier.soundUri, isNull);
  });

  testWidgets('two people with the name: asks which one, then calls the one chosen', (t) async {
    final rig = await start(t,
        data: AppData(contacts: [
          Contact(name: 'মোবারক ভাই', phone: '01711000001'),
          Contact(name: 'মোবারক হোসেন', phone: '01811000003'),
          Contact(name: 'ইবনে সিনা মোস্তাফিজ ভাই', phone: '01911000002'),
        ]));
    await openChat(t);
    rig.voice.say('মোবারককে ফোন দাও');
    await settle(t);
    expect(rig.voice.spoken.last, contains('২ জন আছেন'));
    final l = rig.services.launcher as FakeLauncher;
    expect(l.opened, isEmpty);
    rig.voice.say('দ্বিতীয় জন');
    await settle(t);
    expect(l.opened.single.toString(), 'tel:01811000003');
  });

  testWidgets('a day\'s list over several breaths is kept until "শেষ", then saved on one yes', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('আজকের কাজের তালিকা');
    await settle(t);
    expect(rig.voice.spoken.last, contains('একটা একটা করে'));
    final spokenBefore = rig.voice.spoken.length;
    rig.voice.say('সকালে ঘুম থেকে উঠে স্কুলে যাবো');
    await settle(t);
    rig.voice.say('বিকেলে বাজার করব তারপর ব্যাংকে যাবো');
    await settle(t);
    expect(rig.voice.spoken.length, spokenBefore);
    expect(rig.brain.data.tasks, isEmpty);
    rig.voice.say('শেষ');
    await settle(t);
    expect(rig.voice.spoken.last, contains('৩টা কাজ পেলাম'));
    rig.voice.say('হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.tasks, hasLength(3));
    expect(rig.brain.data.tasks.every((x) => x.due == DateTime(2026, 10, 9)), isTrue);
  });

  testWidgets('a sentence ending in "আর" waits for the rest', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('রবিনকে ৫০০ টাকা ধার দিলাম আর');
    await settle(t);
    final before = rig.voice.spoken.length;
    expect(rig.brain.data.ledger, isEmpty);
    rig.voice.say('করিমকে ২০০ টাকা ধার দিলাম');
    await settle(t);
    expect(rig.voice.spoken.length, before + 1);
    expect(rig.voice.spoken.last, contains('২টা জিনিস পেলাম'));
  });

  testWidgets('ringtones can be heard before choosing', (t) async {
    final rig = await start(t);
    await openMenu(t, 'আমি');
    await t.scrollUntilVisible(find.text('রিমাইন্ডারের রিংটোন'), 200);
    await t.tap(find.text('রিমাইন্ডারের রিংটোন'));
    await settle(t);
    await t.tap(find.text('Morning'));
    await settle(t);
    expect(rig.notifier.played, ['content://media/internal/audio/media/7']);
    await t.tap(find.text('রাখুন'));
    await settle(t);
    expect(rig.notifier.soundUri, 'content://media/internal/audio/media/7');
  });

  testWidgets('typed to the assistant: understood like speech, and a typed password goes to the vault', (t) async {
    final rig = await start(t);
    await openTyping(t);
    await t.enterText(find.byType(TextField).first, 'রবিনকে ৫০০০ টাকা ধার দিলাম');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await settle(t);
    expect(find.text('রবিনকে ৫০০০ টাকা ধার দিলাম'), findsNWidgets(2));
    expect(find.textContaining('তাই তো'), findsOneWidget);
    await t.tap(find.widgetWithText(ActionChip, 'হ্যাঁ'));
    await settle(t);
    expect(rig.brain.data.ledger.single.amount, 5000);
    await t.enterText(find.byType(TextField).last, 'ফেসবুকের পাসওয়ার্ড ১২২৩৯৯৩৯');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'হ্যাঁ');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await settle(t);
    expect(rig.brain.data.vault.single.name, 'ফেসবুক');
    expect(rig.brain.data.vault.single.password, '12239939');
    expect(rig.voice.spoken.join(' '), isNot(contains('১২২৩৯৯৩৯')));
    expect(rig.ai.asked, isEmpty);

    // Kept in "আগের কথা", without the password.
    await t.tap(find.byTooltip('আগের কথা'));
    await settle(t);
    expect(find.text('রবিনকে ৫০০০ টাকা ধার দিলাম'), findsWidgets);
    final saved = await rig.services.lock.keys.read('chat_history');
    expect(saved, isNot(contains('১২২৩৯৯৩৯')));
  });

  testWidgets('money typed to a name in যোগাযোগ: the number is found and shown before saving', (t) async {
    final rig = await start(t, data: AppData(contacts: [Contact(name: 'Robin Bhai', phone: '01711223344')]));
    await openChat(t);
    rig.voice.say('রবিনকে ৫০০০ টাকা ধার দিলাম');
    await settle(t);
    expect(find.textContaining('০১৭১১-২২৩৩৪৪'), findsOneWidget);
    rig.voice.say('হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.ledger.single.phone, '01711223344');
  });

  testWidgets('a common question is one tap above the text box', (t) async {
    final rig = await start(t, data: AppData(ledger: [LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 500, date: DateTime(2026, 10, 5))]));
    await openTyping(t);
    await t.tap(find.text('আমার মোট পাওনা কত?'));
    await settle(t);
    expect(find.textContaining('৫০০'), findsWidgets);
    expect(rig.brain.data.ledger, hasLength(1));
  });

  testWidgets('with AI on, a question about saved reminders is answered by the AI from the records', (t) async {
    final rig = await start(t,
        data: AppData(reminders: [Reminder(title: 'বাজার', date: DateTime(2026, 10, 9), hour: 18, minute: 20)]),
        ai: {
          'reply': 'আজ ১টা রিমাইন্ডার আছে:\n• সন্ধ্যা ৬টা ২০ — বাজার',
          'items': [
            {'action': 'reminder_query', 'terms': ['আজ']},
          ],
        });
    await openTyping(t);
    await t.enterText(find.byType(TextField).first, 'আজ কোন রিমাইন্ডার আছে?');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await settle(t);
    expect(rig.ai.contexts.last.records, contains('বাজার'));
    expect(find.textContaining('• সন্ধ্যা ৬টা ২০ — বাজার'), findsOneWidget);
    expect(find.textContaining('তারিখ তো লেখা নেই'), findsNothing);
  });

  testWidgets('home shows both dates, sun times and the next holiday; the calendar opens', (t) async {
    await start(t);
    expect(find.text('২৪ আশ্বিন ১৪৩৩'), findsOneWidget);
    expect(find.textContaining('সূর্যোদয়'), findsOneWidget);
    expect(find.textContaining('দুর্গাপূজা'), findsOneWidget);
    await t.scrollUntilVisible(find.text('ক্যালেন্ডার').first, 300, scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(find.text('ক্যালেন্ডার').first);
    await settle(t);
    await t.tap(find.text('ক্যালেন্ডার').first);
    await settle(t);
    expect(find.byType(CalendarScreen), findsOneWidget);
    await t.scrollUntilVisible(find.text('মহান বিজয় দিবস'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('মহান বিজয় দিবস'), findsOneWidget);
  });

  testWidgets('search finds a contact and a note together', (t) async {
    await start(t,
        data: AppData(
          contacts: [Contact(name: 'রহিম', phone: '01712345678')],
          notes: [Note(title: 'রহিম ভবনের নকশা', body: 'রহিম ভবনের নকশা আলমারিতে', category: 'বাসা')],
        ));
    // Typing in the box at the bottom shows matches right above it…
    await t.tap(find.text('খুঁজুন, রাখুন বা জিজ্ঞেস করুন…'));
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'র');
    await settle(t);
    // The keyboard stays open after the first letter.
    expect(t.widget<EditableText>(find.byType(EditableText).last).focusNode.hasFocus, isTrue);
    expect(t.testTextInput.isVisible, isTrue);
    await t.enterText(find.byType(TextField).last, 'রহিম');
    await settle(t);
    expect(t.widget<EditableText>(find.byType(EditableText).last).focusNode.hasFocus, isTrue);
    expect(find.text('রহিম ভবনের নকশা'), findsOneWidget);
    expect(find.textContaining('সহকারীকে বলুন'), findsOneWidget);
    // …and the full results page groups them.
    await t.tap(find.text('সব মিল দেখুন'));
    await settle(t);
    expect(find.textContaining('যোগাযোগ ·'), findsOneWidget);
    expect(find.textContaining('নোট ·'), findsOneWidget);
  });

  testWidgets('দিনলিপি shows today with the Bangla date, and the week', (t) async {
    await start(t, data: AppData(reminders: [Reminder(title: 'ওষুধ', date: DateTime(2026, 10, 9), hour: 20)]));
    await t.tap(find.text('দিনলিপি').last);
    await settle(t);
    expect(find.textContaining('২৪ আশ্বিন'), findsWidgets);
    expect(find.text('ওষুধ'), findsWidgets);
    await t.tap(find.text('সাপ্তাহিক'));
    await settle(t);
    expect(find.textContaining('শনিবার'), findsWidgets);
  });

  testWidgets('voice: loan, money back, then a question that saves nothing; a missing amount is asked', (t) async {
    final rig = await start(t);
    await openChat(t);
    rig.voice.say('সজীবকে পাঁচশ টাকা ধার দিয়েছি');
    await settle(t);
    expect(rig.voice.spoken.last, contains('৫০০'));
    rig.voice.say('হ্যাঁ');
    await settle(t);
    rig.voice.say('সজীব আমাকে তিনশ টাকা ফেরত দিয়েছে');
    await settle(t);
    rig.voice.say('হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.ledger.map((e) => e.kind), [LedgerKind.lent, LedgerKind.received]);
    rig.voice.say('সজীবের কাছে কত টাকা পাই?');
    await settle(t);
    expect(rig.voice.spoken.last, contains('২০০'));
    expect(rig.brain.data.ledger, hasLength(2));
    rig.voice.say('সজীবকে টাকা দিয়েছি');
    await settle(t);
    expect(rig.voice.spoken.last, contains('কত টাকার'));
    expect(rig.brain.data.ledger, hasLength(2));
  });

  testWidgets('an alarm for office days rings six days a week', (t) async {
    final rig = await start(t);
    await t.scrollUntilVisible(find.text('অ্যালার্ম'), 300, scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(find.text('অ্যালার্ম'));
    await settle(t);
    await t.tap(find.text('অ্যালার্ম'));
    await settle(t);
    await t.tap(find.byTooltip('নতুন অ্যালার্ম'));
    await settle(t);
    await t.tap(find.text('অফিসের দিন'));
    await settle(t);
    await t.tap(find.text('অ্যালার্ম রাখুন'));
    await settle(t);
    final r = rig.brain.data.reminders.single;
    expect(r.alarm, isTrue);
    expect(r.repeat, Repeat.weekly);
    expect(r.weekdays, hasLength(6));
    expect(rig.notifier.scheduled, hasLength(6));
  });

  testWidgets('a document photo is kept encrypted in a folder', (t) async {
    final rig = await start(t);
    rig.files.photo = PickedDoc(Uint8List.fromList(List.generate(3000, (i) => i % 251)), 'nid.jpg', 'image/jpeg');
    await t.tap(find.text('সংরক্ষণ').last);
    await settle(t);
    await t.tap(find.text('ডকুমেন্টস'));
    await settle(t);
    await t.tap(find.text('গ্যালারি'));
    await settle(t);
    // The form: a name, a folder and a few words.
    await t.enterText(find.widgetWithText(TextField, 'নাম'), 'আমার NID');
    await t.tap(find.widgetWithText(ChoiceChip, 'জাতীয় পরিচয়পত্র'));
    await settle(t);
    await t.ensureVisible(find.text('রাখুন').last);
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    final d = rig.brain.data.docs.single;
    expect(d.title, 'আমার NID');
    expect(d.folder, 'জাতীয় পরিচয়পত্র');
    expect(d.files.single.size, 3000);
    expect((await rig.brain.docBytes(d.files.single))!.length, 3000);
  });

  testWidgets('v2.10: many photos at once, one group with a description, found again by asking', (t) async {
    final rig = await start(t);
    PickedDoc photo(String n) => PickedDoc(Uint8List.fromList(List.generate(500, (i) => i % 251)), n, 'image/jpeg');
    rig.files.photos = [photo('1.jpg'), photo('2.jpg'), photo('3.jpg')];
    await t.tap(find.text('সংরক্ষণ').last);
    await settle(t);
    await t.tap(find.text('ডকুমেন্টস'));
    await settle(t);
    await t.tap(find.text('গ্যালারি'));
    await settle(t);
    await t.tap(find.text('সবগুলো এক সাথে, একটা গ্রুপে'));
    await settle(t);
    await t.enterText(find.widgetWithText(TextField, 'নাম'), 'ভাইয়ের বিয়ে');
    await t.enterText(find.widgetWithText(TextField, 'কী আছে (বিবরণ)'), 'গায়ে হলুদ আর বিয়ের দিনের ছবি');
    await t.enterText(find.widgetWithText(TextField, 'কোথায়'), 'ফেনী');
    await t.ensureVisible(find.text('রাখুন').last);
    await t.tap(find.text('রাখুন').last);
    await settle(t);
    final d = rig.brain.data.docs.single;
    expect(d.files, hasLength(3));
    expect((d.about, d.place), ('গায়ে হলুদ আর বিয়ের দিনের ছবি', 'ফেনী'));
    // Asked in the chat: the answer names it and a button opens it.
    Navigator.of(t.element(find.byType(Scaffold).first)).popUntil((r) => r.isFirst);
    await settle(t);
    await openTyping(t);
    await t.enterText(find.byType(TextField).first, 'বিয়ের ছবিগুলো দেখাও');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await settle(t);
    expect(find.textContaining('ভাইয়ের বিয়ে'), findsWidgets);
    expect(find.textContaining('দেখুন: ভাইয়ের বিয়ে'), findsOneWidget);
  });

  testWidgets('v2.10: a loan with a pay-back day gets a reminder; deleting the loan removes it', (t) async {
    final rig = await start(t);
    final e = LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 5000, date: DateTime(2026, 10, 9), due: DateTime(2026, 11, 9));
    await rig.brain.saveEntry(e);
    final saved = rig.brain.data.ledger.single;
    final r = rig.brain.reminderById(saved.reminderId!)!;
    expect(r.title, contains('রহিম'));
    expect((r.date, r.daysBefore), (DateTime(2026, 11, 9), 1));
    expect(rig.notifier.scheduled.any((n) => n.reminderId == r.id), isTrue);
    // A new date replaces the old reminder.
    await rig.brain.saveEntry(saved.copyWith(due: DateTime(2026, 12, 1)));
    expect(rig.brain.data.reminders.single.date, DateTime(2026, 12, 1));
    await rig.brain.deleteEntry(saved.id);
    expect(rig.brain.data.reminders, isEmpty);
  });

  testWidgets('v2.10: a note keeps photos and a tick-box list', (t) async {
    final rig = await start(t);
    PickedDoc photo(String n) => PickedDoc(Uint8List.fromList(List.generate(300, (i) => i % 251)), n, 'image/jpeg');
    rig.files.photos = [photo('a.jpg'), photo('b.jpg')];
    await openMenu(t, 'নোট');
    await t.tap(find.byTooltip('নতুন নোট'));
    await settle(t);
    await t.enterText(find.widgetWithText(TextFormField, 'শিরোনাম'), 'বাজারের তালিকা');
    await t.tap(find.text('টিক দেওয়ার তালিকা'));
    await settle(t);
    await t.enterText(find.byType(TextField).at(2), 'ডিম');
    await t.ensureVisible(find.text('ছবি ও ফাইল'));
    await t.tap(find.text('যোগ করুন').last);
    await settle(t);
    await t.tap(find.text('গ্যালারি থেকে (একাধিক)'));
    await settle(t);
    expect(find.text('ছবি ও ফাইল · ২'), findsOneWidget);
    await t.tap(find.text('সেভ করুন').last);
    await settle(t);
    final n = rig.brain.data.notes.single;
    expect(n.files, hasLength(2));
    expect(n.body, '[ ] ডিম');
  });

  testWidgets('v2.9: a birthday said in chat is saved yearly, and ফিরিয়ে নিন takes it back', (t) async {
    final rig = await start(t);
    await openTyping(t);
    await t.enterText(find.byType(TextField).first, 'রহিমের জন্মদিন ১২ মার্চ');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await settle(t);
    expect(find.textContaining('মনে করিয়ে দেবো'), findsWidgets);
    await t.tap(find.widgetWithText(ActionChip, 'হ্যাঁ'));
    await settle(t);
    final s = rig.brain.data.specialDays.single;
    expect((s.person, s.month, s.day), ('রহিম', 3, 12));
    final r = rig.brain.reminderById(s.reminderId!)!;
    expect(r.repeat, Repeat.yearly);
    expect(r.daysBefore, 1);
    expect(find.text('ফিরিয়ে নিন'), findsOneWidget);
    await t.tap(find.text('ফিরিয়ে নিন'));
    await settle(t);
    expect(rig.brain.data.specialDays, isEmpty);
    expect(rig.brain.data.reminders, isEmpty);
    expect(find.textContaining('ফিরিয়ে নিলাম'), findsOneWidget);
  });

  testWidgets('v2.9: "মনে রেখো রহিম আমার শ্যালক" goes to the assistant memory', (t) async {
    final rig = await start(t);
    await openTyping(t);
    await t.enterText(find.byType(TextField).first, 'মনে রেখো রহিম আমার শ্যালক');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await settle(t);
    await t.tap(find.widgetWithText(ActionChip, 'হ্যাঁ'));
    await settle(t);
    expect(rig.brain.data.memories.single.text, contains('শ্যালক'));
    expect(rig.brain.recordsSummary(), contains('শ্যালক'));
  });

  testWidgets('v2.9: settings switch the app to English and to dark, and back', (t) async {
    final rig = await start(t);
    await openMenu(t, 'সেটিংস');
    expect(find.text('সেটিংস'), findsWidgets);
    await t.tap(find.text('English'));
    await settle(t);
    expect(rig.brain.english, isTrue);
    expect(find.text('Settings'), findsWidgets);
    await t.tap(find.text('Dark'));
    await settle(t);
    expect(rig.brain.look, Look.dark);
    expect(C.dark, isTrue);
    expect(await rig.services.lock.keys.read('lang'), 'en');
    await t.tap(find.text('বাংলা'));
    await settle(t);
    await t.tap(find.text('আলো'));
    await settle(t);
    expect(C.dark, isFalse);
    expect(find.text('সেটিংস'), findsWidgets);
  });

  testWidgets('v2.9: first run asks what the user does; a shopkeeper gets the shop tools', (t) async {
    showOnboarding = true;
    addTearDown(() => showOnboarding = false);
    t.view.physicalSize = const Size(1170, 2532);
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    await loadFonts();
    final rig = Rig();
    await t.pumpWidget(DigitalBrainApp(brain: rig.brain));
    await rig.brain.load();
    await settle(t);
    await enterPin(t, '1234');
    await enterPin(t, '1234');
    await settle(t);
    expect(find.text('আপনি কী করেন?'), findsOneWidget);
    await t.tap(find.text('ব্যবসায়ী / দোকানদার'));
    await settle(t);
    await t.tap(find.text('শুরু করি'));
    await settle(t);
    expect(rig.brain.persona, 'business');
    expect(rig.brain.businessMode, isTrue);
    expect(rig.brain.data.tasks.where((x) => x.list == 'মাসের বাজার'), isNotEmpty);
    expect(rig.brain.quickQuestions.first, 'আজ কত বিক্রি হলো?');
    await t.tap(find.text('হিসাব').last);
    await settle(t);
    expect(find.text('আজকের বিক্রি'), findsOneWidget);
  });

  testWidgets('v2.9: every new page opens, in Bangla and in English, light and dark', (t) async {
    final now = DateTime(2026, 10, 9, 15, 53);
    final rig = await start(t,
        data: AppData(
          specialDays: [SpecialDay(person: 'রহিম', month: 10, day: 10, phone: '01711111111')],
          habits: [Habit(name: 'হাঁটা', done: ['2026-10-08'])],
          medicines: [Medicine(name: 'নাপা', times: [540, 1260], stock: 8)],
          accounts: [MoneyAccount(name: 'বিকাশ', kind: AccountKind.bkash, opening: 500), MoneyAccount(name: '', kind: AccountKind.cash)],
          goals: [SavingsGoal(name: 'ঈদ', target: 10000, deadline: DateTime(2027, 3, 1))],
          installments: [Installment(name: 'DPS', amount: 1000, start: DateTime(2026, 1))],
          cash: [CashEntry(kind: CashKind.expense, amount: 500, category: 'বাজার', date: now), CashEntry(kind: CashKind.income, amount: 900, category: 'বিক্রি', date: now)],
          ledger: [LedgerEntry(person: 'করিম', phone: '01722222222', kind: LedgerKind.lent, amount: 300, date: now)],
          docs: [Doc(title: 'পাসপোর্ট', expiry: DateTime(2027, 6, 1))],
          memories: [Memory(text: 'আমি চা খাই না')],
          emergency: const EmergencyCard(name: 'সাইফুল', blood: 'B+', contacts: ['মা|01711111111|মা'], medicines: 'নাপা'),
          tags: {'note:n1': ['গাড়ি']},
          notes: [Note(id: 'n1', title: 'গাড়ির কাগজ', body: 'আলমারিতে')],
        ));
    final pages = <Widget>[
      const SpecialDaysScreen(), const HabitsScreen(), const MedicinesScreen(), const AccountsScreen(), const ReportScreen(), const SavingsScreen(),
      const SplitScreen(), const ZakatScreen(), const ShopScreen(), const ReceiptScreen(), const EmergencyScreen(), const EmergencyEditScreen(),
      const TagsScreen(), const TagScreen(tag: 'গাড়ি'), const ExpiryScreen(), const TemplatesScreen(), const MemoryScreen(), const OnboardingScreen(fromSettings: true),
      const MenuPage(child: MoreScreen()), const SearchScreen(initial: 'Rahim'),
    ];
    for (final (english, look) in [(false, Look.light), (true, Look.dark)]) {
      await rig.brain.setEnglish(english);
      await rig.brain.setLook(look);
      await settle(t);
      final nav = t.state<NavigatorState>(find.byType(Navigator).first);
      for (final p in pages) {
        nav.push(MaterialPageRoute(builder: (_) => p));
        await settle(t, 6);
        expect(t.takeException(), isNull, reason: '${p.runtimeType} ($english, $look)');
        nav.pop();
        await settle(t, 4);
      }
    }
    await rig.brain.setEnglish(false);
    await rig.brain.setLook(Look.light);
  });
}
