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
add_shortcode('my_assistant_delete_account', function () {
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
    ob_start();
    ?>
    <div class="ma-del">
        <h3>My Assistant — অ্যাকাউন্ট মুছুন / Delete your account</h3>
        <p>অ্যাপে সেটিংস › Google অ্যাকাউন্ট › “অ্যাকাউন্ট মুছুন” থেকেও করা যায়। মুছলে আমাদের সার্ভারে রাখা আপনার সব তথ্য (অ্যাকাউন্ট, প্রিমিয়াম, ফ্যামিলি, রক্তের গ্রুপ, মতামত, লগ) মুছে যায়; শুধু পেমেন্টের রেকর্ড আইন অনুযায়ী থাকে। আপনার ফোনে আর আপনার Google Drive-এ রাখা তথ্য আপনার নিজের — অ্যাপ আনইনস্টল করলে ফোনেরটা মুছে যায়।</p>
        <p>You can also do this in the app: Settings › Google account › “Delete account”. Everything our server keeps for you is deleted; payment records stay as the law requires. What is on your phone and in your own Google Drive is yours.</p>
        <?php if ($msg) : ?><p><strong><?php echo esc_html($msg); ?></strong></p><?php endif; ?>
        <form method="post">
            <?php wp_nonce_field('ma_del', 'ma_del_nonce'); ?>
            <label>আপনার Google ইমেইল / Your Google email <input type="email" name="ma_del_email" required></label>
            <button type="submit">লিংক পাঠান / Send the link</button>
        </form>
    </div>
    <?php
    return ob_get_clean();
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
