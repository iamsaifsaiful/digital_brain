# Turns a template into a labelled sentence.
#
# Template syntax:
#   [a|b|c]      pick one (may be empty: [এই |] ); may hold placeholders
#   {name}       a slot value, e.g. {date}, {person:ke}, {todo:must}
# The words a placeholder writes are labelled with its slot; everything else
# is O. Labels are kept per character while filling, then cut into words, so
# an ending glued to a value ("{year}-এর") stays inside the value's word.
import random, re
import lexicon as L
import render as R

ALT = re.compile(r'\[([^\[\]]*)\]')
PH = re.compile(r'\{([a-z_0-9]+)(?::([a-z_0-9]+))?\}')


class Ctx:
    """One sentence's choices: the same {todo} or {person} reads the same
    everywhere in the sentence."""

    def __init__(self):
        self.memo = {}

    def once(self, key, make):
        if key not in self.memo:
            self.memo[key] = make()
        return self.memo[key]


def _person(ctx, key, case):
    name = ctx.once(key, L.person)
    return L.with_case(name, case or 'plain'), name


def _item(ctx, key):
    return ctx.once(key, lambda: random.choice(L.ITEMS))


def _qty(ctx):
    it = _item(ctx, 'item')
    unit = it[1]
    if not unit:
        return None
    n = random.choice([1, 1, 2, 2, 3, 5]) if unit != 'গ্রাম' else random.choice([200, 250, 500])
    ctx.memo['qtyn'] = n
    w = f'{R.digits(n) if unit != "গ্রাম" else L.bn(n)} {unit}'
    if n == 1 and random.random() < 0.3:
        w = f'এক {unit}'
    if unit == 'কেজি' and n == 1 and random.random() < 0.2:
        w = 'আধা কেজি'
        n = 0.5
        ctx.memo['qtyn'] = 0.5
    return w, f'{n} {unit}'


gen = L.gen


OWN_VARIANTS = {'person', 'person2', 'todo', 'rem', 'special', 'amount', 'amount2', 'balance', 'item', 'category', 'pname', 'account2'}


def value(ctx, name, var):
    """(words, slot, value) for one placeholder; words None = skip.
    {x:gen} / {x:loc} put any one-word-ish value in the genitive/locative."""
    if var in ('gen', 'loc') and name not in OWN_VARIANTS:
        w, slot, v = _value(ctx, name, None)
        return (L.gen(w) if var == 'gen' else L.loc(w)), slot, v
    return _value(ctx, name, var)


