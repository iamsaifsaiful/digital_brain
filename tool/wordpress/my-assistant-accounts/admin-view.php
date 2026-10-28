<?php
/**
 * The admin page of My Assistant Accounts: members, their plan, and the
 * settings. Only draws; every change goes through admin-post.php with a nonce.
 */

if (!defined('ABSPATH')) {
    exit;
}

/** Status => [label, css class]. */
function ma_acc_status_labels() {
    return [
        'pro' => ['প্রিমিয়াম', 'pro'],
        'trial' => ['ট্রায়াল', 'trial'],
        'free' => ['ফ্রি', 'free'],
        'expired' => ['মেয়াদ শেষ', 'expired'],
        'waiting' => ['লগইনের অপেক্ষায়', 'waiting'],
    ];
}

function ma_acc_bn($s) {
    return strtr((string) $s, ['0' => '০', '1' => '১', '2' => '২', '3' => '৩', '4' => '৪', '5' => '৫', '6' => '৬', '7' => '৭', '8' => '৮', '9' => '৯']);
}

/** "১৬ অক্টো ২০২৬" in the site's time zone. */
function ma_acc_date($mysql) {
    $ts = ma_acc_ts($mysql);
    if (!$ts) {
        return '—';
    }
    $m = ['জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে'];
    $local = $ts + (int) (get_option('gmt_offset', 0) * HOUR_IN_SECONDS);
    return ma_acc_bn(gmdate('j', $local)) . ' ' . $m[(int) gmdate('n', $local) - 1] . ' ' . ma_acc_bn(gmdate('Y', $local));
}

/** "৩ ঘণ্টা আগে". */
function ma_acc_ago($mysql) {
    $ts = ma_acc_ts($mysql);
    if (!$ts) {
        return '—';
    }
    $d = max(0, time() - $ts);
    if ($d < 120) {
        return 'এইমাত্র';
    }
    if ($d < HOUR_IN_SECONDS) {
        return ma_acc_bn(floor($d / 60)) . ' মিনিট আগে';
    }
    if ($d < DAY_IN_SECONDS) {
        return ma_acc_bn(floor($d / HOUR_IN_SECONDS)) . ' ঘণ্টা আগে';
    }
    if ($d < 60 * DAY_IN_SECONDS) {
        return ma_acc_bn(floor($d / DAY_IN_SECONDS)) . ' দিন আগে';
    }
    return ma_acc_date($mysql);
}

/** Two letters for a member without a photo, and a steady colour for them. */
function ma_acc_initials($name, $email) {
    $src = trim($name) !== '' ? $name : $email;
    $parts = preg_split('/\s+/u', trim($src));
    $a = mb_substr($parts[0] ?? '?', 0, 1);
    $b = count($parts) > 1 ? mb_substr(end($parts), 0, 1) : '';
    return mb_strtoupper($a . $b);
}

function ma_acc_hue($email) {
    return [158, 196, 28, 262, 340, 210][abs(crc32((string) $email)) % 6];
}

function ma_acc_url($args) {
    return esc_url(add_query_arg(array_merge(['page' => 'my-assistant'], $args), admin_url('admin.php')));
}

function ma_acc_render($v) {
    $labels = ma_acc_status_labels();
    $s = $v['stats'];
    $tab = in_array($v['tab'], ['settings', 'ai', 'nlu', 'heirs', 'payments', 'notices', 'feedback', 'finance', 'errors', 'security'], true) ? $v['tab'] : 'members';
    $fb_new = (int) ($v['fb_new'] ?? 0);
    $pending = (int) ($v['pending'] ?? 0);
    $paying_rate = $s['total'] ? round($s['pro'] * 100 / $s['total'], 1) : 0;
    ?>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Hind+Siliguri:wght@400;500;600;700&display=swap">
    <?php ma_acc_styles(); ?>
    <div class="wrap ma">
        <h1 class="screen-reader-text">My Assistant</h1>
        <header class="ma-hero">
            <div class="ma-hero-top">
                <div class="ma-brand">
                    <span class="ma-mark" aria-hidden="true">
                        <svg viewBox="0 0 24 24" width="22" height="22"><path fill="currentColor" d="M12 2a4 4 0 0 1 4 4v6a4 4 0 0 1-8 0V6a4 4 0 0 1 4-4Zm0 2a2 2 0 0 0-2 2v6a2 2 0 1 0 4 0V6a2 2 0 0 0-2-2Zm-7 7a1 1 0 0 1 1 1 6 6 0 0 0 12 0 1 1 0 1 1 2 0 8 8 0 0 1-7 7.9V21h2a1 1 0 1 1 0 2H9a1 1 0 1 1 0-2h2v-2.1A8 8 0 0 1 4 12a1 1 0 0 1 1-1Z"/></svg>
                    </span>
                    <div>
                        <div class="ma-brand-name">My Assistant</div>
                        <div class="ma-brand-sub">সদস্য ও প্রিমিয়াম · getmyassistant.app</div>
                    </div>
                </div>
                <nav class="ma-tabs" aria-label="বিভাগ">
                    <a class="<?php echo $tab === 'members' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'members']); ?>">সদস্য</a>
                    <a class="<?php echo $tab === 'payments' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'payments']); ?>">পেমেন্ট<?php if ($pending) : ?><i class="ma-badge"><?php echo esc_html(ma_acc_bn($pending)); ?></i><?php endif; ?></a>
                    <a class="<?php echo $tab === 'notices' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'notices']); ?>">নোটিফিকেশন</a>
                    <a class="<?php echo $tab === 'feedback' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'feedback']); ?>">মতামত<?php if ($fb_new) : ?><i class="ma-badge"><?php echo esc_html(ma_acc_bn($fb_new)); ?></i><?php endif; ?></a>
                    <a class="<?php echo $tab === 'heirs' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'heirs']); ?>">উত্তরাধিকার<?php if (!empty($v['heirs_pending'])) : ?><i class="ma-badge"><?php echo esc_html(ma_acc_bn($v['heirs_pending'])); ?></i><?php endif; ?></a>
                    <a class="<?php echo $tab === 'nlu' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'nlu']); ?>">AI মডেল</a>
                    <a class="<?php echo $tab === 'errors' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'errors']); ?>">সমস্যার লগ</a>
                    <a class="<?php echo $tab === 'security' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'security']); ?>">নিরাপত্তা<?php if (ma_admin_app_otp() && !ma_totp_on(get_current_user_id())) : ?><i class="ma-badge">!</i><?php endif; ?></a>
                    <?php if (!empty($v['can_settings'])) : ?><a class="<?php echo $tab === 'finance' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'finance']); ?>">হিসাব</a><?php endif; ?>
                    <?php if (!empty($v['can_settings'])) : ?><a class="<?php echo $tab === 'ai' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'ai']); ?>">AI খরচ</a><?php endif; ?>
                    <?php if (!empty($v['can_settings'])) : ?><a class="<?php echo $tab === 'settings' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'settings']); ?>">সেটিংস</a><?php endif; ?>
                </nav>
            </div>
            <div class="ma-figures">
                <div class="ma-fig"><span>মোট সদস্য</span><strong><?php echo esc_html(ma_acc_bn(number_format($s['total']))); ?></strong><em>এ মাসে নতুন <?php echo esc_html(ma_acc_bn($s['month_new'] ?? 0)); ?> · আজ <?php echo esc_html(ma_acc_bn($s['today_new'] ?? 0)); ?></em></div>
                <div class="ma-fig"><span>প্রিমিয়াম</span><strong><?php echo esc_html(ma_acc_bn(number_format($s['pro']))); ?></strong><em><?php echo esc_html(ma_acc_bn($paying_rate)); ?>% সদস্য প্রিমিয়াম নিয়েছেন</em></div>
                <div class="ma-fig"><span>নতুন মতামত</span><strong><?php echo esc_html(ma_acc_bn(number_format($fb_new))); ?></strong><em>অ্যাপ থেকে সদস্যদের লেখা</em></div>
                <div class="ma-fig"><span>সক্রিয় (৭ দিনে)</span><strong><?php echo esc_html(ma_acc_bn(number_format($s['active']))); ?></strong><em>গত ৭ দিনে অ্যাপ খুলেছেন</em></div>
            </div>
        </header>

        <?php if ($v['msg'] !== '') : ?>
            <div class="ma-toast <?php echo $v['msg_type'] === 'error' ? 'bad' : ''; ?>" role="status"><?php echo esc_html($v['msg']); ?></div>
        <?php endif; ?>

        <?php if ($tab === 'ai' && !empty($v['can_settings'])) {
            ma_acc_render_ai_report($v);
        } elseif ($tab === 'heirs') {
            ma_acc_render_heirs($v['heirs'] ?? []);
        } elseif ($tab === 'nlu') {
            ma_acc_render_nlu($v['nlu'] ?? []);
        } elseif ($tab === 'errors') {
            ma_acc_render_errors();
        } elseif ($tab === 'security') {
            ma_acc_render_security();
        } elseif ($tab === 'settings' && !empty($v['can_settings'])) {
            ma_acc_render_settings($v);
        } elseif ($tab === 'payments') {
            ma_acc_render_payments($v);
        } elseif ($tab === 'notices') {
            ma_acc_render_notices($v);
        } elseif ($tab === 'finance' && !empty($v['can_settings'])) {
            ma_acc_render_finance($v['finance'] ?? []);
        } elseif ($tab === 'feedback') {
            ma_acc_render_feedback($v);
        } else {
            ma_acc_render_members($v, $labels);
        } ?>

        <p class="ma-foot">
            <svg viewBox="0 0 24 24" width="14" height="14" aria-hidden="true"><path fill="currentColor" d="M12 2 4 5v6c0 5 3.4 9.7 8 11 4.6-1.3 8-6 8-11V5l-8-3Zm0 2.2 6 2.2V11c0 4-2.6 7.8-6 9-3.4-1.2-6-5-6-9V6.4l6-2.2Z"/></svg>
            এখানে শুধু নাম, ইমেইল, ছবি আর প্রিমিয়ামের তথ্য পড়া যায়। সদস্যের হিসাব, নোট, পাসওয়ার্ড বা ব্যাকআপ পড়ার মতো করে কখনো এই সার্ভারে আসে না — ফ্যামিলি বা উত্তরাধিকারীর জন্য যা আসে, তা তালাবদ্ধ; সার্ভার খুলতে পারে না।
        </p>
    </div>
    <?php
    ma_acc_script();
}

