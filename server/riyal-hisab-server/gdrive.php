<?php
/**
 * Automatic backup to Google Drive, once a day: the whole account (and the
 * photos) in the app's own backup format, locked with a backup password.
 * It can be opened in the app (সেটিংস → ব্যাকআপ থেকে ফিরিয়ে আনুন) and is
 * useless without that password. Google sees only a locked file.
 */

if (!defined('ABSPATH')) {
    exit;
}

const RH_GD_SCOPE = 'https://www.googleapis.com/auth/drive.file openid email';

function rh_gd_redirect() {
    return admin_url('admin-post.php?action=rh_gdrive_cb');
}

/** Small secrets at rest: AES-256-GCM with a key from the site's salts. */
function rh_seal($plain) {
    $key = hash('sha256', 'rh-site-v1|' . wp_salt('secure_auth'), true);
    $iv = random_bytes(12);
    $tag = '';
    $ct = openssl_encrypt((string) $plain, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag, '', 16);
    return 'enc1:' . base64_encode($iv . $tag . $ct);
}

function rh_unseal($sealed) {
    $sealed = (string) $sealed;
    if (strpos($sealed, 'enc1:') !== 0) {
        return '';
    }
    $raw = base64_decode(substr($sealed, 5), true);
    if ($raw === false || strlen($raw) < 29) {
        return '';
    }
    $key = hash('sha256', 'rh-site-v1|' . wp_salt('secure_auth'), true);
    $out = openssl_decrypt(substr($raw, 28), 'aes-256-gcm', $key, OPENSSL_RAW_DATA, substr($raw, 0, 12), substr($raw, 12, 16), '');
    return $out === false ? '' : $out;
}

function rh_gd_state() {
    return [
        'client_id' => (string) get_option('rh_gd_client_id', ''),
        'client_secret' => rh_unseal(get_option('rh_gd_client_secret', '')),
        'refresh' => rh_unseal(get_option('rh_gd_refresh', '')),
        'password' => rh_unseal(get_option('rh_gd_password', '')),
        'email' => (string) get_option('rh_gd_email', ''),
        'keep' => max(3, (int) get_option('rh_gd_keep', 30)),
        'last' => get_option('rh_gd_last', []),
    ];
}

/**
 * The app's backup file: "RHSBBK1" + salt(16) + iterations(4, big-endian)
 * + AES-256-GCM(nonce 12 | text | tag 16) of {data, photos}, key from the
 * password with PBKDF2-HMAC-SHA256 (lib/services/store.dart, Backup).
 */
function rh_backup_bytes($password) {
    global $wpdb;
    $lists = ['customer' => 'customers', 'agent' => 'agents', 'txn' => 'txns', 'deposit' => 'deposits', 'payment' => 'agentPayments', 'expense' => 'expenses', 'close' => 'closes', 'loss' => 'losses', 'handover' => 'handovers', 'adjust' => 'adjusts', 'log' => 'log'];
    $data = ['v' => 1];
    foreach ($lists as $kind => $key) {
        $data[$key] = array_values(rh_all($kind));
    }
    usort($data['log'], fn($a, $b) => strcmp((string) ($a['at'] ?? ''), (string) ($b['at'] ?? '')));
    $settings = rh_all('settings')['main'] ?? [];
    $data['settings'] = $settings + ['ownerName' => '', 'defaultDueLimit' => 1000, 'oldDueDays' => 7, 'dupMinutes' => 10, 'nextNo' => 1001];
    $photos = [];
    foreach ($wpdb->get_results('SELECT pid, data FROM ' . rh_t('photos'), ARRAY_A) as $p) {
        $photos[$p['pid']] = $p['data'];
    }
    $clear = wp_json_encode(['data' => $data, 'photos' => (object) $photos], JSON_UNESCAPED_UNICODE);
    $salt = random_bytes(16);
    $iter = 120000;
    $key = hash_pbkdf2('sha256', $password, $salt, $iter, 32, true);
    $iv = random_bytes(12);
    $tag = '';
    $ct = openssl_encrypt($clear, 'aes-256-gcm', $key, OPENSSL_RAW_DATA, $iv, $tag, '', 16);
    return 'RHSBBK1' . $salt . pack('N', $iter) . $iv . $ct . $tag;
}

