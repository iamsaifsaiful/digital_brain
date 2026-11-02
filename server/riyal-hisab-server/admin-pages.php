<?php
/**
 * The records, to look at only, in menus with filters. The one thing that can
 * be set here: the main admin's login and Firebase (settings tab). Everything
 * else is done from the app.
 */

if (!defined('ABSPATH')) {
    exit;
}

add_action('admin_menu', function () {
    add_menu_page('টাকাসেতু', 'টাকাসেতু', 'manage_options', 'riyal-hisab', 'rh_page', 'dashicons-money-alt', 3);
    foreach (rh_tabs() as $key => $label) {
        add_submenu_page('riyal-hisab', $label, $label, 'manage_options', $key === 'summary' ? 'riyal-hisab' : 'riyal-hisab-' . $key, 'rh_page');
    }
});

function rh_tabs() {
    return [
        'summary' => 'সারসংক্ষেপ',
        'txns' => 'লেনদেন',
        'customers' => 'গ্রাহক',
        'deposits' => 'রিয়াল জমা',
        'agents' => 'এজেন্ট',
        'payments' => 'এজেন্টকে দেওয়া',
        'cash' => 'হাতের হিসাব',
        'expenses' => 'খরচ',
        'losses' => 'লস',
        'closes' => 'দিন শেষ',
        'promises' => 'তাগাদা',
        'notes' => 'নোটিফিকেশন',
        'log' => 'কাজের লগ',
        'errors' => 'সমস্যার লগ',
        'users' => 'লগইন',
        'backup' => 'ব্যাকআপ',
        'settings' => 'সেটিংস',
    ];
}

function rh_tab_now() {
    $page = sanitize_key($_GET['page'] ?? 'riyal-hisab');
    $tab = $page === 'riyal-hisab' ? 'summary' : substr($page, strlen('riyal-hisab-'));
    return array_key_exists($tab, rh_tabs()) ? $tab : 'summary';
}

function rh_url($tab, $args = []) {
    return esc_url(add_query_arg(array_merge(['page' => $tab === 'summary' ? 'riyal-hisab' : 'riyal-hisab-' . $tab], $args), admin_url('admin.php')));
}

/** The filter values from the address. */
function rh_f($key, $default = '') {
    return isset($_GET[$key]) ? sanitize_text_field(wp_unslash($_GET[$key])) : $default;
}

function rh_date_ok($d) {
    return preg_match('/^\d{4}-\d{2}-\d{2}$/', $d) ? $d : '';
}

/** Records of a kind between the dates (from the filter), newest first. */
function rh_rows($kind) {
    global $wpdb;
    $from = rh_date_ok(rh_f('from'));
    $to = rh_date_ok(rh_f('to'));
    $sql = 'SELECT data FROM ' . rh_t('records') . ' WHERE kind = %s';
    $args = [$kind];
    if ($from !== '') {
        $sql .= ' AND at >= %s';
        $args[] = $from . ' 00:00:00';
    }
    if ($to !== '') {
        $sql .= ' AND at <= %s';
        $args[] = $to . ' 23:59:59';
    }
    $sql .= ' ORDER BY at DESC';
    $out = [];
    foreach ($wpdb->get_col($wpdb->prepare($sql, $args)) as $raw) {
        $d = json_decode($raw, true);
        if (is_array($d)) {
            $out[] = $d;
        }
    }
    return $out;
}

/** "২৫ অক্টো ২০২৬, রাত ১১:৫৮" from the app's local ISO time. */
function rh_when($iso, $time = true) {
    $ts = strtotime(str_replace('T', ' ', substr((string) $iso, 0, 19)));
    if (!$ts) {
        return '—';
    }
    $m = ['জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে'];
    $s = rh_bn(date('j', $ts)) . ' ' . $m[(int) date('n', $ts) - 1] . ' ' . rh_bn(date('Y', $ts));
    if ($time) {
        $h = (int) date('G', $ts);
        $part = $h < 4 ? 'রাত' : ($h < 6 ? 'ভোর' : ($h < 12 ? 'সকাল' : ($h < 15 ? 'দুপুর' : ($h < 18 ? 'বিকাল' : ($h < 20 ? 'সন্ধ্যা' : 'রাত')))));
        $s .= ', ' . $part . ' ' . rh_bn(((($h + 11) % 12) + 1) . ':' . date('i', $ts));
    }
    return $s;
}

function rh_search_hit($q, ...$fields) {
    if ($q === '') {
        return true;
    }
    $q = mb_strtolower(strtr($q, ['০' => '0', '১' => '1', '২' => '2', '৩' => '3', '৪' => '4', '৫' => '5', '৬' => '6', '৭' => '7', '৮' => '8', '৯' => '9']));
    foreach ($fields as $f) {
        if (mb_strpos(mb_strtolower((string) $f), ltrim($q, '#')) !== false) {
            return true;
        }
    }
    return false;
}

function rh_printing() {
    return !empty($_GET['print']);
}

/** "PDF / প্রিন্ট": the same list (with its filters) on a clean page that opens the print box — choose "Save as PDF". */
function rh_print_link($tab) {
    $args = array_map('sanitize_text_field', wp_unslash($_GET));
    unset($args['page'], $args['p']);
    $args['print'] = 1;
    printf('<a class="rh-btn rh-pdf" target="_blank" href="%s">PDF / প্রিন্ট</a>', rh_url($tab, $args));
}

/** Print mode: our page without the WordPress menus, then the print box. */
add_action('admin_init', function () {
    $page = sanitize_key($_GET['page'] ?? '');
    if (!rh_printing() || strpos($page, 'riyal-hisab') !== 0 || !current_user_can('manage_options')) {
        return;
    }
    $tab = rh_tab_now();
    if (in_array($tab, ['settings', 'backup'], true)) {
        return;
    }
    header('Content-Type: text/html; charset=utf-8');
    echo rh_print_page($tab);
    exit;
});

/** The print page of a tab, as HTML. */
function rh_print_page($tab) {
    ob_start();
    $title = rh_tabs()[$tab];
    $from = rh_date_ok(rh_f('from'));
    $to = rh_date_ok(rh_f('to'));
    $span = $from || $to ? ($from ? rh_when($from, false) : '…') . ' – ' . ($to ? rh_when($to, false) : '…') : 'সব সময়';
    echo '<!doctype html><html lang="bn"><head><meta charset="utf-8"><title>' . esc_html('টাকাসেতু — ' . $title) . '</title>';
    echo '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+Bengali:wght@400;600;700&display=swap">';
    rh_styles();
    echo '<style>body{background:#fff;margin:24px}.rh-filters,.rh-pager,.rh-pdf,.rh-link{display:none!important}.rh-table{font-size:12px}.rh-table th,.rh-table td{padding:6px}.rh-figs div,.rh-table{border:1px solid #ddd}@page{size:A4;margin:12mm}</style>';
    echo '</head><body class="rh"><h1 style="margin:0;color:#14284B">টাকাসেতু — ' . esc_html($title) . '</h1>';
    echo '<p class="rh-muted">' . esc_html($span . ' · তৈরি ' . rh_when(current_time('Y-m-d\TH:i:s'))) . '</p>';
    $fn = 'rh_tab_' . $tab;
    $fn();
    echo '<script>window.onload=function(){setTimeout(function(){window.print()},600)}</script></body></html>';
    return ob_get_clean();
}

/** Shows one page of a list; returns the rows of this page. */
function rh_paged(array $rows, &$pager) {
    $per = rh_printing() ? 100000 : 50;
    $page = max(1, (int) rh_f('p', 1));
    $total = count($rows);
    $pages = max(1, (int) ceil($total / $per));
    $page = min($page, $pages);
    $pager = ['page' => $page, 'pages' => $pages, 'total' => $total];
    return array_slice($rows, ($page - 1) * $per, $per);
}

function rh_pager_html($tab, $pager) {
    if ($pager['pages'] <= 1) {
        return;
    }
    $args = $_GET;
    unset($args['page']);
    echo '<div class="rh-pager">';
    for ($i = 1; $i <= $pager['pages']; $i++) {
        $args['p'] = $i;
        printf('<a class="%s" href="%s">%s</a>', $i === $pager['page'] ? 'on' : '', rh_url($tab, array_map('sanitize_text_field', $args)), esc_html(rh_bn($i)));
    }
    echo '</div>';
}

