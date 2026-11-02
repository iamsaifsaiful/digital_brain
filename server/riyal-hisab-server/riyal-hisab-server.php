<?php
/**
 * Plugin Name: Remit Khata Server (রেমিট খাতা)
 * Description: রেমিট খাতা অ্যাপের সার্ভার — এডমিন ও এজেন্টদের লগইন, সব ফোনে একই হিসাব, এজেন্টকে নোটিফিকেশন। এখানে শুধু মূল এডমিন আর Firebase ঠিক করা যায়; বাকি সব অ্যাপ থেকে। রেকর্ড এখানে শুধু দেখা যায়।
 * Version: 1.2.0
 * Requires at least: 6.0
 * Requires PHP: 8.0
 * Author: Owlgorithm Labs
 * Author URI: https://owlgorithmlabs.com/
 * License: GPL-2.0-or-later
 */

if (!defined('ABSPATH')) {
    exit;
}

const RH_VERSION = '1.2.0';

/** What an admin may do; the main admin may do all of it. */
const RH_PERMS = [
    'send' => 'নতুন পাঠানো (গ্রাহক যোগসহ)',
    'deposit' => 'রিয়াল জমা নেওয়া',
    'edit' => 'লেনদেন সংশোধন ও বাতিল',
    'customers' => 'গ্রাহকের প্রোফাইল বদল',
    'loss' => 'লস ধরা',
    'agent_pay' => 'এজেন্টকে টাকা দেওয়া',
    'agents' => 'এজেন্ট যোগ ও বদল',
    'expense' => 'খরচ ও দিন শেষের হিসাব',
    'reports' => 'রিপোর্ট, লগ ও PDF দেখা',
    'users' => 'এডমিন ও এজেন্টের লগইন',
    'settings' => 'সেটিংস বদল',
];

/** The permissions of a user row: all for the main admin, none for an agent. */
function rh_perms($u) {
    if (($u['role'] ?? '') === 'owner') {
        return array_keys(RH_PERMS);
    }
    if (($u['role'] ?? '') !== 'admin') {
        return [];
    }
    $p = json_decode((string) ($u['perms'] ?? ''), true);
    return is_array($p) ? array_values(array_intersect(array_keys(RH_PERMS), $p)) : array_keys(RH_PERMS);
}

function rh_can($u, $perm) {
    return in_array($perm, rh_perms($u), true);
}
const RH_NS = 'rbh/v1';

require_once __DIR__ . '/ledger.php';
require_once __DIR__ . '/push.php';
require_once __DIR__ . '/sync.php';
require_once __DIR__ . '/agent.php';
require_once __DIR__ . '/users.php';
require_once __DIR__ . '/admin-pages.php';
require_once __DIR__ . '/gdrive.php';

function rh_t($name) {
    global $wpdb;
    return $wpdb->prefix . 'rh_' . $name;
}

