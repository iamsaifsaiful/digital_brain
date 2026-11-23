<?php
/**
 * কোম্পানির পরিসংখ্যান (owner, 24 Nov): how many use the app, how long they
 * stay, where new members drop off, the money, how well the app runs, and
 * where / in which language — shown as sections of the admin dashboard.
 *
 * What the app sends (on by default; Settings › "ব্যবহারের হিসাব পাঠান"
 * turns it off): which parts were opened on a day (keys like "money",
 * never what was written), how long the app took to open, the phone's
 * maker and Android version, the app's language, the country (from the
 * phone's network), business mode on or off, and whether anything was kept
 * in the app yet (yes / no). Tied to the account only so each person is
 * counted once; the dashboard shows totals only; deleted with the account
 * (account-delete.php). A first-open ping before sign-in carries nothing.
 *
 * Also measured here, with nothing from the phone: how long this server
 * takes to answer the app (login, plan, AI).
 */

if (!defined('ABSPATH')) {
    exit;
}

/** The parts of the app counted when opened: key => label. */
const MA_ST_PARTS = [
    'tasks' => 'আজকের কাজ',
    'reminders' => 'রিমাইন্ডার',
    'money' => 'হিসাব (আয়-ব্যয়)',
    'diary' => 'দিনলিপি',
    'files' => 'আমার ফাইল',
    'calendar' => 'ঋতুপঞ্জি (ক্যালেন্ডার ও আবহাওয়া)',
    'prayer' => 'নামাজ ও ইবাদত',
    'health' => 'স্বাস্থ্য ও ওষুধ',
    'notes' => 'নোট',
    'contacts' => 'যোগাযোগ',
    'passwords' => 'পাসওয়ার্ড',
    'zakat' => 'যাকাত',
    'family' => 'পরিবার',
    'business' => 'ব্যবসায়ী মোড',
    'voice' => 'সহকারীকে বলা (মাইক বা লিখে)',
];

function ma_st_table($k) {
    global $wpdb;
    return $wpdb->prefix . 'ma_stats_' . $k;
}

function ma_st_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $c = $wpdb->get_charset_collate();
    // One row a person a day: the parts opened, the slowest-free open time.
    dbDelta('CREATE TABLE ' . ma_st_table('days') . " (
        user_id bigint(20) unsigned NOT NULL,
        day date NOT NULL,
        opens varchar(400) NOT NULL DEFAULT '',
        start_ms int(10) unsigned NOT NULL DEFAULT 0,
        PRIMARY KEY  (user_id,day),
        KEY day (day)
    ) $c;");
    // One row a person: the phone and the app as last told.
    dbDelta('CREATE TABLE ' . ma_st_table('dev') . " (
        user_id bigint(20) unsigned NOT NULL,
        brand varchar(30) NOT NULL DEFAULT '',
        android smallint(5) unsigned NOT NULL DEFAULT 0,
        lang varchar(5) NOT NULL DEFAULT '',
        country char(2) NOT NULL DEFAULT '',
        biz tinyint(1) NOT NULL DEFAULT 0,
        items tinyint(1) NOT NULL DEFAULT 0,
        updated_at datetime NOT NULL,
        PRIMARY KEY  (user_id),
        KEY updated_at (updated_at)
    ) $c;");
    // Plain counts a day: first opens, and the server's answer times.
    dbDelta('CREATE TABLE ' . ma_st_table('count') . " (
        day date NOT NULL,
        k varchar(40) NOT NULL,
        n bigint(20) unsigned NOT NULL DEFAULT 0,
        PRIMARY KEY  (day,k)
    ) $c;");
}

function ma_st_today() {
    return gmdate('Y-m-d', time() + ma_acc_tz_off());
}

function ma_st_add($k, $n = 1, $day = null) {
    global $wpdb;
    $wpdb->query($wpdb->prepare('INSERT INTO ' . ma_st_table('count') . ' (day, k, n) VALUES (%s, %s, %d) ON DUPLICATE KEY UPDATE n = n + VALUES(n)', $day ?: ma_st_today(), $k, (int) $n));
}

