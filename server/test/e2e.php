<?php
define('RH_TEST', true);
// End-to-end check of the Riyal Hisab Server plugin inside a real WordPress (SQLite).
$_SERVER['HTTP_HOST'] = '127.0.0.1:8899';
$_SERVER['REMOTE_ADDR'] = '10.0.0.' . rand(1, 250);
require $argv[1] . '/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';
require_once ABSPATH . 'wp-admin/includes/admin.php';
$fail = 0;
add_action('doing_it_wrong_run', function ($fn, $msg) { echo "  WRONG $fn: " . (new Exception())->getTraceAsString() . "\n"; }, 10, 2);
function check($ok, $what) { global $fail; echo ($ok ? "  ok   " : "  FAIL ") . $what . "\n"; if (!$ok) $fail++; }

$r = activate_plugin('riyal-hisab-server/riyal-hisab-server.php');
check(!is_wp_error($r), 'activates' . (is_wp_error($r) ? ': ' . $r->get_error_message() : ''));
global $wpdb;
foreach (['users', 'sessions', 'records', 'revs', 'photos', 'notes', 'errors'] as $t) {
    check($wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}rh_$t") !== null, "table rh_$t");
}

// Firebase, pretended.
$sent = ['fcm' => []];
add_filter('pre_http_request', function ($pre, $args, $url) use (&$sent) {
    if ($pre !== false) return $pre;
    if (str_contains($url, 'oauth2.googleapis.com/token')) {
        return ['response' => ['code' => 200], 'body' => '{"access_token":"fcm-access"}', 'headers' => [], 'cookies' => []];
    }
    if (str_contains($url, 'fcm.googleapis.com')) {
        $sent['fcm'][] = json_decode($args['body'], true);
        return ['response' => ['code' => 200], 'body' => '{}', 'headers' => [], 'cookies' => []];
    }
    return $pre;
}, 10, 3);
add_filter('wp_redirect', function ($loc) { throw new RuntimeException($loc); });

function call($method, $route, $body = [], $session = null) {
    $req = new WP_REST_Request($method, '/rbh/v1' . $route);
    if ($session) $req->set_header('authorization', 'Bearer ' . $session);
    if ($method === 'GET') { foreach ($body as $k => $v) $req->set_param($k, $v); }
    else { $req->set_header('content-type', 'application/json'); $req->set_body(wp_json_encode($body)); }
    $res = rest_do_request($req);
    return [$res->get_status(), rest_get_server()->response_to_data($res, false)];
}
function admin_post($action, $post) {
    wp_set_current_user(1);
    $_POST = wp_slash($post) + ['action' => $action];
    $_REQUEST = $_POST + ['_wpnonce' => wp_create_nonce($action)];
    try { do_action('admin_post_' . $action); } catch (RuntimeException $e) { $m = $e->getMessage(); return str_starts_with($m, 'download:') ? $m : urldecode($m); }
    return '';
}
function page($tab, $get = []) {
    wp_set_current_user(1);
    $_GET = $get + ['page' => $tab === 'summary' ? 'riyal-hisab' : 'riyal-hisab-' . $tab];
    ob_start();
    rh_page();
    return ob_get_clean();
}

echo "\nhidden\n";
$index = rest_get_server()->get_index(new WP_REST_Request('GET', '/'))->get_data();
check(!in_array('rbh/v1', $index['namespaces'], true) && !isset($index['routes']['/rbh/v1/login']), 'not listed in /wp-json');
[$code, $d] = call('POST', '/login', ['login' => 'nobody', 'password' => 'x']);
check($code === 404 && ($d['code'] ?? '') === 'rest_no_route', 'a wrong login looks like a missing route');
[$code, $d] = call('GET', '/pull', ['since' => 0]);
check($code === 404 && ($d['code'] ?? '') === 'rest_no_route', 'no session: looks like a missing route');
[$code] = call('GET', '/pull', ['since' => 0], str_repeat('a', 64));
check($code === 404, 'a made-up session: missing route');

echo "\nmain admin (server settings)\n";
$loc = admin_post('rh_owner', ['name' => 'সাইফুল', 'login' => '0551 234-567', 'password' => 'short']);
check(str_contains($loc, 't=e'), 'a short password is refused');
$loc = admin_post('rh_owner', ['name' => 'সাইফুল', 'login' => '0551 234-567', 'password' => 'owner-pass-1']);
check(str_contains($loc, 't=o'), 'main admin saved');
check($wpdb->get_var("SELECT login FROM {$wpdb->prefix}rh_users WHERE role='owner'") === '0551234567', 'login kept without spaces');
[$code, $d] = call('POST', '/login', ['login' => '০৫৫১২৩৪৫৬৭', 'password' => 'owner-pass-1', 'device' => 'Pixel']);
check($code === 200 && strlen($d['token'] ?? '') === 64 && $d['user']['role'] === 'owner', 'main admin signs in (Bangla digits too)');
$owner = $d['token'];
check($d['firebase'] === null, 'no Firebase yet: push off');
$svc = ['project_info' => ['project_number' => '123', 'project_id' => 'shop-1'], 'client' => [['client_info' => ['mobilesdk_app_id' => '1:123:android:abc', 'android_client_info' => ['package_name' => 'com.iamsaifsaiful.riyal_hisab']], 'api_key' => [['current_key' => 'AIzaKEY']]]]];
openssl_pkey_export(openssl_pkey_new(['private_key_bits' => 2048]), $pk);
$loc = admin_post('rh_firebase', ['services' => wp_json_encode($svc), 'account' => wp_json_encode(['client_email' => 'x@y.iam.gserviceaccount.com', 'project_id' => 'shop-1', 'private_key' => $pk])]);
check(str_contains($loc, 't=o'), 'Firebase saved');
[$code, $d] = call('GET', '/me', [], $owner);
check(($d['firebase']['appId'] ?? '') === '1:123:android:abc' && $d['firebase']['senderId'] === '123', 'the app gets the Firebase settings');
call('POST', '/device', ['token' => 'owner-phone-token-0123456789'], $owner);