def _value(ctx, name, var):
    if name in ('person', 'person2'):
        w, v = _person(ctx, name, var)
        return w, 'person', v
    if name == 'todo':
        t = ctx.once('todo', L.todo)
        return t[var or 'title'], 'title', t['title']
    if name in ('date', 'date2'):
        w, v = ctx.once(name, R.date)
        return w, 'date', v
    if name in ('time', 'time2'):
        w, v = ctx.once(name, R.time)
        return w, 'time', v
    if name == 'daypart':
        w = ctx.once(name, lambda: random.choice(['সকালে', 'দুপুরে', 'বিকালে', 'বিকেলে', 'সন্ধ্যায়', 'রাতে', 'ভোরে']))
        return w, 'daypart', w.rstrip('েয়')
    if name in ('amount', 'amount2', 'balance'):
        n = ctx.once(name, lambda: R.amount(kind=var)[1])
        return R.amount_words(n, tail=var != 'bare'), ('amount' if name == 'amount' else name), n
    if name == 'price':
        it = _item(ctx, 'item')
        n = ctx.once(name, lambda: R.price(it[2][0], it[2][1], ctx.memo.get('qtyn', 1) if it[1] != 'গ্রাম' else ctx.memo.get('qtyn', 1)))
        return R.amount_words(n, tail=var != 'bare'), 'amount', n
    if name == 'item':
        if var == 'buy':
            ctx.once('item', lambda: random.choice([i for i in L.ITEMS if i[0] not in L.NOT_BOUGHT]))
        it = _item(ctx, 'item')
        w = it[0]
        if var == 'gen':
            w = L.gen(w)
        elif var == 'loc':
            w = L.loc(w)
        return w, 'item', it[0]
    if name == 'pdate':
        w, v = ctx.once(name, R.past_date)
        return w, 'date', v
    if name == 'dm':
        w, v = ctx.once(name, R.day_month)
        return w, 'date', v
    if name == 'qty':
        q = ctx.once('qty', lambda: _qty(ctx))
        return (q[0], 'quantity', q[1]) if q else (None, None, None)
    if name == 'category':
        it = _item(ctx, 'item')
        if var == 'own':
            return it[3], 'category', it[3]
        if var in ('near', 'nearloc'):
            near = {'বাজার': ['খাবার', 'সংসার'], 'খাবার': ['বাজার'], 'সংসার': ['বাজার'], 'যাতায়াত': ['অফিস', 'ভ্রমণ'], 'বিল': ['সংসার', 'বাসা'],
                    'চিকিৎসা': ['স্বাস্থ্য', 'পরিবার'], 'ভাড়া': ['বাসা', 'সংসার'], 'শিক্ষা': ['বাচ্চা', 'পরিবার'], 'কাপড়': ['কেনাকাটা', 'ঈদ'],
                    'দান': ['সদকা', 'পরিবার'], 'প্রজেক্ট': ['বাড়ির কাজ', 'নির্মাণ']}.get(it[3], ['অন্যান্য'])
            c = ctx.once('category', lambda: random.choice(near))
            return (L.loc(c) if var == 'nearloc' else c), 'category', c
        c = ctx.once('category', lambda: random.choice([c for c in ['বাজার', 'খাবার', 'যাতায়াত', 'বিল', 'চিকিৎসা', 'সংসার', 'শিক্ষা', 'কাপড়', 'দান', 'ভাড়া'] if c != it[3]]))
        return (L.loc(c) if var == 'loc' else c), 'category', c
    if name == 'pname':
        def mk():
            male = random.random() < 0.6
            return random.choice(L.MALE if male else L.FEMALE)
        n = ctx.once('person', mk)
        return L.with_case(n, var or 'plain'), 'person', n
    if name == 'shift':
        w, v = ctx.once(name, lambda: random.choice([('এক দিন', 1), ('দুই দিন', 2), ('তিন দিন', 3), ('এক সপ্তাহ', 7), ('২ দিন', 2), ('১ সপ্তাহ', 7)]))
        return w, 'shift_days', v
    if name == 'lastref':
        w, v = ctx.once(name, lambda: random.choice([('শেষেরটার', 'idx:-1'), ('শেষ কাজটার', 'idx:-1'), ('প্রথমটার', 'idx:1'), ('প্রথম কাজটার', 'idx:1')]))
        return w, 'list_ref', v
    if name == 'dom':
        d = ctx.once(name, lambda: random.randint(1, 28))
        return random.choice([f'{L.bn(d)} তারিখে', f'{L.bn(d)}{L.day_suffix(d)}', f'{L.bn(d)} তারিখ']), 'date', f'dom:{d}'
    if name == 'income':
        w = ctx.once(name, lambda: random.choice(L.INCOMES))
        return w, 'item', w
    if name == 'account':
        w = ctx.once(name, lambda: random.choice(L.ACCOUNTS))
        return w, 'account', w
    if name == 'project':
        w = ctx.once(name, lambda: random.choice(L.PROJECTS))
        return w, 'target', w
    if name == 'goal':
        w = ctx.once(name, lambda: random.choice(L.GOALS))
        return w, 'target', w
    if name == 'habit':
        w = ctx.once(name, lambda: random.choice(L.HABITS))
        return w, 'target', w
    if name == 'medicine':
        w = ctx.once(name, lambda: random.choice(L.MEDICINES))
        return w, 'item', w
    if name == 'doc':
        w = ctx.once(name, lambda: random.choice(L.DOCS))
        return w, 'target', w
    if name == 'note':
        w = ctx.once(name, lambda: random.choice(L.NOTE_FACTS))
        return w, 'text', w
    if name == 'notedomain':
        w = ctx.once(name, lambda: random.choice(L.NOTE_DOMAIN_FACTS))
        return w, 'text', w
    if name == 'notemoney':
        w = ctx.once(name, lambda: random.choice(L.NOTE_MONEY_FACTS))
        return w, 'text', w
    if name == 'secret':
        w = ctx.once(name, lambda: random.choice(L.SECRETS))
        return w, 'target', w
    if name == 'rem':
        w = ctx.once(name, lambda: random.choice(L.REMINDER_SUBJECTS))
        return (gen(w) if var == 'gen' else w), 'title', w
    if name == 'newtitle':
        w = ctx.once(name, lambda: random.choice([o[0] + ' ' + L.VERBS[o[1]][0] for o in L.TODO_OBJECTS] + ['শ্রমিক দিবস', 'বিজয় দিবস', 'অফিস মিটিং', 'শ্বশুর বাড়ি যাওয়া', 'ঈদের কেনাকাটা']))
        return w, 'new_title', w
    if name == 'special':
        w, v = ctx.once(name, lambda: random.choice(L.SPECIAL_KINDS))
        return (gen(w) if var == 'gen' else w), 'special_kind', v
    if name == 'page':
        w, v = ctx.once(name, lambda: random.choice(L.PAGES))
        return w, 'page', v
    if name == 'listref':
        w, v = ctx.once(name, R.list_ref)
        return w, 'list_ref', v
    if name in ('num', 'num2', 'num3'):
        k = ctx.once(name, lambda: random.randint(1, 9))
        if var == 'ta':
            # "চতুর্থটা", "৪ নম্বরটা": the item said alone.
            w = random.choice([L.ORDINALS[k] + 'টা', f'{L.bn(k)} নম্বরটা', f'{L.bn(k)}নংটা', f'{L.bn(k)} নম্বর কাজটা'])
        else:
            w = random.choice([f'{L.bn(k)}নং', f'{L.bn(k)} নম্বর', f'{L.bn(k)} নং', L.ORDINALS[k]])
        return w, 'list_ref', f'idx:{k}'
    if name == 'year':
        w, v = ctx.once(name, R.year_filter)
        return w, 'filter_year', v
    if name == 'month':
        w, v = ctx.once(name, R.month_filter)
        return w, 'filter_month', v
    if name == 'minutes':
        n = ctx.once(name, lambda: random.choice([5, 10, 15, 20, 30, 45, 60]))
        w = random.choice([f'{R.digits(n)} মিনিট', f'{L.bn(n)} মিনিট']) if n != 60 else random.choice(['এক ঘণ্টা', '১ ঘণ্টা'])
        return w, 'minutes', n
    if name == 'repeat':
        w, v = ctx.once(name, lambda: random.choice([('প্রতিদিন', 'daily'), ('রোজ', 'daily'), ('প্রতি শুক্রবার', 'weekly'), ('প্রতি সপ্তাহে', 'weekly'),
                                                     ('প্রতি মাসে', 'monthly'), ('প্রতি মাসের ১ তারিখে', 'monthly'), ('প্রতি বছর', 'yearly')]))
        return w, 'repeat', v
    if name == 'before':
        w, v = ctx.once(name, lambda: random.choice([('আগের দিন', '1d'), ('এক দিন আগে', '1d'), ('এক ঘণ্টা আগে', '60m'), ('৩০ মিনিট আগে', '30m'),
                                                     ('দুই দিন আগে', '2d'), ('আধা ঘণ্টা আগে', '30m'), ('১৫ মিনিট আগে', '15m')]))
        return w, 'before', v
    if name == 'phone':
        w = ctx.once(name, lambda: '০১' + random.choice('3456789') + ''.join(random.choice('0123456789') for _ in range(8)))
        w = L.bn(w) if random.random() < 0.7 else w.translate(str.maketrans('০১২৩৪৫৬৭৮৯', '0123456789'))
        return w, 'phone', w
    if name == 'bp':
        a, b = ctx.once(name, lambda: (random.randint(100, 160), random.randint(60, 100)))
        return f'{L.bn(a)}/{L.bn(b)}', 'amount', f'{a}/{b}'
    if name == 'sugar':
        a = ctx.once(name, lambda: round(random.uniform(4.5, 14), 1))
        return L.bn(a), 'amount', a
    if name == 'healthk':
        w, v = ctx.once(name, lambda: random.choice([('প্রেশার', 'bp'), ('সুগার', 'sugar'), ('ওজন', 'weight'), ('ডায়াবেটিস', 'sugar')]))
        return w, 'health_kind', v
    if name == 'weight':
        a = ctx.once(name, lambda: random.randint(45, 95))
        return f'{L.bn(a)} কেজি', 'amount', a
    if name == 'pct':
        a = ctx.once(name, lambda: random.choice([2, 5, 10, 12]))
        return f'{L.bn(a)}%', 'terms', a
    if name == 'account2':
        a = ctx.once('account', lambda: random.choice(L.ACCOUNTS))
        w = ctx.once(name, lambda: random.choice([x for x in L.ACCOUNTS if x != a]))
        return (L.loc(w) if var == 'loc' else L.gen(w) if var == 'gen' else w), 'target2', w
    if name == 'lineno':
        k = ctx.once(name, lambda: random.randint(1, 9))
        return random.choice([f'{L.bn(k)}.', f'{L.bn(k)})', f'{k}.']), None, None
    if name == 'num12':
        k = ctx.once(name, lambda: random.choice([2, 3, 4, 5, 6, 10, 12, 15, 20]))
        return L.bn(k), 'quantity', k
    if name == 'unitp':
        k = ctx.once(name, lambda: random.choice([15, 25, 40, 55, 85, 120, 150]))
        return L.bn(k), 'unit_price', k
    if name == 'sdate':
        def mk():
            m = random.randrange(12)
            d = random.randint(1, 28)
            y = random.choice([None, None, None, random.randint(1950, 2015)])
            w = f'{R.digits(d)} {random.choice(L.MONTH_SPELLINGS[L.MONTHS[m]])}' + (f' {L.bn(y)}' if y else '')
            return w, f'{y or "????"}-{m + 1:02d}-{d:02d}'
        w, v = ctx.once(name, mk)
        return w, 'date', v
    if name == 'dategen':
        w, v = ctx.once(name, R.dategen)
        return w, 'date', v
    if name == 'wdgen':
        d = ctx.once(name, lambda: random.choice(L.WEEKDAYS))
        return d + 'ের', 'date', f'wd:{d}'
    if name == 'pdategen':
        w, v = ctx.once(name, R.past_dategen)
        return w, 'date', v
    if name == 'dategen2':
        w = ctx.once(name, lambda: random.choice(['সকালের', 'দুপুরের', 'রাতের', 'বিকালের']))
        return w, 'daypart', w[:-2]
    if name == 'bdate':
        w, v = ctx.once(name, lambda: random.choice([('kal', 'rel:1'), ('kalke', 'rel:1'), ('aj', 'rel:0'), ('ajke', 'rel:0'), ('porshu', 'rel:2')]))
        return w, 'date', v
    if name == 'btime':
        def mk():
            part, hours, add = random.choice([('sokal', (7, 11), 0), ('sokale', (7, 11), 0), ('bikel', (3, 5), 12), ('rat', (8, 11), 12), ('rate', (8, 11), 12), ('dupur', (1, 2), 12)])
            h = random.randint(*hours)
            return f'{part} {h} tay', f'{(h + add) % 24:02d}:00'
        w, v = ctx.once(name, mk)
        return w, 'time', v
    if name == 'memfact':
        w = ctx.once(name, lambda: random.choice(L.MEM_FACTS))
        return w, 'text', w
    if name == 'fullname':
        p = ctx.once('person', L.person)
        first = p.split()[0]
        sur = ['আক্তার', 'বেগম', 'খাতুন', 'আহমেদ', 'আপা'] if first in L.FEMALE else ['উদ্দিন', 'মিয়া', 'হাসান', 'হোসেন', 'আহমেদ', 'ভাই']
        w = ctx.once(name, lambda: first + ' ' + random.choice(sur))
        return w, 'text', w
    if name == 'callme':
        w = ctx.once(name, lambda: random.choice(['সাইফ ভাই', 'স্যার', 'ভাইয়া', 'আপা', 'মামা', 'বস', 'রফিক ভাই', 'আপু']))
        return w, 'text', w
    if name in ('sugar2',):
        a = ctx.once(name, lambda: round(random.uniform(4.5, 14), 1))
        return L.bn(a), 'amount2', a
    if name == 'oos':
        w = ctx.once(name, lambda: random.choice(L.OUT_OF_SCOPE))
        return w, None, None
    # The persona walk's words (23 Oct). Who gave or was paid has no slot of
    # its own (it is the entry's note).
    if name in ('isrc', 'wage', 'earn'):
        w = ctx.once(name, lambda: random.choice({'isrc': L.INCOME_SOURCES, 'wage': L.WAGES, 'earn': L.EARN}[name]))
        return w, ('item' if name != 'earn' else None), w
    if name in ('giver', 'worker', 'family', 'tenant', 'parent', 'pocket'):
        w = ctx.once(name, lambda: random.choice({'giver': L.GIVERS, 'worker': L.WORKERS, 'family': L.FAMILY, 'tenant': L.TENANTS,
                                                   'parent': L.PARENTS, 'pocket': L.POCKET}[name]))
        if var == 'ke':
            w = w + 'কে'
        return w, None, None
    if name == 'kin':
        w = ctx.once(name, lambda: random.choice(L.KIN))
        return w, 'person', w
    if name == 'notetopic':
        w = ctx.once(name, lambda: random.choice(L.NOTE_TOPICS))
        return w, 'terms', w
    if name == 'notecat':
        w = ctx.once(name, lambda: random.choice(L.NOTE_CATS))
        return w, 'category', w
    if name == 'fdone':
        w = random.choice(['হয়ে যাওয়া', 'শেষ হওয়া', 'শেষ করা', 'সম্পন্ন'])
        return w, 'filter', 'done'
    if name == 'all':
        w = random.choice(['সব', 'সবগুলো', 'সব কয়টা'])
        return w, 'list_ref', 'all'
    raise KeyError(name)


