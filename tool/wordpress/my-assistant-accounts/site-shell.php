<?php
/**
 * One look for the website's own pages made by shortcodes (owner, 1 Nov):
 * the privacy policy and account deletion get the same top bar, heading
 * band and footer as the terms page (website/build_legal.py) and the buy
 * page. Use the page template "Elementor Canvas" (or any blank template) so
 * the theme's own header and footer do not show twice; [shortcode nav="no"]
 * leaves the bar and footer out for a theme page.
 */

if (!defined('ABSPATH')) {
    exit;
}

/** Where the privacy policy is: the page carrying [my_assistant_privacy] (on the live site /privacy/). */
function ma_site_privacy_path() {
    $u = function_exists('ma_page_with') ? ma_page_with('my_assistant_privacy') : '';
    $path = $u !== '' ? (string) wp_parse_url($u, PHP_URL_PATH) : '';
    return $path !== '' && $path !== '/' ? $path : '/privacy/';
}

function ma_site_css() {
    return <<<'CSS'
.ma-lg{--g:#0B6B55;--gd:#084D3D;--gt:#E6F2EE;--ink:#10201B;--mut:#4A5752;--line:#DDE5E1;--ground:#F4F6F5;background:#fff;color:var(--ink);font-family:'Noto Sans Bengali',sans-serif;font-size:16px;line-height:1.5;text-align:left}
.ma-lg,.ma-lg *{box-sizing:border-box}
.ma-lg h1,.ma-lg h2,.ma-lg h3{font-family:'Anek Bangla','Noto Sans Bengali',sans-serif;color:inherit;text-transform:none;margin:0;padding:0;border:0;letter-spacing:0}
.ma-lg p,.ma-lg ul,.ma-lg ol{margin:0;padding:0}
.ma-lg a{color:inherit;text-decoration:none;box-shadow:none}
.ma-lg img{border:0;box-shadow:none;border-radius:0;max-width:100%}
.ma-lg .wrap{max-width:1040px;margin:0 auto;padding:0 40px}
.ma-lg nav{border-bottom:1px solid var(--line);background:#fff}
.ma-lg nav .wrap{display:flex;align-items:center;gap:20px;height:72px}
.ma-lg .brand{display:flex;align-items:center;gap:12px;font-family:'Anek Bangla','Noto Sans Bengali',sans-serif;font-weight:700;font-size:21px}
.ma-lg .brand img{width:38px;height:38px}
.ma-lg nav .r{margin-left:auto;display:flex;gap:22px;font-size:15.5px;color:var(--mut)}
.ma-lg nav .r a.on{color:var(--g);font-weight:600}
.ma-lg .head{background:var(--ground);padding:56px 0 44px}
.ma-lg .eyebrow{font-size:15px;font-weight:600;color:var(--g)}
.ma-lg .head h1{margin-top:8px;font-size:52px;line-height:1.1;font-weight:700;font-stretch:86%}
.ma-lg .head .lead{margin-top:14px;font-size:18.5px;line-height:1.75;color:var(--mut);max-width:720px}
.ma-lg .meta{margin-top:18px;font-size:14.5px;color:var(--mut)}
.ma-lg .main{padding-top:44px;padding-bottom:72px}
.ma-lg .main>.doc,.ma-lg .main>.contact{max-width:820px}
.ma-lg .doc h2{font-size:28px;font-weight:700;font-stretch:90%;line-height:1.25;margin:44px 0 0}
.ma-lg .doc h2:first-child{margin-top:0}
.ma-lg .doc h3{font-size:22px;font-weight:700;font-stretch:92%;margin:34px 0 0}
.ma-lg .doc h3:first-child{margin-top:0}
.ma-lg .doc p{margin-top:12px;font-size:16.5px;line-height:1.85;color:#26332F}
.ma-lg .doc ul,.ma-lg .doc ol{margin-top:12px;list-style:none;display:grid;gap:9px}
.ma-lg .doc ul li{position:relative;padding-left:22px;font-size:16.5px;line-height:1.75;color:#26332F}
.ma-lg .doc ul li::before{content:"";position:absolute;left:4px;top:.75em;width:7px;height:7px;border-radius:50%;background:var(--g)}
.ma-lg .doc ol{counter-reset:s}
.ma-lg .doc ol li{counter-increment:s;position:relative;padding-left:36px;font-size:16.5px;line-height:1.75;color:#26332F}
.ma-lg .doc ol li::before{content:counter(s,bengali);position:absolute;left:0;top:2px;width:26px;height:26px;border-radius:50%;background:var(--g);color:#fff;font-size:14px;font-weight:700;display:grid;place-items:center;line-height:1}
.ma-lg .doc b,.ma-lg .doc strong{color:var(--ink)}
.ma-lg .doc a{color:var(--g);font-weight:600}
.ma-lg .doc hr{border:0;border-top:1px solid var(--line);margin:48px 0}
.ma-lg .doc em{font-style:normal;color:var(--mut);font-size:14.5px}
.ma-lg .box{border:1px solid var(--line);border-radius:20px;padding:22px;margin-top:16px}
.ma-lg .box.tint{background:var(--gt);border-color:transparent}
.ma-lg form.ma-form{display:grid;gap:12px}
.ma-lg form.ma-form label{display:grid;gap:6px;font-weight:600;font-size:15px}
.ma-lg form.ma-form input[type=email]{height:48px;border:1px solid var(--line);border-radius:12px;padding:0 14px;font:inherit;font-weight:400;font-size:16px;background:#fff;color:var(--ink);box-shadow:none;margin:0;width:100%}
.ma-lg form.ma-form input:focus{outline:0;border-color:var(--g);box-shadow:0 0 0 3px rgba(11,107,85,.15)}
.ma-lg form.ma-form button{height:52px;border:0;border-radius:14px;background:var(--g);color:#fff;font-family:'Anek Bangla','Noto Sans Bengali',sans-serif;font-size:18px;font-weight:700;cursor:pointer;padding:0 22px}
.ma-lg form.ma-form button:hover{background:var(--gd)}
.ma-lg .msg{background:var(--gt);color:var(--gd);border-radius:14px;padding:14px 16px;margin-top:16px;font-weight:600}
.ma-lg .two{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-top:16px}
.ma-lg .two .box{margin-top:0}
.ma-lg .contact{background:var(--ink);color:#fff;border-radius:22px;padding:28px;margin-top:48px}
.ma-lg .contact h2{font-size:26px;font-weight:700;font-stretch:90%;margin:0;color:#fff}
.ma-lg .contact p{margin-top:8px;color:#B9C6C1;font-size:16px;line-height:1.7}
.ma-lg .contact a.mail{display:inline-block;margin-top:14px;background:#fff;color:var(--gd);border-radius:999px;padding:11px 22px;font-weight:700}
.ma-lg footer{border-top:1px solid var(--line);padding:30px 0;font-size:14.5px;color:var(--mut)}
.ma-lg footer .wrap{display:flex;gap:22px;align-items:center;flex-wrap:wrap}
.ma-lg footer .r{margin-left:auto;display:flex;gap:22px;flex-wrap:wrap}
.ma-lg.bare{background:transparent}
.ma-lg.bare .wrap{padding:0}
@media (max-width:760px){
  .ma-lg .wrap{padding:0 16px}
  .ma-lg nav .r{display:none}
  .ma-lg .head{padding:36px 0 30px}
  .ma-lg .head h1{font-size:36px}
  .ma-lg .head .lead{font-size:17px}
  .ma-lg .main{padding-top:28px;padding-bottom:56px}
  .ma-lg .doc h2{font-size:24px}
  .ma-lg .two{grid-template-columns:1fr}
  .ma-lg .contact{padding:20px}
  .ma-lg footer .r{margin-left:0}
}
CSS;
}

/**
 * A whole page: [active] marks the bar's link ('privacy', 'terms', 'buy', 'delete').
 * [inner] is trusted HTML made by this plugin.
 */
function ma_site_page($active, $eyebrow, $title, $lead, $meta, $inner, $nav = true) {
    $icon = esc_url(plugins_url('assets/icon.svg', __FILE__));
    $home = esc_url(home_url('/'));
    $links = [
        ['/', 'মূল পাতা', ''],
        ['/buy-pro/', 'প্রিমিয়াম কিনুন', 'buy'],
        [ma_site_privacy_path(), 'গোপনীয়তা নীতি', 'privacy'],
        ['/terms-and-conditions/', 'শর্তাবলি', 'terms'],
    ];
    $bar = '';
    foreach ($links as [$href, $label, $key]) {
        $bar .= '<a href="' . esc_url(home_url($href)) . '"' . ($key !== '' && $key === $active ? ' class="on"' : '') . '>' . esc_html($label) . '</a>';
    }
    $fonts = '<link rel="preconnect" href="https://fonts.googleapis.com"><link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
        . '<link href="https://fonts.googleapis.com/css2?family=Anek+Bangla:wdth,wght@75..100,400..800&family=Noto+Sans+Bengali:wght@400;500;600;700&display=swap" rel="stylesheet">';
    $out = $fonts . '<style>' . ma_site_css() . '</style><div class="ma-lg' . ($nav ? '' : ' bare') . '">';
    if ($nav) {
        $out .= '<nav><div class="wrap"><a class="brand" href="' . $home . '"><img src="' . $icon . '" alt="">My Assistant</a><div class="r">' . $bar . '</div></div></nav>';
    }
    $out .= '<header class="head"><div class="wrap"><p class="eyebrow">' . esc_html($eyebrow) . '</p><h1>' . esc_html($title) . '</h1>'
        . ($lead !== '' ? '<p class="lead">' . esc_html($lead) . '</p>' : '') . ($meta !== '' ? '<p class="meta">' . esc_html($meta) . '</p>' : '') . '</div></header>';
    $out .= '<div class="wrap main">' . $inner
        . '<div class="contact"><h2>প্রশ্ন থাকলে লিখুন</h2><p>আপনার তথ্য দেখতে, ঠিক করতে বা মুছতে চাইলে, বা যেকোনো প্রশ্নে ইমেইল করুন।</p><a class="mail" href="mailto:info@getmyassistant.app">info@getmyassistant.app</a></div></div>';
    if ($nav) {
        $out .= '<footer><div class="wrap"><span class="brand" style="font-size:17px"><img src="' . $icon . '" alt="" style="width:28px;height:28px">My Assistant</span><span>getmyassistant.app · Owlgorithm Labs</span>'
            . '<div class="r"><a href="' . esc_url(home_url(ma_site_privacy_path())) . '">গোপনীয়তা নীতি</a><a href="' . esc_url(home_url('/terms-and-conditions/')) . '">শর্তাবলি</a><a href="mailto:info@getmyassistant.app">info@getmyassistant.app</a></div></div></footer>';
    }
    return $out . '</div>';
}
