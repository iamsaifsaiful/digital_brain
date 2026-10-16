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

  testWidgets('scenario: speech in two breaths → "আর কিছু বলতে চান?" → "না, বলতে চাই না" → one preview', (t) async {
    final rig = await start(t);
    final chat = await openVoice(t);
    rig.voice.say('ইসমাইলকে পাঁচ হাজার টাকা');
    await settle(t);
    rig.voice.say('ধার দিয়েছি');
    await settle(t);
    await quiet(t);
    expect(rig.voice.spoken.last, 'আর কিছু বলতে চান?');
    rig.voice.say('না, বলতে চাই না।');
    await settle(t);
    expect(chat.messages.where((m) => m.fromUser).single.text, 'ইসমাইলকে পাঁচ হাজার টাকা ধার দিয়েছি');
    expect(rig.voice.spoken.last, allOf(contains('ইসমাইল'), contains('৫,০০০'), isNot(contains('বলতে চাই না'))));
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

  testWidgets('left open ("…খরচ হচ্ছে কোন") the app asks for more instead of guessing', (t) async {
    final rig = await start(t);
    final chat = await openVoice(t);
    rig.voice.say('আচ্ছা আমার এই মাসে খরচ হচ্ছে কোন');
    await settle(t);
    await quiet(t);
    expect(rig.voice.spoken.last, 'আর কিছু বলতে চান?');
    expect(chat.messages.where((m) => m.fromUser), isEmpty);
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
}
