# যাচাই-সেটে মাপ — pred_bert.jsonl

যাচাই-সেট: 7117 সারি · ভবিষ্যদ্বাণী: 7117

## bert

সারি: 6961 · পুরো মিল (সব intent): 88.7% · প্রধান intent ধরা: 92.7% · আলাদা বাক্য ধরে: 5980/6731 (88.8%)

**আত্মবিশ্বাসের সীমা অনুযায়ী ফোনে সমাধান** (নিয়মে আত্মবিশ্বাস নেই — সিদ্ধান্ত নিলে ১.০)

| সীমা | ফোনে সমাধান | তার মধ্যে ঠিক |
|---|---|---|
| 0.00 | 6961 (100.0%) | 6176 (88.7%) |
| 0.50 | 4579 (65.8%) | 4218 (92.1%) |
| 0.60 | 4579 (65.8%) | 4218 (92.1%) |
| 0.70 | 4579 (65.8%) | 4218 (92.1%) |
| 0.80 | 4579 (65.8%) | 4218 (92.1%) |
| 0.90 | 4579 (65.8%) | 4218 (92.1%) |
| 0.95 | 4579 (65.8%) | 4218 (92.1%) |

মোছা: 131/163 ঠিক (80.4%); না-চাওয়া মোছার প্রস্তাব: 3 · টাকা: 2308/2417 ঠিক (95.5%)
ছোট সাধারণ উত্তর (শেখানোয় আছে, মূল হিসাবের বাইরে): 155/156
তথ্য (slot) হুবহু: 87/101

**উৎস অনুযায়ী**

| উৎস | সারি | পুরো মিল |
|---|---|---|
| angles | 438 | 89.5% |
| angles_holdout | 49 | 89.8% |
| crowd (untuned) | 5360 | 90.3% |
| intent500 | 495 | 92.7% |
| intent_holdout | 40 | 90.0% |
| master100 | 134 | 69.4% |
| persona | 164 | 87.2% |
| screens | 281 | 60.1% |

**অবস্থা অনুযায়ী**

| অবস্থা | সারি | পুরো মিল |
|---|---|---|
| await_kind | 1 | 100.0% |
| await_new_value | 39 | 69.2% |
| await_time | 23 | 78.3% |
| confirm_delete | 20 | 65.0% |
| confirm_save | 14 | 14.3% |
| dictating_list | 10 | 90.0% |
| idle | 6854 | 89.1% |

**intent-ওয়ারি (প্রধান intent ধরা)**

| intent | সারি | ধরা |
|---|---|---|
| cash_add | 969 | 97.1% |
| ledger_add | 898 | 99.3% |
| task_add | 775 | 75.0% |
| reminder_add | 660 | 99.8% |
| health_add | 585 | 100.0% |
| task_query | 417 | 96.4% |
| call | 328 | 100.0% |
| special_add | 308 | 100.0% |
| ledger_query | 288 | 97.6% |
| contact_add | 279 | 100.0% |
| cash_query | 242 | 98.8% |
| open_page | 207 | 95.7% |
| reminder_query | 189 | 74.1% |
| reminder_edit | 116 | 88.8% |
| rename | 109 | 98.2% |
| task_delete | 79 | 84.8% |
| reminder_delete | 75 | 84.0% |
| complain_help | 63 | 55.6% |
| task_remind | 59 | 64.4% |
| inform | 46 | 89.1% |
| task_done | 41 | 97.6% |
| task_edit | 37 | 94.6% |
| select | 32 | 37.5% |
| correct | 26 | 15.4% |
| reminder_stop | 24 | 79.2% |
| menu_project | 12 | 58.3% |
| dictate_start | 11 | 72.7% |
| confirm_yes | 9 | 11.1% |
| doc_query | 8 | 62.5% |
| item_delete | 8 | 25.0% |
| menu_zakat | 7 | 100.0% |
| note_add | 7 | 85.7% |
| calendar_query | 6 | 33.3% |
| menu_notes | 4 | 50.0% |
| contact_query | 3 | 100.0% |
| ledger_set | 3 | 66.7% |
| memory_add | 3 | 33.3% |
| menu_habit | 3 | 100.0% |
| out_of_scope | 3 | 0.0% |
| special_query | 3 | 33.3% |
| menu_health | 2 | 100.0% |
| menu_shop | 2 | 0.0% |
| profile_query | 2 | 50.0% |
| smalltalk | 2 | 100.0% |
| vault_add | 2 | 0.0% |
| briefing | 1 | 0.0% |
| menu_accounts | 1 | 100.0% |
| menu_backup | 1 | 100.0% |
| menu_cash | 1 | 0.0% |
| menu_medicine | 1 | 0.0% |
| menu_people | 1 | 0.0% |
| note_query | 1 | 0.0% |
| task_reopen | 1 | 100.0% |
| vault_query | 1 | 100.0% |

**সবচেয়ে বেশি গুলিয়ে যাওয়া (ঠিক → যা পড়া হলো)**

| ঠিক | পড়া হলো | বার |
|---|---|---|
| task_add | special_add | 124 |
| reminder_query | task_query | 47 |
| task_add | task_edit | 35 |
| task_add | reminder_add | 18 |
| cash_add | menu_savings | 13 |
| reminder_edit | task_edit | 12 |
| select | cancel | 12 |
| task_delete | item_delete | 12 |
| task_remind | reminder_add | 12 |
| reminder_delete | item_delete | 9 |
| cash_add | menu_shop | 8 |
| task_remind | reminder_query | 7 |
| ledger_add | cash_add | 6 |
| task_query | briefing | 5 |
| task_add | confirm_yes | 5 |
| item_delete | task_delete | 5 |
| confirm_yes | inform | 4 |
| complain_help | menu_medicine | 4 |
| confirm_yes | task_remind | 3 |
| complain_help | confirm_no | 3 |
| task_add | smalltalk | 3 |
| ledger_query | cash_query | 3 |
| task_add | memory_add | 3 |
| task_query | calendar_query | 3 |
| complain_help | task_query | 3 |
