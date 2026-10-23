# 2000 made-up users (owner, 23 Oct 2026): each from a district, with a
# schooling, a trade, a temper, a way of speaking of other people and a place
# to live. Each says several things to the app; each sentence carries what a
# right answer must be (the kind of request, the amount, in or out, lent or
# borrowed…). The loop: the user says it → the app answers (rules, and the
# phone model) → the answer is checked against what was meant → the misses
# are fixed in shared layers, and the training half teaches the model.
#
# Two halves that share nothing but word lists: users 0–999 speak only the
# "a" frames (training data), users 1000–1999 only the "b" frames (gold, never
# trained on). So a test sentence is never a training sentence with other
# names — its sentence shape was never taught.
#
#   python3 tool/nlu/crowd/crowd.py   → tool/nlu/out/crowd/{users.jsonl, train.jsonl, test.jsonl}
#                                       and tool/nlu/gold/crowd.jsonl (the test half, as gold)
import json, os, random, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'data'))
import lexicon as L  # noqa: E402
import render as R  # noqa: E402
import noise  # noqa: E402

ROOT = os.path.join(HERE, '..')
OUT = os.path.join(ROOT, 'out', 'crowd')

# ── Who they are ──

# 64 districts → the regional speech the noise list has (others speak the
# standard forms, with their own small slips).
DISTRICTS = {
    'ঢাকা': None, 'গাজীপুর': None, 'নারায়ণগঞ্জ': None, 'নরসিংদী': None, 'মানিকগঞ্জ': None, 'মুন্সিগঞ্জ': None, 'টাঙ্গাইল': 'ময়মনসিংহ',
    'কিশোরগঞ্জ': 'ময়মনসিংহ', 'ফরিদপুর': None, 'গোপালগঞ্জ': None, 'মাদারীপুর': 'বরিশাল', 'শরীয়তপুর': 'বরিশাল', 'রাজবাড়ী': None,
    'ময়মনসিংহ': 'ময়মনসিংহ', 'জামালপুর': 'ময়মনসিংহ', 'শেরপুর': 'ময়মনসিংহ', 'নেত্রকোনা': 'ময়মনসিংহ',
    'চট্টগ্রাম': 'চট্টগ্রাম', 'কক্সবাজার': 'চট্টগ্রাম', 'বান্দরবান': 'চট্টগ্রাম', 'রাঙামাটি': 'চট্টগ্রাম', 'খাগড়াছড়ি': 'চট্টগ্রাম',
    'নোয়াখালী': 'নোয়াখালী', 'ফেনী': 'নোয়াখালী', 'লক্ষ্মীপুর': 'নোয়াখালী', 'কুমিল্লা': None, 'চাঁদপুর': 'নোয়াখালী', 'ব্রাহ্মণবাড়িয়া': None,
    'সিলেট': 'সিলেট', 'মৌলভীবাজার': 'সিলেট', 'হবিগঞ্জ': 'সিলেট', 'সুনামগঞ্জ': 'সিলেট',
    'বরিশাল': 'বরিশাল', 'পটুয়াখালী': 'বরিশাল', 'ভোলা': 'বরিশাল', 'পিরোজপুর': 'বরিশাল', 'ঝালকাঠি': 'বরিশাল', 'বরগুনা': 'বরিশাল',
    'খুলনা': None, 'যশোর': None, 'সাতক্ষীরা': None, 'বাগেরহাট': None, 'কুষ্টিয়া': None, 'ঝিনাইদহ': None, 'মাগুরা': None, 'নড়াইল': None,
    'চুয়াডাঙ্গা': None, 'মেহেরপুর': None,
    'রাজশাহী': 'রাজশাহী', 'নাটোর': 'রাজশাহী', 'নওগাঁ': 'রাজশাহী', 'চাঁপাইনবাবগঞ্জ': 'রাজশাহী', 'পাবনা': 'রাজশাহী', 'সিরাজগঞ্জ': 'রাজশাহী',
    'বগুড়া': 'রাজশাহী', 'জয়পুরহাট': 'রাজশাহী',
    'রংপুর': 'রাজশাহী', 'দিনাজপুর': 'রাজশাহী', 'কুড়িগ্রাম': 'রাজশাহী', 'গাইবান্ধা': 'রাজশাহী', 'নীলফামারী': 'রাজশাহী', 'লালমনিরহাট': 'রাজশাহী',
    'ঠাকুরগাঁও': 'রাজশাহী', 'পঞ্চগড়': 'রাজশাহী',
}
SCHOOLING = ['পড়াশোনা নেই', 'প্রাথমিক', 'মাধ্যমিক', 'উচ্চমাধ্যমিক', 'স্নাতক', 'স্নাতকোত্তর']
SCHOOLING_W = [8, 18, 26, 20, 20, 8]
TEMPER = ['ভদ্র', 'সংক্ষেপে বলে', 'বেশি কথা বলে', 'দুশ্চিন্তায় থাকে', 'সন্দেহপ্রবণ', 'রসিক', 'ভুলোমনা', 'তাড়াহুড়ায় থাকে']
REGARD = ['সম্মান দিয়ে বলে', 'নাম ধরে বলে', 'আদর করে বলে', 'তাচ্ছিল্য করে বলে']
REGARD_W = [45, 35, 12, 8]
HOME = ['শহর', 'মফস্বল', 'গ্রাম', 'বিদেশে থাকে']
HOME_W = [35, 25, 32, 8]
AGE = ['কিশোর', 'তরুণ', 'মধ্যবয়সী', 'বয়স্ক']
AGE_W = [10, 35, 38, 17]

