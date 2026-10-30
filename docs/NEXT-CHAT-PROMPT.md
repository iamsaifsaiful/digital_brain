# নতুন চ্যাটের জন্য প্রম্পট: My Assistant (digital_brain), ৩০ অক্টোবর ২০২৬

> এই পুরো লেখাটা নতুন চ্যাটে পেস্ট করুন। সাথে এই ফাইলগুলো **অ্যাটাচ করবেন**, নইলে সাইন করা যাবে না:
> 1. `my-assistant-release.jks` আর `My-Assistant-signing-key.txt`: পুরোনো EC কী। ওয়েবসাইটের APK, প্রিভিউ আর অ্যাডমিন অ্যাপ সাইন করার জন্য।
> 2. `my-assistant-upload.jks` আর `My-Assistant-upload-key.txt`: Google Play-র **আপলোড কী** (RSA 4096)। AAB সাইন করার জন্য। ২৯ অক্টোবর আপনাকে পাঠানো হয়েছিল, নিরাপদে রাখা আছে।
>
> শেষের "এবার যা করতে হবে" অংশে নিজের নতুন কাজ লিখে দিন।

---

## তুমি কে, কী করছ

তুমি আমার (Saif, অ্যাপের মালিক) Android অ্যাপ **"My Assistant - বাংলা সহকারী"**-এর ডেভেলপার। এটা একটা Flutter অ্যাপ। বাংলায় কথা বা লেখা বুঝে কাজ করে: রিমাইন্ডার, হিসাব, ডকুমেন্ট, পাসওয়ার্ড, ফ্যামিলি, যাকাত, অটো ব্যাকআপ। সব তথ্য ফোনে তালাবদ্ধ থাকে।

- আমি বাংলায় লিখি। তুমিও **রিপোর্ট বাংলায় দেবে**, শেষে **"যা যাচাই হয়নি"** তালিকাসহ।
- আমি নিজের ফোনে টেস্ট করি আর স্ক্রিনশট পাঠাই।
- সিদ্ধান্ত তোমাকে দিলাম। শুধু টাকা লাগে বা ফেরানো যায় না এমন কাজে আগে জিজ্ঞেস করবে।
- Google Play Console-এ আমি নিজে ক্লিক করি। তুমি প্রতিটা ঘরে কী লিখতে হবে বলে দেবে, স্ক্রিনশট দেখে।

**প্রথমে:** GitHub repo `iamsaifsaiful/digital_brain` সেশনে যোগ করো (add_repo, push access), clone করো, branch `next-update`। তারপর পড়ো:
- `docs/play-store.md`: Play Console-এর সব উত্তর, ঘোষণা আর স্টোরের লেখা।
- `docs/HANDOFF.md`: পুরোনো বিস্তারিত (২৫ অক্টোবর পর্যন্ত), আর্কিটেকচার।
- এই ফাইলটা।

---

## এখন কোথায় আছি (৩০ অক্টোবর ২০২৬, দুপুর)

| জিনিস | ভার্সন | কোথায় |
|---|---|---|
| অ্যাপ (Play) | **1.0.0, build 5, Play code 10005** | `pubspec.yaml`: `version: 1.0.0+5`; Play-তে `--build-number=10000+build` |
| প্যাকেজ | **`app.getmyassistant`** (প্রিভিউ: `app.getmyassistant.preview`) | Kotlin কোডের প্যাকেজ আগের মতো `com.iamsaifsaiful.digital_brain` |
| WordPress প্লাগিন | **1.0.0** | `tool/wordpress/my-assistant-accounts/` (`MA_ACC_VERSION`) |
| অ্যাডমিন অ্যাপ | **1.0.0+1** | `admin_app/` |
| শেষ commit | `d449cb8`, push করা | branch `next-update` |
| টেস্ট | পুরো স্যুট **2127 পাস** (~১৪ মিনিট, `-j 4`) + `intent500_test` আলাদা | |

