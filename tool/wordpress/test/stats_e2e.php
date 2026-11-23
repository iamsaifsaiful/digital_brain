<?php
// কোম্পানির পরিসংখ্যান (owner, 24 Nov): what the app sends, what the server
// keeps, and the dashboard sections, in a real WordPress (SQLite).
// Run on a fresh install:  php install.php wp && php stats_e2e.php wp [out.html]
$_SERVER['HTTP_HOST'] = '127.0.0.1:8899';
$_SERVER['REMOTE_ADDR'] = '10.0.1.' . rand(1, 250);
require $argv[1] . '/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';
require_once ABSPATH . 'wp-admin/includes/admin.php';
$fail = 0;
function check($ok, $what) { global $fail; echo ($ok ? "  ok   " : "  FAIL ") . $what . "\n"; if (!$ok) $fail++; }
function call($method, $route, $body = [], $session = null) {
    $req = new WP_REST_Request($method, '/my-assistant/v1' . $route);
    if ($session) $req->set_header('authorization', 'Bearer ' . $session);
    $req->set_header('content-type', 'application/json');
    if ($method !== 'GET') $req->set_body(wp_json_encode($body));
    $res = rest_do_request($req);
    $data = rest_get_server()->response_to_data($res, false);
    do_action('ma_test_after_rest');
    return [$res->get_status(), $data];
}

$r = activate_plugin('my-assistant-accounts/my-assistant-accounts.php');
check(!is_wp_error($r), 'activates');
global $wpdb;
foreach (['ma_stats_days', 'ma_stats_dev', 'ma_stats_count'] as $t) {
    check($wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}$t") !== null, "table $t");
}

