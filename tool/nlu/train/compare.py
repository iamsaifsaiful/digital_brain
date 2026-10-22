# Gate 3 table: old rules vs the models on the gold set.
#   python3 tool/nlu/train/compare.py --md docs/nlu-models-<date>.md
import argparse, json, os, sys
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..'))
import eval as E  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, '..'))
SYSTEMS = [  # (name, prediction file, key, size, on-phone time)
    ('পুরনো নিয়ম (এখনকার অ্যাপ)', 'baseline_old.jsonl', 'chat'),
    ('ভিত্তি মডেল (n-gram linear)', 'pred_baseline.jsonl', 'base'),
    ('ছোট transformer (শূন্য থেকে)', 'pred_tiny.jsonl', 'tiny'),
    ('BanglaBERT-small (পূর্ব-শেখা)', 'pred_bert.jsonl', 'bert'),
]


def pct(a, b):
    return f'{100 * a / b:.1f}%' if b else '—'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--md')
    ap.add_argument('--extra', default='{}', help='json: key → {size, ms}')
    a = ap.parse_args()
    extra = json.loads(a.extra)
    gold = E.load_gold(os.path.join(ROOT, 'gold'))
    res = []
    for label, f, key in SYSTEMS:
        path = os.path.join(ROOT, 'out', f)
        if not os.path.exists(path):
            continue
        preds = [json.loads(l) for l in open(path) if l.strip()]
        r = E.evaluate(gold, preds, key)
        # Settled on the phone = the system's own "sure" (rules: decided; models: above the intent's threshold).
        n = ok = 0
        for g, p in [(gold[p['id']], p) for p in preds if p['id'] in gold and not E.is_closed(gold[p['id']])]:
            conf = p.get(f'{key}_conf', 1.0 if E.decided(p[key]) else 0.0)
            if conf >= 0.999 and E.decided(p[key]):
                n += 1
                ok += set(p[key]) == set(g['intent'])
        res.append((label, key, r, n, ok))
    L = ['| | ' + ' | '.join(x[0] for x in res) + ' |', '|---|' + '---|' * len(res)]

    def row(name, fn):
        L.append(f'| {name} | ' + ' | '.join(fn(x) for x in res) + ' |')
    row('পুরো মিল (সব সারি)', lambda x: pct(x[2]['exact'], x[2]['n']))
    row('আলাদা বাক্য ধরে', lambda x: pct(x[2]['distinct'][1], x[2]['distinct'][0]))
    row('ফোনে নিশ্চিত হয়ে সমাধান', lambda x: pct(x[3], x[2]['n']))
    row('তার মধ্যে ঠিক', lambda x: pct(x[4], x[3]))
    row('মোছা ঠিক', lambda x: pct(x[2]['delete'][1], x[2]['delete'][0]))
    row('না-চাওয়া মোছার প্রস্তাব', lambda x: str(x[2]['false_delete']))
    row('টাকা ঠিক', lambda x: pct(x[2]['money'][1], x[2]['money'][0]))
    row('কাজের নাম ধরা (title)', lambda x: f"{x[2]['slots'][1]}/{x[2]['slots'][0]}" if x[2]['slots'][0] else '—')
    row('ছোট সাধারণ উত্তর', lambda x: f"{x[2]['closed'][1]}/{x[2]['closed'][0]}")
    row('আকার', lambda x: extra.get(x[1], {}).get('size', '—'))
    row('সময় / বার্তা', lambda x: extra.get(x[1], {}).get('ms', '—'))
    L += ['', '**উৎস অনুযায়ী (পুরো মিল)**', '', '| উৎস | ' + ' | '.join(x[0] for x in res) + ' |', '|---|' + '---|' * len(res)]
    srcs = sorted({k for x in res for k in x[2]['by_source']})
    for s in srcs:
        L.append(f'| {s} | ' + ' | '.join(pct(x[2]['by_source'][s][1], x[2]['by_source'][s][0]) for x in res) + ' |')
    L += ['', '**intent অনুযায়ী (প্রধান intent ধরা)**', '', '| intent | সারি | ' + ' | '.join(x[1] for x in res) + ' |', '|---|---|' + '---|' * len(res)]
    per = sorted(res[0][2]['per'].items(), key=lambda kv: -kv[1][0])
    for k, (n, _) in per:
        L.append(f'| {k} | {n} | ' + ' | '.join(pct(x[2]['per'][k][1], x[2]['per'][k][0]) for x in res) + ' |')
    text = '\n'.join(L)
    if a.md:
        open(a.md, 'w').write(text)
    print(text)


if __name__ == '__main__':
    main()
