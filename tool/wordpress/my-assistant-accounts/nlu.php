<?php
/**
 * Understanding (NLU) on the server, step G of the 22 Oct 2026 brief:
 *  - the switch (nlu_mode off | shadow | on, and for what share of members),
 *  - which on-phone model a member gets (versions, rollout share, SHA-256),
 *  - reading a message in the cloud when the phone is unsure (/nlu/resolve):
 *    free → Gemini Flash-Lite, Pro → Claude Haiku, a Pro message the phone
 *    was very unsure of → Sonnet (at most 5% of the day's readings); one
 *    fails → the other; 429/529/timeouts tried once more,
 *  - learning samples (only with the member's consent, names already
 *    replaced on the phone, phone numbers refused here too, gone after 180
 *    days or when the member is deleted),
 *  - the admin side: settings, review of disagreements, models, export.
 * What a member said is never written to a log.
 */

if (!defined('ABSPATH')) {
    exit;
}

require_once __DIR__ . '/nlu-intents.php';

const MA_NLU_PROMPT_VER = 'v1';
const MA_NLU_KEEP_DAYS = 180;
const MA_NLU_MAX_TEXT = 600;
const MA_NLU_STATES = ['idle', 'await_time', 'await_ampm', 'await_new_value', 'await_person', 'await_kind', 'confirm_delete', 'confirm_save', 'confirm_batch', 'pick_one', 'clarify', 'dictating_list'];
const MA_NLU_SIGNALS = ['', 'edited', 'undo', 'said_no', 'repeated', 'thumbs_down', 'thumbs_up'];

function ma_nlu_table($name) {
    global $wpdb;
    return $wpdb->prefix . 'ma_nlu_' . $name;
}

function ma_nlu_install() {
    global $wpdb;
    $charset = $wpdb->get_charset_collate();
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $s = ma_nlu_table('samples');
    $l = ma_nlu_table('labels');
    $m = ma_nlu_table('models');
    dbDelta("CREATE TABLE $s (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        user_hash char(64) NOT NULL,
        created datetime NOT NULL,
        app_ver varchar(32) NOT NULL DEFAULT '',
        model_ver varchar(32) NOT NULL DEFAULT '',
        state varchar(24) NOT NULL DEFAULT 'idle',
        text_delex text NOT NULL,
        alts_delex text NOT NULL,
        local_json text NOT NULL,
        local_conf float NOT NULL DEFAULT 0,
        cloud_json text NOT NULL,
        cloud_provider varchar(16) NOT NULL DEFAULT '',
        final_json text NOT NULL,
        signal_kind varchar(16) NOT NULL DEFAULT '',
        consent_ver varchar(16) NOT NULL DEFAULT '',
        PRIMARY KEY  (id),
        KEY user_hash (user_hash),
        KEY created (created)
    ) $charset;");
    dbDelta("CREATE TABLE $l (
        sample_id bigint(20) unsigned NOT NULL,
        label_json text NOT NULL,
        source varchar(8) NOT NULL DEFAULT 'admin',
        admin_id bigint(20) unsigned NOT NULL DEFAULT 0,
        created datetime NOT NULL,
        PRIMARY KEY  (sample_id,source)
    ) $charset;");
    dbDelta("CREATE TABLE $m (
        version varchar(32) NOT NULL,
        file_url varchar(500) NOT NULL,
        sha256 char(64) NOT NULL,
        size_bytes bigint(20) unsigned NOT NULL DEFAULT 0,
        thresholds_json text NOT NULL,
        eval_json text NOT NULL,
        rollout_pct tinyint(3) unsigned NOT NULL DEFAULT 0,
        status varchar(8) NOT NULL DEFAULT 'draft',
        created datetime NOT NULL,
        PRIMARY KEY  (version)
    ) $charset;");
    if (get_option('ma_nlu_salt', '') === '') {
        update_option('ma_nlu_salt', bin2hex(random_bytes(16)), false);
    }
    // Gemini's published standard price (USD per million tokens), 22 Oct 2026; editable with the others.
    $p = ma_ai_prices();
    if (!isset($p['gemini-3.1-flash-lite'])) {
        $p['gemini-3.1-flash-lite'] = ['in' => 0.25, 'cw' => 0, 'cr' => 0.025, 'out' => 1.50];
        update_option('ma_ai_prices', wp_json_encode($p), false);
    }
    if (!wp_next_scheduled('ma_nlu_purge')) {
        wp_schedule_event(time() + HOUR_IN_SECONDS, 'daily', 'ma_nlu_purge');
    }
}

// Samples older than 180 days go.
add_action('ma_nlu_purge', 'ma_nlu_purge');
function ma_nlu_purge() {
    global $wpdb;
    $cut = gmdate('Y-m-d H:i:s', time() - MA_NLU_KEEP_DAYS * DAY_IN_SECONDS);
    $old = $wpdb->get_col($wpdb->prepare('SELECT id FROM ' . ma_nlu_table('samples') . ' WHERE created < %s', $cut));
    ma_nlu_delete_samples($old);
    return count($old);
}

