<?php
/**
 * The privacy policy page ([my_assistant_privacy]) and app-ads.txt (owner,
 * 29 Oct: Google Play needs both). The policy says what the app really does
 * — keep it the same as the app (lib/…) and the Play Console's Data safety
 * form (docs/play-store.md) whenever either changes.
 */

if (!defined('ABSPATH')) {
    exit;
}

/** The date the policy last changed (shown on the page). */
const MA_PRIVACY_DATE = '2026-11-01';

add_shortcode('my_assistant_privacy', function () {
    $mail = esc_html(get_option('admin_email'));
    $date = esc_html(MA_PRIVACY_DATE);
    $del = esc_url(ma_page_with('my_assistant_delete_account'));
    return <<<HTML
<div class="ma-privacy">
<h2>My Assistant — প্রাইভেসি পলিসি</h2>
<p><em>সর্বশেষ বদল: $date · Owlgorithm Labs</em></p>

<h3>মূল কথা</h3>
<p>My Assistant আপনার তথ্য প্রথমে আপনার ফোনেই রাখে, এনক্রিপ্ট করে। পাসওয়ার্ড, ভল্ট, PIN, OTP, স্বাস্থ্য, ওষুধ, ব্যাংক কার্ড আর অন্য অ্যাপের মেসেজ কখনো ফোনের বাইরে যায় না। আমরা আপনার তথ্য বিক্রি করি না।</p>

<h3>যা ফোনেই থাকে</h3>
<ul>
<li>কাজ, রিমাইন্ডার, নোট, আয়-ব্যয়, ধার-দেনা, ডকুমেন্ট, পাসওয়ার্ড, স্বাস্থ্য, ওষুধ, ব্যাংক কার্ড — AES-256 দিয়ে এনক্রিপ্ট করা, চাবি ফোনের সুরক্ষিত জায়গায়।</li>
<li>Health Connect থেকে পড়া হাঁটা, ঘুম আর ব্যায়াম — শুধু পড়া হয়, ফোনেই থাকে।</li>
<li>কন্টাক্ট — নাম আর নম্বর দেখাতে ও ফোন করতে; কোথাও পাঠানো হয় না।</li>
<li>লোকেশন — জেলা/শহর, নামাজের সময়, কিবলা আর আবহাওয়ার জন্য ফোনেই হিসাব হয়।</li>
<li>মাইক — আপনি মাইক চাপলে কথা লেখায় রূপান্তরের জন্য ফোনের নিজের কথা-চেনার সেবা ব্যবহার হয় (ফোনের প্রস্তুতকারক বা Google-এর নিয়ম অনুযায়ী)।</li>
</ul>

<h3>যা আমাদের সার্ভারে যায়, আর কেন</h3>
<ul>
<li><strong>অ্যাকাউন্ট:</strong> Google লগইন করলে নাম, ইমেইল আর ছবি; প্রিমিয়াম আর ট্রায়ালের তারিখ। পেমেন্ট করলে নাম, ফোন নম্বর আর লেনদেন নম্বর (bKash), বা Google Play-র কেনার তথ্য।</li>
<li><strong>কথা বোঝা ও AI উত্তর:</strong> অ্যাপ প্রথমে ফোনেই বোঝার চেষ্টা করে। না বুঝলে, বা প্রিমিয়ামের AI উত্তরে, আপনার বলা বাক্য (আর AI-কে তথ্য দেখার অনুমতি দিলে কাজ, রিমাইন্ডার, নোট আর হিসাবের সারাংশ) আমাদের সার্ভার হয়ে AI সেবায় (Anthropic, Google) যায় — পাসওয়ার্ড, PIN, OTP, ফোন-কার্ড-NID নম্বর কখনো না। AI সেবা এই তথ্য উত্তর দেওয়া ছাড়া অন্য কাজে ব্যবহার করে না।</li>
<li><strong>কথা বোঝা ভালো করতে:</strong> কিছু বার্তা নাম সরিয়ে সার্ভারে যায় — পাসওয়ার্ড, ফোন নম্বর, কোড বা স্বাস্থ্যের কথা কখনো না। এটা শুরু থেকে চালু থাকে; অ্যাপের “আরও” পাতায় “কথা বোঝা আরও ভালো করতে সাহায্য করুন” বন্ধ করলে আর যায় না। ১৮০ দিন পর নিজে মুছে যায়; অ্যাপ থেকে যেকোনো সময় মুছে দেওয়া যায়।</li>
<li><strong>রক্তদান:</strong> নিজের রক্তের গ্রুপ দিলে গ্রুপ, মোবাইল নম্বর, জেলা আর শেষ রক্তদানের তারিখ; রক্তের অনুরোধে যা লেখেন — যেন রক্ত লাগলে দাতা খুঁজে পাওয়া যায়।</li>
<li><strong>ফ্যামিলি:</strong> কার সাথে যুক্ত। পাঠানো কাজ, নোট, ওষুধের রিমাইন্ডার, লাইভ লোকেশন আর উত্তরাধিকারীর কপি end-to-end সিল করা — আমাদের সার্ভার পড়তে পারে না।</li>
<li><strong>সমস্যার লগ:</strong> অ্যাপ ক্র্যাশ বা ভুল হলে শুধু ভুলের ধরন, কোডের জায়গা আর সংস্করণ (আপনার লেখা বাদ দিয়ে)। বিস্তারিত লগ শুধু আপনি চালু করলে, ৩০ দিন থাকে।</li>
<li><strong>মতামত:</strong> আপনি যা লেখেন বা জুড়ে দেন।</li>
<li><strong>নোটিফিকেশন:</strong> পুশ পাঠানোর জন্য ফোনের পুশ টোকেন।</li>
</ul>

<h3>অন্য সেবা</h3>
<ul>
<li><strong>Google Drive ব্যাকআপ:</strong> আপনার নিজের Drive-এ, এনক্রিপ্ট করে; আমরা দেখতে পারি না।</li>
<li><strong>আবহাওয়া ও জায়গা খোঁজা:</strong> আনুমানিক অবস্থান বা লেখা জায়গার নাম Open-Meteo-তে যায়।</li>
<li><strong>বিদেশের ছুটি:</strong> শুধু দেশের কোড Nager.Date-এ যায়।</li>
<li><strong>বিজ্ঞাপন (ফ্রি সংস্করণ):</strong> Google AdMob বিজ্ঞাপন দেখায়; Google তার নিজের নিয়মে ডিভাইসের বিজ্ঞাপন-আইডি ব্যবহার করতে পারে। ইউরোপসহ যেখানে আইন চায়, আগে আপনার অনুমতি চাওয়া হয়। পাসওয়ার্ড, PIN বা লক পাতায় কখনো বিজ্ঞাপন নেই।</li>
<li><strong>Google Play:</strong> Play Store-এর অ্যাপে কেনা Google Play-র মাধ্যমে হয়; কার্ডের তথ্য আমরা পাই না।</li>
</ul>

<h3>আপনার অধিকার</h3>
<ul>
<li>অ্যাপের সেটিংস › Google অ্যাকাউন্ট › “অ্যাকাউন্ট মুছুন”, বা <a href="$del">ওয়েবসাইটের অ্যাকাউন্ট মোছার পাতা</a> থেকে সার্ভারের সব তথ্য মুছে দিতে পারেন। শুধু পেমেন্টের রেকর্ড আইন অনুযায়ী থাকে।</li>
<li>ফোনের তথ্য অ্যাপ আনইনস্টল করলে মুছে যায়; Drive-এর ব্যাকআপ আপনার Drive থেকে মুছতে পারেন।</li>
<li>যোগাযোগ: $mail</li>
</ul>
<p>অ্যাপটি ১৩ বছরের কম বয়সীদের জন্য নয়। এই পলিসি বদলালে এই পাতায় তারিখসহ জানানো হবে।</p>

<hr>
<h2>My Assistant — Privacy Policy</h2>
<p><em>Last changed: $date · Owlgorithm Labs</em></p>
<p>My Assistant keeps your data on your phone first, encrypted. Passwords, the vault, PINs, OTPs, health, medicines, bank cards and other apps' messages never leave the phone. We do not sell your data.</p>
<p><strong>Stays on the phone:</strong> tasks, reminders, notes, money, loans, documents, passwords, health, medicines and cards (AES-256, the key in the phone's secure storage); Health Connect steps, sleep and exercise (read only); contacts (to show and call); location (district, prayer times, qibla, weather — worked out on the phone); the mic uses the phone's own speech service when you tap it.</p>
<p><strong>Goes to our server, and why:</strong> your account (name, email, picture from Google sign-in; Premium dates; for payments the name, phone and transaction number for bKash, or the Google Play purchase); sentences the phone could not understand and Premium AI questions, through our server to AI services (Anthropic, Google) — with a summary of your tasks, reminders, notes and money only if you allow it, never passwords, PINs, OTPs or phone, card or NID numbers; to improve understanding, some messages with names removed — never passwords, phone numbers, codes or health — on from the start and off with “Help the assistant understand better” on the app's More page (deleted after 180 days, or by you at any time); for blood donation your group, mobile number, district and last donation date, and your requests; family links (shared tasks, notes, medicine reminders, live location and the heirs' copy are end-to-end sealed — our server cannot read them); crash and problem reports without your words (detailed logs only if you turn them on, kept 30 days); your feedback; a push token for notifications.</p>
<p><strong>Other services:</strong> backups go to your own Google Drive, encrypted; weather and place search send an approximate location or the typed place name to Open-Meteo; holidays abroad send only the country code to Nager.Date; the free version shows Google AdMob ads (Google may use the device's advertising ID under its own policy; consent is asked where the law requires; never on password, PIN or lock pages); Play Store purchases go through Google Play — we never see card details.</p>
<p><strong>Your choices:</strong> delete everything our server keeps from the app (Settings › Google account › “Delete account”) or from the <a href="$del">website's deletion page</a>; payment records stay as the law requires. Uninstalling removes the phone's data; delete Drive backups from your Drive. Contact: $mail. Not meant for children under 13. Changes are posted here with the date.</p>
</div>
HTML;
});

/** The published page that carries [shortcode] (the site's home when none does). */
function ma_page_with($shortcode) {
    global $wpdb;
    $id = (int) $wpdb->get_var($wpdb->prepare("SELECT ID FROM {$wpdb->posts} WHERE post_status = 'publish' AND post_type = 'page' AND post_content LIKE %s ORDER BY ID LIMIT 1", '%[' . $wpdb->esc_like($shortcode) . '%'));
    return $id ? (string) get_permalink($id) : home_url('/');
}

/** The AdMob publisher ID (pub-…), set on the settings page. */
function ma_admob_pub() {
    $p = (string) get_option('ma_admob_pub', '');
    return preg_match('/^pub-\d{10,20}$/', $p) ? $p : '';
}

// app-ads.txt at the site's root, from the publisher ID (AdMob checks it).
add_action('init', function () {
    $path = strtok((string) ($_SERVER['REQUEST_URI'] ?? ''), '?');
    if ($path !== '/app-ads.txt') {
        return;
    }
    $pub = ma_admob_pub();
    if ($pub === '') {
        status_header(404);
        exit;
    }
    header('Content-Type: text/plain; charset=utf-8');
    echo 'google.com, ' . $pub . ", DIRECT, f08c47fec0942fa0\n"; // phpcs:ignore
    exit;
});

add_action('admin_post_ma_admob_settings', function () {
    ma_acc_guard('ma_admob_settings', 'manage_options');
    $pub = sanitize_text_field(wp_unslash($_POST['admob_pub'] ?? ''));
    if ($pub !== '' && !preg_match('/^pub-\d{10,20}$/', $pub)) {
        ma_acc_back('AdMob publisher ID দেখতে “pub-১২৩৪…” এমন — AdMob › Settings থেকে কপি করুন।', 'error', ['tab' => 'settings']);
    }
    update_option('ma_admob_pub', $pub, false);
    ma_acc_back('AdMob-এর সেটিংস রাখা হয়েছে।', 'ok', ['tab' => 'settings']);
});

/** The settings page's AdMob card. */
function ma_admob_settings_card() {
    $pub = ma_admob_pub();
    ?>
    <section class="ma-card pad">
        <div class="ma-ai-head">
            <div>
                <h2>AdMob (app-ads.txt)</h2>
                <p class="muted">AdMob চায় সাইটের <code>/app-ads.txt</code>-এ আপনার publisher ID থাকুক। এখানে ID দিলে ফাইলটা নিজে তৈরি হয়।</p>
            </div>
            <span class="ma-pill <?php echo $pub !== '' ? 'pro' : 'expired'; ?>"><?php echo $pub !== '' ? 'app-ads.txt চালু' : 'ID নেই'; ?></span>
        </div>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <input type="hidden" name="action" value="ma_admob_settings">
            <?php wp_nonce_field('ma_admob_settings'); ?>
            <label>AdMob publisher ID <input name="admob_pub" value="<?php echo esc_attr($pub); ?>" placeholder="pub-1234567890123456"></label>
            <p class="muted ma-tip">AdMob › Settings › Account information › Publisher ID।</p>
            <button class="ma-btn" type="submit">রাখুন</button>
        </form>
    </section>
    <?php
}
