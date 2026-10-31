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
        level varchar(10) NOT NULL DEFAULT 'crash',
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
    $k = 'ma_err_' . md5(ma_client_ip());
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
        $level = ($it['level'] ?? '') === 'problem' ? 'problem' : 'crash';
        if ($kind === '' && $msg === '') {
            continue;
        }
        $sig = sha1($level . '|' . $kind . '|' . $msg . '|' . implode("\n", array_slice(explode("\n", $stack), 0, 3)) . '|' . $ver);
        $row = $wpdb->get_row($wpdb->prepare("SELECT id, user_id FROM $t WHERE sig = %s", $sig), ARRAY_A);
        if ($row) {
            $wpdb->query($wpdb->prepare("UPDATE $t SET hits = hits + %d, last_at = %s WHERE id = %d", $hits, $now, $row['id']));
            if (!(int) $row['user_id'] && $uid) {
                $wpdb->update($t, ['user_id' => $uid], ['id' => $row['id']]);
            }
        } else {
            $wpdb->insert($t, ['sig' => $sig, 'user_id' => $uid, 'level' => $level, 'kind' => $kind, 'message' => $msg, 'stack' => $stack, 'app_version' => $ver, 'hits' => $hits, 'first_at' => $now, 'last_at' => $now]);
        }
        $n++;
    }
    return ['ok' => true, 'kept' => $n];
}

/** What a report means, in plain Bangla (from the app's own codes). */
function ma_err_meaning($level, $kind, $msg) {
    $ai = [
        'timeout' => 'ইন্টারনেট ধীর — AI সময়মতো উত্তর দেয়নি', 'offline' => 'ইন্টারনেট ছিল না — AI-তে যাওয়া যায়নি',
        'session' => 'AI-র জন্য আবার লগইন লাগবে', 'not_pro' => 'প্রিমিয়াম নেই বলে AI পায়নি', 'daily_limit' => 'দিনের AI প্রশ্ন শেষ',
        'off' => 'AI বন্ধ রাখা আছে', 'key' => 'API key ঠিক নেই', 'rate' => 'একসাথে অনেক অনুরোধ', 'credit' => 'API-র ক্রেডিট শেষ', 'bad_reply' => 'AI-র উত্তর বোঝা যায়নি',
    ];
    $voice = [
        'error_network' => 'কথা শোনার সময় ইন্টারনেট পায়নি', 'error_network_timeout' => 'কথা শোনার সময় ইন্টারনেট ধীর', 'error_server' => 'Google-এর কথা শোনার সার্ভারে সমস্যা',
        'error_audio' => 'মাইক্রোফোন থেকে শব্দ পায়নি', 'error_permission' => 'মাইক্রোফোনের অনুমতি নেই', 'error_busy' => 'কথা শোনার যন্ত্র ব্যস্ত ছিল',
        'error_recognizer_busy' => 'কথা শোনার যন্ত্র ব্যস্ত ছিল', 'error_client' => 'কথা শোনা মাঝপথে বন্ধ হয়েছে', 'error_language_not_supported' => 'ফোনে বাংলা কথা শোনা নেই',
        'error_language_unavailable' => 'ফোনে বাংলা কথা শোনা এখন পাওয়া যাচ্ছে না', 'error_server_disconnected' => 'কথা শোনার সার্ভারের সাথে যোগাযোগ কেটে গেছে', 'error_too_many_requests' => 'কথা শোনার অনুরোধ বেশি হয়ে গেছে',
    ];
    if ($kind === 'AiSlow') {
        return 'AI দেরি করেছে — ফোন নিজের নিয়মে বুঝে নিয়েছে';
    }
    if ($kind === 'AiError') {
        return $ai[$msg] ?? (str_starts_with($msg, 'status_') ? 'AI সার্ভার ভুল উত্তর দিয়েছে (' . substr($msg, 7) . ')' : 'AI কাজ করেনি');
    }
    if ($kind === 'Voice') {
        return $voice[$msg] ?? 'কথা শোনায় সমস্যা';
    }
    if ($kind === 'VoiceInit') {
        return 'কথা শোনা চালুই হয়নি';
    }
    if ($kind === 'DataLoad') {
        return 'সদস্যের তথ্য খোলা যায়নি';
    }
    if ($kind === 'Server') {
        return 'আমাদের সার্ভার ভুল উত্তর দিয়েছে';
    }
    if (str_starts_with($kind, 'Android:')) {
        return 'অ্যাপ বন্ধ হয়ে গেছে (Android অংশে)';
    }
    return $level === 'crash' ? 'অ্যাপে ভুল — কেউ সামলায়নি' : 'সমস্যা';
}

