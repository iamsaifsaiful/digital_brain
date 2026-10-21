> ধাপ C, ২২ অক্টোবর ২০২৬। যাচাই-সেটে এখনকার নিয়মের ফল — পরের সব তুলনার ভিত্তি। তৈরি: `NLU_SHARD=k/8 NLU_BASELINE=1 flutter test test/nlu_baseline_test.dart` → `python3 tool/nlu/eval.py tool/nlu/out/baseline_old.jsonl`।

**সতর্কতা:** যাচাই-সেটের সব উৎসে পুরনো নিয়ম ঠিক করা হয়েছিল (tuned), তাই এই সংখ্যা আসলের চেয়ে ভালো দেখায়। screens-এর কথোপকথন খালি ডেটায় চালানো হয়েছে (টেস্টের নিজস্ব ডেটা ছাড়া), তাই সেখানে কিছু ভুল আসলে প্রসঙ্গের অভাব। সৎ মাপ আসবে `real.jsonl` (আপনার আসল বাক্য) থেকে।

# যাচাই-সেটে মাপ — baseline_old.jsonl

যাচাই-সেট: 1593 সারি · ভবিষ্যদ্বাণী: 1593

## পুরো চ্যাট (এখনকার নিয়ম, প্রসঙ্গসহ)

সারি: 1593 · পুরো মিল (সব intent): 85.2% · প্রধান intent ধরা: 85.7%

**আত্মবিশ্বাসের সীমা অনুযায়ী ফোনে সমাধান** (নিয়মে আত্মবিশ্বাস নেই — সিদ্ধান্ত নিলে ১.০)

| সীমা | ফোনে সমাধান | তার মধ্যে ঠিক |
|---|---|---|
| 0.00 | 1526 (95.8%) | 1357 (88.9%) |
| 0.50 | 1526 (95.8%) | 1357 (88.9%) |
| 0.60 | 1526 (95.8%) | 1357 (88.9%) |
| 0.70 | 1526 (95.8%) | 1357 (88.9%) |
| 0.80 | 1526 (95.8%) | 1357 (88.9%) |
| 0.90 | 1526 (95.8%) | 1357 (88.9%) |
| 0.95 | 1526 (95.8%) | 1357 (88.9%) |

মোছা: 126/163 ঠিক (77.3%); না-চাওয়া মোছার প্রস্তাব: 6 · টাকা: 69/96 ঠিক (71.9%)
তথ্য (slot) হুবহু: এই পদ্ধতি তথ্য দেয় না — মাপা হয়নি

**উৎস অনুযায়ী**

| উৎস | সারি | পুরো মিল |
|---|---|---|
| angles | 453 | 90.9% |
| angles_holdout | 50 | 94.0% |
| intent500 | 500 | 95.8% |
| intent_holdout | 40 | 97.5% |
| master100 | 179 | 82.1% |
| screens | 371 | 62.8% |

**অবস্থা অনুযায়ী**

| অবস্থা | সারি | পুরো মিল |
|---|---|---|
| await_new_value | 40 | 67.5% |
| await_time | 42 | 71.4% |
| confirm_delete | 49 | 79.6% |
| confirm_save | 64 | 81.2% |
| dictating_list | 15 | 86.7% |
| idle | 1383 | 86.5% |

**intent-ওয়ারি (প্রধান intent ধরা)**