// ── Members, as if they had been using the app for 45 days ──
mt_srand(7);
$today = ma_st_today();
$U = ma_acc_table();
$ids = [];
$brands = ['samsung', 'samsung', 'samsung', 'xiaomi', 'xiaomi', 'redmi', 'realme', 'oppo', 'vivo', 'infinix', 'tecno', 'motorola'];
$countries = ['BD', 'BD', 'BD', 'BD', 'BD', 'BD', 'BD', 'BD', 'BD', 'SA', 'MY', 'AE', 'GB'];
for ($i = 1; $i <= 140; $i++) {
    $age = mt_rand(0, 44);
    $created = gmdate('Y-m-d H:i:s', strtotime($today . ' 10:00:00 UTC') - ma_acc_tz_off() - $age * DAY_IN_SECONDS);
    $wpdb->insert($U, ['google_sub' => "g-$i", 'email' => "m$i@example.com", 'name' => "সদস্য $i", 'created_at' => $created, 'last_seen' => $created, 'app_version' => ['1.0.14', '1.0.14', '1.0.14', '1.0.13', '1.0.12'][mt_rand(0, 4)], 'edition' => 'play']);
    $id = (int) $wpdb->insert_id;
    $ids[$id] = $age;
    // Stickiness: some stay, most fade.
    $stay = mt_rand(1, 100) <= 40 ? 0.75 : (mt_rand(1, 100) <= 50 ? 0.25 : 0.05);
    $last = null;
    for ($d = $age; $d >= 0; $d--) {
        $p = $d === $age ? 0.95 : $stay;
        if (mt_rand(1, 1000) / 1000 <= $p) {
            $day = ma_st_day_shift($today, -$d);
            $wpdb->insert(ma_use_table(), ['user_id' => $id, 'day' => $day, 'secs' => mt_rand(60, 2400)]);
            $last = $day;
        }
    }
    if ($last) {
        $wpdb->update($U, ['last_seen' => gmdate('Y-m-d H:i:s', strtotime($last . ' 12:00:00 UTC') - ma_acc_tz_off())], ['id' => $id]);
    }
    // Trials and Premium.
    if (mt_rand(1, 100) <= 45) {
        $paid = mt_rand(1, 100) <= 22;
        $kind = $paid ? (mt_rand(0, 1) ? 'web' : 'play') : 'trial';
        $wpdb->update($U, ['trial_started' => $created, 'pro_kind' => $kind, 'pro_until' => gmdate('Y-m-d H:i:s', time() + ($paid ? 200 : (mt_rand(0, 1) ? 3 : -3)) * DAY_IN_SECONDS)], ['id' => $id]);
        if ($paid && $kind === 'web') {
            $wpdb->insert(ma_pay_table(), ['created_at' => $created, 'email' => "m$i@example.com", 'plan' => 'yearly', 'amount' => 999, 'method' => 'bKash', 'trx' => 'T' . $i, 'status' => 'approved', 'reviewed_at' => $created]);
        }
        if ($paid && $kind === 'play') {
            $wpdb->insert(ma_play_table(), ['user_id' => $id, 'product' => mt_rand(0, 2) ? 'pro_monthly' : 'pro_yearly', 'token_hash' => hash('sha256', "t$i"), 'token' => "t$i", 'state' => 'ACTIVE', 'checked_at' => $created]);
        }
    }
}
// Money from Play and ads, written by hand in আয়-ব্যয়ের হিসাব; older web payments.
for ($m = 5; $m >= 0; $m--) {
    $d = gmdate('Y-m-10', strtotime(current_time('Y-m') . '-15 00:00:00 UTC') - $m * 30 * DAY_IN_SECONDS);
    ma_fin_add_entry('income', 'Google Play', 4000 + (5 - $m) * 1500, $d, '', 'test');
    ma_fin_add_entry('income', 'বিজ্ঞাপন', 2500 + (5 - $m) * 700, $d, '', 'test');
    for ($k = 0; $k < 8 + (5 - $m) * 2; $k++) {
        $wpdb->insert(ma_pay_table(), ['created_at' => $d . ' 08:00:00', 'email' => "old$m$k@example.com", 'plan' => 'yearly', 'amount' => 999, 'method' => 'bKash', 'trx' => "O$m$k", 'status' => 'approved', 'reviewed_at' => $d . ' 08:00:00']);
    }
}
// Crashes.
$k = 0;
foreach (array_slice(array_keys($ids), 0, 6) as $id) {
    $wpdb->insert(ma_err_table(), ['sig' => sha1('c' . $k++), 'user_id' => $id, 'level' => 'crash', 'kind' => 'StateError', 'message' => 'x', 'stack' => '', 'app_version' => $k < 4 ? '1.0.13' : '1.0.14', 'hits' => mt_rand(1, 6), 'first_at' => gmdate('Y-m-d H:i:s'), 'last_at' => gmdate('Y-m-d H:i:s')]);
}

echo "\nwhat the app sends\n";
$first = array_key_first($ids);
$ses = ma_ai_new_session($first, 'member');
[$code] = call('POST', '/stats', ['days' => [['d' => $today, 'o' => ['money']]]]);
check($code === 401, 'no session: refused');
[$code] = call('POST', '/stats', ['days' => [['d' => $today, 'o' => ['money']]]], ma_ai_new_session(1, 'admin'));
check($code === 401, 'an admin sign-in is not a member');
[$code, $d] = call('POST', '/stats', [
    'days' => [['d' => $today, 'o' => ['money', 'notes', 'secret-text', 'হিসাব'], 'st' => 1450], ['d' => '1999-01-01', 'o' => ['money']], ['d' => 'bad', 'o' => []]],
    'brand' => 'Samsung<script>', 'android' => 34, 'lang' => 'bn', 'country' => 'bd', 'biz' => true, 'items' => true, 'name' => 'রহিম',
], $ses);
check($code === 200 && ($d['kept'] ?? 0) === 1, 'one good day kept, old and bad days dropped');
$row = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_st_table('days') . ' WHERE user_id = %d', $first), ARRAY_A);
check($row && $row['opens'] === 'money,notes' && (int) $row['start_ms'] === 1450, 'only known part names are kept (no text)');
call('POST', '/stats', ['days' => [['d' => $today, 'o' => ['health'], 'st' => 0]]], $ses);
$row = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_st_table('days') . ' WHERE user_id = %d', $first), ARRAY_A);
check($row['opens'] === 'health,money,notes' && (int) $row['start_ms'] === 1450 && (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . ma_st_table('days')) === 1, 'sent again: the day only grows, still one row');
$dev = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_st_table('dev') . ' WHERE user_id = %d', $first), ARRAY_A);
check($dev && $dev['brand'] === 'samsungscript' && (int) $dev['android'] === 34 && $dev['country'] === 'BD' && $dev['lang'] === 'bn' && (int) $dev['biz'] === 1 && (int) $dev['items'] === 1, 'phone maker, Android, language, country, business mode, kept-anything');
check(!str_contains(wp_json_encode($wpdb->get_results('SELECT * FROM ' . ma_st_table('dev'), ARRAY_A)), 'রহিম'), 'nothing else from the phone is kept');

