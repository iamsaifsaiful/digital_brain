/// One thought about money for each day — on the home page and in a
/// morning notification. Bangla sayings and plain advice; the few with a
/// source name it (two Quran verses, Benjamin Franklin's "The Way to
/// Wealth"). Nothing here is made up in anyone's name.
library;

import 'lang.dart';

class MoneyQuote {
  const MoneyQuote(this.text, [this.source = '']);
  final String text;

  /// Where it is from; '' for a saying or plain advice.
  final String source;
}

const moneyQuotes = <MoneyQuote>[
  MoneyQuote('আয় বুঝে ব্যয় করো।', 'প্রবাদ'),
  MoneyQuote('খরচের পর যা থাকে তা জমাবেন না; জমানোর পর যা থাকে, তা খরচ করুন।'),
  MoneyQuote('ছোট খরচগুলোকে অবহেলা করবেন না — ছোট একটা ফুটোই বড় জাহাজ ডুবিয়ে দিতে পারে।', 'বেঞ্জামিন ফ্র্যাংকলিন, “দ্য ওয়ে টু ওয়েলথ”'),
  MoneyQuote('আর তোমরা অপচয় কোরো না। নিশ্চয়ই অপচয়কারীরা শয়তানের ভাই।', 'সূরা বনী ইসরাঈল, ১৭:২৬-২৭'),
  MoneyQuote('আর যারা ব্যয় করার সময় অপব্যয় করে না, কৃপণতাও করে না — বরং এ দুয়ের মাঝামাঝি থাকে।', 'সূরা আল-ফুরকান, ২৫:৬৭'),
  MoneyQuote('বিন্দু বিন্দু জলে সিন্ধু হয় — প্রতিদিনের অল্প সঞ্চয়ই একদিন বড় সম্বল।', 'প্রবাদ'),
  MoneyQuote('যা দরকার তা কিনুন; যা ভালো লাগে, তা কেনার আগে এক দিন অপেক্ষা করুন।'),
  MoneyQuote('বেতন হাতে আসার দিনই আগে সঞ্চয়ের অংশটা সরিয়ে রাখুন — পরে আর থাকে না।'),
  MoneyQuote('তিন থেকে ছয় মাসের খরচের সমান টাকা বিপদের জন্য আলাদা রাখুন।'),
  MoneyQuote('ধার করে শখ মেটানো মানে ভবিষ্যতের আয় আজ খরচ করে ফেলা।'),
  MoneyQuote('প্রতিটা খরচ লিখে রাখুন — না লিখলে বোঝাই যায় না টাকা কোথায় যায়।'),
  MoneyQuote('আয়ের মোটামুটি অর্ধেক প্রয়োজনে, এক-তৃতীয়াংশের কম শখে, আর অন্তত এক-পঞ্চমাংশ সঞ্চয়ে।'),
  MoneyQuote('দামি জিনিস নয়, দরকারি জিনিস কিনুন।'),
  MoneyQuote('বাইরে খাওয়া মাঝে মাঝে আনন্দ; প্রতিদিন হলে বড় খরচ।'),
  MoneyQuote('ঋণ নেওয়ার আগে ভাবুন — কিস্তি দেওয়ার দিনও আসবে।'),
  MoneyQuote('অন্যকে দেখে খরচ করবেন না; নিজের আয় দেখে করুন।'),
  MoneyQuote('ছাড় দেখে কেনা নয় — দরকার থাকলে তবেই ছাড় কাজে লাগে।'),
  MoneyQuote('মাসের শুরুতেই একটা খরচের সীমা ঠিক করুন, শেষে মিলিয়ে দেখুন।'),
  MoneyQuote('পাওনা টাকা সময়মতো তুলুন, দেনা সময়মতো শোধ করুন — সম্পর্ক আর হিসাব দুটোই ভালো থাকে।'),
  MoneyQuote('শিক্ষা আর স্বাস্থ্যে খরচ খরচ নয়, বিনিয়োগ।'),
  MoneyQuote('অল্প আয়েও সঞ্চয় সম্ভব — শুরুটা যত ছোটই হোক।'),
  MoneyQuote('বিল আর কিস্তির তারিখ মনে রাখলে জরিমানার টাকা বাঁচে।'),
  MoneyQuote('যে খরচ না করলেও চলে, সপ্তাহে একবার তার তালিকা করুন — অর্ধেক কমালেই অনেক বাঁচে।'),
  MoneyQuote('হঠাৎ পাওয়া টাকা হঠাৎ খরচ নয় — আগে একটা অংশ জমা রাখুন।'),
  MoneyQuote('দান করলে সম্পদ কমে না — নিজের সামর্থ্য বুঝে নিয়মিত দিন।'),
  MoneyQuote('মোবাইলে কেনাকাটা সহজ, তাই সাবধানও হতে হয় বেশি।'),
  MoneyQuote('ধীরে ধীরে জমানো টাকা হঠাৎ পাওয়া টাকার চেয়ে বেশি দিন থাকে।'),
  MoneyQuote('পরিবারের সবাই মিলে বাজেট করলে খরচ কমানো সহজ হয়।'),
  MoneyQuote('টাকা ভালো ভৃত্য, কিন্তু খারাপ মালিক।', 'প্রবাদ'),
  MoneyQuote('আজকের ছোট সংযম কালকের বড় স্বস্তি।'),
];

/// The thought for [day] (the same all day, a new one each day).
MoneyQuote quoteFor(DateTime day) {
  final n = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(2026)).inDays;
  return moneyQuotes[n % moneyQuotes.length];
}

/// As shown: "“…” — source".
String quoteText(MoneyQuote q) => q.source.isEmpty ? '“${tr(q.text)}”' : '“${tr(q.text)}” — ${tr(q.source)}';
