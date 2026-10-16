<?php
define('WP_INSTALLING', true);
$_SERVER['HTTP_HOST'] = '127.0.0.1:8899';
require $argv[1] . '/wp-load.php';
require_once ABSPATH . 'wp-admin/includes/upgrade.php';
require_once ABSPATH . 'wp-admin/includes/plugin.php';
$r = wp_install('My Assistant', 'admin', 'admin@example.com', true, '', 'pass1234');
echo "installed user {$r['user_id']}\n";
