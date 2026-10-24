<?php
/**
 * ফ্যামিলি (Pro): members join each other by e-mail, with how they are
 * related and what each one lets the other do — add a to-do, a reminder, a
 * medicine reminder or a note for them, see their live location, be their
 * heir. Everything one sends the other is sealed on the phone with the other
 * phone's public key (X25519 + AES-GCM): this server keeps and passes on
 * only what it cannot read — never a medicine, a note, a place or a password.
 *
 * Heirs: a member names heirs among their family and chooses what they may
 * see; the phone keeps a sealed copy of just that here. An heir sees it when
 * the member gives access now, or after a death is reported with a document,
 * checked by an admin (site page or admin app), and 14 days pass without the
 * member cancelling.
 */

if (!defined('ABSPATH')) {
    exit;
}

const MA_FAM_PERMS = ['task', 'reminder', 'medicine', 'note', 'location'];
const MA_FAM_WAIT_DAYS = 14;
const MA_FAM_MAX_PACKAGE = 8 * 1024 * 1024;
const MA_FAM_MAX_ITEM = 64 * 1024;
const MA_FAM_MAX_FILE = 6 * 1024 * 1024;

function ma_fam_table($t) {
    global $wpdb;
    return $wpdb->prefix . 'ma_fam_' . $t;
}

function ma_fam_install() {
    global $wpdb;
    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    $cs = $wpdb->get_charset_collate();
    dbDelta('CREATE TABLE ' . ma_fam_table('keys') . " (
        user_id bigint(20) unsigned NOT NULL,
        pubkey varchar(64) NOT NULL,
        updated_at datetime NOT NULL,
        PRIMARY KEY  (user_id)
    ) $cs;");
    // One row per pair; side a invited side b. Each side's grants are what it lets the OTHER do.
    dbDelta('CREATE TABLE ' . ma_fam_table('links') . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        a_user bigint(20) unsigned NOT NULL,
        b_user bigint(20) unsigned NULL DEFAULT NULL,
        b_email varchar(190) NOT NULL,
        a_calls_b varchar(60) NOT NULL DEFAULT '',
        b_calls_a varchar(60) NOT NULL DEFAULT '',
        a_grants varchar(255) NOT NULL DEFAULT '',
        b_grants varchar(255) NOT NULL DEFAULT '',
        a_heir_b tinyint(1) NOT NULL DEFAULT 0,
        b_heir_a tinyint(1) NOT NULL DEFAULT 0,
        a_open_b tinyint(1) NOT NULL DEFAULT 0,
        b_open_a tinyint(1) NOT NULL DEFAULT 0,
        status varchar(12) NOT NULL DEFAULT 'pending',
        created_at datetime NOT NULL,
        updated_at datetime NOT NULL,
        PRIMARY KEY  (id),
        KEY a_user (a_user),
        KEY b_user (b_user),
        KEY b_email (b_email)
    ) $cs;");
    dbDelta('CREATE TABLE ' . ma_fam_table('items') . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        to_user bigint(20) unsigned NOT NULL,
        from_user bigint(20) unsigned NOT NULL,
        link_id bigint(20) unsigned NOT NULL,
        kind varchar(12) NOT NULL,
        sealed mediumtext NOT NULL,
        created_at datetime NOT NULL,
        PRIMARY KEY  (id),
        KEY to_user (to_user)
    ) $cs;");
    dbDelta('CREATE TABLE ' . ma_fam_table('places') . " (
        user_id bigint(20) unsigned NOT NULL,
        sealed text NOT NULL,
        at datetime NOT NULL,
        asked_at datetime NULL DEFAULT NULL,
        PRIMARY KEY  (user_id)
    ) $cs;");
    dbDelta('CREATE TABLE ' . ma_fam_table('packages') . " (
        owner_id bigint(20) unsigned NOT NULL,
        file_key varchar(64) NOT NULL,
        size int unsigned NOT NULL DEFAULT 0,
        keys_json mediumtext NOT NULL,
        updated_at datetime NOT NULL,
        PRIMARY KEY  (owner_id)
    ) $cs;");
    // Photos and files of the heirs' copy, each sealed on the phone with the copy's file key.
    dbDelta('CREATE TABLE ' . ma_fam_table('files') . " (
        owner_id bigint(20) unsigned NOT NULL,
        file_id varchar(40) NOT NULL,
        file_key varchar(64) NOT NULL,
        size int unsigned NOT NULL DEFAULT 0,
        created_at datetime NOT NULL,
        PRIMARY KEY  (owner_id, file_id)
    ) $cs;");
    dbDelta('CREATE TABLE ' . ma_fam_table('claims') . " (
        id bigint(20) unsigned NOT NULL AUTO_INCREMENT,
        owner_id bigint(20) unsigned NOT NULL,
        heir_id bigint(20) unsigned NOT NULL,
        note varchar(1000) NOT NULL DEFAULT '',
        file_key varchar(64) NOT NULL DEFAULT '',
        file_name varchar(190) NOT NULL DEFAULT '',
        file_mime varchar(64) NOT NULL DEFAULT '',
        status varchar(12) NOT NULL DEFAULT 'review',
        open_at datetime NULL DEFAULT NULL,
        admin_note varchar(500) NOT NULL DEFAULT '',
        reviewer_id bigint(20) unsigned NOT NULL DEFAULT 0,
        created_at datetime NOT NULL,
        updated_at datetime NOT NULL,
        PRIMARY KEY  (id),
        KEY owner_id (owner_id),
        KEY status (status)
    ) $cs;");
}

function ma_fam_now() {
    return current_time('mysql', true);
}

function ma_fam_perms($v) {
    $out = [];
    foreach ((array) $v as $p) {
        $p = sanitize_key((string) $p);
        if (in_array($p, MA_FAM_PERMS, true) && !in_array($p, $out, true)) {
            $out[] = $p;
        }
    }
    return $out;
}