/** The latest errors, most recent first, for the site and the admin app. $level '' = all. */
function ma_err_list($limit = 200, $level = '') {
    global $wpdb;
    $where = in_array($level, ['crash', 'problem'], true) ? $wpdb->prepare(' WHERE e.level = %s', $level) : '';
    $rows = $wpdb->get_results($wpdb->prepare('SELECT e.*, u.email FROM ' . ma_err_table() . ' e LEFT JOIN ' . ma_acc_table() . ' u ON u.id = e.user_id' . $where . ' ORDER BY e.last_at DESC LIMIT %d', $limit), ARRAY_A) ?: [];
    return array_map(function ($r) {
        $level = ($r['level'] ?? '') === 'problem' ? 'problem' : 'crash';
        return [
            'id' => (int) $r['id'],
            'level' => $level,
            'level_label' => $level === 'crash' ? 'ক্র্যাশ' : 'সমস্যা',
            'meaning' => ma_err_meaning($level, $r['kind'], $r['message']),
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

/** The list as plain text (for copying): level, count, kind, meaning, version, times, message and code places — no e-mails. */
function ma_err_text(array $list) {
    $out = ['My Assistant — সমস্যার লগ', 'সময় (UTC): ' . gmdate('Y-m-d H:i') . ' · প্লাগিন ' . MA_ACC_VERSION . ' · মোট ' . count($list) . 'টা', ''];
    foreach ($list as $i => $e) {
        $out[] = '#' . ($i + 1) . ' ' . $e['level_label'] . ' · ' . $e['count'] . ' বার · ' . $e['kind'] . ' · ' . $e['meaning'];
        $out[] = 'অ্যাপ ' . $e['version'] . ' · প্রথম ' . substr($e['first_at'], 0, 16) . ' · শেষ ' . substr($e['last_at'], 0, 16) . ' (UTC)';
        if ((string) $e['message'] !== '') {
            $out[] = 'বার্তা: ' . $e['message'];
        }
        if ((string) $e['stack'] !== '') {
            $out[] = trim((string) $e['stack']);
        }
        $out[] = '';
    }
    return implode("\n", $out);
}

add_action('rest_api_init', function () {
    register_rest_route('my-assistant/v1', '/errors', [
        'methods' => 'POST',
        'callback' => 'ma_err_receive',
        'permission_callback' => '__return_true', // sent before sign-in too; nothing of the member's
    ]);
    ma_admin_route('/errors', 'GET', function (WP_REST_Request $req) {
        return ['errors' => ma_err_list(200, (string) $req->get_param('level')), 'counts' => ma_err_counts()];
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

/** How many of each, and how many came in the last day. */
function ma_err_counts() {
    global $wpdb;
    $t = ma_err_table();
    $out = ['crash' => 0, 'problem' => 0, 'day' => 0];
    foreach ($wpdb->get_results("SELECT level, SUM(hits) AS n FROM $t GROUP BY level", ARRAY_A) ?: [] as $r) {
        $out[$r['level'] === 'problem' ? 'problem' : 'crash'] += (int) $r['n'];
    }
    $out['day'] = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $t WHERE last_at >= %s", gmdate('Y-m-d H:i:s', time() - DAY_IN_SECONDS)));
    return $out;
}

function ma_acc_render_errors() {
    $lv = sanitize_key((string) ($_GET['lv'] ?? ''));
    $list = ma_err_list(200, $lv);
    $cnt = ma_err_counts();
    $post = esc_url(admin_url('admin-post.php'));
    ?>
    <section class="ma-card">
        <div class="ma-bar">
            <div class="ma-bar-title"><h2>সমস্যার লগ</h2><span class="ma-count"><?php echo esc_html(ma_acc_bn(count($list))); ?>টা</span></div>
            <?php if ($list) : ?>
                <div class="ma-bar-actions">
                    <button class="ma-chip" type="button" id="ma-err-copy" onclick="maErrCopy(this)">সব কপি করুন</button>
                    <form method="post" action="<?php echo $post; ?>" onsubmit="return confirm('সব লগ মুছে ফেলবেন?')">
                        <input type="hidden" name="action" value="ma_err_clear"><?php wp_nonce_field('ma_err_clear'); ?>
                        <button class="ma-chip" type="submit">সব মুছুন</button>
                    </form>
                </div>
            <?php endif; ?>
        </div>
        <p class="muted ma-pad">সদস্যদের ফোন থেকে সরাসরি আসে — ঘটার কয়েক সেকেন্ডের মধ্যে; ইন্টারনেট না থাকলে বা অ্যাপ বন্ধ হয়ে গেলে ফোনে জমা থাকে, পরে আসে। <strong>ক্র্যাশ</strong> = অ্যাপে এমন ভুল যা কেউ সামলায়নি (অ্যাপ বন্ধও হয়ে যেতে পারে)। <strong>সমস্যা</strong> = অ্যাপ সামলেছে কিন্তু সদস্য টের পেয়েছেন — AI দেরি বা কাজ না করা, কথা শুনতে না পারা, তথ্য না খোলা, সার্ভারের ভুল। আসে শুধু ধরন, কোডের জায়গা আর ভার্সন — সদস্যের লেখা, বলা কথা, পাসওয়ার্ড বা স্বাস্থ্যের কিছু নয়। একই জিনিস একসাথে গোনা হয়।</p>
        <div class="ma-chips ma-pad">
            <a class="ma-chip <?php echo $lv === '' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'errors']); ?>">সব</a>
            <a class="ma-chip <?php echo $lv === 'crash' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'errors', 'lv' => 'crash']); ?>">ক্র্যাশ <?php echo esc_html(ma_acc_bn($cnt['crash'])); ?> বার</a>
            <a class="ma-chip <?php echo $lv === 'problem' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'errors', 'lv' => 'problem']); ?>">সমস্যা <?php echo esc_html(ma_acc_bn($cnt['problem'])); ?> বার</a>
            <span class="muted">· গত ২৪ ঘণ্টায় <?php echo esc_html(ma_acc_bn($cnt['day'])); ?> ধরনের</span>
        </div>
        <?php if (!$list) : ?>
            <div class="ma-empty"><h3>কোনো সমস্যা আসেনি</h3><p>সদস্যদের ফোনে ভুল বা সমস্যা হলে কয়েক সেকেন্ডের মধ্যে এখানে দেখা যাবে (অ্যাপ ২.৫৫.১২ থেকে; আগের অ্যাপ শুধু ক্র্যাশ পাঠায়, অ্যাপ সরালে)।</p></div>
        <?php else : ?>
            <?php /* Everything on this list as one text, for "সব কপি করুন" (owner, 31 Oct: to paste to Claude). Members' e-mails are left out. */ ?>
            <textarea id="ma-err-text" readonly hidden><?php echo esc_textarea(ma_err_text($list)); ?></textarea>
            <script>
            function maErrCopy(b) {
                var t = document.getElementById('ma-err-text');
                var done = function () { b.textContent = 'কপি হয়েছে ✓'; setTimeout(function () { b.textContent = 'সব কপি করুন'; }, 2500); };
                if (navigator.clipboard && window.isSecureContext) {
                    navigator.clipboard.writeText(t.value).then(done, function () { maErrCopyOld(t); done(); });
                } else { maErrCopyOld(t); done(); }
            }
            function maErrCopyOld(t) { t.hidden = false; t.select(); document.execCommand('copy'); t.hidden = true; }
            </script>
            <div class="ma-fb">
                <?php foreach ($list as $e) : ?>
                    <details class="ma-fb-item" style="display:block">
                        <summary>
                            <span class="ma-pill <?php echo $e['level'] === 'crash' ? 'expired' : 'trial'; ?>"><?php echo esc_html($e['level_label']); ?> · <?php echo esc_html(ma_acc_bn($e['count'])); ?> বার</span>
                            <strong><?php echo esc_html($e['meaning']); ?></strong>
                            <span class="ma-mono muted"> <?php echo esc_html($e['kind']); ?></span>
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
