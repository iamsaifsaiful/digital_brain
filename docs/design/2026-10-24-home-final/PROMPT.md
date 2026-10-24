# পুরো অ্যাপের নতুন UI — নির্দেশ (প্রম্পট), ২৪ অক্টোবর ২০২৬ (চূড়ান্ত হোম ধরে)

> **মালিকের জন্য:** নতুন অ্যাকাউন্টে Claude-কে নিচের "PROMPT শুরু" থেকে শেষ পর্যন্ত পেস্ট করুন। সাথে:
> - GitHub রিপোজিটরি `iamsaifsaiful/digital_brain`-এ ঢোকার অনুমতি দিন।
> - সাইনিং key-র দুটো ফাইল দিন (`my-assistant-release.jks`, `My-Assistant-signing-key.txt`)।
>
> নকশার ছবি আর HTML রিপোজিটরিতে আছে: `docs/design/2026-10-24-home-final/`। এই নির্দেশ আগের ২৮-পাতার নকশাকে (`docs/design/2026-10-24-new-ui/`) বাতিল করে।

---

## PROMPT শুরু

You are continuing work on **My Assistant**, a Bengali voice-first personal assistant (Flutter, Android). The owner (Saif) writes in Bengali; **reply and report in Bengali**. He delegates decisions to you ("তুমি আমার থেকে বেশি বুদ্ধিমান। তুমি সিদ্ধান্ত নিয়ে পরের কাজ গুলো কর") within his rules. His goal is "যত কম খরচে উন্নত সেবা দেওয়া গ্রাহকদের", without loss to the company.

**Task: give the whole app a new UI. The owner approved a final HOME screen design; every menu and section of the app must follow the same UI/UX language.** It is a visual and UX change: the same features, data, voice flow and behaviour.

### 0. Read first
1. `git clone https://github.com/iamsaifsaiful/digital_brain && cd digital_brain && git checkout next-update`.
2. **`docs/HANDOFF.md`** covers the rules, the build/sign/send routine and the architecture. Follow it exactly.
   - It was written at 2.45.0. Other sessions have kept working since then; on 24 Oct the branch was at **2.50.2+105**.
   - Run `git log --oneline 88fae63..HEAD` and read every commit message.
   - Read the newer reports in `docs/` (crowd/persona reports and others).
   - Take the real versions from `pubspec.yaml`, `MA_ACC_VERSION` in `tool/wordpress/my-assistant-accounts/my-assistant-accounts.php`, and `admin_app/pubspec.yaml`.
3. **`docs/pending-2026-10-22.md`** is the open to-do list.
4. **`docs/design/2026-10-24-home-final/`** — THE approved design:
   - `home.html` is the source of truth. Open it in Chromium; it shows the light and dark phones side by side at 390×844, and the prayer/sun slot animates. Its CSS gives the exact tokens, sizes and spacing.
   - `img/01-home-light.jpg`, `02-home-dark.jpg`: the first screen.
   - `img/03/04-home-full-*.jpg`: the whole scrolled page.
   - `img/05-ramadan-iftar-light.jpg`, `06-ramadan-sehri-dark.jpg`: the Ramadan states.
   - `img/07-prayer-sun-rotation.jpg`: the two rotating states.
   - The older `docs/design/2026-10-24-new-ui/` (warm paper, handwritten notes) is **superseded**. Do not use its look; use it only as a list of screens.

### 1. Hard rules (owner's words; never break)
- "পাসওয়ার্ড, ভল্ট, PIN, OTP, স্বাস্থ্য, ওষুধ আর অন্য অ্যাপের মেসেজ কখনো ফোনের বাইরে যাবে না। API key APK-তে থাকবে না। প্যাকেজের নাম আর সাইনিং বদলাবে না। ব্যবহারকারীর ডেটা মুছে বা এনক্রিপশন দুর্বল করে কোনো সমস্যার সমাধান করবে না।"
  - Exception: family medicine reminders and the heirs' copy may leave the phone, but only end-to-end sealed.
