<?php
/**
 * The site's admin page, laid out again (owner, 3–4 Nov: "পুরো সার্ভারের
 * ইউআই ইউএক্স ফিক্স কর" — approved design): a grouped side menu instead of
 * 11 tabs in a row, a dashboard that starts with what needs doing, the
 * notifications as one list of what members get (shown as on the phone,
 * changed in a side panel), and payments with approval first.
 */

if (!defined('ABSPATH')) {
    exit;
}

/** Inline stroke icons for the side menu and the pages. */
function ma_ui_icon($name, $size = 18) {
    $p = [
        'home' => '<path d="M3 11l9-7 9 7v9a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
        'users' => '<circle cx="9" cy="8" r="3.5"/><path d="M2.5 20a6.5 6.5 0 0 1 13 0M16 4.5a3.5 3.5 0 0 1 0 7M18 14.5a6 6 0 0 1 3.5 5.5"/>',
        'card' => '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="M3 10h18M7 15h4"/>',
        'chat' => '<path d="M21 12a8 8 0 0 1-11.5 7.2L4 21l1.8-5.5A8 8 0 1 1 21 12z"/>',
        'heir' => '<path d="M12 3l8 4v5c0 5-3.5 8-8 9-4.5-1-8-4-8-9V7z"/><path d="M9 12l2 2 4-4"/>',
        'bell' => '<path d="M6 8a6 6 0 0 1 12 0c0 7 3 8 3 8H3s3-1 3-8M10 20a2 2 0 0 0 4 0"/>',
        'bug' => '<rect x="7" y="7" width="10" height="13" rx="5"/><path d="M12 7V4M4 13h3M17 13h3M5 7l2.5 2M19 7l-2.5 2M5 19l2.5-2M19 19l-2.5-2"/>',
        'ai' => '<path d="M12 3l1.8 4.7L18.5 9.5l-4.7 1.8L12 16l-1.8-4.7L5.5 9.5l4.7-1.8z"/><path d="M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z"/>',
        'chart' => '<path d="M4 20V10M10 20V4M16 20v-7M22 20H2"/>',
        'money' => '<rect x="2.5" y="6" width="19" height="12" rx="2"/><circle cx="12" cy="12" r="2.5"/>',
        'lock' => '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>',
        'gear' => '<circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M2 12h3M19 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/>',
        'check' => '<path d="M5 12l5 5L20 7"/>',
        'x' => '<path d="M6 6l12 12M18 6L6 18"/>',
        'edit' => '<path d="M4 20h4L19 9l-4-4L4 16z"/>',
        'clock' => '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
        'send' => '<path d="M22 2L11 13M22 2l-7 20-4-9-9-4z"/>',
        'plus' => '<path d="M12 5v14M5 12h14"/>',
        'sun' => '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
        'noon' => '<circle cx="12" cy="12" r="5"/><path d="M12 1v3M1 12h3M20 12h3"/>',
        'moon' => '<path d="M21 12.8A9 9 0 1 1 11.2 3a7 7 0 0 0 9.8 9.8z"/>',
        'zap' => '<path d="M13 2L4 14h7l-1 8 9-12h-7z"/>',
        'warn' => '<path d="M12 3l10 18H2z"/><path d="M12 10v4M12 17.5v.5"/>',
        'link' => '<path d="M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1"/>',
        'phone' => '<rect x="7" y="2" width="10" height="20" rx="2"/><path d="M11 18h2"/>',
        'mic' => '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0M12 18v3"/>',
        'search' => '<circle cx="11" cy="11" r="7"/><path d="M20 20l-4-4"/>',
    ][$name] ?? '';
    return '<svg width="' . (int) $size . '" height="' . (int) $size . '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' . $p . '</svg>';
}

/** The side menu, grouped (members' things, the app, AI, money, the site). */
function ma_ui_side($v, $tab) {
    $pending = (int) ($v['pending'] ?? 0);
    $fb_new = (int) ($v['fb_new'] ?? 0);
    $heirs = (int) ($v['heirs_pending'] ?? 0);
    $errs = (int) ($v['err_day'] ?? 0);
    $owner = !empty($v['can_settings']);
    $sec_warn = function_exists('ma_admin_app_otp') && ma_admin_app_otp() && !ma_totp_on(get_current_user_id());
    $groups = [
        '' => [['home', 'home', 'ড্যাশবোর্ড', 0, '']],
        'সদস্য' => [['members', 'users', 'সদস্য', 0, ''], ['payments', 'card', 'পেমেন্ট', $pending, 'n'], ['feedback', 'chat', 'মতামত', $fb_new, 'n'], ['heirs', 'heir', 'উত্তরাধিকার', $heirs, 'n']],
        'অ্যাপ' => [['notices', 'bell', 'নোটিফিকেশন', 0, ''], ['errors', 'bug', 'সমস্যার লগ', $errs, 'w']],
        'AI' => array_values(array_filter([['nlu', 'ai', 'ফোনের মডেল', 0, ''], $owner ? ['ai', 'chart', 'AI খরচ', 0, ''] : null])),
        'ব্যবসা' => $owner ? [['finance', 'money', 'আয়-ব্যয়ের হিসাব', 0, '']] : [],
        'সাইট' => array_values(array_filter([['security', 'lock', 'নিরাপত্তা', $sec_warn ? '!' : 0, 'w'], $owner ? ['settings', 'gear', 'সেটিংস', 0, ''] : null])),
    ];
    ?>
    <aside class="ma-side" aria-label="বিভাগ">
        <div class="ma-side-brand">
            <span class="ma-side-logo"><?php echo ma_ui_icon('mic', 19); ?></span>
            <div><div class="ma-side-name">My Assistant</div><div class="ma-side-sub">অ্যাডমিন · getmyassistant.app</div></div>
        </div>
        <nav class="ma-tabs">
            <?php foreach ($groups as $g => $items) : if (!$items) { continue; } ?>
                <?php if ($g !== '') : ?><div class="ma-side-grp"><?php echo esc_html($g); ?></div><?php endif; ?>
                <?php foreach ($items as [$key, $ic, $label, $badge, $kind]) : ?>
                    <a class="<?php echo $tab === $key ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => $key]); ?>"<?php echo $tab === $key ? ' aria-current="page"' : ''; ?>>
                        <?php echo ma_ui_icon($ic); ?><span><?php echo esc_html($label); ?></span>
                        <?php if ($badge) : ?><i class="ma-badge <?php echo $kind === 'w' ? 'warn' : ''; ?>"><?php echo esc_html(is_int($badge) ? ma_acc_bn($badge) : $badge); ?></i><?php endif; ?>
                    </a>
                <?php endforeach; ?>
            <?php endforeach; ?>
        </nav>
        <p class="ma-side-foot">সদস্যের হিসাব, নোট, পাসওয়ার্ড এই সার্ভারে আসে না।</p>
    </aside>
    <?php
}

/** A page's own title line. */
function ma_ui_head($title, $sub, $actions = '') {
    ?>
    <div class="ma-head">
        <div><h1 class="ma-h1"><?php echo esc_html($title); ?></h1><?php if ($sub !== '') : ?><p class="ma-sub"><?php echo esc_html($sub); ?></p><?php endif; ?></div>
        <?php if ($actions !== '') : ?><div class="ma-head-actions"><?php echo $actions; // built here from escaped parts ?></div><?php endif; ?>
    </div>
    <?php
}

// ── ড্যাশবোর্ড ──

function ma_ui_greeting() {
    $h = (int) gmdate('G', time() + ma_acc_tz_off());
    return $h < 5 ? 'শুভ রাত্রি' : ($h < 12 ? 'শুভ সকাল' : ($h < 17 ? 'শুভ দুপুর' : ($h < 20 ? 'শুভ সন্ধ্যা' : 'শুভ রাত্রি')));
}

