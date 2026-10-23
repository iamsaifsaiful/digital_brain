import 'package:flutter_test/flutter_test.dart';

import 'walk.dart';

void main() {
  testWidgets('01 বয়স্ক বাবা', (t) async {
    final w = await Walk.begin(t, 'p01', 'রহমান সাহেব, ৬৮, অবসরপ্রাপ্ত, কথায় চালান');
    await w.shot('home');
    await w.openMic();
    await w.say('কাল সকাল আটটায় প্রেশারের ওষুধ খাওয়ার কথা মনে করিয়ে দিও');
    await w.say('হ্যাঁ');
    await w.say('প্রতিদিন রাত দশটায় ঘুমের ওষুধ');
    await w.say('হ্যাঁ');
    await w.say('আমার ছেলে রাশেদের নম্বর ০১৭১২৩৪৫৬৭৮ রাখো');
    await w.say('হ্যাঁ');
    await w.say('রাশেদের নম্বর কত');
    await w.say('আজ কী কী আছে');
    await w.shot('chat');
    await w.done();
  });

  testWidgets('02 গৃহিণী', (t) async {
    final w = await Walk.begin(t, 'p02', 'সালমা, গৃহিণী, সংসারের বাজার-খরচ');
    await w.openMic();
    await w.say('বাজারে আটশো পঞ্চাশ টাকা খরচ হলো');
    await w.say('হ্যাঁ');
    await w.say('মাছ কিনলাম চারশো টাকা');
    await w.say('হ্যাঁ');
    await w.say('গ্যাস বিল ১০৮০ টাকা দিলাম');
    await w.say('হ্যাঁ');
    await w.say('বাজারের লিস্টে ডিম পেঁয়াজ আর আলু যোগ করো');
    await w.say('হ্যাঁ');
    await w.say('বাজারের লিস্টে কী কী আছে');
    await w.say('এই মাসে কত খরচ হলো');
    await w.shot('chat');
    await w.done();
  });

  testWidgets('03 দোকানদার', (t) async {
    final w = await Walk.begin(t, 'p03', 'হাবিব, মুদি দোকানদার');
    await w.openMic();
    await w.say('দোকান নামে আলাদা হিসাব খোলো');
    await w.say('হ্যাঁ');
    await w.say('দোকানে আজ বিক্রি হলো বারো হাজার টাকা');
    await w.say('হ্যাঁ');
    await w.say('করিম দোকান থেকে পাঁচশো টাকার বাকি নিলো');
    await w.say('হ্যাঁ');
    await w.say('করিমের হিসাব দাও');
    await w.say('দোকানের হিসাব দাও');
    await w.shot('chat');
    await w.done();
  });

  testWidgets('04 ছাত্র', (t) async {
    final w = await Walk.begin(t, 'p04', 'তানভীর, অনার্সের ছাত্র');
    await w.openMic();
    await w.say('পরশু সকাল দশটায় ফিজিক্স পরীক্ষা');
    await w.say('হ্যাঁ');
    await w.say('প্রতিদিন রাত এগারোটায় পড়তে বসার কথা মনে করাবে');
    await w.say('হ্যাঁ');
    await w.say('টিউশনি থেকে তিন হাজার টাকা পেলাম');
    await w.say('হ্যাঁ');
    await w.say('এই সপ্তাহে কী কী আছে');
    await w.say('বন্ধু সাকিবকে দুইশো টাকা ধার দিলাম');
    await w.say('হ্যাঁ');
    await w.shot('chat');
    await w.done();
  });

  testWidgets('05 গার্মেন্টস কর্মী', (t) async {
    final w = await Walk.begin(t, 'p05', 'রুমা, গার্মেন্টস কর্মী');
    await w.openMic();
    await w.say('বেতন পেলাম বারো হাজার পাঁচশো টাকা');
    await w.say('হ্যাঁ');
    await w.say('বাড়িতে মাকে পাঁচ হাজার টাকা পাঠালাম');
    await w.say('হ্যাঁ');
    await w.say('রহিমা আপার কাছ থেকে এক হাজার টাকা ধার নিলাম');
    await w.say('হ্যাঁ');
    await w.say('আমার কার কাছে কত দেনা');
    await w.say('এই মাসে হাতে কত থাকলো');
    await w.shot('chat');
    await w.done();
  });
}
