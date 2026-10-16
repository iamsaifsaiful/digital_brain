<?php
/**
 * The admin app's API: /wp-json/my-assistant/v1/admin/…
 * Only a session made by the admin app, for a Google email on the admin
 * list (settings page). Everything lives here; the app keeps nothing but
 * its session.
 */

if (!defined('ABSPATH')) {
    exit;
}

/** The admin behind the request (an admin-app session of a WordPress user who may manage), or null. */
function ma_admin_of(WP_REST_Request $req) {
    $s = ma_session_row($req);
    if (!$s || $s['app'] !== 'admin') {
        return null;
    }
    $user = get_user_by('id', (int) $s['user_id']);
    if (!$user || !user_can($user, 'ma_manage')) {
        return null;
    }
    return ['id' => $user->ID, 'email' => $user->user_email, 'name' => $user->display_name, 'session' => (int) $s['id']];
}

/**
 * Email + password (a WordPress account with the admin role). Five wrong
 * tries for an address or from a network wait 15 minutes.
 */
function ma_admin_login(WP_REST_Request $req) {
    global $wpdb;
    $email = strtolower(sanitize_email((string) $req->get_param('email')));
    $pass = (string) $req->get_param('password');
    $ip = isset($_SERVER['REMOTE_ADDR']) ? sanitize_text_field(wp_unslash($_SERVER['REMOTE_ADDR'])) : 'x';
    $keys = ['ma_adm_fail_' . md5($email), 'ma_adm_fail_' . md5($ip)];
    foreach ($keys as $k) {
        if ((int) get_transient($k) >= 5) {
            return new WP_Error('wait', 'too many tries', ['status' => 429]);
        }
    }
    $user = $email !== '' && $pass !== '' ? wp_authenticate($email, $pass) : null;
    if (!$user || is_wp_error($user) || !user_can($user, 'ma_manage')) {
        foreach ($keys as $k) {
            set_transient($k, (int) get_transient($k) + 1, 15 * MINUTE_IN_SECONDS);
        }
        return new WP_Error('login', 'wrong email or password', ['status' => 401]);
    }
    foreach ($keys as $k) {
        delete_transient($k);
    }
    return ['session' => ma_ai_new_session($user->ID, 'admin'), 'name' => $user->display_name, 'email' => $user->user_email];
}

function ma_admin_route($path, $method, $cb) {
    register_rest_route('my-assistant/v1', '/admin' . $path, [
        'methods' => $method,
        'callback' => $cb,
        'permission_callback' => function (WP_REST_Request $req) {
            return ma_admin_of($req) !== null ? true : new WP_Error('admin', 'not an admin', ['status' => 403]);
        },
    ]);
}

/** One member, as the app shows it. */
function ma_admin_member_json($r) {
    $labels = ma_acc_status_labels();
    $st = ma_acc_status($r);
    return [
        'id' => (int) $r['id'],
        'name' => $r['name'],
        'email' => $r['email'],
        'picture' => $r['picture'],
        'status' => $st,
        'status_label' => $labels[$st][0],
        'pro_until' => $r['pro_until'] ? gmdate('c', ma_acc_ts($r['pro_until'])) : null,
        'pro_kind' => $r['pro_kind'],
        'joined' => gmdate('c', ma_acc_ts($r['created_at'])),
        'last_seen' => gmdate('c', ma_acc_ts($r['last_seen'])),
        'version' => trim($r['app_version'] . ' ' . $r['edition']),
        'note' => $r['note'],
    ];
}

function ma_admin_payment_json($p) {
    $plans = ma_pay_plans();
    return [
        'id' => (int) $p['id'],
        'created' => gmdate('c', ma_acc_ts($p['created_at'])),
        'email' => $p['email'],
        'name' => $p['name'],
        'phone' => $p['phone'],
        'plan' => $plans[$p['plan']]['label'] ?? $p['plan'],
        'amount' => (int) $p['amount'],
        'method' => $p['method'],
        'sender' => $p['sender'],
        'trx' => $p['trx'],
        'note' => $p['note'],
        'status' => $p['status'],
        'reason' => $p['reason'],
        'reviewed_by' => $p['reviewed_email'] ?? '',
        'reviewed' => $p['reviewed_at'] ? gmdate('c', ma_acc_ts($p['reviewed_at'])) : null,
    ];
}

