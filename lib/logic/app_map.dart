/// Every part of the app, by the names people call it — so "নোট খোলো",
/// "সেটিংসে যাও", "প্রেসক্রিপশন ফোল্ডার দেখাও" open the right page — and the
/// one list of what the app can do (the help page, "তুমি কী কী পারো?" and the
/// AI's map of the app all come from here).
library;

import 'lang.dart';
import 'parser.dart' show normalize, fold, findAmount;

class AppPlace {
  const AppPlace(this.id, this.title, this.words, this.what, [this.say = const []]);

  /// Stable id (the screens map it to a page).
  final String id;
  final String title;

  /// Names people use for it, Bangla and English (any form of the word).
  final List<String> words;

  /// One line: what is there and what it does.
  final String what;

  /// Things to say to the assistant about it.
  final List<String> say;
}

/// In the order they are shown on the help page.
const appPlaces = <AppPlace>[
  AppPlace('home', 'হোম', ['হোম', 'হোম পেজ', 'হোমপেজ', 'প্রথম পাতা', 'মূল পাতা', 'home'], 'আজকের তারিখ (বাংলা, হিজরি), আজকের কাজ ও রিমাইন্ডার, দরকারি শর্টকাট।',
      ['আজ আমার কী কী আছে?', 'আজ কত তারিখ?']),
  AppPlace('tasks', 'কাজের তালিকা', ['কাজের তালিকা', 'কাজের লিস্ট', 'কাজ', 'টুডু', 'to do', 'todo', 'tasks', 'task'],
      'দিনের কাজ, বাজারের লিস্ট; টিক দিলে শেষ। তালিকা WhatsApp-এ পাঠানো যায়।', ['কাল ব্যাংকে যেতে হবে', 'বাজারের লিস্টে ডিম রাখো', 'ব্যাংকের কাজ হয়ে গেছে']),
  AppPlace('reminders', 'রিমাইন্ডার', ['রিমাইন্ডার', 'reminder', 'reminders', 'মনে করানো'],
      'ঠিক সময়ে বাজে, ফোন লক থাকলেও; ৩০ মিনিট/১ ঘণ্টা/১ দিন আগেও জানাতে পারে; প্রতিদিন, প্রতি মাসে।', ['বিকেল ৪টায় মিটিং মনে করিয়ে দিও, ৩০ মিনিট আগে', 'প্রতি মাসের ৫ তারিখে দোকান ভাড়া']),
  AppPlace('alarms', 'অ্যালার্ম', ['অ্যালার্ম', 'এলার্ম', 'এলাম', 'alarm', 'alarms'], 'ঘুম ভাঙানোর অ্যালার্ম, নিজের পছন্দের রিংটোন।', ['কাল সকাল ৬টায় অ্যালার্ম দাও']),
  AppPlace('calendar', 'ক্যালেন্ডার', ['ক্যালেন্ডার', 'ক্যালেন্ডার', 'calendar', 'পঞ্জিকা', 'বাংলা তারিখ', 'হিজরি তারিখ', 'আরবি তারিখ', 'ছুটির দিন', 'ছুটির তালিকা', 'সরকারি ছুটি', 'সেহরি', 'ইফতার'],
      'বাংলা, ইংরেজি ও হিজরি তারিখ, সরকারি ছুটি, রমজানে সেহরি-ইফতার।', ['আজ আরবি তারিখ কত?']),
  AppPlace('compass', 'কম্পাস', ['কম্পাস', 'compass', 'দিক নির্ণয়', 'দিক নির্দেশক', 'দিক নির্দেশনা', 'কিবলা', 'কেবলা', 'কিবলার দিক', 'qibla'],
      'ফোনের সেন্সরে উত্তর-দক্ষিণ-পূর্ব-পশ্চিম, আর আপনার জেলা থেকে কিবলার দিক — মিললে ফোন কেঁপে জানায়।', ['কম্পাস খোলো', 'কিবলা কোন দিকে?']),
  AppPlace('special', 'বিশেষ দিন', ['বিশেষ দিন', 'বিশেষ দিবস', 'জন্মদিন', 'বিবাহবার্ষিকী', 'বিবাহ বার্ষিকী', 'মৃত্যুবার্ষিকী', 'মৃত্যু বার্ষিকী'],
      'জন্মদিন, বিবাহবার্ষিকী, মৃত্যুবার্ষিকী — প্রতি বছর আগের দিন আর সেদিন মনে করায়।', ['রহিমের জন্মদিন ১২ মার্চ']),
  AppPlace('notes', 'নোট', ['নোট', 'নোটস', 'নোটবুক', 'notes', 'note'], 'যা মনে রাখতে চান; বিভাগ ধরে সাজানো, ছবি-ফাইল যোগ করা যায়, টিক-চিহ্নের তালিকাও।',
      ['মনে রাখো: গাড়ির কাগজ আলমারিতে', 'গাড়ির কাগজ কোথায় রেখেছি?']),
  AppPlace('docs', 'ডকুমেন্টস', ['ডকুমেন্টস', 'ডকুমেন্ট', 'documents', 'document', 'কাগজপত্র', 'দলিলপত্র'],
      'NID, পাসপোর্ট, জমির কাগজ, প্রেসক্রিপশন, ওয়ারেন্টি, পরিবারের ছবি — ফোল্ডারে, তালাবদ্ধ। একসাথে অনেক ছবি রাখা যায়, পরে নাম-বিবরণ বলে খোঁজা যায়।',
      ['পাসপোর্টের ছবি দেখাও', 'প্রেসক্রিপশন ফোল্ডার খোলো']),
  AppPlace('vault', 'পাসওয়ার্ড ভল্ট', ['পাসওয়ার্ড ভল্ট', 'পাসওয়ার্ড', 'ভল্ট', 'vault', 'password', 'passwords'],
      'ওয়েবসাইট, অ্যাপ, Wi-Fi, ব্যাংকের লগইন; দেখতে আঙুলের ছাপ বা PIN লাগে, কখনো জোরে পড়া হয় না।', ['ফেসবুকের পাসওয়ার্ড দেখাও']),
  AppPlace('contacts', 'যোগাযোগ', ['যোগাযোগ', 'কন্টাক্ট', 'কন্টাক্টস', 'contacts', 'contact', 'ফোনবুক', 'phonebook'],
      'নাম বললেই ফোন, SMS বা WhatsApp; নম্বর, ঠিকানা (ম্যাপে খোলে) আর কাগজ একসাথে।', ['রহিমকে ফোন দাও', 'করিমকে মেসেজ দাও যে মাল পাঠিয়েছি']),
  AppPlace('money', 'আয়-ব্যয়', ['আয় ব্যয়', 'আয়-ব্যয়', 'আয়ব্যয়', 'খরচের হিসাব', 'হিসাব', 'money', 'income', 'expense'],
      'নিজের আয় আর খরচ খাত ধরে; মাসের ব্যালেন্স।', ['বাজারে ৫০০ টাকা খরচ হলো', 'বেতন পেলাম ৩০ হাজার', 'এই মাসে কত খরচ হলো?']),
  AppPlace('ledger', 'লেনদেন (ধার-দেনা)', ['লেনদেন', 'ধার দেনা', 'ধার-দেনা', 'ধারদেনা', 'বাকির খাতা', 'বাকি খাতা', 'খাতা', 'পাওনা দেনা', 'ledger'],
      'কে কত পাবে, কাকে কত দিতে হবে; ফেরতের তারিখে মনে করায়; এক চাপে তাগাদার মেসেজ।', ['করিম ৫০০ টাকার মাল বাকিতে নিল', 'আমি কার কাছে কত পাব?']),
  AppPlace('projects', 'অন্যান্য হিসাব', ['অন্যান্য হিসাব', 'আলাদা হিসাব', 'প্রজেক্ট', 'প্রকল্প', 'project', 'projects'], 'প্রতিটা কাজের (বাড়ি, বিয়ে, ঈদ) আলাদা আয়-খরচ আর বাজেট।',
      ['রহিম ভবন প্রজেক্টে রড কিনলাম ২০ হাজার']),
  AppPlace('report', 'মাসের রিপোর্ট', ['মাসের রিপোর্ট', 'রিপোর্ট', 'report'], 'মাসের আয়, খরচ, ব্যালেন্স; কোন খাতে বেশি গেল, গত মাসের সাথে তুলনা।'),
  AppPlace('accounts', 'অ্যাকাউন্ট', ['অ্যাকাউন্ট', 'একাউন্ট', 'account', 'accounts'], 'হাতের টাকা, বিকাশ, নগদ, ব্যাংক — কোথায় কত আছে, এক জায়গা থেকে আরেক জায়গায় পাঠানো।'),
  AppPlace('savings', 'সঞ্চয় ও কিস্তি', ['সঞ্চয়', 'সেভিংস', 'কিস্তি', 'ডিপিএস', 'dps', 'savings'], 'সঞ্চয়ের লক্ষ্য, কিস্তি আর DPS-এর হিসাব, দেওয়ার দিনে মনে করানো।'),
  AppPlace('spending', 'খরচ বিশ্লেষণ', ['খরচ বিশ্লেষণ', 'খরচের বিশ্লেষণ', 'খরচের ভাগ', 'আয়ের ভাগ', 'অপ্রয়োজনীয় খরচ', 'অপচয়'],
      'এ সপ্তাহে বা ৩০ দিনে আয়ের কত ভাগ কোন খাতে গেল — প্রয়োজনীয়, শখের, সঞ্চয়; ৫০/৩০/২০ নিয়মের সাথে মিলিয়ে কোথায় কমানো যায়।', ['আমার খরচ কেমন হচ্ছে?', 'অপ্রয়োজনীয় খরচ কোথায়?']),
  AppPlace('zakat', 'যাকাত', ['যাকাত', 'জাকাত', 'zakat'], 'সম্পদ লিখলে যাকাতের হিসাব করে দেয়।'),
  AppPlace('split', 'খরচ ভাগাভাগি', ['খরচ ভাগাভাগি', 'ভাগাভাগি', 'খরচ ভাগ', 'split'], 'কয়েকজনের খরচ ভাগ করে কে কাকে কত দেবে।'),
  AppPlace('shop', 'দোকান', ['দোকানের হিসাব', 'দোকান', 'shop', 'ব্যবসা', 'আমার দোকান'], 'একাধিক দোকান — প্রতিটার নাম, নম্বর, ঠিকানা; আলাদা বিক্রি, খরচ, কাস্টমারের বাকি আর রসিদ, উপরে সব দোকান মিলিয়ে।', ['দোকান খোলো']),
  AppPlace('pdf', 'সবকিছু PDF আকারে', ['পিডিএফ', 'pdf', 'সব তথ্যের পিডিএফ', 'রিপোর্ট ডাউনলোড'], 'যা যা চান বেছে নিয়ে এক PDF-এ — ডাউনলোড, শেয়ার বা প্রিন্ট। প্রতিটা পাতার উপরেও PDF বোতাম আছে।', ['পিডিএফ দাও']),
  AppPlace('health', 'স্বাস্থ্য', ['স্বাস্থ্য', 'হেলথ', 'health', 'বিএমআই', 'bmi', 'প্রেশার', 'সুগার', 'ডায়াবেটিস', 'ওজন', 'টিকা', 'টিকার কার্ড', 'ভ্যাকসিন', 'vaccine'],
      'BMI, প্রেশার, সুগার, ওজন — গ্রাফসহ; পরিবারের প্রত্যেকের আলাদা; শিশুর টিকার কার্ড; ডাক্তারকে দেখানোর সারাংশ।', ['প্রেশার ১২০ বাই ৮০', 'আজ ওজন ৬৫ কেজি', 'আমার বিএমআই কত?']),
  AppPlace('medicines', 'ওষুধ', ['ওষুধ', 'ঔষধ', 'অষুধ', 'মেডিসিন', 'medicine', 'medicines'], 'কোন ওষুধ কখন খাবেন, সময়মতো মনে করানো; ফুরিয়ে এলে জানানো।', ['প্রতিদিন রাত ১০টায় ওষুধ']),
  AppPlace('habits', 'অভ্যাস', ['অভ্যাস', 'habit', 'habits'], 'নামাজ, হাঁটা, পানি খাওয়া — প্রতিদিন টিক, টানা কত দিন হলো।'),
  AppPlace('diary', 'ডায়েরি', ['ডায়েরি', 'ডায়রি', 'ডাইরি', 'দিনলিপি', 'diary'], 'দিনের কথা লিখে রাখা; তারিখ ধরে খোঁজা।'),
  AppPlace('emergency', 'জরুরি', ['জরুরি কার্ড', 'জরুরি', 'ইমার্জেন্সি', 'emergency', 'হেল্পলাইন'],
      'রক্তের গ্রুপ, জরুরি নম্বর (৯৯৯, ফায়ার সার্ভিস ১০২…), ওষুধ আর অ্যালার্জি।'),
  AppPlace('expiry', 'কাগজের মেয়াদ', ['কাগজের মেয়াদ', 'মেয়াদ', 'expiry'], 'পাসপোর্ট, লাইসেন্স, ট্যাক্স টোকেনের মেয়াদ শেষের আগে মনে করায়।'),
  AppPlace('tags', 'ট্যাগ', ['ট্যাগ', 'tag', 'tags'], 'এক ট্যাগে নোট, কাগজ, কাজ সব একসাথে।'),
  AppPlace('memory', 'আমার সম্পর্কে', ['মনে রাখা কথা', 'আমার সম্পর্কে', 'memory'], 'আপনার সম্পর্কে যা বলেছেন (অভ্যাস, পছন্দ, সম্পর্ক) — উত্তরে কাজে লাগে।',
      ['মনে রেখো আমি শুক্রবার অফিস করি না']),
  AppPlace('templates', 'তৈরি তালিকা', ['তৈরি তালিকা', 'টেমপ্লেট', 'template', 'templates'], 'হজ, বিয়ে, নতুন বাসা, দেশে ফেরা — তৈরি কাজের তালিকা এক চাপে।'),
  AppPlace('store', 'সব কিছু', ['সব কিছু', 'সবকিছু', 'স্টোর', 'store'], 'অ্যাপের সব অংশ এক পাতায়।'),
  AppPlace('search', 'খুঁজুন', ['খোঁজার পাতা', 'সার্চ', 'search'], 'নোট, কাগজ, নম্বর, লেনদেন — সব জায়গায় একসাথে খোঁজা।'),
  AppPlace('requests', 'ব্লাড ডোনেশন', ['ব্লাড ডোনেশন', 'রক্তদান', 'রক্ত দান', 'অনুরোধ', 'রক্তের অনুরোধ', 'রক্ত চাই', 'রক্ত লাগবে', 'ব্লাড', 'ব্লাড ডোনার', 'blood', 'blood donation', 'blood donor', 'blood request'],
      'রক্ত দরকার হলে অনুরোধ দিন — কার জন্যে, সমস্যা, হাসপাতাল, তারিখ আর নম্বরসহ; সারা দেশের সবাই দেখবেন, আপনার জেলার দাতারা নোটিফিকেশনও পাবেন। দাতা হলে “আমি দিতে পারব” বলতে পারবেন।', ['ব্লাড ডোনেশন খোলো']),
  AppPlace('family', 'ফ্যামিলি', ['ফ্যামিলি', 'পরিবার', 'family'],
      'পরিবারের সদস্যদের ইমেইলে যুক্ত করে তাঁদের জন্য কাজ, রিমাইন্ডার, ওষুধের রিমাইন্ডার, নোট দেওয়া; অনুমতি থাকলে লাইভ লোকেশন; উত্তরাধিকারী (প্রিমিয়াম)।', ['ফ্যামিলি খোলো']),
  AppPlace('settings', 'সেটিংস', ['সেটিংস', 'সেটিং', 'সেটিংসে', 'settings', 'setting', 'আরও'],
      'প্রোফাইল (নাম, জেলা, রক্তের গ্রুপ), রক্তদান, ভাষা, থিম ও নিজের রং, সহজ মোড, তালা, ব্যাকআপ, মতামত পাঠানো।'),
  AppPlace('notifications', 'নোটিফিকেশন', ['নোটিফিকেশন', 'notification', 'notifications', 'বিজ্ঞপ্তি'], 'কোন বার্তা আসবে, রাতে চুপ থাকা, দিনে কয়টা।'),
  AppPlace('sound', 'রিংটোন', ['রিংটোন', 'ringtone', 'সাউন্ড'], 'রিমাইন্ডার আর অ্যালার্মের শব্দ।'),
  AppPlace('backup', 'ব্যাকআপ', ['ব্যাকআপ', 'backup'], 'সব তথ্য একটা তালাবদ্ধ ফাইলে; ফোন বদলালে ফিরিয়ে আনা যায়।'),
  AppPlace('pro', 'প্রিমিয়াম', ['প্রিমিয়াম ভার্সন', 'প্রিমিয়াম', 'premium', 'প্রো ভার্সন', 'প্রো', 'pro', 'সাবস্ক্রিপশন'], 'AI সহকারী, বিজ্ঞাপন ছাড়া, একাধিক দোকান, PDF, যাকাতের নিজে-হিসাব আর আরও সুবিধা।', ['প্রিমিয়াম খোলো']),
  AppPlace('help', 'কী কী করা যায়', ['কী কী করা যায়', 'সাহায্য', 'হেল্প', 'help', 'গাইড'], 'অ্যাপের সব সুবিধা আর কী বললে কী হয়।'),
];