function ma_fam_csv($s) {
    return array_values(array_filter(explode(',', (string) $s)));
}

/** The link as seen by $me: who the other is, what each lets the other do. */
function ma_fam_side($l, $me) {
    $a = (int) $l['a_user'] === (int) $me;
    return [
        'me_a' => $a,
        'other' => $a ? (int) $l['b_user'] : (int) $l['a_user'],
        'i_call' => $a ? $l['a_calls_b'] : $l['b_calls_a'],
        'they_call' => $a ? $l['b_calls_a'] : $l['a_calls_b'],
        'i_allow' => ma_fam_csv($a ? $l['a_grants'] : $l['b_grants']),
        'they_allow' => ma_fam_csv($a ? $l['b_grants'] : $l['a_grants']),
        'they_are_my_heir' => (bool) ($a ? $l['a_heir_b'] : $l['b_heir_a']),
        'i_am_their_heir' => (bool) ($a ? $l['b_heir_a'] : $l['a_heir_b']),
        'i_opened' => (bool) ($a ? $l['a_open_b'] : $l['b_open_a']),
        'they_opened' => (bool) ($a ? $l['b_open_a'] : $l['a_open_b']),
    ];
}

function ma_fam_user($id) {
    global $wpdb;
    return $id ? $wpdb->get_row($wpdb->prepare('SELECT id, name, email, pro_until FROM ' . ma_acc_table() . ' WHERE id = %d', $id), ARRAY_A) : null;
}

function ma_fam_pubkey($user_id) {
    global $wpdb;
    return (string) $wpdb->get_var($wpdb->prepare('SELECT pubkey FROM ' . ma_fam_table('keys') . ' WHERE user_id = %d', $user_id));
}

/** Links of a member (pending invites to their e-mail included, joined to them on the way). */
function ma_fam_links_of($row) {
    global $wpdb;
    $t = ma_fam_table('links');
    $wpdb->query($wpdb->prepare("UPDATE $t SET b_user = %d WHERE b_user IS NULL AND b_email = %s", $row['id'], strtolower($row['email'])));
    return $wpdb->get_results($wpdb->prepare("SELECT * FROM $t WHERE (a_user = %d OR b_user = %d) AND status IN ('pending', 'active') ORDER BY id", $row['id'], $row['id']), ARRAY_A) ?: [];
}

function ma_fam_link_for($row, $id) {
    foreach (ma_fam_links_of($row) as $l) {
        if ((int) $l['id'] === (int) $id) {
            return $l;
        }
    }
    return null;
}

/** The claim that decides whether an heir may open a package now. */
function ma_fam_open_claim($owner_id, $heir_id) {
    global $wpdb;
    return $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_fam_table('claims') . " WHERE owner_id = %d AND heir_id = %d AND status IN ('review', 'waiting', 'open') ORDER BY id DESC LIMIT 1", $owner_id, $heir_id), ARRAY_A);
}

function ma_fam_claim_state($c) {
    if (!$c) {
        return null;
    }
    $st = $c['status'];
    if ($st === 'waiting' && ma_acc_ts($c['open_at']) <= time()) {
        $st = 'open';
    }
    return ['id' => (int) $c['id'], 'status' => $st, 'open_at' => $c['open_at'] ? gmdate('c', ma_acc_ts($c['open_at'])) : null, 'admin_note' => $c['admin_note']];
}

function ma_fam_link_json($l, $me) {
    global $wpdb;
    $s = ma_fam_side($l, $me);
    $o = ma_fam_user($s['other']);
    $incoming = !$s['me_a'] && $l['status'] === 'pending';
    $pkg = $s['other'] ? $wpdb->get_row($wpdb->prepare('SELECT updated_at, size FROM ' . ma_fam_table('packages') . ' WHERE owner_id = %d', $s['other']), ARRAY_A) : null;
    $claim = $s['i_am_their_heir'] ? ma_fam_claim_state(ma_fam_open_claim($s['other'], $me)) : null;
    return [
        'id' => (int) $l['id'],
        'status' => $l['status'],
        'incoming' => $incoming,
        'name' => $o ? ($o['name'] ?: $o['email']) : $l['b_email'],
        'email' => $o ? $o['email'] : $l['b_email'],
        'member' => (bool) $o,
        'i_call' => $s['i_call'],
        'they_call' => $s['they_call'],
        'i_allow' => $s['i_allow'],
        'they_allow' => $s['they_allow'],
        'they_are_my_heir' => $s['they_are_my_heir'],
        'i_am_their_heir' => $s['i_am_their_heir'],
        'i_opened' => $s['i_opened'],
        'they_opened' => $s['they_opened'],
        'their_key' => $l['status'] === 'active' && $s['other'] ? ma_fam_pubkey($s['other']) : '',
        'package' => $s['i_am_their_heir'] && $pkg ? ['at' => gmdate('c', ma_acc_ts($pkg['updated_at'])), 'size' => (int) $pkg['size']] : null,
        'claim' => $claim,
        'can_open' => $s['i_am_their_heir'] && $pkg && ($s['they_opened'] || ($claim && $claim['status'] === 'open')),
    ];
}

function ma_fam_member(WP_REST_Request $req) {
    $row = ma_ai_member($req);
    return $row ?: new WP_Error('session', 'sign in again', ['status' => 401]);
}

function ma_fam_pro_needed($row) {
    return ma_nlu_is_pro($row) ? null : new WP_Error('pro', 'this part of family is a Premium feature', ['status' => 402]);
}

/**
 * Owner, 24 Oct: joining, inviting and sending tasks, reminders, medicine
 * reminders and notes are free; heirs, full access now and showing one's
 * location are Premium. Without Premium, 'location' is left out.
 */
