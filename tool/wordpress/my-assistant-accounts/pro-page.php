<?php
/**
 * The website's Pro page: [my_assistant_pro]. What the free app gives, what
 * Pro adds, the two plans, and (unless form="no") the payment form right
 * under it. The Play Store app never links here (Google's rule); people
 * find it on the website.
 */

if (!defined('ABSPATH')) {
    exit;
}

/** [feature, free, pro] — kept the same as the app (lib/logic/pro.dart). '' = not in free, '✓' = included. */
function ma_pro_rows() {
    // Owner, 24 Oct: only these are Premium; everything else is free.
    return [
        ['একসাথে চালু রিমাইন্ডার (কাজ, বিল, ধার-দেনা, কাগজের মেয়াদ — সব মিলিয়ে)', '২০টা', 'যত খুশি'],
        ['ডকুমেন্ট ও ছবি (NID, পাসপোর্ট, দলিল)', '২০টা', 'যত খুশি'],
        ['অন্যান্য হিসাব (বাড়ি, বিয়ে, ব্যবসা — বকেয়া, বাজেট)', '', '✓'],
        ['নোটে ওছিয়তনামা (শেষ বদলের তারিখসহ)', '', '✓'],
        ['স্বাস্থ্যে পরিবারের সদস্য', 'নিজের স্বাস্থ্য', 'পরিবারের সবার'],
        ['পাসওয়ার্ড', '২০টা', 'যত খুশি'],
        ['ফ্যামিলি: উত্তরাধিকারী, এখনই পুরো অ্যাক্সেস, লাইভ লোকেশন', 'সদস্য যুক্ত করা; কাজ, রিমাইন্ডার, ওষুধ, নোট পাঠানো', '✓ (উত্তরাধিকারী এক চাপে সব ব্যাকআপ নিতে পারেন)'],
        ['Google Drive-এ ব্যাকআপ', 'নিজে চাপলে', 'নিজে থেকে, প্রতিবার কিছু বদলালে'],
        ['সবকিছু PDF-এ — ডাউনলোড, শেয়ার, প্রিন্ট', '', '✓'],
        ['AI উত্তর — লম্বা, এলোমেলো কথাও বোঝে', 'অ্যাপ নিজের নিয়মে বোঝে', 'দিনে ৫০টা প্রশ্ন'],
        ['বিজ্ঞাপন', 'নিচে ছোট বিজ্ঞাপন', 'কোনো বিজ্ঞাপন নেই'],
    ];
}

function ma_pro_free_list() {
    return ['মুখে বলে সব কাজ', 'কাজের তালিকা', 'অ্যালার্ম', 'ক্যালেন্ডার — বাংলা, ইংরেজি, হিজরি', 'নামাজের সময়, সেহরি-ইফতার', 'নোট ও দিনলিপি', 'আয়-ব্যয় আর “এখন আছে”',
        'ধার-দেনা (যত জন খুশি) ও তার রিমাইন্ডার', 'কাগজের মেয়াদের খবর', 'সব মাসের রিপোর্ট', 'নিজের স্বাস্থ্য ও BMI', 'শিশুর টিকার কার্ড', 'ওষুধ খাওয়ার রিমাইন্ডার', 'অভ্যাস', 'বিশেষ দিন',
        'যাকাতের হিসাব', 'সঞ্চয় ও কিস্তি', 'খরচ ভাগাভাগি', 'দোকান ও রসিদ', 'স্মার্ট খেয়াল', 'জরুরি কার্ড', 'রক্তদান', 'ফ্যামিলিতে কাজ-রিমাইন্ডার-নোট পাঠানো',
        'PIN, আঙুলের ছাপ, এনক্রিপশন', 'নতুন ফোনে সব ফিরিয়ে আনা'];
}

add_shortcode('my_assistant_pro', 'ma_pro_page');

