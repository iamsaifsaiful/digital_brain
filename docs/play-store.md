# My Assistant — Google Play-তে দেওয়ার গাইড (২৯ অক্টোবর ২০২৬)

এই ফাইলে প্লে কনসোলে যা যা লিখতে বা বেছে নিতে হবে, তার সব লেখা তৈরি করা আছে — কপি করে বসালেই হবে।
কোড আর সার্ভারের যা কাজ, সব হয়ে গেছে (প্লাগইন ১.০.০, অ্যাপ ১.০.০, প্যাকেজ app.getmyassistant)। নিচের "আপনার কাজ" অংশগুলো শুধু আপনিই করতে পারবেন, কারণ সেগুলোতে আপনার অ্যাকাউন্ট, টাকা বা পরিচয় লাগে।

---

## ০. কোন ক্রমে করবেন

1. প্লে কনসোল অ্যাকাউন্ট (অর্গানাইজেশন — D-U-N-S নম্বর লাগে; নিচে ৯ নং)।
2. ওয়েবসাইটে দুটো পাতা বানান (১ নং)।
3. AdMob অ্যাকাউন্ট আর অ্যাপ (৫ নং) → GitHub-এ তিনটা variable বসান।
4. প্লে কনসোলে অ্যাপ বানান → সাবস্ক্রিপশন দুটো (৩ নং) → সার্ভিস অ্যাকাউন্ট (৪ নং)।
5. GitHub-এ **Play release** ওয়ার্কফ্লো চালান → `.aab` নিন (২ নং)।
6. Internal testing-এ `.aab` আপলোড → নিজে কিনে দেখুন (টেস্ট কার্ডে)।
7. ঘোষণা, Data safety, স্টোর লিস্টিং (৬–৮ নং) → Closed testing (ব্যক্তিগত অ্যাকাউন্টে ১২ জন × ১৪ দিন লাগে; অর্গানাইজেশনে লাগে না) → Production।

---

## ১. ওয়েবসাইটের পাতা (আপনার কাজ, ৫ মিনিট)

WordPress-এ দুটো নতুন Page বানান — ঠিক এই ঠিকানায়, কারণ অ্যাপ এই ঠিকানাই খোলে:

| পাতা | ঠিকানা (slug) | পাতার ভেতরে শুধু এটা লিখুন |
|---|---|---|
| প্রাইভেসি পলিসি | `getmyassistant.app/privacy/` | `[my_assistant_privacy]` |
| অ্যাকাউন্ট মুছুন | `getmyassistant.app/delete-account/` | `[my_assistant_delete_account]` |

- প্রাইভেসি পলিসি বাংলা আর ইংরেজি দুটোতেই লেখা থাকে; যোগাযোগের ইমেইল হিসেবে WordPress-এর অ্যাডমিন ইমেইল দেখায় (Settings › General-এ যেটা আছে)।
- অ্যাকাউন্ট মোছার পাতায় কেউ ইমেইল দিলে সেই ইমেইলে একটা লিংক যায় (২৪ ঘণ্টা কাজ করে)। লিংকে চাপলে সার্ভারের সব তথ্য মুছে যায়, শুধু পেমেন্টের রেকর্ড থাকে।
- **ইমেইল যাচ্ছে কিনা একবার নিজে পরীক্ষা করুন।** হোস্টিং থেকে ইমেইল না গেলে একটা SMTP প্লাগইন (যেমন WP Mail SMTP) লাগবে।
- `getmyassistant.app/app-ads.txt` নিজে থেকেই তৈরি হয় — শুধু AdMob-এর publisher ID বসাতে হবে (৫ নং)।

প্লে কনসোলে এই দুটো ঠিকানা লাগবে: **Privacy policy URL** আর **Delete account URL** (Data safety-তে)।

---

## ২. AAB বানানো আর সাইন করা