function ma_fam_free_perms($row, array $perms) {
    return ma_nlu_is_pro($row) ? $perms : array_values(array_filter($perms, fn($x) => $x !== 'location'));
}

function ma_fam_body(WP_REST_Request $req) {
    $j = json_decode($req->get_body(), true);
    return is_array($j) ? $j : [];
}

function ma_fam_overview($row) {
    global $wpdb;
    $links = array_map(fn($l) => ma_fam_link_json($l, (int) $row['id']), ma_fam_links_of($row));
    // Someone reported this member's death: shown to them (so a living member can stop it).
    $against = $wpdb->get_results($wpdb->prepare('SELECT c.*, u.name, u.email FROM ' . ma_fam_table('claims') . ' c JOIN ' . ma_acc_table() . " u ON u.id = c.heir_id WHERE c.owner_id = %d AND c.status IN ('review', 'waiting')", $row['id']), ARRAY_A) ?: [];
    return [
        'pro' => ma_nlu_is_pro($row),
        'my_key' => ma_fam_pubkey((int) $row['id']),
        'links' => $links,
        'items' => (int) $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . ma_fam_table('items') . ' WHERE to_user = %d', $row['id'])),
        'claims_on_me' => array_map(fn($c) => ['id' => (int) $c['id'], 'by' => $c['name'] ?: $c['email'], 'status' => $c['status'], 'open_at' => $c['open_at'] ? gmdate('c', ma_acc_ts($c['open_at'])) : null], $against),
        'perms' => MA_FAM_PERMS,
    ];
}

