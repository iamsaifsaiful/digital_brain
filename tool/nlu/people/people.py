# 5,000 made-up users (owner, 25 Oct 2026: "৫ হাজার ইউজারের লিস্ট বানাও …
# প্রতিটি মেনুর ভেতরে … একেক জন একেক ভাবে প্রশ্ন করবে … এভাবে তাকে শেখাও।
# প্রয়োজনে খরচ কর"). Each user has an age, a gender, a trade, a district (and
# its speech), schooling, a temper, a way of using the phone; an AI (Claude
# Haiku, batch) writes what that user would say in every menu — and a few
# long one-breath messages with several things in them — with the meaning
# (intent) and the values (<amount>…</amount>, <person>…</person> …) marked.
#
#   python3 tool/nlu/people/people.py prepare            # personas, requests, cost estimate; nothing sent
#   ANTHROPIC_API_KEY=… python3 tool/nlu/people/people.py run --budget 20
#        sends a pilot (100 users), measures the real token use, projects the
#        total; sends the rest only when the projection is under the budget
#   python3 tool/nlu/people/people.py verify             # labels checked, near-duplicates dropped, split
#
# Users 0–3999 → out/people/train.jsonl (training); 4000–4999 → out/people/test.jsonl
# (measuring only — never trained on), and a sample of it → tool/nlu/gold/people.jsonl.
# Synthetic people and sentences only: nothing of a real member is sent. The
# key is read from the environment and never written anywhere.
import argparse, json, os, random, re, sys, time, urllib.request, hashlib
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..'))
OUT = os.path.join(ROOT, 'out', 'people')
GOLD = os.path.join(ROOT, 'gold', 'people.jsonl')
MODEL = 'claude-haiku-5-5'
PRICE = dict(input=0.05, output=0.25)  # USD per million tokens, Haiku 5.5 batch (platform.claude.com pricing, 25 Oct 2026)
N_USERS, N_TRAIN = 5000, 4000