/** Forgets a member's rows (account-delete.php). */
function ma_st_forget_member($id) {
    global $wpdb;
    $wpdb->delete(ma_st_table('days'), ['user_id' => (int) $id]);
    $wpdb->delete(ma_st_table('dev'), ['user_id' => (int) $id]);
}

add_action('rest_api_init', function () {
    register_rest_route('my-assistant/v1', '/stats', [
        'methods' => 'POST',
        'callback' => 'ma_st_receive',
        'permission_callback' => '__return_true', // the session is checked inside
    ]);
    register_rest_route('my-assistant/v1', '/stats/first-open', [
        'methods' => 'POST',
        'callback' => 'ma_st_first_open',
        'permission_callback' => '__return_true',
    ]);
});

/** A new install opened the first time (before sign-in; nothing about the phone). */
function ma_st_first_open(WP_REST_Request $req) {
    $k = 'ma_st_fo_' . md5(function_exists('ma_client_ip') ? ma_client_ip() : (string) ($_SERVER['REMOTE_ADDR'] ?? ''));
    $n = (int) get_transient($k);
    if ($n >= 5) {
        return rest_ensure_response(['ok' => true]);
    }
    set_transient($k, $n + 1, DAY_IN_SECONDS);
    ma_st_add('first_open');
    return rest_ensure_response(['ok' => true]);
}

/**
 * {days: [{d: "2026-11-24", o: ["money", …], st: 1800}], brand, android, lang, country, biz, items}
 * Days are merged (a day's parts only grow), so sending again does no harm.
 */
function ma_st_receive(WP_REST_Request $req) {
    global $wpdb;
    $row = function_exists('ma_ai_member') ? ma_ai_member($req) : null;
    if (!$row) {
        return new WP_Error('session', 'sign in again', ['status' => 401]);
    }
    $uid = (int) $row['id'];
    $in = json_decode($req->get_body(), true);
    if (!is_array($in)) {
        return new WP_Error('bad', 'json', ['status' => 400]);
    }
    $t = ma_st_table('days');
    $from = gmdate('Y-m-d', time() - 15 * DAY_IN_SECONDS);
    $to = gmdate('Y-m-d', time() + DAY_IN_SECONDS);
    $kept = 0;
    foreach (array_slice(is_array($in['days'] ?? null) ? $in['days'] : [], 0, 15) as $d) {
        $day = (string) ($d['d'] ?? '');
        if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $day) || $day < $from || $day > $to) {
            continue;
        }
        $opens = array_values(array_intersect(array_map('strval', is_array($d['o'] ?? null) ? $d['o'] : []), array_keys(MA_ST_PARTS)));
        $st = (int) ($d['st'] ?? 0);
        $st = $st > 0 && $st < 60000 ? $st : 0;
        $old = $wpdb->get_row($wpdb->prepare("SELECT opens, start_ms FROM $t WHERE user_id = %d AND day = %s", $uid, $day), ARRAY_A);
        if ($old) {
            $all = array_unique(array_merge(array_filter(explode(',', $old['opens'])), $opens));
            sort($all);
            $wpdb->update($t, ['opens' => implode(',', $all), 'start_ms' => $st ?: (int) $old['start_ms']], ['user_id' => $uid, 'day' => $day]);
        } else {
            sort($opens);
            $wpdb->insert($t, ['user_id' => $uid, 'day' => $day, 'opens' => implode(',', $opens), 'start_ms' => $st]);
        }
        $kept++;
    }
    $brand = strtolower(preg_replace('/[^a-z0-9 ]/i', '', (string) ($in['brand'] ?? '')));
    $lang = in_array($in['lang'] ?? '', ['bn', 'en'], true) ? $in['lang'] : '';
    $cc = strtoupper((string) ($in['country'] ?? ''));
    $dev = [
        'user_id' => $uid,
        'brand' => mb_substr(trim($brand), 0, 30),
        'android' => max(0, min(99, (int) ($in['android'] ?? 0))),
        'lang' => $lang,
        'country' => preg_match('/^[A-Z]{2}$/', $cc) ? $cc : '',
        'biz' => empty($in['biz']) ? 0 : 1,
        'items' => empty($in['items']) ? 0 : 1,
        'updated_at' => gmdate('Y-m-d H:i:s'),
    ];
    // Only a full report changes the phone's row (a send with days alone keeps it).
    if (array_key_exists('brand', $in) || array_key_exists('lang', $in)) {
        $wpdb->replace(ma_st_table('dev'), $dev);
    }
    // Kept a little over a year.
    if (wp_rand(1, 50) === 1) {
        $wpdb->query($wpdb->prepare("DELETE FROM $t WHERE day < %s", gmdate('Y-m-d', time() - 400 * DAY_IN_SECONDS)));
        $wpdb->query($wpdb->prepare('DELETE FROM ' . ma_st_table('count') . ' WHERE day < %s', gmdate('Y-m-d', time() - 400 * DAY_IN_SECONDS)));
    }
    return rest_ensure_response(['ok' => true, 'kept' => $kept]);
}