add_action('rest_api_init', function () {
    $r = function ($path, $method, $cb) {
        register_rest_route('my-assistant/v1', $path, ['methods' => $method, 'callback' => function (WP_REST_Request $req) use ($cb) {
            $row = ma_fam_member($req);
            return is_wp_error($row) ? $row : $cb($req, $row);
        }, 'permission_callback' => '__return_true']);
    };

    $r('/family', 'GET', function ($req, $row) {
        return ma_fam_overview($row);
    });

    // This phone's public key (X25519, base64): others seal for it.
    $r('/family/key', 'POST', function ($req, $row) {
        global $wpdb;
        $k = (string) (ma_fam_body($req)['pubkey'] ?? '');
        $raw = base64_decode($k, true);
        if ($raw === false || strlen($raw) !== 32) {
            return new WP_Error('bad', 'a 32-byte X25519 key', ['status' => 400]);
        }
        $wpdb->replace(ma_fam_table('keys'), ['user_id' => (int) $row['id'], 'pubkey' => $k, 'updated_at' => ma_fam_now()]);
        return ['ok' => true];
    });

    $r('/family/invite', 'POST', function ($req, $row) {
        global $wpdb;
        $in = ma_fam_body($req);
        $email = strtolower(sanitize_email((string) ($in['email'] ?? '')));
        if (!is_email($email) || $email === strtolower($row['email'])) {
            return new WP_Error('email', 'a valid e-mail of someone else', ['status' => 400]);
        }
        $t = ma_fam_table('links');
        $n = (int) $wpdb->get_var($wpdb->prepare("SELECT COUNT(*) FROM $t WHERE (a_user = %d OR b_user = %d) AND status IN ('pending', 'active')", $row['id'], $row['id']));
        if ($n >= 20) {
            return new WP_Error('many', 'at most 20 family members', ['status' => 429]);
        }
        $other = $wpdb->get_row($wpdb->prepare('SELECT id FROM ' . ma_acc_table() . ' WHERE email = %s', $email), ARRAY_A);
        $dup = $wpdb->get_var($wpdb->prepare("SELECT id FROM $t WHERE status IN ('pending', 'active') AND ((a_user = %d AND b_email = %s) OR (b_user = %d AND a_user = %d))", $row['id'], $email, $row['id'], (int) ($other['id'] ?? 0)));
        if ($dup) {
            return new WP_Error('exists', 'already in your family', ['status' => 409]);
        }
        $wpdb->insert($t, [
            'a_user' => (int) $row['id'], 'b_user' => $other ? (int) $other['id'] : null, 'b_email' => $email,
            'a_calls_b' => mb_substr(sanitize_text_field((string) ($in['relation'] ?? '')), 0, 60),
            'a_grants' => implode(',', ma_fam_perms($in['allow'] ?? [])),
            'status' => 'pending', 'created_at' => ma_fam_now(), 'updated_at' => ma_fam_now(),
        ]);
        if ($other) {
            ma_push_member((int) $other['id'], 'ফ্যামিলিতে যুক্ত হওয়ার অনুরোধ', ($row['name'] ?: $row['email']) . ' আপনাকে ফ্যামিলিতে যুক্ত করতে চান', ['type' => 'family']);
        }
        return ma_fam_overview($row);
    });

    $r('/family/(?P<id>\d+)/(?P<what>accept|decline|remove)', 'POST', function ($req, $row) {
        global $wpdb;
        $l = ma_fam_link_for($row, (int) $req['id']);
        if (!$l) {
            return new WP_Error('none', 'not found', ['status' => 404]);
        }
        $in = ma_fam_body($req);
        $what = $req['what'];
        $t = ma_fam_table('links');
        if ($what === 'accept') {
            if ((int) $l['a_user'] === (int) $row['id'] || $l['status'] !== 'pending') {
                return new WP_Error('bad', 'only the one invited accepts', ['status' => 400]);
            }
            $wpdb->update($t, ['status' => 'active', 'b_user' => (int) $row['id'], 'b_calls_a' => mb_substr(sanitize_text_field((string) ($in['relation'] ?? '')), 0, 60), 'b_grants' => implode(',', ma_fam_free_perms($row, ma_fam_perms($in['allow'] ?? []))), 'updated_at' => ma_fam_now()], ['id' => $l['id']]);
            ma_push_member((int) $l['a_user'], 'ফ্যামিলিতে যুক্ত হয়েছেন', ($row['name'] ?: $row['email']) . ' আপনার অনুরোধ মেনে নিয়েছেন', ['type' => 'family']);
        } else {
            // Declined or removed: nothing sent between them stays.
            $wpdb->update($t, ['status' => $what === 'decline' ? 'declined' : 'removed', 'a_heir_b' => 0, 'b_heir_a' => 0, 'a_open_b' => 0, 'b_open_a' => 0, 'updated_at' => ma_fam_now()], ['id' => $l['id']]);
            $wpdb->delete(ma_fam_table('items'), ['link_id' => $l['id']]);
        }
        return ma_fam_overview($row);
    });

    // What I let the other one do, whether they are my heir, and whether they may open my copy now.
    $r('/family/(?P<id>\d+)/allow', 'POST', function ($req, $row) {
        global $wpdb;
        $l = ma_fam_link_for($row, (int) $req['id']);
        if (!$l || $l['status'] !== 'active') {
            return new WP_Error('none', 'not found', ['status' => 404]);
        }
        $in = ma_fam_body($req);
        $a = (int) $l['a_user'] === (int) $row['id'];
        $p = $a ? 'a' : 'b';
        $o = $a ? 'b' : 'a';
        $set = ['updated_at' => ma_fam_now()];
        if (isset($in['allow'])) {
            $want = ma_fam_perms($in['allow']);
            $had = explode(',', (string) ($l[$p . '_grants'] ?? ''));
            if (in_array('location', $want, true) && !in_array('location', $had, true) && ($e = ma_fam_pro_needed($row))) {
                return $e;
            }
            $set[$p . '_grants'] = implode(',', $want);
        }
        if (((!empty($in['heir']) && !(int) $l[$p . '_heir_' . $o]) || (!empty($in['open_now']) && !(int) $l[$p . '_open_' . $o])) && ($e = ma_fam_pro_needed($row))) {
            return $e;
        }
        if (isset($in['relation'])) {
            $set[$p . '_calls_' . $o] = mb_substr(sanitize_text_field((string) $in['relation']), 0, 60);
        }
        if (isset($in['heir'])) {
            $set[$p . '_heir_' . $o] = $in['heir'] ? 1 : 0;
            if (!$in['heir']) {
                $set[$p . '_open_' . $o] = 0;
            }
        }
        if (isset($in['open_now'])) {
            $set[$p . '_open_' . $o] = !empty($in['open_now']) && (!empty($in['heir']) || (int) $l[$p . '_heir_' . $o]) ? 1 : 0;
        }
        $wpdb->update(ma_fam_table('links'), $set, ['id' => $l['id']]);
        return ma_fam_overview($row);
    });

    // Something sealed for a family member: a to-do, a reminder, a medicine reminder, a note — or the location key.
    $r('/family/items', 'POST', function ($req, $row) {
        global $wpdb;
        $in = ma_fam_body($req);
        // Sending things is free; the location key (sharing where I am) is Premium.
        if (sanitize_key((string) ($in['kind'] ?? '')) === 'lockey' && ($e = ma_fam_pro_needed($row))) {
            return $e;
        }
        $l = ma_fam_link_for($row, (int) ($in['link'] ?? 0));
        $kind = sanitize_key((string) ($in['kind'] ?? ''));
        $sealed = (string) ($in['sealed'] ?? '');
        if (!$l || $l['status'] !== 'active') {
            return new WP_Error('none', 'not in your family', ['status' => 404]);
        }
        if ($sealed === '' || strlen($sealed) > MA_FAM_MAX_ITEM || base64_decode($sealed, true) === false) {
            return new WP_Error('bad', 'a sealed item', ['status' => 400]);
        }
        $s = ma_fam_side($l, (int) $row['id']);
        // The location key is sent by the one who shares their location; everything else needs the other's permission.
        $ok = $kind === 'lockey' ? in_array('location', $s['i_allow'], true) : in_array($kind, $s['they_allow'], true);
        if (!$ok) {
            return new WP_Error('perm', 'they have not allowed this', ['status' => 403]);
        }
        $wpdb->insert(ma_fam_table('items'), ['to_user' => $s['other'], 'from_user' => (int) $row['id'], 'link_id' => (int) $l['id'], 'kind' => $kind, 'sealed' => $sealed, 'created_at' => ma_fam_now()]);
        $what = ['task' => 'একটা কাজ', 'reminder' => 'একটা রিমাইন্ডার', 'medicine' => 'ওষুধের রিমাইন্ডার', 'note' => 'একটা নোট'][$kind] ?? '';
        if ($what !== '') {
            ma_push_member($s['other'], 'ফ্যামিলি থেকে', ($s['they_call'] !== '' ? $s['they_call'] : ($row['name'] ?: 'পরিবারের একজন')) . " আপনার জন্য $what দিয়েছেন", ['type' => 'family_item']);
        } else {
            ma_push_member($s['other'], '', '', ['type' => 'family_item']);
        }
        return ['ok' => true];
    });

    $r('/family/items', 'GET', function ($req, $row) {
        global $wpdb;
        $rows = $wpdb->get_results($wpdb->prepare('SELECT id, link_id, kind, sealed, created_at FROM ' . ma_fam_table('items') . ' WHERE to_user = %d ORDER BY id LIMIT 100', $row['id']), ARRAY_A) ?: [];
        return ['items' => array_map(fn($x) => ['id' => (int) $x['id'], 'link' => (int) $x['link_id'], 'kind' => $x['kind'], 'sealed' => $x['sealed'], 'at' => gmdate('c', ma_acc_ts($x['created_at']))], $rows)];
    });

    $r('/family/items/ack', 'POST', function ($req, $row) {
        global $wpdb;
        $ids = array_map('intval', (array) (ma_fam_body($req)['ids'] ?? []));
        foreach (array_slice($ids, 0, 200) as $id) {
            $wpdb->delete(ma_fam_table('items'), ['id' => $id, 'to_user' => (int) $row['id']]);
        }
        return ['ok' => true];
    });

    // Live location: a family member asks; the phone answers by itself (sealed with the shared location key).
    $r('/family/(?P<id>\d+)/locate', 'POST', function ($req, $row) {
        global $wpdb;
        $l = ma_fam_link_for($row, (int) $req['id']);
        if (!$l || $l['status'] !== 'active') {
            return new WP_Error('none', 'not found', ['status' => 404]);
        }
        $s = ma_fam_side($l, (int) $row['id']);
        if (!in_array('location', $s['they_allow'], true)) {
            return new WP_Error('perm', 'they have not shared their location', ['status' => 403]);
        }
        $last = $wpdb->get_row($wpdb->prepare('SELECT asked_at FROM ' . ma_fam_table('places') . ' WHERE user_id = %d', $s['other']), ARRAY_A);
        if (!$last || ma_acc_ts($last['asked_at'] ?? null) < time() - 30) {
            $wpdb->query($wpdb->prepare('INSERT INTO ' . ma_fam_table('places') . " (user_id, sealed, at, asked_at) VALUES (%d, '', %s, %s) ON DUPLICATE KEY UPDATE asked_at = VALUES(asked_at)", $s['other'], '1970-01-01 00:00:00', ma_fam_now()));
            ma_push_member($s['other'], '', '', ['type' => 'locate']);
        }
        return ['ok' => true];
    });

    $r('/family/location', 'POST', function ($req, $row) {
        global $wpdb;
        $sealed = (string) (ma_fam_body($req)['sealed'] ?? '');
        if ($sealed === '' || strlen($sealed) > 2048 || base64_decode($sealed, true) === false) {
            return new WP_Error('bad', 'sealed', ['status' => 400]);
        }
        $wpdb->query($wpdb->prepare('INSERT INTO ' . ma_fam_table('places') . ' (user_id, sealed, at) VALUES (%d, %s, %s) ON DUPLICATE KEY UPDATE sealed = VALUES(sealed), at = VALUES(at)', $row['id'], $sealed, ma_fam_now()));
        return ['ok' => true];
    });

    $r('/family/(?P<id>\d+)/location', 'GET', function ($req, $row) {
        global $wpdb;
        $l = ma_fam_link_for($row, (int) $req['id']);
        if (!$l || $l['status'] !== 'active') {
            return new WP_Error('none', 'not found', ['status' => 404]);
        }
        $s = ma_fam_side($l, (int) $row['id']);
        if (!in_array('location', $s['they_allow'], true)) {
            return new WP_Error('perm', 'they have not shared their location', ['status' => 403]);
        }
        $p = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_fam_table('places') . ' WHERE user_id = %d', $s['other']), ARRAY_A);
        return ['sealed' => $p ? $p['sealed'] : '', 'at' => $p && $p['sealed'] !== '' ? gmdate('c', ma_acc_ts($p['at'])) : null];
    });

    // The heirs' sealed copy: replaced whole; one content key, sealed for each heir.
    $r('/family/package', 'POST', function ($req, $row) {
        global $wpdb;
        $in = ma_fam_body($req);
        $bytes = base64_decode((string) ($in['blob'] ?? ''), true);
        if ($bytes === false || $bytes === '' || strlen($bytes) > MA_FAM_MAX_PACKAGE) {
            return new WP_Error('bad', 'a sealed copy up to 8 MB', ['status' => 400]);
        }
        // keys: family link id → the content key sealed for that heir (kept by the heir's member id).
        $given = (array) ($in['keys'] ?? []);
        $keys = [];
        foreach (ma_fam_links_of($row) as $l) {
            $s = ma_fam_side($l, (int) $row['id']);
            $k = $given[(string) $l['id']] ?? null;
            if ($l['status'] === 'active' && $s['they_are_my_heir'] && is_string($k) && strlen($k) < 400) {
                $keys[$s['other']] = $k;
            }
        }
        if (!$keys) {
            return new WP_Error('heirs', 'no heir named', ['status' => 400]);
        }
        $old = $wpdb->get_var($wpdb->prepare('SELECT file_key FROM ' . ma_fam_table('packages') . ' WHERE owner_id = %d', $row['id']));
        $key = bin2hex(random_bytes(32));
        if (file_put_contents(ma_fb_dir() . '/' . $key, $bytes) === false) {
            return new WP_Error('disk', 'could not save', ['status' => 500]);
        }
        $wpdb->replace(ma_fam_table('packages'), ['owner_id' => (int) $row['id'], 'file_key' => $key, 'size' => strlen($bytes), 'keys_json' => wp_json_encode($keys), 'updated_at' => ma_fam_now()]);
        // Files the copy no longer mentions go.
        if (isset($in['files']) && is_array($in['files'])) {
            $keep = array_flip(array_map('strval', $in['files']));
            foreach ($wpdb->get_results($wpdb->prepare('SELECT file_id, file_key FROM ' . ma_fam_table('files') . ' WHERE owner_id = %d', $row['id']), ARRAY_A) ?: [] as $f) {
                if (!isset($keep[$f['file_id']])) {
                    @unlink(ma_fb_dir() . '/' . $f['file_key']);
                    $wpdb->delete(ma_fam_table('files'), ['owner_id' => (int) $row['id'], 'file_id' => $f['file_id']]);
                }
            }
        }
        if ($old) {
            @unlink(ma_fb_dir() . '/' . $old);
        }
        return ['ok' => true, 'heirs' => count($keys)];
    });

    // One sealed photo or file for the heirs' copy (only while the member has an heir).
    $r('/family/files', 'POST', function ($req, $row) {
        global $wpdb;
        $in = ma_fam_body($req);
        $id = preg_replace('/[^A-Za-z0-9_\-]/', '', (string) ($in['id'] ?? ''));
        $bytes = base64_decode((string) ($in['blob'] ?? ''), true);
        if ($id === '' || strlen($id) > 40 || $bytes === false || $bytes === '' || strlen($bytes) > MA_FAM_MAX_FILE) {
            return new WP_Error('bad', 'a sealed file up to 6 MB', ['status' => 400]);
        }
        $heir = false;
        foreach (ma_fam_links_of($row) as $l) {
            $heir = $heir || ($l['status'] === 'active' && ma_fam_side($l, (int) $row['id'])['they_are_my_heir']);
        }
        if (!$heir) {
            return new WP_Error('heirs', 'no heir named', ['status' => 400]);
        }
        $n = (int) $wpdb->get_var($wpdb->prepare('SELECT COUNT(*) FROM ' . ma_fam_table('files') . ' WHERE owner_id = %d', $row['id']));
        $old = $wpdb->get_var($wpdb->prepare('SELECT file_key FROM ' . ma_fam_table('files') . ' WHERE owner_id = %d AND file_id = %s', $row['id'], $id));
        if (!$old && $n >= 2000) {
            return new WP_Error('many', 'too many files', ['status' => 429]);
        }
        $key = bin2hex(random_bytes(32));
        if (file_put_contents(ma_fb_dir() . '/' . $key, $bytes) === false) {
            return new WP_Error('disk', 'could not save', ['status' => 500]);
        }
        if ($old) {
            @unlink(ma_fb_dir() . '/' . $old);
        }
        $wpdb->replace(ma_fam_table('files'), ['owner_id' => (int) $row['id'], 'file_id' => $id, 'file_key' => $key, 'size' => strlen($bytes), 'created_at' => ma_fam_now()]);
        return ['ok' => true];
    });

    $r('/family/(?P<id>\d+)/files/(?P<file>[A-Za-z0-9_\-]{1,40})', 'GET', function ($req, $row) {
        global $wpdb;
        $l = ma_fam_link_for($row, (int) $req['id']);
        if (!$l || !ma_fam_link_json($l, (int) $row['id'])['can_open']) {
            return new WP_Error('closed', 'not open to you', ['status' => 403]);
        }
        $s = ma_fam_side($l, (int) $row['id']);
        $k = $wpdb->get_var($wpdb->prepare('SELECT file_key FROM ' . ma_fam_table('files') . ' WHERE owner_id = %d AND file_id = %s', $s['other'], (string) $req['file']));
        $bytes = $k ? @file_get_contents(ma_fb_dir() . '/' . $k) : false;
        return $bytes === false ? new WP_Error('none', 'not uploaded yet', ['status' => 404]) : ['blob' => base64_encode($bytes)];
    });

    $r('/family/package', 'DELETE', function ($req, $row) {
        ma_fam_drop_package((int) $row['id']);
        return ['ok' => true];
    });

    $r('/family/(?P<id>\d+)/package', 'GET', function ($req, $row) {
        global $wpdb;
        $l = ma_fam_link_for($row, (int) $req['id']);
        if (!$l) {
            return new WP_Error('none', 'not found', ['status' => 404]);
        }
        $j = ma_fam_link_json($l, (int) $row['id']);
        if (!$j['can_open']) {
            return new WP_Error('closed', 'not open to you', ['status' => 403]);
        }
        $s = ma_fam_side($l, (int) $row['id']);
        $p = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_fam_table('packages') . ' WHERE owner_id = %d', $s['other']), ARRAY_A);
        $keys = json_decode((string) ($p['keys_json'] ?? ''), true) ?: [];
        $bytes = $p ? @file_get_contents(ma_fb_dir() . '/' . $p['file_key']) : false;
        if ($bytes === false || !isset($keys[(string) $row['id']])) {
            return new WP_Error('none', 'no copy for you', ['status' => 404]);
        }
        return ['blob' => base64_encode($bytes), 'key' => $keys[(string) $row['id']], 'at' => gmdate('c', ma_acc_ts($p['updated_at']))];
    });

    // A death reported by an heir, with a document; an admin checks it.
    $r('/family/(?P<id>\d+)/claim', 'POST', function ($req, $row) {
        global $wpdb;
        $l = ma_fam_link_for($row, (int) $req['id']);
        if (!$l || $l['status'] !== 'active') {
            return new WP_Error('none', 'not found', ['status' => 404]);
        }
        $s = ma_fam_side($l, (int) $row['id']);
        if (!$s['i_am_their_heir']) {
            return new WP_Error('perm', 'only an heir they chose', ['status' => 403]);
        }
        if (ma_fam_open_claim($s['other'], (int) $row['id'])) {
            return new WP_Error('exists', 'already reported', ['status' => 409]);
        }
        $file = ma_fb_file_param($req);
        if (is_wp_error($file)) {
            return $file;
        }
        if (!$file) {
            return new WP_Error('doc', 'a photo of the death certificate is needed', ['status' => 400]);
        }
        $wpdb->insert(ma_fam_table('claims'), [
            'owner_id' => $s['other'], 'heir_id' => (int) $row['id'], 'note' => mb_substr(sanitize_textarea_field((string) $req->get_param('note')), 0, 1000),
            'file_key' => $file['file_key'], 'file_name' => $file['file_name'], 'file_mime' => $file['file_mime'],
            'status' => 'review', 'created_at' => ma_fam_now(), 'updated_at' => ma_fam_now(),
        ]);
        ma_push_admins('উত্তরাধিকারের অনুরোধ', 'একজন সদস্যের ইন্তেকালের খবর এসেছে — কাগজ দেখে সিদ্ধান্ত দিন', ['type' => 'heir_claim']);
        return ma_fam_overview($row);
    });

    // The member (alive) or the heir stops a claim.
    $r('/family/claims/(?P<id>\d+)/cancel', 'POST', function ($req, $row) {
        global $wpdb;
        $c = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_fam_table('claims') . ' WHERE id = %d', (int) $req['id']), ARRAY_A);
        if (!$c || ((int) $c['owner_id'] !== (int) $row['id'] && (int) $c['heir_id'] !== (int) $row['id'])) {
            return new WP_Error('none', 'not found', ['status' => 404]);
        }
        $wpdb->update(ma_fam_table('claims'), ['status' => 'cancelled', 'updated_at' => ma_fam_now()], ['id' => $c['id']]);
        if ((int) $c['owner_id'] === (int) $row['id']) {
            ma_push_member((int) $c['heir_id'], 'উত্তরাধিকারের অনুরোধ বাতিল', 'অ্যাকাউন্টের মালিক নিজে অনুরোধটা বাতিল করেছেন', ['type' => 'family']);
        }
        return ma_fam_overview($row);
    });
});

