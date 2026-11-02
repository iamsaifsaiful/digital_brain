<?php
/**
 * The same account maths as the app (lib/core/ledger.dart), for the record
 * pages: customers' due in riyal, agents' due in taka.
 */

if (!defined('ABSPATH')) {
    exit;
}

/** Every record of a kind, decoded, keyed by id. */
function rh_all($kind) {
    global $rh_cache;
    if (isset($rh_cache[$kind])) {
        return $rh_cache[$kind];
    }
    global $wpdb;
    $out = [];
    foreach ($wpdb->get_results($wpdb->prepare('SELECT rid, data FROM ' . rh_t('records') . ' WHERE kind = %s', $kind), ARRAY_A) as $r) {
        $d = json_decode($r['data'], true);
        if (is_array($d)) {
            $out[$r['rid']] = $d;
        }
    }
    return $rh_cache[$kind] = $out;
}

function rh_one($kind, $rid) {
    global $wpdb;
    $raw = $wpdb->get_var($wpdb->prepare('SELECT data FROM ' . rh_t('records') . ' WHERE kind = %s AND rid = %s', $kind, $rid));
    $d = $raw ? json_decode($raw, true) : null;
    return is_array($d) ? $d : null;
}

function rh_cancelled($t) {
    return ($t['status'] ?? '') === 'cancelled';
}

/** Riyal still owed for one send, as at the time it was made. */
function rh_due_at_send($t) {
    return rh_cancelled($t) ? 0.0 : max(0.0, (float) ($t['sar'] ?? 0) - (float) ($t['sarPaid'] ?? 0));
}

function rh_customer_due($cid) {
    $due = 0.0;
    foreach (rh_all('txn') as $t) {
        if (($t['customerId'] ?? '') === $cid) {
            $due += rh_due_at_send($t);
        }
    }
    foreach (['deposit', 'loss'] as $k) {
        foreach (rh_all($k) as $p) {
            if (($p['customerId'] ?? '') === $cid) {
                $due -= (float) ($p['sar'] ?? 0);
            }
        }
    }
    foreach (rh_all('adjust') as $x) {
        if (!empty($x['applied']) && ($x['customerId'] ?? '') === $cid) {
            $due += (float) ($x['sarDue'] ?? 0);
        }
    }
    return round($due, 2);
}

function rh_agent_taka($t) {
    return (float) ($t['taka'] ?? 0) + (float) ($t['fee'] ?? 0);
}

function rh_commission($t, $agent) {
    if (!$agent || rh_cancelled($t)) {
        return 0.0;
    }
    return round(rh_agent_taka($t) * (float) ($agent['commission'] ?? 0) / 1000);
}

function rh_agent_owed($aid) {
    $a = rh_all('agent')[$aid] ?? null;
    $owed = 0.0;
    foreach (rh_all('txn') as $t) {
        if (($t['agentId'] ?? '') === $aid && !rh_cancelled($t)) {
            $owed += rh_agent_taka($t) + rh_commission($t, $a);
        }
    }
    foreach (rh_all('payment') as $p) {
        if (($p['agentId'] ?? '') === $aid) {
            $owed -= (float) ($p['taka'] ?? 0);
        }
    }
    foreach (rh_all('adjust') as $x) {
        if (!empty($x['applied']) && ($x['agentId'] ?? '') === $aid) {
            $owed += (float) ($x['takaAgent'] ?? 0);
        }
    }
    return round($owed);
}

/**
 * Every riyal into or out of a hand (lib/core/ledger.dart cashLines): with
 * $by, one admin's hand; without, the shop's (handovers then cancel out).
 * Each line: [at, title, sub, in, out, kind, by, byName].
 */
