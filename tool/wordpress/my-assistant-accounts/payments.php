<?php
/**
 * Payments made outside Google Play (bKash, Nagad, Rocket, bank…): the
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
    $raw = (string) get_option('ma_pay_methods', "বিকাশ | 01XXXXXXXXX | Send Money\nনগদ | 01XXXXXXXXX | Send Money\nরকেট | 01XXXXXXXXX | Send Money\nব্যাংক ট্রান্সফার | হিসাব নং … | ব্যাংক, শাখা, হিসাবের নাম");
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

add_shortcode('my_assistant_payment', 'ma_pay_form');

function ma_pay_form() {
    $plans = ma_pay_plans();
    $methods = ma_pay_methods();
    $state = isset($_GET['ma_pay']) ? sanitize_key($_GET['ma_pay']) : '';
    ob_start();
    ?>
    <div class="ma-pay" id="ma-pay">
        <style>
        .ma-pay{--g:#0E7A5F;--gd:#0A5C47;--gt:#E7F4EF;--ink:#111827;--mut:#6B7280;--line:#E5E7EB;font-family:"Hind Siliguri",system-ui,sans-serif;color:var(--ink);max-width:560px;margin:0 auto}
        .ma-pay *{box-sizing:border-box}
        .ma-pay-card{background:#fff;border:1px solid var(--line);border-radius:20px;padding:24px;box-shadow:0 8px 30px -18px rgba(17,24,39,.35)}
        .ma-pay h3{margin:0 0 4px;font-size:22px}
        .ma-pay p{margin:0 0 12px;color:var(--mut);line-height:1.6}
        .ma-pay-steps{counter-reset:s;list-style:none;padding:0;margin:16px 0}
        .ma-pay-steps>li{counter-increment:s;position:relative;padding-left:40px;margin-bottom:18px}
        .ma-pay-steps>li::before{content:counter(s);position:absolute;left:0;top:0;width:28px;height:28px;border-radius:50%;background:var(--g);color:#fff;display:grid;place-items:center;font-weight:700;font-size:14px}
        .ma-pay-steps strong{display:block;margin-bottom:6px}
        .ma-pay-plans,.ma-pay-methods{display:grid;gap:8px}
        .ma-pay-plans{grid-template-columns:1fr 1fr}
        .ma-pay label.opt{display:block;cursor:pointer}
        .ma-pay label.opt input{position:absolute;opacity:0}
        .ma-pay label.opt>span{display:block;border:1.5px solid var(--line);border-radius:14px;padding:12px 14px;transition:all .15s}
        .ma-pay label.opt b{display:block;font-size:17px}
        .ma-pay label.opt small{color:var(--mut);font-size:13px}
        .ma-pay label.opt input:checked+span{border-color:var(--g);background:var(--gt)}
        .ma-pay label.opt input:focus-visible+span{outline:2px solid var(--g);outline-offset:2px}
        .ma-pay .num{font-family:ui-monospace,monospace;font-weight:700;color:var(--gd);font-size:15px;display:inline}
        .ma-pay .field{display:block;margin:10px 0;font-weight:600;font-size:14px}
        .ma-pay .field input,.ma-pay .field textarea{display:block;width:100%;margin-top:6px;height:46px;border:1px solid var(--line);border-radius:12px;padding:0 14px;font:inherit;font-weight:400;font-size:15px}
        .ma-pay .field textarea{height:72px;padding:10px 14px}
        .ma-pay .field input:focus,.ma-pay .field textarea:focus{outline:0;border-color:var(--g);box-shadow:0 0 0 3px rgba(14,122,95,.15)}
        .ma-pay .hint{font-weight:400;color:var(--mut);font-size:12.5px}
        .ma-pay button{width:100%;height:50px;border:0;border-radius:14px;background:var(--g);color:#fff;font:inherit;font-weight:700;font-size:16px;cursor:pointer;margin-top:8px}
        .ma-pay button:hover{background:var(--gd)}
        .ma-pay .hp{position:absolute;left:-9999px}
        .ma-pay .done{background:var(--gt);border-radius:16px;padding:18px;color:var(--gd)}
        .ma-pay .bad{background:#FFF1F2;border-radius:12px;padding:12px 14px;color:#BE123C;margin-bottom:12px}
        @media (max-width:480px){.ma-pay-card{padding:18px}.ma-pay-plans{grid-template-columns:1fr}}
        </style>
        <div class="ma-pay-card">
        <?php if ($state === 'ok') : ?>
            <div class="done">
                <h3>ধন্যবাদ! তথ্য পেয়েছি</h3>
                <p style="color:inherit;margin:0">আমরা পেমেন্ট মিলিয়ে দেখে সাধারণত কয়েক ঘণ্টার মধ্যে প্রো চালু করে দেবো, আর আপনার ইমেইলে জানাবো। তারপর অ্যাপে একই Google অ্যাকাউন্টে লগইন করলেই প্রো চালু হয়ে যাবে।</p>
            </div>
        <?php else : ?>
            <h3>My Assistant প্রো নিন</h3>
            <p>নিচের যেকোনো মাধ্যমে টাকা পাঠিয়ে তথ্যগুলো দিন। আমরা মিলিয়ে দেখে প্রো চালু করে দেবো।</p>
            <?php if ($state && $state !== 'ok') : ?>
                <div class="bad" role="alert"><?php echo esc_html(ma_pay_error_text($state)); ?></div>
            <?php endif; ?>
            <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
                <input type="hidden" name="action" value="ma_pay_submit">
                <input type="hidden" name="back" value="<?php echo esc_url(get_permalink() ?: home_url('/')); ?>">
                <?php wp_nonce_field('ma_pay_submit', 'ma_pay_nonce'); ?>
                <input class="hp" type="text" name="website" tabindex="-1" autocomplete="off" aria-hidden="true">
                <ol class="ma-pay-steps">
                    <li><strong>প্ল্যান বেছে নিন</strong>
                        <div class="ma-pay-plans">
                            <?php $want = isset($_GET['plan']) ? sanitize_key($_GET['plan']) : ''; $first = true; foreach ($plans as $key => $pl) : ?>
                                <label class="opt"><input type="radio" name="plan" value="<?php echo esc_attr($key); ?>" <?php checked(isset($plans[$want]) ? $key === $want : $first); ?> required><span><b>৳<?php echo esc_html(ma_acc_bn($pl['price'])); ?></b><small><?php echo esc_html($pl['label']); ?> · <?php echo esc_html(ma_acc_bn($pl['days'])); ?> দিন</small></span></label>
                            <?php $first = false; endforeach; ?>
                        </div>
                    </li>
                    <li><strong>যেভাবে টাকা পাঠিয়েছেন</strong>
                        <div class="ma-pay-methods">
                            <?php $first = true; foreach ($methods as $key => $m) : ?>
                                <label class="opt"><input type="radio" name="method" value="<?php echo esc_attr($key); ?>" <?php checked($first); ?> required><span><b><?php echo esc_html($m['name']); ?></b><small><span class="num"><?php echo esc_html($m['number']); ?></span><?php echo $m['how'] !== '' ? ' · ' . esc_html($m['how']) : ''; ?></small></span></label>
                            <?php $first = false; endforeach; ?>
                        </div>
                    </li>
                    <li><strong>পেমেন্টের তথ্য</strong>
                        <label class="field">যে নম্বর বা হিসাব থেকে পাঠিয়েছেন<input type="text" name="sender" required maxlength="64" autocomplete="tel" placeholder="01XXXXXXXXX"></label>
                        <label class="field">ট্রানজেকশন আইডি (TrxID / রেফারেন্স)<input type="text" name="trx" required maxlength="64" autocomplete="off" spellcheck="false" placeholder="যেমন 9A7KX2PQ1M"></label>
                    </li>
                    <li><strong>আপনার অ্যাকাউন্ট</strong>
                        <label class="field">যে Google ইমেইলে অ্যাপে লগইন করবেন<input type="email" name="email" required maxlength="190" autocomplete="email" placeholder="name@gmail.com"><span class="hint">এই ইমেইলেই প্রো চালু হবে।</span></label>
                        <label class="field">নাম<input type="text" name="name" maxlength="190" autocomplete="name"></label>
                        <label class="field">যোগাযোগের মোবাইল (ঐচ্ছিক)<input type="tel" name="phone" maxlength="32" autocomplete="tel"></label>
                        <label class="field">কিছু বলার থাকলে (ঐচ্ছিক)<textarea name="note" maxlength="500"></textarea></label>
                    </li>
                </ol>
                <button type="submit">তথ্য জমা দিন</button>
            </form>
        <?php endif; ?>
        </div>
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
    wp_mail($p['email'], 'My Assistant প্রো চালু হয়েছে', "আপনার পেমেন্ট ({$p['method']}, TrxID {$p['trx']}) পেয়েছি — ধন্যবাদ!\n\nঅ্যাপে এই ইমেইলের ({$p['email']}) Google অ্যাকাউন্টে লগইন করলেই প্রো চালু হবে। আগে থেকে লগইন করা থাকলে অ্যাপ খুললেই চালু হয়ে যাবে।\n\n— My Assistant");
    if ($member) {
        ma_push_member((int) $member['id'], 'প্রো চালু হয়েছে 🎉', 'আপনার পেমেন্ট পেয়েছি — ধন্যবাদ! AI, বিজ্ঞাপন ছাড়া আর সব প্রো সুবিধা এখন চালু।', ['type' => 'pro']);
    }
    return [true, 'অনুমোদন দেওয়া হলো, ' . $p['email'] . '-এ প্রো চালু হলো।'];
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