# ── Who they are ──
DISTRICTS = {  # district → regional speech (None: standard with own slips)
    'ঢাকা': None, 'গাজীপুর': None, 'নারায়ণগঞ্জ': None, 'নরসিংদী': None, 'মানিকগঞ্জ': None, 'মুন্সিগঞ্জ': None, 'টাঙ্গাইল': 'ময়মনসিংহ',
    'কিশোরগঞ্জ': 'ময়মনসিংহ', 'ফরিদপুর': None, 'গোপালগঞ্জ': None, 'মাদারীপুর': 'বরিশাল', 'শরীয়তপুর': 'বরিশাল', 'রাজবাড়ী': None,
    'ময়মনসিংহ': 'ময়মনসিংহ', 'জামালপুর': 'ময়মনসিংহ', 'শেরপুর': 'ময়মনসিংহ', 'নেত্রকোনা': 'ময়মনসিংহ',
    'চট্টগ্রাম': 'চট্টগ্রাম', 'কক্সবাজার': 'চট্টগ্রাম', 'বান্দরবান': 'চট্টগ্রাম', 'রাঙামাটি': 'চট্টগ্রাম', 'খাগড়াছড়ি': 'চট্টগ্রাম',
    'নোয়াখালী': 'নোয়াখালী', 'ফেনী': 'নোয়াখালী', 'লক্ষ্মীপুর': 'নোয়াখালী', 'কুমিল্লা': 'কুমিল্লা', 'চাঁদপুর': 'নোয়াখালী', 'ব্রাহ্মণবাড়িয়া': 'কুমিল্লা',
    'সিলেট': 'সিলেট', 'মৌলভীবাজার': 'সিলেট', 'হবিগঞ্জ': 'সিলেট', 'সুনামগঞ্জ': 'সিলেট',
    'বরিশাল': 'বরিশাল', 'পটুয়াখালী': 'বরিশাল', 'ভোলা': 'বরিশাল', 'পিরোজপুর': 'বরিশাল', 'ঝালকাঠি': 'বরিশাল', 'বরগুনা': 'বরিশাল',
    'খুলনা': 'খুলনা', 'যশোর': 'খুলনা', 'সাতক্ষীরা': 'খুলনা', 'বাগেরহাট': 'খুলনা', 'কুষ্টিয়া': 'কুষ্টিয়া', 'ঝিনাইদহ': 'খুলনা', 'মাগুরা': 'খুলনা', 'নড়াইল': 'খুলনা',
    'চুয়াডাঙ্গা': 'কুষ্টিয়া', 'মেহেরপুর': 'কুষ্টিয়া',
    'রাজশাহী': 'রাজশাহী', 'নাটোর': 'রাজশাহী', 'নওগাঁ': 'রাজশাহী', 'চাঁপাইনবাবগঞ্জ': 'রাজশাহী', 'পাবনা': 'পাবনা', 'সিরাজগঞ্জ': 'পাবনা', 'বগুড়া': 'বগুড়া', 'জয়পুরহাট': 'বগুড়া',
    'রংপুর': 'রংপুর', 'দিনাজপুর': 'রংপুর', 'গাইবান্ধা': 'রংপুর', 'কুড়িগ্রাম': 'রংপুর', 'লালমনিরহাট': 'রংপুর', 'নীলফামারী': 'রংপুর', 'ঠাকুরগাঁও': 'রংপুর', 'পঞ্চগড়': 'রংপুর',
}
TRADES = ['কৃষক', 'জেলে', 'দিনমজুর', 'রিকশাচালক', 'সিএনজি চালক', 'বাস/ট্রাক চালক', 'গার্মেন্টস শ্রমিক', 'দোকানদার', 'পাইকারি ব্যবসায়ী', 'মুদি দোকানি',
          'ফেরিওয়ালা', 'দর্জি', 'রাজমিস্ত্রি', 'কাঠমিস্ত্রি', 'ইলেকট্রিশিয়ান', 'মোবাইল মেকানিক', 'গৃহিণী', 'গৃহকর্মী', 'ছাত্র', 'ছাত্রী', 'মাদ্রাসার শিক্ষার্থী',
          'স্কুলশিক্ষক', 'কলেজশিক্ষক', 'মাদ্রাসাশিক্ষক', 'ইমাম', 'ডাক্তার', 'নার্স', 'ফার্মেসি মালিক', 'ব্যাংকার', 'অফিস কর্মচারী', 'সরকারি চাকরিজীবী',
          'পুলিশ সদস্য', 'সেনা সদস্য', 'আইনজীবী', 'প্রকৌশলী', 'সফটওয়্যার ডেভেলপার', 'ফ্রিল্যান্সার', 'সাংবাদিক', 'এনজিও কর্মী', 'প্রবাসী শ্রমিক (সৌদি/দুবাই/মালয়েশিয়া)',
          'প্রবাসী (ইউরোপ/আমেরিকা)', 'অবসরপ্রাপ্ত', 'বাড়িওয়ালা', 'ডেলিভারি কর্মী', 'রেস্টুরেন্ট কর্মী', 'বিউটি পার্লার মালিক', 'অনলাইন ব্যবসায়ী', 'ঠিকাদার', 'হাঁস-মুরগির খামারি', 'গরুর খামারি']
AGES = [(15, 19), (20, 29), (30, 44), (45, 59), (60, 80)]
AGES_W = [8, 30, 32, 20, 10]
SCHOOLING = ['পড়াশোনা নেই', 'প্রাথমিক', 'মাধ্যমিক', 'উচ্চমাধ্যমিক', 'স্নাতক', 'স্নাতকোত্তর']
SCHOOLING_W = [7, 16, 26, 21, 22, 8]
TEMPER = ['ভদ্র ও ধীরস্থির', 'অল্প কথায় বলে', 'অনেক কথা বলে, ঘুরিয়ে বলে', 'দুশ্চিন্তায় থাকে', 'রাগী, অধৈর্য', 'রসিক', 'ভুলোমনা', 'সবসময় তাড়াহুড়ায়', 'খুব বিনয়ী',
          'আদেশের সুরে বলে', 'আবেগপ্রবণ', 'হিসাবি, খুঁটিনাটি বলে']
