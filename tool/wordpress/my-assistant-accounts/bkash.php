<?php
/**
 * bKash payments turned on by themselves (owner, 27 Oct): the admin app on
 * the phone with the payment SIM reads bKash's "You have received Tk …"
 * messages and sends four things only — amount, TrxID, sender number and
 * time (never the message itself, the balance or anything else on that
 * phone). When a payment submitted on the website has the same TrxID and at
 * least the plan's price came in, Premium is turned on at once — whichever
 * of the two arrives first.
 *
 * The phone posts with its own key (made in the admin app), which can do
 * nothing but this.
 */

if (!defined('ABSPATH')) {
    exit;
}

function ma_bk_table() {
    global $wpdb;
    return $wpdb->prefix . 'ma_bkash_in';
}

function ma_bk_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    dbDelta('CREATE TABLE ' . ma_bk_table() . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        trx varchar(32) NOT NULL,
        amount int(10) unsigned NOT NULL DEFAULT 0,
        sender varchar(20) NOT NULL DEFAULT '',
        received_at datetime NOT NULL,
        created_at datetime NOT NULL,
        source varchar(8) NOT NULL DEFAULT 'sms',
        status varchar(12) NOT NULL DEFAULT 'new',
        verified tinyint(1) NOT NULL DEFAULT 0,
        payment_id bigint(20) unsigned NOT NULL DEFAULT 0,
        PRIMARY KEY  (id),
        UNIQUE KEY trx (trx),
        KEY status (status)
    ) " . $wpdb->get_charset_collate() . ';');
}

/**
 * Automatic approval: off unless an admin turns it on (owner's review,
 * 27 Oct). Even on, only a message the payment-SIM phone could check against
 * bKash's running balance is approved by itself — a faked "bKash" sender
 * cannot know the balance.
 */
function ma_bk_auto() {
    return get_option('ma_bk_auto', '0') === '1';
}

/** Bangla digits to ASCII. */
function ma_bk_digits($s) {
    return strtr((string) $s, ['০' => '0', '১' => '1', '২' => '2', '৩' => '3', '৪' => '4', '৫' => '5', '৬' => '6', '৭' => '7', '৮' => '8', '৯' => '9']);
}

/** "01712345678" from "+8801712345678", "01712-345678"…; '' when it is not a Bangladeshi mobile. */
function ma_bk_phone($s) {
    $d = preg_replace('/\D/', '', ma_bk_digits($s));
    if (str_starts_with($d, '880')) {
        $d = substr($d, 2);
    }
    return preg_match('/^01[3-9]\d{8}$/', $d) ? $d : '';
}

/**
 * Reads one bKash message (English or Bangla). Only money received counts —
 * not cash-in, cash-out or sending. Returns
 * ['trx', 'amount', 'sender', 'at' (UTC 'Y-m-d H:i:s' or '')] or null.
 */
function ma_bk_parse($text) {
    $t = ma_bk_digits(trim((string) $text));
    if ($t === '' || !preg_match('/(you have received|received payment|পেয়েছেন|গ্রহণ করেছেন)/iu', $t)) {
        return null;
    }
    if (!preg_match('/TrxID[:\s#]*([A-Z0-9]{8,12})\b/i', $t, $tm)) {
        return null;
    }
    $amount = null;
    if (preg_match('/Tk\.?\s*([\d,]+(?:\.\d{1,2})?)/i', $t, $am)) {
        $amount = $am[1];
    } elseif (preg_match('/([\d,]+(?:\.\d{1,2})?)\s*টাকা/u', $t, $am)) {
        $amount = $am[1];
    } elseif (preg_match('/৳\s*([\d,]+(?:\.\d{1,2})?)/u', $t, $am)) {
        $amount = $am[1];
    }
    if ($amount === null) {
        return null;
    }
    $amount = (int) floor((float) str_replace(',', '', $amount));
    if ($amount <= 0) {
        return null;
    }
    $sender = '';
    if (preg_match('/from\s+(\+?[\d\-\s]{11,16})/i', $t, $sm) || preg_match('/(\+?[\d\-]{11,16})\s*(?:নম্বর\s*)?থেকে/u', $t, $sm)) {
        $sender = ma_bk_phone($sm[1]);
    }
    $at = '';
    if (preg_match('/(\d{1,2})\/(\d{1,2})\/(\d{4})\s+(\d{1,2}):(\d{2})/', $t, $dm)) {
        $local = sprintf('%04d-%02d-%02d %02d:%02d:00', $dm[3], $dm[2], $dm[1], $dm[4], $dm[5]);
        $ts = strtotime($local . ' UTC');
        if ($ts) {
            $at = gmdate('Y-m-d H:i:s', $ts - ma_acc_tz_off());
        }
    }
    return ['trx' => strtoupper($tm[1]), 'amount' => $amount, 'sender' => $sender, 'at' => $at];
}

