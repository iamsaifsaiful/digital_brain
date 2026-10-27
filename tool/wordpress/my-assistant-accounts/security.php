<?php
/**
 * Security helpers (owner's review, 27 Oct):
 *  - sealing small secrets at rest (AES-256-GCM) with a key that does not
 *    live in the database;
 *  - two-step sign-in for the admin app: a 6-digit code from an
 *    authenticator app (TOTP, RFC 6238), required for every admin.
 */

if (!defined('ABSPATH')) {
    exit;
}

// ── Sealing small secrets ──

/**
 * The key for sealing. $strict (members' backup keys): only MA_DATA_KEY from
 * wp-config.php — not in the database; without it, none (the caller keeps
 * things as they were). Otherwise (admins' two-step secrets): from the
 * site's own salts — if those are ever changed, an admin sets two-step
 * sign-in up again (see ma_totp_reset).
 */
function ma_sec_key($strict = false) {
    if ($strict) {
        return defined('MA_DATA_KEY') && is_string(MA_DATA_KEY) && strlen(MA_DATA_KEY) >= 32 ? hash('sha256', 'ma-data-v1|' . MA_DATA_KEY, true) : null;
    }
    return hash('sha256', 'ma-site-v1|' . wp_salt('secure_auth'), true);
}

/** "enc1:" + base64(nonce 12 | tag 16 | text), or null when there is no key. */
function ma_sec_seal($plain, $strict = false) {
    $key = ma_sec_key($strict);
    if ($key === null || !function_exists('openssl_encrypt')) {
        return null;
    }
    $iv = random_bytes(12);
    $tag = '';
    $ct = openssl_encrypt((string) $plain, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag, 'ma', 16);
    return $ct === false ? null : 'enc1:' . base64_encode($iv . $tag . $ct);
}

/** What [ma_sec_seal] made, or null (not sealed, or the key is not this one). */
function ma_sec_open($sealed, $strict = false) {
    $sealed = (string) $sealed;
    if (strpos($sealed, 'enc1:') !== 0) {
        return null;
    }
    $key = ma_sec_key($strict);
    $raw = base64_decode(substr($sealed, 5), true);
    if ($key === null || $raw === false || strlen($raw) < 29) {
        return null;
    }
    $out = openssl_decrypt(substr($raw, 28), 'aes-256-gcm', $key, OPENSSL_RAW_DATA, substr($raw, 0, 12), substr($raw, 12, 16), 'ma');
    return $out === false ? null : $out;
}

// ── TOTP ──

function ma_b32_encode($bin) {
    $abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    $bits = '';
    foreach (str_split($bin) as $c) {
        $bits .= str_pad(decbin(ord($c)), 8, '0', STR_PAD_LEFT);
    }
    $out = '';
    foreach (str_split($bits, 5) as $chunk) {
        $out .= $abc[bindec(str_pad($chunk, 5, '0', STR_PAD_RIGHT))];
    }
    return $out;
}

function ma_b32_decode($s) {
    $abc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    $s = strtoupper(preg_replace('/[^A-Za-z2-7]/', '', (string) $s));
    $bits = '';
    foreach (str_split($s) as $c) {
        $bits .= str_pad(decbin(strpos($abc, $c)), 5, '0', STR_PAD_LEFT);
    }
    $out = '';
    foreach (str_split($bits, 8) as $byte) {
        if (strlen($byte) === 8) {
            $out .= chr(bindec($byte));
        }
    }
    return $out;
}

/** The 6-digit code for a 30-second step. */
function ma_totp_code($secret_b32, $step) {
    $h = hash_hmac('sha1', pack('J', $step), ma_b32_decode($secret_b32), true);
    $o = ord($h[19]) & 0x0f;
    $n = ((ord($h[$o]) & 0x7f) << 24) | (ord($h[$o + 1]) << 16) | (ord($h[$o + 2]) << 8) | ord($h[$o + 3]);
    return str_pad((string) ($n % 1000000), 6, '0', STR_PAD_LEFT);
}

/** The admin's secret (base32), or '' when two-step sign-in is not set up. */
function ma_totp_secret($user_id, $meta = 'ma_totp') {
    $s = ma_sec_open(get_user_meta($user_id, $meta, true));
    return is_string($s) ? $s : '';
}

function ma_totp_on($user_id) {
    return ma_totp_secret($user_id) !== '';
}

/**
 * Checks a code (this step or one either side, for a phone clock a little
 * off); a code is accepted once only.
 */
