# My Assistant — handoff for the next Claude session (18 Oct 2026, v2.25.0-b34)

> **To Claude:** the owner (Saif, iamsaifsaiful@gmail.com — use only to identify him) writes in Bengali; reply and report in Bengali. He tests on his own Android phone and sends screenshots. For each finding: reproduce it in a test first, find the root cause, fix it so similar cases are fixed too, run the whole suite, then build a signed APK and send it. Do not change the package name or the signing.

---

## 0. Starting in a new Claude account (read first)

- The repo is the single source of truth: this file, `docs/voice-test-plan.md`, the commit messages (`git log`, detailed per release) and the tests.
- Older history lives in the old account's claude.ai project "App Development" (`claude/digital-brain-*.md`, `claude/my-assistant-*.md`). That covers the release log since v1, the Pro/free plan decisions, the WordPress account server, the business model and the to-do intent design. The owner can copy those docs into the new account's project if deeper history is needed. Everything current is summarised here.
- **Access:** connect GitHub with access to `iamsaifsaiful/digital_brain`, clone it, then `git checkout next-update`.
- **Signing:** the owner must attach his signing-key file (from 13 Oct: the `.jks`, or its base64, and the password) before the first APK. Without it, only unsigned or CI-signed APKs can be made, and those do not install over his current app.
- **Environment setup:**
  - Flutter stable 3.47.x and Java 17.
  - Run `bash tool/setup_platforms.sh` once, so the `android/` platform files match CI.
  - Then `flutter pub get`.
- Read sections 2, 4 and 9 before touching anything.

## 1a. Business context (decided earlier by the owner)
- **Free and Pro, with no trial.** Two plans: ৳99/month and ৳999/year.
- **Pro includes:** AI, no ads, auto Drive backup, paper-expiry and loan pay-back reminders, full report history, shops, receipts, PDF, inbox, smart notices.
- **Free limits:** 20 reminders on, 20 loan people, 30 documents, 10 passwords, 1 shop, 1 other account.
- **Editions:** `EDITION` dart-define — `direct` (GitHub APK), `play`, `play_preview`. The owner tests the **play_preview** build, which is the separate app `.preview`.
- **Server:** a WordPress plugin on the owner's site (`tool/wordpress/`) handles accounts, the AI proxy (the key stays on the server, never in the APK), payments by bKash on the website, push via FCM, feedback and blood requests. There is also an admin app in `admin_app/`.
- **Rules first, AI only when needed.** Medicines, health data, vault items and messages never go to the AI.

## 1. What the app is

- **My Assistant — আপনার ব্যক্তিগত সহকারী**: a Bengali voice-first personal assistant, built with Flutter and running on Android.
- The user speaks or types Bengali (regional and Banglish too). The app keeps or answers:
  - to-dos, reminders and alarms
  - money: ধার-দেনা/ledger, আয়-ব্যয়, accounts, savings, DPS, shop
  - notes, contacts and calls
  - documents (ডকুমেন্টস/কাগজপত্র) and a password vault
  - health readings, medicines and habits
  - special days (birthdays and so on), the Bangladesh calendar (Bangla and Hijri dates, government holidays), zakat and backup
- **Repo:** `github.com/iamsaifsaiful/digital_brain`. Working branch: **`next-update`** (all recent work is there; `main` is older).
- **Package id:** `com.iamsaifsaiful.digital_brain`. It must never change, because updates install over the old app.
- **Current version:** `pubspec.yaml` `version: 2.25.0+71`, plus `appVersion = '2.25.0'` in `lib/screens/more_screen.dart`. Bump both on every release.
- **Last APK sent:** `My-Assistant-Play-Preview-2.25.0-b34-arm64.apk` / `-armv7.apk` (GitHub pre-release tag `preview-2.25.0-build.34`).

## 2. The owner's standing rules (verbatim where quoted — keep them all)

