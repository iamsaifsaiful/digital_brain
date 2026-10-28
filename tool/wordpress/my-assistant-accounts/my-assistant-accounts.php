<?php
/**
 * Plugin Name: My Assistant Accounts
 * Description: My Assistant অ্যাপের সদস্য — Google লগইন যাচাই, প্রিমিয়াম, পেমেন্ট, নোটিফিকেশন আর মতামত। শুধু নাম, ইমেইল, ছবি আর প্রিমিয়ামের তথ্য রাখে; ইউজারের হিসাব, নোট, পাসওয়ার্ড বা ব্যাকআপ কখনো এখানে আসে না।
 * Version: 1.25.1
 * Requires at least: 6.0
 * Requires PHP: 8.0
 * Author: My Assistant
 * License: GPL-2.0-or-later
 */

if (!defined('ABSPATH')) {
    exit;
}

const MA_ACC_VERSION = '1.25.1';
const MA_ACC_OPTION_CLIENTS = 'ma_acc_google_client_ids';
const MA_ACC_PER_PAGE = 20;

require_once __DIR__ . '/admin-view.php';
require_once __DIR__ . '/ai.php';
require_once __DIR__ . '/nlu.php';
require_once __DIR__ . '/ai-admin.php';
require_once __DIR__ . '/payments.php';
require_once __DIR__ . '/notices.php';
require_once __DIR__ . '/push.php';
require_once __DIR__ . '/admin-api.php';
require_once __DIR__ . '/feedback.php';
require_once __DIR__ . '/pro-page.php';
require_once __DIR__ . '/blood.php';
require_once __DIR__ . '/family.php';
require_once __DIR__ . '/metal.php';
require_once __DIR__ . '/finance.php';
require_once __DIR__ . '/errors.php';
require_once __DIR__ . '/bkash.php';
require_once __DIR__ . '/members.php';
require_once __DIR__ . '/security.php';

/** The members table. */
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
        google_sub varchar(200) NOT NULL,
        email varchar(190) NOT NULL,
        name varchar(190) NOT NULL DEFAULT '',
        picture varchar(500) NOT NULL DEFAULT '',
        note varchar(500) NOT NULL DEFAULT '',
        created_at datetime NOT NULL,
        last_seen datetime NOT NULL,
        app_version varchar(32) NOT NULL DEFAULT '',
        edition varchar(32) NOT NULL DEFAULT '',
        trial_started datetime NULL DEFAULT NULL,
        pro_until datetime NULL DEFAULT NULL,
        pro_kind varchar(32) NOT NULL DEFAULT '',
        backup_key varchar(160) NOT NULL DEFAULT '',
        PRIMARY KEY  (id),
        UNIQUE KEY google_sub (google_sub),
        KEY email (email)
    ) $charset;");
    ma_ai_install();
    ma_nlu_install();
    ma_pay_install();
    ma_note_install();
    ma_fb_install();
    ma_bl_install();
    ma_fam_install();
    ma_fin_install();
    ma_err_install();
    ma_bk_install();
    ma_acc_source_migrate();
    // Who may approve payments and manage members (the admin app signs in with these accounts).
    if (!get_role('ma_admin')) {
        add_role('ma_admin', 'My Assistant অ্যাডমিন', ['read' => true, 'ma_manage' => true]);
    }
    $owner = get_role('administrator');
    if ($owner) {
        $owner->add_cap('ma_manage');
    }
    update_option('ma_acc_db_version', MA_ACC_VERSION);
}

// An update of the plugin brings new columns without re-activating — on any
// request, since the apps may come before anyone opens wp-admin.
add_action('init', function () {
    if (get_option('ma_acc_db_version') !== MA_ACC_VERSION) {
        ma_acc_install();
    }
});

/** UTC "Y-m-d H:i:s" to a timestamp. */
function ma_acc_ts($mysql) {
    return $mysql ? strtotime($mysql . ' UTC') : 0;
}

/** free, trial, pro, expired (had Pro or a trial that ended), waiting (added by hand, not signed in yet). */
function ma_acc_status($row) {
    if (strpos((string) $row['google_sub'], 'pending:') === 0) {
        return 'waiting';
    }
    $until = ma_acc_ts($row['pro_until'] ?? null);
    if ($until > time()) {
        return ($row['pro_kind'] ?? '') === 'trial' ? 'trial' : 'pro';
    }
    return $until ? 'expired' : 'free';
}

// ── REST API: /wp-json/my-assistant/v1/… ──

