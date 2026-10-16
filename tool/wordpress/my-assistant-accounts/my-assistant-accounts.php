<?php
/**
 * Plugin Name: My Assistant Accounts
 * Description: My Assistant অ্যাপের ইউজার অ্যাকাউন্ট — Google লগইন যাচাই, ফ্রি ট্রায়াল আর প্রো। শুধু নাম, ইমেইল আর প্রো-র তথ্য রাখে; ইউজারের হিসাব, নোট, পাসওয়ার্ড বা ব্যাকআপ কখনো এখানে আসে না।
 * Version: 1.0.0
 * Requires at least: 6.0
 * Requires PHP: 7.4
 * Author: My Assistant
 * License: GPL-2.0-or-later
 */

if (!defined('ABSPATH')) {
    exit;
}

const MA_ACC_VERSION = '1.0.0';
const MA_ACC_OPTION_CLIENTS = 'ma_acc_google_client_ids';

/** The users table. */
function ma_acc_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_users';
}

register_activation_hook(__FILE__, 'ma_acc_install');
function ma_acc_install() {
    global $wpdb;
    $table = ma_acc_table();
    $charset = $wpdb->get_charset_collate();
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    dbDelta("CREATE TABLE $table (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        google_sub varchar(64) NOT NULL,
        email varchar(190) NOT NULL,
        name varchar(190) NOT NULL DEFAULT '',
        created_at datetime NOT NULL,
        last_seen datetime NOT NULL,
        app_version varchar(32) NOT NULL DEFAULT '',
        edition varchar(32) NOT NULL DEFAULT '',
        trial_started datetime NULL DEFAULT NULL,
        pro_until datetime NULL DEFAULT NULL,
        pro_kind varchar(32) NOT NULL DEFAULT '',
        PRIMARY KEY  (id),
        UNIQUE KEY google_sub (google_sub),
        KEY email (email)
    ) $charset;");
    update_option('ma_acc_db_version', MA_ACC_VERSION);
}

// ── REST API: /wp-json/my-assistant/v1/… ──

add_action('rest_api_init', function () {
    register_rest_route('my-assistant/v1', '/login', [
        'methods' => 'POST',
        'callback' => 'ma_acc_login',
        'permission_callback' => '__return_true', // checked with Google's token below
    ]);
    register_rest_route('my-assistant/v1', '/trial', [
        'methods' => 'POST',
        'callback' => 'ma_acc_trial',
        'permission_callback' => '__return_true',
    ]);
});

/** Too many requests from one address in an hour. */
function ma_acc_rate_limited() {
    $ip = isset($_SERVER['REMOTE_ADDR']) ? sanitize_text_field(wp_unslash($_SERVER['REMOTE_ADDR'])) : 'x';
    $key = 'ma_acc_rl_' . md5($ip);
    $n = (int) get_transient($key);
    if ($n >= 60) {
        return true;
    }
    set_transient($key, $n + 1, HOUR_IN_SECONDS);
    return false;
}

/**
 * Checks a Google sign-in token with Google and returns its claims, or a
 * WP_Error. The token must be for one of our OAuth client IDs.
 */
function ma_acc_verify($id_token) {
    if (!is_string($id_token) || strlen($id_token) < 100 || strlen($id_token) > 4096) {
        return new WP_Error('bad_token', 'invalid token', ['status' => 400]);
    }
    $res = wp_remote_get('https://oauth2.googleapis.com/tokeninfo?id_token=' . rawurlencode($id_token), ['timeout' => 10]);
    if (is_wp_error($res) || wp_remote_retrieve_response_code($res) !== 200) {
        return new WP_Error('bad_token', 'token not accepted', ['status' => 401]);
    }
    $c = json_decode(wp_remote_retrieve_body($res), true);
    $allowed = array_filter(array_map('trim', explode(',', (string) get_option(MA_ACC_OPTION_CLIENTS, ''))));
    $iss_ok = in_array($c['iss'] ?? '', ['accounts.google.com', 'https://accounts.google.com'], true);
    $aud_ok = !empty($allowed) && in_array($c['aud'] ?? '', $allowed, true);
    $exp_ok = (int) ($c['exp'] ?? 0) > time();
    $mail_ok = ($c['email_verified'] ?? '') === 'true' || ($c['email_verified'] ?? false) === true;
    if (!$iss_ok || !$aud_ok || !$exp_ok || !$mail_ok || empty($c['sub']) || empty($c['email'])) {
        return new WP_Error('bad_token', 'token not for this app', ['status' => 401]);
    }
    return $c;
}