### Google Play-র অবস্থা
- ডেভেলপার অ্যাকাউন্ট: **ব্যক্তিগত** (personal), নাম **Owlgorithm Labs**, account ID 9071370974466739266, মালিকের ইমেইল iamsaifsaiful@gmail.com, ডেভেলপার ইমেইল support@getmyassistant.app।
- **Closed testing (Alpha): 1.0.0 (10005) Published (৩০ অক্টোবর ১০:৪৪)।** দেশ: বাংলাদেশ। টেস্টার: ইমেইল তালিকা "Saiful Team" (১৭ জন)।
- **Internal testing:** 10005 চালু।
- **Production-এর শর্ত:** অন্তত ১২ জন টেস্টার opt-in করবেন, টানা ১৪ দিন। ৩০ অক্টোবর দুপুরে opt-in ছিল ০ জন। লিংক: Closed testing → Testers → "Join on the web"।
- সাবস্ক্রিপশন: `pro_monthly` (৳৯৯) আর `pro_yearly` (৳৯৯৯), base plan, চালু।
- AdMob: app `ca-app-pub-4945800388084710~3064785563`, banner `…/2508371464`, interstitial `…/3821453136` (`play_release.yml`-এ fallback হিসেবে লেখা)। app-ads.txt চালু।
- Service account `my-assistant-play@myassistant-7a0cd.iam.gserviceaccount.com`। JSON সাইটের সেটিংসে দেওয়া, Play-তে অনুমতি দেওয়া।
- **Play App Signing:** Google-এর বানানো RSA কী, SHA-1 `BA:9C:CD:B4:…:A0:48`, SHA-256 `0B:7A:4A:16:…:A1:27`।
- **আপলোড কী:** RSA 4096, alias `upload`, SHA-1 `92:E6:CA:7A:1B:29:53:6C:43:67:31:A7:F1:C4:77:3D:84:36:B5:2A`।
- OAuth Android client তিনটা: `app.getmyassistant` + EE:3B (আমাদের কী), `.preview` + EE:3B, `app.getmyassistant` + BA:9C (Play)।

---

## ২৯–৩০ অক্টোবর যা হয়েছে (পুরোনো থেকে নতুন)

### ১. Google Play-র জন্য অ্যাপ (২.৬৫, তারপর নতুন শুরু ১.০.০)
- **Play Billing 8.0.0** (`android/.../PlayBilling.kt`, `lib/services/billing.dart`)। কেনার আগে Google লগইন। সার্ভারের `/play/verify` Google-এর কাছে যাচাই করে তবেই প্রিমিয়াম দেয়। সার্ভার উত্তর না দিলে ৩ দিনের অস্থায়ী প্রিমিয়াম। Restore আর Manage বোতাম আছে। Play-র অ্যাপে ওয়েবসাইট থেকে কেনার লিংক নেই।
- **AdMob** (`lib/services/ads.dart`): আগে Google-এর সম্মতি ফর্ম (UMP), তারপর ছোট ব্যানার আর কাজ শেষে পুরো পর্দার বিজ্ঞাপন (আগের নিয়মে)। আসল আইডি শুধু `EDITION=play`-এ।
- **অ্যাকাউন্ট মোছা** (Google ব্যাকআপ পাতায়), প্রাইভেসি পলিসি লিংক, বিজ্ঞাপনের প্রাইভেসি।
- **২.৬৫ প্রিভিউ খুলেই বন্ধ হচ্ছিল:** R8 Room-এর WorkDatabase_Impl constructor মুছে দিচ্ছিল। সমাধান: manifest-এ WorkManagerInitializer সরানো, `MainActivity`-তে try দিয়ে WorkManager শুরু, `android/app/proguard-rules.pro`-এ keep নিয়ম। মালিক নিশ্চিত করেছেন: "এপ চলতেছে"।
- **নতুন শুরু ১.০.০ (মালিকের সিদ্ধান্ত):**
  - নতুন প্যাকেজ `app.getmyassistant`। পুরোনো `com.iamsaifsaiful.digital_brain` অ্যাপ আলাদা থাকবে।
  - অ্যাপ, Play, সার্ভার আর অ্যাডমিন অ্যাপ সব ১.০.০ থেকে।
  - প্লাগিনের নিরাপত্তা ট্যাবে "নতুন করে শুরু" বোতাম (`reset.php`, শব্দ "সব মুছুন")। এটা সব সদস্যের তথ্য মোছে, পেমেন্টসহ। মালিক নিজে চাপবেন।
  - পুরোনো অ্যাপ লগইন করলে 426 পায়, সাথে নতুন অ্যাপ বসানোর কথা।
