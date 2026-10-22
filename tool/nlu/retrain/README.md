# শেখার চক্র (ধাপ I)

```
git push -f origin HEAD:nlu-retrain     # GitHub Actions: .github/workflows/nlu_retrain.yml
```

1. `fetch.py` — সার্ভার থেকে লেবেলসহ নমুনা (`/nlu/ci/export`, GitHub secret `MA_NLU_CI_KEY` দিয়ে; key বানানো হয় সাইটের সেটিংস পাতায়)।
2. `labels.py` — কোন উত্তর ঠিক: এডমিনের লেবেল → সদস্যের সংশোধন → ক্লাউড → ফোন (≥০.৯, কোনো ভুলের সংকেত নেই)। নাম ফেরত বানানো নামে; শুধু intent শেখায়। → `out/data/real.jsonl`, যা `generate.py` মিশিয়ে নেয় (যাচাই-সেটের কাছাকাছি হলে বাদ)।
3. `bert.py` — আবার শেখানো, যাচাই-সেট পড়া।
4. `gate.py` — এখনকার মডেলের (`tool/nlu/train/pred_live.jsonl`) চেয়ে কোনো intent ১ পয়েন্টের বেশি খারাপ, বা মোছা/টাকা খারাপ, বা না-চাওয়া মোছা বেশি → বাতিল।
5. `publish.py` — পাস হলে GitHub release + সার্ভারে **draft**। এডমিন অ্যাপের "AI › মডেল" থেকে ১০% দিয়ে চালু।
6. রিপোর্ট `nlu-results` শাখায় (`gate.md`)।

কোনো মডেল সবার জন্য চালু হলে তার যাচাই-সেটের ফল (`pred_bert.jsonl`) `tool/nlu/train/pred_live.jsonl`-এ রাখুন — পরের বার তার সাথে তুলনা হবে।
