# Voice recognition: on-device test plan

The automated tests check what happens **after** a sentence is heard. They
feed written sentences, a repeated final result and the recogniser's
alternative guesses through the real chat logic. They cannot measure how
well the phone turns Bengali speech into text. That needs real audio on
real phones, recorded with the speaker's permission.

## Current engine (checked in the code)

- **Package:** `speech_to_text` 7.x. It uses Android's own `SpeechRecognizer`, which
  is usually Google's online service. Audio goes to Google even with the
  AI off; the Settings page says so.
- **Locale:** the app asks the recogniser for its languages and uses the ID
  it returns (`bn_BD`, then `bn_IN`, then any `bn`).
  - Android 13+ often lists only offline languages. In that case the app
    asks for `bn-BD`.
  - If the phone does not support it, the user sees "বাংলা চালু নেই" with the
    steps to add it.
- **One turn:** each turn has an ID (`_turn`). A result from an older
  turn is ignored.
  - Android ends a session at short pauses. The app opens a new session
    and joins the words until the user has been quiet for 1.3 s (the
    sentence sounds finished) or 2.6 s (it does not).
  - A gap of a few hundred milliseconds between sessions can lose a word.
    This is a limit of the platform recogniser.
- **Final text:** when the user goes quiet, the app asks the recogniser for
  its final text and waits up to 0.9 s for it. Partial text is only shown
  on screen.
- **Own voice:** by default the app finishes speaking, then opens the
  microphone, so it cannot hear itself. "উত্তরের মাঝে কথা বলে থামানো" in
  Settings turns on talking over long answers.
- **Errors:** permission denied, no recogniser, language missing,
  network, no speech and busy each have their own message. After a
  failure the user can type instead.

## What to record (about 60 short clips)

Record each sentence once in a quiet room and once with a fan running.
Use at least two speakers if possible.

| Group | Examples |
|---|---|
| Amounts | পাঁচশ, সাতশ, পাঁচ হাজার, দেড় হাজার, আড়াই হাজার, সাড়ে তিনশ, সাড়ে তিন হাজার |
| Names | সজীব, শফিক, সাইফুল, ইব্রাহিম, রহিম |
| Negatives | দিয়েছি / দিইনি, পেয়েছি / পাইনি |
| Dialect | দিছি, নিছি, পাইমু, মনে করাইও, টেয়া |
| Mixed | কাল eight pm-এ medicine reminder দাও |
| Days and times | কাল, পরশু, আগামী শুক্রবার, সকাল আটটা, আধা ঘণ্টা পরে |
| Pauses | "সজীবকে … পাঁচশ টাকা … ধার দিলাম", with a one-second pause at each "…" |
| Long | One 20–30 second sentence |

## What to note for each clip

1. Clip ID, speaker, room (quiet or fan) and phone model with its
   Android version.
2. The expected sentence, and the text the app showed (in the chat
   bubble).
3. Whether the name, the amount and any negative came out right.
4. Whether the start or end of the sentence was cut off.
5. Seconds from when you stopped speaking until the text appeared.

## How to judge

- **Amounts:** "পাঁচশ" and "৫০০" count as the same; "পাঁচ হাজার" does not.
- **Names:** a name counts as right only if it is the same person.
- **Overall:** count the words that were wrong. Ignore spelling variants
  (য়/য়) and punctuation, and list those ignored variants separately.

## Reading the results

If more than about 1 in 10 amounts or names are wrong in a quiet room,
the phone's recogniser is the limit. A different speech-to-text service
would then need to be compared on the same clips. That service would need
an account, has a cost and has its own privacy terms, so it will only be
set up with the owner's permission.