AppPlace? placeById(String id) {
  for (final p in appPlaces) {
    if (p.id == id) return p;
  }
  return null;
}

/// A folder of papers or a note category, by its words.
class FolderHint {
  const FolderHint(this.kind, this.name, [this.words = const []]);

  /// 'docs' or 'notes'.
  final String kind;
  final String name;
  final List<String> words;
}

/// The built-in paper folders and what people call them.
const docFolderWords = <String, List<String>>{
  'জাতীয় পরিচয়পত্র': ['জাতীয় পরিচয়পত্র', 'এনআইডি', 'nid', 'আইডি কার্ড', 'ভোটার আইডি'],
  'পাসপোর্ট': ['পাসপোর্ট', 'passport'],
  'জমি ও বাড়ির কাগজ': ['জমি ও বাড়ির কাগজ', 'জমির কাগজ', 'বাড়ির কাগজ', 'দলিল'],
  'বিল ও রসিদ': ['বিল ও রসিদ', 'রসিদ', 'বিলের কাগজ'],
  'সার্টিফিকেট': ['সার্টিফিকেট', 'সনদ', 'certificate'],
  'চিকিৎসা': ['চিকিৎসার কাগজ', 'চিকিৎসা', 'মেডিকেল'],
  'প্রেসক্রিপশন': ['প্রেসক্রিপশন', 'prescription', 'ব্যবস্থাপত্র'],
  'ওয়ারেন্টি ও গ্যারান্টি': ['ওয়ারেন্টি', 'গ্যারান্টি', 'warranty'],
  'গাড়ি ও লাইসেন্স': ['গাড়ির কাগজ', 'ড্রাইভিং লাইসেন্স', 'লাইসেন্স'],
  'পরিবারের ছবি': ['পরিবারের ছবি', 'ফ্যামিলি ছবি', 'ফ্যামিলির ছবি', 'পারিবারিক ছবি'],
};

