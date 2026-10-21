# Templates: people's money (ledger), own income/spending (cash) and the
# money menus. See templates_tasks.py for the format.
T = {}

T['ledger_add'] = '''
@ledger_kind=lent
{person:ke} {amount} [ধার দিলাম|ধার দিয়েছি|দিলাম|দিয়েছি|হাওলাত দিলাম]
{pdate} {person:ke} {amount} [ধার দিলাম|দিলাম]
{person:ke} {amount} দিলাম, [ফেরত দেবে|পরে দেবে|ধার হিসেবে]
{person} আমার কাছ থেকে {amount} [নিল|নিয়েছে|ধার নিল|নিয়ে গেল]
{person:ke} {account:loc} {amount} [পাঠালাম|পাঠিয়েছি], [ধার হিসেবে|পরে ফেরত দেবে]
{person:ke} {amount} [দিছি|দিলাম গো|দিয়া আইলাম]

@ledger_kind=borrowed
{person:theke} {amount} [ধার নিলাম|নিয়েছি|ধার করেছি|হাওলাত নিলাম|নিলাম]
{pdate} {person:theke} {amount} [ধার নিলাম|নিয়েছি]
{person} আমাকে {amount} ধার [দিল|দিয়েছে]
{person:er} থেকে {amount} [নিলাম|ধার নিছি]

@ledger_kind=received
{person} {amount} ফেরত [দিল|দিয়েছে|দিয়ে গেল]
{person} বাকির {amount} [দিয়ে গেল|দিয়েছে|শোধ করল]
{pdate} {person} {amount} [ফেরত দিয়েছে|শোধ দিল]
{person} [ধারের|পাওনার] {amount} [দিয়েছে|ফেরত দিল]

@ledger_kind=repaid
{person:ke} {amount} ফেরত [দিলাম|দিয়েছি|দিয়ে দিলাম]
{person:er} [ধারের|পাওনা] {amount} [শোধ করলাম|দিয়ে দিলাম|পরিশোধ করেছি]
{pdate} {person:ke} {amount} [শোধ দিলাম|ফেরত দিলাম]

@ledger_kind=borrowed pair=ledger_query
{person} {amount} পাবে[ আমার কাছে|]
{person} আমার কাছে {amount} পায়

@ledger_kind=lent pair=ledger_query
{person:er} কাছে {amount} পাব
{person:er} কাছে আমার {amount} পাওনা[ আছে|]
'''

T['ledger_set'] = '''
{person} এখন [মোট|সব মিলিয়ে] {balance} পাবে
{person:er} কাছে আমার [সব মিলিয়ে|মোট] {balance} [দেনা|পাওনা]
{person} এখন আমার কাছে {balance} পায়
{person:ke} এখনো মোট {balance} দিতে হবে
{person:er} সাথে হিসাব: [সে|ও] {balance} পাবে
{person:er} [পাওনা|হিসাব] {balance} [করে দাও|ঠিক করো|লিখে রাখো]
{person:er} সাথে হিসাব মিলিয়ে [দেখলাম|নিলাম], [মোট|এখন] {balance}
'''

T['ledger_query'] = '''
@pair=ledger_query
{person} কত [টাকা |]পাবে[?|]
{person:er} কাছে কত [পাব|বাকি|পাওনা][?|]
{person:ke} কত [দেব|দিতে হবে|দেওয়া বাকি][?|]
{person:er} [হিসাব|লেনদেন] [দাও|দেখাও|বলো]
{person:er} সাথে [হিসাব কত|কত লেনদেন হয়েছে][?|]

[আমি |]কাকে কত [দেব|দিতে হবে][?|]
[কে কে টাকা পাবে|কার কাছে কত পাব|আমার মোট পাওনা কত|আমার মোট দেনা কত][?|]
[শুধু |]পাওনাগুলো [দাও|দেখাও]
[ধারের|পাওনা-দেনার|লেনদেনের] হিসাব [দাও|দেখাও|বলো]
{person} [কত পায় আমার কাছে|কত দেবে আমাকে][?|]
'''

T['cash_add'] = '''
@cash_kind=expense pair=ledger_cash
{pdate} {item:loc} {price} [খরচ হলো|খরচ|গেল|লাগল]
{item} {price}
{item} {price}[, খরচে লেখো|, খরচ খাতায় রাখো|, লিখে রাখো]
{qty} {item:buy} {price}
{item:buy} {qty} {price}[ দিয়ে কিনলাম|]
{price} দিয়ে {item:buy} কিনলাম
{pdate} {price} দিয়ে {qty} {item:buy} [কিনলাম|আনলাম]
{item} বাবদ {price} [খরচ|খরচ হলো|গেল]
{pdate} {item:buy} [কিনলাম|কিনেছি] {price}[ দিয়ে|]
{account} থেকে {item} {price} [দিলাম|পে করলাম]
{item} {price}, খাত {category:own}

@cash_kind=income
{income} {amount:big} [পেলাম|পেয়েছি|আসলো|ঢুকলো]
{pdate} {income} বাবদ {amount:big} [আয় হলো|পেলাম]
{account:loc} {income} {amount:big} [এসেছে|ঢুকেছে]
{pdate} {amount} [আয় হলো|ইনকাম হলো], {income}
{income} [পাইছি|পাইলাম] {amount:big}
'''

T['cash_query'] = '''
[আয় ব্যয়ের|আয়-ব্যয়ের|খরচের] হিসাব [দাও|দেখাও|বলো]
{dategen} খরচ [কত|বলো|দেখাও][?|]
{month} [মোট |]খরচ কত[?|]
[এই মাসে|এ মাসে|গত মাসে|এ সপ্তাহে] কত [খরচ হলো|আয় হলো|গেল][?|]
{category} খাতে কত [খরচ হলো|গেল][?|]
{item:loc} এ মাসে কত গেল[?|]
{project} [প্রজেক্টের |]হিসাব [দেখাও|দাও]
[এ মাসে|এই মাসে] আয়ের চেয়ে খরচ [বেশি|কম] কিনা[?| দেখো]
'''

