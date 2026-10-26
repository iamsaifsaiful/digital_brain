<?php
/**
 * Feedback from the app as conversations: a member writes a feature wish or
 * a problem, an admin answers, the member answers back… Each message may
 * carry one photo or PDF. Only what they write or attach is kept — no other
 * data from the phone. Attachments live in a private folder that the web
 * server never serves; they are read through the API by the member who owns
 * the conversation or by an admin.
 */

if (!defined('ABSPATH')) {
    exit;
}

const MA_FB_MAX_FILE = 5 * 1024 * 1024;

function ma_fb_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_feedback';
}

function ma_fb_msgs_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_feedback_msgs';
}

function ma_fb_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $cs = $wpdb->get_charset_collate();
    dbDelta('CREATE TABLE ' . ma_fb_table() . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        user_id bigint(20) unsigned NOT NULL DEFAULT 0,
        email varchar(190) NOT NULL DEFAULT '',
        name varchar(190) NOT NULL DEFAULT '',
        kind varchar(16) NOT NULL DEFAULT 'other',
        body text NOT NULL,
        app_version varchar(32) NOT NULL DEFAULT '',
        status varchar(16) NOT NULL DEFAULT 'new',
        member_unread tinyint(1) NOT NULL DEFAULT 0,
        created_at datetime NOT NULL,
        updated_at datetime NULL DEFAULT NULL,
        PRIMARY KEY  (id),
        KEY status (status),
        KEY user_id (user_id)
    ) $cs;");
    dbDelta('CREATE TABLE ' . ma_fb_msgs_table() . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        feedback_id bigint(20) unsigned NOT NULL,
        sender varchar(10) NOT NULL DEFAULT 'member',
        admin_name varchar(190) NOT NULL DEFAULT '',
        body text NOT NULL,
        file_key varchar(64) NOT NULL DEFAULT '',
        file_name varchar(190) NOT NULL DEFAULT '',
        file_mime varchar(64) NOT NULL DEFAULT '',
        file_size int unsigned NOT NULL DEFAULT 0,
        created_at datetime NOT NULL,
        PRIMARY KEY  (id),
        KEY feedback_id (feedback_id)
    ) $cs;");
    ma_fb_dir();
    // Conversations from 1.6 (one message each) become their first message.
    $t = ma_fb_table();
    $m = ma_fb_msgs_table();
    $wpdb->query("INSERT INTO $m (feedback_id, sender, body, created_at) SELECT f.id, 'member', f.body, f.created_at FROM $t f WHERE NOT EXISTS (SELECT 1 FROM $m x WHERE x.feedback_id = f.id)");
    $wpdb->query("UPDATE $t SET updated_at = created_at WHERE updated_at IS NULL");
}

/** The private folder for attachments (never served by the web server). */
function ma_fb_dir() {
    $up = wp_upload_dir(null, false);
    $dir = trailingslashit($up['basedir']) . 'ma-private';
    if (!is_dir($dir)) {
        wp_mkdir_p($dir);
    }
    if (!file_exists("$dir/.htaccess")) {
        file_put_contents("$dir/.htaccess", "Require all denied\nDeny from all\n");
    }
    if (!file_exists("$dir/index.php")) {
        file_put_contents("$dir/index.php", "<?php // Silence.\n");
    }
    return $dir;
}

/** kind => [label, colour class]. */
function ma_fb_kinds() {
    return ['idea' => ['নতুন সুবিধা', 'pro'], 'problem' => ['সমস্যা', 'expired'], 'other' => ['অন্য কিছু', 'free']];
}

function ma_fb_new_count() {
    global $wpdb;
    return (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . ma_fb_table() . " WHERE status = 'new'");
}

/** Answers from us the member has not opened yet. */
function ma_fb_member_unread($user_id) {
    global $wpdb;
    return (int) $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . ma_fb_table() . ' WHERE user_id = %d AND member_unread = 1', $user_id));
}