// Endings a name may carry ("নোটে", "সেটিংসে", "ওষুধগুলো", "ডায়েরিতে").
const _endings = ['গুলোতে', 'গুলো', 'গুলি', 'টাতে', 'টায়', 'টা', 'টি', 'তে', 'য়', 'এর', 'ের', 'র', 'এ', 'ে', 's'];

/// Pages that "… দেখাও" simply opens.
const _pagesToShow = {'pro', 'requests', 'family', 'shop', 'calendar', 'settings', 'help', 'notifications', 'sound', 'backup', 'accounts', 'savings', 'zakat', 'split', 'emergency', 'templates', 'pdf', 'health'};

// Words that open a page.
const _openVerbs = [
  'খুলে দাও', 'খুলে দেন', 'খুলে দিন', 'খুলে দে', 'খোলো', 'খোল', 'খুলো', 'খুলুন', 'খুলেন', 'খুলবে', 'ওপেন করো', 'ওপেন কর', 'ওপেন করেন', 'ওপেন', 'open', //
  'নিয়ে যাও', 'নিয়ে যান', 'নিয়ে চলো', 'নিয়ে চলেন', 'যাও', 'যান', 'চলো', 'চলেন', 'চলুন', 'go to', 'go',
];
// "দেখাও" opens a page only with a word like পাতা or ফোল্ডার ("রিমাইন্ডার
// দেখাও" is a question and gets an answer).
const _showVerbs = ['দেখাও', 'দেখান', 'দেখাবে', 'দেখি', 'show'];
const _containers = ['পাতা', 'পাতাটা', 'পেজ', 'পেজটা', 'পেইজ', 'স্ক্রিন', 'সেকশন', 'অপশন', 'অপশনটা', 'ফোল্ডার', 'ফোল্ডারটা', 'বিভাগ', 'page', 'folder', 'section'];
const _fillers = [
  'দয়া করে', 'আমার', 'আমাকে', 'আমাদের', 'একটু', 'তো', 'প্লিজ', 'please', 'জি', 'ভাই', 'আপা', 'এখন', 'এখনই', 'সব', 'সবগুলো', 'টা', 'একটা', //
  'অ্যাপের', 'অ্যাপে', 'অ্যাপ', 'app', 'the', 'my', 'to', 'এ', 'তে', 'ওই', 'ঐ', 'সেই', 'এই', 'তালিকা', 'লিস্ট', 'list',
];