function rh_gd_token() {
    $s = rh_gd_state();
    if ($s['client_id'] === '' || $s['refresh'] === '') {
        return new WP_Error('setup', 'Google Drive সংযোগ দেওয়া নেই');
    }
    $res = wp_remote_post('https://oauth2.googleapis.com/token', ['timeout' => 20, 'body' => [
        'client_id' => $s['client_id'],
        'client_secret' => $s['client_secret'],
        'refresh_token' => $s['refresh'],
        'grant_type' => 'refresh_token',
    ]]);
    $j = is_wp_error($res) ? [] : json_decode(wp_remote_retrieve_body($res), true);
    if (empty($j['access_token'])) {
        return new WP_Error('token', 'Google অনুমতি দিচ্ছে না — আবার সংযোগ দিন');
    }
    return $j['access_token'];
}

function rh_gd_api($method, $url, $token, $body = null, $headers = []) {
    $res = wp_remote_request($url, [
        'method' => $method,
        'timeout' => 60,
        'headers' => ['authorization' => 'Bearer ' . $token] + $headers,
        'body' => $body,
    ]);
    if (is_wp_error($res)) {
        return $res;
    }
    $code = (int) wp_remote_retrieve_response_code($res);
    $j = json_decode(wp_remote_retrieve_body($res), true);
    return $code >= 200 && $code < 300 ? (is_array($j) ? $j : []) : new WP_Error('drive', 'Google Drive: ' . $code);
}

/** The backup folder in Drive (made once). */
function rh_gd_folder($token) {
    $id = (string) get_option('rh_gd_folder', '');
    if ($id !== '') {
        $f = rh_gd_api('GET', 'https://www.googleapis.com/drive/v3/files/' . rawurlencode($id) . '?fields=id,trashed', $token);
        if (!is_wp_error($f) && empty($f['trashed'])) {
            return $id;
        }
    }
    $f = rh_gd_api('POST', 'https://www.googleapis.com/drive/v3/files?fields=id', $token, wp_json_encode(['name' => 'Riyal Hisab Backup', 'mimeType' => 'application/vnd.google-apps.folder']), ['content-type' => 'application/json']);
    if (is_wp_error($f) || empty($f['id'])) {
        return is_wp_error($f) ? $f : new WP_Error('drive', 'ফোল্ডার বানানো যায়নি');
    }
    update_option('rh_gd_folder', $f['id'], false);
    return $f['id'];
}

/** Makes the backup, puts it in Drive and keeps only the newest N. */
function rh_gd_run() {
    $s = rh_gd_state();
    $done = function ($ok, $msg, $file = '') {
        update_option('rh_gd_last', ['at' => rh_now(), 'ok' => $ok, 'msg' => $msg, 'file' => $file], false);
        return $ok;
    };
    if ($s['password'] === '') {
        return $done(false, 'ব্যাকআপের পাসওয়ার্ড দেওয়া নেই');
    }
    $token = rh_gd_token();
    if (is_wp_error($token)) {
        return $done(false, $token->get_error_message());
    }
    $folder = rh_gd_folder($token);
    if (is_wp_error($folder)) {
        return $done(false, $folder->get_error_message());
    }
    $name = 'riyal-hisab-' . current_time('Y-m-d-Hi') . '.rhb';
    $bytes = rh_backup_bytes($s['password']);
    $b = 'rh' . bin2hex(random_bytes(8));
    $body = "--$b\r\ncontent-type: application/json; charset=UTF-8\r\n\r\n" . wp_json_encode(['name' => $name, 'parents' => [$folder]])
        . "\r\n--$b\r\ncontent-type: application/octet-stream\r\n\r\n" . $bytes . "\r\n--$b--";
    $up = rh_gd_api('POST', 'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id', $token, $body, ['content-type' => "multipart/related; boundary=$b"]);
    if (is_wp_error($up)) {
        return $done(false, $up->get_error_message());
    }
    // Old backups beyond the newest N go to the bin.
    // Never one younger than 30 days, whatever the setting.
    $list = rh_gd_api('GET', 'https://www.googleapis.com/drive/v3/files?' . http_build_query(['q' => "'$folder' in parents and trashed = false", 'orderBy' => 'createdTime desc', 'fields' => 'files(id,name,createdTime)', 'pageSize' => 200]), $token);
    if (!is_wp_error($list)) {
        foreach (array_slice($list['files'] ?? [], $s['keep']) as $f) {
            if (!empty($f['createdTime']) && strtotime($f['createdTime']) > time() - 30 * DAY_IN_SECONDS) {
                continue;
            }
            rh_gd_api('PATCH', 'https://www.googleapis.com/drive/v3/files/' . rawurlencode($f['id']), $token, wp_json_encode(['trashed' => true]), ['content-type' => 'application/json']);
        }
    }
    return $done(true, 'ঠিকমতো রাখা হয়েছে · ' . size_format(strlen($bytes)), $name);
}