/** The filter bar: dates, search, and the tab's own selects. */
function rh_filters($tab, array $selects = [], $search = 'খুঁজুন') {
    $page = $tab === 'summary' ? 'riyal-hisab' : 'riyal-hisab-' . $tab;
    $from = rh_date_ok(rh_f('from'));
    $to = rh_date_ok(rh_f('to'));
    $today = current_time('Y-m-d');
    $quick = [
        'আজ' => [$today, $today],
        '৭ দিন' => [date('Y-m-d', strtotime($today . ' -6 days')), $today],
        'এই মাস' => [date('Y-m-01', strtotime($today)), $today],
        'গত মাস' => [date('Y-m-01', strtotime(date('Y-m-01', strtotime($today)) . ' -1 month')), date('Y-m-t', strtotime(date('Y-m-01', strtotime($today)) . ' -1 month'))],
    ];
    ?>
    <form class="rh-filters" method="get" action="<?php echo esc_url(admin_url('admin.php')); ?>">
        <input type="hidden" name="page" value="<?php echo esc_attr($page); ?>">
        <label>থেকে <input type="date" name="from" value="<?php echo esc_attr($from); ?>"></label>
        <label>পর্যন্ত <input type="date" name="to" value="<?php echo esc_attr($to); ?>"></label>
        <?php foreach ($selects as $name => [$label, $options]) : ?>
            <label><?php echo esc_html($label); ?>
                <select name="<?php echo esc_attr($name); ?>">
                    <?php foreach ($options as $val => $text) : ?>
                        <option value="<?php echo esc_attr($val); ?>" <?php selected(rh_f($name), (string) $val); ?>><?php echo esc_html($text); ?></option>
                    <?php endforeach; ?>
                </select>
            </label>
        <?php endforeach; ?>
        <?php if ($search !== '') : ?>
            <input type="search" name="q" placeholder="<?php echo esc_attr($search); ?>" value="<?php echo esc_attr(rh_f('q')); ?>">
        <?php endif; ?>
        <button class="rh-btn">দেখান</button>
        <a class="rh-link" href="<?php echo rh_url($tab); ?>">সব মুছুন</a>
        <?php rh_print_link($tab); ?>
        <span class="rh-quick">
            <?php foreach ($quick as $label => [$a, $b]) : ?>
                <a class="<?php echo $from === $a && $to === $b ? 'on' : ''; ?>" href="<?php echo rh_url($tab, ['from' => $a, 'to' => $b]); ?>"><?php echo esc_html($label); ?></a>
            <?php endforeach; ?>
        </span>
    </form>
    <?php
}

function rh_agent_options() {
    $o = ['' => 'সব এজেন্ট'];
    foreach (rh_all('agent') as $id => $a) {
        $o[$id] = (string) ($a['name'] ?? $id);
    }
    return $o;
}

function rh_page() {
    if (!current_user_can('manage_options')) {
        wp_die('অনুমতি নেই');
    }
    $tab = rh_tab_now();
    ?>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Noto+Sans+Bengali:wght@400;500;600;700&display=swap">
    <?php rh_styles(); ?>
    <div class="wrap rh">
        <h1 class="screen-reader-text">রিয়াল হিসাব</h1>
        <header class="rh-head">
            <div class="rh-brand"><span class="rh-mark">⇄</span><div><b>টাকাসেতু</b><em>সব রেকর্ড — শুধু দেখার জন্য; কাজ অ্যাপ থেকে</em></div></div>
            <nav class="rh-tabs">
                <?php foreach (rh_tabs() as $k => $label) : ?>
                    <a class="<?php echo $k === $tab ? 'on' : ''; ?>" href="<?php echo rh_url($k); ?>"><?php echo esc_html($label); ?></a>
                <?php endforeach; ?>
            </nav>
        </header>
        <?php if (isset($_GET['msg'])) : ?>
            <div class="rh-toast <?php echo ($_GET['t'] ?? '') === 'e' ? 'bad' : ''; ?>"><?php echo esc_html(sanitize_text_field(wp_unslash($_GET['msg']))); ?></div>
        <?php endif; ?>
        <?php
        $fn = 'rh_tab_' . $tab;
        $fn();
        ?>
    </div>
    <?php
}

function rh_tab_summary() {
    $txns = array_filter(rh_all('txn'), fn($t) => !rh_cancelled($t));
    $today = current_time('Y-m-d');
    $todayTx = array_filter($txns, fn($t) => substr((string) ($t['at'] ?? ''), 0, 10) === $today);
    $due = 0;
    $dueN = 0;
    foreach (rh_all('customer') as $id => $c) {
        $d = rh_customer_due($id);
        if ($d > 0) {
            $due += $d;
            $dueN++;
        }
    }
    $loss = array_sum(array_map(fn($l) => (float) ($l['sar'] ?? 0), rh_all('loss')));
    $waiting = count(array_filter($txns, fn($t) => ($t['status'] ?? '') === 'pending'));
    $wrong = count(array_filter($txns, fn($t) => !empty($t['fault'])));
    ?>
    <div class="rh-figs">
        <div><span>হাতে থাকা উচিত</span><strong><?php echo esc_html(rh_sar(rh_cash_in_hand())); ?></strong></div>
        <div><span>আজ পাঠানো</span><strong><?php echo esc_html(rh_sar(array_sum(array_map(fn($t) => (float) $t['sar'], $todayTx)))); ?></strong><em><?php echo esc_html(rh_bn(count($todayTx)) . 'টা লেনদেন · ' . rh_taka(array_sum(array_map(fn($t) => (float) $t['taka'], $todayTx)))); ?></em></div>
        <div><span>গ্রাহকের বাকি</span><strong class="red"><?php echo esc_html(rh_sar($due)); ?></strong><em><?php echo esc_html(rh_bn($dueN)); ?> জনের কাছে</em></div>
        <div><span>পাঠানোর অপেক্ষায়</span><strong><?php echo esc_html(rh_bn($waiting)); ?>টা</strong></div>
        <div><span>লস (আদায় হবে না)</span><strong class="red"><?php echo esc_html(rh_sar($loss)); ?></strong></div>
        <div><span>ভুল নম্বরে গেছে</span><strong><?php echo esc_html(rh_bn($wrong)); ?>টা</strong></div>
    </div>
    <h2 class="rh-h">এজেন্টদের হিসাব</h2>
    <table class="rh-table"><thead><tr><th>এজেন্ট</th><th>যোগাযোগ</th><th class="r">দিতে হবে</th></tr></thead><tbody>
        <?php foreach (rh_all('agent') as $id => $a) : $o = rh_agent_owed($id); ?>
            <tr><td><?php echo esc_html($a['name'] ?? ''); ?></td><td><?php echo esc_html(($a['channel'] ?? '') === 'app' ? 'অ্যাপে' : 'হোয়াটসঅ্যাপে'); ?></td><td class="r"><?php echo esc_html(($o < 0 ? 'অগ্রিম ' : '') . rh_taka(abs($o))); ?></td></tr>
        <?php endforeach; ?>
    </tbody></table>
    <?php
    rh_last_seen_note();
}

function rh_last_seen_note() {
    global $wpdb;
    $last = $wpdb->get_var('SELECT MAX(updated_at) FROM ' . rh_t('records'));
    echo '<p class="rh-muted">শেষ আপডেট: ' . esc_html($last ? rh_when(get_date_from_gmt($last, 'Y-m-d\TH:i:s')) : 'এখনো কিছু আসেনি') . '</p>';
}

function rh_status_label($t) {
    $s = $t['status'] ?? 'pending';
    return $s === 'cancelled' ? ['বাতিল', 'gray'] : ($s === 'sent' ? ['পৌঁছেছে', 'green'] : ['পাঠানোর অপেক্ষায়', 'red']);
}