function ma_acc_render_members($v, $labels) {
    $filters = ['' => 'সবাই', 'pro' => 'প্রিমিয়াম', 'trial' => 'ট্রায়াল', 'free' => 'ফ্রি', 'expired' => 'মেয়াদ শেষ', 'waiting' => 'অপেক্ষায়'];
    $joined = (string) ($v['joined'] ?? '');
    $src = (string) ($v['src'] ?? '');
    $keep = ['q' => $v['q'], 'status' => $v['status'], 'joined' => $joined, 'src' => $src];
    $g = $v['growth'] ?? null;
    $s = $v['stats'];
    $print = wp_nonce_url(add_query_arg(['action' => 'ma_acc_print'] + array_filter($keep, 'strlen'), admin_url('admin-post.php')), 'ma_acc_print');
    ?>
    <?php if ($g) :
        $max_d = max(1, max(array_column($g['days'], 'n')));
        $max_m = max(1, max(array_column($g['months'], 'n')));
        ?>
    <section class="ma-card" id="ma-growth">
        <div class="ma-bar">
            <div class="ma-bar-title"><h2>নতুন সদস্য</h2><span class="ma-count">এ মাসে <?php echo esc_html(ma_acc_bn($s['month_new'])); ?> · আজ <?php echo esc_html(ma_acc_bn($s['today_new'])); ?> · গত ৭ দিনে <?php echo esc_html(ma_acc_bn($s['week'])); ?></span></div>
            <div class="ma-seg" role="tablist"><button type="button" class="on" data-grow="days">দৈনিক</button><button type="button" data-grow="months">মাসিক</button></div>
        </div>
        <div class="ma-growth" data-g="days">
            <?php foreach ($g['days'] as $d) : $h = $d['n'] ? max(6, round($d['n'] / $max_d * 100)) : 2; ?>
                <a class="ma-gbar <?php echo $joined === $d['day'] ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['joined' => $d['day']]); ?>#ma-list" title="<?php echo esc_attr(ma_acc_date($d['day'] . ' 06:00:00') . ': ' . ma_acc_bn($d['n']) . ' জন'); ?>"><i style="height:<?php echo (int) $h; ?>%"></i><b><?php echo $d['n'] ? esc_html(ma_acc_bn($d['n'])) : ''; ?></b><span><?php echo esc_html(ma_acc_bn((int) substr($d['day'], 8, 2))); ?></span></a>
            <?php endforeach; ?>
        </div>
        <div class="ma-growth months" data-g="months" hidden>
            <?php foreach ($g['months'] as $m) : $h = $m['n'] ? max(6, round($m['n'] / $max_m * 100)) : 2; ?>
                <a class="ma-gbar <?php echo $joined === $m['month'] ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['joined' => $m['month']]); ?>#ma-list" title="<?php echo esc_attr(ma_acc_month_name($m['month']) . ': ' . ma_acc_bn($m['n']) . ' জন'); ?>"><i style="height:<?php echo (int) $h; ?>%"></i><b><?php echo $m['n'] ? esc_html(ma_acc_bn($m['n'])) : ''; ?></b><span><?php echo esc_html(ma_acc_month_name($m['month'])); ?></span></a>
            <?php endforeach; ?>
        </div>
        <div class="ma-src-line">
            <span class="muted">এখন প্রিমিয়াম যেখান থেকে:</span>
            <?php foreach ($g['sources'] as $x) : ?>
                <a class="ma-chip <?php echo $src === $x['key'] ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['src' => $src === $x['key'] ? '' : $x['key'], 'status' => $v['status'], 'joined' => $joined, 'q' => $v['q']]); ?>#ma-list"><?php echo esc_html($x['label'] . ' · ' . ma_acc_bn($x['n'])); ?></a>
            <?php endforeach; ?>
        </div>
    </section>
    <?php endif; ?>
    <section class="ma-card" id="ma-list">
        <div class="ma-bar">
            <div class="ma-bar-title">
                <h2>সদস্য</h2>
                <span class="ma-count"><?php echo esc_html(ma_acc_bn($v['found'])); ?> জন<?php echo ($joined !== '' || $src !== '') ? ' · ' . esc_html(ma_acc_filter_words('', '', $joined, $src)) : ''; ?></span>
            </div>
            <div class="ma-bar-actions">
                <a class="ma-btn ghost" href="<?php echo esc_url($print); ?>" target="_blank" rel="noopener">
                    <svg viewBox="0 0 24 24" width="17" height="17" aria-hidden="true"><path fill="currentColor" d="M6 2h8l6 6v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2Zm7 1.5V9h5.5L13 3.5ZM7 13v5h1.5v-1.6h.9c1.1 0 1.9-.7 1.9-1.7S10.5 13 9.4 13H7Zm1.5 1.2h.8c.3 0 .5.2.5.5s-.2.5-.5.5h-.8v-1Zm3.6-1.2v5h1.7c1.4 0 2.4-1 2.4-2.5S15.2 13 13.8 13h-1.7Zm1.5 1.3h.2c.6 0 1 .5 1 1.2s-.4 1.2-1 1.2h-.2v-2.4Z"/></svg>
                    PDF
                </a>
                <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
                    <input type="hidden" name="action" value="ma_acc_export">
                    <?php foreach ($keep as $k => $x) : ?><input type="hidden" name="<?php echo esc_attr($k); ?>" value="<?php echo esc_attr($x); ?>"><?php endforeach; ?>
                    <?php wp_nonce_field('ma_acc_export'); ?>
                    <button class="ma-btn ghost" type="submit">
                        <svg viewBox="0 0 24 24" width="17" height="17" aria-hidden="true"><path fill="currentColor" d="M12 3a1 1 0 0 1 1 1v8.6l2.3-2.3a1 1 0 1 1 1.4 1.4l-4 4a1 1 0 0 1-1.4 0l-4-4a1 1 0 1 1 1.4-1.4l2.3 2.3V4a1 1 0 0 1 1-1ZM5 17a1 1 0 0 1 1 1v1h12v-1a1 1 0 1 1 2 0v2a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-2a1 1 0 0 1 1-1Z"/></svg>
                        Excel
                    </button>
                </form>
                <button class="ma-btn" type="button" data-open="ma-add">
                    <svg viewBox="0 0 24 24" width="17" height="17" aria-hidden="true"><path fill="currentColor" d="M12 5a1 1 0 0 1 1 1v5h5a1 1 0 1 1 0 2h-5v5a1 1 0 1 1-2 0v-5H6a1 1 0 1 1 0-2h5V6a1 1 0 0 1 1-1Z"/></svg>
                    সদস্য যোগ করুন
                </button>
            </div>
        </div>

        <form class="ma-tools" method="get" action="<?php echo esc_url(admin_url('admin.php')); ?>">
            <input type="hidden" name="page" value="my-assistant">
            <input type="hidden" name="status" value="<?php echo esc_attr($v['status']); ?>">
            <input type="hidden" name="joined" value="<?php echo esc_attr($joined); ?>">
            <input type="hidden" name="src" value="<?php echo esc_attr($src); ?>">
            <label class="ma-search">
                <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M10.5 3a7.5 7.5 0 0 1 5.9 12.1l4.3 4.2a1 1 0 0 1-1.4 1.4l-4.2-4.3A7.5 7.5 0 1 1 10.5 3Zm0 2a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11Z"/></svg>
                <input type="search" name="q" value="<?php echo esc_attr($v['q']); ?>" placeholder="নাম বা ইমেইল দিয়ে খুঁজুন">
            </label>
            <div class="ma-chips" role="tablist">
                <?php foreach ($filters as $key => $label) : ?>
                    <a class="ma-chip <?php echo $v['status'] === $key ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['status' => $key, 'q' => $v['q'], 'joined' => $joined, 'src' => $src]); ?>#ma-list"><?php echo esc_html($label); ?></a>
                <?php endforeach; ?>
            </div>
        </form>
        <form class="ma-tools ma-when" method="get" action="<?php echo esc_url(admin_url('admin.php')); ?>">
            <input type="hidden" name="page" value="my-assistant">
            <input type="hidden" name="status" value="<?php echo esc_attr($v['status']); ?>">
            <input type="hidden" name="q" value="<?php echo esc_attr($v['q']); ?>">
            <input type="hidden" name="src" value="<?php echo esc_attr($src); ?>">
            <span class="muted">যোগ দিয়েছেন:</span>
            <div class="ma-chips">
                <?php foreach (['' => 'যেকোনো সময়', 'today' => 'আজ', 'week' => 'গত ৭ দিন', 'month' => 'এই মাস'] as $k => $l) : ?>
                    <a class="ma-chip <?php echo $joined === $k ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['joined' => $k, 'status' => $v['status'], 'q' => $v['q'], 'src' => $src]); ?>#ma-list"><?php echo esc_html($l); ?></a>
                <?php endforeach; ?>
            </div>
            <label class="ma-inline">মাস<input type="month" name="jm" value="<?php echo esc_attr(preg_match('/^\d{4}-\d{2}$/', $joined) ? $joined : ''); ?>" onchange="this.form.jd.value='';this.form.submit()"></label>
            <label class="ma-inline">দিন<input type="date" name="jd" value="<?php echo esc_attr(preg_match('/^\d{4}-\d{2}-\d{2}$/', $joined) ? $joined : ''); ?>" onchange="this.form.jm.value='';this.form.submit()"></label>
        </form>

        <?php if (!$v['rows']) : ?>
            <div class="ma-empty">
                <div class="ma-empty-art" aria-hidden="true">
                    <svg viewBox="0 0 24 24" width="34" height="34"><path fill="currentColor" d="M9 4a4 4 0 1 1 0 8 4 4 0 0 1 0-8Zm0 2a2 2 0 1 0 0 4 2 2 0 0 0 0-4Zm7.5 1a3 3 0 1 1 0 6 3 3 0 0 1 0-6ZM9 13c3.3 0 6 1.6 6 4v2H3v-2c0-2.4 2.7-4 6-4Zm7.5 1c2.5 0 4.5 1.2 4.5 3v2h-4v-2c0-1.1-.4-2.1-1.1-2.9l.6-.1Z"/></svg>
                </div>
                <?php if ($v['q'] !== '' || $v['status'] !== '' || $joined !== '' || $src !== '') : ?>
                    <h3>কাউকে পাওয়া যায়নি</h3>
                    <p>অন্য নাম বা ইমেইল দিয়ে খুঁজুন, অথবা <a href="<?php echo ma_acc_url([]); ?>">সবাইকে দেখুন</a>।</p>
                <?php else : ?>
                    <h3>এখনো কোনো সদস্য নেই</h3>
                    <p>অ্যাপে কেউ Google দিয়ে লগইন করলেই এখানে দেখা যাবে। আগে <a href="<?php echo ma_acc_url(['tab' => 'settings']); ?>">সেটিংসে</a> Google Client ID বসিয়ে নিন।</p>
                <?php endif; ?>
            </div>
        <?php else : ?>
            <div class="ma-table-wrap">
                <table class="ma-table">
                    <thead>
                        <tr>
                            <th>সদস্য</th>
                            <th class="hide-s">যোগ দিয়েছেন</th>
                            <th class="hide-m">শেষ দেখা</th>
                            <th>অবস্থা · কোথা থেকে</th>
                            <th class="hide-s">প্রিমিয়াম পর্যন্ত</th>
                            <th class="right">কাজ</th>
                        </tr>
                    </thead>
                    <tbody>
                    <?php foreach ($v['rows'] as $r) :
                        $st = ma_acc_status($r);
                        [$label, $cls] = $labels[$st];
                        $data = [
                            'id' => (int) $r['id'],
                            'name' => $r['name'] !== '' ? $r['name'] : $r['email'],
                            'email' => $r['email'],
                            'status' => $label,
                            'joined' => ma_acc_date($r['created_at']),
                            'seen' => $st === 'waiting' ? '—' : ma_acc_ago($r['last_seen']),
                            'until' => ma_acc_date($r['pro_until']),
                            'kind' => ma_acc_source_label($r),
                            'trial' => ma_acc_date($r['trial_started']),
                            'version' => trim(ma_acc_bn($r['app_version']) . ' ' . ($r['edition'] === 'play' ? 'Play' : ($r['edition'] === 'play_preview' ? 'প্রিভিউ' : ($r['edition'] === 'direct' ? 'APK' : '')))),
                            'note' => $r['note'],
                            'pro' => in_array($st, ['pro', 'trial'], true),
                        ];
                        ?>
                        <tr>
                            <td>
                                <div class="ma-who">
                                    <?php if ($r['picture'] !== '') : ?>
                                        <img class="ma-av" src="<?php echo esc_url($r['picture']); ?>" alt="" loading="lazy" referrerpolicy="no-referrer">
                                    <?php else : ?>
                                        <span class="ma-av" style="--h:<?php echo (int) ma_acc_hue($r['email']); ?>"><?php echo esc_html(ma_acc_initials($r['name'], $r['email'])); ?></span>
                                    <?php endif; ?>
                                    <div class="ma-who-text">
                                        <strong><?php echo esc_html($data['name']); ?></strong>
                                        <span><?php echo esc_html($r['email']); ?></span>
                                    </div>
                                </div>
                            </td>
                            <td class="hide-s muted"><?php echo esc_html($data['joined']); ?></td>
                            <td class="hide-m muted"><?php echo esc_html($data['seen']); ?><?php if ($data['version'] !== '') : ?><span class="ma-ver"><?php echo esc_html($data['version']); ?></span><?php endif; ?></td>
                            <td><span class="ma-pill <?php echo esc_attr($cls); ?>"><?php echo esc_html($label); ?></span><?php if ($data['kind'] !== '—' && $st !== 'free') : ?><span class="ma-ver"><?php echo esc_html($data['kind']); ?></span><?php endif; ?></td>
                            <td class="hide-s muted"><?php echo esc_html(in_array($st, ['pro', 'trial', 'waiting'], true) ? $data['until'] : '—'); ?></td>
                            <td class="right">
                                <div class="ma-ops">
                                    <button type="button" class="ma-icon" title="বিস্তারিত" aria-label="বিস্তারিত: <?php echo esc_attr($data['name']); ?>" data-open="ma-view" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>">
                                        <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M12 5c5 0 8.6 4.3 9.7 6.4a1.3 1.3 0 0 1 0 1.2C20.6 14.7 17 19 12 19s-8.6-4.3-9.7-6.4a1.3 1.3 0 0 1 0-1.2C3.4 9.3 7 5 12 5Zm0 2c-3.6 0-6.4 3-7.6 5 1.2 2 4 5 7.6 5s6.4-3 7.6-5c-1.2-2-4-5-7.6-5Zm0 2a3 3 0 1 1 0 6 3 3 0 0 1 0-6Z"/></svg>
                                    </button>
                                    <button type="button" class="ma-icon" title="প্রিমিয়াম ও নোট" aria-label="প্রিমিয়াম ও নোট: <?php echo esc_attr($data['name']); ?>" data-open="ma-edit" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>">
                                        <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M15.6 3.6a2 2 0 0 1 2.8 0l2 2a2 2 0 0 1 0 2.8L9.2 19.6a2 2 0 0 1-1 .5l-3.9.9a1 1 0 0 1-1.2-1.2l.9-3.9c.1-.4.3-.7.5-1L15.6 3.6ZM17 5l-11 11-.5 2.5L8 18 19 7l-2-2Z"/></svg>
                                    </button>
                                    <button type="button" class="ma-icon danger" title="মুছুন" aria-label="মুছুন: <?php echo esc_attr($data['name']); ?>" data-open="ma-delete" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>">
                                        <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M9 3h6a1 1 0 0 1 1 1v1h4a1 1 0 1 1 0 2h-1l-.9 12.1A2 2 0 0 1 16.1 21H7.9a2 2 0 0 1-2-1.9L5 7H4a1 1 0 0 1 0-2h4V4a1 1 0 0 1 1-1Zm-2 4 .9 12h8.2L17 7H7Zm3 2a1 1 0 0 1 1 1v6a1 1 0 1 1-2 0v-6a1 1 0 0 1 1-1Zm4 0a1 1 0 0 1 1 1v6a1 1 0 1 1-2 0v-6a1 1 0 0 1 1-1Z"/></svg>
                                    </button>
                                    <button type="button" class="ma-btn small <?php echo $data['pro'] ? 'soft' : ''; ?>" data-open="ma-edit" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>"><?php echo $data['pro'] ? 'মেয়াদ বাড়ান' : 'প্রিমিয়াম দিন'; ?></button>
                                </div>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
            <?php if ($v['pages'] > 1) : ?>
                <nav class="ma-pages" aria-label="পাতা">
                    <span class="muted">পাতা <?php echo esc_html(ma_acc_bn($v['page'])); ?> / <?php echo esc_html(ma_acc_bn($v['pages'])); ?></span>
                    <div>
                        <?php if ($v['page'] > 1) : ?><a class="ma-btn ghost small" href="<?php echo ma_acc_url(['paged' => $v['page'] - 1] + $keep); ?>#ma-list">← আগের</a><?php endif; ?>
                        <?php if ($v['page'] < $v['pages']) : ?><a class="ma-btn ghost small" href="<?php echo ma_acc_url(['paged' => $v['page'] + 1] + $keep); ?>#ma-list">পরের →</a><?php endif; ?>
                    </div>
                </nav>
            <?php endif; ?>
        <?php endif; ?>
    </section>

    <?php $post = esc_url(admin_url('admin-post.php')); ?>
    <dialog class="ma-dialog" id="ma-add">
        <form method="post" action="<?php echo $post; ?>">
            <input type="hidden" name="action" value="ma_acc_add">
            <?php wp_nonce_field('ma_acc_add'); ?>
            <h3>সদস্য যোগ করুন</h3>
            <p class="muted">যেমন: কেউ ওয়েবসাইটে বিকাশে প্রিমিয়াম কিনেছেন। তাঁর Google ইমেইল দিন — অ্যাপে সেই ইমেইলে লগইন করলেই প্রিমিয়াম চালু হবে।</p>
            <label>Google ইমেইল<input type="email" name="email" required placeholder="name@gmail.com"></label>
            <label>নাম (ঐচ্ছিক)<input type="text" name="name"></label>
            <fieldset class="ma-days"><legend>প্রিমিয়াম কত দিনের</legend>
                <?php foreach ([0 => 'প্রিমিয়াম ছাড়া', 30 => '১ মাস', 365 => '১ বছর'] as $d => $l) : ?>
                    <label><input type="radio" name="days" value="<?php echo (int) $d; ?>" <?php checked($d, 365); ?>><span><?php echo esc_html($l); ?></span></label>
                <?php endforeach; ?>
            </fieldset>
            <label>নোট (ঐচ্ছিক)<input type="text" name="note" placeholder="যেমন: বিকাশ TrxID 9A7…"></label>
            <div class="ma-dialog-actions"><button type="button" class="ma-btn ghost" data-close>বাতিল</button><button class="ma-btn" type="submit">যোগ করুন</button></div>
        </form>
    </dialog>

    <dialog class="ma-dialog" id="ma-view">
        <div class="ma-view-head"><span class="ma-av big" data-f="initial"></span><div><h3 data-f="name"></h3><span class="muted" data-f="email"></span></div></div>
        <dl class="ma-dl">
            <dt>অবস্থা</dt><dd data-f="status"></dd>
            <dt>প্রিমিয়াম পর্যন্ত</dt><dd data-f="until"></dd>
            <dt>প্রিমিয়াম কোথা থেকে</dt><dd data-f="kind"></dd>
            <dt>ট্রায়াল শুরু</dt><dd data-f="trial"></dd>
            <dt>যোগ দিয়েছেন</dt><dd data-f="joined"></dd>
            <dt>শেষ দেখা</dt><dd data-f="seen"></dd>
            <dt>অ্যাপ</dt><dd data-f="version"></dd>
            <dt>নোট</dt><dd data-f="note"></dd>
        </dl>
        <div class="ma-dialog-actions"><button type="button" class="ma-btn" data-close>ঠিক আছে</button></div>
    </dialog>

    <dialog class="ma-dialog" id="ma-edit">
        <form method="post" action="<?php echo $post; ?>">
            <input type="hidden" name="action" value="ma_acc_edit">
            <input type="hidden" name="id" data-f="id">
            <?php wp_nonce_field('ma_acc_edit'); ?>
            <h3>প্রিমিয়াম ও নোট</h3>
            <p class="muted"><span data-f="name"></span> · এখন: <strong data-f="status"></strong>, প্রিমিয়াম পর্যন্ত <span data-f="until"></span></p>
            <fieldset class="ma-days"><legend>প্রিমিয়াম যোগ করুন (চলমান মেয়াদের পরে যোগ হবে)</legend>
                <?php foreach ([0 => 'বদল নেই', 30 => '+১ মাস', 90 => '+৩ মাস', 365 => '+১ বছর'] as $d => $l) : ?>
                    <label><input type="radio" name="days" value="<?php echo (int) $d; ?>" <?php checked($d, 0); ?>><span><?php echo esc_html($l); ?></span></label>
                <?php endforeach; ?>
            </fieldset>
            <label class="ma-check"><input type="checkbox" name="mode" value="stop"> প্রিমিয়াম এখনই বন্ধ করুন</label>
            <label>নোট<input type="text" name="note" data-f="note" maxlength="500"></label>
            <div class="ma-dialog-actions"><button type="button" class="ma-btn ghost" data-close>বাতিল</button><button class="ma-btn" type="submit">রাখুন</button></div>
        </form>
    </dialog>

    <dialog class="ma-dialog narrow" id="ma-delete">
        <form method="post" action="<?php echo $post; ?>">
            <input type="hidden" name="action" value="ma_acc_delete">
            <input type="hidden" name="id" data-f="id">
            <?php wp_nonce_field('ma_acc_delete'); ?>
            <h3>সদস্যের তথ্য মুছবেন?</h3>
            <p class="muted"><strong data-f="name"></strong> (<span data-f="email"></span>)-এর নাম, ইমেইল আর প্রিমিয়ামের তথ্য মুছে যাবে। অ্যাপে তাঁর নিজের তথ্য যেমন আছে থাকবে।</p>
            <div class="ma-dialog-actions"><button type="button" class="ma-btn ghost" data-close>বাতিল</button><button class="ma-btn danger" type="submit">মুছুন</button></div>
        </form>
    </dialog>
    <?php
}

function ma_acc_render_payments($v) {
    $labels = ma_pay_labels();
    $plans = $v['plans'];
    $c = $v['pay_counts'];
    $post = esc_url(admin_url('admin-post.php'));
    $tabs = ['pending' => 'দেখার অপেক্ষায়', 'approved' => 'অনুমোদিত', 'rejected' => 'বাতিল', 'all' => 'সব'];
    ?>
    <div class="ma-ai-stats ma-pay-sum">
        <div><strong><?php echo esc_html(ma_acc_bn($c['pending']['n'] ?? 0)); ?></strong><span>দেখার অপেক্ষায়</span></div>
        <div><strong>৳<?php echo esc_html(ma_acc_bn(number_format($v['pay_month']))); ?></strong><span>এই মাসে অনুমোদিত</span></div>
        <div><strong><?php echo esc_html(ma_acc_bn($c['approved']['n'] ?? 0)); ?></strong><span>মোট অনুমোদিত</span></div>
        <div><strong>৳<?php echo esc_html(ma_acc_bn(number_format($c['approved']['amt'] ?? 0))); ?></strong><span>মোট আয় (ওয়েবসাইট)</span></div>
    </div>
    <?php $bk = $v['bkash'] ?? null; if ($bk) : $bl = ma_bk_status_labels(); ?>
    <section class="ma-card">
        <div class="ma-bar">
            <div class="ma-bar-title"><h2>বিকাশে আসা টাকা</h2><span class="ma-count">পেমেন্টের সিমের ফোন থেকে</span></div>
            <div class="ma-bar-actions">
                <button class="ma-btn ghost" type="button" data-open="ma-bk-paste">বিকাশের SMS পেস্ট করুন</button>
                <form method="post" action="<?php echo $post; ?>" class="ma-inline-form">
                    <input type="hidden" name="action" value="ma_bk_settings"><?php wp_nonce_field('ma_bk_settings'); ?>
                    <input type="hidden" name="auto" value="<?php echo $bk['auto'] ? '' : '1'; ?>">
                    <button class="ma-btn <?php echo $bk['auto'] ? 'soft' : ''; ?>" type="submit"><?php echo $bk['auto'] ? '✓ নিজে থেকে অনুমোদন চালু' : 'নিজে থেকে অনুমোদন চালু করুন'; ?></button>
                </form>
            </div>
        </div>
        <div class="ma-bk-status">
            <div class="<?php echo $bk['phone_set'] ? 'ok' : 'bad'; ?>">
                <strong><?php echo $bk['phone_set'] ? 'ফোন যুক্ত আছে' : 'ফোন এখনো যুক্ত হয়নি'; ?></strong>
                <span><?php echo $bk['last_sms'] ? 'শেষ SMS এসেছে ' . esc_html(ma_acc_ago(gmdate('Y-m-d H:i:s', strtotime($bk['last_sms'])))) : 'যে ফোনে পেমেন্টের বিকাশ সিম আছে, তাতে অ্যাডমিন অ্যাপ খুলে: পেমেন্ট › বিকাশ মেলানো › “এই ফোনে চালু করুন”।'; ?></span>
            </div>
            <div class="ok"><strong>যা আসে</strong><span>শুধু টাকা, TrxID, কোন নম্বর থেকে, কখন, আর ব্যালেন্স মিলেছে কিনা (হ্যাঁ/না) — ব্যালেন্সের অঙ্ক, মেসেজের বাকি লেখা বা ফোনের অন্য কিছু আসে না।</span></div>
            <div class="ok"><strong>কখন চালু হয়</strong><span>নিজে থেকে অনুমোদন চালু থাকলে: TrxID মিললে, অন্তত প্ল্যানের দাম এলে, আর পেমেন্টের ফোন বিকাশের ব্যালেন্স মিলিয়ে মেসেজটা আসল বলে নিশ্চিত হলে। ভুয়া “bKash” SMS ব্যালেন্স জানে না, তাই সেটা আপনার জন্য অপেক্ষা করে। ফোন যুক্ত করার পর প্রথম মেসেজটাও অপেক্ষা করে (তখনো আগের ব্যালেন্স জানা থাকে না)।</span></div>
        </div>
        <?php if ($bk['received']) : ?>
            <div class="ma-table-wrap">
                <table class="ma-table">
                    <thead><tr><th>TrxID</th><th>টাকা</th><th>কোন নম্বর থেকে</th><th class="hide-s">কখন</th><th>অবস্থা</th></tr></thead>
                    <tbody>
                    <?php foreach ($bk['received'] as $r) : $l = $bl[$r['status']] ?? [$r['status'], 'free']; ?>
                        <tr>
                            <td class="ma-mono"><?php echo esc_html($r['trx']); ?><?php if ($r['source'] === 'manual') : ?><span class="ma-ver">হাতে পেস্ট</span><?php endif; ?></td>
                            <td><strong>৳<?php echo esc_html(ma_acc_bn(number_format($r['amount']))); ?></strong></td>
                            <td class="ma-mono"><?php echo esc_html($r['sender'] !== '' ? $r['sender'] : '—'); ?></td>
                            <td class="hide-s muted"><?php echo esc_html(ma_acc_ago(gmdate('Y-m-d H:i:s', strtotime($r['at'])))); ?></td>
                            <td><span class="ma-pill <?php echo esc_attr($l[1]); ?>"><?php echo esc_html($l[0]); ?></span></td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        <?php else : ?>
            <p class="muted ma-pad">এখনো বিকাশ থেকে কিছু আসেনি।</p>
        <?php endif; ?>
    </section>
    <dialog class="ma-dialog" id="ma-bk-paste">
        <form method="post" action="<?php echo $post; ?>">
            <input type="hidden" name="action" value="ma_bk_paste"><?php wp_nonce_field('ma_bk_paste'); ?>
            <h3>বিকাশের SMS পেস্ট করুন</h3>
            <p class="muted">ফোন যুক্ত না থাকলে বা কোনো SMS বাদ পড়লে: বিকাশের “You have received Tk …” মেসেজটা পুরোটা পেস্ট করুন। এখান থেকে শুধু টাকা, TrxID, নম্বর আর সময় পড়ে রাখা হয়।</p>
            <label>মেসেজ<textarea name="text" rows="5" required placeholder="You have received Tk 999.00 from 01XXXXXXXXX. … TrxID 9A7KX2PQ1M at 27/10/2026 15:02"></textarea></label>
            <div class="ma-dialog-actions"><button type="button" class="ma-btn ghost" data-close>বাতিল</button><button class="ma-btn" type="submit">মেলান</button></div>
        </form>
    </dialog>
    <?php endif; ?>
    <section class="ma-card">
        <div class="ma-bar">
            <div class="ma-bar-title"><h2>পেমেন্ট</h2><span class="ma-count">ওয়েবসাইট থেকে জমা</span></div>
            <div class="ma-bar-actions"><button class="ma-btn ghost" type="button" data-open="ma-pay-set">পেমেন্টের মাধ্যম ও দাম</button></div>
        </div>
        <div class="ma-tools">
            <div class="ma-chips">
                <?php foreach ($tabs as $k => $l) : ?>
                    <a class="ma-chip <?php echo $v['pst'] === $k ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'payments', 'pst' => $k]); ?>"><?php echo esc_html($l); ?><?php if ($k !== 'all' && !empty($c[$k]['n'])) : ?> · <?php echo esc_html(ma_acc_bn($c[$k]['n'])); ?><?php endif; ?></a>
                <?php endforeach; ?>
            </div>
        </div>
        <?php if (!$v['payments']) : ?>
            <div class="ma-empty">
                <div class="ma-empty-art" aria-hidden="true"><svg viewBox="0 0 24 24" width="34" height="34"><path fill="currentColor" d="M4 5h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V7a2 2 0 0 1 2-2Zm0 2v2h16V7H4Zm0 5v5h16v-5H4Zm2 2h5v2H6v-2Z"/></svg></div>
                <h3><?php echo $v['pst'] === 'pending' ? 'দেখার মতো কোনো পেমেন্ট নেই' : 'এখানে কিছু নেই'; ?></h3>
                <p>ওয়েবসাইটের যেকোনো পাতায় <code>[my_assistant_payment]</code> লিখলে পেমেন্টের ফর্ম দেখাবে। কেউ জমা দিলে এখানে আসবে, আর আপনার ইমেইলেও জানানো হবে।</p>
            </div>
        <?php else : ?>
            <div class="ma-table-wrap">
                <table class="ma-table">
                    <thead><tr><th>কে</th><th>প্ল্যান</th><th>মাধ্যম ও নম্বর</th><th>ট্রানজেকশন আইডি</th><th class="hide-s">কবে</th><th>অবস্থা</th><th class="right">কাজ</th></tr></thead>
                    <tbody>
                    <?php foreach ($v['payments'] as $p) :
                        [$label, $cls] = $labels[$p['status']] ?? $labels['pending'];
                        $data = ['id' => (int) $p['id'], 'name' => $p['name'] !== '' ? $p['name'] : $p['email'], 'email' => $p['email'], 'trx' => $p['trx'], 'method' => $p['method'], 'sender' => $p['sender'],
                            'amount' => '৳' . ma_acc_bn($p['amount']), 'plan' => $plans[$p['plan']]['label'] ?? $p['plan'], 'note' => $p['note'], 'phone' => $p['phone']];
                        ?>
                        <tr>
                            <td><div class="ma-who-text"><strong><?php echo esc_html($data['name']); ?></strong><span><?php echo esc_html($p['email']); ?></span></div></td>
                            <td><strong>৳<?php echo esc_html(ma_acc_bn($p['amount'])); ?></strong><span class="ma-ver"><?php echo esc_html($data['plan']); ?></span></td>
                            <td><?php echo esc_html($p['method']); ?><span class="ma-ver ma-mono"><?php echo esc_html($p['sender']); ?></span></td>
                            <td><span class="ma-code"><code id="trx-<?php echo (int) $p['id']; ?>"><?php echo esc_html($p['trx']); ?></code><button type="button" class="ma-icon" data-copy="trx-<?php echo (int) $p['id']; ?>" title="কপি" aria-label="কপি"><svg viewBox="0 0 24 24" width="15" height="15" aria-hidden="true"><path fill="currentColor" d="M8 3h10a2 2 0 0 1 2 2v12h-2V5H8V3Zm-3 4h10a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2Zm0 2v10h10V9H5Z"/></svg></button></span></td>
                            <td class="hide-s muted"><?php echo esc_html(ma_acc_ago($p['created_at'])); ?></td>
                            <td><span class="ma-pill <?php echo esc_attr($cls); ?>"><?php echo esc_html($label); ?></span><?php if ($p['reason'] !== '') : ?><span class="ma-ver"><?php echo esc_html($p['reason']); ?></span><?php endif; ?></td>
                            <td class="right">
                                <?php if ($p['status'] === 'pending') : ?>
                                    <div class="ma-ops">
                                        <button type="button" class="ma-btn small ghost" data-open="ma-pay-no" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>">বাতিল</button>
                                        <button type="button" class="ma-btn small" data-open="ma-pay-yes" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>">অনুমোদন</button>
                                    </div>
                                <?php else : ?>
                                    <span class="muted"><?php echo esc_html(ma_acc_date($p['reviewed_at'])); ?></span>
                                <?php endif; ?>
                            </td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        <?php endif; ?>
    </section>

    <dialog class="ma-dialog" id="ma-pay-yes">
        <form method="post" action="<?php echo $post; ?>">
            <input type="hidden" name="action" value="ma_pay_review"><input type="hidden" name="decision" value="approve"><input type="hidden" name="id" data-f="id">
            <?php wp_nonce_field('ma_pay_review'); ?>
            <h3>পেমেন্ট মিলেছে?</h3>
            <p class="muted">আগে নিজের <strong data-f="method"></strong> অ্যাকাউন্টে দেখে নিন — এই নম্বর থেকে এই TrxID-তে টাকা এসেছে কি না।</p>
            <dl class="ma-dl">
                <dt>টাকা</dt><dd><span data-f="amount"></span> · <span data-f="plan"></span></dd>
                <dt>যে নম্বর থেকে</dt><dd class="ma-mono" data-f="sender"></dd>
                <dt>TrxID</dt><dd class="ma-mono" data-f="trx"></dd>
                <dt>প্রিমিয়াম পাবেন</dt><dd data-f="email"></dd>
                <dt>নোট</dt><dd data-f="note"></dd>
            </dl>
            <div class="ma-dialog-actions"><button type="button" class="ma-btn ghost" data-close>পরে</button><button class="ma-btn" type="submit">মিলেছে — প্রিমিয়াম দিন</button></div>
        </form>
    </dialog>

    <dialog class="ma-dialog" id="ma-pay-no">
        <form method="post" action="<?php echo $post; ?>">
            <input type="hidden" name="action" value="ma_pay_review"><input type="hidden" name="decision" value="reject"><input type="hidden" name="id" data-f="id">
            <?php wp_nonce_field('ma_pay_review'); ?>
            <h3>পেমেন্ট বাতিল করবেন?</h3>
            <p class="muted"><span data-f="name"></span> · <span data-f="method"></span> · <span class="ma-mono" data-f="trx"></span></p>
            <label>কারণ (ঐচ্ছিক)<input type="text" name="reason" maxlength="300" placeholder="যেমন: এই TrxID-তে কোনো টাকা আসেনি"></label>
            <label class="ma-check"><input type="checkbox" name="tell" value="1" checked> ইমেইলে জানিয়ে দিন</label>
            <div class="ma-dialog-actions"><button type="button" class="ma-btn ghost" data-close>ফিরে যান</button><button class="ma-btn danger" type="submit">বাতিল করুন</button></div>
        </form>
    </dialog>

    <dialog class="ma-dialog" id="ma-pay-set">
        <form method="post" action="<?php echo $post; ?>">
            <input type="hidden" name="action" value="ma_pay_settings">
            <?php wp_nonce_field('ma_pay_settings'); ?>
            <h3>পেমেন্টের মাধ্যম ও দাম</h3>
            <div class="ma-ai-row two">
                <label>বার্ষিক (৳)<input type="text" inputmode="numeric" name="yearly" value="<?php echo (int) $plans['yearly']['price']; ?>"></label>
                <label>মাসিক (৳)<input type="text" inputmode="numeric" name="monthly" value="<?php echo (int) $plans['monthly']['price']; ?>"></label>
            </div>
            <label>মাধ্যম — প্রতি লাইনে একটা: <span class="ma-mono">নাম | নম্বর | কীভাবে পাঠাবেন</span>
                <textarea name="methods" rows="6" spellcheck="false"><?php echo esc_textarea($v['methods_raw']); ?></textarea>
            </label>
            <p class="muted ma-tip">ওয়েবসাইটের একটা পাতায় লিখুন <code>[my_assistant_pro]</code> — প্রিমিয়ামের সব সুবিধা, দুই প্ল্যান আর তার নিচে পেমেন্ট ফর্ম একসাথে দেখাবে (শুধু ফর্ম চাইলে <code>[my_assistant_payment]</code>)। Play Store-এর অ্যাপের ভেতরে এই পাতার লিংক বা উল্লেখ দেওয়া যাবে না — এটা Google-এর নিয়ম।</p>
            <div class="ma-dialog-actions"><button type="button" class="ma-btn ghost" data-close>বাতিল</button><button class="ma-btn" type="submit">রাখুন</button></div>
        </form>
    </dialog>
    <?php
}

