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
    ma_ai_usage_migrate();
    dbDelta(ma_ai_usage_sql($u, $charset));
    $src = ma_ai_sources_table();
    dbDelta("CREATE TABLE $src (
        day date NOT NULL,
        source varchar(16) NOT NULL,
        n int(10) unsigned NOT NULL DEFAULT 0,
        PRIMARY KEY  (day,source)
    ) $charset;");
    // The price list lives in the settings (editable on the settings page);
    // the first values are Anthropic's published prices (USD per million
    // tokens, prompts up to 100k), 21 Oct 2026.
    if (get_option('ma_ai_prices', '') === '') {
        update_option('ma_ai_prices', wp_json_encode([
            'claude-haiku-5-5' => ['in' => 0.10, 'cw' => 0.125, 'cr' => 0.01, 'out' => 0.50],
            'claude-sonnet-5-5' => ['in' => 2.00, 'cw' => 2.50, 'cr' => 0.10, 'out' => 10.00],
        ]), false);
    }
}

/**
 * One row per member, day and model: requests, the four kinds of tokens and
 * what they cost (millionths of a dollar). What was said is never kept.
 */
function ma_ai_usage_sql($table, $charset) {
    return "CREATE TABLE $table (
        user_id bigint(20) unsigned NOT NULL,
        day date NOT NULL,
        model varchar(64) NOT NULL DEFAULT 'unknown',
        provider varchar(16) NOT NULL DEFAULT 'anthropic',
        plan varchar(8) NOT NULL DEFAULT 'pro',
        requests int(10) unsigned NOT NULL DEFAULT 0,
        tokens_in bigint(20) unsigned NOT NULL DEFAULT 0,
        tokens_out bigint(20) unsigned NOT NULL DEFAULT 0,
        input bigint(20) unsigned NOT NULL DEFAULT 0,
        cache_write bigint(20) unsigned NOT NULL DEFAULT 0,
        cache_read bigint(20) unsigned NOT NULL DEFAULT 0,
        output bigint(20) unsigned NOT NULL DEFAULT 0,
        cost_micro_usd bigint(20) unsigned NOT NULL DEFAULT 0,
        PRIMARY KEY  (user_id,day,model)
    ) $charset;";
}

/**
 * 1.8.0 → 1.9.0: the usage table keyed by (user_id, day) becomes keyed by
 * (user_id, day, model). The old rows are copied as model 'unknown' — no
 * count is lost — into a new table, which then takes the old one's name.
 */
function ma_ai_usage_migrate() {
    global $wpdb;
    $u = ma_ai_usage_table();
    if ($wpdb->get_var($wpdb->prepare('SHOW TABLES LIKE %s', $u)) !== $u) {
        return;
    }
    $cols = $wpdb->get_col("SHOW COLUMNS FROM $u", 0);
    if (in_array('model', $cols, true)) {
        return;
    }
    // Copy aside (in the new shape), check, rebuild under the old name, copy
    // back, check again. Only plain CREATE/INSERT/DROP — no RENAME, which
    // some databases WordPress runs on cannot do. If a count does not match,
    // the copy is left in place so nothing is lost.
    $bak = $u . '_v18';
    $wpdb->query("DROP TABLE IF EXISTS $bak");
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $charset = $wpdb->get_charset_collate();
    dbDelta(ma_ai_usage_sql($bak, $charset));
    $wpdb->query("INSERT INTO $bak (user_id, day, model, provider, plan, requests, tokens_in, tokens_out, input, output) SELECT user_id, day, 'unknown', 'anthropic', 'pro', requests, tokens_in, tokens_out, tokens_in, tokens_out FROM $u");
    $old = (int) $wpdb->get_var("SELECT COUNT(*) FROM $u");
    if ((int) $wpdb->get_var("SELECT COUNT(*) FROM $bak") !== $old) {
        $wpdb->query("DROP TABLE IF EXISTS $bak");
        return;
    }
    $wpdb->query("DROP TABLE $u");
    dbDelta(ma_ai_usage_sql($u, $charset));
    $wpdb->query("INSERT INTO $u SELECT * FROM $bak");
    if ((int) $wpdb->get_var("SELECT COUNT(*) FROM $u") === $old) {
        $wpdb->query("DROP TABLE $bak");
    }
}

function ma_ai_sources_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_ai_sources';
}

