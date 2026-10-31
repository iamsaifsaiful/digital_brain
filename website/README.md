# getmyassistant.app — the website's pages

Kept here from 1 Nov 2026 (before, only in a Claude session's scratch space).

| Page | Source | What to paste in WordPress |
|---|---|---|
| Home (landing) | `index.html` → `python3 build_elementor.py` | `my-assistant-landing-elementor.html` into one Elementor HTML widget |
| Terms | `build_legal.py` | `terms-and-conditions-elementor.html` into an Elementor HTML widget |
| Privacy policy (`/privacy/`) | the plugin: `[my_assistant_privacy]` (`privacy.php`, look from `site-shell.php`) | the shortcode, page template "Elementor Canvas" — `build_legal.py` also writes an older privacy page; it is not used |
| Delete account (`/delete-account/`) | the plugin: `[my_assistant_delete_account]` (`account-delete.php`) | the shortcode, page template "Elementor Canvas" |
| Buy Premium (`/buy-pro/`) | the plugin: `[my_assistant_payment]` (`payments.php`) | the shortcode, page template "Elementor Canvas" |

The phone pictures (`img/`) come from the app itself: `SHOTS=1 flutter test --no-pub test/ui/site_shots_test.dart --update-goldens`, then `python3 website/shots.py` and `python3 website/build_elementor.py`.
The shortcode pages bring their own top bar and footer; `nav="no"` leaves them out inside a theme page.

Owner, 1 Nov 2026: the website sells the yearly plan only (৳৯৯৯ by bKash Send Money,
no automatic renewal); the download button goes to Google Play
(`app.getmyassistant`). Never write how many AI questions a day Premium allows.