/**
 * Keeps one attachment: bytes checked by their content (a photo or a PDF, at
 * most 5 MB), stored under a random name. Returns the message fields, or a
 * WP_Error.
 */
function ma_fb_store_file($bytes, $name) {
    if (!is_string($bytes) || $bytes === '') {
        return [];
    }
    if (strlen($bytes) > MA_FB_MAX_FILE) {
        return new WP_Error('big', 'file too big', ['status' => 413]);
    }
    $fi = new finfo(FILEINFO_MIME_TYPE);
    $mime = (string) $fi->buffer($bytes);
    $ok = ['image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp', 'application/pdf' => 'pdf'];
    if (!isset($ok[$mime])) {
        return new WP_Error('type', 'only photos and PDF', ['status' => 415]);
    }
    $key = bin2hex(random_bytes(32));
    if (file_put_contents(ma_fb_dir() . '/' . $key, $bytes) === false) {
        return new WP_Error('disk', 'could not save', ['status' => 500]);
    }
    $name = sanitize_file_name((string) $name);
    if ($name === '' || !str_contains($name, '.')) {
        $name = 'attachment.' . $ok[$mime];
    }
    return ['file_key' => $key, 'file_name' => substr($name, 0, 190), 'file_mime' => $mime, 'file_size' => strlen($bytes)];
}

/** {name, data (base64)} from the app, or null. */
function ma_fb_file_param(WP_REST_Request $req) {
    $f = $req->get_param('file');
    if (!is_array($f) || empty($f['data'])) {
        return null;
    }
    $bytes = base64_decode((string) $f['data'], true);
    return $bytes === false ? new WP_Error('bad', 'bad file', ['status' => 400]) : ma_fb_store_file($bytes, $f['name'] ?? '');
}

function ma_fb_add_msg($feedback_id, $sender, $text, array $file = [], $admin_name = '') {
    global $wpdb;
    $wpdb->insert(ma_fb_msgs_table(), [
        'feedback_id' => (int) $feedback_id,
        'sender' => $sender,
        'admin_name' => $admin_name,
        'body' => $text,
        'created_at' => current_time('mysql', true),
    ] + $file);
    return (int) $wpdb->insert_id;
}

function ma_fb_msg_json($m) {
    return [
        'id' => (int) $m['id'],
        'from' => $m['sender'],
        'admin' => $m['admin_name'],
        'text' => $m['body'],
        'created' => gmdate('c', ma_acc_ts($m['created_at'])),
        'file' => $m['file_key'] !== '' ? ['name' => $m['file_name'], 'mime' => $m['file_mime'], 'size' => (int) $m['file_size']] : null,
    ];
}

function ma_fb_messages($feedback_id) {
    global $wpdb;
    return array_map('ma_fb_msg_json', $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . ma_fb_msgs_table() . ' WHERE feedback_id = %d ORDER BY id ASC', $feedback_id), ARRAY_A));
}

function ma_fb_json($r) {
    global $wpdb;
    $last = $wpdb->get_row($wpdb->prepare('SELECT sender, body, file_key FROM ' . ma_fb_msgs_table() . ' WHERE feedback_id = %d ORDER BY id DESC LIMIT 1', $r['id']), ARRAY_A);
    $count = (int) $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . ma_fb_msgs_table() . ' WHERE feedback_id = %d', $r['id']));
    return [
        'id' => (int) $r['id'],
        'created' => gmdate('c', ma_acc_ts($r['created_at'])),
        'updated' => gmdate('c', ma_acc_ts($r['updated_at'] ?: $r['created_at'])),
        'email' => $r['email'],
        'name' => $r['name'],
        'kind' => $r['kind'],
        'kind_label' => ma_fb_kinds()[$r['kind']][0] ?? $r['kind'],
        'text' => $r['body'],
        'last' => $last ? ['from' => $last['sender'], 'text' => $last['body'] !== '' ? $last['body'] : '📎'] : null,
        'count' => $count,
        'version' => $r['app_version'],
        'status' => $r['status'],
        'unread' => (bool) (int) $r['member_unread'],
    ];
}

