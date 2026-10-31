<?php
/**
 * Deleting a member's account (owner, 29 Oct: Google Play asks for it both in
 * the app and on the website). Everything the server keeps for the member goes:
 * the account, sessions, AI counts, NLU samples, family links and sealed items,
 * blood group and requests, feedback, problem logs and notices. Payment
 * records stay, as the law asks of sales (without the member's account).
 * The member's own data on the phone and in their Google Drive is theirs and
 * never on this server.
 */

if (!defined('ABSPATH')) {
    exit;
}

/** Deletes everything this server keeps for member [id]. */
function ma_acc_delete_member($id) {
    global $wpdb;
    $id = (int) $id;
    if ($id <= 0) {
        return;
    }
    $wpdb->delete(ma_acc_table(), ['id' => $id]);
    $wpdb->delete(ma_ai_sessions_table(), ['user_id' => $id]);
    $wpdb->delete(ma_ai_usage_table(), ['user_id' => $id]);
    ma_nlu_forget_member($id);
    ma_fam_forget_member($id);
    if (function_exists('ma_bl_registry')) {
        $wpdb->delete(ma_bl_registry(), ['user_id' => $id]);
        $wpdb->delete(ma_bl_donors(), ['user_id' => $id]);
        $wpdb->delete(ma_bl_accepts(), ['user_id' => $id]);
        $wpdb->delete(ma_bl_reqs(), ['user_id' => $id]);
    }
    if (function_exists('ma_fb_table')) {
        foreach ((array) $wpdb->get_col($wpdb->prepare('SELECT id FROM ' . ma_fb_table() . ' WHERE user_id = %d', $id)) as $fid) {
            $wpdb->delete(ma_fb_msgs_table(), ['feedback_id' => (int) $fid]);
        }
        $wpdb->delete(ma_fb_table(), ['user_id' => $id]);
    }
    if (function_exists('ma_tr_table')) {
        $wpdb->delete(ma_tr_table(), ['user_id' => $id]);
    }
    if (function_exists('ma_nlog_table')) {
        $wpdb->delete(ma_nlog_table(), ['user_id' => $id]);
    }
    if (function_exists('ma_play_table')) {
        $wpdb->delete(ma_play_table(), ['user_id' => $id]);
    }
    // Problem logs hold no words of the member, only the error and the app version:
    // they stay for fixing the app, no longer tied to anyone.
    if (function_exists('ma_err_table')) {
        $wpdb->update(ma_err_table(), ['user_id' => 0], ['user_id' => $id]);
    }
}

/** A link that deletes [email]'s account, good for a day (sent by email). */
function ma_acc_delete_link($email) {
    $exp = time() + DAY_IN_SECONDS;
    $sig = hash_hmac('sha256', strtolower($email) . '|' . $exp, wp_salt('auth') . 'ma-delete');
    return add_query_arg(['ma_del' => rawurlencode($email), 'exp' => $exp, 'sig' => $sig], home_url('/'));
}

add_action('rest_api_init', function () {
    // From the app: the signed-in member deletes their own account.
    register_rest_route('my-assistant/v1', '/account/delete', [
        'methods' => 'POST',
        'permission_callback' => '__return_true', // the member's session is checked inside
        'callback' => function (WP_REST_Request $req) {
            $row = ma_ai_member($req);
            if (!$row) {
                return new WP_Error('session', 'sign in again', ['status' => 401]);
            }
            ma_acc_delete_member((int) $row['id']);
            return ['ok' => true];
        },
    ]);
});