**How to fix things**
- "সমস্যার সমাধান করার আগে, সমস্যা কি, কেন এপ ধরতে পারতেছে না, কি করলে ধরতে পারবে, আনুষঙ্গিক সকল দিক বিবেচনায় নিয়ে সমাধান করবা। যেন, সিমিলার কোন সমস্যা আবার না আসে"
- "শুধু timeout বাড়িয়ে বা synonym list যোগ করে সমাধান হয়েছে বলবে না"; "শুধু UI message পাল্টিয়ে সমাধান হয়েছে বলবে না।"

**Claims and reports**
- "বাস্তব audio test না করে voice recognition সম্পূর্ণ ঠিক হয়েছে বলে দাবি করবে না।"
- "পরীক্ষা ছাড়া সফলতা বা accuracy percentage দাবি করবে না।"
- "Static analysis থেকে নিশ্চিত নয় এমন বিষয়কে runtime fact বলবে না।"
- Always list honestly what is **not** verified (real microphone, live AI, real notifications or vibration).

**Data and security**
- "ব্যবহারকারীর ডেটা মুছে বা encryption দুর্বল করে সমস্যা সমাধান করবে না।"
- "Data model পরিবর্তন হলে নিরাপদ migration রাখো।"
- Passwords, vault items, PINs and OTPs never go to the AI and are never spoken aloud.
- Health data stays on the phone. Messages from other apps never go to the AI. Medicines are not sent to the AI.
- "API key, পাসওয়ার্ড, ব্যক্তিগত নোট ও মেসেজ logs-এ লিখবে না"; "ব্যক্তিগত তথ্য production log-এ লিখবে না। Debug logging বন্ধ করার ব্যবস্থা রাখো।"

**Keys, services and signing**
- "অনুমতি ছাড়া paid service চালু করো না। API key APK-তে রাখবে না; backend ব্যবহার করো।" Also: "credential hardcode করবে না".
- Never ask for the owner's Google password. The Firebase service-account JSON is never sent to Claude.
- "বিদ্যমান package name ও release signing configuration সংরক্ষণ করো". **Never commit the keystore** (see §6).

**Workflow**
- For a visible design change: send screenshots first, then the APK.
- "আর কিছু বলতে চান?" (voice mode asking for more after an answer): the owner chose **"বন্ধই থাকুক"** (keep it off).

## 3. Toolchain and commands

```bash
# Flutter (stable). Analyze: about 21 "info" lines is normal; there must be 0 errors and 0 warnings.
flutter analyze --no-pub
# All tests (~5 min). The last run had 769 passing.
flutter test --no-pub
# One file, or one test by name:
flutter test --no-pub test/screens_1018c_test.dart --plain-name "৫ঙ"
# English UI strings: every Bangla tr()/trf() text needs an English entry.
python3 tool/i18n_missing.py      # must print "0 missing"
```

- **i18n:** UI text is written in Bangla, wrapped in `tr('…')` or `trf('… {0}', [x])`. English lives in `lib/logic/strings_en.dart` (`enStrings` map, with the Bangla text as the key).
  - When adding new text, add `'<bangla>': '<english>',` entries to that map, then run `tool/i18n_missing.py` until it shows 0.
  - Example sentences that stay Bangla are listed in `tool/i18n_keep_bn.txt`.
- **Test clock:** `Fri 9 Oct 2026 15:53` (`Rig.nowAt` in `test/app_test.dart`). Weeks start Saturday.
- **Test helpers in `test/app_test.dart`:**
  - `start(t)` builds a `Rig` with in-memory storage.
  - `ChatController(rig.brain)` gives you the chat; call `chat.hear('…')` and read `chat.messages`.
  - `sendTyped(t)` presses the chat's round send button. The keyboard ↵ now makes a new line.
- **Screenshots without a phone:** a widget test that loads `assets/fonts/NotoSansBengali-*.ttf` and the MaterialIcons font with `FontLoader`, sets `t.view.physicalSize = Size(1170, 2532)` and `devicePixelRatio = 3`, then uses `captureImage(find.byType(MaterialApp).evaluate().first)` inside `t.runAsync` and writes the PNG. Keep such tests out of the committed suite (for example in a `test/tmp/` folder that you delete afterwards).

