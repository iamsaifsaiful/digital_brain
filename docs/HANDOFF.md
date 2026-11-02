# Handoff — রেমিট খাতা

## Where things are
- `lib/core/` — numbers and Bangla formatting (`format.dart`), data (`models.dart`),
  all account maths and message texts (`ledger.dart`). No Flutter here; tested in `test/ledger_test.dart`.
- `lib/services/` — encryption (AES-256-GCM, key in Android Keystore), PIN/fingerprint lock,
  encrypted data file + photos + password-locked backup, phone actions (WhatsApp `wa.me`, call, share, camera, clipboard).
- `lib/state/hisab.dart` — every change goes through here; each one is saved at once and written
  to the activity log (append-only; nothing is deleted, sends are cancelled instead).
- `lib/ui/` — screens. `test/app_flow_test.dart` walks first run → send → WhatsApp → TrxID from clipboard → deposit → agent payment.

## Rules the client asked for
- Customer ledger only in riyal (SAR). Agent ledger only in taka.
- No stored rate: each send has riyal, rate and taka (taka = riyal × rate, can be typed by hand).
- Send flow: find customer (name/number) or quick profile (photo, name, phone) → riyal, rate, number, fee yes/no →
  confirm sheet with নগদ / বাকি / আংশিক → saved → WhatsApp opens on the agent's one saved chat.
- The agent's message never mentions riyal or the rate (tested).
- Agent replies with the TrxID in the same chat. No paid API and no notification reading
  (Play Protect blocks downloaded APKs that read notifications): the user copies the reply,
  and the app finds the TrxID on the clipboard when it comes back to the front, matching it by
  `#number`, the last 3–4 digits of the bKash number, or the only waiting send.
- Riyal deposits: any amount; shown against the oldest sends first.
- Activity log keeps when and what for everything.

## Added in 1.1
- Opening animation on the PIN screen (riyal coin → taka), swipeable tabs, a 5th tab "অন্যান্য"
  (expenses, day close, log, settings, losses, promises, wrong-number list).
- Entry works both ways live: riyal × rate → taka, or taka ÷ rate → riyal (whichever was typed last).
- Customer "promise to pay" date → local notification (flutter_local_notifications, same setup as My Assistant).
- Loss ("আদায় হবে না"): takes riyal off the due, adds nothing to cash in hand.
- Wrong number: mark whose mistake on a sent transaction. A sent transaction cannot be cancelled;
  editing it keeps taka, number and fee fixed.
- Agent payments keep way, date, from-account, reference and an optional receipt photo (encrypted, in backups).
- Mobile recharge and MB packs (operator, pack) as transaction kinds; the agent's message says so.
- Agent reply format: "<send no> <taka>-<last 3 digits>", e.g. `1042 10000-667`, TrxID optional.
  The send number decides the match; without it the app matches by taka and asks. Nothing is put on a
  send until the user taps it.
- PDF for every report (`lib/services/pdf.dart`): pages drawn with Flutter's text engine so Bangla joins
  correctly, stored as images in the PDF (text is not selectable).

## Added in 1.2 (server)
- WordPress plugin `server/riyal-hisab-server` (install as a zip on the client's domain). REST namespace
  `rbh/v1`, hidden from `/wp-json`; without a valid session every route answers like a missing route.
  The app has no offline/local mode with a server build: the address is not in the repo, it comes from
  the `RH_SERVER` Actions secret, scrambled into the build (`tool/hide_server.py` ↔ `serverBase()`).
- Logins: the main admin is set on the server (settings tab). From the app: other admins with a
  permission checklist, and agent logins. Agents can use the app (feed, "পাঠিয়েছি", notifications via
  FCM) instead of WhatsApp — per agent, in Settings → এজেন্ট.
- Sync: hash-diff push, then pull by revision. A phone new to the server pulls first.
  Send numbers are year+month+serial (`26110001`), handed out by the server in blocks per month.
- Per-admin cash: every record carries `by/byName`, stamped by the server. "হাতে থাকা উচিত" is the
  signed-in admin's own hand; the main admin also sees everyone and the shop total. A handover
  ("কালেকশন বুঝে নিন") moves riyal between two hands and is recorded only by the one who takes it,
  so the shop total never counts it.
- Agent payments are in taka with the riyal it cost (required).
- Server menus (look only): records with date/admin/agent filters, "হাতের হিসাব", "সমস্যার লগ" (app
  errors sent by phones), print/PDF of any list, full backup download (app-compatible), daily
  Google Drive backup.
- App: timeline per transaction (who did what, reply auto-filled or typed), agent's day view,
  top-customer lists, PDF preview → download / print / share / just view (`riyal/pdf` channel,
  `PdfTools.kt`), editable message templates (`lib/core/templates.dart`, shared via settings),
  one-tap English (`lib/core/lang.dart`; words in `tool/en.tsv` → `python3 tool/gen_en.py`).
  WhatsApp messages stay in Bangla. Search matches Bangla names typed in English (`soundKey`).
- Server check: `server/test/e2e.php` runs the plugin inside a real WordPress (SQLite) in CI.

## Build / release
- `.github/workflows/riyal_hisab.yml` runs on push to `main` of this repository
  (`iamsaifsaiful/remit-khata`): analyze, test, sign with the same release-key secrets as
  My Assistant (alias `myassistant`), build, and publish a release tagged
  `v<version>-build.<n>`.
- Bump `version:` in `pubspec.yaml` for a new client version; the build number comes from the run.
- Android files kept in git are only the customised ones; `tool/setup_platforms.sh` creates the rest.

## Not done / to check on a real phone
- The `RH_SERVER` repository secret must be set, or the build stops at "Server address".
- Firebase (push) and Google Drive need the client's own Google project files, entered on the server.
- Clipboard reading on Android 10+ works only while the app is in front (that is how it is used here).
- Fingerprint, camera and WhatsApp opening are not covered by tests (need a phone).
