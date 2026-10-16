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
}

function ma_note_options() {
    return [
        'kind' => ['once' => 'একবার', 'daily' => 'প্রতিদিন', 'weekly' => 'প্রতি সপ্তাহে'],
        'audience' => ['all' => 'সবাই', 'pro' => 'প্রো', 'trial' => 'ট্রায়ালে', 'free' => 'ফ্রি'],
        'cond' => ['' => 'সবসময়', 'no_tasks' => 'সেদিন কাজের তালিকা না থাকলে', 'no_spending' => 'সেদিন খরচ লেখা না হলে', 'not_opened' => 'সেদিন অ্যাপ না খুললে'],
        'weekday' => [6 => 'শনিবার', 7 => 'রবিবার', 1 => 'সোমবার', 2 => 'মঙ্গলবার', 3 => 'বুধবার', 4 => 'বৃহস্পতিবার', 5 => 'শুক্রবার'],
    ];
}

add_action('rest_api_init', function () {
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
