<?php
/**
 * Google Play subscriptions (owner, 29 Oct: the Play Store app sells Premium
 * through Google Play Billing). The app buys; this server asks Google whether
 * the purchase is real (Google Play Developer API, with a service account the
 * site owner pastes on the settings page — never in the app), acknowledges it,
 * and sets the member's Premium to the subscription's own end. Renewals and
 * cancellations are read again whenever the member's Premium is near its end.
 */

if (!defined('ABSPATH')) {
    exit;
}

/** The Play app's package and the products sold. */
const MA_PLAY_PACKAGE = 'app.getmyassistant';
const MA_PLAY_PRODUCTS = ['pro_monthly', 'pro_yearly'];

function ma_play_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_play_purchases';
}

/** One row per purchase token: whose it is and what Google last said. */
function ma_play_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $c = $wpdb->get_charset_collate();
    dbDelta('CREATE TABLE ' . ma_play_table() . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        user_id bigint(20) unsigned NOT NULL,
        product varchar(40) NOT NULL DEFAULT '',
        token_hash char(64) NOT NULL,
        token text NOT NULL,
        state varchar(40) NOT NULL DEFAULT '',
        expires_at datetime NULL DEFAULT NULL,
        order_id varchar(80) NOT NULL DEFAULT '',
        checked_at datetime NOT NULL,
        PRIMARY KEY  (id),
        UNIQUE KEY token_hash (token_hash),
        KEY user_id (user_id)
    ) $c;");
}
/** The service account with access to the Play Console's API (JSON), or null. */
function ma_play_account() {
    if (defined('MA_PLAY_SERVICE_ACCOUNT') && MA_PLAY_SERVICE_ACCOUNT) {
        $raw = is_file(MA_PLAY_SERVICE_ACCOUNT) ? (string) file_get_contents(MA_PLAY_SERVICE_ACCOUNT) : (string) MA_PLAY_SERVICE_ACCOUNT;
    } else {
        $raw = (string) get_option('ma_play_account', '');
    }
    $j = json_decode($raw, true);
    return is_array($j) && !empty($j['client_email']) && !empty($j['private_key']) ? $j : null;
}

function ma_play_source() {
    if (defined('MA_PLAY_SERVICE_ACCOUNT') && MA_PLAY_SERVICE_ACCOUNT) {
        return 'config';
    }
    return get_option('ma_play_account', '') !== '' ? 'saved' : '';
}

