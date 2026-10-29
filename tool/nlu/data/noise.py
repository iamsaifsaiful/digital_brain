# Noise that real messages have, applied word by word so the labels stay
# lined up: regional verb forms, words the recogniser mishears, fillers,
# words run together, missing punctuation, digits typed in English.
#
# The recogniser list is written by hand from the misheard words seen in the
# owner's screenshots and common Bengali speech-to-text slips. The app keeps
# the recogniser's other guesses (Voice.lastAlternatives) only in memory; once
# real logs exist (step J) they replace this list.
import random

# Regional forms of standard words, by area. Only forms in everyday use; the
# owner's review of the sample marks any that sound wrong.
REGION = {
    'নোয়াখালী': {'যাব': 'যাইয়ুম', 'করব': 'কইরমু', 'দেব': 'দিমু', 'আজ': 'আইজ্জা', 'আজকে': 'আইজ্জা', 'কাল': 'কাইল', 'কালকে': 'কাইলকা', 'হয়েছে': 'অইছে',
                  'হয়ে': 'অই', 'দাও': 'দেন', 'রাখো': 'রাখেন', 'করো': 'করেন', 'কাজ': 'কাম', 'কাজটা': 'কামগা', 'নেই': 'নাই'},
    'চট্টগ্রাম': {'যাব': 'যাইয়ুম', 'করব': 'গইরগুম', 'দেব': 'দিয়ুম', 'আজ': 'আজিয়া', 'কাল': 'হালিয়া', 'কালকে': 'হালিয়া', 'কী': 'কি', 'দাও': 'দও',
                  'করো': 'গর', 'রাখো': 'রাখো', 'হয়েছে': 'অইয়ে', 'কাজ': 'কাম', 'নেই': 'নাই', 'না': 'ন'},
    'সিলেট': {'যাব': 'যাইমু', 'করব': 'করমু', 'দেব': 'দিমু', 'আজ': 'আইজ', 'কাল': 'কাইল', 'কী': 'কিতা', 'দাও': 'দেও', 'করো': 'করো', 'হয়েছে': 'অইছে',
              'কাজ': 'কাম', 'নেই': 'নাই', 'আছে': 'আছে'},
    'বরিশাল': {'যাব': 'যামু', 'করব': 'হরমু', 'দেব': 'দিমু', 'আজ': 'আইজ', 'কাল': 'কাইল', 'করো': 'হরো', 'হয়েছে': 'হইছে', 'কাজ': 'কাম', 'দাও': 'দেও',
               'কী': 'কী', 'নেই': 'নাই'},
    'রাজশাহী': {'যাব': 'যাবো', 'করব': 'করবো', 'দেব': 'দিবো', 'হয়েছে': 'হয়্যাছে', 'আজ': 'আজ', 'কাল': 'কাল', 'নেই': 'নাই', 'দাও': 'দাও'},
    'ময়মনসিংহ': {'যাব': 'যাইবাম', 'করব': 'করবাম', 'দেব': 'দিবাম', 'আজ': 'আইজ', 'কাল': 'কাইল', 'হয়েছে': 'অইছে', 'দাও': 'দেও', 'কাজ': 'কাম', 'নেই': 'নাই'},
}

STT = {
    'রিমাইন্ডার': ['রিমাইন্ড', 'রিমান্ডার', 'রিমাইনডার'], 'রিমাইন্ডারটা': ['রিমাইন্ডার টা'], 'মুছে': ['মুসে', 'মুছি'], 'সরাও': ['শরাও', 'সরাউ'],
    'কাজটা': ['কাজটি', 'কাজ টা'], 'দাও': ['দাউ'], 'দিও': ['দিয়ো', 'দিয়ো'], 'নম্বর': ['নাম্বার'], 'নাম্বার': ['নম্বর'],
    'ঘণ্টা': ['ঘন্টা'], 'সন্ধ্যা': ['সন্ধা', 'সন্ধ্যায়'], 'বৃহস্পতিবার': ['বিস্যুদবার', 'বেস্পতিবার'], 'হিসাব': ['হিসেব'], 'খরচ': ['খরছ'],
    'বিকাল': ['বিকেল'], 'বিকেল': ['বিকাল'], 'জানুয়ারি': ['জানুয়ারী'], 'ফেব্রুয়ারি': ['ফেব্রুয়ারী'], 'পাসওয়ার্ড': ['পাসওয়ার্ড', 'পাসওয়ার্ডটা'],
    'অ্যালার্ম': ['এলার্ম', 'আলার্ম'], 'ডিলিট': ['ডিলেট'], 'ব্যাংকে': ['ব্যাংক এ', 'বেংকে'], 'রিকশা': ['রিক্সা'], 'বিকাশে': ['বিকাশ এ'],
    'করিয়ে': ['করে'], 'লিস্ট': ['লিস্টে', 'লিষ্ট'], 'দেখাও': ['দেখাও তো'],
    'পরশু': ['পরশুদিন'], 'আগামীকাল': ['আগামী কাল'], 'সকাল': ['সকালে'], 'রাত': ['রাতে'], 'প্রতিদিন': ['প্রতি দিন'],
}
# Pairs heard as one word.
JOIN = [('করে', 'দাও'), ('মুছে', 'দাও'), ('বাদ', 'দাও'), ('লিখে', 'রাখো'), ('মনে', 'করিয়ে'), ('হয়ে', 'গেছে'), ('ফোন', 'দাও'), ('ধার', 'দিলাম'), ('খরচ', 'হলো'),
        ('কত', 'টাকা'), ('কী', 'কী'), ('দিয়ে', 'দাও'), ('সরিয়ে', 'দাও')]