function ma_acc_render_home($v) {
    $s = $v['stats'];
    $h = $v['home'] ?? [];
    $u = wp_get_current_user();
    $name = $u && $u->display_name !== '' ? $u->display_name : '';
    $todo = [];
    if (!empty($v['pending'])) {
        $m = (int) ($h['pay_matched'] ?? 0);
        $todo[] = ['card', 'bad', ma_acc_bn($v['pending']) . 'টা পেমেন্ট অনুমোদনের অপেক্ষায়', $m ? ma_acc_bn($m) . 'টা বিকাশে মিলেছে' : 'বিকাশে মিলিয়ে অনুমোদন দিন', 'payments', 'দেখুন'];
    }
    if (!empty($v['fb_new'])) {
        $todo[] = ['chat', 'blue', ma_acc_bn($v['fb_new']) . 'টা নতুন মতামত', (string) ($h['fb_last'] ?? 'সদস্যরা অ্যাপ থেকে লিখেছেন'), 'feedback', 'উত্তর দিন'];
    }
    if (!empty($v['heirs_pending'])) {
        $todo[] = ['heir', 'warn', ma_acc_bn($v['heirs_pending']) . 'টা উত্তরাধিকার দাবি যাচাই বাকি', 'সনদ দেখে সিদ্ধান্ত দিন', 'heirs', 'যাচাই'];
    }
    if (!empty($v['err_day'])) {
        $todo[] = ['bug', 'warn', 'গত ২৪ ঘণ্টায় ' . ma_acc_bn($v['err_day']) . 'টা সমস্যা', 'ক্র্যাশ আর সমস্যা — কোনটা কত বার', 'errors', 'লগ'];
    }
    if (function_exists('ma_admin_app_otp') && ma_admin_app_otp() && !ma_totp_on(get_current_user_id())) {
        $todo[] = ['lock', 'warn', 'আপনার অ্যাকাউন্টে দুই ধাপের লগইন চালু নেই', 'অ্যাডমিন অ্যাপে ঢুকতে লাগবে — ২ মিনিটের কাজ', 'security', 'চালু করুন'];
    }
    $rate = $s['total'] ? round($s['pro'] * 100 / $s['total']) : 0;
    $g = $v['growth'] ?? null;
    ma_ui_head(trim(ma_ui_greeting() . ($name !== '' ? ', ' . $name : '')), 'আজ যা দেখা দরকার আগে, তারপর সংখ্যা', '<a class="ma-btn ghost" href="' . ma_acc_url(['tab' => 'notices', 'send' => 1]) . '">' . ma_ui_icon('send', 16) . ' সবাইকে নোটিফিকেশন পাঠান</a>');
    ?>
    <section class="ma-card">
        <div class="ma-bar"><div class="ma-bar-title"><h2>আপনার কাজ বাকি</h2><span class="ma-count"><?php echo esc_html(ma_acc_bn(count($todo))); ?>টা</span></div></div>
        <?php if (!$todo) : ?>
            <div class="ma-todo-none"><?php echo ma_ui_icon('check', 20); ?> সব কাজ শেষ — দেখার মতো কিছু বাকি নেই।</div>
        <?php else : ?>
            <div class="ma-todo">
                <?php foreach ($todo as [$ic, $tone, $title, $sub, $tab, $btn]) : ?>
                    <a class="ma-todo-row" href="<?php echo ma_acc_url(['tab' => $tab]); ?>">
                        <span class="ma-tile <?php echo esc_attr($tone); ?>"><?php echo ma_ui_icon($ic); ?></span>
                        <span class="ma-todo-text"><strong><?php echo esc_html($title); ?></strong><span><?php echo esc_html($sub); ?></span></span>
                        <span class="ma-btn ghost small"><?php echo esc_html($btn); ?></span>
                    </a>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </section>
    <div class="ma-stats">
        <div><span>মোট সদস্য</span><strong><?php echo esc_html(ma_acc_bn(number_format($s['total']))); ?></strong><em>এ মাসে নতুন <?php echo esc_html(ma_acc_bn($s['month_new'] ?? 0)); ?> · আজ <?php echo esc_html(ma_acc_bn($s['today_new'] ?? 0)); ?></em></div>
        <div><span>প্রিমিয়াম</span><strong class="g"><?php echo esc_html(ma_acc_bn(number_format($s['pro']))); ?></strong><em><?php echo esc_html(ma_acc_bn($rate)); ?>% সদস্য</em></div>
        <div><span>সক্রিয় (৭ দিনে)</span><strong><?php echo esc_html(ma_acc_bn(number_format($s['active']))); ?></strong><em>গত ৭ দিনে অ্যাপ খুলেছেন</em></div>
        <div><span>এ মাসের আয় (ওয়েবসাইট)</span><strong>৳<?php echo esc_html(ma_acc_bn(number_format((int) ($h['pay_month'] ?? 0)))); ?></strong><em>অনুমোদিত পেমেন্ট</em></div>
    </div>
    <div class="ma-two">
        <section class="ma-card">
            <div class="ma-bar"><div class="ma-bar-title"><h2>নতুন সদস্য, গত ৩০ দিন</h2></div><a class="ma-btn ghost small" href="<?php echo ma_acc_url(['tab' => 'members']); ?>">সদস্য দেখুন</a></div>
            <?php if ($g) : $mx = max(1, max(array_column($g['days'], 'n'))); ?>
                <div class="ma-growth">
                    <?php foreach ($g['days'] as $d) : $hh = $d['n'] ? max(6, round($d['n'] / $mx * 100)) : 2; ?>
                        <a class="ma-gbar" href="<?php echo ma_acc_url(['joined' => $d['day']]); ?>#ma-list" title="<?php echo esc_attr(ma_acc_date($d['day'] . ' 06:00:00') . ': ' . ma_acc_bn($d['n']) . ' জন'); ?>"><i style="height:<?php echo (int) $hh; ?>%"></i><b><?php echo $d['n'] ? esc_html(ma_acc_bn($d['n'])) : ''; ?></b><span><?php echo esc_html(ma_acc_bn((int) substr($d['day'], 8, 2))); ?></span></a>
                    <?php endforeach; ?>
                </div>
            <?php endif; ?>
            <div style="height:16px"></div>
        </section>
        <section class="ma-card pad">
            <h2>আজ সদস্যদের ফোনে</h2>
            <div class="ma-mini">
                <div><strong><?php echo esc_html(ma_acc_bn((int) ($h['notes_total'] ?? 0))); ?></strong><span>নোটিফিকেশন গেছে</span></div>
                <div><strong><?php echo esc_html(ma_acc_bn((int) ($h['notes_people'] ?? 0))); ?></strong><span>জনের কাছে</span></div>
            </div>
            <p class="muted" style="margin:12px 0 0">কোনটা কখন যায়, কী লেখা — <a href="<?php echo ma_acc_url(['tab' => 'notices']); ?>">নোটিফিকেশন</a>-এ দেখে বদলান।</p>
        </section>
    </div>
    <?php
}

// ── নোটিফিকেশন ──

/** The phone's own words ({name} …) shown as plain Bangla chips in the editor, and back. */
function ma_ui_note_words() {
    return ['{name}' => '[নাম]', '{title}' => '[অ্যাপের শিরোনাম]', '{body}' => '[অ্যাপের লেখা]'];
}

function ma_ui_note_to_bn($s) {
    return strtr((string) $s, ma_ui_note_words());
}

function ma_ui_note_from_bn($s) {
    return strtr((string) $s, array_flip(ma_ui_note_words()));
}

/** A rule's text filled with a sample, as the phone would show it. */
function ma_ui_note_fill($tpl, $title, $body) {
    return trim(strtr((string) $tpl, ['{name}' => 'রাকিব', '{title}' => $title, '{body}' => $body]));
}

function ma_ui_note_part($at) {
    if ($at === '') {
        return 'none';
    }
    $h = (int) substr($at, 0, 2);
    return $h < 12 ? 'morning' : ($h < 18 ? 'day' : 'night');
}

