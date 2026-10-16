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
        'pro' => ['প্রো', 'pro'],
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
    $tab = $v['tab'] === 'settings' ? 'settings' : 'members';
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
                        <div class="ma-brand-sub">সদস্য ও প্রো · getmyassistant.app</div>
                    </div>
                </div>
                <nav class="ma-tabs" aria-label="বিভাগ">
                    <a class="<?php echo $tab === 'members' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'members']); ?>">সদস্য</a>
                    <a class="<?php echo $tab === 'settings' ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'settings']); ?>">সেটিংস</a>
                </nav>
            </div>
            <div class="ma-figures">
                <div class="ma-fig"><span>মোট সদস্য</span><strong><?php echo esc_html(ma_acc_bn(number_format($s['total']))); ?></strong><em>এই সপ্তাহে নতুন <?php echo esc_html(ma_acc_bn($s['week'])); ?></em></div>
                <div class="ma-fig"><span>প্রো</span><strong><?php echo esc_html(ma_acc_bn(number_format($s['pro']))); ?></strong><em><?php echo esc_html(ma_acc_bn($paying_rate)); ?>% সদস্য প্রো নিয়েছেন</em></div>
                <div class="ma-fig"><span>ট্রায়ালে আছেন</span><strong><?php echo esc_html(ma_acc_bn(number_format($s['trial']))); ?></strong><em>৭ দিনের ফ্রি চেষ্টা</em></div>
                <div class="ma-fig"><span>সক্রিয় (৭ দিনে)</span><strong><?php echo esc_html(ma_acc_bn(number_format($s['active']))); ?></strong><em>গত ৭ দিনে অ্যাপ খুলেছেন</em></div>
            </div>
        </header>

        <?php if ($v['msg'] !== '') : ?>
            <div class="ma-toast <?php echo $v['msg_type'] === 'error' ? 'bad' : ''; ?>" role="status"><?php echo esc_html($v['msg']); ?></div>
        <?php endif; ?>

        <?php if ($tab === 'settings') {
            ma_acc_render_settings($v);
        } else {
            ma_acc_render_members($v, $labels);
        } ?>

        <p class="ma-foot">
            <svg viewBox="0 0 24 24" width="14" height="14" aria-hidden="true"><path fill="currentColor" d="M12 2 4 5v6c0 5 3.4 9.7 8 11 4.6-1.3 8-6 8-11V5l-8-3Zm0 2.2 6 2.2V11c0 4-2.6 7.8-6 9-3.4-1.2-6-5-6-9V6.4l6-2.2Z"/></svg>
            এখানে শুধু নাম, ইমেইল, ছবি আর প্রো-র তথ্য থাকে। সদস্যের হিসাব, নোট, পাসওয়ার্ড বা ব্যাকআপ কখনো এই সার্ভারে আসে না।
        </p>
    </div>
    <?php
    ma_acc_script();
}