function ma_totp_check($user_id, $code, $meta = 'ma_totp') {
    $secret = ma_totp_secret($user_id, $meta);
    $code = preg_replace('/\D/', '', (string) $code);
    if ($secret === '' || strlen($code) !== 6) {
        return false;
    }
    $now = intdiv(time(), 30);
    $last = (int) get_user_meta($user_id, 'ma_totp_last', true);
    foreach ([0, -1, 1] as $d) {
        $step = $now + $d;
        if ($step > $last && hash_equals(ma_totp_code($secret, $step), $code)) {
            update_user_meta($user_id, 'ma_totp_last', $step);
            return true;
        }
    }
    return false;
}

/** The link an authenticator app reads (also typed in by hand as the key). */
function ma_totp_uri($user, $secret) {
    $label = rawurlencode('My Assistant:' . $user->user_email);
    return "otpauth://totp/$label?secret=$secret&issuer=" . rawurlencode('My Assistant') . '&digits=6&period=30';
}

// ── Setting it up (site page, each admin for themself) ──

add_action('admin_post_ma_totp_start', function () {
    ma_acc_guard('ma_totp_start');
    $uid = get_current_user_id();
    $sealed = ma_sec_seal(ma_b32_encode(random_bytes(20)));
    if ($sealed === null) {
        ma_acc_back('এই সার্ভারে এনক্রিপশন (OpenSSL) নেই — হোস্টিংকে জিজ্ঞেস করুন।', 'error', ['tab' => 'security']);
    }
    update_user_meta($uid, 'ma_totp_pending', $sealed);
    ma_acc_back('Authenticator অ্যাপে নিচের চাবিটা বসান, তারপর অ্যাপের ৬ সংখ্যার কোড দিয়ে নিশ্চিত করুন।', 'ok', ['tab' => 'security']);
});

add_action('admin_post_ma_totp_confirm', function () {
    ma_acc_guard('ma_totp_confirm');
    $uid = get_current_user_id();
    if (!ma_totp_check($uid, wp_unslash((string) ($_POST['code'] ?? '')), 'ma_totp_pending')) {
        ma_acc_back('কোড মেলেনি — অ্যাপে এখন যে কোড দেখাচ্ছে সেটা দিন (ফোনের সময় ঠিক আছে কিনা দেখুন)।', 'error', ['tab' => 'security']);
    }
    update_user_meta($uid, 'ma_totp', get_user_meta($uid, 'ma_totp_pending', true));
    delete_user_meta($uid, 'ma_totp_pending');
    // Every admin-app session made before is signed out.
    global $wpdb;
    $wpdb->delete(ma_ai_sessions_table(), ['user_id' => $uid, 'app' => 'admin']);
    ma_acc_back('দুই ধাপের লগইন চালু হলো। অ্যাডমিন অ্যাপে আবার লগইন করুন — পাসওয়ার্ডের পর এই কোড চাইবে।', 'ok', ['tab' => 'security']);
});

add_action('admin_post_ma_totp_reset', function () {
    ma_acc_guard('ma_totp_reset');
    $uid = get_current_user_id();
    // A secret this site can no longer read (its salts were changed) is reset by the signed-in admin alone.
    $unreadable = get_user_meta($uid, 'ma_totp', true) !== '' && !ma_totp_on($uid);
    if (!$unreadable && !ma_totp_check($uid, wp_unslash((string) ($_POST['code'] ?? '')))) {
        ma_acc_back('বদলাতে এখনকার কোডটা দিন — কোড মেলেনি।', 'error', ['tab' => 'security']);
    }
    delete_user_meta($uid, 'ma_totp');
    delete_user_meta($uid, 'ma_totp_last');
    ma_acc_back('পুরোনো চাবি মুছে গেছে — নতুন ফোনে আবার চালু করুন। চালু না করা পর্যন্ত অ্যাডমিন অ্যাপে লগইন হবে না।', 'ok', ['tab' => 'security']);
});

