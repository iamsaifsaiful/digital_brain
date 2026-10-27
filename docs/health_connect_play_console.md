# Health Connect — Play Console declaration (owner submits)

App: My Assistant (read only; no write permissions are requested).

## android.permission.health.READ_STEPS

**বাংলা:** অ্যাপের স্বাস্থ্য পাতায় ব্যবহারকারীর নিজের ("আমি" প্রোফাইল) আজকের হাঁটার স্টেপ আর আনুমানিক দূরত্ব দেখাতে, আর ব্যবহারকারী জিজ্ঞেস করলে ("আজ কত হাঁটলাম?") সেই সংখ্যা দিয়ে উত্তর দিতে। তথ্য শুধু ফোনে, এনক্রিপ্ট করা অবস্থায় থাকে; সার্ভারে, AI-তে বা তৃতীয় পক্ষের কাছে যায় না; বিজ্ঞাপনে ব্যবহার হয় না।

**English:** To show the user's own ("Me" profile) step count for today and the approximate distance on the app's health page, and to answer the user's own question ("How much did I walk today?") with that number. The data stays on the device, encrypted; it is never sent to our server, to an AI service or to any third party, and is never used for advertising.

## android.permission.health.READ_SLEEP

**বাংলা:** ঘুমের সেশন (ঘুমের ধাপসহ) থেকে প্রতি রাতে কত ঘণ্টা ঘুম হয়েছে তা হিসাব করে স্বাস্থ্য পাতায় ঘুমের মাপ হিসেবে দেখাতে, সাপ্তাহিক গড় দেখাতে, আর জিজ্ঞেস করলে ("গত রাতে কত ঘুমিয়েছি?") উত্তর দিতে। জেগে থাকা বা বিছানার বাইরে থাকার সময় বাদ দেওয়া হয়। তথ্য শুধু ফোনে থাকে, কোথাও পাঠানো হয় না।

**English:** To work out the hours slept each night from sleep sessions (and their stages), show them as sleep readings and a weekly average on the health page, and answer the user's own question ("How long did I sleep last night?"). Awake and out-of-bed time is left out. The data stays on the device and is never sent anywhere.

## android.permission.health.READ_EXERCISE

**বাংলা:** ব্যায়ামের সেশন থেকে মিনিট হিসাব করে স্বাস্থ্য পাতায় ব্যায়ামের মাপ হিসেবে দেখাতে (আজ আর গত ৭ দিন), আর জিজ্ঞেস করলে ("আজ কত মিনিট ব্যায়াম করলাম?") উত্তর দিতে। হাতে লেখা ব্যায়ামের মাপের সাথে একই তালিকায় দেখায়, একই সেশন দুবার যোগ হয় না। তথ্য শুধু ফোনে থাকে, কোথাও পাঠানো হয় না।

**English:** To turn exercise sessions into exercise minutes on the health page (today and the last 7 days), alongside readings the user writes by hand, without adding the same session twice, and to answer the user's own question ("How many minutes did I exercise today?"). The data stays on the device and is never sent anywhere.

## Privacy policy / rationale screen

The app declares `HealthPrivacyActivity` for `androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE` (Android 13 and older) and the `ViewPermissionUsageActivity` alias for `android.intent.action.VIEW_PERMISSION_USAGE` with category `android.intent.category.HEALTH_PERMISSIONS` (Android 14+). Both show the same Bangla/English text (res/values/strings.xml, `health_privacy`). The public privacy policy on the website should carry the same points.