echo "\nsync\n";
$agent = ['id' => 'ag1', 'name' => 'মনোয়ারা স্টোর', 'whatsapp' => '01811111111', 'commission' => 4, 'created' => '2026-11-01T10:00:00.000', 'channel' => 'app'];
$cust = ['id' => 'c1', 'name' => 'করিম মিয়া', 'phone' => '0551234567', 'created' => '2026-11-01T10:00:00.000', 'recipients' => []];
$old = ['id' => 't0', 'no' => 1001, 'customerId' => 'c1', 'agentId' => 'ag1', 'number' => '01812345900', 'method' => 'bkash', 'kind' => 'send', 'sar' => 300, 'rate' => 32.5, 'taka' => 9750, 'fee' => 0, 'pay' => 'cash', 'sarPaid' => 300, 'at' => '2026-10-20T20:00:00.000', 'status' => 'sent', 'trxId' => 'OLD1234567'];
[$code, $d] = call('POST', '/push', ['records' => [['kind' => 'agent', 'rid' => 'ag1', 'data' => $agent], ['kind' => 'customer', 'rid' => 'c1', 'data' => $cust], ['kind' => 'txn', 'rid' => 't0', 'data' => $old], ['kind' => 'bogus', 'rid' => 'x', 'data' => []]]], $owner);
check($code === 200 && $d['saved'] === 3, 'records saved, unknown kinds skipped');
[$code, $d] = call('POST', '/reserve', ['count' => 3], $owner);
check($code === 200 && count($d['numbers']) === 3 && min($d['numbers']) > 1001 && count(array_unique($d['numbers'])) === 3, 'send numbers: after the existing ones, never twice');
[, $d2] = call('POST', '/reserve', ['count' => 2], $owner);
check(min($d2['numbers']) > max($d['numbers']), 'the next block follows');
[, $d3] = call('POST', '/reserve', ['count' => 2, 'ym' => '2701'], $owner);
check($d3['numbers'] === [27010001, 27010002], 'numbers are year+month+serial: 27010001 is the first in January 2027');
[, $d3] = call('POST', '/reserve', ['count' => 1, 'ym' => '2701'], $owner);
[, $d4] = call('POST', '/reserve', ['count' => 1, 'ym' => '2702'], $owner);
check($d3['numbers'] === [27010003] && $d4['numbers'] === [27020001], 'the serial goes on in a month and starts again in the next');
$no = $d['numbers'][0];

echo "\nusers (from the app)\n";
[$code, $d] = call('POST', '/users', ['role' => 'admin', 'name' => 'রহিম', 'login' => 'rahim', 'password' => 'admin-pass', 'perms' => ['send', 'deposit', 'edit', 'customers', 'agent_pay', 'expense', 'reports', 'users', 'loss', 'bogus']], $owner);
check($code === 200 && $d['user']['role'] === 'admin' && !in_array('agents', $d['user']['perms'], true) && !in_array('bogus', $d['user']['perms'], true) && in_array('users', $d['user']['perms'], true), 'the main admin adds an admin with a checklist');
$rahimId = $d['user']['id'];
[$code] = call('POST', '/users', ['role' => 'owner', 'name' => 'X', 'login' => 'xxxx', 'password' => 'xxxxxx'], $owner);
check($code === 400, 'nobody adds a main admin from the app');
[$code] = call('POST', '/users', ['role' => 'agent', 'name' => 'X', 'login' => 'agentx', 'password' => 'xxxxxx', 'agent_rid' => 'nope'], $owner);
check($code === 400, 'an agent login needs a known agent');
[$code, $d] = call('POST', '/users', ['role' => 'agent', 'name' => 'তন্তু ভাই', 'login' => '01811111111', 'password' => 'agent-pass', 'agent_rid' => 'ag1'], $owner);
check($code === 200, 'an agent login is added');
$agentUser = $d['user']['id'];
[$code] = call('POST', '/users', ['role' => 'admin', 'name' => 'Y', 'login' => 'rahim', 'password' => 'xxxxxx'], $owner);
check($code === 409, 'a login is used once');
[, $d] = call('POST', '/login', ['login' => 'rahim', 'password' => 'admin-pass']);
$admin2 = $d['token'];
[, $d] = call('POST', '/login', ['login' => '01811111111', 'password' => 'agent-pass']);
$agentTok = $d['token'];
check($d['user']['role'] === 'agent' && $d['user']['agent_rid'] === 'ag1', 'the agent signs in');
call('POST', '/device', ['token' => 'agent-phone-token-0123456789'], $agentTok);
[$code] = call('GET', '/pull', ['since' => 0], $agentTok);
check($code === 404, 'an agent cannot pull the full account');
[$code] = call('POST', '/users', ['role' => 'admin', 'name' => 'Z', 'login' => 'zzzz', 'password' => 'zzzzzz'], $agentTok);
check($code === 404, 'an agent cannot add users');
[, $d] = call('GET', '/users', [], $admin2);
check(count($d['users']) === 3 && $d['users'][0]['role'] === 'owner' && count($d['users'][0]['perms']) === 11, 'users listed, main admin first, with everything');
$ownerId = $d['users'][0]['id'];
[$code] = call('POST', '/users/update', ['id' => $ownerId, 'status' => 'off'], $admin2);
check($code === 403, 'the main admin cannot be turned off from the app');

[, $d] = call('POST', '/login', ['login' => 'rahim', 'password' => 'admin-pass']);
check(count($d['user']['perms']) === 9, 'the admin gets their checklist at sign-in');
[$code, $d] = call('POST', '/push', ['records' => [['kind' => 'agent', 'rid' => 'ag2', 'data' => ['id' => 'ag2', 'name' => 'X']]]], $admin2);
check($code === 200 && $d['saved'] === 0 && $d['refused'][0]['rid'] === 'ag2' && !rh_one('agent', 'ag2'), 'without "agents" an admin cannot add an agent');
[$code, $d] = call('POST', '/users', ['role' => 'admin', 'name' => 'করিম', 'login' => 'karim', 'password' => 'karim-pass', 'perms' => ['send', 'settings']], $admin2);
check($code === 200 && $d['user']['perms'] === ['send'], 'an admin gives only what they have');
$karimId = $d['user']['id'];
[, $d] = call('POST', '/login', ['login' => 'karim', 'password' => 'karim-pass']);
$karim = $d['token'];
[$code] = call('POST', '/users', ['role' => 'admin', 'name' => 'Q', 'login' => 'qqqq', 'password' => 'qqqqqq'], $karim);
check($code === 403, 'without "users" no logins can be added');
[, $d] = call('POST', '/push', ['records' => [['kind' => 'deposit', 'rid' => 'dx', 'data' => ['id' => 'dx', 'customerId' => 'c1', 'sar' => 5, 'at' => '2026-11-02T10:00:00']]]], $karim);
check($d['saved'] === 0, 'without "deposit" no deposit');
call('POST', '/users/update', ['id' => $karimId, 'perms' => ['send', 'deposit']], $owner);
[, $d] = call('GET', '/me', [], $karim);
check($d['user']['perms'] === ['send', 'deposit'], 'the checklist changes at once');
call('POST', '/users/update', ['id' => $karimId, 'status' => 'off'], $owner);