STYLE = ['মুখে বলে (ভয়েস) — যতিচিহ্ন নেই, এক নিঃশ্বাসে', 'মুখে বলে — মাঝে মাঝে থেমে, "মানে", "তো", "আচ্ছা" দিয়ে', 'টাইপ করে — ছোট করে', 'টাইপ করে — বানান ভুলসহ',
         'বাংলিশে টাইপ করে (রোমান হরফে বাংলা)', 'মুখে বলে — ইংরেজি শব্দ মিশিয়ে']
STYLE_W = [30, 22, 18, 12, 8, 10]

# ── What they ask, menu by menu (context-free requests; follow-ups like
# "হ্যাঁ", "২ নম্বরটা", "না কাল" stay with the made data, which knows the state) ──
GROUPS = [
    ('কাজের তালিকা', ['task_add', 'task_done', 'task_edit', 'task_delete', 'task_query', 'task_remind']),
    ('রিমাইন্ডার ও অ্যালার্ম', ['reminder_add', 'reminder_edit', 'reminder_stop', 'reminder_delete', 'reminder_query', 'menu_alarm']),
    ('আয়-ব্যয়', ['cash_add', 'cash_query', 'menu_cash']),
    ('ধার-দেনা ও পাওনা', ['ledger_add', 'ledger_set', 'ledger_query', 'menu_people']),
    ('নোট', ['note_add', 'note_query', 'menu_notes']),
    ('পাসওয়ার্ড, নম্বর ও ফোন', ['vault_add', 'vault_query', 'contact_add', 'contact_query', 'call']),
    ('স্বাস্থ্য ও ওষুধ', ['health_add', 'menu_health', 'menu_medicine']),
    ('বিশেষ দিন ও নিজের তথ্য', ['special_add', 'special_query', 'menu_special', 'memory_add', 'profile_query', 'menu_memory']),
    ('সঞ্চয়, কিস্তি, একাউন্ট, যাকাত', ['menu_savings', 'menu_installment', 'menu_accounts', 'menu_zakat']),
    ('অভ্যাস, আলাদা হিসাব, দোকান', ['menu_habit', 'menu_project', 'menu_shop']),
    ('পাতা খোলা, তারিখ, সারাংশ, ব্যাকআপ, সেটিংস, কাগজ', ['open_page', 'calendar_query', 'briefing', 'menu_backup', 'menu_settings', 'menu_trash', 'doc_query']),
    ('কথাবার্তা', ['smalltalk', 'complain_help', 'out_of_scope', 'cancel']),
]
HALVES = [GROUPS[:6], GROUPS[6:]]
PER_GROUP = 3
LONG_PER_REQUEST = 3
SLOTS = {
    'amount': 'টাকার অঙ্ক যেমন বলা ("৫০০ টাকা", "পাঁচ হাজার", "দেড় লাখ")', 'amount2': 'দ্বিতীয় অঙ্ক', 'balance': 'মোট/বাকি অঙ্ক', 'person': 'মানুষের নাম বা সম্পর্ক ("রহিম", "আম্মা", "বড় ভাই")',
    'date': 'দিন/তারিখ ("কাল", "২০ তারিখ", "শুক্রবার")', 'time': 'ঘড়ির সময় ("৮টায়", "সাড়ে নয়টা")', 'daypart': 'দিনের ভাগ ("সকাল", "রাতে")', 'repeat': 'বারবার ("প্রতিদিন", "প্রতি মাসে")',
    'before': 'কত আগে ("১ ঘণ্টা আগে")', 'minutes': 'কত মিনিট পরে', 'title': 'কাজ/রিমাইন্ডারের বিষয়', 'new_title': 'নতুন নাম', 'item': 'জিনিস ("চাল", "ওষুধের নাম")', 'quantity': 'পরিমাণ ("২ কেজি")',
    'category': 'খরচের খাত', 'account': 'একাউন্ট ("বিকাশ", "সোনালী ব্যাংক")', 'phone': 'ফোন নম্বর', 'text': 'নোট/পাসওয়ার্ডের লেখা', 'target': 'কোন জিনিস/কোন কাজ', 'target2': 'দ্বিতীয়টা',
    'page': 'পাতার নাম', 'list_ref': 'তালিকার নম্বর ("৩ নম্বর")', 'filter': 'বাছাই ("শেষ হওয়া")', 'filter_month': 'মাস', 'filter_year': 'সাল', 'special_kind': 'জন্মদিন/বিবাহবার্ষিকী', 'shift_days': 'কত দিন সরানো', 'terms': 'শর্ত',
}