register_activation_hook(__FILE__, 'rh_install');
function rh_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $c = $wpdb->get_charset_collate();
    dbDelta('CREATE TABLE ' . rh_t('users') . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        role varchar(16) NOT NULL DEFAULT 'agent',
        name varchar(190) NOT NULL DEFAULT '',
        login varchar(64) NOT NULL,
        pass_hash varchar(255) NOT NULL DEFAULT '',
        agent_rid varchar(64) NOT NULL DEFAULT '',
        status varchar(16) NOT NULL DEFAULT 'active',
        perms text NULL,
        created_at datetime NOT NULL,
        created_by bigint(20) unsigned NOT NULL DEFAULT 0,
        last_seen datetime NULL DEFAULT NULL,
        PRIMARY KEY  (id),
        UNIQUE KEY login (login)
    ) $c;");
    dbDelta('CREATE TABLE ' . rh_t('sessions') . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        user_id bigint(20) unsigned NOT NULL,
        token_hash char(64) NOT NULL,
        device varchar(120) NOT NULL DEFAULT '',
        fcm_token varchar(300) NOT NULL DEFAULT '',
        created_at datetime NOT NULL,
        last_seen datetime NOT NULL,
        PRIMARY KEY  (id),
        UNIQUE KEY token_hash (token_hash),
        KEY user_id (user_id)
    ) $c;");
    dbDelta('CREATE TABLE ' . rh_t('records') . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        kind varchar(16) NOT NULL,
        rid varchar(64) NOT NULL,
        rev bigint(20) unsigned NOT NULL DEFAULT 0,
        agent_rid varchar(64) NOT NULL DEFAULT '',
        cust_rid varchar(64) NOT NULL DEFAULT '',
        at datetime NULL DEFAULT NULL,
        data longtext NOT NULL,
        updated_at datetime NOT NULL,
        updated_by bigint(20) unsigned NOT NULL DEFAULT 0,
        PRIMARY KEY  (id),
        UNIQUE KEY kind_rid (kind,rid),
        KEY rev (rev),
        KEY kind_at (kind,at),
        KEY agent_rid (agent_rid)
    ) $c;");
    dbDelta('CREATE TABLE ' . rh_t('revs') . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        PRIMARY KEY  (id)
    ) $c;");
    dbDelta('CREATE TABLE ' . rh_t('photos') . " (
        pid varchar(64) NOT NULL,
        mime varchar(40) NOT NULL DEFAULT 'image/jpeg',
        data longtext NOT NULL,
        created_at datetime NOT NULL,
        created_by bigint(20) unsigned NOT NULL DEFAULT 0,
        PRIMARY KEY  (pid)
    ) $c;");
    dbDelta('CREATE TABLE ' . rh_t('notes') . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        user_id bigint(20) unsigned NOT NULL,
        kind varchar(24) NOT NULL DEFAULT '',
        title varchar(190) NOT NULL DEFAULT '',
        body varchar(600) NOT NULL DEFAULT '',
        ref varchar(64) NOT NULL DEFAULT '',
        at datetime NOT NULL,
        read_at datetime NULL DEFAULT NULL,
        PRIMARY KEY  (id),
        KEY user_at (user_id,at)
    ) $c;");
    dbDelta('CREATE TABLE ' . rh_t('errors') . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        user_id bigint(20) unsigned NOT NULL DEFAULT 0,
        user_name varchar(190) NOT NULL DEFAULT '',
        at datetime NOT NULL,
        received_at datetime NOT NULL,
        place varchar(190) NOT NULL DEFAULT '',
        message varchar(700) NOT NULL DEFAULT '',
        stack text NULL,
        version varchar(20) NOT NULL DEFAULT '',
        platform varchar(20) NOT NULL DEFAULT '',
        PRIMARY KEY  (id),
        KEY at (at)
    ) $c;");
    update_option('rh_db_version', RH_VERSION);
    if (function_exists('rh_gd_schedule')) {
        rh_gd_schedule();
    }
}

register_deactivation_hook(__FILE__, function () {
    wp_clear_scheduled_hook('rh_gd_daily');
});

add_action('init', function () {
    if (get_option('rh_db_version') !== RH_VERSION) {
        rh_install();
    }
});

function rh_now() {
    return gmdate('Y-m-d H:i:s');
}

/** ISO time from the app ("2026-11-02T21:40:00.000") to "Y-m-d H:i:s" as written (phone's local time). */
function rh_mysql_time($iso) {
    $iso = (string) $iso;
    if (!preg_match('/^(\d{4}-\d{2}-\d{2})[T ](\d{2}:\d{2}(:\d{2})?)/', $iso, $m)) {
        return null;
    }
    return $m[1] . ' ' . (strlen($m[2]) === 5 ? $m[2] . ':00' : $m[2]);
}

function rh_bn($s) {
    return strtr((string) $s, ['0' => '০', '1' => '১', '2' => '২', '3' => '৩', '4' => '৪', '5' => '৫', '6' => '৬', '7' => '৭', '8' => '৮', '9' => '৯']);
}