## 4. Build, sign and send

1. Commit on `next-update` with these trailer lines:
   ```
   Co-Authored-By: Claude <noreply@anthropic.com>
   ```
   Then `git push origin next-update`.
2. Start the build: `gh workflow run play_preview.yml --ref next-update`.
   - The workflow is `.github/workflows/play_preview.yml`: analyze, then `flutter build apk --release --split-per-abi --dart-define=EDITION=play_preview`.
   - It publishes a pre-release tagged `preview-<version>-build.<run_number>`, with arm64 and armeabi-v7a APKs.
3. Find the run with `gh api "repos/iamsaifsaiful/digital_brain/actions/runs?branch=next-update&per_page=1" --jq '.workflow_runs[0].id'` and poll it until `status == completed`. Use REST; do not use GraphQL.
4. Download the assets: `gh api "repos/iamsaifsaiful/digital_brain/releases/tags/<tag>" --jq '.assets[]'`, then `gh api -H "Accept: application/octet-stream" repos/iamsaifsaiful/digital_brain/releases/assets/<id> > in.apk`.
5. **Re-sign with the owner's release key.** The CI APKs are not signed with it. Use apksigner (or `java -jar apksigner.jar sign`):
   - `--ks my-assistant-release.jks --ks-key-alias myassistant`, password from the owner. Alias: `myassistant`.
   - Verify: the signer certificate's SHA-256 must start with **`fc6cff35`**: `…e59a32e26da5b81cb2efbc29af14745b2939d2a3909358af69d0014f`.
6. Name the files `My-Assistant-Play-Preview-<ver>-b<N>-arm64.apk` and `…-armv7.apk`, then send both. The next build number continues from 35.

## 5. Architecture — how a sentence becomes an action

**`ChatController.hear()` (lib/state/chat.dart)** takes these steps in order:
1. `_turn++` and the topic policy (`_topicTurn`, `_onList`).
2. `_answer()` handles a pending question (`ChatWait.*`).
3. `_bulk()` (lib/state/bulk_chat.dart) handles group actions on a shown list ("এগুলো সব মুছে দাও"), date-based groups ("৩০ অক্টোবর এবং ৩১ ডিসেম্বরের রিমাইন্ডার বাদ দাও") and single index picks.
4. `_batchTimeFor()` handles "দুপুরে দাওয়াত" right after several to-dos were added.
5. `_todoCorrection()`: "না, এগারোটায়".
6. `_afterSave()`: "এটা তো বলি নাই".
7. A negation check.
8. `_understand()` → `brain.understandAll()`, which runs the local rules first and the AI only when the rules did not decide.
9. Commands are executed: `_start()`, `_saveCurrent()`, `_todo()`, `_menu()`, `_bulkWith()`.

**`parseAll()` (lib/logic/plan.dart)** runs in this order:
1. `lineTodos` (a typed multi-line list under a heading).
2. Newlines become separate sentences.
3. `tidySpeech()` (lib/logic/meaning.dart). It normalises:
   - plural endings: "সব গুলো" → "সবগুলো"
   - clock times: "৯ টায়" → "৯টায়"
   - "আয় ব্যয়" → "আয়-ব্যয়"
   - "সকল"/"সমস্ত" → "সব"
   - dates and years, and day words
4. `calendarAsked` → `SmallTalk(Talk.calendar | Talk.date)`.
5. `docAsked` (papers by name).
6. `menuCommand` (lib/logic/menus.dart).
7. `spentInParts`.
8. note+task split.
9. `eventOnDays` ("২৩ এবং ২৪ তারিখে দাওয়াত").
10. `datedTodos`.
11. Money clauses.
12. `todoCommands` (lib/logic/todo.dart).
13. `Parser.parse` (lib/logic/parser.dart).
14. `menuUnsupported` fallback.