/** [my_assistant_delete_account]: the website's form — an email, then a link to confirm. */
add_shortcode('my_assistant_delete_account', function ($atts = []) {
    $a = shortcode_atts(['nav' => 'yes'], $atts, 'my_assistant_delete_account');
    $msg = '';
    if (isset($_POST['ma_del_email'], $_POST['ma_del_nonce']) && wp_verify_nonce(sanitize_text_field(wp_unslash($_POST['ma_del_nonce'])), 'ma_del')) {
        $k = 'ma_del_rl_' . md5((string) ($_SERVER['REMOTE_ADDR'] ?? ''));
        $email = sanitize_email(wp_unslash($_POST['ma_del_email']));
        if ((int) get_transient($k) >= 5) {
            $msg = 'অনেকবার চেষ্টা হয়েছে — এক ঘণ্টা পরে আবার চেষ্টা করুন। / Too many tries — try again in an hour.';
        } elseif (is_email($email)) {
            set_transient($k, (int) get_transient($k) + 1, HOUR_IN_SECONDS);
            global $wpdb;
            // The same answer whether or not the email has an account (no one learns who is a member).
            if ($wpdb->get_var($wpdb->prepare('SELECT id FROM ' . ma_acc_table() . ' WHERE email = %s', $email))) {
                wp_mail($email, 'My Assistant — অ্যাকাউন্ট মোছা নিশ্চিত করুন / Confirm account deletion',
                    "আপনার My Assistant অ্যাকাউন্ট মুছতে নিচের লিংকে চাপুন (২৪ ঘণ্টা কাজ করবে)। আপনি না চাইলে এই ইমেইল উপেক্ষা করুন।\n\nTo delete your My Assistant account, open this link (valid for 24 hours). If you did not ask, ignore this email.\n\n" . ma_acc_delete_link($email));
            }
            $msg = 'এই ইমেইলে অ্যাকাউন্ট থাকলে নিশ্চিত করার লিংক পাঠানো হয়েছে। / If this email has an account, a confirmation link was sent.';
        }
    }
    $msg_html = $msg !== '' ? '<p class="msg" role="status">' . esc_html($msg) . '</p>' : '';
    $nonce = wp_nonce_field('ma_del', 'ma_del_nonce', true, false);
    $mail = '<a href="mailto:info@getmyassistant.app">info@getmyassistant.app</a>';
    $inner = <<<HTML
<div class="doc ma-del">
$msg_html
<div class="two">
<div class="box">
<h3>অ্যাপ থেকে</h3>
<ol>
<li>My Assistant খুলে নিচের <b>আরও</b> পাতায় যান।</li>
<li><b>সেটিংস › Google অ্যাকাউন্ট › “অ্যাকাউন্ট মুছুন”</b> চাপুন।</li>
<li>নিশ্চিত করলেই সাথে সাথে মুছে যায়।</li>
</ol>
</div>
<div class="box">
<h3>অ্যাপ ছাড়া, এখান থেকে</h3>
<ol>
<li>যে Google ইমেইলে অ্যাপে লগইন করেছিলেন, নিচে লিখুন।</li>
<li>সেই ইমেইলে নিশ্চিত করার লিংক যাবে — ২৪ ঘণ্টা কাজ করে।</li>
<li>লিংকে চাপলেই সাথে সাথে মুছে যায়।</li>
</ol>
</div>
</div>
<div class="box tint">
<form class="ma-form" method="post">
$nonce
<label>আপনার Google ইমেইল / Your Google email <input type="email" name="ma_del_email" required autocomplete="email" placeholder="name@gmail.com"></label>
<button type="submit">লিংক পাঠান / Send the link</button>
</form>
</div>

<h2>যা মুছে যায়</h2>
<ul>
<li>অ্যাকাউন্ট (নাম, ইমেইল, ছবি) আর প্রিমিয়ামের মেয়াদ</li>
<li>AI ব্যবহারের হিসাব আর কথা বোঝা শেখার নমুনা</li>
<li>ফ্যামিলির সংযোগ আর সিল করা জিনিস, উত্তরাধিকারীর কপি</li>
<li>রক্তের গ্রুপ, রক্তদাতার তথ্য আর রক্তের অনুরোধ</li>
<li>মতামত আর নোটিফিকেশন; সমস্যার লগ থেকে আপনার অ্যাকাউন্টের নাম-ইমেইল (লগে শুধু ভুলের ধরন আর অ্যাপের সংস্করণ থাকে)</li>
</ul>
<h2>যা থাকে</h2>
<ul>
<li>বিকাশ পেমেন্টের রেকর্ড (ইমেইল, পাঠানোর নম্বর, লেনদেন নম্বর, অঙ্ক) — বিক্রির হিসাব আইন অনুযায়ী রাখতে হয়।</li>
<li>আপনার ফোনে আর আপনার নিজের Google Drive-এর ব্যাকআপে রাখা তথ্য আপনার — আমাদের সার্ভারে কখনো আসে না। অ্যাপ আনইনস্টল করলে ফোনেরটা মুছে যায়; Drive-এরটা Drive থেকে মুছতে পারেন।</li>
</ul>

<hr>
<h2>Delete your My Assistant account</h2>
<p><b>In the app:</b> More › Settings › Google account › “Delete account” — deleted at once. <b>Without the app:</b> enter the Google email you signed in with above; we send a confirmation link (valid for 24 hours), and opening it deletes the account at once.</p>
<p><b>Deleted:</b> your account (name, email, picture) and Premium dates, AI usage counts and learning samples, family links and sealed items, blood group, donor details and requests, feedback and notifications; problem logs are no longer tied to you (they hold only the error and the app version). <b>Kept:</b> bKash payment records (email, sending number, transaction number, amount), as the law requires of sales. Your phone's data and your own Google Drive backup are yours and never on our server. Questions: $mail</p>
</div>
HTML;
    return ma_site_page('delete', 'অ্যাকাউন্ট', 'অ্যাকাউন্ট মুছুন', 'অ্যাপ থেকে বা এই পাতা থেকে My Assistant অ্যাকাউন্ট আর আমাদের সার্ভারে রাখা আপনার সব তথ্য মুছে দিতে পারেন।', 'অ্যাপ: My Assistant (Google Play: app.getmyassistant) · নির্মাতা: Owlgorithm Labs', $inner, $a['nav'] !== 'no');
});

// The emailed link: checked, then the account is deleted and the page says so.
add_action('template_redirect', function () {
    if (!isset($_GET['ma_del'], $_GET['exp'], $_GET['sig'])) {
        return;
    }
    $email = sanitize_email(rawurldecode(wp_unslash($_GET['ma_del'])));
    $exp = (int) $_GET['exp'];
    $want = hash_hmac('sha256', strtolower($email) . '|' . $exp, wp_salt('auth') . 'ma-delete');
    $ok = $exp > time() && hash_equals($want, (string) wp_unslash($_GET['sig']));
    if ($ok) {
        global $wpdb;
        $id = (int) $wpdb->get_var($wpdb->prepare('SELECT id FROM ' . ma_acc_table() . ' WHERE email = %s', $email));
        ma_acc_delete_member($id);
    }
    wp_die($ok ? 'আপনার My Assistant অ্যাকাউন্ট মুছে ফেলা হয়েছে। / Your My Assistant account has been deleted.' : 'লিংকটা পুরোনো বা ভুল — আবার চেষ্টা করুন। / This link is old or wrong — please try again.',
        'My Assistant', ['response' => $ok ? 200 : 400]);
});
