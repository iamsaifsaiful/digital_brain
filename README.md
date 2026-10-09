# My Assistant

**আপনার ব্যক্তিগত সহকারী** — a Bengali voice assistant for busy people of every trade (shopkeepers, business owners, office workers, professionals).

Android app (Flutter): tell it what you would tell a human assistant — to-dos, timed reminders, calls and messages, phone numbers, customers' বাকি and other money owed, notes and passwords — by voice (Bengali, regional, Banglish) or by typing.

(Formerly “Digital Brain”; the package id `com.iamsaifsaiful.digital_brain` and the repo name stay the same so updates install over the old app.)

## Download

Every build on `main` publishes a release:

- Most phones: https://github.com/iamsaifsaiful/digital_brain/releases/latest/download/digital-brain.apk
- Old 32-bit phones: https://github.com/iamsaifsaiful/digital_brain/releases/latest/download/digital-brain-armv7.apk

## What it does

- **Assistant**: “কাল ব্যাংকে যেতে হবে” (to-do list), “কাল সকাল ১০টায় মিটিংয়ের কথা মনে করিয়ে দিও” / “৩০ মিনিট পরে…” (timed notification, exact when Android allows), “রহিমকে ফোন দাও”, “করিমকে মেসেজ দাও যে মাল পাঠিয়েছি” (dialer / SMS / WhatsApp opened ready to send; asks and saves the number if missing), “রহিমের নম্বর ০১৭… রাখো”, “করিম ৫০০ টাকার মাল বাকিতে নিল”, “আজ আমার কী কী আছে?” (today's to-dos, reminders, dues).
- **Chat by voice**: one tap starts a conversation — the app answers aloud, then listens again (say “থামো” to stop). A long message with several things in it is split into the separate facts, listed, and saved on one “হ্যাঁ”. Follow-up questions (whom? how much? which kind?) are asked in the chat.
- **Voice, in Bengali**: “সজীবকে ৫০০ টাকা দিলাম”, “সজীবের কাছে আমার কত টাকা পাওনা?”, “ডোমেইন রিনিউ করার তারিখটা মনে করিয়ে দাও”, “আমার Wi-Fi-এর নাম কী?”, “মনে রাখো: …”. Money sentences are confirmed before saving; unclear ones ask (debt repaid, new loan, or other spending).
- **লেনদেন**: balance per person, running history, edit/delete with undo, CSV report.
- **Vault**: website/app/Wi-Fi/bank/email logins. Opening one needs fingerprint or PIN; passwords hide again after 30 s, copied passwords leave the clipboard after 30 s, and they are never read aloud.
- **Contacts, notes, reminders** (one-off, monthly, yearly; phone notification N days before).
- **Security**: 4-digit app PIN (salted PBKDF2), fingerprint unlock, auto-lock (immediately / 30 s / 1 min / 5 min), wait after 5 wrong PINs, screenshots blocked (FLAG_SECURE), Android cloud backup off.
- **Encrypted backup**: everything in one `.dbrain` file locked with its own password (PBKDF2 + AES-256-GCM), restorable on a new phone.

## How data is stored

Everything is in one file on the phone, encrypted with AES-256-GCM. The 256-bit key is random and kept only in Android Keystore (via `flutter_secure_storage`). Nothing leaves the phone except speech recognition audio (Android's recogniser; Bengali usually needs internet) and backups the user shares.

## Code

- `lib/logic/` — Bengali parser (`parser.dart`), ledger maths, phrases spoken by the app, search, CSV, password generator.
- `lib/state/chat.dart` — the conversation (follow-up questions, saving several facts at once).
- `lib/services/` — encryption and data file, PIN/biometric lock, voice (speech_to_text + flutter_tts), notifications, files/clipboard.
- `lib/screens/` — the screens from the design canvas.
- `test/` — logic, storage/crypto and widget tests (real fonts loaded).

## Build

CI (`.github/workflows/build.yml`) runs `tool/setup_platforms.sh` (creates Gradle files with `flutter create`), analyze, tests, and `flutter build apk --release --split-per-abi`, then publishes a GitHub release.

Locally: `bash tool/setup_platforms.sh && flutter pub get && flutter run`.

## Not yet

Play Store upload key and signing, iOS build (needs a Mac/Xcode and an Apple Developer account), sync between devices, PDF/Excel reports, multiple currencies.

Font: Noto Sans Bengali (SIL Open Font License, licence in `assets/fonts/`).