/**
 * Keeps one received payment (a TrxID is kept once) and tries to match it.
 * $item: trx, amount, sender, at. Returns [ok, status, id].
 */
function ma_bk_receive(array $item, $source = 'sms') {
    global $wpdb;
    $trx = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', (string) ($item['trx'] ?? '')));
    $amount = (int) ($item['amount'] ?? 0);
    if (strlen($trx) < 8 || strlen($trx) > 12 || $amount <= 0 || $amount > 1000000) {
        return [false, 'bad', 0];
    }
    $at = strtotime((string) ($item['at'] ?? '')) ?: time();
    // Only fresh ones: a message from long ago is not a payment for today.
    if ($at < time() - 14 * DAY_IN_SECONDS || $at > time() + DAY_IN_SECONDS) {
        $at = time();
    }
    $old = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_bk_table() . ' WHERE trx = %s', $trx), ARRAY_A);
    if ($old) {
        return [true, $old['status'], (int) $old['id']];
    }
    $wpdb->insert(ma_bk_table(), [
        'trx' => $trx,
        'amount' => $amount,
        'sender' => ma_bk_phone((string) ($item['sender'] ?? '')),
        'received_at' => gmdate('Y-m-d H:i:s', $at),
        'created_at' => gmdate('Y-m-d H:i:s'),
        'source' => $source === 'manual' ? 'manual' : 'sms',
        'status' => 'new',
        // Pasted by an admin: the admin saw it. From the phone: only when its balance checked out.
        'verified' => $source === 'manual' || !empty($item['verified']) ? 1 : 0,
    ]);
    $id = (int) $wpdb->insert_id;
    if ($source === 'sms') {
        update_option('ma_bk_last', gmdate('Y-m-d H:i:s'), false);
    }
    $pay = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_pay_table() . " WHERE UPPER(trx) = %s AND status = 'pending' ORDER BY id LIMIT 1", $trx), ARRAY_A);
    $status = $pay ? ma_bk_settle($id, $pay) : 'new';
    return [true, $status, $id];
}

/**
 * A received bKash payment and a submitted one with the same TrxID: Premium
 * on when at least the price came in (and the numbers agree, if both were
 * given). Returns the received line's new status.
 */