/** Text of a message: up to 2000 characters, tags removed. */
function ma_fb_text(WP_REST_Request $req) {
    return mb_substr(trim(sanitize_textarea_field((string) $req->get_param('text'))), 0, 2000);
}

// ── The member's side (/feedback…) ──

add_action('rest_api_init', function () {
    $open = '__return_true'; // the member session is checked inside
    register_rest_route('my-assistant/v1', '/feedback', [
        ['methods' => 'POST', 'callback' => 'ma_fb_receive', 'permission_callback' => $open],
        ['methods' => 'GET', 'callback' => 'ma_fb_mine', 'permission_callback' => $open],
    ]);
    register_rest_route('my-assistant/v1', '/feedback/(?P<id>\d+)', [
        'methods' => 'GET', 'callback' => 'ma_fb_thread_member', 'permission_callback' => $open,
    ]);
    register_rest_route('my-assistant/v1', '/feedback/(?P<id>\d+)/reply', [
        'methods' => 'POST', 'callback' => 'ma_fb_reply_member', 'permission_callback' => $open,
    ]);
    register_rest_route('my-assistant/v1', '/feedback/file/(?P<id>\d+)', [
        'methods' => 'GET', 'callback' => 'ma_fb_file_member', 'permission_callback' => $open,
    ]);
});

/** At most 20 messages a day from one member, new or replies. */
function ma_fb_too_many($user_id) {
    global $wpdb;
    $since = gmdate('Y-m-d H:i:s', time() - DAY_IN_SECONDS);
    $n = (int) $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . ma_fb_msgs_table() . ' m JOIN ' . ma_fb_table() . " f ON f.id = m.feedback_id WHERE f.user_id = %d AND m.sender = 'member' AND m.created_at > %s", $user_id, $since));
    return $n >= 20;
}

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
    $text = ma_fb_text($req);
    $file = ma_fb_file_param($req);
    if (is_wp_error($file)) {
        return $file;
    }
    if (mb_strlen($text) < 5 && !$file) {
        return new WP_Error('short', 'too short', ['status' => 400]);
    }
    if (ma_fb_too_many((int) $m['id'])) {
        return new WP_Error('busy', 'too many today', ['status' => 429]);
    }
    $now = current_time('mysql', true);
    $wpdb->insert(ma_fb_table(), [
        'user_id' => (int) $m['id'],
        'email' => $m['email'],
        'name' => $m['name'],
        'kind' => $kind,
        'body' => $text,
        'app_version' => substr(sanitize_text_field((string) $req->get_param('app_version')), 0, 32),
        'status' => 'new',
        'created_at' => $now,
        'updated_at' => $now,
    ]);
    $id = (int) $wpdb->insert_id;
    ma_fb_add_msg($id, 'member', $text, $file ?: []);
    ma_push_admins('নতুন মতামত — ' . ma_fb_kinds()[$kind][0], $text !== '' ? mb_substr($text, 0, 80) : '📎 সংযুক্তি', ['type' => 'feedback', 'id' => (string) $id]);
    return ['ok' => true, 'id' => $id];
}

function ma_fb_mine(WP_REST_Request $req) {
    global $wpdb;
    $m = ma_ai_member($req);
    if (!$m) {
        return new WP_Error('session', 'sign in again', ['status' => 401]);
    }
    $rows = $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . ma_fb_table() . ' WHERE user_id = %d ORDER BY COALESCE(updated_at, created_at) DESC LIMIT 50', $m['id']), ARRAY_A);
    return ['feedback' => array_map('ma_fb_json', $rows)];
}

