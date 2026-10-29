<?php
/**
 * A fresh start (owner, 29 Oct 2026): the app begins again at 1.0.0 as a new
 * app (app.getmyassistant), and everything kept for its members goes —
 * accounts, Premium, payments and bKash messages, family, blood, feedback,
 * AI counts, learning samples, problem logs, notices sent, Play purchases and
 * the private files. Kept: the site's settings, the notices the admin wrote,
 * the language models, and the admins' own sign-ins. The owner presses it
 * once on the settings page, typing the words; it cannot be undone.
 *
 * After it, an app from before (no 'pkg' at sign-in) is asked to install
 * the new one.
 */

if (!defined('ABSPATH')) {
    exit;
}

const MA_RESET_WORDS = 'সব মুছুন';

/** Every member table, emptied; the private files deleted. */
function ma_reset_everything() {
    global $wpdb;
    $tables = [ma_acc_table(), ma_ai_usage_table(), ma_ai_sources_table(), ma_pay_table(), ma_bk_table(), ma_fb_table(), ma_fb_msgs_table(),
        ma_err_table(), ma_tr_table(), ma_nlog_table(), ma_note_runs_table(), ma_play_table(),
        ma_bl_registry(), ma_bl_donors(), ma_bl_accepts(), ma_bl_reqs(),
        ma_nlu_table('samples'), ma_nlu_table('labels')];
    foreach (['keys', 'links', 'claims', 'packages', 'items', 'places', 'files'] as $t) {
        $tables[] = ma_fam_table($t);
    }
    foreach ($tables as $t) {
        if ($wpdb->get_var($wpdb->prepare('SHOW TABLES LIKE %s', $t)) === $t) {
            $wpdb->query("TRUNCATE TABLE `$t`");
        }
    }
    // Members' sign-ins go; the admins' (admin app) stay.
    $wpdb->query($wpdb->prepare('DELETE FROM ' . ma_ai_sessions_table() . ' WHERE app <> %s', 'admin'));
    $dir = ma_fb_dir();
    foreach ((array) glob($dir . '/*') as $f) {
        $b = basename((string) $f);
        if (is_file($f) && $b !== '.htaccess' && $b !== 'index.php') {
            @unlink($f);
        }
    }
    // The old apps' numbers (2.x) mean nothing to the new app (1.0.0 on).
    delete_option('ma_app_min');
    delete_option('ma_app_min_play');
    update_option('ma_legacy_block', '1', false);
    update_option('ma_reset_at', gmdate('c'), false);
}

/** An app from before the fresh start: it does not say its package. */
function ma_legacy_app(WP_REST_Request $req) {
    return get_option('ma_legacy_block') === '1' && trim((string) $req->get_param('pkg')) === '';
}

add_action('admin_post_ma_fresh_start', function () {
    ma_acc_guard('ma_fresh_start', 'manage_options');
    if (trim((string) wp_unslash($_POST['words'] ?? '')) !== MA_RESET_WORDS) {
        ma_acc_back('কিছুই মোছা হয়নি — ঘরে ঠিক “' . MA_RESET_WORDS . '” লিখতে হবে।', 'error', ['tab' => 'security']);
    }
    ma_reset_everything();
    ma_acc_back('সব সদস্যের তথ্য মুছে নতুন করে শুরু হলো।', 'ok', ['tab' => 'security']);
});

/** The settings page's card for it. */
function ma_reset_card() {
    if (!current_user_can('manage_options')) {
        return;
    }
    $at = (string) get_option('ma_reset_at', '');
    ?>
    <section class="ma-card pad" id="ma-reset">
        <div class="ma-bar-title"><h2>নতুন করে শুরু (সব সদস্যের তথ্য মুছুন)</h2></div>
        <p class="muted">মুছে যাবে: সব সদস্য, প্রিমিয়াম, পেমেন্ট আর বিকাশের মেসেজ, ফ্যামিলি, রক্তের তালিকা, মতামত, AI-এর হিসাব, শেখার নমুনা, সমস্যার লগ, পাঠানো নোটিফিকেশনের হিসাব, Google Play-র কেনা, আর গোপন ফাইল। থাকবে: সাইটের সেটিংস, আপনার লেখা নোটিফিকেশন, ভাষার মডেল, আর অ্যাডমিনদের লগইন। <strong>এটা ফেরানো যায় না।</strong> পুরোনো অ্যাপ (২.x) লগইন করতে চাইলে নতুন অ্যাপ বসাতে বলবে।</p>
        <?php if ($at !== '') : ?><p>শেষবার করা হয়েছে: <?php echo esc_html($at); ?> (UTC)</p><?php endif; ?>
        <form method="post" action="<?php echo esc_url(admin_url('admin-post.php')); ?>" class="ma-inline-form" style="flex-wrap:wrap;gap:10px">
            <input type="hidden" name="action" value="ma_fresh_start"><?php wp_nonce_field('ma_fresh_start'); ?>
            <label>নিশ্চিত করতে লিখুন “<?php echo esc_html(MA_RESET_WORDS); ?>” <input type="text" name="words" autocomplete="off" style="width:140px"></label>
            <button class="ma-btn" type="submit" style="background:#B3261E;border-color:#B3261E">সব মুছে নতুন করে শুরু</button>
        </form>
    </section>
    <?php
}
