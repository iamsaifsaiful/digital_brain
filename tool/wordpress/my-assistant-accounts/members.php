<?php
/**
 * Members, looked at by when they joined and where their Premium came from
 * (owner, 27 Oct): today / last 7 days / this month / any month or day, new
 * members per day and per month, and the list as a PDF (a print page the
 * browser saves as PDF — Bangla letters come out right that way).
 */

if (!defined('ABSPATH')) {
    exit;
}

/** Where a member's Premium came from: key => [label, pill class]. */
function ma_acc_sources() {
    return [
        'web' => ['ওয়েবসাইট (বিকাশ)', 'pro'],
        'bkash' => ['বিকাশ — নিজে থেকে মিলেছে', 'pro'],
        'play' => ['Google Play', 'waiting'],
        'manual' => ['অ্যাডমিন দিয়েছেন', 'free'],
        'trial' => ['ট্রায়াল', 'trial'],
    ];
}

/** The source key of a member's Premium ('' when they never had one). */
function ma_acc_source_key($row) {
    $k = (string) ($row['pro_kind'] ?? '');
    if ($k === '') {
        return '';
    }
    if (str_starts_with($k, 'play')) {
        return 'play';
    }
    return isset(ma_acc_sources()[$k]) ? $k : 'manual';
}

function ma_acc_source_label($row) {
    $k = ma_acc_source_key($row);
    return $k === '' ? '—' : ma_acc_sources()[$k][0];
}

/**
 * Premium approved from a website payment was kept as "manual" before 1.19:
 * those whose e-mail has an approved payment become "web" (once).
 */
function ma_acc_source_migrate() {
    if (get_option('ma_acc_src_mig') === '1') {
        return;
    }
    global $wpdb;
    $u = ma_acc_table();
    $p = ma_pay_table();
    $wpdb->query("UPDATE $u SET pro_kind = 'web' WHERE pro_kind = 'manual' AND email IN (SELECT email FROM $p WHERE status = 'approved')");
    update_option('ma_acc_src_mig', '1');
}

/** Seconds the site's clock is ahead of UTC. */
function ma_acc_tz_off() {
    return (int) (get_option('gmt_offset', 0) * HOUR_IN_SECONDS);
}

/**
 * A joined-date filter as a UTC range: 'today', 'week' (last 7 days),
 * 'month' (this calendar month), 'YYYY-MM' or 'YYYY-MM-DD' (site time).
 * Returns [from, to, label] or null.
 */
function ma_acc_joined_range($joined) {
    $off = ma_acc_tz_off();
    $now = time();
    $local_today = gmdate('Y-m-d', $now + $off);
    $utc = function ($local_day) use ($off) {
        return gmdate('Y-m-d H:i:s', strtotime($local_day . ' 00:00:00 UTC') - $off);
    };
    if ($joined === 'today') {
        return [$utc($local_today), $utc(gmdate('Y-m-d', strtotime($local_today . ' UTC') + DAY_IN_SECONDS)), 'আজ যোগ দিয়েছেন'];
    }
    if ($joined === 'week') {
        return [gmdate('Y-m-d H:i:s', $now - 7 * DAY_IN_SECONDS), gmdate('Y-m-d H:i:s', $now + 60), 'গত ৭ দিনে যোগ দিয়েছেন'];
    }
    if ($joined === 'month') {
        $joined = substr($local_today, 0, 7);
    }
    if (preg_match('/^(\d{4})-(\d{2})$/', $joined, $m) && (int) $m[2] >= 1 && (int) $m[2] <= 12) {
        $next = (int) $m[2] === 12 ? ((int) $m[1] + 1) . '-01' : $m[1] . '-' . sprintf('%02d', (int) $m[2] + 1);
        return [$utc($joined . '-01'), $utc($next . '-01'), ma_acc_month_name($joined) . '-এ যোগ দিয়েছেন'];
    }
    if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $joined) && strtotime($joined . ' UTC')) {
        return [$utc($joined), $utc(gmdate('Y-m-d', strtotime($joined . ' UTC') + DAY_IN_SECONDS)), ma_acc_date($utc($joined) ) . ' যোগ দিয়েছেন'];
    }
    return null;
}

/** "অক্টো ২০২৬" for 'YYYY-MM'. */
function ma_acc_month_name($ym) {
    $m = ['জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে'];
    return $m[(int) substr($ym, 5, 2) - 1] . ' ' . ma_acc_bn(substr($ym, 0, 4));
}

/**
 * The WHERE for a members list: search text, status, joined range, source.
 * Returns [sql, args]. Used by the site, the admin app and the PDF.
 */
