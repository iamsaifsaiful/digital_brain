# My Assistant — handoff for the next Claude session (23 Oct 2026, app 2.45.0-b96)

> **To Claude:** the owner (Saif — his email is only for identifying him) writes in Bengali; reply and report in Bengali. He tests on his own Android phone and sends screenshots. For each finding: reproduce it in a test first, find the root cause, and fix it so similar cases are fixed too. Then run the whole suite, build a signed APK and send it. He has delegated decisions: "তুমি আমার থেকে বেশি বুদ্ধিমান। তুমি সিদ্ধান্ত নিয়ে পরের কাজ গুলো কর". His goal is "যত কম খরচে উন্নত সেবা দেওয়া গ্রাহকদের", without loss to the company ("কোম্পানির যেন, লস না হয়").
>
> This file replaces the 18 Oct handoff (v2.25.0-b34). Everything from 18 Oct to 23 Oct is summarised here. The detailed reports are in `docs/` and in the claude.ai Project "App Development" (`claude/*.md`). The live to-do list is `docs/pending-2026-10-22.md`.

---

## 0a. Update 23 Oct (later): 2.46.0-b97, plugin 1.16.0, admin 1.6.0+8
- Old notifications on open: MainActivity drops a reminder intent when the activity is rebuilt (savedInstanceState != null) and on `clearLaunch` after Dart handled the launch tap; `schedule()` schedules each notice on its own (one bad past one no longer stops the rest), repeating ones go to `nextAhead()` (month-end safe).
- নোটিফিকেশন page (`lib/screens/notice_screen.dart`, bell on Home + আরও): next 7 days (`expandPlan`) and 30 days of history (`addPassed`), kept encrypted in the key vault (`notice_log`); `lib/logic/notice_log.dart`.
- Server log: table `ma_notice_log` (notices.php), `POST /notices/plan` (kind + time only; a title only for kind `server`), `GET /notices/log` (member's pushes), every `ma_push_member` and broadcast logged; site নোটিফিকেশন tab "কার কাছে কী গেছে" + "এখনই পাঠান"; admin `GET /admin/notice-log` + admin app page. e2e covers it.
- বকেয়া in অন্যান্য হিসাব (owner: simple, and like ধার-দেনা — আমি পাবো / আমি দেবো; who, what/why, amount, pay date → reminder; giving is not আয়/ব্যয়; money collected is আয়, money paid is ব্যয়): `LedgerEntry.projectId` (lent/borrowed = বকেয়া, received/repaid = আদায়/শোধ + a project income 'বকেয়া আদায়' / expense 'বকেয়া শোধ'); `lib/screens/project_dues.dart`; helpers `projectDues/projectDueTotals` in logic/ledger.dart; reminder via `_dueReminder` (Pro, like loans); paid in full clears the pay days; PDF table; deleting a project trashes its dues.
- হিসাবে খোঁজা (owner): `lib/logic/person_money.dart` (`personMoney`: cash whose note/category names the person as a word, all their loans and dues; net = income − expense + personal loan cash flow + still owed), `lib/screens/money_search_screen.dart` (search icon on the হিসাব title; card on the person page), and `ledgerAnswer` person adds income/expense/net.
- Business mode: switch hidden unless already on; onboarding "business" no longer turns it on (owner: later). Member profile: owner said not needed.
- Profile plan badge (`PlanBadge` in settings_parts.dart: ফ্রি / প্রো · until / ট্রায়াল, tap → ProScreen; Play app only). Pro coming on adds a one-off local notification `nudge:pro` (Brain._oneOff) — from a server grant only when the phone has no push token (the server pushes its own).
- Persona review + next ideas: `docs/persona-review-2026-10-23.md`.

## 0b. Update 23 Oct (evening): plugin 1.17.0, admin app 1.7.0+9 (app unchanged, 2.46.0-b97)
- কোম্পানির হিসাব (owner): `finance.php` — tables `ma_fin_entries` (hand-written আয়/খরচ) and `ma_fin_investors`; `ma_fin_summary()` = approved payments (Pro given free has no payment, so never counts) + hand income; AI bill from the usage table × usd_bdt + hand costs; investors apart; cash = invested + income − expense. Site tab "হিসাব" and admin `GET /admin/finance`, `POST /admin/finance/entry|investor`, `POST|DELETE /admin/finance/{entry|investor}/{id}` — site owner only (manage_options) in both. Admin app: dashboard card → FinancePage. e2e covers it.

## 0c. Update 23 Oct (night): 2.47.0-b98 (plugin and admin unchanged)
- Second persona walk (21–40) with the real on-phone model: findings 25–40 in `docs/persona-walk-2026-10-23.md`. Walk scripts are `test/persona/*_walk.dart` (renamed from `_test` so the normal suite skips them; they need the model socket server and write `test/persona/out/`). Run: `MODEL=1 flutter test --no-pub --update-goldens test/persona/p5_walk.dart`. The probe: `test/persona/probe_walk.dart --dart-define=LINES='a|b'`.
- Phone model answers: `phoneModelCommands` (nlu/router.dart) answers only when the rules are weak and the model is sure (`Brain._understandAll`, source `nlu_phone`); `nluLoaderForTests` in nlu/shadow.dart.
- Shared fixes: number words 21–99 in `findAmount` (from menus.dart `_bnNumbers1to99`; নয় only before a multiplier); `asksWh()` — a question never marks a to-do done; `yesNo` treats দিন/দাও/হবে as no yes inside a wh-question; `_looksNew` counts an `OpenPlace`; `ownMoneyAsked` + `_spanCashAnswer` (own money of a time: in / out / left, one খাত); project questions (কত আছে / লাভ) → that project; first-person give in a project is spending; `Repeat.every2h/3h/4h/6h` (voice only; pickers show them only when chosen); `taskForReminderQuery`; expiry answer falls back to a to-do about the paper; day + "কী কী" → that day's list.
- UI: বকেয়া from the অন্যান্য হিসাব tab (`AllDuesSection`, "বকেয়া যোগ" picks or creates a হিসাব); unset bills on the reminders page as chips.

## 0. Where things stand right now

| Part | Version | Where |
|---|---|---|
| Android app (play_preview edition, `.preview` package) | **2.45.0+96**, build **b96**. `pubspec.yaml` and `appVersion` in `lib/screens/more_screen.dart` | release `preview-2.45.0-build.64` (CI run number ≠ app build number) |
| WordPress plugin `my-assistant-accounts` | **1.15.0** (`Version:` header and `MA_ACC_VERSION`) | `tool/wordpress/my-assistant-accounts/` |
| Admin app | **1.5.0+7** | `admin_app/`, release `admin-1.5.0-build.10` |
| On-phone NLU model | `2026.10.22-bert2`, SHA-256 `b849a629…17551f` | release `nlu-model-2026.10.22-bert2`; a draft is on the server |

- **Branch:** `next-update`, all work is pushed. Last commit: `53f9e98` ("2.45.0: own ringtone file; …"). The working tree is clean.
- **Last files sent to the owner:**
  - `My-Assistant-Play-Preview-2.45.0-b96-{arm64,armv7}.apk`
  - `My-Assistant-Admin-1.5.0-b7-{arm64,armv7}.apk`
  - `my-assistant-accounts-1.15.0.zip`
- **Next numbers:**
  - App: 2.46.0+97 (b97).
  - Plugin: 1.16.0.
  - Admin: 1.6.0+8.
  - CI run numbers continue from preview build.65 and admin build.11.
- **Tests:** 2176 Flutter tests pass. The full run takes about 16 minutes; run it alone, not alongside another test run (`master100` C58 once failed under parallel load and passes alone).
  - Admin app: 8 tests.
  - WordPress e2e: `ALL OK`.
  - `flutter analyze`: 24 "info" lines, 0 warnings, 0 errors.
  - `tool/i18n_missing.py`: 0 missing.

## 1. The owner's standing rules (keep them all; quoted ones verbatim)

**Never**
- "পাসওয়ার্ড, ভল্ট, PIN, OTP, স্বাস্থ্য, ওষুধ আর অন্য অ্যাপের মেসেজ কখনো ফোনের বাইরে যাবে না। API key APK-তে থাকবে না। প্যাকেজের নাম আর সাইনিং বদলাবে না। ব্যবহারকারীর ডেটা মুছে বা এনক্রিপশন দুর্বল করে কোনো সমস্যার সমাধান করবে না।"
  - **Exception decided by the owner on 22 Oct:** a family member's medicine reminders and the heirs' copy may leave the phone, but only end-to-end sealed (X25519 + AES-GCM), so the server cannot read them.
- "স্ক্রিনশট দেখে নতুন regex নিয়ম লিখবে না।" Fix causes in shared layers; never special-case one sentence.
- "যাচাই-সেটের বাক্য বা তার কাছাকাছি রূপ কখনো শেখানোর ডেটায় যাবে না।" This covers the NLU gold, held-out and validation sets.
- "কোনো সংখ্যা দাবি করবে না যা নিজে চালিয়ে মাপোনি।"
- "বাস্তব audio test না করে voice recognition সম্পূর্ণ ঠিক হয়েছে বলে দাবি করবে না।"
- "অনুমতি ছাড়া paid service চালু করো না।"
  - Example: the paraphrase step costs about $0.37 and is **not** approved yet.
- Never commit the keystore, print its password, or put it in logs. Never ask for the owner's Google password.
- The owner's Gemini key was once visible in a screenshot: never reproduce it.

**Always**
- List what is **not** verified, honestly, in every report.
- Every new Bangla UI string (`tr()`/`trf()`) gets an English entry in `lib/logic/strings_en.dart`. Then `python3 tool/i18n_missing.py` must print "0 missing".

**Decisions taken this period (owner's words)**
- Server settings hold only things to set. Costs and reports go in their own tab ("AI খরচ").
- "এপে যা করা যাবে, সার্ভারেও তাই, এপেও তাই": the site and the admin app have full parity. One PHP implementation serves both (`ai-admin.php`).
- Family is **Pro**: Pro is needed to add members and to send. Joining and receiving are free.
- Live location only when the member allows it; it is meant for finding a lost phone too.
- "যত ট্যাব থাকবে। সব সোয়াইপ হবে।"
- Heirs ("উর্ধাধিকার") can see photos too.
- The district follows the phone's location (default on). Choosing a district by hand turns it off.
- Remaining format choices from earlier still hold: voice "আর কিছু বলতে চান?" stays off.

## 2. Environment, build, sign, send (the exact routine that works)

```bash
export PATH=/opt/fl/flutter/bin:$PATH PUB_CACHE=/root/.pub-cache
cd /home/claude/digital_brain            # clone of iamsaifsaiful/digital_brain, branch next-update
flutter analyze --no-pub                 # 24 infos is normal
flutter test --no-pub                    # ~16 min; one file: flutter test --no-pub test/x_test.dart
python3 tool/i18n_missing.py             # "0 missing"
bash <scratchpad>/e2e.sh                 # WordPress e2e on SQLite -> "ALL OK" (runs tool/wordpress/test/e2e.php)
(cd admin_app && flutter test --no-pub)  # 8 tests
```

**Environment notes**
- Do **not** run `dart format` on large existing files. The formatter re-flows whole files (it happened to `brain.dart`, `more_screen.dart` and `notifications.dart`, and was reverted). Format only new files, or keep edits in the existing style.
- `android/app/build.gradle.kts` is gitignored, because it is generated. Dependencies and minSdk are added by `tool/setup_platforms.sh` (for example `play-services-location:21.3.0`).
- GitHub GraphQL is blocked from the sandbox; use REST (`gh api …`). Releases can't be created from the sandbox (403), so builds go through workflows.

**Build steps**
1. Bump `pubspec.yaml` and `appVersion`. For the plugin, bump `Version:` and `MA_ACC_VERSION`; for the admin app, bump `admin_app/pubspec.yaml`.
2. Commit with these trailers:
   ```
   Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
   Claude-Session: https://claude.ai/code/session_01DGoFS7hoMMTew92zFE2BTR
   ```
3. Push: `git push origin next-update`.
4. Start the builds:
   - `gh workflow run play_preview.yml --ref next-update -R iamsaifsaiful/digital_brain`
   - Admin app: `admin_app.yml`.
   - Wait with `gh run view <id> --json status,conclusion`.
5. Find the release assets:
   ```
   gh api "repos/iamsaifsaiful/digital_brain/releases?per_page=6" -q '.[] | .tag_name+" "+([.assets[]|(.id|tostring)+":"+.name]|join(","))'
   ```
   Download each with `gh api repos/…/releases/assets/<id> -H "Accept: application/octet-stream" > in/x.apk`.
6. **Re-sign with the owner's key.**
   - The keystore is the attached `…-my-assistant-release.jks` (alias `myassistant`). The password is in the attached `…-My-Assistant-signing-key.txt`.
   - **Careful:** that file has a line that is just `পাসওয়ার্ড:`, and the value is on the **next non-empty line**. An earlier line also contains the word পাসওয়ার্ড inside a sentence.
   - Read it only with a script, into a `mktemp` file under umask 077: `KP=$(cat f); shred -u f`.
   - Sign with `java -jar /home/claude/signer/uber.jar -a in.apk --allowResign --ks … --ksAlias myassistant --ksPass "$KP" --ksKeyPass "$KP" -o out | grep -F -v -- "$KP"`, then `unset KP`.
   - **Never echo or preview any line of that file.** On 22 Oct a debug print showed the first 12 characters of the password once. The owner was told; nothing more leaked.
   - Check the certificate: `keytool -printcert -jarfile x.apk` → SHA256 `FC:6C:FF:35:…:69:D0:01:4F`.
7. Name and send the files:
   - Names: `My-Assistant-Play-Preview-<ver>-b<N>-{arm64,armv7}.apk`, `My-Assistant-Admin-<ver>-b<N>-{arm64,armv7}.apk`, and the plugin zip `cd tool/wordpress && zip -qr <scratch>/my-assistant-accounts-<ver>.zip my-assistant-accounts`.
   - Send them with SendUserFile (display "attach").
8. Update the docs in `docs/`, and in the Project with `project_write` (`claude/<name>.md`, using `local_path`).

## 3. What was done from 18 Oct to 23 Oct (by release)

**18–19 Oct: device-screenshot rounds and language audits (2.26 → 2.37)**
- **2.26–2.31**
  - Chat continues after leaving.
  - History button on home.
  - Swipe between tabs.
  - Warranty date read from a photo.
  - Gold/silver price of the day.
  - Every paper and photo is read on the phone (text reading), with details offered as fields.
  - Vibrating channels renewed.
  - Preview builds can sign in CI when keystore secrets are set. We still re-sign locally.
- **2.32–2.34**
  - Tabs follow the finger.
  - Comma lists under a heading.
  - Temperature on home and in chat.
  - Compass with qibla.
  - Spending check in percent.
  - A daily money thought.
- **2.35–2.36**
  - Fixes from the b45 screenshots: accounts by name, mixed money, ordinals, months, per-task reminders.
  - To-do audit: 60 scenarios, all pass (`docs/tasks-audit-2026-10-19.md`).
- **2.37.x**
  - Master-100 case matrix (`docs/master100-*.md`).
  - b85 regression fix (`docs/regression-b85-2026-10-19.md`).
  - 500-phrasing intent corpus plus 40 held-out (`docs/intent500-2026-10-19.md`).
  - "Angles" corpus: 343 multi-turn plus 35 held-out (`docs/angles-2026-10-19.md`).

**22 Oct: the cost/understanding programme ("NLU"), steps A–I. Details: `docs/nlu-*.md`.**
- **Step A (2.38):**
  - Haiku for every AI message; Sonnet only on escalation for Pro.
  - Cached instructions; cost counting per model.
  - Server 1.9.0: budgets and answer sources.
- **Step B:** intent spec, 65 intents (`docs/nlu-spec.md`; `tool/nlu/spec/`).
- **Step C:**
  - Gold set: 1593 turns.
  - Baseline of the old rules (`docs/nlu-baseline-2026-10-22.md`).
- **Step D:** template data generator (about 36k labelled sentences), noise, context (`docs/nlu-data-2026-10-22.md`).
- **Step E/F (2.39):**
  - BanglaBERT-small joint model in TFLite on the phone, in **shadow** mode (it reads every message and acts on nothing).
  - Dart tokenizer/normalizer with parity tests.
  - Vendored `tflite_flutter`.
  - Model comparison: `docs/nlu-models-2026-10-22.md`.
- **Step G (server 1.10.x):**
  - `nlu.php`: mode off/shadow/on, model rollout %, cloud reading (`/nlu/resolve`: Gemini 3.1 Flash-Lite for free members, Haiku for Pro, Sonnet on escalation), budgets that follow income, and a self-test button (`docs/nlu-server-2026-10-22.md`).
- **Step H:** admin app "AI ও বোঝা" tab.
- **Step I (2.40):**
  - Consented learning samples (names removed; numbers and secrets never sent).
  - Model download with a SHA-256 check and rollback.
  - Retrain loop in CI with the narrow key `MA_NLU_CI_KEY` (set and working).
- **"On" mode (2.41/2.42):**
  - When the rules and the model agree, the AI is skipped.
  - When they disagree, members without AI get the cloud reading and two of three decide.
  - Gold-set results: the router skips about 31% of the messages that would have gone to the AI; the rules are right on 94.3% of those; rules+model agreement is 98.3% correct. This was measured on the gold set only, not on live traffic.
- **2.42:**
  - The model is no longer in the APK; it downloads from the server on Wi-Fi only (≤40 MB, SHA-256 checked).
  - "আরও" shows the model's state.
- **Server 1.11–1.12, admin 1.2–1.3:**
  - Site "AI খরচ" tab (reports only).
  - Site "AI মডেল" tab (mode, versions live/%/rollback/draft, review).
  - Parity with the admin app (`ai-admin.php`).
  - `nlu_publish.yml` puts a model on a release plus a server draft.

**22 Oct: new features (2.43.0, plugin 1.13.0, admin 1.4.0). Details: `docs/family-zakat-blood-2026-10-22.md`.**
- **যাকাত as its own menu** (`lib/logic/zakat.dart`, `lib/screens/zakat_screen.dart`, `ZakatBook` in AppData):
  - Every line comes from the records, with its source and date.
  - Any line can be ticked out; items can be added by hand; there is a zakat day every 354 days and a short learning panel.
  - Voice "আমার যাকাত কত?" uses the same count.
  - The old zakat tile inside money was removed.
- **ব্লাড ডোনেশন** (renamed from the request menu; removed from "আরও"'s রক্তদান section):
  - Request fields: for whom, problem, hospital, hospital location, district, date, contact, group, bags.
  - The list covers the whole country, filtered by group and district.
- **ফ্যামিলি (Pro):**
  - Members are invited by email with a relationship and accept in the app.
  - Per-member permissions: task, reminder, medicine, note, location. At most 20 members.
  - Items sent between members are sealed for the receiver's phone key.
  - Code: `lib/services/family_crypto.dart`, `lib/state/family_state.dart`, `lib/screens/family_screen.dart`, server `family.php`.
- **Live location:**
  - The phone answers a silent push even when the app is closed (`LocationShare.kt`), sealed with a location key that rotates when someone is removed.
  - Shows a prominent disclosure before asking for "always" location.
  - **Google Play needs a background-location declaration.** Its text is in the family doc.
- **উত্তরাধিকার (heirs):**
  - The member chooses heirs and which parts they may see (money, notes, docs, tasks, contacts; health and vault only if ticked).
  - A gzip copy is sealed per heir and uploaded at most every 6 hours.
  - The heir may open it if the member gave "এখনই পুরো অ্যাক্সেস", or after a death report with a certificate photo, an admin check (site "উত্তরাধিকার" tab or admin app), and 14 days without the member cancelling.
- The notification small icon is now the app's "আ" mark. Dark mode: 34 pages screenshotted; the chat send button was fixed.

**22 Oct: 2.44.0 (plugin 1.14.0)**
- **Multi-select** (`lib/ui/pick.dart`):
  - Long-press a row to start, tap to add or remove, "সব" for all.
  - Pages and actions:
    - Tasks: done/reopen, date, move to list, share, delete.
    - Income/expense: total, change category, share, delete.
    - Transactions: total, share, delete.
    - Reminders: off/on, delete.
    - Notes: change section, share, delete.
  - One-tap undo restores the whole batch (`brain.undoLastDeletes(n)`). Back only ends the picking.
- **Heirs see photos:**
  - Note and doc files are sealed with `heir_files_key`, which travels inside the heir's copy.
  - Uploaded on Wi-Fi only, ≤4 MB each.
  - Server: `POST /family/files` and `GET /family/{id}/files/{file}`.
  - The heir taps "ছবি দেখুন".
- **Swipe:** all tabs swipe. ব্লাড ডোনেশন uses `TabPages`; pro, calendar and health use the new `SwipeTabs`.
- **Bottom sheets:** all 50 bottom sheets go through `showAppSheet` (bottom SafeArea), so buttons are no longer under the navigation bar.
- A friendly message appears when the site plugin lacks the family routes.

**23 Oct: 2.45.0 (plugin 1.15.0, admin 1.5.0)**
- **Copy all review rows in one click:**
  - Site "AI মডেল" › পর্যালোচনা has "সব কপি করুন (Nটা)". The admin app has the same button.
  - It copies the plain text from `ma_nlu_review_text()`: mode, live model, 30-day sample count, error-signal rate, weakest intents, then each unlabelled row (up to 500) with its sentence (names removed), alternatives, phone/cloud/final intents, signal, and app and model versions.
  - The owner will paste this to Claude.
- **Own ringtone:**
  - "নিজের অডিও ফাইল যোগ করুন" accepts any audio up to 15 MB.
  - Android 10+: copied into MediaStore at Alarms/My Assistant. Android 7–9: the app's files via FileProvider, with a read grant to the system UI, re-granted on app start (`CustomTone.kt`).
  - The previous own tone is removed when replaced; an unkept file is removed on leaving the page.
- **District follows the phone:**
  - "ফোনের লোকেশন অনুযায়ী" is the default. On open and resume (at most every 20 minutes), the nearest of **64** districts is chosen (`nearestPlace`; the list grew from 24 to 64).
  - The location is read on the phone only (`LocationShare.here`, balanced accuracy).
  - Choosing a district by hand turns this off.
- **Home:** the weather moved under the date (it overlapped before) and shows the district name.

## 4. Architecture additions since 18 Oct (where to look)

The chat pipeline in §5 of the old handoff is unchanged in spirit. It now passes through the router:
- **NLU router (`lib/nlu/router.dart`):**
  - `nluAgrees`, `nluMaySkipAi`, `rulesWeak`, `CloudReading`, `nluVote`, `commandsFromReading`.
  - `brain.understandAll(... model, nluState, nluKind)`.
  - `_nluPrivate` keeps health and secret messages on the phone.
- **Other NLU files:**
  - Model files: `lib/nlu/model.dart`, `updater.dart` (Wi-Fi only, `wait-wifi`/`too-big`), `shadow.dart`, `samples.dart` (`delexicalize`).
  - Python and CI: `tool/nlu/` (spec, data, train, retrain, publish); workflows `nlu_train.yml`, `nlu_retrain.yml`, `nlu_publish.yml`.
- **Server plugin files:**
  - `my-assistant-accounts.php` (tabs, install), `nlu.php`, `nlu-intents.php` (generated from the spec), `ai.php`, `ai-admin.php` (shared site/admin actions), `admin-view.php` (site UI and `ma_acc_script` copy handler), `admin-api.php`, `family.php`, `blood.php`, `push.php` (data-only push when title is ''), `payments.php`, `feedback.php`, `notices.php`.
  - Tests: `tool/wordpress/test/e2e.php`.
- **Admin app:** `admin_app/lib/{api,ui,ai_page}.dart`.
- **UI helpers in `lib/ui/widgets.dart`:** `TabPages`, `SwipeTabs`, `showAppSheet`, `ListRow(onLongPress, picked)`. `lib/ui/pick.dart` holds `Picks`, `PickBar`, `PickMark`, `deletedSnack`.
- **Tests added in this period (examples):**
  - `test/pick_test.dart`
  - `test/place_tone_test.dart`
  - `test/zakat_family_test.dart`
  - `test/nlu_*_test.dart`
  - `test/dark/dark_shots_test.dart`: run with `SHOTS=1 … --update-goldens` to write PNGs to `test/dark/shots/` (gitignored).

## 5. What is left

### A. Waiting on the owner (these block later steps)
1. **Install plugin 1.15.0** on the site. It contains everything from 1.12–1.14. Without it, the family page says "প্লাগিন হালনাগাদ করতে হবে".
2. **Model:** make `2026.10.22-bert2` **live at 100%** from site "AI মডেল" (or admin app › AI › মডেল).
   - Open the app on Wi-Fi; "আরও" should show "নামানো আছে · 2026.10.22-bert2". If not, send a screenshot.
3. Turn on "কথা বোঝা আরও ভালো করতে সাহায্য করুন" on his own phone.
4. **Mode "চালু"** for 5–10% of members first. After 2–3 days, send the review via the new **"সব কপি করুন"** button, plus the admin summary.
5. Replace the Gemini key that was seen in a screenshot.
6. **Google Play Console:** background-location declaration (text and video steps are in `docs/family-zakat-blood-2026-10-22.md`).
7. **Two-phone family test:** add a member, send a medicine reminder, "এখন কোথায়?" with the app closed, heir "এখনই পুরো অ্যাক্সেস", and photos.
8. Screenshots of any remaining dark-mode or UI problems.
9. **Try on his phone:** own ringtone (does it ring with the screen locked?), district auto-change, multi-select bar, swipe on every tab.

### B. Claude's next work, in order
1. **When the owner pastes the review text:**
   - Group the errors by kind.
   - Propose the right label for each, applied with the site's buttons or `POST /admin/nlu/review/{id}`.
   - List the training additions. Gold, held-out and validation sentences are never used.
2. **Step J — structural gaps:**
   - Several actions in one message.
   - Follow-ups that depend on the previous turn.
   - Corrections ("না, কাল নয় পরশু").
   - The rest of step F (resolve/validate/cards/dialog_state).
   - Start after 2–3 days of samples (from about 25 Oct).
3. **Retrain:**
   - Push to the `nlu-retrain` branch → gate → draft, when there are a few hundred samples.
   - Fix first: in the first retrain cycle the **call intent fell from 100% to 0%** and the gate rejected the model. The likely cause is the slot-tag/intent_only change.
4. **Step K — rollout:**
   - "চালু" mode 10% → 25% → 50% → 100%, one step per week, each with the owner's OK.
   - Then remove the parts of the old `parseAll()` that the model and the cloud handle well.
5. **Cloud latency:** Gemini takes about 5.5 s; reduce it with a shorter prompt or caching.
6. **Admin app summary:** costs visible to the owner only, as on the site (15–20 min; needs his "হ্যাঁ").
7. **Voice to family:** "আম্মাকে রাত ৯টায় ওষুধের রিমাইন্ডার দাও", after family works on real phones.
8. **Location:** periodic sending and location history, only if the owner wants them (needs Play approval).
9. **Multi-select on more pages:** contacts, documents, medicines, savings, if asked.
10. Remaining dark-mode fixes, after his screenshots.

### C. Needs the owner's permission (costs money)
- The AI paraphrase step for training data (`tool/nlu/data/paraphrase.py`): about $0.37 (~৳45) once on Anthropic. Not approved yet.

### D. Not verified (say so in reports until it is)
- **NLU on real phones:** model download, start, speed and memory.
- **Live site:** the new tabs and endpoints on the real site (MySQL); tests use SQLite. Uploads up to 6 MB depend on the site's PHP limits. Emails from the real site, including the heir emails.
- **Gemini quality:** not measurable from the sandbox.
- **Real voice:** actual voice recognition.
- **Family:**
  - Two real phones.
  - Location with the app closed, under different phone makers' battery savers.
  - Kotlin parts are only compiled in CI.
- **Own ringtone:**
  - Ringing on real phones.
  - Android 7–9 after a restart without opening the app (it may fall back to the default tone).
  - Different makers' file pickers.
- **District:**
  - Auto-change on a real phone.
  - The coordinates of the 40 new districts were written from knowledge, not checked against a source; the effect on prayer times is about a minute at most.
- **UI:** the multi-select bar on small screens and with large text.
- **Data:** the retrain cycle with real member samples.

## 6. How to work a screenshot batch (unchanged routine)
1. List every finding back to the owner in Bengali, numbered.
2. Write `test/screens_<date>_test.dart` replaying each case and seeding the data shown. Assert on data, not only on text.
3. Watch every case fail first, then fix the root cause in the shared layer (`tidySpeech`, a rule's precondition, the resolver, a shared widget). Never write a new regex for one sentence.
4. Run the full suite, analyze, i18n and e2e.
5. Bump the versions, commit, build, re-sign, verify `FC:6C:FF:35…`, and send.
6. Report in Bengali: what changed, what is unverified, then the file names.