/** An OAuth token for the Android Publisher API (kept 50 minutes). Tests replace it. */
function ma_play_access_token() {
    $pre = apply_filters('ma_play_access_token', null);
    if ($pre !== null) {
        return (string) $pre;
    }
    $cached = get_transient('ma_play_token');
    if ($cached) {
        return $cached;
    }
    $acc = ma_play_account();
    if (!$acc || !function_exists('openssl_sign')) {
        return '';
    }
    $now = time();
    $head = ma_push_b64(wp_json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $claim = ma_push_b64(wp_json_encode([
        'iss' => $acc['client_email'],
        'scope' => 'https://www.googleapis.com/auth/androidpublisher',
        'aud' => 'https://oauth2.googleapis.com/token',
        'iat' => $now,
        'exp' => $now + 3600,
    ]));
    $sig = '';
    if (!openssl_sign("$head.$claim", $sig, $acc['private_key'], 'sha256WithRSAEncryption')) {
        return '';
    }
    $res = wp_remote_post('https://oauth2.googleapis.com/token', [
        'timeout' => 15,
        'body' => ['grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion' => "$head.$claim." . ma_push_b64($sig)],
    ]);
    if (is_wp_error($res) || wp_remote_retrieve_response_code($res) !== 200) {
        return '';
    }
    $tok = (string) (json_decode(wp_remote_retrieve_body($res), true)['access_token'] ?? '');
    if ($tok !== '') {
        set_transient('ma_play_token', $tok, 50 * MINUTE_IN_SECONDS);
    }
    return $tok;
}

/** What Google says of a subscription purchase (subscriptionsv2), or a WP_Error. */
function ma_play_lookup($token) {
    $auth = ma_play_access_token();
    if ($auth === '') {
        return new WP_Error('play_off', 'Play is not set up on the server', ['status' => 503]);
    }
    $url = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' . MA_PLAY_PACKAGE . '/purchases/subscriptionsv2/tokens/' . rawurlencode($token);
    $res = wp_remote_get($url, ['timeout' => 15, 'headers' => ['Authorization' => "Bearer $auth"]]);
    if (is_wp_error($res)) {
        return new WP_Error('play_down', 'Google did not answer', ['status' => 503]);
    }
    $code = wp_remote_retrieve_response_code($res);
    $j = json_decode(wp_remote_retrieve_body($res), true);
    if ($code === 404 || $code === 410 || $code === 400) {
        return new WP_Error('play_bad', 'not a purchase Google knows', ['status' => 400]);
    }
    if ($code !== 200 || !is_array($j)) {
        return new WP_Error('play_down', 'Google did not answer', ['status' => 503]);
    }
    return $j;
}

/** Acknowledges a new purchase (else Google refunds it in three days). */
function ma_play_acknowledge($product, $token) {
    $auth = ma_play_access_token();
    if ($auth === '') {
        return false;
    }
    $url = 'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/' . MA_PLAY_PACKAGE . '/purchases/subscriptions/' . rawurlencode($product) . '/tokens/' . rawurlencode($token) . ':acknowledge';
    $res = wp_remote_post($url, ['timeout' => 15, 'headers' => ['Authorization' => "Bearer $auth", 'Content-Type' => 'application/json'], 'body' => '{}']);
    return !is_wp_error($res) && wp_remote_retrieve_response_code($res) === 200;
}

/**
 * Reads [token] from Google and keeps it for [row]'s member: their Premium
 * runs to the subscription's end while it is active. Returns the member's
 * answer (as /me gives it) or a WP_Error.
 */
function ma_play_apply($row, $product, $token) {
    global $wpdb;
    if (!in_array($product, MA_PLAY_PRODUCTS, true) || $token === '' || strlen($token) > 600) {
        return new WP_Error('bad', 'a product and a token', ['status' => 400]);
    }
    $hash = hash('sha256', $token);
    // A token already kept for another member is never moved to this one.
    $owner = $wpdb->get_var($wpdb->prepare('SELECT user_id FROM ' . ma_play_table() . ' WHERE token_hash = %s', $hash));
    if ($owner !== null && (int) $owner !== (int) $row['id']) {
        return new WP_Error('taken', 'this purchase belongs to another account', ['status' => 409]);
    }
    $g = ma_play_lookup($token);
    if (is_wp_error($g)) {
        return $g;
    }
    $item = null;
    foreach ((array) ($g['lineItems'] ?? []) as $li) {
        if (($li['productId'] ?? '') === $product) {
            $item = $li;
        }
    }
    if (!$item) {
        return new WP_Error('play_bad', 'not this product', ['status' => 400]);
    }
    $state = (string) ($g['subscriptionState'] ?? '');
    $ends = strtotime((string) ($item['expiryTime'] ?? '')) ?: 0;
    $active = in_array($state, ['SUBSCRIPTION_STATE_ACTIVE', 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD', 'SUBSCRIPTION_STATE_CANCELED'], true) && $ends > time();
    $now = current_time('mysql', true);
    $data = ['user_id' => (int) $row['id'], 'product' => $product, 'token_hash' => $hash, 'token' => $token, 'state' => substr($state, 0, 40),
        'expires_at' => $ends ? gmdate('Y-m-d H:i:s', $ends) : null, 'order_id' => substr((string) ($g['latestOrderId'] ?? ''), 0, 80), 'checked_at' => $now];
    if ($owner === null) {
        $wpdb->insert(ma_play_table(), $data);
    } else {
        $wpdb->update(ma_play_table(), $data, ['token_hash' => $hash]);
    }
    if (($g['acknowledgementState'] ?? '') === 'ACKNOWLEDGEMENT_STATE_PENDING' && $active) {
        ma_play_acknowledge($product, $token);
    }
    // Premium to the subscription's end — never shortening Premium the member
    // got another way (bKash, a gift) that runs longer.
    if ($active) {
        $fromPlay = str_starts_with((string) $row['pro_kind'], 'play:');
        $kept = ma_acc_ts($row['pro_until'] ?? null);
        if ($fromPlay || $ends > $kept) {
            $wpdb->update(ma_acc_table(), ['pro_until' => gmdate('Y-m-d H:i:s', $ends), 'pro_kind' => 'play:' . $product], ['id' => $row['id']]);
        }
    } elseif (str_starts_with((string) $row['pro_kind'], 'play:') && ma_acc_ts($row['pro_until'] ?? null) > time()) {
        // Ended at Google (refunded, revoked, expired): Premium ends now.
        $wpdb->update(ma_acc_table(), ['pro_until' => $now], ['id' => $row['id']]);
    }
    $fresh = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_acc_table() . ' WHERE id = %d', $row['id']), ARRAY_A);
    return ma_acc_answer($fresh ?: $row) + ['play_active' => $active];
}

/** A Play member near the end of Premium: renewals and cancellations read again (at most every 6 hours). */
function ma_play_refresh($row) {
    global $wpdb;
    if (!str_starts_with((string) ($row['pro_kind'] ?? ''), 'play:') || ma_play_source() === '' && !has_filter('ma_play_access_token')) {
        return $row;
    }
    if (ma_acc_ts($row['pro_until'] ?? null) > time() + DAY_IN_SECONDS) {
        return $row;
    }
    $p = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_play_table() . ' WHERE user_id = %d ORDER BY id DESC LIMIT 1', $row['id']), ARRAY_A);
    if (!$p || ma_acc_ts($p['checked_at']) > time() - 6 * HOUR_IN_SECONDS) {
        return $row;
    }
    $r = ma_play_apply($row, $p['product'], $p['token']);
    if (is_wp_error($r)) {
        $wpdb->update(ma_play_table(), ['checked_at' => current_time('mysql', true)], ['id' => $p['id']]);
        return $row;
    }
    return $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_acc_table() . ' WHERE id = %d', $row['id']), ARRAY_A) ?: $row;
}

