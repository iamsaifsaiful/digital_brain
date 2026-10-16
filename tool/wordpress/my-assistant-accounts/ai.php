<?php
/**
 * AI for Pro members through this server: the Anthropic API key stays here
 * (never in the app). The app signs in once and gets a session token; each
 * AI request is checked (Pro or trial, daily limit, allowed models and size),
 * sent on to Anthropic with our key, and only the counts are kept — never
 * what the member said.
 */

if (!defined('ABSPATH')) {
    exit;
}

const MA_AI_MODELS = ['claude-sonnet-5-5', 'claude-haiku-5-5', 'claude-sonnet-4-5', 'claude-haiku-4-5'];
const MA_AI_MAX_BODY = 200000;

function ma_ai_sessions_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_sessions';
}

function ma_ai_usage_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_ai_usage';
}

function ma_ai_install() {
    global $wpdb;
    $charset = $wpdb->get_charset_collate();
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $s = ma_ai_sessions_table();
    $u = ma_ai_usage_table();
    dbDelta("CREATE TABLE $s (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        user_id bigint(20) unsigned NOT NULL,
        token_hash char(64) NOT NULL,
        created_at datetime NOT NULL,
        expires_at datetime NOT NULL,
        last_used datetime NOT NULL,
        app varchar(16) NOT NULL DEFAULT 'member',
        fcm_token varchar(300) NOT NULL DEFAULT '',
        PRIMARY KEY  (id),
        UNIQUE KEY token_hash (token_hash),
        KEY user_id (user_id)
    ) $charset;");
    dbDelta("CREATE TABLE $u (
        user_id bigint(20) unsigned NOT NULL,
        day date NOT NULL,
        requests int(10) unsigned NOT NULL DEFAULT 0,
        tokens_in bigint(20) unsigned NOT NULL DEFAULT 0,
        tokens_out bigint(20) unsigned NOT NULL DEFAULT 0,
        PRIMARY KEY  (user_id,day)
    ) $charset;");
}

/** The key: MA_ANTHROPIC_API_KEY in wp-config.php (best), or the one saved on the settings page. */
function ma_ai_key() {
    if (defined('MA_ANTHROPIC_API_KEY') && MA_ANTHROPIC_API_KEY) {
        return (string) MA_ANTHROPIC_API_KEY;
    }
    return (string) get_option('ma_ai_key', '');
}

function ma_ai_key_source() {
    if (defined('MA_ANTHROPIC_API_KEY') && MA_ANTHROPIC_API_KEY) {
        return 'config';
    }
    return get_option('ma_ai_key', '') !== '' ? 'saved' : '';
}

function ma_ai_settings() {
    return [
        'on' => get_option('ma_ai_on', '0') === '1',
        'per_user' => max(1, (int) get_option('ma_ai_per_user', 50)),
        'per_day' => max(1, (int) get_option('ma_ai_per_day', 2000)),
    ];
}

/** A new session for a member (60 days); only its hash is kept. */
function ma_ai_new_session($user_id, $app = 'member') {
    global $wpdb;
    $token = bin2hex(random_bytes(32));
    $now = current_time('mysql', true);
    $wpdb->insert(ma_ai_sessions_table(), [
        'user_id' => (int) $user_id,
        'token_hash' => hash('sha256', $token),
        'created_at' => $now,
        'expires_at' => gmdate('Y-m-d H:i:s', time() + 60 * DAY_IN_SECONDS),
        'last_used' => $now,
        'app' => $app === 'admin' ? 'admin' : 'member',
    ]);
    // Old, expired sessions go.
    $wpdb->query($wpdb->prepare('DELETE FROM ' . ma_ai_sessions_table() . ' WHERE expires_at < %s', $now));
    return $token;
}