- "স্ক্রিনশট দেখে নতুন regex নিয়ম লিখবে না।"
- "যাচাই-সেটের বাক্য বা তার কাছাকাছি রূপ কখনো শেখানোর ডেটায় যাবে না।"
- "কোনো সংখ্যা দাবি করবে না যা নিজে চালিয়ে মাপোনি।"
- "অনুমতি ছাড়া paid service চালু করো না।"
- "বাস্তব audio test না করে voice recognition সম্পূর্ণ ঠিক হয়েছে বলে দাবি করবে না।"
- Always list what is **not verified**.
- **Keystore and password:**
  - Never commit the keystore, never print its password, never put it in logs.
  - Never ask for the owner's Google password.
  - The password file has a line that is just `পাসওয়ার্ড:`; the value is on the next non-empty line.
  - Read it only with a script into a `mktemp` file (umask 077), then `KP=$(cat f); shred -u f`.
  - **Never print or preview any line of that file.**
- Every new `tr()`/`trf()` Bangla string needs an English entry in `lib/logic/strings_en.dart`. Then `python3 tool/i18n_missing.py` must print **0 missing**.
- Do not run `dart format` on big existing files (it re-flows them). Format only new files.
- Before every push, run `git fetch && git rebase origin/next-update`. Never force-push; other sessions push to the same branch.
- **Owner's UI wishes from this design round:**
  - "ক্লিন মিনিমাল এবং প্রোফেশনাল".
  - Premium feel for young, educated, busy users (all of Bangladesh uses it).
  - "অহেতুক তথ্য লাগবে না".
  - Keep all information the screens have today. Something less important may be shrunk or moved behind a tap, never silently dropped; list every such move in your report.
  - The badge says **"প্রিমিয়াম"**, never "প্রো", anywhere in the UI.

### 2. Design language (from `home.html`) — implement first as tokens + a widget kit in `lib/ui/`

**Colour tokens** (put them in `lib/ui/theme.dart` class `C` via `_p(light, dark)`, and keep the old names mapped so nothing breaks):

| token | light | dark | use |
|---|---|---|---|
| bg | `#F5F7F6` | `#101916` | screen background |
| surface | `#FFFFFF` | `#19251F` | cards, bottom bar |
| surface2 | `#EDF2F0` | `#223129` | counters, date blocks, quiet chips |
| text | `#192E28` | `#EEF4EF` | main text |
| muted | `#667871` | `#A1B3A8` | secondary text, inactive icons |
| border | `#DFE7E3` | `#2D3D33` | 1 px hairlines on every card and divider |
| accent | `#087866` | `#8BD8BF` | primary buttons, active tab, links, checks, mic |
| accentSoft | `#E7F3EE` | `#223C31` | icon tiles, active-tab pill, soft chips |
| onAccent | `#FFFFFF` | `#102C21` | text/icons on accent |
| warning | `#92631C` | `#E5C487` | late / attention text |
| warningBg | `#FBF5E9` | `#2B281E` | attention card background |
| warningBorder | `#EBDFC5` | `#45402E` | attention card border, Ramadan chip border |

- **No drop shadows on cards.** Flat surfaces with 1 px `border`. That is the "clean minimal" look.
- The user-chosen accent (সেটিংস › চেহারা) may still recolour `accent`/`accentSoft`. The default is the green above.

**Type**
- Headings: Hind Siliguri 600 (bundled). Body: Noto Sans Bengali 400/500/600 (bundled). Latin falls back to a sans (Roboto/Inter), never a serif.
- **Sizes:**
  - Greeting / page title 25.
  - Section heading 17/600.
  - Card title 16/600.
  - Body 14.
  - Secondary 12–13.
  - **Minimum 11** anywhere (nav labels 11).
  - Big money 27/600.
  - Time on the next-item card 22/600, in accent.
- Bangla digits everywhere; ৳ for money.

**Shape and spacing**
- **Radii:** card 17; attention card 14; buttons 11; chips 9; icon tile 12; text field 15; mic button 17 (52×52); bottom-tab active pill 10.
- **Spacing:** page side padding 20; gap between a section heading and its card 6; between sections 16. Rows inside cards are 9–10 vertical, divided by hairlines.
- **Touch targets:** at least 44 px; nav items 52 px tall.

**Icons:** thin outline style (≈1.7 stroke, rounded caps), as the inline SVG symbols in `home.html`. In Flutter, use Material Symbols Rounded/Outlined at weight ≈300 or the existing icons with outlined variants. Be consistent.