function ma_nlu_delete_samples($ids) {
    global $wpdb;
    $ids = array_map('intval', (array) $ids);
    if (!$ids) {
        return;
    }
    $in = implode(',', $ids);
    $wpdb->query('DELETE FROM ' . ma_nlu_table('labels') . " WHERE sample_id IN ($in)");
    $wpdb->query('DELETE FROM ' . ma_nlu_table('samples') . " WHERE id IN ($in)");
}

/** A member's samples are found by this hash only (no member id in the table). */
function ma_nlu_user_hash($user_id) {
    return hash('sha256', get_option('ma_nlu_salt', '') . ':' . (int) $user_id);
}

/** A deleted member's samples go with them. */
function ma_nlu_forget_member($user_id) {
    global $wpdb;
    ma_nlu_delete_samples($wpdb->get_col($wpdb->prepare('SELECT id FROM ' . ma_nlu_table('samples') . ' WHERE user_hash = %s', ma_nlu_user_hash($user_id))));
}

// ── Settings ──

function ma_nlu_settings() {
    $s = json_decode((string) get_option('ma_nlu_settings', ''), true);
    $s = is_array($s) ? $s : [];
    return [
        'mode' => in_array($s['mode'] ?? '', ['off', 'shadow', 'on'], true) ? $s['mode'] : 'shadow',
        'pct' => max(0, min(100, (int) ($s['pct'] ?? 100))),
        'cloud_on' => (bool) ($s['cloud_on'] ?? true),
        'free_model' => (string) ($s['free_model'] ?? 'gemini-3.1-flash-lite'),
        'pro_model' => (string) ($s['pro_model'] ?? 'claude-haiku-5-5'),
        'escalate_model' => (string) ($s['escalate_model'] ?? 'claude-sonnet-5-5'),
        'escalate_below' => max(0, min(1, (float) ($s['escalate_below'] ?? 0.4))),
        'escalate_share' => max(0, min(0.2, (float) ($s['escalate_share'] ?? 0.05))),
        'free_per_user' => max(0, (int) ($s['free_per_user'] ?? 20)),
        'pro_per_user' => max(0, (int) ($s['pro_per_user'] ?? 60)),
        'prompt_ver' => MA_NLU_PROMPT_VER,
        'consent_ver' => (string) ($s['consent_ver'] ?? '1'),
    ];
}

function ma_nlu_save_settings($in) {
    $cur = ma_nlu_settings();
    foreach (['mode', 'free_model', 'pro_model', 'escalate_model', 'consent_ver'] as $k) {
        if (isset($in[$k])) {
            $cur[$k] = sanitize_text_field((string) $in[$k]);
        }
    }
    foreach (['pct', 'free_per_user', 'pro_per_user'] as $k) {
        if (isset($in[$k])) {
            $cur[$k] = (int) $in[$k];
        }
    }
    foreach (['escalate_below', 'escalate_share'] as $k) {
        if (isset($in[$k])) {
            $cur[$k] = (float) $in[$k];
        }
    }
    if (isset($in['cloud_on'])) {
        $cur['cloud_on'] = (bool) $in['cloud_on'];
    }
    unset($cur['prompt_ver']);
    update_option('ma_nlu_settings', wp_json_encode($cur), false);
    return ma_nlu_settings();
}

/** 0–99: a member's fixed place in rollouts (the same member is always in or out). */
function ma_nlu_bucket($user_id) {
    return hexdec(substr(ma_nlu_user_hash($user_id), 0, 6)) % 100;
}

function ma_nlu_is_pro($row) {
    return ma_acc_ts($row['pro_until'] ?? null) > time();
}

/** Gemini's key: MA_GEMINI_API_KEY in wp-config.php, or the saved one. */
function ma_nlu_gemini_key() {
    if (defined('MA_GEMINI_API_KEY') && MA_GEMINI_API_KEY) {
        return (string) MA_GEMINI_API_KEY;
    }
    return (string) get_option('ma_gemini_key', '');
}

function ma_nlu_gemini_key_source() {
    if (defined('MA_GEMINI_API_KEY') && MA_GEMINI_API_KEY) {
        return 'config';
    }
    return get_option('ma_gemini_key', '') !== '' ? 'saved' : '';
}

// ── Models ──

function ma_nlu_model_json($m) {
    return [
        'version' => $m['version'], 'url' => $m['file_url'], 'sha256' => $m['sha256'], 'size' => (int) $m['size_bytes'],
        'rollout_pct' => (int) $m['rollout_pct'], 'status' => $m['status'], 'created' => $m['created'],
        'thresholds' => json_decode($m['thresholds_json'], true) ?: (object) [], 'eval' => json_decode($m['eval_json'], true) ?: (object) [],
    ];
}

/** The newest live model whose rollout share takes this member in, or null (keep the built-in one). */
function ma_nlu_model_for($user_id) {
    global $wpdb;
    $b = ma_nlu_bucket($user_id);
    foreach ($wpdb->get_results('SELECT * FROM ' . ma_nlu_table('models') . " WHERE status = 'live' ORDER BY created DESC, version DESC", ARRAY_A) ?: [] as $m) {
        if ($b < (int) $m['rollout_pct']) {
            return $m;
        }
    }
    return null;
}