function ma_acc_render_notices($v) {
    $nv = sanitize_key((string) ($_GET['nv'] ?? 'list'));
    $nv = in_array($nv, ['list', 'mine', 'stats'], true) ? $nv : 'list';
    $rv = ma_note_rules_view();
    $post = esc_url(admin_url('admin-post.php'));
    $groups = $rv['groups'];
    $count = [];
    foreach ($rv['kinds'] as $k) {
        $count[$k['group']] = ($count[$k['group']] ?? 0) + 1;
    }
    $off = count(array_filter($rv['kinds'], fn($k) => !$k['on']));
    $mine = $v['notices'] ?? [];
    $actions = '<button class="ma-btn ghost" type="button" data-open="ma-send">' . ma_ui_icon('send', 16) . ' এখনই পাঠান</button>'
        . '<button class="ma-btn" type="button" data-open="ma-note" data-m="' . esc_attr(wp_json_encode(['id' => '', 'title' => '', 'body' => '', 'kind' => 'daily', 'at_time' => '21:00', 'weekday' => 5, 'audience' => 'all', 'cond' => '', 'mic' => true, 'on_date' => '', 'start_date' => '', 'end_date' => ''])) . '">' . ma_ui_icon('plus', 16) . ' নতুন নোটিফিকেশন</button>';
    ma_ui_head('নোটিফিকেশন', 'সদস্যরা ফোনে কী কী পান, কখন, কী লেখা — এখান থেকেই বদলান', $actions);
    ?>
    <nav class="ma-subtabs" aria-label="নোটিফিকেশনের ভাগ">
        <a class="<?php echo $nv === 'list' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'notices']); ?>">সদস্যরা যা পান · <?php echo esc_html(ma_acc_bn(count($rv['kinds']))); ?></a>
        <a class="<?php echo $nv === 'mine' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'notices', 'nv' => 'mine']); ?>">আপনার বানানো · <?php echo esc_html(ma_acc_bn(count($mine))); ?></a>
        <a class="<?php echo $nv === 'stats' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'notices', 'nv' => 'stats']); ?>">পাঠানোর হিসাব</a>
    </nav>
    <?php if ($nv === 'list') :
        $parts = ['morning' => ['sun', 'সকাল'], 'day' => ['noon', 'দুপুর ও বিকাল'], 'night' => ['moon', 'সন্ধ্যা ও রাত'], 'none' => ['zap', 'নির্দিষ্ট সময় নেই — কিছু ঘটলে বা সদস্য চালু করলে']];
        $by = [];
        foreach ($rv['kinds'] as $k) {
            $at = $k['at'] !== '' ? $k['at'] : $k['default_at'];
            $k['_at'] = $at;
            $by[ma_ui_note_part($at)][] = $k;
        }
        foreach ($by as &$list) {
            usort($list, fn($a, $b) => strcmp($a['_at'], $b['_at']));
        }
        unset($list);
        $cap = $rv['cap'];
        ?>
        <div class="ma-filter">
            <div class="ma-chips" role="group" aria-label="কত ঘন ঘন">
                <button type="button" class="ma-chip on" data-nf="">সব</button>
                <?php foreach ($groups as $gk => $gl) : if (empty($count[$gk])) { continue; } ?>
                    <button type="button" class="ma-chip" data-nf="<?php echo esc_attr($gk); ?>"><?php echo esc_html($gl); ?> · <?php echo esc_html(ma_acc_bn($count[$gk])); ?></button>
                <?php endforeach; ?>
                <?php if ($off) : ?><button type="button" class="ma-chip" data-nf="off">বন্ধ · <?php echo esc_html(ma_acc_bn($off)); ?></button><?php endif; ?>
            </div>
        </div>
        <div class="ma-note-rules">
            <?php echo ma_ui_icon('clock', 17); ?>
            <span><strong>দিন শুরু সুপ্রভাত দিয়ে (সকাল ৮টা)</strong> · <strong>দুটোর মাঝে অন্তত ৩০ মিনিট</strong> — একই সময়ে কয়েকটা পড়লে বেশি দরকারিটা আগে, বাকিগুলো ৩০ মিনিট পর পর · <strong>দিনে সর্বোচ্চ <?php echo esc_html(ma_acc_bn($cap !== null ? $cap : 3)); ?>টা</strong> (সূচি, সারাংশ আর অর্থ-কথা বাদে) · <strong>চুপ থাকার সময়</strong> রাত ১০টা – সকাল ৭টা, এর মধ্যেরগুলো সুপ্রভাতের পরে যায় · সদস্য নিজে কোনোটা বন্ধ করলে সেটা বন্ধই থাকে</span>
            <button type="button" class="ma-btn ghost small" data-open="ma-cap">বদলান</button>
        </div>
        <section class="ma-card ma-nlist">
            <div class="ma-nhead"><span class="t">সময়</span><span class="p">ফোনে যেমন দেখায়</span><span class="w">কবে · কারা</span><span class="c">আজ গেছে</span><span class="o">চালু</span><span class="e"></span></div>
            <?php foreach ($parts as $pk => [$ic, $pl]) : if (empty($by[$pk])) { continue; } ?>
                <div class="ma-npart"><?php echo ma_ui_icon($ic, 16); ?> <?php echo esc_html($pl); ?></div>
                <?php foreach ($by[$pk] as $k) :
                    $title = $k['title'] !== '' ? ma_ui_note_fill($k['title'], $k['sample'], $k['sample_body']) : $k['sample'];
                    $body = $k['body'] !== '' ? ma_ui_note_fill($k['body'], $k['sample'], $k['sample_body']) : $k['sample_body'];
                    $data = [
                        'key' => $k['key'], 'label' => $k['label'], 'when' => $k['when'], 'on' => $k['on'], 'at' => $k['at'], 'default_at' => $k['default_at'],
                        'title' => ma_ui_note_to_bn($k['title']), 'body' => ma_ui_note_to_bn($k['body']), 'sample' => $k['sample'], 'sample_body' => $k['sample_body'],
                        'who' => $k['who'], 'wd' => (int) $k['wd'], 'wd_editable' => $k['wd_editable'], 'wd_default' => (int) $k['wd_default'], 'today' => (int) $k['today'],
                    ];
                    ?>
                    <div class="ma-nrow <?php echo $k['on'] ? '' : 'off'; ?>" data-g="<?php echo esc_attr($k['group']); ?>" data-on="<?php echo $k['on'] ? '1' : '0'; ?>">
                        <span class="t"><?php echo esc_html($k['_at'] !== '' ? ma_acc_bn($k['_at']) : '—'); ?></span>
                        <span class="p">
                            <span class="ma-phone">
                                <span class="ma-phone-app"><i></i>My Assistant · <?php echo esc_html($k['label']); ?><?php if ($k['changed'] && $k['on']) : ?> <b class="ma-tag">বদলানো</b><?php endif; ?><?php if (!$k['cap']) : ?> <b class="ma-tag">সীমার বাইরে</b><?php endif; ?></span>
                                <strong><?php echo esc_html($title); ?></strong>
                                <?php if ($body !== '') : ?><span><?php echo esc_html($body); ?></span><?php endif; ?>
                            </span>
                        </span>
                        <span class="w"><strong><?php echo esc_html($k['schedule']); ?></strong><span><?php echo esc_html($rv['who'][$k['who']] ?? 'সবাই'); ?><?php echo $k['off_by_default'] ? ' · সদস্য চালু করলে' : ''; ?></span></span>
                        <span class="c"><?php echo $k['today'] ? '<strong>' . esc_html(ma_acc_bn($k['today'])) . '</strong>' : '<span class="muted">—</span>'; ?></span>
                        <span class="o">
                            <form method="post" action="<?php echo $post; ?>" class="ma-inline-form">
                                <input type="hidden" name="action" value="ma_note_rule_one"><input type="hidden" name="key" value="<?php echo esc_attr($k['key']); ?>"><input type="hidden" name="op" value="toggle">
                                <?php wp_nonce_field('ma_note_rule_one'); ?>
                                <button type="submit" class="ma-toggle <?php echo $k['on'] ? 'on' : ''; ?>" role="switch" aria-checked="<?php echo $k['on'] ? 'true' : 'false'; ?>" aria-label="<?php echo esc_attr($k['label'] . ' — ' . ($k['on'] ? 'বন্ধ করুন' : 'চালু করুন')); ?>"></button>
                            </form>
                        </span>
                        <span class="e"><button type="button" class="ma-btn ghost small" data-note-edit="<?php echo esc_attr(wp_json_encode($data)); ?>"><?php echo ma_ui_icon('edit', 14); ?> বদলান</button></span>
                    </div>
                <?php endforeach; ?>
            <?php endforeach; ?>
            <div class="ma-npart"><?php echo ma_ui_icon('users', 16); ?> সদস্যের নিজের রিমাইন্ডার</div>
            <p class="muted ma-pad" style="padding-top:8px">সদস্য নিজে যা রাখেন, সেগুলো অ্যাপ নিজে পাঠায় না — লেখা ফোনেই থাকে; এখানে বদলানোর কিছু নেই। কতগুলো গেছে: <a href="<?php echo ma_acc_url(['tab' => 'notices', 'nv' => 'stats']); ?>">পাঠানোর হিসাব</a>।</p>
        </section>

        <dialog class="ma-drawer" id="ma-note-edit" aria-labelledby="ma-ne-title">
            <form method="post" action="<?php echo $post; ?>">
                <input type="hidden" name="action" value="ma_note_rule_one"><input type="hidden" name="op" value="save"><input type="hidden" name="key" data-ne="key">
                <?php wp_nonce_field('ma_note_rule_one'); ?>
                <div class="ma-drawer-head">
                    <div><h3 id="ma-ne-title" data-ne-text="label"></h3><p class="muted" data-ne-text="when"></p></div>
                    <label class="ma-switch" style="margin:0!important"><input type="checkbox" name="on" value="1" data-ne="on"><span class="ma-switch-ui"></span><span class="screen-reader-text">চালু</span></label>
                    <button type="button" class="ma-icon" data-close aria-label="বন্ধ করুন"><?php echo ma_ui_icon('x', 20); ?></button>
                </div>
                <div class="ma-drawer-body">
                    <div class="ma-preview">
                        <div class="ma-preview-k">সদস্যের ফোনে যেমন দেখাবে</div>
                        <div class="ma-phone big"><span class="ma-phone-app"><i></i>My Assistant · এখন</span><strong data-ne-pv="title"></strong><span data-ne-pv="body"></span></div>
                    </div>
                    <label>শিরোনাম<input type="text" name="title" data-ne="title" maxlength="80" autocomplete="off"></label>
                    <div class="ma-words"><span class="muted">যোগ করুন:</span>
                        <button type="button" class="ma-chip" data-ne-add="title" data-w="[নাম]">+ সদস্যের নাম</button>
                        <button type="button" class="ma-chip" data-ne-add="title" data-w="[অ্যাপের শিরোনাম]">+ অ্যাপের শিরোনাম</button>
                    </div>
                    <label>লেখা<textarea name="body" data-ne="body" maxlength="240" rows="3"></textarea></label>
                    <div class="ma-words"><span class="muted">যোগ করুন:</span>
                        <button type="button" class="ma-chip" data-ne-add="body" data-w="[নাম]">+ সদস্যের নাম</button>
                        <button type="button" class="ma-chip" data-ne-add="body" data-w="[অ্যাপের লেখা]">+ অ্যাপের লেখা</button>
                    </div>
                    <p class="ma-warn" data-ne-bad hidden></p>
                    <details class="ma-guide" open>
                        <summary>[ ] দিয়ে কীভাবে লিখবেন</summary>
                        <p>শিরোনাম বা লেখা খালি রাখলে অ্যাপের নিজেরটা যায়। নিজে লিখলে এই তিনটা [ ] শব্দ প্রতিটা সদস্যের ফোনে আসল জিনিসে বদলে যায় — ওপরের বোতাম চাপলেই বসে:</p>
                        <dl>
                            <dt>[নাম]</dt><dd>সদস্যের নাম, যেমন “রাকিব”। নাম জানা না থাকলে [নাম] আর তার পরের কমা বাদ যায় — তাই বাকিটা এমনভাবে লিখুন যেন নাম ছাড়াও পড়া যায়।</dd>
                            <dt>[অ্যাপের শিরোনাম]</dt><dd>এই নোটিফিকেশনে অ্যাপ নিজে যে শিরোনাম দিত — এখানে: “<span data-ne-text="sample"></span>”।</dd>
                            <dt>[অ্যাপের লেখা]</dt><dd>অ্যাপের বিস্তারিত — দিন অনুযায়ী বদলানো জিনিস (সূচি, কার কাছে কত, কয়টা কাজ)। এখানে: “<span data-ne-text="sample_body"></span>”। লেখা বদলালেও এটা রাখুন, নইলে সদস্য আসল তথ্য পাবেন না।</dd>
                        </dl>
                        <p><strong>উদাহরণ:</strong> শিরোনাম “[নাম], [অ্যাপের শিরোনাম]” → “রাকিব, <span data-ne-text="sample"></span>”।</p>
                        <ul>
                            <li>শুধু এই তিনটা [ ] কাজ করে; অন্য কিছু [ ]-এর ভেতরে লিখলে হুবহু চলে যাবে।</li>
                            <li>শিরোনাম ৮০, লেখা ২৪০ অক্ষরের মধ্যে — ছোট আর পরিষ্কার রাখুন।</li>
                            <li>লক স্ক্রিনে দেখা যায়: টাকার অঙ্ক, ওষুধ বা রোগের নাম শিরোনামে না রাখাই ভালো।</li>
                            <li>অন্য নোটিফিকেশনের ৩০ মিনিটের মধ্যে সময় দিলে ফোন এটাকে একটু পরে সরিয়ে দেবে।</li>
                        </ul>
                    </details>
                    <div class="ma-ai-row two">
                        <label>সময়<input type="time" name="at" data-ne="at"><span class="ma-ver" data-ne-text="at_hint"></span></label>
                        <label data-ne-wd>কোন দিন<select name="wd" data-ne="wd"><option value="0" data-ne-wd0>অ্যাপের দিন</option><?php foreach ($rv['weekdays'] as $wn => $wl) : ?><option value="<?php echo (int) $wn; ?>"><?php echo esc_html($wl); ?></option><?php endforeach; ?></select></label>
                    </div>
                    <fieldset class="ma-days"><legend>কারা পাবেন</legend>
                        <?php foreach ($rv['who'] as $wk => $wl) : ?>
                            <label><input type="radio" name="who" value="<?php echo esc_attr($wk); ?>" data-ne-who><span><?php echo esc_html(preg_replace('/\s*\(.*\)$/u', '', $wl)); ?></span></label>
                        <?php endforeach; ?>
                    </fieldset>
                    <p class="muted ma-small">“কারা পাবেন” প্রতিটা ফোন নিজেই ঠিক করে — সদস্য কতদিন ধরে আছেন, কত খোলেন; সেই তথ্য ফোনের বাইরে যায় না। শর্ত (যেমন “কাজ বাকি থাকলে”) অ্যাপের নিজের।</p>
                    <div class="ma-sent"><?php echo ma_ui_icon('phone', 16); ?> <span>আজ <b data-ne-text="today"></b>টা গেছে</span></div>
                </div>
                <div class="ma-drawer-foot">
                    <button type="submit" name="op" value="reset" class="ma-btn ghost small" formnovalidate data-confirm="অ্যাপের নিজের সময় আর লেখায় ফেরাবেন?" data-yes="হ্যাঁ, ফেরান">আগের মতো করুন</button>
                    <span style="flex:1"></span>
                    <button type="button" class="ma-btn ghost" data-close>বাতিল</button>
                    <button type="submit" class="ma-btn">রাখুন</button>
                </div>
            </form>
        </dialog>

        <dialog class="ma-dialog narrow" id="ma-cap">
            <form method="post" action="<?php echo $post; ?>">
                <input type="hidden" name="action" value="ma_note_rule_one"><input type="hidden" name="op" value="cap"><?php wp_nonce_field('ma_note_rule_one'); ?>
                <h3>দিনে সর্বোচ্চ কয়টা</h3>
                <p class="muted">মনে করানো ধরনের নোটিফিকেশন (সূচি, রাতের সারাংশ আর অর্থ-কথা বাদে) একজন সদস্য দিনে এর বেশি পাবেন না। খালি রাখলে অ্যাপের নিজের: ৩টা।</p>
                <label>দিনে সর্বোচ্চ<input type="number" name="cap" min="0" max="10" value="<?php echo esc_attr($cap ?? ''); ?>" placeholder="৩"></label>
                <div class="ma-dialog-actions"><button type="button" class="ma-btn ghost" data-close>বাতিল</button><button class="ma-btn" type="submit">রাখুন</button></div>
            </form>
        </dialog>
    <?php elseif ($nv === 'mine') : ma_ui_render_mine($v, $post);
    else : ma_ui_render_note_stats($v);
    endif; ?>

    <dialog class="ma-dialog" id="ma-send">
        <form method="post" action="<?php echo $post; ?>">
            <input type="hidden" name="action" value="ma_push_now"><?php wp_nonce_field('ma_push_now'); ?>
            <h3>এখনই পাঠান</h3>
            <p class="muted">সাথে সাথে সদস্যদের ফোনে পুশ যাবে (অ্যাপ বন্ধ থাকলেও)।</p>
            <label>শিরোনাম<input type="text" name="title" maxlength="120" required></label>
            <label>লেখা<input type="text" name="body" maxlength="400"></label>
            <label>কাকে<select name="audience"><?php foreach (ma_note_options()['audience'] as $k => $l) : ?><option value="<?php echo esc_attr($k); ?>"><?php echo esc_html($l); ?></option><?php endforeach; ?></select></label>
            <div class="ma-dialog-actions"><button type="button" class="ma-btn ghost" data-close>বাতিল</button><button class="ma-btn" type="submit" data-confirm="এখনই পাঠাবেন?"><?php echo ma_ui_icon('send', 15); ?> পাঠান</button></div>
        </form>
    </dialog>
    <?php ma_ui_note_dialog($post); ?>
    <?php if (!empty($_GET['send'])) : ?><script>document.addEventListener('DOMContentLoaded',function(){var d=document.getElementById('ma-send');if(d&&d.showModal){d.showModal();}});</script><?php endif; ?>
    <?php
}

