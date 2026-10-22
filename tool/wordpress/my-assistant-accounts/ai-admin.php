<?php
/**
 * AI and the on-phone model: every change an admin can make, written once
 * and used by both places — the site's pages (admin-post forms) and the
 * admin app (REST). Whatever one can do, the other can (owner's rule,
 * 22 Oct 2026). Keys, prices and the retraining key: the site owner only.
 */

if (!defined('ABSPATH')) {
    exit;
}

/** Turns a model on for a share of members, changes its share, or takes it back. */
function ma_nlu_model_do($ver, $action, $pct = null) {
    global $wpdb;
    $t = ma_nlu_table('models');
    $ver = sanitize_text_field((string) $ver);
    if (!preg_match('/^[A-Za-z0-9._\-]{1,32}$/', $ver)) {
        return new WP_Error('bad', 'version', ['status' => 400]);
    }
    $cur = $wpdb->get_row($wpdb->prepare("SELECT * FROM $t WHERE version = %s", $ver), ARRAY_A);
    if (!$cur) {
        return new WP_Error('none', 'not found', ['status' => 404]);
    }
    $p = max(0, min(100, (int) ($pct ?? 10)));
    if ($action === 'live') {
        $wpdb->update($t, ['status' => 'live', 'rollout_pct' => $p], ['version' => $ver]);
    } elseif ($action === 'pct') {
        $wpdb->update($t, ['rollout_pct' => $p], ['version' => $ver]);
    } elseif ($action === 'retire' || $action === 'rollback') {
        // Members fall back to the previous live model (or to none: the app's own rules).
        $wpdb->update($t, ['status' => 'retired', 'rollout_pct' => 0], ['version' => $ver]);
    } else {
        return new WP_Error('bad', 'action', ['status' => 400]);
    }
    return ma_nlu_model_json($wpdb->get_row($wpdb->prepare("SELECT * FROM $t WHERE version = %s", $ver), ARRAY_A));
}

function ma_nlu_models_list() {
    global $wpdb;
    return array_map('ma_nlu_model_json', $wpdb->get_results('SELECT * FROM ' . ma_nlu_table('models') . ' ORDER BY created DESC', ARRAY_A) ?: []);
}

/** Samples worth a look: an error signal, or the phone, the cloud and the final reading disagree. */
function ma_nlu_review_list($limit = 50) {
    global $wpdb;
    $s = ma_nlu_table('samples');
    $l = ma_nlu_table('labels');
    $rows = $wpdb->get_results("SELECT s.* FROM $s s LEFT JOIN $l l ON l.sample_id = s.id AND l.source = 'admin' WHERE l.sample_id IS NULL ORDER BY (s.signal_kind <> '') DESC, s.created DESC LIMIT 500", ARRAY_A) ?: [];
    $intents = function ($j) {
        $d = json_decode((string) $j, true);
        $out = [];
        foreach ((array) ($d['pieces'] ?? $d ?? []) as $p) {
            if (is_array($p) && isset($p['intent'])) {
                $out[] = $p['intent'];
            }
        }
        return $out;
    };
    $out = [];
    foreach ($rows as $r) {
        $a = $intents($r['local_json']);
        $b = $intents($r['cloud_json']);
        $c = $intents($r['final_json']);
        $differ = $r['signal_kind'] !== '' || ($b && $a && $a !== $b) || ($c && $b && $c !== $b) || ($c && $a && $c !== $a);
        if (!$differ) {
            continue;
        }
        $out[] = ['id' => (int) $r['id'], 'created' => $r['created'], 'state' => $r['state'], 'text' => $r['text_delex'], 'phone' => $a, 'phone_conf' => (float) $r['local_conf'], 'cloud' => $b, 'cloud_provider' => $r['cloud_provider'], 'final' => $c, 'signal' => $r['signal_kind']];
        if (count($out) >= max(1, (int) $limit)) {
            break;
        }
    }
    return $out;
}

