<?php
// End-to-end check of the My Assistant Accounts plugin inside a real WordPress (SQLite).
$_SERVER['HTTP_HOST'] = '127.0.0.1:8899';
$_SERVER['REMOTE_ADDR'] = '10.0.0.' . rand(1, 250);
require $argv[1] . '/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';
require_once ABSPATH . 'wp-admin/includes/admin.php';
$fail = 0;
function check($ok, $what) { global $fail; echo ($ok ? "  ok   " : "  FAIL ") . $what . "\n"; if (!$ok) $fail++; }

$r = activate_plugin('my-assistant-accounts/my-assistant-accounts.php');
check(!is_wp_error($r), 'activates' . (is_wp_error($r) ? ': ' . $r->get_error_message() : ''));
global $wpdb;
foreach (['ma_users', 'ma_sessions', 'ma_ai_usage', 'ma_payments', 'ma_notices', 'ma_feedback', 'ma_feedback_msgs', 'ma_donors', 'ma_blood_requests', 'ma_blood_accepts'] as $t) {
    check($wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}$t") !== null, "table $t");
}
update_option('ma_acc_google_client_ids', 'web-client.apps.googleusercontent.com');
update_option('ma_ai_on', '1');
update_option('ma_ai_key', 'sk-ant-test-0123456789abcdefghijkl');
update_option('ma_fcm_account', wp_json_encode(['client_email' => 'x@y.iam.gserviceaccount.com', 'project_id' => 'my-assistant', 'private_key' => openssl_pkey_export(openssl_pkey_new(['private_key_bits' => 2048]), $pk) ? $pk : '']));

// Google, Anthropic and Firebase, pretended.
$sent = ['ai' => [], 'fcm' => [], 'mail' => [], 'metal' => [], 'nlu' => []];
$GLOBALS['gem_fail'] = [];
$GLOBALS['ant_fail'] = [];
add_filter('pre_http_request', function ($pre, $args, $url) use (&$sent) {
    if (str_contains($url, 'tokeninfo')) {
        parse_str(parse_url($url, PHP_URL_QUERY), $q);
        $who = str_starts_with($q['id_token'], 'NLUFREE') ? ['sub' => 'g-nlu-free', 'email' => 'free@x.com', 'name' => 'Free'] : (str_starts_with($q['id_token'], 'BOSS') ? ['sub' => 'g-boss', 'email' => 'boss@gmail.com', 'name' => 'Boss'] : ['sub' => 'g-rahim', 'email' => 'rahim@gmail.com', 'name' => 'রহিম উদ্দিন', 'picture' => 'https://lh3.googleusercontent.com/a/abc']);
        $aud = str_contains($q['id_token'], 'WRONGAUD') ? 'other.apps.googleusercontent.com' : 'web-client.apps.googleusercontent.com';
        return ['response' => ['code' => 200], 'body' => wp_json_encode($who + ['iss' => 'https://accounts.google.com', 'aud' => $aud, 'exp' => time() + 600, 'email_verified' => 'true']), 'headers' => [], 'cookies' => []];
    }
    if (str_contains($url, 'api.anthropic.com') && str_contains($args['body'], 'web_search')) {
        $sent['metal'][] = json_decode($args['body'], true);
        return ['response' => ['code' => 200], 'body' => wp_json_encode(['stop_reason' => 'end_turn', 'content' => [['type' => 'text', 'text' => $GLOBALS['metal_reply']]]]), 'headers' => [], 'cookies' => []];
    }
    // The cloud reading (/nlu/resolve): a forced "route" tool call.
    if ((str_contains($url, 'api.anthropic.com') || str_contains($url, 'generativelanguage.googleapis.com')) && str_contains($args['body'], '"route"')) {
        $gem = str_contains($url, 'generativelanguage');
        $body = json_decode($args['body'], true);
        $sent['nlu'][] = ['url' => $url, 'body' => $body, 'headers' => $args['headers']];
        $fail = array_shift($GLOBALS[$gem ? 'gem_fail' : 'ant_fail']);
        if ($fail) {
            return ['response' => ['code' => $fail], 'body' => '{}', 'headers' => [], 'cookies' => []];
        }
        $route = $GLOBALS['nlu_reply'];
        if ($gem) {
            return ['response' => ['code' => 200], 'body' => wp_json_encode(['candidates' => [['content' => ['parts' => [['functionCall' => ['name' => 'route', 'args' => $route]]]]]], 'usageMetadata' => ['promptTokenCount' => 1500, 'cachedContentTokenCount' => 1000, 'candidatesTokenCount' => 40]]), 'headers' => [], 'cookies' => []];
        }
        return ['response' => ['code' => 200], 'body' => wp_json_encode(['content' => [['type' => 'tool_use', 'name' => 'route', 'input' => $route]], 'usage' => ['input_tokens' => 300, 'cache_read_input_tokens' => 1200, 'output_tokens' => 50]]), 'headers' => [], 'cookies' => []];
    }
    if (str_contains($url, 'api.anthropic.com')) {
        $sent['ai'][] = $args;
        return ['response' => ['code' => 200], 'body' => wp_json_encode(['content' => [['type' => 'text', 'text' => 'ঠিক আছে']], 'usage' => ['input_tokens' => 1200, 'output_tokens' => 80]]), 'headers' => [], 'cookies' => []];
    }
    if (str_contains($url, 'oauth2.googleapis.com/token')) {
        return ['response' => ['code' => 200], 'body' => '{"access_token":"fcm-access"}', 'headers' => [], 'cookies' => []];
    }
    if (str_contains($url, 'fcm.googleapis.com')) {
        $sent['fcm'][] = json_decode($args['body'], true);
        return ['response' => ['code' => 200], 'body' => '{}', 'headers' => [], 'cookies' => []];
    }
    return $pre;
}, 10, 3);
add_filter('pre_wp_mail', function ($r, $atts) use (&$sent) { $sent['mail'][] = $atts; return true; }, 10, 2);

function call($method, $route, $body = [], $session = null) {
    $req = new WP_REST_Request($method, '/my-assistant/v1' . $route);
    if ($session) $req->set_header('authorization', 'Bearer ' . $session);
    if ($method === 'GET') { foreach ($body as $k => $v) $req->set_param($k, $v); }
    else { $req->set_header('content-type', 'application/json'); $req->set_body(wp_json_encode($body)); }
    $res = rest_do_request($req);
    return [$res->get_status(), rest_get_server()->response_to_data($res, false)];
}
$long = str_repeat('x', 120);

echo "\nmember\n";
[$code, $d] = call('POST', '/login', ['id_token' => 'RAHIM' . $long, 'app_version' => '2.14.0', 'edition' => 'play']);
check($code === 200 && strlen($d['session'] ?? '') === 64, 'login gives a session');
// Pro's daily AI limit is 30 (21 Oct 2026 brief; was 50).
check(($d['ai'] ?? null) === true && ($d['ai_left'] ?? 0) === 30, 'AI on, 30 left');
check(($d['admin'] ?? false) === false, 'a member is not an admin');
$ses = $d['session'];
[$code] = call('POST', '/login', ['id_token' => 'RAHIMWRONGAUD' . $long]);
check($code === 401, 'token for another app is refused');
$u = $wpdb->get_row("SELECT * FROM {$wpdb->prefix}ma_users WHERE email = 'rahim@gmail.com'", ARRAY_A);
check($u && $u['picture'] === 'https://lh3.googleusercontent.com/a/abc' && $u['name'] === 'রহিম উদ্দিন', 'member saved with name and photo');
[$code, $d] = call('POST', '/ai', ['model' => 'claude-haiku-5-5', 'max_tokens' => 4000, 'messages' => [['role' => 'user', 'content' => 'হ্যালো']]], $ses);
check($code === 402, 'AI needs Pro');
[$code] = call('POST', '/trial', [], $ses);
check($code === 404, 'no free trial any more');
$wpdb->update($wpdb->prefix . 'ma_users', ['pro_until' => gmdate('Y-m-d H:i:s', time() + 30 * DAY_IN_SECONDS), 'pro_kind' => 'manual'], ['id' => $u['id']]);
[$code, $d] = call('POST', '/ai', ['model' => 'claude-haiku-5-5', 'max_tokens' => 99999, 'messages' => [['role' => 'user', 'content' => 'হ্যালো']], 'metadata' => ['x' => 1]], $ses);
check($code === 200 && ($d['content'][0]['text'] ?? '') === 'ঠিক আছে', 'AI answers through the server');
$fwd = json_decode($sent['ai'][0]['body'], true);
check($fwd['max_tokens'] === 4000 && !isset($fwd['metadata']) && $sent['ai'][0]['headers']['x-api-key'] === 'sk-ant-test-0123456789abcdefghijkl', 'only allowed fields go on, with our key, max_tokens capped');
[$code] = call('POST', '/ai', ['model' => 'gpt-4', 'messages' => []], $ses);
check($code === 400, 'other models refused');
check((int) $wpdb->get_var("SELECT requests FROM {$wpdb->prefix}ma_ai_usage") === 1, 'usage counted (no text kept)');
[$code, $d] = call('GET', '/me', [], $ses);
check($code === 200 && $d['ai_left'] === 29, '/me: 29 left');

echo "\nAI cost by model, budgets and answer sources\n";
$usage = $wpdb->get_row("SELECT * FROM {$wpdb->prefix}ma_ai_usage WHERE model = 'claude-haiku-5-5'", ARRAY_A);
// The pretended answer used 1200 input and 80 output tokens: 1200 × $0.10 + 80 × $0.50 per million = 160 millionths of a dollar.
check($usage && (int) $usage['input'] === 1200 && (int) $usage['output'] === 80 && (int) $usage['cost_micro_usd'] === 160 && $usage['plan'] === 'pro' && $usage['provider'] === 'anthropic', 'Haiku answer: tokens and cost (160 µ$) by model');
[$code] = call('POST', '/ai', ['model' => 'claude-sonnet-5-5', 'max_tokens' => 1000, 'messages' => [['role' => 'user', 'content' => 'হ্যালো']]], $ses);
$son = $wpdb->get_row("SELECT * FROM {$wpdb->prefix}ma_ai_usage WHERE model = 'claude-sonnet-5-5'", ARRAY_A);
check($code === 200 && $son && (int) $son['cost_micro_usd'] === 1200 * 2 + 80 * 10, 'Sonnet in its own row: 3200 µ$ (20× Haiku per token)');
check((int) $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}ma_ai_usage") === 2, 'one row per model');
[$code, $d] = call('GET', '/me', [], $ses);
check($d['ai_left'] === 28, 'the daily limit counts every model');
update_option('ma_ai_budgets', wp_json_encode(['pro' => ['day' => 0.003, 'month' => 0], 'free' => ['day' => 0, 'month' => 0]]));
[$code, $d] = call('POST', '/ai', ['model' => 'claude-haiku-5-5', 'max_tokens' => 1000, 'messages' => [['role' => 'user', 'content' => 'হ্যালো']]], $ses);
check($code === 503 && ($d['code'] ?? '') === 'budget', 'Pro day budget ($0.003) used up ($0.00336): 503, the app goes on with its rules');
update_option('ma_ai_budgets', '');
[$code, $d] = call('POST', '/ai/sources', ['day' => gmdate('Y-m-d'), 'counts' => ['rules' => 7, 'haiku' => 2, 'sonnet' => 1, 'failed' => 1, 'words' => 3, 'local' => -4]], $ses);
check($code === 200 && $d['kept'] === 4, 'answer sources: counts only, unknown and negative left out');
[$code] = call('POST', '/ai/sources', ['day' => '2020-01-01', 'counts' => ['rules' => 1]], $ses);
check($code === 400, 'an old day is refused');
[$code] = call('POST', '/ai/sources', ['day' => gmdate('Y-m-d'), 'counts' => ['rules' => 1]]);
check($code === 401, 'sources need a session');
[$code] = call('GET', '/me', [], str_repeat('a', 64));
check($code === 401, 'unknown session refused');
[$code] = call('POST', '/device', ['token' => 'member-fcm-token-1234567890'], $ses);
check($code === 200, 'device token saved');

echo "\nnotices\n";
$wpdb->insert($wpdb->prefix . 'ma_notices', ['title' => 'আজকের কাজের লিস্ট করেছেন?', 'body' => 'চাপুন আর বলুন', 'kind' => 'daily', 'at_time' => '21:00', 'audience' => 'all', 'cond' => 'no_tasks', 'mic' => 1, 'active' => 1, 'created_at' => current_time('mysql', true)]);
$wpdb->insert($wpdb->prefix . 'ma_notices', ['title' => 'শুধু ফ্রি', 'kind' => 'daily', 'at_time' => '10:00', 'audience' => 'free', 'active' => 1, 'created_at' => current_time('mysql', true)]);
[$code, $d] = call('GET', '/notices');
check($code === 200 && count($d['notices']) === 1, 'without a session: only "everyone"');
[$code, $d] = call('GET', '/notices', [], $ses);
check(count($d['notices']) === 1 && $d['notices'][0]['cond'] === 'no_tasks' && $d['notices'][0]['mic'] === true, 'Pro member: everyone (not free)');