// ── Samples ──

/** True when the words still hold something that must not leave the phone. */
function ma_nlu_unsafe($text) {
    $t = (string) $text;
    $digits = strtr($t, ['০' => '0', '১' => '1', '২' => '2', '৩' => '3', '৪' => '4', '৫' => '5', '৬' => '6', '৭' => '7', '৮' => '8', '৯' => '9']);
    if (preg_match('/(?:\+?88)?0?1[3-9]\d{8}/', preg_replace('/[\s\-]/', '', $digits))) {
        return true; // a Bangladeshi mobile number
    }
    if (preg_match('/\d{6,}/', preg_replace('/[\s\-]/', '', $digits)) && !preg_match('/\d{6,}\s*(টাকা|tk|\/=)/u', $digits)) {
        return true; // a long code (OTP, card, account)
    }
    if (preg_match('/(ওষুধ|ঔষধ|ট্যাবলেট|ক্যাপসুল|ইনসুলিন|প্রেশার|প্রেসার|ডায়াবেটিস|সুগার|ডাক্তার|হাসপাতাল|অসুখ|জ্বর|medicine|doctor|insulin)/iu', $t)) {
        return true; // health and medicine stay on the phone (owner's rule)
    }
    return (bool) preg_match('/(পাসওয়ার্ড|পাসওয়ার্ড|password|পিন\b|pin\b|otp|ওটিপি|সিভিভি|cvv)/iu', $t);
}

function ma_nlu_json_text($v, $max = 4000) {
    $s = is_string($v) ? $v : wp_json_encode($v);
    return substr((string) $s, 0, $max);
}

/** One sample as stored; null when it may not be kept. */
function ma_nlu_sample_row($user_id, $x, $consent) {
    $text = (string) ($x['text_delex'] ?? '');
    if ($text === '' || mb_strlen($text) > MA_NLU_MAX_TEXT || ma_nlu_unsafe($text)) {
        return null;
    }
    $alts = array_values(array_filter(array_map('strval', (array) ($x['alts_delex'] ?? [])), function ($a) {
        return $a !== '' && mb_strlen($a) <= MA_NLU_MAX_TEXT && !ma_nlu_unsafe($a);
    }));
    $state = (string) ($x['state'] ?? '');
    $state = in_array($state, MA_NLU_STATES, true) ? $state : 'idle';
    $signal = (string) ($x['signal'] ?? '');
    $signal = in_array($signal, MA_NLU_SIGNALS, true) ? $signal : '';
    foreach (['local_json', 'cloud_json', 'final_json'] as $k) {
        if (isset($x[$k]) && ma_nlu_unsafe(ma_nlu_json_text($x[$k]))) {
            return null;
        }
    }
    return [
        'user_hash' => ma_nlu_user_hash($user_id),
        'created' => current_time('mysql', true),
        'app_ver' => substr(sanitize_text_field((string) ($x['app_ver'] ?? '')), 0, 32),
        'model_ver' => substr(sanitize_text_field((string) ($x['model_ver'] ?? '')), 0, 32),
        'state' => $state,
        'text_delex' => $text,
        'alts_delex' => wp_json_encode(array_slice($alts, 0, 5)),
        'local_json' => ma_nlu_json_text($x['local_json'] ?? ''),
        'local_conf' => max(0, min(1, (float) ($x['local_conf'] ?? 0))),
        'cloud_json' => ma_nlu_json_text($x['cloud_json'] ?? ''),
        'cloud_provider' => substr(sanitize_key((string) ($x['cloud_provider'] ?? '')), 0, 16),
        'final_json' => ma_nlu_json_text($x['final_json'] ?? ''),
        'signal_kind' => $signal,
        'consent_ver' => substr(sanitize_text_field((string) $consent), 0, 16),
    ];
}

// ── Cloud reading ──

function ma_nlu_prompt() {
    $list = '';
    foreach (MA_NLU_INTENTS as $id => $when) {
        $list .= "- $id: $when\n";
    }
    return "You read ONE message sent to a Bengali personal-assistant app (tasks, reminders, money, notes) and say what the user wants. Do not answer the user; only call route.\n"
        . "Rules: split a message with several requests into pieces, in order. Each piece gets exactly one intent from the list. For each fact copy the user's own words exactly (date, time, amount, person, title, list_ref…) — never compute, convert or invent numbers. "
        . "The app state and the kind of list on screen tell what a short answer (\"হ্যাঁ\", \"৩নং\", \"সন্ধ্যা ৭টায়\") means. A future plan is a task, a past event with money is a ledger or cash entry, a negated plan (\"যেতে হবে না\", \"দিইনি\") is correct. Names look like <নাম১>: keep them as written. A task's or reminder's name is the slot title; text is only for the words of a note, a memory or a message.\n"
        . "Intents:\n$list";
}