T['menu_accounts'] = '''
@op=balance
[একাউন্টে|অ্যাকাউন্টে] কত টাকা আছে[?|]
{account:loc} কত [আছে|টাকা আছে][?|]
{account:gen} ব্যালান্স কত[?|]
সব [একাউন্ট|অ্যাকাউন্ট] [মিলে|মিলিয়ে] কত[?|]

@op=transfer
{account} থেকে {account2:loc} {amount} [পাঠালাম|ট্রান্সফার করলাম|সরালাম]
{account:gen} {amount} {account2:loc} [নিলাম|পাঠিয়েছি]

@op=fee
{account} {amount:fee} [কেটেছে|চার্জ কেটেছে|ফি নিয়েছে]
{account} থেকে {amount:fee} [চার্জ|ফি] কেটে নিল

@op=set_balance
{account:loc} এখন {amount} আছে
{account:gen} ব্যালান্স {amount} [করো|ঠিক করো|লিখে রাখো]

@op=withdraw_spend
[এটিএম|{account}] থেকে {amount} তুললাম, {amount2} [বাজারে গেল|খরচ হলো]
'''

T['menu_savings'] = '''
@op=goal_add
{goal:gen} জন্য {amount:big} [জমানোর লক্ষ্য রাখো|লক্ষ্য রাখো]
নতুন [লক্ষ্য|সঞ্চয়ের লক্ষ্য]: {goal}, {amount:big}

@op=deposit
{goal} [ফান্ডে|লক্ষ্যে] {amount} [জমালাম|রাখলাম|জমা দিলাম]
{goal:gen} জন্য {amount} [জমিয়েছি|রেখে দিলাম]

@op=withdraw
[সঞ্চয়|{goal} ফান্ড] থেকে {amount} [তুললাম|উঠালাম|নিলাম]

@op=goal_left
[লক্ষ্যে|{goal} লক্ষ্যে] আর কত বাকি[?|]
[সব লক্ষ্যের|সঞ্চয়ের] অবস্থা [বলো|দেখাও]
'''

T['menu_installment'] = '''
@op=paid
[এ মাসের|এই মাসের] [ডিপিএস|কিস্তি|লোনের কিস্তি] [দিয়েছি|দিলাম|দেওয়া হয়েছে]
[ডিপিএস|কিস্তি] [জমা দিলাম|দিয়ে দিয়েছি]

@op=not_paid
[কিস্তি|ডিপিএস] [এখনো দিইনি|দেওয়া হয়নি|দেই নাই]

@op=unpay
[ডিপিএসের|কিস্তির] টিক ভুল, [তুলে দাও|উঠিয়ে দাও]
[ভুল করে|ভুলে] [কিস্তিতে|ডিপিএসে] টিক দিয়েছি
'''

T['menu_shop'] = '''
@op=sale
দোকানে [আজ |]{amount} [বিক্রি|বিক্রি হলো|সেল]
[আজ |]নগদ বিক্রি {amount}
{pdate} দোকানে {amount} [বেচাকেনা|বিক্রি] হয়েছে

@op=credit_sale pair=shop_ledger
{person:ke} {amount:bare} টাকার মাল [বাকিতে দিলাম|দিলাম], {amount2} দিল
বাকিতে {amount:bare} টাকার মাল দিলাম {person:ke}
{person:ke} {amount:bare} টাকার [মাল|জিনিস] বাকিতে [দিলাম|দিয়েছি]

@op=today
দোকানের [আজকের|আজ] হিসাব[ দাও| দেখাও|]
আজ দোকানে কত বিক্রি হলো[?|]

@op=calc
{num12}টা × {unitp} কত[?|]
{num12}টা [গুণ|গুন] {unitp} কত হয়[?|]
'''

T['menu_cash'] = '''
@op=recategorize
{item} খরচটা {category} খাতে [সরাও|নাও|রাখো]
শেষ খরচটার খাত [বদলে|পাল্টে] {category}
{item} খরচ {category:loc} [নাও|রাখো]

@op=dupes
[একই খরচ দুবার উঠেছে কিনা দেখো|ডুপ্লিকেট খরচ খোঁজো|দুবার লেখা খরচ আছে কিনা দেখো]
'''

T['menu_project'] = '''
@op=create
{project} নামে নতুন [হিসাব|প্রজেক্ট] খোলো
নতুন প্রজেক্ট: {project}
{project:gen} হিসাব আলাদা খোলো

@op=budget
{project} প্রজেক্টের বাজেট {amount:big}
{project:gen} বাজেট [বাড়িয়ে|কমিয়ে] {amount:big} [করো|দাও]

@op=close
{project} প্রজেক্ট [শেষ|শেষ হয়েছে|বন্ধ করো]
'''

T['menu_zakat'] = '''
@op=price
[আজকের|এখন] [সোনার|রুপার|স্বর্ণের] দাম [কত|বলো|দাও][?|]
[২২|২১|১৮] ক্যারেট [সোনার |]দাম [কত|বলো|আজ কত][?|]
[বাজুসের|বাজুস] [সোনার|রুপার] দাম দাও
ভরি প্রতি [সোনার|রুপার] দাম কত[?|]

@op=set_price
[আজকের|এখনকার] [দাম|সোনার দাম] যাকাতে [বসাও|লাগাও|বসিয়ে দাও|বসিয়ে হিসাব করো]
'''