// ── How long this server takes to answer the app ──

function ma_st_route_group($route) {
    if (strpos($route, '/my-assistant/v1/') !== 0 || strpos($route, '/my-assistant/v1/admin') === 0) {
        return '';
    }
    $r = substr($route, strlen('/my-assistant/v1/'));
    if ($r === 'login') {
        return 'login';
    }
    if ($r === 'me') {
        return 'me';
    }
    if ($r === 'ai') {
        return 'ai';
    }
    return 'other';
}

add_filter('rest_pre_dispatch', function ($result, $server, $request) {
    $GLOBALS['ma_st_t0'] = microtime(true);
    return $result;
}, 1, 3);

// After the answer is made (also for requests made inside WordPress).
add_filter('rest_request_after_callbacks', function ($response, $handler, $request) {
    $t0 = $GLOBALS['ma_st_t0'] ?? null;
    if ($t0 === null || !($request instanceof WP_REST_Request)) {
        return $response;
    }
    $g = ma_st_route_group($request->get_route());
    if ($g !== '') {
        // From WordPress's own start when known (the whole answer), else from routing.
        $start = isset($_SERVER['REQUEST_TIME_FLOAT']) ? (float) $_SERVER['REQUEST_TIME_FLOAT'] : $t0;
        $ms = (int) round((microtime(true) - $start) * 1000);
        if ($ms >= 0 && $ms < 120000) {
            ma_st_add('srv_' . $g . '_ms', $ms);
            ma_st_add('srv_' . $g . '_n', 1);
        }
    }
    return $response;
}, 99, 3);

// ── The numbers for the dashboard ──

/** % with one decimal at most, in Bangla digits ("৯৯.২%"). */
function ma_st_pct($a, $b, $dec = 0) {
    if ($b <= 0) {
        return null;
    }
    return round($a * 100 / $b, $dec);
}

/** Change from [prev] to [now] in whole %, null when there is nothing to compare. */
function ma_st_change($now, $prev) {
    if ($prev <= 0) {
        return null;
    }
    return (int) round(($now - $prev) * 100 / $prev);
}

function ma_st_day_shift($day, $n) {
    return gmdate('Y-m-d', strtotime($day . ' 00:00:00 UTC') + $n * DAY_IN_SECONDS);
}

function ma_st_median(array $v) {
    if (!$v) {
        return null;
    }
    sort($v);
    $c = count($v);
    return $c % 2 ? $v[intdiv($c, 2)] : ($v[$c / 2 - 1] + $v[$c / 2]) / 2;
}

