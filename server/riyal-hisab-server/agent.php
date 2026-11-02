<?php
/**
 * The agent's side: only their own sends, in taka. Riyal, rates and
 * customers never leave the server for an agent.
 */

if (!defined('ABSPATH')) {
    exit;
}

add_action('rest_api_init', function () {
    rh_route('/agent/feed', 'GET', 'rh_agent_feed', 'agent');
    rh_route('/agent/sent', 'POST', 'rh_agent_sent', 'agent');
    rh_route('/agent/problem', 'POST', 'rh_agent_problem', 'agent');
    rh_route('/notes', 'GET', 'rh_notes_get', 'any');
    rh_route('/notes/read', 'POST', 'rh_notes_read', 'any');
});

/** What an agent may see of a send. */
function rh_txn_for_agent($t, $agent) {
    return [
        'id' => (string) ($t['id'] ?? ''),
        'no' => (int) ($t['no'] ?? 0),
        'number' => (string) ($t['number'] ?? ''),
        'method' => (string) ($t['method'] ?? 'bkash'),
        'kind' => (string) ($t['kind'] ?? 'send'),
        'operator' => (string) ($t['operator'] ?? ''),
        'pack' => (string) ($t['pack'] ?? ''),
        'taka' => (float) ($t['taka'] ?? 0),
        'fee' => (float) ($t['fee'] ?? 0),
        'commission' => rh_commission($t, $agent),
        'status' => (string) ($t['status'] ?? 'pending'),
        'trxId' => (string) ($t['trxId'] ?? ''),
        'agentReply' => (string) ($t['agentReply'] ?? ''),
        'at' => (string) ($t['at'] ?? ''),
        'sentAt' => $t['sentAt'] ?? null,
        'paid' => !empty($t['agentPaymentId']),
        'fault' => $t['fault'] ?? null,
        'faultNote' => (string) ($t['faultNote'] ?? ''),
    ];
}

function rh_agent_feed(WP_REST_Request $req, $u) {
    global $wpdb;
    $aid = (string) $u['agent_rid'];
    $agent = rh_all('agent')[$aid] ?? null;
    $txns = [];
    foreach (rh_all('txn') as $t) {
        if (($t['agentId'] ?? '') === $aid) {
            $txns[] = rh_txn_for_agent($t, $agent);
        }
    }
    usort($txns, fn($a, $b) => strcmp($b['at'], $a['at']));
    $pays = [];
    foreach (rh_all('payment') as $p) {
        if (($p['agentId'] ?? '') === $aid) {
            $pays[] = [
                'id' => (string) ($p['id'] ?? ''),
                'taka' => (float) ($p['taka'] ?? 0),
                'at' => (string) ($p['at'] ?? ''),
                'way' => (string) ($p['way'] ?? ''),
                'ref' => (string) ($p['ref'] ?? ''),
                'fromAccount' => (string) ($p['fromAccount'] ?? ''),
                'note' => (string) ($p['note'] ?? ''),
                'receipt' => $p['receipt'] ?? null,
                'count' => count($p['txnIds'] ?? []),
            ];
        }
    }
    usort($pays, fn($a, $b) => strcmp($b['at'], $a['at']));
    $unread = (int) $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . rh_t('notes') . ' WHERE user_id = %d AND read_at IS NULL', (int) $u['id']));
    return rest_ensure_response([
        'agent' => ['name' => $agent['name'] ?? $u['name'], 'commission' => (float) ($agent['commission'] ?? 0)],
        'owed' => rh_agent_owed($aid),
        'owner' => rh_owner_name(),
        'txns' => $txns,
        'payments' => $pays,
        'unread' => $unread,
    ]);
}

/** The phone's local time, as the app writes it. */
function rh_local_iso() {
    return current_time('Y-m-d\TH:i:s');
}

function rh_add_log($title, $detail, $who, $ref, $kind = 'agent') {
    $id = 's' . bin2hex(random_bytes(6));
    rh_put('log', $id, ['id' => $id, 'at' => rh_local_iso(), 'kind' => $kind, 'title' => $title, 'detail' => $detail, 'who' => $who, 'ref' => $ref], 0);
}

function rh_agent_txn(WP_REST_Request $req, $u) {
    $rid = (string) $req->get_param('id');
    $t = preg_match('/^[A-Za-z0-9_\-]{1,64}$/', $rid) ? rh_one('txn', $rid) : null;
    return $t && ($t['agentId'] ?? '') === $u['agent_rid'] ? $t : null;
}