/** "আপনার বানানো": notifications the admin wrote (the server sends them). */
function ma_ui_render_mine($v, $post) {
    $o = ma_note_options();
    $mine = $v['notices'] ?? [];
    ?>
    <section class="ma-card">
        <p class="muted ma-pad" style="padding-top:16px">শর্ত ছাড়া নোটিফিকেশন সার্ভার নিজে ঠিক সময়ে পুশ করে (অ্যাপ বন্ধ থাকলেও যায়)। শর্ত দিলে ফোন নিজে দেখে দেখায় — সদস্যের “চুপ থাকার সময়” আর দিনের সীমা মেনে।</p>
        <?php if (!$mine) : ?>
            <div class="ma-empty">
                <div class="ma-empty-art" aria-hidden="true"><?php echo ma_ui_icon('bell', 30); ?></div>
                <h3>এখনো কোনো নোটিফিকেশন নেই</h3>
                <p>যেমন: প্রতিদিন রাত ৯টায় “আজকের কাজের লিস্ট করেছেন?” — শুধু যাঁরা সেদিন তালিকা করেননি, তাঁদের।</p>
            </div>
        <?php else : ?>
            <div class="ma-nlist">
                <?php foreach ($mine as $n) :
                    $when = $n['kind'] === 'once' ? ma_acc_date($n['on_date'] . ' 00:00:00') : ($n['kind'] === 'weekly' ? 'প্রতি ' . $o['weekday'][(int) $n['weekday']] : 'প্রতিদিন');
                    $run = $v['note_overview']['runs'][(int) $n['id']] ?? null;
                    ?>
                    <div class="ma-nrow <?php echo $n['active'] ? '' : 'off'; ?>">
                        <span class="t"><?php echo esc_html(ma_acc_bn($n['at_time'])); ?></span>
                        <span class="p"><span class="ma-phone"><span class="ma-phone-app"><i></i>My Assistant</span><strong><?php echo esc_html($n['title']); ?></strong><?php if ($n['body'] !== '') : ?><span><?php echo esc_html($n['body']); ?></span><?php endif; ?></span></span>
                        <span class="w"><strong><?php echo esc_html($when); ?></strong><span><?php echo esc_html($o['audience'][$n['audience']] ?? 'সবাই'); ?><?php echo $n['cond'] !== '' ? ' · ' . esc_html($o['cond'][$n['cond']] ?? '') : ''; ?><?php echo $n['end_date'] ? ' · শেষ ' . esc_html(ma_acc_date($n['end_date'] . ' 00:00:00')) : ''; ?></span></span>
                        <span class="c"><?php if ($run) : ?><strong><?php echo esc_html(ma_acc_bn($run['sent'])); ?></strong><span class="ma-ver"><?php echo esc_html(ma_acc_bn($run['times'])); ?> বার<?php echo $run['failed'] ? ' · ' . esc_html(ma_acc_bn($run['failed'])) . ' পৌঁছায়নি' : ''; ?></span><?php else : ?><span class="muted">—</span><?php endif; ?></span>
                        <span class="o">
                            <form method="post" action="<?php echo $post; ?>" class="ma-inline-form"><input type="hidden" name="action" value="ma_note_toggle"><input type="hidden" name="id" value="<?php echo (int) $n['id']; ?>"><?php wp_nonce_field('ma_note_toggle'); ?>
                                <button type="submit" class="ma-toggle <?php echo $n['active'] ? 'on' : ''; ?>" role="switch" aria-checked="<?php echo $n['active'] ? 'true' : 'false'; ?>" aria-label="<?php echo $n['active'] ? 'বন্ধ করুন' : 'চালু করুন'; ?>"></button></form>
                        </span>
                        <span class="e">
                            <button type="button" class="ma-icon" title="বদলান" aria-label="বদলান" data-open="ma-note" data-m="<?php echo esc_attr(wp_json_encode($n + ['mic' => (bool) $n['mic']])); ?>"><?php echo ma_ui_icon('edit', 17); ?></button>
                            <form method="post" action="<?php echo $post; ?>" class="ma-inline-form" data-confirm="মুছে ফেলবেন?"><input type="hidden" name="action" value="ma_note_toggle"><input type="hidden" name="delete" value="1"><input type="hidden" name="id" value="<?php echo (int) $n['id']; ?>"><?php wp_nonce_field('ma_note_toggle'); ?><button class="ma-icon danger" type="submit" title="মুছুন" aria-label="মুছুন"><?php echo ma_ui_icon('x', 17); ?></button></form>
                        </span>
                    </div>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </section>
    <?php
}