def personas():
    rnd = random.Random(2510)
    names_m = ['রহিম', 'করিম', 'সাইফুল', 'রফিক', 'জামাল', 'হাসান', 'সুমন', 'নাঈম', 'আরিফ', 'বাবুল', 'মিজান', 'শাহীন', 'তানভীর', 'রুবেল', 'ইমরান', 'শফিক', 'মোস্তফা', 'নুরুল', 'আব্দুল', 'কামাল']
    names_f = ['রহিমা', 'ফাতেমা', 'নাসরিন', 'শিরিন', 'রুমা', 'তানিয়া', 'সুমাইয়া', 'আয়েশা', 'জান্নাত', 'শাহনাজ', 'রেহানা', 'মিতু', 'লাকি', 'পারভীন', 'সালমা', 'নুসরাত', 'মরিয়ম', 'হালিমা', 'রিনা', 'কুলসুম']
    out = []
    for i in range(N_USERS):
        lo, hi = rnd.choices(AGES, AGES_W)[0]
        age = rnd.randint(lo, hi)
        female = rnd.random() < 0.48
        trade = rnd.choice(TRADES)
        if trade in ('গৃহিণী', 'ছাত্রী', 'বিউটি পার্লার মালিক'):
            female = True
        if trade in ('ছাত্র', 'ইমাম', 'রিকশাচালক', 'সিএনজি চালক', 'বাস/ট্রাক চালক', 'রাজমিস্ত্রি', 'জেলে'):
            female = False
        if age < 23 and trade in ('অবসরপ্রাপ্ত', 'বাড়িওয়ালা', 'কলেজশিক্ষক', 'ব্যাংকার'):
            trade = rnd.choice(['ছাত্র' if not female else 'ছাত্রী', 'ফ্রিল্যান্সার', 'দোকানদার'])
        if age >= 60 and rnd.random() < 0.5:
            trade = 'অবসরপ্রাপ্ত'
        district = rnd.choice(list(DISTRICTS))
        out.append(dict(
            id=i, name=rnd.choice(names_f if female else names_m), age=age, gender='নারী' if female else 'পুরুষ', trade=trade, district=district,
            speech=DISTRICTS[district] or 'প্রমিত (নিজের টান অল্প)', schooling=rnd.choices(SCHOOLING, SCHOOLING_W)[0],
            temper=rnd.choice(TEMPER), style=rnd.choices(STYLE, STYLE_W)[0], family=rnd.choice(['একা থাকে', 'স্বামী/স্ত্রী ও সন্তান', 'বাবা-মাসহ যৌথ পরিবার', 'বিদেশে, পরিবার দেশে'])))
    return out


def _spec():
    return {x['id']: x for x in json.load(open(os.path.join(ROOT, 'spec', 'intents.json')))}


