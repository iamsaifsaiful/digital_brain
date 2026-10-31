"""Privacy policy and terms pages, ready for an Elementor HTML widget.
Writes <slug>-elementor.html (Google Fonts) and <slug>-preview.html (local fonts)."""
import base64, os, re

D = os.path.dirname(os.path.abspath(__file__)) + '/'
MAIL = 'info@getmyassistant.app'
DATE = '১ নভেম্বর ২০২৬'
PRIV, TERMS = '/privacy/', '/terms-and-conditions/'

svg = re.sub(r'<\?xml[^>]*>\s*', '', open(D + 'img/icon.svg', encoding='utf-8').read())
ICON = 'data:image/svg+xml;base64,' + base64.b64encode(svg.encode()).decode()

CSS = """
.ma-lg{--g:#0B6B55;--gd:#084D3D;--gt:#E6F2EE;--ink:#10201B;--mut:#4A5752;--line:#DDE5E1;--ground:#F4F6F5;--amber:#F5B83D;
  background:#fff;color:var(--ink);font-family:'Noto Sans Bengali',sans-serif;font-size:16px;line-height:1.5;text-align:left}
.ma-lg,.ma-lg *{box-sizing:border-box}
.ma-lg h1,.ma-lg h2,.ma-lg h3{font-family:'Anek Bangla','Noto Sans Bengali',sans-serif;color:inherit;text-transform:none;margin:0;padding:0;border:0;letter-spacing:0}
.ma-lg p,.ma-lg ul,.ma-lg ol{margin:0;padding:0}
.ma-lg a{color:inherit;text-decoration:none;box-shadow:none}
.ma-lg img{border:0;box-shadow:none;border-radius:0;max-width:100%}
.ma-lg .wrap{max-width:1040px;margin:0 auto;padding:0 40px}
.ma-lg nav{border-bottom:1px solid var(--line);background:#fff}
.ma-lg nav .wrap{display:flex;align-items:center;gap:20px;height:72px}
.ma-lg .brand{display:flex;align-items:center;gap:12px;font-family:'Anek Bangla','Noto Sans Bengali',sans-serif;font-weight:700;font-size:21px}
.ma-lg .brand img{width:38px;height:38px}
.ma-lg nav .r{margin-left:auto;display:flex;gap:22px;font-size:15.5px;color:var(--mut)}
.ma-lg nav .r a.on{color:var(--g);font-weight:600}
.ma-lg .head{background:var(--ground);padding:56px 0 44px}
.ma-lg .eyebrow{font-size:15px;font-weight:600;color:var(--g)}
.ma-lg .head h1{margin-top:8px;font-size:52px;line-height:1.1;font-weight:700;font-stretch:86%}
.ma-lg .head .lead{margin-top:14px;font-size:18.5px;line-height:1.75;color:var(--mut);max-width:720px}
.ma-lg .meta{margin-top:18px;font-size:14.5px;color:var(--mut)}
.ma-lg .body{display:grid;grid-template-columns:240px 1fr;gap:56px;padding:48px 40px 80px;align-items:start}
.ma-lg .toc{position:sticky;top:24px;font-size:14.5px;line-height:1.5}
.ma-lg .toc b{display:block;font-size:13.5px;color:var(--mut);margin-bottom:10px}
.ma-lg .toc ol{list-style:none;display:grid;gap:8px;counter-reset:t}
.ma-lg .toc li{counter-increment:t;display:grid;grid-template-columns:30px 1fr;color:var(--mut)}
.ma-lg .toc li::before{content:counter(t,bengali) ".";color:var(--g);font-weight:600}
.ma-lg .sum{background:var(--gt);border-radius:22px;padding:26px 28px;margin-bottom:40px}
.ma-lg .sum h2{font-size:24px;font-weight:700;font-stretch:90%;color:var(--gd)}
.ma-lg .sum ul{margin-top:12px;list-style:none;display:grid;gap:10px}
.ma-lg .sum li{display:grid;grid-template-columns:26px 1fr;font-size:16.5px;line-height:1.65;color:var(--gd)}
.ma-lg .sum li::before{content:"✓";font-weight:700}
.ma-lg .warn{background:#FFF6E0;border:1px solid #F3DCA2;border-radius:22px;padding:24px 28px;margin-bottom:40px}
.ma-lg .warn h2{font-size:23px;font-weight:700;font-stretch:90%;color:#6B4200}
.ma-lg .warn ul{margin-top:12px;list-style:none;display:grid;gap:10px}
.ma-lg .warn li{display:grid;grid-template-columns:26px 1fr;font-size:16.5px;line-height:1.65;color:#5A3800}
.ma-lg .warn li::before{content:"!";font-weight:700;color:#B26A00}
.ma-lg section{padding:0;margin:0 0 40px;scroll-margin-top:24px}
.ma-lg section h2{font-size:28px;font-weight:700;font-stretch:90%;line-height:1.25;display:flex;gap:12px;align-items:baseline}
.ma-lg section h2 .n{color:var(--g);font-size:22px}
.ma-lg section h3{margin-top:22px;font-size:19px;font-weight:700}
.ma-lg section p{margin-top:12px;font-size:16.5px;line-height:1.85;color:#26332F}
.ma-lg section ul{margin-top:12px;list-style:none;display:grid;gap:9px}
.ma-lg section li{position:relative;padding-left:22px;font-size:16.5px;line-height:1.75;color:#26332F}
.ma-lg section li::before{content:"";position:absolute;left:4px;top:.75em;width:7px;height:7px;border-radius:50%;background:var(--g)}
.ma-lg section li b,.ma-lg section p b{color:var(--ink)}
.ma-lg .tbl{margin-top:16px;border:1px solid var(--line);border-radius:18px;overflow:hidden}
.ma-lg .row{display:grid;grid-template-columns:200px 1fr;border-bottom:1px solid var(--line)}
.ma-lg .row:last-child{border-bottom:0}
.ma-lg .row>div{padding:14px 18px;font-size:15.5px;line-height:1.7}
.ma-lg .row>div:first-child{background:var(--ground);font-weight:600}
.ma-lg .contact{background:var(--ink);color:#fff;border-radius:22px;padding:28px}
.ma-lg .contact h2{font-size:26px;font-weight:700;font-stretch:90%}
.ma-lg .contact p{margin-top:8px;color:#B9C6C1;font-size:16px;line-height:1.7}
.ma-lg .contact a.mail{display:inline-block;margin-top:14px;background:#fff;color:var(--gd);border-radius:999px;padding:11px 22px;font-weight:700}
.ma-lg footer{border-top:1px solid var(--line);padding:30px 0;font-size:14.5px;color:var(--mut)}
.ma-lg footer .wrap{display:flex;gap:22px;align-items:center;flex-wrap:wrap}
.ma-lg footer .r{margin-left:auto;display:flex;gap:22px;flex-wrap:wrap}
@media (max-width:760px){
  .ma-lg .wrap{padding:0 16px}
  .ma-lg nav .r{display:none}
  .ma-lg .head{padding:36px 0 30px}
  .ma-lg .head h1{font-size:36px}
  .ma-lg .head .lead{font-size:17px}
  .ma-lg .body{grid-template-columns:1fr;gap:28px;padding:28px 16px 56px}
  .ma-lg .toc{position:static;background:var(--ground);border-radius:18px;padding:18px}
  .ma-lg .sum,.ma-lg .warn,.ma-lg .contact{padding:20px}
  .ma-lg section h2{font-size:23px}
  .ma-lg .row{grid-template-columns:1fr}
  .ma-lg footer .r{margin-left:0}
}
"""

