<?php
/**
 * Keeping every admin's phone on the same account. Phones send the records
 * they changed (/push) and fetch everything changed since their last
 * revision (/pull). Nothing is ever deleted: sends are cancelled instead.
 * When a send or a payment concerns an agent who uses the app, the agent is
 * told (notification + list).
 */

if (!defined('ABSPATH')) {
    exit;
}

const RH_KINDS = ['customer', 'agent', 'txn', 'deposit', 'payment', 'expense', 'close', 'loss', 'handover', 'adjust', 'log', 'settings'];

/** Records that belong to the admin who made them (their hand). */
const RH_OWNED = ['txn', 'deposit', 'payment', 'expense', 'close', 'loss', 'adjust'];

add_action('rest_api_init', function () {
    rh_route('/push', 'POST', 'rh_push', 'admin');
    rh_route('/pull', 'GET', 'rh_pull', 'admin');
    rh_route('/reserve', 'POST', 'rh_reserve', 'admin');
    rh_route('/photo', 'POST', 'rh_photo_put', 'admin');
    rh_route('/photo', 'GET', 'rh_photo_get', 'any');
});

/** A new revision number (strictly increasing). */
function rh_next_rev() {
    global $wpdb;
    $wpdb->query('INSERT INTO ' . rh_t('revs') . ' (id) VALUES (NULL)');
    return (int) $wpdb->insert_id;
}

/** The time a record is about, for filtering by date. */
function rh_record_time($kind, $d) {
    $iso = $d['at'] ?? ($d['created'] ?? null);
    return $iso ? rh_mysql_time($iso) : null;
}

/**
 * Writes one record. For a send, what the agent reported (sent, TrxID,
 * reply) is kept even when an admin's phone still had the older copy.
 */
function rh_put($kind, $rid, array $data, $user_id) {
    global $wpdb, $rh_cache;
    unset($rh_cache[$kind]);
    $old = rh_one($kind, $rid);
    if ($kind === 'txn' && $old && ($old['status'] ?? '') === 'sent' && ($data['status'] ?? '') === 'pending') {
        foreach (['status', 'trxId', 'agentReply', 'replyTail', 'sentAt', 'replyFrom'] as $f) {
            $data[$f] = $old[$f] ?? ($data[$f] ?? '');
        }
    }
    if ($kind === 'txn' && $old) {
        foreach (['trxId', 'agentReply', 'replyTail', 'sentAt'] as $f) {
            if (($data[$f] ?? '') === '' && ($old[$f] ?? '') !== '') {
                $data[$f] = $old[$f];
            }
        }
    }
    $json = wp_json_encode($data, JSON_UNESCAPED_UNICODE);
    if ($old !== null && wp_json_encode($old, JSON_UNESCAPED_UNICODE) === $json) {
        return [$old, $old];
    }
    $row = [
        'kind' => $kind,
        'rid' => $rid,
        'rev' => rh_next_rev(),
        'agent_rid' => (string) ($kind === 'agent' ? $rid : ($data['agentId'] ?? '')),
        'cust_rid' => (string) ($kind === 'customer' ? $rid : ($data['customerId'] ?? '')),
        'at' => rh_record_time($kind, $data),
        'data' => $json,
        'updated_at' => rh_now(),
        'updated_by' => (int) $user_id,
    ];
    if ($old === null) {
        $wpdb->insert(rh_t('records'), $row);
    } else {
        $wpdb->update(rh_t('records'), $row, ['kind' => $kind, 'rid' => $rid]);
    }
    return [$old, $data];
}

function rh_push(WP_REST_Request $req, $u) {
    $records = $req->get_param('records');
    if (!is_array($records) || count($records) > 2000) {
        return new WP_Error('bad', 'records', ['status' => 400]);
    }
    $n = 0;
    $refused = [];
    foreach ($records as $r) {
        $kind = (string) ($r['kind'] ?? '');
        $rid = (string) ($r['rid'] ?? '');
        $data = $r['data'] ?? null;
        if (!in_array($kind, RH_KINDS, true) || !preg_match('/^[A-Za-z0-9_\-]{1,64}$/', $rid) || !is_array($data)) {
            continue;
        }
        if (!rh_may_write($u, $kind, $rid, $data)) {
            $refused[] = ['kind' => $kind, 'rid' => $rid];
            continue;
        }
        // Who made it is the server's to say: the signed-in admin for a new
        // record, and never changed afterwards.
        if (in_array($kind, RH_OWNED, true)) {
            $old = rh_one($kind, $rid);
            if ($old) {
                $data['by'] = $old['by'] ?? 0;
                $data['byName'] = $old['byName'] ?? '';
            } else {
                $data['by'] = (int) $u['id'];
                $data['byName'] = $u['name'];
            }
        }
        [$old, $new] = rh_put($kind, $rid, $data, $u['id']);
        if ($old !== $new) {
            rh_tell_agents($kind, $old, $new);
        }
        $n++;
    }
    return rest_ensure_response(['ok' => true, 'saved' => $n, 'refused' => $refused]);
}