**Kit to build (reuse everywhere)**
- **`AppScaffold`:** bg colour.
  - Main tabs get the bottom block = **composer** ("বলুন বা লিখুন — “রবিনকে ৫০০ দিলাম”", keyboard icon, 52 accent mic) + **5-tab nav** (হোম, দিনলিপি, হিসাব, সংরক্ষণ, আরও). The active tab has an icon in an `accentSoft` pill, label in accent 600.
  - This replaces the current `AssistantBar` look only; keep its behaviour, including where it is hidden today.
- **`PageTitle`:** main tabs use a 25/600 title with an optional muted subtitle. Sub-pages use a back chevron + 20–22/600 title + an optional right icon button (44, transparent, no box).
- **`SectionHeading(title, trailing)`:** trailing is either a counter chip (`surface2`, radius 6–9, 11.5 muted) or a link ("ক্যালেন্ডার ›", accent 600 12.5).
- **`AppCard`:** surface, 1 px border, radius 17, padding 13–14.
- **`ListRowX`:** optional leading (checkbox 22 radius 7 / icon tile / date block / avatar), title 14, sub 11.5–12 muted, optional trailing (chip, amount, chevron). Hairline dividers. It must keep `onLongPress`/`picked` for multi-select (`lib/ui/pick.dart`).
- **`AttentionCard`:** warning colours, icon, title 13/600, line 11.5, and an outlined action button ("ঠিক করুন"). Show **only one at a time**, the most important.
- **`PrimaryButton`** (accent filled), **`OutlineButton`** (surface + border), **`SoftChip`** (accentSoft + accent text), **`Counter`**.
- **`DateBlock`:** 44×46, surface2, day 17/700, month 10.5 muted.
- **`ToolTile`:** 22 icon in a 40 `accentSoft` rounded square, label 11.5 below.
- **`InfoRow`:** the weather row; a full-width strip between two hairlines.
- **`RotatingSlot`:** cross-fades two or more short facts every ~5 s with tiny progress dots. Respect "reduce motion": no auto-rotation then; tap or swipe to change. A tap opens the detail.

### 3. HOME (approved; build exactly like `home.html`) → `lib/screens/home_page.dart`
1. **Header:**
   - "শুভ সন্ধ্যা, সাইফুল" (`helloFor`; first name).
   - "শনিবার, ২৪ অক্টোবর".
   - "৮ কার্তিক ১৪৩৩ • ১২ জমাদিউল আউয়াল ১৪৪৮".
   - Right side: bell with an accent unread dot (`NoticeScreen`) and the avatar (`UserPhoto`) with a small **"প্রিমিয়াম"** badge for premium users.
   - The big sky picture (`HomeSky`) goes away; its facts move into the info row.
2. **Info row** between hairlines:
   - **Left:** weather "২৬° · পরিষ্কার · ঢাকা" (`brain.weatherNow`, district). Use a moon icon at night.
   - **Right — `RotatingSlot`, minimal text only:**
     - (a) the **next prayer** name + time, e.g. "এশা ৬:৩৮", with a mosque icon;
     - (b) "সূর্যোদয় ৬:০১" / "সূর্যাস্ত ৫:২৪", two lines, with a sunrise icon.
     - **In Ramadan** (Hijri month 9), slide (a) becomes "রমজান N" chip + "ইফতার ৫:২৪" (between Fajr and Maghrib) or "সেহরি শেষ ৪:৪৩" (from Maghrib to Fajr), with a moon icon.
     - **No countdowns, no day length, no "এখন … ওয়াক্ত" text** (owner: "অহেতুক তথ্য লাগবে না").
     - Times come from `sunTimes(now, placeNamed(brain.district))`, computed on the phone. Ask the owner whether sehri should end a few minutes before Fajr; until then use Fajr.
3. **AttentionCard** (one at a time, highest priority first):
   - Reminders may not ring (`AlarmBanner` logic), "ঠিক করুন".
   - The Google-login card (`GoogleStartCard`, dismissable).
   - The new-user "শুরু করার ৪টা ধাপ (x/৪)" (`StartTips`), until done.