function ma_acc_render_feedback($v) {
    $post = esc_url(admin_url('admin-post.php'));
    if (!empty($v['inbox_one'])) {
        ma_acc_render_inbox_one($v['inbox_one'], $post);
        return;
    }
    $tabs = ['open' => 'খোলা', 'done' => 'শেষ', 'all' => 'সব'];
    $kinds = ma_fb_kinds();
    ?>
    <section class="ma-card">
        <div class="ma-bar">
            <div class="ma-bar-title"><h2>মতামত ও সমস্যা</h2><span class="ma-count"><?php echo esc_html(ma_acc_bn(count($v['inbox']))); ?> জন সদস্য</span></div>
            <div class="ma-bar-actions">
                <?php foreach ($tabs as $k => $l) : ?>
                    <a class="ma-chip <?php echo $v['fst'] === $k ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'feedback', 'fst' => $k, 'fq' => $v['fq']]); ?>"><?php echo esc_html($l); ?></a>
                <?php endforeach; ?>
            </div>
        </div>
        <form class="ma-tools" method="get" action="<?php echo esc_url(admin_url('admin.php')); ?>">
            <input type="hidden" name="page" value="my-assistant"><input type="hidden" name="tab" value="feedback"><input type="hidden" name="fst" value="<?php echo esc_attr($v['fst']); ?>">
            <label class="ma-search"><svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M10.5 3a7.5 7.5 0 0 1 5.9 12.1l4.3 4.2a1 1 0 0 1-1.4 1.4l-4.2-4.3A7.5 7.5 0 1 1 10.5 3Zm0 2a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11Z"/></svg><input type="search" name="fq" value="<?php echo esc_attr($v['fq']); ?>" placeholder="সদস্যের নাম বা ইমেইল"></label>
        </form>
        <p class="muted ma-pad">প্রতিটি সদস্যের সব মতামত আর উত্তর এক জায়গায়, একটা চ্যাটের মতো। খুলে উত্তর দিন — সদস্যের ফোনে নোটিফিকেশন যাবে।</p>
        <?php if (!$v['inbox']) : ?>
            <div class="ma-empty">
                <div class="ma-empty-art" aria-hidden="true"><svg viewBox="0 0 24 24" width="34" height="34"><path fill="currentColor" d="M4 4h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H8l-4 4V6a2 2 0 0 1 2-2Zm0 2v11.2L7.2 14H20V6H4Z"/></svg></div>
                <h3>এখানে এখনো কিছু নেই</h3>
                <p>সদস্যরা নতুন সুবিধা চাইলে বা সমস্যা জানালে এখানে দেখা যাবে।</p>
            </div>
        <?php else : ?>
            <div class="ma-inbox">
                <?php foreach ($v['inbox'] as $g) : $name = $g['name'] !== '' ? $g['name'] : $g['email']; ?>
                    <a class="ma-inbox-row <?php echo $g['new'] ? 'new' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'feedback', 'who' => $g['key']]); ?>">
                        <?php if ($g['picture'] !== '') : ?><img class="ma-av" src="<?php echo esc_url($g['picture']); ?>" alt="" loading="lazy" referrerpolicy="no-referrer"><?php else : ?><span class="ma-av" style="--h:<?php echo (int) ma_acc_hue($g['email']); ?>"><?php echo esc_html(ma_acc_initials($g['name'], $g['email'])); ?></span><?php endif; ?>
                        <div class="ma-inbox-main">
                            <div class="ma-inbox-top"><strong><?php echo esc_html($name); ?></strong><span class="muted"><?php echo esc_html(ma_acc_ago(gmdate('Y-m-d H:i:s', strtotime($g['updated'])))); ?></span></div>
                            <div class="ma-inbox-text"><?php if ($g['last']) : ?><?php echo $g['last']['from'] === 'admin' ? '<span class="muted">আমরা: </span>' : ''; ?><?php echo esc_html(mb_substr($g['last']['text'], 0, 140)); ?><?php endif; ?></div>
                            <div class="ma-inbox-tags">
                                <?php foreach ($g['kinds'] as $k) : $kk = $kinds[$k] ?? $kinds['other']; ?><span class="ma-pill <?php echo esc_attr($kk[1]); ?>"><?php echo esc_html($kk[0]); ?></span><?php endforeach; ?>
                                <span class="muted"><?php echo esc_html(ma_acc_bn($g['threads'])); ?>টা কথোপকথন<?php echo $g['open'] ? ' · খোলা ' . esc_html(ma_acc_bn($g['open'])) : ''; ?></span>
                            </div>
                        </div>
                        <?php if ($g['new']) : ?><i class="ma-badge"><?php echo esc_html(ma_acc_bn($g['new'])); ?></i><?php endif; ?>
                    </a>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </section>
    <?php
}

/** One member's inbox: every conversation in one chat, the reply box under it. */
function ma_acc_render_inbox_one($one, $post) {
    $name = $one['name'] !== '' ? $one['name'] : $one['email'];
    $kinds = ma_fb_kinds();
    ?>
    <section class="ma-card">
        <div class="ma-bar">
            <div class="ma-bar-title">
                <a class="ma-chip" href="<?php echo ma_acc_url(['tab' => 'feedback']); ?>">← সবার মতামত</a>
                <h2><?php echo esc_html($name); ?></h2>
                <span class="ma-count"><?php echo esc_html(ma_acc_bn(count($one['threads']))); ?>টা কথোপকথন</span>
            </div>
            <div class="ma-bar-actions">
                <a class="ma-btn small ghost" href="mailto:<?php echo esc_attr($one['email']); ?>">ইমেইল</a>
                <form method="post" action="<?php echo $post; ?>"><input type="hidden" name="action" value="ma_fb_inbox_set"><input type="hidden" name="who" value="<?php echo esc_attr($one['key']); ?>"><input type="hidden" name="status" value="<?php echo $one['open'] ? 'done' : 'open'; ?>"><?php wp_nonce_field('ma_fb_inbox_set'); ?><button class="ma-btn small" type="submit"><?php echo $one['open'] ? 'সব শেষ হিসেবে রাখুন' : 'আবার খুলুন'; ?></button></form>
            </div>
        </div>
        <p class="muted ma-pad"><?php echo esc_html($one['email']); ?></p>
        <div class="ma-chat">
            <?php $thread = 0; foreach ($one['messages'] as $m) :
                if ($m['thread'] !== $thread) :
                    $thread = $m['thread'];
                    $t = current(array_filter($one['threads'], fn($x) => $x['id'] === $thread));
                    $k = $kinds[$t['kind']] ?? $kinds['other'];
                    ?>
                    <div class="ma-chat-sep">
                        <span class="ma-pill <?php echo esc_attr($k[1]); ?>"><?php echo esc_html($k[0]); ?></span>
                        <span><?php echo esc_html(ma_acc_date(gmdate('Y-m-d H:i:s', strtotime($t['created'])))); ?><?php echo $t['version'] !== '' ? ' · অ্যাপ v' . esc_html($t['version']) : ''; ?><?php echo $t['status'] === 'done' ? ' · শেষ' : ''; ?></span>
                        <form method="post" action="<?php echo $post; ?>" onsubmit="return confirm('এই কথোপকথন আর তার সংযুক্তি মুছে ফেলবেন?')"><input type="hidden" name="action" value="ma_fb_set"><input type="hidden" name="id" value="<?php echo (int) $thread; ?>"><input type="hidden" name="status" value="delete"><?php wp_nonce_field('ma_fb_set'); ?><button class="ma-icon danger" type="submit" title="এই কথোপকথন মুছুন" aria-label="এই কথোপকথন মুছুন"><svg viewBox="0 0 24 24" width="15" height="15" aria-hidden="true"><path fill="currentColor" d="M9 3h6a1 1 0 0 1 1 1v1h4a1 1 0 1 1 0 2h-1l-.9 12.1A2 2 0 0 1 16.1 21H7.9a2 2 0 0 1-2-1.9L5 7H4a1 1 0 0 1 0-2h4V4a1 1 0 0 1 1-1Zm-2 4 .9 12h8.2L17 7H7Z"/></svg></button></form>
                    </div>
                <?php endif;
                $mine = $m['from'] === 'admin';
                ?>
                <div class="ma-msg <?php echo $mine ? 'us' : 'them'; ?>">
                    <?php if ($m['text'] !== '') : ?><div class="ma-msg-text"><?php echo nl2br(esc_html($m['text'])); ?></div><?php endif; ?>
                    <?php if ($m['file']) :
                        $url = wp_nonce_url(admin_url('admin-post.php?action=ma_fb_file&msg=' . (int) $m['id']), 'ma_fb_file');
                        ?>
                        <?php if (str_starts_with($m['file_mime'], 'image/')) : ?>
                            <a href="<?php echo esc_url($url); ?>" target="_blank" rel="noopener"><img class="ma-msg-img" src="<?php echo esc_url($url); ?>" alt="<?php echo esc_attr($m['file']['name']); ?>"></a>
                        <?php else : ?>
                            <a class="ma-msg-file" href="<?php echo esc_url($url); ?>" target="_blank" rel="noopener">📄 <?php echo esc_html($m['file']['name']); ?> · <?php echo esc_html(size_format((int) $m['file_size'])); ?></a>
                        <?php endif; ?>
                    <?php endif; ?>
                    <div class="ma-msg-meta"><?php echo $mine ? esc_html($m['admin'] !== '' ? $m['admin'] : 'আমরা') : 'সদস্য'; ?> · <?php echo esc_html(ma_acc_date(gmdate('Y-m-d H:i:s', strtotime($m['created'])))); ?></div>
                </div>
            <?php endforeach; ?>
        </div>
        <form class="ma-reply" method="post" action="<?php echo $post; ?>" enctype="multipart/form-data">
            <input type="hidden" name="action" value="ma_fb_reply"><input type="hidden" name="id" value="<?php echo (int) $one['reply_to']; ?>">
            <?php wp_nonce_field('ma_fb_reply'); ?>
            <textarea name="text" rows="3" maxlength="2000" placeholder="<?php echo esc_attr($name); ?>-কে উত্তর লিখুন…"></textarea>
            <div class="ma-reply-row">
                <label class="ma-btn small ghost">📎 ছবি বা PDF<input type="file" name="file" accept="image/jpeg,image/png,image/webp,application/pdf" hidden></label>
                <span class="muted">৫ MB পর্যন্ত</span>
                <button class="ma-btn" type="submit">উত্তর পাঠান</button>
            </div>
        </form>
    </section>
    <?php
}