/** USD per million tokens for each model, from the settings. */
function ma_ai_prices() {
    $p = json_decode((string) get_option('ma_ai_prices', ''), true);
    return is_array($p) ? $p : [];
}

/**
 * Millionths of a dollar for one answer's usage: tokens × (USD per million
 * tokens) is exactly that. A model with no price set counts 0 (and the
 * settings page says so).
 */
function ma_ai_cost_micro($model, $in, $cw, $cr, $out) {
    $p = ma_ai_prices()[$model] ?? null;
    if (!is_array($p)) {
        return 0;
    }
    return (int) round($in * (float) ($p['in'] ?? 0) + $cw * (float) ($p['cw'] ?? 0) + $cr * (float) ($p['cr'] ?? 0) + $out * (float) ($p['out'] ?? 0));
}

/** Dollar budgets, free and Pro apart; 0 = no limit. */
function ma_ai_budgets() {
    $b = json_decode((string) get_option('ma_ai_budgets', ''), true);
    $b = is_array($b) ? $b : [];
    $one = function ($k) use ($b) {
        return ['day' => max(0, (float) ($b[$k]['day'] ?? 0)), 'month' => max(0, (float) ($b[$k]['month'] ?? 0))];
    };
    return ['free' => $one('free'), 'pro' => $one('pro')];
}

/** Millionths of a dollar spent by one plan since $from (a Y-m-d day). */
function ma_ai_spent($plan, $from) {
    global $wpdb;
    return (int) $wpdb->get_var($wpdb->prepare('SELECT COALESCE(SUM(cost_micro_usd),0) FROM ' . ma_ai_usage_table() . ' WHERE plan = %s AND day >= %s', $plan, $from));
}

/** True when the plan's daily or monthly budget is used up. */
function ma_ai_over_budget($plan) {
    $b = ma_ai_budgets()[$plan] ?? ['day' => 0, 'month' => 0];
    if ($b['day'] > 0 && ma_ai_spent($plan, ma_ai_today()) >= $b['day'] * 1e6) {
        return true;
    }
    return $b['month'] > 0 && ma_ai_spent($plan, gmdate('Y-m-01')) >= $b['month'] * 1e6;
}

/** One answer's usage, added to the member's row for the day and model. */
function ma_ai_count($user_id, $plan, $model, $provider, $usage) {
    global $wpdb;
    $in = (int) ($usage['input_tokens'] ?? 0);
    $cw = (int) ($usage['cache_creation_input_tokens'] ?? 0);
    $cr = (int) ($usage['cache_read_input_tokens'] ?? 0);
    $out = (int) ($usage['output_tokens'] ?? 0);
    $cost = ma_ai_cost_micro($model, $in, $cw, $cr, $out);
    $wpdb->query($wpdb->prepare(
        'INSERT INTO ' . ma_ai_usage_table() . ' (user_id, day, model, provider, plan, requests, tokens_in, tokens_out, input, cache_write, cache_read, output, cost_micro_usd) VALUES (%d, %s, %s, %s, %s, 1, %d, %d, %d, %d, %d, %d, %d)
         ON DUPLICATE KEY UPDATE requests = requests + 1, tokens_in = tokens_in + VALUES(tokens_in), tokens_out = tokens_out + VALUES(tokens_out), input = input + VALUES(input), cache_write = cache_write + VALUES(cache_write), cache_read = cache_read + VALUES(cache_read), output = output + VALUES(output), cost_micro_usd = cost_micro_usd + VALUES(cost_micro_usd)',
        (int) $user_id, ma_ai_today(), $model, $provider, $plan, $in + $cw + $cr, $out, $in, $cw, $cr, $out, $cost
    ));
    return $cost;
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
        // Pro: 30 a day (21 Oct 2026 brief).
        'per_user' => max(1, (int) get_option('ma_ai_per_user', 30)),
        'per_day' => max(1, (int) get_option('ma_ai_per_day', 2000)),
    ];
}

/** A new session for a member (60 days); only its hash is kept. */
/** A session (members: 60 days; admins: 30). $user_id is ma_users.id, or the WordPress user for 'admin'. */
function ma_ai_new_session($user_id, $app = 'member') {
    global $wpdb;
    $token = bin2hex(random_bytes(32));
    $now = current_time('mysql', true);
    $wpdb->insert(ma_ai_sessions_table(), [
        'user_id' => (int) $user_id,
        'token_hash' => hash('sha256', $token),
        'created_at' => $now,
        'expires_at' => gmdate('Y-m-d H:i:s', time() + ($app === 'admin' ? 30 : 60) * DAY_IN_SECONDS),
        'last_used' => $now,
        'app' => $app === 'admin' ? 'admin' : 'member',
    ]);
    // Old, expired sessions go.
    $wpdb->query($wpdb->prepare('DELETE FROM ' . ma_ai_sessions_table() . ' WHERE expires_at < %s', $now));
    return $token;
}