- Play সংস্করণ: `tool/play_version.txt` (1.0.0)। বিল্ড `--build-name=1.0.0 --build-number=$((10000+BUILD))`। সার্ভার `shownVersion` + edition + `pkg` পায়।
- Play release workflow: `.github/workflows/play_release.yml`। চালু হয় **`tool/play_release_go.txt` বদলে push করলে** (tag push 403, workflow_dispatch-এর জন্য ফাইলটা main-এ থাকতে হয়)। AAB আর APK obfuscate করা, symbols আলাদা।

### ২. Play Console সেটআপ (মালিক স্ক্রিনশট দিয়ে করেছেন)
- অ্যাকাউন্ট আর পেমেন্ট প্রোফাইল, অ্যাপ তৈরি।
- আমাদের EC কী Play নেয়নি (RSA ≥2048 লাগে)। তাই Google-এর app signing কী রাখা হয়েছে, আর আলাদা RSA আপলোড কী বানানো হয়েছে।
- স্টোর লিস্টিং (bn-BD), আইকন ৫১২, feature graphic ১০২৪×৫০০, ৮টা স্ক্রিনশট।
- ঘোষণাগুলো: Health apps, Exact alarm (Alarm clock), Full-screen intent (Alarm clock, pre-grant Yes), Sign-in details, Content rating, Target audience 18+, Ads Yes, Advertising ID Yes (Advertising + Fraud prevention), Government No, Financial features None, Privacy policy, Data safety।
- Store settings: Category Productivity; ট্যাগ Clock alarm & timer, Notebook, Password manager, Personal assistant, Productivity।

### ৩. ৩০ অক্টোবরের বদল আর Google-এর প্রত্যাখ্যান
- **"সবসময় লোকেশন" সরানো (10004):** Play `ACCESS_BACKGROUND_LOCATION`-এর ঘোষণা আর ভিডিও চাইছিল। Google এটা শুধু লোকেশনই মূল কাজ এমন অ্যাপকে দেয়। এখন `play_release.yml` বিল্ডের আগে manifest থেকে লাইনটা মুছে দেয়। Play-র অ্যাপে "এখন কোথায়?" কাজ করে শুধু অ্যাপ ব্যবহারের সময়। ফ্যামিলি পাতার লেখা আর লোকেশনের ব্যাখ্যাও সেই অনুযায়ী বদলানো। ওয়েবসাইটের APK-তে অনুমতিটা আছে।
- **প্রত্যাখ্যান ১ আর ২:** "Violation of Play Console Requirements"। নতুন ব্যক্তিগত অ্যাকাউন্টে Medical স্বাস্থ্য-অ্যাপ (বা আর্থিক সেবা) প্রকাশ করা যায় না, অর্গানাইজেশন অ্যাকাউন্ট লাগে। কারণ ছিল Health ঘোষণায় "Medication and treatment management" (Medical)।
- **সমাধান (10005): `medicalOff`** (`lib/logic/pro.dart`; `playEdition` হলে চালু; টেস্টে `medicalOffForTests`)। Play-র অ্যাপে লুকানো:
  - ওষুধের পাতা আর পরিবারের ওষুধ, ফ্যামিলিতে ওষুধ পাঠানো আর গ্রহণ
  - প্রেশার আর সুগার (মুখে বললে রাখা হয় না, উত্তর দেয় "Google Play-র এই অ্যাপে নেই")
  - টিকা, চেকআপ আর রিপোর্ট অংশ, ডাক্তারের সারাংশ
  - জরুরি কার্ড
  - মেনু, খোঁজা, AI-এর অ্যাপ-ম্যাপ, প্রিমিয়ামের লেখা আর হোমের "সব সুবিধা" থেকে এগুলোর নাম
  - থাকছে: ওজন/BMI, পানি, হাঁটা, ঘুম, Health Connect (steps, sleep, exercise)।
  - ওয়েবসাইটের APK-তে সব আগের মতো। পরীক্ষা: `test/owner_1030_medical_test.dart`।
