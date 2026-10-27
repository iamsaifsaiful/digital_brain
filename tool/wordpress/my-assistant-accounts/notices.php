<?php
/**
 * Notifications written here and shown by the app on members' phones.
 * The app downloads the list when it opens and rings each one at its time
 * (respecting the member's quiet hours, daily limit and switch). Once, every
 * day, or one day a week; for everyone, Pro, trial or free members; with an
 * optional condition the phone checks itself ("only if no to-do list today").
 */

if (!defined('ABSPATH')) {
    exit;
}

function ma_note_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_notices';
}

function ma_note_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $t = ma_note_table();
    dbDelta("CREATE TABLE $t (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        title varchar(120) NOT NULL,
        body varchar(400) NOT NULL DEFAULT '',
        kind varchar(10) NOT NULL DEFAULT 'daily',
        at_time char(5) NOT NULL DEFAULT '21:00',
        weekday tinyint(1) NOT NULL DEFAULT 5,
        on_date date NULL DEFAULT NULL,
        start_date date NULL DEFAULT NULL,
        end_date date NULL DEFAULT NULL,
        audience varchar(10) NOT NULL DEFAULT 'all',
        cond varchar(24) NOT NULL DEFAULT '',
        mic tinyint(1) NOT NULL DEFAULT 1,
        active tinyint(1) NOT NULL DEFAULT 1,
        created_at datetime NOT NULL,
        PRIMARY KEY  (id)
    ) " . $wpdb->get_charset_collate() . ';');
    ma_nlog_install();
    // Each time the server itself pushed a notice (once per notice and day).
    dbDelta('CREATE TABLE ' . ma_note_runs_table() . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        notice_id bigint(20) unsigned NOT NULL,
        day date NOT NULL,
        at datetime NOT NULL,
        members int(10) unsigned NOT NULL DEFAULT 0,
        sent int(10) unsigned NOT NULL DEFAULT 0,
        failed int(10) unsigned NOT NULL DEFAULT 0,
        PRIMARY KEY  (id),
        UNIQUE KEY notice_day (notice_id, day)
    ) " . $wpdb->get_charset_collate() . ';');
}

function ma_note_runs_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_notice_runs';
}

// ── নোটিফিকেশনের লগ: what each member's phone is set to show, and what we pushed ──
// Only the kind and the time from the phone ("reminder" at 08:00) — never
// the member's own words. A title only for what this server wrote.

function ma_nlog_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_notice_log';
}

function ma_nlog_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $t = ma_nlog_table();
    dbDelta("CREATE TABLE $t (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        user_id bigint(20) unsigned NOT NULL,
        source varchar(8) NOT NULL DEFAULT 'plan',
        kind varchar(40) NOT NULL DEFAULT '',
        title varchar(160) NOT NULL DEFAULT '',
        at datetime NOT NULL,
        status varchar(12) NOT NULL DEFAULT 'planned',
        created_at datetime NOT NULL,
        PRIMARY KEY  (id),
        KEY user_at (user_id, at),
        KEY at (at)
    ) " . $wpdb->get_charset_collate() . ';');
}

/** One line in the log. $at is UTC 'Y-m-d H:i:s'. */
function ma_nlog_add($user_id, $source, $kind, $title, $at, $status) {
    global $wpdb;
    $wpdb->insert(ma_nlog_table(), [
        'user_id' => (int) $user_id,
        'source' => $source,
        'kind' => substr(preg_replace('/[^a-z0-9_:]/', '', strtolower((string) $kind)), 0, 40),
        'title' => mb_substr((string) $title, 0, 160),
        'at' => $at,
        'status' => $status,
        'created_at' => gmdate('Y-m-d H:i:s'),
    ]);
}

/** Kept 60 days. */
function ma_nlog_prune() {
    global $wpdb;
    $wpdb->query($wpdb->prepare('DELETE FROM ' . ma_nlog_table() . ' WHERE at < %s', gmdate('Y-m-d H:i:s', time() - 60 * DAY_IN_SECONDS)));
}

/** The phone's plan for the next days: replaces what was still ahead. */
function ma_nlog_plan(WP_REST_Request $req) {
    global $wpdb;
    $member = ma_ai_member($req);
    if (!$member) {
        return new WP_Error('session', 'sign in again', ['status' => 401]);
    }
    $items = $req->get_param('items');
    if (!is_array($items)) {
        return new WP_Error('bad', 'items needed', ['status' => 400]);
    }
    $now = gmdate('Y-m-d H:i:s');
    $end = gmdate('Y-m-d H:i:s', time() + 8 * DAY_IN_SECONDS);
    $wpdb->query($wpdb->prepare('DELETE FROM ' . ma_nlog_table() . " WHERE user_id = %d AND source = 'plan' AND at > %s", (int) $member['id'], $now));
    $n = 0;
    foreach (array_slice($items, 0, 300) as $it) {
        if (!is_array($it)) {
            continue;
        }
        $kind = (string) ($it['kind'] ?? '');
        $ts = strtotime((string) ($it['at'] ?? ''));
        if (!preg_match('/^[a-z0-9_:]{1,40}$/', $kind) || !$ts) {
            continue;
        }
        $at = gmdate('Y-m-d H:i:s', $ts);
        if ($at <= $now || $at > $end) {
            continue;
        }
        // A title only for our own notifications; the phone's reminders stay unnamed.
        $title = $kind === 'server' ? sanitize_text_field((string) ($it['title'] ?? '')) : '';
        ma_nlog_add($member['id'], 'plan', $kind, $title, $at, 'planned');
        $n++;
    }
    if (wp_rand(1, 20) === 1) {
        ma_nlog_prune();
    }
    return ['ok' => true, 'saved' => $n];
}

/** This member's pushes (the app's নোটিফিকেশন page). */
function ma_nlog_mine(WP_REST_Request $req) {
    global $wpdb;
    $member = ma_ai_member($req);
    if (!$member) {
        return new WP_Error('session', 'sign in again', ['status' => 401]);
    }
    $rows = $wpdb->get_results($wpdb->prepare(
        'SELECT kind, title, at, status FROM ' . ma_nlog_table() . " WHERE user_id = %d AND source = 'push' AND at >= %s ORDER BY at DESC LIMIT 100",
        (int) $member['id'], gmdate('Y-m-d H:i:s', time() - 30 * DAY_IN_SECONDS)
    ), ARRAY_A);
    $out = [];
    foreach ($rows as $r) {
        $out[] = ['kind' => $r['kind'], 'title' => $r['title'], 'at' => str_replace(' ', 'T', $r['at']) . 'Z', 'status' => $r['status']];
    }
    return ['pushes' => $out];
}

/**
 * The log for the site and the admin app: newest first. $q is an e-mail
 * or name to look for; $when 'past' (shown/sent), 'next' (planned ahead) or ''.
 */
