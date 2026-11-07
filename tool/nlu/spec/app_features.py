# The app's map for teaching (owner, 7 Nov 2026: "প্রথমত জানানো উচিত, আমাদের
# এপে কি কি মেনু আছে, মেনুর ভেতরের সেকশন, ফিচার কি কি, কোন ফিচার কিভাবে
# ইউজারকে সাহায্য করে বা ফিচারের মূল উদ্দেশ্য কি").
#
# One entry per feature: where it is (menu › section), what it is for, the
# names people call it (Bangla, Banglish, English), what they want to do with
# it (said as "…তে" — "রিমাইন্ডার দিতে"), and what they may ask whether the
# app can do. The page id is the app's own (lib/logic/app_map.dart), so a
# question about a feature is answered from the app's map and opens its page.
#
#   python3 tool/nlu/spec/app_features.py   → tool/nlu/spec/app_features.json
#                                             and docs/app-feature-map.md (for reading)
import json, os

F = []


def feat(id, menu, purpose, bn, bl, en, acts, acts_bl=(), acts_en=(), can=()):
    F.append(dict(id=id, menu=menu, purpose=purpose, bn=list(bn), bl=list(bl), en=list(en), acts=list(acts), acts_bl=list(acts_bl), acts_en=list(acts_en), can=list(can)))


# ── হোম ──
feat('home', 'হোম', 'এক নজরে আজকের তারিখ (বাংলা, হিজরি), আজকের কাজ-রিমাইন্ডার আর টাকার অবস্থা; নিচে কথা বলার ঘর।',
     ['হোম', 'হোম পেজ', 'প্রথম পাতা'], ['home page', 'home'], ['the home screen', 'home'],
     ['হোমের ছবি বদলাতে', 'আজকের সব এক নজরে দেখতে'], ['home er chobi bodlate'], ['change the home picture', 'see today at a glance'],
     ['হোমে নিজের ছবি দেওয়া', 'আজকের সব এক জায়গায় দেখা'])
feat('calendar', 'হোম › ক্যালেন্ডার', 'বাংলা, ইংরেজি আর হিজরি তারিখ, সরকারি ছুটি, রমজানে সেহরি-ইফতারের সময়।',
     ['ক্যালেন্ডার', 'বাংলা ক্যালেন্ডার', 'হিজরি তারিখ', 'ছুটির তালিকা'], ['calendar', 'bangla date'], ['the calendar', 'holidays list'],
     ['বাংলা তারিখ দেখতে', 'সামনের ছুটি দেখতে', 'সেহরি-ইফতারের সময় দেখতে'], ['bangla tarikh dekhte', 'chutir din dekhte'], ['see the Bangla date', 'check upcoming holidays'],
     ['হিজরি তারিখ দেখা', 'সরকারি ছুটি দেখা', 'সেহরি ইফতারের সময় জানা'])
feat('compass', 'সংরক্ষণ › কম্পাস', 'ফোনের সেন্সরে দিক আর কিবলার দিক; মিললে ফোন কেঁপে জানায়।',
     ['কম্পাস', 'কিবলা', 'কিবলার দিক'], ['compass', 'kibla'], ['the compass', 'qibla direction'],
     ['কিবলার দিক বের করতে', 'দিক দেখতে'], ['kiblar dik ber korte'], ['find the qibla', 'check directions'],
     ['কিবলার দিক দেখা', 'দিক নির্ণয় করা'])
# ── দিনলিপি ──
feat('tasks', 'দিনলিপি › কাজ', 'দিনের কাজ, বাজারের লিস্ট; টিক দিলে শেষ, না হলে পরের দিনে যায়; তালিকা WhatsApp-এ পাঠানো যায়।',
     ['কাজের তালিকা', 'কাজের লিস্ট', 'টুডু লিস্ট', 'বাজারের লিস্ট'], ['kajer list', 'todo list'], ['the to-do list', 'tasks'],
     ['নতুন কাজ যোগ করতে', 'কাজ শেষ হিসেবে টিক দিতে', 'কাজের দিন বদলাতে', 'বাজারের লিস্ট বানাতে', 'কাজের তালিকা কাউকে পাঠাতে'],
     ['kaj add korte', 'kaj tick dite', 'bazar list banate'], ['add a task', 'tick off a task', 'move a task to another day', 'share my list'],
     ['কাজের তালিকা রাখা', 'বাজারের লিস্ট বানানো', 'কাজ পরের দিনে সরানো'])