def fill(template, ctx=None):
    """→ (tokens, tags, slots) where tags are BIO over whitespace tokens."""
    ctx = ctx or Ctx()
    t = template
    if '{item:buy}' in t:
        ctx.once('item', lambda: random.choice([i for i in L.ITEMS if i[0] not in L.NOT_BOUGHT]))
    while True:
        m = ALT.search(t)
        if not m:
            break
        t = t[:m.start()] + random.choice(m.group(1).split('|')) + t[m.end():]
    chars, labels, slots = [], [], {}
    pos = 0
    for m in PH.finditer(t):
        lit = t[pos:m.start()]
        chars += lit
        labels += [None] * len(lit)
        w, slot, v = value(ctx, m.group(1), m.group(2))
        pos = m.end()
        if w is None:
            continue
        chars += w
        labels += [slot] * len(w)
        if slot:
            slots[slot] = v
    lit = t[pos:]
    chars += lit
    labels += [None] * len(lit)
    text = ''.join(chars)
    tokens, tags = [], []
    prev = None
    i = 0
    while i < len(text):
        if text[i].isspace():
            i += 1
            continue
        j = i
        while j < len(text) and not text[j].isspace():
            j += 1
        tok_labels = [l for l in labels[i:j] if l]
        slot = tok_labels[0] if tok_labels else None
        tokens.append(text[i:j])
        if slot is None:
            tags.append('O')
        else:
            # A new value starts a new B even when the same slot follows.
            cont = prev == slot and labels[i - 1] == slot if i > 0 else False
            tags.append(('I-' if cont else 'B-') + slot)
        prev = slot
        i = j
    return tokens, tags, slots