function ma_nlog_rows($q = '', $when = '', $limit = 200) {
    global $wpdb;
    $t = ma_nlog_table();
    $u = ma_acc_table();
    $where = '1=1';
    $args = [];
    if ($q !== '') {
        $like = '%' . $wpdb->esc_like($q) . '%';
        $where .= ' AND (u.email LIKE %s OR u.name LIKE %s)';
        $args[] = $like;
        $args[] = $like;
    }
    $now = gmdate('Y-m-d H:i:s');
    if ($when === 'past') {
        $where .= ' AND l.at <= %s';
        $args[] = $now;
    } elseif ($when === 'next') {
        $where .= ' AND l.at > %s';
        $args[] = $now;
    }
    $order = $when === 'next' ? 'l.at ASC' : 'l.at DESC';
    $sql = "SELECT l.id, l.user_id, l.source, l.kind, l.title, l.at, l.status, u.email, u.name FROM $t l LEFT JOIN $u u ON u.id = l.user_id WHERE $where ORDER BY $order LIMIT " . max(1, min(500, (int) $limit));
    $rows = $args ? $wpdb->get_results($wpdb->prepare($sql, ...$args), ARRAY_A) : $wpdb->get_results($sql, ARRAY_A);
    foreach ($rows as &$r) {
        $r['label'] = ma_nlog_kind_label($r['kind']);
        if ($r['source'] === 'plan' && $r['at'] <= $now) {
            $r['status'] = 'shown';
        }
    }
    return $rows;
}

function ma_nlog_kind_label($kind) {
    if (strpos($kind, 'brief:morning') === 0) {
        return 'সকালের সারাংশ';
    }
    if (strpos($kind, 'brief:') === 0) {
        return 'দিনের সারাংশ';
    }
    if (strpos($kind, 'nudge:') === 0) {
        return 'সহকারীর মনে করানো';
    }
    return [
        'reminder' => 'রিমাইন্ডার',
        'reminder_early' => 'আগাম রিমাইন্ডার',
        'server' => 'সাইটের নোটিফিকেশন',
        'news' => 'সবাইকে পাঠানো',
        'pro' => 'প্রিমিয়াম',
        'blood' => 'রক্তদান',
        'family' => 'ফ্যামিলি',
        'family_item' => 'ফ্যামিলি',
        'feedback' => 'মতামতের উত্তর',
        'heir_claim' => 'উত্তরাধিকার',
        'test' => 'পরীক্ষা',
    ][$kind] ?? $kind;
}

function ma_nlog_status_label($s) {
    return ['planned' => 'আসবে', 'shown' => 'দেখানোর কথা', 'sent' => 'পাঠানো হয়েছে', 'no_device' => 'ফোন যুক্ত নেই', 'failed' => 'পৌঁছায়নি'][$s] ?? $s;
}

function ma_note_options() {
    return [
        'kind' => ['once' => 'একবার', 'daily' => 'প্রতিদিন', 'weekly' => 'প্রতি সপ্তাহে'],
        'audience' => ['all' => 'সবাই', 'pro' => 'প্রিমিয়াম', 'trial' => 'ট্রায়ালে', 'free' => 'ফ্রি'],
        'cond' => ['' => 'সবসময়', 'no_tasks' => 'সেদিন কাজের তালিকা না থাকলে', 'no_spending' => 'সেদিন খরচ লেখা না হলে', 'not_opened' => 'সেদিন অ্যাপ না খুললে'],
        'weekday' => [6 => 'শনিবার', 7 => 'রবিবার', 1 => 'সোমবার', 2 => 'মঙ্গলবার', 3 => 'বুধবার', 4 => 'বৃহস্পতিবার', 5 => 'শুক্রবার'],
    ];
}

add_action('rest_api_init', function () {
    register_rest_route('my-assistant/v1', '/notices/plan', [
        'methods' => 'POST',
        'callback' => 'ma_nlog_plan',
        'permission_callback' => '__return_true', // the member session is checked inside
    ]);
    register_rest_route('my-assistant/v1', '/notices/log', [
        'methods' => 'GET',
        'callback' => 'ma_nlog_mine',
        'permission_callback' => '__return_true', // the member session is checked inside
    ]);
    register_rest_route('my-assistant/v1', '/notices', [
        'methods' => 'GET',
        'callback' => 'ma_note_list',
        'permission_callback' => '__return_true', // public text; the audience comes from the session, if any
    ]);
});

/** Active notifications for this phone (everyone's, plus its plan's when signed in). */
function ma_note_list(WP_REST_Request $req) {
    global $wpdb;
    ma_note_tick_soon();
    $member = ma_ai_member($req);
    // A phone that can take our pushes (2.55.11 and later says push=1): the
    // notices without a condition come from here at their time, so the
    // phone does not plan them itself (it could be closed, or not opened
    // since the notice was written — owner, 27 Oct).
    $pushed = [];
    if ($member && $req->get_param('push')) {
        $sess = ma_session_row($req);
        if ($sess) {
            if ((int) $sess['srv_push'] !== 1) {
                $wpdb->update(ma_ai_sessions_table(), ['srv_push' => 1], ['id' => (int) $sess['id']]);
            }
            $pushed_ok = $sess['fcm_token'] !== '' && ma_push_account() !== null;
        }
    }
    $plan = 'free';
    if ($member) {
        $s = ma_acc_status($member);
        $plan = in_array($s, ['pro', 'trial'], true) ? $s : 'free';
    }
    $today = current_time('Y-m-d');
    $rows = $wpdb->get_results($wpdb->prepare(
        'SELECT * FROM ' . ma_note_table() . " WHERE active = 1 AND (end_date IS NULL OR end_date >= %s) AND audience IN ('all', %s) ORDER BY id DESC LIMIT 30",
        $today, $member ? $plan : 'all'
    ), ARRAY_A);
    $out = [];
    foreach ($rows as $r) {
        $out[] = [
            'id' => (int) $r['id'],
            'title' => $r['title'],
            'body' => $r['body'],
            'kind' => $r['kind'],
            'time' => $r['at_time'],
            'weekday' => (int) $r['weekday'],
            'date' => $r['on_date'],
            'from' => $r['start_date'],
            'until' => $r['end_date'],
            'cond' => $r['cond'],
            'mic' => (bool) $r['mic'],
        ];
        if (!empty($pushed_ok) && $r['cond'] === '') {
            $pushed[] = (int) $r['id'];
        }
    }
    $res = new WP_REST_Response(['notices' => $out, 'pushed' => $pushed, 'rules' => ma_note_rules_public()], 200);
    $res->header('Cache-Control', 'private, no-store');
    return $res;
}

