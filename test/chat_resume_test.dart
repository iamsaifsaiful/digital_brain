// 18 Oct (b34): after another app the assistant opened a blank page and
// the conversation had to be dug out of "আগের কথা"; a long one also lost
// its older messages.
import 'package:digital_brain/screens/chat_home.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:digital_brain/state/chat_archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_test.dart' show Rig, openTyping, sendTyped, settle, start;

void main() {
  ChatController chatOf(WidgetTester t) => t.state<ChatHomeState>(find.byType(ChatHome)).chat;

  Future<void> type(WidgetTester t, String s) async {
    await t.enterText(find.byType(TextField).first, s);
    await sendTyped(t);
    await settle(t);
  }

  Future<void> leave(WidgetTester t, Rig rig) async {
    // The lock (or the back button) closes the assistant's page.
    Navigator.of(t.element(find.byType(ChatHome))).pop();
    await settle(t);
  }

  testWidgets('coming back goes on with the same conversation', (t) async {
    final rig = await start(t);
    await openTyping(t);
    await type(t, 'আজ কত তারিখ');
    final before = chatOf(t).messages.length;
    expect(before, greaterThan(1));
    await leave(t, rig);
    rig.nowAt = rig.nowAt.add(const Duration(minutes: 20));
    await openTyping(t);
    final c = chatOf(t);
    expect(c.messages.length, before, reason: 'the earlier messages are back on the page');
    expect(c.messages.first.text, 'আজ কত তারিখ');
    await type(t, 'এখন কয়টা বাজে');
    expect(c.messages.where((m) => m.fromUser).map((m) => m.text), ['আজ কত তারিখ', 'এখন কয়টা বাজে']);
    // Still one conversation in the list, not two.
    expect(await ChatArchive(rig.brain.services.lock.keys).load(), hasLength(1));
  });

  testWidgets('after a long break a clean page opens, with a button to the earlier ones', (t) async {
    final rig = await start(t);
    await openTyping(t);
    await type(t, 'আজ কত তারিখ');
    await leave(t, rig);
    rig.nowAt = rig.nowAt.add(const Duration(hours: 13));
    await openTyping(t);
    expect(chatOf(t).started, isFalse);
    await type(t, 'এখন কয়টা বাজে');
    await t.drag(find.byType(ListView).first, const Offset(0, 2000));
    await settle(t);
    expect(find.byKey(const Key('past-chats')), findsOneWidget);
    await t.tap(find.byKey(const Key('past-chats')));
    await settle(t);
    await t.tap(find.text('আজ কত তারিখ').last);
    await settle(t);
    expect(chatOf(t).messages.first.text, 'আজ কত তারিখ');
  });

  test('a long conversation keeps far more than 120 messages', () {
    final many = [for (var i = 0; i < 400; i++) i.isEven ? ChatMessage.user('প্রশ্ন $i') : ChatMessage.app('উত্তর $i')];
    expect(keepable(many), hasLength(400));
  });
}