add_action('rest_api_init', function () {
    register_rest_route('my-assistant/v1', '/play/verify', [
        'methods' => 'POST',
        'permission_callback' => '__return_true', // the member's session is checked inside
        'callback' => function (WP_REST_Request $req) {
            $row = ma_ai_member($req);
            if (!$row) {
                return new WP_Error('session', 'sign in again', ['status' => 401]);
            }
            $k = 'ma_play_rl_' . (int) $row['id'];
            if ((int) get_transient($k) >= 30) {
                return new WP_Error('busy', 'too many', ['status' => 429]);
            }
            set_transient($k, (int) get_transient($k) + 1, HOUR_IN_SECONDS);
            return ma_play_apply($row, sanitize_key((string) $req->get_param('product')), trim((string) $req->get_param('token')));
        },
    ]);
});

add_action('admin_post_ma_play_settings', function () {
    ma_acc_guard('ma_play_settings', 'manage_options');
    $json = trim((string) wp_unslash($_POST['play_account'] ?? ''));
    if (!empty($_POST['play_remove'])) {
        delete_option('ma_play_account');
        delete_transient('ma_play_token');
    } elseif ($json !== '') {
        $j = json_decode($json, true);
        if (!is_array($j) || empty($j['client_email']) || empty($j['private_key'])) {
            ma_acc_back('Google Play-র service account JSON ঠিক নেই — পুরো ফাইলের লেখা পেস্ট করুন।', 'error', ['tab' => 'settings']);
        }
        update_option('ma_play_account', wp_json_encode($j), false);
        delete_transient('ma_play_token');
    }
    ma_acc_back('Google Play-র সেটিংস রাখা হয়েছে।', 'ok', ['tab' => 'settings']);
});

/** The settings page's Google Play card. */
function ma_play_settings_card() {
    $src = ma_play_source();
    ?>
    <section class="ma-card pad">
        <div class="ma-ai-head">
            <div>
                <h2>Google Play-র সাবস্ক্রিপশন</h2>
                <p class="muted">Play Store-এর অ্যাপে প্রিমিয়াম কিনলে এই সার্ভার Google-এর কাছে যাচাই করে প্রিমিয়াম চালু করে; নবায়ন বা বাতিলও এখান থেকেই ধরা পড়ে। এর জন্য Google Cloud-এর একটা service account লাগে, যাকে Play Console-এ অনুমতি দেওয়া আছে।</p>
            </div>
            <span class="ma-pill <?php echo $src !== '' ? 'pro' : 'expired'; ?>"><?php echo $src !== '' ? 'যাচাই চালু' : 'যুক্ত হয়নি'; ?></span>
        </div>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <input type="hidden" name="action" value="ma_play_settings">
            <?php wp_nonce_field('ma_play_settings'); ?>
            <?php if ($src === 'config') : ?>
                <p class="muted ma-tip">service account <code>wp-config.php</code> থেকে নেওয়া হচ্ছে।</p>
            <?php else : ?>
                <label>Google Play service account JSON <?php echo $src === 'saved' ? '(রাখা আছে — বদলাতে নতুনটা পেস্ট করুন)' : ''; ?>
                    <textarea name="play_account" rows="3" spellcheck="false" placeholder='{"type": "service_account", "client_email": "…", …}'></textarea>
                </label>
                <?php if ($src === 'saved') : ?><label class="ma-check"><input type="checkbox" name="play_remove" value="1"> রাখা service account মুছে দিন</label><?php endif; ?>
            <?php endif; ?>
            <p class="muted ma-tip">Google Cloud Console › IAM › Service accounts › নতুন একটা বানিয়ে “Keys › Add key › JSON”; তারপর Play Console › Users and permissions-এ সেই ইমেইলকে “View financial data” আর “Manage orders and subscriptions” অনুমতি দিন। আরও নিরাপদ: <code>define('MA_PLAY_SERVICE_ACCOUNT', '/home/…/play.json');</code> wp-config.php-তে।</p>
            <button class="ma-btn" type="submit">রাখুন</button>
        </form>
    </section>
    <?php
}