function ma_fam_drop_package($owner_id) {
    global $wpdb;
    foreach ($wpdb->get_col($wpdb->prepare('SELECT file_key FROM ' . ma_fam_table('files') . ' WHERE owner_id = %d', $owner_id)) ?: [] as $k) {
        @unlink(ma_fb_dir() . '/' . $k);
    }
    $wpdb->delete(ma_fam_table('files'), ['owner_id' => $owner_id]);
    $old = $wpdb->get_var($wpdb->prepare('SELECT file_key FROM ' . ma_fam_table('packages') . ' WHERE owner_id = %d', $owner_id));
    if ($old) {
        @unlink(ma_fb_dir() . '/' . $old);
    }
    $wpdb->delete(ma_fam_table('packages'), ['owner_id' => $owner_id]);
}

// ── Admins: the same on the site page and in the admin app ──

function ma_fam_claims_list($status = 'review') {
    global $wpdb;
    $c = ma_fam_table('claims');
    $u = ma_acc_table();
    $where = $status === 'all' ? '1=1' : $wpdb->prepare('c.status = %s', $status);
    $rows = $wpdb->get_results("SELECT c.*, o.name owner_name, o.email owner_email, h.name heir_name, h.email heir_email FROM $c c JOIN $u o ON o.id = c.owner_id JOIN $u h ON h.id = c.heir_id WHERE $where ORDER BY c.id DESC LIMIT 100", ARRAY_A) ?: [];
    return array_map(function ($r) {
        global $wpdb;
        $rel = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_fam_table('links') . " WHERE status = 'active' AND ((a_user = %d AND b_user = %d) OR (a_user = %d AND b_user = %d))", $r['owner_id'], $r['heir_id'], $r['heir_id'], $r['owner_id']), ARRAY_A);
        $s = $rel ? ma_fam_side($rel, (int) $r['heir_id']) : null;
        return [
            'id' => (int) $r['id'], 'status' => ma_fam_claim_state($r)['status'], 'created' => gmdate('c', ma_acc_ts($r['created_at'])),
            'owner' => ['id' => (int) $r['owner_id'], 'name' => $r['owner_name'], 'email' => $r['owner_email']],
            'heir' => ['id' => (int) $r['heir_id'], 'name' => $r['heir_name'], 'email' => $r['heir_email'], 'relation' => $s ? $s['i_call'] : ''],
            'note' => $r['note'], 'file_name' => $r['file_name'], 'file_mime' => $r['file_mime'], 'has_file' => $r['file_key'] !== '',
            'open_at' => $r['open_at'] ? gmdate('c', ma_acc_ts($r['open_at'])) : null, 'admin_note' => $r['admin_note'],
        ];
    }, $rows);
}