/** May this admin write this record (their access checklist)? */
function rh_may_write($u, $kind, $rid, $data) {
    $old = rh_one($kind, $rid);
    switch ($kind) {
        case 'log':
            return true;
        case 'txn':
            if (!$old) {
                return rh_can($u, 'send');
            }
            // Once the agent has sent it, the money side never changes:
            // mistakes are written as "অতিরিক্ত হিসাব" (adjust).
            if (($old['status'] ?? '') === 'sent') {
                foreach (['customerId', 'agentId', 'number', 'method', 'kind', 'sar', 'rate', 'taka', 'fee', 'pay', 'sarPaid', 'operator', 'pack'] as $f) {
                    if (wp_json_encode($old[$f] ?? null) !== wp_json_encode($data[$f] ?? null)) {
                        return false;
                    }
                }
            }
            // Paying the agent marks the sends paid; anything else is an edit.
            $a = $old;
            $b = $data;
            unset($a['agentPaymentId'], $b['agentPaymentId']);
            if (wp_json_encode($a) === wp_json_encode($b)) {
                return rh_can($u, 'agent_pay') || rh_can($u, 'edit');
            }
            return rh_can($u, 'edit');
        case 'customer':
            // A send or a deposit also keeps the customer's numbers up to date.
            return rh_can($u, 'customers') || rh_can($u, 'send') || (!$old && rh_can($u, 'deposit'));
        case 'deposit':
            return rh_can($u, 'deposit');
        case 'loss':
            return rh_can($u, 'loss');
        case 'payment':
            return rh_can($u, 'agent_pay');
        case 'agent':
            return rh_can($u, 'agents');
        case 'expense':
        case 'close':
            return rh_can($u, 'expense');
        case 'settings':
            return rh_can($u, 'settings') || ($old && wp_json_encode($old) === wp_json_encode($data));
        case 'adjust':
            if (!$old) {
                return rh_can($u, 'edit');
            }
            // The only change: adding it to the main account, once.
            $a = $old;
            $b = $data;
            unset($a['applied'], $a['appliedAt'], $a['appliedByName'], $b['applied'], $b['appliedAt'], $b['appliedByName'], $a['by'], $a['byName'], $b['by'], $b['byName']);
            return rh_can($u, 'edit') && empty($old['applied']) && !empty($data['applied']) && wp_json_encode($a) === wp_json_encode($b);
        case 'handover':
            // Only the one who takes the riyal records it, once.
            return !$old && (int) ($data['to'] ?? 0) === (int) $u['id'] && (int) ($data['from'] ?? 0) !== (int) $u['id'] && (float) ($data['sar'] ?? 0) > 0;
    }
    return false;
}

function rh_pull(WP_REST_Request $req, $u) {
    global $wpdb;
    $since = max(0, (int) $req->get_param('since'));
    $limit = 500;
    $rows = $wpdb->get_results($wpdb->prepare('SELECT kind, rid, rev, data FROM ' . rh_t('records') . ' WHERE rev > %d ORDER BY rev ASC LIMIT %d', $since, $limit + 1), ARRAY_A);
    $more = count($rows) > $limit;
    $rows = array_slice($rows, 0, $limit);
    $out = [];
    $rev = $since;
    foreach ($rows as $r) {
        $out[] = ['kind' => $r['kind'], 'rid' => $r['rid'], 'rev' => (int) $r['rev'], 'data' => json_decode($r['data'], true)];
        $rev = max($rev, (int) $r['rev']);
    }
    return rest_ensure_response(['records' => $out, 'rev' => $rev, 'more' => $more]);
}

/**
 * Send numbers for one phone: year, month, then the month's serial —
 * 26110001 is the first send of November 2026. A block no other phone
 * gets, so a phone can save a send even when the internet drops.
 */
function rh_reserve(WP_REST_Request $req, $u) {
    $count = min(50, max(1, (int) $req->get_param('count')));
    $ym = (string) $req->get_param('ym');
    if (!preg_match('/^\d{2}(0[1-9]|1[0-2])$/', $ym)) {
        $ym = current_time('ym');
    }
    $nos = [];
    for ($i = 0; $i < $count; $i++) {
        $nos[] = (int) $ym * 10000 + rh_next_serial($ym);
    }
    return rest_ensure_response(['numbers' => $nos]);
}