/** The member behind "Authorization: Bearer …", or null. */
function ma_ai_member(WP_REST_Request $req) {
    global $wpdb;
    $auth = (string) $req->get_header('authorization');
    if (!preg_match('/^Bearer\s+([a-f0-9]{64})$/i', trim($auth), $m)) {
        return null;
    }
    $s = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_ai_sessions_table() . ' WHERE token_hash = %s', hash('sha256', strtolower($m[1]))), ARRAY_A);
    if (!$s || ma_acc_ts($s['expires_at']) < time()) {
        return null;
    }
    $wpdb->update(ma_ai_sessions_table(), ['last_used' => current_time('mysql', true)], ['id' => $s['id']]);
    $row = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_acc_table() . ' WHERE id = %d', $s['user_id']), ARRAY_A);
    if ($row) {
        $row['_app'] = $s['app'];
    }
    if ($row) {
        $wpdb->update(ma_acc_table(), ['last_seen' => current_time('mysql', true)], ['id' => $row['id']]);
    }
    return $row;
}

function ma_ai_today() {
    return gmdate('Y-m-d');
}

function ma_ai_used($user_id) {
    global $wpdb;
    return (int) $wpdb->get_var($wpdb->prepare('SELECT requests FROM ' . ma_ai_usage_table() . ' WHERE user_id = %d AND day = %s', $user_id, ma_ai_today()));
}

function ma_ai_used_all() {
    global $wpdb;
    return (int) $wpdb->get_var($wpdb->prepare('SELECT COALESCE(SUM(requests),0) FROM ' . ma_ai_usage_table() . ' WHERE day = %s', ma_ai_today()));
}

add_action('rest_api_init', function () {
    register_rest_route('my-assistant/v1', '/me', [
        'methods' => 'GET',
        'callback' => 'ma_ai_me',
        'permission_callback' => '__return_true', // the session token is checked inside
    ]);
    register_rest_route('my-assistant/v1', '/ai', [
        'methods' => 'POST',
        'callback' => 'ma_ai_proxy',
        'permission_callback' => '__return_true',
    ]);
});

/** Plan and today's AI use, for the app to refresh without signing in again. */
function ma_ai_me(WP_REST_Request $req) {
    $row = ma_ai_member($req);
    if (!$row) {
        return new WP_Error('session', 'sign in again', ['status' => 401]);
    }
    $set = ma_ai_settings();
    return rest_ensure_response(ma_acc_answer($row) + [
        'ai' => $set['on'] && ma_ai_key() !== '',
        'ai_left' => max(0, $set['per_user'] - ma_ai_used((int) $row['id'])),
    ]);
}