feat('reminders', 'দিনলিপি › রিমাইন্ডার', 'ঠিক সময়ে বাজে, ফোন লক থাকলেও; আগে থেকে জানাতে পারে; প্রতিদিন, প্রতি সপ্তাহে, প্রতি মাসে।',
     ['রিমাইন্ডার', 'মনে করানোর ব্যবস্থা', 'মনে করিয়ে দেওয়া'], ['reminder', 'remainder'], ['reminders', 'a reminder'],
     ['রিমাইন্ডার দিতে', 'রিমাইন্ডারের সময় বদলাতে', 'প্রতিদিনের রিমাইন্ডার দিতে', 'রিমাইন্ডার বন্ধ করতে', 'আধা ঘণ্টা আগে জানাতে'],
     ['reminder dite', 'reminder off korte'], ['set a reminder', 'change a reminder time', 'turn off a reminder', 'get a reminder every day'],
     ['প্রতি মাসে মনে করানো', 'ফোন লক থাকলেও বাজানো', 'কিছুক্ষণ আগে জানানো'])
feat('alarms', 'দিনলিপি › অ্যালার্ম', 'ঘুম ভাঙানোর অ্যালার্ম, নিজের পছন্দের রিংটোন।',
     ['অ্যালার্ম', 'এলার্ম', 'ঘুম ভাঙানোর অ্যালার্ম'], ['alarm', 'elarm'], ['an alarm', 'alarms'],
     ['অ্যালার্ম দিতে', 'অ্যালার্মের রিংটোন বদলাতে'], ['alarm dite', 'alarm er gaan bodlate'], ['set an alarm', 'change the alarm tone'],
     ['নিজের গান দিয়ে অ্যালার্ম দেওয়া', 'প্রতিদিন একই সময়ে অ্যালার্ম'])
feat('diary', 'দিনলিপি › ডায়েরি', 'দিনের কথা লিখে রাখা; সাথে অভ্যাস, বিশেষ দিন আর তৈরি তালিকা।',
     ['ডায়েরি', 'দিনলিপি', 'ডায়রি'], ['diary', 'dinlipi'], ['the diary', 'my journal'],
     ['ডায়েরি লিখতে', 'আগের দিনের লেখা দেখতে'], ['diary likhte'], ['write my diary', 'read old entries'],
     ['প্রতিদিনের কথা লিখে রাখা'])
feat('special', 'সংরক্ষণ › বিশেষ দিন', 'জন্মদিন, বিবাহবার্ষিকী, মৃত্যুবার্ষিকী — প্রতি বছর আগের দিন আর সেদিন মনে করায়।',
     ['বিশেষ দিন', 'জন্মদিনের তালিকা', 'বিবাহবার্ষিকী'], ['birthday list', 'bishesh din'], ['birthdays', 'special days'],
     ['জন্মদিন রাখতে', 'বিবাহবার্ষিকী মনে রাখতে', 'কার জন্মদিন কবে দেখতে'], ['birthday rakhte', 'kar jonmodin kobe dekhte'], ['save a birthday', 'see upcoming birthdays'],
     ['প্রতি বছর জন্মদিন মনে করানো', 'বিয়ের দিন মনে রাখা'])
feat('habits', 'দিনলিপি › অভ্যাস', 'নামাজ, হাঁটা, পানি খাওয়া — প্রতিদিন টিক, টানা কত দিন হলো।',
     ['অভ্যাস', 'অভ্যাসের হিসাব'], ['habit', 'ovvash'], ['habits', 'habit tracker'],
     ['নতুন অভ্যাস যোগ করতে', 'অভ্যাসে টিক দিতে'], ['habit add korte'], ['track a habit', 'tick a habit'],
     ['নামাজের হিসাব রাখা', 'প্রতিদিন হাঁটার হিসাব রাখা'])
feat('medicines', 'দিনলিপি › ওষুধ', 'কোন ওষুধ কখন খাবেন, সময়মতো মনে করানো; ফুরিয়ে এলে জানানো।',
     ['ওষুধের রিমাইন্ডার', 'ওষুধের পাতা', 'ঔষধের হিসাব'], ['oshudh er reminder', 'medicine reminder'], ['medicines', 'pill reminder'],
     ['ওষুধের সময় রাখতে', 'ওষুধ ফুরানোর আগে জানতে'], ['oshudh er time rakhte'], ['set a medicine reminder', 'know when pills run out'],
     ['ওষুধ খাওয়ার কথা মনে করানো', 'ওষুধ ফুরানোর আগে জানানো'])