**Key files**
- `lib/logic/parser.dart`: all `Command` classes, the main rules, `isQuestionText`, `searchTerms`, `normalize`/`fold`.
- `lib/logic/todo.dart`: the to-do language (`_tdAdd`, `_tdWhen`, `_saysToDo`, `_nounOfVerb`, `todoTitle`).
- `lib/logic/when.dart`: `parseWhen`, `hourOpen`/`ampmUnclear`/`saysDayPart` (a bare hour is never scheduled), `sayWhen`.
- `lib/logic/selection.dart`:
  - `Selection`/`SelKind` (all, indexes, first, last, range, names, filter, rest, global; plus excepts — a singular "ফোনেরটা" is marked `exceptOne`).
  - `BulkAction`, `bulkCommands`, `datedBulk`.
- `lib/state/bulk_chat.dart`:
  - `ResultSet` keeps what was shown: ids, label, matching vs shown, turn. Sets stay fresh for 30 min / 12 turns.
  - Resolver, `_bulkStart` (one confirmation for deletes), `_bulkRun`, undo/restore.
  - `bulkOps` per domain: tasks, reminders, notes, medicines, habits, health, ledger, money.
  - `followUps`: next-step chips.
- `lib/logic/menus.dart` + `lib/state/menu_chat.dart`: the other menus as `MenuAction(domain, op, …)`. `voiceCaps` in `lib/logic/app_map.dart` is the registry of what voice can do; the AI may only use ops listed there.
- `lib/logic/answers.dart`:
  - `answerText` for questions.
  - `reminderView` is the same reading for the answer and for the list remembered (with `alarmsOnly`).
  - `weekdaysSaid`, `contactMatches` (sound-alike matching only on the word as said).
- `lib/logic/ask.dart`: profile and topic questions (expiry, notes count, day agenda "৩১ ডিসেম্বর কী আছে?").
- `lib/logic/calendar_bd.dart` + `lib/logic/calendar_ask.dart`: Bangla and Hijri dates and the `bdHolidays` list.
  - **2027 has only fixed-date holidays.** Add Eid and the other moon-based dates when the government list comes out.
- `lib/logic/suggest.dart`: prompts shown while typing (`suggestPrompts`).
- `lib/services/ai.dart` + `lib/logic/ai_map.dart`: the AI tool schema (rules version `2026-10-18.4`) and its mapping. Ids from the AI are never trusted, and a confirmation never comes from the AI.
- `lib/services/notifications.dart`: notification channels — `reminder_alarm_v2` and `assistant_notes_vibrate`; push is `ma_server_vibrate` in `android/.../PushService.kt` and the manifest. All vibrate.
- `lib/screens/chat_home.dart`: the chat UI.
  - The input is multi-line (↵ = new line; the round button sends).
  - `_actionRow` puts the last answer's buttons low on the right, by the thumb. `_choiceRow` does the same for yes/no, with "হ্যাঁ" at the right end.

**Capability matrix by voice:**
- Full: ধার-দেনা, আয়-ব্যয়, accounts, savings, DPS, habits, projects, calendar.
- Partial: shop (no receipts), medicines (no new medicine or times), health (no vaccines), memory, notes, settings (no AI/lock/language), backup (no restore), trash, special days, zakat.
- Page only: diary, blood requests, reading files (no OCR).

## 6. Signing key (important)

- The release keystore is **`my-assistant-release.jks`**: alias `myassistant`, signer SHA-256 `fc6cff35…`.
- The owner has the key and its password from 13 Oct (the file "My-Assistant-signing-key.txt"). Ask him to attach it when an APK must be signed.
- Never commit it, print the password, or put it in logs.
- If it is lost, updates can no longer install over the existing app.

## 7. What was done on 18 Oct (v2.23 → v2.25)

- **2.23.0 — collective selection.** Built from the owner's spec "আজকের কাজের তালিকা দাও → এইগুলো সব মুছে দাও".
  - Result sets, typed selections, one confirmation for deletes, corrections ("না, শেষের দুটো"), "থাক" to cancel.
  - Undo of a batch, honest partial results.
  - An AI `bulk` action with a typed `select`.
  - `test/bulk_test.dart` has 40 scenarios.