function rh_tab_txns() {
    rh_filters('txns', [
        'status' => ['অবস্থা', ['' => 'সব', 'pending' => 'পাঠানোর অপেক্ষায়', 'sent' => 'পৌঁছেছে', 'cancelled' => 'বাতিল', 'due' => 'রিয়াল বাকি', 'fault' => 'ভুল নম্বর']],
        'kind' => ['ধরন', ['' => 'সব', 'money' => 'টাকা পাঠানো', 'recharge' => 'রিচার্জ', 'mb' => 'এমবি']],
        'agent' => ['এজেন্ট', rh_agent_options()],
        'by' => ['এডমিন', rh_admin_options()],
    ], 'নাম, নম্বর, #নং, TrxID');
    $customers = rh_all('customer');
    $agents = rh_all('agent');
    $q = rh_f('q');
    $rows = array_values(array_filter(rh_rows('txn'), function ($t) use ($q, $customers) {
        $st = rh_f('status');
        $k = rh_f('kind');
        if ($st === 'due' ? rh_due_at_send($t) <= 0 : ($st === 'fault' ? empty($t['fault']) : ($st !== '' && ($t['status'] ?? '') !== $st))) {
            return false;
        }
        $kind = $t['kind'] ?? 'send';
        if ($k === 'money' ? in_array($kind, ['recharge', 'mb'], true) : ($k !== '' && $kind !== $k)) {
            return false;
        }
        if (rh_f('agent') !== '' && ($t['agentId'] ?? '') !== rh_f('agent')) {
            return false;
        }
        if (rh_f('cust') !== '' && ($t['customerId'] ?? '') !== rh_f('cust')) {
            return false;
        }
        if (rh_f('by') !== '' && (int) ($t['by'] ?? 0) !== (int) rh_f('by')) {
            return false;
        }
        return rh_search_hit($q, $t['no'] ?? '', $t['number'] ?? '', $t['trxId'] ?? '', $t['agentReply'] ?? '', $customers[$t['customerId'] ?? '']['name'] ?? '', $t['recipientLabel'] ?? '');
    }));
    $live = array_filter($rows, fn($t) => !rh_cancelled($t));
    echo '<p class="rh-sum">' . esc_html(rh_bn(count($rows)) . 'টা লেনদেন · ' . rh_sar(array_sum(array_map(fn($t) => (float) $t['sar'], $live))) . ' · ' . rh_taka(array_sum(array_map(fn($t) => (float) $t['taka'], $live)))) . '</p>';
    $page = rh_paged($rows, $pager);
    ?>
    <table class="rh-table"><thead><tr><th>নং / সময়</th><th>গ্রাহক</th><th>কী / নম্বর</th><th class="r">রিয়াল</th><th class="r">রেট</th><th class="r">টাকা</th><th>রিয়াল পরিশোধ</th><th>এজেন্ট</th><th>এডমিন</th><th>অবস্থা</th></tr></thead><tbody>
    <?php foreach ($page as $t) : [$sl, $sc] = rh_status_label($t); ?>
        <tr class="<?php echo rh_cancelled($t) ? 'dim' : ''; ?>">
            <td><b>#<?php echo esc_html(rh_bn($t['no'] ?? '')); ?></b><br><small><?php echo esc_html(rh_when($t['at'] ?? '')); ?></small></td>
            <td><?php echo esc_html($customers[$t['customerId'] ?? '']['name'] ?? '—'); ?><?php if (($t['recipientLabel'] ?? '') !== '') : ?><br><small>প্রাপক: <?php echo esc_html($t['recipientLabel']); ?></small><?php endif; ?></td>
            <td><?php echo esc_html(rh_service($t)); ?><?php if (($t['kind'] ?? '') === 'mb' && ($t['pack'] ?? '') !== '') : ?> <small>(<?php echo esc_html($t['pack']); ?>)</small><?php endif; ?><br><small><?php echo esc_html(rh_phone_show($t['number'] ?? '')); ?></small></td>
            <td class="r"><?php echo esc_html(rh_num($t['sar'] ?? 0, 2)); ?></td>
            <td class="r"><?php echo esc_html(rh_num($t['rate'] ?? 0, 2)); ?></td>
            <td class="r"><?php echo esc_html(rh_num(round($t['taka'] ?? 0))); ?><?php if ((float) ($t['fee'] ?? 0) > 0) : ?><br><small>খরচ <?php echo esc_html(rh_num($t['fee'])); ?></small><?php endif; ?></td>
            <td><?php $d = rh_due_at_send($t); echo esc_html(rh_cancelled($t) ? '—' : ($d > 0 ? 'বাকি ' . rh_num($d, 2) : 'পরিশোধ')); ?></td>
            <td><?php echo esc_html($agents[$t['agentId'] ?? '']['name'] ?? '—'); ?></td>
            <td><?php echo esc_html(rh_admin_name($t)); ?></td>
            <td><span class="rh-pill <?php echo esc_attr($sc); ?>"><?php echo esc_html($sl); ?></span>
                <?php if (($t['agentReply'] ?? '') !== '' || ($t['trxId'] ?? '') !== '') : ?><br><small><?php echo esc_html(trim(($t['agentReply'] ?? '') . ' ' . ($t['trxId'] ?? ''))); ?></small><?php endif; ?>
                <?php if (!empty($t['fault'])) : ?><br><span class="rh-pill red">ভুল নম্বর · <?php echo esc_html(['mine' => 'দোকানের', 'agent' => 'এজেন্টের', 'customer' => 'গ্রাহকের'][$t['fault']] ?? ''); ?></span><?php endif; ?>
            </td>
        </tr>
    <?php endforeach; ?>
    <?php if (!$page) : ?><tr><td colspan="10" class="rh-empty">কিছু পাওয়া যায়নি।</td></tr><?php endif; ?>
    </tbody></table>
    <?php
    rh_pager_html('txns', $pager);
}

function rh_tab_customers() {
    $view = sanitize_text_field($_GET['view'] ?? '');
    if ($view !== '' && isset(rh_all('customer')[$view])) {
        rh_customer_view($view);
        return;
    }
    rh_filters('customers', ['due' => ['বাকি', ['' => 'সবাই', 'yes' => 'বাকি আছে', 'no' => 'বাকি নেই', 'promise' => 'তারিখ দেওয়া']]], 'নাম বা নম্বর');
    global $wpdb;
    $q = rh_f('q');
    $rows = [];
    foreach (rh_all('customer') as $id => $c) {
        $due = rh_customer_due($id);
        $f = rh_f('due');
        if (($f === 'yes' && $due <= 0) || ($f === 'no' && $due > 0) || ($f === 'promise' && empty($c['promiseAt']))) {
            continue;
        }
        $created = substr((string) ($c['created'] ?? ''), 0, 10);
        if ((rh_date_ok(rh_f('from')) !== '' && $created < rh_f('from')) || (rh_date_ok(rh_f('to')) !== '' && $created > rh_f('to'))) {
            continue;
        }
        if (!rh_search_hit($q, $c['name'] ?? '', $c['phone'] ?? '', $c['area'] ?? '')) {
            continue;
        }
        $c['due'] = $due;
        $c['loss'] = array_sum(array_map(fn($l) => ($l['customerId'] ?? '') === $id ? (float) $l['sar'] : 0, rh_all('loss')));
        $c['sent'] = array_sum(array_map(fn($t) => ($t['customerId'] ?? '') === $id && !rh_cancelled($t) ? (float) $t['sar'] : 0, rh_all('txn')));
        $rows[] = $c;
    }
    usort($rows, fn($a, $b) => $b['due'] <=> $a['due']);
    echo '<p class="rh-sum">' . esc_html(rh_bn(count($rows)) . ' জন · মোট বাকি ' . rh_sar(array_sum(array_map(fn($c) => max(0, $c['due']), $rows)))) . '</p>';
    $page = rh_paged($rows, $pager);
    ?>
    <table class="rh-table"><thead><tr><th>গ্রাহক</th><th>মোবাইল</th><th>থাকেন</th><th class="r">মোট পাঠানো</th><th class="r">বাকি</th><th class="r">লস</th><th>বাকি দেওয়ার কথা</th><th>যোগ হয়েছেন</th></tr></thead><tbody>
    <?php foreach ($page as $c) : ?>
        <tr>
            <td><?php rh_photo_thumb($c['photo'] ?? null); ?><a href="<?php echo rh_url('customers', ['view' => $c['id']]); ?>"><b><?php echo esc_html($c['name'] ?? ''); ?></b></a></td>
            <td><?php echo esc_html(rh_bn($c['phone'] ?? '')); ?></td>
            <td><?php echo esc_html($c['area'] ?? ''); ?></td>
            <td class="r"><?php echo esc_html(rh_num($c['sent'], 2)); ?></td>
            <td class="r <?php echo $c['due'] > 0 ? 'red' : ''; ?>"><?php echo esc_html($c['due'] > 0 ? rh_num($c['due'], 2) : ($c['due'] < 0 ? 'অগ্রিম ' . rh_num(-$c['due'], 2) : 'বাকি নেই')); ?></td>
            <td class="r"><?php echo esc_html($c['loss'] > 0 ? rh_num($c['loss'], 2) : '—'); ?></td>
            <td><?php echo esc_html(!empty($c['promiseAt']) && $c['due'] > 0 ? rh_when($c['promiseAt']) . (($c['promiseNote'] ?? '') !== '' ? ' · ' . $c['promiseNote'] : '') : '—'); ?></td>
            <td><small><?php echo esc_html(rh_when($c['created'] ?? '', false)); ?></small></td>
        </tr>
    <?php endforeach; ?>
    <?php if (!$page) : ?><tr><td colspan="8" class="rh-empty">কিছু পাওয়া যায়নি।</td></tr><?php endif; ?>
    </tbody></table>
    <?php
    rh_pager_html('customers', $pager);
}

/** A small photo kept on the server (customer, receipt), or nothing. */
function rh_photo_thumb($pid, $big = false) {
    if (!$pid) {
        return;
    }
    global $wpdb;
    $b64 = $wpdb->get_var($wpdb->prepare('SELECT data FROM ' . rh_t('photos') . ' WHERE pid = %s', (string) $pid));
    if (!$b64) {
        return;
    }
    $src = 'data:image/jpeg;base64,' . $b64;
    if ($big) {
        printf('<a href="#" class="rh-receipt" onclick="var w=window.open();w.document.write(\'<img style=max-width:100%% src=\\\'\'+this.dataset.src+\'\\\'>\');return false;" data-src="%s"><img src="%s" alt="রসিদ"></a>', esc_attr($src), esc_attr($src));
    } else {
        printf('<img class="rh-face" src="%s" alt="">', esc_attr($src));
    }
}

