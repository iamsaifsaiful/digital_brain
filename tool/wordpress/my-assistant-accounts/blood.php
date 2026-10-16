<?php
/**
 * অনুরোধ — blood requests between members. A member asks for blood (group,
 * bags, hospital, district, by when, a contact number); members who chose
 * to be donors, in the same district and with a group that can give, get a
 * push and see it. A donor taps "আমি দিতে পারব": the asker sees the donor's
 * name and number. Donors share only their group, district, last donation
 * day and (if they wish) a number — and only after opting in.
 */

if (!defined('ABSPATH')) {
    exit;
}

function ma_bl_donors() {
    global $wpdb;
    return $wpdb->prefix . 'ma_donors';
}

function ma_bl_reqs() {
    global $wpdb;
    return $wpdb->prefix . 'ma_blood_requests';
}

function ma_bl_accepts() {
    global $wpdb;
    return $wpdb->prefix . 'ma_blood_accepts';
}

function ma_bl_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $cs = $wpdb->get_charset_collate();
    dbDelta('CREATE TABLE ' . ma_bl_donors() . " (
        user_id bigint(20) unsigned NOT NULL,
        blood varchar(4) NOT NULL DEFAULT '',
        district varchar(64) NOT NULL DEFAULT '',
        last_donated date NULL DEFAULT NULL,
        phone varchar(20) NOT NULL DEFAULT '',
        active tinyint(1) NOT NULL DEFAULT 1,
        updated_at datetime NOT NULL,
        PRIMARY KEY  (user_id),
        KEY place (district, blood, active)
    ) $cs;");
    dbDelta('CREATE TABLE ' . ma_bl_reqs() . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        user_id bigint(20) unsigned NOT NULL,
        patient varchar(120) NOT NULL DEFAULT '',
        blood varchar(4) NOT NULL,
        bags tinyint unsigned NOT NULL DEFAULT 1,
        district varchar(64) NOT NULL,
        hospital varchar(190) NOT NULL DEFAULT '',
        need_by datetime NOT NULL,
        phone varchar(20) NOT NULL,
        note varchar(500) NOT NULL DEFAULT '',
        status varchar(12) NOT NULL DEFAULT 'open',
        notified int unsigned NOT NULL DEFAULT 0,
        created_at datetime NOT NULL,
        PRIMARY KEY  (id),
        KEY open_place (status, district),
        KEY user_id (user_id)
    ) $cs;");
    dbDelta('CREATE TABLE ' . ma_bl_accepts() . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        request_id bigint(20) unsigned NOT NULL,
        user_id bigint(20) unsigned NOT NULL,
        phone varchar(20) NOT NULL DEFAULT '',
        note varchar(300) NOT NULL DEFAULT '',
        status varchar(12) NOT NULL DEFAULT 'accepted',
        created_at datetime NOT NULL,
        PRIMARY KEY  (id),
        UNIQUE KEY one (request_id, user_id)
    ) $cs;");
}

const MA_BL_GROUPS = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

/** For a patient's group, the donor groups that can give. */
function ma_bl_can_give_to($patient) {
    return [
        'O-' => ['O-'],
        'O+' => ['O-', 'O+'],
        'A-' => ['O-', 'A-'],
        'A+' => ['O-', 'O+', 'A-', 'A+'],
        'B-' => ['O-', 'B-'],
        'B+' => ['O-', 'O+', 'B-', 'B+'],
        'AB-' => ['O-', 'A-', 'B-', 'AB-'],
        'AB+' => MA_BL_GROUPS,
    ][$patient] ?? [];
}

/** "B+", "b +", "B−" → "B+"; anything else ''. */
function ma_bl_group($g) {
    $g = strtoupper(str_replace(['−', '–', ' '], ['-', '-', ''], (string) $g));
    return in_array($g, MA_BL_GROUPS, true) ? $g : '';
}

/** A Bangladeshi mobile number as 01XXXXXXXXX, or ''. */
function ma_bl_phone($p) {
    $d = preg_replace('/\D+/', '', strtr((string) $p, ['০' => '0', '১' => '1', '২' => '2', '৩' => '3', '৪' => '4', '৫' => '5', '৬' => '6', '৭' => '7', '৮' => '8', '৯' => '9']));
    if (str_starts_with($d, '880')) {
        $d = substr($d, 2);
    }
    return preg_match('/^01[3-9]\d{8}$/', $d) ? $d : '';
}

function ma_bl_district($d) {
    return mb_substr(trim(sanitize_text_field((string) $d)), 0, 64);
}

