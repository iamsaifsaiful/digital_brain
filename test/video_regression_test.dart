// From a screen recording (16 Oct 2026): "৫ হাজার টাকা দিলাম ইসমাইলকে আজকে
// 5000 টাকা দিলাম না আর বলতে চাই না" became two things to save — the
// money and "বলতে চাই না". Then "বলতে চাই না এটাকে রাখার মত কিছু" (only
// that one is not worth keeping) threw away the money too.
import 'package:digital_brain/logic/dictation.dart';
import 'package:digital_brain/logic/meaning.dart';
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digital_brain/screens/chat_home.dart';

import 'app_test.dart' show start, settle;

void main() {
  group('closing words are not content', () {
    test('the words before are kept; the closing words go', () {
      for (final (said, kept) in [
        ('৫ হাজার টাকা দিলাম ইসমাইলকে আজকে 5000 টাকা দিলাম না আর বলতে চাই না', '৫ হাজার টাকা দিলাম ইসমাইলকে আজকে 5000 টাকা দিলাম'),
        ('বাজারে ৭০০ টাকা খরচ, আর কিছু বলার নেই', 'বাজারে ৭০০ টাকা খরচ'),
        ('কাল ১০টায় মিটিং মনে করিয়ে দিও। ব্যস', 'কাল ১০টায় মিটিং মনে করিয়ে দিও'),
        ('রহিমকে ৫০০ টাকা দিলাম এই পর্যন্তই', 'রহিমকে ৫০০ টাকা দিলাম'),
        ('আর কিছু বলব না', ''),
        ('না, আর বলতে চাই না', ''),
      ]) {
        final (body, done) = splitDoneTail(said);
        expect(done, isTrue, reason: said);
        expect(body, kept, reason: said);
      }
    });

    test('a real "না" or "শেষ" inside what is said stays', () {
      for (final said in ['রহিমকে টাকা দিলাম না', 'কাজটা শেষ', 'ঘরে চাল আর নেই', 'রহিমের সাথে কথা শেষ', 'আজ আর অফিসে যাব না']) {
        final (body, done) = splitDoneTail(said);
        expect(done, isFalse, reason: said);
        expect(body, said);
      }
    });

    test('"না, আর বলতে চাই না" to "আর কিছু বলতে চান?" finishes the speech', () {
      expect(continuationOf('না, আর বলতে চাই না').$1, Continue.finish);
      expect(continuationOf('আর কিছু বলার নেই').$1, Continue.finish);
      expect(endsSpeech('আর বলতে চাই না'), isTrue);
    });
  });

  group('a reply about some of the listed things', () {
    final lines = ['ইসমাইল — ৫,০০০ টাকা — লেনদেন', 'বলতে চাই না'];
    test('by repeating its words or by its number', () {
      expect(mentionedItems('বলতে চাই না এটাকে রাখার মত কিছু', lines), [1]);
      expect(mentionedItems('২ নম্বরটা রেখো না', lines), [1]);
      expect(mentionedItems('শুধু প্রথমটা রাখো', lines), [0]);
      expect(mentionedItems('শেষেরটা বাদ দাও', lines), [1]);
      expect(mentionedItems('না', lines), isEmpty);
      expect(mentionedItems('হ্যাঁ, সব রাখো', lines), isEmpty);
      expect(dropsItem('বলতে চাই না এটাকে রাখার মত কিছু'), isTrue);
      expect(dropsItem('২ নম্বরটা রাখো'), isFalse);
    });
  });

  testWidgets('the recorded speech: one thing — ইসমাইলকে ৫,০০০ টাকা — and nothing called "বলতে চাই না"', (t) async {
    final rig = await start(t);
    final chat = ChatController(rig.brain);
    final r = await chat.hear('৫ হাজার টাকা দিলাম ইসমাইলকে আজকে 5000 টাকা দিলাম না আর বলতে চাই না');
    expect(r, isNot(contains('জিনিস পেলাম')));
    expect('$r ${chat.messages.last.facts.join(' ')}', isNot(contains('বলতে চাই না')));
    // "দিলাম" alone: ধার, শোধ, না খরচ — not guessed; asked once.
    expect(r, contains('ধার'));
    expect(rig.brain.data.ledger, isEmpty);
    expect(await chat.hear('নতুন করে ধার দিলাম'), allOf(contains('ইসমাইল'), contains('৫,০০০')));
    await chat.hear('হ্যাঁ');
    final e = rig.brain.data.ledger.single;
    expect((e.person, e.amount, e.kind), ('ইসমাইল', 5000, LedgerKind.lent));
  });

  testWidgets('two things listed; "the second is not worth keeping" keeps the first', (t) async {
    final rig = await start(t);
    final chat = ChatController(rig.brain);
    final r = await chat.hear('সজীবকে ৫০০ টাকা ধার দিলাম আর কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও');
    expect(r, contains('২টা জিনিস পেলাম'));
    final again = await chat.hear('মিটিং এর টা রাখার মত কিছু না');
    expect(again, contains('১টা বাদ দিলাম'));
    expect(chat.messages.last.facts.single, contains('সজীব'));
    await chat.hear('হ্যাঁ');
    expect(rig.brain.data.ledger.single.person, 'সজীব');
    expect(rig.brain.data.ledger.single.kind, LedgerKind.lent);
    expect(rig.brain.data.reminders, isEmpty);
  });

  testWidgets('"শুধু ২ নম্বরটা রাখো" keeps only that one; a plain "না" still drops all', (t) async {
    final rig = await start(t);
    final chat = ChatController(rig.brain);
    await chat.hear('সজীবকে ৫০০ টাকা ধার দিলাম আর কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও');
    expect(await chat.hear('শুধু ২ নম্বরটা রাখো'), contains('বাকিটা রেখে দিই'));
    await chat.hear('হ্যাঁ');
    expect(rig.brain.data.ledger, isEmpty);
    expect(rig.brain.data.reminders, hasLength(1));

    await chat.hear('রহিমকে ২০০ টাকা ধার দিলাম আর পরশু বিকেল ৪টায় ডাক্তার মনে করিয়ে দিও');
    expect(await chat.hear('না'), 'আচ্ছা, কিছুই রাখলাম না।');
    expect(rig.brain.data.ledger, isEmpty);
    expect(rig.brain.data.reminders, hasLength(1));
  });

  /// The voice view from the home's mic.
  Future<ChatController> openVoice(WidgetTester t) async {
    await t.tap(find.byTooltip('বলুন').first);
    await settle(t);
    return t.state<ChatHomeState>(find.byType(ChatHome)).chat;
  }

  Future<void> quiet(WidgetTester t) async {
    await t.pump(const Duration(milliseconds: 1600));
    await settle(t);
  }

  testWidgets('scenario: one breath → one preview at once → "না, বলতে চাই না" is not a no → "হ্যাঁ, রাখো" → saved once', (t) async {
    final rig = await start(t);
    final chat = await openVoice(t);
    rig.voice.say('ইসমাইলকে পাঁচ হাজার টাকা ধার দিয়েছি।');
    await settle(t);
    await quiet(t);
    final preview = rig.voice.spoken.last;
    expect(rig.voice.spoken, isNot(contains('আর কিছু বলতে চান?')));
    expect(preview, allOf(contains('ইসমাইল'), contains('৫,০০০')));
    expect(preview, isNot(contains('জিনিস পেলাম')));
    expect(chat.wait, ChatWait.yesNo);
    // "Nothing more to say" while the save waits: asked again, nothing dropped.
    rig.voice.say('না, বলতে চাই না।');
    await settle(t);
    expect(rig.voice.spoken.last, contains('রেখে দিই'));
    expect(chat.wait, ChatWait.yesNo);
    expect(rig.brain.data.ledger, isEmpty);
    rig.voice.say('হ্যাঁ, রাখো');
    await settle(t);
    // The same "হ্যাঁ" arriving again (a repeated final result) does nothing more.
    rig.voice.say('হ্যাঁ');
    await settle(t);
    final e = rig.brain.data.ledger.single;
    expect((e.person, e.amount, e.kind), ('ইসমাইল', 5000, LedgerKind.lent));
    expect(chat.wait, ChatWait.none, reason: 'no second confirmation');
  });

  testWidgets('scenario: speech in two breaths ("…আর" then the rest) → one preview, no "বলতে চাই না" item', (t) async {
    final rig = await start(t);
    final chat = await openVoice(t);
    rig.voice.say('ইসমাইলকে পাঁচ হাজার টাকা ধার দিয়েছি আর');
    await settle(t);
    rig.voice.say('না, বলতে চাই না।');
    await settle(t);
    expect(chat.messages.where((m) => m.fromUser).single.text, 'ইসমাইলকে পাঁচ হাজার টাকা ধার দিয়েছি');
    expect(rig.voice.spoken.last, allOf(contains('ইসমাইল'), contains('৫,০০০'), isNot(contains('বলতে চাই না'))));
    expect(rig.voice.spoken, isNot(contains('আর কিছু বলতে চান?')));
    rig.voice.say('হ্যাঁ');
    await settle(t);
    expect(rig.brain.data.ledger.single.amount, 5000);
  });

  testWidgets('scenario: the same preview, "না, রেখো না" → nothing saved', (t) async {
    final rig = await start(t);
    final chat = await openVoice(t);
    rig.voice.say('ইসমাইলকে পাঁচ হাজার টাকা ধার দিয়েছি।');
    await settle(t);
    await quiet(t);
    expect(chat.wait, ChatWait.yesNo);
    rig.voice.say('না, রেখো না');
    await settle(t);
    expect(rig.brain.data.ledger, isEmpty);
    expect(chat.wait, ChatWait.none);
  });

  testWidgets('"একটা নোট রাখো — আমি বলতে চাই না": a real note, kept as said', (t) async {
    final rig = await start(t);
    final chat = ChatController(rig.brain);
    final r = await chat.hear('একটা নোট রাখো আমি বলতে চাই না');
    expect(r, isNot(contains('জিনিস পেলাম')));
    await chat.hear('হ্যাঁ');
    expect(rig.brain.data.notes.single.body, contains('বলতে চাই না'));
  });

  testWidgets('"ইসমাইলকে ৫ হাজার টাকা দিলাম": ধার, শোধ না খরচ — asked once, then one preview and one yes', (t) async {
    final rig = await start(t);
    final chat = ChatController(rig.brain);
    final r = await chat.hear('ইসমাইলকে ৫ হাজার টাকা দিলাম');
    expect(rig.brain.data.ledger, isEmpty);
    expect(r, anyOf(contains('ধার'), contains('শোধ'), contains('খরচ')));
    final asked = r;
    final r2 = await chat.hear('ধার দিলাম');
    expect(r2, isNot(asked));
    await chat.hear('হ্যাঁ');
    final e = rig.brain.data.ledger.single;
    expect((e.person, e.amount, e.kind), ('ইসমাইল', 5000, LedgerKind.lent));
  });

  testWidgets('two real transactions in one breath stay two; one said twice stays one', (t) async {
    final rig = await start(t);
    final chat = ChatController(rig.brain);
    expect(await chat.hear('রহিমকে ৫০০ টাকা ধার দিলাম আর করিমকে ৫০০ টাকা ধার দিলাম'), contains('২টা জিনিস পেলাম'));
    await chat.hear('হ্যাঁ');
    expect(rig.brain.data.ledger.map((e) => e.person).toSet(), {'রহিম', 'করিম'});
    final r = await chat.hear('ইসমাইলকে ৫ হাজার টাকা ধার দিলাম ইসমাইলকে আজকে 5000 টাকা ধার দিলাম');
    expect(r, isNot(contains('জিনিস পেলাম')));
  });

  // Second recording (17 Oct): a whole question, then quiet — the app asked
  // "আর কিছু বলতে চান?" instead of answering; "নার কিছু বলতে চাই না" (না আর,
  // run together by the recogniser) was added to the question as words.
  test('the recogniser\'s run-together "নার" and "নারে ভাই" are closing words too', () {
    for (final (said, kept) in [
      ('আমি কার কাছে কত টাকা পাব একটু বলতো নার কিছু বলতে চাই না', 'আমি কার কাছে কত টাকা পাব একটু বলতো'),
      ('নারে ভাই আর কিছু বলতে চাই না', ''),
      ('না রে ভাই, কিছু বলতে চাই না', ''),
    ]) {
      final (body, done) = splitDoneTail(said);
      expect(done, isTrue, reason: said);
      expect(body, kept, reason: said);
    }
    expect(splitDoneTail('আমি কিছু বলতে চাই না').$2, isFalse, reason: 'no "না"/"আর" before it: could be what they want noted');
  });

  testWidgets('a whole question in one breath is answered when the user goes quiet — no "আর কিছু বলতে চান?"', (t) async {
    final rig = await start(t);
    await rig.brain.saveEntry(LedgerEntry(person: 'শফিক ভাই', kind: LedgerKind.lent, amount: 5000, date: DateTime(2026, 10, 2)));
    final chat = await openVoice(t);
    rig.voice.say('আমি কার কাছে কত টাকা পাব একটু বলতো');
    await settle(t);
    await quiet(t);
    expect(rig.voice.spoken, isNot(contains('আর কিছু বলতে চান?')));
    expect(chat.messages.where((m) => m.fromUser).single.text, 'আমি কার কাছে কত টাকা পাব একটু বলতো');
    expect(rig.voice.spoken.last, contains('৫,০০০'));
    expect(chat.wait, ChatWait.none, reason: 'a question needs no confirmation');
  });

  testWidgets('a whole request in one breath goes straight to its one confirmation', (t) async {
    final rig = await start(t);
    final chat = await openVoice(t);
    rig.voice.say('রহিমকে ৫০০ টাকা ধার দিলাম');
    await settle(t);
    await quiet(t);
    expect(rig.voice.spoken, isNot(contains('আর কিছু বলতে চান?')));
    expect(rig.voice.spoken.last, contains('লিখে রাখি'));
    expect(chat.wait, ChatWait.yesNo);
  });

  testWidgets('left open ("…খরচ হচ্ছে কোন"): waits; quiet again → sent as it is, never "আর কিছু বলতে চান?"', (t) async {
    final rig = await start(t);
    final chat = await openVoice(t);
    rig.voice.say('আচ্ছা আমার এই মাসে খরচ হচ্ছে কোন');
    await settle(t);
    expect(chat.messages.where((m) => m.fromUser), isEmpty);
    rig.voice.say('খাতে বেশি');
    await settle(t);
    expect(chat.messages.where((m) => m.fromUser).single.text, 'আচ্ছা আমার এই মাসে খরচ হচ্ছে কোন খাতে বেশি');
    expect(rig.voice.spoken, isNot(contains('আর কিছু বলতে চান?')));
  });

  testWidgets('the app\'s own answer heard back a little garbled ("…টাকা পাবেন" → "টাকা পাই") is not taken as speech', (t) async {
    final rig = await start(t);
    await rig.brain.saveEntry(LedgerEntry(person: 'শফিক ভাই', kind: LedgerKind.lent, amount: 5000, date: DateTime(2026, 10, 2)));
    final chat = await openVoice(t);
    rig.voice.say('শফিক ভাইয়ের কাছে আমি টোটাল কত টাকা পাই');
    await settle(t);
    expect(chat.messages.where((m) => m.fromUser), hasLength(1));
    expect(rig.voice.spoken.last, contains('৫,০০০'));
  });

  testWidgets('"শফিক ভাইয়ের কাছে কত পাই" is about শফিক ভাই only', (t) async {
    final rig = await start(t);
    await rig.brain.saveEntry(LedgerEntry(person: 'শফিক ভাই', kind: LedgerKind.lent, amount: 5000, date: DateTime(2026, 10, 2)));
    await rig.brain.saveEntry(LedgerEntry(person: 'রহিম', kind: LedgerKind.lent, amount: 700, date: DateTime(2026, 10, 3)));
    final chat = ChatController(rig.brain);
    final r = await chat.hear('ইয়া শফিক ভাইয়ের কাছে আমি টোটাল কত টাকা পাই');
    expect(r, contains('৫,০০০'));
    expect(r, isNot(contains('৭০০')));
    // "আর কারো কাছে কি কোন টাকা পাই?": everyone.
    expect(await chat.hear('আর কারো কাছে কি কোন টাকা পাই'), contains('৭০০'));
  });

  testWidgets('"নার কিছু বলতে চাই না" after a question: answered at once, the words are not part of it', (t) async {
    final rig = await start(t);
    await rig.brain.saveEntry(LedgerEntry(person: 'শফিক ভাই', kind: LedgerKind.lent, amount: 5000, date: DateTime(2026, 10, 2)));
    final chat = await openVoice(t);
    rig.voice.say('আমি কার কাছে কত টাকা পাব একটু বলতো');
    await settle(t);
    rig.voice.say('নার কিছু বলতে চাই না');
    await settle(t);
    expect(chat.messages.where((m) => m.fromUser).single.text, 'আমি কার কাছে কত টাকা পাব একটু বলতো');
    expect(rig.voice.spoken.last, contains('৫,০০০'));
  });

  // Five recordings (17 Oct, morning): requests with "তুমি একটা কাজ করো…",
  // to-dos "… কাজের লিস্টে রাখ", "আগামীকালকে", talk to the assistant itself.
  group('the recordings of 17 Oct', () {
    Future<(ChatController, String)> ask(WidgetTester t, String s, {List<Contact> contacts = const []}) async {
      final rig = await start(t);
      for (final c in contacts) {
        await rig.brain.saveContact(c);
      }
      final chat = ChatController(rig.brain);
      return (chat, await chat.hear(s));
    }

    testWidgets('"… এটা একটা কাজের লিস্টে রাখ" is a to-do with its day, title without the filler', (t) async {
      final (_, r) = await ask(t, 'আগামীকালকে সকাল দশটায় আমাকে সোনার মণি যাইতে হবে এটা একটা কাজের লিস্টে রাখ');
      expect(r, contains('“সোনার মণি যাইতে হবে”'));
      expect(r, contains('কাল'));
      expect(r, contains('কাজের তালিকায়'));
    });

    testWidgets('"২০ তারিখে সিঙ্গাপুর যাইতে হবে এটা … কাজের তালিকায় লিখে রাখো" is a to-do, not a question about the 20th', (t) async {
      for (final s in [
        'তারপরে আমাকে ২০ তারিখে আমাকে সিঙ্গাপুর যাইতে হবে এটা একটা কাজের তালিকা তুলে রাখ',
        'বললাম ২০ তারিখে আমাকে সিঙ্গাপুর যাইতে হবে এটা আমাকে কাজের তালিকায় লিখে রাখো',
      ]) {
        final rig = await start(t);
        final chat = ChatController(rig.brain);
        final r = await chat.hear(s);
        expect(r, allOf(contains('“সিঙ্গাপুর যাইতে হবে”'), contains('২০ অক্টোবর'), contains('কাজের তালিকায়')), reason: s);
        await chat.hear('হ্যাঁ');
        expect(rig.brain.data.tasks.single.due, DateTime(2026, 10, 20), reason: s);
      }
    });

    testWidgets('"তুমি এক কাজ করো আগামীকালকে সকাল দশটায় আমাকে একটা এলার্ম সেট করে দাও": an alarm, tomorrow 10:00', (t) async {
      final (_, r) = await ask(t, 'তুমি এক কাজ করো আগামীকালকে সকাল দশটায় আমাকে একটা এলার্ম সেট করে দাও');
      expect(r, contains('কাল'));
      expect(r, contains('১০টা'));
      expect(r, isNot(contains('তুমি')));
      expect(r, isNot(contains('কাজ করো')));
    });

    testWidgets('"রিমাইন্ডার সেট করে দাও" with no subject: the app asks, the words are not the title', (t) async {
      final (_, r) = await ask(t, 'তুমি একটা কাজ করো তো আমাকে আগামী কালকের একটা রিমাইন্ডার সেট করে দাও');
      expect(r, isNot(contains('সেট করে দাও')));
      expect(r, isNot(contains('তুমি')));
    });

    testWidgets('a whole new request while a save waits replaces it — never saved by the "দাও" in it', (t) async {
      final rig = await start(t);
      final chat = ChatController(rig.brain);
      await chat.hear('আজ সন্ধ্যা ৭টায় মিটিং মনে করিয়ে দিও');
      expect(chat.wait, ChatWait.yesNo);
      final r = await chat.hear('আগামীকাল সকাল দশটায় আমাকে একটা এলার্ম সেট করে দাও');
      expect(rig.brain.data.reminders, isEmpty, reason: 'the first one is not saved');
      expect(r, contains('১০টা'));
      await chat.hear('হ্যাঁ');
      final saved = rig.brain.data.reminders.single;
      expect((saved.date, saved.hour), (DateTime(2026, 10, 10), 10));
    });

    testWidgets('talk to the assistant itself is answered, never filed as a note', (t) async {
      final rig = await start(t);
      final chat = ChatController(rig.brain);
      expect(await chat.hear('এই তুমি কি আমার কথা বুঝতেছো'), contains('বুঝছি'));
      expect(rig.brain.bargeIn, isFalse);
      final r = await chat.hear('আমি তোমার কথা বলার সময় আমি যদি কথা বলি তখন তুমি কথা বন্ধ করে আমার কথা মনোযোগ দিয়ে শুনবা');
      expect(r, contains('থেমে'));
      expect(rig.brain.bargeIn, isTrue, reason: 'the setting is turned on');
      expect(await chat.hear('এটা এটা হল কোন প্রফেশনাল কিছু হইতেছে না বাজে'), contains('দুঃখিত'));
      expect(await chat.hear('আমি তোমাকে একটা নির্দেশনা দিতেছি তুমি সেই নির্দেশনা না বুঝে'), contains('দুঃখিত'));
      expect(rig.brain.data.notes, isEmpty);
      expect(chat.wait, ChatWait.none, reason: 'no "নতুন বিভাগ খুলে রাখি?"');
      expect(await chat.hear('কয়টা বাজে'), startsWith('এখন'), reason: '"বাজে" the time is not a complaint');
    });

    testWidgets('"… আমাদের যোগাযোগ নাম্বারে ইয়া রবিন হায়দারের নাম্বারটা কি বলতো" finds the number', (t) async {
      final (_, r) = await ask(t, 'তুমি একটা কাজ কর আমাকে বল যে আমাদের যোগাযোগ নাম্বারে ইয়া রবিন হায়দারের নাম্বারটা কি বলতো', contacts: [Contact(name: 'রবিন হায়দার', phone: '01711000000')]);
      expect(r, contains('রবিন হায়দার'));
      expect(r.replaceAll(' ', ''), contains('০১৭১১০০০০০০'));
    });

    testWidgets('"আজকে আরবি কত তারিখে একটু বলতো" is the Hijri date; "কোন ছবি আছে কিনা" the kept photos', (t) async {
      final (chat, r) = await ask(t, 'আচ্ছা একটা কাজ করো তো আজকে আরবি কত তারিখে একটু বলতো');
      expect(r, contains('হিজরি'));
      expect(await chat.hear('ঠিক আছে তাহলে একটা কাজ করো দেখতো আমার এখানে কোন ছবি আছে কিনা'), contains('ছবি রাখা নেই'));
    });

    test('openings and dangling words wait for the rest', () {
      for (final s in ['তুমি একটা কাজ কর', 'যেটা হলো', 'তুমি এক কাজ করো আগামীকালকে সকাল দশটায় আমাকে', 'আচ্ছা একটা কাজ']) {
        expect(leftOpen(s), isTrue, reason: s);
      }
      for (final s in ['তুমি এক কাজ করো আগামীকালকে সকাল দশটায় আমাকে একটা এলার্ম সেট করে দাও', 'শফিক ভাইয়ের কাছে কত টাকা পাই', 'আজকে আরবি কত তারিখ']) {
        expect(leftOpen(s), isFalse, reason: s);
      }
    });
  });

  // Eight more recordings (17 Oct): to-dos said with talk around them, dates
  // as people say them, "শুধু লিখবা …", "এটা তো বলি নাই".
  group('the second set of 17 Oct', () {
    Future<(ChatController, List<String>)> talk(WidgetTester t, List<String> turns) async {
      final rig = await start(t);
      final chat = ChatController(rig.brain);
      final out = <String>[];
      for (final s in turns) {
        out.add(await chat.hear(s));
      }
      return (chat, out);
    }

    testWidgets('"… কালকের কাজের তালিকায় লেখ" then the words: one to-do for tomorrow', (t) async {
      final (chat, r) = await talk(t, ['আমি তোমাকে বলতেছি আমি তোমাকে বলতেছি আগামীকালকের কাজের তালিকায় লেখ', 'আমাকে পুকুরে চুন দিতে হবে']);
      expect(r[0], contains('কী লিখব'));
      expect(r[1], allOf(contains('“পুকুরে চুন দিতে হবে”'), contains('কাল')));
      await chat.hear('হ্যাঁ');
      expect(chat.brain.data.tasks.single.due, DateTime(2026, 10, 10));
    });

    testWidgets('a complaint and the to-do in one breath: the to-do is kept, the talk is not', (t) async {
      final (_, r) = await talk(t, ['এটা কোন কিছু হইল তোমারে আমি বললাম যে আগামীকাল আগামীকাল আগামীকালকে তো রবিবার আসতে না শনিবার আগামীকালকের কাজের তালিকা তে পুকুরে চুন দিতে হবে এটা লিখে রাখ']);
      expect(r.single, contains('“পুকুরে চুন দিতে হবে”'));
      final (_, r2) = await talk(t, ['ভাই আমি তোমাকে কি নিতে চুনা দিলাম আর তুমি কি কি উত্তর দিতেছ আমি কি তোমাকে বলছি ৩১ অক্টোবর এর কাজের তালিকাতে লেখ যে সকালবেলা বাজারে যাইতে হবে']);
      expect(r2.single, allOf(contains('“সকালবেলা বাজারে যাইতে হবে”'), contains('৩১ অক্টোবর')));
      final (_, r3) = await talk(t, ['কাজের তালিকা বোর্ড এন আই ডি যুক্ত করা লাগবে']);
      expect(r3.single, contains('“বোর্ড এন আই ডি যুক্ত করা লাগবে”'));
    });

    testWidgets('dates as people say them: "৩১ শে অক্টোবর", "অক্টোবরের জন্য", "২৭ সালের জানুয়ারি মাসের প্রথম তারিখে"', (t) async {
      final (_, a) = await talk(t, ['৩১ শে অক্টোবর কাজের তালিকাতে লেখ যে সকালবেলা বাজারে যাইতে হবে']);
      expect(a.single, contains('৩১ অক্টোবর'));
      final (_, b) = await talk(t, ['৩১ অক্টোবরের জন্য একটা রিমাইন্ডার সেট করো তো', 'সকাল ৯ টায়']);
      expect(b.join(' '), isNot(contains('“জন্য”')));
      expect(b.last, contains('কী বিষয়ে'));
      final (_, c) = await talk(t, ['তুমি এক কাজ কর ২৭ সালের জানুয়ারি মাসের প্রথম তারিখে আমার জন্য একটা রিমাইন্ডার সেট করো যে স্কুলে যাইতে হবে']);
      expect(c.single, allOf(contains('“স্কুলে যাইতে হবে”'), contains('১ জানুয়ারি'), contains('কয়টায়')));
    });

    testWidgets('"হ্যাঁ কিন্তু শুধু লিখবা …" changes only the words; "এটা তো বলি নাই" is a no', (t) async {
      final (chat, r) = await talk(t, [
        'তুমি আমার জন্য একটা রিমাইন্ডার সেট করো তো যে প্রতিমাসের ৫ তারিখে আমাকে ওয়াইফাই বিল দিতে হবে',
        'হ্যাঁ কিন্তু শুধু তুমি লিখবা ওয়াইফাই বিল এত কিছু প্রয়োজন নাই লেখা',
      ]);
      expect(r[0], allOf(contains('“ওয়াইফাই বিল দিতে হবে”'), contains('প্রতি মাসে')));
      expect(r[1], contains('“ওয়াইফাই বিল”'));
      expect(chat.wait, ChatWait.yesNo);
      final (chat2, r2) = await talk(t, ['আমাকে সোনা মরে যাইতে হবে এটা একটা কাজের লিস্টে রাখো', 'এটা তো বলি নাই']);
      expect(r2.last, 'আচ্ছা, রাখলাম না।');
      expect(chat2.brain.data.tasks, isEmpty);
      expect(chat2.brain.data.notes, isEmpty);
    });

    testWidgets('talk about how it should listen is answered, never saved', (t) async {
      final (chat, r) = await talk(t, [
        'তুমি আমার পুরো কথা শোনো মরে যেতে হবে',
        'মেসেজের নির্দেশনা যত শেষ হয় নাই বা তুমি আগের মেসেজে আমাকে কোন ধরনের আউটপুট দাও নাই তো সেই ক্ষেত্রে পরের মেসেজের সাথে একটু সমন্বয় করার চেষ্টা করবা না',
      ]);
      expect(r, everyElement(contains('দুঃখিত')));
      expect(chat.brain.data.tasks, isEmpty);
    });
  });

  // Four more recordings (17 Oct, 10:30).
  group('the third set of 17 Oct', () {
    Future<(ChatController, List<String>)> talk(WidgetTester t, List<String> turns, {List<Task> tasks = const []}) async {
      final rig = await start(t);
      for (final x in tasks) {
        await rig.brain.saveTask(x);
      }
      final chat = ChatController(rig.brain);
      final out = <String>[];
      for (final s in turns) {
        out.add(await chat.hear(s));
      }
      return (chat, out);
    }

    testWidgets('"কাজ কর যে ৩০ অক্টোবর বিকেল চারটায় পড়ানো আছে এটা একটু লিখে রাখো তো": a reminder "পড়ানো আছে"', (t) async {
      final (_, r) = await talk(t, ['কাজ কর যে ৩০ অক্টোবর বিকেল চারটায় পড়ানো আছে এটা একটু লিখে রাখো তো']);
      expect(r.single, allOf(contains('৩০ অক্টোবর'), contains('৪টা'), contains('“পড়ানো আছে”')));
    });

    testWidgets('a year said with the date: "২০২৭ সালে … জানুয়ারি মাসের এক তারিখে" — title clean, 1 January', (t) async {
      final (_, r) = await talk(t, ['আমি বললাম ২০২৭ সালে জানুয়ারি মাসের এক তারিখে আমার বাচ্চাকে নিয়ে স্কুলে যেতে হবে এটা কাজের তালিকাতে লিখে রাখ']);
      expect(r.single, allOf(contains('“বাচ্চাকে নিয়ে স্কুলে যেতে হবে”'), contains('১ জানুয়ারি')));
    });

    testWidgets('"আমার ৩১ অক্টোবর এর কাজের তালিকা টা কি" / "আজকের কাজের তালিকা আছে": that day only', (t) async {
      final tasks = [Task(title: 'সকালবেলা বাজারে যাইতে হবে', due: DateTime(2026, 10, 31)), Task(title: 'পুকুরে চুন দিতে হবে', due: DateTime(2026, 10, 10)), Task(title: 'বিল দিতে হবে', due: DateTime(2026, 10, 9))];
      final (_, r) = await talk(t, ['আমার ৩১ অক্টোবর এর কাজের তালিকা টা কি', 'আমার আজকের যে কাজের তালিকা আছে'], tasks: tasks);
      expect(r[0], allOf(contains('সকালবেলা বাজারে'), isNot(contains('পুকুরে'))));
      expect(r[1], allOf(contains('বিল দিতে হবে'), isNot(contains('পুকুরে')), isNot(contains('বাজারে'))));
    });

    testWidgets('"ওই যে এক নাম্বারটা" picks the first; a question while a save waits is answered, not a yes', (t) async {
      final (chat, r) = await talk(t, ['আচ্ছা এরপরে সোনাইমুড়ী যাইতে হবে সেটা মুছে দাও', 'ওই যে এক নাম্বারটা'], tasks: [Task(title: 'সোনা মরে যাইতে হবে'), Task(title: 'আগামীকালকে দশটায় সোনার মণি যাইতে হবে এটা একটা')]);
      expect(r[0], contains('কোনটা'));
      expect(r[1], contains('মুছে দেবো?'));
      final (chat2, r2) = await talk(t, ['তুমি এক কাজ কর ২০ শে অক্টোবর এর কাজের তালিকাতে লেখ যে ঢাকায় যাইতে হবে', 'কোন তারিখে তুলবা ঢাকায় যেতে হবে']);
      expect(r2[0], contains('২০ অক্টোবর'));
      expect(r2[1], contains('২০ অক্টোবর'));
      expect(chat2.brain.data.tasks, isEmpty, reason: 'the question is not a yes');
      expect(chat2.wait, ChatWait.yesNo);
      expect(chat.wait, ChatWait.yesNo);
    });

    testWidgets('"… কাজের তালিকা থেকে … মুছে দাও" deletes, never adds', (t) async {
      final (chat, r) = await talk(t, ['আজকের কাজের তালিকা থেকে ঢাকায় যেতে হবে এটা মুছে দাও'], tasks: [Task(title: 'ঢাকায় যাইতে হবে', due: DateTime(2026, 10, 9))]);
      expect(r.single, contains('মুছে দেবো?'));
      expect(chat.brain.data.tasks, hasLength(1));
    });

    testWidgets('"ডিসেম্বর এর কাজের তালিকাতে লেখ রাত্রে পার্টি হবে": asks the day', (t) async {
      final (chat, r) = await talk(t, ['ডিসেম্বর এর কাজের তালিকাতে লেখ রাত্রে পার্টি হবে', '৩১ তারিখে', 'হ্যাঁ']);
      expect(r[0], contains('কত তারিখে'));
      expect(r[1], allOf(contains('“রাত্রে পার্টি হবে”'), contains('৩১ ডিসেম্বর')));
      expect(chat.brain.data.tasks.single.due, DateTime(2026, 12, 31));
    });
  });

  // Three more recordings (17 Oct, 11:00).
  group('the fourth set of 17 Oct', () {
    Future<(ChatController, List<String>)> talk(WidgetTester t, List<String> turns, {List<Task> tasks = const []}) async {
      final rig = await start(t);
      for (final x in tasks) {
        await rig.brain.saveTask(x);
      }
      final chat = ChatController(rig.brain);
      final out = <String>[];
      for (final s in turns) {
        out.add(await chat.hear(s));
      }
      return (chat, out);
    }

    final some = [Task(title: 'পুকুরে চুন দিতে হবে', due: DateTime(2026, 10, 9)), Task(title: 'নিজাম মামা আসবেন', due: DateTime(2026, 10, 9)), Task(title: 'সোনা মরে যাইতে হবে'), Task(title: 'স্কুলে যেতে হবে', due: DateTime(2027, 1, 1))];

    testWidgets('"এরাম একটা" is not part of the to-do; "X শব্দটা বাদ দিও" takes the word out and saves', (t) async {
      final (_, r) = await talk(t, ['আচ্ছা জানুয়ারি মাসের ৩১ তারিখে বাচ্চাকে স্কুলে নিতে হবে এরাম একটা কাজের তালিকা লেখ']);
      expect(r.single, allOf(contains('“বাচ্চাকে স্কুলে নিতে হবে”'), contains('৩১ জানুয়ারি')));
      final (chat, _) = await talk(t, ['জানুয়ারি মাসের ৩১ তারিখে বাচ্চাকে স্কুলে নিতে হবে কাজের তালিকায় লেখ', 'হ্যাঁ তুলে রাখ তবে নিতে শব্দটা বাদ দিও']);
      expect(chat.brain.data.tasks.single.title, 'বাচ্চাকে স্কুলে হবে');
    });

    testWidgets('"জানুয়ারি মাসের কাজের তালিকা" lists that month only', (t) async {
      final (_, r) = await talk(t, ['একটা কাজ কর আমাকে আমার জানুয়ারি মাসের কাজে তালিকা টা দাও তো'], tasks: some);
      expect(r.single, allOf(contains('স্কুলে যেতে হবে'), isNot(contains('পুকুরে'))));
    });

    testWidgets('"আজকের যতগুলো কাজ আছে সবগুলো বাদ দিয়ে দাও": today\'s, confirmed once, all removed', (t) async {
      final (chat, r) = await talk(t, ['হ্যাঁ আমি তো বলা শেষ করছি আমার আজকের যতগুলো কাজ আছে সবগুলো বাদ দিয়ে দাও', 'হ্যাঁ'], tasks: some);
      expect(r[0], contains('আজকের সব — ২টা কাজ মুছে দেবো?'));
      expect(chat.brain.data.tasks.map((x) => x.title), unorderedEquals(['সোনা মরে যাইতে হবে', 'স্কুলে যেতে হবে']));
      final (chat2, r2) = await talk(t, ['আমার কাজের তালিকার মধ্যে যতগুলো কাজ আছে সবকটা মুছে দাও ডিলিট করে দাও', 'হ্যাঁ'], tasks: some);
      expect(r2[0], contains('৪টা কাজ'));
      expect(chat2.brain.data.tasks, isEmpty);
    });

    testWidgets('"তুমি আজকেরটা কেন দিতেছ" is a complaint, answered', (t) async {
      final (_, r) = await talk(t, ['ভাই আমি তো জানো রে তুমি আজকেরটা কেন দিতেছ']);
      expect(r.single, contains('দুঃখিত'));
    });
  });

  // Three more recordings (17 Oct, 11:45).
  group('the fifth set of 17 Oct', () {
    Future<(ChatController, List<String>)> talk(WidgetTester t, List<String> turns, {List<Task> tasks = const []}) async {
      final rig = await start(t);
      for (final x in tasks) {
        await rig.brain.saveTask(x);
      }
      final chat = ChatController(rig.brain);
      final out = <String>[];
      for (final s in turns) {
        out.add(await chat.hear(s));
      }
      return (chat, out);
    }

    final some = [Task(title: 'সোনা মরে যাইতে হবে'), Task(title: 'বাচ্চাকে স্কুলে নিতে হবে', due: DateTime(2027, 1, 31)), Task(title: 'ঢাকায় যাইতে হবে', due: DateTime(2026, 10, 20))];

    testWidgets('today\'s list is what the কাজ page shows under "আজ" (undated too)', (t) async {
      final (_, r) = await talk(t, ['আমার আজকের কাজের তালিকা টা দাও তো'], tasks: some);
      expect(r.single, allOf(contains('সোনা মরে যাইতে হবে'), isNot(contains('কোনো কাজ রাখা নেই'))));
    });

    testWidgets('"৩১ শে জানুয়ারিতে যে কাজটা আছে সেটা মুছে দাও": that day\'s, no list of six', (t) async {
      final (chat, r) = await talk(t, ['তোমাকে বললাম এই যে ৩১ শে জানুয়ারিতে যে কাজটা আছে সেটা মুছে দাও বাদ দিয়ে দাও ডিলিট করে দাও', 'হ্যাঁ'], tasks: some);
      expect(r[0], contains('১টা কাজ মুছে দেবো?'));
      expect(chat.brain.data.tasks.map((x) => x.title), isNot(contains('বাচ্চাকে স্কুলে নিতে হবে')));
      expect(chat.brain.data.tasks, hasLength(2));
    });

    testWidgets('the same delete-all said again while it waits is a yes', (t) async {
      final (chat, _) = await talk(t, ['আমার এখানে যতগুলো কাজ আছে সবকটা মুছে দাও', 'হ্যাঁ বলছি আমার এখানে যতগুলো কাজ আছে সবকটা মুছে দাও'], tasks: some);
      expect(chat.brain.data.tasks, isEmpty);
    });

    testWidgets('"প্রতি মাসের ১ তারিখে একটা কাজ যুক্ত করো যে …": a monthly reminder; "প্রতিমাসে যেন রিপিট হয়" makes the last to-do monthly', (t) async {
      final (_, r) = await talk(t, ['আচ্ছা এখন একটা কাজ কর আমার প্রতি মাসের ১ তারিখে একটা কাজ যুক্ত করো যে আমাকে সোনায় মরে যাইতে হবে']);
      expect(r.single, allOf(contains('১ নভেম্বর'), contains('প্রতি মাসে'), contains('“সোনায় মরে যাইতে হবে”')));
      final (chat, r2) = await talk(t, ['একটা কাজ যুক্ত করো যে আমাকে সোনায় মরে যাইতে হবে', 'হ্যাঁ', 'আমি তো তোমাকে বললাম প্রতিমাসে যেন এই কাজটা রিপিট হয়', 'হ্যাঁ']);
      expect(r2[2], contains('প্রতি মাসে'));
      expect(chat.brain.data.tasks, isEmpty, reason: 'the to-do became the monthly reminder');
      expect(chat.brain.data.reminders.single.repeat, Repeat.monthly);
    });
  });

  // 17 Oct, sixth set: questions about the day's to-dos answered with a
  // contact's number ("কাজ" ~ "Kazi"), speech fragments ("আগামীকাল",
  // "কিন্তু আমি") searched as names, and three dated to-dos in one breath
  // answered as "নভেম্বরে কোনো কাজ নেই".
  group('17 Oct sixth set', () {
    Future<ChatController> withContacts(WidgetTester t) async {
      final rig = await start(t);
      rig.brain.data.contacts.addAll([
        Contact(name: 'Kazi Nazrul', phone: '01700000000'),
        Contact(name: 'Shilpu Khala', phone: '01800000000'),
        Contact(name: 'Moussa Konate', phone: '01900000000'),
      ]);
      return ChatController(rig.brain);
    }

    testWidgets('a question about the day\'s to-dos lists the day, never a contact', (t) async {
      final chat = await withContacts(t);
      final now = DateTime(2026, 10, 9, 15, 53); // the test clock
      chat.brain.data.tasks.add(Task(title: 'ব্যাংকে যাওয়া'));
      chat.brain.data.tasks.add(Task(title: 'বাজার করা', due: DateTime(now.year, now.month, now.day + 1)));
      for (final (said, has) in [
        ('আজকে কোন কাজ আছে', 'ব্যাংকে যাওয়া'),
        ('আমার আজকে কোন কাজ আছে', 'ব্যাংকে যাওয়া'),
        ('আগামীকালকে আমার কোন কাজ আছে', 'বাজার করা'),
        ('কালকের যে কাজগুলো আছে', 'বাজার করা'),
      ]) {
        final before = chat.messages.length;
        await chat.hear(said);
        final reply = chat.messages.skip(before).map((m) => m.text).join(' ');
        expect(reply, contains(has), reason: said);
        expect(reply, isNot(contains('নম্বর')), reason: said);
        expect(chat.brain.data.tasks.length, 2, reason: '$said added nothing');
      }
    });

    testWidgets('fragments are not searched as names', (t) async {
      final chat = await withContacts(t);
      for (final said in ['আগামীকাল', 'কিন্তু আমি', 'আজকে', 'তারপর কাল']) {
        final before = chat.messages.length;
        await chat.hear(said);
        final reply = chat.messages.skip(before).map((m) => m.text).join(' ');
        for (final n in ['Kazi', 'Khala', 'Konate', 'নম্বর']) {
          expect(reply, isNot(contains(n)), reason: said);
        }
      }
    });

    testWidgets('a real name is still found', (t) async {
      final chat = await withContacts(t);
      await chat.hear('কাজী নজরুলের নম্বর কত');
      expect(chat.messages.last.text, contains('Kazi Nazrul'));
    });

    testWidgets('several dated to-dos in one breath become one to-do each', (t) async {
      final chat = await withContacts(t);
      await chat.hear('নভেম্বর মাসে ৮ তারিখে ঢাকায় যাব নভেম্বর মাসের বাইশ তারিখে সিঙ্গাপুর যাব এবং ২৯ তারিখে ঢাকায় ব্যাক করব এগুলো কাজের তালিকায় যুক্ত করো');
      await chat.hear('হ্যাঁ');
      final tasks = chat.brain.data.tasks;
      expect(tasks.map((x) => x.title).toList(), ['ঢাকায় যাব', 'সিঙ্গাপুর যাব', 'ঢাকায় ব্যাক করব']);
      expect(tasks.map((x) => x.due!.day).toList(), [8, 22, 29]);
      expect(tasks.every((x) => x.due!.month == 11), isTrue);
    });

    test('day numbers said as words read as dates', () {
      expect(tidySpeech('নভেম্বর মাসের বাইশ তারিখে সিঙ্গাপুর যাব'), contains('২২ নভেম্বর'));
      expect(tidySpeech('পঁচিশে ডিসেম্বর বাড়ি যাব'), contains('২৫ ডিসেম্বর'));
      expect(tidySpeech('একত্রিশ তারিখে বিল দিতে হবে'), contains('৩১ তারিখে'));
    });

    test('a fragment ending on "আমি" waits for the rest', () {
      expect(leftOpen('কিন্তু আমি'), isTrue);
      expect(leftOpen('আজকে কোন কাজ আছে'), isFalse);
    });

    testWidgets('"জিজ্ঞেস করিনি" is a complaint, not a search', (t) async {
      final chat = await withContacts(t);
      await chat.hear('আমি তো তোমাকে জিজ্ঞেস করিনি');
      expect(chat.messages.last.text, contains('দুঃখিত'));
    });
  });
}