echo "\npayments\n";
$_POST = ['ma_pay_nonce' => wp_create_nonce('ma_pay_submit'), 'plan' => 'yearly', 'method' => array_key_first(ma_pay_methods()), 'email' => 'Karim@Gmail.com', 'trx' => 'bjk4-q9x2pl', 'sender' => '01712345678', 'name' => 'করিম', 'back' => home_url('/pro/')];
add_filter('wp_redirect', function ($loc) { throw new Exception($loc); });
// The admin app is signed in (email + password), so the new payment is pushed to it.
$bossId = wp_insert_user(['user_login' => 'boss@gmail.com', 'user_email' => 'boss@gmail.com', 'user_pass' => 'long-password-123', 'display_name' => 'Boss', 'role' => 'ma_admin']);
check(!is_wp_error($bossId) && user_can($bossId, 'ma_manage') && !user_can($bossId, 'manage_options'), 'admin role: may manage, not change settings');
$plain = wp_insert_user(['user_login' => 'writer@gmail.com', 'user_email' => 'writer@gmail.com', 'user_pass' => 'long-password-123', 'role' => 'subscriber']);
[$code] = call('POST', '/admin/login', ['email' => 'writer@gmail.com', 'password' => 'long-password-123']);
check($code === 401, 'a site user without the admin role cannot');
[$code] = call('POST', '/admin/login', ['email' => 'boss@gmail.com', 'password' => 'wrong']);
check($code === 401, 'wrong password refused');
// Two-step sign-in (owner's review, 27 Oct): no code set up → refused; then the authenticator's code.
[$code, $d] = call('POST', '/admin/login', ['email' => 'BOSS@gmail.com', 'password' => 'long-password-123']);
check($code === 403 && ($d['code'] ?? '') === 'otp_setup', 'admin app: two-step sign-in must be set up first');
$totp = ma_b32_encode(random_bytes(20));
update_user_meta($bossId, 'ma_totp', ma_sec_seal($totp));
check(str_starts_with((string) get_user_meta($bossId, 'ma_totp', true), 'enc1:') && ma_totp_secret($bossId) === $totp, 'two-step: the secret is kept sealed');
[$code, $d] = call('POST', '/admin/login', ['email' => 'BOSS@gmail.com', 'password' => 'long-password-123']);
check($code === 401 && ($d['code'] ?? '') === 'otp_required', 'two-step: the password alone asks for the code');
[$code, $d] = call('POST', '/admin/login', ['email' => 'BOSS@gmail.com', 'password' => 'long-password-123', 'code' => '000000']);
check($code === 401 && ($d['code'] ?? '') === 'otp_wrong', 'two-step: a wrong code refused');
$mails0 = count($sent['mail']);
$otp = ma_totp_code($totp, intdiv(time(), 30));
[$code, $d] = call('POST', '/admin/login', ['email' => 'BOSS@gmail.com', 'password' => 'long-password-123', 'code' => $otp]);
check($code === 200 && strlen($d['session'] ?? '') === 64 && $d['name'] === 'Boss', 'admin app login with email + password + code');
check(count($sent['mail']) === $mails0 + 1 && str_contains($sent['mail'][$mails0]['subject'] ?? '', 'নতুন লগইন'), 'two-step: the admin is e-mailed about the sign-in');
[$code] = call('POST', '/admin/login', ['email' => 'BOSS@gmail.com', 'password' => 'long-password-123', 'code' => $otp]);
check($code === 401, 'two-step: the same code cannot be used twice');
$sesRow = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_ai_sessions_table() . ' WHERE token_hash = %s', hash('sha256', $d['session'])), ARRAY_A);
check($sesRow && abs(ma_acc_ts($sesRow['expires_at']) - time() - 7 * DAY_IN_SECONDS) < 120, 'admin sessions last 7 days');
check(ma_totp_code('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', 1) === '287082', 'TOTP matches RFC 6238 (SHA-1, 59 s)');
$boss = $d['session'];
[$code] = call('GET', '/me', [], $boss);
check($code === 401, 'an admin session is not a member session');
[$code, $d] = call('GET', '/admin/me', [], $boss);
check($code === 200 && $d['email'] === 'boss@gmail.com', '/admin/me');
call('POST', '/device', ['token' => 'boss-fcm-token-1234567890'], $boss);
try { ma_pay_submit(); } catch (Exception $e) { check(str_contains($e->getMessage(), 'ma_pay=ok'), 'payment submitted: ' . basename(parse_url($e->getMessage(), PHP_URL_QUERY))); }
$p = $wpdb->get_row("SELECT * FROM {$wpdb->prefix}ma_payments", ARRAY_A);
check($p && $p['trx'] === 'BJK4-Q9X2PL' && $p['email'] === 'karim@gmail.com' && (int) $p['amount'] === 999, 'kept: email lower-case, TrxID upper-case, price from settings');
check(count($sent['fcm']) === 1 && $sent['fcm'][0]['message']['token'] === 'boss-fcm-token-1234567890', 'admin phone pushed: ' . ($sent['fcm'][0]['message']['notification']['title'] ?? ''));
check(count($sent['mail']) === $mails0 + 2 && str_contains(end($sent['mail'])['subject'] ?? '', 'নতুন পেমেন্ট'), 'admin emailed');
try { ma_pay_submit(); } catch (Exception $e) { check(str_contains($e->getMessage(), 'ma_pay=dup'), 'same TrxID twice refused'); }
[$code] = call('GET', '/admin/summary', [], $ses);
check($code === 403, 'member session cannot use admin API');
[$code, $d] = call('GET', '/admin/summary', [], $boss);
check($code === 200 && $d['pending_payments'] === 1 && $d['members'] === 1, 'admin summary');
check(abs($d['ai_cost_today_usd'] - 0.00336) < 0.000001, 'admin summary: today\'s AI cost $' . $d['ai_cost_today_usd']);
[$code, $d] = call('GET', '/admin/ai/overview', [], $boss);
$models = array_column($d['today'] ?? [], null, 'model');
check($code === 200 && ($models['claude-haiku-5-5']['requests'] ?? 0) === 1 && abs(($models['claude-sonnet-5-5']['cost_usd'] ?? 0) - 0.0032) < 1e-9 && ($d['sources_today']['rules'] ?? 0) === 7, 'admin AI overview: cost by model and answer sources');
[$code] = call('GET', '/admin/ai/overview', [], $ses);
check($code === 403, 'a member cannot see the AI overview');
[$code, $d] = call('GET', '/admin/payments', ['status' => 'pending'], $boss);
check(count($d['payments']) === 1 && $d['payments'][0]['method'] === 'বিকাশ', 'admin sees the pending payment');
[$code, $d] = call('POST', '/admin/payments/' . $p['id'], ['decision' => 'approve'], $boss);
check($code === 200 && $d['ok'], 'approved from the app: ' . $d['message']);
$k = $wpdb->get_row("SELECT * FROM {$wpdb->prefix}ma_users WHERE email = 'karim@gmail.com'", ARRAY_A);
check($k && str_starts_with($k['google_sub'], 'pending:') && ma_acc_status($k) === 'waiting', 'payer waits for first sign-in');
[$code] = call('POST', '/admin/payments/' . $p['id'], ['decision' => 'approve'], $boss);
check($code === 409, 'approving twice refused');
check($wpdb->get_var("SELECT reviewed_email FROM {$wpdb->prefix}ma_payments") === 'boss@gmail.com', 'who approved is kept');

echo "\nadmin gives Pro to a member\n";
$sent['fcm'] = [];
[$code, $d] = call('POST', '/admin/members/' . $u['id'], ['days' => 365], $boss);
check($code === 200 && $d['member']['status'] === 'pro', 'member is Pro');
check(count($sent['fcm']) === 1 && $sent['fcm'][0]['message']['token'] === 'member-fcm-token-1234567890', 'member phone pushed: ' . ($sent['fcm'][0]['message']['notification']['title'] ?? ''));
[$code, $d] = call('POST', '/admin/push', ['title' => 'নতুন সুবিধা', 'body' => 'দেখুন', 'audience' => 'pro'], $boss);
check($code === 200 && $d['sent'] === 1, 'push now to Pro members');
[$code, $d] = call('GET', '/admin/members', ['q' => 'রহিম'], $boss);
check(count($d['members']) === 1, 'search in Bangla');

echo "\nbackup key\n";
[$code, $d] = call('POST', '/login', ['id_token' => 'RAHIM' . $long]);
$key1 = $d['backup_key'] ?? '';
check(strlen($key1) >= 40, 'login gives the account a backup key');
[$code, $d] = call('POST', '/login', ['id_token' => 'RAHIM' . $long]);
check(($d['backup_key'] ?? '') === $key1, 'the same key on every sign-in (a new phone opens the old backup)');
[$code, $d] = call('POST', '/login', ['id_token' => 'BOSS' . $long]);
check(($d['backup_key'] ?? '') !== $key1 && strlen($d['backup_key'] ?? '') >= 40, 'another account has its own key');
[$code, $d] = call('GET', '/admin/members', ['q' => 'রহিম'], $boss);
check(!str_contains(wp_json_encode($d), $key1), 'admins never see the key');