function ma_fam_claims_pending() {
    global $wpdb;
    return (int) $wpdb->get_var('SELECT COUNT(*) FROM ' . ma_fam_table('claims') . " WHERE status = 'review'");
}

/** approve: the member is told, and the heir can open the copy after 14 days unless the member cancels. */
function ma_fam_claim_decide($id, $action, $note, $admin_id) {
    global $wpdb;
    $c = $wpdb->get_row($wpdb->prepare('SELECT * FROM ' . ma_fam_table('claims') . ' WHERE id = %d', (int) $id), ARRAY_A);
    if (!$c || $c['status'] !== 'review') {
        return new WP_Error('none', 'not waiting for a decision', ['status' => 404]);
    }
    $note = mb_substr(sanitize_text_field((string) $note), 0, 500);
    if ($action === 'approve') {
        $open = gmdate('Y-m-d H:i:s', time() + MA_FAM_WAIT_DAYS * DAY_IN_SECONDS);
        $wpdb->update(ma_fam_table('claims'), ['status' => 'waiting', 'open_at' => $open, 'admin_note' => $note, 'reviewer_id' => (int) $admin_id, 'updated_at' => ma_fam_now()], ['id' => $c['id']]);
        $owner = ma_fam_user((int) $c['owner_id']);
        ma_push_member((int) $c['owner_id'], 'আপনার অ্যাকাউন্ট নিয়ে জরুরি', 'আপনার উত্তরাধিকারী আপনার ইন্তেকালের খবর দিয়েছেন। ভুল হলে ১৪ দিনের মধ্যে অ্যাপ খুলে বাতিল করুন।', ['type' => 'heir_claim']);
        if ($owner && is_email($owner['email'])) {
            wp_mail($owner['email'], 'My Assistant: আপনার অ্যাকাউন্টে উত্তরাধিকারীর অনুরোধ', "আসসালামু আলাইকুম,\n\nআপনার বাছাই করা উত্তরাধিকারী জানিয়েছেন আপনি ইন্তেকাল করেছেন। আপনি যদি এটা পড়ছেন, অ্যাপ খুলে ফ্যামিলি পাতায় অনুরোধটা বাতিল করুন। ১৪ দিনের মধ্যে বাতিল না হলে আপনি যা দেখাতে বেছে রেখেছেন, তিনি তা দেখতে পাবেন।\n\nMy Assistant");
        }
        ma_push_member((int) $c['heir_id'], 'উত্তরাধিকারের অনুরোধ', 'কাগজ যাচাই হয়েছে। ১৪ দিন পর দেখতে পাবেন।', ['type' => 'family']);
    } elseif ($action === 'reject') {
        $wpdb->update(ma_fam_table('claims'), ['status' => 'rejected', 'admin_note' => $note, 'reviewer_id' => (int) $admin_id, 'updated_at' => ma_fam_now()], ['id' => $c['id']]);
        ma_push_member((int) $c['heir_id'], 'উত্তরাধিকারের অনুরোধ', 'অনুরোধটা মানা হয়নি' . ($note !== '' ? ': ' . $note : ''), ['type' => 'family']);
    } else {
        return new WP_Error('bad', 'approve or reject', ['status' => 400]);
    }
    return true;
}