feat('templates', 'দিনলিপি › তৈরি তালিকা', 'হজ, বিয়ে, নতুন বাসা, দেশে ফেরা — তৈরি কাজের তালিকা এক চাপে।',
     ['তৈরি তালিকা', 'টেমপ্লেট'], ['template'], ['ready-made lists', 'templates'],
     ['হজের তৈরি তালিকা নিতে', 'বিয়ের কাজের তালিকা নিতে'], ['hojj er list nite'], ['use a ready-made checklist'],
     ['বিয়ের কাজের তালিকা তৈরি পাওয়া'])
# ── হিসাব ──
feat('money', 'হিসাব › আয়-ব্যয়', '“এখন আছে” কত টাকা আর কীভাবে হলো; নিজের আয় আর খরচ খাত ধরে।',
     ['আয়-ব্যয়', 'খরচের হিসাব', 'আয় ব্যয়ের হিসাব', 'টাকার হিসাব'], ['khoroch er hisab', 'ay byay'], ['expenses', 'income and spending'],
     ['খরচ লিখতে', 'আয় লিখতে', 'মাসের খরচ দেখতে', 'খাত বদলাতে', 'ভুল খরচ মুছতে'],
     ['khoroch likhte', 'income likhte', 'masher khoroch dekhte'], ['record an expense', 'add my income', 'see this month\'s spending'],
     ['খাত ধরে খরচ দেখা', 'হাতে কত আছে দেখা'])
feat('ledger', 'হিসাব › ধার-দেনা', 'কে কত পাবে, কাকে কত দিতে হবে; ফেরতের তারিখে মনে করায়; এক চাপে তাগাদার মেসেজ।',
     ['ধার-দেনা', 'লেনদেন', 'বাকির খাতা', 'পাওনা দেনার হিসাব'], ['dhar dena', 'baki khata'], ['loans', 'who owes me'],
     ['ধার দেওয়া লিখতে', 'কারো কাছে কত পাব দেখতে', 'ধার শোধ লিখতে', 'তাগাদা পাঠাতে'],
     ['dhar likhte', 'ke koto pabe dekhte'], ['record a loan', 'see who owes me', 'mark a loan paid'],
     ['কে কত টাকা পাবে মনে রাখা', 'ধার ফেরতের দিনে মনে করানো'])
feat('projects', 'হিসাব › অন্যান্য হিসাব', 'প্রতিটা কাজের (বাড়ি, বিয়ে, কোচিং) আলাদা আয়, খরচ আর বকেয়া।',
     ['অন্যান্য হিসাব', 'আলাদা হিসাব', 'প্রজেক্ট'], ['alada hisab', 'project'], ['separate accounts', 'projects'],
     ['আলাদা হিসাব খুলতে', 'বাড়ির কাজের খরচ আলাদা রাখতে'], ['alada hisab khulte'], ['keep a separate account for a project'],
     ['বিয়ের খরচ আলাদা রাখা', 'বাড়ি বানানোর হিসাব আলাদা রাখা'])
feat('accounts', 'হিসাব › অ্যাকাউন্ট', 'হাতের টাকা, বিকাশ, নগদ, ব্যাংক — কোথায় কত আছে, এক জায়গা থেকে আরেক জায়গায় পাঠানো।',
     ['অ্যাকাউন্ট', 'বিকাশের হিসাব', 'ব্যাংকের হিসাব'], ['account', 'bkash er hisab'], ['accounts', 'wallets'],
     ['বিকাশে কত আছে দেখতে', 'নতুন অ্যাকাউন্ট যোগ করতে', 'এক অ্যাকাউন্ট থেকে আরেকটায় টাকা সরাতে'], ['bkash e koto ache dekhte'], ['add a bank account', 'move money between accounts'],
     ['বিকাশ আর ব্যাংক আলাদা রাখা'])
feat('savings', 'হিসাব › সঞ্চয় ও কিস্তি', 'সঞ্চয়ের লক্ষ্য, কিস্তি আর DPS-এর হিসাব, দেওয়ার দিনে মনে করানো।',
     ['সঞ্চয়ের হিসাব', 'কিস্তির হিসাব', 'ডিপিএসের হিসাব'], ['kistir hisab', 'savings'], ['savings', 'installments'],
     ['কিস্তির হিসাব রাখতে', 'সঞ্চয়ের লক্ষ্য রাখতে'], ['kistir hisab rakhte'], ['track my installments', 'set a savings goal'],
     ['কিস্তির দিনে মনে করানো', 'ডিপিএসের হিসাব রাখা'])