/** The route tool, for Anthropic (input_schema) and Gemini (parameters). */
function ma_nlu_route_schema() {
    return [
        'type' => 'object',
        'properties' => [
            'pieces' => [
                'type' => 'array',
                'items' => [
                    'type' => 'object',
                    'properties' => [
                        'intent' => ['type' => 'string', 'enum' => array_keys(MA_NLU_INTENTS)],
                        'slots' => [
                            'type' => 'array',
                            'items' => ['type' => 'object', 'properties' => ['name' => ['type' => 'string', 'enum' => MA_NLU_SLOTS], 'words' => ['type' => 'string']], 'required' => ['name', 'words']],
                        ],
                    ],
                    'required' => ['intent', 'slots'],
                ],
            ],
            'sure' => ['type' => 'number', 'description' => '0..1, how sure the reading is'],
        ],
        'required' => ['pieces', 'sure'],
    ];
}

function ma_nlu_user_message($in) {
    $guess = [];
    foreach (array_slice((array) ($in['top'] ?? []), 0, 3) as $g) {
        $guess[] = sanitize_key((string) ($g['intent'] ?? '')) . ' ' . round((float) ($g['conf'] ?? 0), 2);
    }
    return 'state: ' . $in['state'] . "\nlist on screen: " . $in['kind'] . "\nphone model's guesses: " . ($guess ? implode(', ', $guess) : 'none') . "\nmessage: " . $in['text'];
}

/** One HTTP call, tried once more on 429/529 or a timeout. → [code, body array|null]. */
function ma_nlu_post($url, $headers, $body) {
    for ($try = 0; $try < 2; $try++) {
        $res = wp_remote_post($url, ['timeout' => 25, 'headers' => $headers, 'body' => wp_json_encode($body)]);
        if (is_wp_error($res)) {
            $code = 0;
            $GLOBALS['ma_nlu_last_error'] = 'সংযোগ হয়নি';
        } else {
            $code = (int) wp_remote_retrieve_response_code($res);
            if ($code === 200) {
                return [200, json_decode(wp_remote_retrieve_body($res), true)];
            }
            // Only the provider's short error message (never the member's words).
            $err = json_decode(wp_remote_retrieve_body($res), true);
            $GLOBALS['ma_nlu_last_error'] = $code . ' ' . substr((string) ($err['error']['message'] ?? $err['error']['status'] ?? ''), 0, 160);
        }
        if (!in_array($code, [0, 429, 529, 503], true)) {
            return [$code, null];
        }
    }
    return [$code, null];
}

/** Anthropic: route tool forced; the fixed instructions are cached. → [pieces-json, usage] or null. */
function ma_nlu_call_anthropic($model, $in) {
    $key = ma_ai_key();
    if ($key === '') {
        return null;
    }
    [$code, $j] = ma_nlu_post('https://api.anthropic.com/v1/messages', ['content-type' => 'application/json', 'x-api-key' => $key, 'anthropic-version' => '2023-06-01'], [
        'model' => $model,
        'max_tokens' => 600,
        'system' => [['type' => 'text', 'text' => ma_nlu_prompt(), 'cache_control' => ['type' => 'ephemeral']]],
        'tools' => [['name' => 'route', 'description' => 'What the message asks for', 'input_schema' => ma_nlu_route_schema()]],
        'tool_choice' => ['type' => 'tool', 'name' => 'route'],
        'messages' => [['role' => 'user', 'content' => ma_nlu_user_message($in)]],
    ]);
    if ($code !== 200 || !is_array($j)) {
        return null;
    }
    foreach ((array) ($j['content'] ?? []) as $c) {
        if (($c['type'] ?? '') === 'tool_use' && ($c['name'] ?? '') === 'route') {
            return [$c['input'], (array) ($j['usage'] ?? [])];
        }
    }
    return null;
}

/** Gemini: the same tool as a function declaration, called by force. */
function ma_nlu_call_gemini($model, $in) {
    $key = ma_nlu_gemini_key();
    if ($key === '') {
        return null;
    }
    [$code, $j] = ma_nlu_post("https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent", ['content-type' => 'application/json', 'x-goog-api-key' => $key], [
        'systemInstruction' => ['parts' => [['text' => ma_nlu_prompt()]]],
        'contents' => [['role' => 'user', 'parts' => [['text' => ma_nlu_user_message($in)]]]],
        'tools' => [['functionDeclarations' => [['name' => 'route', 'description' => 'What the message asks for', 'parameters' => ma_nlu_route_schema()]]]],
        'toolConfig' => ['functionCallingConfig' => ['mode' => 'ANY', 'allowedFunctionNames' => ['route']]],
        'generationConfig' => ['temperature' => 0],
    ]);
    if ($code !== 200 || !is_array($j)) {
        return null;
    }
    foreach ((array) ($j['candidates'][0]['content']['parts'] ?? []) as $p) {
        if (($p['functionCall']['name'] ?? '') === 'route') {
            $u = (array) ($j['usageMetadata'] ?? []);
            $cached = (int) ($u['cachedContentTokenCount'] ?? 0);
            return [$p['functionCall']['args'], [
                'input_tokens' => max(0, (int) ($u['promptTokenCount'] ?? 0) - $cached),
                'cache_read_input_tokens' => $cached,
                'output_tokens' => (int) ($u['candidatesTokenCount'] ?? 0) + (int) ($u['thoughtsTokenCount'] ?? 0),
            ]];
        }
    }
    return null;
}