/** Who a member is to others: first name only. */
function ma_bl_first_name($name, $email) {
    $n = trim((string) $name);
    return $n !== '' ? preg_split('/\s+/u', $n)[0] : strstr((string) $email, '@', true);
}

/** Open requests whose day has not long passed. */
function ma_bl_open_sql() {
    return "r.status = 'open' AND r.need_by > DATE_SUB(UTC_TIMESTAMP(), INTERVAL 1 DAY)";
}

function ma_bl_req_json($r, $me, $with_accepts = false) {
    global $wpdb;
    $mine = (int) $r['user_id'] === (int) $me['id'];
    $acc = $wpdb->get_results($wpdb->prepare('SELECT a.*, u.name, u.email FROM ' . ma_bl_accepts() . ' a JOIN ' . ma_acc_table() . " u ON u.id = a.user_id WHERE a.request_id = %d AND a.status = 'accepted' ORDER BY a.id", $r['id']), ARRAY_A);
    $out = [
        'id' => (int) $r['id'],
        'mine' => $mine,
        'by' => ma_bl_first_name($r['asker_name'] ?? '', $r['asker_email'] ?? ''),
        'patient' => $r['patient'],
        'blood' => $r['blood'],
        'bags' => (int) $r['bags'],
        'district' => $r['district'],
        'hospital' => $r['hospital'],
        'need_by' => gmdate('c', ma_acc_ts($r['need_by'])),
        'phone' => $r['phone'],
        'note' => $r['note'],
        'status' => $r['status'] === 'open' && ma_acc_ts($r['need_by']) < time() - DAY_IN_SECONDS ? 'expired' : $r['status'],
        'created' => gmdate('c', ma_acc_ts($r['created_at'])),
        'accepted' => count($acc),
        'i_accepted' => (bool) array_filter($acc, fn($a) => (int) $a['user_id'] === (int) $me['id']),
    ];
    // Donors' names and numbers: only for the one who asked.
    if ($mine && $with_accepts) {
        $out['donors'] = array_map(fn($a) => ['name' => ma_bl_first_name($a['name'], $a['email']), 'phone' => $a['phone'], 'note' => $a['note'], 'at' => gmdate('c', ma_acc_ts($a['created_at']))], $acc);
    }
    return $out;
}

function ma_bl_member(WP_REST_Request $req) {
    $m = ma_ai_member($req);
    return $m ?: new WP_Error('session', 'sign in again', ['status' => 401]);
}

add_action('rest_api_init', function () {
    $open = '__return_true'; // the member session is checked inside
    register_rest_route('my-assistant/v1', '/blood/donor', [
        ['methods' => 'GET', 'callback' => 'ma_bl_donor_get', 'permission_callback' => $open],
        ['methods' => 'POST', 'callback' => 'ma_bl_donor_set', 'permission_callback' => $open],
    ]);
    register_rest_route('my-assistant/v1', '/blood/requests', [
        ['methods' => 'GET', 'callback' => 'ma_bl_list', 'permission_callback' => $open],
        ['methods' => 'POST', 'callback' => 'ma_bl_ask', 'permission_callback' => $open],
    ]);
    register_rest_route('my-assistant/v1', '/blood/requests/(?P<id>\d+)/(?P<what>accept|withdraw|close)', [
        'methods' => 'POST', 'callback' => 'ma_bl_act', 'permission_callback' => $open,
    ]);
});

function ma_bl_donor_row($user_id) {
    global $wpdb;
    return $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_bl_donors() . ' WHERE user_id = %d', $user_id), ARRAY_A);
}

function ma_bl_donor_json($d) {
    return $d ? ['on' => (bool) (int) $d['active'], 'blood' => $d['blood'], 'district' => $d['district'], 'last_donated' => $d['last_donated'], 'phone' => $d['phone']] : ['on' => false];
}

function ma_bl_donor_get(WP_REST_Request $req) {
    $m = ma_bl_member($req);
    return is_wp_error($m) ? $m : ['donor' => ma_bl_donor_json(ma_bl_donor_row((int) $m['id']))];
}