/** The member's own conversation, or a WP_Error. */
function ma_fb_owned(WP_REST_Request $req, $id) {
    global $wpdb;
    $m = ma_ai_member($req);
    if (!$m) {
        return new WP_Error('session', 'sign in again', ['status' => 401]);
    }
    $f = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_fb_table() . ' WHERE id = %d AND user_id = %d', $id, $m['id']), ARRAY_A);
    return $f ?: new WP_Error('none', 'not found', ['status' => 404]);
}

function ma_fb_thread_member(WP_REST_Request $req) {
    global $wpdb;
    $f = ma_fb_owned($req, (int) $req['id']);
    if (is_wp_error($f)) {
        return $f;
    }
    $wpdb->update(ma_fb_table(), ['member_unread' => 0], ['id' => $f['id']]);
    $f['member_unread'] = 0;
    return ['feedback' => ma_fb_json($f), 'messages' => ma_fb_messages((int) $f['id'])];
}

function ma_fb_reply_member(WP_REST_Request $req) {
    global $wpdb;
    $f = ma_fb_owned($req, (int) $req['id']);
    if (is_wp_error($f)) {
        return $f;
    }
    $text = ma_fb_text($req);
    $file = ma_fb_file_param($req);
    if (is_wp_error($file)) {
        return $file;
    }
    if ($text === '' && !$file) {
        return new WP_Error('short', 'empty', ['status' => 400]);
    }
    if (ma_fb_too_many((int) $f['user_id'])) {
        return new WP_Error('busy', 'too many today', ['status' => 429]);
    }
    $mid = ma_fb_add_msg((int) $f['id'], 'member', $text, $file ?: []);
    // Back on the admins' open list.
    $wpdb->update(ma_fb_table(), ['status' => 'new', 'updated_at' => current_time('mysql', true)], ['id' => $f['id']]);
    ma_push_admins('মতামতে নতুন উত্তর — ' . ($f['name'] !== '' ? $f['name'] : $f['email']), $text !== '' ? mb_substr($text, 0, 80) : '📎 সংযুক্তি', ['type' => 'feedback', 'id' => (string) $f['id']]);
    return ['ok' => true, 'id' => $mid];
}

/** An attachment as {name, mime, data (base64)}. */
function ma_fb_file_json($msg) {
    $path = ma_fb_dir() . '/' . $msg['file_key'];
    if ($msg['file_key'] === '' || !preg_match('/^[a-f0-9]{64}$/', $msg['file_key']) || !is_file($path)) {
        return new WP_Error('none', 'no file', ['status' => 404]);
    }
    return ['name' => $msg['file_name'], 'mime' => $msg['file_mime'], 'data' => base64_encode((string) file_get_contents($path))];
}

function ma_fb_msg_row($id) {
    global $wpdb;
    return $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_fb_msgs_table() . ' WHERE id = %d', $id), ARRAY_A);
}

function ma_fb_file_member(WP_REST_Request $req) {
    $msg = ma_fb_msg_row((int) $req['id']);
    if (!$msg) {
        return new WP_Error('none', 'not found', ['status' => 404]);
    }
    $f = ma_fb_owned($req, (int) $msg['feedback_id']);
    return is_wp_error($f) ? $f : ma_fb_file_json($msg);
}

/** new → read → done; or removed (with its files). False when there is no such row. */
function ma_fb_set($id, $status) {
    global $wpdb;
    if ($status === 'delete') {
        foreach ($wpdb->get_col($wpdb->prepare('SELECT file_key FROM ' . ma_fb_msgs_table() . " WHERE feedback_id = %d AND file_key <> ''", $id)) as $key) {
            if (preg_match('/^[a-f0-9]{64}$/', $key)) {
                wp_delete_file(ma_fb_dir() . '/' . $key);
            }
        }
        $wpdb->delete(ma_fb_msgs_table(), ['feedback_id' => (int) $id]);
        return (bool) $wpdb->delete(ma_fb_table(), ['id' => (int) $id]);
    }
    if (!in_array($status, ['new', 'read', 'done'], true)) {
        return false;
    }
    return $wpdb->update(ma_fb_table(), ['status' => $status], ['id' => (int) $id]) !== false;
}