add_action('admin_post_ma_note_save', function () {
    ma_acc_guard('ma_note_save');
    global $wpdb;
    $o = ma_note_options();
    $kind = sanitize_key($_POST['kind'] ?? 'daily');
    $aud = sanitize_key($_POST['audience'] ?? 'all');
    $cond = sanitize_key($_POST['cond'] ?? '');
    $time = preg_match('/^([01]\d|2[0-3]):[0-5]\d$/', (string) ($_POST['at_time'] ?? '')) ? $_POST['at_time'] : '21:00';
    $date = function ($k) {
        $v = sanitize_text_field(wp_unslash($_POST[$k] ?? ''));
        return preg_match('/^\d{4}-\d{2}-\d{2}$/', $v) ? $v : null;
    };
    $data = [
        'title' => substr(sanitize_text_field(wp_unslash($_POST['title'] ?? '')), 0, 120),
        'body' => substr(sanitize_textarea_field(wp_unslash($_POST['body'] ?? '')), 0, 400),
        'kind' => isset($o['kind'][$kind]) ? $kind : 'daily',
        'at_time' => $time,
        'weekday' => isset($o['weekday'][(int) ($_POST['weekday'] ?? 5)]) ? (int) $_POST['weekday'] : 5,
        'on_date' => $date('on_date'),
        'start_date' => $date('start_date'),
        'end_date' => $date('end_date'),
        'audience' => isset($o['audience'][$aud]) ? $aud : 'all',
        'cond' => isset($o['cond'][$cond]) ? $cond : '',
        'mic' => !empty($_POST['mic']) ? 1 : 0,
        'active' => 1,
    ];
    if ($data['title'] === '') {
        ma_acc_back('শিরোনাম লিখুন।', 'error', ['tab' => 'notices']);
    }
    if ($data['kind'] === 'once' && !$data['on_date']) {
        ma_acc_back('একবারের নোটিফিকেশনের তারিখ দিন।', 'error', ['tab' => 'notices']);
    }
    $id = (int) ($_POST['id'] ?? 0);
    if ($id) {
        unset($data['active']);
        $wpdb->update(ma_note_table(), $data, ['id' => $id]);
    } else {
        $wpdb->insert(ma_note_table(), $data + ['created_at' => current_time('mysql', true)]);
    }
    ma_acc_back('রাখা হয়েছে। সদস্যরা পরের বার অ্যাপ খুললে এটা পেয়ে যাবেন।', 'ok', ['tab' => 'notices']);
});

add_action('admin_post_ma_note_toggle', function () {
    ma_acc_guard('ma_note_toggle');
    global $wpdb;
    $id = (int) ($_POST['id'] ?? 0);
    if (!empty($_POST['delete'])) {
        $wpdb->delete(ma_note_table(), ['id' => $id]);
        ma_acc_back('মুছে ফেলা হলো। সদস্যদের ফোন থেকেও পরের বার খোলার পর সরে যাবে।', 'ok', ['tab' => 'notices']);
    }
    $wpdb->query($wpdb->prepare('UPDATE ' . ma_note_table() . ' SET active = 1 - active WHERE id = %d', $id));
    ma_acc_back('বদলানো হলো।', 'ok', ['tab' => 'notices']);
});

// ── The server pushes the notices without a condition at their time ──
// WordPress runs this every five minutes when anyone uses the site or the
// app (and from a real cron, if the host has one). A notice more than two
// hours late is not sent (old news); each notice goes once a day.

add_filter('cron_schedules', function ($s) {
    $s['ma_five'] = ['interval' => 300, 'display' => 'Every 5 minutes (My Assistant)'];
    return $s;
});
add_action('init', function () {
    if (!wp_next_scheduled('ma_note_tick')) {
        wp_schedule_event(time() + 60, 'ma_five', 'ma_note_tick');
    }
});
add_action('ma_note_tick', 'ma_note_tick');

/** From an app or admin request: at most once a minute. */
function ma_note_tick_soon() {
    if (get_transient('ma_note_tick_lock')) {
        return;
    }
    set_transient('ma_note_tick_lock', 1, MINUTE_IN_SECONDS);
    ma_note_tick();
}

/** When a notice is due on a local day ('Y-m-d'), as a UTC timestamp; null when not that day. */
function ma_note_occurs($n, $day) {
    $ts = strtotime($day . ' UTC');
    if (!$ts) {
        return null;
    }
    if ($n['kind'] === 'once' && $n['on_date'] !== $day) {
        return null;
    }
    if ($n['kind'] === 'weekly' && (int) gmdate('N', $ts) !== (int) $n['weekday']) {
        return null;
    }
    if (!empty($n['start_date']) && $day < $n['start_date']) {
        return null;
    }
    if (!empty($n['end_date']) && $day > $n['end_date']) {
        return null;
    }
    return strtotime($day . ' ' . $n['at_time'] . ':00 UTC') - ma_acc_tz_off();
}

/** Phones that take server pushes, for a notice's audience: user_id => [tokens]. */
function ma_note_push_targets($audience) {
    global $wpdb;
    $rows = $wpdb->get_results('SELECT s.user_id, s.fcm_token FROM ' . ma_ai_sessions_table() . ' s JOIN ' . ma_acc_table() . " u ON u.id = s.user_id WHERE s.app <> 'admin' AND s.srv_push = 1 AND s.fcm_token <> '' AND s.expires_at > UTC_TIMESTAMP() " . ma_push_where($audience) . ' LIMIT 20000', ARRAY_A);
    $by = [];
    foreach ($rows as $r) {
        $by[(int) $r['user_id']][] = $r['fcm_token'];
    }
    return $by;
}

function ma_note_tick() {
    global $wpdb;
    if (!ma_push_account()) {
        return 0;
    }
    $now = time();
    $today = gmdate('Y-m-d', $now + ma_acc_tz_off());
    $notes = $wpdb->get_results('SELECT * FROM ' . ma_note_table() . " WHERE active = 1 AND cond = ''", ARRAY_A);
    $done = 0;
    foreach ($notes as $n) {
        $at = ma_note_occurs($n, $today);
        if ($at === null || $at > $now || $now - $at > 2 * HOUR_IN_SECONDS) {
            continue;
        }
        if ($wpdb->get_var($wpdb->prepare('SELECT id FROM ' . ma_note_runs_table() . ' WHERE notice_id = %d AND day = %s', $n['id'], $today))) {
            continue;
        }
        // Claimed first, so two runs at once never send it twice (the unique key refuses the second).
        $quiet = $wpdb->suppress_errors(true);
        $ok = $wpdb->insert(ma_note_runs_table(), ['notice_id' => (int) $n['id'], 'day' => $today, 'at' => gmdate('Y-m-d H:i:s', $now)]);
        $wpdb->suppress_errors($quiet);
        if (!$ok) {
            continue;
        }
        $run = (int) $wpdb->insert_id;
        $members = 0;
        $sent = 0;
        $failed = 0;
        foreach (ma_note_push_targets($n['audience']) as $uid => $tokens) {
            $members++;
            $k = ma_push_send($tokens, $n['title'], $n['body'], ['type' => 'server', 'id' => (string) $n['id'], 'mic' => $n['mic'] ? '1' : '0']);
            $k > 0 ? $sent++ : $failed++;
            ma_nlog_add($uid, 'push', 'server', $n['title'], gmdate('Y-m-d H:i:s', $now), $k > 0 ? 'sent' : 'failed');
        }
        $wpdb->update(ma_note_runs_table(), ['members' => $members, 'sent' => $sent, 'failed' => $failed], ['id' => $run]);
        $done++;
    }
    return $done;
}

