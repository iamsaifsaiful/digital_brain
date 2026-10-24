# নতুন UI বানানোর পূর্ণ নির্দেশ (প্রম্পট) — My Assistant, ২৪ অক্টোবর ২০২৬

> **মালিকের জন্য (কীভাবে ব্যবহার করবেন):** নতুন অ্যাকাউন্টে Claude-এ এই পুরো লেখাটা (নিচের "PROMPT শুরু" থেকে শেষ পর্যন্ত) পেস্ট করুন। তার আগে:
> 1. GitHub-এ `iamsaifsaiful/digital_brain` রিপোজিটরিতে ঢোকার অনুমতি দিন (Claude-কে বললে সে যুক্ত করবে)।
> 2. সাইনিং key-র দুটো ফাইল সাথে দিন: `my-assistant-release.jks` আর `My-Assistant-signing-key.txt`। এগুলো ছাড়া বানানো APK আপনার ফোনের অ্যাপের ওপর ইনস্টল হবে না।
> 3. চাইলে যে অনুপ্রেরণার ছবিটা দিয়েছিলেন (Shihab-এর "Good morning" আর "Schedule" দুই পাতা), সেটাও সাথে দিন।
>
> নকশার সব ছবি (২৮টা পাতা) রিপোজিটরিতেই আছে: `docs/design/2026-10-24-new-ui/img/` আর এক নজরে সব: `overview.jpg`।

---

## PROMPT শুরু

You are continuing work on **My Assistant**, a Bengali voice-first personal assistant (Flutter, Android). The owner (Saif) writes in Bengali; **reply and report in Bengali**. He has delegated decisions to you ("তুমি আমার থেকে বেশি বুদ্ধিমান। তুমি সিদ্ধান্ত নিয়ে পরের কাজ গুলো কর"), and his goal is "যত কম খরচে উন্নত সেবা দেওয়া গ্রাহকদের" without loss to the company.

**Your task now:** rebuild the app's UI to match an approved-in-principle visual design. That design is 28 page mockups made in a previous session, inspired by a screenshot the owner sent. Design first, code after approval: the owner said "আগে ডিজাইন, ডিজাইন অনুমোদন হলে, এরপর কোড করব". The mockups exist, but **4 design questions are still open (§3); ask them first**.

### 0. Read first (in the repo)
1. Clone and check out the branch:
   ```
   git clone https://github.com/iamsaifsaiful/digital_brain && cd digital_brain
   git checkout next-update
   ```
2. **`docs/HANDOFF.md`**: the full handoff. It covers the rules, build/sign/send routine, architecture, what was done 18–23 Oct, and what is left. Follow it exactly.
3. **`docs/pending-2026-10-22.md`**: the open to-do list (Bengali).
4. **`docs/design/2026-10-24-new-ui/`**: this design.
   - `img/01-home.jpg … img/28-search.jpg`: phone-size mockups (780×1688).
   - `overview.jpg`: all 28 pages on one sheet.
   - `html/`: the HTML/CSS sources of the mockups.
     - `head.html` holds the shared CSS and tokens; `bodyN.html` holds the pages.
     - To re-render them, put a `fonts/` folder next to them containing `assets/fonts/HindSiliguri-*.ttf`, `assets/fonts/NotoSansBengali-*.ttf`, Flutter's `MaterialIcons-Regular.otf` and Inter `.otf` files. Then open `head.html + <body> + bodyN.html` in Chromium (Playwright, 390×844, DPR 3).
   - **Treat the CSS in `head.html` and each `bodyN.html` as the exact spec for sizes, colours and spacing.**

### 1. Hard rules (verbatim from the owner; never break)
- "পাসওয়ার্ড, ভল্ট, PIN, OTP, স্বাস্থ্য, ওষুধ আর অন্য অ্যাপের মেসেজ কখনো ফোনের বাইরে যাবে না। API key APK-তে থাকবে না। প্যাকেজের নাম আর সাইনিং বদলাবে না। ব্যবহারকারীর ডেটা মুছে বা এনক্রিপশন দুর্বল করে কোনো সমস্যার সমাধান করবে না।"
  - Exception, owner's decision of 22 Oct: family medicine reminders and the heirs' copy leave the phone only end-to-end sealed.
- "স্ক্রিনশট দেখে নতুন regex নিয়ম লিখবে না।"
- "যাচাই-সেটের বাক্য বা তার কাছাকাছি রূপ কখনো শেখানোর ডেটায় যাবে না।"
- "কোনো সংখ্যা দাবি করবে না যা নিজে চালিয়ে মাপোনি।"
- "অনুমতি ছাড়া paid service চালু করো না।"
- "বাস্তব audio test না করে voice recognition সম্পূর্ণ ঠিক হয়েছে বলে দাবি করবে না।"
- Always list what is **not verified**.
- Never commit the keystore, never print its password or put it in logs, and never ask for the owner's Google password.
  - The password file has a line that is just `পাসওয়ার্ড:`; the value is on the next non-empty line.
  - Read it only with a script into a `mktemp` file (umask 077), then `KP=$(cat f); shred -u f`.
  - **Never print or preview any line of that file.**