add_action('rest_api_init', function () {
    register_rest_route('my-assistant/v1', '/login', [
        'methods' => 'POST',
        'callback' => 'ma_acc_login',
        'permission_callback' => '__return_true', // checked with Google's token below
    ]);
});

/** Too many requests from one address in an hour. */
function ma_acc_rate_limited() {
    $ip = ma_client_ip();
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

/**
 * The key that locks this member's Google Drive backup: random, made once,
 * given only to the member's own signed-in phone. The backup itself lives in
 * the member's Google Drive and never comes here, so neither Google nor this
 * server alone can open it.
 */
function ma_acc_backup_key($row) {
    global $wpdb;
    $stored = (string) ($row['backup_key'] ?? '');
    // Sealed with MA_DATA_KEY from wp-config.php (owner's review, 27 Oct): a
    // copy of the database alone does not give the keys. Without that key
    // here, a sealed one is never replaced — a new key would make the
    // member's backups unreadable for good.
    if (strpos($stored, 'enc1:') === 0) {
        $plain = ma_sec_open($stored, true);
        return is_string($plain) ? $plain : '';
    }
    $key = $stored;
    if (strlen($key) < 40) {
        if (empty($row['id']) || strpos((string) $row['google_sub'], 'pending:') === 0) {
            return $key;
        }
        $key = rtrim(strtr(base64_encode(random_bytes(32)), '+/', '-_'), '=');
    }
    $sealed = ma_sec_seal($key, true);
    if ($sealed !== null || $key !== $stored) {
        $wpdb->update(ma_acc_table(), ['backup_key' => $sealed ?? $key], ['id' => (int) $row['id']]);
    }
    return $key;
}

function ma_acc_answer($row) {
    $until = $row['pro_until'] ?? null;
    return [
        'backup_key' => ma_acc_backup_key($row),
        'ok' => true,
        'trial_used' => !empty($row['trial_started']),
        'pro_until' => $until ? gmdate('c', ma_acc_ts($until)) : null,
        'pro_kind' => (string) ($row['pro_kind'] ?? ''),
        'feedback_unread' => empty($row['id']) ? 0 : ma_fb_member_unread((int) $row['id']),
    ];
}

/** Only pictures from Google's own image host. */
function ma_acc_picture($url) {
    $url = esc_url_raw((string) $url);
    return preg_match('#^https://[a-z0-9-]+\.googleusercontent\.com/#i', $url) ? substr($url, 0, 500) : '';
}

function ma_acc_login(WP_REST_Request $req) {
    if (ma_acc_rate_limited()) {
        return new WP_Error('busy', 'too many requests', ['status' => 429]);
    }
    // Members' app older than the site's minimum (set on the settings page): asked to update first.
    $min = (string) get_option('ma_app_min', '');
    $have = (string) $req->get_param('app_version');
    if ($min !== '' && version_compare(preg_replace('/[^0-9.]/', '', explode('+', $have)[0]), $min, '<')) {
        return new WP_Error('update', 'update the app', ['status' => 426, 'min' => $min, 'url' => ma_app_update_url()]);
    }
    $c = ma_acc_verify($req->get_param('id_token'));
    if (is_wp_error($c)) {
        return $c;
    }
    global $wpdb;
    $table = ma_acc_table();
    $now = current_time('mysql', true);
    $fields = [
        'email' => sanitize_email($c['email']),
        'name' => substr(sanitize_text_field($c['name'] ?? ''), 0, 190),
        'picture' => ma_acc_picture($c['picture'] ?? ''),
        'last_seen' => $now,
        'app_version' => substr(sanitize_text_field((string) $req->get_param('app_version')), 0, 32),
        'edition' => substr(sanitize_key((string) $req->get_param('edition')), 0, 32),
    ];
    $row = ma_acc_row($c['sub']);
    if (!$row) {
        // Added by hand before the first sign-in (e.g. paid by bKash): claim it.
        $row = ma_acc_row('pending:' . strtolower($fields['email']));
        if ($row) {
            $fields['google_sub'] = $c['sub'];
        }
    }
    if ($row) {
        $wpdb->update($table, $fields, ['id' => $row['id']]);
    } else {
        $wpdb->insert($table, $fields + ['google_sub' => $c['sub'], 'created_at' => $now]);
    }
    $row = ma_acc_row($c['sub']);
    $set = ma_ai_settings();
    // A session for this phone: AI and refreshing the plan without signing in again.
    return rest_ensure_response(ma_acc_answer($row) + [
        'session' => ma_ai_new_session((int) $row['id']),
        'ai' => $set['on'] && ma_ai_key() !== '',
        'ai_left' => max(0, $set['per_user'] - ma_ai_used((int) $row['id'])),
    ]);
}


// ── Admin: the page, and its actions (each with a nonce, back to the page with a message) ──

add_action('admin_menu', function () {
    add_menu_page('My Assistant', 'My Assistant', 'ma_manage', 'my-assistant', 'ma_acc_admin', 'dashicons-groups', 80);
});

function ma_acc_back($msg, $type = 'ok', $extra = []) {
    wp_safe_redirect(add_query_arg(array_merge(['page' => 'my-assistant', 'ma_msg' => rawurlencode($msg), 'ma_type' => $type], $extra), admin_url('admin.php')));
    exit;
}

/** Admins (role "My Assistant অ্যাডমিন", or site administrators) manage members and payments; only site administrators change settings. */
function ma_acc_guard($action, $cap = 'ma_manage') {
    if (!current_user_can($cap)) {
        wp_die('Not allowed', 403);
    }
    check_admin_referer($action);
}

/** Adds [days] of Pro from today, or from the end of the Pro already running. */
function ma_acc_extend($row, $days) {
    $base = max(time(), ma_acc_ts($row['pro_until'] ?? null));
    return gmdate('Y-m-d H:i:s', $base + $days * DAY_IN_SECONDS);
}

add_action('admin_post_ma_acc_settings', function () {
    ma_acc_guard('ma_acc_settings', 'manage_options');
    update_option(MA_ACC_OPTION_CLIENTS, sanitize_text_field(wp_unslash($_POST['client_ids'] ?? '')));
    ma_acc_back('সেটিংস রাখা হয়েছে।', 'ok', ['tab' => 'settings']);
});

add_action('admin_post_ma_acc_add', function () {
    ma_acc_guard('ma_acc_add');
    global $wpdb;
    $table = ma_acc_table();
    $email = strtolower(sanitize_email(wp_unslash($_POST['email'] ?? '')));
    $name = substr(sanitize_text_field(wp_unslash($_POST['name'] ?? '')), 0, 190);
    $days = max(0, min(3660, (int) ($_POST['days'] ?? 0)));
    $note = substr(sanitize_text_field(wp_unslash($_POST['note'] ?? '')), 0, 500);
    if (!is_email($email)) {
        ma_acc_back('ঠিক ইমেইল দিন।', 'error');
    }
    $row = $wpdb->get_row($wpdb->prepare("SELECT * FROM $table WHERE email = %s ORDER BY id LIMIT 1", $email), ARRAY_A);
    if ($row) {
        $wpdb->update($table, ['pro_until' => $days ? ma_acc_extend($row, $days) : $row['pro_until'], 'pro_kind' => $days ? 'manual' : $row['pro_kind'], 'note' => $note ?: $row['note']], ['id' => $row['id']]);
        ma_acc_back('এই ইমেইলের সদস্য আগেই ছিলেন — প্রিমিয়াম যোগ করা হলো।');
    }
    $now = current_time('mysql', true);
    $wpdb->insert($table, [
        'google_sub' => 'pending:' . $email,
        'email' => $email,
        'name' => $name,
        'note' => $note,
        'created_at' => $now,
        'last_seen' => $now,
        'pro_until' => $days ? gmdate('Y-m-d H:i:s', time() + $days * DAY_IN_SECONDS) : null,
        'pro_kind' => $days ? 'manual' : '',
    ]);
    ma_acc_back('যোগ করা হলো। এই ইমেইলে অ্যাপে Google দিয়ে লগইন করলেই প্রিমিয়াম চালু হবে।');
});

add_action('admin_post_ma_acc_edit', function () {
    ma_acc_guard('ma_acc_edit');
    global $wpdb;
    $table = ma_acc_table();
    $id = (int) ($_POST['id'] ?? 0);
    $row = $wpdb->get_row($wpdb->prepare("SELECT * FROM $table WHERE id = %d", $id), ARRAY_A);
    if (!$row) {
        ma_acc_back('সদস্য পাওয়া যায়নি।', 'error');
    }
    $mode = sanitize_key($_POST['mode'] ?? 'add');
    $days = max(0, min(3660, (int) ($_POST['days'] ?? 0)));
    $data = ['note' => substr(sanitize_text_field(wp_unslash($_POST['note'] ?? '')), 0, 500)];
    if ($mode === 'stop') {
        $data['pro_until'] = null;
        $data['pro_kind'] = '';
    } elseif ($days > 0) {
        $data['pro_until'] = ma_acc_extend($row, $days);
        $data['pro_kind'] = 'manual';
    }
    $wpdb->update($table, $data, ['id' => $id]);
    ma_acc_back($mode === 'stop' ? 'প্রিমিয়াম বন্ধ করা হলো।' : 'রাখা হয়েছে। সদস্য অ্যাপে আবার লগইন করলে নতুন প্রিমিয়াম দেখাবে।');
});

add_action('admin_post_ma_acc_delete', function () {
    ma_acc_guard('ma_acc_delete');
    global $wpdb;
    $id = (int) ($_POST['id'] ?? 0);
    $wpdb->delete(ma_acc_table(), ['id' => $id]);
    $wpdb->delete(ma_ai_sessions_table(), ['user_id' => $id]);
    $wpdb->delete(ma_ai_usage_table(), ['user_id' => $id]);
    ma_nlu_forget_member($id);
    ma_fam_forget_member($id);
    ma_acc_back('সদস্যের তথ্য মুছে ফেলা হলো। আবার লগইন করলে নতুন করে যোগ হবেন।');
});

/** Excel opens this CSV directly (UTF-8 with BOM keeps Bangla readable). */
add_action('admin_post_ma_acc_export', function () {
    ma_acc_guard('ma_acc_export');
    global $wpdb;
    $rows = ma_acc_member_rows(sanitize_text_field(wp_unslash((string) ($_POST['q'] ?? ''))), sanitize_key((string) ($_POST['status'] ?? '')), sanitize_text_field((string) ($_POST['joined'] ?? '')), sanitize_key((string) ($_POST['src'] ?? '')), 100000, 0, 'created_at DESC');
    nocache_headers();
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename=my-assistant-members-' . gmdate('Y-m-d') . '.csv');
    $out = fopen('php://output', 'w');
    fwrite($out, "\xEF\xBB\xBF");
    fputcsv($out, ['নাম', 'ইমেইল', 'অবস্থা', 'প্রিমিয়াম পর্যন্ত', 'প্রিমিয়াম কোথা থেকে', 'ট্রায়াল শুরু', 'যোগ দিয়েছেন', 'শেষ দেখা', 'সংস্করণ', 'নোট']);
    $labels = ma_acc_status_labels();
    foreach ($rows as $r) {
        $cells = [$r['name'], $r['email'], $labels[ma_acc_status($r)][0], $r['pro_until'], ma_acc_source_label($r), $r['trial_started'], $r['created_at'], $r['last_seen'], trim($r['app_version'] . ' ' . $r['edition']), $r['note']];
        // A cell starting with = + - @ would run as a formula in Excel.
        fputcsv($out, array_map(function ($v) {
            $v = (string) $v;
            return preg_match('/^[=+\-@]/', $v) ? "'" . $v : $v;
        }, $cells));
    }
    fclose($out);
    exit;
});

/** The admin page: reads the data, then draws it (admin-view.php). */
function ma_acc_admin() {
    if (!current_user_can('ma_manage')) {
        return;
    }
    global $wpdb;
    $table = ma_acc_table();
    $tab = sanitize_key($_GET['tab'] ?? 'members');
    $q = sanitize_text_field(wp_unslash($_GET['q'] ?? ''));
    $status = sanitize_key($_GET['status'] ?? '');
    $page = max(1, (int) ($_GET['paged'] ?? 1));

    $joined = sanitize_text_field((string) ($_GET['joined'] ?? ''));
    // The month and day pickers.
    foreach (['jd', 'jm'] as $k) {
        if (!empty($_GET[$k])) {
            $joined = sanitize_text_field((string) $_GET[$k]);
            break;
        }
    }
    $src = sanitize_key((string) ($_GET['src'] ?? ''));
    $found = ma_acc_member_count($q, $status, $joined, $src);
    $rows = ma_acc_member_rows($q, $status, $joined, $src, MA_ACC_PER_PAGE, ($page - 1) * MA_ACC_PER_PAGE);
    $stats = ma_acc_member_stats();

    $extra = [];
    if ($tab === 'payments') {
        $extra['bkash'] = ma_bk_overview();
        $pst = sanitize_key($_GET['pst'] ?? 'pending');
        $pt = ma_pay_table();
        $extra['pst'] = $pst;
        $extra['payments'] = $pst === 'all'
            ? $wpdb->get_results("SELECT * FROM $pt ORDER BY created_at DESC LIMIT 100", ARRAY_A)
            : $wpdb->get_results($wpdb->prepare("SELECT * FROM $pt WHERE status = %s ORDER BY created_at DESC LIMIT 100", $pst), ARRAY_A);
        $extra['pay_counts'] = [];
        foreach ($wpdb->get_results("SELECT status, COUNT(*) n, COALESCE(SUM(amount),0) amt FROM $pt GROUP BY status", ARRAY_A) as $c) {
            $extra['pay_counts'][$c['status']] = ['n' => (int) $c['n'], 'amt' => (int) $c['amt']];
        }
        $extra['pay_month'] = (int) $wpdb->get_var($wpdb->prepare("SELECT COALESCE(SUM(amount),0) FROM $pt WHERE status = 'approved' AND reviewed_at >= %s", gmdate('Y-m-01')));
        $extra['methods_raw'] = (string) get_option('ma_pay_methods', implode("\n", array_map(function ($m) {
            return $m['name'] . ' | ' . $m['number'] . ' | ' . $m['how'];
        }, ma_pay_methods())));
        $extra['plans'] = ma_pay_plans();
    }
    if ($tab === 'feedback') {
        $who = sanitize_text_field(wp_unslash((string) ($_GET['who'] ?? '')));
        // An old link to one conversation opens its member's inbox.
        if ($who === '' && !empty($_GET['fb'])) {
            $who = ma_fb_key_of((int) $_GET['fb']);
        }
        if ($who !== '') {
            $extra['inbox_one'] = ma_fb_inbox_one($who);
        }
        $fst = sanitize_key($_GET['fst'] ?? 'open');
        $extra['fst'] = in_array($fst, ['open', 'done', 'all'], true) ? $fst : 'open';
        $extra['fq'] = sanitize_text_field(wp_unslash((string) ($_GET['fq'] ?? '')));
        $extra['inbox'] = ma_fb_inbox($extra['fst'], $extra['fq']);
    }
    if ($tab === 'finance' && current_user_can('manage_options')) {
        $month = sanitize_text_field((string) ($_GET['month'] ?? ''));
        $extra['finance'] = ma_fin_summary($month);
        $extra['finance']['lines'] = ma_fin_month_lines($month, sanitize_key((string) ($_GET['fk'] ?? '')), sanitize_text_field(wp_unslash((string) ($_GET['fc'] ?? ''))));
    }
    if ($tab === 'heirs') {
        $extra['heirs'] = ma_fam_claims_list('all');
    }
    if ($tab === 'nlu') {
        $extra['nlu'] = ['settings' => ma_nlu_settings(), 'models' => ma_nlu_models_list(), 'review' => ma_nlu_review_list(30), 'review_all' => ma_nlu_review_list(500), 'intents' => array_keys(MA_NLU_INTENTS), 'overview' => ma_nlu_overview()];
    }
    if ($tab === 'notices') {
        $extra['notices'] = $wpdb->get_results('SELECT * FROM ' . ma_note_table() . ' ORDER BY active DESC, id DESC', ARRAY_A);
        $extra['note_overview'] = ma_note_overview();
        $extra['note_day'] = ma_note_day(sanitize_text_field((string) ($_GET['nday'] ?? '')));
    }
    $extra['pending'] = ma_pay_pending_count();
    $extra['fb_new'] = ma_fb_new_count();
    $extra['heirs_pending'] = ma_fam_claims_pending();

    ma_acc_render($extra + [
        'tab' => $tab,
        'q' => $q,
        'status' => $status,
        'joined' => $joined,
        'src' => $src,
        'growth' => $tab === 'members' ? ma_acc_growth() : null,
        'page' => $page,
        'pages' => max(1, (int) ceil($found / MA_ACC_PER_PAGE)),
        'found' => $found,
        'rows' => $rows,
        'stats' => $stats,
        'clients' => (string) get_option(MA_ACC_OPTION_CLIENTS, ''),
        'msg' => isset($_GET['ma_msg']) ? sanitize_text_field(rawurldecode(wp_unslash($_GET['ma_msg']))) : '',
        'msg_type' => sanitize_key($_GET['ma_type'] ?? 'ok'),
        'endpoint' => rest_url('my-assistant/v1/login'),
        'ai' => ma_ai_settings() + ['source' => ma_ai_key_source(), 'tail' => substr(ma_ai_key(), -4), 'gemini_source' => ma_nlu_gemini_key_source(), 'gemini_tail' => substr(ma_nlu_gemini_key(), -4)],
        'ai_stats' => ma_ai_today_stats(),
        'ai_costs' => ma_ai_cost_report(),
        'push' => ['source' => ma_push_source()],
        'admins' => ma_admin_users(),
        'can_settings' => current_user_can('manage_options'),
    ]);
}