/** An admin's answer: kept, the conversation marked read, the member's phone pushed. */
function ma_fb_admin_reply($id, $text, array $file, $admin_name) {
    global $wpdb;
    $f = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_fb_table() . ' WHERE id = %d', $id), ARRAY_A);
    if (!$f) {
        return new WP_Error('none', 'not found', ['status' => 404]);
    }
    if ($text === '' && !$file) {
        return new WP_Error('short', 'empty', ['status' => 400]);
    }
    $mid = ma_fb_add_msg($id, 'admin', $text, $file, $admin_name);
    $wpdb->update(ma_fb_table(), ['status' => 'read', 'member_unread' => 1, 'updated_at' => current_time('mysql', true)], ['id' => $id]);
    ma_push_member((int) $f['user_id'], 'আপনার মতামতের উত্তর এসেছে', $text !== '' ? mb_substr($text, 0, 100) : '📎 সংযুক্তি', ['type' => 'feedback', 'id' => (string) $id]);
    return $mid;
}

// ── One inbox per member (owner, 27 Oct): every conversation of a member in one place ──

/** The inbox key of a conversation: the member's id, or their e-mail when there is none. */
function ma_fb_key($r) {
    return (int) $r['user_id'] > 0 ? (string) (int) $r['user_id'] : 'e:' . strtolower($r['email']);
}

/**
 * Members with conversations, newest first. $st: 'open' (anything not
 * finished), 'done' (all finished) or 'all'; $q: name or e-mail.
 */
function ma_fb_inbox($st = 'open', $q = '') {
    global $wpdb;
    $rows = $wpdb->get_results('SELECT * FROM ' . ma_fb_table() . ' ORDER BY COALESCE(updated_at, created_at) DESC LIMIT 1000', ARRAY_A);
    $out = [];
    foreach ($rows as $r) {
        $k = ma_fb_key($r);
        if (!isset($out[$k])) {
            $out[$k] = ['key' => $k, 'user_id' => (int) $r['user_id'], 'email' => $r['email'], 'name' => $r['name'], 'picture' => '', 'threads' => 0, 'open' => 0, 'new' => 0, 'kinds' => [], 'updated' => $r['updated_at'] ?: $r['created_at'], 'last' => null, 'thread' => (int) $r['id']];
            $last = $wpdb->get_row($wpdb->prepare('SELECT sender, body, file_key FROM ' . ma_fb_msgs_table() . ' WHERE feedback_id = %d ORDER BY id DESC LIMIT 1', $r['id']), ARRAY_A);
            if ($last) {
                $out[$k]['last'] = ['from' => $last['sender'], 'text' => $last['body'] !== '' ? $last['body'] : '📎 সংযুক্তি'];
            }
        }
        $g = &$out[$k];
        $g['threads']++;
        if ($r['status'] !== 'done') {
            $g['open']++;
        }
        if ($r['status'] === 'new') {
            $g['new']++;
        }
        $g['kinds'][$r['kind']] = true;
        unset($g);
    }
    $ids = array_filter(array_map(fn($g) => $g['user_id'], $out));
    if ($ids) {
        foreach ($wpdb->get_results('SELECT id, picture, name FROM ' . ma_acc_table() . ' WHERE id IN (' . implode(',', array_map('intval', $ids)) . ')', ARRAY_A) as $u) {
            foreach ($out as &$g) {
                if ($g['user_id'] === (int) $u['id']) {
                    $g['picture'] = $u['picture'];
                    if ($g['name'] === '') {
                        $g['name'] = $u['name'];
                    }
                }
            }
            unset($g);
        }
    }
    $kinds = ma_fb_kinds();
    $res = [];
    foreach ($out as $g) {
        if (($st === 'open' && $g['open'] === 0) || ($st === 'done' && $g['open'] > 0)) {
            continue;
        }
        if ($q !== '' && stripos($g['name'] . ' ' . $g['email'], $q) === false) {
            continue;
        }
        $g['kind_labels'] = array_values(array_map(fn($k) => $kinds[$k][0] ?? $k, array_keys($g['kinds'])));
        $g['kinds'] = array_keys($g['kinds']);
        $g['updated'] = gmdate('c', ma_acc_ts($g['updated']));
        $res[] = $g;
    }
    return $res;
}