/** Brand names as people know them. */
function ma_st_brand($b) {
    $b = strtolower(trim((string) $b));
    $map = ['samsung' => 'Samsung', 'xiaomi' => 'Xiaomi / Redmi / Poco', 'redmi' => 'Xiaomi / Redmi / Poco', 'poco' => 'Xiaomi / Redmi / Poco', 'realme' => 'Realme / Oppo / OnePlus', 'oppo' => 'Realme / Oppo / OnePlus', 'oneplus' => 'Realme / Oppo / OnePlus', 'vivo' => 'Vivo / iQOO', 'iqoo' => 'Vivo / iQOO', 'infinix' => 'Infinix / Tecno / itel', 'tecno' => 'Infinix / Tecno / itel', 'itel' => 'Infinix / Tecno / itel', 'motorola' => 'Motorola', 'google' => 'Google Pixel', 'huawei' => 'Huawei / Honor', 'honor' => 'Huawei / Honor', 'nokia' => 'Nokia', 'symphony' => 'Symphony', 'walton' => 'Walton'];
    return $b === '' ? 'জানা নেই' : ($map[$b] ?? ucfirst($b));
}

function ma_st_android($sdk) {
    $sdk = (int) $sdk;
    if ($sdk <= 0) {
        return 'জানা নেই';
    }
    if ($sdk <= 29) {
        return 'Android ১০ বা পুরোনো';
    }
    if ($sdk <= 32) {
        return 'Android ১১–১২';
    }
    if ($sdk === 33) {
        return 'Android ১৩';
    }
    if ($sdk === 34) {
        return 'Android ১৪';
    }
    return 'Android ১৫ বা নতুন';
}

function ma_st_country($cc) {
    $n = ['BD' => 'বাংলাদেশ', 'SA' => 'সৌদি আরব', 'AE' => 'সংযুক্ত আরব আমিরাত', 'MY' => 'মালয়েশিয়া', 'QA' => 'কাতার', 'KW' => 'কুয়েত', 'OM' => 'ওমান', 'BH' => 'বাহরাইন', 'SG' => 'সিঙ্গাপুর', 'IN' => 'ভারত', 'GB' => 'যুক্তরাজ্য', 'US' => 'যুক্তরাষ্ট্র', 'IT' => 'ইতালি', 'CA' => 'কানাডা', 'AU' => 'অস্ট্রেলিয়া', 'JP' => 'জাপান', 'MV' => 'মালদ্বীপ', 'PT' => 'পর্তুগাল', 'FR' => 'ফ্রান্স', 'DE' => 'জার্মানি'];
    return $cc === '' ? 'জানা নেই' : ($n[$cc] ?? $cc);
}

/** Member id => the days (Y-m-d) they used the app, from [from] on. */
function ma_st_use_days(array $ids, $from) {
    global $wpdb;
    $ids = array_values(array_filter(array_map('intval', $ids)));
    $out = [];
    foreach (array_chunk($ids, 500) as $chunk) {
        foreach ($wpdb->get_results($wpdb->prepare('SELECT user_id, day FROM ' . ma_use_table() . ' WHERE user_id IN (' . implode(',', $chunk) . ') AND day >= %s AND secs > 0', $from), ARRAY_A) ?: [] as $r) {
            $out[(int) $r['user_id']][] = $r['day'];
        }
    }
    return $out;
}

/** Members' paid Premium kinds (not a trial, not given by an admin). */
function ma_st_paid_sql() {
    return "(pro_kind IN ('web','bkash') OR pro_kind LIKE 'play%')";
}

/**
 * Everything the dashboard sections show, for the last [days] days
 * (compared with the days before). Plain numbers; the view words them.
 */