function ma_bk_settle($in_id, array $pay) {
    global $wpdb;
    $in = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_bk_table() . ' WHERE id = %d', $in_id), ARRAY_A);
    if (!$in || (int) $in['payment_id'] !== 0 || $pay['status'] !== 'pending') {
        return $in['status'] ?? 'new';
    }
    $said = ma_bk_phone($pay['sender']);
    $status = 'matched';
    $why = '';
    if ((int) $in['amount'] < (int) $pay['amount']) {
        $status = 'short';
        $why = 'বিকাশে এসেছে ৳' . ma_acc_bn($in['amount']) . ', প্ল্যানের দাম ৳' . ma_acc_bn($pay['amount']) . ' — দেখে সিদ্ধান্ত দিন।';
    } elseif ($said !== '' && $in['sender'] !== '' && $said !== $in['sender']) {
        $status = 'other_no';
        $why = 'TrxID মিলেছে, কিন্তু টাকা এসেছে ' . $in['sender'] . ' থেকে, ফর্মে লেখা ' . $said . ' — দেখে সিদ্ধান্ত দিন।';
    } elseif (!ma_bk_auto()) {
        $status = 'found';
        $why = 'বিকাশে টাকা এসেছে (TrxID মিলেছে) — নিজে থেকে অনুমোদন বন্ধ, হাতে দিন।';
    } elseif (empty($in['verified'])) {
        $status = 'found';
        $why = 'TrxID মিলেছে, কিন্তু বিকাশের ব্যালেন্স দিয়ে মেসেজটা নিশ্চিত করা যায়নি (ভুয়া SMS-ও হতে পারে) — বিকাশ অ্যাপে টাকা এসেছে দেখে হাতে দিন।';
    }
    $wpdb->update(ma_bk_table(), ['payment_id' => (int) $pay['id'], 'status' => $status], ['id' => $in_id]);
    if ($status === 'matched') {
        ma_pay_decide((int) $pay['id'], true, '', true, 'বিকাশ — নিজে থেকে', 'bkash');
    } else {
        $wpdb->update(ma_pay_table(), ['reason' => mb_substr($why, 0, 300)], ['id' => (int) $pay['id']]);
    }
    return $status;
}

/** A payment just submitted on the website: was its money already seen? Returns true when Premium came on. */
function ma_bk_on_payment($pay_id) {
    global $wpdb;
    $pay = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_pay_table() . ' WHERE id = %d', $pay_id), ARRAY_A);
    if (!$pay) {
        return false;
    }
    $in = $wpdb->get_row($wpdb->prepare('SELECT id FROM ' . ma_bk_table() . ' WHERE trx = %s AND payment_id = 0', strtoupper($pay['trx'])), ARRAY_A);
    return $in && ma_bk_settle((int) $in['id'], $pay) === 'matched';
}

function ma_bk_status_labels() {
    return [
        'new' => ['ফর্ম জমা হয়নি এখনো', 'waiting'],
        'matched' => ['মিলেছে — প্রিমিয়াম চালু', 'pro'],
        'found' => ['মিলেছে — হাতে অনুমোদন দিন', 'trial'],
        'short' => ['টাকা কম', 'expired'],
        'other_no' => ['নম্বর মেলেনি', 'expired'],
    ];
}

function ma_bk_json($r) {
    $l = ma_bk_status_labels()[$r['status']] ?? [$r['status'], 'free'];
    return [
        'id' => (int) $r['id'],
        'trx' => $r['trx'],
        'amount' => (int) $r['amount'],
        'sender' => $r['sender'],
        'at' => gmdate('c', ma_acc_ts($r['received_at'])),
        'source' => $r['source'],
        'verified' => !empty($r['verified']),
        'status' => $r['status'],
        'status_label' => $l[0],
        'payment_id' => (int) $r['payment_id'],
    ];
}

function ma_bk_list($limit = 100) {
    global $wpdb;
    return $wpdb->get_results($wpdb->prepare('SELECT * FROM ' . ma_bk_table() . ' ORDER BY id DESC LIMIT %d', $limit), ARRAY_A);
}

/** What the payments page shows about this. */
function ma_bk_overview() {
    $last = (string) get_option('ma_bk_last', '');
    return [
        'auto' => ma_bk_auto(),
        'phone_set' => get_option('ma_bk_key', '') !== '',
        'last_sms' => $last !== '' ? gmdate('c', ma_acc_ts($last)) : null,
        'received' => array_map('ma_bk_json', ma_bk_list(50)),
    ];
}

/** A new key for the payment-SIM phone (the old one stops working). Shown once. */
function ma_bk_new_key() {
    $key = 'bk_' . bin2hex(random_bytes(24));
    update_option('ma_bk_key', hash('sha256', $key), false);
    return $key;
}

function ma_bk_key_ok($key) {
    $saved = (string) get_option('ma_bk_key', '');
    return $saved !== '' && is_string($key) && preg_match('/^bk_[a-f0-9]{48}$/', $key) && hash_equals($saved, hash('sha256', $key));
}