function ma_ai_proxy(WP_REST_Request $req) {
    $row = ma_ai_member($req);
    if (!$row) {
        return new WP_Error('session', 'sign in again', ['status' => 401]);
    }
    $set = ma_ai_settings();
    $key = ma_ai_key();
    if (!$set['on'] || $key === '') {
        return new WP_Error('ai_off', 'AI is off', ['status' => 503]);
    }
    if (ma_acc_ts($row['pro_until']) < time()) {
        return new WP_Error('pro', 'Pro needed', ['status' => 402]);
    }
    if (ma_ai_used((int) $row['id']) >= $set['per_user']) {
        return new WP_Error('limit', 'daily limit', ['status' => 429]);
    }
    if (ma_ai_used_all() >= $set['per_day']) {
        return new WP_Error('busy', 'server daily limit', ['status' => 503]);
    }
    $raw = $req->get_body();
    if (strlen($raw) > MA_AI_MAX_BODY) {
        return new WP_Error('size', 'too large', ['status' => 413]);
    }
    $in = json_decode($raw, true);
    if (!is_array($in) || !in_array($in['model'] ?? '', MA_AI_MODELS, true) || !is_array($in['messages'] ?? null)) {
        return new WP_Error('bad', 'bad request', ['status' => 400]);
    }
    // Only what the app sends; nothing else reaches Anthropic.
    $body = ['model' => $in['model'], 'max_tokens' => min(4000, max(1, (int) ($in['max_tokens'] ?? 1000))), 'messages' => $in['messages']];
    foreach (['system', 'tools', 'tool_choice', 'output_config'] as $k) {
        if (isset($in[$k])) {
            $body[$k] = $in[$k];
        }
    }
    $res = wp_remote_post('https://api.anthropic.com/v1/messages', [
        'timeout' => 55,
        'headers' => ['content-type' => 'application/json', 'x-api-key' => $key, 'anthropic-version' => '2023-06-01'],
        'body' => wp_json_encode($body),
    ]);
    if (is_wp_error($res)) {
        return new WP_Error('upstream', 'AI did not answer', ['status' => 504]);
    }
    $code = (int) wp_remote_retrieve_response_code($res);
    $out = wp_remote_retrieve_body($res);
    if ($code === 200) {
        $j = json_decode($out, true);
        global $wpdb;
        $wpdb->query($wpdb->prepare(
            'INSERT INTO ' . ma_ai_usage_table() . ' (user_id, day, requests, tokens_in, tokens_out) VALUES (%d, %s, 1, %d, %d)
             ON DUPLICATE KEY UPDATE requests = requests + 1, tokens_in = tokens_in + VALUES(tokens_in), tokens_out = tokens_out + VALUES(tokens_out)',
            (int) $row['id'], ma_ai_today(),
            (int) ($j['usage']['input_tokens'] ?? 0) + (int) ($j['usage']['cache_read_input_tokens'] ?? 0) + (int) ($j['usage']['cache_creation_input_tokens'] ?? 0),
            (int) ($j['usage']['output_tokens'] ?? 0)
        ));
    }
    // Anthropic's answer as it is (the app reads it); a key problem is ours, not the member's.
    if ($code === 401 || $code === 403) {
        return new WP_Error('ai_off', 'server key problem', ['status' => 503]);
    }
    $r = new WP_REST_Response(json_decode($out, true), $code);
    return $r;
}

// ── Admin: the AI settings ──

add_action('admin_post_ma_ai_settings', function () {
    ma_acc_guard('ma_ai_settings');
    update_option('ma_ai_on', !empty($_POST['ai_on']) ? '1' : '0');
    update_option('ma_ai_per_user', max(1, min(500, (int) ($_POST['per_user'] ?? 50))));
    update_option('ma_ai_per_day', max(1, min(100000, (int) ($_POST['per_day'] ?? 2000))));
    $key = trim(sanitize_text_field(wp_unslash($_POST['ai_key'] ?? '')));
    if (!empty($_POST['ai_key_remove'])) {
        delete_option('ma_ai_key');
    } elseif ($key !== '') {
        if (!preg_match('/^sk-ant-[A-Za-z0-9_\-]{20,}$/', $key)) {
            ma_acc_back('API key ঠিক মনে হচ্ছে না (sk-ant- দিয়ে শুরু হয়)।', 'error', ['tab' => 'settings']);
        }
        update_option('ma_ai_key', $key, false);
    }
    ma_acc_back('AI সেটিংস রাখা হয়েছে।', 'ok', ['tab' => 'settings']);
});

/** Today's totals for the admin page. */
function ma_ai_today_stats() {
    global $wpdb;
    $r = $wpdb->get_row($wpdb->prepare('SELECT COALESCE(SUM(requests),0) req, COALESCE(SUM(tokens_in),0) tin, COALESCE(SUM(tokens_out),0) tout, COUNT(*) people FROM ' . ma_ai_usage_table() . ' WHERE day = %s', ma_ai_today()), ARRAY_A);
    $month = $wpdb->get_var($wpdb->prepare('SELECT COALESCE(SUM(requests),0) FROM ' . ma_ai_usage_table() . ' WHERE day >= %s', gmdate('Y-m-01')));
    return ['requests' => (int) $r['req'], 'in' => (int) $r['tin'], 'out' => (int) $r['tout'], 'people' => (int) $r['people'], 'month' => (int) $month];
}