- Every new Bangla UI string wrapped in `tr()`/`trf()` gets an English entry in `lib/logic/strings_en.dart`. Then `python3 tool/i18n_missing.py` must print **0 missing**.
- Do not run `dart format` on big existing files; it re-flows them. Keep the existing style and format only new files.
- **The UI rebuild must not change behaviour or data.** It is a visual change: same features, same data, same voice flow. Every existing widget test must keep passing; update finders only where text or structure genuinely moved, and say so.

### 2. Current state (23 Oct 2026)
- App **2.45.0+96** (b96), plugin **1.15.0**, admin app **1.5.0+7**, branch `next-update`. The last commit before this design was `88fae63`.
- Tests:
  - Flutter: 2176 pass. The full run takes about 16 min; run it alone, never in parallel.
  - Admin app: 8 tests.
  - WordPress e2e: ALL OK.
  - `flutter analyze`: 24 infos, 0 warnings.
- **Next release:** 2.46.0+97. Bump `pubspec.yaml` and `appVersion` in `lib/screens/more_screen.dart`. The plugin and admin app are unchanged unless needed.
- Build, sign and send exactly as in `docs/HANDOFF.md` §2:
  - Build with the `play_preview.yml` workflow.
  - Download the assets via `gh api` (REST only; GraphQL is blocked).
  - Re-sign with `uber-apk-signer --allowResign`, alias `myassistant`.
  - Verify the certificate is SHA256 `FC:6C:FF:35:…:69:D0:01:4F`.
  - Name the files `My-Assistant-Play-Preview-2.46.0-b97-{arm64,armv7}.apk`.
- **Commit trailers:** the ones your session's system tells you to use. The previous session used `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` plus its own session link.

### 3. Open design decisions — ask the owner FIRST (use one multiple-choice question set)
1. **Is the design approved as is, or what should change?** He may name pages.
2. **Home floating button: 🎤 mic (default in mockups — the app is voice-first) or "+"?**
   - In the mockups, the main tabs and chat use the mic.
   - Page-specific "add" buttons stay as drawn: + on দিনলিপি, alarm-add on অ্যালার্ম, camera on ডকুমেন্টস, red "রক্ত চাই" on ব্লাড ডোনেশন.
3. **Keep the handwritten notes** ("ছোট ছোট পদক্ষেপ, বড় ফল ↗", "গতকালের চেয়ে একটু ভালো", "শুভ দিন :)", …)? Default: keep them, small and decorative.
4. **Main colour:** the mockups use a deep green-black `#1F2A27` with the app's green `#0E7A5F` only for small accents. Choose between:
   - (a) the mockups' deep green-black (default);
   - (b) the app's green as the main colour;
   - (c) follow the user's chosen accent (সেটিংস › চেহারা already has accents: green, blue, purple, teal, rose, amber and a custom colour).
   - Recommendation: (a) as the default look, and keep the accent picker working by mapping `accent.main` to the "accent" token. Then (c) still works for users who change it.

If the owner is not there to answer, go with the defaults above and say so at the top of your report. Also show **dark mode** screenshots of at least home, দিনলিপি and হিসাব before shipping. The mockups are light only (§5.2 gives the dark token proposal).

### 4. The inspiration (what to copy, what not to)
The owner's screenshot shows two iOS-style pages ("Good morning, Shihab" home and "Schedule").
- **Copy:**
  - The warm off-white paper background and white rounded cards with very soft shadows.
  - One near-black accent.
  - Large friendly greeting.
  - A photographic hero card with progress.
  - Horizontally scrolling project cards.
  - Simple round-check task rows with chevrons.
  - Small handwritten scribbles with hand-drawn arrows.
  - A week strip with the selected day in a dark rounded square.
  - A timeline with times on the left.
  - One highlighted, expanded item.
  - Avatar stacks.
  - A botanical leaf decoration.
  - A dark round FAB.
  - A minimal bottom bar.
- **Do not copy:** English text, the "Shihab" name or any of his content. Everything is My Assistant's own data, in Bengali.

### 5. Design system (implement this first, in `lib/ui/`)

#### 5.1 Light tokens (from `head.html` `:root`)
| token | value | use |
|---|---|---|
| page | `#F3F2EE` | screen background (warm paper) |
| card | `#FFFFFF` | cards, inputs, chips |
| ink | `#17191A` | main text |
| ink2 | `#3B3F3E` | secondary text, icons |
| muted | `#8C8C87` | captions, labels |
| line | `#ECEAE5` | dividers, empty bars |
| soft | `#F6F5F2` | icon squares inside cards, light chips |
| accent | `#1F2A27` | dark cards, primary buttons, selected day/chip, toggles |
| fab | `#2E3B37` | floating button |
| green | `#0E7A5F` | money in, success dots, "চলছে" dot |
| amber | `#E9A23B` | sun/weather icon |
| warn bg/fg | `#FBF1E3` / `#9A5F1E` (`#B9772A` icons) | "soon", expiry, debt-to-give |
| danger | `#D2553E` (Friday, now-line), `#B2412E` (blood, debt minus, emergency), bg `#FBE7E3` | |
| success tint | `#E7EFEA`, text `#2F6B53`; on dark `#A6E3C9` | healthy readings, "সব নিরাপদ" |
| dark-card secondary text | white at 75–85% | |

