# যাচাই-সেট (gold set)

শুধু মাপার জন্য। **এখানকার কোনো বাক্য বা তার কাছাকাছি রূপ কখনো শেখানোর ডেটায় যাবে না**
(`tool/nlu/data/` তৈরি করার সময় কাছাকাছি মিল খুঁজে বাদ দেওয়া হবে)।

| ফাইল | কোথা থেকে |
|---|---|
| `screens.jsonl` | `test/screens_*_test.dart`, `test/regression_b85_test.dart` — ফোনের স্ক্রিনশটের কথোপকথন (হাতে লেবেল: `labels_screens.py`) |
| `master100.jsonl` | `docs/master100-records.md` (হাতে লেবেল: `labels_master100.py`) |
| `intent500.jsonl`, `intent_holdout.jsonl` | `test/intent500_test.dart`, `test/intent_holdout_test.dart` |
| `angles.jsonl`, `angles_holdout.jsonl` | `test/angles_test.dart`, `test/angles_holdout_test.dart` |
| `real.jsonl` | **আপনার আসল বাক্য** (এখনো খালি) |

`build_gold.py` আবার চালালে প্রথম পাঁচটা নতুন করে তৈরি হয়; `real.jsonl` হাত দেওয়া হয় না।

`tuned: true` মানে পুরনো নিয়ম এই উৎস দেখে ঠিক করা হয়েছিল — সেখানে পুরনো নিয়মের ফল আসলের চেয়ে ভালো দেখায়।
সৎ মাপ পাওয়া যাবে `real.jsonl` থেকে (`tuned: false`)।

## `real.jsonl`-এর ফরম্যাট (এক লাইনে একটা JSON)

```json
{"id": "real-0001", "source": "real", "tuned": false, "speaker": "saif", "how": "mic",
 "fixture": "empty", "now": "2026-10-22T09:30",
 "before": ["আমার কাজের তালিকা দাও"],
 "state": "idle",
 "text": "৩নং কাজটা কাল সরাও",
 "heard_alts": ["তিন নং কাজটা কাল সরাও"],
 "intent": ["task_edit"],
 "slots": {"list_ref": "3", "date": "কাল"},
 "note": ""}
```

- `how`: `mic` (ফোনে বলা — অ্যাপ যা শুনেছে সেটাই `text`), `typed`।
- `heard_alts`: recogniser-এর অন্য শোনা রূপ (থাকলে)।
- `before`: এই কথার আগে যা বলা হয়েছিল (প্রসঙ্গ দরকার হলে); `state`: তখন অ্যাপ কী জিজ্ঞেস করে অপেক্ষায় ছিল (`docs/nlu-spec.md`-এর অবস্থার নাম)।
- `intent`, `slots`: `docs/nlu-spec.md`-এর নাম। নিশ্চিত না হলে খালি রাখুন — আমি লেবেল করে আপনাকে দেখাব।
- সহজ উপায়: শুধু বাক্যগুলো এক লাইনে একটা করে একটা লেখা ফাইলে দিন (আর পারলে কোনগুলো মাইকে বলা); বাকি ঘর আমি ভরব।