function rh_simple_table($tab, $kind, array $head, callable $row, array $selects = [], $search = 'খুঁজুন', ?callable $filter = null, ?callable $sum = null) {
    rh_filters($tab, $selects, $search);
    $q = rh_f('q');
    $rows = array_values(array_filter(rh_rows($kind), function ($r) use ($q, $filter) {
        return ($filter ? $filter($r, $q) : true);
    }));
    if ($sum) {
        echo '<p class="rh-sum">' . esc_html($sum($rows)) . '</p>';
    }
    $page = rh_paged($rows, $pager);
    echo '<table class="rh-table"><thead><tr>';
    foreach ($head as $h) {
        $r = str_starts_with($h, '>');
        echo '<th class="' . ($r ? 'r' : '') . '">' . esc_html(ltrim($h, '>')) . '</th>';
    }
    echo '</tr></thead><tbody>';
    foreach ($page as $r) {
        echo '<tr>';
        foreach ($row($r) as $i => $cell) {
            $right = str_starts_with($head[$i] ?? '', '>');
            echo '<td class="' . ($right ? 'r' : '') . '">' . $cell . '</td>';
        }
        echo '</tr>';
    }
    if (!$page) {
        echo '<tr><td colspan="' . count($head) . '" class="rh-empty">কিছু পাওয়া যায়নি।</td></tr>';
    }
    echo '</tbody></table>';
    rh_pager_html($tab, $pager);
}

function rh_tab_deposits() {
    $customers = rh_all('customer');
    rh_simple_table('deposits', 'deposit', ['সময়', 'গ্রাহক', 'কীভাবে', 'নোট', '>রিয়াল'], fn($d) => [
        esc_html(rh_when($d['at'] ?? '')),
        esc_html($customers[$d['customerId'] ?? '']['name'] ?? '—'),
        esc_html(($d['way'] ?? '') === 'cash' ? 'নগদ হাতে' : 'ব্যাংক/ট্রান্সফার'),
        esc_html($d['note'] ?? ''),
        esc_html(rh_num($d['sar'] ?? 0, 2)),
    ], ['way' => ['কীভাবে', ['' => 'সব', 'cash' => 'নগদ হাতে', 'bank' => 'ব্যাংক/ট্রান্সফার']]], 'গ্রাহকের নাম', function ($d, $q) use ($customers) {
        return (rh_f('way') === '' || ($d['way'] ?? '') === rh_f('way')) && rh_search_hit($q, $customers[$d['customerId'] ?? '']['name'] ?? '', $d['note'] ?? '');
    }, fn($rows) => rh_bn(count($rows)) . 'টা জমা · ' . rh_sar(array_sum(array_map(fn($d) => (float) $d['sar'], $rows))));
}

function rh_tab_agents() {
    global $wpdb;
    $users = $wpdb->get_results('SELECT name, login, agent_rid, status, last_seen FROM ' . rh_t('users') . " WHERE role = 'agent'", ARRAY_A);
    ?>
    <table class="rh-table"><thead><tr><th>এজেন্ট</th><th>হোয়াটসঅ্যাপ</th><th>যোগাযোগ</th><th>অ্যাপের লগইন</th><th class="r">কমিশন/হাজার</th><th class="r">মোট পাঠালেন</th><th class="r">দিতে হবে</th></tr></thead><tbody>
    <?php foreach (rh_all('agent') as $id => $a) :
        $sent = array_sum(array_map(fn($t) => ($t['agentId'] ?? '') === $id && !rh_cancelled($t) ? rh_agent_taka($t) : 0, rh_all('txn')));
        $logins = array_filter($users, fn($u) => $u['agent_rid'] === $id);
        $o = rh_agent_owed($id); ?>
        <tr>
            <td><b><?php echo esc_html($a['name'] ?? ''); ?></b></td>
            <td><?php echo esc_html(rh_bn($a['whatsapp'] ?? '')); ?></td>
            <td><?php echo esc_html(($a['channel'] ?? '') === 'app' ? 'অ্যাপে' : 'হোয়াটসঅ্যাপে'); ?></td>
            <td><?php echo $logins ? esc_html(implode(', ', array_map(fn($u) => rh_bn($u['login']) . ($u['status'] === 'off' ? ' (বন্ধ)' : ''), $logins))) : '—'; ?></td>
            <td class="r"><?php echo esc_html(rh_num($a['commission'] ?? 0, 2)); ?></td>
            <td class="r"><?php echo esc_html(rh_taka($sent)); ?></td>
            <td class="r"><?php echo esc_html(($o < 0 ? 'অগ্রিম ' : '') . rh_taka(abs($o))); ?></td>
        </tr>
    <?php endforeach; ?>
    </tbody></table>
    <?php
}

function rh_tab_payments() {
    $agents = rh_all('agent');
    rh_simple_table('payments', 'payment', ['সময়', 'এজেন্ট', 'কীভাবে', 'কোথা থেকে / রেফ', 'নোট', 'রসিদ', 'এডমিন', '>টাকা', '>রিয়াল'], function ($p) use ($agents) {
        ob_start();
        rh_photo_thumb($p['receipt'] ?? null, true);
        $img = ob_get_clean();
        $n = count($p['txnIds'] ?? []);
        return [
            esc_html(rh_when($p['at'] ?? '')),
            esc_html($agents[$p['agentId'] ?? '']['name'] ?? '—'),
            esc_html(rh_pay_way($p['way'] ?? '') . ($n ? ' · ' . rh_bn($n) . 'টা লেনদেনের' : '')),
            esc_html(trim(($p['fromAccount'] ?? '') . (($p['ref'] ?? '') !== '' ? ' · রেফ ' . $p['ref'] : ''), ' ·')),
            esc_html($p['note'] ?? ''),
            $img ?: '—',
            esc_html(rh_admin_name($p)),
            esc_html(rh_num($p['taka'] ?? 0)),
            esc_html((float) ($p['sar'] ?? 0) > 0 ? rh_num($p['sar'], 2) : '—'),
        ];
    }, ['agent' => ['এজেন্ট', rh_agent_options()], 'way' => ['কীভাবে', ['' => 'সব'] + ['bank' => 'ব্যাংক', 'bkash' => 'বিকাশ', 'nagad' => 'নগদ (অ্যাপ)', 'cash' => 'হাতে নগদ', 'hundi' => 'অন্যের মাধ্যমে', 'other' => 'অন্যভাবে']]], 'রেফ বা নোট', function ($p, $q) {
        return (rh_f('agent') === '' || ($p['agentId'] ?? '') === rh_f('agent')) && (rh_f('way') === '' || ($p['way'] ?? '') === rh_f('way')) && rh_search_hit($q, $p['ref'] ?? '', $p['note'] ?? '', $p['fromAccount'] ?? '');
    }, fn($rows) => rh_bn(count($rows)) . 'বার · ' . rh_taka(array_sum(array_map(fn($p) => (float) $p['taka'], $rows))) . ' · ' . rh_sar(array_sum(array_map(fn($p) => (float) ($p['sar'] ?? 0), $rows))));
}

function rh_admin_options() {
    $o = ['' => 'সব এডমিন'];
    foreach (rh_admins_in() as $id => $name) {
        $o[(string) $id] = $name;
    }
    return $o;
}

function rh_admin_name($r) {
    $id = (int) ($r['by'] ?? 0);
    return $id === 0 ? 'মূল হিসাব' : ((string) ($r['byName'] ?? '') ?: '#' . rh_bn($id));
}