`lib/ui/theme.dart` already has class `C` with `_p(light, night)` and accents.
- **Add the new tokens there.** Keep the old names working: map `C.ground`→page, `C.surface`→card, `C.ink`, `C.muted`, `C.line`, and so on. Screens not yet redesigned must still look coherent.
- Wire the "accent" token to `C.accent.main` if the owner chooses option (c).

#### 5.2 Dark tokens (proposal — screenshot and ask)
| token | value |
|---|---|
| page | `#0F1312` |
| card | `#181D1B` |
| soft | `#20262A`-ish (`#212826`) |
| ink | `#EEF1EF` |
| ink2 | `#C9D1CD` |
| muted | `#8E9893` |
| line | `#262D2A` |

- **Accent cards:** `#22302B` with a 1px `#2E3D37` border.
- **Primary buttons:** `#E7EEEA` background with `#14201C` text (inverted), or the accent green `#3DBE8B` with dark text.
- **Tints:** green tint `#16302A`, warn `#33281A`, danger `#3A1E1A`.
- **Mockup images:** dim the hero illustrations by ~15%.
- Use `test/dark/dark_shots_test.dart` (`SHOTS=1 … --update-goldens`) to produce the screenshots.

#### 5.3 Type
- **Titles:** **Hind Siliguri** (already in `assets/fonts/`) at 700.
  - Page title 26–28. Greeting name 32 (line height 1.12). Big amounts 26–34. Section titles 18 at 600.
- **Body:** **Noto Sans Bengali** 400/500/600.
  - Body 14–14.5, captions 11–12.5.
- **Latin text** ("Gmail", "PDF", "Google Drive"): Inter or Roboto through `fontFamilyFallback`. In the mockups, Latin fell back to a serif until fixed; make sure the app's fallback is sans.
- **Handwritten notes:**
  - Use **Galada** (Bengali handwriting font, SIL OFL, from Google Fonts). Add `assets/fonts/Galada-Regular.ttf` and its OFL licence, and register it in `pubspec.yaml`.
  - If you cannot download it, ask the owner to attach the font file. Until then, fall back to Hind Siliguri 500, rotated −6…−8°, colour ink2 (that is what the mockups show).
  - Size 12.5–16.
  - The hand-drawn arrows, underlines and smiley are simple stroked paths (1.3–1.6 px, round caps); see the SVGs in `body1.html`.
- **Digits:** Bengali everywhere, as the app already does (`bnDigits`).

#### 5.4 Shape, depth, spacing
- **Radii:** cards 18; hero/dark cards 20–24; inputs 15–16; chips 14–16 (pills); icon squares 10–14; buttons 14–18; FAB a 58 circle.
- **Shadows:** cards `0 1px 3px rgba(0,0,0,.05)`; FAB `0 8px 18px rgba(31,42,39,.35)`; hero none; the selected week day `0 6px 14px rgba(31,42,39,.25)`.
- **Spacing:** page horizontal padding 22 (16 on dense pages such as search and chat). Section header padding is 14–20 top and 8–10 bottom. Gaps between cards are 10–12.
- **Status/top area:** the title row starts about 8 below the status bar.
  - Back is a chevron `arrow_back_ios_new_rounded` (20). The title is 26–28/700, with a 12.5 muted subtitle.
  - Optional right: an icon button (42×42, radius 14, white card) **or** a handwritten note.

#### 5.5 Components to build (reusable; put them in `lib/ui/widgets.dart` or a new `lib/ui/kit.dart`)
1. **`PaperScaffold`**: page background, SafeArea, optional bottom nav and FAB, right-aligned FAB at bottom 100 when the nav is shown and 36 when not.
2. **`PageHeader(title, sub, back, trailing | note)`**: the header described above.
3. **`HandNote(text, arrow: none|right|down-left, rotate)`**: the handwritten scribble.
4. **`HeroCard`**: dark rounded card.
   - Variants: (a) an illustrated landscape (misty layered hills + pine silhouettes + left-to-right dark gradient; the SVG is in `body1.html .hero`); (b) plain accent.
   - Slots: label, big value, small sub, right action ("চালিয়ে যান ›"), optional progress bar (5 px, white on white-28%).
   - Draw the landscape with `CustomPainter`; do not ship a photo.
5. **`AppCard`**: white, radius 18, soft shadow, padding 12–14.
6. **`IconSquare(icon, size 34–40, radius 11–13, bg soft)`**.
7. **`RowItem`**: icon square or avatar + title (14/500–600) + sub (11.5 muted) + trailing (chevron, amount or button), with dividers between rows inside one card. It replaces `ListRow` visually; keep `onLongPress` and `picked`, since multi-select (`lib/ui/pick.dart`) must keep working.
8. **`Pill/Chip`**: status pill with dot ("• চলছে"); count chips ("১০ দিন"; warn variant); filter chips (selected = accent with white text); segmented control (track `#E9E7E2`, selected white with shadow) for tabs inside a page.
   - Tabs must still swipe; see `TabPages`/`SwipeTabs`.
