# Step D: make labelled training sentences from the templates.
#   python3 tool/nlu/data/generate.py [--seed 7] [--scale 1.0]
# Writes tool/nlu/out/data/{train,dev,dropped_gold}.jsonl, stats.json,
# review_1000.csv. The same seed gives the same files.
import argparse, csv, glob, hashlib, json, os, random, re, sys
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import fill, noise  # noqa: E402
import lexicon as L  # noqa: E402
import render as R  # noqa: E402
from templates_tasks import T as T1  # noqa: E402
from templates_money import T as T2  # noqa: E402
from templates_other import T as T3  # noqa: E402
from templates_context import CTX  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, '..'))
OUT = os.path.join(ROOT, 'out', 'data')
GOLD = os.path.join(ROOT, 'gold')
SPEC = os.path.join(ROOT, 'spec')

# How many distinct sentences to aim for per intent (idle, single request).
BUDGET = defaultdict(lambda: 500, {
    'task_add': 2600, 'task_done': 900, 'task_edit': 1300, 'task_delete': 1300, 'task_query': 1300, 'task_remind': 700, 'task_reopen': 450,
    'task_skip_once': 400, 'reminder_add': 2200, 'reminder_edit': 900, 'reminder_stop': 600, 'reminder_delete': 900, 'reminder_snooze': 250,
    'reminder_query': 700, 'ledger_add': 2400, 'ledger_set': 700, 'ledger_query': 900, 'cash_add': 2400, 'cash_query': 700, 'rename': 900,
    'item_delete': 800, 'note_add': 700, 'note_query': 400, 'dictate_start': 300, 'dictate_end': 0, 'correct': 400, 'complain_help': 250,
    'smalltalk': 120, 'out_of_scope': 300, 'menu_alarm': 120, 'menu_backup': 120, 'menu_settings': 200, 'menu_zakat': 120, 'briefing': 80,
    'calendar_query': 200, 'profile_query': 120, 'menu_trash': 200, 'menu_installment': 200, 'menu_health': 250, 'menu_special': 250,
})
CTX_BUDGET = 260          # per (state, shown, intent)
MULTI = 3500              # several requests in one message
HEADED = 1800             # a heading and lines that inherit its date/year
EXIT_SHARE = 0.05         # idle requests said while the app was waiting
NOISE_RATE = 0.4
DEV_SHARE = 0.12


def families(T):
    out = []
    for intent, body in T.items():
        for k, block in enumerate(re.split(r'\n\s*\n', body.strip('\n'))):
            lines = [l.strip() for l in block.split('\n') if l.strip()]
            meta = {}
            if lines and lines[0].startswith('@'):
                meta = dict(kv.split('=') for kv in lines[0][1:].split())
                lines = lines[1:]
            if lines:
                out.append(dict(intent=intent, fam=f'{intent}#{k}', meta=meta, lines=lines))
    return out


def norm(t):
    t = re.sub(r'[?,।!:;—\-/=.()]', ' ', t).translate(noise.BN)
    t = re.sub(r'[০-৯]+', '#', t)
    return re.sub(r'\s+', ' ', t).strip().lower()


def row_from(tokens, tags, slots, intent, fam, meta, state='idle', shown=None, asked=None, kind='single'):
    slots = dict(slots)
    for k, v in meta.items():
        if k == 'opt':
            slots['list_ref'] = f'opt:{v}'
        elif k != 'pair':
            slots[k] = v
    return dict(family=fam, kind=kind, state=state, shown=shown or [], asked=asked, tokens=tokens, tags=tags, text=' '.join(tokens),
                intent=[intent], segs=[dict(intent=intent, start=0, end=len(tokens), slots=slots)], slots=slots,
                pair=meta.get('pair'), noise=[])


def gen_family(f, want, state='idle', shown_kind=None, asked=None, kind='single'):
    rows, seen = [], set()
    tries = 0
    while len(rows) < want and tries < want * 12:
        tries += 1
        line = f['lines'][tries % len(f['lines'])]
        try:
            toks, tags, slots = fill.fill(line)
        except KeyError as e:
            raise SystemExit(f'unknown placeholder {e} in {f["fam"]}: {line}')
        key = ' '.join(toks)
        if key in seen:
            continue
        seen.add(key)
        rows.append(row_from(toks, tags, slots, f['intent'], f['fam'], f['meta'], state, shown_list(shown_kind), asked, kind))
    return rows