function rh_cash_lines($by = null) {
    $mine = fn($r) => $by === null || (int) ($r['by'] ?? 0) === (int) $by;
    $cust = rh_all('customer');
    $agents = rh_all('agent');
    $out = [];
    foreach (rh_all('txn') as $t) {
        if (!rh_cancelled($t) && (float) ($t['sarPaid'] ?? 0) > 0 && $mine($t)) {
            $out[] = [$t['at'], ($cust[$t['customerId'] ?? '']['name'] ?? (($t['walkIn'] ?? '') !== '' ? $t['walkIn'] : 'প্রোফাইল ছাড়া')) . ' · #' . rh_bn($t['no'] ?? ''), (($t['pay'] ?? '') === 'partial' ? 'আংশিক' : 'নগদে') . ' · ' . rh_service($t), (float) $t['sarPaid'], 0.0, 'txn', (int) ($t['by'] ?? 0), (string) ($t['byName'] ?? '')];
        }
    }
    foreach (rh_all('deposit') as $p) {
        if ($mine($p)) {
            $out[] = [$p['at'], ($cust[$p['customerId'] ?? '']['name'] ?? '') . ' · জমা', ($p['way'] ?? '') === 'cash' ? 'নগদ হাতে' : 'ব্যাংক/ট্রান্সফার', (float) $p['sar'], 0.0, 'deposit', (int) ($p['by'] ?? 0), (string) ($p['byName'] ?? '')];
        }
    }
    foreach (rh_all('expense') as $e) {
        if ($mine($e)) {
            $out[] = [$e['at'], (string) ($e['category'] ?? ''), (string) ($e['note'] ?? ''), 0.0, (float) $e['sar'], 'expense', (int) ($e['by'] ?? 0), (string) ($e['byName'] ?? '')];
        }
    }
    foreach (rh_all('payment') as $p) {
        if ((float) ($p['sar'] ?? 0) > 0 && $mine($p)) {
            $out[] = [$p['at'], 'এজেন্টকে ' . rh_taka($p['taka'] ?? 0), ($agents[$p['agentId'] ?? '']['name'] ?? '') . ' · ' . rh_pay_way($p['way'] ?? ''), 0.0, (float) $p['sar'], 'payment', (int) ($p['by'] ?? 0), (string) ($p['byName'] ?? '')];
        }
    }
    if ($by !== null) {
        foreach (rh_all('handover') as $h) {
            if ((int) ($h['from'] ?? 0) === (int) $by) {
                $out[] = [$h['at'], ($h['toName'] ?? '') . '-কে দিলাম', 'হাতবদল' . (($h['note'] ?? '') !== '' ? ' · ' . $h['note'] : ''), 0.0, (float) $h['sar'], 'handover', (int) $by, (string) ($h['fromName'] ?? '')];
            }
            if ((int) ($h['to'] ?? 0) === (int) $by) {
                $out[] = [$h['at'], ($h['fromName'] ?? '') . '-এর কাছ থেকে বুঝে নিলাম', 'হাতবদল' . (($h['note'] ?? '') !== '' ? ' · ' . $h['note'] : ''), (float) $h['sar'], 0.0, 'handover', (int) $by, (string) ($h['toName'] ?? '')];
            }
        }
    }
    $txns = rh_all('txn');
    foreach (rh_all('adjust') as $x) {
        $v = (float) ($x['sarCash'] ?? 0);
        // An admin's mistake goes into that admin's hand (handBy).
        if (($x['handByName'] ?? '') !== '') {
            $x['by'] = (int) ($x['handBy'] ?? 0);
            $x['byName'] = (string) $x['handByName'];
        }
        if (!empty($x['applied']) && abs($v) >= 0.005 && $mine($x)) {
            $no = $txns[$x['txnId'] ?? '']['no'] ?? '';
            $out[] = [$x['appliedAt'] ?? $x['at'], 'অতিরিক্ত হিসাব' . ($no !== '' ? ' · #' . rh_bn($no) : ''), (string) ($x['note'] ?? ''), max(0, $v), max(0, -$v), 'adjust', (int) ($x['by'] ?? 0), (string) ($x['byName'] ?? '')];
        }
    }
    foreach (rh_all('close') as $c) {
        $d = (float) ($c['counted'] ?? 0) - (float) ($c['expected'] ?? 0);
        if (abs($d) >= 0.005 && $mine($c)) {
            $out[] = [$c['at'], 'দিন শেষে গুনে ' . ($d > 0 ? 'বেশি' : 'কম'), (string) ($c['note'] ?? ''), max(0, $d), max(0, -$d), 'close', (int) ($c['by'] ?? 0), (string) ($c['byName'] ?? '')];
        }
    }
    usort($out, fn($a, $b) => strcmp((string) $a[0], (string) $b[0]));
    return $out;
}

function rh_cash_in_hand($by = null) {
    return round(array_sum(array_map(fn($l) => $l[3] - $l[4], rh_cash_lines($by))), 2);
}

/** Admins seen in the records: id => name (0 = before the server). */
function rh_admins_in() {
    $out = [];
    foreach (['txn', 'deposit', 'expense', 'payment', 'close', 'loss', 'adjust'] as $k) {
        foreach (rh_all($k) as $r) {
            $id = (int) ($r['by'] ?? 0);
            if (!isset($out[$id]) || $out[$id] === '') {
                $out[$id] = $id === 0 ? 'মূল হিসাব (সার্ভারের আগের)' : (string) ($r['byName'] ?? '');
            }
        }
    }
    foreach (rh_all('handover') as $h) {
        $out[(int) $h['from']] = $out[(int) $h['from']] ?? (string) $h['fromName'];
        $out[(int) $h['to']] = $out[(int) $h['to']] ?? (string) $h['toName'];
    }
    return $out;
}

/** The main admin's name, which the whole account goes by. */
function rh_owner_name() {
    $s = rh_one('settings', 'main');
    $n = trim((string) ($s['ownerName'] ?? ''));
    if ($n === '') {
        global $wpdb;
        $n = (string) $wpdb->get_var('SELECT name FROM ' . rh_t('users') . " WHERE role = 'owner' LIMIT 1");
    }
    return $n !== '' ? $n : 'মূল এডমিন';
}

function rh_kind_name($t) {
    $kinds = ['send' => 'সেন্ড মানি', 'cashout' => 'ক্যাশ আউট', 'recharge' => 'মোবাইল রিচার্জ', 'mb' => 'এমবি প্যাক'];
    return $kinds[$t['kind'] ?? 'send'] ?? 'সেন্ড মানি';
}

function rh_method_name($m) {
    return ['bkash' => 'বিকাশ', 'nagad' => 'নগদ', 'rocket' => 'রকেট', 'bank' => 'ব্যাংক'][$m] ?? 'বিকাশ';
}

/** "বিকাশ", "রিচার্জ · রবি", "এমবি · রবি". */
function rh_service($t) {
    $k = $t['kind'] ?? 'send';
    if ($k === 'recharge' || $k === 'mb') {
        return ($k === 'mb' ? 'এমবি' : 'রিচার্জ') . (($t['operator'] ?? '') !== '' ? ' · ' . $t['operator'] : '');
    }
    return rh_method_name($t['method'] ?? 'bkash');
}

function rh_pay_way($w) {
    return ['bank' => 'ব্যাংক', 'bkash' => 'বিকাশ', 'nagad' => 'নগদ (অ্যাপ)', 'cash' => 'হাতে নগদ', 'hundi' => 'অন্যের মাধ্যমে', 'other' => 'অন্যভাবে'][$w] ?? $w;
}
