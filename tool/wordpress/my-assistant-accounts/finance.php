<?php
/**
 * কোম্পানির হিসাব (owner, 23 Oct 2026): আয়, ব্যয় আর বিনিয়োগকারী — on the
 * site's "হিসাব" tab and in the admin app, the site owner only.
 *
 * আয় = approved payments (money that really came; Pro given free has no
 * payment, so it never counts) + income written by hand.
 * ব্যয় = the AI bill (from the usage table, in taka) + costs written by hand.
 * বিনিয়োগ is kept apart: it is not আয়.
 */

if (!defined('ABSPATH')) {
    exit;
}

function ma_fin_table($which) {
    global $wpdb;
    return $wpdb->prefix . ($which === 'investors' ? 'ma_fin_investors' : 'ma_fin_entries');
}

function ma_fin_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $c = $wpdb->get_charset_collate();
    $e = ma_fin_table('entries');
    dbDelta("CREATE TABLE $e (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        kind varchar(8) NOT NULL DEFAULT 'expense',
        category varchar(80) NOT NULL DEFAULT '',
        amount bigint(20) unsigned NOT NULL DEFAULT 0,
        on_date date NOT NULL,
        note varchar(400) NOT NULL DEFAULT '',
        created_by varchar(190) NOT NULL DEFAULT '',
        created_at datetime NOT NULL,
        PRIMARY KEY  (id),
        KEY on_date (on_date)
    ) $c;");
    $i = ma_fin_table('investors');
    dbDelta("CREATE TABLE $i (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        name varchar(190) NOT NULL,
        contact varchar(190) NOT NULL DEFAULT '',
        amount bigint(20) unsigned NOT NULL DEFAULT 0,
        share varchar(16) NOT NULL DEFAULT '',
        on_date date NOT NULL,
        note varchar(400) NOT NULL DEFAULT '',
        created_at datetime NOT NULL,
        PRIMARY KEY  (id)
    ) $c;");
}

/** Categories offered when writing by hand (any other text is fine too). */
function ma_fin_categories() {
    return [
        'income' => ['বিজ্ঞাপন', 'Google Play', 'অন্যান্য আয়'],
        'expense' => ['সার্ভার ও হোস্টিং', 'ডোমেইন', 'Google Play ফি', 'বিজ্ঞাপন/প্রচার', 'বেতন', 'অফিস', 'অন্যান্য খরচ'],
    ];
}

function ma_fin_date($s) {
    $s = substr(sanitize_text_field((string) $s), 0, 10);
    return preg_match('/^\d{4}-\d{2}-\d{2}$/', $s) ? $s : current_time('Y-m-d');
}

/** A hand-written line. Returns its id, or an error message. */
function ma_fin_add_entry($kind, $category, $amount, $date, $note, $by) {
    global $wpdb;
    $kind = $kind === 'income' ? 'income' : 'expense';
    $amount = (int) $amount;
    $category = mb_substr(sanitize_text_field((string) $category), 0, 80);
    if ($amount <= 0) {
        return 'টাকার অঙ্ক দিন।';
    }
    if ($category === '') {
        $category = $kind === 'income' ? 'অন্যান্য আয়' : 'অন্যান্য খরচ';
    }
    $wpdb->insert(ma_fin_table('entries'), [
        'kind' => $kind, 'category' => $category, 'amount' => $amount, 'on_date' => ma_fin_date($date),
        'note' => mb_substr(sanitize_text_field((string) $note), 0, 400), 'created_by' => (string) $by, 'created_at' => gmdate('Y-m-d H:i:s'),
    ]);
    return (int) $wpdb->insert_id;
}

function ma_fin_add_investor($name, $contact, $amount, $share, $date, $note) {
    global $wpdb;
    $name = mb_substr(sanitize_text_field((string) $name), 0, 190);
    if ($name === '') {
        return 'নাম দিন।';
    }
    $wpdb->insert(ma_fin_table('investors'), [
        'name' => $name, 'contact' => mb_substr(sanitize_text_field((string) $contact), 0, 190), 'amount' => max(0, (int) $amount),
        'share' => mb_substr(preg_replace('/[^0-9.]/', '', (string) $share), 0, 16), 'on_date' => ma_fin_date($date),
        'note' => mb_substr(sanitize_text_field((string) $note), 0, 400), 'created_at' => gmdate('Y-m-d H:i:s'),
    ]);
    return (int) $wpdb->insert_id;
}

