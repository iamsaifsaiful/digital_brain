# getmyassistant.app — the website's pages

Kept here from 1 Nov 2026 (before, only in a Claude session's scratch space).

| Page | Source | What to paste in WordPress |
|---|---|---|
| Home (landing) | `index.html` → `python3 build_elementor.py` | `my-assistant-landing-elementor.html` into one Elementor HTML widget |
| Terms | `build_legal.py` | `terms-and-conditions-elementor.html` into an Elementor HTML widget |
| Privacy policy | the plugin: `[my_assistant_privacy]` (`tool/wordpress/my-assistant-accounts/privacy.php`) | the shortcode — `build_legal.py` also writes an older privacy page; it is not used |
| Buy Premium (`/buy-pro/`) | the plugin: `[my_assistant_payment]` (`payments.php`) | the shortcode |

Owner, 1 Nov 2026: the website sells the yearly plan only (৳৯৯৯ by bKash Send Money,
no automatic renewal); the download button goes to Google Play
(`app.getmyassistant`). Never write how many AI questions a day Premium allows.
