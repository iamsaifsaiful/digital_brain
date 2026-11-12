/// The example sentences the app shows ("say …"), in Bangla with their
/// English (owner, 12 Nov: the English app shows them in English). The
/// rules understand Bangla, so an example typed, tapped or spoken just as
/// the English app shows it is understood as its Bangla original.
library;

import 'lang.dart' show isEn, tr;

const examplePairs = <(String, String)>[
  ('আমার কাজের তালিকা দাও', 'Show my to-do list'),
  ('সন্ধ্যা ৭টায়', 'at 7 pm'),
  ('সকাল ৯টায়', 'at 9 am'),
  ('আজকের কাজের লিস্ট দাও', 'Show today’s to-do list'),
  ('আমার মোট পাওনা কত?', 'How much am I owed in total?'),
  ('আমি কাকে কত দেব?', 'Who do I owe, and how much?'),
  ('এই মাসে কত খরচ হলো?', 'How much did I spend this month?'),
  ('আজ আমার কী কী আছে?', 'What do I have today?'),
  ('রবিনকে ৫০০০ টাকা ধার দিলাম', 'Lent Robin 5,000 taka'),
  ('কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও', 'Remind me about the meeting tomorrow at 10 am'),
  ('রবিনকে ৫ হাজার টাকা দিলাম আর কাল সকাল ১০টায় মিটিং মনে করিয়ে দিও', 'Gave Robin 5,000 taka, and remind me about the meeting tomorrow at 10 am'),
  ('তুমি কী কী পারো?', 'What can you do?'),
  ('কাল ব্যাংকে যেতে হবে', 'I need to go to the bank tomorrow'),
  ('ব্যাংকের কাজ হয়ে গেছে', 'The bank errand is done'),
  ('বিকেল ৪টায় ক্লায়েন্ট মিটিং মনে করিয়ে দিও', 'Remind me about the client meeting at 4 pm'),
  ('প্রতিদিন রাত ১০টায় ওষুধ', 'Medicine every day at 10 pm'),
  ('প্রতি মাসের ৫ তারিখে দোকান ভাড়া', 'Shop rent on the 5th of every month'),
  ('প্রতি ৩০ মিনিটে পানি খাওয়া', 'Drink water every 30 minutes'),
  ('করিম ৫০০ টাকার মাল বাকিতে নিল', 'Karim took 500 taka of goods on credit'),
  ('রহিমের কাছ থেকে ২ হাজার ধার নিলাম', 'Borrowed 2,000 from Rahim'),
  ('আমি কার কাছে কত পাব?', 'Who owes me, and how much?'),
  ('বাজারে ৫০০ টাকা খরচ হলো', 'Spent 500 taka on groceries'),
  ('বেতন পেলাম ৩০ হাজার', 'Got my salary, 30,000'),
  ('রহিম ভবন প্রজেক্টে রড কিনলাম ২০ হাজার', 'Bought rods for 20,000 in the Rahim House project'),
  ('রহিমকে ফোন দাও', 'Call Rahim'),
  ('করিমকে মেসেজ দাও যে মাল পাঠিয়েছি', 'Text Karim that I’ve sent the goods'),
  ('রহিমের নম্বর ০১৭… রাখো', 'Save Rahim’s number 017…'),
  ('মনে রাখো: গাড়ির কাগজ আলমারিতে', 'Remember: the car papers are in the wardrobe'),
  ('গাড়ির কাগজ কোথায় রেখেছি?', 'Where did I keep the car papers?'),
  ('ফেসবুকের পাসওয়ার্ড দেখাও', 'Show my Facebook password'),
  ('আজ কত তারিখ?', 'What’s the date today?'),
  ('বাজারের লিস্টে ডিম রাখো', 'Add eggs to the grocery list'),
  ('বিকেল ৪টায় মিটিং মনে করিয়ে দিও, ৩০ মিনিট আগে', 'Remind me about the meeting at 4 pm, 30 minutes before'),
  ('কাল সকাল ৬টায় অ্যালার্ম দাও', 'Set an alarm for 6 am tomorrow'),
  ('আজ আরবি তারিখ কত?', 'What’s the Hijri date today?'),
  ('রহিমের জন্মদিন ১২ মার্চ', 'Rahim’s birthday is on 12 March'),
  ('পাসপোর্টের ছবি দেখাও', 'Show the passport photo'),
  ('প্রেসক্রিপশন ফোল্ডার খোলো', 'Open the Prescriptions folder'),
  ('প্রেশার ১২০ বাই ৮০', 'Blood pressure 120 over 80'),
  ('আজ ওজন ৬৫ কেজি', 'My weight is 65 kg today'),
  ('আমার বিএমআই কত?', 'What’s my BMI?'),
  ('মনে রেখো আমি শুক্রবার অফিস করি না', 'Remember, I don’t work on Fridays'),
  ('আমার ব্লাড গ্রুপ বি পজিটিভ', 'My blood group is B positive'),
  ('আমার উচ্চতা ৫ ফুট ৬ ইঞ্চি', 'My height is 5 feet 6 inches'),
  ('হোয়াটসঅ্যাপে কী এসেছে?', 'What’s new on WhatsApp?'),
  ('রহিম কী লিখেছে?', 'What did Rahim write?'),
  ('জরুরি কোনো মেসেজ আছে?', 'Any urgent messages?'),
  ('কম্পাস খোলো', 'Open the compass'),
  ('কিবলা কোন দিকে?', 'Which way is the qibla?'),
  ('আমার খরচ কেমন হচ্ছে?', 'How is my spending going?'),
  ('অপ্রয়োজনীয় খরচ কোথায়?', 'Where am I overspending?'),
  ('দোকান খোলো', 'Open Shop'),
  ('পিডিএফ দাও', 'Make a PDF'),
  ('রিসাইকেল বিন খোলো', 'Open Trash'),
  ('প্রিমিয়াম খোলো', 'Open Premium'),
  ('আজকের কাজের তালিকা', 'Today’s to-do list'),
  ('এই মাসে বাজারে কত গেল?', 'How much went on groceries this month?'),
  ('প্রতি ৩০ মিনিটে পানি', 'Water every 30 minutes'),
  ('আজ ওজন ৬৮ কেজি', 'My weight is 68 kg today'),
  ('সন্ধ্যা ৭টায় মিটিং মনে করিয়ে দিও', 'Remind me about the meeting at 7 pm'),
  ('শুধু অ্যালার্ম', 'Alarm only'),
  ('আজ সন্ধ্যা ৭টায়', 'today at 7 pm'),
  ('কাল সকাল ১০টায়', 'tomorrow at 10 am'),
  ('এক ঘণ্টা পরে', 'in an hour'),
  ('নোট খোলো', 'Open Notes'),
  ('বিকেল ৪টায় মিটিং মনে করিয়ে দিও', 'Remind me about the meeting at 4 pm'),
  ('আমার যাকাত কত?', 'How much is my zakat?'),
  ('রহিম ভবন প্রজেক্টে ৫০ হাজার টাকা এলো', 'Received 50,000 taka in the Rahim House project'),
  ('প্রেশার ১৩০ বাই ৮৫', 'Blood pressure 130 over 85'),
  ('খালি পেটে সুগার ৬.৮', 'Fasting sugar 6.8'),
  ('মনে রেখো, রহিম আমার শ্যালক', 'Remember, Rahim is my brother-in-law'),
  ('রহিমের ৫০০ টাকার লেনদেনটা মুছে দাও', 'Delete Rahim’s 500 taka transaction'),
  ('রহিমের নম্বর কত?', 'What’s Rahim’s number?'),
  ('গাড়ির কাগজ কোথায়?', 'Where are the car papers?'),
  ('আজ কী কী আছে?', 'What do I have today?'),
  ('এ মাসে কত খরচ হলো?', 'How much did I spend this month?'),
  ('বাজারে ৫০০ টাকা খরচ', 'Spent 500 taka on groceries'),
  ('নতুন ধার', 'New loan'),
  ('অ্যালার্ম দাও প্রতিদিন সকাল ৭টায়', 'Set an alarm every day at 7 am'),
  ('স্বাস্থ্যের পাতায় যাও', 'Go to the Health page'),
  ('কাল সকাল ১০টায় ডাক্তারের কাছে যাওয়ার কথা মনে করিয়ে দিও', 'Remind me to see the doctor tomorrow at 10 am'),
  ('মনে রাখো: গাড়ির কাগজ আলমারির উপরের তাকে', 'Remember: the car papers are on the top shelf of the wardrobe'),
  ('রহিমকে ৫০০ টাকা ধার দিলাম', 'Lent Rahim 500 taka'),
  ('রহিমকে ৫০০ টাকা দিলাম', 'Gave Rahim 500 taka'),
  ('রহিমের কাছে কত পাব?', 'How much does Rahim owe me?'),
  ('৩০ মিনিট পরে', 'in 30 minutes'),
  ('রবিনকে ৫০০০ টাকা দিলাম', 'Gave Robin 5,000 taka'),
];

String _key(String s) => s.toLowerCase().replaceAll('’', "'").replaceAll(RegExp(r'[“”"!?.,।:;]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

final _byEnglish = {for (final (bn, en) in examplePairs) _key(en): bn};

/// A one-tap question kept in Bangla (the user's own list, a follow-up),
/// shown in the app's language — and understood as its Bangla when sent.
String asShown(String bn) {
  final en = tr(bn);
  if (isEn && en != bn) _byEnglish[_key(en)] = bn;
  return en;
}

/// The Bangla original of one of the app's own English examples, or [said].
String exampleInBangla(String said) => isEn ? (_byEnglish[_key(said)] ?? said) : said;