/** Approved payments per month 'Y-m' => taka (site time). Free Pro is not a payment. */
function ma_fin_payments_by_month() {
    global $wpdb;
    $rows = $wpdb->get_results('SELECT amount, COALESCE(reviewed_at, created_at) AS at FROM ' . ma_pay_table() . " WHERE status = 'approved' AND amount > 0", ARRAY_A);
    $out = [];
    $off = (int) (get_option('gmt_offset', 0) * HOUR_IN_SECONDS);
    foreach ($rows as $r) {
        $m = gmdate('Y-m', ma_acc_ts($r['at']) + $off);
        $out[$m] = ($out[$m] ?? 0) + (int) $r['amount'];
    }
    return $out;
}

/** The AI bill per month 'Y-m' => taka. */
function ma_fin_ai_by_month() {
    global $wpdb;
    $rows = $wpdb->get_results('SELECT SUBSTR(day, 1, 7) AS m, SUM(cost_micro_usd) AS c FROM ' . ma_ai_usage_table() . ' GROUP BY SUBSTR(day, 1, 7)', ARRAY_A);
    $rate = ma_ai_usd_bdt();
    $out = [];
    foreach ($rows as $r) {
        $out[$r['m']] = (int) round(((int) $r['c']) / 1e6 * $rate);
    }
    return $out;
}

/** Everything for the tab and the admin app. $month 'Y-m' (default this month). */
function ma_fin_summary($month = '') {
    global $wpdb;
    $month = preg_match('/^\d{4}-\d{2}$/', (string) $month) ? $month : current_time('Y-m');
    $pay = ma_fin_payments_by_month();
    $ai = ma_fin_ai_by_month();
    $entries = $wpdb->get_results('SELECT * FROM ' . ma_fin_table('entries') . ' ORDER BY on_date DESC, id DESC', ARRAY_A);
    $months = [];
    $add = function ($m, $k, $v) use (&$months) {
        $months[$m] = ($months[$m] ?? ['month' => $m, 'payments' => 0, 'income_other' => 0, 'ai' => 0, 'expense_other' => 0]);
        $months[$m][$k] += $v;
    };
    foreach ($pay as $m => $v) {
        $add($m, 'payments', $v);
    }
    foreach ($ai as $m => $v) {
        $add($m, 'ai', $v);
    }
    foreach ($entries as $e) {
        $add(substr($e['on_date'], 0, 7), $e['kind'] === 'income' ? 'income_other' : 'expense_other', (int) $e['amount']);
    }
    krsort($months);
    $total = ['income' => 0, 'expense' => 0];
    foreach ($months as &$r) {
        $r['income'] = $r['payments'] + $r['income_other'];
        $r['expense'] = $r['ai'] + $r['expense_other'];
        $r['net'] = $r['income'] - $r['expense'];
        $total['income'] += $r['income'];
        $total['expense'] += $r['expense'];
    }
    unset($r);
    $investors = $wpdb->get_results('SELECT * FROM ' . ma_fin_table('investors') . ' ORDER BY on_date ASC, id ASC', ARRAY_A);
    $invested = 0;
    foreach ($investors as &$i) {
        $i['id'] = (int) $i['id'];
        $i['amount'] = (int) $i['amount'];
        $invested += $i['amount'];
    }
    unset($i);
    foreach ($entries as &$e) {
        $e['id'] = (int) $e['id'];
        $e['amount'] = (int) $e['amount'];
    }
    unset($e);
    $this_month = $months[$month] ?? ['month' => $month, 'payments' => 0, 'income_other' => 0, 'ai' => 0, 'expense_other' => 0, 'income' => 0, 'expense' => 0, 'net' => 0];
    return [
        'month' => $this_month,
        'all' => $total + ['net' => $total['income'] - $total['expense']],
        'invested' => $invested,
        // Money the company should have: investment + income − expense.
        'cash' => $invested + $total['income'] - $total['expense'],
        'months' => array_values(array_slice($months, 0, 24)),
        'entries' => array_slice($entries, 0, 300),
        'investors' => $investors,
        'categories' => ma_fin_categories(),
        'usd_bdt' => ma_ai_usd_bdt(),
    ];
}

