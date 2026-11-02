<?php
/**
 * Push notifications through Firebase Cloud Messaging (free). The phone's
 * Firebase settings (from google-services.json) are given to the app at
 * sign-in, so nothing about Firebase is built into the APK; this server
 * sends with the service account. Both are set on the settings page.
 */

if (!defined('ABSPATH')) {
    exit;
}

/** The service account: RH_FCM_SERVICE_ACCOUNT (path or JSON) in wp-config.php, or the saved one. */
function rh_push_account() {
    $raw = defined('RH_FCM_SERVICE_ACCOUNT') && RH_FCM_SERVICE_ACCOUNT
        ? (is_readable((string) RH_FCM_SERVICE_ACCOUNT) ? (string) file_get_contents((string) RH_FCM_SERVICE_ACCOUNT) : (string) RH_FCM_SERVICE_ACCOUNT)
        : (string) get_option('rh_fcm_account', '');
    $j = json_decode($raw, true);
    return is_array($j) && !empty($j['client_email']) && !empty($j['private_key']) && !empty($j['project_id']) ? $j : null;
}

/** What the app needs to start Firebase: app id, api key, sender id, project id — or null. */
function rh_firebase_options() {
    $j = json_decode((string) get_option('rh_fcm_app', ''), true);
    return is_array($j) && !empty($j['appId']) ? $j : null;
}

/** Reads the app part out of google-services.json for our package. */
function rh_firebase_from_services($json, $package = 'com.iamsaifsaiful.riyal_hisab') {
    $cfg = json_decode((string) $json, true);
    if (!is_array($cfg)) {
        return null;
    }
    $info = $cfg['project_info'] ?? [];
    foreach ($cfg['client'] ?? [] as $c) {
        if (($c['client_info']['android_client_info']['package_name'] ?? '') === $package) {
            return [
                'appId' => (string) ($c['client_info']['mobilesdk_app_id'] ?? ''),
                'apiKey' => (string) ($c['api_key'][0]['current_key'] ?? ''),
                'senderId' => (string) ($info['project_number'] ?? ''),
                'projectId' => (string) ($info['project_id'] ?? ''),
            ];
        }
    }
    return null;
}

function rh_b64u($s) {
    return rtrim(strtr(base64_encode($s), '+/', '-_'), '=');
}

function rh_push_token() {
    $cached = get_transient('rh_fcm_token');
    if ($cached) {
        return $cached;
    }
    $acc = rh_push_account();
    if (!$acc || !function_exists('openssl_sign')) {
        return '';
    }
    $now = time();
    $head = rh_b64u(wp_json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $claim = rh_b64u(wp_json_encode([
        'iss' => $acc['client_email'],
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
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
        'body' => ['grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion' => "$head.$claim." . rh_b64u($sig)],
    ]);
    if (is_wp_error($res) || wp_remote_retrieve_response_code($res) !== 200) {
        return '';
    }
    $tok = (string) (json_decode(wp_remote_retrieve_body($res), true)['access_token'] ?? '');
    if ($tok !== '') {
        set_transient('rh_fcm_token', $tok, 50 * MINUTE_IN_SECONDS);
    }
    return $tok;
}

/** Sends to each device; tokens Firebase no longer knows are forgotten. Returns how many went. */
function rh_push_send(array $tokens, $title, $body, array $data = []) {
    $acc = rh_push_account();
    $auth = $acc ? rh_push_token() : '';
    if ($auth === '' || !$tokens) {
        return 0;
    }
    global $wpdb;
    $sent = 0;
    foreach (array_unique($tokens) as $t) {
        $res = wp_remote_post('https://fcm.googleapis.com/v1/projects/' . rawurlencode($acc['project_id']) . '/messages:send', [
            'timeout' => 10,
            'headers' => ['authorization' => 'Bearer ' . $auth, 'content-type' => 'application/json'],
            'body' => wp_json_encode(['message' => [
                'token' => $t,
                'notification' => ['title' => $title, 'body' => $body],
                'data' => (object) array_map('strval', $data),
                'android' => ['priority' => 'high', 'notification' => ['channel_id' => 'rh_alert', 'sound' => 'remit_alert', 'default_vibrate_timings' => false, 'vibrate_timings' => ['0s', '0.22s', '0.12s', '0.22s', '0.12s', '0.42s'], 'notification_priority' => 'PRIORITY_HIGH', 'visibility' => 'PRIVATE']],
            ]]),
        ]);
        $code = is_wp_error($res) ? 0 : (int) wp_remote_retrieve_response_code($res);
        if ($code === 200) {
            $sent++;
        } elseif ($code === 404 || ($code === 400 && strpos(wp_remote_retrieve_body($res), 'registration') !== false)) {
            $wpdb->update(rh_t('sessions'), ['fcm_token' => ''], ['fcm_token' => $t]);
        }
    }
    return $sent;
}

function rh_push_user($user_id, $title, $body, array $data = []) {
    global $wpdb;
    $tokens = $wpdb->get_col($wpdb->prepare('SELECT fcm_token FROM ' . rh_t('sessions') . " WHERE user_id = %d AND fcm_token <> ''", $user_id));
    return rh_push_send($tokens, $title, $body, $data);
}
