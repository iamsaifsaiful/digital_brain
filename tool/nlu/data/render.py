# Slot values as people say them: each returns (words, value). The value is
# what the app's own rules (values.dart) must get back from the words.
import random
from lexicon import bn, NUM_WORDS, ORDINALS, MONTHS, MONTH_SPELLINGS, WEEKDAYS, day_suffix, loc


def _gen(w):
    from lexicon import gen
    return gen(w)


def digits(n):
    """Bengali digits mostly; sometimes ASCII (typed), sometimes words."""
    r = random.random()
    if r < 0.75:
        return bn(n)
    if r < 0.9 or n not in NUM_WORDS:
        return str(n)
    return NUM_WORDS[n]


def date():
    r = random.random()
    if r < 0.45:
        w, v = random.choice([('আজ', 'rel:0'), ('আজকে', 'rel:0'), ('কাল', 'rel:1'), ('কালকে', 'rel:1'), ('আগামীকাল', 'rel:1'), ('পরশু', 'rel:2'),
                              ('আগামী সপ্তাহে', 'week:+1'), ('সামনের সপ্তাহে', 'week:+1'), ('এই সপ্তাহে', 'week:0'), ('মাসের শেষে', 'month_end'),
                              ('আগামী মাসে', 'month:+1'), ('তিন দিন পরে', 'rel:3'), ('দুই দিন পর', 'rel:2'), ('এক সপ্তাহ পরে', 'rel:7')])
        return w, v
    if r < 0.65:
        d = random.choice(WEEKDAYS)
        pre = random.choice(['', '', 'আগামী ', 'এই ', 'সামনের '])
        suf = random.choice(['', '', 'ে'])
        return f'{pre}{d}{suf}', f'wd:{d}'
    m = random.randrange(12)
    day = random.randint(1, 28)
    mon = random.choice(MONTH_SPELLINGS[MONTHS[m]])
    year = random.choice([None, None, None, 2026, 2027, 2028, 2029, 2030])
    dd = digits(day)
    form = random.random()
    if form < 0.4:
        w = f'{dd} {mon}'
    elif form < 0.6:
        w = f'{bn(day)}{day_suffix(day)} {mon}'
    elif form < 0.8:
        w = f'{"মে মাসের" if mon == "মে" else random.choice([_gen(mon), mon + " মাসের"])} {dd} তারিখে'
    else:
        w = f'{dd} তারিখে'
        year = None
        return w, f'dom:{day}'
    if 'তারিখে' in w:
        year = None
    if year:
        w = f'{w} {bn(year) if random.random() < 0.8 else str(year)}'
    if random.random() < 0.4 and 'তারিখে' not in w:
        last = w[-1]
        if last in BN_DIGITS_SET or last.isdigit():
            w += random.choice(['-এ', ' সালে'])
        else:
            w = loc(w) if random.random() < 0.7 else w + '-এ'
    return w, f'{year or "????"}-{m + 1:02d}-{day:02d}'


def time():
    part = random.choice(['ভোর', 'সকাল', 'সকাল', 'দুপুর', 'বিকাল', 'বিকেল', 'সন্ধ্যা', 'রাত', 'রাত', ''])
    ranges = {'ভোর': [4, 5, 6], 'সকাল': [6, 7, 8, 9, 10, 11], 'দুপুর': [12, 1, 2], 'বিকাল': [3, 4, 5], 'বিকেল': [3, 4, 5], 'সন্ধ্যা': [6, 7],
              'রাত': [8, 9, 10, 11, 12], '': list(range(1, 13))}
    h = random.choice(ranges[part])
    minute = random.choice([0, 0, 0, 0, 30, 15, 45])
    if minute == 30 and random.random() < 0.6:
        core = f'সাড়ে {digits(h)}টায়'
    elif minute == 15 and random.random() < 0.6:
        core = f'সোয়া {digits(h)}টায়'
    elif minute == 45 and random.random() < 0.5:
        core = f'পৌনে {digits(h + 1 if h < 12 else 1)}টায়'
        h, minute = (h + 1 if h < 12 else 1), -15
    elif minute:
        core = random.choice([f'{digits(h)}টা {digits(minute)} মিনিটে', f'{bn(h)}.{bn(minute)}-এ', f'{bn(h)}:{bn(minute)}-এ'])
    else:
        core = random.choice([f'{digits(h)}টায়', f'{digits(h)} টায়', f'{digits(h)}টার সময়', f'{digits(h)}টা'])
    w = f'{part} {core}'.strip() if part else core
    h24 = h
    if part == 'দুপুর' and h < 12:
        h24 = h + 12
    if part in ('বিকাল', 'বিকেল', 'সন্ধ্যা') or (part == 'রাত' and h < 12 and h >= 6):
        h24 = h + 12
    if part == 'রাত' and h == 12:
        h24 = 0
    mm = 45 if minute == -15 else minute
    hh = (h24 - 1) % 24 if minute == -15 else h24
    value = f'{hh:02d}:{mm:02d}' if part else f'?{h:02d}:{mm:02d}'
    return w, value


