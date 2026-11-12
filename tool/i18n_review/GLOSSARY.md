# English style for My Assistant (owner, 12 Nov 2026: make the English standard and professional)

Work: tool output all.json (5138 strings_en.dart rows: i, bn, en, where). For each chunk, write
changes to p_<from>.json as {"<i>": "<proposed English>"}; rows not listed keep the current English
(after the automatic fixes below). Then build the sheet: # | বাংলা | এখনকার ইংরেজি | প্রস্তাবিত ইংরেজি | বদল? | কোথায়.

## Conventions
- US English spelling: color, recognize, installment, canceled, center, favorite, license.
- Sentence case for buttons, labels, titles and messages; feature names keep capitals (Income & Expenses, Password Vault).
- Money: ৳1,200 (never "taka"/"Tk" in UI; "taka" ok only inside spoken examples).
- Curly apostrophe ’ and quotes “ ”.
- Assistant voice: first person, short, plain, contractions ok ("I didn’t catch the time").
- Buttons: verb first ("Save", "Add income", "Delete"). Confirm: "Delete this note?".
- Avoid literal Bangla shapes: "Wrote ৳500" → "Recorded ৳500"; "kept" → "saved"; "made" → "created".
- Counts: "{0} tasks" fine; placeholders unchanged and all kept.

## Glossary (bn → en)
- হোম → Home; দিনলিপি (tab) → Planner; হিসাব (tab) → Money; সংরক্ষণ (tab) → Library; আরও → More
- আয়-ব্যয় → Income & Expenses; আয় → Income; খরচ/ব্যয় → Expense(s) / spent; খাত → Category
- এখন আছে → Current balance; ব্যালেন্স → Balance; মূল হিসাব/মূল টাকা → Main balance; ভরি → bhori
- লেনদেন / ধার-দেনা (page) → Loans; আমি পাব → Owed to me; আমি দেব → I owe; বকেয়া → Dues; শোধ → Repay(ment)
- অন্যান্য হিসাব / আলাদা হিসাব / প্রকল্প → Projects
- অ্যাকাউন্ট → Accounts; সঞ্চয় → Savings; কিস্তি → Installment; লক্ষ্য → Goal
- মাসের রিপোর্ট → Monthly report; খরচ বিশ্লেষণ → Spending insights; খরচ ভাগাভাগি → Split expenses
- কাজ / কাজের তালিকা → Task / To-do list; রিমাইন্ডার → Reminder; আগাম মনে করানো → Early alert
- বিশেষ দিন → Special days; অভ্যাস → Habits; ওষুধ → Medicines; ডায়েরি → Diary; তৈরি তালিকা → Ready-made checklists
- নোট → Notes; ডকুমেন্টস/কাগজপত্র → Documents; পাসওয়ার্ড ভল্ট → Password Vault; যোগাযোগ → Contacts; ট্যাগ → Tags
- ওছিয়তনামা → Will (Wasiyyah); উত্তরাধিকারী → Heir; ফ্যামিলি → Family
- যাকাত → Zakat; স্বাস্থ্য → Health; জরুরি → Emergency; কাগজের মেয়াদ → Document expiry; ব্লাড ডোনেশন → Blood donation
- রিসাইকেল বিন → Trash; ব্যাকআপ → Backup; প্রিমিয়াম → Premium; সহজ মোড → Simple mode; আমার সম্পর্কে → About me
- ব্যবসায়ী মোড → Business mode; বিক্রি → Sales/Sale; গ্রাহক → Customers; ডিলার → Suppliers; স্টক → Inventory;
  বাকিতে → On credit; বাকি আদায় → Payment collected; তাগাদা → Payment reminder; মাল কেনা → Purchases; রসিদ → Receipt; ছাড় → Discount