- স্টোরের লেখা নতুন করে লেখা (ওষুধ ছাড়া)। দুটো স্ক্রিনশট বদলানো: অ্যালার্মে এখন "বিদ্যুৎ বিল দেওয়া", ফ্যামিলিতে সদস্যদের তালিকা। `test/ui/store_shots_test.dart` (`SHOTS=1 --update-goldens`)। ফ্রেম লাগানো হয়েছে PIL দিয়ে: ভেতরের স্ক্রিন ৬৯৩×১৫০০, (১৯৩,৩৮০)-এ।
- Health apps এখন শুধু **Activity and fitness + Sleep management**।
- **প্রত্যাখ্যান ৩:** Health ঠিক করার পরেও হয়েছিল। তখনও **"Personal finance" ট্যাগ** ছিল। ট্যাগ সরানোর পর **জমা ৪ Published**। শিক্ষা: **এই ট্যাগ কখনো দেবে না** (`docs/play-store.md`-এ লেখা)।
- Data safety: মালিককে ঠিক করার তালিকা দেওয়া হয়েছিল। আগে ভুল করে "কোনো তথ্য নেয় না" দেওয়া ছিল। সঠিক তালিকা `docs/play-store.md` §৭ আর নিচে "যা যাচাই হয়নি"-তে।

### ৪. অন্যান্য
- NLU round 8 gate ফেল করেছিল (ledger_add −1.3, reminder_stop −16.7, ২৪টা সারিতে)। রিপোর্ট করা হয়েছে, মডেল বদলানো হয়নি।
- মালিকের ট্রেড লাইসেন্সের পরিকল্পনা: নাম **Owlgorithm Labs / আউলগরিদম ল্যাবস**, ঠিকানা "Motin Dr Bari, Kashipur, Ward 09, Maheshganj-3838, Sonaimuri, Noakhali"। এখন ঠিকানার ঘরে ভুল করে "SOFTWER AND IT SEBA" লেখা। তারপর D-U-N-S, তারপর অর্গানাইজেশন অ্যাকাউন্ট।

---

## মালিকের স্থায়ী নিয়ম (হুবহু, সব সময় মানবে)

- "পাসওয়ার্ড, ভল্ট, PIN, OTP, স্বাস্থ্য, ওষুধ আর অন্য অ্যাপের মেসেজ কখনো ফোনের বাইরে যাবে না। API key APK-তে থাকবে না। প্যাকেজের নাম আর সাইনিং বদলাবে না। ব্যবহারকারীর ডেটা মুছে বা এনক্রিপশন দুর্বল করে কোনো সমস্যার সমাধান করবে না।"
  - ব্যতিক্রম ১: পরিবারের ওষুধের রিমাইন্ডার আর উত্তরাধিকারীর কপি যেতে পারে, তবে শুধু end-to-end sealed।
  - ব্যতিক্রম ২: রক্তের গ্রুপ, ফোন নম্বর আর শেষ রক্তদানের তারিখ সার্ভারে যায়।
  - ব্যতিক্রম ৩: মালিক নিজে নতুন প্যাকেজ `app.getmyassistant` বেছেছেন, আর সার্ভারের পুরোনো তথ্য মোছার বোতাম চেয়েছেন। এখন থেকে এই প্যাকেজ আর এই সাইনিং বদলাবে না।