function ma_acc_render_members($v, $labels) {
    $filters = ['' => 'সবাই', 'pro' => 'প্রো', 'trial' => 'ট্রায়াল', 'free' => 'ফ্রি', 'expired' => 'মেয়াদ শেষ', 'waiting' => 'অপেক্ষায়'];
    ?>
    <section class="ma-card">
        <div class="ma-bar">
            <div class="ma-bar-title">
                <h2>সদস্য</h2>
                <span class="ma-count"><?php echo esc_html(ma_acc_bn($v['found'])); ?> জন</span>
            </div>
            <div class="ma-bar-actions">
                <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>">
                    <input type="hidden" name="action" value="ma_acc_export">
                    <?php wp_nonce_field('ma_acc_export'); ?>
                    <button class="ma-btn ghost" type="submit">
                        <svg viewBox="0 0 24 24" width="17" height="17" aria-hidden="true"><path fill="currentColor" d="M12 3a1 1 0 0 1 1 1v8.6l2.3-2.3a1 1 0 1 1 1.4 1.4l-4 4a1 1 0 0 1-1.4 0l-4-4a1 1 0 1 1 1.4-1.4l2.3 2.3V4a1 1 0 0 1 1-1ZM5 17a1 1 0 0 1 1 1v1h12v-1a1 1 0 1 1 2 0v2a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1v-2a1 1 0 0 1 1-1Z"/></svg>
                        Excel-এ নামান
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
            <label class="ma-search">
                <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M10.5 3a7.5 7.5 0 0 1 5.9 12.1l4.3 4.2a1 1 0 0 1-1.4 1.4l-4.2-4.3A7.5 7.5 0 1 1 10.5 3Zm0 2a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11Z"/></svg>
                <input type="search" name="q" value="<?php echo esc_attr($v['q']); ?>" placeholder="নাম বা ইমেইল দিয়ে খুঁজুন">
            </label>
            <div class="ma-chips" role="tablist">
                <?php foreach ($filters as $key => $label) : ?>
                    <a class="ma-chip <?php echo $v['status'] === $key ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['status' => $key, 'q' => $v['q']]); ?>"><?php echo esc_html($label); ?></a>
                <?php endforeach; ?>
            </div>
        </form>

        <?php if (!$v['rows']) : ?>
            <div class="ma-empty">
                <div class="ma-empty-art" aria-hidden="true">
                    <svg viewBox="0 0 24 24" width="34" height="34"><path fill="currentColor" d="M9 4a4 4 0 1 1 0 8 4 4 0 0 1 0-8Zm0 2a2 2 0 1 0 0 4 2 2 0 0 0 0-4Zm7.5 1a3 3 0 1 1 0 6 3 3 0 0 1 0-6ZM9 13c3.3 0 6 1.6 6 4v2H3v-2c0-2.4 2.7-4 6-4Zm7.5 1c2.5 0 4.5 1.2 4.5 3v2h-4v-2c0-1.1-.4-2.1-1.1-2.9l.6-.1Z"/></svg>
                </div>
                <?php if ($v['q'] !== '' || $v['status'] !== '') : ?>
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
                            <th>অবস্থা</th>
                            <th class="hide-s">প্রো পর্যন্ত</th>
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
                            'kind' => $r['pro_kind'] === 'manual' ? 'হাতে দেওয়া' : ($r['pro_kind'] === 'trial' ? 'ট্রায়াল' : ($r['pro_kind'] !== '' ? 'Google Play' : '—')),
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
                            <td><span class="ma-pill <?php echo esc_attr($cls); ?>"><?php echo esc_html($label); ?></span></td>
                            <td class="hide-s muted"><?php echo esc_html(in_array($st, ['pro', 'trial', 'waiting'], true) ? $data['until'] : '—'); ?></td>
                            <td class="right">
                                <div class="ma-ops">
                                    <button type="button" class="ma-icon" title="বিস্তারিত" aria-label="বিস্তারিত: <?php echo esc_attr($data['name']); ?>" data-open="ma-view" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>">
                                        <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M12 5c5 0 8.6 4.3 9.7 6.4a1.3 1.3 0 0 1 0 1.2C20.6 14.7 17 19 12 19s-8.6-4.3-9.7-6.4a1.3 1.3 0 0 1 0-1.2C3.4 9.3 7 5 12 5Zm0 2c-3.6 0-6.4 3-7.6 5 1.2 2 4 5 7.6 5s6.4-3 7.6-5c-1.2-2-4-5-7.6-5Zm0 2a3 3 0 1 1 0 6 3 3 0 0 1 0-6Z"/></svg>
                                    </button>
                                    <button type="button" class="ma-icon" title="প্রো ও নোট" aria-label="প্রো ও নোট: <?php echo esc_attr($data['name']); ?>" data-open="ma-edit" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>">
                                        <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M15.6 3.6a2 2 0 0 1 2.8 0l2 2a2 2 0 0 1 0 2.8L9.2 19.6a2 2 0 0 1-1 .5l-3.9.9a1 1 0 0 1-1.2-1.2l.9-3.9c.1-.4.3-.7.5-1L15.6 3.6ZM17 5l-11 11-.5 2.5L8 18 19 7l-2-2Z"/></svg>
                                    </button>
                                    <button type="button" class="ma-icon danger" title="মুছুন" aria-label="মুছুন: <?php echo esc_attr($data['name']); ?>" data-open="ma-delete" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>">
                                        <svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M9 3h6a1 1 0 0 1 1 1v1h4a1 1 0 1 1 0 2h-1l-.9 12.1A2 2 0 0 1 16.1 21H7.9a2 2 0 0 1-2-1.9L5 7H4a1 1 0 0 1 0-2h4V4a1 1 0 0 1 1-1Zm-2 4 .9 12h8.2L17 7H7Zm3 2a1 1 0 0 1 1 1v6a1 1 0 1 1-2 0v-6a1 1 0 0 1 1-1Zm4 0a1 1 0 0 1 1 1v6a1 1 0 1 1-2 0v-6a1 1 0 0 1 1-1Z"/></svg>
                                    </button>
                                    <button type="button" class="ma-btn small <?php echo $data['pro'] ? 'soft' : ''; ?>" data-open="ma-edit" data-m="<?php echo esc_attr(wp_json_encode($data)); ?>"><?php echo $data['pro'] ? 'মেয়াদ বাড়ান' : 'প্রো দিন'; ?></button>
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
                        <?php if ($v['page'] > 1) : ?><a class="ma-btn ghost small" href="<?php echo ma_acc_url(['paged' => $v['page'] - 1, 'q' => $v['q'], 'status' => $v['status']]); ?>">← আগের</a><?php endif; ?>
                        <?php if ($v['page'] < $v['pages']) : ?><a class="ma-btn ghost small" href="<?php echo ma_acc_url(['paged' => $v['page'] + 1, 'q' => $v['q'], 'status' => $v['status']]); ?>">পরের →</a><?php endif; ?>
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
            <p class="muted">যেমন: কেউ ওয়েবসাইটে বিকাশে প্রো কিনেছেন। তাঁর Google ইমেইল দিন — অ্যাপে সেই ইমেইলে লগইন করলেই প্রো চালু হবে।</p>
            <label>Google ইমেইল<input type="email" name="email" required placeholder="name@gmail.com"></label>
            <label>নাম (ঐচ্ছিক)<input type="text" name="name"></label>
            <fieldset class="ma-days"><legend>প্রো কত দিনের</legend>
                <?php foreach ([0 => 'প্রো ছাড়া', 30 => '১ মাস', 365 => '১ বছর'] as $d => $l) : ?>
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
            <dt>প্রো পর্যন্ত</dt><dd data-f="until"></dd>
            <dt>কীভাবে</dt><dd data-f="kind"></dd>
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
            <h3>প্রো ও নোট</h3>
            <p class="muted"><span data-f="name"></span> · এখন: <strong data-f="status"></strong>, প্রো পর্যন্ত <span data-f="until"></span></p>
            <fieldset class="ma-days"><legend>প্রো যোগ করুন (চলমান মেয়াদের পরে যোগ হবে)</legend>
                <?php foreach ([0 => 'বদল নেই', 30 => '+১ মাস', 90 => '+৩ মাস', 365 => '+১ বছর'] as $d => $l) : ?>
                    <label><input type="radio" name="days" value="<?php echo (int) $d; ?>" <?php checked($d, 0); ?>><span><?php echo esc_html($l); ?></span></label>
                <?php endforeach; ?>
            </fieldset>
            <label class="ma-check"><input type="checkbox" name="mode" value="stop"> প্রো এখনই বন্ধ করুন</label>
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
            <p class="muted"><strong data-f="name"></strong> (<span data-f="email"></span>)-এর নাম, ইমেইল আর প্রো-র তথ্য মুছে যাবে। অ্যাপে তাঁর নিজের তথ্য যেমন আছে থাকবে।</p>
            <div class="ma-dialog-actions"><button type="button" class="ma-btn ghost" data-close>বাতিল</button><button class="ma-btn danger" type="submit">মুছুন</button></div>
        </form>
    </dialog>
    <?php
}

