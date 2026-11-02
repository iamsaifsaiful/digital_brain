# Handoff — রিয়াল-বিকাশ হিসাব

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

## Build / release
- `.github/workflows/riyal_hisab.yml` runs on push to branch `riyal-hisab` of
  `iamsaifsaiful/digital_brain`: analyze, test, sign with the same release-key secrets as
  My Assistant (alias `myassistant`), build, and publish a **pre-release** tagged
  `riyal-hisab-v<version>-build.<n>`.
- Bump `version:` in `pubspec.yaml` for a new client version; the build number comes from the run.
- Android files kept in git are only the customised ones; `tool/setup_platforms.sh` creates the rest.

## Not done / to check on a real phone
- Clipboard reading on Android 10+ works only while the app is in front (that is how it is used here).
- Fingerprint, camera and WhatsApp opening are not covered by tests (need a phone).