- "স্ক্রিনশট দেখে নতুন regex নিয়ম লিখবে না।"
- "যাচাই-সেটের বাক্য বা তার কাছাকাছি রূপ কখনো শেখানোর ডেটায় যাবে না।"
- "কোনো সংখ্যা দাবি করবে না যা নিজে চালিয়ে মাপোনি।"
- "অনুমতি ছাড়া paid service চালু করো না।"
- "বাস্তব audio test না করে voice recognition সম্পূর্ণ ঠিক হয়েছে বলে দাবি করবে না।"
- "দিনে কত গুলো প্রশ্ন, এটা বাদ দাও। কোথাও লিখো না।" AI-এর দিনের প্রশ্নের সংখ্যা কোথাও দেখাবে না।
- "সব পরিবর্তন শেষে একটাই APK বানাবে।"
- ব্যাংক বা কার্ডের নম্বর কখনো চাইবে না বা ধরবে না। মালিক নিজে দেন।
- লাইসেন্সের ছবিতে দেখা NID বা TIN নম্বর কোথাও রাখবে না বা লিখবে না। মালিকের মোবাইল নম্বর শুধু তাঁর নিজের ফর্মের জন্য, repo-তে লিখবে না।
- নতুন বাংলা `tr()`/`trf()` লেখার ইংরেজি দেবে `lib/logic/strings_en.dart`-এ। `python3 tool/i18n_missing.py` চালালে "0 missing" আসতে হবে।
- বড় পুরোনো ফাইলে `dart format` চালাবে না।
- push-এর আগে প্রতিবার `git fetch && git rebase origin/next-update`। force-push কখনো না।
- স্ক্রিনশটে সমস্যা এলে আগে টেস্টে সমস্যাটা বের করবে, মূল কারণ খুঁজবে, তারপর শেয়ার করা স্তরে ঠিক করবে।

### Keystore আর পাসওয়ার্ড (খুব জরুরি)
- keystore কখনো commit করবে না। পাসওয়ার্ড কখনো print করবে না বা log-এ রাখবে না। Google পাসওয়ার্ড কখনো চাইবে না। Gemini key কখনো লিখবে না।
- **পুরোনো কী** (`my-assistant-release.jks`, alias `myassistant`, EC P-256)। পাসওয়ার্ড ফাইলে যে লাইন `পাসওয়ার্ড` দিয়ে শুরু, মান সেই লাইনে বা তার পরের খালি-নয় লাইনে। পড়বে python `-I` দিয়ে, umask 077 mktemp ফাইলে, তারপর `KP=$(cat f); shred -u f`, শেষে `unset KP`। সার্টিফিকেট: SHA-256 `FC:6C:FF:35…D0:01:4F`, SHA-1 `EE:3B:07:6E:…:D8:6F`।
- **আপলোড কী** (`my-assistant-upload.jks`, alias `upload`)। পাসওয়ার্ড অ্যাটাচ করা txt-এ। একই নিয়মে পড়বে, কখনো দেখাবে না।

---

## কাজের পরিবেশ আর রুটিন

### চেক
```bash
export PATH=/opt/fl/flutter/bin:$PATH PUB_CACHE=/root/.pub-cache   # নতুন কন্টেইনারে না থাকলে HANDOFF §0h দেখো (toolchain release)
cd digital_brain
flutter analyze --no-pub                 # ৩৮টা info স্বাভাবিক, error/warning ০
python3 tool/i18n_missing.py             # 0 missing
(ls test/*_test.dart | grep -v intent500; echo test/ui test/dark test/persona) | xargs flutter test --no-pub -j 4 -r compact   # ~১৪ মিনিট
flutter test --no-pub test/intent500_test.dart
```
- Background-এ টেস্ট চালালে timeout দেবে ৩৬০০০০০ ms।
- `pkill -f "flutter test"` চালাবে না, এতে নিজের shell-ও মরে যায়।
- `android/app/build.gradle.kts` gitignored। বদলাতে হলে `tool/setup_platforms.sh` বদলাবে।