function ma_fam_claim_file($id) {
    global $wpdb;
    $c = $wpdb->get_row($wpdb->prepare('SELECT file_key, file_name, file_mime FROM ' . ma_fam_table('claims') . ' WHERE id = %d', (int) $id), ARRAY_A);
    if (!$c || $c['file_key'] === '') {
        return null;
    }
    $bytes = @file_get_contents(ma_fb_dir() . '/' . $c['file_key']);
    return $bytes === false ? null : ['bytes' => $bytes, 'name' => $c['file_name'], 'mime' => $c['file_mime']];
}

add_action('rest_api_init', function () {
    ma_admin_route('/family/claims', 'GET', function (WP_REST_Request $req) {
        return ['claims' => ma_fam_claims_list(sanitize_key($req->get_param('status') ?: 'review'))];
    });
    ma_admin_route('/family/claims/(?P<id>\d+)', 'POST', function (WP_REST_Request $req) {
        $in = json_decode($req->get_body(), true) ?: [];
        $r = ma_fam_claim_decide((int) $req['id'], sanitize_key((string) ($in['action'] ?? '')), (string) ($in['note'] ?? ''), (int) ma_admin_of($req)['id']);
        return is_wp_error($r) ? $r : ['ok' => true];
    });
    ma_admin_route('/family/claims/(?P<id>\d+)/file', 'GET', function (WP_REST_Request $req) {
        $f = ma_fam_claim_file((int) $req['id']);
        return $f ? ['name' => $f['name'], 'mime' => $f['mime'], 'data' => base64_encode($f['bytes'])] : new WP_Error('none', 'no file', ['status' => 404]);
    });
});