/** The right reading of one sample (an admin's label wins in retraining). */
function ma_nlu_label_sample($id, $intents, $pick, $admin_id) {
    global $wpdb;
    $id = (int) $id;
    if (!$wpdb->get_var($wpdb->prepare('SELECT id FROM ' . ma_nlu_table('samples') . ' WHERE id = %d', $id))) {
        return new WP_Error('none', 'not found', ['status' => 404]);
    }
    $intents = array_values(array_unique(array_filter((array) $intents, function ($i) {
        return is_string($i) && isset(MA_NLU_INTENTS[$i]);
    })));
    if (!$intents) {
        return new WP_Error('bad', 'choose an intent', ['status' => 400]);
    }
    $wpdb->query($wpdb->prepare('DELETE FROM ' . ma_nlu_table('labels') . " WHERE sample_id = %d AND source = 'admin'", $id));
    $wpdb->insert(ma_nlu_table('labels'), ['sample_id' => $id, 'label_json' => wp_json_encode(['intents' => $intents, 'pick' => sanitize_key((string) $pick)]), 'source' => 'admin', 'admin_id' => (int) $admin_id, 'created' => current_time('mysql', true)]);
    return true;
}

/** The kill switch, the old /ai limits and the budgets. */
function ma_ai_save_general($in) {
    if (isset($in['ai_on'])) {
        update_option('ma_ai_on', $in['ai_on'] ? '1' : '0');
    }
    if (isset($in['ai_per_user'])) {
        update_option('ma_ai_per_user', max(1, min(500, (int) $in['ai_per_user'])));
    }
    if (isset($in['ai_per_day'])) {
        update_option('ma_ai_per_day', max(1, min(100000, (int) $in['ai_per_day'])));
    }
    if (!empty($in['budgets_auto'])) {
        delete_option('ma_ai_budgets');
    } elseif (isset($in['budgets']) && is_array($in['budgets'])) {
        $b = ma_ai_budgets();
        foreach (['free', 'pro'] as $plan) {
            foreach (['day', 'month'] as $k) {
                if (isset($in['budgets'][$plan][$k])) {
                    $b[$plan][$k] = max(0, (float) $in['budgets'][$plan][$k]);
                }
            }
        }
        unset($b['auto']);
        update_option('ma_ai_budgets', wp_json_encode($b), false);
    }
}

/** API keys (site owner only). Returns an error message, or ''. */
function ma_ai_save_keys($in) {
    if (!empty($in['anthropic_remove'])) {
        delete_option('ma_ai_key');
    } elseif (($k = trim((string) ($in['anthropic_key'] ?? ''))) !== '') {
        if (!preg_match('/^sk-ant-[A-Za-z0-9_\-]{20,}$/', $k)) {
            return 'API key ঠিক মনে হচ্ছে না (sk-ant- দিয়ে শুরু হয়)।';
        }
        update_option('ma_ai_key', $k, false);
    }
    if (!empty($in['gemini_remove'])) {
        delete_option('ma_gemini_key');
    } elseif (($g = trim((string) ($in['gemini_key'] ?? ''))) !== '') {
        // Google's keys: the old "AIza…" ones and the newer "AQ.…" ones (with a dot).
        if (!preg_match('/^[A-Za-z0-9._\-]{30,200}$/', $g)) {
            return 'Gemini key ঠিক মনে হচ্ছে না।';
        }
        update_option('ma_gemini_key', $g, false);
    }
    return '';
}

/** Prices per million tokens (site owner only); [new] adds a model at 0. */
function ma_ai_save_prices($prices, $new = '') {
    $out = [];
    foreach ((array) $prices as $model => $p) {
        $model = sanitize_text_field((string) $model);
        if (!preg_match('/^[a-z0-9.\-]{3,64}$/', $model) || !is_array($p)) {
            continue;
        }
        $one = [];
        foreach (['in', 'cw', 'cr', 'out'] as $k) {
            $one[$k] = max(0, min(1000, (float) ($p[$k] ?? 0)));
        }
        $out[$model] = $one;
    }
    $new = sanitize_text_field((string) $new);
    if ($new !== '' && preg_match('/^[a-z0-9.\-]{3,64}$/', $new) && !isset($out[$new])) {
        $out[$new] = ['in' => 0, 'cw' => 0, 'cr' => 0, 'out' => 0];
    }
    update_option('ma_ai_prices', wp_json_encode($out), false);
    return $out;
}