# ---------------------------------------------------------------- content
PRIVACY = dict(
    slug='privacy-policy', title='গোপনীয়তা নীতি', eyebrow='আপনার তথ্য, আপনার কাছে',
    lead='একজন ভালো সহকারী আপনার কথা বাইরে বলে না। My Assistant কোন তথ্য ফোনে রাখে, কোনটা আমাদের সার্ভারে আসে, আর কেন — সব এখানে সহজ ভাষায় লেখা।',
    box=('sum', 'সংক্ষেপে', [
        'আপনার হিসাব, লেনদেন, নোট, ডকুমেন্ট, পাসওয়ার্ড আর স্বাস্থ্যের তথ্য আপনার ফোনেই এনক্রিপ্ট করে রাখা থাকে — আমাদের সার্ভারে আসে না।',
        'সার্ভারে থাকে শুধু আপনার অ্যাকাউন্ট, প্রিমিয়াম-র মেয়াদ, পেমেন্টের তথ্য, আর আপনি নিজে চালু করলে রক্তদানের তথ্য।',
        'পাসওয়ার্ড, PIN, OTP আর অন্য অ্যাপের মেসেজ কখনো AI-তে যায় না।',
        'আমরা আপনার তথ্য কারো কাছে বিক্রি করি না।',
    ]),
    sections=[
        ('ফোনে যে তথ্য থাকে', '''
<p>অ্যাপে যা রাখেন, তার প্রায় সবই শুধু আপনার ফোনে থাকে:</p>
<ul>
<li>আয়-ব্যয়, ধার-দেনা, দোকান ও অন্যান্য হিসাব</li>
<li>কাজের তালিকা, রিমাইন্ডার, অ্যালার্ম, নোট ও ডায়েরি</li>
<li>ডকুমেন্টের ছবি (NID, পাসপোর্ট ইত্যাদি) আর পাসওয়ার্ড ভল্ট</li>
<li>পরিবারের স্বাস্থ্যের তথ্য — প্রেশার, সুগার, ওষুধ, শিশুর টিকা</li>
<li>অ্যাপে রাখা যোগাযোগের নম্বর</li>
</ul>
<p>এই তথ্য ফোনে <b>এনক্রিপ্ট করা</b> অবস্থায় থাকে, আর অ্যাপ খুলতে PIN বা আঙুলের ছাপ লাগে। আঙুলের ছাপ ফোনের নিজস্ব ব্যবস্থায় যাচাই হয় — আমরা আপনার আঙুলের ছাপ কখনো পাই না।</p>'''),
        ('আমাদের সার্ভারে যে তথ্য আসে', f'''
<p>কিছু সুবিধা চালাতে সামান্য তথ্য আমাদের সার্ভারে (getmyassistant.app) রাখতে হয়:</p>
<div class="tbl">
<div class="row"><div>অ্যাকাউন্ট</div><div>Google দিয়ে লগইন করলে আপনার নাম, ইমেইল, প্রোফাইল ছবির লিংক ও Google অ্যাকাউন্ট আইডি; অ্যাপের সংস্করণ আর শেষ কবে অ্যাপ খুলেছেন।</div></div>
<div class="row"><div>প্রিমিয়াম ও পেমেন্ট</div><div>কোন প্ল্যান, প্রিমিয়াম-র মেয়াদ, আর পেমেন্ট জমা দেওয়ার সময় আপনি যা দেন — যে নম্বর থেকে টাকা পাঠিয়েছেন, ট্রানজেকশন আইডি, ইমেইল, নাম, মোবাইল ও নোট।</div></div>
<div class="row"><div>নোটিফিকেশন</div><div>ফোনে খবর পাঠানোর জন্য একটা নোটিফিকেশন টোকেন (যেমন প্রিমিয়াম চালু হলে বা রক্তের অনুরোধ এলে)।</div></div>
<div class="row"><div>AI ব্যবহার</div><div>দিনে কয়টা প্রশ্ন করেছেন, সেই সংখ্যা — সীমা মানার জন্য। আপনি কী জিজ্ঞেস করেছেন, তা আমরা রাখি না।</div></div>
<div class="row"><div>মতামত ও অনুরোধ</div><div>অ্যাপ থেকে আমাদের যা লেখেন, আর যে ফাইল বা ছবি সাথে দেন।</div></div>
<div class="row"><div>রক্তদান (নিজে চালু করলে)</div><div>রক্তের গ্রুপ, জেলা, শেষ রক্তদানের তারিখ ও ফোন নম্বর। রক্তের অনুরোধ দিলে রোগীর নাম, হাসপাতাল, কত ব্যাগ, কবে লাগবে ও যোগাযোগের নম্বর।</div></div>
</div>
<p>আপনার হিসাব, নোট, ডকুমেন্ট, পাসওয়ার্ড বা স্বাস্থ্যের তথ্য এই তালিকায় নেই — সেগুলো সার্ভারে আসে না।</p>'''),
        ('AI সহকারী', '''
<p>প্রিমিয়াম-তে লম্বা বা এলোমেলো কথা বুঝতে AI সাহায্য করে। তখন আপনার বলা বা লেখা কথাটুকু আমাদের সার্ভার হয়ে <b>Anthropic</b>-এর Claude AI-এর কাছে যায়, শুধু উত্তর তৈরির জন্য। আমাদের সার্ভার সেই লেখা জমা রাখে না। Anthropic নিজের নীতি অনুযায়ী তা প্রক্রিয়া করে।</p>
<ul>
<li>পাসওয়ার্ড, PIN, OTP, ভল্টের তথ্য আর অন্য অ্যাপের মেসেজ <b>কখনো</b> AI-তে পাঠানো হয় না, জোরে পড়েও শোনানো হয় না।</li>
<li>টাকার হিসাব অ্যাপ নিজে আপনার রাখা তথ্য থেকে গুনে বলে — AI টাকার অঙ্ক বানিয়ে বলে না।</li>
<li>AI-কে দেওয়ার চাবি (API key) অ্যাপের ভেতরে থাকে না, শুধু আমাদের সার্ভারে থাকে।</li>
</ul>'''),
        ('কণ্ঠস্বর ও মাইক্রোফোন', '''
<p>মাইক্রোফোন চালু হয় শুধু যখন আপনি কথা বলার বোতাম চাপেন। কথাকে লেখায় রূপান্তর করে আপনার ফোনের নিজস্ব কথা চেনার ব্যবস্থা (বেশির ভাগ ফোনে Google-এর)। আপনার কণ্ঠের রেকর্ডিং আমরা পাই না, রাখিও না। অ্যাপ যা পড়ে শোনায়, তা ফোনেই তৈরি হয়।</p>'''),
        ('Google Drive-এ ব্যাকআপ', '''
<p>ব্যাকআপ যায় <b>আপনার নিজের</b> Google Drive-এ, এনক্রিপ্ট করা অবস্থায়। তালার চাবি তৈরি হয় আমাদের সার্ভারে আর দেওয়া হয় শুধু আপনার লগইন করা ফোনকে; ব্যাকআপ ফাইল কখনো আমাদের সার্ভারে আসে না। তাই Google বা আমরা কেউ একা আপনার ব্যাকআপ খুলতে পারি না। নতুন ফোনে একই Google অ্যাকাউন্টে লগইন করলে সব ফিরে আসে।</p>'''),
        ('অ্যাপ যে অনুমতি চায়', '''
<ul>
<li><b>মাইক্রোফোন</b> — মুখে বলে কাজ করাতে।</li>
<li><b>কন্টাক্টস</b> — “রহিমকে ফোন দাও” বললে নম্বর খুঁজতে। কন্টাক্টস ফোনেই থাকে, সার্ভারে যায় না।</li>
<li><b>নোটিফিকেশন, অ্যালার্ম ও ফোন চালু হলে চালু হওয়া</b> — রিমাইন্ডার আর অ্যালার্ম ঠিক সময়ে বাজাতে, ফোন রিস্টার্টের পরেও।</li>
<li><b>আঙুলের ছাপ</b> — অ্যাপ খোলার তালা হিসেবে।</li>
<li><b>ছবি ও ফাইল</b> — আপনি ডকুমেন্ট বা রসিদ রাখতে চাইলে।</li>
<li><b>ইন্টারনেট</b> — লগইন, ব্যাকআপ, AI আর রক্তদানের জন্য।</li>
</ul>
<p>কোনো অনুমতি না দিলেও অ্যাপের বাকি অংশ চলে; শুধু সেই সুবিধাটা বন্ধ থাকে।</p>'''),
        ('বিজ্ঞাপন', '''
<p>ফ্রি সংস্করণে Google-এর বিজ্ঞাপন দেখানো হতে পারে। Google তাদের নিজস্ব নীতি অনুযায়ী বিজ্ঞাপন দেখাতে আপনার ফোনের বিজ্ঞাপন আইডি ও সাধারণ ব্যবহারের তথ্য ব্যবহার করতে পারে। আপনার হিসাব, নোট বা অ্যাপে রাখা কোনো তথ্য বিজ্ঞাপনদাতাকে দেওয়া হয় না। প্রিমিয়াম-তে কোনো বিজ্ঞাপন নেই।</p>'''),
        ('যাদের সাথে তথ্য ভাগ হয়', '''
<p>আমরা আপনার তথ্য বিক্রি করি না, ভাড়াও দিই না। শুধু সেবা চালাতে এই প্রতিষ্ঠানগুলো তাদের অংশটুকু পায়:</p>
<ul>
<li><b>Google</b> — লগইন, Google Drive ব্যাকআপ, নোটিফিকেশন পাঠানো ও বিজ্ঞাপন।</li>
<li><b>Anthropic</b> — প্রিমিয়াম-র AI সহকারীর উত্তর তৈরি।</li>
<li><b>রক্তদাতা ও গ্রহীতা</b> — রক্তের অনুরোধে কেউ রাজি হলে কেবল তখনই দুজন দুজনের নম্বর দেখেন।</li>
</ul>
<p>আইন অনুযায়ী বাধ্য হলে আমরা প্রয়োজনীয় তথ্য কর্তৃপক্ষকে দিতে পারি।</p>'''),
        ('কতদিন রাখি, কীভাবে মুছবেন', f'''
<ul>
<li><b>ফোনের তথ্য</b> — অ্যাপের ভেতরেই মুছতে পারেন। ভুল করে মুছলে ৩০ দিন “মুছে ফেলা” থেকে ফেরত আনা যায়, তারপর নিজে থেকে চিরতরে মুছে যায়। অ্যাপ আনইনস্টল করলে ফোনের সব তথ্য মুছে যায়।</li>
<li><b>Google Drive-এর ব্যাকআপ</b> — আপনার Drive থেকে আপনি নিজেই মুছতে পারেন।</li>
<li><b>রক্তদানের তথ্য</b> — রক্তদাতা হওয়া বন্ধ করলে আপনার তথ্য তালিকা থেকে সরে যায়।</li>
<li><b>অ্যাকাউন্ট</b> — পুরো অ্যাকাউন্ট মুছতে আপনার Google ইমেইল থেকে <a href="mailto:{MAIL}"><b>{MAIL}</b></a>-এ লিখুন। আমরা ৩০ দিনের মধ্যে অ্যাকাউন্টের তথ্য মুছে দিই। পেমেন্টের রেকর্ড হিসাবের প্রয়োজনে রাখা হতে পারে।</li>
</ul>'''),
        ('নিরাপত্তা', '''
<p>অ্যাপ আর সার্ভারের মধ্যে সব যোগাযোগ HTTPS-এ এনক্রিপ্ট করা। সার্ভারে লগইন সেশনের আসল চাবি রাখা হয় না, শুধু তার হ্যাশ। পেমেন্ট ফর্মে একই ট্রানজেকশন আইডি দুবার জমা দেওয়া যায় না। আমরা কখনো আপনার বিকাশের PIN, OTP বা Google পাসওয়ার্ড চাই না — কেউ আমাদের নামে চাইলে দেবেন না।</p>
<p>তবু ইন্টারনেটে কোনো ব্যবস্থাই শতভাগ নিরাপদ নয়। আপনার ফোনের লক আর অ্যাপের PIN গোপন রাখুন।</p>'''),
        ('শিশুদের গোপনীয়তা', '''
<p>অ্যাপটি ১৩ বছরের কম বয়সীদের জন্য তৈরি নয়, আর আমরা জেনেশুনে তাদের তথ্য নিই না। শিশুর টিকার কার্ড বাবা-মা নিজের ফোনে রাখেন — সেই তথ্য ফোনেই থাকে।</p>'''),
        ('নীতিতে পরিবর্তন', '''
<p>প্রয়োজনে এই নীতি বদলাতে পারে। বড় কোনো পরিবর্তন হলে অ্যাপে বা এই পাতায় জানানো হবে, আর ওপরে “সর্বশেষ হালনাগাদ” তারিখ বদলাবে।</p>'''),
    ],
)