/** The admin's own notification form (new or change). */
function ma_ui_note_dialog($post) {
    $o = ma_note_options();
    ?>
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

/** "পাঠানোর হিসাব": today and tomorrow, one day's list with counts, the last 14 days. */
function ma_ui_render_note_stats($v) {
    $ov = $v['note_overview'] ?? null;
    $nd = $v['note_day'] ?? null;
    if ($ov) :
        $two = gmdate('Y-m-d', time() + ma_acc_tz_off() + DAY_IN_SECONDS);
        $ov['upcoming'] = array_values(array_filter($ov['upcoming'], fn($u) => $u['day'] <= $two)); ?>
    <section class="ma-card" id="ma-next">
        <div class="ma-bar"><div class="ma-bar-title"><h2>আজ আর কাল কী যাবে</h2><span class="ma-count"><?php echo esc_html(ma_acc_bn(count($ov['upcoming']))); ?>টি · আপনার বানানো</span></div></div>
        <p class="muted ma-pad">
            <?php if ($ov['push_on']) : ?>
                পুশ পাচ্ছে <?php echo esc_html(ma_acc_bn($ov['phones'])); ?>টি ফোন, তার মধ্যে নতুন অ্যাপে <?php echo esc_html(ma_acc_bn($ov['phones_new_app'])); ?>টি; পুরোনো অ্যাপ নিজে খোলার পর তালিকা নিয়ে দেখায়।
            <?php else : ?>
                <strong>Firebase বসানো নেই</strong> — সার্ভার পুশ করতে পারছে না; ফোন অ্যাপ খোলার পর তালিকা নিয়ে দেখায়। সেটিংস › পুশ নোটিফিকেশনে Firebase বসান।
            <?php endif; ?>
        </p>
        <?php if (!$ov['upcoming']) : ?>
            <div class="ma-empty"><h3>আজ-কাল কিছু নেই</h3><p>আপনার বানানো চালু থাকা কোনো নোটিফিকেশন আজ বা কাল পড়েনি।</p></div>
        <?php else : ?>
            <div class="ma-table-wrap"><table class="ma-table">
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
            </table></div>
        <?php endif; ?>
    </section>
    <?php endif;
    if ($nd) : $today = gmdate('Y-m-d', time() + ma_acc_tz_off()); ?>
    <section class="ma-card" id="ma-day">
        <div class="ma-bar">
            <div class="ma-bar-title"><h2>অ্যাপ থেকে কোন কোন নোটিফিকেশন যায়</h2><span class="ma-count"><?php echo $nd['day'] === $today ? 'আজ' : esc_html(ma_acc_date($nd['day'] . ' 06:00:00')); ?> · মোট <?php echo esc_html(ma_acc_bn($nd['total'])); ?>টি · <?php echo esc_html(ma_acc_bn($nd['people'])); ?> জন সদস্য</span></div>
            <div class="ma-chips">
                <?php for ($i = 0; $i < 7; $i++) : $d = gmdate('Y-m-d', strtotime($today . ' UTC') - $i * DAY_IN_SECONDS); ?>
                    <a class="ma-chip <?php echo $nd['day'] === $d ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'notices', 'nv' => 'stats', 'nday' => $d]); ?>#ma-day"><?php echo $i === 0 ? 'আজ' : ($i === 1 ? 'গতকাল' : esc_html(ma_acc_bn((int) substr($d, 8)) . ' ' . ma_acc_month_name(substr($d, 0, 7)))); ?></a>
                <?php endfor; ?>
            </div>
        </div>
        <div class="ma-day-grid">
            <div class="ma-table-wrap">
                <table class="ma-table ma-cat">
                    <thead><tr><th>কখন</th><th>কোন নোটিফিকেশন</th><th class="right">কতজন</th><th class="right">কয়টি</th></tr></thead>
                    <tbody>
                    <?php foreach ($nd['app'] as $it) : $none = $it['count'] === 0 && $it['failed'] === 0; ?>
                        <tr class="<?php echo $none ? 'ma-dim' : ''; ?>">
                            <td><strong><?php echo esc_html($it['times'] ? ma_acc_bn(implode(', ', $it['times'])) : ($it['at'] !== '' ? ma_acc_bn($it['at']) : '—')); ?></strong><?php if ($it['ahead']) : ?><span class="ma-ver"><?php echo esc_html(ma_acc_bn($it['ahead'])); ?>টি আসবে</span><?php endif; ?></td>
                            <td><strong><?php echo esc_html($it['label']); ?></strong>
                                <?php if (!$it['cap']) : ?><span class="ma-tag">সীমার বাইরে</span><?php endif; ?>
                                <?php if ($it['by'] === 'server') : ?><span class="ma-tag srv">সার্ভার থেকে পুশ</span><?php endif; ?>
                                <?php if ($it['off']) : ?><span class="ma-tag">চালু করলে</span><?php endif; ?>
                                <span class="ma-ver">“<?php echo esc_html($it['sample']); ?>” · <?php echo esc_html($it['when']); ?></span></td>
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
    <?php endif;
    if ($ov) : $gl = $ov['groups']; $mx = max(1, max(array_column($ov['days'], 'total') ?: [1])); ?>
    <section class="ma-card" id="ma-daily">
        <div class="ma-bar"><div class="ma-bar-title"><h2>গত ১৪ দিনে দিনে কতটি</h2><span class="ma-count">সব সদস্য মিলে · দিনে চাপলে সেদিনের তালিকা</span></div></div>
        <div class="ma-table-wrap">
            <table class="ma-table ma-daily">
                <thead><tr><th>দিন</th><th>মোট</th><?php foreach ($gl as $k => $l) : ?><th class="right hide-s"><?php echo esc_html($l); ?></th><?php endforeach; ?><th class="right">পৌঁছায়নি</th></tr></thead>
                <tbody>
                <?php foreach ($ov['days'] as $d) : ?>
                    <tr>
                        <td><a href="<?php echo ma_acc_url(['tab' => 'notices', 'nv' => 'stats', 'nday' => $d['day']]); ?>#ma-day"><?php echo esc_html(ma_acc_date($d['day'] . ' 06:00:00')); ?></a></td>
                        <td><div class="ma-meter"><i style="width:<?php echo (int) round($d['total'] / $mx * 100); ?>%"></i><b><?php echo esc_html(ma_acc_bn($d['total'])); ?></b></div></td>
                        <?php foreach ($gl as $k => $l) : ?><td class="right hide-s <?php echo $d[$k] ? '' : 'muted'; ?>"><?php echo esc_html(ma_acc_bn($d[$k])); ?></td><?php endforeach; ?>
                        <td class="right"><?php echo $d['failed'] ? '<span class="ma-pill expired">' . esc_html(ma_acc_bn($d['failed'])) . '</span>' : '<span class="muted">০</span>'; ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </section>
    <?php endif;
}

/** One app notification changed from the side panel, switched on/off, put back, or the daily limit. */
add_action('admin_post_ma_note_rule_one', function () {
    ma_acc_guard('ma_note_rule_one');
    ma_acc_back(ma_ui_note_rule_apply(wp_unslash($_POST)), 'ok', ['tab' => 'notices']);
});

/** The side panel's save, the switch, "আগের মতো করুন" and the daily limit; → the message to show. */
function ma_ui_note_rule_apply(array $p) {
    $r = ma_note_rules();
    $kinds = $r['kinds'];
    $cap = $r['cap'];
    $op = sanitize_key((string) ($p['op'] ?? 'save'));
    $key = (string) ($p['key'] ?? '');
    $msg = 'রাখা হয়েছে — সদস্যদের ফোন পরের বার খুললে বা কয়েক ঘণ্টার মধ্যে মানবে।';
    if ($op === 'cap') {
        $cap = $p['cap'] ?? '';
        $msg = 'দিনের সীমা রাখা হয়েছে।';
    } elseif (isset($kinds[$key])) {
        if ($op === 'toggle') {
            $kinds[$key]['on'] = !$kinds[$key]['on'];
            $msg = $kinds[$key]['on'] ? 'চালু করা হয়েছে।' : 'বন্ধ করা হয়েছে — কারও কাছে যাবে না।';
        } elseif ($op === 'reset') {
            $kinds[$key] = ['on' => true, 'at' => '', 'title' => '', 'body' => '', 'who' => 'all', 'wd' => 0];
            $msg = 'অ্যাপের নিজের সময় আর লেখায় ফেরানো হয়েছে।';
        } else {
            $kinds[$key] = [
                'on' => !empty($p['on']),
                'at' => (string) ($p['at'] ?? ''),
                'title' => ma_ui_note_from_bn((string) ($p['title'] ?? '')),
                'body' => ma_ui_note_from_bn((string) ($p['body'] ?? '')),
                'who' => (string) ($p['who'] ?? 'all'),
                'wd' => (int) ($p['wd'] ?? 0),
            ];
        }
    }
    ma_note_rules_save(['kinds' => $kinds, 'cap' => $cap === null ? '' : $cap]);
    return $msg;
}

// ── পেমেন্ট ──

/** For each waiting payment: did bKash bring it (ok), not yet (no), or less (low)? */
function ma_ui_pay_match($p, $received, $plans) {
    foreach ($received as $r) {
        if (strcasecmp(trim((string) $r['trx']), trim((string) $p['trx'])) === 0) {
            $need = (int) ($plans[$p['plan']]['price'] ?? $p['amount']);
            return (int) $r['amount'] >= $need ? ['ok', 'বিকাশে মিলেছে — টাকা এসেছে'] : ['low', 'টাকা কম এসেছে (৳' . ma_acc_bn($r['amount']) . ')'];
        }
    }
    return ['no', 'বিকাশে এখনো আসেনি'];
}

function ma_acc_render_payments($v) {
    $labels = ma_pay_labels();
    $plans = $v['plans'];
    $c = $v['pay_counts'];
    $post = esc_url(admin_url('admin-post.php'));
    $bk = $v['bkash'] ?? ['auto' => false, 'phone_set' => false, 'last_sms' => null, 'received' => []];
    $pending = $v['pay_pending'] ?? [];
    $tabs = ['all' => 'সব', 'approved' => 'অনুমোদিত', 'rejected' => 'বাতিল'];
    $pst = in_array($v['pst'], ['all', 'approved', 'rejected'], true) ? $v['pst'] : 'all';
    $matched = 0;
    foreach ($pending as $p) {
        $matched += ma_ui_pay_match($p, $bk['received'], $plans)[0] === 'ok' ? 1 : 0;
    }
    $owner = !empty($v['can_settings']);
    ma_ui_head('পেমেন্ট', 'ওয়েবসাইট আর বিকাশ — সব এক জায়গায়', $owner ? '<button class="ma-btn ghost" type="button" data-open="ma-pay-set">' . ma_ui_icon('gear', 16) . ' মাধ্যম ও দাম</button>' : '');
    $bl = ma_bk_status_labels();
    ?>
    <div class="ma-stats">
        <div><span>দেখার অপেক্ষায়</span><strong class="<?php echo $pending ? 'r' : ''; ?>"><?php echo esc_html(ma_acc_bn(count($pending))); ?></strong><em><?php echo $matched ? esc_html(ma_acc_bn($matched)) . 'টা বিকাশে মিলেছে' : 'বিকাশে মিলিয়ে দেখুন'; ?></em></div>
        <div><span>এ মাসে আয়</span><strong>৳<?php echo esc_html(ma_acc_bn(number_format($v['pay_month']))); ?></strong><em>অনুমোদিত পেমেন্ট</em></div>
        <div><span>মোট আয় (ওয়েবসাইট)</span><strong>৳<?php echo esc_html(ma_acc_bn(number_format($c['approved']['amt'] ?? 0))); ?></strong><em><?php echo esc_html(ma_acc_bn($c['approved']['n'] ?? 0)); ?>টা পেমেন্ট</em></div>
        <div class="ma-bk-card">
            <span>বিকাশ মেলানো</span>
            <strong class="small <?php echo $bk['phone_set'] ? 'g' : 'w'; ?>"><?php echo $bk['phone_set'] ? 'ফোন যুক্ত আছে' : 'ফোন যুক্ত নেই'; ?></strong>
            <em><?php echo $bk['last_sms'] ? 'শেষ SMS ' . esc_html(ma_acc_ago(gmdate('Y-m-d H:i:s', strtotime($bk['last_sms'])))) : 'পেমেন্টের সিমের ফোনে অ্যাডমিন অ্যাপ › পেমেন্ট › বিকাশ মেলানো'; ?></em>
            <form method="post" action="<?php echo $post; ?>" class="ma-bk-auto">
                <input type="hidden" name="action" value="ma_bk_settings"><?php wp_nonce_field('ma_bk_settings'); ?>
                <input type="hidden" name="auto" value="<?php echo $bk['auto'] ? '' : '1'; ?>">
                <span>নিজে থেকে অনুমোদন</span>
                <button type="submit" class="ma-toggle <?php echo $bk['auto'] ? 'on' : ''; ?>" role="switch" aria-checked="<?php echo $bk['auto'] ? 'true' : 'false'; ?>" aria-label="নিজে থেকে অনুমোদন <?php echo $bk['auto'] ? 'বন্ধ করুন' : 'চালু করুন'; ?>"></button>
            </form>
        </div>
    </div>

    <section class="ma-card">
        <div class="ma-bar"><div class="ma-bar-title"><h2>অনুমোদন বাকি</h2><span class="ma-count"><?php echo esc_html(ma_acc_bn(count($pending))); ?>টা</span></div>
            <?php if ($matched) : ?>
                <form method="post" action="<?php echo $post; ?>" class="ma-inline-form" data-confirm="বিকাশে মিলে যাওয়া <?php echo esc_attr(ma_acc_bn($matched)); ?>টা পেমেন্টে প্রিমিয়াম দেবেন?">
                    <input type="hidden" name="action" value="ma_pay_matched"><?php wp_nonce_field('ma_pay_matched'); ?>
                    <button class="ma-btn soft small" type="submit"><?php echo ma_ui_icon('check', 15); ?> মিলে যাওয়া <?php echo esc_html(ma_acc_bn($matched)); ?>টা একসাথে অনুমোদন</button>
                </form>
            <?php endif; ?>
        </div>
        <?php if (!$pending) : ?>
            <div class="ma-todo-none"><?php echo ma_ui_icon('check', 20); ?> দেখার মতো কোনো পেমেন্ট নেই। কেউ জমা দিলে এখানে আসবে, আর আপনার ইমেইলেও জানানো হবে।</div>
        <?php else : ?>
            <div class="ma-pays">
                <?php foreach ($pending as $p) :
                    [$mk, $ml] = ma_ui_pay_match($p, $bk['received'], $plans);
                    $data = ['id' => (int) $p['id'], 'name' => $p['name'] !== '' ? $p['name'] : $p['email'], 'email' => $p['email'], 'trx' => $p['trx'], 'method' => $p['method'], 'sender' => $p['sender'],
                        'amount' => '৳' . ma_acc_bn($p['amount']), 'plan' => $plans[$p['plan']]['label'] ?? $p['plan'], 'note' => $p['note'], 'phone' => $p['phone']];
                    $ini = ma_acc_initials($p['name'], $p['email']);
                    ?>
                    <div class="ma-pay">
                        <span class="ma-av" style="--h:<?php echo (int) ma_acc_hue($p['email']); ?>"><?php echo esc_html($ini); ?></span>
                        <span class="who"><strong><?php echo esc_html($data['name']); ?></strong><span><?php echo esc_html($p['email']); ?></span></span>
                        <span class="amt"><strong>৳<?php echo esc_html(ma_acc_bn($p['amount'])); ?></strong><span><?php echo esc_html($data['plan'] . ' · ' . $p['method']); ?></span></span>
                        <span class="trx"><span class="ma-code"><code id="trx-<?php echo (int) $p['id']; ?>"><?php echo esc_html($p['trx']); ?></code><button type="button" class="ma-icon" data-copy="trx-<?php echo (int) $p['id']; ?>" title="কপি" aria-label="কপি"><svg viewBox="0 0 24 24" width="15" height="15" aria-hidden="true"><path fill="currentColor" d="M8 3h10a2 2 0 0 1 2 2v12h-2V5H8V3Zm-3 4h10a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V9a2 2 0 0 1 2-2Zm0 2v10h10V9H5Z"/></svg></button></span><span><?php echo esc_html($p['sender'] . ' · ' . ma_acc_ago($p['created_at'])); ?></span></span>
                        <span class="m"><span class="ma-match <?php echo esc_attr($mk); ?>"><?php echo ma_ui_icon($mk === 'ok' ? 'check' : ($mk === 'low' ? 'warn' : 'clock'), 14); ?> <?php echo esc_html($ml); ?></span></span>
                        <span class="ops">
                            <button type="button" class="ma-btn small ghost" data-open="ma-pay-no" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>">বাতিল</button>
                            <button type="button" class="ma-btn small" data-open="ma-pay-yes" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>">অনুমোদন</button>
                        </span>
                    </div>
                <?php endforeach; ?>
            </div>
        <?php endif; ?>
    </section>

    <section class="ma-card">
        <div class="ma-bar"><div class="ma-bar-title"><h2>সব পেমেন্ট</h2></div>
            <div class="ma-chips">
                <?php foreach ($tabs as $k => $l) : ?>
                    <a class="ma-chip <?php echo $pst === $k ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'payments', 'pst' => $k]); ?>"><?php echo esc_html($l); ?><?php if ($k !== 'all' && !empty($c[$k]['n'])) : ?> · <?php echo esc_html(ma_acc_bn($c[$k]['n'])); ?><?php endif; ?></a>
                <?php endforeach; ?>
            </div>
        </div>
        <?php $done = array_values(array_filter($v['payments'], fn($p) => $p['status'] !== 'pending')); if (!$done) : ?>
            <p class="muted ma-pad">এখানে এখনো কিছু নেই। ওয়েবসাইটের পাতায় <code>[my_assistant_pro]</code> লিখলে প্রিমিয়ামের পাতা আর পেমেন্ট ফর্ম দেখাবে।</p>
        <?php else : ?>
            <div class="ma-table-wrap"><table class="ma-table">
                <thead><tr><th>কবে</th><th>কে</th><th>টাকা</th><th>মাধ্যম ও নম্বর</th><th>TrxID</th><th>অবস্থা</th></tr></thead>
                <tbody>
                <?php foreach ($done as $p) : [$label, $cls] = $labels[$p['status']] ?? $labels['pending']; ?>
                    <tr>
                        <td class="muted"><?php echo esc_html(ma_acc_date($p['reviewed_at'] ?: $p['created_at'])); ?></td>
                        <td><div class="ma-who-text"><strong><?php echo esc_html($p['name'] !== '' ? $p['name'] : $p['email']); ?></strong><span><?php echo esc_html($p['email']); ?></span></div></td>
                        <td><strong>৳<?php echo esc_html(ma_acc_bn($p['amount'])); ?></strong><span class="ma-ver"><?php echo esc_html($plans[$p['plan']]['label'] ?? $p['plan']); ?></span></td>
                        <td><?php echo esc_html($p['method']); ?><span class="ma-ver ma-mono"><?php echo esc_html($p['sender']); ?></span></td>
                        <td class="ma-mono"><?php echo esc_html($p['trx']); ?></td>
                        <td><span class="ma-pill <?php echo esc_attr($cls); ?>"><?php echo esc_html($label); ?></span><?php if ($p['reason'] !== '') : ?><span class="ma-ver"><?php echo esc_html($p['reason']); ?></span><?php endif; ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table></div>
        <?php endif; ?>
    </section>

    <section class="ma-card">
        <details class="ma-details">
            <summary><span><strong>বিকাশে আসা টাকা</strong> <span class="ma-count"><?php echo esc_html(ma_acc_bn(count($bk['received']))); ?>টা</span></span><span class="muted ma-small">পেমেন্টের সিমের ফোন থেকে · কীভাবে কাজ করে</span></summary>
            <div class="ma-bar" style="padding-top:4px"><span class="muted ma-small">শুধু টাকা, TrxID, কোন নম্বর থেকে, কখন আর ব্যালেন্স মিলেছে কিনা আসে — মেসেজের বাকি লেখা আসে না। নিজে থেকে অনুমোদন চালু থাকলে: TrxID মিললে, প্ল্যানের দাম এলে আর ব্যালেন্স মিলিয়ে মেসেজটা আসল নিশ্চিত হলে প্রিমিয়াম চালু হয়; ভুয়া SMS আপনার জন্য অপেক্ষা করে।</span>
                <button class="ma-btn ghost small" type="button" data-open="ma-bk-paste">বিকাশের SMS পেস্ট করুন</button></div>
            <?php if ($bk['received']) : ?>
                <div class="ma-table-wrap"><table class="ma-table">
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
                </table></div>
            <?php else : ?>
                <p class="muted ma-pad">এখনো বিকাশ থেকে কিছু আসেনি।</p>
            <?php endif; ?>
        </details>
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

    <?php if ($owner) : ?>
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
    <?php endif;
}

/** Approve every waiting payment bKash already brought in full (one press, the same check as one by one). */
add_action('admin_post_ma_pay_matched', function () {
    ma_acc_guard('ma_pay_matched');
    global $wpdb;
    $plans = ma_pay_plans();
    $received = ma_bk_overview()['received'];
    $user = wp_get_current_user();
    $n = 0;
    foreach ($wpdb->get_results('SELECT * FROM ' . ma_pay_table() . " WHERE status = 'pending' ORDER BY created_at", ARRAY_A) ?: [] as $p) {
        if (ma_ui_pay_match($p, $received, $plans)[0] !== 'ok') {
            continue;
        }
        [$ok] = ma_pay_decide((int) $p['id'], true, '', false, $user ? $user->user_email : '');
        $n += $ok ? 1 : 0;
    }
    ma_acc_back(ma_acc_bn($n) . 'টা পেমেন্টে প্রিমিয়াম দেওয়া হয়েছে।', 'ok', ['tab' => 'payments']);
});

// ── Page parts: styles and the little scripts the new pages use ──

function ma_ui_styles() {
    ?>
    <style>
    .ma{max-width:none;margin:16px 20px 40px 0}
    .ma-shell{display:flex;gap:24px;align-items:flex-start}
    .ma-side{width:224px;flex:none;background:#fff;border:1px solid var(--line);border-radius:16px;padding:16px 10px;position:sticky;top:46px;display:flex;flex-direction:column;gap:2px}
    .ma-side-brand{display:flex;gap:10px;align-items:center;padding:2px 8px 12px}
    .ma-side-logo{width:36px;height:36px;border-radius:10px;background:var(--g);color:#fff;display:grid;place-items:center;flex:none}
    .ma-side-name{font-weight:700;font-size:15.5px;line-height:1.2}
    .ma-side-sub{font-size:11.5px;color:var(--mut)}
    .ma-side .ma-tabs{display:flex;flex-direction:column;gap:1px;background:none;padding:0;border-radius:0}
    .ma-side-grp{font-size:11.5px;font-weight:700;color:var(--mut);padding:12px 10px 3px;letter-spacing:.02em}
    .ma-side .ma-tabs a{display:flex;align-items:center;gap:10px;padding:8px 10px;border-radius:9px;color:var(--ink);font-weight:500;font-size:14px;text-decoration:none}
    .ma-side .ma-tabs a svg{color:var(--mut);flex:none}
    .ma-side .ma-tabs a:hover{background:var(--bg);color:var(--ink)}
    .ma-side .ma-tabs a.on{background:var(--gt);color:var(--gd);font-weight:700}
    .ma-side .ma-tabs a.on svg{color:var(--g)}
    .ma-side .ma-tabs a:focus-visible{outline:2px solid var(--g);outline-offset:1px}
    .ma-side .ma-badge{margin-left:auto;background:var(--rose);color:#fff}
    .ma-side .ma-badge.warn{background:#F59E0B;color:#111827}
    .ma-side-foot{font-size:11.5px;color:var(--mut);border-top:1px solid var(--line);margin:10px 4px 0;padding:10px 6px 0;line-height:1.5}
    .ma-main{flex:1;min-width:0}
    .ma-main>.ma-card:first-child,.ma-main>.ma-toast:first-child{margin-top:0}
    .ma-head{display:flex;align-items:flex-start;justify-content:space-between;gap:16px;flex-wrap:wrap;margin:2px 0 4px}
    .ma .ma-h1{font-size:24px;font-weight:700;margin:0;padding:0;line-height:1.3;color:var(--ink)}
    .ma-sub{margin:2px 0 0;color:var(--mut);font-size:14px}
    .ma-head-actions{display:flex;gap:8px;flex-wrap:wrap}
    .ma-stats{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin-top:16px}
    .ma-stats>div{background:#fff;border:1px solid var(--line);border-radius:14px;padding:14px 16px;display:flex;flex-direction:column;gap:2px;min-width:0}
    .ma-stats span{font-size:12.5px;color:var(--mut);font-weight:600}
    .ma-stats strong{font-size:26px;font-weight:700;line-height:1.2}
    .ma-stats strong.small{font-size:16px;line-height:1.5}
    .ma-stats strong.g{color:var(--gd)}.ma-stats strong.r{color:var(--rose)}.ma-stats strong.w{color:var(--amber)}
    .ma-stats em{font-style:normal;font-size:12.5px;color:var(--mut)}
    .ma-bk-auto{display:flex;align-items:center;gap:8px;margin:8px 0 0}
    .ma-bk-auto span{font-weight:500;color:var(--mut2)}
    .ma-todo{display:flex;flex-direction:column;border-top:1px solid var(--line)}
    .ma-todo-row{display:flex;align-items:center;gap:14px;padding:12px 20px;border-bottom:1px solid #F1F2F4;text-decoration:none;color:inherit}
    .ma-todo-row:last-child{border-bottom:0}
    .ma-todo-row:hover{background:#F8FBFA}
    .ma-todo-text{flex:1;min-width:0;display:flex;flex-direction:column}
    .ma-todo-text span{font-size:13px;color:var(--mut);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .ma-todo-none{display:flex;gap:10px;align-items:center;padding:16px 20px 20px;color:var(--gd);font-weight:600;border-top:1px solid var(--line)}
    .ma-tile{width:38px;height:38px;border-radius:11px;display:grid;place-items:center;flex:none}
    .ma-tile.bad{background:var(--rot);color:var(--rose)}.ma-tile.warn{background:var(--amt);color:var(--amber)}.ma-tile.blue{background:var(--blt);color:var(--blue)}
    .ma-two{display:grid;grid-template-columns:1.6fr 1fr;gap:16px}
    .ma-two>.ma-card{margin-top:16px}
    .ma-mini{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-top:12px}
    .ma-mini div{background:var(--bg);border-radius:12px;padding:12px 14px;display:flex;flex-direction:column}
    .ma-mini strong{font-size:22px}.ma-mini span{font-size:12.5px;color:var(--mut)}
    .ma-subtabs{display:flex;gap:4px;border-bottom:1px solid var(--line);margin-top:14px;flex-wrap:wrap}
    .ma-subtabs a{padding:10px 14px;font-weight:600;color:var(--mut);text-decoration:none;border-bottom:2px solid transparent;margin-bottom:-1px}
    .ma-subtabs a:hover{color:var(--ink)}
    .ma-subtabs a.on{color:var(--gd);border-color:var(--g)}
    .ma-filter{margin-top:14px}
    .ma-filter .ma-chip{cursor:pointer;font:inherit;font-size:13.5px}
    .ma-note-rules{display:flex;gap:10px;align-items:center;background:var(--gt);color:var(--gd);border-radius:12px;padding:10px 14px;margin-top:12px;font-size:13.5px;line-height:1.55}
    .ma-note-rules svg{flex:none}.ma-note-rules span{flex:1}
    .ma-nlist{overflow:hidden}
    .ma-nhead,.ma-nrow{display:grid;grid-template-columns:62px minmax(0,1fr) 200px 76px 52px 96px;gap:12px;align-items:center;padding:10px 18px}
    .ma-nhead{background:#FAFBFA;border-bottom:1px solid var(--line);font-size:12.5px;color:var(--mut);font-weight:600}
    .ma-nhead .c,.ma-nrow .c{text-align:right}
    .ma-nrow{border-bottom:1px solid #F1F2F4}
    .ma-nrow:hover{background:#FAFCFB}
    .ma-nrow .t{font-weight:700;font-size:15px}
    .ma-nrow .w{display:flex;flex-direction:column;font-size:13px;line-height:1.45}
    .ma-nrow .w span{color:var(--mut)}
    .ma-nrow .c{display:flex;flex-direction:column;align-items:flex-end}
    .ma-nrow .e{display:flex;gap:4px;justify-content:flex-end;align-items:center}
    .ma-nrow.off .p,.ma-nrow.off .t,.ma-nrow.off .w{opacity:.5}
    .ma-npart{display:flex;align-items:center;gap:6px;padding:12px 18px 4px;font-size:13px;font-weight:700;color:var(--mut)}
    .ma-phone{display:flex;flex-direction:column;gap:1px;border:1px solid var(--line);border-radius:12px;padding:8px 12px;background:#FBFCFB;min-width:0}
    .ma-phone strong{font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .ma-phone>span:last-child:not(.ma-phone-app){font-size:13px;color:var(--mut2);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .ma-phone-app{font-size:11.5px;color:var(--mut);display:flex;align-items:center;gap:6px;white-space:nowrap;overflow:hidden}
    .ma-phone-app i{width:13px;height:13px;border-radius:4px;background:var(--g);display:inline-block;flex:none}
    .ma-phone-app .ma-tag{margin-left:2px}
    .ma-phone.big{background:#fff;border:0;padding:10px 12px}
    .ma-phone.big strong,.ma-phone.big>span:last-child{white-space:normal}
    .ma-toggle{width:40px;height:23px;border-radius:999px;border:0;background:#CBD5D1;position:relative;cursor:pointer;padding:0;flex:none;transition:background .15s}
    .ma-toggle::after{content:"";position:absolute;top:3px;left:3px;width:17px;height:17px;border-radius:50%;background:#fff;transition:transform .15s;box-shadow:0 1px 2px rgba(0,0,0,.2)}
    .ma-toggle.on{background:var(--g)}
    .ma-toggle.on::after{transform:translateX(17px)}
    .ma-toggle:focus-visible{outline:2px solid var(--g);outline-offset:2px}
    .ma-drawer{margin:0 0 0 auto;height:100vh;max-height:100vh;width:min(480px,100vw);border:0;padding:0;border-left:1px solid var(--line);font-family:"Hind Siliguri",system-ui,sans-serif;color:var(--ink)}
    .ma-drawer::backdrop{background:rgba(17,24,39,.35)}
    .ma-drawer form{display:flex;flex-direction:column;height:100%;margin:0}
    .ma-drawer-head{display:flex;gap:12px;align-items:center;padding:16px 20px;border-bottom:1px solid var(--line)}
    .ma-drawer-head>div{flex:1;min-width:0}
    .ma-drawer-head h3{margin:0;font-size:18px}
    .ma-drawer-head p{margin:0;font-size:13px}
    .ma-drawer-body{flex:1;overflow:auto;padding:16px 20px}
    .ma-drawer-body label{display:flex;flex-direction:column;gap:6px;font-weight:600;font-size:13.5px;color:var(--mut2);margin:12px 0 6px}
    .ma-drawer-body input[type=text],.ma-drawer-body input[type=time],.ma-drawer-body input[type=number],.ma-drawer-body select,.ma-drawer-body textarea{border:1px solid var(--line);border-radius:10px;padding:8px 12px;font:inherit;font-weight:400;font-size:14px;color:var(--ink);min-height:42px;width:100%}
    .ma-drawer-body textarea{font-family:inherit;line-height:1.6}
    .ma-drawer-body input:focus,.ma-drawer-body textarea:focus,.ma-drawer-body select:focus{border-color:var(--g);box-shadow:0 0 0 3px rgba(14,122,95,.15);outline:0}
    .ma-drawer-foot{display:flex;gap:8px;align-items:center;padding:12px 20px;border-top:1px solid var(--line)}
    .ma-preview{background:#1E2A25;border-radius:16px;padding:12px}
    .ma-preview-k{font-size:12px;color:#A8BCB4;margin-bottom:8px}
    .ma-words{display:flex;gap:6px;flex-wrap:wrap;align-items:center;font-size:12.5px}
    .ma-words .ma-chip{cursor:pointer;font:inherit;font-size:12.5px;padding:3px 10px}
    .ma-guide{background:var(--bg);border-radius:12px;padding:10px 14px;margin:12px 0 4px;font-size:13px;line-height:1.6;color:var(--mut2)}
    .ma-guide summary{font-weight:700;cursor:pointer;color:var(--ink)}
    .ma-guide p{margin:8px 0 0}
    .ma-guide dl{display:grid;grid-template-columns:auto 1fr;gap:6px 10px;margin:8px 0 0}
    .ma-guide dt{font-weight:700;color:var(--gd);white-space:nowrap}
    .ma-guide dd{margin:0}
    .ma-guide ul{margin:8px 0 0;padding-left:18px}
    .ma-warn{background:var(--amt);color:var(--amber);border-radius:10px;padding:8px 12px;font-size:13px;margin:8px 0 0}
    .ma-sent{display:flex;gap:8px;align-items:center;background:var(--bg);border-radius:10px;padding:10px 12px;color:var(--mut2);font-size:13px;margin-top:12px}
    .ma-pays{display:flex;flex-direction:column;border-top:1px solid var(--line)}
    .ma-pay{display:grid;grid-template-columns:40px minmax(150px,1.3fr) minmax(110px,.8fr) minmax(170px,1fr) minmax(170px,1fr) auto;gap:14px;align-items:center;padding:13px 20px;border-bottom:1px solid #F1F2F4}
    .ma-pay:last-child{border-bottom:0}
    .ma-pay>span{display:flex;flex-direction:column;min-width:0}
    .ma-pay>span>span:not(.ma-code):not(.ma-match){font-size:12.5px;color:var(--mut);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .ma-pay .who strong{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
    .ma-pay .amt strong{font-size:16px}
    .ma-pay .ops{flex-direction:row;gap:6px}
    .ma-pay>.ma-av{display:grid;place-items:center}
    .ma-match{display:inline-flex;align-items:center;gap:5px;font-size:12.5px;font-weight:600;border-radius:999px;padding:3px 10px;align-self:flex-start}
    .ma-match.ok{background:var(--gt);color:var(--gd)}.ma-match.no{background:var(--amt);color:var(--amber)}.ma-match.low{background:var(--rot);color:var(--rose)}
    .ma-details summary{display:flex;justify-content:space-between;gap:12px;align-items:center;padding:16px 20px;cursor:pointer;list-style:none;flex-wrap:wrap}
    .ma-details summary::-webkit-details-marker{display:none}
    .ma-details summary::after{content:"▾";color:var(--mut)}
    .ma-details[open] summary::after{content:"▴"}
    .ma-main{container-type:inline-size}
    .ma-grid>*,.ma-two>*,.ma-ai-row>*{min-width:0}
    .ma-code{min-width:0}
    /* Pop-ups (owner, 4 Nov: "কনফার্মেশন বা মডেল সুন্দর কর") */
    .ma-dialog{border-radius:18px;padding:22px 24px 20px;border:1px solid var(--line);box-shadow:0 24px 64px -16px rgba(17,24,39,.35)}
    .ma-dialog[open],.ma-drawer[open]{animation:ma-pop .16s ease-out}
    .ma-drawer[open]{animation-name:ma-slide}
    .ma-dialog::backdrop,.ma-drawer::backdrop{background:rgba(17,24,39,.42);backdrop-filter:blur(2px);animation:ma-fade .16s ease-out}
    @keyframes ma-pop{from{opacity:0;transform:translateY(8px) scale(.97)}to{opacity:1;transform:none}}
    @keyframes ma-slide{from{transform:translateX(32px);opacity:.4}to{transform:none;opacity:1}}
    @keyframes ma-fade{from{opacity:0}to{opacity:1}}
    @media (prefers-reduced-motion:reduce){.ma-dialog[open],.ma-drawer[open],.ma-dialog::backdrop,.ma-drawer::backdrop{animation:none}}
    .ma-dialog h3{font-size:18px;line-height:1.4}
    .ma-dialog-actions{border-top:1px solid var(--line);margin:18px -24px 0;padding:14px 24px 0}
    .ma-dialog-actions .ma-btn{min-width:96px;justify-content:center}
    .ma-confirm{width:min(400px,calc(100vw - 32px));text-align:center;padding-top:26px}
    .ma-confirm-ic{width:52px;height:52px;border-radius:16px;display:grid;place-items:center;margin:0 auto 12px;background:var(--gt);color:var(--g)}
    .ma-confirm.danger .ma-confirm-ic{background:var(--rot);color:var(--rose)}
    .ma-confirm h3{margin:0 0 4px}
    .ma-confirm p{color:var(--mut);margin:0}
    .ma-confirm .ma-dialog-actions{justify-content:center}
    .ma-confirm .ma-dialog-actions .ma-btn{flex:1}
    .ma-dialog .ma-dl{background:var(--bg);border-radius:12px;padding:12px 14px;margin-top:12px}
    @media (max-width:960px){.ma-main{width:100%}}
    .ma-main .ma-who{min-width:0}
    .ma-main .ma-who-text strong,.ma-main .ma-who-text span{max-width:220px}
    .ma-main .ma-ops .ma-btn{min-width:0}
    .ma-price-wrap input{width:100%;min-width:64px;height:34px;border:1px solid var(--line);border-radius:8px;padding:0 8px;font:inherit;font-size:13px}
    .ma-price-wrap{border-top:0}
    @container (max-width:1000px){.ma-main .hide-m{display:none}}
    @container (max-width:820px){.ma-main .hide-s{display:none}}
    @media (max-width:1100px){.ma-nhead,.ma-nrow{grid-template-columns:54px minmax(0,1fr) 150px 52px 86px}.ma-nhead .c,.ma-nrow .c{display:none}.ma-pay{grid-template-columns:40px minmax(0,1fr) auto;row-gap:6px}.ma-pay .trx,.ma-pay .m{grid-column:2/4}}
    @media (max-width:960px){.ma-shell{flex-direction:column}.ma-side{width:100%;position:static}.ma-side .ma-tabs{flex-direction:row;flex-wrap:wrap}.ma-side-grp,.ma-side-foot{display:none}.ma-stats{grid-template-columns:repeat(2,minmax(0,1fr))}.ma-two{grid-template-columns:1fr}}
    @media (max-width:700px){.ma-nhead{display:none}.ma-nrow{grid-template-columns:44px minmax(0,1fr) auto;row-gap:6px}.ma-nrow .w{grid-column:2/4}.ma-nrow .o{grid-row:1;grid-column:3}.ma-nrow .e{grid-column:2/4;justify-content:flex-start}}
    </style>
    <?php
}

/** The styled "are you sure?" window; inside the page's wrapper so it takes its colours. */
function ma_ui_confirm_markup() {
    ?>
    <dialog class="ma-dialog ma-confirm" id="ma-confirm" aria-labelledby="ma-confirm-q">
        <div class="ma-confirm-ic" data-cf-ic></div>
        <h3 id="ma-confirm-q"></h3>
        <p data-cf-sub></p>
        <div class="ma-dialog-actions">
            <button type="button" class="ma-btn ghost" data-cf="no">না, থাক</button>
            <button type="button" class="ma-btn" data-cf="yes">হ্যাঁ</button>
        </div>
    </dialog>
    <?php
}

function ma_ui_script() {
    ?>

    <script>
    (function () {
        function fillPv(dlg) {
            var d = dlg._ne || {};
            var t = dlg.querySelector('[data-ne="title"]').value.trim();
            var b = dlg.querySelector('[data-ne="body"]').value.trim();
            function f(s) { return s.split('[নাম]').join('রাকিব').split('[অ্যাপের শিরোনাম]').join(d.sample || '').split('[অ্যাপের লেখা]').join(d.sample_body || ''); }
            dlg.querySelector('[data-ne-pv="title"]').textContent = t ? f(t) : (d.sample || '');
            dlg.querySelector('[data-ne-pv="body"]').textContent = b ? f(b) : (d.sample_body || '');
            var bad = (t + ' ' + b).match(/\[[^\]]*\]/g) || [];
            bad = bad.filter(function (w) { return ['[নাম]', '[অ্যাপের শিরোনাম]', '[অ্যাপের লেখা]'].indexOf(w) < 0; });
            var warn = dlg.querySelector('[data-ne-bad]');
            warn.hidden = !bad.length;
            warn.textContent = bad.length ? bad.join(', ') + ' — এটা চেনা শব্দ নয়, ফোনে হুবহু দেখাবে। চেনা: [নাম], [অ্যাপের শিরোনাম], [অ্যাপের লেখা]।' : '';
        }
        document.addEventListener('click', function (e) {
            var ed = e.target.closest('[data-note-edit]');
            if (ed) {
                var d = JSON.parse(ed.getAttribute('data-note-edit'));
                var dlg = document.getElementById('ma-note-edit');
                dlg._ne = d;
                dlg.querySelector('[data-ne="key"]').value = d.key;
                dlg.querySelector('[data-ne="on"]').checked = !!d.on;
                var title = dlg.querySelector('[data-ne="title"]'); title.value = d.title || ''; title.placeholder = d.sample || '';
                var body = dlg.querySelector('[data-ne="body"]'); body.value = d.body || ''; body.placeholder = d.sample_body || 'অ্যাপের নিজের লেখা';
                dlg.querySelector('[data-ne="at"]').value = d.at || d.default_at || '';
                dlg.querySelectorAll('[data-ne-text="sample"]').forEach(function (x) { x.textContent = d.sample || ''; });
                dlg.querySelectorAll('[data-ne-text="sample_body"]').forEach(function (x) { x.textContent = d.sample_body || '(এর আলাদা লেখা নেই)'; });
                dlg.querySelector('[data-ne-text="label"]').textContent = d.label;
                dlg.querySelector('[data-ne-text="when"]').textContent = d.when;
                dlg.querySelector('[data-ne-text="today"]').textContent = String(d.today).replace(/\d/g, function (c) { return '০১২৩৪৫৬৭৮৯'[c]; });
                dlg.querySelector('[data-ne-text="at_hint"]').textContent = d.default_at ? 'অ্যাপের নিজের: ' + d.default_at : 'এর নির্দিষ্ট সময় নেই — কিছু ঘটলে যায়';
                var wd = dlg.querySelector('[data-ne-wd]'); wd.hidden = !d.wd_editable;
                dlg.querySelector('[data-ne="wd"]').value = String(d.wd || 0);
                dlg.querySelectorAll('[data-ne-who]').forEach(function (r) { r.checked = r.value === (d.who || 'all'); });
                fillPv(dlg);
                dlg.showModal();
                return;
            }
            var add = e.target.closest('[data-ne-add]');
            if (add) {
                var dlg2 = add.closest('dialog');
                var box = dlg2.querySelector('[data-ne="' + add.getAttribute('data-ne-add') + '"]');
                var w = add.getAttribute('data-w');
                var s = box.selectionStart || box.value.length;
                box.value = box.value.slice(0, s) + w + box.value.slice(box.selectionEnd || s);
                box.focus(); box.setSelectionRange(s + w.length, s + w.length);
                fillPv(dlg2);
                return;
            }
            var nf = e.target.closest('[data-nf]');
            if (nf) {
                var g = nf.getAttribute('data-nf');
                nf.parentNode.querySelectorAll('[data-nf]').forEach(function (b) { b.classList.toggle('on', b === nf); });
                document.querySelectorAll('.ma-nrow[data-g]').forEach(function (r) {
                    r.hidden = g === '' ? false : (g === 'off' ? r.getAttribute('data-on') !== '0' : r.getAttribute('data-g') !== g);
                });
                document.querySelectorAll('.ma-nlist .ma-npart').forEach(function (p) {
                    var n = p.nextElementSibling, any = false;
                    while (n && n.classList.contains('ma-nrow')) { if (!n.hidden) { any = true; } n = n.nextElementSibling; }
                    p.hidden = !any && n !== null && g !== '';
                });
            }
        });
        // A styled "are you sure?" instead of the browser's own box: data-confirm on a form or its button.
        var cf = document.getElementById('ma-confirm');
        var icons = {warn: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M3 6h18M8 6V4h8v2M6 6l1 14h10l1-14"/></svg>', ok: '<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9"/><path d="M9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6M12 17h.01"/></svg>'};
        document.addEventListener('submit', function (e) {
            var f = e.target, sub = e.submitter;
            if (!cf || f.dataset.cfOk) { if (f.dataset) { delete f.dataset.cfOk; } return; }
            var src = sub && sub.dataset.confirm ? sub : (f.dataset.confirm ? f : null);
            if (!src) { return; }
            e.preventDefault();
            var msg = src.dataset.confirm, parts = msg.split(/(?<=[?？])\s+/);
            var danger = /মুছ|বাতিল|তুলে নে|সরাব/.test(msg);
            cf.classList.toggle('danger', danger);
            cf.querySelector('[data-cf-ic]').innerHTML = danger ? icons.warn : icons.ok;
            cf.querySelector('h3').textContent = parts[0];
            cf.querySelector('[data-cf-sub]').textContent = parts.slice(1).join(' ');
            var yes = cf.querySelector('[data-cf="yes"]');
            yes.textContent = src.dataset.yes || (/মুছ/.test(msg) ? 'হ্যাঁ, মুছুন' : (/সরাব/.test(msg) ? 'হ্যাঁ, সরান' : (/পাঠাব/.test(msg) ? 'হ্যাঁ, পাঠান' : 'হ্যাঁ')));
            yes.className = 'ma-btn' + (danger ? ' danger' : '');
            cf._go = function () { f.dataset.cfOk = '1'; if (f.requestSubmit) { f.requestSubmit(sub || undefined); } else { f.submit(); } };
            cf.showModal();
            yes.focus();
        }, true);
        if (cf) {
            cf.addEventListener('click', function (e) {
                var b = e.target.closest('[data-cf]');
                if (!b) { return; }
                cf.close();
                if (b.getAttribute('data-cf') === 'yes' && cf._go) { cf._go(); }
            });
        }
        document.addEventListener('input', function (e) {
            if (e.target.closest && e.target.closest('#ma-note-edit')) { fillPv(document.getElementById('ma-note-edit')); }
        });
    })();
    </script>
    <?php
}