def prompt_for(p, groups, spec):
    lines = []
    for title, ids in groups:
        lines.append(f'## {title}')
        for i in ids:
            s = spec[i]
            lines.append(f'- {i}: {s["when"]}' + (f' (নয়: {s["not_when"]})' if s.get('not_when') else ''))
    slot_lines = '\n'.join(f'- <{k}>: {v}' for k, v in SLOTS.items())
    who = (f'{p["name"]}, {p["age"]} বছর, {p["gender"]}, পেশা {p["trade"]}, জেলা {p["district"]} (ভাষার টান: {p["speech"]}), পড়াশোনা {p["schooling"]}, '
           f'মেজাজ: {p["temper"]}, পরিবার: {p["family"]}, অ্যাপে যেভাবে বলে: {p["style"]}।')
    return f'''You write test messages for "My Assistant", a Bengali personal assistant app (to-dos, reminders, money, loans, notes, health, family…). Users talk to it by voice (speech-to-text output) or by typing.

The user (made-up): {who}

Write what THIS person would really say to the app, in their own words, age, trade, mood and regional speech. For EACH group below write {PER_GROUP} messages with DIFFERENT request types from that group (use the listed ids), each a different everyday situation from their life. Then write {LONG_PER_REQUEST} LONG messages said in one breath that contain 2–4 separate requests (each 8–30 words; voice style: no punctuation, fillers, "আর", "তারপর", numbers often in words).

Request types:
{chr(10).join(lines)}

Mark every value with a tag, keeping the person's exact words inside (do not normalise them):
{slot_lines}

Rules:
- Sound like a real person of this kind — never like a template. Vary length (2–30 words), word order, politeness, mistakes, dialect verb forms, money in words or digits, Bangladeshi names and places.
- Each message stands alone (no "হ্যাঁ", "২ নম্বরটা" replies). No two messages alike.
- Only facts a person would say; no real phone numbers (use 017XXXXXXXX-like made-up ones), no real passwords.
- Answer ONLY JSON: {{"items": [{{"intent": "task_add", "text": "কাল <date>সকালে</date> বাজার করতে হবে"}}, …, {{"multi": [{{"intent": "cash_add", "text": "…"}}, {{"intent": "reminder_add", "text": "…"}}]}}]}}'''


def prepare(a):
    os.makedirs(OUT, exist_ok=True)
    spec = _spec()
    ps = personas()
    json.dump(ps, open(os.path.join(OUT, 'users.json'), 'w'), ensure_ascii=False)
    reqs = []
    for p in ps:
        for h, groups in enumerate(HALVES):
            reqs.append(dict(custom_id=f'u{p["id"]}-h{h}', user=p['id'], half=h, prompt=prompt_for(p, groups, spec)))
    with open(os.path.join(OUT, 'requests.jsonl'), 'w') as f:
        for r in reqs:
            f.write(json.dumps(r, ensure_ascii=False) + '\n')
    tin = sum(len(r['prompt']) for r in reqs) / 1.6
    tout = len(reqs) * (PER_GROUP * 6 + LONG_PER_REQUEST * 3) * 45  # ~45 tokens a Bengali message with tags
    usd = tin / 1e6 * PRICE['input'] + tout / 1e6 * PRICE['output']
    print(json.dumps(dict(users=len(ps), requests=len(reqs), input_tokens=int(tin), output_tokens=int(tout), usd_estimate=round(usd, 2)), ensure_ascii=False))


def _http(url, body=None, headers=None):
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, headers=headers or {})
    with urllib.request.urlopen(req, timeout=300) as r:
        return r.read()


def _batch(reqs, key, tag):
    h = {'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json'}
    ids = []
    for i in range(0, len(reqs), 5000):  # a batch takes at most 10,000 requests
        part = reqs[i:i + 5000]
        body = dict(requests=[dict(custom_id=x['custom_id'], params=dict(model=MODEL, max_tokens=4000, messages=[dict(role='user', content=x['prompt'])])) for x in part])
        res = json.loads(_http('https://api.anthropic.com/v1/messages/batches', body, h))
        ids.append(res['id'])
        print(tag, 'batch', res['id'], len(part), flush=True)
    usage = Counter()
    raw = open(os.path.join(OUT, 'raw.jsonl'), 'a')
    for bid in ids:
        while True:
            st = json.loads(_http(f'https://api.anthropic.com/v1/messages/batches/{bid}', headers=h))
            if st['processing_status'] == 'ended':
                break
            print(tag, 'waiting', st['request_counts'], flush=True)
            time.sleep(60)
        for line in _http(st['results_url'], headers=h).decode().splitlines():
            r = json.loads(line)
            if r['result']['type'] != 'succeeded':
                usage['failed'] += 1
                continue
            m = r['result']['message']
            usage['input'] += m['usage']['input_tokens']
            usage['output'] += m['usage']['output_tokens']
            usage['ok'] += 1
            raw.write(json.dumps(dict(custom_id=r['custom_id'], text=''.join(c.get('text', '') for c in m['content'])), ensure_ascii=False) + '\n')
    raw.close()
    usage['usd'] = round(usage['input'] / 1e6 * PRICE['input'] + usage['output'] / 1e6 * PRICE['output'], 4)
    return usage