/** Riyal in and out of hands, per admin or for the whole shop, with handovers. */
function rh_tab_cash() {
    $admins = rh_admins_in();
    $opts = ['' => 'সবাই মিলে (দোকানের মোট)'];
    foreach ($admins as $id => $name) {
        $opts[(string) $id] = $name;
    }
    rh_filters('cash', ['by' => ['কার হাত', $opts]], '');
    $by = rh_f('by') === '' ? null : (int) rh_f('by');
    if ($by === null) {
        echo '<div class="rh-figs">';
        echo '<div><span>দোকানের হাতে থাকা উচিত</span><strong>' . esc_html(rh_sar(rh_cash_in_hand())) . '</strong><em>সব এডমিন মিলে, হাতবদল বাদে</em></div>';
        foreach ($admins as $id => $name) {
            printf('<div><span>%s</span><strong>%s</strong><em><a href="%s">লাইন ধরে দেখুন</a></em></div>', esc_html($name), esc_html(rh_sar(rh_cash_in_hand($id))), esc_url(rh_url('cash', ['by' => (string) $id])));
        }
        echo '</div>';
    }
    $from = rh_date_ok(rh_f('from'));
    $to = rh_date_ok(rh_f('to'));
    $all = rh_cash_lines($by);
    $before = 0.0;
    $lines = [];
    foreach ($all as $l) {
        $d = substr((string) $l[0], 0, 10);
        if ($from !== '' && $d < $from) {
            $before += $l[3] - $l[4];
            continue;
        }
        if ($to !== '' && $d > $to) {
            continue;
        }
        $lines[] = $l;
    }
    $in = array_sum(array_column($lines, 3));
    $out = array_sum(array_column($lines, 4));
    echo '<p class="rh-sum">' . esc_html(($by === null ? 'দোকানের' : ($admins[$by] ?? '') . '-এর') . ' হাত · আগে থেকে ' . rh_sar($before) . ' · এসেছে ' . rh_sar($in) . ' · গেছে ' . rh_sar($out) . ' · শেষে ' . rh_sar($before + $in - $out)) . '</p>';
    $kinds = ['txn' => 'লেনদেন', 'deposit' => 'জমা', 'expense' => 'খরচ', 'payment' => 'এজেন্টকে', 'handover' => 'হাতবদল', 'close' => 'দিন শেষ'];
    $bal = $before;
    $rows = [];
    foreach ($lines as $l) {
        $bal += $l[3] - $l[4];
        $rows[] = [$l, $bal];
    }
    $rows = array_reverse($rows);
    $page = rh_paged($rows, $pager);
    ?>
    <table class="rh-table"><thead><tr><th>সময়</th><th>কী</th><th>বিবরণ</th><th>এডমিন</th><th class="r">এল</th><th class="r">গেল</th><th class="r">হাতে থাকে</th></tr></thead><tbody>
    <?php foreach ($page as [$l, $b]) : ?>
        <tr>
            <td><?php echo esc_html(rh_when($l[0])); ?></td>
            <td><span class="rh-pill <?php echo $l[3] > 0 ? 'green' : 'red'; ?>"><?php echo esc_html($kinds[$l[5]] ?? $l[5]); ?></span></td>
            <td><b><?php echo esc_html($l[1]); ?></b><?php if ($l[2] !== '') : ?><br><small><?php echo esc_html($l[2]); ?></small><?php endif; ?></td>
            <td><?php echo esc_html($l[6] === 0 ? 'মূল হিসাব' : ($l[7] !== '' ? $l[7] : ($admins[$l[6]] ?? ''))); ?></td>
            <td class="r"><?php echo $l[3] > 0 ? esc_html(rh_num($l[3], 2)) : ''; ?></td>
            <td class="r"><?php echo $l[4] > 0 ? esc_html(rh_num($l[4], 2)) : ''; ?></td>
            <td class="r"><?php echo esc_html(rh_num($b, 2)); ?></td>
        </tr>
    <?php endforeach; ?>
    <?php if (!$page) : ?><tr><td colspan="7" class="rh-empty">এই সময়ে হাতে কোনো রিয়াল আসা-যাওয়া নেই।</td></tr><?php endif; ?>
    </tbody></table>
    <?php
    rh_pager_html('cash', $pager);
}

/** Problems the app ran into, newest first. */
function rh_tab_errors() {
    global $wpdb;
    $users = ['' => 'সবাই'];
    foreach ($wpdb->get_results('SELECT DISTINCT user_id, user_name FROM ' . rh_t('errors'), ARRAY_A) as $u) {
        $users[(string) $u['user_id']] = $u['user_name'];
    }
    $versions = ['' => 'সব'];
    foreach ($wpdb->get_col('SELECT DISTINCT version FROM ' . rh_t('errors') . ' ORDER BY version DESC') as $v) {
        $versions[$v] = $v;
    }
    rh_filters('errors', ['user' => ['কার ফোনে', $users], 'ver' => ['সংস্করণ', $versions]], 'লেখা');
    $sql = 'SELECT * FROM ' . rh_t('errors') . ' WHERE 1=1';
    $args = [];
    if (($f = rh_date_ok(rh_f('from'))) !== '') {
        $sql .= ' AND at >= %s';
        $args[] = $f . ' 00:00:00';
    }
    if (($t = rh_date_ok(rh_f('to'))) !== '') {
        $sql .= ' AND at <= %s';
        $args[] = $t . ' 23:59:59';
    }
    if (rh_f('user') !== '') {
        $sql .= ' AND user_id = %d';
        $args[] = (int) rh_f('user');
    }
    if (rh_f('ver') !== '') {
        $sql .= ' AND version = %s';
        $args[] = rh_f('ver');
    }
    $sql .= ' ORDER BY at DESC, id DESC LIMIT 5000';
    $rows = $wpdb->get_results($args ? $wpdb->prepare($sql, $args) : $sql, ARRAY_A);
    $q = rh_f('q');
    $rows = array_values(array_filter($rows, fn($r) => rh_search_hit($q, $r['message'], $r['place'], $r['stack'])));
    echo '<p class="rh-sum">' . esc_html(rh_bn(count($rows)) . 'টা সমস্যা') . '</p>';
    $page = rh_paged($rows, $pager);
    ?>
    <table class="rh-table"><thead><tr><th>সময়</th><th>কার ফোনে</th><th>কোথায়</th><th>সমস্যা</th><th>সংস্করণ</th></tr></thead><tbody>
    <?php foreach ($page as $r) : ?>
        <tr>
            <td><?php echo esc_html(rh_when(str_replace(' ', 'T', $r['at']))); ?></td>
            <td><?php echo esc_html($r['user_name']); ?></td>
            <td><small><?php echo esc_html($r['place']); ?></small></td>
            <td><b><?php echo esc_html($r['message']); ?></b><?php if (trim((string) $r['stack']) !== '' && !rh_printing()) : ?><details><summary>বিস্তারিত</summary><pre class="rh-pre"><?php echo esc_html($r['stack']); ?></pre></details><?php endif; ?></td>
            <td><?php echo esc_html($r['version'] . ($r['platform'] !== '' ? ' · ' . $r['platform'] : '')); ?></td>
        </tr>
    <?php endforeach; ?>
    <?php if (!$page) : ?><tr><td colspan="5" class="rh-empty">কোনো সমস্যা আসেনি।</td></tr><?php endif; ?>
    </tbody></table>
    <?php
    rh_pager_html('errors', $pager);
}

function rh_tab_expenses() {
    $cats = ['' => 'সব'];
    foreach (rh_all('expense') as $e) {
        $cats[$e['category'] ?? ''] = $e['category'] ?? '';
    }
    rh_simple_table('expenses', 'expense', ['সময়', 'কী', 'নোট', '>রিয়াল'], fn($e) => [
        esc_html(rh_when($e['at'] ?? '')),
        esc_html($e['category'] ?? ''),
        esc_html($e['note'] ?? ''),
        esc_html(rh_num($e['sar'] ?? 0, 2)),
    ], ['cat' => ['কী', $cats]], 'নোট', fn($e, $q) => (rh_f('cat') === '' || ($e['category'] ?? '') === rh_f('cat')) && rh_search_hit($q, $e['note'] ?? '', $e['category'] ?? ''),
        fn($rows) => rh_bn(count($rows)) . 'টা · ' . rh_sar(array_sum(array_map(fn($e) => (float) $e['sar'], $rows))));
}

function rh_tab_losses() {
    $customers = rh_all('customer');
    rh_simple_table('losses', 'loss', ['সময়', 'গ্রাহক', 'কারণ', '>রিয়াল'], fn($l) => [
        esc_html(rh_when($l['at'] ?? '')),
        esc_html($customers[$l['customerId'] ?? '']['name'] ?? '—'),
        esc_html($l['note'] ?? ''),
        esc_html(rh_num($l['sar'] ?? 0, 2)),
    ], [], 'গ্রাহকের নাম', fn($l, $q) => rh_search_hit($q, $customers[$l['customerId'] ?? '']['name'] ?? '', $l['note'] ?? ''),
        fn($rows) => 'মোট লস ' . rh_sar(array_sum(array_map(fn($l) => (float) $l['sar'], $rows))));
}

function rh_tab_closes() {
    rh_simple_table('closes', 'close', ['সময়', '>হিসাবে', '>গুনে', '>পার্থক্য', 'নোট'], function ($c) {
        $d = (float) ($c['counted'] ?? 0) - (float) ($c['expected'] ?? 0);
        return [
            esc_html(rh_when($c['at'] ?? '')),
            esc_html(rh_num($c['expected'] ?? 0, 2)),
            esc_html(rh_num($c['counted'] ?? 0, 2)),
            abs($d) < 0.01 ? 'মিলেছে' : '<span class="red">' . esc_html(rh_num($d, 2)) . '</span>',
            esc_html($c['note'] ?? ''),
        ];
    }, ['diff' => ['মিলেছে?', ['' => 'সব', 'ok' => 'মিলেছে', 'no' => 'মেলেনি']]], '', function ($c) {
        $d = abs((float) ($c['counted'] ?? 0) - (float) ($c['expected'] ?? 0));
        return rh_f('diff') === '' || (rh_f('diff') === 'ok' ? $d < 0.01 : $d >= 0.01);
    });
}