/** "পাঠিয়েছি": the last 3 digits of the number it went from, and/or a TrxID. */
function rh_agent_sent(WP_REST_Request $req, $u) {
    $t = rh_agent_txn($req, $u);
    if (!$t) {
        return rh_hidden();
    }
    if (($t['status'] ?? '') === 'cancelled') {
        return new WP_Error('cancelled', 'cancelled', ['status' => 409]);
    }
    $trx = strtoupper(preg_replace('/[^A-Za-z0-9]/', '', (string) $req->get_param('trxId')));
    $tail = preg_replace('/[^0-9]/', '', strtr((string) $req->get_param('tail'), ['০' => '0', '১' => '1', '২' => '2', '৩' => '3', '৪' => '4', '৫' => '5', '৬' => '6', '৭' => '7', '৮' => '8', '৯' => '9']));
    if ($trx === '' && strlen($tail) !== 3) {
        return new WP_Error('need', 'tail or trx', ['status' => 400]);
    }
    if ($trx !== '' && (strlen($trx) < 6 || strlen($trx) > 14)) {
        return new WP_Error('trx', 'bad trx', ['status' => 400]);
    }
    $was = ($t['status'] ?? '') === 'sent';
    $no = (int) ($t['no'] ?? 0);
    if ($tail !== '') {
        $t['agentReply'] = $no . ' ' . (int) round(rh_agent_taka($t)) . '-' . $tail;
        $t['replyTail'] = $tail;
    }
    if ($trx !== '') {
        $t['trxId'] = $trx;
    }
    $t['status'] = 'sent';
    $t['replyFrom'] = 'agent';
    if (empty($t['sentAt'])) {
        $t['sentAt'] = rh_local_iso();
    }
    rh_put('txn', (string) $t['id'], $t, $u['id']);
    $bnNo = '#' . rh_bn($no);
    $detail = implode(' · ', array_filter([
        $tail !== '' ? 'উত্তর: ' . $t['agentReply'] : '',
        $trx !== '' ? 'TrxID ' . $trx : '',
        'এজেন্ট নিজে অ্যাপে জানালেন',
        $was ? '' : 'লেনদেন "পৌঁছেছে"',
    ]));
    rh_add_log(($was ? 'এজেন্টের উত্তর বদল · ' : 'এজেন্ট পাঠিয়েছেন · ') . $bnNo, $detail, $u['name'], (string) $t['id']);
    rh_note_admins('sent', 'এজেন্ট পাঠিয়েছেন ' . $bnNo, $u['name'] . ' · ' . rh_taka(rh_agent_taka($t)) . ' · ' . rh_phone_show($t['number'] ?? '') . ($trx !== '' ? ' · ' . $trx : ''), (string) $t['id']);
    return rest_ensure_response(['ok' => true, 'txn' => rh_txn_for_agent($t, rh_all('agent')[$u['agent_rid']] ?? null)]);
}

/** "পাঠাতে পারছি না" with a reason: the admins are told. */
function rh_agent_problem(WP_REST_Request $req, $u) {
    $t = rh_agent_txn($req, $u);
    if (!$t) {
        return rh_hidden();
    }
    $note = mb_substr(sanitize_text_field((string) $req->get_param('note')), 0, 300);
    $bnNo = '#' . rh_bn((string) ($t['no'] ?? ''));
    rh_add_log('এজেন্ট জানালেন: সমস্যা · ' . $bnNo, ($note !== '' ? $note : 'কারণ লেখেননি') . ' · ' . rh_phone_show($t['number'] ?? ''), $u['name'], (string) $t['id']);
    rh_note_admins('problem', 'সমস্যা ' . $bnNo . ' · ' . $u['name'], $note !== '' ? $note : 'এজেন্ট পাঠাতে পারছেন না', (string) $t['id']);
    return rest_ensure_response(['ok' => true]);
}

function rh_notes_get(WP_REST_Request $req, $u) {
    global $wpdb;
    $rows = $wpdb->get_results($wpdb->prepare('SELECT id, kind, title, body, ref, at, read_at FROM ' . rh_t('notes') . ' WHERE user_id = %d ORDER BY id DESC LIMIT 200', (int) $u['id']), ARRAY_A);
    return rest_ensure_response(['notes' => array_map(fn($r) => [
        'id' => (int) $r['id'],
        'kind' => $r['kind'],
        'title' => $r['title'],
        'body' => $r['body'],
        'ref' => $r['ref'],
        'at' => gmdate('c', strtotime($r['at'] . ' UTC')),
        'read' => $r['read_at'] !== null,
    ], $rows)]);
}

function rh_notes_read(WP_REST_Request $req, $u) {
    global $wpdb;
    $wpdb->query($wpdb->prepare('UPDATE ' . rh_t('notes') . ' SET read_at = %s WHERE user_id = %d AND read_at IS NULL', rh_now(), (int) $u['id']));
    return rest_ensure_response(['ok' => true]);
}
