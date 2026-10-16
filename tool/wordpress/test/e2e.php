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
foreach (['ma_users', 'ma_sessions', 'ma_ai_usage', 'ma_payments', 'ma_notices', 'ma_feedback'] as $t) {
    check($wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}$t") !== null, "table $t");
}
update_option('ma_acc_google_client_ids', 'web-client.apps.googleusercontent.com');
update_option('ma_ai_on', '1');
update_option('ma_ai_key', 'sk-ant-test-0123456789abcdefghijkl');
update_option('ma_fcm_account', wp_json_encode(['client_email' => 'x@y.iam.gserviceaccount.com', 'project_id' => 'my-assistant', 'private_key' => openssl_pkey_export(openssl_pkey_new(['private_key_bits' => 2048]), $pk) ? $pk : '']));

// Google, Anthropic and Firebase, pretended.
$sent = ['ai' => [], 'fcm' => [], 'mail' => []];
add_filter('pre_http_request', function ($pre, $args, $url) use (&$sent) {
    if (str_contains($url, 'tokeninfo')) {
        parse_str(parse_url($url, PHP_URL_QUERY), $q);
        $who = str_starts_with($q['id_token'], 'BOSS') ? ['sub' => 'g-boss', 'email' => 'boss@gmail.com', 'name' => 'Boss'] : ['sub' => 'g-rahim', 'email' => 'rahim@gmail.com', 'name' => 'রহিম উদ্দিন', 'picture' => 'https://lh3.googleusercontent.com/a/abc'];
        $aud = str_contains($q['id_token'], 'WRONGAUD') ? 'other.apps.googleusercontent.com' : 'web-client.apps.googleusercontent.com';
        return ['response' => ['code' => 200], 'body' => wp_json_encode($who + ['iss' => 'https://accounts.google.com', 'aud' => $aud, 'exp' => time() + 600, 'email_verified' => 'true']), 'headers' => [], 'cookies' => []];
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
check(($d['ai'] ?? null) === true && ($d['ai_left'] ?? 0) === 50, 'AI on, 50 left');
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
check($code === 200 && $d['ai_left'] === 49, '/me: 49 left');
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

echo "\nfeedback\n";
$sent['fcm'] = [];
[$code] = call('POST', '/feedback', ['kind' => 'idea', 'text' => 'ক্যালেন্ডারে চাঁদের ছবি চাই', 'app_version' => '2.15.0']);
check($code === 401, 'feedback needs a member session');
[$code] = call('POST', '/feedback', ['kind' => 'idea', 'text' => 'ক্যালেন্ডারে চাঁদের ছবি চাই', 'app_version' => '2.15.0'], $boss);
check($code === 401, 'an admin session cannot post feedback');
[$code] = call('POST', '/feedback', ['kind' => 'idea', 'text' => 'হুম'], $ses);
check($code === 400, 'too short refused');
[$code, $d] = call('POST', '/feedback', ['kind' => 'problem', 'text' => "রিমাইন্ডার <b>বাজেনি</b>\nদুপুরে", 'app_version' => '2.15.0'], $ses);
check($code === 200 && $d['ok'], 'feedback saved');
$f = $wpdb->get_row("SELECT * FROM {$wpdb->prefix}ma_feedback", ARRAY_A);
check($f && $f['email'] === 'rahim@gmail.com' && $f['kind'] === 'problem' && !str_contains($f['body'], '<b>') && $f['status'] === 'new', 'kept with the member, tags stripped');
check(count($sent['fcm']) === 1 && $sent['fcm'][0]['message']['token'] === 'boss-fcm-token-1234567890', 'admins pushed: ' . ($sent['fcm'][0]['message']['notification']['title'] ?? ''));
[$code, $d] = call('GET', '/admin/feedback', [], $boss);
check($code === 200 && count($d['feedback']) === 1 && $d['new'] === 1 && $d['feedback'][0]['kind_label'] === 'সমস্যা', 'admin app lists it');
[$code] = call('POST', '/admin/feedback/' . $f['id'], ['status' => 'done'], $boss);
[$c2, $d] = call('GET', '/admin/feedback', [], $boss);
check($code === 200 && count($d['feedback']) === 0 && $d['new'] === 0, 'marked done: off the open list');
[$code] = call('GET', '/admin/feedback', [], $ses);
check($code === 403, 'members cannot read feedback');
for ($i = 0; $i < 9; $i++) call('POST', '/feedback', ['kind' => 'idea', 'text' => 'আরও একটা কথা ' . $i], $ses);
[$code] = call('POST', '/feedback', ['kind' => 'idea', 'text' => 'এগারো নম্বর কথা'], $ses);
check($code === 429, 'at most 10 a day from one member');

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
echo $fail ? "\n$fail FAILED\n" : "\nALL OK\n";