function rh_tab_log() {
    $kinds = ['' => 'সব', 'txn' => 'লেনদেন', 'recv' => 'জমা ও লস', 'agent' => 'এজেন্ট', 'edit' => 'সংশোধন', 'cust' => 'গ্রাহক', 'sys' => 'অন্যান্য'];
    $whos = ['' => 'সবাই'];
    foreach (rh_all('log') as $e) {
        $w = (string) ($e['who'] ?? '');
        if ($w !== '' && $w !== 'me' && $w !== 'app') {
            $whos[$w] = $w;
        }
    }
    rh_simple_table('log', 'log', ['সময়', 'কী হলো', 'বিস্তারিত', 'কে'], fn($e) => [
        esc_html(rh_when($e['at'] ?? '')),
        '<b>' . esc_html($e['title'] ?? '') . '</b>',
        esc_html($e['detail'] ?? ''),
        esc_html(['me' => 'এডমিন', 'app' => 'অ্যাপ নিজে'][$e['who'] ?? ''] ?? ($e['who'] ?? '')),
    ], ['kind' => ['ধরন', $kinds], 'who' => ['কে', $whos]], 'যেকোনো লেখা', function ($e, $q) {
        return (rh_f('kind') === '' || ($e['kind'] ?? '') === rh_f('kind')) && (rh_f('who') === '' || ($e['who'] ?? '') === rh_f('who')) && rh_search_hit($q, $e['title'] ?? '', $e['detail'] ?? '');
    }, fn($rows) => rh_bn(count($rows)) . 'টা কাজ');
}

function rh_tab_users() {
    global $wpdb;
    $role = rh_f('role');
    $rows = $wpdb->get_results('SELECT * FROM ' . rh_t('users') . ' ORDER BY id', ARRAY_A);
    $agents = rh_all('agent');
    ?>
    <form class="rh-filters" method="get" action="<?php echo esc_url(admin_url('admin.php')); ?>">
        <input type="hidden" name="page" value="riyal-hisab-users">
        <label>কে <select name="role"><?php foreach (['' => 'সবাই', 'owner' => 'মূল এডমিন', 'admin' => 'এডমিন', 'agent' => 'এজেন্ট'] as $k => $v) : ?><option value="<?php echo esc_attr($k); ?>" <?php selected($role, $k); ?>><?php echo esc_html($v); ?></option><?php endforeach; ?></select></label>
        <button class="rh-btn">দেখান</button>
    </form>
    <p class="rh-muted">এডমিন আর এজেন্ট যোগ বা বন্ধ করা হয় অ্যাপ থেকে। মূল এডমিন সেটিংসে।</p>
    <table class="rh-table"><thead><tr><th>নাম</th><th>কে</th><th>লগইন</th><th>এজেন্ট</th><th>যা করতে পারেন</th><th>অবস্থা</th><th>শেষ দেখা</th><th>যোগ হয়েছেন</th></tr></thead><tbody>
    <?php foreach ($rows as $u) : if ($role !== '' && $u['role'] !== $role) { continue; } ?>
        <tr>
            <td><b><?php echo esc_html($u['name']); ?></b></td>
            <td><?php echo esc_html(rh_role_bn($u['role'])); ?></td>
            <td><?php echo esc_html(rh_bn($u['login'])); ?></td>
            <td><?php echo esc_html($u['agent_rid'] !== '' ? ($agents[$u['agent_rid']]['name'] ?? '—') : '—'); ?></td>
            <td><small><?php $pp = rh_perms($u); echo esc_html($u['role'] === 'agent' ? 'শুধু নিজের কাজ' : (count($pp) === count(RH_PERMS) ? 'সব' : ($pp ? implode(', ', array_map(fn($p) => RH_PERMS[$p], $pp)) : 'কিছুই না'))); ?></small></td>
            <td><span class="rh-pill <?php echo $u['status'] === 'active' ? 'green' : 'gray'; ?>"><?php echo esc_html($u['status'] === 'active' ? 'চালু' : 'বন্ধ'); ?></span></td>
            <td><?php echo esc_html($u['last_seen'] ? rh_when(get_date_from_gmt($u['last_seen'], 'Y-m-d\TH:i:s')) : '—'); ?></td>
            <td><small><?php echo esc_html(rh_when(get_date_from_gmt($u['created_at'], 'Y-m-d\TH:i:s'), false)); ?></small></td>
        </tr>
    <?php endforeach; ?>
    </tbody></table>
    <?php
}

/** One customer's whole account (riyal), with the running due. */
function rh_customer_view($cid) {
    $c = rh_all('customer')[$cid];
    $rows = [];
    foreach (rh_all('txn') as $t) {
        if (($t['customerId'] ?? '') === $cid && !rh_cancelled($t)) {
            $rows[] = [(string) $t['at'], '#' . rh_bn($t['no'] ?? '') . ' · ' . rh_service($t) . ' ' . rh_phone_show($t['number'] ?? '') . (($t['recipientLabel'] ?? '') !== '' ? ' (' . $t['recipientLabel'] . ')' : '') . ' · ' . rh_taka($t['taka'] ?? 0), (float) $t['sar'], (float) ($t['sarPaid'] ?? 0)];
        }
    }
    foreach (rh_all('deposit') as $d) {
        if (($d['customerId'] ?? '') === $cid) {
            $rows[] = [(string) $d['at'], 'রিয়াল জমা' . (($d['note'] ?? '') !== '' ? ' · ' . $d['note'] : ''), 0.0, (float) $d['sar']];
        }
    }
    foreach (rh_all('loss') as $l) {
        if (($l['customerId'] ?? '') === $cid) {
            $rows[] = [(string) $l['at'], 'লস — আদায় হবে না' . (($l['note'] ?? '') !== '' ? ' · ' . $l['note'] : ''), 0.0, (float) $l['sar']];
        }
    }
    usort($rows, fn($a, $b) => strcmp($a[0], $b[0]));
    $due = rh_customer_due($cid);
    if (!rh_printing()) {
        echo '<p><a class="rh-link" href="' . rh_url('customers') . '">← সব গ্রাহক</a> ';
        $args = ['view' => $cid, 'print' => 1];
        printf('<a class="rh-btn rh-pdf" target="_blank" href="%s">PDF / প্রিন্ট</a></p>', rh_url('customers', $args));
    }
    ?>
    <div class="rh-figs">
        <div><span>গ্রাহক</span><strong><?php echo esc_html($c['name'] ?? ''); ?></strong><em><?php echo esc_html(rh_bn($c['phone'] ?? '') . (($c['area'] ?? '') !== '' ? ' · ' . $c['area'] : '')); ?></em></div>
        <div><span>এখন বাকি</span><strong class="<?php echo $due > 0 ? 'red' : ''; ?>"><?php echo esc_html($due > 0 ? rh_sar($due) : ($due < 0 ? 'অগ্রিম ' . rh_sar(-$due) : 'বাকি নেই')); ?></strong></div>
        <?php if (!empty($c['promiseAt']) && $due > 0) : ?><div><span>বাকি দেওয়ার কথা</span><strong><?php echo esc_html(rh_when($c['promiseAt'])); ?></strong><em><?php echo esc_html($c['promiseNote'] ?? ''); ?></em></div><?php endif; ?>
    </div>
    <table class="rh-table"><thead><tr><th>সময়</th><th>বিবরণ</th><th class="r">পাঠানো (রিয়াল)</th><th class="r">দিলেন (রিয়াল)</th><th class="r">বাকি</th></tr></thead><tbody>
    <?php $run = 0.0; foreach ($rows as [$at, $what, $sent, $paid]) : $run += $sent - $paid; ?>
        <tr><td><?php echo esc_html(rh_when($at)); ?></td><td><?php echo esc_html($what); ?></td><td class="r"><?php echo $sent ? esc_html(rh_num($sent, 2)) : ''; ?></td><td class="r"><?php echo $paid ? esc_html(rh_num($paid, 2)) : ''; ?></td><td class="r"><?php echo esc_html($run > 0.004 ? rh_num($run, 2) : ($run < -0.004 ? 'অগ্রিম ' . rh_num(-$run, 2) : '—')); ?></td></tr>
    <?php endforeach; ?>
    <?php if (!$rows) : ?><tr><td colspan="5" class="rh-empty">কিছু নেই।</td></tr><?php endif; ?>
    </tbody></table>
    <?php
}