feat('report', 'হিসাব › মাসের রিপোর্ট', 'মাসের আয়, খরচ, ব্যালেন্স; কোন খাতে বেশি গেল, গত মাসের সাথে তুলনা।',
     ['মাসের রিপোর্ট', 'রিপোর্ট'], ['report', 'masher report'], ['the monthly report'],
     ['মাসের রিপোর্ট দেখতে', 'গত মাসের সাথে মেলাতে'], ['report dekhte'], ['see my monthly report'],
     ['গত মাসের সাথে তুলনা দেখা'])
feat('spending', 'হিসাব › খরচ বিশ্লেষণ', 'আয়ের কত ভাগ কোন খাতে গেল — প্রয়োজন, শখ, সঞ্চয়; কোথায় কমানো যায়।',
     ['খরচ বিশ্লেষণ', 'খরচের ভাগ', 'অপচয়ের হিসাব'], ['khoroch bishleshon'], ['spending analysis'],
     ['অপ্রয়োজনীয় খরচ বের করতে', 'কোথায় খরচ কমানো যায় দেখতে'], ['baje khoroch ber korte'], ['find where I overspend'],
     ['অপচয় ধরা'])
feat('zakat', 'আরও › যাকাত', 'টাকা, ধার-দেনা, সঞ্চয়, সোনা-রুপা আর ব্যবসা ধরে যাকাতের হিসাব; আজকের ভরির দাম নিজে আনে।',
     ['যাকাত', 'যাকাতের হিসাব', 'জাকাত'], ['zakat', 'jakat'], ['zakat', 'zakat calculator'],
     ['যাকাত হিসাব করতে', 'সোনার ওজন দিতে', 'আজকের সোনার দাম বসাতে'], ['zakat hisab korte', 'sonar dam boshate'], ['calculate my zakat', 'add my gold'],
     ['সোনা-রুপার দামসহ যাকাত হিসাব', 'ব্যবসার মাল যাকাতে ধরা'])
feat('split', 'হিসাব › খরচ ভাগাভাগি', 'কয়েকজনের খরচ ভাগ করে কে কাকে কত দেবে।',
     ['খরচ ভাগাভাগি', 'ভাগাভাগি'], ['khoroch bhag', 'split'], ['split bills', 'splitting costs'],
     ['বন্ধুদের সাথে খরচ ভাগ করতে', 'পিকনিকের খরচ ভাগ করতে'], ['picnic er khoroch bhag korte'], ['split a bill with friends'],
     ['কে কাকে কত দেবে হিসাব'])
feat('shop', 'হিসাব › দোকান', 'ছোট দোকানের নাম, নম্বর; বিক্রি, খরচ, কাস্টমারের বাকি আর রসিদ।',
     ['দোকানের হিসাব', 'দোকানের পাতা'], ['dokaner hisab'], ['my shop', 'shop accounts'],
     ['দোকানের বিক্রি লিখতে', 'রসিদ দিতে'], ['dokaner bikri likhte'], ['record shop sales', 'give a receipt'],
     ['দোকানের হিসাব রাখা'])
# ── ব্যবসায়ী মোড ──
feat('business', 'আরও › ব্যবসায়ী মোড', 'দোকান চালানোর আলাদা মোড (প্রিমিয়াম): হোম, বিক্রি, গ্রাহক, হিসাব, স্টক — নিজের আয়-ব্যয় থেকে আলাদা।',
     ['ব্যবসায়ী মোড', 'বিজনেস মোড', 'ব্যবসার মোড'], ['business mode', 'bebsha mode'], ['business mode'],
     ['ব্যবসায়ী মোড চালু করতে', 'দোকানের হিসাব আলাদা রাখতে', 'ব্যবসা আর নিজের হিসাব আলাদা করতে'], ['business mode on korte'], ['turn on business mode', 'keep shop money apart'],
     ['দোকান চালানোর হিসাব আলাদা রাখা', 'ব্যবসা আর সংসারের হিসাব আলাদা রাখা'])
feat('biz_sell', 'ব্যবসায়ী মোড › বিক্রি', 'পণ্য বেছে বিক্রি, ছাড় (টাকায় বা শতাংশে), নগদ/QR/বাকি; PDF রসিদ।',
     ['বিক্রির পাতা', 'নতুন বিক্রি', 'বিক্রির অপশন'], ['bikrir page', 'sale option'], ['sales', 'new sale'],
     ['বিক্রি লিখতে', 'ছাড় দিতে', 'রসিদ পাঠাতে', 'বাকিতে বিক্রি করতে'], ['bikri likhte', 'discount dite'], ['make a sale', 'give a discount', 'send a receipt'],
     ['শতাংশে ছাড় দেওয়া', 'হোয়াটসঅ্যাপে রসিদ পাঠানো'])