// Once a day, at about 3 at night (site time).
add_action('init', 'rh_gd_schedule');
function rh_gd_schedule() {
    if (!wp_next_scheduled('rh_gd_daily')) {
        $next = strtotime(current_time('Y-m-d') . ' 03:00:00') - (int) (get_option('gmt_offset', 0) * HOUR_IN_SECONDS);
        if ($next < time()) {
            $next += DAY_IN_SECONDS;
        }
        wp_schedule_event($next, 'daily', 'rh_gd_daily');
    }
}
add_action('rh_gd_daily', function () {
    $s = rh_gd_state();
    if ($s['refresh'] !== '' && $s['password'] !== '') {
        rh_gd_run();
    }
});

function rh_gd_guard($action) {
    if (!current_user_can('manage_options') || !check_admin_referer($action)) {
        wp_die('অনুমতি নেই');
    }
}

add_action('admin_post_rh_gdrive_save', function () {
    rh_gd_guard('rh_gdrive_save');
    $id = trim(sanitize_text_field(wp_unslash($_POST['client_id'] ?? '')));
    $secret = trim((string) wp_unslash($_POST['client_secret'] ?? ''));
    $pass = (string) wp_unslash($_POST['password'] ?? '');
    $keep = (int) ($_POST['keep'] ?? 30);
    if ($id !== '') {
        update_option('rh_gd_client_id', $id, false);
    }
    if ($secret !== '') {
        update_option('rh_gd_client_secret', rh_seal($secret), false);
    }
    if ($pass !== '') {
        if (strlen($pass) < 8) {
            rh_back('settings', 'ব্যাকআপের পাসওয়ার্ড অন্তত ৮ অক্ষর দিন।', true);
        }
        update_option('rh_gd_password', rh_seal($pass), false);
    }
    update_option('rh_gd_keep', max(3, min(365, $keep)), false);
    rh_back('settings', 'Google Drive ব্যাকআপের সেটিং রাখা হয়েছে।');
});

add_action('admin_post_rh_gdrive_connect', function () {
    rh_gd_guard('rh_gdrive_connect');
    $s = rh_gd_state();
    if ($s['client_id'] === '' || $s['client_secret'] === '') {
        rh_back('settings', 'আগে Google-এর Client ID আর Client secret দিন।', true);
    }
    $state = wp_create_nonce('rh_gdrive_cb');
    wp_redirect('https://accounts.google.com/o/oauth2/v2/auth?' . http_build_query([
        'client_id' => $s['client_id'],
        'redirect_uri' => rh_gd_redirect(),
        'response_type' => 'code',
        'scope' => RH_GD_SCOPE,
        'access_type' => 'offline',
        'prompt' => 'consent',
        'state' => $state,
    ]));
    exit;
});

add_action('admin_post_rh_gdrive_cb', function () {
    if (!current_user_can('manage_options') || !wp_verify_nonce((string) ($_GET['state'] ?? ''), 'rh_gdrive_cb')) {
        wp_die('অনুমতি নেই');
    }
    $s = rh_gd_state();
    $res = wp_remote_post('https://oauth2.googleapis.com/token', ['timeout' => 20, 'body' => [
        'code' => sanitize_text_field(wp_unslash($_GET['code'] ?? '')),
        'client_id' => $s['client_id'],
        'client_secret' => $s['client_secret'],
        'redirect_uri' => rh_gd_redirect(),
        'grant_type' => 'authorization_code',
    ]]);
    $j = is_wp_error($res) ? [] : json_decode(wp_remote_retrieve_body($res), true);
    if (empty($j['refresh_token'])) {
        rh_back('settings', 'Google সংযোগ হয়নি — আবার চেষ্টা করুন।', true);
    }
    update_option('rh_gd_refresh', rh_seal($j['refresh_token']), false);
    $email = '';
    if (!empty($j['id_token'])) {
        $parts = explode('.', $j['id_token']);
        $claims = json_decode(base64_decode(strtr($parts[1] ?? '', '-_', '+/')), true);
        $email = sanitize_email($claims['email'] ?? '');
    }
    update_option('rh_gd_email', $email, false);
    rh_back('settings', 'Google Drive সংযোগ হয়েছে' . ($email ? ' (' . $email . ')' : '') . '। প্রতিদিন রাত ৩টায় ব্যাকআপ যাবে।');
});