/** The conversations of one member (by inbox key), oldest first. */
function ma_fb_member_threads($key) {
    global $wpdb;
    if (preg_match('/^\d+$/', (string) $key)) {
        return $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . ma_fb_table() . ' WHERE user_id = %d ORDER BY id ASC', (int) $key), ARRAY_A);
    }
    if (str_starts_with((string) $key, 'e:')) {
        return $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . ma_fb_table() . ' WHERE user_id = 0 AND email = %s ORDER BY id ASC', substr($key, 2)), ARRAY_A);
    }
    return [];
}

/**
 * One member's inbox: who, every message of every conversation in time
 * order (each says which conversation it belongs to), and where a reply
 * goes (the newest open conversation). Opening it marks the new ones read.
 */
function ma_fb_inbox_one($key) {
    global $wpdb;
    $threads = ma_fb_member_threads($key);
    if (!$threads) {
        return null;
    }
    $kinds = ma_fb_kinds();
    $msgs = [];
    $tjson = [];
    $reply_to = 0;
    foreach ($threads as $t) {
        if ($t['status'] === 'new') {
            $wpdb->update(ma_fb_table(), ['status' => 'read'], ['id' => $t['id']]);
            $t['status'] = 'read';
        }
        if ($t['status'] !== 'done') {
            $reply_to = (int) $t['id'];
        }
        $tjson[] = ['id' => (int) $t['id'], 'kind' => $t['kind'], 'kind_label' => $kinds[$t['kind']][0] ?? $t['kind'], 'status' => $t['status'], 'created' => gmdate('c', ma_acc_ts($t['created_at'])), 'version' => $t['app_version']];
        foreach ($wpdb->get_results($wpdb->prepare('SELECT * FROM ' . ma_fb_msgs_table() . ' WHERE feedback_id = %d', $t['id']), ARRAY_A) as $m) {
            $msgs[] = ma_fb_msg_json($m) + ['thread' => (int) $t['id'], 'kind_label' => $kinds[$t['kind']][0] ?? $t['kind'], 'file_mime' => $m['file_mime'], 'file_size' => (int) $m['file_size'], 'at' => $m['created_at']];
        }
    }
    usort($msgs, fn($a, $b) => [$a['at'], $a['id']] <=> [$b['at'], $b['id']]);
    foreach ($msgs as &$m) {
        unset($m['at']);
    }
    unset($m);
    $last = end($threads);
    $u = (int) $last['user_id'] > 0 ? $wpdb->get_row($wpdb->prepare('SELECT picture, name FROM ' . ma_acc_table() . ' WHERE id = %d', $last['user_id']), ARRAY_A) : null;
    return [
        'key' => (string) $key,
        'user_id' => (int) $last['user_id'],
        'email' => $last['email'],
        'name' => $last['name'] !== '' ? $last['name'] : (string) ($u['name'] ?? ''),
        'picture' => (string) ($u['picture'] ?? ''),
        'threads' => $tjson,
        'messages' => $msgs,
        'reply_to' => $reply_to ?: (int) $last['id'],
        'open' => $reply_to > 0,
    ];
}