feat('biz_customers', 'ব্যবসায়ী মোড › গ্রাহক', 'প্রতিটা গ্রাহকের প্রোফাইল, কেনাকাটা, বাকি; বাকির রিমাইন্ডার আর হোয়াটসঅ্যাপে তাগাদা।',
     ['গ্রাহকের তালিকা', 'কাস্টমারের পাতা', 'গ্রাহকের প্রোফাইল'], ['customer list', 'grahok er list'], ['customers'],
     ['নতুন গ্রাহক যোগ করতে', 'গ্রাহকের বাকি দেখতে', 'তাগাদা পাঠাতে', 'বাকির রিমাইন্ডার দিতে'], ['customer add korte', 'baki dekhte'], ['add a customer', 'see a customer\'s dues', 'send a payment reminder'],
     ['৩০ দিনের বেশি বাকি দেখা', 'তাগাদার মেসেজ বদলানো'])
feat('biz_hisab', 'ব্যবসায়ী মোড › হিসাব', 'ব্যবসার আয়-ব্যয়, আজকের নগদ, ডিলারের কাছ থেকে মাল কেনা আর পরিশোধ।',
     ['ব্যবসার হিসাব', 'ব্যবসার আয়-ব্যয়', 'ডিলারের হিসাব'], ['business er hisab', 'dealer hisab'], ['business accounts', 'dealer accounts'],
     ['ডিলারের কাছে কত দেনা দেখতে', 'দোকানের খরচ লিখতে', 'মাল কেনা লিখতে'], ['dealer er dena dekhte'], ['see what I owe dealers', 'record a shop cost'],
     ['ডিলারের দেনা মনে রাখা', 'দোকান ভাড়া আলাদা লেখা'])
feat('biz_stock', 'ব্যবসায়ী মোড › স্টক', 'পণ্যের স্টক, কেনা-বেচার দাম, কম পড়লে অর্ডারের তালিকা; ধরন ধরে সেকশন।',
     ['স্টক', 'মালের হিসাব', 'পণ্যের তালিকা'], ['stock', 'maler hisab'], ['stock', 'inventory'],
     ['নতুন পণ্য যোগ করতে', 'স্টক দেখতে', 'কম পড়া মালের অর্ডার দিতে'], ['product add korte', 'stock dekhte'], ['add a product', 'check stock', 'reorder low items'],
     ['মাল কম পড়লে জানানো', 'বারকোড দিয়ে পণ্য খোঁজা'])
# ── সংরক্ষণ ──
feat('notes', 'সংরক্ষণ › নোট', 'যা মনে রাখতে চান; বিভাগ ধরে সাজানো, ছবি-ফাইল যোগ করা যায়।',
     ['নোট', 'নোটবুক', 'নোটের পাতা'], ['note', 'notebook'], ['notes'],
     ['নোট রাখতে', 'পুরোনো নোট খুঁজতে', 'নোটে ছবি দিতে', 'নোটের বিভাগ বদলাতে'], ['note rakhte', 'note khujte'], ['save a note', 'find an old note'],
     ['বিভাগ ধরে নোট সাজানো', 'নোটে ছবি রাখা'])
feat('will', 'সংরক্ষণ › ওছিয়তনামা', 'নিজের ওছিয়ত লিখে রাখা; উত্তরাধিকারী পরে দেখতে পান (প্রিমিয়াম)।',
     ['ওছিয়তনামা', 'ওসিয়ত', 'অসিয়তনামা'], ['osiyot', 'will'], ['my will'],
     ['ওছিয়ত লিখতে', 'উত্তরাধিকারীকে জানাতে'], ['osiyot likhte'], ['write my will'],
     ['ওছিয়ত লিখে রাখা'])
feat('docs', 'সংরক্ষণ › ডকুমেন্টস', 'NID, পাসপোর্ট, জমির কাগজ, প্রেসক্রিপশন — ফোল্ডারে, তালাবদ্ধ; পরে বলে খোঁজা যায়।',
     ['ডকুমেন্টস', 'কাগজপত্র', 'দলিলপত্র', 'কাগজের ছবি'], ['document', 'kagojpotro'], ['documents', 'my papers'],
     ['কাগজের ছবি রাখতে', 'পাসপোর্টের ছবি খুঁজতে', 'নতুন ফোল্ডার বানাতে'], ['document rakhte', 'passport er chobi khujte'], ['save a document', 'find my passport scan'],
     ['এনআইডির ছবি রাখা', 'জমির দলিল তালাবদ্ধ রাখা'])
