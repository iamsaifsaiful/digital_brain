<?php
/**
 * সমস্যার লগ (owner, 24 Oct night): errors the app ran into, sent so they
 * can be found and fixed. Only what a developer needs and nothing of the
 * member's: the kind of error, its first line cleaned of words, numbers and
 * quoted text (the app cleans it first, this server again), the places in
 * the app's code, and the app version. Same errors are counted together.
 * Shown on the site's "সমস্যার লগ" tab and in the admin app.
 */

if (!defined('ABSPATH')) {
    exit;
}

function ma_err_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_app_errors';
}

function ma_err_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $t = ma_err_table();
    dbDelta("CREATE TABLE $t (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        sig char(40) NOT NULL,
        user_id bigint(20) unsigned NOT NULL DEFAULT 0,
        kind varchar(80) NOT NULL DEFAULT '',
        message varchar(300) NOT NULL DEFAULT '',
        stack text NOT NULL,
        app_version varchar(32) NOT NULL DEFAULT '',
        hits int(11) unsigned NOT NULL DEFAULT 1,
        first_at datetime NOT NULL,
        last_at datetime NOT NULL,
        PRIMARY KEY  (id),
        UNIQUE KEY sig (sig),
        KEY last_at (last_at)
    ) " . $wpdb->get_charset_collate() . ';');
}

/** No member words: non-ASCII letters, quoted text, e-mails and long numbers go. */
function ma_err_clean($s, $max, $digits = 3) {
    $s = (string) $s;
    $s = preg_replace('/"[^"]*"|\'[^\']*\'/u', '…', $s);
    $s = preg_replace('/[^\x09\x0A\x20-\x7E]+/u', '•', $s);
    $s = preg_replace('/\S+@\S+/', '@', $s);
    // In the stack, line numbers stay (":120"); long numbers still go.
    $s = preg_replace('/\d{' . (int) $digits . ',}/', '#', $s);
    return mb_substr(trim($s), 0, $max);
}

/** At most 60 reports an hour from one address, so a loop cannot fill the table. */
function ma_err_too_many() {
    $k = 'ma_err_' . md5((string) ($_SERVER['REMOTE_ADDR'] ?? ''));
    $n = (int) get_transient($k);
    if ($n >= 60) {
        return true;
    }
    set_transient($k, $n + 1, HOUR_IN_SECONDS);
    return false;
}

function ma_err_receive(WP_REST_Request $req) {
    global $wpdb;
    if (ma_err_too_many()) {
        return new WP_Error('busy', 'too many', ['status' => 429]);
    }
    $in = json_decode($req->get_body(), true);
    $items = is_array($in['items'] ?? null) ? array_slice($in['items'], 0, 20) : [];
    $member = function_exists('ma_ai_member') ? ma_ai_member($req) : null;
    $uid = $member ? (int) $member['id'] : 0;
    $now = current_time('mysql', true);
    $t = ma_err_table();
    $n = 0;
    foreach ($items as $it) {
        if (!is_array($it)) {
            continue;
        }
        $kind = ma_err_clean($it['kind'] ?? '', 80);
        $msg = ma_err_clean($it['message'] ?? '', 300);
        $stack = ma_err_clean($it['stack'] ?? '', 2000, 6);
        $ver = mb_substr(preg_replace('/[^0-9A-Za-z.+\-]/', '', (string) ($it['version'] ?? '')), 0, 32);
        $hits = max(1, min(1000, (int) ($it['count'] ?? 1)));
        if ($kind === '' && $msg === '') {
            continue;
        }
        $sig = sha1($kind . '|' . $msg . '|' . implode("\n", array_slice(explode("\n", $stack), 0, 3)) . '|' . $ver);
        $row = $wpdb->get_row($wpdb->prepare("SELECT id, user_id FROM $t WHERE sig = %s", $sig), ARRAY_A);
        if ($row) {
            $wpdb->query($wpdb->prepare("UPDATE $t SET hits = hits + %d, last_at = %s WHERE id = %d", $hits, $now, $row['id']));
            if (!(int) $row['user_id'] && $uid) {
                $wpdb->update($t, ['user_id' => $uid], ['id' => $row['id']]);
            }
        } else {
            $wpdb->insert($t, ['sig' => $sig, 'user_id' => $uid, 'kind' => $kind, 'message' => $msg, 'stack' => $stack, 'app_version' => $ver, 'hits' => $hits, 'first_at' => $now, 'last_at' => $now]);
        }
        $n++;
    }
    return ['ok' => true, 'kept' => $n];
}