// ── Site (forms on the হিসাব tab; site owner only) ──

add_action('admin_post_ma_fin_entry', function () {
    ma_acc_guard('ma_fin_entry', 'manage_options');
    $u = wp_get_current_user();
    $r = ma_fin_add_entry(sanitize_key((string) ($_POST['kind'] ?? '')), wp_unslash((string) ($_POST['category'] ?? '')), (int) ($_POST['amount'] ?? 0), (string) ($_POST['on_date'] ?? ''), wp_unslash((string) ($_POST['note'] ?? '')), $u ? $u->user_email : '');
    is_string($r) ? ma_acc_back($r, 'error', ['tab' => 'finance']) : ma_acc_back('লেখা হলো।', 'ok', ['tab' => 'finance']);
});

add_action('admin_post_ma_fin_investor', function () {
    ma_acc_guard('ma_fin_investor', 'manage_options');
    $r = ma_fin_add_investor(wp_unslash((string) ($_POST['name'] ?? '')), wp_unslash((string) ($_POST['contact'] ?? '')), (int) ($_POST['amount'] ?? 0), (string) ($_POST['share'] ?? ''), (string) ($_POST['on_date'] ?? ''), wp_unslash((string) ($_POST['note'] ?? '')));
    is_string($r) ? ma_acc_back($r, 'error', ['tab' => 'finance']) : ma_acc_back('বিনিয়োগকারী যোগ হলো।', 'ok', ['tab' => 'finance']);
});

add_action('admin_post_ma_fin_delete', function () {
    ma_acc_guard('ma_fin_delete', 'manage_options');
    global $wpdb;
    $which = ($_POST['which'] ?? '') === 'investor' ? 'investors' : 'entries';
    $wpdb->delete(ma_fin_table($which), ['id' => (int) ($_POST['id'] ?? 0)]);
    ma_acc_back('মুছে ফেলা হলো।', 'ok', ['tab' => 'finance']);
});

// ── Admin app (the same, site owner only) ──

add_action('rest_api_init', function () {
    $owner = function (WP_REST_Request $req) {
        return ma_admin_is_owner($req) ? true : new WP_Error('owner', 'site owner only', ['status' => 403]);
    };
    $route = function ($path, $method, $cb) use ($owner) {
        register_rest_route('my-assistant/v1', '/admin' . $path, ['methods' => $method, 'callback' => $cb, 'permission_callback' => $owner]);
    };
    $route('/finance', 'GET', function (WP_REST_Request $req) {
        return ma_fin_summary((string) $req->get_param('month'));
    });
    $route('/finance/entry', 'POST', function (WP_REST_Request $req) {
        $a = ma_admin_of($req);
        $r = ma_fin_add_entry((string) $req->get_param('kind'), (string) $req->get_param('category'), (int) $req->get_param('amount'), (string) $req->get_param('date'), (string) $req->get_param('note'), $a['email'] ?? '');
        return is_string($r) ? new WP_Error('bad', $r, ['status' => 400]) : ['ok' => true, 'id' => $r];
    });
    $route('/finance/investor', 'POST', function (WP_REST_Request $req) {
        $r = ma_fin_add_investor((string) $req->get_param('name'), (string) $req->get_param('contact'), (int) $req->get_param('amount'), (string) $req->get_param('share'), (string) $req->get_param('date'), (string) $req->get_param('note'));
        return is_string($r) ? new WP_Error('bad', $r, ['status' => 400]) : ['ok' => true, 'id' => $r];
    });
    // The admin app posts (its client sends GET and POST only).
    $route('/finance/(?P<which>entry|investor)/(?P<id>\d+)', 'POST, DELETE', function (WP_REST_Request $req) {
        global $wpdb;
        $wpdb->delete(ma_fin_table($req['which'] === 'investor' ? 'investors' : 'entries'), ['id' => (int) $req['id']]);
        return ['ok' => true];
    });
});