9. **`WeekStrip`**: 7 days, **week starts Saturday**. Selected = accent rounded square (46 wide, radius 14) with weekday, number and event dot. Friday number in danger red.
10. **`TimelineSlot`**: time column (84 wide, right-aligned, 11.5 muted) + item. A **now-line** (1.5 px danger with a dot and the time label). A **focus item**: white expanded card with note and action chips.
11. **`AvatarStack`**: 24–32 px circles with initials, 2 px page-coloured border, −7 px overlap.
12. **`ProgressRing`**: 54 px, 5 px stroke, icon inside; turns green when ≥70%.
13. **`BottomNav`**:
    - 5 tabs: হোম, দিনলিপি, হিসাব, সংরক্ষণ, আরও.
    - Icons 24; label 11; active = ink + 600 + 18×3 underline; inactive `#9B9A95`.
    - White at 92% with a top hairline, height 84 including the home indicator.
    - Keep the existing finger-following page swipe in `home_shell.dart`; only restyle.
14. **`Fab`**: 58 circle `fab` colour, white icon 28.
    - Variants: mic (opens chat), add, alarm-add, camera.
    - Extended red "+ রক্ত চাই" on blood.
15. **`StatTile`** (health), **`DayBlock`** (date number + short month in a soft square), **`MiniBars`** (small bar charts; the current month in accent), **`StackedBar`** (category split), **`Toggle`** (accent switch 40×24).
16. **`SearchField`**: white, radius 15, search icon, optional mic square on the right. In the active search page, a 2 px accent ring and a "বাতিল" text button.

### 6. Page-by-page spec (28 mockups; image file → Flutter screen → what to show)

For every page:
- Use **only data the app already has**. Where the mockup shows something the app does not compute yet, compute it from existing data if that is cheap and safe; otherwise leave it out. **List every such gap in your report**; never fake numbers.
- Sample names and amounts in the mockups are illustrations only.

1. **`01-home.jpg` → `lib/screens/home_page.dart` (HomePage)**
   - **Top:** hand note "ছোট ছোট পদক্ষেপ, বড় ফল ↗" on the left; bell with unread dot (existing notices/inbox) and profile avatar (`UserPhoto`) on the right.
   - **Greeting:** `helloFor(now)` + "," then the first name at 32/700 with a small sun drawing (the mockup used an SVG sun; no emoji font).
   - **Date line:** "শনিবার, ২৪ অক্টোবর · ৮ কার্তিক ১৪৩৩" (existing Bangla date).
   - **Weather chip under the date:** white pill with sun/cloud icon, "২৮° · রোদ · ঢাকা" (`brain.weatherNow`, district name). The owner asked for weather under the date, not overlapping it.
   - **Hero (landscape):**
     - "এই সপ্তাহে" / "৩ / ৫ কাজ শেষ", computed from tasks due this week (Sat–Fri): done vs total. If there are none, show today's sunrise/sunset only.
     - "সূর্যোদয় ৬:০১ · সূর্যাস্ত ৫:২৪" from `sunTimes`.
     - "চালিয়ে যান ›" opens the tasks list.
     - Progress bar.
   - **"চলমান লক্ষ্য" + "সব দেখুন →":**
     - Horizontal 140-wide cards for savings goals, DPS and loans (`d.goals`, `d.installments`).
     - Each card: a coloured top (one dark, one light, one sage) with a "• চলছে" pill and icon; then name, sub (amount/target or কিস্তি x/y), %, and a 4 px bar.
   - **"আজকের কাজ" with the hand note "গতকালের চেয়ে একটু ভালো" and "৩টা কাজ":** rows with round check, title (done = strikethrough muted), "বিভাগ · সময়", chevron. Use the existing `TodaySections` data.
   - Keep the other existing home sections (Google start card, alarm banner, month money card, spend health) **below**, restyled as `AppCard`s.
   - **FAB:** mic → chat.
2. **`02-day.jpg` → `DiaryScreen` (দিনলিপি tab)** (check what `lib/screens/diary_screen.dart` shows today and keep its features)
   - **Header:** "দিনলিপি", sub "আজ গুছিয়ে নিন, কাল সহজ হবে।", calendar icon button (opens `CalendarScreen`).
   - **Month row:** "অক্টোবর ২০২৬ ⌄" + muted "কার্তিক ১৪৩৩"; hand note "শুভ দিন :)" with an underline on the right.
   - **WeekStrip:** Sat–Fri, selected day dark, dots on days with items, Friday red.
   - **Timeline of the selected day:** medicines (`medication`), reminders (done = strikethrough "হয়ে গেছে"), tasks with time, ledger due dates (focus card "রহিম ফেরত দেবেন ৳৫,০০০" with note and chips "ফোন করুন" / "শোধ হয়েছে"), family items (avatar stack, "ফ্যামিলি থেকে").
   - **Now-line** at the current time, only for today.
   - Leaf decoration bottom-left at about 32% opacity; FAB "+".
3. **`03-money.jpg` → `MoneyScreen` (`ledger_screen.dart`), tab আয়-ব্যয় (`CashView` in `money_screens.dart`)**
   - **Header:** "হিসাব" / "টাকা কোথায় যায়, এক নজরে।"; hand note "একটু একটু করে জমান"; PDF icon button (existing `PdfButton`).
   - **Segmented tabs:** আয়-ব্যয় | ধার-দেনা | অন্যান্য হিসাব (existing `MoneyPart`, still swipeable).
   - **Dark balance card:** "এই মাসের ব্যালেন্স", big amount, আয় / খরচ / জমার হার (balance ÷ income). Month chip "অক্টোবর ⌄" (existing month navigation). A soft line chart of the running balance through the month (computed from cash entries).
   - **Buttons:** "+ আয়" (accent) and "+ খরচ" (white).
   - **"খাত অনুযায়ী খরচ":** stacked bar + 2-column legend (`monthSums.topExpenses`).
   - **"সাম্প্রতিক":** recent entries with icon square, category, "date · account", and amount (income green with +). "সব লেনদেন →".
   - Keep multi-select on rows.