/** Opting in or out as a donor. Off removes the details, not just hides them. */
function ma_bl_donor_set(WP_REST_Request $req) {
    global $wpdb;
    $m = ma_bl_member($req);
    if (is_wp_error($m)) {
        return $m;
    }
    if (!$req->get_param('on')) {
        $wpdb->delete(ma_bl_donors(), ['user_id' => (int) $m['id']]);
        return ['donor' => ['on' => false]];
    }
    $blood = ma_bl_group($req->get_param('blood'));
    $district = ma_bl_district($req->get_param('district'));
    if ($blood === '' || $district === '') {
        return new WP_Error('bad', 'blood group and district needed', ['status' => 400]);
    }
    $last = (string) $req->get_param('last_donated');
    $last = preg_match('/^\d{4}-\d{2}-\d{2}$/', $last) && strtotime($last) <= time() ? $last : null;
    $wpdb->replace(ma_bl_donors(), [
        'user_id' => (int) $m['id'],
        'blood' => $blood,
        'district' => $district,
        'last_donated' => $last,
        'phone' => ma_bl_phone($req->get_param('phone')),
        'active' => 1,
        'updated_at' => current_time('mysql', true),
    ]);
    return ['donor' => ma_bl_donor_json(ma_bl_donor_row((int) $m['id']))];
}

/**
 * scope=near (default): open requests in the member's district (donor
 * profile, or ?district=) that their group can give to; scope=district: all
 * open ones there; scope=mine: the member's own, with the donors who said yes.
 */
function ma_bl_list(WP_REST_Request $req) {
    global $wpdb;
    $m = ma_bl_member($req);
    if (is_wp_error($m)) {
        return $m;
    }
    $r = ma_bl_reqs();
    $u = ma_acc_table();
    $sel = "SELECT r.*, u.name asker_name, u.email asker_email FROM $r r JOIN $u u ON u.id = r.user_id";
    $scope = sanitize_key($req->get_param('scope') ?: 'near');
    if ($scope === 'mine') {
        $rows = $wpdb->get_results($wpdb->prepare("$sel WHERE r.user_id = %d ORDER BY r.id DESC LIMIT 30", $m['id']), ARRAY_A);
        return ['requests' => array_map(fn($x) => ma_bl_req_json($x, $m, true), $rows)];
    }
    $donor = ma_bl_donor_row((int) $m['id']);
    $district = ma_bl_district($req->get_param('district') ?: ($donor['district'] ?? ''));
    if ($district === '') {
        return ['requests' => [], 'district' => ''];
    }
    $rows = $wpdb->get_results($wpdb->prepare("$sel WHERE " . ma_bl_open_sql() . ' AND r.district = %s ORDER BY r.need_by ASC LIMIT 60', $district), ARRAY_A);
    $group = ma_bl_group($req->get_param('blood') ?: ($donor['blood'] ?? ''));
    if ($scope !== 'district' && $group !== '') {
        $rows = array_values(array_filter($rows, fn($x) => in_array($group, ma_bl_can_give_to($x['blood']), true)));
    }
    return ['requests' => array_map(fn($x) => ma_bl_req_json($x, $m), $rows), 'district' => $district, 'blood' => $group];
}

function ma_bl_ask(WP_REST_Request $req) {
    global $wpdb;
    $m = ma_bl_member($req);
    if (is_wp_error($m)) {
        return $m;
    }
    $blood = ma_bl_group($req->get_param('blood'));
    $district = ma_bl_district($req->get_param('district'));
    $phone = ma_bl_phone($req->get_param('phone'));
    $need = strtotime((string) $req->get_param('need_by'));
    $bags = max(1, min(10, (int) $req->get_param('bags')));
    if ($blood === '' || $district === '' || $phone === '' || !$need || $need < time() - HOUR_IN_SECONDS || $need > time() + 30 * DAY_IN_SECONDS) {
        return new WP_Error('bad', 'group, district, a mobile number and a day within 30 days are needed', ['status' => 400]);
    }
    $r = ma_bl_reqs();
    $open = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $r r WHERE r.user_id = %d AND " . ma_bl_open_sql(), $m['id']));
    if ($open >= 3) {
        return new WP_Error('busy', 'at most 3 open requests', ['status' => 429]);
    }
    $wpdb->insert($r, [
        'user_id' => (int) $m['id'],
        'patient' => mb_substr(sanitize_text_field((string) $req->get_param('patient')), 0, 120),
        'blood' => $blood,
        'bags' => $bags,
        'district' => $district,
        'hospital' => mb_substr(sanitize_text_field((string) $req->get_param('hospital')), 0, 190),
        'need_by' => gmdate('Y-m-d H:i:s', $need),
        'phone' => $phone,
        'note' => mb_substr(sanitize_textarea_field((string) $req->get_param('note')), 0, 500),
        'status' => 'open',
        'created_at' => current_time('mysql', true),
    ]);
    $id = (int) $wpdb->insert_id;
    $sent = ma_bl_notify_donors($id, $m);
    $wpdb->update($r, ['notified' => $sent], ['id' => $id]);
    return ['ok' => true, 'id' => $id, 'notified' => $sent];
}