/** কোম্পানির হিসাব: আয়, ব্যয়, বিনিয়োগকারী (site owner only; the same in the admin app). */
function ma_acc_render_finance($f) {
    if (!$f) {
        return;
    }
    $post = esc_url(admin_url('admin-post.php'));
    $tk = function ($n) {
        return ($n < 0 ? '−' : '') . '৳' . ma_acc_bn(number_format(abs((int) $n)));
    };
    $m = $f['month'];
    $L = $f['lines'];
    $ym = $L['month'];
    $prev = gmdate('Y-m', strtotime($ym . '-01 UTC -1 month'));
    $next = gmdate('Y-m', strtotime($ym . '-01 UTC +1 month'));
    $is_now = $ym === current_time('Y-m');
    $fk = sanitize_key((string) ($_GET['fk'] ?? ''));
    $fc = sanitize_text_field(wp_unslash((string) ($_GET['fc'] ?? '')));
    $mx = 1;
    foreach ($f['months'] as $r) {
        $mx = max($mx, abs($r['net']), $r['income'], $r['expense']);
    }
    ?>
    <section class="ma-card">
        <div class="ma-bar">
            <div class="ma-bar-title"><h2>হিসাব</h2></div>
            <div class="ma-month">
                <a class="ma-icon" href="<?php echo ma_acc_url(['tab' => 'finance', 'month' => $prev]); ?>" aria-label="আগের মাস" title="আগের মাস">‹</a>
                <strong><?php echo esc_html(ma_acc_month_name($ym)); ?></strong>
                <?php if (!$is_now) : ?><a class="ma-icon" href="<?php echo ma_acc_url(['tab' => 'finance', 'month' => $next]); ?>" aria-label="পরের মাস" title="পরের মাস">›</a><?php else : ?><span class="ma-icon" aria-hidden="true"></span><?php endif; ?>
            </div>
            <div class="ma-bar-actions">
                <button class="ma-btn" type="button" data-open="ma-fin-add">+ আয় বা খরচ লিখুন</button>
            </div>
        </div>
        <div class="ma-kpis">
            <div class="in"><span>এ মাসে আয়</span><strong><?php echo esc_html($tk($m['income'])); ?></strong><em>পেমেন্ট <?php echo esc_html($tk($m['payments'])); ?> · অন্য <?php echo esc_html($tk($m['income_other'])); ?></em></div>
            <div class="out"><span>এ মাসে ব্যয়</span><strong><?php echo esc_html($tk($m['expense'])); ?></strong><em>AI <?php echo esc_html($tk($m['ai'])); ?> · অন্য <?php echo esc_html($tk($m['expense_other'])); ?></em></div>
            <div class="<?php echo $m['net'] < 0 ? 'loss' : 'in'; ?>"><span>এ মাসে <?php echo $m['net'] < 0 ? 'লস' : 'লাভ'; ?></span><strong><?php echo esc_html($tk($m['net'])); ?></strong><em>শুরু থেকে <?php echo esc_html($tk($f['all']['net'])); ?></em></div>
            <div class="cash"><span>হাতে থাকার কথা</span><strong><?php echo esc_html($tk($f['cash'])); ?></strong><em>বিনিয়োগ <?php echo esc_html($tk($f['invested'])); ?> + আয় − ব্যয়</em></div>
        </div>
        <p class="muted ma-pad ma-small">আয়: অনুমোদিত পেমেন্ট আর হাতে লেখা আয় (টাকা ছাড়া দেওয়া প্রিমিয়াম আয় নয়)। ব্যয়: AI-এর বিল (ডলার ৳<?php echo esc_html(ma_acc_bn($f['usd_bdt'])); ?> ধরে) আর হাতে লেখা খরচ। বিনিয়োগ আলাদা, আয় নয়।</p>

        <div class="ma-tools ma-fin-filter">
            <div class="ma-chips">
                <?php foreach (['' => 'সব', 'income' => 'আয়', 'expense' => 'খরচ'] as $k => $l) : ?>
                    <a class="ma-chip <?php echo $fk === $k ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'finance', 'month' => $ym, 'fk' => $k, 'fc' => $fc]); ?>"><?php echo esc_html($l); ?></a>
                <?php endforeach; ?>
            </div>
            <form method="get" action="<?php echo esc_url(admin_url('admin.php')); ?>">
                <input type="hidden" name="page" value="my-assistant"><input type="hidden" name="tab" value="finance"><input type="hidden" name="month" value="<?php echo esc_attr($ym); ?>"><input type="hidden" name="fk" value="<?php echo esc_attr($fk); ?>">
                <select name="fc" onchange="this.form.submit()" aria-label="খাত">
                    <option value="">সব খাত</option>
                    <?php foreach ($L['categories'] as $c) : ?><option value="<?php echo esc_attr($c); ?>" <?php selected($fc, $c); ?>><?php echo esc_html($c); ?></option><?php endforeach; ?>
                </select>
            </form>
            <span class="ma-fin-sum">দেখানো: <b class="in">+<?php echo esc_html($tk($L['sum']['income'])); ?></b> <b class="out">−<?php echo esc_html($tk($L['sum']['expense'])); ?></b></span>
        </div>
        <?php if (!$L['lines']) : ?>
            <div class="ma-empty"><h3><?php echo esc_html(ma_acc_month_name($ym)); ?>-এ কিছু নেই</h3><p>“+ আয় বা খরচ লিখুন” চাপলে এখানে আসবে। অনুমোদিত পেমেন্ট আর AI-এর বিল নিজে থেকেই আসে।</p></div>
        <?php else : ?>
            <div class="ma-table-wrap">
                <table class="ma-table">
                    <thead><tr><th>তারিখ</th><th>খাত</th><th class="hide-s">বিবরণ</th><th class="right">টাকা</th><th></th></tr></thead>
                    <tbody>
                    <?php foreach ($L['lines'] as $e) : ?>
                        <tr>
                            <td class="muted"><?php echo esc_html(ma_acc_date($e['date'] . ' 06:00:00')); ?></td>
                            <td><?php echo esc_html($e['category']); ?><?php if ($e['auto']) : ?><span class="ma-ver">নিজে থেকে</span><?php endif; ?></td>
                            <td class="hide-s muted"><?php echo esc_html($e['note']); ?></td>
                            <td class="right"><strong class="<?php echo $e['kind'] === 'income' ? 'ma-in' : 'ma-out'; ?>"><?php echo esc_html(($e['kind'] === 'income' ? '+' : '−') . $tk($e['amount'])); ?></strong></td>
                            <td class="right"><?php if (!$e['auto']) : ?><form method="post" action="<?php echo $post; ?>" onsubmit="return confirm('মুছে ফেলবেন?')"><input type="hidden" name="action" value="ma_fin_delete"><input type="hidden" name="which" value="entry"><input type="hidden" name="id" value="<?php echo (int) $e['id']; ?>"><?php wp_nonce_field('ma_fin_delete'); ?><button class="ma-icon danger" type="submit" title="মুছুন" aria-label="মুছুন"><svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true"><path fill="currentColor" d="M9 3h6a1 1 0 0 1 1 1v1h4a1 1 0 1 1 0 2h-1l-.9 12.1A2 2 0 0 1 16.1 21H7.9a2 2 0 0 1-2-1.9L5 7H4a1 1 0 0 1 0-2h4V4a1 1 0 0 1 1-1Zm-2 4 .9 12h8.2L17 7H7Z"/></svg></button></form><?php endif; ?></td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        <?php endif; ?>
    </section>

    <?php if ($f['months']) : ?>
    <section class="ma-card">
        <div class="ma-bar"><div class="ma-bar-title"><h2>মাস অনুযায়ী</h2><span class="ma-count">শুরু থেকে লাভ/লস <?php echo esc_html($tk($f['all']['net'])); ?></span></div></div>
        <div class="ma-table-wrap">
            <table class="ma-table">
                <thead><tr><th>মাস</th><th>আয় আর ব্যয়</th><th class="right">আয়</th><th class="right">ব্যয়</th><th class="right">লাভ/লস</th></tr></thead>
                <tbody>
                <?php foreach ($f['months'] as $r) : ?>
                    <tr class="<?php echo $r['month'] === $ym ? 'ma-row-on' : ''; ?>">
                        <td><a href="<?php echo ma_acc_url(['tab' => 'finance', 'month' => $r['month']]); ?>"><?php echo esc_html(ma_acc_month_name($r['month'])); ?></a></td>
                        <td class="ma-bars2"><i class="in" style="width:<?php echo (int) round($r['income'] / $mx * 100); ?>%"></i><i class="out" style="width:<?php echo (int) round($r['expense'] / $mx * 100); ?>%"></i></td>
                        <td class="right"><?php echo esc_html($tk($r['income'])); ?></td>
                        <td class="right"><?php echo esc_html($tk($r['expense'])); ?></td>
                        <td class="right"><strong class="<?php echo $r['net'] < 0 ? 'ma-out' : 'ma-in'; ?>"><?php echo esc_html($tk($r['net'])); ?></strong></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </section>
    <?php endif; ?>

    <section class="ma-card">
        <div class="ma-bar">
            <div class="ma-bar-title"><h2>বিনিয়োগকারী</h2><span class="ma-count"><?php echo esc_html(ma_acc_bn(count($f['investors']))); ?> জন · <?php echo esc_html($tk($f['invested'])); ?></span></div>
            <div class="ma-bar-actions"><button class="ma-btn ghost" type="button" data-open="ma-fin-inv">+ বিনিয়োগকারী</button></div>
        </div>
        <?php if ($f['investors']) : ?>
            <div class="ma-table-wrap">
                <table class="ma-table">
                    <thead><tr><th>নাম</th><th class="hide-s">যোগাযোগ</th><th>তারিখ</th><th class="right">শেয়ার</th><th class="right">টাকা</th><th></th></tr></thead>
                    <tbody>
                    <?php foreach ($f['investors'] as $i) : ?>
                        <tr><td><strong><?php echo esc_html($i['name']); ?></strong><?php if ($i['note'] !== '') : ?><span class="ma-ver"><?php echo esc_html($i['note']); ?></span><?php endif; ?></td><td class="hide-s muted"><?php echo esc_html($i['contact']); ?></td><td class="muted"><?php echo esc_html(ma_acc_date($i['on_date'] . ' 06:00:00')); ?></td>
                            <td class="right"><?php echo $i['share'] !== '' ? esc_html(ma_acc_bn($i['share']) . '%') : '—'; ?></td><td class="right"><strong><?php echo esc_html($tk($i['amount'])); ?></strong></td>
                            <td class="right"><form method="post" action="<?php echo $post; ?>" onsubmit="return confirm('মুছে ফেলবেন?')"><input type="hidden" name="action" value="ma_fin_delete"><input type="hidden" name="which" value="investor"><input type="hidden" name="id" value="<?php echo (int) $i['id']; ?>"><?php wp_nonce_field('ma_fin_delete'); ?><button class="ma-icon danger" type="submit" title="মুছুন" aria-label="মুছুন"><svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true"><path fill="currentColor" d="M9 3h6a1 1 0 0 1 1 1v1h4a1 1 0 1 1 0 2h-1l-.9 12.1A2 2 0 0 1 16.1 21H7.9a2 2 0 0 1-2-1.9L5 7H4a1 1 0 0 1 0-2h4V4a1 1 0 0 1 1-1Zm-2 4 .9 12h8.2L17 7H7Z"/></svg></button></form></td></tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        <?php else : ?>
            <p class="muted ma-pad">এখনো কেউ নেই।</p>
        <?php endif; ?>
    </section>

    <dialog class="ma-dialog" id="ma-fin-add">
        <form method="post" action="<?php echo $post; ?>">
            <input type="hidden" name="action" value="ma_fin_entry"><?php wp_nonce_field('ma_fin_entry'); ?>
            <h3>আয় বা খরচ লিখুন</h3>
            <fieldset class="ma-days"><legend>ধরন</legend>
                <label><input type="radio" name="kind" value="expense" checked><span>খরচ</span></label>
                <label><input type="radio" name="kind" value="income"><span>আয়</span></label>
            </fieldset>
            <label>টাকা<input type="number" name="amount" min="1" required inputmode="numeric" placeholder="যেমন ১৫০০"></label>
            <label>খাত<input type="text" name="category" maxlength="80" list="ma-fin-cats" placeholder="সার্ভার ও হোস্টিং"></label>
            <datalist id="ma-fin-cats"><?php foreach (array_merge($f['categories']['expense'], $f['categories']['income']) as $c) : ?><option value="<?php echo esc_attr($c); ?>"><?php endforeach; ?></datalist>
            <label>তারিখ<input type="date" name="on_date" value="<?php echo esc_attr($is_now ? current_time('Y-m-d') : $ym . '-01'); ?>"></label>
            <label>বিবরণ (ঐচ্ছিক)<input type="text" name="note" maxlength="400"></label>
            <div class="ma-dialog-actions"><button type="button" class="ma-btn ghost" data-close>বাতিল</button><button class="ma-btn" type="submit">রাখুন</button></div>
        </form>
    </dialog>

    <dialog class="ma-dialog" id="ma-fin-inv">
        <form method="post" action="<?php echo $post; ?>">
            <input type="hidden" name="action" value="ma_fin_investor"><?php wp_nonce_field('ma_fin_investor'); ?>
            <h3>বিনিয়োগকারী যোগ করুন</h3>
            <label>নাম<input type="text" name="name" maxlength="190" required></label>
            <label>মোবাইল/ইমেইল<input type="text" name="contact" maxlength="190"></label>
            <div class="ma-ai-row two">
                <label>টাকা<input type="number" name="amount" min="0" inputmode="numeric"></label>
                <label>শেয়ার (%)<input type="text" name="share" maxlength="16" placeholder="১০"></label>
            </div>
            <label>তারিখ<input type="date" name="on_date" value="<?php echo esc_attr(current_time('Y-m-d')); ?>"></label>
            <label>নোট<input type="text" name="note" maxlength="400"></label>
            <div class="ma-dialog-actions"><button type="button" class="ma-btn ghost" data-close>বাতিল</button><button class="ma-btn" type="submit">যোগ করুন</button></div>
        </form>
    </dialog>
    <?php
}

