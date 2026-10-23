import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'walk.dart';

void main() {
  testWidgets('06 দিনমজুর', (t) async {
    final w = await Walk.begin(t, 'p06', 'জলিল, দিনমজুর, পড়তে কষ্ট হয়');
    await w.openMic();
    await w.say('আজ কামাই হইছে সাতশো টাকা');
    await w.say('হ্যাঁ');
    await w.say('চা নাস্তায় পঞ্চাশ টাকা গেল');
    await w.say('হ্যাঁ');
    await w.say('আজকে হাতে কত থাকলো');
    await w.say('মালিকের কাছে দুই দিনের মজুরি চোদ্দশো টাকা পাবো');
    await w.say('হ্যাঁ');
    await w.shot('chat');
    await w.done();
  });

  testWidgets('07 ডায়াবেটিস রোগী', (t) async {
    final w = await Walk.begin(t, 'p07', 'নাসরিন, ৫২, ডায়াবেটিস');
    await w.openMic();
    await w.say('প্রতিদিন সকাল আটটা আর রাত আটটায় ইনসুলিন নেওয়ার কথা মনে করাবে');
    await w.say('হ্যাঁ');
    await w.say('আজ সকালে সুগার ছিল আট দশমিক পাঁচ');
    await w.say('হ্যাঁ');
    await w.say('প্রেশার ১৩০ বাই ৮৫');
    await w.say('হ্যাঁ');
    await w.say('আমার সুগার কত ছিল');
    await w.say('ডাক্তার দেখানো আছে ১৫ তারিখ বিকেল ৫টায়');
    await w.say('হ্যাঁ');
    await w.shot('chat');
    await w.done();
  });

  testWidgets('08 অফিসকর্মী', (t) async {
    final w = await Walk.begin(t, 'p08', 'জামিল, ব্যাংকে চাকরি');
    await w.openMic();
    await w.say('আগামী রবিবার বিকেল তিনটায় ব্রাঞ্চ মিটিং');
    await w.say('হ্যাঁ');
    await w.say('জামান স্যারের নম্বর ০১৮১১২২৩৩৪৪ সেভ করো');
    await w.say('হ্যাঁ');
    await w.say('নোট রাখো ক্লায়েন্ট রফিক সাহেব লোনের কাগজ বৃহস্পতিবার দেবেন');
    await w.say('হ্যাঁ');
    await w.say('রফিক সাহেব কবে কাগজ দেবেন');
    await w.say('কাল কী কী কাজ');
    await w.shot('chat');
    await w.done();
  });

  testWidgets('09 বাচ্চার মা', (t) async {
    final w = await Walk.begin(t, 'p09', 'মিতু, দুই বাচ্চার মা');
    await w.openMic();
    await w.say('পনেরো নভেম্বর মেয়ের টিকা দিতে হবে');
    await w.say('হ্যাঁ');
    await w.say('মেয়ের জন্মদিন বিশে ডিসেম্বর');
    await w.say('হ্যাঁ');
    await w.say('প্রতি মাসের পাঁচ তারিখে স্কুলের বেতন দিতে হবে');
    await w.say('হ্যাঁ');
    await w.say('মেয়ের জন্মদিন কবে');
    await w.say('এই মাসে কী কী দিন আছে');
    await w.shot('chat');
    await w.done();
  });

  testWidgets('10 প্রবাসী', (t) async {
    final w = await Walk.begin(t, 'p10', 'শফিক, সৌদি প্রবাসী');
    await w.openMic();
    await w.say('বাড়িতে আব্বার কাছে বিশ হাজার টাকা পাঠালাম');
    await w.say('খরচ');
    await w.say('ভাইকে দোকানের জন্য পঞ্চাশ হাজার টাকা ধার দিলাম ফেরত দেবে ডিসেম্বরে');
    await w.say('হ্যাঁ');
    await w.say('এই মাসে বাড়িতে কত পাঠালাম');
    await w.say('ভাই কবে টাকা ফেরত দেবে');
    await w.shot('chat');
    await w.done();
  });
}
