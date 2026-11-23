<?php
/**
 * কোম্পানির পরিসংখ্যান as sections at the end of the dashboard (owner,
 * 24 Nov: no new menu; very clear — big numbers, simple charts, and under
 * each card what it means in plain words). Numbers from stats.php.
 */

if (!defined('ABSPATH')) {
    exit;
}

/** "১,২৪০" */
function ma_st_n($n) {
    return ma_acc_bn(number_format((float) $n, 0));
}

/** "৯৯.২%" / "৪৫%" */
function ma_st_p($p) {
    if ($p === null) {
        return '—';
    }
    $s = fmod((float) $p, 1.0) == 0.0 ? number_format((float) $p, 0) : number_format((float) $p, 1);
    return ma_acc_bn($s) . '%';
}

/** ▲ ১৮% / ▼ ২% (green up, red down), '' with nothing to compare. */
function ma_st_delta($ch, $suffix = '') {
    if ($ch === null) {
        return '';
    }
    if ($ch === 0) {
        return '<span class="ma-st-flat">আগের মতোই</span>' . ($suffix !== '' ? ' ' . esc_html($suffix) : '');
    }
    return '<span class="' . ($ch > 0 ? 'ma-st-up' : 'ma-st-down') . '">' . ($ch > 0 ? '▲ ' : '▼ ') . esc_html(ma_acc_bn(abs($ch))) . '%</span>' . ($suffix !== '' ? ' ' . esc_html($suffix) : '');
}

/** "১.৮ সেকেন্ড" from milliseconds. */
function ma_st_secs($ms) {
    if ($ms === null) {
        return '—';
    }
    return ma_acc_bn(number_format($ms / 1000, 1)) . ' সেকেন্ড';
}

function ma_st_ok() {
    return '<span class="ma-st-ok" title="এখনই সার্ভারে আছে">✓</span>';
}

function ma_st_soon($text = 'অ্যাপ আপডেটের পর') {
    return '<span class="ma-st-soon">' . esc_html($text) . '</span>';
}

function ma_st_mean($label, $text) {
    return '<p class="ma-st-mean"><b>' . esc_html($label) . ':</b> ' . esc_html($text) . '</p>';
}

function ma_st_empty($text) {
    return '<div class="ma-st-empty">' . esc_html($text) . '</div>';
}

/** Short Bangla date "২৩ নভে". */
function ma_st_short_day($ymd) {
    $m = ['জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন', 'জুলাই', 'আগস্ট', 'সেপ্টে', 'অক্টো', 'নভে', 'ডিসে'];
    return ma_acc_bn((int) substr($ymd, 8, 2)) . ' ' . $m[(int) substr($ymd, 5, 2) - 1];
}

/** People a day, as a line with the area under it. */
function ma_st_line_svg(array $series) {
    $vals = array_values($series);
    $days = array_keys($series);
    $n = count($vals);
    $W = 640;
    $H = 210;
    $L = 40;
    $B = 180;
    $T = 22;
    $mx = max(4, max($vals ?: [0]));
    $step = $mx <= 4 ? 1 : (int) pow(10, floor(log10($mx / 3))) * (int) ceil(($mx / 3) / pow(10, floor(log10($mx / 3))));
    $top = $step * (int) ceil($mx / $step);
    $y = fn($v) => $B - ($v / $top) * ($B - $T);
    $x = fn($i) => $n > 1 ? $L + $i * (($W - $L - 14) / ($n - 1)) : $L + ($W - $L) / 2;
    $g = '';
    for ($t = 0; $t <= $top; $t += $step) {
        $g .= '<line x1="' . $L . '" x2="' . $W . '" y1="' . round($y($t), 1) . '" y2="' . round($y($t), 1) . '" stroke="#EEF0F2"/>';
        $g .= '<text x="' . ($L - 8) . '" y="' . round($y($t) + 4, 1) . '" font-size="11" fill="#6B7280" text-anchor="end">' . esc_html(ma_acc_bn($t)) . '</text>';
    }
    $pts = [];
    foreach ($vals as $i => $v) {
        $pts[] = round($x($i), 1) . ',' . round($y($v), 1);
    }
    $p = implode(' ', $pts);
    $g .= '<polygon points="' . $L . ',' . $B . ' ' . $p . ' ' . round($x($n - 1), 1) . ',' . $B . '" fill="#0E7A5F" opacity=".10"/>';
    $g .= '<polyline points="' . $p . '" fill="none" stroke="#0E7A5F" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round"/>';
    foreach ($vals as $i => $v) {
        $g .= '<circle cx="' . round($x($i), 1) . '" cy="' . round($y($v), 1) . '" r="9" fill="transparent"><title>' . esc_html(ma_st_short_day($days[$i]) . ': ' . ma_acc_bn($v) . ' জন') . '</title></circle>';
    }
    $last = end($vals);
    $g .= '<circle cx="' . round($x($n - 1), 1) . '" cy="' . round($y($last), 1) . '" r="5" fill="#0E7A5F" stroke="#fff" stroke-width="2"/>';
    $g .= '<text x="' . round($x($n - 1) - 8, 1) . '" y="' . round($y($last) - 10, 1) . '" font-size="13" font-weight="700" fill="#0A5C47" text-anchor="end">আজ ' . esc_html(ma_acc_bn($last)) . '</text>';
    $ticks = $n <= 7 ? range(0, $n - 1) : array_unique([0, (int) round(($n - 1) / 4), (int) round(($n - 1) / 2), (int) round(3 * ($n - 1) / 4), $n - 1]);
    foreach ($ticks as $k => $i) {
        $anchor = $i === $n - 1 ? 'end' : ($i === 0 ? 'start' : 'middle');
        $g .= '<text x="' . round($x($i), 1) . '" y="' . ($B + 20) . '" font-size="11.5" fill="#6B7280" text-anchor="' . $anchor . '">' . esc_html(ma_st_short_day($days[$i])) . '</text>';
    }
    return '<svg class="ma-st-svg" viewBox="0 0 ' . $W . ' ' . $H . '" role="img" aria-label="প্রতিদিন কতজন অ্যাপ খুলেছেন">' . $g . '</svg>';
}