- GitHub › Actions › **Play release** › Run workflow (`next-update` ব্রাঞ্চ)।
- এতে থাকে: প্যাকেজ নাম `app.getmyassistant` (২৯ অক্টোবর থেকে নতুন অ্যাপ, ভার্সন ১.০.০ থেকে), নাম "My Assistant", Google Play Billing, AdMob, ওয়েবসাইটে কেনার লিংক নেই (শুধু সাধারণ ওয়েবসাইটের লিংক), কোড obfuscate করা।
- রিলিজে পাবেন: `play.aab` (প্লে কনসোলে আপলোডের জন্য), দুটো APK (নিজের ফোনে পরীক্ষার জন্য), `play-symbols.zip` (ক্র্যাশ বুঝতে লাগে — ফেলে দেবেন না, প্লে কনসোলে App bundle explorer › Downloads-এ "native debug symbols" নয়, এটা Flutter-এর; নিজের কাছে রাখুন)।

### Play App Signing (একবারই)
প্লে কনসোল প্রথম আপলোডে জিজ্ঞেস করবে অ্যাপের সাইনিং কী কে রাখবে। **আমাদের এখনকার কী-টাই রাখতে হবে**, কারণ যাঁরা ওয়েবসাইট থেকে APK নামিয়েছেন তাঁদের ফোনে প্লে স্টোরের আপডেট তখনই বসবে যখন কী একই থাকে।

1. Setup › App signing › "Use a different key" / "Export and upload a key from Java keystore" বেছে নিন।
2. ওরা `pepk.jar` আর একটা কমান্ড দেবে, যেমন:
   ```
   java -jar pepk.jar --keystore=my-assistant-release.jks --alias=myassistant --output=output.zip --include-cert --rsa-aes-encryption --encryption-key-path=encryption_public_key.pem
   ```
3. কমান্ড চালালে পাসওয়ার্ড চাইবে — আপনার keystore-এর পাসওয়ার্ড দিন (আমাকে কখনো পাঠাবেন না)। `output.zip` প্লে কনসোলে আপলোড করুন।
4. এরপর `.aab` একই কী দিয়ে সাইন করে আপলোড করবেন (upload key = app signing key)। আমি AAB সাইন করে দিলে SHA-256 থাকবে `fc6cff35…d0014f`।

keystore ফাইল আর পাসওয়ার্ড অন্তত দুই জায়গায় অফলাইনে রাখুন (যেমন পেনড্রাইভ আর কাগজে)। হারালে প্লে কনসোলে "upload key reset" করা যায়, কিন্তু ওয়েবসাইটের APK-র আপডেট আর বসবে না।

---

## ৩. সাবস্ক্রিপশন (প্লে কনসোল › Monetize › Subscriptions)

অ্যাপ এই দুটো Product ID খোঁজে — হুবহু এই নাম দিতে হবে:

| Product ID | নাম | Base plan | দাম (বাংলাদেশ) |
|---|---|---|---|
| `pro_monthly` | My Assistant Premium — মাসিক | auto-renewing, 1 month | ৳৯৯ |
| `pro_yearly` | My Assistant Premium — বার্ষিক | auto-renewing, 1 year | ৳৯৯৯ |

- অন্য দেশের দাম প্লে কনসোল নিজে বসিয়ে দেয়; অ্যাপ প্লে-র দেখানো দামই দেখায়।
- Free trial offer দেবেন না — অ্যাপের নিজের ৭ দিনের ট্রায়াল আছে।
- Grace period চালু রাখুন (৭ দিন) — কার্ডে সমস্যা হলে প্রিমিয়াম সাথে সাথে বন্ধ হয় না; সার্ভার এটা বোঝে।
- **Payments profile** (ব্যাংক অ্যাকাউন্ট, ট্যাক্স) প্লে কনসোলে না দিলে সাবস্ক্রিপশন বানানো যায় না।

---

## ৪. সার্ভিস অ্যাকাউন্ট (সার্ভার যেন Google-কে জিজ্ঞেস করে কেনা আসল কিনা)