add_action('admin_post_rh_gdrive_now', function () {
    rh_gd_guard('rh_gdrive_now');
    $ok = rh_gd_run();
    $last = get_option('rh_gd_last', []);
    rh_back('settings', ($ok ? 'ব্যাকআপ Google Drive-এ গেছে: ' : 'ব্যাকআপ হয়নি: ') . ($last['msg'] ?? ''), !$ok);
});

add_action('admin_post_rh_gdrive_off', function () {
    rh_gd_guard('rh_gdrive_off');
    delete_option('rh_gd_refresh');
    delete_option('rh_gd_email');
    rh_back('settings', 'Google Drive সংযোগ বন্ধ করা হলো।');
});

/** The settings card. */
function rh_gd_card() {
    $s = rh_gd_state();
    $last = is_array($s['last']) ? $s['last'] : [];
    $post = esc_url(admin_url('admin-post.php'));
    ?>
    <div class="rh-card">
        <h2>Google Drive অটো ব্যাকআপ</h2>
        <p class="rh-muted">প্রতিদিন রাত ৩টায় পুরো হিসাব (ছবিসহ) পাসওয়ার্ড দিয়ে তালা দেওয়া ফাইল হিসেবে আপনার Google Drive-এর "Riyal Hisab Backup" ফোল্ডারে যাবে। অ্যাপের সেটিংস থেকে এই ফাইল দিয়েই হিসাব ফিরিয়ে আনা যায়।</p>
        <p>অবস্থা: <?php echo $s['refresh'] !== '' ? '<b class="green">সংযোগ আছে</b>' . ($s['email'] ? ' · ' . esc_html($s['email']) : '') : '<b class="red">সংযোগ নেই</b>'; ?>
            · পাসওয়ার্ড: <?php echo $s['password'] !== '' ? '<b class="green">দেওয়া আছে</b>' : '<b class="red">দেওয়া নেই</b>'; ?>
            <?php if ($last) : ?><br>শেষ ব্যাকআপ: <?php echo esc_html(rh_when(get_date_from_gmt($last['at'], 'Y-m-d\TH:i:s')) . ' · ' . $last['msg']); ?><?php endif; ?></p>
        <form method="post" action="<?php echo $post; ?>">
            <?php wp_nonce_field('rh_gdrive_save'); ?>
            <input type="hidden" name="action" value="rh_gdrive_save">
            <label>Google OAuth Client ID <input name="client_id" value="<?php echo esc_attr($s['client_id']); ?>" placeholder="….apps.googleusercontent.com"></label>
            <label>Client secret <?php echo $s['client_secret'] !== '' ? '(দেওয়া আছে — বদলাতে চাইলে লিখুন)' : ''; ?><input name="client_secret" type="password" autocomplete="off"></label>
            <label>ব্যাকআপের পাসওয়ার্ড (অন্তত ৮ অক্ষর; ভুলে গেলে ফাইল খোলা যাবে না) <?php echo $s['password'] !== '' ? '(দেওয়া আছে)' : ''; ?><input name="password" type="password" autocomplete="new-password"></label>
            <label>কতগুলো ব্যাকআপ রাখবে (৩০ দিনের কম পুরনো কোনোটা মোছা হয় না) <input name="keep" type="number" min="3" max="365" value="<?php echo esc_attr($s['keep']); ?>"></label>
            <p class="rh-muted">Google Cloud-এ OAuth client (Web application) বানানোর সময় Authorized redirect URI দিন: <code><?php echo esc_html(rh_gd_redirect()); ?></code></p>
            <button class="rh-btn">রাখুন</button>
        </form>
        <div style="display:flex;gap:8px;flex-wrap:wrap">
            <form method="post" action="<?php echo $post; ?>"><?php wp_nonce_field('rh_gdrive_connect'); ?><input type="hidden" name="action" value="rh_gdrive_connect"><button class="rh-btn"><?php echo $s['refresh'] !== '' ? 'আবার সংযোগ দিন' : 'Google Drive-এ সংযোগ দিন'; ?></button></form>
            <?php if ($s['refresh'] !== '') : ?>
                <form method="post" action="<?php echo $post; ?>"><?php wp_nonce_field('rh_gdrive_now'); ?><input type="hidden" name="action" value="rh_gdrive_now"><button class="rh-btn">এখনই একটা ব্যাকআপ নিন</button></form>
                <form method="post" action="<?php echo $post; ?>"><?php wp_nonce_field('rh_gdrive_off'); ?><input type="hidden" name="action" value="rh_gdrive_off"><button class="rh-btn" style="background:#C5221F">সংযোগ বন্ধ</button></form>
            <?php endif; ?>
        </div>
    </div>
    <?php
}