function ma_acc_render_settings($v) {
    $set = trim($v['clients']) !== '';
    ?>
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
            <p class="muted">Google অ্যাকাউন্টের নাম, ইমেইল, ছবির লিংক, কবে যোগ দিয়েছেন ও শেষ কবে খুলেছেন, অ্যাপের সংস্করণ, ট্রায়াল আর প্রো। এর বেশি কিছু না।</p>
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
    .ma label input[type=text],.ma label input[type=email]{height:42px;border:1px solid var(--line);border-radius:11px;padding:0 12px;font:inherit;font-weight:400;font-size:14px;color:var(--ink);box-shadow:none}
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
    @media (max-width:1100px){.ma .hide-m{display:none}}
    @media (max-width:900px){.ma-figures{grid-template-columns:repeat(2,minmax(0,1fr))}.ma-grid{grid-template-columns:1fr}.ma .hide-s{display:none}.ma-ops .ma-btn{display:none}}
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
                if (el.tagName === 'INPUT') { el.value = m[k] === undefined ? '' : String(m[k]); } else { el.textContent = val; }
            });
            var stop = dlg.querySelector('input[name=mode]'); if (stop) { stop.checked = false; }
            var none = dlg.querySelector('input[name=days][value="0"]'); if (none && dlg.id === 'ma-edit') { none.checked = true; }
        }
        document.addEventListener('click', function (e) {
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
            if (copy && navigator.clipboard) {
                navigator.clipboard.writeText(document.getElementById(copy.getAttribute('data-copy')).textContent);
                copy.title = 'কপি হয়েছে';
            }
        });
    })();
    </script>
    <?php
}
