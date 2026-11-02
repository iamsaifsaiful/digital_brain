<?php
/**
 * Admins and agents, managed from the app by any admin. The main admin
 * (owner) is set only on the WordPress settings page and cannot be changed
 * or turned off from the app.
 */

if (!defined('ABSPATH')) {
    exit;
}

add_action('rest_api_init', function () {
    rh_route('/users', 'GET', 'rh_users_list', 'admin');
    rh_route('/users', 'POST', 'rh_users_add', 'admin');
    rh_route('/users/update', 'POST', 'rh_users_update', 'admin');
    rh_route('/users/delete', 'POST', 'rh_users_delete', 'admin');
});

/** An admin can give another admin only what they have themselves. */
function rh_perms_from($req_perms, $u) {
    $want = is_array($req_perms) ? array_map('strval', $req_perms) : [];
    return array_values(array_intersect(array_keys(RH_PERMS), $want, rh_perms($u)));
}

function rh_users_list(WP_REST_Request $req, $u) {
    global $wpdb;
    $rows = $wpdb->get_results('SELECT * FROM ' . rh_t('users') . ' ORDER BY name', ARRAY_A);
    $order = ['owner' => 0, 'admin' => 1, 'agent' => 2];
    usort($rows, fn($a, $b) => ($order[$a['role']] ?? 3) <=> ($order[$b['role']] ?? 3));
    return rest_ensure_response(['users' => array_map('rh_user_public', $rows)]);
}

function rh_role_bn($r) {
    return ['owner' => 'মূল এডমিন', 'admin' => 'এডমিন', 'agent' => 'এজেন্ট'][$r] ?? $r;
}

function rh_users_add(WP_REST_Request $req, $u) {
    global $wpdb;
    if (!rh_can($u, 'users')) {
        return new WP_Error('perm', 'not allowed', ['status' => 403]);
    }
    $role = (string) $req->get_param('role');
    $name = mb_substr(sanitize_text_field((string) $req->get_param('name')), 0, 190);
    $login = rh_login_norm($req->get_param('login'));
    $pass = (string) $req->get_param('password');
    $agent = (string) $req->get_param('agent_rid');
    if (!in_array($role, ['admin', 'agent'], true) || $name === '' || !preg_match('/^[a-z0-9_.+@]{4,64}$/', $login) || strlen($pass) < 6) {
        return new WP_Error('bad', 'name, login (4+), password (6+)', ['status' => 400]);
    }
    if ($role === 'agent' && (!rh_one('agent', $agent) || !empty(rh_one('agent', $agent)['deleted']))) {
        return new WP_Error('agent', 'unknown agent', ['status' => 400]);
    }
    if ($wpdb->get_var($wpdb->prepare('SELECT id FROM ' . rh_t('users') . ' WHERE login = %s', $login))) {
        return new WP_Error('taken', 'login taken', ['status' => 409]);
    }
    $wpdb->insert(rh_t('users'), [
        'role' => $role,
        'name' => $name,
        'login' => $login,
        'pass_hash' => password_hash($pass, PASSWORD_DEFAULT),
        'agent_rid' => $role === 'agent' ? $agent : '',
        'perms' => $role === 'admin' ? wp_json_encode(rh_perms_from($req->get_param('perms'), $u)) : null,
        'status' => 'active',
        'created_at' => rh_now(),
        'created_by' => (int) $u['id'],
    ]);
    $id = (int) $wpdb->insert_id;
    rh_add_log('নতুন ' . rh_role_bn($role) . ' লগইন', $name . ' · ' . rh_bn($login) . ($role === 'admin' ? ' · অনুমতি: ' . implode(', ', array_map(fn($p) => RH_PERMS[$p], rh_perms_from($req->get_param('perms'), $u))) : ''), $u['name'], '', 'sys');
    $row = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . rh_t('users') . ' WHERE id = %d', $id), ARRAY_A);
    return rest_ensure_response(['ok' => true, 'user' => rh_user_public($row)]);
}