function rh_tab_promises() {
    rh_filters('promises', ['when' => ['কবে', ['' => 'সব', 'came' => 'দিন এসেছে', 'ahead' => 'সামনে']]], 'নাম');
    $now = current_time('Y-m-d\TH:i:s');
    $rows = [];
    foreach (rh_all('customer') as $id => $c) {
        if (empty($c['promiseAt'])) {
            continue;
        }
        $due = rh_customer_due($id);
        $p = substr((string) $c['promiseAt'], 0, 10);
        if ($due <= 0 || (rh_f('when') === 'came' && $c['promiseAt'] > $now) || (rh_f('when') === 'ahead' && $c['promiseAt'] <= $now)) {
            continue;
        }
        if ((rh_date_ok(rh_f('from')) !== '' && $p < rh_f('from')) || (rh_date_ok(rh_f('to')) !== '' && $p > rh_f('to')) || !rh_search_hit(rh_f('q'), $c['name'] ?? '', $c['phone'] ?? '')) {
            continue;
        }
        $rows[] = $c + ['due' => $due];
    }
    usort($rows, fn($a, $b) => strcmp($a['promiseAt'], $b['promiseAt']));
    echo '<p class="rh-sum">' . esc_html(rh_bn(count($rows)) . ' জন · ' . rh_sar(array_sum(array_column($rows, 'due')))) . '</p>';
    ?>
    <table class="rh-table"><thead><tr><th>বাকি দেওয়ার কথা</th><th>গ্রাহক</th><th>মোবাইল</th><th>নোট</th><th class="r">বাকি</th></tr></thead><tbody>
    <?php foreach ($rows as $c) : ?>
        <tr><td class="<?php echo $c['promiseAt'] <= $now ? 'red' : ''; ?>"><?php echo esc_html(rh_when($c['promiseAt'])); ?></td><td><a href="<?php echo rh_url('customers', ['view' => $c['id']]); ?>"><?php echo esc_html($c['name'] ?? ''); ?></a></td><td><?php echo esc_html(rh_bn($c['phone'] ?? '')); ?></td><td><?php echo esc_html($c['promiseNote'] ?? ''); ?></td><td class="r red"><?php echo esc_html(rh_num($c['due'], 2)); ?></td></tr>
    <?php endforeach; ?>
    <?php if (!$rows) : ?><tr><td colspan="5" class="rh-empty">কিছু নেই।</td></tr><?php endif; ?>
    </tbody></table>
    <?php
}

/** Every notification the server sent (to agents and admins). */
function rh_tab_notes() {
    global $wpdb;
    $users = [];
    foreach ($wpdb->get_results('SELECT id, name, role FROM ' . rh_t('users'), ARRAY_A) as $u) {
        $users[(int) $u['id']] = $u;
    }
    $opts = ['' => 'সবাই'];
    foreach ($users as $id => $u) {
        $opts[$id] = $u['name'] . ' (' . rh_role_bn($u['role']) . ')';
    }
    rh_filters('notes', ['user' => ['কাকে', $opts], 'kind' => ['ধরন', ['' => 'সব', 'new' => 'নতুন অনুরোধ', 'edit' => 'সংশোধন', 'cancel' => 'বাতিল', 'paid' => 'টাকা দেওয়া', 'fault' => 'ভুল নম্বর', 'sent' => 'এজেন্ট পাঠালেন', 'problem' => 'সমস্যা']]], 'লেখা');
    $sql = 'SELECT * FROM ' . rh_t('notes') . ' WHERE 1=1';
    $args = [];
    if (rh_f('user') !== '') {
        $sql .= ' AND user_id = %d';
        $args[] = (int) rh_f('user');
    }
    if (rh_f('kind') !== '') {
        $sql .= ' AND kind = %s';
        $args[] = rh_f('kind');
    }
    $sql .= ' ORDER BY id DESC LIMIT 5000';
    $rows = $wpdb->get_results($args ? $wpdb->prepare($sql, $args) : $sql, ARRAY_A);
    $rows = array_values(array_filter($rows, function ($n) {
        $d = substr(get_date_from_gmt($n['at'], 'Y-m-d'), 0, 10);
        return (rh_date_ok(rh_f('from')) === '' || $d >= rh_f('from')) && (rh_date_ok(rh_f('to')) === '' || $d <= rh_f('to')) && rh_search_hit(rh_f('q'), $n['title'], $n['body']);
    }));
    $page = rh_paged($rows, $pager);
    ?>
    <table class="rh-table"><thead><tr><th>সময়</th><th>কাকে</th><th>শিরোনাম</th><th>বিস্তারিত</th><th>দেখেছেন</th></tr></thead><tbody>
    <?php foreach ($page as $n) : ?>
        <tr><td><?php echo esc_html(rh_when(get_date_from_gmt($n['at'], 'Y-m-d\TH:i:s'))); ?></td><td><?php echo esc_html($users[(int) $n['user_id']]['name'] ?? '—'); ?></td><td><b><?php echo esc_html($n['title']); ?></b></td><td><?php echo esc_html($n['body']); ?></td><td><?php echo $n['read_at'] ? 'হ্যাঁ' : '—'; ?></td></tr>
    <?php endforeach; ?>
    <?php if (!$page) : ?><tr><td colspan="5" class="rh-empty">কিছু নেই।</td></tr><?php endif; ?>
    </tbody></table>
    <?php
    rh_pager_html('notes', $pager);
}

function rh_tab_backup() {
    ?>
    <div class="rh-cards">
        <form class="rh-card" method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <?php wp_nonce_field('rh_backup_download'); ?>
            <input type="hidden" name="action" value="rh_backup_download">
            <h2>ব্যাকআপ ডাউনলোড</h2>
            <p class="rh-muted">পুরো হিসাব আর ছবি এক ফাইলে (.rhb), আপনার দেওয়া পাসওয়ার্ড দিয়ে তালা দেওয়া। অ্যাপের সেটিংস → "ব্যাকআপ থেকে ফিরিয়ে আনুন" দিয়ে খোলা যায়। পাসওয়ার্ড ভুলে গেলে কেউ খুলতে পারবে না।</p>
            <label>এই ফাইলের পাসওয়ার্ড (অন্তত ৮ অক্ষর) <input name="password" type="password" minlength="8" required autocomplete="new-password"></label>
            <button class="rh-btn">ডাউনলোড</button>
        </form>
        <?php rh_gd_card(); ?>
    </div>
    <h2 class="rh-h">সব রেকর্ডের PDF</h2>
    <p class="rh-muted">প্রতিটা মেনুর ফিল্টারের পাশে "PDF / প্রিন্ট" আছে — যেভাবে ফিল্টার করা, সেভাবেই। খুললে প্রিন্টের ঘরে "Save as PDF" বাছুন। নিচে এক চাপে পুরোটা:</p>
    <p><?php foreach (rh_tabs() as $k => $label) { if (in_array($k, ['backup', 'settings'], true)) { continue; } printf('<a class="rh-btn rh-pdf" style="margin:3px" target="_blank" href="%s">%s</a>', rh_url($k, ['print' => 1]), esc_html($label)); } ?></p>
    <?php
}

add_action('admin_post_rh_backup_download', function () {
    if (!current_user_can('manage_options') || !check_admin_referer('rh_backup_download')) {
        wp_die('অনুমতি নেই');
    }
    $pass = (string) wp_unslash($_POST['password'] ?? '');
    if (strlen($pass) < 8) {
        rh_back('backup', 'অন্তত ৮ অক্ষরের পাসওয়ার্ড দিন।', true);
    }
    $bytes = rh_backup_bytes($pass);
    rh_add_log('সার্ভার থেকে ব্যাকআপ ডাউনলোড', wp_get_current_user()->display_name, 'সার্ভার', '', 'sys');
    if (defined('RH_TEST')) {
        throw new RuntimeException('download:' . base64_encode($bytes));
    }
    nocache_headers();
    header('Content-Type: application/octet-stream');
    header('Content-Disposition: attachment; filename="riyal-hisab-' . current_time('Y-m-d-Hi') . '.rhb"');
    header('Content-Length: ' . strlen($bytes));
    echo $bytes;
    exit;
});

function rh_owner() {
    global $wpdb;
    return $wpdb->get_row('SELECT * FROM ' . rh_t('users') . " WHERE role = 'owner' LIMIT 1", ARRAY_A);
}

function rh_tab_settings() {
    $o = rh_owner();
    $fb = rh_firebase_options();
    $acc = rh_push_account();
    ?>
    <div class="rh-cards">
        <form class="rh-card" method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <?php wp_nonce_field('rh_owner'); ?>
            <input type="hidden" name="action" value="rh_owner">
            <h2>মূল এডমিন</h2>
            <p class="rh-muted">অ্যাপে এই নম্বর/নাম আর পাসওয়ার্ড দিয়ে লগইন। মূল এডমিন অ্যাপ থেকে অন্য এডমিন আর এজেন্ট যোগ করবেন।<?php echo $o ? ' এখন: ' . esc_html($o['name'] . ' · ' . rh_bn($o['login'])) : ''; ?></p>
            <label>নাম <input name="name" required value="<?php echo esc_attr($o['name'] ?? ''); ?>"></label>
            <label>লগইন (মোবাইল নম্বর বা ইংরেজি নাম) <input name="login" required value="<?php echo esc_attr($o['login'] ?? ''); ?>"></label>
            <label>পাসওয়ার্ড <?php echo $o ? '(বদলাতে চাইলে লিখুন)' : ''; ?> <input name="password" type="password" minlength="8" <?php echo $o ? '' : 'required'; ?> autocomplete="new-password"></label>
            <button class="rh-btn">রাখুন</button>
        </form>
        <form class="rh-card" method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <?php wp_nonce_field('rh_firebase'); ?>
            <input type="hidden" name="action" value="rh_firebase">
            <h2>নোটিফিকেশন (Firebase)</h2>
            <p class="rh-muted">অ্যাপ: <?php echo $fb ? '<b class="green">ঠিক আছে</b> · ' . esc_html($fb['projectId']) : '<b class="red">দেওয়া হয়নি</b>'; ?> · সার্ভার: <?php echo $acc ? '<b class="green">ঠিক আছে</b>' : '<b class="red">দেওয়া হয়নি</b>'; ?></p>
            <label>google-services.json (Firebase-এ Android অ্যাপ <code>com.iamsaifsaiful.riyal_hisab</code> যোগ করে যে ফাইল পাবেন, তার পুরো লেখা)<textarea name="services" rows="4" placeholder="{ &quot;project_info&quot;: … }"></textarea></label>
            <label>Service account JSON (Project settings → Service accounts → Generate new private key)<textarea name="account" rows="4" placeholder="{ &quot;type&quot;: &quot;service_account&quot;, … }"></textarea></label>
            <button class="rh-btn">রাখুন</button>
        </form>
    </div>
    <?php
}

