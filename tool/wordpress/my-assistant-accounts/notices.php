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
    $member = ma_ai_member($req);
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
    }
    $res = new WP_REST_Response(['notices' => $out], 200);
    $res->header('Cache-Control', 'private, max-age=600');
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