4. **`04-store.jpg` → `StoreScreen`**
   - **Header:** "সংরক্ষণ" with a lock icon and sub "দরকারি সব, এই ফোনে তালাবদ্ধ"; hand note "সব এক জায়গায়" with a curved arrow.
   - Search field with mic (existing `openVoice`).
   - **Expiry warning card** (warn bg) for the nearest document expiring within about 30 days (existing `ExpiryScreen` data). Hide it if there is none.
   - **"সব কিছু · ৬টা ভাগ":** 2-column tiles (icon square + name + count): নোট, ডকুমেন্টস (with "তালাবদ্ধ"), **পাসওয়ার্ড (dark tile)**, যোগাযোগ, স্বাস্থ্য, মেসেজের কাজ (only if `inboxSupported`).
   - Chips row: জরুরি কার্ড, কাগজের মেয়াদ, বিশেষ দিন, ট্যাগ.
   - **"সম্প্রতি রাখা":** two recent note cards.
5. **`05-more.jpg` → `MoreScreen`**
   - **Header:** "আরও" / "প্রোফাইল, সুবিধা আর সেটিংস"; hand note "নিজের মতো সাজিয়ে নিন".
   - **Profile card:** avatar, name, "📍 district · ফোনের লোকেশন অনুযায়ী" (when `autoPlace`), "Google দিয়ে লগইন · ব্যাকআপ চালু", and a blood group pill (red tint).
   - **Pro card:** small landscape, "প্রো চালু আছে" + until-date + benefits, and a "নবায়ন" chip. For free users: "প্রো নিন" and the price instead.
   - **"সুবিধা":** 3×2 tiles: ফ্যামিলি (dark), যাকাত, ব্লাড ডোনেশন, কিবলা কম্পাস, শিখে নিন (Help), মতামত.
   - **"সেটিংস · সংস্করণ x":** grouped rows (চেহারা ও ভাষা, রিমাইন্ডারের রিংটোন, অ্যাপ লক with toggle, …). Keep **all** existing settings sections; restyle them into these grouped cards.
6. **`06-chat.jpg` → `ChatHome`**
   - **Header:** back, dark rounded bot square with sparkle icon and a green online dot, "আপনার সহকারী" with status "শুনছি…" (green) while listening, and a menu.
   - **Messages:**
     - User bubbles are right-aligned and dark, radius 18/18/6/18. A voice message shows a small waveform icon and "বলেছেন · time".
     - Assistant bubbles are left-aligned and white, radius 18/18/18/6.
   - **Result cards inside answers:** rows with icon square, title, sub and a green check. Action chips below ("বদলান", "ফিরিয়ে আনুন") use the existing action row and follow-up chips.
   - **Mini charts** for money answers (3 bars), only where the answer already has numbers.
   - Suggestion chips above the input.
   - **Input:** a white pill "লিখুন বা বলুন…" with a send icon, and a big mic (58) with two faint rings. Hand note "বলুন, আমি শুনছি ↘".
   - No bottom nav. Keep **all** current chat behaviour (thumb-zone buttons, multi-line input, listening states).
7. **`07-family.jpg` → `FamilyScreen`**
   - **Header:** "ফ্যামিলি" / "একে অপরের পাশে, সবসময়" + add-person button.
   - **Hero:** "আমার পরিবার · ৪ জন সদস্য", avatar stack, "🛡 যা পাঠান, তালাবদ্ধ যায় — আমরাও খুলতে পারি না".
   - **Member cards:** avatar, name, relation + last info (location age or battery if shared), permission chips (ওষুধ, রিমাইন্ডার, লোকেশন, উত্তরাধিকারী in warn colours), primary action ("এখন কোথায়?" when location is allowed, else "ওষুধ দিন"). For pending invites: "যোগ দেওয়ার অপেক্ষায়" + "আবার পাঠান".
   - **"কারো জন্য পাঠান":** tiles কাজ / রিমাইন্ডার / ওষুধ (existing `_SendSheet`). Keep the heir section, the location disclosure and every existing function.
8. **`08-zakat.jpg` → `ZakatScreen`**
   - **Dark card:** "এ বছর যাকাত দিতে হবে ৳…", a "নিসাব … পেরিয়েছে" pill (green; or "নিসাব হয়নি"), then সম্পদ / দেনা বাদ / নিট. Faint geometric star pattern.
   - **Zakat-day row:** date + days-left pill.
   - **"কোথা থেকে কত · টিক তুললে বাদ":** checkbox rows with source and date. Unticked = strikethrough muted. Debts are red minus.
   - Dashed "+ নিজে কিছু যোগ করুন".
   - No bottom nav; FAB lower.