function rh_back($tab, $msg, $error = false) {
    wp_safe_redirect(add_query_arg(['page' => 'riyal-hisab-' . $tab, 'msg' => rawurlencode($msg), 't' => $error ? 'e' : 'o'], admin_url('admin.php')));
    exit;
}

add_action('admin_post_rh_owner', function () {
    if (!current_user_can('manage_options') || !check_admin_referer('rh_owner')) {
        wp_die('অনুমতি নেই');
    }
    global $wpdb;
    $name = mb_substr(sanitize_text_field(wp_unslash($_POST['name'] ?? '')), 0, 190);
    $login = rh_login_norm(wp_unslash($_POST['login'] ?? ''));
    $pass = (string) wp_unslash($_POST['password'] ?? '');
    $o = rh_owner();
    if ($name === '' || !preg_match('/^[a-z0-9_.+@]{4,64}$/', $login) || (!$o && strlen($pass) < 8) || ($pass !== '' && strlen($pass) < 8)) {
        rh_back('settings', 'নাম, লগইন (অন্তত ৪ অক্ষর, ইংরেজি/সংখ্যা) আর অন্তত ৮ অক্ষরের পাসওয়ার্ড দিন।', true);
    }
    $taken = $wpdb->get_var($wpdb->prepare('SELECT id FROM ' . rh_t('users') . ' WHERE login = %s', $login));
    if ($taken && (!$o || (int) $taken !== (int) $o['id'])) {
        rh_back('settings', 'এই লগইন অন্য কেউ ব্যবহার করছেন।', true);
    }
    $set = ['name' => $name, 'login' => $login, 'status' => 'active'];
    if ($pass !== '') {
        $set['pass_hash'] = password_hash($pass, PASSWORD_DEFAULT);
    }
    if ($o) {
        $wpdb->update(rh_t('users'), $set, ['id' => (int) $o['id']]);
        if ($pass !== '') {
            $wpdb->delete(rh_t('sessions'), ['user_id' => (int) $o['id']]);
        }
    } else {
        $wpdb->insert(rh_t('users'), $set + ['role' => 'owner', 'created_at' => rh_now()]);
    }
    rh_back('settings', 'মূল এডমিন রাখা হয়েছে।');
});

add_action('admin_post_rh_firebase', function () {
    if (!current_user_can('manage_options') || !check_admin_referer('rh_firebase')) {
        wp_die('অনুমতি নেই');
    }
    $services = trim((string) wp_unslash($_POST['services'] ?? ''));
    $account = trim((string) wp_unslash($_POST['account'] ?? ''));
    if ($services !== '') {
        $app = rh_firebase_from_services($services);
        if (!$app || $app['appId'] === '') {
            rh_back('settings', 'google-services.json-এ com.iamsaifsaiful.riyal_hisab অ্যাপ পাওয়া গেল না।', true);
        }
        update_option('rh_fcm_app', wp_json_encode($app), false);
    }
    if ($account !== '') {
        $j = json_decode($account, true);
        if (!is_array($j) || empty($j['client_email']) || empty($j['private_key']) || empty($j['project_id'])) {
            rh_back('settings', 'Service account JSON ঠিক নেই — পুরো ফাইলের লেখা দিন।', true);
        }
        update_option('rh_fcm_account', wp_json_encode($j), false);
        delete_transient('rh_fcm_token');
    }
    rh_back('settings', 'Firebase-এর সেটিং রাখা হয়েছে।');
});

function rh_styles() {
    ?>
    <style>
    .rh{font-family:'Noto Sans Bengali',system-ui,sans-serif;color:#1a1a1a;max-width:1400px}
    .rh *{box-sizing:border-box}
    .rh-head{background:#14284B;color:#fff;border-radius:18px;padding:18px 22px;margin:14px 0}
    .rh-brand{display:flex;gap:12px;align-items:center;margin-bottom:12px}
    .rh-brand b{display:block;font-size:19px}.rh-brand em{font-style:normal;opacity:.75;font-size:13px}
    .rh-mark{width:40px;height:40px;border-radius:50%;background:#2F6BEA;display:grid;place-items:center;font-size:20px}
    .rh-tabs{display:flex;flex-wrap:wrap;gap:6px}
    .rh-tabs a{color:#dce7fb;text-decoration:none;padding:7px 13px;border-radius:20px;font-size:14px}
    .rh-tabs a.on,.rh-tabs a:hover{background:#2F6BEA;color:#fff}
    .rh-figs{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:12px;margin:10px 0 18px}
    .rh-figs div{background:#fff;border-radius:16px;padding:16px}
    .rh-figs span{display:block;color:#6b6b6b;font-size:13px}.rh-figs strong{font-size:24px;display:block}.rh-figs em{font-style:normal;color:#6b6b6b;font-size:12.5px}
    .rh-filters{background:#fff;border-radius:16px;padding:12px 14px;display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin:0 0 12px}
    .rh-filters label{font-size:13px;color:#555;display:flex;gap:6px;align-items:center}
    .rh-filters input,.rh-filters select{border:1px solid #ddd;border-radius:10px;padding:5px 9px;min-height:34px}
    .rh-quick a{margin-left:6px;padding:4px 10px;border-radius:14px;background:#E9E9EB;text-decoration:none;color:#14284B;font-size:13px}
    .rh-quick a.on{background:#14284B;color:#fff}
    .rh-btn{background:#2F6BEA;color:#fff;border:0;border-radius:20px;padding:7px 18px;cursor:pointer;font-family:inherit;font-size:14px}
    .rh-link{color:#6b6b6b;font-size:13px}
    .rh-table{width:100%;border-collapse:separate;border-spacing:0;background:#fff;border-radius:16px;overflow:hidden;font-size:14px}
    .rh-table th{background:#E6EEFD;color:#14284B;text-align:left;padding:10px;font-weight:600}
    .rh-table td{padding:10px;border-top:1px solid #eee;vertical-align:top}
    .rh-table .r{text-align:right}.rh-table small{color:#6b6b6b}
    .rh-table tr.dim td{opacity:.5}
    .rh-empty{text-align:center;color:#6b6b6b;padding:26px!important}
    .rh-pill{display:inline-block;padding:2px 10px;border-radius:12px;font-size:12.5px;margin:2px 0}
    .rh-pill.green{background:#E3F4E7;color:#16833A}.rh-pill.red{background:#FDECEA;color:#C5221F}.rh-pill.gray{background:#E9E9EB;color:#555}
    .rh-pre{white-space:pre-wrap;font-size:11.5px;background:#F5F5F7;padding:8px;border-radius:8px;max-height:260px;overflow:auto}
    .red{color:#C5221F}.green{color:#16833A}
    .rh-sum{color:#14284B;font-weight:600;margin:4px 2px 10px}
    .rh-muted{color:#6b6b6b;font-size:13px}
    .rh-h{font-size:17px;margin:18px 0 8px}
    .rh-pager{display:flex;gap:6px;margin:12px 0;flex-wrap:wrap}
    .rh-pager a{padding:4px 10px;border-radius:10px;background:#fff;text-decoration:none}.rh-pager a.on{background:#14284B;color:#fff}
    .rh-face{width:28px;height:28px;border-radius:50%;object-fit:cover;vertical-align:middle;margin-right:8px}
    .rh-receipt img{width:46px;height:46px;object-fit:cover;border-radius:8px}
    .rh-cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:14px}
    .rh-card{background:#fff;border-radius:16px;padding:18px;display:flex;flex-direction:column;gap:10px}
    .rh-card h2{margin:0;font-size:18px}
    .rh-card label{display:flex;flex-direction:column;gap:4px;font-size:13px;color:#444}
    .rh-card input,.rh-card textarea{border:1px solid #ddd;border-radius:10px;padding:8px;font-family:monospace}
    .rh-card .rh-btn{align-self:flex-start}
    .rh-toast{background:#E3F4E7;color:#16833A;border-radius:12px;padding:10px 14px;margin:0 0 12px}.rh-toast.bad{background:#FDECEA;color:#C5221F}
    </style>
    <?php
}