4. **"আজকের কাজ"** + counter "৩/৫ শেষ":
   - **Next-item card:** "• এরপর · ২৬ মিনিট পর", title "আম্মাকে ফোন", meta "পরিবার · প্রতি শনিবার", time "৭:০০ সন্ধ্যা". Buttons: **ফোন করুন** (primary; only when the item has a phone/contact, otherwise the most relevant action), **হয়ে গেছে**, **পরে** (snooze).
   - **List card:**
     - "দেরি হয়ে গেছে · N" (warning) with rows and a "কাল করব" soft chip.
     - "আজ" rows with checkbox (done = strikethrough muted).
     - Peek line "কাল, রবিবার · ২টা কাজ, প্রথমটা সকাল ৯টায়".
     - Footer buttons "+ যোগ করুন" | "সব কাজ ও রিমাইন্ডার".
     - Use the existing `TodaySections` data and actions.
5. **"টাকার হিসাব"** + link "অক্টোবর · খুলুন ›" → হিসাব tab:
   - "হাতে থাকল ৳২২,৫৫০" with a wallet icon tile.
   - ↓ আয় (accent) / ↑ খরচ.
   - Two halves: "পাবো · ৩ জনের কাছে ৳২৪,৫০০" (+ "আজ রহিমের ফেরতের দিন" in warning colour when there is one) and "দেবো · ১ জনকে ৳১৫,০০০" (+ the next date).
   - Weekly line "এ সপ্তাহে আয়ের ৩১% খরচ — শখের খাতে ৮% ›" → `SpendHealthScreen`.
6. **"সামনের ছুটি"** + "ক্যালেন্ডার ›": two holidays with DateBlock, weekday and a "৫৩ দিন পর" counter. The owner wants it always on home.
7. **"সব সুবিধা · ১৪টা"**: a collapsible card (collapsed by default; remember the state per user). A 4-column ToolTile grid, all 14 in this order: কাজের তালিকা, রিমাইন্ডার, ডকুমেন্টস, নোট, যোগাযোগ, স্বাস্থ্য, অ্যালার্ম, পাসওয়ার্ড, ক্যালেন্ডার, কম্পাস, যাকাত, ফ্যামিলি, ব্লাড ডোনেশন, প্রিমিয়াম.
8. **"আজকের অর্থ-কথা":** a small quote card.
9. **Ad slot (free users only):** a quiet card below the quote, labelled "বিজ্ঞাপন".
10. Privacy line "🔒 আপনার তথ্য এই ফোনেই থাকে, তালাবদ্ধ".
11. **Bottom:** the composer + 5-tab nav (see the kit).

`EasyHome` (easy mode) keeps its own simple layout but uses the new tokens.

### 4. Every other screen: same language (no mockups; derive from the kit)
Apply these rules to **every** screen in `lib/screens/` (and sheets and dialogs):
- **Main tabs** (দিনলিপি `DiaryScreen`, হিসাব `MoneyScreen`, সংরক্ষণ `StoreScreen`, আরও `MoreScreen`) use the home header pattern:
  - Title 25/600 + a muted one-line subtitle, no box around the right-side icons.
  - Then sections built of SectionHeading + AppCard.
  - The composer + nav at the bottom, as today.
- **Sub-pages:** back chevron + title, flat bg, AppCards with hairlines, primary actions as a PrimaryButton or the accent mic/add placement the page already has.
  - Floating action buttons become a 52 accent rounded square (radius 17), placed like the mic.
