# Templates for what the 40-person walk (23 Oct 2026) showed the model did
# not know: money in said by its source or kind, a project's money given by
# someone or paid to a worker, money sent home, own-money questions of a
# time, a project asked about, a family member's reading, habits said as a
# routine, a day's plan asked with its own word. Written fresh — the walk's
# sentences are gold (tool/nlu/gold/persona.jsonl) and never trained on;
# generate.py drops anything close to them. See templates_tasks.py for the format.
T = {}

T['cash_add'] = '''
@cash_kind=income
{isrc} থেকে {amount} [পেলাম|পাইছি|পেয়েছি|এলো|আসলো]
{pdate} {isrc} থেকে {amount} [পেলাম|পাইলাম]
{isrc:gen} [টাকা|পেমেন্ট] {amount} [পেলাম|ঢুকলো|এসেছে]

@cash_kind=income
{wage} [পেলাম|পাইছি|পেয়েছি] {amount}
{pdate} {wage} {amount} [পেলাম|পাইলাম|হাতে পেলাম]
{wage} বাবদ {amount} [পেলাম|এলো]
{wage:gen} {amount} [তুললাম|হাতে পাইছি]

@cash_kind=income
[আজ|আজকে|গতকাল] {earn} [হলো|হইছে|হয়েছে] {amount}
[আজ|আজকে] {amount} {earn} [হলো|হইলো|করলাম]
{pdate} {earn} {amount}

@cash_kind=income
{parent} {pocket} [জন্য|টাকা] {amount} [দিলো|দিল|দিয়েছে|দিলেন]
{parent} আমাকে {amount} [দিলো|দিয়েছে] {pocket} [জন্য|খরচ]

@cash_kind=income
{tenant} [এই মাসের|এ মাসের|গত মাসের] ভাড়া {amount} [দিলেন|দিল|দিয়েছে|দিয়ে গেল]
{tenant} {amount} ভাড়া [দিলেন|দিয়েছেন]
ভাড়া [পেলাম|পাইছি|এলো] {amount}

@cash_kind=income
{project:loc} {giver} {amount} [দিলো|দিলেন|দিয়েছে|পাঠালো|দিয়ে গেল]
{project:loc} [আজ |]বিক্রি {amount}
{project:loc} {amount} [এলো|এসেছে|জমা হলো|উঠলো]

@cash_kind=expense
{project:loc} {worker:ke} {amount} [দিলাম|দিয়েছি|দিছি|পরিশোধ করলাম]
{project:loc} {worker:ke} [বেতন|মজুরি|পারিশ্রমিক] {amount} [দিলাম|দিয়েছি]
{project:loc} {item} {price}
{project:loc} {item} বাবদ {price} [খরচ|দিলাম|গেল]

@cash_kind=expense
[বাড়িতে|গ্রামে|গ্রামের বাড়িতে] {family:ke} {amount} [পাঠালাম|পাঠাইছি|পাঠিয়েছি]
[বাড়িতে|গ্রামে] {amount} [পাঠালাম|পাঠাইলাম|পাঠিয়ে দিলাম]
{family:ke} [সংসার খরচ|খরচের টাকা] {amount} পাঠালাম

@cash_kind=expense
{item} [গেল|লাগলো|লাগল|খরচা হলো] {price}
{item} {price}[ গেল| লাগলো|]
'''

T['cash_query'] = '''
[আজ|আজকে|এই সপ্তাহে|এ সপ্তাহে|এই মাসে|এ মাসে|গত মাসে] [হাতে |]কত [থাকল|থাকলো|রইল|বাঁচল|থাকে][?|]
[আজকে|আজ] [হাতে|পকেটে] কত [আছে|রইলো][?|]

[আজ|এই সপ্তাহে|এ সপ্তাহে|এ মাসে|গত মাসে|গত সপ্তাহে] কত {earn} [হলো|হইল|হয়েছে|করলাম][?|]
{earn} কত [হলো|হইছে] [আজ|এ সপ্তাহে|এ মাসে][?|]

[এই মাসে|এ মাসে|গত মাসে|এ বছর] [ভাড়া|বেতন|কমিশন|পেনশন|মজুরি] কত [পেলাম|এলো|পাইছি|উঠলো][?|]
[এই মাসে|এ মাসে|গত মাসে] [বাড়িতে|গ্রামে] কত [পাঠালাম|পাঠাইছি][?|]

{project:loc} [কত আছে|কত টাকা আছে|কত লাভ হলো|এখন পর্যন্ত কত খরচ|কত বাকি আছে|কত জমলো][?|]
{project:gen} [হিসাব দাও|অবস্থা বলো|লাভ কত|খরচ কত হলো|টাকা কত আছে][?|]
'''