// ── What goes out, when, and how many a day (owner, 27 Oct: not who got what) ──

/** The kind of a log line in one of a few groups. */
function ma_note_group($source, $kind) {
    if ($source === 'push') {
        return match ($kind) {
            'server' => 'server',
            'news' => 'news',
            default => 'other_push',
        };
    }
    if ($kind === 'server' || str_starts_with($kind, 'nudge:srv') || str_starts_with($kind, 'nudge:plan:srv')) {
        return 'server';
    }
    if (str_starts_with($kind, 'reminder')) {
        return 'reminder';
    }
    if (str_starts_with($kind, 'brief:')) {
        return 'brief';
    }
    return 'nudge';
}

function ma_note_group_labels() {
    return [
        'server' => 'সাইটের নোটিফিকেশন',
        'news' => '“এখনই পাঠান”',
        'other_push' => 'প্রিমিয়াম, মতামতের উত্তর, ফ্যামিলি…',
        'reminder' => 'সদস্যদের নিজের রিমাইন্ডার',
        'brief' => 'সকাল/রাতের সারাংশ',
        'nudge' => 'সহকারীর মনে করানো',
    ];
}

/**
 * The notifications page: the next 7 days of our notices (time, who, how
 * many phones), and the last 14 days counted per day and kind.
 */
function ma_note_overview() {
    global $wpdb;
    $off = ma_acc_tz_off();
    $now = time();
    $o = ma_note_options();
    $push_on = ma_push_account() !== null;
    $notes = $wpdb->get_results('SELECT * FROM ' . ma_note_table() . ' WHERE active = 1 ORDER BY at_time ASC', ARRAY_A);
    $aud_count = [];
    $phone_count = [];
    $upcoming = [];
    $today = strtotime(gmdate('Y-m-d', $now + $off) . ' UTC');
    for ($i = 0; $i < 7; $i++) {
        $day = gmdate('Y-m-d', $today + $i * DAY_IN_SECONDS);
        foreach ($notes as $n) {
            $at = ma_note_occurs($n, $day);
            if ($at === null || $at < $now - 5 * MINUTE_IN_SECONDS) {
                continue;
            }
            $aud = $n['audience'];
            if (!isset($aud_count[$aud])) {
                $aud_count[$aud] = (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . ma_acc_table() . " u WHERE u.google_sub NOT LIKE 'pending:%' " . ma_push_where($aud));
                $phone_count[$aud] = count(ma_note_push_targets($aud));
            }
            $by_push = $push_on && $n['cond'] === '';
            $upcoming[] = [
                'id' => (int) $n['id'],
                'day' => $day,
                'time' => $n['at_time'],
                'at' => gmdate('c', $at),
                'title' => $n['title'],
                'body' => $n['body'],
                'audience' => $o['audience'][$aud] ?? 'সবাই',
                'how' => $by_push ? 'push' : 'phone',
                'how_label' => $by_push ? 'সার্ভার থেকে পুশ' : ($n['cond'] !== '' ? 'ফোন নিজে দেখাবে (শর্ত: ' . ($o['cond'][$n['cond']] ?? '') . ')' : 'ফোন নিজে দেখাবে'),
                'members' => $aud_count[$aud],
                'phones' => $by_push ? $phone_count[$aud] : null,
            ];
        }
    }
    usort($upcoming, fn($a, $b) => strcmp($a['at'], $b['at']));

    // The last 14 days, per local day and group (counted by the hour in SQL).
    $from = gmdate('Y-m-d H:i:s', $today - 13 * DAY_IN_SECONDS - $off);
    $rows = $wpdb->get_results($wpdb->prepare(
        'SELECT SUBSTR(at, 1, 13) AS h, source, kind, status, COUNT(*) AS n FROM ' . ma_nlog_table() . ' WHERE at >= %s AND at <= %s GROUP BY SUBSTR(at, 1, 13), source, kind, status',
        $from, gmdate('Y-m-d H:i:s', $now)
    ), ARRAY_A);
    $groups = array_keys(ma_note_group_labels());
    $days = [];
    for ($i = 0; $i < 14; $i++) {
        $d = gmdate('Y-m-d', $today - $i * DAY_IN_SECONDS);
        $days[$d] = ['day' => $d, 'total' => 0, 'failed' => 0] + array_fill_keys($groups, 0);
    }
    foreach ($rows as $r) {
        $d = gmdate('Y-m-d', strtotime($r['h'] . ':00:00 UTC') + $off);
        if (!isset($days[$d])) {
            continue;
        }
        $n = (int) $r['n'];
        if (in_array($r['status'], ['failed', 'no_device'], true)) {
            $days[$d]['failed'] += $n;
            continue;
        }
        $days[$d][ma_note_group($r['source'], $r['kind'])] += $n;
        $days[$d]['total'] += $n;
    }
    // Each notice: how many times the server sent it, and to how many phones.
    $runs = [];
    foreach ($wpdb->get_results('SELECT notice_id, COUNT(*) AS times, SUM(sent) AS sent, SUM(failed) AS failed, MAX(at) AS last FROM ' . ma_note_runs_table() . ' GROUP BY notice_id', ARRAY_A) as $r) {
        $runs[(int) $r['notice_id']] = ['times' => (int) $r['times'], 'sent' => (int) $r['sent'], 'failed' => (int) $r['failed'], 'last' => gmdate('c', ma_acc_ts($r['last']))];
    }
    $sessions = (int) $wpdb->get_var('SELECT COUNT(DISTINCT user_id) FROM ' . ma_ai_sessions_table() . " WHERE app <> 'admin' AND fcm_token <> '' AND expires_at > UTC_TIMESTAMP()");
    $new_app = (int) $wpdb->get_var('SELECT COUNT(DISTINCT user_id) FROM ' . ma_ai_sessions_table() . " WHERE app <> 'admin' AND srv_push = 1 AND fcm_token <> '' AND expires_at > UTC_TIMESTAMP()");
    return [
        'push_on' => $push_on,
        'phones' => $sessions,
        'phones_new_app' => $new_app,
        'upcoming' => $upcoming,
        'days' => array_values($days),
        'groups' => ma_note_group_labels(),
        'runs' => $runs,
    ];
}