9. **`09-blood.jpg` → `RequestsScreen` (ব্লাড ডোনেশন)**
   - **Header** with the hand note "এক ব্যাগ রক্ত, একটা জীবন".
   - **Donor card (dark):** red group square, "আপনি দাতা · district", last donation and next eligible date (last + 120 days, computed). Pill "আপনার গ্রুপে দরকার হলে জানাব".
   - Segmented tabs সারা দেশের অনুরোধ | আমার অনুরোধ (existing `TabPages`) and filter chips (group, district).
   - **Request cards:** group square (red tint), "for whom · problem", hospital, "time · bags · district", "জরুরি" pill when within 24 h, and "ফোন করুন" / "শেয়ার".
   - **Extended red FAB "+ রক্ত চাই".**
10. **`10-docs.jpg` → `DocsScreen`**
    - **Header:** "ডকুমেন্টস", "🔒 ১২টি কাগজ, এই ফোনে তালাবদ্ধ", and a scan button.
    - Search; folder chips.
    - **Featured NID card:** drawn ID thumbnail, masked number "•••• ৪৫২১" with eye icon, "আঙুলের ছাপ দিলে পুরো নম্বর" (existing verify).
    - **2-column doc cards:** a paper thumbnail (real first photo thumbnail if one exists; otherwise the drawn paper), a badge (warn "১২ দিনে শেষ" for soon expiry; "৩টি ছবি"; "PDF"; expiry month), title, and "folder · detail".
    - Camera FAB.
11. **`11-alarm.jpg` → `AlarmsScreen` (`alarm_list_screen.dart`)**
    - **Header:** "ফোন লক থাকলেও ঠিক সময়ে বাজবে" + hand note "ঘুম ভালো হোক".
    - **Next-alarm dark card:** moon drawing, "পরের অ্যালার্ম · কাল রবিবার", big time, "৭ ঘণ্টা ৪৯ মিনিট পর", and the ringtone chip with the tone name.
    - **Alarm cards:** big time + day part, label · repeat, toggle, and day boxes (on = sage `#E2E8E4` with ink). Off alarms are greyed.
    - **Health card (green tint):** "এই ফোনে ঠিকমতো বাজবে", from existing `AlarmHealth`. When something is wrong, it becomes a warn card with the fix.
    - Alarm-add FAB.
12. **`12-health.jpg` → `HealthScreen` (`health_hub.dart`)**
    - **Header:** "🔒 শুধু এই ফোনে থাকে, কোথাও যায় না" + add.
    - Member chips (আমি / আম্মা / আব্বা; existing members, swipeable).
    - **"শেষ মাপ" 2×2 tiles:** প্রেশার (dark, with sparkline), সুগার, ওজন (BMI), পালস. Status pill green "স্বাভাবিক" or warn ("একটু বেশি · খালি পেটে"), using the app's existing ranges.
    - **"আজকের ওষুধ · x/y নেওয়া":** rows with "✓ নেওয়া" or a "নিলাম" button.
    - **"সামনে":** doctor appointments and vaccines.
13. **`13-vault.jpg` → `VaultScreen` / `VaultPage`**
    - **Header:** "আঙুলের ছাপে খোলা · ১ মিনিটে নিজে বন্ধ" + hand note "শুধু আপনার জন্য".
    - **Dark safety card:** shield, "৮টি পাসওয়ার্ড, তালাবদ্ধ", "ফোনের বাইরে যায় না, AI-ও দেখে না। ২টি দুর্বল — বদলে নিন।" The weak count comes from `lib/logic/password.dart`.
    - Search.
    - **Rows:** coloured letter tile, name + "দুর্বল" pill, masked username and dots, copy button. **Never show passwords on this list.**
14. **`14-ledger.jpg` → `MoneyScreen` tab ধার-দেনা**
    - Hand note "হিসাব পরিষ্কার, সম্পর্ক ভালো".
    - **Two cards:** পাবো (dark) "৳… · ৩ জনের কাছে" and দেবো (white, amber amount).
    - **Buttons:** দিলাম / নিলাম / সব লেনদেন.
    - **"মানুষ":** avatar, name, last activity or a red "আজ ফেরতের দিন" pill, amount (green পাবো / amber দেবো). Tapping opens `PersonScreen`.
15. **`15-notes.jpg` → `NotesScreen`**
    - **Header:** "মনে রাখার সব কথা · ২৪টি" + hand note "ভুলে যাওয়ার ভয় নেই".
    - Search ("নোটের ভেতরেও খুঁজুন…"); category chips.
    - **Two-column masonry:**
      - Pinned or first note dark with a pin icon (pinning exists? if not, darken the newest instead; do not add pinning without asking).
      - Checklist notes show checkboxes and "১/৪ কেনা".
      - Photo notes show a thumbnail and "১টি ছবি".
      - Footer "category · date".
    - Keep multi-select (long-press).
16. **`16-pro.jpg` → `ProScreen`**
    - Landscape hero "আরও সহজ, আরও নিশ্চিন্ত".
    - **Two plan cards:** মাসিক ৳৯৯ and বাৎসরিক ৳৯৯৯ (selected, with a green "২ মাস ফ্রি" ribbon and "মাসে ৳৮৩-এর মতো"). Use the real prices from the server/config.
    - **"যা পাবেন":** a feature list with icons.
    - **Bottom CTA:** "বিকাশে প্রো নিন · ৳৯৯৯" with the note "আমাদের সাইটে বিকাশ দিয়ে পেমেন্ট · চালু হলে নিজে থেকে জানাব". Payment stays on the website as now.
    - Keep the existing brief/details tabs content reachable.