/** Indian grouping: 1,13,750 (Bangla digits). */
function rh_num($n, $dec = 0) {
    $neg = $n < 0;
    $n = abs((float) $n);
    $s = number_format($n, $dec, '.', '');
    [$int, $frac] = array_pad(explode('.', $s), 2, '');
    if ($frac !== '' && (int) $frac === 0) {
        $frac = '';
    }
    $frac = rtrim($frac, '0');
    if (strlen($int) > 3) {
        $last = substr($int, -3);
        $rest = substr($int, 0, -3);
        $rest = preg_replace('/\B(?=(\d{2})+(?!\d))/', ',', $rest);
        $int = $rest . ',' . $last;
    }
    return ($neg ? '-' : '') . rh_bn($int . ($frac !== '' ? '.' . $frac : ''));
}

function rh_sar($n) {
    return rh_num($n, 2) . ' SAR';
}

function rh_taka($n) {
    return '৳ ' . rh_num(round((float) $n));
}

function rh_phone_show($d) {
    $d = (string) $d;
    return strlen($d) === 11 ? rh_bn(substr($d, 0, 5) . '-' . substr($d, 5)) : rh_bn($d);
}

// ── Staying out of sight ──
//
// The app's routes are not listed in /wp-json, and a request without a
// valid session gets the same answer WordPress gives for a route that does
// not exist, so nobody can tell from outside that this server is here.

function rh_hidden() {
    return new WP_Error('rest_no_route', 'No route was found matching the URL and request method.', ['status' => 404]);
}

function rh_route($path, $method, $cb, $role = null) {
    register_rest_route(RH_NS, $path, [
        'methods' => $method,
        'callback' => function (WP_REST_Request $req) use ($cb, $role) {
            if ($role === null) {
                return $cb($req);
            }
            $u = rh_session_user($req);
            if (!$u || ($role === 'admin' && !in_array($u['role'], ['owner', 'admin'], true)) || ($role === 'agent' && $u['role'] !== 'agent')) {
                return rh_hidden();
            }
            return $cb($req, $u);
        },
        'permission_callback' => '__return_true', // checked above, so a missing session looks like a missing route
        'show_in_index' => false,
    ]);
}

add_filter('rest_index', function ($response) {
    // Belt and braces: never show our namespace in the index.
    $data = $response->get_data();
    if (isset($data['namespaces'])) {
        $data['namespaces'] = array_values(array_filter($data['namespaces'], fn($n) => $n !== RH_NS));
        unset($data['routes']['/' . RH_NS]);
        $response->set_data($data);
    }
    return $response;
});

// ── Sessions ──

function rh_rate_limited($what) {
    $ip = (string) ($_SERVER['REMOTE_ADDR'] ?? '');
    $key = 'rh_rl_' . md5($what . '|' . $ip);
    $n = (int) get_transient($key);
    if ($n >= 20) {
        return true;
    }
    set_transient($key, $n + 1, 15 * MINUTE_IN_SECONDS);
    return false;
}

function rh_bearer(WP_REST_Request $req) {
    $auth = (string) $req->get_header('authorization');
    return preg_match('/^Bearer\s+([a-f0-9]{64})$/i', trim($auth), $m) ? strtolower($m[1]) : '';
}

/** The signed-in user (row of rh_users, active) for this request, or null. */
function rh_session_user(WP_REST_Request $req) {
    $tok = rh_bearer($req);
    if ($tok === '') {
        return null;
    }
    global $wpdb;
    $s = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . rh_t('sessions') . ' WHERE token_hash = %s', hash('sha256', $tok)), ARRAY_A);
    $u = $s ? $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . rh_t('users') . " WHERE id = %d AND status = 'active'", (int) $s['user_id']), ARRAY_A) : null;
    if ($u) {
        $u['session_id'] = (int) $s['id'];
        $now = rh_now();
        if (strtotime($s['last_seen'] . ' UTC') < time() - 300) {
            $wpdb->update(rh_t('sessions'), ['last_seen' => $now], ['id' => (int) $s['id']]);
            $wpdb->update(rh_t('users'), ['last_seen' => $now], ['id' => (int) $u['id']]);
        }
    }
    return $u ?: null;
}

