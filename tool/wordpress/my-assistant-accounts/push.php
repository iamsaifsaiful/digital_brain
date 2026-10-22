<?php
/**
 * Push notifications through Firebase Cloud Messaging (free). Phones send
 * their device token after signing in; this server sends with the Firebase
 * service account (kept in wp-config.php or the settings page, never in an
 * app). New payment → every admin's phone; Pro approved → the member's phones.
 */

if (!defined('ABSPATH')) {
    exit;
}

/** The service account JSON: MA_FCM_SERVICE_ACCOUNT (a file path or the JSON) in wp-config.php, or the saved one. */
function ma_push_account() {
    $raw = '';
    if (defined('MA_FCM_SERVICE_ACCOUNT') && MA_FCM_SERVICE_ACCOUNT) {
        $v = (string) MA_FCM_SERVICE_ACCOUNT;
        $raw = is_readable($v) ? (string) file_get_contents($v) : $v;
    } else {
        $raw = (string) get_option('ma_fcm_account', '');
    }
    $j = json_decode($raw, true);
    return is_array($j) && !empty($j['client_email']) && !empty($j['private_key']) && !empty($j['project_id']) ? $j : null;
}

function ma_push_source() {
    if (defined('MA_FCM_SERVICE_ACCOUNT') && MA_FCM_SERVICE_ACCOUNT) {
        return 'config';
    }
    return get_option('ma_fcm_account', '') !== '' ? 'saved' : '';
}

function ma_push_b64($s) {
    return rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
}