/** The live session behind "Authorization: Bearer …" (member or admin), or null. */
function ma_session_row(WP_REST_Request $req) {
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
    return $s;
}

/** The member (app user) behind the request, or null. Admin sessions are not members. */
function ma_ai_member(WP_REST_Request $req) {
    global $wpdb;
    $s = ma_session_row($req);
    if (!$s || $s['app'] !== 'member') {
        return null;
    }
    $row = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_acc_table() . ' WHERE id = %d', $s['user_id']), ARRAY_A);
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
    return (int) $wpdb->get_var($wpdb->prepare('SELECT COALESCE(SUM(requests),0) FROM ' . ma_ai_usage_table() . ' WHERE user_id = %d AND day = %s', $user_id, ma_ai_today()));
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
    register_rest_route('my-assistant/v1', '/ai/sources', [
        'methods' => 'POST',
        'callback' => 'ma_ai_sources_in',
        'permission_callback' => '__return_true',
    ]);
});

/** Where each answer came from (rules, phone model, a cloud model, failed): counts only, never words. */
const MA_AI_SOURCES = ['rules', 'local', 'gemini', 'haiku', 'sonnet', 'failed',
    // Shadow mode (the phone model reads next to the rules, acting on nothing).
    'nlu_same_sure', 'nlu_same', 'nlu_differ_sure', 'nlu_differ', 'nlu_early', 'nlu_off'];