/**
 * Every push notification the app itself sends a member (owner, 27 Oct, a
 * third time: "আমাদের এপ থেকে ইউজারের কাছে কি কি পুশ নোটিফিকেশন যায়, কখন
 * যায়, দিনে কয়টা"). Kept in step with lib/logic/proactive.dart by hand.
 * key = the kind the phone reports; at = usual time (for sorting); cap =
 * counted in the daily limit of 3; off = only when the member turns it on.
 */
function ma_note_catalog() {
    return [
        ['key' => 'nudge:bmi', 'at' => '07:30', 'label' => 'ওজনের ছোট ধাপ', 'sample' => 'আজ নিজের জন্য ছোট একটা ধাপ', 'when' => 'সোম আর বৃহস্পতিবার সকাল ৭:৩০ — ওজন স্বাভাবিকের বেশি থাকলে', 'cap' => true],
        ['key' => 'brief:morning', 'at' => '08:00', 'label' => 'সুপ্রভাত — আজকের সূচি', 'sample' => 'সুপ্রভাত! আজকের সূচি', 'when' => 'প্রতিদিন সকাল ৮টা (সদস্য সময় বদলাতে পারেন)', 'cap' => false],
        ['key' => 'nudge:fest', 'at' => '08:30', 'label' => 'উৎসবের শুভেচ্ছা', 'sample' => 'ঈদ মোবারক! / শুভ নববর্ষ!', 'when' => 'উৎসবের দিন সকাল ৮:৩০', 'cap' => true],
        ['key' => 'nudge:quote', 'at' => '09:15', 'label' => 'আজকের অর্থ-কথা', 'sample' => 'আজকের অর্থ-কথা', 'when' => 'প্রতিদিন সকাল ৯:১৫', 'cap' => false],
        ['key' => 'nudge:plan', 'at' => '09:15', 'label' => 'পরিকল্পনা জানতে চাওয়া', 'sample' => 'নতুন সপ্তাহ শুরু / নতুন মাস / কাল ছুটি / কালকের জন্য কিছু?', 'when' => 'রবিবার ৯:১৫, মাসের ১ তারিখ ৯:৩০, ছুটির আগের সন্ধ্যা ৮:৩০, রাত ৯:০৫', 'cap' => true],
        ['key' => 'nudge:due', 'at' => '10:00', 'label' => 'পাওনা টাকার তাগাদা', 'sample' => '…-এর কাছে … পাওনা', 'when' => 'সকাল ১০টা — শেষ লেনদেনের ৩০ দিন পর পর', 'cap' => true],
        ['key' => 'nudge:bill', 'at' => '10:00', 'label' => 'বিল/ভাড়ার শেষ দিন পরশু', 'sample' => '… — শেষ দিন পরশু', 'when' => 'সকাল ১০টা — শেষ দিনের দুই দিন আগে', 'cap' => true],
        ['key' => 'nudge:med', 'at' => '10:00', 'label' => 'ওষুধ ফুরিয়ে আসছে', 'sample' => '… আর … দিনের আছে', 'when' => 'সকাল ১০টা — ৫ দিন বা কম বাকি থাকলে', 'cap' => true],
        ['key' => 'nudge:doc', 'at' => '10:00', 'label' => 'কাগজের মেয়াদ ৬ মাস বাকি', 'sample' => '…-এর মেয়াদ ৬ মাস পর শেষ', 'when' => 'সকাল ১০টা — একবার', 'cap' => true],
        ['key' => 'nudge:fix', 'at' => '10:00', 'label' => 'ঘরের মেরামত বাকি', 'sample' => 'আজ ছুটির দিন — ঘরের …টা জিনিস ঠিক করা বাকি', 'when' => 'ছুটির দিন সকাল ১০টা — তালিকায় থাকলে', 'cap' => false],
        ['key' => 'nudge:soon', 'at' => '10:00', 'label' => 'ঈদ/রমজান ১০ দিন পর', 'sample' => 'ঈদুল আজহা আর ১০ দিন', 'when' => 'সকাল ১০টা — বছরে কয়েকবার', 'cap' => true],
        ['key' => 'nudge:week', 'at' => '10:00', 'label' => 'গত সপ্তাহের হিসাব', 'sample' => 'গত সপ্তাহের হিসাব', 'when' => 'শনিবার সকাল ১০টা', 'cap' => true],
        ['key' => 'nudge:donor', 'at' => '10:00', 'label' => 'আবার রক্ত দিতে পারবেন', 'sample' => 'আবার রক্ত দিতে পারবেন', 'when' => 'সময় হলে সকাল ১০টা — রক্তদাতা হলে', 'cap' => false],
        ['key' => 'nudge:health', 'at' => '10:30', 'label' => 'মৌসুমের স্বাস্থ্য পরামর্শ', 'sample' => 'এই মৌসুমের স্বাস্থ্য পরামর্শ', 'when' => 'মাসের প্রথম শনিবার সকাল ১০:৩০', 'cap' => true],
        ['key' => 'nudge:back', 'at' => '10:30', 'label' => 'কেমন আছেন?', 'sample' => 'কেমন আছেন?', 'when' => '৩ দিন অ্যাপ না খুললে সকাল ১০:৩০', 'cap' => true],
        ['key' => 'nudge:jumuah', 'at' => '11:00', 'label' => 'জুমা মোবারক', 'sample' => 'জুমা মোবারক!', 'when' => 'শুক্রবার সকাল ১১টা', 'cap' => true],
        ['key' => 'nudge:backup', 'at' => '11:30', 'label' => 'ব্যাকআপ নেওয়া হয়নি', 'sample' => '… দিন ব্যাকআপ নেওয়া হয়নি', 'when' => 'শুক্রবার ১১:৩০ — ৩০ দিন ব্যাকআপ না থাকলে', 'cap' => true],
        ['key' => 'nudge:day2', 'at' => '19:00', 'label' => 'পরশু জন্মদিন/বিবাহবার্ষিকী', 'sample' => 'পরশু …-এর জন্মদিন', 'when' => 'সন্ধ্যা ৭টা — দুই দিন আগে', 'cap' => true],
        ['key' => 'nudge:salary', 'at' => '19:00', 'label' => 'বেতন এসেছে — সঞ্চয়', 'sample' => 'বেতন এসেছে — …', 'when' => 'বেতন লেখার দিন সন্ধ্যা ৭টা', 'cap' => true],
        ['key' => 'nudge:spend', 'at' => '19:30', 'label' => 'কোনো খাতে খরচ বেশি', 'sample' => 'এ মাসে …-এ খরচ বেশি', 'when' => 'সন্ধ্যা ৭:৩০ — গত মাসের চেয়ে ২০% বেশি হলে', 'cap' => true],
        ['key' => 'nudge:habit', 'at' => '20:00', 'label' => 'অভ্যাসের ধারা', 'sample' => 'টানা … দিন — …', 'when' => 'রাত ৮টা — সেদিনেরটা না হলে', 'cap' => true],
        ['key' => 'brief:night', 'at' => '21:00', 'label' => 'রাতের সারাংশ — কাজ বাকি', 'sample' => 'আজ …টা কাজ বাকি রইল', 'when' => 'প্রতিদিন রাত ৯টা — কাজ বাকি থাকলে', 'cap' => false],
        ['key' => 'nudge:nocash', 'at' => '21:15', 'label' => 'আজকের খরচ লেখা হয়নি', 'sample' => 'আজকের খরচ লেখা হয়নি', 'when' => 'রাত ৯:১৫ — নিয়মিত লেখেন কিন্তু আজ লেখেননি', 'cap' => true],
        ['key' => 'nudge:prayer', 'at' => '', 'label' => 'নামাজের সময়', 'sample' => 'জোহর-এর সময় হয়েছে', 'when' => 'ওয়াক্ত শুরু হলে — সদস্য চালু করলে', 'cap' => false, 'off' => true],
        ['key' => 'nudge:ramadan', 'at' => '', 'label' => 'সেহরি আর ইফতার', 'sample' => 'সেহরির সময় / ইফতারের সময় হয়ে আসছে', 'when' => 'রমজানে — সদস্য চালু করলে', 'cap' => false, 'off' => true],
        ['key' => 'nudge:pro', 'at' => '', 'label' => 'প্রিমিয়াম চালু হয়েছে', 'sample' => 'প্রিমিয়াম চালু হয়েছে', 'when' => 'প্রিমিয়াম চালু হওয়ার সময় একবার', 'cap' => false],
    ];
}