1. console.cloud.google.com › যে প্রজেক্টে Firebase আছে সেটাই বা নতুন একটা › **Google Play Android Developer API** চালু করুন।
2. IAM › Service accounts › Create → নাম `my-assistant-play` → কোনো role লাগবে না → Keys › Add key › JSON → ফাইলটা নামবে।
3. প্লে কনসোল › Users and permissions › Invite new users → ওই সার্ভিস অ্যাকাউন্টের ইমেইল → App permissions-এ My Assistant → **View financial data** আর **Manage orders and subscriptions** টিক দিন।
4. WordPress › My Assistant › নিচে **Google Play** কার্ডে JSON ফাইলের পুরো লেখা পেস্ট করে সেভ করুন। কার্ডে "সংযুক্ত" দেখাবে।
5. পারমিশন কাজ শুরু করতে Google কখনো কখনো ২৪ ঘণ্টা পর্যন্ত নেয়।

সার্ভার যা করে: অ্যাপ থেকে কেনার টোকেন এলে Google-কে জিজ্ঞেস করে, সত্যি হলে প্রিমিয়ামের মেয়াদ সাবস্ক্রিপশনের শেষ তারিখ পর্যন্ত দেয়, Google-কে "acknowledge" করে (না করলে Google ৩ দিন পর টাকা ফেরত দেয়), মেয়াদ শেষের কাছাকাছি আবার দেখে নেয় নবায়ন হলো কিনা। এক অ্যাকাউন্টের কেনা আরেক অ্যাকাউন্টে যায় না। সার্ভার উত্তর দিতে না পারলে অ্যাপ ৩ দিনের জন্য প্রিমিয়াম খোলা রাখে আর প্রতিবার খোলার সময় আবার চেষ্টা করে।

---

## ৫. AdMob

1. admob.google.com › অ্যাকাউন্ট খুলুন (পেমেন্ট আর ট্যাক্সের তথ্যসহ)।
2. Apps › Add app › Android › "Is the app listed on a supported app store?" — প্রথমে **No** (প্লে স্টোরে আসার পরে লিংক করবেন)। নাম My Assistant।
3. দুটো Ad unit বানান: **Banner** আর **Interstitial**।
4. Privacy & messaging › **GDPR message** বানিয়ে Publish করুন (ইউরোপ/যুক্তরাজ্যের ব্যবহারকারীদের সম্মতি চাওয়ার ফর্ম; অ্যাপ এটা নিজে দেখায়)। US states message-ও বানাতে পারেন।
5. GitHub › Settings › Secrets and variables › Actions › **Variables** ট্যাবে তিনটা বসান (এগুলো গোপন নয়, তাই secret নয়):
   - `ADMOB_APP_ID` = `ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy`
   - `ADMOB_BANNER` = `ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz`
   - `ADMOB_FULL` = ইন্টারস্টিশিয়ালের ID
6. WordPress › My Assistant › **AdMob** কার্ডে publisher ID (`pub-xxxxxxxxxxxxxxxx`) দিন → `app-ads.txt` তৈরি হয়ে যায়।
7. প্লে স্টোরের লিস্টিংয়ে Website হিসেবে `https://getmyassistant.app` দিন (AdMob এখান থেকেই app-ads.txt খোঁজে)।

variable না বসালে Play release বিল্ডে Google-এর টেস্ট বিজ্ঞাপন দেখায় (টাকা আসে না, কিন্তু কিছু ভাঙে না)।
নিজের ফোনে কখনো নিজের আসল বিজ্ঞাপনে ক্লিক করবেন না — AdMob অ্যাকাউন্ট বন্ধ করে দিতে পারে।

অ্যাপে বিজ্ঞাপন যেখানে: ছোট ব্যানার (হোম, কাজের তালিকা, নোট, আয়-ব্যয়, রিপোর্টের নিচে); পুরো পর্দার বিজ্ঞাপন দিনে সর্বোচ্চ ২টা, কাজ শেষ হওয়ার পর, প্রথম দিনে একটাও না। পাসওয়ার্ড, ভল্ট, PIN, অ্যালার্ম পাতায় কখনো না। প্রিমিয়াম আর ৭ দিনের ট্রায়ালে বিজ্ঞাপন নেই।

---

## ৬. ঘোষণা (Policy › App content)