feat('vault', 'সংরক্ষণ › পাসওয়ার্ড ভল্ট', 'ফেসবুক, জিমেইল, বিকাশ, Wi-Fi-এর পাসওয়ার্ড; দেখতে আঙুলের ছাপ বা PIN লাগে, কখনো জোরে পড়া হয় না।',
     ['পাসওয়ার্ড ভল্ট', 'ভল্ট', 'পাসওয়ার্ডের জায়গা'], ['vault', 'password vault'], ['the password vault', 'passwords'],
     ['পাসওয়ার্ড রাখতে', 'পাসওয়ার্ড দেখতে', 'ওয়াইফাই পাসওয়ার্ড রাখতে'], ['password rakhte', 'password dekhte'], ['save a password', 'see a saved password'],
     ['আঙুলের ছাপ দিয়ে পাসওয়ার্ড খোলা', 'পাসওয়ার্ড গোপন রাখা'])
feat('contacts', 'সংরক্ষণ › যোগাযোগ', 'নাম বললেই ফোন, SMS বা WhatsApp; নম্বর, ঠিকানা আর কাগজ একসাথে।',
     ['যোগাযোগ', 'কন্টাক্ট', 'ফোনবুক', 'নম্বরের তালিকা'], ['contact', 'phonebook'], ['contacts', 'phone book'],
     ['নম্বর রাখতে', 'নাম বলে ফোন দিতে', 'ফোনবুক থেকে নম্বর আনতে'], ['number save korte', 'nam bole phone dite'], ['save a number', 'call someone by name'],
     ['নাম বললে ফোন করা', 'হোয়াটসঅ্যাপে মেসেজ পাঠানো'])
feat('health', 'সংরক্ষণ › স্বাস্থ্য', 'BMI, প্রেশার, সুগার, ওজন — গ্রাফসহ; শিশুর টিকার কার্ড; ডাক্তারকে দেখানোর সারাংশ।',
     ['স্বাস্থ্যের পাতা', 'হেলথ অপশন', 'প্রেশারের হিসাব', 'সুগারের হিসাব'], ['health option', 'pressure hisab'], ['health', 'health records'],
     ['প্রেশার লিখতে', 'ওজন লিখতে', 'বিএমআই দেখতে', 'শিশুর টিকার কার্ড রাখতে'], ['pressure likhte', 'ojon likhte'], ['log my blood pressure', 'check my BMI'],
     ['প্রেশারের গ্রাফ দেখা', 'পরিবারের স্বাস্থ্য আলাদা রাখা'])
feat('emergency', 'সংরক্ষণ › জরুরি', 'রক্তের গ্রুপ, জরুরি নম্বর (৯৯৯, ফায়ার সার্ভিস), ওষুধ আর অ্যালার্জি।',
     ['জরুরি কার্ড', 'জরুরি নম্বর', 'ইমার্জেন্সি'], ['emergency'], ['emergency info', 'emergency numbers'],
     ['জরুরি নম্বর দেখতে', 'রক্তের গ্রুপ রাখতে'], ['emergency number dekhte'], ['see emergency numbers'],
     ['৯৯৯-এ ফোন দেওয়া'])
feat('expiry', 'সংরক্ষণ › কাগজের মেয়াদ', 'পাসপোর্ট, লাইসেন্স, ট্যাক্স টোকেনের মেয়াদ শেষের আগে মনে করায়।',
     ['কাগজের মেয়াদ', 'মেয়াদ শেষের রিমাইন্ডার'], ['meyad'], ['document expiry'],
     ['পাসপোর্টের মেয়াদ মনে রাখতে', 'লাইসেন্সের মেয়াদ দিতে'], ['passport er meyad rakhte'], ['track passport expiry'],
     ['মেয়াদ শেষের আগে জানানো'])
feat('tags', 'সংরক্ষণ › ট্যাগ', 'এক ট্যাগে নোট, কাগজ, কাজ সব একসাথে।',
     ['ট্যাগ'], ['tag'], ['tags'],
     ['ট্যাগ দিতে', 'এক ট্যাগের সব দেখতে'], ['tag dite'], ['tag things together'],
     ['একই বিষয়ের সব এক জায়গায় দেখা'])
