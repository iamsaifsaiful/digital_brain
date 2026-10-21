# AI rewrites of template sentences (step D), with the labels carried along
# as inline tags and checked on the way back.
#
#   python3 tool/nlu/data/paraphrase.py prepare [--seeds 2400] [--per 5]
#       picks seeds from the train split, writes the requests and prints the
#       cost estimate. Nothing is sent.
#   ANTHROPIC_API_KEY=… python3 tool/nlu/data/paraphrase.py submit-anthropic
#   ANTHROPIC_API_KEY=… python3 tool/nlu/data/paraphrase.py collect-anthropic
#   GEMINI_API_KEY=…    python3 tool/nlu/data/paraphrase.py submit-gemini / collect-gemini
#   python3 tool/nlu/data/paraphrase.py verify
#       keeps a rewrite only if every tag is still there with exactly the same
#       words inside (so the value is unchanged) and no tag was added; writes
#       out/data/paraphrase.jsonl, which generate.py then merges (gold filter,
#       dedupe and split by the seed's family apply to it too).
#
# Keys are read from the environment only and never written anywhere.
import argparse, json, os, random, re, sys, time, urllib.request
from collections import Counter, defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(HERE, '..', 'out', 'data'))
PRICES = {  # USD per million tokens, batch (half of the normal price)
    'anthropic': dict(model='claude-haiku-5-5', input=0.05, output=0.25),
    'gemini': dict(model='gemini-3.1-flash-lite', input=0.125, output=0.75),
}
# Bengali text costs more tokens than English; this is a cautious guess
# (characters per token), checked against the usage the first batch reports.
CHARS_PER_TOKEN = 1.6

INSTRUCTIONS = '''You rewrite short messages that people in Bangladesh send to a personal assistant app (by voice or typing, mostly Bengali, sometimes Banglish or regional words).
For the message below, write {n} different ways a real person might say the SAME request: different word order, everyday words, short or longer, polite or blunt, spoken style, some with regional (Noakhali, Chattogram, Sylhet, Barishal, Rajshahi, Mymensingh) verb forms, at most one in Banglish.
Rules:
- Same meaning and same request type. Do not add new requests, questions or facts.
- Every <tag>…</tag> must appear exactly once in each rewrite, with EXACTLY the same words inside. You may move it. Do not add tags.
- Do not translate or change numbers, names, dates or times inside tags.
- No numbering, no explanation. Answer only JSON: {{"rewrites": ["…", "…"]}}'''

TAG = re.compile(r'<([a-z_0-9]+)>(.*?)</\1>')


def tagged(r):
    out, cur, buf = [], None, []
    for t, g in zip(r['tokens'], r['tags']):
        slot = g[2:] if g != 'O' else None
        if cur and (g.startswith('B-') or slot != cur):
            out.append(f'<{cur}>{" ".join(buf)}</{cur}>')
            cur, buf = None, []
        if slot:
            cur = slot
            buf.append(t)
        else:
            out.append(t)
    if cur:
        out.append(f'<{cur}>{" ".join(buf)}</{cur}>')
    return ' '.join(out)