function ma_acc_render_notices($v) {
    $o = ma_note_options();
    $post = esc_url(admin_url('admin-post.php'));
    ?>
    <section class="ma-card">
        <div class="ma-bar">
            <div class="ma-bar-title"><h2>নোটিফিকেশন</h2><span class="ma-count">সদস্যদের ফোনে</span></div>
            <div class="ma-bar-actions"><button class="ma-btn" type="button" data-open="ma-note" data-m="<?php echo esc_attr(wp_json_encode(['id' => '', 'title' => '', 'body' => '', 'kind' => 'daily', 'at_time' => '21:00', 'weekday' => 5, 'audience' => 'all', 'cond' => '', 'mic' => true, 'on_date' => '', 'start_date' => '', 'end_date' => ''])); ?>">
                <svg viewBox="0 0 24 24" width="17" height="17" aria-hidden="true"><path fill="currentColor" d="M12 5a1 1 0 0 1 1 1v5h5a1 1 0 1 1 0 2h-5v5a1 1 0 1 1-2 0v-5H6a1 1 0 1 1 0-2h5V6a1 1 0 0 1 1-1Z"/></svg> নতুন নোটিফিকেশন</button></div>
        </div>
        <p class="muted ma-pad">শর্ত ছাড়া নোটিফিকেশন সার্ভার নিজে ঠিক সময়ে পুশ করে (অ্যাপ বন্ধ থাকলেও যায়)। শর্ত দিলে ফোন নিজে দেখে দেখায় — সদস্যের “চুপ থাকার সময়” আর দিনের সীমা মেনে।</p>
        <?php if (!$v['notices']) : ?>
            <div class="ma-empty">
                <div class="ma-empty-art" aria-hidden="true"><svg viewBox="0 0 24 24" width="34" height="34"><path fill="currentColor" d="M12 2a6 6 0 0 1 6 6v3.6l1.7 3.4A1 1 0 0 1 18.8 16H5.2a1 1 0 0 1-.9-1.4L6 11.6V8a6 6 0 0 1 6-6Zm0 2a4 4 0 0 0-4 4v3.8c0 .2 0 .3-.1.5L6.8 14h10.4l-1.1-1.7a1 1 0 0 1-.1-.5V8a4 4 0 0 0-4-4Zm-2 14h4a2 2 0 1 1-4 0Z"/></svg></div>
                <h3>এখনো কোনো নোটিফিকেশন নেই</h3>
                <p>যেমন: প্রতিদিন রাত ৯টায় “আজকের কাজের লিস্ট করেছেন?” — শুধু যাঁরা সেদিন তালিকা করেননি, তাঁদের।</p>
            </div>
        <?php else : ?>
            <div class="ma-notes">
                <?php foreach ($v['notices'] as $n) :
                    $when = $n['kind'] === 'once' ? ma_acc_date($n['on_date'] . ' 00:00:00') : ($n['kind'] === 'weekly' ? 'প্রতি ' . $o['weekday'][(int) $n['weekday']] : 'প্রতিদিন');
                    ?>
                    <article class="ma-note <?php echo $n['active'] ? '' : 'off'; ?>">
                        <div class="ma-note-phone" aria-hidden="true">
                            <span class="ma-note-app"><i></i>My Assistant · <?php echo esc_html(ma_acc_bn($n['at_time'])); ?></span>
                            <strong><?php echo esc_html($n['title']); ?></strong>
                            <span><?php echo esc_html($n['body']); ?></span>
                        </div>
                        <div class="ma-note-meta">
                            <span class="ma-pill <?php echo $n['active'] ? 'pro' : 'free'; ?>"><?php echo $n['active'] ? 'চালু' : 'বন্ধ'; ?></span>
                            <span><?php echo esc_html($when . ' · ' . ma_acc_bn($n['at_time'])); ?></span>
                            <span><?php echo esc_html($o['audience'][$n['audience']] ?? 'সবাই'); ?></span>
                            <?php if ($n['cond'] !== '') : ?><span><?php echo esc_html($o['cond'][$n['cond']] ?? ''); ?></span><?php endif; ?>
                            <?php if ($n['end_date']) : ?><span>শেষ <?php echo esc_html(ma_acc_date($n['end_date'] . ' 00:00:00')); ?></span><?php endif; ?>
                            <?php $run = $v['note_overview']['runs'][(int) $n['id']] ?? null; if ($run) : ?><span>পাঠানো হয়েছে <?php echo esc_html(ma_acc_bn($run['times'])); ?> বার · <?php echo esc_html(ma_acc_bn($run['sent'])); ?> জনের ফোনে<?php echo $run['failed'] ? ' · পৌঁছায়নি ' . esc_html(ma_acc_bn($run['failed'])) : ''; ?></span><?php endif; ?>
                        </div>
                        <div class="ma-note-ops">
                            <button type="button" class="ma-icon" title="বদলান" aria-label="বদলান" data-open="ma-note" data-m="<?php echo esc_attr(wp_json_encode($n + ['mic' => (bool) $n['mic']])); ?>"><svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M15.6 3.6a2 2 0 0 1 2.8 0l2 2a2 2 0 0 1 0 2.8L9.2 19.6a2 2 0 0 1-1 .5l-3.9.9a1 1 0 0 1-1.2-1.2l.9-3.9c.1-.4.3-.7.5-1L15.6 3.6ZM17 5l-11 11-.5 2.5L8 18 19 7l-2-2Z"/></svg></button>
                            <form method="post" action="<?php echo $post; ?>"><input type="hidden" name="action" value="ma_note_toggle"><input type="hidden" name="id" value="<?php echo (int) $n['id']; ?>"><?php wp_nonce_field('ma_note_toggle'); ?><button class="ma-btn small ghost" type="submit"><?php echo $n['active'] ? 'বন্ধ করুন' : 'চালু করুন'; ?></button></form>
                            <form method="post" action="<?php echo $post; ?>" onsubmit="return confirm('মুছে ফেলবেন?')"><input type="hidden" name="action" value="ma_note_toggle"><input type="hidden" name="delete" value="1"><input type="hidden" name="id" value="<?php echo (int) $n['id']; ?>"><?php wp_nonce_field('ma_note_toggle'); ?><button class="ma-icon danger" type="submit" title="মুছুন" aria-label="মুছুন"><svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M9 3h6a1 1 0 0 1 1 1v1h4a1 1 0 1 1 0 2h-1l-.9 12.1A2 2 0 0 1 16.1 21H7.9a2 2 0 0 1-2-1.9L5 7H4a1 1 0 0 1 0-2h4V4a1 1 0 0 1 1-1Zm-2 4 .9 12h8.2L17 7H7Z"/></svg></button></form>
                        </div>
                    </article>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </section>

    <?php $ov = $v['note_overview'] ?? null; if ($ov) : $gl = $ov['groups'];
        // Today and tomorrow here (the cards above say each one's schedule; the admin app shows 7 days).
        $two = gmdate('Y-m-d', time() + ma_acc_tz_off() + DAY_IN_SECONDS);
        $ov['upcoming'] = array_values(array_filter($ov['upcoming'], fn($u) => $u['day'] <= $two)); ?>
    <section class="ma-card" id="ma-next">
        <div class="ma-bar">
            <div class="ma-bar-title"><h2>আজ আর কাল কী যাবে</h2><span class="ma-count"><?php echo esc_html(ma_acc_bn(count($ov['upcoming']))); ?>টি</span></div>
        </div>
        <p class="muted ma-pad">
            <?php if ($ov['push_on']) : ?>
                শর্ত ছাড়া নোটিফিকেশন সার্ভার নিজেই ঠিক সময়ে পুশ করে — অ্যাপ বন্ধ থাকলেও আসে। পুশ পাচ্ছে <?php echo esc_html(ma_acc_bn($ov['phones'])); ?>টি ফোন, তার মধ্যে নতুন অ্যাপে (২.৫৫.১১ বা পরে) <?php echo esc_html(ma_acc_bn($ov['phones_new_app'])); ?>টি; পুরোনো অ্যাপ নিজে খোলার পর তালিকা নিয়ে দেখায়। শর্ত দেওয়া থাকলে ফোন নিজে দেখে দেখায়।
            <?php else : ?>
                <strong>Firebase বসানো নেই</strong> — তাই সার্ভার পুশ করতে পারছে না; ফোন নিজে অ্যাপ খোলার পর তালিকা নিয়ে দেখায়। সেটিংস › পুশ নোটিফিকেশনে Firebase বসান।
            <?php endif; ?>
        </p>
        <?php if (!$ov['upcoming']) : ?>
            <div class="ma-empty"><h3>আজ-কাল কিছু নেই</h3><p>চালু থাকা কোনো নোটিফিকেশন আজ বা কাল পড়েনি।</p></div>
        <?php else : ?>
            <div class="ma-table-wrap">
                <table class="ma-table">
                    <thead><tr><th>কবে</th><th>সময়</th><th>কী</th><th>কাদের</th><th>কীভাবে যাবে</th></tr></thead>
                    <tbody>
                    <?php $prev = ''; foreach ($ov['upcoming'] as $u) : ?>
                        <tr>
                            <td><?php echo $u['day'] !== $prev ? '<strong>' . esc_html(ma_acc_date($u['day'] . ' 06:00:00')) . '</strong>' : ''; $prev = $u['day']; ?></td>
                            <td><?php echo esc_html(ma_acc_bn($u['time'])); ?></td>
                            <td><strong><?php echo esc_html($u['title']); ?></strong><?php if ($u['body'] !== '') : ?><span class="ma-ver"><?php echo esc_html(mb_substr($u['body'], 0, 90)); ?></span><?php endif; ?></td>
                            <td><?php echo esc_html($u['audience']); ?><span class="ma-ver"><?php echo esc_html(ma_acc_bn($u['members'])); ?> জন সদস্য</span></td>
                            <td><span class="ma-pill <?php echo $u['how'] === 'push' ? 'pro' : 'free'; ?>"><?php echo esc_html($u['how'] === 'push' ? 'সার্ভার থেকে পুশ' : 'ফোন নিজে দেখাবে'); ?></span><span class="ma-ver"><?php echo esc_html($u['how'] === 'push' ? ma_acc_bn((int) $u['phones']) . 'টি ফোনে' : $u['how_label']); ?></span></td>
                        </tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        <?php endif; ?>
    </section>

    <?php $nd = $v['note_day'] ?? null; if ($nd) : $today = gmdate('Y-m-d', time() + ma_acc_tz_off()); ?>
    <section class="ma-card" id="ma-day">
        <div class="ma-bar">
            <div class="ma-bar-title"><h2>অ্যাপ থেকে কোন কোন নোটিফিকেশন যায়</h2><span class="ma-count"><?php echo $nd['day'] === $today ? 'আজ' : esc_html(ma_acc_date($nd['day'] . ' 06:00:00')); ?> · মোট <?php echo esc_html(ma_acc_bn($nd['total'])); ?>টি · <?php echo esc_html(ma_acc_bn($nd['people'])); ?> জন সদস্য</span></div>
            <div class="ma-chips">
                <?php for ($i = 0; $i < 7; $i++) : $d = gmdate('Y-m-d', strtotime($today . ' UTC') - $i * DAY_IN_SECONDS); ?>
                    <a class="ma-chip <?php echo $nd['day'] === $d ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'notices', 'nday' => $d]); ?>#ma-day"><?php echo $i === 0 ? 'আজ' : ($i === 1 ? 'গতকাল' : esc_html(ma_acc_bn((int) substr($d, 8)) . ' ' . ma_acc_month_name(substr($d, 0, 7)))); ?></a>
                <?php endfor; ?>
            </div>
        </div>
        <div class="ma-rules">
            <div><strong>দিনে কয়টা:</strong> <?php echo esc_html($nd['rules']['daily']); ?></div>
            <div><strong>চুপ থাকার সময়:</strong> <?php echo esc_html($nd['rules']['quiet']); ?> — এ সময়ের মনে করানো সকাল ৭টায় যায়। সদস্য সেটিংসে যেকোনোটা বন্ধ করতে পারেন।</div>
        </div>
        <div class="ma-day-grid">
            <div class="ma-table-wrap">
                <table class="ma-table ma-cat">
                    <thead><tr><th>কখন</th><th>কোন নোটিফিকেশন</th><th class="right">এদিন কতজন</th><th class="right">কয়টি</th></tr></thead>
                    <tbody>
                    <?php foreach ($nd['app'] as $it) : $none = $it['count'] === 0 && $it['failed'] === 0; ?>
                        <tr class="<?php echo $none ? 'ma-dim' : ''; ?>">
                            <td><strong><?php echo esc_html($it['times'] ? ma_acc_bn(implode(', ', $it['times'])) : ($it['at'] !== '' ? ma_acc_bn($it['at']) : '—')); ?></strong><?php if ($it['ahead']) : ?><span class="ma-ver"><?php echo esc_html(ma_acc_bn($it['ahead'])); ?>টি আসবে</span><?php endif; ?></td>
                            <td>
                                <strong><?php echo esc_html($it['label']); ?></strong>
                                <?php if (!$it['cap']) : ?><span class="ma-tag">সীমার বাইরে</span><?php endif; ?>
                                <?php if ($it['by'] === 'server') : ?><span class="ma-tag srv">সার্ভার থেকে পুশ</span><?php endif; ?>
                                <?php if ($it['off']) : ?><span class="ma-tag">চালু করলে</span><?php endif; ?>
                                <span class="ma-ver">“<?php echo esc_html($it['sample']); ?>” · <?php echo esc_html($it['when']); ?></span>
                            </td>
                            <td class="right"><?php echo $none ? '—' : esc_html(ma_acc_bn($it['people'])); ?></td>
                            <td class="right"><strong><?php echo $none ? '—' : esc_html(ma_acc_bn($it['count'])); ?></strong><?php if ($it['failed']) : ?> <span class="ma-pill expired"><?php echo esc_html(ma_acc_bn($it['failed'])); ?> পৌঁছায়নি</span><?php endif; ?></td>
                        </tr>
                    <?php endforeach; ?>
                    <tr class="ma-dim"><td>—</td><td><strong>সদস্যের নিজের রিমাইন্ডার</strong><span class="ma-ver">অ্যাপ নিজে পাঠায় না — সদস্য যা রাখেন। লেখা ফোনেই থাকে, এখানে শুধু সংখ্যা।</span></td><td class="right"><?php echo esc_html(ma_acc_bn($nd['reminders']['people'])); ?></td><td class="right"><?php echo esc_html(ma_acc_bn($nd['reminders']['count'])); ?></td></tr>
                    </tbody>
                </table>
            </div>
            <div class="ma-table-wrap">
                <table class="ma-table">
                    <thead><tr><th>কে দিনে কতগুলো পাচ্ছে</th><th class="right">গড় <?php echo esc_html(ma_acc_bn($nd['avg'])); ?> · সর্বোচ্চ <?php echo esc_html(ma_acc_bn($nd['max'])); ?></th></tr></thead>
                    <tbody>
                    <?php if (!$nd['members']) : ?><tr><td colspan="2" class="muted">এই দিনে কিছু নেই। সদস্যরা নতুন অ্যাপ খুললে তাঁদের ফোনের তালিকা এখানে আসে।</td></tr><?php endif; ?>
                    <?php foreach (array_slice($nd['members'], 0, 100) as $m) : ?>
                        <tr><td><?php echo esc_html($m['name'] !== '' ? $m['name'] : $m['email']); ?><span class="ma-ver"><?php echo esc_html($m['email']); ?></span></td><td class="right"><strong><?php echo esc_html(ma_acc_bn($m['count'])); ?></strong><?php if ($m['reminders']) : ?><span class="ma-ver">+ নিজের রিমাইন্ডার <?php echo esc_html(ma_acc_bn($m['reminders'])); ?></span><?php endif; ?><?php if ($m['failed']) : ?><span class="ma-ver" style="color:var(--rose)"><?php echo esc_html(ma_acc_bn($m['failed'])); ?> পৌঁছায়নি</span><?php endif; ?></td></tr>
                    <?php endforeach; ?>
                    </tbody>
                </table>
            </div>
        </div>
    </section>
    <?php endif; ?>

    <?php ma_note_render_rules(); ?>

    <section class="ma-card" id="ma-daily">
        <div class="ma-bar"><div class="ma-bar-title"><h2>গত ১৪ দিনে দিনে কতটি</h2><span class="ma-count">সব সদস্য মিলে · দিনে চাপলে সেদিনের তালিকা</span></div></div>
        <p class="muted ma-pad">সদস্যদের ফোনে যা দেখানো হয়েছে আর আমরা যা পুশ করেছি, ধরন অনুযায়ী গোনা।</p>
        <?php $mx = max(1, max(array_column($ov['days'], 'total'))); ?>
        <div class="ma-table-wrap">
            <table class="ma-table ma-daily">
                <thead><tr><th>দিন</th><th>মোট</th><?php foreach ($gl as $k => $l) : ?><th class="right hide-s"><?php echo esc_html($l); ?></th><?php endforeach; ?><th class="right">পৌঁছায়নি</th></tr></thead>
                <tbody>
                <?php foreach ($ov['days'] as $d) : ?>
                    <tr>
                        <td><a href="<?php echo ma_acc_url(['tab' => 'notices', 'nday' => $d['day']]); ?>#ma-day"><?php echo esc_html(ma_acc_date($d['day'] . ' 06:00:00')); ?></a></td>
                        <td><div class="ma-meter"><i style="width:<?php echo (int) round($d['total'] / $mx * 100); ?>%"></i><b><?php echo esc_html(ma_acc_bn($d['total'])); ?></b></div></td>
                        <?php foreach ($gl as $k => $l) : ?><td class="right hide-s <?php echo $d[$k] ? '' : 'muted'; ?>"><?php echo esc_html(ma_acc_bn($d[$k])); ?></td><?php endforeach; ?>
                        <td class="right"><?php echo $d['failed'] ? '<span class="ma-pill expired">' . esc_html(ma_acc_bn($d['failed'])) . '</span>' : '<span class="muted">০</span>'; ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </section>
    <?php endif; ?>

    <section class="ma-card">
        <div class="ma-bar"><div class="ma-bar-title"><h2>এখনই পাঠান</h2><span class="ma-count">পুশ</span></div></div>
        <form class="ma-pad" method="post" action="<?php echo $post; ?>">
            <input type="hidden" name="action" value="ma_push_now"><?php wp_nonce_field('ma_push_now'); ?>
            <div class="ma-ai-row three">
                <label>শিরোনাম<input type="text" name="title" maxlength="120" required></label>
                <label>লেখা<input type="text" name="body" maxlength="400"></label>
                <label>কাকে<select name="audience"><?php foreach (ma_note_options()['audience'] as $k => $l) : ?><option value="<?php echo esc_attr($k); ?>"><?php echo esc_html($l); ?></option><?php endforeach; ?></select></label>
            </div>
            <button class="ma-btn" type="submit" onclick="return confirm('এখনই পাঠাবেন?')">পাঠান</button>
        </form>
    </section>

    <dialog class="ma-dialog wide" id="ma-note">
        <form method="post" action="<?php echo $post; ?>">
            <input type="hidden" name="action" value="ma_note_save"><input type="hidden" name="id" data-f="id">
            <?php wp_nonce_field('ma_note_save'); ?>
            <h3>নোটিফিকেশন</h3>
            <label>শিরোনাম<input type="text" name="title" data-f="title" maxlength="120" required placeholder="আজকের কাজের লিস্ট করেছেন?"></label>
            <label>লেখা<input type="text" name="body" data-f="body" maxlength="400" placeholder="চাপুন আর বলুন — কাল কী কী করবেন, লিখে রাখবো।"></label>
            <div class="ma-ai-row three">
                <label>কখন<select name="kind" data-f="kind"><?php foreach ($o['kind'] as $k => $l) : ?><option value="<?php echo esc_attr($k); ?>"><?php echo esc_html($l); ?></option><?php endforeach; ?></select></label>
                <label>সময়<input type="time" name="at_time" data-f="at_time" required></label>
                <label>কোন দিন (সাপ্তাহিক)<select name="weekday" data-f="weekday"><?php foreach ($o['weekday'] as $k => $l) : ?><option value="<?php echo (int) $k; ?>"><?php echo esc_html($l); ?></option><?php endforeach; ?></select></label>
            </div>
            <div class="ma-ai-row three">
                <label>তারিখ (একবারের)<input type="date" name="on_date" data-f="on_date"></label>
                <label>শুরু (ঐচ্ছিক)<input type="date" name="start_date" data-f="start_date"></label>
                <label>শেষ (ঐচ্ছিক)<input type="date" name="end_date" data-f="end_date"></label>
            </div>
            <div class="ma-ai-row two">
                <label>কাদের<select name="audience" data-f="audience"><?php foreach ($o['audience'] as $k => $l) : ?><option value="<?php echo esc_attr($k); ?>"><?php echo esc_html($l); ?></option><?php endforeach; ?></select></label>
                <label>শর্ত (ফোন নিজে দেখে নেয়)<select name="cond" data-f="cond"><?php foreach ($o['cond'] as $k => $l) : ?><option value="<?php echo esc_attr($k); ?>"><?php echo esc_html($l); ?></option><?php endforeach; ?></select></label>
            </div>
            <label class="ma-check"><input type="checkbox" name="mic" value="1" data-f="mic"> চাপলে মাইক খুলবে (সদস্য সাথে সাথে বলতে পারবেন)</label>
            <div class="ma-dialog-actions"><button type="button" class="ma-btn ghost" data-close>বাতিল</button><button class="ma-btn" type="submit">রাখুন</button></div>
        </form>
    </dialog>
    <?php
}

function ma_acc_render_settings($v) {
    $set = trim($v['clients']) !== '';
    $ai = $v['ai'];
    $ready = $ai['on'] && $ai['source'] !== '';
    ?>
    <section class="ma-card pad ma-ai">
        <div class="ma-ai-head">
            <div>
                <h2>AI সহকারী</h2>
                <p class="muted">প্রিমিয়াম ও ট্রায়ালের সদস্যদের AI এই সার্ভার দিয়ে চলে। API key এখানেই থাকে — অ্যাপে কখনো যায় না। সদস্য কী বললেন তা এখানে রাখা হয় না, শুধু গোনা হয়।</p>
            </div>
            <span class="ma-pill <?php echo $ready ? 'pro' : 'expired'; ?>"><?php echo $ready ? 'চালু' : ($ai['source'] === '' ? 'key নেই' : 'বন্ধ'); ?></span>
        </div>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" class="ma-ai-form">
            <input type="hidden" name="action" value="ma_ai_settings">
            <?php wp_nonce_field('ma_ai_settings'); ?>
            <label class="ma-check ma-switch"><input type="checkbox" name="ai_on" value="1" <?php checked($ai['on'], true); ?>><span class="ma-switch-ui" aria-hidden="true"></span> প্রিমিয়াম সদস্যদের জন্য AI চালু</label>
            <div class="ma-ai-row">
                <label>Anthropic API key
                    <?php if ($ai['source'] === 'config') : ?>
                        <input type="text" value="wp-config.php থেকে নেওয়া · ••••<?php echo esc_attr($ai['tail']); ?>" disabled>
                    <?php else : ?>
                        <input type="password" name="ai_key" autocomplete="off" spellcheck="false" placeholder="<?php echo $ai['source'] === 'saved' ? esc_attr('রাখা আছে · ••••' . $ai['tail'] . ' — বদলাতে নতুনটা দিন') : 'sk-ant-…'; ?>">
                    <?php endif; ?>
                </label>
                <label>Gemini API key (ফ্রি সদস্যদের বোঝার জন্য)
                    <?php if (($ai['gemini_source'] ?? '') === 'config') : ?>
                        <input type="text" value="wp-config.php থেকে নেওয়া · ••••<?php echo esc_attr($ai['gemini_tail']); ?>" disabled>
                    <?php else : ?>
                        <input type="password" name="gemini_key" autocomplete="off" spellcheck="false" placeholder="<?php echo ($ai['gemini_source'] ?? '') === 'saved' ? esc_attr('রাখা আছে · ••••' . $ai['gemini_tail'] . ' — বদলাতে নতুনটা দিন') : 'AQ.… বা AIza…'; ?>">
                    <?php endif; ?>
                </label>
                <label>সদস্যপ্রতি দিনে প্রশ্ন<input type="text" inputmode="numeric" name="per_user" value="<?php echo (int) $ai['per_user']; ?>"></label>
                <label>সার্ভারে দিনে মোট প্রশ্ন<input type="text" inputmode="numeric" name="per_day" value="<?php echo (int) $ai['per_day']; ?>"></label>
            </div>
            <?php if ($ai['source'] === 'saved') : ?>
                <label class="ma-check"><input type="checkbox" name="ai_key_remove" value="1"> রাখা key মুছে দিন</label>
            <?php endif; ?>
            <?php if (($ai['gemini_source'] ?? '') === 'saved') : ?>
                <label class="ma-check"><input type="checkbox" name="gemini_key_remove" value="1"> রাখা Gemini key মুছে দিন</label>
            <?php endif; ?>
            <p class="muted ma-tip">সবচেয়ে নিরাপদ: key ডাটাবেসে না রেখে <code>wp-config.php</code>-এ লিখুন — <code>define('MA_ANTHROPIC_API_KEY', 'sk-ant-…');</code>। Anthropic Console-এ মাসিক খরচের সীমাও বেঁধে দিন।</p>
            <button class="ma-btn" type="submit">রাখুন</button>
        </form>
    </section>
    <section class="ma-card pad">
        <h2>Gemini আর Claude পরীক্ষা</h2>
        <p class="muted ma-tip">একটা বানানো বাক্য ("কাল সকালে ব্যাংকে যেতে হবে") দুটো সেবায় একবার করে পাঠিয়ে দেখায় key আর অনুরোধের গড়ন ঠিক আছে কিনা। খরচ এক পয়সারও কম।</p>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <input type="hidden" name="action" value="ma_nlu_selftest">
            <?php wp_nonce_field('ma_nlu_selftest'); ?>
            <button class="ma-btn" type="submit">এখন পরীক্ষা করুন</button>
        </form>
        <h3>নতুন করে শেখানোর key</h3>
        <p class="muted ma-tip">GitHub-এ মডেল নতুন করে শেখানোর কাজ এটা দিয়ে শুধু শেখার নমুনা পড়ে আর নতুন মডেল <em>draft</em> হিসেবে রাখে — চালু করা, সেটিংস বা সদস্য দেখা পারে না। GitHub › Settings › Secrets-এ <code>MA_NLU_CI_KEY</code> নামে বসান।</p>
        <?php $ci = ma_nlu_ci_key(); if ($ci !== '' && !(defined('MA_NLU_CI_KEY') && MA_NLU_CI_KEY)) : ?>
            <input type="text" readonly value="<?php echo esc_attr($ci); ?>" onclick="this.select()" style="width:100%;font-family:monospace">
        <?php elseif ($ci !== '') : ?>
            <p class="muted">wp-config.php থেকে নেওয়া।</p>
        <?php endif; ?>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <input type="hidden" name="action" value="ma_nlu_ci_key">
            <?php wp_nonce_field('ma_nlu_ci_key'); ?>
            <button class="ma-btn" type="submit"><?php echo $ci === '' ? 'key বানান' : 'নতুন key বানান (আগেরটা বাতিল)'; ?></button>
        </form>
    </section>
    <?php ma_acc_render_ai_costs($v['ai_costs'] ?? null); ?>
    <?php $push = $v['push'] ?? ['source' => '']; $post = esc_url(admin_url('admin-post.php')); ?>
    <section class="ma-card pad">
        <h2>অ্যাডমিন</h2>
        <p class="muted ma-tip">এঁরা ইমেইল আর পাসওয়ার্ড দিয়ে অ্যাডমিন অ্যাপে (আর এই পাতায়) ঢুকতে পারবেন — পেমেন্ট অনুমোদন, সদস্য আর নোটিফিকেশন। সেটিংস বদলাতে পারবেন শুধু সাইটের মূল অ্যাডমিন। নতুন পেমেন্ট এলে সবার অ্যাডমিন অ্যাপে পুশ যাবে।</p>
        <div class="ma-admins">
            <?php foreach ($v['admins'] ?? [] as $a) : $site = user_can((int) $a->ID, 'manage_options'); ?>
                <div class="ma-admin">
                    <span class="ma-av" style="--h:<?php echo (int) ma_acc_hue($a->user_email); ?>"><?php echo esc_html(ma_acc_initials($a->display_name, $a->user_email)); ?></span>
                    <div class="ma-who-text"><strong><?php echo esc_html($a->display_name); ?></strong><span><?php echo esc_html($a->user_email); ?></span></div>
                    <?php if ($site) : ?>
                        <span class="ma-pill pro">সাইটের মূল অ্যাডমিন</span>
                    <?php else : ?>
                        <form method="post" action="<?php echo $post; ?>" onsubmit="return confirm('এই অ্যাডমিনের অনুমতি তুলে নেবেন?')"><input type="hidden" name="action" value="ma_admin_remove"><input type="hidden" name="id" value="<?php echo (int) $a->ID; ?>"><?php wp_nonce_field('ma_admin_remove'); ?><button class="ma-btn small ghost" type="submit">সরান</button></form>
                    <?php endif; ?>
                </div>
            <?php endforeach; ?>
        </div>
        <form method="post" action="<?php echo $post; ?>" class="ma-ai-row three" autocomplete="off">
            <input type="hidden" name="action" value="ma_admin_add"><?php wp_nonce_field('ma_admin_add'); ?>
            <label>নাম<input type="text" name="name" required></label>
            <label>ইমেইল<input type="email" name="email" required autocomplete="off"></label>
            <label>পাসওয়ার্ড (অন্তত ১০ অক্ষর)<input type="password" name="password" minlength="10" required autocomplete="new-password"></label>
            <div><button class="ma-btn" type="submit">অ্যাডমিন যোগ করুন</button></div>
        </form>
    </section>
    <section class="ma-card pad">
        <div class="ma-ai-head">
            <div>
                <h2>পুশ নোটিফিকেশন (Firebase)</h2>
                <p class="muted">নতুন পেমেন্ট এলে অ্যাডমিনদের ফোনে, আর প্রিমিয়াম চালু হলে সদস্যের ফোনে সাথে সাথে পুশ যায়। এর জন্য Firebase-এর service account লাগে (ফ্রি)।</p>
            </div>
            <span class="ma-pill <?php echo $push['source'] !== '' ? 'pro' : 'expired'; ?>"><?php echo $push['source'] !== '' ? 'পুশ চালু' : 'Firebase নেই'; ?></span>
        </div>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
            <input type="hidden" name="action" value="ma_push_settings">
            <?php wp_nonce_field('ma_push_settings'); ?>
            <?php if ($push['source'] === 'config') : ?>
                <p class="muted ma-tip">Firebase service account <code>wp-config.php</code> থেকে নেওয়া হচ্ছে।</p>
            <?php else : ?>
                <label>Firebase service account JSON <?php echo $push['source'] === 'saved' ? '(রাখা আছে — বদলাতে নতুনটা পেস্ট করুন)' : ''; ?>
                    <textarea name="fcm_account" rows="3" spellcheck="false" placeholder='{"type": "service_account", "project_id": "…", …}'></textarea>
                </label>
                <?php if ($push['source'] === 'saved') : ?><label class="ma-check"><input type="checkbox" name="fcm_remove" value="1"> রাখা service account মুছে দিন</label><?php endif; ?>
            <?php endif; ?>
            <p class="muted ma-tip">Firebase Console › Project settings › Service accounts › “Generate new private key” — ফাইলটা খুলে পুরো লেখা এখানে পেস্ট করুন। আরও নিরাপদ: <code>define('MA_FCM_SERVICE_ACCOUNT', '/home/…/firebase.json');</code> wp-config.php-তে।</p>
            <button class="ma-btn" type="submit">রাখুন</button>
        </form>
        <?php if ($push['source'] !== '') : ?>
            <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" style="margin-top:10px">
                <input type="hidden" name="action" value="ma_push_test"><?php wp_nonce_field('ma_push_test'); ?>
                <button class="ma-btn ghost" type="submit">অ্যাডমিনদের ফোনে পরীক্ষার পুশ পাঠান</button>
            </form>
        <?php endif; ?>
    </section>
    <div class="ma-grid">
        <section class="ma-card pad">
            <h2>Google লগইন</h2>
            <p class="muted">Google Cloud Console-এর <strong>Web application</strong> ধরনের OAuth Client ID। অ্যাপ থেকে আসা লগইন এই ID-র জন্য বানানো কি না, সার্ভার তা Google-কে দিয়ে যাচাই করে।</p>
            <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
                <input type="hidden" name="action" value="ma_acc_settings">
                <?php wp_nonce_field('ma_acc_settings'); ?>
                <label>Web Client ID (একাধিক হলে কমা দিয়ে)
                    <input type="text" name="client_ids" value="<?php echo esc_attr($v['clients']); ?>" placeholder="1234567890-abc….apps.googleusercontent.com" spellcheck="false">
                </label>
                <button class="ma-btn" type="submit">রাখুন</button>
            </form>
        </section>
        <section class="ma-card pad">
            <h2>অবস্থা</h2>
            <ul class="ma-checks">
                <li class="<?php echo $set ? 'ok' : ''; ?>"><?php echo $set ? 'Client ID বসানো আছে' : 'Client ID এখনো বসানো হয়নি'; ?></li>
                <li class="<?php echo is_ssl() ? 'ok' : ''; ?>"><?php echo is_ssl() ? 'সাইট HTTPS-এ চলছে' : 'সাইট HTTPS-এ নেই — অ্যাপ যুক্ত হবে না'; ?></li>
                <li class="ok">অ্যাপ যেখানে লগইন পাঠায়:
                    <span class="ma-code"><code id="ma-endpoint"><?php echo esc_html($v['endpoint']); ?></code><button type="button" class="ma-icon" data-copy="ma-endpoint" title="কপি" aria-label="কপি"><svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true"><path fill="currentColor" d="M8 3h10a2 2 0 0 1 2 2v12h-2V5H8V3Zm-3 4h10a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2Zm0 2v10h10V9H5Z"/></svg></button></span>
                </li>
            </ul>
            <h3>কী রাখা হয়</h3>
            <p class="muted">Google অ্যাকাউন্টের নাম, ইমেইল, ছবির লিংক, কবে যোগ দিয়েছেন ও শেষ কবে খুলেছেন, অ্যাপের সংস্করণ, ট্রায়াল আর প্রিমিয়াম। এর বেশি কিছু না।</p>
        </section>
    </div>
    <?php
}