feat('memory', 'আরও › আমার সম্পর্কে', 'আপনার সম্পর্কে যা বলেছেন (অভ্যাস, পছন্দ, সম্পর্ক) — উত্তরে কাজে লাগে।',
     ['আমার সম্পর্কে', 'মনে রাখা কথা'], ['amar shomporke'], ['about me', 'what you remember about me'],
     ['নিজের কথা মনে রাখাতে', 'যা মনে রেখেছে দেখতে'], ['amar kotha mone rakhte'], ['tell you about myself'],
     ['আমার পছন্দ মনে রাখা'])
feat('requests', 'সংরক্ষণ › ব্লাড ডোনেশন', 'রক্ত দরকার হলে অনুরোধ — জেলার যাঁদের গ্রুপ মেলে তাঁরা জানতে পান; নিজেও দাতা হওয়া যায়।',
     ['ব্লাড ডোনেশন', 'রক্তদানের অপশন', 'রক্তের অনুরোধ'], ['blood donation', 'rokto daner option'], ['blood donation', 'blood requests'],
     ['রক্তের অনুরোধ দিতে', 'রক্তদাতা হতে'], ['rokto chaite', 'donor hote'], ['ask for blood', 'register as a donor'],
     ['জেলার রক্তদাতাদের জানানো'])
feat('family', 'আরও › ফ্যামিলি', 'পরিবারের সদস্যদের যুক্ত করে কাজ, রিমাইন্ডার, নোট পাঠানো; লোকেশন আর উত্তরাধিকার (প্রিমিয়াম)।',
     ['ফ্যামিলি অপশন', 'পরিবারের পাতা', 'ফ্যামিলি'], ['family option'], ['family', 'family sharing'],
     ['পরিবারের কাউকে যুক্ত করতে', 'ছেলেকে কাজ পাঠাতে', 'আম্মুকে ওষুধের রিমাইন্ডার পাঠাতে'], ['family add korte'], ['add a family member', 'send a task to my son'],
     ['পরিবারকে রিমাইন্ডার পাঠানো', 'উত্তরাধিকারীকে ব্যাকআপ দেওয়া'])
feat('search', 'সংরক্ষণ › বলে খুঁজুন', 'নোট, কাগজ, নম্বর, লেনদেন — সব জায়গায় একসাথে খোঁজা।',
     ['খোঁজার পাতা', 'সার্চ'], ['search'], ['search'],
     ['কিছু খুঁজতে', 'কোথায় কী রেখেছি খুঁজতে'], ['kichu khujte'], ['search everything'],
     ['সব জায়গায় একসাথে খোঁজা'])
# ── আরও ──
feat('settings', 'আরও › সেটিংস', 'নাম, জেলা, ভাষা, থিম ও নিজের রং, সহজ মোড, তালা, ব্যাকআপ, মতামত পাঠানো।',
     ['সেটিংস', 'সেটিং'], ['settings', 'setting'], ['settings'],
     ['ভাষা বদলাতে', 'রং বদলাতে', 'ডার্ক মোড চালু করতে', 'অক্ষর বড় করতে', 'নাম বদলাতে', 'সহজ মোড চালু করতে'],
     ['language change korte', 'dark mode dite'], ['change the language', 'turn on dark mode', 'make the text bigger'],
     ['অক্ষর বড় করা', 'ইংরেজিতে চালানো', 'নিজের রং বেছে নেওয়া'])
feat('notifications', 'আরও › নোটিফিকেশন', 'কোন বার্তা আসবে, রাতে চুপ থাকা, দিনে কয়টা।',
     ['নোটিফিকেশন', 'বিজ্ঞপ্তি'], ['notification'], ['notifications'],
     ['নোটিফিকেশন কমাতে', 'রাতে নোটিফিকেশন বন্ধ রাখতে'], ['notification bondho korte'], ['turn off notifications at night'],
     ['রাতে চুপ থাকা'])
feat('sound', 'আরও › রিংটোন', 'রিমাইন্ডার আর অ্যালার্মের শব্দ।',
     ['রিংটোন', 'সাউন্ড'], ['ringtone'], ['the ringtone', 'reminder sound'],
     ['রিংটোন বদলাতে'], ['ringtone bodlate'], ['change the reminder sound'],
     ['নিজের গান রিংটোন করা'])