function ma_acc_member_where($q = '', $status = '', $joined = '', $src = '') {
    global $wpdb;
    $where = ['1=1'];
    $args = [];
    if ($q !== '') {
        $where[] = '(name LIKE %s OR email LIKE %s)';
        $like = '%' . $wpdb->esc_like($q) . '%';
        $args[] = $like;
        $args[] = $like;
    }
    $now = gmdate('Y-m-d H:i:s');
    switch ($status) {
        case 'pro':
            $where[] = "pro_until > '$now' AND pro_kind <> 'trial' AND google_sub NOT LIKE 'pending:%'";
            break;
        case 'trial':
            $where[] = "pro_until > '$now' AND pro_kind = 'trial'";
            break;
        case 'free':
            $where[] = "pro_until IS NULL AND google_sub NOT LIKE 'pending:%'";
            break;
        case 'expired':
            $where[] = "pro_until IS NOT NULL AND pro_until <= '$now'";
            break;
        case 'waiting':
            $where[] = "google_sub LIKE 'pending:%'";
            break;
    }
    $range = ma_acc_joined_range($joined);
    if ($range) {
        $where[] = 'created_at >= %s AND created_at < %s';
        $args[] = $range[0];
        $args[] = $range[1];
        // Added by hand and never signed in: not a new member yet.
        $where[] = "google_sub NOT LIKE 'pending:%'";
    }
    if ($src === 'play') {
        $where[] = "pro_kind LIKE 'play%'";
    } elseif (isset(ma_acc_sources()[$src])) {
        $where[] = 'pro_kind = %s';
        $args[] = $src;
    }
    return [implode(' AND ', $where), $args];
}

function ma_acc_member_rows($q, $status, $joined, $src, $limit, $offset = 0, $order = 'last_seen DESC') {
    global $wpdb;
    [$w, $args] = ma_acc_member_where($q, $status, $joined, $src);
    $sql = 'SELECT * FROM ' . ma_acc_table() . " WHERE $w ORDER BY $order LIMIT %d OFFSET %d";
    return $wpdb->get_results($wpdb->prepare($sql, array_merge($args, [(int) $limit, (int) $offset])), ARRAY_A);
}

function ma_acc_member_count($q, $status, $joined, $src) {
    global $wpdb;
    [$w, $args] = ma_acc_member_where($q, $status, $joined, $src);
    $sql = 'SELECT COUNT(*) FROM ' . ma_acc_table() . " WHERE $w";
    return (int) ($args ? $wpdb->get_var($wpdb->prepare($sql, $args)) : $wpdb->get_var($sql));
}

