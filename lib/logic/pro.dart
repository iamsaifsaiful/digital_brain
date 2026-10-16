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

/// Free limits in the Play app.
const freeShops = 1;
const freeProjects = 1;
const freeVaultItems = 10;

/// Days of the free trial (once per user).
const trialDays = 7;

enum ProFeature { ai, noAds, shops, receipts, pdf, zakat, projects, vault, inbox, smartNudges, cloudBackup }

class ProInfo {
  const ProInfo(this.title, this.what, {this.free = '', this.later = false});
  final String title;

  /// What Pro gives.
  final String what;

  /// What the free app gives instead ('' = nothing).
  final String free;

  /// Not built yet (needs a server).
  final bool later;
}

const proInfo = <ProFeature, ProInfo>{
  ProFeature.ai: ProInfo('AI সহকারী', 'লম্বা, এলোমেলো কথাও বোঝে; যেকোনো প্রশ্নের উত্তর — দিনে ৫০টা পর্যন্ত', free: 'অ্যাপ নিজের নিয়মে বোঝে'),
  ProFeature.noAds: ProInfo('কোনো বিজ্ঞাপন নেই', 'কাজের মাঝে কিছু বাধা দেবে না', free: 'নিচে ছোট বিজ্ঞাপন, দিনে সর্বোচ্চ ২টা পুরো পর্দার'),
  ProFeature.shops: ProInfo('একাধিক দোকান', 'যত খুশি দোকান, প্রতিটার আলাদা হিসাব, উপরে সব মিলিয়ে', free: '১টা দোকান'),
  ProFeature.receipts: ProInfo('রসিদ', 'কাস্টমারকে নম্বরসহ রসিদ — শেয়ার বা প্রিন্ট'),
  ProFeature.pdf: ProInfo('PDF রিপোর্ট', 'সবকিছু বা যেকোনো পাতা PDF-এ — ডাউনলোড, শেয়ার, প্রিন্ট'),
  ProFeature.zakat: ProInfo('যাকাতের নিজে-হিসাব', 'হিসাব, ব্যাংক, সঞ্চয়, পাওনা-দেনা থেকে যাকাত বের করে; মুখে জিজ্ঞেস করলেই বলে'),
  ProFeature.projects: ProInfo('আলাদা হিসাব (প্রকল্প)', 'বাড়ি, বিয়ে, ঈদ — যত খুশি আলাদা হিসাব আর বাজেট', free: '১টা আলাদা হিসাব'),
  ProFeature.vault: ProInfo('পাসওয়ার্ড ভল্ট', 'যত খুশি পাসওয়ার্ড', free: '১০টা পাসওয়ার্ড'),
  ProFeature.inbox: ProInfo('মেসেজ থেকে কাজ', 'WhatsApp, SMS, বিকাশের মেসেজ থেকে নিজে হিসাব আর কাজ বানায়'),
  ProFeature.smartNudges: ProInfo('স্মার্ট খেয়াল', 'খরচ বেশি হলে, বেতন এলে, বিশেষ দিনের আগে — নিজে থেকে জানায়'),
  ProFeature.cloudBackup: ProInfo('ক্লাউড ব্যাকআপ', 'ফোন হারালেও তথ্য ফেরত — তালাবদ্ধ অবস্থায়', later: true),
};

class ProPlan {
  const ProPlan(this.id, this.title, this.price, this.note, this.days);
  final String id;
  final String title;
  final String price;
  final String note;
  final int days;
}

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