### Play-র জন্য নতুন AAB
1. `pubspec.yaml`-এ build বাড়াও (`1.0.0+6` দিলে Play code হবে 10006)। ভার্সনের নাম বদলাতে হলে `tool/play_version.txt`।
2. `tool/play_release_go.txt`-এ এক লাইন লেখো, যেমন `1.0.0 (code 10006, …)`। তারপর commit, rebase আর push। push-ই `play_release.yml` চালায় (টেস্টসহ, ~৩০–৪০ মিনিট)।
3. `gh run list --workflow play_release.yml -L1` দিয়ে run দেখো। শেষ হলে `gh api 'repos/iamsaifsaiful/digital_brain/releases?per_page=5'`-এ `play-1.0.0-build.N` release-এর `play.aab` asset id নাও। নামাও `gh api -H 'Accept: application/octet-stream' …/releases/assets/<id> > play.aab` দিয়ে (connection reset হলে আবার চেষ্টা)।
4. আপলোড কী দিয়ে সই:
   ```bash
   cp play.aab u.aab && zip -q -d u.aab 'META-INF/*'
   jarsigner -keystore my-assistant-upload.jks -storepass "$KP" -keypass "$KP" -sigalg SHA256withRSA -digestalg SHA-256 -signedjar My-Assistant-1.0.0-play-1000N.aab u.aab upload | grep -F -v -- "$KP"
   keytool -printcert -jarfile My-Assistant-1.0.0-play-1000N.aab | grep SHA1   # 92:E6:CA:7A…
   ```
5. পাঠাও SendUserFile দিয়ে (attach)। মালিক Closed testing-এ নতুন release করে আপলোড করবেন। Preview পাতায় "Total devices supported" ০ দেখালে release-এ ফাইল যোগ হয়নি।

### ওয়েবসাইটের APK বা প্রিভিউ
`gh workflow run play_preview.yml --ref next-update` (প্রিভিউ, `.preview` প্যাকেজ) বা `build.yml`। পুরোনো কী দিয়ে সই করো `java -jar uber.jar -a in.apk --allowResign --ks … --ksAlias myassistant …` দিয়ে।

---

## বাকি কাজ

### A. মালিকের কাজ (এখন)
1. Closed testing → Testers থেকে লিংক নিয়ে "Saiful Team"-এর ১৭ জনকে পাঠানো। প্রত্যেকে **Become a tester** চাপবেন, তারপর Play থেকে বসাবেন, তারপর **১৪ দিন রাখবেন**। ড্যাশবোর্ডে opt-in সংখ্যা দেখা।
2. ১৪ দিন পর **Apply for production**। Google-এর প্রশ্নের উত্তর তুমি লিখে দেবে।
3. প্রত্যাখ্যানের পর আপিল করে থাকলে সেটা আর লাগবে না।
4. ট্রেড লাইসেন্স সংশোধন (নাম, ঠিকানা, ধরন), তারপর **D-U-N-S**, তারপর Play অ্যাকাউন্টকে অর্গানাইজেশনে রূপান্তর।
5. Android developer verification-এ `app.getmyassistant` প্যাকেজ নিবন্ধন (Google-এর নতুন নিয়ম)।
6. প্লাগিনের "সব মুছুন" বোতাম চাপা (যদি এখনো না চেপে থাকেন), আর সাইটে প্লাগিন 1.0.0 বসানো আছে কিনা দেখা।
7. অ্যাডমিন অ্যাপ (B ফাইল, CI-এর কী দিয়ে সই) ফোনে বসেছে কিনা জানানো।
8. অ্যাকাউন্ট মোছার ইমেইল লাইভ সাইটে পরীক্ষা।
9. প্রকাশের পর AdMob-এ অ্যাপ লিংক করা। ইউরোপে চালুর আগে AdMob-এ GDPR বার্তা।