echo "\nfeedback\n";
$sent['fcm'] = [];
$png = base64_encode(base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='));
[$code] = call('POST', '/feedback', ['kind' => 'idea', 'text' => 'ক্যালেন্ডারে চাঁদের ছবি চাই', 'app_version' => '2.15.0']);
check($code === 401, 'feedback needs a member session');
[$code] = call('POST', '/feedback', ['kind' => 'idea', 'text' => 'ক্যালেন্ডারে চাঁদের ছবি চাই'], $boss);
check($code === 401, 'an admin session cannot post feedback');
[$code] = call('POST', '/feedback', ['kind' => 'idea', 'text' => 'হুম'], $ses);
check($code === 400, 'too short refused');
[$code] = call('POST', '/feedback', ['kind' => 'problem', 'text' => 'ফাইল', 'file' => ['name' => 'x.exe', 'data' => base64_encode("MZ\x90\x00 not a picture")]], $ses);
check($code === 415, 'only photos and PDF');
[$code, $d] = call('POST', '/feedback', ['kind' => 'problem', 'text' => "রিমাইন্ডার <b>বাজেনি</b>\nদুপুরে", 'app_version' => '2.15.0', 'file' => ['name' => 'screen.png', 'data' => $png]], $ses);
check($code === 200 && $d['ok'] && $d['id'] > 0, 'feedback with a screenshot saved');
$fid = $d['id'];
$f = $wpdb->get_row("SELECT * FROM {$wpdb->prefix}ma_feedback WHERE id = $fid", ARRAY_A);
check($f && $f['email'] === 'rahim@gmail.com' && !str_contains($f['body'], '<b>') && $f['status'] === 'new', 'kept with the member, tags stripped');
$msg = $wpdb->get_row("SELECT * FROM {$wpdb->prefix}ma_feedback_msgs WHERE feedback_id = $fid", ARRAY_A);
$dir = wp_upload_dir()['basedir'] . '/ma-private';
check($msg && $msg['file_mime'] === 'image/png' && preg_match('/^[a-f0-9]{64}$/', $msg['file_key']) && is_file("$dir/{$msg['file_key']}"), 'the file kept under a random name');
check(str_contains((string) @file_get_contents("$dir/.htaccess"), 'Require all denied'), 'the folder is closed to the web');
check(count($sent['fcm']) === 1 && $sent['fcm'][0]['message']['token'] === 'boss-fcm-token-1234567890', 'admins pushed: ' . ($sent['fcm'][0]['message']['notification']['title'] ?? ''));
[$code, $d] = call('GET', '/admin/feedback', [], $boss);
check($code === 200 && count($d['feedback']) === 1 && $d['new'] === 1 && $d['feedback'][0]['kind_label'] === 'সমস্যা', 'admin app lists it');
[$code, $d] = call('GET', "/admin/feedback/$fid", [], $boss);
check($code === 200 && count($d['messages']) === 1 && $d['messages'][0]['file']['name'] === 'screen.png' && $d['feedback']['status'] === 'read', 'admin opens the conversation (now read)');
[$code, $d] = call('GET', '/admin/feedback/file/' . $msg['id'], [], $boss);
check($code === 200 && $d['data'] === $png, 'admin gets the screenshot');
$sent['fcm'] = [];
[$code, $d] = call('POST', "/admin/feedback/$fid/reply", ['text' => 'ধন্যবাদ! ফোনের ব্যাটারি সেটিং দেখুন', 'file' => ['name' => 'how.png', 'data' => $png]], $boss);
check($code === 200 && $d['ok'], 'admin replies with a picture');
check(count($sent['fcm']) === 1 && $sent['fcm'][0]['message']['token'] === 'member-fcm-token-1234567890', 'member pushed: ' . ($sent['fcm'][0]['message']['notification']['title'] ?? ''));
[$code, $d] = call('GET', '/me', [], $ses);
check(($d['feedback_unread'] ?? 0) === 1, '/me: one unread answer');
[$code, $d] = call('GET', '/feedback', [], $ses);
check($code === 200 && count($d['feedback']) === 1 && $d['feedback'][0]['unread'] && $d['feedback'][0]['last']['from'] === 'admin', 'member sees the answer waiting');
[$code, $d] = call('GET', "/feedback/$fid", [], $ses);
check($code === 200 && count($d['messages']) === 2 && $d['messages'][1]['admin'] === 'Boss' && !$d['feedback']['unread'], 'member reads the conversation');
$amsg = $d['messages'][1]['id'];
[$code, $d] = call('GET', "/feedback/file/$amsg", [], $ses);
check($code === 200 && $d['mime'] === 'image/png', 'member gets the admin\'s picture');
$sent['fcm'] = [];
[$code, $d] = call('POST', "/feedback/$fid/reply", ['text' => 'ঠিক হয়েছে, ধন্যবাদ'], $ses);
check($code === 200, 'member answers back');
check($wpdb->get_var("SELECT status FROM {$wpdb->prefix}ma_feedback WHERE id = $fid") === 'new' && count($sent['fcm']) === 1, 'back on the admins\' list, admins pushed');
// Someone else cannot read or answer it.
[$code, $other] = call('POST', '/login', ['id_token' => 'BOSS' . $long]);
$otherSes = $other['session'];
[$code] = call('GET', "/feedback/$fid", [], $otherSes);
check($code === 404, 'another member cannot open it');
[$code] = call('GET', '/feedback/file/' . $msg['id'], [], $otherSes);
check($code === 404, 'nor its files');
[$code] = call('POST', "/feedback/$fid/reply", ['text' => 'আমিও'], $otherSes);
check($code === 404, 'nor answer it');
[$code] = call('POST', "/admin/feedback/$fid", ['status' => 'done'], $boss);
[$c2, $d] = call('GET', '/admin/feedback', [], $boss);
check($code === 200 && count($d['feedback']) === 0 && $d['new'] === 0, 'marked done: off the open list');
[$code] = call('GET', '/admin/feedback', [], $ses);
check($code === 403, 'members cannot read the admin list');
for ($i = 0; $i < 18; $i++) call('POST', '/feedback', ['kind' => 'idea', 'text' => 'আরও একটা কথা ' . $i], $ses);
[$code] = call('POST', '/feedback', ['kind' => 'idea', 'text' => 'একুশ নম্বর কথা'], $ses);
check($code === 429, 'at most 20 messages a day from one member');
$_GET = ['page' => 'my-assistant', 'tab' => 'feedback', 'fb' => $fid];
wp_set_current_user(1);
ob_start();
ma_acc_admin();
$thread = ob_get_clean();
file_put_contents(dirname(__FILE__) . '/page-thread.html', '<!doctype html><meta charset="utf-8"><body style="margin:0;background:#f0f0f1;padding:0 0 0 20px">' . $thread);
check(str_contains($thread, 'ঠিক হয়েছে, ধন্যবাদ') && str_contains($thread, 'উত্তর পাঠান') && str_contains($thread, 'ma_fb_file'), 'site page shows the conversation, files and a reply box');
wp_set_current_user(0);
ma_fb_set($fid, 'delete');
check(!is_file("$dir/{$msg['file_key']}") && !$wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}ma_feedback_msgs WHERE feedback_id = $fid"), 'deleting removes messages and files');

echo "\nblood requests\n";
$sent['fcm'] = [];
[$code, $d] = call('POST', '/blood/donor', ['on' => true, 'blood' => 'O−', 'district' => 'ঢাকা', 'phone' => '+880 1812-345678'], $otherSes);
check($code === 200 && $d['donor']['blood'] === 'O-' && $d['donor']['phone'] === '01812345678', 'a donor opts in (group and number normalised)');
call('POST', '/device', ['token' => 'boss-member-fcm-token-123456'], $otherSes);
[$code] = call('POST', '/blood/requests', ['blood' => 'B+', 'district' => 'ঢাকা', 'phone' => '123', 'need_by' => gmdate('c', time() + DAY_IN_SECONDS)], $ses);
check($code === 400, 'a request needs a real mobile number');
[$code, $d] = call('POST', '/blood/requests', ['blood' => 'B+', 'bags' => 2, 'district' => 'ঢাকা', 'hospital' => 'ঢাকা মেডিকেল', 'patient' => 'আব্বা', 'phone' => '01712345678', 'need_by' => gmdate('c', time() + DAY_IN_SECONDS), 'note' => 'অপারেশন'], $ses);
check($code === 200 && $d['notified'] === 1, 'request made; the O− donor in Dhaka pushed');
$rid = $d['id'];
check(($sent['fcm'][0]['message']['token'] ?? '') === 'boss-member-fcm-token-123456', 'push: ' . ($sent['fcm'][0]['message']['notification']['title'] ?? ''));
[$code, $d] = call('GET', '/blood/requests', [], $otherSes);
check($code === 200 && count($d['requests']) === 1 && $d['requests'][0]['hospital'] === 'ঢাকা মেডিকেল' && !isset($d['requests'][0]['donors']), 'donor sees it (near, can give)');
[$code, $d] = call('POST', '/blood/donor', ['on' => true, 'blood' => 'A+', 'district' => 'ঢাকা'], $otherSes);
[$code, $d] = call('GET', '/blood/requests', [], $otherSes);
check(count($d['requests']) === 0, 'an A+ donor is not shown a B+ request');
[$code, $d] = call('GET', '/blood/requests', ['scope' => 'district'], $otherSes);
check(count($d['requests']) === 1, 'but can see all of the district');
call('POST', '/blood/donor', ['on' => true, 'blood' => 'O-', 'district' => 'ঢাকা', 'phone' => '01812345678'], $otherSes);
$sent['fcm'] = [];
[$code] = call('POST', "/blood/requests/$rid/accept", [], $ses);
check($code === 400, 'cannot accept one\'s own request');
[$code, $d] = call('POST', "/blood/requests/$rid/accept", ['note' => 'বিকেলে আসব'], $otherSes);
check($code === 200 && $d['request']['i_accepted'] && $d['request']['phone'] === '01712345678', 'donor accepts and sees the asker\'s number');
check(($sent['fcm'][0]['message']['token'] ?? '') === 'member-fcm-token-1234567890', 'asker pushed: ' . ($sent['fcm'][0]['message']['notification']['title'] ?? ''));
[$code, $d] = call('GET', '/blood/requests', ['scope' => 'mine'], $ses);
check($code === 200 && $d['requests'][0]['donors'][0]['phone'] === '01812345678' && $d['requests'][0]['donors'][0]['note'] === 'বিকেলে আসব', 'asker sees the donor\'s number');
[$code] = call('POST', "/blood/requests/$rid/close", ['status' => 'done'], $otherSes);
check($code === 403, 'only the asker closes it');
[$code, $d] = call('POST', "/blood/requests/$rid/close", ['status' => 'done'], $ses);
check($code === 200 && $d['request']['status'] === 'done', 'asker: রক্ত পেয়েছি');
[$code, $d] = call('GET', '/blood/requests', [], $otherSes);
check(count($d['requests']) === 0, 'closed requests leave the list');
$recent = gmdate('Y-m-d', time() - 30 * DAY_IN_SECONDS);
call('POST', '/blood/donor', ['on' => true, 'blood' => 'O-', 'district' => 'ঢাকা', 'last_donated' => $recent], $otherSes);
$sent['fcm'] = [];
[$code, $d] = call('POST', '/blood/requests', ['blood' => 'O-', 'district' => 'ঢাকা', 'phone' => '01712345678', 'need_by' => gmdate('c', time() + DAY_IN_SECONDS)], $ses);
check($code === 200 && $d['notified'] === 0, 'no push to a donor who gave 30 days ago');
for ($i = 0; $i < 3; $i++) call('POST', '/blood/requests', ['blood' => 'A+', 'district' => 'ঢাকা', 'phone' => '01712345678', 'need_by' => gmdate('c', time() + DAY_IN_SECONDS)], $ses);
[$code] = call('POST', '/blood/requests', ['blood' => 'A+', 'district' => 'ঢাকা', 'phone' => '01712345678', 'need_by' => gmdate('c', time() + DAY_IN_SECONDS)], $ses);
check($code === 429, 'at most 3 open requests at a time');
[$code, $d] = call('POST', '/blood/donor', ['on' => false], $otherSes);
check($code === 200 && !$wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}ma_donors"), 'opting out removes the donor\'s details');

echo "\nlockout\n";
$_SERVER['REMOTE_ADDR'] = '10.9.9.9';
for ($i = 0; $i < 5; $i++) call('POST', '/admin/login', ['email' => 'boss@gmail.com', 'password' => 'nope' . $i]);
[$code] = call('POST', '/admin/login', ['email' => 'boss@gmail.com', 'password' => 'long-password-123']);
check($code === 429, 'five wrong tries: even the right password waits');
[$code] = call('POST', '/admin/logout', [], $boss);
[$code2] = call('GET', '/admin/summary', [], $boss);
check($code === 200 && $code2 === 403, 'logout ends the session');
$u2 = get_user_by('id', $bossId); $u2->remove_role('ma_admin');
check(!user_can($bossId, 'ma_manage'), 'removed admin loses access');

echo "\nadmin pages\n";
wp_set_current_user(1);
foreach (['members', 'payments', 'notices', 'feedback', 'ai', 'nlu', 'settings'] as $tab) {
    $_GET = ['page' => 'my-assistant', 'tab' => $tab];
    ob_start();
    ma_acc_admin();
    $html = ob_get_clean();
    file_put_contents(dirname(__FILE__) . "/page-$tab.html", '<!doctype html><meta charset="utf-8"><body style="margin:0;background:#f0f0f1;padding:0 0 0 20px">' . $html);
    check(strlen($html) > 3000 && !preg_match('/(Warning|Notice|Fatal|Deprecated)\b.*on line/', $html), "$tab page renders cleanly (" . strlen($html) . ' bytes)');
    if ($tab === 'nlu') {
        check(str_contains($html, 'ma_nlu_settings') && str_contains($html, 'মডেলের সংস্করণ') && str_contains($html, 'পর্যালোচনা') && str_contains($html, 'ma_nlu_draft'), 'AI মডেল page: mode, versions, review, draft — as in the app');
    }
    if ($tab === 'ai') {
        check(str_contains($html, 'AI-এর খরচ') && str_contains($html, 'উত্তর কোথা থেকে এল') && !str_contains($html, 'name="ai_key"'), 'AI cost tab: the report, no settings form');
    }
    if ($tab === 'settings') {
        check(!str_contains($html, 'AI-এর খরচ') && !str_contains($html, 'আজ AI প্রশ্ন') && str_contains($html, 'AI-এর দাম আর বাজেট'), 'settings: only things to set (the cost report is in its own tab)');
    }
}
ob_start();
echo do_shortcode('[my_assistant_payment]');
$form = ob_get_clean();
check(str_contains($form, 'তথ্য জমা দিন') && str_contains($form, 'বিকাশ') && !str_contains($form, 'নগদ |'), 'website form shortcode: bKash only');
$_GET = ['plan' => 'monthly'];
$pro = do_shortcode('[my_assistant_pro]');
file_put_contents(dirname(__FILE__) . '/page-pro.html', '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><body style="margin:0;padding:24px 16px;background:#F6F7F9">' . $pro);
check(str_contains($pro, 'ফ্রি আর প্রিমিয়ামে কী কী') && str_contains($pro, 'মাসিক প্রিমিয়াম কিনুন') && str_contains($pro, 'তথ্য জমা দিন'), 'Pro page: features, plans and the form');
check((bool) preg_match('/value="monthly"\s+checked/', $pro), 'the plan chosen above is ticked in the form');
check(!str_contains(do_shortcode('[my_assistant_pro form="no"]'), 'তথ্য জমা দিন'), 'form="no" leaves the form out');

echo "\nunderstanding (NLU): switch, models, cloud reading, samples\n";
foreach (['ma_nlu_samples', 'ma_nlu_labels', 'ma_nlu_models'] as $t) {
    check($wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}$t") !== null, "table $t");
}
// A fresh member (free) and a Pro member.
[$code, $d] = call('POST', '/login', ['id_token' => 'NLUFREE' . $long]);
$free = $d['session'];
$freeId = (int) $wpdb->get_var($wpdb->prepare("SELECT user_id FROM {$wpdb->prefix}ma_sessions WHERE token_hash = %s", hash('sha256', $free)));
$wpdb->update($wpdb->prefix . 'ma_users', ['pro_until' => null, 'pro_kind' => ''], ['id' => $freeId]);
$proId = (int) $u['id'];
$wpdb->update($wpdb->prefix . 'ma_users', ['pro_until' => gmdate('Y-m-d H:i:s', time() + 30 * DAY_IN_SECONDS)], ['id' => $proId]);
update_option('ma_gemini_key', 'gem-test-key');
update_option('ma_ai_on', '1');
[$code, $d] = call('GET', '/nlu/config', [], $ses);
check($code === 200 && $d['mode'] === 'shadow' && $d['cloud'] === true && $d['model'] === null && $d['consent_ver'] === '1', 'config: shadow by default, cloud on, no model yet');
[$code] = call('GET', '/nlu/config');
check($code === 401, 'config needs a session');
[$code] = call('GET', '/nlu/model', [], $ses);
check($code === 204, 'no live model: keep the built-in one');

echo "  — cloud reading\n";
$GLOBALS['nlu_reply'] = ['pieces' => [['intent' => 'task_add', 'slots' => [['name' => 'date', 'words' => 'কাল'], ['name' => 'title', 'words' => 'ব্যাংকে যেতে হবে'], ['name' => 'amount', 'words' => '৫০০০']]], ['intent' => 'made_up', 'slots' => []]], 'sure' => 0.9];
$sent['nlu'] = [];
[$code, $d] = call('POST', '/nlu/resolve', ['text' => 'কাল ব্যাংকে যেতে হবে', 'state' => 'idle', 'kind' => 'none', 'local_conf' => 0.6, 'top' => [['intent' => 'task_add', 'conf' => 0.6]]], $free);
check($code === 200 && count($sent['nlu']) === 1 && str_contains($sent['nlu'][0]['url'], 'gemini-3.1-flash-lite') && $sent['nlu'][0]['headers']['x-goog-api-key'] === 'gem-test-key', 'free member → Gemini Flash-Lite, with our key');
check(count($d['pieces']) === 1 && $d['pieces'][0]['intent'] === 'task_add', 'an intent not in the spec is dropped');
check(array_column($d['pieces'][0]['slots'], 'words') === ['কাল', 'ব্যাংকে যেতে হবে'], 'a fact not in the message (৫০০০) is dropped — the model cannot invent a number');
$gb = $sent['nlu'][0]['body'];
check(($gb['toolConfig']['functionCallingConfig']['mode'] ?? '') === 'ANY' && ($gb['tools'][0]['functionDeclarations'][0]['name'] ?? '') === 'route' && !str_contains(wp_json_encode($gb), 'free@x.com'), 'Gemini: route as a forced function call, no member details sent');
$cost = (int) $wpdb->get_var($wpdb->prepare("SELECT cost_micro_usd FROM {$wpdb->prefix}ma_ai_usage WHERE user_id = %d AND model = %s", $freeId, 'gemini-3.1-flash-lite'));
check($cost === (int) round(500 * 0.25 + 1000 * 0.025 + 40 * 1.5), 'its cost is counted (free plan): ' . $cost);
$sent['nlu'] = [];
[$code, $d] = call('POST', '/nlu/resolve', ['text' => 'কাল ব্যাংকে যেতে হবে', 'local_conf' => 0.9], $ses);
$ab = $sent['nlu'][0]['body'] ?? [];
check($code === 200 && str_contains($sent['nlu'][0]['url'], 'anthropic') && $ab['model'] === 'claude-haiku-5-5' && ($ab['system'][0]['cache_control']['type'] ?? '') === 'ephemeral' && ($ab['tool_choice']['name'] ?? '') === 'route', 'Pro member → Haiku, fixed part cached, route forced');
// Very unsure on the phone → Sonnet, but only within its share of the day.
delete_transient('ma_nlu_day_' . gmdate('Y-m-d'));
for ($i = 0; $i < 19; $i++) ma_nlu_count_use(999, 'claude-haiku-5-5');
$sent['nlu'] = [];
[$code, $d] = call('POST', '/nlu/resolve', ['text' => 'ওটা কাল', 'local_conf' => 0.1], $ses);
check($code === 200 && $d['model'] === 'claude-sonnet-5-5', 'a Pro message the phone was very unsure of → Sonnet');
$sent['nlu'] = [];
[$code, $d] = call('POST', '/nlu/resolve', ['text' => 'ওটা পরশু', 'local_conf' => 0.1], $ses);
check($code === 200 && $d['model'] === 'claude-haiku-5-5', 'Sonnet stays within 5% of the day: the next goes to Haiku');
// Failures: 429 once → tried again; a broken provider → the other.
$GLOBALS['gem_fail'] = [429];
$sent['nlu'] = [];
[$code, $d] = call('POST', '/nlu/resolve', ['text' => 'কাল ব্যাংকে যাব'], $free);
check($code === 200 && count($sent['nlu']) === 2 && $d['model'] === 'gemini-3.1-flash-lite', '429 → tried once more');
$GLOBALS['gem_fail'] = [500];
$sent['nlu'] = [];
[$code, $d] = call('POST', '/nlu/resolve', ['text' => 'কাল ব্যাংকে যাব'], $free);
check($code === 200 && $d['model'] === 'claude-haiku-5-5', 'Gemini fails → Haiku answers');
$GLOBALS['gem_fail'] = [500];
$GLOBALS['ant_fail'] = [500];
[$code] = call('POST', '/nlu/resolve', ['text' => 'কাল ব্যাংকে যাব'], $free);
check($code === 504, 'both fail → 504 (the app stays on the phone path)');
[$code] = call('POST', '/nlu/resolve', ['text' => '<নাম১> এর নম্বর ০১৭১১২২৩৩৪৪'], $free);
check($code === 422, 'a phone number in the text is refused');
[$code] = call('POST', '/nlu/resolve', ['text' => 'ওয়াইফাইয়ের পাসওয়ার্ড কত'], $free);
check($code === 422, 'a secret is refused');
update_option('ma_ai_budgets', wp_json_encode(['free' => ['day' => 0.0001, 'month' => 0], 'pro' => ['day' => 0, 'month' => 0]]));
[$code] = call('POST', '/nlu/resolve', ['text' => 'কাল ব্যাংকে যাব'], $free);
check($code === 503, 'free budget used up → 503');
update_option('ma_ai_budgets', '');
$s = ma_nlu_settings(); $s['free_per_user'] = 1; update_option('ma_nlu_settings', wp_json_encode($s));
[$code] = call('POST', '/nlu/resolve', ['text' => 'কাল ব্যাংকে যাব'], $free);
check($code === 429, 'the member\'s daily limit');
update_option('ma_ai_on', '0');
[$code] = call('POST', '/nlu/resolve', ['text' => 'কাল ব্যাংকে যাব'], $ses);
check($code === 503, 'the one switch stops every cloud call');
update_option('ma_ai_on', '1');
update_option('ma_nlu_settings', '');

echo "  — no loss: budgets follow income\n";
update_option('ma_ai_budgets', '');
update_option('ma_pay_monthly', 99); update_option('ma_pay_yearly', 999); update_option('ma_usd_bdt', 122);
$ab = ma_ai_budgets();
$npro = ma_ai_active_pro();
check(!empty($ab['auto']) && abs($ab['pro']['month'] - max(0.01, round($npro * (999 / 12 / 122) * 0.20, 4))) < 1e-6 && $ab['free']['month'] == 3.0, "automatic budgets: Pro = 20% of $npro Pro member(s)' income, free \$3 a month");
check(abs(ma_ai_member_cap() - round(999 / 12 / 122 * 0.30, 4)) < 1e-6, 'one Pro member may cost at most 30% of what they pay: $' . ma_ai_member_cap());
$capMicro = (int) (ma_ai_member_cap() * 1e6);
$wpdb->query($wpdb->prepare("INSERT INTO {$wpdb->prefix}ma_ai_usage (user_id, day, model, provider, plan, requests, cost_micro_usd) VALUES (%d, %s, 'test-cap', 'anthropic', 'pro', 1, %d)", $proId, gmdate('Y-m-d'), $capMicro));
[$code] = call('POST', '/nlu/resolve', ['text' => 'কাল ব্যাংকে যাব'], $ses);
check($code === 503, 'Pro AI past its share of Pro income → cloud stops for Pro (503)');
update_option('ma_ai_budgets', wp_json_encode(['free' => ['day' => 0, 'month' => 0], 'pro' => ['day' => 0, 'month' => 0]]));
[$code] = call('POST', '/nlu/resolve', ['text' => 'কাল ব্যাংকে যাব'], $ses);
[$code2] = call('POST', '/ai', ['model' => 'claude-haiku-5-5', 'messages' => [['role' => 'user', 'content' => 'হ্যালো']]], $ses);
check($code === 429 && $code2 === 429, 'a member at their monthly cap: cloud stops for them (the phone goes on)');
$wpdb->query($wpdb->prepare("DELETE FROM {$wpdb->prefix}ma_ai_usage WHERE user_id = %d AND model = 'test-cap'", $proId));
update_option('ma_ai_budgets', '');
update_option('ma_gemini_key', 'gem-test-key');

echo "  — samples\n";
$n0 = (int) $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}ma_nlu_samples");
[$code] = call('POST', '/nlu/samples', ['samples' => [['text_delex' => 'কাল ব্যাংকে যাব']]], $ses);
check($code === 403, 'no consent → refused');
$samples = [
    ['text_delex' => '<নাম১>কে ৫০০ টাকা দিলাম', 'state' => 'idle', 'local_json' => ['pieces' => [['intent' => 'cash_add']]], 'local_conf' => 0.7, 'final_json' => ['pieces' => [['intent' => 'ledger_add']]], 'signal' => 'edited'],
    ['text_delex' => 'আমার নম্বর 01711223344', 'state' => 'idle'],
    ['text_delex' => 'ওটিপি 482913 এসেছে'],
    ['text_delex' => 'কাল বাজার করব', 'state' => 'weird', 'signal' => 'nonsense'],
];
[$code, $d] = call('POST', '/nlu/samples', ['consent_ver' => '1', 'samples' => $samples], $ses);
check($code === 200 && $d['kept'] === 2 && $d['refused'] === 2, 'with consent: kept, but a phone number or a code is refused');
$last = $wpdb->get_row("SELECT * FROM {$wpdb->prefix}ma_nlu_samples ORDER BY id DESC LIMIT 1", ARRAY_A);
check($last['state'] === 'idle' && $last['signal_kind'] === '' && strlen($last['user_hash']) === 64 && !str_contains(wp_json_encode($last), (string) $proId . '@'), 'unknown state/signal cleaned; member kept only as a hash');
[$code] = call('POST', '/nlu/samples', ['consent_ver' => '1', 'samples' => array_fill(0, 101, ['text_delex' => 'x'])], $ses);
check($code === 413, 'at most 100 at a time');

