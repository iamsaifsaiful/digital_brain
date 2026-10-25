// Owner's fourth video (25 Oct): removing tonight's reminder took six
// tries — "আজকে রাত্রে সেটা ডিলিট করে দাও", "রাত্রে আটটা ৪৫-এর রিমাইন্ডার",
// "ওই লিস্টের প্রথম যে রিমাইন্ডার আছে" were not found; "বাদ দাও" to "মুছে
// দেব?" was taken as "cancel"; "আমি বাদ দিতে বলছি, মোছ নাই কেন" was looked
// up as a question. Each flow must end with that one reminder removed.
import 'package:digital_brain/models/models.dart';
import 'package:digital_brain/state/chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'app_test.dart' show start;

AppData _data() => AppData(reminders: [
      Reminder(title: 'তুমি আমার মেয়ে তোমাকে নিয়ে আমার মাদ্রাসায় যাওয়া', date: DateTime(2026, 10, 25), hour: 20, minute: 45),
      Reminder(title: 'বিদ্যুৎ বিল', date: DateTime(2026, 10, 27), hour: 10),
      Reminder(title: 'ইন্টারনেট বিল', date: DateTime(2026, 11, 5), hour: 10),
      Reminder(title: 'বাচ্চার স্কুলের বেতন', date: DateTime(2026, 11, 8), hour: 10),
      Reminder(title: 'বাসা ভাড়া', date: DateTime(2026, 11, 10), hour: 10),
    ]);

void main() {
  for (final seq in [
    ['আমি বললাম আমার রিমাইন্ডার কি কি আছে', 'ওই লিস্টের প্রথম যে রিমাইন্ডার আছে সেটা বাদ দাও', 'বাদ দাও আবার কি চিন্তা করতেছো'],
    ['আমার রিমাইন্ডার কি কি আছে', 'কি তুমি কি', 'বললাম প্রথম রিমাইন্ডার যেটা আছে সেটা বাদ দিয়ে দাও', 'হ্যাঁ'],
    ['আচ্ছা আজকে রাত্রে সেটা ডিলিট করে দাও বাদ দিয়ে দাও', 'হ্যাঁ'],
    ['আজকে রাত্রে রিমেন্ডার কোনটা আছে সেটা বাদ দিয়ে দাও', 'হ্যাঁ'],
    ['রাত্রে আটটা ৪৫ এ যে রিমাইন্ডার টা আছে সেটা তুমি বাদ দিয়ে দাও', 'বাদ দাও'],
    ['রাত্রে আটটা ৪৫ এ যে রিমাইন্ডার টা আছে সেটা তুমি বাদ দিয়ে দাও', 'না', 'তোমাকে তো আমি বাদ দিতে বলছি আমি আবার মোছ নাই কেন'],
  ]) {
    testWidgets(seq.join(' → '), (t) async {
      final rig = await start(t, data: _data());
      rig.nowAt = DateTime(2026, 10, 25, 10, 5);
      final chat = ChatController(rig.brain);
      for (final s in seq) {
        await chat.hear(s);
      }
      final left = rig.brain.data.reminders.map((r) => r.title).toList();
      expect(left.length, 4, reason: left.join(', '));
      expect(left.any((x) => x.contains('মাদ্রাসা')), isFalse);
    });
  }

  testWidgets('"না" to "মুছে দেবো?" says nothing was removed', (t) async {
    final rig = await start(t, data: _data());
    rig.nowAt = DateTime(2026, 10, 25, 10, 5);
    final chat = ChatController(rig.brain);
    await chat.hear('রাত্রে আটটা ৪৫ এ যে রিমাইন্ডার টা আছে সেটা তুমি বাদ দিয়ে দাও');
    await chat.hear('না');
    expect(chat.messages.last.text, contains('মুছিনি'));
    expect(rig.brain.data.reminders.length, 5);
  });
}