/** All of a member's conversations finished ('done'), or the newest one opened again ('open'). */
function ma_fb_inbox_set($key, $what) {
    global $wpdb;
    $threads = ma_fb_member_threads($key);
    if (!$threads) {
        return false;
    }
    if ($what === 'done') {
        foreach ($threads as $t) {
            $wpdb->update(ma_fb_table(), ['status' => 'done'], ['id' => $t['id']]);
        }
        return true;
    }
    if ($what === 'open') {
        $t = end($threads);
        return $wpdb->update(ma_fb_table(), ['status' => 'read'], ['id' => $t['id']]) !== false;
    }
    return false;
}

// ── The admin app (/admin/feedback…) ──

add_action('rest_api_init', function () {
    ma_admin_route('/feedback', 'GET', function (WP_REST_Request $req) {
        global $wpdb;
        $st = sanitize_key($req->get_param('status') ?: 'open');
        $t = ma_fb_table();
        $order = 'ORDER BY COALESCE(updated_at, created_at) DESC LIMIT 100';
        $rows = match ($st) {
            'all' => $wpdb->get_results("SELECT * FROM $t $order", ARRAY_A),
            'done' => $wpdb->get_results("SELECT * FROM $t WHERE status = 'done' $order", ARRAY_A),
            default => $wpdb->get_results("SELECT * FROM $t WHERE status <> 'done' $order", ARRAY_A),
        };
        return ['feedback' => array_map('ma_fb_json', $rows), 'new' => ma_fb_new_count()];
    });
    ma_admin_route('/feedback/(?P<id>\d+)', 'GET', function (WP_REST_Request $req) {
        global $wpdb;
        $f = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_fb_table() . ' WHERE id = %d', (int) $req['id']), ARRAY_A);
        if (!$f) {
            return new WP_Error('none', 'not found', ['status' => 404]);
        }
        if ($f['status'] === 'new') {
            $wpdb->update(ma_fb_table(), ['status' => 'read'], ['id' => $f['id']]);
            $f['status'] = 'read';
        }
        return ['feedback' => ma_fb_json($f), 'messages' => ma_fb_messages((int) $f['id'])];
    });
    ma_admin_route('/feedback/(?P<id>\d+)', 'POST', function (WP_REST_Request $req) {
        $ok = ma_fb_set((int) $req['id'], sanitize_key((string) $req->get_param('status')));
        return new WP_REST_Response(['ok' => $ok], $ok ? 200 : 404);
    });
    ma_admin_route('/feedback/(?P<id>\d+)/reply', 'POST', function (WP_REST_Request $req) {
        $file = ma_fb_file_param($req);
        if (is_wp_error($file)) {
            return $file;
        }
        $mid = ma_fb_admin_reply((int) $req['id'], ma_fb_text($req), $file ?: [], ma_admin_of($req)['name']);
        return is_wp_error($mid) ? $mid : ['ok' => true, 'id' => $mid];
    });
    // One inbox per member.
    ma_admin_route('/inbox', 'GET', function (WP_REST_Request $req) {
        return ['members' => ma_fb_inbox(sanitize_key((string) ($req->get_param('status') ?: 'open')), sanitize_text_field((string) $req->get_param('q'))), 'new' => ma_fb_new_count()];
    });
    ma_admin_route('/inbox/(?P<key>[0-9]+|e:[^/]+)', 'GET', function (WP_REST_Request $req) {
        $one = ma_fb_inbox_one(rawurldecode((string) $req['key']));
        return $one ?: new WP_Error('none', 'not found', ['status' => 404]);
    });
    ma_admin_route('/inbox/(?P<key>[0-9]+|e:[^/]+)', 'POST', function (WP_REST_Request $req) {
        $ok = ma_fb_inbox_set(rawurldecode((string) $req['key']), sanitize_key((string) $req->get_param('status')));
        return new WP_REST_Response(['ok' => $ok], $ok ? 200 : 404);
    });
    ma_admin_route('/feedback/file/(?P<id>\d+)', 'GET', function (WP_REST_Request $req) {
        $msg = ma_fb_msg_row((int) $req['id']);
        return $msg ? ma_fb_file_json($msg) : new WP_Error('none', 'not found', ['status' => 404]);
    });
});