TERMS_PAGE = dict(
    slug='terms-and-conditions', title='শর্তাবলি', eyebrow='ব্যবহারের নিয়ম',
    lead='My Assistant ব্যবহার করলে বা প্রিমিয়াম কিনলে আপনি নিচের শর্তগুলো মেনে নিচ্ছেন। পড়ে নিন — বিশেষ করে টাকা ফেরত আর ডিভাইসের নিয়ম।',
    box=('warn', 'আগে জেনে নিন', [
        'প্রিমিয়াম কেনার পর <b>কোনো অবস্থাতেই টাকা ফেরত দেওয়া হয় না।</b>',
        'একটা Google অ্যাকাউন্ট (Gmail) দিয়ে <b>একই সময়ে একটাই ফোনে</b> লগইন করা যায়।',
        'একাধিক ফোনে একসাথে লগইন বা অ্যাকাউন্ট শেয়ার করলে <b>অ্যাকাউন্ট ব্যান হয়ে যায়</b>, টাকা ফেরত ছাড়া।',
        'ভুয়া বা অন্যের ট্রানজেকশন আইডি দিলে প্রিমিয়াম বাতিল ও অ্যাকাউন্ট বন্ধ হয়।',
    ]),
    sections=[
        ('শর্ত মেনে নেওয়া', '''
<p>অ্যাপ ইনস্টল, লগইন বা প্রিমিয়াম কেনার মাধ্যমে আপনি এই শর্তাবলি আর আমাদের <a href="/privacy/"><b>গোপনীয়তা নীতি</b></a> মেনে নিচ্ছেন। না মানলে অ্যাপটি ব্যবহার করবেন না।</p>'''),
        ('সেবা কী, আর কী নয়', '''
<p>My Assistant একটি ব্যক্তিগত সহকারী অ্যাপ — মুখে বলে বা লিখে হিসাব, কাজ, রিমাইন্ডার, নোট, ডকুমেন্ট আর পরিবারের স্বাস্থ্যের তথ্য গুছিয়ে রাখতে সাহায্য করে।</p>
<ul>
<li>সহকারী কথা বুঝতে ভুল করতে পারে। গুরুত্বপূর্ণ হিসাব, ওষুধের মাত্রা বা সময় নিজে একবার মিলিয়ে নিন।</li>
<li>অ্যাপের কোনো তথ্য বা উত্তর <b>চিকিৎসা, আইনি বা আর্থিক পরামর্শ নয়।</b> অসুস্থতায় ডাক্তারের পরামর্শ নিন।</li>
<li>নামাজ, সেহরি-ইফতার আর সূর্যোদয়-সূর্যাস্তের সময় হিসাব করে বের করা — স্থানীয় ঘোষণার সাথে সামান্য পার্থক্য থাকতে পারে।</li>
<li>ইন্টারনেট, ফোনের সেটিংস (যেমন ব্যাটারি সেভার) বা ফোন বন্ধ থাকার কারণে রিমাইন্ডার দেরিতে বা না বাজলে তার দায় আমাদের নয়।</li>
</ul>'''),
        ('অ্যাকাউন্ট', '''
<ul>
<li>লগইন হয় আপনার Google অ্যাকাউন্ট দিয়ে। অ্যাকাউন্টের নিরাপত্তা আর সেখানে যা হয়, তার দায়িত্ব আপনার।</li>
<li>অ্যাপটি ব্যবহার করতে আপনার বয়স অন্তত ১৩ বছর হতে হবে।</li>
<li>অ্যাকাউন্ট ব্যক্তিগত — বিক্রি, ভাড়া বা হস্তান্তর করা যায় না।</li>
</ul>'''),
        ('এক অ্যাকাউন্ট, এক ফোন', '''
<p>প্রতিটি অ্যাকাউন্ট একজন মানুষের, একটি ফোনের জন্য।</p>
<ul>
<li>একই Gmail দিয়ে <b>একই সময়ে একাধিক ফোন, ট্যাবলেট বা ডিভাইসে লগইন করা যায় না।</b></li>
<li>ফোন বদলালে নতুন ফোনে লগইন করুন — আগের ফোন থেকে অ্যাকাউন্ট বের হয়ে যাবে, আর ব্যাকআপ থেকে সব তথ্য নতুন ফোনে ফিরে আসবে।</li>
<li>একসাথে একাধিক ডিভাইসে ব্যবহার, অন্যকে অ্যাকাউন্ট দেওয়া, বা এই নিয়ম এড়ানোর চেষ্টা করলে <b>অ্যাকাউন্ট সাময়িক বা স্থায়ীভাবে ব্যান করা হবে।</b> ব্যান হলে প্রিমিয়াম-র বাকি মেয়াদের কোনো টাকা ফেরত দেওয়া হয় না।</li>
</ul>'''),
        ('প্রিমিয়াম ও পেমেন্ট', '''
<ul>
<li>ওয়েবসাইট থেকে প্রিমিয়ামের দাম বার্ষিক ৳৯৯৯ (৩৬৫ দিন), বিকাশে বছরে একবার; নিজে থেকে নবায়ন হয় না, কিছু কাটে না। Google Play-র অ্যাপে Google Play-র মাধ্যমেও কেনা যায় — সেখানে দাম, নবায়ন আর বাতিল Google Play-র নিয়মে। দাম বদলাতে পারে; চলতি মেয়াদে তার প্রভাব পড়ে না।</li>
<li>ওয়েবসাইটে পেমেন্ট হয় বিকাশে, প্রিমিয়াম কিনুন পাতায় দেওয়া নম্বরে Send Money করে। অন্য নম্বরে পাঠানো টাকার দায় আমাদের নয়।</li>
<li>তথ্য জমা দিলে আমরা পেমেন্ট মিলিয়ে প্রিমিয়াম চালু করি — বেশির ভাগ সময় সাথে সাথেই। পরে যদি দেখা যায় পেমেন্ট মেলেনি, অঙ্ক কম, বা ট্রানজেকশন আইডি ভুয়া, অন্যের বা আগে ব্যবহৃত — তাহলে প্রিমিয়াম বন্ধ করা হয়।</li>
<li>ওয়েবসাইট থেকে কেনা মেয়াদ নিজে থেকে নবায়ন হয় না, আর আমরা কখনো নিজে থেকে টাকা কাটি না।</li>
<li>মেয়াদ শেষ হলে অ্যাপ ফ্রি সংস্করণে ফিরে যায়; আপনার তথ্য যেমন আছে থাকে।</li>
</ul>'''),
        ('টাকা ফেরত নেই', '''
<p><b>প্রিমিয়াম কেনার পর কোনো অবস্থাতেই টাকা ফেরত দেওয়া হয় না</b> — যেমন:</p>
<ul>
<li>মেয়াদের মাঝখানে ব্যবহার বন্ধ করলে বা একেবারেই ব্যবহার না করলে</li>
<li>ভুল প্ল্যান (মাসিক/বার্ষিক) কিনলে</li>
<li>ফোন হারালে, বদলালে বা অ্যাপ মুছে ফেললে</li>
<li>এই শর্ত ভাঙার কারণে অ্যাকাউন্ট ব্যান বা বন্ধ হলে</li>
</ul>
<p>তাই কেনার আগে ফ্রি সংস্করণ ব্যবহার করে দেখে নিন — বেশির ভাগ সুবিধা ফ্রিতেই আছে।</p>'''),
        ('যা করা যাবে না', '''
<ul>
<li>ভুয়া, অন্যের বা চুরি করা ট্রানজেকশন আইডি দিয়ে প্রিমিয়াম নেওয়া</li>
<li>রক্তদানের সুবিধায় ভুয়া অনুরোধ দেওয়া, দাতাদের হয়রানি করা, বা রক্তের বিনিময়ে টাকা চাওয়া</li>
<li>AI সহকারী দিয়ে বেআইনি, ক্ষতিকর বা অন্যকে হয়রানির কাজ করানো</li>
<li>অ্যাপ বা সার্ভার ভাঙার, কপি করার, রিভার্স ইঞ্জিনিয়ারিং বা অতিরিক্ত অনুরোধ পাঠিয়ে সেবা বাধাগ্রস্ত করার চেষ্টা</li>
<li>অ্যাপ বা এর অংশ নিজের নামে বিক্রি বা বিতরণ করা</li>
</ul>
<p>এর যেকোনোটা করলে কোনো নোটিশ ছাড়াই, টাকা ফেরত ছাড়া অ্যাকাউন্ট বন্ধ করা হতে পারে।</p>'''),
        ('রক্তদান', '''
<p>রক্তদানের সুবিধা শুধু দাতা আর গ্রহীতাকে যোগাযোগ করিয়ে দেয়। রক্তের গ্রুপ মেলানো, দাতার সুস্থতা আর রক্ত পরীক্ষা হাসপাতাল ও সংশ্লিষ্টদের দায়িত্ব। দাতা-গ্রহীতার মধ্যে যা ঘটে, তার দায় আমাদের নয়। রক্ত কেনা-বেচা সম্পূর্ণ নিষেধ।</p>'''),
        ('আপনার তথ্যের দায়িত্ব', '''
<p>আপনার বেশির ভাগ তথ্য আপনার ফোনেই থাকে। নিয়মিত Google Drive-এ ব্যাকআপ রাখুন। ব্যাকআপ না থাকা অবস্থায় ফোন হারালে, নষ্ট হলে বা অ্যাপ মুছলে তথ্য ফেরত আনা সম্ভব নাও হতে পারে — আমরা আপনার ফোনের তথ্য দেখতে বা ফিরিয়ে দিতে পারি না।</p>'''),
        ('সেবায় পরিবর্তন ও দায়ের সীমা', '''
<ul>
<li>আমরা যেকোনো সময় সুবিধা যোগ, বদল বা বন্ধ করতে পারি। প্রিমিয়াম-র কোনো মূল সুবিধা স্থায়ীভাবে বন্ধ হলে আগে জানানোর চেষ্টা করব।</li>
<li>অ্যাপটি “যেমন আছে” ভিত্তিতে দেওয়া হয়। আইনের অনুমতি সাপেক্ষে, অ্যাপ ব্যবহারের কারণে কোনো পরোক্ষ ক্ষতি, তথ্য হারানো বা আর্থিক ক্ষতির দায় আমাদের নয়।</li>
</ul>'''),
        ('প্রযোজ্য আইন', '''
<p>এই শর্তাবলি বাংলাদেশের আইন অনুযায়ী পরিচালিত হবে। কোনো বিরোধ হলে আগে আলোচনার মাধ্যমে মেটানোর চেষ্টা করা হবে।</p>'''),
        ('শর্তে পরিবর্তন', '''
<p>প্রয়োজনে এই শর্তাবলি বদলাতে পারে। পরিবর্তনের পরেও অ্যাপ ব্যবহার করলে আপনি নতুন শর্ত মেনে নিচ্ছেন বলে ধরা হবে। ওপরে “সর্বশেষ হালনাগাদ” তারিখ দেখে নিন।</p>'''),
    ],
)