[$code] = call('POST', '/stats/first-open', []);
call('POST', '/stats/first-open', []);
check($code === 200 && (int) $wpdb->get_var('SELECT n FROM ' . ma_st_table('count') . " WHERE k = 'first_open'") === 2, 'first open counted (no sign-in, nothing about the phone)');
for ($i = 0; $i < 6; $i++) call('POST', '/stats/first-open', []);
check((int) $wpdb->get_var('SELECT n FROM ' . ma_st_table('count') . " WHERE k = 'first_open'") === 5, 'at most 5 first opens a day from one address');

// The rest of the members' phones: parts opened on the days they used the app.
$parts = array_keys(MA_ST_PARTS);
$weight = ['tasks' => 80, 'reminders' => 55, 'money' => 62, 'diary' => 30, 'files' => 22, 'calendar' => 48, 'prayer' => 45, 'health' => 28, 'notes' => 25, 'contacts' => 17, 'passwords' => 12, 'zakat' => 6, 'family' => 9, 'business' => 13, 'voice' => 33];
foreach (array_slice(array_keys($ids), 1) as $id) {
    if (mt_rand(1, 100) > 70) continue; // an older app: sends nothing
    $days = $wpdb->get_col($wpdb->prepare('SELECT day FROM ' . ma_use_table() . ' WHERE user_id = %d AND day >= %s', $id, ma_st_day_shift($today, -14)));
    $b = $brands[mt_rand(0, count($brands) - 1)];
    $slow = in_array($b, ['xiaomi', 'redmi', 'infinix', 'tecno'], true) ? 600 : 0;
    $sdk = [28, 29, 30, 31, 33, 33, 34, 34, 34, 35][mt_rand(0, 9)];
    $send = [];
    foreach ($days as $day) {
        $o = [];
        foreach ($weight as $p => $w) if (mt_rand(1, 100) <= $w) $o[] = $p;
        $send[] = ['d' => $day, 'o' => $o, 'st' => 900 + mt_rand(0, 1600) + $slow + ($sdk <= 29 ? 900 : 0)];
    }
    $s2 = ma_ai_new_session($id, 'member');
    call('POST', '/stats', ['days' => $send, 'brand' => $b, 'android' => $sdk, 'lang' => mt_rand(1, 100) <= 82 ? 'bn' : 'en', 'country' => $countries[mt_rand(0, count($countries) - 1)], 'biz' => mt_rand(1, 100) <= 14, 'items' => mt_rand(1, 100) <= 75], $s2);
    call('GET', '/me', [], $s2);
}
for ($i = 0; $i < 40; $i++) { $_SERVER['REMOTE_ADDR'] = '10.0.2.' . $i; call('POST', '/stats/first-open', []); }
check((int) $wpdb->get_var('SELECT COUNT(*) FROM ' . ma_st_table('count') . " WHERE k LIKE 'srv_me_%'") === 2, 'the server measures how long it takes to answer the app');