function rh_login_norm($login) {
    $l = strtolower(trim((string) $login));
    $l = strtr($l, ['০' => '0', '১' => '1', '২' => '2', '৩' => '3', '৪' => '4', '৫' => '5', '৬' => '6', '৭' => '7', '৮' => '8', '৯' => '9']);
    return preg_replace('/[\s\-]+/', '', $l);
}

function rh_user_public($u) {
    return [
        'id' => (int) $u['id'],
        'role' => $u['role'],
        'name' => $u['name'],
        'login' => $u['login'],
        'agent_rid' => $u['agent_rid'],
        'status' => $u['status'],
        'perms' => rh_perms($u),
        'last_seen' => $u['last_seen'] ? gmdate('c', strtotime($u['last_seen'] . ' UTC')) : null,
    ];
}

add_action('rest_api_init', function () {
    rh_route('/login', 'POST', 'rh_login');
    rh_route('/logout', 'POST', 'rh_logout', 'any');
    rh_route('/me', 'GET', fn($req, $u) => rest_ensure_response(['user' => rh_user_public($u), 'firebase' => rh_firebase_options()]), 'any');
    rh_route('/device', 'POST', 'rh_device', 'any');
    rh_route('/password', 'POST', 'rh_own_password', 'any');
    rh_route('/errors', 'POST', 'rh_errors_put', 'any');
});

/** A wrong login looks like a missing route too. */
function rh_login(WP_REST_Request $req) {
    if (rh_rate_limited('login')) {
        return rh_hidden();
    }
    global $wpdb;
    $login = rh_login_norm($req->get_param('login'));
    $pass = (string) $req->get_param('password');
    $u = $login === '' ? null : $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . rh_t('users') . " WHERE login = %s AND status = 'active'", $login), ARRAY_A);
    if (!$u || !password_verify($pass, $u['pass_hash'])) {
        return rh_hidden();
    }
    $tok = bin2hex(random_bytes(32));
    $now = rh_now();
    $wpdb->insert(rh_t('sessions'), [
        'user_id' => (int) $u['id'],
        'token_hash' => hash('sha256', $tok),
        'device' => mb_substr(sanitize_text_field((string) $req->get_param('device')), 0, 120),
        'created_at' => $now,
        'last_seen' => $now,
    ]);
    $wpdb->update(rh_t('users'), ['last_seen' => $now], ['id' => (int) $u['id']]);
    return rest_ensure_response(['ok' => true, 'token' => $tok, 'user' => rh_user_public($u), 'firebase' => rh_firebase_options()]);
}

function rh_logout(WP_REST_Request $req, $u) {
    global $wpdb;
    $wpdb->delete(rh_t('sessions'), ['id' => (int) $u['session_id']]);
    return rest_ensure_response(['ok' => true]);
}

function rh_device(WP_REST_Request $req, $u) {
    global $wpdb;
    $token = (string) $req->get_param('token');
    if (!preg_match('/^[A-Za-z0-9_:\-\.]{20,300}$/', $token)) {
        return new WP_Error('bad', 'bad token', ['status' => 400]);
    }
    // One phone, one session: the token moves to the newest one.
    $wpdb->update(rh_t('sessions'), ['fcm_token' => ''], ['fcm_token' => $token]);
    $wpdb->update(rh_t('sessions'), ['fcm_token' => $token], ['id' => (int) $u['session_id']]);
    return rest_ensure_response(['ok' => true]);
}