add_action('rest_api_init', function () {
    register_rest_route('my-assistant/v1', '/admin/login', [
        'methods' => 'POST',
        'callback' => 'ma_admin_login',
        'permission_callback' => '__return_true', // the password is the check
    ]);

    ma_admin_route('/logout', 'POST', function (WP_REST_Request $req) {
        global $wpdb;
        $wpdb->delete(ma_ai_sessions_table(), ['id' => ma_admin_of($req)['session']]);
        return ['ok' => true];
    });

    ma_admin_route('/me', 'GET', function (WP_REST_Request $req) {
        $a = ma_admin_of($req);
        return ['name' => $a['name'], 'email' => $a['email']];
    });

    ma_admin_route('/summary', 'GET', function () {
        global $wpdb;
        $t = ma_acc_table();
        $now = gmdate('Y-m-d H:i:s');
        $week = gmdate('Y-m-d H:i:s', time() - 7 * DAY_IN_SECONDS);
        $ai = ma_ai_today_stats();
        return [
            'members' => (int) $wpdb->get_var("SELECT COUNT(*) FROM $t WHERE google_sub NOT LIKE 'pending:%'"),
            'pro' => (int) $wpdb->get_var("SELECT COUNT(*) FROM $t WHERE pro_until > '$now' AND pro_kind <> 'trial' AND google_sub NOT LIKE 'pending:%'"),
            'trial' => (int) $wpdb->get_var("SELECT COUNT(*) FROM $t WHERE pro_until > '$now' AND pro_kind = 'trial' AND google_sub NOT LIKE 'pending:%'"),
            'new_week' => (int) $wpdb->get_var("SELECT COUNT(*) FROM $t WHERE created_at > '$week' AND google_sub NOT LIKE 'pending:%'"),
            'active_week' => (int) $wpdb->get_var("SELECT COUNT(*) FROM $t WHERE last_seen > '$week' AND google_sub NOT LIKE 'pending:%'"),
            'pending_payments' => ma_pay_pending_count(),
            'income_month' => (int) $wpdb->get_var($wpdb->prepare('SELECT COALESCE(SUM(amount),0) FROM ' . ma_pay_table() . " WHERE status = 'approved' AND reviewed_at >= %s", gmdate('Y-m-01'))),
            'ai_today' => $ai['requests'],
        ];
    });

    ma_admin_route('/payments', 'GET', function (WP_REST_Request $req) {
        global $wpdb;
        $st = sanitize_key($req->get_param('status') ?: 'pending');
        $pt = ma_pay_table();
        $rows = $st === 'all'
            ? $wpdb->get_results("SELECT * FROM $pt ORDER BY created_at DESC LIMIT 100", ARRAY_A)
            : $wpdb->get_results($wpdb->prepare("SELECT * FROM $pt WHERE status = %s ORDER BY created_at DESC LIMIT 100", $st), ARRAY_A);
        return ['payments' => array_map('ma_admin_payment_json', $rows)];
    });

    ma_admin_route('/payments/(?P<id>\d+)', 'POST', function (WP_REST_Request $req) {
        $admin = ma_admin_of($req);
        [$ok, $msg] = ma_pay_decide((int) $req['id'], $req->get_param('decision') === 'approve', (string) $req->get_param('reason'), (bool) $req->get_param('tell'), $admin['email']);
        return new WP_REST_Response(['ok' => $ok, 'message' => $msg], $ok ? 200 : 409);
    });

    ma_admin_route('/members', 'GET', function (WP_REST_Request $req) {
        global $wpdb;
        $t = ma_acc_table();
        $q = sanitize_text_field((string) $req->get_param('q'));
        $page = max(1, (int) $req->get_param('page'));
        if ($q !== '') {
            $like = '%' . $wpdb->esc_like($q) . '%';
            $rows = $wpdb->get_results($wpdb->prepare("SELECT * FROM $t WHERE name LIKE %s OR email LIKE %s ORDER BY last_seen DESC LIMIT 30 OFFSET %d", $like, $like, ($page - 1) * 30), ARRAY_A);
        } else {
            $rows = $wpdb->get_results($wpdb->prepare("SELECT * FROM $t ORDER BY last_seen DESC LIMIT 30 OFFSET %d", ($page - 1) * 30), ARRAY_A);
        }
        return ['members' => array_map('ma_admin_member_json', $rows)];
    });

    ma_admin_route('/members/(?P<id>\d+)', 'POST', function (WP_REST_Request $req) {
        global $wpdb;
        $t = ma_acc_table();
        $row = $wpdb->get_row($wpdb->prepare("SELECT * FROM $t WHERE id = %d", (int) $req['id']), ARRAY_A);
        if (!$row) {
            return new WP_Error('none', 'not found', ['status' => 404]);
        }
        $days = max(0, min(3660, (int) $req->get_param('days')));
        $data = [];
        if ($req->get_param('stop')) {
            $data = ['pro_until' => null, 'pro_kind' => ''];
        } elseif ($days > 0) {
            $data = ['pro_until' => ma_acc_extend($row, $days), 'pro_kind' => 'manual'];
        }
        if ($req->get_param('note') !== null) {
            $data['note'] = substr(sanitize_text_field((string) $req->get_param('note')), 0, 500);
        }
        if ($data) {
            $wpdb->update($t, $data, ['id' => $row['id']]);
        }
        if ($days > 0) {
            ma_push_member((int) $row['id'], 'প্রো চালু হয়েছে 🎉', 'AI, বিজ্ঞাপন ছাড়া আর সব প্রো সুবিধা এখন চালু।', ['type' => 'pro']);
        }
        return ['ok' => true, 'member' => ma_admin_member_json($wpdb->get_row($wpdb->prepare("SELECT * FROM $t WHERE id = %d", $row['id']), ARRAY_A))];
    });

    ma_admin_route('/notices', 'GET', function () {
        global $wpdb;
        return ['notices' => $wpdb->get_results('SELECT * FROM ' . ma_note_table() . ' ORDER BY active DESC, id DESC', ARRAY_A)];
    });

    ma_admin_route('/notices/(?P<id>\d+)/toggle', 'POST', function (WP_REST_Request $req) {
        global $wpdb;
        $wpdb->query($wpdb->prepare('UPDATE ' . ma_note_table() . ' SET active = 1 - active WHERE id = %d', (int) $req['id']));
        return ['ok' => true];
    });

    /** Sends a message to members' phones now (everyone, or one plan). */
    ma_admin_route('/push', 'POST', function (WP_REST_Request $req) {
        global $wpdb;
        $title = substr(sanitize_text_field((string) $req->get_param('title')), 0, 120);
        $body = substr(sanitize_text_field((string) $req->get_param('body')), 0, 400);
        $aud = sanitize_key((string) $req->get_param('audience'));
        if ($title === '') {
            return new WP_Error('bad', 'title needed', ['status' => 400]);
        }
        $now = gmdate('Y-m-d H:i:s');
        $where = match ($aud) {
            'pro' => "AND u.pro_until > '$now' AND u.pro_kind <> 'trial'",
            'trial' => "AND u.pro_until > '$now' AND u.pro_kind = 'trial'",
            'free' => "AND (u.pro_until IS NULL OR u.pro_until <= '$now')",
            default => '',
        };
        $tokens = $wpdb->get_col('SELECT s.fcm_token FROM ' . ma_ai_sessions_table() . ' s JOIN ' . ma_acc_table() . " u ON u.id = s.user_id WHERE s.app <> 'admin' AND s.fcm_token <> '' AND s.expires_at > UTC_TIMESTAMP() $where LIMIT 5000");
        return ['ok' => true, 'sent' => ma_push_send($tokens, $title, $body, ['type' => 'news'])];
    });
});