function ma_nlu_ci_key_new() {
    $k = bin2hex(random_bytes(24));
    update_option('ma_nlu_ci_key', $k, false);
    return $k;
}

/** Everything the AI settings show, the same for the site page and the admin app. */
function ma_ai_settings_view($owner) {
    $ai = ma_ai_settings();
    $v = [
        'nlu' => ma_nlu_settings(), 'ai_on' => $ai['on'], 'ai_per_user' => $ai['per_user'], 'ai_per_day' => $ai['per_day'],
        'budgets' => ma_ai_budgets(), 'member_cap_usd' => ma_ai_member_cap(), 'usd_bdt' => ma_ai_usd_bdt(),
        'anthropic_key' => ma_ai_key_source(), 'gemini_key' => ma_nlu_gemini_key() !== '', 'prompt_ver' => MA_NLU_PROMPT_VER, 'owner' => (bool) $owner,
    ];
    if ($owner) {
        $v += [
            'anthropic_tail' => substr(ma_ai_key(), -4), 'gemini_source' => ma_nlu_gemini_key_source(), 'gemini_tail' => substr(ma_nlu_gemini_key(), -4),
            'prices' => ma_ai_prices(), 'ci_key' => (defined('MA_NLU_CI_KEY') && MA_NLU_CI_KEY) ? 'wp-config' : ma_nlu_ci_key(),
        ];
    }
    return $v;
}

function ma_admin_is_owner(WP_REST_Request $req) {
    $a = ma_admin_of($req);
    return $a && user_can((int) $a['id'], 'manage_options');
}

// ── The admin app ──

add_action('rest_api_init', function () {
    $owner_only = new WP_Error('owner', 'site owner only', ['status' => 403]);
    ma_admin_route('/ai/settings', 'GET', function (WP_REST_Request $req) {
        return ma_ai_settings_view(ma_admin_is_owner($req));
    });
    ma_admin_route('/ai/settings', 'POST', function (WP_REST_Request $req) use ($owner_only) {
        $in = json_decode($req->get_body(), true) ?: [];
        $owner = ma_admin_is_owner($req);
        // The kill switch, limits, budgets, keys and prices: the site owner only (as on the site's
        // settings page); the on-phone model's settings: any admin (as on the site's "AI মডেল" page).
        if (!$owner && array_intersect(array_keys($in), ['ai_on', 'ai_per_user', 'ai_per_day', 'budgets', 'budgets_auto', 'keys', 'prices', 'new_model'])) {
            return $owner_only;
        }
        ma_ai_save_general($in);
        if (isset($in['nlu']) && is_array($in['nlu'])) {
            ma_nlu_save_settings($in['nlu']);
        }
        if (isset($in['keys']) && is_array($in['keys'])) {
            $err = ma_ai_save_keys($in['keys']);
            if ($err !== '') {
                return new WP_Error('key', $err, ['status' => 400]);
            }
        }
        if (isset($in['prices']) && is_array($in['prices'])) {
            ma_ai_save_prices($in['prices'], (string) ($in['new_model'] ?? ''));
        }
        return ma_ai_settings_view($owner);
    });
    ma_admin_route('/nlu/ci-key', 'POST', function (WP_REST_Request $req) use ($owner_only) {
        return ma_admin_is_owner($req) ? ['ci_key' => ma_nlu_ci_key_new()] : $owner_only;
    });
    ma_admin_route('/nlu/review', 'GET', function (WP_REST_Request $req) {
        return ['samples' => ma_nlu_review_list((int) ($req->get_param('limit') ?: 50)), 'intents' => array_keys(MA_NLU_INTENTS)];
    });
    ma_admin_route('/nlu/review/(?P<id>\d+)', 'POST', function (WP_REST_Request $req) {
        $in = json_decode($req->get_body(), true) ?: [];
        $r = ma_nlu_label_sample((int) $req['id'], $in['intents'] ?? [], $in['pick'] ?? '', (int) ma_admin_of($req)['id']);
        return is_wp_error($r) ? $r : ['ok' => true];
    });
    ma_admin_route('/nlu/models', 'GET', function () {
        return ['models' => ma_nlu_models_list()];
    });
    ma_admin_route('/nlu/models', 'POST', function (WP_REST_Request $req) {
        $in = json_decode($req->get_body(), true) ?: [];
        $action = sanitize_key((string) ($in['action'] ?? 'draft'));
        $r = $action === 'draft' ? ma_nlu_add_draft($in) : ma_nlu_model_do($in['version'] ?? '', $action, $in['pct'] ?? null);
        return is_wp_error($r) ? $r : ['ok' => true, 'model' => $r];
    });
}, 20);