| intent | সারি | ধরা |
|---|---|---|
| task_query | 276 | 96.7% |
| confirm_yes | 153 | 91.5% |
| task_add | 141 | 98.6% |
| reminder_edit | 116 | 89.7% |
| rename | 109 | 99.1% |
| task_delete | 79 | 82.3% |
| reminder_add | 75 | 94.7% |
| reminder_delete | 75 | 80.0% |
| reminder_query | 65 | 100.0% |
| complain_help | 61 | 41.0% |
| task_remind | 59 | 81.4% |
| inform | 44 | 88.6% |
| task_done | 41 | 100.0% |
| cash_add | 39 | 97.4% |
| task_edit | 37 | 86.5% |
| select | 32 | 28.1% |
| correct | 26 | 23.1% |
| reminder_stop | 24 | 100.0% |
| cash_query | 21 | 23.8% |
| ledger_add | 13 | 84.6% |
| ledger_query | 13 | 100.0% |
| dictate_start | 11 | 81.8% |
| item_delete | 8 | 12.5% |
| confirm_no | 7 | 100.0% |
| doc_query | 7 | 0.0% |
| special_add | 7 | 100.0% |
| menu_zakat | 6 | 50.0% |
| note_add | 6 | 100.0% |
| call | 5 | 0.0% |
| menu_project | 5 | 40.0% |
| calendar_query | 4 | 25.0% |
| dictate_end | 4 | 100.0% |
| menu_notes | 4 | 100.0% |
| out_of_scope | 3 | 0.0% |
| contact_query | 2 | 50.0% |
| ledger_set | 2 | 100.0% |
| smalltalk | 2 | 100.0% |
| special_query | 2 | 0.0% |
| cancel | 1 | 0.0% |
| menu_accounts | 1 | 100.0% |
| menu_backup | 1 | 100.0% |
| menu_cash | 1 | 0.0% |
| menu_medicine | 1 | 100.0% |
| menu_people | 1 | 100.0% |
| profile_query | 1 | 100.0% |
| task_reopen | 1 | 100.0% |
| vault_add | 1 | 0.0% |

**সবচেয়ে বেশি গুলিয়ে যাওয়া (ঠিক → যা পড়া হলো)**

| ঠিক | পড়া হলো | বার |
|---|---|---|
| reminder_edit | wait:clarify | 12 |
| select | reminder_edit | 12 |
| reminder_delete | none | 9 |
| complain_help | none | 9 |
| task_delete | item_delete | 9 |
| item_delete | none | 7 |
| task_query | profile_query | 6 |
| task_remind | reminder_add | 6 |
| correct | none | 6 |
| complain_help | profile_query | 5 |
| complain_help | note_query | 5 |
| confirm_yes | inform | 5 |
| complain_help | task_query | 5 |
| complain_help | correct | 5 |
| task_edit | wait:clarify | 4 |
| reminder_delete | item_delete | 4 |
| doc_query | profile_query | 4 |
| call | wait:phone | 4 |
| select | task_delete | 3 |
| task_delete | none | 3 |
| menu_zakat | profile_query | 3 |
| cash_query | profile_query | 3 |
| inform | reminder_add | 3 |
| correct | reminder_edit | 3 |
| confirm_yes | task_remind | 3 |

## শুধু parseAll() (প্রসঙ্গ ছাড়া)

সারি: 1593 · পুরো মিল (সব intent): 57.1% · প্রধান intent ধরা: 57.2%

**আত্মবিশ্বাসের সীমা অনুযায়ী ফোনে সমাধান** (নিয়মে আত্মবিশ্বাস নেই — সিদ্ধান্ত নিলে ১.০)

| সীমা | ফোনে সমাধান | তার মধ্যে ঠিক |
|---|---|---|
| 0.00 | 1429 (89.7%) | 910 (63.7%) |
| 0.50 | 1429 (89.7%) | 910 (63.7%) |
| 0.60 | 1429 (89.7%) | 910 (63.7%) |
| 0.70 | 1429 (89.7%) | 910 (63.7%) |
| 0.80 | 1429 (89.7%) | 910 (63.7%) |
| 0.90 | 1429 (89.7%) | 910 (63.7%) |
| 0.95 | 1429 (89.7%) | 910 (63.7%) |

মোছা: 20/163 ঠিক (12.3%); না-চাওয়া মোছার প্রস্তাব: 1 · টাকা: 74/96 ঠিক (77.1%)
তথ্য (slot) হুবহু: এই পদ্ধতি তথ্য দেয় না — মাপা হয়নি

**উৎস অনুযায়ী**