/** The next serial of a month (never the same twice, even at the same moment). */
function rh_next_serial($ym) {
    global $wpdb;
    $t = rh_t('seq');
    if (get_option('rh_seq_ready') !== '2') {
        $wpdb->query("DROP TABLE IF EXISTS $t");
        $wpdb->query("CREATE TABLE $t (id bigint(20) unsigned NOT NULL AUTO_INCREMENT, ym varchar(4) NOT NULL DEFAULT '', PRIMARY KEY (id), KEY ym (ym))");
        update_option('rh_seq_ready', '2');
    }
    $wpdb->insert($t, ['ym' => $ym]);
    $id = (int) $wpdb->insert_id;
    return (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $t WHERE ym = %s AND id <= %d", $ym, $id));
}

function rh_photo_put(WP_REST_Request $req, $u) {
    global $wpdb;
    $pid = (string) $req->get_param('pid');
    $b64 = (string) $req->get_param('data');
    if (!preg_match('/^[A-Za-z0-9_\-]{1,64}$/', $pid) || strlen($b64) > 4 * 1024 * 1024 || base64_decode($b64, true) === false) {
        return new WP_Error('bad', 'photo', ['status' => 400]);
    }
    $wpdb->replace(rh_t('photos'), ['pid' => $pid, 'mime' => 'image/jpeg', 'data' => $b64, 'created_at' => rh_now(), 'created_by' => (int) $u['id']]);
    return rest_ensure_response(['ok' => true]);
}

/** Admins see every photo; an agent only the receipts of payments made to them. */
function rh_photo_get(WP_REST_Request $req, $u) {
    global $wpdb;
    $pid = (string) $req->get_param('pid');
    if ($u['role'] === 'agent') {
        $ok = false;
        foreach (rh_all('payment') as $p) {
            if (($p['receipt'] ?? '') === $pid && ($p['agentId'] ?? '') === $u['agent_rid']) {
                $ok = true;
            }
        }
        if (!$ok) {
            return rh_hidden();
        }
    }
    $b64 = $wpdb->get_var($wpdb->prepare('SELECT data FROM ' . rh_t('photos') . ' WHERE pid = %s', $pid));
    return $b64 ? rest_ensure_response(['data' => $b64]) : new WP_Error('none', 'no photo', ['status' => 404]);
}

/** "৳ ১৬,২৫০ · বিকাশ 01812-345901 · সেন্ড মানি" — taka only, never riyal. */
function rh_txn_line($t) {
    $parts = [rh_taka(rh_agent_taka($t)), rh_service($t) . ' ' . rh_phone_show($t['number'] ?? '')];
    $k = $t['kind'] ?? 'send';
    if ($k === 'mb' && ($t['pack'] ?? '') !== '') {
        $parts[] = 'প্যাক: ' . $t['pack'];
    } elseif ($k === 'send' || $k === 'cashout') {
        $parts[] = rh_kind_name($t);
    }
    return implode(' · ', $parts);
}

/** Tells the agent what concerns them. Old, already settled records (first upload) are not announced. */
function rh_tell_agents($kind, $old, $new) {
    if ($kind === 'txn') {
        $no = '#' . rh_bn((string) ($new['no'] ?? ''));
        $aid = (string) ($new['agentId'] ?? '');
        $was = $old ? (string) ($old['agentId'] ?? '') : '';
        $status = $new['status'] ?? 'pending';
        if (!$old || ($was !== $aid && $status === 'pending')) {
            if ($status === 'pending') {
                rh_note_agent($aid, 'new', 'নতুন অনুরোধ ' . $no, rh_txn_line($new), (string) $new['id']);
            }
            if ($old && $was !== '') {
                rh_note_agent($was, 'cancel', 'বাতিল ' . $no, 'এটা অন্য এজেন্টকে দেওয়া হয়েছে — পাঠাবেন না।', (string) $new['id']);
            }
            return;
        }
        if (($old['status'] ?? '') !== 'cancelled' && $status === 'cancelled') {
            rh_note_agent($aid, 'cancel', 'বাতিল ' . $no, rh_txn_line($new) . ' — এটা পাঠাবেন না।', (string) $new['id']);
            return;
        }
        $changed = false;
        foreach (['taka', 'fee', 'number', 'method', 'kind', 'operator', 'pack'] as $f) {
            if (($old[$f] ?? null) != ($new[$f] ?? null)) {
                $changed = true;
            }
        }
        if ($changed && $status === 'pending') {
            rh_note_agent($aid, 'edit', 'সংশোধন ' . $no, 'এখন: ' . rh_txn_line($new), (string) $new['id']);
        }
        if (empty($old['fault']) && !empty($new['fault'])) {
            $who = ['mine' => 'এডমিনের ভুল', 'agent' => 'আপনার ভুল', 'customer' => 'গ্রাহকের ভুল'][$new['fault']] ?? '';
            rh_note_agent($aid, 'fault', 'ভুল নম্বরে গেছে ' . $no, trim($who . (($new['faultNote'] ?? '') !== '' ? ' · ' . $new['faultNote'] : '')), (string) $new['id']);
        }
        return;
    }
    if ($kind === 'payment' && !$old) {
        $at = strtotime((string) ($new['at'] ?? ''));
        if ($at && $at < time() - 3 * DAY_IN_SECONDS) {
            return;
        }
        $n = count($new['txnIds'] ?? []);
        $body = rh_pay_way($new['way'] ?? '') . (($new['ref'] ?? '') !== '' ? ' · রেফ ' . $new['ref'] : '') . ($n ? ' · ' . rh_bn($n) . 'টা লেনদেনের' : '');
        rh_note_agent((string) ($new['agentId'] ?? ''), 'paid', 'টাকা পেয়েছেন ' . rh_taka($new['taka'] ?? 0), $body, (string) $new['id']);
    }
}