/** The figures on top: everyone, Premium, new today / this week / this month, active. */
function ma_acc_member_stats() {
    global $wpdb;
    $t = ma_acc_table();
    $now = gmdate('Y-m-d H:i:s');
    $week = gmdate('Y-m-d H:i:s', time() - 7 * DAY_IN_SECONDS);
    $real = "google_sub NOT LIKE 'pending:%'";
    $count_range = function ($joined) use ($wpdb, $t, $real) {
        $r = ma_acc_joined_range($joined);
        return (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $t WHERE created_at >= %s AND created_at < %s AND $real", $r[0], $r[1]));
    };
    return [
        'total' => (int) $wpdb->get_var("SELECT COUNT(*) FROM $t WHERE $real"),
        'pro' => (int) $wpdb->get_var("SELECT COUNT(*) FROM $t WHERE pro_until > '$now' AND pro_kind <> 'trial' AND $real"),
        'trial' => (int) $wpdb->get_var("SELECT COUNT(*) FROM $t WHERE pro_until > '$now' AND pro_kind = 'trial' AND $real"),
        'week' => (int) $wpdb->get_var("SELECT COUNT(*) FROM $t WHERE created_at > '$week' AND $real"),
        'today_new' => $count_range('today'),
        'month_new' => $count_range('month'),
        'month' => current_time('Y-m'),
        'active' => (int) $wpdb->get_var("SELECT COUNT(*) FROM $t WHERE last_seen > '$week' AND $real"),
    ];
}

/**
 * New members per day (last 30 days) and per month (last 12), in site time.
 * Premium members by source as well.
 */
function ma_acc_growth() {
    global $wpdb;
    $off = ma_acc_tz_off();
    $since = gmdate('Y-m-d H:i:s', strtotime(gmdate('Y-m-01', time() + $off) . ' UTC') - 11 * 31 * DAY_IN_SECONDS);
    $rows = $wpdb->get_col($wpdb->prepare('SELECT created_at FROM ' . ma_acc_table() . " WHERE created_at >= %s AND google_sub NOT LIKE 'pending:%%'", $since));
    $days = [];
    $today = strtotime(gmdate('Y-m-d', time() + $off) . ' UTC');
    for ($i = 29; $i >= 0; $i--) {
        $days[gmdate('Y-m-d', $today - $i * DAY_IN_SECONDS)] = 0;
    }
    $months = [];
    $y = (int) gmdate('Y', time() + $off);
    $mo = (int) gmdate('n', time() + $off);
    for ($i = 11; $i >= 0; $i--) {
        $mm = $mo - $i;
        $yy = $y;
        while ($mm < 1) {
            $mm += 12;
            $yy--;
        }
        $months[sprintf('%04d-%02d', $yy, $mm)] = 0;
    }
    foreach ($rows as $c) {
        $local = ma_acc_ts($c) + $off;
        $d = gmdate('Y-m-d', $local);
        $m = gmdate('Y-m', $local);
        if (isset($days[$d])) {
            $days[$d]++;
        }
        if (isset($months[$m])) {
            $months[$m]++;
        }
    }
    $now = gmdate('Y-m-d H:i:s');
    $by_src = [];
    foreach ($wpdb->get_results('SELECT pro_kind, COUNT(*) n FROM ' . ma_acc_table() . " WHERE pro_until > '$now' AND google_sub NOT LIKE 'pending:%' GROUP BY pro_kind", ARRAY_A) as $r) {
        $k = ma_acc_source_key(['pro_kind' => $r['pro_kind']]);
        if ($k !== '') {
            $by_src[$k] = ($by_src[$k] ?? 0) + (int) $r['n'];
        }
    }
    $out = ['days' => [], 'months' => [], 'sources' => []];
    foreach ($days as $d => $n) {
        $out['days'][] = ['day' => $d, 'n' => $n];
    }
    foreach ($months as $m => $n) {
        $out['months'][] = ['month' => $m, 'n' => $n];
    }
    foreach (ma_acc_sources() as $k => $s) {
        $out['sources'][] = ['key' => $k, 'label' => $s[0], 'n' => $by_src[$k] ?? 0];
    }
    return $out;
}

/** What a filter set says in words ("অক্টো ২০২৬-এ যোগ দিয়েছেন · প্রিমিয়াম"). */
function ma_acc_filter_words($q, $status, $joined, $src) {
    $parts = [];
    $r = ma_acc_joined_range($joined);
    if ($r) {
        $parts[] = $r[2];
    }
    if ($status !== '' && isset(ma_acc_status_labels()[$status])) {
        $parts[] = ma_acc_status_labels()[$status][0];
    }
    if (isset(ma_acc_sources()[$src])) {
        $parts[] = 'প্রিমিয়াম: ' . ma_acc_sources()[$src][0];
    }
    if ($q !== '') {
        $parts[] = '“' . $q . '”';
    }
    return $parts ? implode(' · ', $parts) : 'সব সদস্য';
}

// ── The members list as a PDF (a print page) ──

/** Sends the print page and stops. */
function ma_acc_print_page($q, $status, $joined, $src) {
    nocache_headers();
    header('Content-Type: text/html; charset=utf-8');
    header('X-Robots-Tag: noindex');
    echo ma_acc_print_html($q, $status, $joined, $src); // phpcs:ignore WordPress.Security.EscapeOutput -- escaped inside
    exit;
}

/** The print page itself (the browser's "Save as PDF" makes the file). */
function ma_acc_print_html($q, $status, $joined, $src) {
    $rows = ma_acc_member_rows($q, $status, $joined, $src, 5000, 0, 'created_at DESC');
    $labels = ma_acc_status_labels();
    $words = ma_acc_filter_words($q, $status, $joined, $src);
    $count = ['pro' => 0, 'trial' => 0, 'free' => 0, 'expired' => 0, 'waiting' => 0];
    foreach ($rows as $r) {
        $count[ma_acc_status($r)]++;
    }
    $file = 'my-assistant-members-' . current_time('Y-m-d');
    ob_start();
    ?><!doctype html>
<html lang="bn"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title><?php echo esc_html($file); ?></title>
<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Hind+Siliguri:wght@400;600;700&display=swap">
<style>
@page{size:A4 landscape;margin:12mm}
*{box-sizing:border-box}
body{font-family:"Hind Siliguri",system-ui,sans-serif;color:#111827;margin:0;padding:20px;font-size:12.5px}
.bar{display:flex;gap:10px;align-items:center;justify-content:space-between;background:#E7F4EF;border-radius:12px;padding:10px 14px;margin-bottom:16px}
.bar button{font:inherit;font-weight:700;font-size:15px;border:0;border-radius:10px;background:#0E7A5F;color:#fff;padding:10px 18px}
.bar span{color:#0A5C47}
h1{font-size:20px;margin:0}
.sub{color:#6B7280;margin:2px 0 12px}
.sum{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:12px}
.sum span{border:1px solid #E5E7EB;border-radius:999px;padding:2px 10px}
table{width:100%;border-collapse:collapse}
th{text-align:left;font-weight:600;color:#6B7280;border-bottom:1.5px solid #D1D5DB;padding:6px 6px}
td{border-bottom:1px solid #EEF0F2;padding:6px 6px;vertical-align:top}
tr{page-break-inside:avoid}
.n{color:#9CA3AF;width:28px}
.foot{margin-top:14px;color:#9CA3AF;font-size:11px}
@media print{.bar{display:none}body{padding:0}}
</style></head>
<body>
<div class="bar"><span>মোবাইলে: “প্রিন্ট” খুলে প্রিন্টারের জায়গায় <b>Save as PDF</b> বাছুন।</span><button onclick="window.print()">PDF হিসেবে রাখুন</button></div>
<h1>My Assistant — সদস্য তালিকা</h1>
<p class="sub"><?php echo esc_html($words); ?> · মোট <?php echo esc_html(ma_acc_bn(count($rows))); ?> জন · <?php echo esc_html(ma_acc_date(current_time('mysql', true))); ?></p>
<div class="sum"><?php foreach ($count as $k => $n) : if (!$n) { continue; } ?><span><?php echo esc_html($labels[$k][0] . ': ' . ma_acc_bn($n)); ?></span><?php endforeach; ?></div>
<table>
<thead><tr><th class="n">#</th><th>নাম</th><th>ইমেইল</th><th>অবস্থা</th><th>প্রিমিয়াম কোথা থেকে</th><th>প্রিমিয়াম পর্যন্ত</th><th>যোগ দিয়েছেন</th><th>শেষ দেখা</th></tr></thead>
<tbody>
<?php $i = 0; foreach ($rows as $r) : $i++; $st = ma_acc_status($r); ?>
<tr><td class="n"><?php echo esc_html(ma_acc_bn($i)); ?></td><td><?php echo esc_html($r['name'] !== '' ? $r['name'] : '—'); ?></td><td><?php echo esc_html($r['email']); ?></td><td><?php echo esc_html($labels[$st][0]); ?></td><td><?php echo esc_html(ma_acc_source_label($r)); ?></td><td><?php echo esc_html(in_array($st, ['pro', 'trial', 'waiting'], true) ? ma_acc_date($r['pro_until']) : '—'); ?></td><td><?php echo esc_html(ma_acc_date($r['created_at'])); ?></td><td><?php echo esc_html($st === 'waiting' ? '—' : ma_acc_date($r['last_seen'])); ?></td></tr>
<?php endforeach; ?>
</tbody></table>
<p class="foot">শুধু নাম, ইমেইল আর প্রিমিয়ামের তথ্য। সদস্যের হিসাব, নোট বা পাসওয়ার্ড এই সার্ভারে থাকে না।</p>
<script>window.addEventListener('load',function(){setTimeout(function(){window.print();},700);});</script>
</body></html>
    <?php
    return ob_get_clean();
}

/** The site's button (admin page). */
add_action('admin_post_ma_acc_print', function () {
    if (!current_user_can('ma_manage')) {
        wp_die('Not allowed', 403);
    }
    check_admin_referer('ma_acc_print');
    ma_acc_print_page(
        sanitize_text_field(wp_unslash((string) ($_GET['q'] ?? ''))),
        sanitize_key((string) ($_GET['status'] ?? '')),
        sanitize_text_field((string) ($_GET['joined'] ?? '')),
        sanitize_key((string) ($_GET['src'] ?? ''))
    );
});

/**
 * The admin app opens the PDF in the phone's browser: a link that works for
 * 10 minutes, made for one admin and one filter set.
 */
function ma_acc_print_link($admin_id, $q, $status, $joined, $src) {
    $token = bin2hex(random_bytes(24));
    set_transient('ma_print_' . hash('sha256', $token), ['admin' => (int) $admin_id, 'q' => $q, 'status' => $status, 'joined' => $joined, 'src' => $src], 10 * MINUTE_IN_SECONDS);
    return add_query_arg('ma_members_print', $token, home_url('/'));
}

add_action('init', function () {
    if (!isset($_GET['ma_members_print'])) {
        return;
    }
    $token = (string) $_GET['ma_members_print'];
    $job = preg_match('/^[a-f0-9]{48}$/', $token) ? get_transient('ma_print_' . hash('sha256', $token)) : false;
    if (!is_array($job) || !user_can((int) $job['admin'], 'ma_manage')) {
        status_header(403);
        header('Content-Type: text/plain; charset=utf-8');
        echo 'লিংকের মেয়াদ শেষ — অ্যাডমিন অ্যাপ থেকে আবার PDF চাপুন।';
        exit;
    }
    ma_acc_print_page($job['q'], $job['status'], $job['joined'], $job['src']);
});
