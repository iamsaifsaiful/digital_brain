<?php
/**
 * Feedback from the app: a feature wish or a problem, written by a signed-in
 * member. Only what they typed, the kind and the app version are kept — no
 * other data from the phone. Admins read it on the site and in the admin app.
 */

if (!defined('ABSPATH')) {
    exit;
}

function ma_fb_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_feedback';
}

function ma_fb_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    dbDelta('CREATE TABLE ' . ma_fb_table() . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        user_id bigint(20) unsigned NOT NULL DEFAULT 0,
        email varchar(190) NOT NULL DEFAULT '',
        name varchar(190) NOT NULL DEFAULT '',
        kind varchar(16) NOT NULL DEFAULT 'other',
        body text NOT NULL,
        app_version varchar(32) NOT NULL DEFAULT '',
        status varchar(16) NOT NULL DEFAULT 'new',
        created_at datetime NOT NULL,
        PRIMARY KEY  (id),
        KEY status (status),
        KEY user_id (user_id)
    ) " . $wpdb->get_charset_collate() . ';');
}

/** kind => [label, colour class]. */
function ma_fb_kinds() {
    return ['idea' => ['নতুন সুবিধা', 'pro'], 'problem' => ['সমস্যা', 'expired'], 'other' => ['অন্য কিছু', 'free']];
}

function ma_fb_new_count() {
    global $wpdb;
    return (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . ma_fb_table() . " WHERE status = 'new'");
}

add_action('rest_api_init', function () {
    register_rest_route('my-assistant/v1', '/feedback', [
        'methods' => 'POST',
        'callback' => 'ma_fb_receive',
        'permission_callback' => '__return_true', // the member session is checked below
    ]);
});

function ma_fb_receive(WP_REST_Request $req) {
    global $wpdb;
    $m = ma_ai_member($req);
    if (!$m) {
        return new WP_Error('session', 'sign in again', ['status' => 401]);
    }
    $kind = sanitize_key((string) $req->get_param('kind'));
    if (!isset(ma_fb_kinds()[$kind])) {
        $kind = 'other';
    }
    $text = trim(sanitize_textarea_field((string) $req->get_param('text')));
    if (mb_strlen($text) < 5) {
        return new WP_Error('short', 'too short', ['status' => 400]);
    }
    $text = mb_substr($text, 0, 2000);
    // At most 10 a day from one member.
    $since = gmdate('Y-m-d H:i:s', time() - DAY_IN_SECONDS);
    $n = (int) $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . ma_fb_table() . ' WHERE user_id = %d AND created_at > %s', $m['id'], $since));
    if ($n >= 10) {
        return new WP_Error('busy', 'too many today', ['status' => 429]);
    }
    $wpdb->insert(ma_fb_table(), [
        'user_id' => (int) $m['id'],
        'email' => $m['email'],
        'name' => $m['name'],
        'kind' => $kind,
        'body' => $text,
        'app_version' => substr(sanitize_text_field((string) $req->get_param('app_version')), 0, 32),
        'status' => 'new',
        'created_at' => current_time('mysql', true),
    ]);
    $label = ma_fb_kinds()[$kind][0];
    ma_push_admins('নতুন মতামত — ' . $label, mb_substr($text, 0, 80), ['type' => 'feedback', 'id' => (string) $wpdb->insert_id]);
    return ['ok' => true];
}

function ma_fb_json($r) {
    return [
        'id' => (int) $r['id'],
        'created' => gmdate('c', ma_acc_ts($r['created_at'])),
        'email' => $r['email'],
        'name' => $r['name'],
        'kind' => $r['kind'],
        'kind_label' => ma_fb_kinds()[$r['kind']][0] ?? $r['kind'],
        'text' => $r['body'],
        'version' => $r['app_version'],
        'status' => $r['status'],
    ];
}

/** new → read → done; or removed. Returns false when there is no such row. */
function ma_fb_set($id, $status) {
    global $wpdb;
    if ($status === 'delete') {
        return (bool) $wpdb->delete(ma_fb_table(), ['id' => (int) $id]);
    }
    if (!in_array($status, ['new', 'read', 'done'], true)) {
        return false;
    }
    return $wpdb->update(ma_fb_table(), ['status' => $status], ['id' => (int) $id]) !== false;
}

// The admin app.
add_action('rest_api_init', function () {
    ma_admin_route('/feedback', 'GET', function (WP_REST_Request $req) {
        global $wpdb;
        $st = sanitize_key($req->get_param('status') ?: 'open');
        $t = ma_fb_table();
        $rows = match ($st) {
            'all' => $wpdb->get_results("SELECT * FROM $t ORDER BY id DESC LIMIT 100", ARRAY_A),
            'done' => $wpdb->get_results("SELECT * FROM $t WHERE status = 'done' ORDER BY id DESC LIMIT 100", ARRAY_A),
            default => $wpdb->get_results("SELECT * FROM $t WHERE status <> 'done' ORDER BY id DESC LIMIT 100", ARRAY_A),
        };
        return ['feedback' => array_map('ma_fb_json', $rows), 'new' => ma_fb_new_count()];
    });
    ma_admin_route('/feedback/(?P<id>\d+)', 'POST', function (WP_REST_Request $req) {
        $ok = ma_fb_set((int) $req['id'], sanitize_key((string) $req->get_param('status')));
        return new WP_REST_Response(['ok' => $ok], $ok ? 200 : 404);
    });
});

// The site's admin page (মতামত tab).
add_action('admin_post_ma_fb_set', function () {
    ma_acc_guard('ma_fb_set');
    ma_fb_set((int) ($_POST['id'] ?? 0), sanitize_key(wp_unslash($_POST['status'] ?? '')));
    ma_acc_back('রাখা হয়েছে।', 'ok', ['tab' => 'feedback']);
});