add_action('admin_post_ma_fam_claim', function () {
    ma_acc_guard('ma_fam_claim');
    $r = ma_fam_claim_decide((int) ($_POST['claim'] ?? 0), sanitize_key($_POST['op'] ?? ''), wp_unslash($_POST['note'] ?? ''), get_current_user_id());
    ma_acc_back(is_wp_error($r) ? 'হলো না: ' . $r->get_error_message() : (($_POST['op'] ?? '') === 'approve' ? 'মানা হলো — সদস্যকে জানানো হয়েছে, ১৪ দিন পর উত্তরাধিকারী দেখতে পাবেন।' : 'অনুরোধ মানা হয়নি — উত্তরাধিকারীকে জানানো হয়েছে।'), is_wp_error($r) ? 'error' : 'ok', ['tab' => 'heirs']);
});

add_action('admin_post_ma_fam_file', function () {
    if (!current_user_can('ma_manage')) {
        wp_die('Not allowed', 403);
    }
    check_admin_referer('ma_fam_file');
    $f = ma_fam_claim_file((int) ($_GET['claim'] ?? 0));
    if (!$f) {
        wp_die('No file', 404);
    }
    nocache_headers();
    header('Content-Type: ' . $f['mime']);
    header('Content-Disposition: inline; filename="' . sanitize_file_name($f['name']) . '"');
    header('X-Content-Type-Options: nosniff');
    echo $f['bytes']; // phpcs:ignore
    exit;
});

/** A deleted member: their links, sealed items, location, heirs' copy and claims go too. */
function ma_fam_forget_member($user_id) {
    global $wpdb;
    $id = (int) $user_id;
    $wpdb->query($wpdb->prepare('DELETE FROM ' . ma_fam_table('links') . ' WHERE a_user = %d OR b_user = %d', $id, $id));
    $wpdb->query($wpdb->prepare('DELETE FROM ' . ma_fam_table('items') . ' WHERE to_user = %d OR from_user = %d', $id, $id));
    $wpdb->delete(ma_fam_table('places'), ['user_id' => $id]);
    $wpdb->delete(ma_fam_table('keys'), ['user_id' => $id]);
    ma_fam_drop_package($id);
    foreach ($wpdb->get_col($wpdb->prepare('SELECT file_key FROM ' . ma_fam_table('claims') . ' WHERE owner_id = %d OR heir_id = %d', $id, $id)) ?: [] as $k) {
        if ($k) {
            @unlink(ma_fb_dir() . '/' . $k);
        }
    }
    $wpdb->query($wpdb->prepare('DELETE FROM ' . ma_fam_table('claims') . ' WHERE owner_id = %d OR heir_id = %d', $id, $id));
}