/**
 * Push to donors who can give: same district, a group that fits, opted in,
 * not the asker, and not within 90 days of their last donation. A donor gets
 * at most 3 such pushes a day.
 */
function ma_bl_notify_donors($id, $asker) {
    global $wpdb;
    $req = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_bl_reqs() . ' WHERE id = %d', $id), ARRAY_A);
    $groups = ma_bl_can_give_to($req['blood']);
    if (!$groups) {
        return 0;
    }
    $in = implode(',', array_fill(0, count($groups), '%s'));
    $cutoff = gmdate('Y-m-d', time() - 90 * DAY_IN_SECONDS);
    $donors = $wpdb->get_col($wpdb->prepare(
        'SELECT user_id FROM ' . ma_bl_donors() . " WHERE active = 1 AND district = %s AND blood IN ($in) AND user_id <> %d AND (last_donated IS NULL OR last_donated <= %s) LIMIT 500",
        array_merge([$req['district']], $groups, [(int) $asker['id'], $cutoff])
    ));
    $title = $req['blood'] . ' রক্ত দরকার — ' . $req['district'];
    $body = trim(($req['hospital'] !== '' ? $req['hospital'] . ' · ' : '') . ma_acc_bn($req['bags']) . ' ব্যাগ · চাপ দিয়ে দেখুন');
    $sent = 0;
    foreach ($donors as $uid) {
        $k = 'ma_bl_push_' . $uid . '_' . gmdate('Ymd');
        $n = (int) get_transient($k);
        if ($n >= 3) {
            continue;
        }
        set_transient($k, $n + 1, DAY_IN_SECONDS);
        if (ma_push_member((int) $uid, $title, $body, ['type' => 'blood', 'id' => (string) $id])) {
            $sent++;
        }
    }
    return $sent;
}

function ma_bl_act(WP_REST_Request $req) {
    global $wpdb;
    $m = ma_bl_member($req);
    if (is_wp_error($m)) {
        return $m;
    }
    $r = $wpdb->get_row($wpdb->prepare('SELECT r.*, u.name asker_name, u.email asker_email FROM ' . ma_bl_reqs() . ' r JOIN ' . ma_acc_table() . ' u ON u.id = r.user_id WHERE r.id = %d', (int) $req['id']), ARRAY_A);
    if (!$r) {
        return new WP_Error('none', 'not found', ['status' => 404]);
    }
    $mine = (int) $r['user_id'] === (int) $m['id'];
    switch ($req['what']) {
        case 'close':
            if (!$mine) {
                return new WP_Error('not_yours', 'only the asker', ['status' => 403]);
            }
            $st = $req->get_param('status') === 'cancelled' ? 'cancelled' : 'done';
            $wpdb->update(ma_bl_reqs(), ['status' => $st], ['id' => $r['id']]);
            $r['status'] = $st;
            return ['ok' => true, 'request' => ma_bl_req_json($r, $m, true)];
        case 'withdraw':
            $wpdb->update(ma_bl_accepts(), ['status' => 'withdrawn'], ['request_id' => $r['id'], 'user_id' => $m['id']]);
            return ['ok' => true, 'request' => ma_bl_req_json($r, $m)];
        default: // accept
            if ($mine) {
                return new WP_Error('own', 'your own request', ['status' => 400]);
            }
            if ($r['status'] !== 'open' || ma_acc_ts($r['need_by']) < time() - DAY_IN_SECONDS) {
                return new WP_Error('closed', 'no longer open', ['status' => 409]);
            }
            $donor = ma_bl_donor_row((int) $m['id']);
            $phone = ma_bl_phone($req->get_param('phone')) ?: ($donor['phone'] ?? '');
            if ($phone === '') {
                return new WP_Error('phone', 'a mobile number is needed', ['status' => 400]);
            }
            $wpdb->replace(ma_bl_accepts(), [
                'request_id' => (int) $r['id'],
                'user_id' => (int) $m['id'],
                'phone' => $phone,
                'note' => mb_substr(sanitize_text_field((string) $req->get_param('note')), 0, 300),
                'status' => 'accepted',
                'created_at' => current_time('mysql', true),
            ]);
            ma_push_member((int) $r['user_id'], ma_bl_first_name($m['name'], $m['email']) . ' রক্ত দিতে রাজি', $r['blood'] . ' · ' . $phone . ' — চাপ দিয়ে দেখুন', ['type' => 'blood', 'id' => (string) $r['id']]);
            return ['ok' => true, 'request' => ma_bl_req_json($r, $m)];
    }
}