function rh_users_update(WP_REST_Request $req, $u) {
    global $wpdb;
    $id = (int) $req->get_param('id');
    $row = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . rh_t('users') . ' WHERE id = %d', $id), ARRAY_A);
    if (!$row || $row['role'] === 'owner') {
        return new WP_Error('owner', 'the main admin is set on the server', ['status' => 403]);
    }
    if (!rh_can($u, 'users')) {
        return new WP_Error('perm', 'not allowed', ['status' => 403]);
    }
    $set = [];
    $what = [];
    $perms = $req->get_param('perms');
    if (is_array($perms) && $row['role'] === 'admin') {
        // What the editor does not have themselves stays as it was.
        $mine = rh_perms($u);
        $keep = array_diff(rh_perms($row), $mine);
        $new = array_values(array_unique(array_merge($keep, rh_perms_from($perms, $u))));
        sort($new);
        $was = rh_perms($row);
        sort($was);
        if ($new !== $was) {
            $set['perms'] = wp_json_encode($new);
            $what[] = 'অনুমতি: ' . (count($new) === count(RH_PERMS) ? 'সব' : implode(', ', array_map(fn($p) => RH_PERMS[$p], $new)));
        }
    }
    $name = $req->get_param('name');
    if (is_string($name) && trim($name) !== '' && $name !== $row['name']) {
        $set['name'] = mb_substr(sanitize_text_field($name), 0, 190);
        $what[] = 'নাম ' . $row['name'] . ' → ' . $set['name'];
    }
    $pass = $req->get_param('password');
    if (is_string($pass) && $pass !== '') {
        if (strlen($pass) < 6) {
            return new WP_Error('short', 'password too short', ['status' => 400]);
        }
        $set['pass_hash'] = password_hash($pass, PASSWORD_DEFAULT);
        $what[] = 'পাসওয়ার্ড বদল';
    }
    $status = $req->get_param('status');
    if (in_array($status, ['active', 'off'], true) && $status !== $row['status']) {
        $set['status'] = $status;
        $what[] = $status === 'off' ? 'বন্ধ করা হলো' : 'আবার চালু';
    }
    if (!$set) {
        return rest_ensure_response(['ok' => true]);
    }
    $wpdb->update(rh_t('users'), $set, ['id' => $id]);
    if (isset($set['pass_hash']) || ($set['status'] ?? '') === 'off') {
        $wpdb->delete(rh_t('sessions'), ['user_id' => $id]);
    }
    rh_add_log(rh_role_bn($row['role']) . ' লগইন বদল', $row['name'] . ' · ' . implode(' · ', $what), $u['name'], '', 'sys');
    if (($set['status'] ?? '') === 'off' && $row['role'] === 'admin') {
        rh_hand_to_owner($row, $u);
    }
    return rest_ensure_response(['ok' => true]);
}

/**
 * An admin turned off: whatever riyal is in their hand goes to the main
 * admin, as a handover. Their records keep their name.
 */
function rh_hand_to_owner($row, $u) {
    $owner = rh_owner();
    if (!$owner) {
        return;
    }
    $bal = rh_cash_in_hand((int) $row['id']);
    if (abs($bal) < 0.005) {
        return;
    }
    $at = current_time('Y-m-d\TH:i:s');
    $from = $bal > 0 ? $row : $owner;
    $to = $bal > 0 ? $owner : $row;
    $rid = 'off-' . (int) $row['id'] . '-' . time();
    rh_put('handover', $rid, [
        'id' => $rid,
        'at' => $at,
        'from' => (int) $from['id'],
        'fromName' => (string) $from['name'],
        'to' => (int) $to['id'],
        'toName' => (string) $to['name'],
        'sar' => round(abs($bal), 2),
        'note' => $row['name'] . '-এর লগইন বন্ধ হওয়ায় তাঁর হাতের হিসাব মূল এডমিনের কাছে গেল',
        'auto' => true,
    ], (int) $u['id']);
    rh_add_log('কালেকশন মূল এডমিনের কাছে', $row['name'] . ' → ' . $owner['name'] . ' · ' . rh_sar(abs($bal)) . ($bal < 0 ? ' (ঘাটতি)' : ''), $u['name'], '', 'recv');
}


/** The main admin deletes an agent's login for good (the agent's records stay). */
function rh_users_delete(WP_REST_Request $req, $u) {
    global $wpdb;
    if ($u['role'] !== 'owner') {
        return new WP_Error('perm', 'main admin only', ['status' => 403]);
    }
    $id = (int) $req->get_param('id');
    $row = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . rh_t('users') . ' WHERE id = %d', $id), ARRAY_A);
    if (!$row || $row['role'] !== 'agent') {
        return new WP_Error('role', 'only an agent login can be deleted', ['status' => 400]);
    }
    rh_delete_user($row);
    rh_add_log('এজেন্টের লগইন ডিলিট', $row['name'] . ' · ' . $row['login'], $u['name'], (string) $row['agent_rid'], 'sys');
    return rest_ensure_response(['ok' => true]);
}

function rh_delete_user($row) {
    global $wpdb;
    $wpdb->delete(rh_t('sessions'), ['user_id' => (int) $row['id']]);
    $wpdb->delete(rh_t('notes'), ['user_id' => (int) $row['id']]);
    $wpdb->delete(rh_t('users'), ['id' => (int) $row['id']]);
}

/** An agent deleted: every login of theirs goes too. */
function rh_drop_agent_logins($agent_rid, $u) {
    global $wpdb;
    foreach ($wpdb->get_results($wpdb->prepare('SELECT * FROM ' . rh_t('users') . " WHERE role = 'agent' AND agent_rid = %s", $agent_rid), ARRAY_A) as $row) {
        rh_delete_user($row);
        rh_add_log('এজেন্টের লগইন ডিলিট', $row['name'] . ' · ' . $row['login'] . ' (এজেন্ট ডিলিট হওয়ায়)', $u['name'], (string) $agent_rid, 'sys');
    }
}
