<?php
/**
 * Today's gold and silver price in Bangladesh (the rate BAJUS sets), for the
 * app's যাকাত. Looked up on the web by the server's AI with web search, at
 * most once every few hours for everyone, checked for sense and kept; the
 * app never makes up a price and never holds a key.
 */

if (!defined('ABSPATH')) {
    exit;
}

const MA_METAL_FRESH = 6 * HOUR_IN_SECONDS;
const MA_METAL_RETRY = 20 * MINUTE_IN_SECONDS;
const MA_METAL_GRAMS_PER_VORI = 11.664;

add_action('rest_api_init', function () {
    register_rest_route('my-assistant/v1', '/metal-price', [
        'methods' => 'GET',
        'callback' => 'ma_metal_price_route',
        'permission_callback' => '__return_true', // a public fact, the same for everyone
    ]);
});

function ma_metal_price_route(WP_REST_Request $req) {
    $kept = get_option('ma_metal_price', null);
    // Never look it up while the app waits: a web search takes longer than
    // the app's 20 seconds, and the dropped request took the lookup with it,
    // so the price stayed old (owner, 23 Nov). Answer with what is kept, and
    // look up after the answer has gone.
    if (!ma_metal_fresh($kept)) {
        ma_metal_refresh_after_answer();
    }
    if (!is_array($kept)) {
        return new WP_Error('unavailable', 'price not available now', ['status' => 503]);
    }
    return rest_ensure_response(ma_metal_answer($kept));
}

function ma_metal_fresh($kept) {
    return is_array($kept) && (time() - (int) ($kept['fetched'] ?? 0)) < MA_METAL_FRESH;
}

/** Look up a new price, unless one is fresh or a lookup ran in the last minutes. True when a new one was kept. */
function ma_metal_refresh() {
    if (ma_metal_fresh(get_option('ma_metal_price', null)) || get_transient('ma_metal_trying')) {
        return false;
    }
    set_transient('ma_metal_trying', 1, MA_METAL_RETRY);
    if (function_exists('set_time_limit')) {
        @set_time_limit(600);
    }
    $got = ma_metal_lookup();
    if (!is_array($got)) {
        return false;
    }
    $kept = get_option('ma_metal_price', null);
    // An older announcement than the one kept is not taken over it.
    if (is_array($kept) && strcmp((string) $got['date'], (string) ($kept['date'] ?? '')) < 0) {
        $kept['fetched'] = time();
        update_option('ma_metal_price', $kept, false);
    } else {
        $got['fetched'] = time();
        update_option('ma_metal_price', $got, false);
    }
    delete_transient('ma_metal_trying');
    return true;
}

/** Once per request: send the answer to the app first, then look up. */
function ma_metal_refresh_after_answer() {
    static $set = false;
    if ($set || get_transient('ma_metal_trying')) {
        return;
    }
    $set = true;
    add_action('shutdown', function () {
        ignore_user_abort(true);
        if (function_exists('fastcgi_finish_request')) {
            fastcgi_finish_request();
        } elseif (function_exists('litespeed_finish_request')) {
            litespeed_finish_request();
        }
        ma_metal_refresh();
    });
}

// Also kept fresh without anyone asking, so the first one to open যাকাত gets
// today's price (BAJUS changes it often, sometimes twice a week).
add_filter('cron_schedules', function ($s) {
    $s['ma_three_hours'] = ['interval' => 3 * HOUR_IN_SECONDS, 'display' => 'Every 3 hours (My Assistant)'];
    return $s;
});
add_action('init', function () {
    if (!wp_next_scheduled('ma_metal_tick')) {
        wp_schedule_event(time() + 120, 'ma_three_hours', 'ma_metal_tick');
    }
});
add_action('ma_metal_tick', 'ma_metal_refresh');

/** What the app gets: taka per vori (ভরি), the date the rate took effect, and where it came from. */
function ma_metal_answer(array $k) {
    return [
        'date' => $k['date'],
        'unit' => 'vori',
        'grams_per_vori' => MA_METAL_GRAMS_PER_VORI,
        'gold' => $k['gold'],
        'silver' => $k['silver'],
        'source' => $k['source'],
        'source_url' => $k['source_url'],
        'checked_at' => gmdate('c', (int) $k['fetched']),
    ];
}