- **2.24.0 — fixes from the device (b30 screenshots):**
  - "হিসাব" was read as a verb (it became a to-do); "আয়-ব্যয়ের হিসাব" now gives a summary.
  - Dated lists in one sentence; the birthday ring time is kept; weekday ranges for alarms; alarm questions are answered.
  - "জন্মদিন ছাড়া সব" keeps every birthday.
  - পাওনা/দেনা bulk asks "শোধ ধরব, নাকি মুছব?".
  - Topic policy.
  - Contacts: the full name is used ("রবিন হায়দার"); no more sound-alike on a stripped word (হায়দার ≠ Ahad).
  - Calendar questions; context next-step chips; multi-line typing; vibration channels; thumb-zone buttons.
- **2.25.0 — fixes from the device (b33 screenshots):**
  - Deleting reminders by date; a to-do with a clock time gets a linked reminder.
  - Year goals ("২০৩১ সালে…"); "সকল" = "সব".
  - Events on days ("২৩ এবং ২৪ তারিখে দাওয়াত"), then "দুপুরে দাওয়াত" asks the hour for both days.
  - A non-time answer to "কয়টায়?" is never a time.
  - Papers by name ("আমার পাসপোর্ট দাও").
  - "X আজ N টাকা দিবে" is a plan, not a payment. A full contact name picks that person. "ফেরত" beyond what was owed is asked about once.
  - A numbered list under "এই বছরে কিছু কাজ আছে," becomes year-plan to-dos.
  - The notes list, backup on/off status and the expiry question all answer now.
- **Regression tests from the device screenshots:** `test/screens_1018_test.dart`, `screens_1018b_test.dart`, `screens_1018c_test.dart`, `followups_test.dart`, `calendar_ask_test.dart`.

## 8. Open items and known weak spots (next steps)

1. **Waiting for device feedback on b34.**
   - Are the thumb-zone buttons at a good height?
   - Is there vibration on push, reminders and the assistant's messages? Not verified on a phone.
2. **Two wrong ledger entries on the owner's phone** came from older builds: ইমরান ১৫,০০০ and rafi ৯০,০০০. He may delete them from the লেনদেন page.
3. **Small wording issues:**
   - The goal title stays "কোটিপতি হবো" (it could read "কোটিপতি হওয়া").
   - "এই এপকে বাজারে ছাড়া" loses "এই" (the leading-word stripper in `tidySpeech`).
   - The paper answer says "০টা ছবি" when a document has no photos; hide the count when it is 0.
   - `bnTime` gives "১টা-এ" (it should read "১টায়"); this is old app-wide style.
4. **Not possible by voice yet** (`voiceCaps.notYet`):
   - new medicines and medicine times
   - receipts
   - vaccines and checkups
   - restore from backup
   - AI on/off, lock and language
   - diary continuation
   - OCR of files
5. **Calendar:** the 2027 Eid and other moon-based holidays are missing (the app says so honestly).
6. **Never verified:**
   - a real microphone or audio
   - the live AI — tests use fixed AI answers in the schema's shape
   - real notification delivery
   - real Drive backup

## 9. How to work a screenshot batch (the routine that worked)

1. List every finding back to the owner in Bengali, numbered, with what went wrong.
2. Write `test/screens_<date>_test.dart` replaying each conversation word for word. Seed the data the screenshots show (reminders, contacts, docs, ledger). Assert on data, not only on text.
3. Run it and watch every case fail first. Probe `parseAll(...)` to see which command a sentence becomes.
4. Fix the root cause in the shared layer:
   - `tidySpeech` for wording variants
   - a rule's precondition (for example, `ReminderQuery` only for questions)
   - the resolver
   Never special-case one sentence.
5. Run the whole suite, analyze, and `tool/i18n_missing.py`.
6. Bump the version, commit, build, re-sign, verify `fc6cff35`, and send. Report in Bengali: a table of problem, cause and now; then what is unverified; then the two file names.