/** Our server's own pushes (not planned by the phone). */
function ma_note_push_labels() {
    return [
        'news' => ['“এখনই পাঠান”', 'আপনি পাঠালে'],
        'pro' => ['প্রিমিয়াম চালু/মেয়াদ', 'প্রিমিয়াম চালু বা শেষ হলে'],
        'feedback' => ['মতামতের উত্তর', 'আপনি উত্তর দিলে'],
        'blood' => ['রক্তের অনুরোধ', 'কাছের কেউ রক্ত চাইলে'],
        'family' => ['ফ্যামিলি', 'পরিবারের কেউ কিছু ভাগ করলে'],
        'family_item' => ['ফ্যামিলি', 'পরিবারের কেউ কিছু ভাগ করলে'],
        'heir_claim' => ['উত্তরাধিকার', 'কেউ দাবি করলে'],
        'test' => ['পরীক্ষা', 'পরীক্ষার পুশ'],
    ];
}

/**
 * One day: every notification the app sends a member — what, when (the
 * rule), and how many went that day and to how many members; then how many
 * each member got. Members' own reminders are theirs, not the app's: one
 * line, a count only. $day 'Y-m-d' in site time (default today).
 */
function ma_note_day($day = '') {
    global $wpdb;
    $off = ma_acc_tz_off();
    $day = preg_match('/^\d{4}-\d{2}-\d{2}$/', (string) $day) ? $day : gmdate('Y-m-d', time() + $off);
    $from = gmdate('Y-m-d H:i:s', strtotime($day . ' 00:00:00 UTC') - $off);
    $to = gmdate('Y-m-d H:i:s', strtotime($day . ' 00:00:00 UTC') + DAY_IN_SECONDS - $off);
    $now = gmdate('Y-m-d H:i');
    $t = ma_nlog_table();
    $rows = $wpdb->get_results($wpdb->prepare(
        "SELECT source, kind, title, SUBSTR(at, 1, 16) AS m, status, COUNT(*) AS n, COUNT(DISTINCT user_id) AS people FROM $t WHERE at >= %s AND at < %s GROUP BY source, kind, title, SUBSTR(at, 1, 16), status",
        $from, $to
    ), ARRAY_A);
    $people = $wpdb->get_results($wpdb->prepare(
        "SELECT source, kind, title, COUNT(DISTINCT user_id) AS people FROM $t WHERE at >= %s AND at < %s AND status NOT IN ('failed', 'no_device') GROUP BY source, kind, title",
        $from, $to
    ), ARRAY_A);

    // Every kind the app has, in the order of its usual time; counts filled in below.
    $app = [];
    foreach (ma_note_catalog() as $c) {
        $app[$c['key']] = $c + ['by' => 'phone', 'title' => '', 'count' => 0, 'people' => 0, 'failed' => 0, 'ahead' => 0, 'times' => [], 'off' => $c['off'] ?? false];
    }
    $rem = ['count' => 0, 'people' => 0, 'ahead' => 0];
    $rem_people = 0;
    $key_of = function ($source, $kind, $title) {
        if ($source === 'push' && $kind !== 'server') {
            return 'push:' . $kind;
        }
        if ($kind === 'server' || str_starts_with($kind, 'nudge:srv') || str_starts_with($kind, 'nudge:plan:srv')) {
            return 'server:' . $title;
        }
        if (str_starts_with($kind, 'reminder')) {
            return 'reminder';
        }
        foreach (ma_note_catalog() as $c) {
            if ($kind === $c['key'] || str_starts_with($kind, $c['key'] . ':')) {
                return $c['key'];
            }
        }
        return 'other';
    };
    foreach ($rows as $r) {
        $k = $key_of($r['source'], $r['kind'], (string) $r['title']);
        $n = (int) $r['n'];
        $bad = in_array($r['status'], ['failed', 'no_device'], true);
        $ahead = $r['m'] > $now;
        if ($k === 'reminder') {
            if (!$bad) {
                $rem['count'] += $n;
                $rem['ahead'] += $ahead ? $n : 0;
            }
            continue;
        }
        if (!isset($app[$k])) {
            if (str_starts_with($k, 'server:')) {
                $app[$k] = ['key' => $k, 'at' => '', 'label' => 'সাইটের নোটিফিকেশন', 'sample' => (string) $r['title'], 'when' => 'আপনি সাইট থেকে যে সময় ঠিক করেছেন', 'cap' => false];
            } elseif (str_starts_with($k, 'push:')) {
                $pl = ma_note_push_labels()[substr($k, 5)] ?? [ma_nlog_kind_label(substr($k, 5)), 'সার্ভার থেকে'];
                $app[$k] = ['key' => $k, 'at' => '', 'label' => $pl[0], 'sample' => (string) $r['title'], 'when' => $pl[1], 'cap' => false];
            } else {
                $app[$k] = ['key' => $k, 'at' => '', 'label' => 'অন্যান্য মনে করানো', 'sample' => '', 'when' => 'পুরোনো অ্যাপ বা নতুন ধরন', 'cap' => true];
            }
            $app[$k] += ['by' => $r['source'] === 'push' ? 'server' : 'phone', 'title' => '', 'count' => 0, 'people' => 0, 'failed' => 0, 'ahead' => 0, 'times' => [], 'off' => false];
        }
        if ($r['source'] === 'push') {
            $app[$k]['by'] = 'server';
        }
        if ($bad) {
            $app[$k]['failed'] += $n;
            continue;
        }
        $app[$k]['count'] += $n;
        $app[$k]['ahead'] += $ahead ? $n : 0;
        $hm = gmdate('H:i', strtotime($r['m'] . ':00 UTC') + $off);
        $app[$k]['times'][$hm] = ($app[$k]['times'][$hm] ?? 0) + $n;
    }
    foreach ($people as $p) {
        $k = $key_of($p['source'], $p['kind'], (string) $p['title']);
        if ($k === 'reminder') {
            $rem_people = max($rem_people, (int) $p['people']);
        } elseif (isset($app[$k])) {
            $app[$k]['people'] = max($app[$k]['people'], (int) $p['people']);
        }
    }
    $rem['people'] = (int) $wpdb->get_var($wpdb->prepare(
        "SELECT COUNT(DISTINCT user_id) FROM $t WHERE at >= %s AND at < %s AND kind LIKE 'reminder%%' AND status NOT IN ('failed', 'no_device')",
        $from, $to
    ));
    $list = [];
    foreach ($app as $a) {
        // The busiest times first (at most 4), then in order.
        arsort($a['times']);
        $times = array_slice(array_keys($a['times']), 0, 4);
        sort($times);
        $a['times'] = $times;
        if ($a['at'] === '' && $times) {
            $a['at'] = $times[0];
        }
        $list[] = $a;
    }
    usort($list, fn($a, $b) => (($b['count'] > 0) <=> ($a['count'] > 0)) ?: strcmp($a['at'] === '' ? '99' : $a['at'], $b['at'] === '' ? '99' : $b['at']));

    // How many the app sends each member that day (reminders counted apart).
    $per = $wpdb->get_results($wpdb->prepare(
        "SELECT l.user_id, u.name, u.email,
            SUM(CASE WHEN l.kind NOT LIKE 'reminder%%' AND l.status NOT IN ('failed', 'no_device') THEN 1 ELSE 0 END) AS n,
            SUM(CASE WHEN l.kind LIKE 'reminder%%' AND l.status NOT IN ('failed', 'no_device') THEN 1 ELSE 0 END) AS r,
            SUM(CASE WHEN l.status IN ('failed', 'no_device') THEN 1 ELSE 0 END) AS failed
         FROM $t l LEFT JOIN " . ma_acc_table() . " u ON u.id = l.user_id WHERE l.at >= %s AND l.at < %s GROUP BY l.user_id, u.name, u.email ORDER BY n DESC, r DESC LIMIT 500",
        $from, $to
    ), ARRAY_A);
    $members = [];
    $total = 0;
    foreach ($per as $p) {
        $n = (int) $p['n'];
        $total += $n;
        $members[] = ['user_id' => (int) $p['user_id'], 'name' => (string) $p['name'], 'email' => (string) $p['email'], 'count' => $n, 'reminders' => (int) $p['r'], 'failed' => (int) $p['failed']];
    }
    $with = array_filter($members, fn($m) => $m['count'] > 0);
    return [
        'day' => $day,
        'app' => $list,
        'reminders' => $rem,
        'members' => $members,
        'total' => $total,
        'people' => count($with),
        'avg' => $with ? round($total / count($with), 1) : 0,
        'max' => $with ? max(array_column($with, 'count')) : 0,
        'rules' => [
            'cap' => 3,
            'quiet' => 'রাত ১০টা থেকে সকাল ৭টা',
            'daily' => 'প্রতিদিন নিশ্চিত: সুপ্রভাত (৮টা) আর অর্থ-কথা (৯:১৫); কাজ বাকি থাকলে রাতের সারাংশ (৯টা)। বাকি মনে করানো দিনে সর্বোচ্চ ৩টি।',
        ],
    ];
}