/** Only known intents and slots, words that are really in the message; anything else is dropped. */
function ma_nlu_clean_reading($r, $text) {
    $pieces = [];
    foreach ((array) ($r['pieces'] ?? []) as $p) {
        $intent = (string) ($p['intent'] ?? '');
        if (!isset(MA_NLU_INTENTS[$intent])) {
            continue;
        }
        $slots = [];
        foreach ((array) ($p['slots'] ?? []) as $s) {
            $name = (string) ($s['name'] ?? '');
            $words = trim((string) ($s['words'] ?? ''));
            // A model never adds a number or a word: a fact must be words the user said.
            if (in_array($name, MA_NLU_SLOTS, true) && $words !== '' && mb_stripos($text, $words) !== false) {
                $slots[] = ['name' => $name, 'words' => $words];
            }
        }
        $pieces[] = ['intent' => $intent, 'slots' => $slots];
    }
    return ['pieces' => $pieces, 'sure' => max(0, min(1, (float) ($r['sure'] ?? 0)))];
}

function ma_nlu_used_today($user_id) {
    return (int) get_transient('ma_nlu_used_' . $user_id . '_' . ma_ai_today());
}

function ma_nlu_count_use($user_id, $model) {
    $k = 'ma_nlu_used_' . $user_id . '_' . ma_ai_today();
    set_transient($k, ma_nlu_used_today($user_id) + 1, 2 * DAY_IN_SECONDS);
    $d = 'ma_nlu_day_' . ma_ai_today();
    $c = get_transient($d) ?: ['all' => 0, 'escalated' => 0];
    $c['all']++;
    if (str_contains($model, 'sonnet')) {
        $c['escalated']++;
    }
    set_transient($d, $c, 2 * DAY_IN_SECONDS);
}

/** Sonnet only while it stays within its share of the day's cloud readings. */
function ma_nlu_may_escalate($set) {
    $c = get_transient('ma_nlu_day_' . ma_ai_today()) ?: ['all' => 0, 'escalated' => 0];
    return ($c['escalated'] + 1) <= max(1, floor(($c['all'] + 1) * $set['escalate_share']));
}

function ma_nlu_provider_of($model) {
    return str_starts_with($model, 'gemini') ? 'gemini' : 'anthropic';
}

function ma_nlu_resolve(WP_REST_Request $req) {
    $row = ma_ai_member($req);
    if (!$row) {
        return new WP_Error('session', 'sign in again', ['status' => 401]);
    }
    $set = ma_nlu_settings();
    if (!$set['cloud_on'] || $set['mode'] === 'off' || !get_option('ma_ai_on', '0')) {
        return new WP_Error('off', 'cloud reading is off', ['status' => 503]);
    }
    $in = json_decode($req->get_body(), true);
    $text = is_array($in) ? (string) ($in['text'] ?? '') : '';
    if ($text === '' || mb_strlen($text) > MA_NLU_MAX_TEXT) {
        return new WP_Error('bad', 'bad request', ['status' => 400]);
    }
    // The phone takes names out and keeps secrets; anything that still looks like a number or a code is refused.
    if (ma_nlu_unsafe($text)) {
        return new WP_Error('private', 'stays on the phone', ['status' => 422]);
    }
    $in['state'] = in_array($in['state'] ?? '', MA_NLU_STATES, true) ? $in['state'] : 'idle';
    $in['kind'] = in_array($in['kind'] ?? '', ['none', 'tasks', 'reminders'], true) ? $in['kind'] : 'none';
    $pro = ma_nlu_is_pro($row);
    $plan = $pro ? 'pro' : 'free';
    $limit = $pro ? $set['pro_per_user'] : $set['free_per_user'];
    if (ma_nlu_used_today((int) $row['id']) >= $limit) {
        return new WP_Error('limit', 'daily limit', ['status' => 429]);
    }
    if (ma_ai_over_budget($plan)) {
        return new WP_Error('budget', 'budget used up', ['status' => 503]);
    }
    if ($pro && ma_ai_member_over((int) $row['id'])) {
        return new WP_Error('limit', 'monthly limit', ['status' => 429]);
    }
    $local = (float) ($in['local_conf'] ?? 1);
    $first = $pro ? $set['pro_model'] : $set['free_model'];
    $order = [$first, $pro ? $set['free_model'] : $set['pro_model']];
    if ($pro && $local < $set['escalate_below'] && ma_nlu_may_escalate($set)) {
        array_unshift($order, $set['escalate_model']);
    }
    foreach (array_unique($order) as $model) {
        $got = ma_nlu_provider_of($model) === 'gemini' ? ma_nlu_call_gemini($model, $in) : ma_nlu_call_anthropic($model, $in);
        if (!$got) {
            continue;
        }
        [$reading, $usage] = $got;
        $cost = ma_ai_count((int) $row['id'], $plan, $model, ma_nlu_provider_of($model), $usage);
        ma_nlu_count_use((int) $row['id'], $model);
        $clean = ma_nlu_clean_reading($reading, $text);
        // With consent, the cloud reading is kept as a learning sample.
        $consent = (string) ($in['consent_ver'] ?? '');
        if ($consent !== '') {
            $s = ma_nlu_sample_row((int) $row['id'], [
                'text_delex' => $text, 'state' => $in['state'], 'app_ver' => $in['app_ver'] ?? '', 'model_ver' => $in['model_ver'] ?? '',
                'local_json' => $in['top'] ?? [], 'local_conf' => $local, 'cloud_json' => $clean, 'cloud_provider' => str_contains($model, 'sonnet') ? 'sonnet' : (ma_nlu_provider_of($model) === 'gemini' ? 'gemini' : 'haiku'),
            ], $consent);
            if ($s) {
                global $wpdb;
                $wpdb->insert(ma_nlu_table('samples'), $s);
            }
        }
        return rest_ensure_response($clean + ['model' => $model, 'prompt_ver' => MA_NLU_PROMPT_VER, 'cost_micro_usd' => $cost]);
    }
    return new WP_Error('upstream', 'no cloud model answered', ['status' => 504]);
}