# Trades: what they buy, earn, who they deal with, what they must do.
TRADES = {
    'কৃষক': dict(buy=['সার', 'বীজ', 'কীটনাশক', 'সেচের পানি', 'হাল চাষ'], earn=['ধান বিক্রি', 'পাট বিক্রি', 'সবজি বিক্রি'], work=['জমিতে সার দেওয়া', 'ধান কাটা', 'বীজতলা তৈরি'], who=['মহাজন', 'পাইকার', 'বর্গাচাষি'], home=['গ্রাম'], big=(500, 60000)),
    'দিনমজুর': dict(buy=['চাল', 'ডাল', 'চা নাস্তা', 'বিড়ি', 'ভাত'], earn=['মজুরি', 'দিনের হাজিরা', 'কামাই'], work=['ইটভাটায় যাওয়া', 'কাজের খোঁজে যাওয়া'], who=['সর্দার', 'মালিক', 'ঠিকাদার'], home=['গ্রাম', 'শহর'], big=(50, 1500)),
    'রিকশাচালক': dict(buy=['রিকশার জমা', 'চা', 'ভাত', 'টায়ার সারাই'], earn=['ভাড়া', 'কামাই', 'রোজগার'], work=['রিকশা জমা দেওয়া', 'গ্যারেজে যাওয়া'], who=['গ্যারেজ মালিক', 'মহাজন'], home=['শহর'], big=(50, 1500)),
    'গার্মেন্টস কর্মী': dict(buy=['বাসা ভাড়া', 'বাজার', 'গাড়ি ভাড়া', 'মোবাইল রিচার্জ'], earn=['বেতন', 'ওভারটাইম', 'হাজিরা বোনাস'], work=['নাইট শিফট', 'ফ্যাক্টরিতে যাওয়া'], who=['সুপারভাইজার', 'রুমমেট', 'লাইনম্যান'], home=['শহর'], big=(100, 15000)),
    'দোকানদার': dict(buy=['মাল কেনা', 'দোকান ভাড়া', 'কারেন্ট বিল', 'কর্মচারীর বেতন'], earn=['বিক্রি', 'নগদ বিক্রি'], work=['মাল আনা', 'পাইকারের কাছে যাওয়া', 'দোকান খোলা'], who=['খদ্দের', 'পাইকার', 'কর্মচারী'], home=['মফস্বল', 'শহর', 'গ্রাম'], big=(200, 80000)),
    'শিক্ষক': dict(buy=['বই', 'খাতা', 'গাড়ি ভাড়া', 'বাজার'], earn=['বেতন', 'প্রাইভেটের টাকা', 'কোচিংয়ের টাকা'], work=['খাতা দেখা', 'প্রশ্ন তৈরি', 'অভিভাবক সভা', 'ক্লাস নেওয়া'], who=['হেডস্যার', 'সহকর্মী', 'ছাত্রের অভিভাবক'], home=['মফস্বল', 'গ্রাম', 'শহর'], big=(100, 40000)),
    'ডাক্তার': dict(buy=['চেম্বার ভাড়া', 'সহকারীর বেতন', 'জার্নাল'], earn=['চেম্বারের আয়', 'রোগী দেখার ফি', 'বেতন'], work=['রাউন্ড দেওয়া', 'রোগীর ফলোআপ', 'সেমিনারে যাওয়া'], who=['সহকারী', 'নার্স', 'রোগী'], home=['শহর'], big=(500, 100000)),
    'নার্স': dict(buy=['গাড়ি ভাড়া', 'বাজার', 'ইউনিফর্ম'], earn=['বেতন', 'ডিউটি ভাতা'], work=['নাইট ডিউটি', 'মর্নিং শিফট', 'ওষুধ দেওয়া'], who=['সিস্টার', 'ওয়ার্ড বয়', 'রুমমেট'], home=['শহর'], big=(100, 30000)),
    'ছাত্র': dict(buy=['বই', 'টিউশন ফি', 'ক্যান্টিন', 'মোবাইল রিচার্জ', 'বাস ভাড়া'], earn=['টিউশনির টাকা', 'হাতখরচ', 'বৃত্তি'], work=['এসাইনমেন্ট জমা', 'পরীক্ষার পড়া', 'ল্যাব রিপোর্ট'], who=['বন্ধু', 'রুমমেট', 'বড় ভাই'], home=['শহর', 'মফস্বল'], big=(20, 8000)),
    'গৃহিণী': dict(buy=['বাজার', 'মাছ', 'গ্যাস বিল', 'বাচ্চার স্কুলের বেতন', 'কাজের বুয়ার বেতন'], earn=['সংসার খরচের টাকা', 'সেলাইয়ের টাকা'], work=['বাচ্চাকে স্কুলে দেওয়া', 'বাজার করা', 'গ্যাসের লাইন ঠিক করানো'], who=['কাজের বুয়া', 'পাশের বাসার ভাবি', 'দুধওয়ালা'], home=['শহর', 'মফস্বল', 'গ্রাম'], big=(50, 20000)),
    'অবসরপ্রাপ্ত': dict(buy=['ওষুধ', 'ডাক্তারের ফি', 'বাজার'], earn=['পেনশন', 'সঞ্চয়পত্রের মুনাফা', 'বাড়ি ভাড়া'], work=['ব্যাংকে যাওয়া', 'পেনশন তোলা', 'ডাক্তার দেখানো'], who=['ছেলে', 'বউমা', 'নাতি'], home=['শহর', 'মফস্বল'], big=(100, 60000)),
    'প্রবাসী': dict(buy=['বাসা ভাড়া', 'খাবার', 'ফোন বিল'], earn=['বেতন', 'ওভারটাইম'], work=['দেশে টাকা পাঠানো', 'ভিসা নবায়ন', 'আকামা নবায়ন'], who=['কফিল', 'রুমমেট', 'দালাল'], home=['বিদেশে থাকে'], big=(500, 200000)),
    'ড্রাইভার': dict(buy=['তেল', 'গ্যাস', 'গাড়ির সার্ভিসিং', 'টোল'], earn=['ভাড়া', 'বেতন', 'ট্রিপের টাকা'], work=['গাড়ির কাগজ নবায়ন', 'গাড়ি ধোয়া'], who=['মালিক', 'হেলপার', 'যাত্রী'], home=['শহর', 'মফস্বল'], big=(100, 30000)),
    'দর্জি': dict(buy=['সুতা', 'কাপড়', 'মেশিনের তেল', 'দোকান ভাড়া'], earn=['সেলাইয়ের মজুরি', 'অগ্রিম'], work=['ব্লাউজ ডেলিভারি', 'পাঞ্জাবি সেলাই', 'মাপ নেওয়া'], who=['খদ্দের', 'কারিগর'], home=['মফস্বল', 'শহর'], big=(100, 15000)),
    'ইমাম': dict(buy=['আতর', 'বই', 'বাজার'], earn=['সম্মানী', 'হাদিয়া'], work=['জুমার খুতবা লেখা', 'মক্তবে পড়ানো'], who=['মুতাওয়াল্লি', 'মুসল্লি', 'কমিটির সভাপতি'], home=['গ্রাম', 'মফস্বল'], big=(100, 20000)),
    'এনজিও কর্মী': dict(buy=['মোটরসাইকেলের তেল', 'খাতা কলম', 'বাজার'], earn=['বেতন', 'ভাতা'], work=['কিস্তি তোলা', 'সদস্যদের সভা', 'রিপোর্ট জমা'], who=['ম্যানেজার', 'সদস্য', 'সহকর্মী'], home=['গ্রাম', 'মফস্বল'], big=(100, 50000)),
    'ফ্রিল্যান্সার': dict(buy=['ইন্টারনেট বিল', 'ল্যাপটপ সারাই', 'বিদ্যুৎ বিল'], earn=['ফাইভারের পেমেন্ট', 'আপওয়ার্কের পেমেন্ট', 'ক্লায়েন্টের টাকা'], work=['ক্লায়েন্টের কাজ জমা', 'মিটিং', 'প্রপোজাল পাঠানো'], who=['ক্লায়েন্ট', 'টিমমেট'], home=['শহর', 'মফস্বল'], big=(500, 150000)),
    'ব্যাংকার': dict(buy=['গাড়ি ভাড়া', 'দুপুরের খাবার', 'বাসা ভাড়া'], earn=['বেতন', 'বোনাস'], work=['ব্রাঞ্চ মিটিং', 'অডিট', 'রিপোর্ট জমা'], who=['ম্যানেজার স্যার', 'কলিগ', 'ক্লায়েন্ট'], home=['শহর'], big=(200, 120000)),
    'সরকারি চাকুরে': dict(buy=['বাসা ভাড়া', 'বাজার', 'বিদ্যুৎ বিল'], earn=['বেতন', 'উৎসব ভাতা'], work=['ফাইল জমা', 'অফিসের মিটিং', 'ট্রেনিংয়ে যাওয়া'], who=['বড় স্যার', 'সহকর্মী', 'পিয়ন'], home=['শহর', 'মফস্বল'], big=(200, 80000)),
    'জেলে': dict(buy=['জাল সারাই', 'নৌকার তেল', 'বরফ'], earn=['মাছ বিক্রি'], work=['নদীতে যাওয়া', 'জাল বোনা'], who=['আড়তদার', 'মহাজন'], home=['গ্রাম'], big=(100, 30000)),
    'বাড়িওয়ালা': dict(buy=['পানির বিল', 'দারোয়ানের বেতন', 'রং করা'], earn=['ভাড়া', 'দোকান ভাড়া'], work=['ভাড়া তোলা', 'ট্যাংক পরিষ্কার'], who=['ভাড়াটিয়া', 'দারোয়ান', 'কেয়ারটেকার'], home=['শহর'], big=(500, 100000)),
    'ঠিকাদার': dict(buy=['সিমেন্ট', 'রড', 'বালু', 'ইট', 'মিস্ত্রির মজুরি'], earn=['বিলের টাকা', 'অগ্রিম'], work=['সাইটে যাওয়া', 'বিল জমা'], who=['মিস্ত্রি', 'মালিক', 'ইঞ্জিনিয়ার সাহেব'], home=['শহর', 'মফস্বল'], big=(1000, 500000)),
    'ডেলিভারি রাইডার': dict(buy=['বাইকের তেল', 'বাইক সার্ভিসিং', 'চা নাস্তা'], earn=['ডেলিভারির টাকা', 'টিপস', 'কামাই'], work=['বাইকের কাগজ নবায়ন', 'অর্ডার পৌঁছানো'], who=['হাব ম্যানেজার', 'রাইডার ভাই'], home=['শহর'], big=(50, 5000)),
    'বিউটিশিয়ান': dict(buy=['মেকআপের জিনিস', 'পার্লার ভাড়া'], earn=['পার্লারের আয়', 'বুকিংয়ের টাকা'], work=['বিয়ের সাজ', 'মালামাল কেনা'], who=['কাস্টমার', 'সহকারী'], home=['শহর', 'মফস্বল'], big=(200, 30000)),
    'মেকানিক': dict(buy=['যন্ত্রাংশ', 'মোবিল', 'দোকান ভাড়া'], earn=['সারাইয়ের মজুরি', 'কাজের টাকা'], work=['গাড়ি ডেলিভারি', 'পার্টস আনা'], who=['মালিক', 'কাস্টমার', 'শাগরেদ'], home=['শহর', 'মফস্বল'], big=(100, 20000)),
    'পোলট্রি খামারি': dict(buy=['মুরগির খাবার', 'ভ্যাকসিন', 'বাচ্চা মুরগি'], earn=['ডিম বিক্রি', 'মুরগি বিক্রি'], work=['ভ্যাকসিন দেওয়া', 'খামার পরিষ্কার'], who=['পাইকার', 'ডাক্তার সাহেব'], home=['গ্রাম'], big=(200, 80000)),
    'নিরাপত্তা প্রহরী': dict(buy=['মেস খরচ', 'চা', 'বাড়িতে পাঠানো'], earn=['বেতন', 'ডিউটির টাকা'], work=['নাইট ডিউটি', 'হাজিরা দেওয়া'], who=['সুপারভাইজার', 'রুমমেট'], home=['শহর'], big=(50, 15000)),
    'উদ্যোক্তা': dict(buy=['কুরিয়ার খরচ', 'বুস্টিং খরচ', 'প্যাকেজিং'], earn=['অনলাইনে বিক্রি', 'অর্ডারের টাকা'], work=['পার্সেল পাঠানো', 'লাইভে আসা'], who=['কাস্টমার', 'কুরিয়ারের লোক', 'সাপ্লায়ার'], home=['শহর', 'মফস্বল'], big=(100, 60000)),
}

