/// My Assistant Pro: what the free app gives, what Pro adds, and which build
/// sells it.
///
/// The APK people download from GitHub has everything (nothing is locked).
/// The Play Store app is free with ads; Pro (bought through Google Play
/// Billing) adds the features below and removes the ads. The preview build
/// (`--dart-define=EDITION=play_preview`) shows the Play app as a new user
/// gets it, with a test switch in place of real payment.
///
/// Rule: Pro never locks the user's own data. Items already kept stay
/// readable, editable and deletable; only adding more past a free limit, or
/// using a Pro-only tool, asks for Pro.
library;

/// `direct` (GitHub APK), `play` (Play Store) or `play_preview`.
const String edition = String.fromEnvironment('EDITION', defaultValue: 'direct');

/// The Play Store app (or its preview): free with ads, Pro sold in the app.
bool get playEdition => edition == 'play' || edition == 'play_preview';

/// The preview: no real payment; a test switch turns Pro on and off.
bool get previewEdition => edition == 'play_preview';

/// The website's Pro page (the shortcode [my_assistant_pro]), behind
/// "Get Premium". Google Play's payment rules do not allow a Play Store app to
/// send people to pay another way, so the Play Store build can turn the link
/// off with `--dart-define=PRO_LINK=off`.
const proWebPage = 'https://getmyassistant.app/';
const showProLink = String.fromEnvironment('PRO_LINK', defaultValue: 'on') != 'off';

/// Free limits in the Play app.
const freeShops = 1;
/// অন্যান্য হিসাব is premium only (owner, 24 Oct).
const freeProjects = 0;
const freeVaultItems = 20;
const freeReminders = 20;
const freeLedgerPeople = 20;
const freeDocs = 20;

/// Reports: this month and the two before it.
const freeReportMonths = 3;

/// No free trial: the free app is useful on its own, and Premium is bought
/// when its tools are wanted.
enum ProFeature { ai, noAds, autoBackup, docAlerts, dueReminders, history, reminders, people, docs, shops, receipts, pdf, projects, vault, smartNudges, family, will, familyHealth }

/// Open to everyone (owner, 24 Oct: only the list in [proInfo] is premium).
const freeFeatures = {
  ProFeature.docAlerts,
  ProFeature.dueReminders,
  ProFeature.history,
  ProFeature.people,
  ProFeature.shops,
  ProFeature.receipts,
  ProFeature.smartNudges,
};

class ProInfo {
  const ProInfo(this.title, this.what, {this.free = '', this.later = false});
  final String title;

  /// What Premium gives.
  final String what;

  /// What the free app gives instead ('' = nothing).
  final String free;

  /// Not built yet (needs a server).
  final bool later;
}

/// What Premium adds — the owner's list of 24 Oct, in his order. Keep this
/// up to date with every change: the Premium page and every lock read it.
const proInfo = <ProFeature, ProInfo>{
  ProFeature.reminders: ProInfo('যত খুশি রিমাইন্ডার', 'চালু রিমাইন্ডারের কোনো সীমা নেই — কাজ, বিল, ধার-দেনা, কাগজের মেয়াদ সব মিলিয়ে', free: 'সব মিলিয়ে একসাথে ২০টা চালু রিমাইন্ডার'),
  ProFeature.docs: ProInfo('যত খুশি ডকুমেন্ট', 'NID, পাসপোর্ট, দলিল, ছবি — কোনো সীমা নেই', free: '২০টা ডকুমেন্ট'),
  ProFeature.projects: ProInfo('অন্যান্য হিসাব', 'বাড়ি, বিয়ে, ঈদ, ব্যবসা — আলাদা হিসাব, বকেয়া আর বাজেট; মূল টাকায় নিজে যুক্ত হয়'),
  ProFeature.will: ProInfo('ওছিয়তনামা', 'নোটে নিজের ওছিয়ত লিখে রাখা, শেষ কবে বদলেছেন তারিখসহ'),
  ProFeature.familyHealth: ProInfo('পরিবারের স্বাস্থ্য', 'স্বাস্থ্যে পরিবারের সদস্য যুক্ত করে প্রত্যেকের BMI, প্রেশার, সুগার, টিকা আলাদা রাখা', free: 'নিজের স্বাস্থ্য'),
  ProFeature.vault: ProInfo('যত খুশি পাসওয়ার্ড', 'পাসওয়ার্ডের কোনো সীমা নেই', free: '২০টা পাসওয়ার্ড'),
  ProFeature.family: ProInfo('ফ্যামিলি: উত্তরাধিকার, পুরো অ্যাক্সেস, লোকেশন', 'উত্তরাধিকারী রাখা, এখনই পুরো অ্যাক্সেস দেওয়া, লাইভ লোকেশন দেখানো; উত্তরাধিকারী এক চাপে সব ব্যাকআপ নিতে পারেন',
      free: 'সদস্য যুক্ত করা, কাজ, রিমাইন্ডার, ওষুধের রিমাইন্ডার আর নোট পাঠানো'),
  ProFeature.autoBackup: ProInfo('Google Drive-এ অটো ব্যাকআপ', 'কিছু বদলালেই নিজে থেকে ব্যাকআপ — কিছু মনে রাখতে হবে না', free: 'নিজে চাপলে Drive-এ ব্যাকআপ; নতুন ফোনে ফিরিয়ে আনা সবসময় ফ্রি'),
  ProFeature.pdf: ProInfo('PDF ডাউনলোড', 'সবকিছু বা যেকোনো পাতা PDF-এ — ডাউনলোড, শেয়ার, প্রিন্ট'),
  ProFeature.ai: ProInfo('AI উত্তর', 'লম্বা, এলোমেলো কথাও বোঝে; যেকোনো প্রশ্নের উত্তর — দিনে ৫০টা পর্যন্ত', free: 'অ্যাপ নিজের নিয়মে বোঝে আর উত্তর দেয়'),
  ProFeature.noAds: ProInfo('কোনো বিজ্ঞাপন নেই', 'কাজের মাঝে কিছু বাধা দেবে না', free: 'নিচে ছোট বিজ্ঞাপন, দিনে সর্বোচ্চ ২টা পুরো পর্দার'),
};