def run(a):
    key = os.environ.get('ANTHROPIC_API_KEY', '')
    if not key:
        sys.exit('ANTHROPIC_API_KEY is not set')
    reqs = [json.loads(l) for l in open(os.path.join(OUT, 'requests.jsonl'))]
    open(os.path.join(OUT, 'raw.jsonl'), 'w').close()
    pilot_users = set(range(N_TRAIN - 50, N_TRAIN + 50))  # 100 users across both halves
    pilot = [r for r in reqs if r['user'] in pilot_users]
    u1 = _batch(pilot, key, 'pilot')
    per_req = u1['usd'] / max(1, u1['ok'])
    projected = u1['usd'] + per_req * (len(reqs) - len(pilot))
    report = dict(pilot=dict(u1), projected_usd=round(projected, 2), budget_usd=a.budget)
    print('pilot', json.dumps(report), flush=True)
    if projected > a.budget:
        report['stopped'] = 'projected cost over budget'
        json.dump(report, open(os.path.join(OUT, 'usage.json'), 'w'))
        print('STOP: projected', round(projected, 2), '> budget', a.budget)
        return
    u2 = _batch([r for r in reqs if r['user'] not in pilot_users], key, 'main')
    report['main'] = dict(u2)
    report['total_usd'] = round(u1['usd'] + u2['usd'], 2)
    json.dump(report, open(os.path.join(OUT, 'usage.json'), 'w'))
    print('done', json.dumps(report), flush=True)


TAG = re.compile(r'<([a-z_0-9]+)>(.*?)</\1>')


def _tokens(text):
    toks, tags, pos = [], [], 0
    for m in TAG.finditer(text):
        if m.group(1) not in SLOTS:
            return None
        for w in text[pos:m.start()].split():
            toks.append(w)
            tags.append('O')
        words = m.group(2).split()
        if not words:
            return None
        for k, w in enumerate(words):
            toks.append(w)
            tags.append(('B-' if k == 0 else 'I-') + m.group(1))
        pos = m.end()
    for w in text[pos:].split():
        toks.append(w)
        tags.append('O')
    if any('<' in t or '>' in t for t in toks) or not toks:
        return None
    return toks, tags


def _norm(s):
    s = re.sub(r'[^\w\s]', ' ', s.lower())
    return re.sub(r'\s+', ' ', s).strip()


def _shingles(s):
    s = _norm(s)
    return {s[i:i + 4] for i in range(max(1, len(s) - 3))}


def _minhash(sh, seeds):
    return tuple(min((int(hashlib.blake2b(f'{k}:{x}'.encode(), digest_size=8).hexdigest(), 16) for x in sh), default=0) for k in seeds)


