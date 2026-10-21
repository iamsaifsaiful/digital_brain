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
$sent = ['ai' => [], 'fcm' => [], 'mail' => [], 'metal' => []];
add_filter('pre_http_request', function ($pre, $args, $url) use (&$sent) {
    if (str_contains($url, 'tokeninfo')) {
        parse_str(parse_url($url, PHP_URL_QUERY), $q);
        $who = str_starts_with($q['id_token'], 'BOSS') ? ['sub' => 'g-boss', 'email' => 'boss@gmail.com', 'name' => 'Boss'] : ['sub' => 'g-rahim', 'email' => 'rahim@gmail.com', 'name' => 'রহিম উদ্দিন', 'picture' => 'https://lh3.googleusercontent.com/a/abc'];
        $aud = str_contains($q['id_token'], 'WRONGAUD') ? 'other.apps.googleusercontent.com' : 'web-client.apps.googleusercontent.com';
        return ['response' => ['code' => 200], 'body' => wp_json_encode($who + ['iss' => 'https://accounts.google.com', 'aud' => $aud, 'exp' => time() + 600, 'email_verified' => 'true']), 'headers' => [], 'cookies' => []];
    }
    if (str_contains($url, 'api.anthropic.com') && str_contains($args['body'], 'web_search')) {
        $sent['metal'][] = json_decode($args['body'], true);
        return ['response' => ['code' => 200], 'body' => wp_json_encode(['stop_reason' => 'end_turn', 'content' => [['type' => 'text', 'text' => $GLOBALS['metal_reply']]]]), 'headers' => [], 'cookies' => []];
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
[$code, $d] = call('POST', '/admin/login', ['email' => 'BOSS@gmail.com', 'password' => 'long-password-123']);
check($code === 200 && strlen($d['session'] ?? '') === 64 && $d['name'] === 'Boss', 'admin app login with email + password');
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
check(count($sent['mail']) === 1, 'admin emailed');
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
foreach (['members', 'payments', 'notices', 'feedback', 'settings'] as $tab) {
    $_GET = ['page' => 'my-assistant', 'tab' => $tab];
    ob_start();
    ma_acc_admin();
    $html = ob_get_clean();
    file_put_contents(dirname(__FILE__) . "/page-$tab.html", '<!doctype html><meta charset="utf-8"><body style="margin:0;background:#f0f0f1;padding:0 0 0 20px">' . $html);
    check(strlen($html) > 3000 && !preg_match('/(Warning|Notice|Fatal|Deprecated)\b.*on line/', $html), "$tab page renders cleanly (" . strlen($html) . ' bytes)');
}
ob_start();
echo do_shortcode('[my_assistant_payment]');
$form = ob_get_clean();
check(str_contains($form, 'তথ্য জমা দিন') && str_contains($form, 'নগদ'), 'website form shortcode');
$_GET = ['plan' => 'monthly'];
$pro = do_shortcode('[my_assistant_pro]');
file_put_contents(dirname(__FILE__) . '/page-pro.html', '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><body style="margin:0;padding:24px 16px;background:#F6F7F9">' . $pro);
check(str_contains($pro, 'ফ্রি আর প্রো-তে কী কী') && str_contains($pro, 'মাসিক প্রো কিনুন') && str_contains($pro, 'তথ্য জমা দিন'), 'Pro page: features, plans and the form');
check((bool) preg_match('/value="monthly"\s+checked/', $pro), 'the plan chosen above is ticked in the form');
check(!str_contains(do_shortcode('[my_assistant_pro form="no"]'), 'তথ্য জমা দিন'), 'form="no" leaves the form out');
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

echo $fail ? "\n$fail FAILED\n" : "\nALL OK\n";