def pick_seeds(n_seeds, rnd):
    rows = [json.loads(l) for l in open(os.path.join(OUT, 'train.jsonl'))]
    # Phone-only kinds (vault, health, medicine, contacts, profile) are not
    # sent out even as made-up sentences: the rule is simple to keep that way.
    spec = json.load(open(os.path.join(HERE, '..', 'spec', 'intents.json')))
    phone_only = {x['id'] for x in spec if x.get('phone_only')}
    rows = [r for r in rows if r['kind'] in ('single', 'context') and not r['noise'] and r['intent'][0] not in phone_only]
    by = defaultdict(list)
    for r in rows:
        by[r['intent'][0]].append(r)
    # Small intents get as many seeds as the big ones: they need the variety most.
    per = max(10, n_seeds // len(by))
    seeds = []
    for intent, rs in sorted(by.items()):
        rnd.shuffle(rs)
        seeds += rs[:per]
    rnd.shuffle(seeds)
    return seeds[:n_seeds]


def prompt_for(r, n):
    ctx = ''
    if r['state'] != 'idle':
        ctx = f"\nThe app had just asked: “{r['asked']}”" + (f" and shown: {' / '.join(r['shown'])}" if r['shown'] else '') + '. The message is the answer.'
    return INSTRUCTIONS.format(n=n) + ctx + f"\nMessage: {tagged(r)}"


def prepare(a):
    rnd = random.Random(a.seed)
    seeds = pick_seeds(a.seeds, rnd)
    half = len(seeds) // 2 if a.providers == 'both' else (len(seeds) if a.providers == 'anthropic' else 0)
    reqs = {'anthropic': [], 'gemini': []}
    for i, r in enumerate(seeds):
        p = 'anthropic' if i < half else 'gemini'
        reqs[p].append(dict(custom_id=f'p{i:05d}', seed=r['id'], family=r['family'], prompt=prompt_for(r, a.per)))
    est = {}
    for p, rs in reqs.items():
        if not rs:
            continue
        tin = sum(len(x['prompt']) for x in rs) / CHARS_PER_TOKEN
        tout = sum(a.per * (len(tagged(next(s for s in seeds if s['id'] == x['seed']))) * 1.2 + 10) for x in rs) / CHARS_PER_TOKEN + 20 * len(rs)
        pr = PRICES[p]
        cost = tin / 1e6 * pr['input'] + tout / 1e6 * pr['output']
        est[p] = dict(model=pr['model'], requests=len(rs), input_tokens=int(tin), output_tokens=int(tout), usd=round(cost, 2), max_sentences=len(rs) * a.per)
        with open(os.path.join(OUT, f'paraphrase_requests_{p}.jsonl'), 'w') as f:
            for x in rs:
                f.write(json.dumps(x, ensure_ascii=False) + '\n')
    est['total_usd'] = round(sum(v['usd'] for v in est.values() if isinstance(v, dict)), 2)
    est['seeds_by_intent'] = Counter(s['intent'][0] for s in seeds)
    json.dump(est, open(os.path.join(OUT, 'paraphrase_estimate.json'), 'w'), ensure_ascii=False, indent=1)
    print(json.dumps({k: v for k, v in est.items() if k != 'seeds_by_intent'}, ensure_ascii=False, indent=1))


def _key(name):
    k = os.environ.get(name)
    if not k:
        sys.exit(f'{name} is not set')
    return k


def _http(url, body=None, headers=None, method=None):
    req = urllib.request.Request(url, data=json.dumps(body).encode() if body is not None else None, headers=headers or {}, method=method)
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def submit_anthropic(a):
    key = _key('ANTHROPIC_API_KEY')
    rs = [json.loads(l) for l in open(os.path.join(OUT, 'paraphrase_requests_anthropic.jsonl'))]
    body = dict(requests=[dict(custom_id=x['custom_id'], params=dict(model=PRICES['anthropic']['model'], max_tokens=1200,
                                                                         messages=[dict(role='user', content=x['prompt'])])) for x in rs])
    h = {'x-api-key': key, 'anthropic-version': '2023-06-01', 'content-type': 'application/json'}
    res = json.loads(_http('https://api.anthropic.com/v1/messages/batches', body, h))
    json.dump(dict(id=res['id']), open(os.path.join(OUT, 'paraphrase_batch_anthropic.json'), 'w'))
    print('batch', res['id'], res.get('processing_status'))


def collect_anthropic(a):
    key = _key('ANTHROPIC_API_KEY')
    bid = json.load(open(os.path.join(OUT, 'paraphrase_batch_anthropic.json')))['id']
    h = {'x-api-key': key, 'anthropic-version': '2023-06-01'}
    while True:
        st = json.loads(_http(f'https://api.anthropic.com/v1/messages/batches/{bid}', headers=h))
        if st['processing_status'] == 'ended':
            break
        print('waiting', st['request_counts'])
        time.sleep(60)
    raw = _http(st['results_url'], headers=h).decode()
    usage = Counter()
    with open(os.path.join(OUT, 'paraphrase_raw_anthropic.jsonl'), 'w') as f:
        for line in raw.splitlines():
            r = json.loads(line)
            if r['result']['type'] != 'succeeded':
                continue
            m = r['result']['message']
            usage['input'] += m['usage']['input_tokens']
            usage['output'] += m['usage']['output_tokens']
            f.write(json.dumps(dict(custom_id=r['custom_id'], text=''.join(c.get('text', '') for c in m['content'])), ensure_ascii=False) + '\n')
    pr = PRICES['anthropic']
    usage['usd'] = round(usage['input'] / 1e6 * pr['input'] + usage['output'] / 1e6 * pr['output'], 4)
    json.dump(usage, open(os.path.join(OUT, 'paraphrase_usage_anthropic.json'), 'w'))
    print('usage', dict(usage))


def submit_gemini(a):
    key = _key('GEMINI_API_KEY')
    rs = [json.loads(l) for l in open(os.path.join(OUT, 'paraphrase_requests_gemini.jsonl'))]
    body = dict(batch=dict(display_name='my-assistant-paraphrase', input_config=dict(requests=dict(requests=[
        dict(request=dict(contents=[dict(parts=[dict(text=x['prompt'])], role='user')], generationConfig=dict(responseMimeType='application/json')),
             metadata=dict(key=x['custom_id'])) for x in rs]))))
    model = PRICES['gemini']['model']
    res = json.loads(_http(f'https://generativelanguage.googleapis.com/v1beta/models/{model}:batchGenerateContent', body,
                           {'x-goog-api-key': key, 'content-type': 'application/json'}))
    json.dump(dict(name=res['name']), open(os.path.join(OUT, 'paraphrase_batch_gemini.json'), 'w'))
    print('batch', res['name'])


def collect_gemini(a):
    key = _key('GEMINI_API_KEY')
    name = json.load(open(os.path.join(OUT, 'paraphrase_batch_gemini.json')))['name']
    h = {'x-goog-api-key': key}
    while True:
        st = json.loads(_http(f'https://generativelanguage.googleapis.com/v1beta/{name}', headers=h))
        if st.get('done'):
            break
        print('waiting', st.get('metadata', {}).get('state'))
        time.sleep(60)
    usage = Counter()
    with open(os.path.join(OUT, 'paraphrase_raw_gemini.jsonl'), 'w') as f:
        for r in st['response']['inlinedResponses']['inlinedResponses']:
            if 'response' not in r:
                continue
            resp = r['response']
            u = resp.get('usageMetadata', {})
            usage['input'] += u.get('promptTokenCount', 0)
            usage['output'] += u.get('candidatesTokenCount', 0) + u.get('thoughtsTokenCount', 0)
            text = ''.join(p.get('text', '') for c in resp.get('candidates', []) for p in c['content'].get('parts', []))
            f.write(json.dumps(dict(custom_id=r['metadata']['key'], text=text), ensure_ascii=False) + '\n')
    pr = PRICES['gemini']
    usage['usd'] = round(usage['input'] / 1e6 * pr['input'] + usage['output'] / 1e6 * pr['output'], 4)
    json.dump(usage, open(os.path.join(OUT, 'paraphrase_usage_gemini.json'), 'w'))
    print('usage', dict(usage))


def verify(a):
    seeds = {}
    for f in ('train.jsonl',):
        for l in open(os.path.join(OUT, f)):
            r = json.loads(l)
            seeds[r['id']] = r
    kept, why = [], Counter()
    for p in ('anthropic', 'gemini'):
        req_f = os.path.join(OUT, f'paraphrase_requests_{p}.jsonl')
        raw_f = os.path.join(OUT, f'paraphrase_raw_{p}.jsonl')
        if not os.path.exists(raw_f):
            continue
        reqs = {x['custom_id']: x for x in map(json.loads, open(req_f))}
        for line in open(raw_f):
            r = json.loads(line)
            q = reqs.get(r['custom_id'])
            seed = seeds.get(q['seed']) if q else None
            if not seed:
                why['no_seed'] += 1
                continue
            want = Counter(TAG.findall(tagged(seed)))
            try:
                m = re.search(r'\{.*\}', r['text'], re.S)
                outs = json.loads(m.group(0))['rewrites']
            except Exception:
                why['bad_json'] += 1
                continue
            for o in outs:
                o = re.sub(r'\s+', ' ', str(o)).strip()
                got = Counter(TAG.findall(o))
                if got != want:
                    why['tags_changed'] += 1
                    continue
                toks, tags = [], []
                pos = 0
                for m2 in TAG.finditer(o):
                    for w in o[pos:m2.start()].split():
                        toks.append(w)
                        tags.append('O')
                    for k, w in enumerate(m2.group(2).split()):
                        toks.append(w)
                        tags.append(('B-' if k == 0 else 'I-') + m2.group(1))
                    pos = m2.end()
                for w in o[pos:].split():
                    toks.append(w)
                    tags.append('O')
                if '<' in ' '.join(toks) or '>' in ' '.join(toks):
                    why['stray_tag'] += 1
                    continue
                x = dict(seed, tokens=toks, tags=tags, text=' '.join(toks), kind=seed['kind'] + '+ai', noise=[], source=p, seed_id=seed['id'])
                x['segs'] = [dict(seed['segs'][0], end=len(toks))]
                kept.append(x)
                why['kept'] += 1
    with open(os.path.join(OUT, 'paraphrase.jsonl'), 'w') as f:
        for x in kept:
            f.write(json.dumps(x, ensure_ascii=False) + '\n')
    print(dict(why))


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('cmd', choices=['prepare', 'submit-anthropic', 'collect-anthropic', 'submit-gemini', 'collect-gemini', 'verify'])
    ap.add_argument('--seeds', type=int, default=2400)
    ap.add_argument('--per', type=int, default=5)
    ap.add_argument('--seed', type=int, default=11)
    ap.add_argument('--providers', default='both', choices=['both', 'anthropic', 'gemini'])
    a = ap.parse_args()
    {'prepare': prepare, 'submit-anthropic': submit_anthropic, 'collect-anthropic': collect_anthropic, 'submit-gemini': submit_gemini,
     'collect-gemini': collect_gemini, 'verify': verify}[a.cmd](a)
