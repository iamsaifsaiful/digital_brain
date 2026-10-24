<?php
/**
 * Payments made outside Google Play (bKash, Nagad…): the
 * payer submits the details on the website ([my_assistant_payment] on any
 * page), the admin checks them against the account and approves; approval
 * gives Pro to that Google email.
 */

if (!defined('ABSPATH')) {
    exit;
}

function ma_pay_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_payments';
}

function ma_pay_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $t = ma_pay_table();
    dbDelta("CREATE TABLE $t (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        created_at datetime NOT NULL,
        email varchar(190) NOT NULL,
        name varchar(190) NOT NULL DEFAULT '',
        phone varchar(32) NOT NULL DEFAULT '',
        plan varchar(16) NOT NULL,
        amount int(10) unsigned NOT NULL DEFAULT 0,
        method varchar(64) NOT NULL,
        sender varchar(64) NOT NULL DEFAULT '',
        trx varchar(64) NOT NULL,
        note varchar(500) NOT NULL DEFAULT '',
        status varchar(16) NOT NULL DEFAULT 'pending',
        reason varchar(300) NOT NULL DEFAULT '',
        reviewed_at datetime NULL DEFAULT NULL,
        reviewed_by bigint(20) unsigned NULL DEFAULT NULL,
        reviewed_email varchar(190) NOT NULL DEFAULT '',
        PRIMARY KEY  (id),
        KEY status (status),
        KEY email (email),
        KEY trx (trx)
    ) " . $wpdb->get_charset_collate() . ';');
}

/** The plans and their prices (taka), set on the settings page. */
function ma_pay_plans() {
    return [
        'yearly' => ['label' => 'বার্ষিক', 'price' => (int) get_option('ma_pay_yearly', 999), 'days' => 365],
        'monthly' => ['label' => 'মাসিক', 'price' => (int) get_option('ma_pay_monthly', 99), 'days' => 30],
    ];
}

/**
 * Payment methods, one per line on the settings page: "name | number | how".
 * e.g. "বিকাশ | 01XXXXXXXXX | Send Money (পার্সোনাল)".
 */
function ma_pay_methods() {
    $default = "বিকাশ | 01997959167 | Send Money\nনগদ | 01997959167 | Send Money";
    $raw = (string) get_option('ma_pay_methods', $default);
    // The first versions saved sample numbers (01XXXXXXXXX); those are not real, so the real ones are used.
    if (trim($raw) === '' || str_contains($raw, 'XXXXXXX')) {
        $raw = $default;
    }
    $out = [];
    foreach (preg_split('/\r?\n/', $raw) as $line) {
        $p = array_map('trim', explode('|', $line));
        if ($p[0] === '') {
            continue;
        }
        // Keyed by the method's name, so a form opened before a change still matches.
        $out['m' . substr(md5($p[0]), 0, 10)] = ['name' => $p[0], 'number' => $p[1] ?? '', 'how' => $p[2] ?? ''];
    }
    return $out;
}

function ma_pay_labels() {
    return ['pending' => ['দেখার অপেক্ষায়', 'trial'], 'approved' => ['অনুমোদিত', 'pro'], 'rejected' => ['বাতিল', 'expired']];
}

// ── The website form: [my_assistant_payment] ──
//
// A whole "প্রিমিয়াম কিনুন" page: plan, where to send the money, and the form
// whose details come to this server (admin-post.php → ma_pay_submit).
// [my_assistant_payment]            the full page with its own top bar and footer
//                                   (for an Elementor Canvas / blank page)
// [my_assistant_payment nav="no"]   without the top bar and footer (inside a theme page)

add_shortcode('my_assistant_payment', 'ma_pay_form');

/** Colour for a payment method's badge. */
function ma_pay_color($name) {
    $n = mb_strtolower($name);
    foreach (['বিকাশ' => '#D12053', 'bkash' => '#D12053', 'নগদ' => '#E4572E', 'nagad' => '#E4572E', 'রকেট' => '#7B2A8C', 'rocket' => '#7B2A8C', 'উপায়' => '#1E5AA8', 'upay' => '#1E5AA8'] as $k => $c) {
        if (str_contains($n, $k)) {
            return $c;
        }
    }
    return '#1F4E79';
}