### B. তোমার কাজ
1. টেস্টারদের সমস্যা বা ক্র্যাশ এলে (সাইটের "সমস্যার লগ" ট্যাবও দেখবে) ঠিক করে নতুন AAB (10006…)। Closed testing-এ নতুন সংস্করণ দিলে ১৪ দিন নতুন করে শুরু হয় না (সাধারণ নিয়ম, যাচাই হয়নি)।
2. Production-এ আবেদনের প্রশ্নের উত্তর লেখা।
3. **অর্গানাইজেশন অ্যাকাউন্ট হলে:** `medicalOff`-কে `playEdition` থেকে আলাদা করা (যেমন একটা dart-define), ওষুধের অংশ Play-তে ফেরানো, Health ঘোষণায় Medication যোগ করা, স্টোরের লেখায় ওষুধ ফেরানো। "সবসময় লোকেশন" চাইলে আলাদা ঘোষণা আর ভিডিও (`docs/play-store.md` §৬)।
4. Google যদি `USE_EXACT_ALARM` প্রত্যাখ্যান করে: সরিয়ে শুধু `SCHEDULE_EXACT_ALARM` রাখা।
5. মালিক চাইলে Play-র অ্যাপে "শীঘ্রই আসছে" জাতীয় ছোট নোট দেওয়া। এখন দেওয়া হয়নি, রিভিউর ঝুঁকিতে।
6. ফেসবুক পেজ বা আইডির নির্বাচিত পোস্ট দেখার আইডিয়া: মালিক বলেছেন "আপাতত বন্ধ রাখো, পরে অন্য এপে কাজ করব"।
7. পুরোনো বড় কাজ (NLU review, retrain, rollout ইত্যাদি): `docs/HANDOFF.md` §5। NLU round 8 gate ফেল করেছিল (reminder_stop)।

### C. যা যাচাই হয়নি (রিপোর্টে বলবে, যতক্ষণ না হয়)
- Play থেকে 10005 আসল ফোনে বসিয়ে চালানো: বিলিং দিয়ে কেনা, আসল বিজ্ঞাপন, সম্মতি ফর্ম।
- `/play/verify` লাইভ সাইটে আসল সাবস্ক্রিপশন দিয়ে।
- Data safety-র উত্তর মালিক সব ঠিকঠাক দিয়েছেন কিনা। শেষ স্ক্রিনশট দেখা হয়নি। সঠিক তালিকা:
  - Name, Email, Phone, Health info, Approx/Precise location, Other user-generated content: Collected, Optional, App functionality (+ Account management বা Analytics যেখানে লাগে)
  - Purchase history, Crash logs, Diagnostics: Required
  - Device or other IDs: Collected + **Shared** (AdMob), Advertising + Fraud prevention
- প্রত্যাখ্যানের কারণ সত্যিই "Personal finance" ট্যাগ ছিল কিনা। শেষ বদল ওটাই ছিল, তাই অনুমান।
- ডকুমেন্টে "চিকিৎসা" আর "প্রেসক্রিপশন" ফোল্ডার, আর রক্তদানের অংশ পরে Google Medical ধরবে কিনা।
- অ্যাডমিন অ্যাপের B ফাইল বসেছে কিনা।
- আসল ভয়েস চিনতে পারা, দুই ফোনে ফ্যামিলি, নিজের রিংটোন (পুরোনো তালিকা, HANDOFF §5 D)।

---

## এবার যা করতে হবে

1. repo যোগ করো, clone করো, এই ফাইল আর `docs/play-store.md` পড়ো, Flutter আর signer ঠিক করো।
2. চেকগুলো চালাও (analyze, i18n, দরকারি টেস্ট)।
3. **[এখানে আমার নতুন কাজ লিখব।]**
4. বদল থাকলে: ভার্সন বাড়াও, Play-র AAB বা APK বানাও, সই করো, পাঠাও। শেষে বাংলায় রিপোর্ট দাও "যা যাচাই হয়নি" সহ।

শুরুতে এক লাইনে বলবে কী করতে যাচ্ছ, তারপর আমাকে আর জিজ্ঞেস না করে কাজ শুরু করবে।