T['health_add'] = '''
@health_kind=weight
{kin} ওজন {weight}
{kin} ওজন [মাপলাম|নিলাম], {weight}

@health_kind=bp
{kin} প্রেশার {bp}
{kin} [বিপি|প্রেশার] মাপলাম {bp}

@health_kind=sugar
{kin} সুগার {sugar}
'''

T['menu_health'] = '''
@op=list
[আমার|{kin}] [প্রেশার|সুগার|ওজন] [কেমন যাচ্ছে|কত ছিল|শেষ কত ছিল|কেমন আছে][?|]
[আমার|{kin}] [প্রেশার|সুগারের] [অবস্থা|মাপগুলো] [বলো|দেখাও][?|]
'''

T['menu_habit'] = '''
@op=add
[প্রতিদিন|রোজ] [ফজরের পর|সকালে|রাতে|ঘুমানোর আগে|বিকেলে] {habit}
[প্রতিদিন|রোজ] {habit}[, অভ্যাসে রাখো|, অভ্যাস হিসেবে রাখো|]

@op=tick
[আজ|আজকে] {habit} [করেছি|করলাম|হয়ে গেছে]

@op=streak
[এই সপ্তাহে|এ মাসে] কত দিন {habit} [করেছি|হয়েছে][?|]
{habit} [কত দিন হলো|টানা কত দিন][?|]
'''

T['task_query'] = '''
{wdgen} কী কী [ডেলিভারি|মিটিং|ক্লাস|কাজ|অর্ডার|পরীক্ষা][?| আছে?]
[কাল|পরশু|আজ] কী কী [ডেলিভারি|মিটিং|ক্লাস|অর্ডার] আছে[?|]
{todo:title} কবে [যেন|আছে|রাখা][?|]
'''

T['task_query'] += '''
[todo|to do|to-do] [list|liste] [dao|dekhao|bolo|show koro]
[amar |][kajer|kaj er] [list|talika] [ta |][dao|dekhao|bolo]
[aj|kal|ajke|kalke] [ki ki|koto] kaj [ache|ase][?|]
'''

T['open_page'] = '''
{page} [খোলো|খুলো|খুলে দাও|দেখাও][ তো| একটু|]
'''

T['reminder_query'] = '''
[আমার |]{rem} [কখন|কয়টায়][?| যেন?]
'''

# Data the gold showed missing (round 6): "আর লাগবে না" is a stop (the
# spec), not a removal; "আমার যাকাত কত" is the zakat menu.
T['reminder_stop'] = '''
{rem:gen} [রিমাইন্ডার|রিমাইন্ডারটা|অ্যালার্ম] আর [দরকার নেই|লাগবে না|দিতে হবে না|চাই না]
{rem:gen} কথা আর [মনে করিও না|মনে করাতে হবে না|মনে করাইও না|বলতে হবে না]
{person:er} {special:gen} রিমাইন্ডার আর [লাগবে না|দরকার নেই]
{sdate} এর রিমাইন্ডার আর [লাগবে না|দরকার নেই|দিও না]
'''

# Round 3 tried more stop sentences ("আর বাজবে না", "বন্ধ করে দাও"): the
# model then read 8 gold stops as removals — the dangerous way. Taken out
# again (round 4); a stop must never look like a delete.

T['menu_zakat'] = '''
@op=calc
[আমার |][এ বছর |এই বছর |]যাকাত কত [দিতে হবে|হলো|আসে|হয়][?|]
[আমার |]যাকাতের হিসাব [দাও|করে দাও|বলো]
[এ বছর|এবার] [আমার |]কত টাকা যাকাত [দিতে হবে|আসে][?|]
'''