/** Money a month, stacked by where it came from. */
function ma_st_rev_svg(array $months) {
    $colors = ['web' => '#0E7A5F', 'play' => '#2563EB', 'ads' => '#D97706', 'other' => '#9CA3AF'];
    $W = 640;
    $L = 52;
    $B = 196;
    $T = 22;
    $tot = array_map('array_sum', $months);
    $mx = max(1000, max($tot ?: [0]));
    $mag = pow(10, floor(log10($mx / 3)));
    $step = $mag * ceil(($mx / 3) / $mag);
    $top = $step * ceil($mx / $step);
    $y = fn($v) => $B - ($v / $top) * ($B - $T);
    $gap = ($W - $L - 10) / max(1, count($months));
    $bw = min(64, $gap * 0.6);
    $short = function ($v) {
        if ($v >= 100000) {
            return '৳' . ma_acc_bn(number_format($v / 100000, 1)) . ' লাখ';
        }
        if ($v >= 1000) {
            return '৳' . ma_acc_bn(number_format($v / 1000, $v >= 10000 ? 0 : 1)) . ' হা.';
        }
        return '৳' . ma_acc_bn($v);
    };
    $g = '';
    for ($t = 0; $t <= $top; $t += $step) {
        $g .= '<line x1="' . $L . '" x2="' . $W . '" y1="' . round($y($t), 1) . '" y2="' . round($y($t), 1) . '" stroke="#EEF0F2"/>';
        $g .= '<text x="' . ($L - 8) . '" y="' . round($y($t) + 4, 1) . '" font-size="11" fill="#6B7280" text-anchor="end">' . esc_html($t ? $short($t) : '০') . '</text>';
    }
    $i = 0;
    foreach ($months as $m => $parts) {
        $x = $L + $i * $gap + ($gap - $bw) / 2;
        $acc = 0;
        $tip = ma_acc_month_name($m) . ': ৳' . ma_st_n(array_sum($parts));
        foreach ($colors as $k => $c) {
            $v = (int) ($parts[$k] ?? 0);
            if ($v <= 0) {
                continue;
            }
            $y0 = $y($acc);
            $y1 = $y($acc + $v);
            $g .= '<rect x="' . round($x, 1) . '" y="' . round($y1, 1) . '" width="' . round($bw, 1) . '" height="' . max(1, round($y0 - $y1 - 1, 1)) . '" fill="' . $c . '"><title>' . esc_html($tip) . '</title></rect>';
            $acc += $v;
        }
        if ($acc > 0) {
            $g .= '<text x="' . round($x + $bw / 2, 1) . '" y="' . round($y($acc) - 7, 1) . '" font-size="12" font-weight="700" fill="#111827" text-anchor="middle">' . esc_html($short($acc)) . '</text>';
        }
        $g .= '<text x="' . round($x + $bw / 2, 1) . '" y="' . ($B + 18) . '" font-size="12" fill="#6B7280" text-anchor="middle">' . esc_html(explode(' ', ma_acc_month_name($m))[0]) . '</text>';
        $i++;
    }
    return '<svg class="ma-st-svg" viewBox="0 0 ' . $W . ' 220" role="img" aria-label="মাস অনুযায়ী আয়">' . $g . '</svg>';
}

/** A labelled bar: label, bar, value. */
function ma_st_hbar($label, $pct, $value, $color = '') {
    $w = max(0, min(100, (float) $pct));
    return '<div class="ma-st-hb"><span>' . esc_html($label) . '</span><span class="t"><i style="width:' . $w . '%' . ($color !== '' ? ';background:' . esc_attr($color) : '') . '"></i></span><span class="v">' . esc_html($value) . '</span></div>';
}

/** The plain-words summary at the top: only what the numbers really say. */
function ma_st_story($s) {
    $out = [];
    if ($s['dau_avg'] > 0) {
        $out[] = 'প্রতিদিন গড়ে <b>' . esc_html(ma_st_n($s['dau_avg'])) . ' জন</b> অ্যাপ খোলেন' . ($s['mins_avg'] > 0 ? ', প্রত্যেকে গড়ে <b>' . esc_html(ma_acc_bn($s['mins_avg'])) . ' মিনিট</b> চালান' : '') . '।';
    }
    $f = $s['funnel'];
    if ($f['signed'] > 0) {
        $line = 'নতুন এসেছেন <b>' . esc_html(ma_st_n($f['signed'])) . ' জন</b>।';
        if ($f['week_can'] > 0 && $f['week'] > 0) {
            $line .= ' এদের <b>' . esc_html(ma_st_n($f['week'])) . ' জন</b> এক সপ্তাহ পরেও অ্যাপ খুলছেন।';
        }
        $out[] = $line;
    }
    if ($s['trial_ended'] > 0) {
        $p = ma_st_pct($s['trial_paid'], $s['trial_ended']);
        $out[] = 'ট্রায়াল শেষ করা <b>১০০ জনে ' . esc_html(ma_acc_bn((int) round($p))) . ' জন</b> প্রিমিয়াম কিনেছেন' . ($s['plans']['yearly'] + $s['plans']['monthly'] > 0 ? '। ' . ($s['plans']['yearly'] >= $s['plans']['monthly'] ? 'বার্ষিক' : 'মাসিক') . ' প্ল্যান বেশি চলছে।' : '।');
    }
    if ($s['crash_free'] !== null) {
        $worst = '';
        $wc = 0;
        foreach ($s['versions'] as $v => $r) {
            if ($r['crash'] > $wc && $v !== '') {
                $wc = $r['crash'];
                $worst = $v;
            }
        }
        $out[] = 'অ্যাপ ক্র্যাশ ছাড়া চলেছে <b>' . esc_html(ma_st_p($s['crash_free'])) . '</b> জনের ফোনে।' . ($worst !== '' ? ' সবচেয়ে বেশি ক্র্যাশ <b>' . esc_html(ma_acc_bn($worst)) . '</b> ভার্সনে।' : '');
    }
    return $out;
}