function ma_acc_styles() {
    ?>
    <style>
    .ma{--g:#0E7A5F;--gd:#0A5C47;--gt:#E7F4EF;--ink:#111827;--mut:#6B7280;--mut2:#374151;--line:#E5E7EB;--bg:#F6F7F9;--amber:#B45309;--amt:#FEF3E2;--rose:#BE123C;--rot:#FFF1F2;--blue:#1D4ED8;--blt:#EEF2FF;
        font-family:"Hind Siliguri",system-ui,-apple-system,"Segoe UI",sans-serif;color:var(--ink);max-width:1240px;margin:16px 20px 40px 0}
    .ma *{box-sizing:border-box}
    .ma .muted{color:var(--mut)}
    .ma-hero{background:var(--g);background-image:radial-gradient(120% 140% at 100% 0%,rgba(255,255,255,.14) 0,rgba(255,255,255,0) 55%),linear-gradient(160deg,#0E7A5F 0%,#0A5C47 100%);color:#fff;border-radius:22px;padding:22px 26px 24px;box-shadow:0 10px 30px -12px rgba(10,92,71,.55)}
    .ma-hero-top{display:flex;align-items:center;justify-content:space-between;gap:16px;flex-wrap:wrap}
    .ma-brand{display:flex;align-items:center;gap:12px}
    .ma-mark{width:42px;height:42px;border-radius:13px;background:rgba(255,255,255,.16);display:grid;place-items:center;color:#fff}
    .ma-brand-name{font-size:20px;font-weight:700;line-height:1.2}
    .ma-brand-sub{font-size:13px;color:#C9EBDD}
    .ma-fb{display:grid;gap:10px;padding:0 16px 16px}
    a.ma-fb-item{display:block;color:inherit;text-decoration:none;transition:border-color .15s}
    a.ma-fb-item:hover{border-color:var(--g)}
    .ma-fb-last{margin:-6px 0 0;font-size:13.5px}
    .ma-chat{display:flex;flex-direction:column;gap:10px;padding:8px 16px 16px;max-width:760px}
    .ma-msg{max-width:78%;border-radius:16px;padding:10px 14px;line-height:1.6;font-size:15px}
    .ma-msg.them{align-self:flex-start;background:#F3F4F6;border-bottom-left-radius:4px}
    .ma-msg.us{align-self:flex-end;background:var(--gt);color:#064E3B;border-bottom-right-radius:4px}
    .ma-msg-img{display:block;max-width:260px;max-height:260px;border-radius:10px;margin-top:6px}
    .ma-msg-file{display:inline-block;margin-top:6px;font-weight:600;color:var(--gd)}
    .ma-msg-meta{font-size:12px;color:var(--mut);margin-top:4px}
    .ma-reply{border-top:1px solid var(--line);padding:14px 16px;display:grid;gap:10px;max-width:760px}
    .ma-reply textarea{width:100%;border:1px solid var(--line);border-radius:12px;padding:10px 12px;font:inherit;font-size:15px}
    .ma-reply-row{display:flex;align-items:center;gap:10px}
    .ma-reply-row .ma-btn:last-child{margin-left:auto}
    .ma-fb-item{border:1px solid var(--line);border-radius:14px;padding:14px 16px;background:#fff}
    .ma-fb-item.new{border-color:#A7D9C8;background:#F6FBF9}
    .ma-fb-head{display:flex;flex-wrap:wrap;align-items:center;gap:8px;font-size:14px}
    .ma-fb-text{margin:10px 0 12px;font-size:15px;line-height:1.65;white-space:normal}
    .ma-fb-ops{display:flex;flex-wrap:wrap;gap:8px;align-items:center}
    .ma-fb-ops form{margin:0}
    .ma-tabs{display:flex;gap:4px;background:rgba(0,0,0,.18);padding:4px;border-radius:12px}
    .ma-tabs a{color:#DDF2EA;text-decoration:none;font-weight:600;font-size:14px;padding:7px 16px;border-radius:9px;transition:background .15s}
    .ma-tabs a:hover{background:rgba(255,255,255,.1);color:#fff}
    .ma-tabs a.on{background:#fff;color:var(--gd)}
    .ma-tabs a:focus-visible,.ma-chip:focus-visible,.ma-btn:focus-visible,.ma-icon:focus-visible{outline:2px solid #A7F3D0;outline-offset:2px;box-shadow:none}
    .ma-figures{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin-top:20px}
    .ma-fig{background:rgba(255,255,255,.1);border:1px solid rgba(255,255,255,.14);border-radius:16px;padding:14px 16px;display:flex;flex-direction:column;gap:2px;min-width:0}
    .ma-fig span{font-size:13px;color:#C9EBDD;font-weight:500}
    .ma-fig strong{font-size:30px;font-weight:700;line-height:1.15;letter-spacing:-.01em}
    .ma-fig em{font-style:normal;font-size:12.5px;color:#A7DCC8;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .ma-toast{margin:14px 0 0;background:var(--gt);color:var(--gd);border-radius:12px;padding:11px 16px;font-weight:500;border-left:4px solid var(--g)}
    .ma-toast.bad{background:var(--rot);color:var(--rose);border-color:var(--rose)}
    .ma-card{background:#fff;border:1px solid var(--line);border-radius:18px;margin-top:16px;box-shadow:0 1px 2px rgba(17,24,39,.04)}
    .ma-card.pad{padding:20px 22px}
    .ma-card h2{font-size:19px;margin:0;font-weight:700;color:var(--ink)}
    .ma-card h3{font-size:15px;margin:18px 0 4px;font-weight:700}
    .ma-bar{display:flex;align-items:center;justify-content:space-between;gap:12px;padding:18px 20px 10px;flex-wrap:wrap}
    .ma-bar-title{display:flex;align-items:baseline;gap:10px}
    .ma-count{font-size:13px;color:var(--mut);background:var(--bg);padding:2px 10px;border-radius:999px}
    .ma-bar-actions{display:flex;gap:8px;flex-wrap:wrap}
    .ma-bar-actions form{margin:0}
    .ma-btn{display:inline-flex;align-items:center;gap:7px;height:40px;padding:0 16px;border-radius:11px;border:1px solid var(--g);background:var(--g);color:#fff;font:inherit;font-weight:600;font-size:14px;cursor:pointer;text-decoration:none;transition:background .15s,transform .05s}
    .ma-btn:hover{background:var(--gd);border-color:var(--gd);color:#fff}
    .ma-btn:active{transform:translateY(1px)}
    .ma-btn.ghost{background:#fff;color:var(--mut2);border-color:var(--line)}
    .ma-btn.ghost:hover{background:var(--bg);color:var(--ink)}
    .ma-btn.soft{background:var(--gt);color:var(--gd);border-color:var(--gt)}
    .ma-btn.soft:hover{background:#D3EDE3}
    .ma-btn.small{height:32px;padding:0 12px;font-size:13px;border-radius:9px}
    .ma-btn.danger{background:var(--rose);border-color:var(--rose)}
    .ma-btn.danger:hover{background:#9F1239}
    .ma-tools{display:flex;gap:12px;align-items:center;padding:4px 20px 14px;flex-wrap:wrap;margin:0}
    .ma label.ma-search{flex:1 1 260px;display:flex;flex-direction:row;margin:0;font-weight:400;align-items:center;gap:8px;background:var(--bg);border:1px solid transparent;border-radius:12px;padding:0 12px;height:42px;color:var(--mut);transition:border-color .15s,background .15s}
    .ma label.ma-search:focus-within{background:#fff;border-color:var(--g)}
    .ma-search input{border:0!important;background:transparent!important;box-shadow:none!important;outline:0;flex:1;font:inherit;font-size:14px;color:var(--ink);min-height:0;padding:0}
    .ma-chips{display:flex;gap:6px;flex-wrap:wrap}
    .ma-chip{font-size:13.5px;font-weight:500;color:var(--mut2);text-decoration:none;padding:6px 13px;border-radius:999px;border:1px solid var(--line);background:#fff;transition:all .15s}
    .ma-chip:hover{border-color:var(--g);color:var(--gd)}
    .ma-chip.on{background:var(--ink);border-color:var(--ink);color:#fff}
    .ma-table-wrap{overflow-x:auto;border-top:1px solid var(--line)}
    .ma-table{width:100%;border-collapse:collapse;font-size:14px}
    .ma-table th{text-align:left;font-weight:600;font-size:12.5px;color:var(--mut);padding:11px 16px;background:#FBFBFC;border-bottom:1px solid var(--line);white-space:nowrap}
    .ma-table td{padding:12px 16px;border-bottom:1px solid #F1F2F4;vertical-align:middle}
    .ma-table tbody tr{transition:background .12s}
    .ma-table tbody tr:hover{background:#F8FBFA}
    .ma-table tbody tr:last-child td{border-bottom:0}
    .ma-table .right{text-align:right}
    .ma-table td.muted{color:var(--mut);white-space:nowrap}
    .ma-who{display:flex;align-items:center;gap:12px;min-width:220px}
    .ma-av{width:40px;height:40px;border-radius:12px;flex:none;object-fit:cover;display:grid;place-items:center;font-weight:700;font-size:14px;color:hsl(var(--h,158) 55% 28%);background:hsl(var(--h,158) 55% 92%)}
    .ma-av.big{width:52px;height:52px;border-radius:15px;font-size:18px}
    .ma-who-text{display:flex;flex-direction:column;min-width:0}
    .ma-who-text strong{font-weight:600;color:var(--ink);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:280px}
    .ma-who-text span{font-size:13px;color:var(--mut);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:280px}
    .ma-ver{display:block;font-size:12px;color:#9CA3AF}
    .ma-pill{display:inline-flex;align-items:center;gap:6px;font-size:12.5px;font-weight:600;padding:3px 11px 3px 9px;border-radius:999px;white-space:nowrap}
    .ma-pill::before{content:"";width:7px;height:7px;border-radius:50%;background:currentColor}
    .ma-pill.pro{background:var(--gt);color:var(--gd)}
    .ma-pill.trial{background:var(--amt);color:var(--amber)}
    .ma-pill.free{background:#F3F4F6;color:#4B5563}
    .ma-pill.expired{background:var(--rot);color:var(--rose)}
    .ma-pill.waiting{background:var(--blt);color:var(--blue)}
    .ma-ops{display:inline-flex;align-items:center;gap:4px;justify-content:flex-end}
    .ma-ops .ma-btn{margin-left:6px;min-width:104px;justify-content:center}
    .ma-icon{width:34px;height:34px;display:grid;place-items:center;border-radius:10px;border:0;background:transparent;color:var(--mut);cursor:pointer;transition:background .15s,color .15s}
    .ma-icon:hover{background:var(--gt);color:var(--gd)}
    .ma-icon.danger:hover{background:var(--rot);color:var(--rose)}
    .ma-pages{display:flex;justify-content:space-between;align-items:center;padding:12px 20px;border-top:1px solid var(--line)}
    .ma-pages div{display:flex;gap:8px}
    .ma-empty{text-align:center;padding:48px 20px 56px;border-top:1px solid var(--line)}
    .ma-empty-art{width:68px;height:68px;border-radius:22px;background:var(--gt);color:var(--g);display:grid;place-items:center;margin:0 auto 14px}
    .ma-empty h3{font-size:17px;margin:0 0 4px}
    .ma-empty p{color:var(--mut);margin:0}
    .ma-empty a,.ma-foot a{color:var(--g)}
    .ma-foot{display:flex;gap:8px;align-items:center;color:var(--mut);font-size:13px;margin:18px 4px 0}
    .ma-grid{display:grid;grid-template-columns:1.2fr 1fr;gap:16px}
    .ma-grid .ma-card{margin-top:16px}
    .ma label{display:flex;flex-direction:column;gap:6px;font-weight:600;font-size:13.5px;color:var(--mut2);margin:14px 0}
    .ma label input[type=text],.ma label input[type=email],.ma label input[type=number],.ma label input[type=url],.ma label input[type=password],.ma label select{height:42px;border:1px solid var(--line);border-radius:11px;padding:0 12px;font:inherit;font-weight:400;font-size:14px;color:var(--ink);box-shadow:none}
    .ma-table input[type=number],.ma-card select{height:32px;border:1px solid var(--line);border-radius:9px;padding:0 8px;font:inherit;font-size:13px}
    .ma label input:focus{border-color:var(--g);box-shadow:0 0 0 3px rgba(14,122,95,.15);outline:0}
    .ma .ma-check{flex-direction:row;align-items:center;gap:8px;font-weight:500}
    .ma-checks{list-style:none;margin:12px 0 0;padding:0;display:flex;flex-direction:column;gap:10px}
    .ma-checks li{display:flex;flex-wrap:wrap;align-items:center;gap:8px;font-size:14px;color:var(--rose)}
    .ma-checks li::before{content:"!";width:20px;height:20px;border-radius:50%;background:var(--rot);color:var(--rose);font-weight:700;display:grid;place-items:center;font-size:12px}
    .ma-checks li.ok{color:var(--mut2)}
    .ma-checks li.ok::before{content:"✓";background:var(--gt);color:var(--g)}
    .ma-code{display:inline-flex;align-items:center;gap:4px;background:var(--bg);border-radius:9px;padding:2px 2px 2px 10px;max-width:100%}
    .ma-code code{background:none;padding:0;font-size:12.5px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
    .ma-dialog{border:0;border-radius:20px;padding:24px;width:min(460px,calc(100vw - 32px));box-shadow:0 24px 60px -12px rgba(17,24,39,.35);font-family:"Hind Siliguri",system-ui,sans-serif;color:var(--ink)}
    .ma-dialog.narrow{width:min(400px,calc(100vw - 32px))}
    .ma-dialog::backdrop{background:rgba(17,24,39,.45);backdrop-filter:blur(2px)}
    .ma-dialog h3{font-size:19px;margin:0 0 6px}
    .ma-dialog p{margin:0 0 4px;line-height:1.6}
    .ma-dialog form{margin:0}
    .ma-days{border:0;padding:0;margin:14px 0 0}
    .ma-days legend{font-weight:600;font-size:13.5px;color:var(--mut2);margin-bottom:8px}
    .ma-days{display:flex;gap:8px;flex-wrap:wrap}
    .ma-days label{margin:0;flex-direction:row}
    .ma-days input{position:absolute;opacity:0;pointer-events:none}
    .ma-days span{display:inline-block;padding:8px 14px;border:1px solid var(--line);border-radius:10px;font-weight:600;cursor:pointer;transition:all .15s}
    .ma-days input:checked+span{background:var(--gt);border-color:var(--g);color:var(--gd)}
    .ma-days input:focus-visible+span{outline:2px solid var(--g);outline-offset:2px}
    .ma-dialog-actions{display:flex;justify-content:flex-end;gap:8px;margin-top:20px}
    .ma-view-head{display:flex;gap:14px;align-items:center;margin-bottom:14px}
    .ma-view-head h3{margin:0}
    .ma-dl{display:grid;grid-template-columns:120px 1fr;gap:8px 12px;margin:0;font-size:14px}
    .ma-dl dt{color:var(--mut)}
    .ma-dl dd{margin:0;font-weight:500;word-break:break-word}
    .ma-admins{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:10px;margin:8px 0 6px}
    .ma-admin{display:flex;align-items:center;gap:12px;border:1px solid var(--line);border-radius:14px;padding:10px 12px}
    .ma-admin .ma-who-text{flex:1;min-width:0}
    .ma-admin form{margin:0}
    .ma-ai-row.three>div{display:flex;align-items:flex-end;padding-bottom:6px}
    .ma label input[type=email]{height:42px}
    .ma-ai-head{display:flex;justify-content:space-between;gap:16px;align-items:flex-start}
    .ma-ai-head p{margin:4px 0 0;max-width:720px;line-height:1.6}
    .ma-ai-stats{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px;margin:16px 0 4px}
    .ma-ai-stats div{background:var(--bg);border-radius:14px;padding:12px 14px;display:flex;flex-direction:column}
    .ma-ai-stats strong{font-size:22px;font-weight:700}
    .ma-ai-stats span{font-size:12.5px;color:var(--mut)}
    .ma-ai-row{display:grid;grid-template-columns:2fr 1fr 1fr;gap:12px}
    .ma-ai-row label{margin:6px 0}
    .ma label input[type=password]{height:42px;border:1px solid var(--line);border-radius:11px;padding:0 12px;font:inherit;font-weight:400;font-size:14px;box-shadow:none}
    .ma label input:disabled{background:var(--bg);color:var(--mut)}
    .ma-tip{font-size:13px;margin:6px 0 14px;line-height:1.6}
    .ma-tip code{font-size:12px;background:var(--bg);padding:1px 6px;border-radius:6px}
    .ma-switch{margin:14px 0 4px!important;font-size:14.5px!important;color:var(--ink)!important}
    .ma-switch input{position:absolute;opacity:0}
    .ma-switch-ui{width:42px;height:24px;border-radius:999px;background:#D1D5DB;position:relative;transition:background .15s;flex:none}
    .ma-switch-ui::after{content:"";position:absolute;top:3px;left:3px;width:18px;height:18px;border-radius:50%;background:#fff;transition:transform .15s;box-shadow:0 1px 2px rgba(0,0,0,.2)}
    .ma-switch input:checked+.ma-switch-ui{background:var(--g)}
    .ma-switch input:checked+.ma-switch-ui::after{transform:translateX(18px)}
    .ma-switch input:focus-visible+.ma-switch-ui{outline:2px solid var(--g);outline-offset:2px}
    .ma-badge{font-style:normal;display:inline-grid;place-items:center;min-width:20px;height:20px;padding:0 6px;margin-left:6px;border-radius:999px;background:#F59E0B;color:#111827;font-size:12px;font-weight:700}
    .ma-tabs a{display:inline-flex;align-items:center}
    .ma-mono{font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:13px;letter-spacing:.02em}
    .ma-pay-sum{margin-top:16px}
    .ma-pay-sum div{background:#fff;border:1px solid var(--line)}
    .ma-pad{padding:0 20px 14px;margin:0;line-height:1.6;max-width:860px}
    .ma-ai-row.two{grid-template-columns:1fr 1fr}
    .ma-ai-row.three{grid-template-columns:1fr 1fr 1fr}
    .ma label select,.ma-dialog label select,.ma label input[type=time],.ma label input[type=date]{height:42px;border:1px solid var(--line);border-radius:11px;padding:0 10px;font:inherit;font-weight:400;font-size:14px;max-width:none;width:100%}
    .ma label textarea{border:1px solid var(--line);border-radius:11px;padding:10px 12px;font-family:ui-monospace,monospace;font-size:13px;font-weight:400;line-height:1.7}
    .ma-dialog.wide{width:min(640px,calc(100vw - 32px))}
    .ma-dialog label{display:flex;flex-direction:column;gap:6px;font-weight:600;font-size:13.5px;color:var(--mut2);margin:12px 0}
    .ma-dialog label input[type=text]{height:42px;border:1px solid var(--line);border-radius:11px;padding:0 12px;font:inherit;font-weight:400;font-size:14px}
    .ma-dialog .ma-check{flex-direction:row;align-items:center;gap:8px;font-weight:500}
    .ma-notes{display:grid;grid-template-columns:repeat(auto-fill,minmax(330px,1fr));gap:14px;padding:4px 20px 20px}
    .ma-note{border:1px solid var(--line);border-radius:16px;padding:14px;display:flex;flex-direction:column;gap:12px;background:linear-gradient(180deg,#F8FBFA,#fff)}
    .ma-note.off{opacity:.6}
    .ma-note-phone{background:#fff;border-radius:14px;padding:10px 12px;box-shadow:0 4px 16px -8px rgba(17,24,39,.3);display:flex;flex-direction:column;gap:2px}
    .ma-note-app{font-size:11.5px;color:var(--mut);display:flex;align-items:center;gap:6px}
    .ma-note-app i{width:14px;height:14px;border-radius:4px;background:var(--g);display:inline-block}
    .ma-note-phone strong{font-size:14.5px}
    .ma-note-phone span:last-child{font-size:13px;color:var(--mut2);line-height:1.45}
    .ma-note-meta{display:flex;flex-wrap:wrap;gap:6px;align-items:center;font-size:12.5px;color:var(--mut)}
    .ma-note-meta span:not(.ma-pill){background:var(--bg);padding:2px 9px;border-radius:999px}
    .ma-note-ops{display:flex;gap:6px;align-items:center;justify-content:flex-end}
    .ma-note-ops form{margin:0}
    .ma-seg{display:inline-flex;background:var(--bg);border-radius:10px;padding:3px;gap:2px}
    .ma-seg button{border:0;background:transparent;font:inherit;font-size:13.5px;font-weight:600;color:var(--mut2);padding:6px 14px;border-radius:8px;cursor:pointer}
    .ma-seg button.on{background:#fff;color:var(--gd);box-shadow:0 1px 3px rgba(17,24,39,.12)}
    .ma-growth{display:grid;grid-template-columns:repeat(30,minmax(0,1fr));gap:4px;align-items:end;height:150px;padding:8px 20px 0}
    .ma-growth.months{grid-template-columns:repeat(12,minmax(0,1fr));gap:10px}
    .ma-growth[hidden]{display:none}
    .ma-gbar{display:flex;flex-direction:column;justify-content:flex-end;align-items:center;height:100%;text-decoration:none;color:var(--mut);position:relative;min-width:0}
    .ma-gbar i{display:block;width:100%;max-width:34px;background:#BFE3D5;border-radius:5px 5px 2px 2px;transition:background .15s}
    .ma-gbar:hover i,.ma-gbar.on i{background:var(--g)}
    .ma-gbar b{font-size:11px;font-weight:700;color:var(--gd);line-height:1.3}
    .ma-gbar span{font-size:10.5px;margin-top:3px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;max-width:100%}
    .ma-src-line{display:flex;gap:8px;align-items:center;flex-wrap:wrap;padding:14px 20px 18px;border-top:1px solid var(--line);margin-top:12px}
    .ma-when{padding-top:0}
    .ma-when .ma-inline{flex-direction:row;align-items:center;gap:6px;margin:0;font-weight:500}
    .ma-when .ma-inline input{height:34px;border:1px solid var(--line);border-radius:9px;padding:0 8px;font:inherit;font-size:13px}
    .ma-inline-form{margin:0}
    .ma-bk-status{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:10px;padding:0 20px 16px}
    .ma-bk-status div{border-radius:14px;padding:12px 14px;display:flex;flex-direction:column;gap:3px;font-size:13.5px;line-height:1.55}
    .ma-bk-status div.ok{background:var(--bg)}
    .ma-bk-status div.bad{background:var(--amt);color:#7C2D12}
    .ma-bk-status strong{font-size:14.5px}
    .ma-meter{position:relative;min-width:140px;height:22px;background:var(--bg);border-radius:7px;overflow:hidden}
    .ma-meter i{position:absolute;left:0;top:0;bottom:0;background:#BFE3D5}
    .ma-meter b{position:relative;padding-left:8px;font-size:12.5px;line-height:22px}
    .ma-daily td,.ma-daily th{padding:9px 12px}
    .ma-day-grid{display:grid;grid-template-columns:1.8fr 1fr;gap:0;border-top:1px solid var(--line)}
    .ma-rules{padding:4px 22px 16px;display:grid;gap:4px;font-size:13.5px;color:var(--mut2)}
    .ma-rules strong{color:var(--ink)}
    .ma-cat td{vertical-align:top}
    .ma-rules input[type=text]{width:100%;min-width:140px}
    .ma-rules td{vertical-align:middle}
    .ma-dim td{opacity:.55}
    .ma-tag{display:inline-block;margin-left:6px;padding:1px 8px;border-radius:999px;background:var(--line);font-size:11.5px;font-weight:600;color:var(--mut2)}
    .ma-tag.srv{background:var(--gt);color:var(--gd)}
    .ma-day-grid>.ma-table-wrap{border-top:0}
    .ma-day-grid>.ma-table-wrap+.ma-table-wrap{border-left:1px solid var(--line)}
    @media (max-width:1000px){.ma-day-grid{grid-template-columns:1fr}.ma-day-grid>.ma-table-wrap+.ma-table-wrap{border-left:0;border-top:1px solid var(--line)}}
    .ma-inbox{display:flex;flex-direction:column;border-top:1px solid var(--line)}
    .ma-inbox-row{display:flex;gap:14px;align-items:flex-start;padding:14px 20px;border-bottom:1px solid #F1F2F4;text-decoration:none;color:inherit;transition:background .12s}
    .ma-inbox-row:hover{background:#F8FBFA}
    .ma-inbox-row.new{background:#F3FAF7}
    .ma-inbox-main{flex:1;min-width:0;display:flex;flex-direction:column;gap:4px}
    .ma-inbox-top{display:flex;justify-content:space-between;gap:10px;font-size:14.5px}
    .ma-inbox-top .muted{font-size:12.5px;white-space:nowrap}
    .ma-inbox-text{font-size:14px;color:var(--mut2);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .ma-inbox-tags{display:flex;flex-wrap:wrap;gap:6px;align-items:center;font-size:12.5px}
    .ma-chat-sep{display:flex;align-items:center;gap:8px;align-self:center;font-size:12.5px;color:var(--mut);margin:10px 0 2px;background:var(--bg);border-radius:999px;padding:3px 6px 3px 4px}
    .ma-chat-sep form{margin:0}
    .ma-chat-sep .ma-icon{width:26px;height:26px}
    .ma-month{display:flex;align-items:center;gap:6px;font-size:16px}
    .ma-month .ma-icon{font-size:22px;line-height:1;text-decoration:none}
    .ma-kpis{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;padding:4px 20px 8px}
    .ma-kpis div{border:1px solid var(--line);border-radius:16px;padding:14px 16px;display:flex;flex-direction:column;gap:2px;background:#fff}
    .ma-kpis span{font-size:13px;color:var(--mut);font-weight:600}
    .ma-kpis strong{font-size:26px;font-weight:700;letter-spacing:-.01em}
    .ma-kpis em{font-style:normal;font-size:12.5px;color:var(--mut)}
    .ma-kpis .in{border-left:4px solid var(--g)}
    .ma-kpis .in strong{color:var(--gd)}
    .ma-kpis .out{border-left:4px solid #D97706}
    .ma-kpis .out strong{color:#B45309}
    .ma-kpis .loss{border-left:4px solid var(--rose)}
    .ma-kpis .loss strong{color:var(--rose)}
    .ma-kpis .cash{border-left:4px solid var(--blue)}
    .ma-small{font-size:12.5px}
    .ma-fin-filter{justify-content:space-between}
    .ma-fin-filter form{margin:0}
    .ma-fin-filter select{height:34px;border:1px solid var(--line);border-radius:9px;padding:0 10px;font:inherit;font-size:13.5px}
    .ma-fin-sum{font-size:13.5px;color:var(--mut)}
    .ma-fin-sum b.in,.ma-in{color:var(--gd)}
    .ma-fin-sum b.out,.ma-out{color:#B45309}
    .ma-bars2{min-width:160px}
    .ma-bars2 i{display:block;height:7px;border-radius:4px;margin:2px 0}
    .ma-bars2 i.in{background:#7CC8AE}
    .ma-bars2 i.out{background:#F2B36B}
    .ma-row-on{background:#F3FAF7}
    .ma-table td a{color:var(--gd);font-weight:600;text-decoration:none}
    @media (max-width:900px){.ma-kpis{grid-template-columns:repeat(2,minmax(0,1fr))}.ma-bk-status{grid-template-columns:1fr}.ma-growth{gap:2px;padding:8px 10px 0}.ma-gbar span{display:none}.ma-growth.months .ma-gbar span{display:block;font-size:9px}}
    @media (max-width:1100px){.ma .hide-m{display:none}}
    @media (max-width:900px){.ma-ai-row,.ma-ai-row.two,.ma-ai-row.three{grid-template-columns:1fr}.ma-ai-stats{grid-template-columns:repeat(2,minmax(0,1fr))}.ma-figures{grid-template-columns:repeat(2,minmax(0,1fr))}.ma-grid{grid-template-columns:1fr}.ma .hide-s{display:none}.ma-ops .ma-btn{display:none}}
    @media (max-width:782px){.ma{margin-right:10px}.ma-hero{padding:18px}.ma-fig strong{font-size:24px}}
    </style>
    <?php
}

function ma_acc_script() {
    ?>
    <script>
    (function () {
        function fill(dlg, m) {
            dlg.querySelectorAll('[data-f]').forEach(function (el) {
                var k = el.getAttribute('data-f');
                if (k === 'initial') { el.textContent = (m.name || '?').trim().charAt(0).toUpperCase(); return; }
                var val = m[k] === undefined || m[k] === '' ? '—' : String(m[k]);
                if (el.type === 'checkbox') { el.checked = !!m[k]; }
                else if (el.tagName === 'INPUT' || el.tagName === 'SELECT') { el.value = m[k] === undefined || m[k] === null ? '' : String(m[k]); }
                else { el.textContent = val; }
            });
            var stop = dlg.querySelector('input[name=mode]'); if (stop) { stop.checked = false; }
            var none = dlg.querySelector('input[name=days][value="0"]'); if (none && dlg.id === 'ma-edit') { none.checked = true; }
        }
        document.addEventListener('click', function (e) {
            var grow = e.target.closest('[data-grow]');
            if (grow) {
                var box = grow.closest('.ma-card');
                box.querySelectorAll('[data-grow]').forEach(function (b) { b.classList.toggle('on', b === grow); });
                box.querySelectorAll('[data-g]').forEach(function (g) { g.hidden = g.getAttribute('data-g') !== grow.getAttribute('data-grow'); });
                return;
            }
            var open = e.target.closest('[data-open]');
            if (open) {
                var dlg = document.getElementById(open.getAttribute('data-open'));
                if (!dlg) { return; }
                if (open.dataset.m) { fill(dlg, JSON.parse(open.dataset.m)); }
                dlg.showModal();
                var first = dlg.querySelector('input:not([type=hidden]):not([type=radio])'); if (first) { first.focus(); }
                return;
            }
            if (e.target.closest('[data-close]')) { e.target.closest('dialog').close(); return; }
            if (e.target.tagName === 'DIALOG') {
                var r = e.target.getBoundingClientRect();
                if (e.clientX < r.left || e.clientX > r.right || e.clientY < r.top || e.clientY > r.bottom) { e.target.close(); }
                return;
            }
            var copy = e.target.closest('[data-copy]');
            if (copy) {
                var src = document.getElementById(copy.getAttribute('data-copy'));
                var text = src.value !== undefined ? src.value : src.textContent;
                var done = function () {
                    copy.title = 'কপি হয়েছে';
                    if (copy.tagName === 'BUTTON') {
                        var was = copy.dataset.was || copy.textContent;
                        copy.dataset.was = was;
                        copy.textContent = 'কপি হয়েছে ✓';
                        setTimeout(function () { copy.textContent = was; }, 2500);
                    }
                };
                var fallback = function () {
                    // http:// sites and old browsers have no clipboard API.
                    var t = document.createElement('textarea');
                    t.value = text; t.setAttribute('readonly', ''); t.style.position = 'fixed'; t.style.opacity = '0';
                    document.body.appendChild(t); t.select();
                    try { document.execCommand('copy'); done(); } catch (err) {}
                    document.body.removeChild(t);
                };
                if (navigator.clipboard && window.isSecureContext) { navigator.clipboard.writeText(text).then(done, fallback); } else { fallback(); }
            }
        });
    })();
    </script>
    <?php
}

/** AI cost by model (today and this month), answer sources, prices and budgets. */
/** The "AI খরচ" tab: what the AI cost and where answers came from (only reading — nothing to set here). */
function ma_acc_render_ai_report($v) {
    $c = $v['ai_costs'] ?? null;
    $st = $v['ai_stats'];
    if (!is_array($c)) {
        return;
    }
    $usd = function ($x) { return '$' . number_format((float) $x, 4); };
    $table = function ($rows, $title) use ($usd) { ?>
        <h3><?php echo esc_html($title); ?></h3>
        <?php if (!$rows) : ?><p class="muted">এখনো কিছু নেই।</p><?php return; endif; ?>
        <table class="ma-table ma-cost">
            <thead><tr><th>মডেল</th><th>প্ল্যান</th><th>প্রশ্ন</th><th>ইনপুট</th><th>ক্যাশে লেখা</th><th>ক্যাশ থেকে</th><th>আউটপুট</th><th>খরচ</th><th>প্রতি প্রশ্নে</th><th>ক্যাশ হিট</th></tr></thead>
            <tbody>
            <?php foreach ($rows as $r) : ?>
                <tr>
                    <td><?php echo esc_html($r['model']); ?><?php if (!$r['priced']) : ?> <span class="ma-pill expired">দাম নেই</span><?php endif; ?></td>
                    <td><?php echo esc_html($r['plan']); ?></td>
                    <td><?php echo esc_html(ma_acc_bn(number_format($r['requests']))); ?></td>
                    <td><?php echo esc_html(ma_acc_bn(number_format($r['input']))); ?></td>
                    <td><?php echo esc_html(ma_acc_bn(number_format($r['cache_write']))); ?></td>
                    <td><?php echo esc_html(ma_acc_bn(number_format($r['cache_read']))); ?></td>
                    <td><?php echo esc_html(ma_acc_bn(number_format($r['output']))); ?></td>
                    <td><?php echo esc_html($usd($r['cost_usd'])); ?></td>
                    <td><?php echo esc_html($usd($r['per_request_usd'])); ?></td>
                    <td><?php echo esc_html(ma_acc_bn((string) round($r['cache_hit'] * 100))) . '%'; ?></td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
    <?php };
    $src = $c['sources_today'];
    $names = ['rules' => 'নিয়ম', 'local' => 'ফোনের মডেল', 'gemini' => 'Gemini', 'haiku' => 'Haiku', 'sonnet' => 'Sonnet', 'failed' => 'ব্যর্থ',
        'nlu_agree' => 'মিলে যাওয়ায় AI লাগেনি', 'nlu_cloud' => 'ক্লাউডের পড়া নেওয়া', 'nlu_cloud_rules' => 'ক্লাউড জিজ্ঞেস, নিয়ম রইল', 'nlu_cloud_fail' => 'ক্লাউড পাওয়া যায়নি',
        'nlu_same_sure' => 'মডেল-নিয়ম মিল (নিশ্চিত)', 'nlu_same' => 'মডেল-নিয়ম মিল', 'nlu_differ_sure' => 'অমিল (মডেল নিশ্চিত)', 'nlu_differ' => 'অমিল', 'nlu_off' => 'মডেল নেই'];
    $budget = $c['budget'] ?? [];
    $post = esc_url(admin_url('admin-post.php'));
    ?>
    <section class="ma-card pad">
        <h2>AI-এর খরচ</h2>
        <p class="muted">প্রতিটা উত্তরের আসল টোকেন আর দাম ধরে মডেল অনুযায়ী হিসাব। সদস্য কী বললেন তা রাখা হয় না। দাম, বাজেট আর key বদলাতে “সেটিংস”।</p>
        <div class="ma-ai-stats">
            <div><strong><?php echo esc_html(ma_acc_bn(number_format($st['requests']))); ?></strong><span>আজ AI প্রশ্ন</span></div>
            <div><strong><?php echo esc_html(ma_acc_bn(number_format($st['people']))); ?></strong><span>আজ ব্যবহার করেছেন</span></div>
            <div><strong><?php echo esc_html(ma_acc_bn(number_format($st['in'] + $st['out']))); ?></strong><span>আজকের টোকেন</span></div>
            <div><strong><?php echo esc_html(ma_acc_bn(number_format($st['month']))); ?></strong><span>এই মাসে প্রশ্ন</span></div>
        </div>
        <h3>বাজেট কতটা খরচ হলো</h3>
        <p><?php foreach (['free' => 'ফ্রি', 'pro' => 'প্রিমিয়াম'] as $plan => $label) : $b = $budget[$plan] ?? null; if (!$b) { continue; } ?>
            <span class="ma-pill"><?php echo esc_html($label . ' — আজ ' . $usd($b['spent_day']) . ' / ' . ((float) $b['day'] > 0 ? $usd($b['day']) : 'সীমা নেই') . ' · এই মাসে ' . $usd($b['spent_month']) . ' / ' . ((float) $b['month'] > 0 ? $usd($b['month']) : 'সীমা নেই')); ?></span>
        <?php endforeach; ?></p>
        <?php $table($c['today'], 'আজ'); $table($c['month'], 'এই মাসে'); ?>
        <h3>উত্তর কোথা থেকে এল</h3>
        <?php foreach (['আজ' => $src, 'এই মাসে' => $c['sources_month'] ?? []] as $when => $counts) : ?>
            <p><strong><?php echo esc_html($when); ?>:</strong> <?php foreach ($names as $k => $label) : if (empty($counts[$k])) { continue; } ?><span class="ma-pill"><?php echo esc_html($label . ': ' . ma_acc_bn((string) $counts[$k])); ?></span> <?php endforeach; ?></p>
        <?php endforeach; ?>
    </section>
    <?php
}

function ma_acc_render_ai_costs($c) {
    if (!is_array($c)) {
        return;
    }
    $usd = function ($x) { return '$' . number_format((float) $x, 4); };
    $post = esc_url(admin_url('admin-post.php'));
    ?>
    <section class="ma-card pad">
        <h2>AI-এর দাম আর বাজেট</h2>
        <p class="muted">খরচের হিসাব দেখতে উপরে “AI খরচ”।</p>
        <form method="post" action="<?php echo $post; ?>" class="ma-ai-form">
            <input type="hidden" name="action" value="ma_ai_costs"><?php wp_nonce_field('ma_ai_costs'); ?>
            <h3>দাম (ডলার, প্রতি ১০ লাখ টোকেন)</h3>
            <table class="ma-table">
                <thead><tr><th>মডেল</th><th>ইনপুট</th><th>ক্যাশে লেখা</th><th>ক্যাশ থেকে পড়া</th><th>আউটপুট</th></tr></thead>
                <tbody>
                <?php foreach ($c['prices'] as $model => $p) : $m = esc_attr($model); ?>
                    <tr><td><?php echo esc_html($model); ?></td>
                    <?php foreach (['in', 'cw', 'cr', 'out'] as $k) : ?><td><input type="text" inputmode="decimal" name="price[<?php echo $m; ?>][<?php echo $k; ?>]" value="<?php echo esc_attr((string) ($p[$k] ?? 0)); ?>"></td><?php endforeach; ?></tr>
                <?php endforeach; ?>
                </tbody>
            </table>
            <label>নতুন মডেল যোগ (নাম)<input type="text" name="new_model" placeholder="gemini-…"></label>
            <h3>বাজেট (ডলার; ০ = সীমা নেই)</h3>
            <label class="ma-check"><input type="checkbox" name="budget_auto" value="1" <?php checked(!empty($c['budget']['auto'])); ?>> আয় অনুযায়ী নিজে ঠিক হোক (লোকসান যেন না হয়): প্রিমিয়ামের আয়ের ২০% পর্যন্ত AI-তে, একজন প্রিমিয়াম সদস্যের খরচ তাঁর মাসিক দামের ৩০% পর্যন্ত, ফ্রি সবার জন্য মাসে $৩</label>
            <div class="ma-ai-row">
                <?php foreach (['free' => 'ফ্রি', 'pro' => 'প্রিমিয়াম'] as $plan => $label) : $b = $c['budget'][$plan]; ?>
                    <label><?php echo esc_html($label); ?> — দিনে<input type="text" inputmode="decimal" name="budget[<?php echo $plan; ?>][day]" value="<?php echo esc_attr((string) $b['day']); ?>"></label>
                    <label><?php echo esc_html($label); ?> — মাসে<input type="text" inputmode="decimal" name="budget[<?php echo $plan; ?>][month]" value="<?php echo esc_attr((string) $b['month']); ?>"></label>
                <?php endforeach; ?>
            </div>
            <p class="muted ma-tip">বাজেট শেষ হলে ওই প্ল্যানের AI বন্ধ থাকে, অ্যাপ নিজের নিয়মে বোঝে।</p>
            <button class="ma-btn" type="submit">রাখুন</button>
        </form>
    </section>
    <?php
}

/**
 * "AI মডেল": the on-phone model's mode, its versions (make live, share,
 * take back) and the readings to check — the same as the admin app's
 * AI › মডেল / পর্যালোচনা / সেটিংস (any admin; keys and costs stay with the owner).
 */
function ma_acc_render_nlu($n) {
    $set = $n['settings'] ?? ma_nlu_settings();
    $post = esc_url(admin_url('admin-post.php'));
    $ov = $n['overview'] ?? [];
    $intent_opts = function ($sel = '') use ($n) {
        $o = '<option value="">— বাছুন —</option>';
        foreach ((array) ($n['intents'] ?? []) as $i) {
            $o .= '<option value="' . esc_attr($i) . '"' . selected($sel, $i, false) . '>' . esc_html($i) . '</option>';
        }
        return $o;
    };
    ?>
    <section class="ma-card pad ma-ai">
        <h2>ফোনের মডেল</h2>
        <p class="muted">ছায়া: মডেল পড়ে, কিছু করে না। চালু: নিয়ম আর মডেল একমত হলে AI ডাকা হয় না; অমিল হলে ফ্রি সদস্যের বেলায় ক্লাউড জিজ্ঞেস হয় (তিনটার দুটো যা বলে)। শুরুতে অল্প % দিন।
        <?php if ($ov) : ?> শেখার নমুনা (৩০ দিন): <?php echo esc_html(ma_acc_bn((string) ($ov['samples_30d'] ?? 0))); ?> · ভুলের সংকেত প্রতি ১০০-তে <?php echo esc_html(ma_acc_bn((string) ($ov['error_signals_per_100'] ?? 0))); ?><?php endif; ?></p>
        <form method="post" action="<?php echo $post; ?>" class="ma-ai-form">
            <input type="hidden" name="action" value="ma_nlu_settings"><?php wp_nonce_field('ma_nlu_settings'); ?>
            <div class="ma-ai-row">
                <label>মোড
                    <select name="nlu[mode]">
                        <?php foreach (['off' => 'বন্ধ', 'shadow' => 'ছায়া', 'on' => 'চালু'] as $k => $l) : ?><option value="<?php echo $k; ?>" <?php selected($set['mode'], $k); ?>><?php echo esc_html($l); ?></option><?php endforeach; ?>
                    </select>
                </label>
                <label>কত % সদস্য<input type="number" min="0" max="100" name="nlu[pct]" value="<?php echo (int) $set['pct']; ?>"></label>
                <label>ফ্রি সদস্যের ক্লাউড মডেল<input type="text" name="nlu[free_model]" value="<?php echo esc_attr($set['free_model']); ?>"></label>
                <label>প্রিমিয়াম সদস্যের ক্লাউড মডেল<input type="text" name="nlu[pro_model]" value="<?php echo esc_attr($set['pro_model']); ?>"></label>
                <label>খুব অনিশ্চিত হলে (প্রিমিয়াম)<input type="text" name="nlu[escalate_model]" value="<?php echo esc_attr($set['escalate_model']); ?>"></label>
                <label>তার ভাগ, দিনে সর্বোচ্চ %<input type="number" step="0.5" min="0" max="20" name="nlu[escalate_share]" value="<?php echo esc_attr((string) round($set['escalate_share'] * 100, 1)); ?>"></label>
                <label>"খুব অনিশ্চিত" মানে নিশ্চয়তা এর নিচে (০–১)<input type="number" step="0.05" min="0" max="1" name="nlu[escalate_below]" value="<?php echo esc_attr((string) $set['escalate_below']); ?>"></label>
                <label>ফ্রি — সদস্যপ্রতি দিনে ক্লাউড<input type="number" min="0" name="nlu[free_per_user]" value="<?php echo (int) $set['free_per_user']; ?>"></label>
                <label>প্রিমিয়াম — সদস্যপ্রতি দিনে ক্লাউড<input type="number" min="0" name="nlu[pro_per_user]" value="<?php echo (int) $set['pro_per_user']; ?>"></label>
            </div>
            <label class="ma-check"><input type="checkbox" name="nlu[cloud_on]" value="1" <?php checked(!empty($set['cloud_on'])); ?>> ক্লাউডে বোঝা চালু</label>
            <button class="ma-btn" type="submit">রাখুন</button>
        </form>
    </section>

    <section class="ma-card pad">
        <h2>মডেলের সংস্করণ</h2>
        <p class="muted">নতুন মডেল GitHub থেকে <em>draft</em> হয়ে আসে। চালু করলে যত % দেবেন তত সদস্যের ফোন Wi-Fi-তে নামাবে; বাকিরা আগের চালু মডেল পান। “ফিরিয়ে নিন” দিলে সবাই আগেরটায় ফেরে।</p>
        <?php if (empty($n['models'])) : ?><p class="muted">এখনো কোনো মডেল আসেনি।</p><?php else : ?>
        <table class="ma-table">
            <thead><tr><th>সংস্করণ</th><th>অবস্থা</th><th>আকার</th><th>যাচাই</th><th>কাজ</th></tr></thead>
            <tbody>
            <?php foreach ($n['models'] as $m) : $ver = esc_attr($m['version']); ?>
                <tr>
                    <td><strong><?php echo esc_html($m['version']); ?></strong><br><span class="muted"><?php echo esc_html(ma_acc_date($m['created'])); ?></span></td>
                    <td><?php if ($m['status'] === 'live') : ?><span class="ma-pill pro">চালু · <?php echo esc_html(ma_acc_bn((string) $m['rollout_pct'])); ?>%</span><?php elseif ($m['status'] === 'draft') : ?><span class="ma-pill trial">draft</span><?php else : ?><span class="ma-pill expired">বন্ধ</span><?php endif; ?></td>
                    <td><?php echo esc_html(ma_acc_bn(number_format($m['size'] / 1e6, 1))); ?> MB</td>
                    <td><?php $e = (array) $m['eval']; echo esc_html($e ? implode(' · ', array_map(function ($k, $x) { return $k . ': ' . (is_numeric($x) ? round($x * 100, 1) . '%' : (is_scalar($x) ? $x : '')); }, array_keys($e), $e)) : '—'); ?></td>
                    <td>
                        <?php if ($m['status'] !== 'retired') : ?>
                        <form method="post" action="<?php echo $post; ?>" style="display:inline-flex;gap:6px;align-items:center">
                            <input type="hidden" name="action" value="ma_nlu_model"><?php wp_nonce_field('ma_nlu_model'); ?>
                            <input type="hidden" name="version" value="<?php echo $ver; ?>">
                            <input type="hidden" name="op" value="<?php echo $m['status'] === 'draft' ? 'live' : 'pct'; ?>">
                            <input type="number" name="pct" min="0" max="100" style="width:72px" value="<?php echo (int) ($m['status'] === 'draft' ? 10 : $m['rollout_pct']); ?>">%
                            <button class="ma-btn small" type="submit"><?php echo $m['status'] === 'draft' ? 'চালু করুন' : '% রাখুন'; ?></button>
                        </form>
                        <?php endif; ?>
                        <?php if ($m['status'] === 'live') : ?>
                        <form method="post" action="<?php echo $post; ?>" style="display:inline">
                            <input type="hidden" name="action" value="ma_nlu_model"><?php wp_nonce_field('ma_nlu_model'); ?>
                            <input type="hidden" name="version" value="<?php echo $ver; ?>"><input type="hidden" name="op" value="rollback">
                            <button class="ma-btn ghost small" type="submit">ফিরিয়ে নিন</button>
                        </form>
                        <?php endif; ?>
                    </td>
                </tr>
            <?php endforeach; ?>
            </tbody>
        </table>
        <?php endif; ?>
        <details style="margin-top:12px"><summary>হাতে একটা মডেল draft হিসেবে যোগ করুন</summary>
            <form method="post" action="<?php echo $post; ?>" class="ma-ai-form">
                <input type="hidden" name="action" value="ma_nlu_draft"><?php wp_nonce_field('ma_nlu_draft'); ?>
                <div class="ma-ai-row">
                    <label>সংস্করণ<input type="text" name="version" placeholder="2026.11.01-bert3"></label>
                    <label>ফাইলের ঠিকানা (https)<input type="url" name="url" placeholder="https://github.com/…/nlu-….tflite"></label>
                    <label>SHA-256<input type="text" name="sha256" spellcheck="false"></label>
                    <label>আকার (বাইট)<input type="number" name="size" min="0"></label>
                </div>
                <button class="ma-btn ghost" type="submit">draft রাখুন</button>
            </form>
        </details>
    </section>

    <section class="ma-card pad">
        <div style="display:flex;gap:10px;align-items:center;justify-content:space-between;flex-wrap:wrap">
            <h2 style="margin:0">পর্যালোচনা</h2>
            <?php if (!empty($n['review_all'])) : ?>
                <button type="button" class="ma-btn small" id="ma-review-copy-btn" data-copy="ma-review-copy">সব কপি করুন (<?php echo esc_html(ma_acc_bn((string) count($n['review_all']))); ?>টা)</button>
            <?php endif; ?>
        </div>
        <?php if (!empty($n['review_all'])) : ?><textarea id="ma-review-copy" readonly hidden><?php echo esc_textarea(ma_nlu_review_text($n['review_all'], $ov)); ?></textarea><?php endif; ?>
        <p class="muted">যেসব বার্তায় ফোন, ক্লাউড আর শেষ কাজ মেলেনি বা সদস্য “না” বলেছেন। নাম সরানো (<code>&lt;নাম১&gt;</code>)। ঠিকটা বেছে দিলে পরের শেখানোয় সবার আগে সেটা মানা হয়।</p>
        <?php if (empty($n['review'])) : ?><p class="muted">এখন দেখার মতো কিছু নেই।</p><?php endif; ?>
        <?php foreach ((array) ($n['review'] ?? []) as $r) : ?>
            <form method="post" action="<?php echo $post; ?>" class="ma-ai-form" style="border-top:1px solid var(--line);padding-top:12px;margin-top:12px">
                <input type="hidden" name="action" value="ma_nlu_label"><?php wp_nonce_field('ma_nlu_label'); ?>
                <input type="hidden" name="sample" value="<?php echo (int) $r['id']; ?>">
                <input type="hidden" name="phone_intents" value="<?php echo esc_attr(implode(',', $r['phone'])); ?>">
                <input type="hidden" name="cloud_intents" value="<?php echo esc_attr(implode(',', $r['cloud'])); ?>">
                <p style="font-size:16px;margin:0 0 6px"><?php echo esc_html($r['text']); ?></p>
                <p class="muted" style="margin:0 0 8px">ফোন: <?php echo esc_html(implode(', ', $r['phone']) ?: '—'); ?> (<?php echo esc_html(round($r['phone_conf'] * 100) . '%'); ?>) · ক্লাউড<?php echo $r['cloud_provider'] ? ' (' . esc_html($r['cloud_provider']) . ')' : ''; ?>: <?php echo esc_html(implode(', ', $r['cloud']) ?: '—'); ?> · শেষে: <?php echo esc_html(implode(', ', $r['final']) ?: '—'); ?><?php if ($r['signal']) : ?> · <span class="ma-pill expired">ভুলের সংকেত: <?php echo esc_html($r['signal']); ?></span><?php endif; ?></p>
                <div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center">
                    <?php if ($r['phone']) : ?><button class="ma-btn soft small" name="pick" value="phone">ফোন ঠিক</button><?php endif; ?>
                    <?php if ($r['cloud']) : ?><button class="ma-btn soft small" name="pick" value="cloud">ক্লাউড ঠিক</button><?php endif; ?>
                    <select name="intents[]"><?php echo $intent_opts(); ?></select>
                    <select name="intents[]"><?php echo $intent_opts(); ?></select>
                    <button class="ma-btn small" name="pick" value="other">এটাই ঠিক</button>
                </div>
            </form>
        <?php endforeach; ?>
    </section>
    <?php
}

/**
 * "উত্তরাধিকার": deaths reported by an heir the member chose, with the
 * document — the same list and decision as in the admin app.
 */
function ma_acc_render_heirs($claims) {
    $post = esc_url(admin_url('admin-post.php'));
    $names = ['review' => ['যাচাই বাকি', 'trial'], 'waiting' => ['১৪ দিনের অপেক্ষা', 'pro'], 'open' => ['খোলা', 'pro'], 'rejected' => ['মানা হয়নি', 'expired'], 'cancelled' => ['বাতিল', 'expired']];
    ?>
    <section class="ma-card pad">
        <h2>উত্তরাধিকারের অনুরোধ</h2>
        <p class="muted">সদস্য নিজে যাঁকে উত্তরাধিকারী বেছেছেন, শুধু তিনিই ইন্তেকালের খবর দিতে পারেন — মৃত্যু সনদের ছবিসহ। মানলে সদস্যের ফোনে আর ইমেইলে জানানো হয়; ১৪ দিনের মধ্যে সদস্য নিজে বাতিল না করলে উত্তরাধিকারী সদস্যের বেছে রাখা অংশ দেখতে পান। সেই অংশ তালাবদ্ধ — এই সার্ভার বা অ্যাডমিন খুলতে পারেন না।</p>
        <?php if (!$claims) : ?><p class="muted">কোনো অনুরোধ নেই।</p><?php endif; ?>
        <?php foreach ($claims as $c) : $st = $names[$c['status']] ?? [$c['status'], 'free']; ?>
            <div style="border-top:1px solid var(--line);padding-top:12px;margin-top:12px">
                <p style="margin:0 0 4px"><span class="ma-pill <?php echo esc_attr($st[1]); ?>"><?php echo esc_html($st[0]); ?></span> <strong><?php echo esc_html($c['owner']['name'] ?: $c['owner']['email']); ?></strong> (<?php echo esc_html($c['owner']['email']); ?>)</p>
                <p class="muted" style="margin:0 0 6px">খবর দিয়েছেন: <?php echo esc_html(($c['heir']['name'] ?: $c['heir']['email']) . ' · ' . $c['heir']['email'] . ($c['heir']['relation'] !== '' ? ' · সম্পর্ক: ' . $c['heir']['relation'] : '')); ?> · <?php echo esc_html(ma_acc_date(gmdate('Y-m-d H:i:s', strtotime($c['created'])))); ?></p>
                <?php if ($c['note'] !== '') : ?><p style="margin:0 0 6px"><?php echo esc_html($c['note']); ?></p><?php endif; ?>
                <?php if ($c['has_file']) : ?><p style="margin:0 0 8px"><a class="ma-btn ghost small" target="_blank" rel="noopener" href="<?php echo esc_url(wp_nonce_url(admin_url('admin-post.php?action=ma_fam_file&claim=' . (int) $c['id']), 'ma_fam_file')); ?>">কাগজ দেখুন (<?php echo esc_html($c['file_name']); ?>)</a></p><?php endif; ?>
                <?php if ($c['status'] === 'waiting' && $c['open_at']) : ?><p class="muted">খুলবে: <?php echo esc_html(ma_acc_date(gmdate('Y-m-d H:i:s', strtotime($c['open_at'])))); ?></p><?php endif; ?>
                <?php if ($c['admin_note'] !== '') : ?><p class="muted">নোট: <?php echo esc_html($c['admin_note']); ?></p><?php endif; ?>
                <?php if ($c['status'] === 'review') : ?>
                    <form method="post" action="<?php echo $post; ?>" style="display:flex;gap:8px;flex-wrap:wrap;align-items:center">
                        <input type="hidden" name="action" value="ma_fam_claim"><?php wp_nonce_field('ma_fam_claim'); ?>
                        <input type="hidden" name="claim" value="<?php echo (int) $c['id']; ?>">
                        <label style="flex:1;min-width:220px">নোট (ঐচ্ছিক)<input type="text" name="note" placeholder="যেমন: সনদ মিলেছে / ছবি অস্পষ্ট"></label>
                        <button class="ma-btn small" name="op" value="approve">কাগজ ঠিক — মানুন</button>
                        <button class="ma-btn ghost small" name="op" value="reject">মানবেন না</button>
                    </form>
                <?php endif; ?>
            </div>
        <?php endforeach; ?>
    </section>
    <?php
}