String _esc(String s) => RegExp.escape(s);

/// Removes [phrase] (with any ending) from [text]; null when it is not there.
String? _cut(String text, String phrase) {
  final p = normalize(phrase);
  if (p.isEmpty) return null;
  final ends = _endings.map(normalize).map(_esc).join('|');
  final re = RegExp('(^| )${_esc(p)}($ends)?(?= |\$)');
  if (!re.hasMatch(text)) return null;
  return text.replaceFirst(re, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _cutAll(String text, List<String> phrases) {
  var t = text;
  // Longest first, so "খুলে দাও" goes before "দাও"-less "খুলে".
  final sorted = [...phrases]..sort((a, b) => b.length.compareTo(a.length));
  for (final p in sorted) {
    while (true) {
      final next = _cut(t, p);
      if (next == null) break;
      t = next;
    }
  }
  return t;
}

/// (page id, folder) when [text] (normalized) asks to open a part of the
/// app — and says nothing else. [folders]: the user's own paper folders and
/// note categories.
(String, FolderHint?)? openRequest(String text, {List<FolderHint> folders = const []}) {
  final hasOpen = _openVerbs.any((v) => _cut(text, v) != null);
  final showing = _showVerbs.any((v) => _cut(text, v) != null);
  final hasShow = showing && _containers.any((c) => _cut(text, c) != null);
  if (!hasOpen && !hasShow && !showing) return null;
  // "দোকান দেখাও": a page with nothing to answer about it opens even
  // with "দেখাও" alone ("রিমাইন্ডার দেখাও" is still a question).
  final onlyPages = !hasOpen && !hasShow;
  // The thing named: a folder first (it is more specific), then a page.
  final candidates = <(String, FolderHint?, String)>[
    for (final f in folders)
      for (final w in [f.name, ...f.words]) (f.kind, f, w),
    for (final p in appPlaces)
      for (final w in p.words) (p.id, null, w),
  ]..sort((a, b) => b.$3.length.compareTo(a.$3.length));
  for (final (id, folder, w) in candidates) {
    final rest = _cut(text, w);
    if (rest == null) continue;
    final left = _cutAll(rest, [..._openVerbs, ..._showVerbs, ..._containers, ..._fillers]);
    if (left.isEmpty && (!onlyPages || _pagesToShow.contains(id))) return (id, folder);
    // Only the first (longest) name found counts.
    return null;
  }
  return null;
}

/// A part of the app mentioned anywhere in [text] (normalized), for a "দেখুন" link.
AppPlace? placeMentioned(String text) {
  final all = [for (final p in appPlaces) for (final w in p.words) (p, w)]..sort((a, b) => b.$2.length.compareTo(a.$2.length));
  for (final (p, w) in all) {
    if (normalize(w).length < 3) continue;
    if (_cut(text, w) != null) return p;
  }
  return null;
}

/// "কিভাবে ডকুমেন্টস যুক্ত করব?", "নোট কীভাবে রাখে?": how to do something
/// in a part of the app — a question, never a to-do. The part, or null.
AppPlace? howToAsked(String said) {
  final text = ' ${normalize(said)} ';
  bool any(List<String> ws) => ws.any((w) => text.contains(' ${normalize(w)}') || text.contains(normalize(w)));
  if (!any(const ['কিভাবে', 'কীভাবে', 'কি ভাবে', 'কী ভাবে', 'কেমনে', 'কেমন করে', 'কি করে', 'কী করে', 'how to', 'how do'])) return null;
  if (!any(const ['করব', 'করবো', 'করতে', 'করে', 'করা', 'রাখব', 'রাখবো', 'রাখতে', 'রাখে', 'দেখব', 'দেখবো', 'দেখতে', 'খুলব', 'খুলবো', 'খুলতে', 'যুক্ত', 'যোগ', 'দিব', 'দেব', 'দিতে', 'পাঠাব', 'পাঠাতে', 'বানাব', 'বানাতে', 'চালু', 'বন্ধ', 'মুছব', 'মুছতে', 'add', 'use'])) return null;
  final p = placeMentioned(normalize(said));
  // "তুমি কিভাবে হেল্প করতে পারো?" is about the assistant, not a page.
  return p == null || p.id == 'help' ? null : p;
}

/// "ডকুমেন্টসে ওয়ারেন্টি কার্ড রাখা যায়?", "ছবি থেকে ওয়ারেন্টির তারিখ নিতে
/// পারবা?": can the app do this — answered from what it really does, never
/// a search of the user's data. ('photo_date', 'warranty') or null.
String? abilityAsked(String said) {
  final t = ' ${fold(normalize(said))} ';
  bool any(String re) => RegExp(fold(re)).hasMatch(t);
  if (findAmount(normalize(said)) != null) return null;
  final can = any(r'(?:পারবা|পারবে|পারবেন|পারো|পারেন|পারবি|পারব|যাবে|যায়|সম্ভব|সিস্টেম|ব্যবস্থা|অপশন|আছে\s*$|\?)') || said.contains('?');
  if (!can) return null;
  final photo = any(r'(?:ছবি|ফটো|স্ক্যান|ক্যামেরা|photo|scan)');
  final date = any(r'(?:তারিখ|মেয়াদ|ওয়ারেন্টি|ওয়ারেন্টি|গ্যারান্টি|warranty|expiry|লেখা)');
  final read = any(r'(?:নিতে|নেওয়া|নিবা|নেবে|পড়তে|পড়ে|পড়া|বের\s+করতে|তুলে)');
  if (photo && date && read) return 'photo_date';
  if (any(r'(?:ওয়ারেন্টি|ওয়ারেন্টি|গ্যারান্টি|warranty)') && any(r'(?:রাখা|রাখার|রাখতে|রাখব|রাখি|সিস্টেম|ব্যবস্থা|জায়গা|ফোল্ডার)')) return 'warranty';
  return null;
}

String abilityAnswer(String id) => switch (id) {
      'photo_date' => tr(
          'পারি। ডকুমেন্টসে কাগজের ছবি বা PDF যোগ করলে তার ছাপা লেখা ফোনেই পড়ি — নাম, NID বা পাসপোর্ট নম্বর, জন্মতারিখ, ইস্যু আর মেয়াদ শেষের তারিখ, ইনভয়েস-সিরিয়াল-IMEI, ওয়ারেন্টি — যা পাই, তথ্যের ঘরে বসিয়ে দেখাই, আপনি মিলিয়ে নিয়ে রাখবেন। আগে রাখা কাগজেও “ছবি থেকে তথ্য পড়ুন” চাপলে পড়ে দিই। শুধু “১ বছর ওয়ারেন্টি” লেখা থাকলে কেনার তারিখ থেকে হিসাব করি। ইংরেজিতে ছাপা অক্ষর-অঙ্ক সবচেয়ে ভালো পড়া যায়; হাতের লেখা বা বাংলা লেখা এখনো পড়তে পারি না।'),
      _ => tr(
          'হ্যাঁ। ডকুমেন্টসে “ওয়ারেন্টি ও গ্যারান্টি” নামে আলাদা ফোল্ডার আছে — কার্ড বা রসিদের ছবি তুলে সেখানে রাখুন। ছবি থেকে ওয়ারেন্টি শেষের তারিখও পড়ে নিতে পারি; প্রিমিয়ামে মেয়াদ শেষের আগে মনে করিয়ে দিই।'),
    };

/// The answer to [howToAsked]: what is there, and how to get to it.
String howToAnswer(AppPlace p) {
  final say = p.say.isEmpty ? '' : trf(' আমাকে বলেও করা যায় — যেমন “{0}”।', [tr(p.say.first)]);
  return trf('{0}: {1} নিচের বোতাম চেপে {0} পাতা খুলুন — সেখানে নতুন যোগ করা, দেখা আর বদলানো যায়।{2}', [tr(p.title), tr(p.what), say]);
}

/// "তুমি কী কী পারো?" — spoken: short; shown: one line per part.
String capabilitiesSpoken() => tr(
    'অনেক কিছু পারি — কাজের তালিকা, সময়মতো মনে করানো, ফোন-মেসেজ, ধার-দেনা আর আয়-ব্যয়ের হিসাব, নোট, কাগজপত্র, পাসওয়ার্ড, স্বাস্থ্য আর বিশেষ দিন। যেকোনো পাতাও খুলে দিতে পারি — যেমন বলুন “নোট খোলো”। পুরো তালিকা নিচে দিলাম।');

String capabilitiesList() => [
      for (final p in appPlaces)
        if (p.id != 'home' && p.id != 'store' && p.id != 'search' && p.id != 'help') '• ${tr(p.title)} — ${tr(p.what)}',
    ].join('\n');

/// The app's parts for the AI ("id: name — what").
String appMapForAi() => [for (final p in appPlaces) '${p.id}: ${p.title} — ${p.what}'].join('\n');

// ───────────────────────── What each menu can do by voice ─────────────────────────

/// How far a menu can be used by voice: the page can be opened, its data
/// asked about, and/or written. Read by the chat ("কী করতে পারো?"), by the
/// AI's tool schema (the `menu` action may only name these ops) and by the
/// executor (state/menu_chat.dart), so the three never disagree.
enum VoiceLevel { full, partial, openOnly }

class VoiceCap {
  const VoiceCap(this.level, this.ops, {this.notYet = const []});
  final VoiceLevel level;

  /// The [MenuAction.op]s the executor carries out for this menu, with what
  /// each does (shown to the AI).
  final Map<String, String> ops;

  /// What is asked for but cannot be done by voice yet (said plainly).
  final List<String> notYet;
}

/// Menus beyond to-dos, reminders, notes, contacts and the money book (those
/// have their own typed actions). Keys are [MenuAction.domain]s.
const voiceCaps = <String, VoiceCap>{
  'accounts': VoiceCap(VoiceLevel.full, {
    'balance': 'how much is in all accounts, or in one (target)',
    'transfer': 'money moved from target to target2 (amount; fee in amount2) — not income or spending',
    'fee': 'a charge (amount) taken from account target',
    'set_balance': 'the user states what is in account target now (amount) — asked once, never income',
    'withdraw_spend': 'taken out of target (amount) and part spent (amount2, on text) from cash',
  }),
  'savings': VoiceCap(VoiceLevel.full, {
    'goal_add': 'a saving goal named target of amount',
    'deposit': 'amount put into goal target (happened)',
    'withdraw': 'amount taken out of goal target (happened; not spending)',
    'goal_left': 'how much is left for goal target (or all)',
  }),
  'installment': VoiceCap(VoiceLevel.full, {
    'paid': "this month's instalment/DPS paid", 'not_paid': 'said it is not paid (nothing written)', 'unpay': 'ticked paid by mistake',
  }),
  'medicine': VoiceCap(VoiceLevel.partial, {
    'list': 'show the medicines (then "এগুলো…" points at them)',
    'dose': 'a dose taken (target medicine, part of day)', 'dose_not': 'not taken (nothing written)', 'dose_undo': 'ticked taken by mistake',
    'stock_add': 'amount more pills of target bought', 'stock_query': 'how long target lasts', 'reminder_off': "turn off target's reminders, keep it",
  }, notYet: ['ওষুধের সময় বা ডোজ কথায় বদলানো', 'নতুন ওষুধ কথায় যোগ করা']),
  'habit': VoiceCap(VoiceLevel.full, {
    'list': "show the habits with today's ticks",
    'add': 'a new daily habit named target', 'tick': 'done on day (today if not said)', 'not_done': 'not done on day (untick if ticked)',
    'streak': 'days in a row for target', 'reminder_set': 'a daily reminder for target at time', 'reminder_off': "turn off target's reminder, keep the habit",
  }),
  'memory': VoiceCap(VoiceLevel.full, {'forget': 'forget a kept fact about the user (text: its words)'}),
  'people': VoiceCap(VoiceLevel.partial, {'rename': 'give person target in the ledger the name text (all their records)'}),
  'alarm': VoiceCap(VoiceLevel.full, {'all_off': 'turn off every alarm (asked once, not deleted)'}),
  'trash': VoiceCap(VoiceLevel.partial, {'restore': 'bring back the last deleted item of a kind (target: নোট, কাজ…)'}),
  'backup': VoiceCap(VoiceLevel.partial, {'when': 'when the last backup was', 'now': 'back up to Google Drive now', 'status': 'whether Google backup is on, and the last one'}, notYet: ['ব্যাকআপ থেকে ফিরিয়ে আনা (পাতায় দেখে করতে হয়)']),
  'settings': VoiceCap(VoiceLevel.partial, {'call_me': 'the name to call the user (text)', 'look': 'dark or light (text)', 'letters': 'bigger or smaller (text)'},
      notYet: ['AI চালু/বন্ধ', 'তালা ও PIN', 'ভাষা']),
  'project': VoiceCap(VoiceLevel.full, {'create': 'a new separate account named target', 'budget': 'budget amount for project target', 'close': 'mark project target finished (kept)'}),
  'shop': VoiceCap(VoiceLevel.partial, {
    'sale': 'a sale of amount at shop target (cash received)', 'credit_sale': 'goods of amount to person target, amount2 paid now — the rest owed',
    'today': "a shop's sales and costs today", 'calc': 'quantity amount × unit price amount2 (nothing written)', 'profit': 'profit needs costs (nothing written)',
  }, notYet: ['রসিদ কথায় বানানো বা খোলা', 'স্টক']),
  'cash': VoiceCap(VoiceLevel.full, {
    'spend': 'spending in a span (day…until), category text', 'income': 'income in a span', 'net': 'income minus spending in a span',
    'recategorize': 'move the latest expense about target to category text', 'dupes': 'find two identical expenses; one removed if confirmed',
  }),
  'notes': VoiceCap(VoiceLevel.partial, {'list': 'show notes of a category or with words (text)', 'read': 'read one note out as written (text: its words)', 'replace_word': 'in the latest note with word target, write text instead'}),
  'health': VoiceCap(VoiceLevel.partial, {'list': "a family member's last readings (target, amount = how many)", 'none': 'nothing measured (nothing written)', 'fix_last': 'the last reading amount/10 was really amount2/10'},
      notYet: ['টিকা দেওয়া হয়েছে কথায় টিক দেওয়া', 'চেকআপের তারিখ কথায় বদলানো']),
  'zakat': VoiceCap(VoiceLevel.partial, {'price': "today's gold/silver price from BAJUS through our server (text gold|silver)", 'set_price': "put today's 22-carat prices into the zakat page"},
      notYet: ['যাকাতের সম্পদ কথায় লেখা']),
  'special': VoiceCap(VoiceLevel.partial, {'age': "a person's age from their birthday (only with a birth year)", 'month': "whose special days fall in a month"}),
  'diary': VoiceCap(VoiceLevel.openOnly, {}, notYet: ['ডায়েরিতে আলাদা লেখা রাখা']),
  'docs': VoiceCap(VoiceLevel.partial, {}, notYet: ['ফাইলের ভেতরের লেখা পড়া (OCR)', 'ফাইলের নাম বা মেয়াদ কথায় বদলানো']),
  'requests': VoiceCap(VoiceLevel.openOnly, {}, notYet: ['রক্তের অনুরোধ কথায় লেখা বা প্রকাশ করা']),
  'family': VoiceCap(VoiceLevel.openOnly, {}, notYet: ['পরিবারের কারো জন্য কথায় কাজ বা রিমাইন্ডার পাঠানো']),
  'emergency': VoiceCap(VoiceLevel.partial, {'allergy_none': '"no allergy" said — not written as an allergy'}, notYet: ['জরুরি নম্বর ও অ্যালার্জি কথায় লেখা']),
};