/** The site's নিরাপত্তা tab: two-step sign-in for the admin who is looking. */
function ma_acc_render_security() {
    $user = wp_get_current_user();
    $uid = (int) $user->ID;
    $on = ma_totp_on($uid);
    $pending = ma_totp_secret($uid, 'ma_totp_pending');
    $post = esc_url(admin_url('admin-post.php'));
    ?>
    <section class="ma-card pad" id="ma-2fa">
        <div class="ma-bar-title"><h2>দুই ধাপের লগইন (অ্যাডমিন অ্যাপ)</h2><span class="ma-pill <?php echo $on ? 'pro' : 'expired'; ?>"><?php echo $on ? 'চালু' : 'চালু হয়নি'; ?></span></div>
        <p class="muted">অ্যাডমিন অ্যাপে লগইনে পাসওয়ার্ডের পর ফোনের Authenticator অ্যাপের (Google Authenticator, Microsoft Authenticator…) ৬ সংখ্যার কোড লাগে। পাসওয়ার্ড কারও হাতে গেলেও কোড ছাড়া কেউ ঢুকতে পারবে না। প্রত্যেক অ্যাডমিন নিজের জন্য চালু করেন; চালু না করলে অ্যাডমিন অ্যাপে লগইন হয় না।</p>
        <?php if ($on) : ?>
            <p><strong>চালু আছে।</strong> ফোন বদলালে: এখনকার কোড দিয়ে পুরোনো চাবি মুছুন, তারপর নতুন ফোনে আবার চালু করুন।</p>
            <form method="post" action="<?php echo $post; ?>" class="ma-inline-form">
                <input type="hidden" name="action" value="ma_totp_reset"><?php wp_nonce_field('ma_totp_reset'); ?>
                <input type="text" name="code" inputmode="numeric" pattern="[0-9 ]{6,7}" maxlength="7" autocomplete="one-time-code" placeholder="৬ সংখ্যার কোড" required>
                <button class="ma-btn ghost" type="submit">চাবি মুছে নতুন করে চালু করব</button>
            </form>
        <?php elseif ($pending !== '') : ?>
            <ol>
                <li>ফোনে Authenticator অ্যাপ খুলুন › “+” › <em>Enter a setup key</em>।</li>
                <li>নাম: <code>My Assistant</code>, চাবি: <code style="font-size:16px;letter-spacing:1px"><?php echo esc_html(trim(chunk_split($pending, 4, ' '))); ?></code> (ধরন: Time based)।</li>
                <li>অ্যাপে যে ৬ সংখ্যার কোড দেখায়, এখানে দিন।</li>
            </ol>
            <p class="muted">অথবা এই লিংক Authenticator অ্যাপ সরাসরি পড়তে পারে: <code><?php echo esc_html(ma_totp_uri($user, $pending)); ?></code></p>
            <form method="post" action="<?php echo $post; ?>" class="ma-inline-form">
                <input type="hidden" name="action" value="ma_totp_confirm"><?php wp_nonce_field('ma_totp_confirm'); ?>
                <input type="text" name="code" inputmode="numeric" pattern="[0-9 ]{6,7}" maxlength="7" autocomplete="one-time-code" placeholder="৬ সংখ্যার কোড" required>
                <button class="ma-btn" type="submit">নিশ্চিত করুন</button>
            </form>
        <?php else : ?>
            <form method="post" action="<?php echo $post; ?>">
                <input type="hidden" name="action" value="ma_totp_start"><?php wp_nonce_field('ma_totp_start'); ?>
                <button class="ma-btn" type="submit">দুই ধাপের লগইন চালু করুন</button>
            </form>
        <?php endif; ?>
        <?php if (get_user_meta($uid, 'ma_totp', true) !== '' && !$on) : ?>
            <p><strong>পুরোনো চাবি আর পড়া যাচ্ছে না</strong> (সাইটের salt বদলেছে)। নিচের বোতামে মুছে নতুন করে চালু করুন।</p>
            <form method="post" action="<?php echo $post; ?>"><input type="hidden" name="action" value="ma_totp_reset"><?php wp_nonce_field('ma_totp_reset'); ?><button class="ma-btn ghost" type="submit">পুরোনো চাবি মুছুন</button></form>
        <?php endif; ?>
        <p class="muted">সাইটের wp-admin লগইনের জন্যও দুই ধাপ চালু রাখা ভালো — একটা বিনামূল্যের 2FA প্লাগইন (যেমন “Two Factor”) দিয়ে।</p>
    </section>
    <?php if (current_user_can('manage_options')) : $has = ma_sec_key(true) !== null; ?>
    <section class="ma-card pad" id="ma-datakey">
        <div class="ma-bar-title"><h2>সদস্যদের ব্যাকআপ-চাবির তালা</h2><span class="ma-pill <?php echo $has ? 'pro' : 'expired'; ?>"><?php echo $has ? 'চালু' : 'বন্ধ'; ?></span></div>
        <p class="muted">সদস্যদের Google Drive ব্যাকআপের চাবি এই সার্ভারের ডাটাবেসে থাকে। <code>wp-config.php</code>-এ একটা গোপন চাবি বসালে ডাটাবেসে চাবিগুলো তালাবদ্ধ থাকে — ডাটাবেসের কপি কারও হাতে গেলেও চাবি পাবে না।</p>
        <?php if ($has) : ?>
            <p><strong>চালু আছে।</strong> সাবধান: <code>MA_DATA_KEY</code> কখনো বদলাবেন বা মুছবেন না, আর সাইট সরালে <code>wp-config.php</code>-ও সাথে নেবেন — না হলে সদস্যরা নতুন ফোনে ব্যাকআপ খুলতে পারবেন না। লাইনটা নিরাপদ কোথাও কপি করে রাখুন।</p>
        <?php else : ?>
            <p>হোস্টিংয়ের File Manager-এ <code>wp-config.php</code> খুলে <code>/* That's all, stop editing! */</code> লাইনের উপরে এই লাইনটা বসান (প্রতিবার নতুন একটা দেখায় — একটাই বসাবেন):</p>
            <pre class="ma-mono" style="white-space:pre-wrap">define('MA_DATA_KEY', '<?php echo esc_html(bin2hex(random_bytes(32))); ?>');</pre>
            <p class="muted">বসানোর পর এই লাইনটাও নিরাপদ কোথাও কপি রাখুন। কখনো বদলাবেন বা মুছবেন না।</p>
        <?php endif; ?>
    </section>
    <?php endif; ?>
    <?php
}

