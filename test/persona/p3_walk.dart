import 'package:flutter_test/flutter_test.dart';

import 'walk.dart';

void main() {
  testWidgets('11 কৃষক', (t) async {
    final w = await Walk.begin(t, 'p11', 'মোতালেব, কৃষক');
    await w.openMic();
    await w.say('বোরো ধান নামে হিসাব খোলো');
    await w.say('হ্যাঁ');
    await w.say('বোরো ধান হিসাবে সার কিনলাম আড়াই হাজার টাকা');
    await w.say('হ্যাঁ');
    await w.say('বোরো ধান হিসাবে ধান বিক্রি চল্লিশ হাজার টাকা');
    await w.say('হ্যাঁ');
    await w.say('বোরো ধানে কত লাভ হলো');
    await w.shot('chat');
    await w.done();
  });

  testWidgets('12 ফ্রিল্যান্সার', (t) async {
    final w = await Walk.begin(t, 'p12', 'রিয়া, গ্রাফিক ডিজাইনার, ফ্রিল্যান্স');
    await w.openMic();
    await w.say('ফাইভার থেকে বিশ হাজার টাকা পেলাম');
    await w.say('হ্যাঁ');
    await w.say('ইন্টারনেট বিল বারোশো টাকা');
    await w.say('হ্যাঁ');
    await w.say('ক্লায়েন্ট জন এর কাজ জমা দিতে হবে মঙ্গলবার রাত নয়টায়');
    await w.say('হ্যাঁ');
    await w.say('এই মাসে আয় কত');
    await w.shot('chat');
    await w.done();
  });

  testWidgets('13 নামাজি', (t) async {
    final w = await Walk.begin(t, 'p13', 'আব্দুল করিম, নিয়মিত নামাজি');
    await w.openMic();
    await w.say('আজকে মাগরিবের ওয়াক্ত কখন');
    await w.say('আজ কত তারিখ হিজরি');
    await w.say('আমার যাকাত কত দিতে হবে');
    await w.say('প্রতি শুক্রবার জুমার আগে সূরা কাহাফ পড়ার কথা মনে করাবে');
    await w.say('হ্যাঁ');
    await w.shot('chat');
    await w.done();
  });

  testWidgets('14 কিশোর', (t) async {
    final w = await Walk.begin(t, 'p14', 'অয়ন, ১৫, ক্লাস টেন');
    await w.openMic();
    await w.say('তুমি কী কী পারো');
    await w.say('বিকেল পাঁচটায় ক্রিকেট খেলা');
    await w.say('হ্যাঁ');
    await w.say('আম্মু টিফিনের জন্য একশো টাকা দিলো');
    await w.say('হ্যাঁ');
    await w.say('কাল স্কুলে বিজ্ঞান খাতা নিয়ে যেতে হবে');
    await w.say('হ্যাঁ');
    await w.shot('chat');
    await w.done();
  });

  testWidgets('15 ডাক্তার', (t) async {
    final w = await Walk.begin(t, 'p15', 'ডা. ফারহানা, চেম্বার চালান');
    await w.openMic();
    await w.say('আটাশ অক্টোবর রোগী রফিক সাহেবের ফলোআপ');
    await w.say('হ্যাঁ');
    await w.say('চেম্বারে আজ আয় আট হাজার টাকা');
    await w.say('হ্যাঁ');
    await w.say('চেম্বারের ভাড়া পনেরো হাজার টাকা দিলাম');
    await w.say('হ্যাঁ');
    await w.say('এই মাসে চেম্বারে কত আয়');
    await w.shot('chat');
    await w.done();
  });
}