add_action('rest_api_init', function () {
    // The payment-SIM phone (its own key, nothing else).
    register_rest_route('my-assistant/v1', '/bkash/sms', [
        'methods' => 'POST',
        'permission_callback' => '__return_true', // the key is checked inside
        'callback' => function (WP_REST_Request $req) {
            if (!ma_bk_key_ok((string) $req->get_header('x-ma-bkash-key'))) {
                return new WP_Error('key', 'not this phone', ['status' => 403]);
            }
            $rl = 'ma_bk_rl';
            $n = (int) get_transient($rl);
            if ($n >= 300) {
                return new WP_Error('busy', 'too many', ['status' => 429]);
            }
            set_transient($rl, $n + 1, HOUR_IN_SECONDS);
            $items = $req->get_param('items');
            if (!is_array($items)) {
                return new WP_Error('bad', 'items needed', ['status' => 400]);
            }
            $out = [];
            foreach (array_slice($items, 0, 20) as $it) {
                if (is_array($it)) {
                    [$ok, $status] = ma_bk_receive($it, 'sms');
                    $out[] = $ok ? $status : 'bad';
                }
            }
            return ['ok' => true, 'results' => $out];
        },
    ]);

    ma_admin_route('/bkash', 'GET', function () {
        return ma_bk_overview();
    });
    ma_admin_route('/bkash/settings', 'POST', function (WP_REST_Request $req) {
        if ($req->get_param('auto') !== null) {
            update_option('ma_bk_auto', $req->get_param('auto') ? '1' : '0');
        }
        return ma_bk_overview();
    });
    // The payment-SIM phone's key (from the admin app on that phone).
    ma_admin_route('/bkash/key', 'POST', function () {
        return ['key' => ma_bk_new_key()];
    });
    // A message pasted by hand (the phone reads it; only the four fields come).
    ma_admin_route('/bkash/manual', 'POST', function (WP_REST_Request $req) {
        $item = ['trx' => $req->get_param('trx'), 'amount' => $req->get_param('amount'), 'sender' => $req->get_param('sender'), 'at' => $req->get_param('at'), 'verified' => (bool) $req->get_param('verified')];
        // Read from the phone's inbox by the admin app: as trusted as the phone's check. Pasted: the admin saw it.
        [$ok, $status] = ma_bk_receive($item, $req->get_param('from') === 'scan' ? 'sms' : 'manual');
        return $ok ? ['ok' => true, 'status' => $status, 'status_label' => ma_bk_status_labels()[$status][0] ?? $status] : new WP_Error('bad', 'TrxID বা টাকা পড়া যায়নি', ['status' => 400]);
    });
});

// ── The site's payments tab ──

add_action('admin_post_ma_bk_settings', function () {
    ma_acc_guard('ma_bk_settings');
    update_option('ma_bk_auto', !empty($_POST['auto']) ? '1' : '0');
    ma_acc_back(ma_bk_auto() ? 'বিকাশে টাকা মিললে প্রিমিয়াম নিজে থেকে চালু হবে।' : 'নিজে থেকে অনুমোদন বন্ধ — প্রতিটা পেমেন্ট আপনি দেখে দেবেন।', 'ok', ['tab' => 'payments']);
});

add_action('admin_post_ma_bk_paste', function () {
    ma_acc_guard('ma_bk_paste');
    $p = ma_bk_parse(wp_unslash((string) ($_POST['text'] ?? '')));
    if (!$p) {
        ma_acc_back('মেসেজ থেকে TrxID বা টাকা পড়া যায়নি — বিকাশের “You have received …” মেসেজটা পুরোটা পেস্ট করুন।', 'error', ['tab' => 'payments']);
    }
    [, $status] = ma_bk_receive($p, 'manual');
    ma_acc_back('TrxID ' . $p['trx'] . ' · ৳' . ma_acc_bn($p['amount']) . ' — ' . (ma_bk_status_labels()[$status][0] ?? $status), 'ok', ['tab' => 'payments']);
});