def verify(a):
    users = {u['id']: u for u in json.load(open(os.path.join(OUT, 'users.json')))}
    reqs = {r['custom_id']: r for r in map(json.loads, open(os.path.join(OUT, 'requests.jsonl')))}
    allowed = {h: {i for _, ids in groups for i in ids} for h, groups in enumerate(HALVES)}
    every = set().union(*allowed.values())
    rows, why = [], Counter()
    for line in open(os.path.join(OUT, 'raw.jsonl')):
        r = json.loads(line)
        q = reqs.get(r['custom_id'])
        if not q:
            why['no_request'] += 1
            continue
        try:
            items = json.loads(re.search(r'\{.*\}', r['text'], re.S).group(0))['items']
        except Exception:
            why['bad_json'] += 1
            continue
        for it in items:
            parts = it.get('multi') if isinstance(it, dict) and it.get('multi') else [it]
            toks, tags, segs, ok = [], [], [], True
            for part in parts:
                intent = (part or {}).get('intent')
                got = _tokens(re.sub(r'\s+', ' ', str((part or {}).get('text', ''))).strip())
                # Long messages may reach into the other half's menus too.
                if intent not in (every if len(parts) > 1 else allowed[q['half']]) or got is None:
                    ok = False
                    break
                start = len(toks)
                toks += got[0]
                tags += got[1]
                segs.append(dict(intent=intent, start=start, end=len(toks), slots={}))
            if not ok:
                why['bad_label'] += 1
                continue
            u = q['user']
            rows.append(dict(id=f'people-{u}-{len(rows)}', family=f'people:{u}', kind='people' + ('+multi' if len(segs) > 1 else ''), user=u, state='idle', shown=[], asked=None,
                             tokens=toks, tags=tags, text=' '.join(toks), intent=[s['intent'] for s in segs], segs=segs, noise=[], split='train' if u < N_TRAIN else 'test'))
    why['parsed'] = len(rows)
    # No two alike: the same words (normalised), or 80% of the same 4-letter pieces.
    seen, kept = set(), []
    for x in rows:
        n = _norm(x['text'])
        if n in seen:
            why['dup_exact'] += 1
            continue
        seen.add(n)
        kept.append(x)
    seeds = list(range(24))
    bands = defaultdict(list)
    drop = set()
    sh = [_shingles(x['text']) for x in kept]
    for i, x in enumerate(kept):
        mh = _minhash(sh[i], seeds)
        near = False
        for b in range(6):
            k = (b, mh[b * 4:(b + 1) * 4])
            for j in bands[k]:
                if j in drop:
                    continue
                inter = len(sh[i] & sh[j])
                if inter / max(1, len(sh[i] | sh[j])) >= 0.8:
                    near = True
                    break
            if near:
                break
        if near:
            drop.add(i)
            why['dup_near'] += 1
            continue
        for b in range(6):
            bands[(b, mh[b * 4:(b + 1) * 4])].append(i)
    kept = [x for i, x in enumerate(kept) if i not in drop]
    train = [x for x in kept if x['split'] == 'train']
    test = [x for x in kept if x['split'] == 'test']
    for name, part in (('train', train), ('test', test)):
        with open(os.path.join(OUT, f'{name}.jsonl'), 'w') as f:
            for x in part:
                f.write(json.dumps(x, ensure_ascii=False) + '\n')
    # A sample of the test half as gold (the app's own measuring set).
    rnd = random.Random(7)
    sample = rnd.sample(test, min(len(test), a.gold))
    with open(GOLD, 'w') as f:
        for x in sample:
            f.write(json.dumps(dict(id=x['id'], source='people', tuned=False, fixture='empty', now='2026-10-25T10:00', before=[], state='idle', text=x['text'], intent=x['intent'], slots={}),
                               ensure_ascii=False) + '\n')
    why.update(train=len(train), test=len(test), gold=len(sample), users_train=len({x['user'] for x in train}), users_test=len({x['user'] for x in test}))
    by_intent = Counter(i for x in train for i in x['intent'])
    json.dump(dict(why=why, by_intent=by_intent), open(os.path.join(OUT, 'stats.json'), 'w'), ensure_ascii=False, indent=1)
    print(json.dumps(dict(why), ensure_ascii=False))


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('cmd', choices=['prepare', 'run', 'verify'])
    ap.add_argument('--budget', type=float, default=20.0)
    ap.add_argument('--gold', type=int, default=3000)
    a = ap.parse_args()
    dict(prepare=prepare, run=run, verify=verify)[a.cmd](a)
