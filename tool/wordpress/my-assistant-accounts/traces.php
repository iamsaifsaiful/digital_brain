<?php
/**
 * সমস্যা খোঁজার লগ (owner, 28 Oct): a member may choose to send the app's
 * conversation log to us, now or each time they leave the app. The phone
 * leaves out every conversation about passwords, the vault, PIN/OTP,
 * health, medicines or messages, and hides long numbers; this server does
 * the same again before keeping anything. Kept 30 days, newest 500.
 * Seen in the admin app (সমস্যা খোঁজার লগ).
 */

if (!defined('ABSPATH')) {
    exit;
}

function ma_tr_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_app_traces';
}

function ma_tr_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $t = ma_tr_table();
    dbDelta("CREATE TABLE $t (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        user_id bigint(20) unsigned NOT NULL DEFAULT 0,
        app_version varchar(32) NOT NULL DEFAULT '',
        n int(11) unsigned NOT NULL DEFAULT 0,
        body mediumtext NOT NULL,
        at datetime NOT NULL,
        PRIMARY KEY  (id),
        KEY at (at)
    ) " . $wpdb->get_charset_collate() . ';');
}

/** The same private words the phone looks for: such a line is never kept. */
function ma_tr_private($s) {
    return (bool) preg_match('/পাসওয়ার্ড|পাসওয়ার্ড|password|ভল্ট|vault|পিন|\bpin\b|otp|ওটিপি|কোড|\bcode\b|গোপন|কার্ড|card|স্বাস্থ্য|health|ওষুধ|ঔষধ|medicine|\bmed|ট্যাবলেট|ইনসুলিন|ডাক্তার|doctor|হাসপাতাল|প্রেসার|রক্ত|ডায়াবেটিস|সুগার|ওজন|weight|bmi|পিরিয়ড|গর্ভ|টিকা|vaccine|অসুখ|জ্বর|ব্যথা|রোগ|ঘুম|sleep|নোটিফিকেশন|notification|মেসেজ|message|sms|বিকাশ|bkash/iu', $s);
}

function ma_tr_clean_line($s) {
    $s = mb_substr((string) $s, 0, 600);
    $s = preg_replace('/\S+@\S+/u', '@', $s);
    // Six or more digits in a row (Bangla or English) are hidden.
    $s = preg_replace('/[+]?[0-9০-৯][0-9০-৯ \-]{4,}[0-9০-৯]/u', '••••••', $s);
    return $s;
}

function ma_tr_receive(WP_REST_Request $req) {
    global $wpdb;
    $k = 'ma_tr_' . md5(ma_client_ip());
    $n = (int) get_transient($k);
    if ($n >= 12) {
        return new WP_Error('busy', 'too many', ['status' => 429]);
    }
    set_transient($k, $n + 1, HOUR_IN_SECONDS);
    $in = json_decode($req->get_body(), true);
    $lines = [];
    foreach (array_slice(is_array($in['lines'] ?? null) ? $in['lines'] : [], 0, 400) as $l) {
        if (!is_string($l) || ma_tr_private($l)) {
            continue;
        }
        $lines[] = ma_tr_clean_line($l);
    }
    if (!$lines) {
        return ['ok' => true, 'kept' => 0];
    }
    $member = function_exists('ma_ai_member') ? ma_ai_member($req) : null;
    $ver = mb_substr(preg_replace('/[^0-9A-Za-z.+\-]/', '', (string) ($in['version'] ?? '')), 0, 32);
    $t = ma_tr_table();
    $wpdb->insert($t, ['user_id' => $member ? (int) $member['id'] : 0, 'app_version' => $ver, 'n' => count($lines), 'body' => implode("\n", $lines), 'at' => current_time('mysql', true)]);
    // Older than 30 days, or beyond the newest 500, go.
    $wpdb->query($wpdb->prepare("DELETE FROM $t WHERE at < %s", gmdate('Y-m-d H:i:s', time() - 30 * DAY_IN_SECONDS)));
    $keep = (int) $wpdb->get_var("SELECT id FROM $t ORDER BY id DESC LIMIT 1 OFFSET 499");
    if ($keep) {
        $wpdb->query($wpdb->prepare("DELETE FROM $t WHERE id < %d", $keep));
    }
    return ['ok' => true, 'kept' => count($lines)];
}

function ma_tr_list($limit = 100) {
    global $wpdb;
    $rows = $wpdb->get_results($wpdb->prepare('SELECT t.id, t.user_id, t.app_version, t.n, t.at, SUBSTRING(t.body, 1, 160) AS head, u.email FROM ' . ma_tr_table() . ' t LEFT JOIN ' . ma_acc_table() . ' u ON u.id = t.user_id ORDER BY t.id DESC LIMIT %d', $limit), ARRAY_A) ?: [];
    return array_map(fn($r) => [
        'id' => (int) $r['id'],
        'email' => (string) ($r['email'] ?? ''),
        'version' => $r['app_version'],
        'lines' => (int) $r['n'],
        'head' => (string) $r['head'],
        'at' => gmdate('c', ma_acc_ts($r['at'])),
    ], $rows);
}

add_action('rest_api_init', function () {
    register_rest_route('my-assistant/v1', '/trace', [
        'methods' => 'POST',
        'callback' => 'ma_tr_receive',
        'permission_callback' => '__return_true', // the member's own choice; cleaned on the phone and here
    ]);
    ma_admin_route('/traces', 'GET', function () {
        return ['traces' => ma_tr_list()];
    });
    ma_admin_route('/traces/(?P<id>\d+)', 'GET', function (WP_REST_Request $req) {
        global $wpdb;
        $r = $wpdb->get_row($wpdb->prepare('SELECT body FROM ' . ma_tr_table() . ' WHERE id = %d', (int) $req['id']), ARRAY_A);
        return $r ? ['body' => $r['body']] : new WP_Error('not_found', 'নেই', ['status' => 404]);
    });
    ma_admin_route('/traces/clear', 'POST', function () {
        global $wpdb;
        $wpdb->query('DELETE FROM ' . ma_tr_table());
        return ['traces' => []];
    });
});