// ── The site's pages ──

add_action('admin_post_ma_nlu_settings', function () {
    ma_acc_guard('ma_nlu_settings');
    $n = (array) wp_unslash($_POST['nlu'] ?? []);
    $n['cloud_on'] = !empty($n['cloud_on']);
    if (isset($n['escalate_share'])) {
        $n['escalate_share'] = ((float) $n['escalate_share']) / 100; // the form asks in %
    }
    ma_nlu_save_settings($n);
    ma_acc_back('ফোনের মডেলের সেটিংস রাখা হয়েছে।', 'ok', ['tab' => 'nlu']);
});

add_action('admin_post_ma_nlu_model', function () {
    ma_acc_guard('ma_nlu_model');
    $r = ma_nlu_model_do(wp_unslash($_POST['version'] ?? ''), sanitize_key($_POST['op'] ?? ''), (int) ($_POST['pct'] ?? 0));
    if (is_wp_error($r)) {
        ma_acc_back('হলো না: ' . $r->get_error_message(), 'error', ['tab' => 'nlu']);
    }
    $say = $r['status'] === 'live' ? sprintf('%s চালু — %s%% সদস্য পাবেন।', $r['version'], ma_acc_bn((string) $r['rollout_pct'])) : sprintf('%s বন্ধ করা হলো — সদস্যরা আগের মডেলে ফিরবেন।', $r['version']);
    ma_acc_back($say, 'ok', ['tab' => 'nlu']);
});

add_action('admin_post_ma_nlu_draft', function () {
    ma_acc_guard('ma_nlu_draft');
    $r = ma_nlu_add_draft(['version' => wp_unslash($_POST['version'] ?? ''), 'url' => wp_unslash($_POST['url'] ?? ''), 'sha256' => trim((string) wp_unslash($_POST['sha256'] ?? '')), 'size' => (int) ($_POST['size'] ?? 0)]);
    ma_acc_back(is_wp_error($r) ? 'হলো না: নতুন সংস্করণের নাম, https ঠিকানা আর SHA-256 লাগবে।' : 'draft হিসেবে রাখা হলো — এখন চালু করতে পারেন।', is_wp_error($r) ? 'error' : 'ok', ['tab' => 'nlu']);
});

add_action('admin_post_ma_nlu_label', function () {
    ma_acc_guard('ma_nlu_label');
    $pick = sanitize_key($_POST['pick'] ?? 'other');
    $intents = array_map('sanitize_key', (array) ($_POST['intents'] ?? []));
    if ($pick === 'phone' || $pick === 'cloud') {
        $intents = array_filter(explode(',', sanitize_text_field(wp_unslash($_POST[$pick . '_intents'] ?? ''))));
    }
    $r = ma_nlu_label_sample((int) ($_POST['sample'] ?? 0), $intents, $pick, get_current_user_id());
    ma_acc_back(is_wp_error($r) ? 'হলো না: ঠিক কাজের ধরন বাছুন।' : 'রাখা হয়েছে — পরের শেখানোয় এটা কাজে লাগবে।', is_wp_error($r) ? 'error' : 'ok', ['tab' => 'nlu']);
});