/** An OAuth access token for FCM (kept for 50 minutes). */
function ma_push_token() {
    $cached = get_transient('ma_fcm_token');
    if ($cached) {
        return $cached;
    }
    $acc = ma_push_account();
    if (!$acc || !function_exists('openssl_sign')) {
        return '';
    }
    $now = time();
    $head = ma_push_b64(wp_json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $claim = ma_push_b64(wp_json_encode([
        'iss' => $acc['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => 'https://oauth2.googleapis.com/token',
        'iat' => $now,
        'exp' => $now + 3600,
    ]));
    $sig = '';
    if (!openssl_sign("$head.$claim", $sig, $acc['private_key'], 'sha256WithRSAEncryption')) {
        return '';
    }
    $res = wp_remote_post('https://oauth2.googleapis.com/token', [
        'timeout' => 15,
        'body' => ['grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion' => "$head.$claim." . ma_push_b64($sig)],
    ]);
    if (is_wp_error($res) || wp_remote_retrieve_response_code($res) !== 200) {
        return '';
    }
    $tok = (string) (json_decode(wp_remote_retrieve_body($res), true)['access_token'] ?? '');
    if ($tok !== '') {
        set_transient('ma_fcm_token', $tok, 50 * MINUTE_IN_SECONDS);
    }
    return $tok;
}

/** Sends to each device token; tokens Firebase no longer knows are forgotten. Returns how many went. */
function ma_push_send(array $tokens, $title, $body, array $data = []) {
    $acc = ma_push_account();
    $auth = $acc ? ma_push_token() : '';
    if ($auth === '' || !$tokens) {
        return 0;
    }
    global $wpdb;
    $sent = 0;
    $data = array_map('strval', $data);
    foreach (array_unique($tokens) as $t) {
        $res = wp_remote_post('https://fcm.googleapis.com/v1/projects/' . rawurlencode($acc['project_id']) . '/messages:send', [
            'timeout' => 10,
            'headers' => ['authorization' => 'Bearer ' . $auth, 'content-type' => 'application/json'],
            // No title: a silent data message the app handles itself (e.g. a family member asking where the phone is).
            'body' => wp_json_encode(['message' => $title === '' ? [
                'token' => $t,
                'data' => (object) $data,
                'android' => ['priority' => 'high', 'ttl' => '600s'],
            ] : [
                'token' => $t,
                'notification' => ['title' => $title, 'body' => $body],
                'data' => (object) $data,
                'android' => ['priority' => 'high', 'notification' => ['channel_id' => 'ma_server_v3']],
            ]]),
        ]);
        $code = is_wp_error($res) ? 0 : (int) wp_remote_retrieve_response_code($res);
        if ($code === 200) {
            $sent++;
        } elseif ($code === 404 || ($code === 400 && strpos(wp_remote_retrieve_body($res), 'registration') !== false)) {
            $wpdb->update(ma_ai_sessions_table(), ['fcm_token' => ''], ['fcm_token' => $t]);
        }
    }
    return $sent;
}

/** WordPress users who may use the admin app (role "My Assistant অ্যাডমিন" or site administrators). */
function ma_admin_users() {
    return get_users(['capability' => 'ma_manage', 'orderby' => 'display_name', 'fields' => ['ID', 'display_name', 'user_email']]);
}

function ma_push_admins($title, $body, array $data = []) {
    global $wpdb;
    $rows = $wpdb->get_results('SELECT user_id, fcm_token FROM ' . ma_ai_sessions_table() . " WHERE app = 'admin' AND fcm_token <> '' AND expires_at > UTC_TIMESTAMP()", ARRAY_A);
    $tokens = [];
    foreach ($rows as $r) {
        if (user_can((int) $r['user_id'], 'ma_manage')) {
            $tokens[] = $r['fcm_token'];
        }
    }
    return ma_push_send($tokens, $title, $body, $data);
}

function ma_push_member($user_id, $title, $body, array $data = []) {
    global $wpdb;
    $tokens = $wpdb->get_col($wpdb->prepare(
        'SELECT fcm_token FROM ' . ma_ai_sessions_table() . " WHERE user_id = %d AND app <> 'admin' AND fcm_token <> '' AND expires_at > UTC_TIMESTAMP()",
        $user_id
    ));
    return ma_push_send($tokens, $title, $body, $data);
}

add_action('rest_api_init', function () {
    register_rest_route('my-assistant/v1', '/device', [
        'methods' => 'POST',
        'callback' => 'ma_push_device',
        'permission_callback' => '__return_true', // the session token is checked inside
    ]);
});

/** The phone's Firebase token, kept with its session. */
function ma_push_device(WP_REST_Request $req) {
    global $wpdb;
    $row = ma_session_row($req);
    if (!$row) {
        return new WP_Error('session', 'sign in again', ['status' => 401]);
    }
    $token = (string) $req->get_param('token');
    if (!preg_match('/^[A-Za-z0-9_:\-\.]{20,300}$/', $token)) {
        return new WP_Error('bad', 'bad token', ['status' => 400]);
    }
    $auth = (string) $req->get_header('authorization');
    preg_match('/([a-f0-9]{64})/i', $auth, $m);
    // One phone, one session: the token moves to the newest one.
    $wpdb->update(ma_ai_sessions_table(), ['fcm_token' => ''], ['fcm_token' => $token]);
    $wpdb->update(ma_ai_sessions_table(), ['fcm_token' => $token], ['token_hash' => hash('sha256', strtolower($m[1] ?? ''))]);
    return rest_ensure_response(['ok' => true]);
}

add_action('admin_post_ma_push_settings', function () {
    ma_acc_guard('ma_push_settings', 'manage_options');
    $json = trim((string) wp_unslash($_POST['fcm_account'] ?? ''));
    if (!empty($_POST['fcm_remove'])) {
        delete_option('ma_fcm_account');
        delete_transient('ma_fcm_token');
    } elseif ($json !== '') {
        $j = json_decode($json, true);
        if (!is_array($j) || empty($j['client_email']) || empty($j['private_key']) || empty($j['project_id'])) {
            ma_acc_back('Firebase-এর service account JSON ঠিক নেই — পুরো ফাইলের লেখা পেস্ট করুন।', 'error', ['tab' => 'settings']);
        }
        update_option('ma_fcm_account', wp_json_encode($j), false);
        delete_transient('ma_fcm_token');
    }
    ma_acc_back('পুশের সেটিংস রাখা হয়েছে।', 'ok', ['tab' => 'settings']);
});

/** A new admin account (email + password) for the admin app and this page. */
add_action('admin_post_ma_admin_add', function () {
    ma_acc_guard('ma_admin_add', 'manage_options');
    $email = sanitize_email(wp_unslash($_POST['email'] ?? ''));
    $name = sanitize_text_field(wp_unslash($_POST['name'] ?? ''));
    $pass = (string) wp_unslash($_POST['password'] ?? '');
    if (!is_email($email) || strlen($pass) < 10) {
        ma_acc_back('ঠিক ইমেইল আর অন্তত ১০ অক্ষরের পাসওয়ার্ড দিন।', 'error', ['tab' => 'settings']);
    }
    $existing = get_user_by('email', $email);
    if ($existing) {
        $existing->add_role('ma_admin');
        ma_acc_back('এই ইমেইলের অ্যাকাউন্ট আগেই ছিল — অ্যাডমিন করা হলো (পাসওয়ার্ড বদলায়নি)।', 'ok', ['tab' => 'settings']);
    }
    $id = wp_insert_user(['user_login' => $email, 'user_email' => $email, 'user_pass' => $pass, 'display_name' => $name ?: $email, 'role' => 'ma_admin']);
    if (is_wp_error($id)) {
        ma_acc_back('অ্যাডমিন যোগ হয়নি: ' . $id->get_error_message(), 'error', ['tab' => 'settings']);
    }
    ma_acc_back('অ্যাডমিন যোগ হলো। এই ইমেইল আর পাসওয়ার্ড দিয়ে অ্যাডমিন অ্যাপে লগইন করা যাবে।', 'ok', ['tab' => 'settings']);
});

/** Takes the admin role away and ends their app sessions (site administrators stay). */
add_action('admin_post_ma_admin_remove', function () {
    ma_acc_guard('ma_admin_remove', 'manage_options');
    global $wpdb;
    $user = get_user_by('id', (int) ($_POST['id'] ?? 0));
    if ($user) {
        $user->remove_role('ma_admin');
        $wpdb->delete(ma_ai_sessions_table(), ['user_id' => $user->ID, 'app' => 'admin']);
    }
    ma_acc_back('অ্যাডমিনের অনুমতি তুলে নেওয়া হলো, তাঁর অ্যাপ থেকেও লগআউট হলো।', 'ok', ['tab' => 'settings']);
});

add_action('admin_post_ma_push_test', function () {
    ma_acc_guard('ma_push_test', 'manage_options');
    $n = ma_push_admins('পরীক্ষা', 'My Assistant অ্যাডমিন অ্যাপে পুশ ঠিকমতো আসছে।', ['type' => 'test']);
    ma_acc_back($n ? 'পরীক্ষার পুশ গেছে ' . ma_acc_bn($n) . 'টা ফোনে।' : 'কোনো অ্যাডমিন ফোনে যায়নি — অ্যাডমিন অ্যাপে লগইন করা আছে আর Firebase ঠিক আছে কি না দেখুন।', $n ? 'ok' : 'error', ['tab' => 'settings']);
});