17. **`17-contacts.jpg` → `CallsScreen` / `ContactsScreen`**
    - **Header:** "১৮৬ জন · নাম বললেই ফোন" + add.
    - Search with mic.
    - **"প্রায়ই কথা হয়":** 54 px avatars with names, plus the hand note. Rank by the app's own call/usage history if it has one. Otherwise use family members and contacts marked important. Do **not** read the phone's call log without permission/rules.
    - **Birthday card** (warm tint) when a special day today belongs to a contact: message and call buttons.
    - **Alphabetical sections:** avatar, name + tag (পরিবার / অফিস / ডাক্তার), number, round call button.
18. **`18-savings.jpg` → `SavingsScreen` (`money_more_screens.dart`)**
    - Dark total "মোট জমা" + "এ মাসে জমা +৳…" + hand note "চালিয়ে যান!".
    - **Goal rows with ProgressRing:** name, saved/target and year, %. Green at ≥70%.
    - **"কিস্তি":** DPS and loans with next date, amount and paid/total. For loans, a row of small squares (paid dark, left light).
19. **`19-report.jpg` → `ReportScreen`**
    - Month expense + "গত মাসের চেয়ে x% কম" (green) or "বেশি" (amber) + hand note "ভালো হচ্ছে!" (only when lower).
    - 6-month bar chart, current month dark with its value on top.
    - **Two insight tiles:** saved vs last month (green); "শখের খাতে x%" (warn) using the app's existing wants/needs split (`SpendHealthScreen` logic).
    - **"কোথায় গেল":** category rows with icon, amount, % and a bar. PDF button.
20. **`20-habits.jpg` → `HabitsScreen` (`health_screens.dart`)**
    - Dark streak card: flame, "সবচেয়ে লম্বা ধারা · ১২ দিন টানা", "habit · আজও হলে ১৩", and the hand note "থামবেন না!".
    - **"শেষ ৭ দিন":** a grid with the habit name, icon and "x/৭ দিন" or streak, and 7 day squares: done = accent with tick, missed = light red `#F3E4E0`, today pending = dashed outline. Tap today's square to tick.
    - Legend under the grid.
    - Streaks are computed from existing habit logs.
21. **`21-welcome.jpg` → `OnboardingScreen` (first page)**
    - Top half: a large landscape illustration with the white hand note "ছোট ছোট পদক্ষেপ, বড় ফল ↗".
    - The white "আ" logo tile overlapping the image edge.
    - "আপনার ব্যক্তিগত সহকারী" + one line + two feature rows (মুখে বললেই হয় with an example; তথ্য আপনার ফোনেই, তালাবদ্ধ).
    - Page dots, a dark "G Google দিয়ে শুরু করুন" button, "লগইন ছাড়াই দেখি", and the small note about backup restore.
    - Keep the existing onboarding steps after it.
22. **`22-lock.jpg` → `LockScreen`**
    - Soft gradient background, dark "আ" logo tile, "শুভ সকাল, name", "🔒 আপনার তথ্য তালাবদ্ধ আছে", 4 PIN dots.
    - **Keypad:** 76 px white round keys with Bengali digits; a dark fingerprint key bottom-left; backspace bottom-right.
    - "PIN ভুলে গেছেন?" and the hand note "শুধু আপনিই খুলতে পারেন". The PIN logic is unchanged.
23. **`23-calendar.jpg` → `CalendarScreen`**
    - Header + hand note "প্রতিটা দিন গুরুত্বপূর্ণ".
    - "অক্টোবর ২০২৬ / আশ্বিন–কার্তিক ১৪৩৩" with prev/next buttons.
    - **Month grid (Saturday first):** day number + tiny Bangla date (the month name on the 1st of a Bangla month), Friday red, holidays red (existing `bdHolidays`), event dots green, today in a dark square.
    - **Prayer row:** ফজর, যোহর, আসর, মাগরিব, এশা from `sunTimes(district)`; the current one is highlighted green.
    - Then the selected day's items.
    - Keep the existing side tabs (CalSide, swipeable) and Hijri.
24. **`24-backup.jpg` → `BackupScreen` (`more_screen.dart`)**
    - Dark status card: cloud-done icon, "সব নিরাপদ আছে", last backup time · Google Drive · size. Show a warn variant if it is old or failed.
    - **Buttons:** "এখনই ব্যাকআপ" and "ফিরিয়ে আনুন" (existing restore flow with its confirmations).
    - **"কীভাবে":** daily auto (Pro) toggle, Wi-Fi only toggle, "তালাবদ্ধ ব্যাকআপ — Google-ও খুলতে পারে না".
    - **"যা থাকে":** green-tick chips with counts.
25. **`25-special.jpg` → `SpecialDaysScreen`**
    - Today's dark card ("জামালের জন্মদিন · ৩৫ বছরে পা দিলেন", "শুভেচ্ছা পাঠান" / "ফোন"), only when there is one today; otherwise show the next one.
    - **Month-grouped lists:** DayBlock, title, type and nth, days-left pill (warn when ≤10).
    - Remembrance days use a flower icon and "দোয়া ও স্মরণ".
