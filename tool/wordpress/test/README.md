# Plugin check in a real WordPress

Runs the My Assistant Accounts plugin inside WordPress (SQLite, no MySQL needed)
with Google, Anthropic and Firebase pretended, and checks sign-in, AI, trial,
payments, the admin API, push and the admin pages.

    git clone --depth 1 --branch 6.6.2 https://github.com/WordPress/WordPress.git wp
    git clone --depth 1 --branch v2.1.16 https://github.com/WordPress/sqlite-database-integration.git wp/wp-content/plugins/sqlite-database-integration
    # wp-content/db.php from the SQLite plugin's db.copy; wp-config.php with DB_ENGINE sqlite
    ln -s "$PWD/../my-assistant-accounts" wp/wp-content/plugins/my-assistant-accounts
    php install.php wp && php e2e.php wp
