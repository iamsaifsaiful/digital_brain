# Short answers that only make sense after the app asked something or showed
# a list. Each entry: state, what the app showed ('tasks', 'reminders',
# 'ledger', 'none'), what it asked, and templates per intent.
# The same answer can mean different things in different states ("হ্যাঁ",
# "৩নং"); the state and the shown list are part of the example.
CTX = []


def C(state, shown, asked, **by_intent):
    CTX.append(dict(state=state, shown=shown, asked=asked, T=by_intent))


YES = '''
[হ্যাঁ|হ্যাঁ দাও|ঠিক আছে|আচ্ছা|জি|জি হ্যাঁ|হুম|হুম করো|করো|দাও|ওকে|হ্যাঁ, ঠিক আছে|অবশ্যই|হ ঠিক আছে|হ, দেন|জ্বি|জ্বি হ্যাঁ|হ্যাঁ ভাই|ঠিক|ঠিক আছে, করো|আচ্ছা করো|হ্যাঁ, এটাই|হুম, ঠিক|ওকে করো|yes|ha|hya]
[হ্যাঁ|জি|আচ্ছা|ঠিক আছে], [করে ফেলো|এগিয়ে যাও|তাই করো|কোনো সমস্যা নেই]
'''
NO = '''
[না|না থাক|দরকার নেই|নাহ|উহু|না, রেখো না|না না|লাগবে না|না, করো না|না ভাই|জি না|না, দরকার নাই|না, এখন না|নো|na|না, ঠিক আছে থাক]
'''
CANCEL = '''
[বাতিল|থাক|এটা বাদ, কিছু করো না|কিছু রাখো না|ছেড়ে দাও|বাদ দাও এই প্রশ্ন|ক্যানসেল|বাতিল করো|থাক, লাগবে না|থাক বাদ দাও|কিছুই করো না|এই কাজটা বাতিল|আগের কথা বাদ|ক্যানসেল করো]
'''
SELECT = '''
{listref}
[শুধু |]{listref}
{num}

[শুধু |কেবল ]{year}[গুলো|]
[শুধু |]{month}[গুলো|]
'''

C('confirm_delete', 'tasks', 'এই কাজগুলো মুছে দেব?', confirm_yes=YES + '''
[হ্যাঁ মুছে দাও|মুছে দাও|মুছো|হ্যাঁ, সব মুছো|ডিলিট করো]
''', confirm_no=NO + '''
[মুছো না|রেখে দাও|না, থাকুক]
''', cancel=CANCEL, select=SELECT)

C('confirm_delete', 'reminders', 'এই রিমাইন্ডারগুলো মুছে দেব?', confirm_yes=YES, confirm_no=NO, cancel=CANCEL, select=SELECT)

C('confirm_save', 'none', 'রাখব?', confirm_yes=YES + '''
[রাখো|হ্যাঁ রাখো|সেভ করো|লিখে রাখো]
''', confirm_no=NO, correct='''
[না, |]{date}
{date} না, {date2}
[না, |]{time}
{amount} না, {amount2}
[না, |]{amount2} হবে
[ভুল, |এটা ভুল, ]{person} না, {person2}
[রাত|সকাল|বিকাল] না, [সকাল|রাত|সন্ধ্যা]
''')

C('confirm_batch', 'tasks', 'এই কাজগুলো একসাথে রাখব?', confirm_yes=YES, confirm_no=NO, select=SELECT, correct='''
{num}[ কাজটা|] {date} না, {date2}
[না, |]{num} কাজটা {date2}
''', task_remind='''
[এই দুটিতে|এগুলোতে|সবগুলোতে|{listref}-এ] রিমাইন্ডার দাও
[এগুলোর|প্রথম দুটোর] জন্য {time} রিমাইন্ডার দিও
''', rename='''
{num} কাজের নাম {newtitle}
{num} কাজটার নাম হবে {newtitle}
''')

C('await_time', 'none', 'কয়টায় মনে করাব?', inform='''
{time}
{time} [দিও|দাও|মনে করিও]
{daypart}
{time}[ ঠিক আছে|ই ভালো|]
''', confirm_yes='''
[হ্যাঁ, ওই সময়েই|ওই সময়েই দাও|যেটা বললে সেটাই|তুমি যেটা বলেছো সেটা]
''', cancel=CANCEL)

C('await_ampm', 'none', 'সকাল না সন্ধ্যা?', inform='''
[সকাল|সকালে|রাত|রাতে|বিকাল|বিকেলে|সন্ধ্যা|সন্ধ্যায়|দুপুর|দুপুরে|ভোরে]
[সকালের|রাতের|বিকালের] [টা|দিকে|]
''', cancel=CANCEL)

C('await_new_value', 'none', 'নতুন তারিখ বা সময় কত?', inform='''
{date}
{time}
{date} {time}
{date}[ দাও| করো| সরাও]
''', cancel=CANCEL)

C('await_person', 'none', 'কার সাথে লেনদেন?', inform='''
{person:plain}
{person:plain}[ এর সাথে| এর|র সাথে|]
[আচ্ছা, |]{person:plain}
''', cancel=CANCEL)

C('await_kind', 'none', 'দিলেন না নিলেন? / আয় না খরচ?', inform='''
@ledger_kind=lent
[দিলাম|আমি দিয়েছি|ধার দিয়েছি|ধার দিলাম]

@ledger_kind=borrowed
[নিলাম|আমি নিয়েছি|ধার নিয়েছি]

@cash_kind=expense
[খরচ|নিজের খরচ|খরচ হয়েছে|ব্যয়]

@cash_kind=income
[আয়|আয় হয়েছে|ইনকাম|পেয়েছি]
''', cancel=CANCEL)

C('pick_one', 'tasks', 'কয়েকটা মিলেছে — কোনটা?', select='''
{num}
[শুধু |]{num}[ কাজটা|]
{listref}
''', cancel=CANCEL + '''
[কোনোটাই না|কোনোটা না, থাক]
''')

C('pick_one', 'reminders', 'কয়েকটা রিমাইন্ডার মিলেছে — কোনটা?', select='''
{num}
[শুধু |]{num}[ রিমাইন্ডারটা|]
''', cancel=CANCEL)

C('clarify', 'reminders', 'আগেরটা সরাব, নাকি আরেকটা রিমাইন্ডার রাখব?', select='''
@opt=1
[সরাও|আগেরটা সরাও|ওটাই সরাও|আগেরটাই বদলাও|সরিয়ে দাও]

@opt=2
[আরেকটা|নতুন একটা রাখো|আরেকটা রাখো|আলাদা রাখো|দুটোই থাকুক]
''')

C('clarify', 'tasks', 'আজকেরগুলো, নাকি সব?', select='''
@opt=1
[আজকেরগুলো|শুধু আজকের|আজকেরটা]

@opt=2
[সব|সবগুলো|সব কয়টা]
''')

C('dictating_list', 'none', 'বলুন, লিখছি — শেষ হলে "শেষ" বলুন', task_add='''
{todo:title}
{date} {todo:title}
{todo:must}
[তারপর |আর |]{todo:title}
{num12}. {todo:title}
''', dictate_end='''
[শেষ|আর নেই|এটুকুই|এই কয়টাই|লেখা শেষ|ব্যস|এতটুকুই|হয়ে গেছে, রেখে দাও|আর কিছু না|শেষ, সেভ করো|এই পর্যন্তই|আপাতত এটুকুই|লিস্ট শেষ|আর কিছু নাই|এগুলোই|শেষ, রেখে দাও|এই কয়টা রাখো|তালিকা শেষ]
''', cancel=CANCEL)