function ma_acc_row($sub) {
    global $wpdb;
    $table = ma_acc_table();
    return $wpdb->get_row($wpdb->prepare("SELECT * FROM $table WHERE google_sub = %s", $sub), ARRAY_A);
}

function ma_acc_answer($row) {
    $until = $row['pro_until'] ?? null;
    return [
        'ok' => true,
        'trial_used' => !empty($row['trial_started']),
        'pro_until' => $until ? gmdate('c', strtotime($until . ' UTC')) : null,
        'pro_kind' => (string) ($row['pro_kind'] ?? ''),
    ];
}

function ma_acc_login(WP_REST_Request $req) {
    if (ma_acc_rate_limited()) {
        return new WP_Error('busy', 'too many requests', ['status' => 429]);
    }
    $c = ma_acc_verify($req->get_param('id_token'));
    if (is_wp_error($c)) {
        return $c;
    }
    global $wpdb;
    $table = ma_acc_table();
    $now = current_time('mysql', true);
    $version = substr(sanitize_text_field((string) $req->get_param('app_version')), 0, 32);
    $edition = substr(sanitize_key((string) $req->get_param('edition')), 0, 32);
    $email = sanitize_email($c['email']);
    $name = substr(sanitize_text_field($c['name'] ?? ''), 0, 190);
    $row = ma_acc_row($c['sub']);
    if ($row) {
        $wpdb->update($table, ['email' => $email, 'name' => $name, 'last_seen' => $now, 'app_version' => $version, 'edition' => $edition], ['id' => $row['id']]);
    } else {
        $wpdb->insert($table, ['google_sub' => $c['sub'], 'email' => $email, 'name' => $name, 'created_at' => $now, 'last_seen' => $now, 'app_version' => $version, 'edition' => $edition]);
    }
    return rest_ensure_response(ma_acc_answer(ma_acc_row($c['sub'])));
}

function ma_acc_trial(WP_REST_Request $req) {
    if (ma_acc_rate_limited()) {
        return new WP_Error('busy', 'too many requests', ['status' => 429]);
    }
    $c = ma_acc_verify($req->get_param('id_token'));
    if (is_wp_error($c)) {
        return $c;
    }
    global $wpdb;
    $row = ma_acc_row($c['sub']);
    if (!$row) {
        return new WP_Error('no_user', 'log in first', ['status' => 404]);
    }
    if (empty($row['trial_started'])) {
        $now = current_time('mysql', true);
        $until = gmdate('Y-m-d H:i:s', time() + 7 * DAY_IN_SECONDS);
        $data = ['trial_started' => $now];
        if (empty($row['pro_until']) || strtotime($row['pro_until'] . ' UTC') < time()) {
            $data['pro_until'] = $until;
            $data['pro_kind'] = 'trial';
        }
        $wpdb->update(ma_acc_table(), $data, ['id' => $row['id']]);
    }
    return rest_ensure_response(ma_acc_answer(ma_acc_row($c['sub'])));
}

// ── Admin page: settings, users, and Pro given by hand (e.g. paid by bKash on the website) ──

add_action('admin_menu', function () {
    add_menu_page('My Assistant', 'My Assistant', 'manage_options', 'my-assistant', 'ma_acc_admin', 'dashicons-groups', 80);
});