BN = str.maketrans('0123456789', '০১২৩৪৫৬৭৮৯')

def page(p):
    other = (TERMS, 'শর্তাবলি') if p['slug'] == 'privacy-policy' else (PRIV, 'গোপনীয়তা নীতি')
    kind, btitle, items = p['box']
    toc = ''.join(f'<li><a href="#s{i+1}">{t}</a></li>' for i, (t, _) in enumerate(p['sections']))
    secs = ''.join(f'<section id="s{i+1}"><h2><span class="n">{str(i+1).translate(BN)}.</span>{t}</h2>{body.strip()}</section>\n'
                   for i, (t, body) in enumerate(p['sections']))
    box = f'<div class="{kind}"><h2>{btitle}</h2><ul>' + ''.join(f'<li><span>{x}</span></li>' for x in items) + '</ul></div>'
    return f'''<div class="ma-lg">
<nav><div class="wrap"><a class="brand" href="/"><img src="{ICON}" alt="">My Assistant</a>
<div class="r"><a href="/">মূল পাতা</a><a href="/buy-pro/">প্রিমিয়াম কিনুন</a><a href="{PRIV}"{' class="on"' if p['slug']=='privacy-policy' else ''}>গোপনীয়তা নীতি</a><a href="{TERMS}"{' class="on"' if p['slug']!='privacy-policy' else ''}>শর্তাবলি</a></div></div></nav>
<header class="head"><div class="wrap">
<p class="eyebrow">{p['eyebrow']}</p><h1>{p['title']}</h1><p class="lead">{p['lead']}</p>
<p class="meta">সর্বশেষ হালনাগাদ: {DATE} · My Assistant (getmyassistant.app)</p>
</div></header>
<div class="wrap body">
<aside class="toc"><b>এই পাতায়</b><ol>{toc}</ol></aside>
<main>
{box}
{secs}<div class="contact"><h2>প্রশ্ন থাকলে লিখুন</h2><p>এই {p['title']} নিয়ে কিছু জানতে চাইলে, বা আপনার তথ্য দেখতে, ঠিক করতে বা মুছতে চাইলে আমাদের ইমেইল করুন।</p><a class="mail" href="mailto:{MAIL}">{MAIL}</a></div>
</main>
</div>
<footer><div class="wrap"><span class="brand" style="font-size:17px"><img src="{ICON}" alt="" style="width:28px;height:28px">My Assistant</span><span>getmyassistant.app</span>
<div class="r"><a href="{other[0]}">{other[1]}</a><a href="mailto:{MAIL}">{MAIL}</a></div></div></footer>
</div>'''