echo "\nagent told, agent replies\n";
$sent['fcm'] = [];
$tx = ['id' => 't1', 'no' => $no, 'customerId' => 'c1', 'agentId' => 'ag1', 'recipientLabel' => 'স্ত্রী', 'number' => '01812345901', 'method' => 'bkash', 'kind' => 'send', 'sar' => 500, 'rate' => 32.5, 'taka' => 16250, 'fee' => 200, 'pay' => 'due', 'sarPaid' => 0, 'at' => '2026-11-02T21:40:00.000', 'status' => 'pending', 'trxId' => '', 'agentReply' => ''];
call('POST', '/push', ['records' => [['kind' => 'txn', 'rid' => 't1', 'data' => $tx]]], $admin2);
check(count($sent['fcm']) === 1 && $sent['fcm'][0]['message']['token'] === 'agent-phone-token-0123456789', 'new send: pushed to the agent\'s phone');
$m = $sent['fcm'][0]['message']['notification'];
check(str_contains($m['title'], 'নতুন অনুরোধ') && str_contains($m['body'], '১৬,৪৫০') && !str_contains($m['body'], 'SAR') && !str_contains($m['body'], '500'), 'the notification has taka only');
[, $f] = call('GET', '/agent/feed', [], $agentTok);
$t1 = array_values(array_filter($f['txns'], fn($t) => $t['id'] === 't1'))[0] ?? null;
check($t1 && !isset($t1['sar']) && !isset($t1['rate']) && !isset($t1['customerId']) && !isset($t1['pay']) && $t1['taka'] == 16250, 'agent sees no riyal, rate or customer');
check(!str_contains(wp_json_encode($f), 'করিম') && !str_contains(wp_json_encode($f), '"sar"'), 'nothing about the customer anywhere in the feed');
check($f['owed'] == 9750 + 39 && $f['unread'] === 1, 'agent\'s due with commission, a waiting request not owed yet; one unread notification');
[$code] = call('POST', '/agent/sent', ['id' => 't1'], $agentTok);
check($code === 400, '"sent" needs 3 digits or a TrxID');
$sent['fcm'] = [];
[$code, $d] = call('POST', '/agent/sent', ['id' => 't1', 'tail' => '৬৬৭'], $agentTok);
check($code === 200 && $d['txn']['status'] === 'sent' && $d['txn']['agentReply'] === "$no 16450-667", 'agent: sent, reply in the usual form');
check(rh_agent_owed('ag1') == 9750 + 39 + 16450 + 66, 'once sent, it is owed to the agent');
check(count($sent['fcm']) === 1 && $sent['fcm'][0]['message']['token'] === 'owner-phone-token-0123456789' && str_contains($sent['fcm'][0]['message']['notification']['title'], 'এজেন্ট পাঠিয়েছেন'), 'the admins are told');
[, $p] = call('GET', '/pull', ['since' => 0], $owner);
$recs = $p['records'];
$t1s = array_values(array_filter($recs, fn($r) => $r['rid'] === 't1'));
check(count($t1s) === 1 && $t1s[0]['data']['status'] === 'sent' && $t1s[0]['data']['replyTail'] === '667', 'pull: the send as the agent left it');
check((bool) array_filter($recs, fn($r) => $r['kind'] === 'log' && str_contains($r['data']['title'], 'এজেন্ট পাঠিয়েছেন') && $r['data']['who'] === 'তন্তু ভাই'), 'pull: the log line, by the agent\'s name');
$rev = $p['rev'];
// An admin phone that still had the old copy edits the note: the agent's reply stays.
call('POST', '/push', ['records' => [['kind' => 'txn', 'rid' => 't1', 'data' => ['note' => 'x'] + $tx]]], $admin2);
check(rh_one('txn', 't1')['status'] === 'sent' && rh_one('txn', 't1')['agentReply'] === "$no 16450-667" && rh_one('txn', 't1')['note'] === 'x', 'an older copy does not undo what the agent reported');
[, $p] = call('GET', '/pull', ['since' => $rev], $owner);
check(count($p['records']) === 1 && $p['records'][0]['rid'] === 't1', 'pull since: only what changed');
[$code] = call('POST', '/agent/sent', ['id' => 't0x', 'tail' => '123'], $agentTok);
check($code === 404, 'an agent cannot touch a send that is not theirs');
$sent['fcm'] = [];
[$code] = call('POST', '/agent/problem', ['id' => 't1', 'note' => 'নম্বর বন্ধ'], $agentTok);
check($code === 409 && count($sent['fcm']) === 0, 'no problem on a send already sent');

echo "\nedit, cancel, fault, payment\n";
$tx2 = ['id' => 't2', 'no' => $no + 1, 'number' => '01712000111', 'taka' => 1000] + $tx;
call('POST', '/push', ['records' => [['kind' => 'txn', 'rid' => 't2', 'data' => $tx2]]], $owner);
$sent['fcm'] = [];
call('POST', '/push', ['records' => [['kind' => 'txn', 'rid' => 't2', 'data' => ['taka' => 1500] + $tx2]]], $owner);
check(str_contains($sent['fcm'][0]['message']['notification']['title'] ?? '', 'সংশোধন'), 'edit: agent told');
$sent['fcm'] = [];
call('POST', '/push', ['records' => [['kind' => 'txn', 'rid' => 't2', 'data' => ['taka' => 1500, 'status' => 'cancelled'] + $tx2]]], $owner);
check(str_contains($sent['fcm'][0]['message']['notification']['title'] ?? '', 'বাতিল'), 'cancel: agent told');
[$code] = call('POST', '/agent/sent', ['id' => 't2', 'tail' => '111'], $agentTok);
check($code === 409, 'a cancelled send cannot be marked sent');
$sent['fcm'] = [];
call('POST', '/push', ['records' => [['kind' => 'txn', 'rid' => 't1', 'data' => ['note' => 'x', 'fault' => 'agent', 'faultNote' => 'শেষ সংখ্যা উল্টো'] + rh_one('txn', 't1')]]], $owner);
check(str_contains($sent['fcm'][0]['message']['notification']['title'] ?? '', 'ভুল নম্বরে'), 'wrong number: agent told');
$jpg = base64_encode(random_bytes(300));
[$code] = call('POST', '/photo', ['pid' => 'rc1', 'data' => $jpg], $owner);
check($code === 200, 'receipt photo kept');
$sent['fcm'] = [];
call('POST', '/push', ['records' => [['kind' => 'payment', 'rid' => 'p1', 'data' => ['id' => 'p1', 'agentId' => 'ag1', 'taka' => 20000, 'at' => current_time('Y-m-d\TH:i:s'), 'txnIds' => ['t0'], 'way' => 'bank', 'ref' => 'IBFT5', 'receipt' => 'rc1']]]], $owner);
check(str_contains($sent['fcm'][0]['message']['notification']['title'] ?? '', 'টাকা পেয়েছেন') && str_contains($sent['fcm'][0]['message']['notification']['body'], 'IBFT5'), 'payment: agent told with the reference');
[, $d] = call('GET', '/photo', ['pid' => 'rc1'], $agentTok);
check(($d['data'] ?? '') === $jpg, 'agent sees the receipt of a payment to them');
call('POST', '/photo', ['pid' => 'face1', 'data' => $jpg], $owner);
[$code] = call('GET', '/photo', ['pid' => 'face1'], $agentTok);
check($code === 404, 'agent cannot see other photos (customers)');
[, $f] = call('GET', '/agent/feed', [], $agentTok);
check(($f['owner'] ?? '') === 'সাইফুল', 'the agent sees the main admin\'s name');
check(count($f['payments']) === 1 && $f['payments'][0]['count'] === 1 && $f['unread'] >= 5, 'agent feed: payments and notifications');
[, $n] = call('GET', '/notes', [], $agentTok);
check(count($n['notes']) >= 5 && $n['notes'][0]['title'] !== '', 'agent\'s notification list');
call('POST', '/notes/read', [], $agentTok);
[, $f] = call('GET', '/agent/feed', [], $agentTok);
check($f['unread'] === 0, 'notifications read');