### Background location (ACCESS_BACKGROUND_LOCATION)
**৩০ অক্টোবর থেকে Play-র অ্যাপে এই অনুমতি নেই** (`play_release.yml` বিল্ডের আগে manifest থেকে সরায়; Google এটা শুধু লোকেশনই-মূল-কাজ অ্যাপকে দেয়)। Play-তে "এখন কোথায়?" কাজ করে অ্যাপ ব্যবহারের সময়। ওয়েবসাইটের APK-তে আছে। নিচের লেখা আর ভিডিও কেবল পরে আবেদন করলে লাগবে।

**বাংলা:** ফ্যামিলি ফিচারে ব্যবহারকারী নিজে যাঁদের অনুমতি দেন, সেই পরিবারের সদস্য "এখন কোথায়?" জিজ্ঞেস করলে ফোন — অ্যাপ বন্ধ থাকলেও — নিজের লোকেশন জানায় (যেমন ফোন হারালে বা বয়স্ক বাবা-মায়ের খোঁজ নিতে)। লোকেশন end-to-end তালাবদ্ধ হয়ে শুধু অনুমতি পাওয়া সদস্যের কাছে যায়; আমাদের সার্ভার পড়তে পারে না; বিজ্ঞাপনে ব্যবহার হয় না। ফ্যামিলি পাতা থেকে যেকোনো সময় বন্ধ করা যায়।

**English (Play Console-এ এটা দিন):** My Assistant's Family feature lets a user choose family members who may ask "Where is this phone now?". When such a member asks, the phone answers with its location even when the app is closed or not in use (for example to find a lost phone or check on an elderly parent). The location is end-to-end encrypted and only the members the user approved can read it; our server cannot read it and it is never used for ads. The user turns it on and off on the Family page. Before Android's permission dialog the app shows a full-screen explanation of this use.

**ভিডিও (৩০ সেকেন্ডের মধ্যে, YouTube-এ unlisted করে লিংক দিন):**
1. অ্যাপ খুলে ফ্যামিলি পাতা → একজন সদস্যকে লোকেশনের অনুমতি দেওয়া দেখান।
2. "লোকেশনের অনুমতি দিন" চাপুন → অ্যাপের ব্যাখ্যার পাতা ("লোকেশন কীভাবে ব্যবহার হয়") পুরোটা দেখান → "বুঝেছি, চালিয়ে যান"।
3. Android-এর ডায়ালগ → "While using the app"।
4. "“সবসময় অনুমতি দিন” বেছে নিন" চাপুন → আবার ব্যাখ্যা → সেটিংসে "Allow all the time"।
5. অ্যাপ বন্ধ করুন। দ্বিতীয় ফোন থেকে "এখন কোথায়?" জিজ্ঞেস করুন → প্রথম ফোনের লোকেশন আসছে দেখান।

### Exact alarm (USE_EXACT_ALARM / SCHEDULE_EXACT_ALARM)
**English:** My Assistant is a reminder and alarm app: the user sets reminders, medicine times and prayer-time alarms that must ring at the exact minute, like an alarm clock. Exact alarms are the app's core function.

(নোট: Google `USE_EXACT_ALARM` শুধু অ্যালার্ম/ক্যালেন্ডার অ্যাপকে দেয়। প্রত্যাখ্যান করলে আমাকে বলবেন — `USE_EXACT_ALARM` সরিয়ে শুধু `SCHEDULE_EXACT_ALARM` রেখে দেব; তখন ব্যবহারকারীকে একবার "Alarms & reminders" অনুমতি দিতে হবে, অ্যাপ সেটা নিজে চায়।)