function ma_acc_admin() {
    if (!current_user_can('manage_options')) {
        return;
    }
    global $wpdb;
    $table = ma_acc_table();
    $msg = '';
    if (isset($_POST['ma_acc_save']) && check_admin_referer('ma_acc_settings')) {
        $ids = sanitize_text_field(wp_unslash($_POST['client_ids'] ?? ''));
        update_option(MA_ACC_OPTION_CLIENTS, $ids);
        $msg = 'সেটিংস রাখা হয়েছে।';
    }
    if (isset($_POST['ma_acc_pro']) && check_admin_referer('ma_acc_pro')) {
        $email = sanitize_email(wp_unslash($_POST['email'] ?? ''));
        $days = max(0, min(3660, (int) ($_POST['days'] ?? 0)));
        $row = $wpdb->get_row($wpdb->prepare("SELECT * FROM $table WHERE email = %s", $email), ARRAY_A);
        if (!$row) {
            $msg = 'এই ইমেইলে কোনো ইউজার নেই — আগে অ্যাপে Google দিয়ে লগইন করতে বলুন।';
        } elseif ($days === 0) {
            $wpdb->update($table, ['pro_until' => null, 'pro_kind' => ''], ['id' => $row['id']]);
            $msg = 'প্রো বন্ধ করা হলো: ' . esc_html($email);
        } else {
            $base = (!empty($row['pro_until']) && strtotime($row['pro_until'] . ' UTC') > time()) ? strtotime($row['pro_until'] . ' UTC') : time();
            $wpdb->update($table, ['pro_until' => gmdate('Y-m-d H:i:s', $base + $days * DAY_IN_SECONDS), 'pro_kind' => 'manual'], ['id' => $row['id']]);
            $msg = 'প্রো দেওয়া হলো: ' . esc_html($email) . ' (' . $days . ' দিন)। অ্যাপে (সেটিংস › Google অ্যাকাউন্ট) লগআউট করে আবার লগইন করলে চালু হবে।';
        }
    }
    $total = (int) $wpdb->get_var("SELECT COUNT(*) FROM $table");
    $pro = (int) $wpdb->get_var("SELECT COUNT(*) FROM $table WHERE pro_until > UTC_TIMESTAMP() AND pro_kind <> 'trial'");
    $trial = (int) $wpdb->get_var("SELECT COUNT(*) FROM $table WHERE pro_until > UTC_TIMESTAMP() AND pro_kind = 'trial'");
    $rows = $wpdb->get_results("SELECT email, name, created_at, last_seen, app_version, edition, trial_started, pro_until, pro_kind FROM $table ORDER BY last_seen DESC LIMIT 200", ARRAY_A);
    ?>
    <div class="wrap">
        <h1>My Assistant — ইউজার</h1>
        <?php if ($msg) : ?><div class="notice notice-info"><p><?php echo esc_html($msg); ?></p></div><?php endif; ?>
        <p>মোট ইউজার: <strong><?php echo (int) $total; ?></strong> · প্রো: <strong><?php echo (int) $pro; ?></strong> · ট্রায়ালে: <strong><?php echo (int) $trial; ?></strong></p>

        <h2>সেটিংস</h2>
        <form method="post">
            <?php wp_nonce_field('ma_acc_settings'); ?>
            <p><label>Google OAuth Web client ID (একাধিক হলে কমা দিয়ে)<br>
                <input type="text" name="client_ids" class="large-text" value="<?php echo esc_attr(get_option(MA_ACC_OPTION_CLIENTS, '')); ?>"></label></p>
            <p><button class="button button-primary" name="ma_acc_save" value="1">রাখুন</button></p>
        </form>

        <h2>হাতে প্রো দিন (যেমন ওয়েবসাইটে বিকাশে পেমেন্ট)</h2>
        <form method="post">
            <?php wp_nonce_field('ma_acc_pro'); ?>
            <input type="email" name="email" placeholder="ইউজারের Google ইমেইল" required>
            <input type="number" name="days" min="0" max="3660" value="365" style="width:90px"> দিন (০ = প্রো বন্ধ)
            <button class="button" name="ma_acc_pro" value="1">দিন</button>
        </form>

        <h2>সাম্প্রতিক ২০০ জন</h2>
        <table class="widefat striped">
            <thead><tr><th>ইমেইল</th><th>নাম</th><th>যোগ দিয়েছেন</th><th>শেষ দেখা</th><th>সংস্করণ</th><th>ট্রায়াল</th><th>প্রো পর্যন্ত</th></tr></thead>
            <tbody>
            <?php foreach ($rows as $r) : ?>
                <tr>
                    <td><?php echo esc_html($r['email']); ?></td>
                    <td><?php echo esc_html($r['name']); ?></td>
                    <td><?php echo esc_html($r['created_at']); ?></td>
                    <td><?php echo esc_html($r['last_seen']); ?></td>
                    <td><?php echo esc_html($r['app_version'] . ' ' . $r['edition']); ?></td>
                    <td><?php echo $r['trial_started'] ? esc_html($r['trial_started']) : '—'; ?></td>
                    <td><?php echo $r['pro_until'] ? esc_html($r['pro_until'] . ' (' . $r['pro_kind'] . ')') : '—'; ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
        <p style="color:#666">সময় UTC-তে। এখানে শুধু নাম, ইমেইল আর প্রো-র তথ্য থাকে — ইউজারের হিসাব, নোট, পাসওয়ার্ড বা ব্যাকআপ কখনো আসে না।</p>
    </div>
    <?php
}