// ── REST ──

add_action('rest_api_init', function () {
    $member = function ($path, $method, $cb) {
        register_rest_route('my-assistant/v1', $path, ['methods' => $method, 'callback' => $cb, 'permission_callback' => '__return_true']);
    };
    $member('/nlu/config', 'GET', function (WP_REST_Request $req) {
        $row = ma_ai_member($req);
        if (!$row) {
            return new WP_Error('session', 'sign in again', ['status' => 401]);
        }
        $set = ma_nlu_settings();
        $m = ma_nlu_model_for((int) $row['id']);
        $pro = ma_nlu_is_pro($row);
        $limit = $pro ? $set['pro_per_user'] : $set['free_per_user'];
        return [
            'mode' => ma_nlu_bucket((int) $row['id']) < $set['pct'] ? $set['mode'] : 'off',
            'cloud' => $set['cloud_on'] && get_option('ma_ai_on', '0') === '1',
            'cloud_left' => max(0, $limit - ma_nlu_used_today((int) $row['id'])),
            'thresholds' => $m ? (json_decode($m['thresholds_json'], true) ?: (object) []) : (object) [],
            'model' => $m ? $m['version'] : null,
            'prompt_ver' => MA_NLU_PROMPT_VER,
            'consent_ver' => $set['consent_ver'],
        ];
    });
    $member('/nlu/model', 'GET', function (WP_REST_Request $req) {
        $row = ma_ai_member($req);
        if (!$row) {
            return new WP_Error('session', 'sign in again', ['status' => 401]);
        }
        $m = ma_nlu_model_for((int) $row['id']);
        return $m ? ma_nlu_model_json($m) : new WP_REST_Response(null, 204);
    });
    $member('/nlu/resolve', 'POST', 'ma_nlu_resolve');
    $member('/nlu/samples', 'POST', function (WP_REST_Request $req) {
        $row = ma_ai_member($req);
        if (!$row) {
            return new WP_Error('session', 'sign in again', ['status' => 401]);
        }
        $in = json_decode($req->get_body(), true);
        $consent = is_array($in) ? (string) ($in['consent_ver'] ?? '') : '';
        if ($consent === '') {
            return new WP_Error('consent', 'no consent', ['status' => 403]);
        }
        $list = (array) ($in['samples'] ?? []);
        if (count($list) > 100) {
            return new WP_Error('size', 'at most 100 at a time', ['status' => 413]);
        }
        global $wpdb;
        $kept = 0;
        foreach ($list as $x) {
            $s = is_array($x) ? ma_nlu_sample_row((int) $row['id'], $x, $consent) : null;
            if ($s) {
                $wpdb->insert(ma_nlu_table('samples'), $s);
                $kept++;
            }
        }
        return ['ok' => true, 'kept' => $kept, 'refused' => count($list) - $kept];
    });
    $member('/nlu/samples/mine', 'DELETE', function (WP_REST_Request $req) {
        $row = ma_ai_member($req);
        if (!$row) {
            return new WP_Error('session', 'sign in again', ['status' => 401]);
        }
        global $wpdb;
        $ids = $wpdb->get_col($wpdb->prepare('SELECT id FROM ' . ma_nlu_table('samples') . ' WHERE user_hash = %s', ma_nlu_user_hash((int) $row['id'])));
        ma_nlu_delete_samples($ids);
        return ['ok' => true, 'deleted' => count($ids)];
    });

    // ── Admin ──
    ma_admin_route('/ai/selftest', 'POST', function (WP_REST_Request $req) {
        $admin = ma_admin_of($req);
        if (!user_can((int) $admin['id'], 'manage_options')) {
            return new WP_Error('owner', 'site owner only', ['status' => 403]);
        }
        return ma_nlu_selftest();
    });
    ma_admin_route('/nlu/export', 'GET', function (WP_REST_Request $req) {
        $admin = ma_admin_of($req);
        if (!user_can((int) $admin['id'], 'manage_options')) {
            return new WP_Error('owner', 'site owner only', ['status' => 403]);
        }
        global $wpdb;
        $s = ma_nlu_table('samples');
        $l = ma_nlu_table('labels');
        $since = (int) $req->get_param('since_id');
        $rows = $wpdb->get_results($wpdb->prepare("SELECT s.id, s.created, s.app_ver, s.model_ver, s.state, s.text_delex, s.alts_delex, s.local_json, s.local_conf, s.cloud_json, s.cloud_provider, s.final_json, s.signal_kind, l.label_json admin_label FROM $s s LEFT JOIN $l l ON l.sample_id = s.id AND l.source = 'admin' WHERE s.id > %d ORDER BY s.id LIMIT 2000", $since), ARRAY_A) ?: [];
        return ['samples' => $rows];
    });
});