### Full-screen intent (USE_FULL_SCREEN_INTENT)
**English:** Reminders and medicine alarms ring with a full-screen alarm page (like the phone's clock app) so they are seen even when the phone is locked. Used only for alarms the user set.

### Battery optimization (REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
**English:** Some phones (Xiaomi, Oppo, Vivo, Samsung) stop the app's alarms in the background. The app asks once, with an explanation, to be left out of battery optimization so medicine and reminder alarms ring on time. The user can refuse; the app still works.

### Health Connect
আলাদা ফাইলে আছে: `docs/health_connect_play_console.md`।

### Contacts (READ_CONTACTS)
ঘোষণা লাগে না। তবে প্রশ্ন এলে: ধার-দেনায় নাম লিখতে ফোনের কন্টাক্ট থেকে বেছে নেওয়া আর কল/মেসেজ করা; কন্টাক্ট ফোনেই থাকে, কোথাও যায় না।

### অন্যান্য প্রশ্ন
- **Ads:** Yes, contains ads।
- **App access:** "All functionality is available without special access" — তবে প্রিমিয়াম পরীক্ষার জন্য: "Premium features can be tested with a license tester account on Google Play (subscriptions pro_monthly / pro_yearly)." প্লে কনসোল › Settings › License testing-এ রিভিউ টিমের জন্য কিছু দিতে হয় না।
- **Content rating:** Utility/Productivity; কোনো সহিংসতা, জুয়া নেই; ব্যবহারকারীরা একে অপরের সাথে যোগাযোগ করতে পারে — **হ্যাঁ** (ফ্যামিলি আর রক্তের অনুরোধ)। শেয়ার করে লোকেশন — **হ্যাঁ**।
- **Target audience:** ১৮+ (শিশুদের জন্য নয়)।
- **News app:** না। **Government app:** না। **Financial features:** হিসাব রাখার অ্যাপ — "My app doesn't provide any financial features" বেছে নিন (লেনদেন করে না, শুধু খাতা)।
- **Health apps declaration (৩০ অক্টোবর থেকে):** শুধু Health & Fitness ভাগের **Activity and fitness** আর **Sleep management** (Health Connect থেকে হাঁটা, ব্যায়াম আর ঘুম পড়ে)। Medical ভাগের কিছু নয়, "Other"-ও নয়। Medical বাছলে অর্গানাইজেশন অ্যাকাউন্ট লাগে।

---

## ৭. Data safety (প্লে কনসোল › App content › Data safety)

শুরুর প্রশ্ন:
- Does your app collect or share any of the required user data types? **Yes**
- Is all of the user data collected by your app encrypted in transit? **Yes**
- Do you provide a way for users to request that their data is deleted? **Yes** (in-app আর `getmyassistant.app/delete-account/`)

| Data type | Collected | Shared | ঐচ্ছিক? | কেন (Purpose) |
|---|---|---|---|---|
| Personal info › Name | হ্যাঁ | না | ঐচ্ছিক (Google লগইন) | Account management |
| Personal info › Email address | হ্যাঁ | না | ঐচ্ছিক | Account management, Developer communications |
| Personal info › Phone number | হ্যাঁ | না | ঐচ্ছিক (রক্তদাতা হলে) | App functionality |
| Health and fitness › Health info (রক্তের গ্রুপ, শেষ রক্তদান) | হ্যাঁ | না | ঐচ্ছিক | App functionality |
| Location › Approximate location | হ্যাঁ | না | ঐচ্ছিক | App functionality (আবহাওয়া, নামাজের সময়, রক্তদাতা খোঁজা) |
| Location › Precise location | হ্যাঁ | না | ঐচ্ছিক | App functionality (ফ্যামিলির "এখন কোথায়", end-to-end তালাবদ্ধ) |
| Financial info › Purchase history | হ্যাঁ | না | — | App functionality (প্রিমিয়াম) |
| App activity › Other user-generated content (AI-কে প্রশ্ন, মতামত, সম্মতি দিলে কথার নমুনা) | হ্যাঁ | না | ঐচ্ছিক | App functionality, Analytics |
| App info and performance › Crash logs, Diagnostics | হ্যাঁ | না | — | Analytics |
| Device or other IDs (push token, Advertising ID) | হ্যাঁ | হ্যাঁ (Google AdMob — শুধু ফ্রি Play অ্যাপে) | — | Advertising or marketing, App functionality |

সব collected তথ্য: **Processed ephemerally — না** (সার্ভারে থাকে), **Required — না** (Device IDs ছাড়া)।

যা **কখনো ফোনের বাইরে যায় না** (তাই ঘোষণায় নেই): পাসওয়ার্ড, ভল্ট, PIN, OTP, স্বাস্থ্যের মাপ, ওষুধ (পরিবারের সাথে end-to-end তালাবদ্ধ ছাড়া), Health Connect-এর তথ্য, কন্টাক্ট, হিসাব-খাতা, নোট, ডকুমেন্ট, অন্য অ্যাপের মেসেজ। ব্যাকআপ যায় ব্যবহারকারীর নিজের Google Drive-এ, তালাবদ্ধ হয়ে।

(যেকোনো সন্দেহে বেশি ঘোষণা করা নিরাপদ; কম ঘোষণা করলে অ্যাপ সরিয়ে দিতে পারে।)

---

## ৮. স্টোর লিস্টিং

**৩০ অক্টোবর:** Google "Medication and treatment management" (Medical) ঘোষণার কারণে প্রত্যাখ্যান করেছে। ব্যক্তিগত অ্যাকাউন্টে Medical অ্যাপ চলে না। তাই Play-র অ্যাপে ওষুধ, প্রেশার, সুগার, টিকা, চেকআপ, ডাক্তারের সারাংশ আর জরুরি কার্ড নেই (`lib/logic/pro.dart` `medicalOff`)। স্টোরের লেখা আর ছবিতেও এগুলো থাকবে না। অর্গানাইজেশন অ্যাকাউন্ট হলে ফেরানো যাবে।

**App name:** My Assistant - বাংলা সহকারী

**Short description (৮০ অক্ষরের মধ্যে):**
- বাংলা: `রিমাইন্ডার, হিসাব, ডকুমেন্ট আর পাসওয়ার্ড: বাংলায় বলুন, তালাবদ্ধ থাকে ফোনেই`
- English: `Reminders, money, documents and passwords: say it in Bangla, kept locked`

**Full description (বাংলা):**
```
My Assistant: বাংলায় বলুন, কাজ হয়ে যাবে নিজে থেকেই।

"কাল সকাল ৯টায় বিদ্যুৎ বিল দেওয়ার কথা মনে করিয়ে দিও", "রহিমকে ৫০০ টাকা দিলাম", "এই মাসে বাজারে কত খরচ হলো?" বলুন, অ্যাপ বুঝে নিজেই রেখে দেয়।

যা যা করে:
• রিমাইন্ডার আর কাজের তালিকা: অ্যালার্মের মতো বাজে, ফোন লক থাকলেও
• হিসাব: আয়-ব্যয়, ধার-দেনা, দোকান আর অন্যান্য হিসাব; মাসের রিপোর্ট
• ডকুমেন্টস: NID, পাসপোর্ট, দলিল গুছিয়ে রাখা; মেয়াদ শেষের আগে খবর
• পাসওয়ার্ড: শুধু আপনার ফোনে, তালাবদ্ধ ভল্টে
• ফ্যামিলি: পরিবারের সদস্যদের কাজ, রিমাইন্ডার আর নোট পাঠানো; লোকেশন; উত্তরাধিকার
• যাকাত: এখন আছে, ধার-দেনা, সঞ্চয় আর সোনা-রুপা ধরে হিসাব
• অটো ব্যাকআপ: আপনার নিজের Google Drive-এ, তালাবদ্ধ হয়ে
• নামাজের সময়, কিবলা কম্পাস, আবহাওয়া, ছুটির দিন

আপনার তথ্য আপনার: পাসওয়ার্ড, ভল্ট আর PIN কখনো ফোনের বাইরে যায় না। ব্যাকআপ end-to-end তালাবদ্ধ, আমরাও পড়তে পারি না।

ফ্রিতে প্রায় সব কিছু। প্রিমিয়ামে: AI উত্তর, বিজ্ঞাপন নেই, অটো ব্যাকআপ, আরও বেশি রিমাইন্ডার-ডকুমেন্ট-পাসওয়ার্ড, পরিবারের পুরো সুবিধা। শুরুতে ৭ দিন সব ফ্রি।
```

**Full description (English):**
```
My Assistant: say it in Bangla and it's done.

"Remind me to pay the electricity bill at 9 tomorrow", "I gave Rahim 500 taka", "How much did I spend on groceries this month?" Speak, and the app understands and keeps it.

• Reminders and to-dos that ring like an alarm, even on a locked phone
• Money: income and expenses, loans, shop and other accounts, monthly reports
• Documents: ID, passport, deeds in one place, with a reminder before they expire
• Passwords: on your phone only, in a locked vault
• Family: send tasks, reminders and notes to family members; location; inheritance
• Zakat: calculated from your money, loans, savings, gold and silver
• Automatic backup to your own Google Drive, locked
• Prayer times, Qibla compass, weather and holidays

Your data is yours: passwords, the vault and your PIN never leave your phone. Backups are end-to-end locked; we cannot read them.

Almost everything is free. Premium adds AI answers, no ads, automatic backup, more reminders, documents and passwords, and the full family features. The first 7 days are fully free.
```

**স্ক্রিনশট:** হোম, রিমাইন্ডার অ্যালার্ম ("বিদ্যুৎ বিল দেওয়া"), হিসাব, ডকুমেন্টস, পাসওয়ার্ড, ফ্যামিলি (সদস্যের তালিকা), যাকাত, ব্যাকআপ। কোনো ছবিতে ওষুধ নেই (`test/ui/store_shots_test.dart`)।

**Category:** Productivity। **Website:** `https://getmyassistant.app`

---

## ৯. ব্যক্তিগত না অর্গানাইজেশন অ্যাকাউন্ট

| | ব্যক্তিগত | অর্গানাইজেশন |
|---|---|---|
| খরচ | $২৫ একবার | $২৫ একবার |
| কাগজ | NID/পাসপোর্ট | D-U-N-S নম্বর (ফ্রি, ২–৪ সপ্তাহ), ট্রেড লাইসেন্স, অফিসের ঠিকানা-ফোন |
| প্রকাশের আগে | Closed testing-এ ১২ জন × টানা ১৪ দিন বাধ্যতামূলক | লাগে না |
| প্লে স্টোরে দেখায় | আপনার নাম, আর (কেনা থাকলে) ঠিকানা | প্রতিষ্ঠানের নাম |
| স্বাস্থ্য/আর্থিক অ্যাপে বিশ্বাস | কম | বেশি |

পরামর্শ আগের মতোই: অর্গানাইজেশন। D-U-N-S আবেদন আজই করুন (dnb.com-এ "D-U-N-S Number for Apple/Google developers")।

---

## ১০. প্রকাশের আগে নিজে যা পরীক্ষা করবেন

- [ ] Internal testing থেকে অ্যাপ নামিয়ে Google লগইন → প্রিমিয়াম নিন → টেস্ট কার্ডে মাসিক কিনুন → "প্রিমিয়াম চালু হলো" আসছে কিনা।
- [ ] WordPress-এ সেই ইউজারের প্রিমিয়ামের তারিখ বসেছে কিনা (Members তালিকায় `play:pro_monthly`)।
- [ ] প্লে স্টোর › Subscriptions থেকে বাতিল করুন → মেয়াদ শেষে প্রিমিয়াম বন্ধ হয় কিনা (টেস্ট কার্ডে মাসিক মানে ৫ মিনিট)।
- [ ] অ্যাপ মুছে আবার নামিয়ে লগইন → "আগে কেনা প্রিমিয়াম ফিরিয়ে আনুন"।
- [ ] ফ্রি অবস্থায় হোমের নিচে ছোট বিজ্ঞাপন আসছে কিনা; কয়েকটা কাজ সেভের পরে পুরো পর্দার বিজ্ঞাপন (প্রথম দিনে না)।
- [ ] সেটিংস › Google › "অ্যাকাউন্ট মুছুন" → WordPress-এ সেই সদস্য আর নেই।
- [ ] ওয়েবসাইটের অ্যাকাউন্ট মোছার পাতা থেকে ইমেইল আসে কিনা।