// ── Controlling the app's own notifications (owner, 27 Oct: "সার্ভার বা
// এডমিন এপ থেকে নোটিফিকেশন নিয়ন্ত্রণ — কোনগুলো যাবে, লেখার ধরণ, সময়, কোন
// ধরনের ইউজার পাবে") ──
//
// One rule per kind of the catalog: on/off, a clock time, a title and text
// written as templates ({title} {body} {name} = what the app would have
// said), and who gets it — decided on each phone from how it is used, so
// nothing about the member's use leaves the phone. Plus at most how many
// reminders a day. A member's own settings still win (one they turned off
// stays off).

/** Who: decided on the phone. */
function ma_note_who_options() {
    return [
        'all' => 'সবাই',
        'new' => 'নতুন (প্রথম ৭ দিন)',
        'old' => 'পুরোনো (৮ দিন বা বেশি)',
        'regular' => 'নিয়মিত (১৪ দিনে ৫ দিন বা বেশি খোলেন)',
        'occasional' => 'মাঝে মাঝে (১৪ দিনে ৫ দিনের কম খোলেন)',
        'free' => 'ফ্রি',
        'pro' => 'প্রিমিয়াম',
    ];
}

function ma_note_rules() {
    $saved = get_option('ma_note_rules', []);
    $saved = is_array($saved) ? $saved : [];
    $kinds = [];
    foreach (ma_note_catalog() as $c) {
        $r = is_array($saved['kinds'][$c['key']] ?? null) ? $saved['kinds'][$c['key']] : [];
        $kinds[$c['key']] = [
            'on' => !array_key_exists('on', $r) || !empty($r['on']),
            'at' => (string) ($r['at'] ?? ''),
            'title' => (string) ($r['title'] ?? ''),
            'body' => (string) ($r['body'] ?? ''),
            'who' => isset(ma_note_who_options()[$r['who'] ?? '']) ? $r['who'] : 'all',
        ];
    }
    $cap = $saved['cap'] ?? null;
    return ['kinds' => $kinds, 'cap' => is_numeric($cap) ? max(0, min(10, (int) $cap)) : null];
}