/** Overview numbers for the admin app and the settings page. */
function ma_nlu_overview() {
    global $wpdb;
    $s = ma_nlu_table('samples');
    $from = gmdate('Y-m-d 00:00:00', time() - 30 * DAY_IN_SECONDS);
    $n = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $s WHERE created >= %s", $from));
    $sig = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $s WHERE created >= %s AND signal_kind NOT IN ('', 'thumbs_up')", $from));
    // The weakest intents: the phone's reading, how often it drew an error
    // signal or a different final/cloud reading (at least 5 samples).
    $per = [];
    foreach ($wpdb->get_results($wpdb->prepare("SELECT local_json, cloud_json, final_json, signal_kind FROM $s WHERE created >= %s ORDER BY id DESC LIMIT 5000", $from), ARRAY_A) ?: [] as $r) {
        $first = function ($j) {
            $d = json_decode((string) $j, true);
            $p = $d['pieces'][0]['intent'] ?? ($d[0]['intent'] ?? null);
            return is_string($p) ? $p : null;
        };
        $a = $first($r['local_json']);
        if (!$a) {
            continue;
        }
        $b = $first($r['final_json']) ?: $first($r['cloud_json']);
        $bad = ($r['signal_kind'] !== '' && $r['signal_kind'] !== 'thumbs_up') || ($b && $b !== $a);
        $per[$a] = $per[$a] ?? ['intent' => $a, 'n' => 0, 'bad' => 0];
        $per[$a]['n']++;
        $per[$a]['bad'] += $bad ? 1 : 0;
    }
    $weak = array_values(array_filter($per, function ($x) {
        return $x['n'] >= 5;
    }));
    usort($weak, function ($x, $y) {
        return $y['bad'] / $y['n'] <=> $x['bad'] / $x['n'];
    });
    $weak = array_map(function ($x) {
        return $x + ['ok_share' => round(1 - $x['bad'] / $x['n'], 3)];
    }, array_slice($weak, 0, 5));
    return ['settings' => ma_nlu_settings(), 'samples_30d' => $n, 'error_signals_per_100' => $n ? round(100 * $sig / $n, 1) : 0, 'weakest' => $weak, 'day' => get_transient('ma_nlu_day_' . ma_ai_today()) ?: ['all' => 0, 'escalated' => 0]];
}

/**
 * One real call to each cloud reader with a fixed made-up sentence, so the
 * owner can see that the keys and the request shape work (costs a fraction
 * of a cent; counted like any other call, under the admin's id 0).
 */
function ma_nlu_selftest() {
    $in = ['text' => 'কাল সকালে ব্যাংকে যেতে হবে', 'state' => 'idle', 'kind' => 'none', 'top' => []];
    $set = ma_nlu_settings();
    $out = [];
    foreach (['gemini' => $set['free_model'], 'anthropic' => $set['pro_model']] as $who => $model) {
        $t0 = microtime(true);
        $got = $who === 'gemini' ? ma_nlu_call_gemini($model, $in) : ma_nlu_call_anthropic($model, $in);
        $ms = (int) round((microtime(true) - $t0) * 1000);
        if (!$got) {
            $out[$who] = ['ok' => false, 'model' => $model, 'ms' => $ms, 'error' => $GLOBALS['ma_nlu_last_error'] ?? ''];
            continue;
        }
        $cost = ma_ai_count(0, 'free', $model, ma_nlu_provider_of($model), $got[1]);
        $clean = ma_nlu_clean_reading($got[0], $in['text']);
        $out[$who] = ['ok' => $clean['pieces'] !== [], 'model' => $model, 'ms' => $ms, 'cost_micro_usd' => $cost, 'reading' => $clean];
    }
    return $out;
}