function ma_pay_form($atts = []) {
    $a = shortcode_atts(['nav' => 'yes', 'head' => 'yes'], $atts, 'my_assistant_payment');
    $plans = ma_pay_plans();
    $methods = ma_pay_methods();
    $state = isset($_GET['ma_pay']) ? sanitize_key($_GET['ma_pay']) : '';
    $want = isset($_GET['plan']) ? sanitize_key($_GET['plan']) : '';
    $chosen = isset($plans[$want]) ? $want : 'yearly';
    if (!isset($plans[$chosen])) {
        $chosen = array_key_first($plans);
    }
    $save = max(0, $plans['monthly']['price'] * 12 - $plans['yearly']['price']);
    $icon = plugins_url('assets/icon.svg', __FILE__);
    $home = home_url('/');
    $lock = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="4" y="10" width="16" height="11" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/></svg>';
    $check = '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12l5 5 9-10"/></svg>';
    ob_start();
    ?>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Anek+Bangla:wdth,wght@75..100,400..800&family=Noto+Sans+Bengali:wght@400;500;600;700&display=swap" rel="stylesheet">
    <div class="ma-pay<?php echo $a['head'] === 'no' ? ' bare' : ''; ?>" id="ma-pay">
    <style>
    .ma-pay{--g:#0B6B55;--gd:#084D3D;--gt:#E6F2EE;--ink:#10201B;--mut:#4A5752;--line:#DDE5E1;--ground:#F4F6F5;--amber:#F5B83D;background:var(--ground);color:var(--ink);font-family:'Noto Sans Bengali',system-ui,sans-serif;font-size:16px;line-height:1.5;text-align:left}
    .ma-pay,.ma-pay *{box-sizing:border-box}
    .ma-pay h1,.ma-pay h2,.ma-pay h3{font-family:'Anek Bangla','Noto Sans Bengali',sans-serif;color:inherit;text-transform:none;letter-spacing:0;margin:0;padding:0;border:0}
    .ma-pay p{margin:0;padding:0}
    .ma-pay a{color:inherit;text-decoration:none;box-shadow:none}
    .ma-pay img{border:0;box-shadow:none;border-radius:0;max-width:100%}
    .ma-pay .wrap{max-width:1160px;margin:0 auto;padding:0 40px}
    .ma-pay .top{background:#fff;border-bottom:1px solid var(--line)}
    .ma-pay .top .wrap{display:flex;align-items:center;height:72px;gap:20px}
    .ma-pay .brand{display:flex;align-items:center;gap:12px;font-family:'Anek Bangla','Noto Sans Bengali',sans-serif;font-weight:700;font-size:21px}
    .ma-pay .brand img{width:38px;height:38px}
    .ma-pay .top .back{margin-left:auto;font-size:15.5px;color:var(--mut)}
    .ma-pay .head{padding-top:48px;padding-bottom:28px}
    .ma-pay .head h1{font-size:54px;font-weight:700;font-stretch:86%;line-height:1.1}
    .ma-pay .head p{margin-top:10px;font-size:18px;line-height:1.7;color:var(--mut);max-width:680px}
    .ma-pay .layout{display:grid;grid-template-columns:1fr 440px;gap:28px;align-items:start;padding-bottom:64px}
    .ma-pay .box{background:#fff;border:1px solid var(--line);border-radius:24px;padding:28px}
    .ma-pay .box+.box{margin-top:22px}
    .ma-pay .label{display:flex;align-items:center;gap:12px;font-family:'Anek Bangla','Noto Sans Bengali',sans-serif;font-size:22px;font-weight:700;font-stretch:90%}
    .ma-pay .n{width:34px;height:34px;border-radius:50%;background:var(--g);color:#fff;display:grid;place-items:center;font-family:'Anek Bangla','Noto Sans Bengali',sans-serif;font-size:16px;font-weight:700;flex:none}
    .ma-pay .sub{margin-top:8px;font-size:15px;color:var(--mut);line-height:1.6}
    .ma-pay .opt{display:block;cursor:pointer;position:relative;margin:0}
    .ma-pay .opt input{position:absolute;opacity:0;width:1px;height:1px}
    .ma-pay .opt .card{display:block;border:1.5px solid var(--line);border-radius:18px;background:#fff;transition:border-color .15s,background .15s}
    .ma-pay .opt input:checked+.card{border-color:var(--g);background:var(--gt)}
    .ma-pay .opt input:focus-visible+.card{outline:2px solid var(--g);outline-offset:2px}
    .ma-pay .radio{position:absolute;top:20px;right:20px;width:22px;height:22px;border-radius:50%;border:2px solid var(--line);background:#fff}
    .ma-pay .opt input:checked+.card .radio{border:7px solid var(--g)}
    .ma-pay .plans{margin-top:20px;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px}
    .ma-pay .plan .card{padding:20px;position:relative;height:100%}
    .ma-pay .plan .tag{position:absolute;top:-12px;right:16px;background:var(--amber);color:#3d2600;border-radius:999px;padding:2px 11px;font-size:13px;font-weight:700}
    .ma-pay .plan .nm{display:block;font-weight:600;color:var(--mut)}
    .ma-pay .plan .price{display:block;margin-top:4px;font-family:'Anek Bangla','Noto Sans Bengali',sans-serif;font-size:38px;font-weight:700}
    .ma-pay .plan .price small{font-size:16px;font-weight:500;color:var(--mut)}
    .ma-pay .plan .ps{display:block;font-size:14px;color:var(--mut)}
    .ma-pay .methods{margin-top:20px;display:grid;gap:12px}
    .ma-pay .method .card{display:grid;grid-template-columns:52px 1fr auto;gap:16px;align-items:center;padding:14px 56px 14px 16px;position:relative}
    .ma-pay .method .radio{top:50%;margin-top:-11px;right:18px}
    .ma-pay .logo{width:52px;height:52px;border-radius:14px;display:grid;place-items:center;font-family:'Anek Bangla','Noto Sans Bengali',sans-serif;font-weight:700;font-size:14px;color:#fff;text-align:center;line-height:1.1;padding:2px}
    .ma-pay .method b{display:block;font-size:17.5px}
    .ma-pay .method .num{display:block;font-size:19px;font-weight:700;letter-spacing:.5px;color:var(--ink);font-variant-numeric:tabular-nums}
    .ma-pay .method .how{display:block;font-size:13.5px;color:var(--mut)}
    .ma-pay .copy{display:inline-flex;align-items:center;gap:6px;border:1px solid var(--line);background:#fff;color:var(--ink);border-radius:10px;padding:8px 12px;font:inherit;font-size:14px;font-weight:600;cursor:pointer;width:auto;height:auto;margin:0}
    .ma-pay .copy:hover{border-color:var(--g);color:var(--g);background:#fff}
    .ma-pay .tip{margin-top:16px;font-size:15px;line-height:1.7;color:var(--mut)}
    .ma-pay .tip b{color:var(--ink)}
    .ma-pay .field{display:grid;gap:6px;margin-top:16px;font-size:14.5px;font-weight:600}
    .ma-pay .field input,.ma-pay .field textarea{display:block;width:100%;height:48px;border:1px solid var(--line);border-radius:12px;padding:0 14px;font:inherit;font-weight:400;font-size:16px;color:var(--ink);background:#fff;box-shadow:none;margin:0}
    .ma-pay .field textarea{height:80px;padding:12px 14px;resize:vertical}
    .ma-pay .field input:focus,.ma-pay .field textarea:focus{outline:0;border-color:var(--g);box-shadow:0 0 0 3px rgba(11,107,85,.15)}
    .ma-pay .hint{font-weight:400;font-size:13px;color:var(--mut)}
    .ma-pay .sumline{margin-top:18px;background:var(--ground);border-radius:14px;padding:12px 14px;display:flex;justify-content:space-between;font-size:15.5px}
    .ma-pay .submit{display:block;margin-top:18px;width:100%;height:54px;border:0;border-radius:14px;background:var(--g);color:#fff;font-family:'Anek Bangla','Noto Sans Bengali',sans-serif;font-size:19px;font-weight:700;cursor:pointer;padding:0}
    .ma-pay .submit:hover{background:var(--gd);color:#fff}
    .ma-pay .secure{margin-top:14px;display:flex;gap:10px;font-size:13.5px;line-height:1.6;color:var(--mut)}
    .ma-pay .secure svg{flex:none;margin-top:2px}
    .ma-pay .secure a{color:var(--g);font-weight:600}
    .ma-pay .hp{position:absolute;left:-9999px;width:1px;height:1px;overflow:hidden}
    .ma-pay .after h3{font-size:22px;font-weight:700;font-stretch:90%}
    .ma-pay .after ol{margin:16px 0 0;padding:0;list-style:none;display:grid;gap:14px}
    .ma-pay .after li{display:grid;grid-template-columns:34px 1fr;gap:12px;font-size:15.5px;line-height:1.65;margin:0}
    .ma-pay .after li b{display:block}
    .ma-pay .done{background:var(--gt);border-radius:24px;padding:28px}
    .ma-pay .done .ck{width:52px;height:52px;border-radius:50%;background:var(--g);display:grid;place-items:center;color:#fff}
    .ma-pay .done h2{margin-top:14px;font-size:28px;font-weight:700;color:var(--gd)}
    .ma-pay .done p{margin-top:8px;font-size:16px;line-height:1.75;color:var(--gd)}
    .ma-pay .done a{display:inline-block;margin-top:16px;color:var(--g);font-weight:700}
    .ma-pay .bad{background:#FFF1F2;border:1px solid #FECDD3;border-radius:14px;padding:12px 14px;color:#BE123C;margin-top:14px;font-size:15px}
    .ma-pay .foot{border-top:1px solid var(--line);background:#fff;padding:26px 0;font-size:14.5px;color:var(--mut)}
    .ma-pay .foot .wrap{display:flex;gap:22px;flex-wrap:wrap;align-items:center}
    .ma-pay .foot .r{margin-left:auto;display:flex;gap:22px;flex-wrap:wrap}
    .ma-pay.bare{background:transparent}
    .ma-pay.bare .wrap{padding:0}
    @media (max-width:760px){
      .ma-pay .wrap{padding:0 16px}
      .ma-pay .head{padding-top:32px}
      .ma-pay .head h1{font-size:38px}
      .ma-pay .layout{grid-template-columns:1fr}
      .ma-pay .plans{grid-template-columns:1fr}
      .ma-pay .method .card{grid-template-columns:44px 1fr;padding-right:52px}
      .ma-pay .method .copy{grid-column:2;justify-self:start}
      .ma-pay .logo{width:44px;height:44px;font-size:12.5px}
      .ma-pay .box,.ma-pay .done{padding:20px}
      .ma-pay .foot .r{margin-left:0}
    }
    </style>

    <?php if ($a['nav'] !== 'no') : ?>
    <div class="top"><div class="wrap"><a class="brand" href="<?php echo esc_url($home); ?>"><img src="<?php echo esc_url($icon); ?>" alt="">My Assistant</a><a class="back" href="<?php echo esc_url($home); ?>">← মূল পাতায় ফিরুন</a></div></div>
    <?php endif; ?>

    <?php if ($state === 'ok') : ?>
    <div class="wrap" style="padding-top:48px;padding-bottom:64px;max-width:760px">
        <div class="done" role="status">
            <span class="ck"><?php echo $check; ?></span>
            <h2>ধন্যবাদ! তথ্য পেয়েছি</h2>
            <p>পেমেন্ট মিলিয়ে আমরা প্রিমিয়াম চালু করছি — বেশির ভাগ সময় সাথে সাথেই হয়ে যায়। চালু হলে ফোনে নোটিফিকেশন আর ইমেইল পাবেন। অ্যাপে যে Google অ্যাকাউন্ট দিয়েছেন, সেটাতেই লগইন রাখুন।</p>
            <p>পেমেন্ট না মিললে কেন মেলেনি, ইমেইলে জানিয়ে দেব।</p>
            <a href="<?php echo esc_url($home); ?>">← মূল পাতায় ফিরুন</a>
        </div>
    </div>
    <?php else : ?>

    <?php if ($a['head'] !== 'no') : ?>
    <div class="wrap head">
        <h1>প্রিমিয়াম কিনুন</h1>
        <p>নিচের নম্বরে টাকা পাঠিয়ে তথ্য জমা দিন। তথ্য সরাসরি আমাদের সার্ভারে আসে — পেমেন্ট মিলিয়ে আমরা আপনার Google অ্যাকাউন্টে প্রিমিয়াম চালু করি, বেশির ভাগ সময় সাথে সাথেই।</p>
    </div>
    <?php endif; ?>

    <form class="wrap layout" method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
        <input type="hidden" name="action" value="ma_pay_submit">
        <input type="hidden" name="back" value="<?php echo esc_url(get_permalink() ?: $home); ?>">
        <?php wp_nonce_field('ma_pay_submit', 'ma_pay_nonce'); ?>
        <span class="hp" aria-hidden="true"><input type="text" name="website" tabindex="-1" autocomplete="off"></span>

        <div>
            <div class="box">
                <p class="label"><span class="n">১</span>প্ল্যান বেছে নিন</p>
                <div class="plans">
                    <?php foreach ($plans as $key => $pl) : ?>
                        <label class="opt plan"><input type="radio" name="plan" value="<?php echo esc_attr($key); ?>" <?php checked($key === $chosen); ?> data-price="<?php echo esc_attr(ma_acc_bn($pl['price'])); ?>" data-label="<?php echo esc_attr($pl['label']); ?>" required><span class="card"><span class="radio"></span>
                            <?php if ($key === 'yearly' && $save > 0) : ?><span class="tag">বছরে ৳<?php echo esc_html(ma_acc_bn($save)); ?> সাশ্রয়</span><?php endif; ?>
                            <span class="nm"><?php echo esc_html($pl['label']); ?></span>
                            <span class="price">৳<?php echo esc_html(ma_acc_bn($pl['price'])); ?><small> / <?php echo esc_html(ma_acc_bn($pl['days'])); ?> দিন</small></span>
                            <span class="ps"><?php echo $key === 'yearly' ? 'মাসে ৳' . esc_html(ma_acc_bn((int) round($pl['price'] / 12))) . '-এর মতো' : 'একবার চেখে দেখতে'; ?></span>
                        </span></label>
                    <?php endforeach; ?>
                </div>
            </div>

            <div class="box">
                <p class="label"><span class="n">২</span>টাকা পাঠান</p>
                <p class="sub">যেটা দিয়ে টাকা পাঠাবেন, সেটা বেছে নিন।</p>
                <div class="methods">
                    <?php $first = true; foreach ($methods as $key => $m) : ?>
                        <label class="opt method"><input type="radio" name="method" value="<?php echo esc_attr($key); ?>" <?php checked($first); ?> required><span class="card"><span class="radio"></span>
                            <span class="logo" style="background:<?php echo esc_attr(ma_pay_color($m['name'])); ?>"><?php echo esc_html($m['name']); ?></span>
                            <span><b><?php echo esc_html($m['name']); ?></b><span class="num"><?php echo esc_html($m['number']); ?></span><?php if ($m['how'] !== '') : ?><span class="how"><?php echo esc_html($m['how']); ?></span><?php endif; ?></span>
                            <button class="copy" type="button" data-copy="<?php echo esc_attr($m['number']); ?>">নম্বর কপি</button>
                        </span></label>
                    <?php $first = false; endforeach; ?>
                </div>
                <p class="tip">অ্যাপ থেকে <b>Send Money</b> করুন। টাকা পাঠানোর পর যে মেসেজ আসে, সেখানে <b>ট্রানজেকশন আইডি (TrxID)</b> থাকে — সেটা পাশের ফর্মে লাগবে।</p>
            </div>

            <div class="box after">
                <h3>জমা দেওয়ার পর</h3>
                <ol>
                    <li><span class="n">ক</span><div><b>আমরা পেমেন্ট মিলিয়ে নিই</b>আপনার TrxID দেখে প্রিমিয়াম চালু করি — বেশির ভাগ সময় সাথে সাথেই।</div></li>
                    <li><span class="n">খ</span><div><b>অ্যাপে প্রিমিয়াম চলে আসে</b>একই Google অ্যাকাউন্টে লগইন থাকলেই হবে। ফোনে নোটিফিকেশন আর ইমেইলেও জানাই।</div></li>
                    <li><span class="n">গ</span><div><b>না মিললে জানাই</b>কেন মেলেনি ইমেইলে লিখে দিই; উত্তর দিলেই আবার দেখি।</div></li>
                </ol>
            </div>
        </div>

        <div class="box">
            <p class="label"><span class="n">৩</span>তথ্য জমা দিন</p>
            <p class="sub">সব তথ্য নিরাপদে আমাদের সার্ভারে আসে, শুধু পেমেন্ট মেলাতে।</p>
            <?php if ($state !== '') : ?><div class="bad" role="alert"><?php echo esc_html(ma_pay_error_text($state)); ?></div><?php endif; ?>
            <label class="field">যে নম্বর থেকে টাকা পাঠিয়েছেন<input type="text" name="sender" required maxlength="64" autocomplete="tel" inputmode="tel" placeholder="01XXXXXXXXX"></label>
            <label class="field">ট্রানজেকশন আইডি (TrxID)<input type="text" name="trx" required maxlength="64" autocomplete="off" spellcheck="false" placeholder="যেমন 9A7KX2PQ1M"></label>
            <label class="field">যে Google ইমেইলে অ্যাপে লগইন করেন<input type="email" name="email" required maxlength="190" autocomplete="email" placeholder="name@gmail.com"><span class="hint">এই ইমেইলেই প্রিমিয়াম চালু হবে — ঠিকমতো লিখুন।</span></label>
            <label class="field">নাম<input type="text" name="name" maxlength="190" autocomplete="name" placeholder="আপনার নাম"></label>
            <label class="field">মোবাইল (ঐচ্ছিক)<input type="tel" name="phone" maxlength="32" autocomplete="tel" placeholder="যোগাযোগের নম্বর"></label>
            <label class="field">কিছু বলার থাকলে (ঐচ্ছিক)<textarea name="note" maxlength="500"></textarea></label>
            <div class="sumline"><span id="ma-pay-sum-label"><?php echo esc_html($plans[$chosen]['label']); ?> প্রিমিয়াম</span><b id="ma-pay-sum-price">৳<?php echo esc_html(ma_acc_bn($plans[$chosen]['price'])); ?></b></div>
            <button class="submit" type="submit">তথ্য জমা দিন</button>
            <p class="secure"><?php echo $lock; ?><span>আমরা কখনো আপনার PIN, OTP বা পাসওয়ার্ড চাই না। একই TrxID দুবার জমা দেওয়া যায় না। জমা দিয়ে আপনি <a href="<?php echo esc_url(home_url('/terms-and-conditions/')); ?>">শর্তাবলি</a> মেনে নিচ্ছেন — কেনার পর টাকা ফেরত হয় না।</span></p>
        </div>
    </form>
    <script>
    (function () {
        var root = document.getElementById('ma-pay');
        if (!root) return;
        root.querySelectorAll('input[name="plan"]').forEach(function (r) {
            r.addEventListener('change', function () {
                document.getElementById('ma-pay-sum-label').textContent = r.dataset.label + ' প্রিমিয়াম';
                document.getElementById('ma-pay-sum-price').textContent = '৳' + r.dataset.price;
            });
        });
        root.querySelectorAll('.copy').forEach(function (b) {
            b.addEventListener('click', function () {
                var r = b.closest('label') && b.closest('label').querySelector('input');
                if (r) r.checked = true;
                var t = b.dataset.copy, done = function () { var o = b.textContent; b.textContent = 'কপি হয়েছে ✓'; setTimeout(function () { b.textContent = o; }, 1600); };
                if (navigator.clipboard) { navigator.clipboard.writeText(t).then(done, function () {}); }
                else { var i = document.createElement('input'); i.value = t; document.body.appendChild(i); i.select(); try { document.execCommand('copy'); done(); } catch (x) {} i.remove(); }
            });
        });
    })();
    </script>
    <?php endif; ?>

    <?php if ($a['nav'] !== 'no') : ?>
    <div class="foot"><div class="wrap"><span>My Assistant · getmyassistant.app</span><div class="r"><a href="<?php echo esc_url(home_url('/privacy-policy/')); ?>">গোপনীয়তা নীতি</a><a href="<?php echo esc_url(home_url('/terms-and-conditions/')); ?>">শর্তাবলি</a><a href="mailto:info@getmyassistant.app">info@getmyassistant.app</a></div></div></div>
    <?php endif; ?>
    </div>
    <?php
    return ob_get_clean();
}

function ma_pay_error_text($code) {
    return [
        'fields' => 'সব ঘর ঠিকমতো পূরণ করুন।',
        'email' => 'ঠিক Google ইমেইল দিন।',
        'dup' => 'এই ট্রানজেকশন আইডি আগেই জমা হয়েছে। সমস্যা হলে আমাদের সাথে যোগাযোগ করুন।',
        'busy' => 'অনেকবার চেষ্টা হয়েছে, একটু পরে আবার চেষ্টা করুন।',
        'expired' => 'পাতাটা পুরোনো হয়ে গেছে — একবার রিফ্রেশ করে আবার জমা দিন।',
    ][$code] ?? 'জমা দেওয়া যায়নি, আবার চেষ্টা করুন।';
}

function ma_pay_submit() {
    $back = esc_url_raw(wp_unslash($_POST['back'] ?? home_url('/')));
    if (wp_validate_redirect($back, '') === '') {
        $back = home_url('/');
    }
    $go = function ($state) use ($back) {
        wp_safe_redirect(add_query_arg('ma_pay', $state, $back) . '#ma-pay');
        exit;
    };
    if (!isset($_POST['ma_pay_nonce']) || !wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['ma_pay_nonce'])), 'ma_pay_submit')) {
        $go('expired');
    }
    if (!empty($_POST['website'])) {
        $go('ok'); // a bot filled the hidden field
    }
    $ip = isset($_SERVER['REMOTE_ADDR']) ? sanitize_text_field(wp_unslash($_SERVER['REMOTE_ADDR'])) : 'x';
    $rl = 'ma_pay_rl_' . md5($ip);
    $n = (int) get_transient($rl);
    if ($n >= 8) {
        $go('busy');
    }
    set_transient($rl, $n + 1, HOUR_IN_SECONDS);

    $plans = ma_pay_plans();
    $methods = ma_pay_methods();
    $plan = sanitize_key($_POST['plan'] ?? '');
    $method = sanitize_key(wp_unslash($_POST['method'] ?? ''));
    $email = strtolower(sanitize_email(wp_unslash($_POST['email'] ?? '')));
    $trx = strtoupper(preg_replace('/[^A-Za-z0-9\-]/', '', (string) wp_unslash($_POST['trx'] ?? '')));
    $sender = substr(sanitize_text_field(wp_unslash($_POST['sender'] ?? '')), 0, 64);
    if (!isset($plans[$plan]) || !isset($methods[$method]) || strlen($trx) < 4 || $sender === '') {
        $go('fields');
    }
    if (!is_email($email)) {
        $go('email');
    }
    global $wpdb;
    $dup = $wpdb->get_var($wpdb->prepare('SELECT id FROM ' . ma_pay_table() . " WHERE trx = %s AND method = %s AND status <> 'rejected'", substr($trx, 0, 64), $methods[$method]['name']));
    if ($dup) {
        $go('dup');
    }
    $wpdb->insert(ma_pay_table(), [
        'created_at' => current_time('mysql', true),
        'email' => $email,
        'name' => substr(sanitize_text_field(wp_unslash($_POST['name'] ?? '')), 0, 190),
        'phone' => substr(sanitize_text_field(wp_unslash($_POST['phone'] ?? '')), 0, 32),
        'plan' => $plan,
        'amount' => $plans[$plan]['price'],
        'method' => $methods[$method]['name'],
        'sender' => $sender,
        'trx' => substr($trx, 0, 64),
        'note' => substr(sanitize_textarea_field(wp_unslash($_POST['note'] ?? '')), 0, 500),
    ]);
    ma_push_admins('নতুন পেমেন্ট — ৳' . $plans[$plan]['price'], $methods[$method]['name'] . ' · ' . $email, ['type' => 'payment', 'id' => (string) $wpdb->insert_id]);
    wp_mail(
        get_option('admin_email'),
        'My Assistant: নতুন পেমেন্ট — ' . $methods[$method]['name'] . ' ৳' . $plans[$plan]['price'],
        "ইমেইল: $email\nমাধ্যম: {$methods[$method]['name']}\nযে নম্বর থেকে: $sender\nTrxID: $trx\n\nদেখে অনুমোদন দিন: " . admin_url('admin.php?page=my-assistant&tab=payments')
    );
    $go('ok');
}
add_action('admin_post_nopriv_ma_pay_submit', 'ma_pay_submit');
add_action('admin_post_ma_pay_submit', 'ma_pay_submit');

// ── Admin: approve or reject ──

/**
 * Approves (gives Pro to the payer's Google email and tells them) or
 * rejects a payment. Used by the website admin page and the admin app.
 * Returns [ok, message].
 */
function ma_pay_decide($id, $approve, $reason = '', $tell = true, $by = '') {
    global $wpdb;
    $p = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_pay_table() . ' WHERE id = %d', $id), ARRAY_A);
    if (!$p || $p['status'] !== 'pending') {
        return [false, 'এই পেমেন্ট আগেই দেখা হয়েছে।'];
    }
    $now = current_time('mysql', true);
    $who = ['reviewed_at' => $now, 'reviewed_by' => get_current_user_id() ?: null, 'reviewed_email' => substr((string) $by, 0, 190)];
    if (!$approve) {
        $reason = substr(sanitize_text_field($reason), 0, 300);
        $wpdb->update(ma_pay_table(), ['status' => 'rejected', 'reason' => $reason] + $who, ['id' => $id]);
        if ($tell) {
            wp_mail($p['email'], 'My Assistant: পেমেন্ট মেলেনি', "আপনার জমা দেওয়া পেমেন্ট ({$p['method']}, TrxID {$p['trx']}) আমরা মেলাতে পারিনি।" . ($reason !== '' ? "\nকারণ: $reason" : '') . "\n\nভুল হয়ে থাকলে এই ইমেইলের উত্তর দিন।\n\n— My Assistant");
        }
        return [true, 'পেমেন্ট বাতিল করা হলো।'];
    }
    $plans = ma_pay_plans();
    $days = $plans[$p['plan']]['days'] ?? 30;
    $table = ma_acc_table();
    $member = $wpdb->get_row($wpdb->prepare("SELECT * FROM $table WHERE email = %s ORDER BY id LIMIT 1", $p['email']), ARRAY_A);
    if ($member) {
        $wpdb->update($table, ['pro_until' => ma_acc_extend($member, $days), 'pro_kind' => 'manual'], ['id' => $member['id']]);
    } else {
        $wpdb->insert($table, [
            'google_sub' => 'pending:' . $p['email'], 'email' => $p['email'], 'name' => $p['name'], 'note' => $p['method'] . ' ' . $p['trx'],
            'created_at' => $now, 'last_seen' => $now, 'pro_until' => gmdate('Y-m-d H:i:s', time() + $days * DAY_IN_SECONDS), 'pro_kind' => 'manual',
        ]);
    }
    $wpdb->update(ma_pay_table(), ['status' => 'approved'] + $who, ['id' => $id]);
    wp_mail($p['email'], 'My Assistant প্রিমিয়াম চালু হয়েছে', "আপনার পেমেন্ট ({$p['method']}, TrxID {$p['trx']}) পেয়েছি — ধন্যবাদ!\n\nঅ্যাপে এই ইমেইলের ({$p['email']}) Google অ্যাকাউন্টে লগইন করলেই প্রিমিয়াম চালু হবে। আগে থেকে লগইন করা থাকলে অ্যাপ খুললেই চালু হয়ে যাবে।\n\n— My Assistant");
    if ($member) {
        ma_push_member((int) $member['id'], 'প্রিমিয়াম চালু হয়েছে 🎉', 'আপনার পেমেন্ট পেয়েছি — ধন্যবাদ! AI, বিজ্ঞাপন ছাড়া আর সব প্রিমিয়াম সুবিধা এখন চালু।', ['type' => 'pro']);
    }
    return [true, 'অনুমোদন দেওয়া হলো, ' . $p['email'] . '-এ প্রিমিয়াম চালু হলো।'];
}

add_action('admin_post_ma_pay_review', function () {
    ma_acc_guard('ma_pay_review');
    $user = wp_get_current_user();
    [$ok, $msg] = ma_pay_decide((int) ($_POST['id'] ?? 0), sanitize_key($_POST['decision'] ?? '') === 'approve', wp_unslash($_POST['reason'] ?? ''), !empty($_POST['tell']), $user ? $user->user_email : '');
    ma_acc_back($msg, $ok ? 'ok' : 'error', ['tab' => 'payments']);
});

add_action('admin_post_ma_pay_settings', function () {
    ma_acc_guard('ma_pay_settings', 'manage_options');
    update_option('ma_pay_yearly', max(1, (int) ($_POST['yearly'] ?? 999)));
    update_option('ma_pay_monthly', max(1, (int) ($_POST['monthly'] ?? 99)));
    update_option('ma_pay_methods', sanitize_textarea_field(wp_unslash($_POST['methods'] ?? '')));
    ma_acc_back('পেমেন্টের সেটিংস রাখা হয়েছে।', 'ok', ['tab' => 'payments']);
});

function ma_pay_pending_count() {
    global $wpdb;
    return (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . ma_pay_table() . " WHERE status = 'pending'");
}