function ma_st_view($days = 30) {
    global $wpdb;
    $days = in_array((int) $days, [7, 30, 90], true) ? (int) $days : 30;
    $today = ma_st_today();
    $from = ma_st_day_shift($today, -($days - 1));
    $pfrom = ma_st_day_shift($from, -$days);
    $pto = ma_st_day_shift($from, -1);
    $from_utc = gmdate('Y-m-d H:i:s', strtotime($from . ' 00:00:00 UTC') - ma_acc_tz_off());
    $now = gmdate('Y-m-d H:i:s');
    $u = ma_use_table();
    $acc = ma_acc_table();
    $real = "google_sub NOT LIKE 'pending:%'";
    $out = ['days' => $days, 'from' => $from, 'today' => $today];

    // ১ — কতজন অ্যাপ চালান (the app's minutes a day, since 4 Nov).
    $series = [];
    for ($d = $from; $d <= $today; $d = ma_st_day_shift($d, 1)) {
        $series[$d] = 0;
    }
    foreach ($wpdb->get_results($wpdb->prepare("SELECT day, COUNT(*) AS n FROM $u WHERE day >= %s AND day <= %s AND secs > 0 GROUP BY day", $from, $today), ARRAY_A) ?: [] as $r) {
        $series[$r['day']] = (int) $r['n'];
    }
    $out['dau'] = $series;
    $out['today_n'] = $series[$today] ?? 0;
    $out['week_ago_n'] = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $u WHERE day = %s AND secs > 0", ma_st_day_shift($today, -7)));
    $vals = array_values($series);
    // Today is not over: the average leaves it out.
    $done = array_slice($vals, 0, -1);
    $out['dau_avg'] = $done ? (int) round(array_sum($done) / count($done)) : (int) ($vals[0] ?? 0);
    $out['active'] = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(DISTINCT user_id) FROM $u WHERE day >= %s AND day <= %s AND secs > 0", $from, $today));
    $out['active_prev'] = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(DISTINCT user_id) FROM $u WHERE day >= %s AND day <= %s AND secs > 0", $pfrom, $pto));
    $out['members'] = (int) $wpdb->get_var("SELECT COUNT(*) FROM $acc WHERE $real");
    $mins = $wpdb->get_row($wpdb->prepare("SELECT COUNT(*) AS n, COALESCE(AVG(secs),0) AS avg, SUM(CASE WHEN secs < 300 THEN 1 ELSE 0 END) AS a, SUM(CASE WHEN secs >= 300 AND secs < 1200 THEN 1 ELSE 0 END) AS b FROM $u WHERE day >= %s AND day <= %s AND secs > 0", $from, $today), ARRAY_A) ?: ['n' => 0, 'avg' => 0, 'a' => 0, 'b' => 0];
    $out['mins_avg'] = (int) round($mins['avg'] / 60);
    $out['mins_prev'] = (int) round(((float) $wpdb->get_var($wpdb->prepare("SELECT COALESCE(AVG(secs),0) FROM $u WHERE day >= %s AND day <= %s AND secs > 0", $pfrom, $pto))) / 60);
    $n = (int) $mins['n'];
    $out['mins_split'] = $n ? [(int) round($mins['a'] * 100 / $n), (int) round($mins['b'] * 100 / $n), 100 - (int) round($mins['a'] * 100 / $n) - (int) round($mins['b'] * 100 / $n)] : null;
    $out['use_since'] = (string) $wpdb->get_var("SELECT MIN(day) FROM $u");

    // নতুনরা কতদিন থাকেন: of those who joined (after the minutes began),
    // how many used the app 1 day after, in their 2nd week, in their 5th week.
    $since = $out['use_since'] !== '' ? $out['use_since'] : $today;
    $ret = [];
    foreach ([1 => [1, 1], 7 => [7, 13], 30 => [30, 36]] as $key => [$a, $b]) {
        $last_join = ma_st_day_shift($today, -$b);
        $first_join = max($since, ma_st_day_shift($last_join, -max(30, $days)));
        $cohort = $first_join <= $last_join ? $wpdb->get_results($wpdb->prepare(
            "SELECT id, created_at FROM $acc WHERE $real AND created_at >= %s AND created_at < %s",
            gmdate('Y-m-d H:i:s', strtotime($first_join . ' 00:00:00 UTC') - ma_acc_tz_off()),
            gmdate('Y-m-d H:i:s', strtotime(ma_st_day_shift($last_join, 1) . ' 00:00:00 UTC') - ma_acc_tz_off())
        ), ARRAY_A) : [];
        $days_of = ma_st_use_days(array_column($cohort, 'id'), $first_join);
        $back = 0;
        foreach ($cohort as $c) {
            $joined = gmdate('Y-m-d', ma_acc_ts($c['created_at']) + ma_acc_tz_off());
            $lo = ma_st_day_shift($joined, $a);
            $hi = ma_st_day_shift($joined, $b);
            foreach ($days_of[(int) $c['id']] ?? [] as $d) {
                if ($d >= $lo && $d <= $hi) {
                    $back++;
                    break;
                }
            }
        }
        $ret[$key] = ['n' => count($cohort), 'back' => $back, 'pct' => count($cohort) >= 5 ? ma_st_pct($back, count($cohort)) : null];
    }
    $out['retention'] = $ret;

    // কোন অংশ কতবার খোলা হয় (needs the new app).
    $st = ma_st_table('days');
    $rows = $wpdb->get_results($wpdb->prepare("SELECT user_id, opens, start_ms FROM $st WHERE day >= %s AND day <= %s", $from, $today), ARRAY_A) ?: [];
    $who = [];
    $parts = [];
    $starts = [];
    $start_by_user = [];
    foreach ($rows as $r) {
        $id = (int) $r['user_id'];
        $who[$id] = true;
        foreach (array_filter(explode(',', $r['opens'])) as $p) {
            $parts[$p][$id] = true;
        }
        if ((int) $r['start_ms'] > 0) {
            $starts[] = (int) $r['start_ms'];
            $start_by_user[$id][] = (int) $r['start_ms'];
        }
    }
    $out['parts_people'] = count($who);
    $list = [];
    foreach (MA_ST_PARTS as $k => $label) {
        $c = isset($parts[$k]) ? count($parts[$k]) : 0;
        if ($c) {
            $list[] = ['label' => $label, 'n' => $c, 'pct' => ma_st_pct($c, count($who))];
        }
    }
    usort($list, fn($a, $b) => $b['n'] <=> $a['n']);
    $out['parts'] = $list;

    // ২ — শুরুর পথ (the people who joined in these days).
    $ffrom = $wpdb->prepare('%s', $from_utc);
    $joined_ids = array_map('intval', $wpdb->get_col("SELECT id FROM $acc WHERE $real AND created_at >= $ffrom") ?: []);
    $in = $joined_ids ? implode(',', $joined_ids) : '0';
    $week = 0;
    $days_of = ma_st_use_days($joined_ids, $from);
    foreach ($wpdb->get_results("SELECT id, created_at FROM $acc WHERE id IN ($in)", ARRAY_A) ?: [] as $c) {
        $j = ma_st_day_shift(gmdate('Y-m-d', ma_acc_ts($c['created_at']) + ma_acc_tz_off()), 7);
        foreach ($days_of[(int) $c['id']] ?? [] as $d) {
            if ($d >= $j) {
                $week++;
                break;
            }
        }
    }
    $out['funnel'] = [
        'first_open' => (int) $wpdb->get_var($wpdb->prepare('SELECT COALESCE(SUM(n),0) FROM ' . ma_st_table('count') . " WHERE k = 'first_open' AND day >= %s AND day <= %s", $from, $today)),
        'signed' => count($joined_ids),
        'items' => (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . ma_st_table('dev') . " WHERE items = 1 AND user_id IN ($in)"),
        'told' => (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . ma_st_table('dev') . " WHERE user_id IN ($in)"),
        'week' => $week,
        'week_can' => (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $acc WHERE id IN ($in) AND created_at < %s", gmdate('Y-m-d H:i:s', time() - 7 * DAY_IN_SECONDS))),
        'paid' => (int) $wpdb->get_var("SELECT COUNT(*) FROM $acc WHERE id IN ($in) AND " . ma_st_paid_sql()),
    ];

    // ৩ — আয় (the last 6 months).
    $pay = function_exists('ma_fin_payments_by_month') ? ma_fin_payments_by_month() : [];
    $months = [];
    $ym = current_time('Y-m');
    for ($i = 5; $i >= 0; $i--) {
        $m = gmdate('Y-m', strtotime($ym . '-15 00:00:00 UTC') - $i * 30 * DAY_IN_SECONDS);
        $months[$m] = ['web' => (int) ($pay[$m] ?? 0), 'play' => 0, 'ads' => 0, 'other' => 0];
    }
    if (function_exists('ma_fin_table')) {
        foreach ($wpdb->get_results($wpdb->prepare('SELECT SUBSTR(on_date,1,7) AS m, category, SUM(amount) AS a FROM ' . ma_fin_table('entries') . " WHERE kind = 'income' AND on_date >= %s GROUP BY SUBSTR(on_date,1,7), category", array_key_first($months) . '-01'), ARRAY_A) ?: [] as $r) {
            if (!isset($months[$r['m']])) {
                continue;
            }
            $k = $r['category'] === 'Google Play' ? 'play' : ($r['category'] === 'বিজ্ঞাপন' ? 'ads' : 'other');
            $months[$r['m']][$k] += (int) $r['a'];
        }
    }
    $out['revenue'] = $months;
    $tot = fn($m) => $m ? array_sum($m) : 0;
    $keys = array_keys($months);
    $out['rev_month'] = $tot($months[$ym] ?? []);
    $out['rev_prev'] = $tot($months[$keys[count($keys) - 2]] ?? []);

    $out['trial_ended'] = (int) $wpdb->get_var("SELECT COUNT(*) FROM $acc WHERE $real AND trial_started IS NOT NULL AND (pro_kind <> 'trial' OR pro_until < '$now')");
    $out['trial_paid'] = (int) $wpdb->get_var("SELECT COUNT(*) FROM $acc WHERE $real AND trial_started IS NOT NULL AND " . ma_st_paid_sql());
    // Premium now: which plan, from where.
    $plans = ['yearly' => 0, 'monthly' => 0, 'unknown' => 0];
    $from_src = ['web' => 0, 'play' => 0, 'manual' => 0];
    $pt = ma_pay_table();
    foreach ($wpdb->get_results("SELECT id, email, pro_kind FROM $acc WHERE $real AND pro_until > '$now' AND pro_kind <> 'trial'", ARRAY_A) ?: [] as $m) {
        $k = (string) $m['pro_kind'];
        if (strpos($k, 'play') === 0) {
            $from_src['play']++;
            $prod = (string) $wpdb->get_var($wpdb->prepare('SELECT product FROM ' . ma_play_table() . ' WHERE user_id = %d ORDER BY checked_at DESC LIMIT 1', (int) $m['id']));
            $plans[strpos($prod, 'year') !== false ? 'yearly' : (strpos($prod, 'month') !== false ? 'monthly' : 'unknown')]++;
        } elseif ($k === 'web' || $k === 'bkash') {
            $from_src['web']++;
            $plan = (string) $wpdb->get_var($wpdb->prepare("SELECT plan FROM $pt WHERE email = %s AND status = 'approved' ORDER BY id DESC LIMIT 1", $m['email']));
            $plans[isset($plans[$plan]) ? $plan : 'yearly']++;
        } else {
            $from_src['manual']++;
        }
    }
    $out['plans'] = $plans;
    $out['pro_from'] = $from_src;

    // ৪ — অ্যাপ কতটা ঠিক চলে.
    $et = ma_err_table();
    $crash_people = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(DISTINCT user_id) FROM $et WHERE level = 'crash' AND user_id > 0 AND last_at >= %s", $from_utc));
    $seen = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $acc WHERE $real AND last_seen >= %s", $from_utc));
    $base = max($out['active'], $seen);
    $out['crash_people'] = $crash_people;
    $out['crash_free'] = $base ? max(0, round(100 - $crash_people * 100 / $base, 1)) : null;
    $out['start_med'] = ma_st_median($starts);
    $out['start_n'] = count($starts);
    $srv = [];
    foreach ($wpdb->get_results($wpdb->prepare('SELECT k, SUM(n) AS n FROM ' . ma_st_table('count') . " WHERE k LIKE 'srv%%' AND day >= %s AND day <= %s GROUP BY k", $from, $today), ARRAY_A) ?: [] as $r) {
        $srv[$r['k']] = (int) $r['n'];
    }
    $groups = ['login' => 'লগইন', 'me' => 'প্রিমিয়াম দেখা', 'ai' => 'AI', 'other' => 'বাকি সব'];
    $sv = [];
    $all_ms = 0;
    $all_n = 0;
    foreach ($groups as $g => $label) {
        $c = $srv["srv_{$g}_n"] ?? 0;
        if ($c) {
            $sv[$g] = ['label' => $label, 'ms' => (int) round(($srv["srv_{$g}_ms"] ?? 0) / $c), 'n' => $c];
            if ($g !== 'ai') {
                $all_ms += $srv["srv_{$g}_ms"] ?? 0;
                $all_n += $c;
            }
        }
    }
    $out['server'] = $sv;
    $out['server_ms'] = $all_n ? (int) round($all_ms / $all_n) : null;

    $ver = [];
    foreach ($wpdb->get_results($wpdb->prepare("SELECT app_version AS v, COUNT(*) AS n FROM $acc WHERE $real AND last_seen >= %s GROUP BY app_version", $from_utc), ARRAY_A) ?: [] as $r) {
        $ver[(string) $r['v']] = ['n' => (int) $r['n'], 'crash' => 0];
    }
    foreach ($wpdb->get_results($wpdb->prepare("SELECT app_version AS v, SUM(hits) AS h FROM $et WHERE level = 'crash' AND last_at >= %s GROUP BY app_version", $from_utc), ARRAY_A) ?: [] as $r) {
        $ver[(string) $r['v']] = ['n' => $ver[(string) $r['v']]['n'] ?? 0, 'crash' => (int) $r['h']];
    }
    uksort($ver, fn($a, $b) => version_compare($b, $a));
    $out['versions'] = $ver;
    $out['seen'] = $seen;

    // Phones, countries, language (needs the new app).
    $dev = $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . ma_st_table('dev') . ' WHERE updated_at >= %s', $from_utc), ARRAY_A) ?: [];
    $brands = [];
    $android = [];
    $countries = [];
    $lang = ['bn' => 0, 'en' => 0];
    $biz = 0;
    foreach ($dev as $d) {
        $b = ma_st_brand($d['brand']);
        $brands[$b]['n'] = ($brands[$b]['n'] ?? 0) + 1;
        foreach ($start_by_user[(int) $d['user_id']] ?? [] as $ms) {
            $brands[$b]['ms'][] = $ms;
        }
        $a = ma_st_android($d['android']);
        $android[$a]['n'] = ($android[$a]['n'] ?? 0) + 1;
        foreach ($start_by_user[(int) $d['user_id']] ?? [] as $ms) {
            $android[$a]['ms'][] = $ms;
        }
        $c = ma_st_country($d['country']);
        $countries[$c] = ($countries[$c] ?? 0) + 1;
        if (isset($lang[$d['lang']])) {
            $lang[$d['lang']]++;
        }
        $biz += (int) $d['biz'];
    }
    $shape = function ($m) {
        $o = [];
        foreach ($m as $k => $v) {
            $o[] = ['label' => $k, 'n' => $v['n'], 'ms' => ma_st_median($v['ms'] ?? [])];
        }
        usort($o, fn($a, $b) => $b['n'] <=> $a['n']);
        return $o;
    };
    arsort($countries);
    $out['dev_n'] = count($dev);
    $out['brands'] = array_slice($shape($brands), 0, 6);
    $out['android'] = $shape($android);
    $out['countries'] = $countries;
    $out['lang'] = $lang;
    $out['biz'] = $biz;
    return $out;
}