/// Everything else, open in the free app too (the Premium page lists it).
const freeList = 'মুখে বলে সব কাজ, আয়-ব্যয়, এখন আছে, ধার-দেনা (যত জন খুশি) ও তার রিমাইন্ডার, তাগাদার মেসেজ, কাজের তালিকা, অ্যালার্ম, ক্যালেন্ডার ও নামাজের সময়, নোট, কাগজের মেয়াদের খবর, সব মাসের রিপোর্ট, নিজের স্বাস্থ্য, শিশুর টিকা, ওষুধের রিমাইন্ডার, অভ্যাস, বিশেষ দিন, যাকাতের হিসাব, সঞ্চয়, দোকান ও রসিদ, স্মার্ট খেয়াল, ফ্যামিলিতে কাজ-রিমাইন্ডার-নোট পাঠানো, নিজে চাপলে Google Drive-এ ব্যাকআপ আর নতুন ফোনে সব ফিরিয়ে আনা। আপনার রাখা কোনো তথ্য কখনো তালাবদ্ধ হবে না।';

class ProPlan {
  const ProPlan(this.id, this.title, this.price, this.note, this.days);
  final String id;
  final String title;
  final String price;
  final String note;
  final int days;
}

/// Two plans only: monthly and yearly.
const proPlans = [
  ProPlan('pro_yearly', 'বছরে', '৳৯৯৯', 'মাসে মাত্র ৳৮৩ — ২ মাস ফ্রি', 365),
  ProPlan('pro_monthly', 'মাসে', '৳৯৯', 'যেকোনো সময় বন্ধ করা যায়', 30),
];

/// Where the free Play app shows Google ads (AdMob). Never on the password,
/// vault, PIN or lock pages, never while the mic is listening or the app is
/// speaking, never on alarm or reminder screens.
const adPlaces = [
  ('ছোট ব্যানার', 'হোম, কাজের তালিকা, নোট, আয়-ব্যয় আর রিপোর্ট পাতার একদম নিচে'),
  ('পুরো পর্দার বিজ্ঞাপন', 'দিনে সর্বোচ্চ ২টা, শুধু একটা কাজ শেষ হওয়ার পর (লেনদেন বা রিমাইন্ডার সেভ করার পরে) — প্রথম দিন একটাও না'),
  ('কখনো না', 'পাসওয়ার্ড, ভল্ট, PIN, লক, অ্যালার্ম বাজার পাতায়, আর মাইক চালু বা কথা বলার সময়'),
];

/// At most this many full-screen ads a day, at least this many finished
/// tasks apart.
const fullAdsPerDay = 2;
const tasksBetweenFullAds = 3;

/// Whether a full-screen ad may show after a finished task: [shown] today
/// already, [done] tasks finished since the last one, [firstDay] the user's
/// first day.
bool fullAdDue({required int shown, required int done, required bool firstDay}) =>
    !firstDay && shown < fullAdsPerDay && done >= tasksBetweenFullAds;
