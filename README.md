# Digital Brain

**আপনার ব্যক্তিগত স্মৃতি ও নিরাপদ তথ্যভান্ডার** — Your Personal Memory & Secure Vault.

Android app (Flutter) to keep passwords, contacts, money lent and borrowed, notes and dates, by voice (Bengali) or by typing, and to ask for them back in plain Bengali.

## Download

Every build on `main` publishes a release:

- Most phones: https://github.com/iamsaifsaiful/digital_brain/releases/latest/download/digital-brain.apk
- Old 32-bit phones: https://github.com/iamsaifsaiful/digital_brain/releases/latest/download/digital-brain-armv7.apk

## What it does

- **Voice, in Bengali**: “সজীবকে ৫০০ টাকা দিলাম”, “সজীবের কাছে আমার কত টাকা পাওনা?”, “ডোমেইন রিনিউ করার তারিখটা মনে করিয়ে দাও”, “আমার Wi-Fi-এর নাম কী?”, “মনে রাখো: …”. Money sentences are confirmed before saving; unclear ones ask (debt repaid, new loan, or other spending).
- **ধার-দেনা**: balance per person, running history, edit/delete with undo, CSV report.
- **Vault**: website/app/Wi-Fi/bank/email logins. Opening one needs fingerprint or PIN; passwords hide again after 30 s, copied passwords leave the clipboard after 30 s, and they are never read aloud.
- **Contacts, notes, reminders** (one-off, monthly, yearly; phone notification N days before).
- **Security**: 4-digit app PIN (salted PBKDF2), fingerprint unlock, auto-lock (immediately / 30 s / 1 min / 5 min), wait after 5 wrong PINs, screenshots blocked (FLAG_SECURE), Android cloud backup off.
- **Encrypted backup**: everything in one `.dbrain` file locked with its own password (PBKDF2 + AES-256-GCM), restorable on a new phone.

## How data is stored

Everything is in one file on the phone, encrypted with AES-256-GCM. The 256-bit key is random and kept only in Android Keystore (via `flutter_secure_storage`). Nothing leaves the phone except speech recognition audio (Android's recogniser; Bengali usually needs internet) and backups the user shares.

## Code

- `lib/logic/` — Bengali parser (`parser.dart`), ledger maths, phrases spoken by the app, search, CSV, password generator.
- `lib/services/` — encryption and data file, PIN/biometric lock, voice (speech_to_text + flutter_tts), notifications, files/clipboard.
- `lib/screens/` — the screens from the design canvas.
- `test/` — logic, storage/crypto and widget tests (real fonts loaded).

## Build

CI (`.github/workflows/build.yml`) runs `tool/setup_platforms.sh` (creates Gradle files with `flutter create`), analyze, tests, and `flutter build apk --release --split-per-abi`, then publishes a GitHub release.

Locally: `bash tool/setup_platforms.sh && flutter pub get && flutter run`.

## Not yet

Play Store upload key and signing, iOS build (needs a Mac/Xcode and an Apple Developer account), sync between devices, PDF/Excel reports, multiple currencies.

Fonts: Hind Siliguri and Anek Bangla (SIL Open Font License, licences in `assets/fonts/`).