add_action('admin_post_ma_nlu_selftest', function () {
    ma_acc_guard('ma_nlu_selftest', 'manage_options');
    $r = ma_nlu_selftest();
    $say = [];
    foreach ($r as $who => $x) {
        $name = $who === 'gemini' ? 'Gemini' : 'Claude';
        if ($x['ok']) {
            $p = $x['reading']['pieces'][0];
            $say[] = "$name কাজ করছে ({$x['model']}, {$x['ms']} ms): " . $p['intent'] . ' — ' . implode(', ', array_map(function ($s) {
                return $s['name'] . '=' . $s['words'];
            }, $p['slots']));
        } else {
            $say[] = "$name কাজ করছে না ({$x['model']})" . ($x['error'] !== '' ? ': ' . $x['error'] : '');
        }
    }
    $all = !in_array(false, array_column($r, 'ok'), true);
    ma_acc_back(implode(' · ', $say), $all ? 'ok' : 'error', ['tab' => 'settings']);
});

// ── The retraining job (GitHub Actions, tool/nlu/retrain): its own narrow key ──
// It can only read the labelled samples and add a model as a draft — never
// make one live, change settings or see members. The key is made on the
// settings page (or MA_NLU_CI_KEY in wp-config.php) and kept as a GitHub secret.

function ma_nlu_ci_key() {
    if (defined('MA_NLU_CI_KEY') && MA_NLU_CI_KEY) {
        return (string) MA_NLU_CI_KEY;
    }
    return (string) get_option('ma_nlu_ci_key', '');
}

function ma_nlu_ci_ok(WP_REST_Request $req) {
    $key = ma_nlu_ci_key();
    $got = (string) $req->get_header('x-ma-ci-key');
    return strlen($key) >= 32 && hash_equals($key, $got) ? true : new WP_Error('ci', 'not allowed', ['status' => 403]);
}

function ma_nlu_export_rows($since) {
    global $wpdb;
    $s = ma_nlu_table('samples');
    $l = ma_nlu_table('labels');
    return $wpdb->get_results($wpdb->prepare("SELECT s.id, s.created, s.app_ver, s.model_ver, s.state, s.text_delex, s.alts_delex, s.local_json, s.local_conf, s.cloud_json, s.cloud_provider, s.final_json, s.signal_kind, l.label_json admin_label FROM $s s LEFT JOIN $l l ON l.sample_id = s.id AND l.source = 'admin' WHERE s.id > %d ORDER BY s.id LIMIT 2000", (int) $since), ARRAY_A) ?: [];
}

/** Adds a model as a draft (an admin still has to make it live). */
function ma_nlu_add_draft($in) {
    global $wpdb;
    $t = ma_nlu_table('models');
    $ver = sanitize_text_field((string) ($in['version'] ?? ''));
    $url = esc_url_raw((string) ($in['url'] ?? ''));
    $sha = strtolower((string) ($in['sha256'] ?? ''));
    if (!preg_match('/^[A-Za-z0-9._\-]{1,32}$/', $ver) || !str_starts_with($url, 'https://') || !preg_match('/^[a-f0-9]{64}$/', $sha)) {
        return new WP_Error('bad', 'need a version, an https url and a sha256', ['status' => 400]);
    }
    if ($wpdb->get_var($wpdb->prepare("SELECT version FROM $t WHERE version = %s", $ver))) {
        return new WP_Error('exists', 'version exists', ['status' => 409]);
    }
    $wpdb->insert($t, ['version' => $ver, 'file_url' => $url, 'sha256' => $sha, 'size_bytes' => max(0, (int) ($in['size'] ?? 0)), 'thresholds_json' => wp_json_encode($in['thresholds'] ?? new stdClass()), 'eval_json' => wp_json_encode($in['eval'] ?? new stdClass()), 'rollout_pct' => 0, 'status' => 'draft', 'created' => current_time('mysql', true)]);
    return ma_nlu_model_json($wpdb->get_row($wpdb->prepare("SELECT * FROM $t WHERE version = %s", $ver), ARRAY_A));
}

add_action('rest_api_init', function () {
    register_rest_route('my-assistant/v1', '/nlu/ci/export', ['methods' => 'GET', 'permission_callback' => 'ma_nlu_ci_ok', 'callback' => function (WP_REST_Request $req) {
        return ['samples' => ma_nlu_export_rows((int) $req->get_param('since_id'))];
    }]);
    register_rest_route('my-assistant/v1', '/nlu/ci/model', ['methods' => 'POST', 'permission_callback' => 'ma_nlu_ci_ok', 'callback' => function (WP_REST_Request $req) {
        $r = ma_nlu_add_draft(json_decode($req->get_body(), true) ?: []);
        return is_wp_error($r) ? $r : ['ok' => true, 'model' => $r];
    }]);
});

add_action('admin_post_ma_nlu_ci_key', function () {
    ma_acc_guard('ma_nlu_ci_key', 'manage_options');
    update_option('ma_nlu_ci_key', bin2hex(random_bytes(24)), false);
    ma_acc_back('নতুন শেখানোর key বানানো হয়েছে — GitHub-এর secret MA_NLU_CI_KEY-তে বসান।', 'ok', ['tab' => 'settings']);
});