GF = '''<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Anek+Bangla:wdth,wght@75..100,400..800&family=Noto+Sans+Bengali:wght@400;500;600;700&display=swap" rel="stylesheet">'''
LOCAL = '''<style>
@font-face{font-family:'Anek Bangla';src:url(AnekBangla.ttf);font-weight:100 900;font-stretch:75% 100%}
@font-face{font-family:'Noto Sans Bengali';src:url(NotoSansBengali-Regular.ttf);font-weight:400}
@font-face{font-family:'Noto Sans Bengali';src:url(NotoSansBengali-Medium.ttf);font-weight:500}
@font-face{font-family:'Noto Sans Bengali';src:url(NotoSansBengali-SemiBold.ttf);font-weight:600}
@font-face{font-family:'Noto Sans Bengali';src:url(NotoSansBengali-Bold.ttf);font-weight:700}
body{margin:0}
</style>'''
CSS_MIN = re.sub(r'\n\s*', '\n', CSS).strip()

for p in (PRIVACY, TERMS_PAGE):
    html = page(p)
    open(D + p['slug'] + '-elementor.html', 'w', encoding='utf-8').write(
        f'<!-- My Assistant — {p["title"]} — Elementor HTML উইজেটে পুরোটা পেস্ট করুন -->\n{GF}\n<style>\n{CSS_MIN}\n</style>\n{html}\n')
    open(D + p['slug'] + '-preview.html', 'w', encoding='utf-8').write(
        f'<!doctype html><html lang="bn"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{p["title"]}</title>{LOCAL}<style>{CSS_MIN}</style></head><body>{html}</body></html>')
    print(p['slug'], 'ok')