function ma_ui_render_stats($v) {
    $s = $v['home']['stats'] ?? null;
    if (!$s) {
        return;
    }
    $period = ['7' => '৭ দিন', '30' => '৩০ দিন', '90' => '৯০ দিন'];
    $dn = ma_acc_bn($s['days']);
    $f = $s['funnel'];
    $ret = $s['retention'];
    $since = $s['use_since'] !== '' ? ma_st_short_day($s['use_since']) : '';
    ?>
    <section class="ma-st" id="ma-stats">
        <div class="ma-st-headline">
            <div><h2 class="ma-st-h">কোম্পানির পরিসংখ্যান</h2><p class="ma-sub">অ্যাপ কতজন চালায়, কতদিন থাকে, কত আয়, অ্যাপ কতটা ঠিক চলে — গত <?php echo esc_html($dn); ?> দিনের, আগের <?php echo esc_html($dn); ?> দিনের সাথে তুলনা</p></div>
            <nav class="ma-st-seg" aria-label="কত দিনের">
                <?php foreach ($period as $k => $label) : ?>
                    <a class="<?php echo (int) $k === $s['days'] ? 'on' : ''; ?>" href="<?php echo ma_acc_url(['tab' => 'home', 'sp' => $k]); ?>#ma-stats"><?php echo esc_html($label); ?></a>
                <?php endforeach; ?>
            </nav>
        </div>
        <div class="ma-st-legend">
            <span><?php echo ma_st_ok(); ?> এখনই সার্ভারে আছে</span>
            <span><?php echo ma_st_soon(); ?> নতুন অ্যাপ বের হওয়ার পর থেকে জমা হবে</span>
        </div>

        <div class="ma-st-big">
            <div><span>আজ অ্যাপ খুলেছেন</span><strong><?php echo esc_html(ma_st_n($s['today_n'])); ?> জন</strong><em><?php echo ma_st_delta(ma_st_change($s['today_n'], $s['week_ago_n']), 'গত সপ্তাহের এই দিনের চেয়ে') ?: 'আজ যতজন খুলেছেন'; ?></em></div>
            <div><span><?php echo esc_html($dn); ?> দিনে অ্যাপ চালিয়েছেন</span><strong><?php echo esc_html(ma_st_n($s['active'])); ?> জন</strong><em>মোট সদস্যের <?php echo esc_html(ma_st_p(ma_st_pct($s['active'], $s['members']))); ?> <?php echo ma_st_delta(ma_st_change($s['active'], $s['active_prev'])); ?></em></div>
            <div><span>৩০ দিন পরেও আছেন</span><strong><?php echo esc_html(ma_st_p($ret[30]['pct'])); ?></strong><em><?php echo $ret[30]['pct'] !== null ? esc_html('নতুনদের ১০০ জনে ' . ma_acc_bn((int) round($ret[30]['pct'])) . ' জন') : 'তথ্য জমছে — ৩০ দিন পুরো হলে দেখা যাবে'; ?></em></div>
            <div><span>এ মাসের আয়</span><strong>৳<?php echo esc_html(ma_st_n($s['rev_month'])); ?></strong><em>ওয়েবসাইট + Google Play + বিজ্ঞাপন <?php echo ma_st_delta(ma_st_change($s['rev_month'], $s['rev_prev'])); ?></em></div>
        </div>

        <?php $story = ma_st_story($s); if ($story) : ?>
            <div class="ma-st-story"><h3>এক কথায়, গত <?php echo esc_html($dn); ?> দিন</h3><ul><?php foreach ($story as $line) : ?><li><?php echo $line; // built from escaped parts ?></li><?php endforeach; ?></ul></div>
        <?php endif; ?>

        <!-- ১ -->
        <div class="ma-st-sec"><span class="n">১</span><div><h3>কতজন অ্যাপ চালান</h3><p>প্রতিদিন কতজন খোলেন আর কতক্ষণ থাকেন</p></div></div>
        <div class="ma-st-row r2">
            <div class="ma-st-card">
                <div class="ma-st-ch"><h4>প্রতিদিন কতজন অ্যাপ খুলেছেন <?php echo ma_st_ok(); ?></h4><span class="muted">গড় <?php echo esc_html(ma_st_n($s['dau_avg'])); ?> জন/দিন</span></div>
                <?php echo array_sum($s['dau']) > 0 ? ma_st_line_svg($s['dau']) : ma_st_empty('এই কয় দিনে এখনো কারও হিসাব আসেনি।'); ?>
                <?php echo ma_st_mean('এর মানে', 'রেখা ওপরে উঠলে বেশি মানুষ রোজ অ্যাপ খুলছেন। রেখার ওপর মাউস রাখলে সেদিনের সংখ্যা দেখায়।' . ($since !== '' ? ' এই হিসাব ' . $since . ' থেকে জমছে।' : '')); ?>
            </div>
            <div class="ma-st-card">
                <h4>একজন দিনে কতক্ষণ চালান <?php echo ma_st_ok(); ?></h4>
                <div class="ma-st-figure"><strong><?php echo esc_html(ma_acc_bn($s['mins_avg'])); ?> মিনিট</strong><?php if ($s['mins_prev'] > 0 && $s['mins_avg'] !== $s['mins_prev']) : $dm = $s['mins_avg'] - $s['mins_prev']; ?><span class="muted"><span class="<?php echo $dm > 0 ? 'ma-st-up' : 'ma-st-down'; ?>"><?php echo $dm > 0 ? '▲' : '▼'; ?> <?php echo esc_html(ma_acc_bn(abs($dm))); ?> মিনিট</span> আগের <?php echo esc_html($dn); ?> দিনের চেয়ে</span><?php endif; ?></div>
                <?php if ($s['mins_split']) : [$a, $b, $c] = $s['mins_split']; ?>
                    <?php echo ma_st_hbar('৫ মিনিটের কম', $a, ma_st_p($a)) . ma_st_hbar('৫–২০ মিনিট', $b, ma_st_p($b)) . ma_st_hbar('২০ মিনিটের বেশি', $c, ma_st_p($c)); ?>
                <?php endif; ?>
                <?php echo ma_st_mean('এর মানে', 'যেদিন অ্যাপ খুলেছেন, সেদিন কতক্ষণ কেটেছে। বেশি সময় মানে অ্যাপ কাজে লাগছে।'); ?>
            </div>
        </div>
        <div class="ma-st-row r2">
            <div class="ma-st-card">
                <div class="ma-st-ch"><h4>কোন অংশ কতজন খুলেছেন</h4><?php echo $s['parts_people'] ? ma_st_ok() : ma_st_soon(); ?></div>
                <?php if ($s['parts']) : ?>
                    <div class="ma-st-parts"><?php foreach ($s['parts'] as $p) { echo ma_st_hbar($p['label'], $p['pct'], ma_st_p($p['pct'])); } ?></div>
                <?php else : echo ma_st_empty('নতুন অ্যাপ বের হলে এখানে দেখাবে — হিসাব, ওষুধ, নামাজ, ব্যবসা… কোনটা কতজন খোলেন।'); endif; ?>
                <?php echo ma_st_mean('এর মানে', 'যারা হিসাব পাঠিয়েছেন (' . ma_st_n($s['parts_people']) . ' জন), তাদের ১০০ জনে কতজন এই অংশ অন্তত একবার খুলেছেন। কে কী লিখেছেন তা আসে না, শুধু “খুলেছেন” গোনা হয়।'); ?>
            </div>
            <div class="ma-st-card">
                <h4>নতুনরা কতদিন থাকেন <?php echo ma_st_ok(); ?></h4>
                <div class="ma-st-ret">
                    <?php foreach ([1 => 'পরের দিন ফিরেছেন', 7 => '৭ দিন পরেও আছেন', 30 => '৩০ দিন পরেও আছেন'] as $k => $label) : $r = $ret[$k]; ?>
                        <div><strong><?php echo esc_html(ma_st_p($r['pct'])); ?></strong><span><?php echo esc_html($label); ?></span><em><?php echo $r['pct'] !== null ? esc_html(ma_st_n($r['n']) . ' জনের ' . ma_st_n($r['back']) . ' জন') : 'তথ্য জমছে'; ?></em></div>
                    <?php endforeach; ?>
                </div>
                <?php echo ma_st_mean('এর মানে', '১০০ জন নতুন এলে কতজন পরেও অ্যাপ চালাচ্ছেন। এই সংখ্যা বাড়লে অ্যাপ মানুষের অভ্যাসে ঢুকছে।'); ?>
            </div>
        </div>

        <!-- ২ -->
        <div class="ma-st-sec"><span class="n">২</span><div><h3>নতুনরা কোথায় আটকে যান</h3><p>অ্যাপ খোলা থেকে প্রিমিয়াম পর্যন্ত, গত <?php echo esc_html($dn); ?> দিনে কতজন কোন ধাপে পৌঁছেছেন</p></div></div>
        <div class="ma-st-card ma-st-funnel">
            <?php
            // First opens are counted only by the new app: until they outnumber
            // the sign-ins, the path starts at signing in.
            $fo = $f['first_open'] >= $f['signed'] && $f['first_open'] > 0 ? $f['first_open'] : null;
            $top = max(1, $fo ?? $f['signed']);
            $steps = [
                ['অ্যাপ প্রথম খুলেছেন', $fo === null && $f['first_open'] > 0 ? 'গোনা শুরু হয়েছে (' . ma_st_n($f['first_open']) . ' জন), নতুন অ্যাপ সবার কাছে গেলে দেখাবে' : 'নতুন ইনস্টল', $fo, true],
                ['সাইন-ইন করেছেন', 'Google দিয়ে', $f['signed'], false],
                ['প্রথম কিছু রেখেছেন', 'কাজ, হিসাব, নোট, ওষুধ…', $f['told'] ? $f['items'] : null, true],
                ['৭ দিন পরেও আছেন', $f['week_can'] < $f['signed'] ? 'যারা ৭ দিন আগে এসেছেন' : '', $f['week'], false],
                ['প্রিমিয়াম কিনেছেন', 'ট্রায়ালের পর টাকা দিয়ে', $f['paid'], false],
            ];
            $prev = null;
            foreach ($steps as [$label, $sub, $val, $needs_app]) :
                ?>
                <div class="ma-st-step">
                    <div class="lab"><?php echo esc_html($label); ?><?php if ($sub !== '') : ?><small><?php echo esc_html($sub); ?></small><?php endif; ?></div>
                    <div>
                        <?php if ($val === null) : ?>
                            <?php echo ma_st_soon(); ?>
                        <?php else : $w = max(3, round($val * 100 / $top)); ?>
                            <div class="bar<?php echo $label === 'প্রিমিয়াম কিনেছেন' ? ' dark' : ''; ?>" style="width:<?php echo (float) $w; ?>%"><?php echo esc_html(ma_st_n($val) . ' জন' . ($top > 0 && $val !== $top ? ' · ' . ma_st_p(ma_st_pct($val, $top)) : '')); ?></div>
                        <?php endif; ?>
                    </div>
                    <div class="drop"><?php echo $val !== null && $prev !== null && $prev > $val ? esc_html(ma_st_n($prev - $val) . ' জন থেমে গেছেন') : ''; ?></div>
                </div>
                <?php
                if ($val !== null) {
                    $prev = $val;
                }
            endforeach;
            ?>
            <?php echo ma_st_mean('এর মানে', 'লাল লেখা যে ধাপে সবচেয়ে বড়, সেখানেই সবচেয়ে বেশি মানুষ থেমে যাচ্ছেন — ওই জায়গাটা সহজ করলে সবচেয়ে বেশি লাভ।'); ?>
        </div>

        <!-- ৩ -->
        <div class="ma-st-sec"><span class="n">৩</span><div><h3>আয়</h3><p>কোথা থেকে কত টাকা আসছে, কোন প্ল্যান বেশি চলে</p></div></div>
        <div class="ma-st-row r2">
            <div class="ma-st-card">
                <div class="ma-st-ch"><h4>মাস অনুযায়ী আয় <?php echo ma_st_ok(); ?></h4><span class="muted">গত ৬ মাস</span></div>
                <?php echo array_sum(array_map('array_sum', $s['revenue'])) > 0 ? ma_st_rev_svg($s['revenue']) : ma_st_empty('গত ৬ মাসে কোনো আয় লেখা নেই।'); ?>
                <div class="ma-st-lg"><span><i style="background:#0E7A5F"></i>ওয়েবসাইট (বিকাশ)</span><span><i style="background:#2563EB"></i>Google Play</span><span><i style="background:#D97706"></i>বিজ্ঞাপন</span><span><i style="background:#9CA3AF"></i>অন্যান্য</span></div>
                <?php echo ma_st_mean('এর মানে', 'প্রতিটা দাগ এক মাসের মোট আয়। ওয়েবসাইটের টাকা অনুমোদিত পেমেন্ট থেকে; Google Play আর বিজ্ঞাপনের টাকা “আয়-ব্যয়ের হিসাব”-এ যা লেখা হয়েছে সেখান থেকে।'); ?>
            </div>
            <div class="ma-st-card">
                <h4>ট্রায়াল থেকে প্রিমিয়াম <?php echo ma_st_ok(); ?></h4>
                <div class="ma-st-figure"><strong><?php echo esc_html(ma_st_p(ma_st_pct($s['trial_paid'], $s['trial_ended']))); ?></strong><span class="muted"><?php echo esc_html('ট্রায়াল শেষ করা ' . ma_st_n($s['trial_ended']) . ' জনের ' . ma_st_n($s['trial_paid']) . ' জন কিনেছেন'); ?></span></div>
                <h4 style="margin-top:16px">এখন প্রিমিয়াম কারা <?php echo ma_st_ok(); ?></h4>
                <?php
                $pl = $s['plans'];
                $pf = $s['pro_from'];
                $pn = max(1, array_sum($pf));
                echo ma_st_hbar('বার্ষিক প্ল্যান', $pl['yearly'] * 100 / $pn, ma_st_n($pl['yearly']) . ' জন');
                echo ma_st_hbar('মাসিক প্ল্যান', $pl['monthly'] * 100 / $pn, ma_st_n($pl['monthly']) . ' জন', '#2563EB');
                echo ma_st_hbar('ওয়েবসাইট থেকে', $pf['web'] * 100 / $pn, ma_st_n($pf['web']) . ' জন');
                echo ma_st_hbar('Google Play থেকে', $pf['play'] * 100 / $pn, ma_st_n($pf['play']) . ' জন', '#2563EB');
                if ($pf['manual']) {
                    echo ma_st_hbar('অ্যাডমিন দিয়েছেন', $pf['manual'] * 100 / $pn, ma_st_n($pf['manual']) . ' জন', '#9CA3AF');
                }
                ?>
                <?php echo ma_st_mean('এর মানে', 'যাদের প্রিমিয়াম এখন চালু, তারা কোন প্ল্যানে আর কোথা থেকে কিনেছেন। ট্রায়াল এখানে ধরা হয়নি।'); ?>
            </div>
        </div>

        <!-- ৪ -->
        <div class="ma-st-sec"><span class="n">৪</span><div><h3>অ্যাপ কতটা ঠিক চলে</h3><p>ক্র্যাশ, অ্যাপ খুলতে কত সময়, সার্ভার কত দ্রুত উত্তর দেয়</p></div></div>
        <div class="ma-st-row r3">
            <div class="ma-st-card">
                <?php $cf = $s['crash_free']; ?>
                <div class="ma-st-ch"><h4>ক্র্যাশ ছাড়া চলেছে <?php echo ma_st_ok(); ?></h4><?php if ($cf !== null) : ?><span class="ma-st-pill <?php echo $cf >= 99 ? 'good' : 'warn'; ?>"><?php echo $cf >= 99 ? 'ভালো' : 'নজর দিন'; ?></span><?php endif; ?></div>
                <div class="ma-st-figure"><strong><?php echo esc_html(ma_st_p($cf)); ?></strong><span class="muted"><?php echo esc_html($s['crash_people'] ? ma_st_n($s['crash_people']) . ' জনের ফোনে অন্তত একবার ক্র্যাশ হয়েছে' : 'কারও ফোনে ক্র্যাশ হয়নি'); ?></span></div>
                <?php echo ma_st_mean('লক্ষ্য', '৯৯% এর ওপরে থাকলে ভালো। কোন ক্র্যাশ কতবার — “সমস্যার লগ”-এ।'); ?>
            </div>
            <div class="ma-st-card">
                <?php $sm = $s['start_med']; ?>
                <div class="ma-st-ch"><h4>অ্যাপ খুলতে সময়</h4><?php echo $sm === null ? ma_st_soon() : '<span class="ma-st-pill ' . ($sm <= 2000 ? 'good">ভালো' : 'warn">নজর দিন') . '</span>'; ?></div>
                <div class="ma-st-figure"><strong><?php echo esc_html(ma_st_secs($sm)); ?></strong><span class="muted"><?php echo $sm === null ? 'নতুন অ্যাপ থেকে আসবে' : 'অর্ধেক মানুষের এর চেয়ে কম লাগে'; ?></span></div>
                <?php echo ma_st_mean('লক্ষ্য', '২ সেকেন্ডের কম।'); ?>
            </div>
            <div class="ma-st-card">
                <?php $sv = $s['server_ms']; ?>
                <div class="ma-st-ch"><h4>সার্ভারের উত্তর <?php echo $sv !== null ? ma_st_ok() : ''; ?></h4><?php if ($sv !== null) : ?><span class="ma-st-pill <?php echo $sv <= 800 ? 'good' : 'warn'; ?>"><?php echo $sv <= 800 ? 'ভালো' : 'নজর দিন'; ?></span><?php endif; ?></div>
                <div class="ma-st-figure"><strong><?php echo esc_html(ma_st_secs($sv)); ?></strong><span class="muted"><?php echo $sv === null ? 'এই প্লাগিন বসানোর পর থেকে মাপা হবে' : 'লগইন, প্রিমিয়াম দেখা আর বাকি সবের গড়'; ?></span></div>
                <?php if (!empty($s['server']['ai'])) : ?><p class="ma-st-note">AI-এর উত্তরে গড়ে <?php echo esc_html(ma_st_secs($s['server']['ai']['ms'])); ?> লাগে (AI নিজে ভাবতে সময় নেয়, তাই আলাদা)।</p><?php endif; ?>
                <?php echo ma_st_mean('লক্ষ্য', '০.৮ সেকেন্ডের কম। বেশি হলে হোস্টিং দেখা দরকার।'); ?>
            </div>
        </div>
        <div class="ma-st-row r11">
            <div class="ma-st-card">
                <div class="ma-st-ch"><h4>ভার্সন অনুযায়ী <?php echo ma_st_ok(); ?></h4><span class="muted">কোন ভার্সন কতজনের ফোনে, কত ক্র্যাশ</span></div>
                <?php if ($s['versions']) : ?>
                    <table class="ma-st-table"><thead><tr><th>ভার্সন</th><th class="r">কতজনের ফোনে</th><th class="r">ক্র্যাশ</th><th class="r">অবস্থা</th></tr></thead><tbody>
                    <?php $i = 0; foreach ($s['versions'] as $ver => $r) : if (++$i > 6) { break; } $bad = $r['n'] > 0 ? $r['crash'] / $r['n'] > 0.05 : $r['crash'] > 0; ?>
                        <tr><td><b><?php echo esc_html($ver !== '' ? ma_acc_bn($ver) : 'জানা নেই'); ?></b><?php echo $i === 1 && $ver !== '' ? ' <span class="muted">নতুন</span>' : ''; ?></td><td class="r"><?php echo esc_html(ma_st_n($r['n']) . ' জন' . ($s['seen'] ? ' · ' . ma_st_p(ma_st_pct($r['n'], $s['seen'])) : '')); ?></td><td class="r"><?php echo esc_html(ma_st_n($r['crash'])); ?></td><td class="r"><span class="ma-st-pill <?php echo $bad ? 'warn' : 'good'; ?>"><?php echo $bad ? 'নজর দিন' : 'ভালো'; ?></span></td></tr>
                    <?php endforeach; ?>
                    </tbody></table>
                <?php else : echo ma_st_empty('এই কয় দিনে কেউ অ্যাপ খোলেননি।'); endif; ?>
                <?php echo ma_st_mean('এর মানে', 'পুরোনো ভার্সনে বেশি ক্র্যাশ হলে “নোটিফিকেশন” থেকে সবাইকে আপডেট করতে বলা যায়।'); ?>
            </div>
            <div class="ma-st-card">
                <div class="ma-st-ch"><h4>ফোন ও Android অনুযায়ী</h4><?php echo $s['dev_n'] ? ma_st_ok() : ma_st_soon(); ?></div>
                <?php if ($s['dev_n']) : ?>
                    <table class="ma-st-table"><thead><tr><th>ফোন</th><th class="r">কতজন</th><th class="r">খুলতে সময়</th></tr></thead><tbody>
                    <?php foreach ($s['brands'] as $b) : ?>
                        <tr><td><?php echo esc_html($b['label']); ?></td><td class="r"><?php echo esc_html(ma_st_p(ma_st_pct($b['n'], $s['dev_n']))); ?></td><td class="r"><?php echo esc_html($b['ms'] !== null ? ma_acc_bn(number_format($b['ms'] / 1000, 1)) . ' সে.' : '—'); ?></td></tr>
                    <?php endforeach; ?>
                    <?php foreach ($s['android'] as $b) : ?>
                        <tr class="ma-st-andr"><td><?php echo esc_html($b['label']); ?></td><td class="r"><?php echo esc_html(ma_st_p(ma_st_pct($b['n'], $s['dev_n']))); ?></td><td class="r"><?php echo esc_html($b['ms'] !== null ? ma_acc_bn(number_format($b['ms'] / 1000, 1)) . ' সে.' : '—'); ?></td></tr>
                    <?php endforeach; ?>
                    </tbody></table>
                <?php else : echo ma_st_empty('নতুন অ্যাপ বের হলে এখানে দেখাবে কোন কোম্পানির ফোন আর কোন Android-এ অ্যাপ কত দ্রুত খোলে।'); endif; ?>
                <?php echo ma_st_mean('এর মানে', 'কোন ব্র্যান্ড বা পুরোনো Android-এ অ্যাপ ধীর, তা বোঝা যায়। শুধু ফোনের কোম্পানির নাম আসে, মডেল বা কারও ফোন চেনা যায় না।'); ?>
            </div>
        </div>

        <!-- ৫ -->
        <div class="ma-st-sec"><span class="n">৫</span><div><h3>কোথায় ও কোন ভাষায়</h3><p>দেশ, ভাষা আর ব্যবসায়ী মোড — গত <?php echo esc_html($dn); ?> দিনে যারা অ্যাপ খুলেছেন</p></div></div>
        <div class="ma-st-row r11">
            <div class="ma-st-card">
                <div class="ma-st-ch"><h4>দেশ অনুযায়ী</h4><?php echo $s['dev_n'] ? ma_st_ok() : ma_st_soon(); ?></div>
                <?php if ($s['dev_n']) {
                    $i = 0;
                    $rest = 0;
                    foreach ($s['countries'] as $c => $cn) {
                        if (++$i <= 5) {
                            echo ma_st_hbar($c, $cn * 100 / $s['dev_n'], ma_st_p(ma_st_pct($cn, $s['dev_n'])));
                        } else {
                            $rest += $cn;
                        }
                    }
                    if ($rest) {
                        echo ma_st_hbar('অন্যান্য', $rest * 100 / $s['dev_n'], ma_st_p(ma_st_pct($rest, $s['dev_n'])), '#9CA3AF');
                    }
                } else {
                    echo ma_st_empty('নতুন অ্যাপ বের হলে দেখাবে।');
                } ?>
                <?php echo ma_st_mean('এর মানে', 'শুধু দেশ, ফোনের মোবাইল নেটওয়ার্ক থেকে। কারও অবস্থান (লোকেশন) নেওয়া হয় না।'); ?>
            </div>
            <div class="ma-st-card">
                <div class="ma-st-ch"><h4>অ্যাপের ভাষা</h4><?php echo $s['dev_n'] ? ma_st_ok() : ma_st_soon(); ?></div>
                <?php $ln = $s['lang']['bn'] + $s['lang']['en']; if ($ln) : $bp = (int) round($s['lang']['bn'] * 100 / $ln); ?>
                    <div class="ma-st-split"><div style="width:<?php echo max(12, $bp); ?>%;background:#0E7A5F">বাংলা <?php echo esc_html(ma_st_p($bp)); ?></div><?php if ($bp < 100) : ?><div style="width:<?php echo max(18, 100 - $bp); ?>%;background:#2563EB">English <?php echo esc_html(ma_st_p(100 - $bp)); ?></div><?php endif; ?></div>
                <?php else : echo ma_st_empty('নতুন অ্যাপ বের হলে দেখাবে।'); endif; ?>
                <h4 style="margin-top:16px">ব্যবসায়ী মোড চালু করেছেন</h4>
                <?php if ($s['dev_n']) : $bz = (int) round($s['biz'] * 100 / $s['dev_n']); ?>
                    <div class="ma-st-split"><?php if ($bz > 0) : ?><div style="width:<?php echo max(12, $bz); ?>%;background:#D97706"><?php echo esc_html(ma_st_p($bz)); ?></div><?php endif; ?><div style="flex:1;background:#E5E7EB;color:#374151">শুধু ব্যক্তিগত <?php echo esc_html(ma_st_p(100 - $bz)); ?></div></div>
                <?php else : echo ma_st_empty('নতুন অ্যাপ বের হলে দেখাবে।'); endif; ?>
                <?php echo ma_st_mean('এর মানে', 'কতজন ইংরেজিতে চালান আর কতজন দোকান বা ব্যবসার হিসাব রাখেন।'); ?>
            </div>
        </div>
        <div class="ma-st-foot"><?php echo ma_st_ok(); ?> এখানে কারও নাম, লেখা, টাকার অঙ্ক, স্বাস্থ্য, পাসওয়ার্ড বা কন্ট্যাক্ট নেই — শুধু মোট সংখ্যা। কেউ অ্যাপের সেটিংসে “ব্যবহারের হিসাব পাঠান” বন্ধ করলে তার কিছুই আসে না।</div>
    </section>
    <?php
}