26. **`26-emergency.jpg` → `EmergencyScreen` (`store_more_screens.dart`)**
    - **Card:** red header "✱ জরুরি তথ্য", red-tint blood group square, name, allergies, conditions, address. Footer "লক স্ক্রিনে দেখাচ্ছে · আপনি যা লিখেছেন, শুধু তা-ই". The existing lock-screen card feature stays as is.
    - **"বিপদে খবর দিন":** emergency contacts with dark call buttons.
    - Red **৯৯৯** card ("জাতীয় জরুরি সেবা — পুলিশ, ফায়ার সার্ভিস, অ্যাম্বুলেন্স") with a white call button.
    - "লক স্ক্রিনে দেখাবে" toggle.
27. **`27-shop.jpg` → `ShopScreen` / `ShopDetailScreen`**
    - **Header:** shop name + area, plus a switch-shop button (when there is more than one shop).
    - **Dark sales card:** "আজকের বিক্রি", receipts count, vs yesterday, a 7-day mini bar chart (today green), and the hand note "বরকত হোক".
    - **Buttons:** "+ বিক্রি" (green), "+ খরচ", "রসিদ".
    - **"বাকির খাতা":** only if the shop already tracks customer dues; otherwise omit and report it.
    - **"শেষ রসিদ":** number square, items, time · payment, amount.
28. **`28-search.jpg` → `SearchScreen`**
    - Active field with an accent ring, clear button and "বাতিল".
    - Type chips with counts.
    - **Results grouped:** ডকুমেন্ট (including text read from photos, with numbers masked), রিমাইন্ডার ও কাজ, নোট. Matches are highlighted `#F6E3A8`.
    - **"আগে খুঁজেছেন":** recent searches stored locally, never sent. Hand note "মুখে বলেও খোঁজা যায়"; mic FAB.

Pages not in the mockups keep their features and get the same kit: tasks list, reminders, transactions, person, cash form, new item, docs detail, vault item, medicines, inbox, trash, settings sub-pages, compass, help, feedback, tags, expiry, accounts, split, receipts, sound/ringtone, notification settings, family member, heir view, ask blood, and others. Restyle them in the same language (PageHeader, AppCard, RowItem, chips) so nothing looks old.

### 7. How to work (order)
1. Read §0–§6 and the mockup images (look at every one). Ask the 4 questions in §3.
2. **Tokens + kit:**
   - Implement §5 in `lib/ui/` (theme + components).
   - Make the existing app compile and look coherent with the new tokens.
   - Add the handwriting font; if it cannot be downloaded, use the fallback and ask.
3. **Screenshots before code freeze:**
   - Extend `test/dark/dark_shots_test.dart`, or add `test/design/new_ui_shots_test.dart`, to render the redesigned pages light **and** dark at 1170×2532.
   - Compare each with `docs/design/2026-10-24-new-ui/img/NN-*.jpg` side by side.
   - **Send the owner the light + dark screenshots of the first 4 pages (home, দিনলিপি, হিসাব, সংরক্ষণ) and wait for OK** before doing all 28.
4. Then do the rest page by page, keeping every test green.
   - Update test finders only when text or structure really moved.
   - Add tests for new computed bits: week progress, streaks, next-eligible blood date, now-line, "এই সপ্তাহে x/y", and similar.
5. **Run the full checks:**
   - `flutter analyze --no-pub` (0 warnings).
   - The full `flutter test --no-pub`, alone.
   - `python3 tool/i18n_missing.py` = 0.
   - Admin app tests (unchanged).
   - WordPress e2e (unchanged).
6. Bump to 2.46.0+97, commit, push, build `play_preview.yml`, re-sign, verify `FC:6C:FF:35`, and send both APKs.
7. Update `docs/HANDOFF.md` and `docs/pending-2026-10-22.md` (also in the claude.ai Project if one is attached).
8. **Report in Bengali:**
   - What changed, with screenshots.
   - What is **not verified** (real phone, small screens, large text, real dark mode on device, the handwriting font on device).
   - The data gaps you left out.
   - The file names.

### 8. Still pending from before (do not lose; from `docs/pending-2026-10-22.md`)
- **Owner:**
  - Install plugin 1.15.0.
  - Make NLU model `2026.10.22-bert2` live at 100%.
  - Turn on "কথা বোঝা আরও ভালো করতে সাহায্য করুন" and mode "চালু" for 5–10%.
  - Send the review text via the site's "সব কপি করুন".
  - Replace the Gemini key seen in a screenshot.
  - Play Console background-location declaration.
  - Two-phone family test; try the own ringtone, district auto-change, multi-select and swipe on his phone.
- **Claude, after the UI:**
  - Label the pasted review rows.
  - NLU step J (several actions in one message, follow-ups, corrections).
  - Retrain, after fixing the call-intent drop to 0% seen in the first retrain.
  - Step K rollout 10→100%.
  - Gemini latency (about 5.5 s).
  - Owner-only costs in the admin summary.
  - Voice-to-family.
  - Location history (only if asked).
  - Multi-select on more pages.
- **Needs permission (paid):** the AI paraphrase step (about $0.37). Not approved.

## PROMPT শেষ