feat('trash', 'আরও › রিসাইকেল বিন', 'যা মুছেছেন, ৩০ দিন থাকে; সেখান থেকে ফিরিয়ে আনা যায়।',
     ['রিসাইকেল বিন', 'মুছে ফেলা জিনিস', 'ট্র্যাশ'], ['recycle bin', 'trash'], ['the recycle bin', 'deleted items'],
     ['মুছে ফেলা জিনিস ফেরত আনতে', 'ভুল করে মোছা কাজ ফেরাতে'], ['delete kora jinish ferot ante'], ['restore something I deleted'],
     ['মুছে ফেলা জিনিস ফেরত আনা'])
feat('backup', 'আরও › ব্যাকআপ', 'সব তথ্য তালাবদ্ধ হয়ে নিজের Google Drive-এ বা ফাইলে; নতুন ফোনে সব ফিরে আসে।',
     ['ব্যাকআপ', 'গুগল ড্রাইভ ব্যাকআপ'], ['backup', 'drive backup'], ['backup', 'Google Drive backup'],
     ['ব্যাকআপ নিতে', 'নতুন ফোনে তথ্য ফেরাতে', 'অটো ব্যাকআপ চালু করতে'], ['backup nite', 'notun phone e data ante'], ['back up my data', 'restore on a new phone'],
     ['ফোন হারালে সব ফেরত পাওয়া', 'গুগল ড্রাইভে ব্যাকআপ রাখা'])
feat('pro', 'আরও › প্রিমিয়াম', 'যত খুশি রিমাইন্ডার, ডকুমেন্ট, পাসওয়ার্ড; অন্যান্য হিসাব, ওছিয়তনামা, ব্যবসায়ী মোড, অটো ব্যাকআপ, PDF — বিজ্ঞাপন ছাড়া।',
     ['প্রিমিয়াম', 'প্রিমিয়াম ভার্সন', 'সাবস্ক্রিপশন'], ['premium', 'pro version'], ['premium', 'the subscription'],
     ['প্রিমিয়াম নিতে', 'বিকাশে প্রিমিয়ামের টাকা দিতে', 'বিজ্ঞাপন বন্ধ করতে'], ['premium nite', 'bkash e payment korte'], ['buy premium', 'remove ads'],
     ['বিজ্ঞাপন ছাড়া চালানো', 'বিকাশে প্রিমিয়াম কেনা'])
feat('pdf', 'আরও › PDF', 'যা যা চান বেছে নিয়ে এক PDF-এ — ডাউনলোড, শেয়ার বা প্রিন্ট (প্রিমিয়াম)।',
     ['পিডিএফ', 'সব তথ্যের পিডিএফ'], ['pdf'], ['a PDF export'],
     ['হিসাবের পিডিএফ বানাতে', 'সব তথ্য প্রিন্ট করতে'], ['pdf banate'], ['export to PDF', 'print my records'],
     ['হিসাব পিডিএফ করে পাঠানো'])
feat('help', 'আরও › কী কী করা যায়', 'অ্যাপের সব সুবিধা আর কী বললে কী হয়।',
     ['এই অ্যাপ', 'অ্যাপটা', 'মাই অ্যাসিস্ট্যান্ট'], ['ei app', 'app ta'], ['this app', 'My Assistant'],
     ['অ্যাপটা চালাতে', 'কথা বলে কাজ করাতে', 'শুরু করতে'], ['app ta chalate'], ['use this app', 'get started'],
     ['কথা বলে সব করা', 'ইন্টারনেট ছাড়া চালানো'])


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, 'app_features.json'), 'w') as f:
        json.dump(F, f, ensure_ascii=False, indent=1)
    root = os.path.abspath(os.path.join(here, '..', '..', '..'))
    lines = ['# অ্যাপের মানচিত্র — মেনু, সেকশন, ফিচার আর তার উদ্দেশ্য', '',
             'মডেলকে শেখানোর জন্য (tool/nlu/spec/app_features.py থেকে বানানো)। প্রতিটা ফিচারের নাম মানুষ যেভাবে বলে, আর তা দিয়ে যা করতে চায়।', '']
    menu = None
    for x in sorted(F, key=lambda x: x['menu'].split(' › ')[0]):
        m = x['menu'].split(' › ')[0]
        if m != menu:
            lines += ['', f'## {m}', '']
            menu = m
        lines.append(f"- **{x['menu']}** — {x['purpose']}  ")
        lines.append(f"  কাজে লাগে: {', '.join(x['acts'])}")
    with open(os.path.join(root, 'docs', 'app-feature-map.md'), 'w') as f:
        f.write('\n'.join(lines) + '\n')
    print(len(F), 'features')


if __name__ == '__main__':
    main()