def shown_list(kind):
    if kind == 'tasks':
        return [L.todo()['title'] for _ in range(random.randint(2, 6))]
    if kind == 'reminders':
        return [random.choice(L.REMINDER_SUBJECTS) for _ in range(random.randint(2, 5))]
    return []


def singles():
    fams = families(T1) + families(T2) + families(T3)
    by_intent = defaultdict(list)
    for f in fams:
        by_intent[f['intent']].append(f)
    rows = []
    for intent, fs in by_intent.items():
        want = BUDGET[intent]
        if not want:
            continue
        total_lines = sum(len(f['lines']) for f in fs)
        for f in fs:
            rows += gen_family(f, max(8, round(want * len(f['lines']) / total_lines)))
    return rows, fams


def contexts():
    rows = []
    for c in CTX:
        for intent, body in c['T'].items():
            fs = families({intent: body})
            for f in fs:
                f['fam'] = f"{c['state']}:{c['shown']}:{f['fam']}"
                n = max(6, CTX_BUDGET // len(fs))
                rows += gen_family(f, n, c['state'], c['shown'], c['asked'], 'context')
    return rows


CONNECT = [' আর ', ', ', ', আর ', '। ', ' এবং ', ', তারপর ', ', সাথে ']
MULTI_INTENTS = ['task_add', 'task_add', 'reminder_add', 'cash_add', 'cash_add', 'ledger_add', 'note_add', 'task_done', 'task_edit', 'task_delete', 'reminder_add']


def join_rows(parts, kind, sep_fn):
    tokens, tags, segs = [], [], []
    for i, p in enumerate(parts):
        if i:
            sep = sep_fn(i).split()
            tokens += sep
            tags += ['O'] * len(sep)
        start = len(tokens)
        tokens += p['tokens']
        tags += p['tags']
        segs.append(dict(intent=p['intent'][0], start=start, end=len(tokens), slots=p['slots']))
    return dict(family='+'.join(p['family'] for p in parts), kind=kind, state='idle', shown=[], asked=None, tokens=tokens, tags=tags,
                text=' '.join(tokens), intent=[s['intent'] for s in segs], segs=segs, slots={}, pair=None, noise=[])


def multis(pool):
    by = defaultdict(list)
    for r in pool:
        if r['state'] == 'idle' and len(r['tokens']) <= 12:
            by[r['intent'][0]].append(r)
    rows = []
    for k in range(MULTI):
        n = random.choice([2, 2, 2, 3])
        parts = [random.choice(by[random.choice(MULTI_INTENTS)]) for _ in range(n)]
        if k % 4 == 0:
            # A numbered list.
            sep = lambda i: f'{L.bn(i + 1)}.'
            r = join_rows(parts, 'multi_numbered', sep)
            r['tokens'] = ['১.'] + r['tokens']
            r['tags'] = ['O'] + r['tags']
            for s in r['segs']:
                s['start'] += 1
                s['end'] += 1
            r['text'] = ' '.join(r['tokens'])
        else:
            c = random.choice(CONNECT)
            r = join_rows(parts, 'multi', lambda i: c)
        rows.append(r)
    return rows


def headed():
    """A heading whose day/year every line takes on."""
    rows = []
    for k in range(HEADED):
        ctx = fill.Ctx()
        r = random.random()
        if r < 0.45:
            head = random.choice(['{pdategen} [বাজারের হিসাব|বাজার|খরচ|খরচের হিসাব]:', '[বাজারের হিসাব|খরচ] {pdate}:', '{pdategen} বাজার:'])
            htoks, htags, hslots = fill.fill(head, ctx)
            lines, used = [], set()
            for i in range(random.randint(2, 5)):
                c = fill.Ctx()
                market = 'বাজার' in ' '.join(htoks)
                c.memo['item'] = random.choice([x for x in L.ITEMS if x[0] not in used and (not market or x[3] in ('বাজার', 'সংসার', 'খাবার'))])
                used.add(c.memo['item'][0])
                t, g, s = fill.fill(random.choice(['{item} {price}', '{qty} {item:buy} {price}', '{item:buy} {qty} {price}', '{item} {price}', '{item} - {price}']), c)
                s = dict(s, cash_kind='expense', **{'date': hslots.get('date')} if hslots.get('date') else {})
                s['inherited'] = ['date'] if hslots.get('date') else []
                lines.append((t, g, s, 'cash_add'))
        elif r < 0.8:
            head = random.choice(['{year} কাজ:', '{year} [কাজগুলো|করণীয়|লিস্ট]:', '{month} কাজ:', '{month} [কাজগুলো|করণীয়]:', '{dategen} [কাজ|লিস্ট|কাজের তালিকা]:'])
            htoks, htags, hslots = fill.fill(head, ctx)
            inherit = {k: v for k, v in hslots.items() if k in ('filter_year', 'filter_month', 'date')}
            lines, seen_lines = [], set()
            for i in range(random.randint(2, 5)):
                c = fill.Ctx()
                if 'date' in inherit:
                    tmpl = '{todo:title}'
                elif 'filter_month' in inherit:
                    tmpl = random.choice(['{dom} {todo:title}', '{todo:title}', '{dom}: {todo:title}'])
                else:
                    tmpl = random.choice(['{dm} {todo:title}', '{todo:title}', '{dm} {todo:title}', '{dm}: {todo:title}'])
                t, g, s = fill.fill(tmpl, c)
                if ' '.join(t) in seen_lines:
                    continue
                seen_lines.add(' '.join(t))
                s = dict(s)
                if 'filter_year' in inherit and 'date' in s:
                    s['date'] = s['date'].replace('????', str(inherit['filter_year']))
                if 'filter_month' in inherit and str(s.get('date', '')).startswith('dom:'):
                    s['date'] = f"????-{inherit['filter_month']:02d}-{int(s['date'][4:]):02d}"
                s['inherited'] = list(inherit)
                for kk, vv in inherit.items():
                    s.setdefault(kk, vv)
                lines.append((t, g, s, 'task_add'))
        else:
            head = random.choice(['[শিক্ষার্থীদের বেতন বকেয়া|কার কাছে কত পাব|পাওনার হিসাব|বাকির খাতা]:'])
            htoks, htags, hslots = fill.fill(head, ctx)
            lines = []
            for i in range(random.randint(2, 5)):
                c = fill.Ctx()
                t, g, s = fill.fill('{person:plain} {balance}', c)
                s = dict(s, inherited=[])
                lines.append((t, g, s, 'ledger_set'))
        numbered = random.random() < 0.6
        tokens, tags, segs = list(htoks), list(htags), []
        for i, (t, g, s, intent) in enumerate(lines):
            if numbered:
                tokens.append(random.choice([f'{L.bn(i + 1)}.', f'{L.bn(i + 1)})', f'{i + 1}.']))
                tags.append('O')
            elif i:
                tokens[-1] = tokens[-1] + ','
            start = len(tokens)
            tokens += t
            tags += g
            segs.append(dict(intent=intent, start=start, end=len(tokens), slots=s))
        rows.append(dict(family=f'headed:{segs[0]["intent"]}:{k % 40}', kind='headed', state='idle', shown=[], asked=None, tokens=tokens, tags=tags,
                         text=' '.join(tokens), intent=[s['intent'] for s in segs], segs=segs, slots={}, heading=' '.join(htoks), pair=None, noise=[]))
    return rows


EXIT_OK = {'task_add', 'task_query', 'reminder_add', 'reminder_query', 'ledger_add', 'ledger_query', 'cash_add', 'cash_query', 'note_add',
           'calendar_query', 'smalltalk', 'out_of_scope', 'complain_help', 'open_page', 'briefing'}


def exits(pool):
    states = [c for c in CTX if c['state'] != 'dictating_list']
    cand = [r for r in pool if r['intent'][0] in EXIT_OK]
    rows = []
    for r in random.sample(cand, int(len(cand) * EXIT_SHARE)):
        c = random.choice(states)
        x = dict(r, state=c['state'], shown=shown_list(c['shown']), asked=c['asked'], kind='exit', family='exit:' + r['family'])
        rows.append(x)
    return rows


def add_noise(rows):
    for r in rows:
        rate = NOISE_RATE if r['kind'] != 'context' else NOISE_RATE * 0.5
        if r['kind'] in ('headed', 'multi_numbered'):
            continue
        if random.random() < rate:
            toks, tags, kinds = noise.apply(r['tokens'], r['tags'], rate=0.9)
            if kinds and len(r['segs']) == 1:
                r['tokens'], r['tags'], r['noise'] = toks, tags, kinds
                r['segs'][0]['end'] = len(toks)
                r['text'] = ' '.join(toks)
            elif kinds and not any(k.startswith(('filler', 'stt', 'join')) for k in kinds):
                # Several requests: only changes that keep word positions.
                r['tokens'], r['tags'], r['noise'] = toks, tags, kinds
                r['text'] = ' '.join(toks)


def trigrams(s):
    s = f' {s} '
    return {s[i:i + 3] for i in range(len(s) - 2)}


def gold_filter(rows):
    gold = []
    for f in glob.glob(os.path.join(GOLD, '*.jsonl')):
        for line in open(f):
            if line.strip():
                g = json.loads(line)
                gold.append((g['id'], g['text']))
                for a in g.get('heard_alts') or []:
                    gold.append((g['id'], a))
    gnorm = [(gid, norm(t)) for gid, t in gold]
    exact = {n: gid for gid, n in gnorm}
    index = defaultdict(set)
    gtri = []
    for i, (gid, n) in enumerate(gnorm):
        tri = trigrams(n)
        gtri.append(tri)
        for t in tri:
            index[t].add(i)
    keep, dropped = [], []
    for r in rows:
        n = norm(r['text'])
        hit = exact.get(n)
        why = 'exact' if hit else None
        if not hit and len(n) >= 6:
            tri = trigrams(n)
            cnt = Counter()
            for t in tri:
                for i in index.get(t, ()):
                    cnt[i] += 1
            need = 0.8 * len(tri)
            for i in sorted(i for i, c in cnt.items() if c >= need):
                j = cnt[i] / len(tri | gtri[i])
                if j >= 0.8:
                    hit, why = gnorm[i][0], f'near:{j:.2f}'
                    break
        if hit:
            dropped.append(dict(text=r['text'], intent=r['intent'], gold=hit, why=why))
        else:
            keep.append(r)
    return keep, dropped, len(gold)


def dedupe(rows):
    by = defaultdict(list)
    for r in rows:
        by[(r['state'], norm(r['text']))].append(r)
    out, conflicts = [], []
    for k, rs in by.items():
        intents = {tuple(r['intent']) for r in rs}
        if len(intents) > 1:
            conflicts.append(dict(text=rs[0]['text'], state=k[0], intents=sorted(intents)))
            continue
        out.append(rs[0])
    return out, conflicts


def is_dev(fam):
    base = fam.split('+')[0]
    h = int(hashlib.md5(base.encode()).hexdigest()[:8], 16)
    return (h % 1000) / 1000 < DEV_SHARE


def check_pairs(rows):
    P = json.load(open(os.path.join(SPEC, 'pairs.json')))
    have = Counter(r['intent'][0] for r in rows if len(r['intent']) == 1)
    return [dict(pair=p['pair'], a=p['a_intent'], a_n=have[p['a_intent']], b=p['b_intent'], b_n=have[p['b_intent']]) for p in P]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--seed', type=int, default=7)
    a = ap.parse_args()
    random.seed(a.seed)
    os.makedirs(OUT, exist_ok=True)
    single, fams = singles()
    ctx = contexts()
    rows = single + ctx + multis(single) + headed() + exits(single)
    add_noise(rows)
    ai = os.path.join(OUT, 'paraphrase.jsonl')
    ai_rows = [json.loads(l) for l in open(ai)] if os.path.exists(ai) else []
    rows += ai_rows
    rows, conflicts = dedupe(rows)
    rows, dropped, ngold = gold_filter(rows)
    spec_intents = [x['id'] for x in json.load(open(os.path.join(SPEC, 'intents.json')))]
    bad = sorted({i for r in rows for i in r['intent'] if i not in spec_intents})
    if bad:
        raise SystemExit(f'intents not in the spec: {bad}')
    spec_slots = set(json.load(open(os.path.join(SPEC, 'slots.json'))))
    bad_slots = sorted({t[2:] for r in rows for t in r['tags'] if t != 'O' and t[2:] not in spec_slots})
    if bad_slots:
        raise SystemExit(f'slots not in the spec: {bad_slots}')
    for i, r in enumerate(rows):
        r['id'] = f'gen-{i:06d}'
        r['split'] = 'dev' if is_dev(r['family']) else 'train'
        assert len(r['tokens']) == len(r['tags']), r
    train = [r for r in rows if r['split'] == 'train']
    dev = [r for r in rows if r['split'] == 'dev']
    for name, rs in (('train', train), ('dev', dev), ('dropped_gold', dropped), ('conflicts', conflicts)):
        with open(os.path.join(OUT, f'{name}.jsonl'), 'w') as f:
            for r in rs:
                f.write(json.dumps(r, ensure_ascii=False) + '\n')
    per = Counter()
    for r in rows:
        for i in r['intent']:
            per[i] += 1
    stats = dict(seed=a.seed, total=len(rows), train=len(train), dev=len(dev), families=len({r['family'].split('+')[0] for r in rows}),
                 template_families=len(fams), kinds=Counter(r['kind'] for r in rows), states=Counter(r['state'] for r in rows),
                 noise=Counter(k.split(':')[0] for r in rows for k in r['noise']), regions=Counter(k.split(':')[1] for r in rows for k in r['noise'] if k.startswith('region')),
                 per_intent=dict(sorted(per.items(), key=lambda x: -x[1])), missing_intents=[i for i in spec_intents if not per[i]],
                 dropped_gold=len(dropped), dropped_gold_kinds=Counter(d['why'].split(':')[0] for d in dropped), gold_sentences=ngold, conflicts=len(conflicts),
                 pairs=check_pairs(rows), sources=Counter(r.get('source', 'template') for r in rows), cost_usd=ai_cost())
    json.dump(stats, open(os.path.join(OUT, 'stats.json'), 'w'), ensure_ascii=False, indent=1)
    review(rows)
    print(json.dumps({k: v for k, v in stats.items() if k not in ('per_intent', 'pairs')}, ensure_ascii=False))


def ai_cost():
    total = 0.0
    for p in ('anthropic', 'gemini'):
        f = os.path.join(OUT, f'paraphrase_usage_{p}.json')
        if os.path.exists(f):
            total += json.load(open(f)).get('usd', 0)
    return round(total, 4)


def show_slots(r):
    parts = []
    for s in r['segs']:
        sl = ', '.join(f'{k}={v}' for k, v in s['slots'].items() if k != 'inherited' and v not in (None, ''))
        parts.append(f"{s['intent']}" + (f' ({sl})' if sl else ''))
    return ' | '.join(parts)


def marked(r):
    out, cur = [], None
    for t, g in zip(r['tokens'], r['tags']):
        if g.startswith('B-'):
            if cur:
                out.append(']')
            out.append(f'[{g[2:]}: {t}')
            cur = g[2:]
        elif g.startswith('I-'):
            out.append(t)
        else:
            if cur:
                out.append(']')
                cur = None
            out.append(t)
    if cur:
        out.append(']')
    return ' '.join(out).replace(' ]', ']')


def review(rows):
    rnd = random.Random(1000)
    sample = rnd.sample(rows, min(1000, len(rows)))
    with open(os.path.join(OUT, 'review_1000.csv'), 'w', newline='', encoding='utf-8-sig') as f:
        w = csv.writer(f)
        w.writerow(['নং', 'id', 'অ্যাপ তখন যা জিজ্ঞেস করেছিল', 'দেখানো তালিকা', 'বাক্য', 'চিহ্নিত তথ্য', 'intent (কাজ) ও তথ্য', 'রায় (ঠিক / অস্বাভাবিক / ভুল লেবেল)', 'মন্তব্য'])
        for i, r in enumerate(sample, 1):
            w.writerow([i, r['id'], r['asked'] or '', ' / '.join(r['shown']), r['text'], marked(r), show_slots(r), '', ''])


if __name__ == '__main__':
    main()