function ma_ai_sources_in(WP_REST_Request $req) {
    $row = ma_ai_member($req);
    if (!$row) {
        return new WP_Error('session', 'sign in again', ['status' => 401]);
    }
    $in = json_decode($req->get_body(), true);
    $day = (string) ($in['day'] ?? '');
    $counts = $in['counts'] ?? null;
    // Only today or the last week, only known sources, sane numbers.
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $day) || $day > ma_ai_today() || $day < gmdate('Y-m-d', time() - 7 * DAY_IN_SECONDS) || !is_array($counts)) {
        return new WP_Error('bad', 'bad request', ['status' => 400]);
    }
    global $wpdb;
    $kept = 0;
    foreach ($counts as $src => $n) {
        $n = (int) $n;
        if (!in_array($src, MA_AI_SOURCES, true) || $n <= 0 || $n > 5000) {
            continue;
        }
        $wpdb->query($wpdb->prepare('INSERT INTO ' . ma_ai_sources_table() . ' (day, source, n) VALUES (%s, %s, %d) ON DUPLICATE KEY UPDATE n = n + VALUES(n)', $day, $src, $n));
        $kept++;
    }
    return rest_ensure_response(['ok' => true, 'kept' => $kept]);
}

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
    // The Pro budget used up: the app understands on the phone instead.
    if (ma_ai_over_budget('pro')) {
        return new WP_Error('budget', 'AI budget used up', ['status' => 503]);
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
        ma_ai_count((int) $row['id'], 'pro', $in['model'], 'anthropic', is_array($j['usage'] ?? null) ? $j['usage'] : []);
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
    ma_acc_guard('ma_ai_settings', 'manage_options');
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

/**
 * Cost by model, today and this month (for the settings page and the admin
 * app): requests, tokens of each kind, dollars, and the share of the prompt
 * that was read from the cache.
 */
function ma_ai_cost_report() {
    global $wpdb;
    $t = ma_ai_usage_table();
    $rows = function ($from) use ($wpdb, $t) {
        $r = $wpdb->get_results($wpdb->prepare("SELECT model, provider, plan, SUM(requests) requests, SUM(input) input, SUM(cache_write) cache_write, SUM(cache_read) cache_read, SUM(output) output, SUM(cost_micro_usd) cost FROM $t WHERE day >= %s GROUP BY model, provider, plan ORDER BY cost DESC", $from), ARRAY_A) ?: [];
        return array_map(function ($x) {
            $req = (int) $x['requests'];
            $prompt = (int) $x['input'] + (int) $x['cache_write'] + (int) $x['cache_read'];
            return [
                'model' => $x['model'], 'provider' => $x['provider'], 'plan' => $x['plan'], 'requests' => $req,
                'input' => (int) $x['input'], 'cache_write' => (int) $x['cache_write'], 'cache_read' => (int) $x['cache_read'], 'output' => (int) $x['output'],
                'cost_usd' => round((int) $x['cost'] / 1e6, 6),
                'per_request_usd' => $req > 0 ? round((int) $x['cost'] / 1e6 / $req, 6) : 0,
                'cache_hit' => $prompt > 0 ? round((int) $x['cache_read'] / $prompt, 3) : 0,
                'priced' => isset(ma_ai_prices()[$x['model']]),
            ];
        }, $r);
    };
    $sources = function ($from) use ($wpdb) {
        $out = array_fill_keys(MA_AI_SOURCES, 0);
        foreach ($wpdb->get_results($wpdb->prepare('SELECT source, SUM(n) n FROM ' . ma_ai_sources_table() . ' WHERE day >= %s GROUP BY source', $from), ARRAY_A) ?: [] as $x) {
            $out[$x['source']] = (int) $x['n'];
        }
        return $out;
    };
    $b = ma_ai_budgets();
    return [
        'today' => $rows(ma_ai_today()),
        'month' => $rows(gmdate('Y-m-01')),
        'sources_today' => $sources(ma_ai_today()),
        'sources_month' => $sources(gmdate('Y-m-01')),
        'budget' => [
            'free' => $b['free'] + ['spent_day' => ma_ai_spent('free', ma_ai_today()) / 1e6, 'spent_month' => ma_ai_spent('free', gmdate('Y-m-01')) / 1e6],
            'pro' => $b['pro'] + ['spent_day' => ma_ai_spent('pro', ma_ai_today()) / 1e6, 'spent_month' => ma_ai_spent('pro', gmdate('Y-m-01')) / 1e6],
        ],
        'prices' => ma_ai_prices(),
        'nlu' => ma_nlu_overview(),
    ];
}

add_action('admin_post_ma_ai_costs', function () {
    ma_acc_guard('ma_ai_costs', 'manage_options');
    $prices = [];
    foreach ((array) ($_POST['price'] ?? []) as $model => $p) {
        $model = sanitize_text_field(wp_unslash((string) $model));
        if (!preg_match('/^[a-z0-9.\-]{3,64}$/', $model)) {
            continue;
        }
        $one = [];
        foreach (['in', 'cw', 'cr', 'out'] as $k) {
            $one[$k] = max(0, min(1000, (float) ($p[$k] ?? 0)));
        }
        $prices[$model] = $one;
    }
    $new = sanitize_text_field(wp_unslash((string) ($_POST['new_model'] ?? '')));
    if ($new !== '' && preg_match('/^[a-z0-9.\-]{3,64}$/', $new) && !isset($prices[$new])) {
        $prices[$new] = ['in' => 0, 'cw' => 0, 'cr' => 0, 'out' => 0];
    }
    update_option('ma_ai_prices', wp_json_encode($prices), false);
    $b = [];
    foreach (['free', 'pro'] as $plan) {
        $b[$plan] = ['day' => max(0, (float) ($_POST['budget'][$plan]['day'] ?? 0)), 'month' => max(0, (float) ($_POST['budget'][$plan]['month'] ?? 0))];
    }
    update_option('ma_ai_budgets', wp_json_encode($b), false);
    ma_acc_back('দাম আর বাজেট রাখা হয়েছে।', 'ok', ['tab' => 'settings']);
});

/** Today's totals for the admin page. */
function ma_ai_today_stats() {
    global $wpdb;
    $r = $wpdb->get_row($wpdb->prepare('SELECT COALESCE(SUM(requests),0) req, COALESCE(SUM(tokens_in),0) tin, COALESCE(SUM(tokens_out),0) tout, COUNT(*) people FROM ' . ma_ai_usage_table() . ' WHERE day = %s', ma_ai_today()), ARRAY_A);
    $month = $wpdb->get_var($wpdb->prepare('SELECT COALESCE(SUM(requests),0) FROM ' . ma_ai_usage_table() . ' WHERE day >= %s', gmdate('Y-m-01')));
    return ['requests' => (int) $r['req'], 'in' => (int) $r['tin'], 'out' => (int) $r['tout'], 'people' => (int) $r['people'], 'month' => (int) $month];
}
