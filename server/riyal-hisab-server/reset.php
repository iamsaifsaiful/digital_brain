<?php
/**
 * Starting over: the main admin, from the app, with their server password.
 * First a backup of everything is kept on the server (and sent to Google
 * Drive when that is set up), together with a plain copy of every record and
 * login, so nothing is lost; then every record, photo, notification, other
 * login and session is removed. The main admin's own login stays.
 */

if (!defined('ABSPATH')) {
    exit;
}

add_action('rest_api_init', function () {
    rh_route('/reset', 'POST', 'rh_reset', 'admin');
});

/** A backup taken by a reset stays at least this many days; nobody can delete it before. */
const RH_ARCHIVE_DAYS = 30;

function rh_archive_deletable($r) {
    return strtotime($r['at'] . ' UTC') <= time() - RH_ARCHIVE_DAYS * DAY_IN_SECONDS;
}

function rh_reset(WP_REST_Request $req, $u) {
    global $wpdb, $rh_cache;
    if ($u['role'] !== 'owner') {
        return rh_hidden();
    }
    if (rh_rate_limited('reset')) {
        return new WP_Error('rh_limit', 'too many tries', ['status' => 429]);
    }
    $pass = (string) $req->get_param('password');
    if (!password_verify($pass, $u['pass_hash'])) {
        return new WP_Error('wrong', 'wrong password', ['status' => 403]);
    }

    // 1. The backup, locked with the main admin's password (opens in the app).
    $bytes = rh_backup_bytes($pass);

    // 2. Everything as it was, kept on the server.
    $kinds = ['customer', 'agent', 'txn', 'deposit', 'payment', 'expense', 'close', 'loss', 'handover', 'adjust', 'log', 'settings'];
    $data = [];
    $counts = [];
    foreach ($kinds as $k) {
        $data[$k] = array_values(rh_all($k));
        $counts[$k] = count($data[$k]);
    }
    $users = $wpdb->get_results('SELECT id, role, name, login, agent_rid, status, perms, created_at, last_seen FROM ' . rh_t('users') . ' ORDER BY id', ARRAY_A);
    $wpdb->insert(rh_t('archives'), [
        'at' => rh_now(),
        'by_id' => (int) $u['id'],
        'by_name' => (string) $u['name'],
        'summary' => wp_json_encode($counts),
        'users' => wp_json_encode($users, JSON_UNESCAPED_UNICODE),
        'data' => wp_json_encode($data, JSON_UNESCAPED_UNICODE),
        'backup' => base64_encode($bytes),
    ]);
    $archive = (int) $wpdb->insert_id;
    if ($archive <= 0) {
        return new WP_Error('rh_archive', 'could not keep the backup', ['status' => 500]);
    }
    $drive = '';
    if (function_exists('rh_gd_state')) {
        $s = rh_gd_state();
        if ($s['refresh'] !== '' && $s['password'] !== '') {
            $drive = rh_gd_run() ? 'ok' : 'failed';
        }
    }

    // 3. Everything goes, except the main admin's own login and this session.
    $wpdb->query('DELETE FROM ' . rh_t('records'));
    $wpdb->query('DELETE FROM ' . rh_t('photos'));
    $wpdb->query('DELETE FROM ' . rh_t('notes'));
    $wpdb->query($wpdb->prepare('DELETE FROM ' . rh_t('sessions') . ' WHERE id <> %d', (int) $u['session_id']));
    $wpdb->query($wpdb->prepare('DELETE FROM ' . rh_t('users') . ' WHERE id <> %d', (int) $u['id']));
    $rh_cache = [];

    // 4. The new account starts with one log line about it.
    $others = count(array_filter($users, fn($x) => (int) $x['id'] !== (int) $u['id']));
    $detail = sprintf('আগের হিসাব রাখা আছে (রেকর্ড #%s): %s গ্রাহক · %s লেনদেন · %s এজেন্ট · %s লগইন মোছা হলো',
        rh_bn($archive), rh_bn($counts['customer']), rh_bn($counts['txn']), rh_bn($counts['agent']), rh_bn($others));
    rh_add_log('সব হিসাব রিসেট', $detail, (string) $u['name'], '', 'sys');

    return rest_ensure_response([
        'ok' => true,
        'archive' => $archive,
        'counts' => $counts,
        'logins' => $others,
        'drive' => $drive,
        'name' => 'remit-khata-reset-' . current_time('Y-m-d-Hi') . '.rhb',
        'backup' => base64_encode($bytes),
    ]);
}