FILLERS_PRE = ['আচ্ছা', 'মানে', 'উমম', 'ইয়ে', 'শোনো', 'আচ্ছা শোনো', 'এই', 'হ্যালো', 'আরে', 'আচ্ছা মানে', 'জি']
FILLERS_POST = ['প্লিজ', 'তো', 'ভাই', 'একটু']
# Round 8 (gate of 28 Oct): a polite, forgetful or chatty run-up or tail is
# not a request of its own — "দয়া করে", "ভুলে গেছিলাম," or "… বুঝছো" must not
# add a complaint, small talk or a yes to what was asked. Idle rows only (in a
# yes/no state "হ্যাঁ…" means something).
RUNUPS = ['দয়া করে', 'প্লিজ', 'একটু', 'ও হ্যাঁ,', 'ভুলে গেছিলাম,', 'ভুলেই গেছিলাম,', 'ভাই একটা কথা,', 'আরেকটা কথা,', 'আচ্ছা শোনো,', 'শোনো ভাই,',
          'আচ্ছা ভাই,', 'এই যে,', 'একটা কাজ করো,', 'মনে পড়ল,', 'বলতে ভুলে গেছি,', 'আপা শোনেন,', 'স্যার,']
TAILS = ['বুঝছো', 'বুঝলে', 'ঠিক আছে', 'কেমন', 'ভুলে যেও না কিন্তু', 'ঠিকমতো রাখবে', 'মনে করে', 'বাবা', 'মা', 'ভাই', 'bro', 'প্লিজ', 'ঠিক করে লিখবা',
         'ভুল করবা না', 'জলদি', 'একটু তাড়াতাড়ি']
IMPERATIVE = ('দাও', 'করো', 'বলো', 'দেখাও', 'রাখো', 'দিও', 'দিয়ো', 'লেখো', 'খোলো', 'সরাও', 'নাও', 'মুছো', 'থামাও')
PUNCT = '?,।!:;—'
ASCII = str.maketrans('০১২৩৪৫৬৭৮৯', '0123456789')
BN = str.maketrans('0123456789', '০১২৩৪৫৬৭৮৯')


def apply(tokens, tags, rate=0.35, idle=False):
    """Returns (tokens, tags, kinds) — kinds lists the noise used."""
    toks, tg = list(tokens), list(tags)
    kinds = []
    if random.random() < rate * 0.35:
        region = random.choice(list(REGION))
        m = REGION[region]
        changed = False
        for i, t in enumerate(toks):
            if t in m and m[t] != t:
                toks[i] = m[t]
                changed = True
        if changed:
            kinds.append(f'region:{region}')
    if random.random() < rate * 0.6:
        cand = [i for i, t in enumerate(toks) if t.strip(PUNCT) in STT]
        if cand:
            i = random.choice(cand)
            core = toks[i].strip(PUNCT)
            new = random.choice(STT[core]).split()
            toks[i:i + 1] = new
            tg[i:i + 1] = [tg[i]] + [('I-' + tg[i][2:]) if tg[i] != 'O' else 'O' for _ in new[1:]]
            kinds.append('stt')
    if random.random() < rate * 0.6:
        for i in range(len(toks) - 1):
            if (toks[i], toks[i + 1].strip(PUNCT)) in JOIN and (tg[i] == 'O' and tg[i + 1] == 'O' or tg[i + 1].startswith('I-')):
                toks[i:i + 2] = [toks[i] + toks[i + 1]]
                tg[i:i + 2] = [tg[i]]
                kinds.append('join')
                break
    if random.random() < rate * 0.2:
        toks = [t.translate(ASCII) for t in toks]
        kinds.append('ascii_digits')
    elif random.random() < 0.1:
        toks = [t.translate(BN) for t in toks]
    if random.random() < rate * 0.3:
        f = random.choice(FILLERS_PRE).split()
        toks = f + toks
        tg = ['O'] * len(f) + tg
        kinds.append('filler')
    elif idle and random.random() < rate * 0.3:
        f = random.choice(RUNUPS).split()
        toks = f + toks
        tg = ['O'] * len(f) + tg
        kinds.append('filler')
    if idle and random.random() < rate * 0.22:
        f = random.choice(TAILS).split()
        toks = toks + f
        tg = tg + ['O'] * len(f)
        kinds.append('filler_end')
    elif random.random() < rate * 0.25 and toks and toks[-1].strip(PUNCT).endswith(IMPERATIVE):
        f = random.choice(FILLERS_POST).split()
        toks = toks + f
        tg = tg + ['O'] * len(f)
        kinds.append('filler_end')
    if random.random() < 0.5:
        # Speech has no punctuation; typing often drops it.
        out_t, out_g = [], []
        for t, g in zip(toks, tg):
            s = t.strip(PUNCT)
            if s:
                out_t.append(s)
                out_g.append(g)
        if out_t != toks:
            kinds.append('no_punct')
        toks, tg = out_t, out_g
    # A B- tag may now follow nothing of its kind and an I- may start a value.
    for i, g in enumerate(tg):
        if g.startswith('I-') and (i == 0 or tg[i - 1] == 'O' or tg[i - 1][2:] != g[2:]):
            tg[i] = 'B-' + g[2:]
    return toks, tg, kinds