# 1–99 as one word each (the app reads the same list, menus.dart).
NUM_1_99 = {1: 'এক', 2: 'দুই', 3: 'তিন', 4: 'চার', 5: 'পাঁচ', 6: 'ছয়', 7: 'সাত', 8: 'আট', 9: 'নয়', 10: 'দশ', 11: 'এগারো', 12: 'বারো', 13: 'তেরো', 14: 'চৌদ্দ', 15: 'পনেরো', 16: 'ষোলো', 17: 'সতেরো', 18: 'আঠারো', 19: 'উনিশ', 20: 'বিশ', 21: 'একুশ', 22: 'বাইশ', 23: 'তেইশ', 24: 'চব্বিশ', 25: 'পঁচিশ', 26: 'ছাব্বিশ', 27: 'সাতাশ', 28: 'আঠাশ', 29: 'ঊনত্রিশ', 30: 'ত্রিশ', 31: 'একত্রিশ', 32: 'বত্রিশ', 33: 'তেত্রিশ', 34: 'চৌত্রিশ', 35: 'পঁয়ত্রিশ', 36: 'ছত্রিশ', 37: 'সাঁইত্রিশ', 38: 'আটত্রিশ', 39: 'ঊনচল্লিশ', 40: 'চল্লিশ', 41: 'একচল্লিশ', 42: 'বিয়াল্লিশ', 43: 'তেতাল্লিশ', 44: 'চুয়াল্লিশ', 45: 'পঁয়তাল্লিশ', 46: 'ছেচল্লিশ', 47: 'সাতচল্লিশ', 48: 'আটচল্লিশ', 49: 'ঊনপঞ্চাশ', 50: 'পঞ্চাশ', 51: 'একান্ন', 52: 'বাহান্ন', 53: 'তিপ্পান্ন', 54: 'চুয়ান্ন', 55: 'পঞ্চান্ন', 56: 'ছাপ্পান্ন', 57: 'সাতান্ন', 58: 'আটান্ন', 59: 'ঊনষাট', 60: 'ষাট', 61: 'একষট্টি', 62: 'বাষট্টি', 63: 'তেষট্টি', 64: 'চৌষট্টি', 65: 'পঁয়ষট্টি', 66: 'ছেষট্টি', 67: 'সাতষট্টি', 68: 'আটষট্টি', 69: 'ঊনসত্তর', 70: 'সত্তর', 71: 'একাত্তর', 72: 'বাহাত্তর', 73: 'তিয়াত্তর', 74: 'চুয়াত্তর', 75: 'পঁচাত্তর', 76: 'ছিয়াত্তর', 77: 'সাতাত্তর', 78: 'আটাত্তর', 79: 'ঊনআশি', 80: 'আশি', 81: 'একাশি', 82: 'বিরাশি', 83: 'তিরাশি', 84: 'চুরাশি', 85: 'পঁচাশি', 86: 'ছিয়াশি', 87: 'সাতাশি', 88: 'আটাশি', 89: 'ঊননব্বই', 90: 'নব্বই', 91: 'একানব্বই', 92: 'বিরানব্বই', 93: 'তিরানব্বই', 94: 'চুরানব্বই', 95: 'পঁচানব্বই', 96: 'ছিয়ানব্বই', 97: 'সাতানব্বই', 98: 'আটানব্বই', 99: 'নিরানব্বই'}