/** The admin menu: every reset, with its backup and its records. */
function rh_tab_resets() {
    global $wpdb;
    $rows = $wpdb->get_results('SELECT id, at, by_name, summary, users FROM ' . rh_t('archives') . ' ORDER BY id DESC', ARRAY_A);
    $names = ['customer' => 'গ্রাহক', 'txn' => 'লেনদেন', 'agent' => 'এজেন্ট', 'deposit' => 'জমা', 'payment' => 'এজেন্টকে দেওয়া', 'expense' => 'খরচ', 'loss' => 'লস', 'handover' => 'হাতবদল', 'adjust' => 'অতিরিক্ত হিসাব', 'log' => 'লগ'];
    ?>
    <p class="rh-muted">অ্যাপ থেকে মূল এডমিন "সব হিসাব রিসেট" করলে মোছার আগে পুরো হিসাব এখানে রাখা হয়। ৩০ দিনের আগে কেউ এটা মুছতে পারবে না। ব্যাকআপ ফাইল (.rhb) মূল এডমিনের সেই সময়ের সার্ভার পাসওয়ার্ড দিয়ে খোলে — অ্যাপের "ব্যাকআপ থেকে ফিরিয়ে আনুন" দিয়ে। পুরো রেকর্ড (JSON) পড়ার মতো, তালা ছাড়া।</p>
    <table class="rh-table"><thead><tr><th>#</th><th>সময়</th><th>কে করলেন</th><th>যা ছিল</th><th>মোছা লগইন</th><th>ডাউনলোড</th></tr></thead><tbody>
    <?php foreach ($rows as $r) :
        $c = json_decode((string) $r['summary'], true) ?: [];
        $us = array_filter(json_decode((string) $r['users'], true) ?: [], fn($x) => ($x['role'] ?? '') !== 'owner');
        $parts = [];
        foreach ($names as $k => $label) {
            if (!empty($c[$k])) {
                $parts[] = rh_bn($c[$k]) . ' ' . $label;
            }
        }
        ?>
        <tr>
            <td><?php echo esc_html(rh_bn($r['id'])); ?></td>
            <td><?php echo esc_html(rh_when(get_date_from_gmt($r['at'], 'Y-m-d\TH:i:s'))); ?></td>
            <td><?php echo esc_html($r['by_name']); ?></td>
            <td><?php echo esc_html(implode(' · ', $parts) ?: '—'); ?></td>
            <td><?php echo esc_html(implode(', ', array_map(fn($x) => $x['name'] . ' (' . ($x['role'] === 'agent' ? 'এজেন্ট' : 'এডমিন') . ')', $us)) ?: '—'); ?></td>
            <td>
                <?php foreach (['rhb' => 'ব্যাকআপ (.rhb)', 'json' => 'পুরো রেকর্ড (JSON)'] as $what => $label) : ?>
                    <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" style="display:inline">
                        <?php wp_nonce_field('rh_archive_download'); ?>
                        <input type="hidden" name="action" value="rh_archive_download">
                        <input type="hidden" name="id" value="<?php echo (int) $r['id']; ?>">
                        <input type="hidden" name="what" value="<?php echo esc_attr($what); ?>">
                        <button class="rh-btn" style="margin:2px"><?php echo esc_html($label); ?></button>
                    </form>
                <?php endforeach; ?>
                <?php if (rh_archive_deletable($r)) : ?>
                    <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" style="display:inline" onsubmit="return confirm('এই রিসেটের ব্যাকআপ আর রেকর্ড মুছে ফেলবেন? ফেরানো যাবে না।')">
                        <?php wp_nonce_field('rh_archive_delete'); ?>
                        <input type="hidden" name="action" value="rh_archive_delete">
                        <input type="hidden" name="id" value="<?php echo (int) $r['id']; ?>">
                        <button class="rh-btn" style="margin:2px;color:#c5221f">মুছুন</button>
                    </form>
                <?php else : ?>
                    <small class="rh-muted"><?php echo esc_html(rh_bn(gmdate('Y-m-d', strtotime($r['at'] . ' UTC') + RH_ARCHIVE_DAYS * DAY_IN_SECONDS))); ?>-এর আগে মোছা যাবে না</small>
                <?php endif; ?>
            </td>
        </tr>
    <?php endforeach; ?>
    <?php if (!$rows) : ?><tr><td colspan="6" class="rh-empty">কখনো রিসেট হয়নি।</td></tr><?php endif; ?>
    </tbody></table>
    <?php
}

add_action('admin_post_rh_archive_download', function () {
    global $wpdb;
    if (!current_user_can('manage_options') || !check_admin_referer('rh_archive_download')) {
        wp_die('অনুমতি নেই');
    }
    $r = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . rh_t('archives') . ' WHERE id = %d', (int) ($_POST['id'] ?? 0)), ARRAY_A);
    if (!$r) {
        wp_die('নেই');
    }
    $json = ($_POST['what'] ?? '') === 'json';
    $body = $json
        ? wp_json_encode(['at' => $r['at'], 'by' => $r['by_name'], 'logins' => json_decode($r['users'], true), 'records' => json_decode($r['data'], true)], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT)
        : base64_decode($r['backup']);
    $name = 'remit-khata-reset-' . (int) $r['id'] . ($json ? '.json' : '.rhb');
    if (defined('RH_TEST')) {
        throw new RuntimeException('download:' . base64_encode($body));
    }
    nocache_headers();
    header('Content-Type: ' . ($json ? 'application/json; charset=utf-8' : 'application/octet-stream'));
    header('Content-Disposition: attachment; filename="' . $name . '"');
    header('Content-Length: ' . strlen($body));
    echo $body;
    exit;
});

add_action('admin_post_rh_archive_delete', function () {
    global $wpdb;
    if (!current_user_can('manage_options') || !check_admin_referer('rh_archive_delete')) {
        wp_die('অনুমতি নেই');
    }
    $r = $wpdb->get_row($wpdb->prepare('SELECT id, at FROM ' . rh_t('archives') . ' WHERE id = %d', (int) ($_POST['id'] ?? 0)), ARRAY_A);
    if (!$r) {
        rh_back('resets', 'নেই।', true);
    }
    if (!rh_archive_deletable($r)) {
        rh_back('resets', 'রিসেটের ব্যাকআপ ৩০ দিনের আগে মোছা যায় না।', true);
    }
    $wpdb->delete(rh_t('archives'), ['id' => (int) $r['id']]);
    rh_back('resets', 'মোছা হলো।');
});
