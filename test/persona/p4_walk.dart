import 'package:digital_brain/state/brain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'walk.dart';

void main() {
  testWidgets('16 ঠিকাদার', (t) async {
    final w = await Walk.begin(t, 'p16', 'মান্নান, বাড়ি বানানোর ঠিকাদার');
    await w.openMic();
    await w.say('রহিম ভবন প্রজেক্টে মালিক পাঁচ লাখ টাকা দিলো');
    await w.say('হ্যাঁ');
    await w.say('রহিম ভবন প্রজেক্টে রড কিনলাম পঞ্চাশ হাজার');
    await w.say('হ্যাঁ');
    await w.say('রহিম ভবনে মিস্ত্রিকে বারো হাজার টাকা দিলাম');
    await w.say('হ্যাঁ');
    await w.say('রহিম ভবন প্রজেক্টের হিসাব দাও');
    await w.shot('chat');
    await w.done();
  });

  testWidgets('17 কম দেখেন এমন বয়স্ক নারী', (t) async {
    final w = await Walk.begin(t, 'p17', 'হালিমা খাতুন, ৭২, চোখে কম দেখেন');
    await w.tap(find.byTooltip('প্রোফাইল'), 'প্রোফাইল');
    await w.shot('more');
    final easy = find.textContaining('বয়স্কদের');
    await w.tap(easy, 'বয়স্কদের সুবিধা');
    await w.shot('easy-setting');
    await w.back();
    await w.tap(find.text('হোম').last, 'হোম');
    await w.shot('home-after');
    await w.openMic();
    await w.say('আমার ওষুধ কখন');
    await w.say('মেয়েকে ফোন দাও');
    await w.done();
  });

  testWidgets('18 গোপনীয়তা নিয়ে সচেতন', (t) async {
    final w = await Walk.begin(t, 'p18', 'আরিফ, আইটি পেশাজীবী');
    await w.openMic();
    await w.say('আমার ডাচ বাংলা ব্যাংকের পিন ৪৪২১ মনে রাখো');
    await w.say('হ্যাঁ');
    await w.say('আমার ব্যাংকের পিন কত');
    await w.say('আমার তথ্য কি তোমার সার্ভারে যায়');
    await w.shot('chat');
    await w.done();
  });

  testWidgets('19 প্রো সদস্য', (t) async {
    final w = await Walk.begin(t, 'p19', 'নুসরাত, প্রো নিয়েছেন');
    w.rig.brain.gated = true;
    await w.rig.brain.setProForTest(true);
    await w.tap(find.byTooltip('প্রোফাইল'), 'প্রোফাইল');
    await w.shot('profile');
    await w.tap(find.byKey(const Key('plan-badge')), 'প্রো ব্যাজ');
    await w.shot('pro-page');
    await w.done();
  });

  testWidgets('20 রক্তদাতা', (t) async {
    final w = await Walk.begin(t, 'p20', 'সাজ্জাদ, নিয়মিত রক্তদাতা');
    await w.openMic();
    await w.say('আমার রক্তের গ্রুপ বি পজিটিভ');
    await w.say('হ্যাঁ');
    await w.say('শেষ রক্ত দিয়েছি দশ আগস্ট');
    await w.say('হ্যাঁ');
    await w.say('আবার কবে রক্ত দিতে পারব');
    await w.say('রক্ত লাগবে');
    await w.shot('chat');
    await w.done();
  });
}