echo "\nper admin: who made it, handover, cash, errors\n";
$shopBefore = rh_cash_in_hand();
call('POST', '/push', ['records' => [['kind' => 'deposit', 'rid' => 'd9', 'data' => ['id' => 'd9', 'customerId' => 'c9', 'sar' => 120, 'at' => '2026-11-02T10:00:00.000', 'way' => 'cash', 'by' => 999, 'byName' => 'ভুয়া']]]], $admin2);
$d9 = rh_one('deposit', 'd9');
check((int) $d9['by'] === (int) $rahimId && $d9['byName'] === 'রহিম', 'the server says who made a record, not the phone');
call('POST', '/push', ['records' => [['kind' => 'deposit', 'rid' => 'd9', 'data' => ['note' => 'x'] + $d9]]], $owner);
check((int) rh_one('deposit', 'd9')['by'] === (int) $rahimId, 'an edit by another admin keeps who made it');
$rahimBefore = rh_cash_in_hand($rahimId);
$ownerBefore = rh_cash_in_hand($ownerId);
$ho = ['id' => 'h1', 'at' => '2026-11-02T18:00:00.000', 'from' => $rahimId, 'fromName' => 'রহিম', 'to' => $ownerId, 'toName' => 'সাইফুল', 'sar' => 50, 'note' => ''];
[, $d] = call('POST', '/push', ['records' => [['kind' => 'handover', 'rid' => 'h1', 'data' => $ho]]], $admin2);
check($d['saved'] === 0 && !rh_one('handover', 'h1'), 'only the one who takes the collection records the handover');
[, $d] = call('POST', '/push', ['records' => [['kind' => 'handover', 'rid' => 'h1', 'data' => $ho]]], $owner);
check($d['saved'] === 1, 'the main admin takes over the collection');
[, $d] = call('POST', '/push', ['records' => [['kind' => 'handover', 'rid' => 'h1', 'data' => ['sar' => 5000] + $ho]]], $owner);
check($d['saved'] === 0 && (float) rh_one('handover', 'h1')['sar'] === 50.0, 'a handover cannot be changed afterwards');
check(abs(rh_cash_in_hand($rahimId) - ($rahimBefore - 50)) < 0.001 && abs(rh_cash_in_hand($ownerId) - ($ownerBefore + 50)) < 0.001, 'handover: out of one hand, into the other');
check(abs(rh_cash_in_hand() - ($shopBefore + 120)) < 0.001, 'the shop total counts the deposit once and the handover not at all');
$html = page('cash', ['by' => (string) $rahimId]);
check(str_contains($html, 'সাইফুল-কে দিলাম') && str_contains($html, '১২০'), 'cash page: one admin\'s lines with the handover');
$html = page('cash');
check(str_contains($html, 'সাইফুল-এর মোট হিসাবে হাতে থাকা উচিত') && str_contains($html, 'রহিম') && !str_contains($html, 'দোকান'), 'cash page: every admin and the total, named after the main admin');
$html = page('txns', ['by' => (string) $rahimId]);
check(str_contains($html, '#' . rh_bn($no)) && !str_contains($html, '#১০০১<'), 'txns: filter by admin, with the admin\'s name');
call('POST', '/push', ['records' => [['kind' => 'payment', 'rid' => 'p9', 'data' => ['id' => 'p9', 'agentId' => 'ag1', 'taka' => 3250, 'sar' => 100.5, 'at' => '2026-11-02T19:00:00.000', 'txnIds' => [], 'way' => 'cash']]]], $owner);
check(str_contains(page('payments'), '১০০.৫'), 'payments: the riyal it cost');
[$code, $d] = call('POST', '/errors', ['errors' => [['at' => '2026-11-02T20:00:00.000', 'where' => 'sync', 'message' => 'SocketException: boom', 'stack' => "#0 main\n#1 x", 'version' => '1.2.0', 'platform' => 'android'], 'junk']], $admin2);
check($code === 200 && $d['saved'] === 1, 'the app sends its problems');
[$code] = call('POST', '/errors', ['errors' => [['message' => 'agent side']]], $agentTok);
[$code2] = call('POST', '/errors', ['errors' => [['message' => 'nobody']]]);
check($code === 200 && $code2 === 404, 'agents can send problems too; without a session nothing');
$html = page('errors', ['user' => (string) $rahimId]);
check(str_contains($html, 'SocketException: boom') && !str_contains($html, 'agent side') && str_contains($html, 'রহিম'), 'problem log page with filter');
$set = ['ownerName' => 'সাইফুল', 'templates' => ['cust_due' => 'ভাই {নাম}, {বকেয়া} রিয়াল বকেয়া।']];
call('POST', '/push', ['records' => [['kind' => 'settings', 'rid' => 'main', 'data' => $set]]], $owner);
[, $d] = call('GET', '/pull', ['since' => 0], $admin2);
$got = array_values(array_filter($d['records'], fn($r) => $r['kind'] === 'settings'));
check(($got[0]['data']['templates']['cust_due'] ?? '') === 'ভাই {নাম}, {বকেয়া} রিয়াল বকেয়া।', 'message templates reach the other admins');