- **Tabs inside pages** (হিসাব's আয়-ব্যয়/ধার-দেনা/অন্যান্য, ব্লাড ডোনেশন, প্রিমিয়াম, ক্যালেন্ডার, স্বাস্থ্য members):
  - A segmented control: `surface2` track, the selected segment `surface` with a 1 px border, text 13.
  - **Swipe must keep working** (`TabPages`/`SwipeTabs`).
- **Lists:** ListRowX with hairline dividers inside one AppCard per group. Amounts are right-aligned, 14–15/600: income in accent, money going out in text colour, debts to give in warning colour.
- **Status:** chips (SoftChip / warning chip) instead of coloured text blocks. Only one attention card per page.
- **Forms:** text fields with radius 15, 1 px border, `bg` fill, labels 12.5 muted. Primary button full-width at the bottom.
- **Bottom sheets and dialogs:** surface, radius 20 top, a drag handle, the same buttons. Keep `showAppSheet` (bottom SafeArea).
- **Dark mode:** every screen uses the tokens; no hard-coded colours. Check contrast (WCAG AA).
- **Premium:** wherever "প্রো"/Pro appears in UI text, show **"প্রিমিয়াম"** (pricing page, badges, gates, settings). Keep internal names; change only the UI strings, plus their English entries in `strings_en.dart` ("Premium").
- **Keep every existing feature, action and test.** Update test finders only when text or structure really moved, and say which.

**Screens to cover** (check the code for the full list):
- tasks, reminders, alarms
- calendar, diary
- money (cash, ledger, other accounts, transactions, person, cash form, accounts, savings, report, split, receipts, shop)
- store, notes, docs (+ doc detail and folders), vault (+ item), contacts/calls
- health (+ kinds, vaccines, doctor summary), medicines, habits
- special days, emergency card, expiry, tags
- inbox, search, trash
- more (+ settings parts, backup, notification settings, notices page, sound/ringtone)
- premium (`ProScreen`), help, feedback, compass, zakat, family (+ member, heir view), blood donation (+ ask)
- onboarding, lock screen, chat (`ChatHome`), answer/confirm screens, new item, library, trace, templates

### 5. How to work
1. **Read §0–§4,** open `home.html` and every image.
2. **Build the tokens and kit (§2).** Migrate the old `C` names so the app compiles and looks coherent.
3. **Build HOME (§3) exactly.**
   - Render screenshots light and dark at 1170×2532 with a widget test (see `test/dark/dark_shots_test.dart`, `SHOTS=1 … --update-goldens`).
   - Compare them with the images.
   - **Send the owner the home screenshots plus দিনলিপি, হিসাব and সংরক্ষণ redone in the same language, and wait for his OK** before converting all remaining screens.
4. **Convert the remaining screens** group by group, keeping all tests green. Add tests for new computed bits:
   - the rotating slot's content (next prayer; Ramadan iftar/sehri switch at Maghrib/Fajr);
   - the one-attention-card priority;
   - "প্রিমিয়াম" badge visibility.
5. **Run all checks:**
   - `flutter analyze --no-pub` (0 warnings).
   - The full `flutter test --no-pub`, alone (~16+ min).
   - `python3 tool/i18n_missing.py` = 0.
   - Admin app tests and WordPress e2e, unchanged.
6. **Release:** bump the version (next minor after the branch's current one; `pubspec.yaml` + `appVersion` in `lib/screens/more_screen.dart`), commit, rebase, push.
7. **Build and send:**
   - Build with `play_preview.yml`.
   - Download via `gh api` (REST; GraphQL is blocked).
   - Re-sign with uber-apk-signer `--allowResign`, alias `myassistant`.
   - Verify the certificate SHA256 `FC:6C:FF:35:…:69:D0:01:4F`.
   - Send `My-Assistant-Play-Preview-<ver>-b<N>-{arm64,armv7}.apk`.
8. **Docs:** update `docs/HANDOFF.md` and `docs/pending-2026-10-22.md` (and the claude.ai Project if attached).
9. **Report in Bengali:**
   - What changed, with screenshots.
   - What moved or shrank.
   - What is not verified (real phone, small screens, big text setting, dark mode on device, animation smoothness).
   - The file names.

### 6. Still pending from before (do not lose)
**Owner:**
- Install the latest plugin.
- Make the NLU model `2026.10.22-bert2` live at 100%.
- Turn on "কথা বোঝা আরও ভালো করতে সাহায্য করুন" and mode "চালু" for 5–10%.
- Send the review text (site "সব কপি করুন").
- Replace the Gemini key seen in a screenshot.
- Make the Play Console background-location declaration.
- Two-phone family test.

**Claude:**
- Label the review rows.
- NLU step J.
- Retrain (fix the call-intent drop first).
- Step K rollout.
- Gemini latency.
- Owner-only costs in the admin summary.
- Voice-to-family.
- Multi-select on more pages.

**Paid, needs permission:** the AI paraphrase step (about $0.37).

## PROMPT শেষ