/** Saves what an admin sent (only known kinds and fields, each checked). */
function ma_note_rules_save(array $in) {
    $known = array_column(ma_note_catalog(), 'key');
    $out = ['kinds' => [], 'cap' => null];
    foreach ((array) ($in['kinds'] ?? []) as $k => $r) {
        if (!in_array($k, $known, true) || !is_array($r)) {
            continue;
        }
        $at = (string) ($r['at'] ?? '');
        $out['kinds'][$k] = [
            'on' => !empty($r['on']),
            'at' => preg_match('/^([01]\d|2[0-3]):[0-5]\d$/', $at) ? $at : '',
            'title' => mb_substr(sanitize_text_field((string) ($r['title'] ?? '')), 0, 80),
            'body' => mb_substr(sanitize_textarea_field((string) ($r['body'] ?? '')), 0, 240),
            'who' => isset(ma_note_who_options()[$r['who'] ?? '']) ? $r['who'] : 'all',
        ];
    }
    $cap = $in['cap'] ?? '';
    $out['cap'] = is_numeric($cap) && $cap !== '' ? max(0, min(10, (int) $cap)) : null;
    update_option('ma_note_rules', $out, false);
    return ma_note_rules();
}

/** What phones get: only the rules that differ from the app's own way. */
function ma_note_rules_public() {
    $r = ma_note_rules();
    $kinds = [];
    foreach ($r['kinds'] as $k => $x) {
        if (!$x['on'] || $x['at'] !== '' || $x['title'] !== '' || $x['body'] !== '' || $x['who'] !== 'all') {
            $kinds[$k] = $x;
        }
    }
    return ['kinds' => (object) $kinds, 'cap' => $r['cap']];
}

/** For the site page and the admin app: each kind with its rule. */
function ma_note_rules_view() {
    $r = ma_note_rules();
    $rows = [];
    foreach (ma_note_catalog() as $c) {
        $rows[] = ['key' => $c['key'], 'label' => $c['label'], 'sample' => $c['sample'], 'when' => $c['when'], 'default_at' => $c['at'], 'cap' => $c['cap'], 'off_by_default' => !empty($c['off'])] + $r['kinds'][$c['key']];
    }
    return ['kinds' => $rows, 'cap' => $r['cap'], 'who' => ma_note_who_options()];
}

add_action('admin_post_ma_note_rules', function () {
    ma_acc_guard('ma_note_rules');
    $post = wp_unslash($_POST);
    $kinds = [];
    foreach (ma_note_catalog() as $c) {
        $f = $post['r'][$c['key']] ?? [];
        $kinds[$c['key']] = ['on' => !empty($f['on']), 'at' => $f['at'] ?? '', 'title' => $f['title'] ?? '', 'body' => $f['body'] ?? '', 'who' => $f['who'] ?? 'all'];
    }
    ma_note_rules_save(['kinds' => $kinds, 'cap' => $post['cap'] ?? '']);
    ma_acc_back('নোটিফিকেশনের নিয়ম রাখা হয়েছে — সদস্যদের ফোন পরের বার খুললে বা কয়েক ঘণ্টার মধ্যে মানবে।', 'ok', ['tab' => 'notices']);
});

add_action('rest_api_init', function () {
    ma_admin_route('/notice-rules', 'GET', function () {
        return ma_note_rules_view();
    });
    ma_admin_route('/notice-rules', 'POST', function (WP_REST_Request $req) {
        ma_note_rules_save((array) $req->get_json_params());
        return ma_note_rules_view();
    });
});

/** The site's notifications tab: the rules, one row per kind. */
function ma_note_render_rules() {
    $v = ma_note_rules_view();
    $who = $v['who'];
    $post = esc_url(admin_url('admin-post.php'));
    ?>
    <section class="ma-card" id="ma-rules">
        <div class="ma-bar"><div class="ma-bar-title"><h2>অ্যাপের নোটিফিকেশন নিয়ন্ত্রণ</h2><span class="ma-count">কোনটা যাবে, কখন, কোন লেখায়, কারা পাবেন</span></div></div>
        <p class="muted ma-pad">সময় খালি রাখলে অ্যাপের নিজের সময়। লেখায় <code>{title}</code> = অ্যাপ যা লিখত, <code>{body}</code> = অ্যাপের বিস্তারিত (যেমন আজকের সূচি), <code>{name}</code> = সদস্যের নাম। খালি রাখলে অ্যাপের নিজের লেখা। “কারা পাবেন” প্রতিটা ফোন নিজেই ঠিক করে — কে কতদিন অ্যাপ খোলেন তা সার্ভারে আসে না। সদস্য নিজে কোনোটা বন্ধ করে থাকলে সেটা বন্ধই থাকে।</p>
        <form method="post" action="<?php echo $post; ?>">
            <input type="hidden" name="action" value="ma_note_rules"><?php wp_nonce_field('ma_note_rules'); ?>
            <div class="ma-table-wrap">
                <table class="ma-table ma-rules">
                    <thead><tr><th>চালু</th><th>নোটিফিকেশন</th><th>সময়</th><th>শিরোনাম</th><th>লেখা</th><th>কারা পাবেন</th></tr></thead>
                    <tbody>
                    <?php foreach ($v['kinds'] as $k) : $n = 'r[' . esc_attr($k['key']) . ']'; ?>
                        <tr class="<?php echo $k['on'] ? '' : 'ma-dim'; ?>">
                            <td><input type="checkbox" name="<?php echo $n; ?>[on]" value="1" <?php checked($k['on']); ?> aria-label="চালু"></td>
                            <td><strong><?php echo esc_html($k['label']); ?></strong><span class="ma-ver"><?php echo esc_html($k['when']); ?></span></td>
                            <td><input type="time" name="<?php echo $n; ?>[at]" value="<?php echo esc_attr($k['at']); ?>" placeholder="<?php echo esc_attr($k['default_at']); ?>" style="width:110px"></td>
                            <td><input type="text" name="<?php echo $n; ?>[title]" value="<?php echo esc_attr($k['title']); ?>" placeholder="<?php echo esc_attr($k['sample']); ?>" maxlength="80"></td>
                            <td><input type="text" name="<?php echo $n; ?>[body]" value="<?php echo esc_attr($k['body']); ?>" placeholder="{body}" maxlength="240"></td>
                            <td><select name="<?php echo $n; ?>[who]"><?php foreach ($who as $wk => $wl) : ?><option value="<?php echo esc_attr($wk); ?>" <?php selected($k['who'], $wk); ?>><?php echo esc_html($wl); ?></option><?php endforeach; ?></select></td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
            <div class="ma-pad" style="display:flex;gap:12px;align-items:center;flex-wrap:wrap">
                <label>দিনে সর্বোচ্চ মনে করানো (সারাংশ, অর্থ-কথা বাদে): <input type="number" name="cap" min="0" max="10" value="<?php echo esc_attr($v['cap'] ?? ''); ?>" placeholder="৩" style="width:70px"></label>
                <button class="ma-btn" type="submit">নিয়ম রাখুন</button>
            </div>
        </form>
    </section>
    <?php
}
