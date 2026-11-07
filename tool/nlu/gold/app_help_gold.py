# Held-out questions about the app (owner, 7 Nov 2026), written by hand in
# shapes the app_help templates do not use, by many kinds of people — and
# look-alikes that are NOT app questions. Never trained on.
#   python3 tool/nlu/gold/app_help_gold.py → tool/nlu/gold/app_help.jsonl
import json, os

ROWS = [
    # app_help — what, how, where, can, free; old, young, polite, rushed, regional, Banglish, English
    ('এই যাকাতের অংশটা আসলে কী হিসাব করে', 'app_help'),
    ('ভল্টে কী কী জিনিস রাখা যায় একটু বলেন', 'app_help'),
    ('ব্যবসায়ী মোড চালু করলে কী বদলায়?', 'app_help'),
    ('আমার মতো বুড়া মানুষ এই অ্যাপ দিয়া কী করমু', 'app_help'),
    ('ব্যাকআপ জিনিসটা না নিলে কী ক্ষতি', 'app_help'),
    ('ওছিয়তনামা লিখলে কে দেখতে পাবে', 'app_help'),
    ('ফোন হারাইলে আমার হিসাব কি ফেরত পামু', 'app_help'),
    ('রক্ত লাগলে এই অ্যাপে অনুরোধ দেওয়ার নিয়মটা কী', 'app_help'),
    ('দোকানের মালের স্টক কেমনে রাখে এইখানে', 'app_help'),
    ('গ্রাহকরে হোয়াটসঅ্যাপে তাগাদা পাঠানোর ব্যবস্থা আছে নি', 'app_help'),
    ('ডকুমেন্টসে রাখা কাগজ কেউ চুরি করে দেখতে পারবে না তো?', 'app_help'),
    ('কোন কোন জিনিস প্রিমিয়াম ছাড়া চলে না', 'app_help'),
    ('ক্যালেন্ডারে হিজরি তারিখ দেখার সুযোগ আছে কি', 'app_help'),
    ('খরচ বিশ্লেষণ পাতাটায় কী দেখায়', 'app_help'),
    ('অন্যান্য হিসাব আর আয়-ব্যয়ের মধ্যে তফাত কী', 'app_help'),
    ('বিকাশ আর ব্যাংকের টাকা আলাদা আলাদা দেখার ব্যবস্থা কোনখানে', 'app_help'),
    ('পরিবারের লোকেরে কাজ পাঠানো যায় কেমনে কন', 'app_help'),
    ('মুছে দেওয়া নোট আবার ফিরাইতে চাই, উপায় কী', 'app_help'),
    ('রিসাইকেল বিনে জিনিস কতদিন থাকে', 'app_help'),
    ('অ্যালার্ম আর রিমাইন্ডারের পার্থক্যটা বুঝাইয়া দেন', 'app_help'),
    ('মুখে বললেই কাজ হবে, নাকি টাইপ করা লাগবে?', 'app_help'),
    ('ইন্টারনেট না থাকলেও কি এইটা চলে', 'app_help'),
    ('রসিদ পিডিএফ বানাইয়া দেওয়ার সিস্টেম কোথায়', 'app_help'),
    ('ছাড় শতাংশে দিতে চাইলে কোনটা টিপতে হয়', 'app_help'),
    ('কিবলা দেখার জিনিসটা কি এই অ্যাপেই আছে', 'app_help'),
    ('ট্যাগ লাগাইলে কী সুবিধা', 'app_help'),
    ('আমার সম্পর্কে অংশে কী লেখা থাকে', 'app_help'),
    ('ভাই এইটার ফিচারগুলা একটু ঘুরায়া দেখাও', 'app_help'),
    ('নতুন ফোন কিনছি, পুরান ফোনের সব আনব কিভাবে', 'app_help'),
    ('শিশুর টিকার হিসাব রাখার কোনো জায়গা আছে?', 'app_help'),
    ('হাঁটা আর পানির অভ্যাস ট্র্যাক করার অপশন কোথায় লুকানো', 'app_help'),
    ('তৈরি তালিকা মানে কোন তালিকার কথা বলতেছে', 'app_help'),
    ('ডিলারের কাছে বাকির হিসাব রাখা সম্ভব?', 'app_help'),
    ('জাকাতের হিসাবে ব্যবসার মাল ধরে কিনা', 'app_help'),
    ('রিমাইন্ডার কয়টা পর্যন্ত ফ্রিতে দিতে পারব', 'app_help'),
    ('অক্ষর বড় করার সেটিং কোনখানে পাই', 'app_help'),
    ('মাসের রিপোর্টটা কিসের ভিত্তিতে বানায়', 'app_help'),
    ('শুরুতে কোনটা দিয়ে ধরব বুঝতেছি না, গাইড করো', 'app_help'),
    ('এক জনের ধার কত বাকি সেটা দেখার পদ্ধতি কী', 'app_help'),
    ('ফ্যামিলিতে লোকেশন দেখা কিভাবে কাজ করে', 'app_help'),
    ('ki ki feature ache ei app e', 'app_help'),
    ('vault e password rakhle safe to?', 'app_help'),
    ('business mode on korle ki hoy bhai', 'app_help'),
    ('zakat er option ta kothay lukano', 'app_help'),
    ('backup kivabe nibo bujhte parchi na', 'app_help'),
    ('reminder r alarm er difference ki', 'app_help'),
    ('what does the business mode actually do', 'app_help'),
    ('how does the password vault keep things safe', 'app_help'),
    ('where would I find my old receipts', 'app_help'),
    ('is the backup automatic or do I press something', 'app_help'),
    ('explain the zakat page to me', 'app_help'),
    ('what features do I get with premium', 'app_help'),
    # Look-alikes that are not questions about the app
    ('রিমাইন্ডার বাজলো না কেন আজকে', 'complain_help'),
    ('বারবার উল্টাপাল্টা হিসাব দেখাও কেন', 'complain_help'),
    ('যাকাতের পাতাটা খুলে দাও', 'open_page'),
    ('ব্যাকআপ এখনই নাও', 'menu_backup'),
    ('আমার এ মাসের যাকাত কত দাঁড়াল', 'menu_zakat'),
    ('কাল সকাল ৯টায় ব্যাংকে যাওয়ার কথা মনে করাও', 'reminder_add'),
    ('ফেসবুকের পাসওয়ার্ডটা দেখাও', 'vault_query'),
    ('পাসপোর্টের ছবি কোথায় রেখেছি', 'doc_query'),
    ('ডিম কিনতে হবে', 'task_add'),
    ('রক্তচাপ কমানোর উপায় কী', 'out_of_scope'),
    ('যাকাত কাদের দেওয়া যায়', 'out_of_scope'),
    ('show me my reminders', 'reminder_query'),
    ('open the settings', 'open_page'),
]


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(here, 'app_help.jsonl'), 'w') as f:
        for i, (t, it) in enumerate(ROWS, 1):
            f.write(json.dumps(dict(id=f'app_help-{i:03d}', source='app_help', tuned=False, speaker='claude', how='typed', fixture='empty', now='2026-11-07T14:30',
                                    before=[], state='idle', text=t, heard_alts=[], intent=[it], slots={},
                                    note='owner, 7 Nov: questions about the app; written by hand, not from the templates'), ensure_ascii=False) + '\n')
    print(len(ROWS), 'rows')


if __name__ == '__main__':
    main()