function ma_st_styles() {
    ?>
    <style>
    .ma-st{margin-top:30px;border-top:1px solid var(--line);padding-top:22px}
    .ma-st-headline{display:flex;justify-content:space-between;align-items:flex-start;gap:16px;flex-wrap:wrap}
    .ma .ma-st-h{font-size:22px;font-weight:700;margin:0;line-height:1.3;color:var(--ink)}
    .ma-st-seg{display:flex;gap:4px;background:#fff;border:1px solid var(--line);padding:4px;border-radius:12px}
    .ma-st-seg a{font-weight:600;font-size:13.5px;padding:6px 14px;border-radius:9px;color:var(--mut2);text-decoration:none}
    .ma-st-seg a.on{background:var(--ink);color:#fff}
    .ma-st-legend{display:flex;gap:18px;flex-wrap:wrap;align-items:center;background:#fff;border:1px solid var(--line);border-radius:12px;padding:9px 14px;margin-top:12px;font-size:13.5px;color:var(--mut2)}
    .ma-st-legend span{display:inline-flex;gap:7px;align-items:center}
    .ma-st-ok{display:inline-grid;place-items:center;width:18px;height:18px;border-radius:99px;background:var(--gt);color:var(--g);font-size:11px;font-weight:700;vertical-align:1px}
    .ma-st-soon{display:inline-flex;font-size:11.5px;font-weight:600;background:var(--amt);color:var(--amber);border-radius:99px;padding:1px 9px;white-space:nowrap}
    .ma-st-big{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin-top:12px}
    .ma-st-big>div{background:#fff;border:1px solid var(--line);border-radius:16px;padding:16px 18px;display:flex;flex-direction:column;gap:2px;min-width:0}
    .ma-st-big span{font-size:13.5px;color:var(--mut);font-weight:600}
    .ma-st-big strong{font-size:32px;font-weight:700;line-height:1.2}
    .ma-st-big em{font-style:normal;font-size:13px;color:var(--mut)}
    .ma-st-up{color:#047857;font-weight:700}.ma-st-down{color:var(--rose);font-weight:700}.ma-st-flat{color:var(--mut2);font-weight:600}
    .ma-st-story{background:var(--gt);border-radius:16px;padding:14px 20px;margin-top:12px;color:#064E3B;font-size:15px;line-height:1.75}
    .ma-st-story h3{margin:0 0 4px;font-size:15px;color:var(--gd)}
    .ma-st-story ul{margin:0;padding-left:20px;list-style:disc}
    .ma-st-sec{display:flex;align-items:center;gap:10px;margin:26px 0 0}
    .ma-st-sec .n{width:30px;height:30px;border-radius:9px;background:var(--g);color:#fff;display:grid;place-items:center;font-weight:700;flex:none}
    .ma-st-sec h3{font-size:19px;margin:0;line-height:1.3}
    .ma-st-sec p{margin:0;color:var(--mut);font-size:13.5px}
    .ma-st-row{display:grid;gap:14px;margin-top:12px}
    .ma-st-row.r2{grid-template-columns:1.55fr 1fr}.ma-st-row.r3{grid-template-columns:repeat(3,minmax(0,1fr))}.ma-st-row.r11{grid-template-columns:1fr 1fr}
    .ma-st-card{background:#fff;border:1px solid var(--line);border-radius:18px;padding:18px 20px;min-width:0}
    .ma-st-funnel{margin-top:12px}
    .ma-st-ch{display:flex;justify-content:space-between;align-items:baseline;gap:10px}
    .ma-st-card h4{margin:0;font-size:15.5px;font-weight:700}
    .ma-st-card .muted{font-size:13px}
    .ma-st-svg{width:100%;height:auto;display:block;margin-top:6px}
    .ma-st-svg text{font-family:inherit}
    .ma-st-mean{margin:10px 0 0;font-size:13px;color:var(--mut);border-top:1px dashed var(--line);padding-top:9px;line-height:1.6}
    .ma-st-mean b{color:var(--mut2)}
    .ma-st-note{margin:8px 0 0;font-size:13px;color:var(--mut2)}
    .ma-st-empty{margin-top:12px;background:var(--bg);border-radius:12px;padding:16px;color:var(--mut);font-size:14px;line-height:1.6}
    .ma-st-figure strong{display:block;font-size:30px;line-height:1.2;margin-top:6px}
    .ma-st-figure .muted{display:block}
    .ma-st-hb{display:grid;grid-template-columns:minmax(110px,170px) 1fr 70px;gap:10px;align-items:center;margin-top:9px;font-size:14px}
    .ma-st-hb .t{height:14px;background:var(--bg);border-radius:99px;overflow:hidden}
    .ma-st-hb .t i{display:block;height:100%;background:var(--g);border-radius:99px;min-width:3px}
    .ma-st-hb .v{text-align:right;font-weight:700}
    .ma-st-ret{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-top:12px}
    .ma-st-ret div{background:var(--bg);border-radius:14px;padding:12px;text-align:center;display:flex;flex-direction:column}
    .ma-st-ret strong{font-size:28px;line-height:1.2}
    .ma-st-ret span{font-size:13px;color:var(--mut2)}
    .ma-st-ret em{font-style:normal;font-size:11.5px;color:var(--mut)}
    .ma-st-step{display:grid;grid-template-columns:200px 1fr 150px;gap:12px;align-items:center;margin-top:8px}
    .ma-st-step .bar{height:38px;background:var(--g);border-radius:10px;color:#fff;display:flex;align-items:center;padding:0 12px;font-weight:700;font-size:14.5px;white-space:nowrap;min-width:fit-content}
    .ma-st-step .bar.dark{background:var(--gd)}
    .ma-st-step .lab{font-size:14px;font-weight:600}
    .ma-st-step .lab small{display:block;font-weight:400;color:var(--mut);font-size:12px}
    .ma-st-step .drop{font-size:12.5px;color:var(--rose);font-weight:600;text-align:right}
    .ma-st-pill{font-size:12px;font-weight:700;border-radius:99px;padding:2px 10px;white-space:nowrap}
    .ma-st-pill.good{background:var(--gt);color:var(--gd)}.ma-st-pill.warn{background:var(--amt);color:var(--amber)}
    .ma-st-table{width:100%;border-collapse:collapse;font-size:14px;margin-top:8px}
    .ma-st-table th{text-align:left;font-size:12.5px;color:var(--mut);font-weight:600;padding:8px 6px;border-bottom:1px solid var(--line)}
    .ma-st-table td{padding:9px 6px;border-bottom:1px solid #F1F2F4}
    .ma-st-table .r{text-align:right}
    .ma-st-table tr.ma-st-andr td{color:var(--mut2);font-size:13.5px}
    .ma-st-table tr.ma-st-andr:first-of-type td{border-top:2px solid var(--line)}
    .ma-st-lg{display:flex;gap:14px;flex-wrap:wrap;font-size:12.5px;color:var(--mut2);margin-top:8px}
    .ma-st-lg i{display:inline-block;width:10px;height:10px;border-radius:3px;margin-right:5px;vertical-align:-1px}
    .ma-st-split{display:flex;height:34px;border-radius:10px;overflow:hidden;margin-top:12px;font-weight:700;color:#fff;font-size:14px}
    .ma-st-split div{display:flex;align-items:center;padding:0 12px;white-space:nowrap}
    .ma-st-foot{margin-top:22px;display:flex;gap:10px;align-items:center;background:#fff;border:1px solid var(--line);border-radius:14px;padding:12px 16px;font-size:13.5px;color:var(--mut2)}
    @media (max-width:1100px){.ma-st-big{grid-template-columns:repeat(2,minmax(0,1fr))}.ma-st-row.r2,.ma-st-row.r3,.ma-st-row.r11{grid-template-columns:1fr}.ma-st-step{grid-template-columns:140px 1fr 110px}}
    </style>
    <?php
}