def spoken(n):
    """A whole number said in words: ২৮০০০ → "আঠাশ হাজার", ২১০০ → "দুই হাজার একশো",
    ৪০০ → "চারশো", ১১০০ → "এগারোশো" (people say hundreds past a thousand too)."""
    parts = []
    if n >= 100000:
        parts.append(f'{NUM_1_99[n // 100000]} লাখ')
        n %= 100000
    if 1100 <= n < 2000 and n % 100 == 0 and random.random() < 0.5:
        return ' '.join(parts + [NUM_1_99[n // 100] + 'শো'])
    if n >= 1000:
        parts.append(f'{NUM_1_99[n // 1000]} হাজার')
        n %= 1000
    if n >= 100:
        h = NUM_1_99[n // 100]
        parts.append('একশো' if n // 100 == 1 else h + random.choice(['শো', 'শো', 'শ']))
        n %= 100
    if n:
        parts.append(NUM_1_99[n])
    return ' '.join(parts)


def amount_words(n, tail=True):
    """A number of taka as people write or say it."""
    s = random.random()
    # Said aloud in words (the persona walk, 23 Oct: "আঠাশ হাজার", "নয়শো").
    if n < 10000000 and random.random() < 0.18:
        w = spoken(n)
        return w + random.choice([' টাকা', ' টাকা', '']) if tail else w
    if 1000 <= n < 100000 and n % 1000 == 0 and s < 0.3:
        w = f'{digits(n // 1000)} হাজার'
    elif n == 1500 and s < 0.5:
        w = 'দেড় হাজার'
    elif n == 2500 and s < 0.5:
        w = 'আড়াই হাজার'
    elif n == 250 and s < 0.5:
        w = random.choice(['আড়াইশো', 'আড়াইশ'])
    elif n == 500 and s < 0.3:
        w = random.choice(['পাঁচশো', 'পাঁচশ', 'পাচশো'])
    elif n == 3500 and s < 0.5:
        w = 'সাড়ে তিন হাজার'
    elif n >= 1000 and n % 500 == 0 and n % 1000 and s < 0.4:
        w = f'সাড়ে {digits(n // 1000)} হাজার' if random.random() < 0.5 else bn(n)
    elif n >= 100000 and n % 100000 == 0 and s < 0.7:
        w = f'{digits(n // 100000)} লাখ'
    elif n >= 1000 and s < 0.45:
        w = f'{bn(n // 1000)},{bn(n % 1000).rjust(3, "০")}' if random.random() < 0.3 else bn(n)
    elif 1000 <= n < 100000 and s < 0.55 and n % 1000 == 0:
        w = f'{n // 1000}k'
    else:
        w = bn(n) if random.random() < 0.85 else str(n)
    if not tail:
        return w
    t = random.choice([' টাকা', ' টাকা', ' টাকা', '', '', '/=', ' tk'])
    if t == '/=' and not (w[-1] in BN_DIGITS_SET or w[-1].isdigit()):
        t = ' টাকা'
    return w + t


def amount(tail=True, kind=None):
    if kind == 'big':
        n = random.choice([5000, 8000, 10000, 12000, 15000, 20000, 25000, 30000, 35000, 40000, 50000, 60000, 80000, 100000, 150000, 200000, 500000])
        return amount_words(n, tail), n
    if kind == 'fee':
        n = random.choice([5, 10, 15, 20, 25, 30, 50, 100, 115, 230])
        return amount_words(n, tail), n
    n = random.choice([50, 80, 100, 120, 150, 200, 250, 300, 350, 400, 450, 500, 600, 700, 750, 800, 900] if random.random() < 0.5 else
                      [1000, 1200, 1500, 2000, 2500, 3000, 3500, 4000, 5000, 7000, 8000, 10000, 12000, 15000, 20000, 25000, 30000, 50000, 100000, 200000])
    return amount_words(n, tail), n


def price(lo, hi, qty=1):
    """A believable price: rounded to 5/10/50 like a shop bill."""
    n = random.uniform(lo, hi) * qty
    step = 5 if n < 200 else 10 if n < 1000 else 50 if n < 5000 else 500
    n = max(step, int(round(n / step) * step))
    return n


def past_date():
    """A day already gone ("কাল" with a past verb is yesterday)."""
    r = random.random()
    if r < 0.6:
        return random.choice([('আজ', 'rel:0'), ('আজকে', 'rel:0'), ('গতকাল', 'rel:-1'), ('কাল', 'rel:-1'), ('কালকে', 'rel:-1'), ('গত পরশু', 'rel:-2'),
                              ('পরশু', 'rel:-2'), ('গত সপ্তাহে', 'week:-1'), ('গত মাসে', 'month:-1'), ('আজ সকালে', 'rel:0'), ('সকালে', 'rel:0')])
    if r < 0.8:
        d = random.choice(WEEKDAYS)
        return random.choice([f'গত {d}', d, f'{d}ে']), f'wd:-{d}'
    day = random.randint(1, 28)
    if random.random() < 0.5:
        return f'{digits(day)} তারিখে', f'dom:{day}'
    m = random.randrange(12)
    return f'{bn(day)} {random.choice(MONTH_SPELLINGS[MONTHS[m]])}', f'????-{m + 1:02d}-{day:02d}'


def day_month():
    m = random.randrange(12)
    day = random.randint(1, 28)
    mon = random.choice(MONTH_SPELLINGS[MONTHS[m]])
    w = random.choice([f'{digits(day)} {mon}', f'{bn(day)}{day_suffix(day)} {mon}', f'{digits(day)} {mon}'])
    return w, f'????-{m + 1:02d}-{day:02d}'


BN_DIGITS_SET = set('০১২৩৪৫৬৭৮৯')


def list_ref():
    r = random.random()
    k = random.randint(1, 9)
    if r < 0.2:
        return random.choice([f'{bn(k)}নং', f'{bn(k)} নং', f'{bn(k)} নম্বর', f'{bn(k)} নাম্বার']), f'idx:{k}'
    if r < 0.32:
        return f'{NUM_WORDS[k]} নম্বর', f'idx:{k}'
    if r < 0.45:
        return f'{ORDINALS[k]}', f'idx:{k}'
    if r < 0.55:
        return random.choice(['শেষেরটা', 'শেষেরটার', 'সর্বশেষটা', 'শেষ কাজটা']), 'idx:-1'
    if r < 0.62:
        return random.choice(['প্রথমটা', 'প্রথমটার']), 'idx:1'
    if r < 0.72:
        a = random.randint(1, 4)
        b = a + random.randint(1, 4)
        return random.choice([f'{bn(a)} থেকে {bn(b)}', f'{NUM_WORDS[a]} থেকে {NUM_WORDS[b]} নম্বর', f'{bn(a)}নং থেকে {bn(b)}নং']), f'range:{a}-{b}'
    if r < 0.82:
        n = random.randint(2, 4)
        w = {2: random.choice(['দুটো', 'দুইটা', 'দুটি']), 3: random.choice(['তিনটা', 'তিনটি']), 4: random.choice(['চারটা', 'চারটি'])}[n]
        side = random.choice([('প্রথম', 'first'), ('শেষের', 'last')])
        return f'{side[0]} {w}', f'{side[1]}:{n}'
    if r < 0.9:
        return random.choice([f'{bn(k)} ছাড়া সব', f'{bn(k)}নং বাদে বাকি সব', f'{ORDINALS[k]}টা ছাড়া']), f'except:{k}'
    return random.choice(['এগুলো', 'এই দুটো', 'এগুলো সব', 'সবগুলো', 'ওটা', 'এটা']), 'all'


def year_filter():
    y = random.randint(2026, 2032)
    return random.choice([f'{bn(y)} সালের', f'{bn(y)} এর', f'{bn(y)}-এর', f'{y} সালের']), y


def month_filter():
    m = random.randrange(12)
    mon = random.choice(MONTH_SPELLINGS[MONTHS[m]])
    if mon == 'মে':
        return 'মে মাসের', 5
    return random.choice([_gen(mon), f'{mon} মাসের', _gen(mon)]), m + 1


def dategen():
    """A day said as "of" (কালকের, শুক্রবারের, ১৫ জুনের)."""
    r = random.random()
    if r < 0.55:
        return random.choice([('আজকের', 'rel:0'), ('কালকের', 'rel:1'), ('আগামীকালের', 'rel:1'), ('পরশুর', 'rel:2'), ('এই সপ্তাহের', 'week:0'),
                              ('আগামী সপ্তাহের', 'week:+1'), ('সামনের সপ্তাহের', 'week:+1'), ('এ মাসের', 'month:0'), ('আগামী মাসের', 'month:+1')])
    if r < 0.75:
        d = random.choice(WEEKDAYS)
        return f'{random.choice(["", "এই ", "আগামী "])}{d}ের', f'wd:{d}'
    m = random.randrange(12)
    day = random.randint(1, 28)
    mon = random.choice(MONTH_SPELLINGS[MONTHS[m]])
    return f'{digits(day)} {"মে-র" if mon == "মে" else _gen(mon)}', f'????-{m + 1:02d}-{day:02d}'


def past_dategen():
    r = random.random()
    if r < 0.6:
        return random.choice([('আজকের', 'rel:0'), ('আজকের', 'rel:0'), ('গতকালের', 'rel:-1'), ('কালকের', 'rel:-1'), ('গত পরশুর', 'rel:-2'),
                              ('গত সপ্তাহের', 'week:-1'), ('এই সপ্তাহের', 'week:0')])
    if r < 0.8:
        d = random.choice(WEEKDAYS)
        return f'গত {d}ের', f'wd:-{d}'
    m = random.randrange(12)
    day = random.randint(1, 28)
    mon = random.choice(MONTH_SPELLINGS[MONTHS[m]])
    return f'{digits(day)} {"মে-র" if mon == "মে" else _gen(mon)}', f'????-{m + 1:02d}-{day:02d}'