echo "\ndeleting an agent and a login (main admin only)\n";
call('POST', '/push', ['records' => [['kind' => 'agent', 'rid' => 'ag3', 'data' => ['id' => 'ag3', 'name' => 'পুরনো এজেন্ট', 'whatsapp' => '01733333333', 'created' => '2026-11-01T10:00:00.000']]]], $owner);
[$code, $d] = call('POST', '/users', ['role' => 'agent', 'name' => 'পুরনো', 'login' => 'old-agent', 'password' => 'agent-pass', 'agent_rid' => 'ag3'], $owner);
$oldLogin = $d['user']['id'];
[, $d] = call('POST', '/users', ['role' => 'agent', 'name' => 'পুরনো ২', 'login' => 'old-agent2', 'password' => 'agent-pass', 'agent_rid' => 'ag3'], $owner);
[$code] = call('POST', '/users/delete', ['id' => $oldLogin], $admin2);
check($code === 403 && $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM {$wpdb->prefix}rh_users WHERE id = %d", $oldLogin)) == 1, 'another admin cannot delete a login');
[$code] = call('POST', '/users/delete', ['id' => $ownerId], $owner);
check($code === 400, 'the main admin\'s own login cannot be deleted');
[$code] = call('POST', '/users/delete', ['id' => $oldLogin], $owner);
check($code === 200 && $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM {$wpdb->prefix}rh_users WHERE id = %d", $oldLogin)) == 0, 'the main admin deletes an agent\'s login');
$ag3 = rh_one('agent', 'ag3');
[, $d] = call('POST', '/push', ['records' => [['kind' => 'agent', 'rid' => 'ag3', 'data' => ['deleted' => true] + $ag3]]], $admin2);
check($d['saved'] === 0 && empty(rh_one('agent', 'ag3')['deleted']), 'another admin cannot delete an agent');
[, $d] = call('POST', '/push', ['records' => [['kind' => 'agent', 'rid' => 'ag3', 'data' => ['deleted' => true] + $ag3]]], $owner);
check($d['saved'] === 1 && !empty(rh_one('agent', 'ag3')['deleted']) && $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}rh_users WHERE agent_rid = 'ag3'") == 0, 'the main admin deletes an agent: all its logins go too');
[$code] = call('POST', '/login', ['login' => 'old-agent2', 'password' => 'agent-pass']);
check($code === 404, 'a deleted agent cannot sign in');
[$code] = call('POST', '/users', ['role' => 'agent', 'name' => 'X', 'login' => 'old-agent3', 'password' => 'agent-pass', 'agent_rid' => 'ag3'], $owner);
check($code === 400, 'no new login for a deleted agent');
[, $d] = call('POST', '/push', ['records' => [['kind' => 'agent', 'rid' => 'ag3', 'data' => $ag3]]], $owner);
check($d['saved'] === 0, 'a deleted agent stays deleted');

echo "\nsent sends are locked; অতিরিক্ত হিসাব\n";
$t0 = rh_one('txn', 't0');
[, $d] = call('POST', '/push', ['records' => [['kind' => 'txn', 'rid' => 't0', 'data' => ['sar' => 999] + $t0]]], $owner);
check($d['saved'] === 0 && (float) rh_one('txn', 't0')['sar'] === 300.0, 'a sent send cannot be changed, not even by the main admin');
[, $d] = call('POST', '/push', ['records' => [['kind' => 'txn', 'rid' => 't0', 'data' => ['fault' => 'mine', 'faultNote' => 'x'] + $t0]]], $owner);
check($d['saved'] === 1, 'a wrong-number mark still can be set');
$dueBefore = rh_customer_due('c1');
$owedBefore = rh_agent_owed('ag1');
$adj = ['id' => 'a1', 'at' => '2026-11-02T20:30:00.000', 'txnId' => 't0', 'customerId' => 'c1', 'agentId' => 'ag1', 'sarDue' => 50, 'sarCash' => 0, 'takaAgent' => 1625, 'note' => 'রিয়াল কম লিখেছিলাম', 'applied' => false];
[, $d] = call('POST', '/push', ['records' => [['kind' => 'adjust', 'rid' => 'a1', 'data' => $adj]]], $admin2);
check($d['saved'] === 1 && rh_customer_due('c1') == $dueBefore && rh_agent_owed('ag1') == $owedBefore, 'অতিরিক্ত হিসাব is kept apart: no account changes');
[, $d] = call('POST', '/push', ['records' => [['kind' => 'adjust', 'rid' => 'a1', 'data' => ['sarDue' => 5000, 'applied' => true] + $adj]]], $owner);
check($d['saved'] === 0, 'its amounts cannot be changed afterwards');
[, $d] = call('POST', '/push', ['records' => [['kind' => 'adjust', 'rid' => 'a1', 'data' => ['applied' => true, 'appliedAt' => '2026-11-02T21:00:00.000', 'appliedByName' => 'সাইফুল'] + $adj]]], $owner);
check($d['saved'] === 1 && rh_customer_due('c1') == $dueBefore + 50 && rh_agent_owed('ag1') == $owedBefore + 1625 && (int) rh_one('adjust', 'a1')['by'] === (int) $rahimId, 'added to the main account: due and agent change, who wrote it is kept');
[, $d] = call('POST', '/push', ['records' => [['kind' => 'adjust', 'rid' => 'a1', 'data' => ['applied' => false] + $adj]]], $owner);
check($d['saved'] === 0 && !empty(rh_one('adjust', 'a1')['applied']), 'once added it stays added');
$html = page('adjusts');
check(str_contains($html, 'রিয়াল কম লিখেছিলাম') && str_contains($html, 'মূল হিসাবে যোগ হয়েছে') && str_contains($html, '+৫০'), 'অতিরিক্ত হিসাব page');
// An admin's mistake: written by the main admin, the riyal goes into রহিম's hand.
$rBefore = rh_cash_in_hand($rahimId);
$oBefore = rh_cash_in_hand($ownerId);
$adj2 = ['id' => 'a2', 'at' => '2026-11-02T20:35:00.000', 'txnId' => 't0', 'customerId' => 'c1', 'agentId' => 'ag1', 'sarDue' => 0, 'sarCash' => 20, 'takaAgent' => 0, 'note' => '', 'what' => 'rate', 'who' => 'admin', 'handBy' => (int) $rahimId, 'handByName' => 'রহিম', 'applied' => false];
call('POST', '/push', ['records' => [['kind' => 'adjust', 'rid' => 'a2', 'data' => $adj2]]], $owner);
[, $d] = call('POST', '/push', ['records' => [['kind' => 'adjust', 'rid' => 'a2', 'data' => ['applied' => true, 'appliedAt' => '2026-11-02T21:05:00.000', 'appliedByName' => 'সাইফুল'] + $adj2]]], $owner);
check($d['saved'] === 1 && abs(rh_cash_in_hand($rahimId) - ($rBefore + 20)) < 0.001 && abs(rh_cash_in_hand($ownerId) - $oBefore) < 0.001, 'an admin\'s mistake goes into that admin\'s hand, not the writer\'s');
$html = page('adjusts');
check(str_contains($html, 'রেট ভুল হয়েছিল') && str_contains($html, 'এডমিনের ভুল (রহিম)'), 'what went wrong and whose mistake on the page');
call('POST', '/push', ['records' => [['kind' => 'txn', 'rid' => 'tw', 'data' => ['id' => 'tw', 'no' => 27010009, 'customerId' => '', 'walkIn' => 'রাস্তার ভাই', 'walkInPhone' => '0559999999', 'agentId' => 'ag1', 'number' => '01812345999', 'method' => 'bkash', 'kind' => 'send', 'sar' => 100, 'rate' => 32.5, 'taka' => 3250, 'fee' => 0, 'pay' => 'cash', 'sarPaid' => 100, 'at' => '2026-11-02T20:40:00.000', 'status' => 'pending']]]], $owner);
$html = page('txns', ['q' => 'রাস্তার']);
check(str_contains($html, 'রাস্তার ভাই') && str_contains($html, '#২৭০১০০০৯'), 'a send without a profile shows its typed name');

echo "\nthe main admin's own name and password\n";
[$code] = call('POST', '/me/name', ['name' => 'সাইফুল ইসলাম'], $owner);
check($code === 200 && $wpdb->get_var($wpdb->prepare("SELECT name FROM {$wpdb->prefix}rh_users WHERE id = %d", $ownerId)) === 'সাইফুল ইসলাম', 'the main admin renames themself from the app');
[$code] = call('POST', '/me/name', ['name' => ''], $owner);
check($code === 400, 'an empty name is refused');
[$code] = call('POST', '/me/name', ['name' => 'X'], $agentTok);
check($code === 404, 'an agent cannot use it');
[$code] = call('POST', '/password', ['old' => 'owner-pass-1', 'new' => 'owner-pass-2'], $owner);
[$code2] = call('POST', '/login', ['login' => '0551234567', 'password' => 'owner-pass-2']);
check($code === 200 && $code2 === 200, 'the main admin changes their own password and signs in with it');
call('POST', '/me/name', ['name' => 'সাইফুল'], $owner);

echo "\nturning off, passwords\n";
[$code] = call('POST', '/password', ['old' => 'wrong', 'new' => 'newpass1'], $admin2);
check($code === 403, 'own password: the old one is needed');
[$code] = call('POST', '/password', ['old' => 'admin-pass', 'new' => 'newpass1'], $admin2);
check($code === 200, 'own password changed');
[$code] = call('POST', '/login', ['login' => 'rahim', 'password' => 'newpass1']);
check($code === 200, 'signs in with the new password');
[$code] = call('POST', '/users/update', ['id' => $agentUser, 'status' => 'off'], $owner);
check($code === 200, 'an admin turns an agent login off');
[$code] = call('GET', '/agent/feed', [], $agentTok);
check($code === 404, 'that agent is signed out at once');
[$code] = call('POST', '/login', ['login' => '01811111111', 'password' => 'agent-pass']);
check($code === 404, 'and cannot sign in');
call('POST', '/logout', [], $admin2);
[$code] = call('GET', '/pull', ['since' => 0], $admin2);
check($code === 404, 'signed out');
$rahimBal = rh_cash_in_hand($rahimId);
$ownerBal = rh_cash_in_hand($ownerId);
$total = rh_cash_in_hand();
[$code] = call('POST', '/users/update', ['id' => $rahimId, 'status' => 'off'], $owner);
$auto = array_values(array_filter(rh_all('handover'), fn($x) => !empty($x['auto'])));
check($code === 200 && count($auto) === 1 && (int) $auto[0]['from'] === (int) $rahimId && abs((float) $auto[0]['sar'] - $rahimBal) < 0.001, 'an admin turned off: their riyal goes to the main admin');
check(abs(rh_cash_in_hand($rahimId)) < 0.001 && abs(rh_cash_in_hand($ownerId) - ($ownerBal + $rahimBal)) < 0.001 && abs(rh_cash_in_hand() - $total) < 0.001, 'his hand is empty, the main admin\'s grew, the total stayed');
check((int) rh_one('deposit', 'd9')['by'] === (int) $rahimId && rh_one('deposit', 'd9')['byName'] === 'রহিম', 'his records keep his name');

echo "\nrecord pages\n";
call('POST', '/push', ['records' => [
    ['kind' => 'deposit', 'rid' => 'd1', 'data' => ['id' => 'd1', 'customerId' => 'c1', 'sar' => 200, 'at' => '2026-11-02T22:00:00.000', 'way' => 'cash']],
    ['kind' => 'loss', 'rid' => 'l1', 'data' => ['id' => 'l1', 'customerId' => 'c1', 'sar' => 100, 'at' => '2026-11-02T22:10:00.000', 'note' => 'চলে গেছেন']],
    ['kind' => 'expense', 'rid' => 'e1', 'data' => ['id' => 'e1', 'category' => 'যাতায়াত', 'sar' => 15, 'at' => '2026-11-02T12:00:00.000']],
    ['kind' => 'close', 'rid' => 'k1', 'data' => ['id' => 'k1', 'at' => '2026-11-02T23:00:00.000', 'expected' => 485, 'counted' => 480]],
]], $owner);
check(rh_customer_due('c1') == 500 - 200 - 100 + 50, 'customer due: sends − deposits − losses + added corrections');
foreach (array_keys(rh_tabs()) as $tab) {
    $html = page($tab);
    check(str_contains($html, 'rh-tabs') && !str_contains($html, 'Warning') && !str_contains($html, 'Fatal'), "page: $tab");
}
$html = page('txns', ['status' => 'fault']);
check(str_contains($html, '#' . rh_bn($no)) && !str_contains($html, '#' . rh_bn($no + 1)), 'txns: filter by wrong number');
$html = page('txns', ['from' => '2026-10-01', 'to' => '2026-10-31']);
check(str_contains($html, '#১০০১') && !str_contains($html, '#' . rh_bn($no)), 'txns: filter by dates');
$html = page('txns', ['q' => '345901']);
check(str_contains($html, '#' . rh_bn($no)) && !str_contains($html, '#১০০১<'), 'txns: search by number');
$html = page('customers', ['due' => 'yes']);
check(str_contains($html, 'করিম মিয়া') && str_contains($html, '২৫০'), 'customers: due shown');
$html = page('payments');
check(str_contains($html, 'IBFT5') && str_contains($html, 'data:image/jpeg;base64'), 'payments: reference and receipt');
$html = page('log', ['who' => 'তন্তু ভাই']);
check(str_contains($html, 'এজেন্ট পাঠিয়েছেন') && !str_contains($html, 'লগইন বদল'), 'log: filter by who');
$html = page('closes', ['diff' => 'no']);
check(str_contains($html, '-৫'), 'day close: difference shown');
$html = page('summary');
check(str_contains($html, 'লস') && str_contains($html, 'মনোয়ারা স্টোর'), 'summary');

echo "\nall records, PDF, backups\n";
$html = page('notes', ['user' => (string) $agentUser]);
check(str_contains($html, 'নতুন অনুরোধ') && str_contains($html, 'টাকা পেয়েছেন'), 'notifications: every one, filter by who got it');
$html = page('customers', ['view' => 'c1']);
check(str_contains($html, 'রিয়াল জমা') && str_contains($html, 'লস — আদায় হবে না') && str_contains($html, 'print=1'), 'one customer: the whole account, with a PDF link');
update_option('gmt_offset', 0);
$_GET = ['page' => 'riyal-hisab-txns', 'print' => '1', 'status' => 'fault'];
$printed = rh_print_page('txns');
check(str_contains($printed, 'window.print()') && str_contains($printed, 'রেমিট খাতা — লেনদেন') && !str_contains($printed, 'class="rh-tabs"') && str_contains($printed, '#' . rh_bn($no)), 'PDF / print: the filtered list on a clean page');
foreach (array_keys(rh_tabs()) as $tab) {
    if (in_array($tab, ['settings', 'backup'], true)) continue;
    $_GET = ['page' => 'riyal-hisab-' . $tab, 'print' => '1'];
    $p = rh_print_page($tab);
    check(str_contains($p, '</html>') && !str_contains($p, 'Warning'), "print: $tab");
}
$loc = admin_post('rh_backup_download', ['password' => 'backup-pass-1']);
check(str_starts_with($loc, 'download:'), 'backup downloads');
$file = base64_decode(substr($loc, 9));
function rh_open_backup($file, $pass) {
    $salt = substr($file, 7, 16);
    $iter = unpack('N', substr($file, 23, 4))[1];
    $box = substr($file, 27);
    $key = hash_pbkdf2('sha256', $pass, $salt, $iter, 32, true);
    $clear = openssl_decrypt(substr($box, 12, -16), 'aes-256-gcm', $key, OPENSSL_RAW_DATA, substr($box, 0, 12), substr($box, -16));
    return $clear === false ? null : json_decode($clear, true);
}
$j = rh_open_backup($file, 'backup-pass-1');
check(str_starts_with($file, 'RHSBBK1') && $j && count($j['data']['txns']) === 4 && count($j['data']['handovers']) >= 1 && count($j['data']['adjusts']) === 2 && $j['data']['customers'][0]['name'] === 'করিম মিয়া' && isset($j['photos']['rc1']), 'the backup holds the whole account and photos, in the app\'s format');
check(rh_open_backup($file, 'wrong-pass') === null, 'useless without its password');
if (getenv('RH_BACKUP_OUT')) file_put_contents(getenv('RH_BACKUP_OUT'), $file);

echo "\nGoogle Drive\n";
$drive = [];
add_filter('pre_http_request', function ($pre, $args, $url) use (&$drive) {
    if (str_contains($url, 'oauth2.googleapis.com/token') && ($args['body']['grant_type'] ?? '') === 'authorization_code') {
        $claims = rtrim(strtr(base64_encode(wp_json_encode(['email' => 'shop@gmail.com'])), '+/', '-_'), '=');
        return ['response' => ['code' => 200], 'body' => wp_json_encode(['access_token' => 'a', 'refresh_token' => 'REFRESH1', 'id_token' => "h.$claims.s"]), 'headers' => [], 'cookies' => []];
    }
    if (str_contains($url, 'oauth2.googleapis.com/token') && ($args['body']['grant_type'] ?? '') === 'refresh_token') {
        return ['response' => ['code' => 200], 'body' => wp_json_encode(['access_token' => 'drive-access']), 'headers' => [], 'cookies' => []];
    }
    if (str_contains($url, 'googleapis.com/drive') || str_contains($url, 'googleapis.com/upload/drive')) {
        $drive[] = [$args['method'] ?? 'GET', $url, $args['body'] ?? '', $args['headers'] ?? []];
        if (str_contains($url, 'upload/drive')) return ['response' => ['code' => 200], 'body' => '{"id":"file1"}', 'headers' => [], 'cookies' => []];
        if (($args['method'] ?? '') === 'POST') return ['response' => ['code' => 200], 'body' => '{"id":"folder1"}', 'headers' => [], 'cookies' => []];
        if (str_contains($url, 'files?')) return ['response' => ['code' => 200], 'body' => wp_json_encode(['files' => array_map(fn($i) => ['id' => "old$i", 'name' => "x$i", 'createdTime' => $i === 4 ? gmdate('c', time() - 5 * DAY_IN_SECONDS) : '2020-01-01T00:00:00Z'], range(1, 5))]), 'headers' => [], 'cookies' => []];
        return ['response' => ['code' => 200], 'body' => '{}', 'headers' => [], 'cookies' => []];
    }
    return $pre;
}, 5, 3);
$loc = admin_post('rh_gdrive_save', ['client_id' => 'cid.apps.googleusercontent.com', 'client_secret' => 'sec', 'password' => 'drive-pass-1', 'keep' => '3']);
check(str_contains($loc, 't=o') && get_option('rh_gd_client_secret') !== 'sec' && str_starts_with(get_option('rh_gd_password'), 'enc1:'), 'Drive settings kept, secrets locked');
$loc = admin_post('rh_gdrive_connect', []);
check(str_contains($loc, 'accounts.google.com') && str_contains($loc, 'drive.file') && str_contains($loc, 'access_type=offline'), 'connect: sent to Google');
parse_str(parse_url($loc, PHP_URL_QUERY), $q);
$_GET = ['state' => $q['state'], 'code' => 'CODE'];
try { do_action('admin_post_rh_gdrive_cb'); } catch (RuntimeException $e) { $loc = urldecode($e->getMessage()); }
check(str_contains($loc, 't=o') && rh_gd_state()['refresh'] === 'REFRESH1' && get_option('rh_gd_email') === 'shop@gmail.com', 'Google answered: connected');
check(rh_gd_run() === true, 'backup to Drive');
$up = array_values(array_filter($drive, fn($d) => str_contains($d[1], 'upload/drive')))[0] ?? null;
check($up && str_contains($up[2], 'RHSBBK1') && str_contains($up[2], 'folder1') && !str_contains($up[2], 'করিম'), 'uploaded: a locked file in the backup folder, nothing readable');
$patched = array_values(array_filter($drive, fn($d) => $d[0] === 'PATCH'));
check(count($patched) === 1 && str_contains($patched[0][1], 'old5'), 'only the newest 3 kept, but never one younger than 30 days');
check(wp_next_scheduled('rh_gd_daily') !== false, 'daily backup scheduled');

echo "\nagent's problem\n";
$t7 = ['id' => 't7', 'no' => 27110077, 'customerId' => 'c1', 'agentId' => 'ag1', 'number' => '01812345977', 'method' => 'bkash', 'kind' => 'send', 'sar' => 100, 'rate' => 32.5, 'taka' => 3250, 'fee' => 0, 'pay' => 'cash', 'sarPaid' => 100, 'at' => '2026-11-04T10:00:00.000', 'status' => 'pending'];
call('POST', '/users/update', ['id' => $agentUser, 'status' => 'active'], $owner);
[, $d] = call('POST', '/login', ['login' => '01811111111', 'password' => 'agent-pass']);
$agentTok = $d['token'];
call('POST', '/device', ['token' => 'agent-phone-token-0123456789'], $agentTok);
call('POST', '/push', ['records' => [['kind' => 'txn', 'rid' => 't7', 'data' => $t7]]], $owner);
$sent['fcm'] = [];
[$code] = call('POST', '/agent/problem', ['id' => 't7', 'note' => 'নম্বর বন্ধ'], $agentTok);
check(count($sent['fcm']) >= 1 && str_contains($sent['fcm'][0]['message']['notification']['body'], 'নম্বর বন্ধ'), 'problem: admins told');
$p7 = rh_one('txn', 't7');
check($code === 200 && $p7['problem'] === 'নম্বর বন্ধ' && ($p7['problemAt'] ?? '') !== '' && rh_has_problem($p7), 'the problem is kept on the send');
[, $f] = call('GET', '/agent/feed', [], $agentTok);
$f7 = array_values(array_filter($f['txns'], fn($t) => $t['id'] === 't7'))[0];
check($f7['problem'] === 'নম্বর বন্ধ', 'the agent sees it under problems');
call('POST', '/push', ['records' => [['kind' => 'txn', 'rid' => 't7', 'data' => ['note' => 'x'] + $t7]]], $owner);
check(rh_has_problem(rh_one('txn', 't7')), 'a phone with an old copy cannot clear it');
call('POST', '/push', ['records' => [['kind' => 'txn', 'rid' => 't7', 'data' => ['problemSolved' => 'not-the-stamp'] + rh_one('txn', 't7')]]], $owner);
check(rh_has_problem(rh_one('txn', 't7')), 'nor a wrong stamp');
$sent['fcm'] = [];
call('POST', '/push', ['records' => [['kind' => 'txn', 'rid' => 't7', 'data' => ['problemSolved' => $p7['problemAt']] + rh_one('txn', 't7')]]], $owner);
check(!rh_has_problem(rh_one('txn', 't7')) && count($sent['fcm']) === 1 && str_contains($sent['fcm'][0]['message']['notification']['title'], 'আবার অনুরোধ'), 'asked again: solved, the agent is told');
[, $f] = call('GET', '/agent/feed', [], $agentTok);
$f7 = array_values(array_filter($f['txns'], fn($t) => $t['id'] === 't7'))[0];
check($f7['problem'] === '' && $f7['status'] === 'pending', 'and it is a request again');
[$code] = call('POST', '/agent/problem', ['id' => 't0'], $agentTok);
check($code === 409, 'no problem on a send already sent (t0)');
call('POST', '/push', ['records' => [['kind' => 'txn', 'rid' => 't7', 'data' => ['status' => 'cancelled'] + rh_one('txn', 't7')]]], $owner);

echo "\ncustomer profile deleted\n";
[, $d] = call('POST', '/push', ['records' => [['kind' => 'customer', 'rid' => 'c1', 'data' => ['deleted' => true] + rh_one('customer', 'c1')]]], $owner);
check($d['saved'] === 0 && empty(rh_one('customer', 'c1')['deleted']), 'a customer who owes cannot be deleted');
$c5 = ['id' => 'c5', 'name' => 'পুরনো ভাই', 'phone' => '0557777777', 'created' => '2026-11-01T10:00:00.000', 'recipients' => []];
call('POST', '/push', ['records' => [['kind' => 'customer', 'rid' => 'c5', 'data' => $c5]]], $owner);
[, $d] = call('POST', '/push', ['records' => [['kind' => 'customer', 'rid' => 'c5', 'data' => ['deleted' => true] + $c5]]], $owner);
check($d['saved'] === 1 && !empty(rh_one('customer', 'c5')['deleted']), 'nothing owed: the profile is deleted');
[, $d] = call('POST', '/push', ['records' => [['kind' => 'customer', 'rid' => 'c5', 'data' => $c5]]], $owner);
check($d['saved'] === 0 && !empty(rh_one('customer', 'c5')['deleted']), 'and stays deleted');
check(str_contains(page('customers', ['q' => 'পুরনো']), 'ডিলিট'), 'marked in the customers menu');

echo "\nreset: backup, keep, then everything goes\n";
global $wpdb;
$txnsBefore = count(rh_all('txn'));
$custBefore = count(rh_all('customer'));
[$code] = call('POST', '/reset', ['password' => 'owner-pass-2'], $agentTok);
check($code === 404 && count(rh_all('txn')) === $txnsBefore, 'only the main admin can reset');
[$code] = call('POST', '/reset', ['password' => 'wrong-pass'], $owner);
check($code === 403 && count(rh_all('txn')) === $txnsBefore, 'a wrong password: nothing happens');
$uploadsBefore = count(array_filter($drive, fn($d) => str_contains($d[1], 'upload/drive')));
[$code, $d] = call('POST', '/reset', ['password' => 'owner-pass-2'], $owner);
check($code === 200 && $d['ok'] === true && $d['counts']['txn'] === $txnsBefore && $d['logins'] >= 1, 'reset done');
$file = base64_decode($d['backup']);
$j = rh_open_backup($file, 'owner-pass-2');
check($j && count($j['data']['txns']) === $txnsBefore && count($j['data']['customers']) === $custBefore, 'the backup it gave opens with the main admin\'s password and holds everything');
check(count(array_filter($drive, fn($d) => str_contains($d[1], 'upload/drive'))) === $uploadsBefore + 1 && $d['drive'] === 'ok', 'a copy went to Google Drive too');
$arc = $wpdb->get_row('SELECT * FROM ' . rh_t('archives') . ' ORDER BY id DESC LIMIT 1', ARRAY_A);
check($arc && (int) $arc['id'] === (int) $d['archive'] && base64_decode($arc['backup']) === $file && str_contains($arc['data'], 'করিম মিয়া') && str_contains($arc['users'], 'rahim'), 'kept on the server: the backup, every record and every login');
check(count(rh_all('txn')) === 0 && count(rh_all('customer')) === 0 && count(rh_all('agent')) === 0 && !rh_all('settings'), 'every record is gone');
check((int) $wpdb->get_var('SELECT COUNT(*) FROM ' . rh_t('photos')) === 0 && (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . rh_t('notes')) === 0, 'photos and notifications gone');
$left = $wpdb->get_col('SELECT role FROM ' . rh_t('users'));
check($left === ['owner'] && (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . rh_t('sessions')) === 1, 'only the main admin\'s login and this session are left');
$logs = array_values(rh_all('log'));
check(count($logs) === 1 && $logs[0]['title'] === 'সব হিসাব রিসেট' && str_contains($logs[0]['detail'], '#' . rh_bn($d['archive'])), 'the new account starts with one log line about the reset');
[$code] = call('GET', '/agent/feed', [], $agentTok);
check($code === 404, 'the agent\'s login no longer works');
[$code, $p] = call('GET', '/pull', ['since' => 0], $owner);
check($code === 200 && count($p['records']) === 1 && $p['records'][0]['kind'] === 'log', 'the main admin\'s phone gets the empty account');
$html = page('resets');
check(str_contains($html, 'রহিম') && str_contains($html, rh_bn($txnsBefore) . ' লেনদেন'), 'রিসেট menu: what there was and whose logins went');
$loc = admin_post('rh_archive_download', ['id' => (string) $d['archive'], 'what' => 'json']);
check(str_starts_with($loc, 'download:') && str_contains(base64_decode(substr($loc, 9)), 'করিম মিয়া'), 'its records download in plain JSON');
$loc = admin_post('rh_archive_download', ['id' => (string) $d['archive'], 'what' => 'rhb']);
check(base64_decode(substr($loc, 9)) === $file, 'and its backup file');
$loc = admin_post('rh_archive_delete', ['id' => (string) $d['archive']]);
check(str_contains($loc, 't=e') && $wpdb->get_var('SELECT COUNT(*) FROM ' . rh_t('archives')) == 1, 'a reset backup cannot be deleted before 30 days');
check(!str_contains(page('resets'), 'rh_archive_delete') , 'no delete button yet');
$wpdb->update(rh_t('archives'), ['at' => gmdate('Y-m-d H:i:s', time() - 31 * DAY_IN_SECONDS)], ['id' => (int) $d['archive']]);
check(str_contains(page('resets'), 'rh_archive_delete'), 'after 30 days: a delete button');
$loc = admin_post('rh_archive_delete', ['id' => (string) $d['archive']]);
check(str_contains($loc, 't=o') && $wpdb->get_var('SELECT COUNT(*) FROM ' . rh_t('archives')) == 0, 'and it can be deleted');

echo $fail ? "\n$fail FAILED\n" : "\nall passed\n";
exit($fail ? 1 : 0);