// ── Admin-app sign-in: told by e-mail ──

function ma_sec_login_mail($user) {
    $ip = isset($_SERVER['REMOTE_ADDR']) ? sanitize_text_field(wp_unslash($_SERVER['REMOTE_ADDR'])) : '';
    $ua = isset($_SERVER['HTTP_USER_AGENT']) ? substr(sanitize_text_field(wp_unslash($_SERVER['HTTP_USER_AGENT'])), 0, 120) : '';
    wp_mail(
        $user->user_email,
        'My Assistant: অ্যাডমিন অ্যাপে নতুন লগইন',
        'আপনার অ্যাকাউন্ট দিয়ে অ্যাডমিন অ্যাপে লগইন হয়েছে — ' . wp_date('j M Y, g:i a') . "\nIP: $ip\nডিভাইস: $ua\n\nআপনি না হলে এখনই সাইটে পাসওয়ার্ড বদলান আর নিরাপত্তা ট্যাবে দুই ধাপের চাবি নতুন করুন।"
    );
}

/** Once, on updating to two-step sign-in: every admin-app session made with a password alone ends. */
add_action('init', function () {
    if (get_option('ma_sec_v') === '1') {
        return;
    }
    global $wpdb;
    $t = ma_ai_sessions_table();
    if ($wpdb->get_var($wpdb->prepare('SHOW TABLES LIKE %s', $t)) === $t) {
        $wpdb->delete($t, ['app' => 'admin']);
    }
    update_option('ma_sec_v', '1', false);
});

// ── The visitor's real address (for the try limits) ──

/**
 * REMOTE_ADDR, or — only when the request really comes through Cloudflare
 * (REMOTE_ADDR is one of Cloudflare's published ranges) — the address
 * Cloudflare saw. Behind Cloudflare every visitor would otherwise share a
 * few addresses and the limits would block everyone at once; trusting the
 * header from anywhere else would let anyone pick an address.
 */
function ma_client_ip() {
    $remote = isset($_SERVER['REMOTE_ADDR']) ? (string) $_SERVER['REMOTE_ADDR'] : '';
    $cf = isset($_SERVER['HTTP_CF_CONNECTING_IP']) ? trim((string) $_SERVER['HTTP_CF_CONNECTING_IP']) : '';
    if ($cf !== '' && filter_var($cf, FILTER_VALIDATE_IP) && ma_ip_in_cloudflare($remote)) {
        return $cf;
    }
    return filter_var($remote, FILTER_VALIDATE_IP) ? $remote : 'x';
}

function ma_ip_in_cloudflare($ip) {
    static $ranges = [
        '173.245.48.0/20', '103.21.244.0/22', '103.22.200.0/22', '103.31.4.0/22', '141.101.64.0/18', '108.162.192.0/18',
        '190.93.240.0/20', '188.114.96.0/20', '197.234.240.0/22', '198.41.128.0/17', '162.158.0.0/15', '104.16.0.0/13',
        '104.24.0.0/14', '172.64.0.0/13', '131.0.72.0/22',
        '2400:cb00::/32', '2606:4700::/32', '2803:f800::/32', '2405:b500::/32', '2405:8100::/32', '2a06:98c0::/29', '2c0f:f248::/32',
    ];
    $bin = @inet_pton((string) $ip);
    if ($bin === false) {
        return false;
    }
    foreach ($ranges as $r) {
        [$net, $bits] = explode('/', $r);
        $nb = inet_pton($net);
        if (strlen($nb) !== strlen($bin)) {
            continue;
        }
        $bytes = intdiv((int) $bits, 8);
        $rest = (int) $bits % 8;
        if (substr($bin, 0, $bytes) !== substr($nb, 0, $bytes)) {
            continue;
        }
        if ($rest === 0 || ((ord($bin[$bytes]) ^ ord($nb[$bytes])) & (0xff << (8 - $rest)) & 0xff) === 0) {
            return true;
        }
    }
    return false;
}