// ── The site's admin page (মতামত tab) ──

add_action('admin_post_ma_fb_set', function () {
    ma_acc_guard('ma_fb_set');
    $id = (int) ($_POST['id'] ?? 0);
    $st = sanitize_key(wp_unslash($_POST['status'] ?? ''));
    $who = ma_fb_key_of($id);
    ma_fb_set($id, $st);
    ma_acc_back($st === 'delete' ? 'কথোপকথন মুছে ফেলা হলো।' : 'রাখা হয়েছে।', 'ok', $st === 'delete' || $who === '' ? ['tab' => 'feedback'] : ['tab' => 'feedback', 'who' => $who]);
});

/** The inbox key of a conversation id ('' when there is none). */
function ma_fb_key_of($id) {
    global $wpdb;
    $r = $wpdb->get_row($wpdb->prepare('SELECT user_id, email FROM ' . ma_fb_table() . ' WHERE id = %d', $id), ARRAY_A);
    return $r ? ma_fb_key($r) : '';
}

add_action('admin_post_ma_fb_inbox_set', function () {
    ma_acc_guard('ma_fb_inbox_set');
    $who = sanitize_text_field(wp_unslash((string) ($_POST['who'] ?? '')));
    $what = sanitize_key((string) ($_POST['status'] ?? ''));
    ma_fb_inbox_set($who, $what);
    ma_acc_back($what === 'done' ? 'সব কথোপকথন শেষ হিসেবে রাখা হলো।' : 'আবার খোলা হলো।', 'ok', $what === 'done' ? ['tab' => 'feedback'] : ['tab' => 'feedback', 'who' => $who]);
});

add_action('admin_post_ma_fb_reply', function () {
    ma_acc_guard('ma_fb_reply');
    $id = (int) ($_POST['id'] ?? 0);
    $text = mb_substr(trim(sanitize_textarea_field(wp_unslash($_POST['text'] ?? ''))), 0, 2000);
    $file = [];
    if (!empty($_FILES['file']['tmp_name']) && is_uploaded_file($_FILES['file']['tmp_name'])) {
        $file = ma_fb_store_file((string) file_get_contents($_FILES['file']['tmp_name']), $_FILES['file']['name'] ?? '');
        if (is_wp_error($file)) {
            ma_acc_back('সংযুক্তি রাখা যায়নি — শুধু ছবি বা PDF, ৫ MB পর্যন্ত।', 'error', ['tab' => 'feedback', 'who' => ma_fb_key_of($id)]);
        }
    }
    $r = ma_fb_admin_reply($id, $text, $file ?: [], wp_get_current_user()->display_name);
    ma_acc_back(is_wp_error($r) ? 'কিছু লিখুন বা ফাইল দিন।' : 'উত্তর পাঠানো হয়েছে — সদস্যের ফোনে নোটিফিকেশন গেছে।', is_wp_error($r) ? 'error' : 'ok', ['tab' => 'feedback', 'who' => ma_fb_key_of($id)]);
});

/** Opens an attachment for a signed-in admin (never a public link). */
add_action('admin_post_ma_fb_file', function () {
    if (!current_user_can('ma_manage')) {
        wp_die('Not allowed', 403);
    }
    check_admin_referer('ma_fb_file');
    $msg = ma_fb_msg_row((int) ($_GET['msg'] ?? 0));
    $path = $msg && preg_match('/^[a-f0-9]{64}$/', $msg['file_key']) ? ma_fb_dir() . '/' . $msg['file_key'] : '';
    if ($path === '' || !is_file($path)) {
        wp_die('Not found', 404);
    }
    nocache_headers();
    header('Content-Type: ' . $msg['file_mime']);
    header('Content-Disposition: inline; filename="' . rawurlencode($msg['file_name']) . '"');
    header('X-Content-Type-Options: nosniff');
    readfile($path);
    exit;
});