function rh_own_password(WP_REST_Request $req, $u) {
    global $wpdb;
    $old = (string) $req->get_param('old');
    $new = (string) $req->get_param('new');
    if (!password_verify($old, $u['pass_hash'])) {
        return new WP_Error('wrong', 'old password wrong', ['status' => 403]);
    }
    if (strlen($new) < 6) {
        return new WP_Error('short', 'password too short', ['status' => 400]);
    }
    $wpdb->update(rh_t('users'), ['pass_hash' => password_hash($new, PASSWORD_DEFAULT)], ['id' => (int) $u['id']]);
    // Other phones signed in as this user are signed out.
    $wpdb->query($wpdb->prepare('DELETE FROM ' . rh_t('sessions') . ' WHERE user_id = %d AND id <> %d', (int) $u['id'], (int) $u['session_id']));
    return rest_ensure_response(['ok' => true]);
}

// ── Notes: what each user is told (the agent's notification list) ──

function rh_note($user_id, $kind, $title, $body, $ref = '') {
    global $wpdb;
    $wpdb->insert(rh_t('notes'), ['user_id' => (int) $user_id, 'kind' => $kind, 'title' => mb_substr($title, 0, 190), 'body' => mb_substr($body, 0, 600), 'ref' => $ref, 'at' => rh_now()]);
    rh_push_user((int) $user_id, $title, $body, ['type' => $kind, 'ref' => $ref]);
}

/** Every active user who signs in as this agent. */
function rh_agent_users($agent_rid) {
    global $wpdb;
    return $agent_rid === '' ? [] : $wpdb->get_col($wpdb->prepare('SELECT id FROM ' . rh_t('users') . " WHERE role = 'agent' AND status = 'active' AND agent_rid = %s", $agent_rid));
}

function rh_admin_users() {
    global $wpdb;
    return $wpdb->get_col('SELECT id FROM ' . rh_t('users') . " WHERE role IN ('owner','admin') AND status = 'active'");
}

function rh_note_agent($agent_rid, $kind, $title, $body, $ref = '') {
    foreach (rh_agent_users($agent_rid) as $id) {
        rh_note($id, $kind, $title, $body, $ref);
    }
}

function rh_note_admins($kind, $title, $body, $ref = '', $except = 0) {
    foreach (rh_admin_users() as $id) {
        if ((int) $id !== (int) $except) {
            rh_note($id, $kind, $title, $body, $ref);
        }
    }
}


// ── Problems in the app ──

/** The app sends its errors here (any signed-in admin or agent); the "সমস্যার লগ" menu shows them. */
function rh_errors_put(WP_REST_Request $req, $u) {
    global $wpdb;
    $list = $req->get_json_params()['errors'] ?? [];
    if (!is_array($list)) {
        return new WP_Error('rh_bad', 'bad', ['status' => 400]);
    }
    $n = 0;
    foreach (array_slice($list, 0, 50) as $e) {
        if (!is_array($e)) {
            continue;
        }
        $wpdb->insert(rh_t('errors'), [
            'user_id' => (int) $u['id'],
            'user_name' => (string) $u['name'],
            'at' => rh_mysql_time($e['at'] ?? '') ?? rh_now(),
            'received_at' => rh_now(),
            'place' => mb_substr((string) ($e['where'] ?? ''), 0, 190),
            'message' => mb_substr((string) ($e['message'] ?? ''), 0, 700),
            'stack' => mb_substr((string) ($e['stack'] ?? ''), 0, 6000),
            'version' => mb_substr((string) ($e['version'] ?? ''), 0, 20),
            'platform' => mb_substr((string) ($e['platform'] ?? ''), 0, 20),
        ]);
        $n++;
    }
    // Keep the newest 5000.
    $cut = (int) $wpdb->get_var('SELECT id FROM ' . rh_t('errors') . ' ORDER BY id DESC LIMIT 1 OFFSET 5000');
    if ($cut > 0) {
        $wpdb->query($wpdb->prepare('DELETE FROM ' . rh_t('errors') . ' WHERE id <= %d', $cut));
    }
    return rest_ensure_response(['saved' => $n]);
}