echo "\nthe numbers\n";
$v = ma_st_view(30);
$todayUse = (int) $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . ma_use_table() . ' WHERE day = %s AND secs > 0', $today));
check($v['today_n'] === $todayUse && $todayUse > 0, 'today: everyone who used the app today (' . $todayUse . ')');
check(count($v['dau']) === 30 && $v['active'] > 0 && $v['active'] <= 140, 'people a day for 30 days; people in the 30 days');
check($v['mins_avg'] > 0 && array_sum($v['mins_split']) === 100, 'minutes a day, split three ways');
check($v['retention'][1]['pct'] !== null && $v['retention'][7]['pct'] !== null && $v['retention'][30]['n'] >= 0, 'new members coming back: next day, a week, a month');
check($v['parts_people'] > 50 && $v['parts'][0]['label'] === MA_ST_PARTS['tasks'], 'parts opened, the most used first');
check($v['funnel']['signed'] === (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $U WHERE created_at >= %s", gmdate('Y-m-d H:i:s', strtotime($v['from'] . ' 00:00:00 UTC') - ma_acc_tz_off()))) && $v['funnel']['first_open'] >= 40, 'start path: first opens, sign-ins in the 30 days');
check($v['trial_ended'] > 0 && $v['trial_paid'] > 0 && $v['trial_paid'] <= $v['trial_ended'], 'trial to Premium');
check(array_sum($v['plans']) === array_sum($v['pro_from']) && $v['pro_from']['web'] > 0 && $v['pro_from']['play'] > 0, 'Premium now: plan and where from add up');
$rev = end($v['revenue']);
check($rev['web'] > 0 && $rev['play'] === 4000 + 5 * 1500 && $rev['ads'] === 2500 + 5 * 700 && $v['rev_month'] === array_sum($rev), 'money this month: website, Play, ads');
check($v['crash_people'] === 6 && $v['crash_free'] < 100 && $v['crash_free'] > 90, 'crash-free share');
check($v['start_med'] > 900 && $v['start_med'] < 4000 && $v['server_ms'] !== null, 'opening time and server answer time');
check($v['dev_n'] > 50 && $v['lang']['bn'] > $v['lang']['en'] && isset($v['countries']['বাংলাদেশ']), 'phones, language and countries');
check(isset($v['versions']['1.0.13']) && $v['versions']['1.0.13']['crash'] > 0, 'crashes by version');
$v7 = ma_st_view(7);
check(count($v7['dau']) === 7 && $v7['days'] === 7 && ma_st_view(5)['days'] === 30, '7 days, and an unknown span falls back to 30');

echo "\nthe dashboard\n";
wp_set_current_user(1);
$_GET = ['page' => 'my-assistant', 'tab' => 'home'];
ob_start();
ma_acc_admin();
$html = ob_get_clean();
check(str_contains($html, 'কোম্পানির পরিসংখ্যান') && str_contains($html, 'id="ma-stats"'), 'the sections are on the dashboard');
check(substr_count($html, 'class="ma-st-mean"') >= 12, 'every card says what it means');
check(str_contains($html, 'আপনার কাজ বাকি'), 'the dashboard\'s own cards stay');
check(!str_contains($html, 'm1@example.com') && !str_contains($html, 'সদস্য 1<'), 'no member names or e-mails in the sections');
check(str_contains($html, 'ma-st-svg') && str_contains($html, 'এক কথায়'), 'charts and the plain-words summary');
check(!str_contains($html, 'কোম্পানির পরিসংখ্যান</a>'), 'no menu of its own (owner)');
if (!empty($argv[2])) file_put_contents($argv[2], $html);

$h = do_shortcode('[my_assistant_privacy]');
check(str_contains($h, 'ব্যবহারের হিসাব পাঠান') && str_contains($h, 'Send usage counts'), 'privacy page: what the usage counts are and how to turn them off, Bangla and English');

echo "\naccount deleted\n";
ma_acc_delete_member($first);
check(!(int) $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . ma_st_table('days') . ' WHERE user_id = %d', $first)) && !(int) $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . ma_st_table('dev') . ' WHERE user_id = %d', $first)) && !(int) $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . ma_use_table() . ' WHERE user_id = %d', $first)), 'a deleted account takes its counts and minutes with it');

echo $fail ? "\n$fail FAILED\n" : "\nALL OK\n";
exit($fail ? 1 : 0);
