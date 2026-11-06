# English and Banglish (Bangla in Latin letters) values for the templates in
# templates_english.py (owner, 6 Nov: "বাংলা ইংরেজি বুঝে"). Values use the
# same forms as the Bangla ones (rel:1, wd:শুক্রবার, 09:00, ?10:00, idx:2 …).
import random

NAMES = ['Rahim', 'Karim', 'Salma', 'Nasrin', 'Jamal', 'Rubel', 'Mitu', 'Sumon', 'Rina', 'Tanvir', 'Shila', 'Hasan', 'Faruk', 'Nadia', 'Imran', 'Sabbir', 'Lima', 'Arif']
KIN_EN = [('my brother', 'ভাই'), ('my sister', 'বোন'), ('my wife', 'বউ'), ('my mother', 'মা'), ('my father', 'বাবা'), ('my uncle', 'মামা')]
KIN_BL = [('vaiya', 'ভাইয়া'), ('apu', 'আপু'), ('ammu', 'আম্মু'), ('abbu', 'আব্বু'), ('mama', 'মামা'), ('chacha', 'চাচা')]

DATES_EN = [('today', 'rel:0'), ('tomorrow', 'rel:1'), ('day after tomorrow', 'rel:2'), ('on Friday', 'wd:শুক্রবার'), ('on Sunday', 'wd:রবিবার'),
            ('next Monday', 'wd:সোমবার'), ('on the 25th', 'dom:25'), ('on the 3rd', 'dom:3'), ('this Saturday', 'wd:শনিবার'), ('next week', 'week:+1')]
DATES_BL = [('aj', 'rel:0'), ('ajke', 'rel:0'), ('kal', 'rel:1'), ('kalke', 'rel:1'), ('porshu', 'rel:2'), ('shukrobar', 'wd:শুক্রবার'),
            ('robibar', 'wd:রবিবার'), ('shamner shombar', 'wd:সোমবার'), ('25 tarikh', 'dom:25'), ('agami shoptahe', 'week:+1')]
TIMES_EN = [('at 9 am', '09:00'), ('at 7:30 pm', '19:30'), ('at 10', '?10:00'), ('at 6 in the morning', '06:00'), ('at 8 tonight', '20:00'),
            ('at noon', '12:00'), ('at 4 pm', '16:00'), ('at 5:15', '?05:15'), ('at 11 pm', '23:00')]
TIMES_BL = [('sokal 9 tay', '09:00'), ('rat 8 tay', '20:00'), ('bikel 4 tay', '16:00'), ('dupur 2 tay', '14:00'), ('shondha 7 tay', '19:00'),
            ('10 tay', '?10:00'), ('sokal 6 tay', '06:00'), ('rat 10:30 e', '22:30')]
AMOUNTS = [500, 1000, 1500, 200, 250, 3000, 5000, 750, 120, 80, 2500, 10000, 600, 450]
TODO_EN = ['buy groceries', 'pay the electricity bill', 'call the doctor', 'go to the bank', 'submit the report', 'pick up the kids',
           'book the train tickets', 'renew my passport', 'clean the room', 'send the invoice', 'visit grandma', 'fix the fan']
# (said as a thing to do, said as "must do")
TODO_BL = [('bazar kora', 'bazar korte hobe'), ('current bill dewa', 'current bill dite hobe'), ('doctor ke call kora', 'doctor ke call dite hobe'),
           ('bank e jawa', 'bank e jete hobe'), ('report jama dewa', 'report jama dite hobe'), ('baccha ke school theke ana', 'baccha ke school theke ante hobe'),
           ('train er ticket kata', 'train er ticket katte hobe'), ('passport renew kora', 'passport renew korte hobe'), ('ghor porishkar kora', 'ghor porishkar korte hobe'),
           ('invoice pathano', 'invoice pathate hobe'), ('nanu bari jawa', 'nanu bari jete hobe'), ('fan thik kora', 'fan thik korate hobe')]
