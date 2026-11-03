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
    $tab = in_array($v['tab'], ['home', 'settings', 'ai', 'nlu', 'heirs', 'payments', 'notices', 'feedback', 'finance', 'errors', 'security'], true) ? $v['tab'] : 'members';
    $fb_new = (int) ($v['fb_new'] ?? 0);
    $pending = (int) ($v['pending'] ?? 0);
    $paying_rate = $s['total'] ? round($s['pro'] * 100 / $s['total'], 1) : 0;
    ?>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Hind+Siliguri:wght@400;500;600;700&display=swap">
    <?php ma_acc_styles(); ma_ui_styles(); ?>
    <div class="wrap ma">
        <h1 class="screen-reader-text">My Assistant</h1>
        <div class="ma-shell">
        <?php ma_ui_side($v, $tab); ?>
        <main class="ma-main">

        <?php if ($v['msg'] !== '') : ?>
            <div class="ma-toast <?php echo $v['msg_type'] === 'error' ? 'bad' : ''; ?>" role="status"><?php echo esc_html($v['msg']); ?></div>
        <?php endif; ?>

        <?php if ($tab === 'home') {
            ma_acc_render_home($v);
        } elseif ($tab === 'ai' && !empty($v['can_settings'])) {
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

        </main>
        </div>
        <?php ma_ui_confirm_markup(); ?>
    </div>
    <?php
    ma_acc_script();
    ma_ui_script();
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
                            <th>শেষ খুলেছেন</th>
                            <th>দিনে গড় ব্যবহার</th>
                            <th class="hide-s">প্রিমিয়াম · কোথা থেকে</th>
                            <th class="right"><span class="screen-reader-text">কাজ</span></th>
                        </tr>
                    </thead>
                    <tbody>
                    <?php $use = ma_use_summary(array_column($v['rows'], 'id')); foreach ($v['rows'] as $r) :
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
                                        <span class="ma-name-line"><strong><?php echo esc_html($data['name']); ?></strong><span class="ma-pill <?php echo esc_attr($cls); ?>"><?php echo esc_html($label); ?></span></span>
                                        <span><?php echo esc_html($r['email']); ?></span>
                                    </div>
                                </div>
                            </td>
                            <td class="hide-s muted"><?php echo esc_html($data['joined']); ?></td>
                            <td class="muted"><?php if ($st === 'waiting') : ?>—<?php else : ?><span class="ma-strong"><?php echo esc_html(ma_acc_date($r['last_seen']) . ', ' . ma_ui_clock($r['last_seen'])); ?></span><span class="ma-ver"><?php echo esc_html($data['seen'] . ($data['version'] !== '' ? ' · ' . $data['version'] : '')); ?></span><?php endif; ?></td>
                            <td><?php $u = $use[(int) $r['id']] ?? null; if ($u) : ?><span class="ma-strong"><?php echo esc_html(ma_use_words($u['avg'])); ?></span><span class="ma-ver">১৪ দিনে <?php echo esc_html(ma_acc_bn($u['days'])); ?> দিন খুলেছেন</span><?php else : ?><span class="muted">—</span><span class="ma-ver">নতুন অ্যাপে আসবে</span><?php endif; ?></td>
                            <td class="hide-s muted"><?php if (in_array($st, ['pro', 'trial', 'waiting'], true)) : ?><?php echo esc_html($data['until'] . ' পর্যন্ত'); ?><?php if ($data['kind'] !== '—') : ?><span class="ma-ver"><?php echo esc_html($data['kind']); ?></span><?php endif; ?><?php else : ?>—<?php endif; ?></td>
                            <td class="right">
                                <details class="ma-menu">
                                    <summary class="ma-icon" title="আরও" aria-label="আরও: <?php echo esc_attr($data['name']); ?>"><svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><circle cx="12" cy="5" r="1.8" fill="currentColor"/><circle cx="12" cy="12" r="1.8" fill="currentColor"/><circle cx="12" cy="19" r="1.8" fill="currentColor"/></svg></summary>
                                    <div class="ma-menu-list" role="menu">
                                        <button type="button" role="menuitem" data-open="ma-edit" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>"><?php echo ma_ui_icon('plus', 16); ?> <?php echo $data['pro'] ? 'মেয়াদ বাড়ান' : 'প্রিমিয়াম দিন'; ?></button>
                                        <button type="button" role="menuitem" data-open="ma-view" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>"><?php echo ma_ui_icon('users', 16); ?> বিস্তারিত</button>
                                        <button type="button" role="menuitem" data-open="ma-edit" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>"><?php echo ma_ui_icon('edit', 16); ?> নোট লিখুন</button>
                                        <button type="button" role="menuitem" class="danger" data-open="ma-delete" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>"><?php echo ma_ui_icon('x', 16); ?> মুছুন</button>
                                    </div>
                                </details>
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
                        <form method="post" action="<?php echo $post; ?>" data-confirm="এই কথোপকথন আর তার সংযুক্তি মুছে ফেলবেন?"><input type="hidden" name="action" value="ma_fb_set"><input type="hidden" name="id" value="<?php echo (int) $thread; ?>"><input type="hidden" name="status" value="delete"><?php wp_nonce_field('ma_fb_set'); ?><button class="ma-icon danger" type="submit" title="এই কথোপকথন মুছুন" aria-label="এই কথোপকথন মুছুন"><svg viewBox="0 0 24 24" width="15" height="15" aria-hidden="true"><path fill="currentColor" d="M9 3h6a1 1 0 0 1 1 1v1h4a1 1 0 1 1 0 2h-1l-.9 12.1A2 2 0 0 1 16.1 21H7.9a2 2 0 0 1-2-1.9L5 7H4a1 1 0 0 1 0-2h4V4a1 1 0 0 1 1-1Zm-2 4 .9 12h8.2L17 7H7Z"/></svg></button></form>
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
                            <td class="right"><?php if (!$e['auto']) : ?><form method="post" action="<?php echo $post; ?>" data-confirm="মুছে ফেলবেন?"><input type="hidden" name="action" value="ma_fin_delete"><input type="hidden" name="which" value="entry"><input type="hidden" name="id" value="<?php echo (int) $e['id']; ?>"><?php wp_nonce_field('ma_fin_delete'); ?><button class="ma-icon danger" type="submit" title="মুছুন" aria-label="মুছুন"><svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true"><path fill="currentColor" d="M9 3h6a1 1 0 0 1 1 1v1h4a1 1 0 1 1 0 2h-1l-.9 12.1A2 2 0 0 1 16.1 21H7.9a2 2 0 0 1-2-1.9L5 7H4a1 1 0 0 1 0-2h4V4a1 1 0 0 1 1-1Zm-2 4 .9 12h8.2L17 7H7Z"/></svg></button></form><?php endif; ?></td>
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
                            <td class="right"><form method="post" action="<?php echo $post; ?>" data-confirm="মুছে ফেলবেন?"><input type="hidden" name="action" value="ma_fin_delete"><input type="hidden" name="which" value="investor"><input type="hidden" name="id" value="<?php echo (int) $i['id']; ?>"><?php wp_nonce_field('ma_fin_delete'); ?><button class="ma-icon danger" type="submit" title="মুছুন" aria-label="মুছুন"><svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true"><path fill="currentColor" d="M9 3h6a1 1 0 0 1 1 1v1h4a1 1 0 1 1 0 2h-1l-.9 12.1A2 2 0 0 1 16.1 21H7.9a2 2 0 0 1-2-1.9L5 7H4a1 1 0 0 1 0-2h4V4a1 1 0 0 1 1-1Zm-2 4 .9 12h8.2L17 7H7Z"/></svg></button></form></td></tr>
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
                        <form method="post" action="<?php echo $post; ?>" data-confirm="এই অ্যাডমিনের অনুমতি তুলে নেবেন?"><input type="hidden" name="action" value="ma_admin_remove"><input type="hidden" name="id" value="<?php echo (int) $a->ID; ?>"><?php wp_nonce_field('ma_admin_remove'); ?><button class="ma-btn small ghost" type="submit">সরান</button></form>
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
    <?php if (function_exists('ma_play_settings_card')) { ma_play_settings_card(); } ?>
    <?php if (function_exists('ma_admob_settings_card')) { ma_admob_settings_card(); } ?>
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
            <p class="muted">Google অ্যাকাউন্টের নাম, ইমেইল, ছবির লিংক, কবে যোগ দিয়েছেন ও শেষ কবে খুলেছেন, দিনে কত মিনিট অ্যাপ খোলা থাকে (শুধু সময়), অ্যাপের সংস্করণ, ট্রায়াল আর প্রিমিয়াম। এর বেশি কিছু না।</p>
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
            <div class="ma-table-wrap ma-price-wrap"><table class="ma-table">
                <thead><tr><th>মডেল</th><th>ইনপুট</th><th>ক্যাশে লেখা</th><th>ক্যাশ থেকে পড়া</th><th>আউটপুট</th></tr></thead>
                <tbody>
                <?php foreach ($c['prices'] as $model => $p) : $m = esc_attr($model); ?>
                    <tr><td><?php echo esc_html($model); ?></td>
                    <?php foreach (['in', 'cw', 'cr', 'out'] as $k) : ?><td><input type="text" inputmode="decimal" name="price[<?php echo $m; ?>][<?php echo $k; ?>]" value="<?php echo esc_attr((string) ($p[$k] ?? 0)); ?>"></td><?php endforeach; ?></tr>
                <?php endforeach; ?>
                </tbody>
            </table></div>
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
                <div style="display:flex;gap:8px;flex-wrap:wrap">
                    <button type="button" class="ma-btn small" id="ma-review-copy-btn" data-copy="ma-review-copy">সব কপি করুন (<?php echo esc_html(ma_acc_bn((string) count($n['review_all']))); ?>টা)</button>
                    <form method="post" action="<?php echo $post; ?>" data-confirm="পর্যালোচনার সব বার্তা তালিকা থেকে সরাবেন? বার্তাগুলো শেখানোর জন্য থেকে যাবে, শুধু এখানে আর আসবে না।" style="margin:0">
                        <input type="hidden" name="action" value="ma_nlu_review_clear"><?php wp_nonce_field('ma_nlu_review_clear'); ?>
                        <button class="ma-btn ghost small" type="submit">সব মুছুন</button>
                    </form>
                </div>
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
                    <button class="ma-btn ghost small" type="submit" form="ma-review-skip-<?php echo (int) $r['id']; ?>">বাদ দিন</button>
                </div>
            </form>
            <form method="post" action="<?php echo $post; ?>" id="ma-review-skip-<?php echo (int) $r['id']; ?>" hidden>
                <input type="hidden" name="action" value="ma_nlu_review_clear"><?php wp_nonce_field('ma_nlu_review_clear'); ?>
                <input type="hidden" name="sample" value="<?php echo (int) $r['id']; ?>">
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