echo "  — admin\n";
$bossSes = ma_ai_new_session(1, 'admin');
[$code, $d] = call('GET', '/admin/nlu/review', [], $bossSes);
check($code === 200 && count($d['samples']) >= 1 && $d['samples'][0]['signal'] === 'edited' && $d['samples'][0]['phone'] === ['cash_add'] && $d['samples'][0]['final'] === ['ledger_add'], 'review: disagreements, error signals first');
check(str_contains($d['text'], 'বাক্য: <নাম১>কে ৫০০ টাকা দিলাম') && str_contains($d['text'], 'ফোন: cash_add (70%)') && str_contains($d['text'], 'শেষে: ledger_add') && str_contains($d['text'], 'ভুলের সংকেত: edited') && !str_contains($d['text'], '01711223344'), 'review: all of it as one text to copy (names already removed)');
$_GET = ['page' => 'my-assistant', 'tab' => 'nlu'];
ob_start();
ma_acc_admin();
$html = ob_get_clean();
check(str_contains($html, 'id="ma-review-copy-btn"') && str_contains($html, 'id="ma-review-copy"') && str_contains($html, 'বাক্য: &lt;নাম১&gt;কে ৫০০ টাকা দিলাম'), 'site AI মডেল › পর্যালোচনা: one button copies everything');
file_put_contents(dirname(__FILE__) . '/page-nlu-review.html', '<!doctype html><meta charset="utf-8"><body style="margin:0;background:#f0f0f1;padding:0 0 0 20px">' . $html);
$sid = $d['samples'][0]['id'];
[$code] = call('POST', "/admin/nlu/review/$sid", ['intents' => ['nonsense']], $bossSes);
check($code === 400, 'a label must be a spec intent');
[$code] = call('POST', "/admin/nlu/review/$sid", ['intents' => ['ledger_add'], 'pick' => 'user'], $bossSes);
[$c2, $d2] = call('GET', '/admin/nlu/review', [], $bossSes);
check($code === 200 && !in_array($sid, array_column($d2['samples'], 'id'), true), 'labelled → leaves the review list');
[$code, $d] = call('GET', '/admin/nlu/export', [], $bossSes);
$ex = array_values(array_filter($d['samples'] ?? [], function ($x) use ($sid) { return (int) $x['id'] === $sid; }));
check($code === 200 && $ex && str_contains($ex[0]['admin_label'], 'ledger_add'), 'export with the admin label (site owner)');
[$code, $d] = call('POST', '/admin/ai/settings', ['nlu' => ['mode' => 'on', 'pct' => 0, 'free_model' => 'gemini-3.1-flash-lite'], 'budgets' => ['pro' => ['month' => 25]]], $bossSes);
check($code === 200 && $d['nlu']['mode'] === 'on' && $d['nlu']['pct'] === 0 && $d['budgets']['pro']['month'] == 25, 'settings saved from the admin app');
$GLOBALS['gem_fail'] = []; $GLOBALS['ant_fail'] = [];
[$code, $d] = call('POST', '/admin/ai/selftest', [], $bossSes);
check($code === 200 && $d['gemini']['ok'] && $d['anthropic']['ok'] && $d['gemini']['reading']['pieces'][0]['intent'] === 'task_add', 'self-test: one real call to each (here pretended) shows the keys work');
$GLOBALS['gem_fail'] = [403];
[$code, $d] = call('POST', '/admin/ai/selftest', [], $bossSes);
check($code === 200 && !$d['gemini']['ok'] && str_starts_with($d['gemini']['error'], '403'), 'self-test: a refused key is reported with its code');
[$code, $d] = call('GET', '/nlu/config', [], $ses);
check($d['mode'] === 'off', 'a member outside the share (0%) gets mode off');
call('POST', '/admin/ai/settings', ['nlu' => ['mode' => 'shadow', 'pct' => 100]], $bossSes);
[$code] = call('POST', '/admin/nlu/models', ['version' => 'm2', 'url' => 'http://x/m.tflite', 'sha256' => str_repeat('a', 64)], $bossSes);
check($code === 400, 'a model needs an https address');
[$code] = call('POST', '/admin/nlu/models', ['version' => 'm2', 'url' => 'https://github.com/x/m2.tflite', 'sha256' => str_repeat('a', 64), 'size' => 14068808, 'thresholds' => ['task_add' => 0.8], 'eval' => ['exact' => 0.81]], $bossSes);
[$c2] = call('GET', '/nlu/model', [], $ses);
check($code === 200 && $c2 === 204, 'a draft reaches nobody');
call('POST', '/admin/nlu/models', ['version' => 'm2', 'action' => 'live', 'pct' => 100], $bossSes);
[$code, $d] = call('GET', '/nlu/model', [], $ses);
check($code === 200 && $d['version'] === 'm2' && $d['sha256'] === str_repeat('a', 64) && $d['size'] === 14068808, 'live at 100%: the member gets it, with its SHA-256');
[$code, $d] = call('GET', '/nlu/config', [], $ses);
check(($d['thresholds']['task_add'] ?? 0) == 0.8 && $d['model'] === 'm2', 'config carries the live model\'s thresholds');
call('POST', '/admin/nlu/models', ['version' => 'm2', 'action' => 'rollback'], $bossSes);
[$code] = call('GET', '/nlu/model', [], $ses);
check($code === 204, 'rollback: back to the built-in model');
[$code, $d] = call('GET', '/admin/ai/overview', [], $bossSes);
check($code === 200 && isset($d['nlu']['samples_30d']) && $d['nlu']['error_signals_per_100'] > 0, 'overview carries the NLU numbers');
check(isset($d['nlu']['weakest']) && is_array($d['nlu']['weakest']) && $d['usd_bdt'] == 122, 'overview: weakest intents list and the taka rate');
[$code, $d] = call('POST', '/admin/ai/settings', ['budgets_auto' => true], $bossSes);
check($code === 200 && !empty($d['budgets']['auto']), 'budgets back to automatic from the admin app');

echo "  — the same on the site and in the admin app\n";
[$code, $d] = call('GET', '/admin/ai/settings', [], $bossSes);
check($code === 200 && $d['owner'] === true && isset($d['prices'], $d['ci_key'], $d['ai_per_user'], $d['nlu']['escalate_share']), 'owner: the app gets everything the settings page has');
[$code, $d] = call('POST', '/admin/ai/settings', ['keys' => ['anthropic_key' => 'not-a-key']], $bossSes);
check($code === 400, 'a wrong key is refused in the app as on the site');
[$code, $d] = call('POST', '/admin/ai/settings', ['ai_per_user' => 40, 'prices' => ['claude-haiku-5-5' => ['in' => 1, 'cw' => 1.25, 'cr' => 0.1, 'out' => 5]], 'new_model' => 'gemini-9-test', 'nlu' => ['cloud_on' => false, 'escalate_share' => 0.03]], $bossSes);
check($code === 200 && $d['ai_per_user'] === 40 && isset($d['prices']['gemini-9-test']) && $d['nlu']['cloud_on'] === false && abs($d['nlu']['escalate_share'] - 0.03) < 1e-9, 'limits, prices, cloud switch and Sonnet share from the app');
call('POST', '/admin/ai/settings', ['nlu' => ['cloud_on' => true]], $bossSes);
[$code, $d] = call('POST', '/admin/nlu/ci-key', [], $bossSes);
check($code === 200 && strlen($d['ci_key']) === 48 && ma_nlu_ci_key() === $d['ci_key'], 'retraining key made from the app');
$helperId = wp_insert_user(['user_login' => 'helper', 'user_email' => 'helper@gmail.com', 'user_pass' => 'long-password-456', 'role' => 'ma_admin']);
$helperSes = ma_ai_new_session($helperId, 'admin');
[$code, $d] = call('GET', '/admin/ai/settings', [], $helperSes);
check($code === 200 && $d['owner'] === false && !isset($d['prices']) && !isset($d['ci_key']), 'another admin: no keys, prices or retraining key');
[$code] = call('POST', '/admin/ai/settings', ['ai_on' => false], $helperSes);
[$c2] = call('POST', '/admin/nlu/ci-key', [], $helperSes);
check($code === 403 && $c2 === 403 && get_option('ma_ai_on') === '1', 'another admin cannot stop AI or make keys (owner only, as on the site)');
[$code, $d] = call('POST', '/admin/ai/settings', ['nlu' => ['pct' => 50]], $helperSes);
check($code === 200 && $d['nlu']['pct'] === 50, 'another admin can set the on-phone model (as on the site\'s AI মডেল page)');
call('POST', '/admin/ai/settings', ['nlu' => ['pct' => 100]], $bossSes);
$r = ma_nlu_model_do('m2', 'live', 30);
check(!is_wp_error($r) && $r['status'] === 'live' && $r['rollout_pct'] === 30, 'site form and app share one action: live at 30%');
wp_set_current_user(1);
$_GET = ['page' => 'my-assistant', 'tab' => 'nlu'];
ob_start();
ma_acc_admin();
$html = ob_get_clean();
file_put_contents(dirname(__FILE__) . '/page-nlu2.html', '<!doctype html><meta charset="utf-8"><body style="margin:0;background:#f0f0f1;padding:0 0 0 20px">' . $html);
check(str_contains($html, 'চালু · ৩০%') && str_contains($html, '% রাখুন') && str_contains($html, 'ফিরিয়ে নিন') && !preg_match('/(Warning|Notice|Fatal|Deprecated)\b.*on line/', $html), 'AI মডেল page with a live model: share, change, take back');
ma_nlu_model_do('m2', 'rollback');
check(is_wp_error(ma_nlu_model_do('nope', 'live', 10)), 'an unknown version is refused');
[$code, $d] = call('POST', '/ai/sources', ['day' => gmdate('Y-m-d'), 'counts' => ['nlu_same_sure' => 5, 'nlu_differ' => 2]], $ses);
check($code === 200 && $d['kept'] === 2, 'shadow-mode counts are accepted');
[$code, $d] = call('POST', '/ai/sources', ['day' => gmdate('Y-m-d'), 'counts' => ['nlu_agree' => 9, 'nlu_cloud' => 2, 'nlu_cloud_rules' => 3, 'nlu_cloud_fail' => 1, 'nlu_nonsense' => 4]], $ses);
check($code === 200 && $d['kept'] === 4, 'on-mode counts are accepted (unknown names are not)');

echo "  — retraining job key\n";
function ci_call($method, $route, $key, $body = []) {
    $req = new WP_REST_Request($method, '/my-assistant/v1' . $route);
    $req->set_header('x-ma-ci-key', $key);
    if ($method === 'GET') { foreach ($body as $k => $v) $req->set_param($k, $v); } else { $req->set_header('content-type', 'application/json'); $req->set_body(wp_json_encode($body)); }
    $res = rest_do_request($req);
    return [$res->get_status(), rest_get_server()->response_to_data($res, false)];
}
[$code] = ci_call('GET', '/nlu/ci/export', 'nothing');
check($code === 403, 'no key yet: the job is refused');
update_option('ma_nlu_ci_key', str_repeat('k', 48));
[$code] = ci_call('GET', '/nlu/ci/export', str_repeat('x', 48));
check($code === 403, 'a wrong key is refused');
[$code, $d] = ci_call('GET', '/nlu/ci/export', str_repeat('k', 48));
check($code === 200 && isset($d['samples']) && str_contains(wp_json_encode($d), 'ledger_add'), 'the job reads the labelled samples');
[$code, $d] = ci_call('POST', '/nlu/ci/model', str_repeat('k', 48), ['version' => 'r3', 'url' => 'https://github.com/x/r3.tflite', 'sha256' => str_repeat('b', 64), 'thresholds' => ['intents' => ['task_add']], 'eval' => ['exact' => 0.83]]);
check($code === 200 && $d['model']['status'] === 'draft' && $d['model']['rollout_pct'] === 0, 'the job adds a model only as a draft');
[$code] = ci_call('POST', '/nlu/ci/model', str_repeat('k', 48), ['version' => 'r3', 'url' => 'https://github.com/x/r3.tflite', 'sha256' => str_repeat('b', 64)]);
check($code === 409, 'the same version twice is refused');
[$code] = call('GET', '/nlu/model', [], $ses);
check($code === 204, 'a draft from the job reaches nobody');