HONOR = {'সম্মান দিয়ে বলে': ['সাহেব', 'ভাই', 'আপা', 'চাচা', 'স্যার', 'ভাইজান'], 'নাম ধরে বলে': [''], 'আদর করে বলে': ['ভাই', 'আপু', 'বাবু', 'মামা'],
         'তাচ্ছিল্য করে বলে': ['', 'বেটা', 'ব্যাটা']}
FEMALE_HON = {'আপা', 'আপু'}


class User:
    def __init__(self, i):
        r = random.Random(1000003 * (i + 7))
        self.i = i
        self.r = r
        self.district = r.choice(list(DISTRICTS))
        self.dialect = DISTRICTS[self.district]
        self.school = r.choices(SCHOOLING, SCHOOLING_W)[0]
        self.trade = r.choice(list(TRADES))
        t = TRADES[self.trade]
        self.home = r.choice(t['home']) if r.random() < 0.8 else r.choices(HOME, HOME_W)[0]
        self.temper = r.choice(TEMPER)
        self.regard = r.choices(REGARD, REGARD_W)[0]
        self.age = 'কিশোর' if self.trade == 'ছাত্র' and r.random() < 0.5 else (
            'বয়স্ক' if self.trade == 'অবসরপ্রাপ্ত' else r.choices(AGE, AGE_W)[0])
        self.mic = r.random() < 0.7  # speaks to the phone (no punctuation, digits as heard)

    def card(self):
        return dict(id=self.i, district=self.district, dialect=self.dialect or 'প্রমিত', school=self.school, trade=self.trade, home=self.home,
                    temper=self.temper, regard=self.regard, age=self.age, mic=self.mic)

    # How this user names a person.
    def person(self):
        r = self.r
        if r.random() < 0.3:
            return r.choice(TRADES[self.trade]['who'])
        female = r.random() < 0.35
        name = r.choice(L.FEMALE if female else L.MALE)
        hon = r.choice(HONOR[self.regard])
        if female and hon in ('সাহেব', 'ভাই', 'চাচা', 'স্যার', 'ভাইজান', 'বেটা', 'ব্যাটা', 'মামা'):
            hon = r.choice(['আপা', 'খালা', 'ভাবি', ''])
        if not female and hon in FEMALE_HON:
            hon = 'ভাই'
        return f'{name} {hon}'.strip()

    def amount(self, lo=None, hi=None):
        r = self.r
        lo, hi = lo or TRADES[self.trade]['big'][0], hi or TRADES[self.trade]['big'][1]
        n = r.randint(lo, hi)
        step = 500 if n > 20000 else (100 if n > 2000 else (50 if n > 300 else 10))
        n = max(step, n // step * step)
        # Schooling and the mic decide how it is said.
        s = r.random()
        if self.mic and s < 0.35 or self.school in ('পড়াশোনা নেই', 'প্রাথমিক') and s < 0.5:
            w = R.spoken(n)
        elif self.school in ('স্নাতক', 'স্নাতকোত্তর') and s < 0.2:
            w = str(n)
        else:
            w = L.bn(n)
        return n, w


def taka(u, w):
    return w + (' টাকা' if u.r.random() < 0.75 else '')


# ── What they say: frames by intent. "a" frames teach, "b" frames test. ──
# Each frame is a function (user) → (sentence, expected) or None.

def _p(u):
    return u.person()


def F(intent, half, fn):
    FRAMES.append((intent, half, fn))


FRAMES = []
D_TODAY = ['আজ', 'আজকে', '']
D_PAST = ['আজ', 'আজকে', 'গতকাল', 'কাল', '']
D_FUT = ['কাল', 'আগামীকাল', 'পরশু', 'শুক্রবার', 'রবিবার', 'সোমবার', 'মঙ্গলবার', 'বুধবার', 'বৃহস্পতিবার', 'শনিবার', '১৫ তারিখে', 'সামনের সপ্তাহে']
TIMES = [('সকাল আটটায়', 8), ('সকাল ৯টায়', 9), ('সকাল দশটায়', 10), ('দুপুর ২টায়', 14), ('বিকেল চারটায়', 16), ('বিকাল ৫টায়', 17), ('সন্ধ্যা সাতটায়', 19), ('রাত নয়টায়', 21), ('রাত ১০টায়', 22)]


def ch(u, xs):
    return u.r.choice(xs)


def j(*ws):
    return ' '.join(w for w in ws if w).strip()


# own spending
F('cash_add', 'a', lambda u: (lambda n, w, it: (j(ch(u, D_PAST), it, taka(u, w), ch(u, ['খরচ হলো', 'খরচ', 'গেল', 'লাগলো'])), dict(cash_kind='expense', amount=n)))(*u.amount(), ch(u, TRADES[u.trade]['buy'])))
F('cash_add', 'b', lambda u: (lambda n, w, it: (j(ch(u, D_PAST), it, ch(u, ['বাবদ', 'এর জন্য', '']), taka(u, w), ch(u, ['দিলাম', 'খরচ করলাম', 'দিয়ে দিলাম'])), dict(cash_kind='expense', amount=n)))(*u.amount(), ch(u, TRADES[u.trade]['buy'])))
F('cash_add', 'a', lambda u: (lambda n, w, it: (j(it, ch(u, ['কিনলাম', 'আনলাম', 'কিনেছি']), taka(u, w)), dict(cash_kind='expense', amount=n)))(*u.amount(), ch(u, TRADES[u.trade]['buy'])))
F('cash_add', 'b', lambda u: (lambda n, w, it: (j(taka(u, w), ch(u, ['দিয়ে', 'খরচ করে']), it, ch(u, ['কিনলাম', 'করালাম', 'আনলাম'])), dict(cash_kind='expense', amount=n)))(*u.amount(), ch(u, TRADES[u.trade]['buy'])))
# own income
F('cash_add', 'a', lambda u: (lambda n, w, it: (j(ch(u, D_PAST), it, ch(u, ['পেলাম', 'পাইছি', 'এলো', 'হলো']), taka(u, w)), dict(cash_kind='income', amount=n)))(*u.amount(), ch(u, TRADES[u.trade]['earn'])))
F('cash_add', 'b', lambda u: (lambda n, w, it: (j(ch(u, D_PAST), ch(u, ['আমার ', '']) + it, ch(u, ['বাবদ', 'হিসেবে', '']), taka(u, w), ch(u, ['হাতে পেলাম', 'পেয়েছি', 'আসছে', 'জমা হলো'])), dict(cash_kind='income', amount=n)))(*u.amount(), ch(u, TRADES[u.trade]['earn'])))
# lent / borrowed / paid back
F('ledger_add', 'a', lambda u: (lambda n, w, p: (j(ch(u, D_PAST), p + 'কে', taka(u, w), ch(u, ['ধার দিলাম', 'ধার দিছি', 'হাওলাত দিলাম'])), dict(ledger_kind='lent', amount=n)))(*u.amount(), _p(u)))
F('ledger_add', 'b', lambda u: (lambda n, w, p: (j(p, ch(u, ['আমার থেকে', 'আমার কাছ থেকে']), taka(u, w), ch(u, ['ধার নিল', 'ধার নিয়ে গেল', 'হাওলাত নিল'])), dict(ledger_kind='lent', amount=n)))(*u.amount(), _p(u)))
F('ledger_add', 'a', lambda u: (lambda n, w, p: (j(L.gen(p), 'কাছ থেকে', taka(u, w), ch(u, ['ধার নিলাম', 'ধার নিছি', 'কর্জ নিলাম'])), dict(ledger_kind='borrowed', amount=n)))(*u.amount(), _p(u)))
F('ledger_add', 'b', lambda u: (lambda n, w, p: (j(p, ch(u, ['আমাকে', '']), taka(u, w), ch(u, ['ধার দিল', 'ধার দিলেন', 'কর্জ দিছে'])), dict(ledger_kind='borrowed', amount=n)))(*u.amount(), _p(u)))
F('ledger_add', 'a', lambda u: (lambda n, w, p: (j(p, ch(u, ['আগের ধারের', 'পাওনা', '']), taka(u, w), ch(u, ['ফেরত দিল', 'ফেরত দিয়েছে', 'শোধ করল'])), dict(ledger_kind='received', amount=n)))(*u.amount(), _p(u)))
F('ledger_add', 'b', lambda u: (lambda n, w, p: (j(p + 'কে', ch(u, ['ধারের', 'আগের', '']), taka(u, w), ch(u, ['ফেরত দিলাম', 'শোধ করে দিলাম', 'ফিরিয়ে দিলাম'])), dict(ledger_kind='repaid', amount=n)))(*u.amount(), _p(u)))
# questions about money
F('cash_query', 'a', lambda u: (j(ch(u, ['এই মাসে', 'এ মাসে', 'গত মাসে', 'আজ']), ch(u, ['কত খরচ হলো', 'খরচ কত হলো', 'মোট কত গেল'])), {}))
F('cash_query', 'b', lambda u: (j(ch(u, ['আমার', '']), ch(u, ['এ মাসের', 'এই মাসের', 'গত মাসের']), ch(u, ['আয় ব্যয়ের হিসাব', 'খরচের হিসাব', 'আয়-খরচ']), ch(u, ['দাও', 'বলো', 'শোনাও', 'দেখাও'])), {}))
F('ledger_query', 'a', lambda u: (lambda p: (j(L.gen(p), 'কাছে', ch(u, ['কত পাব', 'কত পাওনা', 'আর কত বাকি'])), {}))(_p(u)))
F('ledger_query', 'b', lambda u: (lambda p: (j(p, ch(u, ['আমার কাছে কত পায়', 'কত টাকা পাবে', 'কত পায় আমার কাছে'])), {}))(_p(u)))
# to-dos and reminders
F('task_add', 'a', lambda u: (j(ch(u, D_FUT), ch(u, TRADES[u.trade]['work']), ch(u, ['করতে হবে', 'আছে', 'কাজ আছে', 'লিখে রাখো'])), {}))
F('task_add', 'b', lambda u: (j(ch(u, TRADES[u.trade]['work']), ch(u, D_FUT), ch(u, ['তালিকায় রাখো', 'কাজে রাখো', 'মনে রাখতে হবে', 'যেতে হবে'])), {}))
F('reminder_add', 'a', lambda u: (lambda t: (j(ch(u, D_FUT[:3]), t[0], ch(u, TRADES[u.trade]['work']), ch(u, ['মনে করিয়ে দিও', 'রিমাইন্ডার দাও', 'মনে করাবে'])), dict(hour=t[1])))(ch(u, TIMES)))
F('reminder_add', 'b', lambda u: (lambda t: (j(ch(u, [L.gen(w) + ' কথা' for w in TRADES[u.trade]['work']] + TRADES[u.trade]['work']), ch(u, D_FUT[:3]), t[0], ch(u, ['মনে করাইয়া দিবা', 'একটু মনে করিয়ে দিও', 'অ্যালার্ম দাও', 'রিমাইন্ড করো'])), dict(hour=t[1])))(ch(u, TIMES)))
F('reminder_add', 'a', lambda u: (lambda t: (j(ch(u, ['প্রতিদিন', 'রোজ']), t[0], ch(u, ['ওষুধ খাওয়ার কথা', 'নামাজের কথা', 'হাঁটার কথা', 'পানি খাওয়ার কথা']), ch(u, ['মনে করিয়ে দিও', 'মনে করাবে'])), dict(hour=t[1], repeat='daily')))(ch(u, TIMES)))
F('reminder_add', 'b', lambda u: (lambda t: (j(ch(u, ['ডেইলি', 'প্রত্যেক দিন', 'প্রতি দিন']), t[0], ch(u, ['প্রেশারের ওষুধ', 'ইনসুলিন', 'ভিটামিন']), ch(u, ['খেতে মনে করিও', 'নেওয়ার রিমাইন্ডার দাও'])), dict(hour=t[1], repeat='daily')))(ch(u, TIMES)))
F('task_query', 'a', lambda u: (j(ch(u, ['আজ', 'কাল', 'আজকে']), ch(u, ['কী কী কাজ আছে', 'কি কাজ আছে', 'কাজের লিস্ট দাও'])), {}))
F('task_query', 'b', lambda u: (j(ch(u, ['আমার', '']), ch(u, ['কালকের', 'আজকের', 'এই সপ্তাহের']), ch(u, ['কাজগুলো কী', 'কাজগুলা বলো', 'তালিকা শোনাও'])), {}))
F('reminder_query', 'a', lambda u: (j(ch(u, ['আমার', '']), ch(u, ['সব রিমাইন্ডার দেখাও', 'রিমাইন্ডারগুলো বলো', 'কী কী রিমাইন্ডার আছে'])), {}))
F('reminder_query', 'b', lambda u: (j(ch(u, ['কাল', 'আজ']), ch(u, ['কী কী মনে করাবে', 'কোন কোন রিমাইন্ডার আছে', 'কয়টা অ্যালার্ম আছে'])), {}))
# health
F('health_add', 'a', lambda u: (lambda a, b: (j(ch(u, ['আমার', 'আম্মার', 'আব্বার', 'আজ']), ch(u, ['প্রেশার', 'বিপি']), f'{L.bn(a)} বাই {L.bn(b)}'), dict(health='bp')))(u.r.randint(100, 170), u.r.randint(60, 105)))
F('health_add', 'b', lambda u: (lambda a, b: (j(ch(u, ['আজ সকালে', 'এখন', 'মাপলাম,']), ch(u, ['প্রেশার', 'ব্লাড প্রেশার']), ch(u, ['আসলো', 'ছিল', 'হলো']), f'{L.bn(a)}/{L.bn(b)}'), dict(health='bp')))(u.r.randint(100, 170), u.r.randint(60, 105)))
F('health_add', 'a', lambda u: (j(ch(u, ['আমার', 'ছেলের', 'আজ']), 'ওজন', f'{L.bn(u.r.randint(8, 95))} কেজি'), dict(health='weight')))
F('health_add', 'b', lambda u: (j(ch(u, ['খালি পেটে', 'আজ', 'খাওয়ার পর']), 'সুগার', ch(u, ['ছিল', 'আসলো', '']), f'{L.bn(u.r.randint(5, 14))}.{L.bn(u.r.randint(0, 9))}'), dict(health='sugar')))
# people, pages, days
F('contact_add', 'a', lambda u: (j(L.gen(_p(u)), 'নম্বর', '০১৭' + ''.join(L.bn(u.r.randint(0, 9)) for _ in range(8)), ch(u, ['রাখো', 'সেভ করো', 'লিখে রাখো'])), {}))
F('contact_add', 'b', lambda u: (j(ch(u, ['নতুন নম্বর', 'নম্বরটা রাখো,']), _p(u), '০১৮' + ''.join(L.bn(u.r.randint(0, 9)) for _ in range(8))), {}))
F('call', 'a', lambda u: (j(_p(u) + 'কে', ch(u, ['ফোন দাও', 'কল দাও', 'একটা ফোন লাগাও'])), {}))
F('call', 'b', lambda u: (j(ch(u, ['একটু', 'এখনই']), _p(u) + 'কে', ch(u, ['কল করো', 'ফোন করো তো'])), {}))
F('open_page', 'a', lambda u: (j(ch(u, ['রিমাইন্ডার', 'নোট', 'হিসাব', 'স্বাস্থ্য', 'ডকুমেন্টস', 'ক্যালেন্ডার']), ch(u, ['খোলো', 'খুলো', 'খুলে দাও'])), dict(page=True)))
F('open_page', 'b', lambda u: (j(ch(u, ['লেনদেনের', 'নোটের', 'রিমাইন্ডারের', 'অভ্যাসের', 'ওষুধের', 'ক্যালেন্ডারের', 'সেটিংসের']), ch(u, ['পাতাটা', 'পেজ', 'পাতা']), ch(u, ['দেখাও', 'খোলো', 'ওপেন করো'])), dict(page=True)))
# Contrast for special_add: a relation and a date are a plan too ("বারো
# নভেম্বর ছেলের টিকা" is a to-do, not a birthday) — only জন্মদিন / বার্ষিকী
# make a yearly day.
F('task_add', 'a', lambda u: (j(f'{L.bn(u.r.randint(1, 28))} {ch(u, L.MONTHS)}', ch(u, ['ছেলের', 'মেয়ের', 'আম্মার', 'বোনের', 'নানুর']), ch(u, ['টিকা', 'স্কুলের মিটিং', 'ডাক্তার দেখানো', 'বিয়েতে দাওয়াত', 'পরীক্ষা', 'চোখের অপারেশন'])), {}))
F('task_add', 'b', lambda u: (j(ch(u, ['ছেলের', 'মেয়ের', 'ভাইয়ের', 'খালার']), ch(u, ['ভর্তির কাজ', 'বিয়ের বাজার', 'টিকার দিন', 'রেজাল্ট আনা']), f'{L.bn(u.r.randint(1, 28))} {ch(u, L.MONTHS)}'), {}))
F('special_add', 'a', lambda u: (j(ch(u, ['ছেলের', 'মেয়ের', 'বউয়ের', 'আম্মার', L.gen(ch(u, L.MALE))]), 'জন্মদিন', f'{L.bn(u.r.randint(1, 28))} {ch(u, L.MONTHS)}'), {}))
F('special_add', 'b', lambda u: (j(f'{L.bn(u.r.randint(1, 28))} {ch(u, L.MONTHS)}', ch(u, ['আমাদের বিবাহবার্ষিকী', 'আমার বিয়ের দিন'])), {}))


def say(u, text):
    """The user's own way of saying it: region, schooling, temper, age."""
    r = u.r
    toks = text.split()
    if u.dialect and r.random() < (0.7 if u.home == 'গ্রাম' else 0.35):
        m = noise.REGION[u.dialect]
        toks = [m.get(t, t) for t in toks]
    if u.school in ('পড়াশোনা নেই', 'প্রাথমিক') and r.random() < 0.5:
        # Spelling as it sounds.
        sp = {'হিসাব': 'হিসেব', 'রিমাইন্ডার': 'রিমান্ডার', 'বৃহস্পতিবার': 'বিস্যুদবার', 'দিলাম': 'দিলাম', 'খরচ': 'খরছ', 'ধার': 'দার', 'কিনলাম': 'কিনলাম',
              'পেলাম': 'পাইলাম', 'হলো': 'হইলো', 'দিয়ে': 'দিয়া', 'করে': 'কইরা', 'নিলাম': 'নিলাম', 'গেল': 'গেলো'}
        toks = [sp.get(t, t) if r.random() < 0.5 else t for t in toks]
    if u.school in ('স্নাতক', 'স্নাতকোত্তর') and r.random() < 0.3:
        en = {'মনে করিয়ে দিও': 'remind করো', 'খরচ': 'খরচ', 'বেতন': 'স্যালারি', 'মিটিং': 'meeting', 'সেভ করো': 'save করো', 'দেখাও': 'show করো'}
        s = ' '.join(toks)
        for k, v in en.items():
            if k in s and r.random() < 0.5:
                s = s.replace(k, v)
        toks = s.split()
    s = ' '.join(toks)
    t = u.temper
    if t == 'ভদ্র' and r.random() < 0.5:
        s = r.choice(['দয়া করে ', 'একটু ', 'প্লিজ ']) + s
    elif t == 'বেশি কথা বলে' and r.random() < 0.6:
        s = r.choice(['শোনো, ', 'আচ্ছা শোনো, ', 'ভাই একটা কথা, ', 'আরেকটা কথা, ']) + s + r.choice(['', ' বুঝছো', ' ঠিক আছে', ' কেমন'])
    elif t == 'দুশ্চিন্তায় থাকে' and r.random() < 0.5:
        s = s + r.choice([' ভুলে যেও না কিন্তু', ' ঠিকমতো রাখবে', ' মনে করে'])
    elif t == 'সন্দেহপ্রবণ' and r.random() < 0.4:
        s = s + r.choice([' ঠিক করে লিখবা', ' ভুল করবা না'])
    elif t == 'ভুলোমনা' and r.random() < 0.4:
        s = r.choice(['ও হ্যাঁ, ', 'ভুলে গেছিলাম, ', 'উমম ']) + s
    elif t == 'তাড়াহুড়ায় থাকে' and r.random() < 0.5:
        s = s.replace(' টাকা', '')
    if u.age == 'বয়স্ক' and r.random() < 0.3:
        s = s + r.choice([' বাবা', ' মা'])
    if u.age == 'কিশোর' and r.random() < 0.3:
        s = s + r.choice([' bro', ' ভাই', ''])
    if not u.mic and r.random() < 0.4:
        s = s + ('?' if re.search(r'(?:^|\s)(?:কত|কী|কি|কয়টা|কোন)(?:\s|$)', s) else '।')
    return re.sub(r'\s+', ' ', s).strip()


def run(n=2000, per=6):
    users, train, test = [], [], []
    for i in range(n):
        u = User(i)
        users.append(u.card())
        half = 'a' if i < n // 2 else 'b'
        fr = [f for f in FRAMES if f[1] == half]
        for k in range(per):
            intent, _, fn = u.r.choice(fr)
            text, want = fn(u)
            row = dict(id=f'crowd-{i:04d}-{k}', user=i, intent=intent, text=say(u, text), want=want)
            (train if half == 'a' else test).append(row)
    os.makedirs(OUT, exist_ok=True)
    for name, rows in (('users', users), ('train', train), ('test', test)):
        with open(os.path.join(OUT, f'{name}.jsonl'), 'w') as f:
            for r in rows:
                f.write(json.dumps(r, ensure_ascii=False) + '\n')
    # The test half is gold: measured, never taught.
    with open(os.path.join(ROOT, 'gold', 'crowd.jsonl'), 'w') as f:
        seen = set()
        for r in test:
            if r['text'] in seen:
                continue
            seen.add(r['text'])
            f.write(json.dumps(dict(id=r['id'], source='crowd', tuned=False, fixture='empty', now='2026-10-09T15:53', before=[], state='idle',
                                    text=r['text'], intent=[r['intent']], slots={}), ensure_ascii=False) + '\n')
    print(len(users), 'users;', len(train), 'training sentences;', len(test), 'test sentences')


if __name__ == '__main__':
    random.seed(7)
    run()
