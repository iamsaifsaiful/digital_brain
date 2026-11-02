# Plugin check in a real WordPress

Runs the Riyal Hisab Server plugin inside WordPress (SQLite, no MySQL) with
Firebase pretended, and checks hiding, logins, sync, the agent side, users,
push and every record page.

    git clone --depth 1 --branch 6.6.2 https://github.com/WordPress/WordPress.git wp
    git clone --depth 1 --branch v2.1.16 https://github.com/WordPress/sqlite-database-integration.git wp/wp-content/plugins/sqlite-database-integration
    # wp-content/db.php from the SQLite plugin's db.copy; wp-config.php with DB_ENGINE sqlite (see .github/workflows/riyal_hisab.yml)
    ln -s "$PWD/../riyal-hisab-server" wp/wp-content/plugins/riyal-hisab-server
    php install.php wp && php e2e.php wp
