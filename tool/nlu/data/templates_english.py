# English and Banglish requests (owner, 6 Nov: "বাংলা ইংরেজি বুঝে" — members
# say and type English, Bangla in Latin letters, and the two mixed). Same
# intents and slots as the Bangla templates; values from english.py.
# Nothing here is copied from tool/nlu/gold (generate.py drops near matches).
T = {}

T['reminder_add'] = '''
[remind me|please remind me|can you remind me] {en_date} {en_time} to {en_rem}
[set a reminder|add a reminder|create a reminder] {en_time} {en_date} for {en_remn}
{en_date} {en_time}[,|] remind me about {en_remn}

{bl_date} {bl_time} {bl_rem} er kotha [mone koriye dio|mone koriye diyo|remind koro]
{bl_rem} er [reminder|alarm] [dao|set koro|diye rakho] {bl_date} {bl_time}
[amake|] {bl_time} {bl_rem} [mone koriye dio|remind koro]

{date} {time} {en_remn} এর [reminder|alarm] [দাও|সেট করো|দিয়ে রাখো]
{bl_date} {bl_time} meeting আছে, reminder [দাও|দিও]
'''

T['task_add'] = '''
[add|put] {en_todo} [to my to-do list|to my tasks|to the list]
[i need to|i have to|i must] {en_todo} {en_date}
[new task|add task|task]: {en_todo}

{bl_date} {bl_todo:must}
{bl_date} {bl_todo} [lagbe|korbo|er kaj ache]
{bl_todo} [kaj ta|task ta] [list e add koro|তালিকায় রাখো|add kore dao]
{bl_todo} [ke|] kajer list e [rakho|add koro]

{date} {en_todo} [করতে হবে|কাজে রাখো|লিস্টে রাখো]
'''

T['task_query'] = '''
[show|show me|read out] my [tasks|to-do list|todo list] [for today|for tomorrow|]
what do i [have to do|need to do] {en_date}[?|]
[any tasks|anything pending] {en_date}[?|]

{bl_date} er [kaj gula|kajer list|task gula] [dekhao|bolo|dao]
amar [kaj gula|todo list] [dekhao|bolo][?|]
'''

T['task_done'] = '''
[i finished|i have done|done with|mark as done] {en_todo}
{en_todo} is done

{bl_todo} [hoye geche|shesh|korsi|kore felsi]
'''

T['task_delete'] = '''
[delete|remove] {en_todo} [from my tasks|from the list|]
[i don't need to|no need to] {en_todo} anymore[, remove it|]

{bl_todo} [kaj ta|ta] [bad dao|muche dao|delete koro]
'''

T['reminder_query'] = '''
[what|which] reminders do i have {en_date}[?|]
[show|list] my reminders
when is my [next reminder|next alarm][?|]

amar [reminder gula|alarm gula] [dekhao|bolo]
{bl_date} [kon|ki] reminder [ache|ase][?|]
'''

T['ledger_add'] = '''
@ledger_kind=lent
[i lent|i gave] {en_name} {en_amount}[ as a loan|]
{en_name} borrowed {en_amount} from me
{bl_name} ke {en_amount} [dhar dilam|dilam|dhar disi]
{bl_name} ke {en_amount} দিলাম, ferot dibe

@ledger_kind=borrowed
[i borrowed|i took] {en_amount} from {en_name}
{en_name} lent me {en_amount}
{bl_name} er kach theke {en_amount} [dhar nilam|nilam|nisi]

@ledger_kind=received
{en_name} [paid me back|returned] {en_amount}
{bl_name} {en_amount} [ferot dise|ferot dilo|dilo]

@ledger_kind=repaid
i [paid back|returned] {en_amount} to {en_name}
{bl_name} ke {en_amount} ferot [dilam|disi]
'''

T['ledger_query'] = '''
how much does {en_name} owe me[?|]
how much do i owe {en_name}[?|]
[who owes me money|show my loans|show who owes me][?|]

{bl_name} er kache koto [pabo|pai][?|]
{bl_name} ke koto [dibo|dite hobe][?|]
'''

T['cash_add'] = '''
@cash_kind=expense
[i spent|spent|paid] {en_amount} [on|for] {en_item}
{en_item} [cost me|was] {en_amount}
{bl_item} e {en_amount} [khoroch holo|khoroch hoise|gelo|dilam]
{bl_item} [kinlam|kinsi] {en_amount} [diye|te]

@cash_kind=income
[i got|got|received] {en_amount} [as|from] {en_income}
{en_income} [came in|credited][,|] {en_amount}
{bl_income} {en_amount} [pailam|paisi|ashlo]
'''

T['cash_query'] = '''
how much did i spend [today|this month|this week|yesterday][?|]
[show|what are] my expenses [this month|today|]
what is my balance[?|]

[aj|ei mashe|ei shoptahe] koto khoroch [holo|hoise][?|]
amar [hisab|khoroch] [dekhao|bolo]
'''

T['call'] = '''
[call|phone|ring] {en_name}[ please|]
[make a call to|give a call to] {en_name}

{bl_name} ke [call dao|phone dao|call koro]
'''

T['note_add'] = '''
[note that|make a note:|write down that|save a note:] {en_note}
[just |]note [it|this]: {en_note}

note [rakho|kore rakho]: {bl_note}
{bl_note}, eta note kore [rakho|rakhen]
'''

T['calendar_query'] = '''
what's the date [today|tomorrow][?|]
what day is it [today|tomorrow][?|]
when is [maghrib|asr|isha|fajr] today[?|]

[aj|kal] koto tarikh[?|]
[aj|kal] ki bar[?|]
'''

T['open_page'] = '''
[open|go to|show me] {en_page}
{en_page} [kholo|open koro|dekhao]
'''

T['smalltalk'] = '''
[hi|hello|hey][ there|][!|]
[how are you|what's up|how is it going][?|]
[thanks|thank you|thanks a lot|ok thanks][!|]
[good morning|good night|good evening]
[lol|haha|hahaha]
[kemon acho|ki khobor|ki koro][?|]
[dhonnobad|thank you vai|thanks bhai]
'''

T['complain_help'] = '''
[that's wrong|that is not what i said|you got it wrong]
[you don't understand me|you are not listening][!|]
how do i use this[ app|][?|]
[bujhlam na|ki bolle][?|]
'''

T['out_of_scope'] = '''
[order a pizza|book a cab|buy me a ticket][ for me|]
[write my essay|do my homework|apply for the job for me]
'''