function ma_pro_page($atts = []) {
    $a = shortcode_atts(['form' => 'yes'], $atts, 'my_assistant_pro');
    $plans = ma_pay_plans();
    $here = get_permalink() ?: home_url('/');
    $tick = '<svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path fill="currentColor" d="M9.5 16.2 5.3 12l-1.4 1.4 5.6 5.6L20.1 8.4 18.7 7z"/></svg>';
    $dash = '<span class="ma-pro-no" aria-label="নেই">—</span>';
    $monthly = $plans['monthly']['price'];
    $yearly = $plans['yearly']['price'];
    $save = max(0, $monthly * 12 - $yearly);
    ob_start();
    ?>
    <div class="ma-pro">
        <style>
        .ma-pro{--g:#0E7A5F;--gd:#0A5C47;--gt:#E7F4EF;--ink:#111827;--mut:#6B7280;--line:#E5E7EB;--amber:#B45309;font-family:"Hind Siliguri",system-ui,sans-serif;color:var(--ink);max-width:960px;margin:0 auto}
        .ma-pro *{box-sizing:border-box}
        .ma-pro-hero{background:linear-gradient(135deg,#0E7A5F,#0F766E);color:#fff;border-radius:28px;padding:40px 28px;text-align:center;position:relative;overflow:hidden}
        .ma-pro-hero::after{content:"";position:absolute;right:-60px;top:-60px;width:220px;height:220px;border-radius:50%;background:rgba(255,255,255,.08)}
        .ma-pro-hero h2{color:#fff;margin:6px 0 8px;font-size:clamp(28px,5vw,40px);line-height:1.2}
        .ma-pro-hero p{margin:0 auto;max-width:560px;color:#D1FAE5;font-size:17px;line-height:1.6}
        .ma-pro-tag{display:inline-block;background:rgba(255,255,255,.16);border-radius:999px;padding:4px 14px;font-weight:600;font-size:14px}
        .ma-pro-plans{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin:-28px 20px 0;position:relative;z-index:1}
        .ma-pro-plan{background:#fff;border:1.5px solid var(--line);border-radius:22px;padding:22px;box-shadow:0 18px 40px -26px rgba(17,24,39,.45);display:flex;flex-direction:column}
        .ma-pro-plan.best{border-color:var(--g)}
        .ma-pro-plan .name{font-weight:600;color:var(--mut)}
        .ma-pro-plan .price{font-size:38px;font-weight:700;line-height:1.1;margin:6px 0 2px}
        .ma-pro-plan .price small{font-size:16px;color:var(--mut);font-weight:500}
        .ma-pro-plan .note{color:var(--mut);font-size:14px;min-height:22px}
        .ma-pro-badge{align-self:flex-start;background:var(--gt);color:var(--gd);border-radius:999px;padding:3px 12px;font-size:13px;font-weight:700;margin-bottom:6px}
        .ma-pro-buy{display:block;margin-top:16px;text-align:center;background:var(--g);color:#fff!important;text-decoration:none!important;border-radius:14px;padding:13px;font-weight:700;font-size:16px;transition:background .15s}
        .ma-pro-buy:hover{background:var(--gd)}
        .ma-pro-plan:not(.best) .ma-pro-buy{background:#fff;color:var(--g)!important;border:1.5px solid var(--g)}
        .ma-pro-plan:not(.best) .ma-pro-buy:hover{background:var(--gt)}
        .ma-pro-sec{margin:40px 0 0}
        .ma-pro-sec h3{font-size:24px;margin:0 0 6px}
        .ma-pro-sec>p{color:var(--mut);margin:0 0 16px;line-height:1.6}
        .ma-pro-table{width:100%;border-collapse:separate;border-spacing:0;background:#fff;border:1px solid var(--line);border-radius:18px;overflow:hidden;font-size:15px}
        .ma-pro-table th{background:#F9FAFB;text-align:left;padding:14px 16px;font-size:14px;color:var(--mut);border-bottom:1px solid var(--line)}
        .ma-pro-table th.pro{color:var(--gd);background:var(--gt)}
        .ma-pro-table td{padding:13px 16px;border-bottom:1px solid #F1F2F4;vertical-align:top;line-height:1.5}
        .ma-pro-table tr:last-child td{border-bottom:0}
        .ma-pro-table td.pro{background:#F6FBF9;color:var(--gd);font-weight:600}
        .ma-pro-table td.free{color:#4B5563}
        .ma-pro-table svg{vertical-align:-4px;color:var(--g)}
        .ma-pro-no{color:#C4C9D1}
        .ma-pro-free{display:flex;flex-wrap:wrap;gap:8px}
        .ma-pro-free span{display:inline-flex;align-items:center;gap:6px;background:#fff;border:1px solid var(--line);border-radius:999px;padding:7px 14px;font-size:14.5px}
        .ma-pro-free svg{color:var(--g)}
        .ma-pro-faq details{background:#fff;border:1px solid var(--line);border-radius:14px;padding:14px 18px;margin-bottom:8px}
        .ma-pro-faq summary{cursor:pointer;font-weight:600;font-size:16px}
        .ma-pro-faq p{color:var(--mut);margin:10px 0 0;line-height:1.65}
        .ma-pro-trust{display:flex;gap:10px;align-items:flex-start;background:var(--gt);color:var(--gd);border-radius:16px;padding:16px 18px;margin-top:16px;line-height:1.6}
        @media (max-width:640px){
            .ma-pro-hero{padding:32px 18px 52px;border-radius:22px}
            .ma-pro-plans{grid-template-columns:1fr;margin:-32px 8px 0}
            .ma-pro-table thead{display:none}
            .ma-pro-table,.ma-pro-table tbody,.ma-pro-table tr,.ma-pro-table td{display:block;width:100%}
            .ma-pro-table tr{border-bottom:1px solid var(--line);padding:10px 0}
            .ma-pro-table td{border:0;padding:3px 16px}
            .ma-pro-table td:first-child{font-weight:600}
            .ma-pro-table td.free::before{content:"ফ্রি: ";color:var(--mut);font-weight:500}
            .ma-pro-table td.pro{background:none}
            .ma-pro-table td.pro::before{content:"প্রিমিয়াম: ";color:var(--mut);font-weight:500}
        }
        </style>

        <section class="ma-pro-hero">
            <span class="ma-pro-tag">My Assistant — আপনার ব্যক্তিগত সহকারী</span>
            <h2>My Assistant প্রিমিয়াম</h2>
            <p>মুখে বলুন, বাকিটা সহকারী সামলাবে। প্রিমিয়ামে যত খুশি রিমাইন্ডার, ডকুমেন্ট আর পাসওয়ার্ড, অন্যান্য হিসাব, ওছিয়তনামা, পরিবারের স্বাস্থ্য, উত্তরাধিকার, অটো ব্যাকআপ, PDF আর AI — বিজ্ঞাপন ছাড়া।</p>
        </section>

        <div class="ma-pro-plans" id="ma-pro-plans">
            <div class="ma-pro-plan best">
                <span class="ma-pro-badge">সবচেয়ে লাভ<?php echo $save ? ' · ৳' . esc_html(ma_acc_bn($save)) . ' বাঁচে' : ''; ?></span>
                <span class="name">বার্ষিক</span>
                <span class="price">৳<?php echo esc_html(ma_acc_bn($yearly)); ?> <small>/ বছর</small></span>
                <span class="note">মাসে মাত্র ৳<?php echo esc_html(ma_acc_bn((int) round($yearly / 12))); ?></span>
                <a class="ma-pro-buy" href="<?php echo esc_url(add_query_arg('plan', 'yearly', $here) . '#ma-pay'); ?>">বার্ষিক প্রিমিয়াম কিনুন</a>
            </div>
            <div class="ma-pro-plan">
                <span class="ma-pro-badge" style="visibility:hidden">—</span>
                <span class="name">মাসিক</span>
                <span class="price">৳<?php echo esc_html(ma_acc_bn($monthly)); ?> <small>/ মাস</small></span>
                <span class="note">একবার চেখে দেখতে</span>
                <a class="ma-pro-buy" href="<?php echo esc_url(add_query_arg('plan', 'monthly', $here) . '#ma-pay'); ?>">মাসিক প্রিমিয়াম কিনুন</a>
            </div>
        </div>

        <section class="ma-pro-sec">
            <h3>ফ্রি আর প্রিমিয়ামে কী কী</h3>
            <p>প্রিমিয়াম শেষ হলেও আপনার রাখা কোনো তথ্য আটকে যায় না — সব দেখা, বদলানো আর মোছা যায়।</p>
            <table class="ma-pro-table">
                <thead><tr><th>সুবিধা</th><th>ফ্রি</th><th class="pro">প্রিমিয়াম</th></tr></thead>
                <tbody>
                <?php foreach (ma_pro_rows() as [$name, $free, $pro]) : ?>
                    <tr>
                        <td><?php echo esc_html($name); ?></td>
                        <td class="free"><?php echo $free === '' ? $dash : ($free === '✓' ? $tick : esc_html($free)); ?></td>
                        <td class="pro"><?php echo $pro === '✓' ? $tick : esc_html($pro); ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </section>

        <section class="ma-pro-sec">
            <h3>সবার জন্য সবসময় ফ্রি</h3>
            <div class="ma-pro-free">
                <?php foreach (ma_pro_free_list() as $f) : ?>
                    <span><?php echo $tick; ?><?php echo esc_html($f); ?></span>
                <?php endforeach; ?>
            </div>
        </section>

        <section class="ma-pro-sec ma-pro-faq">
            <h3>প্রশ্ন ও উত্তর</h3>
            <details><summary>কীভাবে টাকা দেব?</summary><p>বিকাশে নিচের নম্বরে Send Money করে ট্রানজেকশন আইডি আর আপনার Google ইমেইল দিন।</p></details>
            <details><summary>প্রিমিয়াম কখন চালু হবে?</summary><p>পেমেন্ট মিলিয়ে আমরা প্রিমিয়াম চালু করি — বেশির ভাগ সময় সাথে সাথেই। চালু হলে ফোনে নোটিফিকেশন আর ইমেইল যাবে। অ্যাপে একই Google অ্যাকাউন্টে লগইন থাকলেই হবে।</p></details>
            <details><summary>নতুন ফোনে কি প্রিমিয়াম থাকবে?</summary><p>হ্যাঁ। প্রিমিয়াম আপনার Google অ্যাকাউন্টের সাথে থাকে — যেকোনো ফোনে একই অ্যাকাউন্টে লগইন করলেই চালু।</p></details>
            <details><summary>মেয়াদ শেষ হলে কী হবে?</summary><p>অ্যাপ ফ্রি সংস্করণে ফিরে যাবে। আপনার সব তথ্য যেমন আছে থাকবে; শুধু প্রিমিয়াম সুবিধাগুলো বন্ধ হবে।</p></details>
            <div class="ma-pro-trust">
                <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true"><path fill="currentColor" d="M12 2 4 5v6c0 5 3.4 9.7 8 11 4.6-1.3 8-6 8-11V5l-8-3Zm-1 14-4-4 1.4-1.4L11 13.2l5.6-5.6L18 9l-7 7Z"/></svg>
                <span>আপনার হিসাব, নোট, পাসওয়ার্ড বা ব্যাকআপ কখনো আমাদের সার্ভারে আসে না — সব আপনার ফোনে এনক্রিপ্ট করা থাকে, আর ব্যাকআপ আপনার নিজের Google Drive-এ, তালাবদ্ধ অবস্থায়।</span>
            </div>
        </section>

        <?php if ($a['form'] !== 'no') : ?>
            <section class="ma-pro-sec"><?php echo ma_pay_form(['nav' => 'no', 'head' => 'no']); ?></section>
        <?php endif; ?>
    </div>
    <?php
    return ob_get_clean();
}
