/// Every part of the app, by the names people call it — so "নোট খোলো",
/// "সেটিংসে যাও", "প্রেসক্রিপশন ফোল্ডার দেখাও" open the right page — and the
/// one list of what the app can do (the help page, "তুমি কী কী পারো?" and the
/// AI's map of the app all come from here).
library;

import 'lang.dart';
import 'parser.dart' show normalize;

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
  AppPlace('inbox', 'মেসেজ থেকে কাজ', ['মেসেজ থেকে কাজ', 'বার্তা থেকে কাজ', 'বার্তা', 'মেসেজ', 'মেসেজগুলো', 'ইনবক্স', 'inbox', 'হোয়াটসঅ্যাপের মেসেজ', 'অন্য অ্যাপের মেসেজ'],
      'WhatsApp, Telegram, imo, Messenger, Gmail, SMS-এর নতুন মেসেজ পড়ে মিটিং, টাকা চাওয়া, বিল, উত্তর দেওয়ার কাজ আলাদা করে; এক চাপে রিমাইন্ডার, এখান থেকেই উত্তর।',
      ['হোয়াটসঅ্যাপে কী এসেছে?', 'রহিম কী লিখেছে?', 'জরুরি কোনো মেসেজ আছে?']),
  AppPlace('money', 'আয়-ব্যয়', ['আয় ব্যয়', 'আয়-ব্যয়', 'আয়ব্যয়', 'খরচের হিসাব', 'হিসাব', 'money', 'income', 'expense'],
      'নিজের আয় আর খরচ খাত ধরে; মাসের ব্যালেন্স।', ['বাজারে ৫০০ টাকা খরচ হলো', 'বেতন পেলাম ৩০ হাজার', 'এই মাসে কত খরচ হলো?']),
  AppPlace('ledger', 'লেনদেন (ধার-দেনা)', ['লেনদেন', 'ধার দেনা', 'ধার-দেনা', 'ধারদেনা', 'বাকির খাতা', 'বাকি খাতা', 'খাতা', 'পাওনা দেনা', 'ledger'],
      'কে কত পাবে, কাকে কত দিতে হবে; ফেরতের তারিখে মনে করায়; এক চাপে তাগাদার মেসেজ।', ['করিম ৫০০ টাকার মাল বাকিতে নিল', 'আমি কার কাছে কত পাব?']),
  AppPlace('projects', 'প্রজেক্ট', ['প্রজেক্ট', 'প্রকল্প', 'project', 'projects'], 'প্রতিটা কাজের (বাড়ি, বিয়ে, ঈদ) আলাদা আয়-খরচ আর বাজেট।',
      ['রহিম ভবন প্রজেক্টে রড কিনলাম ২০ হাজার']),
  AppPlace('report', 'মাসের রিপোর্ট', ['মাসের রিপোর্ট', 'রিপোর্ট', 'report'], 'মাসের আয়, খরচ, ব্যালেন্স; কোন খাতে বেশি গেল, গত মাসের সাথে তুলনা।'),
  AppPlace('accounts', 'অ্যাকাউন্ট', ['অ্যাকাউন্ট', 'একাউন্ট', 'account', 'accounts'], 'হাতের টাকা, বিকাশ, নগদ, ব্যাংক — কোথায় কত আছে, এক জায়গা থেকে আরেক জায়গায় পাঠানো।'),
  AppPlace('savings', 'সঞ্চয় ও কিস্তি', ['সঞ্চয়', 'সেভিংস', 'কিস্তি', 'ডিপিএস', 'dps', 'savings'], 'সঞ্চয়ের লক্ষ্য, কিস্তি আর DPS-এর হিসাব, দেওয়ার দিনে মনে করানো।'),
  AppPlace('zakat', 'যাকাত', ['যাকাত', 'জাকাত', 'zakat'], 'সম্পদ লিখলে যাকাতের হিসাব করে দেয়।'),
  AppPlace('split', 'খরচ ভাগাভাগি', ['খরচ ভাগাভাগি', 'ভাগাভাগি', 'খরচ ভাগ', 'split'], 'কয়েকজনের খরচ ভাগ করে কে কাকে কত দেবে।'),
  AppPlace('shop', 'দোকান', ['দোকানের হিসাব', 'দোকান', 'shop'], 'দোকানের বিক্রি, বাকি আর রসিদ।'),
  AppPlace('health', 'স্বাস্থ্য', ['স্বাস্থ্য', 'হেলথ', 'health', 'বিএমআই', 'bmi', 'প্রেশার', 'সুগার', 'ডায়াবেটিস', 'ওজন', 'টিকা', 'টিকার কার্ড', 'ভ্যাকসিন', 'vaccine'],
      'BMI, প্রেশার, সুগার, ওজন — গ্রাফসহ; পরিবারের প্রত্যেকের আলাদা; শিশুর টিকার কার্ড; ডাক্তারকে দেখানোর সারাংশ।', ['প্রেশার ১২০ বাই ৮০', 'আজ ওজন ৬৫ কেজি', 'আমার বিএমআই কত?']),
  AppPlace('medicines', 'ওষুধ', ['ওষুধ', 'ঔষধ', 'অষুধ', 'মেডিসিন', 'medicine', 'medicines'], 'কোন ওষুধ কখন খাবেন, সময়মতো মনে করানো; ফুরিয়ে এলে জানানো।', ['প্রতিদিন রাত ১০টায় ওষুধ']),
  AppPlace('habits', 'অভ্যাস', ['অভ্যাস', 'habit', 'habits'], 'নামাজ, হাঁটা, পানি খাওয়া — প্রতিদিন টিক, টানা কত দিন হলো।'),
  AppPlace('diary', 'ডায়েরি', ['ডায়েরি', 'ডায়রি', 'ডাইরি', 'দিনলিপি', 'diary'], 'দিনের কথা লিখে রাখা; তারিখ ধরে খোঁজা।'),
  AppPlace('emergency', 'জরুরি', ['জরুরি কার্ড', 'জরুরি', 'ইমার্জেন্সি', 'emergency', 'হেল্পলাইন', 'রক্তদান', 'ব্লাড', 'blood'],
      'রক্তের গ্রুপ, জরুরি নম্বর (৯৯৯, ফায়ার সার্ভিস ১০২…), রক্তদাতার প্রোফাইল।'),
  AppPlace('expiry', 'কাগজের মেয়াদ', ['কাগজের মেয়াদ', 'মেয়াদ', 'expiry'], 'পাসপোর্ট, লাইসেন্স, ট্যাক্স টোকেনের মেয়াদ শেষের আগে মনে করায়।'),
  AppPlace('tags', 'ট্যাগ', ['ট্যাগ', 'tag', 'tags'], 'এক ট্যাগে নোট, কাগজ, কাজ সব একসাথে।'),
  AppPlace('memory', 'আমার সম্পর্কে', ['মনে রাখা কথা', 'আমার সম্পর্কে', 'memory'], 'আপনার সম্পর্কে যা বলেছেন (অভ্যাস, পছন্দ, সম্পর্ক) — উত্তরে কাজে লাগে।',
      ['মনে রেখো আমি শুক্রবার অফিস করি না']),
  AppPlace('templates', 'তৈরি তালিকা', ['তৈরি তালিকা', 'টেমপ্লেট', 'template', 'templates'], 'হজ, বিয়ে, নতুন বাসা, দেশে ফেরা — তৈরি কাজের তালিকা এক চাপে।'),
  AppPlace('store', 'সব কিছু', ['সব কিছু', 'সবকিছু', 'স্টোর', 'store'], 'অ্যাপের সব অংশ এক পাতায়।'),
  AppPlace('search', 'খুঁজুন', ['খোঁজার পাতা', 'সার্চ', 'search'], 'নোট, কাগজ, নম্বর, লেনদেন — সব জায়গায় একসাথে খোঁজা।'),
  AppPlace('settings', 'সেটিংস', ['সেটিংস', 'সেটিং', 'সেটিংসে', 'settings', 'setting'], 'প্রোফাইল ছবি, ভাষা (বাংলা/English), থিম, সহজ মোড, তালা, ব্যাকআপ।'),
  AppPlace('notifications', 'নোটিফিকেশন', ['নোটিফিকেশন', 'notification', 'notifications', 'বিজ্ঞপ্তি'], 'কোন বার্তা আসবে, রাতে চুপ থাকা, দিনে কয়টা।'),
  AppPlace('sound', 'রিংটোন', ['রিংটোন', 'ringtone', 'সাউন্ড'], 'রিমাইন্ডার আর অ্যালার্মের শব্দ।'),
  AppPlace('backup', 'ব্যাকআপ', ['ব্যাকআপ', 'backup'], 'সব তথ্য একটা তালাবদ্ধ ফাইলে; ফোন বদলালে ফিরিয়ে আনা যায়।'),
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
  final hasShow = _showVerbs.any((v) => _cut(text, v) != null) && _containers.any((c) => _cut(text, c) != null);
  if (!hasOpen && !hasShow) return null;
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
    if (left.isEmpty) return (id, folder);
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

/// "তুমি কী কী পারো?" — spoken: short; shown: one line per part.
String capabilitiesSpoken() => tr(
    'অনেক কিছু পারি — কাজের তালিকা, সময়মতো মনে করানো, ফোন-মেসেজ, ধার-দেনা আর আয়-ব্যয়ের হিসাব, নোট, কাগজপত্র, পাসওয়ার্ড, স্বাস্থ্য আর বিশেষ দিন। যেকোনো পাতাও খুলে দিতে পারি — যেমন বলুন “নোট খোলো”। পুরো তালিকা নিচে দিলাম।');

String capabilitiesList() => [
      for (final p in appPlaces)
        if (p.id != 'home' && p.id != 'store' && p.id != 'search' && p.id != 'help') '• ${tr(p.title)} — ${tr(p.what)}',
    ].join('\n');

/// The app's parts for the AI ("id: name — what").
String appMapForAi() => [for (final p in appPlaces) '${p.id}: ${p.title} — ${p.what}'].join('\n');