/** The latest BAJUS rate through the AI's web search; null when it could not be found or did not make sense. */
function ma_metal_lookup() {
    $key = function_exists('ma_ai_key') ? ma_ai_key() : '';
    if ($key === '' || get_option('ma_ai_on', '0') !== '1') {
        return null;
    }
    $today = wp_date('Y-m-d');
    $ask = "Today is $today. Find the gold and silver prices currently in force in Bangladesh, as last set by the Bangladesh Jewellers Association (BAJUS, bajus.org). "
        . 'BAJUS changes the price often, sometimes several times a week, and news sites (bdnews24, Prothom Alo, The Daily Star, Dhaka Tribune, Jago News and others) report each change: search for the newest announcement and use the rate it says takes effect, not an older one. '
        . 'Use only what the search results say; never estimate. Give taka per vori (ভরি, 11.664 g). '
        . 'Answer with only this JSON and nothing else: '
        . '{"effective_date":"YYYY-MM-DD","gold":{"22k":0,"21k":0,"18k":0,"traditional":0},"silver":{"22k":0,"21k":0,"18k":0,"traditional":0},"source_url":"https://..."}';
    $messages = [['role' => 'user', 'content' => $ask]];
    $text = '';
    foreach (['claude-sonnet-5-5', 'claude-haiku-5-5'] as $model) {
        for ($turn = 0; $turn < 5; $turn++) {
            $res = wp_remote_post('https://api.anthropic.com/v1/messages', [
                'timeout' => 90,
                'headers' => ['content-type' => 'application/json', 'x-api-key' => $key, 'anthropic-version' => '2023-06-01'],
                'body' => wp_json_encode([
                    'model' => $model,
                    'max_tokens' => 4000,
                    'messages' => $messages,
                    'tools' => [['type' => 'web_search_20250305', 'name' => 'web_search', 'max_uses' => 5]],
                ]),
            ]);
            if (is_wp_error($res)) {
                break;
            }
            $code = (int) wp_remote_retrieve_response_code($res);
            $j = json_decode(wp_remote_retrieve_body($res), true);
            if ($code !== 200 || !is_array($j)) {
                break;
            }
            // A long search can pause: carry on from where it stopped.
            if (($j['stop_reason'] ?? '') === 'pause_turn') {
                $messages[] = ['role' => 'assistant', 'content' => $j['content']];
                continue;
            }
            foreach ((array) ($j['content'] ?? []) as $b) {
                if (is_array($b) && ($b['type'] ?? '') === 'text') {
                    $text .= $b['text'];
                }
            }
            break;
        }
        $got = ma_metal_read($text, $today);
        if ($got) {
            return $got;
        }
        $messages = [['role' => 'user', 'content' => $ask]];
        $text = '';
    }
    return null;
}

/** The JSON in [$text], checked: sensible amounts, gold dearer by purity, a recent date. */
function ma_metal_read($text, $today) {
    $a = strpos($text, '{');
    $b = strrpos($text, '}');
    if ($a === false || $b === false || $b <= $a) {
        return null;
    }
    $j = json_decode(substr($text, $a, $b - $a + 1), true);
    if (!is_array($j)) {
        return null;
    }
    $num = function ($v) {
        // Bangla digits and grouping (২,০৫,০০০) as well.
        $v = strtr((string) $v, ['০' => '0', '১' => '1', '২' => '2', '৩' => '3', '৪' => '4', '৫' => '5', '৬' => '6', '৭' => '7', '৮' => '8', '৯' => '9', ',' => '', ' ' => '', '৳' => '']);
        return (int) round((float) $v);
    };
    $gold = [];
    $silver = [];
    foreach (['22k', '21k', '18k', 'traditional'] as $k) {
        $gold[$k] = $num($j['gold'][$k] ?? 0);
        $silver[$k] = $num($j['silver'][$k] ?? 0);
    }
    // Taka per vori: gold well above silver, each in a believable range.
    if ($gold['22k'] < 50000 || $gold['22k'] > 2000000) {
        return null;
    }
    // Dearer by purity, and close to it: 18 carat is about three quarters of 22.
    if (!($gold['22k'] >= $gold['21k'] && $gold['21k'] >= $gold['18k'] && $gold['18k'] >= $gold['traditional'] && $gold['traditional'] >= $gold['22k'] * 0.4)) {
        return null;
    }
    if ($silver['22k'] < 300 || $silver['22k'] > 100000 || $silver['22k'] * 10 > $gold['22k']) {
        return null;
    }
    $date = (string) ($j['effective_date'] ?? '');
    $t = strtotime($date);
    if (!preg_match('/^\d{4}-\d{2}-\d{2}$/', $date) || !$t || $t > strtotime($today) + DAY_IN_SECONDS || $t < strtotime($today) - 120 * DAY_IN_SECONDS) {
        return null;
    }
    $url = esc_url_raw((string) ($j['source_url'] ?? ''));
    return [
        'date' => $date,
        'gold' => $gold,
        'silver' => array_filter($silver),
        'source' => 'বাজুস (বাংলাদেশ জুয়েলার্স অ্যাসোসিয়েশন)',
        'source_url' => $url !== '' ? $url : 'https://www.bajus.org/gold-price',
    ];
}