/** The latest errors, most recent first, for the site and the admin app. */
function ma_err_list($limit = 200) {
    global $wpdb;
    $rows = $wpdb->get_results($wpdb->prepare('SELECT e.*, u.email FROM ' . ma_err_table() . ' e LEFT JOIN ' . ma_acc_table() . ' u ON u.id = e.user_id ORDER BY e.last_at DESC LIMIT %d', $limit), ARRAY_A) ?: [];
    return array_map(function ($r) {
        return [
            'id' => (int) $r['id'],
            'kind' => $r['kind'],
            'message' => $r['message'],
            'stack' => $r['stack'],
            'version' => $r['app_version'],
            'count' => (int) $r['hits'],
            'first_at' => gmdate('c', ma_acc_ts($r['first_at'])),
            'last_at' => gmdate('c', ma_acc_ts($r['last_at'])),
            'email' => (string) ($r['email'] ?? ''),
        ];
    }, $rows);
}

add_action('rest_api_init', function () {
    register_rest_route('my-assistant/v1', '/errors', [
        'methods' => 'POST',
        'callback' => 'ma_err_receive',
        'permission_callback' => '__return_true', // sent before sign-in too; nothing of the member's
    ]);
    ma_admin_route('/errors', 'GET', function () {
        return ['errors' => ma_err_list()];
    });
    ma_admin_route('/errors/clear', 'POST', function () {
        global $wpdb;
        $wpdb->query('DELETE FROM ' . ma_err_table());
        return ['errors' => []];
    });
});

add_action('admin_post_ma_err_clear', function () {
    ma_acc_guard('ma_err_clear');
    global $wpdb;
    $wpdb->query('DELETE FROM ' . ma_err_table());
    ma_acc_back('সমস্যার লগ খালি করা হয়েছে।', 'ok', ['tab' => 'errors']);
});

function ma_acc_render_errors() {
    $list = ma_err_list();
    $post = esc_url(admin_url('admin-post.php'));
    ?>
    <section class="ma-card">
        <div class="ma-bar">
            <div class="ma-bar-title"><h2>সমস্যার লগ</h2><span class="ma-count"><?php echo esc_html(ma_acc_bn(count($list))); ?>টা</span></div>
            <?php if ($list) : ?>
                <div class="ma-bar-actions">
                    <form method="post" action="<?php echo $post; ?>" onsubmit="return confirm('সব লগ মুছে ফেলবেন?')">
                        <input type="hidden" name="action" value="ma_err_clear"><?php wp_nonce_field('ma_err_clear'); ?>
                        <button class="ma-chip" type="submit">সব মুছুন</button>
                    </form>
                </div>
            <?php endif; ?>
        </div>
        <p class="muted ma-pad">অ্যাপে কোনো ভুল (error) হলে এখানে আসে — ভুলের ধরন, কোডের কোন জায়গায় আর অ্যাপের ভার্সন। সদস্যের লেখা, পাসওয়ার্ড বা স্বাস্থ্যের কিছু আসে না। একই ভুল একসাথে গোনা হয়।</p>
        <?php if (!$list) : ?>
            <div class="ma-empty"><h3>কোনো সমস্যা আসেনি</h3><p>অ্যাপে ভুল হলে এখানে দেখা যাবে।</p></div>
        <?php else : ?>
            <div class="ma-fb">
                <?php foreach ($list as $e) : ?>
                    <details class="ma-fb-item" style="display:block">
                        <summary>
                            <span class="ma-pill trial"><?php echo esc_html(ma_acc_bn($e['count'])); ?> বার</span>
                            <strong class="ma-mono"><?php echo esc_html($e['kind']); ?></strong>
                            <span class="muted"> · <?php echo esc_html($e['version']); ?> · <?php echo esc_html(get_date_from_gmt(gmdate('Y-m-d H:i:s', strtotime($e['last_at'])), 'j M, g:i a')); ?><?php echo $e['email'] !== '' ? ' · ' . esc_html($e['email']) : ''; ?></span>
                            <div class="ma-mono" style="margin-top:4px"><?php echo esc_html($e['message']); ?></div>
                        </summary>
                        <pre class="ma-mono" style="white-space:pre-wrap;font-size:12px;margin:8px 0 0"><?php echo esc_html($e['stack']); ?></pre>
                    </details>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </section>
    <?php
}