# "remind me to …"
REM_EN = ['take my medicine', 'join the client meeting', 'pray Asr', 'call mom', 'turn off the gas', 'water the plants', 'go to the dentist']
# "a reminder for …"
REMN_EN = ['my medicine', 'the client meeting', 'Asr prayer', 'the gas', 'the dentist appointment', 'the school pickup', 'the bill payment']
REM_BL = ['oshudh khawa', 'client er sathe meeting', 'namaz pora', 'ammu ke phone dewa', 'gas bondho kora', 'gach e pani dewa', 'dentist er appointment']
ITEM_EN = [('groceries', 'বাজার'), ('rice', 'বাজার'), ('lunch', 'খাবার'), ('rickshaw fare', 'যাতায়াত'), ('the electricity bill', 'বিল'),
           ('medicine', 'চিকিৎসা'), ('school fees', 'শিক্ষা'), ('a shirt', 'কাপড়'), ('house rent', 'ভাড়া'), ('fuel', 'যাতায়াত')]
ITEM_BL = [('bazar', 'বাজার'), ('chal', 'বাজার'), ('dupurer khabar', 'খাবার'), ('rickshaw bhara', 'যাতায়াত'), ('current bill', 'বিল'),
           ('oshudh', 'চিকিৎসা'), ('school er beton', 'শিক্ষা'), ('shirt', 'কাপড়'), ('basha bhara', 'ভাড়া'), ('tel', 'যাতায়াত')]
INCOME_EN = ['salary', 'my salary', 'rent from the shop', 'a bonus', 'the commission']
INCOME_BL = ['beton', 'salary', 'dokaner bhara', 'bonus', 'commission']
NOTES_EN = ['the car needs servicing next month', 'Rafiq will bring the papers on Thursday', 'the plumber charges 800 per visit', 'the wifi box is in the drawer']
NOTES_BL = ['gari next month service korte hobe', 'Rafiq bhai brihoshpotibar kagoj dibe', 'plumber protibar 800 ney', 'wifi er box drawer e']
PAGES_EN = [('settings', 'settings'), ('my notes', 'notes'), ('the calendar', 'calendar'), ('my reminders', 'reminders'), ('the money page', 'money')]


def amount_en(ctx):
    n = ctx.once('amount', lambda: random.choice(AMOUNTS))
    w = random.choice([f'{n} taka', f'{n} tk', f'{n:,} taka', f'tk {n}', f'{n}'])
    return w, 'amount', n


def value(ctx, name, var):
    """(words, slot, value) for an en_/bl_ placeholder, or None when it is not one."""
    pick = lambda key, xs: ctx.once(key, lambda: random.choice(xs))
    if name in ('en_name', 'bl_name'):
        if random.random() < 0.15:
            w, v = pick(name + 'k', KIN_EN if name == 'en_name' else KIN_BL)
            return w, 'person', v
        n = pick('name', NAMES)
        return n, 'person', n
    if name == 'en_date' or name == 'bl_date':
        w, v = pick(name, DATES_EN if name == 'en_date' else DATES_BL)
        return w, 'date', v
    if name == 'en_time' or name == 'bl_time':
        w, v = pick(name, TIMES_EN if name == 'en_time' else TIMES_BL)
        return w, 'time', v
    if name == 'en_amount':
        return amount_en(ctx)
    if name == 'en_todo':
        w = pick(name, TODO_EN)
        return w, 'title', w
    if name == 'bl_todo':
        noun, must = pick(name, TODO_BL)
        return (must if var == 'must' else noun), 'title', noun
    if name in ('en_rem', 'bl_rem', 'en_remn'):
        w = pick(name, {'en_rem': REM_EN, 'bl_rem': REM_BL, 'en_remn': REMN_EN}[name])
        return w, 'title', w
    if name in ('en_item', 'bl_item'):
        w, cat = pick(name, ITEM_EN if name == 'en_item' else ITEM_BL)
        return w, 'item', w
    if name in ('en_income', 'bl_income'):
        w = pick(name, INCOME_EN if name == 'en_income' else INCOME_BL)
        return w, 'item', w
    if name in ('en_note', 'bl_note'):
        w = pick(name, NOTES_EN if name == 'en_note' else NOTES_BL)
        return w, 'text', w
    if name == 'en_page':
        w, v = pick(name, PAGES_EN)
        return w, 'page', v
    return None