echo "  — privacy\n";
[$code, $d] = call('DELETE', '/nlu/samples/mine', [], $ses);
check($code === 200 && $d['deleted'] >= 2 && !$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM {$wpdb->prefix}ma_nlu_samples WHERE user_hash = %s", ma_nlu_user_hash($proId))), 'a member deletes all their samples');
$wpdb->insert($wpdb->prefix . 'ma_nlu_samples', ma_nlu_sample_row($freeId, ['text_delex' => 'পুরনো কথা'], '1'));
$wpdb->query("UPDATE {$wpdb->prefix}ma_nlu_samples SET created = '2025-01-01 00:00:00' WHERE text_delex = 'পুরনো কথা'");
$wpdb->insert($wpdb->prefix . 'ma_nlu_samples', ma_nlu_sample_row($freeId, ['text_delex' => 'নতুন কথা'], '1'));
check(ma_nlu_purge() === 1 && (int) $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}ma_nlu_samples WHERE text_delex = 'নতুন কথা'") === 1, 'after 180 days a sample goes; newer ones stay');
ma_nlu_forget_member($freeId);
check(!$wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM {$wpdb->prefix}ma_nlu_samples WHERE user_hash = %s", ma_nlu_user_hash($freeId))), 'a deleted member\'s samples go with them');
check(wp_next_scheduled('ma_nlu_purge') !== false, 'the daily clean-up is scheduled');

echo "\nusage table migration (1.8.0 → 1.9.0)\n";
$ut = $wpdb->prefix . 'ma_ai_usage';
$wpdb->query("DROP TABLE $ut");
$wpdb->query("CREATE TABLE $ut (user_id bigint(20) unsigned NOT NULL, day date NOT NULL, requests int(10) unsigned NOT NULL DEFAULT 0, tokens_in bigint(20) unsigned NOT NULL DEFAULT 0, tokens_out bigint(20) unsigned NOT NULL DEFAULT 0, PRIMARY KEY (user_id,day))");
$wpdb->insert($ut, ['user_id' => 7, 'day' => '2026-10-01', 'requests' => 12, 'tokens_in' => 50000, 'tokens_out' => 900]);
$wpdb->insert($ut, ['user_id' => 8, 'day' => '2026-10-02', 'requests' => 3, 'tokens_in' => 9000, 'tokens_out' => 100]);
update_option('ma_acc_db_version', '1.8.0');
ma_acc_install();
$cols = $wpdb->get_col("SHOW COLUMNS FROM $ut", 0);
$old = $wpdb->get_results("SELECT * FROM $ut ORDER BY user_id", ARRAY_A);
check(in_array('model', $cols, true) && in_array('cost_micro_usd', $cols, true) && in_array('cache_read', $cols, true), 'new columns added');
check(count($old) === 2 && (int) $old[0]['requests'] === 12 && $old[0]['model'] === 'unknown' && (int) $old[1]['tokens_in'] === 9000, 'old rows kept (model "unknown")');
ma_ai_count(7, 'pro', 'claude-haiku-5-5', 'anthropic', ['input_tokens' => 10]);
ma_ai_count(7, 'pro', 'claude-haiku-5-5', 'anthropic', ['input_tokens' => 10]);
check((int) $wpdb->get_var($wpdb->prepare("SELECT requests FROM $ut WHERE user_id = 7 AND model = %s", 'claude-haiku-5-5')) === 2 && (int) $wpdb->get_var("SELECT COUNT(*) FROM $ut") === 3, 'after migration: the same day, a new model gets its own row');
ma_acc_install();
check((int) $wpdb->get_var("SELECT COUNT(*) FROM $ut") === 3, 'running the install again changes nothing');

echo "\ngold and silver price\n";
$today = wp_date('Y-m-d');
$GLOBALS['metal_reply'] = 'এই যে: {"effective_date":"' . $today . '","gold":{"22k":"1,000,000","21k":1,"18k":1,"traditional":1},"silver":{"22k":3500,"21k":3300,"18k":2800,"traditional":2100},"source_url":"https://www.bajus.org/gold-price"}';
[$code] = call('GET', '/metal-price');
check($code === 503, 'a price that makes no sense (gold not dearer by purity) is not given: ' . $code);
check(count($sent['metal']) === 2, 'tried with both models: ' . count($sent['metal']));
[$code] = call('GET', '/metal-price');
check($code === 503 && count($sent['metal']) === 2, 'after a failure it waits before asking the web again');
delete_transient('ma_metal_trying');
$GLOBALS['metal_reply'] = '{"effective_date":"' . $today . '","gold":{"22k":"2,05,000","21k":195700,"18k":167700,"traditional":139400},"silver":{"22k":3965,"21k":3780,"18k":3240,"traditional":2433},"source_url":"https://www.bajus.org/gold-price"}';
[$code, $d] = call('GET', '/metal-price');
check($code === 200 && $d['gold']['22k'] === 205000 && $d['silver']['traditional'] === 2433 && $d['date'] === $today && $d['unit'] === 'vori', 'today\'s price, per vori, with its date');
check(str_contains($d['source'], 'বাজুস') && $d['source_url'] === 'https://www.bajus.org/gold-price', 'says where it is from');
$m = end($sent['metal']);
check(($m['tools'][0]['type'] ?? '') === 'web_search_20250305' && !isset($m['system']), 'looked up with web search');
$n = count($sent['metal']);
[$code, $d2] = call('GET', '/metal-price');
check($code === 200 && count($sent['metal']) === $n && $d2['gold']['22k'] === 205000, 'kept for everyone: no new lookup within hours');
$k = get_option('ma_metal_price');
$k['fetched'] = time() - 7 * HOUR_IN_SECONDS;
update_option('ma_metal_price', $k, false);
$GLOBALS['metal_reply'] = 'not found';
[$code, $d3] = call('GET', '/metal-price');
check($code === 200 && $d3['gold']['22k'] === 205000 && count($sent['metal']) === $n + 2, 'an old price is still given (with its date) when a new one is not found');

echo "  — family (Pro), sealed items, location, heirs\n";
$mk = function ($email, $name, $pro) use ($wpdb) {
    $wpdb->insert(ma_acc_table(), ['google_sub' => 'g-' . $email, 'email' => $email, 'name' => $name, 'pro_until' => $pro ? gmdate('Y-m-d H:i:s', time() + 30 * DAY_IN_SECONDS) : null, 'created_at' => gmdate('Y-m-d H:i:s'), 'last_seen' => gmdate('Y-m-d H:i:s')]);
    $id = (int) $wpdb->insert_id;
    return [$id, ma_ai_new_session($id, 'member')];
};
[$momId, $momSes] = $mk('mom@gmail.com', 'আম্মা', true);
[$sonId, $sonSes] = $mk('son@gmail.com', 'রাফি', false);
$wpdb->update(ma_ai_sessions_table(), ['fcm_token' => 'son-phone-fcm-token-123456'], ['user_id' => $sonId]);
[$code, $d] = call('POST', '/family/invite', ['email' => 'aunt@gmail.com', 'relation' => 'খালা'], $sonSes);
check($code === 200, 'family: inviting is free (owner, 24 Oct)');
// A request not yet answered can be taken back by the one who sent it (owner, 24 Oct night).
$aunt = $d['links'][0]['id'] ?? 0;
[$code, $d] = call('POST', "/family/$aunt/remove", [], $sonSes);
check($code === 200 && count($d['links']) === 0, 'family: a pending request is taken back');
check($wpdb->get_var($wpdb->prepare('SELECT status FROM ' . ma_fam_table('links') . ' WHERE id = %d', $aunt)) === 'removed', 'family: the taken-back request is closed on the server');
$wpdb->query($wpdb->prepare('DELETE FROM ' . ma_fam_table('links') . ' WHERE a_user = %d', $sonId));
[$code, $d] = call('POST', '/family/key', ['pubkey' => 'short'], $momSes);
check($code === 400, 'a public key must be 32 bytes');
call('POST', '/family/key', ['pubkey' => base64_encode(random_bytes(32))], $momSes);
$sonKey = base64_encode(random_bytes(32));
call('POST', '/family/key', ['pubkey' => $sonKey], $sonSes);
$n0 = count($sent['fcm']);
[$code, $d] = call('POST', '/family/invite', ['email' => 'SON@gmail.com', 'relation' => 'ছেলে', 'allow' => ['task', 'bogus']], $momSes);
check($code === 200 && count($d['links']) === 1 && $d['links'][0]['status'] === 'pending' && $d['links'][0]['i_allow'] === ['task'], 'invite by e-mail with a relation; unknown permissions dropped');
check(count($sent['fcm']) === $n0 + 1, 'the invited member is pushed');
[$code] = call('POST', '/family/invite', ['email' => 'son@gmail.com'], $momSes);
check($code === 409, 'no second invite to the same person');
[$code, $d] = call('GET', '/family', [], $sonSes);
$lid = $d['links'][0]['id'] ?? 0;
check($code === 200 && $d['links'][0]['incoming'] === true && $d['links'][0]['they_call'] === 'ছেলে', 'the invited one sees it');
[$code] = call('POST', '/family/items', ['link' => $lid, 'kind' => 'task', 'sealed' => base64_encode('x')], $momSes);
check($code === 404, 'nothing can be sent before they accept');
[$code, $d] = call('POST', "/family/$lid/accept", ['relation' => 'আম্মা', 'allow' => ['task', 'reminder', 'medicine', 'location']], $sonSes);
check($code === 200 && $d['links'][0]['status'] === 'active' && $d['links'][0]['i_allow'] === ['task', 'reminder', 'medicine'], 'accepted, with what he lets her do — location left out without Premium');
[$code] = call('POST', "/family/$lid/allow", ['allow' => ['task', 'reminder', 'medicine', 'location']], $sonSes);
check($code === 402, 'showing my location needs Premium');
[$code] = call('POST', "/family/$lid/allow", ['heir' => true], $sonSes);
check($code === 402, 'naming an heir needs Premium');
$wpdb->update(ma_acc_table(), ['pro_until' => gmdate('Y-m-d H:i:s', time() + 30 * DAY_IN_SECONDS)], ['id' => $sonId]);
[$code] = call('POST', "/family/$lid/allow", ['allow' => ['task', 'reminder', 'medicine', 'location']], $sonSes);
check($code === 200, 'with Premium, location can be shared');
$wpdb->update(ma_acc_table(), ['pro_until' => null], ['id' => $sonId]);
[$code, $d] = call('GET', '/family', [], $momSes);
check($d['links'][0]['their_key'] === $sonKey && $d['links'][0]['they_allow'] === ['task', 'reminder', 'medicine', 'location'], 'she gets his public key and his permissions');
[$code] = call('POST', '/family/items', ['link' => $lid, 'kind' => 'medicine', 'sealed' => base64_encode(random_bytes(80))], $momSes);
[$c2] = call('POST', '/family/items', ['link' => $lid, 'kind' => 'note', 'sealed' => base64_encode('x')], $momSes);
check($code === 200 && $c2 === 403, 'a medicine reminder goes (allowed); a note does not (not allowed)');
[$code] = call('POST', '/family/items', ['link' => $lid, 'kind' => 'task', 'sealed' => base64_encode('x')], $sonSes);
check($code === 200, 'sending a task is free too');
[$code] = call('POST', '/family/items', ['link' => $lid, 'kind' => 'lockey', 'sealed' => base64_encode('k')], $sonSes);
check($code === 402, 'the location key needs Premium');
$wpdb->query($wpdb->prepare('DELETE FROM ' . ma_fam_table('items') . ' WHERE from_user = %d', $sonId));
$row = $wpdb->get_row("SELECT * FROM " . ma_fam_table('items') . " ORDER BY id DESC LIMIT 1", ARRAY_A);
check(!str_contains($row['sealed'] . wp_json_encode($row), 'ওষুধ') && $row['kind'] === 'medicine', 'the server keeps only the sealed bytes');
[$code, $d] = call('GET', '/family/items', [], $sonSes);
check($code === 200 && count($d['items']) === 1 && $d['items'][0]['kind'] === 'medicine', 'he fetches it');
call('POST', '/family/items/ack', ['ids' => [$d['items'][0]['id']]], $momSes);
[$c2, $d2] = call('GET', '/family/items', [], $sonSes);
check(count($d2['items']) === 1, 'only the receiver can clear it');
call('POST', '/family/items/ack', ['ids' => [$d['items'][0]['id']]], $sonSes);
[$c2, $d2] = call('GET', '/family/items', [], $sonSes);
check(count($d2['items']) === 0, 'received → removed from the server');
// Location
$n0 = count($sent['fcm']);
[$code] = call('POST', "/family/$lid/locate", [], $momSes);
$push = end($sent['fcm']);
check($code === 200 && count($sent['fcm']) === $n0 + 1 && !isset($push['message']['notification']) && $push['message']['data']['type'] === 'locate', 'asking where he is: a silent push to his phone');
[$code] = call('POST', "/family/$lid/locate", [], $sonSes);
check($code === 403, 'she has not shared hers: he cannot ask');
call('POST', '/family/location', ['sealed' => base64_encode('sealed-place')], $sonSes);
[$code, $d] = call('GET', "/family/$lid/location", [], $momSes);
check($code === 200 && base64_decode($d['sealed']) === 'sealed-place' && $d['at'], 'his phone answered (sealed); she reads it');
// Heirs (Premium)
$wpdb->update(ma_acc_table(), ['pro_until' => gmdate('Y-m-d H:i:s', time() + 30 * DAY_IN_SECONDS)], ['id' => $sonId]);
[$code, $d] = call('POST', "/family/$lid/allow", ['heir' => true], $sonSes);
check($code === 200 && $d['links'][0]['they_are_my_heir'] === true, 'he names his mother as heir');
[$code] = call('POST', '/family/package', ['blob' => base64_encode('sealed-copy'), 'keys' => [$lid => 'wrapped-for-mom', 999 => 'stranger']], $sonSes);
$pk = $wpdb->get_row("SELECT * FROM " . ma_fam_table('packages') . " WHERE owner_id = $sonId", ARRAY_A);
check($code === 200 && !str_contains($pk['keys_json'], 'stranger'), 'the sealed copy is kept, only for named heirs');
[$code] = call('GET', "/family/$lid/package", [], $momSes);
check($code === 403, 'not open while he lives and has not opened it');
[$code] = call('POST', "/family/$lid/claim", ['note' => 'x'], $momSes);
check($code === 400, 'a death report needs the certificate');
[$code, $d] = call('POST', "/family/$lid/claim", ['note' => 'গত শুক্রবার', 'file' => ['name' => 'sonod.png', 'data' => base64_encode(base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='))]], $momSes);
check($code === 200 && $d['links'][0]['claim']['status'] === 'review', 'reported with the certificate → waits for an admin');
[$code, $d] = call('GET', '/family/claims', [], $bossSes);
[$code, $d] = call('GET', '/admin/family/claims', [], $bossSes);
$cid = $d['claims'][0]['id'] ?? 0;
check($code === 200 && $d['claims'][0]['owner']['email'] === 'son@gmail.com' && $d['claims'][0]['heir']['relation'] === 'ছেলে' && $d['claims'][0]['has_file'], 'the admin app lists it, with who and the document');
[$code, $f] = call('GET', "/admin/family/claims/$cid/file", [], $bossSes);
check($code === 200 && $f['mime'] === 'image/png', 'the document opens for the admin');
[$code, $d] = call('GET', '/family', [], $sonSes);
check(count($d['claims_on_me']) === 1, 'he (if alive) sees that someone reported his death');
$mails = count($sent['mail']);
[$code] = call('POST', "/admin/family/claims/$cid", ['action' => 'approve', 'note' => 'সনদ মিলেছে'], $helperSes);
check($code === 200 && count($sent['mail']) === $mails + 1, 'approved (any admin) → the member is e-mailed and pushed');
[$code] = call('GET', "/family/$lid/package", [], $momSes);
check($code === 403, 'still closed during the 14 days');
[$code, $d] = call('POST', "/family/claims/$cid/cancel", [], $sonSes);
check($code === 200 && count($d['claims_on_me']) === 0, 'a living member cancels it');
// Full access given while alive: no waiting.
[$code, $d] = call('POST', "/family/$lid/allow", ['open_now' => true], $sonSes);
[$code, $d] = call('GET', "/family/$lid/package", [], $momSes);
check($code === 200 && base64_decode($d['blob']) === 'sealed-copy' && $d['key'] === 'wrapped-for-mom', 'access given now: she opens it at once (sealed for her)');
[$code] = call('POST', '/family/files', ['id' => 'f-photo-1', 'blob' => base64_encode('sealed-photo')], $sonSes);
[$c2, $f] = call('GET', "/family/$lid/files/f-photo-1", [], $momSes);
check($code === 200 && $c2 === 200 && base64_decode($f['blob']) === 'sealed-photo', 'photos too: sealed on his phone, opened by his heir');
call('POST', '/family/package', ['blob' => base64_encode('sealed-copy-2'), 'keys' => [$lid => 'wrapped-for-mom'], 'files' => []], $sonSes);
[$c4] = call('GET', "/family/$lid/files/f-photo-1", [], $momSes);
check($c4 === 404, 'a photo the copy no longer lists is deleted');
// A claim that runs its 14 days
call('POST', "/family/$lid/allow", ['open_now' => false], $sonSes);
call('POST', "/family/$lid/claim", ['note' => 'y', 'file' => ['name' => 'sonod.png', 'data' => base64_encode(base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='))]], $momSes);
$cid2 = (int) $wpdb->get_var("SELECT MAX(id) FROM " . ma_fam_table('claims'));
ma_fam_claim_decide($cid2, 'approve', '', 1);
$wpdb->update(ma_fam_table('claims'), ['open_at' => gmdate('Y-m-d H:i:s', time() - 60)], ['id' => $cid2]);
[$code] = call('GET', "/family/$lid/package", [], $momSes);
check($code === 200, 'after 14 days without a cancel: the heir opens it');
[$code, $d] = call('POST', "/family/$lid/remove", [], $sonSes);
[$code] = call('GET', "/family/$lid/package", [], $momSes);
check($code === 404 && (int) $wpdb->get_var("SELECT COUNT(*) FROM " . ma_fam_table('items') . " WHERE link_id = $lid") === 0, 'removing the link ends everything between them');
ma_fam_forget_member($sonId);
check(!$wpdb->get_var("SELECT COUNT(*) FROM " . ma_fam_table('packages') . " WHERE owner_id = $sonId") && !$wpdb->get_var("SELECT COUNT(*) FROM " . ma_fam_table('claims') . " WHERE owner_id = $sonId"), 'a deleted member leaves nothing behind');
wp_set_current_user(1);
$_GET = ['page' => 'my-assistant', 'tab' => 'heirs'];
ob_start();
ma_acc_admin();
$html = ob_get_clean();
check(str_contains($html, 'উত্তরাধিকারের অনুরোধ') && !preg_match('/(Warning|Notice|Fatal|Deprecated)\b.*on line/', $html), 'site page উত্তরাধিকার renders');

echo "  — ব্লাড ডোনেশন: the whole country\n";
[$farId, $farSes] = $mk('far@gmail.com', 'দূরের সদস্য', false);
[$code, $d] = call('POST', '/blood/requests', ['blood' => 'B+', 'bags' => 2, 'district' => 'রাজশাহী', 'hospital' => 'রাজশাহী মেডিকেল', 'location' => 'লক্ষ্মীপুর, ওয়ার্ড ৫', 'need_by' => gmdate('c', time() + DAY_IN_SECONDS), 'phone' => '01711223344', 'patient' => 'আমার মা', 'problem' => 'অপারেশন'], $momSes);
check($code === 200, 'a request with for whom, the problem and where the hospital is');
[$code, $d] = call('GET', '/blood/requests', ['scope' => 'all'], $farSes);
$mine = array_values(array_filter($d['requests'], fn($x) => $x['hospital'] === 'রাজশাহী মেডিকেল'));
check($code === 200 && $mine && $mine[0]['problem'] === 'অপারেশন' && $mine[0]['location'] === 'লক্ষ্মীপুর, ওয়ার্ড ৫' && $mine[0]['patient'] === 'আমার মা', 'seen from another district (the whole country), with every field');
[$code, $d] = call('GET', '/blood/requests', ['scope' => 'all', 'blood' => 'A+'], $farSes);
check($code === 200 && !array_filter($d['requests'], fn($x) => $x['hospital'] === 'রাজশাহী মেডিকেল'), 'a group filter narrows it');

echo "  — নোটিফিকেশনের লগ: the phone's plan and our pushes\n";
[$logId, $logSes] = $mk('log@gmail.com', 'লগ সদস্য', false);
$wpdb->update(ma_ai_sessions_table(), ['fcm_token' => 'log-phone-fcm-token-123456'], ['user_id' => $logId]);
$soon = gmdate('c', time() + 3600);
$later = gmdate('c', time() + 2 * DAY_IN_SECONDS);
[$code] = call('POST', '/notices/plan', ['items' => [['kind' => 'reminder', 'at' => $soon]]]);
check($code === 401, 'plan: needs the member session');
[$code, $d] = call('POST', '/notices/plan', ['items' => [
    ['kind' => 'reminder', 'at' => $soon, 'title' => 'ওষুধ খান — নাপা'],
    ['kind' => 'brief:morning', 'at' => $later],
    ['kind' => 'server', 'at' => $later, 'title' => 'আজকের লিস্ট করেছেন?'],
    ['kind' => 'Bad Kind!', 'at' => $soon],
    ['kind' => 'reminder', 'at' => gmdate('c', time() - 3600)],
    ['kind' => 'reminder', 'at' => gmdate('c', time() + 30 * DAY_IN_SECONDS)],
]], $logSes);
check($code === 200 && $d['saved'] === 3, 'plan: three good lines kept (bad kind, past and far ones dropped)');
$t = ma_nlog_table();
check(!$wpdb->get_var("SELECT COUNT(*) FROM $t WHERE user_id = $logId AND title LIKE '%নাপা%'"), "plan: a reminder's own words are never stored");
check($wpdb->get_var("SELECT title FROM $t WHERE user_id = $logId AND kind = 'server'") === 'আজকের লিস্ট করেছেন?', "plan: our own notification keeps its title");
call('POST', '/notices/plan', ['items' => [['kind' => 'reminder', 'at' => $later]]], $logSes);
check((int) $wpdb->get_var("SELECT COUNT(*) FROM $t WHERE user_id = $logId AND source = 'plan'") === 1, 'plan: a new list replaces what was still ahead');
$wpdb->insert($t, ['user_id' => $logId, 'source' => 'plan', 'kind' => 'reminder', 'title' => '', 'at' => gmdate('Y-m-d H:i:s', time() - 7200), 'status' => 'planned', 'created_at' => gmdate('Y-m-d H:i:s')]);
call('POST', '/notices/plan', ['items' => [['kind' => 'reminder', 'at' => $later]]], $logSes);
check((int) $wpdb->get_var("SELECT COUNT(*) FROM $t WHERE user_id = $logId AND source = 'plan'") === 2, 'plan: what already went by stays as history');
ma_push_member($logId, 'আপনার মতামতের উত্তর এসেছে', 'ধন্যবাদ', ['type' => 'feedback']);
ma_push_member($logId, '', '', ['type' => 'locate']);
[$code, $d] = call('GET', '/notices/log', [], $logSes);
check($code === 200 && count($d['pushes']) === 1 && $d['pushes'][0]['kind'] === 'feedback' && $d['pushes'][0]['status'] === 'sent', 'push: logged for the member (a silent one is not)');
[$code, $d] = call('GET', '/admin/notice-log', ['q' => 'log@gmail'], $bossSes);
$kinds = array_column($d['rows'] ?? [], 'kind');
check($code === 200 && in_array('feedback', $kinds, true) && in_array('reminder', $kinds, true) && !array_filter($d['rows'], fn($r) => $r['email'] !== 'log@gmail.com'), 'admin app: the log, filtered by member');
$shown = array_values(array_filter($d['rows'], fn($r) => $r['source'] === 'plan' && $r['status'] === 'shown'));
check($shown && $shown[0]['status_label'] === 'দেখানোর কথা', 'admin app: a planned one whose time came reads "দেখানোর কথা"');
[$code, $d] = call('GET', '/admin/notice-log', ['q' => 'log@gmail', 'when' => 'next'], $bossSes);
check($code === 200 && count($d['rows']) === 1 && $d['rows'][0]['kind'] === 'reminder', 'admin app: only what is still ahead');
[$code] = call('GET', '/admin/notice-log', [], $logSes);
check($code === 403, 'admin app: a member cannot read the log');
$n0 = count($sent['fcm']);
[$code, $d] = call('POST', '/admin/push', ['title' => 'নতুন সুবিধা', 'body' => 'দেখুন', 'audience' => 'all'], $bossSes);
check($code === 200 && $d['sent'] >= 1 && (int) $wpdb->get_var("SELECT COUNT(*) FROM $t WHERE user_id = $logId AND kind = 'news'") === 1, 'a push to everyone is logged per member');
wp_set_current_user(1);
$_GET = ['page' => 'my-assistant', 'tab' => 'notices', 'nq' => 'log@gmail'];
ob_start();
ma_acc_admin();
$html = ob_get_clean();
check(str_contains($html, 'কোন কোন নোটিফিকেশন') && str_contains($html, 'মতামতের উত্তর') && str_contains($html, 'এখনই পাঠান') && !preg_match('/(Warning|Notice|Fatal|Deprecated)\b.*on line/', $html), 'site: the log and "send now" on the নোটিফিকেশন tab');

echo "  — হিসাব: income, expense, investors (owner only)\n";
$paid = (int) $wpdb->get_var('SELECT COALESCE(SUM(amount),0) FROM ' . ma_pay_table() . " WHERE status = 'approved'");
[$code, $f0] = call('GET', '/admin/finance', [], $bossSes);
check($code === 200 && $f0['all']['income'] === $paid, 'income = approved payments only (' . $paid . ')');
$bossOnly = ma_ai_new_session($bossId, 'admin');
[$code] = call('GET', '/admin/finance', [], $bossOnly);
check($code === 403, 'an admin who is not the site owner cannot see the money');
$someone = $wpdb->get_row('SELECT id FROM ' . ma_acc_table() . " WHERE email = 'log@gmail.com'", ARRAY_A);
call('POST', '/admin/members/' . $someone['id'], ['days' => 30], $bossSes);
[$code, $f1] = call('GET', '/admin/finance', [], $bossSes);
check($f1['all']['income'] === $paid, 'Pro given without money adds nothing to income');
[$code] = call('POST', '/admin/finance/entry', ['kind' => 'expense', 'category' => 'সার্ভার ও হোস্টিং', 'amount' => 1500, 'date' => current_time('Y-m-d'), 'note' => 'হোস্টিং'], $bossSes);
[$code2] = call('POST', '/admin/finance/entry', ['kind' => 'income', 'category' => 'বিজ্ঞাপন', 'amount' => 400], $bossSes);
[$code3] = call('POST', '/admin/finance/entry', ['kind' => 'expense', 'amount' => 0], $bossSes);
check($code === 200 && $code2 === 200 && $code3 === 400, 'hand-written expense and income; no amount refused');
[$code] = call('POST', '/admin/finance/investor', ['name' => 'করিম চৌধুরী', 'contact' => '01711000000', 'amount' => 200000, 'share' => '10', 'date' => '2026-09-01'], $bossSes);
[$code, $f2] = call('GET', '/admin/finance', [], $bossSes);
check($f2['month']['expense'] === $f1['month']['expense'] + 1500 && $f2['month']['income'] === $f1['month']['income'] + 400, "this month's figures include them");
check($f2['invested'] === 200000 && $f2['investors'][0]['share'] === '10' && $f2['all']['income'] === $paid + 400, 'investment kept apart from income');
check($f2['cash'] === 200000 + $f2['all']['income'] - $f2['all']['expense'], 'cash = investment + income − expense');
$eid = $f2['entries'][0]['id'];
[$code] = call('DELETE', "/admin/finance/entry/$eid", [], $bossSes);
[$code, $f3] = call('GET', '/admin/finance', [], $bossSes);
check(count($f3['entries']) === count($f2['entries']) - 1, 'a line can be deleted');
wp_set_current_user(1);
$_GET = ['page' => 'my-assistant', 'tab' => 'finance'];
ob_start();
ma_acc_admin();
$html = ob_get_clean();
check(str_contains($html, 'বিনিয়োগকারী') && str_contains($html, 'করিম চৌধুরী') && str_contains($html, 'এ মাসে আয়') && !preg_match('/(Warning|Notice|Fatal|Deprecated)\b.*on line/', $html), 'site: the হিসাব tab renders');

// ── সমস্যার লগ (owner, 24 Oct night) ──
$err = ['kind' => 'StateError', 'message' => 'Bad state: "রহিমকে ৫০০" for saif@gmail.com 01712345678', 'stack' => "package:digital_brain/state/brain.dart:120\npackage:flutter/src/widgets/framework.dart:5", 'version' => '2.53.0+108', 'count' => 2];
[$code, $d] = call('POST', '/errors', ['items' => [$err, ['kind' => '', 'message' => '']]], '');
check($code === 200 && $d['kept'] === 1, 'errors: kept without sign-in; empty ones dropped');
call('POST', '/errors', ['items' => [$err]], $sonSes);
[$code, $d] = call('GET', '/admin/errors', [], $bossSes);
$e0 = $d['errors'][0] ?? [];
check($code === 200 && count($d['errors']) === 1 && $e0['count'] === 4, 'errors: the same error counted together');
check(!str_contains(json_encode($e0, JSON_UNESCAPED_UNICODE), 'রহিম') && !str_contains($e0['message'], 'saif@') && !str_contains($e0['message'], '01712345678'), 'errors: no member words, e-mail or number kept');
check(str_contains($e0['stack'], 'brain.dart:120') && $e0['version'] === '2.53.0+108', 'errors: code places and version kept');
[$code] = call('GET', '/admin/errors', [], $sonSes);
check($code === 403, 'errors: only admins read them');
$_GET = ['page' => 'my-assistant', 'tab' => 'errors'];
ob_start();
ma_acc_admin();
$html = ob_get_clean();
check(str_contains($html, 'সমস্যার লগ') && str_contains($html, 'StateError') && !preg_match('/(Warning|Notice|Fatal|Deprecated)\b.*on line/', $html), 'site: the সমস্যার লগ tab renders');
// Problems the app handled but the member felt (owner, 27 Oct): apart from crashes, with a plain meaning.
call('POST', '/errors', ['items' => [
    ['level' => 'problem', 'kind' => 'AiError', 'message' => 'timeout', 'stack' => 'package:digital_brain/state/brain.dart:1555', 'version' => '2.55.12', 'count' => 3],
    ['level' => 'problem', 'kind' => 'Voice', 'message' => 'error_network', 'stack' => '', 'version' => '2.55.12'],
    ['level' => 'crash', 'kind' => 'Android:IllegalStateException', 'message' => 'x', 'stack' => 'com.iamsaifsaiful.digital_brain.MainActivity.onCreate:120', 'version' => '2.55.12'],
]], $sonSes);
[$code, $d] = call('GET', '/admin/errors', ['level' => 'problem'], $bossSes);
$ai = current(array_filter($d['errors'], fn($e) => $e['kind'] === 'AiError'));
check($code === 200 && count($d['errors']) === 2 && $ai && $ai['level'] === 'problem' && $ai['count'] === 3 && str_contains($ai['meaning'], 'সময়মতো'), 'errors: problems apart, with a plain meaning');
check($d['counts']['crash'] >= 5 && $d['counts']['problem'] === 4 && $d['counts']['day'] >= 3, 'errors: counted by kind (' . json_encode($d['counts']) . ')');
[$code, $d] = call('GET', '/admin/errors', ['level' => 'crash'], $bossSes);
check(array_filter($d['errors'], fn($e) => str_contains($e['meaning'], 'Android')) && !array_filter($d['errors'], fn($e) => $e['level'] !== 'crash'), 'errors: an Android crash among the crashes');
$_GET = ['page' => 'my-assistant', 'tab' => 'errors', 'lv' => 'problem'];
ob_start();
ma_acc_admin();
$html = ob_get_clean();
check(str_contains($html, 'ফোন থেকে সরাসরি') && str_contains($html, 'কথা শোনার সময় ইন্টারনেট পায়নি') && !str_contains($html, 'StateError') && !preg_match('/(Warning|Notice|Fatal|Deprecated)\b.*on line/', $html), 'site: problems filter on the সমস্যার লগ tab');
[$code, $d] = call('POST', '/admin/errors/clear', [], $bossSes);
check($code === 200 && $d['errors'] === [], 'errors: cleared by an admin');


// ── 27 Oct: members by date and source, PDF, bKash on its own, server pushes, inbox, হিসাব ──
echo "\n  — members by join date and Premium source\n";
$U = ma_acc_table();
$mkm = function ($email, $days_ago, $kind = '', $pro = false) use ($wpdb, $U) {
    $at = gmdate('Y-m-d H:i:s', time() - $days_ago * DAY_IN_SECONDS - 60);
    $wpdb->insert($U, ['google_sub' => 'g-' . $email, 'email' => $email, 'name' => $email, 'created_at' => $at, 'last_seen' => $at, 'pro_kind' => $kind, 'pro_until' => $pro ? gmdate('Y-m-d H:i:s', time() + 30 * DAY_IN_SECONDS) : null]);
    return (int) $wpdb->insert_id;
};
$before = ma_acc_member_stats();
$mkm('today1@x.com', 0);
$mkm('today2@x.com', 0, 'web', true);
$mkm('old@x.com', 45, 'manual', true);
$mkm('play@x.com', 3, 'play:pro_yearly', true);
$st = ma_acc_member_stats();
check($st['today_new'] === $before['today_new'] + 2, 'members: new today counted (' . $st['today_new'] . ')');
[$code, $d] = call('GET', '/admin/members', ['joined' => 'today'], $bossSes);
$emails = array_column($d['members'], 'email');
check($code === 200 && in_array('today1@x.com', $emails, true) && !in_array('old@x.com', $emails, true) && $d['count'] === $st['today_new'], 'members: joined=today filter');
$oldMonth = gmdate('Y-m', time() + ma_acc_tz_off() - 45 * DAY_IN_SECONDS);
[$code, $d] = call('GET', '/admin/members', ['joined' => $oldMonth], $bossSes);
check(in_array('old@x.com', array_column($d['members'], 'email'), true) && !in_array('today1@x.com', array_column($d['members'], 'email'), true), 'members: a month (' . $oldMonth . ')');
[$code, $d] = call('GET', '/admin/members', ['src' => 'play'], $bossSes);
check(array_column($d['members'], 'email') === ['play@x.com'] && $d['members'][0]['source_label'] === 'Google Play', 'members: by Premium source (Google Play)');
[$code, $g] = call('GET', '/admin/members/growth', [], $bossSes);
check($code === 200 && count($g['days']) === 30 && count($g['months']) === 12 && end($g['days'])['n'] === $st['today_new'] && $g['stats']['month_new'] >= 2, 'members: growth per day (30) and month (12)');
$src = array_column($g['sources'], 'n', 'key');
check(($src['web'] ?? 0) >= 1 && ($src['play'] ?? 0) === 1 && ($src['manual'] ?? 0) >= 1, 'members: Premium counted by source');
// The old "manual" Premium that came from a website payment becomes "web" (once).
$mid = $mkm('paidbefore@x.com', 10, 'manual', true);
$wpdb->insert(ma_pay_table(), ['created_at' => gmdate('Y-m-d H:i:s'), 'email' => 'paidbefore@x.com', 'plan' => 'yearly', 'amount' => 999, 'method' => 'বিকাশ', 'trx' => 'OLDPAY0001', 'status' => 'approved', 'reviewed_at' => gmdate('Y-m-d H:i:s')]);
delete_option('ma_acc_src_mig');
ma_acc_source_migrate();
check($wpdb->get_var("SELECT pro_kind FROM $U WHERE id = $mid") === 'web' && $wpdb->get_var("SELECT pro_kind FROM $U WHERE email = 'old@x.com'") === 'manual', 'members: old website payments shown as ওয়েবসাইট, gifts stay অ্যাডমিন');
[$code, $d] = call('POST', '/admin/members/print-link', ['joined' => 'today'], $bossSes);
parse_str((string) parse_url($d['url'] ?? '', PHP_URL_QUERY), $pq);
$job = get_transient('ma_print_' . hash('sha256', $pq['ma_members_print'] ?? ''));
check($code === 200 && is_array($job) && $job['joined'] === 'today', 'PDF: a 10-minute link for the admin app');
check(is_array(ma_acc_print_take($pq['ma_members_print'])) && ma_acc_print_take($pq['ma_members_print']) === null, 'PDF: the link opens once only');
$_SERVER['REMOTE_ADDR'] = '162.158.10.20';
$_SERVER['HTTP_CF_CONNECTING_IP'] = '103.4.145.9';
check(ma_client_ip() === '103.4.145.9', 'client IP: through Cloudflare, the visitor\'s own address');
$_SERVER['REMOTE_ADDR'] = '45.12.1.1';
check(ma_client_ip() === '45.12.1.1', 'client IP: the Cloudflare header from anywhere else is not believed');
$_SERVER['REMOTE_ADDR'] = '2606:4700:10::6816:1';
check(ma_client_ip() === '103.4.145.9' && !ma_ip_in_cloudflare('2001:db8::1'), 'client IP: Cloudflare over IPv6 too');
unset($_SERVER['HTTP_CF_CONNECTING_IP']);
$_SERVER['REMOTE_ADDR'] = '127.0.0.1';
[$code] = call('POST', '/admin/members/print-link', [], $ses);
check($code === 403, 'PDF: members cannot make one');
$html = ma_acc_print_html('', '', 'today', '');
check(str_contains($html, 'today1@x.com') && !str_contains($html, 'old@x.com') && str_contains($html, 'window.print()') && str_contains($html, 'আজ যোগ দিয়েছেন'), 'PDF: the print page has the filtered list');

echo "\n  — bKash: Premium on by itself\n";
$sms = 'You have received Tk 999.00 from 01712345678. Ref 12. Fee Tk 0.00. Balance Tk 5,210.50. TrxID 9A7KX2PQ1M at 27/10/2026 15:02';
$p = ma_bk_parse($sms);
check($p && $p['trx'] === '9A7KX2PQ1M' && $p['amount'] === 999 && $p['sender'] === '01712345678' && $p['at'] !== '', 'bKash: an English “received” message read (balance left out)');
$p2 = ma_bk_parse('আপনি ০১৮১২৩৪৫৬৭৮ থেকে ৯৯.০০ টাকা পেয়েছেন। TrxID BJR4XYZ123 সময় ২৭/১০/২০২৬ ১০:১৫');
check($p2 && $p2['amount'] === 99 && $p2['sender'] === '01812345678' && $p2['trx'] === 'BJR4XYZ123', 'bKash: a Bangla message read');
check(ma_bk_parse('Cash In Tk 500.00 from 01712345678 successful. TrxID 8J7K6L5M4N') === null && ma_bk_parse('Send Money Tk 50.00 to 01712345678 successful. TrxID 7J7K6L5M4N') === null, 'bKash: cash-in and sending are not payments');
[$code, $d] = call('POST', '/admin/bkash/key', [], $bossSes);
$bkey = $d['key'] ?? '';
check($code === 200 && preg_match('/^bk_[a-f0-9]{48}$/', $bkey), 'bKash: the payment-SIM phone gets its own key');
$smscall = function ($key, $items) {
    $req = new WP_REST_Request('POST', '/my-assistant/v1/bkash/sms');
    $req->set_header('x-ma-bkash-key', $key);
    $req->set_header('content-type', 'application/json');
    $req->set_body(wp_json_encode(['items' => $items]));
    $res = rest_do_request($req);
    return [$res->get_status(), rest_get_server()->response_to_data($res, false)];
};
[$code] = $smscall('bk_' . str_repeat('0', 48), [$p]);
check($code === 403, 'bKash: a wrong key is refused');
[$code] = call('POST', '/admin/bkash/key', [], $ses);
check($code === 403, 'bKash: a member cannot make a key');
// Automatic approval is off until an admin turns it on (owner's review, 27 Oct).
[$code, $d] = call('GET', '/admin/bkash', [], $bossSes);
check($code === 200 && $d['auto'] === false, 'bKash: automatic approval starts off');
call('POST', '/admin/bkash/settings', ['auto' => true], $bossSes);
$p['verified'] = true;
// 0) a faked "bKash" message (its balance could not be checked on the phone): never approved by itself.
$mkm('spoof@x.com', 2);
$wpdb->insert(ma_pay_table(), ['created_at' => gmdate('Y-m-d H:i:s'), 'email' => 'spoof@x.com', 'plan' => 'yearly', 'amount' => 999, 'method' => 'বিকাশ', 'sender' => '01555555555', 'trx' => 'SPOOFED001', 'status' => 'pending']);
[$code, $d] = $smscall($bkey, [['trx' => 'SPOOFED001', 'amount' => 999, 'sender' => '01555555555', 'at' => gmdate('c'), 'verified' => false]]);
$ps = $wpdb->get_row('SELECT * FROM ' . ma_pay_table() . " WHERE trx = 'SPOOFED001'", ARRAY_A);
check($d['results'] === ['found'] && $ps['status'] === 'pending' && str_contains($ps['reason'], 'ব্যালেন্স') && $wpdb->get_var("SELECT pro_until FROM $U WHERE email = 'spoof@x.com'") === null, 'bKash: a message the phone could not check against the balance waits for an admin');
// 1) the form first, then the money.
$U2 = $mkm('bkpayer@x.com', 2);
$wpdb->insert(ma_pay_table(), ['created_at' => gmdate('Y-m-d H:i:s'), 'email' => 'bkpayer@x.com', 'plan' => 'yearly', 'amount' => 999, 'method' => 'বিকাশ', 'sender' => '01712-345678', 'trx' => '9a7kx2pq1m', 'status' => 'pending']);
$pid1 = (int) $wpdb->insert_id;
$fcm0 = count($sent['fcm']);
[$code, $d] = $smscall($bkey, [$p, ['trx' => 'x', 'amount' => 5]]);
$row = $wpdb->get_row("SELECT * FROM $U WHERE id = $U2", ARRAY_A);
check($code === 200 && $d['results'] === ['matched', 'bad'] && $wpdb->get_var("SELECT status FROM " . ma_pay_table() . " WHERE id = $pid1") === 'approved', 'bKash: money arrives → the waiting payment is approved');
check(ma_acc_status($row) === 'pro' && $row['pro_kind'] === 'bkash' && ma_acc_source_label($row) === 'বিকাশ — নিজে থেকে মিলেছে', 'bKash: Premium on, source বিকাশ (নিজে থেকে)');
$bkrow = $wpdb->get_row('SELECT * FROM ' . ma_bk_table() . " WHERE trx = '9A7KX2PQ1M'", ARRAY_A);
check($bkrow && (int) $bkrow['amount'] === 999 && $bkrow['sender'] === '01712345678' && !str_contains(wp_json_encode($bkrow), '5,210') && !str_contains(wp_json_encode($bkrow), 'Balance'), 'bKash: only amount, TrxID, number and time kept');
[$code, $d] = $smscall($bkey, [$p]);
check($d['results'] === ['matched'] && (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . ma_bk_table() . " WHERE trx = '9A7KX2PQ1M'") === 1, 'bKash: the same message twice is kept once');
// 2) the money first, then the form.
$smscall($bkey, [['trx' => 'MONEYFIRST1', 'amount' => 99, 'sender' => '01911111111', 'at' => gmdate('c'), 'verified' => true]]);
$wpdb->insert(ma_pay_table(), ['created_at' => gmdate('Y-m-d H:i:s'), 'email' => 'later@x.com', 'plan' => 'monthly', 'amount' => 99, 'method' => 'বিকাশ', 'sender' => '01911111111', 'trx' => 'MONEYFIRST1', 'status' => 'pending']);
$pid2 = (int) $wpdb->insert_id;
check(ma_bk_on_payment($pid2) === true && $wpdb->get_var("SELECT pro_kind FROM $U WHERE email = 'later@x.com'") === 'bkash', 'bKash: the form after the money → Premium at once (a member waiting to sign in)');
// 3) too little money, or another number: left for an admin.
$wpdb->insert(ma_pay_table(), ['created_at' => gmdate('Y-m-d H:i:s'), 'email' => 'short@x.com', 'plan' => 'yearly', 'amount' => 999, 'method' => 'বিকাশ', 'sender' => '01700000000', 'trx' => 'SHORTPAY01', 'status' => 'pending']);
$pid3 = (int) $wpdb->insert_id;
[$code, $d] = $smscall($bkey, [['trx' => 'SHORTPAY01', 'amount' => 500, 'sender' => '01700000000']]);
$p3 = $wpdb->get_row('SELECT * FROM ' . ma_pay_table() . " WHERE id = $pid3", ARRAY_A);
check($d['results'] === ['short'] && $p3['status'] === 'pending' && str_contains($p3['reason'], '৳৫০০'), 'bKash: less than the price → waits for an admin, reason written');
$wpdb->insert(ma_pay_table(), ['created_at' => gmdate('Y-m-d H:i:s'), 'email' => 'other@x.com', 'plan' => 'monthly', 'amount' => 99, 'method' => 'বিকাশ', 'sender' => '01799999999', 'trx' => 'OTHERNO001', 'status' => 'pending']);
[$code, $d] = $smscall($bkey, [['trx' => 'OTHERNO001', 'amount' => 99, 'sender' => '01788888888']]);
check($d['results'] === ['other_no'], 'bKash: the money came from another number → waits for an admin');
[$code, $d] = call('POST', '/admin/bkash/settings', ['auto' => false], $bossSes);
$wpdb->insert(ma_pay_table(), ['created_at' => gmdate('Y-m-d H:i:s'), 'email' => 'manual@x.com', 'plan' => 'monthly', 'amount' => 99, 'method' => 'বিকাশ', 'sender' => '', 'trx' => 'AUTOOFF001', 'status' => 'pending']);
[$code2, $d2] = call('POST', '/admin/bkash/manual', ['trx' => 'AUTOOFF001', 'amount' => 99, 'sender' => '01700000001'], $bossSes);
check($d['auto'] === false && $d2['status'] === 'found' && $wpdb->get_var('SELECT status FROM ' . ma_pay_table() . " WHERE trx = 'AUTOOFF001'") === 'pending', 'bKash: automatic approval off → found, but an admin decides');
call('POST', '/admin/bkash/settings', ['auto' => true], $bossSes);
[$code, $d] = call('GET', '/admin/bkash', [], $bossSes);
check($code === 200 && $d['phone_set'] === true && $d['last_sms'] !== null && count($d['received']) >= 5, 'bKash: the overview for the admin app');

echo "\n  — notifications: the server pushes at the time; what goes, when, how many\n";
$pushSes = ma_ai_new_session((int) $u['id']);
call('POST', '/device', ['token' => 'fcm-token-for-rahim-0123456789'], $pushSes);
$localNow = time() + ma_acc_tz_off();
$wpdb->insert(ma_note_table(), ['title' => 'এখনকার নোটিফিকেশন', 'body' => 'পরীক্ষা', 'kind' => 'daily', 'at_time' => gmdate('H:i', $localNow - 120), 'audience' => 'all', 'cond' => '', 'mic' => 1, 'active' => 1, 'created_at' => gmdate('Y-m-d H:i:s')]);
$nidNow = (int) $wpdb->insert_id;
$wpdb->insert(ma_note_table(), ['title' => 'শর্তের নোটিফিকেশন', 'kind' => 'daily', 'at_time' => gmdate('H:i', $localNow - 120), 'audience' => 'all', 'cond' => 'no_tasks', 'mic' => 0, 'active' => 1, 'created_at' => gmdate('Y-m-d H:i:s')]);
$nidCond = (int) $wpdb->insert_id;
$wpdb->insert(ma_note_table(), ['title' => 'পুরোনো সময়', 'kind' => 'daily', 'at_time' => gmdate('H:i', $localNow - 3 * 3600), 'audience' => 'all', 'cond' => '', 'mic' => 0, 'active' => 1, 'created_at' => gmdate('Y-m-d H:i:s')]);
$nidLate = (int) $wpdb->insert_id;
[$code, $d] = call('GET', '/notices', ['push' => 1], $pushSes);
check($code === 200 && in_array($nidNow, $d['pushed'], true) && !in_array($nidCond, $d['pushed'], true), 'notices: the new app is told which ones the server pushes (not the conditional one)');
[$code, $d] = call('GET', '/notices', [], $ses);
check($d['pushed'] === [], 'notices: an old app still plans them all itself');
delete_transient('ma_note_tick_lock');
$wpdb->query('DELETE FROM ' . ma_note_runs_table());
$f0 = count($sent['fcm']);
ma_note_tick();
$mine = array_filter(array_slice($sent['fcm'], $f0), fn($m) => ($m['message']['notification']['title'] ?? '') === 'এখনকার নোটিফিকেশন');
$m1 = reset($mine);
check(count($mine) === 1 && $m1['message']['token'] === 'fcm-token-for-rahim-0123456789' && $m1['message']['data']['type'] === 'server' && $m1['message']['data']['mic'] === '1', 'notices: due now → pushed to the phone that asked for pushes');
check(!array_filter(array_slice($sent['fcm'], $f0), fn($m) => in_array($m['message']['notification']['title'] ?? '', ['শর্তের নোটিফিকেশন', 'পুরোনো সময়'], true)), 'notices: the conditional one and one 3 hours late are not pushed');
$f1 = count($sent['fcm']);
ma_note_tick();
check(count($sent['fcm']) === $f1, 'notices: each notice goes once a day');
$run = $wpdb->get_row('SELECT * FROM ' . ma_note_runs_table() . " WHERE notice_id = $nidNow", ARRAY_A);
check($run && (int) $run['sent'] === 1 && (int) $run['members'] === 1, 'notices: the run is counted (1 member, 1 sent)');
[$code, $ov] = call('GET', '/admin/notice-stats', [], $bossSes);
$today = gmdate('Y-m-d', $localNow);
$day0 = $ov['days'][0] ?? [];
check($code === 200 && $day0['day'] === $today && $day0['server'] >= 1 && $day0['total'] >= 1 && count($ov['days']) === 14, 'notices: per day and kind (today has the server push)');
$up = array_filter($ov['upcoming'], fn($x) => $x['id'] === $nidNow);
check(count($up) >= 6 && reset($up)['how'] === 'push' && reset($up)['phones'] >= 1, 'notices: the next 7 days, with how each goes');
$upc = array_filter($ov['upcoming'], fn($x) => $x['id'] === $nidCond);
check($upc && reset($upc)['how'] === 'phone', 'notices: a conditional one is shown by the phone');
check(($ov['runs'][$nidNow]['sent'] ?? 0) === 1 && !isset($ov['nlog']), 'notices: per-notice sends, and no list of who got what');
[$code] = call('GET', '/admin/notice-stats', [], $ses);
check($code === 403, 'notices: the overview is for admins');
$wpdb->delete(ma_note_table(), ['id' => $nidLate]);
// One day: what, when, how many; and how many each member gets.
call('POST', '/notices/plan', ['items' => [['kind' => 'reminder', 'at' => gmdate('c', time() + 3600)], ['kind' => 'brief:morning', 'at' => gmdate('c', time() + 7200)]]], $pushSes);
[$code, $nd] = call('GET', '/admin/notice-day', [], $bossSes);
$cat = array_column($nd['app'], null, 'key');
$srv = current(array_filter($nd['app'], fn($i) => $i['sample'] === 'এখনকার নোটিফিকেশন'));
check($code === 200 && $srv && $srv['by'] === 'server' && $srv['count'] === 1 && $srv['people'] === 1 && preg_match('/^\d\d:\d\d$/', $srv['times'][0] ?? ''), 'notice day: the server push with its time and count');
check(isset($cat['brief:morning'], $cat['nudge:quote'], $cat['brief:night'], $cat['nudge:jumuah']) && $cat['brief:morning']['count'] === 1 && $cat['brief:morning']['ahead'] === 1 && $cat['nudge:jumuah']['count'] === 0 && str_contains($cat['brief:night']['when'], '৯টা'), 'notice day: every kind the app sends, with its rule; the morning one counted and coming');
check(!isset($cat['reminder']) && $nd['reminders']['count'] >= 1 && $nd['reminders']['people'] >= 1 && !array_filter($nd['app'], fn($i) => str_contains($i['label'], 'রিমাইন্ডার')), 'notice day: members\' own reminders only as one count, apart from the app\'s');
$me = current(array_filter($nd['members'], fn($m) => $m['email'] === 'rahim@gmail.com'));
check($me && $me['count'] >= 2 && $me['reminders'] >= 1 && $nd['people'] >= 1 && $nd['max'] >= $me['count'] && $nd['avg'] > 0 && $nd['rules']['cap'] === 3, 'notice day: how many the app sends each member (' . ($me['count'] ?? 0) . ' + ' . ($me['reminders'] ?? 0) . ' own reminders)');
[$code] = call('GET', '/admin/notice-day', [], $ses);
check($code === 403, 'notice day: admins only');

echo "\n  — feedback: one inbox per member\n";
$sesA = ma_ai_new_session((int) $u['id']);
[$c1, $t1] = call('POST', '/feedback', ['kind' => 'idea', 'text' => 'প্রথম মতামত — রিংটোন নিজের মতো'], $sesA);
[$c2, $t2] = call('POST', '/feedback', ['kind' => 'problem', 'text' => 'দ্বিতীয় মতামত — লোকেশন বদলায় না'], $sesA);
[$code, $d] = call('GET', '/admin/inbox', ['status' => 'open'], $bossSes);
$me = current(array_filter($d['members'], fn($g) => $g['user_id'] === (int) $u['id']));
check($code === 200 && $me && $me['threads'] >= 2 && $me['new'] >= 2 && in_array('idea', $me['kinds'], true) && in_array('problem', $me['kinds'], true), 'inbox: one row per member with both conversations');
check(count(array_filter($d['members'], fn($g) => $g['user_id'] === (int) $u['id'])) === 1, 'inbox: the member appears once');
[$code, $one] = call('GET', '/admin/inbox/' . $u['id'], [], $bossSes);
$texts = array_column($one['messages'], 'text');
check($code === 200 && array_search('প্রথম মতামত — রিংটোন নিজের মতো', $texts) < array_search('দ্বিতীয় মতামত — লোকেশন বদলায় না', $texts) && $one['reply_to'] === $t2['id'], 'inbox: all messages in time order; a reply goes to the newest open one');
check((int) $wpdb->get_var('SELECT COUNT(*) FROM ' . ma_fb_table() . " WHERE user_id = {$u['id']} AND status = 'new'") === 0, 'inbox: opening marks them read');
call('POST', "/admin/feedback/{$one['reply_to']}/reply", ['text' => 'দেখছি, ধন্যবাদ!'], $bossSes);
[$code, $one2] = call('GET', '/admin/inbox/' . $u['id'], [], $bossSes);
check(end($one2['messages'])['text'] === 'দেখছি, ধন্যবাদ!' && end($one2['messages'])['from'] === 'admin', 'inbox: the reply shows at the end');
[$code] = call('POST', '/admin/inbox/' . $u['id'], ['status' => 'done'], $bossSes);
[$code2, $d] = call('GET', '/admin/inbox', ['status' => 'open'], $bossSes);
check($code === 200 && !array_filter($d['members'], fn($g) => $g['user_id'] === (int) $u['id']), 'inbox: “all finished” closes every conversation of the member');
[$code] = call('GET', '/admin/inbox', [], $ses);
check($code === 403, 'inbox: admins only');

echo "\n  — হিসাব: one month's lines with filters\n";
$ym = current_time('Y-m');
$L = ma_fin_month_lines($ym);
$cats = array_column($L['lines'], 'category');
check(in_array('প্রিমিয়াম (বার্ষিক)', $cats, true) && (bool) array_filter($L['lines'], fn($l) => $l['auto'] && $l['id'] === 0), 'হিসাব: approved payments come in as lines by themselves');
$Li = ma_fin_month_lines($ym, 'income');
check($Li['lines'] && !array_filter($Li['lines'], fn($l) => $l['kind'] !== 'income') && $Li['sum']['expense'] === 0, 'হিসাব: filter income only');
$Lc = ma_fin_month_lines($ym, '', 'প্রিমিয়াম (মাসিক)');
check($Lc['lines'] && !array_filter($Lc['lines'], fn($l) => $l['category'] !== 'প্রিমিয়াম (মাসিক)'), 'হিসাব: filter by category');
[$code, $d] = call('GET', '/admin/finance', ['month' => $ym, 'kind' => 'expense'], $bossSes);
check($code === 200 && isset($d['month_lines']) && !array_filter($d['month_lines']['lines'], fn($l) => $l['kind'] !== 'expense'), 'হিসাব: the same for the admin app');

echo "\n  — the site pages\n";
wp_set_current_user(1);
$render = function ($get) {
    $_GET = ['page' => 'my-assistant'] + $get;
    ob_start();
    ma_acc_admin();
    return ob_get_clean();
};
$bad = '/(Warning|Notice|Fatal|Deprecated)\b.*on line/';
$h = $render(['joined' => 'today']);
check(str_contains($h, 'নতুন সদস্য') && str_contains($h, 'দৈনিক') && str_contains($h, 'মাসিক') && str_contains($h, 'today1@x.com') && !str_contains($h, 'old@x.com') && str_contains($h, 'ma_acc_print') && !preg_match($bad, $h), 'site: members by day, bars, PDF button');
$h = $render(['jm' => $oldMonth]);
check(str_contains($h, 'old@x.com') && !str_contains($h, 'today1@x.com') && !preg_match($bad, $h), 'site: the month picker');
$h = $render(['src' => 'web']);
check(str_contains($h, 'ওয়েবসাইট (বিকাশ)') && str_contains($h, 'today2@x.com') && !str_contains($h, 'play@x.com') && !preg_match($bad, $h), 'site: Premium source filter and label');
$h = $render(['tab' => 'payments', 'pst' => 'all']);
check(str_contains($h, 'বিকাশে আসা টাকা') && str_contains($h, '9A7KX2PQ1M') && str_contains($h, 'মিলেছে — প্রিমিয়াম চালু') && !preg_match($bad, $h), 'site: payments show bKash');
$h = $render(['tab' => 'security']);
check(str_contains($h, 'দুই ধাপের লগইন') && str_contains($h, 'নিরাপত্তা') && !preg_match($bad, $h), 'site: the নিরাপত্তা tab (two-step sign-in)');
$h = $render(['tab' => 'notices']);
check(str_contains($h, 'আজ আর কাল কী যাবে') && str_contains($h, 'দিনে কতটি') && str_contains($h, 'অ্যাপ থেকে কোন কোন নোটিফিকেশন যায়') && str_contains($h, 'জুমা মোবারক') && str_contains($h, 'সীমার বাইরে') && str_contains($h, 'সদস্যের নিজের রিমাইন্ডার') && str_contains($h, 'কে দিনে কতগুলো পাচ্ছে') && str_contains($h, 'এখনকার নোটিফিকেশন') && str_contains($h, 'সার্ভার থেকে পুশ') && !str_contains($h, '<h2>কার কাছে কী গেছে</h2>') && !preg_match($bad, $h), 'site: notifications overview instead of the per-member log');
$h = $render(['tab' => 'feedback', 'fst' => 'all']);
check(str_contains($h, 'জন সদস্য') && str_contains($h, 'ma-inbox-row') && !preg_match($bad, $h), 'site: feedback inbox list');
$h = $render(['tab' => 'feedback', 'who' => (string) $u['id']]);
check(str_contains($h, 'প্রথম মতামত') && str_contains($h, 'দ্বিতীয় মতামত') && str_contains($h, 'দেখছি, ধন্যবাদ!') && str_contains($h, 'ma-chat-sep') && !preg_match($bad, $h), 'site: one member’s inbox');
$h = $render(['tab' => 'feedback', 'fb' => (string) $t1['id']]);
check(str_contains($h, 'দ্বিতীয় মতামত'), 'site: an old link to a conversation opens the member’s inbox');
$h = $render(['tab' => 'finance', 'fk' => 'income']);
check(str_contains($h, 'আয় বা খরচ লিখুন') && str_contains($h, 'ma-fin-add') && str_contains($h, 'হাতে থাকার কথা') && str_contains($h, 'মাস অনুযায়ী') && !preg_match($bad, $h), 'site: হিসাব with month, filters and a pop-up form');
$_GET = [];

echo "\n  — members' backup keys sealed with MA_DATA_KEY (owner's review, 27 Oct)\n";
$h = $render(['tab' => 'security']);
check(str_contains($h, "define('MA_DATA_KEY'") && !preg_match($bad, $h), 'security tab: how to add MA_DATA_KEY');
$rowK = $wpdb->get_row("SELECT * FROM $U WHERE backup_key <> '' AND google_sub NOT LIKE 'pending:%' LIMIT 1", ARRAY_A);
$plainK = $rowK['backup_key'];
check(strlen($plainK) >= 40 && strpos($plainK, 'enc1:') !== 0, 'without MA_DATA_KEY: kept as it was');
define('MA_DATA_KEY', str_repeat('ab', 32));
check(ma_acc_backup_key($rowK) === $plainK, 'with MA_DATA_KEY: the same key comes back');
$stored = $wpdb->get_var($wpdb->prepare("SELECT backup_key FROM $U WHERE id = %d", $rowK['id']));
check(strpos($stored, 'enc1:') === 0 && !str_contains($stored, $plainK), 'and it is now sealed in the database');
$rowK['backup_key'] = $stored;
check(ma_acc_backup_key($rowK) === $plainK, 'sealed: opens to the same key');
check(ma_totp_secret($bossId) === $totp, 'two-step secrets do not depend on MA_DATA_KEY');
$h = $render(['tab' => 'security']);
check(str_contains($h, 'MA_DATA_KEY</code> কখনো বদলাবেন') && !preg_match($bad, $h), 'security tab: the data key is on');

echo $fail ? "\n$fail FAILED\n" : "\nALL OK\n";