| উৎস | সারি | পুরো মিল |
|---|---|---|
| angles | 453 | 48.8% |
| angles_holdout | 50 | 44.0% |
| intent500 | 500 | 80.8% |
| intent_holdout | 40 | 90.0% |
| master100 | 179 | 48.6% |
| screens | 371 | 37.7% |

**অবস্থা অনুযায়ী**

| অবস্থা | সারি | পুরো মিল |
|---|---|---|
| await_new_value | 40 | 0.0% |
| await_time | 42 | 0.0% |
| confirm_delete | 49 | 2.0% |
| confirm_save | 64 | 0.0% |
| dictating_list | 15 | 66.7% |
| idle | 1383 | 65.0% |

**intent-ওয়ারি (প্রধান intent ধরা)**

| intent | সারি | ধরা |
|---|---|---|
| task_query | 276 | 92.4% |
| confirm_yes | 153 | 0.0% |
| task_add | 141 | 91.5% |
| reminder_edit | 116 | 24.1% |
| rename | 109 | 99.1% |
| task_delete | 79 | 17.7% |
| reminder_add | 75 | 94.7% |
| reminder_delete | 75 | 0.0% |
| reminder_query | 65 | 100.0% |
| complain_help | 61 | 49.2% |
| task_remind | 59 | 13.6% |
| inform | 44 | 0.0% |
| task_done | 41 | 90.2% |
| cash_add | 39 | 97.4% |
| task_edit | 37 | 78.4% |
| select | 32 | 0.0% |
| correct | 26 | 0.0% |
| reminder_stop | 24 | 91.7% |
| cash_query | 21 | 33.3% |
| ledger_add | 13 | 84.6% |
| ledger_query | 13 | 100.0% |
| dictate_start | 11 | 0.0% |
| item_delete | 8 | 75.0% |
| confirm_no | 7 | 0.0% |
| doc_query | 7 | 0.0% |
| special_add | 7 | 100.0% |
| menu_zakat | 6 | 50.0% |
| note_add | 6 | 100.0% |
| call | 5 | 100.0% |
| menu_project | 5 | 20.0% |
| calendar_query | 4 | 25.0% |
| dictate_end | 4 | 0.0% |
| menu_notes | 4 | 100.0% |
| out_of_scope | 3 | 0.0% |
| contact_query | 2 | 50.0% |
| ledger_set | 2 | 100.0% |
| smalltalk | 2 | 100.0% |
| special_query | 2 | 0.0% |
| cancel | 1 | 100.0% |
| menu_accounts | 1 | 100.0% |
| menu_backup | 1 | 100.0% |
| menu_cash | 1 | 0.0% |
| menu_medicine | 1 | 100.0% |
| menu_people | 1 | 100.0% |
| profile_query | 1 | 100.0% |
| task_reopen | 1 | 100.0% |
| vault_add | 1 | 100.0% |

**সবচেয়ে বেশি গুলিয়ে যাওয়া (ঠিক → যা পড়া হলো)**

| ঠিক | পড়া হলো | বার |
|---|---|---|
| confirm_yes | none | 142 |
| reminder_delete | item_delete | 72 |
| reminder_edit | reminder_add | 65 |
| task_delete | item_delete | 61 |
| task_remind | reminder_add | 46 |
| inform | reminder_add | 41 |
| select | note_query | 19 |
| reminder_edit | note_add | 12 |
| reminder_edit | reminder_query | 10 |
| select | note_add | 10 |
| task_add | note_add | 10 |
| task_query | note_query | 9 |
| complain_help | note_query | 9 |
| dictate_start | note_add | 8 |
| task_edit | task_add | 7 |
| confirm_no | none | 7 |
| task_query | profile_query | 6 |
| confirm_yes | note_query | 6 |
| complain_help | none | 5 |
| correct | task_add | 5 |
| complain_help | profile_query | 5 |
| correct | note_add | 5 |
| task_remind | reminder_query | 4 |
| menu_project | ledger_query | 4 |
| doc_query | profile_query | 4 |
