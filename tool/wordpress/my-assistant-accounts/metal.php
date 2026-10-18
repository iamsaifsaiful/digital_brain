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
    $fresh = is_array($kept) && (time() - (int) ($kept['fetched'] ?? 0)) < MA_METAL_FRESH;
    if (!$fresh && !get_transient('ma_metal_trying')) {
        set_transient('ma_metal_trying', 1, MA_METAL_RETRY);
        $got = ma_metal_lookup();
        if (is_array($got)) {
            $got['fetched'] = time();
            update_option('ma_metal_price', $got, false);
            $kept = $got;
            delete_transient('ma_metal_trying');
        }
    }
    if (!is_array($kept)) {
        return new WP_Error('unavailable', 'price not available now', ['status' => 503]);
    }
    return rest_ensure_response(ma_metal_answer($kept));
}

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
        . 'Use only what the search results say; never estimate. Give taka per vori (ভরি, 11.664 g). '
        . 'Answer with only this JSON and nothing else: '
        . '{"effective_date":"YYYY-MM-DD","gold":{"22k":0,"21k":0,"18k":0,"traditional":0},"silver":{"22k":0,"21k":0,"18k":0,"traditional":0},"source_url":"https://..."}';
    $messages = [['role' => 'user', 'content' => $ask]];
    $text = '';
    foreach (['claude-sonnet-5-5', 'claude-haiku-5-5'] as $model) {
        for ($turn = 0; $turn < 3; $turn++) {
            $res = wp_remote_post('https://api.anthropic.com/v1/messages', [
                'timeout' => 90,
                'headers' => ['content-type' => 'application/json', 'x-api-key' => $key, 'anthropic-version' => '2023-06-01'],
                'body' => wp_json_encode([
                    'model' => $model,
                    'max_tokens' => 1500,
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
        return (int) round((float) str_replace([',', ' '], '', (string) $v));
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
